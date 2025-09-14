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

-- fetch display
-- NOTE: this project was made using 128x128 display,
-- and other resolutions for now will not be scaled
local display = getComponent("display")
local utils = require("utils")
display.setOptimizationLevel(0)

-- fetch display resolution
local WIDTH, HEIGHT = display.getSize()
local HWIDTH, HHEIGHT = WIDTH / 2, HEIGHT / 2

-- variables
local cam = sm.vec3.new(0, 0, 0)  -- camera position
local camr = sm.vec3.new(0, 0, 0)  -- camera rotation

-- constants
local FOV = 120
local DRAW_THRESHOLD = 0.01

-- object vertices
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

-- poly_queue
local poly_queue = {}
local poly_queue_ptr = 0

-- simple perspective projection
function project3d(pos)
	return pos.x * FOV / pos.z + HWIDTH, pos.y * FOV / pos.z + HHEIGHT
end

-- call to draw polygons
function draw_call()
	-- apply camera transformations to all polygons
	for i, poly in ipairs(poly_queue) do
		-- rotate & move vertices according to camera's position and rotation
		poly[1] = poly[1]:rotateX(camr.x):rotateY(camr.y):rotateZ(camr.z) + cam
		poly[2] = poly[2]:rotateX(camr.x):rotateY(camr.y):rotateZ(camr.z) + cam
		poly[3] = poly[3]:rotateX(camr.x):rotateY(camr.y):rotateZ(camr.z) + cam
	end

	-- sort polygons by distance to camera
	table.sort(
		poly_queue,
		function(a, b)
			local dist_a = (utils.dist(a[1], cam) + utils.dist(a[2], cam) + utils.dist(a[3], cam)) / 3
			local dist_b = (utils.dist(b[1], cam) + utils.dist(b[2], cam) + utils.dist(b[3], cam)) / 3
			return dist_a > dist_b
		end)

	-- render polygons
	for i, poly in ipairs(poly_queue) do
		-- project verticies from 3d to 2d
		local x1, y1 = project3d(poly[1])
		local x2, y2 = project3d(poly[2])
		local x3, y3 = project3d(poly[3])

		-- draw polygon
		draw_poly(
			x1, y1,  -- vertex 1
			x2, y2,  -- vertex 2
			x3, y3,  -- vertex 3
			poly[4]  -- polygon color
		)
	end
	poly_queue = {}
end

-- appends polygon to list
function append_poly(point1, point2, point3, color)
	table.insert(
		poly_queue,
			{
				point1,  -- vertex 1
				point2,  -- vertex 2
				point3,  -- vertex 3
				color  -- polygon color
			}
		)
end

-- draw triangle function
-- NOTE: uses naive / simplistic scanline filling algorithm
function draw_poly(x1, y1, x2, y2, x3, y3, color)
	-- sort vectors (y3 - biggest, y1 - smallest)
	-- selection sorting
	if y1 > y2 then  -- swap p1 with p2
		x1, y1, x2, y2 = x2, y2, x1, y1
	end
	if y2 > y3 then  -- swap p2 with p3
		x2, y2, x3, y3 = x3, y3, x2, y2
		if y1 > y2 then  -- swap p1 with p2
			x1, y1, x2, y2 = x2, y2, x1, y1
		end
	end

	-- 0 height triangle
	if y1 - y3 == 0 then return end

	-- slope for line p1 to p3
	local slope_middle = (x3 - x1) / (y3 - y1)

	-- scanline filling algorithm
	local xo1, xo2 = x1, x1  -- 'x offset 1' and 'x offset 2'
	if y2 - y1 > DRAW_THRESHOLD then  -- draw top-flat triangle
		-- slope for line p1 to p2
		local slope_top = (x2 - x1) / (y2 - y1)
		for yo = y1, y2 do
			display.drawLine(xo1, yo, xo2, yo, color)
			xo1 = xo1 + slope_top
			xo2 = xo2 + slope_middle
		end
	end

	-- set both offsets to be at exact points
	xo1 = x2
	xo2 = slope_middle * (y2 - y1) + x1

	if y3 - y2 > DRAW_THRESHOLD then  -- draw bottom-flat triangle
		-- slope for line p2 to p3
		local slope_bottom = (x3 - x2) / (y3 - y2)
		for yo = y2, y3 do
			display.drawLine(xo1, yo, xo2, yo, color)
			xo1 = xo1 + slope_bottom
			xo2 = xo2 + slope_middle
		end
	end
end

-- object drawing function (for now just cube)
function draw_cube(pos, size, rot)
	local vertex_count = 12
	for i=1, vertex_count do
		-- fetch vertices
		local point1 = sm.vec3.new(unpack(cube_vertices[cube_polygons[i][1]])) * size
		local point2 = sm.vec3.new(unpack(cube_vertices[cube_polygons[i][2]])) * size
		local point3 = sm.vec3.new(unpack(cube_vertices[cube_polygons[i][3]])) * size

		-- rotate vertices
		point1 = point1:rotateX(rot.x):rotateY(rot.y):rotateZ(rot.z)
		point2 = point2:rotateX(rot.x):rotateY(rot.y):rotateZ(rot.z)
		point3 = point3:rotateX(rot.x):rotateY(rot.y):rotateZ(rot.z)

		-- append polygon
		append_poly(point1 + pos, point2 + pos, point3 + pos, i / vertex_count * 255)
	end
end

-- main loop
local frame_count = 330
function onTick()
	display.clear()
	frame_count = frame_count + 1
	draw_cube(
		sm.vec3.new(0, 0, 30),
		sm.vec3.new(3, 3, 3),
		sm.vec3.new(frame_count / 80, frame_count / 80, frame_count / 80))
	draw_call()
	display.flush()
end

_enableCallbacks = true