function sc_reglib_graphic()
    local graphic_lib = {}

    function graphic_lib.textBox(display, x, y, width, height, text, color, centerX, centerY, spacingY, autoNewline, tool, myGuiColorPrefixSupport)
        centerX = not not centerX
        centerY = not not centerY
        tool = tool or (display.getUtf8Support() and utf8 or string)
        if autoNewline == nil then autoNewline = true end

        local _x, _y, _width, _height = display.getViewport()
        display.setInlineViewport(x, y, width, height)
        if not autoNewline and not text:find("%\n") then
            if centerX then x = x + (width / 2) end
            if centerY then y = y + (height / 2) end
            display.drawCenteredText(x, y, text, color, centerX, centerY)
            display.setViewport(_x, _y, _width, _height)
            return
        end
        
        local lines = {}
        local customColors = {}
        local fontX, fontY = display.getFontWidth(), display.getFontHeight() + (spacingY or 1)
        local maxLines = height / fontY
        local customColor
        for _, line in ipairs(strSplit(tool, text, "\n")) do
            if myGuiColorPrefixSupport and tool.sub(line, 1, 1) == "#" and tool.sub(line, 2, 2) ~= "#" then
                customColor = tool.sub(line, 1, 7)
                line = tool.sub(line, 8, tool.len(line))
            end
            if line == "" or not autoNewline then
                sc.yield()
                table.insert(lines, line)
                if customColor then
                    customColors[#lines] = customColor
                end
                maxLines = maxLines - 1
            else
                local maxSize
                --[[
                for i = #line, 1, -1 do
                    local textPixelLen = display.calcTextBox(line:sub(1, i))
                    if textPixelLen <= width then
                        maxSize = i
                        break
                    end
                end
                ]]
                if display.isMonospacedFont() then
                    maxSize = math.floor(width / fontX)
                else
                    local lens = display.calcDecreasingTextSizes(line)
                    local lineLen = display.getUtf8Support() and utf8.len(line) or #line
                    for i = lineLen, 1, -1 do
                        local textPixelLen = lens[i]
                        if textPixelLen <= width then
                            maxSize = i
                            break
                        end
                    end
                end

                if maxSize then
                    for _, line in ipairs(splitByMaxSizeWithTool(tool, line, maxSize)) do
                        sc.yield()
                        table.insert(lines, line)
                        if customColor then
                            customColors[#lines] = customColor
                        end
                        maxLines = maxLines - 1
                        if maxLines == 0 then break end
                    end
                else
                    sc.yield()
                    table.insert(lines, line)
                    if customColor then
                        customColors[#lines] = customColor
                    end
                    maxLines = maxLines - 1
                end
            end
            if maxLines == 0 then break end
        end
        local addY = math.floor((height / 2) - (((fontY * #lines) - 1) / 2))
        for i, line in ipairs(lines) do
            local lx, ly = x, y
            if centerX then
                lx = x + ((width / 2) - (display.calcTextBox(line) / 2))
            end
            ly = y + ((i - 1) * fontY)
            if centerY then
                ly = ly + addY
            end
            display.drawText(lx, ly, line, customColors[i] or color)
        end
        display.setViewport(_x, _y, _width, _height)
    end

    return graphic_lib
end