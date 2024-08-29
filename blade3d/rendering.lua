--[[pod_format="raw",created="2024-05-22 18:18:28",modified="2024-08-28 23:16:33",revision=18317]]
local Utils = require"blade3d.utils"
local sort = Utils.sort

local camera

local draw_queue = {}
local model_queue = {}


local function set_camera(cam)
	camera = cam
end

local function project_points(pts)
	local pts_height = pts:height()
	local inv_w = userdata("f64",pts_height)
	--userdata_op(u0, u1, u2, offset1, offset2, len, stride1, stride2, spans)
	inv_w:copy(1,true,0,0,1,1,1,pts_height)
	inv_w:div(pts,true,3,0,1,4,1,pts_height)
	
	pts:mul(inv_w,true,0,0,1,1,4,pts_height)
	pts:mul(inv_w,true,0,1,1,1,4,pts_height)
	pts:mul(inv_w,true,0,2,1,1,4,pts_height)
	pts:copy(inv_w,true,0,3,1,1,4,pts_height)
	
	return pts
end

local function project_point(pt)
	local w = 1/pt[3]
	pt = pt:mul(w,false,0,0,3)
	pt[3] = w
	return pt
end

local function clip_tris(model)
	local pts,uvs,indices,skip_tris,materials,depths =
		model.pts,model.uvs,model.indices,model.skip_tris,model.materials,model.depths
	local tri_clips = {}
	local quad_clips = {}
	for i = 0,indices:height()-1 do
		if not skip_tris[i] then
			local i1,i2,i3 = indices:get(0,i,3)
			local p1,p2,p3 =
				pts:row(i1),
				pts:row(i2),
				pts:row(i3)
			local w1,w2,w3 = p1[3],p2[3],p3[3]
			
			-- The near clipping plane is the only one that's actually clipped.
			-- Truncation is cheaper on the edges, and culling entire objects is
			-- cheaper than that.
			local n1,n2,n3 =
				p1.z > w1,
				p2.z > w2,
				p3.z > w3
			
			if (n1 and n2 and n3)
				or (p1.x < -w1 and p2.x < -w2 and p3.x < -w3)
				or (p1.x >  w1 and p2.x >  w2 and p3.x >  w3)
				or (p1.y < -w1 and p2.y < -w2 and p3.y < -w3)
				or (p1.y >  w1 and p2.y >  w2 and p3.y >  w3)
			then
				skip_tris[i] = true
			else
				if n1 or n2 or n3 then
					skip_tris[i] = true
					local iuv = i*3
					
					local uv1,uv2,uv3 =
						uvs:row(iuv),
						uvs:row(iuv+1),
						uvs:row(iuv+2)
					
					local outside = {} -- Refers to the clipping plane.
					local inside = {}
					add(n1 and inside or outside, {p1,uv1,1})
					add(n2 and inside or outside, {p2,uv2,2})
					add(n3 and inside or outside, {p3,uv3,3})
					
					if #inside == 1 then
						add(quad_clips,{outside[1],outside[2],inside[1],materials[i],depths[i]})
					else
						add(tri_clips,{outside[1],inside[1],inside[2],materials[i],depths[i]})
					end
				end
			end
		end
	end
	
	local gen_tri_count = #tri_clips+#quad_clips*2
	if gen_tri_count == 0 then return end
	
	local gen_vert_count = #tri_clips*3+#quad_clips*4
	
	local gen_pts = userdata("f64",4,gen_vert_count)
	local gen_uvs = userdata("f64",2,gen_tri_count*3)
	local gen_indices = userdata("i64",3,gen_tri_count)
	local gen_materials = {}
	local gen_depths = userdata("f64",gen_tri_count)
	
	local vert_i = 0
	local tri_i = 0
	for i = 1,#tri_clips do
		local verts = tri_clips[i]
		-- Fetch data
		local v1,v2,v3 = verts[1],verts[2],verts[3]
		
		-- The one case where the winding order as retreived is backwards.
		if v2[3] == 1 and v3[3] == 3 then
			v2,v3 = v3,v2
		end
		
		local p1,p2,p3 = v1[1],v2[1],v3[1]
		local uv1,uv2,uv3 = v1[2],v2[2],v3[2]
		
		-- Deltas are very useful for interpolation.
		local diff2,diff3 = p2-p1,p3-p1
		-- Oh yeah baby, ultra weird clip space inverse lerp math.
		-- Frankly, I don't think I understand it myself.
		local mul = p1.z-p1[3]
		local t2,t3 =
			mul/(diff2.z+diff2[3]),
			mul/(diff3.z+diff3[3])
		
		-- Lerp the new intersection vertices.
		p2,p3 = diff2*t2+p1,diff3*t3+p1
		gen_pts:set(0,vert_i,
			p1[0],p1[1],p1[2],p1[3],
			p2[0],p2[1],p2[2],p2[3],
			p3[0],p3[1],p3[2],p3[3]
		)
		
		uv2,uv3 = (uv2-uv1)*t2+uv1,(uv3-uv1)*t3+uv1
		gen_uvs:set(0,tri_i*3,
			uv1[0],uv1[1],
			uv2[0],uv2[1],
			uv3[0],uv3[1]
		)
		
		gen_indices:set(0,tri_i,vert_i,vert_i+1,vert_i+2)
		gen_materials[tri_i] = verts[4]
		gen_depths[tri_i] = verts[5]
		
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
		local mul = p3.z-p3[3]
		local t1,t2 =
			mul/(diff1.z+diff1[3]),
			mul/(diff2.z+diff2[3])
		
		-- If two vertices are outside, and two edges are clipped, that means there's
		-- four vertices, or a quad. This is represented with two traingles.
		local p4 = diff2*t2+p3
		p3 = diff1*t1+p3
		gen_pts:set(0,vert_i,
			p1[0],p1[1],p1[2],p1[3],
			p2[0],p2[1],p2[2],p2[3],
			p3[0],p3[1],p3[2],p3[3],
			p4[0],p4[1],p4[2],p4[3]
		)
		
		local uv4 = (uv2-uv3)*t2+uv3
		uv3 = (uv1-uv3)*t1+uv3
		gen_uvs:set(0,tri_i*3,
			uv1[0],uv1[1],
			uv2[0],uv2[1],
			uv3[0],uv3[1],
			
			uv3[0],uv3[1],
			uv2[0],uv2[1],
			uv4[0],uv4[1]
		)
		
		local i1,i2,i3,i4 = vert_i,vert_i+1,vert_i+2,vert_i+3
		gen_indices:set(0,tri_i,
			i1,i2,i3,
			i3,i2,i4
		)
		gen_materials[tri_i] = verts[4]
		gen_materials[tri_i+1] = verts[4]
		gen_depths[tri_i] = verts[5]
		gen_depths[tri_i+1] = verts[5]
		
		vert_i += 4
		tri_i += 2
	end
	
	return gen_pts,gen_uvs,gen_indices,gen_materials,gen_depths
