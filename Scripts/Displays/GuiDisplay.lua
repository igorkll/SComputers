dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/Displays/modules/sendStack.lua")
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

    if not directList then
        directList = {}
        for name, obj in pairs(self.api) do
            if type(obj) == "function" and name ~= "flush" and name ~= "forceFlush" and name ~= "update" then
                directList[name] = true
            end
        end
    end

	self.interactable.publicData = {
		sc_component = {
			type = GuiDisplay.componentType,
			api = self.api,
            directList = directList
		}
	}
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

    self.dataTunnel.scriptableApi_update()

	if self:isAllow() then
        self.allow_send = true
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

function GuiDisplay:client_onCreate()
    self._old_res_x = self.data.x
    self._old_res_y = self.data.y

    self.canvasGUI = canvasGUI.createGuiCanvas(self.data.x, self.data.y, 500, 500, 25)

    self.drawer = canvasAPI.createDrawer(self.data.x, self.data.y, function(x, y, color)
        local fColor = sc.formatColor(color)
        self.canvasGUI.setPixel(x, y, fColor.r .. " " .. fColor.g .. " " .. fColor.b)
    end, nil, nil, nil, nil, nil, true)
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
    end
    self.oldComputerConnected = computerConnected

	self.canvasGUI.update()
    self:canvasService(self.canvasGUI.isRendering())

	if self.dragging.interact then
		--self:cl_onClick(1, "drag")
	elseif self.dragging.tinker then
		--self:cl_onClick(2, "drag")
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
		self.stack = nil
        self:lagDetector(os.clock() - startTime, sc.clockLagMul)
	end
end

function GuiDisplay:cl_dataTunnel(data)
	self.c_dataTunnel = data
    self.drawer.pushDataTunnelParams(data)
    if data.res_x ~= self._old_res_x or data.res_y ~= self._old_res_y then
        self.drawer.setDrawerResolution(data.res_x, data.res_y)
        self._old_res_x = data.res_x
        self._old_res_y = data.res_y
    end
end
