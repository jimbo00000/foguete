-- example_sound.lua
local bit = require("bit")
local ffi = require("ffi")
local rk = require("rocket")
if (ffi.os == "Windows") then
    package.cpath = package.cpath .. ';bin/windows/socket/core.dll'
    package.loadlib("socket/core.dll", "luaopen_socket_core")
    socket = require 'socket.core'
elseif (ffi.os == "Linux") then
    package.cpath = package.cpath .. ';bin/linux/socket/?.so'
    socket = require 'socket.core'
end
local fpstimer = require("util.fpstimer")

package.path = package.path .. ';lib/?.lua'

-- http://stackoverflow.com/questions/17877224/how-to-prevent-a-lua-script-from-failing-when-a-require-fails-to-find-the-scri
local function prequire(m)
  local ok, err = pcall(require, m)
  if not ok then return nil, err end
  return err
end

local bass, err = prequire("bass")
if bass == nil then
    print("main_demo.lua: Could not load Bass library: "..err)
end

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

local bpm = 150
local rpb = 8 -- rows per beat
local rps = (bpm / 60) * rpb
local curtime_ms = 0.0

local function row_to_ms_round(row, rps) 
	local newtime = row / rps
	return math.floor(newtime * 1000 + .5)
end

local function ms_to_row_f(time_ms, rps) 
	local row = rps * time_ms/1000
	return row
end

local function ms_to_row_round(time_ms, rps)
	local r = ms_to_row_f(time_ms, rps)
	return math.floor(r + .5)
end

function bass_get_time()
    if not stream then return 0 end
    local pos = bass.BASS_ChannelGetPosition(stream, bass.BASS_POS_BYTE)
    local time_s = bass.BASS_ChannelBytes2Seconds(stream, pos)
    return time_s * 1000
end

function bass_get_row()
    if not stream then return 0 end
    return bass_get_time() * rps
end

function cb_pause(flag)
    if not stream then return false end
    if flag == 1 then
        bass.BASS_ChannelPause(stream)
    else
        bass.BASS_ChannelPlay(stream, false)
    end
end

function cb_setrow(row)
	local newtime_ms = row_to_ms_round(row, rps)
    curtime_ms = newtime_ms

    local pos = bass.BASS_ChannelSeconds2Bytes(stream, curtime_ms/1000)
    local ret = bass.BASS_ChannelSetPosition(stream, pos, bass.BASS_POS_BYTE)
    if ret == 0 then
        print("BASS_ChannelSetPosition returned ",bass.BASS_ErrorGetCode())
    end
end

function cb_isplaying()
    if not stream then return false end
    return (bass.BASS_ChannelIsActive(stream) == bass.BASS_ACTIVE_PLAYING)
end

local cbs = {
    ["pause"] = cb_pause,
    ["setrow"] = cb_setrow,
    ["isplaying"] = cb_isplaying,
}

local function rocket_update()
	if cb_isplaying() then
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

local function main()
    local success = rk.connect_demo()
    if success ~= 0 then
        print("Failed to connect.")
        os.exit(0)
    end

    rk.sync_tracks = {}

    local init_ret = bass.BASS_Init(-1, 44100, 0, 0, nil)
    stream = bass.BASS_StreamCreateFile(false, "data/SimpleBeat.wav", 0, 0, bass.BASS_STREAM_PRESCAN)

    bass.BASS_Start()
    bass.BASS_ChannelPlay(stream, false)

	while true do
	  rocket_update()
	  print("current time "..tostring(curtime_ms).. " row "..tostring(ms_to_row_round(curtime_ms, rps)))
	  -- print track values

	  sleep(0.016)
      bass.BASS_Update(0) -- decrease the chance of missing vsync
	end
    bass.BASS_StreamFree(stream)
    bass.BASS_Free()
end

main()
