--filesystems (even file systems created in RAM, see the "raw filesystem" example) have a simplified API for saving data
--this API allows you to save a string to disk without creating files.
--you can also use methods for the table, then it will be serialized and overwrite the row saved in setData
--this API saves a row or a sterilized table to a file .fastsave in the file system
--this API is identical to the built-in computer storage API (see the "internal computer storage" example)

local disk = getComponent("disk")

local function printTable(tbl)
    print("table: ", sm.json.writeJsonString(tbl))
end

local function printRaw(obj)
    print("raw: ", obj)
end

print("-----------------------")

-- table access
--getTable tries to deserialize the row obtained from getData, if it fails, it will return an empty table
disk.setTable({5, 6, 7})
printTable(disk.getTable())
disk.setTable({1, 2, 3})
printTable(disk.getTable())

-- raw access
printRaw(disk.getData())
disk.setData("NOT TABLE VALUE")
printRaw(disk.getData())
printTable(disk.getTable())

function callback_loop()
end