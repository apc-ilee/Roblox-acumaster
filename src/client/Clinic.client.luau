--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared.AcupointData)
local Rig = require(Shared.Rig)
local HitRules = require(Shared.HitRules)
local Protocol = require(Shared.Protocol)
local ClinicUI = require(script.Parent.ClinicUI)
local PatientView = require(script.Parent.PatientView)

type Snapshot = Protocol.Snapshot
local player = Players.LocalPlayer
local ui = ClinicUI.build(player:WaitForChild("PlayerGui") :: PlayerGui)
local view = PatientView.build(ui.viewport)
local T = ClinicUI.theme
local wire = ReplicatedStorage:WaitForChild(Protocol.folder)
local receiver = wire:WaitForChild("Snapshot") :: RemoteEvent
local get = wire:WaitForChild("GetSnapshot") :: RemoteFunction
local macroRemote = wire:WaitForChild("SelectRegion") :: RemoteEvent
local needleRemote = wire:WaitForChild("PlaceNeedle") :: RemoteEvent
local backRemote = wire:WaitForChild("Back") :: RemoteEvent
local queueRemote = wire:WaitForChild("Queue") :: RemoteEvent
local cheerRemote = wire:WaitForChild("Cheer") :: RemoteEvent

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health,false) end)
pcall(function() StarterGui:SetCore("TopbarEnabled",false) end)
pcall(function() GuiService.TouchControlsEnabled = false end)

local sound = Instance.new("Sound")
sound.SoundId, sound.Volume, sound.Parent = "rbxasset://sounds/electronicpingshort.wav", .36, SoundService
local function chime(rate: number)
 sound.PlaybackSpeed = rate
 sound:Play()
end

local server: Snapshot = {
 revision = -1, phase = "Lobby", deadline = 0, roundStart = 0, round = 0, roundId = "",
 active = false, dynamic = false, overtime = false, pool = {}, clues = {}, reveal = {},
 step = 1, status = "Watching", lockUntil = 0, rows = {}, message = "",
}
local state = server
local practice: Snapshot? = nil
local lesson = {"03_YinTang","09_WaiGuan","20_YongQuan","02_BaiHui"}
local lessonIndex = 1
local selected = 1
local side = "Front"
local views = {"Front","Back","Top","Sole"}
local reduceMotion, compact, hasButtons = false, false, false
local cursor: Vector2? = nil
local touch: InputObject? = nil
local touchStart: Vector2? = nil
local orientationDrag: Vector2? = nil
local stick = Vector2.zero
local resultAt, pendingUntil, cameraAt, noAimUntil = 0, 0, 0, 0
local warningBeat = -1
local pendingPosition: Vector3? = nil
local cameraFrom: CFrame? = nil
local resize: Vector2? = nil
local hitVisual: Vector3? = nil
local didPlace = false
local cachedList = ""
local recapRoster = false

local function clock(): number return Workspace:GetServerTimeNow() end
local function active(): boolean
 return state.phase == "Action" and state.active and (state.status == "Checking" or state.status == "Aiming")
end
local function turn(to: string, animate: boolean?)
 side = to
 cursor = nil
 cameraFrom = if animate and not reduceMotion then view.camera.CFrame else nil
 cameraAt = clock()
