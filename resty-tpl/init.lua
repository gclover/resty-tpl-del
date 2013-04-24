
package.path = package.path .. ";" .. os.getenv("HOME") .. "/app/resty-tpl/?.lua"

local cjson = require "cjson"
local file = io.open(os.getenv("HOME") .. "/app/resty-tpl/conf/backend.json", "r")
local content = cjson.decode(file:read("*all"))
file.close()

local config = ngx.shared.config
for name, value in pairs(content) do
	if (name == "beanstalkd") then 
		for bid, bvalue in pairs(value) do
			config:set(name..bid, bvalue)
			config:set("beanum", bid)
		end
	else
		config:set(name, value)
	end		
end

