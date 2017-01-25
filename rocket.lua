-- rocket.lua

local ffi = require( "ffi" )
print(ffi.os)
local socket = nil
if (ffi.os == "Windows") then
    package.cpath = package.cpath .. ';bin/windows/socket/core.dll'
    package.loadlib("socket/core.dll", "luaopen_socket_core")
    socket = require 'socket.core'
elseif (ffi.os == "Linux") then
    package.cpath = package.cpath .. ';bin/linux/socket/?.so'
    socket = require 'socket.core'
end

rocket = {}

rocket.SYNC_HOST = "127.0.0.1"
rocket.SYNC_DEFAULT_PORT = 1338
rocket.CLIENT_GREET = "hello, synctracker!"
rocket.SERVER_GREET = "hello, demo!"

rocket.SET_KEY = 0
rocket.DELETE_KEY = 1
rocket.GET_TRACK = 2
rocket.SET_ROW = 3
rocket.PAUSE = 4
rocket.SAVE_TRACKS = 5

rocket.KEY_STEP = 0
rocket.KEY_LINEAR = 1
rocket.KEY_SMOOTH = 2
rocket.KEY_RAMP = 3

rocket.last_sent_row = 0

rocket.sync_tracks = {}

-- http://www.lua.org/pil/12.1.1.html
local function serialize (o)
  if type(o) == "number" then
    io.write(o)
  elseif type(o) == "string" then
    io.write(string.format("%q", o))
  elseif type(o) == "table" then
    io.write("{\n")
    for k,v in pairs(o) do
      io.write("  [")
      serialize(k)
      io.write("] = ")
      serialize(v)
      io.write(",\n")
    end
    io.write("}\n")
  else
    error("cannot serialize a " .. type(o))
  end
end

local function save_tracks()
	local filename = "data/tracks.lua"
	print("Saving tracks to "..filename)
	local fh = io.open(filename, "w+")
	if fh then
		io.output(fh)
		io.write("tracks = ")
		serialize(rocket.sync_tracks)
		io.write("return tracks")
		io.close(fh)
	end
end

function key_interp(k0, k1, row)
	if not k1 then return k0.val end

    local step = k0.interp
    if step == rocket.KEY_STEP then
        return k0.val
    end
    local t = (row - k0.row) / (k1.row - k0.row)
    if step == rocket.KEY_SMOOTH then
        t = t * t * (3 - 2 * t)
    elseif step == rocket.KEY_RAMP then
        t = math.pow(t, 2)
    end
    return k0.val + (k1.val - k0.val) * t
end

-- TODO: fold this into get_track
function rocket.create_track(name)
	track = {name = name, keys = {}}
	table.insert(rocket.sync_tracks, track)
end

function rocket.get_track(name)
	-- TODO: index by name for no search
	for _,v in pairs(rocket.sync_tracks) do
		if v.name == name then
			return v
		end
	end
	-- TODO: add track if it doesn't exist
	return nil
end

function rocket.get_value(name, row)
	local track = rocket.get_track(name)
	if not track then return 0 end

    -- TODO: using an array and table.insert, consecutive keys can be neighbors
	local k = track.keys
	if not k then return 0 end

	local kr = k[row]
	if kr then return kr.val end

	-- Find the previous and next keys in the "list"

	-- Create a list of sorted row keys
	local keyset={}
	local n=0
	for kk,vv in pairs(k) do
		n=n+1
		keyset[n]=kk
	end
	table.sort(keyset)
	-- Now we can traverse in order
	local prv = nil
	local nxt = nil
	for kk,vv in pairs(keyset) do
		if vv < row then
			prv = vv
		elseif vv > row then
			nxt = vv
			break
		end
	end

	-- Get value from the two neighboring keyframes
	if not prv then
		if k[kxt] then return k[nxt].val end
	else
		return key_interp(k[prv], k[nxt], row)
	end
	-- No next key found; use last
	if prv and not nxt then
		return k[prv].val
	end

	return 0
end

