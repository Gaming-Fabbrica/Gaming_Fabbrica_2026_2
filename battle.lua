local Battle = {}
Battle.__index = Battle

function Battle.new(cols, rows, map)
  local instance = {
    cols = cols,
    rows = rows,
    map = map,
    mode = "menu",
    characters = {},
    moveRange = {},
    moveTarget = { column = 1, row = 1 },
    movingCharacter = nil,
    moveAnimation = nil,
    moveStepDuration = 0.6,
    jumpHeight = 64,
  }
  return setmetatable(instance, Battle)
end

function Battle:setMap(map)
  self.map = map
end

function Battle:setCharacters(characters)
  self.characters = characters or {}
end

function Battle:getMode()
  return self.mode
end

function Battle:setMode(mode)
  self.mode = mode
  if mode ~= "move" then
    self.moveRange = {}
    self.movingCharacter = nil
  end
  if mode ~= "animating" then
    self.moveAnimation = nil
  end
end

function Battle:isCharacterAt(column, row, ignoreCharacter)
  for _, character in ipairs(self.characters) do
    if character ~= ignoreCharacter and character.column == column and character.row == row then
      return true
    end
  end
  return false
end

function Battle:isPassable(column, row, ignoreCharacter)
  if not self.map[column] or not self.map[column][row] then
    return false
  end
  return not self:isCharacterAt(column, row, ignoreCharacter)
end

function Battle:isMoveMode()
  return self.mode == "move"
end

function Battle:getMoveRange()
  return self.moveRange
end

function Battle:getMoveAnimation()
  return self.moveAnimation
end

function Battle:isAnimating()
  return self.moveAnimation ~= nil
end

function Battle:isAnimatingCharacter(character)
  return self.moveAnimation ~= nil and self.moveAnimation.character == character
end

function Battle:getAnimationState(character)
  if self.moveAnimation and self.moveAnimation.character == character then
    return self.moveAnimation
  end
  return nil
end

function Battle:isReachable(column, row)
  return self.moveRange[column .. "," .. row]
end

function Battle:getCursorColumnRow(activeCharacter)
  if self.mode == "move" then
    return self.moveTarget.column, self.moveTarget.row
  end
  return activeCharacter.column, activeCharacter.row
end

function Battle:isInMap(column, row)
  return column >= 1 and column <= self.cols and row >= 1 and row <= self.rows
end

function Battle:isWalkableStep(column, row, ignoreCharacter)
  if not self:isInMap(column, row) then
    return false
  end
  return self:isPassable(column, row, ignoreCharacter)
end

function Battle:getHexNeighbors(column, row)
  if column % 2 == 0 then
    return {
      {column + 1, row},
      {column - 1, row},
      {column, row - 1},
      {column, row + 1},
      {column + 1, row - 1},
      {column - 1, row - 1},
    }
  else
    return {
      {column + 1, row},
      {column - 1, row},
      {column, row - 1},
      {column, row + 1},
      {column + 1, row + 1},
      {column - 1, row + 1},
    }
  end
end

function Battle:getReachableTiles(startColumn, startRow, maxMoves)
  local reachable = {}
  if maxMoves < 1 then
    return reachable
  end
  if not self:isWalkableStep(startColumn, startRow, self.movingCharacter) then
    return reachable
  end

  local queue = {
    {startColumn, startRow, 0},
  }
  local visited = {[startColumn .. "," .. startRow] = 0}

  local head = 1
  while head <= #queue do
    local node = queue[head]
    head = head + 1

    local column = node[1]
    local row = node[2]
    local distance = node[3]

    if distance > 0 then
      reachable[column .. "," .. row] = true
    end

    if distance < maxMoves then
      for _, neighbor in ipairs(self:getHexNeighbors(column, row)) do
        local nextColumn = neighbor[1]
        local nextRow = neighbor[2]
        local nextKey = nextColumn .. "," .. nextRow

        if
          self:isWalkableStep(nextColumn, nextRow, self.movingCharacter)
          and not visited[nextKey]
        then
          visited[nextKey] = distance + 1
          table.insert(queue, {nextColumn, nextRow, distance + 1})
        end
      end
    end
  end

  return reachable
end

