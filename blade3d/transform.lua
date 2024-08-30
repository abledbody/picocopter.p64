--[[pod_format="raw",created="2024-05-23 00:40:43",modified="2024-06-14 22:18:11",revision=6156]]

---Creates a translation matrix.
---@param pos userdata The translation to apply.
---@return userdata @A translation matrix.
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

---Applies a translation to a forward transformation matrix,
---and its inverse to an inverse transformation matrix.
---@param pos userdata The translation to apply.
---@param forward? userdata The original forward transformation matrix.
---@param inverse? userdata The original inverse transformation matrix.
---@return userdata @The new forward transformation matrix.
---@return userdata @The new inverse transformation matrix.
local function double_translate(pos,forward,inverse)
	local mat = translate(pos)
	local imat = translate(pos*-1)
	if forward then
		return forward:matmul3d(mat),imat:matmul3d(inverse)
	end
	return mat,imat
end

---Creates a rotation matrix around the x-axis.
---@param a number The angle to rotate by in revolutions.
---@return userdata @A rotation matrix.
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

---Creates a rotation matrix around the y-axis.
---@param a number The angle to rotate by in revolutions.
---@return userdata @A rotation matrix.
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

---Creates a rotation matrix around the z-axis.
---@param a number The angle to rotate by in revolutions.
---@return userdata @A rotation matrix.
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

---Creates a rotation matrix from a set of Euler angles.
---@param rot userdata The XYZ Euler angles in revolutions.
---@return userdata @A rotation matrix.
local function rotate(rot)
	local x,y,z = rot.x,rot.y,rot.z
	local x_mat = rot_x(x)
	local y_mat = rot_y(y)
	local z_mat = rot_z(z)
	return z_mat:matmul3d(x_mat):matmul3d(y_mat)
end

---Applies an Euler angles rotation to a forward transformation matrix,
---and its inverse to an inverse transformation matrix.
---@param rot userdata The XYZ Euler angles in revolutions.
---@param forward? userdata The original forward transformation matrix.
---@param inverse? userdata The original inverse transformation matrix.
local function double_rotate(rot,forward,inverse)
	local mat = rotate(rot)
	local imat = mat:transpose()
	if forward then
		return forward:matmul3d(mat),imat:matmul3d(inverse)
	end
	return mat,imat
end

---Creates a scaling matrix.
---@param scale userdata The scale to apply.
---@return userdata @A scaling matrix.
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

---Applies a scaling to a forward transformation matrix,
---and its inverse to an inverse transformation matrix.
---@param scaling userdata The scaling to apply.
---@param forward? userdata The original forward transformation matrix.
---@param inverse? userdata The original inverse transformation matrix.
---@return userdata @The new forward transformation matrix.
---@return userdata @The new inverse transformation matrix.
local function double_scale(scaling,forward,inverse)
	local mat = scale(scaling)
	local imat = scale(1/scaling)
	if forward then
		return forward:matmul3d(mat),imat:matmul3d(inverse)
	end
	return mat,imat
end

---The Transform module provides functions for working with transformation
---matrices.
return {
	translate = translate,
	rot_x = rot_x,
	rot_y = rot_y,
	rot_z = rot_z,
	rotate = rotate,
	scale = scale,
	
	double_translate = double_translate,
	double_scale = double_scale,
	double_rotate = double_rotate,
}