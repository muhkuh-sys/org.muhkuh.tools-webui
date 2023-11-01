local class = require 'pl.class'
local WebUiBuffer = class()


function WebUiBuffer:_init(tLog, usWebsocketPort)
  self.tLog = tLog
  self.usWebsocketPort = usWebsocketPort
  self.strWebsocketProtocol = 'muhkuh-tester'
  self.strWebsocketURL = string.format('ws://*:%d', usWebsocketPort)

  self.json = require 'dkjson'
  self.pl = require'pl.import_into'()
  local uv = require 'lluv'
  self.uv = uv
  self.ws  = require"lluv.websocket"

  -- Create a new converter from ISO-8859-1 to UTF-8.
  local iconv = require 'iconv'
  self.iconv = iconv
  tIConvUtf8 = iconv.new('UTF-8//TRANSLIT', 'ISO-8859-1')
  if tIConvUtf8==nil then
    tLog.error('Failed to create a new converter from ISO-8859-1 to UTF-8.')
  end
  self.tIConvUtf8 = tIConvUtf8

  self.tActiveConnection = nil
  self.strInteractionJsx = nil
  self.strInteractionData = nil
  self.tServer = nil

  self.strTitle = ''
  self.strSubTitle = ''
  self.fHasSerial = true

  self.uiCurrentSerial = nil
  self.uiRunningTest = nil

  self.astrTestNames = {}
  self.astrTestStati = {}

  self.astrLogMessages = {}
  self.uiSyncedLogIndex = 0

  self.atDocuments = {}

  self.tPersistenceApp = nil
  self.tPersistenceInteraction = nil

  self.tTester = nil

  -- Create a new log target for the test output.
  local this = self
  self.tLogWebUi = require "log".new(
    -- maximum log level
    'debug',
    function(fmt, msg, lvl, now) this:__onLogMessage(fmt, msg, lvl, now) end
  )

  self.tLogTimer = uv.timer()
  self.uiLogTimerMs = 500

  self.tHeartbeatTimer = uv.timer()
  self.uiHeartbeatIntervalMs = 2000
end



