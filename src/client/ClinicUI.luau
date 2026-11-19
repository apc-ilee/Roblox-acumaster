--!strict
local function hex(value: string): Color3
 return Color3.fromHex(value)
end
local Theme = table.freeze({
 bg=hex("111B20"), panel=hex("18272C"), edge=hex("345055"), scene=hex("203A3D"),
 button=hex("2A4042"), cream=hex("F7EDDC"), muted=hex("AFBFBA"), faint=hex("879F9C"),
 gold=hex("FAC773"), goldDark=hex("3B2D1D"), mint=hex("82E0BE"), red=hex("FF9A83"),
})
local font = Enum.Font.Gotham
local bold = Enum.Font.GothamBold
local mono = Enum.Font.RobotoMono

local function position(item: GuiObject, x: number, y: number, w: number, h: number)
 item.Position, item.Size = UDim2.fromOffset(x,y), UDim2.fromOffset(w,h)
end
local function corner(item: GuiObject, radius: number)
 local rounded = Instance.new("UICorner")
 rounded.CornerRadius, rounded.Parent = UDim.new(0,radius), item
end
local function border(item: GuiObject, col: Color3, thickness: number?): UIStroke
 local stroke = Instance.new("UIStroke")
 stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 stroke.Color, stroke.Thickness, stroke.Parent = col, thickness or 1, item
 return stroke
end
local function panel(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, radius: number?): Frame
 local item = Instance.new("Frame")
 item.BackgroundColor3, item.BorderSizePixel = color, 0
 position(item,x,y,w,h)
 if radius then corner(item,radius) end
 item.Parent = parent
 return item
end
local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number, size: number, color: Color3, face: Enum.Font?): TextLabel
 local item = Instance.new("TextLabel")
 item.BackgroundTransparency, item.BorderSizePixel = 1, 0
 item.Text, item.TextSize, item.TextColor3, item.Font = text,size,color,face or font
 item.TextXAlignment = Enum.TextXAlignment.Left
 item.TextTruncate = Enum.TextTruncate.AtEnd
 position(item,x,y,w,h)
 item.Parent = parent
 return item
end
local function wrap(item: TextLabel)
 item.TextTruncate, item.TextWrapped = Enum.TextTruncate.None, true
 item.TextYAlignment = Enum.TextYAlignment.Top
end
local function button(parent: Instance, text: string, x: number, y: number, w: number, h: number, accent: boolean?): TextButton
 local item = Instance.new("TextButton")
 item.Name, item.Text = text,text
 item.BackgroundColor3 = if accent then Theme.gold else Theme.button
 item.TextColor3 = if accent then Theme.bg else Theme.cream
 item.BorderSizePixel, item.Font, item.TextSize = 0, bold, 14
 item.AutoButtonColor = true
 position(item,x,y,w,h)
 corner(item,7)
 item.Parent = parent
 return item
end
local function center(item: TextLabel)
 item.TextXAlignment = Enum.TextXAlignment.Center
end

