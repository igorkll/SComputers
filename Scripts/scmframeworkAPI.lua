scmframework = {
    version = "1.1",
    scomputers = scomputers,
    dofile = scmframework_dofile
}

local hookCallbackSetters = {
    "setButtonCallback",
    "setGridButtonCallback",
    "setGridItemChangedCallback",
    "setGridMouseFocusCallback",
    "setListSelectionCallback",
    "setSliderCallback",
    "setTextAcceptedCallback",
    "setTextChangedCallback"
}

local hookGuiCreators = {
    "createAmmunitionContainerGui",
    "createBagIconGui",
    "createBatteryContainerGui",
    "createBeaconIconGui",
    "createChallengeHUDGui",
    "createChallengeMessageGui",
    "createCharacterCustomizationGui",
    "createChemicalContainerGui",
    "createContainerGui",
    "createCraftBotGui",
    "createDressBotGui",
    "createEngineGui",
    "createFertilizerContainerGui",
    "createGasContainerGui",
    "createGuiFromLayout",
    "createHideoutGui",
    "createLogbookGui",
    "createMechanicStationGui",
    "createNameTagGui",
    "createQuestTrackerGui",
    "createSeatGui",
    "createSeatUpgradeGui",
    "createSeedContainerGui",
    "createSteeringBearingGui",
    "createSurvivalHudGui",
    "createWaterContainerGui",
    "createWaypointIconGui",
    "createWorkbenchGui",
    "createWorldIconGui"
}

----------------------------------------------

local isRealObjectExists_tag = {}

local function loadRealObject(fakeObject)
    local ok, result = pcall(function ()
        if fakeObject.isRealObjectExists == isRealObjectExists_tag then
            return fakeObject.realObject
        end
    end)
    if ok and result then
        return result
    end
    return fakeObject
end

local function getBundle(virtualShape)
    if sm.isServerMode() then
        return virtualShape.sv_bundle or error("failed to get bundle server reference")
    else
        return virtualShape.cl_bundle or error("failed to get bundle client reference")
    end
end

----------------------------------------------

local virtualShapeClass = {}

function virtualShapeClass:interact(character, state)
    if self.self.client_onInteract then
        self.self:client_onInteract(character, state)
    end
end

function virtualShapeClass:tinker(character, state)
    if self.self.client_onTinker then
        self.self:client_onTinker(character, state)
    end
end

function virtualShapeClass:canInteract(character)
    if self.self.client_canInteract then
        return not not self.self:client_canInteract(character)
    end
    return not not self.self.client_onInteract
end

function virtualShapeClass:canTinker(character)
    if self.self.client_canTinker then
        return not not self.self:client_canTinker(character)
    end
    return not not self.self.client_onTinker
end

function virtualShapeClass:createVirtualLink(child)
    local bundle = getBundle(self)
    if not bundle.virtualLinks_childen[self] then bundle.virtualLinks_childen[self] = {} end
    if not bundle.virtualLinks_parents[child] then bundle.virtualLinks_parents[child] = {} end
    table.insert(bundle.virtualLinks_childen[self], child.interactable)
    table.insert(bundle.virtualLinks_parents[child], self.interactable)
end

function virtualShapeClass:setOpenedOutput(openedOutput)
    self.openedOutput = not not openedOutput
end

function virtualShapeClass:setOpenedInput(openedInput)
    self.openedInput = not not openedInput
end

----------------------------------------------

local virtualComputer = {}

function virtualComputer:getEnv()
    return self.self.env
end

function virtualComputer:reboot()
    self.self.reboot_flag = true
end

function virtualComputer:setActive(active)
    self.self.external_active = not not active
end

function virtualComputer:isActive()
    return self.self.isActive
end

----------------------------------------------

local function mt_hook(mt)
	local empty_class = class(mt)
    empty_class.__index = mt.__index
    return empty_class()
end

