-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

require 'muhkuh_server_init'
local Pegasus = require 'pegasus'
local argparse = require 'argparse'
local mimetypes = require 'mimetypes'
local pl = require'pl.import_into'()

------------------------------------------------------------------------------
--
-- Try to read the package file.
--
local strPackageInfoFile = pl.path.join('.jonchki', 'package.txt')
local strPackageInfo, strError = pl.utils.readfile(strPackageInfoFile, false)
-- Default to version "unknown".
local strVersion = 'unknown'
local strVcsVersion = 'unknown'
if strPackageInfo~=nil then
  strVersion = string.match(strPackageInfo, 'PACKAGE_VERSION=([0-9.]+)')
  strVcsVersion = string.match(strPackageInfo, 'PACKAGE_VCS_ID=([a-zA-Z0-9+]+)')
end


------------------------------------------------------------------------------
--
-- Parse the command line arguments.
--
local function convertPortNumber(strArgument)
  -- Try to convert the string to a number.
  local usPort = tonumber(strArgument)
  local strError = nil
  if usPort==nil then
    strError = string.format('The port "%s" is not a number.', strArgument)
  elseif (usPort<1) or (usPort>65535) then
    usPort = nil
    strError = string.format('The port must be between 1 and 65535, but it is %d.' % usPort)
  end

  return usPort, strError
end

local tParser = argparse('serverkuh', 'A Pegasus based webserver for Muhkuh tests.')

tParser:flag('--version')
  :description('Show the version and exit.')
  :action(function()
    print(string.format('serverkuh V%s %s', strVersion, strVcsVersion))
    os.exit(0)
  end)
tParser:argument('websocket-port', 'Announce the websocket port in cfg.js as PORT.')
  :argname('<PORT>')
  :target('usWebsocketPort')
  :convert(convertPortNumber)
tParser:argument('ssdp-uuid', 'Use UUID as the SSDP UUID.')
  :argname('<UUID>')
  :target('strUUID')
tParser:argument('ssdp-serial', 'Use SERIAL as the SSDP serial number.')
  :argname('<SERIAL>')
  :target('strSerial')
tParser:option('-i --webserver-address')
  :description('Serve the HTTP documents on address ADDRESS.')
  :argname('<ADDRESS>')
  :default('localhost')
  :target('strWebserverAddress')
tParser:option('-w --webserver-port')
  :description('Serve the HTTP documents on port PORT.')
  :argname('<PORT>')
  :default(9090)
  :target('usWebserverPort')
  :convert(convertPortNumber)

local tArgs = tParser:parse()

------------------------------------------------------------------------------
--
-- Get a local copy of the SSDP serial and UUID.
-- Get the system UUID if no UUID was set on the command line.
--
local strSSDP_serial = tArgs.strSerial
local strSSDP_UUID = tArgs.strUUID


------------------------------------------------------------------------------
--
-- Show a summary of the parameters.
--
print()
print('Parameter:')
print(string.format('Webserver address: %s', tArgs.strWebserverAddress))
print(string.format('Webserver port:    %d', tArgs.usWebserverPort))
print(string.format('Websocket port:    %d', tArgs.usWebsocketPort))
print(string.format('SSDP serial:      "%s"', strSSDP_serial))
print(string.format('SSDP UUID:        "%s"', strSSDP_UUID))
print()


------------------------------------------------------------------------------
--
-- Run Pegasus.
--
local server = Pegasus:new({
  host=tArgs.strWebserverAddress,
  port=tArgs.usWebserverPort,
  location='/www/'
})

server:start(function(req, tResponse)
  local strPath = req:path()
  local strMethod = req:method()

  if strPath=='/cfg.js' and strMethod=='GET' then
    local strData = string.format("var g_CFG_strServerURL = 'ws://%s:%s';\n", tArgs.strWebserverAddress, tArgs.usWebsocketPort)

    tResponse:contentType('application/javascript')
    tResponse:statusCode(200)
    tResponse:write(strData)

  elseif strPath=='/description.xml' and strMethod=='GET' then
    local strURL = string.format('%s:%d/index.html', tArgs.strWebserverAddress, tArgs.usWebsocketPort)
    local strData = string.format([[<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
 <specVersion>
   <major>1</major>
   <minor>0</minor>
 </specVersion>
 <device>
  <deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType>
  <friendlyName>Muhkuh Production Test</friendlyName>
  <manufacturer>Muhkuh Team</manufacturer>
  <manufacturerURL>https://github.com/muhkuh-sys</manufacturerURL>
  <modelDescription>A Muhkuh production test.</modelDescription>
  <modelName>Muhkuh Production Test XYZ</modelName>
  <modelNumber>1.0.0</modelNumber>
  <modelURL>https://github.com/muhkuh-sys/org.muhkuh.tools-webui</modelURL>
  <serialNumber>%s</serialNumber>
  <UDN>uuid:%s</UDN>
  <presentationURL>http://%s</presentationURL>
 </device>
</root>
]], strSSDP_serial, strSSDP_UUID, strURL)

    tResponse:contentType('text/xml')
    tResponse:statusCode(200)
    tResponse:write(strData)

  elseif string.sub(strPath, 1, 6)=='/test/' and strMethod=='GET' then
    -- Read the file from the "test/www" folder.
    local strRealPath = 'test/www/' .. string.sub(strPath, 7)
    -- Try to open the file for reading.
    local tFile = io.open(strRealPath, 'rb')
    if tFile~=nil then
      -- The file exists. Serve it.
      local strMimeType = mimetypes.guess(strRealPath) or 'text/html'
      tResponse:writeFile(tFile, strMimeType)
    end
  end
end)
