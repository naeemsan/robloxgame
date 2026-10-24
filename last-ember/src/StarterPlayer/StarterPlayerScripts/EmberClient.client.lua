local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local SoundService=game:GetService("SoundService")
local ContentProvider=game:GetService("ContentProvider")
local ContextAction=game:GetService("ContextActionService")
local Input=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Marketplace=game:GetService("MarketplaceService")
local StarterGui=game:GetService("StarterGui")
local player=Players.LocalPlayer
local Shared=RS:WaitForChild("EmberShared")
local Config=require(Shared.Config)
local Warden=require(Shared.WardenModel)
local net=RS:WaitForChild("EmberNet")
local state=net:WaitForChild("State")
local action=net:WaitForChild("Action")
local signal=net:WaitForChild("Signal")
local camera=workspace.CurrentCamera
local reduced=false
local quality="CINEMATIC"
local audioLevel=1
local optionsOpen=false
local toastText,toastUntil="",0
local scareUntil,scareStarted=0,0
local frightUntil=0
local sprintHeld=false
local spectateIndex=1
local lastHeartbeat=0
local enemyFootsteps
local enemyRoot
local nextWhisper=0
local passPrice
local purchaseBusy=false
local uiClock=0
local palette={black=Color3.fromRGB(13,16,19),paper=Color3.fromRGB(217,211,192),
    amber=Color3.fromRGB(206,153,87),red=Color3.fromRGB(167,65,55),muted=Color3.fromRGB(132,142,145)}
local function emit(kind,value) action:FireServer(kind,value) end
local function toast(message) toastText=message;toastUntil=os.clock()+4 end
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
player.CameraMode=Enum.CameraMode.Classic
player.CameraMinZoomDistance=5;player.CameraMaxZoomDistance=10

-- Only Roblox-bundled fallback sounds are referenced until owner-provided audio IDs exist.
local sounds={}
local master=Instance.new("SoundGroup");master.Name="EmberMix";master.Volume=audioLevel;master.Parent=SoundService
for name,spec in pairs(Config.Audio) do
    local sound=Instance.new("Sound");sound.Name="Ember"..name;sound.SoundGroup=master
    sound.SoundId=spec.id>0 and ("rbxassetid://"..spec.id) or spec.fallback
    sound.Volume=spec.volume
    sound.PlaybackSpeed=spec.id>0 and 1 or spec.rate
    sound.Looped=name=="Drone";sound.Parent=SoundService
    if name=="Scream" or name=="Whisper" then
        local reverb=Instance.new("ReverbSoundEffect")
        reverb.DecayTime=2.8;reverb.DryLevel=-4;reverb.WetLevel=-11;reverb.Parent=sound
    end
    sounds[name]=sound
end
task.spawn(function()
    local all={};for _,s in pairs(sounds) do table.insert(all,s) end
    pcall(function() ContentProvider:PreloadAsync(all) end)
    sounds.Drone:Play()
end)
local function sound(name,volumeScale)
    local original=sounds[name]
    if not original or audioLevel==0 then return end
    local copy=original:Clone();copy.Looped=false
    copy.Volume=original.Volume*(volumeScale or 1)
    copy.Parent=SoundService;copy:Play();Debris:AddItem(copy,15)
end

-- A local shoulder flashlight tracks your view; teammates have replicated lanterns.
local beam=Instance.new("Part");beam.Name="LocalFlashlight";beam.Size=Vector3.new(.1,.1,.1)
beam.Transparency=1;beam.Anchored=true;beam.CanCollide=false;beam.CanTouch=false;beam.CanQuery=false
beam.Parent=workspace
local spot=Instance.new("SpotLight");spot.Name="FlashlightBeam";spot.Face=Enum.NormalId.Front
spot.Angle=72;spot.Range=57;spot.Brightness=3.2;spot.Shadows=true
spot.Color=Color3.fromRGB(244,223,185);spot.Parent=beam
local bounce=Instance.new("PointLight");bounce.Range=9;bounce.Brightness=.3
bounce.Color=spot.Color;bounce.Parent=beam

local gui=Instance.new("ScreenGui");gui.Name="EmberInterface";gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=player:WaitForChild("PlayerGui")
local root=Instance.new("Frame");root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Parent=gui
local function corner(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 5);c.Parent=p end
local function panel(parent,name,pos,size)
    local f=Instance.new("Frame");f.Name=name;f.Position=pos;f.Size=size
    f.BackgroundColor3=palette.black;f.BackgroundTransparency=.12;f.BorderSizePixel=0;f.Parent=parent
    corner(f,7)
    return f
