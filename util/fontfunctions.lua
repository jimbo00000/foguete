-- fontfunctions.lua
fontfunctions = {}

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local bf = require("util.bmfont")
local mm = require("util.matrixmath")

-- Types from:
-- https://github.com/nanoant/glua/blob/master/init.lua
local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glCharv    = ffi.typeof('GLchar[?]')
local glSizeiv   = ffi.typeof('GLsizei[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')
local glConstCharpp = ffi.typeof('const GLchar *[1]')

local g = 0.0
local vao = 0
local prog = 0
local tex = 0
local vvbo
local cvbo
local vbos = {}
local texs = {}
local font

local dataDir = nil
local tex_w, tex_h
fontfunctions.fogDist = 10

local basic_vert = [[
#version 410 core

in vec4 vPosition;
in vec4 vColor;
out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vfColor = vColor.xyz;

    // Billboard quads to face camera
    vec4 txpt =
        mvmtx * vec4(0.,0.,0.,1.)
        + vec4(-2., 4.5, 1., 0.)
        + .015 * vec4(1.,-1.,1.,1.) * vec4(vPosition.xy, 0., 1.);

    //gl_Position = prmtx * txpt;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local basic_frag = [[
#version 330

in vec3 vfColor;
out vec4 fragColor;
uniform sampler2D tex;
uniform float u_fogDist;

void main()
{
    float dist = gl_FragCoord.z / gl_FragCoord.w;
    float m = 1.-exp(-dist/u_fogDist);
    vec3 fogCol = vec3(0.);
    float colBoost = 1.3;
    vec3 texCol = colBoost * texture(tex, vfColor.xy).xyz;

    fragColor = texCol.xyzx;
}
]]

function fontfunctions.setDataDirectory(dir)
    dataDir = dir
end

local function init_cube_attributes()
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })

    local vpos_loc = gl.GetAttribLocation(prog, "vPosition")
    local vcol_loc = gl.GetAttribLocation(prog, "vColor")

    vvbo = glIntv(0)
    gl.GenBuffers(1, vvbo)
    gl.BindBuffer(GL.ARRAY_BUFFER, vvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.STATIC_DRAW)
    gl.VertexAttribPointer(vpos_loc, 2, GL.FLOAT, GL.FALSE, 0, nil)
    table.insert(vbos, vvbo)

    cvbo = glIntv(0)
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
end

function fontfunctions.initGL()
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

    init_cube_attributes()
    gl.BindVertexArray(0)

    local texId = ffi.new("int[1]")
    gl.GenTextures(1, texId);

    --local fontname, texname, tw, th, td, format = 'font.txt', 'font.data', 512, 256, 4, GL.RGBA
    --local fontname, texname, tw, th, td, format = 'arial.fnt', 'arial_0.data', 256, 256, 4, GL.RGBA
    local fontname, texname, tw, th, td, format = 'segoe_ui128.fnt', 'segoe_ui128_0.raw', 512, 512, 4, GL.RGBA
    tex_w = tw
    tex_h = th
    if dataDir then fontname = dataDir .. "/" .. fontname end
    if dataDir then texname = dataDir .. "/" .. texname end

    font = BMFont.new(fontname, nil)
    local inp = io.open(texname, "rb")
    if inp then
        local data = inp:read("*all")
        local pixels = glCharv(tex_w*tex_h*td, data)

        gl.BindTexture(GL.TEXTURE_2D, tex)
        gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR)
        gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR)
        gl.TexImage2D(GL.TEXTURE_2D, 0, format, tex_w, tex_h, 0, format, GL.UNSIGNED_BYTE, pixels)
        gl.BindTexture(GL.TEXTURE_2D, 0)
        table.insert(texs, texId)
    end
end

function fontfunctions.exitGL()
    for k,v in pairs(vbos) do
        print(k,v[0])
        gl.DeleteBuffers(1,v)
    end
    for k,v in pairs(texs) do
        print("deltex:",k,v[0])
        gl.DeleteTextures(1,v)
    end
    vbos = nil
    gl.DeleteProgram(prog)

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.DeleteVertexArrays(1, vaoId)
end

local function draw_letter_func(x, y, char)
    local cx, cy = char.x, char.y
    local cw, ch = char.width, char.height
    local ox, oy = char.xoffset, char.yoffset
    local v = {
        x   +ox, y   +oy,
        x+cw+ox, y   +oy,
        x+cw+ox, y+ch+oy,
        x   +ox, y+ch+oy,
    }
    local verts = glFloatv(4*2, v)

    local pw, ph = tex_w, tex_h
    local t = {
         cx    /pw,  cy    /ph,
        (cx+cw)/pw,  cy    /ph,
        (cx+cw)/pw, (cy+ch)/ph,
         cx    /pw, (cy+ch)/ph,
    }
    local texs = glFloatv(4*2, t)

    gl.BindVertexArray(vao)
    gl.BindBuffer(GL.ARRAY_BUFFER, vvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.STATIC_DRAW)
    
    gl.BindBuffer(GL.ARRAY_BUFFER, cvbo[0])
    gl.BufferData(GL.ARRAY_BUFFER, ffi.sizeof(texs), texs, GL.STATIC_DRAW)
    
    gl.DrawElements(GL.TRIANGLES, 3*2, GL.UNSIGNED_INT, nil)
    gl.BindVertexArray(0)
end

function fontfunctions.render_string(mview, proj, str)
    local umv_loc = gl.GetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.GetUniformLocation(prog, "prmtx")
    gl.UseProgram(prog)
    gl.UniformMatrix4fv(umv_loc, 1, GL.FALSE, glFloatv(16, mview))
    gl.UniformMatrix4fv(upr_loc, 1, GL.FALSE, glFloatv(16, proj))

    gl.ActiveTexture(GL.TEXTURE0)
    gl.BindTexture(GL.TEXTURE_2D, tex)
    local tx_loc = gl.GetUniformLocation(prog, "tex")
    gl.Uniform1i(tx_loc, 0)

    local ufgd_loc = gl.GetUniformLocation(prog, "u_fogDist")
    gl.Uniform1f(ufgd_loc, fontfunctions.fogDist)

    gl.Enable(GL.BLEND)
    gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
    font:drawstring(str, draw_letter_func, 0, 0)
    gl.Disable(GL.BLEND)

    gl.UseProgram(0)
end

function fontfunctions.timestep(dt)
    g = g + dt
end

return fontfunctions
