--[[pod_format="raw",created="2024-06-09 05:34:23",modified="2024-06-09 05:40:14",revision=4]]
local Camera = require"camera"
local cam_pos = Camera.get_pos

local e = 2.718281828459

local function get_vol(pos)
	return (e-log(cam_pos():distance(pos)+1))/e
end