end
local function label(parent,value,pos,size,fontSize,color,font)
    local l=Instance.new("TextLabel");l.Size=size;l.Position=pos;l.BackgroundTransparency=1
    l.Text=value;l.TextColor3=color or palette.paper;l.Font=font or Enum.Font.Gotham
    l.TextSize=fontSize or 15;l.TextWrapped=true;l.Parent=parent
    return l
end
local function button(parent,value,pos,size,callback)
    local b=Instance.new("TextButton");b.Size=size;b.Position=pos;b.BackgroundColor3=Color3.fromRGB(42,39,33)
    b.TextColor3=palette.paper;b.Font=Enum.Font.GothamMedium;b.TextSize=13
    b.TextWrapped=true;b.BorderSizePixel=0;b.Parent=parent;corner(b,5)
    local line=Instance.new("UIStroke");line.Color=palette.amber;line.Transparency=.65;line.Parent=b
    b.Activated:Connect(callback)
    return b
end
local function constrain(p,width,height)
    local s=Instance.new("UISizeConstraint");s.MaxSize=Vector2.new(width,height);s.Parent=p
end
local function vignette()
    for _,s in ipairs({
        {pos=UDim2.fromScale(0,0),size=UDim2.fromScale(1,.13),rotation=90},
        {pos=UDim2.fromScale(0,.87),size=UDim2.fromScale(1,.13),rotation=270},
        {pos=UDim2.fromScale(0,0),size=UDim2.fromScale(.12,1),rotation=0},
        {pos=UDim2.fromScale(.88,0),size=UDim2.fromScale(.12,1),rotation=180},
    }) do
        local f=Instance.new("Frame");f.Size=s.size;f.Position=s.pos
        f.BackgroundColor3=Color3.new(0,0,0);f.BorderSizePixel=0;f.Active=false;f.ZIndex=1;f.Parent=root
        local g=Instance.new("UIGradient");g.Rotation=s.rotation
        g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)})
        g.Parent=f
    end
end
vignette()
local menu=panel(root,"Entry",UDim2.fromScale(.5,.5),UDim2.new(.9,0,0,440))
menu.AnchorPoint=Vector2.new(.5,.5);constrain(menu,620,440);menu.ZIndex=3
label(menu,"A  1–4  PLAYER  CO-OP  HORROR",UDim2.new(.06,0,0,23),UDim2.new(.88,0,0,25),12,palette.amber)
label(menu,"THE LAST\nEMBER",UDim2.new(.04,0,0,57),UDim2.new(.92,0,0,123),51,palette.paper,Enum.Font.Garamond)
label(menu,"The house has six seals.\nThe furnace needs feeding. She needs company.",UDim2.new(.08,0,0,187),UDim2.new(.84,0,0,49),16)
label(menu,"Find 2 fuses → restore power → burn 6 seals → escape.\nStay together. Carry one item. Revive anyone who falls.",UDim2.new(.08,0,0,253),UDim2.new(.84,0,0,48),13,palette.muted)
local enter=button(menu,"ENTER THE HOUSE",UDim2.new(.08,0,0,325),UDim2.new(.84,0,0,48),function()
    emit("Ready",not player:GetAttribute("Ready"))
end)
local queue=label(menu,"Third-person • no overhead camera",UDim2.new(.08,0,0,385),UDim2.new(.84,0,0,33),12,palette.amber)

