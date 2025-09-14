--camera documentation: http://igorkll.github.io/SComputers/camera.html
local fastmode = true

local camera = getComponent("camera")
local fov = math.rad(120)

local displays = getComponents("display")
local cameraForks = {}
for index, display in ipairs(displays) do
    display.reset()
    display.clear()
    display.flush()

    local cameraFork = camera.fork(true)
    cameraFork.setNonSquareFov(fov * (display.getWidth() / display.getHeight()), fov)
    cameraFork.setStep(512)
    cameraForks[index] = cameraFork
end

local renderSettings = {
    lampLighting = not fastmode,
    shadows = not fastmode,
    smoothingTerrain = not fastmode,
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
        for index, display in ipairs(displays) do
            display.clear()
            display.flush()
        end
        return
    end

    for index, display in ipairs(displays) do
        cameraForks[index].drawAdvanced(display, renderSettings)
        display.flush()
    end
end