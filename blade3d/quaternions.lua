--[[pod_format="raw",created="2024-06-14 20:38:40",modified="2024-07-03 20:39:10",revision=4928]]
local acos = require"blade3d.utils".acos

---Creates a new quaternion which rotates `angle` revolutions around `dir`.
---@param dir userdata The direction vector.
---@param angle number The angle in revolutions.
local function new(_,dir,angle) -- Discard 'cause __call always provides self.
	local out = vec(dir.x,dir.y,dir.z,0)*-sin(angle*0.5)
	out[3] = cos(angle*0.5)
	return out
end

---Gets the inverse of a unit quaternion.
local function inv(quat)
	return vec(-quat.x,-quat.y,-quat.z,quat[3])
end

---Creates a quaternion from Euler angles.
---@param euler userdata The Euler angles in revolutions.
---@return userdata @A quaternion with the specified rotation.
local function from_euler(euler)
	euler *= 0.5
	
	local x = vec(cos(euler.x),-sin(euler.x))
	local y = vec(cos(euler.y),-sin(euler.y))
	local z = vec(cos(euler.z),-sin(euler.z))
	local xy,xz,yz = x*y,x*z,y*z
	local xyz = xy*z
	
	return vec(
		yz.x*x.y + yz.y*x.x,
		xz.x*y.y - xz.y*y.x,
		xy.x*z.y + xy.y*z.x,
		xyz.x    - xyz.y
	)
end

---Multiplies two quaternions.
---@param a userdata The second rotation operation as a quaternion.
---@param b userdata The first rotation operation as a quaternion.
---@return userdata @The combined rotation as a quaternion.
local function mul(a,b)
	local w1,w2 = a[3],b[3]
	local v1 = userdata("f64",3,1):copy(a,true,0,0,3)
	local v2 = userdata("f64",3,1):copy(b,true,0,0,3)
	local real = w1*w2-v1:dot(v2)
	local vector = v1*w2+v2*w1+v1:cross(v2)
	
	return vec(vector.x,vector.y,vector.z,real)
end

---Multiplies a quaternion by a vector.
---@param vector userdata The vector to rotate.
---@param quat userdata The quaternion to rotate by.
---@return userdata @The rotated vector.
local function vmul(vector,quat)
	local qw = quat[3]
	local qv = userdata("f64",3,1):copy(quat,true,0,0,3)
	-- Forward
	local scalar = -qv:dot(vector)
	vector = vector*qw+qv:cross(vector)
	-- Inverse
	return vector*qw-qv*scalar-vector:cross(qv)
end

---Normalizes a vector or quaternion. Mutates the input.
---@return userdata @The normalized vector or quaternion.
local function norm(vector)
	return vector:div(vector:magnitude(),true)
end

---Creates a rotation matrix from a quaternion.
---@param quat userdata The quaternion to convert.
---@return userdata @A 4x4 rotation matrix.
local function mat(quat)
	local quat2 = quat*2
	local qq,qx,qy,qz =
		quat2*quat,
		quat2*quat.x,
		quat2*quat.y,
		quat2*quat.z
	
	local mat = userdata("f64",4,4)
	mat:set(0,0,
		1-qq.y-qq.z,  qx.y+qz[3],  qx.z-qy[3], 0,
		 qx.y-qz[3], 1-qq.x-qq.z,  qy.z+qx[3], 0,
		 qx.z+qy[3],  qy.z-qx[3], 1-qq.x-qq.y, 0,
		          0,           0,           0, 1
	)
	return mat
end

---Applies a quaternion to a forward transformation matrix,
---and its inverse to an inverse transformation matrix.
---@param quat userdata The quaternion to apply.
---@param forward? userdata The original forward transformation matrix.
---@param inverse? userdata The original inverse transformation matrix.
---@return userdata @The new forward transformation matrix.
---@return userdata @The new inverse transformation matrix.
local function dtf(quat,forward,inverse)
	local qmat = mat(quat)
	local qimat = qmat:transpose()
	if forward then
		return forward:matmul3d(qmat),qimat:matmul3d(inverse)
	end
	return qmat,qimat
end

---Generates a quaternion representing the rotation between v1 and v2.
---@param v1 userdata The first normalized vector.
---@param v2 userdata The second normalized vector.
---@return userdata @The rotation between the two vectors as a quaternion.
local function delta(v1,v2)
	local dir = v1:cross(v2)
	return norm(vec(dir.x,dir.y,dir.z,v1:dot(v2)*0.5))
end

---Extracts the component of `quat` which rotates around `axis`.
---@param quat userdata The quaternion to extract from.
---@param axis userdata The axis to extract.
---@return userdata @The twist component of the quaternion.
local function twist(quat,axis)
	local twist = quat:dot(axis)*axis
	return norm(vec(twist.x,twist.y,twist.z,quat[3]))
end

---Extracts the component of `quat` which is not contained in `twist`.
---@param quat userdata The quaternion to extract from.
---@param twist userdata The twist component to remove.
---@return userdata @The swing component of the quaternion.
local function swing(quat,twist)
	return mul(inv(twist),quat)
end

---@return userdata @The axis of rotation of `quat`.
local function axis(quat)
	local axis = quat:copy(quat,nil,0,0,3)
	return norm(axis) or vec(0,1,0)
end

---@return number @The number of revolutions around `dir` that `quat` traverses.
local function angle(quat,dir)
	local w = quat[3]
	local theta = acos(w)*2
	local _axis = axis(quat)
	return theta*sgn(dir:dot(_axis))
end

---Spherically interpolates between two quaternions.
---@param a userdata The first quaternion.
---@param b userdata The second quaternion.
---@param t number The interpolation factor.
---@return userdata @The interpolated quaternion.
local function slerp(a,b,t)
	local dot = a:dot(b)
	if dot < 0 then
		b *= -1
		dot = -dot
	end
	
	if dot > 0.9995 then
		return norm(a*(1-t)+b*t)
	end
	
	local dir = axis(b)
	b = new(nil,dir,acos(b[3])*2*t)
	return mul(a,b)
end

---The quaternion module. Call it to create a quaternion with an axis and angle.
---@class Quat
local quat = {
	__call = new,
	from_euler = from_euler,
	mul = mul,
	vmul = vmul,
	norm = norm,
	mat = mat,
	inv = inv,
	dtf = dtf,
	delta = delta,
	twist = twist,
	swing = swing,
	slerp = slerp,
	angle = angle,
}
setmetatable(quat,quat)

return quat