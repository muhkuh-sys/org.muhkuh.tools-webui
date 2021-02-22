local class = require 'pl.class'
local TestController = class()

function TestController:_init(tLog, tLogTest, strLuaInterpreter, strTestPath)
  self.tLog = tLog
  self.tLogTest = tLogTest

  self.strLuaInterpreter = strLuaInterpreter
  self.strTestPath = strTestPath

  self.json = require 'dkjson'
  self.pl = require'pl.import_into'()
  self.ProcessZmq = require 'process_zmq'

  self.m_buffer = nil
  self.m_testProcess = nil
  self.m_strPeerName = nil

  self.m_logConsumer = nil

  self.m_strStartPageOk = 'jsx/test_start.jsx'
  self.m_strStartPageNoTestDescription = 'jsx/test_error_testdescription.jsx'
end



function TestController:setBuffer(tBuffer)
  self.m_buffer = tBuffer
end



function TestController:setLogConsumer(tLogConsumer)
  self.m_logConsumer = tLogConsumer
end



function TestController:__setStartPage(strFilename)
  local tBuffer = self.m_buffer

  -- Clear all fields in the tester header.
  tBuffer:setSerials(true, nil, nil)
  tBuffer:setTestNames({})
  tBuffer:setCurrentSerial(nil)
  tBuffer:setRunningTest(nil)

  -- Register the test controller to get the interaction responses.
  tBuffer:setTester(self)

  -- Read the first interaction.
  local strJsx, strErr = self.pl.file.read(strFilename)
  if strJsx==nil then
    self.tLog.error('Failed to read JSX from "%s": %s', strFilename, strErr)
  else
    self.m_buffer:setInteraction(strJsx)
  end
end



function TestController:run(bHaveValidTestDescription)
  local strFilename = self.m_strStartPageOk
  if bHaveValidTestDescription~=true then
    strFilename = self.m_strStartPageNoTestDescription
  end

  self:__setStartPage(strFilename)
end



function TestController:onPeerNameChanged(strPeerName)
  self.m_strPeerName = strPeerName
end



function TestController:setInteractionResponse(strMessage)
  local tLog = self.tLog
  local pl = self.pl
  tLog.debug('Received message: %s', strMessage)

  local tJson, uiPos, strJsonErr = self.json.decode(strMessage)
  if tJson==nil then
    tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
  else
    local strButton = tJson.button
    if strButton==nil then
      tLog.error('Invalid startup response, "button" missing: %s', strMessage)
    elseif strButton~='start' then
      tLog.error('Invalid startup response, "button" = "%s".', strButton)
    else
      -- The "start" button was pressed.
      local tBuffer = self.m_buffer

      -- Clear the interaction.
      tBuffer:setInteraction()

      -- Clear the log.
      tBuffer:clearLog()

      -- Detect the LUA interpreter. Try LUA5.4 first, then fallback to LUA5.1 .
      local strExeSuffix = ''
      if pl.path.is_windows then
        strExeSuffix = '.exe'
      end
      local strInterpreterPath = pl.path.abspath(pl.path.join(self.strTestPath, 'lua5.4'..strExeSuffix))
      tLog.debug('Looking for the LUA5.4 interpreter in "%s".', strInterpreterPath)
      if pl.path.exists(strInterpreterPath)~=strInterpreterPath then
        strInterpreterPath = pl.path.abspath(pl.path.join(self.strTestPath, 'lua5.1'..strExeSuffix))
        tLog.debug('Looking for the LUA5.1 interpreter in "%s".', strInterpreterPath)
        if pl.path.exists(strInterpreterPath)~=strInterpreterPath then
          tLog.error('No LUA interpreter found.')
          strInterpreterPath = nil
        end
      end
      if strInterpreterPath~=nil then
        -- Create a new ZMQ process.
        local tTestProc = self.ProcessZmq(tLog, self.tLogTest, strInterpreterPath, {'test_system.lua', '${ZMQPORT}'}, self.strTestPath)
        -- Connect the buffer to the test process.
        tTestProc:setBuffer(tBuffer)
        -- Register the test process as the new consumer of interaction responses.
        tBuffer:setTester(tTestProc)
        -- Set the current peer name.
        tTestProc:onPeerNameChanged(self.m_strPeerName)
        -- Set the current log consumer.
        tTestProc:setLogConsumer(self.m_logConsumer)

        -- Run the test and set this as the consumer for the terminate message.
        tTestProc:run(self.onTestTerminate, self)

        self.m_testProcess = tTestProc
      end
    end
  end
end



function TestController:onTestTerminate()
  -- The test finished.
  self:__setStartPage(self.m_strStartPageOk)
end


function TestController:onCancel()
  local tLog = self.tLog

  tLog.info('Cancel: no test running.')
end



return TestController
