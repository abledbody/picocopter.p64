--[[pod_format="raw",created="2024-06-23 22:23:23",modified="2024-07-03 20:39:10",revision=2118]]
local textri = require"blade3d.shaders.textri"
local lambtri = require"blade3d.shaders.lambtri"
local lambtextri = require"blade3d.shaders.lambtextri"


return {
	RobinsonR22Chassis = {
		shader = lambtextri,
		properties = {tex = 3}
	},
	A109Chassis = {
		shader = textri,
		properties = {tex = 1}
	},
	Rotor = {
		shader = textri,
		properties = {tex = 5}
	},
	Tailrotor = {
		shader = textri,
		properties = {tex = 9}
	},
	Grass = {
		shader = lambtextri,
		properties = {tex = 4}
	},
	Windows1 = {
		shader = lambtextri,
		properties = {tex = 6}
	},
	Shadow = {
		shader = textri,
		properties = {tex = 8}
	},
	Color5 = {
		shader = lambtri,
		properties = {col = 5}
	},
	Color22 = {
		shader = lambtri,
		properties = {col = 22}
	}
}
