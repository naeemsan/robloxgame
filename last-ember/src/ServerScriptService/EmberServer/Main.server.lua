local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Physics=game:GetService("PhysicsService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Marketplace=game:GetService("MarketplaceService")
local Shared=RS:WaitForChild("EmberShared")
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Director=require(script.Parent.Director)
local manor=workspace:WaitForChild("Manor")
local markers=manor:WaitForChild("Markers")
local runtime=Instance.new("Folder");runtime.Name="EmberRuntime";runtime.Parent=workspace
local net=Instance.new("Folder");net.Name="EmberNet";net.Parent=RS
local action=Instance.new("RemoteEvent");action.Name="Action";action.Parent=net
local signal=Instance.new("RemoteEvent");signal.Name="Signal";signal.Parent=net
local state=Instance.new("Folder");state.Name="State";state.Parent=net
local phase="Lobby"
local party={}
local allPlayers={}
local director
local mission={fuses=0,burned=0,fusesNeeded=Config.Fuses,sealsNeeded=Config.Seals}
local roundId=0
local nextItem=0
local matchEnd=0
local holds={}
local prompts={}
local items={}
local helpCooldown={}
local closing=false
local finalOutcome=""
local furnaceFire=Instance.new("Fire")
furnaceFire.Name="FurnaceFlame";furnaceFire.Size=6;furnaceFire.Heat=3
furnaceFire.Color=Color3.fromRGB(242,126,41);furnaceFire.SecondaryColor=Color3.fromRGB(255,209,88)
furnaceFire.Enabled=false;furnaceFire.Parent=manor.FurnaceGrate
pcall(function() Physics:RegisterCollisionGroup("EmberPlayers") end)
Physics:CollisionGroupSetCollidable("EmberPlayers","EmberPlayers",false)
local function now() return workspace:GetServerTimeNow() end
local function vec(p) return {x=p.X,y=p.Y,z=p.Z} end
local function send(player,kind,value)
    if player and player.Parent then signal:FireClient(player,kind,value) end
end
local function broadcast(kind,value) for player in pairs(party) do send(player,kind,value) end end
local function attr(values) for k,v in pairs(values) do state:SetAttribute(k,v) end end
local function rootFor(player)
    local character=player.Character
    return character and character:FindFirstChild("HumanoidRootPart"),character and character:FindFirstChildOfClass("Humanoid")
end
local function sync(player)
    local d=party[player]
    if not d then return end
    player:SetAttribute("Status",d.status);player:SetAttribute("Held",d.held)
    player:SetAttribute("Stamina",math.floor(d.stamina));player:SetAttribute("Hidden",d.hidden)
    player:SetAttribute("Flashlight",d.flashlight)
    player:SetAttribute("BleedAt",d.bleedAt or 0)
end
local function stage()
    furnaceFire.Enabled=mission.fuses>=Config.Fuses
    attr({Fuses=mission.fuses,Burned=mission.burned,Threat=Rules.threat(mission.fuses,mission.burned)})
    local objective
    if mission.fuses<Config.Fuses then objective="FIND TWO FUSES • RESTORE THE GENERATOR"
    elseif mission.burned<Config.Seals then objective="FIND THE CURSED SEALS • BURN THEM IN THE ASH CHAMBER"
    else objective="THE GATE IS OPEN • GET EVERYONE OUT" end
    state:SetAttribute("Objective",objective)
    local door=manor:FindFirstChild("ExitDoor")
    door.CanCollide=mission.burned<Config.Seals
    door.Transparency=mission.burned<Config.Seals and 0 or .85
end
local function phaseSet(value,duration)
    phase=value;attr({Phase=value,EndsAt=duration and now()+duration or 0})
end
local function visible(player,target)
    local root=rootFor(player);if not root then return false end
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character}
    local hit=workspace:Raycast(root.Position,target.Position-root.Position,ray)
    return not hit or hit.Instance==target or hit.Instance:IsDescendantOf(target)
        or (target.Name=="HumanoidRootPart" and hit.Instance:IsDescendantOf(target.Parent))
