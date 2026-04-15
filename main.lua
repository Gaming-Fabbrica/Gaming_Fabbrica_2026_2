local Character = require("character")
local Camera = require("camera")
local Menu = require("menu")
local Battle = require("battle")
local Lifebar = require("lifebar")
local Obstacle = require("obstacle")

local cols = 20
local rows = 20

local mapBackground = nil
local tile = nil
local tileW = 0
local tileH = 0
local tileSpacingX = 0
local tileSpacingY = 0
local cursor = nil
local moveTile = nil
local attackTile = nil

local characterScale = 1.0
local characterFootOffsetY = 32
local characterRightOffsetX = 0
local camera = nil
local battle = nil
local lifebar = nil
local enemyTurnState = nil

local enemyMovePreviewDelay = 0.9
local enemyPostMoveDelay = 0.45
local enemyAttackPreviewDelay = 0.55
local enemySkipActionDelay = 0.3

local map = {}
local obstacles = {}
local characters = {}
local currentTurn = 1
local playerSpawnCount = 5
local enemySpawnCount = 3
local treeCount = 56
local bushCount = 24
local stoneCount = 16

local availableClasses = {
  {className = "archer", sprites = {"archer_boy", "archer_girl"}},
  {className = "atk_mov", sprites = {"atk_mov_boy", "atk_mov_girl"}},
  {className = "counter", sprites = {"counter_boy", "counter_girl"}},
  {className = "free", sprites = {"free_boy", "free_girl"}},
  {className = "grab", sprites = {"grab_boy", "grab_girl"}},
  {className = "healer", sprites = {"healer_boy", "healer_girl"}},
  {className = "lancer", sprites = {"lancer_boy", "lancer_girl"}},
  {className = "tactician", sprites = {"tactician_boy", "tactician_girl"}},
  {className = "tank", sprites = {"tank_boy", "tank_girl"}},
}

local function shuffledCopy(list)
  local copy = {}
  for index, value in ipairs(list) do
    copy[index] = value
  end

  for index = #copy, 2, -1 do
    local swapIndex = math.random(index)
    copy[index], copy[swapIndex] = copy[swapIndex], copy[index]
  end

  return copy
end

local function tileKey(column, row)
  return string.format("%d:%d", column, row)
end

local function tileDistance(columnA, rowA, columnB, rowB)
  local xA = (columnA - 1) * 0.75
  local yA = (rowA - 1) + ((columnA % 2 == 1) and 0.5 or 0)
  local xB = (columnB - 1) * 0.75
  local yB = (rowB - 1) + ((columnB % 2 == 1) and 0.5 or 0)
  local dx = xA - xB
  local dy = yA - yB
  return math.sqrt((dx * dx) + (dy * dy))
end

local function countNearbyTiles(tiles, column, row, maxDistance)
  local count = 0
  for _, tileInfo in ipairs(tiles) do
    if tileDistance(column, row, tileInfo.column, tileInfo.row) <= maxDistance then
      count = count + 1
    end
  end
  return count
end

local function takeWeightedCandidate(candidates)
  local totalWeight = 0
  for _, candidate in ipairs(candidates) do
    totalWeight = totalWeight + candidate.weight
  end

  if totalWeight <= 0 then
    return nil
  end

  local roll = math.random() * totalWeight
  local runningWeight = 0
  for index, candidate in ipairs(candidates) do
    runningWeight = runningWeight + candidate.weight
    if roll <= runningWeight then
      return table.remove(candidates, index)
    end
  end

  return table.remove(candidates)
end

local function buildCandidates(columnStart, columnEnd, rowStart, rowEnd, blockedLookup, weightFn)
  local candidates = {}
  for column = columnStart, columnEnd do
    for row = rowStart, rowEnd do
      if not blockedLookup[tileKey(column, row)] then
        local weight = weightFn(column, row)
        if weight and weight > 0 then
          candidates[#candidates + 1] = {
            column = column,
            row = row,
            weight = weight,
          }
        end
      end
    end
  end
  return candidates
end