end
local function orbit(by: number)
 local index = table.find(views,side) or 1
 turn(views[(index-1+by)%#views+1],true)
end

local phaseLabels = {Lobby="CLINIC LOBBY",Intermission="GET READY",Memory="STUDY PHASE",Action="DIAGNOSE",Recap="ROUND RECAP",Victory="CLINIC CLOSED"}
local regionLabels: {[string]: string} = {Head="Head",Torso="Torso",LeftArm="Left arm",RightArm="Right arm",LeftLeg="Left leg",RightLeg="Right leg"}
local function goPoint(id: string)
 local point = Data.byId[id]
 if point then turn(Rig.pointView(point),true) end
end

local function updateList(ids: {string}?, showRoster: boolean, canCheer: boolean)
 local fragments: {string} = {state.phase,tostring(selected),tostring(state.practice),tostring(showRoster),tostring(canCheer)}
 if ids then
  for _, id in ipairs(ids) do table.insert(fragments,id) end
 end
 if showRoster then
  for _, row in ipairs(state.rows) do
   table.insert(fragments,string.format("%d,%d,%d,%s,%s,%d",row.id,row.qi,row.delta,tostring(row.alive),tostring(row.ready),row.cheers))
  end
 end
 local key = table.concat(fragments,"|")
 if key == cachedList then return end
 cachedList = key
 local scroll = ui.list.CanvasPosition
 for _, item in ipairs(ui.list:GetChildren()) do
  if item:IsA("GuiObject") then item:Destroy() end
 end
 ui.list.CanvasPosition = scroll
 if ids then
  for i, id in ipairs(ids) do
   local point = Data.byId[id]
   local row = ClinicUI.button(ui.list,"",0,0,0,43,i == selected)
   row.Size, row.LayoutOrder = UDim2.new(1,-7,0,43),i
   local tint = if i == selected then T.bg else T.cream
   local subTint = if i == selected then T.goldDark else T.muted
   ClinicUI.label(row,point.cn.."  "..point.name,10,2,226,19,13,tint,ClinicUI.bold)
   ClinicUI.label(row,point.location.."  /  "..string.upper(Rig.pointView(point)),10,20,238,19,11,subTint)
   local tag = ClinicUI.label(row,point.clue,0,0,137,43,11,tint)
   tag.Position,tag.AnchorPoint = UDim2.new(1,-9,0,0),Vector2.new(1,0)
   tag.TextXAlignment = Enum.TextXAlignment.Right
   row.Activated:Connect(function()
    selected = i
    goPoint(id)
    updateList(ids,false,false)
   end)
  end
 elseif showRoster then
  for i, row in ipairs(state.rows) do
   local item = ClinicUI.panel(ui.list,0,0,0,34,T.button,6)
   item.Size,item.LayoutOrder = UDim2.new(1,-7,0,34),i
   ClinicUI.label(item,row.name..(if row.id == player.UserId then "  (you)" else ""),9,0,186,34,13,T.cream)
   local mark = if state.phase == "Lobby" or state.phase == "Intermission" then (if row.ready then "QUEUED" else "OUT")
    elseif not row.alive then "OUT"
    else string.format("%d QI",row.qi)
   if state.phase == "Recap" and row.delta ~= 0 then mark ..= string.format("  %+.0f",row.delta) end
   if row.cheers > 0 and not canCheer then mark ..= string.format("  ♥%d",row.cheers) end
   local text = ClinicUI.label(item,mark,0,0,128,34,12,if row.delta < 0 then T.red elseif row.alive then T.mint else T.faint,ClinicUI.mono)
   text.TextXAlignment,text.AnchorPoint,text.Position = Enum.TextXAlignment.Right,Vector2.new(1,0),UDim2.new(1,if canCheer and row.alive then -75 else -9,0,0)
   if canCheer and row.alive then
    local cheerButton = ClinicUI.button(item,string.format("♥ %d",row.cheers),0,4,61,26)
    cheerButton.AnchorPoint,cheerButton.Position,cheerButton.TextSize = Vector2.new(1,0),UDim2.new(1,-5,0,4),12
    cheerButton.Activated:Connect(function() cheerRemote:FireServer(row.id) end)
   end
  end
 end
end

local function inQueue(): boolean
 for _, row in ipairs(server.rows) do
  if row.id == player.UserId then return row.ready end
 end
 return true
end

local function renderText()
 local s = state
 local phase = s.phase
 local heading, description, caption = "", "", "CASE NOTES"
 local ids: {string}? = nil
 local showRoster = false
 local main, alt = "", ""
 ui.phase.Text = if s.practice then "SOLO PRACTICE" elseif phase == "Action" and s.overtime then "SUDDEN DEATH" else (phaseLabels[phase] or "")
 ui.detail.Text = if s.practice then string.format("LESSON  %02d / %02d",lessonIndex,#lesson)
  elseif phase == "Lobby" then "2–12 PLAYERS"
  elseif s.round > 0 then string.format("ROUND  %02d",s.round)
  else "MATCH QUEUE"
 ui.sceneTitle.Text = if phase == "Action" and s.region then "PRECISION VIEW"
  elseif phase == "Memory" or phase == "Recap" then "MERIDIAN ATLAS" else "PATIENT VIEW"
 if phase == "Lobby" or phase == "Intermission" then
  heading, caption, showRoster = "The clinic is open", "MATCH QUEUE", true
  description = if phase == "Lobby" then "A match starts when two players queue. Start a solo lesson while you wait."
   else "The match is about to start. Study the marked points first, then diagnose by clue."
  main, alt = "Solo practice", if inQueue() then "Leave queue" else "Join queue"
 elseif phase == "Memory" then
  heading, caption = if s.practice then "Study the marker" else "Memorize the points", "MERIDIAN STUDY"
  description = if s.practice then "Match the highlighted point to its clue. Rotate the mannequin to see the location."
   else "Pick a card to show its side of the mannequin. You’ll use these clues during the round."
  ids = s.pool
  if s.practice then main, alt = "Start placement", "Exit lesson" end
 elseif phase == "Action" then
  local count = #s.clues
  caption = if count > 1 then string.format("CASE NOTES   /   POINT %d OF %d", s.step, count) else "PATIENT REPORT"
  if not s.active then
   heading, description = "Spectating", "Follow the live case and cheer for a practitioner. The next match starts after the ceremony."
   showRoster = true
  else
   heading = if s.status == "Placed" then "Placement confirmed" elseif s.status == "Missed" then "Off target"
    elseif s.region then "Place the needle" else "Find the region"
   description = s.clues[s.step] or ""
   if s.practice then
    local point = Data.byId[lesson[lessonIndex]]
    description = point.cn.." · "..point.name.."  /  "..point.location.."\n"..description
    alt = "Exit lesson"
   else
    showRoster = true
   end
  end
 elseif phase == "Recap" then
  heading, caption = if s.practice then "Placement confirmed" else "Review the case", "ROUND RECAP"
  description = if s.practice then "Compare the marker to your placement, then continue to the next view."
   elseif s.message ~= "" then s.message else "Review the correct location before the next round."
  ids = s.reveal
  main, alt = if s.practice then "Next lesson" else "Clinic roster", if s.practice then "Exit lesson" else "Review points"
  if not s.practice and recapRoster then ids,showRoster = nil,true end
 elseif phase == "Victory" then
  heading, caption = s.winner or (if s.practice then "Practice complete" else "Clinic closed"), if s.practice then "SOLO PRACTICE" else "MATCH COMPLETE"
  description = if s.practice then "You practiced front, back, sole, and crown placements." else s.message
  if s.practice then main,alt = "Try again","Exit lesson" else showRoster = true end
 end

 ui.overline.Text,ui.heading.Text,ui.description.Text = caption,heading,description
 ui.action.Text,ui.aux.Text = main,alt
 ui.action.Visible,ui.aux.Visible = main ~= "",alt ~= ""
 local buttonState = ui.action.Visible or ui.aux.Visible
 if buttonState ~= hasButtons then
  hasButtons = buttonState
  if resize then compact = ClinicUI.layout(ui,resize,hasButtons) end
 end
 local canPlace = active()
 ui.place.Visible,ui.back.Visible = canPlace,canPlace and s.region ~= nil
 ui.place.Text = if s.region then "Place needle" else "Select region"
 ui.listHeading.Text = if showRoster then "CLINIC ROSTER" else (if ids then "ACUPOINT CARDS" else "")
 ui.separator.Visible = showRoster or ids ~= nil
 ui.listHeading.Visible,ui.list.Visible = ui.separator.Visible,ui.separator.Visible
 updateList(ids,showRoster,phase=="Action" and not s.active)
end

local function apply(next: Snapshot)
 local old = state
 state = next
 local changed = old.phase ~= next.phase or old.roundId ~= next.roundId or old.practice ~= next.practice
 if changed then
  selected, recapRoster = 1,false
  hitVisual, didPlace, pendingPosition, pendingUntil, noAimUntil = nil,false,nil,0,0
  warningBeat = -1
  turn("Front",true)
  local ids = if next.phase == "Memory" then next.pool elseif next.phase == "Recap" then next.reveal else {}
  PatientView.setMarkers(view,ids)
  if ids[1] then goPoint(ids[1]) end
  ui.list.CanvasPosition = Vector2.zero
 elseif old.region ~= next.region then
  turn("Front",true)
  pendingUntil = 0
 end
 if next.phase == "Action" and (old.message ~= next.message or old.step ~= next.step) then
  if next.status == "Placed" or next.step > old.step then
   hitVisual,didPlace,resultAt = pendingPosition,true,clock()
   chime(1.15)
  elseif next.status == "Missed" or next.lockUntil > clock() then
   hitVisual,didPlace,resultAt = pendingPosition,false,clock()
   chime(.68)
  end
  pendingUntil = 0
  pendingPosition = nil
 end
 renderText()
end

local function accept(s: Snapshot)
 if s.revision < server.revision then return end
 server = s
 if not practice or s.active then
  practice = nil
  apply(s)
 end
end

local function localState(phase: Protocol.Phase)
 local point = lesson[lessonIndex]
 local snapshot: Snapshot = {
  revision = server.revision, phase = phase, deadline = 0, roundStart = 0, round = lessonIndex,
  roundId = "lesson_"..tostring(lessonIndex),active = true,practice = true,dynamic = false,overtime = false,
  pool = {point}, clues = {Data.byId[point].dialogue},reveal={point},step = 1,
  region=nil,status=if phase == "Action" then "Checking" else "Watching",lockUntil=0,rows={},message="",
 }
 practice = snapshot
 apply(snapshot)
end

local function editPractice(changes: (Snapshot) -> ())
 if not practice then return end
 local new = table.clone(practice)
 changes(new)
 practice = new
 apply(new)
end

local resumeQueue = false
local function beginPractice()
 if not practice then
  resumeQueue = inQueue()
  if resumeQueue then queueRemote:FireServer(false) end
 end
 lessonIndex = 1
 localState("Memory")
end

local function endPractice()
 practice = nil
 apply(server)
 if resumeQueue then
  task.delay(.4,function()
   if not practice and resumeQueue then queueRemote:FireServer(true) end
  end)
 end
end

local function currentHit(): (Rig.Segment?, Vector3?)
 if not cursor then return nil,nil end
 local origin, dir = PatientView.ray(view,cursor)
 return Rig.trace(origin,dir,state.region)
end

local function send(isBack: boolean?)
 if ui.shade.Visible or not active() then return end
 local t = clock()
 if t < pendingUntil or t < state.lockUntil or (state.deadline > 0 and t >= state.deadline) then return end
 if not isBack and cameraFrom and t - cameraAt < .30 then return end
 local part, position = currentHit()
 if not isBack and (not position or not part) then
  noAimUntil = t + 1.0
  return
 end
 local pos = position or Vector3.zero
 if practice then
  local goal = Data.byId[lesson[lessonIndex]]
  if isBack then
   editPractice(function(s) s.region,s.status,s.message = nil,"Checking","Choose a body region." end)
  elseif part and not state.region then
   if part.region == goal.region then
    editPractice(function(s) s.region,s.status,s.message = goal.region,"Aiming","Find the exact point." end)
    turn(Rig.pointView(goal),true)
   else
    editPractice(function(s) s.lockUntil,s.message = t+.55,"Try the "..string.lower(regionLabels[goal.region]).." region." end)
   end
  elseif HitRules.validNeedle(pos,goal) then
   chime(1.15)
   localState("Recap")
   hitVisual,didPlace,resultAt = pos,true,t
  else
   pendingPosition = pos
   editPractice(function(s) s.lockUntil,s.message = t+.55,"Try again. Use the location hint and rotate." end)
  end
  return
 end
 local intent: Protocol.Intent = {roundId=state.roundId,stepIndex=state.step,hitLocalPosition=pos,clientTimestamp=t}
 pendingUntil,pendingPosition = t+.70,pos
 if isBack then backRemote:FireServer(intent)
 elseif state.region then needleRemote:FireServer(intent)
 else macroRemote:FireServer(intent) end
end

ui.help.Activated:Connect(function()
 ui.shade.Visible = true
 if UserInputService.GamepadEnabled then GuiService.SelectedObject = ui.close end
end)
ui.close.Activated:Connect(function()
 ui.shade.Visible = false
 GuiService.SelectedObject = nil
end)
ui.motion.Activated:Connect(function()
 reduceMotion = not reduceMotion
 ui.motion.Text = if reduceMotion then "Motion: Low" else "Motion: Full"
end)
ui.previous.Activated:Connect(function() orbit(-1) end)
ui.nextView.Activated:Connect(function() orbit(1) end)
ui.place.Activated:Connect(function() send() end)
ui.back.Activated:Connect(function() send(true) end)
ui.action.Activated:Connect(function()
 if practice then
  if state.phase == "Memory" then localState("Action")
  elseif state.phase == "Victory" then beginPractice()
  elseif state.phase == "Recap" then
   if lessonIndex < #lesson then
    lessonIndex += 1
    localState("Memory")
   else localState("Victory") end
  end
 elseif state.phase == "Lobby" or state.phase == "Intermission" then beginPractice()
 elseif state.phase == "Recap" then
  recapRoster = true
  renderText()
 end
end)
ui.aux.Activated:Connect(function()
 if practice then endPractice()
 elseif state.phase == "Lobby" or state.phase == "Intermission" then queueRemote:FireServer(not inQueue())
 elseif state.phase == "Recap" then
  recapRoster = false
  renderText()
 end
end)

local function point2(p: Vector3): Vector2 return Vector2.new(p.X,p.Y) end
local function inside(point: Vector2): boolean
 local rel = point - ui.viewport.AbsolutePosition
 return rel.X >= 0 and rel.Y >= 0 and rel.X <= ui.viewport.AbsoluteSize.X and rel.Y <= ui.viewport.AbsoluteSize.Y
end
local function touchAim(point: Vector2): Vector2
 local box = ui.viewport
 local origin, size = box.AbsolutePosition,box.AbsoluteSize
 return Vector2.new(math.clamp(point.X,origin.X,origin.X+size.X),math.clamp(point.Y-40,origin.Y,origin.Y+size.Y))
end
local function canOrbitDrag(): boolean
 return state.phase == "Memory" or state.phase == "Recap" or state.phase == "Lobby"
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
 local kind,p = input.UserInputType,point2(input.Position)
 if ui.shade.Visible then
  if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
   ui.shade.Visible = false
   GuiService.SelectedObject = nil
  end
  return
 end
 if kind == Enum.UserInputType.Touch and inside(p) and not touch then
  touch,touchStart = input,p
  cursor = touchAim(p)
 elseif kind == Enum.UserInputType.MouseButton1 and inside(p) then
  cursor = p
  if canOrbitDrag() then orientationDrag = p else send() end
 elseif not processed then
  local key = input.KeyCode
  if key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then orbit(-1)
  elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonR1 then orbit(1)
  elseif key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then send(true)
  elseif key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.Space then
   if active() then send()
   elseif ui.action.Visible and key == Enum.KeyCode.ButtonA then
    if state.phase == "Lobby" then beginPractice()
    elseif practice and state.phase == "Memory" then localState("Action")
    elseif practice and state.phase == "Recap" then
     if lessonIndex < #lesson then lessonIndex += 1; localState("Memory") else localState("Victory") end
    elseif practice and state.phase == "Victory" then beginPractice() end
   end
  end
 end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
 local kind,p = input.UserInputType,point2(input.Position)
 if kind == Enum.UserInputType.MouseMovement then
  if orientationDrag and math.abs(p.X-orientationDrag.X) > 54 then
   orbit(if p.X > orientationDrag.X then 1 else -1)
   orientationDrag = p
  end
  -- Preserve the last aim while the pointer moves to the confirmation button.
  if inside(p) then cursor = p end
 elseif input == touch then
  if canOrbitDrag() and touchStart and math.abs(p.X-touchStart.X) > 54 then
   orbit(if p.X > touchStart.X then 1 else -1)
   touchStart = p
  end
  cursor = touchAim(p)
 elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
  stick = if p.Magnitude > .16 then Vector2.new(p.X,-p.Y) else Vector2.zero
 end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
 if input == touch then
  touch,touchStart = nil,nil
  if not state.region and active() then send() end
 elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
  orientationDrag = nil
 elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
  stick = Vector2.zero
 end
end)

local neutral = Rig.pose(false,0,0)
view.camera.CFrame = PatientView.desired(ui.viewport,nil,"Front")
renderText()
receiver.OnClientEvent:Connect(accept)
task.spawn(function()
 for _ = 1, 3 do
  local ok, snapshot = pcall(function() return get:InvokeServer() end)
  if ok and snapshot then accept(snapshot); return end
  task.wait(.7)
 end
end)

local function project(p: Vector3): Vector2?
 local relative = view.camera.CFrame:PointToObjectSpace(p)
 if relative.Z >= -.1 then return nil end
 local size = ui.viewport.AbsoluteSize
 local pixels = size.Y/(2*math.tan(math.rad(view.camera.FieldOfView/2)))
 return size/2 + Vector2.new(relative.X,-relative.Y)*pixels/-relative.Z
end

local markerTag = ClinicUI.label(ui.markerLayer,"",0,0,124,22,12,T.gold,ClinicUI.bold)
markerTag.BackgroundColor3,markerTag.BackgroundTransparency = T.bg,.10
markerTag.TextXAlignment = Enum.TextXAlignment.Center
local markerRound = Instance.new("UICorner")
markerRound.CornerRadius,markerRound.Parent = UDim.new(0,4),markerTag

RunService.RenderStepped:Connect(function(dt)
 local size = ui.gui.AbsoluteSize
 if size.X < 32 or size.Y < 32 then return end
 if resize ~= size then
  resize = size
  compact = ClinicUI.layout(ui,size,hasButtons)
 end
 local t = clock()
 local s = state
 local remaining = math.max(0,s.deadline-t)
 local duration = if s.phase == "Action" then (if s.overtime then Protocol.overtime else Protocol.action)
  elseif s.phase == "Memory" then Protocol.memory elseif s.phase == "Intermission" then Protocol.intermission
  elseif s.phase == "Recap" then Protocol.recap else Protocol.victory
 local urgent = s.phase == "Action" and s.deadline > 0 and remaining <= 3
 ui.timer.Text = if s.deadline > 0 then string.format("%02d",math.ceil(remaining)) else "—"
 ui.timer.TextColor3 = if urgent then T.red else T.gold
 ui.bar.Size = UDim2.fromScale(if s.deadline > 0 then math.clamp(remaining/duration,0,1) else 0,1)
 ui.bar.BackgroundColor3 = if urgent then T.red else T.gold
 ui.direction.Text,ui.viewTitle.Text = string.upper(side),if s.region then string.upper(regionLabels[s.region]) else string.upper(side)
 ui.previous.Text = if compact then "‹" else "Q  ‹"
 ui.nextView.Text = if compact then "›" else "›  E"

 local dest = PatientView.desired(ui.viewport,s.region,side)
 local elapsed = t - cameraAt
 if cameraFrom and elapsed < .45 and not reduceMotion then
  local alpha = 1 - (1-math.clamp(elapsed/.45,0,1))^2
  view.camera.CFrame = cameraFrom:Lerp(dest,alpha)
 else
  view.camera.CFrame = dest
  cameraFrom = nil
 end
 local pose = if s.phase == "Action" and not s.region and s.dynamic and (s.status == "Checking" or not s.active)
  then Rig.pose(true,t-s.roundStart,s.round) else neutral
 if reduceMotion and pose ~= neutral then
  pose = {offset=Vector3.zero,twist=0,guard=pose.guard}
 end
 view.root = Rig.root(pose)
 local canAim = active() and not ui.shade.Visible
 if canAim and stick.Magnitude > 0 then
  local origin, boxSize = ui.viewport.AbsolutePosition,ui.viewport.AbsoluteSize
  local p = (cursor or origin + boxSize/2) - origin + stick*dt*math.min(boxSize.X,boxSize.Y)*.83
  cursor = origin + Vector2.new(math.clamp(p.X,0,boxSize.X),math.clamp(p.Y,0,boxSize.Y))
 end
 local aimPart = if canAim then currentHit() else nil
 PatientView.draw(view,pose,s.region,if aimPart then aimPart.region else nil,s.phase=="Memory",side)

 local locked = t < s.lockUntil
 local point = if s.phase == "Memory" then Data.byId[s.pool[selected] or ""]
  elseif s.phase == "Recap" then Data.byId[s.reveal[selected] or ""] else nil
 local mark = if point and Rig.pointView(point)==side then project(Rig.pointPosition(point)+Rig.normals[side]*.18) else nil
 markerTag.Visible = mark ~= nil
 if mark and point then
  markerTag.Text = point.name
  markerTag.Position = UDim2.fromOffset(mark.X/ui.scale.Scale+12,mark.Y/ui.scale.Scale-11)
 end

 ui.reticle.Visible = canAim and cursor ~= nil
 if cursor then
  local at = (cursor-ui.scene.AbsolutePosition)/ui.scale.Scale
  ui.reticle.Position = UDim2.fromOffset(at.X,at.Y)
 end
 ui.reticleStroke.Color = if locked then T.red elseif aimPart then T.gold else T.cream
 ui.place.BackgroundColor3 = if locked or t < pendingUntil then T.button else T.gold
 ui.place.TextColor3 = if locked or t < pendingUntil then T.muted else T.bg
 local feedback = s.message
 if locked then feedback ..= string.format("  %.1fs",s.lockUntil-t)
 elseif pose.guard and canAim and not s.region then feedback = string.upper(regionLabels[pose.guard]).." GUARDED"
 elseif s.phase == "Action" and feedback == "" and canAim then
  feedback = if UserInputService.TouchEnabled then "Drag to aim above your finger" elseif aimPart and not s.region then regionLabels[aimPart.region] else "Aim at the mannequin"
 end
 if t < noAimUntil and not locked then feedback = "Move the reticle onto the patient." end
 if s.phase == "Recap" and s.status == "Timeout" then feedback = "TIME EXPIRED" end
 ui.feedback.Text,ui.feedback.TextColor3 = feedback,if locked or s.status == "Missed" or s.status == "Timeout" then T.red elseif s.status == "Placed" then T.mint else T.cream
 local fx = t-resultAt
 local beat = math.floor(remaining*2)
 local flashing = fx < .27 and not didPlace and s.phase == "Action"
 if urgent and canAim and beat ~= warningBeat and remaining > 0 and not reduceMotion then
  warningBeat = beat
  if not sound.IsPlaying then chime(.54) end
 end
 ui.flashStroke.Transparency = if reduceMotion then 1 elseif flashing then .35+fx*2
  elseif urgent and canAim then .78 + .14*math.sin(t*4*math.pi) else 1
 local pulse = hitVisual ~= nil and fx < .48 and (s.region ~= nil or s.phase == "Recap")
 ui.halo.Visible = pulse
 if pulse and hitVisual then
  local at = project(hitVisual)
  if at then
   local d = if reduceMotion then 33 else 26+fx*100
   ui.halo.Size,ui.halo.Position = UDim2.fromOffset(d,d),UDim2.fromOffset(at.X/ui.scale.Scale,at.Y/ui.scale.Scale)
   ui.hitStroke.Color,ui.hitStroke.Transparency = if didPlace then T.mint else T.red,math.clamp(fx*2,0,1)
  else ui.halo.Visible = false end
 end
end)
