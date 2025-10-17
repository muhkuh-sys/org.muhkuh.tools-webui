local pl = require 'pl.import_into'()
local uv  = require 'lluv'
uv.poll_zmq = require 'lluv.poll_zmq'


local function __prepareFolder(tLog, strPath, strName)
  local tResult = true
  local strErrorMessage

  -- Refuse to work with a relative folder.
  if pl.path.isabs(strPath)~=true then
    strErrorMessage =string.format('The %s path "%s" is not absolute.', strName, strPath)
    tLog.error(strErrorMessage)
    tResult = false
  else
    -- Does the folder exist?
    if pl.path.exists(strPath)~=strPath then
      -- The path does not exist. Try to create it now.
      local tMkdirResult, strError = pl.dir.makepath(strPath)
      if tMkdirResult~=true then
        strErrorMessage = string.format('Failed to create the %s path "%s": %s', strName, strPath, strError)
        tLog.error(strErrorMessage)
        tResult = false
      end
    end

    if tResult==true then
      if pl.path.isdir(strPath)~=true then
        strErrorMessage = string.format('The %s path "%s" does not point to a directory.', strName, strPath)
        tLog.error(strErrorMessage)
        tResult = false
      end
    end
  end

  return tResult, strErrorMessage
end


local function __prepareAndCleanFolder(tLog, strPath, strName)
  local tResult, strErrorMessage = __prepareFolder(tLog, strPath, strName)
  if tResult==true then
    -- Remove all files in the depack folder.
    local astrObsoleteFiles = pl.dir.getallfiles(strPath)
    for _, strObsoleteFile in ipairs(astrObsoleteFiles) do
      tLog.debug('Delete %s', strObsoleteFile)
      local tDeleteResult, strError = pl.file.delete(strObsoleteFile)
      if tDeleteResult~=true then
        strErrorMessage = string.format('Failed to delete "%s": %s', strObsoleteFile, tostring(strError))
        tLog.error(strErrorMessage)
        tResult = false
      end
    end
  end

  return tResult, strErrorMessage
end


local function __extractArchive(tLog, strTestArchivePath, strDepackPath)
  local archive = require 'archive'
  local lfs = require 'lfs'
  local tResult = true
  local strTestBasePath = ''
  local strErrorMessage

  local tArcRead = archive.ArchiveRead()
  tArcRead:support_filter_all()
  tArcRead:support_format_all()

  local tArcWrite = archive.ArchiveWriteDisk()
  local iExtractFlags = (
    archive.ARCHIVE_EXTRACT_NO_OVERWRITE +
    archive.ARCHIVE_EXTRACT_SECURE_SYMLINKS +
    archive.ARCHIVE_EXTRACT_SECURE_NODOTDOT +
    archive.ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS
  )
  tArcWrite:set_options(iExtractFlags)
  tArcWrite:set_standard_lookup()

  -- Keep the old working directory for later.
  local strOldWorkingDir = lfs.currentdir()
  -- Move to the extract folder.
  local tLfsResult, strError = lfs.chdir(strDepackPath)
  if tLfsResult~=true then
    strErrorMessage = string.format('Failed to change to the depack path "%s": %s', strDepackPath, strError)
    tLog.error(strErrorMessage)
    tResult = false
  else
    tLog.debug('Extracting archive "%s".', strTestArchivePath)
    local r = tArcRead:open_filename(strTestArchivePath, 262144)
    if r~=0 then
      strErrorMessage = string.format(
        'Failed to open the archive "%s": %s',
        strTestArchivePath,
        tArcRead:error_string()
      )
      tLog.error(strErrorMessage)
      tResult = false
    else
      for tEntry in tArcRead:iter_header() do
        local strPathName = tEntry:pathname()
        tLog.debug('Processing entry "%s".', strPathName)

        local iResult = tArcWrite:write_header(tEntry)
        if iResult~=0 then
          strErrorMessage = string.format('Failed to create "%s": %s', strPathName, tArcWrite:error_string())
          tLog.error(strErrorMessage)
          tResult = false
          break
        end

        -- Copy the data in chunks of 256k.
        repeat
          local strData = tArcRead:read_data(262144)
          if strData~=nil then
            iResult = tArcWrite:write_data(strData)
            if iResult~=0 then
              strErrorMessage = string.format('Failed to write "%s": %s', strPathName, tArcWrite:error_string())
              tLog.error(strErrorMessage)
              tResult = false
              break
            end
          end
        until strData==nil

        iResult = tArcWrite:finish_entry()
        if iResult~=0 then
          strErrorMessage = string.format('Failed to write "%s": %s', strPathName, tArcWrite:error_string())
          tLog.error(strErrorMessage)
          tResult = false
          break
        end
      end
      tArcRead:close()
      tArcWrite:close()
    end

    -- Restore the old working directory.
    local tResultChdir, strErrorChdir = lfs.chdir(strOldWorkingDir)
    if tResultChdir~=true then
      strErrorMessage = string.format(
        'Failed to restore the working directory "%s" after depacking: %s',
        strOldWorkingDir,
        strErrorChdir
      )
      tLog.error(strErrorMessage)
      tResult = false
    end

    if tResult==true then
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
        tResult = false
      elseif sizTestsXmlPaths~=1 then
        strErrorMessage = string.format('More than 1 "tests.xml" found in path "%s".', strDepackPath)
        tLog.error(strErrorMessage)
        tResult = false
      else
        -- Get the path to the tests.xml path. The dirname is the test base path.
        local strTestXmlFile = astrTestsXmlPaths[1]
        strTestBasePath = pl.path.dirname(strTestXmlFile)
        tLog.debug('Found "tests.xml" in path "%s".', strTestBasePath)
      end
    end
  end

  return tResult, strTestBasePath, strErrorMessage
