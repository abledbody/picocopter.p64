--[[pod_format="raw",created="2024-04-09 22:52:04",modified="2024-04-11 17:26:16",revision=1003]]
-- abledbody's profiler v1.1

local function do_nothing() end

-- The metatable here is to make profile() possible.
-- Why use a table at all? Because otherwise lua will try to cache the function call,
-- which by default is do_nothing.
local profile_meta = {__call = do_nothing}
profile = {draw = do_nothing}
setmetatable(profile,profile_meta)

local running = {} -- All incomplete profiles
 -- All complete profiles. Note that if the profiles haven't been drawn yet, it will
 -- not be cleared, and further profiles of the same name will add to the usage metric.
local profiles = {}
-- All completed lingering profiles. These are never automatically cleared.
local lingers = {}

-- start_profile, stop_profile, and stop_linger are all internal functions,
-- serving as paths for _profile to take. Lingers share start_profile.
local function start_profile(name,linger)
	local source = profiles[name]
	running[name] = {
		linger = linger,
	}
	local active = running[name]
	active.start = stat(1) --Delaying CPU usage grab until the last possible second.
end

local function stop_profile(name,active,delta)
	local profile = profiles[name]
	if profile then
		profile.time = delta+profile.time
	else
		profiles[name] = {
			time = delta,
			name = name,
		}
		add(profiles,profiles[name])
	end
end

local function stop_linger(name,active,delta)
	local profile = lingers[name]
	if profile then
		profile.time = profile.this_frame and delta+profile.time or delta
		profile.this_frame = true
	else
		lingers[name] = {
			time = delta,
			this_frame = true,
		}
	end
end

-- The main functionality lives here.
-- Takes in the name of what you're profiling, and whether or not to
-- make the profile linger.
local function _profile(_,name,linger)
	local t = stat(1)
	local active = running[name]
	if active then
		local delta = t-active.start
		
		if active.linger then stop_linger(name,active,delta)
		else stop_profile(name,active,delta) end
	
		running[name] = nil
	else
		start_profile(name,linger)
	end
end

-- Clears all lingering profiles.
function profile.clear_lingers()
	lingers = {}
end

local function draw_cpu(col)
	print("cpu:"..string.sub(stat(1)*100,1,5).."%",1,1,col)
end

-- This draws the profiles, and then resets everything for the next frame.
-- If it is not called, usage metrics will accumulate.
-- Lingering profiles are always displayed after persistent profiles.
local function display_profiles(col)
	local i = 1
	for prof in all(profiles) do
		local usage = string.sub(prof.time*100,1,5).."%"
		local to_print = prof.name..":"..usage
		print(to_print,1,1+i*9,col)
		i = i+1
	end
	for name,prof in pairs(lingers) do
		local usage = string.sub(prof.time*100,1,5).."%"
		local to_print = name..(prof.this_frame and "[X]:" or "[ ]:")..usage
		print(to_print,1,1+i*9,col)
		prof.this_frame = false
		i = i+1
	end
	profiles = {}
end

local function display_both(col)
	draw_cpu(col)
	display_profiles(col)
end

-- This swaps out function calls depending on whether or not you want to have
-- profiling. This is to make it as much as possible so that you don't have to
-- think about cleaning up profile calls for efficiency.
-- The first boolean is for detailed profiling, the second is for CPU usage.
function profile.enabled(detailed,cpu)
	profile_meta.__call = detailed and _profile or do_nothing
	profile.draw = detailed and (cpu and display_both or display_profiles)
		or (cpu and draw_cpu or do_nothing)
end