--[[pod_format="raw",created="2024-06-04 05:42:45",modified="2024-06-26 22:47:36",revision=7478]]
return function(path,material_lookup)
	local pcm_model = unpod(fetch(path))
	
	local pcm_pts,pcm_uvs,pcm_mats =
		pcm_model.pts,pcm_model.uvs,pcm_model.materials
	local pt_indices,uv_indices =
		pcm_model.pt_indices,pcm_model.uv_indices
	
	-- .pcm file indices refer to matrix rows, but flat indices are faster
	-- and more convenient for userdata operations.
	local indices = pt_indices*4
	uv_indices *= 2
	
	-- Calculate the AABB and create a sphere which encompasses it.
	-- This is used for efficient frustum culling.
	-- Ideally this would be the minimum bounding sphere, but that's
	-- a lot harder to calculate.
	local min_bound = vec(pcm_pts[0],pcm_pts[1],pcm_pts[2])
	local max_bound = min_bound:copy(min_bound)
	
	for i = 0,(pcm_pts:height()-1)*4,4 do
		local x,y,z = pcm_pts[i],pcm_pts[i+1],pcm_pts[i+2]
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
		uvs:copy(pcm_uvs,true,uv_indices[ir],iw,2)
	end
	
	-- Actualize materials from their names, and calculate normals,
	-- face distances, and sorting points.
	local materials = {}
	local norms = userdata("f64",3,tri_count)
	local face_dists = userdata("f64",tri_count)
	local sorting_points = userdata("f64",3,tri_count)
	
	for i = 0,tri_count-1 do
		local mat_name = pcm_mats[i+1]
		local mtl = material_lookup[mat_name]
		assert(mtl,"Could not find material "..mat_name)
		
		-- Transform uvs if the material uses a texture property,
		-- because picotron uses texel coordinates, not normalized coordinates.
		local tex = mtl.properties.tex
		if tex then
			uvs:mul(vec(tex:width(),tex:height()),true,0,i*6,2,0,2,3)
		end
		
		materials[i] = mtl
		
		-- Truncate the points to 3 dimensions. We're not in 4D just yet.
		local p1,p2,p3 =
			userdata("f64",3):copy(pcm_pts,true,indices[i*3  ],0,3),
			userdata("f64",3):copy(pcm_pts,true,indices[i*3+1],0,3),
			userdata("f64",3):copy(pcm_pts,true,indices[i*3+2],0,3)
		
		-- pcm does not come with pre-baked normals to save space.
		local norm = (p3-p1):cross(p2-p1)
		norm:div(norm:magnitude(),true)
		norms:copy(norm,true,0,i*3,3)
		
		-- All three points are on the plane defined by the three points,
		-- duh, so any point will do.
		face_dists[i] = p1:dot(norm)
		
		sorting_points:copy((p1+p2+p3)/3,true,0,i*3,3)
	end
	
	return {
		materials = materials,
		pts = pcm_pts,
		indices = indices,
		cull_center = cull_center,
		cull_radius = cull_radius,
		uvs = uvs,
		norms = norms,
		face_dists = face_dists,
		sorting_points = sorting_points,
	}
end