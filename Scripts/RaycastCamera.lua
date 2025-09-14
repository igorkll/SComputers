dofile '$CONTENT_DATA/Scripts/Config.lua'

RaycastCamera = class(nil)

RaycastCamera.maxParentCount = 0
RaycastCamera.maxChildCount = 1
RaycastCamera.connectionOutput = sm.interactable.connectionType.composite + sm.interactable.connectionType.networkCamera
RaycastCamera.colorNormal = sm.color.new(0x139d9eff)
RaycastCamera.colorHighlight = sm.color.new(0x1adbddff)
RaycastCamera.componentType = "camera"
RaycastCamera.poseWeightCount = 1

local rc_raycast = sm.physics.raycast
local rc_multicast = sm.physics.multicast
local rc_insert = table.insert
local rc_remove = table.remove
local rc_vec3_new = sm.vec3.new
local rc_floor = math.floor
local rc_color_new = sm.color.new
local sm_exists = sm.exists

local constrain = constrain
local floor = math.floor
local abs = math.abs
local min = math.min
local max = math.max
local shadowVec = sm.vec3.new(0, 0, 0.8)
local mathDist = mathDist

local vec3_new = rc_vec3_new
local floor = rc_floor
local insert = rc_insert

local formatColor = sc.formatColor
local formatColorStr = sc.formatColorStr
local formatColorToSmallNumber = canvasAPI.formatColorToSmallNumber
local tostring = tostring
local mapClip = mapClip
local map = map
local dot = sm.vec3.dot
local multiColorCombine = multiColorCombine
local colorCombine = colorCombine
local colorCombineToNumber = colorCombineToNumber
local colorCombineToString = colorCombineToString
local colorCombineAdd = colorCombineAdd

local zero = sm.vec3.zero()
local normalize = sm.vec3.normalize
local function cNormalize(vec)
    if vec ~= zero then
        return normalize(vec)
    end
    return vec
end

local rad_0 = math.rad(0)
local rad_1 = math.rad(1)
local rad_45 = math.rad(45)
local rad_60 = math.rad(60)
local rad_90 = math.rad(90)
local rad_82_5 = math.rad(82.5)
local rad_165 = math.rad(165)

local defaultRayColor = rc_color_new("#80A520")
local liftColor = rc_color_new("#ebb700")
local assetColor = rc_color_new("#808080")
local sunColor = rc_color_new("#EEF4DE")

local waterColor = rc_color_new("41ADC5")
local chemicalColor = rc_color_new("FF659A")
local oilColor = rc_color_new("0B2028")

local sunColorSmallNumber = formatColorToSmallNumber(sunColor)

local skyStates = {
    {color = rc_color_new("#000008")},
    {color = rc_color_new("#182c43")},
    {color = rc_color_new("#6099bb")},
    {color = rc_color_new("#6ab4c8"), dir = sm.vec3.new(-0.227422, -0.674264, 0.7026)},
    {color = rc_color_new("#73c4cc"), dir = sm.vec3.new(-0.227422, -0.674264, 0.7026)},
    {color = rc_color_new("#7bc9cb"), dir = sm.vec3.new(-0.227422, -0.674264, 0.7026)}, --day
    {color = rc_color_new("#93b394"), dir = sm.vec3.new(-0.227422, -0.674264, 0.7026)},
    {color = rc_color_new("#c48933"), dir = sm.vec3.new(-0.227422, -0.674264, 0.7026)},
    {color = rc_color_new("#c88322")},
    {color = rc_color_new("#643037")},
    {color = rc_color_new("#31073d")},
    {color = rc_color_new("#000008")},
}

local materialColors = {
    Rock = rc_color_new("#808080"),
    Sand = rc_color_new("#FFBA5F"),
    Dirt = rc_color_new("#7E6135")
}

local assetMaterialColors = {
    Sand = rc_color_new("#883c00"),
    Dirt = rc_color_new("#883c00"),
    Grass = rc_color_new("#883c00"),
    Rock = rc_color_new("#656565")
}

local defaultCameraSettings = {
    lampLighting = true,
    shadows = true,
    smoothingTerrain = true,
    simpleShadows = true,
    sun = true,
    fog = true,
    reduceAccuracy = true,

    shadowMultiplier = 0.6,
    sunPercentage = 1 - (0.003 * 2),
    simpleShadowMin = 0.3,
    simpleShadowMax = 1
}

local fastCameraSettings = {
    lampLighting = false,
    shadows = false,
    smoothingTerrain = false
}

for k, v in pairs(defaultCameraSettings) do
    if fastCameraSettings[k] == nil then
        fastCameraSettings[k] = v
    end
end

local lamps = {
    ["27c00cfb-4e7f-45fc-a037-f9a941464ce6"] = {dist = 3},
    ["e91b0bf2-dafa-439e-a503-286e91461bb0"] = {dist = 3},
    ["1e2485d7-f600-406e-b348-9f0b7c1f5077"] = {dist = 3},
    ["7b2c96af-a4a1-420e-9370-ea5b58f23a7e"] = {dist = 3},
    ["5e3dff9b-2450-44ae-ad46-d2f6b5148cbf"] = {dist = 3},
    ["16ba2d22-7b96-4c5e-9eb7-f6422ed80ad4"] = {dist = 3},
    ["85339a1d-e67f-4c63-94fd-4a1cf8c25810"] = {dist = 3},
    ["abaef792-741e-4c6b-8e79-02461a37b035"] = {dist = 3},
    ["cc454365-7262-4953-a190-4bead4f4a260"] = {dist = 3},
    ["ba79e3c0-914f-46ff-874b-243df5589e3c"] = {dist = 3},
    ["da6e54df-a223-4a0e-b42f-ddeddd33f5b3"] = {dist = 3},
    ["ebefa387-fe4a-4839-bdd9-b6b4da39368f"] = {dist = 3},
    ["47062936-5d28-43ec-81b5-8fdb619e97e4"] = {dist = 3},
    ["ed27f5e2-cac5-4a32-a5d9-49f116acc6af"] = {dist = 3},
    ["695d66c8-b937-472d-8bc2-f3d72dd92879"] = {dist = 3}
}

local glassBlocks = {
    ["5f41af56-df4c-4837-9b3c-10781335757f"] = 0.15,
    ["749f69e0-56c9-488c-adf6-66c58531818f"] = 0.2,
    ["f406bf6e-9fd5-4aa0-97c1-0b3c2118198e"] = 0.3,
    ["b5ee5539-75a2-4fef-873b-ef7c9398b3f5"] = 0.4
}

--[[
local function drawAdvanced(posx, posy, raydata, skyColor, width, time, lampsData, skyState)
    local localSky = skyColor
    if skyState.dir and dot(skyState.dir, (raydata.rawray.directionWorld):normalize()) > 0.993 then
        localSky = sunColor
    end
    if not raydata.type or raydata.type == "limiter" then
        return localSky
    end
    
    local shadowMul = 1
    local sunShadowMul = 1
    local globalSunMul = max(1 - (abs(time - 0.5) * 2), 0.3)
    if raydata.normalWorld then
        shadowMul = max((shadowVec:dot(raydata.normalWorld) + 1) / 2, 0.2)
    end
    if raydata.overlapSunbeam then
        sunShadowMul = 0.6
    end
    local color = (raydata.color or defaultRayColor) * shadowMul * sunShadowMul
    local lampsColorAdded = false
    if lampsData then
        local lamp, dist
        for i = 1, #lampsData do
            lamp = lampsData[i]
            dist = mathDist(raydata.rawray.pointWorld, lamp[1].worldPosition)
            if dist <= lamp[2].dist * extendedLampLight then
                --color = colorCombine(constrain((dist / lamp[2].dist) * ((i2 * 0.35) + 1), 0.6, 1), lamp[1].color, color)
                color = color * lamp[1].color * constrain(map(dist / lamp[2].dist, 0, 1, 4, 1), globalSunMul, 4)
                lampsColorAdded = true
            end
        end
    end
    if not lampsColorAdded then
        color = color * globalSunMul
    end
    return colorCombine(
        raydata.fraction,
        color,
        localSky
    )
end
]]

local function downscaleResolution(resolutionX, resolutionY, step, downscale)
    resolutionX = floor(resolutionX / downscale)
    resolutionY = floor(resolutionY / downscale)
    if resolutionX < 1 then resolutionX = 1 end
    if resolutionY < 1 then resolutionY = 1 end
    local maxStep = resolutionX * resolutionY
    if step > maxStep then step = maxStep end
    return resolutionX, resolutionY, step
end

local function preprocessAdvancedSettings(self, advancedSettings)
    if advancedSettings ~= defaultCameraSettings and advancedSettings ~= fastCameraSettings then
        advancedSettings.constColor = advancedSettings.constColor and formatColor(advancedSettings.constColor)

        advancedSettings.skyColorColor = advancedSettings.constSkyColor and formatColor(advancedSettings.constSkyColor)
        advancedSettings.constTerrainColor = advancedSettings.constTerrainColor and formatColor(advancedSettings.constTerrainColor)
        advancedSettings.constHarvestableColor = advancedSettings.constHarvestableColor and formatColor(advancedSettings.constHarvestableColor)
        advancedSettings.constAssetsColor = advancedSettings.constAssetsColor and formatColor(advancedSettings.constAssetsColor)

        advancedSettings.constShapeColor = advancedSettings.constShapeColor and formatColor(advancedSettings.constShapeColor)
        advancedSettings.customLiftColor = advancedSettings.customLiftColor and formatColor(advancedSettings.customLiftColor)
        advancedSettings.constCharacterColor = advancedSettings.constCharacterColor and formatColor(advancedSettings.constCharacterColor)
        advancedSettings.constJointColor = advancedSettings.constJointColor and formatColor(advancedSettings.constJointColor)

        advancedSettings.customWaterColor = advancedSettings.customWaterColor and formatColor(advancedSettings.customWaterColor)
        advancedSettings.customChemicalColor = advancedSettings.customChemicalColor and formatColor(advancedSettings.customChemicalColor)
        advancedSettings.customOilColor = advancedSettings.customOilColor and formatColor(advancedSettings.customOilColor)

        advancedSettings.customTerrainColor_dirt = advancedSettings.customTerrainColor_dirt and formatColor(advancedSettings.customTerrainColor_dirt)
        advancedSettings.customTerrainColor_grass = advancedSettings.customTerrainColor_grass and formatColor(advancedSettings.customTerrainColor_grass)
        advancedSettings.customTerrainColor_sand = advancedSettings.customTerrainColor_sand and formatColor(advancedSettings.customTerrainColor_sand)
        advancedSettings.customTerrainColor_stone = advancedSettings.customTerrainColor_stone and formatColor(advancedSettings.customTerrainColor_stone)

        if advancedSettings.customTerrainColor_dirt or advancedSettings.customTerrainColor_grass or advancedSettings.customTerrainColor_sand or advancedSettings.customTerrainColor_stone then
            if advancedSettings.customTerrainColor_dirt ~= self._old_dirt or
            advancedSettings.customTerrainColor_grass ~= self._old_grass or
            advancedSettings.customTerrainColor_sand ~= self._old_sand or
            advancedSettings.customTerrainColor_stone ~= self._old_stone then
                self.customTerrainColors = {
                    Rock = advancedSettings.customTerrainColor_stone or materialColors.Rock,
                    Sand = advancedSettings.customTerrainColor_sand or materialColors.Sand,
                    Dirt = advancedSettings.customTerrainColor_dirt or materialColors.Dirt
                }
                self.customDefaultColor = advancedSettings.customTerrainColor_grass
                self.customSmoothedCache = {}
                self._old_dirt = advancedSettings.customTerrainColor_dirt
                self._old_grass = advancedSettings.customTerrainColor_grass
                self._old_sand = advancedSettings.customTerrainColor_sand
                self._old_stone = advancedSettings.customTerrainColor_stone
            end
        else
            self.customTerrainColors = nil
            self.customDefaultColor = nil
            self.customSmoothedCache = nil
            self._old_dirt = nil
            self._old_grass = nil
            self._old_sand = nil
            self._old_stone = nil
        end
    end
