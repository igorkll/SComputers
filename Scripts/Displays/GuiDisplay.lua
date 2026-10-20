dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/Displays/modules/sendStack.lua")
dofile("$CONTENT_DATA/Scripts/Displays/modules/lagCheck.lua")
GuiDisplay = class(canvasAPI.canvasService)
GuiDisplay.maxParentCount = 1
GuiDisplay.maxChildCount = 0
GuiDisplay.connectionInput = sm.interactable.connectionType.composite
GuiDisplay.colorNormal = sm.color.new(0xbbbb1aff)
GuiDisplay.colorHighlight = sm.color.new(0xecec1fff)
GuiDisplay.componentType = "display"

local stackChecksum = canvasAPI.stackChecksum
local needPushStack = canvasAPI.needPushStack
local sendStack = displays_sendStack
local lagCheck = displays_lagCheck

-- Константы окна холста (должны совпадать с client_onCreate)
local GUI_SIZE = 500
local GUI_PADDING = 25

-- ============================================================
-- СЕРВЕРНАЯ ЧАСТЬ (без изменений)
-- ============================================================

function GuiDisplay:server_onCreate()
    self.lastLagScore = 0
    self.dataTunnel = {}
    self.width = self.data.x
    self.height = self.data.y
    self.mulSize = self.width * self.height
    local allowHoloAPI = false

    local allowSetResolution
    if self.data.dynamicResolution then
        allowSetResolution = true
    else
        local maxSide = math.max(self.width, self.height)
        allowSetResolution = {
            maxPixels = self.width * self.height,
            maxWidth = maxSide,
            maxHeight = maxSide
        }
    end

    self.api, self.internalApi = canvasAPI.createScriptableApi(self.width, self.height, self.dataTunnel, function ()
        self.lastComputer = sc.lastComputer
    end, {
        getRealBuffer = function(...)
            if not self.drawer then return end
            return self.drawer.getRealBuffer(...)
        end,
        getNewBuffer = function(...)
            if not self.drawer then return end
            return self.drawer.getNewBuffer(...)
        end
    }, (self.data.glass or self.data.unlockGlass) and canvasAPI.materialList or canvasAPI.materialListWithoutGlass, self.data.glass and 0 or 1, allowHoloAPI, allowSetResolution)

    self.api.noCameraEncode = true
    self._flush = self.api.flush
    self._forceFlush = self.api.forceFlush

    function self.api.flush()
        self.flushCallFlag = true
    end
    self.api.update = self.api.flush

    function self.api.forceFlush()
        self.flushCallFlag = true
        self.flushCallForce = true
    end

    self.touchscreen = canvasAPI.addTouch(self.api, self.dataTunnel)

    self.api.isAllow = function()
        return self:isAllow()
    end

    self.api.getAudience = function()
        if self._getAudienceCount then
            return self._getAudienceCount()
        end
        return 0
    end

    local directList = {}
    for name, obj in pairs(self.api) do
        if type(obj) == "function" and name ~= "flush" and name ~= "forceFlush" and name ~= "update" then
            directList[name] = true
        end
    end

    self.interactable.publicData = {
        sc_component = {
            type = GuiDisplay.componentType,
            api = self.api,
            directList = directList
        }
    }

    sc.componentsBackend[self.api] = self
end

function GuiDisplay:server_onFixedUpdate()
    local computerConnected = sm.scomputers.isComputerConnected(self.interactable)
    if not computerConnected and self.sv_oldComputerConnected then
        self.internalApi.setForceFrame()
    end
    self.sv_oldComputerConnected = computerConnected

    if self.flushCallFlag then
        if self.flushCallForce then
            self._forceFlush()
        else
            self._flush()
        end
        self.flushCallFlag = nil
        self.flushCallForce = nil
    end

    lagCheck(self)

    self.dataTunnel.scriptableApi_update()

    if self:isAllow() then
        if self.allow_send then
            if self.dataTunnel.dataUpdated then
                if self.dataTunnel.resolutionChanged then
                    self:sv_canvasRequest()
                    self.dataTunnel.resolutionChanged = nil
                end

                self.network:sendToClients("cl_dataTunnel", canvasAPI.minimizeDataTunnel(self.dataTunnel))
                self.allow_send = nil
                self.dataTunnel.dataUpdated = nil
                self.dataTunnel.display_reset = nil
            end

            if self.dataTunnel.display_flush then
                sendStack(self, "cl_pushStack", self.dataTunnel.display_stack, self.dataTunnel.display_forceFlush, self.dataTunnel.display_forceForceFlush)

                self.dataTunnel.display_flush()
                self.dataTunnel.display_stack = nil
                self.dataTunnel.display_flush = nil
                self.dataTunnel.display_forceFlush = nil
                self.dataTunnel.display_forceForceFlush = nil
                self.allow_send = nil
            end
        end
    elseif self.dataTunnel.display_flush then
        self.dataTunnel.display_flush()
        self.dataTunnel.display_stack = nil
        self.dataTunnel.display_flush = nil
        self.dataTunnel.display_forceFlush = nil
        self.dataTunnel.display_forceForceFlush = nil
    end
