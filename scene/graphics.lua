-- graphics.lua

local mm = require("util.matrixmath")

local graphics = {}

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
local scenedir = "scene2"
local scene_names = {
    "vsfstri",
    "colorcube",
}
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
        Scene:render_for_one_eye(v,p)
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

-- A table of handlers for different track name-value pairs coming from
-- the rocket module. Values may be updated by messages from the editor.
-- Keys must match track names sent to editor.
graphics.sync_callbacks = {
    ["Scene"] = function(v)
        -- Switch scenes with an index
        if scenes[v] then Scene = scenes[v] end
    end,
    ["posx"] = function(v)
        if Scene.posx then Scene.posx = v end
    end,
    ["posy"] = function(v)
        if Scene.posy then Scene.posy = v end
    end,
    ["rot"] = function(v)
        if Scene.rot then Scene.rot = v end
    end,
    -- Add new keyframe names here
}

function graphics.sync_params(get_param_value_at_current_time)
    -- The get_param_value_at_current_time function
    -- calls into rocket's track list of keyframes
    -- with the current time(according to main) as a parameter.
    local f = get_param_value_at_current_time
    if not f then return end

    for trackname,_ in pairs(graphics.sync_callbacks) do
        local val = f(trackname)
        local g = graphics.sync_callbacks[trackname]
        if g and val then g(val) end
    end
end

return graphics
