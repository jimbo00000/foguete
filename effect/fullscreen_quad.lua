-- fullscreen_quad.lua
-- Creates the vertex and color attributes for a fullscreen quad.

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
    local vcol_loc = gl.GetAttribLocation(prog, "vColor")

    local vvbo = glIntv(0)
    gl.GenBuffers(1, vvbo)
    gl.BindBuffer(GL.ARRAY_BUFFER, vvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.STATIC_DRAW)
    gl.VertexAttribPointer(vpos_loc, 2, GL.FLOAT, GL.FALSE, 0, nil)
    table.insert(vbos, vvbo)

    local cvbo = glIntv(0)
    gl.GenBuffers(1, cvbo)
    gl.BindBuffer(GL.ARRAY_BUFFER, cvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.DYNAMIC_DRAW)
    gl.VertexAttribPointer(vcol_loc, 2, GL.FLOAT, GL.FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.EnableVertexAttribArray(vpos_loc)
    gl.EnableVertexAttribArray(vcol_loc)

    local quads = glUintv(3*2, {
        1,0,2,
        2,0,3,
    })
    local qvbo = glIntv(0)
    gl.GenBuffers(1, qvbo)
    gl.BindBuffer(GL.ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.BufferData(GL.ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.STATIC_DRAW)
    table.insert(vbos, qvbo)

    return vbos
end

return fullscreen_quad
