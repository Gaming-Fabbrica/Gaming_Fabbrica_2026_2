local Menu = {}

Menu.phase = "move"
Menu.entriesByPhase = {
  move = { "Move", "Skip" },
  action = { "Attack", "Skill", "Item" },
}
Menu.selectedIndex = 1
Menu.scale = 2

function Menu:reset()
  self.selectedIndex = 1
end

function Menu:getEntries()
  return self.entriesByPhase[self.phase] or {}
end

function Menu:setPhase(phase)
  if self.phase ~= phase and self.entriesByPhase[phase] then
    self.phase = phase
    self:reset()
  end
end

function Menu:setIndex(index)
  local entries = self:getEntries()
  if index >= 1 and index <= #entries then
    self.selectedIndex = index
  end
end

function Menu:moveSelection(delta)
  local entries = self:getEntries()
  self.selectedIndex = math.max(1, math.min(#entries, self.selectedIndex + delta))
end

function Menu:next()
  self:moveSelection(1)
end

function Menu:prev()
  self:moveSelection(-1)
end

function Menu:selectedAction()
  local entries = self:getEntries()
  return entries[self.selectedIndex]
end

function Menu:isMoveSelected()
  local action = self:selectedAction()
  return type(action) == "string" and action:lower() == "move"
end

function Menu:draw(worldX, worldY, tileW, worldToScreen)
  local entries = self:getEntries()
  local menuX = worldX + tileW * 0.6
  local menuY = worldY - (#entries * 18) * 0.5
  local menuWidth = 90 * self.scale
  local rowHeight = 18 * self.scale
  local padding = 6 * self.scale
  local menuHeight = (#entries * rowHeight) + (padding * 2)

  local screenX = menuX
  local screenY = menuY
  if worldToScreen then
    screenX, screenY = worldToScreen(worldX, worldY)
    screenX = screenX + tileW * 0.6
    screenY = screenY - (#entries * 18) * 0.5
  end

  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", screenX, screenY, menuWidth, menuHeight, 4, 4)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("line", screenX, screenY, menuWidth, menuHeight, 4, 4)

  for i, entry in ipairs(entries) do
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
