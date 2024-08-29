--[[pod_format="raw",created="2024-06-14 20:38:40",modified="2024-07-03 20:39:10",revision=4928]]

local Utils = require"blade3d.utils"
local acos = Utils.acos

local function new(_,dir,angle)
	local out = vec(dir.x,dir.y,dir.z,0)*-sin(angle*0.5)
	out[3] = cos(angle*0.5)
	return out
end

local function inv(quat)
	return vec(-quat.x,-quat.y,-quat.z,quat[3])
end

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

local function mul(a,b)
	local w1,w2 = a[3],b[3]
	local v1 = userdata("f64",3,1):copy(a,true,0,0,3)
	local v2 = userdata("f64",3,1):copy(b,true,0,0,3)
	local real = w1*w2-v1:dot(v2)
	local vector = v1*w2+v2*w1+v1:cross(v2)
	
	return vec(vector.x,vector.y,vector.z,real)
end

local function vmul(vector,quat)
	local qw = quat[3]
	local qv = userdata("f64",3,1):copy(quat,true,0,0,3)
	-- Forward
	local scalar = -qv:dot(vector)
	vector = vector*qw+qv:cross(vector)
	-- Inverse
	return vector*qw-qv*scalar-vector:cross(qv)
end

local function norm(vector)
	return vector:div(vector:magnitude(),true)
end

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

local function dtf(quat,forward,inverse)
	local qmat = mat(quat)
	local qimat = qmat:transpose()
	if forward then
		return forward:matmul3d(qmat),qimat:matmul3d(inverse)
	end
	return qmat,qimat
end

local function delta(v1,v2)
	local dir = v1:cross(v2)
	return norm(vec(dir.x,dir.y,dir.z,v1:dot(v2)*0.5))
end

local function twist(quat,axis)
	local twist = quat:dot(axis)*axis
	return norm(vec(twist.x,twist.y,twist.z,quat[3]))
end

local function swing(quat,twist)
	local swing = mul(inv(twist),quat)
	return swing
end

local function axis(quat)
	local axis = quat:copy(quat,nil,0,0,3)
	return norm(axis) or vec(0,1,0)
end

local function angle(quat,dir)
	local w = quat[3]
	local theta = acos(w)*2
	local axis = axis(quat)
	return theta*sgn(dir:dot(axis))
end

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