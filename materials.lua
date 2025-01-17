--[[pod_format="raw",created="2024-06-23 22:23:23",modified="2024-07-03 20:39:10",revision=2118]]
local textri = require"blade3d.shaders.textri"
local lambtri = require"blade3d.shaders.lambtri"
local lambtextri = require"blade3d.shaders.lambtextri"
local lambbillboard = require"blade3d.shaders.lambbillboard"


return {
	RobinsonR22Chassis = {
		shader = lambtextri,
		__index = {tex = 3}
	},
	A109Chassis = {
		shader = lambtextri,
		__index = {tex = 1}
	},
	Rotor = {
		shader = lambtextri,
		__index = {tex = 5}
	},
	Tailrotor = {
		shader = lambtextri,
		__index = {tex = 9}
	},
	Grass = {
		shader = lambtextri,
		__index = {tex = 4}
	},
	Windows1 = {
		shader = lambtextri,
		__index = {tex = 6}
	},
	Shadow = {
		shader = textri,
		__index = {tex = 8}
	},
	Color5 = {
		shader = lambtri,
		__index = {col = 5}
	},
	Color22 = {
		shader = lambtri,
		__index = {col = 22}
	},
	Tree = {
		shader = lambbillboard,
		__index = {tex = 2, size = vec(8,8), pivot = vec(0.5,1)},
	},
	Road = {
		shader = lambtextri,
		__index = {tex = 10}
	},
	["Road diag"] = {
		shader = lambtextri,
		__index = {tex = 11}
	},
	["Road T"] = {
		shader = lambtextri,
		__index = {tex = 12}
	},
	["Road cross"] = {
		shader = lambtextri,
		__index = {tex = 13}
	},
}
