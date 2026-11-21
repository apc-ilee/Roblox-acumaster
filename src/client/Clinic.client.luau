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
local RankingsView = require(script.Parent.RankingsView)
local Fireworks = require(script.Parent.Fireworks)

type Snapshot = Protocol.Snapshot
local player = Players.LocalPlayer
local ui = ClinicUI.build(player:WaitForChild("PlayerGui") :: PlayerGui)
local view = PatientView.build(ui.viewport)
local ranks = RankingsView.build(ui.scene)
local T = ClinicUI.theme
local wire = ReplicatedStorage:WaitForChild(Protocol.folder)
local receiver = wire:WaitForChild("Snapshot") :: RemoteEvent
local get = wire:WaitForChild("GetSnapshot") :: RemoteFunction
local macroRemote = wire:WaitForChild("SelectRegion") :: RemoteEvent
local needleRemote = wire:WaitForChild("PlaceNeedle") :: RemoteEvent
local backRemote = wire:WaitForChild("Back") :: RemoteEvent
local queueRemote = wire:WaitForChild("Queue") :: RemoteEvent
local studyRemote = wire:WaitForChild("StudyReady") :: RemoteEvent
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
local reduceMotion, compact = false, false
local useHumanFigure = true
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

local phaseLabels = {Lobby="LOBBY",Intermission="GET READY",Memory="STUDY",Action="DIAGNOSE",Recap="RECAP",Victory="RESULT"}
local regionLabels: {[string]: string} = {Head="Head",Torso="Torso",LeftArm="Left arm",RightArm="Right arm",LeftLeg="Left leg",RightLeg="Right leg"}
local function goPoint(id: string)
 local point = Data.byId[id]
 if point then turn(Rig.pointView(point),true) end
end

local function studyMarkerIds(): {string}
 local focused = state.pool[selected]
 return if focused then {focused} else state.pool
end

local function focusStudyPoint(index: number)
 selected = index
 PatientView.setMarkers(view,studyMarkerIds())
 local focused = state.pool[selected]
 if focused then goPoint(focused) else turn("Front",true) end
 ui.nextPoint.Text = if selected == 0 or selected >= #state.pool then "First point" else "Next point"
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
 for _, item in ipairs(ui.list:GetChildren()) do
  if item:IsA("GuiObject") then item:Destroy() end
 end
 if ids then
  for i, id in ipairs(ids) do
   local point = Data.byId[id]
   local row = ClinicUI.button(ui.list,"",0,0,0,91,i == selected)
   row.Size, row.LayoutOrder = UDim2.new(1,-4,0,91),i
   local tint = if i == selected then T.bg else T.cream
   local subTint = if i == selected then T.goldDark else T.muted
   local name = ClinicUI.label(row,point.cn.."  "..point.name,10,3,0,29,13,tint,ClinicUI.bold)
   local location = ClinicUI.label(row,point.location.."  /  "..string.upper(Rig.pointView(point)),10,32,0,26,11,subTint)
   local clue = ClinicUI.label(row,point.clue,10,59,0,26,11,tint)
   name.Size,location.Size,clue.Size = UDim2.new(1,-20,0,29),UDim2.new(1,-20,0,26),UDim2.new(1,-20,0,26)
   row.Activated:Connect(function()
    if state.phase == "Memory" then
     focusStudyPoint(i)
    else
     selected = i
     goPoint(id)
    end
    updateList(ids,false,false)
   end)
  end
 elseif showRoster then
  for i, row in ipairs(state.rows) do
   local item = ClinicUI.panel(ui.list,0,0,0,55,T.button,6)
   item.Size,item.LayoutOrder = UDim2.new(1,-4,0,55),i
   ClinicUI.label(item,row.name..(if row.id == player.UserId then "  (you)" else ""),9,0,186,55,13,T.cream)
   local mark = if state.phase == "Lobby" or state.phase == "Intermission" then (if row.ready then "QUEUED" else "OUT")
    elseif not row.alive then "OUT"
    else string.format("%d QI",row.qi)
   if state.phase == "Recap" and row.delta ~= 0 then mark ..= string.format("  %+.0f",row.delta) end
   if row.cheers > 0 and not canCheer then mark ..= string.format("  ♥%d",row.cheers) end
   local text = ClinicUI.label(item,mark,0,0,157,55,12,if row.delta < 0 then T.red elseif row.alive then T.mint else T.faint,ClinicUI.mono)
   text.TextXAlignment,text.AnchorPoint,text.Position = Enum.TextXAlignment.Right,Vector2.new(1,0),UDim2.new(1,if canCheer and row.alive then -92 else -9,0,0)
   if canCheer and row.alive then
    local cheerButton = ClinicUI.button(item,string.format("♥ %d",row.cheers),0,5,82,45)
    cheerButton.AnchorPoint,cheerButton.Position,cheerButton.TextSize = Vector2.new(1,0),UDim2.new(1,-5,0,5),12*ClinicUI.textScale
    cheerButton.Activated:Connect(function() cheerRemote:FireServer(row.id) end)
   end
  end
 end