end

local function getVecHash(vec, mul)
    mul = mul or 1
    return floor(vec.x * mul) + (floor(vec.y * mul) * 3000) + (floor(vec.z * mul) * 3000 * 3000)
    --return "" .. floor(vec.x * mul) .. "" .. floor(vec.y * mul) .. "" .. floor(vec.z * mul) 
end

local function fDrawPixel(drawPixel, fillRect, width, height, downscale, offsetX, offsetY, x, y, color)
    local changed = false
    if downscale > 1 then
        x = offsetX + x * downscale
        y = offsetY + y * downscale
        if fillRect then
            --[[
            local sizeX, sizeY = downscale, downscale
            local maxSizeX, maxSizeY = width - x, height - y
            if sizeX > maxSizeX then sizeX = maxSizeX end
            if sizeY > maxSizeY then sizeY = maxSizeY end
            fillRect(x, y, sizeX, sizeY, color)
            ]]
            fillRect(x, y, downscale, downscale, color)
            changed = true
        else
            if downscale > 256 then downscale = 256 end
            local downscaleM = downscale - 1
            for ix = 0, downscaleM do
                for iy = 0, downscaleM do
                    local px, py = x + ix, y + iy
                    if px < width and py < height and drawPixel(px, py, color) then
                        changed = true
                    end
                end
            end
        end
    else
        changed = drawPixel(offsetX + x, offsetY + y, color)
    end
    return changed
end

local function ffDrawPixel(drawPixel, fillRect, width, height, downscale, offsetX, offsetY, x, y, color)
    return fDrawPixel(drawPixel, fillRect, width, height, downscale, offsetX, offsetY, x, y, formatColorToSmallNumber(color))
end

local function cDrawPixel(display, downscale, offsetX, offsetY, x, y, color)
    fDrawPixel(display.drawPixel, display.fillRect, display.getWidth(), display.getHeight(), downscale, offsetX, offsetY, x, y, color)
end

local physics_getGroundMaterial = sm.physics.getGroundMaterial

local groundCache = {}
local assetsCache = {}

local function cached_getGroundMaterial(point, cache, gridSize)
    local vechash = getVecHash(point, gridSize)
    cache = cache or groundCache
    if cache[vechash] then
        return cache[vechash]
    end
    local color = physics_getGroundMaterial(point)
    cache[vechash] = color
    return color
end

local function cached_getGroundColor(point, colors, cache, gridSize)
    local material = cached_getGroundMaterial(point, cache, gridSize)
    if not material then
        return
    end
    colors = colors or materialColors
    return colors[material]
end

local groundSmoothedPointCache = {}
local groundSmoothedCache = {}
local function cached_smoothed_getGroundColor(point, defaultColor, colors, smoothedPointCache, smoothedCache)
    local vechash = getVecHash(point, 4)
    smoothedCache = smoothedCache or groundSmoothedCache
    if smoothedCache[vechash] then
        return smoothedCache[vechash]
    end

    smoothedPointCache = smoothedPointCache or groundSmoothedPointCache

    local r, g, b = 0, 0, 0
    local sum = 0
    local lcol
    local dx = point.x
    local dy = point.y
    for ix = -0.75, 0.75, 0.25 do
        point.x = dx + ix
        for iy = -0.75, 0.75, 0.25 do
            point.y = dy + iy
            lcol = cached_getGroundColor(point, colors, smoothedPointCache, 4) or defaultColor
            if lcol then
                r = r + lcol.r
                g = g + lcol.g
                b = b + lcol.b
                sum = sum + 1
            end
        end
    end
    point.x = dx
    point.y = dy

    if sum == 0 then
        return
    end

    local color = rc_color_new(r / sum, g / sum, b / sum)
    smoothedCache[vechash] = color
    return color
end



local areaPosCache = {}
local function getRayColor(self, rawray, advancedSettings)
    local rtype = rawray.type

    --[[
    local shape = rawray:getShape()
    if shape then
        return shape.color
    else
        local character = rawray:getCharacter()
        if character then
            return character.color
        else
            local harvestable = rawray:getHarvestable()
            if harvestable then
                return harvestable:getColor()
            else
                local joint = rawray:getJoint()
                if joint then
                    return joint.color
                elseif rtype == "lift" then
                    return liftColor
                elseif rtype == "terrainAsset" then
                    return customFastGetGroundColor(rawray, assetMaterialColors, assetColor)
                elseif rtype == "areaTrigger" then
                    local triggerData = rawray:getAreaTrigger():getUserData()
                    if triggerData then
                        if triggerData.water then
                            return waterColor
                        elseif triggerData.chemical then
                            return chemicalColor
                        elseif triggerData.oil then
                            return oilColor
                        end
                    end
                elseif fastmode then
                    return customFastGetGroundColor(rawray)
                else
                    return customGetGroundColor(rawray)
                end
            end
        end
    end
    ]]

    local color = advancedSettings.constColor
    if color then
        return color
    end

    if rtype == "terrainAsset" then
        if advancedSettings.smoothingTerrain then
            color = advancedSettings.constAssetsColor or cached_smoothed_getGroundColor(rawray.pointWorld, defaultRayColor, assetMaterialColors, assetsCache) or assetColor
        else
            color = advancedSettings.constAssetsColor or cached_getGroundColor(rawray.pointWorld, assetMaterialColors, assetsCache) or assetColor
        end
        --color = assetMaterialColors[getGroundMaterial(rawray.pointWorld)] or assetColor
    elseif rtype == "body" then
        color = advancedSettings.constShapeColor or rawray:getShape().color
    elseif rtype == "character" then
        color = advancedSettings.constCharacterColor or rawray:getCharacter().color
    elseif rtype == "harvestable" then
        color = advancedSettings.constHarvestableColor or rawray:getHarvestable():getColor()
    elseif rtype == "lift" then
        color = advancedSettings.customLiftColor or liftColor
    elseif rtype == "joint" then
        color = advancedSettings.constJointColor or rawray:getJoint().color
    else
        if rtype == "areaTrigger" then
            local vechash = getVecHash(rawray.pointWorld)
            if areaPosCache[vechash] then
                color = areaPosCache[vechash]
            end

            if not color then
                areaPosCache[vechash] = true
                local areaTrigger = rawray:getAreaTrigger()
                if sm_exists(areaTrigger) then
                    local triggerData = areaTrigger:getUserData()
                    if triggerData then
                        if triggerData.water then
                            color = 1
                        elseif triggerData.chemical then
                            color = 2
                        elseif triggerData.oil then
                            color = 3
                        end
                    end

                    areaPosCache[vechash] = color
                end
            end

            if color == true then
                color = nil
            elseif color == 1 then
                color = advancedSettings.customWaterColor or waterColor
            elseif color == 2 then
                color = advancedSettings.customChemicalColor or chemicalColor
            elseif color == 3 then
                color = advancedSettings.customOilColor or oilColor
            end
        end
        
        color = color or advancedSettings.constTerrainColor
        if not color then
            if advancedSettings.smoothingTerrain then
                color = cached_smoothed_getGroundColor(rawray.pointWorld, self.customDefaultColor or defaultRayColor, self.customTerrainColors, nil, self.customSmoothedCache)
            else
                color = cached_getGroundColor(rawray.pointWorld, self.customTerrainColors)
            end
        end
    end

    if not color then
        color = self.customDefaultColor or defaultRayColor
    end

    return color
end

local function getGlobalSunMul(self, advancedSettings)
    return max(1 - (abs((advancedSettings.constDayLightValue or self.time or 0) - 0.5) * 2), 0.3)
end

local function drawAdvanced(self, x, y, res, skyState, lampsData, sunres, advancedSettings, globalSunMul, distance)
    local collision, rawray = res[1], res[2]

    if not collision or rawray.type == "limiter" then
        if advancedSettings.sun and skyState.dir and dot(skyState.dir, cNormalize(rawray.directionWorld)) > advancedSettings.sunPercentage then
            return advancedSettings.customSunColor or sunColorSmallNumber
        else
            return advancedSettings.constSkyColor or skyState.colorNumber
        end
    end
    
    -- FUCKING LAGS
    local color = getRayColor(self, rawray, advancedSettings)

    -- FUCKING LAGS
    if rawray.type ~= "character" then
        local shadowMul = 0.95
        if advancedSettings.simpleShadows then
            shadowMul = map(dot(skyState.dir or shadowVec, rawray.normalWorld), -1, 1, advancedSettings.simpleShadowMin, advancedSettings.simpleShadowMax)
            if advancedSettings.reduceAccuracy then
                shadowMul = floor(shadowMul * 16) / 16
            end
        end
        if sunres and sunres[1] then
            if sunres[2].type ~= "limiter" then
                --[[
                if sunresType == "body" then
                    local shape = sunres[2]:getShape()
                    local glassMul = glassBlocks[tostring(shape.uuid)]
                    if glassMul then
                        colorCombineAdd(color, glassMul, shape.color)
                    else
                        color.r = color.r * 0.6
                        color.g = color.g * 0.6
                        color.b = color.b * 0.6
                    end
                else
                ]]
                shadowMul = shadowMul * advancedSettings.shadowMultiplier
                --end
            end
        end
        local minLampDist = 1
        if lampsData then
            for i = 1, #lampsData do
                local lamp = lampsData[i]
                local dist = mathDist(rawray.pointWorld, lamp[1].worldPosition)
                if dist <= lamp[2].dist then
                    local lampDist = dist / lamp[2].dist
                    color = colorCombine(lampDist, lamp[1].color, color)
                    if lampDist < minLampDist then
                        minLampDist = lampDist
                    end
                end
            end
        end
        shadowMul = shadowMul * (((globalSunMul - 1) * minLampDist) + 1)
        color = color * shadowMul
    else
        color = color * globalSunMul
    end

    -- FUCKING LAGS
    if not advancedSettings.fog or rawray.fraction <= 0.025 then
        return formatColorToSmallNumber(color)
    end
    if advancedSettings.reduceAccuracy then
        return colorCombineToNumber(floor(rawray.fraction * 16) / 16, color, advancedSettings.skyColorColor or skyState.color)
    else
        return colorCombineToNumber(rawray.fraction, color, advancedSettings.skyColorColor or skyState.color)
    end
