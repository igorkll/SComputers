function sc_reglib_objs()
local objs = {}
local gui = sc.lib_require("gui")
local image = sc.lib_require("image")

objs.textbox = { --legacy, use scene:createTextBox
    drawer = function(self)
        local fontX = self.display.getFontWidth()
        local fontY = self.display.getFontHeight()
        local text = self.args[1]
        local color = self.args[2]
        local centerText = self.args[3]
        local centerLines = self.args[4]
        if self.args[5] then
            self.display.fillRect(self.x, self.y, self.sizeX, self.sizeY, self.args[5])
        end

        local lines = {}
        for _, line in ipairs(strSplit(utf8, text, "\n")) do
            for _, line in ipairs(splitByMaxSizeWithTool(utf8, line, self.sizeX / (fontX + 1))) do
                table.insert(lines, line)
            end
        end

        local index = 0
        for _, line in ipairs(lines) do
            local len = utf8.len(line)
            local px, py
            if centerText then
                px = (self.x + (self.sizeX / 2)) - ((len * (fontX + 1)) / 2)
            else
                px = self.x
            end
            if centerLines then
                py = (self.y + (self.sizeY / 2) + (index * (fontY + 1))) - ((#lines * (fontY + 1)) / 2)
            else
                py = self.y + (index * (fontY + 1))
            end
            if py >= self.y and py + fontY < self.y + self.sizeY and px >= self.x and px + fontX < self.x + self.sizeX then
                self.display.drawText(px, py, line, color)
            end
            index = index + 1
        end
    end
}

objs.panel = { --legacy. use scene:createWindow
    drawer = function(self)
        self.display.fillRect(self.x, self.y, self.sizeX, self.sizeY, self.args[1] or 0xffffff)
    end
}

objs.camera = {
    init = function(self, camera, func, ...)
        self.camera = camera
        self.func = func or "drawAdvanced"
        self.args = {...}
    end,
    drawer = function(self)
        self:capture(true)
    end,
    methods = {
        capture = function(self, noUpdate)
            self.camera.setViewport(self.x, self.y, self.sizeX, self.sizeY)
            self.camera[self.func](self.display, unpack(self.args))
            if not noUpdate then
                self:update()
                self.needUpdate = false
            end
        end,
        setFov = function(self, fov)
            self.camera.setNonSquareFov(fov * (self.sizeX / self.sizeY), fov)
        end
    }
}

objs.bufferedCamera = {
    init = function(self, camera, func, ...)
        self.camera = camera
        self.func = func or "drawAdvanced"
        self.args = {...}
    end,
    drawer = function(self)
        self:capture(true)
    end,
    methods = {
        capture = function(self, noUpdate)
            if not self.buffer or self.bufferSizeX ~= self.sizeX or self.bufferSizeY ~= self.sizeY then
                self.buffer = image.new(self.sizeX, self.sizeY, sm.color.new(0, 0, 0))
                self.bufferSizeX = self.sizeX
                self.bufferSizeY = self.sizeY
            end

            self.buffer:fromCamera(self.camera, self.func, unpack(self.args))
            self.buffer:draw(self.display, self.x, self.y)
            
            if not noUpdate then
                self:update()
                self.needUpdate = false
            end
        end,
        setFov = function(self, fov)
            self.camera.setNonSquareFov(fov * (self.sizeX / self.sizeY), fov)
        end
    }
}

objs.context = {
    layerMode = gui.layerMode.topLayer,
    init = function(self, contextSettings)
        self.contextSettings = contextSettings
    end,
    drawer = function(self)
        self.display.fillRect(self.x, self.y, self.sizeX, self.sizeY, self.contextSettings.background)
    end,
    
}

objs.tabbar = {
    useWindow = true,
    init = function(self, background, verticle, buttonSize, offset, bg, fg, bg_press, fg_press)
        self.bg, self.fg, self.bg_press, self.fg_press = bg, fg, bg_press, fg_press
        self.list = {}
        self.buttons = {}
        self.verticle = verticle
        self.buttonSize = buttonSize
        self.offset = offset or 0

        if background then
            self:setColor(background)
        end

        if verticle then
            self:setDefaultSet(function(guiobject, previousElement)
                if previousElement then
                    guiobject:setDown(previousElement, self.offset)
                else
                    guiobject:setPosition(0, math.floor(self.offset / 2))
                end
            end)
        else
            self:setDefaultSet(function(guiobject, previousElement)
                if previousElement then
                    guiobject:setRight(previousElement, self.offset)
                else
                    guiobject:setPosition(math.floor(self.offset / 2), 0)
                end
            end)
        end
        
        for _, item in ipairs(self.list) do
            self:addButton(item[1], item[2])
        end
    end,
    methods = {
        setSelected = function(self, selected)
            checkArg(1, selected, "number")
            self.selected = selected
            for _, button in ipairs(self.buttons) do
                button:setState(false)
            end
            for _, item in ipairs(self.list) do
                item:setDisabled(true)
                item:setInvisible(true)
            end
            self.buttons[selected]:setState(true)
            if self.list[selected] then
                self.list[selected]:setDisabled(false)
                self.list[selected]:setInvisible(false)
            end
        end,
        getSelected = function(self)
            return self.selected
        end,
        addTab = function(self, title, object)
            table.insert(self.list, object)
            object:setDisabled(true)
            object:setInvisible(true)

            local button
            if self.verticle then
                button = self:createButton(nil, nil, nil, nil, true, title, self.bg, self.fg, self.bg_press, self.fg_press)
                
                local _autofunc = button.autofunc
                function button.autofunc(rself, previousElement, container)
                    _autofunc(rself, previousElement, container)
                    rself:setSize(self.sizeX, self.buttonSize or mathRound((self.sizeY / #self.list) - self.offset))
                end
            else
                button = self:createButton(nil, nil, nil, nil, true, title, self.bg, self.fg, self.bg_press, self.fg_press)

                local _autofunc = button.autofunc
                function button.autofunc(rself, previousElement, container)
                    _autofunc(rself, previousElement, container)
                    rself:setSize(self.buttonSize or mathRound((self.sizeX / #self.list) - self.offset), self.sizeY)
                end
            end

            table.insert(self.buttons, button)
            local index = #self.buttons

            function button.onToggle(state)
                if state then
                    self:setSelected(index)
                else
                    button:setState(true)
                end
            end

            if not self.selected then
                self:setSelected(index)
            end
        end,
        createOtherspaceWindow = function(self)
            local parent = self:getParent()
            local sizeX, sizeY = parent:getContainerSize()
            local window
            if self.verticle then
                if self.sourceX == 0 then
                    window = parent:createWindow(self.sizeX, 0, sizeX - self.sizeX, sizeY)
                else
                    window = parent:createWindow(0, 0, sizeX, sizeY - self.sizeX)
                end
            else
                if self.sourceY == 0 then
                    window = parent:createWindow(0, self.sizeY, sizeX, sizeY - self.sizeY)
                else
                    window = parent:createWindow(0, 0, sizeX, sizeY - self.sizeX)
                end
            end
            if parent.color and type(parent.color) ~= "function" then
                window.color = parent.color
            end
            return window
        end
    }
}

objs.seekbar = {
    handlerLocalPosition = true,
    handlerOutsideDrag = true,
    init = function(self, verticle, thickness, lineColor, circleColor, value, minValue, maxValue)
        self.verticle = verticle
        if self.verticle then
            self.thickness = thickness or mathRound(self.sizeX / 5)
        else
            self.thickness = thickness or mathRound(self.sizeY / 5)
        end
        self.lineColor = lineColor or 0x686868
        self.circleColor = circleColor or 0x00ff00
        self.value = value or 0.5
        self.minValue = minValue or 0
        self.maxValue = maxValue or 1
        self:_posFromValue()
    end,
    drawer = function(self)
        if self.verticle then
            self.display.fillRect(self.x + (self.sizeX / 2) - (self.thickness / 2), self.y, self.thickness, self.sizeY, self.lineColor)
        else
            self.display.fillRect(self.x, self.y + (self.sizeY / 2) - (self.thickness / 2), self.sizeX, self.thickness, self.lineColor)
        end
        local px, py = self.x, self.y
        local radius
        local side = self.verticle and self.sizeY or self.sizeX
        if self.verticle then
            radius = self.sizeX
            px = px + mathRound(self.sizeX / 2)
        else
            radius = self.sizeY
            py = py + mathRound(self.sizeY / 2)
        end
        local offset = constrain(self.pos, (radius / 2), side - (radius / 2))
        if self.verticle then
            py = py + offset
        else
            px = px + offset
        end
        radius = radius / 2
        self.display.fillCircle(px, py, radius, self.circleColor)
    end,
    handler = function(self, x, y, clickType, button, nickname, inZone, elementCapture)
        if clickType == "pressed" or clickType == "drag" then
            if self.verticle then
                self.pos = y
            else
                self.pos = x
            end
            self:_valueFromPos()
            self:clear()
            self:update()
            if self.onValueChanged then
                self:onValueChanged(self.value)
            end
        end
    end,
    methods = {
        _posFromValue = function(self)
            self.pos = mapClip(self.value, self.minValue, self.maxValue, 0, self.verticle and self.sizeY or self.sizeX)
        end,
        _valueFromPos = function(self)
            self.value = mapClip(self.pos, 0, self.verticle and self.sizeY or self.sizeX, self.minValue, self.maxValue)
        end,
        setValue = function(self, value)
            checkArg(1, value, "number")
            self.value = value
            self:_posFromValue()
            self:clear()
            self:update()
        end,
        getValue = function(self)
            return self.value
        end
    }
}

return objs
end