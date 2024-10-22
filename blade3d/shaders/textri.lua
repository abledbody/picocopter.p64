---Draws a 3D textured triangle to the screen. Note that the vertices need W components,
---and that they need to be the reciprocal of the W which is produced by the projection matrix.
---This step is typically done in the perspective division step.
---@param props table The properties passed to the shader. Expects a `tex` field with a texture index.
---@param p1 userdata The XYZW coordinates of the first vertex.
---@param p2 userdata The XYZW coordinates of the second vertex.
---@param p3 userdata The XYZW coordinates of the third vertex.
---@param uv1 userdata The UV texture coordinates of the first vertex.
---@param uv2 userdata The UV texture coordinates of the second vertex.
---@param uv3 userdata The UV texture coordinates of the third vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(props,p1,p2,p3,uv1,uv2,uv3,screen_height)
	profile"Triangle drawing"
	local spr = props.tex
	
	-- To make it so that rasterizing top to bottom is always correct,
	-- and so that we know at which point to switch the minor side's slope,
	-- we need the vertices to be sorted by y.
	if p1.y > p2.y then
		p1,p2,uv1,uv2 = p2,p1,uv2,uv1
	end
	if p2.y > p3.y then
		p2,p3,uv2,uv3 = p3,p2,uv3,uv2
	end
	if p1.y > p2.y then
		p1,p2,uv1,uv2 = p2,p1,uv2,uv1
	end
	
	-- Since the y and w components are used extensively, we'll store them in
	-- local variables.
	local y1,y2,y3,w1,w2,w3 = p1.y,p2.y,p3.y,p1[3],p2[3],p3[3]
	
	-- To get perspective correct interpolation, we need to multiply
	-- the UVs by the w component of their vertices.
	uv1 *= w1
	uv2 *= w2
	uv3 *= w3
	
	local t = (y2-y1)/(y3-y1)
	local uvd = (uv3-uv1)*t+uv1
	local v1,v2 = 
		vec(spr,p1.x,y1,p1.x,y1,uv1.x,uv1.y,uv1.x,uv1.y,w1,w1),
		vec(
			spr,
			p2.x,y2,
			(p3.x-p1.x)*t+p1.x, y2,
			uv2.x,uv2.y,
			uvd.x,uvd.y,
			w2, (w3-w1)*t+w1
		)
	
	local start_y = y1 > 0 and y1\1 or 0
	local mid_y = y2 < 0 and 0 or y2 > screen_height and screen_height or y2\1
	local stop_y = (y3 <= screen_height and y3\1 or screen_height)
	
	-- Top half
	local dy = mid_y-start_y
	if dy > 0 then
		local slope = (v2-v1)/(y2-y1)
		
		local scanlines = userdata("f64",11,dy)
			:copy(slope*(start_y+1-y1)+v1,true,0,0,11)
			:copy(slope,true,0,11,11,0,11,dy-1)
		
		tline3d(scanlines:add(scanlines,true,0,11,11,11,11,dy-1))
	end
	
	-- Bottom half
	dy = stop_y-mid_y
	if dy > 0 then
		-- This is, otherwise, the only place where v3 would be used,
		-- so we just inline it.
		local slope = (vec(spr,p3.x,y3,p3.x,y3,uv3.x,uv3.y,uv3.x,uv3.y,w3,w3)-v2)/(y3-y2)
		local scanlines = userdata("f64",11,dy)
			:copy(slope*(mid_y+1-y2)+v2,true,0,0,11)
			:copy(slope,true,0,11,11,0,11,dy-1)
			
		tline3d(scanlines:add(scanlines,true,0,11,11,11,11,dy-1))
	end
	profile"Triangle drawing"
end