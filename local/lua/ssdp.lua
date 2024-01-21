local class = require 'pl.class'
local SSDP = class()


function SSDP:_init(tLog, strDescriptionUrl, strMuhkuhVersion)
  self.tLog = tLog

  self.pl = require'pl.import_into'()
  self.lluv = require 'lluv'

  self.m_strSsdpIpV4 = '239.255.255.250'
  self.m_strSsdpPort = 1900
  self.m_uiAnnounceIntervalInMs = 2000

  self.m_tSsdpSocket = nil
  self.m_tAnnounceTimer = nil

  self.m_strSystemUuid = nil
  self.m_strDescriptionUrl = strDescriptionUrl
  self.m_strMuhkuhVersion = strMuhkuhVersion

  self:__generateTypeLookup()

  self.strTemplateSsdpNotify = table.concat(
    {
      'NOTIFY * HTTP/1.1',
      'Host: %SSDP_IPV4%:%SSDP_PORT%',
      'Server: Muhkuh/%MUHKUH_VERSION% UPnP/1.0 ssdpd/1.5',
      'Location: %LOCATION%',
      'NT: %NT%',
      'NTS: ssdp:alive',
      'USN: %USN%',
      'Cache-Control: max-age=%MAX_AGE%',
      '',
      ''
    },
    '\r\n'
  )

  self.strTemplateSsdpResponse = table.concat(
    {
      'HTTP/1.1 200 OK',
      'Server: Muhkuh/%MUHKUH_VERSION% UPnP/1.0 ssdpd/1.5',
      'Location: %LOCATION%',
      'ST: %ST%',
      'EXT: ',
      'USN: %USN%',
      'Cache-Control: max-age=%MAX_AGE%',
      '',
      ''
    },
    '\r\n'
  )
end



function SSDP:__generateTypeLookup()
  self.m_atSsdpTypes = {
    {
      type='ssdp',
      data='all',
      fIncludeInNotifyAll=false,
      fSendOnlyUUID=true
    },
    {
      type='upnp',
      data='rootdevice',
      fIncludeInNotifyAll=true,
      fSendOnlyUUID=false
    },
    {
      type='urn',
      data='schemas-upnp-org:device:InternetGatewayDevice:1',
      fIncludeInNotifyAll=true,
      fSendOnlyUUID=false
    },
    {
      type='uuid',
      data=self.m_strSystemUuid,
      fIncludeInNotifyAll=true,
      fSendOnlyUUID=true
    }
  }
end



function SSDP:setSystemUuid()
  local tResult
  local tLog = self.tLog

  -- Linux has a machine ID which should work.
  local strSystemUUIDFile = '/etc/machine-id'
  local strSystemUUID, strError = self.pl.utils.readfile(strSystemUUIDFile, false)
  if strSystemUUID==nil then
    tLog.error('Failed to read the system UUID from "%s": %s', strSystemUUIDFile, strError)

  else
    local strU1, strU2, strU3, strU4, strU5 = string.match(
      strSystemUUID,
      '(%x%x%x%x%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x%x%x%x%x%x%x%x%x)'
    )
    if strU1==nil then
    tLog.error(
      'The UUID in "%s" does not match the expected format of 32 hex digits: "%s"',
      strSystemUUIDFile,
      strSystemUUID
    )

    else
      -- Combine all elements of the UUID with dashes.
      local strSystemUuid = string.format('%s-%s-%s-%s-%s', strU1, strU2, strU3, strU4, strU5)
      tLog.info('The system UUID is %s .', strSystemUuid)
      self.m_strSystemUuid = strSystemUuid

      self:__generateTypeLookup()

      tResult = strSystemUuid
    end
  end

  return tResult
end



