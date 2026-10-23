local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local ContextAction = game:GetService("ContextActionService")
local Marketplace = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Shared = RS:WaitForChild("RumalShared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local net = RS:WaitForChild("RumalNet")
local action, state, notice = net:WaitForChild("Action"), net:WaitForChild("State"), net:WaitForChild("Notice")
local C = Config.Colors
local camera = workspace.CurrentCamera
local overview, reducedMotion, shopOpen, helpOpen = true, false, false, false
local passPrice
local purchaseBusy = false
local notification, notificationUntil, lastPhase = "", 0, ""
local lastCoins
local renderClock = 0

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
local gui = Instance.new("ScreenGui")
gui.Name = "RumalRushUI";gui.ResetOnSpawn = false;gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Name = "ResponsiveRoot";root.BackgroundTransparency = 1;root.Size = UDim2.fromScale(1,1);root.Parent = gui
local function round(parent,radius)
    local c = Instance.new("UICorner");c.CornerRadius = UDim.new(0,radius or 12);c.Parent = parent
end
local function frame(parent,name,pos,size,color)
    local f = Instance.new("Frame");f.Name = name;f.Position = pos;f.Size = size
    f.BackgroundColor3 = color or C.Ink;f.BorderSizePixel = 0;f.Parent = parent;round(f,14)
    return f
end
local function text(parent,name,value,pos,size,fontSize,color,align)
    local l = Instance.new("TextLabel");l.Name = name;l.Text = value;l.Position = pos;l.Size = size
    l.BackgroundTransparency = 1;l.TextColor3 = color or C.Cream;l.Font = Enum.Font.GothamBold
    l.TextSize = fontSize or 16;l.TextWrapped = true;l.TextXAlignment = align or Enum.TextXAlignment.Center
    l.Parent = parent
    return l
end
local function button(parent,name,value,pos,size,color,callback)
    local b = Instance.new("TextButton");b.Name = name;b.Text = value;b.Position = pos;b.Size = size
    b.BackgroundColor3 = color or C.Teal;b.TextColor3 = C.Ink;b.Font = Enum.Font.GothamBold
    b.TextSize = 15;b.TextWrapped = true;b.AutoButtonColor = true;b.BorderSizePixel = 0;b.Parent = parent
    round(b,10);b.Activated:Connect(callback)
    return b
end
local function cap(parent,width,height)
    local c = Instance.new("UISizeConstraint")
    c.MaxSize = Vector2.new(width,height or 10000);c.Parent = parent
end
local function toast(value) notification = value;notificationUntil = os.clock()+3.5 end
local function send(kind,value) action:FireServer(kind,value) end

local header = frame(root,"Scoreboard",UDim2.new(.5,0,0,8),UDim2.new(.92,0,0,76))
header.AnchorPoint = Vector2.new(.5,0);cap(header,560,76)
local tealScore = text(header,"TealScore","TEAL  0",UDim2.new(0,12,0,10),UDim2.new(.3,-12,0,28),21,C.Teal)
local coralScore = text(header,"CoralScore","0  CORAL",UDim2.new(.7,0,0,10),UDim2.new(.3,-12,0,28),21,C.Coral)
local clock = text(header,"Clock","RUMAL RUSH",UDim2.new(.3,0,0,8),UDim2.new(.4,0,0,30),17,C.Gold)
local matchInfo = text(header,"MatchInfo","FIRST TO 3",UDim2.new(0,8,0,44),UDim2.new(1,-16,0,22),12)
local banner = text(root,"Instruction","",UDim2.new(.5,0,0,94),UDim2.new(.9,0,0,36),17,C.Ink)
banner.AnchorPoint = Vector2.new(.5,0);cap(banner,680,36)
banner.TextStrokeColor3 = C.Cream;banner.TextStrokeTransparency = .55

local tools = frame(root,"Tools",UDim2.new(0,12,1,-116),UDim2.fromOffset(142,102))
local wallet = text(tools,"Wallet","0 COINS",UDim2.fromOffset(6,4),UDim2.new(1,-12,0,26),15,C.Gold)
button(tools,"Locker","LOCKER",UDim2.fromOffset(8,35),UDim2.fromOffset(126,28),C.Cream,function()
    shopOpen = not shopOpen;helpOpen = false
end)
button(tools,"Help","HOW TO PLAY",UDim2.fromOffset(8,69),UDim2.fromOffset(126,25),C.Teal,function()
    helpOpen = not helpOpen;shopOpen = false
end)
local status = text(root,"Status","",UDim2.new(.5,0,1,-35),UDim2.new(.48,0,0,27),11,C.Cream)
status.AnchorPoint = Vector2.new(.5,0)
status.BackgroundColor3 = C.Ink;status.BackgroundTransparency = .15;round(status,8)
local exit = button(root,"SitOut","SIT OUT",UDim2.new(1,-116,0,94),UDim2.fromOffset(104,28),C.Cream,function()
    send("Ready",false)
end)
exit.Visible = false
local controls = frame(root,"Actions",UDim2.new(1,-160,1,-138),UDim2.fromOffset(148,124))
controls.BackgroundTransparency = 1
local grabButton = button(controls,"Grab","GRAB [E]",UDim2.fromOffset(0,0),UDim2.fromOffset(148,52),C.Gold,function() send("Grab") end)
local dashButton = button(controls,"Dash","DASH [SHIFT]",UDim2.fromOffset(0,62),UDim2.fromOffset(148,52),C.Teal,function() send("Dash") end)

local menu = frame(root,"Welcome",UDim2.fromScale(.5,.52),UDim2.new(.9,0,0,384))
menu.AnchorPoint = Vector2.new(.5,.5);cap(menu,590,384)
text(menu,"Kicker","THE COURTYARD IS CALLING",UDim2.new(0,20,0,19),UDim2.new(1,-40,0,22),12,C.Teal)
text(menu,"Title","RUMAL RUSH",UDim2.new(0,16,0,44),UDim2.new(1,-32,0,49),36,C.Cream)
text(menu,"Subtitle","A real playground rivalry. One scarf. Two sides.",UDim2.new(0,24,0,97),UDim2.new(1,-48,0,38),16,C.Gold)
local instructions = {
    {"01", "GRAB", "Reach the scarf. Press E or tap GRAB."},
    {"02", "OUTSMART", "Bait your rival. Save your dash for the chase."},
    {"03", "GET HOME", "Cross your colored line. Or tag the carrier!"},
}
for i,step in ipairs(instructions) do
    local y = 145+(i-1)*44
    text(menu,"Number"..i,step[1],UDim2.new(0,20,0,y),UDim2.fromOffset(28,32),18,C.Teal)
    text(menu,"Step"..i,step[2].."  /  "..step[3],UDim2.new(0,58,0,y),UDim2.new(1,-78,0,36),13,C.Cream,Enum.TextXAlignment.Left)
end
local play = button(menu,"Play","PLAY A MATCH",UDim2.new(.06,0,1,-90),UDim2.new(.58,0,0,46),C.Teal,function()
    shopOpen = false;helpOpen = false;send("Ready",true)
end)
local difficulty = button(menu,"Difficulty","BOT: EASY",UDim2.new(.67,0,1,-90),UDim2.new(.27,0,0,46),C.Gold,function()
    send("Difficulty",player:GetAttribute("Difficulty") == "Standard" and "Easy" or "Standard")
end)
text(menu,"SoloHint","Solo? Milo joins you. Friends? Take turns in team duels.",UDim2.new(.05,0,1,-37),UDim2.new(.9,0,0,27),12,C.Cream)

local help = frame(root,"HelpPanel",UDim2.fromScale(.5,.52),UDim2.new(.9,0,0,360))
help.AnchorPoint = Vector2.new(.5,.5);cap(help,580,360);help.Visible = false
text(help,"Title","WIN THE CHASE",UDim2.new(0,16,0,20),UDim2.new(1,-32,0,35),27,C.Gold)
text(help,"Rules",[[1. Nobody can tag until someone takes the rumal.
2. Carry it over YOUR home line to score.
3. Chase the carrier; close contact tags automatically.
4. Dash gives a short speed burst, NOT invincibility.
5. No pickup before time runs out? The round is a draw.
6. First team to 3 wins. Teammates rotate each round.]],UDim2.new(0,24,0,68),UDim2.new(1,-48,0,180),15,C.Cream,Enum.TextXAlignment.Left)
text(help,"Inputs","MOVE: WASD / left stick / touch stick\nGRAB: E / X   •   DASH: Shift / B",UDim2.new(0,24,0,250),UDim2.new(1,-48,0,44),13,C.Teal)
button(help,"Close","GOT IT",UDim2.new(.3,0,1,-54),UDim2.new(.4,0,0,38),C.Teal,function() helpOpen = false end)

local shop = frame(root,"LockerPanel",UDim2.fromScale(.5,.52),UDim2.new(.92,0,0,446))
shop.AnchorPoint = Vector2.new(.5,.5);cap(shop,610,446);shop.Visible = false
text(shop,"Title","YOUR LOCKER",UDim2.new(0,20,0,16),UDim2.new(1,-80,0,32),25,C.Gold,Enum.TextXAlignment.Left)
button(shop,"Close","X",UDim2.new(1,-50,0,15),UDim2.fromOffset(34,32),C.Cream,function() shopOpen = false end)
text(shop,"Note","Cosmetics only. Everyone has the same speed and dash.",UDim2.new(0,20,0,52),UDim2.new(1,-40,0,30),12)
local shopButtons = {}
for i,item in ipairs(Cosmetics) do
    local row = frame(shop,"Item_"..item.id,UDim2.new(0,16,0,90+(i-1)*56),UDim2.new(1,-32,0,49),Color3.fromRGB(38,52,65))
    frame(row,"Swatch",UDim2.fromOffset(10,10),UDim2.fromOffset(28,28),item.color)
    text(row,"Name",item.name,UDim2.fromOffset(48,3),UDim2.new(.6,-48,0,23),14,C.Cream,Enum.TextXAlignment.Left)
    text(row,"Description",item.pass and "Permanent cosmetic pass" or "Earned with play coins",UDim2.fromOffset(48,26),UDim2.new(.6,-48,0,18),10,C.Teal,Enum.TextXAlignment.Left)
    shopButtons[item.id] = button(row,"Buy","",UDim2.new(.63,0,0,7),UDim2.new(.35,-8,0,35),item.color,function()
        if item.pass and not player:GetAttribute("NeonOwned") then
            if not passPrice or Config.NeonPassId <= 0 or purchaseBusy then toast("Neon is not on sale yet.");return end
            purchaseBusy = true
            local ok = pcall(function() Marketplace:PromptGamePassPurchase(player,Config.NeonPassId) end)
            if not ok then purchaseBusy = false;toast("Roblox shop unavailable. Try again later.") end
        else send("Equip",item.id) end
    end)
end
local viewButton = button(shop,"Camera","VIEW: ARENA",UDim2.new(.04,0,1,-61),UDim2.new(.44,0,0,32),C.Cream,function()
    overview = not overview
end)
local motionButton = button(shop,"Motion","FX: ON",UDim2.new(.52,0,1,-61),UDim2.new(.44,0,0,32),C.Cream,function()
    reducedMotion = not reducedMotion
    for _,object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Trail") then object.Enabled = not reducedMotion end
    end
end)
text(shop,"SafeShop","No random rewards. No paid advantages.",UDim2.new(.04,0,1,-26),UDim2.new(.92,0,0,18),11,C.Teal)

local result = frame(root,"Result",UDim2.fromScale(.5,.38),UDim2.new(.88,0,0,138))
result.AnchorPoint = Vector2.new(.5,.5);cap(result,540,138);result.Visible = false
local resultTitle = text(result,"Title","HOME SAFE!",UDim2.new(.04,0,0,17),UDim2.new(.92,0,0,44),29,C.Gold)
resultTitle.TextScaled = true
local resultDetail = text(result,"Detail","",UDim2.new(.05,0,0,68),UDim2.new(.9,0,0,50),16)
local toastLabel = text(root,"Toast","",UDim2.new(.5,0,1,-164),UDim2.new(.86,0,0,38),14,C.Cream)
toastLabel.AnchorPoint = Vector2.new(.5,0);toastLabel.BackgroundColor3 = C.Ink;toastLabel.BackgroundTransparency = .1
cap(toastLabel,600,38);round(toastLabel,10);toastLabel.Visible = false

local function inputAction(name,inputState)
    if inputState ~= Enum.UserInputState.Begin or UserInput:GetFocusedTextBox() or not player:GetAttribute("Active") then
        return Enum.ContextActionResult.Pass
    end
    if name == "RumalGrab" then send("Grab") else send("Dash") end
    return Enum.ContextActionResult.Sink
end
ContextAction:BindAction("RumalGrab",inputAction,false,Enum.KeyCode.E,Enum.KeyCode.ButtonX)
ContextAction:BindAction("RumalDash",inputAction,false,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift,Enum.KeyCode.ButtonB)

local function update()
    local phase = state:GetAttribute("Phase") or "Lobby"
    local active = player:GetAttribute("Active") == true
    local ready = player:GetAttribute("Ready") == true
    local side = player:GetAttribute("Side") or 0
    local seconds = math.max(0,math.ceil((state:GetAttribute("EndsAt") or 0)-workspace:GetServerTimeNow()))
    local coins = player:GetAttribute("Coins") or 0
    local carrier = state:GetAttribute("Carrier") or 0
    if phase ~= lastPhase then
        if phase == "Countdown" then shopOpen = false;helpOpen = false end
        if not reducedMotion and (phase == "Result" or phase == "MatchEnd") then
            result.BackgroundTransparency = .6
            TweenService:Create(result,TweenInfo.new(.25),{BackgroundTransparency=0}):Play()
        end
        lastPhase = phase
    end
    tealScore.Text = "TEAL  "..(state:GetAttribute("TealScore") or 0)
    coralScore.Text = (state:GetAttribute("CoralScore") or 0).."  CORAL"
    clock.Text = (phase == "Live" or phase == "Countdown") and string.format("%02d",seconds) or "RUMAL RUSH"
    matchInfo.Text = string.format("%s  •  ROUND %d  •  FIRST TO %d",state:GetAttribute("Mode") or "Practice",state:GetAttribute("Round") or 0,Config.MatchTarget)
    wallet.Text = string.format("%d COINS",coins)
    if lastCoins and coins > lastCoins then toast("+"..(coins-lastCoins).." coins") end
    lastCoins = coins
    controls.Visible = active and phase == "Live" and not shopOpen and not helpOpen
    exit.Visible = ready and not shopOpen and not helpOpen
    local dashRemaining = math.max(0,(player:GetAttribute("DashReadyAt") or 0)-workspace:GetServerTimeNow())
    dashButton.Text = dashRemaining > 0 and string.format("DASH  %.1fs",dashRemaining) or (UserInput.TouchEnabled and "DASH" or "DASH [SHIFT / B]")
    dashButton.BackgroundColor3 = dashRemaining > 0 and Color3.fromRGB(130,154,156) or C.Teal
    grabButton.Text = carrier == side and carrier > 0 and "RUN HOME!" or (carrier > 0 and "TAG: GET CLOSE" or (UserInput.TouchEnabled and "GRAB" or "GRAB [E / X]"))
    difficulty.Text = "BOT: "..string.upper(player:GetAttribute("Difficulty") or "Easy")
    local isResult = phase == "Result" or phase == "MatchEnd"
    menu.Visible = not ready and not active and not shopOpen and not helpOpen and not (isResult and side > 0)
    shop.Visible = shopOpen;help.Visible = helpOpen
    tools.Visible = not active or phase ~= "Live"
    play.Text = (state:GetAttribute("Match") or 0) > 0 and "PLAY / JOIN NEXT MATCH" or "PLAY A MATCH"
    if active and phase == "Countdown" then
        banner.Text = "YOU ARE "..(side == 1 and "TEAL ←" or "CORAL →").."  •  "..seconds
    elseif active and phase == "Live" then
        if carrier == side then banner.Text = side == 1 and "← RUN TO YOUR TEAL HOME LINE!" or "RUN TO YOUR CORAL HOME LINE! →"
        elseif carrier > 0 then banner.Text = "CHASE THE CARRIER • GET CLOSE TO TAG!"
        else banner.Text = "BAIT YOUR RIVAL • GRAB THE GOLD RUMAL" end
    elseif ready and phase == "Intermission" then
        banner.Text = "MATCH STARTS IN "..seconds.." • FRIENDS CAN JOIN NOW"
    elseif ready and phase ~= "Lobby" and not isResult then
        banner.Text = side == 0 and "QUEUED FOR THE NEXT MATCH" or "WATCH THE DUEL • YOUR TURN IS COMING"
    else banner.Text = "" end
    result.Visible = isResult and ready and not shopOpen and not helpOpen
    if result.Visible then
        resultTitle.Text = state:GetAttribute("Headline") or "ROUND OVER"
        local winner = state:GetAttribute("Winner") or 0
        resultTitle.TextColor3 = winner == 1 and C.Teal or (winner == 2 and C.Coral or C.Gold)
        if phase == "MatchEnd" then
            resultDetail.Text = "Good game! Another match is your choice.\nReturning to the courtyard menu…"
        else
            resultDetail.Text = winner == 0 and "A clean reset. Try a different move next round." or
                ((winner == side and "YOUR TEAM SCORES!" or "THE OTHER TEAM SCORES").."\nNext duel in "..seconds.."s")
        end
    end
    for _,item in ipairs(Cosmetics) do
        local owned = item.pass and player:GetAttribute("NeonOwned") or player:GetAttribute("Own_"..item.id)
        if player:GetAttribute("Equipped") == item.id then shopButtons[item.id].Text = "EQUIPPED"
        elseif owned then shopButtons[item.id].Text = "EQUIP"
        elseif item.pass then shopButtons[item.id].Text = passPrice and (passPrice.." ROBUX") or "NOT ON SALE"
        else shopButtons[item.id].Text = item.cost.." COINS" end
    end
    viewButton.Text = overview and "VIEW: ARENA" or "VIEW: FOLLOW"
    motionButton.Text = reducedMotion and "FX: LOW" or "FX: ON"
    if player:GetAttribute("SaveWarning") then status.Text = "Save delayed — retrying"
    elseif player:GetAttribute("SavingAvailable") == false then status.Text = "Practice session • saving unavailable"
    elseif player:GetAttribute("SavingAvailable") == nil then status.Text = "Loading progress…"
    else status.Text = "Cosmetics only • no paid advantages" end
    status.Visible = not shopOpen and not helpOpen and not menu.Visible
    toastLabel.Visible = os.clock() < notificationUntil;toastLabel.Text = notification
    local view = camera and camera.ViewportSize or Vector2.new(1280,720)
    local available = math.max(240,view.Y-110)
    for _,panel in ipairs({menu,help,shop}) do
        local scale = panel:FindFirstChildOfClass("UIScale")
        if not scale then scale = Instance.new("UIScale");scale.Parent = panel end
        scale.Scale = math.min(1,available/panel.Size.Y.Offset)
    end
end

notice.OnClientEvent:Connect(function(value) if type(value) == "string" then toast(value) end end)
Marketplace.PromptGamePassPurchaseFinished:Connect(function(buyer,id)
    if buyer == player and id == Config.NeonPassId then purchaseBusy = false end
end)
workspace.DescendantAdded:Connect(function(object)
    if reducedMotion and object:IsA("Trail") then object.Enabled = false end
end)
if Config.NeonPassId > 0 then
    task.spawn(function()
        local ok,info = pcall(function() return Marketplace:GetProductInfo(Config.NeonPassId,Enum.InfoType.GamePass) end)
        if ok and info.IsForSale and info.PriceInRobux then passPrice = info.PriceInRobux end
    end)
end
RunService.RenderStepped:Connect(function(dt)
    camera = workspace.CurrentCamera
    if camera then
        if overview then
            camera.CameraType = Enum.CameraType.Scriptable;camera.FieldOfView = 55
            local view = camera.ViewportSize
            local aspect = math.max(.45,view.X/math.max(1,view.Y))
            local distance = math.max(102,54/(math.tan(math.rad(27.5))*aspect))
            camera.CFrame = CFrame.lookAt(Vector3.new(0,distance*.69,distance*.73),Vector3.zero)
        else
            camera.CameraType = Enum.CameraType.Custom
            local character = player.Character
            local human = character and character:FindFirstChildOfClass("Humanoid")
            if human then camera.CameraSubject = human end
        end
    end
    renderClock += dt
    if renderClock >= .1 then renderClock = 0;update() end
end)
update()
