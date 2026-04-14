local cols = 10
local rows = 10

local tile = nil
local tileW = 0
local tileH = 0
local grid = {}

function love.load()
  love.graphics.setBackgroundColor(1, 1, 1)

  tile = love.graphics.newImage("assets/sprites/hexa.png")
  tileW = tile:getWidth()
  tileH = tile:getHeight()

  for c = 1, cols do
    grid[c] = {}
    for r = 1, rows do
      grid[c][r] = true
    end
  end

  local cellSpacingX = tileW * 0.75
  local cellSpacingY = tileH
  local offsetY = tileH / 2
  local windowWidth = math.floor((cols - 1) * cellSpacingX + tileW + 1)
  local windowHeight = math.floor(rows * cellSpacingY + offsetY + 1)
  love.window.setMode(windowWidth, windowHeight)
end

function love.draw()
  local cellSpacingX = tileW * 0.75
  local cellSpacingY = tileH
  for c = 1, cols do
    for r = 1, rows do
      if grid[c][r] then
        local x = (c - 1) * cellSpacingX
        local y = (r - 1) * cellSpacingY
        if c % 2 == 1 then
          y = y + (tileH / 2)
        end

        love.graphics.draw(tile, x, y)
      end
    end
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
