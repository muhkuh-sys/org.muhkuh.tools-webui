-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

require 'muhkuh_server_init'
local Pegasus = require 'pegasus'
local argparse = require 'argparse'
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
tParser:argument('ssdp-serial', 'Use SERIAL as the SSDP serial number.')
  :argname('<SERIAL>')
  :target('strSerial')
tParser:option('-w --webserver-port')
  :description('Serve the HTTP documents on port PORT.')
  :argname('<PORT>')
  :default(9090)
  :target('usWebserverPort')
  :convert(convertPortNumber)
tParser:option('-u --ssdp-uuid')
  :description('Use UUID as the SSDP UUID.')
  :argname('<UUID>')
  :default(nil)
  :target('strUUID')

local tArgs = tParser:parse()

------------------------------------------------------------------------------
--
-- Get a local copy of the SSDP serial and UUID.
-- Get the system UUID if no UUID was set on the command line.
--
local strSSDP_serial = tArgs.strSerial
local strSSDP_UUID = tArgs.strUUID
if strSSDP_UUID==nil then
  print('No SSDP UUID specified on the command line. Readin the system UUID.')
  -- Get the system UUID.
  local strSystemUUIDFile = '/etc/machine-id'
  local strSystemUUID, strError = pl.utils.readfile(strSystemUUIDFile, false)
  if strSystemUUID==nil then
    error(string.format('Failed to read the system UUID from "%s": %s', strSystemUUIDFile, strError))
  else
    -- fa4bcfdf-9ee9-44ea-bb15-d0e214afef82
    local strU1, strU2, strU3, strU4, strU5 = string.match(strSystemUUID, '(%x%x%x%x%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x%x%x%x%x%x%x%x%x)')
    if strU1==nil then
      error(string.format('The UUID in "%s" does not match the expected format of 32 hex digits: "%s"', strSystemUUIDFile, strSystemUUID))
    else
      -- Combine all elements of the UUID with dashes.
      strSSDP_UUID = string.format('%s-%s-%s-%s-%s', strU1, strU2, strU3, strU4, strU5)
      print(string.format('The system UUID is %s .', strSSDP_UUID))
    end
  end
end

------------------------------------------------------------------------------
--
-- Show a summary of the parameters.
--
print()
print('Parameter:')
print(string.format('Webserver port:  %d', tArgs.usWebserverPort))
print(string.format('Websocket port:  %d', tArgs.usWebsocketPort))
print(string.format('SSDP serial:    "%s"', strSSDP_serial))
print(string.format('SSDP UUID:      "%s"', strSSDP_UUID))
print()


------------------------------------------------------------------------------
--
-- Run Pegasus.
--
local server = Pegasus:new({
  port=tArgs.usWebserverPort,
  location='/www/'
})

server:start(function(req, rep)
  local strPath = req:path()
  local strMethod = req:method()

  if strPath=='/cfg.js' and strMethod=='GET' then
    local strData = string.format("var g_CFG_strServerURL = 'ws://%s:%s';\n", req.ip, tArgs.usWebsocketPort)

    rep:contentType('application/javascript')
    rep:statusCode(200)
    rep:write(strData)
  elseif strPath=='/description.xml' and strMethod=='GET' then
    local strURL = string.format('%s:%d/index.html', req.ip, req.port)
    local strData = string.format([[<?xml version="1.0"?>
<root xmlns=\"urn:schemas-upnp-org:device-1-0\">
 <specVersion>
   <major>1</major>
   <minor>0</minor>
 </specVersion>
 <device>
  <deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType>
  <friendlyName>Muhkuh WebUI Gateway</friendlyName>
  <manufacturer>Muhkuh Team</manufacturer>
  <manufacturerURL>https://github.com/muhkuh-sys</manufacturerURL>
  <modelDescription>A gateway to all Muhkuh WebUI tests in the local network.</modelDescription>
  <modelName>Muhkuh WebUI</modelName>
  <modelNumber>1.0.0</modelNumber>
  <modelURL>https://github.com/muhkuh-sys/org.muhkuh.tools-webui</modelURL>
  <serialNumber>%s</serialNumber>
  <UDN>uuid:%s</UDN>
  <presentationURL>http://%s</presentationURL>
 </device>
</root>
]], strSSDP_serial, strSSDP_UUID, strURL)

    rep:contentType('text/xml')
    rep:statusCode(200)
    rep:write(strData)
  end
end)
