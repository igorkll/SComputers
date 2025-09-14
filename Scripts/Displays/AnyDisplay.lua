--dofile("$CONTENT_DATA/Scripts/Displays/old/AnyDisplay.lua")
--do return end

dofile("$CONTENT_DATA/Scripts/Config.lua")
AnyDisplay = class(canvasAPI.canvasService)
AnyDisplay.maxParentCount = 1
AnyDisplay.maxChildCount = 0
AnyDisplay.connectionInput = sm.interactable.connectionType.composite
AnyDisplay.colorNormal = sm.color.new(0xbbbb1aff)
AnyDisplay.colorHighlight = sm.color.new(0xecec1fff)
AnyDisplay.componentType = "display"
AnyDisplay.stretchable_core_uuid = sm.uuid.new("ab36aa06-ea7d-4309-acd1-ed772e8c61fc")
AnyDisplay.stretchable_part_uuid = sm.uuid.new("c4704ff3-dd5a-4840-bfd6-0551497ccc32")

local PIXEL_SCALE = 0.0072
local RENDER_DISTANCE = 15
local DEBUG_WORLDMODE = false
local defaultTrySend = 7000
local sc = sc

--is it allowed to distort the geometry when auto is enabled to avoid pixels that pop out of the screen
local allowDistortGeometry = false
--local _debug_overwriteScale = 729

--------------------------------------- SERVER

local stackChecksum = canvasAPI.stackChecksum
local needPushStack = canvasAPI.needPushStack

local function sendStack(self, method, stack, force, forceForce)
    if #sm.player.getAllPlayers() > 1 then
        stack.flush = true
        stack.force = force
        stack.forceForce = forceForce
        if not pcall(self.network.sendToClients, self.network, method, stack) then
            stack.flush = nil

            local mul = 0.8
            local index = 1
            local stackSize = #stack
            local count = math.min(stackSize, self.tryPacket or defaultTrySend)
            local cycles = 0
            local lastIndex
            local datapack
            local dataPackI
            while true do
                lastIndex = index + (count - 1)
                datapack = {}
                dataPackI = 1
                for i = index, math.min(lastIndex, stackSize) do
                    datapack[dataPackI] = stack[i]
                    dataPackI = dataPackI + 1
                end
                datapack.force = force

                index = index + count
                if lastIndex >= #stack then
                    datapack.flush = true
                    if pcall(self.network.sendToClients, self.network, method, datapack) then
                        self.tryPacket = count
                        break
                    else
                        datapack.flush = nil
                        index = index - count
                        count = math.floor(count * mul)
                    end
                elseif not pcall(self.network.sendToClients, self.network, method, datapack) then
                    index = index - count
                    count = math.floor(count * mul)
                end

                cycles = cycles + 1
                if cycles > 100 then
                    print("try send: ", pcall(self.network.sendToClients, self.network, method, stack))
                    error("cycles to many 100")
                    break
                end
            end
        end
    else
        stack.force = force
        self["sendedData_" .. method] = stack
        self.network:sendToClients(method)
    end
end

function AnyDisplay:isAllow()
    if not sc.restrictions then return true end
    return self.width * self.height <= (sc.restrictions.maxDisplays * sc.restrictions.maxDisplays) --attempt to index field 'restrictions' (a nil value) on clients
end

local directList

