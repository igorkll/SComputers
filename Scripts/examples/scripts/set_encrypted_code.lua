--this code overwrites itself with another code that was previously encrypted
--if you need the code to overwrite itself with an unencrypted code, use setCode(code:string)
--if you need the code to encrypt itself, use encryptCode(message:string)

local enlua = require("enlua")

function onStart(dt)
    local bytecode = assert(enlua.compile("print(\"example\")")) --the code can be compiled on another machine and then transmitted over the network
    setEncryptedCode(bytecode, "USER MESSAGE") --an analog of setCode, but accepts an encrypted code immediately. It can be used to receive OTA updates in encrypted form
end

_enableCallbacks = true