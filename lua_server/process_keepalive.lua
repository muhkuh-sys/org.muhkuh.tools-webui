local class = require 'pl.class'
local Process = require 'process'
local ProcessKeepalive = class(Process)

function ProcessKeepalive:_init(strCommand, astrArguments)
  self:super(strCommand, astrArguments)
end



function ProcessKeepalive:onClose(strError, iExitStatus, uiTermSignal)
  -- Was a shutdown requested?
  if self.fRequestedShutdown==false then
    -- No -> restart the process.
    print('Restarting')
    self:run()
  end
end



function ProcessKeepalive:onStdOut(strData)
  print('STDOUT:', strData)
end



function ProcessKeepalive:onStdErr(strData)
  print('STDERR:', strData)
end


return ProcessKeepalive
