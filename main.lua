--[[pod_format="raw",created="2024-05-22 17:25:58",modified="2024-11-16 19:03:23",revision=18667]]
include"require.lua"
include"profiler.lua"

poke4(0x5000, get(fetch"/ram/cart/pal/0.pal"))

profile.enabled(false,true)
local show_forces = false

sun = vec(0.25,0.64,0.5)
ambience = 0.25

local Rendering = require"blade3d.rendering"
local quat = require"blade3d.quaternions"
local B3dUtils = require"blade3d.utils"

local Helicopter = require"helicopter"
local Camera = require"camera"
local Map = require"map"
local Chunk = require"chunk"
local TILE_SIZE = Chunk.TILE_SIZE

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

map = Map.load"basin"
local mapw,maph = map.width,map.height

local sqrt2 = sqrt(2)

local graphical_map = userdata("u8",mapw,maph)

local heli_body = Helicopter.get_body()
heli_body.position = vec(mapw*TILE_SIZE*0.5,0,maph*TILE_SIZE*0.5)
heli_body.position.y = map:get_height(heli_body.position.x,heli_body.position.z)

function update_game()
	force_display = {}
	Helicopter.update()
	Camera.update()
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
			flr(heli_body.position.x/TILE_SIZE+x+1),
			flr(heli_body.position.z/TILE_SIZE+y+1)
		
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
	map:draw(cam_pos)
	
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
	
--[[ 	for i = 0,16 do
		for j = 0,63 do
			memcpy(0x10000+i*480+j+65,0x81000+i*0x1000+j*64+1,1)
		end
	end ]]
	
	profile.draw(7)
end

loops = {update = update_game,draw = draw_game}
function _update() loops.update() end
function _draw() loops.draw() end

include"error_explorer.lua"