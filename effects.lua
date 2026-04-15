local Effects = {}
Effects.__index = Effects

function Effects.new()
  local instance = {
    thorns = {},
    algae = {},
    damagePopups = {},
    healAnimation = nil,
    thornsTile = nil,
    algaeTile = nil,
    splashTile = nil,
    healHeartTile = nil,
    terrainEffectScale = 0.9,
    terrainEffectAppearDuration = 0.25,
    damagePopupDuration = 0.7,
  }
  return setmetatable(instance, Effects)
end

function Effects:load()
  self.thornsTile = love.graphics.newImage("assets/sprites/effects/thorns.png")
  self.algaeTile = love.graphics.newImage("assets/sprites/effects/algae.png")
  self.splashTile = love.graphics.newImage("assets/sprites/effects/splash.png")
  self.healHeartTile = love.graphics.newImage("assets/sprites/items/heart.png")
end

function Effects:clear()
  self.thorns = {}
  self.algae = {}
  self.damagePopups = {}
  self.healAnimation = nil
end

function Effects:getThorns()
  return self.thorns
end

function Effects:getAlgae()
  return self.algae
end

function Effects:getDamagePopups()
  return self.damagePopups
end

function Effects:getHealAnimation()
  return self.healAnimation
end

function Effects:clearHealAnimation()
  self.healAnimation = nil
end

function Effects:hasThornsAt(column, row)
  return self.thorns[column .. "," .. row] ~= nil
end

function Effects:hasAlgaeAt(column, row)
  return self.algae[column .. "," .. row] ~= nil
end

function Effects:addThorns(column, row)
  self.thorns[column .. "," .. row] = love.timer.getTime()
  print(string.format("[thorns] add at %d,%d", column, row))
end

function Effects:addAlgae(column, row)
  self.algae[column .. "," .. row] = love.timer.getTime()
end

function Effects:addDamagePopup(column, row, damage)
  self.damagePopups[#self.damagePopups + 1] = {
    column = column,
    row = row,
    damage = damage,
    timer = 0,
  }
end