local objective=panel(root,"Objective",UDim2.fromOffset(15,13),UDim2.new(.66,0,0,84))
constrain(objective,570,84)
local chapter=label(objective,"THE LAST EMBER",UDim2.fromOffset(14,7),UDim2.new(1,-28,0,20),11,palette.amber)
chapter.TextXAlignment=Enum.TextXAlignment.Left
local missionLabel=label(objective,"RESTORE THE GENERATOR",UDim2.fromOffset(14,29),UDim2.new(1,-28,0,45),15)
missionLabel.TextXAlignment=Enum.TextXAlignment.Left
local meter=panel(root,"Progress",UDim2.new(1,-160,0,13),UDim2.fromOffset(145,84))
local seals=label(meter,"0 / 6",UDim2.fromOffset(5,5),UDim2.new(1,-10,0,43),30,palette.amber,Enum.Font.Garamond)
local timer=label(meter,"SEALS BURNED",UDim2.fromOffset(5,50),UDim2.new(1,-10,0,25),11,palette.muted)
local inventory=panel(root,"Hands",UDim2.new(.5,0,1,-93),UDim2.new(.45,0,0,76))
inventory.AnchorPoint=Vector2.new(.5,0);constrain(inventory,390,76)
local held=label(inventory,"HANDS EMPTY",UDim2.fromOffset(8,7),UDim2.new(1,-16,0,25),13)
local staminaBack=panel(inventory,"Stamina",UDim2.new(.08,0,0,42),UDim2.new(.84,0,0,5))
staminaBack.BackgroundColor3=Color3.fromRGB(52,55,55)
local staminaFill=Instance.new("Frame");staminaFill.Size=UDim2.fromScale(1,1)
staminaFill.BackgroundColor3=palette.amber;staminaFill.BorderSizePixel=0;staminaFill.Parent=staminaBack
label(inventory,"STAMINA",UDim2.new(.08,0,0,53),UDim2.new(.84,0,0,15),9,palette.muted)
local team=panel(root,"Team",UDim2.new(0,15,1,-167),UDim2.fromOffset(170,150))
local teamText=label(team,"",UDim2.fromOffset(10,8),UDim2.new(1,-20,1,-16),12)
teamText.TextXAlignment=Enum.TextXAlignment.Left;teamText.TextYAlignment=Enum.TextYAlignment.Top
local settings=button(root,"SETTINGS",UDim2.new(1,-123,0,108),UDim2.fromOffset(108,30),function()
    optionsOpen=not optionsOpen
    if optionsOpen then sprintHeld=false;emit("Sprint",false) end
end)
local hint=label(root,"",UDim2.new(.5,0,1,-157),UDim2.new(.86,0,0,45),15,palette.paper)
hint.AnchorPoint=Vector2.new(.5,0);hint.BackgroundColor3=palette.black;hint.BackgroundTransparency=.12
constrain(hint,720,45);corner(hint,5);hint.Visible=false;hint.ZIndex=7
local danger=label(root,"",UDim2.new(.5,0,0,108),UDim2.new(.62,0,0,35),14,palette.red)
danger.AnchorPoint=Vector2.new(.5,0)

local touch=panel(root,"Actions",UDim2.new(1,-173,1,-171),UDim2.fromOffset(158,154))
touch.BackgroundTransparency=1
local sprintButton=button(touch,"SPRINT",UDim2.fromOffset(0,0),UDim2.fromOffset(158,40),function()
    sprintHeld=not sprintHeld;emit("Sprint",sprintHeld)
end)
button(touch,"LIGHT [F]",UDim2.fromOffset(0,49),UDim2.fromOffset(76,40),function() emit("Flashlight") end)
button(touch,"DROP [G]",UDim2.fromOffset(82,49),UDim2.fromOffset(76,40),function() emit("Drop") end)
button(touch,"CALL TEAM [Q]",UDim2.fromOffset(0,98),UDim2.fromOffset(158,40),function() emit("Call") end)

local options=panel(root,"Settings",UDim2.fromScale(.5,.5),UDim2.new(.9,0,0,400))
options.AnchorPoint=Vector2.new(.5,.5);constrain(options,580,400);options.Visible=false;options.ZIndex=5
label(options,"KEEP THE DARKNESS READABLE",UDim2.new(.06,0,0,20),UDim2.new(.88,0,0,37),22,palette.paper,Enum.Font.Garamond)
local qualityButton
local function applyQuality()
    local cinematic=quality=="CINEMATIC"
    Lighting.GlobalShadows=quality~="LOW"
    pcall(function()
        Lighting.LightingStyle=quality=="LOW" and Enum.LightingStyle.Soft or Enum.LightingStyle.Realistic
        Lighting.PrioritizeLightingQuality=cinematic
    end)
    spot.Shadows=quality~="LOW";spot.Range=quality=="LOW" and 43 or 57
    for _,light in ipairs(workspace.Manor:GetDescendants()) do
        if light:IsA("PointLight") then light.Shadows=cinematic and not light.Parent.Name:match("Moonlight") end
    end
    local bloom=Lighting:FindFirstChild("EmberBloom");if bloom then bloom.Enabled=quality~="LOW" end