local function build(parent: PlayerGui)
 local gui = Instance.new("ScreenGui")
 gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "AcuMaster",false,true
 gui.ScreenInsets, gui.ZIndexBehavior, gui.DisplayOrder = Enum.ScreenInsets.None,Enum.ZIndexBehavior.Sibling,5
 gui.Parent = parent
 panel(gui,0,0,0,0,Theme.bg).Size = UDim2.fromScale(1,1)
 local root = panel(gui,0,0,0,0,Theme.bg)
 root.AnchorPoint, root.Position = Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 local scale = Instance.new("UIScale")
 scale.Parent = root

 local header = panel(root,0,0,0,0,Theme.bg)
 local seal = panel(header,0,0,40,40,Theme.gold,10)
 center(label(seal,"针",0,0,40,40,23,Theme.bg,bold))
 local title = label(header,"ACU-MASTER",52,-1,228,29,27,Theme.cream,bold)
 local subtitle = label(header,"神针手  /  MERIDIAN CLINIC",53,29,260,17,11,Theme.mint,mono)
 local help = button(header,"How to play",0,1,112,38)
 local motion = button(header,"Motion: Full",0,1,115,38)

 local strip = panel(root,0,0,0,52,Theme.panel,9)
 border(strip,Theme.edge)
 local phase = label(strip,"LOBBY",16,5,185,40,19,Theme.cream,bold)
 local detail = label(strip,"",0,5,240,40,12,Theme.mint,mono)
 local timer = label(strip,"—",0,4,89,40,25,Theme.gold,mono)
 timer.TextXAlignment = Enum.TextXAlignment.Right
 local track = panel(strip,0,47,0,4,Theme.button,2)
 local bar = panel(track,0,0,0,4,Theme.gold,2)
 bar.Size = UDim2.fromScale(1,1)

 local scene = panel(root,0,0,0,0,Theme.scene,12)
 scene.ClipsDescendants = true
 local gradient = Instance.new("UIGradient")
 gradient.Color = ColorSequence.new(hex("284A49"),hex("192D33"))
 gradient.Rotation, gradient.Parent = 90,scene
 border(scene,Theme.edge)
 local viewport = Instance.new("ViewportFrame")
 viewport.Name, viewport.BackgroundTransparency = "PatientViewport",1
 viewport.Parent = scene
 local grid = panel(scene,0,0,1,1,hex("42615D"))
 grid.BackgroundTransparency = .4
 local scan = panel(scene,0,0,1,1,hex("42615D"))
 scan.BackgroundTransparency = .4
 local sceneTitle = label(scene,"PATIENT VIEW",14,10,250,23,11,Theme.mint,mono)
 local viewTitle = label(scene,"FRONT",0,10,128,23,11,Theme.muted,mono)
 viewTitle.TextXAlignment = Enum.TextXAlignment.Right
 local markerLayer = panel(scene,0,0,0,0,Theme.scene)
 markerLayer.BackgroundTransparency = 1
 markerLayer.Size = UDim2.fromScale(1,1)
 local reticle = panel(scene,0,0,31,31,Theme.scene,20)
 reticle.AnchorPoint, reticle.BackgroundTransparency, reticle.Visible = Vector2.new(.5,.5),1,false
 local reticleStroke = border(reticle,Theme.cream,1.5)
 local dot = panel(reticle,13,13,5,5,Theme.gold,3)
 local halo = panel(scene,0,0,44,44,Theme.scene,26)
 halo.AnchorPoint, halo.BackgroundTransparency, halo.Visible = Vector2.new(.5,.5),1,false
 local hitStroke = border(halo,Theme.mint,2)
 local cameraControls = panel(scene,0,0,0,0,Theme.panel,8)
 local previous = button(cameraControls,"Q  ‹",0,0,44,40)
 local nextView = button(cameraControls,"›  E",0,0,44,40)
 local direction = label(cameraControls,"FRONT",0,0,70,40,12,Theme.cream,mono)
 center(direction)
 local back = button(scene,"Back",0,0,64,40)
 local place = button(scene,"Select region",0,0,132,40,true)
 local flash = panel(scene,2,2,0,0,Theme.red,11)
 flash.Size, flash.BackgroundTransparency = UDim2.new(1,-4,1,-4),1
 local flashStroke = border(flash,Theme.red,6)
 flashStroke.Transparency = 1
 local feedback = label(scene,"",0,0,0,29,13,Theme.cream,bold)
 center(feedback)

 local side = panel(root,0,0,0,0,Theme.panel,12)
 border(side,Theme.edge)
 local overline = label(side,"CASE NOTES",14,12,260,21,11,Theme.gold,mono)
 local heading = label(side,"",14,37,0,34,26,Theme.cream,bold)
 local description = label(side,"",14,79,0,88,14,Theme.muted)
 wrap(description)
 local action = button(side,"Solo practice",14,0,0,40,true)
 local aux = button(side,"Leave queue",14,0,0,40)
 local separator = panel(side,14,0,0,1,Theme.edge)
 local listHeading = label(side,"CLINIC ROSTER",14,0,0,23,11,Theme.mint,mono)
 local list = Instance.new("ScrollingFrame")
 list.BackgroundTransparency, list.BorderSizePixel, list.ScrollBarThickness = 1,0,4
 list.ScrollBarImageColor3 = Theme.faint
 list.CanvasSize, list.AutomaticCanvasSize = UDim2.fromOffset(0,0),Enum.AutomaticSize.Y
 list.ScrollingDirection, list.Parent = Enum.ScrollingDirection.Y,side
 local stacking = Instance.new("UIListLayout")
 stacking.Padding, stacking.SortOrder, stacking.Parent = UDim.new(0,5),Enum.SortOrder.LayoutOrder,list
 local footer = label(root,"Fictional clinic simulation  •  Game clues are inspired by traditional acupoint lore.",0,0,0,18,11,Theme.faint)
 center(footer)

 local shade = button(root,"",0,0,0,0)
 shade.ZIndex, shade.Visible, shade.AutoButtonColor = 15,false,false
 shade.BackgroundColor3, shade.BackgroundTransparency = Theme.bg,.15
 local modal = panel(shade,0,0,390,412,Theme.panel,12)
 modal.AnchorPoint, modal.Position = Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 modal.ZIndex, modal.Active = 16,true
 border(modal,Theme.edge)
 local modalHead = label(modal,"How to play",20,16,294,41,27,Theme.cream,bold)
 modalHead.ZIndex = 17
 local instructions = label(modal,
  "1  STUDY\nRotate the mannequin and remember which clue goes with each marker.\n\n2  DIAGNOSE\nRead the patient’s clue, then select a body region.\n\n3  PLACE\nRotate to the right view and aim at the point. A miss costs one Qi. The fastest valid run gains two.\n\nMouse or touch to aim. Q/E or LB/RB rotates.\nGamepad left stick aims, A confirms, B goes back.",
  20,72,350,266,15,Theme.cream)
 wrap(instructions)
 instructions.ZIndex = 17
 local close = button(modal,"Back to clinic",20,352,350,43,true)
 close.ZIndex = 17

 return {
  gui=gui,root=root,scale=scale,header=header,seal=seal,title=title,subtitle=subtitle,help=help,motion=motion,
  strip=strip,phase=phase,detail=detail,timer=timer,track=track,bar=bar,scene=scene,viewport=viewport,
  grid=grid,scan=scan,sceneTitle=sceneTitle,viewTitle=viewTitle,markerLayer=markerLayer,reticle=reticle,
  reticleStroke=reticleStroke,dot=dot,halo=halo,hitStroke=hitStroke,flashStroke=flashStroke,cameraControls=cameraControls,
  previous=previous,nextView=nextView,direction=direction,back=back,place=place,feedback=feedback,
  side=side,overline=overline,heading=heading,description=description,action=action,aux=aux,
  separator=separator,listHeading=listHeading,list=list,footer=footer,shade=shade,close=close,
 }
