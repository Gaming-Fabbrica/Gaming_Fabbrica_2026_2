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
local stoneTile = nil

local characterScale = 1.0
local characterFootOffsetY = 32
local characterRightOffsetX = 0
local camera = nil
local battle = nil

local map = {}
local obstacleTiles = {
  {column = 4, row = 4},
  {column = 9, row = 6},
  {column = 14, row = 12},
}
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

local function getAnimationRenderState(character)
  if not battle then
    return nil
  end

  local animation = battle:getAnimationState(character)
  if not animation or not animation.path then
    return nil
  end

  local fromNode = animation.path[animation.step]
  local toNode = animation.path[animation.step + 1]
  if not fromNode or not toNode then
    return nil
  end

  local ratio = math.min(1, animation.timer / battle.moveStepDuration)
  local fromX, fromY = gridToScreen(fromNode.column, fromNode.row)
  local toX, toY = gridToScreen(toNode.column, toNode.row)
  local x = fromX + (toX - fromX) * ratio
  local y = fromY + (toY - fromY) * ratio
  local jump = math.sin(math.pi * ratio) * battle.jumpHeight
  return x, y, jump
end

function love.load()
  love.graphics.setBackgroundColor(1, 1, 1)

  tile = love.graphics.newImage("assets/sprites/hexa.png")
  stoneTile = love.graphics.newImage("assets/sprites/stone.png")
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
  for _, obstacle in ipairs(obstacleTiles) do
    map[obstacle.column][obstacle.row] = false
  end
  battle = Battle.new(cols, rows, map)

  characters = loadSprites()
  battle:setCharacters(characters)
  local screenW, screenH = love.window.getDesktopDimensions(1)
  love.window.setMode(screenW, screenH, {
    fullscreen = true,
    fullscreentype = "desktop",
  })
  camera = Camera.new(screenW, screenH)
  camera:setViewSize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.update(dt)
  if battle then
    battle:update(dt)
  end

  local active = getActiveCharacter()
  if active then
    local gameMode = battle and battle:getMode() or "menu"
    local focusColumn = active.column
    local focusRow = active.row
    if gameMode == "move" then
      focusColumn, focusRow = battle:getCursorColumnRow(active)
    end

    local tileX, tileY = gridToScreen(focusColumn, focusRow)
    if gameMode == "animating" then
      local animatedX, animatedY = getAnimationRenderState(active)
      if animatedX then
        tileX = animatedX
        tileY = animatedY
      end
    end
    if not tileX then
      tileX, tileY = getAnimationRenderState(active)
    end

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
      local x, y = gridToScreen(c, r)
      if map[c][r] then
        love.graphics.draw(tile, x, y)
        if active and battle and battle:isMoveMode() and battle:isReachable(c, r) then
          local glow = 0.45 + 0.1 * math.cos(love.timer.getTime() * 4)
          love.graphics.setColor(1, 1, 1, glow)
          love.graphics.draw(moveTile, x, y)
          love.graphics.setColor(1, 1, 1, 1)
        end
      else
        love.graphics.draw(stoneTile, x, y)
      end
    end
  end

  if active and not (battle and battle:isAnimating()) then
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
    local x, y, jumpOffset = getAnimationRenderState(character)
    if not x then
      x, y = gridToScreen(character.column, character.row)
      jumpOffset = 0
    end
    local spriteW = character.sprite:getWidth()
    local spriteH = character.sprite:getHeight()
    local scale = math.min((tileW / spriteW), (tileH / spriteH)) * characterScale
    local directionScale = character.direction == "left" and -scale or scale
    local tileCenterX = x + (tileW * 0.5)
    local tileCenterY = y + (tileH * 0.5) - jumpOffset
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

  local isAnimating = battle and battle:isAnimating()
  if active and not isAnimating then
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
  elseif battle and gameMode == "animating" then
    -- disable input during movement
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
