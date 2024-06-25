--[[pod_format="raw",created="2024-05-22 18:39:52",modified="2024-06-25 21:58:13",revision=7933]]
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
		str ..= "["
		for _x = 0,w-1 do
			str ..= string.format("%.1f",matrix[_x+_y*w])..","
		end
		str ..= "]\n"
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

return Utils