local function createVirtualNetwork(virtualShape)
    virtualShape.self.network = {}

    virtualShape.self.network.realObject = virtualShape.realSelf.network
    virtualShape.self.network.isRealObjectExists = isRealObjectExists_tag

    function virtualShape.self.network:sendToServer(method, arg)
        if sm.isServerMode() then
            error("Sandbox violation (virtualShape): calling client function from server callback.", 2)
        end
        table.insert(getBundle(virtualShape).sendBuffer, {target="server",arg={method, arg, virtualShape.index}})
    end

    function virtualShape.self.network:sendToClient(player, method, arg)
        if not sm.isServerMode() then
            error("Sandbox violation (virtualShape): calling server function from client callback.", 2)
        end
        table.insert(getBundle(virtualShape).sendBuffer, {player=player,target="client",arg={method, arg, virtualShape.index}})
    end

    function virtualShape.self.network:sendToClients(method, arg)
        if not sm.isServerMode() then
            error("Sandbox violation (virtualShape): calling server function from client callback.", 2)
        end
        table.insert(getBundle(virtualShape).sendBuffer, {target="clients",arg={method, arg, virtualShape.index}})
    end
end

local function createVirtualStorage(virtualShape)
    virtualShape.self.storage = {}

    virtualShape.self.storage.realObject = virtualShape.realSelf.storage
    virtualShape.self.storage.isRealObjectExists = isRealObjectExists_tag

    local realStorageData = virtualShape.realSelf.storage:load()
    if type(realStorageData) ~= "table" then realStorageData = {} end
    realStorageData.virtualStorage = realStorageData.virtualStorage or {}

    function virtualShape.self.storage:load()
        return realStorageData.virtualStorage[virtualShape.index] or virtualShape.defaultStorage
    end

    function virtualShape.self.storage:save(data)
        realStorageData.virtualStorage[virtualShape.index] = data
        virtualShape.realSelf.storage:save(realStorageData)
    end
end

local function hookValue(tbl, key)
    local val = tbl[key]
    if type(val) == "function" then
        return function(_, ...)
            return val(tbl, ...)
        end
    end
    return val
end

local function createVirtualShape(virtualShape)
    local realSelf = virtualShape.realSelf

    virtualShape.shape = mt_hook({
        __index = function(_, key)
            if key == "interactable" then
                return virtualShape.interactable
            end
            return hookValue(realSelf.shape, key)
        end
    })

    virtualShape.shape.realObject = realSelf.shape
    virtualShape.shape.isRealObjectExists = isRealObjectExists_tag

    virtualShape.self.shape = virtualShape.shape
end

local function copyTable(tbl, newtbl)
    for _, v in ipairs(newtbl or {}) do
        table.insert(tbl, v)
    end
end

local function copyTableKV(tbl, newtbl)
    for k, v in pairs(newtbl or {}) do
       tbl[k] = v
    end
end

local function createVirtualInteractable(virtualShape)
    local realSelf = virtualShape.realSelf

    virtualShape.interactable = mt_hook({
        __index = function(_, key)
            if key == "shape" then
                return virtualShape.shape
            elseif key == "body" then
                return realSelf.shape.body
            end
            return hookValue(realSelf.interactable, key)
        end
    })

    virtualShape.interactable.id = math.random(0, 9999999)
    virtualShape.interactable.active = false
    virtualShape.interactable.power = 0
    virtualShape.interactable.type = "scripted"
    virtualShape.interactable.publicData = {}

    virtualShape.interactable.realObject = realSelf.interactable
    virtualShape.interactable.isRealObjectExists = isRealObjectExists_tag

    function virtualShape.interactable:getShape()
        return virtualShape.shape
    end

    function virtualShape.interactable:getBody()
        return virtualShape.shape.body
    end

    function virtualShape.interactable:getType()
        return virtualShape.interactable.type
    end

    function virtualShape.interactable:getId()
        return virtualShape.interactable.id
    end

    function virtualShape.interactable:isActive()
        return virtualShape.interactable.active
    end

    function virtualShape.interactable:setActive(active)
        checkArg(1, active, "boolean")
        virtualShape.interactable.active = active
    end

    function virtualShape.interactable:setPower(power)
        checkArg(1, power, "number")
        virtualShape.interactable.power = power
    end

    function virtualShape.interactable:getPower()
        return virtualShape.interactable.power
    end

    function virtualShape.interactable:setPublicData(publicData)
        virtualShape.interactable.publicData = publicData
    end

    function virtualShape.interactable:getPublicData(publicData)
        return virtualShape.interactable.publicData
    end

    function virtualShape.interactable:getChildren()
        local tbl = {}
        copyTable(tbl, getBundle(virtualShape).virtualLinks_childen[virtualShape])
        if virtualShape.openedOutput then
            copyTable(tbl, realSelf.interactable:getChildren())
        end
        return tbl
    end

    function virtualShape.interactable:getParents()
        local tbl = {}
        copyTable(tbl, getBundle(virtualShape).virtualLinks_parents[virtualShape])
        if virtualShape.openedInput then
            copyTable(tbl, realSelf.interactable:getParents())
        end
        return tbl
    end

    local poseWeight = {}
    function virtualShape.interactable:setPoseWeight(index, value)
        poseWeight[index] = value
    end

    function virtualShape.interactable:getPoseWeight(index)
        return poseWeight[index] or 0
    end

    local uvFrameIndex = 0
    function virtualShape.interactable:setUvFrameIndex(index)
        uvFrameIndex = index
    end

    function virtualShape.interactable:getUvFrameIndex()
        return uvFrameIndex
    end
    
    virtualShape.self.interactable = virtualShape.interactable
