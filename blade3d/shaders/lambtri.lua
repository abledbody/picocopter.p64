--[[pod_format="raw",created="2024-10-26 19:38:52",modified="2024-10-26 19:58:30",revision=73]]
local trifill = require"blade3d.shaders.trifill"
local shading = require"blade3d.shading"
local set_luminance_shape,reset_luminance = shading.set_luminance_shape,shading.reset_luminance

---Draws a shaded triangle to the screen.
---@param props table The properties passed to the shader. Expects a `light` field that determines the color of the triangle.
---@param vert_data userdata A 6x3 matrix where each row is the xyzwuv of a vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(props,vert_data,screen_height)
	props.col = set_luminance_shape(props.light,props.col)
	trifill(props,vert_data,screen_height)
	reset_luminance()
end