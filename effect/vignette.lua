-- vignette.lua
vignette = {}

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")
local fsq = require("effect.fullscreen_quad")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vao = 0
local prog = 0
local vbos = {}

vignette.factor = .25

local basic_vert = [[
#version 410 core

in vec4 vPosition;
in vec4 vColor;
out vec3 vfTexCoord;

void main()
{
    vfTexCoord = vec3(.5*(vColor.xy+1.),0.);
    gl_Position = vec4(vPosition.xy, 0., 1.);
}
]]

local basic_frag = [[
#version 330

in vec3 vfTexCoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform int ResolutionX;
uniform int ResolutionY;
uniform float uVigFactor;

void main()
{
    vec2 uv = vfTexCoord.xy;
    vec3 texcol = texture(tex, uv).rgb;

    // https://www.shadertoy.com/view/lsKSWR
    uv *=  1.0 - uv.yx;   //vec2(1.0)- uv.yx; -> 1.-u.yx; Thanks FabriceNeyret !
    float vig = uv.x*uv.y * 15.0; // multiply with sth for intensity
    vig = pow(vig, uVigFactor); // change pow for modifying the extend of the  vignette

    fragColor = vec4(texcol * vig, 1.);
}
]]

function vignette.initGL()
    vbos = {}
    texs = {}
    local vaoId = ffi.new("int[1]")
    gl.GenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.BindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })
    vbos = fsq.make_quad_vbos(prog)

    gl.BindVertexArray(0)
end

function vignette.exitGL()
    for k,v in pairs(vbos) do
        gl.DeleteBuffers(1,v)
    end
    vbos = nil
    gl.DeleteProgram(prog)

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.DeleteVertexArrays(1, vaoId)

    fbf.deallocate_fbo(vignette.fbo)
end

local function draw_fullscreen_quad()
    gl.BindVertexArray(vao)
    gl.DrawElements(GL.TRIANGLES, 3*2, GL.UNSIGNED_INT, nil)
    gl.BindVertexArray(0)
end

function vignette.present_texture(texId, resx, resy)
    gl.UseProgram(prog)

    gl.ActiveTexture(GL.TEXTURE0)
    gl.BindTexture(GL.TEXTURE_2D, texId)
    local tx_loc = gl.GetUniformLocation(prog, "tex")
    gl.Uniform1i(tx_loc, 0)

    local rx_loc = gl.GetUniformLocation(prog, "ResolutionX")
    gl.Uniform1i(rx_loc, resx)
    local ry_loc = gl.GetUniformLocation(prog, "ResolutionY")
    gl.Uniform1i(ry_loc, resy)

    local vf_loc = gl.GetUniformLocation(prog, "uVigFactor")
    gl.Uniform1f(vf_loc, vignette.factor)

    draw_fullscreen_quad()

    gl.UseProgram(0)
end

function vignette.bind_fbo()
    if fbo then fbf.bind_fbo(vignette.fbo) end
end

function vignette.unbind_fbo()
    fbf.unbind_fbo()
end

function vignette.resize_fbo(w,h)
    local e = vignette
    if e.fbo then fbf.deallocate_fbo(e.fbo) end
    e.fbo = fbf.allocate_fbo(w,h)
end

function vignette.present()
    local e = vignette
    local f = e.fbo
    e.present_texture(f.tex, f.w, f.h)
end

return vignette
