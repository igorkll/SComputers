dofile("$CONTENT_DATA/Scripts/canvasAPI/canvas.lua")
test1 = class()

local function color(...)
    return canvasAPI.formatColorToSmallNumber(sm.color.new(...))
end

function test1:client_onCreate()
    self.canvas = canvasAPI.createCanvas(self.interactable, 64, 64)
    self.canvas.setRenderDistance(64)
    self.rotation = 0
end

function test1:client_onFixedUpdate()
	self.canvas.update()
	
    --------------------------------------- motion

    self.canvas.setOffset(sm.vec3.new(0, 2.5 + (math.sin(math.rad(sm.game.getCurrentTick())) / 8), 0))
    self.canvas.setCanvasRotation(sm.vec3.new(0, self.rotation, 0))
    self.rotation = self.rotation + 0.25
    if not self.canvas.isRendering() then return end

    --------------------------------------- random fill

    local stack = {}
    for i = 1, 64 do
		canvasAPI.pushData(stack, canvasAPI.draw.fill, math.random(0, self.canvas.sizeX - 1), math.random(0, self.canvas.sizeY - 1), math.random(0, 16), math.random(0, 16), color(math.random() / 3, math.random() / 3, 0))
    end

	canvasAPI.pushData(stack, canvasAPI.draw.rect, 0, 0, self.canvas.sizeX, self.canvas.sizeY, color(1, 1, 1), 1)
	canvasAPI.pushData(stack, canvasAPI.draw.set, 0, 0, color(0, 1, 0))
	canvasAPI.pushData(stack, canvasAPI.draw.set, self.canvas.sizeX - 1, 0, color(1, 0, 0))
	canvasAPI.pushData(stack, canvasAPI.draw.set, self.canvas.sizeX - 1, self.canvas.sizeY - 1, color(1, 1, 0))
	canvasAPI.pushData(stack, canvasAPI.draw.set, 0, self.canvas.sizeY - 1, color(0, 0, 1))
	canvasAPI.pushData(stack, canvasAPI.draw.set, 0, 1, color(0, 1, 1))
	canvasAPI.pushData(stack, canvasAPI.draw.set, 1, 0, color(0, 1, 1))

    --------------------------------------- pushing

    self.canvas.pushStack(stack)
    self.canvas.flush()
end

function test1:client_onDestroy()
    self.canvas.destroy()
end