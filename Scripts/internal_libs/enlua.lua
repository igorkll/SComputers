function sc_reglib_enlua(self, env)
    local enlua = {}

    function enlua.compile(code)
        checkArg(1, code, "string")
        local ok, result = pcall(encryptVM.compile, self, code)
        if ok then
            return result
        end
        return nil, tostring(result)
    end

    function enlua.load(bytecode, lenv)
        checkArg(1, bytecode, "string")
        checkArg(2, lenv, "table", "nil")
        return encryptVM.load(self, bytecode, lenv or env)
    end

    function enlua.version(bytecode)
        checkArg(1, bytecode, "string")
        return encryptVM.version(self, bytecode)
    end

    function enlua.lastVersion()
        return tonumber(encryptVM.currentEncryptVM or -1) or -1
    end

    return enlua
end