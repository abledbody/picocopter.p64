--[[pod_format="raw",created="2024-06-09 05:13:18",modified="2024-06-26 06:25:44",revision=5238]]
local Transform = require"transform"
local Utils = require"utils"
local quat = require"quaternions"
local Rendering = require"rendering"
local log = math.log

local cam_pos = vec(0,2,3)
local cam_rot = vec(0,0,0,1)
local cam_offset = vec(0,2,3)
local pitch = -0.08
local yaw = 0
local follow_target

local e = 2.718281828459

local function get_pos()
	return cam_pos
end

local function get_rot()
	return cam_rot,pitch,yaw
end

local function get_vol(pos)
	return mid((1-log(pos:distance(cam_pos))/e),0,0.7)
end

local function update()
	if follow_target then
		local delta = follow_target.position-cam_pos
		
		local target_vel = vec(follow_target.velocity.x,0,follow_target.velocity.z)
		local offset = vec(0,0,0)
		if target_vel.x != 0 or target_vel.z != 0 then
			offset = (target_vel/target_vel:magnitude()*-9)
		end
		offset = vec(offset.x,3,offset.z)
		cam_offset = Utils.lerp(cam_offset,offset,1-1/(target_vel:magnitude()*0.001+1))
		cam_pos = follow_target.position+cam_offset
		yaw = atan2(follow_target.position.x-cam_pos.x,follow_target.position.z-cam_pos.z)-0.25
		pitch = Utils.lerp(pitch,1-1/(1+follow_target.velocity.y*0.01)-0.08,0.05)
		cam_rot = quat.mul(
			quat(vec(0,1,0),yaw),
			quat(vec(1,0,0),pitch)
		)
	end
	Rendering.view(cam_pos,cam_rot)
end

local function set_target(target)
	follow_target = target
end

return {
	get_pos = get_pos,
	get_rot = get_rot,
	update = update,
	set_target = set_target,
	get_vol = get_vol,
}