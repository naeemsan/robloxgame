local Pathfinding = game:GetService("PathfindingService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.EmberShared.Config)
local Rules = require(RS.EmberShared.Rules)
local Warden = require(RS.EmberShared.WardenModel)
local Director = {}
Director.__index = Director
function Director.new(parent,context)
    local self=setmetatable({},Director)
    self.context=context;self.model=Warden.create(parent,false)
    self.root=self.model.PrimaryPart;self.human=self.model:FindFirstChildOfClass("Humanoid")
    self.model:PivotTo(CFrame.new(-36,4,-35))
    self.waypoints={};self.index=1;self.pathBusy=false;self.nextPath=0
    self.nextAttack=0;self.started=workspace:GetServerTimeNow();self.lastSeen=0
    self.target=nil;self.lastKnown=nil;self.patrol=1;self.rageUntil=0
    self.previous=self.root.Position;self.stuck=0;self.dead=false
    self.ray=RaycastParams.new();self.ray.FilterType=Enum.RaycastFilterType.Exclude
    return self
end
function Director:visible(character)
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    self.ray.FilterDescendantsInstances={self.model}
    local origin=self.root.Position+Vector3.new(0,1.5,0)
    local hit=workspace:Raycast(origin,root.Position-origin,self.ray)
    return not hit or hit.Instance:IsDescendantOf(character)
end
function Director:rage()
    self.rageUntil=workspace:GetServerTimeNow()+9
    self.nextPath=0
end
function Director:pathTo(goal,time)
    if self.pathBusy or time<self.nextPath then return end
    self.nextPath=time+1.2;self.pathBusy=true
    local start=self.root.Position
    task.spawn(function()
        local path=Pathfinding:CreatePath({AgentRadius=2,AgentHeight=7,AgentCanJump=false,WaypointSpacing=4})
        local ok=pcall(function() path:ComputeAsync(start,goal) end)
        if not self.dead then
            if ok and path.Status==Enum.PathStatus.Success then
                self.waypoints=path:GetWaypoints();self.index=2
            else
                self.waypoints={};self.index=1
            end
            self.pathBusy=false
        end
    end)
end
function Director:step(dt,time)
    if self.dead or not self.root.Parent then return end
    if time-self.started<Config.MonsterGrace then self.human.WalkSpeed=0;return end
    local candidates={}
    local byId={}
    for player,data in pairs(self.context.players()) do
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and data.status=="Alive" then
            local distance=(root.Position-self.root.Position).Magnitude
            local visible=distance<Config.MonsterSight and self:visible(player.Character)
            local noisy=data.sprinting and distance<Config.MonsterHear
            table.insert(candidates,{id=player.UserId,alive=true,hidden=data.hidden,
                distance=distance,visible=visible,noisy=noisy,carrying=data.held=="Seal"})
            byId[player.UserId]=player
        end
    end
    local id=Rules.chooseTarget(candidates)
    if id then
        self.target=byId[id];self.lastSeen=time
        self.lastKnown=self.target.Character.HumanoidRootPart.Position
    elseif self.target and time-self.lastSeen>Config.HuntMemory then
        self.target=nil;self.lastKnown=nil
    end
    local threat=self.context.threat()
    local hunting=self.target~=nil or time<self.rageUntil
    self.human.WalkSpeed=hunting and (Config.MonsterHuntSpeed+threat*Config.MonsterRageBonus) or Config.MonsterWalkSpeed
    self.model:SetAttribute("Hunting",hunting)
    local goal
    if self.target and self.lastKnown then goal=self.lastKnown end
    if not goal then
        local points=self.context.patrol
        goal=points[self.patrol]
        if (self.root.Position-goal).Magnitude<6 then
            self.patrol=self.patrol%#points+1;goal=points[self.patrol]
        end
    end
    if self.target and self.target.Character and self:visible(self.target.Character) then
        self.human:MoveTo(goal)
    else
        self:pathTo(goal,time)
        local waypoint=self.waypoints[self.index]
        if waypoint then
            if (self.root.Position-waypoint.Position).Magnitude<3 then
                self.index+=1;waypoint=self.waypoints[self.index]
            end
            if waypoint then self.human:MoveTo(waypoint.Position) end
        end
    end
    if (self.root.Position-self.previous).Magnitude<.12 then self.stuck+=dt else self.stuck=0 end
    self.previous=self.root.Position
    if self.stuck>3 then self.nextPath=0;self.waypoints={};self.stuck=0 end
    if self.target and time>=self.nextAttack then
        local root=self.target.Character and self.target.Character:FindFirstChild("HumanoidRootPart")
        if root and (root.Position-self.root.Position).Magnitude<Config.MonsterHitRadius and self:visible(self.target.Character) then
            self.nextAttack=time+1.5
            self.context.down(self.target)
        end
    end
end
function Director:destroy()
    self.dead=true
    self.model:Destroy()
end
return Director
