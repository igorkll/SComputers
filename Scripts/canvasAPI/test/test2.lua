dofile("$CONTENT_DATA/Scripts/canvasAPI/canvas.lua")
test2 = class()
test2.displaySize = 1
test2.displayPosition = sm.vec3.new(0, 0.25, 0.25)
test2.displayRotation = sm.vec3.new(-32, 0, 0)

function test2:client_onCreate()
    self.display = canvasAPI.createClientScriptableCanvas(self.interactable, 64, 64, -test2.displaySize / 64, test2.displayPosition, test2.displayRotation)
	self.display.setOptimizationLevel(16)
	--self.display.setFont(canvasAPI.fonts.lgc_5x5)

    self.width = self.display.getWidth()
    self.height = self.display.getHeight()
    self.perlinSize = (1 / self.width) * 5
end

function test2:client_onFixedUpdate()
	self.display.update()

    self.pos = (self.pos or 0) + 1
    if self.display.getAudience() > 0 then
        --self.display.clear()
        local pos = math.floor(self.pos)
        for ix = 0, self.width - 1 do
            for iy = 0, self.height - 1 do
                self.display.drawPixel(ix, iy, sm.color.new(sm.noise.perlinNoise2d((ix + pos) * self.perlinSize, iy * self.perlinSize, 0), 0, 0))
            end
        end
		self.display.drawText(1, 1, "HELLO, WORLD!")
        self.display.flush()
    end
end

function test2:client_onDestroy()
    self.display.destroy()
end