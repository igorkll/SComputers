--_G.luavm = _G.luavm or {}
_G.luavm = {}
dofile './LuaVM/LBI.lua'
dofile './LuaVM/LuaZ.lua'
dofile './LuaVM/LuaX.lua'
dofile './LuaVM/LuaP.lua'
dofile './LuaVM/LuaK.lua'
dofile './LuaVM/LuaY.lua'
dofile './LuaVM/LuaU.lua'
_G.luavm.luaX:init()

function _G.luavm.custom_loadstring(LuaState, str, env)
    local f,writer,buff
    local ran,error=pcall(function()
        local zio = _G.luavm.luaZ:init(_G.luavm.luaZ:make_getS(str), nil)
        if not zio then return error() end
        local func = _G.luavm.luaY:parser(LuaState, zio, nil, "@input")
        writer, buff = _G.luavm.luaU:make_setS()
        _G.luavm.luaU:dump(LuaState, func, writer, buff)
        f = _G.luavm.lbi.load_bytecode(buff.data, env)
    end)
    if ran then
        return f,buff.data
    else
        return nil,error
    end
end
