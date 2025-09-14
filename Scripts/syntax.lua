local palettes = {
    {
        mainColor = "#8ee4ff",
        functionColor = "#f5d689",
        commentColor = "#1ca800",
        stringColor = "#e39a2d",
        numberColor = "#6FCE54",
        
        keywords = {
            ["true"] = "#0d8ef7",
            ["false"] = "#0d8ef7",
            ["nil"] = "#0d8ef7",
            ["local"] = "#0d8ef7",
        
            ["until"] = "#C456BD",
            ["repeat"] = "#C456BD",
            ["while"] = "#C456BD",
            ["for"] = "#C456BD",
            ["if"] = "#C456BD",
            ["in"] = "#C456BD",
            ["then"] = "#C456BD",
            ["end"] = "#C456BD",
            ["else"] = "#C456BD",
            ["elseif"] = "#C456BD",
            ["do"] = "#C456BD",
            ["function"] = "#C456BD",
            ["return"] = "#C456BD",
            ["or"] = "#C456BD",
            ["and"] = "#C456BD",
            ["not"] = "#C456BD",

            ["+"] = "#ffffff",
            ["*"] = "#ffffff",
            ["/"] = "#ffffff",
            ["-"] = "#ffffff",
            ["^"] = "#ffffff"
        },
        
        bracketsColors = {
            "#d2cc29",
            "#C456BD",
            "#0d8ef7"
        },
        
        afterDotColors = {
            "#0c9beb",
            "#2ad163",
            "#c9d12a"
        }
    },
    {
        mainColor = "#fcfa90",
        functionColor = "#ee9c6a",
        commentColor = "#6aa300",
        stringColor = "#e39a2d",
        numberColor = "#d5ff1f",
        
        keywords = {
            ["true"] = "#d76600",
            ["false"] = "#d76600",
            ["nil"] = "#d76600",
            ["local"] = "#d76600",
        
            ["until"] = "#e8ae17",
            ["repeat"] = "#e8ae17",
            ["while"] = "#e8ae17",
            ["for"] = "#e8ae17",
            ["if"] = "#e8ae17",
            ["in"] = "#e8ae17",
            ["then"] = "#e8ae17",
            ["end"] = "#e8ae17",
            ["else"] = "#e8ae17",
            ["elseif"] = "#e8ae17",
            ["do"] = "#e8ae17",
            ["function"] = "#e8ae17",
            ["return"] = "#e8ae17",
            ["or"] = "#e8ae17",
            ["and"] = "#e8ae17",
            ["not"] = "#e8ae17",

            ["+"] = "#ffffff",
            ["*"] = "#ffffff",
            ["/"] = "#ffffff",
            ["-"] = "#ffffff",
            ["^"] = "#ffffff"
        },
        
        bracketsColors = {
            "#ff541e",
            "#d18606",
            "#cdd106"
        },
        
        afterDotColors = {
            "#d14a06",
            "#d18306",
            "#d1bd06"
        }
    },
    {
        mainColor = "#ffffff",
        functionColor = "#88d914",
        commentColor = "#00ee00",
        stringColor = "#eab600",
        numberColor = "#00ff00",
        
        keywords = {
            ["true"] = "#4aff6a",
            ["false"] = "#4aff6a",
            ["nil"] = "#4aff6a",
            ["local"] = "#ff4a8e",
        
            ["until"] = "#eb00de",
            ["repeat"] = "#eb00de",
            ["while"] = "#eb00de",
            ["for"] = "#eb00de",
            ["if"] = "#eb00de",
            ["in"] = "#eb00de",
            ["then"] = "#eb00de",
            ["end"] = "#eb00de",
            ["else"] = "#eb00de",
            ["elseif"] = "#eb00de",
            ["do"] = "#eb00de",
            ["function"] = "#eb00de",
            ["return"] = "#eb00de",
            ["or"] = "#eb00de",
            ["and"] = "#eb00de",
            ["not"] = "#eb00de",

            ["+"] = "#ff8f00",
            ["*"] = "#ff8f00",
            ["/"] = "#ff8f00",
            ["-"] = "#ff8f00",
            ["^"] = "#ff8f00"
        },
        
        bracketsColors = {
            "#ffffff",
            "#44ff44",
            "#ff2222"
        },
        
        afterDotColors = {
            "#3de2ff",
            "#02f546",
            "#e9f502"
        }
    },
    {
        mainColor = "#96ffb2",
        functionColor = "#0cb856",
        commentColor = "#01a305",
        stringColor = "#0088ff",
        numberColor = "#00f4ff",
        
        keywords = {
            ["true"] = "#f0ca02",
            ["false"] = "#f0ca02",
            ["nil"] = "#f0ca02",
            ["local"] = "#f0ca02",
        
            ["until"] = "#9bd100",
            ["repeat"] = "#9bd100",
            ["while"] = "#9bd100",
            ["for"] = "#9bd100",
            ["if"] = "#9bd100",
            ["in"] = "#9bd100",
            ["then"] = "#9bd100",
            ["end"] = "#9bd100",
            ["else"] = "#9bd100",
            ["elseif"] = "#9bd100",
            ["do"] = "#9bd100",
            ["function"] = "#9bd100",
            ["return"] = "#9bd100",
            ["or"] = "#9bd100",
            ["and"] = "#9bd100",
            ["not"] = "#9bd100",

            ["+"] = "#ffffff",
            ["*"] = "#ffffff",
            ["/"] = "#ffffff",
            ["-"] = "#ffffff",
            ["^"] = "#ffffff"
        },
        
        bracketsColors = {
            "#02f068",
            "#02f090",
            "#02f0cc"
        },
        
        afterDotColors = {
            "#0cff00",
            "#daf002",
            "#f0b802"
        }
    },
    {
        noHighlight = true
    }
}

