local ConfigurationFile = {}

function ConfigurationFile.read(tLog)
  tLog = tLog or {
    debug = function (...) print(string.format(...)) end
  }
  local pl = require'pl.import_into'()

  local strConfigurationFile = pl.path.abspath('server.cfg')
  local tConfigurationFromFile = {}
  if pl.path.isfile(strConfigurationFile)~=true then
    tLog.debug('The configuration file "%s" does not exist.', strConfigurationFile)
  else
    tLog.debug('Reading the configuration from "%s"...', strConfigurationFile)
    tConfigurationFromFile = pl.config.read(strConfigurationFile)
  end
  local tConfigurationDefault = {
    ssdp_name = 'Muhkuh Teststation',
    tests_folder = pl.path.abspath('test'),
    interface = '',
    webserver_port = 9090,
    websocket_port = 12345,
    system_serial = 4321,
    kafka_broker = ''
  }
  -- Join both configurations.
  local tConfiguration = {}
  for strKey, tValue in pairs(tConfigurationDefault) do
    local tValueFile = tConfigurationFromFile[strKey]
    if tValueFile~=nil then
      tValue = tValueFile
      tLog.debug('  [%s] from file = %s', strKey, tostring(tValueFile))
    else
      tLog.debug('  [%s] default = %s', strKey, tostring(tValue))
    end
    tConfiguration[strKey] = tValue
  end

  return tConfiguration
end


return ConfigurationFile
