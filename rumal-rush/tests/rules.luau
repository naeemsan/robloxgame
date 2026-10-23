local Rules = require("../src/ReplicatedStorage/RumalShared/Rules")
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error("FAIL: "..name.."\n"..tostring(err)) end
    count += 1
    print("PASS",name)
end
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function p(x,z,y) return {x=x,y=y or 3,z=z or 0} end
local function scenario(overrides)
    local a = {phase="Live",carrier=1,pickedAt=0,now=2,grace=.8,
        positions={p(-10),p(10)},homeX=34,tagRadius=4,remaining=15}
    for k,v in pairs(overrides or {}) do a[k]=v end
    return a
end
test("finite rejects NaN and infinity",function()
    eq(Rules.finite(0/0),false);eq(Rules.finite(math.huge),false)
    eq(Rules.finite("12"),false);eq(Rules.finite(12),true)
end)
test("court boundaries include edges",function()
    eq(Rules.validPosition(p(44,29),44,29),true)
    eq(Rules.validPosition(p(-44,-29),44,29),true)
end)
test("reject teleport outside court or under floor",function()
    eq(Rules.validPosition(p(45),44,29),false)
    eq(Rules.validPosition(p(0,30),44,29),false)
    eq(Rules.validPosition(p(0,0,-1),44,29),false)
    eq(Rules.validPosition(p(0,0,15),44,29),false)
    eq(Rules.validPosition(p(0/0),44,29),false)
end)
test("only live nearby pickup succeeds",function()
    eq(Rules.canGrab("Live",false,p(5),p(0),5.5),true)
    eq(Rules.canGrab("Countdown",false,p(0),p(0),5.5),false)
    eq(Rules.canGrab("Result",false,p(0),p(0),5.5),false)
    eq(Rules.canGrab("Live",false,p(6),p(0),5.5),false)
end)
test("second pickup rejected",function()
    eq(Rules.canGrab("Live",true,p(0),p(0),5.5),false)
end)
test("dash cooldown and phase",function()
    eq(Rules.canDash("Live",10,10),true)
    eq(Rules.canDash("Live",9.9,10),false)
    eq(Rules.canDash("Lobby",10,0),false)
    eq(Rules.canDash("Live",0/0,0),false)
end)
test("no tag before pickup",function()
    local a=scenario();a.carrier=nil;a.positions={p(0),p(0)}
    eq(Rules.resolve(a),nil)
end)
test("no score during countdown or result",function()
    eq(Rules.resolve(scenario({phase="Countdown",positions={p(-40),p(40)}})),nil)
    eq(Rules.resolve(scenario({phase="Result",remaining=0})),nil)
end)
test("teal carrier reaches teal line",function()
    local r=Rules.resolve(scenario({positions={p(-34),p(0)}}))
    eq(r.winner,1);eq(r.reason,"HOME SAFE!")
end)
test("coral carrier reaches coral line",function()
    eq(Rules.resolve(scenario({carrier=2,positions={p(0),p(34)}})).winner,2)
end)
test("opponent home line never scores",function()
    eq(Rules.resolve(scenario({positions={p(34),p(0)}})),nil)
    eq(Rules.resolve(scenario({carrier=2,positions={p(0),p(-34)}})),nil)
end)
test("tag scores defender after grace",function()
    local r=Rules.resolve(scenario({positions={p(0),p(3.9)}}))
    eq(r.winner,2);eq(r.reason,"TAGGED!")
end)
test("pickup grace prevents instant tag",function()
    eq(Rules.resolve(scenario({now=.79,positions={p(0),p(0)}})),nil)
    eq(Rules.resolve(scenario({now=.8,positions={p(0),p(0)}})).winner,2)
end)
test("tag wins exact home-line tie",function()
    eq(Rules.resolve(scenario({positions={p(-34),p(-33)}})).winner,2)
end)
test("three dimensional distance used",function()
    eq(Rules.resolve(scenario({positions={p(0,0,3),p(0,0,8)}})),nil)
end)
test("timeout awards defense when carried",function()
    eq(Rules.resolve(scenario({remaining=0})).winner,2)
    eq(Rules.resolve(scenario({carrier=2,remaining=-1})).winner,1)
end)
test("unclaimed scarf timeout is a draw",function()
    local a=scenario({remaining=0});a.carrier=nil
    eq(Rules.resolve(a).winner,0)
end)
test("first to three ends match",function()
    eq(Rules.matchWinner(3,2,5,3,9),1)
    eq(Rules.matchWinner(1,3,4,3,9),2)
    eq(Rules.matchWinner(2,2,8,3,9),nil)
end)
test("round cap ends ties and stalled matches",function()
    eq(Rules.matchWinner(2,2,9,3,9),0)
    eq(Rules.matchWinner(2,1,9,3,9),1)
    eq(Rules.matchWinner(0,2,9,3,9),2)
end)
test("cosmetic spends once then equips for free",function()
    local d={coins=100,owned={Classic=true},equipped="Classic"}
    local item={id="Mint",cost=80}
    eq(Rules.buy(d,item),true);eq(d.coins,20);eq(d.owned.Mint,true)
    eq(Rules.buy(d,item),true);eq(d.coins,20);eq(d.equipped,"Mint")
end)
test("insufficient coins cannot create ownership",function()
    local d={coins=79,owned={}}
    eq(Rules.buy(d,{id="Mint",cost=80}),false);eq(d.coins,79);eq(d.owned.Mint,nil)
end)
test("paid cosmetic cannot be bought with forged coin price",function()
    local d={coins=1000,owned={}}
    eq(Rules.buy(d,{id="Neon",pass=true,cost=0}),false);eq(d.owned.Neon,nil)
    eq(Rules.buy(d,{id="Oops",cost=-100}),false)
    eq(Rules.buy(d,{id="Oops",cost=0/0}),false)
end)
test("movement budget allows normal walk",function()
    local budget=9
    for _=1,100 do
        local ok;ok,budget=Rules.movementBudget(budget,.95,.05,23)
        eq(ok,true)
    end
end)
test("movement budget rejects teleport",function()
    eq(Rules.movementBudget(9,35,.05,23),false)
    eq(Rules.movementBudget(9,math.huge,.05,23),false)
end)
test("movement budget catches sustained overspeed",function()
    local budget=9
    local rejected=false
    for _=1,100 do
        local ok;ok,budget=Rules.movementBudget(budget,2,.05,23)
        if not ok then rejected=true;break end
    end
    eq(rejected,true)
end)
test("bounded replication burst is tolerated",function()
    local ok,budget=Rules.movementBudget(9,7,.05,23)
    eq(ok,true)
    for _=1,20 do ok,budget=Rules.movementBudget(budget,.6,.05,23);eq(ok,true) end
end)
test("complete escape match simulation",function()
    local scores={0,0}
    for round=1,3 do
        local x=0
        local outcome
        for tick=1,100 do
            x-=.95
            outcome=Rules.resolve(scenario({now=1+tick*.05,positions={p(x),p(15)},remaining=30-tick*.05}))
            if outcome then break end
        end
        assert(outcome);scores[outcome.winner]+=1
        eq(Rules.matchWinner(scores[1],scores[2],round,3,9),round==3 and 1 or nil)
    end
    eq(scores[1],3)
end)
print(string.format("RESULT: %d rule tests passed",count))