function SSDP:__announce(tSocket, tAttr, strSourceIp, uiSourcePort)
  -- Get the NT and USN for the type.
  local strNT
  local strUSN
  if tAttr.fSendOnlyUUID==true then
    -- The NT and USN is the UUID.
    strNT = string.format('uuid:%s', self.m_strSystemUuid)
    strUSN = strNT
  else
    -- The NT is the type.
    strNT = string.format('%s:%s', tAttr.type, tAttr.data)
    -- The USN is the combination of the UUID and the new item.
    strUSN = string.format('uuid:%s::%s:%s', self.m_strSystemUuid, tAttr.type, tAttr.data)
  end

  -- Select the template.
  local strTemplate
  if strSourceIp==nil then
    strTemplate = self.strTemplateSsdpNotify
  else
    strTemplate = self.strTemplateSsdpResponse
  end

  local atReplace = {
    LOCATION = self.m_strDescriptionUrl,
    MAX_AGE = 80,
    MUHKUH_VERSION = self.m_strMuhkuhVersion,
    NT = strNT,
    SSDP_IPV4 = self.m_strSsdpIpV4,
    SSDP_PORT = self.m_strSsdpPort,
    ST = strNT,
    USN = strUSN
  }
  local strData = string.gsub(strTemplate, '%%([a-ZA-Z0-9_]+)%%', atReplace)

  local strDestinationIp = strSourceIp or self.m_strSsdpIpV4
  local uiDestinationPort = uiSourcePort or self.m_strSsdpPort
  tSocket:send(strDestinationIp, uiDestinationPort, strData)
end



function SSDP:__onReceive(tSocket, tError, strData, _, strHost, uiPort)
  if tError then
    return
  end

  -- Does the packet start with "M-SEARCH *" ?
  if string.sub(strData, 1, 10)=='M-SEARCH *' then
    -- Search for "ST".
    local strService = string.match(strData, '\r\nST:([^\r\n]+)\r\n')
    if strService==nil then
      strService = 'ssdp:all'
    else
      -- Remove whitespace at the start and end of the string.
      strService = self.pl.stringx.strip(strService)
    end
    for _, tAttr in ipairs(self.m_atSsdpTypes) do
      local strTypeData = tAttr.type .. ':' .. tAttr.data
      if strService==strTypeData then
        self:__announce(tSocket, tAttr, strHost, uiPort)
      end
    end
  end
end



function SSDP:__notifyAll()
  for _, tAttr in ipairs(self.m_atSsdpTypes) do
    if tAttr.fIncludeInNotifyAll==true then
      self:__announce(self.m_tSsdpSocket, tAttr)
    end
  end
end



function SSDP:run()
  local lluv = self.lluv

  local tSsdpSocket = lluv.udp()
  tSsdpSocket:bind('*', self.m_strSsdpPort)
  tSsdpSocket:set_membership(self.m_strSsdpIpV4, nil, 'join')
  tSsdpSocket:set_multicast_ttl(255)
  self.m_tSsdpSocket = tSsdpSocket

  local this = self
  tSsdpSocket:start_recv(
    function(tSocket, tError, strData, tFlags, strHost, uiPort)
      this:__onReceive(tSocket, tError, strData, tFlags, strHost, uiPort)
    end
  )

  local tAnnounceTimer = lluv.timer()
  tAnnounceTimer:start(self.m_uiAnnounceIntervalInMs, function(tTimer)
    this:__notifyAll()
    tTimer:again(this.m_uiAnnounceIntervalInMs)
  end)
  self.m_tAnnounceTimer = tAnnounceTimer
end


function SSDP:shutdown()
  local tSsdpSocket = self.m_tSsdpSocket
  if tSsdpSocket~=nil then
    tSsdpSocket:close()
    self.m_tSsdpSocket = nil
  end

  local tAnnounceTimer = self.m_tAnnounceTimer
  if tAnnounceTimer~=nil then
    tAnnounceTimer:stop()
    tAnnounceTimer:close()
    self.m_tAnnounceTimer = nil
  end
end

return SSDP
