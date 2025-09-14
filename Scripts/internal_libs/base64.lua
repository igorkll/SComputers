function sc_reglib_base64()
    local base64lib = {}

    function base64lib.encode(data)
        checkArg(1, data, "string")
        return base64.encode(data, true)
    end

    function base64lib.decode(data)
        checkArg(1, data, "string")
        return base64.decode(data, true)
    end
    
    return base64lib
end