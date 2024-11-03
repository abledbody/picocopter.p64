local color = require"blade3d.color"
local log = math.log

local lightness_range = 8
local dithers_address = 0x80000
local lookup_address = 0x81000
local orig_colormap_address = lookup_address+0x1000*(lightness_range*2+1)

local dithers = userdata("u8",8,64)
memmap(dithers_address,dithers)
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

local lin_colors = userdata("f64",3,64)
for i=0,63 do
	local blue_b = peek(0x5000+i*4)
	local green_b = peek(0x5000+i*4+1)
	local red_b = peek(0x5000+i*4+2)
	local rgb = vec(red_b,green_b,blue_b)/255
	lin_colors:copy(color.srgb_to_linear(rgb),true,0,i*3,3,0,0,1)
end

local cielab_colors = userdata("f64",3,64)
for i=0,63 do
	cielab_colors:copy(color.linear_to_cielab(lin_colors:row(i)),true,0,i*3,3,0,0,1)
end

local min_lightness,min_light_index = 1,0
for i = 0,63 do
	local lightness = lin_colors:row(i):dot(vec(0.2126,0.7152,0.0722))
	if lightness < min_lightness then
		min_lightness = lightness
		min_light_index = i
	end
end
local lookups = userdata("u8",64,64*(lightness_range*2+1))
memmap(lookup_address,lookups)
-- The first lookup should be pure black, or as close as possible.
lookups:copy(min_light_index,true,0,0,64*64)

for i = 1,lightness_range*2 do
	local luminance_mul = 2^((i-lightness_range))
	
	for col_i = 0,lin_colors:height()-1 do
		local col_lab = color.linear_to_cielab(lin_colors:row(col_i)*luminance_mul)
		
		local best_dist,best_index = math.huge,0
		
		for test_i = 0,lin_colors:height()-1 do
			local dist = (cielab_colors:row(test_i)-col_lab):magnitude()
			if dist < best_dist then
				best_dist = dist
				best_index = test_i
			end
		end
		lookups:copy(best_index,true,0,col_i*64+i*0x1000,64)
	end
end

local orig_colormap = userdata("u8",64,64)
memmap(orig_colormap_address,orig_colormap)
memcpy(orig_colormap_address,0x8000,0x1000)

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
	memcpy(0x5500,dithers_address+(i%1*64)\1*8,8)
	memcpy(0x8000,lookup_address+i\1*0x1000,0x1000)
	memcpy(0xA000,lookup_address+ceil(i)*0x1000,0x1000)
	palt(0,true)
end

local function set_luminance_shape(luminance,col)
	local i = get_lookup_index(luminance)
	memcpy(0x5500,dithers_address+(i%1*64)\1*8,8)
	local low_col = lookups:get(1,col+i\1*64) -- Second column's a safer bet.
	local high_col = lookups:get(1,col+ceil(i)*64)
	return (high_col<<8)|low_col
end

local function reset_luminance()
	memcpy(0x8000,orig_colormap_address,0x1000)
	memset(0x5500,0,8)
	palt(0,true)
end

return {
	set_luminance_tex = set_luminance_tex,
	set_luminance_shape = set_luminance_shape,
	reset_luminance = reset_luminance
}