end

local function draw_all()
	local screen_height = camera.target:height()
	set_draw_target(camera.target)
	local cts_mul = camera.cts_mul
	local cts_add = camera.cts_add
	
	for i = 1,#model_queue do
		local model = model_queue[i]
		local materials,pts,uvs,indices,skip_tris,depths =
			model.materials,model.pts,model.uvs,model.indices,model.skip_tris,model.depths
		profile("Near clipping")
		local gen_pts,gen_uvs,gen_indices,gen_materials,gen_depths = clip_tris(model)
		profile("Near clipping")
		
		profile("Projection")
		pts = project_points(pts:copy(pts))
		pts:mul(cts_mul,true,0,0,3,0,4,pts:height())
		pts:add(cts_add,true,0,0,3,0,4,pts:height())
		profile("Projection")
		
		profile("Model iteration")
		for j = 0,indices:height()-1 do
			if not skip_tris[j] then
				local it = j*3
				local p1,p2,p3 =
					pts:row(indices[it]),
					pts:row(indices[it+1]),
					pts:row(indices[it+2])
				
				local uv1,uv2,uv3 =
					uvs:row(it),
					uvs:row(it+1),
					uvs:row(it+2)
				
				local material = materials[j]
				local shader,properties = material.shader,material.properties
				
				add(draw_queue,{
					func = function() shader(properties,p1,p2,p3,uv1,uv2,uv3,screen_height) end,
					z = depths[j]
				})
			end
		end
		profile("Model iteration")
		
		if gen_indices then
			profile("Projection")
			gen_pts = project_points(gen_pts)
			profile("Projection")
			gen_pts:mul(cts_mul,true,0,0,2,0,4,gen_pts:height())
			gen_pts:add(cts_add,true,0,0,2,0,4,gen_pts:height())
			
			profile("Model iteration")
			for j = 0,gen_indices:height()-1 do
				local it = j*3
				local p1,p2,p3 =
					gen_pts:row(gen_indices[it]),
					gen_pts:row(gen_indices[it+1]),
					gen_pts:row(gen_indices[it+2])
				
				local uv1,uv2,uv3 =
					gen_uvs:row(it),
					gen_uvs:row(it+1),
					gen_uvs:row(it+2)
					
				local material = gen_materials[j]
				local shader,properties = material.shader,material.properties
				
				add(draw_queue,{
					func = function() shader(properties,p1,p2,p3,uv1,uv2,uv3,screen_height) end,
					z = gen_depths[j]
				})
			end
			profile("Model iteration")
		end
	end
    
	-- Sort the triangles by the average z of their vertices.
	profile("Z-sorting")
	sort(draw_queue,"z")
	profile("Z-sorting")
	-- Drop
	profile("Draw queue execution")
	for i = #draw_queue,1,-1 do
		draw_queue[i].func()
	end
	profile("Draw queue execution")
	
	-- Clear the queues.
	model_queue = {}
	draw_queue = {}