function AnyDisplay:server_onCreate()
    self.lastLagScore = 0
	self.dataTunnel = {}
	self.width = self.data.x
	self.height = self.data.y
    self.mulSize = self.width * self.height
	local allowHoloAPI = self.data.allowOffsets
	if allowHoloAPI and (self.data.unrestrictedOffsets or DEBUG_WORLDMODE) then
		allowHoloAPI = {
			maxOffset = math.huge,
			maxScale = math.huge
		}
	end

	local allowSetResolution
	if self.data.dynamicResolution then
		allowSetResolution = true
	else
		local maxSide = math.max(self.width, self.height)
		allowSetResolution = {
			maxPixels = self.width * self.height,
			maxWidth = maxSide,
			maxHeight = maxSide
		}
	end

	self.api, self.internalApi = canvasAPI.createScriptableApi(self.width, self.height, self.dataTunnel, function ()
        self.lastComputer = sc.lastComputer
    end, {
        getRealBuffer = function(...)
            if not self.canvas then return end
            return self.canvas.getRealBuffer(...)
        end,
        getNewBuffer = function(...)
            if not self.canvas then return end
            return self.canvas.getNewBuffer(...)
        end
    }, (self.data.glass or self.data.unlockGlass) and canvasAPI.materialList or canvasAPI.materialListWithoutGlass, self.data.glass and 0 or 1, allowHoloAPI, allowSetResolution)
	
	self.api.noCameraEncode = true
    self._flush = self.api.flush
    self._forceFlush = self.api.forceFlush

    function self.api.flush()
        self.flushCallFlag = true
    end
    self.api.update = self.api.flush

    function self.api.forceFlush()
        self.flushCallFlag = true
        self.flushCallForce = true
    end

	self.touchscreen = canvasAPI.addTouch(self.api, self.dataTunnel)

	self.api.isAllow = function()
		return self:isAllow()
	end

    self.api.getAudience = function()
        if self._getAudienceCount then
            return self._getAudienceCount()
        end
        return 0
    end

    if not directList then
        directList = {}
        for name, obj in pairs(self.api) do
            if type(obj) == "function" and name ~= "flush" and name ~= "forceFlush" then
                directList[name] = true
            end
        end
    end

	self.interactable.publicData = {
		sc_component = {
			type = AnyDisplay.componentType,
			api = self.api,
            directList = directList
		}
	}

    sc.componentsBackend[self.api] = self
end

local rates = {1, 2, 4, 6, 8, 10}
local bigSize2 = 256 * 256
local bigSize1 = 128 * 128
function AnyDisplay:server_onFixedUpdate()
    local computerConnected = sm.scomputers.isComputerConnected(self.interactable)
    if not computerConnected and self.sv_oldComputerConnected then
        self.internalApi.setForceFrame()
    end
    self.sv_oldComputerConnected = computerConnected
    
    if self.flushCallFlag then
        if self.flushCallForce then
            self._forceFlush()
        else
            self._flush()
        end
        self.flushCallFlag = nil
        self.flushCallForce = nil
    end

    local lagScore
    if self._getLagDetector then
        lagScore = self._getLagDetector()
    end

	local ctick = sm.game.getCurrentTick()
    if sc.restrictions.screenRate < 0 then
        if lagScore then
            local mathRateIndex = 1
            if lagScore > 8 then
                mathRateIndex = 5
            elseif lagScore > 6 then
                mathRateIndex = 4
            elseif lagScore > 4 then
                mathRateIndex = 3
            elseif lagScore > 2 then
                mathRateIndex = 2
            end
            if sc.restrictions.screenRate == -2 then
                mathRateIndex = mathRateIndex + 1
            end
            local newRate = rates[mathRateIndex] or 1
            if self.mulSize >= bigSize2 then
                if newRate < 4 then
                    newRate = 4
                end
            elseif self.mulSize >= bigSize1 then
                if newRate < 2 then
                    newRate = 2
                end
            end
            if self.allowDownRate or not self.mathRate or newRate > self.mathRate then
                self.allowDownRate = nil
                self.mathRate = newRate
            end
        elseif not self.mathRate then
            self.mathRate = 1
        end
        if ctick % self.mathRate == 0 then
            self.oldMathRate = self.mathRate
            self.allow_send = true
        elseif self.mathRate ~= self.oldMathRate then
            self.oldMathRate = self.mathRate
            self.allow_send = true
        end
    elseif ctick % sc.restrictions.screenRate == 0 then
        self.mathRate = nil
		self.allow_send = true
	end

    if ctick % (40 * 4) == 0 then
        self.tryPacket = nil
    end

    if ctick % 40 == 0 then
        self.allowDownRate = true
    end

    if self.lastComputer and self.lastComputer.lagScore and lagScore and type(sc.restrictions.lagDetector) == "number" then
        self.lastComputer.lagScore = self.lastComputer.lagScore + (lagScore * sc.restrictions.lagDetector)
    end

    self.dataTunnel.scriptableApi_update()

	if self:isAllow() then
		if self.allow_send then
			if self.dataTunnel.dataUpdated then
				if self.dataTunnel.resolutionChanged then
					self:sv_canvasRequest()
					self.dataTunnel.resolutionChanged = nil
				end

				self.network:sendToClients("cl_dataTunnel", canvasAPI.minimizeDataTunnel(self.dataTunnel))
				self.allow_send = nil
                self.dataTunnel.dataUpdated = nil
                self.dataTunnel.display_reset = nil
			end
	
			if self.dataTunnel.display_flush then
                sendStack(self, "cl_pushStack", self.dataTunnel.display_stack, self.dataTunnel.display_forceFlush, self.dataTunnel.display_forceForceFlush)
				
				self.dataTunnel.display_flush()
				self.dataTunnel.display_stack = nil
				self.dataTunnel.display_flush = nil
                self.dataTunnel.display_forceFlush = nil
                self.dataTunnel.display_forceForceFlush = nil
				self.allow_send = nil
			end
		end
	elseif self.dataTunnel.display_flush then
        self.dataTunnel.display_flush()
        self.dataTunnel.display_stack = nil
        self.dataTunnel.display_flush = nil
        self.dataTunnel.display_forceFlush = nil
        self.dataTunnel.display_forceForceFlush = nil
	end
