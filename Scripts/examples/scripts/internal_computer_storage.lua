--each computer has a storage capacity of 4 kilobytes.
--this storage is built into the computer unit and allows you to store data.
--this storage can be accessed via the setData/getData/setTable/getTable methods
--you can even create a small file system there (see the "raw filesystem" example)
--the data you save remains when you re-enter the world and when you save it to the blueprint

local function printTable(tbl)
    print("table: ", sm.json.writeJsonString(tbl))
end

local function printRaw(obj)
    print("raw: ", obj)
end

print("-----------------------")

-- table access
--getTable tries to deserialize the row obtained from getData, if it fails, it will return an empty table
setTable({5, 6, 7})
printTable(getTable())
setTable({1, 2, 3})
printTable(getTable())

-- raw access
printRaw(getData())
setData("NOT TABLE VALUE")
printRaw(getData())
printTable(getTable())

function callback_loop()
end