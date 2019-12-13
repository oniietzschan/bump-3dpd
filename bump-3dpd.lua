--[[

bump-3dpd 1.0.0
===============

bump-3dpd by shru. (see: https://github.com/oniietzschan/bump-3dpd)

This is a 3D conversion of kikito's excellent bump.lua. (see: https://github.com/kikito/bump.lua)

MIT LICENSE
-----------

Copyright (c) 2014 Enrique García Cota

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--]]

------------------------------------------
-- Table Pool
------------------------------------------

local Pool = {}
do
  local ok, tableClear = pcall(require, 'table.clear')
  if not ok then
    tableClear = function (t)
      for k, _ in pairs(t) do
        t[k] = nil
      end
    end
  end

  local pool = {}
  local len = 0

  function Pool.fetch()
    if len == 0 then
      Pool.free({})
    end
    local t = table.remove(pool, len)
    len = len - 1
    return t
  end

  function Pool.free(t)
    tableClear(t)
    len = len + 1
    pool[len] = t
  end
end

------------------------------------------
-- Auxiliary functions
------------------------------------------

local DELTA = 1e-10 -- floating-point margin of error

local abs, floor, ceil, min, max = math.abs, math.floor, math.ceil, math.min, math.max

local function sign(x)
  if x > 0 then return 1 end
  if x == 0 then return 0 end
  return -1
end

local function nearest(x, a, b)
  if abs(a - x) < abs(b - x) then return a else return b end
end

local function assertType(desiredType, value, name)
  if type(value) ~= desiredType then
    error(name .. ' must be a ' .. desiredType .. ', but was ' .. tostring(value) .. '(a ' .. type(value) .. ')')
  end
end

local function assertIsPositiveNumber(value, name)
  if type(value) ~= 'number' or value <= 0 then
    error(name .. ' must be a positive integer, but was ' .. tostring(value) .. '(' .. type(value) .. ')')
  end
end

local function assertIsCube(x,y,z,w,h,d)
  assertType('number', x, 'x')
  assertType('number', y, 'y')
  assertType('number', z, 'z')
  assertIsPositiveNumber(w, 'w')
  assertIsPositiveNumber(h, 'h')
  assertIsPositiveNumber(d, 'd')
end

local defaultFilter = function()
  return 'slide'
end

------------------------------------------
-- Cube functions
------------------------------------------

local function cube_getNearestCorner(x,y,z,w,h,d, px, py, pz)
  return nearest(px, x, x + w),
         nearest(py, y, y + h),
         nearest(pz, z, z + d)
end

-- This is a generalized implementation of the liang-barsky algorithm, which also returns
-- the normals of the sides where the segment intersects.
-- Returns nil if the segment never touches the cube
-- Notice that normals are only guaranteed to be accurate when initially ti1, ti2 == -math.huge, math.huge
local function cube_getSegmentIntersectionIndices(x,y,z,w,h,d, x1,y1,z1,x2,y2,z2, ti1,ti2)
  ti1, ti2 = ti1 or 0, ti2 or 1
  local dx = x2 - x1
  local dy = y2 - y1
  local dz = z2 - z1
  local nx, ny, nz
  local nx1, ny1, nz1, nx2, ny2, nz2 = 0,0,0,0,0,0
  local p, q, r

  for side = 1,6 do
    if     side == 1 then -- Left
      nx,ny,nz,p,q = -1,  0,  0, -dx, x1 - x
    elseif side == 2 then -- Right
      nx,ny,nz,p,q =  1,  0,  0,  dx, x + w - x1
    elseif side == 3 then -- Top
      nx,ny,nz,p,q =  0, -1,  0, -dy, y1 - y
    elseif side == 4 then -- Bottom
      nx,ny,nz,p,q =  0,  1,  0,  dy, y + h - y1
    elseif side == 5 then -- Front
      nx,ny,nz,p,q =  0,  0, -1, -dz, z1 - z
    else --                  Back
      nx,ny,nz,p,q =  0,  0,  1,  dz, z + d - z1
    end

    if p == 0 then
      if q <= 0 then
        return nil
      end
    else
      r = q / p
      if p < 0 then
        if     r > ti2 then
          return nil
        elseif r > ti1 then
          ti1, nx1,ny1,nz1 = r, nx,ny,nz
        end
      else -- p > 0
        if     r < ti1 then
          return nil
        elseif r < ti2 then
          ti2, nx2,ny2,nz2 = r,nx,ny,nz
        end
      end
    end
  end

  return ti1,ti2, nx1,ny1,nz1, nx2,ny2,nz2
end

-- Calculates the minkowsky difference between 2 cubes, which is another cube
local function cube_getDiff(x1,y1,z1,w1,h1,d1, x2,y2,z2,w2,h2,d2)
  return x2 - x1 - w1,
         y2 - y1 - h1,
         z2 - z1 - d1,
         w1 + w2,
         h1 + h2,
         d1 + d2
end

local function cube_containsPoint(x,y,z,w,h,d, px,py,pz)
  return px - x > DELTA
     and py - y > DELTA
     and pz - z > DELTA
     and x + w - px > DELTA
     and y + h - py > DELTA
     and z + d - pz > DELTA
end

local function cube_isIntersecting(x1,y1,z1,w1,h1,d1, x2,y2,z2,w2,h2,d2)
  return x1 < x2 + w2 and x2 < x1 + w1 and
         y1 < y2 + h2 and y2 < y1 + h1 and
         z1 < z2 + d2 and z2 < z1 + d1
end

local function cube_getCubeDistance(x1,y1,z1,w1,h1,d1, x2,y2,z2,w2,h2,d2)
  local dx = x1 - x2 + (w1 - w2)/2
  local dy = y1 - y2 + (h1 - h2)/2
  local dz = z1 - z2 + (d1 - d2)/2
  return (dx * dx) + (dy * dy) + (dz * dz)
end

local function cube_detectCollision(x1,y1,z1,w1,h1,d1, x2,y2,z2,w2,h2,d2, goalX, goalY, goalZ)
  goalX = goalX or x1
  goalY = goalY or y1
  goalZ = goalZ or z1

  local dx = goalX - x1
  local dy = goalY - y1
  local dz = goalZ - z1
  local x,y,z,w,h,d = cube_getDiff(x1,y1,z1,w1,h1,d1, x2,y2,z2,w2,h2,d2)

  local overlaps, ti, nx, ny, nz

  if cube_containsPoint(x,y,z,w,h,d, 0,0,0) then -- item was intersecting other
    local px, py, pz = cube_getNearestCorner(x,y,z,w,h,d, 0,0,0)
    -- Volume of intersection:
    local wi = min(w1, abs(px))
    local hi = min(h1, abs(py))
    local di = min(d1, abs(pz))
    ti = wi * hi * di * -1 -- ti is the negative volume of intersection
    overlaps = true
  else
    local ti1,ti2,nx1,ny1,nz1 = cube_getSegmentIntersectionIndices(x,y,z,w,h,d, 0,0,0,dx,dy,dz, -math.huge, math.huge)

    -- item tunnels into other
    if ti1
    and ti1 < 1
    and (abs(ti1 - ti2) >= DELTA) -- special case for cube going through another cube's corner
    and (0 < ti1 + DELTA
      or 0 == ti1 and ti2 > 0)
    then
      ti, nx, ny, nz = ti1, nx1, ny1, nz1
      overlaps = false
    end
  end

  if not ti then
    return
  end

  local tx, ty, tz

  if overlaps then
    if dx == 0 and dy == 0 and dz == 0 then
      -- intersecting and not moving - use minimum displacement vector
      local px, py, pz = cube_getNearestCorner(x,y,z,w,h,d, 0,0,0)
      if abs(px) <= abs(py) and abs(px) <= abs(pz) then
        -- X axis has minimum displacement
        py, pz = 0, 0
      elseif abs(py) <= abs(pz) then
        -- Y axis has minimum displacement
        px, pz = 0, 0
      else
        -- Z axis has minimum displacement
        px, py = 0, 0
      end
      nx, ny, nz = sign(px), sign(py), sign(pz)
      tx = x1 + px
      ty = y1 + py
      tz = z1 + pz
    else
      -- intersecting and moving - move in the opposite direction
      local ti1, _
      ti1,_,nx,ny,nz = cube_getSegmentIntersectionIndices(x,y,z,w,h,d, 0,0,0,dx,dy,dz, -math.huge, 1)
      if not ti1 then
        return
      end
      tx = x1 + dx * ti1
      ty = y1 + dy * ti1
      tz = z1 + dz * ti1
    end
  else -- tunnel
    tx = x1 + dx * ti
    ty = y1 + dy * ti
    tz = z1 + dz * ti
  end

  return {
    overlaps  = overlaps,
    ti        = ti,
    move      = {x = dx, y = dy, z = dz},
    normal    = {x = nx, y = ny, z = nz},
    touch     = {x = tx, y = ty, z = tz},
    distance = cube_getCubeDistance(x1,y1,z1,w1,h1,d1, x2,y2,z2,w2,h2,d2),
  }
end

------------------------------------------
-- Grid functions
------------------------------------------

local function grid_toWorld(cellSize, cx, cy, cz)
  return (cx - 1) * cellSize,
         (cy - 1) * cellSize,
         (cz - 1) * cellSize
end

local function grid_toCell(cellSize, x, y, z)
  return floor(x / cellSize) + 1,
         floor(y / cellSize) + 1,
         floor(z / cellSize) + 1
end

-- grid_traverse* functions are based on "A Fast Voxel Traversal Algorithm for Ray Tracing",
-- by John Amanides and Andrew Woo - http://www.cse.yorku.ca/~amana/research/grid.pdf
-- It has been modified to include both cells when the ray "touches a grid corner",
-- and with a different exit condition

local function grid_traverse_initStep(cellSize, ct, t1, t2)
  local v = t2 - t1
  if     v > 0 then
    return  1,  cellSize / v, ((ct + v) * cellSize - t1) / v
  elseif v < 0 then
    return -1, -cellSize / v, ((ct + v - 1) * cellSize - t1) / v
  else
    return 0, math.huge, math.huge
  end
end

local function grid_traverse(cellSize, x1,y1,z1,x2,y2,z2, f)
  local cx1, cy1, cz1 = grid_toCell(cellSize, x1, y1, z1)
  local cx2, cy2, cz2 = grid_toCell(cellSize, x2, y2, z2)
  local stepX, dx, tx = grid_traverse_initStep(cellSize, cx1, x1, x2)
  local stepY, dy, ty = grid_traverse_initStep(cellSize, cy1, y1, y2)
  local stepZ, dz, tz = grid_traverse_initStep(cellSize, cz1, z1, z2)
  local cx, cy, cz = cx1, cy1, cz1

  f(cx, cy, cz)

  -- The default implementation had an infinite loop problem when
  -- approaching the last cell in some occassions. We finish iterating
  -- when we are *next* to the last cell
  while abs(cx - cx2) + abs(cy - cy2) + abs(cz - cz2) > 1 do
    if tx < ty and tx < tz then -- tx is smallest
      tx = tx + dx
      cx = cx + stepX
      f(cx, cy, cz)
    elseif ty < tz then -- ty is smallest
      -- Addition: include both cells when going through corners
      if tx == ty then
        f(cx + stepX, cy, cz)
      end
      ty = ty + dy
      cy = cy + stepY
      f(cx, cy, cz)
    else -- tz is smallest
      -- Addition: include both cells when going through corners
      if tx == tz then
        f(cx + stepX, cy, cz)
      end
      if ty == tz then
        f(cx, cy + stepY, cz)
      end
      tz = tz + dz
      cz = cz + stepZ
      f(cx, cy, cz)
    end
  end

  -- If we have not arrived to the last cell, use it
  if cx ~= cx2 or cy ~= cy2 or cz ~= cz2 then
    f(cx2, cy2, cz2)
  end
end

local function grid_toCellCube(cellSize, x,y,z,w,h,d)
  local cx,cy,cz = grid_toCell(cellSize, x, y, z)
  local cx2 = ceil((x + w) / cellSize)
  local cy2 = ceil((y + h) / cellSize)
  local cz2 = ceil((z + d) / cellSize)

  return cx,
         cy,
         cz,
         cx2 - cx + 1,
         cy2 - cy + 1,
         cz2 - cz + 1
end

------------------------------------------
-- Responses
------------------------------------------

local touch = function(_, col)
  return col.touch.x, col.touch.y, col.touch.z, {}, 0
end

local cross = function(world, col, x,y,z,w,h,d, goalX, goalY, goalZ, filter, alreadyVisited)
  local cols, len = world:project(col.item, x,y,z,w,h,d, goalX, goalY, goalZ, filter, alreadyVisited)

  return goalX, goalY, goalZ, cols, len
end

local slide = function(world, col, x,y,z,w,h,d, goalX, goalY, goalZ, filter, alreadyVisited)
  goalX = goalX or x
  goalY = goalY or y
  goalZ = goalZ or z

  local tch, move = col.touch, col.move
  if move.x ~= 0 or move.y ~= 0 or move.z ~= 0 then
    if col.normal.x ~= 0 then
      goalX = tch.x
    end
    if col.normal.y ~= 0 then
      goalY = tch.y
    end
    if col.normal.z ~= 0 then
      goalZ = tch.z
    end
  end

  col.slide = {x = goalX, y = goalY, z = goalZ}

  x, y, z = tch.x, tch.y, tch.z
  local cols, len = world:project(col.item, x,y,z,w,h,d, goalX, goalY, goalZ, filter, alreadyVisited)

  return goalX, goalY, goalZ, cols, len
end

local bounce = function(world, col, x,y,z,w,h,d, goalX, goalY, goalZ, filter, alreadyVisited)
  goalX = goalX or x
  goalY = goalY or y
  goalZ = goalZ or z

  local tch, move = col.touch, col.move
  local tx, ty, tz = tch.x, tch.y, tch.z
  local bx, by, bz = tx, ty, tz

  if move.x ~= 0 or move.y ~= 0 or move.z ~= 0 then
    local bnx = goalX - tx
    local bny = goalY - ty
    local bnz = goalZ - tz

    if col.normal.x ~= 0 then
      bnx = -bnx
    end
    if col.normal.y ~= 0 then
      bny = -bny
    end
    if col.normal.z ~= 0 then
      bnz = -bnz
    end

    bx = tx + bnx
    by = ty + bny
    bz = tz + bnz
  end

  col.bounce = {x = bx, y = by, z = bz}
  x, y, z = tch.x, tch.y, tch.z
  goalX, goalY, goalZ = bx, by, bz

  local cols, len = world:project(col.item, x,y,z,w,h,d, goalX, goalY, goalZ, filter, alreadyVisited)

  return goalX, goalY, goalZ, cols, len
end

------------------------------------------
-- World
------------------------------------------

local World = {}
local World_mt = {__index = World}

-- Private functions and methods

local function sortByWeight(a,b)
  return a.weight < b.weight
end

local function sortByTiAndDistance(a,b)
  if a.ti == b.ti then
    return a.distance < b.distance
  end
  return a.ti < b.ti
end

local function addItemToCell(self, item, cx, cy, cz)
  self.cells[cz] = self.cells[cz] or {}
  self.cells[cz][cy] = self.cells[cz][cy] or setmetatable({}, {__mode = 'v'})
  if self.cells[cz][cy][cx] == nil then
    self.cells[cz][cy][cx] = {
      itemCount = 0,
      x = cx,
      y = cy,
      z = cz,
      items = setmetatable({}, {__mode = 'k'})
    }
  end

  local cell = self.cells[cz][cy][cx]
  self.nonEmptyCells[cell] = true
  if not cell.items[item] then
    cell.items[item] = true
    cell.itemCount = cell.itemCount + 1
  end
end

local function removeItemFromCell(self, item, cx, cy, cz)
  if not self.cells[cz]
    or not self.cells[cz][cy]
    or not self.cells[cz][cy][cx]
    or not self.cells[cz][cy][cx].items[item]
  then
    return false
  end

  local cell = self.cells[cz][cy][cx]
  cell.items[item] = nil

  cell.itemCount = cell.itemCount - 1
  if cell.itemCount == 0 then
    self.nonEmptyCells[cell] = nil
  end

  return true
end

local function getDictItemsInCellCube(self, cx,cy,cz, cw,ch,cd)
  local items_dict = Pool.fetch()

  for z = cz, cz + cd - 1 do
    local plane = self.cells[z]
    if plane then
      for y = cy, cy + ch - 1 do
        local row = plane[y]
        if row then
          for x = cx, cx + cw - 1 do
            local cell = row[x]
            if cell and cell.itemCount > 0 then -- no cell.itemCount > 1 because tunneling
              for item,_ in pairs(cell.items) do
                items_dict[item] = true
              end
            end
          end
        end
      end
    end
  end

  return items_dict
end

local function getCellsTouchedBySegment(self, x1,y1,z1,x2,y2,z2)
  local cells, cellsLen, visited = {}, 0, {}

  grid_traverse(self.cellSize, x1,y1,z1,x2,y2,z2, function(cx, cy, cz)
    local plane = self.cells[cz]
    if not plane then
      return
    end

    local row = plane[cy]
    if not row then
      return
    end

    local cell = row[cx]
    if not cell or visited[cell] then
      return
    end

    visited[cell] = true
    cellsLen = cellsLen + 1
    cells[cellsLen] = cell
  end)

  return cells, cellsLen
end

local function getInfoAboutItemsTouchedBySegment(self, x1,y1,z1, x2,y2,z2, filter)
  local cells, len = getCellsTouchedBySegment(self, x1,y1,z1,x2,y2,z2)
  local cell, cube, x,y,z,w,h,d, ti1, ti2, tii0, tii1
  local visited, itemInfo, itemInfoLen = Pool.fetch(), Pool.fetch(), 0

  for i = 1, len do
    cell = cells[i]
    for item in pairs(cell.items) do
      if not visited[item] then
        visited[item] = true
        if (not filter or filter(item)) then
          cube = self.cubes[item]
          x, y, z, w, h, d = cube.x, cube.y, cube.z, cube.w, cube.h, cube.d

          ti1, ti2 = cube_getSegmentIntersectionIndices(x,y,z,w,h,d, x1,y1,z1, x2,y2,z2, 0, 1)
          if ti1 and ((0 < ti1 and ti1 < 1) or (0 < ti2 and ti2 < 1)) then
            -- the sorting is according to the t of an infinite line, not the segment
            tii0, tii1 = cube_getSegmentIntersectionIndices(x,y,z,w,h,d, x1,y1,z1, x2,y2,z2, -math.huge, math.huge)
            itemInfoLen = itemInfoLen + 1
            itemInfo[itemInfoLen] = {item = item, ti1 = ti1, ti2 = ti2, weight = min(tii0, tii1)}
          end
        end
      end
    end
  end

  Pool.free(visited)

  table.sort(itemInfo, sortByWeight)

  return itemInfo, itemInfoLen
end

local function getResponseByName(self, name)
  local response = self.responses[name]
  if not response then
    error(('Unknown collision type: %s (%s)'):format(name, type(name)))
  end

  return response
end


-- Misc Public Methods

function World:addResponse(name, response)
  self.responses[name] = response
end

local EMPTY_TABLE = {}

function World:projectMove(item, x,y,z,w,h,d, goalX,goalY,goalZ, filter)
  filter = filter or defaultFilter

  local projected_cols, projected_len = self:project(item, x,y,z,w,h,d, goalX,goalY,goalZ, filter)

  if projected_len == 0 then
    return goalX, goalY, goalZ, EMPTY_TABLE, 0
  end

  local cols, len = {}, 0

  local visited = Pool.fetch()
  visited[item] = true

  while projected_len > 0 do
    local col = projected_cols[1]
    len       = len + 1
    cols[len] = col

    visited[col.other] = true

    local response = getResponseByName(self, col.type)

    goalX, goalY, goalZ, projected_cols, projected_len = response(
      self,
      col,
      x, y, z, w, h, d,
      goalX, goalY, goalZ,
      filter,
      visited
    )
  end

  return goalX, goalY, goalZ, cols, len
end

function World:project(item, x,y,z,w,h,d, goalX,goalY,goalZ, filter, alreadyVisited)
  assertIsCube(x, y, z, w, h, d)

  goalX = goalX or x
  goalY = goalY or y
  goalZ = goalZ or z
  filter = filter or defaultFilter

  local collisions, len = nil, 0

  local visited = Pool.fetch()
  if item ~= nil then
    visited[item] = true
  end

  -- This could probably be done with less cells using a polygon raster over the cells instead of a
  -- bounding cube of the whole movement. Conditional to building a queryPolygon method
  local tx = min(goalX, x)
  local ty = min(goalY, y)
  local tz = min(goalZ, z)
  local tx2 = max(goalX + w, x + w)
  local ty2 = max(goalY + h, y + h)
  local tz2 = max(goalZ + d, z + d)
  local tw = tx2 - tx
  local th = ty2 - ty
  local td = tz2 - tz

  local cx,cy,cz,cw,ch,cd = grid_toCellCube(self.cellSize, tx,ty,tz, tw,th,td)

  local dictItemsInCellCube = getDictItemsInCellCube(self, cx,cy,cz,cw,ch,cd)

  for other, _ in pairs(dictItemsInCellCube) do
    if not visited[other] and (alreadyVisited == nil or not alreadyVisited[other]) then
      visited[other] = true

      local responseName = filter(item, other)
      if responseName then
        local ox,oy,oz,ow,oh,od = self:getCube(other)
        local col = cube_detectCollision(x,y,z,w,h,d, ox,oy,oz,ow,oh,od, goalX, goalY, goalZ)

        if col then
          col.other = other
          col.item  = item
          col.type  = responseName

          len = len + 1
          if collisions == nil then
            collisions = {}
          end
          collisions[len] = col
        end
      end
    end
  end

  Pool.free(visited)
  Pool.free(dictItemsInCellCube)

  if collisions ~= nil then
    table.sort(collisions, sortByTiAndDistance)
  end

  return collisions or EMPTY_TABLE, len
end

function World:countCells()
  local count = 0

  for _, plane in pairs(self.cells) do
    for _, row in pairs(plane) do
      for _,_ in pairs(row) do
        count = count + 1
      end
    end
  end

  return count
end

function World:hasItem(item)
  return not not self.cubes[item]
end

function World:getItems()
  local items, len = {}, 0
  for item,_ in pairs(self.cubes) do
    len = len + 1
    items[len] = item
  end
  return items, len
end

function World:countItems()
  local len = 0
  for _ in pairs(self.cubes) do len = len + 1 end
  return len
end

function World:getCube(item)
  local cube = self.cubes[item]
  if not cube then
    error('Item ' .. tostring(item) .. ' must be added to the world before getting its cube. Use world:add(item, x,y,z,w,h,d) to add it first.')
  end

  return cube.x, cube.y, cube.z, cube.w, cube.h, cube.d
end

function World:toWorld(cx, cy, cz)
  return grid_toWorld(self.cellSize, cx, cy, cz)
end

function World:toCell(x,y,z)
  return grid_toCell(self.cellSize, x, y, z)
end


-- Query methods

function World:queryCube(x,y,z,w,h,d, filter)
  assertIsCube(x,y,z,w,h,d)

  local cx,cy,cz,cw,ch,cd = grid_toCellCube(self.cellSize, x,y,z,w,h,d)
  local dictItemsInCellCube = getDictItemsInCellCube(self, cx,cy,cz,cw,ch,cd)

  local items, len = nil, 0

  local cube
  for item, _ in pairs(dictItemsInCellCube) do
    cube = self.cubes[item]
    if (not filter or filter(item))
    and cube_isIntersecting(x,y,z,w,h,d, cube.x, cube.y, cube.z, cube.w, cube.h, cube.d)
    then
      len = len + 1
      if items == nil then
        items = {}
      end
      items[len] = item
    end
  end

  Pool.free(dictItemsInCellCube)

  return items, len
end

function World:queryPoint(x,y,z, filter)
  local cx,cy,cz = self:toCell(x,y,z)
  local dictItemsInCellCube = getDictItemsInCellCube(self, cx,cy,cz, 1,1,1)

  local items, len = {}, 0

  local cube
  for item,_ in pairs(dictItemsInCellCube) do
    cube = self.cubes[item]
    if (not filter or filter(item))
    and cube_containsPoint(cube.x, cube.y, cube.z, cube.w, cube.h, cube.d, x, y, z)
    then
      len = len + 1
      items[len] = item
    end
  end

  Pool.free(dictItemsInCellCube)

  return items, len
end

function World:querySegment(x1, y1, z1, x2, y2, z2, filter)
  local itemInfo, len = getInfoAboutItemsTouchedBySegment(self, x1, y1, z1, x2, y2, z2, filter)

  local items = {}
  for i = 1, len do
    items[i] = itemInfo[i].item
  end

  Pool.free(itemInfo)

  return items, len
end

function World:querySegmentWithCoords(x1, y1, z1, x2, y2, z2, filter)
  local itemInfo, len = getInfoAboutItemsTouchedBySegment(self, x1, y1, z1, x2, y2, z2, filter)
  local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
  local info, ti1, ti2
  for i = 1, len do
    info = itemInfo[i]
    ti1 = info.ti1
    ti2 = info.ti2

    info.weight = nil
    info.x1 = x1 + dx * ti1
    info.y1 = y1 + dy * ti1
    info.z1 = z1 + dz * ti1
    info.x2 = x1 + dx * ti2
    info.y2 = y1 + dy * ti2
    info.z2 = z1 + dz * ti2
  end
  return itemInfo, len
end


--- Main methods

function World:add(item, x,y,z,w,h,d)
  local cube = self.cubes[item]
  if cube then
    error('Item ' .. tostring(item) .. ' added to the world twice.')
  end
  assertIsCube(x,y,z,w,h,d)

  self.cubes[item] = {x=x,y=y,z=z,w=w,h=h,d=d}

  local cl,ct,cs,cw,ch,cd = grid_toCellCube(self.cellSize, x,y,z,w,h,d)
  for cz = cs, cs + cd - 1 do
    for cy = ct, ct + ch - 1 do
      for cx = cl, cl + cw - 1 do
        addItemToCell(self, item, cx, cy, cz)
      end
    end
  end

  return item
end

function World:remove(item)
  local x,y,z,w,h,d = self:getCube(item)

  self.cubes[item] = nil
  local cl,ct,cs,cw,ch,cd = grid_toCellCube(self.cellSize, x,y,z,w,h,d)
  for cz = cs, cs + cd - 1 do
    for cy = ct, ct + ch - 1 do
      for cx = cl, cl + cw - 1 do
        removeItemFromCell(self, item, cx, cy, cz)
      end
    end
  end
end

function World:update(item, x2,y2,z2,w2,h2,d2)
  local x1,y1,z1, w1,h1,d1 = self:getCube(item)
  w2 = w2 or w1
  h2 = h2 or h1
  d2 = d2 or d1
  assertIsCube(x2,y2,z2,w2,h2,d2)

  if x1 == x2 and y1 == y2 and z1 == z2 and w1 == w2 and h1 == h2 and d1 == d2 then
    return
  end

  local cl1,ct1,cs1,cw1,ch1,cd1 = grid_toCellCube(self.cellSize, x1,y1,z1, w1,h1,d1)
  local cl2,ct2,cs2,cw2,ch2,cd2 = grid_toCellCube(self.cellSize, x2,y2,z2, w2,h2,d2)

  if cl1 ~= cl2 or ct1 ~= ct2 or cs1 ~= cs2 or cw1 ~= cw2 or ch1 ~= ch2 or cd1 ~= cd2 then
    local cr1 = cl1 + cw1 - 1
    local cr2 = cl2 + cw2 - 1
    local cb1 = ct1 + ch1 - 1
    local cb2 = ct2 + ch2 - 1
    local css1 = cs1 + cd1 - 1
    local css2 = cs2 + cd2 - 1
    local cyOut, czOut

    for cz = cs1, css1 do
      czOut = cz < cs2 or cz > css2
      for cy = ct1, cb1 do
        cyOut = cy < ct2 or cy > cb2
        for cx = cl1, cr1 do
          if czOut or cyOut or cx < cl2 or cx > cr2 then
            removeItemFromCell(self, item, cx, cy, cz)
          end
        end
      end
    end

    for cz = cs2, css2 do
      czOut = cz < cs1 or cz > css1
      for cy = ct2, cb2 do
        cyOut = cy < ct1 or cy > cb1
        for cx = cl2, cr2 do
          if czOut or cyOut or cx < cl1 or cx > cr1 then
            addItemToCell(self, item, cx, cy, cz)
          end
        end
      end
    end
  end

  local cube = self.cubes[item]
  cube.x, cube.y, cube.z, cube.w, cube.h, cube.d = x2, y2, z2, w2, h2, d2
end

function World:move(item, goalX, goalY, goalZ, filter)
  local actualX, actualY, actualZ, cols, len = self:check(item, goalX, goalY, goalZ, filter)

  self:update(item, actualX, actualY, actualZ)

  return actualX, actualY, actualZ, cols, len
end

function World:check(item, goalX, goalY, goalZ, filter)
  local x,y,z,w,h,d = self:getCube(item)

  return self:projectMove(item, x,y,z,w,h,d, goalX,goalY,goalZ, filter)
end


-- Public library functions

local bump = {}

bump.newWorld = function(cellSize)
  cellSize = cellSize or 64
  assertIsPositiveNumber(cellSize, 'cellSize')
  local world = setmetatable({
    cellSize = cellSize,
    cubes = {},
    cells = {},
    nonEmptyCells = {},
    responses = {},
  }, World_mt)

  world:addResponse('touch', touch)
  world:addResponse('cross', cross)
  world:addResponse('slide', slide)
  world:addResponse('bounce', bounce)

  return world
end

bump.cube = {
  getNearestCorner              = cube_getNearestCorner,
  getSegmentIntersectionIndices = cube_getSegmentIntersectionIndices,
  getDiff                       = cube_getDiff,
  containsPoint                 = cube_containsPoint,
  isIntersecting                = cube_isIntersecting,
  getCubeDistance               = cube_getCubeDistance,
  detectCollision               = cube_detectCollision
}

bump.responses = {
  touch  = touch,
  cross  = cross,
  slide  = slide,
  bounce = bounce
}

return bump
