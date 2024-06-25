--[[pod_format="raw",created="2024-06-04 05:42:45",modified="2024-06-25 21:58:13",revision=7075]]
local interps = {
	v = function(obj,ln)
		add(obj.v,vec(ln[2],ln[3],ln[4],1))
	end,
	vt = function(obj,ln)
		add(obj.vt,vec(ln[2],ln[3]))
	end,
	vn = function (obj,ln)
		add(obj.vn,vec(ln[2],ln[3],ln[4]))
	end,
	vp = function (obj,ln)
		add(obj.vp,vec(ln[2],ln[3],ln[4]))
	end,
	f = function (obj,ln)
		local f = {}
		
		for i = #ln,2,-1 do
			local indices = split(ln[i], "/")
			local v = {}
			
			v.v = indices[1]
			if indices[2] ~= "" then v.vt = indices[2] end
			v.vn = indices[3]
			
			add(f, v)
		end
		
		add(obj.f, f)
	end,
}

local function import(path,tex)
	local obj = {
		v = {},
		vt = {},
		vn = {},
		vp = {},
		f = {},
	}
	
	for l in all(split(fetch(path),"\n")) do
		local tokens = split(l," ")
		local interpreter = interps[tokens[1] ]
		if interpreter then interpreter(obj,tokens) end
	end
	
	local min_bound = vec(obj.v[1][0],obj.v[1][1],obj.v[1][2])
	local max_bound = min_bound:copy(min_bound)
	
	-- Get all vertices.
	local pts = userdata("f64",4,#obj.v)
	for i = 1,#obj.v do
		local v = obj.v[i]
		pts:set(0,i-1,v[0],v[1],v[2],v[3])
		min_bound = vec(
			min(min_bound.x,v[0]),
			min(min_bound.y,v[1]),
			min(min_bound.z,v[2])
		)
		max_bound = vec(
			max(max_bound.x,v[0]),
			max(max_bound.y,v[1]),
			max(max_bound.z,v[2])
		)
	end
	
	local cull_center = (min_bound+max_bound)*0.5
	local cull_radius = (max_bound-cull_center):magnitude()
	cull_center = vec(cull_center.x,cull_center.y,cull_center.z,1)
	
	-- Add 3 UVs, indices, and normals for every face.
	local uvs = userdata("f64",2,#obj.f*3)
	local indices = userdata("i64",3,#obj.f)
	local norms = userdata("f64",3,#obj.f)
	local face_dists = userdata("f64",#obj.f)
	for i = 1,#obj.f do
		local face = obj.f[i]
		local v1,v2,v3 = face[1],face[2],face[3]
		local normal = obj.vn[v1.vn]+obj.vn[v2.vn]+obj.vn[v3.vn]
		normal /= normal:magnitude()
		-- obj files are 1-indexed, but userdatas are 0-indexed.
		indices:set(0,i-1,(v1.v-1)*4,(v2.v-1)*4,(v3.v-1)*4)
		norms:set(0,i-1,normal[0],normal[1],normal[2])
		
		face_dists[i-1] = vec(pts:get(0,v1.v-1,3)):dot(normal)
		
		-- UVs are per-face rather than per-vertex.
		local y = (i-1)*3
		local uv1,uv2,uv3 = obj.vt[v1.vt],obj.vt[v2.vt],obj.vt[v3.vt]
		uvs:set(0,y  ,uv1[0],uv1[1])
		uvs:set(0,y+1,uv2[0],uv2[1])
		uvs:set(0,y+2,uv3[0],uv3[1])
	end
	uvs:sub(1,true,0,1,1,0,2,uvs:height())
	uvs:mul(vec(tex:width(),-tex:height()),true,0,0,2,0,2,uvs:height())

	return {
		pts = pts,
		uvs = uvs,
		indices = indices,
		tex = tex,
		norms = norms,
		face_dists = face_dists,
		cull_center = cull_center,
		cull_radius = cull_radius,
	}
end

return import