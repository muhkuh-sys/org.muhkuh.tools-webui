require 'muhkuh_server_init'

local pl = require'pl.import_into'()
local uv  = require"lluv"
uv.poll_zmq = require "lluv.poll_zmq"

-- This is the port for the websocket.
local usWebsocketPort = 12345

-- This number is used as the serial number in the SSDP responses.
local ulSystemSerial = 4321

-- This is the port for the web server.
local usWebserverPort = 9090

-- This is the complete path to the test folder.
local strTestPath = pl.path.abspath('test')
local strTestXmlFile = pl.path.join(strTestPath, 'tests.xml')

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
local strPackageInfoFile = pl.path.join('.jonchki', 'package.txt')
local strPackageInfo, strError = pl.utils.readfile(strPackageInfoFile, false)
-- Default to version "unknown".
local strVersion = 'unknown'
local strVcsVersion = 'unknown'
if strPackageInfo~=nil then
  strVersion = string.match(strPackageInfo, 'PACKAGE_VERSION=([0-9.]+)')
  strVcsVersion = string.match(strPackageInfo, 'PACKAGE_VCS_ID=([a-zA-Z0-9+]+)')
end

-- TODO: Do not overwrite this once there is a package file.
strVersion = '1.0'

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

local strHtmlLocation = string.format('http://%s:%s/index.html', strInterfaceAddress, usWebserverPort)
local SSDP = require 'ssdp'
local tSsdp = SSDP(tLog, strHtmlLocation, strVersion)
local strSSDP_UUID = tSsdp:setSystemUuid()
tSsdp:run()

local TestDescription = require 'test_description'
local tTestDescription = TestDescription(tLog)
local tResult = tTestDescription:parse(strTestXmlFile)
if tResult~=true then
  tLog.error('Failed to parse the test description.')
  error('Invalid test description.')
end

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
local tTestController = TestController(tLog, tLogTest, strLuaInterpreter, strTestPath)
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