local orig_backslash = "\\"
local magic_backslash = "¦"

local parsedLinesCache = {}
local function parseLine(str)
    local paletteIndex = localStorage.current.palette
    if not parsedLinesCache[paletteIndex] then
        parsedLinesCache[paletteIndex] = {}
    end
    if parsedLinesCache[paletteIndex][str] then
        return parsedLinesCache[paletteIndex][str]
    end
    local lst = {}
    local oldChrType
    local force
    local forceDisable
    for i = 1, utf8.len(str) do
        local chr = utf8.sub(str, i, i)
        local nextChr = utf8.sub(str, i + 1, i + 1)

        local chrType
        if chr >= "0" and chr <= "9" then
            if oldChrType ~= 2 and nextChr ~= "x" then
                chrType = 1
            else
                chrType = 2
            end
        elseif (chr >= "A" and chr <= "Z") or (chr >= "a" and chr <= "z") or chr == "_" then
            chrType = 2
        elseif chr == "-" then
            chrType = 5
        elseif chr == "." or chr == ":" then
            chrType = 7
        elseif forceDisable and forceDisable[chr] then
            force = nil
        end

        if force then
            chrType = force
        elseif chr == "#" then
            force = 6
            forceDisable = {[" "] = true, ["\""] = true, ["'"] = true}
            chrType = force
        end            

        if not chrType or oldChrType ~= chrType or #lst == 0 then
            table.insert(lst, {})
            oldChrType = chrType
        end

        table.insert(lst[#lst], chr)
    end
    for i, v in ipairs(lst) do
        lst[i] = table.concat(v)
    end
    parsedLinesCache[paletteIndex][str] = lst
    return lst
end

function syntax_make(code, errorLine, yieldActive, customPalette)
    local bracketsValue = 0
    local currentPalette = palettes[customPalette or (localStorage.current.palette + 1)] or palettes[1]

    local _strSplit
    if yieldActive then
        _strSplit = strSplit
    else
        _strSplit = strSplitNoYield
    end

    local newstr = {}
    local gcomment
    for posY, str in ipairs(_strSplit(string, code, {"\n"})) do
        if posY == errorLine then
            if posY > 1 then
                table.insert(newstr, "\n")
            end
            local parts = parseLine(str)
            for lstrI, lstr in ipairs(parts) do
                if lstr ~= "" then
                    table.insert(newstr, "#ff0000")
                    table.insert(newstr, lstr)
                end
            end
        elseif not currentPalette.noHighlight then
            if posY > 1 then
                table.insert(newstr, "\n")
            end
            local lcomment = false
            local lostr = false
            local lostr2 = false
            local prev
            local parts = parseLine(str)
            local dotValue = 0
            local dotExists = false
            for lstrI, lstr in ipairs(parts) do
                if lstr ~= "" then
                    local lcolor
    
                    if lstr:sub(1, 2) == "--" then
                        lcomment = true
                    elseif lstr == "[" and parts[lstrI+1] == "[" then
                        gcomment = lcomment and currentPalette.commentColor or currentPalette.stringColor
                    end
    
                    local isStr = lostr or lostr2
                    if lstr == "\"" then
                        if not lostr2 then
                            lostr = not lostr
                        end
                    elseif lstr == "'" then
                        if not lostr then
                            lostr2 = not lostr2
                        end
                    elseif lstr == "." or lstr == ":" then
                        dotValue = dotValue + 1
                        if dotValue > #currentPalette.afterDotColors then
                            dotValue = 1
                        end
                        dotExists = true
                    end

                    if lstr == " " or lstr == "(" or lstr == "{" or lstr == "[" or lstr == "\"" or lstr == "'" then
                        dotExists = false
                        dotValue = 0
                    end
    
                    if lcomment or gcomment then
                        lcolor = gcomment or currentPalette.commentColor
                    elseif lostr or lostr2 or isStr then
                        lcolor = currentPalette.stringColor
                    elseif tonumber(lstr) then
                        lcolor = currentPalette.numberColor
                    elseif currentPalette.functionColor and parts[lstrI+1] == "(" then
                        lcolor = currentPalette.functionColor
                    else
                        lcolor = currentPalette.keywords[lstr]
                        if not lcolor and dotExists then
                            lcolor = currentPalette.afterDotColors[dotValue]
                        end
                        lcolor = lcolor or currentPalette.mainColor
                    end
    
                    if not lcomment and not gcomment then
                        if lstr == "(" or lstr == "[" or lstr == "{" then
                            bracketsValue = bracketsValue + 1
                            if bracketsValue > #currentPalette.bracketsColors then
                                bracketsValue = 1
                            end
                            lcolor = currentPalette.bracketsColors[bracketsValue] or currentPalette.bracketsColors[1]
                        elseif lstr == ")" or lstr == "]" or lstr == "}" then
                            lcolor = currentPalette.bracketsColors[bracketsValue] or currentPalette.bracketsColors[1]
                            bracketsValue = bracketsValue - 1
                            if bracketsValue < 1 then
                                bracketsValue = #currentPalette.bracketsColors
                            end
                        end
                    end
                    
                    if lstr == "]" and prev == "]" then
                        gcomment = false
                    end
    
                    table.insert(newstr, lcolor)
                    table.insert(newstr, lstr)
                    prev = lstr
                end
            end
        else
            if posY > 1 then
                table.insert(newstr, "\n")
            end
            table.insert(newstr, "#ffffff")
            table.insert(newstr, str)
        end
    end
    return table.concat(newstr)
end

local upFindTokens = {
    "function"
}

local upTokens = {
    "local function",
    "do",
    "while",
    "for",
    "if",
    "repeat"
}

local downTokens = {
    "end",
    "until",
}

local localDownTokens = {
    "else",
    "elseif",
}

local function isToken(str, token)
    if str:sub(1, #token) == token then
        return true
    elseif str:sub(#str - (#token - 1), #str) == token then
        return true
    end
end

function syntax_format(code, yieldActive)
    local tab = "    "
    local tabLevel = 0
    local newCode = {}
    local _strSplit
    if yieldActive then
        _strSplit = strSplit
    else
        _strSplit = strSplitNoYield
    end
    for _, str in ipairs(_strSplit(string, code, {"\n"})) do
        if #newCode > 0 then
            table.insert(newCode, "\n")
        end

        local newStr = {}
        local chrAdded = false
        for i = 1, #str do
            local char = str:sub(i, i)
            if (char ~= " " and char ~= "\t") or chrAdded then
                chrAdded = true
                table.insert(newStr, char)
            end
        end
        for i = 1, #newStr do
            if newStr[#newStr] == " " or newStr[#newStr] == "\t" then
                table.remove(newStr, #newStr)
            end
        end
        newStr = table.concat(newStr)
        if newStr:sub(1, 2) ~= "--" then
            local returnLevel = false
            local findedDownToken = false
            if tabLevel > 0 then
                for i, token in ipairs(localDownTokens) do
                    if isToken(newStr, token) then
                        tabLevel = tabLevel - 1
                        returnLevel = true
                        findedDownToken = true
                        break
                    end
                end

                if not returnLevel then
                    for i, token in ipairs(downTokens) do
                        if isToken(newStr, token) then
                            tabLevel = tabLevel - 1
                            findedDownToken = true
                            break
                        end
                    end
                end
            end

            local findedUpToken = false
            for i, token in ipairs(upTokens) do
                if isToken(newStr, token) then
                    findedUpToken = true
                    break
                end
            end

            if not findedUpToken then
                for i, token in ipairs(upFindTokens) do
                    if newStr:find(token) then
                        findedUpToken = true
                        break
                    end
                end
            end

            if findedDownToken and findedUpToken then
                tabLevel = tabLevel + 1
                findedUpToken = false
            end

            if tabLevel > 0 then
                table.insert(newCode, string.rep(tab, tabLevel))
            end

            if returnLevel or findedUpToken then
                tabLevel = tabLevel + 1
            end
        elseif tabLevel > 0 then
            table.insert(newCode, string.rep(tab, tabLevel))
        end
        table.insert(newCode, newStr)
    end
    return table.concat(newCode)
end