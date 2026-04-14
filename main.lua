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
local attackTile = nil
local stoneTile = nil

local characterScale = 1.0
local characterFootOffsetY = 32
local characterRightOffsetX = 0
local camera = nil
local battle = nil

local map = {}
local obstacleTiles = {
  {column = 3, row = 2},
  {column = 3, row = 3},
  {column = 3, row = 4},
  {column = 4, row = 2},
  {column = 4, row = 3},
  {column = 4, row = 4},
}
local characters = {}
local currentTurn = 1

local function loadSprites()
  return {
    Character.new("tank_girl", "assets/sprites/heroes/tank_girl.png", 2, 3, Character.rollStats(16), "right"),
    Character.new("tank_boy", "assets/sprites/heroes/tank_boy.png", 5, 3, Character.rollStats(16), "left"),
    Character.new("archer_boy", "assets/sprites/heroes/archer_boy.png", 8, 3, Character.rollStats(16), "right"),
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
  Menu:reset()
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

local function getAttackAnimationRenderState(character)
  if not battle then
    return nil
  end

  local animation = battle:getAttackAnimation()
  if not animation then
    return nil
  end

  local baseX, baseY = gridToScreen(character.column, character.row)

  if character == animation.attacker then
    local targetX, targetY = gridToScreen(animation.target.column, animation.target.row)
    local dx = targetX - baseX
    local dy = targetY - baseY
    local distance = math.sqrt((dx * dx) + (dy * dy))
    if distance <= 0 then
      return baseX, baseY, 0
    end

    local directionX = dx / distance
    local directionY = dy / distance
    local windupOffset = math.min(tileW * 0.18, distance * 0.18)
    local maxOffset = math.min(tileW * 0.42, distance * 0.42)
    local offset = 0
    local timer = animation.timer

    if timer < battle.attackWindupDuration then
      offset = -windupOffset * (timer / battle.attackWindupDuration)
    elseif timer < battle.attackWindupDuration + battle.attackLungeDuration then
      local lungeTimer = timer - battle.attackWindupDuration
      local lungeRatio = lungeTimer / battle.attackLungeDuration
      offset = -windupOffset + ((maxOffset + windupOffset) * lungeRatio)
    elseif timer < battle.attackWindupDuration + battle.attackLungeDuration + battle.attackImpactDuration then
      offset = maxOffset
    elseif timer < battle.attackWindupDuration + battle.attackLungeDuration + battle.attackImpactDuration + battle.attackRetreatDuration then
      local retreatTimer = timer - battle.attackWindupDuration - battle.attackLungeDuration - battle.attackImpactDuration
      offset = maxOffset * (1 - (retreatTimer / battle.attackRetreatDuration))
    end

    return baseX + (directionX * offset), baseY + (directionY * offset), 0
  end

  if character == animation.target then
    local attackerX, attackerY = gridToScreen(animation.attacker.column, animation.attacker.row)
    local dx = baseX - attackerX
    local dy = baseY - attackerY
    local distance = math.sqrt((dx * dx) + (dy * dy))
    local directionX = distance > 0 and (dx / distance) or 1
    local directionY = distance > 0 and (dy / distance) or 0
    local shakeTimer = animation.timer - battle.attackWindupDuration - battle.attackLungeDuration
    local shakeDuration = battle.attackImpactDuration + battle.attackRetreatDuration

    if animation.applied and shakeTimer >= 0 and shakeTimer <= shakeDuration then
      local intensity = 16 * (1 - (shakeTimer / shakeDuration))
      local oscillation = math.sin(shakeTimer * 75)
      return baseX + (directionX * intensity * oscillation), baseY + (directionY * intensity * oscillation * 0.6), 0
    end

    return baseX, baseY, 0
  end

  return nil
end

local function getDeathAnimationRenderState(character)
  if not battle then
    return nil
  end

  local animation = battle:getDeathAnimation()
  if not animation or character ~= animation.character then
    return nil
  end

  local baseX, baseY = gridToScreen(character.column, character.row)
  local ratio = math.min(1, animation.timer / battle.deathDuration)
  local rise = 72 * ratio
  local flipScaleX = math.cos(ratio * math.pi * 3)
  local alpha = 1 - ratio

  return baseX, baseY - rise, 0, flipScaleX, alpha
end

local function getCharacterRenderState(character)
  local x, y, jumpOffset, scaleXFactor, alpha = getDeathAnimationRenderState(character)
  if x then
    return x, y, jumpOffset, scaleXFactor, alpha
  end

  x, y, jumpOffset = getAnimationRenderState(character)
  if x then
    return x, y, jumpOffset, 1, 1
  end

  x, y, jumpOffset = getAttackAnimationRenderState(character)
  if x then
    return x, y, jumpOffset or 0, 1, 1
  end

  return nil
end

function love.load()
  love.graphics.setBackgroundColor(1, 1, 1)
  math.randomseed(os.time())

  tile = love.graphics.newImage("assets/sprites/hexa.png")
  stoneTile = love.graphics.newImage("assets/sprites/stone.png")
  cursor = love.graphics.newImage("assets/sprites/cursor.png")
  moveTile = love.graphics.newImage("assets/sprites/move.png")
  attackTile = love.graphics.newImage("assets/sprites/attack.png")
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
  battle:startTurn()

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
    local completedActionCharacter = battle:consumeCompletedActionCharacter()
    if completedActionCharacter then
      advanceTurn(completedActionCharacter)
    end
    Menu:setPhase(battle:getTurnPhase())
  end

  local active = getActiveCharacter()
  if active then
    local gameMode = battle and battle:getMode() or "menu"
    local focusColumn = active.column
    local focusRow = active.row
    if gameMode == "move" or gameMode == "attack" then
      focusColumn, focusRow = battle:getCursorColumnRow(active)
    end

    local tileX, tileY = gridToScreen(focusColumn, focusRow)
    if gameMode == "animating" then
      local animatedX, animatedY = getAnimationRenderState(active)
      if animatedX then
        tileX = animatedX
        tileY = animatedY
      end
    elseif battle and battle:getAttackAnimation() then
      local attackAnimation = battle:getAttackAnimation()
      local attackerX, attackerY = getAttackAnimationRenderState(attackAnimation.attacker)
      local targetX, targetY = getAttackAnimationRenderState(attackAnimation.target)
      if attackerX and targetX then
        tileX = (attackerX + targetX) * 0.5
        tileY = (attackerY + targetY) * 0.5
      end
    elseif battle and battle:getDeathAnimation() then
      local deathAnimation = battle:getDeathAnimation()
      local deathX, deathY = getDeathAnimationRenderState(deathAnimation.character)
      if deathX then
        tileX = deathX
        tileY = deathY
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
        elseif active and battle and battle:isAttackMode() and battle:isAttackable(c, r) then
          local glow = 0.45 + 0.1 * math.cos(love.timer.getTime() * 4)
          love.graphics.setColor(1, 1, 1, glow)
          love.graphics.draw(attackTile, x, y)
          love.graphics.setColor(1, 1, 1, 1)
        end
      else
        love.graphics.draw(stoneTile, x, y)
      end
    end
  end

  if active and not (battle and battle:isAnimating()) then
    local cursorX, cursorY
    if battle and (battle:isMoveMode() or battle:isAttackMode()) then
      local targetColumn, targetRow = battle:getCursorColumnRow(active)
      cursorX, cursorY = gridToScreen(targetColumn, targetRow)
    else
      cursorX, cursorY = gridToScreen(active.column, active.row)
    end
    love.graphics.draw(cursor, cursorX, cursorY)
  end

  local characterDrawList = {}
  for _, character in ipairs(characters) do
    local x, y, jumpOffset, scaleXFactor, alpha = getCharacterRenderState(character)
    if not x then
      x, y = gridToScreen(character.column, character.row)
      jumpOffset = 0
      scaleXFactor = 1
      alpha = 1
    end
    characterDrawList[#characterDrawList + 1] = {
      character = character,
      x = x,
      y = y,
      jumpOffset = jumpOffset or 0,
      scaleXFactor = scaleXFactor or 1,
      alpha = alpha or 1,
      sortY = y + (tileH * 0.5),
      sortX = x + (tileW * 0.5),
    }
  end

  table.sort(characterDrawList, function(a, b)
    if a.sortY == b.sortY then
      return a.sortX < b.sortX
    end
    return a.sortY < b.sortY
  end)

  for _, entry in ipairs(characterDrawList) do
    local character = entry.character
    local spriteW = character.sprite:getWidth()
    local spriteH = character.sprite:getHeight()
    local scale = math.min((tileW / spriteW), (tileH / spriteH)) * characterScale
    local directionScale = (character.direction == "left" and -scale or scale) * entry.scaleXFactor
    local tileCenterX = entry.x + (tileW * 0.5)
    local tileCenterY = entry.y + (tileH * 0.5) - entry.jumpOffset
    love.graphics.setColor(1, 1, 1, entry.alpha)
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
    love.graphics.setColor(1, 1, 1, 1)
  end

  if battle and battle:getAttackAnimation() then
    local animation = battle:getAttackAnimation()
    if animation.applied then
      local textX, textY = getAttackAnimationRenderState(animation.target)
      if not textX then
        textX, textY = gridToScreen(animation.target.column, animation.target.row)
      end
      local elapsed = animation.timer - battle.attackWindupDuration - battle.attackLungeDuration
      local floatDuration = battle.attackImpactDuration + battle.attackRetreatDuration + battle.attackHoldDuration
      local rise = 72 * math.min(1, elapsed / floatDuration)
      local fadeStart = battle.attackImpactDuration + battle.attackRetreatDuration
      local alpha = 1
      if elapsed > fadeStart then
        alpha = math.max(0, 1 - ((elapsed - fadeStart) / battle.attackHoldDuration))
      end

      local damageText = "-" .. animation.damage
      local damageScale = 3
      local damageX = textX + (tileW * 0.5) - 30
      local damageY = textY - 52 - rise

      love.graphics.setColor(0, 0, 0, alpha)
      love.graphics.print(damageText, damageX - 3, damageY, 0, damageScale, damageScale)
      love.graphics.print(damageText, damageX + 3, damageY, 0, damageScale, damageScale)
      love.graphics.print(damageText, damageX, damageY - 3, 0, damageScale, damageScale)
      love.graphics.print(damageText, damageX, damageY + 3, 0, damageScale, damageScale)
      love.graphics.setColor(1, 0.1, 0.1, alpha)
      love.graphics.print(damageText, damageX, damageY, 0, damageScale, damageScale)
      love.graphics.setColor(1, 1, 1, 1)
    end
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
        elseif selectedAction == "Skip" then
          battle:startActionPhase()
        end
      elseif battle and battle:getTurnPhase() == "action" then
        if selectedAction == "Attack" then
          if not battle:startAttackSelection(active) then
            advanceTurn(active)
          end
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
