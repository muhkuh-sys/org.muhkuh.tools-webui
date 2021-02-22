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
    ssdp_name = 'Muhkuh Teststation Unconfigured',
    tests_folder = pl.path.abspath('test'),
    interface = '',
    webserver_port = 9090,
    websocket_port = 12345,
    system_serial = 4321,
    kafka_broker = '',
    kafka_options = {},
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

  return tMergedConfig
end


return ConfigurationFile
