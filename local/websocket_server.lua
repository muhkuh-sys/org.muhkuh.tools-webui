local archive = require 'archive'
local lfs = require 'lfs'
local pl = require 'pl.import_into'()
local uv  = require 'lluv'
uv.poll_zmq = require 'lluv.poll_zmq'

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
local cConfigurationFile = require 'configuration_file'(tLog)
local tConfiguration = cConfigurationFile:read()


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


local tTestDescription = require 'test_description'(tLog)

local tResult = true
local bSeriousError = false
local bInstallPossible = false
local bHaveValidTestDescription = false
local strErrorMessage
local strTestBasePath = ''

-- Refuse to work with a relative depack folder.
local strDepackPath = tConfiguration.depack_path
if pl.path.isabs(strDepackPath)~=true then
  strErrorMessage =string.format('The depack path "%s" is not absolute.', strDepackPath)
  tLog.error(strErrorMessage)
  bSeriousError = true
  tResult = false
else
  -- Does the depack folder exist?
  if pl.path.exists(strDepackPath)~=strDepackPath then
    -- The depack path does not exist. Try to create it now.
    local tMkdirResult, strError = pl.path.mkdir(strDepackPath)
    if tMkdirResult~=true then
      strErrorMessage = string.format('Falied to create the depack path "%s": %s', strDepackPath, strError)
      tLog.error(strErrorMessage)
      bSeriousError = true
      tResult = false
    end
  end

  if tResult==true then
    if pl.path.isdir(strDepackPath)~=true then
      strErrorMessage = string.format('The depack path "%s" does not point to a directory.', strDepackPath)
      tLog.error(strErrorMessage)
      bSeriousError = true
      tResult = false
    end
  end

  if tResult==true then
    -- Remove all files in the depack folder.
    local astrObsoleteFiles = pl.dir.getallfiles(strDepackPath)
    for _, strObsoleteFile in ipairs(astrObsoleteFiles) do
      tLog.debug('Delete %s', strObsoleteFile)
      local tDeleteResult, strError = pl.file.delete(strObsoleteFile)
      if tDeleteResult~=true then
        strErrorMessage = string.format('Failed to delete "%s": %s', strObsoleteFile, tostring(strError))
        tLog.error(strErrorMessage)
        bSeriousError = true
        tResult = false
      end
    end
  end

  local strArchivePath = tConfiguration.archive_path
  if tResult==true then
    if pl.path.exists(strArchivePath)~=strArchivePath then
      strErrorMessage = string.format('The archive path "%s" does not exist.', strArchivePath)
      tLog.error(strErrorMessage)
      bSeriousError = true
      tResult = false
    end
  end

  if tResult==true then
    if pl.path.isdir(strArchivePath)~=true then
      strErrorMessage = string.format('The archive path "%s" does not point to a directory.', strArchivePath)
      tLog.error(strErrorMessage)
      bSeriousError = true
      tResult = false
    end
  end

  local strTestArchive = tConfiguration.test_archive
  if tResult==true then
    if strTestArchive=='' then
      strErrorMessage = string.format('The test archive is not set.')
      tLog.error(strErrorMessage)
      bInstallPossible = true
      tResult = false
    end
  end

  if tResult==true then
    -- Get the path to the archive.
    local strTestArchivePath = pl.path.join(strArchivePath, strTestArchive)
    if pl.path.isfile(strTestArchivePath)~=true then
      strErrorMessage = string.format('The archive "%s" does not exist.', strTestArchivePath)
      tLog.error(strErrorMessage)
      bInstallPossible = true
      tResult = false
    else
      local tArc = archive.ArchiveRead()
      tArc:support_filter_all()
      tArc:support_format_all()

      local iExtractFlags = archive.ARCHIVE_EXTRACT_SECURE_SYMLINKS + archive.ARCHIVE_EXTRACT_SECURE_NODOTDOT + archive.ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS

      -- Keep the old working directory for later.
      local strOldWorkingDir = lfs.currentdir()
      -- Move to the extract folder.
      local tLfsResult, strError = lfs.chdir(strDepackPath)
      if tLfsResult~=true then
        strErrorMessage = string.format('Failed to change to the depack path "%s": %s', strDepackPath, strError)
        tLog.error(strErrorMessage)
        bSeriousError = true
        tResult = false
      else
        tLog.debug('Extracting archive "%s".', strTestArchivePath)
        local r = tArc:open_filename(strTestArchivePath, 16384)
        if r~=0 then
          strErrorMessage = string.format('Failed to open the archive "%s": %s', strTestArchivePath, tArc:error_string())
          tLog.error(strErrorMessage)
          bInstallPossible = true
          tResult = false
        else
          for tEntry in tArc:iter_header() do
            local strPathName = tEntry:pathname()
            tLog.debug('Processing entry "%s".', strPathName)

            local iResult = tArc:extract(tEntry, iExtractFlags)
            if iResult~=0 then
              strErrorMessage = string.format('Failed to extract entry "%s" from archive "%s".', strPathName, strTestArchivePath)
              tLog.error(strErrorMessage)
              bInstallPossible = true
              tResult = false
              break
            end
          end
        end

        -- Restore the old working directory.
        local tLfsResult, strError = lfs.chdir(strOldWorkingDir)
        if tLfsResult~=true then
          strErrorMessage = string.format('Failed to restore the working directory "%s" after depacking: %s', strOldWorkingDir, strError)
          tLog.error(strErrorMessage)
          bSeriousError = true
          tResult = false
        else
          -- Find all "tests.xml" files.
          local astrTestsXmlPaths = {}
          for strPathName, fIsDirectory in pl.dir.dirtree(strDepackPath) do
            if fIsDirectory==false and pl.path.basename(strPathName)=='tests.xml' then
              table.insert(astrTestsXmlPaths, strPathName)
            end
          end
          -- There must be exactly one tests.xml file.
          local sizTestsXmlPaths = #astrTestsXmlPaths
          if sizTestsXmlPaths==0 then
            strErrorMessage = string.format('No "tests.xml" found in path "%s".', strDepackPath)
            tLog.error(strErrorMessage)
            bInstallPossible = true
            tResult = false
          elseif sizTestsXmlPaths~=1 then
            strErrorMessage = string.format('More than 1 "tests.xml" found in path "%s".', strDepackPath)
            tLog.error(strErrorMessage)
            bInstallPossible = true
            tResult = false
          else
            -- Get the path to the tests.xml path. The dirname is the test base path.
            local strTestXmlFile = astrTestsXmlPaths[1]
            strTestBasePath = pl.path.dirname(strTestXmlFile)
            tLog.debug('Found "tests.xml" in path "%s".', strTestBasePath)

            bHaveValidTestDescription = tTestDescription:parse(strTestXmlFile)
            if bHaveValidTestDescription~=true then
              strErrorMessage = string.format('Failed to parse the test description.')
              tLog.error(strErrorMessage)
              bInstallPossible = true
            end
          end
        end
      end
    end
  end
