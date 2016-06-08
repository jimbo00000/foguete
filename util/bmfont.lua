-- Ripped from https://github.com/gideros/BMFont

-- check if string1 starts with string2
local function startsWith(string1, string2)
   return string1:sub(1, #string2) == string2
end

-- create table from a bmfont line
local function lineToTable(line)
    local result = {}
    for pair in line:gmatch("%a+=[-%d]+") do
        local key = pair:match("%a+")
        local value = pair:match("[-%d]+")
        result[key] = tonumber(value)
    end
    return result
end

-- this is our BMFont class
BMFont = {}
BMFont.__index = BMFont

-- and its new function
function BMFont.new(...)
    local self = setmetatable({}, BMFont)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function BMFont:init(fontfile, imagefile, filtering)
    -- load font texture
    --self.texture = Texture.new(imagefile, filtering)

    -- read glyphs from font.txt and store them in chars table
    self.chars = {}
    file = io.open(fontfile, "rt")
    if not file then return end
    for line in file:lines() do
        if startsWith(line, "char ") then
            local char = lineToTable(line)
            self.chars[char.id] = char
        end
    end

    io.close(file)
end

function BMFont:drawstring(str, draw_func, xstart, ystart)
    if not str then return end
    local x = xstart
    local y = ystart
    for i=1,#str do
        local char = self.chars[str:byte(i)]
        if char ~= nil then
            draw_func(x, y, char)
            x = x + char.xadvance
        end
    end
end
