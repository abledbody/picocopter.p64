--[[pod_format="raw",created="2024-06-09 05:13:18",modified="2024-07-19 23:16:27",revision=7343]]
local B3dUtils = require"blade3d.utils"
local B3dCamera = require"blade3d.camera"
local Rendering = require"blade3d.rendering"
local quat = require"blade3d.quaternions"
local log = math.log

window()
local render_cam = B3dCamera.new(0.5,196,B3dCamera.get_fov_slope(110),get_display())
Rendering.set_camera(render_cam)

local DRAW_DIST = 4
local cam_pos = vec(0,2,3)
local cam_rot = vec(0,0,0,1)
local cam_offset = vec(0,3,6)
local pitch = -0.08
local yaw = 0
local follow_target

local e = 2.718281828459

local function get_pos()
	return render_cam.position
end

local function get_rot()
	return render_cam.rotation,pitch,yaw
end

local function get_vol(pos)
	return mid((1-log(pos:distance(cam_pos)*0.5)/e),0,0.7)
end

local function update()
	if follow_target then
		local target_vel = vec(follow_target.velocity.x,0,follow_target.velocity.z)
		local offset = vec(0,0,0)
		if target_vel.x != 0 or target_vel.z != 0 then
			offset = (target_vel/target_vel:magnitude()*-14)
		end
		offset = vec(offset.x,5,offset.z)
		cam_offset = B3dUtils.lerp(cam_offset,offset,1-1/(target_vel:magnitude()*0.0015+1))
		cam_pos = follow_target.position+cam_offset
		yaw = atan2(follow_target.position.x-cam_pos.x,follow_target.position.z-cam_pos.z)-0.25
		pitch = B3dUtils.lerp(pitch,1-1/(1+follow_target.velocity.y*0.01)-0.08,0.05)
		cam_rot = quat.mul(
			quat(vec(0,1,0),yaw),
			quat(vec(1,0,0),pitch)
		)
	end
	render_cam:set_transform(cam_pos,cam_rot)
end

local function set_target(target)
	follow_target = target
end

return {
	DRAW_DIST = DRAW_DIST,
	get_pos = get_pos,
	get_rot = get_rot,
	update = update,
	set_target = set_target,
	get_vol = get_vol,
}