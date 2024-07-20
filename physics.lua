--[[pod_format="raw",created="2024-05-22 17:30:22",modified="2024-07-19 23:16:27",revision=11096]]
local Transform = require"transform"
local dtf = Transform.double_transform
local quat = require"quaternions"

local dt = 1/60
local half_dt = dt/2

local function step(body)
	local accel,vel,pos,ang_vel =
		body.acceleration,body.velocity,body.position,body.angular_velocity,body.torque
	add(force_display,{pos,accel*body.mass,11})
	body.position += (vel+accel*half_dt)*dt
	body.velocity += accel
	body.acceleration = vec(0,0,0)
	
	body.rotation = 
		quat.norm(
		quat.mul(body.rotation,
		quat.mul(quat(vec(0,0,1),ang_vel.z),
		quat.mul(quat(vec(1,0,0),ang_vel.x),
		quat(vec(0,1,0),ang_vel.y)))))
end

local function accelerate(body,acceleration)
	add(force_display,{body.position,acceleration*body.mass,11})
	body.acceleration += acceleration
end

local function add_force(body,force,suppress_display)
	if not suppress_display then add(force_display,{body.position,force,8}) end
	body.acceleration += force/body.mass
end

local function add_impulse(body,force)
	add(force_display,{body.position,force,8})
	body.velocity += force/body.mass
end

local function add_torque(body,torque)
	add(force_display,{body.position,quat.vmul(torque,body.rotation),28})
	body.angular_velocity += torque*dt/body.angular_inertia
end

local function add_force_at_point(body,force,point)
	add_force(body,force,true)
	add(force_display,{body.position+point,force,8})
	local torque = quat.vmul(point:cross(force),quat.inv(body.rotation))
	add_torque(body,torque)
end

local function transform_mat(body)
	return dtf(Transform.translate,body.position,
		quat.dtf(body.rotation))
end

local m_rigidbody = {
	physics_step = step,
	accelerate = accelerate,
	force = add_force,
	impulse = add_impulse,
	transform_mat = transform_mat,
	torque = add_torque,
	force_at_point = add_force_at_point,
}
m_rigidbody.__index = m_rigidbody

local function new_rigidbody(position,mass,angular_inertia)
	local body = {
		position = position,
		rotation = vec(0,0,0,1),
		velocity = vec(0,0,0),
		angular_velocity = vec(0,0,0),
		acceleration = vec(0,0,0),
		mass = mass,
		angular_inertia = angular_inertia
	}
	
	return setmetatable(body,m_rigidbody)
end

return {
	new_rigidbody = new_rigidbody
}