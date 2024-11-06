--[[pod_format="raw",created="2024-05-22 17:25:58",modified="2024-11-06 05:06:09",revision=18665]]
include"require.lua"
include"profiler.lua"

poke4(0x5000, get(fetch"/ram/cart/pal/0.pal"))

profile.enabled(false,true)
local show_forces = false

sun = vec(0.3,0.8,0.6)
ambience = 0.1

local Rendering = require"blade3d.rendering"
local Transform = require"blade3d.transform"
local quat = require"blade3d.quaternions"
local B3dUtils = require"blade3d.utils"

local perlin = require"utils".perlin
local Helicopter = require"helicopter"
local Camera = require"camera"
local import_ptm = require"blade3d.ptm_importer"
local materials = require"materials"
local MapGen = require"map_gen"

local building = import_ptm("mdl/Building1.ptm",materials)

local mapw = 48
local maph = 48
local chunk_size = 32
local draw_dist = 4

local loops
force_display = {}

local terrain_seed = 546244

function coplow(co)
	local state,output = coresume(co)
	if state then
		return output
	else
		error(output)
	end
end

local heightmap_co = cocreate(function()
	MapGen.make_heightmap(terrain_seed,vec(mapw,maph),8,{1,0.5,0.5})
end)
local road_co = cocreate(function()
	MapGen.make_roads(terrain_seed+10,vec(mapw,maph),0.03,8,45)
end)
local heightmap,extents = unpack(coplow(heightmap_co))
local roads = coplow(road_co)

local function get_chunk_pos(x,y)
	return x/chunk_size,y/chunk_size
end

local sqrt2 = sqrt(2)

function get_height(x,y)
	local mapx,mapy = get_chunk_pos(x,y)
	mapx,mapy = mid(mapx,0,mapw),mid(mapy,0,maph)
	local nw,ne = heightmap:get(flr(mapx),flr(mapy),2)
	local sw,se = heightmap:get(flr(mapx),ceil(mapy),2)
	
	--[[
	local in_chunk = vec(mapx%1,mapy%1)
	local diag_t = vec(0.5,-0.5):dot(vec(in_chunk.x,in_chunk.y-1))
	local cross_diag_t = vec(0.5,0.5):dot(in_chunk)
	local diag = Utils.lerp(sw,ne,diag_t)
	
	if cross_diag_t > 0.5 then
		return Utils.lerp(diag,se,cross_diag_t*2-1)
	else
		return Utils.lerp(nw,diag,cross_diag_t*2)
	end]]
	
	local n = B3dUtils.lerp(nw,ne,mapx%1)
	local s = B3dUtils.lerp(sw,se,mapx%1)
	return B3dUtils.lerp(n,s,mapy%1)
end

local chunks = {}

local graphical_map = userdata("u8",mapw,maph)

local heli_body = Helicopter.get_body()
heli_body.position = vec(mapw*chunk_size*0.5,0,maph*chunk_size*0.5)
heli_body.position.y = get_height(heli_body.position.x,heli_body.position.z)

function update_game()
	force_display = {}
	Helicopter.update()
	Camera.update()
	sun = quat.vmul(vec(0.8,0,0.3),quat(vec(0,-1,0),(t()*0.05)%0.5))*abs(-sin(t()*0.05)*((t()*0.05)%1 > 0.5 and 0.1 or 3))
	ambience = max(-sin(t()*0.05),0)*0.15+0.02
end

local sky_spr = get_spr(7)

local function draw_sky(pitch,yaw)
	local sky_x_off = yaw%0.25*1920
	local sky_y_off = abs(pitch*1920)
	blit(sky_spr,0,-sky_x_off,sky_y_off,0,0,480,270-sky_y_off)
	blit(sky_spr,0,-sky_x_off+480,sky_y_off,0,0,480,270-sky_y_off)
end

