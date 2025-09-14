local fs = global.better.filesystem

function onStart()
    fs.makeDirectory("/SComputers_filesystem_example")
    fs.makeDirectory("/SComputers_filesystem_example/mkdir")
    fs.makeDirectory("/SComputers_filesystem_example/mkdir/test")
    fs.makeDirectory("/SComputers_filesystem_example/folder")
    fs.writeFile("/SComputers_filesystem_example/folder/test.txt", "just a text file")
    fs.writeFile("/SComputers_filesystem_example/readme.txt", "this example shows how the betterAPI file system works")
    logPrint(fs.readFile("/SComputers_filesystem_example/readme.txt"))
    fs.show("/SComputers_filesystem_example")
end

function onStop()
    fs.remove("/SComputers_filesystem_example")
end

_enableCallbacks = true