end

function AnyDisplay:sv_dataRequest()
    self.tryPacket = nil
    self.dataTunnel.dataUpdated = true
    self.dataTunnel.display_forceFlush = true
    self.dataTunnel.display_forceForceFlush = true
end

function AnyDisplay:sv_recvPress(data)
	self.touchscreen(data)
end

function AnyDisplay:sv_canvasRequest(_, caller)
	self.width = self.api.getWidth()
	self.height = self.api.getHeight()
	self.mulSize = self.width * self.height

	local data = {
		width = self.width,
		height = self.height
	}

	if caller then
		self.network:sendToClient(caller, "cl_canvasResponse", data)
	else
		self.network:sendToClients("cl_canvasResponse", data)
	end
end

--------------------------------------- CLIENT

function AnyDisplay:client_onCreate()
	local material = canvasAPI.material.classic
	local rotate
	local ypos = 0
	local zpos = 0.12
	if self.data then
		if self.data.glass then
			material = canvasAPI.material.glass
		end

		if self.data.zpos then
			zpos = self.data.zpos
		end

		if self.data.offset then
			ypos = -(self.data.offset / 4)
		end

		if self.data.rotate then
			rotate = true
			ypos = -ypos
		end
	end

    if self.data.flat then
        zpos = -0.1025
    elseif self.data.ultra_flat then
        zpos = -0.124
    end

	self.width = self.data.x
	self.height = self.data.y
	self.defaultWidth = self.width
	self.defaultHeight = self.height
    local rot
	if self.data.altRotateMode then
		rot = sm.vec3.new(0, -90, -90)
	else
		rot = sm.vec3.new(0, -90, (not rotate) and 180 or 0)
	end
    local pos = sm.vec3.new(0, ypos, zpos)
    if self.data.addRot then
        rot = rot + self.data.addRot
    end
    if self.data.addPos then
        pos = pos + self.data.addPos
    end
	--self.canvas = (canvasAPI.createBetterCanvas or canvasAPI.createCanvas)(self.interactable, self.width, self.height, self.pixelScale, pos, sm.quat.fromEuler(rot), material)
    if self.data.autoV then
        local boundingBox = self.shape:getBoundingBox()
        local boxSizeX = self.data.fakeZ or boundingBox.z * 4
        local boxSizeY = self.data.fakeY or boundingBox.y * 4
        local borderSizeX = 0.2
        local borderSizeY = 0.2
        if (boxSizeX <= 3 or boxSizeY == 1) and not (boxSizeX == 3 and boxSizeY == 2) then
            borderSizeX = 0.1
            borderSizeY = 0.1
        end
        if self.data.ultra_flat then
            borderSizeX = 0
            borderSizeY = 0
        end

        local pixelScaleX = (boxSizeX - borderSizeX) / self.width / 4
        local pixelScaleY = (boxSizeY - borderSizeY) / self.height / 4

        if allowDistortGeometry then
            self.pixelScale = sm.vec3.new(pixelScaleX, pixelScaleY, 0.00025)
        else
            local pixelScaleXY
            if self.data.use_min or (self.data.ultra_flat_min and self.data.ultra_flat) then
                pixelScaleXY = math.min(pixelScaleX, pixelScaleY)
            else
                pixelScaleXY = math.max(pixelScaleX, pixelScaleY)
            end
            self.pixelScale = sm.vec3.new(pixelScaleXY, pixelScaleXY, 0.00025)
        end

        self.pixelScaleX = self.pixelScale.x / PIXEL_SCALE
        self.pixelScaleY = self.pixelScale.y / PIXEL_SCALE
    elseif self.data.sizeX and not self.data.displayIgnoreSize then
        local pixelScaleX = self.data.sizeX / self.width
        local pixelScaleY = self.data.sizeY / self.height

        self.pixelScale = sm.vec3.new(pixelScaleX, pixelScaleY, 0.00025)
        self.pixelScaleX = self.pixelScale.x / PIXEL_SCALE
        self.pixelScaleY = self.pixelScale.y / PIXEL_SCALE
    else
        self.pixelScale = _debug_overwriteScale or self.data.v
        if self.data.div then
            self.pixelScale = self.pixelScale / self.width
        end
        self.pixelScaleX = self.pixelScale
        self.pixelScaleY = self.pixelScale
    end

	local canvasAttachObject
	if self.data.worldMode or DEBUG_WORLDMODE then
		canvasAttachObject = nil
	else
		canvasAttachObject = self.interactable
	end
    self.canvas = canvasAPI.createCanvas(canvasAttachObject, self.width, self.height, self.pixelScale, pos, rot, material, nil, self.data.altFromEuler, self.data.unrestrictedOffsets, not self.data.allowOffsets and not self.data.noConstParameters)
	self.network:sendToServer("sv_dataRequest")

	self.c_dataTunnel = {}
	self.dragging = {interact=false, tinker=false, interactLastPos={x=-1, y=-1}, tinkerLastPos={x=-1, y=-1}}

	self.network:sendToServer("sv_canvasRequest")
