require 'muhkuh_cli_init'

local pl = require'pl.import_into'()
local json = require 'dkjson'
local zmq = require 'lzmq'
local TestDescription = require 'test_description'

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

local function setInteraction(strFilename, atReplace)
  local tResult

  -- Read the interaction code.
  local strJsxTemplate, strErr = pl.file.read(strFilename)
  if strJsxTemplate==nil then
    tLogSystem.error('Failed to read JSX from "%s": %s', strFilename, strErr)
  else
    local strJsx

    -- Replace something?
    if atReplace==nil then
      strJsx = strJsxTemplate
    else
      strJsx = string.gsub(strJsxTemplate, '@([%w_]+)@', atReplace)
    end

    m_zmqSocket:send(string.format('INT%s', strJsx))

    tResult = true
  end

  return tResult
end



local function getInteractionResponse()
  local strResponse

  repeat
    local strMessage = m_zmqSocket:recv()
    strResponse = string.match(strMessage, '^RSP(.*)')
    if strResponse==nil then
      tLogSystem.debug('Ignoring invalid response: %s', strMessage)
    end
  until strResponse~=nil

  return strResponse
end



local function setInteractionGetJson(strFilename, atReplace)
  local tResult = setInteraction(strFilename, atReplace)
  if tResult==true then
    local strResponseRaw = getInteractionResponse()
    if strResponseRaw~=nil then
      local tJson, uiPos, strJsonErr = json.decode(strResponseRaw)
      if tJson==nil then
        tLogSystem.error('JSON Error: %d %s', uiPos, strJsonErr)
      else
        tLogSystem.debug('JSON OK!')
        tResult = tJson
      end
    end
  end

  return tResult
end



local function clearInteraction()
  m_zmqSocket:send('INT')
end



-- Read the test.xml file.
local tTestDescription = TestDescription(tLogSystem)
local tResult = tTestDescription:parse('tests.xml')
if tResult~=true then
  tLogSystem.error('Failed to parse the test description.')
else
  local astrTestNames = tTestDescription:getTestNames()
  -- Get all test names in the style of a table.
  local astrQuotedTests = {}
  for _, strName in ipairs(astrTestNames) do
    table.insert(astrQuotedTests, string.format('"%s"', strName))
  end
  local strTestNames = table.concat(astrQuotedTests, ', ')

  for iCnt=0,4,1 do
    print('sending something on STDOUT...')
    tLogSystem.debug('Send some log...')
    os.execute('sleep 0.1')
  end

  -- Now set a new interaction.

  -- Read the first interaction code.
  tResult = setInteractionGetJson('jsx/select_serial_range_and_tests.jsx', { ['TEST_NAMES']=strTestNames })
  if tResult==nil then
    tLogSystem.error('Failed to read interaction.')
  else
    local tJson = tResult
    pl.pretty.dump(tJson)
    clearInteraction()
  end
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
