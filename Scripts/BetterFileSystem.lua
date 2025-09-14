local vfs = sm.scomputers.require({}, "vfs")
local betterDisksDirectory = vfs.concat("/", "BetterDisks")

local function safeConcat(basePath, path)
    local char = path:sub(1, 1)
    if char == "/" or char == "\\" then
        path = path:sub(2, #path)
    end

    return vfs.safeConcat(basePath, path) or basePath
end

local function getPath(diskdata, path)
    local char = path:sub(1, 1)
    if char == "/" or char == "\\" then
        return safeConcat(diskdata.path, path)
    else
        return safeConcat(safeConcat(diskdata.path, diskdata.storageData.path), path)
    end
end

local function getLocalFullPath(diskdata, path)
    local char = path:sub(1, 1)
    if char == "/" or char == "\\" then
        return path
    else
        return safeConcat(diskdata.storageData.path, path)
    end
end

local function checkSize(api, diskdata, sizeDelta)
    if api.getUsedSize() + sizeDelta > api.getMaxSize() then
        error("Out of Memory!/No Memory.", 3)
    end
end

local function calcFolderSize(api, diskdata, path)
    local size = 0

    for _, filename in ipairs(api.getFileList(path)) do
        local localPath = vfs.concat(path, filename)
        size = size + api.getFileSize(localPath) + #getLocalFullPath(diskdata, localPath)
    end

    for _, dirname in ipairs(api.getFolderList(path)) do
        local localPath = vfs.concat(path, dirname)
        size = size + calcFolderSize(api, diskdata, localPath)
    end

    local selfFolderSize = 0
    if path ~= "/" then
        selfFolderSize = #getLocalFullPath(diskdata, path)
    end
    return size + selfFolderSize
end

local fastsavePath = "/.fastsave"
function createBetterFilesystemData(diskdata, readonly)
    local function readonlyCheck()
        if readonly then
            error("this filesystem is read-only", 3)
        end
    end

    local api
    api = {
        createFile = function (path)
            checkArg(1, path, "string")
            readonlyCheck()
            diskdata.changed = true
            initBetterDisk(diskdata)
            if api.hasFile(path) then
                error("File already exists", 2)
            end
            checkSize(api, diskdata, #getLocalFullPath(diskdata, path))
            return better.filesystem.writeFile(getPath(diskdata, path), "")
        end,
        readFile = function (path)
            checkArg(1, path, "string")
            checkSize(api, diskdata, 0)
            return better.filesystem.readFile(getPath(diskdata, path))
        end,
        writeFile = function (path, data)
            checkArg(1, path, "string")
            checkArg(2, data, "string")
            readonlyCheck()
            diskdata.changed = true
            initBetterDisk(diskdata)
            if not api.hasFile(path) then
                error("File doesn't exist", 2)
            end
            checkSize(api, diskdata, #data - api.getFileSize(path))
            better.filesystem.writeFile(getPath(diskdata, path), data)
        end,
        deleteFile = function (path)
            checkArg(1, path, "string")
            readonlyCheck()
            diskdata.changed = true
            better.filesystem.remove(getPath(diskdata, path))
        end,
        hasFile = function (path)
            checkArg(1, path, "string")
            local betterFsPath = getPath(diskdata, path)
            return better.filesystem.exists(betterFsPath) and not better.filesystem.isDirectory(betterFsPath)
        end,
        getFileSize = function (path)
            checkArg(1, path, "string")
            return better.filesystem.size(getPath(diskdata, path))
        end,

        createFolder = function (path)
            checkArg(1, path, "string")
            readonlyCheck()
            diskdata.changed = true
            initBetterDisk(diskdata)
            if api.hasFolder(path) then
                error("Folder already exists", 2)
            end
            checkSize(api, diskdata, #getLocalFullPath(diskdata, path))
            better.filesystem.makeDirectory(getPath(diskdata, path))
        end,
        deleteFolder = function (path)
            checkArg(1, path, "string")
            readonlyCheck()
            diskdata.changed = true
            better.filesystem.remove(getPath(diskdata, path))
        end,
        getFolderSize = function (path)
            checkArg(1, path, "string")
            return calcFolderSize(api, diskdata, path)
        end,
        hasFolder = function (path)
            checkArg(1, path, "string")
            return better.filesystem.isDirectory(getPath(diskdata, path))
        end,

        getUsedSize = function ()
            initBetterDisk(diskdata)
            return calcFolderSize(api, diskdata, "/")
        end,
        getMaxSize = function ()
            return diskdata.size
        end,
        getFileList = function (path)
            checkArg(1, path, "string")
            local betterFsPath = getPath(diskdata, path)
            local list = {}
            for _, localPath in ipairs(better.filesystem.list(betterFsPath)) do
                if not better.filesystem.isDirectory(vfs.concat(betterFsPath, localPath)) then
                    table.insert(list, localPath)
                end
                sc.yield()
            end
            return list
        end,
        getFolderList = function (path)
            checkArg(1, path, "string")
            local betterFsPath = getPath(diskdata, path)
            local list = {}
            for _, localPath in ipairs(better.filesystem.list(betterFsPath)) do
                if better.filesystem.isDirectory(vfs.concat(betterFsPath, localPath)) then
                    table.insert(list, localPath)
                end
                sc.yield()
            end
            return list
        end,
        openFolder = function (path)
            checkArg(1, path, "string")
            local path1 = diskdata.storageData.path
            local path2 = vfs.concat(diskdata.storageData.path, path)
            if #path2 > 1024 then
                error("what the hell are you doing?", 2)
            end
            diskdata.storageData.path = path2
            if path1 ~= diskdata.storageData.path then
                diskdata.changedPath = true
            end
        end,
        getCurrentPath = function ()
            return diskdata.storageData.path
        end,
        clear = function ()
            readonlyCheck()
            diskdata.changed = true
            better.filesystem.remove(getPath(diskdata, "/"))
        end,

        isReadOnly = function()
            return not not readonly
        end,


        --API for quick saving of settings (see the "simple disk using" example)
        setData = function (data)
            checkArg(1, data, "string")
            readonlyCheck()
            if not api.hasFile(fastsavePath) then
                api.createFile(fastsavePath)
            end
            api.writeFile(fastsavePath, data)
            diskdata.changed = true
        end,
        getData = function ()
            if api.hasFile(fastsavePath) then
                return api.readFile(fastsavePath)
            else
                return ""
            end
        end,
        setTable = function(tbl)
            checkArg(1, tbl, "table")
            readonlyCheck()
            local data = json.encode(tbl)
            if not api.hasFile(fastsavePath) then
                api.createFile(fastsavePath)
            end
            api.writeFile(fastsavePath, data)
            diskdata.changed = true
        end,
        getTable = function()
            local data
            if api.hasFile(fastsavePath) then
                data = api.readFile(fastsavePath)
            else
                return {}
            end

            local ok, tbl = pcall(json.decode, data)
            if ok and type(tbl) == "table" then
                return tbl
            end
            return {}
        end
    }
    return api
end