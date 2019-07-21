require 'muhkuh_cli_init'

local pl = require'pl.import_into'()
local json = require 'dkjson'
local zmq = require 'lzmq'
local TestDescription = require 'test_description'

-- Register the tester as a global module.
_G.tester = require 'tester_webgui'

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

------------------------------------------------------------------------------

local function setInteraction(strFilename, atReplace)
  local tResult

  -- Read the interaction code.
  local strJsxTemplate, strErr = pl.file.read(strFilename)
  if strJsxTemplate==nil then
    tLogSystem.error('Failed to read JSX from "%s": %s', strFilename, strErr)
  else
    local strJsx

    -- Replace something?
    if atReplace==nil then
      strJsx = strJsxTemplate
    else
      strJsx = string.gsub(strJsxTemplate, '@([%w_]+)@', atReplace)
    end

    m_zmqSocket:send(string.format('INT%s', strJsx))

    tResult = true
  end

  return tResult
end



local function getInteractionResponse()
  local strResponse

  repeat
    local strMessage = m_zmqSocket:recv()
    strResponse = string.match(strMessage, '^RSP(.*)')
    if strResponse==nil then
      tLogSystem.debug('Ignoring invalid response: %s', strMessage)
    end
  until strResponse~=nil

  return strResponse
end



local function setInteractionGetJson(strFilename, atReplace)
  local tResult = setInteraction(strFilename, atReplace)
  if tResult==true then
    local strResponseRaw = getInteractionResponse()
    if strResponseRaw~=nil then
      local tJson, uiPos, strJsonErr = json.decode(strResponseRaw)
      if tJson==nil then
        tLogSystem.error('JSON Error: %d %s', uiPos, strJsonErr)
      else
        tLogSystem.debug('JSON OK!')
        tResult = tJson
      end
    end
  end

  return tResult
end



local function clearInteraction()
  m_zmqSocket:send('INT')
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



local function run_tests(atModules, tTestDescription)
  -- Run all enabled modules with their parameter.
  local fTestResult = true

  local astrTestNames = tTestDescription:getTestNames()
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  for uiTestIndex = 1, uiNumberOfTests do
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

      -- Execute the test code. Write a stack trace to the debug logger if the test case crashes.
      fStatus, tResult = xpcall(function() tModule:run() end, function(tErr) tLogSystem.debug(debug.traceback()) return tErr end)
      tLogSystem.info('Testcase %d (%s) finished.', uiTestIndex, strTestCaseName)
      if not fStatus then
        local strError
        if tResult~=nil then
          strError = tostring(tResult)
        else
          strError = 'No error message.'
        end
        tLogSystem.error('Error running the test: %s', strError)

        fTestResult = false
        break
      end
    end
  end

  -- TODO: Close the connection to the netX.
--  close_netx_connection()

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
  local astrTestNames = tTestDescription:getTestNames()
  -- Get all test names in the style of a table.
  local astrQuotedTests = {}
  for _, strName in ipairs(astrTestNames) do
    table.insert(astrQuotedTests, string.format('"%s"', strName))
  end
  local strTestNames = table.concat(astrQuotedTests, ', ')

  -- Now set a new interaction.

  -- Read the first interaction code.
  tResult = setInteractionGetJson('jsx/select_serial_range_and_tests.jsx', { ['TEST_NAMES']=strTestNames })
  if tResult==nil then
    tLogSystem.fatal('Failed to read interaction.')
  else
    local tJson = tResult
    pl.pretty.dump(tJson)
    clearInteraction()

    -- Loop over all serials.
    -- ulSerialFirst is the first serial to test
    -- ulSerialLast is the last serial to test
    local ulSerialFirst = tonumber(tJson.serialFirst)
    local ulSerialLast = ulSerialFirst + tonumber(tJson.numberOfBoards) - 1
    tLogSystem.info('Running over the serials [%d,%d] .', ulSerialFirst, ulSerialLast)
    for ulSerialCurrent = ulSerialFirst, ulSerialLast do
      tLogSystem.info('Testing serial %d .', ulSerialCurrent)

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
