local scanlines = userdata("f64",5,270)

---Draws a solid color triangle to the screen.
---@param props table The properties passed to the shader. Expects a `col` field with a color index.
---@param vert_data userdata A 6x3 matrix where each row is the xyzwuv of a vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(props,vert_data,screen_height)
	profile"Triangle setup"
	local col = props.col
	
	-- To make it so that rasterizing top to bottom is always correct,
	-- and so that we know at which point to switch the minor side's slope,
	-- we need the vertices to be sorted by y.
	vert_data:sort(1)
	
	-- These values are used extensively in the setup, so we'll store them in
	-- local variables.
	local x1,y1, y2, x3,y3 = 
		vert_data[0],vert_data[1],
		vert_data[7],
		vert_data[12],vert_data[13]
	
	local v1,v2 = 
		vec(x1,y1,x1,y1,col),
		vec(
			vert_data[6],y2,
			(x3-x1)*(y2-y1)/(y3-y1)+x1, y2,
			col
		)
	profile"Triangle setup"
	
	profile"Triangle drawing"
	local start_y = y1 < -1 and -1 or y1\1
	local mid_y = y2 < -1 and -1 or y2 > screen_height-1 and screen_height-1 or y2\1
	local stop_y = (y3 <= screen_height-1 and y3\1 or screen_height-1)
	
	-- Top half
	local dy = mid_y-start_y
	if dy > 0 then
		local slope = (v2-v1)/(y2-y1)
		
		scanlines:copy(slope*(start_y+1-y1)+v1,true,0,0,5)
			:copy(slope,true,0,5,5,0,5,dy-1)
		
		rectfill(scanlines:add(scanlines,true,0,5,5,5,5,dy-1),0,dy)
	end
	
	-- Bottom half
	dy = stop_y-mid_y
	if dy > 0 then
		-- This is, otherwise, the only place where v3 would be used,
		-- so we just inline it.
		local slope = (vec(x3,y3,x3,y3,col)-v2)/(y3-y2)
		
		scanlines:copy(slope*(mid_y+1-y2)+v2,true,0,0,5)
			:copy(slope,true,0,5,5,0,5,dy-1)
		
		rectfill(scanlines:add(scanlines,true,0,5,5,5,5,dy-1),0,dy)
	end
	profile"Triangle drawing"
end