--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared.AcupointData)
local Rig = require(Shared.Rig)
local HitRules = require(Shared.HitRules)
local Protocol = require(Shared.Protocol)
local Rules = require(script.Parent.Rules)
local Rankings = require(script.Parent.Rankings)

type Entry = {
 player: Player, qi: number, earned: number, alive: boolean, delta: number, cheers: number,
 status: Protocol.Status, step: number, region: string?, lockUntil: number,
 lastInput: number, studyReady: boolean?, finish: number?, message: string,
}

local function makeRemote(name: string, parent: Folder): RemoteEvent
 local event = Instance.new("RemoteEvent")
 event.Name, event.Parent = name, parent
 return event
end
local network = Instance.new("Folder")
network.Name = Protocol.folder
local update = makeRemote("Snapshot", network)
local macro = makeRemote("SelectRegion", network)
local needle = makeRemote("PlaceNeedle", network)
local back = makeRemote("Back", network)
local queue = makeRemote("Queue", network)
local studyReady = makeRemote("StudyReady", network)
local cheer = makeRemote("Cheer", network)
local get = Instance.new("RemoteFunction")
get.Name, get.Parent = "GetSnapshot", network

local random = Random.new()
local entries: {[number]: Entry} = {}
local queuedPlayers: {[Player]: boolean} = {}
local queueRefreshPending = false
local cheerAt: {[Player]: number} = {}
local roster: {number} = {}
local pool: {string} = {}
local previous: string? = nil
local targets: {string} = {}
local phase: Protocol.Phase = "Lobby"
local deadline, roundStart, round, revision = 0, 0, 0, 0
local disputed, overtime = false, false
local roundId = ""
local winner: string? = nil
local matchMessage = ""

local function now(): number
 return Workspace:GetServerTimeNow()
end

local function contestants(): {Entry}
 local list: {Entry} = {}
 for _, id in ipairs(roster) do
  local entry = entries[id]
  if entry and entry.alive and entry.player.Parent == Players then table.insert(list, entry) end
 end
 return list
end


