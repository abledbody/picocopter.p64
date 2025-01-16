local Chunk = require"chunk"
local quat = require"blade3d.quaternions"

local SQRT2 = sqrt(2)
local RAMP = {[0] = 32,1,19,16,3,17,27,12,11,26,28,7}
local TILE_COLORS = {22,21}

local function draw(minimap,x,y,heli_body)
	rect(x,y,x+map.width+1,y+map.height+1,16)
	sspr(minimap.bmp,0,0,map.width,map.height,x+1,y+1)
	
	if time()%0.8 > 0.2 then
		local hx,hy =
			flr(heli_body.position.x/Chunk.TILE_SIZE+x+1),
			flr(heli_body.position.z/Chunk.TILE_SIZE+y+1)
		
		local up = vec(0,1,0)
		local angle = quat.angle(quat.twist(heli_body.rotation,up),up)-0.25
		local fwd_x,fwd_y = cos(angle),-sin(angle)
		
		line(
			hx+fwd_x*SQRT2,
			hy+fwd_y*SQRT2,
			hx+fwd_x*6,
			hy+fwd_y*6,
			9
		)
		circ(hx,hy,1,9)
	end
end

local m_minimap = {
	draw = draw
}
m_minimap.__index = m_minimap

---@param map Map
local function new(map)
	local bmp = userdata("u8",map.width,map.height)

	for y=0,map.height-1 do
		for x=0,map.width-1 do
			local col = TILE_COLORS[map.tiles:get(x,y,1)]
			if not col then
				local nw,ne = map.heightmap:get(x,y,2)
				local sw,se = map.heightmap:get(x,y+1,2)
				col = RAMP[mid((nw+ne+sw+se)\1+1,1,#RAMP)]
			end
			bmp:set(x,y,col)
		end
	end
	
	local minimap = {
		width = map.width,
		height = map.height,
		bmp = bmp,
	}

	return setmetatable(minimap, m_minimap)
end

return {
	new = new
}