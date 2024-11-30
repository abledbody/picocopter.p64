--[[pod_format="raw",created="2024-10-26 19:38:52",modified="2024-10-26 19:58:30",revision=73]]
local trifill = require"blade3d.shaders.trifill"
local dithers_addr = require"blade3d.shading".dithers_addr

---Draws a shaded triangle to the screen.
---@param props table The properties passed to the shader. Expects a `color_ramp` field, which is an array of colors, and an optional `max_luminance` field, which is the light value that the triangle needs to reach to use the last color in the ramp.
---@param vert_data userdata A 6x3 matrix where each row is the xyzwuv of a vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(props,vert_data,screen_height)
	local color_transitions = #props.color_ramp-1
	local i = props.light*(color_transitions)/(props.max_luminance or 1)
	i = i < 0 and 0 or i > color_transitions and color_transitions or i
	
	props.col = props.color_ramp[i\1+1]|(props.color_ramp[ceil(i)+1]<<8)
	memcpy(0x5500,dithers_addr+(i%1*64)\1*8,8)
	
	trifill(props,vert_data,screen_height)
	
	memset(0x5500,0,8)
end