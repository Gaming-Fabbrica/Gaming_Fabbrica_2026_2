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
    smoothDiv = 8,
    epsilon = 0.2,
  }
  return setmetatable(self, Camera)
end

function Camera:clampPosition(x, y)
  if not self.boundsWidth or not self.boundsHeight then
    return x, y
  end

  local maxX = math.max(0, self.boundsWidth - self.viewWidth)
  local maxY = math.max(0, self.boundsHeight - self.viewHeight)

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
  self.targetX = centerX - (self.viewWidth * 0.5)
  self.targetY = centerY - (self.viewHeight * 0.5)
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
end

function Camera:apply()
  love.graphics.translate(-self.x, -self.y)
end

function Camera:worldToScreen(x, y)
  return x - self.x, y - self.y
end

return Camera
