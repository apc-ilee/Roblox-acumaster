--!strict
export type Result = { id: number, qi: number, finish: number?, missed: boolean }
export type Award = { id: number, qi: number, delta: number, reason: string }

local function score(results: {Result}): ({Award}, number)
 local ranking: {Result} = {}
 for _, result in ipairs(results) do
  if result.finish then table.insert(ranking, result) end
 end
 table.sort(ranking, function(a, b)
  if a.finish == b.finish then return a.id < b.id end
  return (a.finish or math.huge) < (b.finish or math.huge)
 end)
 local places: {[number]: number} = {}
 for i, result in ipairs(ranking) do places[result.id] = i end
 local awards: {Award} = {}
 local survivors = 0
 for _, result in ipairs(results) do
  local place = places[result.id]
  local delta, reason = -1, if result.missed then "Wrong point" else "Time expired"
  if place then
   delta = if place == 1 then 2 elseif place == #ranking then 0 else 1
   reason = if place == 1 then "Fastest placement" elseif delta == 0 then "Placed last" else "Placed"
  end
  local qi = math.max(0, result.qi + delta)
  if qi > 0 then survivors += 1 end
  table.insert(awards, {id = result.id, qi = qi, delta = delta, reason = reason})
 end
 return awards, survivors
end

return table.freeze({score = score})
