local bump = require 'bump'

local seed = 1504899684 -- os.time()
print('Seeding RNG with: ' .. seed)
math.randomseed(seed)

-- Enable console output.
io.stdout:setvbuf("no")

local shouldDrawConsole = false

local instructions = [[
  bump.lua simple demo

    arrows: move
    space: jump
    tab: toggle console info
    delete: run garbage collector
]]

local collisionsThisTick = 0

local world = bump.newWorld()

local ph = 25
local player = {
  x = 50,
  y = 50,
  z = -ph,
  w = 20,
  h = 20,
  d = ph,
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
for i=1,consoleBufferSize do consoleBuffer[i] = "" end

local function addBlock(x,y,z,w,h,d)
  local block = {
    x = x,
    y = y,
    z = z,
    w = w,
    h = h,
    d = d,
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
  local floor = addBlock(0, 0, 0, 800, 800, 5)
  floor.invisible = true

  -- Add walls around the edge.
  addBlock(     0,      0, -32, 800,       32, 32)
  addBlock(     0,     32, -32,  32, 600-32*2, 32)
  addBlock(800-32,     32, -32,  32, 600-32*2, 32)
  addBlock(     0, 600-32, -32, 800,       32, 32)

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

function love.update(dt)
  collisionsThisTick = 0

  if love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
    dt = dt / 100
  end

  updatePlayer(dt)
end

local function drawPlayerShadow()
  local color = player.color
  love.graphics.setColor(color.r * 0.15, color.g * 0.15, color.b * 0.15)
  local x,y,_,w,h,_ = world:getCube(player)
  love.graphics.rectangle("fill", x, y, w, h)
end

local function drawItem(item)
  if item.invisible == true then
    return
  end

  local setAlpha = function(alpha)
    local color = item.color
    love.graphics.setColor(color.r * alpha, color.g * alpha, color.b * alpha)
  end

  local x,y,z,w,h,d = world:getCube(item)

  -- -- Back Side
  -- setAlpha(0.15)
  -- love.graphics.rectangle("fill", x, y + z, w, d)
  -- setAlpha(1)
  -- love.graphics.rectangle("line", x, y + z, w, d)

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

  -- -- Bottom
  -- setAlpha(1)
  -- love.graphics.rectangle("line", x, y + z + d, w, h)
end

local function drawItemDebug(item)
  if item.sort == nil then
    return
  end

  local x,y,z,_,h,_ = world:getCube(item)

  love.graphics.setColor(255, 255, 255)
  love.graphics.print(y .. ' + ' .. h .. ' = ' .. item.sort , x, y + z)
end

local function drawSort(a, b)
  a.sort = a.z
  b.sort = b.z

  if a.z + a.d == b.z + b.d then
    if a.y == b.y then
      return false
    else
      return a.y < b.y
    end
  else
    return a.z + a.d > b.z + b.d
  end
end

local drawWorld = function()
  drawPlayerShadow()

  local items = world:getItems()
  table.sort(items, drawSort)
  for _, item in ipairs(items) do
    drawItem(item)
  end
  for _, item in ipairs(items) do
    drawItemDebug(item)
  end

  --testing only
  drawPlayerShadow()
end

local function drawMessage()
  local msg = instructions:format(tostring(shouldDrawConsole))
  love.graphics.setColor(255, 255, 255)
  love.graphics.print(msg, 550, 10)
end

local function drawDebug()
  local statistics = ("fps: %d, mem: %dKB, collisions: %d, items: %d, player: (%d, %d, %d)"):format(
    love.timer.getFPS(),
    collectgarbage("count"),
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

  drawDebug()

  if shouldDrawConsole then
    drawConsole()
  end

  drawMessage()
end

function love.keypressed(k)
  if k == "escape" then
    love.event.quit()
  end

  if k == "tab" then
    shouldDrawConsole = not shouldDrawConsole
  end

  if k == "delete" then
    collectgarbage("collect")
  end
end