end
qualityButton=button(options,"QUALITY: CINEMATIC",UDim2.new(.08,0,0,79),UDim2.new(.84,0,0,43),function()
    quality=quality=="CINEMATIC" and "BALANCED" or (quality=="BALANCED" and "LOW" or "CINEMATIC")
    applyQuality()
end)
local audioButton=button(options,"SOUND: FULL",UDim2.new(.08,0,0,133),UDim2.new(.84,0,0,43),function()
    audioLevel=audioLevel==1 and .4 or (audioLevel==.4 and 0 or 1);master.Volume=audioLevel
end)
local scareButton=button(options,"SCARES: FULL",UDim2.new(.08,0,0,187),UDim2.new(.84,0,0,43),function()
    reduced=not reduced
end)
local passButton=button(options,"SPECTRAL LANTERN • NOT ON SALE",UDim2.new(.08,0,0,241),UDim2.new(.84,0,0,43),function()
    if player:GetAttribute("SpectralOwned") then emit("Spectral");return end
    if not passPrice or purchaseBusy then toast("Optional lantern tint is not on sale.");return end
    purchaseBusy=true
    local ok=pcall(function() Marketplace:PromptGamePassPurchase(player,Config.SpectralLanternPassId) end)
    if not ok then purchaseBusy=false;toast("Roblox shop is unavailable.") end
end)
label(options,"Lantern tint is cosmetic only. It does not change brightness.\nInteract: hold E / X / tap a prompt. Sprint: Shift / L3.",UDim2.new(.08,0,0,298),UDim2.new(.84,0,0,46),12,palette.muted)
button(options,"BACK",UDim2.new(.3,0,1,-45),UDim2.new(.4,0,0,30),function() optionsOpen=false end)

local hidden=panel(root,"Hiding",UDim2.fromScale(0,0),UDim2.fromScale(1,1))
hidden.BackgroundColor3=Color3.new(0,0,0);hidden.BackgroundTransparency=.06;hidden.ZIndex=6;hidden.Visible=false
label(hidden,"DON'T BREATHE.",UDim2.new(.1,0,.35,0),UDim2.new(.8,0,0,60),35,palette.muted,Enum.Font.Garamond)
label(hidden,"You can only hide briefly. Listen for her footsteps.",UDim2.new(.1,0,.49,0),UDim2.new(.8,0,0,40),14,palette.muted)
button(hidden,"LEAVE WARDROBE [H]",UDim2.new(.3,0,.65,0),UDim2.new(.4,0,0,45),function() emit("LeaveHide") end)
local downPanel=panel(root,"Downed",UDim2.new(.5,0,.33,0),UDim2.new(.85,0,0,154))
downPanel.AnchorPoint=Vector2.new(.5,0);constrain(downPanel,590,154);downPanel.ZIndex=5;downPanel.Visible=false
local downTitle=label(downPanel,"YOUR LIGHT IS FADING",UDim2.new(.05,0,0,14),UDim2.new(.9,0,0,40),29,palette.red,Enum.Font.Garamond)
local downInfo=label(downPanel,"",UDim2.new(.05,0,0,60),UDim2.new(.9,0,0,37),13)
local downAction=button(downPanel,"CALL YOUR TEAM",UDim2.new(.3,0,1,-44),UDim2.new(.4,0,0,30),function()
    if player:GetAttribute("Status")=="Downed" then emit("Call")
    else spectateIndex+=1 end
end)
local result=panel(root,"Outcome",UDim2.fromScale(.5,.5),UDim2.new(.88,0,0,228))
result.AnchorPoint=Vector2.new(.5,.5);constrain(result,640,228);result.ZIndex=5;result.Visible=false
local resultTitle=label(result,"",UDim2.new(.04,0,0,22),UDim2.new(.92,0,0,84),40,palette.paper,Enum.Font.Garamond)
local resultText=label(result,"",UDim2.new(.08,0,0,120),UDim2.new(.84,0,0,75),15,palette.muted)

