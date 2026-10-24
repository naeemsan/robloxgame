-- Original procedural creature. No uploaded meshes or third-party models.
local Warden = {}
function Warden.create(parent,anchored)
    local model=Instance.new("Model");model.Name="The Mourner"
    local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(2,2,1)
    root.Transparency=1;root.CanCollide=false;root.Anchored=anchored;root.Parent=model
    model.PrimaryPart=root
    local function piece(name,size,cf,color,shape)
        local p=Instance.new(shape=="Wedge" and "WedgePart" or "Part")
        p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
        p.Material=Enum.Material.SmoothPlastic;p.Anchored=anchored;p.CanCollide=false;p.CanTouch=false
        p.Massless=true
        if shape=="Ball" then p.Shape=Enum.PartType.Ball end
        p.Parent=model
        if not anchored then
            local weld=Instance.new("WeldConstraint");weld.Part0=root;weld.Part1=p;weld.Parent=p
        end
        return p
    end
    local cloth=Color3.fromRGB(24,26,29)
    local skin=Color3.fromRGB(157,154,137)
    piece("Torso",Vector3.new(2.4,3.5,1.2),CFrame.new(0,.1,0)*CFrame.Angles(.12,0,0),cloth)
    for i=-2,2 do
        local strip=piece("TornRobe",Vector3.new(.72,3.2+math.abs(i)*.2,1.4),
            CFrame.new(i*.48,-2,.15)*CFrame.Angles(-.08,0,i*.11),Color3.fromRGB(20+i,22+i,24+i),"Wedge")
        strip.CastShadow=true
    end
    piece("Neck",Vector3.new(.55,1.4,.65),CFrame.new(0,2.05,-.2)*CFrame.Angles(-.2,0,.12),skin)
    local head=piece("Head",Vector3.new(1.55,2.1,1.3),CFrame.new(0,3.12,-.4)*CFrame.Angles(.12,0,-.12),skin,"Ball")
    piece("HairCap",Vector3.new(1.75,1.15,1.5),CFrame.new(0,3.9,-.25),Color3.fromRGB(11,12,14),"Ball")
    for i=-2,2 do
        piece("HangingHair",Vector3.new(.25,3.6,1.2),CFrame.new(i*.39,2.4,.05)*CFrame.Angles(0,0,i*.05),Color3.fromRGB(13,14,16))
    end
    for _,x in ipairs({-.43,.43}) do
        piece("HollowEye",Vector3.new(.52,.48,.17),CFrame.new(x,3.3,-1.03)*CFrame.Angles(.12,0,-.12),Color3.fromRGB(5,5,7),"Ball")
        local eye=piece("EyeEmber",Vector3.new(.09,.09,.06),CFrame.new(x,3.25,-1.13),Color3.fromRGB(242,220,170),"Ball")
        eye.Material=Enum.Material.Neon
    end
    piece("OpenMouth",Vector3.new(.65,.95,.2),CFrame.new(0,2.62,-1.03),Color3.fromRGB(7,6,8),"Ball")
    for i=-2,2 do
        piece("Teeth",Vector3.new(.09,.17,.08),CFrame.new(i*.11,2.96,-1.15),Color3.fromRGB(179,168,136))
    end
    for _,side in ipairs({-1,1}) do
        piece("LongSleeve",Vector3.new(.65,3.4,.7),CFrame.new(side*1.7,-.15,-.3)*CFrame.Angles(-.18,0,side*.18),cloth)
        piece("Forearm",Vector3.new(.38,2.1,.42),CFrame.new(side*2,-2,-.65)*CFrame.Angles(-.1,0,-side*.05),skin)
        for finger=1,4 do
            piece("Finger",Vector3.new(.095,.75,.11),CFrame.new(side*2+(finger-2.5)*.1,-3.25,-.85),skin)
        end
    end
    if not anchored then
        local collider=piece("Collider",Vector3.new(2,4,1.5),CFrame.new(0,-.3,0),cloth)
        collider.Transparency=1;collider.CanCollide=true
        local human=Instance.new("Humanoid");human.Name="Humanoid";human.HipHeight=2.8
        human.RequiresNeck=false;human.BreakJointsOnDeath=false;human.MaxHealth=100000;human.Health=100000
        human.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        human.JumpPower=0;human.AutoRotate=true;human.Parent=model
    end
    model.Parent=parent
    if not anchored then pcall(function() root:SetNetworkOwner(nil) end) end
    return model
end
return Warden
