local Menu = {}

Menu.entries = { "Move", "Attack", "Skill", "Item" }
Menu.selectedIndex = 1
Menu.scale = 2

function Menu:reset()
  self.selectedIndex = 1
end

function Menu:setIndex(index)
  if index >= 1 and index <= #self.entries then
    self.selectedIndex = index
  end
end

function Menu:moveSelection(delta)
  self.selectedIndex = math.max(1, math.min(#self.entries, self.selectedIndex + delta))
end

function Menu:next()
  self:moveSelection(1)
end

function Menu:prev()
  self:moveSelection(-1)
end

function Menu:selectedAction()
  return self.entries[self.selectedIndex]
end

function Menu:isMoveSelected()
  local action = self:selectedAction()
  return self.selectedIndex == 1
    or (type(action) == "string" and action:lower() == "move")
end

function Menu:draw(worldX, worldY, tileW, worldToScreen)
  local menuX = worldX + tileW * 0.6
  local menuY = worldY - (4 * 18) * 0.5
  local menuWidth = 90 * self.scale
  local rowHeight = 18 * self.scale
  local padding = 6 * self.scale
  local menuHeight = (#self.entries * rowHeight) + (padding * 2)

  local screenX = menuX
  local screenY = menuY
  if worldToScreen then
    screenX, screenY = worldToScreen(worldX, worldY)
    screenX = screenX + tileW * 0.6
    screenY = screenY - (4 * 18) * 0.5
  end

  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", screenX, screenY, menuWidth, menuHeight, 4, 4)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("line", screenX, screenY, menuWidth, menuHeight, 4, 4)

  for i, entry in ipairs(self.entries) do
    local y = screenY + padding + (i - 1) * rowHeight
    if i == self.selectedIndex then
      love.graphics.setColor(1, 1, 0, 1)
      love.graphics.print("> " .. entry, screenX + 4, y, 0, self.scale, self.scale)
    else
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("  " .. entry, screenX + 4, y, 0, self.scale, self.scale)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Menu