-- The close-up is rendered from our original model, not a downloaded image.
local scare=Instance.new("ViewportFrame");scare.Name="MournerCloseUp"
scare.Size=UDim2.fromScale(1,1);scare.BackgroundColor3=Color3.fromRGB(2,3,4)
scare.Ambient=Color3.fromRGB(100,106,119);scare.LightColor=Color3.fromRGB(170,177,182)
scare.LightDirection=Vector3.new(-.4,1,-1);scare.ZIndex=20;scare.Visible=false;scare.Parent=gui
local world=Instance.new("WorldModel");world.Parent=scare
Warden.create(world,true)
local scareCamera=Instance.new("Camera");scareCamera.FieldOfView=49;scareCamera.Parent=scare;scare.CurrentCamera=scareCamera
local blackout=Instance.new("Frame");blackout.Size=UDim2.fromScale(1,1);blackout.BackgroundColor3=Color3.new(0,0,0)
blackout.BorderSizePixel=0;blackout.Visible=false;blackout.ZIndex=21;blackout.Parent=gui
local function jumpScare()
    scareStarted=os.clock();scareUntil=scareStarted+(reduced and .4 or 1.3)
    sound("Impact",reduced and .3 or 1)
    sound("Scream",reduced and .25 or 1)
end
signal.OnClientEvent:Connect(function(kind,value)
    if kind=="Hint" and type(value)=="string" then toast(value)
    elseif kind=="Sound" and type(value)=="string" then sound(value)
    elseif kind=="Jumpscare" then jumpScare()
    elseif kind=="Fright" then frightUntil=os.clock()+.7;sound("Whisper",.7);toast(value)
    elseif kind=="Burn" then
        sound("Scream",.45);frightUntil=os.clock()+1.1
        if not reduced then
            local grade=Lighting:FindFirstChild("EmberGrade")
            if grade then
                Tween:Create(grade,TweenInfo.new(.2),{Brightness=-.12}):Play()
                task.delay(.3,function() Tween:Create(grade,TweenInfo.new(.8),{Brightness=-.025}):Play() end)
            end
        end
    end
end)
local function bind(name,inputState)
    if Input:GetFocusedTextBox() or optionsOpen then return Enum.ContextActionResult.Pass end
    if name=="EmberSprint" then
        if inputState==Enum.UserInputState.Begin then sprintHeld=true;emit("Sprint",true)
        elseif inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel then sprintHeld=false;emit("Sprint",false) end
    elseif inputState==Enum.UserInputState.Begin then
        if name=="EmberLight" then emit("Flashlight") elseif name=="EmberDrop" then emit("Drop")
        elseif name=="EmberHide" then emit("LeaveHide") else emit("Call") end
    end
    return Enum.ContextActionResult.Sink
