function sc_reglib_gui()
local _utf8 = utf8
local objinstance = {}
local gui = {}

local arrow1 = {
    [4] = {
        "11..",
        "111.",
        "1111",
        "111.",
        "11.."
    },
    [5] = {
        "111..",
        "1111.",
        "11111",
        "1111.",
        "111.."
    }
}

local arrow2 = {
    [4] = {
        "1111",
        "1111",
        "1111",
        ".11.",
        ".11."
    },
    [5] = {
        "11111",
        "11111",
        "11111",
        ".111.",
        "..1.."
    }
}

local function rawToLayer(self, layer)
    local pobjs = self.sceneinstance.objs
    if pobjs[layer] ~= self then
        local selfIndex
        for i = 1, #pobjs do
            if pobjs[i] == self then
                selfIndex = i
                break
            end
        end
        if selfIndex then
            table.remove(pobjs, selfIndex)
            table.insert(pobjs, layer, self)
            return true
        end
    end
end

local function rawToBottomLayer(self)
    return rawToLayer(self, 1)
end

local function rawToTopLayer(self)
    return rawToLayer(self, #self.sceneinstance.objs)
end

local function drawBitmap(display, x, y, bitmap, color)
    for y2, line in ipairs(bitmap) do
        for x2 = 1, #line do
            if line:sub(x2, x2) == "1" then
                display.drawPixel(x + (x2 - 1), y + (y2 - 1), color)
            end
        end
    end
end

local function txtLen(display, text)
    return ((display.getFontWidth() + 1) * _utf8.len(text)) - 1
end

local function formatColor(color, black)
    return canvasAPI.formatColorToSmallNumber(color, black and 0 or 0xffffff)
end

local function setCustomFont(self)
    if not self.guiinstance.customFontEnable then
        return
    end
    
    local oldFont = self.display.getFont()
    local oldScaleX, oldScaleY = self.display.getFontScale()
    local oldTextSpacing = self.display.getTextSpacing()
    self.display.setFont(self.customFont)
    self.display.setTextSpacing(self.textSpacing or 1)
    if self.fontSizeX and self.fontSizeY then
        self.display.setFontSize(self.fontSizeX, self.fontSizeY)
    else
        self.display.setFontScale(1, 1)
    end

    return function ()
        self.display.setFont(oldFont)
        self.display.setFontSize(oldScaleX, oldScaleY)
        self.display.setTextSpacing(oldTextSpacing)
    end
end

local function calcTextBox(self, text)
    local restoreFont = setCustomFont(self)
    local boxX, boxY = self.display.calcTextBox(text)
    if restoreFont then
        restoreFont()
    end
    return boxX, boxY
end

local function getObjectWidth(self, box)
    if self.sizeX then
        return self.sizeX
    elseif self.isText then
        return box and box[1] or (calcTextBox(self, self.text))
    elseif self.isImage then
        return (self.img:getSize())
    end

    return 0
end

local function getObjectHeight(self, box)
    if self.sizeY then
        if self.up_hide then
            return self.up_size
        end
        return self.sizeY
    elseif self.isText then
        return box and box[2] or select(2, calcTextBox(self, self.text))
    elseif self.isImage then
        return select(2, self.img:getSize())
    end

    return 0
end

local function remathElementInWindowPos(obj)
    obj.x = (obj.sceneinstance.x or 0) + obj.sourceX
    obj.y = (obj.sceneinstance.y or 0) + obj.sourceY
end

local function checkIntersection(object1, object2)
    local sx1, sy1 = object1:getDisplaySize()
    local sx2, sy2 = object2:getDisplaySize()
    
    local x1, y1 = object1.x, object1.y
    local x2, y2 = object2.x, object2.y

    return x1 < x2 + sx2 and
           x1 + sx1 > x2 and
           y1 < y2 + sy2 and
           y1 + sy1 > y2
end

-------- main

function objinstance:setPosition(x, y)
    self.sourceX = math.floor(x + 0.5)
    self.sourceY = math.floor(y + 0.5)
    remathElementInWindowPos(self)
    if self.isWindow then
        for _, obj in ipairs(self.objs) do
            remathElementInWindowPos(obj)
        end
    end
end

function objinstance:setPositionX(x)
    self:setPosition(x, self.sourceY)
end

function objinstance:setPositionY(y)
    self:setPosition(self.sourceX, y)
end

function objinstance:setCenter(offsetX, offsetY, gobj)
    if gobj then
        self:setPosition(
            gobj.sourceX + ((getObjectWidth(gobj) / 2) - (getObjectWidth(self) / 2)) + (offsetX or 0),
            gobj.sourceY + ((getObjectHeight(gobj) / 2) - (getObjectHeight(self) / 2)) + (offsetY or 0)
        )
    else
        self:setPosition(
            ((getObjectWidth(self.sceneinstance) / 2) - (getObjectWidth(self) / 2)) + (offsetX or 0),
            ((getObjectHeight(self.sceneinstance) / 2) - (getObjectHeight(self) / 2)) + (offsetY or 0)
        )
    end
end

function objinstance:setCenterX(offsetX, gobj)
    if gobj then
        self:setPositionX(
            gobj.sourceX + ((getObjectWidth(gobj) / 2) - (getObjectWidth(self) / 2)) + (offsetX or 0)
        )
    else
        self:setPositionX(
            ((getObjectWidth(self.sceneinstance) / 2) - (getObjectWidth(self) / 2)) + (offsetX or 0)
        )
    end
end

function objinstance:setCenterY(offsetY, gobj)
    if gobj then
        self:setPositionY(
            gobj.sourceY + ((getObjectHeight(gobj) / 2) - (getObjectHeight(self) / 2)) + (offsetY or 0)
        )
    else
        self:setPositionY(
            ((getObjectHeight(self.sceneinstance) / 2) - (getObjectHeight(self) / 2)) + (offsetY or 0)
        )
    end
end



function objinstance:setOffsetPosition(gobj, x, y)
    self:setPosition(gobj.sourceX + x, gobj.sourceY + y)
end

function objinstance:setOffsetPositionX(gobj, x)
    self:setPositionX(gobj.sourceX + x)
end

function objinstance:setOffsetPositionY(gobj, y)
    self:setPositionY(gobj.sourceY + y)
end



function objinstance:setLeft(gobj, offset)
    offset = offset or self.sceneinstance.defaultOffsetX
    self:setOffsetPosition(gobj, -getObjectWidth(self) - offset, 0)
end

function objinstance:setRight(gobj, offset)
    offset = offset or self.sceneinstance.defaultOffsetX
    self:setOffsetPosition(gobj, getObjectWidth(gobj) + offset, 0)
end

function objinstance:setUp(gobj, offset)
    offset = offset or self.sceneinstance.defaultOffsetY
    self:setOffsetPosition(gobj, 0, -getObjectHeight(self) - offset)
end

function objinstance:setDown(gobj, offset)
    offset = offset or self.sceneinstance.defaultOffsetY
    self:setOffsetPosition(gobj, 0, getObjectHeight(gobj) + offset)
end


function objinstance:setBottomLayer(gobj)
    rawToBottomLayer(self)
end

function objinstance:setTopLayer(gobj)
    rawToTopLayer(self)
end

function objinstance:setLayer(layer)
    rawToLayer(self, layer)
end

function objinstance:updateLayer()
    if self.layerMode == gui.layerMode.topLayer then
        self:setTopLayer()
    elseif self.layerMode == gui.layerMode.bottomLayer then
        self:setBottomLayer()
    end
end


function objinstance:setCenterLeft(gobj, offset)
    self:setLeft(gobj, offset)
    self:setCenterY(0, gobj)
end

function objinstance:setCenterRight(gobj, offset)
    self:setRight(gobj, offset)
    self:setCenterY(0, gobj)
end

function objinstance:setCenterUp(gobj, offset)
    self:setUp(gobj, offset)
    self:setCenterX(0, gobj)
end

function objinstance:setCenterDown(gobj, offset)
    self:setDown(gobj, offset)
    self:setCenterX(0, gobj)
end

function objinstance:set(autofunc)
    self.autofunc = autofunc
end


function objinstance:setShiftedLeft(gobj, offset)
    self:setLeft(gobj, offset)
    self:setPositionY(gobj.sourceY + getObjectHeight(gobj) - getObjectHeight(self))
end

function objinstance:setShiftedRight(gobj, offset)
    self:setRight(gobj, offset)
    self:setPositionY(gobj.sourceY + getObjectHeight(gobj) - getObjectHeight(self))
end

function objinstance:setShiftedUp(gobj, offset)
    self:setUp(gobj, offset)
    self:setPositionX(gobj.sourceX + getObjectWidth(gobj) - getObjectWidth(self))
end

function objinstance:setShiftedDown(gobj, offset)
    self:setDown(gobj, offset)
    self:setPositionX(gobj.sourceX + getObjectWidth(gobj) - getObjectWidth(self))
end


function objinstance:setBorderLeft(offset)
    offset = offset or self.sceneinstance.defaultOffsetX
    self:setPositionX(offset)
end

function objinstance:setBorderRight(offset)
    offset = offset or self.sceneinstance.defaultOffsetX
    self:setPositionX(self.sceneinstance.sizeX - getObjectWidth(self) - offset)
end

function objinstance:setBorderUp(offset)
    offset = offset or self.sceneinstance.defaultOffsetY
    self:setPositionY(offset)
end

function objinstance:setBorderDown(offset)
    offset = offset or self.sceneinstance.defaultOffsetY
    self:setPositionY(self.sceneinstance.sizeY - getObjectHeight(self) - offset)
end


function objinstance:setFontParameters(customFont, fontSizeX, fontSizeY, textSpacing)
    self.guiinstance.customFontEnable = true
    self.customFont = customFont
    self.fontSizeX = fontSizeX
    self.fontSizeY = fontSizeY
    self.textSpacing = textSpacing
end

function objinstance:setCustomStyle(style)
    self.style = style
end

local function getContainersBranch(obj)
    local list = {}
    while true do
        if not obj.sceneinstance then
            return list
        end
        table.insert(list, 1, obj)
        obj = obj.sceneinstance
    end
end

local function isObjectIsUpper(obj1, obj2) --WTF!!
    if obj1.sceneinstance.isWindow and not obj2.sceneinstance.isWindow and not obj2.isWindow then
        return true
    end

    if not obj1.sceneinstance.isWindow and obj2.sceneinstance.isWindow and not obj1.isWindow then
        return false
    end

    local contrainersBranch1, contrainersBranch2 = getContainersBranch(obj1), getContainersBranch(obj2)
    for i = 1, math.max(#contrainersBranch1, #contrainersBranch2) do
        local branch1obj = contrainersBranch1[i]
        local branch2obj = contrainersBranch2[i]
        if not branch1obj or not branch2obj then
            break
        end
        if branch1obj.sceneinstance == branch2obj.sceneinstance and branch1obj ~= branch2obj then
            obj1 = branch1obj
            obj2 = branch2obj
        end
    end

    if obj1.sceneinstance ~= obj2.sceneinstance then
        return false
    end

    local layer1, layer2
    for index, lobj in ipairs(obj1.sceneinstance.objs) do
        sc.yield()
        
        if obj1 == lobj then
            layer1 = index
        elseif obj2 == lobj then
            layer2 = index
        end

        if layer1 and layer2 then
            break
        end
    end

    return layer1 > layer2
end

local function updateTwoStep(self, updatedList, ignoreObject)
    if not self:isVisible() then return end
    if updatedList[self] then return end
    updatedList[self] = true

    self.needUpdateTwoStep = true

    for _, obj in ipairs(self.sceneinstance.allWindows) do
        sc.yield()
        if obj ~= self and obj ~= ignoreObject and checkIntersection(self, obj) then
            if isObjectIsUpper(obj, self) then
                updateTwoStep(obj, updatedList, ignoreObject)
            end
        end
    end

    for _, obj in ipairs(self.sceneinstance.objs) do
        sc.yield()
        if obj ~= self and obj ~= ignoreObject and checkIntersection(self, obj) then
            if isObjectIsUpper(obj, self) then
                updateTwoStep(obj, updatedList, ignoreObject)
            end
        end
    end
end

local function intersectionCheck(self, updatedList, objs)
    for _, obj in ipairs(objs) do
        sc.yield()
        if self ~= obj and checkIntersection(self, obj) then
            if isObjectIsUpper(obj, self) then
                updateTwoStep(obj, updatedList, self)
            end
        end
    end
end

function objinstance:setSize(width, height)
    if not width or not height then
        local _width, _height
        if self.calculateSize then
            _width, _height = self:calculateSize()
        else
            _width, _height = self.sceneinstance.sizeX - self.sourceX - self.sceneinstance.defaultOffsetX, self.sceneinstance.sizeY - self.sourceY - self.sceneinstance.defaultOffsetY
        end

        width = width or _width or 1
        height = height or _height or 1
    end

    self.sizeX = math.floor(width + 0.5)
    self.sizeY = math.floor(height + 0.5)
    remathElementInWindowPos(self)
    if self.isWindow then
        for _, obj in ipairs(self.objs) do
            remathElementInWindowPos(obj)
        end
    end
end

function objinstance:realUpdate()
    if not self:isVisible() then return end

    self.needUpdate = true

    local updatedList = {}
    local objectIntersectionMode = self.rootsceneinstance.objectIntersectionMode
    if objectIntersectionMode == 2 then
        intersectionCheck(self, updatedList, self.sceneinstance.allObjs)
    elseif objectIntersectionMode == 4 then
        intersectionCheck(self, updatedList, self.sceneinstance.allWindows)
        intersectionCheck(self, updatedList, self.sceneinstance.objs)
    elseif objectIntersectionMode == 1 or (objectIntersectionMode == 3 and #self.sceneinstance.allWindows > 0) then
        intersectionCheck(self, updatedList, self.sceneinstance.allWindows)
    end

    if self.sceneinstance:isSelected() then
        self.guiinstance.needFlushFlag = true
    end
end

function objinstance:update()
    self.rootsceneinstance.updateList[self] = true
end

function objinstance:getLastInteractionType()
    return self.lastInteractionType
end

function objinstance:getLastNickname()
    return self.lastNickname
end

function objinstance:isVisible()
    if self.invisible or self.destroyed then return false end
    if not self.sceneinstance:isSelected() then return false end

    local function recursionMinimizeCheck(self)
        sc.yield()

        if not self.sceneinstance.isWindow then
            return
        end

        if self.sceneinstance.up_hide and self.sourceY >= self.sceneinstance.up_size then
            return true
        end

        if recursionMinimizeCheck(self.sceneinstance) then
            return true
        end
    end

    return not recursionMinimizeCheck(self)
end

function objinstance:destroy()
    if self.destroyed then return false end
    self.destroyed = true

    if self.isWindow then
        for i = #self.objs, 1, -1 do
            local lobj = self.objs[i]
            lobj:destroy()
        end
    end

    for index, obj in ipairs(self.sceneinstance.panelObjs or {}) do
        sc.yield()
        if obj == self then
            table.remove(self.sceneinstance.panelObjs, index)
            break
        end
    end
    
    for index, obj in ipairs(self.sceneinstance.allObjs) do
        sc.yield()
        if obj == self then
            table.remove(self.sceneinstance.allObjs, index)
            break
        end
    end

    for index, obj in ipairs(self.sceneinstance.allWindows) do
        sc.yield()
        if obj == self then
            table.remove(self.sceneinstance.allWindows, index)
            break
        end
    end

    for index, obj in ipairs(self.sceneinstance.orderedObjs) do
        sc.yield()
        if obj == self then
            table.remove(self.sceneinstance.orderedObjs, index)
            break
        end
    end

    for index, obj in ipairs(self.sceneinstance.objs) do
        sc.yield()
        if obj == self then
            if self.onDestroy then self:onDestroy() end
            if self.onDestroy_fromClass then self:onDestroy_fromClass() end
            table.remove(self.sceneinstance.objs, index)
            self.guiinstance.needFlushFlag = true
            self.sceneinstance.needUpdate = true
            return true
        end
    end

    return false
end

function objinstance:_getBackColor()
    if self.sceneinstance.color and type(self.sceneinstance.color) ~= "function" then
        return self.sceneinstance.color
    end
    if self.sceneinstance and self.sceneinstance._getBackColor then
        return self.sceneinstance:_getBackColor()
    end
end

function objinstance:clear(color, minWidth, minHeight)
    if not self.sceneinstance:isSelected() then return end
    if not color then
        color = self:_getBackColor()
    end
    color = formatColor(color, true)

    self.display.fillRect(self.x, self.y, math.max(minWidth or 0, getObjectWidth(self)), math.max(minHeight or 0, getObjectHeight(self)), color)
end

function objinstance:getDisplaySize()
    local box
    if self.text then
        box = {calcTextBox(self, self.text)}
    end
    return getObjectWidth(self, box), getObjectHeight(self, box)
end

function objinstance:setDisabled(state)
    if self.disable ~= state then
        self.disable = state
        self:update()
    end
end

function objinstance:setInvisible(state)
    if self.invisible ~= state then
        self.invisible = state
        self:update()
    end
end

-------- window

function objinstance:upPanel(color, textcolor, title, collapsibility)
    if color then
        self.up_color = formatColor(color, true)
        self.up_textcolor = formatColor(textcolor, true)
        self.up_title = title or ""
        self.up_collapsibility = collapsibility
        self.up_hide = false
        self.up_size = self.display.getFontHeight() + 2
        self.panelObjs = {}
    else
        self.up_color = nil
        self.up_title = nil
        self.up_collapsibility = nil
        self.up_hide = nil
        self.up_size = nil
        if self.panelObjs then
            for i, v in ipairs(self.panelObjs) do
                v:destroy()
            end
            self.panelObjs = nil
        end
    end
    self:update()
end

function objinstance:panelButton(sizeX, ...)
    if self.panelObjs then
        sizeX = sizeX or self.up_size
        local posX = self.panelObjs[#self.panelObjs]
        if posX then
            posX = posX.sourceX - sizeX
        else
            posX = self.sizeX - sizeX
        end
        local button = self:createButton(posX, 0, sizeX or self.up_size, self.up_size, ...)
        table.insert(self.panelObjs, button)
        self:update()
        return button
    end
end

function objinstance:panelObject(contructorname, sizeX, ...)
    if self.panelObjs then
        sizeX = sizeX or self.up_size
        local posX = self.panelObjs[#self.panelObjs]
        if posX then
            posX = posX.sourceX - sizeX
        else
            posX = self.sizeX - sizeX
        end
        local object = self[contructorname](self, posX, 0, sizeX or self.up_size, self.up_size, ...)
        table.insert(self.panelObjs, object)
        self:update()
        return object
    end
end

function objinstance:minimize(state)
    if self.up_color then
        if self.up_hide ~= state then
            self.up_hide = state
            self:update()
        end
    end
end

function objinstance:setDraggable(state)
    self.draggable = state
end

function objinstance:setAutoViewport(autoViewport)
    self.autoViewport = autoViewport
end

function objinstance:setColor(color)
    if self.color ~= color then
        self.color = color
        self:update()
    end
end

function objinstance:isSelected()
    return self.sceneinstance:isSelected()
end

function objinstance:updateParent()
    self.sceneinstance:update()
end

function objinstance:getParent()
    return self.sceneinstance
end

function objinstance:getLayer()
    for index, lobj in ipairs(self.sceneinstance.objs) do
        sc.yield()
        
        if lobj == self then
            return index
        end
    end

    error("failed to get layer", 2)
end

function objinstance:setLayerMode(mode)
    self.layerMode = mode
    self:updateLayer()
end

-------- label / text / button

function objinstance:setText(text)
    text = tostring(text)
    if self.text ~= text then
        local minWidth, minHeight = self:getDisplaySize()
        self.text = text
        self:update()
        if self.sceneinstance.color and type(self.sceneinstance.color) ~= "function" then
            self:clear(self.sceneinstance.color, minWidth, minHeight)
        end
    end
end

function objinstance:setFgColor(color)
    if self.fg ~= color then
        self.fg = formatColor(color)
        self:update()
    end
end

function objinstance:setBgColor(color)
    if self.bg ~= color then
        self.bg = color and formatColor(color)
        self:update()
    end
end

function objinstance:setPfgColor(color)
    if self.fg_press ~= color then
        self.fg_press = formatColor(color)
        self:update()
    end
end

function objinstance:setPbgColor(color)
    if self.bg_press ~= color then
        self.bg_press = formatColor(color)
        self:update()
    end
end

function objinstance:setIbgColor(color)
    if self.bg_interaction ~= color then
        self.bg_interaction = formatColor(color)
        self:update()
    end
end

function objinstance:setIfgColor(color)
    if self.fg_interaction ~= color then
        self.fg_interaction = formatColor(color)
        self:update()
    end
end

function objinstance:setStColor(color)
    if self.stroke_color ~= color then
        self.stroke_color = formatColor(color)
        self:update()
    end
end

function objinstance:setPstColor(color)
    if self.stroke_press ~= color then
        self.stroke_press = formatColor(color)
        self:update()
    end
end

function objinstance:setIstColor(color)
    if self.stroke_interaction ~= color then
        self.stroke_interaction = formatColor(color)
        self:update()
    end
end

-------- image

function objinstance:updateImage(img)
    self.img = img
    self:update()
end

-------- button

function objinstance:getState()
    return self.state
end

function objinstance:setState(state)
    self.state = state
    self.old_toggle_state = state
    self:update()
end

function objinstance:isPress()
    return self.state and not self.old_state
end

function objinstance:isReleased()
    return self.old_state and not self.state
end

function objinstance:attachCallback(callback)
    self.callbacks[1] = callback
end

function objinstance:setSceneSwitch(scene)
    self.callbacks[2] = function(_, state, inZone)
        if not state and inZone then
            scene:select()
        end
    end
end

-------- service

local function toUpperLevel(self)
    if self.layerMode ~= gui.layerMode.auto then
        return
    end
    
    return rawToTopLayer(self)
end

local function windowPosCheck(self)
    if self.sceneinstance.isWindow then
        local maxX = self.sceneinstance.sizeX - self.sizeX
        if self.sourceX < 0 then
            self.sourceX = 0
        elseif self.sourceX >= maxX then
            self.sourceX = maxX
        end

        local minY = self.sceneinstance.up_size or 0
        local maxY = self.sceneinstance.sizeY
        if self.up_hide then
            maxY = maxY - self.up_size
        else
            maxY = maxY - self.sizeY
        end
        if self.sourceY < minY then
            self.sourceY = minY
        elseif self.sourceY >= maxY then
            self.sourceY = maxY
        end
    end

    self.x = self.sourceX + (self.sceneinstance.x or 0)
    self.y = self.sourceY + (self.sceneinstance.y or 0)

    local function recursionUpdate(objs)
        sc.yield()
        for _, obj in ipairs(objs) do
            sc.yield()
            obj:setPosition(obj.sourceX, obj.sourceY)
            if obj.isWindow then
                recursionUpdate(obj.objs)
            end
        end
    end

    recursionUpdate(self.objs)
end

local function getLocalPosition(self, click)
    return click.x - self.x, click.y - self.y
end

local function processNewCallbacks(click, self, state, inZone)
    if click == true then click = nil end
    if click then
        if state then
            if inZone and not self.universalCallbacksState then
                self.universalCallbacksState = true
                if not self.isWindow then
                    toUpperLevel(self)
                end
                if self.onClick then
                    self:onClick(click, getLocalPosition(self, click))
                end
            end
        elseif self.universalCallbacksState then
            self.universalCallbacksState = false

            if self.onDrop then
                self:onDrop(click, getLocalPosition(self, click))
            end

            if inZone and self.onDropInZone then
                self:onDropInZone(click, getLocalPosition(self, click))
            end
        end

        if click.state == "drag" and self.universalCallbacksState then
            if self.onDrag then
                self:onDrag(click, getLocalPosition(self, click))
            end

            if inZone and self.onDragInZone then
                self:onDragInZone(click, getLocalPosition(self, click))
            end
        end
    end
end

local function runCallbacks(click, self, state, inZone)
    if self.callback then
        self.callback(self, state, inZone)
    end
    for k, v in pairs(self.callbacks) do
        v(self, state, inZone)
    end
    if self.state ~= self.old_toggle_state then
        if self.onToggle then
            self:onToggle(self.state)
        end
        self.old_toggle_state = self.state
    end
end

function objinstance:_tick(click)
    if not self.sizeX or self.disable or self.destroyed then
        return
    end

    local selected = false

    if click == true then
        self.interactionCurrently = false
    elseif click then
        selected = click and click[1] >= self.x and click[2] >= self.y and click[1] < (self.x + self.sizeX) and click[2] < (self.y + self.sizeY)
        local state = click[3] ~= "released"
        if not state or selected then
            self.interactionCurrently = state
        end
    end

    if self.interactionCurrently ~= self._interactionCurrently then
        self:update()
        self._interactionCurrently = self.interactionCurrently
    end

    if self.customHandler then
        if click == true and self.state then
            self:customHandler(-1, -1, "released", -1, "unknown", false) --release the pressed items when switching the scene
            self.state = false
        end
    end
    if self.button then
        if click == true and not self.toggle then
            self.state = false
            runCallbacks(click, self, false, false)
        end
        self.old_state = self.state
    end
    if click == true then
        processNewCallbacks(click, self, false, false)
    end
    if not click or click == true then
        return
    end

    local tx, ty = click[1], click[2]
    local lx, ly = tx - self.x, ty - self.y
    local clktype = click[3]
    local btntype = click[4]
    local nickname = click[5]

    if self.sceneinstance.autoViewport then
        if not (click[1] >= self.sceneinstance.x and click[2] >= self.sceneinstance.y and click[1] < (self.sceneinstance.x + self.sceneinstance.sizeX) and click[2] < (self.sceneinstance.y + self.sceneinstance.sizeY)) then
            selected = false
        end
    end

    self.lastClickTable = click
    self.lastInteractionType = btntype
    self.lastNickname = nickname
    
    processNewCallbacks(click, self, clktype == "pressed" or (self.universalCallbacksState and clktype == "drag"), selected)

    local elementCapture = false
    local windowDragging

    if self.button then
        if self.toggle then
            if selected and clktype == "pressed" then
                self.state = not self.state
                runCallbacks(click, self, self.state, true)
            end
        elseif selected and clktype == "pressed" then
            self.state = true
            runCallbacks(click, self, true, true)
        elseif clktype == "released" and self.state then
            self.state = false
            runCallbacks(click, self, false, selected)
        end

        if self.state ~= self.old_state then
            self:update()
        end
    elseif self.isWindow then
        local objectList
        if self.up_hide then
            objectList = self.panelObjs
            if selected and self.up_size and ly >= self.up_size then
                selected = false
            end
        else
            objectList = self.objs
        end
        if objectList and (clktype ~= "pressed" or selected) then
            local objs = sc.copy(objectList)
            for i = #objs, 1, -1 do
                sc.yield()
                local obj = objs[i]
                if not objs.destroyed and obj:_tick(click) then
                    elementCapture = true
                    if clktype ~= "released" then
                        break
                    end
                end
            end
        end

        if elementCapture and clktype == "pressed" then
            self.touchX = nil
            self.touchY = nil
            if toUpperLevel(self) then
                self.guiinstance.needFlushFlag = true
                self.sceneinstance.needUpdate = true
            end
        elseif clktype == "pressed" then
            if selected then
                local upSel = self.up_size and ly < self.up_size
                if self.up_color and self.up_collapsibility and upSel and lx < self.display.getFontWidth() + 2 then
                    self.up_hide = not self.up_hide
                    if self.up_hide then
                        if self.onMinimize then self:onMinimize() end
                        if self.sceneinstance.onWindowMinimize then
                            self.sceneinstance:onWindowMinimize()
                        end
                    else
                        if self.onMaximize then self:onMaximize() end
                        if self.sceneinstance.onWindowMaximize then
                            self.sceneinstance:onWindowMaximize()
                        end
                    end
                    windowPosCheck(self)
                    toUpperLevel(self)
                    self.guiinstance.needFlushFlag = true
                    self.sceneinstance.needUpdate = true
                    self.sceneinstance:updateChildrenRule()
                elseif not self.up_hide or upSel then
                    self.touchX = tx
                    self.touchY = ty
                    windowPosCheck(self)
                    if toUpperLevel(self) then
                        self.guiinstance.needFlushFlag = true
                        self.sceneinstance.needUpdate = true
                    end
                end
            end
        elseif clktype == "released" then
            self.touchX = nil
            self.touchY = nil
        elseif clktype == "drag" and self.touchX and self.draggable then
            self.guiinstance.needFlushFlag = true
            self.sceneinstance.needUpdate = true
            local dx = tx - self.touchX
            local dy = ty - self.touchY
            self.touchX = tx
            self.touchY = ty
            self.sourceX = self.sourceX + dx
            self.sourceY = self.sourceY + dy
            windowPosCheck(self)
            toUpperLevel(self)
            if self.onDragging then
                self:onDragging()
            end
            if self.sceneinstance.onWindowDragging then
                self.sceneinstance:onWindowDragging()
            end
            self.sceneinstance:updateChildrenRule()
            windowDragging = true
        end
    end

    if self.customHandler then
        if selected or (self.state and clktype == "released") or (self.state and self.handlerOutsideDrag and clktype == "drag") then
            self.state = clktype ~= "released"
            if not self.handlerAllClicks then
                local ax, ay = tx, ty
                if self.handlerLocalPosition then
                    ax, ay = lx, ly
                end
                if self:customHandler(ax, ay, clktype, btntype, nickname, selected, elementCapture) then
                    self:update()
                end
            end
        end
    end

    return self.universalCallbacksState and (selected or windowDragging)
end

function objinstance:redraw()
    self:update()
    self:_draw()
end

local function updateWindowObjects(self, force, twoStep)
    if self.up_hide then
        for _, obj in ipairs(self.objs) do
            sc.yield()
            if obj.sourceY < self.up_size then
                obj:_draw(force, twoStep)
            end
        end
    else
        for _, obj in ipairs(self.objs) do
            sc.yield()
            obj:_draw(force, twoStep)
        end
    end
end

function objinstance:_draw(force, twoStep)
    if self.invisible or self.destroyed then return end

    if twoStep then
        if not force and not self.needUpdateTwoStep then
            if self.isWindow then
                updateWindowObjects(self, false, true)
            end
            return
        end
        self.needUpdateTwoStep = false
    else
        if not force and not self.needUpdate then
            if self.isWindow then
                updateWindowObjects(self, false, false)
            end
            return
        end
        self.needUpdate = false
        if force then
            self.needUpdateTwoStep = false
        end
    end

    local restoreFont = setCustomFont(self)

    local old_viewport_x, old_viewport_y, old_viewport_sizeX, old_viewport_sizeY = self.display.getViewport()
    if self.autoViewport then
        self.display.setInlineViewport(self.x, self.y, self.sizeX, self.sizeY)
    end

    if self.preDraw then
        self:preDraw()
    end

    if self.style then
        self:style()
    elseif self.button or self.label or self.textBox then
        local bg, fg = self.bg, self.fg
        if self.state then
            bg, fg = self.bg_press, self.fg_press
        end
        if self.interactionCurrently then
            bg, fg = self.bg_interaction or bg, self.fg_interaction or fg
        end

        local strokeColor = self.state and self.stroke_press or self.stroke_color
        if self.interactionCurrently and self.stroke_interaction then
            strokeColor = self.stroke_interaction
        end
        self.display.fillRect(self.x, self.y, self.sizeX, self.sizeY, bg or self.sceneinstance.color or 0)
        if strokeColor then
            self.display.drawRect(self.x, self.y, self.sizeX, self.sizeY, strokeColor)
        end
        
        local graphic = sc.lib_require("graphic")
        if self.textBox then
            graphic.textBox(self.display, self.x + 1, self.y + 1, self.sizeX - 1, self.sizeY, self.text, fg, self.centerX, self.centerY, self.spacingY, self.autoNewline, self.tool)
        else
            graphic.textBox(self.display, self.x, self.y, self.sizeX, self.sizeY, self.text, fg, true, true, nil, false)
        end
    elseif self.isText then
        self.display.drawText(self.x, self.y, self.text, self.fg)
    elseif self.isImage then
        self.img:draw(self.display, self.x, self.y)
    elseif self.isWindow then
        if not self.up_hide then
            if type(self.color) == "function" then
                self:color()
            elseif self.color then
                self.display.fillRect(self.x, self.y, self.sizeX, self.sizeY, self.color)
            end
        end

        if self.up_color then
            self.display.fillRect(self.x, self.y, self.sizeX, self.up_size, self.up_color)
            if self.up_collapsibility then
                local arrowList = self.up_hide and arrow1 or arrow2
                local fontWidth = self.display.getFontWidth()
                local fontHeight = self.display.getFontHeight()
                local bitmap = arrowList[fontWidth]
                if bitmap then
                    drawBitmap(self.display, self.x + 1, self.y + 1, bitmap, self.up_textcolor)
                elseif self.up_hide then
                    self.display.fillTriangle(self.x + 1, self.y + 1, self.x + fontWidth, self.y + mathRound(fontHeight / 2), self.x + 1, self.y + fontHeight, self.up_textcolor)
                else
                    self.display.fillTriangle(self.x + 1, self.y + 1, self.x + fontWidth, self.y + 1, self.x + mathRound(fontWidth / 2), self.y + fontHeight, self.up_textcolor)
                end
                self.display.drawText(self.x + fontWidth + 2, self.y + 1, self.up_title, self.up_textcolor)
            else
                self.display.drawText(self.x + 1, self.y + 1, self.up_title, self.up_textcolor)
            end
        end
        
        updateWindowObjects(self, true, twoStep)
    end

    if self.postDraw then
        self:postDraw()
    end

    if self.autoViewport then
        self.display.setViewport(old_viewport_x, old_viewport_y, old_viewport_sizeX, old_viewport_sizeY)
    end

    if restoreFont then
        restoreFont()
    end
end

-----------------------------------scene instance

local sceneinstance = {}

function sceneinstance:setObjectIntersectionMode(mode)
    if not mode then
        mode = 0
    elseif mode == true then
        mode = 3
    end
    self.objectIntersectionMode = mode
end

function sceneinstance:setAlwaysRedraw(state)
    self.alwaysRedraw = not not state
end

function sceneinstance:isAlwaysRedraw()
    return self.alwaysRedraw
end

function sceneinstance:update()
    if self:isSelected() then
        self.needUpdate = true
        self.guiinstance.needFlushFlag = true
    end
end

function sceneinstance:_tick(clean)
    local click = self.display.getClick()
    if clean then
        click = true
    elseif self.onTick then
        self:onTick(click)
    end

    local elementCapture = false
    local elementCaptureList = {}
    if not self.bgHandleUse then
        local objs = sc.copy(self.objs)
        for i = #objs, 1, -1 do
            sc.yield()
            local obj = objs[i]
            if not obj.destroyed and obj:_tick(click) then
                elementCapture = true
                elementCaptureList[obj] = true
                if click ~= true and click[3] ~= "released" then
                    break
                end
            end
        end
    end

    if not clean then
        for i = #self.allObjs, 1, -1 do
            sc.yield()
    
            local obj = self.allObjs[i]
            obj:updateLayer()
            
            if obj.onTick then
                obj:onTick(click)
            end
    
            local visible = nil
    
            if obj.onTickIfVisible then
                if visible == nil then
                    visible = obj:isVisible()
                end
                if visible then
                    obj:onTickIfVisible(click)
                end
            end
    
            if obj.isWindow and not obj.up_hide and obj.onTickIfOpen then
                if visible == nil then
                    visible = obj:isVisible()
                end
                if visible then
                    obj:onTickIfOpen(click)
                end
            end
    
            if obj.universalCallbacksState and obj.onTickIfPressed then
                obj:onTickIfPressed(click, getLocalPosition(obj, click))
            end
    
            if click and obj.handlerAllClicks and obj.customHandler then
                local tx, ty = click[1], click[2]
                local lx, ly = tx - obj.x, ty - obj.y
                local selected = click[1] >= obj.x and click[2] >= obj.y and click[1] < (obj.x + obj.sizeX) and click[2] < (obj.y + obj.sizeY)
                local clktype = click[3]
                local btntype = click[4]
                local nickname = click[5]
    
                if obj.handlerLocalPosition then
                    tx, ty = lx, ly
                end
    
                if obj:customHandler(tx, ty, clktype, btntype, nickname, selected, not not elementCaptureList[obj]) then
                    obj:update()
                end
            end
        end
    
        if click then
            if not elementCapture and click[3] == "pressed" then
                self.bgHandleUse = true
            end
            if self.bgHandleUse and self.bgHandle then
                self:bgHandle(click)
            end
            if self.onBackgroundClick then
                self:onBackgroundClick(click, not self.bgHandleUse)
            end
            if click[3] == "released" then
                self.bgHandleUse = nil
            end
        end

        if self.needUpdateChildrenRule then
            self:realUpdateChildrenRule()
            self.needUpdateChildrenRule = nil
        end
        for _, window in ipairs(self.allWindows) do
            if window.needUpdateChildrenRule then
                window:realUpdateChildrenRule()
                window.needUpdateChildrenRule = nil
            end
        end
        
        return click
    end
end

function sceneinstance:_draw(force)
    if self.alwaysRedraw then
        force = true
    end

    if self.needUpdate or force then
        if self.color then
            if type(self.color) == "function" then
                self:color()
            else
                self.display.clear(self.color)
            end
        end
        self.needUpdate = false
        force = true
    end

    for _, obj in ipairs(self.objs) do
        sc.yield()
        obj:_draw(force)
    end

    if not force then
        for _, obj in ipairs(self.objs) do
            sc.yield()
            obj:_draw(force, true)
        end
    end
end

function sceneinstance:select()
    if self.guiinstance.scene and self.guiinstance.scene.onUnselect then
        self.guiinstance.scene:onUnselect()
    end
    
    if self.guiinstance.scene then
        self.guiinstance.scene:_tick(true) --чтобы сбросить все кнопки(не переключатели)
    end
    self.guiinstance.scene = self
    self:update()

    if self.onSelect then
        self:onSelect()
    end
end

function sceneinstance:isSelected()
    return self == self.guiinstance.scene
end

local function initObject(self, obj, noCalcSize)
    obj.guiinstance = self.guiinstance
    obj.sceneinstance = self
    obj.rootsceneinstance = self.rootsceneinstance or self
    obj.onWindow = self.isWindow
    obj.display = self.display
    obj._tick = objinstance._tick
    obj._draw = objinstance._draw
    obj.redraw = objinstance.redraw
    obj.destroy = objinstance.destroy
    obj.getLastInteractionType = objinstance.getLastInteractionType
    obj.getLastNickname = objinstance.getLastNickname
    obj.update = objinstance.update
    obj.clear = objinstance.clear
    obj._getBackColor = objinstance._getBackColor
    obj.setCustomStyle = objinstance.setCustomStyle
    obj.setInvisible = objinstance.setInvisible
    obj.setDisabled = objinstance.setDisabled

    obj.guiinstance.needFlushFlag = true
    obj.sceneinstance.needUpdate = true

    obj.setCenter = objinstance.setCenter
    obj.setCenterX = objinstance.setCenterX
    obj.setCenterY = objinstance.setCenterY
    obj.setPosition = objinstance.setPosition
    obj.setPositionX = objinstance.setPositionX
    obj.setPositionY = objinstance.setPositionY
    obj.setOffsetPosition = objinstance.setOffsetPosition
    obj.setOffsetPositionX = objinstance.setOffsetPositionX
    obj.setOffsetPositionY = objinstance.setOffsetPositionY
    obj.setLeft = objinstance.setLeft
    obj.setRight = objinstance.setRight
    obj.setUp = objinstance.setUp
    obj.setDown = objinstance.setDown
    obj.setCenterLeft = objinstance.setCenterLeft
    obj.setCenterRight = objinstance.setCenterRight
    obj.setCenterUp = objinstance.setCenterUp
    obj.setCenterDown = objinstance.setCenterDown
    obj.set = objinstance.set
    obj.setShiftedLeft = objinstance.setShiftedLeft
    obj.setShiftedRight = objinstance.setShiftedRight
    obj.setShiftedUp = objinstance.setShiftedUp
    obj.setShiftedDown = objinstance.setShiftedDown
    obj.setBorderLeft = objinstance.setBorderLeft
    obj.setBorderRight = objinstance.setBorderRight
    obj.setBorderUp = objinstance.setBorderUp
    obj.setBorderDown = objinstance.setBorderDown
    obj.setFontParameters = objinstance.setFontParameters
    obj.setBottomLayer = objinstance.setBottomLayer
    obj.setTopLayer = objinstance.setTopLayer
    obj.setLayer = objinstance.setLayer
    obj.getDisplaySize = objinstance.getDisplaySize
    obj.isVisible = objinstance.isVisible
    obj.updateParent = objinstance.updateParent
    obj.getParent = objinstance.getParent
    obj.getLayer = objinstance.getLayer
    obj.realUpdate = objinstance.realUpdate
    obj.setSize = objinstance.setSize
    obj.setLayerMode = objinstance.setLayerMode
    obj.updateLayer = objinstance.updateLayer

    obj.disable = obj.disable or false
    obj.invisible = obj.invisible or false
    obj.autoViewport = obj.autoViewport or false
    obj.layerMode = obj.layerMode or gui.layerMode.static

    --[[
    local autoX, autoY, autoSX, autoSY
    if self.isGrid then
        autoX, autoY = obj.x or 0, obj.y or 0
        autoX, autoY = autoX * self.gridItemSizeX, autoY * self.gridItemSizeY
        autoX, autoY = autoX + (self.gridItemSizeX / 2), autoY + (self.gridItemSizeY / 2)
        autoSX, autoSY = mathRound(self.gridItemSizeX * self.defaultObjectSizeXmul), mathRound(self.gridItemSizeY * self.defaultObjectSizeYmul)
        self.grid[obj.x][obj.y] = obj
        obj.x = nil
        obj.y = nil
    else
        autoX, autoY = self.defaultOffsetX, (self.up_size or 0) + self.defaultOffsetY
    end

    -- pos math
    local offsetX, offsetY = 0, 0
    if self.isGrid then
        offsetX, offsetY = -(autoSX / 2), -(autoSY / 2)
    end
    obj.x = mathRound((obj.x or autoX) + offsetX)
    obj.y = mathRound((obj.y or autoY) + offsetY)
    if obj.isText then
        obj.sizeX = obj.sizeX or autoSX
        obj.sizeY = obj.sizeY or autoSY
    else
        obj.sizeX = obj.sizeX or autoSX or (self.sizeX - obj.x - self.defaultOffsetX)
        obj.sizeY = obj.sizeY or autoSY or (self.sizeY - obj.y - self.defaultOffsetY)
    end
    obj.sourceX = obj.x
    obj.sourceY = obj.y
    remathElementInWindowPos(obj)
    ]]

    -- auto pos & size & layer
    obj.sourceX = mathRound(obj.x or self.defaultOffsetX)
    obj.sourceY = mathRound(obj.y or ((self.up_size or 0) + self.defaultOffsetY))

    remathElementInWindowPos(obj)

    if not obj.isText and not noCalcSize then
        obj:setSize(obj.sizeX, obj.sizeY)
    end

    obj:updateLayer()
    if self.defaultSet then
        obj:set(self.defaultSet)
    end

    table.insert(self.objs, obj)
    table.insert(self.orderedObjs, obj)
    table.insert(self.allObjs, obj)
end

function sceneinstance:setDefaultOffset(offsetX, offsetY)
    self.defaultOffsetX = offsetX or 1
    self.defaultOffsetY = offsetY or offsetX or 1
end

function sceneinstance:setDefaultPadding(paddingX, paddingY)
    self.defaultPaddingX = paddingX or 1
    self.defaultPaddingY = paddingY or paddingX or 1
end

function sceneinstance:getContainerSize()
    return self.sizeX, self.sizeY
end

function sceneinstance:getChildrenCount()
    return #self.objs
end

function sceneinstance:isScene()
    return not self.isWindow
end

function sceneinstance:updateChildrenRule()
    self.needUpdateChildrenRule = true
end

function sceneinstance:realUpdateChildrenRule()
    local autofuncPrevious
    for _, obj in ipairs(self.orderedObjs) do
        if obj.autofunc then
            obj:autofunc(autofuncPrevious, self)
            autofuncPrevious = obj
        end
    end
end

function sceneinstance:setDefaultSet(defaultSet)
    self.defaultSet = defaultSet
end

local function addSceneFields(sceneOrWindow, parent)
    sceneOrWindow.defaultOffsetX = parent and parent.defaultOffsetX or 1
    sceneOrWindow.defaultOffsetY = parent and parent.defaultOffsetY or 1
    sceneOrWindow.defaultPaddingX = parent and parent.defaultPaddingX or 2
    sceneOrWindow.defaultPaddingY = parent and parent.defaultPaddingY or 2
    sceneOrWindow.setDefaultOffset = sceneinstance.setDefaultOffset
    sceneOrWindow.setDefaultPadding = sceneinstance.setDefaultPadding
    sceneOrWindow.getContainerSize = sceneinstance.getContainerSize
    sceneOrWindow.getChildrenCount = sceneinstance.getChildrenCount
    sceneOrWindow.isScene = sceneinstance.isScene
    sceneOrWindow.setDefaultSet = sceneinstance.setDefaultSet
    sceneOrWindow.updateChildrenRule = sceneinstance.updateChildrenRule
    sceneOrWindow.realUpdateChildrenRule = sceneinstance.realUpdateChildrenRule
    sceneOrWindow.orderedObjs = {}
    sceneOrWindow.objs = {}

    sceneOrWindow.createButton = sceneinstance.createButton
    sceneOrWindow.createImage = sceneinstance.createImage
    sceneOrWindow.createText = sceneinstance.createText
    sceneOrWindow.createLabel = sceneinstance.createLabel
    sceneOrWindow.createTextBox = sceneinstance.createTextBox
    sceneOrWindow.createCustom = sceneinstance.createCustom
    sceneOrWindow.createWindow = sceneinstance.createWindow

    sceneOrWindow:updateChildrenRule()
end

function sceneinstance:createWindow(x, y, sizeX, sizeY, color)
    local obj = {
        x = x,
        y = y,
        sizeX = sizeX,
        sizeY = sizeY,
        color = color,
        draggable = false,
        allObjs = self.allObjs,
        allWindows = self.allWindows,
        windowNesting = (self.windowNesting or 0) + 1,
        layerMode = gui.layerMode.auto,

        setDraggable = objinstance.setDraggable,
        setAutoViewport = objinstance.setAutoViewport,
        setColor = objinstance.setColor,
        isSelected = objinstance.isSelected,
        upPanel = objinstance.upPanel,
        panelButton = objinstance.panelButton,
        panelObject = objinstance.panelObject,
        minimize = objinstance.minimize,

        isWindow = true
    }
    addSceneFields(obj, self)
    initObject(self, obj)

    table.insert(self.allWindows, obj)
    return obj
end

function sceneinstance:createCustom(x, y, sizeX, sizeY, cls, ...)
    if cls.useWindow then
        local clsCopy = sc.copy(cls)
        clsCopy.useWindow = nil

        local obj = self:createWindow(x, y, sizeX, sizeY)
        obj.preDraw = cls.drawer
        obj.customHandler = cls.handler
        obj.layerMode = cls.layerMode or gui.layerMode.static
        obj.handlerLocalPosition = cls.handlerLocalPosition
        obj.handlerAllClicks = cls.handlerAllClicks
        obj.handlerOutsideDrag = cls.handlerOutsideDrag
        obj.autoViewport = cls.autoViewport
        obj.calculateSize = cls.calculateSize
        if cls.methods then
            for k, v in pairs(cls.methods) do
                obj[k] = v
            end
        end
        if cls.init then
            cls.init(obj, ...)
        end
        obj:setSize(obj.sizeX, obj.sizeY)
        obj:updateLayer()
        return obj
    end

    local obj = {
        x = x,
        y = y,
        sizeX = sizeX,
        sizeY = sizeY,
        state = false,

        args = {...},
        style = cls.drawer,
        customHandler = cls.handler,
        handlerLocalPosition = cls.handlerLocalPosition,
        handlerAllClicks = cls.handlerAllClicks,
        handlerOutsideDrag = cls.handlerOutsideDrag,
        autoViewport = cls.autoViewport,
        calculateSize = cls.calculateSize,
        onDestroy_fromClass = cls.destroyHandler
    }
    initObject(self, obj, true)
    if cls.methods then
        for k, v in pairs(cls.methods) do
            obj[k] = v
        end
    end
    if cls.init then
        cls.init(obj, ...)
    end
    obj:setSize(obj.sizeX, obj.sizeY)

    return obj
end

function sceneinstance:createButton(x, y, sizeX, sizeY, toggle, text, bg, fg, bg_press, fg_press)
    text = tostring(text or "")
    bg = formatColor(bg)
    fg = formatColor(fg, true)
    if bg_press then
        bg_press = formatColor(bg_press)
    else
        bg_press = fg
    end
    if fg_press then
        fg_press = formatColor(fg_press, true)
    else
        fg_press = bg
    end

    local obj = {
        calculateSize = gui.calculateSizeByText,
        
        x = x,
        y = y,
        sizeX = sizeX,
        sizeY = sizeY,
        toggle = toggle,
        text = text,
        bg = bg,
        fg = fg,
        bg_press = bg_press,
        fg_press = fg_press,
        callbacks = {},

        getState = objinstance.getState,
        setState = objinstance.setState,
        isPress = objinstance.isPress,
        isReleased = objinstance.isReleased,
        attachCallback = objinstance.attachCallback,
        setSceneSwitch = objinstance.setSceneSwitch,

        setText = objinstance.setText,
        setBgColor = objinstance.setBgColor,
        setFgColor = objinstance.setFgColor,
        setPbgColor = objinstance.setPbgColor,
        setPfgColor = objinstance.setPfgColor,
        setIbgColor = objinstance.setIbgColor,
        setIfgColor = objinstance.setIfgColor,
        setStColor = objinstance.setStColor,
        setIstColor = objinstance.setIstColor,
        setPstColor = objinstance.setPstColor,

        old_toggle_state = false,
        state = false,
        button = true
    }
    initObject(self, obj)

    return obj
end

function sceneinstance:createImage(x, y, img)
    local obj = {
        calculateSize = gui.calculateSizeByImage,

        x = x,
        y = y,
        img = img,

        updateImage = objinstance.updateImage,

        isImage = true
    }
    initObject(self, obj)

    return obj
end

function sceneinstance:createLabel(x, y, sizeX, sizeY, text, bg, fg)
    text = tostring(text or "")
    bg = formatColor(bg)
    fg = formatColor(fg, true)

    local obj = {
        calculateSize = gui.calculateSizeByText,

        x = x,
        y = y,
        sizeX = sizeX,
        sizeY = sizeY,
        text = text,
        bg = bg,
        fg = fg,

        setText = objinstance.setText,
        setBgColor = objinstance.setBgColor,
        setFgColor = objinstance.setFgColor,
        setIbgColor = objinstance.setIbgColor,
        setIfgColor = objinstance.setIfgColor,
        setStColor = objinstance.setStColor,
        setIstColor = objinstance.setIstColor,

        label = true
    }

    initObject(self, obj)

    return obj
end

function sceneinstance:createTextBox(x, y, sizeX, sizeY, text, bg, fg, centerX, centerY, spacingY, autoNewline, tool)
    text = tostring(text or "")
    bg = bg and formatColor(bg)
    fg = formatColor(fg, true)

    local obj = {
        calculateSize = gui.calculateSizeByText,

        x = x,
        y = y,
        sizeX = sizeX,
        sizeY = sizeY,
        text = text,
        bg = bg,
        fg = fg,

        centerX = centerX,
        centerY = centerY,
        spacingY = spacingY,
        autoNewline = autoNewline,
        tool = tool,

        setText = objinstance.setText,
        setBgColor = objinstance.setBgColor,
        setFgColor = objinstance.setFgColor,
        setIbgColor = objinstance.setIbgColor,
        setIfgColor = objinstance.setIfgColor,
        setStColor = objinstance.setStColor,
        setIstColor = objinstance.setIstColor,

        textBox = true,
        disable = true
    }
    initObject(self, obj)

    return obj
end

function sceneinstance:createText(x, y, text, fg)
    text = tostring(text or "")
    fg = formatColor(fg)

    local obj = {
        x = x,
        y = y,
        text = text,
        fg = fg,

        setText = objinstance.setText,
        setFgColor = objinstance.setFgColor,
        setIfgColor = objinstance.setIfgColor,

        isText = true,
        disable = true
    }
    initObject(self, obj)
    
    return obj
end

-----------------------------------gui instance

local guiinstance = {}

--legacy
function guiinstance:setGameLight() end
function guiinstance:getGameLight() end

function guiinstance:tick()
    if not self.scene and self.defaultScene then self.defaultScene:select() end
    if not self.scene then return end

    local tickReturn = self.scene:_tick()

    for obj in pairs(self.scene.updateList) do
        obj:realUpdate()
    end
    self.scene.updateList = {}

    return tickReturn
end

function guiinstance:draw()
    if self.scene then
        self.scene:_draw()
    end
end

function guiinstance:drawForce()
    if self.scene then
        self.scene:_draw(true)
    end
end

function guiinstance:needFlush()
    local needFlushFlag = self.needFlushFlag or (self.scene and self.scene.alwaysRedraw)
    self.needFlushFlag = false
    return needFlushFlag
end

function guiinstance:createScene(color, bgHandle)
    if color and type(color) ~= "function" then
        color = sc.formatColor(color)
    end

    local scene = {
        guiinstance = self,
        display = self.display,
        color = color,
        bgHandle = bgHandle,
        allObjs = {},
        allWindows = {},
        updateList = {},
        objectIntersectionMode = 3,
        sizeX = self.display.getWidth(),
        sizeY = self.display.getHeight(),

        alwaysRedraw = false,
        setObjectIntersectionMode = sceneinstance.setObjectIntersectionMode,
        setAlwaysRedraw = sceneinstance.setAlwaysRedraw,
        isAlwaysRedraw = sceneinstance.isAlwaysRedraw,

        select = sceneinstance.select,
        isSelected = sceneinstance.isSelected,
        update = sceneinstance.update,

        _tick = sceneinstance._tick,
        _draw = sceneinstance._draw
    }
    addSceneFields(scene)

    if not self.defaultScene then
        self.defaultScene = scene
    end

    return scene
end

-----------------------------------gui

gui.intersectionMode = {
    disabled = 0,
    windows = 1,
    fullcheck = 2,
    auto = 3,
    advanced = 4
}

gui.layerMode = {
    auto = 0,
    static = 1,
    topLayer = 2,
    bottomLayer = 3
}

function gui.new(display)
    return {
        display = display,
        needFlushFlag = false,

        tick = guiinstance.tick,
        draw = guiinstance.draw,
        drawForce = guiinstance.drawForce,
        createScene = guiinstance.createScene,
        setGameLight = guiinstance.setGameLight,
        getGameLight = guiinstance.getGameLight,
        needFlush = guiinstance.needFlush,

        intersectionMode = gui.intersectionMode,
        layerMode = gui.layerMode
    }
end

function gui.calculateSizeByText(self)
    if self.text then
        local boxX, boxY = calcTextBox(self, self.text)
        return boxX + self.sceneinstance.defaultPaddingX, boxY + self.sceneinstance.defaultPaddingY
    end
end

function gui.calculateSizeByImage(self)
    if self.img then
        return self.img:getSize()
    end
end

-----------------------------------

return gui
end