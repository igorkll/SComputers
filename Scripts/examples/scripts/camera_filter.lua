local display = getComponent("display")
display.reset()
display.clear()
display.setSkipAtNotSight(true) --in order for the picture not to be updated for those who do not look at the screen

local camera = getComponent("camera")
local fov = math.rad(60)
camera.setNonSquareFov(fov * (display.getWidth() / display.getHeight()), fov)
camera.setStep(512)
camera.setDetectableObjects({
    characters = true,
    dynamicBody = true,
    staticBody = true
})

local renderSettings = {
    lampLighting = false,
    shadows = false,
    smoothingTerrain = false,
    simpleShadows = true,
    sun = true, --is the solar disk being rendered
    fog = true,
    reduceAccuracy = true, --allows you to use fewer display effects in fog and simpleShadows, which increases performance in some cases

    constColor = nil, --allows you to make all objects in one color
    constDayLightValue = nil, --you can make a constant time of day
    shadowMultiplier = 0.6,
    sunPercentage = 0.003, --this value is the percentage of the sun from the size of the sky
    simpleShadowMin = 0.3, --the minimum brightness of an object that a simple shadow can give
    simpleShadowMax = 1, --the maximum brightness of an object that a simple shadow can give

    customWaterColor = nil,
    customChemicalColor = nil,
    customOilColor = nil,

    constSkyColor = nil, --by default, it depends on the time of day
    customSunColor = nil, --you can change the color of the sun
    constShapeColor = nil,
    customLiftColor = nil,
    constTerrainColor = nil, --you can make the whole terrain one color, even blue
    constCharacterColor = nil,
    constJointColor = nil,
    constHarvestableColor = nil, --allows all Harvestables to be the same color, instead of their real color
    constAssetsColor = nil, --you can set the constant color of assets so that it is always 1 and is not determined by the material

    customTerrainColor_dirt = nil,
    customTerrainColor_grass = nil,
    customTerrainColor_sand = nil,
    customTerrainColor_stone = nil,
}

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    if display.getAudience() > 0 then --if no one is looking at the screen at all, then the camera will not work
        camera.drawAdvanced(display, renderSettings)
        display.flush()
    end
end