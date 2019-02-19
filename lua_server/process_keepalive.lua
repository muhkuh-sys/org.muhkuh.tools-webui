local class = require 'pl.class'
local Process = require 'process'
local ProcessKeepalive = class(Process)

function ProcessKeepalive:_init(strCommand, astrArguments)
  self:super(strCommand, astrArguments)
end



function ProcessKeepalive:onCrash(strError, iExitStatus, uiTermSignal)
  -- Restart the process.
  print('Restarting')
  self:run()
end



function ProcessKeepalive:onClose(strError, iExitStatus, uiTermSignal)
end



function ProcessKeepalive:onStdOut(strData)
  print('STDOUT:', strData)
end



function ProcessKeepalive:onStdErr(strData)
  print('STDERR:', strData)
end


return ProcessKeepalive
