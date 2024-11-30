local function srgb_to_linear(rgb)
	return vec(
		rgb.x < 0.04045 and rgb.x/12.92 or ((rgb.x+0.055)/1.055)^2.4,
		rgb.y < 0.04045 and rgb.y/12.92 or ((rgb.y+0.055)/1.055)^2.4,
		rgb.z < 0.04045 and rgb.z/12.92 or ((rgb.z+0.055)/1.055)^2.4
	)
end

local xyz_mat = userdata("f64",3,3)
xyz_mat:set(0,0,
	0.4124564,0.2126729,0.0193339,
	0.3575761,0.7151522,0.1191920,
	0.1804375,0.0721750,0.9503041
)

local function linear_to_cielab(rgb)
	local xyz = rgb:matmul(xyz_mat)/vec(95.047,100,108.883)
	
	local fx,fy,fz =
		xyz.x > 0.00885645167904 and xyz.x^(1/3) or 7.78703703704*xyz.x+16/116,
		xyz.y > 0.00885645167904 and xyz.y^(1/3) or 7.78703703704*xyz.y+16/116,
		xyz.z > 0.00885645167904 and xyz.z^(1/3) or 7.78703703704*xyz.z+16/116
	
	return vec(116*fy-16,
		500*(fx-fy),
		200*(fy-fz)
	)
end

-- These functions consider the rgb to be 90% of the actual brightness because
-- otherwise pure white would be considered intensely bright.
local function aces_tonemap(rgb)
	local mapped = (rgb*(2.51*rgb+0.03))/(rgb*(2.43*rgb+0.59)+0.14)
	local r = mapped.x > 1 and 1 or mapped.x < 0 and 0 or mapped.x
	local g = mapped.y > 1 and 1 or mapped.y < 0 and 0 or mapped.y
	local b = mapped.z > 1 and 1 or mapped.z < 0 and 0 or mapped.z
	return vec(r,g,b)
end

local function inverse_aces(rgb)
	local a = 0.0009+rgb*1.3702-rgb*rgb*1.0127
	return (rgb*-0.59+0.03-vec(sqrt(a.x),sqrt(a.y),sqrt(a.z)))/(rgb*4.86-5.02)
end

return {
	srgb_to_linear = srgb_to_linear,
	linear_to_cielab = linear_to_cielab,
	aces_tonemap = aces_tonemap,
	inverse_aces = inverse_aces,
}