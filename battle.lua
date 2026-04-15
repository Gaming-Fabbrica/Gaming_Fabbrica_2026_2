local Battle = {}
Battle.__index = Battle

function Battle.new(cols, rows, map)
  local instance = {
    cols = cols,
    rows = rows,
    map = map,
    effects = nil,
    mode = "menu",
    turnPhase = "move",
    characters = {},
    moveRange = {},
    moveTarget = { column = 1, row = 1 },
    attackRange = {},
    attackTarget = { column = 1, row = 1 },
    healTargets = {},
    healTarget = { column = 1, row = 1 },
    movingCharacter = nil,
    moveAnimation = nil,
    attackAnimation = nil,
    deathAnimation = nil,
    deathQueue = nil,
    completedActionCharacter = nil,
    pendingScreenShake = nil,
    pendingSlowMotion = nil,
    moveStepDuration = 0.6,
    jumpHeight = 64,
    attackWindupDuration = 0.12,
    attackLungeDuration = 0.14,
    attackImpactDuration = 0.12,
    attackRetreatDuration = 0.14,
    attackHoldDuration = 0.45,
    deathDuration = 0.75,
    damagePopupDuration = 0.7,
  }
  return setmetatable(instance, Battle)
end

function Battle:triggerScreenShake(duration, amplitude)
  self.pendingScreenShake = {
    duration = duration or 0.22,
    amplitude = amplitude or 10,
  }
end

function Battle:consumeScreenShake()
  local shake = self.pendingScreenShake
  self.pendingScreenShake = nil
  return shake
end

function Battle:triggerSlowMotion(duration, scale)
  self.pendingSlowMotion = {
    duration = duration or 0.18,
    scale = scale or 0.35,
  }
end

function Battle:consumeSlowMotion()
  local slowMotion = self.pendingSlowMotion
  self.pendingSlowMotion = nil
  return slowMotion
end

function Battle:setMap(map)
  self.map = map
end

function Battle:setEffects(effects)
  self.effects = effects
end

function Battle:setCharacters(characters)
  self.characters = characters or {}
end

function Battle:getMode()
  return self.mode
end

function Battle:getTurnPhase()
  return self.turnPhase
end

function Battle:startTurn()
  self.turnPhase = "move"
  self.mode = "menu"
  self.moveRange = {}
  self.attackRange = {}
  self.healTargets = {}
  self.moveAnimation = nil
  if self.effects then
    self.effects:clearHealAnimation()
  end
  self.attackAnimation = nil
  self.deathAnimation = nil
  self.deathQueue = nil
  self.movingCharacter = nil
  self.completedActionCharacter = nil
end

function Battle:getThorns()
  return self.effects and self.effects:getThorns() or {}
end

function Battle:getAlgae()
  return self.effects and self.effects:getAlgae() or {}
end

function Battle:getDamagePopups()
  return self.effects and self.effects:getDamagePopups() or {}
end

function Battle:hasThornsAt(column, row)
  return self.effects and self.effects:hasThornsAt(column, row) or false
end

function Battle:hasAlgaeAt(column, row)
  return self.effects and self.effects:hasAlgaeAt(column, row) or false
end

function Battle:addThorns(column, row)
  if self.effects then
    self.effects:addThorns(column, row)
  end
end

function Battle:addAlgae(column, row)
  if self.effects then
    self.effects:addAlgae(column, row)
  end
end

function Battle:addDamagePopup(column, row, damage)
  if self.effects then
    self.effects:addDamagePopup(column, row, damage)
  end
end

function Battle:updateDamagePopups(dt)
  if self.effects then
    self.effects:updateDamagePopups(dt)
  end
end

