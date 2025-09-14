dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/FileSystem.lua")
dofile("$CONTENT_DATA/Scripts/base64.lua")

romdisk = class()
romdisk.maxParentCount = 1
romdisk.maxChildCount = 0
romdisk.connectionInput = sm.interactable.connectionType.composite
romdisk.connectionOutput = sm.interactable.connectionType.none
romdisk.colorNormal = sm.color.new(0xbf1996ff)
romdisk.colorHighlight = sm.color.new(0xec1db9ff)
romdisk.componentType = "rom" --absences can cause problems
romdisk.pathStart = "$CONTENT_"
romdisk.pathStart2 = "$GAME_DATA/ROM"
romdisk.pathEnd = ".json"

local function isPathValid1(path)
    return (#path > #romdisk.pathStart and path:sub(1, #romdisk.pathStart) == romdisk.pathStart) or (#path > #romdisk.pathStart2 and path:sub(1, #romdisk.pathStart2) == romdisk.pathStart2)
end

local function isPathValid2(path)
    return path:sub(#path - (#romdisk.pathEnd - 1), #path) == romdisk.pathEnd
end

local function isPathValid(path)
    return isPathValid1(path) and isPathValid2(path)
end

function romdisk:server_onCreate()
    self.resetLagCounter = true

    self.sdata = self.storage:load() or {path = ""}
	self:sv_setData(self.sdata)

    local api
    api = {
        open = function ()
            if isPathValid(self.sdata.path) then
                if self.cache then
                    return self.cache
                end

                local result = sm.json.open(self.sdata.path)
                if self.resetLagCounter then
                    sc.resetLagCounter()
                    self.resetLagCounter = false
                end
                self.cache = result
                return result
            else
                error("the wrong path is specified in the ROM block settings", 2)
            end
        end,
        openFilesystemImage = function()
            if self.cacheFilesystemImage then
                return self.cacheFilesystemImage
            end

            local romsource = api.open()
            local fs = FileSystem.new(math.huge)

            for path, bs64 in pairs(romsource) do
                sc.yield()

                local strs = strSplitNoYield(string, path, {"/"})
                if path:sub(1, 1) == "/" then
                    table.remove(strs, 1)
                end
                if strs[#strs] == "" then
                    table.remove(strs)
                end
                table.remove(strs)

                local pth = "/"
                for _, str in ipairs(strs) do
                    pth = pth .. str
                    print("createFolder", pcall(fs.createFolder, fs, pth))
                    pth = pth .. "/"
                end

                fs:createFile(path)
                fs:writeFile(path, base64.decode(bs64, true))
            end

            fs.maxSize = 0
            self.cacheFilesystemImage = FileSystem.createFilesystemData(self, fs, {}, true)
            return self.cacheFilesystemImage
        end,
        openFilesystemDump = function()
            if self.cacheFilesystemDump then
                return self.cacheFilesystemDump
            end

            local fs = FileSystem.deserialize({jsondata = api.open()})
            fs.maxSize = 0
            self.cacheFilesystemDump = FileSystem.createFilesystemData(self, fs, {}, true)
            return self.cacheFilesystemDump
        end,
        isAvailable = function()
            return isPathValid(self.sdata.path)
        end,
        clearCache = function()
            self:sv_resetCache()
        end
    }

    self.interactable.publicData = {
        sc_component = {
            type = romdisk.componentType,
            api = api
        }
    }
end

function romdisk:sv_setData(data)
	data.path = tostring(data.path or "")
    self.sdata = data
    self.network:sendToClients("cl_setData", self.sdata)
    self.storage:save(self.sdata)
    self.resetLagCounter = true
    self:sv_resetCache()
end

function romdisk:sv_dataRequest(_, player)
    self.network:sendToClient(player, "cl_setData", self.sdata)
end

function romdisk:sv_resetCache()
    self.cache = nil
    self.cacheFilesystemImage = nil
    self.cacheFilesystemDump = nil
end

---------------------

function romdisk:client_onCreate()
	self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/romdisk.layout", false, { backgroundAlpha = 0 })
	self.gui:setTextChangedCallback("Path", "cl_onPathChanged")
	self.gui:setButtonCallback("Save", "cl_onPathChange")

    self.network:sendToServer("sv_dataRequest")
end

function romdisk:cl_onPathChanged(_, data)
	if #data <= 256 then
        if isPathValid1(data) then
            if isPathValid2(data) then
                self.cl_temp_path = data
                self:cl_guiError(nil)
            else
                self:cl_guiError("the path must end at " .. romdisk.pathEnd)
            end
        else
            self:cl_guiError("the path must start with " .. romdisk.pathStart .. " or " .. romdisk.pathStart2)
        end
	else
		self:cl_guiError("path is too long")
	end
end

function romdisk:cl_onPathChange()
    self.csdata.path = self.cl_temp_path
    self.network:sendToServer("sv_setData", self.csdata)
	self.gui:close()
end

function romdisk:client_onInteract(_, state)
	if state and self.csdata then
        self.cl_temp_path = self.csdata.path
        self.gui:setText("Path", tostring(self.cl_temp_path))
	    self:cl_onPathChanged(nil, self.cl_temp_path)
		self.gui:open()
	end
end

function romdisk:cl_guiError(text)
	if text ~= nil then
		self.gui:setVisible("Save", false)
        self.gui:setVisible("Error", true)
		self.gui:setText("Error", text)
	else
		self.gui:setVisible("Save", true)
        self.gui:setVisible("Error", false)
		self.gui:setText("Error", "")
	end
end

function romdisk:cl_setData(data)
    self.csdata = data
end

function romdisk:client_onDestroy()
	self.gui:destroy()
end