end

export type UI = typeof(build(nil :: any))

local function layout(ui: UI, size: Vector2, hasButtons: boolean): boolean
 local compact = size.X/size.Y < 1.30
 local w, h = if compact then 430 else 1192, if compact then 811 else 728
 local availableWidth, availableHeight = size.X - 20, size.Y - 59
 local s = math.max(.2,math.min(availableWidth/w,availableHeight/h))
 ui.scale.Scale,ui.root.Size = s,UDim2.fromOffset(w,h)
 ui.root.Position = UDim2.new(.5,0,.5,19)
 local top = if compact then 42 else 50
 local sx, sy, sw, sh = 0, top+65, if compact then w else 777, if compact then 374 else 534
 local px, py, pw, ph = if compact then 0 else sw+15, if compact then sy+sh+11 else sy, if compact then w else w-sw-15, if compact then 280 else sh
 position(ui.header,0,0,w,46)
 position(ui.help,w-102,1,102,38)
 position(ui.motion,w-211,1,102,38)
 ui.title.TextSize = if compact then 22 else 27
 ui.subtitle.TextSize = if compact then 9 else 11
 position(ui.strip,0,top,w,52)
 position(ui.phase,14,5,181,40)
 position(ui.detail,if compact then 192 else 213,5,if compact then 155 else 380,40)
 position(ui.timer,w-85,3,70,43)
 position(ui.track,9,47,w-18,3)
 position(ui.scene,sx,sy,sw,sh)
 position(ui.viewport,0,0,sw,sh-67)
 position(ui.grid,0,if compact then 132 else 200,sw,1)
 position(ui.scan,math.floor(sw/2),33,1,sh-137)
 position(ui.viewTitle,sw-142,10,128,23)
 position(ui.feedback,16,sh-77,sw-32,28)
 position(ui.cameraControls,14,sh-53,if compact then 156 else 178,40)
 position(ui.direction,44,0,if compact then 69 else 90,40)
 position(ui.nextView,if compact then 112 else 134,0,44,40)
 position(ui.place,sw-153,sh-53,139,40)
 position(ui.back,sw-226,sh-53,65,40)

 position(ui.side,px,py,pw,ph)
 position(ui.overline,14,if compact then 7 else 12,pw-28,19)
 position(ui.heading,14,if compact then 25 else 35,pw-28,31)
 ui.heading.TextSize = if compact then 22 else 26
 position(ui.description,14,if compact then 61 else 82,pw-28,if compact then 60 else 84)
 ui.description.TextSize = if compact then 13 else 15
 local btnY = if compact then 115 else 174
 position(ui.action,14,btnY,math.floor((pw-36)/2),37)
 position(ui.aux,math.floor((pw-36)/2)+22,btnY,math.floor((pw-36)/2),37)
 local ruleY = if compact then (if hasButtons then 161 else 117) else (if hasButtons then 226 else 169)
 position(ui.separator,14,ruleY,pw-28,1)
 position(ui.listHeading,14,ruleY+6,pw-28,23)
 position(ui.list,14,ruleY+34,pw-28,ph-ruleY-44)
 position(ui.footer,0,h-25,w,18)
 position(ui.shade,0,0,w,h)
 return compact
end

return table.freeze({theme=Theme,build=build,layout=layout,label=label,panel=panel,button=button,
 position=position,border=border,bold=bold,mono=mono})
