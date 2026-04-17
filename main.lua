local Character = require("character")
local Camera = require("camera")
local Menu = require("menu")
local Battle = require("battle")
local Lifebar = require("lifebar")
local Obstacle = require("obstacle")
local Effects = require("effects")
local Rules = require("rules")
local MapTheme = require("map_theme")

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
local provokedIcon = nil

local characterScale = 1.1
local characterFootOffsetY = 32
local characterRightOffsetX = 0
local camera = nil
local battle = nil
local effects = nil
local lifebar = nil
local enemyTurnState = nil
local pendingAdvanceTurn = nil
local mapBackgroundScale = 2.5
local hudFont = nil
local resultFont = nil
local resultPromptFont = nil
local battleResult = nil
local battleResultTimer = 0
local battleResultDuration = 1.0
local introFadeAlpha = 0
local introFadeDuration = 0.8
local slowMotionTimer = 0
local slowMotionScale = 1
local uiScale = 1
local uiReferenceWidth = 2256
local uiReferenceHeight = 1504
local isWeb = false
local windowInitialized = false
local generateSpawnPositions = nil
local generateObstaclePlacements = nil
local loadSprites = nil
local resetGame = nil
local titleState = {
  active = true,
  step = "mode",
  selectedIndex = 1,
  modeIndex = 1,
  mapIndex = 1,
}

local function isHumanControlledCharacter(character)
  return character ~= nil and (Rules.PVP or character.team == "player")
end

local enemyMovePreviewDelay = 0.9
local turnAdvanceDelay = 0.5
local enemyPostMoveDelay = 0.45
local enemyAttackPreviewDelay = 0.55
local enemySkipActionDelay = 0.3
local gamepadAxisThreshold = 0.45
local gamepadInitialRepeatDelay = 0.22
local gamepadRepeatDelay = 0.12
local gamepadHeldDirection = nil
local gamepadRepeatTimer = 0
local rumbleTimer = 0
local rumbleLow = 0
local rumbleHigh = 0
local allowGamepadRumble = true

local function computeUiScale(viewWidth, viewHeight)
  return math.min(viewWidth / uiReferenceWidth, viewHeight / uiReferenceHeight)
end

local function rebuildUi(viewWidth, viewHeight)
  uiScale = computeUiScale(viewWidth, viewHeight)
  hudFont = love.graphics.newFont(math.max(14, math.floor((28 * uiScale) + 0.5)))
  resultFont = love.graphics.newFont("assets/fonts/ChildishFree 400.otf", math.max(36, math.floor((72 * uiScale) + 0.5)))
  resultPromptFont = love.graphics.newFont(math.max(14, math.floor((24 * uiScale) + 0.5)))
  Menu:setUiScale(uiScale)
end

local function ensureWindowInitialized()
  if windowInitialized then
    return
  end

  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  if not isWeb then
    screenW, screenH = love.window.getDesktopDimensions(1)
    love.window.setMode(screenW, screenH, {
      fullscreen = true,
      fullscreentype = "desktop",
      highdpi = true,
    })
    screenW = love.graphics.getWidth()
    screenH = love.graphics.getHeight()
  end

  rebuildUi(screenW, screenH)
  windowInitialized = true
end

local function getTitleEntries()
  if titleState.step == "mode" then
    return { "Héros contre Monstres", "Héros contre Héros" }
  end
  return { "Forêt", "Marais" }
end

local function syncTitleSelection()
  titleState.modeIndex = Rules.PVP and 2 or 1
  titleState.mapIndex = Rules.SWAMP and 2 or 1
  titleState.selectedIndex = titleState.step == "mode" and titleState.modeIndex or titleState.mapIndex
end

local function openTitleScreen()
  titleState.active = true
  titleState.step = "mode"
  syncTitleSelection()
end

local function startGameFromTitleSelection()
  Rules:setPvp(titleState.modeIndex == 2)
  Rules:setSwamp(titleState.mapIndex == 2)
  titleState.active = false
  resetGame()
end