end
local function validInteraction(player,target,required,prompt)
    local d=party[player];local root=rootFor(player)
    if not d or not root or not target.Parent then return false end
    local began=holds[prompt] and holds[prompt][player]
    local heldTime=required==0 and 0 or (began and now()-began or -1)
    if not Rules.canInteract(phase,d.status,(root.Position-target.Position).Magnitude,heldTime,required) then return false end
    if d.hidden then return false end
    if not visible(player,target) then return false end
    if holds[prompt] then holds[prompt][player]=nil end
    return true
end
local function promptOn(target,title,object,seconds,callback)
    local prompt=Instance.new("ProximityPrompt")
    prompt.ActionText=title;prompt.ObjectText=object;prompt.HoldDuration=seconds
    prompt.MaxActivationDistance=8;prompt.RequiresLineOfSight=false
    prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
    prompt.Parent=target;holds[prompt]={};table.insert(prompts,prompt)
    prompt.PromptButtonHoldBegan:Connect(function(player)
        local root=rootFor(player)
        if root and (root.Position-target.Position).Magnitude<=10 then holds[prompt][player]=now() end
    end)
    prompt.PromptButtonHoldEnded:Connect(function(player)
        -- Give the engine's completion event time to arrive; do not clear a newer hold.
        local began=holds[prompt] and holds[prompt][player]
        task.delay(.5,function()
            if holds[prompt] and holds[prompt][player]==began then holds[prompt][player]=nil end
        end)
    end)
    prompt.Triggered:Connect(function(player)
        if validInteraction(player,target,seconds,prompt) then callback(player) end
    end)
    return prompt
end
local function clearHeldVisual(player)
    local character=player.Character
    local old=character and character:FindFirstChild("CarriedEmber")
    if old then old:Destroy() end
end
local function carryVisual(player,kind)
    clearHeldVisual(player)
    if kind=="" then return end
    local root=rootFor(player);if not root then return end
    local p=Instance.new("Part");p.Name="CarriedEmber";p.Size=kind=="Fuse" and Vector3.new(.5,1.2,.5) or Vector3.new(.8,1.1,.25)
    p.Color=kind=="Fuse" and Color3.fromRGB(95,155,168) or Color3.fromRGB(178,139,87)
    p.Material=Enum.Material.Metal;p.CanCollide=false;p.CanTouch=false;p.Massless=true
    p.CFrame=root.CFrame*CFrame.new(1.1,-.5,-.8);p.Parent=player.Character
    local weld=Instance.new("WeldConstraint");weld.Part0=root;weld.Part1=p;weld.Parent=p
end
local spawnItem
local function drop(player)
    local d=party[player];local root=rootFor(player)
    if not d or d.held=="" then return end
    local pos=d.hidden and d.hideExit or (root and root.Position or d.last or Vector3.new(0,3,35))
    if not Rules.inHouse(vec(pos)) then pos=Vector3.new(0,3,35) end
    -- Rest drops on the surface below, not inside tables or beneath beds.
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={runtime,player.Character or runtime}
    local surface=workspace:Raycast(pos+Vector3.new(0,3,0),Vector3.new(0,-24,0),ray)
    local y=surface and surface.Position.Y+1 or 1.4
    local kind=d.held;d.held="";clearHeldVisual(player)
    spawnItem(kind,Vector3.new(pos.X,y,pos.Z))
    sync(player)
end
spawnItem=function(kind,position)
    nextItem+=1
    local p=Instance.new("Part");p.Name=kind.."_"..nextItem
    p.Size=kind=="Fuse" and Vector3.new(.65,1.5,.65) or Vector3.new(1.2,1.5,.35)
    p.CFrame=CFrame.new(position)*CFrame.Angles(0,.3,0)
    p.Color=kind=="Fuse" and Color3.fromRGB(99,158,171) or Color3.fromRGB(161,119,67)
    p.Material=Enum.Material.Metal;p.Anchored=true;p.CanCollide=false;p.Parent=runtime
    local light=Instance.new("PointLight");light.Brightness=.3;light.Range=5
    light.Color=p.Color;light.Parent=p
    if kind=="Seal" then
        local glyph=Instance.new("SurfaceGui");glyph.Face=Enum.NormalId.Front;glyph.Parent=p
        local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
        label.Text="✦";label.TextColor3=Color3.fromRGB(34,29,25);label.TextScaled=true;label.Parent=glyph
    end
    items[p]=kind
    local pr
    pr=promptOn(p,"Take "..kind,kind=="Fuse" and "Generator fuse" or "Cursed seal",.35,function(player)
        local d=party[player]
        if not items[p] then return end
        if not Rules.canPickup(d.status,d.held,kind) then send(player,"Hint","Hands full. Carry your item to its station, or drop it.");return end
        d.held=kind;items[p]=nil;holds[pr]=nil;p:Destroy()
        carryVisual(player,kind);sync(player)
        send(player,"Sound","Whisper")
        if kind=="Seal" and mission.burned>=2 and math.random()<.28 then send(player,"Fright","The seal remembers you.") end
    end)
