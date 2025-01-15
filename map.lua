local Chunk = require"chunk"
local TILE_SIZE = Chunk.TILE_SIZE
local Camera = require"camera"
local Rendering = require"blade3d.rendering"
local B3dUtils = require"blade3d.utils"
local import_ptm = require"blade3d.ptm_importer"
local materials = require"materials"

local building = import_ptm("mdl/Building1.ptm",materials)

local tile_generators = {
	[0] = function(x,y,nw,ne,sw,se)
		return Chunk.new(
			Chunk.terrain_model("Grass",ne-nw,sw-nw,se-nw),vec(x,y),nw
		)
	end,
	function(x,y,nw,ne,sw,se)
		return Chunk.new(building,vec(x,y),nw)
	end,
}

local object_drawers = {
	[0] = function(pos)
		Rendering.queue_billboard(pos,materials["Tree"],ambience,sun)
	end,
}

local function get_height(level,x,y)
	local mapx,mapy = x/TILE_SIZE,y/TILE_SIZE
	mapx,mapy = mid(mapx,0,level.width),mid(mapy,0,level.height)
	local nw,ne = level.heightmap:get(flr(mapx),flr(mapy),2)
	local sw,se = level.heightmap:get(flr(mapx),ceil(mapy),2)
	
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
	return B3dUtils.lerp(n,s,mapy%1)*TILE_SIZE
end

local function draw(map,cam_pos)
	local sortable_chunks = {}
	local min_y = flr(cam_pos.z/TILE_SIZE-Camera.DRAW_DIST)
	local max_y = flr(cam_pos.z/TILE_SIZE+Camera.DRAW_DIST)
	local min_x = flr(cam_pos.x/TILE_SIZE-Camera.DRAW_DIST)
	local max_x = flr(cam_pos.x/TILE_SIZE+Camera.DRAW_DIST)

	for y = min_y,max_y do
		local y_arr = map[y]
		if y_arr then
			for x = min_x,max_x do
				local chunk = y_arr[x]
				if chunk then
					local model,mat = chunk.model,chunk.mat
					if Rendering.in_frustum(model,mat) then
						local depth = (vec(x,y)+0.5)*TILE_SIZE-vec(cam_pos.x,cam_pos.z)
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

	for chunk_dist in sorted do
		local chunk = chunk_dist[1]
		local model,mat,imat,objects =
			chunk.model,chunk.mat,chunk.imat,chunk.objects
		
		Rendering.queue_model(model,mat,imat,ambience,sun)
		Rendering.draw_all()
		
		if objects then
			for object in all(objects) do
				local drawer = object_drawers[object.id]
				if drawer then
					drawer(object.pos)
				end
			end
		end
		Rendering.draw_all()
	end
end

local m_map = {
	get_height = get_height,
	draw = draw,
}
m_map.__index = m_map

local function load(level_name)
	local map_dat = fetch("/ram/cart/pclv/"..level_name..".pclv")
	local heightmap,tiles = map_dat.heightmap,map_dat.tiles

	local map = setmetatable({
		heightmap = heightmap,
		tiles = tiles,
		width = tiles:width(),
		height = tiles:height(),
	},m_map)

	for y = 0, heightmap:height()-2 do
		map[y] = {}
		for x = 0, heightmap:width()-2 do
			local nw,ne = heightmap:get(x,y,2)
			local sw,se = heightmap:get(x,y+1,2)
			
			local tile_gen =
				tile_generators[tiles:get(x,y,1)]
				or tile_generators[0]

			map[y][x] = tile_gen(x,y,nw,ne,sw,se)
		end
	end

	for object in all(map_dat.objects) do
		local y_arr = map[object.pos.y\1]
		if y_arr then
			local chunk = y_arr[object.pos.x\1]
			if chunk then
				if not chunk.objects then
					chunk.objects = {}
				end
				object.pos *= TILE_SIZE
				object.pos = vec(
					object.pos.x,
					map:get_height(object.pos.x,object.pos.y),
					object.pos.y,1
				)
				add(chunk.objects,object)
			end
		end
	end


	return setmetatable(map,m_map)
end

return {
	load = load,
}