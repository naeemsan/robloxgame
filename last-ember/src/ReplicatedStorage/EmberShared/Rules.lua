local Rules = {}
function Rules.finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Rules.inHouse(p)
    return Rules.finite(p.x) and Rules.finite(p.y) and Rules.finite(p.z)
        and math.abs(p.x)<=65 and p.z>=-68 and p.z<=53 and p.y>=-4 and p.y<=22
end
function Rules.distance(a,b)
    local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
    return math.sqrt(x*x+y*y+z*z)
end
function Rules.canInteract(phase,status,distance,hold,required)
    return phase=="Playing" and status=="Alive" and Rules.finite(distance)
        and distance<=10 and Rules.finite(hold) and hold>=required-.12
end
function Rules.canPickup(status,held,kind)
    return status=="Alive" and held=="" and (kind=="Fuse" or kind=="Seal")
end
function Rules.deposit(state,held)
    if held=="Fuse" then
        if state.fuses>=state.fusesNeeded then return false,"Generator already powered" end
        state.fuses+=1
        return true,state.fuses==state.fusesNeeded and "POWER RESTORED" or "Fuse installed"
    end
    if held=="Seal" then
        if state.fuses<state.fusesNeeded then return false,"Restore the generator first" end
        if state.burned>=state.sealsNeeded then return false,"All seals are already burned" end
        state.burned+=1
        return true,state.burned==state.sealsNeeded and "THE FRONT GATE IS OPEN" or "Seal destroyed"
    end
    return false,"Your hands are empty"
end
function Rules.stamina(value,sprinting,dt)
    dt=math.clamp(dt,0,.25)
    return math.clamp(value+(sprinting and -22 or 15)*dt,0,100)
end
function Rules.outcome(statuses,remaining)
    local alive,down,escaped=0,0,0
    for _,status in ipairs(statuses) do
        if status=="Alive" then alive+=1 elseif status=="Downed" then down+=1 elseif status=="Escaped" then escaped+=1 end
    end
    if #statuses==0 then return "Abandoned" end
    if alive==0 then return escaped>0 and "Escaped" or "Lost" end
    if remaining<=0 then return escaped>0 and "Escaped" or "Lost" end
    return nil
end
function Rules.canEscape(state,status)
    return status=="Alive" and state.burned>=state.sealsNeeded
end
function Rules.canHide(status,seen,held)
    return status=="Alive" and not seen
end
function Rules.threat(fuses,burned)
    return math.clamp((fuses>0 and .15 or 0)+burned*.14,0,1)
end
function Rules.chooseTarget(candidates)
    local best,score=nil,math.huge
    for _,c in ipairs(candidates) do
        if c.alive and not c.hidden and (c.visible or c.noisy) then
            local s=c.distance-(c.carrying and 5 or 0)
            if s<score then best=c.id;score=s end
        end
    end
    return best
end
function Rules.movement(budget,distance,dt,speed)
    budget=math.min(10,budget+math.max(0,dt)*speed)
    if not Rules.finite(distance) or distance>budget then return false,budget end
    return true,budget-distance
end
return Rules
