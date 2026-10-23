-- Pure rules: no Roblox services. Executed by the offline regression suite.
local Rules = {}

function Rules.finite(n)
    return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Rules.validPosition(p, boundsX, boundsZ)
    return type(p) == "table" and Rules.finite(p.x) and Rules.finite(p.y)
        and Rules.finite(p.z) and math.abs(p.x) <= boundsX
        and math.abs(p.z) <= boundsZ and p.y >= 0 and p.y <= 14
end

function Rules.distance(a, b)
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(x*x + y*y + z*z)
end

function Rules.canGrab(phase, hasCarrier, position, scarf, radius)
    return phase == "Live" and not hasCarrier and Rules.distance(position, scarf) <= radius
end

function Rules.canDash(phase, now, readyAt)
    return phase == "Live" and Rules.finite(now) and now >= readyAt
end

function Rules.resolve(args)
    if args.phase ~= "Live" then return nil end
    local c = args.carrier
    if c then
        local grace = args.now - args.pickedAt >= args.grace
        -- A tag on the line wins the tie; a player must cross safely.
        if grace and Rules.distance(args.positions[c], args.positions[3-c]) <= args.tagRadius then
            return { winner = 3-c, reason = "TAGGED!" }
        end
        local x = args.positions[c].x
        if (c == 1 and x <= -args.homeX) or (c == 2 and x >= args.homeX) then
            return { winner = c, reason = "HOME SAFE!" }
        end
    end
    if args.remaining <= 0 then
        return { winner = c and (3-c) or 0, reason = c and "TIME UP — DEFENSE WINS" or "NO PICKUP — DRAW" }
    end
    return nil
end

function Rules.matchWinner(a, b, rounds, target, limit)
    if a >= target then return 1 end
    if b >= target then return 2 end
    if rounds >= limit then
        if a == b then return 0 end
        return a > b and 1 or 2
    end
    return nil
end

function Rules.buy(profile, item)
    if not item or item.pass or not Rules.finite(item.cost) or item.cost < 0 then return false, "Unavailable" end
    if profile.owned[item.id] then
        profile.equipped = item.id
        return true, "Equipped"
    end
    if profile.coins < item.cost then return false, "Not enough coins" end
    profile.coins -= item.cost
    profile.owned[item.id] = true
    profile.equipped = item.id
    return true, "Unlocked and equipped"
end

function Rules.movementBudget(budget, distance, elapsed, maxSpeed)
    local replenished = math.min(9, budget + maxSpeed * math.max(0, elapsed))
    if not Rules.finite(distance) or distance > replenished then return false, replenished end
    return true, replenished - distance
end

return Rules
