function sc_reglib_gui()
local _utf8 = utf8
local objinstance = {}

local arrow1 = {
    "11..",
    "111.",
    "1111",
    "111.",
    "11.."
}

local arrow2 = {
    "1111",
    "1111",
    "1111",
    ".11.",
    ".11."
}

local function rawToBottomLevel(self)
    local pobjs = self.sceneinstance.objs
    if pobjs[1] ~= self then
        local selfIndex
        for i = 1, #pobjs do
            if pobjs[i] == self then
                selfIndex = i
                break
            end
        end
        if selfIndex then
            table.remove(pobjs, selfIndex)
            table.insert(pobjs, 1, self)
            return true
        end
    end
end

local function rawToTopLevel(self)
    local pobjs = self.sceneinstance.objs
    if pobjs[#pobjs] ~= self then
        local selfIndex
        for i = 1, #pobjs do
            if pobjs[i] == self then
                selfIndex = i
                break
            end
        end
        if selfIndex then
            table.remove(pobjs, selfIndex)
            table.insert(pobjs, self)
            return true
        end
    end
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

local function getObjectWidth(self)
    if self.sizeX then
        return self.sizeX
    elseif self.isText then
        return txtLen(self.display, self.text)
    elseif self.isImage then
        return (self.img:getSize())
    end

    return 0
end

local function getObjectHeight(self)
    if self.sizeY then
        return self.sizeY
    elseif self.isText then
        return self.display.getFontHeight()
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

function objinstance:getGridSize()
    return self.gridItemsX, self.gridItemsY
end

function objinstance:getGridItemSize()
    return self.gridItemSizeX, self.gridItemSizeY
end

function objinstance:getGridObject(x, y)
    return self.grid[x][y]
end

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
            gobj.sourceX + (((gobj.sizeX or 0) / 2) - ((self.sizeX or 0) / 2)) + (offsetX or 0),
            gobj.sourceY + (((gobj.sizeY or 0) / 2) - ((self.sizeY or 0) / 2)) + (offsetY or 0)
        )
    else
        self:setPosition(
            (((self.sceneinstance.sizeX or 0) / 2) - ((self.sizeX or 0) / 2)) + (offsetX or 0),
            (((self.sceneinstance.sizeY or 0) / 2) - ((self.sizeY or 0) / 2)) + (offsetY or 0)
        )
    end
end

function objinstance:setCenterX(offsetX, gobj)
    if gobj then
        self:setPositionX(
            gobj.sourceX + (((gobj.sizeX or 0) / 2) - ((self.sizeX or 0) / 2)) + (offsetX or 0)
        )
    else
        self:setPositionX(
            (((self.sceneinstance.sizeX or 0) / 2) - ((self.sizeX or 0) / 2)) + (offsetX or 0)
        )
    end
end

