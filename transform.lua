--[[pod_format="raw",created="2024-05-23 00:40:43",modified="2024-06-14 22:18:11",revision=6156]]
local Utils = require"utils"

local function double_transform(func,data,forward,inverse)
	local mat = func(data)
	local imat = func(data*-1)
	if forward then
		return forward:matmul3d(mat),imat:matmul3d(inverse)
	end
	return mat,imat
end

local function translate(pos)
	local mat = userdata("f64",4,4)
	mat:set(0,0,
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		pos.x,pos.y,pos.z,1
	)
	return mat
end

local function rot_x(a)
	local mat = userdata("f64",4,4)
	mat:set(0,0,
		1,     0,      0,0,
		0,cos(a),-sin(a),0,
		0,sin(a), cos(a),0,
		0,     0,      0,1
	)
	return mat
end

local function rot_y(a)
	local mat = userdata("f64",4,4)
	mat:set(0,0,
		 cos(a),0, sin(a),0,
		      0,1,      0,0,
		-sin(a),0, cos(a),0,
		      0,0,      0,1
	)
	return mat
end

local function rot_z(a)
	local mat = userdata("f64",4,4)
	mat:set(0,0,
		 cos(a),-sin(a),0,0,
		 sin(a), cos(a),0,0,
		      0,      0,1,0,
		      0,      0,0,1
	)
	return mat
end

local function rotate(rot)
	local x,y,z = rot.x,rot.y,rot.z
	local x_mat = rot_x(x)
	local y_mat = rot_y(y)
	local z_mat = rot_z(z)
	return z_mat:matmul3d(x_mat):matmul3d(y_mat)
end

local function scale(scale)
	local x,y,z = scale.x,scale.y,scale.z
	mat = userdata("f64",4,4)
	mat:set(0,0,
		x,0,0,0,
		0,y,0,0,
		0,0,z,0,
		0,0,0,1
	)
	return mat
end

return {
	double_transform = double_transform,
	translate = translate,
	rot_x = rot_x,
	rot_y = rot_y,
	rot_z = rot_z,
	rotate = rotate,
	scale = scale,
	quat = quat,
	quatnorm = quatnorm,
	quatmul = quatmul,
	vquatmul = vquatmul,
	quat_mat = quat_mat,
	quat_dtf = quat_dtf,
}