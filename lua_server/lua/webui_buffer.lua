local class = require 'pl.class'
local WebUiBuffer = class()


function WebUiBuffer:_init(tLog, usWebsocketPort)
  self.tLog = tLog
  self.usWebsocketPort = usWebsocketPort
  self.strWebsocketProtocol = 'muhkuh'
  self.strWebsocketURL = string.format('ws://*:%d', usWebsocketPort)

  self.json = require 'dkjson'
  self.pl = require'pl.import_into'()
  local uv = require 'lluv'
  self.uv = uv
  self.ws  = require"lluv.websocket"

  self.tActiveConnection = nil
  self.strInteractionJsx = nil
  self.tServer = nil

  self.strTitle = ''
  self.strSubTitle = ''
  self.fHasSerial = false
  self.uiFirstSerial = 0
  self.uiLastSerial = 0

  self.astrTestNames = {}
  self.astrTestStati = {}

  self.astrLogMessages = {}
  self.uiSyncedLogIndex = 0

  self.tTester = nil

  -- Create a new log target for the test output.
  local this = self
  self.tLogWebUi = require "log".new(
    -- maximum log level
    'debug',
    function(fmt, msg, lvl, now) this:__onLogMessage(fmt, msg, lvl, now) end,
    -- Formatter
    require "log.formatter.format".new()
  )

  self.tLogTimer = uv.timer()
  self.uiLogTimerMs = 500
end



function WebUiBuffer:__onLogTimer(tTimer)
  local tConnection = self.tActiveConnection
  if tConnection~=nil then
    -- Are new log messages waiting?
    local astrLogMessages = self.astrLogMessages
    local uiLogMessages = table.maxn(astrLogMessages)
    local uiSyncedLogIndex = self.uiSyncedLogIndex

    if uiSyncedLogIndex<uiLogMessages then
      local l = {}
      for uiCnt=uiSyncedLogIndex+1, uiLogMessages, 1 do
        table.insert(l, astrLogMessages[uiCnt])
      end

      local tMessage = {
        id = 'Log',
        lines = l
      }
      local strJson = self.json.encode(tMessage)
      tConnection:write(strJson)

      print('LOG:', strJson)

      self.uiSyncedLogIndex = uiLogMessages
    end

    tTimer:again(self.uiLogTimerMs)
  end
end



function WebUiBuffer:__onLogMessage(fnFormat, strMessage, uiLevel, tDate)
  table.insert(self.astrLogMessages, string.format('%d,%s', uiLevel, fnFormat(strMessage, uiLevel, tDate)))
end



function WebUiBuffer:getLogTarget()
  return self.tLogWebUi
end



function WebUiBuffer:getWebsocketURL()
  return self.strWebsocketURL
end



function WebUiBuffer:setTitle(strTitle, strSubTitle)
  strTitle = tostring(strTitle)
  strSubTitle = tostring(strSubTitle)

  -- Did the title or subtitle change?
  local fChanged = (self.strTitle~=strTitle) or (self.strSubTitle~=strSubTitle)
  if fChanged==true then
    -- Yes, the title or subtitle changed.

    -- Accept the new values.
    self.strTitle = strTitle
    self.strSubTitle = strSubTitle

    -- Push the new values to the UI if there is a connection.
    self:__sendTitle()
  end
end



function WebUiBuffer:setSerials(fHasSerial, uiFirstSerial, uiLastSerial)
  fHasSerial = (fHasSerial==true)
  uiFirstSerial = tonumber(uiFirstSerial)
  uiLastSerial = tonumber(uiLastSerial)

  -- Did something change?
  local fChanged = (self.fHasSerial~=fHasSerial) or (self.uiFirstSerial~=uiFirstSerial) or (self.uiLastSerial~=uiLastSerial)
  if fChanged==true then
    -- Yes, something changed.

    -- Accept the new values.
    self.fHasSerial = fHasSerial
    self.uiFirstSerial = uiFirstSerial
    self.uiLastSerial = uiLastSerial

    -- Push the new values to the UI if there is a connection.
    self:__sendTitle()
  end
end



function WebUiBuffer:setTestNames(astrTestNames)
  local strType = type(astrTestNames)
  if strType~='table' then
    self.tLogWebUi.error('The argument to "setTestNames" must be an array. Here it is %s.', strType)
  else
    -- Copy the test names and set the state to the default.
    local astrNames = {}
    local astrStati = {}
    for _,tName in ipairs(astrTestNames) do
      table.insert(astrNames, tostring(tName))
      table.insert(astrStati, 'idle')
    end

    -- Accept the new values.
    self.astrTestNames = astrNames
    self.astrTestStati = astrStati

    -- Push the new values to the UI if there is a connection.
    self:__sendTestNames()
  end
end



