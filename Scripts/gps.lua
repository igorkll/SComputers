gps = class()
gps.maxParentCount = 1
gps.maxChildCount = 0
gps.connectionInput = sm.interactable.connectionType.composite
gps.connectionOutput = sm.interactable.connectionType.none
gps.colorNormal = sm.color.new("1e8efa")
gps.colorHighlight = sm.color.new("37b2fd")
gps.componentType = "gps" --absences can cause problems

function gps:sv_createGpsData(shape)
    return sc.advDeepcopy({
        position = shape.worldPosition,
        rotation = shape.worldRotation,
        rotationEuler = toEuler(shape.worldRotation),
        velocity = shape.velocity,
        speed = shape.velocity:length(),
        angularVelocity = shape.body.angularVelocity,
        distance = mathDist(self.shape.worldPosition, shape.worldPosition),

        --aliases
        worldPosition = shape.worldPosition,
        worldRotation = shape.worldRotation,
        localPosition = shape.localPosition,
        localRotation = shape.localRotation,
        xAxis = shape.xAxis,
        yAxis = shape.yAxis,
        zAxis = shape.zAxis,
        up = shape.up,
        at = shape.at,
        right = shape.right
    })
end

function gps:server_onCreate()
    sc.creativeCheck(self, self.data and self.data.creative)

    self.interactable.publicData = {
        sc_component = {
            type = gps.componentType,
            api = {
                getRadius = function ()
                    return math.huge
                end,
                getSelfGpsData = function ()
                    local gpsdata = self:sv_createGpsData(self.shape)
                    gpsdata.distance = 0
                    return gpsdata
                end,
                getTagsGpsData = function (label)
                    checkArg(1, label, "string", "number")
                    label = tostring(label)

                    local gpsdatas = {}
                    for id, gpstag in pairs(sc.gpstags) do
                        if gpstag.freq == label then
                            table.insert(gpsdatas, self:sv_createGpsData(gpstag.shape))
                        end
                    end
                    return gpsdatas
                end
            }
        }
    }
end