end

local clientCameras = {}

local dcwf_def_noCollideColor = "000000"
local dcwf_def_terrainColor = "666666"
local dcwf_def_unitsColor = "ffffff"

local dc_def_noCollideColor = "45c2de"
local dc_def_terrainColor = "666666"
local dc_def_unitsColor = "ffffff"

local dd_def_baseColor = "666666"
local dd_def_noCollideColor = "000000"
local dd_def_unitsColor = "ffffff"

local redMul = 256 * 256 * 256
local greenMul = 256 * 256
local blueMul = 256

local function ifCheckNeedActivate(offsetX, offsetY, width, height, rx, ry)
    return offsetX < 0 or offsetY < 0 or offsetX + width > rx or offsetY + height > ry
end

local rawPushID = 6723
canvasAPI.dataSizes[rawPushID] = 17
canvasAPI.userCalls[rawPushID] = function(newBuffer, rotation, _, _, rx, ry, stack, offset, _, bufferRangeUpdate, setDot, checkSetDot, rasterize_fill)
    local nextPixel = stack[offset]
    local offsetX, offsetY, width, height = stack[offset+1], stack[offset+2], stack[offset+3], stack[offset+4]
    if ifCheckNeedActivate(offsetX, offsetY, width, height, rx, ry) then
        setDot = checkSetDot
    end
    local step = stack[offset+5]
    local distance = stack[offset+6]
    local fovX = stack[offset+7]
    local fovY = stack[offset+8]
    local downscale = stack[offset+9]
    local actionNum = stack[offset+11]
    local interactableId = stack[offset+12]
    local col1 = stack[offset+13]
    local col2 = stack[offset+14]
    local col3 = stack[offset+15]

    local fwidth, fheight = width, height
    width, height, step = downscaleResolution(width, height, step, downscale)
    local stepM = step - 1

    local clientSelf = clientCameras[interactableId]
    local results = clientSelf:rays(width, height, nextPixel, stepM, distance, fovX, fovY, downscale)
    local tCol = 0
    local res, pixel
    local x, y
    local data, shape, character
    local idx, changed = 0, false

    --[[
    local function fillRect(x, y, sizeX, sizeY, color)
        insert(stack, 2)
        insert(stack, x)
        insert(stack, y)
        insert(stack, sizeX)
        insert(stack, sizeY)
        insert(stack, color)
    end
    ]]

    if actionNum == 0 then
        for i = 0, stepM do
            res = results[i+1]
            pixel = nextPixel + i
            x = floor(pixel / height) % width
            y = pixel % height

            if res and res[1] then
                data = res[2]
                shape = data:getShape()
                character = data:getCharacter()
                if character then
                    if ffDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col3 * (1 - data.fraction)) then
                        changed = true
                    end
                elseif shape then
                    if ffDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, shape.color * (1 - data.fraction)) then
                        changed = true
                    end
                elseif data.type ~= "limiter" then
                    if ffDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col2 * (1 - data.fraction)) then
                        changed = true
                    end
                elseif fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col1) then
                    changed = true
                end
            elseif fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col1) then
                changed = true
            end
        end
    elseif actionNum == 1 then
        for i = 0, stepM do
            res = results[i+1]
            pixel = nextPixel + i
            x = floor(pixel / height) % width
            y = pixel % height

            if res and res[1] then
                data = res[2]
                shape = data:getShape()
                character = data:getCharacter()

                if character then
                    if fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col3) then
                        changed = true
                    end
                elseif shape then
                    if ffDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, shape.color) then
                        changed = true
                    end
                elseif data.type ~= "limiter" then
                    if fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col2) then
                        changed = true
                    end
                elseif fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col1) then
                    changed = true
                end
            elseif fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col1) then
                changed = true
            end
        end
    elseif actionNum == 2 then
        for i = 0, stepM do
            res = results[i+1]
            pixel = nextPixel + i
            x = floor(pixel / height) % width
            y = pixel % height

            if res and res[1] then
                data = res[2]
                character = data:getCharacter()
                if character then
                    if ffDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col3 * (1 - data.fraction)) then
                        changed = true
                    end
                elseif data.type ~= "limiter" then
                    if ffDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col1 * (1 - data.fraction)) then
                        changed = true
                    end
                elseif fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col2) then
                    changed = true
                end
            elseif fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, col2) then
                changed = true
            end
        end
    end

    --clientSelf:cl_saveLastInfo(results, nextPixel)
    return changed
end

local rawPushID2 = 6724
canvasAPI.dataSizes[rawPushID2] = 14
canvasAPI.userCalls[rawPushID2] = function(newBuffer, rotation, _, _, rx, ry, stack, offset, _, bufferRangeUpdate, setDot, checkSetDot, rasterize_fill)
    local nextPixel = stack[offset]
    local offsetX, offsetY, width, height = stack[offset+1], stack[offset+2], stack[offset+3], stack[offset+4]
    if ifCheckNeedActivate(offsetX, offsetY, width, height, rx, ry) then
        setDot = checkSetDot
    end
    local step = stack[offset+5]
    local distance = stack[offset+6]
    local fovX = stack[offset+7]
    local fovY = stack[offset+8]
    local downscale = stack[offset+9]

    local fwidth, fheight = width, height
    width, height, step = downscaleResolution(width, height, step, downscale)
    local stepM = step - 1

    local interactableId = stack[offset+11]
    local rawAdvancedSettings = stack[offset+12]
    
    local clientSelf = clientCameras[interactableId]
    local advancedSettings
    if type(rawAdvancedSettings) == "string" then
        advancedSettings = sm.json.parseJsonString(rawAdvancedSettings)
        preprocessAdvancedSettings(clientSelf, advancedSettings)
    elseif rawAdvancedSettings then
        advancedSettings = fastCameraSettings
    else
        advancedSettings = defaultCameraSettings
    end
    local results = clientSelf:rays(width, height, nextPixel, stepM, distance, fovX, fovY, downscale)
    local sunRays, lampsData
    if advancedSettings.shadows then
        sunRays = clientSelf:sunRays(width, height, nextPixel, distance, results, advancedSettings)
    end
    if advancedSettings.lampLighting then
        lampsData = clientSelf:getLampsData(distance)
    end
    local skyState = clientSelf:getSkyState(advancedSettings)
    local res, sunres, pixel
    local x, y
    local idx, changed = 0, false
    local raydata
    local globalSunMul = getGlobalSunMul(clientSelf, advancedSettings)

    --[[
    local function fillRect(x, y, sizeX, sizeY, color)
        insert(stack, 2)
        insert(stack, x)
        insert(stack, y)
        insert(stack, sizeX)
        insert(stack, sizeY)
        insert(stack, formatColorToSmallNumber(color))
    end
    ]]

    for i = 0, stepM do
        res = results[i+1]
        sunres = sunRays and sunRays[i+1]
        pixel = nextPixel + i
        x = floor(pixel / height) % width
        y = pixel % height

        if fDrawPixel(setDot, rasterize_fill, fwidth, fheight, downscale, offsetX, offsetY, x, y, drawAdvanced(clientSelf, x, y, res, skyState, lampsData, sunres, advancedSettings, globalSunMul, distance)) then
            changed = true
        end
    end

    --clientSelf:cl_saveLastInfo(results, nextPixel)
    return changed
end

--[[
local clientHostcall = {}
local hostcallId = 0

local rawPushID3 = 6725
canvasAPI.dataSizes[rawPushID3] = 2
canvasAPI.userCalls[rawPushID3] = function(newBuffer, rotation, rSizeX, rSizeY, rx, ry, stack, offset, _, bufferRangeUpdate, setDot, checkSetDot)
    local id = stack[offset]
    if id then
        clientHostcall[id](stack, offset, rSizeX, rSizeY)
        clientHostcall[id] = nil
    end
end

local function pushClientHostcall(self, display, backend, func)
    if not backend.internalApi then return end

    if not display or display.getAudience() > 0 then
        clientHostcall[hostcallId] = func
        backend.internalApi.rawPush({rawPushID3, hostcallId})
        hostcallId = hostcallId + 1
    end

    self.iterator = self.iterator + 1
end
]]

local function getViewportWH(self, width, height)
    if self.viewport_x then
        return self.viewport_x, self.viewport_y, self.viewport_sizeX, self.viewport_sizeY
    else
        return 0, 0, width, height
    end
end

local function getViewport(self, display)
    return getViewportWH(self, display.getWidth(), display.getHeight())
end

local function checkNextPixel(self, resolutionX, resolutionY)
    if self.nextPixel ~= self.nextPixel then self.nextPixel = 0 end --is nan check
    self.nextPixel = self.nextPixel % (resolutionX * resolutionY)
end

local function pushClientRender(self, display, localRawPush, backend, ...)
    if not backend.internalApi then return end

    local width = backend.api.getWidth()
    local height = backend.api.getHeight()
    local step
    width, height, step = downscaleResolution(width, height, self.step, self.downscale)
    checkNextPixel(self, width, height)

    local x, y, sizeX, sizeY = getViewport(self, display)
    backend.internalApi.rawPush({
        localRawPush,
        self.nextPixel,
        x, y, sizeX, sizeY,
        step,
        self.distance,
        self.fovX,
        self.fovY,
        self.downscale,
        self.iterator,
        ...
    })

    self.nextPixel = (self.nextPixel + step) % (width * height)
    self.iterator = self.iterator + 1
end

