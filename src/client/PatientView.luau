--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared.Rig)
local Data = require(Shared.AcupointData)

local function color(hex: string): Color3
 return Color3.fromHex(hex)
end
local palette: {[string]: Color3} = {
 skin = color("F3B980"), cloth = color("238577"), sleeve = color("40B49A"),
 gold = color("F5BC65"), point = color("FF253E"), pointRim = color("FFCFD2"), dark = color("102929"), enamel = color("DCEBE1"),
}
local function block(parent: Instance, name: string, size: Vector3, at: Vector3, tint: Color3): Part
 local part = Instance.new("Part")
 part.Name, part.Size, part.CFrame, part.Color = name, size, CFrame.new(at), tint
 part.Anchored, part.CanCollide, part.CanQuery, part.CastShadow = true, false, false, false
 part.Material = Enum.Material.SmoothPlastic
 part.Parent = parent
 return part
end
type Decoration = {part: Part, base: CFrame, region: string}
export type View = {
 frame: ViewportFrame, camera: Camera, model: WorldModel, pieces: {Decoration},
 rig: {[string]: Part}, marks: {Part}, guard: {Part}, root: CFrame, stage: {Part},
}

local v = Vector3.new
local function build(frame: ViewportFrame): View
 local model = Instance.new("WorldModel")
 model.Parent = frame
 local camera = Instance.new("Camera")
 camera.FieldOfView = 36
 camera.Parent, frame.CurrentCamera = frame, camera
 frame.LightColor, frame.Ambient = color("FFE1B5"), color("8DA9A6")
 frame.LightDirection = v(-0.5,-1,-0.8)
 local pieces: {Decoration} = {}
 local anatomy: {[string]: Part} = {}
 local function detail(name: string, size: Vector3, at: Vector3, tint: Color3, region: string, tilt: number?): Part
  local part = block(model, name, size, at, tint)
  if tilt then part.CFrame *= CFrame.Angles(0, 0, tilt) end
  table.insert(pieces, {part = part, base = part.CFrame, region = region})
  return part
 end
 for _, s in ipairs(Rig.segments) do
  anatomy[s.name] = detail(s.name, s.size, s.at, palette[s.tone], s.region)
 end
 detail("Neck", v(.55,.30,.58), v(0,2.51,.02), palette.skin, "Head")
 detail("Hair", v(1.56,.24,1.13), v(0,4.07,.02), palette.dark, "Head")
 detail("Topknot", v(.45,.27,.44), v(.17,4.31,.13), palette.dark, "Head")
 detail("Side sweep", v(.41,.28,.12), v(-.56,3.89,-.55), palette.dark, "Head", -.15)
 for _, sign in ipairs({-1, 1}) do
  detail("Ear", v(.16,.34,.23), v(sign*.79,3.44,.0), palette.skin, "Head")
  detail("Eye", v(.13,.16,.016), v(sign*.28,3.49,-.555), palette.dark, "Head")
  detail("Brow", v(.23,.045,.016), v(sign*.28,3.65,-.555), palette.dark, "Head", sign*.12)
  detail("Cheek", v(.15,.075,.016), v(sign*.50,3.30,-.555), color("DA8664"), "Head")
 end
 detail("Smile", v(.23,.055,.02), v(0,3.18,-.556), color("945044"), "Head")
 detail("Collar A", v(.66,.10,.035), v(-.31,2.33,-.56), palette.enamel, "Torso", -.58)
 detail("Collar B", v(.65,.10,.035), v(.32,2.33,-.56), palette.enamel, "Torso", .58)
 detail("Belt", v(1.69,.15,1.115), v(0,.68,0), palette.dark, "Torso")
 detail("Badge", v(.19,.19,.026), v(.51,1.90,-.56), palette.gold, "Torso", math.pi/4)
 detail("Back seam", v(.06,1.05,.03), v(0,1.91,.56), color("175149"), "Torso")
 for _, sign in ipairs({-1, 1}) do
  local side = if sign == -1 then "Right" else "Left"
  detail("Sleeve edge", v(.68,.13,.58), v(1.45*sign,1.46,0), palette.gold, side.."Arm")
  detail("Ankle trim", v(.81,.10,.71), v(.74*sign,-1.79,0), palette.dark, side.."Leg")
 end
 local podium = block(model, "Platform", v(.24,6.8,6.8), v(0,-2.59,0), color("21433F"))
 podium.Shape = Enum.PartType.Cylinder
 podium.CFrame *= CFrame.Angles(0,0,math.pi/2)
 local rim = block(model, "Rim", v(.065,6.84,6.84), v(0,-2.50,0), color("6C9D8A"))
 rim.Shape = Enum.PartType.Cylinder
 rim.CFrame *= CFrame.Angles(0,0,math.pi/2)
 local stage = {podium, rim}
 for i = 1, 16 do
  local a = i * math.pi / 8
  local at = v(math.cos(a)*3.05,-2.455,math.sin(a)*3.05)
  table.insert(stage, block(model, "Platform mark", v(.18,.022,.09), at, if i%4 == 0 then palette.gold else color("588778")))
 end
 local guard: {Part} = {}
 for i = 1, 2 do
  local arm = block(model,"Guard arm",v(1.40,.35,.33),v(0,0,0),color("EE8A6C"))
  arm.Transparency = 1
  guard[i] = arm
 end
 return {frame=frame,camera=camera,model=model,pieces=pieces,rig=anatomy,marks={},guard=guard,root=CFrame.identity,stage=stage}
