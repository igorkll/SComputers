local servicecode = [[(function(a)local b=a.table.concat;local c=a.table.insert;local d=a.string.find;local e=a.string.gsub;local f=a.string.sub;local g=a.string.char;local h;local i,j;local k="%d%d%d?%d?%d?%d?%d?%d?"local l,m="0","1"local function n(o,p)if p==0 then return o end;local q={}for r=1,#o do local s=(r-p-1)%#o+1;c(q,f(o,s,s))end;return b(q)end;local t={}return function(u,v,p)if not t[p]then t[p]={}end;if not t[p][v]then t[p][v]={}end;local w=t[p][v][u]if w then return w end;if p~=i or v~=j then i=p;j=v;h={}end;local x={}local y=n(v,p+a[1])u=e(u,"[^"..y.."=]","")local z,A,B,C;local D=e(e(u,".",function(E)if E=="="then return""end;if not x[E]then A,B,C=d(y,E)-1,{},1;for r=6,1,-1 do B[C]=A%2^r-A%2^(r-1)>0 and m or l;C=C+1 end;x[E]=b(B)end;return x[E]end),k,function(E)if#E~=8 then return""end;if not h[E]then z=0;for r=1,8 do z=z+(f(E,r,r)==m and 2^(8-r)or 0)end;h[E]=g(z)end;return h[E]end)t[p][v][u]=D;return D end end)]]

local customCode_base = 'LVWiBIo12d/8b+YjJpUOwX70CPcxDrfZheyHKSE5t9Mluq6kQmsRTFGgA4Nva3nz'

local function shuffleString(input)
    local chars = {}

    for i = 1, #input do
        chars[i] = input:sub(i, i)
    end

    for i = #chars, 2, -1 do
        local j = math.random(i)
        chars[i], chars[j] = chars[j], chars[i]
    end

    return table.concat(chars)
end

local function stringRoll(str, roll)
    if roll == 0 then return str end
    local nstr = {}
    for i = 1, #str do
        local index = ((i - roll - 1) % #str) + 1
        table.insert(nstr, str:sub(index, index))
    end
    return table.concat(nstr)
end

local customCode_encode
do
    local b2 = '%d%d%d?%d?%d?%d?%d?%d?'
    local b3 = '%d%d%d?%d?%d?%d?'
    local n0, n1 = '0', '1'

    local cache2
    local oldRoll, oldEcode
    function customCode_encode(data, ecode, roll)
        if roll ~= oldRoll or ecode ~= oldEcode then
            oldRoll = roll
            oldEcode = ecode
            cache2 = {}
        end

        local cache1 = {}
        local b = stringRoll(ecode, roll)
        return ((data:gsub('.', function(x) 
            if not cache1[x] then
                local r,b='',x:byte()
                for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and n1 or n0) end
                cache1[x] = r
            end
            return cache1[x]
        end)..'0000'):gsub(b3, function(x)
            if (#x < 6) then return '' end
            if not cache2[x] then
                local c=0
                for i=1,6 do c=c+(x:sub(i,i)==n1 and 2^(6-i) or 0) end
                cache2[x] = b:sub(c+1,c+1)
            end
            return cache2[x]
        end)..({ '', '==', '=' })[#data%3+1])
    end
end

local function generateRoll()
    return math.random(-4096, 4096)
end

local function encryptString(code, index, obval1)
    local char = code:sub(index, index)
    if char == "[" then
        index = index + 2
    else
        index = index + 1
    end

    local sourceString = {}
    local newI
    local prev
    for i = index, #code do
        sc.smartYield()
        local char2 = code:sub(i, i)
        if char == "[" then
            if char2 == "]" and code:sub(i+1, i+1) == "]" then
                newI = i + 2
                break
            else
                table.insert(sourceString, char2)
            end
        elseif char2 == char and prev ~= "\\" then
            newI = i + 1
            break
        else
            table.insert(sourceString, char2)
        end
        prev = char2
    end
    sourceString = table.concat(sourceString)
    sourceString = sourceString:gsub("\\n", "\n")
    sourceString = sourceString:gsub("\\r", "\r")
    sourceString = sourceString:gsub("\\t", "\t")
    sourceString = sourceString:gsub("\\b", "\b")
    sourceString = sourceString:gsub("\\f", "\f")
    sourceString = sourceString:gsub("\\v", "\v")
    sourceString = sourceString:gsub("\\0", "\0")
    sourceString = sourceString:gsub("\\\\", "\\")
    sourceString = sourceString:gsub("\\'", "'")
    sourceString = sourceString:gsub('\\"', '"')
    sourceString = sourceString:gsub("\\x(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    sourceString = sourceString:gsub("\\(%d%d?%d?)", function(oct) return string.char(tonumber(oct, 8)) end)

    --------------------------------

    local ecode = shuffleString(customCode_base)
    local roll = generateRoll()
    return "([[" .. customCode_encode(sourceString, ecode, roll + obval1) .. "]],[[" .. ecode .. "]]," .. roll .. ")", newI
end

local function generateRandomString()
    local length = math.random(8, 24)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = {}

    local index = math.random(1, 52)
    local randomChar = chars:sub(index, index)
    table.insert(result, randomChar)

    for i = 2, length do
        index = math.random(1, #chars)
        randomChar = chars:sub(index, index)
        table.insert(result, randomChar)
    end

    return table.concat(result)
end

local function localObfuscator(code, obval1)
    local newcode = {}
    local decryptName = generateRandomString()

    local i = 1
    while i <= #code do
        sc.smartYield()
        local char = code:sub(i, i)
        if char == "\"" or char == "\'" or (char == "[" and code:sub(i+1, i+1) == "[") then
            local encodedString, newI = encryptString(code, i, obval1)
            table.insert(newcode, " ")
            table.insert(newcode, decryptName)
            table.insert(newcode, encodedString)
            i = newI - 1
        else
            table.insert(newcode, char)
        end
        i = i + 1
    end

    return "local " .. decryptName .. "=" .. servicecode .. "(___obfuscator_env)" .. " " .. table.concat(newcode)
end

function obfuscator(code, obval1)
    return localObfuscator(code, obval1)
end