local function needOnClient()
    return true
    --return #sm.player.getAllPlayers() > 1
end

local function getCurrentRotation(self)
    local currentRotation = self.netdata and self.netdata.currentRotation or 0
    if self.netdata and self.netdata.rotateSync then
        currentRotation = currentRotation + toEuler(self.shape.worldRotation).z
    end
    currentRotation = -currentRotation
    return currentRotation
end

local function unrestrictedOnly(self)
    if not self.unrestricted then
        error("this method is intended only for unrestricted camera from the power toys addon", 3)
    end
end

function RaycastCamera:createData(forceMinimap) --forceMinimap is used from CameraTunnel.lua to get an up-to-date list of minimap methods
    self.iterator = 0
    self.downscale = 1
    local api
    local _detectable
    api = {
        fork = function(cloneSettings)
            local newapi = sc.copy(api)
            local nextPixel = 0
            local viewport_x, viewport_y, viewport_sizeX, viewport_sizeY
            local fovX, fovY = rad_60, rad_60
            local downscale = 1
            local distance = 1024
            local step = 256
            local detectable

            local function hookDrawerFunction(name)
                newapi[name] = function(...)
                    local old_viewport_x, old_viewport_y, old_viewport_sizeX, old_viewport_sizeY = api.getViewport()
                    local old_fovX, old_fovY = api.getFovX(), api.getFovY()
                    local old_nextPixel = api.getNextPixel()
                    local old_downscale = api.getDownScale()
                    local old_distance = api.getDistance()
                    local old_step = api.getStep()
                    local old_detectable = api.getDetectableObjects()
                    
                    api.setViewport(viewport_x, viewport_y, viewport_sizeX, viewport_sizeY)
                    api.setNextPixel(nextPixel)

                    if cloneSettings then
                        api.setNonSquareFov(fovX, fovY)
                        api.setDownScale(downscale)
                        api.setDistance(distance)
                        api.setStep(step)
                        api.setDetectableObjects(detectable)
                    end

                    api[name](...)
                    nextPixel = api.getNextPixel()
                    
                    api.setViewport(old_viewport_x, old_viewport_y, old_viewport_sizeX, old_viewport_sizeY)
                    api.setNonSquareFov(old_fovX, old_fovY)
                    api.setNextPixel(old_nextPixel)
                    api.setDownScale(old_downscale)
                    api.setDistance(old_distance)
                    api.setStep(old_step)
                    api.setDetectableObjects(old_detectable)
                end
            end

            hookDrawerFunction("drawColorWithDepth")
            hookDrawerFunction("drawColor")
            hookDrawerFunction("drawDepth")
            hookDrawerFunction("drawCustom")
            hookDrawerFunction("drawAdvanced")
            hookDrawerFunction("drawOverlay")

            function newapi.setViewport(x, y, sizeX, sizeY)
                if x then
                    checkArg(1, x, "number")
                    checkArg(2, y, "number")
                    checkArg(3, sizeX, "number")
                    checkArg(4, sizeY, "number")
                    nextPixel = nextPixel % (sizeX * sizeY)
                    viewport_x = floor(x)
                    viewport_y = floor(y)
                    viewport_sizeX = floor(sizeX)
                    viewport_sizeY = floor(sizeY)
                else
                    checkArg(1, x, "nil")
                    checkArg(2, y, "nil")
                    checkArg(3, sizeX, "nil")
                    checkArg(4, sizeY, "nil")
                    viewport_x = nil
                    viewport_y = nil
                    viewport_sizeX = nil
                    viewport_sizeY = nil
                end
            end

            function newapi.getViewport()
                return viewport_x, viewport_y, viewport_sizeX, viewport_sizeY
            end

            function newapi.setNextPixel(_nextPixel)
                checkArg(1, _nextPixel, "number")
                nextPixel = _nextPixel
            end
            function newapi.getNextPixel() return nextPixel end
            function newapi.resetCounter() nextPixel = 0 end

            if cloneSettings then
                function newapi.setFov(fov)
                    checkArg(1, fov, "number")
                    newapi.setNonSquareFov(fov, fov)
                end
    
                function newapi.setNonSquareFov(fovX, fovY)
                    checkArg(1, fovX, "number")
                    checkArg(2, fovY, "number")
                    
                    if fovX < rad_1 then
                        fovX = rad_1
                    elseif fovX > rad_165 then
                        fovX = rad_165
                    end
    
                    if fovY < rad_1 then
                        fovY = rad_1
                    elseif fovY > rad_165 then
                        fovY = rad_165
                    end
                end
                
                function newapi.getFov() return math.max(fovX, fovY) end
                function newapi.getFovX() return fovX end
                function newapi.getFovY() return fovY end
                
                function newapi.setDownScale(_downscale)
                    _downscale = floor(_downscale)
                    if _downscale < 1 then _downscale = 1 end
                    if _downscale ~= downscale then
                        downscale = _downscale
                    end
                end

                function newapi.getDownScale()
                    return downscale
                end

                function newapi.setStep(_step)
                    if type(_step) == "number" and _step % 1 == 0 and _step > 0 and _step <= 4096 then
                        step = _step
                    else
                        error("integer must be in [1; 4096]")
                    end
                end
                function newapi.getStep() return step end

                function newapi.setDistance(_distance) 
                    if type(_distance) == "number" and _distance >= 0 then
                        if distance > 2048 then
                            distance = 2048
                        end
                        distance = _distance
                    else
                        error("number must be (0; 2048)")
                    end
                end
                function newapi.getDistance() return distance end

                function newapi.resetDetectableObjects()
                    newapi.setDetectableObjects({
                        liquids = true,
                        dynamicBody = true,
                        staticBody = true,
                        characters = true,
                        joints = true,
                        terrain = true,
                        assets = true,
                        harvestable = true
                    })
                end

                function newapi.setDetectableObjects(_detectable)
                    checkArg(1, _detectable, "table")
                    detectable = _detectable
                end

                function newapi.getDetectableObjects()
                    return detectable
                end

                newapi.resetDetectableObjects()
            end

            return newapi
        end,
        setViewport = function(x, y, sizeX, sizeY)
            if x then
                checkArg(1, x, "number")
                checkArg(2, y, "number")
                checkArg(3, sizeX, "number")
                checkArg(4, sizeY, "number")
                self.nextPixel = self.nextPixel % (sizeX * sizeY)
                self.viewport_x = floor(x)
                self.viewport_y = floor(y)
                self.viewport_sizeX = floor(sizeX)
                self.viewport_sizeY = floor(sizeY)
            else
                checkArg(1, x, "nil")
                checkArg(2, y, "nil")
                checkArg(3, sizeX, "nil")
                checkArg(4, sizeY, "nil")
                self.viewport_x = nil
                self.viewport_y = nil
                self.viewport_sizeX = nil
                self.viewport_sizeY = nil
            end
        end,
        getViewport = function()
            return self.viewport_x, self.viewport_y, self.viewport_sizeX, self.viewport_sizeY
        end,
        setDownScale = function(downscale)
            downscale = floor(downscale)
            if downscale < 1 then downscale = 1 end
            if downscale ~= self.downscale then
                self.downscale = downscale
            end
        end,
        getDownScale = function()
            return self.downscale
        end,
        drawColorWithDepth = function (display, noCollideColor, terrainColor, unitsColor)
            self.lightTick = sm.game.getCurrentTick()
            local backend = sc.componentsBackend[display]
            if self.interactable and backend and needOnClient() then
                pushClientRender(self, display, rawPushID, backend,
                    0,
                    self.interactable.id,
                    formatColorToSmallNumber(noCollideColor or dcwf_def_noCollideColor),
                    formatColor(terrainColor or dcwf_def_terrainColor),
                    formatColor(unitsColor or dcwf_def_unitsColor)
                )
            else
                self:sv_drawColorWithDepth(display, noCollideColor, terrainColor, unitsColor)
            end
        end,
        drawColor = function (display, noCollideColor, terrainColor, unitsColor)
            self.lightTick = sm.game.getCurrentTick()
            local backend = sc.componentsBackend[display]
            if self.interactable and backend and needOnClient() then
                pushClientRender(self, display, rawPushID, backend,
                    1,
                    self.interactable.id,
                    formatColorToSmallNumber(noCollideColor or dc_def_noCollideColor),
                    formatColorToSmallNumber(terrainColor or dc_def_terrainColor),
                    formatColorToSmallNumber(unitsColor or dc_def_unitsColor)
                )
            else
                self:sv_drawColor(display, noCollideColor, terrainColor, unitsColor)
            end
        end,
        drawDepth = function (display, baseColor, noCollideColor, unitsColor)
            self.lightTick = sm.game.getCurrentTick()
            local backend = sc.componentsBackend[display]
            if self.interactable and backend and needOnClient() then
                pushClientRender(self, display, rawPushID, backend,
                    2,
                    self.interactable.id,
                    formatColor(baseColor or dd_def_baseColor),
                    formatColorToSmallNumber(noCollideColor or dd_def_noCollideColor),
                    formatColor(unitsColor or dd_def_unitsColor)
                )
            else
                self:sv_drawDepth(display, baseColor, noCollideColor, unitsColor)
            end
        end,
        drawCustom = function (display, drawer, ...)
            self.lightTick = sm.game.getCurrentTick()
            self:sv_drawCustom(false, display, drawer, ...)
        end,
        deepDrawCustom = function(display, drawer, maxIntersections, ...)
            checkArg(3, maxIntersections, "number", "nil")
            unrestrictedOnly(self)
            self.lightTick = sm.game.getCurrentTick()
            self:sv_deepDrawCustom(false, display, drawer, maxIntersections or 1, ...)
        end,
        drawAdvanced = function (display, advancedSettings)
            self.lightTick = sm.game.getCurrentTick()
            local backend = sc.componentsBackend[display]
            local newAdvancedSettings
            if type(advancedSettings) == "table" then
                newAdvancedSettings = {}
                for k, v in pairs(defaultCameraSettings) do
                    newAdvancedSettings[k] = v
                end
                for k, v in pairs(advancedSettings) do
                    local ttype = type(v)
                    if ttype == "string" or ttype == "Color" then
                        newAdvancedSettings[k] = formatColorToSmallNumber(v)
                    else
                        newAdvancedSettings[k] = v
                    end
                end
                if advancedSettings.sunPercentage then
                    newAdvancedSettings.sunPercentage = 1 - (advancedSettings.sunPercentage * 2)
                end
            end
            if self.interactable and backend and needOnClient() then
                if newAdvancedSettings then
                    jsonEncodeInputCheck(newAdvancedSettings, 0)
                    pushClientRender(self, display, rawPushID2, backend,
                        self.interactable.id,
                        sm.json.writeJsonString(newAdvancedSettings)
                    )
                else
                    pushClientRender(self, display, rawPushID2, backend,
                        self.interactable.id,
                        not not advancedSettings
                    )
                end
            else
                if not newAdvancedSettings then
                    if advancedSettings then
                        newAdvancedSettings = fastCameraSettings
                    else
                        newAdvancedSettings = defaultCameraSettings
                    end
                end
                self:sv_drawAdvanced(display, newAdvancedSettings)
            end
        end,
        drawOverlay = function(display, mainDrawFunction, mainArgs, overlayDrawer, overlayArgs)
            --[[
            checkDisplayRes(display)
            self.lightTick = sm.game.getCurrentTick()
            mainDrawFunction(display, unpack(mainArgs))
            local backend = sc.componentsBackend[display]
            if self.interactable and backend and needOnClient() then
                pushClientHostcall(self, display, backend, function (stack, stackIndex, rSizeX, rSizeY)
                    self:sv_drawCustom(true, function(x, y, color)
                        rc_insert(stack, 16)
                        rc_insert(stack, x + (y * rSizeX))
                        rc_insert(stack, formatColorToSmallNumber(color))
                    end, display, overlayDrawer, unpack(overlayArgs))
                end)
            else
                self:sv_drawCustom(true, nil, display, overlayDrawer, unpack(overlayArgs))
            end
            ]]

            self.lightTick = sm.game.getCurrentTick()

            local serverSideRenderHook = {
                getWidth = function()
                    return display.getWidth()
                end,
                getHeight = function()
                    return display.getHeight()
                end,
                drawPixel = function(...)
                    return display.drawPixel(...)
                end
            }

            mainDrawFunction(serverSideRenderHook, unpack(mainArgs))
            self:sv_drawCustom(true, serverSideRenderHook, overlayDrawer, unpack(overlayArgs))
        end,
        rawRay = function (x, y, maxdist)
            self.lightTick = sm.game.getCurrentTick()
            return self:rawRay(x, y, maxdist)
        end,
        deepRawRay = function (x, y, maxdist, maxIntersections)
            checkArg(1, maxIntersections, "number", "nil")
            unrestrictedOnly(self)
            self.lightTick = sm.game.getCurrentTick()
            return self:rawRay(x, y, maxdist, maxIntersections or 1)
        end,
        getSkyColor = function (constDayLightValue)
            return self:getSkyColor({constDayLightValue = constDayLightValue})
        end,
        getDayLightValue = function()
            return self.time or 0
        end,
        getGlobalSunMul = function(constDayLightValue)
            return getGlobalSunMul(self, {constDayLightValue = constDayLightValue})
        end,
        
        setStep = function (step)
            if type(step) == "number" and step % 1 == 0 and step > 0 and step <= 4096 then
                self.step = step
            else
                error("integer must be in [1; 4096]")
            end
        end,
        getStep = function () return self.step end,
        setDistance = function (dist) 
            if type(dist) == "number" and dist >= 0 then
                if self.distance > 2048 then
                    self.distance = 2048
                end
                self.distance = dist
            else
                error("number must be (0; 2048)")
            end
        end,
        getDistance = function () return self.distance end,
        setFov = function (fov)
            checkArg(1, fov, "number")
            api.setNonSquareFov(fov, fov)
        end,
        setNonSquareFov = function(fovX, fovY)
            checkArg(1, fovX, "number")
            checkArg(2, fovY, "number")
            if fovX < rad_1 then
                fovX = rad_1
            elseif fovX > rad_165 then
                fovX = rad_165
            end
            if fovY < rad_1 then
                fovY = rad_1
            elseif fovY > rad_165 then
                fovY = rad_165
            end

            self.fovX = fovX
            self.fovY = fovY

            if fovX ~= self.netdata.fovX or fovY ~= self.netdata.fovY then
                self.netdata.fovX = fovX
                self.netdata.fovY = fovY
                self.netdataSend = true
            end
        end,
        getFov = function () return math.max(self.fovX, self.fovY) end,
        getFovX = function () return self.fovX end,
        getFovY = function () return self.fovY end,
        setNextPixel = function (nextPixel)
            checkArg(1, nextPixel, "number")
            self.nextPixel = nextPixel
        end,
        getNextPixel = function () return self.nextPixel end,
        resetCounter = function () self.nextPixel = 0 end,

        resetDetectableObjects = function()
            api.setDetectableObjects({
                liquids = true,
                dynamicBody = true,
                staticBody = true,
                characters = true,
                joints = true,
                terrain = true,
                assets = true,
                harvestable = true
            })
        end,
        setDetectableObjects = function(detectable)
            checkArg(1, detectable, "table")
            _detectable = detectable
            self.netdata.ray_mask = 0
            if detectable.liquids then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.areaTrigger
            end
            if detectable.dynamicBody then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.dynamicBody
            end
            if detectable.staticBody then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.staticBody
            end
            if detectable.characters then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.character
            end
            if detectable.joints then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.joints
            end
            if detectable.terrain then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.terrainSurface
            end
            if detectable.assets then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.terrainAsset
            end
            if detectable.harvestable then
                self.netdata.ray_mask = self.netdata.ray_mask + sm.physics.filter.harvestable
            end
            if self.netdata.ray_mask ~= self._ray_mask then
                self.netdataSend = true
                self._ray_mask = self.netdata.ray_mask
            end
        end,
        getDetectableObjects = function()
            return _detectable
        end,

        setUseMaskForRawRay = function(state)
            checkArg(1, state, "boolean")
            self.netdata.useMaskForRawRay = state
            self.netdataSend = true
        end,
        getUseMaskForRawRay = function()
            return self.netdata.useMaskForRawRay
        end,
        setCustomWorldPosition = function(customWorldPosition)
            checkArg(1, customWorldPosition, "Vec3", "nil")
            unrestrictedOnly(self)
            self.netdata.customWorldPosition = customWorldPosition
            self.netdataSend = true
        end,
        setCustomWorldRotation = function(customWorldRotation)
            checkArg(1, customWorldRotation, "Quat", "nil")
            unrestrictedOnly(self)
            self.netdata.customWorldRotation = customWorldRotation
            self.netdataSend = true
        end,
        setCustomLocalPosition = function(customLocalPosition)
            checkArg(1, customLocalPosition, "Vec3", "nil")
            unrestrictedOnly(self)
            self.netdata.customLocalPosition = customLocalPosition
            self.netdataSend = true
        end,
        setCustomLocalAfterPosition = function(customLocalAfterPosition)
            checkArg(1, customLocalAfterPosition, "Vec3", "nil")
            unrestrictedOnly(self)
            self.netdata.customLocalAfterPosition = customLocalAfterPosition
            self.netdataSend = true
        end,
    }

    --[[
    local drawAdvanced = api.drawAdvanced
    function api.drawAdvanced(...)
        return freezeDetector("drawAdvanced", drawAdvanced, ...) 
    end
    ]]

    self.netdata = self.netdata or {}
    self.netdata.useMaskForRawRay = false
    self.netdata.currentRotation = 0
    self.netdata.fovX = rad_60
    self.netdata.fovY = rad_60
    self.netdataSend = true

    function api.setImageRotation(currentRotation)
        checkArg(1, currentRotation, "number")
        if self.netdata.currentRotation ~= currentRotation then
            self.netdata.currentRotation = currentRotation
            self.netdataSend = true
        end
    end

    function api.getImageRotation()
        return self.netdata.currentRotation
    end

    if (self.data and self.data.minimap) or forceMinimap then
        self.netdata.currentHeight = 100
        self.netdata.isometricRender = false
        self.netdata.rotateSync = true
        self.netdata.worldMode = true
        self.netdata.isometricSizeX = 1
        self.netdata.isometricSizeY = 1
        self.netdata.offsetX = 0
        self.netdata.offsetY = 0

        function api.setMinimapHeight(currentHeight)
            checkArg(1, currentHeight, "number")
            if self.netdata.currentHeight ~= currentHeight then
                self.netdata.currentHeight = currentHeight
                self.netdataSend = true
            end
        end

        function api.getMinimapHeight()
            return self.netdata.currentHeight
        end

        function api.setMinimapRotation(currentRotation, rotateSync)
            checkArg(1, currentRotation, "number")
            api.setImageRotation(currentRotation)
            rotateSync = not not rotateSync
            if self.netdata.rotateSync ~= rotateSync then
                self.netdata.rotateSync = rotateSync
                self.netdataSend = true
            end
        end

        function api.getMinimapRotation()
            return self.netdata.currentRotation, self.netdata.rotateSync
        end

        function api.setIsometricRender(isometricRender)
            checkArg(1, isometricRender, "boolean")
            if self.netdata.isometricRender ~= isometricRender then
                self.netdata.isometricRender = isometricRender
                self.netdataSend = true
            end
        end

        function api.isIsometricRender()
            return self.netdata.isometricRender
        end

        function api.setIsometricSize(isometricSizeX, isometricSizeY)
            checkArg(1, isometricSizeX, "number")
            checkArg(2, isometricSizeY, "number")
            if self.netdata.isometricSizeX ~= isometricSizeX or self.netdata.isometricSizeY ~= isometricSizeY then
                self.netdata.isometricSizeX = isometricSizeX
                self.netdata.isometricSizeY = isometricSizeY
                self.netdataSend = true
            end
        end

        function api.getIsometricSize()
            return self.netdata.isometricSizeX, self.netdata.isometricSizeY
        end

        function api.setMinimapOffset(offsetX, offsetY)
            checkArg(1, offsetX, "number")
            checkArg(2, offsetY, "number")
            if self.netdata.offsetX ~= offsetX or self.netdata.offsetY ~= offsetY then
                self.netdata.offsetX = offsetX
                self.netdata.offsetY = offsetY
                self.netdataSend = true
            end
        end

        function api.getMinimapOffset()
            return self.netdata.offsetX, self.netdata.offsetY
        end

        function api.getWaypoints(width, height)
            checkArg(1, width, "number")
            checkArg(2, height, "number")
            return self:sv_getWaypoints(width, height)
        end

        function api.drawWaypoints(display, drawer)
            self:sv_drawWaypoints(display, self:sv_getWaypoints(display.getWidth(), display.getHeight()), drawer)
        end

        function api.getRealRotation()
            return getCurrentRotation(self)
        end

        function api.setWorldMode(worldMode)
            checkArg(1, worldMode, "boolean")
            if self.netdata.worldMode ~= worldMode then
                self.netdata.worldMode = worldMode
                self.netdataSend = true
            end
        end

        function api.isWorldMode()
            return self.netdata.worldMode
        end
    end

    api.resetDetectableObjects()

    return api
