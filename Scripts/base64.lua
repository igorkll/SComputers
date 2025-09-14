base64 = {}

local table_concat = table.concat
local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local string_char = string.char

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
local b2 = '%d%d%d?%d?%d?%d?%d?%d?'
local b3 = '%d%d%d?%d?%d?%d?'
local n0, n1 = '0', '1'

local cache2 = {}
function base64.encode(data, needYield)
    if better and better.algorithm then
        return better.algorithm.base64_encode(data)
    end

    local cache1 = {}

    local function yield()
        if needYield then
            sc.smartYield()
        end
    end

    return ((data:gsub('.', function(x) 
        if not cache1[x] then
            local r,b='',x:byte()
            for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and n1 or n0) yield() end
            cache1[x] = r
        end
        return cache1[x]
    end)..'0000'):gsub(b3, function(x)
        if (#x < 6) then return '' end
        if not cache2[x] then
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)==n1 and 2^(6-i) or 0) yield() end
            cache2[x] = b:sub(c+1,c+1)
        end
        return cache2[x]
    end)..({ '', '==', '=' })[#data%3+1])
end

local cache3 = {}
function base64.decode(data, needYield)
    if better and better.algorithm then
        return better.algorithm.base64_decode(data)
    end

    local cache4 = {}

    local function yield()
        if needYield then
            sc.smartYield()
        end
    end

    data = string_gsub(data, '[^'..b..'=]', '')
    local c, f, t, ti
    return string_gsub(string_gsub(data, '.', function(x)
        if (x == '=') then return '' end
        if not cache4[x] then
            f, t, ti= string_find(b,x)-1, {}, 1
            for i=6,1,-1 do t[ti] = f%2^i-f%2^(i-1)>0 and n1 or n0 ti = ti + 1 yield() end
            cache4[x] = table_concat(t)
        end
        return cache4[x]
    end), b2, function(x)
        if (#x ~= 8) then return '' end
        if not cache3[x] then
            c=0
            for i=1,8 do c=c+(string_sub(x,i,i)==n1 and 2^(8-i) or 0) yield() end
            cache3[x] = string_char(c)
        end
        return cache3[x]
    end)
end 