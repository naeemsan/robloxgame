local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.RumalShared.Config)
local Rules = require(RS.RumalShared.Rules)
local Items = require(RS.RumalShared.Cosmetics)
local Profiles = {}
local entries = {}
local store
local LEASE = 180
local allowed = {Classic = true, Mint = true, Berry = true, Sunset = true}

if game.GameId ~= 0 then
    local ok, value = pcall(function() return DSS:GetDataStore(Config.DataStore) end)
    if ok then store = value else warn("Rumal Rush: persistence unavailable", value) end
end

local function clean(raw)
    raw = type(raw) == "table" and raw or {}
    local function integer(n)
        return Rules.finite(n) and math.clamp(math.floor(n), 0, 100000000) or 0
    end
    local owned = {Classic = true}
    if type(raw.owned) == "table" then
        for id in pairs(allowed) do if raw.owned[id] == true then owned[id] = true end end
    end
    return {
        coins = integer(raw.coins), wins = integer(raw.wins), rounds = integer(raw.rounds),
        owned = owned, equipped = owned[raw.equipped] and raw.equipped or "Classic",
    }
end

function Profiles.get(player) return entries[player] end

function Profiles.sync(player)
    local data = entries[player]
    if not data then return end
    player:SetAttribute("Coins", data.coins)
    player:SetAttribute("Wins", data.wins)
    player:SetAttribute("Equipped", data.equipped)
    player:SetAttribute("SavingAvailable", data.loaded)
    for id in pairs(allowed) do player:SetAttribute("Own_" .. id, data.owned[id] == true) end
    local stats = player:FindFirstChild("leaderstats")
    if stats then stats.Coins.Value = data.coins; stats.Wins.Value = data.wins end
end

function Profiles.save(player, release)
    local data = entries[player]
    if not data or not data.loaded or not store then return end
    local deadline = os.clock() + 10
    while data.saving and os.clock() < deadline do task.wait(0.1) end
    if data.saving or not data.loaded then return end
    data.saving = true
    local snapshot = clean(data)
    local ok, result
    for attempt = 1, 3 do
        ok, result = pcall(function()
            return store:UpdateAsync("player_" .. player.UserId, function(previous)
                if type(previous) ~= "table" or type(previous.lock) ~= "table"
                    or previous.lock.token ~= data.token then return nil end
                if release then
                    snapshot.lock = nil
                else
                    snapshot.lock = {token = data.token, expires = os.time() + LEASE}
                end
                return snapshot
            end)
        end)
        if ok then break end
        task.wait(attempt)
    end
    data.saving = false
    if not ok then
        warn("Rumal Rush: progress save failed", player.UserId)
        player:SetAttribute("SaveWarning", true)
    elseif result == nil then
        data.loaded = false
        Profiles.sync(player)
    else
        player:SetAttribute("SaveWarning", false)
    end
    if release then data.loaded = false end
end

function Profiles.load(player)
    local token = Http:GenerateGUID(false)
    local ok, result = false, nil
    if store then
        for attempt = 1, 3 do
            ok, result = pcall(function()
                return store:UpdateAsync("player_" .. player.UserId, function(previous)
                    if type(previous) == "table" and type(previous.lock) == "table"
                        and type(previous.lock.expires) == "number"
                        and previous.lock.expires > os.time() and previous.lock.token ~= token then
                        return nil
                    end
                    local value = clean(previous)
                    value.lock = {token = token, expires = os.time() + LEASE}
                    return value
                end)
            end)
            if ok then break end
            task.wait(attempt)
        end
    end
    local data = clean(result)
    data.loaded = ok and type(result) == "table"
    data.token = token
    entries[player] = data
    if not player.Parent then
        Profiles.save(player, true)
        entries[player] = nil
        return
    end
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    stats.Parent = player
    for _, name in ipairs({"Coins", "Wins"}) do
        local value = Instance.new("IntValue")
        value.Name = name
        value.Parent = stats
    end
    Profiles.sync(player)
end

function Profiles.reward(player, coins, win)
    local data = entries[player]
    if not data then return end
    data.coins += coins
    if win then data.wins += 1 end
    Profiles.sync(player)
end

function Profiles.buy(player, id)
    local data = entries[player]
    if not data then return false, "Progress is still loading" end
    for _, item in ipairs(Items) do
        if item.id == id then
            if item.pass then
                if not player:GetAttribute("NeonOwned") then return false, "Pass not owned" end
                -- Pass ownership is independently rechecked every join.
                data.equipped = "Neon"
                Profiles.sync(player)
                return true, "Neon equipped"
            end
            local ok, message = Rules.buy(data, item)
            Profiles.sync(player)
            return ok, message
        end
    end
    return false, "Unknown cosmetic"
end

function Profiles.remove(player)
    Profiles.save(player, true)
    entries[player] = nil
end

function Profiles.start()
    task.spawn(function()
        while true do
            task.wait(45)
            for player in pairs(entries) do
                task.spawn(Profiles.save, player, false)
            end
        end
    end)
    game:BindToClose(function()
        local pending = 0
        for player in pairs(entries) do
            pending += 1
            task.spawn(function() Profiles.save(player, true); pending -= 1 end)
        end
        local deadline = os.clock() + 25
        repeat task.wait(0.1) until pending == 0 or os.clock() >= deadline
    end)
end
return Profiles