end

local function createFakeGui(virtualShape, gui)
    local fake = mt_hook({
        __index = function(_, key)
            return function(_, ...)
                return gui[key](gui, ...)
            end
        end
    })

    for _, callbackSetter in ipairs(hookCallbackSetters) do
        fake[callbackSetter] = function(_, widgetName, callback)
            getBundle(virtualShape).guiCallbacks[widgetName] = {virtualShape, callback}
            return gui[callbackSetter](gui, widgetName, "cl_guiCallback")
        end
    end

    fake.setOnCloseCallback = function(_, callback)
        getBundle(virtualShape).guiCloseCallbacks[virtualShape] = callback
        return gui:setOnCloseCallback("cl_guiCloseCallback")
    end

    return fake
end

local sm_gui = sm.gui
local function loadFakeGui(virtualShape)
    if not virtualShape.fake_gui then
        virtualShape.fake_gui = {}
        for k, v in pairs(sm_gui) do
            virtualShape.fake_gui[k] = v
        end

        for _, guiCreator in ipairs(hookGuiCreators) do
            virtualShape.fake_gui[guiCreator] = function(...)
                return createFakeGui(virtualShape, sm_gui[guiCreator](...))
            end
        end
    end
    return virtualShape.fake_gui
end

local sm_interactable_getChildren = sm.interactable.getChildren
local sm_interactable_getParents = sm.interactable.getParents

local function fake_interactable_getChildren(interactable)
    return interactable:getChildren()
end

local function fake_interactable_getParents(interactable)
    return interactable:getParents()
end

local sm_effect_createEffect = sm.effect.createEffect

local function fake_effect_createEffect(name, target, boneName)
    return sm_effect_createEffect(name, loadRealObject(target), boneName)
end

local sm_exists = sm.exists

local function fake_exists(obj)
    return sm_exists(loadRealObject(obj))
end

local _type = type

local function new_type(val)
    return _type(loadRealObject(val))
end

local function pushBaseEnvHacks()
    sm.interactable.getChildren = fake_interactable_getChildren
    sm.interactable.getParents = fake_interactable_getParents
    sm.effect.createEffect = fake_effect_createEffect
    sm.exists = fake_exists
    type = new_type
end

local function popBaseEnvHacks()
    sm.interactable.getChildren = sm_interactable_getChildren
    sm.interactable.getParents = sm_interactable_getParents
    sm.effect.createEffect = sm_effect_createEffect
    sm.exists = sm_exists
    type = _type
end

local function pushEnvHacks(virtualShape)
    if not sm.isServerMode() then
        sm.gui = loadFakeGui(virtualShape)
    end
    pushBaseEnvHacks()
end

local function popEnvHacks(virtualShape)
    if not sm.isServerMode() then
        sm.gui = sm_gui
    end
    popBaseEnvHacks()
end

