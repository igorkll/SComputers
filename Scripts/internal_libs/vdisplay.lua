function sc_reglib_vdisplay()
local math_floor = math.floor
local vdisplay = {}

local function localNeedPushStack(audience, dataTunnel, dt)
    return dataTunnel.display_forceFlush or not ((dataTunnel.skipAtNotSight and audience <= 0))
end

function vdisplay.create(callbacks, width, height, supportGlassMaterial, glassMaterialByDefault, allowSetResolution)
    local setResolutionSettings
	if allowSetResolution then
		local maxSide = math.max(width, height)
		setResolutionSettings = {
			maxPixels = width * height,
			maxWidth = maxSide,
			maxHeight = maxSide
		}
	end

    local dataTunnel = {}
    local audience = 1
    local libUpdate
    local libUpdateManualCall = false
    local obj
    local drawer = canvasAPI.createDrawer(width, height, function (x, y, color)
        callbacks.set(obj, x, y, color)
    end, nil, nil, nil, nil, nil, true)
    obj = canvasAPI.createScriptableApi(width, height, dataTunnel, function ()
        if not libUpdateManualCall then --if there is no manual library update, it will occur when flush is called.
            libUpdate()
        end
    end, drawer, supportGlassMaterial and canvasAPI.materialList or canvasAPI.materialListWithoutGlass, glassMaterialByDefault and 0 or 1, nil, setResolutionSettings)
    callbacks.pushClick = canvasAPI.addTouch(obj, dataTunnel)

    function callbacks.updateAudience(_audience)
        checkArg(1, "number", _audience)
        audience = _audience
    end

    local oldUpdateTick
    function libUpdate()
        local ctick = sm.game.getCurrentTick()
        if ctick == oldUpdateTick then return end
        oldUpdateTick = ctick

        dataTunnel.scriptableApi_update()

        if dataTunnel.display_reset then
            drawer.drawerReset()
            dataTunnel.display_reset = nil
        end

        if dataTunnel.dataUpdated then
            drawer.pushDataTunnelParams(dataTunnel)
            dataTunnel.dataUpdated = nil
        end

        if dataTunnel.display_flush then
            if localNeedPushStack(audience, dataTunnel, sc.deltaTime) then
                drawer.pushStack(dataTunnel.display_stack)
                drawer.flush()
                callbacks.flush(obj, not not dataTunnel.display_forceFlush)
            end
            
            dataTunnel.display_flush()
            dataTunnel.display_stack = nil
            dataTunnel.display_flush = nil
            dataTunnel.display_forceFlush = nil
            dataTunnel.display_forceForceFlush = nil
        end
    end
    callbacks.update = function()
        libUpdateManualCall = true
        libUpdate()
    end

    function obj.getAudience()
        return audience
    end

    drawer.flush(true)
    obj.noCameraEncode = true
    return obj
end

function vdisplay.touchscreen(vdisplayObject)
    local dataTunnel = {}
    local processClick = canvasAPI.addTouch(vdisplayObject, dataTunnel)
    return function (x, y, state, button, nickname)
        checkArg(1, x, "number")
        checkArg(2, y, "number")
        checkArg(3, state, "string")
        checkArg(4, button, "number")
        checkArg(5, nickname, "string")
        if not dataTunnel.clicksAllowed then
            return
        end
        return processClick({x, y, state, button, nickname})
    end
end

function vdisplay.bundle(displays, numberDisplaysByWidth)
    local width, height
    local supportGlassMaterial = true
    for i, display in ipairs(displays) do
        if width then
            if width ~= display.getWidth() or height ~= display.getHeight() then
                error("vdisplay.bundle: the index \"" .. i .. "\" display has a different resolution from the first display", 2)
            end
        else
            width, height = display.getSize()
        end
        if display.getDefaultMaterial() ~= 0 then
            supportGlassMaterial = false
        end
    end

    local numberDisplaysByHeight = #displays / numberDisplaysByWidth
    local bundleWidth, bundleHeight = width * numberDisplaysByWidth, height * numberDisplaysByHeight

    local vdisplayObject = vdisplay.create({
        set = function(vdisplayObject, x, y, color)
            local index = math_floor(x / width) + (math_floor(y / height) * numberDisplaysByWidth)
            displays[index + 1].drawPixel(x % width, y % height, color)
        end,
        flush = function(vdisplayObject, isForce)
            if isForce then
                for i, display in ipairs(displays) do
                    display.forceFlush()
                end
            else
                for i, display in ipairs(displays) do
                    display.flush()
                end
            end
        end
    }, bundleWidth, bundleHeight, supportGlassMaterial, supportGlassMaterial)

    local function hookSetter(name)
        local oldFunc = vdisplayObject[name]
        vdisplayObject[name] = function(...)
            for i, display in ipairs(displays) do
                if display[name] then
                    display[name](...)
                end
            end
            if oldFunc then
                return oldFunc(...)
            end
        end
    end

    local function hookGetter(name)
        vdisplayObject[name] = function(...)
            if displays[1][name] then
                return displays[1][name](...)
            end
        end
    end

    local touchscreen = vdisplay.touchscreen(vdisplayObject)

    hookSetter("setLight")
    hookGetter("getLight")

    hookSetter("setOptimizationLevel")
    hookGetter("getOptimizationLevel")

    hookSetter("setBrightness")
    hookGetter("getBrightness")

    hookSetter("setMaterial")
    hookGetter("getMaterial")

    hookSetter("setSkipAtNotSight")
    hookGetter("getSkipAtNotSight")

    hookSetter("setClicksAllowed")
    hookGetter("getClicksAllowed")

    hookSetter("setMaxClicks")
    hookGetter("getMaxClicks")

    hookGetter("isAllow")
    hookGetter("getAudience")
    
    local _reset = vdisplayObject.reset
    function vdisplayObject.reset()
        for i, display in ipairs(displays) do
            display.reset()
        end
        _reset()
    end

    local _getClick = vdisplayObject.getClick
    function vdisplayObject.getClick()
        for i, display in ipairs(displays) do
            local ii = i - 1
            local displayX, displayY = ii % numberDisplaysByWidth, math.floor(ii / numberDisplaysByWidth)
            for i = 1, 16 do
                local click = display.getClick()
                if not click then
                    break
                end
                click[1] = click.x + (displayX * width)
                click[2] = click.y + (displayY * height)
                touchscreen(unpack(click))
            end
        end
        return _getClick()
    end

    function vdisplayObject.getDefaultMaterial()
        return supportGlassMaterial and 0 or 1
    end

    return vdisplayObject
end

return vdisplay
end