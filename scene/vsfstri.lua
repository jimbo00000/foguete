--[[ vsfstri.lua

    The simplest example of a using a vertex shader(vs)
    and a fragment shader(fs) to draw a triangle(tri).

    Vertex attributes are created in a function called from initGL.
    The same array is used for both locations and colors.
    The shaders used to do the drawing are a simple passthrough,
    applying the modelview and projection matrices to position vertices
    and passing the color rgb(xyz) values directly through to output.
]]
vsfstri = {}

vsfstri.__index = vsfstri

function vsfstri.new(...)
    local self = setmetatable({}, vsfstri)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function vsfstri:init()
    -- Object-internal state: hold a list of VBOs for deletion on exitGL
    self.vbos = {}
    self.vao = 0
    self.prog = 0

    -- These fields may be changed by rocket
    self.posx = 0
    self.posy = 0
    self.rot = 0
    self.scale = 1
    self.col = 1
end

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local mm = require("util.matrixmath")

local glIntv = ffi.typeof('GLint[?]')
local glUintv = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local basic_vert = [[
#version 100

attribute vec4 vPosition;
attribute vec4 vColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

varying vec3 vfColor;

void main()
{
    vfColor = vColor.xyz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]


local basic_frag = [[
#version 100

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform float col;

varying vec3 vfColor;

void main()
{
    gl_FragColor = vec4(col * vfColor, 1.0);
}
]]

function vsfstri:init_tri_attributes()
    local verts = glFloatv(3*3, {
        0,0,0,
        1,0,0,
        0,1,0,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(self.prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)
end

function vsfstri:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self:init_tri_attributes()
    gl.glBindVertexArray(0)
end

function vsfstri:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
    gl.glBindVertexArray(0)
end

function vsfstri:renderEye(model, view, proj)
    -- Overwrite any "member" vars with values from a specific rocket sub-table
    local myTable = "tri"
    if self.syncVars and self.syncVars[myTable] then
        for k,v in pairs(self.syncVars[myTable]) do
            self[k] = v
        end
    end

    local m = {}
    for i=1,16 do m[i] = view[i] end
    mm.glh_translate(m, self.posx, self.posy, 0)
    mm.glh_rotate(m, self.rot, 0,0,1)
    mm.glh_scale(m, self.scale, self.scale, self.scale)

    gl.glUseProgram(self.prog)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    local uc_loc = gl.glGetUniformLocation(self.prog, "col")
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniform1f(uc_loc, self.col)
    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

function vsfstri:timestep(absTime, dt)
end

function vsfstri:onSingleTouch(pointerid, action, x, y)
    --print("vsfstri.onSingleTouch",pointerid, action, x, y)
end

return vsfstri
