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
            if type(obj) == "function" and name ~= "flush" and name ~= "forceFlush" and name ~= "update" then
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

function GuiDisplay:isAllow()
    if not sc.restrictions then return true end
    return self.width * self.height <= (sc.restrictions.maxDisplays * sc.restrictions.maxDisplays)
end

---------------------------------------------

function GuiDisplay:client_onCreate()
    self.canvasGUI = canvasGUI.createGuiCanvas(32, 32, 500, 500, 25)
end

function GuiDisplay:client_onInteract(_, state)
    if state then
        self.canvasGUI:open()
    end
end

function GuiDisplay:client_onFixedUpdate(delta)
    self.canvasGUI:update()
    self:canvasService(self.canvasGUI.isRendering())
end

function GuiDisplay:client_onDestroy()
    self.canvasGUI:destroy()
end
