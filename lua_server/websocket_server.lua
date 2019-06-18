require 'muhkuh_cli_init'

local pl = require'pl.import_into'()
local uv  = require"lluv"
uv.poll_zmq = require "lluv.poll_zmq"

-- This is the port for the websocket.
local usWebsocketPort = 12345

-- This number is used as the serial number in the SSDP responses.
local ulSystemSerial = 4321


-- Set the logger level from the command line options.
local strLogLevel = 'debug'
local cLogWriter = require 'log.writer.filter'.new(
  strLogLevel,
  require 'log.writer.console'.new()
)
local cLogWriterSystem = require 'log.writer.prefix'.new('[System] ', cLogWriter)
local tLog = require "log".new(
  -- maximum log level
  "trace",
  cLogWriterSystem,
  -- Formatter
  require "log.formatter.format".new()
)
tLog.info('Start')


local WebUiBuffer = require 'webui_buffer'
local webui_buffer = WebUiBuffer(tLog, usWebsocketPort)
webui_buffer:setTitle('NXHX90-R1', '7730.100')
webui_buffer:setSerials(true, nil, nil)
webui_buffer:setTestNames({})
webui_buffer:setInteraction(nil)
local tLogTest = webui_buffer:getLogTarget()
webui_buffer:start()

local ProcessKeepalive = require 'process_keepalive'
local ProcessZmq = require 'process_zmq'

local strLuaInterpreter = uv.exepath()

-- Create a new process.
tLog.debug('LUA interpreter: %s', strLuaInterpreter)
local tServerProc = ProcessKeepalive(tLog, strLuaInterpreter, {'server.lua', tostring(usWebsocketPort), tostring(ulSystemSerial)}, 3)


-- Create a new ZMQ process.
local tTestProc = ProcessZmq(tLog, tLogTest, strLuaInterpreter, {'dummy_test.lua', '${ZMQPORT}'})

tTestProc:setBuffer(webui_buffer)
webui_buffer:setTester(tTestProc)

tServerProc:run()
tTestProc:run()

local function OnCancelAll()
  print('Cancel pressed!')
  tServerProc:shutdown()
  tTestProc:shutdown()
end
uv.signal():start(uv.SIGINT, OnCancelAll)


uv.run(debug.traceback)
