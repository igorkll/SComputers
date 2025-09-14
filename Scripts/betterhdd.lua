dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/BetterFileSystem.lua")
local vfs = sm.scomputers.require({}, "vfs")
local betterDisksDirectory = vfs.concat("/", "BetterDisks")

betterhdd = class(nil)
betterhdd.maxParentCount = 1
betterhdd.maxChildCount = 0
betterhdd.connectionInput = sm.interactable.connectionType.composite
betterhdd.colorNormal = sm.color.new(0xbf1996ff)
betterhdd.colorHighlight = sm.color.new(0xec1db9ff)
betterhdd.componentType = "disk"
betterhdd.minBetterApi = 59

betterDisksLoaded = betterDisksLoaded or {}

function initBetterDisk(diskdata)
    better.filesystem.makeDirectory(betterDisksDirectory)
    better.filesystem.makeDirectory(vfs.concat(betterDisksDirectory, diskdata.storageData.key))
end

function betterhdd:server_onCreate()
    self.storageData = self.storage:load() or {path = "/"}
    if better and better.version >= betterhdd.minBetterApi and better.isAvailable("filesystem") then
        self.loaded = true

        if not self.storageData.key then
            self.storageData.key = tostring(sm.uuid.new())
            self.storage:save(self.storageData)
        elseif betterDisksLoaded[self.storageData.key] then
            local oldKey = self.storageData.key
            self.storageData.key = tostring(sm.uuid.new())
            print("two better disks with the same uuid exist simultaneously, automatic cloning", oldKey, ">", self.storageData.key)
            self:sv_cloneBetterDisk(oldKey)
            self.storage:save(self.storageData)
        end

        self.loadedData = {
            path = vfs.concat(betterDisksDirectory, self.storageData.key)
        }

        betterDisksLoaded[self.storageData.key] = true
    end

    self.diskdata = {
        storageData = self.storageData,
        path = self.loadedData.path,
        size = self.data.size
    }

    self.interactable.publicData = {
        sc_component = {
            type = betterhdd.componentType,
            api = self.loaded and createBetterFilesystemData(self.diskdata) or {}
        }
    }

    if self.loaded then
        self.network:sendToClients("cl_n_onLoad", self.loadedData)
    end
end

function betterhdd:sv_dataRequest(_, caller)
    if self.loaded then
        self.network:sendToClient(caller, "cl_n_onLoad", self.loadedData)
    end
end

function betterhdd:server_onFixedUpdate()
    if self.diskdata.changedPath then
        self.storage:save(self.storageData)
    end
end

function betterhdd:server_onDestroy()
    if self.loaded and self.storageData.key then
        betterDisksLoaded[self.storageData.key] = nil
    end
end

function betterhdd:sv_cloneBetterDisk(base)
    local baseDirectory = vfs.concat(betterDisksDirectory, base)
    local newDirectory = vfs.concat(betterDisksDirectory, self.storageData.key)
    better.filesystem.copy(baseDirectory, newDirectory)
end

function betterhdd:sv_n_clear()
    better.filesystem.remove(self.diskdata.path)
end

-----------------------------------------------------------

function betterhdd:client_onCreate()
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/betterdisk.layout")
    self.gui:setButtonCallback("clear", "cl_g_clear")
    self.gui:setButtonCallback("open", "cl_g_open")

    self.network:sendToServer("sv_dataRequest")
end

function betterhdd:client_onInteract(_, state)
    if state and self.cl_loadedData then
        self.gui:open()
    end
end

function betterhdd:client_canInteract()
    if self.cl_loadedData then
        return true
    end
    
    sm.gui.setInteractionText("", "#ff0000the host must have betterAPI installed to use this disk (minimal: " .. betterhdd.minBetterApi .. ")", "")
    return false
end

function betterhdd:cl_g_clear()
    self.network:sendToServer("sv_n_clear")
end

function betterhdd:cl_g_open()
    if self.diskdata then
        initBetterDisk(self.diskdata)
        better.filesystem.show(self.cl_loadedData.path)
    else
        sm.gui.displayAlertText("#ff0000only the host can open the file directory")
    end
end

function betterhdd:cl_n_onLoad(loadedData)
    self.cl_loadedData = loadedData
end