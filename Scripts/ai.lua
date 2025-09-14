if not better or not better.isAvailable() then return end

local ai_prompt = better.filesystem.readFile(sc.modPrefix .. "/ROM/chatGPTprompt.txt")
local baseCode = [[_enableCallbacks = true]]
local allowedChars = {}

for i = 33, 126 do
    allowedChars[string.char(i)] = true
end

local function simpleFind(str, test)
    for i = 1, #str do
        local endf = i + (#test - 1)
        if str:sub(i, endf) == test then
            return i, endf
        end
    end
end

local function trim(text)
    while true do
        if #text == 0 then
            break
        end
        local firstChar = text:sub(1, 1)
        if not allowedChars[firstChar] then
            text = text:sub(2, #text)
        else
            local lastChar = text:sub(#text, #text)
            if not allowedChars[lastChar] then
                text = text:sub(1, #text - 1)
            else
                break
            end
        end
    end
    return text
end

function ai_codeGen(prompt)
    local startpos = select(2, simpleFind(prompt, "--[[")) or 0
    local endpos = simpleFind(prompt, "]]") or (#prompt + 1)
    prompt = prompt:sub(startpos + 1, endpos - 1)
    while true do
        local firstChar = prompt:sub(1, 1)
        if firstChar == "\n" then
            prompt = prompt:sub(2, #prompt)
        else
            local lastChar = prompt:sub(#prompt, #prompt)
            if lastChar == "\n" then
                prompt = prompt:sub(1, #prompt - 1)
            else
                break
            end
        end
    end

    local async = better.openAI.textRequest(nil, nil, ai_prompt, prompt)

    return function ()
        local str = async()
        if str then
            local startpos = select(2, str:find("```lua")) or select(2, str:find("```")) or 0
            local endpos = str:find("```", startpos + 1) or (#str + 1)
            local code = trim(str:sub(startpos + 1, endpos - 1))
            local preCode = trim(str:sub(1, startpos - 6))
            local postCode = trim(str:sub(endpos + 6, #str))
            local selfPrompt = "--ai code-gen prompt:\n--[[\n" .. prompt .. "\n]]\n\n"
            if #code > 0 and load_code(nil, code) then
                return selfPrompt .. code .. "\n\n" .. baseCode .. "\n\n--[[\n" .. preCode .. "\n\n" .. postCode .. "\n]]", true
            else
                return selfPrompt .. str, false
            end
        end
    end
end