end

function GuiDisplay:sv_dataRequest()
    self.tryPacket = nil
    self.dataTunnel.dataUpdated = true
    self.dataTunnel.display_forceFlush = true
    self.dataTunnel.display_forceForceFlush = true
end

function GuiDisplay:sv_recvPress(data)
    self.touchscreen(data)
end

function GuiDisplay:sv_canvasRequest(_, caller)
    self.width = self.api.getWidth()
    self.height = self.api.getHeight()
    self.mulSize = self.width * self.height

    local data = {
        width = self.width,
        height = self.height
    }

    if caller then
        self.network:sendToClient(caller, "cl_canvasResponse", data)
    else
        self.network:sendToClients("cl_canvasResponse", data)
    end
end

function GuiDisplay:isAllow()
    if not sc.restrictions then return true end
    return self.width * self.height <= (sc.restrictions.maxDisplays * sc.restrictions.maxDisplays)
end

-- ============================================================
-- КЛИЕНТСКАЯ ЧАСТЬ
-- ============================================================

local formatColorToSmallNumber = canvasAPI.formatColorToSmallNumber

function GuiDisplay:client_onCreate()
    self._old_res_x = self.data.x
    self._old_res_y = self.data.y

    self.canvasGUI = canvasGUI.createGuiCanvas(self.data.x, self.data.y, GUI_SIZE, GUI_SIZE, GUI_PADDING, "Gui Display - BETA")

    self.drawer = canvasAPI.createDrawer(self.data.x, self.data.y, function(x, y, color, background)
        local fColor = formatColorToSmallNumber(color)
        local fBackground = formatColorToSmallNumber(background)
        if fBackground ~= self.oldBackground then
            self.canvasGUI.clear(fBackground)
            self.oldBackground = fBackground
        end
        self.canvasGUI.setPixel(x, y, fColor)
    end, nil, nil, nil, nil, nil, true)

    self.network:sendToServer("sv_dataRequest")

    self.c_dataTunnel = {}
    self.dragging = {interact=false, tinker=false, interactLastPos={x=-1, y=-1}, tinkerLastPos={x=-1, y=-1}}

    self.network:sendToServer("sv_canvasRequest")

    -- ========================================================
    -- СЕНСОРНЫЙ СЛОЙ: GuiInterface с кнопкой на весь экран
    -- ========================================================
    -- Создаём прозрачный GUI-интерфейс из layout-файла,
    -- который содержит одну кнопку "CanvasBackplate" на весь экран.
    -- Путь к layout: $CONTENT_DATA/Gui/Layouts/CanvasTouch.layout
    -- (см. пример layout-файла в ответе ниже)
    self.touchGui = sm.gui.createGuiFromLayout(
        "$CONTENT_DATA/Gui/Layouts/CanvasTouch.layout",
        false,
        {
            isHud = true,
            isInteractive = true,
            needsCursor = true,
            hidesHotbar = false,
            isOverlapped = true
        }
    )

    if self.touchGui then
        self.touchGui:setButtonCallback("CanvasBackplate", "cl_onCanvasClick")
    end

    -- Виртуальный курсор (в пикселях экрана)
    self.cursorX = nil
    self.cursorY = nil
    local screenW, screenH = sm.gui.getScreenSize()
    self.screenW = screenW or 1920
    self.screenH = screenH or 1080
end

function GuiDisplay:client_onInteract(_, state)
    if state then
        self.canvasGUI.open()
        -- Активируем сенсорный слой, когда открыт GUI
        if self.touchGui and not self.touchGui:isActive() then
            self.touchGui:open()
        end
    end
end

