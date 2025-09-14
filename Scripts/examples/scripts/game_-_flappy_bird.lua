--designed to work with a 128x128 display
local display = getComponent("display")
local width, height = display.getSize()

display.reset()
display.setClicksAllowed(true)

-- Bird properties
local bird = {x = width / 4, y = height / 2, velocity = 0, gravity = 0.3, jumpStrength = -3}

-- Pipes properties
local pipes = {}
local pipeWidth = 20
local pipeMainHeight = 5
local startPipeGap = 40
local minPipeGap = 30
local offsetPipeGap = 5
local pipeBodyOffset = 5
local pipeGap = startPipeGap
local pipeSpeed = 2
local spawnRate = 1
local spawnTimer = 0
local score = 0

local _buttonState = false
local gameOver = false

-- Function to spawn new pipes
function spawnPipe()
    local gapY = math.random(offsetPipeGap, height - pipeGap - offsetPipeGap)
    table.insert(pipes, {x = width, gapY = gapY})
end

-- Function to draw bird
function drawBird()
    display.fillRect(bird.x, bird.y, 5, 5, 0xeb4907)
end

-- Function to draw pipes
function drawPipes()
    for _, pipe in ipairs(pipes) do
        display.fillRect(pipe.x + pipeBodyOffset, 0, pipeWidth - (pipeBodyOffset * 2), pipe.gapY, 0xebb307)
        display.fillRect(pipe.x + pipeBodyOffset, pipe.gapY + pipeGap, pipeWidth - (pipeBodyOffset * 2), height - pipe.gapY - pipeGap, 0xebb307)
        
        display.fillRect(pipe.x, pipe.gapY - pipeMainHeight, pipeWidth, pipeMainHeight, 0xeb8007)
        display.fillRect(pipe.x, pipe.gapY + pipeGap, pipeWidth, pipeMainHeight, 0xeb8007)
    end
end

-- Function to check collision
function checkCollision()
    if bird.y < 0 or bird.y + 5 > height then return true end
    for _, pipe in ipairs(pipes) do
        if bird.x < pipe.x + pipeWidth and bird.x + 5 > pipe.x then
            if bird.y < pipe.gapY or bird.y + 5 > pipe.gapY + pipeGap then
                return true
            end
        end
    end
    return false
end

-- Function to reset game
function resetGame()
    bird.y = height / 2
    bird.velocity = 0
    pipes = {}
    score = 0
    gameOver = false
    spawnTimer = 0
end

-- Main game loop
function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    -- Click process code
    local click = display.getClick()
    local buttonState = getreg("jump") == 1
    if (click and click.state == "pressed") or (buttonState and not _buttonState) then
        if gameOver then
            reboot()
            return
        else
            bird.velocity = bird.jumpStrength
        end
    end
    _buttonState = buttonState

    -- Collision detection
    if checkCollision() then
        gameOver = true
    end
    
    -- Gameover screen
    if gameOver then
        display.clear(0x4d4d4d)
        display.drawCenteredText(width / 2, height / 2, "Game Over!", 0xFF0000)
        display.drawCenteredText(width / 2, height / 2 + 10, "Score: " .. score, 0xFFFFFF)
        display.flush()
        return
    end

    -- Bird physics
    bird.velocity = bird.velocity + bird.gravity
    bird.y = bird.y + bird.velocity
    
    -- Pipe logic
    spawnTimer = spawnTimer + 1
    if spawnTimer % spawnRate == 0 then
        spawnPipe()
        spawnRate = math.random(30, 60)
        spawnTimer = 0
    end
    for _, pipe in ipairs(pipes) do
        pipe.x = pipe.x - pipeSpeed
        if pipe.x + pipeWidth == bird.x then
            score = score + 1
        end
    end
    if #pipes > 0 and pipes[1].x + pipeWidth < 0 then
        table.remove(pipes, 1)
    end
    pipeGap = startPipeGap - math.floor(score / 5)
    if pipeGap < minPipeGap then
        pipeGap = minPipeGap
    end
    
    -- Draw everything
    display.clear(0x0787c6)
    drawBird()
    drawPipes()
    display.fillRect(0, height - 3, width, 3, 0x058726)
    display.drawText(5, 5, "Score: " .. score, 0xFFFFFF)
    
    -- Update Display
    display.flush()
end