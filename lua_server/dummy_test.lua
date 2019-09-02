-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

require 'muhkuh_cli_init'

local pl = require'pl.import_into'()
local json = require 'dkjson'
local zmq = require 'lzmq'
local TestDescription = require 'test_description'

-- Register the tester as a global module.
local cTester = require 'tester_webgui'
_G.tester = cTester()

-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

local usServerPort = tonumber(arg[1])

m_zmqPort = usServerPort
strAddress = string.format('tcp://127.0.0.1:%d', usServerPort)
print(string.format("Connecting to %s", strAddress))

-- Create the 0MQ context.
local zmq = require 'lzmq'
local tZContext, strError = zmq.context()
if tZContext==nil then
  error('Failed to create ZMQ context: ' .. tostring(strError))
end
m_zmqContext = tZContext

-- Create the socket.
local tZSocket, strError = tZContext:socket(zmq.PAIR)
if tZSocket==nil then
  error('Failed to create ZMQ socket: ' .. tostring(strError))
end

-- Connect the socket to the server.
local tResult, strError = tZSocket:connect(strAddress)
if tResult==nil then
  error('Failed to connect the socket: ' .. tostring(strError))
end
m_zmqSocket = tZSocket
tester:setSocket(m_zmqSocket)

print(string.format('0MQ socket connected to tcp://127.0.0.1:%d', usServerPort))


------------------------------------------------------------------------------
-- Now create the logger. It sends the data to the ZMQ socket.
-- It does not use the formatter function 'fmt' or the date 'now'. This is
-- done at the server side.
local tLogWriterFn = function(fmt, msg, lvl, now)
  m_zmqSocket:send(string.format('LOG%d,%s', lvl, msg))
end

-- This is the default log level. Note that the filtering should happen in
-- the GUI and all messages which are already filtered with this level here
-- will never be available in the GUI.
local strLogLevel = 'debug'

-- Create a new log target with "SYSTEM" prefix.
local tLogWriterSystem = require 'log.writer.prefix'.new('[System] ', tLogWriterFn)
local tLogSystem = require "log".new(
  strLogLevel,
  tLogWriterSystem,
  require "log.formatter.format".new()
)
tester:setLog(tLogSystem)

------------------------------------------------------------------------------

