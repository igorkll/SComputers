local strtool = string

function sc_reglib_vfs(self, env)
local vfshost = {}
local vfs = {}

local function formatPathWithoutEndSlash(path)
    path = path:gsub("\\", "/")
    local pathLen = strtool.len(path)
    if pathLen > 1 and strtool.sub(path, pathLen, pathLen) == "/" then path = strtool.sub(path, 1, pathLen - 1) end
    return path
end

local function formatPathWithEndSlash(path)
    path = path:gsub("\\", "/")
    local pathLen = strtool.len(path)
    if strtool.sub(path, pathLen, pathLen) ~= "/" then path = path .. "/" end
    return path
end

local function formatPathWithoutStartSlash(path)
    path = path:gsub("\\", "/")
    local pathLen = strtool.len(path)
    if strtool.sub(path, 1, 1) == "/" then path = strtool.sub(path, 2, pathLen) end
    return path
end

--------------------------------------- vfshost

function vfshost:mount(path, fs)
    checkArg(1, path, "string")
    checkArg(2, fs, "table")
    table.insert(self.mountList, {formatPathWithoutEndSlash(path), fs})
    table.sort(self.mountList, function(a, b)
        return strtool.len(a[1]) > strtool.len(b[1])
    end)
end

function vfshost:get(path)
    checkArg(1, path, "string")
    path = formatPathWithEndSlash(self:absolute(path))
    for _, mount in ipairs(self.mountList) do
        local mountPath = formatPathWithEndSlash(mount[1])
        if strtool.sub(path, 1, strtool.len(mountPath)) == mountPath then
            return mount[2], formatPathWithoutEndSlash(strtool.sub(path, strtool.len(mountPath), strtool.len(path)))
        end
    end
end

function vfshost:unmount(pathOrFs)
    checkArg(1, pathOrFs, "string", "table")
    local unmounted = false
    if type(pathOrFs) == "table" then
        for i = #self.mountList, 1, -1 do
            local mount = self.mountList[i]
            if mount[2] == pathOrFs then
                unmounted = true
                table.remove(self.mountList, i)
            end
        end
    else
        for i = #self.mountList, 1, -1 do
            local mount = self.mountList[i]
            if self:equals(mount[1], pathOrFs) then
                unmounted = true
                table.remove(self.mountList, i)
            end
        end
    end
    return unmounted
end

function vfshost:mounts()
    return self.mountList
end

function vfshost:absolute(path)
    return vfs.concat(self.workingDirectory, path)
end

function vfshost:equals(...)
    local paths = {...}
    local oldPath
    for i, v in ipairs(paths) do
        local path = self:absolute(v)
        if oldPath and path ~= oldPath then
            return false
        end
        oldPath = path
    end
    return true
end

local function get(self, path)
    local fs, internalPath = self:get(path)
    if not fs then
        error("there is no filesystem mounted on the path \"" .. path .. "\"", 3)
    end
    return fs, internalPath
end

---------------

function vfshost:openFolder(path)
    checkArg(1, path, "string")
    self.workingDirectory = vfs.concat(self.workingDirectory, path)
end

function vfshost:getCurrentPath()
    return self.workingDirectory
end

---------------

local directList = {
    "createFile",
    "createFolder",
    "deleteFile",
    "deleteFolder",
    "writeFile",
    "readFile",
    "hasFile",
    "hasFolder",
    "getFileSize",
    "getFolderSize",
    "getFileList",
    "getFolderList"
}

for _, name in ipairs(directList) do
    vfshost[name] = function (self, path, ...)
        local fs, internalPath = get(self, path)
        return fs[name](internalPath, ...)
    end
end

---------------

function vfshost:hasMount(path)
    local findName = vfs.name(path)
    path = formatPathWithEndSlash(vfs.path(self:absolute(path)))
    for _, mount in ipairs(self.mountList) do
        local mountName = vfs.name(mount[1])
        if self:equals(path, vfs.path(mount[1])) and not self:equals(mount[1], "/") and findName == mountName then
            return true
        end
    end
    return false
end

function vfshost:getMountList(path)
    path = formatPathWithEndSlash(self:absolute(path))
    local mountList = {}
    for _, mount in ipairs(self.mountList) do
        if self:equals(path, vfs.path(mount[1])) and not self:equals(mount[1], "/") then
            table.insert(mountList, vfs.name(mount[1]))
        end
    end
    return mountList
end

---------------

function vfshost:pCreateFolder(path)
    local elements = vfs.elements(formatPathWithoutStartSlash(self:absolute(path)))
    local oldPath = "/"
    for _, element in ipairs(elements) do
        sc.yield()
        local folderPath = vfs.concat(oldPath, element)
        pcall(self.createFolder, self, folderPath)
        oldPath = folderPath
    end
end

function vfshost:pCreateFile(path)
    self:pCreateFolder(vfs.path(path))
    if not self:hasFile(path) then
        self:createFile(path)
    end
end

function vfshost:pWriteFile(path, data)
    self:pCreateFile(path)
    return self:writeFile(path, data)
end

function vfshost:pReadFile(path)
    local ok, result = pcall(self.readFile, self, path)
    if ok then
        return result
    end
