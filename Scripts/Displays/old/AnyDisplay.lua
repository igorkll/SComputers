--dofile "$CONTENT_DATA/Scripts/Displays/DisplayBase.lua"
--dofile "$CONTENT_DATA/Scripts/Displays/old/DisplayBase.lua"

AnyDisplay = class(nil)

AnyDisplay.maxParentCount = 1
AnyDisplay.maxChildCount = 0
AnyDisplay.connectionInput = sm.interactable.connectionType.composite
AnyDisplay.colorNormal = sm.color.new(0xbbbb1aff)
AnyDisplay.colorHighlight = sm.color.new(0xecec1fff)
AnyDisplay.componentType = "display"


-- SERVER --


function AnyDisplay.server_onCreate(self)
	self.display = self.display or sc.display.createDisplay(self, self.data.x, self.data.y, self.data.v)
	sc.display.server_init(self.display)
end

function AnyDisplay.server_onDestroy(self)
	sc.display.server_destroy(self.display)
end

function AnyDisplay.server_onFixedUpdate(self, dt)
	sc.display.server_update(self.display, dt)
end

function AnyDisplay.server_recvPress(self, p, caller)
	sc.display.server_recvPress(self.display, p, caller)
end

function AnyDisplay.server_onDataRequired(self, client)
	sc.display.server_onDataRequired(self.display, client)
end

-- CLIENT --

function AnyDisplay.client_onReceiveDrawStack(self, stack)
	sc.display.client_drawStack(self.display, stack)
end

function AnyDisplay.client_onCreate(self)
	self.display = self.display or sc.display.createDisplay(self, self.data.x, self.data.y, self.data.v)
	sc.display.client_init(self.display)
end

function AnyDisplay.client_onDestroy(self)
	sc.display.client_destroy(self.display)
end

function AnyDisplay.client_onFixedUpdate(self, dt)
	sc.display.client_update(self.display, dt)
end

function AnyDisplay.client_onInteract(self, character, state)
	sc.display.client_onInteract(self.display, character, state)
end

function AnyDisplay:client_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
	sc.display.client_onClick(self.display, 1, "pressed", normal)
	sc.display.client_onClick(self.display, 1, "released", normal)
end

function AnyDisplay.client_canInteract(self, character)
	return sc.display.client_canInteract(self.display, character)
end

function AnyDisplay.client_canTinker(self, character)
	return sc.display.client_canTinker(self.display, character)
end

function AnyDisplay.client_onTinker(self, character, state)
	sc.display.client_onTinker(self.display, character, state)
end

function AnyDisplay.client_onDataResponse(self, data)
	sc.display.client_onDataResponse(self.display, data)
end