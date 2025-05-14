local class = require 'pl.class'
local _M = class()


function _M:_init(tLog, fActivateDebugging)
  self.tLog = tLog

  local ulid = require("ulid")
  self.ulid = ulid
  local socket = require("socket")
  ulid.set_time_func(socket.gettime)

  -- Create a new converter from ISO-8859-1 to UTF-8.
  local iconv = require 'iconv'
  self.iconv = iconv
  local tIConvUtf8 = iconv.new('UTF-8//TRANSLIT', 'ISO-8859-1')
  if tIConvUtf8==nil then
    tLog.error('Failed to create a new converter from ISO-8859-1 to UTF-8.')
  end
  self.tIConvUtf8 = tIConvUtf8

  self.m_tApi = require 'api'(tLog)

  self.m_fDebuggingIsActive = fActivateDebugging
  if fActivateDebugging==true then
    tLog.debug('Log debugging is active.')
  end

  self.m_atSystemAttributes = {}
  self.m_atAttributes = {}

  self.m_astrLogMessages = {}
  self.m_sizLogMessages = 0
  self.m_sizLogMessagesMax = 32768

  self.m_strUlidTestRun = nil
  self.m_strUlidTestStep = nil

  self.m_astrLogLevel = {
   [1] = 'EMERG',
   [2] = 'ALERT',
   [3] = 'FATAL',
   [4] = 'ERROR',
   [5] = 'WARNING',
   [6] = 'NOTICE',
   [7] = 'INFO',
   [8] = 'DEBUG',
   [9] = 'TRACE'
  }

  self.strTopic_logs = 'muhkuh-production-logs-v2'
  self.strTopic_events = 'muhkuh-production-events-v2'

  --- @alias MessageQueueElement { topic: string, msg: string }
  --- @type MessageQueueElement[]
  self.astrMessageQueue = {}

  local uiDeliverInervalMS = 1000
  local this = self
  local uv  = require 'lluv'
  self.m_tDeliverTimer = uv.timer():start(uiDeliverInervalMS, function(tTimer)
    this:__flushMessages(250)
    tTimer:again(uiDeliverInervalMS)
  end)

  --- @type boolean
  self.fDisableLogging = false
  if fActivateDebugging==true then
    self.tTopic_teststations_cnt = 0
    self.tTopic_logs_cnt = 0
    self.tTopic_events_cnt = 0
    local strPath = '/tmp/muhkuh-production-teststations-%03d.json'
    self.tTopic_teststations_template = strPath
    tLog.debug('Write messages for the testatations topic to: %s', strPath)

    strPath = '/tmp/muhkuh-production-logs-v2-%03d.json'
    self.tTopic_logs_template = strPath
    tLog.debug('Write messages for the logs topic to: %s', strPath)

    strPath = '/tmp/muhkuh-production-events-v2-%03d.json'
    self.tTopic_events_template = strPath
    tLog.debug('Write messages for the events topic to: %s', strPath)
  end
end


