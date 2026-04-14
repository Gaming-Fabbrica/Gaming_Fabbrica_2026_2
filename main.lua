local Character = require("character")
local Camera = require("camera")
local Menu = require("menu")
local Battle = require("battle")

local cols = 20
local rows = 20

local tile = nil
local tileW = 0
local tileH = 0
local tileSpacingX = 0
local tileSpacingY = 0
local cursor = nil
local moveTile = nil

local characterScale = 1.0
local characterFootOffsetY = 32
local characterRightOffsetX = 0
local camera = nil
local battle = nil

local map = {}
local characters = {}
local currentTurn = 1

local function loadSprites()
  return {
    Character.new("tank_girl", "assets/sprites/heroes/tank_girl.png", 2, 3, 5, 5, "right"),
    Character.new("tank_boy", "assets/sprites/heroes/tank_boy.png", 5, 3, 5, 5, "left"),
    Character.new("archer_boy", "assets/sprites/heroes/archer_boy.png", 8, 3, 5, 5, "right"),
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

local function getActiveCharacter()
  return characters[currentTurn]
end

function love.load()
  love.graphics.setBackgroundColor(1, 1, 1)

  tile = love.graphics.newImage("assets/sprites/hexa.png")
  cursor = love.graphics.newImage("assets/sprites/cursor.png")
  moveTile = love.graphics.newImage("assets/sprites/move.png")
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
  battle = Battle.new(cols, rows, map)

  characters = loadSprites()
  local screenW, screenH = love.window.getDesktopDimensions(1)
  love.window.setMode(screenW, screenH, {
    fullscreen = true,
    fullscreentype = "desktop",
  })
  camera = Camera.new(screenW, screenH)
  camera:setViewSize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.update()
  local active = getActiveCharacter()
  if active then
    local gameMode = battle and battle:getMode() or "menu"
    local focusColumn = active.column
    local focusRow = active.row
    if gameMode == "move" then
      focusColumn, focusRow = battle:getCursorColumnRow(active)
    end

    local tileX, tileY = gridToScreen(focusColumn, focusRow)
    local focusX = tileX + (tileW * 0.5)
    local focusY = tileY + (tileH * 0.5)

    camera:setViewSize(love.graphics.getWidth(), love.graphics.getHeight())
    camera:setTarget(focusX, focusY)
    camera:update()
    if battle then
      battle:setMode(gameMode)
    end
  else
    if battle then
      battle:setMode("menu")
    end
  end
end

function love.resize(width, height)
  if camera then
    camera:setViewSize(width, height)
  end
end

function love.draw()
  local active = getActiveCharacter()

  if camera then
    love.graphics.push()
    camera:apply()
  end

  for c = 1, cols do
    for r = 1, rows do
      if map[c][r] then
        local x, y = gridToScreen(c, r)
        love.graphics.draw(tile, x, y)
        if active and battle and battle:isMoveMode() and battle:isReachable(c, r) then
          love.graphics.setColor(1, 1, 1, 0.5)
          love.graphics.draw(moveTile, x, y)
          love.graphics.setColor(1, 1, 1, 1)
        end
      end
    end
  end

  if active then
    local cursorX, cursorY
    if battle and battle:isMoveMode() then
      local targetColumn, targetRow = battle:getCursorColumnRow(active)
      cursorX, cursorY = gridToScreen(targetColumn, targetRow)
    else
      cursorX, cursorY = gridToScreen(active.column, active.row)
    end
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
    Menu:draw(worldX, worldY, tileW, camera and function(x, y)
      return camera:worldToScreen(x, y)
    end)
  end

  love.graphics.setColor(0, 0, 0)
  if active then
    love.graphics.print(
      string.format("Turn %d: %s  HP:%d  MOV:%d  Action: %s", currentTurn, active.name, active.hp, active.mov, Menu:selectedAction()),
      10,
      10
    )
  else
    love.graphics.print("No active character", 10, 10)
  end
  love.graphics.setColor(1, 1, 1)
end

function love.keypressed(key)
  local active = getActiveCharacter()
  local gameMode = battle and battle:getMode() or "menu"
  if key == "escape" then
    love.event.quit()
  elseif gameMode == "move" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle then
        battle:moveTargetByKey(key)
      end
    elseif key == "return" or key == "kpenter" then
      if active then
        if battle then
          battle:confirmMove(active)
        end
        Menu:reset()
      end
    elseif key == "tab" then
      -- cancel move mode and keep current turn
      if battle then
        battle:cancelMoveMode()
      end
      Menu:reset()
    end
  elseif key == "return" or key == "kpenter" then
    if active then
      if Menu:isMoveSelected() then
        if battle then
          battle:startMoveSelection(active)
        end
      end
    end
  elseif key == "up" then
    Menu:prev()
  elseif key == "down" then
    Menu:next()
  elseif key == "tab" then
    currentTurn = currentTurn % #characters + 1
    Menu:reset()
    if battle then
      battle:setMode("menu")
    end
  elseif key == "1" then
    Menu:setIndex(1)
  elseif key == "2" then
    Menu:setIndex(2)
  elseif key == "3" then
    Menu:setIndex(3)
  elseif key == "4" then
    Menu:setIndex(4)
  end
end
