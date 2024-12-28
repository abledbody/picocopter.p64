--[[pod_format="raw",created="2024-06-04 05:42:45",modified="2024-08-30 04:00:01",revision=9598]]

---Shaders draw triangles to the screen. If properties is a userdata or a table that contains a tex property, the UVs will be transformed to texel coordinates.
---@alias Shader fun(properties:any,p1:userdata,p2:userdata,p3:userdata,uv1:userdata,uv2:userdata,uv3:userdata,screen_height:number)

---@class Material
---@field shader Shader The shader to use for rendering.
---@field __index table? The properties passed to the shader.

---@alias MaterialLookup table<string,Material>

---Loads and preprocesses a ptm file for use in Blade3D.
---@param path string|table The path to the ptm file, or the ptm model itself.
---@param material_lookup MaterialLookup A table of materials to use for the model. Keys should match the material names in the ptm file.
---@return PtmModel @The processed model.
return function(path,material_lookup)
	local ptm_model
	if type(path) == "string" then
		ptm_model = unpod(fetch(path))
	else
		ptm_model = path
	end
	
	local ptm_pts,ptm_uvs,ptm_mats =
		ptm_model.pts,ptm_model.uvs,ptm_model.materials
	local pt_indices,uv_indices,mat_indices =
		ptm_model.pt_indices,ptm_model.uv_indices,ptm_model.material_indices
	
	-- .pcm file indices refer to matrix rows, but flat indices are faster
	-- and more convenient for userdata operations.
	uv_indices *= 2
	pt_indices *= 4
	
	-- Calculate the AABB and create a sphere which encompasses it.
	-- This is used for efficient frustum culling.
	-- Ideally this would be the minimum bounding sphere, but that's
	-- a lot harder to calculate.
	local min_bound = vec(ptm_pts[0],ptm_pts[1],ptm_pts[2])
	local max_bound = min_bound:copy(min_bound)
	
	for i = 0,(ptm_pts:height()-1)*4,4 do
		local x,y,z = ptm_pts[i],ptm_pts[i+1],ptm_pts[i+2]
		min_bound = vec(
			min(min_bound.x,x),
			min(min_bound.y,y),
			min(min_bound.z,z)
		)
		max_bound = vec(
			max(max_bound.x,x),
			max(max_bound.y,y),
			max(max_bound.z,z)
		)
	end
	
	local cull_center = (min_bound+max_bound)*0.5
	local cull_radius = (max_bound-cull_center):magnitude()
	cull_center = vec(cull_center.x,cull_center.y,cull_center.z,1)

	local tri_count = pt_indices:height()
	
	-- Actualize uvs
	local uvs = userdata("f64",2,tri_count*3)
	for ir = 0,uvs:height()-1 do
		local iw = ir*2
		uvs:copy(ptm_uvs,true,uv_indices[ir],iw,2)
	end
	
	-- Actualize materials from their names, and calculate normals,
	-- face distances, and sorting points.
	local materials = {}
	local norms = userdata("f64",3,tri_count)
	local face_dists = userdata("f64",tri_count)
	local sorting_points = userdata("f64",3,tri_count)
	
	for i = 0,tri_count-1 do
		local mat_name = ptm_mats[mat_indices[i]]
		local mtl = material_lookup[mat_name]
		assert(mtl,"Could not find material "..mat_name)
		
		-- Transform uvs if the material uses a texture property,
		-- because picotron uses texel coordinates, not normalized coordinates.
		if mtl.__index and mtl.__index.tex then
			local tex = get_spr(mtl.__index.tex)
			uvs:mul(vec(tex:width(),tex:height()),true,0,i*6,2,0,2,3)
		end
		
		materials[i] = mtl
		
		-- Truncate the points to 3 dimensions. We're not in 4D just yet.
		local p1,p2,p3 =
			userdata("f64",3):copy(ptm_pts,true,pt_indices[i*3  ],0,3),
			userdata("f64",3):copy(ptm_pts,true,pt_indices[i*3+1],0,3),
			userdata("f64",3):copy(ptm_pts,true,pt_indices[i*3+2],0,3)
		
		-- pcm does not come with pre-baked normals to save space.
		local norm = (p3-p1):cross(p2-p1)
		norm:div(norm:magnitude(),true)
		norms:copy(norm,true,0,i*3,3)
		
		-- All three points are on the plane defined by the three points,
		-- duh, so any point will do.
		face_dists[i] = p1:dot(norm)
		
		sorting_points:copy((p1+p2+p3)/3,true,0,i*3,3)
	end
	
	---@class PtmModel
	---@field materials table<number,Material> A table of materials used in the model.
	---@field pts userdata A 4xN matrix of points.
	---@field indices userdata A 3x3N matrix of point indices.
	---@field cull_center userdata The center of the model's bounding sphere.
	---@field cull_radius number The radius of the model's bounding sphere.
	---@field uvs userdata A 2x3N matrix of UV coordinates.
	---@field norms userdata A 3xN matrix of normals.
	---@field face_dists userdata An N-length array of distances from the origin to the planes of each face.
	return {
		materials = materials,
		pts = ptm_pts,
		indices = pt_indices,
		cull_center = cull_center,
		cull_radius = cull_radius,
		uvs = uvs,
		norms = norms,
		face_dists = face_dists,
		sorting_points = sorting_points,
	}
end