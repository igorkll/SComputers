local display = getComponents("display")[1]
local width, height = display.getWidth(), display.getHeight()

local A, B = 0, 0
local R1, R2 = width / 16, width / 8
local K1, K2 = width / 2, height / 2

function renderFrame()
    local zBuffer = {}
    
    for i = 1, width * height do
        zBuffer[i] = 0
    end
    
    display.clear()
    
    for theta = 0, math.pi * 2, 0.03 do
        for phi = 0, math.pi * 2, 0.01 do
            local cosTheta, sinTheta = math.cos(theta), math.sin(theta)
            local cosPhi, sinPhi = math.cos(phi), math.sin(phi)
            local cosA, sinA = math.cos(A), math.sin(A)
            local cosB, sinB = math.cos(B), math.sin(B)
            
            local circleX = R2 + R1 * cosTheta
            local circleY = R1 * sinTheta
            
            local x = circleX * (cosB * cosPhi + sinA * sinB * sinPhi) - circleY * cosA * sinB
            local y = circleX * (sinB * cosPhi - sinA * cosB * sinPhi) + circleY * cosA * cosB
            local z = K2 + cosA * circleX * sinPhi + circleY * sinA
            local ooz = 1 / z
            
            local xp = math.floor(width / 2 + K1 * x * ooz)
            local yp = math.floor(height / 2 - K1 * y * ooz)
            local idx = xp + yp * width
            
            local L = 0.5 * (cosPhi * cosTheta - sinA * sinTheta - cosA * sinPhi)
            if idx > 0 and idx < width * height and L > 0 then
                if ooz > zBuffer[idx] then
                    zBuffer[idx] = ooz
                    local brightness = math.floor(L * 255)
                    display.drawPixel(xp, yp, brightness)
                end
            end
        end
    end
end

function onTick()
    display.clear()
    A = A + 0.04
    B = B + 0.02
    renderFrame()
    display.flush()
end


_enableCallbacks = true