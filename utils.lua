--[[pod_format="raw",created="2024-05-22 18:39:52",modified="2024-07-19 23:16:27",revision=10248]]
local Utils = {}

function Utils.ident_4x4()
	local mat = userdata("f64",4,4)
	mat:set(0,0,
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		0,0,0,1
	)
	return mat
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

-- An implementation of QuickSort which does not allocate new tables.
-- Mutates the provided table.
function Utils.sort(arr,key)
    local function insertion_sort(min,max)
        for i = min+1,max do
            for j = i,min+1,-1 do
                local item,other = arr[j],arr[j-1]
                if other[key] <= item[key] then break end
                arr[j],arr[j-1] = other,item
            end
        end
    end

    local function quick_sort(min,max)
        -- This means there's one or none elements in the list.
        -- It literally cannot be unsorted.
        if min >= max then
            return
        end
        
        -- The pivot will be the median value between the first, last,
        -- and middle elements. This is done to avoid worst case scenarios
        -- where the pivot is already at the boundary between buckets.
        local pivot
        do -- The local variables here can be discarded after pivot selection.
            local pivot_i = flr((max+min)/2)
            pivot = arr[pivot_i][key]
            
            local first = arr[min][key]
            local last = arr[max][key]
            
            -- Bubble sort the first, middle, and last elements.
            if first > pivot then
                arr[min],arr[pivot_i] = arr[pivot_i],arr[min]
                first,pivot = pivot,first
            end
            if pivot > last then
                arr[pivot_i],arr[max] = arr[max],arr[pivot_i]
                pivot = last -- last is unused from here on. Doesn't need to be valid.
            end
            if first > pivot then
                arr[min],arr[pivot_i] = arr[pivot_i],arr[min]
                pivot = first -- first is unused from here on. Doesn't need to be valid.
            end
        end
        
        -- If there's three or fewer elements, it is already sorted.
        if max-min < 3 then return end
        
        local low,high = min+1,max-1
        while true do
            -- Find the first high bucket item in the low bucket,
            while low < high and arr[low][key] < pivot do
                low += 1
            end
            -- and the last low bucket item in the high bucket.
            while low < high and arr[high][key] > pivot do
                high -= 1
            end
            -- If they are the same item, we have sorted all elements into the buckets.
            if low >= high then break end
            
            -- Otherwise, swap the elements, so they are in the correct buckets.
            arr[low],arr[high] = arr[high],arr[low]
            -- We now know those two items are in the correct buckets, so we
            -- don't need to recheck them.
            low += 1
            high -= 1
        end
        
        -- Sort the low bucket and the high bucket individually.
        -- insertion_sort is better for small buckets.
        local algo = high-min < 8 and insertion_sort or quick_sort
        algo(min,high)
        algo = max-low < 8 and insertion_sort or quick_sort
        algo(low,max)
    end
    
    -- Sort everything
    local algo = #arr <= 8 and insertion_sort or quick_sort
    algo(1,#arr)
    
    -- Return the sorted array. Since this function mutates the original,
    -- this is purely for convenience.
    return arr
end

local function brot(x,k)
	return (x<<k)|(x>>(32-k))
end

local prime1,prime2,prime3 = 356735872903,845723454073,34478587249
local max32 = 2^32-1

local function hash_xy(x,y,seed)
	x += 674
	y += 2986
	seed += 397
	local hash = brot(x*prime1,y%32)^^brot(y*prime2,seed%32)^^brot(seed*prime3,x%32)
	return hash/max32
end

local sqrt2 = sqrt(2)

function Utils.perlin(x,y,scale,seed)
	x,y = x/scale,y/scale
	local seed_x,seed_y = flr(x),flr(y)
	local nw = hash_xy(seed_x,seed_y,seed)
	local ne = hash_xy(seed_x+1,seed_y,seed)
	local sw = hash_xy(seed_x,seed_y+1,seed)
	local se = hash_xy(seed_x+1,seed_y+1,seed)
	
	x,y = x%1,y%1
	
	local nwd = (vec(cos(nw),-sin(nw)):dot(vec(x,y))/sqrt2)
	local ned = (vec(cos(ne),-sin(ne)):dot(vec(x-1,y))/sqrt2)
	local swd = (vec(cos(sw),-sin(sw)):dot(vec(x,y-1))/sqrt2)
	local sed = (vec(cos(se),-sin(se)):dot(vec(x-1,y-1))/sqrt2)
	
	local smooth_x = 6*x^5-15*x^4+10*x^3
	local smooth_y = 6*y^5-15*y^4+10*y^3
	
	local n = (ned-nwd)*smooth_x+nwd
	local s = (sed-swd)*smooth_x+swd
	return (s-n)*smooth_y+n
end

Utils.hash_xy = hash_xy

return Utils