function WebUiBuffer:__toUtf8(strMsg)
  local iconv = self.iconv
  local tIConvUtf8 = self.tIConvUtf8
  local tLog = self.tLog

  -- Logging in the wrong encoding is still better than no logging. %-(
  if tIConvUtf8~=nil then
    -- Convert the data from ISO-8859-1 to UTF-8.
    local strMsgConv, tError = tIConvUtf8:iconv(strMsg)
    if strMsgConv==nil then
      if tError==iconv.ERROR_NO_MEMORY then
        strError = 'Failed to allocate enough memory in the conversion process.'
      elseif tError==iconv.ERROR_INVALID then
        strError = 'An invalid character was found in the input sequence.'
      elseif tError==iconv.ERROR_INCOMPLETE then
        strError = 'An incomplete character was found in the input sequence.'
      elseif tError==iconv.iconv.ERROR_FINALIZED then
        strError = 'Trying to use an already-finalized converter. This usually means that the user was tweaking the garbage collector private methods.'
      else
        strError = 'Unknown error.'
      end
      tLog.error('UTF-8 conversion failed: %s', strError)
    else
      strMsg = strMsgConv
    end
  end

  return strMsg
end



function WebUiBuffer:__onHeartbeatTimer(tTimer)
  local tConnection = self.tActiveConnection
  if tConnection~=nil then
    -- Send a heartbeat message.
    local tMessage = {
      id = 'Heartbeat'
    }
    local strJson = self.json.encode(tMessage)
    tConnection:write(strJson)

    tTimer:again(self.uiHeartbeatIntervalMs)
  end
end



function WebUiBuffer:__onLogTimer(tTimer)
  local tConnection = self.tActiveConnection
  if tConnection~=nil then
    -- Are new log messages waiting?
    local astrLogMessages = self.astrLogMessages
    local uiLogMessages = #astrLogMessages
    local uiSyncedLogIndex = self.uiSyncedLogIndex

    if uiSyncedLogIndex<uiLogMessages then
      local l = {}
      for uiCnt=uiSyncedLogIndex+1, uiLogMessages, 1 do
        table.insert(l, self:__toUtf8(astrLogMessages[uiCnt]))
      end

      local tMessage = {
        id = 'Log',
        lines = l
      }
      local strJson = self.json.encode(tMessage)
      tConnection:write(strJson)
      self.uiSyncedLogIndex = uiLogMessages
    end

    tTimer:again(self.uiLogTimerMs)
  end
end



function WebUiBuffer:__onLogMessage(fnFormat, strMessage, uiLevel, tDate)
  table.insert(self.astrLogMessages, string.format('%d,%s', uiLevel, fnFormat(strMessage, uiLevel, tDate)))
end



function WebUiBuffer:getLogTarget()
  return self.tLogWebUi
end



function WebUiBuffer:getWebsocketURL()
  return self.strWebsocketURL
end



function WebUiBuffer:__sendCurrentPeerName()
  local tTester = self.tTester
  if tTester~=nil then
    local strPeerName
    local tConnection = self.tActiveConnection
    if tConnection~=nil then
      strPeerName = tConnection:getpeername()
    end
    tTester:onPeerNameChanged(strPeerName)
  end
end



function WebUiBuffer:setTitle(strTitle, strSubTitle)
  -- Did the title or subtitle change?
  local fChanged = (self.strTitle~=strTitle) or (self.strSubTitle~=strSubTitle)
  if fChanged==true then
    -- Yes, the title or subtitle changed.

    -- Accept the new values.
    self.strTitle = strTitle
    self.strSubTitle = strSubTitle

    -- Push the new values to the UI if there is a connection.
    self:__sendState()
  end
end



function WebUiBuffer:setTestNames(astrTestNames)
  local strType = type(astrTestNames)
  if strType~='table' then
    self.tLogWebUi.error(string.format('The argument to "setTestNames" must be an array. Here it is %s.', strType))
  else
    -- Copy the test names and set the state to the default.
    local astrNames = {}
    local astrStati = {}
    for _,tName in ipairs(astrTestNames) do
      table.insert(astrNames, tostring(tName))
      table.insert(astrStati, 'idle')
    end

    -- Accept the new values.
    self.astrTestNames = astrNames
    self.astrTestStati = astrStati

    -- Push the new values to the UI if there is a connection.
    self:__sendState()
  end
end



function WebUiBuffer:setDocuments(atDocuments)
  local strType = type(atDocuments)
  if strType~='table' then
    self.tLogWebUi.error(string.format('The argument to "setDocuments" must be an array. Here it is %s.', strType))
  else
    -- Copy all documents.
    local atDocs = {}
    for _,tAttr in ipairs(atDocuments) do
      local strName = tAttr.name
      local strUrl = tAttr.url
      if strName~=nil and strUrl~=nil then
        table.insert(atDocs, {name=strName, url=strUrl})
      end
    end

    self.atDocuments = atDocs

    self:__sendState()
  end
end



function WebUiBuffer:setTestStati(astrTestStati)
  local astrOldTestStati = self.astrTestStati
  local fChanged = false
  for uiCnt, strOldState in ipairs(astrOldTestStati) do
    if strOldState~=astrTestStati[uiCnt] then
      fChanged = true
    end
  end
  if fChanged==true then
    for uiCnt = 1, #astrOldTestStati do
      astrOldTestStati[uiCnt] = astrTestStati[uiCnt]
    end
    self:__sendState()
  end
end



function WebUiBuffer:setInteraction(strJsx)
  if strJsx==nil then
    strJsx = ''
  else
    strJsx = tostring(strJsx)
  end

  -- Did the interaction change?
  local fChanged = (self.strInteractionJsx~=strJsx)
  if fChanged==true then
    -- Yes, it changed.

    -- Accept the new code.
    self.strInteractionJsx = strJsx
    -- Clear the persistent state of the old interaction.
    self.tPersistenceInteraction = nil

    -- Push the code to the UI if there is a connection.
    self:__sendState()
  end
end



function WebUiBuffer:setInteractionData(strData)
  if strData==nil then
    strData = ''
  else
    strData = tostring(strData)
  end

  -- Did the interaction data change?
  local fChanged = (self.strInteractionData~=strData)
  if fChanged then
    -- Yes, it changed.
    self.strInteractionData = strData

    -- Push the code to the UI if there is a connection.
    self:__sendState()
  end
end



function WebUiBuffer:setCurrentSerial(uiCurrentSerial)
  -- The current serial number can be nil or a number.
  if uiCurrentSerial==nil or tonumber(uiCurrentSerial)~=nil then
    -- Did the current serial change?
    local fChanged = (self.uiCurrentSerial~=uiCurrentSerial)
    if fChanged==true then
      self.uiCurrentSerial = uiCurrentSerial

      self:__sendState()
    end
  end
end



function WebUiBuffer:setRunningTest(uiRunningTest)
  -- The running test can be nil or a number.
  if uiRunningTest==nil or tonumber(uiRunningTest)~=nil then
    -- Did the running test change?
    local fChanged = (self.uiRunningTest~=uiRunningTest)
    if fChanged==true then
      self.uiRunningTest = uiRunningTest

      self:__sendState()
    end
  end
end



function WebUiBuffer:setTestState(strTestState)
  -- The test state must be a string.
  if type(strTestState)=='string' then
    -- This works only if a test is running.
    local uiRunningTest = self.uiRunningTest
    if uiRunningTest~=nil then
      local strOldState = self.astrTestStati[uiRunningTest]
      -- Did something change?
      local fChanged = (strOldState~=strTestState)
      if fChanged==true then
        self.astrTestStati[uiRunningTest] = strTestState
        self:__sendState()
      end
    end
  end
end



function WebUiBuffer:clearLog()
  -- Clear the log buffer.
  self.astrLogMessages = {}
  self.uiSyncedLogIndex = 0
end



function WebUiBuffer:__sendState()
  -- Push the values to the UI if there is a connection.
  local tConnection = self.tActiveConnection
  if tConnection~=nil then
    local tRunningTest = self.uiRunningTest
    if tRunningTest~=nil then
      tRunningTest = tRunningTest - 1
    end

    local atTests = {}
    for uiIdx, strName in ipairs(self.astrTestNames) do
      local tAttr = atTests[uiIdx]
      if tAttr==nil then
        tAttr = {}
        atTests[uiIdx] = tAttr
      end
      tAttr.name = strName
    end
    for uiIdx, strState in ipairs(self.astrTestStati) do
      local tAttr = atTests[uiIdx]
      if tAttr==nil then
        tAttr = {}
        atTests[uiIdx] = tAttr
      end
      tAttr.state = strState
    end

    local tPersistence = {
      app = self.tPersistenceApp,
      interaction = self.tPersistenceInteraction
    }

    local tMessage = {
      id = 'State',
      title = self.strTitle,
      subtitle = self.strSubTitle,
      hasSerial = self.fHasSerial,
      docs = self.atDocuments,
      interaction = self.strInteractionJsx,
      interaction_data = self.strInteractionData,
      currentSerial = self.uiCurrentSerial,
      runningTest = tRunningTest,
      tests = atTests,
      persistence = tPersistence
    }
    local strJson = self.json.encode(tMessage)
    tConnection:write(strJson)
  end
end



--- Set the persistence data.
-- The incoming data can have an "app" and an "interaction" part.
-- Both are optional, as the application and the interaction send their persistence data individually without adding
-- the other part. This means that a missing "app" or "interaction" part must not clear the stored persistence data.
function WebUiBuffer:__setPersistenceData(tPersistence)
  local tPersistenceApp = tPersistence.app
  if tPersistenceApp~=nil then
    self.tPersistenceApp = tPersistenceApp
  end

  local tPersistenceInteraction = tPersistence.interaction
  if tPersistenceInteraction~=nil then
    self.tPersistenceInteraction = tPersistenceInteraction
  end
end



function WebUiBuffer:__connectionOnReceive(tConnection, err, strMessage, opcode)
  local tLog = self.tLog

  if err then
    tLog.error('Server read error, closing the connection: %s', tostring(err))
    self.tActiveConnection = nil
    self.uiSyncedLogIndex = 0
    self.tLogTimer:stop()
    self.tHeartbeatTimer:stop()
    self:__sendCurrentPeerName()
    return tConnection:close()
  else
    tLog.debug('__connectionOnReceive: %s %s', tostring(tConnection), tostring(self.tActiveConnection))
    tLog.debug('JSON: "%s"', strMessage)

    local tTester = self.tTester

    local tJson, uiPos, strJsonErr = self.json.decode(strMessage)
    if tJson==nil then
      tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
    else
      local strId = tJson.id
      if strId==nil then
        tLog.error('Ignoring invalid message without "id".')
      else
        if strId=='ReqInit' then
          self:__sendState()

        elseif strId=='RspInteraction' then
          if tTester~=nil then
            tTester:setInteractionResponse(strMessage)
          end

        elseif strId=='Cancel' then
          if tTester~=nil then
            tTester:onCancel()
          end

        elseif strId=='Persist' then
          self:__setPersistenceData(tJson.data)

        else
          print('Unknown message ID received.')
          self.pl.pretty.dump(tJson)
        end
      end
    end
  end
end



function WebUiBuffer:__connectionHandshake(tConnection, err, protocol)
  local tLog = self.tLog

  if err then
    tLog.error('Server handshake error: %s', tostring(err))
    self.tActiveConnection = nil
    self.uiSyncedLogIndex = 0
    self.tLogTimer:stop()
    self.tHeartbeatTimer:stop()
    return tConnection:close()

  elseif self.tActiveConnection~=nil then
    tLog.notice('Not accepting a second conncetion.')
    return tConnection:close()

  else
    tLog.info('New server connection: %s', tostring(protocol))
    self.tActiveConnection = tConnection

    self:__sendCurrentPeerName()

    local this = self
    self.tLogTimer:start(self.uiLogTimerMs, function(tTimer) this:__onLogTimer(tTimer) end)

    self.tHeartbeatTimer:start(
      self.uiHeartbeatIntervalMs,
      function(tTimer)
        this:__onHeartbeatTimer(tTimer)
      end
    )

    tConnection:start_read(function(tConnection, err, strMessage, opcode) this:__connectionOnReceive(tConnection, err, strMessage, opcode) end)
  end
end



function WebUiBuffer:__onAccept(tSomething, tError)
  if tError then
    self.tLog.error("Server listen: %s", tError)
    self.tActiveConnection = nil
    return self.tServer:close()
  else
    local cli = self.tServer:accept()
    local this = self
    cli:handshake(function(tConnection, err, protocol) this:__connectionHandshake(tConnection, err, protocol) end)
  end
end



function WebUiBuffer:__onCreate(tSomething, tError)
  if tError then
    self.tLog.error("Server error: %s", tostring(tError))
    self.tActiveConnection = nil
    self.uiSyncedLogIndex = 0
    return self.tServer:close()
  else
    local this = self
    self.tServer:listen(function(tSomething, tError) this:__onAccept(tSomething, tError) end)
  end
end



function WebUiBuffer:setTester(tTester)
  self.tTester = tTester
end



function WebUiBuffer:start()
  self.tServer = self.ws.new(
    {
      auto_ping_response = true
    }
  )

  local this = self
  self.tServer:bind(self.strWebsocketURL, self.strWebsocketProtocol, function(tSomething, tError) this:__onCreate(tSomething, tError) end)
end



return WebUiBuffer