local function studyProgress(): (number, number, number)
 local active = contestants()
 local ready = 0
 for _, entry in ipairs(active) do
  if entry.studyReady then ready += 1 end
 end
 return ready, math.ceil(#active / 2), #active
end

local function queued(): {Player}
 local list: {Player} = {}
 for _, player in ipairs(Players:GetPlayers()) do
  if queuedPlayers[player] then table.insert(list, player) end
 end
 table.sort(list, function(a, b) return a.UserId < b.UserId end)
 return list
end

local function snapshot(player: Player): Protocol.Snapshot
 local rows: {Protocol.Row} = {}
 local entry = entries[player.UserId]
 if #roster > 0 then
  for _, id in ipairs(roster) do
   local e = entries[id]
   if e then
    table.insert(rows, {id = id, name = e.player.DisplayName, qi = e.qi, alive = e.alive,
     delta = e.delta, ready = true, cheers = e.cheers})
   end
  end
 else
  local list = Players:GetPlayers()
  table.sort(list, function(a,b) return a.UserId < b.UserId end)
  for _, p in ipairs(list) do
   local ready = queuedPlayers[p] == true
   table.insert(rows, {id = p.UserId, name = p.DisplayName, qi = 3, alive = ready, delta = 0, ready = ready, cheers = 0})
  end
 end
 local clues: {string} = {}
 if phase == "Action" or phase == "Recap" then
  for _, id in ipairs(targets) do table.insert(clues, Data.byId[id].dialogue) end
 end
 local study = nil
 if phase == "Memory" then
  local ready, required = studyProgress()
  study = {ready = ready, required = required, voted = entry ~= nil and entry.studyReady == true}
 end
 return {
  rankings = if phase == "Lobby" or phase == "Intermission" or phase == "Victory" then Rankings.snapshot() else nil,
  matchPoints = if phase == "Victory" and entry then entry.earned else nil,
  study = study, revision = revision, phase = phase, deadline = deadline, roundStart = roundStart,
  round = round, roundId = roundId, active = entry ~= nil and entry.alive, dynamic = round >= 6 and not overtime,
  overtime = overtime, pool = if phase == "Memory" then pool else {},
  clues = clues, reveal = if phase == "Recap" then targets else {},
  step = if entry then entry.step else 1, region = if entry then entry.region else nil,
  status = if entry then entry.status else "Watching",
  lockUntil = if entry then entry.lockUntil else 0, rows = rows, winner = winner,
  message = if entry and entry.message ~= "" then entry.message else matchMessage,
 }
end

local function publish(player: Player?)
 revision += 1
 if player then
  update:FireClient(player, snapshot(player))
 else
  for _, p in ipairs(Players:GetPlayers()) do update:FireClient(p, snapshot(p)) end
 end
end

local function transition(nextPhase: Protocol.Phase, duration: number)
 phase = nextPhase
 if nextPhase == "Intermission" then Rankings.requestRefresh() end
 deadline = if duration > 0 then now() + duration else 0
 if nextPhase == "Action" then roundStart = deadline - duration end
 publish(nil)
end

local function startStudyCountdown(): boolean
 if phase ~= "Memory" or deadline > 0 then return false end
 local ready, required, total = studyProgress()
 if total < 2 or ready < required then return false end
 transition("Memory", Protocol.memory)
 return true
end

local function waitPhase(early: (() -> boolean)?)
 while now() < deadline do
  if early and early() then return end
  task.wait(0.08)
 end
end

local function expand(n: number)
 local available: {string} = {}
 for _, point in ipairs(Data.points) do
  if not table.find(pool, point.id) then table.insert(available, point.id) end
 end
 for _ = 1, math.min(n, #available) do
  local picked = table.remove(available, random:NextInteger(1, #available))
  if picked then table.insert(pool, picked) end
 end
end

local function chooseTargets(): {string}
 if overtime then
  return {Data.points[random:NextInteger(1, #Data.points)].id}
 end
 local count = if round >= 4 then 2 else 1
 if count == 2 and random:NextNumber() < 0.5 then
  local combos: {{string}} = {}
  for _, combo in ipairs(Data.combos) do
   if table.find(pool, combo[1]) and table.find(pool, combo[2]) and combo[1] ~= previous then
    table.insert(combos, combo)
   end
  end
  if #combos > 0 then return table.clone(combos[random:NextInteger(1, #combos)]) end
 end
 local options = table.clone(pool)
 local old = previous and table.find(options, previous)
 if old then table.remove(options, old) end
 local picked: {string} = {}
 for _ = 1, count do
  local id = table.remove(options, random:NextInteger(1, #options))
  if id then table.insert(picked, id) end
 end
 return picked
end

local function validate(player: Player, payload: any): (Entry?, number)
 local t = now()
 local entry = entries[player.UserId]
 if phase ~= "Action" or winner or t >= deadline or not entry or not entry.alive
  or (entry.status ~= "Checking" and entry.status ~= "Aiming")
  or t < entry.lockUntil or t - entry.lastInput < 0.085 then return nil, t end
 entry.lastInput = t
 if type(payload) ~= "table" or payload.roundId ~= roundId or payload.stepIndex ~= entry.step
  or not HitRules.validVector(payload.hitLocalPosition)
  or type(payload.clientTimestamp) ~= "number" or not HitRules.finite(payload.clientTimestamp)
  or payload.clientTimestamp < t - 1 or payload.clientTimestamp > t + 0.15 then return nil, t end
 return entry, t
end

macro.OnServerEvent:Connect(function(player: Player, payload: any)
 local entry, t = validate(player, payload)
 if not entry or entry.status ~= "Checking" then return end
 local sampled = math.clamp(payload.clientTimestamp, t - 0.22, t)
 local pose = Rig.pose(round >= 6 and not overtime, sampled - roundStart, round)
 local part = Rig.segmentAt(payload.hitLocalPosition, nil, 0.045)
 if not part then return end
 local point = Data.byId[targets[entry.step]]
 if part.region == pose.guard then
  entry.lockUntil, entry.message = t + 1, "Blocked! Wait for the guard to drop."
 elseif part.region ~= point.region then
  entry.lockUntil, entry.message = t + 1.5, "Wrong region. Try a different part."
 else
  entry.region, entry.status, entry.message = part.region, "Aiming", "Lock acquired. Find the exact point."
 end
 publish(player)
end)

needle.OnServerEvent:Connect(function(player: Player, payload: any)
 local entry, t = validate(player, payload)
 if not entry or entry.status ~= "Aiming" then return end
 local point = Data.byId[targets[entry.step]]
 if not HitRules.validNeedle(payload.hitLocalPosition, point) then
  if overtime then
   entry.lockUntil, entry.message = t + 0.45, "Off target. Try again."
  else
   entry.status, entry.message = "Missed", "Off target. Take a look at the recap."
  end
 elseif entry.step < #targets then
  entry.step += 1
  entry.region, entry.status, entry.message = nil, "Checking", "First point placed! Find the next region."
 else
  entry.finish, entry.status, entry.message = t, "Placed", "Placement confirmed."
  if overtime then
   entry.earned += 2
   winner = player.DisplayName
  end
 end
 publish(player)
end)

back.OnServerEvent:Connect(function(player: Player, payload: any)
 local entry = validate(player, payload)
 if not entry or entry.status ~= "Aiming" then return end
 entry.region, entry.status, entry.message = nil, "Checking", "Choose a body region."
 publish(player)
end)

queue.OnServerEvent:Connect(function(player: Player, ready: any)
 if type(ready) ~= "boolean" or entries[player.UserId] or (queuedPlayers[player] == true) == ready then return end
 queuedPlayers[player] = ready
 if queueRefreshPending then return end
 queueRefreshPending = true
 task.delay(0.2, function()
  queueRefreshPending = false
  publish(nil)
 end)
end)

studyReady.OnServerEvent:Connect(function(player: Player, studyId: any)
 if phase ~= "Memory" or deadline > 0 or studyId ~= roundId then return end
 local entry = entries[player.UserId]
 if not entry or entry.player ~= player or not entry.alive or entry.studyReady then return end
 entry.studyReady = true
 if not startStudyCountdown() then publish(nil) end
end)

cheer.OnServerEvent:Connect(function(player: Player, target: any)
 local source = entries[player.UserId]
 if phase ~= "Action" or (source and source.alive) or type(target) ~= "number" or not HitRules.finite(target) then return end
 local entry = entries[target]
 local t = now()
 if not entry or not entry.alive or t - (cheerAt[player] or 0) < 3 then return end
 cheerAt[player] = t
 entry.cheers += 1
 publish(nil)
end)

get.OnServerInvoke = function(player: Player)
 return snapshot(player)
end
network.Parent = ReplicatedStorage
Rankings.start(function()
 if phase == "Lobby" or phase == "Intermission" or phase == "Victory" then publish(nil) end
end)

Players.PlayerAdded:Connect(function()
 publish(nil)
end)
Players.PlayerRemoving:Connect(function(player)
 queuedPlayers[player], cheerAt[player] = nil, nil
 local entry = entries[player.UserId]
 if entry then
  entry.alive, entry.status, entry.message = false, "Watching", "Left the clinic."
 end
 task.defer(function()
  if not startStudyCountdown() then publish(nil) end
 end)
end)

local function startRound()
 targets = chooseTargets()
 previous, roundId = targets[1], HttpService:GenerateGUID(false)
 for _, e in ipairs(contestants()) do
  e.step, e.region, e.status, e.lockUntil, e.lastInput = 1, nil, "Checking", 0, 0
  e.finish, e.delta, e.message = nil, 0, ""
 end
 matchMessage = if overtime then "First valid placement wins." else ""
 transition("Action", Protocol.action)
end

local function roundDone(): boolean
 if winner then return true end
 local list = contestants()
 if #list <= 1 then return true end
 for _, e in ipairs(list) do
  if e.status == "Checking" or e.status == "Aiming" then return false end
 end
 return true
end

local function resolve()
 local results: {Rules.Result} = {}
 for _, e in ipairs(contestants()) do
  table.insert(results, {id = e.player.UserId, qi = e.qi, finish = e.finish, missed = e.status == "Missed"})
  if e.status == "Checking" or e.status == "Aiming" then e.status = "Timeout" end
 end
 local awards, survivors = Rules.score(results)
 disputed = survivors == 0 and #results > 1
 for _, award in ipairs(awards) do
  local e = entries[award.id]
  e.earned += math.max(award.delta,0)
  e.qi = if disputed then 1 else award.qi
  e.alive, e.delta = e.qi > 0, award.delta
  e.message = award.reason
 end
 matchMessage = if disputed then "Whole clinic wiped out. Sudden death is next." else ""
end

local function reset()
 table.clear(entries)
 table.clear(roster)
 table.clear(pool)
 targets, previous, winner = {}, nil, nil
 disputed, overtime = false, false
 round, roundId, roundStart, matchMessage = 0, "", 0, ""
end

while true do
 reset()
 transition("Lobby", 0)
 repeat task.wait(0.25) until #queued() >= 2
 transition("Intermission", Protocol.intermission)
 waitPhase(function() return #queued() < 2 end)
 local list = queued()
 if #list < 2 then continue end
 for i = 1, math.min(Protocol.capacity, #list) do
  local p = list[i]
  table.insert(roster, p.UserId)
  entries[p.UserId] = {player = p, qi = 3, earned = 0, alive = true, delta = 0, cheers = 0, status = "Checking",
   step = 1, lockUntil = 0, lastInput = 0, message = ""}
 end
 expand(3)
 while #contestants() > 1 and not winner do
  round += 1
  overtime = disputed
  local showMemory = round == 1 or round == 3 or (round >= 7 and (round - 7) % 3 == 0 and #pool < #Data.points)
  if not overtime and showMemory then
   if round > 1 then expand(3) end
   for _, e in ipairs(contestants()) do e.message, e.studyReady = "", false end
   matchMessage = ""
   roundId = HttpService:GenerateGUID(false)
   transition("Memory", 0)
   while deadline == 0 and #contestants() > 1 do task.wait(0.08) end
   waitPhase(function() return #contestants() <= 1 end)
   if #contestants() <= 1 then break end
  end
  startRound()
  waitPhase(roundDone)
  if winner then break end
  local stillPlaying = contestants()
  if #stillPlaying <= 1 then
   local last = stillPlaying[1]
   if last and last.finish then last.earned += 2 end
   break
  end
  if overtime then
   for _, e in ipairs(contestants()) do
    e.status, e.message = "Timeout", "Time expired. A new sudden-death point is coming."
   end
  else
   resolve()
  end
  transition("Recap", Protocol.recap)
  waitPhase(function() return #contestants() == 0 end)
 end
 local remaining = contestants()
 if not winner and #remaining == 1 then winner = remaining[1].player.DisplayName end
 local scores: {[number]: number} = {}
 for id, e in pairs(entries) do
  e.message = ""
  if e.earned > 0 then scores[id] = e.earned end
 end
 Rankings.submit(scores,os.time())
 matchMessage = if winner then "Last practitioner standing." else "The clinic has closed this match."
 transition("Victory", Protocol.victory)
 waitPhase(nil)
end
