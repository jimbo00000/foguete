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

--[[
    Music attributes:
    SimpleBeat.wav - length 3.2s, 8 beats
    8 / 3.2 == 2.5 beats.second *60 == 150 bpm
]]
local bpm = 150
local song_end = 3.2

local rpb = 8 -- rows per beat
local row_rate = (bpm / 60) * rpb
local row_time = 0.0
local current_row = 0
local last_sent_row = 0
local paused = 1
local stream = nil

local g_lastFrameTime = 0
local g_lastFilterSwapTime = 0
local g_ft = fpstimer.create()
local animParams = {}

function bass_get_time()
    if stream then
        local pos = bass.BASS_ChannelGetPosition(stream, bass.BASS_POS_BYTE)
        local time = bass.BASS_ChannelBytes2Seconds(stream, pos)
        local startTime = .0 -- Start of first beat according to audacity
        local fudge = 0 --.12 -- Line hits up to beat visually

        -- TODO: why is there half a beat discrepancy when running without sync?
        --fudge = fudge - 0.48385126/2

        return time - startTime - fudge
    end
end

function bass_get_row()
    if stream then
        return bass_get_time() * row_rate
    end
end

function cb_pause(flag)
    if stream then
        if flag == 1 then
            bass.BASS_ChannelPause(stream)
        else
            bass.BASS_ChannelPlay(stream, false)
        end
    end
end

function cb_setrow(row)
    current_row = row
    last_sent_row = row
    row_time = row / row_rate

    local pos = bass.BASS_ChannelSeconds2Bytes(stream, row / row_rate)
    bass.BASS_ChannelSetPosition(stream, pos, bass.BASS_POS_BYTE)
end

function cb_isplaying()
    return (bass.BASS_ChannelIsActive(stream) == bass.BASS_ACTIVE_PLAYING)
end

local cbs = {
    cb_pause,
    cb_setrow,
    cb_isplaying
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
    return rk.get_value(pname, current_row)
end

function timestep(absTime, dt)
    gfx.sync_params(get_current_param_value_by_name)

    if cb_isplaying() then
        row_time = row_time + dt
        current_row = row_rate * row_time
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
    print(a[0],b[0],c[0])


    if arg[1] and arg[1] == "sync" then
        SYNC_PLAYER = 1
    end

    if SYNC_PLAYER then
        local success = rk.connect_demo()
        -- Sort keys before inserting
        alphakeys = {}
        for n in pairs(gfx.sync_callbacks) do table.insert(alphakeys, n) end
        table.sort(alphakeys)
        for _,k in ipairs(alphakeys) do
            print("Create track: ",k)
            rk.create_track(k)
            rk.send_track_name(rk.obj, k)
        end
    else
        --print("Load tracks from file")
        local tracks_module = 'keyframes.tracks'
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

    gfx.setbpm(bpm)
    --gfx.reset_camera_to_initial()

    bass.BASS_Start()
    bass.BASS_ChannelPlay(stream, false)

    --if true then
        glfw.glfw.SwapInterval(1)
   -- else
        --glfw.glfw.SwapInterval(0)
    --end

    g_lastFrameTime = 0
    local gcc = 0 -- collect garbage every n cycles
    while glfw.glfw.WindowShouldClose(window) == 0 do
        if SYNC_PLAYER then
            local uret = rk.sync_update(rocket.obj, current_row, cbs)
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
            if now > song_end then
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
