local t = ...
local strDistId, strDistVersion, strCpuArch = t:get_platform()
local cLog = t.cLog
local tLog = t.tLog
local tResult
local archives = require 'installer.archives'
local pl = require'pl.import_into'()


-- Copy all additional files.
local atScripts = {
  ['targets/www']                  = '${install_base}/www/',

  ['lua/process_keepalive.lua']    = '${install_lua_path}/process_keepalive.lua',
  ['lua/process.lua']              = '${install_lua_path}/process.lua',
  ['lua/process_zmq.lua']          = '${install_lua_path}/process_zmq.lua',
  ['lua/ssdp.lua']                 = '${install_lua_path}/ssdp.lua',
  ['lua/test_controller.lua']      = '${install_lua_path}/test_controller.lua',
  ['lua/test_description.lua']     = '${install_lua_path}/test_description.lua',
  ['lua/webui_buffer.lua']         = '${install_lua_path}/webui_buffer.lua',

  ['${report_path}']               = '${install_base}/.jonchki/'
}
for strSrc, strDst in pairs(atScripts) do
  t:install(strSrc, strDst)
end


-- Install the CLI init script.
--if strDistId=='windows' then
--  t:install('local/windows/muhkuh_cli_init.lua', '${install_base}/')
--elseif strDistId=='ubuntu' then
--  t:install('local/linux/muhkuh_cli_init.lua', '${install_base}/')
--  t:install('local/linux/Desktop/NXHX90-JTAG-0.0.1.desktop', '${install_base}/data/Desktop/${root_artifact_artifact}-${root_artifact_version}.desktop')
--end


-- Create the package file.
local strPackageText = t:replace_template([[PACKAGE_NAME=${root_artifact_artifact}
PACKAGE_VERSION=${root_artifact_version}
PACKAGE_VCS_ID=${root_artifact_vcs_id}
HOST_DISTRIBUTION_ID=${platform_distribution_id}
HOST_DISTRIBUTION_VERSION=${platform_distribution_version}
HOST_CPU_ARCHITECTURE=${platform_cpu_architecture}
]])
local strPackagePath = t:replace_template('${install_base}/.jonchki/package.txt')
local tFileError, strError = pl.utils.writefile(strPackagePath, strPackageText, false)
if tFileError==nil then
  tLog.error('Failed to write the package file "%s": %s', strPackagePath, strError)
else
  local Archive = archives(cLog)

  -- Create a ZIP archive for Windows platforms. Build a "tar.gz" for Linux.
  local strArchiveExtension
  local tFormat
  local atFilter
  if strDistId=='windows' then
    strArchiveExtension = 'zip'
    tFormat = Archive.archive.ARCHIVE_FORMAT_ZIP
    atFilter = {}
  else
    strArchiveExtension = 'tar.gz'
    tFormat = Archive.archive.ARCHIVE_FORMAT_TAR_GNUTAR
    atFilter = { Archive.archive.ARCHIVE_FILTER_GZIP }
  end

  local strArtifactVersion = t:replace_template('${root_artifact_artifact}-${root_artifact_version}')
  local strDV = '-' .. strDistVersion
  if strDistVersion=='' then
    strDV = ''
  end
  local strArchive = t:replace_template(string.format('${install_base}/../../../%s-%s%s_%s.%s', strArtifactVersion, strDistId, strDV, strCpuArch, strArchiveExtension))
  local strDiskPath = t:replace_template('${install_base}')
  local strArchiveMemberPrefix = strArtifactVersion

  tResult = Archive:pack_archive(strArchive, tFormat, atFilter, strDiskPath, strArchiveMemberPrefix)
end

return tResult
