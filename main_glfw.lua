-- main_glfw.lua

local ffi = require("ffi")
local glfw = require("glfw")
local openGL = require("opengl")
openGL.loader = glfw.glfw.GetProcAddress
openGL:import()
local DEBUG = false

local gfx = require("scene.graphics")

local mm = require("util.matrixmath")
local fpstimer = require("util.fpstimer")

local win_w = 800
local win_h = 600
local fb_w = win_w
local fb_h = win_h
local g_ft = fpstimer.create()
local clickpos = {0,0}
local clickrot = {0,0}
local holding = false
local keymove = {0,0,0}
local altdown = false
local ctrldown = false
local shiftdown = false
local keystates = {}
for i=0, glfw.GLFW.KEY_LAST do
    keystates[i] = glfw.GLFW.RELEASE
end

function onkey(window,k,code,action,mods)
    keystates[k] = action
    altdown = 0 ~= bit.band(mods, glfw.GLFW.MOD_ALT)
    ctrldown = 0 ~= bit.band(mods, glfw.GLFW.MOD_CONTROL)
    shiftdown = 0 ~= bit.band(mods, glfw.GLFW.MOD_SHIFT)

    local effect_func = function(x)
        gfx.switch_to_effect(k - glfw.GLFW.KEY_F1 + 1)
    end

    local func_table_ctrl = {
        [glfw.GLFW.KEY_GRAVE_ACCENT] = function (x) gfx.switch_scene_and_reinit(shiftdown) end,
        [glfw.GLFW.KEY_TAB] = function (x) gfx.switch_scene_and_reinit(shiftdown) end,
    }
    local func_table = {
        [glfw.GLFW.KEY_ESCAPE] = function (x) glfw.glfw.SetWindowShouldClose(window, 1) end,
        [glfw.GLFW.KEY_F1] = effect_func,
        [glfw.GLFW.KEY_F2] = effect_func,
        [glfw.GLFW.KEY_F3] = effect_func,
        [glfw.GLFW.KEY_F] = function (x) gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL) end,
        [glfw.GLFW.KEY_L] = function (x) gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE) end,
        [glfw.GLFW.KEY_R] = function (x) chassis = {0,0,1} end,
        [glfw.GLFW.KEY_SPACE] = function (x) camerapan = {0,0,0} end,

        [glfw.GLFW.KEY_ENTER] = function (x)
            if Scene and Scene.shoot then
                Scene.shoot()
            end
        end,
    }
    if action == glfw.GLFW.PRESS or action == glfw.GLFW.REPEAT then
        if ctrldown then
            local f = func_table_ctrl[k]
            if f then f() end
        else
            local f = func_table[k]
            if f then f() end
        end
    end

    local mag = 1
    local spd = 10
    local km = {0,0,0}
    if keystates[glfw.GLFW.KEY_W] ~= glfw.GLFW.RELEASE then km[3] = km[3] + -spd end -- -z forward
    if keystates[glfw.GLFW.KEY_S] ~= glfw.GLFW.RELEASE then km[3] = km[3] - -spd end
    if keystates[glfw.GLFW.KEY_A] ~= glfw.GLFW.RELEASE then km[1] = km[1] - spd end
    if keystates[glfw.GLFW.KEY_D] ~= glfw.GLFW.RELEASE then km[1] = km[1] + spd end
    if keystates[glfw.GLFW.KEY_Q] ~= glfw.GLFW.RELEASE then km[2] = km[2] - spd end
    if keystates[glfw.GLFW.KEY_E] ~= glfw.GLFW.RELEASE then km[2] = km[2] + spd end
    if keystates[glfw.GLFW.KEY_UP] ~= glfw.GLFW.RELEASE then km[3] = km[3] + -spd end
    if keystates[glfw.GLFW.KEY_DOWN] ~= glfw.GLFW.RELEASE then km[3] = km[3] - -spd end
    if keystates[glfw.GLFW.KEY_LEFT] ~= glfw.GLFW.RELEASE then km[1] = km[1] - spd end
    if keystates[glfw.GLFW.KEY_RIGHT] ~= glfw.GLFW.RELEASE then km[1] = km[1] + spd end

    if keystates[glfw.GLFW.KEY_LEFT_CONTROL] ~= glfw.GLFW.RELEASE then mag = 10 * mag end
    if keystates[glfw.GLFW.KEY_LEFT_SHIFT] ~= glfw.GLFW.RELEASE then mag = .1 * mag end
    for i=1,3 do
        keymove[i] = km[i] * mag
    end
