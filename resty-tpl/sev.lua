
ngx.header.content_type = "text/plain";
	
local cjson = require "cjson"			-- 引入cjson扩展
local beanstalk = require('beanstalkd')   -- 引入beanstalkd操作扩展
local args = ngx.req.get_uri_args()		-- 获取URL的参数
local args_encoded = cjson.encode(args)		-- encode参数
local config = ngx.shared.config		-- config

local beanum = config:get("beanum")		-- beanum的数量
local beanrand = math.random(beanum)		-- 生成beanstalk随机数

local beanstalkd = config:get("beanstalkd"..beanrand)  -- 当前连接的beanstalk的配置
ngx.say(beanstalkd)

function split(str, delim, maxNb)   -- 分隔字符函数
    if string.find(str, delim) == nil then  
        return { str }  
    end  
    if maxNb == nil or maxNb < 1 then  
        maxNb = 0    -- No limit   
    end  
    local result = {}  
    local pat = "(.-)" .. delim .. "()"   
    local nb = 0  
    local lastPos   
    for part, pos in string.gfind(str, pat) do  
        nb = nb + 1  
        result[nb] = part   
        lastPos = pos   
        if nb == maxNb then break end  
    end  
    -- Handle the last field   
    if nb ~= maxNb then  
        result[nb + 1] = string.sub(str, lastPos)   
    end  
    return result   
end   

local host = split(beanstalkd,":")

local bean, err = beanstalk:new()
local ok, err = bean:connect(host[1], host[2])
if not ok then
    ngx.say("1: failed to connect: ", err)
    return
end

local ok, err = bean:use("default")
if not ok then
    ngx.say("2: failed to use tube: ", err)
    return
end

local id, err = bean:put(args_encoded)
if not id then
    ngx.say("3: failed to put: ", err)
    return
end

ngx.say("put: ", id)

bean:set_keepalive(10)
