--[[
Copyright: Ren Tatsumoto and contributors
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Utils for downloading pronunciations from Cambridge Dictionary
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
            ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
            ["Host"] = "dictionary.cambridge.org",
            ["Accept-Language"] = "en-US,en;q=0.9",
            ["Accept"] = "*/*",
        },
        sink = ltn12.sink.table(sink),
    }
    local code, _, status = socket.skip(1, http.request(request))
    if code == 200 then
        return table.concat(sink)
    end
    -- Special handling for 403 error (likely rate limit or access restriction)
    if code == 403 then
        return false, "CAMBRIDGE_403"
    end
    return false, ("[%d]: %s"):format(code or -1, status or "")
end

local function get_pronunciation_url(word, language)
    local cambridge_url = ("https://dictionary.cambridge.org/dictionary/english/%s"):format(utils.url_encode(word))
    local cambridge_page, err = GET(cambridge_url)
    if not cambridge_page then
        return false, err
    end

    -- Look for UK pronunciation audio (ogg format)
    local uk_audio_pattern = 'data%-src%-ogg="([^"]*uk_pron[^"]*%.ogg)"'
    local uk_audio_url = string.match(cambridge_page, uk_audio_pattern)

    -- Look for US pronunciation audio (ogg format) if UK not found
    local us_audio_pattern = 'data%-src%-ogg="([^"]*us_pron[^"]*%.ogg)"'
    local us_audio_url = string.match(cambridge_page, us_audio_pattern)

    -- Also try alternative patterns without data- prefix
    if not uk_audio_url then
        uk_audio_url = string.match(cambridge_page, 'src="([^"]*uk_pron[^"]*%.ogg)"')
    end
    if not us_audio_url then
        us_audio_url = string.match(cambridge_page, 'src="([^"]*us_pron[^"]*%.ogg)"')
    end

    -- Prefer UK pronunciation, fall back to US
    local audio_url = uk_audio_url or us_audio_url

    if audio_url then
        -- Handle relative URLs
        if audio_url:sub(1, 2) == "//" then
            audio_url = "https:" .. audio_url
        elseif audio_url:sub(1, 1) == "/" then
            audio_url = "https://dictionary.cambridge.org" .. audio_url
        end
        return true, audio_url
    end

    return false, "No audio found"
end

return {
    get_pronunciation_url = get_pronunciation_url,
}