end

function AnyDisplay:client_onDestroy()
	self.canvas.destroy()
end

function AnyDisplay:cl_canvasResponse(data)
	if sm.isHost then return end
	self.width, self.height = data.width, data.height
end

local function defaultDisplayTouchDetect(self, detect, localPoint)
	local pixelScaleX = self.defaultWidth / self.width
	local pixelScaleY = self.defaultHeight / self.height
    if self.data.altTouchMode then
        if localPoint and localPoint.x > 0 then
            local pointX = math.floor(self.width / 2 - localPoint.z / (PIXEL_SCALE * self.pixelScaleX * pixelScaleX))
            local pointY = math.floor(self.height / 2 + localPoint.y / (PIXEL_SCALE * self.pixelScaleY * pixelScaleY))
        
            return detect(pointX, pointY)
        end
    else
        if localPoint and localPoint.x < 0 then
            local localPoint = sm.vec3.new(0, localPoint.y, localPoint.z)
    
            local pointX = math.floor(self.width / 2 - localPoint.z / (PIXEL_SCALE * self.pixelScaleX * pixelScaleX))
            local pointY = math.floor(self.height / 2 + localPoint.y / (PIXEL_SCALE * self.pixelScaleY * pixelScaleY))
        
            return detect(pointX, pointY)
        end
    end

    return false
end