local function draw_map(x,y)
	rect(x,y,x+mapw+1,y+maph+1,16)
	sspr(graphical_map,0,0,mapw,maph,x+1,y+1)
	
	if time()%0.8 > 0.2 then
		local hx,hy =
			flr(heli_body.position.x/chunk_size+x+1),
			flr(heli_body.position.z/chunk_size+y+1)
		
		local up = vec(0,1,0)
		local angle = quat.angle(quat.twist(heli_body.rotation,up),up)-0.25
		local fwd_x,fwd_y = cos(angle),-sin(angle)
		
		line(hx+fwd_x*sqrt2,hy+fwd_y*sqrt2,hx+fwd_x*6,hy+fwd_y*6,9)
		circ(hx,hy,1,9)
	end
end

local function draw_game()
	cls(12)
	local cam_pos = Camera.get_pos()
	local _,cam_pitch,cam_yaw = Camera.get_rot()
	-- Sky
	draw_sky(cam_pitch,cam_yaw)
	
	-- Chunks
	local sortable_chunks = {}
	local min_y = flr(cam_pos.z/chunk_size-draw_dist)
	local max_y = flr(cam_pos.z/chunk_size+draw_dist)
	local min_x = flr(cam_pos.x/chunk_size-draw_dist)
	local max_x = flr(cam_pos.x/chunk_size+draw_dist)
	for y = min_y,max_y do
		local y_arr = chunks[y]
		if y_arr then
			for x = min_x,max_x do
				local chunk = y_arr[x]
				if chunk then
					local model,mat = unpack(chunk)
					if Rendering.in_frustum(model,mat) then
						local depth = (vec(x,y)+0.5)*chunk_size-vec(cam_pos.x,cam_pos.z)
						depth *= depth
						add(sortable_chunks,{chunk,depth = depth.x+depth.y})
					end
				end
			end
		end
	end
	
	profile"Z-sorting"
	local sorted = B3dUtils.tab_sort(sortable_chunks,"depth",true)
	profile"Z-sorting"
	
	for chunk in sorted do
		local model,mat,imat = unpack(chunk[1])
		Rendering.queue_model(model,mat,imat,ambience,sun)
		Rendering.draw_all()
	end
	
	-- Helicopter
	Helicopter.draw()
	Rendering.draw_all()
	
	-- Forces
	if show_forces then
		for i = 1,#force_display do
			local force = force_display[i]
			local pt = vec(0,0,0,1):add(force[1],true)
			Rendering.queue_line(
				pt,
				pt+force[2]*0.1,
				force[3],B3dUtils.ident_4x4())
		end
		Rendering.draw_all()
	end
	
	draw_map(0,0)
	
	for i = 0,16 do
		for j = 0,63 do
			memcpy(0x10000+i*480+j+65,0x81000+i*0x1000+j*64+1,1)
		end
	end
	
	profile.draw()
end

local gen_co = cocreate(function()
	while costatus(heightmap_co) == "suspended" do
		coplow(heightmap_co)
		if stat(1) > 0.5 then yield() end
	end
	while costatus(road_co) == "suspended" do
		coplow(road_co)
		yield()
	end
	heightmap:add(0.4,true)
	heightmap:mul(70,true)
	
	for y = 0,maph-1 do
		chunks[y] = {}
		for x = 0,mapw-1 do
			local building_prob = perlin(x,y,7,85)+0.5
			if building_prob > 0.5 and building_prob < 0.6 then
				graphical_map[x+y*mapw] = 22
	
				local nw,ne = heightmap:get(x,y,2)
				local sw,se = heightmap:get(x,y+1,2)
					
				local z = (nw+sw+se+ne)*0.25
				
				heightmap:set(x,y,z,z)
				heightmap:set(x,y+1,z,z)
				local mat,imat = Transform.double_translate(
					vec(x*chunk_size+chunk_size/2,z,y*chunk_size+chunk_size/2))
				chunks[y][x] = {building,mat,imat}
			end
		end
	end
	
	chunks,graphical_map =
		MapGen.to_chunks(chunks,graphical_map,heightmap,materials,vec(mapw,maph),chunk_size)
end)

local function update_generation()
	if costatus(gen_co) == "suspended" then
		coplow(gen_co)
	else
		loops = {update = update_game,draw = draw_game}
	end
end

local function draw_generation()
	cls()
	MapGen.draw(heightmap,extents,roads,vec(0,0),vec(270,270))
end

loops = {update = update_generation,draw = draw_generation}
function _update() loops.update() end
function _draw() loops.draw() end

include"error_explorer.lua"