end

-- Passing raw character values to scene lets us get away with not
-- including glfw key enums in scenes.
function onchar(window,ch)
    local Scene = gfx.GetScene()
    if Scene.keypressed then
        Scene.keypressed(string.char(ch))
    end
end

function onclick(window, button, action, mods)
    if action == glfw.GLFW.PRESS then
        holding = button
        local double_buffer = ffi.new("double[2]")
        glfw.glfw.GetCursorPos(window, double_buffer, double_buffer+1)
        local x,y = double_buffer[0], double_buffer[1]
        clickpos = {x,y}
        clickrot = {gfx.objrot[1], gfx.objrot[2]}
    elseif action == glfw.GLFW.RELEASE then
        holding = nil
    end
end

function onmousemove(window, x, y)
    local Scene = gfx.GetScene()
    if holding == glfw.GLFW.MOUSE_BUTTON_1 then
        gfx.objrot[1] = clickrot[1] + x-clickpos[1]
        gfx.objrot[2] = clickrot[2] + y-clickpos[2]
        if Scene.onmouse ~= nil then
            Scene.onmouse(x/win_w, y/win_h)
        end
    elseif holding == glfw.GLFW.MOUSE_BUTTON_2 then
        local s = .01
        if ctrldown then s = s * 10 end
        if shiftdown then s = s / 10 end
        gfx.camerapan[1] = s * (x-clickpos[1])
        gfx.camerapan[2] = -s * (y-clickpos[2])
    end
end

function onwheel(window,x,y)
    local s = 1
    if ctrldown then s = s * 10 end
    if shiftdown then s = s / 10 end
    gfx.camerapan[3] = gfx.camerapan[3] - s * y
end

function resize(window, w, h)
    win_w, win_h = w, h
    fb_w, fb_h = w,h
    gfx.resize(w,h)
end

function initGL()
    if gfx then gfx.initGL() end
end

function display()
    gfx.display()
end

function timestep(absTime, dt)
    if gfx then gfx.timestep(absTime, dt) end
    for i=1,3 do
        gfx.chassis[i] = gfx.chassis[i] + dt * keymove[i]
    end
end

ffi.cdef[[
typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLsizei;
typedef char GLchar;
///@todo APIENTRY
typedef void (__stdcall *GLDEBUGPROC)(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userParam);
]]

local count = 0
local myCallback = ffi.cast("GLDEBUGPROC", function(source, type, id, severity, length, message, userParam)
    if severity == GL.DEBUG_SEVERITY_NOTIFICATION then return end
    local enum_table = {
        [tonumber(GL.DEBUG_SEVERITY_HIGH)] = "SEVERITY_HIGH",
        [tonumber(GL.DEBUG_SEVERITY_MEDIUM)] = "SEVERITY_MEDIUM",
        [tonumber(GL.DEBUG_SEVERITY_LOW)] = "SEVERITY_LOW",
        [tonumber(GL.DEBUG_SEVERITY_NOTIFICATION)] = "SEVERITY_NOTIFICATION",
        [tonumber(GL.DEBUG_SOURCE_API)] = "SOURCE_API",
        [tonumber(GL.DEBUG_SOURCE_WINDOW_SYSTEM)] = "SOURCE_WINDOW_SYSTEM",
        [tonumber(GL.DEBUG_SOURCE_SHADER_COMPILER)] = "SOURCE_SHADER_COMPILER",
        [tonumber(GL.DEBUG_SOURCE_THIRD_PARTY)] = "SOURCE_THIRD_PARTY",
        [tonumber(GL.DEBUG_SOURCE_APPLICATION)] = "SOURCE_APPLICATION",
        [tonumber(GL.DEBUG_SOURCE_OTHER)] = "SOURCE_OTHER",
        [tonumber(GL.DEBUG_TYPE_ERROR)] = "TYPE_ERROR",
        [tonumber(GL.DEBUG_TYPE_DEPRECATED_BEHAVIOR)] = "TYPE_DEPRECATED_BEHAVIOR",
        [tonumber(GL.DEBUG_TYPE_UNDEFINED_BEHAVIOR)] = "TYPE_UNDEFINED_BEHAVIOR",
        [tonumber(GL.DEBUG_TYPE_PORTABILITY)] = "TYPE_PORTABILITY",
        [tonumber(GL.DEBUG_TYPE_PERFORMANCE)] = "TYPE_PERFORMANCE",
        [tonumber(GL.DEBUG_TYPE_MARKER)] = "TYPE_MARKER",
        [tonumber(GL.DEBUG_TYPE_PUSH_GROUP)] = "TYPE_PUSH_GROUP",
        [tonumber(GL.DEBUG_TYPE_POP_GROUP)] = "TYPE_POP_GROUP",
        [tonumber(GL.DEBUG_TYPE_OTHER)] = "TYPE_OTHER",
    }
    print(enum_table[source], enum_table[type], enum_table[severity], id)
    print("   "..ffi.string(message))
    print("   Stack Traceback\n   ===============")
    -- Chop off the first lines of the traceback, as it's always this function.
    local tb = debug.traceback()
    local i = string.find(tb, '\n')
    local i = string.find(tb, '\n', i+1)
    print(string.sub(tb,i+1,-1))
end)

