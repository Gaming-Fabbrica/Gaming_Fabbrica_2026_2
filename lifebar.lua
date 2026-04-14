local Lifebar = {}
Lifebar.__index = Lifebar

function Lifebar.new(spritePath)
  local instance = {
    heartSprite = love.graphics.newImage(spritePath),
  }
  return setmetatable(instance, Lifebar)
end

function Lifebar:getDisplayedHp(character, battle)
  local displayedHp = math.max(0, character.hp)
  local maxHp = character.maxHp or displayedHp

  if not battle then
    return displayedHp, maxHp
  end

  local animation = battle:getAttackAnimation()
  if not animation or animation.target ~= character then
    return displayedHp, maxHp
  end

  local startHp = animation.startHp or displayedHp
  if not animation.applied then
    return startHp, maxHp
  end

  local postImpactElapsed = math.max(0, animation.timer - battle.attackWindupDuration - battle.attackLungeDuration)
  local lostHp = math.max(0, math.min(animation.damage, startHp))
  local heartStepDuration = 0.11
  local heartsGreyed = math.min(lostHp, math.floor(postImpactElapsed / heartStepDuration) + 1)
  displayedHp = math.max(character.hp, startHp - heartsGreyed)
  return displayedHp, maxHp
end

function Lifebar:draw(character, drawList, tileW, tileH, characterScale, rightOffsetX, footOffsetY, battle)
  if not character or not drawList or not self.heartSprite then
    return
  end

  local drawEntry = nil
  for _, entry in ipairs(drawList) do
    if entry.character == character then
      drawEntry = entry
      break
    end
  end

  if not drawEntry then
    return
  end

  local displayedHp, maxHp = self:getDisplayedHp(character, battle)
  local spriteW = character.sprite:getWidth()
  local spriteH = character.sprite:getHeight()
  local baseScale = math.min((tileW / spriteW), (tileH / spriteH)) * characterScale
  local scaleY = baseScale * drawEntry.scaleYFactor
  local tileCenterX = drawEntry.x + (tileW * 0.5)
  local tileCenterY = drawEntry.y + (tileH * 0.5) - drawEntry.jumpOffset
  local anchorX = tileCenterX + rightOffsetX
  local anchorY = tileCenterY + footOffsetY
  local headY = anchorY - (spriteH * scaleY)

  local heartSize = math.max(10, math.floor(tileW * 0.16))
  local heartScale = heartSize / self.heartSprite:getWidth()
  local heartSpacing = math.floor(heartSize * 0.85)
  local totalHearts = math.max(1, maxHp or displayedHp)
  local contentWidth = heartSize + ((totalHearts - 1) * heartSpacing)
  local paddingX = 10
  local paddingY = 7
  local barWidth = contentWidth + (paddingX * 2)
  local barHeight = heartSize + (paddingY * 2)
  local barX = anchorX - (barWidth * 0.5)
  local barY = headY - barHeight - 12

  love.graphics.setColor(1, 1, 1, 0.96 * drawEntry.alpha)
  love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, barHeight * 0.5, barHeight * 0.5)
  love.graphics.setColor(0, 0, 0, 0.18 * drawEntry.alpha)
  love.graphics.rectangle("line", barX, barY, barWidth, barHeight, barHeight * 0.5, barHeight * 0.5)

  for index = 1, totalHearts do
    local heartX = barX + paddingX + ((index - 1) * heartSpacing)
    local heartY = barY + paddingY
    if index <= displayedHp then
      love.graphics.setColor(1, 1, 1, drawEntry.alpha)
    else
      love.graphics.setColor(0.62, 0.62, 0.62, 0.95 * drawEntry.alpha)
    end
    love.graphics.draw(self.heartSprite, heartX, heartY, 0, heartScale, heartScale)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Lifebar
