--!strict
local function hex(value: string): Color3
 return Color3.fromHex(value)
end
local Theme = table.freeze({
 bg=hex("111B20"), panel=hex("18272C"), edge=hex("345055"), scene=hex("203A3D"),
 button=hex("2A4042"), cream=hex("F7EDDC"), muted=hex("AFBFBA"), faint=hex("879F9C"),
 gold=hex("FAC773"), goldDark=hex("3B2D1D"), mint=hex("82E0BE"), red=hex("FF9A83"), point=hex("FF7281"),
})
local symptomGold, symptomMint, symptomUrgent = hex("FFE3AA"), hex("BAF4E9"), hex("59162D")
local textScale = 2
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
 item.Text, item.TextSize, item.TextColor3, item.Font = text,size*textScale,color,face or font
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
 item.BorderSizePixel, item.Font, item.TextSize = 0, bold, 14*textScale
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
 local seal = panel(header,0,0,58,58,Theme.gold,10)
 center(label(seal,"针",0,0,58,58,23,Theme.bg,bold))
 local title = label(header,"ACU-MASTER",52,-1,228,29,27,Theme.cream,bold)
 local subtitle = label(header,"神针手  /  MERIDIAN CLINIC",53,29,260,17,11,Theme.mint,mono)
 local help = button(header,"Help",0,1,112,38)
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
 local figure = button(scene,"Show blocks",0,0,226,46)
 figure.Visible = false
 local back = button(scene,"Back",0,0,64,40)
 local place = button(scene,"Select region",0,0,132,40,true)
 local flash = panel(scene,2,2,0,0,Theme.red,11)
 flash.Size, flash.BackgroundTransparency = UDim2.new(1,-4,1,-4),1
 local flashStroke = border(flash,Theme.red,6)
 flashStroke.Transparency = 1
 local feedback = label(scene,"",0,0,0,29,13,Theme.cream,bold)
 center(feedback)

 local side = Instance.new("ScrollingFrame")
 side.BackgroundColor3, side.BorderSizePixel, side.ScrollBarThickness = Theme.panel,0,5
 side.ScrollBarImageColor3 = Theme.faint
 side.CanvasSize, side.AutomaticCanvasSize = UDim2.fromOffset(0,0),Enum.AutomaticSize.Y
 side.ScrollingDirection, side.Parent = Enum.ScrollingDirection.Y,root
 corner(side,12)
 border(side,Theme.edge)
 local inset = Instance.new("UIPadding")
 inset.PaddingTop, inset.PaddingBottom = UDim.new(0,12), UDim.new(0,14)
 inset.PaddingLeft, inset.PaddingRight = UDim.new(0,14), UDim.new(0,18)
 inset.Parent = side
 local flow = Instance.new("UIListLayout")
 flow.Padding, flow.SortOrder, flow.Parent = UDim.new(0,9),Enum.SortOrder.LayoutOrder,side
 local function stack(item: GuiObject, order: number, height: number)
  item.Size, item.LayoutOrder = UDim2.new(1,0,0,height),order
 end
 local symptom = panel(side,0,0,0,0,symptomGold,9)
 symptom.Visible,symptom.AutomaticSize = false,Enum.AutomaticSize.Y
 stack(symptom,0,0)
 local symptomEdge = border(symptom,Theme.gold,2)
 local symptomInset = Instance.new("UIPadding")
 symptomInset.PaddingTop,symptomInset.PaddingBottom = UDim.new(0,11),UDim.new(0,15)
 symptomInset.PaddingLeft,symptomInset.PaddingRight = UDim.new(0,15),UDim.new(0,15)
 symptomInset.Parent = symptom
 local symptomFlow = Instance.new("UIListLayout")
 symptomFlow.Padding,symptomFlow.SortOrder,symptomFlow.Parent = UDim.new(0,6),Enum.SortOrder.LayoutOrder,symptom
 local symptomLabel = label(symptom,"",0,0,0,0,11,Theme.bg,mono)
 stack(symptomLabel,1,26)
 local symptomText = label(symptom,"",0,0,0,0,18,Theme.bg,bold)
 wrap(symptomText)
 stack(symptomText,2,0)
 symptomText.AutomaticSize = Enum.AutomaticSize.Y
 local overline = label(side,"CASE NOTES",0,0,0,0,11,Theme.gold,mono)
 stack(overline,1,30)
 local heading = label(side,"",0,0,0,0,26,Theme.cream,bold)
 wrap(heading)
 stack(heading,2,0)
 heading.AutomaticSize = Enum.AutomaticSize.Y
 local controls = panel(side,0,0,0,56,Theme.panel)
 stack(controls,3,56)
 local action = button(controls,"Solo practice",0,0,0,56,true)
 local aux = button(controls,"Leave queue",0,0,0,56)
 local description = label(side,"",0,0,0,0,14,Theme.muted)
 wrap(description)
 stack(description,4,0)
 description.AutomaticSize = Enum.AutomaticSize.Y
 local separator = panel(side,0,0,0,1,Theme.edge)
 stack(separator,5,1)
 local listHeading = label(side,"CLINIC ROSTER",0,0,0,0,11,Theme.mint,mono)
 stack(listHeading,6,31)
 local list = panel(side,0,0,0,0,Theme.panel)
 stack(list,7,0)
 list.AutomaticSize = Enum.AutomaticSize.Y
 local stacking = Instance.new("UIListLayout")
 stacking.Padding, stacking.SortOrder, stacking.Parent = UDim.new(0,7),Enum.SortOrder.LayoutOrder,list
 local footer = label(root,"Fictional clinic simulation",0,0,0,28,11,Theme.faint)
 center(footer)

 local shade = panel(root,0,0,0,0,Theme.bg)
 shade.ZIndex, shade.Visible, shade.Active = 15,false,true
 shade.BackgroundTransparency = .15
 local modal = panel(shade,0,0,0,0,Theme.panel,12)
 modal.AnchorPoint, modal.Position = Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 modal.ZIndex, modal.Active, modal.SelectionGroup = 16,true,true
 local stop = Enum.SelectionBehavior.Stop
 modal.SelectionBehaviorUp, modal.SelectionBehaviorDown = stop, stop
 modal.SelectionBehaviorLeft, modal.SelectionBehaviorRight = stop, stop
 border(modal,Theme.edge)
 local helpStep = label(modal,"",20,12,0,31,11,Theme.mint,mono)
 local modalHead = label(modal,"",20,48,0,70,27,Theme.cream,bold)
 local helpScroll = Instance.new("ScrollingFrame")
 helpScroll.BackgroundTransparency,helpScroll.BorderSizePixel,helpScroll.ScrollBarThickness = 1,0,5
 helpScroll.CanvasSize,helpScroll.AutomaticCanvasSize = UDim2.fromOffset(0,0),Enum.AutomaticSize.Y
 helpScroll.ScrollingDirection,helpScroll.ZIndex,helpScroll.Parent = Enum.ScrollingDirection.Y,17,modal
 local instructions = label(helpScroll,"",0,0,0,0,15,Theme.cream)
 wrap(instructions)
 instructions.Size, instructions.AutomaticSize = UDim2.new(1,-12,0,0),Enum.AutomaticSize.Y
 local helpClose = button(modal,"Skip",20,0,0,58)
 local helpBack = button(modal,"Back",20,0,0,58)
 local helpNext = button(modal,"Next",20,0,0,58,true)
 helpStep.ZIndex,modalHead.ZIndex,instructions.ZIndex = 17,17,17
 helpClose.ZIndex,helpBack.ZIndex,helpNext.ZIndex = 17,17,17
 helpClose.NextSelectionRight = helpBack
 helpBack.NextSelectionLeft,helpBack.NextSelectionRight = helpClose,helpNext
 helpNext.NextSelectionLeft = helpBack

 return {
  gui=gui,root=root,scale=scale,header=header,seal=seal,title=title,subtitle=subtitle,help=help,motion=motion,
  strip=strip,phase=phase,detail=detail,timer=timer,track=track,bar=bar,scene=scene,viewport=viewport,
  grid=grid,scan=scan,sceneTitle=sceneTitle,viewTitle=viewTitle,markerLayer=markerLayer,reticle=reticle,
  reticleStroke=reticleStroke,dot=dot,halo=halo,hitStroke=hitStroke,flashStroke=flashStroke,cameraControls=cameraControls,
  previous=previous,nextView=nextView,direction=direction,figure=figure,back=back,place=place,feedback=feedback,
  symptom=symptom,symptomEdge=symptomEdge,symptomLabel=symptomLabel,symptomText=symptomText,
  side=side,overline=overline,heading=heading,description=description,action=action,aux=aux,controls=controls,
  separator=separator,listHeading=listHeading,list=list,footer=footer,shade=shade,modal=modal,modalHead=modalHead,helpStep=helpStep,helpScroll=helpScroll,
  instructions=instructions,helpClose=helpClose,helpBack=helpBack,helpNext=helpNext,
 }
