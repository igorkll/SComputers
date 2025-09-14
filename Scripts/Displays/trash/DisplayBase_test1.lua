-- debug
debug_out = true
debug_printeffects = false
debug_disabletext = false
debug_disableoptimize = false
debug_raycast = false
debug_offset = true
debug_disableEffectsBuffer = false
debug_disableDBuff = false
debug_disableForceNativeRender = false
debug_disableUpdateColor = false

--settings
mul_ray_fov = 2

--code
if __displayBaseLoaded then return end
__displayBaseLoaded = true

dofile "$CONTENT_DATA/Scripts/Config.lua"

local vnetwork = vnetwork
local sc = sc
local sm = sm
local probability = probability
local checkArg = checkArg

sc.display.drawType = {
    clear = 0,
    drawPixel = 1,
    drawRect = 2,
    fillRect = 3,
    drawCircle = 4,
    fillCircle = 5,
    drawLine = 6,
    drawText = 7,
    optimize = 8,
}

local tableChecksum = tableChecksum

local floor = math.floor
local function nRound(num)
    return floor(num + 0.5)
end

--local _utf8 = string
local splitByMaxSize = splitByMaxSize
local string = string
local _utf8 = utf8
local sc_display_drawType = sc.display.drawType
local constrain, mathDist = constrain, mathDist

sc.display.PIXEL_SCALE = 0.0072
sc.display.RENDER_DISTANCE = 15
sc.display.SKIP_RENDER_DT = 1 / 30
sc.display.SKIP_RENDER_DT_ALL = 1 / 20
sc.display.deltaTime = 0

sc.display.quad = {}

local oopsUuid = sm.uuid.new("c3931873-eadc-4e46-a575-0a369ae01202")
local cursorUuid = sm.uuid.new("77e46b76-0b2e-4a00-86e4-d030b8d9b59d")

local RENDER_DISTANCE = sc.display.RENDER_DISTANCE

local sm_camera_getRotation = sm.camera.getRotation
local sm_camera_getFov = sm.camera.getFov

local sm_isHost = sm.isHost
local sm_effect_createEffect = sm.effect.createEffect
local sm_quat_fromEuler = sm.quat.fromEuler

local table_insert = table.insert
local table_remove = table.remove

local tostring = tostring
local tonumber = tonumber
local math_rad = math.rad
local math_random = math.random
local math_floor = math.floor
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
--local string_sub = string.sub
local string_byte = string.byte
--local table_pack = table.pack

local sm_exists = sm.exists
local ipairs = ipairs
local pairs = pairs
local print = print
local type = type
local unpack = unpack
local getCurrentTick = sm.game.getCurrentTick
local sm_localPlayer = sm.localPlayer
local sm_localPlayer_getPlayer = sm_localPlayer.getPlayer
local os_clock = os.clock

local sm_vec3 = sm.vec3
local util_clamp = sm.util.clamp
local sm_vec3_new = sm.vec3.new
local sc_display_PIXEL_SCALE = sc.display.PIXEL_SCALE

local formatColor = sc.formatColor
--local formatColorStr = sc.formatColorStr

local effectsData = {}

local emptyEffect = sm.effect.createEffect(sc.getEffectName())
local effect_setParameter = emptyEffect.setParameter
local effect_stop = emptyEffect.stop
local effect_destroy = emptyEffect.destroy
local effect_start = emptyEffect.start
local effect_isDone = emptyEffect.isDone
local effect_isPlaying = emptyEffect.isPlaying
local effect_setScale = emptyEffect.setScale
local effect_setOffsetPosition = emptyEffect.setOffsetPosition
local effect_setOffsetRotation = emptyEffect.setOffsetRotation
--effect_stop(emptyEffect)
effect_destroy(emptyEffect)

local function effect_destroyAndUnreg(effect)
    effectsData[effect.id] = nil
    effect_destroy(effect)
end

local sm_camera_getPosition = sm.camera.getPosition

local quad_visibleRot = sm_quat_fromEuler(sm_vec3.zero())
local quad_hideRot = sm_quat_fromEuler(sm_vec3_new(0, 180, 0))

local quad_displayOffset = sm_vec3_new(-0.125, 0, 0)
--local quad_offsetRotation = sm_quat_fromEuler(sm_vec3_new(0, 0, 0))

local sm_physics_multicast = sm.physics.multicast
local sm_physics_filter_dynamicBody = sm.physics.filter.dynamicBody
local sm_physics_filter_staticBody = sm.physics.filter.staticBody
local filter_body = sm_physics_filter_dynamicBody + sm_physics_filter_staticBody

local function cl_displayRaycast(self, position, r)
    if _G.raycastCache and (getCurrentTick() - _G.raycastCache.time) < 20 then
        return _G.raycastCache.shapes
    end

    --[[
    local shapes = {}
    local maxoffset = math.pi / 3
    for x = -maxoffset, maxoffset, maxoffset / 10 do
        for y = -maxoffset, maxoffset, maxoffset / 10 do
            local offset = sm.vec3.new(
                0, --why does it work relative to the world and not relative to the player?
                0, --why does it work relative to the world and not relative to the player?
                y
            )
            

            local ok, result = sm.localPlayer.getRaycast(r, nil, sm.localPlayer.getDirection() + offset)
            
            if result.pointWorld then
                sm.debris.createDebris(
                    sm.uuid.new("d3db3f52-0a8d-4884-afd6-b4f2ac4365c2"),
                    result.pointWorld,
                    sm.quat.fromEuler(sm.vec3.new(0, 0, 0)),
                    sm.vec3.zero(),
                    sm.vec3.zero(),
                    sm.color.new(1, 0, 0),
                    1 / 40
                )
            end
            if ok and result and result.type == "body" then
                --sm.debugDraw.addSphere("11", result.pointWorld, 0.5, sm.color.new(1, 0, 0))
                shapes[result:getShape()] = result
            end
        end
    end
    ]]

    ----createRays
    local rotation = sm_camera_getRotation() * sm_quat_fromEuler(sm_vec3_new(90, 180, 0))

    local resolutionX, resolutionY = sc.restrictions.rays, sc.restrictions.rays
    local distance = r
    local fov = math_rad(sm_camera_getFov() * mul_ray_fov)
    local rays = {}
    local rays_idx = 1
    local u, v, direction
    for x = 1, resolutionX do
        for y = 1, resolutionY do
            u = ( x / resolutionX - 0.5 ) * fov
            v = ( y / resolutionY - 0.5 ) * fov

            direction = rotation * sm_vec3_new(-u, -v, 1)

            rays[rays_idx] = {
                type = "ray",
                startPoint = position,
                endPoint = position + direction * distance,
                mask = filter_body
            }
            rays_idx = rays_idx + 1
         end
    end

    ----raycasting
    local casts = sm_physics_multicast(rays)

    local shapes, shape = {}
    for _, data in pairs(casts) do
        if data[1] then
            shape = data[2]:getShape()
            if shape then
                shapes[shape] = data[2]
            end

            if debug_raycast then
                sm.debris.createDebris(
                    sm.uuid.new("d3db3f52-0a8d-4884-afd6-b4f2ac4365c2"),
                    data[2].pointWorld,
                    sm.quat.fromEuler(sm.vec3.new(0, 0, 0)),
                    sm.vec3.zero(),
                    sm.vec3.zero(),
                    sm.color.new(1, 0, 0),
                    1 / 40
                )
            end
        end
    end
    
    _G.raycastCache = {shapes = shapes, time = getCurrentTick()}
    return shapes
end

local function debug_print_force(...)
    print(...)
end

local function debug_print(...)
    if debug_out then
        print(...)
    end
end

local sc_display_shapesUuid = sm.uuid.new("708d4a47-7de7-49df-8ba3-e58083c2610e")
--local sc_display_shapesUuidGlass = sm.uuid.new("3d11dd1d-1296-414b-a2d9-101e876c022f")
local sc_display_shapesUuidGlass = sm.uuid.new("75708339-6420-41e4-88a0-fbc210826c14")

local sc_getEffectName = sc.getEffectName

local quadIntersectsCircle, quad_createNode, quad_createRoot, quad_updateEffectColor
local quad_createEffect, quad_effectHide, quad_effectShow, quad_destroy, quad_destroyEffect
local quad_destroyChildren, quad_optimize, quad_split
local quad_findChild
--local quad_treeMultiSetColor
local quad_treeSetColor
local quad_treeFillRect
local quad_treeFillCircle
local quad_treeShow
local quad_treeHide
local quad_rootRealShow
local quad_rootRealHide
local sc_display_client_clear
local sc_display_client_drawPixelForce
local sc_display_client_drawPixel
local sc_display_client_drawRect
local sc_display_client_fillRect
local sc_display_client_drawCircle
local sc_display_client_fillCircle
local sc_display_client_drawLine
local sc_display_client_optimize

local sm_color_new = sm.color.new
local black = sm_color_new("000000ff")
local white = sm_color_new("ffffffff")
local oopsColor = sm_color_new("ffff00ff")

local font_chars = sc.display.font.optimized
local font_width = sc.display.font.width
local font_height = sc.display.font.height

local total_effects = 0

--[[
local function pointInQuad(x, y, qx, qy, qs)
    return (x >= qx and x < qx + qs) and (y >= qy and y < qy + qs)
end

local function pointInCircle(x, y, cx, cy, cr)
    local dx = cx - x
    local dy = cy - y

    return dx*dx + dy*dy <= cr*cr
end
]]

local function quadInRect(qx, qy, qs, rx, ry, rw, rh)
    return (qx >= rx and qx + qs <= rx + rw) and (qy >= ry and qy + qs <= ry + rh)
end

local quadInCircle = quadInCircle

local function quadIntersectsRect(qx, qy, qs, rx, ry, rw, rh)
    return (qx < rx + rw and qx + qs > rx) and (qy < ry + rh and qy + qs > ry)
end

function quadIntersectsCircle(qx, qy, qs, cx, cy, cr)
    local clamp = util_clamp
    local closestX = clamp(cx, qx, qx + qs)
    local closestY = clamp(cy, qy, qy + qs)

    local dx = cx - closestX
    local dy = cy - closestY

    return dx*dx + dy*dy <= cr*cr
end

function quad_createNode(parent, x, y, sizeX, sizeY, color)
    local node =  {
        x = x,
        y = y,
        sizeX = sizeX,
        sizeY = sizeY,
        size = math_max(sizeX, sizeY),
        children = nil,
        parent = parent,
        effect = nil,
        color = color,
        root = parent.root,
        display = parent.root.display,
        --uroot = parent.root.display.quadTree
    }

    --[[
    print(color, parent.root.display.lastLastClearColor, color == parent.root.display.lastLastClearColor)
    if color == parent.root.display.lastLastClearColor then
        node.effect = quad_createEffect(node.root, x, y, sizeX, sizeY)
        --quad_updateEffectColor(node)
        effect_setParameter(node.effect, "color", sm.color.new(1, 0, 0))
        effect_setScale(node.effect, sm.vec3.new(0.01, 0.01, 0.01))
        return node
    end
    ]]

    if color ~= parent.root.display.lastLastClearColor or parent.root.display.scriptableObject.data.noDoubleEffect then
        node.effect = quad_createEffect(node.root, x, y, sizeX, sizeY)
        quad_updateEffectColor(node, true)
    end

    --if parent.root.display.isRendering then
    --    quad_treeShow(node)
    --end
    
    return node
end

