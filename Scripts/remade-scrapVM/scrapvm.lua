--_G.luavm = _G.luavm or {}
_G.luavm = {}
dofile '$CONTENT_DATA/Scripts/remade-scrapVM/LuaVM/LBI.lua'
dofile '$CONTENT_DATA/Scripts/remade-scrapVM/LuaVM/LuaZ.lua'
dofile '$CONTENT_DATA/Scripts/remade-scrapVM/LuaVM/LuaX.lua'
dofile '$CONTENT_DATA/Scripts/remade-scrapVM/LuaVM/LuaP.lua'
dofile '$CONTENT_DATA/Scripts/remade-scrapVM/LuaVM/LuaK.lua'
dofile '$CONTENT_DATA/Scripts/remade-scrapVM/LuaVM/LuaY.lua'
dofile '$CONTENT_DATA/Scripts/remade-scrapVM/LuaVM/LuaU.lua'
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
