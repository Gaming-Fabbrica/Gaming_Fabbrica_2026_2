local Character = require("character")

local cols = 10
local rows = 10

local tile = nil
local tileW = 0
local tileH = 0
local tileSpacingX = 0
local tileSpacingY = 0
local characterScale = 1.0
local characterFootOffsetY = 32
local characterRightOffsetX = 32

local map = {}
local characters = {}
local currentTurn = 1

local function loadSprites()
  return {
    Character.new("tank_girl", "assets/sprites/tank_girl.png", 2, 3),
    Character.new("tank_boy", "assets/sprites/tank_boy.png", 5, 3),
    Character.new("archer_boy", "assets/sprites/archer_boy.png", 8, 3),
  }
end

local function gridToScreen(column, row)
  local x = (column - 1) * tileSpacingX
  local y = (row - 1) * tileSpacingY
  if column % 2 == 1 then
    y = y + (tileH * 0.5)
  end
  return x, y
end

function love.load()
  love.graphics.setBackgroundColor(1, 1, 1)

  tile = love.graphics.newImage("assets/sprites/hexa.png")
  tileW = tile:getWidth()
  tileH = tile:getHeight()
  tileSpacingX = tileW * 0.75
  tileSpacingY = tileH

  for c = 1, cols do
    map[c] = {}
    for r = 1, rows do
      map[c][r] = true
    end
  end

  characters = loadSprites()
  local mapWidth = math.floor((cols - 1) * tileSpacingX + tileW + 1)
  local mapHeight = math.floor(rows * tileSpacingY + tileH * 0.5 + 1)
  love.window.setMode(mapWidth, mapHeight)
end

function love.draw()
  for c = 1, cols do
    for r = 1, rows do
      if map[c][r] then
        local x, y = gridToScreen(c, r)
        love.graphics.draw(tile, x, y)
      end
    end
  end

  for _, character in ipairs(characters) do
    local x, y = gridToScreen(character.column, character.row)
    local spriteW = character.sprite:getWidth()
    local spriteH = character.sprite:getHeight()
    local scale = math.min((tileW / spriteW), (tileH / spriteH)) * characterScale
    local tileCenterX = x + (tileW * 0.5)
    local tileCenterY = y + (tileH * 0.5)
    love.graphics.draw(
      character.sprite,
      tileCenterX + characterRightOffsetX,
      tileCenterY + characterFootOffsetY,
      0,
      scale,
      scale,
      spriteW * 0.5,
      spriteH
    )
  end

  local active = characters[currentTurn]
  love.graphics.setColor(0, 0, 0)
  love.graphics.print(
    string.format("Turn %d: %s  HP:%d  MOV:%d", currentTurn, active.name, active.hp, active.mov),
    10,
    10
  )
  love.graphics.setColor(1, 1, 1)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "tab" then
    currentTurn = currentTurn % #characters + 1
  end
end
