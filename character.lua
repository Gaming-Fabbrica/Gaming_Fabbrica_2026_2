local Character = {}
Character.__index = Character

function Character.new(name, spritePath, column, row, hp, mov, direction)
  local instance = {
    name = name,
    spritePath = spritePath,
    sprite = love.graphics.newImage(spritePath),
    hp = hp or 5,
    mov = mov or 5,
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
