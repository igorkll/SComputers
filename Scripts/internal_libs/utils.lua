function sc_reglib_utils()
local utils = {}

utils.clamp = constrain
utils.map = map
utils.roundTo = round
utils.split = function(tool, str, seps)
    return strSplit(tool, str, seps)
end
utils.splitByMaxSize = splitByMaxSize
utils.splitByMaxSizeWithTool = splitByMaxSizeWithTool
utils.deepcopy = sc.advDeepcopy
utils.copy = sc.copy
utils.md5 = function (str)
    return md5.sumhexa(str, true)
end
utils.md5bin = function (str)
    return md5.sum(str, true)
end

utils.sha256 = function (str)
    return sha256.sha256hex(str, true)
end
utils.sha256bin = function (str)
    return sha256.sha256bin(str, true)
end

utils.dist = mathDist

function utils.fromEuler(euler)
    return fromEuler(euler.x, euler.y, euler.z)
end
utils.toEuler = toEuler

function utils.radarTriangulation(radarTarget, radarPosition, radarDirectionYPrad)
    local radar_X = radarPosition.x * 4
    local radar_Y = radarPosition.y * 4
    local radar_Z = radarPosition.z * 4

    local flip = 1
    local target_2d_distance = math.abs(radarTarget[4] * 4*math.cos(radarTarget[3]))

    return sm.vec3.new(
        radar_X + (target_2d_distance * math.sin(flip*(radarTarget[2]+radarDirectionYPrad))) * -1,
        radar_Y + (target_2d_distance * (-1*math.cos(flip*(radarTarget[2]+radarDirectionYPrad)))) * 1,
        radar_Z + (radarTarget[4]*4)*math.sin(-flip*radarTarget[3]) * -1
    ) / 4
end

utils.createPID = createPID

return utils
end