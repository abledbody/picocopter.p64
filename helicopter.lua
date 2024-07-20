--[[pod_format="raw",created="2024-06-09 04:49:34",modified="2024-07-19 23:16:27",revision=8575]]
local Rendering = require"rendering"
local Transform = require"transform"
local dtf = Transform.double_transform
local quat = require"quaternions"
local Physics = require"physics"
local Camera = require"camera"
local import_ptm = require"ptm_importer"
local materials = require"materials"

local r22 = import_ptm("mdl/r22.ptm",materials)
local r22_rotor = import_ptm("mdl/r22Rotor.ptm",materials)
local r22_tail_rotor = import_ptm("mdl/r22TailRotor.ptm",materials)
local shadow = import_ptm("mdl/Shadow.ptm",materials)

local body = Physics.new_rigidbody(vec(0,0,0),375,1000)
local floor_height = 0
local min_collect,max_collect = 2,14

local rotor_pos = vec(0,1.7016,0.1963)
local rotor_pos_mat,rotor_pos_imat = dtf(Transform.translate,rotor_pos)
local tail_rotor_pos = vec(-0.1973,0.9405,4.4833)
local tail_rotor_pos_mat,tail_rotor_pos_imat =
	dtf(Transform.translate,tail_rotor_pos,quat.dtf(quat(vec(0,0,1),0.25)))
local rotor_rot = 0
local tail_rotor_rot = 0

local shadow_scale_mat,shadow_scale_imat = dtf(Transform.scale,vec(1.5,1.5,1.5))

Camera.set_target(body)

local function update()
	local up = quat.vmul(vec(0,1,0),body.rotation)
	local forward = quat.vmul(vec(0,0,-1),body.rotation)
	local right = quat.vmul(vec(1,0,0),body.rotation)
	body:accelerate(vec(0,-9.8/60,0))
	
	local input_vec = vec(
		(btn(11) or 0)/255-(btn(10) or 0)/255,
		(btn(0) or 0)/255-(btn(1) or 0)/255,
		(btn(8) or 0)/255-(btn(9) or 0)/255,
		(btn(2) or 0)/255-(btn(3) or 0)/255
	)
	body:torque(vec(0,-50,0))
	local tail_rotor_force = quat.vmul(vec(input_vec.y*3+11,0,0),body.rotation)
	local tail_rotor_point = quat.vmul(vec(-0.197,0.939,4.488),body.rotation)
	body:force_at_point(tail_rotor_force,tail_rotor_point)
	input_vec *= vec(abs(input_vec.x),abs(input_vec.y),abs(input_vec.z))
	body.angular_velocity += input_vec*vec(0.05,0,0.05)/60
	body.angular_velocity *= vec(0.8,0.94,0.8)
	
	local slip = quat.vmul(body.velocity,quat.inv(body.rotation))
	local sqr_slip = vec(abs(slip.x),abs(slip.y),abs(slip.z))*slip
	body.angular_velocity +=
		vec(-sqr_slip.z*0.00004,-sqr_slip.x*0.0004,sqr_slip.x*0.00004)/60
	
	local etl = mid((body.velocity:magnitude()-1)*0.03,0,0.3)+1
	
	local throttle = (input_vec[3] < 0
		and (min_collect-9.8)*-input_vec[3]+9.8
		or (max_collect-9.8)*input_vec[3]+9.8)
		/60
	local rotor_dir = vec(-1,10,1.2)
	rotor_dir /= rotor_dir:magnitude()
	rotor_dir = quat.vmul(rotor_dir,body.rotation)
	local rotor_force = rotor_dir*(throttle*375*etl)
	local rotor_point = quat.vmul(rotor_pos,body.rotation)
	body:force_at_point(rotor_force,rotor_point)
	body:force(body.velocity*-body.velocity:magnitude()*0.5)
	body:physics_step()
	
	rotor_rot += 0.111
	tail_rotor_rot += 0.154
	local vol = Camera.get_vol(body.position)*100
	note(0,5,vol,0,0,9,false)
	note(0,6,vol,0,0,10,false)
	
	floor_height = get_height(body.position.x,body.position.z)
	local center_from_floor = floor_height+0.9

	if body.position.y <= center_from_floor then
		if body.velocity:magnitude() > 5 then
			body.position.y = -body.position.y+center_from_floor*2
			body.velocity.y += abs(body.velocity.y)*1.8
			note(68+rnd(3),8,vol,0,0,8,true)
		else
			body.position.y = center_from_floor
			body.velocity = vec(0,0,0)
			body.rotation = quat.twist(body.rotation,vec(0,1,0))
			body.angular_velocity = vec(0,0,0)
		end
	end
end

local function draw_shadow()
	local mat,imat = dtf(
		Transform.translate,
		vec(body.position.x,floor_height,body.position.z)
	)
	mat = shadow_scale_mat:matmul(mat)
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
	
	Rendering.line(vec(-0.3569,-0.3005,-0.6508,1),vec(-0.5233,-0.8224,-0.6508,1),32,model_mat)
	Rendering.line(vec( 0.3569,-0.3005,-0.6508,1),vec( 0.5233,-0.8224,-0.6508,1),32,model_mat)
	Rendering.line(vec(-0.299,       0,  0.717,1),vec(-0.5233,-0.8224,  0.717,1),32,model_mat)
	Rendering.line(vec( 0.299,       0,  0.717,1),vec( 0.5233,-0.8224,  0.717,1),32,model_mat)
	Rendering.line(vec(-0.5233,-0.8224,-1.0465,1),vec(-0.5233,-0.8224,  0.897,1),32,model_mat)
	Rendering.line(vec( 0.5233,-0.8224,-1.0465,1),vec( 0.5233,-0.8224,  0.897,1),32,model_mat)
	Rendering.line(vec(-0.5233,-0.8224,-1.0465,1),vec(-0.5233,-0.6728,-1.4203,1),32,model_mat)
	Rendering.line(vec( 0.5233,-0.8224,-1.0465,1),vec( 0.5233,-0.6728,-1.4203,1),32,model_mat)
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