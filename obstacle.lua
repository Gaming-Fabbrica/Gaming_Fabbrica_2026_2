local Obstacle = {}
Obstacle.__index = Obstacle

local TREE_SWAY_SPEED = 1.15
local TREE_SWAY_ANGLE = 0.04
local TREE_SCALE = 2.0
local STONE_SCALE = 0.9075
local STONE_OFFSET_Y = -48
local TREE_PIVOT_RATIO = 0.9
local STONE_VARIANTS = {
  "assets/sprites/stone1.png",
  "assets/sprites/stone2.png",
  "assets/sprites/stone3.png",
  "assets/sprites/stone4.png",
}
local BUSH_VARIANTS = {
  "assets/sprites/bush1.png",
  "assets/sprites/bush2.png",
  "assets/sprites/bush3.png",
}
local TREE_VARIANTS = {
  "assets/sprites/tree1.png",
  "assets/sprites/tree2.png",
  "assets/sprites/tree3.png",
  "assets/sprites/tree4.png",
  "assets/sprites/tree5.png",
  "assets/sprites/tree6.png",
}

function Obstacle.new(kind, column, row, spritePath)
  local sprite = love.graphics.newImage(spritePath)
  local scale = TREE_SCALE
  if kind == "stone" or kind == "bush" then
    scale = STONE_SCALE
  end

  local instance = {
    kind = kind,
    column = column,
    row = row,
    sprite = sprite,
    spritePath = spritePath,
    scale = scale,
  }

  return setmetatable(instance, Obstacle)
end

function Obstacle.randomForTile(column, row)
  local familyRoll = math.random(3)
  if familyRoll == 1 then
    return Obstacle.new("stone", column, row, STONE_VARIANTS[math.random(#STONE_VARIANTS)])
  elseif familyRoll == 2 then
    return Obstacle.new("bush", column, row, BUSH_VARIANTS[math.random(#BUSH_VARIANTS)])
  end
  return Obstacle.new("tree", column, row, TREE_VARIANTS[math.random(#TREE_VARIANTS)])
end

function Obstacle.buildDrawList(obstacles, gridToScreen, tileW, tileH)
  local drawList = {}

  for _, obstacle in ipairs(obstacles) do
    local x, y = gridToScreen(obstacle.column, obstacle.row)
    drawList[#drawList + 1] = {
      kind = "obstacle",
      obstacle = obstacle,
      x = x,
      y = y,
      sortY = y + (tileH * 0.5),
      sortX = x + (tileW * 0.5),
    }
  end

  return drawList
end

function Obstacle.drawEntry(entry, tileW, tileH, timeSeconds)
  local obstacle = entry.obstacle
  local sprite = obstacle.sprite
  local spriteW = sprite:getWidth()
  local spriteH = sprite:getHeight()
  local scale = math.min((tileW / spriteW), (tileH / spriteH)) * obstacle.scale
  local tileCenterX = entry.x + (tileW * 0.5)
  local tileCenterY = entry.y + (tileH * 0.5)

  if obstacle.kind == "tree" then
    local swayPhase = (timeSeconds * TREE_SWAY_SPEED) + (obstacle.column * 0.41) + (obstacle.row * 0.23)
    local swayAngle = math.sin(swayPhase) * TREE_SWAY_ANGLE

    love.graphics.draw(
      sprite,
      tileCenterX,
      tileCenterY,
      swayAngle,
      scale,
      scale,
      spriteW * 0.5,
      spriteH * TREE_PIVOT_RATIO
    )
    return
  end

  love.graphics.draw(
    sprite,
    tileCenterX,
    tileCenterY + STONE_OFFSET_Y,
    0,
    scale,
    scale,
    spriteW * 0.5,
    spriteH * 0.5
  )
end

return Obstacle
