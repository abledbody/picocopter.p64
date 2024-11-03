local textri = require"blade3d.shaders.textri"
local shading = require"blade3d.shading"
local set_luminance_tex,reset_luminance = shading.set_luminance_tex,shading.reset_luminance

---Draws a shaded 3D textured triangle to the screen. Note that the vertices need W components,
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
	set_luminance_tex(props.light)
	textri(props,p1,p2,p3,uv1,uv2,uv3,screen_height)
	reset_luminance()
end