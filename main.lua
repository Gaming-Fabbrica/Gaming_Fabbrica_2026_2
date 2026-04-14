local Character = require("character")
local Camera = require("camera")

local cols = 10
local rows = 10

local tile = nil
local tileW = 0
local tileH = 0
local tileSpacingX = 0
local tileSpacingY = 0
local cursor = nil

local characterScale = 1.0
local characterFootOffsetY = 32
local characterRightOffsetX = 0
local camera = nil

local map = {}
local characters = {}
local currentTurn = 1
local actionMenu = { "Move", "Attack", "Skill", "Item" }
local selectedActionIndex = 1
local actionMenuScale = 2

local function loadSprites()
  return {
    Character.new("tank_girl", "assets/sprites/tank_girl.png", 2, 3, 5, 5, "right"),
    Character.new("tank_boy", "assets/sprites/tank_boy.png", 5, 3, 5, 5, "left"),
    Character.new("archer_boy", "assets/sprites/archer_boy.png", 8, 3, 5, 5, "right"),
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
  cursor = love.graphics.newImage("assets/sprites/cursor.png")
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
  local screenW, screenH = love.window.getDesktopDimensions(1)
  love.window.setMode(screenW, screenH, {
    fullscreen = true,
    fullscreentype = "desktop",
  })
  camera = Camera.new(screenW, screenH)
  camera:setViewSize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.update()
  local active = characters[currentTurn]
  if active then
    local tileX, tileY = gridToScreen(active.column, active.row)
    local focusX = tileX + (tileW * 0.5)
    local focusY = tileY + (tileH * 0.5)
    camera:setViewSize(love.graphics.getWidth(), love.graphics.getHeight())
    camera:follow(focusX, focusY)
  end
end

function love.resize(width, height)
  if camera then
    camera:setViewSize(width, height)
  end
end

function love.draw()
  local active = characters[currentTurn]

  if camera then
    love.graphics.push()
    camera:apply()
  end

  for c = 1, cols do
    for r = 1, rows do
      if map[c][r] then
        local x, y = gridToScreen(c, r)
        love.graphics.draw(tile, x, y)
      end
    end
  end

  if active then
    local cursorX, cursorY = gridToScreen(active.column, active.row)
    love.graphics.draw(cursor, cursorX, cursorY)
  end

  for _, character in ipairs(characters) do
    local x, y = gridToScreen(character.column, character.row)
    local spriteW = character.sprite:getWidth()
    local spriteH = character.sprite:getHeight()
    local scale = math.min((tileW / spriteW), (tileH / spriteH)) * characterScale
    local directionScale = character.direction == "left" and -scale or scale
    local tileCenterX = x + (tileW * 0.5)
    local tileCenterY = y + (tileH * 0.5)
    love.graphics.draw(
      character.sprite,
      tileCenterX + characterRightOffsetX,
      tileCenterY + characterFootOffsetY,
      0,
      directionScale,
      scale,
      spriteW * 0.5,
      spriteH
    )
  end

  if camera then
    love.graphics.pop()
  end

  if active then
    local tileX, tileY = gridToScreen(active.column, active.row)
    local worldX = tileX + (tileW * 0.5)
    local worldY = tileY + (tileH * 0.5)
    local screenX, screenY = worldX, worldY
    if camera then
      screenX, screenY = camera:worldToScreen(worldX, worldY)
    end

    local menuX = screenX + tileW * 0.6
    local menuY = screenY - (4 * 18) * 0.5
    local menuWidth = 90 * actionMenuScale
    local rowHeight = 18 * actionMenuScale
    local padding = 6 * actionMenuScale
    local menuHeight = (#actionMenu * rowHeight) + (padding * 2)

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight, 4, 4)

    for i, action in ipairs(actionMenu) do
      local y = menuY + padding + (i - 1) * rowHeight
      if i == selectedActionIndex then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("> " .. action, menuX + 4, y, 0, actionMenuScale, actionMenuScale)
      else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("  " .. action, menuX + 4, y, 0, actionMenuScale, actionMenuScale)
      end
    end
  end

  love.graphics.setColor(0, 0, 0)
  if active then
    love.graphics.print(
      string.format("Turn %d: %s  HP:%d  MOV:%d  Action: %s", currentTurn, active.name, active.hp, active.mov, actionMenu[selectedActionIndex]),
      10,
      10
    )
  else
    love.graphics.print("No active character", 10, 10)
  end
  love.graphics.setColor(1, 1, 1)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "up" then
    selectedActionIndex = math.max(1, selectedActionIndex - 1)
  elseif key == "down" then
    selectedActionIndex = math.min(#actionMenu, selectedActionIndex + 1)
  elseif key == "return" or key == "kpenter" then
    -- action selected (placeholder for future action handling)
    selectedActionIndex = selectedActionIndex
  elseif key == "tab" then
    currentTurn = currentTurn % #characters + 1
    selectedActionIndex = 1
  elseif key == "1" then
    selectedActionIndex = 1
  elseif key == "2" then
    selectedActionIndex = 2
  elseif key == "3" then
    selectedActionIndex = 3
  elseif key == "4" then
    selectedActionIndex = 4
  end
end
