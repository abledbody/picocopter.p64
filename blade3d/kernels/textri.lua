---Draws a 3D textured triangle to the screen. Note that the vertices need W components,
---and that they need to be the reciprocal of the W which is produced by the projection matrix.
---This step is typically done in the perspective division step.
---@param tex userdata The texture to draw with.
---@param p1 userdata The XYZW coordinates of the first vertex.
---@param p2 userdata The XYZW coordinates of the second vertex.
---@param p3 userdata The XYZW coordinates of the third vertex.
---@param uv1 userdata The UV texture coordinates of the first vertex.
---@param uv2 userdata The UV texture coordinates of the second vertex.
---@param uv3 userdata The UV texture coordinates of the third vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(tex,p1,p2,p3,uv1,uv2,uv3,screen_height)
	profile"Triangle setup"
	
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
	
	-- Since the y components are used extensively, we'll store them in
	-- local variables. Not sure I can justify doing the same for w.
	local y1,y2,y3,w1,w2,w3 = p1.y,p2.y,p3.y,p1[3],p2[3],p3[3]
	
	-- To get perspective correct interpolation, we need to multiply
	-- the UVs by the w component of their vertices.
	uv1 *= w1
	uv2 *= w2
	uv3 *= w3
	
	-- The only components that need to be extrapolated per row are XUVW.
	local v1,v2,v3 = 
		vec(p1.x,uv1.x,uv1.y,w1),
		vec(p2.x,uv2.x,uv2.y,w2),
		vec(p3.x,uv3.x,uv3.y,w3)
	
	-- The major slope is the same from the topmost to bottommost vertex.
	-- It is defined as the run over the rise of the first and last vertices.
	-- Note that this could be nil if y1 == y3. That's fine, we just can't
	-- use it for any operations.
	local major_slope = (v3-v1)/(y3-y1)
	
	-- First we do y1 to y2.
	local dy = y2-y1
	
	-- To make iteration as cheap as possible, we calculate the rate of
	-- change ahead of time, instead of interpolating values per row.
	-- If dy < 1, it's pointless to use the slope, could result in
	-- division by zero, and may ultimately crash Picotron.
	local slopes = userdata("f64",8)
	if dy >= 1 then
		slopes:copy(major_slope,true)
		slopes:copy((v2-v1)/dy,true,0,4)
	end
	
	-- Here we truncate the scanlines so we don't iterate where lines
	-- can't be drawn. Note that tline3d already truncates the columns,
	-- but we are responsible for iterating over the rows.
	local y = y1 > 0 and ceil(y1) or 0
	local y_end = y2 < screen_height and y2 or screen_height
	
	-- This gets indexed a lot, so e is shorthand for "edges".
	local e = userdata("f64",8)
	-- The edges meet at p1, so we copy the values from v1 twice.
	e:copy(v1,true,0,0,4,0,4,2)
	-- There's always a difference between y and y1, since y1 pretty
	-- much never lies exactly on a drawable scanline. To compensate,
	-- we move down the slopes to where there is one.
	e:add(slopes*(y-y1),true)
	profile"Triangle setup"
	
	profile"Triangle iteration"
	-- And now, we iterate over the rows, until reaching y2.
	while y < y_end do
		tline3d(tex,e[0],y,e[4],y,e[1],e[2],e[5],e[6],e[3],e[7],0x100)
		e:add(slopes,true)
		y += 1
	end
	profile"Triangle iteration"
	
	profile"Triangle setup"
	-- Now we do y2 to y3.
	dy = y3-y2
	if dy >= 1 then
		-- We need to re-copy major slope, in case it wasn't done before.
		slopes:copy(major_slope,true)
		-- We need the new slope for the minor side.
		slopes:copy((v3-v2)/dy,true,0,4)
	else
		-- There could still be data in the slopes array from the last
		-- iteration, so we zero it out.
		slopes:mul(0,true)
	end
	
	y_end = y3 < screen_height and ceil(y3) or screen_height
	
	-- Since this part of the triangle has width, we need to set both
	-- edges individually. The major side is calculated backwards from
	-- p3, just because that's the dy we have at the moment.
	e:copy(v3-major_slope*dy,true)
	e:copy(v2,true,0,4)
	e:add(slopes*(y-y2),true)
	profile"Triangle setup"
	
	profile"Triangle iteration"
	while y < y_end do
		tline3d(tex,e[0],y,e[4],y,e[1],e[2],e[5],e[6],e[3],e[7],0x100)
		e:add(slopes,true)
		y += 1
	end
	profile"Triangle iteration"
end