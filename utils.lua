--[[pod_format="raw",created="2024-05-22 18:39:52",modified="2024-07-19 23:16:27",revision=10248]]
local function brot(x,k)
	return (x<<k)|(x>>(32-k))
end

local prime1,prime2,prime3 = 356735872903,845723454073,34478587249
local max32 = 2^32-1

local function hash_xy(x,y,seed)
	x += 674
	y += 2986
	seed += 397
	local hash = brot(x*prime1,y%32)^^brot(y*prime2,seed%32)^^brot(seed*prime3,x%32)
	return hash/max32
end

local sqrt2 = sqrt(2)

local function perlin(x,y,scale,seed)
	x,y = x/scale,y/scale
	local seed_x,seed_y = flr(x),flr(y)
	local nw = hash_xy(seed_x,seed_y,seed)
	local ne = hash_xy(seed_x+1,seed_y,seed)
	local sw = hash_xy(seed_x,seed_y+1,seed)
	local se = hash_xy(seed_x+1,seed_y+1,seed)
	
	x,y = x%1,y%1
	
	local nwd = (vec(cos(nw),-sin(nw)):dot(vec(x,y))/sqrt2)
	local ned = (vec(cos(ne),-sin(ne)):dot(vec(x-1,y))/sqrt2)
	local swd = (vec(cos(sw),-sin(sw)):dot(vec(x,y-1))/sqrt2)
	local sed = (vec(cos(se),-sin(se)):dot(vec(x-1,y-1))/sqrt2)
	
	local smooth_x = 6*x^5-15*x^4+10*x^3
	local smooth_y = 6*y^5-15*y^4+10*y^3
	
	local n = (ned-nwd)*smooth_x+nwd
	local s = (sed-swd)*smooth_x+swd
	return (s-n)*smooth_y+n
end

return {
	hash_xy = hash_xy,
	perlin = perlin
}