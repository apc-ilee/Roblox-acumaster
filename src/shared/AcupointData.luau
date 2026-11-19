--!strict
export type Point = {
 id: string, cn: string, name: string, region: string, view: string, part: string,
 offset: Vector3, radius: number, location: string, clue: string, dialogue: string,
}

local points: {Point} = {}
local byId: {[string]: Point} = {}

local function add(id: string, cn: string, name: string, region: string, view: string, part: string,
 offset: Vector3, radius: number, location: string, clue: string, dialogue: string)
 local point = table.freeze({
  id = id, cn = cn, name = name, region = region, view = view, part = part,
  offset = offset, radius = radius, location = location, clue = clue, dialogue = dialogue,
 })
 table.insert(points, point)
 byId[id] = point
end

add("01_TaiYang", "太阳穴", "Tai Yang", "Head", "Front", "Head", Vector3.new(0.55, 0.15, -0.15), 0.45,
 "Temple", "Temple pressure", "My temples feel tight after a midnight study marathon.")
add("02_BaiHui", "百会穴", "Bai Hui", "Head", "Top", "Head", Vector3.new(0.0, 0.85, 0.0), 0.40,
 "Crown", "Heavy head", "The exam clock started and my head felt like a spinning top.")
add("03_YinTang", "印堂穴", "Yin Tang", "Head", "Front", "Head", Vector3.new(0.0, 0.25, -0.55), 0.40,
 "Between the brows", "Stuffy nose", "I barely slept. My nose felt like a traffic jam.")
add("04_FengChi", "风池穴", "Feng Chi", "Head", "Back", "Head", Vector3.new(0.35, -0.4, 0.45), 0.50,
 "Base of the skull", "Stiff neck", "A whole day of gaming turned my neck into a plank.")
add("05_JiaChe", "颊车穴", "Jia Che", "Head", "Front", "Head", Vector3.new(0.45, -0.35, -0.2), 0.45,
 "Side of the jaw", "Sore jaw", "I challenged a bag of almonds to a duel. My jaw lost.")
add("06_HeGu", "合谷穴", "He Gu", "RightArm", "Front", "RightHand", Vector3.new(-0.25, 0.1, -0.15), 0.45,
 "Thumb web", "Sore tooth", "A frozen snack made my tooth complain. Even my thumb web is making an appearance in this story.")
add("07_NeiGuan", "内关穴", "Nei Guan", "LeftArm", "Front", "LeftLowerArm", Vector3.new(0.0, -0.3, -0.25), 0.50,
 "Inner wrist", "Motion sickness", "A roller coaster followed by a bus ride was a terrible idea.")
add("08_QuChi", "曲池穴", "Qu Chi", "RightArm", "Front", "RightUpperArm", Vector3.new(0.3, -0.45, 0.0), 0.50,
 "Outer elbow", "Sore elbow", "One more arcade round and my elbow might file a complaint.")
add("09_WaiGuan", "外关穴", "Wai Guan", "LeftArm", "Back", "LeftLowerArm", Vector3.new(0.0, -0.2, 0.25), 0.50,
 "Outer wrist", "Tired wrist", "I typed for ten hours. Now my wrist wants a holiday.")
add("10_ChiZe", "尺泽穴", "Chi Ze", "LeftArm", "Front", "LeftLowerArm", Vector3.new(0.15, 0.4, -0.2), 0.45,
 "Inner elbow", "Tickly throat", "My throat keeps tickling and sending me into little coughs.")
add("11_ZhongWan", "中脘穴", "Zhong Wan", "Torso", "Front", "UpperTorso", Vector3.new(0.0, -0.4, -0.55), 0.60,
 "Upper belly", "Full stomach", "At the buffet, I ate as if tomorrow had been cancelled.")
add("12_TianShu", "天枢穴", "Tian Shu", "Torso", "Front", "LowerTorso", Vector3.new(0.4, 0.1, -0.55), 0.55,
 "Beside the navel", "Belly pressure", "My belly feels tight on both sides of my navel.")
add("13_GuanYuan", "关元穴", "Guan Yuan", "Torso", "Front", "LowerTorso", Vector3.new(0.0, -0.45, -0.55), 0.55,
 "Lower belly", "Low energy", "After three late nights, I feel cold and out of energy.")
add("14_DanZhong", "膻中穴", "Dan Zhong", "Torso", "Front", "UpperTorso", Vector3.new(0.0, 0.2, -0.55), 0.50,
 "Mid-chest", "Chest tension", "That close match left me feeling tense across the center of my chest.")
add("15_ShenYu", "肾俞穴", "Shen Yu", "Torso", "Back", "LowerTorso", Vector3.new(0.35, 0.1, 0.55), 0.60,
 "Lower back", "Tired back", "I carried boxes all day and my lower back is staging a protest.")
add("16_ZuSanLi", "足三里", "Zu San Li", "RightLeg", "Front", "RightLowerLeg", Vector3.new(0.25, 0.3, -0.35), 0.60,
 "Front of the shin", "Heavy legs", "I walked thirty thousand steps and my shins feel like lead.")
add("17_YangLingQuan", "阳陵泉", "Yang Ling Quan", "LeftLeg", "Front", "LeftLowerLeg", Vector3.new(-0.35, 0.4, -0.25), 0.55,
 "Outer knee", "Leg cramp", "One dramatic kick later, my outer knee area cramped up.")
add("18_YinLingQuan", "阴陵泉", "Yin Ling Quan", "RightLeg", "Front", "RightLowerLeg", Vector3.new(-0.25, 0.35, -0.2), 0.55,
 "Inner knee", "Puffy legs", "After standing all day, the inside of my knee and leg feel puffy.")
add("19_WeiZhong", "委中穴", "Wei Zhong", "LeftLeg", "Back", "LeftLowerLeg", Vector3.new(0.0, 0.45, 0.35), 0.50,
 "Behind the knee", "Stiff back", "After bending all day, my back and the crease behind my knee feel stiff.")
add("20_YongQuan", "涌泉穴", "Yong Quan", "RightLeg", "Bottom", "RightFoot", Vector3.new(0.0, -0.25, -0.1), 0.50,
 "Sole of the foot", "Cold feet", "My toes are icicles, and I still can’t fall asleep.")

return table.freeze({
 points = table.freeze(points),
 byId = table.freeze(byId),
 combos = table.freeze({
  table.freeze({"01_TaiYang", "02_BaiHui"}),
  table.freeze({"07_NeiGuan", "11_ZhongWan"}),
  table.freeze({"05_JiaChe", "12_TianShu"}),
  table.freeze({"15_ShenYu", "16_ZuSanLi"}),
 }),
})
