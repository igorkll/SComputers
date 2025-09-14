radarDetector = class()
radarDetector.maxParentCount = 1
radarDetector.maxChildCount = 0
radarDetector.connectionInput = sm.interactable.connectionType.composite
radarDetector.connectionOutput = sm.interactable.connectionType.none
radarDetector.colorNormal = sm.color.new("#134da9")
radarDetector.colorHighlight = sm.color.new("#3080ff")
radarDetector.componentType = "radarDetector"

function radarDetector:server_onCreate()
    self.interactable.publicData = {
        sc_component = {
            type = radarDetector.componentType,
            api = {
                getRadars = function()
                    local tick = sm.game.getCurrentTick()
                    if tick == self.old_tick and not sc.restrictions.disableCallLimit then
                        error("getRadars can only be used 1 time per tick on one radar", 2)
                    end
                    self.old_tick = tick

                    local radars = {}
                    for _, data in pairs(sc.radarDetectedBodies[self.shape:getBody().id] or {}) do
                        if tick < data[1] and not data[3][self.interactable.id] then
                            local direction = data[2] - self.shape.worldPosition
                            local f_at = sm.quat.getUp(self.shape.worldRotation)
                            local f_up = sm.quat.getAt(self.shape.worldRotation)
                            table.insert(radars, (sm.quat.lookRotation(f_at, f_up) * direction):normalize())
                            --table.insert(radars, (self.shape:transformDirection(direction)):normalize())
                            data[3][self.interactable.id] = true
                        end
                    end
                    return radars
                end
            }
        }
    }
end

