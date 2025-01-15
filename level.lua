local Chunk = require"chunk"
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

local function load(map_dat)
	local heightmap = map_dat.heightmap

	local chunks = {}

	for y = 0, heightmap:height()-2 do
		chunks[y] = {}
		for x = 0, heightmap:width()-2 do
			local nw,ne = heightmap:get(x,y,2)
			local sw,se = heightmap:get(x,y+1,2)
			
			local tile_gen =
				tile_generators[map_dat.tiles:get(x,y,1)]
				or tile_generators[0]

			chunks[y][x] = tile_gen(x,y,nw,ne,sw,se)
		end
	end

	for object in all(map_dat.objects) do
		local y_arr = chunks[object.pos.y\1]
		if y_arr then
			local chunk = y_arr[object.pos.x\1]
			if chunk then
				if not chunk.objects then
					chunk.objects = {}
				end
				object.pos = vec(
					object.pos.x*Chunk.TILE_SIZE,
					object.pos.y*Chunk.TILE_SIZE,
					0,1
				)
				add(chunk.objects,object)
			end
		end
	end

	return chunks
end

local function draw(chunks,cam_pos)
	local sortable_chunks = {}
	local min_y = flr(cam_pos.z/Chunk.TILE_SIZE-Camera.DRAW_DIST)
	local max_y = flr(cam_pos.z/Chunk.TILE_SIZE+Camera.DRAW_DIST)
	local min_x = flr(cam_pos.x/Chunk.TILE_SIZE-Camera.DRAW_DIST)
	local max_x = flr(cam_pos.x/Chunk.TILE_SIZE+Camera.DRAW_DIST)

	for y = min_y,max_y do
		local y_arr = chunks[y]
		if y_arr then
			for x = min_x,max_x do
				local chunk = y_arr[x]
				if chunk then
					local model,mat = chunk.model,chunk.mat
					if Rendering.in_frustum(model,mat) then
						local depth = (vec(x,y)+0.5)*Chunk.TILE_SIZE-vec(cam_pos.x,cam_pos.z)
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
		if objects then
			for object in all(objects) do
				local drawer = object_drawers[object.id]
				if drawer then
					drawer(object.pos,get_height(object.pos.x,object.pos.y))
				end
			end
		end
		Rendering.draw_all()
	end
end

return {
	load = load,
	draw = draw,
}