end
local function teleport(player,pos)
    local root,human=rootFor(player)
    if root then
        root.Anchored=false;root.CFrame=CFrame.new(pos);root.AssemblyLinearVelocity=Vector3.zero
    end
    if human then human.WalkSpeed=Config.WalkSpeed;human.JumpPower=0;human.JumpHeight=0 end
    local d=party[player]
    if d then d.last=pos;d.checked=now();d.budget=10 end
end
local function removeRevive(player)
    local root=rootFor(player)
    local old=root and root:FindFirstChild("RevivePrompt")
    if old then holds[old]=nil;old:Destroy() end
end
local function revive(player,pos)
    local d=party[player]
    if not d then return end
    d.status="Alive";d.hidden=false;d.stamina=70;d.bleedAt=0;d.invulnerable=now()+7
    d.flashlight=true;d.sprinting=false
    removeRevive(player);teleport(player,pos or Vector3.new(0,3.5,35));sync(player)
    send(player,"Hint","You can breathe again. Keep moving.")
end
local function down(player)
    local d=party[player];local root,human=rootFor(player)
    if not d or d.status~="Alive" or d.hidden or now()<d.invulnerable then return end
    drop(player)
    d.status="Downed";d.hidden=false;d.sprinting=false;d.flashlight=false
    d.bleedAt=now()+Config.BleedSeconds
    if root then root.Anchored=true end
    if human then human.WalkSpeed=0 end
    sync(player);send(player,"Jumpscare","CAUGHT BY THE MOURNER")
    if root then
        local pr=promptOn(root,"Revive",player.DisplayName,Config.ReviveSeconds,function(helper)
            if helper==player or d.status~="Downed" then return end
            local pos=root.Position
            revive(player,pos)
            send(helper,"Hint","You pulled them back.")
        end)
        pr.Name="RevivePrompt"
    end
end
local function leaveHide(player)
    local d=party[player];if not d or not d.hidden then return end
    d.hidden=false;d.flashlight=true
    if d.hideExit then teleport(player,d.hideExit);d.hideExit=nil end
    local root,human=rootFor(player)
    if root then root.Anchored=false end
    if human then human.WalkSpeed=Config.WalkSpeed end
    d.invulnerable=math.max(d.invulnerable,now()+.5)
    sync(player)
end
local function lobby(player)
    clearHeldVisual(player);removeRevive(player)
    player:SetAttribute("Status","Lobby");player:SetAttribute("Held","")
    player:SetAttribute("Hidden",false);player:SetAttribute("Stamina",100)
    player:SetAttribute("Flashlight",false);player:SetAttribute("BleedAt",0)
    teleport(player,Vector3.new((player.UserId%4-1.5)*3,4,76))
end
local function setupCharacter(player,character)
    local root=character:WaitForChild("HumanoidRootPart",10)
    local human=character:WaitForChild("Humanoid",10)
    if not root or not human then return end
    local function collision(obj)
        if obj:IsA("BasePart") then obj.CollisionGroup="EmberPlayers" end
    end
    for _,obj in ipairs(character:GetDescendants()) do collision(obj) end
    character.DescendantAdded:Connect(collision)
    human.JumpPower=0;human.JumpHeight=0
    local d=party[player]
    if d and phase=="Playing" then
        if d.status=="Alive" then down(player) end
        d.status="Dead";d.hidden=false;d.held="";sync(player)
        teleport(player,Vector3.new(0,4,76))
    else lobby(player) end
    human.Died:Connect(function()
        local data=party[player]
        if data and data.status=="Alive" then drop(player);data.status="Dead";sync(player) end
    end)
    local attach=Instance.new("Attachment");attach.Name="LanternAttachment";attach.Position=Vector3.new(1,-.5,-.5);attach.Parent=root
    local light=Instance.new("PointLight");light.Name="TeammateLantern";light.Range=13
    light.Brightness=.55;light.Color=Color3.fromRGB(240,195,123);light.Enabled=false;light.Parent=attach
