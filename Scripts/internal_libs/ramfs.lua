dofile("$CONTENT_DATA/Scripts/FileSystem.lua")

function sc_reglib_ramfs()
local ramfs = {}

local function makeobj(nativefs)
    local isChange, fs = FileSystem.createData(nativefs)
    return {
        fs = fs,

        _fs = nativefs,
        _isChange = isChange,

        dump = ramfs.dump,
        isChange = ramfs.isChange
    }
end



function ramfs.create(size)
    checkArg(1, size, "number")
    return makeobj(FileSystem.new(size))
end

function ramfs.load(dump)
    checkArg(1, dump, "string")
    return makeobj(FileSystem.deserialize({jsondata = dump}))
end



function ramfs:dump()
    return self._fs:serialize().jsondata
end

function ramfs:isChange()
    return self._isChange()
end

return ramfs
end