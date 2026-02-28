-- Rewrite of my partstojson.lua but for literally everything and with more skidding (playr-lol/scripts)
local compress = false
local target = workspace

-- skidding from Dex Explorer (luau/Dex on github)
local zLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/playr-lol/scripts/refs/heads/main/lib/zlib.lua"))()
local Lib = {}
local service = setmetatable({}, {
	__index = function(self, name)
		local serv = game:GetService(name)
		self[name] = serv
		return serv
	end,
})
Lib.Elevated = pcall(function()
	local a = service.CoreGui:GetFullName()
end)
Lib.RobloxVersion = game:HttpGet("https://setup.rbxcdn.com/versionQTStudio")
Lib.RawAPI = nil
Lib.FetchAPI = function()
    local api, rawAPI
    if Lib.Elevated then
        rawAPI = rawAPI or game:HttpGet("https://setup.rbxcdn.com/" .. Lib.RobloxVersion .. "-API-Dump.json")
    else
        if script:FindFirstChild("API") then
            rawAPI = require(script.API)
        else
            error("NO API EXISTS")
        end
    end
    Lib.RawAPI = rawAPI
    api = service.HttpService:JSONDecode(rawAPI)

    local classes, enums = {}, {}
    local categoryOrder, seenCategories = {}, {}

    local function insertAbove(t, item, aboveItem)
        local findPos = table.find(t, item)
        if not findPos then
            return
        end
        table.remove(t, findPos)

        local pos = table.find(t, aboveItem)
        if not pos then
            return
        end
        table.insert(t, pos, item)
    end

    for _, class in ipairs(api.Classes) do
        local newClass = {}
        newClass.Name = class.Name
        newClass.Superclass = class.Superclass
        newClass.Properties = {}
        newClass.Functions = {}
        newClass.Events = {}
        newClass.Callbacks = {}
        newClass.Tags = {}

        if class.Tags then
            for c, tag in ipairs(class.Tags) do
                newClass.Tags[tag] = true
            end
        end
        for _, member in ipairs(class.Members) do
            local newMember = {}
            newMember.Name = member.Name
            newMember.Class = class.Name
            newMember.Security = member.Security
            newMember.Tags = {}
            if member.Tags then
                for c, tag in ipairs(member.Tags) do
                    newMember.Tags[tag] = true
                end
            end

            local mType = member.MemberType
            if mType == "Property" then
                local propCategory = member.Category or "Other"
                propCategory = propCategory:match("^%s*(.-)%s*$")
                if not seenCategories[propCategory] then
                    categoryOrder[#categoryOrder + 1] = propCategory
                    seenCategories[propCategory] = true
                end
                newMember.ValueType = member.ValueType
                newMember.Category = propCategory
                newMember.Serialization = member.Serialization
                table.insert(newClass.Properties, newMember)
            elseif mType == "Function" then
                newMember.Parameters = {}
                newMember.ReturnType = member.ReturnType.Name
                for c, param in ipairs(member.Parameters) do
                    table.insert(newMember.Parameters, { Name = param.Name, Type = param.Type.Name })
                end
                table.insert(newClass.Functions, newMember)
            elseif mType == "Event" then
                newMember.Parameters = {}
                for c, param in ipairs(member.Parameters) do
                    table.insert(newMember.Parameters, { Name = param.Name, Type = param.Type.Name })
                end
                table.insert(newClass.Events, newMember)
            end
        end

        classes[class.Name] = newClass
    end

    for _, class in next, classes do
        class.Superclass = classes[class.Superclass]
    end

    for _, enum in ipairs(api.Enums) do
        local newEnum = {}
        newEnum.Name = enum.Name
        newEnum.Items = {}
        newEnum.Tags = {}

        if enum.Tags then
            for c, tag in ipairs(enum.Tags) do
                newEnum.Tags[tag] = true
            end
        end
        for _, item in ipairs(enum.Items) do
            local newItem = {}
            newItem.Name = item.Name
            newItem.Value = item.Value
            table.insert(newEnum.Items, newItem)
        end

        enums[enum.Name] = newEnum
    end

    local function getMember(class, member)
        if not classes[class] or not classes[class][member] then
            return
        end
        local result = {}

        local currentClass = classes[class]
        while currentClass do
            for _, entry in next, currentClass[member] do
                result[#result + 1] = entry
            end
            currentClass = currentClass.Superclass
        end

        table.sort(result, function(a, b)
            return a.Name < b.Name
        end)
        return result
    end

    insertAbove(categoryOrder, "Behavior", "Tuning")
    insertAbove(categoryOrder, "Appearance", "Data")
    insertAbove(categoryOrder, "Attachments", "Axes")
    insertAbove(categoryOrder, "Cylinder", "Slider")
    insertAbove(categoryOrder, "Localization", "Jump Settings")
    insertAbove(categoryOrder, "Surface", "Motion")
    insertAbove(categoryOrder, "Surface Inputs", "Surface")
    insertAbove(categoryOrder, "Part", "Surface Inputs")
    insertAbove(categoryOrder, "Assembly", "Surface Inputs")
    insertAbove(categoryOrder, "Character", "Controls")
    categoryOrder[#categoryOrder + 1] = "Unscriptable"
    categoryOrder[#categoryOrder + 1] = "Attributes"

    local categoryOrderMap = {}
    for i = 1, #categoryOrder do
        categoryOrderMap[categoryOrder[i]] = i
    end

    return {
        Classes = classes,
        Enums = enums,
        CategoryOrder = categoryOrderMap,
        GetMember = getMember,
    }
end

Lib.IgnoreProps = {
    ["DataModel"] = {
        ["PrivateServerId"] = true,
        ["PrivateServerOwnerId"] = true,
        ["VIPServerId"] = true,
        ["VIPServerOwnerId"] = true,
    },
}

Lib.GetIndexableProps = function(obj, classData)
    if not Lib.Elevated then
        if not pcall(function()
            return obj.ClassName
        end) then
            return nil
        end
    end

    local ignoreProps = Lib.IgnoreProps[classData.Name] or {}

    local result = {}
    local count = 1
    local props = classData.Properties
    for i = 1, #props do
        local prop = props[i]
        if not ignoreProps[prop.Name] then
            local s = pcall(function()
                return obj[prop.Name]
            end)
            if s then
                result[count] = prop
                count = count + 1
            end
        end
    end

    return result
end

Lib.ColorToBytes = function(col)
    local round = math.round
    return ("%d, %d, %d"):format(round(col.r * 255), round(col.g * 255), round(col.b * 255))
end

Lib.ValueToString = function(prop, val)
    local typeData = prop.ValueType
    local typeName = typeData.Name

    if typeName == "Color3" then
        return Lib.ColorToBytes(val)
    elseif typeName == "NumberRange" then
        return val.Min .. ", " .. val.Max
    end

    return tostring(val)
end
local start = os.clock()
print("Grabbing API...")
local API = Lib.FetchAPI()
print(`Api fetched in {os.clock() - start} seconds`)

local function getProperties(obj)
    local props = API.GetMember(obj.ClassName, "Properties") or {}
    local out = {}

    for _, prop in ipairs(props) do
        local ignoreProps = Lib.IgnoreProps[obj.ClassName] or {}
        if not ignoreProps[prop.Name] then
            local ok, value = pcall(function()
                return obj[prop.Name]
            end)
            if ok then
                out[prop.Name] = Lib.ValueToString(prop, value)
            end
        end
    end

    --print(service.HttpService:JSONEncode(out))
    return out
end

local function serializeInstance(obj)
    local yay = {
        Properties = getProperties(obj),
        Children = {}
    }

    for _, child in ipairs(obj:GetChildren()) do
        table.insert(yay.Children, serializeInstance(child))
    end

    return yay
end

local timestart = os.clock()
local result = {}
for _, child in ipairs(target:GetChildren()) do
    table.insert(result, serializeInstance(child))
end

local output = service.HttpService:JSONEncode(result)
if compress then
    output = zLib.Deflate.Compress(output)
end
local filename = `{target.Name} ({game.PlaceId}).txt`
local writefile = writefile
writefile(filename, output)
print(`written to "{filename}" in {os.clock() - timestart} seconds`)
