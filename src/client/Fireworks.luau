--!strict
local TweenService = game:GetService("TweenService")

local colors = {
 Color3.fromHex("FAC773"), Color3.fromHex("82E0BE"), Color3.fromHex("F49A84"),
 Color3.fromHex("B7A6FA"), Color3.fromHex("F7EDDC"),
}

local function spark(parent: Frame, tint: Color3, size: number): Frame
 local dot = Instance.new("Frame")
 dot.Size, dot.BackgroundColor3 = UDim2.fromOffset(size,size),tint
 dot.BorderSizePixel, dot.AnchorPoint = 0,Vector2.new(.5,.5)
 dot.Parent = parent
 local rounded = Instance.new("UICorner")
 rounded.CornerRadius,rounded.Parent = UDim.new(.5,0),dot
 return dot
end

local function play(layer: Frame, reduced: boolean)
 local effect = Instance.new("Frame")
 effect.Name, effect.Size, effect.BackgroundTransparency = "Victory fireworks",UDim2.fromScale(1,1),1
 effect.Parent = layer
 local random = Random.new()
 local origins = {Vector2.new(.18,.099),Vector2.new(.78,.108),Vector2.new(.42,.16),Vector2.new(.92,.16)}
 for burst, center in ipairs(origins) do
  task.delay(if reduced then 0 else (burst-1)*.58,function()
   if not effect.Parent then return end
   local tint = colors[burst]
   local count = if reduced then 8 else 20
   for i = 1,count do
    local angle = i*math.pi*2/count
    local distance = random:NextNumber(if reduced then 14 else 31,if reduced then 34 else 95)
    local x,y = math.cos(angle)*distance,math.sin(angle)*distance
    local dot = spark(effect,if i%5 == 0 then colors[5] else tint,random:NextInteger(3,7))
    if reduced then
     dot.Position, dot.BackgroundTransparency = UDim2.new(center.X,x,center.Y,y),.25
    else
     dot.Position = UDim2.fromScale(center.X,center.Y)
     TweenService:Create(dot,TweenInfo.new(random:NextNumber(.65,1.3),Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
      Position=UDim2.new(center.X,x,center.Y,y+13),
      BackgroundTransparency=1,
     }):Play()
    end
   end
  end)
 end
 if not reduced then task.delay(3.5,function() effect:Destroy() end) end
end

return table.freeze({play=play})
