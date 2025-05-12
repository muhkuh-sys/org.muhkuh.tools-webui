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

    -- The announce interval in seconds for the heartbeat.
    -- The default of 2 seconds provide a responsive feedback in a local network. Increase this number for high latency
    -- links.
    announce_interval = 2,

    -- Choose the storage type for the test. This can be...
    -- "FOLDER": The test is stored in a local folder. It is ready-to-run.
    --           The option "test_path" points to the local folder.
    -- "LOCAL_ARCHIVE": The test is in a compressed local archive.
    --           The options "archive_path" and "test_archive" form the complete path to the archive.
    --           It is depacked to the folder specified in "depack_path".
    -- "REMOTE_LIST": Read a remote list from the URL specified in "remote_list_url".
    --                Look up the station ID specified in "remote_list_station_id" to get the URL to the test archive.
    --                Download the URL to the folder specified in "remote_list_download_folder" and
    --                extract it to the folder specified in "remote_list_depack_path".
    test_storage = 'FOLDER',

    -- Only for test_storage="FOLDER": The path to a folder containing an extracted test.
    test_path = '',

    -- Only for test_storage="LOCAL_ARCHIVE": The folder where test archives are stored.
    archive_path = '',

    -- Only for test_storage="LOCAL_ARCHIVE": The file name of the test archive. It will be combined with the
    -- "archive_path" to form a complete path.
    test_archive = '',

    -- Only for test_storage="LOCAL_ARCHIVE": A working folder. Here the test archive will be extracted.
    depack_path = '',

    -- Only for test_storage="REMOTE_LIST": The URL of the remote list mapping the station ID to a test archive.
    remote_list_url = '',

    -- Only for test_storage="REMOTE_LIST": The station ID for the lookup operation.
    remote_list_station_id = '',

    -- Only for test_storage="REMOTE_LIST": Download the archive here.
    remote_list_download_folder = '',

    -- Only for test_storage="REMOTE_LIST": Depack the downloaded archive here.
    remote_list_depack_path = '',

    -- The name of the ethernet interface o use. If none specified, take the first non-local.
    interface = '',

    -- Start the embedded webserver. Set this to false if an external webserver is used.
    webserver_embedded = true,

    -- The port of the webserver. Must be >1024 if the server is starting with non-root rights.
    webserver_port = 9090,

    -- The path to the web application.
    webserver_path = '/webui',

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

  -- Convert the boolean entries to a proper value
  local astrBooleanKeys = {
    'webserver_embedded',
    'kafka_debugging'
  }
  for _, strKey in ipairs(astrBooleanKeys) do
    local tValue = tMergedConfig[strKey]
    local fValue = false
    if type(tValue)=='boolean' then
      fValue = tValue
    elseif type(tValue)=='string' and string.lower(tValue)=='true' then
      fValue = true
    end
    tMergedConfig[strKey] = fValue
  end

  return tMergedConfig
end


return ConfigurationFile
