local pl = require'pl.import_into'()
local uv  = require"lluv"
uv.poll_zmq = require "lluv.poll_zmq"

-- This is the port for the websocket.
local usWebsocketPort = 12345

-- This number is used as the serial number in the SSDP responses.
local ulSystemSerial = 4321

-- This is the port for the web server.
local usWebserverPort = 9090

-- Set the logger level from the command line options.
local strLogLevel = 'debug'
local cLogWriter = require 'log.writer.filter'.new(
  strLogLevel,
  require 'log.writer.console'.new()
)
local cLogWriterSystem = require 'log.writer.prefix'.new('[System] ', cLogWriter)
local tLog = require "log".new(
  -- maximum log level
  "trace",
  cLogWriterSystem,
  -- Formatter
  require "log.formatter.format".new()
)
tLog.info('Start')


------------------------------------------------------------------------------
--
-- Try to read the package file.
--
local cPackageFile = require 'package_file'
local strVersion, strVcsVersion = cPackageFile.read(tLog)


------------------------------------------------------------------------------
--
--  Try to read the configuration file.
--
local cConfigurationFile = require 'configuration_file'
local tConfiguration = cConfigurationFile.read(tLog)


------------------------------------------------------------------------------
--
-- Select an interface to bind to.
-- For now just take the first interface with an IP.
--

local tInterfaces = uv.interface_addresses()
if tInterfaces==nil then
  error('Failed to get the list of ethernet interfaces.')
end
local strInterfaceAddress = nil
for uiCnt, tIf in ipairs(tInterfaces) do
  -- Select the first interface of the type "inet" which is not internal.
  if tIf.family=='inet' and tIf.internal==false then
    strInterfaceAddress = tIf.address
    tLog.info('Seleceting interface "%s" with address %s.', tIf.name, strInterfaceAddress)
    break
  end
end
if strInterfaceAddress==nil then
  error('No suitable interface found.')
end


------------------------------------------------------------------------------
--
-- Start the SSDP server.
--
local strDescriptionLocation = string.format('http://%s:%s/description.xml', strInterfaceAddress, usWebserverPort)
local SSDP = require 'ssdp'
local tSsdp = SSDP(tLog, strDescriptionLocation, strVersion)
local strSSDP_UUID = tSsdp:setSystemUuid()
tSsdp:run()


-- Read a test description.
-- TODO: For now there is only one test.
local strTestXmlFile = pl.path.join(tConfiguration.tests_folder, 'tests.xml')


local TestDescription = require 'test_description'
local tTestDescription = TestDescription(tLog)
local tResult = tTestDescription:parse(strTestXmlFile)
if tResult~=true then
  tLog.error('Failed to parse the test description.')
  error('Invalid test description.')
end

-- Create the kafka log consumer.
local tLogKafka = require 'log-kafka'(tLog)
-- Register this test station.
tLogKafka:registerInstance{
  ip = strInterfaceAddress,
  port = usWebserverPort,
  ssdp = {
    name = tConfiguration.ssdp_name,
    uuid = strSSDP_UUID
  },
  test = {
    title = tTestDescription:getTitle(),
    subtitle = tTestDescription:getSubtitle()
  }
}

local WebUiBuffer = require 'webui_buffer'
local webui_buffer = WebUiBuffer(tLog, usWebsocketPort)
webui_buffer:setTitle(tTestDescription:getTitle(), tTestDescription:getSubtitle())
local tLogTest = webui_buffer:getLogTarget()
webui_buffer:start()

-- Create the server process.
local strLuaInterpreter = uv.exepath()
tLog.debug('LUA interpreter: %s', strLuaInterpreter)
local ProcessKeepalive = require 'process_keepalive'
local astrServerArgs = {
  'server.lua',
  tostring(usWebsocketPort),
  strSSDP_UUID,
  tostring(ulSystemSerial),
  '--webserver-address',
  strInterfaceAddress,
  '--webserver-port',
  tostring(usWebserverPort)
}
local tServerProc = ProcessKeepalive(tLog, strLuaInterpreter, astrServerArgs, 3)

-- Create a new test controller.
local TestController = require 'test_controller'
local tTestController = TestController(tLog, tLogTest, strLuaInterpreter, tConfiguration.tests_folder)
tTestController:setBuffer(webui_buffer)


tServerProc:run()
tTestController:run()


local function OnCancelAll()
  print('Cancel pressed!')
  tServerProc:shutdown()
  tTestProc:shutdown()
end
uv.signal():start(uv.SIGINT, OnCancelAll)


uv.run(debug.traceback)