local function generateSpawnPositions(count, columnStart, columnEnd, rowStart, rowEnd, anchorColumn, anchorRow, direction)
  local positions = {}
  local blockedLookup = {}

  while #positions < count do
    local candidates = buildCandidates(columnStart, columnEnd, rowStart, rowEnd, blockedLookup, function(column, row)
      for _, position in ipairs(positions) do
        if tileDistance(column, row, position.column, position.row) < 2.6 then
          return 0
        end
      end

      local distanceToAnchor = tileDistance(column, row, anchorColumn, anchorRow)
      return math.max(0.1, 8 - (distanceToAnchor * 1.7))
    end)

    local candidate = takeWeightedCandidate(candidates)
    if not candidate then
      break
    end

    blockedLookup[tileKey(candidate.column, candidate.row)] = true
    positions[#positions + 1] = {
      column = candidate.column,
      row = candidate.row,
      direction = direction,
    }
  end

  return positions
end

local function buildReservedLookup(playerSpawnPositions, enemySpawnPositions)
  local reservedLookup = {}
  local allSpawnPositions = {}

  for _, position in ipairs(playerSpawnPositions) do
    allSpawnPositions[#allSpawnPositions + 1] = position
  end
  for _, position in ipairs(enemySpawnPositions) do
    allSpawnPositions[#allSpawnPositions + 1] = position
  end

  for column = 1, cols do
    for row = 1, rows do
      for _, position in ipairs(allSpawnPositions) do
        if tileDistance(column, row, position.column, position.row) < 1.8 then
          reservedLookup[tileKey(column, row)] = true
          break
        end
      end
    end
  end

  return reservedLookup
end

local function generateObstaclePlacements(playerSpawnPositions, enemySpawnPositions)
  local placements = {}
  local occupiedLookup = buildReservedLookup(playerSpawnPositions, enemySpawnPositions)

  local treeCandidates = buildCandidates(1, cols, 1, rows, occupiedLookup, function(column, row)
    local edgeDistance = math.min(column - 1, cols - column, row - 1, rows - row)
    local edgeBias = math.max(0, 5 - edgeDistance)
    return 1 + (edgeBias * edgeBias)
  end)

  for _ = 1, treeCount do
    local candidate = takeWeightedCandidate(treeCandidates)
    if not candidate then
      break
    end
    occupiedLookup[tileKey(candidate.column, candidate.row)] = true
    placements[#placements + 1] = {
      kind = "tree",
      column = candidate.column,
      row = candidate.row,
    }
  end

  local bushCandidates = buildCandidates(1, cols, 1, rows, occupiedLookup, function(column, row)
    local nearbyTrees = countNearbyTiles(placements, column, row, 2.2)
    return 1 + (nearbyTrees * 4)
  end)

  for _ = 1, bushCount do
    local candidate = takeWeightedCandidate(bushCandidates)
    if not candidate then
      break
    end
    occupiedLookup[tileKey(candidate.column, candidate.row)] = true
    placements[#placements + 1] = {
      kind = "bush",
      column = candidate.column,
      row = candidate.row,
    }
  end

  local stoneCandidates = buildCandidates(1, cols, 1, rows, occupiedLookup, function(column, row)
    local edgeDistance = math.min(column - 1, cols - column, row - 1, rows - row)
    return 1 + math.max(0, 3 - edgeDistance)
  end)

  for _ = 1, stoneCount do
    local candidate = takeWeightedCandidate(stoneCandidates)
    if not candidate then
      break
    end
    occupiedLookup[tileKey(candidate.column, candidate.row)] = true
    placements[#placements + 1] = {
      kind = "stone",
      column = candidate.column,
      row = candidate.row,
    }
  end

  return placements
end

local function loadSprites(playerSpawnPositions, enemySpawnPositions)
  local roster = {}
  local classPool = shuffledCopy(availableClasses)

  for index, spawn in ipairs(playerSpawnPositions) do
    local classInfo = classPool[index]
    local spriteName = classInfo.sprites[math.random(#classInfo.sprites)]
    local spritePath = "assets/sprites/heroes/" .. spriteName .. ".png"
    roster[#roster + 1] = Character.new(
      classInfo.className .. "_" .. index,
      spritePath,
      spawn.column,
      spawn.row,
      Character.rollStats(16),
      spawn.direction,
      classInfo.className,
      "player"
    )
  end

  for index, spawn in ipairs(enemySpawnPositions) do
    roster[#roster + 1] = Character.new(
      "trauma_" .. index,
      "assets/sprites/mobs/trauma.png",
      spawn.column,
      spawn.row,
      Character.rollStats(16),
      spawn.direction,
      "trauma",
      "enemy"
    )
  end

  return roster
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

local function isPlayerTurn()
  local active = getActiveCharacter()
  return active and active.team == "player"
end

local function advanceTurn(activeCharacter)
  if #characters == 0 then
    currentTurn = 1
    if battle then
      battle:startTurn()
    end
    Menu:reset()
    return
  end

  local activeIndex = nil
  for index, character in ipairs(characters) do
    if character == activeCharacter then
      activeIndex = index
      break
    end
  end

  if activeIndex then
    currentTurn = (activeIndex % #characters) + 1
  else
    currentTurn = 1
  end

  if battle then
    battle:startTurn()
  end
  enemyTurnState = nil
  Menu:reset()
end

function love.load()
  love.graphics.setBackgroundColor(1, 1, 1)
  math.randomseed(os.time())

  mapBackground = love.graphics.newImage("assets/map_bg2.png")
  tile = love.graphics.newImage("assets/sprites/hexa.png")
  cursor = love.graphics.newImage("assets/sprites/cursor.png")
  moveTile = love.graphics.newImage("assets/sprites/move.png")
  attackTile = love.graphics.newImage("assets/sprites/attack.png")
  lifebar = Lifebar.new("assets/sprites/items/heart.png")
  tileW = tile:getWidth()
  tileH = tile:getHeight()
  tileSpacingX = tileW * 0.75
  tileSpacingY = tileH

  local playerSpawnPositions = generateSpawnPositions(playerSpawnCount, 5, 10, 6, 14, 8, 10, "right")
  local enemySpawnPositions = generateSpawnPositions(enemySpawnCount, 11, 16, 6, 14, 13, 10, "left")
  local obstaclePlacements = generateObstaclePlacements(playerSpawnPositions, enemySpawnPositions)

  for c = 1, cols do
    map[c] = {}
    for r = 1, rows do
      map[c][r] = true
    end
  end
  obstacles = {}
  for _, obstaclePlacement in ipairs(obstaclePlacements) do
    map[obstaclePlacement.column][obstaclePlacement.row] = false
    obstacles[#obstacles + 1] = Obstacle.randomOfKind(
      obstaclePlacement.kind,
      obstaclePlacement.column,
      obstaclePlacement.row
    )
  end
  battle = Battle.new(cols, rows, map)
  battle:startTurn()

  characters = loadSprites(playerSpawnPositions, enemySpawnPositions)
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
    local completedActionCharacter = battle:consumeCompletedActionCharacter()
    if completedActionCharacter then
      advanceTurn(completedActionCharacter)
    end
    Menu:setPhase(battle:getTurnPhase())
  end

  local active = getActiveCharacter()
  if active and battle and active.team == "enemy" and not battle:isAnimating() then
    if battle:getTurnPhase() == "move" then
      if not enemyTurnState or enemyTurnState.character ~= active or enemyTurnState.phase ~= "move_preview" then
        local targetColumn, targetRow = battle:getBestMoveTileFor(active)
        battle:startMoveSelection(active)
        battle:setMoveTarget(targetColumn, targetRow)
        enemyTurnState = {
          character = active,
          phase = "move_preview",
          timer = enemyMovePreviewDelay,
          targetColumn = targetColumn,
          targetRow = targetRow,
        }
      else
        enemyTurnState.timer = enemyTurnState.timer - dt
        if enemyTurnState.timer <= 0 then
          if enemyTurnState.targetColumn ~= active.column or enemyTurnState.targetRow ~= active.row then
            if battle:confirmMove(active) then
              enemyTurnState = {
                character = active,
                phase = "post_move_wait",
                timer = enemyPostMoveDelay,
              }
            else
              battle:cancelMoveMode()
              battle:startActionPhase()
              enemyTurnState = {
                character = active,
                phase = "post_move_wait",
                timer = enemyPostMoveDelay,
              }
            end
          else
            battle:cancelMoveMode()
            battle:startActionPhase()
            enemyTurnState = {
              character = active,
              phase = "post_move_wait",
              timer = enemyPostMoveDelay,
            }
          end
        end
      end
    elseif battle:getTurnPhase() == "action" then
      if enemyTurnState and enemyTurnState.character == active and enemyTurnState.phase == "post_move_wait" then
        enemyTurnState.timer = enemyTurnState.timer - dt
        if enemyTurnState.timer <= 0 then
          enemyTurnState = nil
        end
      elseif enemyTurnState and enemyTurnState.character == active and enemyTurnState.phase == "end_turn_wait" then
        enemyTurnState.timer = enemyTurnState.timer - dt
        if enemyTurnState.timer <= 0 then
          advanceTurn(active)
        end
      elseif enemyTurnState and enemyTurnState.character == active and enemyTurnState.phase == "attack_preview" then
        enemyTurnState.timer = enemyTurnState.timer - dt
        if enemyTurnState.timer <= 0 then
          battle:confirmAttack(active)
          enemyTurnState = nil
        end
      elseif not enemyTurnState or enemyTurnState.character ~= active or enemyTurnState.phase ~= "attack_preview" then
        if battle:startAttackSelection(active) then
          enemyTurnState = {
            character = active,
            phase = "attack_preview",
            timer = enemyAttackPreviewDelay,
          }
        else
          enemyTurnState = {
            character = active,
            phase = "end_turn_wait",
            timer = enemySkipActionDelay,
          }
        end
      end
    end
  elseif enemyTurnState and (not active or active.team ~= "enemy") then
    enemyTurnState = nil
  end

  if active then
    local gameMode = battle and battle:getMode() or "menu"
    local focusColumn = active.column
    local focusRow = active.row
    if gameMode == "move" or gameMode == "attack" then
      focusColumn, focusRow = battle:getCursorColumnRow(active)
    end

    local tileX, tileY = gridToScreen(focusColumn, focusRow)
    if gameMode == "animating" then
      local animatedX, animatedY = Character.getMoveRenderState(active, battle, gridToScreen)
      if animatedX then
        tileX = animatedX
        tileY = animatedY
      end
    elseif battle and battle:getAttackAnimation() then
      local attackAnimation = battle:getAttackAnimation()
      local attackerX, attackerY = Character.getAttackRenderState(attackAnimation.attacker, battle, gridToScreen, tileW)
      local targetX, targetY = Character.getAttackRenderState(attackAnimation.target, battle, gridToScreen, tileW)
      if attackerX and targetX then
        tileX = (attackerX + targetX) * 0.5
        tileY = (attackerY + targetY) * 0.5
      end
    elseif battle and battle:getDeathAnimation() then
      local deathAnimation = battle:getDeathAnimation()
      local deathX, deathY = Character.getDeathRenderState(deathAnimation.character, battle, gridToScreen)
      if deathX then
        tileX = deathX
        tileY = deathY
      end
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
  local hoveredCharacter = nil
  local attackAnimation = battle and battle:getAttackAnimation() or nil
  if attackAnimation then
    hoveredCharacter = attackAnimation.target
  elseif active and active.team == "player" and not (battle and battle:isAnimating()) then
    local hoverColumn = active.column
    local hoverRow = active.row
    if battle and (battle:isMoveMode() or battle:isAttackMode()) then
      hoverColumn, hoverRow = battle:getCursorColumnRow(active)
    end
    hoveredCharacter = Character.getAtTile(characters, hoverColumn, hoverRow)
  end

  if camera then
    love.graphics.push()
    camera:apply()
  end

  if mapBackground then
    love.graphics.draw(mapBackground, 0, 0, 0, 2.5, 2.5)
  end

  for c = 1, cols do
    for r = 1, rows do
      local x, y = gridToScreen(c, r)
      love.graphics.draw(tile, x, y)
      if active and battle and battle:isMoveMode() and battle:isReachable(c, r) then
        local glow = 0.45 + 0.1 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(moveTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      elseif active and battle and battle:isAttackMode() and battle:isAttackable(c, r) then
        local glow = 0.45 + 0.1 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(attackTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  if active and active.team == "player" and not (battle and battle:isAnimating()) then
    local cursorX, cursorY
    if battle and (battle:isMoveMode() or battle:isAttackMode()) then
      local targetColumn, targetRow = battle:getCursorColumnRow(active)
      cursorX, cursorY = gridToScreen(targetColumn, targetRow)
    else
      cursorX, cursorY = gridToScreen(active.column, active.row)
    end
    love.graphics.draw(cursor, cursorX, cursorY)
  end

  local characterDrawList = Character.buildDrawList(
    characters,
    battle,
    gridToScreen,
    tileW,
    tileH,
    love.timer.getTime()
  )
  local obstacleDrawList = Obstacle.buildDrawList(obstacles, gridToScreen, tileW, tileH)
  local renderDrawList = {}
  for _, entry in ipairs(obstacleDrawList) do
    renderDrawList[#renderDrawList + 1] = entry
  end
  for _, entry in ipairs(characterDrawList) do
    renderDrawList[#renderDrawList + 1] = entry
  end
  table.sort(renderDrawList, function(a, b)
    if a.sortY == b.sortY then
      return a.sortX < b.sortX
    end
    return a.sortY < b.sortY
  end)
  for _, entry in ipairs(renderDrawList) do
    if entry.kind == "obstacle" then
      Obstacle.drawEntry(entry, tileW, tileH, love.timer.getTime())
    else
      Character.drawEntry(
        entry,
        tileW,
        tileH,
        characterScale,
        characterRightOffsetX,
        characterFootOffsetY
      )
    end
  end
  lifebar:draw(
    hoveredCharacter,
    characterDrawList,
    tileW,
    tileH,
    characterScale,
    characterRightOffsetX,
    characterFootOffsetY,
    battle
  )
  Character.drawAttackDamageText(battle, gridToScreen, tileW)

  if camera then
    love.graphics.pop()
  end

  local isAnimating = battle and battle:isAnimating()
  if active and active.team == "player" and not isAnimating then
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
      string.format(
        "Turn %d: %s  HP:%d  MOV:%d  DEF:%d  ATK:%d  Phase: %s  Action: %s",
        currentTurn,
        active.name,
        active.hp,
        active.mov,
        active.def,
        active.atk,
        battle and battle:getTurnPhase() or "move",
        Menu:selectedAction()
      ),
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
  elseif active and active.team ~= "player" then
    -- disable player input during enemy turns
  elseif battle and battle:isAnimating() then
    -- disable input during animations
  elseif gameMode == "move" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle then
        battle:moveTargetByKey(key)
      end
    elseif key == "return" or key == "kpenter" or key == "enter" then
      if active then
        local didMove = false
        if battle then
          didMove = battle:confirmMove(active)
        end
        if didMove then
          Menu:reset()
        end
      end
    elseif key == "tab" then
      -- cancel move mode and keep current turn
      if battle then
        battle:cancelMoveMode()
      end
      Menu:reset()
    end
  elseif gameMode == "attack" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle and active then
        battle:moveAttackTargetByKey(active, key)
      end
    elseif key == "return" or key == "kpenter" or key == "enter" then
      if battle and active then
        battle:confirmAttack(active)
      end
    elseif key == "tab" then
      if battle then
        battle:cancelAttackMode()
      end
      Menu:reset()
    end
  elseif key == "return" or key == "kpenter" or key == "enter" then
    if active then
      local selectedAction = Menu:selectedAction()
      if battle and battle:getTurnPhase() == "move" then
        if Menu:isMoveSelected() then
          battle:startMoveSelection(active)
        elseif selectedAction == "Rester ici" then
          battle:startActionPhase()
        end
      elseif battle and battle:getTurnPhase() == "action" then
        if selectedAction == "Se battre" then
          if not battle:startAttackSelection(active) then
            advanceTurn(active)
          end
        elseif selectedAction == "Passer son tour" then
          advanceTurn(active)
        end
      end
    end
  elseif key == "up" then
    Menu:prev()
  elseif key == "down" then
    Menu:next()
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
