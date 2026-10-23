local count=0
local function test(name,fn)
    local ok,err=pcall(fn);if not ok then error("FAIL: "..name.."\n"..tostring(err)) end
    count+=1;print("PASS",name)
end
local function botAt(x,z)
    local b=setmetatable({position=Vector3.new(x,3.1,z or 0),dashReady=0,dashUntil=0},{__index=Bot})
    function b:move(pos) self.position=pos end
    return b
end
local function context(changes)
    local c={side=2,opponent=Vector3.new(-10,3.1,0),scarf=Vector3.new(0,3.1,0),
        started=0,pickedAt=0,easy=true}
    for k,v in pairs(changes or {}) do c[k]=v end
    return c
end
test("easy bot pauses before approaching",function()
    local b=botAt(36);b:step(.1,.5,context());assert(b.position.X==36)
end)
test("bot approaches scarf and requests nearby pickup",function()
    local b=botAt(36);local wants
    for i=1,50 do wants=b:step(.05,2+i*.05,context());if wants then break end end
    assert(wants);assert(b.position.X<4)
end)
test("carrier bot returns to correct home line",function()
    local b=botAt(0)
    for i=1,100 do b:step(.05,2+i*.05,context({carrier=2}));if b.position.X>=34 then break end end
    assert(b.position.X>=34)
    local a=botAt(0)
    for i=1,100 do a:step(.05,2+i*.05,context({carrier=1,side=1}));if a.position.X<=-34 then break end end
    assert(a.position.X<=-34)
end)
test("defender bot reacts after its response delay",function()
    local b=botAt(10)
    b:step(.1,.3,context({carrier=1}));assert(b.position.X==10)
    b:step(.1,2,context({carrier=1}));assert(b.position.X<10)
end)
test("standard approach is faster than easy",function()
    local a,b=botAt(36),botAt(36)
    a:step(.1,2,context());b:step(.1,2,context({easy=false}))
    assert(b.position.X<a.position.X)
end)
test("bot dash has a cooldown",function()
    local b=botAt(0);b:step(.1,2,context({carrier=2}))
    local ready=b.dashReady;assert(ready>2)
    b:step(.1,2.1,context({carrier=2}));assert(b.dashReady==ready)
end)
test("bot stays within playable court",function()
    local b=botAt(40,26)
    for i=1,100 do b:step(.1,2+i*.1,context({carrier=1,opponent=Vector3.new(200,3.1,200)})) end
    assert(b.position.X<=42 and b.position.Z<=27)
end)
print(string.format("RESULT: %d bot decision tests passed (vector fixture, not Roblox physics)",count))
