local class = require 'pl.class'
local TestDescription = class()


function TestDescription:_init(tLog)
  self.tLog = tLog

  self.pl = require'pl.import_into'()
  self.lxp = require 'lxp'

  self.strTitle = nil
  self.strSubtitle = nil
  self.atTestCases = nil
  self.uiNumberOfTests = nil
  self.astrTestNames = nil
end


--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function TestDescription.__parseTests_StartElement(tParser, strName, atAttributes)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn, iPosAbs = tParser:pos()

  table.insert(aLxpAttr.atCurrentPath, strName)
  local strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
  aLxpAttr.strCurrentPath = strCurrentPath

  if strCurrentPath=='/MuhkuhTest' then
    local strTitle = atAttributes['title']
    local strSubtitle = atAttributes['subtitle']
    aLxpAttr.strTitle = strTitle
    aLxpAttr.strSubtitle = strSubtitle

  elseif strCurrentPath=='/MuhkuhTest/Testcase' then
    local strID = atAttributes['id']
    local strFile = atAttributes['file']
    local strName = atAttributes['name']
    if (strID==nil or strID=='') and (strFile==nil or strFile=='') then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: one of "id" or "file" must be present, but none found.', iPosLine, iPosColumn)
    elseif (strID~=nil and strID~='') and (strFile~=nil and strFile~='') then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: one of "id" or "file" must be present, but both found.', iPosLine, iPosColumn)
    elseif strName==nil or strName=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "name".', iPosLine, iPosColumn)
    else
      local tTestCase = {
        id = strID,
        file = strFile,
        name = strName,
        parameter = {}
      }
      aLxpAttr.tTestCase = tTestCase
      aLxpAttr.strParameterName = nil
      aLxpAttr.strParameterValue = nil
    end

  elseif strCurrentPath=='/MuhkuhTest/Testcase/Parameter' then
    local strName = atAttributes['name']
    if strName==nil or strName=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "name".', iPosLine, iPosColumn)
    else
      aLxpAttr.strParameterName = strName
    end

  elseif strCurrentPath=='/MuhkuhTest/Testcase/Connection' then
    local strName = atAttributes['name']
    if strName==nil or strName=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "name".', iPosLine, iPosColumn)
    else
      aLxpAttr.strParameterName = strName
    end
  end
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function TestDescription.__parseTests_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn, iPosAbs = tParser:pos()

  local strCurrentPath = aLxpAttr.strCurrentPath

  if strCurrentPath=='/MuhkuhTest/Testcase' then
    table.insert(aLxpAttr.atTestCases, aLxpAttr.tTestCase)
    aLxpAttr.tTestCase = nil
  elseif strCurrentPath=='/MuhkuhTest/Testcase/Parameter' then
    if aLxpAttr.strParameterName==nil then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "name".', iPosLine, iPosColumn)
    elseif aLxpAttr.strParameterValue==nil then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing value for parameter.', iPosLine, iPosColumn)
    else
      table.insert(aLxpAttr.tTestCase.parameter, {name=aLxpAttr.strParameterName, value=aLxpAttr.strParameterValue})
    end
  elseif strCurrentPath=='/MuhkuhTest/Testcase/Connection' then
    if aLxpAttr.strParameterName==nil then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "name".', iPosLine, iPosColumn)
    elseif aLxpAttr.strParameterConnection==nil then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing connection for parameter.', iPosLine, iPosColumn)
    else
      table.insert(aLxpAttr.tTestCase.parameter, {name=aLxpAttr.strParameterName, connection=aLxpAttr.strParameterConnection})
    end
  end

  table.remove(aLxpAttr.atCurrentPath)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function TestDescription.__parseTests_CharacterData(tParser, strData)
  local aLxpAttr = tParser:getcallbacks().userdata

  if aLxpAttr.strCurrentPath=="/MuhkuhTest/Testcase/Parameter" then
    aLxpAttr.strParameterValue = strData
  elseif aLxpAttr.strCurrentPath=="/MuhkuhTest/Testcase/Connection" then
    aLxpAttr.strParameterConnection = strData
  end
end



