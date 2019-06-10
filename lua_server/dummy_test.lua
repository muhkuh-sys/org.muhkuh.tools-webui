require 'muhkuh_cli_init'

local pl = require'pl.import_into'()

local zmq = require 'lzmq'

-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

local usServerPort = tonumber(arg[1])

m_zmqPort = usServerPort
strAddress = string.format('tcp://127.0.0.1:%d', usServerPort)
print(string.format("Connecting to %s", strAddress))

-- Create the 0MQ context.
local zmq = require 'lzmq'
local tZContext, strError = zmq.context()
if tZContext==nil then
  error('Failed to create ZMQ context: ' .. tostring(strError))
end
m_zmqContext = tZContext

-- Create the socket.
local tZSocket, strError = tZContext:socket(zmq.PAIR)
if tZSocket==nil then
  error('Failed to create ZMQ socket: ' .. tostring(strError))
end

-- Connect the socket to the server.
local tResult, strError = tZSocket:connect(strAddress)
if tResult==nil then
  error('Failed to connect the socket: ' .. tostring(strError))
end
m_zmqSocket = tZSocket

print(string.format('0MQ socket connected to tcp://127.0.0.1:%d', usServerPort))


------------------------------------------------------------------------------
-- Now create the logger. It sends the data to the ZMQ socket.
-- It does not use the formatter function 'fmt' or the date 'now'. This is
-- done at the server side.
local tLogWriterFn = function(fmt, msg, lvl, now)
  m_zmqSocket:send(string.format('LOG%d,%s', lvl, msg))
end

-- Create a new log target with "SYSTEM" prefix.
local tLogSystem = require "log".new(
  -- maximum log level
  'debug',
  tLogWriterFn,
  -- Formatter
  require "log.formatter.format".new()
)
------------------------------------------------------------------------------


for iCnt=0,4,1 do
  print('sending something on STDOUT...')
  tLogSystem.debug('Send some log...')
  os.execute('sleep 0.1')
end

-- Now set a new interaction.

-- Read the first interaction code.
local strJsrFilename = 'jsx/select_serial_range_and_tests.jsx'
local strJsx, strErr = pl.file.read(strJsrFilename)
if strJsx==nil then
  tLogSystem.error('Failed to read JSX from "%s": %s', strJsrFilename, strErr)
else
  m_zmqSocket:send(string.format('INT,%s', strJsx))
end

if m_zmqSocket~=nil then
  if m_zmqSocket:closed()==false then
    m_zmqSocket:close()
  end
  m_zmqSocket = nil
end

if m_zmqContext~=nil then
  m_zmqContext:destroy()
  m_zmqContext = nil
end