end

local function rotateVector(x, y, angle)
    local x_new = x * math.cos(angle) - y * math.sin(angle)
    local y_new = x * math.sin(angle) + y * math.cos(angle)
    return x_new, y_new
end

local function calculateCaptureArea(fovRadians, height)
    local halfFOV = fovRadians / 2
    return height * math.tan(halfFOV)
end

function RaycastCamera:sv_getWaypoints(width, height)
    if not sc.minimap_waypoints then return {} end
    
    local offsetX, offsetY, resolutionX, resolutionY = getViewportWH(self, width, height)
    local waypoints = {}
    for id, shape in pairs(sc.minimap_waypoints) do
        local fovX, fovY
        if self.netdata.isometricRender then
            fovX = self.netdata.isometricSizeX / 2
            fovY = self.netdata.isometricSizeY / 2
        else
            local height = self.netdata.currentHeight - self.shape.worldPosition.z
            fovX = calculateCaptureArea(self.netdata.fovX, height)
            fovY = calculateCaptureArea(self.netdata.fovY, height)
        end
        local posdiff = shape.worldPosition - self.shape.worldPosition
        local posX = (posdiff.x - self.netdata.offsetX) / fovX
        local posY = (posdiff.y - self.netdata.offsetY) / fovY

        posX, posY = rotateVector(posX, posY, getCurrentRotation(self) + (math.pi / 2))
        posY = -posY
        posX = (posX + 1) / 2
        posY = (posY + 1) / 2

        if posX >= 0 and posX <= 1 and posY >= 0 and posY <= 1 then
            rc_insert(waypoints, {offsetX + mathRound(posX * (resolutionX - 1)), offsetY + mathRound(posY * (resolutionY - 1)), shape.color})
        end
        sc.yield()
    end
    return waypoints
