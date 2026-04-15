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
local thornsTile = nil
local algaeTile = nil
local splashTile = nil

local characterScale = 1.0
local characterFootOffsetY = 32
local characterRightOffsetX = 0
local camera = nil
local battle = nil
local lifebar = nil
local enemyTurnState = nil
local mapBackgroundScale = 2.5
local hudFont = nil
local resultFont = nil
local resultPromptFont = nil
local terrainEffectScale = 0.9
local terrainEffectAppearDuration = 0.25
local battleResult = nil
local battleResultTimer = 0
local battleResultDuration = 1.0

local enemyMovePreviewDelay = 0.9
local enemyPostMoveDelay = 0.45
local enemyAttackPreviewDelay = 0.55
local enemySkipActionDelay = 0.3

local map = {}
local obstacles = {}
local characters = {}
local currentTurn = 1
local playerSpawnCount = 5
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

local enemyArchetypes = {
  {name = "affamé", file = "affamé.png", stats = {hp = 7, mov = 4, def = 1, atk = 5, attackRange = 2}},
  {name = "embourbe", file = "embourbe.png", stats = {hp = 10, mov = 2, def = 4, atk = 2}},
  {name = "loup1", file = "loup1.png", stats = {hp = 5, mov = 5, def = 1, atk = 5}},
  {name = "loup2", file = "loup2.png", stats = {hp = 7, mov = 5, def = 1, atk = 4}},
  {name = "loup3", file = "loup3.png", stats = {hp = 8, mov = 4, def = 1, atk = 4}},
  {name = "noye", file = "noye.png", stats = {hp = 8, mov = 3, def = 3, atk = 3}},
  {name = "serpent acrobate", file = "serpent acrobate.png", stats = {hp = 5, mov = 6, def = 1, atk = 4}},
  {name = "serpentroche", file = "serpentroche.png", stats = {hp = 8, mov = 3, def = 3, atk = 3}},
  {name = "serpentsoleil", file = "serpentsoleil.png", stats = {hp = 5, mov = 4, def = 1, atk = 6}},
  {name = "trauma", file = "trauma.png", stats = {hp = 7, mov = 3, def = 2, atk = 5}},
  {name = "trauma2", file = "trauma2.png", stats = {hp = 8, mov = 3, def = 2, atk = 4}},
  {name = "trauma3", file = "trauma3.png", stats = {hp = 10, mov = 2, def = 2, atk = 4}},
}
local enemySpawnCount = 6

local function getBattleResultAlpha()
  return math.min(1, battleResultTimer / battleResultDuration)
end

local function hasLivingTeam(teamName)
  for _, character in ipairs(characters) do
    if character.team == teamName then
      return true
    end
  end
  return false
end

local function beginBattleResult(result)
  if battleResult then
    return
  end
  battleResult = result
  battleResultTimer = 0
end

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

