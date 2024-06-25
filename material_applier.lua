--[[pod_format="raw",created="2024-06-23 22:23:23",modified="2024-06-25 21:58:13",revision=839]]
local Rendering = require"rendering"

local material_lookup = {
	RobinsonR22Chassis = {
		shader = Rendering.draw_tri,
		properties = {tex = get_spr(3)}
	},
	A109Chassis = {
		shader = Rendering.draw_tri,
		properties = {tex = get_spr(1)}
	},
	Rotor = {
		shader = Rendering.draw_tri,
		properties = {tex = get_spr(5)}
	},
	Tailrotor = {
		shader = Rendering.draw_tri,
		properties = {tex = get_spr(9)}
	},
	Grass = {
		shader = Rendering.draw_tri,
		properties = {tex = get_spr(4)}
	},
	Windows1 = {
		shader = Rendering.draw_tri,
		properties = {tex = get_spr(6)}
	},
	Color22 = {
		shader = Rendering.draw_flat_tri,
		properties = {col = 22}
	},
	Color5 = {
		shader = Rendering.draw_flat_tri,
		properties = {col = 5}
	}
}

local function apply_materials(model)
	local materials = model.materials
	local uvs = model.uvs
	for i = 0,#materials-1 do
		local mtl = material_lookup[materials[i+1]]
		assert(mtl,"Could not find material "..materials[i+1])
		local tex = mtl.properties.tex
		if tex then
			uvs:mul(vec(tex:width(),tex:height()),true,0,i*6,2,0,2,3)
		end
		materials[i] = mtl
	end
	
	return model
end

return apply_materials