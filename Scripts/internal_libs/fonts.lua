function sc_reglib_fonts()
    local fonts_lib = {}

    for name, data in pairs(canvasAPI.fonts) do
        if type(name) == "string" then
            fonts_lib[name] = data
            --print("font available: ", name)
        end
    end

    return fonts_lib
end