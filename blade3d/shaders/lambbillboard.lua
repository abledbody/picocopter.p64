local Shading = require"blade3d.shading"
local set_luminance_tex,reset_luminance = Shading.set_luminance_tex,Shading.reset_luminance

return function(props,pt)
	local size = props.size
	pt -= props.pivot*size
	
	local tex = props.tex
	local spr = get_spr(tex)
	
	set_luminance_tex(props.light)
	sspr(tex,0,0,spr:width(),spr:height(),pt.x,pt.y,size.x,size.y)
	reset_luminance()
end