local function sendTitles(strTitle, strSubtitle)
  if strTitle==nil then
    strTitle = 'No title'
  else
    strTitle = tostring(strTitle)
  end
  if strSubtitle==nil then
    strSubtitle = 'No subtitle'
  else
    strSubtitle = tostring(strSubtitle)
  end

  local tData = {
    title=strTitle,
    subtitle=strSubtitle
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('TTL'..strJson)
end



local function sendSerials(ulSerialFirst, ulSerialLast)
  local tData = {
    hasSerial=true,
    firstSerial=ulSerialFirst,
    lastSerial=ulSerialLast
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('SER'..strJson)
end



local function sendTestNames(astrTestNames)
  local strJson = json.encode(astrTestNames)
  m_zmqSocket:send('NAM'..strJson)
end



local function sendTestStati(astrTestStati)
  local strJson = json.encode(astrTestStati)
  m_zmqSocket:send('STA'..strJson)
end



local function sendCurrentSerial(uiCurrentSerial)
  local tData = {
    currentSerial=uiCurrentSerial
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('CUR'..strJson)
end



local function sendRunningTest(uiRunningTest)
  local tData = {
    runningTest=uiRunningTest
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('RUN'..strJson)
end



local function sendTestState(strTestState)
  local tData = {
    testState=strTestState
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('RES'..strJson)
end



local function load_test_module(uiTestIndex)
  local strModuleName = string.format("test%02d", uiTestIndex)
  tLogSystem.debug('Reading module for test %d from %s .', uiTestIndex, strModuleName)

  local tClass = require(strModuleName)
  local tModule = tClass(uiTestIndex, tLogWriterFn, strLogLevel)
  return tModule
end



local function collect_testcases(tTestDescription, aActiveTests)
  local tResult

  -- Get the number of tests from the test description.
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  -- Get the number of tests specified in the GUI response.
  local uiTestsFromGui = table.maxn(aActiveTests)
  -- Both test counts must match or there is something wrong.
  if uiNumberOfTests~=uiTestsFromGui then
    tLogSystem.error('The test description specifies %d tests, but the selection covers %d tests.', uiNumberOfTests, uiTestsFromGui)
  else
    local aModules = {}
    local astrTestNames = tTestDescription:getTestNames()
    local fAllModulesOk = true
    for uiTestIndex, fTestCaseIsActive in ipairs(aActiveTests) do
      local strTestName = astrTestNames[uiTestIndex]
      -- Only process test cases which are active.
      if fTestCaseIsActive==true then
        local fOk, tValue = pcall(load_test_module, uiTestIndex)
        if fOk~=true then
          tLogSystem.error('Failed to load the module for test case %d: %s', uiTestIndex, tostring(tValue))
          fAllModulesOk = false
        else
          aModules[uiTestIndex] = tValue
        end
      else
        tLogSystem.debug('Skipping deactivated test %02d:%s .', uiTestIndex, strTestName)
      end
    end

    if fAllModulesOk==true then
      tResult = aModules
    end
  end

  return tResult
end



local function apply_parameters(atModules, tTestDescription, ulSerial)
  local tResult = true

  local astrTestNames = tTestDescription:getTestNames()

  -- Loop over all active tests and apply the tests from the XML.
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  for uiTestIndex = 1, uiNumberOfTests do
    local tModule = atModules[uiTestIndex]
    local strTestCaseName = astrTestNames[uiTestIndex]

    if tModule==nil then
      tLogSystem.debug('Skipping deactivated test %02d:%s .', uiTestIndex, strTestCaseName)
    else
      -- Get the parameters for the module.
      local atParametersModule = tModule.atParameter

      -- Get the parameters from the XML.
      local atParametersXml = tTestDescription:getTestCaseParameters(uiTestIndex)
      for _, tParameter in ipairs(atParametersXml) do
        local strParameterName = tParameter.name
        local strParameterValue = tParameter.value
        local strParameterConnection = tParameter.connection

        -- Does the parameter exist?
        tParameter = atParametersModule[strParameterName]
        if tParameter==nil then
          tLogSystem.fatal('The parameter "%s" does not exist in test case %d (%s).', strParameterName, uiTestIndex, strTestCaseName)
          tResult = nil
          break
        else
          if strParameterValue~=nil then
            -- This is a direct assignment of a value.
            tParameter:set(strParameterValue)
          elseif strParameterConnection~=nil then
            -- This is a connection to another value.
            -- For now accept only the serial.
            if strParameterConnection=='system:serial' then
              strParameterValue = tostring(ulSerial)
              tParameter:set(strParameterValue)
            else
              tLogSystem.fatal('The connection target "%s" is unknown.', strParameterConnection)
              tResult = nil
              break
            end
          end
        end
      end
    end
  end

  return tResult
end



local function check_parameters(atModules, tTestDescription)
  -- Check all parameters.
  local fParametersOk = true

  local astrTestNames = tTestDescription:getTestNames()
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  for uiTestIndex = 1, uiNumberOfTests do
    local tModule = atModules[uiTestIndex]
    local strTestCaseName = astrTestNames[uiTestIndex]
    if tModule==nil then
      tLogSystem.debug('Skipping deactivated test %02d:%s .', uiTestIndex, strTestCaseName)
    else
      for _, tParameter in ipairs(tModule.CFG_aParameterDefinitions) do
        -- Validate the parameter.
        local fValid, strError = tParameter:validate()
        if fValid==false then
          tLogSystem.fatal('The parameter %02d:%s is invalid: %s', uiTestCase, tParameter.strName, strError)
          fParametersOk = nil
        end
      end
    end
  end

  if fParametersOk~=true then
    tLogSystem.fatal('One or more parameters were invalid. Not running the tests!')
  end

  return fParametersOk
end



local function run_action(strAction)
  if strAction~=nil then
    -- If the action is a JSX file, this is a static GUI element.
    if string.sub(strAction, -4)=='.jsx' then
      local tResult = tester:setInteraction(strAction)
      if tResult==nil then
        error('Failed to load the JSX.')
      end
    elseif string.sub(strAction, -4)=='.lua' then
      error('LUA actions are not yet implemented.')
    else
      error('Unknown action: ' .. tostring(strAction))
    end
  end
end



local function run_tests(atModules, tTestDescription)
  -- Run all enabled modules with their parameter.
  local fTestResult = true

  local astrTestNames = tTestDescription:getTestNames()
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  for uiTestIndex = 1, uiNumberOfTests do
    repeat
      local fExitTestCase = true

      -- Get the module for the test index.
      local tModule = atModules[uiTestIndex]
      local strTestCaseName = astrTestNames[uiTestIndex]
      if tModule==nil then
        tLogSystem.info('Not running deactivated test case %02d (%s).', uiTestIndex, strTestCaseName)
      else
        tLogSystem.info('Running testcase %d (%s).', uiTestIndex, strTestCaseName)

        -- Get the parameters for the module.
        local atParameters = tModule.atParameter
        if atParameters==nil then
          atParameters = {}
        end

        -- Show all parameters for the test case.
        tLogSystem.info("__/Parameters/________________________________________________________________")
        if pl.tablex.size(atParameters)==0 then
          tLogSystem.info('Testcase %d (%s) has no parameter.', uiTestIndex, strTestCaseName)
        else
          tLogSystem.info('Parameters for testcase %d (%s):', uiTestIndex, strTestCaseName)
          for _, tParameter in pairs(atParameters) do
            tLogSystem.info('  %02d:%s = %s', uiTestIndex, tParameter.strName, tParameter:get_pretty())
          end
        end
        tLogSystem.info("______________________________________________________________________________")

        sendRunningTest(uiTestIndex)

        -- Run a pre action if present.
        local strAction = tTestDescription:getTestCaseActionPre(uiTestIndex)
        run_action(strAction)

        -- Execute the test code. Write a stack trace to the debug logger if the test case crashes.
        fStatus, tResult = xpcall(function() tModule:run() end, function(tErr) tLogSystem.debug(debug.traceback()) return tErr end)
        tLogSystem.info('Testcase %d (%s) finished.', uiTestIndex, strTestCaseName)

        -- Send the result to the GUI.
        local strTestState = 'error'
        if fStatus==true then
          strTestState = 'ok'
        end
        sendTestState(strTestState)
        sendRunningTest(nil)

        if not fStatus then
          local strError
          if tResult~=nil then
            strError = tostring(tResult)
          else
            strError = 'No error message.'
          end
          tLogSystem.error('Error running the test: %s', strError)

          local tResult = tester:setInteractionGetJson('jsx/test_failed.jsx', {})
          if tResult==nil then
            tLogSystem.fatal('Failed to read interaction.')
          else
            local tJson = tResult
            pl.pretty.dump(tJson)
            tester:clearInteraction()

            if tJson.button=='again' then
              fExitTestCase = false
            else
              fTestResult = false
            end
          end
        else
          -- Run a post action if present.
          local strAction = tTestDescription:getTestCaseActionPost(uiTestIndex)
          run_action(strAction)
        end
      end
    until fExitTestCase==true

    if fTestResult~=true then
      break
    end
  end

  -- Close the connection to the netX.
  tester:closeCommonPlugin()

  -- Print the result in huge letters.
  if fTestResult==true then
    tLogSystem.info('***************************************')
    tLogSystem.info('*                                     *')
    tLogSystem.info('* ######## ########  ######  ######## *')
    tLogSystem.info('*    ##    ##       ##    ##    ##    *')
    tLogSystem.info('*    ##    ##       ##          ##    *')
    tLogSystem.info('*    ##    ######    ######     ##    *')
    tLogSystem.info('*    ##    ##             ##    ##    *')
    tLogSystem.info('*    ##    ##       ##    ##    ##    *')
    tLogSystem.info('*    ##    ########  ######     ##    *')
    tLogSystem.info('*                                     *')
    tLogSystem.info('*          #######  ##    ##          *')
    tLogSystem.info('*         ##     ## ##   ##           *')
    tLogSystem.info('*         ##     ## ##  ##            *')
    tLogSystem.info('*         ##     ## #####             *')
    tLogSystem.info('*         ##     ## ##  ##            *')
    tLogSystem.info('*         ##     ## ##   ##           *')
    tLogSystem.info('*          #######  ##    ##          *')
    tLogSystem.info('*                                     *')
    tLogSystem.info('***************************************')

    local tResult = tester:setInteractionGetJson('jsx/test_ok.jsx', {})
    if tResult==nil then
      tLogSystem.fatal('Failed to read interaction.')
    else
      local tJson = tResult
      pl.pretty.dump(tJson)
      tester:clearInteraction()

--[[      if tJson.button=='again' then
              fExitTestCase = false
            else
              fTestResult = false
            end
          end
--]]
    end
  else
    tLogSystem.error('*******************************************************')
    tLogSystem.error('*                                                     *')
    tLogSystem.error('*         ######## ########  ######  ########         *')
    tLogSystem.error('*            ##    ##       ##    ##    ##            *')
    tLogSystem.error('*            ##    ##       ##          ##            *')
    tLogSystem.error('*            ##    ######    ######     ##            *')
    tLogSystem.error('*            ##    ##             ##    ##            *')
    tLogSystem.error('*            ##    ##       ##    ##    ##            *')
    tLogSystem.error('*            ##    ########  ######     ##            *')
    tLogSystem.error('*                                                     *')
    tLogSystem.error('* ########    ###    #### ##       ######## ########  *')
    tLogSystem.error('* ##         ## ##    ##  ##       ##       ##     ## *')
    tLogSystem.error('* ##        ##   ##   ##  ##       ##       ##     ## *')
    tLogSystem.error('* ######   ##     ##  ##  ##       ######   ##     ## *')
    tLogSystem.error('* ##       #########  ##  ##       ##       ##     ## *')
    tLogSystem.error('* ##       ##     ##  ##  ##       ##       ##     ## *')
    tLogSystem.error('* ##       ##     ## #### ######## ######## ########  *')
    tLogSystem.error('*                                                     *')
    tLogSystem.error('*******************************************************')
  end

  return fTestResult
end



-- Read the test.xml file.
local tTestDescription = TestDescription(tLogSystem)
local tResult = tTestDescription:parse('tests.xml')
if tResult~=true then
  tLogSystem.error('Failed to parse the test description.')
else
  sendTitles(tTestDescription:getTitle(), tTestDescription:getSubtitle())

  local astrTestNames = tTestDescription:getTestNames()
  -- Get all test names in the style of a table.
  local astrQuotedTests = {}
  for _, strName in ipairs(astrTestNames) do
    table.insert(astrQuotedTests, string.format('"%s"', strName))
  end
  local strTestNames = table.concat(astrQuotedTests, ', ')

  -- Now set a new interaction.

  -- Read the first interaction code.
  tResult = tester:setInteractionGetJson('jsx/select_serial_range_and_tests.jsx', { ['TEST_NAMES']=strTestNames })
  if tResult==nil then
    tLogSystem.fatal('Failed to read interaction.')
  else
    local tJson = tResult
    pl.pretty.dump(tJson)
    tester:clearInteraction()

    -- Loop over all serials.
    -- ulSerialFirst is the first serial to test
    -- ulSerialLast is the last serial to test
    local ulSerialFirst = tonumber(tJson.serialFirst)
    local ulSerialLast = ulSerialFirst + tonumber(tJson.numberOfBoards) - 1
    tLogSystem.info('Running over the serials [%d,%d] .', ulSerialFirst, ulSerialLast)

    -- Build the initial test states.
    local astrStati = {}
    for _, fIsEnabled in ipairs(tJson.activeTests) do
      local strState = 'idle'
      if fIsEnabled==false then
        strState = 'disabled'
      end
      table.insert(astrStati, strState)
    end

    -- Set the serial numbers.
    sendSerials(ulSerialFirst, ulSerialLast)
    sendTestNames(tTestDescription:getTestNames())
    sendTestStati(astrStati)

    for ulSerialCurrent = ulSerialFirst, ulSerialLast do
      tLogSystem.info('Testing serial %d .', ulSerialCurrent)
      sendCurrentSerial(ulSerialCurrent)

      tResult = collect_testcases(tTestDescription, tJson.activeTests)
      if tResult==nil then
        tLogSystem.fatal('Failed to collect all test cases.')
      else
        local atModules = tResult

        tResult = apply_parameters(atModules, tTestDescription, ulSerialCurrent)
        if tResult==nil then
          tLogSystem.fatal('Failed to apply the parameters.')
        else
          tResult = check_parameters(atModules, tTestDescription)
          if tResult==nil then
            tLogSystem.fatal('Failed to check the parameters.')
          else
            tResult = run_tests(atModules, tTestDescription)
          end
        end
      end
    end

    -- TODO: Show a test result (OK/FAILED) and buttons to proceed to the next board or run the test on the same board again.
--    sendCurrentSerial(nil)
  end
end

if m_zmqSocket~=nil then
  if m_zmqSocket:closed()==false then
    m_zmqSocket:close()
  end
  m_zmqSocket = nil
end

if m_zmqContext~=nil then
  m_zmqContext:destroy()
  m_zmqContext = nil
end
