-- square.lua
square = {}

local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0

-- Sync variables
square.rotationy = 0
square.rotationz = 0
square.scale = 1


local basic_vert = [[
#version 330

in vec4 vPosition;
in vec4 vColor;

out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vfColor = vColor.xyz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local basic_frag = [[
#version 330

in vec3 vfColor;
out vec4 fragColor;

void main()
{
    fragColor = vec4(vfColor, 1.0);
}
]]


local function init_cube_attributes()
    local verts = glFloatv(3*4, {
        0,0,0,
        1,0,0,
        1,1,0,
        0,1,0,
        })

    local vpos_loc = gl.GetAttribLocation(prog, "vPosition")
    local vcol_loc = gl.GetAttribLocation(prog, "vColor")

    local vvbo = glIntv(0)
    gl.GenBuffers(1, vvbo)
    gl.BindBuffer(GL.ARRAY_BUFFER, vvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.STATIC_DRAW)
    gl.VertexAttribPointer(vpos_loc, 3, GL.FLOAT, GL.FALSE, 0, nil)
    table.insert(vbos, vvbo)

    local cvbo = glIntv(0)
    gl.GenBuffers(1, cvbo)
    gl.BindBuffer(GL.ARRAY_BUFFER, cvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.STATIC_DRAW)
    gl.VertexAttribPointer(vcol_loc, 3, GL.FLOAT, GL.FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.EnableVertexAttribArray(vpos_loc)
    gl.EnableVertexAttribArray(vcol_loc)

    local quads = glUintv(2*3, {
        0,1,2,
        0,2,3,
    })
    local qvbo = glIntv(0)
    gl.GenBuffers(1, qvbo)
    gl.BindBuffer(GL.ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.BufferData(GL.ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.STATIC_DRAW)
    table.insert(vbos, qvbo)
end

function square.initGL()
    local vaoId = ffi.new("int[1]")
    gl.GenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.BindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    init_cube_attributes()
    gl.BindVertexArray(0)
end

function square.exitGL()
    gl.BindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.DeleteBuffers(1,v)
    end
    vbos = {}
    gl.DeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.DeleteVertexArrays(1, vaoId)
end

function square.render_for_one_eye(view, proj)
    local umv_loc = gl.GetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.GetUniformLocation(prog, "prmtx")
    gl.UseProgram(prog)
    gl.UniformMatrix4fv(upr_loc, 1, GL.FALSE, glFloatv(16, proj))

    for h=0,3 do
        local m = {}
        for i=1,16 do m[i] = view[i] end
        mm.glh_rotate(m, square.rotationy, 0,1,0)
        mm.glh_rotate(m, square.rotationz, 0,0,1)
        local s = .5
        mm.glh_scale(m, s,s,s)
        mm.glh_translate(m, h-2,0,0)

        gl.UniformMatrix4fv(umv_loc, 1, GL.FALSE, glFloatv(16, m))
        gl.BindVertexArray(vao)
        gl.DrawElements(GL.TRIANGLES, 3*2, GL.UNSIGNED_INT, nil)
        gl.BindVertexArray(0)
    end

    gl.UseProgram(0)
end

function square.timestep(absTime, dt)
end

return square