function Battle:startActionPhase()
  self.turnPhase = "action"
  self.mode = "menu"
  self.moveRange = {}
  self.attackRange = {}
  self.healTargets = {}
  self.movingCharacter = nil
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
  if mode ~= "attack" then
    self.attackRange = {}
  end
  if mode ~= "heal" then
    self.healTargets = {}
  end
  if mode ~= "heal_animating" and self.effects then
    self.effects:clearHealAnimation()
  end
  if mode ~= "attack_animating" then
    self.attackAnimation = nil
  end
  if mode ~= "death_animating" then
    self.deathAnimation = nil
    self.deathQueue = nil
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

function Battle:getCharacterAt(column, row, ignoreCharacter)
  for _, character in ipairs(self.characters) do
    if character ~= ignoreCharacter and character.column == column and character.row == row then
      return character
    end
  end
  return nil
end

function Battle:areOpponents(a, b)
  return a and b and a.team ~= b.team
end

function Battle:getOpponentsOf(character)
  local opponents = {}
  for _, other in ipairs(self.characters) do
    if self:areOpponents(character, other) then
      opponents[#opponents + 1] = other
    end
  end
  return opponents
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

function Battle:isAttackMode()
  return self.mode == "attack"
end

function Battle:isHealMode()
  return self.mode == "heal"
end

function Battle:getAttackAnimation()
  return self.attackAnimation
end

function Battle:getHealAnimation()
  return self.effects and self.effects:getHealAnimation() or nil
end

function Battle:getDeathAnimation()
  return self.deathAnimation
end

function Battle:getMoveRange()
  return self.moveRange
end

function Battle:getAttackRange()
  return self.attackRange
end

function Battle:getMoveAnimation()
  return self.moveAnimation
end

function Battle:isAnimating()
  return self.moveAnimation ~= nil or self:getHealAnimation() ~= nil or self.attackAnimation ~= nil or self.deathAnimation ~= nil
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

function Battle:consumeCompletedActionCharacter()
  local character = self.completedActionCharacter
  self.completedActionCharacter = nil
  return character
end

function Battle:isReachable(column, row)
  return self.moveRange[column .. "," .. row]
end

function Battle:isAttackable(column, row)
  return self.attackRange[column .. "," .. row]
end

function Battle:isHealable(column, row)
  return self.healTargets[column .. "," .. row]
end

function Battle:getCursorColumnRow(activeCharacter)
  if self.mode == "move" then
    return self.moveTarget.column, self.moveTarget.row
  elseif self.mode == "attack" then
    return self.attackTarget.column, self.attackTarget.row
  elseif self.mode == "heal" then
    return self.healTarget.column, self.healTarget.row
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

function Battle:getMovementCost(column, row)
  return self.effects and self.effects:getMovementCost(column, row) or 1
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

function Battle:getGridVector(column, row)
  local x = (column - 1) * 0.75
  local y = row - 1
  if column % 2 == 1 then
    y = y + 0.5
  end
  return x, y
end

function Battle:getTilesInRange(startColumn, startRow, maxRange)
  local tiles = {}
  if maxRange < 1 then
    return tiles
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
    local key = column .. "," .. row

    if distance > 0 then
      tiles[key] = distance
    end

    if distance < maxRange then
      for _, neighbor in ipairs(self:getHexNeighbors(column, row)) do
        local nextColumn = neighbor[1]
        local nextRow = neighbor[2]
        local nextKey = nextColumn .. "," .. nextRow

        if self:isInMap(nextColumn, nextRow) and not visited[nextKey] then
          visited[nextKey] = distance + 1
          queue[#queue + 1] = {nextColumn, nextRow, distance + 1}
        end
      end
    end
  end

  return tiles
end

function Battle:getTileDistance(startColumn, startRow, targetColumn, targetRow)
  if startColumn == targetColumn and startRow == targetRow then
    return 0
  end
  local tiles = self:getTilesInRange(startColumn, startRow, self.cols * self.rows)
  return tiles[targetColumn .. "," .. targetRow]
end

function Battle:getReachableTiles(startColumn, startRow, maxMoves, ignoreCharacter)
  local reachable = {}
  if maxMoves < 1 then
    return reachable
  end
  local ignored = ignoreCharacter or self.movingCharacter
  if not self:isWalkableStep(startColumn, startRow, ignored) then
    return reachable
  end

  local open = {
    {column = startColumn, row = startRow, distance = 0},
  }
  local visited = {[startColumn .. "," .. startRow] = 0}

  while #open > 0 do
    local bestIndex = 1
    for index = 2, #open do
      if open[index].distance < open[bestIndex].distance then
        bestIndex = index
      end
    end

    local node = table.remove(open, bestIndex)
    local column = node.column
    local row = node.row
    local distance = node.distance

    if distance > 0 then
      reachable[column .. "," .. row] = true
    end

    if distance < maxMoves then
      for _, neighbor in ipairs(self:getHexNeighbors(column, row)) do
        local nextColumn = neighbor[1]
        local nextRow = neighbor[2]
        local nextKey = nextColumn .. "," .. nextRow
        local stepCost = self:getMovementCost(nextColumn, nextRow)
        local nextDistance = distance + stepCost

        if
          self:isWalkableStep(nextColumn, nextRow, ignored)
          and nextDistance <= maxMoves
          and (visited[nextKey] == nil or nextDistance < visited[nextKey])
        then
          visited[nextKey] = nextDistance
          open[#open + 1] = {
            column = nextColumn,
            row = nextRow,
            distance = nextDistance,
          }
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

  local open = {
    {column = startColumn, row = startRow, distance = 0},
  }
  local visited = {[startColumn .. "," .. startRow] = 0}
  local previous = {}

  while #open > 0 do
    local bestIndex = 1
    for index = 2, #open do
      if open[index].distance < open[bestIndex].distance then
        bestIndex = index
      end
    end

    local node = table.remove(open, bestIndex)
    local column = node.column
    local row = node.row
    local distance = node.distance

    if column == targetColumn and row == targetRow then
      break
    end

    for _, neighbor in ipairs(self:getHexNeighbors(column, row)) do
      local nextColumn = neighbor[1]
      local nextRow = neighbor[2]
      local nextKey = nextColumn .. "," .. nextRow
      local nextDistance = distance + self:getMovementCost(nextColumn, nextRow)

      if
        self:isWalkableStep(nextColumn, nextRow, self.movingCharacter)
        and (visited[nextKey] == nil or nextDistance < visited[nextKey])
      then
        visited[nextKey] = nextDistance
        previous[nextKey] = {column, row}
        open[#open + 1] = {
          column = nextColumn,
          row = nextRow,
          distance = nextDistance,
        }
      end
    end
  end

  local targetKey = targetColumn .. "," .. targetRow
  if visited[targetKey] == nil then
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

function Battle:updateCharacterDirection(character, fromColumn, toColumn)
  if toColumn < fromColumn then
    character:setDirection("left")
  elseif toColumn > fromColumn then
    character:setDirection("right")
  end
end

function Battle:isHealer(character)
  return character and character.team == "player" and character.className == "healer"
end

function Battle:getAttackableTiles(activeCharacter)
  if self:isSplashAttacker(activeCharacter) then
    return self:getSplashAttackCenters(activeCharacter)
  end
  return self:getTilesInRange(
    activeCharacter.column,
    activeCharacter.row,
    activeCharacter.attackRange or 1
  )
end

function Battle:isSplashAttacker(character)
  return character and character.team == "enemy" and character.className == "affamé"
end

function Battle:getSplashAreaTiles(centerColumn, centerRow)
  local areaTiles = {[centerColumn .. "," .. centerRow] = true}
  for _, neighbor in ipairs(self:getHexNeighbors(centerColumn, centerRow)) do
    local column = neighbor[1]
    local row = neighbor[2]
    if self:isInMap(column, row) then
      areaTiles[column .. "," .. row] = true
    end
  end
  return areaTiles
end

function Battle:getSplashTargetsForCenter(activeCharacter, centerColumn, centerRow)
  local targets = {}
  local areaTiles = self:getSplashAreaTiles(centerColumn, centerRow)

  for _, character in ipairs(self:getOpponentsOf(activeCharacter)) do
    if areaTiles[character.column .. "," .. character.row] then
      targets[#targets + 1] = character
    end
  end

  return targets
end

function Battle:getSplashAttackCenters(activeCharacter)
  local centers = {}
  local tilesInRange = self:getTilesInRange(
    activeCharacter.column,
    activeCharacter.row,
    activeCharacter.attackRange or 2
  )

  for key in pairs(tilesInRange) do
    local commaIndex = key:find(",")
    local column = tonumber(key:sub(1, commaIndex - 1))
    local row = tonumber(key:sub(commaIndex + 1))
    if #self:getSplashTargetsForCenter(activeCharacter, column, row) > 0 then
      centers[key] = true
    end
  end

  return centers
end

function Battle:selectAttackTargetInDirection(originColumn, originRow, key)
  local originX, originY = self:getGridVector(originColumn, originRow)
  local bestColumn = originColumn
  local bestRow = originRow
  local bestPrimary = nil
  local bestSecondary = nil

  for _, character in ipairs(self.characters) do
    if self:isAttackable(character.column, character.row) then
      local targetX, targetY = self:getGridVector(character.column, character.row)
      local dx = targetX - originX
      local dy = targetY - originY
      local primary = nil
      local secondary = nil

      if key == "left" and dx < 0 then
        primary = -dx
        secondary = math.abs(dy)
      elseif key == "right" and dx > 0 then
        primary = dx
        secondary = math.abs(dy)
      elseif key == "up" and dy < 0 then
        primary = -dy
        secondary = math.abs(dx)
      elseif key == "down" and dy > 0 then
        primary = dy
        secondary = math.abs(dx)
      end

      if primary and (bestPrimary == nil or primary < bestPrimary or (primary == bestPrimary and secondary < bestSecondary)) then
        bestPrimary = primary
        bestSecondary = secondary
        bestColumn = character.column
        bestRow = character.row
      end
    end
  end

  return bestColumn, bestRow
end

function Battle:startAttackSelection(activeCharacter)
  if self.turnPhase ~= "action" then
    return false
  end

  self.attackRange = self:getAttackableTiles(activeCharacter)
  if self:isSplashAttacker(activeCharacter) then
    local bestCount = nil
    local bestDistance = nil

    for key in pairs(self.attackRange) do
      local commaIndex = key:find(",")
      local column = tonumber(key:sub(1, commaIndex - 1))
      local row = tonumber(key:sub(commaIndex + 1))
      local targets = self:getSplashTargetsForCenter(activeCharacter, column, row)
      local targetCount = #targets
      local distance = self:getTileDistance(activeCharacter.column, activeCharacter.row, column, row)

      if
        targetCount > 0
        and (
          bestCount == nil
          or targetCount > bestCount
          or (targetCount == bestCount and distance < bestDistance)
        )
      then
        bestCount = targetCount
        bestDistance = distance
        self.attackTarget.column = column
        self.attackTarget.row = row
      end
    end

    if bestCount then
      self.mode = "attack"
      return true
    end

    return false
  end

  local tilesInRange = self:getTilesInRange(
    activeCharacter.column,
    activeCharacter.row,
    activeCharacter.attackRange or 1
  )
  local nearestDistance = nil

  for _, character in ipairs(self:getOpponentsOf(activeCharacter)) do
    if character ~= activeCharacter then
      local key = character.column .. "," .. character.row
      local distance = tilesInRange[key]
      if distance and (nearestDistance == nil or distance < nearestDistance) then
        nearestDistance = distance
        self.attackTarget.column = character.column
        self.attackTarget.row = character.row
      end
    end
  end

  if nearestDistance then
    self.mode = "attack"
    return true
  end

  return false
end

function Battle:getHealableTargets(activeCharacter)
  local healable = {}

  for _, character in ipairs(self.characters) do
    if
      character ~= activeCharacter
      and character.team == activeCharacter.team
      and character.hp < character.maxHp
    then
      healable[character.column .. "," .. character.row] = true
    end
  end

  return healable
end

function Battle:startHealSelection(activeCharacter)
  if self.turnPhase ~= "move" or not self:isHealer(activeCharacter) then
    return false
  end

  self.healTargets = self:getHealableTargets(activeCharacter)
  local nearestDistance = nil

  for _, character in ipairs(self.characters) do
    if self:isHealable(character.column, character.row) then
      local distance = self:getTileDistance(activeCharacter.column, activeCharacter.row, character.column, character.row)
      if distance and (nearestDistance == nil or distance < nearestDistance) then
        nearestDistance = distance
        self.healTarget.column = character.column
        self.healTarget.row = character.row
      end
    end
  end

  if nearestDistance then
    self.mode = "heal"
    return true
  end

  self.healTargets = {}
  return false
end

function Battle:selectHealTargetInDirection(originColumn, originRow, key)
  local originX, originY = self:getGridVector(originColumn, originRow)
  local bestColumn = originColumn
  local bestRow = originRow
  local bestPrimary = nil
  local bestSecondary = nil

  for _, character in ipairs(self.characters) do
    if self:isHealable(character.column, character.row) then
      local targetX, targetY = self:getGridVector(character.column, character.row)
      local dx = targetX - originX
      local dy = targetY - originY
      local primary = nil
      local secondary = nil

      if key == "left" and dx < 0 then
        primary = -dx
        secondary = math.abs(dy)
      elseif key == "right" and dx > 0 then
        primary = dx
        secondary = math.abs(dy)
      elseif key == "up" and dy < 0 then
        primary = -dy
        secondary = math.abs(dx)
      elseif key == "down" and dy > 0 then
        primary = dy
        secondary = math.abs(dx)
      end

      if primary and (bestPrimary == nil or primary < bestPrimary or (primary == bestPrimary and secondary < bestSecondary)) then
        bestPrimary = primary
        bestSecondary = secondary
        bestColumn = character.column
        bestRow = character.row
      end
    end
  end

  return bestColumn, bestRow
end

function Battle:moveHealTargetByKey(activeCharacter, key)
  self.healTarget.column, self.healTarget.row = self:selectHealTargetInDirection(
    self.healTarget.column,
    self.healTarget.row,
    key
  )
end

function Battle:confirmHeal(activeCharacter)
  if not self:isHealable(self.healTarget.column, self.healTarget.row) then
    return false
  end

  local target = self:getCharacterAt(self.healTarget.column, self.healTarget.row, nil)
  if not target or target.team ~= activeCharacter.team or target == activeCharacter then
    return false
  end

  self.healTargets = {}
  self.mode = "heal_animating"
  if self.effects then
    self.effects:startHealAnimation(activeCharacter, target)
  end
  return true
end

function Battle:getBestMoveTileFor(activeCharacter)
  local bestColumn = activeCharacter.column
  local bestRow = activeCharacter.row
  local bestScore = nil
  local bestTargetDistance = nil
  local reachable = self:getReachableTiles(activeCharacter.column, activeCharacter.row, activeCharacter.mov, activeCharacter)
  local opponents = self:getOpponentsOf(activeCharacter)

  local function evaluateTile(column, row)
    local targetDistance = nil
    for _, opponent in ipairs(opponents) do
      local distance = self:getTileDistance(column, row, opponent.column, opponent.row)
      if distance and (targetDistance == nil or distance < targetDistance) then
        targetDistance = distance
      end
    end

    if not targetDistance then
      return
    end

    local score = math.max(0, targetDistance - (activeCharacter.attackRange or 1))
    if
      bestScore == nil
      or score < bestScore
      or (score == bestScore and targetDistance < bestTargetDistance)
    then
      bestScore = score
      bestTargetDistance = targetDistance
      bestColumn = column
      bestRow = row
    end
  end

  evaluateTile(activeCharacter.column, activeCharacter.row)
  for key in pairs(reachable) do
    local commaIndex = key:find(",")
    local column = tonumber(key:sub(1, commaIndex - 1))
    local row = tonumber(key:sub(commaIndex + 1))
    evaluateTile(column, row)
  end

  return bestColumn, bestRow
end

function Battle:startMoveSelection(activeCharacter)
  if self.turnPhase ~= "move" then
    return
  end
  self.movingCharacter = activeCharacter
  self.moveRange = self:getReachableTiles(activeCharacter.column, activeCharacter.row, activeCharacter.mov, activeCharacter)
  self.moveTarget.column = activeCharacter.column
  self.moveTarget.row = activeCharacter.row
  self.mode = "move"
end

function Battle:setMoveTarget(column, row)
  self.moveTarget.column = column
  self.moveTarget.row = row
end

function Battle:moveTargetByKey(key)
  local nextColumn = self.moveTarget.column
  local nextRow = self.moveTarget.row
  local neighbors = self:getHexNeighbors(self.moveTarget.column, self.moveTarget.row)
  local candidates = {}

  if key == "left" then
    candidates[1] = neighbors[2]
    candidates[2] = neighbors[6]
  elseif key == "right" then
    candidates[1] = neighbors[1]
    candidates[2] = neighbors[5]
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

function Battle:moveAttackTargetByKey(activeCharacter, key)
  self.attackTarget.column, self.attackTarget.row = self:selectAttackTargetInDirection(
    self.attackTarget.column,
    self.attackTarget.row,
    key
  )
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
      self:updateCharacterDirection(activeCharacter, path[1].column, path[2].column)
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

function Battle:isBackAttack(attacker, defender)
  local attackerX = self:getGridVector(attacker.column, attacker.row)
  local defenderX = self:getGridVector(defender.column, defender.row)

  if defender.direction == "right" then
    return attackerX < defenderX
  elseif defender.direction == "left" then
    return attackerX > defenderX
  end

  return false
end

function Battle:calculateDamage(attacker, defender)
  local critical = attacker and attacker.team == "player" and love.math.random(6) == 1
  local damage = nil
  if self:isBackAttack(attacker, defender) then
    damage = math.max(1, attacker.atk)
  else
    damage = math.max(1, attacker.atk - defender.def)
  end
  if critical then
    damage = damage + 2
  end
  return damage, critical
end

function Battle:isMeleeAttack(attacker, defender)
  if not attacker or not defender then
    return false
  end
  return self:getTileDistance(attacker.column, attacker.row, defender.column, defender.row) == 1
end

function Battle:canCounterAttack(attacker, defender)
  return
    attacker
    and defender
    and defender.className == "counter"
    and defender.hp > 0
    and self:isMeleeAttack(attacker, defender)
end

function Battle:calculateCounterDamage(attacker, defender)
  local attackerAtk = attacker and attacker.atk or 0
  local attackerDef = attacker and attacker.def or 0
  return math.max(1, attackerAtk - attackerDef)
end

function Battle:defeatCharacter(target)
  for index, character in ipairs(self.characters) do
    if character == target then
      table.remove(self.characters, index)
      return
    end
  end
end

function Battle:shouldLeaveThorns(character)
  return character and character.team == "enemy" and character.className == "embourbe"
end

function Battle:shouldLeaveAlgae(character)
  return character and character.team == "enemy" and character.className == "noye"
end

function Battle:applyLandingTileEffects(character, column, row)
  if not character or character.team ~= "player" then
    if character then
      print(string.format("[thorns] skip landing effects for %s team=%s", character.name, tostring(character.team)))
    end
    return false
  end
  local targetColumn = column or character.column
  local targetRow = row or character.row
  print(string.format("[thorns] landing check %s at %d,%d thorn=%s", character.name, targetColumn, targetRow, tostring(self:hasThornsAt(targetColumn, targetRow))))
  if not self:hasThornsAt(targetColumn, targetRow) then
    return false
  end

  character.hp = math.max(0, character.hp - 1)
  print(string.format("[thorns] %s takes 1 damage, hp=%d", character.name, character.hp))
  self:addDamagePopup(targetColumn, targetRow, 1)
  if character.hp <= 0 then
    print(string.format("[thorns] %s defeated by thorns at %d,%d", character.name, targetColumn, targetRow))
    self.mode = "death_animating"
    self.deathAnimation = {
      character = character,
      attacker = character,
      timer = 0,
    }
    return true
  end

  return false
end

function Battle:confirmAttack(activeCharacter)
  if not self:isAttackable(self.attackTarget.column, self.attackTarget.row) then
    return false
  end

  if self:isSplashAttacker(activeCharacter) then
    local targets = self:getSplashTargetsForCenter(activeCharacter, self.attackTarget.column, self.attackTarget.row)
    if #targets == 0 then
      return false
    end

    self:updateCharacterDirection(activeCharacter, activeCharacter.column, self.attackTarget.column)
    self.attackRange = {}
    self.mode = "attack_animating"
    self.attackAnimation = {
      kind = "splash",
      attacker = activeCharacter,
      centerColumn = self.attackTarget.column,
      centerRow = self.attackTarget.row,
      targets = targets,
      target = targets[1],
      timer = 0,
      applied = false,
      defeatedTargets = {},
    }
    return true
  end

  local target = self:getCharacterAt(self.attackTarget.column, self.attackTarget.row, activeCharacter)
  if not target then
    return false
  end

  self:updateCharacterDirection(activeCharacter, activeCharacter.column, target.column)
  self.attackRange = {}
  local damage, critical = self:calculateDamage(activeCharacter, target)
  self.mode = "attack_animating"
  self.attackAnimation = {
    attacker = activeCharacter,
    target = target,
    startHp = target.hp,
    damage = damage,
    critical = critical,
    counterDamage = nil,
    counterApplied = false,
    timer = 0,
    applied = false,
    defeatedTargets = {},
  }
  return true
end

function Battle:cancelMoveMode()
  self.mode = "menu"
  self.moveRange = {}
end

function Battle:cancelAttackMode()
  self.mode = "menu"
  self.attackRange = {}
end

function Battle:cancelHealMode()
  self.mode = "menu"
  self.healTargets = {}
end

function Battle:update(dt)
  self:updateDamagePopups(dt)

  if self.moveAnimation then
    local animation = self.moveAnimation
    animation.timer = animation.timer + dt
    while animation.timer >= self.moveStepDuration do
      animation.step = animation.step + 1
      animation.timer = animation.timer - self.moveStepDuration

      if animation.step >= #animation.path then
        local finalNode = animation.path[#animation.path]
        print(string.format("[move] final landing for %s at %d,%d", animation.character.name, finalNode.column, finalNode.row))
        animation.character:setPosition(finalNode.column, finalNode.row)
        if self:shouldLeaveThorns(animation.character) then
          self:addThorns(finalNode.column, finalNode.row)
        end
        if self:shouldLeaveAlgae(animation.character) then
          self:addAlgae(finalNode.column, finalNode.row)
        end
        self.moveAnimation = nil
        self.movingCharacter = nil
        if self:applyLandingTileEffects(animation.character, finalNode.column, finalNode.row) then
          return
        end
        self:startActionPhase()
        return
      end

      local fromNode = animation.path[animation.step]
      local toNode = animation.path[animation.step + 1]
      if fromNode and toNode then
        print(string.format("[move] %s traverses %d,%d -> %d,%d", animation.character.name, fromNode.column, fromNode.row, toNode.column, toNode.row))
      end
      if self:shouldLeaveThorns(animation.character) and fromNode then
        self:addThorns(fromNode.column, fromNode.row)
      end
      if self:shouldLeaveAlgae(animation.character) and fromNode then
        self:addAlgae(fromNode.column, fromNode.row)
      end
      if fromNode and toNode then
        self:updateCharacterDirection(animation.character, fromNode.column, toNode.column)
      end
    end
    return
  end

  if self:getHealAnimation() then
    local completedHealer = self.effects and self.effects:updateHealAnimation(dt) or nil
    if completedHealer then
      self.mode = "menu"
      self.completedActionCharacter = completedHealer
      return
    end
    return
  end

  if self.attackAnimation then
    local animation = self.attackAnimation
    animation.timer = animation.timer + dt
    local strikeDuration =
      self.attackWindupDuration
      + self.attackLungeDuration
      + self.attackImpactDuration
      + self.attackRetreatDuration
      + self.attackHoldDuration

    if not animation.applied and animation.timer >= self.attackWindupDuration + self.attackLungeDuration then
      animation.applied = true
      if animation.kind == "splash" then
        local hitPlayer = false
        for _, target in ipairs(animation.targets) do
          local damage = self:calculateDamage(animation.attacker, target)
          target.hp = target.hp - damage
          self:addDamagePopup(target.column, target.row, damage)
          if target.team == "player" then
            hitPlayer = true
          end
          if target.hp <= 0 then
            target.hp = 0
            animation.defeatedTargets[#animation.defeatedTargets + 1] = target
          end
        end
        if hitPlayer then
          self:triggerScreenShake(0.24, 14)
        end
      else
        animation.target.hp = animation.target.hp - animation.damage
        if animation.target.team == "player" then
          self:triggerScreenShake(0.24, 14)
        end
        if animation.critical then
          self:triggerScreenShake(0.32, 22)
          self:triggerSlowMotion(0.2, 0.3)
        end
        if animation.target.hp <= 0 then
          animation.target.hp = 0
          animation.defeatedTargets[#animation.defeatedTargets + 1] = animation.target
        elseif not animation.counterApplied and self:canCounterAttack(animation.attacker, animation.target) then
          animation.counterDamage = self:calculateCounterDamage(animation.attacker, animation.target)
        end
      end
    end

    if
      animation.counterDamage
      and not animation.counterApplied
      and animation.timer >= strikeDuration + self.attackWindupDuration + self.attackLungeDuration
    then
      animation.counterApplied = true
      animation.attacker.hp = animation.attacker.hp - animation.counterDamage
      if animation.attacker.team == "player" then
        self:triggerScreenShake(0.24, 14)
      end
      if animation.attacker.hp <= 0 then
        animation.attacker.hp = 0
        animation.defeatedTargets[#animation.defeatedTargets + 1] = animation.attacker
      end
    end

    local totalDuration = strikeDuration
    if animation.counterDamage then
      totalDuration = totalDuration + strikeDuration
    end

    if animation.timer >= totalDuration then
      if #animation.defeatedTargets > 0 then
        self.attackAnimation = nil
        self.mode = "death_animating"
        self.deathQueue = {
          attacker = animation.attacker,
          targets = animation.defeatedTargets,
          index = 1,
        }
        self.deathAnimation = {
          character = animation.defeatedTargets[1],
          attacker = animation.attacker,
          timer = 0,
        }
        return
      end
      self.attackAnimation = nil
      self.mode = "menu"
      self.completedActionCharacter = animation.attacker
      return
    end
    return
  end

  if self.deathAnimation then
    local animation = self.deathAnimation
    animation.timer = animation.timer + dt

    if animation.timer >= self.deathDuration then
      self:defeatCharacter(animation.character)
      if self.deathQueue and self.deathQueue.index < #self.deathQueue.targets then
        self.deathQueue.index = self.deathQueue.index + 1
        self.deathAnimation = {
          character = self.deathQueue.targets[self.deathQueue.index],
          attacker = self.deathQueue.attacker,
          timer = 0,
        }
      else
        self.deathAnimation = nil
        self.deathQueue = nil
        self.mode = "menu"
        self.completedActionCharacter = animation.attacker
      end
    end
  end
end

return Battle
