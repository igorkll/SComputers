FileSystem = {}
FileSystem.__index = FileSystem

FileSystem.strSplit = strSplit

function FileSystem.new(maxSize)
    local instance = sc.setmetatable({}, FileSystem)

    instance.root = Folder.new("")
    instance.currentFolderPath = {}
    instance.maxSize = maxSize
    instance.currentSize = 0

    return instance
end

function FileSystem.parsePath(pathStr)
    local path = {}
    local insert = table.insert

    for i, v in pairs(strSplit(string, pathStr, {"/"})) do
        insert(path, v)
    end

    --[[
    for i, v in ipairs(path) do
        if v == "" then-- and not i == #path) then
            error("cannot parse empty name in path "..pathStr)
        end
    end

    insert(path, 1, "")
    ]]
    if path[#path] == "" then
        table.remove(path, #path)
    end
    --if pathStr:sub(1, 1) == "/" then
    --    insert(path, 1, "")
    --end

    return path
end

function FileSystem.concatPaths(basepath, to)
    local path
    --print("concatPaths 1", path, to)

    if to[1] == "" then --при не относительном пути базовый путь - пустой
        table.remove(to, 1)
        path = {""} --шоб не срабатывала проверка на пустой элемент
    else
        path = sc.deepcopy(basepath) --при относительном пути копируеться "базовый" путь
    end

    local insert = table.insert --обработка должна происходить даже на неотносительных путиях, так как иначе не будут работать ".." и "."
    local remove = table.remove
    for i, v in ipairs(to) do
        FileSystem._checkObjectName(v) --шоб небыло пустых элементов в пути
        if v == "." then
            --empty
        elseif v == ".." then
            if #path > 0 then
                remove(path)
            else
                --error("path .. underflow")
            end
        else
            insert(path, v)
        end
    end

    --print("concatPaths 2", path)
    return path
end

function FileSystem:_updateCurrentPath(path)
    local newCurrentPath = FileSystem.concatPaths(self.currentFolderPath, path)
    if #newCurrentPath > 1024 then
        error("what the hell are you doing?", 3)
    end
    self.currentFolderPath = newCurrentPath
end

function FileSystem:_checkHaveMemory(deltaSize)
    return self:getUsedSize() + deltaSize <= self.maxSize
end

function FileSystem._checkObjectName(name)
    if not name or name == "" then
        error("the folder/file name cannot be empty", 3)
    elseif name:find("/") then
        error("the folder/file name cannot contain the character /", 3)
    end
end


function FileSystem:createFile(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))
    local target = table.remove(path)
    self._checkObjectName(target)

    local folder = self:_getFolder(path)
    if not self:_checkHaveMemory(target:len()) then
        error("Out of Memory!/No Memory.", 2)
    end

    self.currentSize = self.currentSize + target:len()
    folder:createFile(target)
end

function FileSystem:readFile(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))
    local file = self:_getFile(path)

    return file:readData()
end

function FileSystem:writeFile(path, data)
    if type(data) ~= "string" then
        error("only strings can be saved", 2)
    end

    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))
    local file = self:_getFile(path)

    local currentData = file:readData()
    local deltaSize = data:len() - currentData:len()

    if not self:_checkHaveMemory(deltaSize) then
        error("Out of Memory!/No Memory.", 2)
    end

    self.currentSize = self.currentSize + deltaSize
    return file:writeData(data)
end

function FileSystem:deleteFile(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))

    local target = table.remove(path)
    local folder = self:_getFolder(path)

    local fileSize = folder:getFile(target):getSize()

    self.currentSize = self.currentSize - fileSize
    folder:deleteFile(target)
end

function FileSystem:hasFile(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))
    local target = table.remove(path)

    local folder = self:_getFolder(path)
    if folder then
        return folder:containsFile(target)
    end
    return false
end