function AnyDisplay:cl_onClick(type, action, localPoint) -- type - 1:interact|2:tinker (e.g 1 or 2), action - pressed, released, drag
    if self.data and self.data.noTouch then
        return
    end

    local function detect(pointX, pointY)
        pointX = math.floor(pointX + 0.5)
        pointY = math.floor(pointY + 0.5)

        if pointX >= 0 and pointX < self.width and pointY >= 0 and pointY < self.height then
            if action == "drag" then
                local t = type == 1 and self.dragging.interactLastPos or self.dragging.tinkerLastPos

                if t.x ~= -1 then
                    if t.x == pointX and t.y == pointY then 
                        return
                    else
                        t.x = pointX
                        t.y = pointY
                    end
                else
                    t.x = pointX
                    t.y = pointY
                    return
                end
            end

            local reverseX, reverseY, changeXY
            if self.c_dataTunnel.rotation == 1 then
                changeXY = true
                reverseX = true
            elseif self.c_dataTunnel.rotation == 2 then
                reverseX = true
                reverseY = true
            elseif self.c_dataTunnel.rotation == 3 then
                changeXY = true
                reverseY = true
            end
            if reverseX then
                pointX = self.width - pointX - 1
            end
            if reverseY then
                pointY = self.height - pointY - 1
            end
            if changeXY then
                pointX, pointY = pointY, pointX
            end

            --print("touch", pointX, pointY)
            self.lastPointX, self.lastPointY = pointX, pointY
            self.network:sendToServer("sv_recvPress", {pointX, pointY, action, type, sm.localPlayer.getPlayer().name})
        end
    end

    local localReg = self.altReg or function (ldetect, localPoint)
        defaultDisplayTouchDetect(self, ldetect, localPoint)
    end
    
    local function release(player)
        if self.lastPointX then
            self.network:sendToServer("sv_recvPress", {self.lastPointX or -1, self.lastPointY or -1, "released", type, player.name})
            self.lastPointX, self.lastPointY = nil, nil
            self.dragging.interact = false
            self.dragging.tinker = false
        end
    end

    if localPoint then
        localReg(detect, localPoint)
    elseif self.shape then
        local player = sm.localPlayer.getPlayer()
        local succ, res = sm.localPlayer.getRaycast((sc.restrictions and sc.restrictions.rend) or RENDER_DISTANCE)
        local shape = res:getShape()
        if succ and shape and (shape.id == self.shape.id or shape.uuid == AnyDisplay.stretchable_core_uuid or shape.uuid == AnyDisplay.stretchable_part_uuid) then
            local shape = self.shape
            local localPoint = shape:transformPoint(res.pointWorld)
            if self:cl_touchCheck(nil, nil, nil, succ, res) then
                localReg(detect, localPoint, res)
            else
                release(player)
            end
        else
            release(player)
        end
    elseif self.tablet_posX and self.tablet_posY then
        detect(self.tablet_posX, self.tablet_posY)
    end
end

function AnyDisplay:cl_touchCheck(type, action, localPoint, _succ, _res)
    if self.data and self.data.noTouch then
        return false
    end

    if self.altReg then
        return true
    end

    local function detect(pointX, pointY)
        pointX = math.floor(pointX + 0.5)
        pointY = math.floor(pointY + 0.5)

        if pointX >= 0 and pointX < self.width and pointY >= 0 and pointY < self.height then
            return true
        end
        return false
    end

    local function localReg(ldetect, localPoint)
        return defaultDisplayTouchDetect(self, ldetect, localPoint)
    end
    
    if localPoint then
        return localReg(detect, localPoint)
    elseif self.shape then
        local succ, res
        if _succ then
            succ, res = _succ, _res
        else
            succ, res = sm.localPlayer.getRaycast((sc.restrictions and sc.restrictions.rend) or RENDER_DISTANCE)
        end
        local shape = res:getShape()
        if succ and shape and shape.id == self.shape.id then
            local shape = self.shape
            local localPoint = shape:transformPoint(res.pointWorld)
            return localReg(detect, localPoint, res)
        end
    elseif self.tablet_posX and self.tablet_posY then
        return true
    end

    return false
end

