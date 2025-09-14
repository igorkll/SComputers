local timerhost = require("timer").createHost()
local utils = require("utils")
local holo = getComponent("holoprojector")

local shrapnels = {}
local fireworks = {}
local fireworksLimit = 50
local fireworkNumber = 0
local white = sm.color.new(1, 1, 1)

local rainbox_colors

local palettes = {
    {0xff3030, 0xff3083},
    {0x30dfff, 0x30a1ff, 0x305dff},
    {0x30ff8a, 0x8dff30, 0x30ffa9},
    {0xfffe30, 0xffdf30, 0xdeff30},
    {0xc130ff, 0x8f30ff, 0xff30be}
}

local function random(min, max)
    local val = math.random(min, max)
    if math.random(0, 1) == 0 then
        return -val
    end
    return val
end

local function floatRandom(min, max)
    return utils.map(math.random(), 0, 1, min, max)
end

---------------------------------------- shrapnel class

local shrapnelClass = class()

function shrapnelClass:init(pos, mode, color, minSpeed, maxSpeed, scale)
    self.pos = pos
    self.color = sm.color.new((color * 256) + 255)
    self.scale = scale

    if type(mode) == "Vec3" then
        self.waitTimer = 0
        self.baseTimer = 40
        self.vec = mode
    else
        if mode == 0 then
            self.waitTimer = 40 * floatRandom(0, 0.5)
            self.baseTimer = 40 * floatRandom(0.5, 1)
            local speed = floatRandom(minSpeed, maxSpeed)
            local angle = math.rad(math.random(0, 359))
            self.vec = sm.vec3.new(math.sin(angle), math.cos(angle), math.sin(math.rad(math.random(0, 359)))):normalize() * speed
        elseif mode == 1 then
            self.waitTimer = 0
            self.baseTimer = 40
            local angle = math.rad(math.random(0, 359))
            self.vec = sm.vec3.new(math.sin(angle), math.cos(angle), 0):normalize() * minSpeed
        elseif mode == 2 then
            self.waitTimer = 0
            self.baseTimer = 40
            local speed = floatRandom(minSpeed, maxSpeed)
            local angle = math.rad(math.random(0, 359))
            self.vec = sm.vec3.new(math.sin(angle), math.cos(angle), math.sin(math.rad(math.random(0, 359)))):normalize() * speed
        elseif mode == 3 then
            self.waitTimer = 0
            self.baseTimer = 40
            self.vec = sm.vec3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, (math.random() - 0.5) * 2):normalize() * minSpeed
        elseif mode == 4 then
            self.waitTimer = 0
            self.baseTimer = 40
            self.vec = sm.vec3.new((math.random(0, 1) - 0.5) * 2, (math.random(0, 1) - 0.5) * 2, (math.random(0, 1) - 0.5) * 2):normalize() * minSpeed
            local lockSide = math.random(0, 2)
            local lockRandom = (math.random() - 0.5) * 1.3
            if lockSide == 0 then
                self.vec.x = lockRandom
            elseif lockSide == 1 then
                self.vec.y = lockRandom
            elseif lockSide == 2 then
                self.vec.z = lockRandom
            end
        end
    end

    self.timer = self.baseTimer
end

function shrapnelClass:tick()
    self.waitTimer = self.waitTimer - 1
    if self.waitTimer <= 0 then
        self.pos = self.pos + self.vec
    end
    
    self.timer = self.timer - 1
    if self.timer <= 0 then
        return true
    end
end

function shrapnelClass:draw()
    local color
    local mulVal = self.timer / self.baseTimer
    if mulVal < 0.3 and math.random(0, 100) == 0 then
        color = white
    else
        color = self.color * mulVal
    end
    holo.addVoxel(self.pos.x, self.pos.z, self.pos.y, color, 1, self.scale)
end

---------------------------------------- firework class

local fireworkClass = class()

function fireworkClass:init(mode)
    self.pos = sm.vec3.new(0, 0, 0)
    self.mode = mode

    if mode < 0 then
        self.timer = 120
        self.vec = sm.vec3.new(0, 0, 3)
        self.color = white
    else
        self.timer = 40 * floatRandom(2, 3)
        self.vec = sm.vec3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, (math.random() + 0.4) * 5)
        self.pal = math.random(1, #palettes)
        self.color = palettes[self.pal][1]    
    end
end

function fireworkClass:tick()
    self.pos = self.pos + self.vec
    self.timer = self.timer - 1
    if self.timer <= 0 then
        if self.mode == -1 then
            local scale = sm.vec3.new(4, 16, 4)
            local lifeTime = 40 * 10
            for index, color in ipairs(rainbox_colors) do
                local pos = self.pos + sm.vec3.new(0, 0, -index * 16)
                for i = -25, 25 do
                    local shrapnel = shrapnelClass()
                    shrapnel:init(pos, sm.vec3.new(i / 50, 0, 0), color, 1, nil, scale)
                    shrapnel.baseTimer = lifeTime
                    shrapnel.timer = lifeTime
                    table.insert(shrapnels, shrapnel)
                end
                for i = -25, 25 do
                    local shrapnel = shrapnelClass()
                    shrapnel:init(pos, sm.vec3.new(0, i / 50, 0), color, 1, nil, scale)
                    shrapnel.baseTimer = lifeTime
                    shrapnel.timer = lifeTime
                    table.insert(shrapnels, shrapnel)
                end
            end
        else
            local pal = palettes[self.pal]
            for i = 1, 500 do
                local shrapnel = shrapnelClass()
                shrapnel:init(self.pos, self.mode, pal[math.random(1, #pal)], 1, 2)
                table.insert(shrapnels, shrapnel)
            end
        end
        return true
    end
end

function fireworkClass:draw()
    holo.addVoxel(self.pos.x, self.pos.z, self.pos.y, self.color, 1)
end

----------------------------------------

timerhost:createTimer(40, true, function (timer)
    local firework = fireworkClass()
    firework:init(math.floor(fireworkNumber / 10))
    table.insert(fireworks, firework)
    fireworksLimit = fireworksLimit - 1
    fireworkNumber = fireworkNumber + 1
    if fireworksLimit <= 0 then
        if rainbox_colors then
            local t = timerhost:createTimer(80, false, function (timer)
                local firework = fireworkClass()
                firework:init(-1)
                table.insert(fireworks, firework)
            end)
            t:setEnabled(true)
            t:reset()
        end
        timer:delete()
    end
end):setEnabled(true)

function onStart()
    holo.reset()
end

function onTick(dt)
    timerhost:tick()
    holo.clear()
    for id, firework in pairs(fireworks) do
        if firework:tick() then
            fireworks[id] = nil
        end
        firework:draw()
    end
    for id, shrapnel in pairs(shrapnels) do
        if shrapnel:tick() then
            shrapnels[id] = nil
        end
        shrapnel:draw()
    end
    holo.flush()
end

function onStop()
    holo.reset()
    holo.clear()
    holo.flush()
end

_enableCallbacks = true