end
local function setup(player)
    allPlayers[player]={tokens=12,time=now()}
    player:SetAttribute("Ready",false);player:SetAttribute("Status","Lobby")
    player:SetAttribute("SpectralOwned",false);player:SetAttribute("SpectralEquipped",false)
    player.RespawnLocation=manor:WaitForChild("LobbySpawn")
    player.CameraMode=Enum.CameraMode.Classic;player.CameraMinZoomDistance=5;player.CameraMaxZoomDistance=10
    player.CharacterAdded:Connect(function(c) setupCharacter(player,c) end)
    player.CharacterRemoving:Connect(function()
        local d=party[player]
        if d and (d.status=="Alive" or d.status=="Downed") then
            drop(player);d.status="Dead";d.hidden=false;sync(player)
        end
    end)
    if player.Character then task.spawn(setupCharacter,player,player.Character) end
    if Config.SpectralLanternPassId>0 then task.spawn(function()
        local ok,owned=pcall(Marketplace.UserOwnsGamePassAsync,Marketplace,player.UserId,Config.SpectralLanternPassId)
        if ok and player.Parent then player:SetAttribute("SpectralOwned",owned) end
    end) end
end
Players.PlayerAdded:Connect(setup)
for _,player in ipairs(Players:GetPlayers()) do setup(player) end
Players.PlayerRemoving:Connect(function(player)
    if party[player] then drop(player);party[player]=nil end
    allPlayers[player]=nil;helpCooldown[player]=nil
    for _,h in pairs(holds) do h[player]=nil end
end)
Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
    if purchased and id==Config.SpectralLanternPassId then
        local ok,owned=pcall(Marketplace.UserOwnsGamePassAsync,Marketplace,player.UserId,id)
        if ok and player.Parent then player:SetAttribute("SpectralOwned",owned) end
    end