local function drawTitleScreen()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local heading = titleState.step == "mode" and "Choisissez un mode" or "Choisissez une carte"
  local entries = getTitleEntries()
  local titleFont = resultFont or love.graphics.getFont()
  local menuFont = hudFont or love.graphics.getFont()
  local hintFont = resultPromptFont or love.graphics.getFont()
  local previousFont = love.graphics.getFont()

  love.graphics.clear(1, 1, 1, 1)

  love.graphics.setFont(titleFont)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.print(heading, (width - titleFont:getWidth(heading)) * 0.5, height * 0.28)

  love.graphics.setFont(menuFont)
  local lineHeight = menuFont:getHeight()
  local rowHeight = lineHeight + math.floor((14 * uiScale) + 0.5)
  local padding = math.floor((16 * uiScale) + 0.5)
  local leftPadding = math.floor((28 * uiScale) + 0.5)
  local rightPadding = math.floor((28 * uiScale) + 0.5)
  local textWidth = 0
  for _, entry in ipairs(entries) do
    textWidth = math.max(textWidth, menuFont:getWidth(entry))
  end
  local menuWidth = textWidth + leftPadding + rightPadding + (padding * 2)
  local menuHeight = (#entries * rowHeight) + (padding * 2)
  local menuX = (width - menuWidth) * 0.5
  local menuY = height * 0.62
  local radius = math.max(12, math.floor((30 * uiScale) + 0.5))

  love.graphics.setColor(1, 1, 1, 0.96)
  love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, radius, radius, 24)
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight, radius, radius, 24)

  for i, entry in ipairs(entries) do
    local y = menuY + padding + (i - 1) * rowHeight
    if i == titleState.selectedIndex then
      local entryRadius = math.floor(rowHeight * 0.5)
      local insetX = math.floor((12 * uiScale) + 0.5)
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", menuX + insetX, y - math.floor((2 * uiScale) + 0.5), menuWidth - (insetX * 2), rowHeight, entryRadius, entryRadius, 24)
      love.graphics.setColor(1, 1, 1, 1)
    else
      love.graphics.setColor(0, 0, 0, 1)
    end
    love.graphics.print(entry, menuX + leftPadding, y + math.floor((5 * uiScale) + 0.5))
  end

  love.graphics.setFont(hintFont)
  local hint = titleState.step == "mode" and "Entrée pour continuer" or "Entrée pour lancer, Retour arrière pour revenir"
  love.graphics.setColor(0.15, 0.15, 0.15, 1)
  love.graphics.print(hint, (width - hintFont:getWidth(hint)) * 0.5, menuY + menuHeight + math.floor((22 * uiScale) + 0.5))

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(previousFont)
end

local function logViewport(label)
  local graphicsWidth, graphicsHeight = love.graphics.getDimensions()
  local windowWidth, windowHeight, flags = love.window.getMode()
  local zoom = camera and string.format("%.4f", camera.zoom) or "nil"
  local uiScaleText = string.format("%.4f", uiScale)
  flags = flags or {}
  print(string.format(
    "[%s] graphics=%dx%d window=%dx%d zoom=%s uiScale=%s highdpi=%s fullscreen=%s resizable=%s fullscreentype=%s",
    label,
    graphicsWidth,
    graphicsHeight,
    windowWidth,
    windowHeight,
    zoom,
    uiScaleText,
    tostring(flags.highdpi),
    tostring(flags.fullscreen),
    tostring(flags.resizable),
    tostring(flags.fullscreentype)
  ))
end

local function drawHudAvatar(character, x, y, diameter)
  local sprite = character and (character.faceSprite or character.sprite) or nil
  if not sprite then
    return
  end

  local spriteWidth = sprite:getWidth()
  local spriteHeight = sprite:getHeight()
  local radius = diameter * 0.5
  local centerX = x + radius
  local centerY = y + radius

  love.graphics.stencil(function()
    love.graphics.circle("fill", centerX, centerY, radius)
  end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)
  love.graphics.setColor(1, 1, 1, 1)

  if character.faceSprite then
    local drawScale = math.max(diameter / spriteWidth, diameter / spriteHeight)
    local drawWidth = spriteWidth * drawScale
    local drawHeight = spriteHeight * drawScale
    love.graphics.draw(sprite, x + (diameter - drawWidth) * 0.5, y + (diameter - drawHeight) * 0.5, 0, drawScale, drawScale)
  else
    local headCenterX = spriteWidth * 0.5
    local headCenterY = spriteHeight * 0.25
    local cropSize = math.min(spriteWidth * 0.72, spriteHeight * 0.52)
    local cropX = math.max(0, math.min(spriteWidth - cropSize, headCenterX - (cropSize * 0.5)))
    local cropY = math.max(0, math.min(spriteHeight - cropSize, headCenterY - (cropSize * 0.5)))
    local quad = love.graphics.newQuad(cropX, cropY, cropSize, cropSize, spriteWidth, spriteHeight)
    love.graphics.draw(sprite, quad, x, y, 0, diameter / cropSize, diameter / cropSize)
  end

  love.graphics.setStencilTest()
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.circle("line", centerX, centerY, radius)
  love.graphics.setColor(1, 1, 1, 1)
end

local function buildCharacterPillLines(character, showTeam)
  local className = character.displayClassName or character.className or "Inconnu"
  local line1 = nil
  if character.team == "enemy" then
    line1 = className
  else
    local displayName = Character.getDisplayName(character)
    line1 = showTeam and string.format("%s  %s (%s)", Character.getTeamDisplayName(character.team), displayName, className) or string.format("%s (%s)", displayName, className)
  end
  local line2 = string.format("HP:%d  MOV:%d  DEF:%d  ATK:%d", character.hp, character.mov, character.def, character.atk)
  return line1, line2
