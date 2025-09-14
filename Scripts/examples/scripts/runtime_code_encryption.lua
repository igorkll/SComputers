--the library can be used to encrypt code outside the computer block (for example, to encrypt code on a disk)
local enlua = require("enlua")

local bytecode = assert(enlua.compile("myenvtest('hello, encrypted code!')"))

logPrint("last enlua version: ", enlua.lastVersion())
logPrint("bytecode   version: ", enlua.version(bytecode))

local func = assert(enlua.load(bytecode, {myenvtest = logPrint})) --you can execute encrypted code in the sandbox in exactly the same way as in the case of a regular loadstring
func()

function callback_loop()
end