end

function vfshost:pDeleteFile(path)
    return (pcall(self.deleteFile, self, path))
end

function vfshost:pDeleteFolder(path)
    return (pcall(self.deleteFolder, self, path))
end

function vfshost:pGetFileSize(path)
    local ok, result = pcall(self.getFileSize, self, path)
    if ok then
        return result
    end
end

function vfshost:pGetFolderSize(path)
    local ok, result = pcall(self.getFolderSize, self, path)
    if ok then
        return result
    end
end

function vfshost:pHasFile(path)
    local ok, result = pcall(self.hasFile, self, path)
    if ok then
        return result
    end
    return false
end

function vfshost:pHasFolder(path)
    local ok, result = pcall(self.hasFolder, self, path)
    if ok then
        return result
    end
    return false
end

function vfshost:pGetFileList(path)
    local ok, result = pcall(self.getFileList, self, path)
    if ok then
        return result
    end
    return {}
end

function vfshost:pGetFolderList(path)
    local ok, result = pcall(self.getFolderList, self, path)
    if ok then
        return result
    end
    return {}
end

---------------

function vfshost:recursionDelete(path, deleteContentsMountPoints)
    sc.yield()

    for _, file in ipairs(self:pGetFileList(path)) do
        sc.yield()
        self:pDeleteFile(vfs.concat(path, file))
    end

    for _, dir in ipairs(self:pGetFolderList(path)) do
        sc.yield()
        self:recursionDelete(vfs.concat(path, dir))
    end

    if deleteContentsMountPoints then
        for _, mount in ipairs(self:getMountList(path)) do
            sc.yield()
            self:recursionDelete(vfs.concat(path, mount))
        end
    end

    self:pDeleteFolder(path)
end

function vfshost:recursionCopy(path, path2, copyContentsMountPoints)
    sc.yield()
    path = self:absolute(path)
    path2 = self:absolute(path2)
    self:pCreateFolder(path2)

    for _, file in ipairs(self:pGetFileList(path)) do
        sc.yield()
        self:pWriteFile(vfs.concat(path2, file), self:readFile(vfs.concat(path, file)))
    end

    for _, dir in ipairs(self:pGetFolderList(path)) do
        sc.yield()
        local from = vfs.concat(path, dir)
        if not self:equals(from, path2) then
            self:recursionCopy(from, vfs.concat(path2, dir))
        end
    end

    if copyContentsMountPoints then
        for _, mount in ipairs(self:getMountList(path)) do
            sc.yield()
            local from = vfs.concat(path, mount)
            if not self:equals(from, path2) then
                self:recursionCopy(from, vfs.concat(path2, mount))
            end
        end
    end
end

---------------------------------------

function vfs.createHost()
    return sc.setmetatable({mountList = {}, workingDirectory = "/"}, vfshost)
end

function vfs.elements(path)
    path = formatPathWithoutEndSlash(path)

    local elements = {}
    for i, element in ipairs(strSplit(strtool, path, "/")) do
        elements[i] = element
    end
    return elements
end

function vfs.resolve(...)
    local elementsList = {...}
    local newElements = {}
    for _, elements in ipairs(elementsList) do
        for _, element in ipairs(elements) do
            if element == "." then
            elseif element == ".." then
                if newElements[#newElements] ~= "" then
                    table.remove(newElements)
                end
            elseif element == "" then
                newElements = {""}
            else
                table.insert(newElements, element)
            end
        end
    end
    if #newElements == 1 and newElements[1] == "" then
        return "/"
    end
    return table.concat(newElements, "/")
end

function vfs.concat(...)
    local paths = {...}
    for i, path in ipairs(paths) do
        paths[i] = vfs.elements(path)
    end
    return vfs.resolve(unpack(paths))
end

function vfs.safeConcat(rootpath, ...)
    rootpath = formatPathWithEndSlash(rootpath)

    local paths = {rootpath, ...}
    for i, path in ipairs(paths) do
        paths[i] = vfs.elements(path)
    end

    local resultPath = vfs.resolve(unpack(paths))
    resultPath = formatPathWithEndSlash(resultPath)
    if strtool.sub(resultPath, 1, strtool.len(rootpath)) ~= rootpath then
        return
    end

    return formatPathWithoutEndSlash(resultPath)
end

function vfs.isGlobalPath(path)
    local firstChar = strtool.sub(path, 1, 1)
    return firstChar == "/" or firstChar == "\\"
end

function vfs.path(path)
    local elements = vfs.elements(path)
    table.remove(elements)
    return vfs.resolve(elements)
end

function vfs.name(path)
    local elements = vfs.elements(path)
    return table.remove(elements)
end

function vfs.hideExtension(name)
    local newName = {}
    for i = 1, strtool.len(name) do
        local char = strtool.sub(name, i, i)
        if char == "." then
            break
        end
        table.insert(newName, char)
    end
    return table.concat(newName)
end

function vfs.getExtension(name)
    local newName = {}
    for i = strtool.len(name), 1, -1 do
        local char = strtool.sub(name, i, i)
        if char == "." then
            break
        end
        table.insert(newName, 1, char)
    end
    return table.concat(newName)
end

return vfs
end