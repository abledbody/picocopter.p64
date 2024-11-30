local Color = require"blade3d.color"
local log = math.log

local rayleigh = vec(1.05,1.025,1)
local lightness_range = 8

-- White is considered by the ACES color space to be infinitely bright.
-- To compensate, we essentially just tell the inverse ACES
-- function that the input is some fraction of the actual brightness so that
-- the resulting HDR color is something more workable.
-- Once it gets converted back to ACES, we scale it back up, so the
-- luminance transformations are sensible, but this scaling factor doesn't
-- directly affect the brightness of the color values.
local filmic_compression = 2

local dithers_addr = 0x80000
local lookup_addr = 0x81000
local orig_colormap_addr = lookup_addr+0x1000*(lightness_range*2+1)

local dithers = userdata("u8",8,64)
memmap(dithers_addr,dithers)
do
	local bayer = userdata("u8",8,8)
	bayer:set(0,0,
		0,32, 8,40, 2,34,10,42,
		48,16,56,24,50,18,58,26,
		12,44, 4,36,14,46, 6,38,
		60,28,52,20,62,30,54,22,
		3,35,11,43, 1,33, 9,41,
		51,19,59,27,49,17,57,25,
		15,47, 7,39,13,45, 5,37,
		63,31,55,23,61,29,53,21
	)
	
	for i = 0,63 do
		for y = 0,7 do
			local row = 0
			for x = 0,7 do
				row |= (i > bayer[x+y*8] and 1 or 0)<<x
			end
			dithers[y+i*8] = row
		end
	end
end

local lookups = userdata("u8",64,64*(lightness_range*2+1))
memmap(lookup_addr,lookups)

do
	-- Contains the HDR color values of the original colormap.
	local lin_colors = userdata("f64",3,64)
	-- Contains the tone-mapped CIELAB values of the original colormap.
	local cielab_colors = userdata("f64",3,64)
	
	local min_lightness,min_light_index = 1,1
	for i=0,63 do
		local b8 = peek(0x5000+i*4)
		local g8 = peek(0x5000+i*4+1)
		local r8 = peek(0x5000+i*4+2)
		
		-- We assume that the original palette colors are all sRGB, ACES
		-- tone-mapped colors at a luminance of 1, so that we can extrapolate
		-- the other luminance values from them.
		-- This is why we undo the ACES tone-mapping here. We want the equivalent
		-- raw, linear RGB values.
		local aces_rgb = Color.srgb_to_linear(vec(r8,g8,b8)/255)
		local rgb = Color.inverse_aces(aces_rgb/filmic_compression)
		
		lin_colors:copy(rgb,true,0,i*3,3,0,0,1)
		-- Since CIELAB is used for perceptual color comparisons, we are
		-- disregarding the tone mapping entirely.
		-- The palette colors are what they are.
		cielab_colors:copy(Color.linear_to_cielab(aces_rgb),true,0,i*3,3,0,0,1)
		
		-- While we're looping through the colors, we might as well find the
		-- darkest color in the palette to use as the 0 luminance color.
		local lightness = rgb:dot(vec(0.2126,0.7152,0.0722))
		if i ~= 0 and lightness < min_lightness then
			min_lightness = lightness
			min_light_index = i
		end
	end
	-- The first lookup should be pure black, or as close as possible.
	lookups:copy(min_light_index,true,0,1,63,0,64,64)
	
	for i = 1,lightness_range*2 do
		local table_offset = i*0x1000
		-- This equation makes each step in the lightness range logarithmic.
		-- That way, we get more precision in the darker colors.
		local luminance_mul = 2^((i-lightness_range)*0.7)
		local rayleigh_lum = ((luminance_mul-1)*rayleigh+1)
		rayleigh_lum.x = rayleigh_lum.x < 0 and 0 or rayleigh_lum.x
		rayleigh_lum.y = rayleigh_lum.y < 0 and 0 or rayleigh_lum.y
		rayleigh_lum.z = rayleigh_lum.z < 0 and 0 or rayleigh_lum.z
		
		-- Ew, O(n^2)
		for col_i = 0,lin_colors:height()-1 do
			-- Since we want the result to be tone-mapped, we do that before
			-- converting to CIELAB for comparison.
			local col_lab = Color.linear_to_cielab(
				Color.aces_tonemap(lin_colors:row(col_i)*rayleigh_lum)
				*filmic_compression
			)
			
			local best_dist,best_index = math.huge,0
			for test_i = 0,lin_colors:height()-1 do
				-- Prioritize L (lightness), followed by A (green-magenta), and
				-- then B (blue-yellow).
				local dist = ((cielab_colors:row(test_i)-col_lab)*vec(1,0.7,0.5)):magnitude()
				
				if dist < best_dist then
					best_dist = dist
					best_index = test_i
				end
			end
			
			local row_offset = col_i*64
			lookups:copy(best_index,true,0,row_offset+table_offset,64)
		end
	end
	
	lookups[0] = 0
	lookups:copy(1,true,0,1,1,0,1,63)
	lookups:add(lookups,true,0,1,63)
	lookups:copy(lookups,true,0,0x1000,64,0x1000,0x1000,lightness_range*2+1)

	local orig_colormap = userdata("u8",64,64)
	memmap(orig_colormap_addr,orig_colormap)
	memcpy(orig_colormap_addr,0x8000,0x1000)
end

local color_transitions = lookups:height()-1
local log2 = 1/log(2)
local function get_lookup_index(luminance)
	if luminance <= 0 then return 0 end
	local i = log(luminance)*log2+lightness_range
	i = i > color_transitions and color_transitions or i
	return i
end


local function set_luminance_tex(luminance)
	local i = get_lookup_index(luminance)
	memcpy(0x5500,dithers_addr+(i%1*64)\1*8,8)
	memcpy(0x8000,lookup_addr+i\1*0x1000,0x1000)
	memcpy(0xA000,lookup_addr+ceil(i)*0x1000,0x1000)
end

local function set_luminance_shape(luminance,col)
	local i = get_lookup_index(luminance)
	memcpy(0x5500,dithers_addr+(i%1*64)\1*8,8)
	local low_col = lookups:get(1,col+i\1*64) -- Second column's a safer bet.
	local high_col = lookups:get(1,col+ceil(i)*64)
	return (high_col<<8)|low_col
end

local function reset_luminance()
	memcpy(0x8000,orig_colormap_addr,0x1000)
	memset(0x5500,0,8)
end

return {
	set_luminance_tex = set_luminance_tex,
	set_luminance_shape = set_luminance_shape,
	reset_luminance = reset_luminance,
	dithers_addr = dithers_addr,
	lookup_addr = lookup_addr,
	orig_colormap_addr = orig_colormap_addr,
}