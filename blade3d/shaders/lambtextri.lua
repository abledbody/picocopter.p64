local textri = require"blade3d.shaders.textri"
local shading = require"blade3d.shading"
local set_luminance_tex,reset_luminance = shading.set_luminance_tex,shading.reset_luminance

---Draws a shaded 3D textured triangle to the screen. Note that the vertices need W components,
---and that they need to be the reciprocal of the W which is produced by the projection matrix.
---This step is typically done in the perspective division step.
---@param props table The properties passed to the shader. Expects a `tex` field with a texture index.
---@param vert_data userdata A 6x3 matrix where each row is the xyzwuv of a vertex.
---@param screen_height number The height of the screen, used for scanline truncation.
return function(props,vert_data,screen_height)
	set_luminance_tex(props.light)
	textri(props,vert_data,screen_height)
	reset_luminance()
end