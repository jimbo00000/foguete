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

local scenedir = "scene2"
function graphics.switch_to_scene(name)
    local fullname = scenedir.."."..name
    if Scene and Scene.exitGL then
        Scene:exitGL()
    end
    -- Do we need to unload the module?
    package.loaded[fullname] = nil
    Scene = nil

    if not Scene then
        local SceneLibrary = require(fullname)
        Scene = SceneLibrary.new()
        if Scene then
            if Scene.setDataDirectory then Scene:setDataDirectory("data") end
            Scene:initGL()
        end
    end
end


function graphics.initGL()
    graphics.switch_to_scene("vsfstri")
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
-- either the Rocket editor or a saved list of keyframes.
graphics.sync_callbacks = {
    ["posx"] = function(v)
        if Scene.posx then Scene.posx = v end
    end,
    ["posy"] = function(v)
        if Scene.posy then Scene.posy = v end
    end,
    -- Add new keyframe names here
}

function graphics.sync_params(get_cur_param)
    -- The get_cur_param function is passed in from the calling main func
    local f = get_cur_param
    if not f then return end

    for k,_ in pairs(graphics.sync_callbacks) do
        local g = graphics.sync_callbacks[k]
        local val = f(k)
        if g and val then g(val) end
    end
end

return graphics