end
ContextAction:BindAction("EmberSprint",bind,false,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonL3)
ContextAction:BindAction("EmberLight",bind,false,Enum.KeyCode.F,Enum.KeyCode.ButtonY)
ContextAction:BindAction("EmberDrop",bind,false,Enum.KeyCode.G,Enum.KeyCode.DPadDown)
ContextAction:BindAction("EmberHide",bind,false,Enum.KeyCode.H,Enum.KeyCode.ButtonB)
ContextAction:BindAction("EmberCall",bind,false,Enum.KeyCode.Q,Enum.KeyCode.DPadUp)
Input.WindowFocusReleased:Connect(function() sprintHeld=false;emit("Sprint",false) end)
Marketplace.PromptGamePassPurchaseFinished:Connect(function(buyer,id)
    if buyer==player and id==Config.SpectralLanternPassId then purchaseBusy=false end
end)
if Config.SpectralLanternPassId>0 then task.spawn(function()
    local ok,info=pcall(Marketplace.GetProductInfo,Marketplace,Config.SpectralLanternPassId,Enum.InfoType.GamePass)
    if ok and info.IsForSale and info.PriceInRobux then passPrice=info.PriceInRobux end
end) end
local function refresh()
    local phase=state:GetAttribute("Phase") or "Lobby"
    local status=player:GetAttribute("Status") or "Lobby"
    local active=status=="Alive"
    local hiding=player:GetAttribute("Hidden")==true
    local remaining=math.max(0,math.ceil((state:GetAttribute("EndsAt") or 0)-workspace:GetServerTimeNow()))
    menu.Visible=status=="Lobby" and not optionsOpen
    options.Visible=optionsOpen
    objective.Visible=not menu.Visible and not optionsOpen
    meter.Visible=objective.Visible
    inventory.Visible=active and not optionsOpen and not hiding
    touch.Visible=active and not optionsOpen and not hiding
    team.Visible=not menu.Visible and not optionsOpen and not hiding
    hidden.Visible=hiding and not optionsOpen
    settings.Visible=not hiding
    local isResult=phase=="Result" and status~="Lobby"
    result.Visible=isResult and not optionsOpen
    downPanel.Visible=(status=="Downed" or status=="Dead" or status=="Escaped") and not isResult and not optionsOpen
    if status=="Downed" then
        downTitle.Text="YOUR LIGHT IS FADING"
        downInfo.Text=string.format("A teammate can revive you. %ds remaining.",math.max(0,math.ceil((player:GetAttribute("BleedAt") or 0)-workspace:GetServerTimeNow())))
        downAction.Text="CALL YOUR TEAM"
    elseif status=="Escaped" then downTitle.Text="YOU MADE IT OUT";downInfo.Text="Your team is still inside.";downAction.Text="WATCH NEXT TEAMMATE"
    else downTitle.Text="THE HOUSE KEPT YOU";downInfo.Text="Watch your teammates finish the mission.";downAction.Text="WATCH NEXT TEAMMATE" end
    enter.Text=player:GetAttribute("Ready") and "READY • CLICK TO CANCEL" or "ENTER THE HOUSE"
    local count=0;for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute("Ready") then count+=1 end end
    if phase=="Intermission" then queue.Text=string.format("%d READY • STARTING IN %ds",count,remaining)
    elseif phase=="Playing" or phase=="Intro" then queue.Text="A mission is running • ready up for the next one"
    else queue.Text=string.format("%d / 4 READY • SOLO OR WITH FRIENDS",math.min(count,4)) end
    chapter.Text=string.format("THE LAST EMBER  /  %02d:%02d",math.floor(remaining/60),remaining%60)
    missionLabel.Text=state:GetAttribute("Objective") or ""
    seals.Text=string.format("%d / %d",state:GetAttribute("Burned") or 0,Config.Seals)
    timer.Text=(state:GetAttribute("Fuses") or 0)<2 and string.format("FUSES: %d / 2",state:GetAttribute("Fuses") or 0) or "SEALS BURNED"
    local item=player:GetAttribute("Held") or ""
    held.Text=item=="" and "HANDS EMPTY • HOLD E TO INTERACT" or (item=="Fuse" and "CARRYING FUSE → GENERATOR" or "CARRYING SEAL → ASH CHAMBER")
    staminaFill.Size=UDim2.fromScale((player:GetAttribute("Stamina") or 100)/100,1)
    sprintButton.Text=Input.TouchEnabled and (sprintHeld and "STOP SPRINT" or "SPRINT") or "SPRINT [SHIFT / L3]"
    local names={"YOUR TEAM"}
    local survivors={}
    for _,p in ipairs(Players:GetPlayers()) do
        local s=p:GetAttribute("Status")
        if s and s~="Lobby" then
            table.insert(names,p.DisplayName.."  /  "..string.upper(s))
            if s=="Alive" and p.Character then table.insert(survivors,p) end
        end
    end
    teamText.Text=table.concat(names,"\n")
    camera=workspace.CurrentCamera
    if camera then
        camera.CameraType=Enum.CameraType.Custom
        local subject=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if (status=="Dead" or status=="Escaped") and #survivors>0 then
            local p=survivors[(spectateIndex-1)%#survivors+1]
            subject=p.Character:FindFirstChildOfClass("Humanoid")
        end
        if subject then camera.CameraSubject=subject end
    end
    if isResult then
        local escaped=state:GetAttribute("Outcome")=="Escaped"
        resultTitle.Text=escaped and "YOU LEFT THE HOUSE.\nIT DIDN'T LEAVE YOU." or "THE HOUSE\nKEPT YOUR LIGHT."
        resultText.Text=string.format("%d of 6 seals destroyed.\nReturning outside in %ds.",state:GetAttribute("Burned") or 0,remaining)
    end
    qualityButton.Text="QUALITY: "..quality
    audioButton.Text=audioLevel==1 and "SOUND: FULL" or (audioLevel==0 and "SOUND: OFF" or "SOUND: LOW")
    scareButton.Text=reduced and "SCARES: REDUCED • NO CLOSE-UP / SHAKE" or "SCARES: FULL"
    passButton.Text=player:GetAttribute("SpectralOwned") and ("SPECTRAL TINT: "..(player:GetAttribute("SpectralEquipped") and "ON" or "OFF"))
        or (passPrice and ("SPECTRAL LANTERN • "..passPrice.." ROBUX") or "SPECTRAL LANTERN • NOT ON SALE")
    hint.Visible=os.clock()<toastUntil and not optionsOpen;hint.Text=toastText
    local view=camera and camera.ViewportSize or Vector2.new(1280,720)
    for _,p in ipairs({menu,options,result}) do
        local scale=p:FindFirstChildOfClass("UIScale") or Instance.new("UIScale",p)
        scale.Scale=math.min(1,math.max(220,view.Y-70)/p.Size.Y.Offset)
    end
end
applyQuality()
RunService:BindToRenderStep("EmberView",Enum.RenderPriority.Camera.Value+1,function(dt)
    camera=workspace.CurrentCamera
    if not camera then return end
    local status=player:GetAttribute("Status")
    local head=player.Character and player.Character:FindFirstChild("Head")
    local enabled=status=="Alive" and player:GetAttribute("Flashlight") and not player:GetAttribute("Hidden")
    spot.Enabled=enabled;bounce.Enabled=enabled
    if head then beam.CFrame=CFrame.lookAt(head.Position+camera.CFrame.RightVector*.6,head.Position+camera.CFrame.LookVector*30) end
    spot.Color=player:GetAttribute("SpectralEquipped") and Color3.fromRGB(192,219,241) or Color3.fromRGB(244,223,185)
    local t=os.clock()
    local entity=workspace:FindFirstChild("EmberRuntime") and workspace.EmberRuntime:FindFirstChild("The Mourner")
    if entity and entity.PrimaryPart and enemyRoot~=entity.PrimaryPart then
        if enemyFootsteps then enemyFootsteps:Destroy() end
        enemyRoot=entity.PrimaryPart
        enemyFootsteps=Instance.new("Sound")
        enemyFootsteps.Name="MournerFootsteps";enemyFootsteps.SoundGroup=master
        enemyFootsteps.SoundId="rbxasset://sounds/action_footsteps_plastic.mp3"
        enemyFootsteps.Volume=.4;enemyFootsteps.PlaybackSpeed=.65;enemyFootsteps.Looped=true
        enemyFootsteps.RollOffMinDistance=5;enemyFootsteps.RollOffMaxDistance=48
        enemyFootsteps.Parent=enemyRoot
        local reverb=Instance.new("ReverbSoundEffect");reverb.DecayTime=2;reverb.WetLevel=-10;reverb.Parent=enemyFootsteps
    end
    if enemyFootsteps and enemyRoot and enemyRoot.Parent then
        local moving=enemyRoot.AssemblyLinearVelocity.Magnitude>.8 and state:GetAttribute("Phase")=="Playing"
        if moving and not enemyFootsteps.IsPlaying then enemyFootsteps:Play()
        elseif not moving and enemyFootsteps.IsPlaying then enemyFootsteps:Stop() end
    end
    local rootPart=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local distance=entity and entity.PrimaryPart and rootPart and (entity.PrimaryPart.Position-rootPart.Position).Magnitude or 200
    local dangerLevel=status=="Alive" and math.clamp((34-distance)/28,0,1) or 0
    danger.Text=dangerLevel>.7 and "SHE IS CLOSE." or ""
    if dangerLevel>.15 and t-lastHeartbeat>1.05-dangerLevel*.5 then lastHeartbeat=t;sound("Heartbeat",dangerLevel) end
    if status=="Alive" and t>nextWhisper then nextWhisper=t+math.random(20,38);sound("Whisper",.5) end
    if not reduced and dangerLevel>.5 and not optionsOpen then
        camera.CFrame=camera.CFrame*CFrame.Angles(math.sin(t*9)*.0015*dangerLevel,0,math.sin(t*7)*.0015*dangerLevel)
    end
    scare.Visible=t<scareUntil and not reduced
    blackout.Visible=(t<scareUntil and reduced) or (t>=scareStarted+.95 and t<scareUntil)
    if scare.Visible then
        local progress=math.clamp((t-scareStarted)/.3,0,1)
        scareCamera.CFrame=CFrame.lookAt(Vector3.new(math.sin(t*43)*.045,3.1,-4+progress*1.5),Vector3.new(0,3.1,-.2))
    end
    if t<frightUntil and not reduced then danger.Text="DON'T TURN AROUND." end
    uiClock+=dt
    if uiClock>=.1 then uiClock=0;refresh() end
end)
refresh()
