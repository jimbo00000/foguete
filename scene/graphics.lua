-- graphics.lua
local graphics = {}

local scene_names = {
    "vsfstri",
    "colorcube",
    -- Add new scenes here
}

local trackNames = {
    "Scene",
    "cube:rot",
    "tri:col",
    "tri:posx",
    "tri:posy",
    "tri:rot",
    "tri:scale",
    -- Add new keyframe names here
}

-- main_demo reports all these to the Editor on launch
graphics.trackNames = trackNames

local mm = require("util.matrixmath")

-- Window info
local win_w = 800
local win_h = 600
local fb_w = win_w
local fb_h = win_h

-- Camera controls
graphics.objrot = {0,0}
graphics.camerapan = {0,0,0}
graphics.chassis = {0,0,1}

local Scene = nil
local scenedir = "scene"
local scenes = {}

-- Load  and call initGL on all scenes at startup
function graphics.initGL()
    for _,name in pairs(scene_names) do
        local fullname = scenedir..'.'..name
        local SceneLibrary = require(fullname)
        s = SceneLibrary.new()
        if s then
            if s.setDataDirectory then s:setDataDirectory("data") end
            s:initGL()
        end
        table.insert(scenes, s)
    end
    Scene = scenes[1]
end

function graphics.prerender()
    gl.glDrawBuffer(GL.GL_NONE)
    for k,v in pairs(scenes) do
        local i = {}
        mm.make_identity_matrix(i)
        v:renderEye(i,i,i)
    end
    gl.glDrawBuffer(GL.GL_BACK)
end

function graphics.display()
    local b = .3
    gl.glClearColor(b,b,b,0)
    gl.glClear(GL.GL_COLOR_BUFFER_BIT + GL.GL_DEPTH_BUFFER_BIT)
    gl.glEnable(GL.GL_DEPTH_TEST)

    if Scene then
        local v = {}
        mm.make_identity_matrix(v)

        if altdown then
            -- Lookaround camera
            mm.glh_translate(v, graphics.chassis[1], graphics.chassis[2], graphics.chassis[3])
            mm.glh_translate(v, graphics.camerapan[1], camerapan[2], graphics.camerapan[3])
            mm.glh_rotate(v, -graphics.objrot[1], 0,1,0)
            mm.glh_rotate(v, -graphics.objrot[2], 1,0,0)
        else
            -- Flyaround camera
            mm.glh_rotate(v, graphics.objrot[1], 0,1,0)
            mm.glh_rotate(v, graphics.objrot[2], 1,0,0)
            mm.glh_translate(v, graphics.chassis[1], graphics.chassis[2], graphics.chassis[3])
            mm.glh_translate(v, graphics.camerapan[1], graphics.camerapan[2], graphics.camerapan[3])
        end

        mm.affine_inverse(v)
        local p = {}
        local aspect = win_w / win_h
        mm.glh_perspective_rh(p, 90, aspect, .004, 500)

        local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
        Scene:renderEye(m,v,p)
        if Scene.set_origin_matrix then Scene:set_origin_matrix(v) end
    end
end

function graphics.resize(w, h)
    win_w, win_h = w, h
    fb_w, fb_h = win_w, win_h
end

function graphics.timestep(absTime, dt)
    if Scene and Scene.timestep then Scene:timestep(absTime, dt) end
end

function graphics.setbpm(bpm)
    Scene.BPM = bpm
end

function graphics.sync_params(get_param_value_at_current_time)
    -- The get_param_value_at_current_time function
    -- calls into rocket's track list of keyframes
    -- with the current time(according to main) as a parameter.
    if not get_param_value_at_current_time then return end

    local syncVars = {}
    for _,trackname in pairs(trackNames) do
        -- Split a:b name into a.b as lua tables
        last = trackname
        nextlast = nil
        -- Get last token of x:y colon-delimited string
        for a,b in string.gmatch(trackname, "(%w+):(%w+)") do
            nextlast = a
            last = b
        end

        -- Target a specific sub-table
        local targetTable = syncVars
        if nextlast then
            if not syncVars[nextlast] then
                local subTable = {}
                syncVars[nextlast] = subTable
            end
            targetTable = syncVars[nextlast]
        end

        local val = get_param_value_at_current_time(trackname)
        if val then
            targetTable[last] = val
        end
    end
    Scene = scenes[syncVars.Scene]
    Scene.syncVars = syncVars
end

return graphics
