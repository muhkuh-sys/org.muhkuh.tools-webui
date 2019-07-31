local class = require 'pl.class'
local Tester = class()


function Tester:_init()
  self.pl = require'pl.import_into'()
  self.json = require 'dkjson'

  self.tCommonPlugin = nil
  self.strCommonPluginName = nil

  self.tLog = nil
  self.tSocket = nil
end



function Tester:setLog(tLog)
  self.tLog = tLog
end



function Tester:setSocket(tSocket)
  self.tSocket = tSocket
end



function Tester.hexdump(strData, uiBytesPerRow)
  uiBytesPerRow = uiBytesPerRow or 16

  local aDump
  local uiByteCnt = 0
  local tLog = self.tLog
  for uiCnt=1,strData:len() do
    if uiByteCnt==0 then
      aDump = { string.format("%08X :", uiCnt-1) }
    end
    table.insert(aDump, string.format(" %02X", strData:byte(uiCnt)))
    uiByteCnt = uiByteCnt + 1
    if uiByteCnt==uiBytesPerRow then
      uiByteCnt = 0
      print(table.concat(aDump))
    end
  end
  if uiByteCnt~=0 then
    print(table.concat(aDump))
  end
end



function Tester.callback_progress(a,b)
  print(string.format("%d%% (%d/%d)", a*100/b, a, b))
  return true
end



function Tester.callback(a,b)
  io.write(a)
  return true
end



function Tester:stdRead(tPlugin, ulAddress, sizData)
  return tPlugin:read_image(ulAddress, sizData, self.callback_progress, sizData)
end



function Tester:stdWrite(tPlugin, ulAddress, strData)
  tPlugin:write_image(ulAddress, strData, self.callback_progress, string.len(strData))
end



function Tester:stdCall(tPlugin, ulAddress, ulParameter)
  print('__/Output/____________________________________________________________________')
  tPlugin:call(ulAddress, ulParameter, self.callback, 0)
  print('')
  print('______________________________________________________________________________')
end



function Tester:getCommonPlugin(strInterfacePattern)
  -- Is a common plugin present?
  local tPlugin = self.tCommonPlugin
  local strPluginName = self.strCommonPluginName
  if tPlugin~=nil then
    -- Yes -> does it match the interface?
    local fMatches = false
    if strInterfacePattern==nil then
      -- An empty pattern matches all interfaces.
      fMatches = true
    elseif string.match(strPluginName, strInterfacePattern)~=nil then
      fMatches = true
    end
    if fMatches~=true then
      -- The current plugin does not match the pattern.
      -- Close it and select a new one.
      self:closeCommonPlugin()
    end
  end

  if tPlugin==nil then
    -- Open a new plugin.

    -- Detect all interfaces.
    local aDetectedInterfaces = {}
    local atPlugins = _G.__MUHKUH_PLUGINS
    if atPlugins==nil then
      error('No plugins registered!')
    else
      for _, tPlugin in ipairs(atPlugins) do
        tPlugin:DetectInterfaces(aDetectedInterfaces)
      end
    end

    -- Search all detected interfaces for the pattern.
    print(string.format('Searching for an interface with the pattern "%s".', strInterfacePattern))
    for iInterfaceIdx, tInterface in ipairs(aDetectedInterfaces) do
      local strName = tInterface:GetName()
      if string.match(strName, strInterfacePattern)==nil then
        print(string.format('Not connection to plugin "%s" as it does not match the interface pattern.', strName))
      else
        print(string.format('Connecting to plugin "%s".', strName))
        tPlugin = aDetectedInterfaces[iInterfaceIdx]:Create()
        strPluginName = strName

        tPlugin:Connect()

        break
      end
    end

    -- Found the interface?
    if tPlugin==nil then
      print(string.format('No interface matched the pattern "%s".', strInterfacePattern))
    else
      self.tCommonPlugin = tPlugin
      self.strCommonPluginName = strPluginName
    end
  end

  return tPlugin
end



function Tester:closeCommonPlugin()
  local tPlugin = self.tCommonPlugin
  if tPlugin~=nil and tPlugin:IsConnected()==true then
    -- Disconnect the plugin.
    tPlugin:Disconnect()
  end

  self.tCommonPlugin = nil
  self.strCommonPluginName = nil
