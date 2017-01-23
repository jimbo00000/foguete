-- shaderfunctions.lua
shaderfunctions = {}

function print_stack_trace()
    local tb = debug.traceback()
    local i = 0
    for x=0,3 do i = string.find(tb, '\n', i+1) end -- Chop off top of call stack(we're here)
    local j = string.find(tb, '\n', i+1) -- Chop off bottom of call stack
    print(string.sub(tb,i+1,j))
end

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
    -- Version replacement for various GL implementations 
    if ffi.os == "OSX" then
        -- MacOS X's inadequate GL support
        src = string.gsub(src, "#version 300 es", "#version 410")
        src = string.gsub(src, "#version 310 es", "#version 410")
    elseif string.match(ffi.string(gl.glGetString(GL.GL_VENDOR)), "ATI") then
        -- AMD's strict standard compliance
        src = string.gsub(src, "#version 300 es", "#version 430")
        src = string.gsub(src, "#version 310 es", "#version 430")
    end
    
    local sourcep = glCharv(#src + 1)
    ffi.copy(sourcep, src)
    local sourcepp = glConstCharpp(sourcep)
    local s = gl.glCreateShader(type)
    gl.glShaderSource(s, 1, sourcepp, NULL)
    gl.glCompileShader(s)

    local ill = glIntv(0)
    gl.glGetShaderiv(s, GL.GL_INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.glGetShaderInfoLog(s, ill[0], cw, logp)
        print("__ShaderInfoLog: \n"..ffi.string(logp))
        print_stack_trace()
        return 0
    end

    local success = glIntv(0)
    gl.glGetShaderiv(s, GL.GL_COMPILE_STATUS, success);
    assert(success[0] == GL.GL_TRUE)

    return s
end

function shaderfunctions.make_shader_from_source(sources)
    local program = gl.glCreateProgram()

    -- Deleted shaders, once attached, will be deleted when program is.
    if type(sources.vsrc) == "string" then
        vs = load_and_compile_shader_source(sources.vsrc, GL.GL_VERTEX_SHADER)
        gl.glAttachShader(program, vs)
        gl.glDeleteShader(vs)
    end
    if type(sources.tcsrc) == "string" then
        tcs = load_and_compile_shader_source(sources.tcsrc, GL.GL_TESS_CONTROL_SHADER)
        gl.glAttachShader(program, tcs)
        gl.glDeleteShader(tcs)
    end
    if type(sources.tesrc) == "string" then
        tes = load_and_compile_shader_source(sources.tesrc, GL.GL_TESS_EVALUATION_SHADER)
        gl.glAttachShader(program, tes)
        gl.glDeleteShader(tes)
    end
    if type(sources.gsrc) == "string" then
        gs = load_and_compile_shader_source(sources.gsrc, GL.GL_GEOMETRY_SHADER)
        gl.glAttachShader(program, gs)
        gl.glDeleteShader(gs)
    end
    if type(sources.fsrc) == "string" then
        fs = load_and_compile_shader_source(sources.fsrc, GL.GL_FRAGMENT_SHADER)
        gl.glAttachShader(program, fs)
        gl.glDeleteShader(fs)
    end
    if type(sources.compsrc) == "string" then
        comps = load_and_compile_shader_source(sources.compsrc, GL.GL_COMPUTE_SHADER)
        gl.glAttachShader(program, comps)
        gl.glDeleteShader(comps)
    end

    gl.glLinkProgram(program)

    local ill = glIntv(0)
    gl.glGetProgramiv(program, GL.GL_INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.glGetProgramInfoLog(program, ill[0], cw, logp)
        print("__ProgramInfoLog: "..ffi.string(logp))
        print_stack_trace()
        --os.exit()
        return 0
    end

    gl.glUseProgram(0)
    return program
end

return shaderfunctions
