local class = require 'pl.class'
local Process = require 'process'
local ProcessZmq = class(Process)

function ProcessZmq:_init(tLog, strCommand, astrArguments)
  self:super(tLog)

  self.strCommand = strCommand
  self.astrArguments = astrArguments

  self.m_zmqContext = nil
  self.m_zmqSocket = nil
  self.m_zmqPort = nil
end



function ProcessZmq:__zmq_init()
  -- Create the 0MQ context and the socket.
  local zmq = require 'lzmq'
  local tZContext, strError = zmq.context()
  if tZContext==nil then
    error('Failed to create ZMQ context: ' .. tostring(strError))
  end
  self.m_zmqContext = tZContext

  local tZSocket, strError = tZContext:socket(zmq.PAIR)
  if tZSocket==nil then
    error('Failed to create ZMQ socket: ' .. tostring(strError))
  end
  self.m_zmqSocket = tZSocket

  local tServerPort, strError = tZSocket:bind_to_random_port('tcp://127.0.0.1')
  if tServerPort==nil then
    error('Failed to bind the socket: ' .. tostring(strError))
  end
  self.tLog.debug('0MQ listening on tcp://127.0.0.1:%d', tServerPort)
  self.m_zmqPort = tServerPort

  local uv = require 'lluv'
  local this = self
  uv.poll_zmq(tZSocket):start(function(tHandle, strErr, tSocket)
    this:__onZmqReceive(tHandle, strErr, tSocket)
  end)
end



function ProcessZmq:__onZmqReceive(tHandle, strErr, tSocket)
  if strErr then
    return handle:close()
  end

  print('**** ZMQ recv:', tSocket:recv())
end



function ProcessZmq:__zmq_delete()
  local zmqSocket = self.m_zmqSocket
  if zmqSocket~=nil then
    if zmqSocket:closed()==false then
      zmqSocket:close()
    end
    self.m_zmqSocket = nil
  end

  local zmqContext = self.m_zmqContext
  if zmqContext~=nil then
    zmqContext:destroy()
    self.m_zmqContext = nil
  end

  self.m_zmqPort = nil

  self.tLog.debug('0MQ closed')
end



function ProcessZmq:run()
  self:__zmq_init()

  -- Filter the arguments.
  local astrArgs = {}
  local strZmqPort = tostring(self.m_zmqPort)
  for _, strArg in ipairs(self.astrArguments) do
    local strArgSub = string.gsub(tostring(strArg), '%${ZMQPORT}', strZmqPort)
    table.insert(astrArgs, strArgSub)
  end

  self:run_process(self.strCommand, astrArgs)
end



function ProcessZmq:onClose(strError, iExitStatus, uiTermSignal)
  print('ZMQ closed:', strError, iExitStatus, uiTermSignal)
  self:__zmq_delete()
end



function ProcessZmq:onStdOut(strData)
  print('ZMQ STDOUT:', strData)
end



function ProcessZmq:onStdErr(strData)
  print('ZMQ STDERR:', strData)
end


return ProcessZmq