end


-- Create the kafka log consumer.
local tSystemAttributes = {
  station = {
    name = tConfiguration.station_name,
    uuid = strSSDP_UUID
  },
  test = {
    title = tTestDescription:getTitle(),
    subtitle = tTestDescription:getSubtitle()
  }
}
local tLogKafka = require 'log-kafka'(tLog, tConfiguration.kafka_debugging)
tLogKafka:setSystemAttributes(tSystemAttributes)
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
-- Announce the test station in regular intervals.
-- The interval can be set in milliseconds with the "announce_interval" item in the configuration.
local tAnnounceData = {
  ip = strInterfaceAddress,
  port = tConfiguration.webserver_port
}
local uiAnnounceInterval = tConfiguration.announce_interval
local uiCheckInterval = 10000
tLogKafka:announceInstance(tAnnounceData)
local uiLastAnnouncedTime = os.time()
local tAnnounceTimer = uv.timer():start(uiCheckInterval, function(tTimer)
  local uiNow = os.time()
  if os.difftime(uiNow, uiLastAnnouncedTime)>=uiAnnounceInterval then
    tLogKafka:announceInstance(tAnnounceData)
    uiLastAnnouncedTime = uiNow
  end
  tTimer:again(uiCheckInterval)
end)

local WebUiBuffer = require 'webui_buffer'
local webui_buffer = WebUiBuffer(tLog, tConfiguration.websocket_port)
webui_buffer:setTitle(tTestDescription:getTitle(), tTestDescription:getSubtitle())
webui_buffer:setDocuments(tTestDescription:getDocuments())
local tLogTest = webui_buffer:getLogTarget()
webui_buffer:start()

-- Create the server process.
local strLuaInterpreter = uv.exepath()
tLog.debug('LUA interpreter: %s', strLuaInterpreter)
local ProcessKeepalive = require 'process_keepalive'
local astrServerArgs = {
  'server.lua',
  pl.path.join(strTestBasePath, 'www'),
  strSSDP_UUID,
  '--webserver-address',
  strInterfaceAddress
}
local tServerProc = ProcessKeepalive(tLog, strLuaInterpreter, astrServerArgs, 3)

-- Create a new test controller.
local TestController = require 'test_controller'
local tTestController = TestController(tLog, tLogTest, strLuaInterpreter, strTestBasePath)
tTestController:setBuffer(webui_buffer)
tTestController:setLogConsumer(tLogKafka)


tServerProc:run()
tTestController:run(bHaveValidTestDescription, bInstallPossible, strErrorMessage)


local function OnCancelAll()
  print('Cancel pressed!')
  tServerProc:shutdown()
  tTestProc:shutdown()
end
uv.signal():start(uv.SIGINT, OnCancelAll)


uv.run(debug.traceback)
