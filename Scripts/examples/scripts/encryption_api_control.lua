--this code encrypts itself after the first shutdown.
--after the second shutdown, it overwrites itself with a new code that will no longer be encrypted (but if you remove return, the new code will also be encrypted)

function onTick(dt)
    print(getUptime(), isCodeEncrypted())
end

function onStop()
    if isCodeEncrypted() then
        setCode("print(\"THE CODE HAS BEEN DELETED\")")
        return --if you comment out this line, then after the second shutdown, the code that outputs a message about deleting the code in the chat will also be encrypted.
    end
    assert(encryptCode("here you can leave any message for the user who opens the computer\nthere may be several lines")) --passing a string is optional.
end

_enableCallbacks = true