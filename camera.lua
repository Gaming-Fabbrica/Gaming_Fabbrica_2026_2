local Camera = {}
Camera.__index = Camera

function Camera.new(viewWidth, viewHeight)
  local self = {
    x = 0,
    y = 0,
    targetX = 0,
    targetY = 0,
    viewWidth = viewWidth,
    viewHeight = viewHeight,
    boundsWidth = nil,
    boundsHeight = nil,
    zoom = 0.8,
    smoothDiv = 8,
    epsilon = 0.2,
    shakeTimer = 0,
    shakeDuration = 0,
    shakeAmplitude = 0,
    shakeOffsetX = 0,
    shakeOffsetY = 0,
  }
  return setmetatable(self, Camera)
end

function Camera:getWorldViewWidth()
  return self.viewWidth / self.zoom
end

function Camera:getWorldViewHeight()
  return self.viewHeight / self.zoom
end

function Camera:clampPosition(x, y)
  if not self.boundsWidth or not self.boundsHeight then
    return x, y
  end

  local maxX = math.max(0, self.boundsWidth - self:getWorldViewWidth())
  local maxY = math.max(0, self.boundsHeight - self:getWorldViewHeight())

  return math.max(0, math.min(maxX, x)), math.max(0, math.min(maxY, y))
end

function Camera:setViewSize(viewWidth, viewHeight)
  self.viewWidth = viewWidth
  self.viewHeight = viewHeight
  self.x, self.y = self:clampPosition(self.x, self.y)
  self.targetX, self.targetY = self:clampPosition(self.targetX, self.targetY)
end

function Camera:setBounds(boundsWidth, boundsHeight)
  self.boundsWidth = boundsWidth
  self.boundsHeight = boundsHeight
  self.x, self.y = self:clampPosition(self.x, self.y)
  self.targetX, self.targetY = self:clampPosition(self.targetX, self.targetY)
end

function Camera:setTarget(centerX, centerY)
  self.targetX = centerX - (self:getWorldViewWidth() * 0.5)
  self.targetY = centerY - (self:getWorldViewHeight() * 0.5)
  self.targetX, self.targetY = self:clampPosition(self.targetX, self.targetY)
end

function Camera:follow(centerX, centerY)
  self:setTarget(centerX, centerY)
end

function Camera:update()
  self.x = self.x + (self.targetX - self.x) / self.smoothDiv
  self.y = self.y + (self.targetY - self.y) / self.smoothDiv

  if math.abs(self.targetX - self.x) < self.epsilon then
    self.x = self.targetX
  end
  if math.abs(self.targetY - self.y) < self.epsilon then
    self.y = self.targetY
  end

  if self.shakeTimer > 0 then
    self.shakeTimer = math.max(0, self.shakeTimer - love.timer.getDelta())
    local ratio = self.shakeDuration > 0 and (self.shakeTimer / self.shakeDuration) or 0
    local amplitude = self.shakeAmplitude * ratio
    self.shakeOffsetX = (love.math.random() * 2 - 1) * amplitude
    self.shakeOffsetY = (love.math.random() * 2 - 1) * amplitude
  else
    self.shakeOffsetX = 0
    self.shakeOffsetY = 0
  end
end

function Camera:startShake(duration, amplitude)
  self.shakeDuration = duration or 0.22
  self.shakeTimer = self.shakeDuration
  self.shakeAmplitude = amplitude or 10
end

function Camera:apply()
  love.graphics.scale(self.zoom, self.zoom)
  love.graphics.translate(-(self.x - self.shakeOffsetX), -(self.y - self.shakeOffsetY))
end

function Camera:worldToScreen(x, y)
  return (x - self.x) * self.zoom, (y - self.y) * self.zoom
end

return Camera
