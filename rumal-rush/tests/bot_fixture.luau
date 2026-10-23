local vectorMeta = {}
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
Vector3.zero = Vector3.new(0,0,0)
function vectorMeta.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vectorMeta.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vectorMeta.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vectorMeta.__index(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then local m=v.Magnitude;return Vector3.new(v.X/m,v.Y/m,v.Z/m) end
end
