local Camera = {}
Camera.__index = Camera

function Camera.new(viewWidth, viewHeight)
  local self = {
    x = 0,
    y = 0,
    viewWidth = viewWidth,
    viewHeight = viewHeight,
  }
  return setmetatable(self, Camera)
end

function Camera:setViewSize(viewWidth, viewHeight)
  self.viewWidth = viewWidth
  self.viewHeight = viewHeight
end

function Camera:follow(centerX, centerY)
  self.x = centerX - (self.viewWidth * 0.5)
  self.y = centerY - (self.viewHeight * 0.5)
end

function Camera:apply()
  love.graphics.translate(-self.x, -self.y)
end

function Camera:worldToScreen(x, y)
  return x - self.x, y - self.y
end

return Camera