function quad_createRoot(display, x, y, size, maxX, maxY)
    local node = {
        x = x,
        y = y,
        size = size,
        maxX = maxX,
        maxY = maxY,
        sizeX = maxX,
        sizeY = maxY,
        children = nil,
        parent = nil,
        effect = nil,
        color = nil,
        display = display,
        bufferedEffects = {},
        bf_idx = 0,
        allEffects = {}
    }

    node.root = node
    if not display.scriptableObject.data.noDoubleEffect then
        node.back_effect = quad_createEffect(node, x, y, maxX, maxY, 0.0005, true)
    end

    --node.effect = quad_createEffect(node, x, y, maxX, maxY)

    --if display.isRendering then
    --    quad_treeShow(node)
    --end

    --node.uroot = node
    return node
end

local function raw_set_color(effect, color)
    --local colorChecksum = tableChecksum(color)
    --if effectsData[effect.id][1] ~= color then
        --print("COLORPUSH", effectsData[effect.id][1], color)
    effect_setParameter(effect, "color", color)
    effectsData[effect.id][1] = color
    --end
end

function quad_updateEffectColor(self, force)
    if debug_disableUpdateColor then return end

    --if not self.effect or not sm_exists(self.effect) then return end
    local color = self.color

    --if color ~= self.display.lastLastClearColor or force then
        --effect_setScale(effect, sm.vec3.new(0.02, 0.02, 0.02))

    if color ~= self.root.display.lastLastClearColor or self.root.display.scriptableObject.data.noDoubleEffect then
        if not self.effect then
            self.effect = quad_createEffect(self.root, self.x, self.y, self.sizeX, self.sizeY)
        end

        raw_set_color(self.effect, color)
    else
        if self.effect and sm_exists(self.effect) then
            --effect_destroy(self.effect)
            --self.root.allEffects[self.effect] = nil
            quad_destroyEffect(self)
        end
        self.effect = nil
    end
    --end

    --effect_setParameter(self.effect, "color", color)
end

function quad_destroy(self, removeAll)
    if self.children then
        quad_destroyChildren(self)
    end
    quad_destroyEffect(self)


    if removeAll then
        debug_print("removeAll")
        
        --effect_stop(self.back_effect)
        if self.back_effect then
            effect_destroyAndUnreg(self.back_effect)
        end
        total_effects = total_effects - 1
        for effect in pairs(self.allEffects) do
            if effect and sm_exists(effect) then
                total_effects = total_effects - 1
                --effect_stop(effect)
                effect_destroyAndUnreg(effect)
            end
        end
        self.allEffects = {}
        self.bufferedEffects = {}
        self.bf_idx = 0
    end
end

local function getWidth(self)
    if self.quadTree.rotation == 1 or self.quadTree.rotation == 3 then
        return self.height
    else
        return self.width
    end
end

local function getHeight(self)
    if self.quadTree.rotation == 1 or self.quadTree.rotation == 3 then
        return self.width
    else
        return self.height
    end
end

local quad_alt_hideRot = sm_quat_fromEuler(sm_vec3_new(0, 90, 0))
local quad_alt_visibleRot = sm_quat_fromEuler(sm_vec3_new(0, 180 + 90, 0))


function quad_createEffect(root, x, y, sizeX, sizeY, z, nonBuf, nativeScale, wide, uuid)
    --local attemptRemove

    --::attempt::

    local rmaxX = root.maxX
    local rmaxY = root.maxY
    local reverseX, reverseY, changeXY

    if root.rotation == 1 then
        changeXY = true
        reverseX = true
    elseif root.rotation == 2 then
        reverseX = true
        reverseY = true
    elseif root.rotation == 3 then
        changeXY = true
        reverseY = true
    end

    if changeXY then
        x, y = y, x
        --rmaxX, rmaxY = rmaxY, rmaxX
        --sizeX, sizeY = sizeY, sizeX
    end
    if reverseX then x = (rmaxX - x) - sizeX end
    if reverseY then y = (rmaxY - y) - sizeY end
    
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x > rmaxX then x = rmaxX end
    if y > rmaxY then y = rmaxY end
    if x + sizeX > rmaxX then sizeX = sizeX - ((x + (sizeX)) - rmaxX) end
    if y + sizeY > rmaxY then sizeY = sizeY - ((y + (sizeY)) - rmaxY) end

    local effect
    local display = root.display

    if not nonBuf and root.bf_idx > 0 and not debug_disableEffectsBuffer then
        effect = table_remove(root.bufferedEffects)
        if sm_exists(effect) and effect_isDone(effect) then
            effect_start(effect)
        else
            effect = nil
        end
        root.bf_idx = root.bf_idx - 1
    end
    if not effect then
        --if total_effects < (1050000) then
            --debug_print(effectsNames[currentEffect])

            effect = sm_effect_createEffect(sc_getEffectName(), display.scriptableObject.character or display.scriptableObject.interactable)
            --effect = {stop = function() end, start = function() end, destroy = function() end,
            --setScale = function() end, setOffsetPosition = function() end, setOffsetRotation = function() end,
            --setParameter = function() end, id = math.random(0, 99999), trash = string.rep(" ", 1024 * 8)}
            --print("create_id", effect.id)

            if display.scriptableObject and display.scriptableObject.data.glass then
                effect_setParameter(effect, "uuid", uuid or sc_display_shapesUuidGlass)
            else
                effect_setParameter(effect, "uuid", uuid or sc_display_shapesUuid)
            end
            
            --effect:start()

            if not nonBuf and display.newEffects then
                display.newEffects[effect] = true
            end
            if not nonBuf then
                root.allEffects[effect] = true
            end

            total_effects = total_effects + 1

            --[[
            if effect and sm_exists(effect) then
                if not nonBuf then
                    
                end
            else
                debug_print("EFFECTS OVERFLOW!!!!", total_effects)
            end
            ]]
        --else
            --[[
            if attemptRemove then
                return
            else
                local count = 0
                for effect in pairs(root.allEffects) do
                    if effect and sm_exists(effect) then
                        quad_effectHide(effect)
                        table_insert(bufferedEffects, effect)
                        
                        count = count + 1
                        if count >= 50 then
                            break
                        end

                        debug_print("super quad_destroyEffect")
                    end
                end
                    

                attemptRemove = true
                goto attempt
            end
            ]]
        --end
    end

    if not effect or not sm_exists(effect) then return effect end

    local scale = sc_display_PIXEL_SCALE * display.pixelScale
    local vx = scale * sizeX + 1e-4
    local vy = scale * sizeY + 1e-4

    wide = wide or 0
    if display.scriptableObject.data and display.scriptableObject.data.wide then
        wide = display.scriptableObject.data.wide
    end

    local vecScale = sm_vec3_new(wide, vy, vx)
    if nativeScale then
        effect_setScale(effect, sm_vec3_new(wide, sizeX, sizeY))
    else
        effect_setScale(effect, vecScale)
    end

    local offset = sm_vec3_new(0, y - display.height/2 + sizeY/2, display.width/2 - x - sizeX/2) * scale
    offset.x = z or (debug_offset and -0.5 or 0)

    local chr = display.scriptableObject.character
    if chr then
        local x, y, z = offset.x, offset.y, offset.z
        offset.z = x
        offset.x = z
        offset.y = -y
        offset = offset + sm_vec3_new(0, 1, 1)
    else
        local loff = quad_displayOffset
        if display.scriptableObject.data and display.scriptableObject.data.zpos then
            loff = sm_vec3_new(display.scriptableObject.data.zpos, 0, 0)
        end
        offset = loff + offset

        if display.scriptableObject.data and display.scriptableObject.data.offset then
            offset = offset + sm_vec3_new(0, display.scriptableObject.data.offset / 4, 0)
        end
    end

    effect_setOffsetPosition(effect, offset)

    local tbl = {nil, nil, display.scriptableObject.data or {}, sizeX, sizeY, offset}
    if chr then
        tbl[7] = quad_alt_hideRot
        tbl[8] = quad_alt_visibleRot
    else
        tbl[7] = quad_hideRot
        tbl[8] = quad_visibleRot
    end
    local datatbl = effectsData[effect.id]
    if datatbl then
        for k, v in pairs(tbl) do
            datatbl[k] = v
        end
    else
        effectsData[effect.id] = tbl
    end
    quad_effectShow(effect)
    
    return effect
end

function quad_destroyEffect(self)
    local effect = self.effect

    if effect and sm_exists(effect) then
        if debug_disableEffectsBuffer then
            effect_destroyAndUnreg(effect)
            total_effects = total_effects - 1
            self.root.allEffects[effect] = nil
        else
            quad_effectHide(effect)
            self.root.bf_idx = self.root.bf_idx + 1
            self.root.bufferedEffects[self.root.bf_idx] = effect
        end
    end

    self.effect = nil
end

local hideOffset = sm_vec3_new(10000000, 10000000, 10000000)

function quad_effectHide(effect)
    if effect and sm_exists(effect) then
        local data = effectsData[effect.id]
        if data[3] and data[3].noRotateEffects then
            effect_setOffsetPosition(effect, hideOffset)
        else
            effect_setOffsetRotation(effect, data[7])
        end
        data[2] = false
    end
end

function quad_effectShow(effect)
    if effect and sm_exists(effect) then
        local data = effectsData[effect.id]
        if data[3] and data[3].noRotateEffects then
            effect_setOffsetPosition(effect, data[6])
        else
            effect_setOffsetRotation(effect, data[8])
        end
        data[2] = true
    end
end

function quad_destroyChildren(self)
    local children = self.children

    quad_destroy(children[1])
    quad_destroy(children[2])
    quad_destroy(children[3])
    quad_destroy(children[4])

    self.children = nil
    self.effect = quad_createEffect(self.root, self.x, self.y, self.size, self.size)
end


function quad_optimize(self)
    if debug_disableoptimize then return end

    local children = self.children
    if children then
        --debug_print("children found!!!")

        quad_optimize(children[1])
        quad_optimize(children[2])
        quad_optimize(children[3])
        quad_optimize(children[4])

        local color = children[1].color
        
        -- check children the same color
        local same = true
        for i = 2, 4 do
            if children[i].color ~= color then
                --debug_print("color is not equals", tostring(children[i].color), tostring(color))
                same = false
                break
            end
        end

        --[[
        local same = false
        for i = 2, 4 do
            if children[i].color == color then
                --debug_print("color is not equals", tostring(children[i].color), tostring(color))
                same = true
                break
            end
        end
        ]]

        if color and same then
            --debug_print("quad_optimize successful")

            quad_destroyChildren(self)

            --[[
            quad_destroy(children[1])
            for i = 2, 4 do
                if children[i].color == color then quad_destroy(children[i]) end
            end

            self.children = nil
            self.effect = quad_createEffect(self.root, self.x, self.y, self.sizeX, self.sizeY)
            ]]



            self.color = color
            quad_updateEffectColor(self)

            --if self.root.display.isRendering then
            --    quad_effectShow(self.effect)
            --end
        end
    end

    --return not not children
end

function quad_split(self)
    --assert(self.children == nil, "quad node already has children")
    --assert(self.size > 1, "cant split size 1")

    --quad_effectHide(self.effect)
    quad_destroyEffect(self)

    local hsize = self.size / 2
    local x = self.x
    local y = self.y
    local color = self.color

    self.children = {
        quad_createNode(self, x, y, hsize, hsize, color),
        quad_createNode(self, x + hsize, y, hsize, hsize, color),
        quad_createNode(self, x, y + hsize, hsize, hsize, color),
        quad_createNode(self, x + hsize, y + hsize, hsize, hsize, color)
    }

    self.color = nil