local function generateSpawnPositions(count, columnStart, columnEnd, rowStart, rowEnd, anchorColumn, anchorRow, direction, minDistance)
  local positions = {}
  local blockedLookup = {}
  local separationDistance = minDistance or 2.6

  while #positions < count do
    local candidates = buildCandidates(columnStart, columnEnd, rowStart, rowEnd, blockedLookup, function(column, row)
      for _, position in ipairs(positions) do
        if tileDistance(column, row, position.column, position.row) < separationDistance then
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
  local enemyPool = shuffledCopy(enemyArchetypes)

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
    local enemyInfo = enemyPool[index]
    roster[#roster + 1] = Character.new(
      enemyInfo.name,
      "assets/sprites/mobs/" .. enemyInfo.file,
      spawn.column,
      spawn.row,
      enemyInfo.stats,
      spawn.direction,
      enemyInfo.name,
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
    currentTurn = math.max(1, math.min(currentTurn, #characters))
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
  battleResult = nil
  battleResultTimer = 0
  enemyTurnState = nil

  mapBackground = love.graphics.newImage("assets/map_bg2.png")
  tile = love.graphics.newImage("assets/sprites/hexa.png")
  cursor = love.graphics.newImage("assets/sprites/cursor.png")
  moveTile = love.graphics.newImage("assets/sprites/move.png")
  attackTile = love.graphics.newImage("assets/sprites/attack.png")
  thornsTile = love.graphics.newImage("assets/sprites/effects/thorns.png")
  algaeTile = love.graphics.newImage("assets/sprites/effects/algae.png")
  splashTile = love.graphics.newImage("assets/sprites/effects/splash.png")
  lifebar = Lifebar.new("assets/sprites/items/heart.png")
  tileW = tile:getWidth()
  tileH = tile:getHeight()
  tileSpacingX = tileW * 0.75
  tileSpacingY = tileH
  hudFont = love.graphics.newFont(28)
  resultFont = love.graphics.newFont("assets/fonts/ChildishFree 400.otf", 72)
  resultPromptFont = love.graphics.newFont(24)

  local playerSpawnPositions = generateSpawnPositions(playerSpawnCount, 5, 10, 6, 14, 8, 10, "right", 2.6)
  local enemySpawnPositions = generateSpawnPositions(enemySpawnCount, 11, 19, 3, 17, 15, 10, "left", 2.2)
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
  camera:setBounds(
    mapBackground:getWidth() * mapBackgroundScale,
    mapBackground:getHeight() * mapBackgroundScale
  )
end

function love.update(dt)
  if battleResult then
    battleResultTimer = math.min(battleResultDuration, battleResultTimer + dt)
    return
  end

  if battle then
    battle:update(dt)
    local completedActionCharacter = battle:consumeCompletedActionCharacter()
    if completedActionCharacter then
      advanceTurn(completedActionCharacter)
    end
    Menu:setPhase(battle:getTurnPhase())
  end

  if not hasLivingTeam("player") then
    beginBattleResult("game_over")
    return
  end
  if not hasLivingTeam("enemy") then
    beginBattleResult("victory")
    return
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
      if attackAnimation.kind == "splash" then
        tileX, tileY = gridToScreen(attackAnimation.centerColumn, attackAnimation.centerRow)
      else
        local attackerX, attackerY = Character.getAttackRenderState(attackAnimation.attacker, battle, gridToScreen, tileW)
        local targetX, targetY = Character.getAttackRenderState(attackAnimation.target, battle, gridToScreen, tileW)
        if attackerX and targetX then
          tileX = (attackerX + targetX) * 0.5
          tileY = (attackerY + targetY) * 0.5
        end
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
    love.graphics.draw(mapBackground, 0, 0, 0, mapBackgroundScale, mapBackgroundScale)
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

  if attackAnimation and attackAnimation.kind == "splash" and splashTile then
    local splashX, splashY = gridToScreen(attackAnimation.centerColumn, attackAnimation.centerRow)
    local splashRatio = math.min(1, attackAnimation.timer / (battle.attackWindupDuration + battle.attackLungeDuration))
    local splashScale = 0.6 + (0.4 * splashRatio)
    local splashAlpha = math.min(1, 0.35 + (0.65 * splashRatio))
    love.graphics.setColor(1, 1, 1, splashAlpha)
    love.graphics.draw(
      splashTile,
      splashX + (tileW * 0.5),
      splashY + (tileH * 0.5),
      0,
      ((tileW * 3) / splashTile:getWidth()) * splashScale,
      ((tileH * 3) / splashTile:getHeight()) * splashScale,
      splashTile:getWidth() * 0.5,
      splashTile:getHeight() * 0.5
    )
    love.graphics.setColor(1, 1, 1, 1)
  end

  if battle and thornsTile then
    local now = love.timer.getTime()
    for thornKey, createdAt in pairs(battle:getThorns()) do
      local commaIndex = thornKey:find(",")
      local column = tonumber(thornKey:sub(1, commaIndex - 1))
      local row = tonumber(thornKey:sub(commaIndex + 1))
      if column and row then
        local x, y = gridToScreen(column, row)
        local appearRatio = math.min(1, math.max(0, (now - createdAt) / terrainEffectAppearDuration))
        local effectScale = terrainEffectScale * (0.6 + (0.4 * appearRatio))
        local drawScaleX = (tileW / thornsTile:getWidth()) * effectScale
        local drawScaleY = (tileH / thornsTile:getHeight()) * effectScale
        local drawX = x + ((tileW - (thornsTile:getWidth() * drawScaleX)) * 0.5)
        local drawY = y + ((tileH - (thornsTile:getHeight() * drawScaleY)) * 0.5)
        love.graphics.setColor(1, 1, 1, appearRatio)
        love.graphics.draw(
          thornsTile,
          drawX,
          drawY,
          0,
          drawScaleX,
          drawScaleY
        )
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  if battle and algaeTile then
    local now = love.timer.getTime()
    for algaeKey, createdAt in pairs(battle:getAlgae()) do
      local commaIndex = algaeKey:find(",")
      local column = tonumber(algaeKey:sub(1, commaIndex - 1))
      local row = tonumber(algaeKey:sub(commaIndex + 1))
      if column and row then
        local x, y = gridToScreen(column, row)
        local appearRatio = math.min(1, math.max(0, (now - createdAt) / terrainEffectAppearDuration))
        local effectScale = terrainEffectScale * (0.6 + (0.4 * appearRatio))
        local drawScaleX = (tileW / algaeTile:getWidth()) * effectScale
        local drawScaleY = (tileH / algaeTile:getHeight()) * effectScale
        local drawX = x + ((tileW - (algaeTile:getWidth() * drawScaleX)) * 0.5)
        local drawY = y + ((tileH - (algaeTile:getHeight() * drawScaleY)) * 0.5)
        love.graphics.setColor(1, 1, 1, appearRatio)
        love.graphics.draw(
          algaeTile,
          drawX,
          drawY,
          0,
          drawScaleX,
          drawScaleY
        )
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

  local previousFont = love.graphics.getFont()
  if hudFont then
    love.graphics.setFont(hudFont)
  end

  if active then
    local hudText = string.format(
      "Turn %d: %s  HP:%d  MOV:%d  DEF:%d  ATK:%d  Phase: %s  Action: %s",
      currentTurn,
      active.name,
      active.hp,
      active.mov,
      active.def,
      active.atk,
      battle and battle:getTurnPhase() or "move",
      Menu:selectedAction()
    )
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(hudText, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(hudText, 10, 10)
  else
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("No active character", 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("No active character", 10, 10)
  end
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(previousFont)

  if battleResult then
    local alpha = getBattleResultAlpha()
    local previousFont = love.graphics.getFont()
    if resultFont then
      love.graphics.setFont(resultFont)
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local message = battleResult == "game_over" and "GAME OVER" or "VICTOIRE"
    local textWidth = love.graphics.getFont():getWidth(message)
    local textHeight = love.graphics.getFont():getHeight()
    local textX = (width - textWidth) * 0.5
    local textY = (height - textHeight) * 0.5

    if battleResult == "game_over" then
      love.graphics.setColor(0, 0, 0, alpha)
      love.graphics.rectangle("fill", 0, 0, width, height)
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.print(message, textX, textY)
    else
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.rectangle("fill", 0, 0, width, height)
      love.graphics.setColor(1, 0.45, 0.05, alpha)
      love.graphics.print(message, textX, textY)
    end

    local prompt = "Appuyez sur Entree pour recommencer"
    if resultPromptFont then
      love.graphics.setFont(resultPromptFont)
    end
    local promptWidth = love.graphics.getFont():getWidth(prompt)
    local promptX = (width - promptWidth) * 0.5
    local promptY = textY + textHeight + 28
    if battleResult == "game_over" then
      love.graphics.setColor(1, 1, 1, alpha)
    else
      love.graphics.setColor(0.15, 0.15, 0.15, alpha)
    end
    love.graphics.print(prompt, promptX, promptY)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(previousFont)
  end
end

function love.keypressed(key)
  local active = getActiveCharacter()
  local gameMode = battle and battle:getMode() or "menu"
  if key == "escape" then
    love.event.quit()
  elseif battleResult then
    if key == "return" or key == "kpenter" or key == "enter" then
      love.load()
    end
    return
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
