-- Can only decompile VisualSource v4.
local input = ""

local base93 = loadstring(game:HttpGet("https://raw.githubusercontent.com/playr-lol/scripts/refs/heads/main/lib/base93.lua"))()
local zlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/playr-lol/scripts/refs/heads/main/lib/zlib.lua"))()

local function decode(visualsource)
    local vsrc = visualsource
    vsrc = string.sub(vsrc, 19, -1)
    vsrc = base93.decode(vsrc)
    vsrc = zlib.Deflate.Decompress(vsrc)
end

local function encode(input)
    local vsrc = input
    vsrc = zlib.Deflate.Compress(vsrc)
    vsrc = base93.encode(vsrc)
    vsrc = "0000000000000004 " .. vsrc
end

writefile("decoded.retro", decode(input))
print("hopefully, successful (Written to workspace/decoded.retro)")
