--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Protocol)
local ClinicUI = require(script.Parent.ClinicUI)
local T = ClinicUI.theme

local function heading(parent: Instance, content: string, size: number, tint: Color3): TextLabel
 return ClinicUI.label(parent,content,0,0,0,0,size,tint,ClinicUI.bold)
end

local function makeChart(parent: Frame, title: string)
 local frame = ClinicUI.panel(parent,0,0,0,0,T.panel,10)
 frame.ZIndex = 3
 ClinicUI.border(frame,T.edge)
 local name = heading(frame,title,13,T.mint)
 local period = ClinicUI.label(frame,"",0,0,0,0,10,T.muted,ClinicUI.mono)
 local empty = ClinicUI.label(frame,"Loading rankings…",0,0,0,0,11,T.muted)
 empty.TextWrapped,empty.TextTruncate = true,Enum.TextTruncate.None
 local rows = {}
 for i = 1, 5 do
  local item = ClinicUI.panel(frame,0,0,0,0,if i == 1 then T.button else T.panel,5)
  local rank = ClinicUI.label(item,tostring(i),0,0,0,0,10,if i == 1 then T.gold else T.muted,ClinicUI.mono)
  local player = ClinicUI.label(item,"",0,0,0,0,11,T.cream)
  local points = heading(item,"",11,T.gold)
  points.TextXAlignment = Enum.TextXAlignment.Right
  item.Visible = false
  table.insert(rows,{item=item,rank=rank,player=player,points=points})
 end
 return {frame=frame,name=name,period=period,rows=rows,empty=empty}
end

local function build(parent: Frame)
 local board = ClinicUI.panel(parent,0,0,0,0,T.bg,12)
 board.Size,board.Visible,board.ZIndex = UDim2.fromScale(1,1),false,3
 local daily = makeChart(board,"Daily")
 local monthly = makeChart(board,"Monthly")
 local sparks = ClinicUI.panel(board,0,0,0,0,T.bg)
 sparks.Size,sparks.BackgroundTransparency,sparks.ZIndex = UDim2.fromScale(1,1),1,2
 local caption = ClinicUI.label(board,"",0,0,0,0,11,T.mint,ClinicUI.mono)
 local title = heading(board,"",20,T.cream)
 local status = ClinicUI.label(board,"",0,0,0,0,10,T.muted)
 caption.TextXAlignment,title.TextXAlignment,status.TextXAlignment = Enum.TextXAlignment.Center,Enum.TextXAlignment.Center,Enum.TextXAlignment.Center
 caption.ZIndex,title.ZIndex,status.ZIndex = 4,4,4
 return {board=board,daily=daily,monthly=monthly,caption=caption,title=title,status=status,sparks=sparks}
end

type View = typeof(build(nil :: any))
type ChartUI = typeof(makeChart(nil :: any,""))

local function layoutChart(chart: ChartUI, x: number, y: number, w: number, h: number)
 local p = ClinicUI.position
 p(chart.frame,x,y,w,h)
 p(chart.name,10,4,w-20,33)
 p(chart.period,10,34,w-20,25)
 p(chart.empty,10,64,w-20,h-68)
 local rowHeight = math.floor((h-67)/#chart.rows)
 for i, row in ipairs(chart.rows) do
  p(row.item,6,61+(i-1)*rowHeight,w-12,rowHeight)
  p(row.rank,4,0,20,rowHeight)
  p(row.player,25,0,w-96,rowHeight)
  p(row.points,w-72,0,54,rowHeight)
 end
end

local function layout(view: View, scene: Frame)
 local w,h = scene.Size.X.Offset,scene.Size.Y.Offset
 local p = ClinicUI.position
 p(view.caption,12,5,w-24,32)
 p(view.title,12,35,w-24,51)
 local width = math.floor((w-34)/2)
 layoutChart(view.daily,11,91,width,h-128)
 layoutChart(view.monthly,w-11-width,91,width,h-128)
 p(view.status,9,h-32,w-18,28)
end

local function showChart(ui: ChartUI, chart: Protocol.Chart?)
 local rows = if chart then chart.rows else {}
 local status = if chart then chart.status else "Loading"
 ui.period.Text = if chart then chart.period else ""
 ui.empty.Text = if status == "Loading" then "Loading rankings…"
  elseif status == "Unavailable" then "Rankings unavailable"
  else "No points yet"
 ui.empty.Visible = #rows == 0
 for i, row in ipairs(ui.rows) do
  local record = rows[i]
  row.item.Visible = record ~= nil
  if record then
   row.player.Text = record.name
   row.points.Text = tostring(record.points)
  end
 end
end

local function render(view: View, snapshot: Protocol.Snapshot)
 local phase = snapshot.phase
 view.board.Visible = not snapshot.practice and (phase == "Lobby" or phase == "Intermission" or phase == "Victory")
 if not view.board.Visible then return end
 local data = snapshot.rankings
 view.caption.Text = if phase == "Victory" then (if snapshot.winner then "MATCH WINNER" else "MATCH COMPLETE") else "MULTIPLAYER RANKINGS"
 view.title.Text = if phase == "Victory" then (snapshot.winner or "No winner") else "Clinic leaders"
 local unavailable = data and (data.daily.status == "Unavailable" or data.monthly.status == "Unavailable")
 view.status.Text = if not data then "" elseif data.studio then "Studio rankings · This session"
  elseif data.saving then "Saving results…"
  elseif unavailable then "Rankings may be out of date"
  else "Ranking periods use Hong Kong time"
 showChart(view.daily,if data then data.daily else nil)
 showChart(view.monthly,if data then data.monthly else nil)
end

return table.freeze({build=build,layout=layout,render=render})
