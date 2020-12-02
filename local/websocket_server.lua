local pl = require'pl.import_into'()
local uv  = require"lluv"
uv.poll_zmq = require "lluv.poll_zmq"

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
local strInterfaceName = tConfiguration.interface
if strInterfaceName==nil or strInterfaceName=='' then
  for uiCnt, tIf in ipairs(tInterfaces) do
    -- Select the first interface of the type "inet" which is not internal.
    if tIf.family=='inet' and tIf.internal==false then
      strInterfaceAddress = tIf.address
      tLog.info('Selecting interface "%s" with address %s.', tIf.name, strInterfaceAddress)
      break
    end
  end
  if strInterfaceAddress==nil then
    error('No suitable interface found.')
  end
else
  -- Search the requested interface.
  for uiCnt, tIf in ipairs(tInterfaces) do
    if tIf.name==strInterfaceName then
      strInterfaceAddress = tIf.address
      tLog.info('Using interface "%s" with address %s.', tIf.name, strInterfaceAddress)
      break
    end
  end
  if strInterfaceAddress==nil then
    error('No interface with the name "' .. tostring(strInterfaceName) .. '" found.')
  end
end


------------------------------------------------------------------------------
--
-- Start the SSDP server.
--
local strDescriptionLocation = string.format('http://%s:%s/description.xml', strInterfaceAddress, tConfiguration.webserver_port)
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
local tSystemAttributes = {
  ssdp = {
    name = tConfiguration.ssdp_name,
    uuid = strSSDP_UUID
  },
  test = {
    title = tTestDescription:getTitle(),
    subtitle = tTestDescription:getSubtitle()
  }
}
local tLogKafka = require 'log-kafka'(tLog, tSystemAttributes)
-- Connect the log consumer to a broker.
local strKafkaBroker = tConfiguration.kafka_broker
if strKafkaBroker~=nil and strKafkaBroker~='' then
  local atKafkaOptions = {}
  local astrKafkaOptions = tConfiguration.kafka_options
  if astrKafkaOptions==nil then
    astrKafkaOptions = {}
  elseif type(astrKafkaOptions)=='string' then
    astrKafkaOptions = { astrKafkaOptions }
  end
  for _, strOption in ipairs(astrKafkaOptions) do
    local strKey, strValue = string.match(strOption, '([^=]+)=(.+)')
    if strKey==nil then
      tLog.error('Ignoring invalid Kafka option: %s', strOption)
    else
      local strOldValue = atKafkaOptions[strKey]
      if strOldValue~=nil then
        if strKey=='sasl.password' then
          tLog.warning('Not overwriting Kafka option "%s".', strKey)
        else
          tLog.warning('Not overwriting Kafka option "%s" with the value "%s". Keeping the value "%s".', strKey, strValue, strOldValue)
        end
      else
        if strKey=='sasl.password' then
          tLog.debug('Setting Kafka option "%s" to ***hidden***.', strKey)
        else
          tLog.debug('Setting Kafka option "%s" to "%s".', strKey, strValue)
        end
        atKafkaOptions[strKey] = strValue
      end
    end
  end
  tLog.info('Connecting to kafka brokers: %s', strKafkaBroker)
  tLogKafka:connect(strKafkaBroker, atKafkaOptions)
else
  tLog.warning('Not connecting to any kafka brokers. The logs will not be saved.')
end
-- Register this test station.
tLogKafka:registerInstance{
  ip = strInterfaceAddress,
  port = tConfiguration.webserver_port
}

local WebUiBuffer = require 'webui_buffer'
local webui_buffer = WebUiBuffer(tLog, tConfiguration.websocket_port)
webui_buffer:setTitle(tTestDescription:getTitle(), tTestDescription:getSubtitle())
local tLogTest = webui_buffer:getLogTarget()
webui_buffer:start()

-- Create the server process.
local strLuaInterpreter = uv.exepath()
tLog.debug('LUA interpreter: %s', strLuaInterpreter)
local ProcessKeepalive = require 'process_keepalive'
local astrServerArgs = {
  'server.lua',
  strSSDP_UUID,
  '--webserver-address',
  strInterfaceAddress
}
local tServerProc = ProcessKeepalive(tLog, strLuaInterpreter, astrServerArgs, 3)

-- Create a new test controller.
local TestController = require 'test_controller'
local tTestController = TestController(tLog, tLogTest, strLuaInterpreter, tConfiguration.tests_folder)
tTestController:setBuffer(webui_buffer)
tTestController:setLogConsumer(tLogKafka)


tServerProc:run()
tTestController:run()


local function OnCancelAll()
  print('Cancel pressed!')
  tServerProc:shutdown()
  tTestProc:shutdown()
end
uv.signal():start(uv.SIGINT, OnCancelAll)


uv.run(debug.traceback)
