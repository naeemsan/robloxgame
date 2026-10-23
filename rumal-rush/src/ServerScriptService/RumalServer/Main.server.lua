local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Marketplace = game:GetService("MarketplaceService")
local PhysicsService = game:GetService("PhysicsService")
local Shared = RS:WaitForChild("RumalShared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Cosmetics = require(Shared.Cosmetics)
local Profiles = require(script.Parent.Profiles)
local Bot = require(script.Parent.Bot)
local arena = workspace:WaitForChild("Arena")
local lobbySpawn = arena:WaitForChild("LobbySpawn")
local runtime = Instance.new("Folder");runtime.Name = "RumalRuntime";runtime.Parent = workspace
local net = Instance.new("Folder");net.Name = "RumalNet";net.Parent = RS
local action = Instance.new("RemoteEvent");action.Name = "Action";action.Parent = net
local notice = Instance.new("RemoteEvent");notice.Name = "Notice";notice.Parent = net
local state = Instance.new("Folder");state.Name = "State";state.Parent = net
local actors = {}
local phase = "Lobby"
local carrier, pickedAt, liveStart, roundEnd = nil, 0, 0, 0
local scorer, resultReason = nil, ""
local cooldowns, monitors = {}, {}
local scarfPosition = Vector3.new(0,3.1,0)
local currentBot
local closing = false
local matchId = 0

pcall(function() PhysicsService:RegisterCollisionGroup("RumalPlayers") end)
PhysicsService:CollisionGroupSetCollidable("RumalPlayers","RumalPlayers",false)

local scarf = Instance.new("Part")
scarf.Name = "The Rumal";scarf.Size = Vector3.new(2.8,.18,2.8)
scarf.Color = Config.Colors.Gold;scarf.Material = Enum.Material.SmoothPlastic
scarf.Anchored = true;scarf.CanCollide = false;scarf.CanTouch = false;scarf.CastShadow = false
scarf.CFrame = CFrame.new(scarfPosition)*CFrame.Angles(0,math.pi/4,0)
scarf.Parent = runtime
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Grab rumal";prompt.ObjectText = "Then run HOME!"
prompt.KeyboardKeyCode = Enum.KeyCode.E;prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
prompt.HoldDuration = 0;prompt.MaxActivationDistance = Config.GrabRadius
prompt.RequiresLineOfSight = false;prompt.Enabled = false;prompt.Parent = scarf
local beacon = Instance.new("BillboardGui")
beacon.Size = UDim2.fromOffset(150,32);beacon.StudsOffset = Vector3.new(0,3,0)
beacon.AlwaysOnTop = true;beacon.Parent = scarf
local beaconText = Instance.new("TextLabel")
beaconText.BackgroundColor3 = Config.Colors.Ink;beaconText.BackgroundTransparency = .15
beaconText.Size = UDim2.fromScale(1,1);beaconText.TextColor3 = Config.Colors.Cream
beaconText.Text = "THE RUMAL";beaconText.Font = Enum.Font.GothamBold;beaconText.TextSize = 14
beaconText.Parent = beacon
Instance.new("UICorner",beaconText).CornerRadius = UDim.new(0,8)

local function now() return workspace:GetServerTimeNow() end
local function attributes(values) for key,value in pairs(values) do state:SetAttribute(key,value) end end
local function setPhase(value, seconds, headline)
    phase = value
    attributes({Phase=value,EndsAt=now()+(seconds or 0),Headline=headline or ""})
    prompt.Enabled = value == "Live" and not carrier
end
local function notify(player,text) if player and player.Parent then notice:FireClient(player,text) end end
local function rootFor(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if root and human and human.Health > 0 then return root,human end
    return nil,nil
end
local function position(side)
    local actor = actors[side]
    if not actor then return nil end
    if actor.bot then return actor.bot.position end
    local root = actor.player and rootFor(actor.player)
    return root and root.Position or nil
end
local function point(v) return {x=v.X,y=v.Y,z=v.Z} end
local function actorSide(player)
    for side,actor in pairs(actors) do if actor.player == player then return side end end
    return nil
end
local function lobby(player)
    player:SetAttribute("Active",false)
    player:SetAttribute("Carrying",false)
    local root,human = rootFor(player)
    if root then
        root.Anchored = false;root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = CFrame.new((player.UserId%5-2)*4,10,44)
        -- Spectators stay on the viewing deck; active runners are moved by spawnActor.
        human.WalkSpeed = 0
        human.JumpPower = 0;human.JumpHeight = 0
    end
    monitors[player] = nil
end
local function visual(player)
    local root = rootFor(player)
    if not root then return end
    for _,name in ipairs({"CosmeticTrail","CosmeticA","CosmeticB"}) do
        local old = root:FindFirstChild(name);if old then old:Destroy() end
    end
    local id = player:GetAttribute("Equipped") or "Classic"
    if id == "Classic" then return end
    local color
    for _,item in ipairs(Cosmetics) do if item.id == id then color = item.color end end
    if not color then return end
    local a = Instance.new("Attachment");a.Name = "CosmeticA";a.Position = Vector3.new(-.6,0,0);a.Parent = root
    local b = Instance.new("Attachment");b.Name = "CosmeticB";b.Position = Vector3.new(.6,0,0);b.Parent = root
    local trail = Instance.new("Trail");trail.Name = "CosmeticTrail";trail.Attachment0 = a;trail.Attachment1 = b
    trail.Lifetime = .25;trail.Color = ColorSequence.new(color);trail.FaceCamera = true
    trail.Transparency = NumberSequence.new(.3,1);trail.Parent = root
end
local function clearActors()
    for _,actor in pairs(actors) do
        if actor.player and actor.player.Parent then lobby(actor.player) end
    end
    actors = {};carrier = nil;prompt.Enabled = false
    if currentBot then currentBot:destroy();currentBot = nil end
    scarf.Transparency = 0;scarf.Color = Config.Colors.Gold
    scarf.CFrame = CFrame.new(scarfPosition)*CFrame.Angles(0,math.pi/4,0)
    beaconText.Text = "THE RUMAL"
    attributes({Carrier=0,TealUserId=0,CoralUserId=0})
end
local function finish(winner,reason)
    if phase ~= "Live" and phase ~= "Countdown" then return end
    scorer = winner;resultReason = reason
    setPhase("Result",Config.ResultSeconds,reason)
    for _,actor in pairs(actors) do
        if actor.player then
            local root = rootFor(actor.player)
            if root then root.Anchored = true end
        end
    end
end
local function validActor(player)
    local root = rootFor(player)
    if not root then return false end
    return Rules.validPosition(point(root.Position),Config.BoundsX,Config.BoundsZ)
end
local function grab(side)
    if not side or carrier or phase ~= "Live" then return end
    local pos = position(side)
    if not pos or not Rules.validPosition(point(pos),Config.BoundsX,Config.BoundsZ) then return end
    if not Rules.canGrab(phase,carrier ~= nil,point(pos),point(scarfPosition),Config.GrabRadius) then return end
    -- Check displacement on the request path as well as in the simulation tick.
    local actor = actors[side]
    if actor.player then
        local m = monitors[actor.player]
        if not m or (pos-m.last).Magnitude > 9 then return end
    end
    carrier = side;pickedAt = now();prompt.Enabled = false
    state:SetAttribute("Carrier",side)
    if actor.player then actor.player:SetAttribute("Carrying",true) end
    local id = actor.player and actor.player:GetAttribute("Equipped") or "Classic"
    for _,item in ipairs(Cosmetics) do if item.id == id then scarf.Color = item.color end end
    beaconText.Text = side == 1 and "← TEAL: GET HOME" or "CORAL: GET HOME →"
end
prompt.Triggered:Connect(function(player) grab(actorSide(player)) end)

local function refreshPass(player)
    if Config.NeonPassId <= 0 then return end
    local ok,owned = pcall(function() return Marketplace:UserOwnsGamePassAsync(player.UserId,Config.NeonPassId) end)
    if ok and player.Parent then
        player:SetAttribute("NeonOwned",owned)
        if owned then notify(player,"Neon club unlocked. Equip it in your locker.") end
    end
end
Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
    if purchased and id == Config.NeonPassId then task.spawn(refreshPass,player) end
end)

local function setup(player)
    player:SetAttribute("Ready",false);player:SetAttribute("Active",false)
    player:SetAttribute("Side",0);player:SetAttribute("DashReadyAt",0)
    player:SetAttribute("Difficulty","Easy");player:SetAttribute("NeonOwned",false)
    player.RespawnLocation = lobbySpawn
    local function characterAdded(character)
        local root = character:WaitForChild("HumanoidRootPart",10)
        local human = character:WaitForChild("Humanoid",10)
        if not root or not human or not player.Parent then return end
        local function collision(object)
            if object:IsA("BasePart") then object.CollisionGroup = "RumalPlayers" end
        end
        for _,object in ipairs(character:GetDescendants()) do collision(object) end
        character.DescendantAdded:Connect(collision)
        human.JumpPower = 0;human.JumpHeight = 0;human.WalkSpeed = Config.WalkSpeed
        local side = actorSide(player)
        if side then finish(3-side,"OPPONENT RESET — ROUND WON") end
        lobby(player);visual(player)
        human.Died:Connect(function()
            local activeSide = actorSide(player)
            if activeSide then finish(3-activeSide,"OPPONENT OUT — ROUND WON") end
        end)
    end
    player.CharacterAdded:Connect(characterAdded)
    if player.Character then task.spawn(characterAdded,player.Character) end
    task.spawn(function() Profiles.load(player);if player.Parent then visual(player);refreshPass(player) end end)
end
Players.PlayerAdded:Connect(setup)
for _,player in ipairs(Players:GetPlayers()) do setup(player) end
Players.PlayerRemoving:Connect(function(player)
    local side = actorSide(player)
    if side then finish(3-side,"OPPONENT LEFT — ROUND WON") end
    cooldowns[player] = nil;monitors[player] = nil
    Profiles.remove(player)
end)
Profiles.start()

-- The remote never accepts positions, rewards, prices, ownership, or winner claims.
action.OnServerEvent:Connect(function(player,kind,value)
    if type(kind) ~= "string" then return end
    local time = now()
    local rate = cooldowns[player] or {time=time,tokens=12}
    rate.tokens = math.min(12,rate.tokens+(time-rate.time)*6);rate.time = time
    cooldowns[player] = rate
    if rate.tokens < 1 then return end
    rate.tokens -= 1
    if kind == "Ready" and type(value) == "boolean" then
        if not Profiles.get(player) then notify(player,"Loading progress. Try again in a moment.");return end
        player:SetAttribute("Ready",value)
        if not value then
            local side = actorSide(player)
            if side then finish(3-side,"OPPONENT SAT OUT") else lobby(player) end
        end
    elseif kind == "Difficulty" and (value == "Easy" or value == "Standard") then
        if not player:GetAttribute("Active") then player:SetAttribute("Difficulty",value) end
    elseif kind == "Grab" then
        grab(actorSide(player))
    elseif kind == "Dash" then
        if not actorSide(player) or not validActor(player) then return end
        if not Rules.canDash(phase,time,player:GetAttribute("DashReadyAt") or 0) then return end
        local _,human = rootFor(player)
        if not human then return end
        player:SetAttribute("DashReadyAt",time+Config.DashCooldown)
        human.WalkSpeed = Config.DashSpeed
        local monitor = monitors[player]
        if monitor then monitor.dashUntil = time+Config.DashSeconds end
    elseif kind == "Equip" and type(value) == "string" and #value <= 20 then
        local ok,message = Profiles.buy(player,value)
        notify(player,message)
        if ok then visual(player) end
    end
end)

-- Server simulation: bot, movement checks, pickup follow, tags and home-line scoring.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
    accumulator += dt
    if accumulator < .05 then return end
    local elapsed = math.min(accumulator,.25);accumulator = 0
    if phase ~= "Live" then return end
    local time = now()
    for side,actor in pairs(actors) do
        if actor.player then
            local root,human = rootFor(actor.player)
            if not root then finish(3-side,"OPPONENT OUT — ROUND WON");return end
            local m = monitors[actor.player]
            if not m then finish(3-side,"ROUND RESET");return end
            if time >= m.dashUntil then human.WalkSpeed = Config.WalkSpeed end
            local pos = root.Position
            local horizontal = Vector3.new(pos.X-m.last.X,0,pos.Z-m.last.Z).Magnitude
            local allowedSpeed = time < m.dashUntil + .15 and Config.DashSpeed+4 or Config.WalkSpeed+4
            local ok,budget = Rules.movementBudget(m.budget,horizontal,time-m.checked,allowedSpeed)
            m.budget = budget;m.checked = time
            if not ok or not Rules.validPosition(point(pos),Config.BoundsX,Config.BoundsZ) then
                root.CFrame = CFrame.new(m.last);root.AssemblyLinearVelocity = Vector3.zero
                m.violations += 1
                if m.violations >= 4 then finish(3-side,"OUT OF BOUNDS — ROUND LOST");return end
            else
                m.last = pos
            end
        elseif actor.bot then
            local enemy = position(3-side)
            if not enemy then finish(side,"OPPONENT LEFT");return end
            local humanActor = actors[3-side]
            local easy = not humanActor.player or humanActor.player:GetAttribute("Difficulty") ~= "Standard"
            local wantsGrab = actor.bot:step(elapsed,time,{
                side=side,carrier=carrier,opponent=enemy,scarf=scarfPosition,
                started=liveStart,pickedAt=pickedAt,easy=easy,
            })
            if wantsGrab then grab(side) end
        end
    end
    local a,b = position(1),position(2)
    if not a or not b then return end
    if carrier then
        local p = carrier == 1 and a or b
        scarf.CFrame = CFrame.new(p+Vector3.new(0,3.8,0))*CFrame.Angles(0,math.pi/4,0)
    end
    local outcome = Rules.resolve({phase=phase,carrier=carrier,pickedAt=pickedAt,now=time,
        grace=Config.PickupGrace,positions={point(a),point(b)},homeX=Config.HomeX,
        tagRadius=Config.TagRadius,remaining=roundEnd-time})
    if outcome then finish(outcome.winner,outcome.reason) end
end)