function GuiDisplay:client_onFixedUpdate()
    local computerConnected = sm.scomputers.isComputerConnected(self.interactable)
    if not computerConnected and self.oldComputerConnected then
        self.drawer.pushStack({canvasAPI.draw.clear, 0})
        self.drawer.flush()
        self.canvasGUI.flush()
    end
    self.oldComputerConnected = computerConnected

    self.canvasGUI.update()
    local isRendering = self.canvasGUI.isRendering()
    self:canvasService(isRendering)

    if not isRendering then
        if self.touchGui and self.touchGui:isActive() then
            self.touchGui:close()
        end
    end

    -- Обновление виртуального курсора, пока GUI активен
    if self.touchGui and self.touchGui:isActive() then
        if not self.cursorX then
            -- Стартуем из центра экрана при первом тике
            self.cursorX = self.screenW / 2
            self.cursorY = self.screenH / 2
        end
        local dx, dy = sm.localPlayer.getMouseDelta()
        if dx then
            self.cursorX = self.cursorX + dx
            self.cursorY = self.cursorY + dy
            -- Клампим в пределах экрана
            if self.cursorX < 0 then self.cursorX = 0 elseif self.cursorX > self.screenW then self.cursorX = self.screenW end
            if self.cursorY < 0 then self.cursorY = 0 elseif self.cursorY > self.screenH then self.cursorY = self.screenH end
        end
    else
        self.cursorX = nil
        self.cursorY = nil
    end

    if self.dragging.interact then
        -- self:cl_onClick(1, "drag")  -- при необходимости можно добавить drag
    elseif self.dragging.tinker then
        -- self:cl_onClick(2, "drag")
    end
end

function GuiDisplay:client_onDestroy()
    if self.touchGui then
        self.touchGui:close()
        self.touchGui = nil
    end
    self.canvasGUI.destroy()
end

-- Callback клика по кнопке "CanvasBackplate"
function GuiDisplay:cl_onCanvasClick(buttonName)
    if not self.cursorX or not self.cursorY then return end

    -- Вычисляем область холста на экране
    local panelX = (self.screenW - GUI_SIZE) / 2
    local panelY = (self.screenH - GUI_SIZE) / 2
    local canvasX = self.cursorX - panelX - GUI_PADDING
    local canvasY = self.cursorY - panelY - GUI_PADDING
    local canvasW = GUI_SIZE - GUI_PADDING * 2
    local canvasH = GUI_SIZE - GUI_PADDING * 2

    if canvasX < 0 or canvasY < 0 or canvasX >= canvasW or canvasY >= canvasH then
        return -- клик мимо холста
    end

    local rx = self._old_res_x or self.data.x
    local ry = self._old_res_y or self.data.y
    local px = math.floor(canvasX * rx / canvasW)
    local py = math.floor(canvasY * ry / canvasH)

    local player = sm.localPlayer.getPlayer()
    if player then
        self.network:sendToServer("sv_recvPress", {
            x = px,
            y = py,
            state = "pressed",
            button = 1,
            nickname = player.name
        })
    end
end

function GuiDisplay:cl_canvasResponse(data)
    if sm.isHost then return end
    self.width, self.height = data.width, data.height
end

function GuiDisplay:cl_pushStack(stack)
    if self.disableState or not sm.scomputers.isComputerConnected(self.interactable) then
        return
    end

    if self.sendedData_cl_pushStack then
        if self.sendedData_cl_pushStack.force or needPushStack(self.canvasGUI, self.c_dataTunnel, sc.deltaTime) then
            local startTime = os.clock()
            self.drawer.pushStack(self.sendedData_cl_pushStack)
            self.drawer.flush(self.sendedData_cl_pushStack.forceForce)
            self.canvasGUI.flush()
            self.sendedData_cl_pushStack = nil
            self:lagDetector(os.clock() - startTime, sc.clockLagMul)
        end
        self.sendedData_cl_pushStack = nil
        return
    elseif self.stack and self.stack[1][1] ~= canvasAPI.draw.clear then
        for _, action in ipairs(stack) do
            table.insert(self.stack, action)
        end
    else
        self.stack = stack
    end

    if stack.flush and (stack.force or needPushStack(self.canvasGUI, self.c_dataTunnel, sc.deltaTime)) then
        local startTime = os.clock()
        self.drawer.pushStack(self.stack)
        self.drawer.flush(stack.forceForce)
        self.canvasGUI.flush()
        self.stack = nil
        self:lagDetector(os.clock() - startTime, sc.clockLagMul)
    end
end

function GuiDisplay:cl_dataTunnel(data)
    self.c_dataTunnel = data
    self.drawer.pushDataTunnelParams(data)
    if data.res_x ~= self._old_res_x or data.res_y ~= self._old_res_y then
        self.drawer.setDrawerResolution(data.res_x, data.res_y)
        self.canvasGUI.resize(data.res_x, data.res_y)
        self._old_res_x = data.res_x
        self._old_res_y = data.res_y
    end
end