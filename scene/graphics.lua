-- graphics.lua

local mm = require("util.matrixmath")

local graphics = {}

local current_scene_name = "scene.vsfstri"
local Scene = require(current_scene_name)
local current_effect_idx = 1
local PostFX = nil

-- Window info
local win_w = 800
local win_h = 600
local fb_w = win_w
local fb_h = win_h

-- Camera controls
graphics.objrot = {0,0}
graphics.camerapan = {0,0,0}
graphics.chassis = {0,0,1}

graphics.clearlum = .2

function graphics.GetScene()
    return Scene
end

function graphics.GetSceneName()
    return current_scene_name
end

local scene_modules = {
    "scene.vsfstri",
}
local scene_module_idx = 1
function graphics.switch_scene(reverse)
    if reverse then
        scene_module_idx = scene_module_idx - 1
        if scene_module_idx < 1 then scene_module_idx = #scene_modules end
    else
        scene_module_idx = scene_module_idx + 1
        if scene_module_idx > #scene_modules then scene_module_idx = 1 end
    end
    graphics.switch_to_scene(scene_modules[scene_module_idx])
end

local loaded_scenes = {}

function graphics.switch_scene_and_reinit(reverse)
    graphics.switch_scene(reverse)
    if Scene then
        Scene.exitGL()
        Scene = nil

        local name = current_scene_name
        package.loaded[name] = nil
        Scene = require(name)
        Scene.initGL()
        loaded_scenes[name] = Scene
    end
end

function graphics.load_all_scenes()
    for k,name in pairs(scene_modules) do
        local sce = require(name)
        if sce then
            local now = os.clock()
            sce.initGL()
            local initTime = os.clock() - now
            print(name.." initGL: "..math.floor(1000*initTime).."ms")
        end
        loaded_scenes[name] = sce
    end
end

function graphics.switch_to_scene(name)
    if name == current_scene_name then return end
    current_scene_name = name
    print("Switch scene", name)
    Scene = loaded_scenes[name]
end


local effect_modules = {
    nil,
    "effect.onepassblur_effect",
    "effect.vignette",
}

local loaded_effects = {}

function graphics.load_all_effects()
    for k,name in pairs(effect_modules) do
        local eff = require(name)
        if eff then
            local now = os.clock()
            eff.initGL()
            local initTime = os.clock() - now
            print(name.." initGL: "..math.floor(1000*initTime).."ms")
        end
        loaded_effects[k] = eff
    end
end

function graphics.switch_to_effect(idx)
    if idx == current_effect_idx then return end
    PostFx = loaded_effects[idx]
    current_effect_idx = idx
    print("Switch effect", idx)
end


function graphics.initGL()
    graphics.load_all_scenes()
    graphics.load_all_effects()

    if Scene then Scene.initGL() end
    if PostFX then PostFX.initGL(win_w, win_h) end

    for k=1,#loaded_effects do
        local p = loaded_effects[k]
        if p then p.resize_fbo(win_w,win_h) end
    end
end

function graphics.display()
    -- Render scenes to texture for post processing
    if PostFx then
        PostFx.bind_fbo()
    else
        gl.Viewport(0,0, fb_w, fb_h)
    end

    local b = graphics.clearlum
    gl.ClearColor(b,b,b,0)
    gl.Clear(GL.COLOR_BUFFER_BIT + GL.DEPTH_BUFFER_BIT)
    gl.Enable(GL.DEPTH_TEST)

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
        Scene.render_for_one_eye(v,p)
        if Scene.set_origin_matrix then Scene.set_origin_matrix(v) end
    end

    if PostFx then PostFx.unbind_fbo() end

    -- Apply post-processing and present
    if PostFx then
        gl.Disable(GL.DEPTH_TEST)
        gl.Viewport(0,0, win_w, win_h)
        PostFx.present(win_w, win_h)
    end
end


function graphics.resize(w, h)
    win_w, win_h = w, h
    fb_w, fb_h = win_w, win_h

    if Scene then
        if Scene.resize_window then Scene.resize_window(w, h) end
    end

    for k=1,#loaded_effects do
        local p = loaded_effects[k]
        if p then p.resize_fbo(win_w,win_h) end
    end
end

function graphics.timestep(absTime, dt)
    --animParams.tparam = math.abs(math.sin(absTime))
    if Scene then Scene.timestep(absTime, dt) end
end

function graphics.setbpm(bpm)
    Scene.BPM = bpm
end

-- A table of handlers for different track name-value pairs coming from
-- either the Rocket editor or a saved list of keyframes.
graphics.sync_callbacks = {
    ["Scene"] = function(i)
        local s = scene_modules[i]
        graphics.switch_to_scene(s)
    end,
    ["PostFx"] = function(i)
        graphics.switch_to_effect(i)
    end,
    ["tri.rotationz"] = function(i)
        if Scene.rotationz then Scene.rotationz = i end
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
        if g then g(val) end
    end
end

return graphics
