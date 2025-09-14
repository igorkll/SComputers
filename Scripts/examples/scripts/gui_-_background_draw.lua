--example for display 128x128

local display = getComponent("display")
local camera = getComponent("camera")

local width, height = display.getSize()
display.reset()
display.clearClicks()
display.setClicksAllowed(true)
display.clear()
display.flush()

local gui = require("gui").new(display)
local scene = gui:createScene(function()
    camera.drawAdvanced(display, true)
end)

local rgbButtons = {
    init = function(self, partsX, partsY)
        self.colors = {}
        self.partsX = partsX
        self.partsY = partsY
        self.partSizeX = math.floor((self.sizeX / partsX) + 0.5)
        self.partSizeY = math.floor((self.sizeY / partsY) + 0.5)
        for ix = 0, partsX - 1 do
            self.colors[ix] = {}
            for iy = 0, partsY - 1 do
                self.colors[ix][iy] = 0
            end
        end
    end,
    drawer = function(self)
        self:clear(0x000000)
        for ix = 0, self.partsX - 1 do
            for iy = 0, self.partsY - 1 do
                local color
                local colorIdx = self.colors[ix][iy]
                if colorIdx == 0 then
                    color = 0xff0000
                elseif colorIdx == 1 then
                    color = 0x00ff00
                elseif colorIdx == 2 then
                    color = 0x0000ff
                end
                self.display.fillRect(self.x + (ix * self.partSizeX) + 1, self.y + (iy * self.partSizeY) + 1, self.partSizeX - 1, self.partSizeY - 1, color)
            end
        end
    end,
    handlerLocalPosition = true, --tells the library that you would like to get the click position relative to your element
    handler = function(self, x, y, action, button) -- if the object was clicked and then the scene switched, the method will be called with the parameters: self, -1, -1, "released", -1
        if action == "pressed" then
            self:togglePartIndex(math.floor(x / self.partSizeX), math.floor(y / self.partSizeY))
            self:update()
        end
    end,
    methods = { --here you can implement your own methods that the user of the component can call
        togglePartIndex = function(self, x, y)
            local colorIdx = self:getPartIndex(x, y)
            if not colorIdx then return end
            colorIdx = colorIdx + 1
            if colorIdx > 2 then
                colorIdx = 0
            end
            self:setPartIndex(x, y, colorIdx)
        end,
        setPartIndex = function(self, x, y, colorIdx)
            self.colors[x][y] = colorIdx
        end,
        getPartIndex = function(self, x, y)
            if not self.colors[x] then
                return
            end
            return self.colors[x][y]
        end
    }
}

local rgbButtons1 = scene:createCustom(2, 2, 29, 29, rgbButtons, 4, 4)

scene:select()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    gui:tick()
    gui:drawForce()
    display.flush()
end