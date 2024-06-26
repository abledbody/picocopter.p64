--[[pod_format="raw",created="2024-06-09 04:49:34",modified="2024-06-26 06:25:44",revision=6203]]
local Rendering = require"rendering"
local Transform = require"transform"
local dtf = Transform.double_transform
local quat = require"quaternions"
local Physics = require"physics"
local Camera = require"camera"
local import_pcm = require"pcm_importer"
local materials = require"materials"

local r22 = import_pcm("mdl/r22.pcm",materials)
local r22_rotor = import_pcm("mdl/r22Rotor.pcm",materials)
local r22_tail_rotor = import_pcm("mdl/r22TailRotor.pcm",materials)
local shadow = import_pcm("mdl/Shadow.pcm",materials)

local rotor_pos_mat,rotor_pos_imat = dtf(Transform.translate,vec(0,1.1382,0.13131))
local tail_rotor_pos_mat,tail_rotor_pos_imat =
	dtf(Transform.translate,vec(-0.131973,0.6291,2.99883),quat.dtf(quat(vec(0,0,1),0.25)))
local rotor_rot = 0
local tail_rotor_rot = 0

local body = Physics.new_rigidbody(vec(0,0,0),375)
local throttle = 0.164
local floor_height = 0

Camera.set_target(body)

local function update()
	local up = quat.vmul(vec(0,1,0),body.rotation)
	local forward = quat.vmul(vec(0,0,-1),body.rotation)
	local right = quat.vmul(vec(1,0,0),body.rotation)
	body:accelerate(vec(0,-0.164,0))
	
	local input_vec = vec(
		(btn(11) or 0)/255-(btn(10) or 0)/255,
		(btn(0) or 0)/255-(btn(1) or 0)/255,
		(btn(8) or 0)/255-(btn(9) or 0)/255
	)
	input_vec *= vec(abs(input_vec.x),abs(input_vec.y),abs(input_vec.z))
	body.angular_velocity += input_vec*vec(0.0003,0.0002,0.0003)
	body.angular_velocity *= 0.93
	
	local slip = quat.vmul(body.velocity,quat.inv(body.rotation))
	local sqr_slip = vec(abs(slip.x),abs(slip.y),abs(slip.z))*slip
	body.angular_velocity.y -= sqr_slip.x*0.00001
	body.angular_velocity.x -= sqr_slip.z*0.000001
	body.angular_velocity.z += sqr_slip.x*0.000001
	
	local etl = mid((body.velocity:magnitude()-1)*0.02,0,0.2)+1
	
	throttle = 0.164+(btn(2) or 0)/255*0.02-(btn(3) or 0)/255*0.1
	body:force(up*(throttle*375*etl))
	body:force(body.velocity*body.velocity:magnitude()*-1)
	body:physics_step()
	
	rotor_rot += 0.111
	tail_rotor_rot += 0.154
	local vol = Camera.get_vol(body.position)*100
	note(0,5,vol,0,0,9,false)
	note(0,6,vol,0,0,10,false)
	
	floor_height = get_height(body.position.x,body.position.z)
	local center_from_floor = floor_height+0.5501

	if body.position.y <= center_from_floor then
		if body.velocity:magnitude() > 3 then
			body.position.y = -body.position.y+center_from_floor*2
			body.velocity.y += abs(body.velocity.y)*1.8
			note(68+rnd(3),8,vol,0,0,8,true)
		else
			body.position.y = center_from_floor
			body.velocity = vec(0,0,0)
			body.rotation = quat.twist(body.rotation,vec(0,1,0))
		end
	end
end

local function draw_shadow()
	local mat,imat = dtf(Transform.translate,vec(body.position.x,floor_height,body.position.z))
	Rendering.model(shadow,mat,imat)
end

local function draw()
	draw_shadow()
	local model_mat,model_imat = body:transform_mat()
	local rotor_mat,rotor_imat =
		quat.dtf(quat(vec(0,1,0),rotor_rot))
	local tail_rotor_mat,tail_rotor_imat = quat.dtf(quat(vec(0,1,0),tail_rotor_rot))
	
	rotor_mat,rotor_imat =
		rotor_mat:matmul3d(rotor_pos_mat):matmul3d(model_mat),
		model_imat:matmul3d(rotor_pos_imat):matmul3d(rotor_imat)
	
	tail_rotor_mat,tail_rotor_imat =
		tail_rotor_mat:matmul3d(tail_rotor_pos_mat):matmul3d(model_mat),
		model_imat:matmul3d(tail_rotor_pos_imat):matmul3d(tail_rotor_imat)
	
	local cam_pos = Camera.get_pos()
	
	Rendering.model(r22,model_mat,model_imat)
	Rendering.model(r22_rotor,rotor_mat,rotor_imat)
	Rendering.model(r22_tail_rotor,tail_rotor_mat,tail_rotor_imat)
	
	Rendering.line(vec(-0.2387,-0.201,-0.4353,1),vec(-0.35,-0.5501,-0.4353,1),32,model_mat)
	Rendering.line(vec(0.2387,-0.201,-0.4353,1),vec(0.35,-0.5501,-0.4353,1),32,model_mat)
	Rendering.line(vec(-0.2,0,0.479621,1),vec(-0.35,-0.5501,0.479621,1),32,model_mat)
	Rendering.line(vec(0.2,0,0.479621,1),vec(0.35,-0.5501,0.479621,1),32,model_mat)
	Rendering.line(vec(-0.35,-0.5501,-0.7,1),vec(-0.35,-0.5501,0.6,1),32,model_mat)
	Rendering.line(vec(0.35,-0.5501,-0.7,1),vec(0.35,-0.5501,0.6,1),32,model_mat)
	Rendering.line(vec(-0.35,-0.5501,-0.7,1),vec(-0.35,-0.45,-0.95,1),32,model_mat)
	Rendering.line(vec(0.35,-0.5501,-0.7,1),vec(0.35,-0.45,-0.95,1),32,model_mat)
end

local function get_body()
	return body
end

return {
	draw = draw,
	draw_shadow = draw_shadow,
	update = update,
	get_body = get_body,
}