--- Encode an ISO-8859-1 string to UTF-8.
--- @param strMsg string The string to encode.
--- @return string|nil, nil|string
function _M:__toUtf8(strMsg)
  local iconv = self.iconv
  local tIConvUtf8 = self.tIConvUtf8
  local tLog = self.tLog

  -- Logging in the wrong encoding is still better than no logging. %-(
  if tIConvUtf8~=nil then
    -- Convert the data from ISO-8859-1 to UTF-8.
    local strMsgConv, tError = tIConvUtf8:iconv(strMsg)
    if strMsgConv==nil then
      local strError
      if tError==iconv.ERROR_NO_MEMORY then
        strError = 'Failed to allocate enough memory in the conversion process.'
      elseif tError==iconv.ERROR_INVALID then
        strError = 'An invalid character was found in the input sequence.'
      elseif tError==iconv.ERROR_INCOMPLETE then
        strError = 'An incomplete character was found in the input sequence.'
      elseif tError==iconv.iconv.ERROR_FINALIZED then
        strError = 'Trying to use an already-finalized converter. ' ..
                   'This usually means that the user was tweaking the garbage collector private methods.'
      else
        strError = 'Unknown error.'
      end
      tLog.error('UTF-8 conversion failed: %s', strError)
    else
      strMsg = strMsgConv
    end
  end

  return strMsg
end



function _M:__flushMessages(uiTimeoutMS)
  local tLog = self.tLog
  local tApi = self.m_tApi
  local astrMessageQueue = self.astrMessageQueue

  -- Try to deliver messages until the timeout is reached or the queue is empty.
  local socket = require 'socket'
  local tTimeEnd = socket.gettime() + uiTimeoutMS/1000
  while socket.gettime()<tTimeEnd do
    -- Stop if the queue is empty.
    if #astrMessageQueue==0 then
      break

    else
      local tItem = astrMessageQueue[1]
      local tPostResult, strPostError = tApi:post(
        '/v2/api/kafka/deliver/' .. tostring(tItem.topic),
        tItem.msg
      )
      if tPostResult==nil then
        tLog.error('Failed to deliver a message: ' .. tostring(strPostError))
        break

      else
        -- Remove the processed message from the queue.
        table.remove(astrMessageQueue, 1)
      end
    end
  end
end



function _M:__sendMessage(strTopic, strMessage)
  -- Append the message to the end of the queue.
  table.insert(
    self.astrMessageQueue,
    {
      topic = strTopic,
      msg = strMessage
    }
  )

  -- Try to send a few messages.
  self:__flushMessages(2)
end



function _M:setSystemAttributes(atSystemAttributes)
  self.m_atSystemAttributes = atSystemAttributes

  -- Make a copy of the attributes.
  local tablex = require 'pl.tablex'
  self.m_atAttributes = tablex.deepcopy(atSystemAttributes)
end



function _M:announceInstance(atAttributes)
  local tLog = self.tLog

  -- Send the heartbeat to the API.
  local tPostResult, strPostError = self.m_tApi:post('/v2/api/teststation/heartbeat/%%TESTSTATIONID%%', atAttributes)
  if tPostResult==nil then
    tLog.error('Failed to deliver heartbeat: ' .. tostring(strPostError))
  end
end



function _M:__getNewUlid()
  return self.ulid.ulid()
end



function _M:__sendMessageBuffer()
  -- Is something in the buffer?
  if self.m_sizLogMessages~=0 then
    -- Get all log messages.
    local strMsg = table.concat(self.m_astrLogMessages)
    -- Create a new message.
    local atAttr = self.m_atAttributes
    atAttr.log = strMsg
    local dkjson = require 'dkjson'
    local strJson = self:__toUtf8(dkjson.encode(atAttr))
    atAttr.log = nil

    -- Send the message to the topic.
    local strTopic = self.strTopic_logs
    if strTopic~=nil and self.fDisableLogging~=true then
      self:__sendMessage(strTopic, strJson)
    end

    -- Write the message to a temp file.
    if self.m_fDebuggingIsActive==true then
      local tFile = io.open(string.format(self.tTopic_logs_template, self.tTopic_logs_cnt), 'w')
      if tFile~=nil then
        tFile:write(strJson)
        tFile:close()
      end
      self.tTopic_logs_cnt = self.tTopic_logs_cnt + 1
    end
  end

  self.m_astrLogMessages = {}
  self.m_sizLogMessages = 0
end



function _M:__sendEvent(strEventId, atAttributes)
  -- Create a new message.
  local atAttr = self.m_atAttributes
  atAttr.event = strEventId
  atAttr.eventAttr = atAttributes
  local date = require 'date'
  atAttr.timestamp = date(false):fmt('%Y-%m-%d %H:%M:%S')
  local dkjson = require 'dkjson'
  local strJson = self:__toUtf8(dkjson.encode(atAttr))
  atAttr.event = nil
  atAttr.eventAttr = nil
  atAttr.timestamp = nil

  -- Send the event to the topic.
  local strTopic = self.strTopic_events
  if strTopic~=nil and self.fDisableLogging~=true then
    self:__sendMessage(strTopic, strJson)
  end

  -- Write the event to a temp file.
  if self.m_fDebuggingIsActive==true then
    local tFile = io.open(string.format(self.tTopic_events_template, self.tTopic_events_cnt), 'w')
    if tFile~=nil then
      tFile:write(strJson)
      tFile:close()
    end
    self.tTopic_events_cnt = self.tTopic_events_cnt + 1
  end
end



function _M:disableLogging(fDisableLogging)
  -- Convert the parameter to boolean.
  fDisableLogging = (fDisableLogging == true)
  -- Store the parameter.
  self.fDisableLogging = fDisableLogging
end



function _M:onLogMessage(uiLogLevel, strLogMessage)
  local sizLogMessagesMax = self.m_sizLogMessagesMax
  local astrLogMessages = self.m_astrLogMessages

  -- Get the log level as a string.
  local strLogLevel = self.m_astrLogLevel[uiLogLevel]
  if strLogLevel==nil then
    strLogLevel = tostring(uiLogLevel)
  end

  -- Combine the pretty-print level with the log message.
  local date = require 'date'
  local strMsg = date(false):fmt('%Y-%m-%d %H:%M:%S')..' ['..strLogLevel..'] '..tostring(strLogMessage)
  local sizMsg = string.len(strMsg)

  -- Does the new log message fit into the buffer?
  if (self.m_sizLogMessages+sizMsg)>sizLogMessagesMax then
    -- Flush the message buffer.
    self:__sendMessageBuffer()

    -- Chunk the new message.
    repeat
      -- Get the size of the next chunk.
      local sizChunk = sizMsg
      -- Does the chunk fit into the buffer?
      if sizChunk>sizLogMessagesMax then
        sizChunk = sizLogMessagesMax
        -- Add a part of the message to the buffer.
        table.insert(astrLogMessages, string.sub(strMsg, 1, sizChunk))
        -- Update the size of the buffer.
        self.m_sizLogMessages = self.m_sizLogMessages + sizChunk

        -- Flush the buffer.
        self:__sendMessageBuffer()

        sizMsg = sizMsg - sizChunk
        strMsg = string.sub(strMsg, sizChunk+1)
      else
        -- Add the complete message to the buffer.
        table.insert(astrLogMessages, strMsg)
        -- Update the size of the buffer.
        self.m_sizLogMessages = self.m_sizLogMessages + sizMsg

        sizMsg = 0
      end
    until sizMsg==0
  else
    -- The new message fits into the buffer.
    table.insert(astrLogMessages, strMsg)
    -- Update the size of the buffer.
    self.m_sizLogMessages = self.m_sizLogMessages + sizMsg
  end
end



function _M:onEvent(strEventId, tEventAttributes)
  self:__sendEvent(strEventId, tEventAttributes)
end



function _M:onTestStepStarted(uiStepIndex, strTestCaseId, strTestCaseName, atLogAttributes)
  -- Send any waiting messages.
  self:__sendMessageBuffer()

  -- Create a new ULID for the test step.
  local strUlidTestStep = self:__getNewUlid()
  self.m_strUlidTestStep = strUlidTestStep

  -- Make a copy of the attributes.
  local tablex = require 'pl.tablex'
  local atAttributes = tablex.deepcopy(atLogAttributes)
  tablex.update(atAttributes, self.m_atSystemAttributes)

  -- Append the ULID for the test run.
  atAttributes.test_run_ulid = self.m_strUlidTestRun
  -- Append the test step.
  atAttributes.test_step = uiStepIndex
  -- Append the test ID and name.
  atAttributes.test_id = strTestCaseId
  atAttributes.test_name = strTestCaseName
  -- Append the ULID for the test step.
  atAttributes.test_step_ulid = strUlidTestStep

  self.m_atAttributes = atAttributes
end



function _M:onTestStepFinished()
  -- Send any waiting messages.
  self:__sendMessageBuffer()

  local atAttributes = self.m_atAttributes

  self.m_strUlidTestStep = nil

  -- Remove the test step from the attributes.
  atAttributes.test_step = nil
  -- Remove the test ID and name.
  atAttributes.test_id = nil
  atAttributes.test_name = nil
  -- Remove the test step ULID from the attributes.
  atAttributes.test_step_ulid = nil
end



function _M:onTestRunStarted(atLogAttributes)
  -- Send any waiting messages.
  self:__sendMessageBuffer()

  -- Create a new ULID for the test.
  local strUlidTestRun = self:__getNewUlid()
  self.m_strUlidTestRun = strUlidTestRun
  -- Clear any old ULID for the test step.
  self.m_strUlidTestStep = nil

  -- Make a copy of the attributes.
  local tablex = require 'pl.tablex'
  local atAttributes = tablex.deepcopy(atLogAttributes)
  tablex.update(atAttributes, self.m_atSystemAttributes)

  -- Append the ULID for the test run.
  atAttributes.test_run_ulid = strUlidTestRun

  self.m_atAttributes = atAttributes
end



function _M:onTestRunFinished()
  -- Send any waiting messages.
  self:__sendMessageBuffer()

  local atAttributes = self.m_atAttributes

  self.m_strUlidTestRun = nil
  self.m_strUlidTestStep = nil

  -- Remove the test run ULID from the attributes.
  atAttributes.test_run_ulid = nil
  -- Remove the test step from the attributes.
  atAttributes.test_step = nil
  -- Remove the test step ULID from the attributes.
  atAttributes.test_step_ulid = nil
end



function _M:shutdown()
  -- Stop the deliver timer.
  local tDeliverTimer = self.m_tDeliverTimer
  if tDeliverTimer~=nil then
    tDeliverTimer:stop()
    tDeliverTimer:close()
    self.m_tDeliverTimer = nil
  end

  -- Try to flush any leftovers in the message queue for 2000ms.
  self:__flushMessages(2000)
end


return _M
