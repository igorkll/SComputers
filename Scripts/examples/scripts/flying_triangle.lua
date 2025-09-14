local display = getComponent("display")
display.reset()
display.clear()

local width, height = display.getSize()
local minSide = math.min(width, height)
local ballRadius = math.floor((minSide / 32) + 0.5)
local ballSpeed = math.floor((minSide / 64) + 0.5)

-- ball class
local ballClass = class()

function ballClass:init()
    self.x = math.random(ballRadius, width - 1 - ballRadius)
    self.y = math.random(ballRadius, height - 1 - ballRadius)
    self.dx = (math.random() - 0.5) * ballSpeed
    self.dy = (math.random() - 0.5) * ballSpeed
    self.color = sm.color.new(math.random(), math.random(), math.random())
end

function ballClass:tick()
    self.x = self.x + self.dx
    self.y = self.y + self.dy
    if self.x < ballRadius or self.x > width - 1 - ballRadius then self.dx = -self.dx end
    if self.y < ballRadius or self.y > height - 1 - ballRadius then self.dy = -self.dy end
end

-- create balls
local ball1 = ballClass()
local ball2 = ballClass()
local ball3 = ballClass()
ball1:init()
ball2:init()
ball3:init()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    ball1:tick()
    ball2:tick()
    ball3:tick()

    display.clear()
    display.fillWidePoly(0xff0000, ballRadius * 2, true, ball1.x, ball1.y, ball2.x, ball2.y, ball3.x, ball3.y)
    display.flush()
end