local utils = require("utils")
local gps = getComponent("gps")

local tagsLabel = "tag_xxxxxx"

function callback_loop()
    local gpsdata = gps.getSelfGpsData()

    logPrint("------------------------------------------------")
    logPrint("position-self", utils.roundTo(gpsdata.position.x, 1), utils.roundTo(gpsdata.position.y, 1), utils.roundTo(gpsdata.position.z, 1))
    logPrint("rotation-self", utils.roundTo(gpsdata.rotation.x, 1), utils.roundTo(gpsdata.rotation.y, 1), utils.roundTo(gpsdata.rotation.z, 1), utils.roundTo(gpsdata.rotation.w, 1))
    logPrint("rotation-euler-self", utils.roundTo(gpsdata.rotationEuler.x, 1), utils.roundTo(gpsdata.rotationEuler.y, 1), utils.roundTo(gpsdata.rotationEuler.z, 1))
    logPrint("velocity-self", utils.roundTo(gpsdata.velocity.x, 1), utils.roundTo(gpsdata.velocity.y, 1), utils.roundTo(gpsdata.velocity.z, 1))
    for i, v in ipairs(gps.getTagsGpsData(tagsLabel)) do
        logPrint("position-tag:" .. tostring(i), utils.roundTo(v.position.x, 1), utils.roundTo(v.position.y, 1), utils.roundTo(v.position.z, 1))
        logPrint("distance-tag:" .. tostring(i), utils.roundTo(v.distance, 1))
        logPrint("rotation-tag:" .. tostring(i), utils.roundTo(v.rotation.x, 1), utils.roundTo(v.rotation.y, 1), utils.roundTo(v.rotation.z, 1), utils.roundTo(v.rotation.w, 1))
        logPrint("rotation-euler-tag:" .. tostring(i), utils.roundTo(v.rotationEuler.x, 1), utils.roundTo(v.rotationEuler.y, 1), utils.roundTo(v.rotationEuler.z, 1))
        logPrint("velocity-tag:" .. tostring(i), utils.roundTo(v.velocity.x, 1), utils.roundTo(v.velocity.y, 1), utils.roundTo(v.velocity.z, 1))
    end
end