function objinstance:setCenterY(offsetY, gobj)
    if gobj then
        self:setPositionY(
            gobj.sourceY + (((gobj.sizeY or 0) / 2) - ((self.sizeY or 0) / 2)) + (offsetY or 0)
        )
    else
        self:setPositionY(
            (((self.sceneinstance.sizeY or 0) / 2) - ((self.sizeY or 0) / 2)) + (offsetY or 0)
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
    offset = offset or 1
    self:setOffsetPosition(gobj, -getObjectWidth(self) - offset, 0)
end

function objinstance:setRight(gobj, offset)
    offset = offset or 1
    self:setOffsetPosition(gobj, getObjectWidth(gobj) + offset, 0)
end

function objinstance:setUp(gobj, offset)
    offset = offset or 1
    self:setOffsetPosition(gobj, 0, -getObjectHeight(self) - offset)
end

function objinstance:setDown(gobj, offset)
    offset = offset or 1
    self:setOffsetPosition(gobj, 0, getObjectHeight(gobj) + offset)
end


function objinstance:setBottomLayer(gobj)
    rawToBottomLevel(self)
end

function objinstance:setTopLayer(gobj)
    rawToTopLevel(self)
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

function objinstance:setFontParameters(customFont, fontSizeX, fontSizeY)
    self.guiinstance.customFontEnable = true
    self.customFont = customFont
    self.fontSizeX = fontSizeX
    self.fontSizeY = fontSizeY
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

function objinstance:clear(color, minWidth, minHeight)
    if not self.sceneinstance:isSelected() then return end
    if not color and self.sceneinstance.color and type(self.sceneinstance.color) ~= "function" then
        color = self.sceneinstance.color
    end
    color = formatColor(color, true)

    self.display.fillRect(self.x, self.y, math.max(minWidth or 0, getObjectWidth(self)), math.max(minHeight or 0, getObjectHeight(self)), color)
end

function objinstance:getDisplaySize()
    return getObjectWidth(self), getObjectHeight(self)
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
        local button = self:createButton(posX, 0, sizeX, self.up_size, ...)
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
        local object = self[contructorname](self, posX, 0, sizeX, self.up_size, ...)
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

local function updateLayerMode(self)
    if self.layerMode == 2 then
        self:setTopLayer()
    elseif self.layerMode == 3 then
        self:setBottomLayer()
    end
end

function objinstance:setLayerMode(mode)
    self.layerMode = mode
    updateLayerMode(self)
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
    if not self.draggable or self.layerMode ~= 0 then
        return
    end
    
    return rawToTopLevel(self)
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
    local selected = click[1] >= self.x and click[2] >= self.y and click[1] < (self.x + self.sizeX) and click[2] < (self.y + self.sizeY)
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
            for i = #objectList, 1, -1 do
                local obj = objectList[i]
                sc.yield()
                if obj:_tick(click) then
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

    local oldFont, oldScaleX, oldScaleY
    if self.guiinstance.customFontEnable then
        oldFont = self.display.getFont()
        oldScaleX, oldScaleY = self.display.getFontScale()
        self.display.setFont(self.customFont)
        if self.fontSizeX and self.fontSizeY then
            self.display.setFontSize(self.fontSizeX, self.fontSizeY)
        else
            self.display.setFontScale(1, 1)
        end
    end

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
        self.display.fillRect(self.x, self.y, self.sizeX, self.sizeY, bg or self.sceneinstance.color or 0)
        local graphic = sc.lib_require("graphic")
        if self.textBox then
            graphic.textBox(self.display, self.x + 1, self.y + 1, self.sizeX - 1, self.sizeY, self.text, fg, self.centerX, self.centerY, self.spacingY, self.autoNewline, self.tool)
        else
            graphic.textBox(self.display, self.x, self.y, self.sizeX, self.sizeY, self.text, fg, true, true)
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
                local fontX = self.display.getFontHeight()
                drawBitmap(self.display, self.x + 1, self.y + 1, self.up_hide and arrow1 or arrow2, self.up_textcolor)
                self.display.drawText(self.x + 6, self.y + 1, self.up_title, self.up_textcolor)
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

    if self.guiinstance.customFontEnable then
        self.display.setFont(oldFont)
        self.display.setFontSize(oldScaleX, oldScaleY)
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

    if not clean then
        for i = #self.allObjs, 1, -1 do
            sc.yield()

            local obj = self.allObjs[i]
            
            if obj.isWindow then
                updateLayerMode(obj)
            end
        end
    end

    local elementCapture = false
    local elementCaptureList = {}
    if not self.bgHandleUse then
        for i = #self.objs, 1, -1 do
            local obj = self.objs[i]
            sc.yield()
            if obj:_tick(click) then
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
            if click[3] == "released" then
                self.bgHandleUse = nil
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

local function initObject(self, obj)
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
    obj.setFontParameters = objinstance.setFontParameters
    obj.setBottomLayer = objinstance.setBottomLayer
    obj.setTopLayer = objinstance.setTopLayer
    obj.getDisplaySize = objinstance.getDisplaySize
    obj.isVisible = objinstance.isVisible
    obj.updateParent = objinstance.updateParent
    obj.realUpdate = objinstance.realUpdate

    obj.disable = obj.disable or false
    obj.invisible = obj.invisible or false
    obj.autoViewport = obj.autoViewport or false

    -- auto pos & size
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
        autoX, autoY = 1, (self.up_size or 0) + 1
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
        obj.sizeX = obj.sizeX or autoSX or (self.sizeX - obj.x - 1)
        obj.sizeY = obj.sizeY or autoSY or (self.sizeY - obj.y - 1)
    end
    obj.sourceX = obj.x
    obj.sourceY = obj.y
    remathElementInWindowPos(obj)
end

local function addSceneFunctions(sceneOrWindow)
    sceneOrWindow.createButton = sceneinstance.createButton
    sceneOrWindow.createImage = sceneinstance.createImage
    sceneOrWindow.createText = sceneinstance.createText
    sceneOrWindow.createLabel = sceneinstance.createLabel
    sceneOrWindow.createTextBox = sceneinstance.createTextBox
    sceneOrWindow.createCustom = sceneinstance.createCustom
    sceneOrWindow.createWindow = sceneinstance.createWindow
    sceneOrWindow.createGrid = sceneinstance.createGrid
end

function sceneinstance:createGrid(x, y, sizeX, sizeY, gridItemsX, gridItemsY, defaultObjectSizeXmul, defaultObjectSizeYmul)
    local window = self:createWindow(x, y, sizeX, sizeY)
    window.gridItemsX = gridItemsX or 1
    window.gridItemsY = gridItemsY or 1
    window.gridItemSizeX = math.floor(window.sizeX / window.gridItemsX)
    window.gridItemSizeY = math.floor(window.sizeY / window.gridItemsY)
    window.getGridSize = objinstance.getGridSize
    window.getGridItemSize = objinstance.getGridItemSize
    window.getGridObject = objinstance.getGridObject
    window.defaultObjectSizeXmul = defaultObjectSizeXmul or 1
    window.defaultObjectSizeYmul = defaultObjectSizeYmul or 1
    window.isGrid = true
    window.grid = {}
    for i = 0, window.gridItemsX do
        window.grid[i] = {}
    end
    return window
end

function sceneinstance:createWindow(x, y, sizeX, sizeY, color)
    local obj = {
        x = x,
        y = y,
        sizeX = sizeX,
        sizeY = sizeY,
        color = color,
        draggable = false,
        layerMode = 0,
        objs = {},
        allObjs = self.allObjs,
        allWindows = self.allWindows,
        windowNesting = (self.windowNesting or 0) + 1,

        setDraggable = objinstance.setDraggable,
        setAutoViewport = objinstance.setAutoViewport,
        setLayerMode = objinstance.setLayerMode,
        setColor = objinstance.setColor,
        isSelected = objinstance.isSelected,
        upPanel = objinstance.upPanel,
        panelButton = objinstance.panelButton,
        panelObject = objinstance.panelObject,
        minimize = objinstance.minimize,

        isWindow = true
    }
    addSceneFunctions(obj)
    initObject(self, obj)
    table.insert(self.objs, obj)
    table.insert(self.allObjs, obj)
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
        obj.layerMode = cls.layerMode or 1
        obj.handlerLocalPosition = cls.handlerLocalPosition
        obj.handlerAllClicks = cls.handlerAllClicks
        obj.handlerOutsideDrag = cls.handlerOutsideDrag
        obj.autoViewport = cls.autoViewport
        if cls.methods then
            for k, v in pairs(cls.methods) do
                obj[k] = v
            end
        end
        if cls.init then
            cls.init(obj, ...)
        end
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
        onDestroy_fromClass = cls.destroyHandler
    }
    initObject(self, obj)
    if cls.methods then
        for k, v in pairs(cls.methods) do
            obj[k] = v
        end
    end
    if cls.init then
        cls.init(obj, ...)
    end
    table.insert(self.objs, obj)
    table.insert(self.allObjs, obj)
    return obj
