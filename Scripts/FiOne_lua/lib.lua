dofile("$CONTENT_DATA/Scripts/FiOne_lua/source.lua")
dofile("$CONTENT_DATA/Scripts/remade-scrapVM/scrapvm.lua")

FiOne_lua.load = function(self, chunk, chunkname, env)
    if self and not self.luastate then
        self.luastate = {}
    end
    local tunnel, state = luavm.luaU:make_setS()
    local intershitator = luavm.luaY:parser(self.luastate, assert(luavm.luaZ:init(luavm.luaZ:make_getS(chunk))), nil, chunkname or "@code")
    luavm.luaU:dump(self.luastate, intershitator, tunnel, state)
    return FiOne_lua.wrap_state(FiOne_lua.bc_to_state(state.data), env)
end