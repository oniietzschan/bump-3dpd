local bump3dpd = require 'bump-3dpd'

local seed = os.time()
print('Seeding RNG with: ' .. seed)
math.randomseed(seed)

io.stdout:setvbuf("no") -- Enable console output.

local isDrawConsole = false

local collisionsThisTick = 0

local world = bump3dpd.newWorld()

local playerHeight = 25
local player = {
  name = 'player',
  x = 50,
  y = 50,
  z = -playerHeight,
  w = 20,
  h = 20,
  d = playerHeight,
  zVelocity = 0,
  speed = 140,
  jump = 375,
  gravity = 750,
  color = {
    r = 0,
    g = 255,
    b = 0,
  },
}

local consoleBuffer = {}
local consoleBufferSize = 15
for i = 1, consoleBufferSize do
  consoleBuffer[i] = ''
end

local function addBlock(x,y,z,w,h,d)
  local block = {
    name = 'block',
    color = {
      r = 255,
      g = 0,
      b = 0,
    },
  }
  world:add(block, x,y,z,w,h,d)

  return block
end

function love.load()
  world:add(player, player.x, player.y, player.z, player.w, player.h, player.d)

  -- Add floor.
  local floor = addBlock(0, 0, 0, 800, 600, 5)
  floor.invisible = true

  -- Add walls around the edge.
  addBlock(     0,      0, -20, 800-32,     32, 20)
  addBlock(800-32,      0, -20,     32, 600-32, 20)
  addBlock(    32, 600-32, -20, 800-32,     32, 20)
  addBlock(     0,     32, -20,     32, 600-32, 20)

  -- Add 30 random blocks. No intersection.
  for i=1,30 do
    local verticalMagnitude = math.random(10, 100)

    local x = math.random(100, 600)
    local y = math.random(100, 400)
    local z = verticalMagnitude * -1
    local w = math.random(10, 100)
    local h = math.random(10, 100)
    local d = verticalMagnitude

    local items = world:queryCube(x, y, z, w, h, d)
    if #items == 0 then
      addBlock(x, y, z, w, h, d)
    end
  end
end

local function consolePrint(msg)
  table.remove(consoleBuffer,1)
  consoleBuffer[consoleBufferSize] = msg
end

local function updatePlayer(dt)
  local dx, dy = 0, 0

  -- Walking
  if love.keyboard.isDown('right') then
    dx = player.speed * dt
  end
  if love.keyboard.isDown('left') then
    dx = -player.speed * dt
  end
  if love.keyboard.isDown('down') then
    dy = player.speed * dt
  end
  if love.keyboard.isDown('up') then
    dy = -player.speed * dt
  end

  -- Jumping
  local isOnGround = player.zVelocity == 0
  if isOnGround and love.keyboard.isDown('space') then
    player.zVelocity = player.jump * -1
  end

  -- Apply gravity.
  player.zVelocity = player.zVelocity + player.gravity * dt

  if dx ~= 0 or dy ~= 0 or player.zVelocity ~= 0 then
    local cols
    player.x, player.y, player.z, cols, collisionsThisTick = world:move(
      player,
      player.x + dx,
      player.y + dy,
      player.z + player.zVelocity * dt
    )
    for i=1, collisionsThisTick do
      local col = cols[i]
      consolePrint(("col.other = %s, col.type = %s, col.normal = %d,%d,%d"):format(
        col.other,
        col.type,
        col.normal.x,
        col.normal.y,
        col.normal.z
      ))
      if col.normal.z ~= 0 then
        player.zVelocity = 0
      end
    end
  end
end

local memoryTotalLastFrame = 0
local memoryChangeThisFrame = 0

local function calculateMemoryChangeThisFrame()
  local memoryTotalThisFrame = collectgarbage("count")
  memoryChangeThisFrame = memoryTotalThisFrame - memoryTotalLastFrame
  memoryTotalLastFrame = memoryTotalThisFrame
end

function love.update(dt)
  collisionsThisTick = 0

  if love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
    dt = dt / 100
  end

  updatePlayer(dt)
  calculateMemoryChangeThisFrame()
end

local function drawPlayerShadow()
  local color = player.color
  love.graphics.setColor(color.r * 0.15, color.g * 0.15, color.b * 0.15)
  local x,y,_,w,h,_ = world:getCube(player)
  love.graphics.rectangle("fill", x, y, w, h)
end

