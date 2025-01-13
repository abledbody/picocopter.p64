--[[pod_format="raw",created="2024-05-22 18:18:28",modified="2024-11-06 08:29:04",revision=18461]]
local Utils = require"blade3d.utils"
local sort = Utils.tab_sort
local quat = require"blade3d.quaternions"

---@class RenderCamera
local camera

local draw_queue = {}
local model_queue = {}

---Sets the camera to be used for rendering.
---@param cam RenderCamera
local function set_camera(cam)
	camera = cam
end

---Applies perspective division to a matrix of points.
local function perspective_points(pts)
	local pts_height = pts:height()

	-- Replace the w column with its reciprocals.
	pts.div(1,pts,true,0,3,1,0,4,pts_height)

    -- Unfortunately, we can't do a single operation which uses the same w
    -- twice, so we split it into X and Y.
	return pts:mul(pts,true,3,0,1,4,4,pts_height) -- X
		:mul(pts,true,3,1,1,4,4,pts_height) -- Y
end

---Applies perspective division to a single point.
local function perspective_point(pt)
	local w = 1/pt[3]
	pt = pt:mul(w,false,0,0,3)
	pt[3] = w
	return pt
end

---Takes a model in clip space, culls triangles that are outside the frustum,
---and clips triangles that intersect the near plane.
---@return table? @A new model containing every clipped triangle.
local function clip_tris(model)
	local pts,uvs,indices,
		skip_tris,materials,depths,lums =
			model.pts,model.uvs,model.indices,
			model.skip_tris,model.materials,model.depths,model.lums
	
	local tri_clips = {}
	local quad_clips = {}
	for i = 0,indices:height()-1 do
		if skip_tris[i] <= 0 then
			local i1,i2,i3 = indices:get(0,i,3)
			local p1,p2,p3 =
				pts:row(i1/4),
				pts:row(i2/4),
				pts:row(i3/4)
			local w1,w2,w3 = p1[3],p2[3],p3[3]
			
			-- The near clipping plane is the only one that's actually clipped.
			-- Truncation is cheaper on the edges, and culling entire triangles
			-- is cheaper than that.
			local n1,n2,n3 =
				p1.z < 0,
				p2.z < 0,
				p3.z < 0
			
			-- If all three vertices are behind a clipping plane, discard the
			-- triangle.
			if (n1 and n2 and n3)
				or (p1.x < -w1 and p2.x < -w2 and p3.x < -w3)
				or (p1.x >  w1 and p2.x >  w2 and p3.x >  w3)
				or (p1.y < -w1 and p2.y < -w2 and p3.y < -w3)
				or (p1.y >  w1 and p2.y >  w2 and p3.y >  w3)
			then
				skip_tris[i] = 1
				-- If all vertices are in front of the near plane,
				-- we don't need to clip.
			elseif n1 or n2 or n3 then
				
				-- Instead of modifying the existing triangle, we disable this
				-- one and provide a list of new generated ones.
				skip_tris[i] = 1
				local iuv = i*3
				
				-- UVs are per-triangle.
				local uv1,uv2,uv3 =
					uvs:row(iuv),
					uvs:row(iuv+1),
					uvs:row(iuv+2)
				
				-- "Inside" and "outside" referring to the frustum.
				local inside = {}
				local outside = {}
				-- By including the original index of the vertex, we can
				-- determine how to write the new vertices to maintain
				-- the winding order, even though we're scrambling the
				-- order so we know which ones are inside and outside.
				add(n1 and outside or inside, {p1,uv1,1})
				add(n2 and outside or inside, {p2,uv2,2})
				add(n3 and outside or inside, {p3,uv3,3})
				
				-- If two vertices are inside, and one is outside, the cut
				-- is an entirely new edge, so we need a quad. If only one
				-- is inside, the cut is essentially one of the existing
				-- edges. A slightly smaller triangle is enough.
				if #outside == 1 then
					add(
						quad_clips,
						{
							inside[1],inside[2],outside[1],
							materials[i],depths[i],lums and lums[i]
						}
					)
				else
					add(
						tri_clips,
						{
							inside[1],outside[1],outside[2],
							materials[i],depths[i],lums and lums[i]
						}
					)
				end
			end
		end
	end
	
	-- We know ahead of time how many triangles we need to generate, so these
	-- arrays can be made with a fixed size.
	local gen_tri_count = #tri_clips+#quad_clips*2
	if gen_tri_count == 0 then return end
	
	local gen_vert_count = #tri_clips*3+#quad_clips*4
	
	local gen_pts = userdata("f64",4,gen_vert_count)
	local gen_uvs = userdata("f64",2,gen_tri_count*3)
	local gen_indices = userdata("i32",3,gen_tri_count)
	local gen_materials = {}
	local gen_depths = userdata("f64",gen_tri_count)
	local gen_lums = lums and userdata("f64",gen_tri_count)
	
	-- vert_i and tri_i mutate differently for triangles and quads.
	local vert_i = 0
	local tri_i = 0
	for i = 1,#tri_clips do
		local verts = tri_clips[i]
		-- Fetch data. v1 is the inside vertex.
		local v1,v2,v3 = verts[1],verts[2],verts[3]
		
		-- The one case where the winding order as retreived is backwards.
		if v2[3] == 1 and v3[3] == 3 then
			v2,v3 = v3,v2
		end
		
		local p1,p2,p3 = v1[1],v2[1],v3[1]
		local uv1,uv2,uv3 = v1[2],v2[2],v3[2]
		
		-- Deltas are very useful for interpolation.
		local diff2,diff3 = p2-p1,p3-p1

		local t2,t3 =
			-p1.z/diff2.z,
			-p1.z/diff3.z
		
		-- Lerp to get the vertices at the clipping plane.
		p2,p3 = diff2*t2+p1,diff3*t3+p1
		uv2,uv3 = (uv2-uv1)*t2+uv1,(uv3-uv1)*t3+uv1
		
		gen_pts:set(0,vert_i,
			p1[0],p1[1],p1[2],p1[3],
			p2[0],p2[1],p2[2],p2[3],
			p3[0],p3[1],p3[2],p3[3]
		)
		gen_uvs:set(0,tri_i*3,
			uv1[0],uv1[1],
			uv2[0],uv2[1],
			uv3[0],uv3[1]
		)
		local i1 = vert_i*4
		gen_indices:set(0,tri_i,i1,i1+4,i1+8)
		
		-- Copy over the extra data from the original triangle.
		gen_materials[tri_i] = verts[4]
		gen_depths[tri_i] = verts[5]
		if lums then
			gen_lums[tri_i] = verts[6]
		end
		
		vert_i += 3
		tri_i += 1
	end
	
	for i = 1,#quad_clips do
		local verts = quad_clips[i]
		local v1,v2,v3 = verts[1],verts[2],verts[3]
		
		if v1[3] == 1 and v2[3] == 3 then
			v1,v2 = v2,v1
		end
		
		local p1,p2,p3 = v1[1],v2[1],v3[1]
		local uv1,uv2,uv3 = v1[2],v2[2],v3[2]
		
		local diff1,diff2 = p1-p3,p2-p3
		local t1,t2 =
			-p3.z/diff1.z,
			-p3.z/diff2.z
		
		-- We need to generate one extra vertex for the quad.
		local p4 = diff2*t2+p3
		local uv4 = (uv2-uv3)*t2+uv3
		
		p3 = diff1*t1+p3
		uv3 = (uv1-uv3)*t1+uv3
		
		gen_pts:set(0,vert_i,
			p1[0],p1[1],p1[2],p1[3],
			p2[0],p2[1],p2[2],p2[3],
			p3[0],p3[1],p3[2],p3[3],
			p4[0],p4[1],p4[2],p4[3]
		)
		gen_uvs:set(0,tri_i*3,
			uv1[0],uv1[1],
			uv2[0],uv2[1],
			uv3[0],uv3[1],
			
			uv3[0],uv3[1],
			uv2[0],uv2[1],
			uv4[0],uv4[1]
		)
		local i1 = vert_i*4
		local i2,i3,i4 = i1+4,i1+8,i1+12
		gen_indices:set(0,tri_i,
			i1,i2,i3,
			i3,i2,i4
		)
		
		gen_materials[tri_i] = verts[4]
		gen_materials[tri_i+1] = verts[4]
		gen_depths[tri_i] = verts[5]
		gen_depths[tri_i+1] = verts[5]
		if lums then
			gen_lums[tri_i] = verts[6]
			gen_lums[tri_i+1] = verts[6]
		end
		
		vert_i += 4
		tri_i += 2
	end
	
	return {
		pts = gen_pts,
		uvs = gen_uvs,
		indices = gen_indices,
		skip_tris = userdata("f64",gen_tri_count),
		materials = gen_materials,
		depths = gen_depths,
		lums = gen_lums
	}
