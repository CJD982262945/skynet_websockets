local skynet = require 'skynet'


local api = {}
local CONFIGD


skynet.init(function()
end)


function api.notify_reload(config_list)
	return skynet.error(" ===========reload_config================")
end





return api