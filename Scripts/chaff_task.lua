sc.background.chaff = sc.background.chaff or {}

local uuid = sm.uuid.new("24986ff2-3735-42d5-b3ba-f8c60c3b70bb")
local color = sm.color.new(1, 0, 0)
local checkFromHeight = 1000
local addSizeSpeed = 5 / 40

local function doChaffObjects(chaff_objects, clientSide)
    for i = #chaff_objects, 1, -1 do
        local chaffObject = chaff_objects[i]
        
        if sm.physics.raycast(sm.vec3.new(0, 0, checkFromHeight), chaffObject.position + sm.vec3.new(0, 0, sc.chaff_visible_size + 4), nil, sm.physics.filter.terrainSurface) then
            table.remove(chaff_objects, i)

            if chaffObject.effect then
                chaffObject.effect:destroy()
            end
        elseif clientSide then
            if not chaffObject.effect then
                chaffObject.radius = 0.1

                chaffObject.rotation = sm.vec3.new(math.rad(math.random(-360, 360)), math.rad(math.random(-360, 360)), math.rad(math.random(-360, 360)))
                chaffObject.rotationSpeed = sm.vec3.new(
                    math.rad(math.random(-360, 360)) / 40,
                    math.rad(math.random(-360, 360)) / 40,
                    math.rad(math.random(-360, 360)) / 40
                )
                
                chaffObject.effect = sm.effect.createEffect("ShapeRenderable")
                chaffObject.effect:setParameter("uuid", uuid)
                chaffObject.effect:setParameter("color", color)
                chaffObject.effect:setPosition(chaffObject.position)
                chaffObject.effect:start()
            end
            
            chaffObject.effect:setPosition(chaffObject.position)
            chaffObject.effect:setRotation(sm.quat.fromEuler(chaffObject.rotation))
            chaffObject.effect:setScale(sm.vec3.new(chaffObject.radius, chaffObject.radius, chaffObject.radius))

            chaffObject.rotation = chaffObject.rotation + chaffObject.rotationSpeed
            chaffObject.radius = chaffObject.radius + addSizeSpeed
            if chaffObject.radius > sc.chaff_visible_size then
                chaffObject.radius = sc.chaff_visible_size
            end
        end

        chaffObject.position = chaffObject.position + chaffObject.move
    end
end

function sc.background.chaff:server()
    doChaffObjects(sc.sv_chaff_objects)
end

function sc.background.chaff:client()
    doChaffObjects(sc.cl_chaff_objects, true)
end