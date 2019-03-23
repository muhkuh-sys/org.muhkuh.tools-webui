require 'muhkuh_cli_init'

local json = require 'dkjson'
local pl = require'pl.import_into'()
local uv  = require"lluv"
local ws  = require"lluv.websocket"
uv.poll_zmq = require "lluv.poll_zmq"

-- This is the port for the websocket.
local usWebsocketPort = 12345

-- Build the websocket URL. The protocol is "ws", so no encryption is used. The host is "*", so any interface works.
local strWebsocketURL = string.format('ws://*:%d', usWebsocketPort);
local strWebsocketProtocol = "muhkuh"

-- This number is used as the serial number in the SSDP responses.
local ulSystemSerial = 4321

local tActiveConnection = nil

local Server = require 'testerui_server'
local tServer = Server('Logger')


local function sendTitle(tConnection)
  local tMessage = {
    id = 'SetTitle',
    title = 'NXHX90-R1',
    subtitle = '7730.100',
    hasSerial = true,
    firstSerial = 20000,
    lastSerial = 20009
  }
  local strJson = json.encode(tMessage)
  tConnection:write(strJson, opcode)
end



local function sendInteraction(tConnection)
  local tFile = io.open('test.jsx', 'r')
  local strJsx = tFile:read('*a')
  tFile:close()
  local tMessage = {
    id = 'SetInteraction',
    jsx = strJsx
  }
  local strJson = json.encode(tMessage)
  tConnection:write(strJson, opcode)
end



local function connectionOnReceive(tConnection, err, strMessage, opcode)
  if err then
    print("Server read error, closing the connection:", err)
    tActiveConnection = nil
    return tConnection:close()
  else

    print("JSON: ", strMessage)
    local tJson, uiPos, strJsonErr = json.decode(strMessage)
    if tJson==nil then
      print ("JSON Error:", uiPos, tJsonErr)
    else
      local strId = tJson.id
      if strId==nil then
        print('Ignoring invalid message without "id".')
      else
        if strId=='ReqInit' then
          sendTitle(tConnection)
          sendInteraction(tConnection)

        elseif strId=='RspInteraction' then
          print('Interaction response received:')
          pl.pretty.dump(tJson)

        else
          print('Unknown message ID received.')
          pl.pretty.dump(tJson)
        end
      end
    end
  end
end



local function connectionHandshake(tConnection, err, protocol)
  if err then
    print("Server handshake error:", err)
    tActiveConnection = nil
    return tConnection:close()

  elseif tActiveConnection~=nil then
    print("Not accepting a second conncetion.")
    return tConnection:close()

  else
    print("New server connection:", protocol)
    tActiveConnection = tConnection

    tConnection:start_read(connectionOnReceive)
  end
end



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

local server = ws.new()
server:bind(strWebsocketURL, strWebsocketProtocol, function(self, err)
  if err then
    print("Server error:", err)
    tActiveConnection = nil
    return server:close()
  end

  server:listen(function(self, err)
    if err then
      print("Server listen:", err)
      tActiveConnection = nil
      return server:close()
    end

    local cli = server:accept()
    cli:handshake(connectionHandshake)
  end)
end)


local ProcessKeepalive = require 'process_keepalive'
local ProcessZmq = require 'process_zmq'

local strLuaInterpreter = uv.exepath()

-- Create a new process.
tLog.debug('LUA interpreter: %s', strLuaInterpreter)
local tServerProc = ProcessKeepalive(tLog, strLuaInterpreter, {'server.lua', tostring(usWebsocketPort), tostring(ulSystemSerial)}, 3)
tServerProc:run()


-- Create a new ZMQ process.
local tTestProc = ProcessZmq(tLog, strLuaInterpreter, {'dummy_test.lua', '${ZMQPORT}'})
tTestProc:run()

local function OnCancelAll()
  print('Cancel pressed!')
  tServerProc:shutdown()
  tTestProc:shutdown()
end
uv.signal():start(uv.SIGINT, OnCancelAll)


uv.run(debug.traceback)
