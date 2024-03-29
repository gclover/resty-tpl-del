
local setmetatable = setmetatable
local error = error

local tcp       = ngx.socket.tcp
local strlen    = string.len
local strsub    = string.sub
local strmatch  = string.match
local tabconcat = table.concat

module(...)

_VERSION = "0.02"

local mt = { __index = _M }

function new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({sock = sock}, mt)
end

function set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:settimeout(timeout)
end

function set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:setkeepalive(...)
end

function connect(self, host, port, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    host = host or "127.0.0.1"
    port = port or 11300
    return sock:connect(host, port, ...)
end

function use(self, tube)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"use", " ", tube, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to use tube, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to use tube, receive data error: " .. err
    end
    return line
end

function watch(self, tube)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"watch", " ", tube, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to watch tube, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to watch tube, receive data error: " .. err
    end
    local size = strmatch(line, "^WATCHING (%d+)$")
    if size then
        return size, line
    end
    return 0, line
end

function put(self, body, pri, delay, ttr)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    pri   = pri or 2 ^ 32
    delay = delay or 0
    ttr   = ttr or 120
    local cmd = {"put", " ", pri, " ", delay, " ", ttr, " ", strlen(body), "\r\n", body, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to put, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to put, receive data error:" .. err
    end
    local id = strmatch(line, " (%d+)$")
    if id then
        return id, line
    end
    return nil, line
end

function delete(self, id)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"delete", " ", id, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to delete, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to delete, receive data error: " .. err
    end
    if line == "DELETED" then
        return true, line
    end
    return false, line
end

function reserve(self, timeout)
    local sock = self.sock
    local cmd = {"reserve", "\r\n"}
    if timeout then
        cmd = {"reserve-with-timeout", " ", timeout, "\r\n"}
    end
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to reserve, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to reserve, receive data error: " .. err
    end
    local id, size = strmatch(line, "^RESERVED (%d+) (%d+)$")
    if id and size then -- remove \r\n
        local data, err = sock:receive(size+2)
        return id, strsub(data, 1, strlen(data)-2)
    end
    return false, line
end

function close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    sock:send("quit\r\n")
    return sock:close()
end

local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
        error('attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)
