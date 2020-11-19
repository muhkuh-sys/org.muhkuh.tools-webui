local class = require 'pl.class'
local Process = require 'process'
local ProcessZmq = class(Process)

function ProcessZmq:_init(tLog, tLogTest, strCommand, astrArguments, strWorkingPath)
  self:super(tLog)
  self.tLogTest = tLogTest

  self.strCommand = strCommand
  self.astrArguments = astrArguments
  self.strWorkingPath = strWorkingPath

  self.json = require 'dkjson'

  self.m_zmqContext = nil
  self.m_zmqSocket = nil
  self.m_zmqPort = nil
  self.m_zmqServerAddress = nil
  self.m_zmqPoll = nil

  self.m_buffer = nil

  self.m_fnOnTerminate = nil
  self.m_tOnTerminateParameter = nil

  self.m_strPeerName = nil

  self.m_logConsumer = nil

  self.m_zmqReceiveHandler = {
    LOG = self.__onZmqReceiveLog,
    INT = self.__onZmqReceiveInt,
    IDA = self.__onZmqReceiveIda,
    TTL = self.__onZmqReceiveTtl,
    SER = self.__onZmqReceiveSer,
    NAM = self.__onZmqReceiveNam,
    STA = self.__onZmqReceiveSta,
    CUR = self.__onZmqReceiveCur,
    TSS = self.__onZmqReceiveTss,
    TSF = self.__onZmqReceiveTsf,
    TDS = self.__onZmqReceiveTds,
    TDF = self.__onZmqReceiveTdf,
    GPN = self.__onZmqReceiveGpn,
    LEV = self.__onZmqReceiveLev
  }
end



function ProcessZmq:__zmq_init()
  -- Create the 0MQ context and the socket.
  local zmq = require 'lzmq'
  local tZContext, strError = zmq.context()
  if tZContext==nil then
    error('Failed to create ZMQ context: ' .. tostring(strError))
  end
  self.m_zmqContext = tZContext

  local tZSocket, strError = tZContext:socket(zmq.PAIR)
  if tZSocket==nil then
    error('Failed to create ZMQ socket: ' .. tostring(strError))
  end
  self.m_zmqSocket = tZSocket

  local tServerPort, strError = tZSocket:bind_to_random_port('tcp://127.0.0.1')
  if tServerPort==nil then
    error('Failed to bind the socket: ' .. tostring(strError))
  end
  strServerAddress = string.format('tcp://127.0.0.1:%d', tServerPort)
  self.tLog.debug('0MQ listening on %s', strServerAddress)
  self.m_zmqPort = tServerPort
  self.m_zmqServerAddress = strServerAddress

  local uv = require 'lluv'
  local this = self
  local tPoll = uv.poll_zmq(tZSocket)
  tPoll:start(function(tHandle, strErr, tSocket)
    this:__onZmqReceive(tHandle, strErr, tSocket)
  end)
  self.m_zmqPoll = tPoll
end



function ProcessZmq:__onZmqReceiveLog(tHandle, strMessage)
  local strLogLevel, strLogMessage = string.match(strMessage, '^LOG(%d+),(.*)')
  if strLogLevel~=nil and strLogMessage~=nil then
    -- Add a newline if it is not already there.
    if string.sub(strLogMessage, -1)~='\n' then
      strLogMessage = strLogMessage .. '\n'
    end
    local uiLogLevel = tonumber(strLogLevel)
    if uiLogLevel==nil then
      print(string.format('Invalid LOG level received: "%s".', strMessage))
    else
      self.tLogTest.log(uiLogLevel, strLogMessage)

      -- Send the log to the log consumer.
      local tLogConsumer = self.m_logConsumer
      if tLogConsumer~=nil then
        tLogConsumer:onLogMessage(uiLogLevel, strLogMessage)
      end
    end
  else
    print(string.format('Invalid LOG message received: "%s".', strMessage))
  end
end