end

function quad_findChild(self, tx, ty, size)
    if self.size ~= size then
        if not self.children then quad_split(self) end

        local hsize = self.size / 2

        local i = math_floor((tx - self.x) / hsize) + 2 * math_floor((ty - self.y) / hsize)
        --assert(self.children[i + 1] ~= nil, "children[i+1] is nil, i:"..i.." x:"..tx.." y:"..ty)
        return quad_findChild(self.children[i + 1], tx, ty, size)
    else
        return self
    end
end

--[[
function quad_treeMultiSetColor(self, coords, color)
    local coord0 = table_remove(coords, 1)

    if coord0 then
        local x0, y0 = unpack(coord0)
        local child
        local function updateChild(x, y)
            child = quad_findChild(self, x, y, 4)
        end

        updateChild(x0, y0)
        quad_treeSetColor(child, x0, y0, color)

        for k, v in pairs(coords) do
            local x, y = unpack(v)
            if pointInQuad(x, y, child.x, child.y, child.size) then
                quad_treeSetColor(child, x, y, color)
            else
                updateChild(x, y)
                quad_treeSetColor(child, x, y, color)
            end
        end
    end
end
]]


function quad_treeSetColor(self, tx, ty, color)
    if self and self.color ~= color then
        if self.size ~= 1 then
            if not self.children then quad_split(self) end

            local Q_hsize = 2 / self.size
            return quad_treeSetColor(self.children[math_floor((tx - self.x) * Q_hsize) + 2 * math_floor((ty - self.y) * Q_hsize) + 1], tx, ty, color)
        else
            if self.color ~= color then
                self.color = color
                quad_updateEffectColor(self)
            end
        end
    else
        return true
    end
end

function quad_treeFillRect(self, x, y, w, h, color)
    local sx = self.x
    local sy = self.y
    local ssize = self.size

    if quadIntersectsRect(sx, sy, ssize, x, y, w, h) then

        if quadInRect(sx, sy, ssize, x, y, w, h) then
            if self.children then
                quad_destroyChildren(self)
            end

            if self.color ~= color then
                self.color = color
                quad_updateEffectColor(self)
            end
            --if self.root.display.isRendering then
            --    quad_effectShow(self.effect)
            --end
        else
            if not self.children then quad_split(self) end
            local children = self.children

            quad_treeFillRect(children[1], x, y, w, h, color)
            quad_treeFillRect(children[2], x, y, w, h, color)
            quad_treeFillRect(children[3], x, y, w, h, color)
            quad_treeFillRect(children[4], x, y, w, h, color)
        end
    end
end

function quad_treeFillCircle(self, x, y, r, color)
    local sx = self.x
    local sy = self.y
    local ssize = self.size

    if quadIntersectsCircle(sx, sy, ssize, x, y, r) then
        if quadInCircle(sx, sy, ssize, x, y, r) then
            if self.children then
                quad_destroyChildren(self)
            end

            if self.color ~= color then
                self.color = color
                quad_updateEffectColor(self)
                return true --если получилось шось отрисовать
            end

            --if self.root.display.isRendering then
            --    quad_effectShow(self.effect)
            --end
        else
            if ssize ~= 1 then
                if not self.children then quad_split(self) end

                local children = self.children

                local drawed = false
                if quad_treeFillCircle(children[1], x, y, r, color) then drawed = true end
                if quad_treeFillCircle(children[2], x, y, r, color) then drawed = true end
                if quad_treeFillCircle(children[3], x, y, r, color) then drawed = true end
                if quad_treeFillCircle(children[4], x, y, r, color) then drawed = true end
                return drawed
            end
        end
    end
end

function quad_treeShow(self)
    if self.children then
        local children = self.children

        quad_treeShow(children[1])
        quad_treeShow(children[2])
        quad_treeShow(children[3])
        quad_treeShow(children[4])
    else
        quad_effectShow(self.effect)
    end
end

function quad_treeHide(self)
    if self.children then
        local children = self.children

        quad_treeHide(children[1])
        quad_treeHide(children[2])
        quad_treeHide(children[3])
        quad_treeHide(children[4])
    else
        quad_effectHide(self.effect)
    end
end

function quad_rootRealShow(self, noRecurse)
    --[[
    if self.children then
        local children = self.children

        quad_rootRealShow(children[1])
        quad_rootRealShow(children[2])
        quad_rootRealShow(children[3])
        quad_rootRealShow(children[4])
    end
    if self.effect and sm_exists(self.effect) and effect_isDone(self.effect) then
        effect_start(self.effect)
    end

    if self.bufferedEffects and noRecurse then
        if effect_isDone(self.back_effect) then
            effect_start(self.back_effect)
        end

        for k, v in pairs(self.bufferedEffects) do
            if sm_exists(v) and effect_isDone(v) then
                effect_start(v)
            end
        end
    end
    ]]

    if self.splashEffect and sm_exists(self.splashEffect) and effect_isDone(self.splashEffect) then
        effect_start(self.splashEffect)
    end
    if self.back_effect and effect_isDone(self.back_effect) then
        effect_start(self.back_effect)
    end
    for effect in pairs(self.allEffects) do
        if sm_exists(effect) and effect_isDone(effect) then
            effect_start(effect)
        end
    end
end

function quad_rootRealHide(self, noRecurse)
    --[[
    if self.children then
        local children = self.children

        quad_rootRealHide(children[1])
        quad_rootRealHide(children[2])
        quad_rootRealHide(children[3])
        quad_rootRealHide(children[4])
    end
    if self.effect and sm_exists(self.effect) then
        effect_stop(self.effect)
    end

    if self.bufferedEffects and noRecurse then
        effect_stop(self.back_effect)

        for k, v in pairs(self.bufferedEffects) do
            if sm_exists(v) then
                effect_stop(v)
            end
        end
    end
    ]]

    if self.splashEffect and sm_exists(self.splashEffect) then
        effect_stop(self.splashEffect)
    end
    if self.back_effect then
        effect_stop(self.back_effect)
    end
    for effect in pairs(self.allEffects) do
        if sm_exists(effect) then
            effect_stop(effect)
        end
    end
end

------------------------------------------------------------

local function hideNewEffects(self)
    if self.newEffects then
        for eff in pairs(self.newEffects) do
            effect_stop(eff)
            --quad_effectHide(eff)
        end
    end
end

local function showNewEffects(self)
    if self.newEffects then
        for eff in pairs(self.newEffects) do
            if effect_isDone(eff) then
                effect_start(eff)
            end
            --quad_effectShow(eff)
        end
    end
end

local function applyNew(self)
    if self.isRendering then
        if self.quadTree.splashEffect and effect_isDone(self.quadTree.splashEffect) then
            effect_start(self.quadTree.splashEffect)
        end
        if self.quadTree.back_effect and effect_isDone(self.quadTree.back_effect) then
            effect_start(self.quadTree.back_effect)
        end
        showNewEffects(self)
    else
        --[[
        if self.quadTree.splashEffect then
            effect_stop(self.quadTree.splashEffect)
        end
        if self.quadTree.back_effect then
            effect_stop(self.quadTree.back_effect)
        end
        hideNewEffects(self)
        ]]
        quad_rootRealHide(self.quadTree)
    end
end

------------------------------------------------------------

local function random_hide_show(self, probabilityNum, allow)
    --[[
    local sendallow = (allow or 0) + 1
    if self.children then
        local children = self.children

        random_hide_show(children[1], probabilityNum, sendallow)
        random_hide_show(children[2], probabilityNum, sendallow)
        random_hide_show(children[3], probabilityNum, sendallow)
        random_hide_show(children[4], probabilityNum, sendallow)
    end
    if self.effect and allow and allow >= 2 then
        if probability(probabilityNum) then
            self.effect:stop()
        else
            self.effect:start()
        end
    end
    ]]

    debug_print("random_hide_show")

    local edata
    for effect in pairs(self.quadTree.allEffects) do
        if sm_exists(effect) then
            if probabilityNum > 0 and probability(probabilityNum) then
                edata = effectsData[effect.id]
                --если писклесь хотябы по одной оси меньше или равно 2
                --это позволит рендерить изображения в сильно упрошенном виде
                if edata[4] <= 2 or edata[5] <= 2 then
                    effect_stop(effect)
                end
            elseif effect_isDone(effect) then
                effect_start(effect)
            end
        end
    end
end

local forceRotate = false

local function reset(self)
    self.maxClicks = 16
    self.rotation = 0
    self.settedRotation = 0
    self.skipAtNotSight = false
    self.utf8support = false
    self.renderAtDistance = false
    self.skipAtLags = true
    self.clicksAllowed = false
    self.clickData = {}

    self.needSendData = true

    if self.scriptableObject.data and self.scriptableObject.data.rotate then
        forceRotate = true
        self.api.setRotation(0)
        forceRotate = false
    end
end

function sc.display.createDisplay(scriptableObject, width, height, pixelScale)
    local display = {
        renderingStack = {},
        rnd_idx = 1,
        width = width,
        height = height,
        pixelScale = pixelScale,
        scriptableObject = scriptableObject,
        needUpdate = false,
        serverCache = {},

        -- client
        localLag = 0,
        rnd = math_random(0, 40 * 5),
        dbuffPixels = {},
        quadTree = nil,
        dragging = {interact=false, tinker=false, interactLastPos={x=-1, y=-1}, tinkerLastPos={x=-1, y=-1}},

        buffer1 = {},
        buffer2 = {}
    }

    display.force_update = true --первая отрисовка всегда форсированая
    display.allow_update = true
    display.audience = {}

    return display
end

function sc.display.server_init(self)
    self.old_this_display_blocked = false

    if self.scriptableObject.interactable then
        sc.displaysDatas[self.scriptableObject.interactable.id] = sc.display.server_createData(self)
    end

    reset(self)
end

local function sendFont(self, client)
    local function send(name, arg)
        if client then
            self.scriptableObject.network:sendToClient(client, name, arg)
        else
            self.scriptableObject.network:sendToClients(name, arg)
        end
    end

    if self.customFont then
        send("client_onDataResponse", {fontdata = {width = self.customFont.width, height = self.customFont.height}})
        for name, data in pairs(self.customFont.chars) do
            send("client_onDataResponse", {fontdata = {name = name, data = data}})
        end
    else
        send("client_onDataResponse", {fontdata = {remove = true}})
    end
end

local function isAllow(self)
    return self.width * self.height <= (sc.restrictions.maxDisplays * sc.restrictions.maxDisplays)
end

