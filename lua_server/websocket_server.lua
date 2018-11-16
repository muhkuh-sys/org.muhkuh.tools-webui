require 'muhkuh_cli_init'

local json = require 'dkjson'
local uv  = require"lluv"
local ws  = require"lluv.websocket"

local wsurl   = "ws://127.0.0.1:12345"
local sprot = "echo"

local server = ws.new()
server:bind(wsurl, sprot, function(self, err)
  if err then
    print("Server error:", err)
    return server:close()
  end

  server:listen(function(self, err)
    if err then
      print("Server listen:", err)
      return server:close()
    end

    local cli = server:accept()
    cli:handshake(function(self, err, protocol)
      if err then
        print("Server handshake error:", err)
        return cli:close()
      end
      print("New server connection:", protocol)

      cli:start_read(function(self, err, message, opcode)
        if err then
          print("Server read error:", err)
          return cli:close()
        end

        print(message, opcode)

        local tMessage = {
          id = 'SetTitle',
          title = 'NXHX90-R1',
          subtitle = '7730.100',
          hasSerial = true,
          firstSerial = 20000,
          lastSerial = 20009
        }
        local strJson = json.encode(tMessage)
        cli:write(strJson, opcode)

        local tFile = io.open('test.jsx', 'r')
        local strJsx = tFile:read('*a')
        tFile:close()
        local tMessage = {
          id = 'SetInteraction',
          jsx = strJsx
        }
        local strJson = json.encode(tMessage)
        cli:write(strJson, opcode)
      end)
    end)
  end)
end)

uv.run(debug.traceback)
