-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

local Pegasus = require 'pegasus'
local argparse = require 'argparse'
local mimetypes = require 'mimetypes'
local pl = require'pl.import_into'()

------------------------------------------------------------------------------
--
-- Try to read the package file.
--
local cPackageFile = require 'package_file'
local strVersion, strVcsVersion = cPackageFile.read()


------------------------------------------------------------------------------
--
-- Try to read the configuration file.
--
local cConfigurationFile = require 'configuration_file'
local tConfiguration = cConfigurationFile.read()

-- Prepare the path of the "www" folder. Add a path separator at the end.
local strPathTestWww = pl.path.join(tConfiguration.tests_folder, 'www', '')


------------------------------------------------------------------------------
--
-- Parse the command line arguments.
--
local tParser = argparse('serverkuh', 'A Pegasus based webserver for Muhkuh tests.')

tParser:flag('--version')
  :description('Show the version and exit.')
  :action(function()
    print(string.format('serverkuh V%s %s', strVersion, strVcsVersion))
    os.exit(0)
  end)
tParser:argument('ssdp-uuid', 'Use UUID as the SSDP UUID.')
  :argname('<UUID>')
  :target('strUUID')
tParser:option('-i --webserver-address')
  :description('Serve the HTTP documents on address ADDRESS.')
  :argname('<ADDRESS>')
  :default('localhost')
  :target('strWebserverAddress')

local tArgs = tParser:parse()

------------------------------------------------------------------------------
--
-- Get a local copy of the SSDP serial and UUID.
-- Get the system UUID if no UUID was set on the command line.
--
local strSSDP_UUID = tArgs.strUUID


------------------------------------------------------------------------------
--
-- Show a summary of the parameters.
--
print()
print('Parameter:')
print(string.format('Webserver address: %s', tArgs.strWebserverAddress))
print(string.format('Webserver port:    %d', tConfiguration.webserver_port))
print(string.format('Websocket port:    %d', tConfiguration.websocket_port))
print(string.format('SSDP serial:      "%s"', tConfiguration.system_serial))
print(string.format('SSDP UUID:        "%s"', strSSDP_UUID))
print()


------------------------------------------------------------------------------
--
-- Generate the javacript configuration file.
--
local strJavacriptCfg = string.format("var g_CFG_strServerURL = 'ws://%s:%s';\n", tArgs.strWebserverAddress, tConfiguration.websocket_port)

------------------------------------------------------------------------------
--
-- Generate the SSDP description.
--
local atReplacement = {
  FRIENDLY_NAME = tConfiguration.ssdp_name,
  PRESENTATION_URL = string.format('http://%s:%d/index.html', tArgs.strWebserverAddress, tConfiguration.webserver_port),
  SERIAL_NUMBER = tConfiguration.system_serial,
  MODEL_NUMBER = string.format('%s %s', strVersion, strVcsVersion),
  UUID = strSSDP_UUID
}
local strSsdpTemplate = [[<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
 <specVersion>
   <major>1</major>
   <minor>0</minor>
 </specVersion>
 <device>
  <deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType>
  <friendlyName>%FRIENDLY_NAME%</friendlyName>
  <manufacturer>Muhkuh Team</manufacturer>
  <manufacturerURL>https://github.com/muhkuh-sys</manufacturerURL>
  <modelDescription>A Muhkuh production test.</modelDescription>
  <modelName>Muhkuh Production Test Server</modelName>
  <modelNumber>%MODEL_NUMBER%</modelNumber>
  <modelURL>https://github.com/muhkuh-sys/org.muhkuh.tools-webui</modelURL>
  <serialNumber>%SERIAL_NUMBER%</serialNumber>
  <UDN>uuid:%UUID%</UDN>
  <presentationURL>%PRESENTATION_URL%</presentationURL>
 </device>
</root>
]]
local strSsdpDescription = string.gsub(strSsdpTemplate, '%%([%w_]+)%%', atReplacement)


------------------------------------------------------------------------------
--
-- Run Pegasus.
--
local server = Pegasus:new({
  host=tArgs.strWebserverAddress,
  port=tConfiguration.webserver_port,
  location='/www/'
})

server:start(function(req, tResponse)
  local strPath = req:path()
  local strMethod = req:method()

  if strPath=='/cfg.js' and strMethod=='GET' then

    tResponse:contentType('application/javascript')
    tResponse:statusCode(200)
    tResponse:write(strJavacriptCfg)

  elseif strPath=='/description.xml' and strMethod=='GET' then
    tResponse:contentType('text/xml')
    tResponse:statusCode(200)
    tResponse:write(strSsdpDescription)

  elseif string.sub(strPath, 1, 6)=='/test/' and strMethod=='GET' then
    -- Read the file from the "test/www" folder.
    local strRealPath = strPathTestWww .. string.sub(strPath, 7)
    -- Try to open the file for reading.
    local tFile = io.open(strRealPath, 'rb')
    if tFile~=nil then
      -- The file exists. Serve it.
      local strMimeType = mimetypes.guess(strRealPath) or 'text/html'
      tResponse:writeFile(tFile, strMimeType)
    end
  end
end)
