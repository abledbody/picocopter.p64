--[[pod_format="raw",created="2024-06-23 22:23:23",modified="2024-07-03 20:39:10",revision=2118]]
return {
	RobinsonR22Chassis = {
		shader = require"blade3d.shaders.textri",
		properties = {tex = 3}
	},
	A109Chassis = {
		shader = require"blade3d.shaders.textri",
		properties = {tex = 1}
	},
	Rotor = {
		shader = require"blade3d.shaders.textri",
		properties = {tex = 5}
	},
	Tailrotor = {
		shader = require"blade3d.shaders.textri",
		properties = {tex = 9}
	},
	Grass = {
		shader = require"blade3d.shaders.lambtri",
		properties = {color_ramp = {32,1,19,3,27,11,26}}
	},
	Windows1 = {
		shader = require"blade3d.shaders.textri",
		properties = {tex = 6}
	},
	Shadow = {
		shader = require"blade3d.shaders.textri",
		properties = {tex = 8}
	},
	Color5 = {
		shader = require"blade3d.shaders.lambtri",
		properties = {color_ramp = {32,21,5,22,6,7}}
	},
	Color22 = {
		shader = require"blade3d.shaders.trifill",
		properties = {col = 22}
	}
}
