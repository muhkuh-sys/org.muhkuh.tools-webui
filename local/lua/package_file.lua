local PackageFile = {}

function PackageFile.read(tLog)
  tLog = tLog or {
    debug = function (...) print(string.format(...)) end,
    warning = function (...) print(string.format(...)) end
  }
  local pl = require'pl.import_into'()

  -- Default to version "unknown".
  local strVersion = 'unknown'
  local strVcsVersion = 'unknown'

  local strPackageInfoFile = pl.path.join('.jonchki', 'package.txt')
  if pl.path.isfile(strPackageInfoFile)~=true then
    if tLog~=nil then
      tLog.debug('The package file "%s" does not exist.', strPackageInfoFile)
    end
  else
    if tLog~=nil then
      tLog.debug('Reading the package file "%s".', strPackageInfoFile)
    end
    local strPackageInfo, strError = pl.utils.readfile(strPackageInfoFile, false)
    if strPackageInfo==nil then
      tLog.error('Failed to read the package file "%s": %s', strPackageInfoFile, strError)
    else
      strVersion = string.match(strPackageInfo, 'PACKAGE_VERSION=([0-9.]+)')
      strVcsVersion = string.match(strPackageInfo, 'PACKAGE_VCS_ID=([a-zA-Z0-9+]+)')
    end
    if tLog~=nil then
      tLog.debug('Version: %s', strVersion)
      tLog.debug('VCS version: %s', strVcsVersion)
    end
  end

  return strVersion, strVcsVersion
end


return PackageFile