local function readyPlayers()
    local list = {}
    for _,player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("Ready") and Profiles.get(player) and rootFor(player) then table.insert(list,player) end
    end
    table.sort(list,function(a,b) return a.UserId < b.UserId end)
    return list
end
local function waitPhase(seconds)
    local deadline = now()+seconds
    while now() < deadline and not closing do task.wait(.1) end
end
local function choose(roster,cursor)
    if #roster == 0 then return nil,cursor end
    for offset=1,#roster do
        local index = (cursor+offset-1)%#roster+1
        local player = roster[index]
        if player.Parent and player:GetAttribute("Ready") and rootFor(player) then return player,index end
    end
    return nil,cursor
end
local function spawnActor(player,side)
    local x = side == 1 and -36 or 36
    if player then
        local root,human = rootFor(player)
        if not root then return nil end
        player:SetAttribute("Side",side);player:SetAttribute("Active",true)
        player:SetAttribute("Carrying",false);player:SetAttribute("DashReadyAt",0)
        root.CFrame = CFrame.lookAt(Vector3.new(x,3.2,0),Vector3.new(0,3.2,0))
        root.AssemblyLinearVelocity = Vector3.zero;root.Anchored = true
        human.WalkSpeed = Config.WalkSpeed
        monitors[player] = {last=root.Position,checked=now(),budget=9,dashUntil=0,violations=0}
        return {player=player,name=player.DisplayName}
    end
    currentBot = Bot.new(runtime,side == 1 and Config.Colors.Teal or Config.Colors.Coral)
    currentBot:move(Vector3.new(x,3.1,0),Vector3.new(-x,0,0))
    return {bot=currentBot,name="Milo (bot)"}