end

function sceneinstance:createButton(x, y, sizeX, sizeY, toggle, text, bg, fg, bg_press, fg_press)
    text = text or ""
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

    local boxX, boxY
    if text and (not sizeX or not sizeY) and not self.isGrid then
        boxX, boxY = self.display.calcTextBox(text)
    end

    if not sizeX and boxX then
        sizeX = boxX + 2
    end

    if not sizeY and boxY then
        sizeY = boxY + 2
    end

    local obj = {
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

        old_toggle_state = false,
        state = false,
        button = true
    }
    initObject(self, obj)
    table.insert(self.objs, obj)
    table.insert(self.allObjs, obj)
    return obj
end

function sceneinstance:createImage(x, y, img)
    local obj = {
        x = x,
        y = y,
        img = img,

        updateImage = objinstance.updateImage,

        isImage = true
    }
    initObject(self, obj)
    table.insert(self.objs, obj)
    table.insert(self.allObjs, obj)
    return obj
end

function sceneinstance:createLabel(x, y, sizeX, sizeY, text, bg, fg)
    text = text or ""
    bg = formatColor(bg)
    fg = formatColor(fg, true)

    local obj = {
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

        label = true
    }
    initObject(self, obj)
    table.insert(self.objs, obj)
    table.insert(self.allObjs, obj)
    return obj
end

function sceneinstance:createTextBox(x, y, sizeX, sizeY, text, bg, fg, centerX, centerY, spacingY, autoNewline, tool)
    text = text or ""
    bg = bg and formatColor(bg)
    fg = formatColor(fg, true)

    local obj = {
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

        textBox = true,
        disable = true
    }
    initObject(self, obj)
    table.insert(self.objs, obj)
    table.insert(self.allObjs, obj)
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

        isText = true,
        disable = true
    }
    initObject(self, obj)
    table.insert(self.objs, obj)
    table.insert(self.allObjs, obj)
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
        objs = {},
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
    addSceneFunctions(scene)

    if not self.defaultScene then
        self.defaultScene = scene
    end

    return scene
end

-----------------------------------gui

local gui = {}

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

        intersectionMode = {
            disabled = 0,
            windows = 1,
            fullcheck = 2,
            auto = 3,
            advanced = 4
        },

        layerMode = {
            auto = 0,
            static = 1,
            topLayer = 2,
            bottomLayer = 3
        }
    }
end

-----------------------------------

return gui
end