--[[pod_format="raw",created="2024-05-22 18:39:52",modified="2024-07-19 23:16:27",revision=10248]]
local Utils = {}

---Creates an identity matrix of size n.
---@param n number the width and height of the matrix.
function Utils.ident_mat(n)
	return userdata("f64",n,n):copy(1,true,0,0,1,0,n+1,n)
end

function Utils.print_mat(matrix,x,y,col)
	local str = ""
	local w = matrix:width()
	for _y = 0,(matrix:height() or 1)-1 do
		str = str.."["
		for _x = 0,w-1 do
			str = str..string.format("%.1f",matrix[_x+_y*w])..","
		end
		str = str.."]\n"
	end
	print(str,x,y,col)
	return str
end

function Utils.lerp(a,b,t) return (b-a)*t+a end
function Utils.invlerp(a,b,x) return (x-a)/(b-a) end
function Utils.remap(x,a1,b1,a2,b2) return (b2-a2)*(x-a1)/(b1-a1)+a2 end
function Utils.asin(x) return atan2(sqrt(1-x*x),x) end
function Utils.acos(x) return atan2(x,sqrt(1-x*x)) end

---Creates an iterator which iterates over the elements of a table array in
---sorted order.
---@param tab table The table to sort.
---@param key string The key to sort by.
---@param descending? boolean Whether to iterate in descending order.
---@return function iterator An iterator over each element in sorted order.
function Utils.tab_sort(tab,key,descending)
	local len = #tab
	if len == 0 then return function() end end
	local order = userdata("f64",2,len)
	if descending then
		for i = 1,len do
			order:set(0,i-1,-tab[i][key],i)
		end
	else
		for i = 1,len do
			order:set(0,i-1,tab[i][key],i)
		end
	end
	order:sort()
	
	local i = 0
	return function()
		if i >= len then return end
		local idx = order:get(1,i)
		i += 1
		return tab[idx]
	end
end

---A set of 64 precalculated ordered dither patterns.
local dithers = userdata("u8",8,64)
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
memmap(0x80000,dithers)

return Utils