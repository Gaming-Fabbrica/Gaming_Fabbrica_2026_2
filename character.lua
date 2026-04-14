local Character = {}
Character.__index = Character

function Character.rollStats(totalPoints)
  local stats = {
    hp = 2,
    mov = 2,
    def = 2,
    atk = 2,
  }
  local statKeys = {"hp", "mov", "def", "atk"}
  local pointsToAssign = math.max(0, (totalPoints or 16) - 8)

  for _ = 1, pointsToAssign do
    local key = statKeys[math.random(#statKeys)]
    stats[key] = stats[key] + 1
  end

  return stats
end

function Character.inferClassName(name)
  return (name and name:match("^[^_]+")) or "fighter"
end

function Character.attackRangeForClass(className)
  if className == "archer" then
    return 4
  elseif className == "lancer" then
    return 2
  end
  return 1
end

function Character.new(name, spritePath, column, row, stats, direction, className)
  local resolvedStats = stats or Character.rollStats(16)
  local resolvedClassName = className or Character.inferClassName(name)
  local resolvedHp = resolvedStats.hp or 5
  local instance = {
    name = name,
    className = resolvedClassName,
    spritePath = spritePath,
    sprite = love.graphics.newImage(spritePath),
    hp = resolvedHp,
    maxHp = resolvedHp,
    mov = resolvedStats.mov or 5,
    def = resolvedStats.def or 2,
    atk = resolvedStats.atk or 2,
    attackRange = resolvedStats.attackRange or Character.attackRangeForClass(resolvedClassName),
    column = column,
    row = row,
    direction = direction or "right",
  }
  return setmetatable(instance, Character)
end

function Character:getPosition()
  return self.column, self.row
end

function Character:setPosition(column, row)
  self.column = column
  self.row = row
end

function Character:setDirection(direction)
  if direction == "left" or direction == "right" then
    self.direction = direction
  end
end

function Character.getAtTile(characters, column, row)
  for _, character in ipairs(characters) do
    if character.column == column and character.row == row then
      return character
    end
  end
  return nil
end

function Character.getMoveRenderState(character, battle, gridToScreen)
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
  local stretch = math.sin(math.pi * ratio)
  local squash = math.abs(math.cos(math.pi * ratio))
  local scaleXFactor = 1 + (0.1 * squash) - (0.06 * stretch)
  local scaleYFactor = 1 - (0.08 * squash) + (0.12 * stretch)
  return x, y, jump, scaleXFactor, scaleYFactor
end

function Character.getAttackRenderState(character, battle, gridToScreen, tileW)
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

function Character.getDeathRenderState(character, battle, gridToScreen)
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

  return baseX, baseY - rise, 0, flipScaleX, 1, alpha
end

function Character.getAnimatedRenderState(character, battle, gridToScreen, tileW)
  local x, y, jumpOffset, scaleXFactor, scaleYFactor, alpha =
    Character.getDeathRenderState(character, battle, gridToScreen)
  if x then
    return x, y, jumpOffset, scaleXFactor, scaleYFactor, alpha
  end

  x, y, jumpOffset, scaleXFactor, scaleYFactor = Character.getMoveRenderState(character, battle, gridToScreen)
  if x then
    return x, y, jumpOffset, scaleXFactor or 1, scaleYFactor or 1, 1
  end

  x, y, jumpOffset = Character.getAttackRenderState(character, battle, gridToScreen, tileW)
  if x then
    return x, y, jumpOffset or 0, 1, 1, 1
  end

  return nil
end

function Character.getIdleBreathingState(character, battle, timeSeconds)
  if not battle then
    return 1, 1
  end

  local attackAnimation = battle:getAttackAnimation()
  local deathAnimation = battle:getDeathAnimation()
  if battle:getAnimationState(character) then
    return 1, 1
  end
  if attackAnimation and (attackAnimation.attacker == character or attackAnimation.target == character) then
    return 1, 1
  end
  if deathAnimation and deathAnimation.character == character then
    return 1, 1
  end

  local phase = (timeSeconds * 2.2) + (character.column * 0.31) + (character.row * 0.17)
  local breath = math.sin(phase)
  local scaleXFactor = 1 - (0.018 * breath)
  local scaleYFactor = 1 + (0.03 * breath)
  return scaleXFactor, scaleYFactor
end

function Character.buildDrawList(characters, battle, gridToScreen, tileW, tileH, timeSeconds)
  local drawList = {}

  for _, character in ipairs(characters) do
    local x, y, jumpOffset, scaleXFactor, scaleYFactor, alpha =
      Character.getAnimatedRenderState(character, battle, gridToScreen, tileW)
    if not x then
      x, y = gridToScreen(character.column, character.row)
      jumpOffset = 0
      scaleXFactor, scaleYFactor = Character.getIdleBreathingState(character, battle, timeSeconds)
      alpha = 1
    end

    drawList[#drawList + 1] = {
      character = character,
      x = x,
      y = y,
      jumpOffset = jumpOffset or 0,
      scaleXFactor = scaleXFactor or 1,
      scaleYFactor = scaleYFactor or 1,
      alpha = alpha or 1,
      sortY = y + (tileH * 0.5),
      sortX = x + (tileW * 0.5),
    }
  end

  table.sort(drawList, function(a, b)
    if a.sortY == b.sortY then
      return a.sortX < b.sortX
    end
    return a.sortY < b.sortY
  end)

  return drawList
end

function Character.drawDrawList(drawList, tileW, tileH, characterScale, rightOffsetX, footOffsetY)
  for _, entry in ipairs(drawList) do
    local character = entry.character
    local spriteW = character.sprite:getWidth()
    local spriteH = character.sprite:getHeight()
    local scale = math.min((tileW / spriteW), (tileH / spriteH)) * characterScale
    local scaleX = scale * entry.scaleXFactor
    local scaleY = scale * entry.scaleYFactor
    local directionScale = character.direction == "left" and -scaleX or scaleX
    local tileCenterX = entry.x + (tileW * 0.5)
    local tileCenterY = entry.y + (tileH * 0.5) - entry.jumpOffset

    love.graphics.setColor(1, 1, 1, entry.alpha)
    love.graphics.draw(
      character.sprite,
      tileCenterX + rightOffsetX,
      tileCenterY + footOffsetY,
      0,
      directionScale,
      scaleY,
      spriteW * 0.5,
      spriteH
    )
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function Character.drawAttackDamageText(battle, gridToScreen, tileW)
  if not battle then
    return
  end

  local animation = battle:getAttackAnimation()
  if not animation or not animation.applied then
    return
  end

  local textX, textY = Character.getAttackRenderState(animation.target, battle, gridToScreen, tileW)
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

return Character