function AnyDisplay:client_onFixedUpdate()
    if not self.canvas then
        return
    end

    local computerConnected = sm.scomputers.isComputerConnected(self.interactable)
    if not computerConnected and self.oldComputerConnected then
        self.canvas.pushStack({canvasAPI.draw.clear, 0})
        self.canvas.flush()
    end
    self.oldComputerConnected = computerConnected
    
    self.disableState = not self:isAllow()
    if sm.isHost and not sc.restrictions.hostrender then
        self.disableState = true
    end
	self.canvas.disable(self.disableState)
	if self.data.alwaysRenderAtDistance or DEBUG_WORLDMODE then
		self.canvas.setRenderDistance(math.huge)
	else
		if sc.restrictions then
			if self.c_dataTunnel.renderAtDistance and sc.restrictions.allowDist then
				self.canvas.setRenderDistance(128)
			else
				self.canvas.setRenderDistance((sc.restrictions and sc.restrictions.rend) or RENDER_DISTANCE)
			end
		else
			self.canvas.setRenderDistance(RENDER_DISTANCE)
		end
	end
	self.canvas.update()
    self:canvasService(self.canvas.isRendering())

	if self.dragging.interact then
		self:cl_onClick(1, "drag")
	elseif self.dragging.tinker then
		self:cl_onClick(2, "drag")
	end

	if self.character then
        if self.tablet_left ~= self.old_tablet_left then
            self:client_onInteract(nil, not not self.tablet_left)
        end
    
        if self.tablet_right ~= self.old_tablet_right then
            self:client_onTinker(nil, not not self.tablet_right)
        end

        self.old_tablet_left = self.tablet_left
        self.old_tablet_right = self.tablet_right
    else
        if _G.stylus_left ~= self.old_stylus_left then
            self:client_onInteract(nil, not not _G.stylus_left)
        end
    
        if _G.stylus_right ~= self.old_stylus_right then
            self:client_onTinker(nil, not not _G.stylus_right)
        end

        self.old_stylus_left = _G.stylus_left
        self.old_stylus_right = _G.stylus_right
    end
end

function AnyDisplay:client_onInteract(character, state)
    self.dragging.interact = state
    if state then
        local t = self.dragging.interactLastPos
        t.x = -1
        t.y = -1
    end
    self:cl_onClick(1, state and "pressed" or "released")
end

function AnyDisplay:client_onTinker(character, state)
    self.dragging.tinker = state
    if state then
        local t = self.dragging.tinkerLastPos
        t.x = -1
        t.y = -1
    end
    self:cl_onClick(2, state and "pressed" or "released")
end

function AnyDisplay:client_canInteract(character)
	if self.data and self.data.noTouch then
        return false
    end

	local can = (not not self.c_dataTunnel.clicksAllowed) and self:cl_touchCheck()
    if can then
        sm.gui.setInteractionText("", "<p textShadow='false' bg='gui_keybinds_bg_orange' spacing='9' color='#65430B'>" .. sm.gui.getKeyBinding("Use") .. "</p> Primary Touch", "")
        sm.gui.setInteractionText("", "<p textShadow='false' bg='gui_keybinds_bg_orange' spacing='9' color='#65430B'>" .. sm.gui.getKeyBinding("Tinker") .. "</p> Secondary Touch", "")
    end
    return can
end

function AnyDisplay:client_canTinker(character)
	if self.data and self.data.noTouch then
        return false
    end

    return (not not self.c_dataTunnel.clicksAllowed) and self:cl_touchCheck()
end

function AnyDisplay:cl_pushStack(stack)
    if self.disableState or not sm.scomputers.isComputerConnected(self.interactable) then
        return
    end
    
    if self.sendedData_cl_pushStack then
        if self.sendedData_cl_pushStack.force or needPushStack(self.canvas, self.c_dataTunnel, sc.deltaTime) then
            local startTime = os.clock()
            self.canvas.pushStack(self.sendedData_cl_pushStack)
            self.canvas.flush(self.sendedData_cl_pushStack.forceForce)
            self.sendedData_cl_pushStack = nil
            self:lagDetector(os.clock() - startTime, sc.clockLagMul)
        end
        return
    elseif self.stack then
		for _, action in ipairs(stack) do
			table.insert(self.stack, action)
		end
	else
		self.stack = stack
	end

	if stack.flush and (stack.force or needPushStack(self.canvas, self.c_dataTunnel, sc.deltaTime)) then
        local startTime = os.clock()
		self.canvas.pushStack(self.stack)
		self.canvas.flush(stack.forceForce)
		self.stack = nil
        self:lagDetector(os.clock() - startTime, sc.clockLagMul)
	end
end

function AnyDisplay:cl_dataTunnel(data)
	self.c_dataTunnel = data
    if data.display_reset then
        self.canvas.drawerReset()
    end
    self.canvas.pushDataTunnelParams(data)
end