-- Add key into tracks table
function rocket.add_key_to_table(t, r, v, f)
	local tidx = t + 1
	kk = {row = r, val = v, interp = string.byte(f)}
	-- Insert into sparse array
	if rocket.sync_tracks[tidx] then
		rocket.sync_tracks[tidx].keys[r] = kk
	end
end

function rocket.delete_key_from_table(track, row)
	local tidx = track + 1
	rocket.sync_tracks[tidx].keys[row] = nil
end

-- Coalesce 4 bytes read from a socket into one 32 bit int
local function receive_int32(o)
	local b = o:receive(4)
	if not b then return 0 end
	b = string.reverse(b) -- ntohs
	return ffi.cast("const int*", b)[0]
end

local function receive_float32(o)
	local b = o:receive(4)
	if not b then return 0 end
	b = string.reverse(b) -- ntohs
	return ffi.cast("const float*", b)[0]
end

-- Send byte values in network order over a socket
function send_int32(o, num32)
	-- http://giderosmobile.com/forum/discussion/1083/any-demo-code-for-lua-socket
	-- Integer 32 bit serialization (big-endian)
	local function serializeInt32(value)
		local a = bit.band(bit.rshift(value, 24), 255)
		local b = bit.band(bit.rshift(value, 16), 255)
		local c = bit.band(bit.rshift(value, 8), 255)
		local d = bit.band(value, 255)
		return string.char(a, b, c, d)
	end

	local ser = serializeInt32(num32)
	local ret = o:send(ser)
	if ret and ret ~= 4 then
		print("Send error: returned: "..ret)
	end
end

-- Returns 0 for success
-- Todo: return non-zero for failure
function rocket.connect_demo()
	rocket.obj = socket.tcp()
	rocket.obj:settimeout(1)
	c = rocket.obj:connect(rocket.SYNC_HOST, rocket.SYNC_DEFAULT_PORT)

	-- Greet the Editor...
	rocket.obj:send(rocket.CLIENT_GREET)
	local resp = rocket.obj:receive(string.len(rocket.SERVER_GREET))
	if resp then print("Response: "..resp) end
	rocket.obj:settimeout(0)
	return 0
end

function rocket.send_track_name(o, trackname)
	o:send(string.char(rocket.GET_TRACK))
	send_int32(o, string.len(trackname))
	o:send(trackname)
end

function rocket.receive_and_process_command_demo(obj, row, callbacks)
	obj:settimeout(0)
	local cmd = obj:receive(1)
	if not cmd then return 0 end

	local bcmd = string.byte(cmd)
	if bcmd == rocket.SET_KEY then
		local t = receive_int32(obj)
		local r = receive_int32(obj)
		local v = receive_float32(obj)
		local f = obj:receive(1)
		if t and r and v and f then
			rocket.add_key_to_table(t, r, v, f)
		end
	elseif bcmd == rocket.DELETE_KEY then
		local track = receive_int32(obj)
		local row = receive_int32(obj)
		if track and row then
			rocket.delete_key_from_table(track, row)
		end
	elseif bcmd == rocket.SET_ROW then
		local row = receive_int32(obj)
		if row then callbacks.setrow(row) end
	elseif bcmd == rocket.PAUSE then
		local p = obj:receive(1)
		if p then callbacks.pause(string.byte(p)) end
	elseif bcmd == rocket.SAVE_TRACKS then
		save_tracks()
	else
		print("Unknown cmd: "..cmd.." ("..bcmd..")")
		return 2
	end
end

function rocket.sync_update(obj, row, callbacks)
	local retval = 0
	repeat
		obj:settimeout(0)
		r,w,e = socket.select({obj}, {obj}, 0)
		if e then
			print("Select error: "..e)
			return 3
		end
		retval = rocket.receive_and_process_command_demo(obj, row, callbacks)
	until table.getn(r) == 0

	if callbacks.isplaying() == true then
		if row ~= rocket.last_sent_row then
			rocket.last_sent_row = row
			obj:send(string.char(rocket.SET_ROW))
			send_int32(obj, row)
		end
	end

	return retval
end

return rocket