end)
action.OnServerEvent:Connect(function(player,kind,value)
    if type(kind)~="string" then return end
    local rate=allPlayers[player];if not rate then return end
    local t=now();rate.tokens=math.min(12,rate.tokens+(t-rate.time)*6);rate.time=t
    if rate.tokens<1 then return end;rate.tokens-=1
    local d=party[player]
    if kind=="Ready" and type(value)=="boolean" and not d then player:SetAttribute("Ready",value)
    elseif kind=="Sprint" and type(value)=="boolean" and d and d.status=="Alive" then d.sprinting=value and d.stamina>5 and not d.hidden
    elseif kind=="Flashlight" and d and d.status=="Alive" and not d.hidden then d.flashlight=not d.flashlight;sync(player)
    elseif kind=="Drop" and d and d.status=="Alive" and not d.hidden then drop(player)
    elseif kind=="LeaveHide" then leaveHide(player)
    elseif kind=="Spectral" and player:GetAttribute("SpectralOwned") then
        player:SetAttribute("SpectralEquipped",not player:GetAttribute("SpectralEquipped"))
    elseif kind=="Call" and d and t>(helpCooldown[player] or 0) then
        helpCooldown[player]=t+6
        broadcast("Hint",player.DisplayName..(d.status=="Downed" and " needs a revive!" or " is calling for the team."))
    end
end)
local function installPrompts()
    promptOn(manor.GeneratorPanel,"Install fuse","GENERATOR",1,function(player)
        local d=party[player]
        if d.held~="Fuse" then send(player,"Hint","Find a blue fuse in the rooms.");return end
        local ok,message=Rules.deposit(mission,d.held)
        if ok then d.held="";carryVisual(player,"");sync(player);stage();broadcast("Sound","Bell") end
        broadcast("Hint",message)
        if director then director:rage() end
    end)
    promptOn(manor.BurnPrompt,"Burn seal","ASH CHAMBER",Config.BurnSeconds,function(player)
        local d=party[player]
        if d.held~="Seal" then send(player,"Hint","Bring a cursed seal here.");return end
        local ok,message=Rules.deposit(mission,d.held)
        if ok then
            d.held="";carryVisual(player,"");sync(player);stage()
            local burning=Instance.new("Part");burning.Name="BurningSeal"
            burning.Size=Vector3.new(1.2,1.5,.35);burning.Anchored=true;burning.CanCollide=false
            burning.Material=Enum.Material.Metal;burning.Color=Color3.fromRGB(181,91,37)
            burning.CFrame=CFrame.new(manor.FurnaceGrate.Position+Vector3.new(0,1.7,0))
            burning.Parent=runtime
            local flame=Instance.new("Fire");flame.Size=4;flame.Heat=2;flame.Parent=burning
            Tween:Create(burning,TweenInfo.new(1.6),{Transparency=1,Size=Vector3.new(.2,.3,.1)}):Play()
            Debris:AddItem(burning,2)
            broadcast("Sound","Burn");broadcast("Burn",mission.burned)
            if director then director:rage() end
        end
        broadcast("Hint",message)
    end)
    promptOn(manor.ExitPrompt,"Escape","FRONT GATE",.6,function(player)
        local d=party[player]
        if not Rules.canEscape(mission,d.status) then send(player,"Hint","The gate stays sealed until all six seals burn.");return end
        drop(player);d.status="Escaped";d.flashlight=false;sync(player)
        teleport(player,Vector3.new(0,4,72))
        send(player,"Hint","You escaped. Wait for the rest of your team.")
    end)
    for _,marker in ipairs(markers:GetChildren()) do
        if marker.Name:match("^Hide") then
            promptOn(marker,"Hide","WARDROBE • short refuge",.4,function(player)
                local d=party[player]
                local seen=director and (director.root.Position-marker.Position).Magnitude<15 and director:visible(player.Character)
                if not Rules.canHide(d.status,seen,d.held) then send(player,"Hint","She saw you. Run!");return end
                d.hidden=true;d.hideUntil=now()+Config.HideSeconds;d.flashlight=false;d.sprinting=false
                d.hideExit=marker.Position
                teleport(player,marker.Position-Vector3.new(0,0,4.5))
                local root=rootFor(player);if root then root.Anchored=true end
                sync(player);send(player,"Hint","Hold your breath. Press H / LEAVE to come out.")
            end)
        end
    end
end
local function reset()
    if director then director:destroy();director=nil end
    for player in pairs(party) do
        if player.Parent then lobby(player);player:SetAttribute("Ready",false) end
    end
    party={}
    for _,prompt in ipairs(prompts) do if prompt.Parent then prompt:Destroy() end end
    prompts={};holds={};items={}
    runtime:ClearAllChildren()
    mission={fuses=0,burned=0,fusesNeeded=Config.Fuses,sealsNeeded=Config.Seals}
    stage()
end
local function eligible()
    local list={}
    for _,player in ipairs(Players:GetPlayers()) do
        local root,human=rootFor(player)
        if player:GetAttribute("Ready") and root and human and human.Health>0 then table.insert(list,player) end
    end
    table.sort(list,function(a,b) return a.UserId<b.UserId end)
    return list
end
local function finish(result)
    if phase~="Playing" then return end
    finalOutcome=result
    state:SetAttribute("Outcome",result)
    phaseSet("Result",12)
    broadcast("Sound",result=="Escaped" and "Bell" or "Impact")
    if director then director.human.WalkSpeed=0 end
