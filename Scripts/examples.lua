--[[
_g_examples = nil

function loadExample(self, widgetName, text)
    if widgetName == "exmpnum" then
        self.lastExampleStr = text
        return
    elseif widgetName == "exmpload" then
        if self.lastExampleStr then
            local example = _g_examples[self.lastExampleStr] or _g_examples[self.lastExampleStr:gsub(" ", "_")] or _g_examples_num[tonumber(self.lastExampleStr) or false]
            if example then
                ScriptableComputer.cl_setText(self, example)
            else
                self:cl_internal_alertMessage("failed to load an example")
            end
        end
    end
end

function exampleLabelConvert(name)
    return name:gsub("_", " ")
end

function initExamples()
    if not _g_examples then
        _g_examples_lastI = 0
        _g_examples_labels = {}
        _g_examples_num = {}

        _g_examples = sm.json.open(sc.modPrefix .. "/Scripts/examples/examples.json")
        local list = {}
        for k, v in pairs(_g_examples) do
            table.insert(list, k)
            _g_examples[k] = base64.decode(v)
        end
        table.sort(list)
        
        for _, name in ipairs(list) do
            _g_examples_lastI = _g_examples_lastI + 1
            _g_examples_num[_g_examples_lastI] = _g_examples[name]
            _g_examples_labels[_g_examples_lastI] = exampleLabelConvert(name)
        end
    end
end


function addCustomExample(name, code)
    initExamples()
    _g_examples_lastI = _g_examples_lastI + 1
    _g_examples_labels[_g_examples_lastI] = exampleLabelConvert(name)
    _g_examples[name] = code
    _g_examples_num[_g_examples_lastI] = _g_examples[name]
end

function bindExamples(self)
    initExamples()
    updateExamples(self)
    self.gui:setButtonCallback("exmpload", "cl_onExample")
    self.gui:setTextChangedCallback("exmpnum", "cl_onExample")
end

function updateExamples(self, search)
    local text = {}
    if search and search ~= "" then
        search = search:lower()
        for i, name in ipairs(_g_examples_labels) do
            if name:lower():find(search) then
                table.insert(text, tostring(i))
                table.insert(text, ". ")
                table.insert(text, name)
                table.insert(text, "\n")
            end
        end
    else
        for i, name in ipairs(_g_examples_labels) do
            table.insert(text, tostring(i))
            table.insert(text, ". ")
            table.insert(text, name)
            table.insert(text, "\n")
        end
    end
    table.remove(text, #text)
    self.gui:setText("exmplist", table.concat(text))
end
]]

scExamples_binded = scExamples_binded or {}
scExamples_list = scExamples_list or {}

local function initArchitecture(architecture)
    if not scExamples_binded[architecture] then scExamples_binded[architecture] = {} end
    if not scExamples_list[architecture] then scExamples_list[architecture] = {} end
end

function addCustomExample(name, code, architecture, bottom)
    architecture = architecture or "lua"
    initArchitecture(architecture)
    if scExamples_binded[architecture][name] then
        for _, data in ipairs(scExamples_list[architecture]) do --example overwrite
            if data[1] == name then
                data[2] = code
                break
            end
        end
        return
    end
    scExamples_binded[architecture][name] = true
    if bottom then
        table.insert(scExamples_list[architecture], 1, {name, code})
    else
        table.insert(scExamples_list[architecture], {name, code})
    end
end

local examplesCache = {}
function loadExamples(path, architecture)
    if examplesCache[path] then return examplesCache[path] end
    path = path or (sc.modPrefix .. "/Scripts/examples/examples.json")
    architecture = architecture or "lua"
    initArchitecture(architecture)

    do
        local sortedNames = {}
        local rawExamples
        if not __SCMFRAMEWORK then
            rawExamples = sm.json.open(path)
        else
            rawExamples = {}
        end
        for name in pairs(rawExamples) do
            table.insert(sortedNames, name)
        end
        table.sort(sortedNames, function(a, b) return a > b end)
        
        for _, name in ipairs(sortedNames) do
            addCustomExample(name:gsub("_", " "), base64.decode(rawExamples[name]), architecture, true)
        end
    end

    ---------------------------

    local examples = {}
    examples.list = {}
    examples.listKV = {}

    for index, data in ipairs(scExamples_list[architecture]) do
        table.insert(examples.list, data)
        local name = data[1]:lower()
        examples.listKV[name] = data[2]
        examples.listKV[tostring(index) .. ". " .. name] = data[2]
    end

    function examples.getList(search)
        local text = {}
        
        local function searchCheck(name)
            if search and search ~= "" then
                return not not name:lower():find(search:lower())
            end
            return true
        end

        for index, data in ipairs(examples.list) do
            if searchCheck(data[1]) then
                table.insert(text, tostring(index))
                table.insert(text, ". ")
                table.insert(text, data[1])
                table.insert(text, "\n")
            end
        end

        table.remove(text, #text)
        return table.concat(text)
    end

    function examples.load(name)
        name = tostring(name)

        local index = tonumber(name)
        if index and examples.list[index] then
            return examples.list[index][2]
        end

        return examples.listKV[name:lower()]
    end

    examplesCache[path] = examples
    return examples
end