end

local function draw(view: View, p: Rig.Pose, visibleRegion: string?, hovered: string?, lit: boolean, side: string)
 for _, item in ipairs(view.pieces) do
  item.part.CFrame = view.root * item.base
  local crown = item.part.Name == "Hair" or item.part.Name == "Topknot"
  local focus = (not visibleRegion or visibleRegion == item.region) and (side ~= "Top" or not crown)
  item.part.Transparency = if focus then 0 else 1
 end
 for _, info in ipairs(Rig.segments) do
  local part = view.rig[info.name]
  local tint = palette[info.tone]
  part.Color = if hovered == info.region then tint:Lerp(palette.gold,.45)
   elseif lit then tint:Lerp(palette.gold,.32) else tint
 end
 for _, platform in ipairs(view.stage) do
  platform.Transparency = if visibleRegion or side == "Sole" then 1 else 0
 end
 local guard = if not visibleRegion then p.guard else nil
 for i, arm in ipairs(view.guard) do
  arm.Transparency = if guard then 0 else 1
  if guard then
   local center = Rig.center(guard)
   local sign = if i == 1 then -1 else 1
   arm.CFrame = view.root * CFrame.new(center + v(sign*.43, .03, -.73-i*.04)) * CFrame.Angles(0,0,sign*.39)
  end
 end
end

local function setMarkers(view: View, ids: {string})
 for _, part in ipairs(view.marks) do part:Destroy() end
 table.clear(view.marks)
 for _, id in ipairs(ids) do
  local p = Data.byId[id]
  local normal = Rig.normals[Rig.pointView(p)]
  local at = Rig.pointPosition(p) + normal*.085
  local point = block(view.model,p.name,v(.24,.24,.24),at,palette.point)
  point.Shape, point.Material = Enum.PartType.Ball, Enum.Material.Neon
  table.insert(view.marks, point)
  local outline = block(view.model,"Meridian glow",v(.34,.34,.34),at,palette.pointRim)
  outline.Shape, outline.Transparency = Enum.PartType.Ball,.69
  table.insert(view.marks, outline)
 end
end

local function desired(f: ViewportFrame, region: string?, side: string): CFrame
 local w, h = f.AbsoluteSize.X, math.max(f.AbsoluteSize.Y,1)
 local aspect = math.max(w/h,.35)
 local center, height = v(0,.86,0), 7.35
 if region then center, height = Rig.center(region) end
 if side == "Sole" then
  center = v(center.X,-2.08,-.12)
  if region then height = 2.05 end
 elseif side == "Top" then
  center = v(center.X,3.70,0)
  if region then height = 2.30 end
 end
 local normal = Rig.normals[side] or Rig.normals.Front
 local vertical = if normal.Y == 0 then v(0,1,0) else v(0,0,if normal.Y > 0 then 1 else -1)
 local widthFactor = if region == "Torso" then 1.18 else .87
 local distance = height * math.max(1,widthFactor/aspect) / (2*math.tan(math.rad(18)))
 local lift = if region == nil and normal.Y == 0 then v(0,1.0,0) else Vector3.zero
 return CFrame.lookAt(center + normal*distance + lift, center, vertical)
end

local function ray(view: View, screen: Vector2): (Vector3, Vector3)
 local f, c = view.frame, view.camera
 local relative = screen - f.AbsolutePosition
 local w, h = math.max(1,f.AbsoluteSize.X), math.max(1,f.AbsoluteSize.Y)
 local tangent = math.tan(math.rad(c.FieldOfView/2))
 local localDirection = v((2*relative.X/w-1)*(w/h)*tangent,(1-2*relative.Y/h)*tangent,-1)
 return view.root:PointToObjectSpace(c.CFrame.Position), view.root:VectorToObjectSpace(c.CFrame:VectorToWorldSpace(localDirection).Unit)
end

return table.freeze({build=build, draw=draw, setMarkers=setMarkers, desired=desired, ray=ray})