function FileSystem:createFolder(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))

    local target = table.remove(path)
    self._checkObjectName(target)
    local folder = self:_getFolder(path)

    if not self:_checkHaveMemory(target:len()) then
        error("Out of Memory!/No Memory.", 2)
    end

    self.currentSize = self.currentSize + target:len()
    folder:createFolder(target)
end

function FileSystem:deleteFolder(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))

    local target = table.remove(path)
    local folder = self:_getFolder(path)

    local targetFolder = folder:getFolder(target)

    if not targetFolder:isEmpty() then
        error("Cant delete non-empty folder "..table.concat(path, '/')..'/'..target, 2)
    end
    
    local targetSize = targetFolder:getSize()
    self.currentSize = self.currentSize - targetSize

    folder:deleteFolder(target)
end

function FileSystem:hasFolder(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))
    --local target = table.remove(path)

    local ok, folder = pcall(self._getFolder, self, path)
    return not not (ok and folder)
    --if folder then
    --    return folder:containsFolder(target)
    --end
    --return false
end

function FileSystem:getFolderSize(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))

    local target = table.remove(path)
    local folder = self:_getFolder(path)

    return folder:getSize()
end

function FileSystem:getFileSize(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))

    --local target = table.remove(path)
    local file = self:_getFile(path)

    return file:getSize()
end

function FileSystem:getFolderList(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))

    local folder = self:_getFolder(path)
    return folder:getFolderList()
end

function FileSystem:getFileList(path)
    local path = FileSystem.concatPaths(self.currentFolderPath, FileSystem.parsePath(path))

    local folder = self:_getFolder(path)
    return folder:getFileList()
end

function FileSystem:getUsedSize()
    return self.currentSize
end

function FileSystem:openFolder(path)
    local path = FileSystem.parsePath(path)
    self:_updateCurrentPath(path)
end

function FileSystem:getCurrentPath()
    local str = table.concat(self.currentFolderPath, "/")
    if str:sub(1, 1) ~= "/" then
        str = "/" .. str
    end
    return str
end

