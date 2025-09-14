local currentEncryptVM = 1

dofile("$CONTENT_DATA/Scripts/encryptVM/compile/scrapvm.lua")
dofile("$CONTENT_DATA/Scripts/encryptVM/obfuscator.lua")
for i = 0, currentEncryptVM do
    dofile("$CONTENT_DATA/Scripts/encryptVM/vm_" .. i .. ".lua")
end

local table_concat = table.concat
local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local string_char = string.char

local customCode_encode, customCode_decode
do
    local b='LVWiBIo12d/8b+YjJpUOwX70CPcxDrfZheyHKSE5t9Mluq6kQmsRTFGgA4Nva3nz'
    local b2 = '%d%d%d?%d?%d?%d?%d?%d?'
    local b3 = '%d%d%d?%d?%d?%d?'
    local n0, n1 = '0', '1'

    local function stringRoll(str, roll)
        if roll == 0 then return str end
        local nstr = {}
        for i = 1, #str do
            local index = ((i - roll - 1) % #str) + 1
            table.insert(nstr, str:sub(index, index))
        end
        return table.concat(nstr)
    end

    local cache2
    local oldRoll
    function customCode_encode(data, roll)
        if roll ~= oldRoll then
            oldRoll = roll
            cache2 = {}
        end
        local cache1 = {}
        local b = stringRoll(b, roll)
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

    local cache3
    local oldRoll2
    function customCode_decode(data, roll)
        if roll ~= oldRoll2 then
            oldRoll2 = roll
            cache3 = {}
        end
        local cache4 = {}
        local b = stringRoll(b, roll)
        data = string_gsub(data, '[^'..b..'=]', '')
        local c, f, t, ti
        return string_gsub(string_gsub(data, '.', function(x)
            if (x == '=') then return '' end
            if not cache4[x] then
                f, t, ti= string_find(b,x)-1, {}, 1
                for i=6,1,-1 do t[ti] = f%2^i-f%2^(i-1)>0 and n1 or n0 ti = ti + 1 end
                cache4[x] = table_concat(t)
            end
            return cache4[x]
        end), b2, function(x)
            if (#x ~= 8) then return '' end
            if not cache3[x] then
                c=0
                for i=1,8 do c=c+(string_sub(x,i,i)==n1 and 2^(8-i) or 0) end
                cache3[x] = string_char(c)
            end
            return cache3[x]
        end)
    end
end

local function eload(self, bytecode, env)
    addServiceCode(self, "", env)

    local r1 = bytecode:byte(1)
    local r2 = bytecode:byte(2)
    local r3 = bytecode:byte(3)
    local result = customCode_decode(bytecode:sub(4, #bytecode), (r1 * r2) + r3)

    local vmid = result:byte(1)
    local vmlib = _G["encryptVM_" .. vmid]
    if not vmlib then
        return nil, "failed to select encryptVM"
    end

    env.___obfuscator_env = {
        math.ceil(((r1 * r3) - r2) / r1),
        table = sc.advDeepcopy(table),
        string = sc.advDeepcopy(string)
    }

    return vmlib.wrap_state(vmlib.bc_to_state(result:sub(2, #result)), env)
end

encryptVM = {
    compile = function(self, code)
        if self and not self.luastate then
            self.luastate = {}
        end
        local r1 = math.random(0, 255)
        local r2 = math.random(0, 255)
        local r3 = math.random(0, 255)
        code = obfuscator(addServiceCode(self, code), math.ceil(((r1 * r3) - r2) / r1))
        encryptVM_compile.luaY.initObfuscator()
        local tunnel, state = encryptVM_compile.luaU:make_setS()
        local intershitator = encryptVM_compile.luaY:parser(self.luastate, assert(encryptVM_compile.luaZ:init(encryptVM_compile.luaZ:make_getS(code))), nil, "@encrypted_code")
        encryptVM_compile.luaU:dump(self.luastate, intershitator, tunnel, state)
        return string.char(r1) .. string.char(r2) .. string.char(r3) .. customCode_encode(string.char(currentEncryptVM) .. state.data, (r1 * r2) + r3)
    end,
    load = function(self, bytecode, env)
        local ok, code, err = pcall(eload, self, bytecode, env)
        if ok then
            if type(code) == "function" then
                err = nil
            else
                err = "something went wrong"
                code = nil
            end
        else
            err = tostring(code)
            code = nil
        end
        return code, err
    end,
    version = function(self, bytecode)
        local version = -3
        pcall(function ()
            local r1 = bytecode:byte(1)
            local r2 = bytecode:byte(2)
            local r3 = bytecode:byte(3)
            local result = customCode_decode(bytecode:sub(4, #bytecode), (r1 * r2) + r3)
            version = result:byte(1)
        end)
        return version
    end,
    currentEncryptVM = currentEncryptVM
}