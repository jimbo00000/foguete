-- fullscreen_quad.lua
-- Creates the vertex attributes for a fullscreen quad.

fullscreen_quad = {}

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

function fullscreen_quad.make_quad_vbos(prog)
    vbos = {}

    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })

    local vpos_loc = gl.GetAttribLocation(prog, "vPosition")

    local vvbo = glIntv(0)
    gl.GenBuffers(1, vvbo)
    gl.BindBuffer(GL.ARRAY_BUFFER, vvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.STATIC_DRAW)
    gl.VertexAttribPointer(vpos_loc, 2, GL.FLOAT, GL.FALSE, 0, nil)
    table.insert(vbos, vvbo)

    gl.EnableVertexAttribArray(vpos_loc)

    local quads = glUintv(3*2, {
        0,1,2,
        0,2,3,
    })
    local qvbo = glIntv(0)
    gl.GenBuffers(1, qvbo)
    gl.BindBuffer(GL.ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.BufferData(GL.ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.STATIC_DRAW)
    table.insert(vbos, qvbo)

    return vbos
end

return fullscreen_quad
