local class = require 'pl.class'
local LogKafka = class()


function LogKafka:_init(tLog, tSystemAttributes)
  self.date = require 'date'
  self.dkjson = require 'dkjson'

  local kafka = require 'kafka'
  tLog.info('Using kafka %s', kafka.version())
  self.kafka = kafka

  local pl = require'pl.import_into'()
  self.pl = pl

  self.tLog = tLog

  local ulid = require("ulid")
  self.ulid = ulid
  local socket = require("socket")
  ulid.set_time_func(socket.gettime)

  self.m_atSystemAttributes = tSystemAttributes
  self.m_atAttributes = nil


  -- Make a copy of the attributes.
  local atAttributes = pl.tablex.deepcopy(tSystemAttributes)
  -- Append a placeholder for the log message.
  atAttributes.log = '%s'
  self.m_strMessageTemplate = self.dkjson.encode(atAttributes)


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

--  local strBrokerList = 'reportportal01.hilscher.local:9092'
  self.m_strBrokerList = nil

  self.tProducer = nil
  self.tTopic_teststations = nil
  self.tTopic_teststations_cnt = 0
  self.tTopic_logs = nil
  self.tTopic_logs_cnt = 0
end



function LogKafka:connect(strBrokerList)
  local tLog = self.tLog
  local kafka = self.kafka

  if self.m_strBrokerList~=nil then
    tLog.alert('Refusing to connect an already connected instance.')
  else
    if strBrokerList~=nil then
      local tProducer_conf = {
        ["queue.buffering.max.messages"] = 20000,
        ["batch.num.messages"] = 200,
        ["message.max.bytes"] = 1024 * 1024,
        ["queue.buffering.max.ms"] = 10,
        ["topic.metadata.refresh.interval.ms"] = -1,
      }

      local tProducer = kafka.Producer(strBrokerList, tProducer_conf)
      self.tProducer = tProducer

      self.tTopic_teststations = tProducer:create_topic('muhkuh-production-teststations')
      self.tTopic_teststations_cnt = 0

      self.tTopic_logs = tProducer:create_topic('muhkuh-production-logs')
      self.tTopic_logs_cnt = 0

      self.m_strBrokerList = strBrokerList
    end
  end
end



function LogKafka:registerInstance(atAttributes)
  local tTopic = self.tTopic_teststations
  if tTopic~=nil then
    local pl = self.pl

    -- Merge the attributes with the system attributes.
    local atAttrMerged = pl.tablex.deepcopy(atAttributes)
    pl.tablex.insertvalues(atAttrMerged, self.m_atSystemAttributes)

    -- Convert the attributes to JSON.
    local strJson = self.dkjson.encode(atAttrMerged)
    tTopic:send(-1, uiCnt, strJson)
    local uiCnt = self.tTopic_teststations_cnt
    self.tTopic_teststations_cnt = uiCnt + 1

    tTopic:poll(-1)
  end
end



function LogKafka:__getNewUlid()
  return self.ulid.ulid()
end



function LogKafka:__sendMessageBuffer()
  local astrLogMessages = self.m_astrLogMessages

  -- Is something in the buffer?
  if self.m_sizLogMessages~=0 then
    -- Get all log messages.
    local strMsg = table.concat(astrLogMessages)
    -- Create a new message.
    local strJson = string.format(self.m_strMessageTemplate, strMsg)

    -- DEBUG: Write this to a temp file.
    local tFile = io.open(string.format('/tmp/message%03d.json', self.tTopic_logs_cnt), 'w')
    tFile:write(strJson)
    tFile:close()
    self.tTopic_logs_cnt = self.tTopic_logs_cnt + 1
  end

  self.m_astrLogMessages = {}
  self.m_sizLogMessages = 0
end



function LogKafka:onLogMessage(uiLogLevel, strLogMessage)
  local date = self.date
  local sizLogMessagesMax = self.m_sizLogMessagesMax
  local astrLogMessages = self.m_astrLogMessages

  -- Get the log level as a string.
  local strLogLevel = self.m_astrLogLevel[uiLogLevel]
  if strLogLevel==nil then
    strLogLevel = tostring(uiLogLevel)
  end

  -- Combine the pretty-print level with the log message.
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



function LogKafka:onTestStepStarted(uiStepIndex, strTestCaseId, strTestCaseName, atLogAttributes)
  local pl = self.pl

  -- Send any waiting messages.
  self:__sendMessageBuffer()

  -- Create a new ULID for the test step.
  local strUlidTestStep = self:__getNewUlid()
  self.m_strUlidTestStep = strUlidTestStep

  -- Make a copy of the attributes.
  local atAttributes = pl.tablex.deepcopy(atLogAttributes)
  pl.tablex.update(atAttributes, self.m_atSystemAttributes)

  -- Append the ULID for the test run.
  atAttributes.test_run_ulid = self.m_strUlidTestRun
  -- Append the test step.
  atAttributes.test_step = uiStepIndex
  -- Append the test ID and name.
  atAttributes.test_id = strTestCaseId
  atAttributes.test_name = strTestCaseName
  -- Append the ULID for the test step.
  atAttributes.test_step_ulid = strUlidTestStep
  -- Append a placeholder for the log message.
  atAttributes.log = '%s'

  self.m_atAttributes = atAttributes
  self.m_strMessageTemplate = self.dkjson.encode(atAttributes)
end



function LogKafka:onTestStepFinished()
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

  -- Update the template.
  self.m_strMessageTemplate = self.dkjson.encode(atAttributes)
end



function LogKafka:onTestRunStarted(atLogAttributes)
  local pl = self.pl

  -- Send any waiting messages.
  self:__sendMessageBuffer()

  -- Create a new ULID for the test.
  local strUlidTestRun = self:__getNewUlid()
  self.m_strUlidTestRun = strUlidTestRun
  -- Clear any old ULID for the test step.
  self.m_strUlidTestStep = nil

  -- Make a copy of the attributes.
  local atAttributes = pl.tablex.deepcopy(atLogAttributes)
  pl.tablex.update(atAttributes, self.m_atSystemAttributes)

  -- Append the ULID for the test run.
  atAttributes.test_run_ulid = strUlidTestRun
  -- Append a placeholder for the log message.
  atAttributes.log = '%s'

  self.m_atAttributes = atAttributes
  self.m_strMessageTemplate = self.dkjson.encode(atAttributes)
end



function LogKafka:onTestRunFinished()
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

  -- Update the template.
  self.m_strMessageTemplate = self.dkjson.encode(atAttributes)
end



return LogKafka