end

local function drawCharacterPill(character, boxX, boxY, alignRight, showTeam)
  if not character then
    return
  end

  local font = love.graphics.getFont()
  local line1, line2 = buildCharacterPillLines(character, showTeam)
  local lineHeight = font:getHeight()
  local lineGap = math.floor((2 * uiScale) + 0.5)
  local paddingX = math.floor((18 * uiScale) + 0.5)
  local paddingY = math.floor((10 * uiScale) + 0.5)
  local textBlockHeight = (lineHeight * 2) + lineGap
  local boxHeight = textBlockHeight + (paddingY * 2)
  local avatarInset = math.floor((5 * uiScale) + 0.5)
  local avatarSize = boxHeight - (avatarInset * 2)
  local avatarSpacing = math.floor((14 * uiScale) + 0.5)
  local textWidth = math.max(font:getWidth(line1), font:getWidth(line2))
  local extraRightPadding = math.floor((10 * uiScale) + 0.5)
  local boxWidth = textWidth + (paddingX * 2) + avatarSize + avatarSpacing + extraRightPadding
  local radius = math.floor(boxHeight * 0.5)

  if alignRight then
    boxX = boxX - boxWidth
  end

  local textX = boxX + paddingX + avatarSize + avatarSpacing
  local textY = boxY + paddingY

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, radius, radius)
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, radius, radius)
  drawHudAvatar(character, boxX + avatarInset, boxY + avatarInset, avatarSize)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.print(line1, textX, textY)
  love.graphics.print(line2, textX, textY + lineHeight + lineGap)
end

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
  {name = "affame", file = "affame.png", stats = {hp = 7, mov = 4, def = 1, atk = 5, attackRange = 2}},
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

