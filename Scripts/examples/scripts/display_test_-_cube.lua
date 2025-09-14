local display = getComponent("display")
local width, height = display.getSize()

-- Camera parameters
local fov = math.rad(90) -- Field of view
local scale = math.tan(fov / 2)

-- Cube vertices (in local coordinates)
local vertices = {
    {-1, -1, -1}, {1, -1, -1}, {1, 1, -1}, {-1, 1, -1},
    {-1, -1,  1}, {1, -1,  1}, {1, 1,  1}, {-1, 1,  1}
}

-- Cube faces (vertex indices)
local faces = {
    {1, 2, 3, 4}, {5, 6, 7, 8}, {1, 2, 6, 5}, {2, 3, 7, 6},
    {3, 4, 8, 7}, {4, 1, 5, 8}
}

-- Convert 3D coordinates to 2D screen coordinates
function project(x, y, z)
    local zNear = 2  -- Clipping plane
    local zFar = 10   -- Far render distance
    local depth = 5   -- Scene depth

    z = z + depth
    if z <= zNear then return nil end

    local screenX = (x / (z * scale)) * (width / 2) + (width / 2)
    local screenY = (y / (z * scale)) * (height / 2) + (height / 2)

    return math.floor(screenX), math.floor(screenY), z
end

-- Rotate a point in 3D space
function rotate(x, y, z, angleX, angleY)
    -- Rotation around X-axis
    local cosX, sinX = math.cos(angleX), math.sin(angleX)
    local y1, z1 = y * cosX - z * sinX, y * sinX + z * cosX

    -- Rotation around Y-axis
    local cosY, sinY = math.cos(angleY), math.sin(angleY)
    local x2, z2 = x * cosY + z1 * sinY, -x * sinY + z1 * cosY

    return x2, y1, z2
end

-- Start rendering
local angleX, angleY = 0, 0

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    display.clear(0x000000) -- Clear screen (black background)

    -- Rotate and project vertices
    local projected = {}
    for i, v in ipairs(vertices) do
        local x, y, z = rotate(v[1], v[2], v[3], angleX, angleY)
        local px, py, pz = project(x, y, z)
        if px then
            projected[i] = {px, py, pz}
        end
    end

    -- Draw cube faces
    for _, face in ipairs(faces) do
        local p1, p2, p3, p4 = projected[face[1]], projected[face[2]], projected[face[3]], projected[face[4]]
        if p1 and p2 and p3 and p4 then
            display.drawLine(p1[1], p1[2], p2[1], p2[2], 0xFFFFFF)
            display.drawLine(p2[1], p2[2], p3[1], p3[2], 0xFFFFFF)
            display.drawLine(p3[1], p3[2], p4[1], p4[2], 0xFFFFFF)
            display.drawLine(p4[1], p4[2], p1[1], p1[2], 0xFFFFFF)
        end
    end

    display.flush()

    -- Update rotation angles
    angleX = angleX + 0.02
    angleY = angleY + 0.015
end
