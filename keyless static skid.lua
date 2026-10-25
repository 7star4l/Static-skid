repeat task.wait() until game:IsLoaded()

local cloneref = cloneref or function(x) return x end
local Services = setmetatable({}, {
    __index = function(self, name)
        local service = cloneref(game:GetService(name))
        rawset(self, name, service)
        return service
    end,
})

local CONFIG = {
    API_SCRIPT_ID = "85a45c6dd86733f3b4b2a1a202d86e06",
    GAMES_URL = "https://raw.githubusercontent.com/th3-osc/Static/main/games.json",
    GAMES_PATH = "Static/games.json",
}

local Utils = {}

function Utils.log(level, msg)
    local prefix = string.format("[Static][%s]", level)
    if level == "ERROR" then warn(prefix, msg) else print(prefix, msg) end
end

function Utils.try(fn, ctx)
    local ok, result = pcall(fn)
    if not ok then
        Utils.log("ERROR", ctx .. ": " .. tostring(result))
        return nil
    end
    return result
end

local Games = { list = nil, ready = false }

function Games.load()
    local raw = Utils.try(function()
        return game:HttpGet(CONFIG.GAMES_URL)
    end, "Failed to fetch games")

    local list = raw and Utils.try(function()
        return Services.HttpService:JSONDecode(raw)
    end, "Failed to decode games")
    
    if list and list[1] then
        if writefile then pcall(writefile, CONFIG.GAMES_PATH, raw) end
    elseif isfile and isfile(CONFIG.GAMES_PATH) then
        list = Utils.try(function()
            return Services.HttpService:JSONDecode(readfile(CONFIG.GAMES_PATH))
        end, "Failed to decode cached games")
    end

    Games.list = (list and list[1]) and list or nil
    Games.ready = true

    return Games.list
end

task.spawn(Games.load)

function Games.all()
    local deadline = os.clock() + 10
    while not Games.ready and os.clock() < deadline do
        task.wait()
    end

    if not Games.list and Games.ready then
        Games.load()
    end

    return Games.list
end

local GameDetector = {}

function GameDetector.findGame()
    local games = Games.all()
    if not games then
        Utils.log("ERROR", "Game list unavailable")
        return nil, false
    end

    for _, data in games do
        for _, id in data.gameIds or {} do
            if id == game.GameId then
                Utils.log("INFO", "Game detected by GameId: " .. data.name)
                return data, true
            end
        end
    end

    local name = Utils.try(function()
        return Services.MarketplaceService:GetProductInfo(game.PlaceId).Name:lower()
    end, "Failed to fetch place info")

    if name then
        for _, data in games do
            if data.name and data.name:lower() == name then
                Utils.log("INFO", "Game detected by name: " .. data.name)
                return data, true
            end
        end

        for _, data in games do
            for _, pattern in data.patterns or {} do
                if name:find(pattern:lower(), 1, true) then
                    Utils.log("INFO", "Game detected by pattern: " .. data.name)
                    return data, true
                end
            end
        end
    end

    Utils.log("INFO", "No game detected")
    return nil, true
end

-- Main Initialization (Direct Load)
task.spawn(function()
    local api = Utils.try(function()
        return loadstring(game:HttpGet("https://sdkAPI-public.luarmor.net/library.lua"))()
    end, "Failed to load API")

    if not api then
        Utils.log("ERROR", "API load failed")
        return
    end

    local gameData = GameDetector.findGame()
    api.script_id = (gameData and gameData.scriptId) or CONFIG.API_SCRIPT_ID

    Utils.log("INFO", "Loading script...")
    api.load_script()
end)