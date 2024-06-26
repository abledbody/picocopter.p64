--[[pod_format="raw",created="2024-05-22 17:25:58",modified="2024-06-26 22:47:36",revision=15551]]
include"require.lua"
include"profiler.lua"

profile.enabled(false,true)

local Rendering = require"rendering"
local Transform = require"transform"
local Utils = require"utils"
local Helicopter = require"helicopter"
local Camera = require"camera"
local import_pcm = require"pcm_importer"
local materials = require"materials"
local quat = require"quaternions"

local t_flat = import_pcm("mdl/TerrainFlat.pcm",materials)
local t_slope = import_pcm("mdl/TerrainSlope.pcm",materials)
local t_in = import_pcm("mdl/TerrainIn.pcm",materials)
local t_out = import_pcm("mdl/TerrainOut.pcm",materials)
local t_cross = import_pcm("mdl/TerrainCross.pcm",materials)
local building = import_pcm("mdl/Building1.pcm",materials)

srand(1304145)
local heightmap = {}
for y = -10,11 do
	heightmap[y] = {}
	for x = -10,11 do
		local minz,maxz = 0,10
		local has_west = x > -10
		local has_east = x < 11
		local has_north = y > -10
		if has_west then
			local w = heightmap[y][x-1]
			minz = max(minz,w-1)
			maxz = min(maxz,w+1)
		end
		if has_north then
			local n = heightmap[y-1][x]
			minz = max(minz,n-1)
			maxz = min(maxz,n+1)
		end
		if has_west and has_north then
			local nw = heightmap[y-1][x-1]
			minz = max(minz,nw-1)
			maxz = min(maxz,nw+1)
		end
		if has_east and has_north then
			local ne = heightmap[y-1][x+1]
			minz = max(minz,ne-1)
			maxz = min(maxz,ne+1)
		end
		
		heightmap[y][x] = flr(Utils.lerp(minz,maxz,rnd())+0.5)
	end
end

local function get_chunk_pos(x,y)
	return x/16+0.5,y/16+0.5
end

function get_height(x,y)
	local mapx,mapy = get_chunk_pos(x,y)
	local y_arr = heightmap[flr(mapy)]
	nw = y_arr and y_arr[flr(mapx)] or 0
	ne = y_arr and y_arr[ceil(mapx)] or 0
	y_arr = heightmap[ceil(mapy)]
	sw = y_arr and y_arr[flr(mapx)] or 0
	se = y_arr and y_arr[ceil(mapx)] or 0
	local n = Utils.lerp(nw,ne,mapx%1)
	local s = Utils.lerp(sw,se,mapx%1)
	return Utils.lerp(n,s,mapy%1)*8
end

local terrain_lookup = {
	[0b0000] = {t_flat,0},
	
	[0b0001] = {t_out,0},
	[0b0010] = {t_out,0.25},
	[0b0100] = {t_out,0.5},
	[0b1000] = {t_out,0.75},
	
	[0b1001] = {t_slope,0},
	[0b0011] = {t_slope,0.25},
	[0b0110] = {t_slope,0.5},
	[0b1100] = {t_slope,0.75},
	
	[0b1011] = {t_in,0},
	[0b0111] = {t_in,0.25},
	[0b1110] = {t_in,0.5},
	[0b1101] = {t_in,0.75},
	
	[0b1010] = {t_cross,0},
	[0b0101] = {t_cross,0.25},
}

local chunks = {}

for y = -10,10 do
	chunks[y] = {}
	for x = -10,10 do
		local nw = heightmap[y  ][x  ]
		local sw = heightmap[y+1][x  ]
		local se = heightmap[y+1][x+1]
		local ne = heightmap[y  ][x+1]
		
		local z = min(nw,min(sw,min(se,ne)))
		local lookup_index =
			(nw > z and 0b0001 or 0)
			| (sw > z and 0b0010 or 0)
			| (se > z and 0b0100 or 0)
			| (ne > z and 0b1000 or 0)
		
		local mat,imat,model
		if lookup_index == 0 and rnd() < 0.8 then
			mat,imat = Transform.double_transform(
				Transform.translate,vec(x*16,z*8,y*16))
			model = building
		else
			local t_model,y_rot = unpack(terrain_lookup[lookup_index])
			
			mat,imat =
				Transform.double_transform(Transform.translate,vec(x*16,z*8,y*16),
				Transform.double_transform(Transform.rot_y,y_rot))
			model = t_model
		end
		chunks[y][x] = {model,mat,imat}
	end
end

Rendering.cam{near=0.3,far=128,fov=110}

function _update()
	Helicopter.update()
	Camera.update()
end

local sky_spr = get_spr(7)

function draw_sky(pitch,yaw)
	local sky_x_off = yaw%0.25*1920
	local sky_y_off = abs(pitch*1920)
	blit(sky_spr,0,-sky_x_off,sky_y_off,0,0,480,270-sky_y_off)
	blit(sky_spr,0,-sky_x_off+480,sky_y_off,0,0,480,270-sky_y_off)
end

function _draw()
	cls(12)
	local cam_pos = Camera.get_pos()
	local _,cam_pitch,cam_yaw = Camera.get_rot()
	-- Sky
	draw_sky(cam_pitch,cam_yaw)
	
	-- Chunks
	local sorted_chunks = {}
	for y = flr(cam_pos.z/16-3.5),flr(cam_pos.z/16+4.5) do
		local y_arr = chunks[y]
		if y_arr then
			for x = flr(cam_pos.x/16-3.5),flr(cam_pos.x/16+4.5) do
				local chunk = y_arr[x]
				if chunk then
					local model,mat = unpack(chunk)
					if Rendering.in_frustum(model,mat) then
						local depth = vec(x*16,y*16)-vec(cam_pos.x,cam_pos.z)
						depth *= depth
						add(sorted_chunks,{chunk,depth = depth.x+depth.y})
					end
				end
			end
		end
	end
	
	profile("Z-sorting")
	Utils.sort(sorted_chunks,"depth")
	profile("Z-sorting")
	
	for i = #sorted_chunks,1,-1 do
		local chunk = sorted_chunks[i]
		Rendering.model(unpack(chunk[1]))
		Rendering.draw_all()
	end
	
	-- Helicopter
	Helicopter.draw()
	Rendering.draw_all()
	
	profile.draw()
end

include"error_explorer.lua"