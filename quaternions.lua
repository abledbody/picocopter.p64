--[[pod_format="raw",created="2024-06-14 20:38:40",modified="2024-06-26 22:47:36",revision=3889]]
local function new(_,dir,angle)
	local out = vec(dir.x,dir.y,dir.z,0)*-sin(angle*0.5)
	out[3] = cos(angle*0.5)
	return out
end

local function mul(a,b)
	local qq = a*b
	local awb,axb,ayb,azb =
		b*a[3],
		b*a.x,
		b*a.y,
		b*a.z
	
	return vec(
		awb.x + axb[3] + ayb.z - azb.y,
		awb.y + ayb[3] + azb.x - axb.z,
		awb.z + azb[3] + axb.y - ayb.x,
		qq[3] -   qq.x -  qq.y -  qq.z
	)
end

local function vmul(vector,quat)
	local iquat = vec(-quat.x,-quat.y,-quat.z,quat[3])
	return mul(mul(quat,vec(vector[0],vector[1],vector[2],0)),iquat)
end

local function norm(vector)
	return vector:div(vector:magnitude(),true)
end

local function mat(quat)
	local quat2 = quat*2
	local qq,qx,qy,qz,qw =
		quat2*quat,
		quat2*quat.x,
		quat2*quat.y,
		quat2*quat.z,
		quat2*quat.w
	
	local mat = userdata("f64",4,4)
	mat:set(0,0,
		1-qq.y-qq.z,  qx.y+qz[3],  qx.z-qy[3], 0,
		 qx.y-qz[3], 1-qq.x-qq.z,  qy.z+qx[3], 0,
		 qx.z+qy[3],  qy.z-qx[3], 1-qq.x-qq.y, 0,
		          0,           0,           0, 1
	)
	return mat
end

local function inv(quat)
	return vec(-quat.x,-quat.y,-quat.z,quat[3])
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
	local half_dot = v1:dot(v2)*0.5
	local out = vec(dir.x,dir.y,dir.z,0)*sqrt(0.5-half_dot)
	out[3] = sqrt(0.5+half_dot)
	return out
end

local function twist(quat,axis)
	local twist = quat:dot(axis)*axis
	return norm(vec(twist.x,twist.y,twist.z,quat[3]))
end

local function swing(quat,twist)
	local swing = mul(inv(twist),quat)
	return swing
end

local function slerp(a,b,t)
	local y = sqrt(1-b[3]*b[3])
	local angle = atan2(b[3],y)
	local dir = norm(vec(b.x,b.y,b.z))
	b = new(nil,dir,angle*t)
	return mul(a,b)
end

local quat = {
	__call = new,
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
}
setmetatable(quat,quat)

return quat