function Effects:updateDamagePopups(dt)
  local nextPopups = {}
  for _, popup in ipairs(self.damagePopups) do
    popup.timer = popup.timer + dt
    if popup.timer < self.damagePopupDuration then
      nextPopups[#nextPopups + 1] = popup
    end
  end
  self.damagePopups = nextPopups
end

function Effects:getMovementCost(column, row)
  if self:hasAlgaeAt(column, row) then
    return 2
  end
  return 1
end

function Effects:startHealAnimation(healer, target)
  local healAmount = love.math.random(1, 3)
  self.healAnimation = {
    healer = healer,
    target = target,
    healAmount = healAmount,
    timer = 0,
    duration = 1.0,
    applied = false,
    particles = {
      {angle = -1.35, driftX = -74, rise = 132, delay = 0.00, wobble = 12, speed = 7.2, scale = 0.95},
      {angle = -1.05, driftX = -58, rise = 144, delay = 0.03, wobble = 13, speed = 8.1, scale = 1.05},
      {angle = -0.78, driftX = -44, rise = 126, delay = 0.07, wobble = 12, speed = 7.7, scale = 0.9},
      {angle = -0.42, driftX = -24, rise = 138, delay = 0.02, wobble = 14, speed = 8.4, scale = 1.0},
      {angle = -0.08, driftX = -8, rise = 118, delay = 0.09, wobble = 11, speed = 7.4, scale = 0.85},
      {angle = 0.18, driftX = 10, rise = 134, delay = 0.05, wobble = 13, speed = 8.8, scale = 1.0},
      {angle = 0.46, driftX = 28, rise = 146, delay = 0.11, wobble = 14, speed = 7.6, scale = 1.08},
      {angle = 0.74, driftX = 46, rise = 128, delay = 0.15, wobble = 12, speed = 8.0, scale = 0.92},
      {angle = 1.02, driftX = 62, rise = 140, delay = 0.08, wobble = 13, speed = 7.5, scale = 1.02},
      {angle = 1.28, driftX = 78, rise = 136, delay = 0.18, wobble = 12, speed = 8.2, scale = 0.9},
    },
  }
end

function Effects:updateHealAnimation(dt)
  local animation = self.healAnimation
  if not animation then
    return nil
  end

  animation.timer = animation.timer + dt

  if not animation.applied and animation.timer >= animation.duration * 0.18 then
    animation.applied = true
    animation.target.hp = math.min(
      animation.target.maxHp or animation.target.hp,
      animation.target.hp + animation.healAmount
    )
  end

  if animation.timer >= animation.duration then
    local healer = animation.healer
    self.healAnimation = nil
    return healer
  end

  return nil
end

local function drawTerrainTile(image, column, row, createdAt, gridToScreen, tileW, tileH, scale, appearDuration, now)
  local x, y = gridToScreen(column, row)
  local appearRatio = math.min(1, math.max(0, (now - createdAt) / appearDuration))
  local effectScale = scale * (0.6 + (0.4 * appearRatio))
  local drawScaleX = (tileW / image:getWidth()) * effectScale
  local drawScaleY = (tileH / image:getHeight()) * effectScale
  local drawX = x + ((tileW - (image:getWidth() * drawScaleX)) * 0.5)
  local drawY = y + ((tileH - (image:getHeight() * drawScaleY)) * 0.5)
  love.graphics.setColor(1, 1, 1, appearRatio)
  love.graphics.draw(image, drawX, drawY, 0, drawScaleX, drawScaleY)
  love.graphics.setColor(1, 1, 1, 1)
end

function Effects:drawWorld(battle, gridToScreen, tileW, tileH, timeSeconds)
  local attackAnimation = battle and battle:getAttackAnimation() or nil
  if attackAnimation and attackAnimation.kind == "splash" and self.splashTile then
    local splashX, splashY = gridToScreen(attackAnimation.centerColumn, attackAnimation.centerRow)
    local splashRatio = math.min(1, attackAnimation.timer / (battle.attackWindupDuration + battle.attackLungeDuration))
    local splashScale = 0.6 + (0.4 * splashRatio)
    local splashAlpha = math.min(1, 0.35 + (0.65 * splashRatio))
    love.graphics.setColor(1, 1, 1, splashAlpha)
    love.graphics.draw(
      self.splashTile,
      splashX + (tileW * 0.5),
      splashY + (tileH * 0.5),
      0,
      ((tileW * 3) / self.splashTile:getWidth()) * splashScale,
      ((tileH * 3) / self.splashTile:getHeight()) * splashScale,
      self.splashTile:getWidth() * 0.5,
      self.splashTile:getHeight() * 0.5
    )
    love.graphics.setColor(1, 1, 1, 1)
  end

  if self.thornsTile then
    for thornKey, createdAt in pairs(self.thorns) do
      local commaIndex = thornKey:find(",")
      local column = tonumber(thornKey:sub(1, commaIndex - 1))
      local row = tonumber(thornKey:sub(commaIndex + 1))
      if column and row then
        drawTerrainTile(
          self.thornsTile,
          column,
          row,
          createdAt,
          gridToScreen,
          tileW,
          tileH,
          self.terrainEffectScale,
          self.terrainEffectAppearDuration,
          timeSeconds
        )
      end
    end
  end

  if self.algaeTile then
    for algaeKey, createdAt in pairs(self.algae) do
      local commaIndex = algaeKey:find(",")
      local column = tonumber(algaeKey:sub(1, commaIndex - 1))
      local row = tonumber(algaeKey:sub(commaIndex + 1))
      if column and row then
        drawTerrainTile(
          self.algaeTile,
          column,
          row,
          createdAt,
          gridToScreen,
          tileW,
          tileH,
          self.terrainEffectScale,
          self.terrainEffectAppearDuration,
          timeSeconds
        )
      end
    end
  end

  if self.healAnimation and self.healHeartTile then
    local targetX, targetY = gridToScreen(self.healAnimation.target.column, self.healAnimation.target.row)
    local baseX = targetX + (tileW * 0.5)
    local baseY = targetY + (tileH * 0.18)
    local duration = self.healAnimation.duration * 0.75
    for _, particle in ipairs(self.healAnimation.particles) do
      local localTimer = self.healAnimation.timer - particle.delay
      if localTimer > 0 then
        local ratio = math.min(1, localTimer / duration)
        local x = baseX + (particle.driftX * ratio) + (math.sin((ratio * particle.speed * math.pi * 2) + particle.angle) * particle.wobble)
        local y = baseY - (particle.rise * ratio)
        local scale = (tileW * 0.18 / self.healHeartTile:getWidth()) * particle.scale * (0.65 + (0.55 * ratio))
        local alpha = math.max(0, 1 - (ratio * 0.6))
        love.graphics.setColor(1, 0.72, 0.9, alpha)
        love.graphics.draw(
          self.healHeartTile,
          x,
          y,
          math.sin(particle.angle + (ratio * 4)) * 0.08,
          scale,
          scale,
          self.healHeartTile:getWidth() * 0.5,
          self.healHeartTile:getHeight() * 0.5
        )
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return Effects
