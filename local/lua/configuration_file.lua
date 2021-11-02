local class = require 'pl.class'
local ConfigurationFile = class()


function ConfigurationFile:_init(tLog)
  self.tLog = tLog
  self.pl = require'pl.import_into'()
end


function ConfigurationFile:__merge(strIdBase, atCfgBase, strIdOverlay, atCfgOverlay)
  local tLog = self.tLog
  local pl = self.pl

  local tConfiguration = {}
  for strKey, tValue in pairs(atCfgBase) do
    local strId = strIdBase
    local tValueOverlay = atCfgOverlay[strKey]
    if tValueOverlay~=nil then
      strId = strIdOverlay
      tValue = tValueOverlay
    end
    if strId~=nil then
      tLog.debug('  %s [%s] = %s', strId, strKey, pl.pretty.write(tValue))
    end
    tConfiguration[strKey] = tValue
  end

  return tConfiguration
end


function ConfigurationFile:read()
  local tLog = self.tLog
  local pl = self.pl

  local strServerConfigFile = pl.path.abspath('server.cfg')
  local tServerConfig = {}
  if pl.path.isfile(strServerConfigFile)~=true then
    tLog.debug('The server configuration file "%s" does not exist.', strServerConfigFile)
  else
    tLog.debug('Reading the server configuration from "%s"...', strServerConfigFile)
    tServerConfig = pl.config.read(strServerConfigFile)
  end
  local tConfigurationDefault = {
    -- The station name for the announcement in the Kafka teststations topic and the "friendly name" in SSDP.
    station_name = 'Muhkuh Teststation Unconfigured',

    -- The announce interval in seconds for the Kafka teststations topic.
    announce_interval = 300,

    -- OPT1: The path to a folder containing an extracted test.
    test_path = '',

    -- OPT2: The folder where test archives are stored.
    archive_path = '',

    -- OPT2: The file name of the test archive. It will be combined with the "archive_path" to form a complete path.
    test_archive = '',

    -- OPT2: A working folder. Here the test archive will be extracted.
    depack_path = '',

    -- The name of the ethernet interface o use. If none specified, take the first non-local.
    interface = '',

    -- The port of the webserver. Must be >1024 if the server is starting with non-root rights.
    webserver_port = 9090,

    -- The port number for the websocket. This is a regular port on the teststation server.
    -- It can be changed if it colliges with something else.
    websocket_port = 12345,

    -- This is used as the SSDP serial number.
    system_serial = 4321,

    -- One or more Kafka brokers to contact.
    kafka_broker = '',

    -- Options for the Kafka conneection.
    kafka_options = {},

    -- Store a copy of all kafka messages in /tmp .
    kafka_debugging = false,

    -- A second configuration file. If this option is present, the entries from the file will extend and override the
    -- entries in the mail configuration.
    local_config = ''
  }
  -- Merge the default and server configuration.
  local tMergedConfig0 = self:__merge('defaults', tConfigurationDefault, 'server config', tServerConfig)

  -- Is a local configuration defined?
  local strLocalConfigFile = tMergedConfig0.local_config
  local tLocalConfig = {}
  if strLocalConfigFile~=nil and strLocalConfigFile~='' then
    if pl.path.isfile(strLocalConfigFile)~=true then
      tLog.debug('The local configuration file "%s" does not exist.', strLocalConfigFile)
    else
      tLog.debug('Reading the local configuration from "%s"...', strLocalConfigFile)
      tLocalConfig = pl.config.read(strLocalConfigFile)
    end
  end
  -- Merge the local configuration.
  local tMergedConfig = self:__merge(nil, tMergedConfig0, 'local config', tLocalConfig)

  -- Convert the "kafka_debugging" entry to a boolean.
  local tValue = tMergedConfig.kafka_debugging
  local fValue = false
  if type(tValue)=='boolean' then
    fValue = tValue
  elseif type(tValue)=='string' and string.lower(tValue)=='true' then
    fValue = true
  end
  tMergedConfig.kafka_debugging = fValue

  return tMergedConfig
end


return ConfigurationFile
