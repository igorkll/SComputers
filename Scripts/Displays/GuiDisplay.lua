dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/Displays/modules/sendStack.lua")
dofile("$CONTENT_DATA/Scripts/Displays/modules/lagCheck.lua")
GuiDisplay = class(canvasAPI.canvasService)
GuiDisplay.maxParentCount = 1
GuiDisplay.maxChildCount = 0
GuiDisplay.connectionInput = sm.interactable.connectionType.composite
GuiDisplay.colorNormal = sm.color.new(0xbbbb1aff)
GuiDisplay.colorHighlight = sm.color.new(0xecec1fff)
GuiDisplay.componentType = "display"

local stackChecksum = canvasAPI.stackChecksum
local needPushStack = canvasAPI.needPushStack
local sendStack = displays_sendStack
local lagCheck = displays_lagCheck

function GuiDisplay:server_onCreate()
    self.lastLagScore = 0
	self.dataTunnel = {}
	self.width = self.data.x
	self.height = self.data.y
    self.mulSize = self.width * self.height
	local allowHoloAPI = false

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
            if not self.drawer then return end
            return self.drawer.getRealBuffer(...)
        end,
        getNewBuffer = function(...)
            if not self.drawer then return end
            return self.drawer.getNewBuffer(...)
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

    local directList = {}
    for name, obj in pairs(self.api) do
        if type(obj) == "function" and name ~= "flush" and name ~= "forceFlush" and name ~= "update" then
            directList[name] = true
        end
    end

	self.interactable.publicData = {
		sc_component = {
			type = GuiDisplay.componentType,
			api = self.api,
            directList = directList
		}
	}

    sc.componentsBackend[self.api] = self
end

function GuiDisplay:server_onFixedUpdate()
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

    lagCheck(self)

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

function GuiDisplay:sv_dataRequest()
    self.tryPacket = nil
    self.dataTunnel.dataUpdated = true
    self.dataTunnel.display_forceFlush = true
    self.dataTunnel.display_forceForceFlush = true
end

function GuiDisplay:sv_recvPress(data)
	self.touchscreen(data)
end

function GuiDisplay:sv_canvasRequest(_, caller)
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

function GuiDisplay:isAllow()
    if not sc.restrictions then return true end
    return self.width * self.height <= (sc.restrictions.maxDisplays * sc.restrictions.maxDisplays)
end

---------------------------------------------

local formatColorToSmallNumber = canvasAPI.formatColorToSmallNumber

function GuiDisplay:client_onCreate()
    self._old_res_x = self.data.x
    self._old_res_y = self.data.y

    self.canvasGUI = canvasGUI.createGuiCanvas(self.data.x, self.data.y, 500, 500, 25, "Gui Display")

    self.drawer = canvasAPI.createDrawer(self.data.x, self.data.y, function(x, y, color, background)
        local fColor = formatColorToSmallNumber(color)
        local fBackground = formatColorToSmallNumber(background)
        if fBackground ~= self.oldBackground then
            self.canvasGUI.clear(fBackground)
            self.oldBackground = fBackground
        end
        self.canvasGUI.setPixel(x, y, fColor)
    end, nil, nil, nil, nil, nil, true)

    self.network:sendToServer("sv_dataRequest")

	self.c_dataTunnel = {}
	self.dragging = {interact=false, tinker=false, interactLastPos={x=-1, y=-1}, tinkerLastPos={x=-1, y=-1}}

	self.network:sendToServer("sv_canvasRequest")
end

function GuiDisplay:client_onInteract(_, state)
    if state then
        self.canvasGUI.open()
    end
end

function GuiDisplay:client_onFixedUpdate()
    local computerConnected = sm.scomputers.isComputerConnected(self.interactable)
    if not computerConnected and self.oldComputerConnected then
        self.drawer.pushStack({canvasAPI.draw.clear, 0})
        self.drawer.flush()
        self.canvasGUI.flush()
    end
    self.oldComputerConnected = computerConnected

	self.canvasGUI.update()
    self:canvasService(self.canvasGUI.isRendering())

    local state1 = sc.localInputState.mouse_l
    if state1 ~= self.mouse_l then
        self:cl_clk1(state1)
    end
    self.mouse_l = state1

    local state2 = sc.localInputState.mouse_r
    if state2 ~= self.mouse_r then
        self:cl_clk2(state2)
    end
    self.mouse_r = state2

	if self.dragging.interact then
		self:cl_onClick(1, "drag")
	elseif self.dragging.tinker then
		self:cl_onClick(2, "drag")
	end
end

function GuiDisplay:client_onDestroy()
    self.canvasGUI.destroy()
end

function GuiDisplay:cl_canvasResponse(data)
	if sm.isHost then return end
	self.width, self.height = data.width, data.height
end

function GuiDisplay:cl_pushStack(stack)
    if self.disableState or not sm.scomputers.isComputerConnected(self.interactable) then
        return
    end
    
    if self.sendedData_cl_pushStack then
        if self.sendedData_cl_pushStack.force or needPushStack(self.canvasGUI, self.c_dataTunnel, sc.deltaTime) then
            local startTime = os.clock()
            self.drawer.pushStack(self.sendedData_cl_pushStack)
            self.drawer.flush(self.sendedData_cl_pushStack.forceForce)
            self.canvasGUI.flush()
            self.sendedData_cl_pushStack = nil
            self:lagDetector(os.clock() - startTime, sc.clockLagMul)
        end
        self.sendedData_cl_pushStack = nil
        return
    --elseif self.stack then
    elseif self.stack and self.stack[1][1] ~= canvasAPI.draw.clear then
		for _, action in ipairs(stack) do
			table.insert(self.stack, action)
		end
	else
		self.stack = stack
	end

	if stack.flush and (stack.force or needPushStack(self.canvasGUI, self.c_dataTunnel, sc.deltaTime)) then
        local startTime = os.clock()
		self.drawer.pushStack(self.stack)
		self.drawer.flush(stack.forceForce)
        self.canvasGUI.flush()
		self.stack = nil
        self:lagDetector(os.clock() - startTime, sc.clockLagMul)
	end
end

function GuiDisplay:cl_dataTunnel(data)
	self.c_dataTunnel = data
    self.drawer.pushDataTunnelParams(data)
    if data.res_x ~= self._old_res_x or data.res_y ~= self._old_res_y then
        self.drawer.setDrawerResolution(data.res_x, data.res_y)
        self.canvasGUI.resize(data.res_x, data.res_y)
        self._old_res_x = data.res_x
        self._old_res_y = data.res_y
    end
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

function GuiDisplay:cl_onClick(type, action) -- type - 1:interact|2:tinker (e.g 1 or 2), action - pressed, released, drag
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

    detect(5, 5)
end

function GuiDisplay:cl_clk1(state)
    self.dragging.interact = state
    if state then
        local t = self.dragging.interactLastPos
        t.x = -1
        t.y = -1
    end
    self:cl_onClick(1, state and "pressed" or "released")
end

function GuiDisplay:cl_clk2(state)
    self.dragging.tinker = state
    if state then
        local t = self.dragging.tinkerLastPos
        t.x = -1
        t.y = -1
    end
    self:cl_onClick(2, state and "pressed" or "released")
end