function ProcessZmq:__onZmqReceiveInt(tHandle, strMessage)
  local strInteraction = string.match(strMessage, '^INT(.*)')
  if strInteraction~=nil then
    local tBuffer = self.m_buffer
    if tBuffer==nil then
      print('warning: discarding interaction as no buffer present.')
    else
      tBuffer:setInteraction(strInteraction)
    end
  else
    print(string.format('Invalid interaction received: "%s".', strMessage))
  end
end



function ProcessZmq:__onZmqReceiveIda(tHandle, strMessage)
  local strInteractionData = string.match(strMessage, '^IDA(.*)')
  if strInteractionData~=nil then
    local tBuffer = self.m_buffer
    if tBuffer==nil then
      print('warning: discarding interaction data as no buffer present.')
    else
      tBuffer:setInteractionData(strInteractionData)
    end
  else
    print(string.format('Invalid interaction data received: "%s".', strMessage))
  end
end



function ProcessZmq:__onZmqReceiveTtl(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^TTL(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local strTitle = tJson.title
    local strSubtitle = tJson.subtitle
    self.m_buffer:setTitle(strTitle, strSubtitle)
  end
end



function ProcessZmq:__onZmqReceiveSer(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^SER(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local fHasSerial = tJson.hasSerial
    local uiFirstSerial = tJson.firstSerial
    local uiLastSerial = tJson.lastSerial
    self.m_buffer:setSerials(fHasSerial, uiFirstSerial, uiLastSerial)
  end
end



function ProcessZmq:__onZmqReceiveNam(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^NAM(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    self.m_buffer:setTestNames(tJson)
  end
end



function ProcessZmq:__onZmqReceiveSta(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^STA(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    self.m_buffer:setTestStati(tJson)
  end
end



function ProcessZmq:__onZmqReceiveCur(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^CUR(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local uiCurrentSerial = tJson.currentSerial
    self.m_buffer:setCurrentSerial(uiCurrentSerial)
  end
end



function ProcessZmq:__onZmqReceiveTss(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^TSS(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local uiStepIndex = tJson.stepIndex
    local strTestCaseId = tJson.testId
    local strTestCaseName = tJson.testName
    local atLogAttributes = tJson.attributes

    self.m_buffer:setRunningTest(uiStepIndex)
    self.m_buffer:setTestState('idle')

    -- Send the log consumer a test step started event and the log atttributes.
    local tLogConsumer = self.m_logConsumer
    if tLogConsumer~=nil then
      tLogConsumer:onTestStepStarted(uiStepIndex, strTestCaseId, strTestCaseName, atLogAttributes)
    end
  end
end



function ProcessZmq:__onZmqReceiveTsf(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^TSF(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local strTestStepState = tJson.testStepState

    self.m_buffer:setTestState(strTestStepState)
    self.m_buffer:setRunningTest(nil)

    -- Send the log consumer a test step finished event.
    local tLogConsumer = self.m_logConsumer
    if tLogConsumer~=nil then
      tLogConsumer:onTestStepFinished()
    end
  end
end



function ProcessZmq:__onZmqReceiveTds(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^TDS(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local atLogAttributes = tJson.attributes

    -- Send the log consumer a test device started event and the log atttributes.
    local tLogConsumer = self.m_logConsumer
    if tLogConsumer~=nil then
      tLogConsumer:onTestRunStarted(atLogAttributes)
    end
  end
end



function ProcessZmq:__onZmqReceiveTdf(tHandle, strMessage)
  -- Send the log consumer a test device finished event.
  local tLogConsumer = self.m_logConsumer
  if tLogConsumer~=nil then
    tLogConsumer:onTestRunFinished()
  end
end



function ProcessZmq:__onZmqReceiveGpn(tHandle, strMessage)
  local strPeerName = self.m_strPeerName
  if strPeerName==nil then
    strPeerName = ''
  end
  local strData = string.format('SPN%s', strPeerName)
  self.m_zmqSocket:send(strData)
end



function ProcessZmq:__onZmqReceiveLev(tHandle, strMessage)
  local tLog = self.tLog
  local strResponseRaw = string.match(strMessage, '^LEV(.*)')
  local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local strEventId = tJson.id
    local atAttributes = tJson.attr

    -- Send the log consumer an event.
    local tLogConsumer = self.m_logConsumer
    if tLogConsumer~=nil then
      tLogConsumer:onEvent(strEventId, atAttributes)
    end
  end
end



function ProcessZmq:__onZmqReceive(tHandle, strErr, tSocket)
  if strErr then
    return tHandle:close()
  else
    local strMessage = tSocket:recv()

    -- The first 3 chars are the message type.
    local strId = string.sub(strMessage, 1, 3)
    local fnHandler = self.m_zmqReceiveHandler[strId]
    if fnHandler==nil then
      print('**** ZMQ received unknown message:', strMessage)
    else
      -- Call the handler.
      fnHandler(self, tHandle, strMessage)
    end
  end
end



function ProcessZmq:__zmq_delete()
  local tPoll = self.m_zmqPoll
  if tPoll~=nil then
    tPoll:stop()
    tPoll:close()
    self.m_zmqPoll = nil
  end

  local zmqSocket = self.m_zmqSocket
  if zmqSocket~=nil then
    if zmqSocket:closed()==false then
      zmqSocket:disconnect(self.m_zmqServerAddress)
      zmqSocket:close()
    end
    self.m_zmqSocket = nil
  end

  local zmqContext = self.m_zmqContext
  if zmqContext~=nil then
    zmqContext:destroy()
    self.m_zmqContext = nil
  end

  self.m_zmqPort = nil

  self.tLog.debug('0MQ closed')
end



function ProcessZmq:setInteractionResponse(strResponse)
  local strData = string.format('RSP%s', strResponse)
  self.m_zmqSocket:send(strData)
end



function ProcessZmq:setBuffer(tBuffer)
  self.m_buffer = tBuffer
end



function ProcessZmq:setLogConsumer(tLogConsumer)
  self.m_logConsumer = tLogConsumer
end



function ProcessZmq:run(fnOnTerminate, tOnTerminateParameter)
  -- Remember the callback function.
  self.m_fnOnTerminate = fnOnTerminate
  self.m_tOnTerminateParameter = tOnTerminateParameter

  self:__zmq_init()

  -- Filter the arguments.
  local astrArgs = {}
  local strZmqPort = tostring(self.m_zmqPort)
  for _, strArg in ipairs(self.astrArguments) do
    local strArgSub = string.gsub(tostring(strArg), '%${ZMQPORT}', strZmqPort)
    table.insert(astrArgs, strArgSub)
  end

  self:run_process(self.strCommand, astrArgs, self.strWorkingPath)
end



function ProcessZmq:onClose(strError, iExitStatus, uiTermSignal)
  print('ZMQ closed:', strError, iExitStatus, uiTermSignal)
  self:__zmq_delete()

  -- Does a callback exist?
  local fnOnTerminate = self.m_fnOnTerminate
  if fnOnTerminate~=nil then
    fnOnTerminate(self.m_tOnTerminateParameter)
  end
end



function ProcessZmq:onStdOut(strData)
  if strData~=nil then
    self.tLogTest.info(strData)

    local tLogConsumer = self.m_logConsumer
    if tLogConsumer~=nil then
      tLogConsumer:onLogMessage(7, strData)
    end
  end
end



function ProcessZmq:onStdErr(strData)
  if strData~=nil then
    self.tLogTest.error(strData)

    local tLogConsumer = self.m_logConsumer
    if tLogConsumer~=nil then
      tLogConsumer:onLogMessage(4, strData)
    end
  end
end


function ProcessZmq:onCancel()
  local tLog = self.tLog

  tLog.info('Cancel: stop the running test.')
  -- TODO: this kills only the process, which is the LUA test. Any subprocesses started by the LUA test will keep running.
  self:shutdown()
end



function ProcessZmq:onPeerNameChanged(strPeerName)
  self.m_strPeerName = strPeerName
end


return ProcessZmq
