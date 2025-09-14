local xEngine = require("xEngine")
local engine = xEngine.create()

local display = getComponent("display")
local wasd = getComponents("wasd")[1]

local speed = 0.3
local rotationSpeed = 3
local renderSettings = {
    lampLighting = false,
    shadows = true,
    smoothingTerrain = false,
    simpleShadows = true,
    sun = true, --is the solar disk being rendered
    fog = true,
    reduceAccuracy = false, --allows you to use fewer display effects in fog and simpleShadows, which increases performance in some cases

    constColor = nil, --allows you to make all objects in one color
    constDayLightValue = 0.5, --you can make a constant time of day
    shadowMultiplier = 0.3,
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

local cameraPosition = sm.vec3.new(0, 2, 1)
local cameraRotation = 0

function onStart()
    for ix = -4, 4 do
        for iy = -4, 4 do
            local shape = engine:addShape(xEngine.shapes.box_16x16x1,
                sm.vec3.new(ix * 4, iy * 4, 0),
                sm.quat.fromEuler(sm.vec3.new(0, 0, 0)),
                false
            )
            shape:setColor((ix + iy) % 2 == 0 and 0xff0000 or 0xffff00)
        end
    end

    local shapeX, shapeY = 4, 2
    for i = 1, 80 do
        local shape = engine:addShape(xEngine.shapes.box_1x1x1,
            sm.vec3.new(shapeX, shapeY, 2 + (i / 2)),
            sm.quat.fromEuler(sm.vec3.new(0, 0, 0)),
            true
        )
    end
    sphere = engine:addShape(xEngine.shapes.sphere_16,
        sm.vec3.new(shapeX - 2, shapeY - 2, 50),
        sm.quat.fromEuler(sm.vec3.new(0, 0, 0)),
        true
    )

    local fov = math.rad(90)
    camera = engine:addCamera()
    camera.api.setStep(2048)
    camera.api.setNonSquareFov(fov * (display.getWidth() / display.getHeight()), fov)
    camera.api.setDistance(64)
end

function onTick(dt)
    if wasd then
        if wasd.isW() then
            cameraPosition.x = cameraPosition.x + (math.cos(math.rad(cameraRotation)) * speed)
            cameraPosition.y = cameraPosition.y + (math.sin(math.rad(cameraRotation)) * speed)
        elseif wasd.isS() then
            cameraPosition.x = cameraPosition.x - (math.cos(math.rad(cameraRotation)) * speed)
            cameraPosition.y = cameraPosition.y - (math.sin(math.rad(cameraRotation)) * speed)
        end
        if wasd.isA() then
            cameraRotation = cameraRotation + rotationSpeed
        elseif wasd.isD() then
            cameraRotation = cameraRotation - rotationSpeed
        end
    end
    camera:setPosition(cameraPosition)
    camera:setRotation(sm.quat.fromEuler(sm.vec3.new(90, cameraRotation + 90, 0)))

    local uptime = getUptime()
    if sphere:exists() and uptime > 160 then
        local mass = sphere:getMass()
        sphere:applyImpulse(sm.vec3.new(math.cos(math.rad(uptime * 16)) * mass, math.sin(math.rad(uptime * 16)) * mass, 0), true)
        sphere:setColor(sm.color.new(1, 0, 1))
    end

    engine:tick()
    camera.api.drawAdvanced(display, renderSettings)
    display.flush()
end

function onStop()
    display.clear()
    display.flush()
end

_enableCallbacks = true