function Battle:getPathToTarget(startColumn, startRow, targetColumn, targetRow)
  if not self:isWalkableStep(startColumn, startRow, self.movingCharacter) then
    return nil
  end

  if not self:isWalkableStep(targetColumn, targetRow, self.movingCharacter) then
    return nil
  end

  if startColumn == targetColumn and startRow == targetRow then
    return {
      {column = startColumn, row = startRow},
    }
  end

  local queue = {
    {startColumn, startRow},
  }
  local visited = {[startColumn .. "," .. startRow] = true}
  local previous = {}

  local head = 1
  while head <= #queue do
    local node = queue[head]
    head = head + 1

    local column = node[1]
    local row = node[2]

    if column == targetColumn and row == targetRow then
      break
    end

    for _, neighbor in ipairs(self:getHexNeighbors(column, row)) do
      local nextColumn = neighbor[1]
      local nextRow = neighbor[2]
      local nextKey = nextColumn .. "," .. nextRow

      if
        self:isWalkableStep(nextColumn, nextRow, self.movingCharacter)
        and not visited[nextKey]
      then
        visited[nextKey] = true
        previous[nextKey] = {column, row}
        queue[#queue + 1] = {nextColumn, nextRow}
      end
    end
  end

  local targetKey = targetColumn .. "," .. targetRow
  if not visited[targetKey] then
    return nil
  end

  local path = {}
  local cursorColumn = targetColumn
  local cursorRow = targetRow
  while cursorColumn do
    path[#path + 1] = {column = cursorColumn, row = cursorRow}
    local currentKey = cursorColumn .. "," .. cursorRow
    local prev = previous[currentKey]
    if not prev then
      break
    end
    cursorColumn = prev[1]
    cursorRow = prev[2]
  end

  for i = 1, math.floor(#path * 0.5) do
    local j = #path - i + 1
    path[i], path[j] = path[j], path[i]
  end

  return path
end

function Battle:startMoveSelection(activeCharacter)
  self.movingCharacter = activeCharacter
  self.moveRange = self:getReachableTiles(activeCharacter.column, activeCharacter.row, activeCharacter.mov)
  self.moveTarget.column = activeCharacter.column
  self.moveTarget.row = activeCharacter.row
  self.mode = "move"
end

function Battle:moveTargetByKey(key)
  local nextColumn = self.moveTarget.column
  local nextRow = self.moveTarget.row
  local neighbors = self:getHexNeighbors(self.moveTarget.column, self.moveTarget.row)
  local candidates = {}

  if key == "left" then
    candidates[1] = neighbors[2]
  elseif key == "right" then
    candidates[1] = neighbors[1]
  elseif key == "up" then
    candidates[1] = neighbors[3]
    candidates[2] = neighbors[5]
  elseif key == "down" then
    candidates[1] = neighbors[4]
    candidates[2] = neighbors[6]
  end

  for _, candidate in ipairs(candidates) do
    if candidate then
      local c = candidate[1]
      local r = candidate[2]
      if self:isInMap(c, r) and self:isReachable(c, r) then
        nextColumn = c
        nextRow = r
        break
      end
    end
  end

  self.moveTarget.column = nextColumn
  self.moveTarget.row = nextRow
end

function Battle:confirmMove(activeCharacter)
  if self:isReachable(self.moveTarget.column, self.moveTarget.row) then
    self.movingCharacter = activeCharacter
    local path = self:getPathToTarget(
      activeCharacter.column,
      activeCharacter.row,
      self.moveTarget.column,
      self.moveTarget.row
    )
    if path and #path > 1 then
      self.moveRange = {}
      self.mode = "animating"
      self.moveAnimation = {
        character = activeCharacter,
        path = path,
        step = 1,
        timer = 0,
      }
      return true
    end
  end
  return false
end

function Battle:cancelMoveMode()
  self.mode = "menu"
  self.moveRange = {}
end

function Battle:update(dt)
  if not self.moveAnimation then
    return
  end

  local animation = self.moveAnimation
  animation.timer = animation.timer + dt
  while animation.timer >= self.moveStepDuration do
    animation.step = animation.step + 1
    animation.timer = animation.timer - self.moveStepDuration

    if animation.step >= #animation.path then
      local finalNode = animation.path[#animation.path]
      animation.character:setPosition(finalNode.column, finalNode.row)
      self.moveAnimation = nil
      self.movingCharacter = nil
      self.mode = "menu"
      return
    end
  end
end

return Battle