end

local function defaultWaypointDrawer(display, waypoint)
    local circleSize = math.min(display.getSize()) / 32
    if circleSize < 3 then circleSize = 3 end
    display.fillCircle(waypoint[1], waypoint[2], circleSize, waypoint[3])
end

function RaycastCamera:sv_drawWaypoints(display, waypoints, drawer)
    drawer = drawer or defaultWaypointDrawer
    for _, waypoint in ipairs(waypoints) do
        drawer(display, waypoint)
        sc.yield()
    end
end

function RaycastCamera:_position()
    if self.netdata.customWorldPosition then
        return self.netdata.customWorldPosition
    end

    if self.data and self.data.minimap then
        local pos = self.shape.worldPosition
        if self.netdata.worldMode then
            pos = sm.vec3.zero()
        end
        pos.x = pos.x + self.netdata.offsetX
        pos.y = pos.y + self.netdata.offsetY
        pos.z = self.netdata.currentHeight
        return pos
    end

    return self.shape.worldPosition
end

function RaycastCamera:position()
    local pos = self:_position()
    if self.netdata.customLocalPosition then
        pos = pos + (self:rotation() * self.netdata.customLocalPosition)
    end
    if self.netdata.customLocalAfterPosition then
        pos = pos + self.netdata.customLocalAfterPosition
    end
    return pos
end

local function rotate_quaternion(q, angle, axis)
    local length = math.sqrt(axis.x^2 + axis.y^2 + axis.z^2)
    local u_x, u_y, u_z = axis.x / length, axis.y / length, axis.z / length
    
    local q_rotation = sm.quat.new(
        math.sin(angle / 2) * u_x,
        math.sin(angle / 2) * u_y,
        math.sin(angle / 2) * u_z,
        math.cos(angle / 2)
    )
    
    return q_rotation * q
end

local downQuat = sm.quat.new(0.707107, 0.707107, 0, 0)
function RaycastCamera:rotation()
    if self.netdata.customWorldRotation then
        return self.netdata.customWorldRotation
    end

    local rotation

    if self.data and self.data.minimap then
        rotation = downQuat
    else
        rotation = self.shape.worldRotation
    end
    
    return rotate_quaternion(rotation, getCurrentRotation(self), rotation * vec3_new(0, 0, 1))
end

function RaycastCamera:calcStartPosition()
    local shape = self.shape
    local position = self:position()
    local rotation = self:rotation()

    if self.data and self.data.minimap then
        return position
    end

    local direction = rotation * vec3_new(0, 0, 1)
    local startPosition = position + direction * 0.25
    if sm.physics.raycast(position, startPosition) then
        startPosition = position
    end
    return startPosition
end

local downDirection = vec3_new(0, 0, -1)
function RaycastCamera:rays(resolutionX, resolutionY, currentPixel, stepM, distance, fovX, fovY, downscale)
    if downscale ~= self.raysCache.downscale or
        fovX ~= self.raysCache.fovX or
        fovY ~= self.raysCache.fovY or
        resolutionX ~= self.raysCache.resolutionX or
        resolutionY ~= self.raysCache.resolutionY or
        stepM ~= self.raysCache.stepM or
        self.netdata.isometricRender ~= self.raysCache.isometricRender or
        self.netdata.isometricSizeX ~= self.raysCache.isometricSizeX or
        self.netdata.isometricSizeY ~= self.raysCache.isometricSizeY or
        self.netdata.ray_mask ~= self.raysCache.ray_mask or
        distance ~= self.raysCache.distance then
        self.raysCache = {}
        self.raysCache.downscale = downscale
        self.raysCache.fovX = fovX
        self.raysCache.fovY = fovY
        self.raysCache.resolutionX = resolutionX
        self.raysCache.resolutionY = resolutionY
        self.raysCache.stepM = stepM
        self.raysCache.distance = distance
        self.raysCache.isometricRender = self.netdata.isometricRender
        self.raysCache.isometricSizeX = self.netdata.isometricSizeX
        self.raysCache.isometricSizeY = self.netdata.isometricSizeY
        self.raysCache.ray_mask = self.netdata.ray_mask
    end

    if self.raysCache[currentPixel] then
        --print("FROM CACHE", currentPixel)
        return rc_multicast(self.raysCache[currentPixel])
    end

    local rays = {}
    if self.netdata.isometricRender then
        local shape = self.shape
        local position = self:position()
        local rotation = rotate_quaternion(downQuat, getCurrentRotation(self) + (math.pi / 2), downQuat * vec3_new(0, 0, 1))
        local startPosition = self:calcStartPosition()

        for i = 0, stepM do
            local pixel = currentPixel + i
            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY

            local vec = rotation * vec3_new(
                ((resolutionY - 1 - y) / resolutionY - 0.5) * self.netdata.isometricSizeY,
                (x / resolutionX - 0.5) * self.netdata.isometricSizeX,
                0
            )

            rays[i] = {
                type = "ray",
                startPoint = startPosition + vec,
                endPoint = startPosition + vec + downDirection * distance,
                mask = self.netdata.ray_mask
            }
        end
    else
        local shape = self.shape
        local position = self:position()
        local rotation = self:rotation()

        local startPosition = self:calcStartPosition()
        local vec = vec3_new(0, 0, 1)

        for i = 0, stepM do
            local pixel = currentPixel + i
            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY

            local u = ( x / resolutionX - 0.5 ) * fovX
            local v = ( y / resolutionY - 0.5 ) * fovY

            vec.x = -u
            vec.y = -v
            local direction = rotation * vec

            rays[i] = {
                type = "ray",
                startPoint = startPosition,
                endPoint = position + direction * distance,
                mask = self.netdata.ray_mask
            }
        end
    end

    self.raysCache[currentPixel] = rays
    return rc_multicast(rays)
end

function RaycastCamera:deepRays(resolutionX, resolutionY, currentPixel, stepM, distance, fovX, fovY, downscale, maxIntersections)
    local resultsIntersections = {}
    local currentPositions = {}
    local currentDistance = {}
    local currentOffset = {}

    local _startPosition = self:calcStartPosition()
    for i = 0, stepM do
        resultsIntersections[i] = {}
        currentPositions[i] = _startPosition
        currentDistance[i] = distance
        currentOffset[i] = 0
    end

    for intersectionIndex = 1, maxIntersections do
        local rays = {}
        local raysI = 1
        local mapping = {}

        if self.netdata.isometricRender then
            local rotation = rotate_quaternion(downQuat, getCurrentRotation(self) + (math.pi / 2), downQuat * vec3_new(0, 0, 1))

            for i = 0, stepM do
                local pixel = currentPixel + i
                local x = floor(pixel / resolutionY) % resolutionX
                local y = pixel % resolutionY

                local vec = rotation * vec3_new(
                    ((resolutionY - 1 - y) / resolutionY - 0.5) * self.netdata.isometricSizeY,
                    (x / resolutionX - 0.5) * self.netdata.isometricSizeX,
                    0
                )

                if currentDistance[i] then
                    rays[raysI] = {
                        type = "ray",
                        startPoint = currentPositions[i] + vec,
                        endPoint = currentPositions[i] + vec + downDirection * currentDistance[i],
                        mask = self.netdata.ray_mask
                    }
                    mapping[i] = raysI
                    raysI = raysI + 1
                end
            end
        else
            local rotation = self:rotation()

            local vec = vec3_new(0, 0, 1)

            for i = 0, stepM do
                local pixel = currentPixel + i
                local x = floor(pixel / resolutionY) % resolutionX
                local y = pixel % resolutionY

                local u = ( x / resolutionX - 0.5 ) * fovX
                local v = ( y / resolutionY - 0.5 ) * fovY

                vec.x = -u
                vec.y = -v
                local direction = rotation * vec

                if currentDistance[i] then
                    rays[raysI] = {
                        type = "ray",
                        startPoint = currentPositions[i],
                        endPoint = currentPositions[i] + direction * currentDistance[i],
                        mask = self.netdata.ray_mask
                    }
                    mapping[i] = raysI
                    raysI = raysI + 1
                end
            end
        end

        local results = rc_multicast(rays)

        for i = 0, stepM do
            if mapping[i] then
                local t = results[mapping[i]]
                if t[1] then
                    table.insert(resultsIntersections[i], self:getRaydata(t[1], t[2], currentDistance[i], currentOffset[i], distance, intersectionIndex == maxIntersections))
                    currentPositions[i] = t[2].pointWorld
                    local dist = currentDistance[i] * t[2].fraction
                    currentDistance[i] = currentDistance[i] - dist
                    currentOffset[i] = currentOffset[i] + dist
                    if currentDistance[i] < 0 then currentDistance[i] = nil end
                else
                    currentDistance[i] = nil
                end
            end
        end
    end

    return resultsIntersections