-- Z-Sorting algorithm implementation was largely informed by this excellent blog post:
-- http://andrewrussell.net/2016/06/how-2-5d-sorting-works-in-river-city-ransom-underground/
local getZSortedItems
do
  -- We use the original, 2d version of bump.lua in order to detect which items
  -- overlap when painting the world.
  -- https://github.com/kikito/bump.lua
  local bump2d   = require 'demolibs.bump'

  -- Topological sorting library.
  -- https://github.com/bungle/lua-resty-tsort
  local tsort    = require 'demolibs.tsort'

  local world2d = bump2d.newWorld()

  getZSortedItems = function()
    -- Add or update draw positions of all visible items.
    for _, item in ipairs(world:getItems()) do
      if item.invisible ~= true then
        local x,y,z,w,h,d = world:getCube(item)
        if world2d:hasItem(item) then
          world2d:update(item, x, y + z)
        else
          world2d:add(item, x, y + z, w, h + d)
        end
      end
    end

    local graph = tsort.new()
    local noOverlap = {}

    -- Iterate through all visible items, and calculate ordering of all pairs
    -- of overlapping items.
    -- TODO: Each pair is calculated twice currently. Maybe this is slow?
    for _, itemA in ipairs(world2d:getItems()) do repeat
      local x, y, w, h = world2d:getRect(itemA)
      local otherItemsFilter = function(other) return other ~= itemA end
      local overlapping, len = world2d:queryRect(x, y, w, h, otherItemsFilter)

      if len == 0 then
        table.insert(noOverlap, itemA)

        break
      end

      local _, aY, aZ, _, aH, aD = world:getCube(itemA)
      for _, itemB in ipairs(overlapping) do
        local _, bY, bZ, _, bH, bD = world:getCube(itemB)
        if aZ + aD <= bZ then
          -- item A is completely above item B
          graph:add(itemB, itemA)
        elseif bZ + bD <= aZ then
          -- item B is completely above item A
          graph:add(itemA, itemB)
        elseif aY + aH <= bY then
          -- item A is completely behind item B
          graph:add(itemA, itemB)
        elseif bY + bH <= aY then
          -- item B is completely behind item A
          graph:add(itemB, itemA)
        elseif aY + aZ + aH + aD >= bY + bZ + bH + bD then
          -- item A's forward-most point is in front of item B's forward-most point
          graph:add(itemB, itemA)
        else
          -- item B's forward-most point is in front of item A's forward-most point
          graph:add(itemA, itemB)
        end
      end
    until true end

    local sorted, err = graph:sort()
    if err then
      error(err)
    end
    for _, item in ipairs(noOverlap) do
      table.insert(sorted, item)
    end

    return sorted
  end
end

local function drawItem(item)
  if item.invisible == true then
    return
  end

  local setAlpha = function(alpha)
    love.graphics.setColor(
      item.color.r * alpha,
      item.color.g * alpha,
      item.color.b * alpha
    )
  end

  local x,y,z,w,h,d = world:getCube(item)

  -- Front Side
  setAlpha(0.3)
  love.graphics.rectangle("fill", x, y + z + h, w, d)
  setAlpha(1)
  love.graphics.rectangle("line", x, y + z + h, w, d)

  -- Top
  setAlpha(0.5)
  love.graphics.rectangle("fill", x, y + z, w, h)
  setAlpha(1)
  love.graphics.rectangle("line", x, y + z, w, h)
end

local drawWorld = function()
  drawPlayerShadow()

  for _, item in ipairs(getZSortedItems()) do
    drawItem(item)
  end
end

local INSTRUCTIONS = [[
  bump-3dpd simple demo

    arrows: move
    space: jump
    tab: toggle console info
    delete: run garbage collector
]]

local function drawInstructions()
  love.graphics.setColor(255, 255, 255)
  love.graphics.print(INSTRUCTIONS, 550, 10)
end

local function drawDebug()
  local statistics = ("fps: %d, mem: %dKB, mem/frame: %.3fKB, collisions: %d, items: %d"):format(
    love.timer.getFPS(),
    collectgarbage("count"),
    memoryChangeThisFrame,
    collisionsThisTick,
    world:countItems(),
    player.x,
    player.y,
    player.z
  )
  love.graphics.setColor(255, 255, 255)
  love.graphics.printf(statistics, 0, 580, 790, 'right')
end

local function drawConsole()
  for i = 1, consoleBufferSize do
    love.graphics.setColor(255,255,255, i*255/consoleBufferSize)
    love.graphics.printf(consoleBuffer[i], 10, 580-(consoleBufferSize - i)*12, 790, "left")
  end
end

function love.draw()
  drawWorld()

  drawInstructions()
  drawDebug()
  if isDrawConsole then
    drawConsole()
  end
end

function love.keypressed(k)
  if k == "escape" then
    love.event.quit()
  end

  if k == "tab" then
    isDrawConsole = not isDrawConsole
  end

  if k == "delete" then
    collectgarbage("collect")
  end
end
