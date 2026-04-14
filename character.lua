local Character = {}
Character.__index = Character

function Character.rollStats(totalPoints)
  local stats = {
    hp = 2,
    mov = 2,
    def = 2,
    atk = 2,
  }
  local statKeys = {"hp", "mov", "def", "atk"}
  local pointsToAssign = math.max(0, (totalPoints or 16) - 8)

  for _ = 1, pointsToAssign do
    local key = statKeys[math.random(#statKeys)]
    stats[key] = stats[key] + 1
  end

  return stats
end

function Character.new(name, spritePath, column, row, stats, direction)
  local resolvedStats = stats or Character.rollStats(16)
  local instance = {
    name = name,
    spritePath = spritePath,
    sprite = love.graphics.newImage(spritePath),
    hp = resolvedStats.hp or 5,
    mov = resolvedStats.mov or 5,
    def = resolvedStats.def or 2,
    atk = resolvedStats.atk or 2,
    column = column,
    row = row,
    direction = direction or "right",
  }
  return setmetatable(instance, Character)
end

function Character:getPosition()
  return self.column, self.row
end

function Character:setPosition(column, row)
  self.column = column
  self.row = row
end

function Character:setDirection(direction)
  if direction == "left" or direction == "right" then
    self.direction = direction
  end
end

return Character