end

function RaycastCamera:sunRays(resolutionX, resolutionY, currentPixel, distance, results, advancedSettings)
    local shape = self.shape
    local position = self:position()
    local rotation = self:rotation()
    local sunDir = self:getSunDirection(advancedSettings)
    if not sunDir then return end

    local rays = {}
    local raysI = 1
    local out = {}

    local result
    local vecdat
    local startFrom
    for i = 1, #results do
        result = results[i]
        vecdat = result[2]
        if result[1] and vecdat.type ~= "limiter" then
            startFrom = vecdat.pointWorld - (cNormalize(vecdat.pointWorld - vecdat.originWorld) / 32)
            rays[raysI] = {
                type = "ray",
                startPoint = startFrom,
                endPoint = startFrom + (sunDir * distance),
                mask = self.netdata.ray_mask
            }
            out[i] = raysI
            raysI = raysI + 1
        end
    end

    local sunRays = {}
    local rayResult = rc_multicast(rays)
    for i, rayIndex in pairs(out) do
        sunRays[i] = rayResult[rayIndex]
    end
    return sunRays
end

local lampsStatesCache = {}
function RaycastCamera:getLampsData(distance)
    local lampsdata
    for _, shape in ipairs(sm.shape.shapesInSphere(self:position(), distance)) do
        if shape.interactable then
            local cacheState = lampsStatesCache[shape.interactable.id]
            local ctick = sm.game.getCurrentTick()
            if not cacheState or ctick - cacheState[2] > 20 then
                local parents = shape.interactable:getParents()
                local active = #parents == 0
                if not active then
                    for _, parent in ipairs(parents) do
                        if parent.active then
                            active = true
                            break
                        end
                    end
                end
                cacheState = {active, ctick}
                lampsStatesCache[shape.interactable.id] = cacheState
            end
            if cacheState[1] then
                local lampInfo = lamps[tostring(shape.uuid)]
                if lampInfo then
                    lampsdata = lampsdata or {}
                    rc_insert(lampsdata, {shape, lampInfo})
                end
            end
        end
    end
    return lampsdata
end

function RaycastCamera:getSkyState(advancedSettings)
    local time = advancedSettings.constDayLightValue or self.time or 0
    local index = floor(map(time, 0, 1, 1, #skyStates))
    local skyState = skyStates[index] or skyStates[1]
    if not skyState.colorNumber then
        skyState.colorNumber = formatColorToSmallNumber(skyState.color)
    end
    return skyState
end


function RaycastCamera:getSkyColor(advancedSettings)
    return self:getSkyState(advancedSettings).color
end

function RaycastCamera:getSunDirection(advancedSettings)
    return self:getSkyState(advancedSettings).dir
end

function RaycastCamera:getRaydata(successful, raydata, maxdist, offset, sourceMaxdist, endIntersection)
    local tbl = self:_getRaydata(successful, raydata, maxdist, offset)
    if tbl and self.unrestricted and scomputers.isUnsafeFeatures(self.interactable) then
        tbl.raydata = raydata
    end
    if endIntersection then
        tbl.deepDistance = offset + tbl.distance
        tbl.deepFraction = tbl.deepDistance / sourceMaxdist
    end
    return tbl
end

function RaycastCamera:_getRaydata(successful, raydata, maxdist)
    if not successful then return end

    local rtype = raydata.type
    if rtype == "limiter" then
        return {
            fraction = raydata.fraction,
            distance = raydata.fraction * maxdist,
            type = "limiter"
        }
    elseif rtype == "terrainAsset" then
        return {
            fraction = raydata.fraction,
            distance = raydata.fraction * maxdist,
            normalWorld = raydata.normalWorld,
            color = cached_getGroundColor(raydata.pointWorld, assetMaterialColors, assetsCache) or assetColor,
            type = "asset"
        }
    elseif rtype == "body" then
        local shape = raydata:getShape()
        local tbl =  {
            color = shape.color,
            fraction = raydata.fraction,
            normalWorld = raydata.normalWorld,
            distance = raydata.fraction * maxdist,
            type = "shape"
        }

        if self.unrestricted or raydata.fraction * maxdist <= 4 then
            tbl.uuid = shape.uuid
        end

        return tbl
    elseif rtype == "character" then
        local character = raydata:getCharacter()
        return {
            color = character.color,
            fraction = raydata.fraction,
            normalWorld = raydata.normalWorld,
            distance = raydata.fraction * maxdist,
            type = "character"
        }
    elseif rtype == "harvestable" then
        local harvestable = raydata:getHarvestable()
        return {
            color = harvestable:getColor(),
            fraction = raydata.fraction,
            normalWorld = raydata.normalWorld,
            distance = raydata.fraction * maxdist,
            type = "harvestable"
        }
    elseif rtype == "lift" then
        local lift = raydata:getLiftData()
        return {
            color = liftColor,
            fraction = raydata.fraction,
            normalWorld = raydata.normalWorld,
            distance = raydata.fraction * maxdist,
            type = "lift"
        }
    elseif rtype == "joint" then
        local joint = raydata:getJoint()
        return {
            color = joint.color,
            fraction = raydata.fraction,
            normalWorld = raydata.normalWorld,
            distance = raydata.fraction * maxdist,
            type = "joint"
        }
    else
        if rtype == "areaTrigger" then
            local triggerData = raydata:getAreaTrigger():getUserData()
            if triggerData then
                if triggerData.water then
                    return {
                        fraction = raydata.fraction,
                        distance = raydata.fraction * maxdist,
                        normalWorld = raydata.normalWorld,
                        color = waterColor,
                        type = "liquid"
                    }
                elseif triggerData.chemical then
                    return {
                        fraction = raydata.fraction,
                        distance = raydata.fraction * maxdist,
                        normalWorld = raydata.normalWorld,
                        color = chemicalColor,
                        type = "liquid"
                    }
                elseif triggerData.oil then
                    return {
                        fraction = raydata.fraction,
                        distance = raydata.fraction * maxdist,
                        normalWorld = raydata.normalWorld,
                        color = oilColor,
                        type = "liquid"
                    }
                end
            end
        end

        return {
            fraction = raydata.fraction,
            distance = raydata.fraction * maxdist,
            normalWorld = raydata.normalWorld,
            color = cached_getGroundColor(raydata.pointWorld) or defaultRayColor,
            type = "terrain"
        }
    end
end

function RaycastCamera:rawRay(xAngle, yAngle, maxdist, maxIntersections)
    local position = self:position()
    local rotation = self:rotation()

    if not self.unrestricted then
        if xAngle < -rad_82_5 then
            xAngle = -rad_82_5
        elseif xAngle > rad_82_5 then
            xAngle = rad_82_5
        end

        if yAngle < -rad_82_5 then
            yAngle = -rad_82_5
        elseif yAngle > rad_82_5 then
            yAngle = rad_82_5
        end
    end

    local mask
    if self.netdata.useMaskForRawRay then
        mask = self.netdata.ray_mask
    end

    local sourceMaxdist = maxdist
    if maxIntersections then
        local offset = 0
        local intersections = {}
        for i = 1, maxIntersections do
            if maxdist <= 0 then break end
            local successful, raydata = rc_raycast(position, position + (rotation * vec3_new(-xAngle, -yAngle, 1)) * maxdist, nil, mask)
            table.insert(intersections, self:getRaydata(successful, raydata, maxdist, offset, sourceMaxdist, i == maxIntersections))
            position = raydata.pointWorld
            local dist = raydata.fraction * maxdist
            maxdist = maxdist - dist
            offset = offset + dist
        end
        return intersections
    else
        local successful, raydata = rc_raycast(position, position + (rotation * vec3_new(-xAngle, -yAngle, 1)) * maxdist, nil, mask)
        return self:getRaydata(successful, raydata, maxdist)
    end
end

function RaycastCamera:sv_drawAdvanced(displayData, advancedSettings)
    preprocessAdvancedSettings(self, advancedSettings)

    --return self:sv_drawCustom(displayData, drawAdvanced, self:getSkyColor(), displayData.getWidth(), self.time, self:getLampsData(), self:getSkyState())
    local offsetX, offsetY, resolutionX, resolutionY = getViewport(self, displayData)
    local downscale = self.downscale
    local step
    resolutionX, resolutionY, step = downscaleResolution(resolutionX, resolutionY, self.step, downscale)
    checkNextPixel(self, resolutionX, resolutionY)

    local currentPixel = self.nextPixel
    local results = self:rays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale)
    local skyState = self:getSkyState(advancedSettings)
    local globalSunMul = getGlobalSunMul(self, advancedSettings)

    local sunRays, lampsData
    if advancedSettings.shadows then
        sunRays = self:sunRays(resolutionX, resolutionY, currentPixel, self.distance, results, advancedSettings)
    end
    if advancedSettings.lampLighting then
        lampsData = self:getLampsData(self.distance)
    end
    
    for i = 0, step - 1 do
        local res = results[i+1]
        local sunres = sunRays and sunRays[i+1]
        local pixel = currentPixel + i

        local x = floor(pixel / resolutionY) % resolutionX
        local y = pixel % resolutionY
        cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, formatColorStr(drawAdvanced(self, x, y, res, skyState, lampsData, sunres, advancedSettings, globalSunMul, self.distance)))
    end

    self:saveLastInfo(results)
    self.nextPixel = (currentPixel + step) % (resolutionX * resolutionY)
end

function RaycastCamera:sv_drawCustom(fromLastInfo, displayData, drawer, ...)
    local offsetX, offsetY, resolutionX, resolutionY = getViewport(self, displayData)
    local downscale = self.downscale
    local step
    resolutionX, resolutionY, step = downscaleResolution(resolutionX, resolutionY, self.step, downscale)

    if not fromLastInfo then
        checkNextPixel(self, resolutionX, resolutionY)
    end

    local currentPixel, results
    if fromLastInfo then
        local lastInfo = self:getLastInfo()
        if not lastInfo then return end

        currentPixel = lastInfo.position
        results = lastInfo.rays or self:rays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale)
    else
        currentPixel = self.nextPixel
        results = self:rays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale)
    end

    if displayData.noCameraEncode then
        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i
    
            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            local color = drawer(x, y, self:getRaydata(res and res[1], res and res[2], self.distance), ...)
            if color then
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, color)
            end
        end
    else
        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i
    
            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            local color = drawer(x, y, self:getRaydata(res and res[1], res and res[2], self.distance), ...)
            if color then
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, formatColorStr(color, true))
            end
        end
    end

    if not fromLastInfo then
        self:saveLastInfo(results)
        self.nextPixel = (currentPixel + step) % (resolutionX * resolutionY)
    end
