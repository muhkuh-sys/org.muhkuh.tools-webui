local t = ...
local strDistId = t:get_platform()
local pl = require'pl.import_into'()


-- Copy all additional files.
t:install{
  ['targets/www']                        = '${install_base}/www/',

  ['local/server.lua']                   = '${install_base}/',
  ['local/websocket_server.lua']         = '${install_base}/',
  ['local/server.cfg.template']          = '${install_base}/',
  ['local/server.cfg.local_folder.template'] = '${install_base}/',
  ['local/server.cfg.local_archive.template'] = '${install_base}/',

  ['local/lua/configuration_file.lua']   = '${install_lua_path}/',
  ['local/lua/log-kafka.lua']            = '${install_lua_path}/',
  ['local/lua/package_file.lua']         = '${install_lua_path}/',
  ['local/lua/process_keepalive.lua']    = '${install_lua_path}/',
  ['local/lua/process.lua']              = '${install_lua_path}/',
  ['local/lua/process_zmq.lua']          = '${install_lua_path}/',
  ['local/lua/ssdp.lua']                 = '${install_lua_path}/',
  ['local/lua/test_controller.lua']      = '${install_lua_path}/',
  ['local/lua/test_description.lua']     = '${install_lua_path}/',
  ['local/lua/webui_buffer.lua']         = '${install_lua_path}/',

  ['local/jsx/test_error_install_possible.jsx'] = '${install_base}/jsx/',
  ['local/jsx/test_error_serious.jsx']   = '${install_base}/jsx/',
  ['local/jsx/test_start.jsx']           = '${install_base}/jsx/',

  ['${report_path}']                     = '${install_base}/.jonchki/'
}


-- Install the CLI init script.
if strDistId=='ubuntu' then
  t:install('local/linux/run_server', '${install_base}/')
end


-- Filter the service file.
local strFileSourcePath = 'local/linux/systemd/muhkuh_webui.service'
local strFileDestinationPath = '${install_base}/systemd/'

local strSrcAbs = pl.path.abspath(strFileSourcePath, t.strCwd)
local strFileDestinationPathExpanded = t:replace_template(strFileDestinationPath)
local strFile, strError = pl.utils.readfile(strSrcAbs, false)
if strFile==nil then
  tLog.error('Failed to read the file "%s": %s', strSrcAbs, strError)
  error('Failed to read the file.')
end
local strFilteredFile = t:replace_template(strFile)
pl.dir.makepath(strFileDestinationPathExpanded)
local tFileError, strError = pl.utils.writefile(pl.path.join(strFileDestinationPathExpanded, 'ready_led.service'), strFilteredFile, false)
if tFileError==nil then
  tLog.error('Failed to write the file "%s": %s', strFileDestinationPathExpanded, strError)
  error('Failed to write the file.')
end


t:createPackageFile()
t:createHashFile()
t:createArchive('${install_base}/../../../${default_archive_name}', 'native')

return true
