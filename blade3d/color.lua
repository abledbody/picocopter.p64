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
	local xyz = rgb:matmul(xyz_mat)
	
	local function chan(t)
		return t > 0.00885645167904 and t^(1/3) or 7.78703703704*t+16/116
	end
	
	local fx,fy,fz =
		chan(xyz.x/95.047),
		chan(xyz.y/100),
		chan(xyz.z/108.883)
	
	return vec(116*fy-16,
		500*(fx-fy),
		200*(fy-fz)
	)
end

return {
	srgb_to_linear = srgb_to_linear,
	linear_to_cielab = linear_to_cielab
}