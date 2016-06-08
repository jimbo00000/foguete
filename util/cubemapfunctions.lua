-- cubemapfunctions.lua
cubemapfunctions = {}

local openGL = require("opengl")
local ffi = require("ffi")

function cubemapfunctions.allocate_fbo(w, h)
    fbo = {}
    fbo.w = w
    fbo.h = h

    local fboId = ffi.new("GLuint[1]")
    gl.GenFramebuffers(1, fboId)
    fbo.id = fboId[0]
    gl.BindFramebuffer(GL.FRAMEBUFFER, fbo.id)

    local texId = ffi.new("GLuint[1]")
    gl.GenTextures(1, texId)
    fbo.tex = texId[0]
    gl.BindTexture(GL.TEXTURE_CUBE_MAP, fbo.tex)
    gl.TexParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MIN_FILTER, GL.LINEAR)
    gl.TexParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MAG_FILTER, GL.LINEAR)
    gl.TexParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE)
    gl.TexParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE)
    gl.TexParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_R, GL.CLAMP_TO_EDGE)
    gl.TexParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_COMPARE_MODE, GL.COMPARE_REF_TO_TEXTURE)
    for i=0,5 do
        gl.TexImage2D(GL.TEXTURE_CUBE_MAP_POSITIVE_X+i,
                      0, GL.RGBA8,
                      w, h, 0,
                      GL.RGBA, GL.UNSIGNED_BYTE, nil)
    end

    gl.BindTexture(GL.TEXTURE_CUBE_MAP, 0)
    gl.FramebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0,
        GL.TEXTURE_CUBE_MAP_POSITIVE_X, fbo.tex, 0)

    local status = gl.CheckFramebufferStatus(GL.FRAMEBUFFER)
    if status ~= GL.FRAMEBUFFER_COMPLETE then
        print("ERROR: Framebuffer status: "..string.format("0x%x",status))
    end

    gl.BindFramebuffer(GL.FRAMEBUFFER, 0)
    return fbo
end

function cubemapfunctions.deallocate_fbo(fbo)
    if fbo == nil then return end
    local fboId = ffi.new("int[1]")
    fboId[0] = fbo.id
    gl.DeleteFramebuffers(1, fboId)

    local texId = ffi.new("int[1]")
    texId[0] = fbo.tex
    gl.DeleteTextures(1, texId)
end

function cubemapfunctions.bind_fbo(fbo)
    gl.BindFramebuffer(GL.FRAMEBUFFER, fbo.id)
    -- Note: viewport is not set here
end

function cubemapfunctions.unbind_fbo()
    gl.BindFramebuffer(GL.FRAMEBUFFER, 0)
    -- Note: viewport is not set here
end

return cubemapfunctions
