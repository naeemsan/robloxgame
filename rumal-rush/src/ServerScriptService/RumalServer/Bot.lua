local Bot = {}
Bot.__index = Bot
local function part(model, name, size, offset, color, ball)
    local p = Instance.new("Part")
    p.Name = name; p.Size = size; p.CFrame = CFrame.new(offset)
    p.Color = color; p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CastShadow = false
    if ball then p.Shape = Enum.PartType.Ball end
    p.Parent = model
    return p
end
function Bot.new(parent, color)
    local self = setmetatable({}, Bot)
    local model = Instance.new("Model")
    model.Name = "Milo • practice rival"
    local root = part(model,"Root",Vector3.new(2,2,1),Vector3.zero,color)
    root.Transparency = 1
    model.PrimaryPart = root
    part(model,"Jersey",Vector3.new(2.5,2.4,1.5),Vector3.new(0,0,0),color)
    part(model,"Head",Vector3.new(1.8,1.8,1.8),Vector3.new(0,2,0),Color3.fromRGB(225,174,129),true)
    part(model,"Hair",Vector3.new(1.9,.65,1.7),Vector3.new(0,2.8,.1),Color3.fromRGB(47,43,52))
    for _,x in ipairs({-0.4,0.4}) do
        part(model,"Eye",Vector3.new(.18,.22,.12),Vector3.new(x,2.1,-.85),Color3.fromRGB(23,35,49))
    end
    for _,x in ipairs({-1.6,1.6}) do
        part(model,"Arm",Vector3.new(.65,2,.8),Vector3.new(x,-.1,0),Color3.fromRGB(225,174,129))
    end
    for _,x in ipairs({-.65,.65}) do
        part(model,"Leg",Vector3.new(.85,1.5,1),Vector3.new(x,-1.9,0),Color3.fromRGB(40,58,76))
        part(model,"Shoe",Vector3.new(.95,.4,1.4),Vector3.new(x,-2.7,-.2),Color3.fromRGB(255,243,214))
    end
    local label = Instance.new("BillboardGui")
    label.Size = UDim2.fromOffset(160,28);label.StudsOffset = Vector3.new(0,4,0)
    label.AlwaysOnTop = true;label.Parent = root
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1,1);text.BackgroundTransparency = 1
    text.Text = "MILO · PRACTICE BOT";text.TextColor3 = Color3.fromRGB(23,35,49)
    text.TextSize = 12;text.Font = Enum.Font.GothamBold;text.Parent = label
    model.Parent = parent
    self.model = model;self.root = root;self.position = Vector3.new(34,3.1,0)
    self.dashReady = 0;self.dashUntil = 0;self.thinkAt = 0
    self:move(self.position, Vector3.new(-1,0,0))
    return self
end
function Bot:move(position, direction)
    self.position = position
    if direction.Magnitude < .01 then direction = Vector3.new(-1,0,0) end
    self.model:PivotTo(CFrame.lookAt(position,position+direction))
end
function Bot:step(dt, now, context)
    local target
    local easy = context.easy
    if context.carrier == context.side then
        target = Vector3.new(context.side == 1 and -37 or 37,3.1,0)
    elseif context.carrier then
        if now - context.pickedAt < (easy and .9 or .45) then return false end
        target = Vector3.new(context.opponent.X,3.1,context.opponent.Z)
    else
        target = Vector3.new(context.scarf.X,3.1,context.scarf.Z)
        -- A brief approach pause makes the pickup readable and allows a bluff.
        if now - context.started < (easy and 1.3 or .6) then return false end
    end
    local delta = target - self.position
    local speed = easy and 16 or 18.5
    if context.carrier and now >= self.dashReady and delta.Magnitude > 10 then
        self.dashUntil = now + .28
        self.dashReady = now + (easy and 7 or 5)
    end
    if now < self.dashUntil then speed = easy and 24 or 28 end
    if delta.Magnitude > .1 then
        local nextPosition = self.position + delta.Unit * math.min(delta.Magnitude, speed*dt)
        nextPosition = Vector3.new(math.clamp(nextPosition.X,-42,42),3.1,math.clamp(nextPosition.Z,-27,27))
        self:move(nextPosition,delta.Unit)
    end
    return not context.carrier and (self.position-context.scarf).Magnitude <= 3.5
end
function Bot:destroy() self.model:Destroy() end
return Bot
