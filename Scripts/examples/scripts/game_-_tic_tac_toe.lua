--designed to work with a 128x128 display
local graphic = require("graphic")
local fonts = require("fonts")

local display = getComponent("display")
local width, height = display.getSize()

display.reset()
display.setClicksAllowed(true)
display.setFont(fonts.lgc_5x5)

-- Game variables
local board = {
    {"", "", ""},
    {"", "", ""},
    {"", "", ""}
}
local currentPlayer = "X"
local cellSize = math.min(width, height) / 3
local xPadding = math.ceil(cellSize / 8)
local gameOver = false

-- Draw the game board
function drawBoard()
    display.clear(0x000000)
    
    -- Draw grid lines
    for i = 1, 2 do
        local pos = i * cellSize
        display.drawLine(pos, 0, pos, height, 0xFFFFFF)
        display.drawLine(0, pos, width, pos, 0xFFFFFF)
    end
    
    -- Draw marks (X and O)
    for y = 1, 3 do
        for x = 1, 3 do
            local mark = board[y][x]
            if mark == "X" then
                drawX((x - 1) * cellSize, (y - 1) * cellSize)
            elseif mark == "O" then
                drawO((x - 1) * cellSize, (y - 1) * cellSize)
            end
        end
    end

    display.flush()
end

-- Draw an "X" in a cell
function drawX(x, y)
    display.drawLine(x + xPadding, y + xPadding, x + cellSize - xPadding, y + cellSize - xPadding, 0xFF0000)
    display.drawLine(x + xPadding, y + cellSize - xPadding, x + cellSize - xPadding, y + xPadding, 0xFF0000)
end

-- Draw an "O" in a cell
function drawO(x, y)
    display.drawCircle(x + cellSize / 2, y + cellSize / 2, cellSize / 3, 0x00FF00)
end

-- Check for a win
function checkWin()
    for i = 1, 3 do
        -- Check rows and columns
        if board[i][1] ~= "" and board[i][1] == board[i][2] and board[i][2] == board[i][3] then return board[i][1] end
        if board[1][i] ~= "" and board[1][i] == board[2][i] and board[2][i] == board[3][i] then return board[1][i] end
    end
    -- Check diagonals
    if board[1][1] ~= "" and board[1][1] == board[2][2] and board[2][2] == board[3][3] then return board[1][1] end
    if board[1][3] ~= "" and board[1][3] == board[2][2] and board[2][2] == board[3][1] then return board[1][3] end

    local findedSpace = false
    for ix = 1, 3 do
        for iy = 1, 3 do
            if board[ix][iy] == "" then
                findedSpace = true
            end
        end
        if findedSpace then
            break
        end
    end

    if not findedSpace then
        return "GAME OVER", true
    end
end

-- Handle player input
function handleClick(x, y)
    if gameOver then
        reboot()
        return
    end
    
    local cellX = math.floor(x / cellSize) + 1
    local cellY = math.floor(y / cellSize) + 1
    
    if board[cellY][cellX] == "" then
        board[cellY][cellX] = currentPlayer
        local winner, rawMsg = checkWin()
        if winner then
            gameOver = true
            display.clear()
            graphic.textBox(display, 0, 0, display.getWidth(), display.getHeight(), rawMsg and winner or winner .. " WINS!", 0xFFFF00, true, true)
            display.flush()
        else
            currentPlayer = (currentPlayer == "X") and "O" or "X"
            drawBoard()
        end
    end
end

drawBoard()

-- Main game loop
function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end
    
    local click = display.getClick()
    if click and click.state == "pressed" then
        handleClick(click.x, click.y)
    end
end