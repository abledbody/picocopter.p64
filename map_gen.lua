--[[pod_format="raw",created="2024-07-07 19:33:12",modified="2024-07-19 23:16:27",revision=1172]]
local Utils = require"utils"
local perlin,invlerp,lerp = Utils.perlin,Utils.invlerp,Utils.lerp

local heightmap_cols = {
	[0] = 32,1,19,16,3,17,27,12,11,26,28,7
}

local function make_heightmap(seed,size,scale,octaves)
	local w,h = size.x,size.y
	local heightmap = userdata("f64",w+1,h+1)
	local extents = {min = 0,max = 0}
	yield{heightmap,extents}
	
	for i = 1,#octaves do
		local scale = scale/i
		local flat = 0
		for y = 0,h do
			for x = 0,w do
				local value = heightmap[flat]+perlin(x,y,scale,seed+i-1)*octaves[i]
				heightmap[flat] = value
				extents.min = min(extents.min,value)
				extents.max = max(extents.max,value)
				flat += 1
				--yield()
			end
		end
	end
end

local function make_roads(seed,size,create_chance,min_len,max_len)
	srand(seed)
	local w,h = size.x,size.y
	local total_roads = (rnd(w*h*0.5)+rnd(w*h*0.5))*create_chance
	
	local roads = userdata("u8",w,h)
	yield(roads)
	
	for r = 1,total_roads do
		local x,y = rnd(w),rnd(h)
		for i = 1,lerp(min_len,max_len,rnd()) do
			roads:set(flr(x),flr(y),1)
			local a = (perlin(x,y,16,seed+r-1)+0.5)*4
			x += cos(flr(a*4)/4)
			y -= sin(flr(a*4)/4)
			if x < 0 or x > w or y < 0 or y > h then
				break
			end
			--yield()
		end
	end
end

local function to_chunks(heightmap)
	local chunks = {}
	
	for y = 0,maph-1 do
		for x = 0,mapw-1 do
			local nw = heightmap[y  ][x  ]
			local sw = heightmap[y+1][x  ]
			local se = heightmap[y+1][x+1]
			local ne = heightmap[y  ][x+1]
			
			local z = min(nw,min(sw,min(se,ne)))
			
			local mat,imat,model
			local pts = userdata("f64",4,4)
			pts:set(0,0,
				         0,nw-z,         0,1,
				chunk_size,ne-z,         0,1,
				         0,sw-z,chunk_size,1,
				chunk_size,se-z,chunk_size,1
			)
			model = import_ptm(
				{
					pts=pts,
					uvs=t_uvs,
					materials=t_mats,
					pt_indices=t_pt_indices,
					uv_indices=t_uv_indices,
				},
				materials
			)
			local mat,imat = Transform.double_transform(
				Transform.translate,vec(x*chunk_size,z,y*chunk_size,1)
			)
			chunks[y][x] = {model,mat,imat}
		end
	end
	
	return chunks
end

local function render(heightmap,extents,roads)
	local w,h = heightmap:width()-1,heightmap:height()-1
	local chunk_avg = userdata("f64",w,h)
	chunk_avg:add(heightmap,true,0,0,w,w+1,w,h)
	chunk_avg:add(heightmap,true,1,0,w,w+1,w,h)
	chunk_avg:add(heightmap,true,w+1,0,w,w+1,w,h)
	chunk_avg:add(heightmap,true,w+2,0,w,w+1,w,h)
	chunk_avg:mul(0.25,true)
	
	local pw,ph = 1,1
	while pw < w do
		pw <<= 1
	end
	while ph < h do
		ph <<= 1
	end
	
	local vmap = userdata("u8",pw,ph)
	local flat = 0
	local col_count = #heightmap_cols+1
	for y = 0,h-1 do
		for x = 0,w-1 do
			if roads:get(x,y,1) > 0 then
				vmap:set(x,y,5)
			else
				local z = invlerp(extents.min,extents.max,chunk_avg[flat])
				vmap:set(x,y,heightmap_cols[flr(z*col_count)])
			end
			flat += 1
		end
	end
	
	return vmap
end

local function draw(heightmap,extents,roads,pos,size)
	local w,h = heightmap:width()-1,heightmap:height()-1
	local vmap = render(heightmap,extents,roads)
	
	local scalar = mid(size.x/w,size.y/h,1)
	size = vec(w,h)*scalar
	
	for y = pos.y,pos.y+size.y-1 do
		local v = y/size.y*h
		tline3d(vmap,pos.x,y,pos.x+size.x,y,0,v,w,v,nil,nil,0x100)
	end
end

return {
	make_heightmap = make_heightmap,
	make_roads = make_roads,
	to_chunks = to_chunks,
	draw = draw,
}