function FileSystem:_getFolder(fullPath)
    --assert(fullPath[1] == "")
    --if fullPath[1] ~= "" then return self.root end

    local path = sc.deepcopy(fullPath)
    if path[1] == "" then table.remove(path, 1) end
    if path[#path] == "" then table.remove(path) end

    local folder = self.root
    for i, v in ipairs(path) do
        folder = folder:getFolder(v)
    end

    return folder
end

function FileSystem:_getFile(fullPath)
    --assert(fullPath[1] == "")

    local path = sc.deepcopy(fullPath)
    if path[1] == "" then table.remove(path, 1) end

    local target = table.remove(path)

    local folder = self.root
    for i, v in ipairs(path) do
        folder = folder:getFolder(v)
    end

    return folder:getFile(target)
end

function FileSystem:serialize()
    local tbl = {
        r = self.root:serialize(),
        cs = self.currentSize,
        ms = self.maxSize,
        cf = sc.deepcopy(self.currentFolderPath)
    }
    return {jsondata = json.encode(tbl)} --нативный json скрапа баговал
end

function FileSystem.deserialize(t)
    if t.jsondata then
        if type(t.jsondata) == "table" then
            t = t.jsondata
        else
            t = json.decode(t.jsondata) --нативный json скрапа баговал
        end
    end
    --print(t)

    local fs = FileSystem.new(t.ms or t.maxSize)
    fs.currentSize = t.cs or t.currentSize
    fs.currentFolderPath = sc.deepcopy(t.cf or t.currentFolderPath)
    fs.root = Folder.deserialize(t.r or t.root)

    return fs
end

function FileSystem:clear()
    self.root = Folder.new("")
    self.currentFolderPath = {}
    self.currentSize = 0
end



Folder = {}
Folder.__index = Folder

function Folder.new(name)
    local instance = sc.setmetatable({}, Folder)

    instance.name = name
    instance.files = {}
    instance.folders = {}

    return instance
end

function Folder:createFolder(name)
    if self:containsFolder(name) then
        error("Folder "..name.." already exists", 3)
    end
    
    table.insert(self.folders, Folder.new(name))
end

function Folder:createFile(name)
    if self:containsFile(name) then
        error("File "..name.." already exists", 3)
    end
    
    table.insert(self.files, File.new(name))
end

function Folder:deleteFile(name)
    local index = -1

    for i, v in ipairs(self.files or {}) do
        if v.name == name then
            index = i
            break
        end
    end

    if index == -1 then
        error("File "..name.." doesn't exist", 3)
    end
    
    table.remove(self.files, index)
end

function Folder:deleteFolder(name)
    local index = -1

    for i, v in ipairs(self.folders or {}) do
        if v.name == name then
            index = i
            break
        end
    end

    if index == -1 then
        error("Folder "..name.." doesn't exist", 3)
    end
    
    table.remove(self.folders, index)
end

function Folder:getFolder(name)
    for k, v in ipairs(self.folders or {}) do
        if v.name == name then
            return v
        end
    end
    error("Folder "..name.." doesn't exist", 3)
end

function Folder:getFile(name)
    for k, v in ipairs(self.files or {}) do
        if v.name == name then
            return v
        end
    end
    error("File "..name.." doesn't exist", 3)
end

function Folder:getSize()
    local treeSize = 0

    for i, v in ipairs(self.files or {}) do
        treeSize = treeSize + v:getSize()
    end

    for i, v in ipairs(self.folders or {}) do
        treeSize = treeSize + v:getSize()
    end

    return self.name:len() + treeSize
end

function Folder:containsFile(name)
    for i, v in ipairs(self.files or {}) do
        if v.name == name then
            return true
        end
    end

    return false
end

function Folder:containsFolder(name)
    for i, v in ipairs(self.folders or {}) do
        if v.name == name then
            return true
        end
    end

    return false
end

function Folder:isEmpty()
    return #self.files == 0 and #self.folders == 0
end

function Folder:getFolderList()
    local ret = {}
    local insert = table.insert

    for i, v in ipairs(self.folders or {}) do
        insert(ret, v.name)
    end

    return ret
end

function Folder:getFileList()
    local ret = {}
    local insert = table.insert

    for i, v in ipairs(self.files or {}) do
        insert(ret, v.name)
    end

    return ret
end

function Folder:serialize()
    local insert = table.insert

    local files = {}
    for i, v in ipairs(self.files or {}) do
        insert(files, v:serialize())
    end

    local folders = {}
    for i, v in ipairs(self.folders or {}) do
        insert(folders, v:serialize())
    end

    return {
        n = self.name,
        f = files,
        d = folders,
    }
end

function Folder.deserialize(t)
    local folder = Folder.new(t.n or t.name)
    local insert = table.insert

    local folders = {}
    for i, v in ipairs(t.d or t.folders or {}) do
        insert(folders, Folder.deserialize(v))
    end

    local files = {}
    for i, v in ipairs(t.f or t.files or {}) do
        insert(files, File.deserialize(v))
    end

    folder.files = files
    folder.folders = folders

    return folder
end






File = {}
File.__index = File

function File.new(name)
    local instance = sc.setmetatable({}, File)

    instance.name = name
    instance.data = ""

    return instance
end

function File:getSize()
    return self.name:len() + self.data:len()
end

function File:writeData(data)
    self.data = data
end

function File:readData()
    return self.data
end

function File:serialize()
    return {
        n = self.name,
        d = base64.encode(self.data)
    }
end

function File.deserialize(t)
    --the keys has been changed to save space
    local file = File.new(t.n or t.name)
    if t.base64encoded or t.d then
        file.data = base64.decode(t.d or t.data)
    else
        file.data = t.d or t.data
    end

    return file
end









local fastsavePath = "/.fastsave"
function FileSystem.createFilesystemData(_, fs, changeFlagTarget, readonly)
    local function readonlyCheck()
        if readonly then
            error("this filesystem is read-only", 3)
        end
    end

    return {
        createFile = function (path)
            --sc.checkComponent(self)

            readonlyCheck()
            changeFlagTarget.changed = true
            return fs:createFile(path)
        end,
        readFile = function (path)
            --sc.checkComponent(self)
            return fs:readFile(path)
        end,
        writeFile = function (path, data)
            --sc.checkComponent(self)
            readonlyCheck()
            changeFlagTarget.changed = true
            return fs:writeFile(path, data)            
        end,
        deleteFile = function (path)
            --sc.checkComponent(self)
            readonlyCheck()
            changeFlagTarget.changed = true
            return fs:deleteFile(path)
        end,
        hasFile = function (path)
            --sc.checkComponent(self)
            
            return fs:hasFile(path)
        end,
        getFileSize = function (path)
            --sc.checkComponent(self)
            
            return fs:getFileSize(path)
        end,

        createFolder = function (path)
            --sc.checkComponent(self)

            readonlyCheck()
            changeFlagTarget.changed = true
            return fs:createFolder(path)
        end,
        deleteFolder = function (path)
            --sc.checkComponent(self)

            readonlyCheck()
            changeFlagTarget.changed = true
            return fs:deleteFolder(path)
        end,
        getFolderSize = function (path)
            --sc.checkComponent(self)
            return fs:getFolderSize(path)
        end,
        hasFolder = function (path)
            --sc.checkComponent(self)
            return fs:hasFolder(path)
        end,

        getUsedSize = function ()
            --sc.checkComponent(self)
            return fs:getUsedSize()
        end,
        getMaxSize = function ()
            return fs.maxSize
        end,
        getFileList = function (path)
            --sc.checkComponent(self)
            return fs:getFileList(path)
        end,
        getFolderList = function (path)
            --sc.checkComponent(self)
            return fs:getFolderList(path)
        end,
        openFolder = function (path)
            --sc.checkComponent(self)

            local sum1 = tableChecksum(fs.currentFolderPath)
            fs:openFolder(path)
            local sum2 = tableChecksum(fs.currentFolderPath)
            if sum1 ~= sum2 then
                changeFlagTarget.changed = true
            end
        end,
        getCurrentPath = function ()
            --sc.checkComponent(self)
            return fs:getCurrentPath()
        end,
        clear = function ()
            --sc.checkComponent(self)

            readonlyCheck()
            changeFlagTarget.changed = true
            return fs:clear()
        end,

        isReadOnly = function()
            return not not readonly
        end,


        --API for quick saving of settings (see the "simple disk using" example)
        setData = function (data)
            checkArg(1, data, "string")
            readonlyCheck()
            if not fs:hasFile(fastsavePath) then
                fs:createFile(fastsavePath)
            end
            fs:writeFile(fastsavePath, data)
            changeFlagTarget.changed = true
        end,
        getData = function ()
            if fs:hasFile(fastsavePath) then
                return fs:readFile(fastsavePath)
            else
                return ""
            end
        end,
        setTable = function(tbl)
            checkArg(1, tbl, "table")
            readonlyCheck()
            local data = json.encode(tbl)
            if not fs:hasFile(fastsavePath) then
                fs:createFile(fastsavePath)
            end
            fs:writeFile(fastsavePath, data)
            changeFlagTarget.changed = true
        end,
        getTable = function()
            local data
            if fs:hasFile(fastsavePath) then
                data = fs:readFile(fastsavePath)
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
end

function FileSystem.createData(fs)
    local changeFlagTarget = {changed = false}
    local function isChange()
        local lchanged = changeFlagTarget.changed
        changeFlagTarget.changed = false
        return not not lchanged
    end
    return isChange, FileSystem.createFilesystemData(nil, fs, changeFlagTarget)
end

function FileSystem.createSelfData(self)
    return FileSystem.createFilesystemData(nil, self.fs, self)
end