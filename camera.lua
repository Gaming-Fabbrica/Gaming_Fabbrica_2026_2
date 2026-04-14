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
    smoothDiv = 8,
    epsilon = 0.2,
  }
  return setmetatable(self, Camera)
end

function Camera:setViewSize(viewWidth, viewHeight)
  self.viewWidth = viewWidth
  self.viewHeight = viewHeight
end

function Camera:setTarget(centerX, centerY)
  self.targetX = centerX - (self.viewWidth * 0.5)
  self.targetY = centerY - (self.viewHeight * 0.5)
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
