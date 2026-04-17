local Rules = require("rules")

local Obstacle = {}
Obstacle.__index = Obstacle

local TREE_SWAY_SPEED = 1.15
local TREE_SWAY_ANGLE = 0.04
local TREE_SCALE = 2.5
local STONE_SCALE = 0.9075
local STONE_OFFSET_Y = -48
local TREE_PIVOT_RATIO = 0.9
local THEMES = {
  forest = {
    stone = {
      "assets/sprites/stone1.png",
      "assets/sprites/stone2.png",
      "assets/sprites/stone3.png",
      "assets/sprites/stone4.png",
    },
    bush = {
      "assets/sprites/bush1.png",
      "assets/sprites/bush2.png",
      "assets/sprites/bush3.png",
      "assets/sprites/bush4.png",
      "assets/sprites/bush5.png",
      "assets/sprites/bush6.png",
    },
    tree = {
      "assets/sprites/tree1.png",
      "assets/sprites/tree2.png",
      "assets/sprites/tree3.png",
      "assets/sprites/tree4.png",
      "assets/sprites/tree5.png",
      "assets/sprites/tree6.png",
    },
  },
  swamp = {
    stone = {
      "assets/sprites/swamp_stone1.png",
      "assets/sprites/swamp_stone2.png",
      "assets/sprites/swamp_stone3.png",
      "assets/sprites/swamp_stone4.png",
    },
    bush = {
      "assets/sprites/swamp_bush1.png",
      "assets/sprites/swamp_bush2.png",
      "assets/sprites/swamp_bush3.png",
      "assets/sprites/swamp_bush4.png",
      "assets/sprites/swamp_bush5.png",
      "assets/sprites/swamp_bush6.png",
    },
    tree = {
      "assets/sprites/swamp_tree1.png",
      "assets/sprites/swamp_tree2.png",
      "assets/sprites/swamp_tree3.png",
      "assets/sprites/swamp_tree4.png",
      "assets/sprites/swamp_tree5.png",
      "assets/sprites/swamp_tree6.png",
    },
  },
}

local function getThemeVariants()
  if Rules.SWAMP then
    return THEMES.swamp
  end
  return THEMES.forest
end

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

function Obstacle.randomOfKind(kind, column, row)
  local theme = getThemeVariants()
  if kind == "stone" then
    return Obstacle.new("stone", column, row, theme.stone[math.random(#theme.stone)])
  elseif kind == "bush" then
    return Obstacle.new("bush", column, row, theme.bush[math.random(#theme.bush)])
  end
  return Obstacle.new("tree", column, row, theme.tree[math.random(#theme.tree)])
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
    local swayAngle = 0
    if not Rules.SWAMP then
      local swayPhase = (timeSeconds * TREE_SWAY_SPEED) + (obstacle.column * 0.41) + (obstacle.row * 0.23)
      swayAngle = math.sin(swayPhase) * TREE_SWAY_ANGLE
    end

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