end

function RaycastCamera:sv_deepDrawCustom(fromLastInfo, displayData, drawer, maxIntersections, ...)
    local offsetX, offsetY, resolutionX, resolutionY = getViewport(self, displayData)
    local downscale = self.downscale
    local step
    resolutionX, resolutionY, step = downscaleResolution(resolutionX, resolutionY, self.step, downscale)

    if not fromLastInfo then
        checkNextPixel(self, resolutionX, resolutionY)
    end

    local currentPixel, results
    if fromLastInfo then
        local lastInfo = self:getLastInfo()
        if not lastInfo then return end

        currentPixel = lastInfo.position
        results = lastInfo.deepRays or self:deepRays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale, maxIntersections)
    else
        currentPixel = self.nextPixel
        results = self:deepRays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale, maxIntersections)
    end

    if displayData.noCameraEncode then
        for i = 0, step - 1 do
            local pixel = currentPixel + i
    
            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            local color = drawer(x, y, results[i], ...)
            if color then
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, color)
            end
        end
    else
        for i = 0, step - 1 do
            local pixel = currentPixel + i
    
            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            local color = drawer(x, y, results[i], ...)
            if color then
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, formatColorStr(color, true))
            end
        end
    end

    if not fromLastInfo then
        self:saveLastInfo(results, true)
        self.nextPixel = (currentPixel + step) % (resolutionX * resolutionY)
    end
end

function RaycastCamera:saveLastInfo(rays, deep)
    self.sv_lastInfo = {
        position = self.nextPixel,
        tick = sm.game.getCurrentTick()
    }

    if deep then
        self.sv_lastInfo.deepRays = rays        
    else
        self.sv_lastInfo.rays = rays
    end
end

function RaycastCamera:cl_saveLastInfo(rays, nextPixel)
    self.cl_lastInfo = {
        rays = rays,
        position = nextPixel,
        tick = sm.game.getCurrentTick()
    }
end

function RaycastCamera:getLastInfo()
    if self.sv_lastInfo and self.cl_lastInfo then
        if self.cl_lastInfo.tick > self.sv_lastInfo.tick then
            return self.cl_lastInfo
        end
        return self.sv_lastInfo
    end

    return self.cl_lastInfo or self.sv_lastInfo
end

function RaycastCamera:sv_drawColorWithDepth(displayData, noCollideColor, terrainColor, unitsColor)
    local offsetX, offsetY, resolutionX, resolutionY = getViewport(self, displayData)
    local downscale = self.downscale
    local step
    resolutionX, resolutionY, step = downscaleResolution(resolutionX, resolutionY, self.step, downscale)
    checkNextPixel(self, resolutionX, resolutionY)

    local currentPixel = self.nextPixel
    local results = self:rays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale)

    terrainColor = formatColor(terrainColor or dcwf_def_terrainColor)
    unitsColor = formatColor(unitsColor or dcwf_def_unitsColor)
    
    if displayData.noCameraEncode then
        noCollideColor = formatColor(noCollideColor or dcwf_def_noCollideColor)
        
        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i

            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            if res and res[1] then
                local data = res[2]
                local shape = data:getShape()
                local character = data:getCharacter()
                if character then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, unitsColor * (1 - data.fraction))
                elseif shape then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, shape.color * (1 - data.fraction))
                elseif data.type ~= "limiter" then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, terrainColor * (1 - data.fraction))
                else
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
                end
            else
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
            end
        end
    else
        noCollideColor = formatColorStr(noCollideColor or dcwf_def_noCollideColor)
        
        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i

            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            if res and res[1] then
                local data = res[2]
                local shape = data:getShape()
                local character = data:getCharacter()
                if character then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, tostring(unitsColor * (1 - data.fraction)))
                elseif shape then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, tostring(shape.color * (1 - data.fraction)))
                elseif data.type ~= "limiter" then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, tostring(terrainColor * (1 - data.fraction)))
                else
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
                end
            else
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
            end
        end
    end

    self:saveLastInfo(results)
    self.nextPixel = (currentPixel + step) % (resolutionX * resolutionY)
end

function RaycastCamera:sv_drawDepth(displayData, baseColor, noCollideColor, unitsColor)
    local offsetX, offsetY, resolutionX, resolutionY = getViewport(self, displayData)
    local downscale = self.downscale
    local step
    resolutionX, resolutionY, step = downscaleResolution(resolutionX, resolutionY, self.step, downscale)
    checkNextPixel(self, resolutionX, resolutionY)

    local currentPixel = self.nextPixel
    local results = self:rays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale)

    unitsColor = formatColor(unitsColor or dd_def_unitsColor)
    baseColor = formatColor(baseColor or dd_def_baseColor)

    if displayData.noCameraEncode then
        noCollideColor = formatColor(noCollideColor or dd_def_noCollideColor)

        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i

            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            if res and res[1] then
                local data = res[2]
                local character = data:getCharacter()
                if character then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, unitsColor * (1 - data.fraction))
                elseif data.type ~= "limiter" then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, baseColor * (1 - data.fraction))
                else
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
                end
            else
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
            end
        end
    else
        noCollideColor = formatColorStr(noCollideColor or dd_def_noCollideColor)

        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i

            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            if res and res[1] then
                local data = res[2]
                local character = data:getCharacter()
                if character then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, tostring(unitsColor * (1 - data.fraction)))
                elseif data.type ~= "limiter" then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, tostring(baseColor * (1 - data.fraction)))
                else
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
                end
            else
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
            end
        end
    end

    self:saveLastInfo(results)
    self.nextPixel = (currentPixel + step) % (resolutionX * resolutionY)
end

function RaycastCamera:sv_drawColor(displayData, noCollideColor, terrainColor, unitsColor)
    local offsetX, offsetY, resolutionX, resolutionY = getViewport(self, displayData)
    local downscale = self.downscale
    local step
    resolutionX, resolutionY, step = downscaleResolution(resolutionX, resolutionY, self.step, downscale)
    checkNextPixel(self, resolutionX, resolutionY)

    local currentPixel = self.nextPixel
    local results = self:rays(resolutionX, resolutionY, currentPixel, step - 1, self.distance, self.fovX, self.fovY, downscale)

    if displayData.noCameraEncode then
        noCollideColor = formatColor(noCollideColor or dc_def_noCollideColor)
        terrainColor = formatColor(terrainColor or dc_def_terrainColor)
        unitsColor = formatColor(unitsColor or dc_def_unitsColor)

        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i

            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            if res and res[1] then
                local data = res[2]
                local shape = data:getShape()
                local character = data:getCharacter()
                if character then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, unitsColor)
                elseif shape then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, shape.color)
                elseif data.type ~= "limiter" then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, terrainColor)
                else
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
                end
            else
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
            end
        end
    else
        noCollideColor = formatColorStr(noCollideColor or dc_def_noCollideColor)
        terrainColor = formatColorStr(terrainColor or dc_def_terrainColor)
        unitsColor = formatColorStr(unitsColor or dc_def_unitsColor)

        for i = 0, step - 1 do
            local res = results[i+1]
            local pixel = currentPixel + i

            local x = floor(pixel / resolutionY) % resolutionX
            local y = pixel % resolutionY
            if res and res[1] then
                local data = res[2]
                local shape = data:getShape()
                local character = data:getCharacter()
                if character then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, unitsColor)
                elseif shape then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, tostring(shape.color))
                elseif data.type ~= "limiter" then
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, terrainColor)
                else
                    cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
                end
            else
                cDrawPixel(displayData, downscale, offsetX, offsetY, x, y, noCollideColor)
            end
        end
    end

    self:saveLastInfo(results)
    self.nextPixel = (currentPixel + step) % (resolutionX * resolutionY)
end

function RaycastCamera:server_onCreate()
    if self.data and self.data.unrestricted then
        self.unrestricted = true
    end

    self.camApi = self:createData()
    if self.interactable then
        local id = self.interactable:getId()
        sc.camerasDatas[id] = self.camApi
        sc.camerasRefs[id] = self
    end

    self.step = 256
    self.nextPixel = 0
    self.distance = 1024
    self.fovX = rad_60
    self.fovY = rad_60
    self.raysCache = {}
end

local function simpleQuatDif(q1, q2)
    return math.abs(q1.x - q2.x) + math.abs(q1.y - q2.y) + math.abs(q1.z - q2.z) + math.abs(q1.w - q2.w)
end

function RaycastCamera:cacheCheck()
    local pos = self:position()
    local rot = self:rotation()

    if self.oldPos then
        if mathDist(self.oldPos, pos) > 0.01 or simpleQuatDif(rot, self.oldRot) > 0.01 then
            self.raysCache = {}
            self.oldPos = pos
            self.oldRot = rot
        end
    else
        self.oldPos = pos
        self.oldRot = rot
    end
end

function RaycastCamera:sv_dataRequest(_, player)
    self.network:sendToClient(player, "cl_netdata", self.netdata)
end

function RaycastCamera:server_onFixedUpdate()
    self:cacheCheck()

    if self.network and self.netdataSend then
        self.network:sendToClients("cl_netdata", self.netdata)
        self.netdataSend = nil
    end

    if self.interactable then
        local ctick = sm.game.getCurrentTick()
        self.interactable:setActive(self.lightTick and (ctick - self.lightTick < 10) or false)
    end
end

function RaycastCamera.server_onDestroy(self)
    local id = self.interactable:getId()
    sc.camerasDatas[id] = nil
    sc.camerasRefs[id] = nil
end


function RaycastCamera:client_onCreate()
    if self.data and self.data.unrestricted then
        self.unrestricted = true
    end

    clientCameras[self.interactable.id] = self
    self.time = sm.render.getOutdoorLighting()
    self.raysCache = {}
    self.netdata = self.netdata or {}

    self.network:sendToServer("sv_dataRequest")
end

function RaycastCamera:client_onDestroy()
    clientCameras[self.interactable.id] = nil
end

function RaycastCamera:client_onFixedUpdate()
    --sm.render.setOutdoorLighting(math.sin(math.rad(sm.game.getCurrentTick() / 15)))
    self.time = sm.render.getOutdoorLighting()
    if not sm.isHost then
        self:cacheCheck()
    end

    self.interactable:setPoseWeight(0, self.interactable:isActive() and 1 or 0)
end

function RaycastCamera:cl_netdata(netdata)
    if sm.isHost then return end
    self.netdata = netdata
end