function WebUiBuffer:setInteraction(strJsx)
  if strJsx==nil then
    strJsx = ''
  else
    strJsx = tostring(strJsx)
  end

  -- Did the interaction change?
  local fChanged = (self.strInteractionJsx~=strJsx)
  if fChanged==true then
    -- Yes, it changed.

    -- Accept the new code.
    self.strInteractionJsx = strJsx

    -- Push the code to the UI if there is a connection.
    self:__sendInteraction()
  end
end



function WebUiBuffer:__sendTitle()
  -- Push the values to the UI if there is a connection.
  local tConnection = self.tActiveConnection
  if tConnection~=nil then
    local tMessage = {
      id = 'SetTitle',
      title = self.strTitle,
      subtitle = self.strSubTitle,
      hasSerial = self.fHasSerial,
      firstSerial = self.uiFirstSerial,
      lastSerial = self.uiLastSerial
    }
    local strJson = self.json.encode(tMessage)
    tConnection:write(strJson)
  end
end



function WebUiBuffer:__sendTestNames()
  -- Push the values to the UI if there is a connection.
  local tConnection = self.tActiveConnection
  if tConnection~=nil then
    local tMessage = {
      id = 'SetTestNames',
      testNames = self.astrTestNames
    }
    local strJson = self.json.encode(tMessage)
    tConnection:write(strJson)
  end
end



function WebUiBuffer:__sendInteraction()
  local tConnection = self.tActiveConnection
  if tConnection~=nil then
    local tMessage = {
      id = 'SetInteraction',
      jsx = self.strInteractionJsx
    }
    local strJson = self.json.encode(tMessage)
    tConnection:write(strJson)
  end
end



function WebUiBuffer:__connectionOnReceive(tConnection, err, strMessage, opcode)
  if err then
    self.tLog.error('Server read error, closing the connection: %s', tostring(err))
    self.tActiveConnection = nil
    self.uiSyncedLogIndex = 0
    self.tLogTimer:stop()
    return tConnection:close()
  else
    self.tLog.debug('__connectionOnReceive: %s %s', tostring(tConnection), tostring(self.tActiveConnection))
    self.tLog.debug('JSON: "%s"', strMessage)

    local tTester = self.tTester

    local tJson, uiPos, strJsonErr = self.json.decode(strMessage)
    if tJson==nil then
      self.tLog.error('JSON Error: %d %s', uiPos, strJsonErr)
    else
      local strId = tJson.id
      if strId==nil then
        self.tLog.error('Ignoring invalid message without "id".')
      else
        if strId=='ReqInit' then
          self:__sendTitle()
          self:__sendTestNames()
          self:__sendInteraction()

        elseif strId=='RspInteraction' then
          if tTester~=nil then
            tTester:setInteractionResponse(strMessage)
          end
        else
          print('Unknown message ID received.')
          self.pl.pretty.dump(tJson)
        end
      end
    end
  end
end



function WebUiBuffer:__connectionHandshake(tConnection, err, protocol)
  if err then
    self.tLog.error('Server handshake error: %s', tostring(err))
    self.tActiveConnection = nil
    self.uiSyncedLogIndex = 0
    self.tLogTimer:stop()
    return tConnection:close()

  elseif self.tActiveConnection~=nil then
    self.tLog.notice('Not accepting a second conncetion.')
    return tConnection:close()

  else
    self.tLog.info('New server connection: %s', tostring(protocol))
    self.tActiveConnection = tConnection
    local this = self
    self.tLogTimer:start(self.uiLogTimerMs, function(tTimer) this:__onLogTimer(tTimer) end)
    tConnection:start_read(function(tConnection, err, strMessage, opcode) this:__connectionOnReceive(tConnection, err, strMessage, opcode) end)
  end
end



function WebUiBuffer:__onAccept(tSomething, tError)
  if tError then
    self.tLog.error("Server listen: %s", tError)
    self.tActiveConnection = nil
    return self.tServer:close()
  else
    local cli = self.tServer:accept()
    local this = self
    cli:handshake(function(tConnection, err, protocol) this:__connectionHandshake(tConnection, err, protocol) end)
  end
end



function WebUiBuffer:__onCreate(tSomething, tError)
  if tError then
    self.tLog.error("Server error: %s", tostring(tError))
    self.tActiveConnection = nil
    self.uiSyncedLogIndex = 0
    return self.tServer:close()
  else
    local this = self
    self.tServer:listen(function(tSomething, tError) this:__onAccept(tSomething, tError) end)
  end
end



function WebUiBuffer:setTester(tTester)
  self.tTester = tTester
end



function WebUiBuffer:start()
  self.tServer = self.ws.new()

  local this = self
  self.tServer:bind(self.strWebsocketURL, self.strWebsocketProtocol, function(tSomething, tError) this:__onCreate(tSomething, tError) end)
end



return WebUiBuffer