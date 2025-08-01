--[[
Copyright: Ren Tatsumoto and contributors
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Utils for downloading pronunciations from Forvo
]]

local http = require("socket.http")
local socket = require("socket")
local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local utils = require("lua_utils/utils")


local function GET(url)
    local sink = {}
    socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
    local request = {
        url = url,
        method = "GET",
        headers = {
            ['User-Agent'] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
            ['Host'] = 'forvo.com',
            ['Accept-Language'] = "en-US,en;q=0.9",
            ['Accept'] = "*/*"
        },
        sink = ltn12.sink.table(sink),
    }
    local code, _, status = socket.skip(1, http.request(request))
    if code == 200 then
        return table.concat(sink)
    end
    -- Special handling for 403 error (likely rate limit or access restriction)
    if code == 403 then
        return false, "FORVO_403"
    end
    return false, ("[%d]: %s"):format(code or -1, status or "")
end

-- http://lua-users.org/wiki/BaseSixtyFour
-- character table string
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64e(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64d(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end



local function get_pronunciation_url(word, language)
    local forvo_url = ('https://forvo.com/search/%s/%s'):format(utils.url_encode(word), language)
    local forvo_page, err = GET(forvo_url)
    if not forvo_page then
        return false, err
    end
    local play_params = string.match(forvo_page, "Play%((.-)%);")

    local word_url = nil
    if play_params then
        local iter = string.gmatch(play_params, "'(.-)'")
        local formats = { mp3 = iter(), ogg = iter() }
        word_url = string.format('https://audio00.forvo.com/%s/%s', "ogg", base64d(formats["ogg"]))
    end
    return true, word_url
end

return {
    get_pronunciation_url = get_pronunciation_url,
    base64e = base64e,
}
