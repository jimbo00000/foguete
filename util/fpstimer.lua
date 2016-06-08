-- fpstimer.lua

FPSTimer = {
    maxCount = 10,
    sz = 0,
    frameTimes = {}
}
FPSTimer.__index = FPSTimer

function FPSTimer.create()
    local ft = {}
    setmetatable(ft, FPSTimer)
    return ft
end

function FPSTimer:reset()
    self.sz = 0
    self.frameTimes = {}
end

function FPSTimer:onFrame()
    table.insert(self.frameTimes, os.clock())
    if self.sz < self.maxCount then
        self.sz = self.sz + 1
    else
        table.remove(self.frameTimes, 1)
    end
end

function FPSTimer:getFPS()
    local totalTime = self.frameTimes[self.sz] - self.frameTimes[1]
    return self.sz / totalTime
end

return FPSTimer
