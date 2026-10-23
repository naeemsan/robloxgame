-- Mock only the service boundary; the production Profiles source is injected by verify.py.
local database = {}
local failRequests = false
local requests = 0
local fakeStore = {}
function fakeStore:UpdateAsync(key,callback)
    requests += 1
    if failRequests then error("Service unavailable") end
    local output = callback(database[key])
    if output ~= nil then database[key] = output end
    return output
end
local ids = 0
local fakePlayers = {}
local fakeGame = {GameId=123}
local services = {
    Players=fakePlayers,
    DataStoreService={GetDataStore=function() return fakeStore end},
    HttpService={GenerateGUID=function() ids+=1;return "test-"..ids end},
    ReplicatedStorage={RumalShared={Config="config",Rules="rules",Cosmetics="items"}},
}
function fakeGame:GetService(name) return services[name] end
function fakeGame:BindToClose() end
local game = fakeGame
local task = {wait=function() end,spawn=function() end}
local warn = function() end
local Instance = {new=function()
    return setmetatable({}, {__newindex=function(self,key,value)
        rawset(self,key,value)
        if key=="Parent" and value then rawset(value,self.Name,self) end
    end})
end}
local dependencies = {
    config={DataStore="fixture"},
    rules=ACTUAL_RULES,
    items={{id="Mint",cost=80},{id="Classic",cost=0},{id="Neon",pass=true}},
}
local require = function(name) return dependencies[name] end
local function player(id)
    local p={UserId=id,Parent=true,attributes={}}
    function p:SetAttribute(name,value) self.attributes[name]=value end
    function p:GetAttribute(name) return self.attributes[name] end
    function p:FindFirstChild(name) return rawget(self,name) end
    return p
end
