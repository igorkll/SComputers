--the example was created for a 64x64 display
display = getComponent("display")
camera = getComponents("camera")[1] --camera is optional
display.reset()
display.clearClicks()
display.setClicksAllowed(true)

gui = require("gui").new(display)
image = require("image")

-------------------------

function buttonDrawer(self) --custom style for button
    local bg, fg = self.bg, self.fg
    if self.state then
        bg, fg = self.bg_press, self.fg_press
    end
    self.display.fillRect(self.x, self.y, self.sizeX, self.sizeY, bg)
    self.display.drawRect(self.x, self.y, self.sizeX, self.sizeY, fg)

    local x = math.floor(((self.x + (self.sizeX / 2)) - (((self.display.getFontWidth() + 1) * #self.text) / 2)) + 0.5)
    local y = math.floor(((self.y + (self.sizeY / 2)) - (self.display.getFontHeight() / 2)) + 0.5)
    self.display.drawText(x, y - 1, self.text, fg)
end

local oldPrint = print
function print(...) --to avoid failures when the print to chat function is disabled
    pcall(print, ...)
end

------------------------- scene 1
scene = gui:createScene(sm.color.new(0, 0, 1))
button1 = scene:createButton(1, 1, 40, 8, false, "button")
button2 = scene:createButton(1, 9, 40, 8, true, "toggle")
selectScene2 = scene:createButton(1, 17, 40, 8, false, "scene2")
selectScene2:setCustomStyle(buttonDrawer)

------------------------- scene 2
scene2 = gui:createScene(sm.color.new(0, 1, 1))
label = scene2:createLabel(1, 1, 40, 8, "label")
text = scene2:createText(1, 10, "text")
selectScene1 = scene2:createButton(1, 17, 40, 8, false, "scene1")
img = image.new(32, 32, sm.color.new(0, 0, 0))
gimg = scene2:createImage(display.getWidth() - 32, display.getHeight() - 32, img)
selectScene1:setCustomStyle(buttonDrawer)

customObjClass = {
    init = function(self, color)
        self.color = color or 0xffffff
    end,
    drawer = function(self)
        self.display.fillCircle(self.x + (self.sizeX / 2), self.y + (self.sizeY / 2), self.sizeX / 2, self.color)
    end,
    handler = function(self, x, y, action, button) -- if the object was clicked and then the scene switched, the method will be called with the parameters: self, -1, -1, "released", -1
        if action == "pressed" then
            self:lolz()
        end
    end,
    methods = {
        lolz = function(self) --can be called from outside
            self.color = sm.color.new(math.random(), math.random(), math.random())
            self:update()
        end
    }
}

customObj = scene2:createCustom(0, display.getHeight() - 32, 32, 32, customObjClass, 0xff00ff)

-------------------------

scene:select()
tick = 0

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    gui:tick()

    if scene:isSelected() then
        if button1:isPress() then
            print("button pressed")
        end
        if button1:isReleased() then
            print("button released")
        end
        if button2:isPress() then
            print("toggle true")
        end
        if button2:isReleased() then
            print("toggle false")
        end
        if selectScene2:isPress() then
            print("scene 2")
            scene2:select()
        end
    end

    if scene2:isSelected() then
        if selectScene1:isPress() then
            print("scene 1")
            scene:select()
        end

        if camera then
            img:fromCamera(camera, "drawDepth", sm.color.new(0, 1, 0))
            gimg:update()
        end
        text:clear()
        text:setText(tostring(tick))
        text:update()

        label:setBgColor(sm.color.new(math.random(), math.random(), math.random()))
        label:update()
    end

    tick = tick + 1
    if tick % 40 == 0 then
        customObj:lolz()
    end

    if gui:needFlush() then
        gui:draw()
        display.flush()
    end
end