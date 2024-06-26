--[[pod_format="raw",created="2024-05-22 17:30:22",modified="2024-06-26 06:25:44",revision=8955]]
local Transform = require"transform"
local dtf = Transform.double_transform
local quat = require"quaternions"

local Physics = {}

local dt = 1/60
local half_dt = dt/2

function Physics.step(body)
	local accel,vel,pos,ang_vel =
		body.acceleration,body.velocity,body.position,body.angular_velocity
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

function Physics.accelerate(body,acceleration)
	body.acceleration += acceleration
end

function Physics.force(body,force)
	body.acceleration += force/body.mass
end

function Physics.impulse(body,force)
	body.velocity += force/body.mass
end

local function transform_mat(body)
	return dtf(Transform.translate,body.position,
		quat.dtf(body.rotation))
end

local m_rigidbody = {
	physics_step = Physics.step,
	accelerate = Physics.accelerate,
	force = Physics.force,
	impulse = Physics.impulse,
	transform_mat = transform_mat,
}
m_rigidbody.__index = m_rigidbody

function Physics.new_rigidbody(position,mass)
	local body = {
		position = position,
		rotation = vec(0,0,0,1),
		velocity = vec(0,0,0),
		angular_velocity = vec(0,0,0),
		acceleration = vec(0,0,0),
		mass = mass,
	}
	
	return setmetatable(body,m_rigidbody)
end

return Physics