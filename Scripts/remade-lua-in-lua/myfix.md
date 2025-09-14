## I will fix critical lua-in-lua bugs
### these tests did not pass the original lua-in-lua

```lua
if not start then
    notPassedArgument = true
    function a(notPassedArgument)
        return notPassedArgument and ("lua-in-lua") or ("normal lua")
    end

    start = true
end
print(a())
```

```lua
if not start then
    local anyVar = true
    function a()
        return anyVar and ("normal lua") or ("lua-in-lua")
    end

    start = true
end
print(a())
```

```lua
print(pcall(loadstring([[local asd = ...]])) and "normal lua" or "lua-in-lua")
```