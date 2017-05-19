-- basic_example.lua

local rk = require("rocket")

local ffi = require("ffi")
ffi.cdef[[
void Sleep(int ms);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
]]

local sleep
if ffi.os == "Windows" then
  function sleep(s)
    ffi.C.Sleep(s*1000)
  end
else
  function sleep(s)
    ffi.C.poll(nil, 0, s*1000)
  end
end

local bpm = 180
local rpb = 8 -- rows per beat
local rps = (bpm / 60) * rpb
local is_playing = true
local curtime_ms = 0.0

local function row_to_ms_round(row, rps) 
	local newtime = row / rps
	return math.floor(newtime * 1000 + .5)
end

local function ms_to_row_f(time_ms, rps) 
	local row = rps * time_ms * 1.0/1000.0
	return row
end

local function ms_to_row_round(time_ms, rps)
	local r = ms_to_row_f(time_ms, rps)
	return math.floor(r + .5)
end

function cb_pause(flag)
    if flag == 1 then
    	is_playing = false
    else
    	is_playing = true
    end
end

function cb_setrow(row)
	local newtime_ms = row_to_ms_round(row, rps)
    curtime_ms = newtime_ms 
end

function cb_isplaying()
    return is_playing
end

local cbs = {
    ["pause"] = cb_pause,
    ["setrow"] = cb_setrow,
    ["isplaying"] = cb_isplaying,
}


local function rocket_update()
	if is_playing then
	  curtime_ms = curtime_ms + 16
	end

    local uret = rk.sync_update(rocket.obj, ms_to_row_round(curtime_ms, rps), cbs)
    if uret and uret ~= 0 then
        print("sync_update returned: "..uret)
        rk.connect_demo()
    end
end

function get_current_param_value_by_name(pname)
    if not rk then return end
    return rk.get_value(pname, ms_to_row_round(curtime_ms, rps))
end


-- Main
local function main()
    local success = rk.connect_demo()
    if success ~= 0 then
        print("Failed to connect.")
        os.exit(0)
    end

    rk.sync_tracks = {}

	while true do
	  rocket_update()
	  print("current time "..tostring(curtime_ms).. " row "..tostring(ms_to_row_round(curtime_ms, rps)))
	  -- print track values

	  sleep(0.016)
	end
end

main()
