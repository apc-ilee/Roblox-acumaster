--!strict
local Data = require(script.Parent.AcupointData)

export type Segment = {name: string, region: string, at: Vector3, size: Vector3, tone: string}
export type Pose = {offset: Vector3, twist: number, guard: string?}

local segments: {Segment} = {}
local byName: {[string]: Segment} = {}
local function segment(name: string, region: string, at: Vector3, size: Vector3, tone: string)
 local item = table.freeze({name = name, region = region, at = at, size = size, tone = tone})
 table.insert(segments, item)
 byName[name] = item
end
local v = Vector3.new
segment("Head", "Head", v(0, 3.42, 0), v(1.50, 1.70, 1.10), "skin")
segment("UpperTorso", "Torso", v(0, 1.97, 0), v(2.05, 1.12, 1.10), "cloth")
segment("LowerTorso", "Torso", v(0, 0.96, 0), v(1.68, 0.98, 1.10), "cloth")
for _, side in ipairs({"Right", "Left"}) do
 local x = if side == "Right" then -1 else 1
 segment(side.."UpperArm", side.."Arm", v(1.45*x, 1.96, 0), v(0.67, 1.1, 0.56), "sleeve")
 segment(side.."LowerArm", side.."Arm", v(1.69*x, 0.94, 0), v(0.59, 1.02, 0.50), "skin")
 segment(side.."Hand", side.."Arm", v(1.80*x, 0.16, 0), v(0.65, 0.58, 0.36), "skin")
 segment(side.."UpperLeg", side.."Leg", v(0.61*x, -0.16, 0), v(0.93, 1.20, 0.77), "cloth")
 segment(side.."LowerLeg", side.."Leg", v(0.74*x, -1.29, 0), v(0.81, 1.12, 0.70), "sleeve")
 segment(side.."Foot", side.."Leg", v(0.80*x, -2.08, -0.12), v(0.88, 0.50, 1.03), "skin")
end

local normals: {[string]: Vector3} = {
 Front = v(0, 0, -1), Back = v(0, 0, 1), Top = v(0, 1, 0), Sole = v(0, -1, 0),
}
local guards = {"Torso", "Head", "LeftLeg", "Torso", "RightLeg", "Head"}
local function pose(dynamic: boolean, elapsed: number, round: number): Pose
 if not dynamic then return {offset = Vector3.zero, twist = 0} end
 local t = math.max(0, elapsed)
 local slot = math.floor(t / 2.15)
 local guard = if t % 2.15 >= 1.15 then guards[(slot + round) % #guards + 1] else nil
 return {offset = v(math.sin(t * 4.5) * 0.47, math.sin(t * 7) * 0.12, 0), twist = math.sin(t * 4.5) * 0.16, guard = guard}
end

local function root(p: Pose): CFrame
 return CFrame.new(p.offset) * CFrame.Angles(0, 0, p.twist)
end

local function center(region: string): (Vector3, number)
 if region == "Head" then return v(0, 3.42, 0), 1.95 end
 if region == "Torso" then return v(0, 1.48, 0), 2.35 end
 local sign = if string.sub(region, 1, 4) == "Left" then 1 else -1
 if string.find(region, "Arm") then return v(1.65*sign, 1.28, 0), 2.8 end
 return v(0.73*sign, -1.02, 0), 2.95
end

local function pointPosition(point: Data.Point): Vector3
 local part = byName[point.part]
 local half = part.size / 2
 local o = point.offset
 local x, y = math.clamp(o.X, -half.X + 0.025, half.X - 0.025), math.clamp(o.Y, -half.Y + 0.025, half.Y - 0.025)
 if point.view == "Bottom" or point.view == "Top" then
  return part.at + v(x, if point.view == "Top" then half.Y else -half.Y, math.clamp(o.Z, -half.Z + 0.025, half.Z - 0.025))
 end
 return part.at + v(x, y, if point.view == "Back" then half.Z else -half.Z)
end

local function pointView(point: Data.Point): string
 return if point.view == "Bottom" then "Sole" else point.view
end

-- Intersect the same canonical boxes used for rendering and server validation.
local function rayBox(origin: Vector3, dir: Vector3, part: Segment): number?
 local p = origin - part.at
 local half = part.size / 2
 local enter, exit = 0, 100
 local function slab(value: number, speed: number, extent: number): boolean
  if math.abs(speed) < 1e-6 then return math.abs(value) <= extent end
  local a, b = (-extent-value)/speed, (extent-value)/speed
  enter, exit = math.max(enter, math.min(a,b)), math.min(exit, math.max(a,b))
  return enter <= exit
 end
 if slab(p.X, dir.X, half.X) and slab(p.Y, dir.Y, half.Y) and slab(p.Z, dir.Z, half.Z) then return enter end
 return nil
end

local function trace(origin: Vector3, dir: Vector3, region: string?): (Segment?, Vector3?)
 local closest, hit = math.huge, nil :: Segment?
 for _, part in ipairs(segments) do
  if not region or part.region == region then
   local distance = rayBox(origin, dir, part)
   if distance and distance < closest then
    closest, hit = distance, part
   end
  end
 end
 return hit, if hit then origin + dir * closest else nil
end

local function segmentAt(position: Vector3, region: string?, slack: number): Segment?
 for _, part in ipairs(segments) do
  if not region or part.region == region then
   local d, h = position - part.at, part.size / 2
   if math.abs(d.X) <= h.X + slack and math.abs(d.Y) <= h.Y + slack and math.abs(d.Z) <= h.Z + slack then
    return part
   end
  end
 end
 return nil
end

return table.freeze({
 segments = table.freeze(segments), byName = table.freeze(byName), normals = table.freeze(normals),
 pose = pose, root = root, center = center, pointPosition = pointPosition, pointView = pointView,
 trace = trace, segmentAt = segmentAt,
})
