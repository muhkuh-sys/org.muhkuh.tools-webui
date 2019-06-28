local class = require 'pl.class'
local Process = require 'process'
local ProcessKeepalive = class(Process)

function ProcessKeepalive:_init(tLog, strCommand, astrArguments, fCrashDelayInS)
  self:super(tLog)

  -- luasocket provides a sleep function.
  self.socket = require 'socket'

  self.strCommand = strCommand
  self.astrArguments = astrArguments
  self.fCrashDelayInS = fCrashDelayInS
end



function ProcessKeepalive:run()
  self:run_process(self.strCommand, self.astrArguments)
end



function ProcessKeepalive:onClose(strError, iExitStatus, uiTermSignal)
  -- Was a shutdown requested?
  if self.fRequestedShutdown==false then
    -- No -> restart the process.
    local fCrashDelayInS = self.fCrashDelayInS
    self.tLog.warning('The keepalive process terminated. Sleeping for %fms.', fCrashDelayInS)
    self.socket.sleep(fCrashDelayInS)
    self.tLog.warning('Restarting keepalive process.')
    self:run_process(self.strCommand, self.astrArguments)
  end
end



function ProcessKeepalive:onStdOut(strData)
  self.tLog.info('STDOUT: %s', strData)
end



function ProcessKeepalive:onStdErr(strData)
  self.tLog.notice('STDERR: %s', strData)
end


return ProcessKeepalive