local function createVirtualShapeBundle(realSelf, clientMode)
    local prefix = clientMode and "client_" or "server_"
    local bundle = {
        sendBuffer = {},
        virtualShapes = {},
        guiCallbacks = {},
        guiCloseCallbacks = {},
        virtualLinks_childen = {},
        virtualLinks_parents = {}
    }

    local function runMethodWithoutPrefix(virtualShape, method, ...)
        local func = virtualShape.self[method]
        if func then
            pushEnvHacks(virtualShape)
            func(virtualShape.self, ...)
            popEnvHacks(virtualShape)
        end
    end

    local function runMethod(virtualShape, method, ...)
        runMethodWithoutPrefix(virtualShape, prefix .. method, ...)
    end

    function bundle.runMethod(method, ...)
        for _, virtualShape in ipairs(bundle.virtualShapes) do
            runMethod(virtualShape, method, ...)
        end
    end

    local function addBundleToShape(virtualShape, bundle)
        if sm.isServerMode() then
            virtualShape.sv_bundle = bundle
        else
            virtualShape.cl_bundle = bundle
        end
    end

    function bundle.addShape(klass, scriptedData, defaultStorage)
        local index = #bundle.virtualShapes + 1
        if realSelf.clientServerVirtualShapeLink[index] then
            local virtualShape = realSelf.clientServerVirtualShapeLink[index]
            addBundleToShape(virtualShape, bundle)
            table.insert(bundle.virtualShapes, virtualShape)
            runMethod(virtualShape, "onCreate")
            return virtualShape
        else
            local virtualSelf = klass()
            virtualSelf.data = scriptedData

            local virtualShape = {
                class = klass,
                data = scriptedData,
                defaultStorage = defaultStorage,
                self = virtualSelf,
                index = index,
                realSelf = realSelf,
                openedInput = false,
                openedOutput = false
            }

            addBundleToShape(virtualShape, bundle)
    
            for k, v in pairs(virtualShapeClass) do
                virtualShape[k] = v
            end
    
            createVirtualShape(virtualShape)
            createVirtualInteractable(virtualShape)
            createVirtualNetwork(virtualShape)
            createVirtualStorage(virtualShape)
    
            table.insert(bundle.virtualShapes, virtualShape)
            runMethod(virtualShape, "onCreate")
    
            realSelf.clientServerVirtualShapeLink[index] = virtualShape
            return virtualShape
        end
    end

    function bundle.networkCallback(package, player)
        local virtualShape = assert(bundle.virtualShapes[package[3]])
        runMethodWithoutPrefix(virtualShape, package[1], package[2], player)
    end

    function bundle.guiCallback(widgetName, ...)
        local callbackInfo = assert(bundle.guiCallbacks[widgetName])
        runMethodWithoutPrefix(callbackInfo[1], callbackInfo[2], widgetName, ...)
    end

    function bundle.guiCloseCallback(...)
        for virtualShape, callback in pairs(bundle.guiCloseCallbacks) do
            runMethodWithoutPrefix(virtualShape, callback, ...)
        end
    end

    function bundle.getNetwork()
        local _sendBuffer = bundle.sendBuffer
        bundle.sendBuffer = {}
        return _sendBuffer
    end

    function bundle.destroy()
        for _, virtualShape in ipairs(bundle.virtualShapes) do
            runMethod(virtualShape, "onDestroy")
        end
    end

    return bundle
end

----------------------------------------------

scmframework.scmframeworkClass = class()

function scmframework.scmframeworkClass:server_onCreate()
    self.clientServerVirtualShapeLink = self.clientServerVirtualShapeLink or {}
    self.sv_virtualShapeBundle = createVirtualShapeBundle(self, false)

    if self.scmframework_init then
        self:scmframework_init()
    end
end

function scmframework.scmframeworkClass:client_onCreate()
    self.clientServerVirtualShapeLink = self.clientServerVirtualShapeLink or {}
    self.cl_virtualShapeBundle = createVirtualShapeBundle(self, true)

    if self.scmframework_init then
        self:scmframework_init()
    end
end

local function doNetwork(self, sendBuffer)
    for _, rawPackage in ipairs(sendBuffer) do
        if rawPackage.target == "server" then
            self.network:sendToServer("sv_network", rawPackage.arg)
        elseif rawPackage.target == "clients" then
            self.network:sendToClients("cl_network", rawPackage.arg)
        elseif rawPackage.target == "client" then
            self.network:sendToClient(rawPackage.player, "cl_network", rawPackage.arg)
        end
    end
end