end
local accumulated=0
RunService.Heartbeat:Connect(function(dt)
    accumulated+=dt;if accumulated<.1 then return end
    local elapsed=math.min(accumulated,.25);accumulated=0
    if phase~="Playing" then return end
    local t=now()
    for player,d in pairs(party) do
        local root,human=rootFor(player)
        if d.status=="Alive" and root and human then
            if d.hidden and t>=d.hideUntil then leaveHide(player);send(player,"Hint","You cannot stay hidden forever.") end
            if d.stamina<=0 then d.sprinting=false end
            d.stamina=Rules.stamina(d.stamina,d.sprinting and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>1,elapsed)
            human.WalkSpeed=d.hidden and 0 or (d.sprinting and Config.SprintSpeed or Config.WalkSpeed)
            local pos=root.Position
            local distance=Vector3.new(pos.X-d.last.X,0,pos.Z-d.last.Z).Magnitude
            local ok,budget=Rules.movement(d.budget,distance,t-d.checked,Config.SprintSpeed+5)
            d.checked=t;d.budget=budget
            if not ok or not Rules.inHouse(vec(pos)) then
                root.CFrame=CFrame.new(d.last);root.AssemblyLinearVelocity=Vector3.zero
            else d.last=pos end
        elseif d.status=="Downed" and t>=d.bleedAt then
            d.status="Dead";removeRevive(player)
            teleport(player,Vector3.new(0,4,76));send(player,"Hint","Your light went out. Watch your team finish.")
        end
        local attach=root and root:FindFirstChild("LanternAttachment")
        local lamp=attach and attach:FindFirstChild("TeammateLantern")
        if lamp then
            lamp.Enabled=d.status=="Alive" and d.flashlight and not d.hidden
            lamp.Color=player:GetAttribute("SpectralEquipped") and Color3.fromRGB(159,193,220) or Color3.fromRGB(240,195,123)
        end
        sync(player)
    end
    if director then director:step(elapsed,t) end
    local statuses={};local solo
    for player,d in pairs(party) do table.insert(statuses,d.status);solo=player end
    local outcome=Rules.outcome(statuses,matchEnd-t)
    if outcome=="Lost" and #statuses==1 and Config.SoloSecondChance and party[solo] and not party[solo].secondChance
        and party[solo].status=="Downed" and matchEnd>t then
        party[solo].secondChance=true
        revive(solo,Vector3.new(0,3.5,35))
        if director then director.model:PivotTo(CFrame.new(-36,4,-35));director.target=nil;director.lastKnown=nil;director.started=t end
        send(solo,"Hint","ONE LAST CHANCE. The house will not spare you again.")
    elseif outcome then finish(outcome) end
end)
attr({Phase="Lobby",Fuses=0,Burned=0,Threat=0,Outcome="",Objective="ENTER THE HOUSE TO BEGIN",EndsAt=0})
game:BindToClose(function() closing=true end)
task.spawn(function()
    while not closing do
        reset();phaseSet("Lobby")
        repeat task.wait(.5) until #eligible()>0 or closing
        if closing then break end
        phaseSet("Intermission",Config.Intermission)
        task.wait(Config.Intermission)
        local list=eligible()
        if #list==0 then continue end
        roundId+=1
        for i,player in ipairs(list) do
            if i<=Config.MaxPlayers then
                party[player]={status="Alive",held="",stamina=100,hidden=false,flashlight=true,sprinting=false,
                    invulnerable=now()+Config.IntroSeconds+3,bleedAt=0,hideUntil=0,secondChance=false}
                player:SetAttribute("Ready",false)
                teleport(player,Vector3.new((i-2.5)*3,3.5,38));sync(player)
            end
        end
        installPrompts()
        local loot,patrol={},{}
        for _,marker in ipairs(markers:GetChildren()) do
            if marker.Name:match("^Loot") then table.insert(loot,marker.Position) end
            if marker.Name:match("^Patrol") then table.insert(patrol,marker.Position) end
        end
        for i=#loot,2,-1 do local j=math.random(i);loot[i],loot[j]=loot[j],loot[i] end
        for i=1,Config.Fuses+Config.Seals do spawnItem(i<=Config.Fuses and "Fuse" or "Seal",loot[i]) end
        stage();state:SetAttribute("Outcome","")
        phaseSet("Intro",Config.IntroSeconds)
        broadcast("Hint","The generator is dead. Find two blue fuses. Keep your team close.")
        task.wait(Config.IntroSeconds)
        director=Director.new(runtime,{players=function() return party end,down=down,
            threat=function() return Rules.threat(mission.fuses,mission.burned) end,patrol=patrol})
        matchEnd=now()+Config.RoundSeconds
        phaseSet("Playing",Config.RoundSeconds)
        while phase=="Playing" and not closing do task.wait(.2) end
        task.wait(12)
    end
end)
