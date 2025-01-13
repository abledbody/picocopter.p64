--[[pod_format="raw",created="2024-05-22 18:39:52",modified="2024-07-19 23:16:27",revision=10248]]
---Creates an identity matrix of size n.
---@param n number the width and height of the matrix.
local function ident_mat(n)
	return userdata("f64",n,n):copy(1,true,0,0,1,0,n+1,n)
end

local function print_mat(matrix,x,y,col)
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

local function lerp(a,b,t) return (b-a)*t+a end
local function invlerp(a,b,x) return (x-a)/(b-a) end
local function remap(x,a1,b1,a2,b2) return (b2-a2)*(x-a1)/(b1-a1)+a2 end
local function asin(x) return atan2(sqrt(1-x*x),x) end
local function acos(x) return atan2(x,sqrt(1-x*x)) end

---Creates an iterator which iterates over the elements of a table array in
---sorted order.
---@param tab table The table to sort.
---@param key string The key to sort by.
---@param descending? boolean Whether to iterate in descending order.
---@return function iterator An iterator over each element in sorted order.
local function tab_sort(tab,key,descending)
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

return {
	ident_mat = ident_mat,
	print_mat = print_mat,
	lerp = lerp,
	invlerp = invlerp,
	remap = remap,
	asin = asin,
	acos = acos,
	tab_sort = tab_sort,
}