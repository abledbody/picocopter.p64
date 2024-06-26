--[[pod_format="raw",created="2024-06-23 22:23:23",modified="2024-06-26 06:25:44",revision=1041]]
local Rendering = require"rendering"

return {
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
	Shadow = {
		shader = Rendering.draw_tri,
		properties = {tex = get_spr(8)}
	},
	Color5 = {
		shader = Rendering.draw_flat_tri,
		properties = {col = 5}
	},
	Color22 = {
		shader = Rendering.draw_flat_tri,
		properties = {col = 22}
	}
}