end
attributes({Phase="Lobby",Headline="Your next courtyard rivalry starts here.",EndsAt=0,
    TealScore=0,CoralScore=0,Round=0,Carrier=0,Mode="Practice",TealUserId=0,CoralUserId=0,
    TealName="TEAL",CoralName="CORAL",Match=0,Winner=0,Variant="Classic center"})
game:BindToClose(function() closing = true end)

task.spawn(function()
    while not closing do
        clearActors()
        setPhase("Lobby",0,"Press PLAY to enter the courtyard")
        repeat task.wait(.5) until #readyPlayers() > 0 or closing
        if closing then break end
        matchId += 1
        local scores,cursors = {0,0},{0,0}
        attributes({TealScore=0,CoralScore=0,Round=0,Winner=0,Match=matchId})
        setPhase("Intermission",Config.IntermissionSeconds,"FIRST TO 3 • one runner per team each round")
        waitPhase(Config.IntermissionSeconds)
        -- Accept friends who join during the countdown, then lock rosters for this match.
        local list = readyPlayers()
        local rosters = {{},{}}
        for index,player in ipairs(list) do
            if index <= Config.MaxPlayers then
                local side = (index-1)%2+1
                table.insert(rosters[side],player);player:SetAttribute("Side",side)
            end
        end
        state:SetAttribute("Mode",#list == 1 and "Practice" or "Team duel")
        local completed = 0
        local matchWinner
        for round=1,Config.MaxRounds do
            if #readyPlayers() == 0 or closing then break end
            clearActors()
            local a,b
            a,cursors[1] = choose(rosters[1],cursors[1])
            b,cursors[2] = choose(rosters[2],cursors[2])
            if not a and not b then break end
            -- Missing team gets a practice opponent; a bot never occupies both sides.
            actors[1] = spawnActor(a,1);actors[2] = spawnActor(b,2)
            if not actors[1] or not actors[2] then break end
            local offset = ({0,-9,9})[(round-1)%3+1]
            scarfPosition = Vector3.new(0,3.1,offset)
            scarf.CFrame = CFrame.new(scarfPosition)*CFrame.Angles(0,math.pi/4,0)
            carrier = nil;scorer = nil
            attributes({Round=round,Carrier=0,Winner=0,TealName=actors[1].name,CoralName=actors[2].name,
                TealUserId=a and a.UserId or 0,CoralUserId=b and b.UserId or 0,
                Mode=(not a or not b) and "Practice" or "Team duel",
                Variant=offset == 0 and "Classic center" or "Side-step pickup"})
            setPhase("Countdown",Config.CountdownSeconds,"READY • grab the rumal, then reach YOUR home line")
            waitPhase(Config.CountdownSeconds)
            if scorer == nil then
                liveStart = now();roundEnd = liveStart+Config.RoundSeconds
                for _,actor in pairs(actors) do
                    if actor.player then
                        local root = rootFor(actor.player)
                        if root then root.Anchored = false;monitors[actor.player].checked = now() end
                    end
                end
                setPhase("Live",Config.RoundSeconds,"GRAB • DODGE • GET HOME")
                while phase == "Live" and not closing do task.wait(.1) end
            end
            completed = round
            if scorer and scorer > 0 then scores[scorer] += 1 end
            attributes({TealScore=scores[1],CoralScore=scores[2],Winner=scorer or 0})
            -- Only completed live duels pay; resets during countdown cannot farm coins.
            if liveStart > 0 and now()-liveStart >= 2 and resultReason ~= "OPPONENT SAT OUT" then
                for side,actor in pairs(actors) do
                    if actor.player and actor.player.Parent and actor.player:GetAttribute("Ready") then
                        Profiles.reward(actor.player,side == scorer and Config.RoundWinCoins or Config.RoundPlayCoins,false)
                    end
                end
            end
            liveStart = 0
            waitPhase(Config.ResultSeconds)
            matchWinner = Rules.matchWinner(scores[1],scores[2],round,Config.MatchTarget,Config.MaxRounds)
            if matchWinner ~= nil then break end
        end
        clearActors()
        if completed > 0 and matchWinner ~= nil then
            local text = matchWinner == 0 and "MATCH DRAW" or (matchWinner == 1 and "TEAL TAKES THE MATCH!" or "CORAL TAKES THE MATCH!")
            if matchWinner > 0 then
                for _,player in ipairs(rosters[matchWinner]) do
                    if player.Parent and player:GetAttribute("Ready") then Profiles.reward(player,Config.MatchWinCoins,true) end
                end
            end
            attributes({Winner=matchWinner,Headline=text})
            setPhase("MatchEnd",7,text)
            waitPhase(7)
        end
        -- Participants choose a rematch. Late arrivals keep their place in the queue.
        for _,roster in ipairs(rosters) do
            for _,player in ipairs(roster) do
                if player.Parent then
                    player:SetAttribute("Ready",false);player:SetAttribute("Side",0)
                end
            end
        end
    end
end)
