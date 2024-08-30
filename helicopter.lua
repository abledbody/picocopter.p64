--[[pod_format="raw",created="2024-06-09 04:49:34",modified="2024-08-28 23:16:33",revision=8617]]
local Rendering = require"blade3d.rendering"
local Transform = require"blade3d.transform"
local dtrans,dscale =
	Transform.double_translate,Transform.double_scale
local quat = require"blade3d.quaternions"
local Physics = require"physics"
local Camera = require"camera"
local import_ptm = require"ptm_importer"
local materials = require"materials"

local r22 = import_ptm("mdl/r22.ptm",materials)
local r22_rotor = import_ptm("mdl/r22Rotor.ptm",materials)
local r22_tail_rotor = import_ptm("mdl/r22TailRotor.ptm",materials)
local shadow = import_ptm("mdl/Shadow.ptm",materials)

local mass = 375
local body = Physics.new_rigidbody(vec(0,0,0),mass,200)
local floor_height = 0
local min_collect,max_collect = 2,14

local rotor_pos = vec(0,1.7016,0.1963)
local rotor_pos_mat,rotor_pos_imat = dtrans(rotor_pos)
local tail_rotor_pos = vec(-0.1973,0.9405,4.4833)
local tail_rotor_pos_mat,tail_rotor_pos_imat =
	dtrans(tail_rotor_pos,quat.dtf(quat(vec(0,0,1),0.25)))
local rotor_rot = 0
local tail_rotor_rot = 0

local shadow_scale_mat,shadow_scale_imat = dscale(vec(1.5,1.5,1.5))

Camera.set_target(body)

local function update()
	local rotation = body.rotation
	
	--Input
	local input_vec = vec(
		(btn(11) or 0)/255-(btn(10) or 0)/255,
		(btn(0) or 0)/255-(btn(1) or 0)/255,
		(btn(8) or 0)/255-(btn(9) or 0)/255,
		(btn(2) or 0)/255-(btn(3) or 0)/255
	)
	input_vec *= vec(abs(input_vec.x),abs(input_vec.y),abs(input_vec.z))
	
	-- Gravity
	body:accelerate(vec(0,-9.8,0))
	
	-- Thrust
	local up = quat.vmul(vec(0,1,0),rotation)
	local speed = body.velocity:magnitude()
	local throttle = (input_vec[3] < 0
		and (min_collect-9.8)*-input_vec[3]+9.8
		or (max_collect-9.8)*input_vec[3]+9.8)
	local etl = mid((speed-1)*0.03,0,0.3)+1
	body:force(up*throttle*mass*etl)
	
	-- Torque
	body:torque(input_vec*vec(100,60,100))
	
	-- Angular drag
	local a_drag = body.angular_velocity*body.angular_velocity:magnitude()*-2000
	body:torque(a_drag)
	
	-- Drag
	local drag = body.velocity*speed*-30
	body:force(drag)
	
	-- Tail drag
	local left = quat.vmul(vec(-1,0,0),rotation)
	local tail_drag = quat.vmul(body:velocity_at_point(tail_rotor_pos),quat.inv(rotation)).x
	tail_drag *= abs(tail_drag)*0.2
	body:force_at_point(left*tail_drag,quat.vmul(tail_rotor_pos,rotation))
	
	-- Precession
	local slip = quat.vmul(body.velocity,quat.inv(rotation))
	local sqr_slip = vec(abs(slip.x),abs(slip.y),abs(slip.z))*slip
	body:torque(vec(-sqr_slip.z,0,sqr_slip.x)*0.3)
	
	body:physics_step()
	
	-- Animation
	rotor_rot += 0.1166666666666
	tail_rotor_rot += 0.9166666
	
	-- Sound
	local vol = Camera.get_vol(body.position)*100
	note(0,5,vol,0,0,9,false)
	note(0,6,vol,0,0,10,false)
	
	-- Collision
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
	local mat,imat = dtrans(
		vec(body.position.x,floor_height,body.position.z)
	)
	mat = shadow_scale_mat:matmul(mat)
	Rendering.queue_model(shadow,mat,imat)
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
	
	Rendering.queue_model(r22,model_mat,model_imat)
	Rendering.queue_model(r22_rotor,rotor_mat,rotor_imat)
	Rendering.queue_model(r22_tail_rotor,tail_rotor_mat,tail_rotor_imat)
	
	Rendering.queue_line(vec(-0.3569,-0.3005,-0.6508,1),vec(-0.5233,-0.8224,-0.6508,1),32,model_mat)
	Rendering.queue_line(vec( 0.3569,-0.3005,-0.6508,1),vec( 0.5233,-0.8224,-0.6508,1),32,model_mat)
	Rendering.queue_line(vec(-0.299,       0,  0.717,1),vec(-0.5233,-0.8224,  0.717,1),32,model_mat)
	Rendering.queue_line(vec( 0.299,       0,  0.717,1),vec( 0.5233,-0.8224,  0.717,1),32,model_mat)
	Rendering.queue_line(vec(-0.5233,-0.8224,-1.0465,1),vec(-0.5233,-0.8224,  0.897,1),32,model_mat)
	Rendering.queue_line(vec( 0.5233,-0.8224,-1.0465,1),vec( 0.5233,-0.8224,  0.897,1),32,model_mat)
	Rendering.queue_line(vec(-0.5233,-0.8224,-1.0465,1),vec(-0.5233,-0.6728,-1.4203,1),32,model_mat)
	Rendering.queue_line(vec( 0.5233,-0.8224,-1.0465,1),vec( 0.5233,-0.6728,-1.4203,1),32,model_mat)
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