end

-- Draw requests

local function in_frustum(model,mat)
	profile("Model frustum culling")
	local cull_center = model.cull_center:matmul3d(mat:matmul3d(camera:get_view_matrix()))
	local cull_radius = model.cull_radius
	local depth = -cull_center.z
	
	local outside = depth < camera.near_plane-cull_radius
		or depth > camera.far_plane+cull_radius
		or vec(abs(cull_center.x),depth):dot(camera.frust_norm_x) > cull_radius
		or vec(abs(cull_center.y),depth):dot(camera.frust_norm_y) > cull_radius
	profile("Model frustum culling")
	return not outside
end

local function model(model,mat,imat)
	profile("Backface culling")
	local relative_cam_pos = camera.position:matmul3d(imat)
	local skip_tris = {}
	local face_dists = model.face_dists
	local dots = model.norms:matmul(userdata("f64",1,3):copy(relative_cam_pos,true))
	for i = 0,#face_dists-1 do
		skip_tris[i] = dots[i] < face_dists[i]
	end
	profile("Backface culling")
	
	local mvp = mat:matmul(camera:get_vp_matrix())
	local pts = model.pts:matmul(mvp)
	
	profile("Depth determination")
	local sorting_points = model.sorting_points
	local cam_sort_points = sorting_points:sub(relative_cam_pos,false,0,0,3,0,3,sorting_points:height())
	-- Square
	cam_sort_points:mul(cam_sort_points,true)
	
	-- Sum
	local cam_depths = userdata("f64",cam_sort_points:height())
	cam_depths:add(cam_sort_points,true,0,0,1,3,1,cam_sort_points:height())
	cam_depths:add(cam_sort_points,true,1,0,1,3,1,cam_sort_points:height())
	cam_depths:add(cam_sort_points,true,2,0,1,3,1,cam_sort_points:height())
	profile("Depth determination")
	
	add(model_queue,{
		pts = pts,
		uvs = model.uvs,
		indices = model.indices,
		tex = model.tex,
		skip_tris = skip_tris,
		materials = model.materials,
		depths = cam_depths
	})
	
	return true
end

local function line3d(p1,p2,col,mat)
	local mvp = mat:matmul(camera:get_vp_matrix())
	p1,p2 = p1:matmul(mvp),p2:matmul(mvp)
	if	   p1.z >  p1[3] or  p2.z >  p2[3]
		or p1.z < -p1[3] and p2.z < -p2[3]
		or p1.x >  p1[3] and p2.x >  p2[3]
		or p1.x < -p1[3] and p2.x < -p2[3]
		or p1.y >  p1[3] and p2.y >  p2[3]
		or p1.y < -p1[3] and p2.y < -p2[3]
	then return end
	p1,p2 =
		project_point(p1):mul(camera.cts_mul,true,0,0,3):add(camera.cts_add,true,0,0,3),
		project_point(p2):mul(camera.cts_mul,true,0,0,3):add(camera.cts_add,true,0,0,3)
	local z = (p1.z+p2.z)*0.5
	add(draw_queue,{
		func = function() line(p1.x,p1.y,p2.x,p2.y,col) end,
		z = z*z
	})
end

return {
	set_camera = set_camera,
	project_point = project_point,
	project_points = project_points,
	in_frustum = in_frustum,
	model = model,
	line = line3d,
	draw_all = draw_all,
}