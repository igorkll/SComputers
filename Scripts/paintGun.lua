paintGun = class()
paintGun.maxParentCount = 1
paintGun.maxChildCount = 0
paintGun.connectionInput = sm.interactable.connectionType.composite
paintGun.connectionOutput = sm.interactable.connectionType.none
paintGun.colorNormal = sm.color.new("#aa0000")
paintGun.colorHighlight = sm.color.new("#ff0303")
paintGun.componentType = "paint"

local blockSize = sm.vec3.new(1, 1, 1)
local floor = math.floor
local oneSize = sm.vec3.new(0.25, 0.25, 0.25)

function paintGun:server_onCreate()
    self.interactable.publicData = {
        sc_component = {
            type = paintGun.componentType,
            api = {
                shot = function(color)
                    self.shot = sc.formatColor(color)
                end,
                scan = function ()
                    local ok, raydata = sm.physics.raycast(self.shape.worldPosition, self.shape.worldPosition + (self.shape.worldRotation * sm.vec3.new(0, 0, 4)))
                    if ok then
                        local shape = raydata:getShape()
                        local character = raydata:getCharacter()
                        local joint = raydata:getJoint()
                        local harvestable = raydata:getHarvestable()

                        if shape then
                            return shape.color, raydata.fraction * 4
                        elseif character then
                            return character.color, raydata.fraction * 4
                        elseif joint then
                            return joint.color, raydata.fraction * 4
                        elseif harvestable then
                            if sc.treesPainted[harvestable.id] then
                                return sc.treesPainted[harvestable.id][2] or sm.color.new(0, 0, 0), raydata.fraction * 4
                            else
                                return sm.color.new(0, 0, 0), raydata.fraction * 4
                            end
                        end
                    end
                end
            }
        }
    }
end

function paintGun:server_onFixedUpdate()
    if self.shot then
        local data = {}

        local ok, raydata = sm.physics.raycast(self.shape.worldPosition, self.shape.worldPosition + (self.shape.worldRotation * sm.vec3.new(0, 0, 4)))
        if ok then
            data.pos = raydata.pointWorld
            local shape = raydata:getShape()
            local character = raydata:getCharacter()
            local joint = raydata:getJoint()
            local harvestable = raydata:getHarvestable()

            if shape then
                if shape.color ~= self.shot then
                    if shape.isBlock and shape:getBoundingBox() ~= oneSize then
                        local uuid = shape.uuid
                        local pos = raydata.pointLocal + (shape:transformRotation(self.shape.worldRotation) * sm.vec3.new(0, 0, 0.1))

                        local lpos = pos * 4
                        lpos.x = floor(lpos.x)
                        lpos.y = floor(lpos.y)
                        lpos.z = floor(lpos.z)

                        shape:destroyBlock(lpos)
                        local block = shape.body:createBlock(uuid, blockSize, lpos)
                        block.color = self.shot
                    else
                        shape.color = self.shot
                    end
                end
            elseif character then
                character.color = self.shot
            elseif joint then
                joint.color = self.shot
            elseif harvestable then
                sc.treesPainted[harvestable.id] = {harvestable, self.shot}
                sm.storage.save("sc_treesPainted", sc.treesPainted)
                data[1] = harvestable
                data[2] = self.shot
            end
        end

        self.network:sendToClients("cl_shot", data)
        self.shot = nil
        self.allow_update = nil
    end
end



function paintGun:cl_shot(data)
    if type(data[1]) == "Harvestable" then
        data[1]:setColor(data[2])
    end
    if data.pos then
        sm.effect.playEffect("PaintTool - Paint", data.pos)
    else
        sm.effect.playEffect("PaintTool - Paint", self.shape.worldPosition)
    end
    --sm.effect.playEffect("Steam - quench", self.shape.worldPosition, (self.shape.worldRotation * sm.vec3.new(0, 0, 3)))
end