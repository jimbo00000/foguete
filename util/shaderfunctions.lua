-- shaderfunctions.lua
shaderfunctions = {}

local openGL = require("opengl")
local ffi = require("ffi")

-- Types from:
-- https://github.com/nanoant/glua/blob/master/init.lua
local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glCharv    = ffi.typeof('GLchar[?]')
local glSizeiv   = ffi.typeof('GLsizei[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')
local glConstCharpp = ffi.typeof('const GLchar *[1]')

function load_and_compile_shader_source(src, type)
    local sourcep = glCharv(#src + 1)
    ffi.copy(sourcep, src)
    local sourcepp = glConstCharpp(sourcep)
    local s = gl.CreateShader(type)
    gl.ShaderSource(s, 1, sourcepp, NULL)
    gl.CompileShader(s)

    local ill = glIntv(0)
    gl.GetShaderiv(s, GL.INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.GetShaderInfoLog(s, ill[0], cw, logp)
        print("__ShaderInfoLog: "..ffi.string(logp))
        return 0
    end

    local success = glIntv(0)
    gl.GetShaderiv(s, GL.COMPILE_STATUS, success);
    assert(success[0] == GL.TRUE)

    return s
end

function shaderfunctions.make_shader_from_source(sources)
    local program = gl.CreateProgram()

    -- Deleted shaders, once attached, will be deleted when program is.
    if type(sources.vsrc) == "string" then
        vs = load_and_compile_shader_source(sources.vsrc, GL.VERTEX_SHADER)
        gl.AttachShader(program, vs)
        gl.DeleteShader(vs)
    end
    if type(sources.tcsrc) == "string" then
        tcs = load_and_compile_shader_source(sources.tcsrc, GL.TESS_CONTROL_SHADER)
        gl.AttachShader(program, tcs)
        gl.DeleteShader(tcs)
    end
    if type(sources.tesrc) == "string" then
        tes = load_and_compile_shader_source(sources.tesrc, GL.TESS_EVALUATION_SHADER)
        gl.AttachShader(program, tes)
        gl.DeleteShader(tes)
    end
    if type(sources.gsrc) == "string" then
        gs = load_and_compile_shader_source(sources.gsrc, GL.GEOMETRY_SHADER)
        gl.AttachShader(program, gs)
        gl.DeleteShader(gs)
    end
    if type(sources.fsrc) == "string" then
        fs = load_and_compile_shader_source(sources.fsrc, GL.FRAGMENT_SHADER)
        gl.AttachShader(program, fs)
        gl.DeleteShader(fs)
    end
    if type(sources.compsrc) == "string" then
        comps = load_and_compile_shader_source(sources.compsrc, GL.COMPUTE_SHADER)
        gl.AttachShader(program, comps)
        gl.DeleteShader(comps)
    end

    gl.LinkProgram(program)

    local ill = glIntv(0)
    gl.GetProgramiv(program, GL.INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.GetProgramInfoLog(program, ill[0], cw, logp)
        print("__ProgramInfoLog: "..ffi.string(logp))
        os.exit()
        return 0
    end

    gl.UseProgram(0)
    return program
end

return shaderfunctions
