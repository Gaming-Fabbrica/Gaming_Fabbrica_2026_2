local Menu = {}

Menu.phase = "move"
Menu.entriesByPhase = {
  move = { "Bouger", "Rester ici" },
  action = { "Se battre", "Botte secrète", "Utiliser un objet", "Passer son tour" },
}
Menu.canHeal = false
Menu.canGrapple = false
Menu.canActionFirst = false
Menu.canTank = false
Menu.disabledEntriesByPhase = {
  action = {
    ["Botte secrète"] = true,
    ["Utiliser un objet"] = true,
  },
}
Menu.selectedIndex = 1
Menu.scale = 2
Menu.font = nil

function Menu:getFont()
  if not self.font then
    self.font = love.graphics.newFont(28)
  end
  return self.font
end

function Menu:reset()
  self.selectedIndex = 1
end

function Menu:getEntries()
  if self.phase == "move" and self.canHeal then
    return { "Bouger", "Soigner", "Rester ici" }
  end
  if self.phase == "move" and self.canTank then
    return { "Bouger", "Tank", "Rester ici" }
  end
  if self.phase == "move" and self.canActionFirst then
    return { "Bouger", "Se battre", "Rester ici" }
  end
  if self.phase == "action" and self.canGrapple then
    return { "Se battre", "Grapin", "Botte secrète", "Utiliser un objet", "Passer son tour" }
  end
  return self.entriesByPhase[self.phase] or {}
end

function Menu:setCanHeal(canHeal)
  self.canHeal = canHeal == true
end

function Menu:setCanGrapple(canGrapple)
  self.canGrapple = canGrapple == true
end

function Menu:setCanActionFirst(canActionFirst)
  self.canActionFirst = canActionFirst == true
end

function Menu:setCanTank(canTank)
  self.canTank = canTank == true
end

function Menu:setPhase(phase)
  if self.phase ~= phase and self.entriesByPhase[phase] then
    self.phase = phase
    self:reset()
  end
end

function Menu:setIndex(index)
  local entries = self:getEntries()
  if index >= 1 and index <= #entries and self:isEntryEnabled(entries[index]) then
    self.selectedIndex = index
  end
end

function Menu:isEntryEnabled(entry)
  local disabledEntries = self.disabledEntriesByPhase[self.phase]
  return not (disabledEntries and disabledEntries[entry])
end

function Menu:findSelectableIndex(startIndex, delta)
  local entries = self:getEntries()
  if #entries == 0 then
    return startIndex
  end

  local index = startIndex
  for _ = 1, #entries do
    index = math.max(1, math.min(#entries, index + delta))
    if self:isEntryEnabled(entries[index]) then
      return index
    end
    if index == 1 or index == #entries then
      break
    end
  end

  return self.selectedIndex
end

function Menu:moveSelection(delta)
  self.selectedIndex = self:findSelectableIndex(self.selectedIndex, delta)
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
  return type(action) == "string" and action:lower() == "bouger"
end

function Menu:draw(worldX, worldY, tileW, worldToScreen)
  local entries = self:getEntries()
  local font = self:getFont()
  local previousFont = love.graphics.getFont()
  love.graphics.setFont(font)
  local lineHeight = font:getHeight()
  local menuX = worldX
  local menuY = worldY + 180
  local rowHeight = lineHeight + 14
  local padding = 6 * self.scale
  local leftPadding = 26
  local rightPadding = 18
  local textWidth = 0
  for _, entry in ipairs(entries) do
    textWidth = math.max(textWidth, font:getWidth("> " .. entry))
  end
  local menuWidth = textWidth + leftPadding + rightPadding + (padding * 2)
  local menuHeight = (#entries * rowHeight) + (padding * 2)

  local screenX = menuX
  local screenY = menuY
  if worldToScreen then
    screenX, screenY = worldToScreen(menuX, menuY)
  end
  screenX = screenX - (menuWidth * 0.5)

  local radius = 30
  love.graphics.setColor(1, 1, 1, 0.96)
  love.graphics.rectangle("fill", screenX, screenY, menuWidth, menuHeight, radius, radius, 24)
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.rectangle("line", screenX, screenY, menuWidth, menuHeight, radius, radius, 24)

  for i, entry in ipairs(entries) do
    local y = screenY + padding + (i - 1) * rowHeight
    if i == self.selectedIndex then
      love.graphics.setColor(0, 0, 0, 1)
      local entryRadius = math.floor(rowHeight * 0.5)
      love.graphics.rectangle("fill", screenX + 12, y - 2, menuWidth - 24, rowHeight, entryRadius, entryRadius, 24)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(entry, screenX + leftPadding, y + 5)
    else
      if self:isEntryEnabled(entry) then
        love.graphics.setColor(0, 0, 0, 1)
      else
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
      end
      love.graphics.print(entry, screenX + leftPadding, y + 5)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(previousFont)
end

return Menu
