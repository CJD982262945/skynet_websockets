--- websockets service
-- @module websockets
local skynet = require 'skynet'
local socket = require "socket"



if ... == 'agent' then

  local handshake = require 'websockets.handshake'
  local frame     = require 'websockets.frame'
  local tools     = require 'websockets.tools'

  local LIMIT = 8192

  --- 读header
  local function recvheader(sid)
    local header = ''

    while true do
      local r, err = socket.read(sid)

      if not r then return end

      header = header .. r

      if #header > LIMIT then return end

      -- TODO 不包含\r\n非法请求的退出条件
      local b, e = header:find("\r\n\r\n", -#r - 3, true)
      if b then return header:sub(1, e) end

      if header:find "^\r\n" then return end
    end
  end

  local ws_meta = {}
  ws_meta.__index = ws_meta

  function ws_meta:recv()
    local first_opcode
    local frames
    local bytes = 3
    local encoded = ''

    while true do
      local r, bytes_read = socket.read(self.sid, bytes)

      if not r then return end

      encoded = encoded .. r

      local decoded, fin, opcode, _, _ = frame.decode(encoded)
      if decoded then

        if opcode == frame.CLOSE then return end

        if not first_opcode then first_opcode = opcode end

        if not fin then
          if not frames then
            frames = {}
          elseif opcode ~= frame.CONTINUATION then
            return
          end
          bytes = 3
          encoded = ''
          table.insert(frames, decoded)
        elseif not frames then
          return decoded, first_opcode
        else
          table.insert(frames, decoded)
          return table.concat(frames), first_opcode
        end
      else
        assert(type(fin) == 'number' and fin > 0)
        bytes = fin
      end
    end
  end

  function ws_meta:send(msg, opcode)
    socket.write(self.sid, frame.encode(msg, opcode, false))
  end

  function ws_meta:close()
    local code, reason = 1000, 'done'
    local close_msg = frame.encode_close(code, reason)
    socket.write(self.sid, frame.encode(close_msg, frame.CLOSE, false))
    socket.close(self.sid)
  end

  local function mk_ws(sid)
    return setmetatable({sid = sid}, ws_meta)
  end


  local ws_sub_protocols, protocols = {}, {}

  local wsapp = {}

  function wsapp.clear()
    ws_sub_protocols, protocols = {}, {}
  end

  function wsapp.add_sub_protocol (protocol)
    assert(type(protocol) == 'string')
    return function (hd)
      table.insert(protocols, protocol)
      ws_sub_protocols[protocol] = type(hd) == 'table' and hd[1] or hd
    end
  end

  local api =  require "websockets.api" --{}

  --- ws app 更新策略开关
  -- 可以通过debug console动态设置
  -- true: 加载一次后不再每次加载
  -- false: 每次加载
  -- nil: 内部状态
  code_cache = false

  local function handle_socket (session, source, sid)

    if type(code_cache) == 'boolean' then
      local fn = 'service/websockets/app.lua'
      load(io.open(fn, 'rb'):read 'a', '@' .. fn)(wsapp, api)

      if code_cache then code_cache = nil end
    end

    socket.start(sid)

    local request = recvheader(sid)
    if not request then return socket.close(sid) end

    local res, protocol = handshake.accept_upgrade(request, protocols)
    if not res then
      socket.write(sid, protocol)
      return socket.close(sid)
    end

    local err_res = 'HTTP/1.1 501 Not Implemented\r\n\r\n'
    if not protocol then
      socket.write(sid, err_res)
      return socket.close(sid)
    end
    local hd = ws_sub_protocols[protocol]
    if type(hd) == 'function' then
      socket.write(sid, res)
      return skynet.fork(hd, mk_ws(sid))
    else
      socket.write(sid, err_res)
      return socket.close(sid)
    end
  end


  skynet.start(function()
    skynet.dispatch("lua", handle_socket)
  end)


else

  local CMD = {}

  --- 启动websockets
  function CMD.start(conf)
    local listen_id = socket.listen(conf.host, conf.port)
    skynet.error("listen on:", conf.port)

    local agent = {}
    for i= 1, conf.agent do
      agent[i] = skynet.newservice('websockets', 'agent')
    end

    local balance = 1

    socket.start(listen_id , function(id, addr)
      skynet.send(agent[balance], "lua", id)
      balance = balance == #agent and 1 or balance + 1
    end)
  end

  skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
      return skynet.retpack(CMD[cmd](...))
    end)
  end)

end
