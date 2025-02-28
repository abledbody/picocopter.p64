local TILE_SIZE = 32

local Transform = require"blade3d.transform"
local import_ptm = require"blade3d.ptm_importer"
local materials = require"materials"

local t_pt_indices = userdata("i32",3,2)
t_pt_indices:set(0,0,
	0,1,2,
	1,3,2
)
local t_uvs = userdata("f64",2,4)
t_uvs:set(0,0,
	0,0,
	1,0,
	1,1,
	0,1
)

local t_uv_indices = {
	userdata("i32",3,2),
	userdata("i32",3,2),
	userdata("i32",3,2),
	userdata("i32",3,2),
}
t_uv_indices[1]:set(0,0,
	0,1,3,
	1,2,3
)
t_uv_indices[2]:set(0,0,
	1,2,0,
	2,3,0
)
t_uv_indices[3]:set(0,0,
	2,3,1,
	3,0,1
)
t_uv_indices[4]:set(0,0,
	3,0,2,
	0,1,2
)

local t_mat_indices = userdata("i32",2)
t_mat_indices:set(0,1,1)

local function new(model,coord,y,objects)
	coord *= TILE_SIZE
	local mat,imat = Transform.double_translate(vec(coord.x,y*TILE_SIZE,coord.y))

	return {
		model = model,
		mat = mat,
		imat = imat,
		objects = objects
	}
end

local function terrain_model(material,ne,sw,se,rotation)
	local pts = userdata("f64",4,4)
	pts:set(0,0,
		        0,           0,        0,1,
		TILE_SIZE,ne*TILE_SIZE,        0,1,
		        0,sw*TILE_SIZE,TILE_SIZE,1,
		TILE_SIZE,se*TILE_SIZE,TILE_SIZE,1
	)

	rotation = rotation or 1
	local uv_indices = t_uv_indices[(rotation-1)%4+1]
	
	return import_ptm(
		{
			pts=pts,
			uvs=t_uvs,
			materials={material},
			
			pt_indices=t_pt_indices,
			uv_indices=uv_indices,
			material_indices=t_mat_indices
		},
		materials
	)
end

return {
	TILE_SIZE = TILE_SIZE,
	new = new,
	terrain_model = terrain_model,
}