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

  ['local/nginx/http-50-webui.conf']     = '${install_base}/openresty/nginx/conf.d/',

  ['${report_path}']                     = '${install_base}/.jonchki/'
}


-- Install the CLI init script.
if strDistId=='ubuntu' then
  t:install('local/linux/run_server', '${install_base}/')
end


-- Filter files.
local atFilterFiles = {
  ['local/linux/systemd/muhkuh_webui.service']  = '${install_base}/systemd/muhkuh_webui.service',
  ['local/nginx/server-50-webui.conf']   = '${install_base}/openresty/nginx/conf.d/server-50-webui.conf'
}
for strFileSourcePath, strFileDestinationPath in pairs(atFilterFiles) do
  local strSrcAbs = pl.path.abspath(strFileSourcePath, t.strCwd)
  local strFileDestinationPathExpanded = t:replace_template(strFileDestinationPath)
  local strFileData, strReadError = pl.utils.readfile(strSrcAbs, false)
  if strFileData==nil then
    error(string.format('Failed to read the file "%s": %s', strSrcAbs, strReadError))
  end
  local strFilteredFile = t:replace_template(strFileData)
  pl.dir.makepath(pl.path.dirname(strFileDestinationPathExpanded))
  local tFileError, strError = pl.utils.writefile(strFileDestinationPathExpanded, strFilteredFile, false)
  if tFileError==nil then
    error(string.format('Failed to write the file "%s": %s', strFileDestinationPathExpanded, strError))
  end
end


t:createPackageFile()
t:createHashFile()
t:createArchive('${install_base}/../../../${default_archive_name}', 'native')

return true
