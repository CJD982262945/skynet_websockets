local skynet = require 'skynet'

local wsapp, api = ...

wsapp.clear()


wsapp.add_sub_protocol 'reload_config' {
  function (ws)
    local msg, opcode = ws:recv()
    if msg then
      ws:send(api.notify_reload(msg), opcode)
    end
    ws:close()
  end
}

wsapp.add_sub_protocol 'file_upload' {
  function (ws)
    local filename = ws:recv()
    if filename then
      skynet.error('新文件上传: ', filename)
      local fc, opcode = ws:recv()
      if fc then
        local wf = io.open('upload/' .. filename, 'wb')
        if wf then
          wf:write(fc)
          wf:close()
          ws:send('200 OK')
        else
          ws:send('400 write file failed')
        end
      end
    end
    ws:close()
  end
}