function scmframework.scmframeworkClass:server_onFixedUpdate(dt)
    self.sv_virtualShapeBundle.runMethod("onFixedUpdate", dt)
    doNetwork(self, self.sv_virtualShapeBundle.getNetwork())
end

function scmframework.scmframeworkClass:client_onFixedUpdate(dt)
    self.cl_virtualShapeBundle.runMethod("onFixedUpdate", dt)
    doNetwork(self, self.cl_virtualShapeBundle.getNetwork())
end

function scmframework.scmframeworkClass:client_onUpdate(dt)
    self.cl_virtualShapeBundle.runMethod("onUpdate", dt)
end

function scmframework.scmframeworkClass:sv_network(package, player)
    self.sv_virtualShapeBundle.networkCallback(package, player)
end

function scmframework.scmframeworkClass:cl_network(package)
    self.cl_virtualShapeBundle.networkCallback(package)
end

function scmframework.scmframeworkClass:cl_guiCallback(widgetName, ...)
    self.cl_virtualShapeBundle.guiCallback(widgetName, ...)
end

function scmframework.scmframeworkClass:cl_guiCloseCallback(...)
    self.cl_virtualShapeBundle.guiCloseCallback(...)
end

function scmframework.scmframeworkClass:server_onDestroy()
    self.sv_virtualShapeBundle.destroy()
end

function scmframework.scmframeworkClass:client_onDestroy()
    self.cl_virtualShapeBundle.destroy()
end

function scmframework.scmframeworkClass:addVirtualShape(...)
    if sm.isServerMode() then
        return self.sv_virtualShapeBundle.addShape(...)
    else
        return self.cl_virtualShapeBundle.addShape(...)
    end
end

function scmframework.scmframeworkClass:addVirtualComputer(defaultScript, defaultData, alwaysOn, unsafe, localEnvHook)
    checkArg(1, defaultScript, "string", "nil")
    checkArg(2, defaultData, "string", "nil")
    checkArg(3, alwaysOn, "boolean", "nil")
    checkArg(4, unsafe, "boolean", "nil")
    checkArg(5, localEnvHook, "function", "nil")

    local virtualShape = self:addVirtualShape(ScriptableComputer, {
        unsafe = unsafe,
        localEnvHook = localEnvHook
    }, {
        alwaysOn = alwaysOn,

        script = defaultScript or "",
        gsubFix = true,

        userdata = base64.encode(defaultData or ""),
        userdata_bs64 = true
    })
    copyTableKV(virtualShape, virtualComputer)
    return virtualShape
end

function scmframework.scmframeworkClass:addVirtualDisplay(width, height, sizeX, sizeY, zpos)
    checkArg(1, width, "number")
    checkArg(2, height, "number")
    checkArg(3, sizeX, "number")
    checkArg(4, sizeY, "number")
    checkArg(5, zpos, "number", "nil")

    return self:addVirtualShape(AnyDisplay, {
        x = width,
        y = height,
        sizeX = sizeX,
        sizeY = sizeY,
        zpos = zpos or 0
    })
end

function scmframework.scmframeworkClass:addVirtualClassicDisplay(width, height)
    checkArg(1, width, "number")
    checkArg(2, height, "number")

    local boundingBox = self.shape:getBoundingBox()
    return self:addVirtualShape(AnyDisplay, {
        x = width,
        y = height,
        v = 32 * boundingBox.z * 4,
        div = true
    })
end

function scmframework.scmframeworkClass:addVirtualSynthesizer()
    return self:addVirtualShape(synthesizer)
end

function scmframework.scmframeworkClass:addVirtualGps()
    return self:addVirtualShape(gps)
end

----------------------------------------------

pushBaseEnvHacks()
dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/ScriptableComputer.lua")
dofile("$CONTENT_DATA/Scripts/synthesizer.lua")
dofile("$CONTENT_DATA/Scripts/gps.lua")
dofile("$CONTENT_DATA/Scripts/Displays/AnyDisplay.lua")
popBaseEnvHacks()

----------------------------------------------

scmframework.defaultSettings = sc.defaultRestrictions
scmframework.unrestrictedSettings = sc.unrestrictedRestrictions

function scmframework.setSComputersSettings(settings)
    sc.setRestrictions(settings)
    sc.saveRestrictions()
end