---Draws a solid color triangle to the screen.
---@param col number The color index to draw with.
---@param p1 userdata The XY coordinates of the first vertex.
---@param p2 userdata The XY coordinates of the second vertex.
---@param p3 userdata The XY coordinates of the third vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(col,p1,p2,p3,_,_,_,screen_height)
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
	
	-- Since the y components are used extensively, we'll store them in
	-- local variables.
	local y1,y2,y3 = p1.y,p2.y,p3.y
	
	local v1,v2 = 
		vec(p1.x,p1.y,p1.x,p1.y,col),
		vec(
			p2.x,p2.y,
			(p3.x-p1.x)*(p2.y-p1.y)/(p3.y-p1.y)+p1.x, p2.y,
			col
		)
	profile"Triangle setup"
	
	profile"Triangle drawing"
	-- Top half
	local start_y = y1 > 0 and y1 or 0
	local stop_y = (y2 <= screen_height and y2 or screen_height)
	local dy = (stop_y\1)-(start_y\1)
	if dy > 0 then
		local slope = (v2-v1)/(y2-y1)
		
		rectfill(userdata("f64",5,dy+1)
			:copy((start_y-y1)*slope+v1,true)
			:copy((stop_y-y1)*slope+v1,true,0,dy*5)
			:lerp(0,dy,5,5,1)
		)
	end
	
	-- Bottom half
	start_y = y2 > 0 and y2 or 0
	stop_y = (y3 <= screen_height and y3 or screen_height)
	dy = (stop_y\1)-(start_y\1)
	if dy > 0 then
		local slope = (vec(p3.x,p3.y,p3.x,p3.y,col)-v2)/(y3-y2)
		
		rectfill(userdata("f64",5,dy+1)
			:copy(slope*(start_y-y2)+v2,true)
			:copy(slope*(stop_y-y2)+v2,true,0,dy*5)
			:lerp(0,dy,5,5,1)
		)
	end
	profile"Triangle drawing"
end