--64x64 recommended

local display = getComponent("display")
display.reset()
display.clear()
display.setFont(require("fonts").lgc_5x5)

local width, height = display.getSize()
local logo = "DVD"
local logoSizeX, logoSizeY = display.calcTextBox(logo)

-- ball class
local ballClass = class()

function ballClass:init()
    self.x = math.random(0, width - logoSizeX)
    self.y = math.random(0, height - logoSizeY)
    self.dx = (math.random() - 0.5) * 2
    self.dy = (math.random() - 0.5) * 2
    self:randColor()
end

function ballClass:randColor()
    self.color = sm.color.new(math.random(), math.random(), math.random())
end

function ballClass:tick()
    self.x = self.x + self.dx
    self.y = self.y + self.dy
    if self.x <= 0 or self.x > width - logoSizeX then self.dx = -self.dx self:randColor() end
    if self.y <= 0 or self.y > height - logoSizeY then self.dy = -self.dy self:randColor() end
end

function ballClass:draw()
    display.drawText(self.x, self.y, logo, self.color)
end

-- create balls
local ball = ballClass()
ball:init()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    display.clear()
    ball:tick()
    ball:draw()
    display.flush()
end