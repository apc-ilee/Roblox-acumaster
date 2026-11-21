--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Protocol)

type Chart = Protocol.Chart
type RankRow = Protocol.RankRow
type Ledger = { points: number, servers: {[string]: number} }
type Write = { id: number, scope: string, target: number, running: boolean, retryAt: number, failures: number }

local studio = RunService:IsStudio()
local serverId = HttpService:GenerateGUID(false)
local limit = 5
local utcOffset = 8 * 60 * 60
local ledgerStore = if studio then nil else DataStoreService:GetDataStore("AcuMasterRankLedgerV1")
local localTotals: {[string]: {[number]: number}} = {}
local pending: {[string]: Write} = {}
local names: {[number]: string} = {}
local daily: Chart = {period="",rows={},status="Loading"}
local monthly: Chart = {period="",rows={},status="Loading"}
local changed: (() -> ())? = nil
local activeWrites = 0
local refreshRequested = true
local readAfter = 0
local nextReadAllowed = 0

local function periods(timestamp: number): (string, string)
 local localTime = os.date("!*t", timestamp + utcOffset)
 return string.format("%04d-%02d-%02d",localTime.year,localTime.month,localTime.day),
  string.format("%04d-%02d",localTime.year,localTime.month)
end

local function publish()
 if changed then changed() end
end

local function snapshot(): Protocol.Rankings
 return {daily=daily,monthly=monthly,saving=next(pending)~=nil,studio=studio}
end

local function ordered(scope: string): OrderedDataStore
 return DataStoreService:GetOrderedDataStore("AcuMasterRankingsV1",scope)
end

local function save(key: string, write: Write)
 local target = write.target
 local ok, message = pcall(function()
  if not ledgerStore then return true end
  local ledger: Ledger = ledgerStore:UpdateAsync(key,function(old: Ledger?): Ledger
   local record: Ledger = old or {points=0,servers={}}
   local previous = record.servers[serverId] or 0
   -- A retried write, including a retry after only the ledger succeeded,
   -- adds only the uncommitted part of this server's cumulative score.
   if target > previous then
    record.points += target - previous
    record.servers[serverId] = target
   end
   return record
  end)
  ordered(write.scope):UpdateAsync(tostring(write.id),function(points: number?): number
   -- Another server may have projected a newer ledger total already.
   return math.max(points or 0,ledger.points)
  end)
  return true
 end)
 activeWrites -= 1
 write.running = false
 if ok then
  write.failures = 0
  if write.target == target then pending[key] = nil end
  if next(pending) == nil then
   refreshRequested = true
   readAfter = 0
   -- Keep the saving label until the refreshed charts replace the cached rows.
  end
 else
  write.failures += 1
  write.retryAt = os.clock() + math.min(2^write.failures,15)
  if write.failures == 1 then warn("Acu-Master could not save a ranking yet:",message) end
 end
end

local function add(scope: string, id: number, points: number)
 local totals = localTotals[scope]
 if not totals then
  totals = {}
  localTotals[scope] = totals
 end
 local total = (totals[id] or 0) + points
 totals[id] = total
 if studio then return end
 local key = scope.."_"..tostring(id)
 local write = pending[key]
 if write then
  write.target = total
 else
  pending[key] = {id=id,scope=scope,target=total,running=false,retryAt=0,failures=0}
 end
end

local function submit(scores: {[number]: number}, finishedAt: number)
 local day, month = periods(finishedAt)
 for id, points in pairs(scores) do
  if points > 0 and (studio or id > 0) then
   add("day_"..day,id,points)
   add("month_"..month,id,points)
  end
 end
 refreshRequested = true
 if studio then readAfter = 0 end
end

local function read(period: string, scope: string, previous: Chart): Chart
 local rows: {RankRow} = {}
 if studio then
  for id, points in pairs(localTotals[scope] or {}) do table.insert(rows,{id=id,name="",points=points}) end
  table.sort(rows,function(a,b) return if a.points == b.points then a.id < b.id else a.points > b.points end)
  while #rows > limit do table.remove(rows) end
 else
  local ok, result = pcall(function()
   return ordered(scope):GetSortedAsync(false,limit):GetCurrentPage()
  end)
  if not ok then
   return {period=period,rows=if previous.period == period then previous.rows else {},status="Unavailable"}
  end
  for _, row in ipairs(result) do
   local id = tonumber(row.key)
   if id then table.insert(rows,{id=id,name="",points=row.value}) end
  end
 end
 return {period=period,rows=rows,status="Ready"}
end

local function resolveNames(charts: {Chart})
 local missing: {number} = {}
 local lookup: {[number]: boolean} = {}
 for _, chart in ipairs(charts) do
  if chart.status ~= "Ready" then continue end
  for _, row in ipairs(chart.rows) do
   local player = Players:GetPlayerByUserId(row.id)
   if player then names[row.id] = player.Name end
   if not names[row.id] and not lookup[row.id] and row.id > 0 then
    lookup[row.id] = true
    table.insert(missing,row.id)
   end
  end
 end
 if #missing > 0 then
  local ok, users = pcall(function() return UserService:GetUserInfosByUserIdsAsync(missing) end)
  if ok then
   for _, user in ipairs(users) do names[user.Id] = user.Username end
  end
 end
 for _, chart in ipairs(charts) do
  if chart.status ~= "Ready" then continue end
  for _, row in ipairs(chart.rows) do row.name = names[row.id] or ("Player "..tostring(row.id)) end
 end
end

local function requestRefresh()
 refreshRequested = true
end

local function start(onChange: () -> ())
 changed = onChange
 task.spawn(function()
  while true do
   for key, write in pairs(pending) do
    if activeWrites >= Protocol.capacity then break end
    if not write.running and write.retryAt <= os.clock() then
     write.running = true
     activeWrites += 1
     task.spawn(save,key,write)
    end
   end
   task.wait(.5)
  end
 end)
 task.spawn(function()
  while true do
   local day, month = periods(os.time())
   if day ~= daily.period or month ~= monthly.period or os.clock() >= readAfter then
    refreshRequested = true
   end
   if refreshRequested and os.clock() >= nextReadAllowed then
    refreshRequested = false
    local nextDay = read(day,"day_"..day,daily)
    local nextMonth = read(month,"month_"..month,monthly)
    resolveNames({nextDay,nextMonth})
    daily,monthly = nextDay,nextMonth
    readAfter = os.clock() + 25
    nextReadAllowed = os.clock() + 2
    publish()
    -- Cumulative targets stay available for retries and for new matches in this period.
    local currentDay, currentMonth = periods(os.time())
    for scope in pairs(localTotals) do
     if scope ~= "day_"..currentDay and scope ~= "month_"..currentMonth then localTotals[scope] = nil end
    end
   end
   task.wait(.5)
  end
 end)
 if not studio then
  game:BindToClose(function()
   local untilTime = os.clock()+24
   while next(pending) and os.clock() < untilTime do task.wait(.25) end
  end)
 end
end

return table.freeze({start=start,submit=submit,snapshot=snapshot,requestRefresh=requestRefresh})
