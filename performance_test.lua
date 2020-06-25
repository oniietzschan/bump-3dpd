local RNG_SEED = 69420731
local WORLD_SIZE = 10
local OBJECT_COUNT = 100
local MOVEMENT_GENERATIONS = 25
local MOVE_RANGE = 1
local TEST_COUNT = 10

local function clamp(lower, val, upper)
  if lower > upper then lower, upper = upper, lower end
  return math.max(lower, math.min(upper, val))
end

local function doTest(world, moveFn)
  -- seed RNG
  math.randomseed(RNG_SEED)

  -- create OBJECT_COUNT random entities
  local entities = {}
  for i = 1, OBJECT_COUNT do
    local x = math.random() * WORLD_SIZE
    local y = math.random() * WORLD_SIZE
    local z = math.random() * WORLD_SIZE
    local w = (math.random() * 1.5) + 0.5
    local h = (math.random() * 1.5) + 0.5
    local d = (math.random() * 1.5) + 0.5
    local entity = {name = i}
    table.insert(entities, entity)
    world:add(entity, x, y, z, w, h, d)
  end

  -- Collect garbage and stop GC.
  collectgarbage('collect')
  collectgarbage('stop')

  -- move all entities for MOVEMENT_GENERATIONS generations.
  local collisions = 0
  for _ = 1, MOVEMENT_GENERATIONS do
    for _, entity in ipairs(entities) do
      local x, y, z = world:getCube(entity)
      local goalX = clamp(0, x - MOVE_RANGE + (math.random() * MOVE_RANGE * 2), WORLD_SIZE)
      local goalY = clamp(0, y - MOVE_RANGE + (math.random() * MOVE_RANGE * 2), WORLD_SIZE)
      local goalZ = clamp(0, z - MOVE_RANGE + (math.random() * MOVE_RANGE * 2), WORLD_SIZE)
      local len = moveFn(world, entity, goalX, goalY, goalZ)
      collisions = collisions + len
    end
    -- if world.debug then world.debug() end
  end

  -- restart GC and measure memory difference before and after.
  local kbBefore = collectgarbage('count')
  collectgarbage('restart')
  collectgarbage('collect')
  local kbAfter = collectgarbage('count')
  local kbGarbage = kbBefore - kbAfter

  -- -- Print stats.
  -- print(("Collisions: %d"):format(collisions))
  -- print(("Garbage: %.2fkB"):format(kbGarbage))

  return kbGarbage
end

local function doTests(label, bump, moveFn)
  print(("============= %s ============="):format(label))
  local totalGarbage = 0
  for _ = 1, TEST_COUNT do
    local world = bump.newWorld(1)
    local garbage = doTest(world, moveFn)
    totalGarbage = totalGarbage + garbage
  end
  local averageGarbage = totalGarbage / TEST_COUNT
  print(("Garbage: %.2f kB"):format(averageGarbage))
  print(("(Average after %d tests.)\n"):format(TEST_COUNT))
end

local function moveOriginalFn(world, entity, goalX, goalY, goalZ)
  local len = select(5, world:move(entity, goalX, goalY, goalZ))
  return len
end
doTests('Original', require 'bump-3dpd-original', moveOriginalFn)

local function moveModdedFn(world, entity, goalX, goalY, goalZ)
  local _, _, _, cols, len = world:move(entity, goalX, goalY, goalZ)
  world.freeCollisionTable(cols)
  return len
end
doTests('New', require 'bump-3dpd', moveModdedFn)
