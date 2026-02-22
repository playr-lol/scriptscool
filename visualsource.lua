local input = readfile("input.retro")
local mode = "decode"
-- tips: Pretty sure VisualSource v1 and v2 do not need to be decoded

local starttime = os.clock()
local base93 = loadstring(game:HttpGet("https://raw.githubusercontent.com/playr-lol/scripts/refs/heads/main/lib/base93.lua"))()
local zlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/playr-lol/scripts/refs/heads/main/lib/zlib.lua"))()

local function decode(visualsource)
    local vsrc = visualsource
    local start = string.sub(vsrc, 1, 18)
    -- v4/v3
    if start == "\0260000000000000004\027" or start == "\0260000000000000003\027" then
        vsrc = string.sub(vsrc, 19, -1)
        vsrc = base93.decode(vsrc)
        vsrc = zlib.Deflate.Decompress(vsrc)
    end

    return vsrc
end

local function encode(version, input)
    if version == 4 or version == 3 then
        local vsrc = input
        vsrc = zlib.Deflate.Compress(vsrc)
        vsrc = base93.encode(vsrc)
        vsrc = `000000000000000{tostring(version)}` .. vsrc
        return vsrc
    end
end

if mode == "decode" then
    writefile("decoded.retro", decode(input))
    print("hopefully, successful (Written to workspace/decoded.retro)")
elseif mode == "encode" then
    writefile("encoded.retro", encode(4, input))
    print("hopefully, successful (Written to workspace/encoded.retro)")
end 
print(`Time taken: {os.clock() - starttime} seconds`)