function TestDescription:__parse_tests(strTestsFile)
  local tResult = nil
  local tLog = self.tLog

  -- Read the complete file.
  local strFileData, strError = self.pl.utils.readfile(strTestsFile)
  if strFileData==nil then
    tLog.error('Failed to read the test configuration file "%s": %s', strTestsFile, strError)
  else
    local lxp = self.lxp

    local aLxpAttr = {
      -- Start at root ("/").
      atCurrentPath = {""},
      strCurrentPath = nil,

      strTitle = nil,
      strSubtitle = nil,
      tTestCase = nil,
      strParameterName = nil,
      strParameterValue = nil,
      strParameterConnection = nil,
      atTestCases = {},

      tResult = true,
      tLog = tLog
    }

    local aLxpCallbacks = {}
    aLxpCallbacks._nonstrict    = false
    aLxpCallbacks.StartElement  = self.__parseTests_StartElement
    aLxpCallbacks.EndElement    = self.__parseTests_EndElement
    aLxpCallbacks.CharacterData = self.__parseTests_CharacterData
    aLxpCallbacks.userdata      = aLxpAttr

    local tParser = lxp.new(aLxpCallbacks)

    local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strFileData)
    if tParseResult~=nil then
      tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
      if tParseResult~=nil then
        tParser:close()
      end
    end

    if tParseResult==nil then
      tLog.error('Failed to parse the test configuration "%s": %s in line %d, column %d, position %d.', strTestsFile, strMsg, uiLine, uiCol, uiPos)
    elseif aLxpAttr.tResult~=true then
      tLog.error('Failed to parse the test configuration.')
    else
      self.strTitle = aLxpAttr.strTitle
      self.strSubtitle = aLxpAttr.strSubtitle
      self.atTestCases = aLxpAttr.atTestCases
      tResult = true
    end
  end

  return tResult
end



function TestDescription:parse(strTestsFile)
  local tResult = true
  local pl = self.pl
  local tLog = self.tLog

  if pl.path.exists(strTestsFile)~=strTestsFile then
    tLog.error('The test configuration file "%s" does not exist.', strTestsFile)
    tResult = nil
  elseif pl.path.isfile(strTestsFile)~=true then
    tLog.error('The path "%s" is no regular file.', strTestsFile)
    tResult = nil
  else
    tLog.debug('Parsing tests file "%s".', strTestsFile)
    tResult = self:__parse_tests(strTestsFile)
    if tResult~=true then
      tLog.error('Failed to parse the test configuration file "%s".', strTestsFile)
      tResult = nil
    else
      local atTestCases = self.atTestCases

      -- Get the number of available test cases.
      self.uiNumberOfTests = table.maxn(atTestCases)

      -- Get a lookup table with the test names.
      local astrTestNames = {}
      for uiTestIndex, tTestCase in ipairs(atTestCases) do
        table.insert(astrTestNames, tTestCase.name)
      end
      self.astrTestNames = astrTestNames
    end
  end

  return tResult
end



function TestDescription:getTitle()
  return self.strTitle
end



function TestDescription:getSubtitle()
  return self.strSubtitle
end



function TestDescription:getNumberOfTests()
  return self.uiNumberOfTests
end



function TestDescription:getTestNames()
  return self.astrTestNames
end



function TestDescription:getTestCaseName(uiTestCase)
  local tLog = self.tLog
  local tResult

  -- Is the test case valid?
  local strType = type(uiTestCase)
  if strType=='number' then
    if uiTestCase>0 and uiTestCase<=self.uiNumberOfTests then
      tResult = self.astrTestNames[uiTestCase]
    else
      tLog.error('Invalid test case index for test cases 1 to %d: %d .', self.uiNumberOfTests, uiTestCase)
    end
  else
    tLog.error('The test case must be a number, here it has the type %s.', strType)
  end

  return tResult
end



function TestDescription:getTestCaseParameters(uiTestCase)
  local tLog = self.tLog
  local tResult

  -- Is the test case valid?
  local strType = type(uiTestCase)
  if strType=='number' then
    if uiTestCase>0 and uiTestCase<=self.uiNumberOfTests then
      tResult = self.atTestCases[uiTestCase].parameter
    else
      tLog.error('Invalid test case index for test cases 1 to %d: %d .', self.uiNumberOfTests, uiTestCase)
    end
  else
    tLog.error('The test case must be a number, here it has the type %s.', strType)
  end

  return tResult
end


return TestDescription
