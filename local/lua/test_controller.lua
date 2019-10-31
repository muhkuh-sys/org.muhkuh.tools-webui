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
end



function TestController:setBuffer(tBuffer)
  self.m_buffer = tBuffer
end



function TestController:__setStartPage()
  local tBuffer = self.m_buffer

  -- Clear all fields in the tester header.
  tBuffer:setSerials(true, nil, nil)
  tBuffer:setTestNames({})
  tBuffer:setCurrentSerial(nil)
  tBuffer:setRunningTest(nil)

  -- Register the test controller to get the interaction responses.
  tBuffer:setTester(self)

  -- Read the first interaction.
  local strFilename = 'jsx/test_start.jsx'
  local strJsx, strErr = self.pl.file.read(strFilename)
  if strJsx==nil then
    self.tLog.error('Failed to read JSX from "%s": %s', strFilename, strErr)
  else
    self.m_buffer:setInteraction(strJsx)
  end
end



function TestController:run()
  self:__setStartPage()
end



function TestController:setInteractionResponse(strMessage)
  local tLog = self.tLog
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

      -- Create a new ZMQ process.
      local tTestProc = self.ProcessZmq(tLog, self.tLogTest, self.strLuaInterpreter, {'test_system.lua', '${ZMQPORT}'}, self.strTestPath)
      -- Connect the buffer to the test process.
      tTestProc:setBuffer(tBuffer)
      -- Register the test process as the new consumer of interaction responses.
      tBuffer:setTester(tTestProc)

      -- Run the test and set this as the consumer for the terminate message.
      tTestProc:run(self.onTestTerminate, self)

      self.m_testProcess = tTestProc
    end
  end
end



function TestController:onTestTerminate()
  -- The test finished.
  self:__setStartPage()
end


return TestController
