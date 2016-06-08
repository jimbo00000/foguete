-- fbofunctions.lua
fbofunctions = {}

local openGL = require("opengl")
local ffi = require("ffi")

function fbofunctions.allocate_fbo(w, h)
    fbo = {}
    fbo.w = w
    fbo.h = h

    local fboId = ffi.new("GLuint[1]")
    gl.GenFramebuffers(1, fboId)
    fbo.id = fboId[0]
    gl.BindFramebuffer(GL.FRAMEBUFFER, fbo.id)

    local dtxId = ffi.new("GLuint[1]")
    gl.GenTextures(1, dtxId)
    fbo.depth = dtxId[0]
    gl.BindTexture(GL.TEXTURE_2D, fbo.depth)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST)
    --gl.TexParameteri( GL.TEXTURE_2D, GL.DEPTH_TEXTURE_MODE, GL.INTENSITY ); --deprecated, out in 3.1
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAX_LEVEL, 0)
    gl.TexImage2D(GL.TEXTURE_2D, 0, GL.DEPTH_COMPONENT,
                  w, h, 0,
                  GL.DEPTH_COMPONENT, GL.UNSIGNED_BYTE, nil)
    gl.BindTexture(GL.TEXTURE_2D, 0)
    gl.FramebufferTexture2D(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.TEXTURE_2D, fbo.depth, 0)

    local texId = ffi.new("GLuint[1]")
    gl.GenTextures(1, texId)
    fbo.tex = texId[0]
    gl.BindTexture(GL.TEXTURE_2D, fbo.tex)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR)
    gl.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR)
    gl.TexImage2D(GL.TEXTURE_2D, 0, GL.RGBA8,
                  w, h, 0,
                  GL.RGBA, GL.UNSIGNED_BYTE, nil)
    gl.BindTexture(GL.TEXTURE_2D, 0)
    gl.FramebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, fbo.tex, 0)

    local status = gl.CheckFramebufferStatus(GL.FRAMEBUFFER)
    if status ~= GL.FRAMEBUFFER_COMPLETE then
        print("ERROR: Framebuffer status: "..status)
    end

    gl.BindFramebuffer(GL.FRAMEBUFFER, 0)
    return fbo
end

function fbofunctions.deallocate_fbo(fbo)
    if fbo == nil then return end
    local fboId = ffi.new("int[1]")
    fboId[0] = fbo.id
    gl.DeleteFramebuffers(1, fboId)

    local texId = ffi.new("int[1]")
    texId[0] = fbo.tex
    gl.DeleteTextures(1, texId)

    local depthId = ffi.new("int[1]")
    depthId[0] = fbo.depth
    gl.DeleteTextures(1, depthId)
end

function fbofunctions.bind_fbo(fbo)
    gl.BindFramebuffer(GL.FRAMEBUFFER, fbo.id)
    -- Note: viewport is not set here
end

function fbofunctions.unbind_fbo()
    gl.BindFramebuffer(GL.FRAMEBUFFER, 0)
    -- Note: viewport is not set here
end

return fbofunctions
