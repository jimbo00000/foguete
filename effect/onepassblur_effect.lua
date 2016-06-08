-- onepassblur_effect.lua
onepassblur_effect = {}

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

// Simple one-pass blurring
#define KERNEL_SIZE 9
float step_x = 1./float(ResolutionX);
float step_y = 1./float(ResolutionY);

vec2 offset[KERNEL_SIZE] = vec2[](
    vec2(-step_x, -step_y), vec2(0.0, -step_y), vec2(step_x, -step_y),
    vec2(-step_x,     0.0), vec2(0.0,     0.0), vec2(step_x,     0.0),
    vec2(-step_x,  step_y), vec2(0.0,  step_y), vec2(step_x,  step_y)
);

float kernel[KERNEL_SIZE] = float[](
#if 0
    1./16., 2./16., 1./16.,
    2./16., 4./16., 2./16.,
    1./16., 2./16., 1./16.

    0., 1., 0.,
    1., -4., 1.,
    0., 1., 0.
#else
    1., 2., 1.,
    0., 0., 0.,
    -1., -2., -1.
#endif
);

void main()
{
    vec4 sum = vec4(0.);
    int i;
    for( i=0; i<KERNEL_SIZE; i++ )
    {
        vec4 tc = texture(tex, vfTexCoord.xy + offset[i]);
        sum += tc * kernel[i];
    }
    if (sum.x + sum.y + sum.z > .1)
        sum = vec4(vec3(1.)-sum.xyz,1.);
    fragColor = sum;
}
]]

function onepassblur_effect.initGL()
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

function onepassblur_effect.exitGL()
    for k,v in pairs(vbos) do
        gl.DeleteBuffers(1,v)
    end
    vbos = nil
    gl.DeleteProgram(prog)

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.DeleteVertexArrays(1, vaoId)

    fbf.deallocate_fbo(onepassblur_effect.fbo)
end

local function draw_fullscreen_quad()
    gl.BindVertexArray(vao)
    gl.DrawElements(GL.TRIANGLES, 3*2, GL.UNSIGNED_INT, nil)
    gl.BindVertexArray(0)
end

function onepassblur_effect.present_texture(texId, resx, resy)
    gl.UseProgram(prog)

    gl.ActiveTexture(GL.TEXTURE0)
    gl.BindTexture(GL.TEXTURE_2D, texId)
    local tx_loc = gl.GetUniformLocation(prog, "tex")
    gl.Uniform1i(tx_loc, 0)

    local rx_loc = gl.GetUniformLocation(prog, "ResolutionX")
    gl.Uniform1i(rx_loc, resx)
    local ry_loc = gl.GetUniformLocation(prog, "ResolutionY")
    gl.Uniform1i(ry_loc, resy)

    draw_fullscreen_quad()

    gl.UseProgram(0)
end

function onepassblur_effect.bind_fbo()
    if fbo then fbf.bind_fbo(onepassblur_effect.fbo) end
end

function onepassblur_effect.unbind_fbo()
    fbf.unbind_fbo()
end

function onepassblur_effect.resize_fbo(w,h)
    local e = onepassblur_effect
    if e.fbo then fbf.deallocate_fbo(e.fbo) end
    e.fbo = fbf.allocate_fbo(w,h)
end

function onepassblur_effect.present()
    local e = onepassblur_effect
    local f = e.fbo
    e.present_texture(f.tex, f.w, f.h)
end

return onepassblur_effect
