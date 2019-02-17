require 'muhkuh_cli_init'

local json = require 'dkjson'
local pl = require'pl.import_into'()
local uv  = require"lluv"
local ws  = require"lluv.websocket"

local wsurl = "ws://127.0.0.1:12345"
local sprot = "echo"

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
local cLog = require "log".new(
  -- maximum log level
  "trace",
  cLogWriterSystem,
  -- Formatter
  require "log.formatter.format".new()
)
cLog.info('Start')

local server = ws.new()
server:bind(wsurl, sprot, function(self, err)
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

------------------------------------------------------------------------------
--
-- Process test
--
local class = require 'pl.class'
local Process = class()

function Process:_init(strCommand, astrArguments)
  self.strCommand = strCommand
  self.astrArguments = astrArguments

  self.pl = require'pl.import_into'()
  self.uv = require 'lluv'

  self.STATE_Idle = 0
  self.STATE_Running = 1
  self.STATE_RequestedShutdown = 2
  self.STATE_Killing = 3
  self.STATE_Terminated = 4

  self.tState = self.STATE_Idle
  self.tProc = nil
  self.tPipeStdOut = nil
  self.tPipeStdErr = nil
  self.fRequestedShutdown = false
  self.tShutdownTimer = nil
end


function Process:run()
  local tResult

  if (self.tState==self.STATE_Idle) or (self.tState==self.STATE_Terminated) then
    local this = self

    -- Create pipes for the new process.
    local tPipeStdOut = uv.pipe(false)
    local tPipeStdErr = uv.pipe(false)

    -- Start a new process.
    local tProc = uv.spawn(
      {
        file = self.strCommand,
        args = self.astrArguments,
        stdio = {
          -- STDIN
          {},
          -- STDOUT
          {
            flags = uv.CREATE_PIPE + uv.WRITABLE_PIPE,
            stream = tPipeStdOut
          },
          -- STDERR
          {
            flags = uv.CREATE_PIPE + uv.WRITABLE_PIPE,
            stream = tPipeStdErr
          }
        }
      },
      function(tHandle, strError, tExitStatus, tTermSignal)
        this:onClose(tHandle, strError, tExitStatus, tTermSignal)
      end
    )
    tPipeStdOut:start_read(function(tHandle, strError, strData) this:onStdOut(tHandle, strError, strData) end)
    tPipeStdErr:start_read(function(tHandle, strError, strData) this:onStdErr(tHandle, strError, strData) end)

    self.tProc = tProc
    self.tPipeStdOut = tPipeStdOut
    self.tPipeStdErr = tPipeStdErr

    self.tState = self.STATE_Running

    tResult = true
  else
    print('Not starting as not idle or terminated.')
  end

  return tResult
end



function Process:shutdown()
  self.fRequestedShutdown = true
  self.tProc:kill(uv.SIGHUP)

  self.tShutdownTimer = self.uv.timer():start(2000, function(tHandle)
    tHandle:close()
    self.tShutdownTimer = nil
    self.tProc:kill(uv.SIGKILL)
  end)
end



function Process:onClose(tHandle, err, exit_status, term_signal)
  if tHandle==self.tProc then
    tHandle:close()

    -- Stop 
    local tShutdownTimer = self.tShutdownTimer
    if tShutdownTimer~=nil then
      tShutdownTimer:close()
      self.tShutdownTimer = nil
    end

    self.tState = self.STATE_Terminated

    print('Process terminated:', err, exit_status, term_signal)

    -- Did the process terminate on request?
    if self.fRequestedShutdown==false then
      -- No -> restart the process.
      print('Restarting')
      self:run()
    end
  else
    print('Unknown process handle')
  end
end



function Process:onStdOut(tHandle, strError, strData)
  if tHandle==self.tPipeStdOut then
    if strError==nil then
      print('STDOUT:', strData)
    else
      print('Closing STDOUT:', strError)
      tHandle:close()
      self.tPipeStdOut = nil
    end
  else
    print('Invalid handle for STDOUT.')
  end
end



function Process:onStdErr(tHandle, strError, strData)
  if tHandle==self.tPipeStdErr then
    if strError==nil then
      print('STDERR:', strData)
    else
      print('Closing STDERR:', strError)
      tHandle:close()
      self.tPipeStdErr = nil
    end
  else
    print('Invalid handle for STDERR.')
  end
end



-- Create a new process.
local strLuaInterpreter = uv.exepath()
cLog.debug('LUA interpreter: %s', strLuaInterpreter)
local tTestProc = Process(strLuaInterpreter, {'server.lua'})
tTestProc:run()


local function OnCancelAll()
  print('Cancel pressed!')
  tTestProc:shutdown()
end
uv.signal():start(uv.SIGINT, OnCancelAll)


uv.run(debug.traceback)
