-----------------------------------------------------------------------------
-- SMTP client support for the Lua language.
-- LuaSocket toolkit.
-- Author: Diego Nehab
-- RCS ID: $Id: smtp.lua,v 1.2 2005/07/31 00:05:08 cpressey Exp $
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Declare module and import dependencies
-----------------------------------------------------------------------------
local base = require("base")
local coroutine = require("coroutine")
local string = require("string")
local math = require("math")
local os = require("os")
local socket = require("socket")
local tp = require("tp")
local ltn12 = require("ltn12")
local mime = require("mime")
module("socket.smtp")

smtp = {}

-----------------------------------------------------------------------------
-- Program constants
-----------------------------------------------------------------------------
-- timeout for connection
TIMEOUT = 60
-- default server used to send e-mails
SERVER = "localhost"
-- default port
PORT = 25 
-- domain used in HELO command and default sendmail 
-- If we are under a CGI, try to get from environment
DOMAIN = os.getenv("SERVER_NAME") or "localhost"
-- default time zone (means we don't know)
ZONE = "-0000"

---------------------------------------------------------------------------
-- Low level SMTP API
-----------------------------------------------------------------------------
local metat = { __index = {} }

function metat.__index:greet(domain)
    self.try(self.tp:check("2.."))
    self.try(self.tp:command("EHLO", domain or DOMAIN))
    return socket.skip(1, self.try(self.tp:check("2..")))
end 

function metat.__index:mail(from)
    self.try(self.tp:command("MAIL", "FROM:" .. from))
    return self.try(self.tp:check("2.."))
end 

function metat.__index:rcpt(to)
    self.try(self.tp:command("RCPT", "TO:" .. to))
    return self.try(self.tp:check("2.."))
end

function metat.__index:data(src, step)
    self.try(self.tp:command("DATA"))
    self.try(self.tp:check("3.."))
    self.try(self.tp:source(src, step))
    self.try(self.tp:send("\r\n.\r\n"))
    return self.try(self.tp:check("2.."))
end

function metat.__index:quit()
    self.try(self.tp:command("QUIT"))
    return self.try(self.tp:check("2.."))
end

function metat.__index:close()
    return self.tp:close()
end

function metat.__index:login(user, password)
    self.try(self.tp:command("AUTH", "LOGIN"))
    self.try(self.tp:check("3.."))
    self.try(self.tp:command(mime.b64(user)))
    self.try(self.tp:check("3.."))
    self.try(self.tp:command(mime.b64(password)))
    return self.try(self.tp:check("2.."))
end

function metat.__index:plain(user, password)
    local auth = "PLAIN " .. mime.b64("\0" .. user .. "\0" .. password)
    self.try(self.tp:command("AUTH", auth))
    return self.try(self.tp:check("2.."))
end

function metat.__index:auth(user, password, ext)
    if not user or not password then return 1 end
    if string.find(ext, "AUTH[^\n]+LOGIN") then
        return self:login(user, password)
    elseif string.find(ext, "AUTH[^\n]+PLAIN") then
        return self:plain(user, password)
    else
        self.try(nil, "authentication not supported")
    end
end

-- send message or throw an exception
function metat.__index:send(mailt) 
    self:mail(mailt.from)
    if base.type(mailt.rcpt) == "table" then
        for i,v in base.ipairs(mailt.rcpt) do
            self:rcpt(v)
        end
    else
        self:rcpt(mailt.rcpt)
    end
    self:data(ltn12.source.chain(mailt.source, mime.stuff()), mailt.step)
end

function open(server, port)
    local tp = socket.try(tp.connect(server or SERVER, port or PORT, TIMEOUT))
    local s = base.setmetatable({tp = tp}, metat)
    -- make sure tp is closed if we get an exception
    s.try = socket.newtry(function() 
        if s.tp:command("QUIT") then s.tp:check("2..") end
        s:close()
    end)
    return s 
end

---------------------------------------------------------------------------
-- Multipart message source
-----------------------------------------------------------------------------
-- returns a hopefully unique mime boundary
local seqno = 0
local function newboundary()
    seqno = seqno + 1
    return string.format('%s%05d==%05u', os.date('%d%m%Y%H%M%S'),
        math.random(0, 99999), seqno)
end

-- send_message forward declaration
local send_message

-- yield multipart message body from a multipart message table
local function send_multipart(mesgt)
    local bd = newboundary()
    -- define boundary and finish headers
    coroutine.yield('content-type: multipart/mixed; boundary="' .. 
        bd .. '"\r\n\r\n')
    -- send preamble
    if mesgt.body.preamble then 
        coroutine.yield(mesgt.body.preamble) 
        coroutine.yield("\r\n") 
    end
    -- send each part separated by a boundary
    for i, m in base.ipairs(mesgt.body) do
        coroutine.yield("\r\n--" .. bd .. "\r\n")
        send_message(m)
    end
    -- send last boundary 
    coroutine.yield("\r\n--" .. bd .. "--\r\n\r\n")
    -- send epilogue
    if mesgt.body.epilogue then 
        coroutine.yield(mesgt.body.epilogue) 
        coroutine.yield("\r\n") 
    end
end

-- yield message body from a source
local function send_source(mesgt)
    -- set content-type if user didn't override
    if not mesgt.headers or not mesgt.headers["content-type"] then
        coroutine.yield('content-type: text/plain; charset="iso-8859-1"\r\n')
    end
    -- finish headers
    coroutine.yield("\r\n")
    -- send body from source
    while true do 
        local chunk, err = mesgt.body()
        if err then coroutine.yield(nil, err)
        elseif chunk then coroutine.yield(chunk)
        else break end
    end
end

-- yield message body from a string
local function send_string(mesgt)
    -- set content-type if user didn't override
    if not mesgt.headers or not mesgt.headers["content-type"] then
        coroutine.yield('content-type: text/plain; charset="iso-8859-1"\r\n')
    end
    -- finish headers
    coroutine.yield("\r\n")
    -- send body from string
    coroutine.yield(mesgt.body)

end

-- yield the headers one by one
local function send_headers(mesgt)
    if mesgt.headers then
        for i,v in base.pairs(mesgt.headers) do
            coroutine.yield(i .. ':' .. v .. "\r\n")
        end
    end
end

-- message source
function send_message(mesgt)
    send_headers(mesgt)
    if base.type(mesgt.body) == "table" then send_multipart(mesgt)
    elseif base.type(mesgt.body) == "function" then send_source(mesgt)
    else send_string(mesgt) end
end

-- set defaul headers
local function adjust_headers(mesgt)
    local lower = {}
    for i,v in (mesgt.headers or lower) do
        lower[string.lower(i)] = v
    end
    lower["date"] = lower["date"] or 
        os.date("!%a, %d %b %Y %H:%M:%S ") .. (mesgt.zone or ZONE)
    lower["x-mailer"] = lower["x-mailer"] or socket.VERSION
    -- this can't be overriden
    lower["mime-version"] = "1.0" 
    mesgt.headers = lower
end

function smtp.message(mesgt)
    adjust_headers(mesgt)
    -- create and return message source
    local co = coroutine.create(function() send_message(mesgt) end)
    return function() 
        local ret, a, b = coroutine.resume(co)
        if ret then return a, b
        else return nil, a end
    end
end

---------------------------------------------------------------------------
-- High level SMTP API
-----------------------------------------------------------------------------
smtp.send = socket.protect(function(mailt)
    local s = open(mailt.server, mailt.port)
    local ext = s:greet(mailt.domain)
    s:auth(mailt.user, mailt.password, ext)
    s:send(mailt)
    s:quit()
    return s:close()
end)

--getmetatable(_M).__index = nil

return smtp