end



function Tester:mbin_open(strFilename, tPlugin)
  local aAttr


  -- Replace the ASIC_TYPE magic.
  if string.find(strFilename, "${ASIC_TYPE}")~=nil then
    -- Get the chip type.
    local tAsicTyp = tPlugin:GetChiptyp()

    -- Get the binary for the ASIC.
    local strAsic
    if tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX4000_RELAXED or tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX4000_FULL or tAsicTyp==romloader.ROMLOADER_CHIPTYP_NET4100_SMALL then
      strAsic = "4000"
    elseif tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX100 or tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX500 then
      strAsic = "500"
    elseif tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX90_MPW then
      strAsic = "90_mpw"
    elseif tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX90 then
      strAsic = "90"
    elseif tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX90B then
      strAsic = "90b"
    elseif tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX56 or tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX56B then
      strAsic = "56"
    elseif tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX50 then
      strAsic = "50"
    elseif tAsicTyp==romloader.ROMLOADER_CHIPTYP_NETX10 then
      strAsic = "10"
    else
      error(string.format('Unknown chiptyp %s.', tostring(tAsicTyp)))
    end

    strFilename = string.gsub(strFilename, "${ASIC_TYPE}", strAsic)
  end

  -- Try to load the binary.
  local strData, strMsg = self.pl.utils.readfile(strFilename, true)
  if not strData then
    error(string.format('Failed to load the file "%s": %s', strFilename, strMsg))
  else
    -- Get the header from the binary.
    if string.sub(strData, 1, 4)~="mooh" then
      error(string.format('The file "%s" has no valid "mooh" header.', strFilename))
    else
      aAttr = {}

      aAttr.strFilename = strFilename

      aAttr.ulHeaderVersionMaj = string.byte(strData,5) + string.byte(strData,6)*0x00000100
      aAttr.ulHeaderVersionMin = string.byte(strData,7) + string.byte(strData,8)*0x00000100
      aAttr.ulLoadAddress = string.byte(strData,9) + string.byte(strData,10)*0x00000100 + string.byte(strData,11)*0x00010000 + string.byte(strData,12)*0x01000000
      aAttr.ulExecAddress = string.byte(strData,13) + string.byte(strData,14)*0x00000100 + string.byte(strData,15)*0x00010000 + string.byte(strData,16)*0x01000000
      aAttr.ulParameterStartAddress = string.byte(strData,17) + string.byte(strData,18)*0x00000100 + string.byte(strData,19)*0x00010000 + string.byte(strData,20)*0x01000000
      aAttr.ulParameterEndAddress = string.byte(strData,21) + string.byte(strData,22)*0x00000100 + string.byte(strData,23)*0x00010000 + string.byte(strData,24)*0x01000000

      aAttr.strBinary = strData
    end
  end

  return aAttr
end


function Tester:mbin_debug(aAttr, tLogLevel)
  print(string.format('file "%s":', aAttr.strFilename))
  print(string.format('  header version: %d.%d', aAttr.ulHeaderVersionMaj, aAttr.ulHeaderVersionMin))
  print(string.format('  load address:   0x%08x', aAttr.ulLoadAddress))
  print(string.format('  exec address:   0x%08x', aAttr.ulExecAddress))
  print(string.format('  parameter:      0x%08x - 0x%08x', aAttr.ulParameterStartAddress, aAttr.ulParameterEndAddress))
  print(string.format('  binary:         %d bytes', aAttr.strBinary:len()))
end


function Tester:mbin_write(tPlugin, aAttr)
  self:stdWrite(tPlugin, aAttr.ulLoadAddress, aAttr.strBinary)
end


