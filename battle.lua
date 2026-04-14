local Battle = {}
Battle.__index = Battle

function Battle.new(cols, rows, map)
  local instance = {
    cols = cols,
    rows = rows,
    map = map,
    mode = "menu",
    moveRange = {},
    moveTarget = { column = 1, row = 1 },
  }
  return setmetatable(instance, Battle)
end

function Battle:setMap(map)
  self.map = map
end

function Battle:getMode()
  return self.mode
end

function Battle:setMode(mode)
  self.mode = mode
  if mode ~= "move" then
    self.moveRange = {}
  end
end

function Battle:isMoveMode()
  return self.mode == "move"
end

function Battle:getMoveRange()
  return self.moveRange
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
          self:isInMap(nextColumn, nextRow)
          and self.map[nextColumn][nextRow]
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

function Battle:startMoveSelection(activeCharacter)
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
    activeCharacter:setPosition(self.moveTarget.column, self.moveTarget.row)
    self.mode = "menu"
    self.moveRange = {}
    return true
  end
  return false
end

function Battle:cancelMoveMode()
  self.mode = "menu"
  self.moveRange = {}
end

return Battle
