dofile("$CONTENT_DATA/Scripts/syntax.lua")

function sc_reglib_syntax()
    local syntax = {}

    function syntax.format(code)
        checkArg(1, code, "string")
        return syntax_format(code, true)
    end

    function syntax.highlight(code, errorLine, palette)
        checkArg(1, code, "string")
        checkArg(2, errorLine, "number", "nil")
        checkArg(3, palette, "number")
        palette = math.floor(palette or 1)
        return syntax_make(code, errorLine, true, palette)
    end

    return syntax
end