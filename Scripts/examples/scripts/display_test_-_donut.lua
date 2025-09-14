-- Get display component (128 x 128 recommended) 
local display = getComponent("display")

-- Get width and height
local width, height = display.getWidth(), display.getHeight()

-- Initialise variables
local centerX, centerY = width / 2, height / 2  -- Center of the display
local rotationSpeedX, rotationSpeedY = 0.04, 0.02  -- Speed of rotation
local angleX, angleY = 0, 0  -- Initial angles for rotation

-- Donut parameters
local R = 1.5  -- Major radius
local r = 0.8  -- Minor radius
local segments = 10  -- Number of segments for the donut

-- Precompute donut vertices
local vertices = {}
for theta = 1, segments do
    for phi = 1, segments do
        -- Parametric equations for the torus (donut)
        local thetaAngle = 2 * math.pi * (theta / segments)
        local phiAngle = 2 * math.pi * (phi / segments)

        local x = (R + r * math.cos(phiAngle)) * math.cos(thetaAngle)
        local y = (R + r * math.cos(phiAngle)) * math.sin(thetaAngle)
        local z = r * math.sin(phiAngle)
        
        table.insert(vertices, sm.vec3.new(x, y, z))
    end
end

function projectVertex(vertex)
    -- Simple perspective projection
    local scale = 50 / (vertex.z + 3)
    local x = vertex.x * scale + centerX
    local y = vertex.y * scale + centerY

    -- Clamp and round the coordinates
    x = sm.util.clamp(math.floor(x + 0.5), 1, width)
    y = sm.util.clamp(math.floor(y + 0.5), 1, height)

    return x, y
end

function calculateShading(zValue)
    -- Normalize zValue to a 0-1 range based on its depth (closer is darker)
    local normalizedZ = sm.util.clamp((zValue + 3) / 6, 0, 1)
    -- Create a color shade between light and dark based on normalizedZ
    return sm.color.new(1 - normalizedZ, 1 - normalizedZ, 1 - normalizedZ)
end

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    -- Clear the display
    display.clear()

    -- Create projected vertices table
    local projectedVertices = {}

    -- Loop through each vertex
    for i = 1, #vertices do
        -- Get the current vertex and rotate it based on the x and y angles
        local rotatedVertex = vertices[i]
        rotatedVertex = rotatedVertex:rotateX(angleX)
        rotatedVertex = rotatedVertex:rotateY(angleY)

        -- Project the rotated vertex to 2D screen space and add to the table
        local x, y = projectVertex(rotatedVertex)
        projectedVertices[i] = {x, y, z = rotatedVertex.z}
    end

    -- Loop through vertices and connect adjacent points to form the wireframe donut
    for theta = 1, segments do
        for phi = 1, segments do
            local nextTheta = theta % segments + 1
            local nextPhi = phi % segments + 1

            local v1 = projectedVertices[(theta - 1) * segments + phi]
            local v2 = projectedVertices[(nextTheta - 1) * segments + phi]
            local v3 = projectedVertices[(theta - 1) * segments + nextPhi]

            -- Calculate shading based on the depth of the vertices
            local color1 = calculateShading(v1.z)
            local color2 = calculateShading(v2.z)
            local color3 = calculateShading(v3.z)

            -- Draw lines to connect vertices in the grid with the appropriate shading
            display.drawLine(v1[1], v1[2], v2[1], v2[2], color1)
            display.drawLine(v1[1], v1[2], v3[1], v3[2], color2)
        end
    end

    -- Update the display
    display.flush()

    -- Increment rotation angles
    angleX = angleX + rotationSpeedX
    angleY = angleY + rotationSpeedY
end