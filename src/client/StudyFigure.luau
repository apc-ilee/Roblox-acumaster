--!strict
local v = Vector3.new
local skin = Color3.fromHex("DFA781")
local warm = Color3.fromHex("C68A6A")
local light = Color3.fromHex("EAB997")
local fabric = Color3.fromHex("315A62")
local trim = Color3.fromHex("44777A")
local hair = Color3.fromHex("343139")
local eye = Color3.fromHex("302C34")

type Surface = {frame: CFrame, half: Vector3}
export type Figure = {model: Model, surfaces: {Surface}}

local function build(): Figure
 local model = Instance.new("Model")
 model.Name = "Human study figure"
 local figure: Figure = {model = model, surfaces = {}}
 local function shape(name: string, size: Vector3, at: Vector3, tint: Color3, roll: number?, feature: boolean?): Part
  local part = Instance.new("Part")
  part.Name, part.Size = name, Vector3.one
  part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, roll or 0)
  part.Color, part.Material = tint, Enum.Material.SmoothPlastic
  part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
  part.CastShadow = false
  local mesh = Instance.new("SpecialMesh")
  mesh.MeshType, mesh.Scale, mesh.Parent = Enum.MeshType.Sphere, size, part
  part.Parent = model
  if not feature then table.insert(figure.surfaces, {frame = part.CFrame, half = size / 2}) end
  return part
 end

 shape("Neck",v(.69,.85,.70),v(0,2.66,.08),warm)
 shape("Head",v(1.30,1.42,1.17),v(0,3.52,.025),skin)
 shape("Jaw",v(1.05,.87,.94),v(0,3.17,-.095),skin)
 shape("Hair",v(1.32,.69,1.19),v(0,3.94,.11),hair)
 shape("Hairline",v(1.17,.24,.24),v(-.04,3.89,-.38),hair,-.13)
 shape("Nose",v(.21,.39,.24),v(0,3.40,-.53),light)
 shape("Lips",v(.32,.057,.075),v(0,3.15,-.540),Color3.fromHex("915052"),nil,true)
 shape("Chin",v(.51,.28,.28),v(0,3.04,-.41),light)

 shape("Ribcage",v(2.12,1.44,1.11),v(0,1.91,.025),fabric)
 shape("Waist",v(1.63,1.27,.97),v(0,1.12,.025),fabric)
 shape("Hips",v(1.78,.85,1.05),v(0,.59,.04),fabric)
 shape("Collar trim",v(.80,.22,.55),v(0,2.45,-.13),trim,nil,true)
 shape("Waist seam",v(1.57,.14,1.00),v(0,.87,.04),trim,nil,true)
 shape("Back seam",v(.082,1.72,.07),v(0,1.64,.52),trim,nil,true)

 for _, sign in ipairs({-1, 1}) do
  local side = if sign < 0 then "Right " else "Left "
  local function limb(name: string, size: Vector3, x: number, y: number, z: number, tint: Color3, roll: number?)
   shape(side..name,size,v(x*sign,y,z),tint,if roll then roll*sign else nil)
  end

  limb("ear",v(.24,.42,.24),.65,3.47,.02,skin,-.20)
  shape(side.."ear detail",v(.068,.23,.105),v(.71*sign,3.47,-.08),warm,sign*-.20,true)
  shape(side.."eyelid",v(.30,.13,.13),v(.265*sign,3.49,-.474),warm,sign*.08,true)
  shape(side.."eye",v(.235,.082,.12),v(.266*sign,3.50,-.498),Color3.fromHex("EEE1D0"),sign*.08,true)
  shape(side.."iris",v(.09,.09,.053),v(.26*sign,3.50,-.555),eye,nil,true)
  shape(side.."brow",v(.29,.063,.11),v(.26*sign,3.66,-.499),hair,sign*-.09,true)

  limb("shoulder",v(.79,.79,.84),1.03,2.18,.035,fabric,.23)
  limb("upper arm",v(.68,1.31,.65),1.40,1.92,.015,skin,.30)
  limb("elbow",v(.78,.60,.55),1.51,1.45,.018,skin,.27)
  limb("forearm",v(.62,1.21,.57),1.69,.99,.005,skin,.19)
  limb("wrist",v(.37,.46,.35),1.76,.49,-.02,warm,.08)
  limb("palm",v(.51,.56,.34),1.79,.23,-.025,skin,.10)
  limb("thumb",v(.23,.44,.28),2.025,.22,-.047,skin,.47)
  for finger = 0, 3 do
   limb("finger "..tostring(finger+1),v(.115,.30+((2-math.abs(finger-1))*.055),.19),1.605+finger*.115,-.018,-.036,skin,.09)
  end

  limb("thigh",v(.91,1.43,.86),.55,.10,.04,fabric,.145)
  limb("knee",v(.76,.64,.70),.69,-.78,-.035,skin,.02)
  limb("kneecap",v(.49,.39,.35),.68,-.84,-.174,light,.06)
  limb("calf",v(.79,1.29,.78),.72,-1.23,.065,skin,.018)
  limb("shin",v(.59,1.15,.54),.73,-1.33,-.08,skin,.07)
  limb("ankle",v(.41,.52,.44),.77,-1.84,.00,warm,.03)
  limb("heel",v(.48,.42,.56),.78,-2.03,.105,skin)
  limb("foot",v(.63,.39,.98),.78,-2.10,-.13,skin)
  for toe = 0, 4 do
   limb("toe "..tostring(toe+1),v(.155-toe*.013,.20,.29-toe*.022),.54+toe*.113,-2.14,-.57+toe*.035,skin)
  end
 end
 return figure
end

-- Keep the training coordinates parallel to the aiming surface, but sit the
-- red marker on the curved figure instead of leaving it at the box face.
local function surfaceAt(figure: Figure, point: Vector3, normal: Vector3): Vector3?
 local origin = point + normal * 2
 local best = math.huge
 for _, surface in ipairs(figure.surfaces) do
  local o = surface.frame:PointToObjectSpace(origin) / surface.half
  local d = surface.frame:VectorToObjectSpace(-normal) / surface.half
  local a, b, c = d:Dot(d), o:Dot(d), o:Dot(o)-1
  local discriminant = b*b - a*c
  if discriminant >= 0 then
   local distance = (-b - math.sqrt(discriminant)) / a
   -- Ignore unrelated body surfaces across the figure.
   if distance >= 0 and math.abs(distance-2) <= .62 then
    best = math.min(distance,best)
   end
  end
 end
 return if best < math.huge then origin-normal*best else nil
end

return table.freeze({build=build,surfaceAt=surfaceAt})