end


local function __download(tLog, strUrl)
  local curl = require 'lcurl'
  local tResult
  local strMessage

  local tCURL = curl.easy()

  -- Set the URL to download.
  tCURL:setopt_url(strUrl)

  -- Collect the received data in a table.
  local atDownloadData = {}

  -- Allow redirects. This is important for all big hosters which use cloud
  -- services in the background.
  tCURL:setopt(curl.OPT_FOLLOWLOCATION, true)

  -- Set the write function.
  -- The write function is called with a configurable first parameter. The
  -- second parameter will be a string with the received data.
  -- Here we want to insert the string of received data in the table
  -- atDownloadData.
  tCURL:setopt_writefunction(table.insert, atDownloadData)

  -- Show progress information.
  tCURL:setopt_noprogress(false)
  tCURL:setopt_progressfunction(
    function(tProgressInfo, ulTotal, ulNow)
      local tNow = os.time()
      if os.difftime(tNow, tProgressInfo.tLastProgressTime)>=tProgressInfo.uiDisplayIntervalInSeconds then
        tProgressInfo.tLastProgressTime = tNow
        if ulTotal~=nil and ulNow~=nil then
          if ulTotal~=0 then
            local ulPercent = math.floor(0.5 + (ulNow * 100.0 / ulTotal))
            tLog.debug('Downloading % 3d%% (% 8d/% 8d bytes)', ulPercent, ulNow, ulTotal)
          else
            tLog.debug('Downloading %d bytes', ulNow)
          end
        end
      end
    end,
    {
      uiDisplayIntervalInSeconds = 2,
      tLastProgressTime = 0
    }
  )

  local tCallResult, strError = pcall(tCURL.perform, tCURL)
  if tCallResult~=true then
    tResult = nil
    strMessage = string.format('Failed to retrieve URL "%s": %s', strUrl, strError)
  else
    local uiHttpResult = tCURL:getinfo(curl.INFO_RESPONSE_CODE)
    if uiHttpResult==200 then
      tResult = table.concat(atDownloadData)
    else
      tResult = nil
      strMessage = string.format('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult))
    end
  end
  tCURL:close()

  return tResult, strMessage
end


--- Convert a string to a HEX dump.
-- Convert each char in the string to its HEX representation.
-- @param strBin The string with the data to dump.
-- @return A HEX dump of strBin.
local function __bin_to_hex(strBin)
  local aHashHex = {}
  for iCnt=1,string.len(strBin) do
    table.insert(aHashHex, string.format('%02x', string.byte(strBin, iCnt)))
  end
  return table.concat(aHashHex)
end


local function __downloadBestHash(tLog, strBaseUrl)
  -- Use mhash to generate the hash sums.
  local mhash = require 'mhash'

  -- The table lists the accepted hash sums. They are sorted by quality.
  -- SHA384 is the best and MD5 the worst.
  local atMhashHashes = {
    { name='sha384', id=mhash.MHASH_SHA384 },
    { name='sha512', id=mhash.MHASH_SHA512 },
    { name='sha224', id=mhash.MHASH_SHA224 },
    { name='sha256', id=mhash.MHASH_SHA256 },
    { name='sha1',   id=mhash.MHASH_SHA1 },
    { name='md5',    id=mhash.MHASH_MD5 }
  }

  -- Placeholders for the result.
  local tHashID
  local strHashServer
  local strHashName

  -- Loop over all accepted hash algorithms.
  for _, tAttr in ipairs(atMhashHashes) do
    -- Append the name with a dot to the base URL. This is the hash file.
    local strName = tAttr.name
    local strUrl = strBaseUrl .. '.' .. strName
    tLog.debug('Looking for a %s hash in %s.', strName, strUrl)
    -- Try to download the hash file.
    local strData, strErrorDownload = __download(tLog, strUrl)
    if strData==nil then
      tLog.debug('Failed to download the %s hash: %s', strName, strErrorDownload)
    else
      tLog.debug('Downloaded %s hash.', strName)
      -- Try to parse the hash.
      local strHex = string.match(pl.stringx.strip(strData), '^([0-9a-fA-F]+)')
      if strHex==nil then
        tLog.debug('The URL %s contains no hash.', strUrl)
      else
        -- Check if the hash has the expected size.
        local sizHex = string.len(strHex)
        local uiBlocksize = mhash.get_block_size(tAttr.id)
        if sizHex~=(uiBlocksize*2) then
          tLog.debug('Invalid size for a %s hash. Expected %d bytes, but found %f.', strName, uiBlocksize, sizHex/2.0)
        else
          tLog.debug('Found a valid %s hash.', strName)
          tHashID = tAttr.id
          strHashServer = strHex
          strHashName = strName
          break
        end
      end
    end
  end

  return tHashID, strHashServer, strHashName
end


local function __findBestHash(tLog, strBaseFile)
  -- Use mhash to generate the hash sums.
  local mhash = require 'mhash'

  -- The table lists the accepted hash sums. They are sorted by quality.
  -- SHA384 is the best and MD5 the worst.
  local atMhashHashes = {
    { name='sha384', id=mhash.MHASH_SHA384 },
    { name='sha512', id=mhash.MHASH_SHA512 },
    { name='sha224', id=mhash.MHASH_SHA224 },
    { name='sha256', id=mhash.MHASH_SHA256 },
    { name='sha1',   id=mhash.MHASH_SHA1 },
    { name='md5',    id=mhash.MHASH_MD5 }
  }

  -- Placeholders for the result.
  local tHashID
  local strHashServer
  local strHashName

  -- Loop over all accepted hash algorithms.
  for _, tAttr in ipairs(atMhashHashes) do
    -- Append the name with a dot to the base URL. This is the hash file.
    local strName = tAttr.name
    local strFile = strBaseFile .. '.' .. strName
    tLog.debug('Looking for a %s hash in %s.', strName, strFile)
    -- Try to read the hash file.
    if pl.path.isfile(strFile)==true then
      local strData, strError = pl.utils.readfile(strFile)
      if strData==nil then
        tLog.debug('No %s hash found: %s', strName, strError)
      else
        tLog.debug('Found %s hash.', strName)
        -- Try to parse the hash.
        local strHex = string.match(pl.stringx.strip(strData), '^([0-9a-fA-F]+)')
        if strHex==nil then
          tLog.debug('The file %s contains no hash.', strFile)
        else
          -- Check if the hash has the expected size.
          local sizHex = string.len(strHex)
          local uiBlocksize = mhash.get_block_size(tAttr.id)
          if sizHex~=(uiBlocksize*2) then
            tLog.debug('Invalid size for a %s hash. Expected %d bytes, but found %f.', strName, uiBlocksize, sizHex/2.0)
          else
            tLog.debug('Found a valid %s hash.', strName)
            tHashID = tAttr.id
            strHashServer = strHex
            strHashName = strName
            break
          end
        end
      end
    end
  end

  return tHashID, strHashServer, strHashName
end


local function __getList(tLog, strRemoteListUrl, strRemoteListStationId, strRemoteDownloadFolder,
                         strRemoteListDepackPath)
  local tResult
  local strTestBasePath = ''
  local strErrorMessage

  local mhash = require 'mhash'

  if strRemoteListUrl==nil or strRemoteListUrl=='' then
    strErrorMessage = 'Test storage "REMOTE_LIST" selected, but no "remote_list_url" found.'
    tResult = false
  elseif strRemoteListStationId==nil or strRemoteListStationId=='' then
    strErrorMessage = 'Test storage "REMOTE_LIST" selected, but no "remote_list_station_id" found.'
    tResult = false
  elseif strRemoteDownloadFolder==nil or strRemoteDownloadFolder=='' then
    strErrorMessage = 'Test storage "REMOTE_LIST" selected, but no "remote_list_download_folder" found.'
    tResult = false
  elseif strRemoteListDepackPath==nil or strRemoteListDepackPath=='' then
    strErrorMessage = 'Test storage "REMOTE_LIST" selected, but no "remote_list_depack_path" found.'
    tResult = false

  else
    tResult, strErrorMessage = __prepareFolder(tLog, strRemoteDownloadFolder, 'download')
    if tResult==true then
      tResult, strErrorMessage = __prepareAndCleanFolder(tLog, strRemoteListDepackPath, 'depack')
      if tResult==true then

        tLog.debug('Downloading test list from %s .', strRemoteListUrl)
        local strList, strDlError = __download(tLog, strRemoteListUrl)
        if strList==nil then
          strErrorMessage = string.format('Failed to download the list from "%s": %s', strRemoteListUrl, strDlError)
          tResult = false
        else
          local dkjson = require 'dkjson'
          local tList, strJsonError = dkjson.decode(strList)
          if tList==nil then
            strErrorMessage = string.format(
              'Failed to parse the downloaded list from "%s" as JSON: %s',
              strRemoteListUrl,
              strJsonError
            )
            tResult = false
          else
            -- TODO: Schema test?

            tLog.debug('Looking for station ID "%s" in the downloaded test list.', strRemoteListStationId)
            -- Search all mapping entries for the station name.
            local strMatchingUrl
            for strUrl, atStationIDs in pairs(tList.mapping) do
              local iIdx = pl.tablex.find(atStationIDs,  strRemoteListStationId)
              if iIdx~=nil then
                strMatchingUrl = strUrl
                break
              end
            end

            if strMatchingUrl==nil then
              strErrorMessage = string.format(
                'The station ID "%s" was not found in the list "%s".',
                strRemoteListStationId,
                strRemoteListUrl
              )
              tResult = false
            else
              -- Get the optional base URL.
              local strBaseUrl = tList.baseUrl or ''
              local strUrl = strMatchingUrl
              if strBaseUrl~='' then
                strBaseUrl = pl.stringx.rstrip(strBaseUrl, '/')
                strMatchingUrl = pl.stringx.lstrip(strMatchingUrl, '/')
                strUrl = strBaseUrl .. '/' .. strMatchingUrl
              end
              tLog.debug('Found a matching URL: %s', strUrl)

              -- Check if the archive was already downloaded.
              local fHaveLocalFiles = false
              local strLocalArchive = pl.path.join(strRemoteDownloadFolder, pl.path.basename(strUrl))
              if pl.path.exists(strLocalArchive)==strLocalArchive then
                if pl.path.isfile(strLocalArchive)==false then
                  strErrorMessage = string.format(
                    'The download folder contains a directory with the name of the archive: %s',
                    strLocalArchive
                  )
                  tResult = false
                else
                  -- Search the best hash for the file.
                  local tHashID, strHashServer, strHashName = __findBestHash(tLog, strLocalArchive)
                  if tHashID==nil then
                    tLog.debug('No valid hash file found for "%s".', strLocalArchive)
                  else
                    tLog.debug('Using hash "%s".', strHashName)
                    -- Check the hash.
                    local tState = mhash.mhash_state()
                    tState:init(tHashID)
                    local tFile, strError = io.open(strLocalArchive, 'rb')
                    if tFile==nil then
                      tLog.debug('Failed to read "%s": %s', strLocalArchive, strError)
                    else
                      repeat
                        local tChunk = tFile:read(16384)
                        if tChunk~=nil then
                          tState:hash(tChunk)
                        end
                      until tChunk==nil
                      tFile:close()
                      local strHashMy = __bin_to_hex(tState:hash_end())
                      if strHashServer~=strHashMy then
                        tLog.debug('The hash for the file "%s" does not match.', strLocalArchive)
                      else
                        fHaveLocalFiles = true
                      end
                    end
                  end

                  if fHaveLocalFiles~=true then
                    pl.file.delete(strLocalArchive)
                  end
                end
              end

              if tResult==true and fHaveLocalFiles~=true then
                local strTestData, strDlError2 = __download(tLog, strUrl)
                if strTestData==nil then
                  strErrorMessage = string.format('Failed to download the test archive "%s": %s', strUrl, strDlError2)
                  tResult = false
                else
                  -- Try to get the hash sum.
                  local tHashID, strHashServer, strHashName = __downloadBestHash(tLog, strUrl)
                  if tHashID==nil then
                    strErrorMessage = string.format('No valid hash file found for "%s".', strUrl)
                    tResult = false
                  else
                    -- Check the hash.
                    local tState = mhash.mhash_state()
                    tState:init(tHashID)
                    tState:hash(strTestData)
                    local strHashMy = __bin_to_hex(tState:hash_end())
                    if strHashServer~=strHashMy then
                      strErrorMessage = 'The hash does not match. Did the download fail?!?'
                      tResult = false
                    else
                      -- Write the archive and the hash to the download folder.
                      local strLocalHash = strLocalArchive .. '.' .. strHashName
                      tResult, strErrorMessage = pl.utils.writefile(strLocalArchive, strTestData, true)
                      if tResult==true then
                        tResult, strErrorMessage = pl.utils.writefile(strLocalHash, strHashMy, false)
                      end
                    end
                  end
                end
              end

              if tResult==true then
                tResult, strTestBasePath, strErrorMessage = __extractArchive(
                  tLog,
                  strLocalArchive,
                  strRemoteListDepackPath
                )
              end
            end
          end
        end
      end
    end
  end

  return tResult, strTestBasePath, strErrorMessage
end


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
local strVersion = cPackageFile.read(tLog)


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
  for _, tIf in ipairs(tInterfaces) do
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
  for _, tIf in ipairs(tInterfaces) do
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
local strDescriptionLocation = string.format(
  'http://%s:%s/description.xml',
  strInterfaceAddress,
  tConfiguration.webserver_port
)
local SSDP = require 'ssdp'
local tSsdp = SSDP(tLog, strDescriptionLocation, strVersion)
local strSSDP_UUID = tSsdp:setSystemUuid()
tSsdp:run()


local tTestDescription = require 'test_description'(tLog)

local tResult = true
local bHaveValidTestDescription = false
local strErrorMessage
local strTestBasePath = ''

-- Does the configuration have a path to a test folder?
local strTestStorage = tConfiguration.test_storage
if strTestStorage=='FOLDER' then
  -- Use a folder with a ready-to-run test.
  local strTestPath = tConfiguration.test_path

  -- Get an absolute path to the test.
  strTestBasePath = pl.path.abspath(strTestPath)
  if strTestPath~=strTestBasePath then
    tLog.debug('Expanded the test path from "%s" to "%s".', strTestPath, strTestBasePath)
  end

  -- Does the folder exist?
  if pl.path.exists(strTestBasePath)~=strTestBasePath then
    strErrorMessage = string.format('The specified "test_path" does not exist: %s', strTestBasePath)
    tLog.error(strErrorMessage)
    tResult = false
  end

elseif strTestStorage=='LOCAL_ARCHIVE' then
  -- Config option "test_path" is not set -> depack an archive.

  local strDepackPath = tConfiguration.depack_path
  tResult, strErrorMessage = __prepareAndCleanFolder(tLog, strDepackPath, 'depack')
  if tResult==true then
    local strArchivePath = tConfiguration.archive_path
    if tResult==true then
      if pl.path.exists(strArchivePath)~=strArchivePath then
        strErrorMessage = string.format('The archive path "%s" does not exist.', strArchivePath)
        tLog.error(strErrorMessage)
        tResult = false
      end
    end

    if tResult==true then
      if pl.path.isdir(strArchivePath)~=true then
        strErrorMessage = string.format('The archive path "%s" does not point to a directory.', strArchivePath)
        tLog.error(strErrorMessage)
        tResult = false
      end
    end

    local strTestArchive = tConfiguration.test_archive
    if tResult==true then
      if strTestArchive=='' then
        strErrorMessage = string.format('The test archive is not set.')
        tLog.error(strErrorMessage)
        tResult = false
      end
    end

    if tResult==true then
      -- Get the path to the archive.
      local strTestArchivePath = pl.path.join(strArchivePath, strTestArchive)
      if pl.path.isfile(strTestArchivePath)~=true then
        strErrorMessage = string.format('The archive "%s" does not exist.', strTestArchivePath)
        tLog.error(strErrorMessage)
        tResult = false
      else
        tResult, strTestBasePath, strErrorMessage = __extractArchive(tLog, strTestArchivePath, strDepackPath)
      end
    end
  end

elseif strTestStorage=='REMOTE_LIST' then
  -- Download the URL in "remote_list_url".
  local strRemoteListUrl = tConfiguration.remote_list_url
  local strRemoteListStationId = tConfiguration.remote_list_station_id
  local strRemoteDownloadFolder = tConfiguration.remote_list_download_folder
  local strRemoteListDepackPath = tConfiguration.remote_list_depack_path
  tResult, strTestBasePath, strErrorMessage = __getList(
    tLog,
    strRemoteListUrl,
    strRemoteListStationId,
    strRemoteDownloadFolder,
    strRemoteListDepackPath
  )

else
  strErrorMessage = string.format('The configuration option "test_storage" defines an invalid type: %s', strTestStorage)
  tLog.error(strErrorMessage)
  tResult = false
end


local tPackageInfo
if tResult==true then
  tPackageInfo = pl.config.read(pl.path.join(strTestBasePath, '.jonchki/package.txt'), {convert_numbers=false})
  local tLocalPackageInfo = pl.config.read('.jonchki/package.txt', {convert_numbers=false})
  -- At least the host distribution ID and the host CPU architecture must match.
  if tPackageInfo.HOST_DISTRIBUTION_ID~=tLocalPackageInfo.HOST_DISTRIBUTION_ID then
    strErrorMessage = string.format(
      'The distribution ID "%s" of the test station does not match the test archive: "%s"',
      tLocalPackageInfo.HOST_DISTRIBUTION_ID,
      tPackageInfo.HOST_DISTRIBUTION_ID
    )
  elseif tPackageInfo.HOST_CPU_ARCHITECTURE~=tLocalPackageInfo.HOST_CPU_ARCHITECTURE then
    strErrorMessage = string.format(
      'The CPU architecture "%s" of the test station does not match the test archive: %s',
      tLocalPackageInfo.HOST_CPU_ARCHITECTURE,
      tPackageInfo.HOST_CPU_ARCHITECTURE
    )
  else
    -- Does the "tests.xml" file exist?
    local strTestXmlFile = pl.path.join(strTestBasePath, 'tests.xml')
    if pl.path.exists(strTestXmlFile)~=strTestXmlFile then
      strErrorMessage =string.format('No "tests.xml" found in the test path "%s".', strTestBasePath)
      tLog.error(strErrorMessage)
    else
      tLog.debug('Found "tests.xml" in path "%s".', strTestBasePath)

      bHaveValidTestDescription = tTestDescription:parse(strTestXmlFile)
      if bHaveValidTestDescription~=true then
        strErrorMessage = 'Failed to parse the test description.'
        tLog.error(strErrorMessage)
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
if tPackageInfo~=nil then
  tSystemAttributes.test.package_name = tPackageInfo.PACKAGE_NAME
  tSystemAttributes.test.package_version = tPackageInfo.PACKAGE_VERSION
  tSystemAttributes.test.package_vcs_id = tPackageInfo.PACKAGE_VCS_ID
  tSystemAttributes.test.host_distribution_id = tPackageInfo.HOST_DISTRIBUTION_ID
  tSystemAttributes.test.host_distribution_version = tPackageInfo.HOST_DISTRIBUTION_VERSION
  tSystemAttributes.test.host_cpu_architecture = tPackageInfo.HOST_CPU_ARCHITECTURE
end
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
          tLog.warning(
            'Not overwriting Kafka option "%s" with the value "%s". Keeping the value "%s".',
            strKey,
            strValue,
            strOldValue
          )
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
-- The interval can be set in seconds with the "announce_interval" item in the configuration.
local tAnnounceData = {
  ip = strInterfaceAddress,
  port = tConfiguration.webserver_port,
  path = pl.path.join(tConfiguration.webserver_path, 'index.html')
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

local strLuaInterpreter = uv.exepath()
tLog.debug('LUA interpreter: %s', strLuaInterpreter)

-- Create the server process.
local tServerProc
if tConfiguration.webserver_embedded~=true then
  tLog.info('Not starting the embedded web server as requested in the config.')
else
  local ProcessKeepalive = require 'process_keepalive'
  local astrServerArgs = {
    'server.lua',
    pl.path.join(strTestBasePath, 'www'),
    strSSDP_UUID,
    '--webserver-address',
    strInterfaceAddress
  }
  tServerProc = ProcessKeepalive(tLog, strLuaInterpreter, astrServerArgs, 3)
end

-- Create a new test controller.
local TestController = require 'test_controller'
local tTestController = TestController(tLog, tLogTest, strLuaInterpreter, strTestBasePath)
tTestController:setBuffer(webui_buffer)
tTestController:setLogConsumer(tLogKafka)


if tServerProc~=nil then
  tServerProc:run()
end
tTestController:run(bHaveValidTestDescription, strErrorMessage)

--[[
local function dumpUvHandles()
  local atHandles = uv.handles()
  if #atHandles==0 then
    print('No UV handles.')
  else
    print('UV handles:')
    for uiIndex, tHandle in ipairs(atHandles) do
      print(string.format('%03d: %s', uiIndex, tostring(tHandle)))
    end
  end
end
--]]

local tSignalHandler
local function OnCancelAll()
  print('Cancel pressed!')
--  dumpUvHandles()

  -- Stop the announce timer.
  if tAnnounceTimer~=nil then
    tAnnounceTimer:stop()
    tAnnounceTimer:close()
    tAnnounceTimer = nil
  end

  -- Shutdown the server.
  if tServerProc~=nil then
    tServerProc:shutdown()
    tServerProc= nil
  end

  -- Shutdown the test controller.
  if tTestController~=nil then
    tTestController:shutdown()
    tTestController = nil
  end

  -- Shutdown the webUI buffer.
  if webui_buffer~=nil then
    webui_buffer:shutdown()
    webui_buffer = nil
  end

  -- Shutdown the SSDP announcer.
  if tSsdp~=nil then
    tSsdp:shutdown()
    tSsdp = nil
  end

  -- Stop the signal handler.
  tSignalHandler:stop()
end
tSignalHandler = uv.signal():start(uv.SIGINT, OnCancelAll)

uv.timer():start(
    1000,
    0,
    function(handle)
      tLog.info('http://%s:%s/webui/index.html',
      strInterfaceAddress,
      tConfiguration.webserver_port
      )
    end
  )


uv.run(debug.traceback)