function Tester:mbin_set_parameter(tPlugin, aAttr, aParameter)
  if not aParameter then
    aParameter = 0
  end

  -- Write the standard header.
  tPlugin:write_data32(aAttr.ulParameterStartAddress+0x00, 0xFFFFFFFF)                          -- Init the test result.
  tPlugin:write_data32(aAttr.ulParameterStartAddress+0x08, 0x00000000)                          -- Reserved

  if type(aParameter)=='table' then
    tPlugin:write_data32(aAttr.ulParameterStartAddress+0x04, aAttr.ulParameterStartAddress+0x0c)  -- Address of test parameters.

    for iIdx,tValue in ipairs(aParameter) do
      if type(tValue)=='string' and tValue=='OUTPUT' then
        -- Initialize output variables with 0.
        ulValue = 0
      else
        ulValue = tonumber(tValue)
        if ulValue==nil then
          error(string.format('The parameter %s is no valid number.', tostring(tValue)))
        elseif ulValue<0 or ulValue>0xffffffff then
          error(string.format("The parameter %s exceeds the range of an unsigned 32bit integer number.", tostring(tValue)))
        end
      end
      tPlugin:write_data32(aAttr.ulParameterStartAddress+0x0c+((iIdx-1)*4), ulValue)
    end
  elseif type(aParameter)=='string' then
    tPlugin:write_data32(aAttr.ulParameterStartAddress+0x04, aAttr.ulParameterStartAddress+0x0c)  -- Address of test parameters.
    self:stdWrite(tPlugin, aAttr.ulParameterStartAddress+0x0c, aParameter)
  else
    -- One single parameter.
    tPlugin:write_data32(aAttr.ulParameterStartAddress+0x04, aParameter)
  end
end


function Tester:mbin_execute(tPlugin, aAttr, aParameter, fnCallback, ulUserData)
  if not fnCallback then
    fnCallback = self.callback
  end
  if not ulUserData then
    ulUserData = 0
  end

  print('__/Output/____________________________________________________________________')
  tPlugin:call(aAttr.ulExecAddress, aAttr.ulParameterStartAddress, fnCallback, ulUserData)
  print('')
  print('______________________________________________________________________________')

  -- Read the result status.
  local ulResult = tPlugin:read_data32(aAttr.ulParameterStartAddress)
  if ulResult==0 then
    if type(aParameter)=='table' then
      -- Search the parameter for "OUTPUT" elements.
      for iIdx,tValue in ipairs(aParameter) do
        if type(tValue)=='string' and tValue=='OUTPUT' then
          -- This is an output element. Read the value from the netX memory.
          aParameter[iIdx] = tPlugin:read_data32(aAttr.ulParameterStartAddress+0x0c+((iIdx-1)*4))
        end
      end
    end
  end

  return ulResult
end


function Tester:mbin_simple_run(tPlugin, strFilename, aParameter)
  local aAttr = self:mbin_open(strFilename, tPlugin)
  self:mbin_debug(aAttr)
  self:mbin_write(tPlugin, aAttr)
  self:mbin_set_parameter(tPlugin, aAttr, aParameter)
  return self:mbin_execute(tPlugin, aAttr, aParameter)
end



function Tester:setInteraction(strFilename, atReplace)
  local tResult

  -- Read the interaction code.
  local strJsxTemplate, strErr = self.pl.file.read(strFilename)
  if strJsxTemplate==nil then
    self.tLog.error('Failed to read JSX from "%s": %s', strFilename, strErr)
  else
    local strJsx

    -- Replace something?
    if atReplace==nil then
      strJsx = strJsxTemplate
    else
      strJsx = string.gsub(strJsxTemplate, '@([%w_]+)@', atReplace)
    end

    self.tSocket:send(string.format('INT%s', strJsx))

    tResult = true
  end

  return tResult
end



function Tester:getInteractionResponse()
  local strResponse

  repeat
    local strMessage = self.tSocket:recv()
    strResponse = string.match(strMessage, '^RSP(.*)')
    if strResponse==nil then
      self.tLog.debug('Ignoring invalid response: %s', strMessage)
    end
  until strResponse~=nil

  return strResponse
end



function Tester:setInteractionGetJson(strFilename, atReplace)
  local tLog = self.tLog

  local tResult = self:setInteraction(strFilename, atReplace)
  if tResult==true then
    local strResponseRaw = self:getInteractionResponse()
    if strResponseRaw~=nil then
      local tJson, uiPos, strJsonErr = self.json.decode(strResponseRaw)
      if tJson==nil then
        tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
      else
        tLog.debug('JSON OK!')
        tResult = tJson
      end
    end
  end

  return tResult
end



function Tester:clearInteraction()
  self.tSocket:send('INT')
end



return Tester
