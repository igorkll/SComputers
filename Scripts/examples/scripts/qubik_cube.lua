-- MIT License
-- 
-- Copyright (c) 2024 Qubik
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- was made for 128x128 display


local display = getComponent("display")

local WIDTH, HEIGHT = display.getSize()
local HWIDTH, HHEIGHT = WIDTH / 2, HEIGHT / 2

local FOV = 120

local cube_vertices = {
	{ 1,  1,  1},  -- 1 (1, 1, 1)
	{ 1,  1, -1},  -- 2
	{ 1, -1,  1},  -- 3
	{ 1, -1, -1},  -- 4
	{-1,  1,  1},  -- 5
	{-1,  1, -1},  -- 6
	{-1, -1,  1},  -- 7
	{-1, -1, -1},  -- 8 (0, 0, 0)
}

-- indexes into 'cube_vertices'
local cube_polygons = {
	-- front
	{7, 3, 4},
	{7, 4, 8},
	-- back
	{1, 5, 6},
	{1, 6, 2},
	-- left
	{5, 7, 8},
	{5, 8, 6},
	-- right
	{3, 1, 2},
	{3, 2, 4},
	-- top
	{5, 1, 3},
	{5, 3, 7},
	-- bottom
	{8, 4, 2},
	{8, 2, 6}
}

function rotX(x, y, z, theta)
	return x, y * math.cos(theta) - z * math.sin(theta), z * math.cos(theta) + y * math.sin(theta)
end

function rotY(x, y, z, theta)
	return x * math.cos(theta) - z * math.sin(theta), y, z * math.cos(theta) + x * math.sin(theta)
end

function rotZ(x, y, z, theta)
	return x * math.cos(theta) - y * math.sin(theta), y * math.cos(theta) + x * math.sin(theta), z
end

function rotXYZ(x, y, z, rx, ry, rz)
	px, py, pz = rotX(x, y, z, rx)
	px, py, pz = rotY(px, py, pz, ry)
	px, py, pz = rotZ(px, py, pz, rz)
	return px, py, pz
end

function drawTri(x1, y1, x2, y2, x3, y3, color)
	display.drawPoly(color, x1, y1, x2, y2, x3, y3)
	
end

function project3d(x, y, z)
	return x * FOV / z + HWIDTH, y * FOV / z + HHEIGHT
end

function drawCube(x, y, z, sx, sy, sz, rx, ry, rz)
	local vertex_count = 12
	for i=1, vertex_count do
		x1, y1, z1 = unpack(cube_vertices[cube_polygons[i][1]])
		x2, y2, z2 = unpack(cube_vertices[cube_polygons[i][2]])
		x3, y3, z3 = unpack(cube_vertices[cube_polygons[i][3]])

		x1, y1, z1 = rotXYZ(x1 * sx, y1 * sy, z1 * sz, rx, ry, rz)
		x2, y2, z2 = rotXYZ(x2 * sx, y2 * sy, z2 * sz, rx, ry, rz)
		x3, y3, z3 = rotXYZ(x3 * sx, y3 * sy, z3 * sz, rx, ry, rz)

		px1, py1 = project3d(x1 + x, y1 + y, z1 + z)
		px2, py2 = project3d(x2 + x, y2 + y, z2 +z)
		px3, py3 = project3d(x3 + x, y3 + y, z3 +z)

		drawTri(px1, py1, px2, py2, px3, py3)
	end
end

local frame_count = 0

function onTick()
	display.clear()
	frame_count = frame_count + 0.05
	drawCube(
		0, 0, 30,
		3, 3, 3,
		frame_count, frame_count, frame_count)

	drawCube(
		3, 7, 30,
		3, 3, 1,
		frame_count / 2, frame_count, frame_count / 3)
	display.flush()
end

_enableCallbacks = true