warnings = {}
regularWarnings = {}

if better then
    if not better.version or better.version < sc.actualBetterAPI or (canvasAPI and better.version < canvasAPI.actualBetterAPI) then
        table.insert(warnings, "#FF0000WARNING#FFFFFF: you have an outdated version of the betterAPI \"" .. (better.version or "unknown") .. "\" installed. currently, the current version is \"" .. sc.actualBetterAPI .. "\". please update betterAPI: https://steamcommunity.com/sharedfiles/filedetails/?id=3177944610")
    end
else
    --table.insert(warnings, "#FF0000WARNING#FFFFFF: the betterAPI is not installed, the mod will use the LUA virtual machine, which may cause the code to malfunction.\nit is recommended to install betterAPI: https://steamcommunity.com/sharedfiles/filedetails/?id=3177944610")
end

--[[
dofile("$CONTENT_DATA/Scripts/loadCanvas.lua")
if not canvasAPI then
    table.insert(regularWarnings, "#FF0000WARNING#FFFFFF: for some reason, you did not download the display framework automatically, the displays will not work until you manually download: https://steamcommunity.com/sharedfiles/filedetails/?id=3202981462")
elseif canvasAPI.version ~= sc.actualCanvasVersion then
    print("CANVAS VERSION", canvasAPI.version)
    print("ACTUAL CANVAS", sc.actualCanvasVersion)
    table.insert(regularWarnings, "#FF0000WARNING#FFFFFF: the version of the canvas api and SComputers do not match. the displays may not work. please re-subscribe to canvas api and SComputers. if you are not subscribed to the canvas api, then subscribe, then unsubscribe and subscribe again:\ncanvas-api: https://steamcommunity.com/sharedfiles/filedetails/?id=3202981462\nSComputers: https://steamcommunity.com/sharedfiles/filedetails/?id=2949350596")
end
]]

function sc.warningsCheck()
    if _checked then return end
    _checked = true

    local origBlockUuid = sm.uuid.new("41d7c8b2-e2de-4c29-b842-5efd8af37ae6") --old screen pixel uuid
    if pcall(sm.shape.createPart, origBlockUuid, sm.vec3.new(0, 0, 10000)) then
        table.insert(warnings, "#FF0000CRITICAL ERROR#FFFFFF: SComputers conflicts with ScriptableComputer or another fork of ScriptableComputer!!!! URGENTLY REMOVE ALL OTHER COMPUTER MODS FROM YOUR WORLD, OTHERWISE SCOMPUTERS WILL NOT WORK")
        sc.shutdownFlag = true
    end
end