function main()
    for k,v in pairs(arg) do
        if k > 0 then
            if v == '-d' then DEBUG = true end
        end
    end

    glfw.glfw.Init()

    glfw.glfw.WindowHint(glfw.GLFW.DEPTH_BITS, 16)
    if ffi.os == "OSX" then
        -- GL context 4.3 request causes MacOS to segfault.
        -- Maybe Apple lacks the resources to implement current standard support.
        glfw.glfw.WindowHint(glfw.GLFW.CONTEXT_VERSION_MAJOR, 3)
        glfw.glfw.WindowHint(glfw.GLFW.CONTEXT_VERSION_MINOR, 3)
    else
        glfw.glfw.WindowHint(glfw.GLFW.CONTEXT_VERSION_MAJOR, 4)
        glfw.glfw.WindowHint(glfw.GLFW.CONTEXT_VERSION_MINOR, 3)
    end
    glfw.glfw.WindowHint(glfw.GLFW.OPENGL_FORWARD_COMPAT, 1)
    glfw.glfw.WindowHint(glfw.GLFW.OPENGL_PROFILE, glfw.GLFW.OPENGL_CORE_PROFILE)
    if DEBUG then
        glfw.glfw.WindowHint(glfw.GLFW.OPENGL_DEBUG_CONTEXT, GL.TRUE)
    end

    window = glfw.glfw.CreateWindow(win_w,win_h,"Luajit",nil,nil)
    local int_buffer = ffi.new("int[2]")
    -- Get actual framebuffer size for oversampled ("Retina") displays
    glfw.glfw.GetFramebufferSize(window, int_buffer, int_buffer+1)
    fb_w = int_buffer[0]
    fb_h = int_buffer[1]
    glfw.glfw.SetKeyCallback(window, onkey)
    glfw.glfw.SetCharCallback(window, onchar);
    glfw.glfw.SetMouseButtonCallback(window, onclick)
    glfw.glfw.SetCursorPosCallback(window, onmousemove)
    glfw.glfw.SetScrollCallback(window, onwheel)
    glfw.glfw.SetWindowSizeCallback(window, resize)
    glfw.glfw.MakeContextCurrent(window)
    glfw.glfw.SwapInterval(1)

    if DEBUG then
        gl.DebugMessageCallback(myCallback, nil)
        gl.DebugMessageControl(GL.DONT_CARE, GL.DONT_CARE, GL.DONT_CARE, 0, nil, GL.TRUE)
        gl.DebugMessageInsert(GL.DEBUG_SOURCE_APPLICATION, GL.DEBUG_TYPE_MARKER, 0,
            GL.DEBUG_SEVERITY_NOTIFICATION, -1 , "Start debugging")
        gl.Enable(GL.DEBUG_OUTPUT_SYNCHRONOUS);
    end

    local windowTitle = "OpenGL with Luajit"
    local lastFrameTime = 0
    initGL()
    while glfw.glfw.WindowShouldClose(window) == 0 do
        glfw.glfw.PollEvents()
        g_ft:onFrame()
        display()

        local now = os.clock()
        timestep(now, now - lastFrameTime)
        lastFrameTime = now

        if (ffi.os == "Windows") then
            windowTitle = gfx.GetSceneName()
            glfw.glfw.SetWindowTitle(window, windowTitle.." "..math.floor(g_ft:getFPS()).." fps")
        end

        glfw.glfw.SwapBuffers(window)
    end
end

main()
