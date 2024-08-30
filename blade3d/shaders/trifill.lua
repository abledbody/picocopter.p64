---Draws a solid color triangle to the screen.
---@param col number The color index to draw with.
---@param p1 userdata The XY coordinates of the first vertex.
---@param p2 userdata The XY coordinates of the second vertex.
---@param p3 userdata The XY coordinates of the third vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(col,p1,p2,p3,uv1,uv2,uv3,screen_height)
	profile"Triangle setup"
	
	-- To make it so that rasterizing top to bottom is always correct,
	-- and so that we know at which point to switch the minor side's slope,
	-- we need the vertices to be sorted by y.
	if p1.y > p2.y then
		p1,p2 = p2,p1
	end
	if p2.y > p3.y then
		p2,p3 = p3,p2
	end
	if p1.y > p2.y then
		p1,p2 = p2,p1
	end
	
	-- We'll extract the x and y components to make operations cheaper.
	local y1,y2,y3,x1,x2,x3 = p1.y,p2.y,p3.y,p1.x,p2.x,p3.x
	
	-- The major slope is the same from the topmost to bottommost vertex.
	-- It is defined as the run over the rise of the first and last vertices.
	-- Note that this could be nil if y1 == y3. That's fine, we just can't
	-- use it for any operations.
	local major_slope = (x3-x1)/(y3-y1)
	
	-- First we do y1 to y2.
	local dy = y2-y1
	
	-- To make iteration as cheap as possible, we calculate the rate of
	-- change ahead of time, instead of interpolating values per row.
	-- If dy < 1, it's pointless to use the slope, could result in
	-- division by zero, and may ultimately crash Picotron.
	local slopes = userdata("f64",2)
	if dy >= 1 then
		slopes[0] = major_slope
		slopes[1] = (x2-x1)/dy
	end
	
	-- Here we truncate the scanlines so we don't iterate where lines
	-- can't be drawn. Note that tline3d already truncates the columns,
	-- but we are responsible for iterating over the rows.
	local y = y1 > 0 and ceil(y1) or 0
	local y_end = y2 < screen_height and y2 or screen_height
	
	-- The edges meet at p1.
	local edges = vec(x1,x1)
	-- There's always a difference between y and y1, since y1 pretty
	-- much never lies exactly on a drawable scanline. To compensate,
	-- we move down the slopes to where there is one.
	edges:add(slopes*(y-y1),true)
	profile"Triangle setup"
	
	profile"Triangle iteration"
	-- And now, we iterate over the rows, until reaching y2.
	while y < y_end do
		-- We use rectfill because it's cheaper than line.
		rectfill(edges[0],y,edges[1],y,col)
		y += 1
		edges:add(slopes,true)
	end
	profile"Triangle iteration"
	
	profile"Triangle setup"
	-- Now we do y2 to y3.
	dy = y3-y2
	if dy >= 1 then
		-- We need to re-copy major slope, in case it wasn't done before.
		slopes[0] = major_slope
		-- We need the new slope for the minor side.
		slopes[1] = (x3-x2)/dy
	else
		-- There could still be data in the slopes array from the last
		-- iteration, so we zero it out.
		slopes:mul(0,true)
	end
	
	y_end = y3 < screen_height and ceil(y3) or screen_height
	
	-- Since this part of the triangle has width, we need to set both
	-- edges individually. The major side is calculated backwards from
	-- p3, just because that's the dy we have at the moment.
	edges[0] = x3-major_slope*dy
	edges[1] = x2
	edges:add(slopes*(y-y2),true)
	profile"Triangle setup"
	
	profile"Triangle iteration"
	while y < y_end do
		rectfill(edges[0],y,edges[1],y,col)
		edges:add(slopes,true)
		y += 1
	end
	profile"Triangle iteration"
end