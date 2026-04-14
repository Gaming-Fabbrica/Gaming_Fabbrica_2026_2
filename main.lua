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
local gameMode = "menu"
local moveRange = {}
local moveTarget = { column = 1, row = 1 }

local map = {}
local characters = {}
local currentTurn = 1
local actionMenu = { "Move", "Attack", "Skill", "Item" }
local selectedActionIndex = 1
local actionMenuScale = 2

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

local function isInMap(column, row)
  return column >= 1 and column <= cols and row >= 1 and row <= rows
end

local function getHexNeighbors(column, row)
  local neighbors = {}
  if column % 2 == 0 then
    neighbors = {
      {column + 1, row},
      {column - 1, row},
      {column, row - 1},
      {column, row + 1},
      {column + 1, row - 1},
      {column - 1, row - 1},
    }
  else
    neighbors = {
      {column + 1, row},
      {column - 1, row},
      {column, row - 1},
      {column, row + 1},
      {column + 1, row + 1},
      {column - 1, row + 1},
    }
  end
  return neighbors
end

local function getReachableTiles(startColumn, startRow, maxMoves)
  local reachable = {}
  if maxMoves < 1 then
    return reachable
  end

  local queue = {
    {startColumn, startRow, 0},
  }
  local visited = {[startColumn .. "," .. startRow] = 0}

  local head = 1
  while head <= #queue do
    local node = queue[head]
    head = head + 1

    local column = node[1]
    local row = node[2]
    local distance = node[3]

    local key = column .. "," .. row
    if distance > 0 then
      reachable[key] = true
    end

    if distance < maxMoves then
      for _, neighbor in ipairs(getHexNeighbors(column, row)) do
        local nextColumn = neighbor[1]
        local nextRow = neighbor[2]
        local nextKey = nextColumn .. "," .. nextRow

        if isInMap(nextColumn, nextRow) and map[nextColumn][nextRow] and not visited[nextKey] then
          visited[nextKey] = distance + 1
          table.insert(queue, {nextColumn, nextRow, distance + 1})
        end
      end
    end
  end

  return reachable
end

local function isMoveActionSelected()
  return actionMenu[selectedActionIndex] == "Move"
end

local function isReachableForMove(column, row)
  return moveRange[column .. "," .. row]
end

local function startMoveSelection(active)
  moveRange = getReachableTiles(active.column, active.row, active.mov)
  moveTarget.column = active.column
  moveTarget.row = active.row
  gameMode = "move"
end

local function moveTargetByKey(key)
  local nextColumn = moveTarget.column
  local nextRow = moveTarget.row
  local neighbors = getHexNeighbors(moveTarget.column, moveTarget.row)
  local candidates = {}

  if key == "left" then
    candidates[1] = neighbors[2]
  elseif key == "right" then
    candidates[1] = neighbors[1]
  elseif key == "up" then
    candidates[1] = neighbors[3]
    candidates[2] = neighbors[5]
  elseif key == "down" then
    candidates[1] = neighbors[4]
    candidates[2] = neighbors[6]
  end

  for _, candidate in ipairs(candidates) do
    if candidate then
      local c = candidate[1]
      local r = candidate[2]
      if isInMap(c, r) and isReachableForMove(c, r) then
        nextColumn = c
        nextRow = r
        break
      end
    end
  end

  moveTarget.column = nextColumn
  moveTarget.row = nextRow
end

local function confirmMove(active)
  if isReachableForMove(moveTarget.column, moveTarget.row) then
    active:setPosition(moveTarget.column, moveTarget.row)
    gameMode = "menu"
  end
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
  local active = getActiveCharacter()
  if active then
    local focusColumn = active.column
    local focusRow = active.row
    if gameMode == "move" then
      focusColumn = moveTarget.column
      focusRow = moveTarget.row
    end

    local tileX, tileY = gridToScreen(focusColumn, focusRow)
    local focusX = tileX + (tileW * 0.5)
    local focusY = tileY + (tileH * 0.5)

    camera:setViewSize(love.graphics.getWidth(), love.graphics.getHeight())
    camera:setTarget(focusX, focusY)
    camera:update()
    if gameMode == "move" then
      moveRange = moveRange
    else
      moveRange = {}
    end
  else
    moveRange = {}
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
        local key = c .. "," .. r
        love.graphics.draw(tile, x, y)
        if active and gameMode == "move" and isReachableForMove(c, r) then
          love.graphics.setColor(1, 1, 0, 0.5)
          love.graphics.draw(tile, x, y)
          love.graphics.setColor(1, 1, 1, 1)
        end
      end
    end
  end

  if active then
    local cursorX, cursorY
    if gameMode == "move" then
      cursorX, cursorY = gridToScreen(moveTarget.column, moveTarget.row)
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
  local active = getActiveCharacter()
  if key == "escape" then
    love.event.quit()
  elseif gameMode == "move" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      moveTargetByKey(key)
    elseif key == "return" or key == "kpenter" then
      if active then
        confirmMove(active)
        selectedActionIndex = 1
      end
    elseif key == "tab" then
      -- cancel move mode and keep current turn
      gameMode = "menu"
      selectedActionIndex = 1
    end
  elseif key == "return" or key == "kpenter" then
    if active then
      if isMoveActionSelected() then
        startMoveSelection(active)
      else
        -- action selected (placeholder for future action handling)
        selectedActionIndex = selectedActionIndex
      end
    end
  elseif key == "up" then
    selectedActionIndex = math.max(1, selectedActionIndex - 1)
  elseif key == "down" then
    selectedActionIndex = math.min(#actionMenu, selectedActionIndex + 1)
  elseif key == "tab" then
    currentTurn = currentTurn % #characters + 1
    selectedActionIndex = 1
    gameMode = "menu"
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
