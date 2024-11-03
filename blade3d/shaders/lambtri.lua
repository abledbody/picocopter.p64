--[[pod_format="raw",created="2024-10-26 19:38:52",modified="2024-10-26 19:58:30",revision=73]]
local trifill = require"blade3d.shaders.trifill"
local shading = require"blade3d.shading"
local set_luminance_shape,reset_luminance = shading.set_luminance_shape,shading.reset_luminance

---Draws a shaded triangle to the screen.
---@param props table The properties passed to the shader. Expects a `light` field that determines the color of the triangle.
---@param p1 userdata The XY coordinates of the first vertex.
---@param p2 userdata The XY coordinates of the second vertex.
---@param p3 userdata The XY coordinates of the third vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(props,p1,p2,p3,_,_,_,screen_height)
	props.col = set_luminance_shape(props.light,props.col)
	trifill(props,p1,p2,p3,_,_,_,screen_height)
	reset_luminance()
end