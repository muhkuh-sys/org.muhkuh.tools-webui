local Tester = {}


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



function Tester.stdRead(tParentWindow, tPlugin, ulAddress, sizData)
  return tPlugin:read_image(ulAddress, sizData, self.callback_progress, sizData)
end



function Tester.stdWrite(tParentWindow, tPlugin, ulAddress, strData)
	tPlugin:write_image(ulAddress, strData, self.callback_progress, string.len(strData))
end



function Tester.stdCall(tParentWindow, tPlugin, ulAddress, ulParameter)
	print('__/Output/____________________________________________________________________')
	tPlugin:call(ulAddress, ulParameter, self.callback, 0)
	print('')
	print('______________________________________________________________________________')
end



function Tester.mbin_open(strFilename, tPlugin)
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


function Tester.mbin_debug(aAttr, tLogLevel)
  print('file "%s":', aAttr.strFilename)
  print('  header version: %d.%d', aAttr.ulHeaderVersionMaj, aAttr.ulHeaderVersionMin)
  print('  load address:   0x%08x', aAttr.ulLoadAddress)
  print('  exec address:   0x%08x', aAttr.ulExecAddress)
  print('  parameter:      0x%08x - 0x%08x', aAttr.ulParameterStartAddress, aAttr.ulParameterEndAddress)
  print('  binary:         %d bytes', aAttr.strBinary:len())
end


function Tester.mbin_write(tParentWindow, tPlugin, aAttr)
  self.stdWrite(tPlugin, aAttr.ulLoadAddress, aAttr.strBinary)
end


function Tester.mbin_set_parameter(tPlugin, aAttr, aParameter)
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
    self.stdWrite(tPlugin, aAttr.ulParameterStartAddress+0x0c, aParameter)
  else
    -- One single parameter.
    tPlugin:write_data32(aAttr.ulParameterStartAddress+0x04, aParameter)
  end
end


function Tester.mbin_execute(tParentWindow, tPlugin, aAttr, aParameter, fnCallback, ulUserData)
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


function Tester.mbin_simple_run(tParentWindow, tPlugin, strFilename, aParameter)
  local aAttr = mbin_open(strFilename, tPlugin)
  mbin_debug(aAttr)
  mbin_write(tPlugin, aAttr)
  mbin_set_parameter(tPlugin, aAttr, aParameter)
  return mbin_execute(tPlugin, aAttr, aParameter)
end

return Tester
