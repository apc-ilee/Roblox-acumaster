--!strict
local Data = require(script.Parent.AcupointData)
local Rig = require(script.Parent.Rig)

local function finite(n: number): boolean
 return n == n and math.abs(n) < math.huge
end

local function validVector(value: any): boolean
 return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
  and value.Magnitude < 12
end

local function validNeedle(position: Vector3, point: Data.Point): boolean
 local target = Rig.byName[point.part]
 local h = target.size / 2
 local p = position - target.at
 local normal = Rig.normals[Rig.pointView(point)]
 if math.abs(p.X) > h.X + 0.02 or math.abs(p.Y) > h.Y + 0.02 or math.abs(p.Z) > h.Z + 0.02 then
  return false
 end
 local depth = if normal.Y ~= 0 then h.Y else h.Z
 if math.abs(p:Dot(normal) - depth) > 0.035 then return false end
 local distance = (position - Rig.pointPosition(point)).Magnitude
 if distance > point.radius then return false end
 -- Nearby point centers remain distinct even when their tolerance circles overlap.
 for _, other in ipairs(Data.points) do
  if other ~= point and other.part == point.part and other.view == point.view
   and (position - Rig.pointPosition(other)).Magnitude + 0.005 < distance then return false end
 end
 return true
end

return table.freeze({finite = finite, validVector = validVector, validNeedle = validNeedle})
