local display = getComponent("display")
local width, height = display.getSize()
display.setClicksAllowed(true)

-- Paddle properties
local paddleWidth, paddleHeight = 3, 15
local playerPaddle = {x = 5, y = height / 2 - paddleHeight / 2, speed = 2, color = 0x00FF00}
local aiPaddle = {x = width - 8, y = height / 2 - paddleHeight / 2, speed = 1.5, color = 0xFF0000}
local aiStop = 0

-- Ball properties
local ballSpeed = 1.6
local ball = {x = width / 2, y = height / 2, dx = -ballSpeed, dy = ballSpeed, size = 3, color = 0xFFFF00}

-- Score
local playerScore = 0
local aiScore = 0

-- Controls
local touchY = height / 2

-- Function to draw paddles, ball, score, and divider
function drawGame()
    display.clear(0x0a6b85)
    display.fillRect(playerPaddle.x, playerPaddle.y, paddleWidth, paddleHeight, playerPaddle.color)
    display.fillRect(aiPaddle.x, aiPaddle.y, paddleWidth, paddleHeight, aiPaddle.color)
    display.fillRect(ball.x, ball.y, ball.size, ball.size, ball.color)
    
    -- Draw center line
    for i = 0, height, 4 do
        display.fillRect(width / 2 - 1, i, 2, 2, 0xFFFFFF)
    end
    
    -- Draw score
    display.drawText(width / 4, 5, tostring(playerScore), 0xFFFFFF)
    display.drawText(3 * width / 4, 5, tostring(aiScore), 0xFFFFFF)
    
    display.flush()
end

-- Function to update paddle positions
function updatePaddles()
    -- Move player paddle based on touch input
    playerPaddle.y = touchY - paddleHeight / 2
    if playerPaddle.y < 0 then playerPaddle.y = 0 end
    if playerPaddle.y + paddleHeight > height then playerPaddle.y = height - paddleHeight end
    
    -- AI movement (follows the ball with some delay)
    if aiStop <= 0 then
        if ball.y < aiPaddle.y + paddleHeight / 2 then
            aiPaddle.y = aiPaddle.y - aiPaddle.speed
        elseif ball.y > aiPaddle.y + paddleHeight / 2 then
            aiPaddle.y = aiPaddle.y + aiPaddle.speed
        end
    else
        aiStop = aiStop - 1
    end
    if aiPaddle.y < 0 then aiPaddle.y = 0 end
    if aiPaddle.y + paddleHeight > height then aiPaddle.y = height - paddleHeight end
end

-- Function to update ball movement and collisions
function updateBall()
    ball.x = ball.x + ball.dx
    ball.y = ball.y + ball.dy
    
    -- Collision with top and bottom walls
    if ball.y <= 0 or ball.y + ball.size >= height then
        ball.dy = -ball.dy
    end
    
    -- Collision with paddles
    if ball.dx < 0 and ball.x <= playerPaddle.x + paddleWidth and ball.y + ball.size >= playerPaddle.y and ball.y <= playerPaddle.y + paddleHeight then
        ball.dx = math.abs(ball.dx) -- Ensure ball moves right
    elseif ball.dx > 0 and ball.x + ball.size >= aiPaddle.x and ball.y + ball.size >= aiPaddle.y and ball.y <= aiPaddle.y + paddleHeight then
        ball.dx = -math.abs(ball.dx) -- Ensure ball moves left
        -- Fix ball sticking under paddle
        if ball.y < aiPaddle.y then
            ball.dy = -math.abs(ball.dy)
        elseif ball.y > aiPaddle.y + paddleHeight then
            ball.dy = math.abs(ball.dy)
        end
    end
    
    -- Reset ball and update score if it goes out of bounds
    if ball.x < 0 then
        aiScore = aiScore + 1
        ball.x, ball.y = width / 2, height / 2
        ball.dx = ballSpeed
    elseif ball.x > width then
        playerScore = playerScore + 1
        ball.x, ball.y = width / 2, height / 2
        ball.dx = -ballSpeed
    end
end

-- Main game loop
function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    if math.random(0, 160) == 0 then
        aiStop = math.random(3, 30)
    end
    
    local click = display.getClick()
    if click and (click.state == "pressed" or click.state == "drag") then
        touchY = click.y
    end

    updatePaddles()
    updateBall()
    drawGame()
end