end

local queuedForMatch = false
local function setQueue(ready: boolean)
 if queuedForMatch == ready then return end
 queuedForMatch = ready
 queueRemote:FireServer(ready)
end

local function updateCelebration()
 ranks.sparks:ClearAllChildren()
 if state.phase == "Victory" and not state.practice and state.winner then Fireworks.play(ranks.sparks,reduceMotion) end
end

local function renderText()
 local s = state
 local phase = s.phase
 local heading, description, caption = "", "", "CASE NOTES"
 local ids: {string}? = nil
 local showRoster = false
 local main, alt = "", ""
 ui.phase.Text = if s.practice then "PRACTICE" elseif phase == "Action" and s.overtime then "OVERTIME" else (phaseLabels[phase] or "")
 ui.detail.Text = if s.practice then string.format("%s%d/%d",if compact then "" else "LESSON ",lessonIndex,#lesson)
  elseif phase == "Lobby" then (if compact then "2–12" else "2–12 PLAYERS")
  elseif phase == "Memory" and s.study and s.deadline == 0 then string.format("%s%d/%d",if compact then "" else "READY ",s.study.ready,s.study.required)
  elseif s.round > 0 then string.format("ROUND %d",s.round)
  else (if compact then "" else "MATCH QUEUE")
 ui.sceneTitle.Text = if phase == "Memory" then (if useHumanFigure then "HUMAN FIGURE" else "BLOCK FIGURE")
  elseif phase == "Action" and s.region then "PRECISION VIEW"
  elseif phase == "Recap" then "MERIDIAN ATLAS" else "PATIENT VIEW"
 RankingsView.render(ranks,s)
 local patientVisible = not ranks.board.Visible
 ui.viewport.Visible,ui.cameraControls.Visible = patientVisible,patientVisible
 local studyPhase = phase == "Memory"
 ui.sceneTitle.Visible,ui.viewTitle.Visible = patientVisible,patientVisible and not studyPhase
 ui.figure.Visible,ui.overview.Visible,ui.nextPoint.Visible = studyPhase,studyPhase,studyPhase and #s.pool > 0
 ui.figure.Text = if useHumanFigure then (if compact then "Blocks" else "Show blocks") else (if compact then "Human" else "Show human")
 ui.nextPoint.Text = if selected == 0 or selected >= #s.pool then "First point" else "Next point"
 if phase == "Lobby" or phase == "Intermission" then
  heading, caption, showRoster = "The clinic is open", "MATCH QUEUE", true
  description = if phase == "Lobby" then "A match starts when two players queue. Start a solo lesson while you wait."
   else "The match is about to start. Study the marked points first, then diagnose by clue."
  main, alt = "Solo practice", if queuedForMatch then "Leave queue" else "Join queue"
 elseif phase == "Memory" then
  heading, caption = "Study the points", "MERIDIAN STUDY"
  ids = s.pool
  if s.practice then
   main, alt, description = "Start lesson", "Exit lesson", "Match the red marker to its clue."
  elseif s.deadline > 0 then
   description = "The countdown has started. Use Next point to review the markers."
  elseif s.active and s.study then
   main = if s.study.voted then "" else "Ready"
   description = if s.study.voted then "You’re ready. Waiting for other players."
    else "Select Ready when done. Half the players start a 10-second countdown."
  else
   description = "The players are studying. The countdown starts when half are ready."
  end
 elseif phase == "Action" then
  caption = if active() then "" else "PATIENT REPORT"
  if not s.active then
   heading, description = "Spectating", "Follow the live case and cheer for a practitioner. The next match starts after the ceremony."
   showRoster = true
  else
   heading = if s.status == "Placed" then "Placement confirmed" elseif s.status == "Missed" then "Off target"
    elseif s.region then "Place the needle" else "Find the region"
   if s.practice then
    local point = Data.byId[lesson[lessonIndex]]
    description = point.cn.." · "..point.name.."  /  "..point.location
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
  if s.practice then
   heading, caption = "Practice complete", "SOLO PRACTICE"
   description = "You practiced front, back, sole, and crown placements."
   main, alt = "Try again", "Exit lesson"
  else
   heading, caption, showRoster = "Match scores", "", true
   if s.matchPoints then description = string.format("You earned %d ranking points this match.",s.matchPoints) end
  end
 end

 ui.overline.Text,ui.heading.Text,ui.description.Text = caption,heading,description
 ui.overline.Visible,ui.description.Visible = caption ~= "",description ~= ""
 ui.action.Text,ui.aux.Text = main,alt
 ui.action.Visible,ui.aux.Visible = main ~= "",alt ~= ""
 ui.controls.Visible = ui.action.Visible or ui.aux.Visible
 local split = ui.action.Visible and ui.aux.Visible
 ui.action.Size = UDim2.new(if split then .5 else 1,if split then -4 else 0,1,0)
 ui.aux.Size = ui.action.Size
 ui.aux.Position = UDim2.new(if split then .5 else 0,if split then 4 else 0,0,0)
 local canPlace = active()
 ClinicUI.setSymptom(ui,if canPlace then s.clues[s.step] else nil,s.step,#s.clues)
 ui.place.Visible,ui.back.Visible = canPlace,canPlace and s.region ~= nil
 ui.place.Text = if s.region then (if compact then "Place" else "Place needle") else (if compact then "Select" else "Select region")
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
  selected, recapRoster = (if next.phase == "Memory" then 0 else 1),false
  hitVisual, didPlace, pendingPosition, pendingUntil, noAimUntil = nil,false,nil,0,0
  warningBeat = -1
  turn("Front",next.phase ~= "Memory")
  local ids = if next.phase == "Memory" then next.pool elseif next.phase == "Recap" then next.reveal else {}
  PatientView.setStudyFigure(view,next.phase == "Memory" and useHumanFigure)
  PatientView.setMarkers(view,ids)
  if next.phase == "Recap" and ids[1] then goPoint(ids[1]) end
  ui.side.CanvasPosition = Vector2.zero
  updateCelebration()
 elseif old.region ~= next.region then
  turn("Front",true)
  pendingUntil = 0
 end
 if next.phase == "Action" and old.step ~= next.step then ui.side.CanvasPosition = Vector2.zero end
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
 if s.active then queuedForMatch = true end
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
  resumeQueue = queuedForMatch
  setQueue(false)
 end
 lessonIndex = 1
 localState("Memory")
end

local function endPractice()
 practice = nil
 setQueue(resumeQueue)
 apply(server)
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

local helpPages = {
 {
  title = "How to play",
  body = [[Study the red acupoints before the round. Start with the full figure, then choose First point or a card to zoom in. Use Overview to return.

Select Ready when you’re done. When half the players are ready, everyone gets a final 10 seconds to study.]],
 },
 {
  title = "How to aim",
  body = [[Read the patient’s clue. Select the matching body region, then rotate to the right view and aim at the exact point.

The fastest valid placement gains 2 Qi. A miss or timeout costs 1 Qi.]],
 },
 {
  title = "Controls",
  body = [[Mouse and keyboard
Aim and click to confirm. Q/E rotates and Backspace goes back.

Touch
Drag to aim. Release to select a region, then use Place to confirm the exact point. Tap the arrows to rotate.

Gamepad
Left stick aims. A confirms, LB/RB rotates, and B goes back.]],
 },
}
local introPending = true
local helpPage = 1
local function showHelpPage()
 local page = helpPages[helpPage]
 ui.helpStep.Text = string.format("QUICK START  %d/%d",helpPage,#helpPages)
 ui.modalHead.Text,ui.instructions.Text = page.title,page.body
 ui.helpScroll.CanvasPosition = Vector2.zero
 ui.helpClose.Text = if introPending then "Skip" else "Close"
 ui.helpBack.Visible = helpPage > 1
 ui.helpNext.Text = if helpPage < #helpPages then "Next" elseif introPending then "Play" else "Done"
 ui.helpClose.NextSelectionRight = if helpPage > 1 then ui.helpBack else ui.helpNext
 ui.helpNext.NextSelectionLeft = if helpPage > 1 then ui.helpBack else ui.helpClose
end
local function openHelp()
 helpPage = 1
 showHelpPage()
 ui.shade.Visible = true
 if UserInputService.GamepadEnabled then GuiService.SelectedObject = ui.helpNext end
end
local function closeHelp()
 if not ui.shade.Visible then return end
 ui.shade.Visible = false
 GuiService.SelectedObject = nil
 if introPending then
  introPending = false
  setQueue(true)
  renderText()
 end
end
local function nextHelpPage()
 if helpPage == #helpPages then
  closeHelp()
 else
  helpPage += 1
  showHelpPage()
 end
end
ui.help.Activated:Connect(openHelp)
ui.helpClose.Activated:Connect(closeHelp)
ui.helpNext.Activated:Connect(nextHelpPage)
ui.helpBack.Activated:Connect(function()
 if helpPage > 1 then
  helpPage -= 1
  showHelpPage()
  if GuiService.SelectedObject == ui.helpBack and not ui.helpBack.Visible then GuiService.SelectedObject = ui.helpNext end
 end
end)
ui.motion.Activated:Connect(function()
 reduceMotion = not reduceMotion
 ui.motion.Text = if reduceMotion then "Motion: Low" else "Motion: Full"
 if state.phase == "Victory" then updateCelebration() end
end)
local function switchStudyFigure()
 if state.phase ~= "Memory" then return end
 useHumanFigure = not useHumanFigure
 PatientView.setStudyFigure(view,useHumanFigure)
 PatientView.setMarkers(view,studyMarkerIds())
 renderText()
end
ui.figure.Activated:Connect(switchStudyFigure)
ui.overview.Activated:Connect(function()
 if state.phase ~= "Memory" then return end
 focusStudyPoint(0)
 renderText()
end)
ui.nextPoint.Activated:Connect(function()
 if state.phase ~= "Memory" or #state.pool == 0 then return end
 focusStudyPoint(selected % #state.pool + 1)
 renderText()
end)
ui.previous.Activated:Connect(function() orbit(-1) end)
ui.nextView.Activated:Connect(function() orbit(1) end)
ui.place.Activated:Connect(function() send() end)
ui.back.Activated:Connect(function() send(true) end)
local function primaryAction()
 if ui.shade.Visible then return end
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
 elseif state.phase == "Memory" and state.active and state.deadline == 0 and state.study and not state.study.voted then
  studyRemote:FireServer(state.roundId)
 elseif state.phase == "Recap" then
  recapRoster = true
  renderText()
 end
end
ui.action.Activated:Connect(primaryAction)
ui.aux.Activated:Connect(function()
 if ui.shade.Visible then return end
 if practice then endPractice()
 elseif state.phase == "Lobby" or state.phase == "Intermission" then
  setQueue(not queuedForMatch)
  renderText()
 elseif state.phase == "Recap" then
  recapRoster = false
  renderText()
 end
end)

local function point2(p: Vector3): Vector2 return Vector2.new(p.X,p.Y) end
local function inside(point: Vector2): boolean
 if not ui.viewport.Visible then return false end
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
   closeHelp()
  elseif not processed and input.KeyCode == Enum.KeyCode.Return then
   nextHelpPage()
  elseif not processed and input.KeyCode == Enum.KeyCode.ButtonA and not GuiService.SelectedObject then
   nextHelpPage()
   if ui.shade.Visible then GuiService.SelectedObject = ui.helpNext end
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
  elseif key == Enum.KeyCode.ButtonY then switchStudyFigure()
  elseif key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then send(true)
  elseif key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.Space then
   if active() then send()
   elseif ui.action.Visible and (key == Enum.KeyCode.ButtonA or state.phase == "Memory") then
    primaryAction()
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
openHelp()
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

local markerTag = ClinicUI.label(ui.markerLayer,"",0,0,190,33,12,T.point,ClinicUI.bold)
markerTag.BackgroundColor3,markerTag.BackgroundTransparency = T.bg,.10
markerTag.TextXAlignment = Enum.TextXAlignment.Center
local markerRound = Instance.new("UICorner")
markerRound.CornerRadius,markerRound.Parent = UDim.new(0,4),markerTag

RunService.RenderStepped:Connect(function(dt)
 local size = ui.gui.AbsoluteSize
 if size.X < 32 or size.Y < 32 then return end
 if resize ~= size then
  resize = size
  compact = ClinicUI.layout(ui,size)
  RankingsView.layout(ranks,ui.scene)
  renderText()
 end
 local t = clock()
 local s = state
 local remaining = math.max(0,s.deadline-t)
 local duration = if s.phase == "Action" then Protocol.action
  elseif s.phase == "Memory" then Protocol.memory elseif s.phase == "Intermission" then Protocol.intermission
  elseif s.phase == "Recap" then Protocol.recap else Protocol.victory
 local urgent = s.phase == "Action" and s.deadline > 0 and remaining <= 3
 if ui.symptom.Visible then ClinicUI.paintSymptom(ui,s.step,urgent) end
 ui.timer.Text = if s.deadline > 0 then string.format("%02d",math.ceil(remaining)) else "—"
 ui.timer.TextColor3 = if urgent then T.red else T.gold
 ui.bar.Size = UDim2.fromScale(if s.deadline > 0 then math.clamp(remaining/duration,0,1) else 0,1)
 ui.bar.BackgroundColor3 = if urgent then T.red else T.gold
 ui.direction.Text,ui.viewTitle.Text = string.upper(side),if s.region then string.upper(regionLabels[s.region]) else string.upper(side)
 ui.previous.Text = if compact then "‹" else "Q  ‹"
 ui.nextView.Text = if compact then "›" else "›  E"

 local point = if s.phase == "Memory" then Data.byId[s.pool[selected] or ""]
  elseif s.phase == "Recap" then Data.byId[s.reveal[selected] or ""] else nil
 local displayRegion = if s.phase == "Memory" and point then point.region else s.region
 local dest = PatientView.desired(ui.viewport,displayRegion,side)
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
 if ui.viewport.Visible then PatientView.draw(view,pose,displayRegion,if aimPart then aimPart.region else nil,s.phase=="Memory",side) end

 local locked = t < s.lockUntil
 local markerAt = if point then view.markerPositions[point.id] else nil
 local mark = if point and markerAt and Rig.pointView(point)==side then project(markerAt) else nil
 markerTag.Visible = mark ~= nil
 if mark and point then
  markerTag.Text = point.name
  local at, viewportSize = mark/ui.scale.Scale,ui.viewport.AbsoluteSize/ui.scale.Scale
  local width = markerTag.Size.X.Offset
  local x = if at.X+width+14 <= viewportSize.X-8 then at.X+14 else at.X-width-14
  markerTag.Position = UDim2.fromOffset(math.clamp(x,0,math.max(0,viewportSize.X-width)),at.Y-16)
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
  feedback = if UserInputService.TouchEnabled then "Drag to aim" elseif aimPart and not s.region then regionLabels[aimPart.region] else "Aim at the patient"
 end
 if t < noAimUntil and not locked then feedback = "Aim at the patient" end
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
