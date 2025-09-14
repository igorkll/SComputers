local wasd = getComponent("wasd")
local inertialEngine = getComponent("inertialEngine")

inertialEngine.setActive(true)
inertialEngine.setStableMode(1)

local speed = 1
local rotateSpeed = math.rad(5)

--------------------------

local function up()
    inertialEngine.addPosition(sm.vec3.new(0, 0, speed))
end

local function down()
    inertialEngine.addPosition(sm.vec3.new(0, 0, -speed))
end

local function forward()
    inertialEngine.addPosition(sm.vec3.new(speed, 0, 0))
end

local function back()
    inertialEngine.addPosition(sm.vec3.new(-speed, 0, 0))
end

local function left()
    inertialEngine.addPosition(sm.vec3.new(0, speed, 0))
end

local function right()
    inertialEngine.addPosition(sm.vec3.new(0, -speed, 0))
end

--------------------------

local function _up()
    inertialEngine.addRotation(sm.vec3.new(0, -rotateSpeed, 0))
end

local function _down()
    inertialEngine.addRotation(sm.vec3.new(0, rotateSpeed, 0))
end

local function _left()
    inertialEngine.addRotation(sm.vec3.new(0, 0, rotateSpeed))
end

local function _right()
    inertialEngine.addRotation(sm.vec3.new(0, 0, -rotateSpeed))
end

--------------------------

function callback_loop()
    if _endtick then
        inertialEngine.setActive(false)
        return
    end

    if wasd.isSeated() then
        forward()
    end

    if wasd.isW() then
        _up()
    elseif wasd.isS() then
        _down()
    end

    if wasd.isA() then
        _left()
    elseif wasd.isD() then
        _right()
    end
end