end

local function draw_model(model,cts_mul,cts_add,screen_height)
	local pts,uvs,indices,skip_tris,materials,depths,lums =
			model.pts,model.uvs,model.indices,
			model.skip_tris,model.materials,model.depths,
			model.lums
	
	profile"Perspective"
	pts = perspective_points(pts:copy(pts))
		:mul(cts_mul,true,0,0,3,0,4,pts:height())
		:add(cts_add,true,0,0,3,0,4,pts:height())
	profile"Perspective"
	
	profile"Model iteration"
	local unpacked_verts = userdata("f64",6,#indices)
	pts:copy(indices,unpacked_verts,0,0,4,1,6,#indices)
	unpacked_verts:copy(uvs,true,0,4,2,2,6,uvs:height())
	
	for j = 0,indices:height()-1 do
		if skip_tris[j] <= 0 then
			local vert_data = userdata("f64",6,3)
				:copy(unpacked_verts,true,j*18,0,18)
			
			local material = materials[j]
			local props_in = setmetatable({light = lums and lums[j]},material)
			
			add(draw_queue,{
				func = function()
					material.shader(props_in,vert_data,screen_height)
				end,
				z = depths[j]
			})
		end
	end
	profile"Model iteration"
end

---Draws all render calls in the queue using the current camera.
local function draw_all()
	local screen_height = camera.target:height()
	set_draw_target(camera.target)
	local cts_mul = camera.cts_mul
	local cts_add = camera.cts_add
	
	-- Too expensive to concatenate all the triangles together.
	-- Iterating over the models and doing mass operations on their triangles
	-- is the compromise.
	for i = 1,#model_queue do
		local model = model_queue[i]
		
		
		profile"Frustum tests"
		local clipped_tris = clip_tris(model)
		profile"Frustum tests"
		
		draw_model(model,cts_mul,cts_add,screen_height)
		
		if clipped_tris then
			draw_model(clipped_tris,cts_mul,cts_add,screen_height)
		end
	end
    
	profile"Z-sorting"
	local sorted = sort(draw_queue,"z",true)
	profile"Z-sorting"
	for draw_command in sorted do
		draw_command.func()
	end
	
	model_queue = {}
	draw_queue = {}
end

---@param model table @The model to check.
---@param mat userdata @The model's transformation matrix.
---@return boolean @Whether the model intersects the frustum.
local function in_frustum(model,mat)
	profile"Model frustum culling"
	-- If we transform the cull center into camera space, the frustum
	-- becomes less mathematically complex to deal with.
	local cull_center = model.cull_center:matmul3d(
		mat:matmul3d(camera:get_view_matrix())
	)
	local cull_radius = model.cull_radius
	local depth = -cull_center.z
	
	-- Near and far plane are simple. They're just a depth check.
	local inside = depth > camera.near_plane-cull_radius
		and depth < camera.far_plane+cull_radius
		-- To determine the distance from the sides, we need to use the
		-- scalar rejection from the frustum planes.
		and vec(abs(cull_center.x),depth):dot(camera.frust_norm_x) < cull_radius
		and vec(abs(cull_center.y),depth):dot(camera.frust_norm_y) < cull_radius
	profile"Model frustum culling"
	return inside
end

---Queues a model for rendering.
---@param model table @The model to queue.
---@param mat userdata @The model's transformation matrix.
---@param imat userdata @The inverse of the model's transformation matrix.
---@param ambience? number @The ambient light intensity.
---@param light? userdata @The position of the light source.
---@param light_intensity? number @The intensity of the light source. If not provided, the light is assumed to be directional, and the intensity is the magnitude of the light vector.
local function queue_model(model,mat,imat,ambience,light,light_intensity)
	profile"Backface culling"
	local face_dists,norms = model.face_dists,model.norms
	local relative_cam_pos = camera.position:matmul3d(imat)
	
	-- Each face, in addition to a normal, has a length. This length is the
	-- the distance between the origin and the plane that the face sits on, and
	-- can be precomputed. The scalar projection of the camera onto the normal
	-- tells us how far along the normal the camera is from the origin. If this
	-- is less than the face's length, the camera is behind the face.
	
	-- Did you know that multiplying a matrix by a transposed vector is the same
	-- as performing a dot product between the matrix's rows and the vector?
	local dots = norms:matmul(relative_cam_pos:transpose())
	local skip_tris = face_dists-dots
	profile"Backface culling"
	
	local mvp = mat:matmul(camera:get_vp_matrix())
	-- Since the vertices are arranged in a 4xN matrix, we can transform all of
	-- them at once by multiplying it by the MVP matrix.
	local pts = model.pts:matmul(mvp)
	
	profile"Depth determination"
	-- Here we do a mass operation to determine the distance of each sorting
	-- point to the camera.
	local sorting_points = model.sorting_points
	local cam_sort_points = sorting_points:sub(
		relative_cam_pos,false,0,0,3,0,3,sorting_points:height()
	)
	-- Square the components.
	cam_sort_points:mul(cam_sort_points,true)
	
	-- Since this distance is only used in comparisons, we can cheap out and
	-- skip the square root.
	local depths = userdata("f64",cam_sort_points:height())
		:add(cam_sort_points,true,0,0,1,3,1,cam_sort_points:height()) -- X
		:add(cam_sort_points,true,1,0,1,3,1,cam_sort_points:height()) -- Y
		:add(cam_sort_points,true,2,0,1,3,1,cam_sort_points:height()) -- Z
	profile"Depth determination"
	
	profile"Lighting"
	local lums
	if light then
		-- For directional lights, the position needs to be stripped from the
		-- inverse matrix.
		local light_pos = light:matmul3d(
			light_intensity and imat or imat:copy(0,false,0,12,3)
		)
		local light_mag = light_pos:magnitude()+0.00001
		local illuminance = light_intensity
			and light_intensity/(light_mag*light_mag) -- Inverse square falloff
			or light_mag
		
		lums = norms:matmul((light_pos/light_mag):transpose()):max(0) -- Normal contribution
			*illuminance -- Intensity
		if ambience then
			lums += ambience -- Ambient light
		end
	elseif ambience then
		lums = userdata("f64",norms:height())
			:copy(ambience,true,0,0,1,0,1,norms:height())
	end
	profile"Lighting"
	
	-- The model's data has been, and will be, aggressively mutated, so a new one
	-- gets created to isolate side effects.
	add(model_queue,{
		pts = pts,
		uvs = model.uvs,
		indices = model.indices,
		tex = model.tex,
		skip_tris = skip_tris,
		materials = model.materials,
		depths = depths,
		lums = lums,
	})
	
	return true
end

---Queues a point for rendering.
---@param p userdata @The coordinates of the point.
---@param col integer @The color of the point.
---@param mat userdata @The point's transformation matrix.
local function queue_point(p,col,mat)
	profile"Point queueing"
	p = p:matmul(mat)
	
	local relative_cam_pos = p-camera.position
	local depth = relative_cam_pos:dot(relative_cam_pos)
	
	p = p:matmul(camera:get_vp_matrix())
	
	if	   p.z >  p[3]
		or p.z < -p[3]
	then return end

	p = perspective_point(p)
		:mul(camera.cts_mul,true,0,0,3)
		:add(camera.cts_add,true,0,0,3),
	
	add(draw_queue,{
		func = function() pset(p.x,p.y,col) end,
		z = depth
	})
	profile"Point queueing"
end

---Queues multiple points for rendering.
---@param pts userdata @4xN userdata of point coordinates.
---@param col integer @The color of the points.
---@param mat userdata @The point's transformation matrix.
---@param midpoint? userdata @The coodinate used for calculating the depth for sorting. Otherwise calculates depth per point.
local function queue_points(pts,col,mat,midpoint)
	profile"Point queueing"
	local pmodel = pts:matmul(mat)
	local ph = pmodel:height()
	local depth = 1
	
	local p = pmodel:matmul(camera:get_vp_matrix())
	
	profile"Frustum tests"
	for i = 0, ph-1 do
		local pt = p:row(i)
		
		-- The other axes are actually not worth culling, too expensive.
		if 	   pt.z >  pt[3]
			or pt.z < -pt[3]  then
			-- Yup, just get that out of the way.
			p:set(0,i,1,0,0,1)
		end
	end	
	profile"Frustum tests"

	p = perspective_points(p:copy(p))
		:mul(camera.cts_mul,true,0,0,3,0,4,ph)
		:add(camera.cts_add,true,0,0,3,0,4,ph)

	if midpoint then
		local relative_cam_pos = midpoint-camera.position
		depth = relative_cam_pos:dot(relative_cam_pos)

		local draws = userdata("f64",3,ph)
			:copy(p,true,0,0,2,4,3,ph)
			:copy(col,true,0,2,1,0,3,ph)
		
		add(draw_queue,{
			func = function()
				pset(draws)
			end,
			z = depth
		})
	else
		local relative_cam_pos = pmodel:sub(camera.position,false,0,0,3,0,4,ph)
		relative_cam_pos:mul(relative_cam_pos,true,0,0,3,4,4,ph)
		local depths = userdata("f64",ph) -- Sum of squares
			:copy(relative_cam_pos,true,0,0,1,4,1,ph)
			:add(relative_cam_pos,true,1,0,1,4,1,ph)
			:add(relative_cam_pos,true,2,0,1,4,1,ph)

		for i = 0,ph-1 do
			local pt = p:row(i)

			add(draw_queue,{
				func = function()
					pset(pt.x,pt.y,col)
				end,
				z = depths[i]
			})
		end
	end

	profile"Point queueing"
end

---Queues a line for rendering.
---@param p1 userdata @The first point of the line.
---@param p2 userdata @The second point of the line.
---@param col integer @The color of the line.
---@param mat userdata @The line's transformation matrix.
local function queue_line(p1,p2,col,mat)
	p1,p2 = p1:matmul(mat),p2:matmul(mat)
	
	local relative_cam_pos = (p1+p2)*0.5-camera.position
	local depth = relative_cam_pos:dot(relative_cam_pos)
	
	local vp = camera:get_vp_matrix()
	p1,p2 = p1:matmul(vp),p2:matmul(vp)
	
	if	   p1.z >  p1[3] and p2.z >  p2[3]
		or p1.z < -p1[3] and p2.z < -p2[3]
		or p1.x >  p1[3] and p2.x >  p2[3]
		or p1.x < -p1[3] and p2.x < -p2[3]
		or p1.y >  p1[3] and p2.y >  p2[3]
		or p1.y < -p1[3] and p2.y < -p2[3]
	then return end
	
	if p1.z >  p1[3] or  p2.z > p2[3] then
		-- We'll call the point behind the camera p2.
		if p1.z < p2.z then
			p1, p2 = p2, p1
		end
		
		local diff2 = p2-p1
		p2 = diff2*(p1.z-p1[3])/(diff2.z+diff2[3])+p1
	end

	p1,p2 =
		perspective_point(p1)
			:mul(camera.cts_mul,true,0,0,3)
			:add(camera.cts_add,true,0,0,3),
		perspective_point(p2)
			:mul(camera.cts_mul,true,0,0,3)
			:add(camera.cts_add,true,0,0,3)
	
	add(draw_queue,{
		func = function() line(p1.x,p1.y,p2.x,p2.y,col) end,
		z = depth
	})
end

local function queue_billboard(pt,material,ambience,light,light_intensity)
	local relative_cam_pos = pt-camera.position
	
	pt = perspective_point(pt:matmul(camera:get_vp_matrix()))
	
	if pt.z > pt[3] or pt.z < -pt[3] then return end
	
	local depth = relative_cam_pos:dot(relative_cam_pos)
	
	local props = setmetatable({},material)
	if light then
		local light_mag = light:magnitude()+0.00001
		local illuminance = light_intensity
			and light_intensity/(light_mag*light_mag) -- Inverse square falloff
			or light_mag
		
		local relative_dir = relative_cam_pos/-relative_cam_pos:magnitude()
		
		local lum = relative_dir:dot(light/light_mag)
		props.light = (lum > 0 and lum or 0)
			*illuminance
			+ambience
	elseif ambience then
		props.light = ambience
	end
	
	props.size *= pt[3]*camera.target:height()*0.5 --NDC spans -1 to 1.
	pt:mul(camera.cts_mul,true,0,0,3)
		:add(camera.cts_add,true,0,0,3)
	
	add(draw_queue,{
		func = function() material.shader(props,pt) end,
		z = depth
	})
end

return {
	set_camera = set_camera,
	perspective_point = perspective_point,
	perspective_points = perspective_points,
	in_frustum = in_frustum,
	queue_model = queue_model,
	queue_point = queue_point,
	queue_points = queue_points,
	queue_line = queue_line,
	queue_billboard = queue_billboard,
	draw_all = draw_all,
}