function sc.display.server_update(self)
    local audienceSize = 0
    for id, timer in pairs(self.audience) do
        audienceSize = audienceSize + 1
        if timer <= 0 then
            self.audience[id] = nil
        else
            self.audience[id] = timer - 1
        end
    end

    local rate = sc.restrictions.screenRate
    if audienceSize == 0 then
        rate = 16
    end

    local ctick = sm.game.getCurrentTick()
    if ctick % rate == 0 then self.allow_update = true end
    if ctick % (40 * 5) == 0 then
		self.forceNative_update = true
		self.serverCache = {}
        self.serverCacheAll = nil
	end
    if ctick % (40 * 2) == 0 then
        self.force_update = true
        self.allow_update = true
        self.stackChecksum = nil

        debug_print("force setted")
    end


    if self.needUpdate and self.this_display_blocked then
        self.rnd_idx = 1
        self.renderingStack = {}
        self.needUpdate = false
    end

    self.this_display_blocked = not isAllow(self)
    if self.this_display_blocked ~= self.old_this_display_blocked then
        self.api.reset()
        self.api.clear()
        self.api.forceFlush()
        if self.this_display_blocked then
            self.renderingStack.oops = true
        end
        self.old_this_display_blocked = self.this_display_blocked
    end

    if self.needSendData then
        --debug_print("self.needSendData")
        self.scriptableObject.network:sendToClients("client_onDataResponse", sc.display.server_createNetworkData(self))
        sendFont(self)

        self.needSendData = false
    end



    if self.needUpdate and self.allow_update then
        if self.rnd_idx > 1 then
            local stackChecksumVal
            local function stackChecksum()
                if not stackChecksumVal then
                    stackChecksumVal = tableChecksum(self.renderingStack)
                end
                return stackChecksumVal
            end

            if self.force_update or
            not self.stackChecksum or
            self.stackChecksumLen ~= self.rnd_idx or
            self.stackChecksum ~= stackChecksum() then
                local cancel
                if self.lastComputer and self.lastComputer.cdata and not self.lastComputer.cdata.unsafe and type(sc.restrictions.lagDetector) == "number" then
                    local oldLagScore = self.lastComputer.lagScore
                    self.lastComputer.lagScore = self.lastComputer.lagScore + (self.rnd_idx * 0.0005 * sc.restrictions.lagDetector)
                    debug_print("lag score delta", self.lastComputer.lagScore - oldLagScore)

                    if self.lastComputer.lagScore > 120 then
                        debug_print_force("lagScore > 120!!")
                        cancel = true
                    end
                end

                if not cancel then
                    self.renderingStack.force = self.force_update
                    self.renderingStack.forceNative = self.forceNative_update
                    self.renderingStack.endPack = true
                    --[[
                    local dist = RENDER_DISTANCE
                    if self.renderAtDistance or self.player then
                        dist = nil
                    end
                    ]]
                    --local dist = nil --sending to all players

                    local whitelist
                    if self.player then
                        whitelist = {[self.player.id] = true}
                    end
                    local maxDist
                    if self.skipAtNotSight and not self.force_update then
                        maxDist = sc.restrictions.rend
                    end

                    if not pcall(vnetwork.sendToClients, self.scriptableObject, "client_onReceiveDrawStack", self.renderingStack, maxDist, whitelist) then
                        self.renderingStack.endPack = false
                        
                        local index = 1
                        local count = 1024
                        local cycles = 0

                        local datapack
                        while true do
                            --datapack = {unpack(self.renderingStack, index, index + (count - 1))}
                            datapack = {unpack(self.renderingStack, index, index + (count - 1))}

                            index = index + count
                            if datapack[#datapack] == self.renderingStack[#self.renderingStack] then
                                datapack.endPack = true
                                if pcall(vnetwork.sendToClients, self.scriptableObject, "client_onReceiveDrawStack", datapack, maxDist, whitelist) then
                                    break
                                else
                                    index = index - count
                                    count = math_floor((count / 2) + 0.5)
                                end
                            elseif not pcall(vnetwork.sendToClients, self.scriptableObject, "client_onReceiveDrawStack", datapack, maxDist, whitelist) then
                                index = index - count
                                count = math_floor((count / 2) + 0.5)
                            end

                            cycles = cycles + 1
                            if cycles > 100 then
                                debug_print_force("cycles to many 100", pcall(vnetwork.sendToClients, self.scriptableObject, "client_onReceiveDrawStack", self.renderingStack, maxDist, whitelist))
                                error("cycles to many 100")
                                break
                            end
                        end
                        debug_print("self.needUpdate-sending end")
                    end
                end

                self.stackChecksum = stackChecksum()
                self.stackChecksumLen = self.rnd_idx
                
                self.force_update = false
                self.allow_update = false
                self.forceNative_update = false

                debug_print("RENDER SENDED!!!")
            end
        end

        self.needUpdate = false
        self.rnd_idx = 1
        self.renderingStack = {}
    end
end

function sc.display.client_init(self)
    --local size = math_max(self.width, self.height)
    --local root = quad_createRoot(self, 0, 0, size, self.width, self.height)
    --self.quadTree = root

    self.scriptableObject.network:sendToServer("server_onDataRequired", sm_localPlayer_getPlayer())

    self.newEffects = {}
    sc_display_client_clear(self, black, true)
    applyNew(self)
    self.newEffects = nil
end


function sc.display.server_destroy(self)
    if self.scriptableObject.interactable then
        sc.displaysDatas[self.scriptableObject.interactable.id] = nil
    end
end

function sc.display.client_destroy(self)
    local quadTree = self.quadTree

    if self.splashEffect and sm_exists(self.splashEffect) then
        effect_destroyAndUnreg(self.splashEffect)
    end
    quad_destroy(quadTree, true)
end

function sc.display.server_createData(self)
    local width = self.width
    local height = self.height

    local rwidth = width
    local rheight = height

    local function checkPos(x, y)
        x = nRound(x)
        y = nRound(y)
        if x ~= x or x < 0 or x >= rwidth then return end -- x ~= x is NAN check
        if y ~= y or y < 0 or y >= rheight then return end -- y ~= y is NAN check
        return x, y
    end

    local function checkRectPos(x, y)
        if x < 0 then x = 0 end
        if y < 0 then y = 0 end
        if x >= rwidth then x = rwidth - 1 end
        if y >= rheight then y = rheight - 1 end
        return x, y
    end

    local function checkRect(x, y, w, h)
        local xneg, yneg = w < 0, h < 0
		w = math_floor(math_abs(w))
        h = math_floor(math_abs(h))
        if x + w > rwidth then
            w = w - ((x + w) - rwidth)
        end
        if y + h > rheight then
            h = h - ((y + h) - rheight)
        end
		if xneg then x = x - w end
		if yneg then y = y - h end
        return x, y, w, h
    end

    local data = {
        isAllow = function ()
            return isAllow(self)
        end,
        getAudience = function()
            local num = 0
            for k, v in pairs(self.audience) do
                num = num + 1
            end
            return num
        end,
        reset = function ()
            reset(self)
            self.api.setFont()
        end,
        getWidth = function ()
            return rwidth
        end,
        getHeight = function ()
            return rheight
        end,
        clear = function (color)
            self.renderingStack = {{
                0,
                color or "000000ff"
            }}
            self.rnd_idx = 2

            self.serverCache = {}
            self.serverCacheAll = color
        end,
        drawPixel = function (x, y, color)
            x, y = checkPos(x, y)
            if x and (self.serverCache[x + (y * rwidth)] or self.serverCacheAll) ~= color then
                self.renderingStack[self.rnd_idx] = {
                    1,
                    color or "ffffffff",
                    x,
                    y
                }
                self.rnd_idx = self.rnd_idx + 1
                self.serverCache[x + (y * rwidth)] = color
            end
        end,
        drawRect = function (x, y, w, h, c)
            x, y = checkRectPos(x, y)
            x, y, w, h = checkRect(x, y, w, h)

            self.renderingStack[self.rnd_idx] = {
                2,
                c or "ffffffff",
                nRound(x),
                nRound(y),
                nRound(w),
                nRound(h)
            }
            self.rnd_idx = self.rnd_idx + 1
            
            self.serverCache = {}
            self.serverCacheAll = nil
        end,
        fillRect = function (x, y, w, h, c)
            x, y = checkRectPos(x, y)
            x, y, w, h = checkRect(x, y, w, h)

            self.renderingStack[self.rnd_idx] = {
                3,
                c or "ffffffff",
                nRound(x),
                nRound(y),
                nRound(w),
                nRound(h)
            }
            self.rnd_idx = self.rnd_idx + 1
            
            self.serverCache = {}
            self.serverCacheAll = nil
        end,
        drawCircle = function (x, y, r, c)
            if r > 1024 then
                r = 1024
            end

            self.renderingStack[self.rnd_idx] = {
                4,
                c or "ffffffff",
                nRound(x) + 0.5, -- +0.5 because center of pixel
                nRound(y) + 0.5, -- +0.5 because center of pixel
                nRound(r)
            }
            self.rnd_idx = self.rnd_idx + 1
            
            self.serverCache = {}
            self.serverCacheAll = nil
        end,
        fillCircle = function (x, y, r, c)
            if r > 1024 then
                r = 1024
            end

            self.renderingStack[self.rnd_idx] = {
                5,
                c or "ffffffff",
                nRound(x) + 0.5, -- +0.5 because center of pixel
                nRound(y) + 0.5, -- +0.5 because center of pixel
                nRound(r)
            }
            self.rnd_idx = self.rnd_idx + 1
            
            self.serverCache = {}
            self.serverCacheAll = nil
        end,
        drawLine = function (x, y, x1, y1, c)
            self.renderingStack[self.rnd_idx] = {
                6,
                c or "ffffffff",
                nRound(x),
                nRound(y),
                nRound(x1),
                nRound(y1)
            }
            self.rnd_idx = self.rnd_idx + 1
            
            self.serverCache = {}
            self.serverCacheAll = nil
        end,
        drawText = function (x, y, text, c)
            if not debug_disabletext then
                self.renderingStack[self.rnd_idx] = {
                    7,
                    c or "ffffffff",
                    nRound(x),
                    nRound(y),
                    tostring(text)
                }
                self.rnd_idx = self.rnd_idx + 1
                
                self.serverCache = {}
                self.serverCacheAll = nil
            end
        end,


        optimize = function ()
            --ручная оптимизация отключена из за того что большенство использует ее неправильно, что вызовет понижения производительности. данная функция сейчас работает полностью автоматически
            --потом может быть что-то придумаю
            --[[
            self.renderingStack[self.rnd_idx] = {
                8
            }
            self.rnd_idx = self.rnd_idx + 1
            ]]
        end,
        update = function () --для совместимости с SCI
            self.lastComputer = sc.lastComputer
            self.needUpdate = true
        end,
        flush = function ()
            self.lastComputer = sc.lastComputer
            self.needUpdate = true
        end,
        forceFlush = function()
            self.lastComputer = sc.lastComputer
            self.force_update = true
            self.needUpdate = true
        end,
        
        getClick = function ()
            local res = table_remove(self.clickData, 1)
            return res
        end,
        setMaxClicks = function (c)
            if type(c) == "number" and c % 1 == 0 and c > 0 and c <= 16 then
                self.maxClicks = c
            else
                error("integer must be in [1; 16]", 2)
            end
        end,
        getMaxClicks = function ()
            return self.maxClicks
        end,
        clearClicks = function ()
            self.clickData = {}
        end,

        setFont = function (font)
            checkArg(1, font, "table", "nil")
            if font then
                basegraphic_checkFont(font)
                self.customFont = {
                    width = font.width,
                    height = font.height,
                    chars = sc.display.optimizeFont(font.chars, font.width, font.height)
                }
            else
                self.customFont = nil
            end
            self.needSendData = true
            self.stackChecksum = nil
        end,

        getFontWidth = function ()
            return (self.customFont and self.customFont.width) or font_width
        end,

        getFontHeight = function ()
            return (self.customFont and self.customFont.height) or font_height
        end,

        setClicksAllowed = function (c)
            if type(c) == "boolean" then
                if self.clicksAllowed ~= c then
                    self.clicksAllowed = c
                    self.needSendData = true
                end
            else
                error("Type must be boolean", 2)
            end
        end,
        getClicksAllowed = function () return self.clicksAllowed end,

        setRenderAtDistance = function (c)
            if type(c) == "boolean" then
                if self.renderAtDistance ~= c then
                    self.renderAtDistance = c
                    self.needSendData = true
                end
            else
                error("Type must be boolean", 2)
            end
        end,
        getRenderAtDistance = function () return self.renderAtDistance end,

        setSkipAtLags = function (state)
            if type(state) == "boolean" then
                if self.skipAtLags ~= state then
                    self.skipAtLags = state
                    self.needSendData = true
                end
            else
                error("Type must be boolean", 2)
            end
        end,
        getSkipAtLags = function () return self.skipAtLags end,

        setRotation = function (rotation)
            if type(rotation) == "number" and rotation % 1 == 0 and rotation >= 0 and rotation <= 3 then
                if self.rotation ~= rotation or forceRotate then
                    self.rotation = rotation
                    self.settedRotation = rotation
                    self.needSendData = true

                    if self.scriptableObject.data and self.scriptableObject.data.rotate then
                        self.rotation = (self.rotation + self.scriptableObject.data.rotate) % 4
                    end

                    if self.rotation == 1 or self.rotation == 3 then
                        rwidth = height
                        rheight = width
                    else
                        rwidth = width
                        rheight = height
                    end
                end
            else
                error("integer must be in [0; 3]", 2)
            end
        end,
        getRotation = function () return self.settedRotation end,

        setFrameCheck = function (framecheck) end, --legacy (stub)
        getFrameCheck = function () return true end, --legacy (stub)


        setSkipAtNotSight = function (skipAtNotSight)
            if type(skipAtNotSight) == "boolean" then
                if self.skipAtNotSight ~= skipAtNotSight then
                    self.skipAtNotSight = skipAtNotSight
                    self.needSendData = true
                end
            else
                error("Type must be boolean", 2)
            end
        end,
        getSkipAtNotSight = function () return self.skipAtNotSight end,

        setUtf8Support = function (state)
            if type(state) == "boolean" then
                if self.utf8support ~= state then
                    self.utf8support = state
                    self.needSendData = true
                end
            else
                error("Type must be boolean", 2)
            end
        end,
        getUtf8Support = function () return self.utf8support end
    }

    self.api = data
    return data
end

function sc.display.server_createNetworkData(self)
    return {
        renderAtDistance = self.renderAtDistance,
        clicksAllowed = self.clicksAllowed,
        skipAtLags = self.skipAtLags,
        rotation = self.rotation,
        skipAtNotSight = self.skipAtNotSight,
        utf8support = self.utf8support
    }
end

function sc.display.server_onDataRequired(self, client)
    --self.dbuffPixels = {}
    --self.dbuffPixelsAll = nil

    self.scriptableObject.network:sendToClient(client, "client_onDataResponse", sc.display.server_createNetworkData(self))
    sendFont(self, client)
    self.serverCache = {}

    self.allow_update = true
    self.force_update = true
    self.forceNative_update = true
end

function sc.display.server_recvPress(self, p, caller)
    if type(p) == "number" then
        if self.lastComputer and (not self.lastComputer.cdata or not self.lastComputer.cdata.unsafe) and type(sc.restrictions.lagDetector) == "number" then
			local num = 0
            for k, v in pairs(self.audience) do
                num = num + 1
            end
			if num == 0 then
				num = 1
			end
            
            local add = (p / num) * sc.restrictions.lagDetector
            self.lastComputer.lagScore = self.lastComputer.lagScore + add
            debug_print("get lag score", add)
        end
    elseif p == "reg" then --user reg
        self.audience[caller.id] = 40
    else
        local d = self.clickData
        if #d <= self.maxClicks then
            table_insert(d, p)
        end
    end
end



















function sc_display_client_clear(self, color, removeAll)
    if not removeAll and color == self.lastLastClearColor2 and not self.scriptableObject.data.noDoubleEffect then
        return true
    end
    self.lastLastClearColor = color
    self.lastLastClearColor2 = color

    local quadTree = self.quadTree
    if removeAll then
        local rotation

        if quadTree then
            rotation = quadTree.rotation
            quad_destroy(quadTree, true)
        end

        local size = math_max(self.width, self.height)
        local root = quad_createRoot(self, 0, 0, size, self.width, self.height)
        if quadTree then
            root.splashEffect = quadTree.splashEffect
        end

        if rotation then
            root.rotation = rotation
        end
        self.quadTree = root
        quadTree = root

        --total_effects = 1 --в мире можно быть много дисплеев
    end

    -------------------------

    if quadTree.children then
        quad_destroyChildren(quadTree)
    end

    if quadTree.color ~= color then
        quadTree.color = color
        quad_updateEffectColor(quadTree)
    end

    --if self.isRendering then
    --    quad_effectShow(quadTree.effect)
    --end

    if self.quadTree.back_effect then
        raw_set_color(self.quadTree.back_effect, color)
    end

    self.dbuffPixels = {}
    self.dbuffPixelsAll = color

    self.buffer1 = {}
    self.buffer2 = {}
    self.buffer1All = nil
    self.buffer2All = nil
end

function sc_display_client_drawPixelForce(self, x, y, color)
    local width = getWidth(self)
    local currentColor = self.dbuffPixels[x + (y * width)] or self.dbuffPixelsAll

    if currentColor and currentColor == color and not debug_disableDBuff then
        return true --если нехрена не поменялось
    end

    quad_treeSetColor(self.quadTree, x, y, color)
    self.dbuffPixels[x + (y * width)] = color
end

function sc_display_client_drawPixel(self, x, y, color)
    x = math_floor(x)
    y = math_floor(y)

    if x >= 0 and x < getWidth(self) and y >= 0 and y < getHeight(self) then
        return sc_display_client_drawPixelForce(self, x, y, color)
    else
        return true
    end
end

function sc_display_client_drawRect(self, x, y, w, h, color)
    local width = getWidth(self)
    local height = getHeight(self)

    if x >= width then return true end
    if y >= height then return true end
    local lx = math_floor(x >= 0 and x or 0)
    local ly = math_floor(y >= 0 and y or 0)
    
    local lw = w - (lx - x)
    local lh = h - (ly - y)

    local rw = width - lx
    local rh = height - ly

    lw = math_floor(lw < rw and lw or rw)
    lh = math_floor(lh < rh and lh or rh)

    local isEffect = false

    for i = lx,lx+lw-1 do
        if not sc_display_client_drawPixelForce(self, i, ly, color) then
            isEffect = true
        end
    end

    local ex = lx+lw-1
    for iy = ly+1, ly+lh-2 do
        if not sc_display_client_drawPixelForce(self, lx, iy, color) then
            isEffect = true
        end
        if not sc_display_client_drawPixelForce(self, ex, iy, color) then
            isEffect = true
        end
    end

    local ey = ly + lh - 1
    for i = lx,lx+lw-1 do
        if not sc_display_client_drawPixelForce(self, i, ey, color) then
            isEffect = true
        end
    end

    return not isEffect
end

function sc_display_client_fillRect(self, x, y, w, h, color)
    self.dbuffPixels = {}
    self.dbuffPixelsAll = nil
    quad_treeFillRect(self.quadTree, math_floor(x), math_floor(y), math_floor(w), math_floor(h), color)

    --[[
    local realAction = false
    local mw, mh = getWidth(self), getHeight(self)
    for cx = x, x + (w - 1) do
        for cy = y, y + (h - 1) do
            if cx >= 0 and cy >= 0 and cx < mw and cy < mh then
                if self.dbuffPixels[x + (y * mw)] or self.dbuffPixelsAll ~= color then
                    self.dbuffPixels[cx + (cy * mw)] = color
                    realAction = true
                end
            end
        end
    end
    if realAction then
        quad_treeFillRect(self.quadTree, math_floor(x), math_floor(y), math_floor(w), math_floor(h), color)
    else
        return true
    end
    ]]
end

sc.display.client_fillRect = sc_display_client_fillRect

local function drawCircle_putpixel(self, cx, cy, x, y, color)
    local posDX_x = cx + x
    local negDX_x = cx - x
    local posDX_y = cx + y
    local negDX_y = cx - y

    local posDY_y = cy + y
    local negDY_y = cy - y
    local posDY_x = cy + x
    local negDY_x = cy - x

    local isEffect = false
    if not sc_display_client_drawPixel(self, posDX_x, posDY_y, color) then isEffect = true end
    if not sc_display_client_drawPixel(self, negDX_x, posDY_y, color) then isEffect = true end
    if not sc_display_client_drawPixel(self, posDX_x, negDY_y, color) then isEffect = true end
    if not sc_display_client_drawPixel(self, negDX_x, negDY_y, color) then isEffect = true end
    if not sc_display_client_drawPixel(self, posDX_y, posDY_x, color) then isEffect = true end
    if not sc_display_client_drawPixel(self, negDX_y, posDY_x, color) then isEffect = true end
    if not sc_display_client_drawPixel(self, posDX_y, negDY_x, color) then isEffect = true end
    if not sc_display_client_drawPixel(self, negDX_y, negDY_x, color) then isEffect = true end
    return not isEffect
end

function sc_display_client_drawCircle(self, x, y, r, color)
    x = math_floor(x)
    y = math_floor(y)
    r = math_floor(r)

    local lx = 0
    local ly = r
    local d = 3 - 2 * r

    local isEffect = false
    if not drawCircle_putpixel(self, x, y, lx, ly, color) then isEffect = true end
    while ly >= lx do
        lx = lx + 1

        if d > 0 then
            ly = ly - 1
            d = d + 4 * (lx - ly) + 10
        else
            d = d + 4 * lx + 6
        end

        if not drawCircle_putpixel(self, x, y, lx, ly, color) then isEffect = true end
    end
    return not isEffect
end

function sc_display_client_fillCircle(self, x, y, r, color)
    if quad_treeFillCircle(self.quadTree, x, y, r, color) then
        self.dbuffPixels = {}
        self.dbuffPixelsAll = nil
    else
        return true
    end

    --[[
    r = math_abs(r)
    local mw, mh = getWidth(self), getHeight(self)
    local cx, cy = math_min(r, 1024), math_min(r, 1024)
    local px, py
    for ix = -cx, cx do
        px = x + ix
        if px >= 0 and px < mw then
            for iy = -cy, cy do
                py = y + iy
                if py >= mh then
                    break
                elseif ix*ix + iy*iy <= r*r and py >= 0 then
                    sc_display_client_drawPixel(self, px, py, color)
                    self.dbuffPixels[px + (py * mw)] = color
                end
            end
            if px == true then --dubble break
                break
            end
        end
    end
    ]]
end

--[[
local function sc_display_client_drawLineForce(self, x, y, x1, y1, color)
    x = math_floor(x)
    y = math_floor(y)
    x1 = math_floor(x1)
    y1 = math_floor(y1)

    local dx = math_abs(x1 - x)
    local sx = x < x1 and 1 or -1
    local dy = -math_abs(y1 - y)
    local sy = y < y1 and 1 or -1
    
    local isEffect = false
    local error = dx + dy
    local e2
    while true do
        if not sc_display_client_drawPixelForce(self, x, y, color) then isEffect = true end

        if x == x1 and y == y1 then break end
        e2 = error * 2
        if e2 >= dy then
            if x == x1 then break end
            error = error + dy
            x = x + sx
        end
        if e2 <= dx then
            if y == y1 then break end
            error = error + dx
            y = y + sy
        end
    end
    return not isEffect
end
]]

-- y = y0 + round( (x-x0) * dy / dx )
function sc_display_client_drawLine(self, x, y, x1, y1, color)
    local width = getWidth(self)
    local height = getHeight(self)
    
    x = math_floor(x)
    y = math_floor(y)
    x1 = math_floor(x1)
    y1 = math_floor(y1)

    local sign_x, sign_y

    local clip_xmin = 0
    local clip_xmax = width - 1

    local clip_ymin = 0
    local clip_ymax = height - 1

    local isEffect = false

    if x == x1 then
        if x < clip_xmin or x > clip_xmax then return not isEffect end

        if y <= y1 then
            if y1 < clip_ymin or y > clip_xmax then return not isEffect end

            y = math_max(y, clip_ymin)
            y1 = math_min(y1, clip_ymax)

            for iy = y, y1 do
                if not sc_display_client_drawPixelForce(self, x, iy, color) then isEffect = true end
            end
        else
            if y < clip_ymin or y1 > clip_ymax then return not isEffect end

            y1 = math_max(y1, clip_ymin)
            y = math_min(y, clip_ymax)

            for iy = y, y1, -1 do
                if not sc_display_client_drawPixelForce(self, x, iy, color) then isEffect = true end
            end
        end

        return not isEffect
    end

    if y == y1 then
        if y < clip_ymin or y > clip_ymax then return not isEffect end

        if x <= x1 then
            if x1 < clip_xmin or x > clip_xmax then return not isEffect end

            x = math_max(x, clip_xmin)
            x1 = math_min(x1, clip_xmax)

            for ix = x, x1 do
                if not sc_display_client_drawPixelForce(self, ix, y, color) then isEffect = true end
            end
        else
            if x < clip_xmin or x1 > clip_xmax then return not isEffect end

            x1 = math_max(x1, clip_xmin)
            x = math_min(x, clip_xmax)

            for ix = x, x1, -1 do
                if not sc_display_client_drawPixelForce(self, ix, y, color) then isEffect = true end
            end
        end

        return not isEffect
    end

    if x < x1 then
        if x > clip_xmax or x1 < clip_xmin then return not isEffect end
        sign_x = 1
    else
        if x1 > clip_xmax or x < clip_xmin then return not isEffect end
        x = -x
        x1 = -x1
        clip_xmin, clip_xmax = -clip_xmax, -clip_xmin

        sign_x = -1
    end

    if y < y1 then
        if y > clip_ymax or y1 < clip_ymin then return not isEffect end
        sign_y = 1
    else
        if y1 > clip_ymax or y < clip_ymin then return not isEffect end
        y = -y
        y1 = -y1
        clip_ymin, clip_ymax = -clip_ymax, -clip_ymin

        sign_y = -1
    end

    local delta_x = x1 - x
    local delta_y = y1 - y

    local delta_x_step = 2 * delta_x
    local delta_y_step = 2 * delta_y

    local xpos = x
    local ypos = y

    if delta_x >= delta_y then
        local error = delta_y_step - delta_x
        local exit = false

        if y < clip_ymin then
            local temp = (2 * (clip_ymin - y) - 1) * delta_x
            local msd = math_floor(temp / delta_y_step)

            xpos = xpos + msd

            if xpos > clip_xmax then return not isEffect end

            if xpos >= clip_xmin then
                local rem = temp - msd * delta_y_step

                ypos = clip_ymin
                error = error - rem - delta_x

                if rem > 0 then
                    xpos = xpos + 1
                    error = error + delta_y_step
                end

                exit = true
            end
        end

        if not exit and x < clip_xmin then
            local temp = delta_y_step * (clip_xmin - x)
            local msd = math_floor(temp / delta_x_step)

            ypos = ypos + msd
            local rem = temp % delta_x_step

            if ypos > clip_ymax or (ypos == clip_ymax and rem >= delta_x) then return not isEffect end

            xpos = clip_xmin
            error = error + rem

            if rem >= delta_x then
                ypos = ypos + 1
                error = error - delta_x_step
            end
        end

        local xpos_end = x1

        if y1 > clip_ymax then
            local temp = delta_x_step * (clip_ymax - y) + delta_x
            local msd = math_floor(temp / delta_y_step)

            xpos_end = x + msd

            if (temp - msd * delta_y_step) == 0 then
                xpos_end = xpos_end - 1
            end
        end

        xpos_end = math_min(xpos_end, clip_xmax) + 1

        if sign_y == -1 then 
            ypos = -ypos 
        end
        if sign_x == -1 then -- TODO * sign
            xpos = -xpos
            xpos_end = -xpos_end
        end

        delta_x_step = delta_x_step - delta_y_step

        while xpos ~= xpos_end do
            if not sc_display_client_drawPixelForce(self, xpos, ypos, color) then isEffect = true end

            if error >= 0 then
                ypos = ypos + sign_y
                error = error - delta_x_step
            else
                error = error + delta_y_step
            end

            xpos = xpos + sign_x
        end
    else
        local error = delta_x_step - delta_y
        local exit = false

        if x < clip_xmin then
            local temp = (2 * (clip_xmin - x) - 1) * delta_y
            local msd = math_floor(temp / delta_x_step)
            ypos = ypos + msd

            if ypos > clip_ymax then return not isEffect end

            if ypos >= clip_ymin then
                local rem = temp - msd * delta_x_step

                xpos = clip_xmin
                error = error - rem - delta_y

                if rem > 0 then
                    ypos = ypos + 1
                    error = error + delta_x_step
                end

                exit = true
            end
        end

        if not exit and y < clip_ymin then
            local temp = delta_x_step * (clip_ymin - y)
            local msd = math_floor(temp / delta_y_step)

            xpos = xpos + msd

            local rem = temp % delta_y_step

            if xpos > clip_xmax or (xpos == clip_xmax and rem >= delta_y) then return not isEffect end

            ypos = clip_ymin
            error = error + rem

            if rem >= delta_y then
                xpos = xpos + 1
                error = error - delta_y_step
            end
        end

        local ypos_end = y1

        if x1 > clip_xmax then
            local temp = delta_y_step * (clip_xmax - x) + delta_y
            local msd = math_floor(temp / delta_x_step)

            ypos_end = y + msd

            if (temp - msd * delta_x_step) == 0 then
                ypos_end = ypos_end - 1
            end
        end

        ypos_end = math_min(ypos_end, clip_ymax) + 1

        if sign_x == -1 then -- TODO * sign
            xpos = -xpos
        end
        if sign_y == -1 then
            ypos = -ypos
            ypos_end = -ypos_end
        end

        delta_y_step = delta_y_step - delta_x_step

        while ypos ~= ypos_end do
            if not sc_display_client_drawPixelForce(self, xpos, ypos, color) then isEffect = true end

            if error >= 0 then
                xpos = xpos + sign_x
                error = error - delta_y_step
            else
                error = error + delta_x_step
            end

            ypos = ypos + sign_y
        end
    end
end


local string_char = string.char

--[[
local function loadChar(self, c)
    local chars = self.customFont and self.customFont.chars or font_chars
    local pixels = chars[c]
    if not pixels and type(c) == "number" then
        pixels = chars[string_char(c)]
    end
    if pixels then return pixels end
    return chars.error or font_chars.error
end

local function drawCharForce(self, x, y, c, color)
    local pixels = loadChar(self, c)
    local v
    for i = 1, #pixels do
        v = pixels[i]
        drawPixelForce(self, x + v[1], y + v[2], color)
    end
end


local function drawChar(self, x, y, c, color)
    local pixels = loadChar(self, c)
    local v
    for i = 1, #pixels do
        v = pixels[i]
        drawPixel(self, x + v[1], y + v[2], color)
    end
end
]]

local _utf8_code = _utf8.code
local _utf8_sub = _utf8.sub
local _utf8_len = _utf8.len
local string_sub = string.sub
local string_len = string.len
local basegraphic_printText = basegraphic_printText
local function sc_display_client_drawText(self, x, y, text, color)
    basegraphic_printText(self.customFont, self.utf8support, self, sc_display_client_drawPixel, sc_display_client_drawPixelForce, x, y, getWidth(self), getHeight(self), text, color)
    --[[
    x = math_floor(x)
    y = math_floor(y)

    local sub, len, byte
    if self.utf8support then
        sub = _utf8_sub
        len = _utf8_len
        byte = _utf8_code
    else
        sub = string_sub
        len = string_len
        byte = string_byte
    end

    local len = len(text)
    local font_width = font_width
    local font_height = font_height
    local width = getWidth(self)

    if self.customFont then
        font_width = self.customFont.width
        font_height = self.customFont.height
    end

    if x < 0 then
        local ic = 1
        while x + font_width < 0 do
            x = x + font_width + 1
            ic = ic + 1
            if ic > len or x >= width then
                return
            end
        end
        drawChar(self, x, y, sub(text, ic, ic), color)
        x = x + font_width + 1
        text = sub(text, ic + 1, len)
        len = len - ic
    end

    --старый вариант
    --if y >= 0 and (y + font_height) < self.height then
    --вот допустим размер шрифта по вертикали 1, в таком случаи предельное значения(например 127) окажеться не в пределах, так как 127 + 1 это 128, а 128 не меньше 128
    
    local height = getHeight(self)
    local ex, c
    if y >= 0 and (y + font_height) <= height then
        for i = 1, len do
            c = byte(text, i)

            ex = x + font_width
            if ex < width then
                drawCharForce(self, x, y, c, color)
            else
                drawChar(self, x, y, c, color)
                break
            end
            x = ex + 1
        end
    else
        for i = 1, len do
            c = byte(text, i)

            ex = x + font_width
            drawChar(self, x, y, c, color)
            if ex >= width then
                break
            end
            x = ex + 1
        end
    end
    ]]
end

function sc_display_client_optimize(self)
    if not self.scriptableObject.data.noDoubleEffect then
        local popularColors, oldVal, popularColor = {}, 0
        local edata = effectsData[self.quadTree.back_effect.id]
        local baseValue = 0
        for effect in pairs(self.quadTree.allEffects) do
            local data = effectsData[effect.id]
            if sm_exists(effect) and effect_isPlaying(effect) and data[2] then
                local colorHash = tableChecksum(data[1])
                if not popularColors[colorHash] then
                    popularColors[colorHash] = {data[1], 0}
                end
                local v = data[4] * data[5]
                baseValue = baseValue + v
                popularColors[colorHash][2] = popularColors[colorHash][2] + v
            end
        end
        popularColors[tableChecksum(edata[1])] = {edata[1], (edata[4] * edata[5]) - baseValue}
        for _, dat in pairs(popularColors) do
            if dat[2] > oldVal then
                popularColor = dat[1]
                oldVal = dat[2]
            end
        end

        debug_print("popularColor", popularColor)


        if popularColor and popularColor ~= self.lastLastClearColor then
            raw_set_color(self.quadTree.back_effect, popularColor)
            for effect in pairs(self.quadTree.allEffects) do
                local data = effectsData[effect.id]
                if sm_exists(effect) and effect_isPlaying(effect) and data[2] and data[1] == popularColor then
                    quad_effectHide(effect)
                    --self.quadTree.bf_idx = self.quadTree.bf_idx + 1
                    --self.quadTree.bufferedEffects[self.quadTree.bf_idx] = effect
                end
            end
        
            self.lastLastClearColor = popularColor
            if self.lastLastClearColor2 then
                self.lastLastClearColor2 = popularColor
            end

            debug_print("changed")
        end
    end
    quad_optimize(self.quadTree)
end

local math_sin = math.sin
local basegraphic_doubleBuffering = basegraphic_doubleBuffering

function sc.display.client_update(self, dt)
    --debug_print("total_effects", total_effects)
    --[[
    local allEffs = 0
    for key, value in pairs(self.quadTree.allEffects) do
        allEffs = allEffs + 1
    end
    debug_print("allEffs", allEffs)
    ]]

	if self.forceNativeRender then
		self.forceNativeRender = self.forceNativeRender - (40 / (1 / dt))
	end

    local ctick = getCurrentTick()

    if self.isRendering and self.bufferWait then
        debug_print("buffer flushing")

        self.newEffects = {}
        local isEffect = false
        if basegraphic_doubleBuffering(self, nil, getWidth(self), getHeight(self), self.customFont, self.utf8support, sc_display_client_drawPixelForce, sc_display_client_optimize) then
            self.lastLastClearColor2 = nil
            isEffect = true
        end

        if isEffect then
            debug_print("buffer flushing - isEffect!!")
    
            self.lastClearColor = nil
            self.dispValue = nil

            self.clientDrawingTimer = ctick
            self.lastDrawTime = self.clientDrawingTimer
    
            applyNew(self)
        else
            debug_print("buffer flushing - no effect")
        end


        self.bufferWait = false
        self.newEffects = nil
    end
    
    local scriptableObject = self.scriptableObject
    local quadTree = self.quadTree
    local bufferedEffects = quadTree.bufferedEffects
    local allEffects = quadTree.allEffects

    if debug_printeffects then
        debug_print("total_effects", total_effects, quadTree.bf_idx)
    end
    
    if not debug_disableEffectsBuffer then
        --если картинка давно не обновлялась
        --то минимальное каличество для удаления эфектов 5000
        --а если обновления идей сейчас то только если буферезированых минимум 10000
        local minToRemove = (not self.lastDrawTime or ctick - self.lastDrawTime >= 40) and 5000 or 10000
        if quadTree.bf_idx >= minToRemove then
            local effect
            for i = 1, 250 do
                if quadTree.bf_idx > 0 then
                    effect = table_remove(bufferedEffects)
                    quadTree.bf_idx = quadTree.bf_idx - 1
                    if effect and sm_exists(effect) then
                        --effect_stop(effect)
                        effect_destroyAndUnreg(effect)
                        total_effects = total_effects - 1

                        allEffects[effect] = nil
                    end
                else
                    break
                end
            end
        end

        --[[
        if quadTree.bf_idx >= minToRemove then
            local effect
            for i = 1, 250 do
                effect = table_remove(bufferedEffects, 1)
                if effect then
                    if sm_exists(effect) then
                        effect_stop(effect)
                    end
                    table_insert(bufferedEffects, effect)
                else
                    break
                end
            end
        end
        ]]
    end

    --debug_print("cursor works")
    if scriptableObject.character and self.clicksAllowed and self.tablet_posX and self.tablet_posY and not quadTree.splashEffect then
        if self.cursor then
            if sm_exists(self.cursor) then
                effect_setOffsetPosition(self.cursor, effectsData[self.cursor.id][6] - sm_vec3_new((self.tablet_posX / self.width) * 0.95, (self.tablet_posY / self.height) * 0.95, 0))
                effect_setParameter(self.cursor, "color", sm_color_new(0.6, (0.5 + (math_sin(math_rad(ctick * 4)) / 2)) * 0.6, 0))
            else
                self.cursor = nil
            end
        else
            local old_rotation = quadTree.rotation
            quadTree.rotation = 0
            self.cursor = quad_createEffect(quadTree, 0, 0, 0.06, 0.06, -0.0005, true, true, 0.01)
            --self.cursor = quad_createEffect(quadTree, 0, 0, 1, 1, -0.0005, true, true)
            --self.cursor = sm_effect_createEffect(sc_getEffectName(), quadTree.display.scriptableObject.character)
            --effect_setParameter(self.cursor, "uuid", cursorUuid)
            effect_setParameter(self.cursor, "uuid", sc_display_shapesUuid)
            quadTree.rotation = old_rotation
            effect_start(self.cursor)
        end
    elseif self.cursor then
        --effect_stop(self.cursor)
        effect_destroyAndUnreg(self.cursor)
        self.cursor = nil
        total_effects = total_effects - 1
    end

    --debug_print("dispValue works")
    if self.dispValue then
        self.dispValue = self.dispValue - 1
        if self.dispValue <= 0 then
            self.dispValue = nil
            
            debug_print("lastClearColor", self.lastClearColor)

            self.newEffects = {}
            sc_display_client_clear(self, self.lastClearColor, true)
            applyNew(self)
            self.newEffects = nil

            self.lastClearColor = nil
        end
    end

    if self.clientDrawingTimer and (
        self.optimize_flag or
        not self.oldOptimizeTime or
        ctick - self.oldOptimizeTime >= (40 * 5) or --автооптимизация каждые 5 секунд
        ctick - self.clientDrawingTimer >= 40 --если более секунды не было отрисовки - оптимизация
    ) then
        self.clientDrawingTimer = nil
        self.optimize_flag = nil
        self.oldOptimizeTime = ctick
        
        debug_print("effects optimization")

        self.newEffects = {}
        sc_display_client_optimize(self)
        applyNew(self)
        self.newEffects = nil
    end

    local localPlayer = sm_localPlayer_getPlayer().character
    if localPlayer and sc.restrictions then
        --[[
        local playerPos = localPlayer.worldPosition
        local selfPos
        if scriptableObject.shape then
            selfPos = scriptableObject.shape.worldPosition
        else
            selfPos = scriptableObject.character.worldPosition
        end
        ]]
        local playerPos = sm_camera_getPosition()
        local selfPos = scriptableObject.shape and scriptableObject.shape.worldPosition

        local nowIsRendering, dist = false
        if selfPos then
            dist = mathDist(selfPos, playerPos)
        end

        local r = sc.restrictions and sc.restrictions.rend
        if scriptableObject.character then
            if self.tablet_posX or self.renderAtDistance then --функция renderAtDistance на планшете паказывает экран когда планшет не в руке
                nowIsRendering = true
            end
        else
            local rendondist = sc.restrictions.allowDist and self.renderAtDistance
            if rendondist or dist < r then
                if rendondist then
                    nowIsRendering = true
                elseif self.last_raycast_time then
                    nowIsRendering = (ctick - self.last_raycast_time) < 10
                end

                if not nowIsRendering then
                    if not sc.restrictions or sc.restrictions.rays == 0 then
                        nowIsRendering = true
                    else
                        local detectedShapes = cl_displayRaycast(self, playerPos, r)
                        local localPoint, scale, pointX, pointY
                        for shape, result in pairs(detectedShapes) do
                            if shape.id == scriptableObject.shape.id then
                                localPoint = shape:transformPoint(result.pointWorld)
        
                                if localPoint and localPoint.x < 0 then
                                    localPoint = sm_vec3_new(0, localPoint.y, localPoint.z)
                                    scale = sc_display_PIXEL_SCALE * self.pixelScale
                    
                                    pointX = math_floor(self.width / 2 - localPoint.z / scale)
                                    pointY = math_floor(self.height / 2 + localPoint.y / scale)
                                
                                    if pointX >= 0 and pointX < self.width and pointY >= 0 and pointY < self.height then
                                        nowIsRendering = true
                                        self.last_raycast_time = ctick
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        --debug_print("isRendering works")
        local nowRender
        if self.isRendering ~= nowIsRendering then
            if nowIsRendering then
                nowRender = true
                quad_rootRealShow(quadTree, self)
            else
                quad_rootRealHide(quadTree, self)
            end
        end
        self.isRendering = nowIsRendering

        --debug_print("click works")
        if self.dragging.interact then
            sc.display.client_onClick(self, 1, "drag")
        elseif self.dragging.tinker then
            sc.display.client_onClick(self, 2, "drag")
        end

        --debug_print("random_hide_show works")
        if nowIsRendering and sc.restrictions and sc.restrictions.optSpeed and dist then
            local meters = math_floor(dist + 0.5)
            if meters ~= self.meters or nowRender or not self.old_opt then
                --if self.clientDrawingTimer then
                --    random_hide_show(self, 0)
                --end
                --debug_print("meters changed")
                
                local p = 0
                if meters > 2 then
                    p = ((meters * sc.restrictions.optSpeed) / self.pixelScale) * 4
                    p = constrain(p, 0, 100)
                    if p < 10 then
                        p = 0
                    --elseif p > 60 then
                    --    p = (p * 0.5) + 30
                    end
                    if p > 80 then
                        p = 80
                    end
                end

                if not self.old_p then self.old_p = p end
                --print("P", p, self.old_p, math.abs(p - self.old_p))
                if math_abs(p - self.old_p) > 5 or nowRender or not self.old_opt then
                    random_hide_show(self, p)
                    self.old_p = p
                end

                self.meters = meters
            end
        end

        if nowIsRendering then
            self.scriptableObject.network:sendToServer("server_recvPress", "reg")

            if self.old_opt and not sc.restrictions.optSpeed then
                random_hide_show(self, 0)
            end
        end
        self.old_opt = not not sc.restrictions.optSpeed
    end

    --debug_print("self.restrictions", self.restrictions, self.isRendering and self.restrictions and self.restrictions.opt)

    --[[
    if (getCurrentTick() + self.rnd) % (40 * 4) == 40 then
        debug_print("clear doValueHashCache")
        doValueHashCache = {}
    end
    ]]

    if self.clearLastClearColor3 then
        self.clearLastClearColor3 = self.clearLastClearColor3 - 1
        if self.clearLastClearColor3 <= 0 then
            self.old_backgroundChanged = false
            self.lastClearColor3 = nil
            self.clearLastClearColor3 = nil
        end
    end

    ------stylus
    --debug_print("stylus works")
    if scriptableObject.character then
        if self.tablet_left ~= self.old_tablet_left then
            sc.display.client_onInteract(self, nil, not not self.tablet_left)
        end
    
        if self.tablet_right ~= self.old_tablet_right then
            sc.display.client_onTinker(self, nil, not not self.tablet_right)
        end

        self.old_tablet_left = self.tablet_left
        self.old_tablet_right = self.tablet_right
    else
        if _G.stylus_left ~= self.old_stylus_left then
            sc.display.client_onInteract(self, nil, not not _G.stylus_left)
        end
    
        if _G.stylus_right ~= self.old_stylus_right then
            sc.display.client_onTinker(self, nil, not not _G.stylus_right)
        end

        self.old_stylus_left = _G.stylus_left
        self.old_stylus_right = _G.stylus_right
    end

    if ctick % 20 == 0 then
        if self.localLag > 0 then
            self.scriptableObject.network:sendToServer("server_recvPress", self.localLag)
            self.localLag = 0
        end
    end
end

function sc.display.client_onDataResponse(self, data)
    debug_print("client_onDataResponse", data)
    local font_data = data.fontdata
    if font_data then
        if not sm_isHost then
            if font_data.remove then
                debug_print("custom font erase")
                self.customFont = nil
            else
                if font_data.width then
                    debug_print("custom font init")
                    self.customFont = {width = font_data.width, height = font_data.height, chars = {}}
                else
                    --debug_print("custom font add", font_data.name, tostring(font_data.data))
                    self.customFont.chars[font_data.name] = font_data.data
                end
            end
        end
        return
    end

    self.quadTree.rotation = data.rotation
    if data.rotation ~= self.old_rotation then
        self.dbuffPixels = {}
        self.dbuffPixelsAll = nil

        self.buffer1 = {}
        self.buffer2 = {}
        self.buffer1All = nil
        self.buffer2All = nil

        self.old_rotation = data.rotation
    end

    if sm_isHost then return end
    self.clicksAllowed = data.clicksAllowed
    self.renderAtDistance = data.renderAtDistance
    self.skipAtLags = data.skipAtLags
    self.skipAtNotSight = data.skipAtNotSight
    self.utf8support = data.utf8support
end


local drawActions = {
    [sc_display_drawType.clear] = function (self, t) return sc_display_client_clear(self, t[2]) end,
    [sc_display_drawType.drawPixel] = function (self, t) return sc_display_client_drawPixel(self, t[3], t[4], t[2]) end,
    [sc_display_drawType.drawRect] = function (self, t) return sc_display_client_drawRect(self, t[3], t[4], t[5], t[6], t[2]) end,
    [sc_display_drawType.fillRect] = function (self, t) return sc_display_client_fillRect(self, t[3], t[4], t[5], t[6], t[2]) end,
    [sc_display_drawType.drawCircle] = function (self, t) return sc_display_client_drawCircle(self, t[3], t[4], t[5], t[2]) end,
    [sc_display_drawType.fillCircle] = function (self, t) return sc_display_client_fillCircle(self, t[3], t[4], t[5], t[2]) end,
    [sc_display_drawType.drawLine] = function (self, t) return sc_display_client_drawLine(self, t[3], t[4], t[5], t[6], t[2]) end,
    [sc_display_drawType.drawText] = function (self, t) return sc_display_client_drawText(self, t[3], t[4], t[5], t[2]) end,
    [sc_display_drawType.optimize] = function (self) self.optimize_flag = true end,
}

function sc.display.client_drawStack(self, sendstack)
    local startExecTimeStart = os_clock()

    sendstack = sendstack or self.scriptableObject.sendData
    if sendstack then
        if self.quadTree.splashEffect and sm_exists(self.quadTree.splashEffect) then
            effect_destroyAndUnreg(self.quadTree.splashEffect)
            self.quadTree.splashEffect = nil
        end
        if sendstack.oops then
            local eff = quad_createEffect(self.quadTree, 0, 0, self.quadTree.sizeX, self.quadTree.sizeY, nil, true)
            --effect_setParameter(eff, "uuid", oopsUuid)
            --effect_setParameter(eff, "uuid", sc_display_shapesUuid)
            effect_setParameter(eff, "color", oopsColor)
            if self.scriptableObject.character then
                effectsData[eff.id][8] = sm_quat_fromEuler(sm_vec3_new(180, 90, 0))
                quad_effectShow(eff)
            end
            self.quadTree.splashEffect = eff
            applyNew(self)    
        end

        if sendstack.endPack then
            if self.savestack then
                local lstack = self.savestack
                local lidx = self.savestack_idx
                for i = 1, #sendstack do
                    lstack[lidx] = sendstack[i]
                    lidx = lidx + 1
                end
                self.savestack_idx = lidx
            else
                self.savestack = sendstack
            end
        else
            if not self.savestack then self.savestack = {} self.savestack_idx = 1 end
            local lstack = self.savestack
            local lidx = self.savestack_idx
            for i = 1, #sendstack do
                lstack[lidx] = sendstack[i]
                lidx = lidx + 1
            end
            self.savestack_idx = lidx
            return
        end
    end
    local stack = self.savestack
    self.savestack = nil
    self.savestack_idx = nil
    if not stack then
        return
    end

    debug_print("start render --------------------", self.isRendering, sendstack.force, self.skipAtLags, self.skipAtNotSight, self.forceNativeRender)

    if sendstack.force then
        self.dbuffPixels = {}
        self.dbuffPixelsAll = nil
    else
        if self.skipAtNotSight and not self.isRendering then debug_print("skipAtNotSight skipped") return end --если skipAtNotSight true, то картинка не будет обновляться когда ты на нее не смотриш
        if self.skipAtLags and sc.restrictions and sc.deltaTime >= (1 / sc.restrictions.skipFps) then debug_print("skipAtLags skipped") return end
    end

    self.localLag = self.localLag + ((os_clock() - startExecTimeStart) * sc.clockLagMul)
    if self.localLag > 120 then
        debug_print_force("localLag > 120!!")
    end

    local ctick = getCurrentTick()

    local startExecTime = os_clock()

    local isEndClear = stack[#stack][1] == 0
    local clearColor
	for i, v in ipairs(stack) do
		if v[1] == 0 then
			clearColor = formatColor(v[2], true)
			break
		end
	end

    self.newEffects = {}
    local isEffect = false --если от всего стека был хоть какой-то смысл
    local backgroundChanged = clearColor and clearColor ~= self.lastClearColor3
    debug_print("background change detecter", clearColor, self.lastClearColor3, backgroundChanged, self.old_backgroundChanged)

    if isEndClear and #stack == 1 then
        debug_print("clear only render")

        local col = formatColor(stack[1][2], true)

        self.buffer1 = {}
        self.buffer2 = {}
        self.buffer2All = col
        self.buffer1All = col

        if not sc_display_client_clear(self, col) then
            isEffect = true
        end

        self.oldRenderType = true
        self.bufferWait = false
    elseif self.isRendering and ((backgroundChanged and not self.old_backgroundChanged) or sendstack.forceNative or (self.forceNativeRender and self.forceNativeRender > 0)) then
        debug_print("native render")

        self.buffer1 = {}
        self.buffer2 = {}
        self.buffer2All = nil
        self.buffer1All = nil

        local startRnd = os_clock()
        for _, v in ipairs(stack) do
            v[2] = formatColor(v[2], v[1] == 0)
    
            if v[1] ~= 0 and v[1] ~= 8 then
                self.lastLastClearColor2 = nil
            end
    
            --если хоть что-то не вернуло значения, значит эфект от стека был
            if not drawActions[v[1]](self, v) and v[1] ~= 8 then
                isEffect = true
            end
        end
        self.lastNativeRenderTime = os_clock() - startRnd
        self.oldRenderType = true
        self.bufferWait = false
    else
        debug_print("buffer render")

        local startRnd = os_clock()
        if basegraphic_doubleBuffering(self, stack, getWidth(self), getHeight(self), self.customFont, self.utf8support, self.isRendering and sc_display_client_drawPixelForce, sc_display_client_optimize) then
            self.lastLastClearColor2 = nil
            isEffect = true
        end

		if self.lastNativeRenderTime then
			local rendTime = os_clock() - startRnd
			local dt2 = self.lastNativeRenderTime * 2
			if not self.oldRenderType and dt2 < rendTime and not debug_disableForceNativeRender then
				local add = constrain(math.ceil(rendTime / dt2) * 5, 10, 40)
				debug_print("force native render", self.lastNativeRenderTime, dt2, rendTime, add)
				self.forceNativeRender = add
			end
		end

        self.oldRenderType = false
        if not self.isRendering then
            self.bufferWait = true
        end
    end

    self.old_backgroundChanged = backgroundChanged
    if clearColor then
    	self.lastClearColor3 = clearColor
    end
    self.clearLastClearColor3 = 5

    if isEffect then
        debug_print("isEffect!!")

        if isEndClear then
            self.lastClearColor = clearColor
            self.dispValue = 40 * 2
        else
            self.lastClearColor = nil
            self.dispValue = nil
        end
        
        self.clientDrawingTimer = ctick
        self.lastDrawTime = self.clientDrawingTimer

        applyNew(self)
    else
        debug_print("no effect")
    end
    self.newEffects = nil

    self.localLag = self.localLag + ((os_clock() - startExecTime) * sc.clockLagMul)
    if self.localLag > 120 then
        debug_print_force("localLag > 120!!")
    end
end


function sc.display.client_onClick(self, type, action, localPoint) -- type - 1:interact|2:tinker (e.g 1 or 2), action - pressed, released, drag
    if not self.clicksAllowed or (self.scriptableObject and self.scriptableObject.data and self.scriptableObject.data.noTouch) then
        return
    end

    local function detect(pointX, pointY)
        pointX = math_floor(pointX + 0.5)
        pointY = math_floor(pointY + 0.5)

        if pointX >= 0 and pointX < self.width and pointY >= 0 and pointY < self.height then
            if action == "drag" then
                local t = type == 1 and self.dragging.interactLastPos or self.dragging.tinkerLastPos

                if t.x ~= -1 then
                    if t.x == pointX and t.y == pointY then 
                        return
                    else
                        t.x = pointX
                        t.y = pointY
                    end
                else
                    t.x = pointX
                    t.y = pointY
                    return
                end
            end

            local reverseX, reverseY, changeXY
            if self.quadTree.rotation == 1 then
                changeXY = true
                reverseX = true
            elseif self.quadTree.rotation == 2 then
                reverseX = true
                reverseY = true
            elseif self.quadTree.rotation == 3 then
                changeXY = true
                reverseY = true
            end
            if reverseX then
                pointX = self.width - pointX - 1
            end
            if reverseY then
                pointY = self.height - pointY - 1
            end
            if changeXY then
                pointX, pointY = pointY, pointX
            end

            debug_print("touch", pointX, pointY)

            self.scriptableObject.network:sendToServer("server_recvPress", { pointX, pointY, action, type })
        end
    end

    local function reg(localPoint)
        if localPoint and localPoint.x < 0 then
            local localPoint = sm_vec3_new(0, localPoint.y, localPoint.z)
            local scale = sc_display_PIXEL_SCALE * self.pixelScale

            local pointX = math_floor(self.width / 2 - localPoint.z / scale)
            local pointY = math_floor(self.height / 2 + localPoint.y / scale)
        
            detect(pointX, pointY)
        end
    end
    
    if localPoint then
        reg(localPoint)
    elseif self.scriptableObject.shape then
        local succ, res = sm_localPlayer.getRaycast((sc.restrictions and sc.restrictions.rend) or RENDER_DISTANCE)
        if succ then
            local shape = self.scriptableObject.shape
            local localPoint = shape:transformPoint(res.pointWorld)
            reg(localPoint)
        end
    elseif self.tablet_posX and self.tablet_posY then
        detect(self.tablet_posX, self.tablet_posY)
    end
end

function sc.display.client_onInteract(self, character, state)
    self.dragging.interact = state
    if state then
        local t = self.dragging.interactLastPos
        t.x = -1
        t.y = -1
    end
    sc.display.client_onClick(self, 1, state and "pressed" or "released")
end

function sc.display.client_onTinker(self, character, state)
    self.dragging.tinker = state
    if state then
        local t = self.dragging.tinkerLastPos
        t.x = -1
        t.y = -1
    end
    sc.display.client_onClick(self, 2, state and "pressed" or "released")
end

function sc.display.client_canInteract(self, character)
    if self.scriptableObject and self.scriptableObject.data and self.scriptableObject.data.noTouch then
        return false
    end

    return self.clicksAllowed
end

function sc.display.client_canTinker(self, character)
    if self.scriptableObject and self.scriptableObject.data and self.scriptableObject.data.noTouch then
        return false
    end

    return self.clicksAllowed
end