local function getEnemyArchetypesForTheme()
  if not Rules.SWAMP then
    return enemyArchetypes
  end

  local filtered = {}
  for _, enemyInfo in ipairs(enemyArchetypes) do
    if enemyInfo.name ~= "loup3" then
      filtered[#filtered + 1] = enemyInfo
    end
  end
  return filtered
end

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

local function getWinningTeam()
  if hasLivingTeam("player") and not hasLivingTeam("enemy") then
    return "player"
  end
  if hasLivingTeam("enemy") and not hasLivingTeam("player") then
    return "enemy"
  end
  return nil
end

local function beginBattleResult(result)
  if battleResult then
    return
  end
  battleResult = result
  battleResultTimer = 0
end

resetGame = function()
  love.graphics.setBackgroundColor(1, 1, 1)
  math.randomseed(os.time())
  battleResult = nil
  battleResultTimer = 0
  introFadeAlpha = 1
  enemyTurnState = nil
  pendingAdvanceTurn = nil
  currentTurn = 1
  slowMotionTimer = 0
  slowMotionScale = 1
  map = {}
  obstacles = {}
  characters = {}

  mapBackground = love.graphics.newImage(MapTheme.getBackgroundPath())
  tile = love.graphics.newImage("assets/sprites/hexa.png")
  cursor = love.graphics.newImage("assets/sprites/cursor.png")
  moveTile = love.graphics.newImage("assets/sprites/move.png")
  attackTile = love.graphics.newImage("assets/sprites/attack.png")
  provokedIcon = love.graphics.newImage("assets/sprites/effects/provoked.png")
  effects = Effects.new()
  effects:load()
  lifebar = Lifebar.new("assets/sprites/items/heart.png")
  tileW = tile:getWidth()
  tileH = tile:getHeight()
  tileSpacingX = tileW * 0.75
  tileSpacingY = tileH
  local activeEnemySpawnCount = Rules.PVP and playerSpawnCount or enemySpawnCount
  local playerSpawnPositions = generateSpawnPositions(playerSpawnCount, 5, 10, 6, 14, 8, 10, "right", 2.6)
  local enemySpawnPositions = generateSpawnPositions(activeEnemySpawnCount, 11, 19, 3, 17, 15, 10, "left", 2.2)
  local obstaclePlacements = generateObstaclePlacements(playerSpawnPositions, enemySpawnPositions)

  for c = 1, cols do
    map[c] = {}
    for r = 1, rows do
      map[c][r] = true
    end
  end

  for _, obstaclePlacement in ipairs(obstaclePlacements) do
    map[obstaclePlacement.column][obstaclePlacement.row] = false
    obstacles[#obstacles + 1] = Obstacle.randomOfKind(
      obstaclePlacement.kind,
      obstaclePlacement.column,
      obstaclePlacement.row
    )
  end

  battle = Battle.new(cols, rows, map)
  battle:setEffects(effects)
  battle:startTurn()
  characters = loadSprites(playerSpawnPositions, enemySpawnPositions)
  battle:setCharacters(characters)

  ensureWindowInitialized()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  camera = Camera.new(screenW, screenH)
  camera:setViewSize(love.graphics.getWidth(), love.graphics.getHeight())
  camera:setBounds(
    mapBackground:getWidth() * mapBackgroundScale,
    mapBackground:getHeight() * mapBackgroundScale
  )
  local active = characters[currentTurn]
  if active then
    local tileX = (active.column - 1) * tileSpacingX
    local tileY = (active.row - 1) * tileSpacingY
    if active.column % 2 == 1 then
      tileY = tileY + (tileH * 0.5)
    end
    local focusX = tileX + (tileW * 0.5)
    local focusY = tileY + (tileH * 0.5)
    camera:setTarget(focusX, focusY)
    camera.x = camera.targetX
    camera.y = camera.targetY
  end

  Menu:reset()
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

generateSpawnPositions = function(count, columnStart, columnEnd, rowStart, rowEnd, anchorColumn, anchorRow, direction, minDistance)
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

generateObstaclePlacements = function(playerSpawnPositions, enemySpawnPositions)
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

loadSprites = function(playerSpawnPositions, enemySpawnPositions)
  local roster = {}

  if Rules.PVP then
    local function addHeroTeam(spawnPositions, teamName)
      local classPool = shuffledCopy(availableClasses)

      for index, spawn in ipairs(spawnPositions) do
        local classInfo = classPool[index]
        local spriteName = classInfo.sprites[math.random(#classInfo.sprites)]
        local spritePath = "assets/sprites/heroes/" .. spriteName .. ".png"
        local givenName = Character.getHeroFirstName(classInfo.className, spritePath) or (classInfo.className .. "_" .. teamName .. "_" .. index)
        roster[#roster + 1] = Character.new(
          givenName,
          spritePath,
          spawn.column,
          spawn.row,
          Character.rollHeroStats(classInfo.className),
          spawn.direction,
          classInfo.className,
          teamName
        )
      end
    end

    addHeroTeam(playerSpawnPositions, "player")
    addHeroTeam(enemySpawnPositions, "enemy")
    return roster
  end

  local classPool = shuffledCopy(availableClasses)
  local enemyPool = shuffledCopy(getEnemyArchetypesForTheme())

  for index, spawn in ipairs(playerSpawnPositions) do
    local classInfo = classPool[index]
    local spriteName = classInfo.sprites[math.random(#classInfo.sprites)]
    local spritePath = "assets/sprites/heroes/" .. spriteName .. ".png"
    local givenName = Character.getHeroFirstName(classInfo.className, spritePath) or (classInfo.className .. "_" .. index)
    roster[#roster + 1] = Character.new(
      givenName,
      spritePath,
      spawn.column,
      spawn.row,
      Character.rollHeroStats(classInfo.className),
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

local function advanceTurn(activeCharacter)
  if #characters == 0 then
    currentTurn = 1
    if battle then
      battle:startTurn(nil)
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
    if currentTurn > #characters then
      currentTurn = 1
    else
      currentTurn = math.max(1, currentTurn)
    end
  end

  if battle then
    battle:startTurn(characters[currentTurn])
  end
  enemyTurnState = nil
  pendingAdvanceTurn = nil
  Menu:reset()
end

local function getActiveGamepad()
  local joysticks = love.joystick.getJoysticks()
  for _, joystick in ipairs(joysticks) do
    if joystick:isGamepad() and joystick:isVibrationSupported() then
      return joystick
    end
  end
  return nil
end

local function pulseRumble(low, high, duration)
  if not allowGamepadRumble then
    return
  end
  local joystick = getActiveGamepad()
  if not joystick then
    return
  end
  rumbleLow = low or 0
  rumbleHigh = high or 0
  rumbleTimer = duration or 0.08
  joystick:setVibration(rumbleLow, rumbleHigh)
end

local function handleDirectionalInput(direction)
  if titleState.active then
    local entries = getTitleEntries()
    if direction == "up" then
      titleState.selectedIndex = math.max(1, titleState.selectedIndex - 1)
    elseif direction == "down" then
      titleState.selectedIndex = math.min(#entries, titleState.selectedIndex + 1)
    end
    return
  end

  local active = getActiveCharacter()
  local gameMode = battle and battle:getMode() or "menu"
  if pendingAdvanceTurn or battleResult or not active or not isHumanControlledCharacter(active) or (battle and battle:isAnimating()) then
    return
  end

  if gameMode == "move" then
    battle:moveTargetByKey(direction)
    pulseRumble(0.08, 0.04, 0.05)
  elseif gameMode == "heal" then
    battle:moveHealTargetByKey(active, direction)
    pulseRumble(0.08, 0.04, 0.05)
  elseif gameMode == "tank" then
    return
  elseif gameMode == "grapple" then
    battle:moveGrappleTargetByKey(active, direction)
    pulseRumble(0.08, 0.04, 0.05)
  elseif gameMode == "order_target" then
    battle:moveOrderTargetByKey(direction)
    pulseRumble(0.08, 0.04, 0.05)
  elseif gameMode == "order_move" then
    battle:moveOrderMoveTargetByKey(direction)
    pulseRumble(0.08, 0.04, 0.05)
  elseif gameMode == "attack" then
    battle:moveAttackTargetByKey(active, direction)
    pulseRumble(0.08, 0.04, 0.05)
  else
    if direction == "up" then
      Menu:prev()
      pulseRumble(0.07, 0.03, 0.05)
    elseif direction == "down" then
      Menu:next()
      pulseRumble(0.07, 0.03, 0.05)
    end
  end
end

local function handleConfirmInput()
  local active = getActiveCharacter()
  local gameMode = battle and battle:getMode() or "menu"
  if titleState.active then
    if titleState.step == "mode" then
      titleState.modeIndex = titleState.selectedIndex
      titleState.step = "map"
      titleState.selectedIndex = titleState.mapIndex
    else
      titleState.mapIndex = titleState.selectedIndex
      startGameFromTitleSelection()
    end
    return
  end
  if battleResult then
    resetGame()
    return
  end
  if pendingAdvanceTurn or not active or not isHumanControlledCharacter(active) or (battle and battle:isAnimating()) then
    return
  end

  if gameMode == "move" then
    local didMove = battle and battle:confirmMove(active)
    if didMove then
      Menu:reset()
    end
  elseif gameMode == "heal" then
    if battle and battle:confirmHeal(active) then
      Menu:reset()
    end
  elseif gameMode == "tank" then
    if battle and battle:confirmTank(active) then
      Menu:reset()
    end
  elseif gameMode == "grapple" then
    if battle and battle:confirmGrapple(active) then
      Menu:reset()
    end
  elseif gameMode == "order_target" or gameMode == "order_move" then
    if battle and battle:confirmOrder(active) then
      Menu:reset()
    end
  elseif gameMode == "attack" then
    if battle then
      battle:confirmAttack(active)
    end
  else
    local selectedAction = Menu:selectedAction()
    if battle and battle:getTurnPhase() == "move" then
      if Menu:isMoveSelected() then
        battle:startMoveSelection(active)
      elseif selectedAction == "Tank" then
        if battle:startTankSelection(active) then
          Menu:reset()
        end
      elseif selectedAction == "Se battre" then
        if battle:beginActionFirstTurn(active) then
          Menu:reset()
        end
      elseif selectedAction == "Soigner" then
        if battle:startHealSelection(active) then
          Menu:reset()
        end
      elseif selectedAction == "Rester ici" then
        if battle:hasActionSpent() then
          advanceTurn(active)
        else
          battle:startActionPhase()
        end
      end
    elseif battle and battle:getTurnPhase() == "action" then
      if selectedAction == "Se battre" then
        if not battle:startAttackSelection(active) then
          battle:completeAction(active)
        end
      elseif selectedAction == "Grapin" then
        if battle:startGrappleSelection(active) then
          Menu:reset()
        end
      elseif selectedAction == "Ordonner" then
        if battle:startOrderSelection(active) then
          Menu:reset()
        end
      elseif selectedAction == "Passer son tour" then
        battle:completeAction(active)
      end
    end
  end
end

local function handleCancelInput()
  local active = getActiveCharacter()
  local gameMode = battle and battle:getMode() or "menu"
  if titleState.active then
    if titleState.step == "map" then
      titleState.step = "mode"
      titleState.selectedIndex = titleState.modeIndex
    end
    return
  end

  if pendingAdvanceTurn or battleResult or not active or not isHumanControlledCharacter(active) or (battle and battle:isAnimating()) then
    return
  end

  if gameMode == "move" then
    battle:cancelMoveMode()
    Menu:reset()
  elseif gameMode == "heal" then
    battle:cancelHealMode()
    Menu:reset()
  elseif gameMode == "tank" then
    battle:setMode("menu")
    Menu:reset()
  elseif gameMode == "grapple" then
    battle:cancelGrappleMode()
    Menu:reset()
  elseif gameMode == "order_target" or gameMode == "order_move" then
    battle:cancelOrderMode()
    Menu:reset()
  elseif gameMode == "attack" then
    battle:cancelAttackMode()
    Menu:reset()
  end
end

local function readGamepadDirection()
  local joysticks = love.joystick.getJoysticks()
  for _, joystick in ipairs(joysticks) do
    if joystick:isGamepad() then
      local x = joystick:getGamepadAxis("leftx")
      local y = joystick:getGamepadAxis("lefty")
      if math.abs(x) >= gamepadAxisThreshold or math.abs(y) >= gamepadAxisThreshold then
        if math.abs(x) > math.abs(y) then
          return x < 0 and "left" or "right"
        else
          return y < 0 and "up" or "down"
        end
      end
      break
    end
  end
  return nil
end

function love.load()
  isWeb = love.system.getOS() == "Web"
  allowGamepadRumble = not isWeb
  ensureWindowInitialized()
  openTitleScreen()
  logViewport("load")
end

function love.update(dt)
  if allowGamepadRumble and rumbleTimer > 0 then
    rumbleTimer = math.max(0, rumbleTimer - dt)
    if rumbleTimer <= 0 then
      local joystick = getActiveGamepad()
      if joystick then
        joystick:setVibration(0, 0)
      end
      rumbleLow = 0
      rumbleHigh = 0
    end
  end

  if slowMotionTimer > 0 then
    slowMotionTimer = math.max(0, slowMotionTimer - dt)
    if slowMotionTimer <= 0 then
      slowMotionScale = 1
    end
  end
  local updateDt = dt * slowMotionScale

  if introFadeAlpha > 0 then
    introFadeAlpha = math.max(0, introFadeAlpha - (dt / introFadeDuration))
  end

  if battleResult then
    battleResultTimer = math.min(battleResultDuration, battleResultTimer + dt)
    return
  end

  if pendingAdvanceTurn then
    pendingAdvanceTurn.timer = math.max(0, pendingAdvanceTurn.timer - dt)
    if pendingAdvanceTurn.timer <= 0 then
      local completedActionCharacter = pendingAdvanceTurn.character
      pendingAdvanceTurn = nil
      advanceTurn(completedActionCharacter)
    else
      return
    end
  end

  local gamepadDirection = readGamepadDirection()
  if gamepadDirection ~= gamepadHeldDirection then
    gamepadHeldDirection = gamepadDirection
    gamepadRepeatTimer = 0
    if gamepadDirection then
      handleDirectionalInput(gamepadDirection)
      gamepadRepeatTimer = gamepadInitialRepeatDelay
    end
  elseif gamepadHeldDirection then
    gamepadRepeatTimer = gamepadRepeatTimer - dt
    if gamepadRepeatTimer <= 0 then
      handleDirectionalInput(gamepadHeldDirection)
      gamepadRepeatTimer = gamepadRepeatDelay
    end
  end

  if titleState.active then
    return
  end

  if battle then
    battle:update(updateDt)
    local screenShake = battle:consumeScreenShake()
    if screenShake and camera then
      camera:startShake(screenShake.duration, screenShake.amplitude)
      pulseRumble(0.45, 0.8, math.min(0.22, screenShake.duration or 0.22))
    end
    local slowMotion = battle:consumeSlowMotion()
    if slowMotion then
      slowMotionTimer = slowMotion.duration
      slowMotionScale = slowMotion.scale
    end
    local completedActionCharacter = battle:consumeCompletedActionCharacter()
    if completedActionCharacter then
      pendingAdvanceTurn = {
        character = completedActionCharacter,
        timer = turnAdvanceDelay,
      }
    end
    Menu:setPhase(battle:getTurnPhase())
  end

  if Rules.PVP then
    local winningTeam = getWinningTeam()
    if winningTeam then
      beginBattleResult(winningTeam)
      return
    end
  else
    if not hasLivingTeam("player") then
      beginBattleResult("game_over")
      return
    end
    if not hasLivingTeam("enemy") then
      beginBattleResult("victory")
      return
    end
  end

  local active = getActiveCharacter()
  Menu:setCanHeal(active and battle and battle:getTurnPhase() == "move" and battle:isHealer(active))
  Menu:setCanTank(active and battle and battle:getTurnPhase() == "move" and battle:isTank(active))
  Menu:setCanActionFirst(
    active
    and battle
    and battle:getTurnPhase() == "move"
    and battle:isActionFirstCapable(active)
    and not battle:hasActionSpent()
  )
  Menu:setCanGrapple(active and battle and battle:getTurnPhase() == "action" and battle:isGrappler(active))
  Menu:setCanOrder(active and battle and battle:getTurnPhase() == "action" and battle:isTactician(active))
  if not Rules.PVP and active and battle and active.team == "enemy" and not battle:isAnimating() then
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
  elseif enemyTurnState and (Rules.PVP or not active or active.team ~= "enemy") then
    enemyTurnState = nil
  end

  if active then
    local gameMode = battle and battle:getMode() or "menu"
    local focusColumn = active.column
    local focusRow = active.row
    if gameMode == "move" or gameMode == "attack" or gameMode == "heal" or gameMode == "grapple" or gameMode == "order_target" or gameMode == "order_move" then
      focusColumn, focusRow = battle:getCursorColumnRow(active)
    end

    local tileX, tileY = gridToScreen(focusColumn, focusRow)
    if gameMode == "animating" then
      local moveAnimation = battle and battle:getMoveAnimation() or nil
      local movingCharacter = moveAnimation and moveAnimation.character or active
      local animatedX, animatedY = Character.getMoveRenderState(movingCharacter, battle, gridToScreen)
      if animatedX then
        tileX = animatedX
        tileY = animatedY
      end
    elseif battle and battle:getGrappleAnimation() then
      local grappleAnimation = battle:getGrappleAnimation()
      local grappleX, grappleY = Character.getGrappleRenderState(grappleAnimation.target, battle, gridToScreen)
      if grappleX then
        tileX = grappleX
        tileY = grappleY
      end
    elseif battle and battle:getHealAnimation() then
      local activeHealAnimation = battle:getHealAnimation()
      tileX, tileY = gridToScreen(activeHealAnimation.target.column, activeHealAnimation.target.row)
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
  rebuildUi(width, height)
  if camera then
    camera:setViewSize(width, height)
  end
  logViewport("resize")
end

function love.draw()
  if titleState.active then
    drawTitleScreen()
    if introFadeAlpha > 0 then
      local width = love.graphics.getWidth()
      local height = love.graphics.getHeight()
      love.graphics.setColor(1, 1, 1, introFadeAlpha)
      love.graphics.rectangle("fill", 0, 0, width, height)
      love.graphics.setColor(1, 1, 1, 1)
    end
    return
  end

  local active = getActiveCharacter()
  local hoveredCharacter = nil
  local showHoveredTargetPill = false
  local attackAnimation = battle and battle:getAttackAnimation() or nil
  local healAnimation = battle and battle:getHealAnimation() or nil
  if attackAnimation then
    hoveredCharacter = attackAnimation.target
    showHoveredTargetPill = hoveredCharacter ~= nil
  elseif healAnimation then
    hoveredCharacter = healAnimation.target
  elseif active and isHumanControlledCharacter(active) and not (battle and battle:isAnimating()) then
    local hoverColumn = active.column
    local hoverRow = active.row
    if battle and (battle:isMoveMode() or battle:isAttackMode() or battle:isHealMode() or battle:isTankMode() or battle:isGrappleMode() or battle:isOrderTargetMode() or battle:isOrderMoveMode()) then
      hoverColumn, hoverRow = battle:getCursorColumnRow(active)
    end
    hoveredCharacter = Character.getAtTile(characters, hoverColumn, hoverRow)
    showHoveredTargetPill = battle and (battle:isAttackMode() or battle:isTankMode() or battle:isGrappleMode()) or false
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
        local glow = 0.58 + 0.12 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(moveTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      elseif active and battle and battle:isAttackMode() and battle:isAttackable(c, r) then
        local glow = 0.58 + 0.12 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(attackTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      elseif active and battle and battle:isTankMode() and battle:getTankRange()[c .. "," .. r] then
        local glow = 0.58 + 0.12 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(attackTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      elseif active and battle and battle:isGrappleMode() and battle:isInGrappleRange(c, r) then
        local glow = 0.58 + 0.12 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(attackTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      elseif active and battle and battle:isOrderTargetMode() and battle:isOrderable(c, r) then
        local glow = 0.58 + 0.12 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(attackTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      elseif active and battle and battle:isOrderMoveMode() and battle:isOrderMoveReachable(c, r) then
        local glow = 0.58 + 0.12 * math.cos(love.timer.getTime() * 4)
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.draw(moveTile, x, y)
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  if effects and battle then
    effects:drawWorld(battle, gridToScreen, tileW, tileH, love.timer.getTime())
  end

  if active and isHumanControlledCharacter(active) and not (battle and battle:isAnimating()) then
    local cursorX, cursorY
    if battle and battle:isTankMode() then
      cursorX = nil
      cursorY = nil
    elseif battle and (battle:isMoveMode() or battle:isAttackMode() or battle:isHealMode() or battle:isGrappleMode() or battle:isOrderTargetMode() or battle:isOrderMoveMode()) then
      local targetColumn, targetRow = battle:getCursorColumnRow(active)
      cursorX, cursorY = gridToScreen(targetColumn, targetRow)
    else
      cursorX, cursorY = gridToScreen(active.column, active.row)
    end
    if cursorX and cursorY then
      love.graphics.draw(cursor, cursorX, cursorY)
    end
    if battle and battle:isTankMode() then
      for _, character in ipairs(characters) do
        if battle:isTankTarget(character.column, character.row) then
          local targetCursorX, targetCursorY = gridToScreen(character.column, character.row)
          love.graphics.draw(cursor, targetCursorX, targetCursorY)
        end
      end
    end
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
  if provokedIcon then
    for _, entry in ipairs(characterDrawList) do
      local character = entry.character
        if character.forcedTarget ~= nil then
          local iconScale = (tileW * 0.16) / provokedIcon:getWidth()
          local iconX = entry.x + (tileW * 0.78)
          local iconY = entry.y - (tileH * 0.22) - entry.jumpOffset
          love.graphics.setColor(1, 0.85, 0.92, entry.alpha or 1)
        love.graphics.draw(
          provokedIcon,
          iconX,
          iconY,
          0,
          iconScale,
          iconScale,
          provokedIcon:getWidth() * 0.5,
          provokedIcon:getHeight() * 0.5
        )
        love.graphics.setColor(1, 1, 1, 1)
      end
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
  if not pendingAdvanceTurn and active and isHumanControlledCharacter(active) and not isAnimating and (not battle or battle:getMode() == "menu") then
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
    local boxX = math.floor((10 * uiScale) + 0.5)
    local boxY = math.floor((10 * uiScale) + 0.5)
    drawCharacterPill(active, boxX, boxY, false, Rules.PVP)

    if showHoveredTargetPill and hoveredCharacter and hoveredCharacter ~= active and hoveredCharacter.team ~= active.team then
      local screenWidth = love.graphics.getWidth()
      local rightMargin = math.floor((10 * uiScale) + 0.5)
      drawCharacterPill(hoveredCharacter, screenWidth - rightMargin, boxY, true, false)
    end
  else
    local font = love.graphics.getFont()
    local text = "No active character"
    local paddingX = math.floor((18 * uiScale) + 0.5)
    local paddingY = math.floor((12 * uiScale) + 0.5)
    local boxX = math.floor((10 * uiScale) + 0.5)
    local boxY = math.floor((10 * uiScale) + 0.5)
    local boxWidth = font:getWidth(text) + (paddingX * 2)
    local boxHeight = font:getHeight() + (paddingY * 2)
    local radius = math.floor(boxHeight * 0.5)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, radius, radius)
    love.graphics.setColor(0, 0, 0, 0.18)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, radius, radius)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(text, boxX + paddingX, boxY + paddingY)
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
    local message = battleResult == "game_over" and "GAME OVER" or (battleResult == "victory" and "VICTOIRE" or (battleResult == "player" and "L'EQUIPE BLEUE GAGNE" or "L'EQUIPE ROUGE GAGNE"))
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
      if battleResult == "player" then
        love.graphics.setColor(0.12, 0.48, 1, alpha)
      elseif battleResult == "enemy" then
        love.graphics.setColor(0.9, 0.18, 0.18, alpha)
      else
        love.graphics.setColor(1, 0.45, 0.05, alpha)
      end
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

  if introFadeAlpha > 0 then
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    love.graphics.setColor(1, 1, 1, introFadeAlpha)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
    return
  elseif key == "return" or key == "kpenter" or key == "enter" then
    handleConfirmInput()
    return
  elseif key == "backspace" then
    handleCancelInput()
    return
  end

  if titleState.active then
    if key == "up" or key == "down" then
      handleDirectionalInput(key)
    elseif key == "1" then
      titleState.selectedIndex = 1
    elseif key == "2" then
      titleState.selectedIndex = 2
    end
    return
  end

  local active = getActiveCharacter()
  local gameMode = battle and battle:getMode() or "menu"
  if pendingAdvanceTurn or battleResult then
    return
  elseif active and not isHumanControlledCharacter(active) then
    -- disable player input during AI turns
  elseif battle and battle:isAnimating() then
    -- disable input during animations
  elseif gameMode == "move" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle then
        battle:moveTargetByKey(key)
      end
    end
  elseif gameMode == "heal" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle and active then
        battle:moveHealTargetByKey(active, key)
      end
    end
  elseif gameMode == "tank" then
  elseif gameMode == "grapple" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle and active then
        battle:moveGrappleTargetByKey(active, key)
      end
    end
  elseif gameMode == "order_target" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle then
        battle:moveOrderTargetByKey(key)
      end
    end
  elseif gameMode == "order_move" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle then
        battle:moveOrderMoveTargetByKey(key)
      end
    end
  elseif gameMode == "attack" then
    if key == "left" or key == "right" or key == "up" or key == "down" then
      if battle and active then
        battle:moveAttackTargetByKey(active, key)
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

function love.gamepadpressed(joystick, button)
  if not joystick:isGamepad() then
    return
  end

  if button == "a" then
    handleConfirmInput()
  elseif button == "b" then
    handleCancelInput()
  elseif button == "dpleft" then
    handleDirectionalInput("left")
  elseif button == "dpright" then
    handleDirectionalInput("right")
  elseif button == "dpup" then
    handleDirectionalInput("up")
  elseif button == "dpdown" then
    handleDirectionalInput("down")
  end
end
