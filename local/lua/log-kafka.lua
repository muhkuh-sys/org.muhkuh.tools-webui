local class = require 'pl.class'
local LogKafka = class()


function LogKafka:_init(tLog)
  self.dkjson = require 'dkjson'

  local kafka = require 'kafka'
  tLog.info('Using kafka %s', kafka.version())
  self.kafka = kafka

  self.tLog = tLog

  local strBrokerList = 'reportportal01.hilscher.local:9092'

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
end



function LogKafka:registerInstance(atAttributes)
  local tLog = self.tLog
  local uiCnt = self.tTopic_teststations_cnt
  local tTopic = self.tTopic_teststations

  -- Convert the attributes to JSON.
  local strJson = self.dkjson.encode(atAttributes)
  tLog.alert('data:', strJson)
  tTopic:send(-1, uiCnt, strJson)
  self.tTopic_teststations_cnt = uiCnt + 1

  tTopic:poll(-1)
end



return LogKafka


--[[
local kafka = require 'kafka'
print('Using kafka ' .. kafka.version())

local date = require 'date'

local brokerlist    = "localhost:9092"
local producer_conf = {
    ["queue.buffering.max.messages"] = 20000,
    ["batch.num.messages"] = 200,
    ["message.max.bytes"] = 1024 * 1024,
    ["queue.buffering.max.ms"] = 10,
    ["topic.metadata.refresh.interval.ms"] = -1,
}
local tProducer = kafka.Producer(brokerlist, producer_conf)

-- Create the topic if it does not exist yet.
local tTopic1 = tProducer:create_topic('test-log')

-- Produce some demo messages.
for uiCnt=0,10 do
  local strMsg = string.format('Test %d %s', uiCnt, tostring(date(false)))
  local ret = tTopic1:send(-1, uiCnt, strMsg)
  print(ret)

  local sequence_id, failures = tTopic1:poll(-1)
  print(sequence_id, failures)
end

]]--