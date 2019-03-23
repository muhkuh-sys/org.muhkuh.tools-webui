-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

-- Say "hi".
io.stdout:write('This is stdout.\n')
io.stderr:write('This is stderr.\n')

for iCnt=0,10,1 do
  io.stdout:write(string.format('count %d\n', iCnt))
  os.execute('sleep 1')
end
