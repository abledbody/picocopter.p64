--[[pod_format="raw",created="2024-10-26 19:38:52",modified="2024-10-26 19:58:30",revision=73]]
local trifill = require"blade3d.shaders.trifill"

---Draws a shaded triangle to the screen.
---@param props table The properties passed to the shader. Expects a `light` field that determines the color of the triangle.
---@param p1 userdata The XY coordinates of the first vertex.
---@param p2 userdata The XY coordinates of the second vertex.
---@param p3 userdata The XY coordinates of the third vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(props,p1,p2,p3,_,_,_,screen_height)
	local color_ramp = props.color_ramp
	local color_transitions = #color_ramp-1
	local i = props.light*(color_transitions)
	i = i < 0 and 0 or (i > color_transitions and color_transitions or i)
	
	memcpy(0x5500,0x80000+(((i%1)*64)\1)*8,8)
	trifill(
		{col = color_ramp[i\1+1]|(color_ramp[ceil(i)+1]<<8)},
		p1,p2,p3,_,_,_,screen_height
	)
	memset(0x5500,0,8)
end