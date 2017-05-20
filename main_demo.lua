-- main_demo.lua

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

local glfw = require("glfw")
local openGL = require("opengl")
openGL.loader = glfw.glfw.GetProcAddress
openGL:import()

local mm = require("util.matrixmath")
local gfx = require("scene.graphics")

local win_w = 800
local win_h = 600

local g_ft = fpstimer.create()
local g_lastFrameTime = 0

--[[
    Music attributes:
    SimpleBeat.wav - length 3.2s, 8 beats
    8 / 3.2 == 2.5 beats.second *60 == 150 bpm
]]
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

function onkey(window,k,code,action,mods)
    if action == glfw.GLFW.PRESS or action == glfw.GLFW.REPEAT then
        if k == glfw.GLFW.KEY_ESCAPE then os.exit(0)
        end
    end
end

function initGL()
    gfx.initGL()
end

function display()
    gfx.display()
end

function resize(window, w, h)
    win_w = w
    win_h = h
    gl.glViewport(0,0, win_w, win_h)
    gfx.resize(w, h)
end

function get_current_param_value_by_name(pname)
    if not rk then return end
    return rk.get_value(pname, ms_to_row_round(curtime_ms, rps))
end

function timestep(absTime, dt)
    gfx.sync_params(get_current_param_value_by_name)

    if cb_isplaying() then
        curtime_ms = curtime_ms + dt
        gfx.timestep(absTime, dt)
    else
        if socket then socket.sleep(0.001) end
    end
end

function dofile(filename)
    local f = assert(loadfile(filename))
    return f()
end

function main()
    local a = ffi.new("int[1]")
    local b = ffi.new("int[1]")
    local c = ffi.new("int[1]")
    glfw.glfw.GetVersion(a,b,c)
    print("glfw version "..a[0]..'.'..b[0]..'.'..c[0])

    if arg[1] and arg[1] == "sync" then
        SYNC_PLAYER = 1
    end

    if SYNC_PLAYER then
        local success = rk.connect_demo()
        if success ~= 0 then
            print("Failed to connect.")
            os.exit(0)
        end
        -- Sort keys before inserting
        alphakeys = {}
        for n in pairs(gfx.sync_callbacks) do table.insert(alphakeys, n) end
        table.sort(alphakeys)
        for _,k in ipairs(alphakeys) do
            print("Create track: ",k)
            rk.get_track(k)
            rk.send_track_name(rk.obj, k)
        end
    else
        --print("Load tracks from file")
        local tracks_module = 'data.tracks'
        local status, module = pcall(require, tracks_module)
        if not status then
            print('Tracks file ['..tracks_module ..'.lua] not found.')
            print('Re-launch with argument sync to connect to editor.')
            print('')
            print('Press any key to exit...')
            io.read()
            os.exit(1)
        end
        if rk then rk.sync_tracks = module end
    end

    -- Load config file
    if arg[1] and arg[1] == "compo" then
        fullscreen = true
        vsync = true
        showfps = false
    else
        dofile('appconfig.lua')
        win_w, win_h = window_w, window_h
    end

    glfw.glfw.Init()

    local windowTitle = "Your Demo Here"
    local monitor = nil
    if fullscreen == true then monitor = glfw.glfw.GetPrimaryMonitor() end
    if monitor then
        mode = glfw.glfw.GetVideoMode(monitor)
        win_w = mode.width
        win_h = mode.height
        print("Monitor mode:",mode.width, mode.height)
    end

    glfw.glfw.WindowHint(glfw.GLFW.CONTEXT_VERSION_MAJOR, 4)
    glfw.glfw.WindowHint(glfw.GLFW.CONTEXT_VERSION_MINOR, 1)
    glfw.glfw.WindowHint(glfw.GLFW.OPENGL_FORWARD_COMPAT, 1)
    glfw.glfw.WindowHint(glfw.GLFW.OPENGL_PROFILE, glfw.GLFW.OPENGL_CORE_PROFILE)

    window = glfw.glfw.CreateWindow(win_w,win_h,windowTitle,monitor,nil)
    glfw.glfw.MakeContextCurrent(window)

    glfw.glfw.SetKeyCallback(window, onkey)
    glfw.glfw.SetWindowSizeCallback(window, resize)

    if fullscreen then
        glfw.glfw.SetInputMode(window, glfw.GLFW.CURSOR, glfw.GLFW.CURSOR_HIDDEN)
    end

    initGL()
    resize(window, win_w, win_h)

    local init_ret = bass.BASS_Init(-1, 44100, 0, 0, nil)
    stream = bass.BASS_StreamCreateFile(false, "data/SimpleBeat.wav", 0, 0, bass.BASS_STREAM_PRESCAN)
    local streamlen_bytes = bass.BASS_ChannelGetLength(stream, bass.BASS_POS_BYTE)
    local streamlen_sec = bass.BASS_ChannelBytes2Seconds(stream, streamlen_bytes)

    gfx.setbpm(bpm)

    bass.BASS_Start()
    bass.BASS_ChannelPlay(stream, false)

    --if true then
        glfw.glfw.SwapInterval(1)
   -- else
        --glfw.glfw.SwapInterval(0)
    --end

    g_lastFrameTime = 0
    while glfw.glfw.WindowShouldClose(window) == 0 do
        if SYNC_PLAYER then
            local uret = rk.sync_update(rocket.obj, ms_to_row_round(curtime_ms, rps), cbs)
            if uret and uret ~= 0 then
                print("sync_update returned: "..uret)
                --rk.connect_demo()
            end
        end

        glfw.glfw.PollEvents()
        g_ft:onFrame()
        display()

        local now = bass_get_time()
        timestep(now, now - g_lastFrameTime)
        g_lastFrameTime = now

        -- TODO: figure out why vsync isn't working
        local targetfps = 80
        if socket then socket.sleep(1/targetfps) end


        if not SYNC_PLAYER then
            -- Quit at the end of the song
            -- TODO: this is never reached.
            if curtime_ms/1000 >= streamlen_sec then
                print("Song done. Quitting...")
                glfw.glfw.SetWindowShouldClose(window, true)
            end
        end

        if showfps then
            if (ffi.os == "Windows") then
                glfw.glfw.SetWindowTitle(window, windowTitle.." "..math.floor(g_ft:getFPS()).." fps")
            end
        end
        glfw.glfw.SwapBuffers(window)

        bass.BASS_Update(0) -- decrease the chance of missing vsync
    end

    bass.BASS_StreamFree(stream)
    bass.BASS_Free()
end

main()