end

export type UI = typeof(build(nil :: any))

local function paintSymptom(ui: UI, step: number, urgent: boolean)
 local fill = if urgent then symptomUrgent elseif step % 2 == 0 then symptomMint else symptomGold
 if ui.symptom.BackgroundColor3 == fill then return end
 local text = if urgent then Theme.cream else Theme.bg
 ui.symptom.BackgroundColor3, ui.symptomEdge.Color = fill, if urgent then Theme.red elseif step % 2 == 0 then Theme.mint else Theme.gold
 ui.symptomLabel.TextColor3, ui.symptomText.TextColor3 = text, text
end

local function setSymptom(ui: UI, clue: string?, step: number, count: number)
 ui.symptom.Visible = clue ~= nil and clue ~= ""
 if not ui.symptom.Visible then return end
 ui.symptomLabel.Text = if count > 1 then string.format("SYMPTOM %d OF %d",step,count) else "CURRENT SYMPTOM"
 ui.symptomText.Text = clue or ""
end

local function layout(ui: UI, size: Vector2): boolean
 local compact = size.X/size.Y < 1.30
 local w, h = if compact then 430 else 1192, if compact then 811 else 728
 local availableWidth, availableHeight = size.X - 20, size.Y - 59
 ui.scale.Scale,ui.root.Size = math.max(.2,math.min(availableWidth/w,availableHeight/h)),UDim2.fromOffset(w,h)
 ui.root.Position = UDim2.new(.5,0,.5,19)
 local top = if compact then 119 else 78
 local sy = top+70
 local sw, sh = if compact then w else 698, if compact then 345 else 536
 local px, py = if compact then 0 else sw+14, if compact then sy+sh+10 else sy
 local pw, ph = if compact then w else w-px, if compact then h-py-39 else sh

 position(ui.header,0,0,w,top-8)
 position(ui.title,68,0,350,56)
 position(ui.subtitle,70,if compact then 55 else 51,if compact then 350 else 440,27)
 ui.title.TextSize = (if compact then 22 else 27)*textScale
 ui.subtitle.TextSize = (if compact then 9 else 11)*textScale
 ui.subtitle.Text = if compact then "神针手" else "神针手  /  MERIDIAN CLINIC"
 position(ui.help,w-95,if compact then 65 else 6,95,46)
 position(ui.motion,w-306,if compact then 65 else 6,201,46)
 position(ui.strip,0,top,w,62)
 position(ui.phase,12,0,if compact then 235 else 360,55)
 position(ui.detail,if compact then 230 else 386,0,if compact then 122 else 430,55)
 position(ui.timer,w-72,0,60,55)
 position(ui.track,10,55,w-20,4)

 position(ui.scene,0,sy,sw,sh)
 position(ui.viewport,0,0,sw,sh-90)
 position(ui.grid,0,math.floor((sh-90)/2),sw,1)
 position(ui.scan,math.floor(sw/2),35,1,sh-130)
 position(ui.sceneTitle,12,6,232,30)
 position(ui.viewTitle,sw-200,6,188,30)
 position(ui.feedback,12,sh-106,sw-24,48)
 position(ui.cameraControls,12,sh-56,if compact then 160 else 212,46)
 position(ui.previous,0,0,if compact then 36 else 56,46)
 position(ui.direction,if compact then 36 else 56,0,if compact then 88 else 100,46)
 position(ui.nextView,if compact then 124 else 156,0,if compact then 36 else 56,46)
 position(ui.place,sw-(if compact then 139 else 211),sh-56,if compact then 127 else 199,46)
 position(ui.figure,sw-254,sh-56,242,46)
 position(ui.back,sw-(if compact then 225 else 301),sh-56,78,46)

 position(ui.side,px,py,pw,ph)
 ui.symptomText.TextSize = (if compact then 16 else 18)*textScale
 ui.heading.TextSize = (if compact then 22 else 26)*textScale
 ui.description.TextSize = (if compact then 13 else 15)*textScale
 position(ui.footer,0,h-34,w,32)
 position(ui.shade,0,0,w,h)
 local mw, mh = if compact then w-14 else 650, if compact then 675 else 632
 ui.modal.Size = UDim2.fromOffset(mw,mh)
 position(ui.helpStep,20,14,mw-40,32)
 position(ui.modalHead,20,51,mw-40,68)
 position(ui.helpScroll,20,132,mw-40,mh-218)
 local buttonWidth = math.floor((mw-60)/3)
 position(ui.helpClose,20,mh-70,buttonWidth,56)
 position(ui.helpBack,30+buttonWidth,mh-70,buttonWidth,56)
 position(ui.helpNext,40+buttonWidth*2,mh-70,buttonWidth,56)
 return compact
end

return table.freeze({theme=Theme,build=build,layout=layout,label=label,panel=panel,button=button,
 position=position,border=border,bold=bold,mono=mono,textScale=textScale,
 setSymptom=setSymptom,paintSymptom=paintSymptom})
