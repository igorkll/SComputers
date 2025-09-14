--if not _fsmanager then _fsmanager = true end
--_fsmanager = true

function fsmanager_init(self)
    function self:sv_fs_import(importPath, caller)
        local data
        pcall(function ()
            data = sm.json.open(importPath)
        end)
        if data then
            local gok = true
            print("openFolder", pcall(self.fs.openFolder, self.fs, "/"))
            for path, data in pairs(data) do
                data = base64.decode(data)

                
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
                    print("pth", pth)
                    print("createFolder", pcall(self.fs.createFolder, self.fs, pth))
                    pth = pth .. "/"
                end
                
                print("filepath", path)
                
                print("deleteFile", pcall(self.fs.deleteFile, self.fs, path))

                local ok, err = pcall(self.fs.createFile, self.fs, path)
                print("createFile", ok, err)
                if not ok then gok = "createFile: " .. path break end
                local ok, err = pcall(self.fs.writeFile, self.fs,  path, data)
                print("createFile", ok, err)
                if not ok then gok = "writeFile: " .. path break end
            end
            if gok == true then
                self.network:sendToClient(caller, "cl_internal_alertMessage", "successful import")
            else
                self.network:sendToClient(caller, "cl_internal_alertMessage", "import error " .. gok)
            end
        else
            self.network:sendToClient(caller, "cl_internal_alertMessage", "read error: " .. importPath)
        end
        self.changed = true
    end

    function self:sv_fs_export(exportPath, caller)
        local dump = {}
        print("openFolder", pcall(self.fs.openFolder, self.fs, "/"))
        local function recurse(lpath)
            for _, filename in ipairs(self.fs:getFileList(lpath)) do
                local filepath = lpath:sub(2, -1) .. filename
                local data = self.fs:readFile(filepath)
                dump[filepath] = base64.encode(data)
            end

            for _, folderpath in ipairs(self.fs:getFolderList(lpath)) do
                recurse(lpath .. folderpath .. "/")
            end
        end
        recurse("/")


        local ok, err = pcall(sm.json.save, dump, exportPath)
        if ok then
            self.network:sendToClient(caller, "cl_internal_alertMessage", "successful export")
        else
            self.network:sendToClient(caller, "cl_internal_alertMessage", "export error: " .. (err or "unknown"))
        end
    end
    
    function self:sv_fs_clear(_, caller)
        self.fs:clear()
        self.network:sendToClient(caller, "cl_internal_alertMessage", "successful clear")
        self.changed = true
    end

    ---------------------

    if not self.cl_internal_alertMessage then
        function self:cl_internal_alertMessage(text)
            sm.gui.displayAlertText(text)
        end
    end

    function self:cl_fs_clear()
        self.network:sendToServer("sv_fs_clear")
    end

    local function isValidWidgetPath(widgetName)
        return (widgetName:sub(1, 1) == "i" or widgetName:sub(1, 1) == "e") and #widgetName == 2
    end

    local function getWidgetPath(widgetName)
        if isValidWidgetPath(widgetName) then
            return "$CONTENT_DATA/USER/userdisks/" .. widgetName:sub(2, 2) .. ".json"
        else
            return "$CONTENT_DATA/USER/importer/disk.json"
        end
    end

    function self:cl_fs_export(widgetName)
        if not sm.isHost then sm.gui.displayAlertText("at the moment. works only when you are the host") return end
        self.network:sendToServer("sv_fs_export", getWidgetPath(widgetName))
    end

    function self:cl_fs_import(widgetName)
        if widgetName == "userImage" or isValidWidgetPath(widgetName) then
            if not sm.isHost then sm.gui.displayAlertText("at the moment. works only when you are the host") return end
            self.network:sendToServer("sv_fs_import", getWidgetPath(widgetName))
        elseif widgetName == "osImage" then
            self.network:sendToServer("sv_fs_import", "$CONTENT_DATA/ROM/gamedisks/scriptableOS.json")
        elseif widgetName == "pictures" then
            self.network:sendToServer("sv_fs_import", "$CONTENT_DATA/ROM/gamedisks/pics.json")
        elseif widgetName == "midis" then
            self.network:sendToServer("sv_fs_import", "$CONTENT_DATA/ROM/gamedisks/midis.json")
        elseif widgetName == "nbs" then
            self.network:sendToServer("sv_fs_import", "$CONTENT_DATA/ROM/gamedisks/nbs.json")
        end
    end

    function self:cl_fs_openImporter()
        if not better or not better.isAvailable() then
            sm.gui.displayAlertText("automatic opening requires betterAPI. the importer is located in the mod folder: /USER")
            return
        end

        better.filesystem.show(sc.modPrefix .. "/USER/importer")
    end
end

function fsmanager_open(self)
    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/fsMenu.layout", false)
	gui:setButtonCallback("clear", "cl_fs_clear")
	gui:setButtonCallback("userImage", "cl_fs_import")
    gui:setButtonCallback("export", "cl_fs_export")
    gui:setButtonCallback("openImporter", "cl_fs_openImporter")

    gui:setButtonCallback("osImage", "cl_fs_import")
    gui:setButtonCallback("pictures", "cl_fs_import")
    gui:setButtonCallback("midis", "cl_fs_import")
    gui:setButtonCallback("nbs", "cl_fs_import")
    
    for i = 1, 4 do
        gui:setButtonCallback("i" .. i, "cl_fs_import")
        gui:setButtonCallback("e" .. i, "cl_fs_export")
    end

    gui:open()
end