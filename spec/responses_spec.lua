local bump = require('bump-3dpd')
local detect = bump.cube.detectCollision
local responses = bump.responses

local world = bump.newWorld()

local touch = function(x,y,z,w,h,d, ox,oy,oz,ow,oh,od, goalX, goalY, goalZ)
  local col = detect(x,y,z,w,h,d, ox,oy,oz,ow,oh,od, goalX, goalY, goalZ)

  return {
    col.touch.x,
    col.touch.y,
    col.touch.z,
    col.normal.x,
    col.normal.y,
    col.normal.z,
  }
end

local slide = function(x,y,z,w,h,d, ox,oy,oz,ow,oh,od, goalX, goalY, goalZ)
  local col = detect(x,y,z,w,h,d, ox,oy,oz,ow,oh,od, goalX, goalY, goalZ)
  responses.slide(world, col, x,y,z,w,h,d, goalX, goalY, goalZ)

  return {
    col.touch.x,
    col.touch.y,
    col.touch.z,
    col.normal.x,
    col.normal.y,
    col.normal.z,
    col.slide.x,
    col.slide.y,
    col.slide.z,
  }
end

local bounce = function(x,y,z,w,h,d, ox,oy,oz,ow,oh,od, goalX, goalY, goalZ)
  local col = detect(x,y,z,w,h,d, ox,oy,oz,ow,oh,od, goalX, goalY, goalZ)
  responses.bounce(world, col, x,y,z,w,h,d, goalX, goalY, goalZ)

  return {
    col.touch.x,
    col.touch.y,
    col.touch.z,
    col.normal.x,
    col.normal.y,
    col.normal.z,
    col.bounce.x,
    col.bounce.y,
    col.bounce.z,
  }
end

describe('bump.responses', function()
  describe('touch', function()
    describe('when resolving collisions', function()
      describe('on overlaps', function()
        describe('when there is no movement', function()
          it('returns the left,top coordinates of the minimum displacement on static items', function()
            --                                          -2-1 0 1 2 3 4 5 6 7 8 9 10
            --      -2 -1 0 1 2 3 4 5 6 7 8 9           -2 · ┌–––┐ · ┌–––┐ · ┌–––┐ ·
            --      -1  ┌–––┐ · ┌–––┐ · ┌–––┐           -1 · │0-1│ · │0-1│ · │0-1│ ·
            --       0  │ ┌–––––––––––––––┐ │ 1  2  3    0 · └–┌–––––––––––––––┐–┘ ·
            --       1  └–│–┘ · └–––┘ · └–│–┘            1 · · │ · · · · · · · │ · ·
            --       2  · │ · · · · · · · │ ·            2 · · │ · · · · · · · │ · ·
            --       3  ┌–│–┐ · ┌–––┐ · ┌–│–┐            3 ┌–––│ · · · · · · · │–––┐
            --       4  │ │ │ · │ · │ · │ │ │ 4  5  6    4 -1 0│ · · · · · · · │1 0│
            --       5  └–│–┘ · └–––┘ · └–│–┘            5 └–––│ · · · · · · · │–––┘
            --       6  · │ · · · · · · · │ ·            6 · · │ · · · · · · · │ · ·
            --       7  ┌–│–┐ · ┌–––┐ · ┌–│–┐            7 · · │ · · · · · · · │ · ·
            --       8  │ └–––––––––––––––┘ │ 7  8  9    8 · ┌–└–––––––––––––––┘–┐ ·
            --       9  └–––┘ · └–––┘ · └–––┘            9 · │0 1│ · ╎0 1╎ · │0 1│ ·
            --      10                                  10 · └–––┘ · └╌╌╌┘ · └–––┘ ·

            -- -- Z AXIS AT -1. (top)
            assert.same({-2,-1,-1, -1, 0, 0}, touch(-1,-1,-1,2,2,2, 0,0,0,8,8,8)) -- 1
            assert.same({ 3,-2,-1,  0,-1, 0}, touch( 3,-1,-1,2,2,2, 0,0,0,8,8,8)) -- 2
            assert.same({ 8,-1,-1,  1, 0, 0}, touch( 7,-1,-1,2,2,2, 0,0,0,8,8,8)) -- 3

            assert.same({-2, 3,-1, -1, 0, 0}, touch(-1, 3,-1,2,2,2, 0,0,0,8,8,8)) -- 4
            assert.same({ 3, 3,-2,  0, 0,-1}, touch( 3, 3,-1,2,2,2, 0,0,0,8,8,8)) -- 5
            assert.same({ 8, 3,-1,  1, 0, 0}, touch( 7, 3,-1,2,2,2, 0,0,0,8,8,8)) -- 6

            assert.same({-2, 7,-1, -1, 0, 0}, touch(-1, 7,-1,2,2,2, 0,0,0,8,8,8)) -- 7
            assert.same({ 3, 8,-1,  0, 1, 0}, touch( 3, 7,-1,2,2,2, 0,0,0,8,8,8)) -- 8
            assert.same({ 8, 7,-1,  1, 0, 0}, touch( 7, 7,-1,2,2,2, 0,0,0,8,8,8)) -- 9

            -- Z AXIS AT 3 (middle)
            assert.same({-2,-1, 3, -1, 0, 0}, touch(-1,-1, 3,2,2,2, 0,0,0,8,8,8)) -- 1
            assert.same({ 3,-2, 3,  0,-1, 0}, touch( 3,-1, 3,2,2,2, 0,0,0,8,8,8)) -- 2
            assert.same({ 8,-1, 3,  1, 0, 0}, touch( 7,-1, 3,2,2,2, 0,0,0,8,8,8)) -- 3

            assert.same({-2, 3, 3, -1, 0, 0}, touch(-1, 3, 3,2,2,2, 0,0,0,8,8,8)) -- 4
            assert.same({ 8, 3, 3,  1, 0, 0}, touch( 3, 3, 3,2,2,2, 0,0,0,8,8,8)) -- 5
            assert.same({ 8, 3, 3,  1, 0, 0}, touch( 7, 3, 3,2,2,2, 0,0,0,8,8,8)) -- 6

            assert.same({-2, 7, 3, -1, 0, 0}, touch(-1, 7, 3,2,2,2, 0,0,0,8,8,8)) -- 7
            assert.same({ 3, 8, 3,  0, 1, 0}, touch( 3, 7, 3,2,2,2, 0,0,0,8,8,8)) -- 8
            assert.same({ 8, 7, 3,  1, 0, 0}, touch( 7, 7, 3,2,2,2, 0,0,0,8,8,8)) -- 9

            -- -- Z AXIS AT 7. (bottom)
            assert.same({-2,-1, 7, -1, 0, 0}, touch(-1,-1, 7,2,2,2, 0,0,0,8,8,8)) -- 1
            assert.same({ 3,-2, 7,  0,-1, 0}, touch( 3,-1, 7,2,2,2, 0,0,0,8,8,8)) -- 2
            assert.same({ 8,-1, 7,  1, 0, 0}, touch( 7,-1, 7,2,2,2, 0,0,0,8,8,8)) -- 3

            assert.same({-2, 3, 7, -1, 0, 0}, touch(-1, 3, 7,2,2,2, 0,0,0,8,8,8)) -- 4
            assert.same({ 3, 3, 8,  0, 0, 1}, touch( 3, 3, 7,2,2,2, 0,0,0,8,8,8)) -- 5
            assert.same({ 8, 3, 7,  1, 0, 0}, touch( 7, 3, 7,2,2,2, 0,0,0,8,8,8)) -- 6

            assert.same({-2, 7, 7, -1, 0, 0}, touch(-1, 7, 7,2,2,2, 0,0,0,8,8,8)) -- 7
            assert.same({ 3, 8, 7,  0, 1, 0}, touch( 3, 7, 7,2,2,2, 0,0,0,8,8,8)) -- 8
            assert.same({ 8, 7, 7,  1, 0, 0}, touch( 7, 7, 7,2,2,2, 0,0,0,8,8,8)) -- 9
          end)
        end)

        describe('when the item is moving', function()
          it('returns the left,top coordinates of the overlaps with the movement line, opposite direction', function()
            -- one axis
            assert.same({-2, 3, 3, -1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 4,3,3))
            assert.same({ 8, 3, 3,  1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 2,3,3))
            assert.same({ 3,-2, 3,  0,-1, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 3,4,3))
            assert.same({ 3, 8, 3,  0, 1, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 3,2,3))
            assert.same({ 3, 3,-2,  0, 0,-1}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 3,3,4))
            assert.same({ 3, 3, 8,  0, 0, 1}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 3,3,2))

            -- two axises
            assert.same({-2,-2, 3, -1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 4,4,3))
            assert.same({ 8, 8, 3,  1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 2,2,3))
            assert.same({ 3,-2,-2,  0,-1, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 3,4,4))
            assert.same({ 3, 8, 8,  0, 1, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 3,2,2))
            assert.same({-2, 3,-2, -1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 4,3,4))
            assert.same({ 8, 3, 8,  1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 2,3,2))

            -- three axises
            assert.same({-2,-2,-2, -1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 4,4,4))
            assert.same({ 8, 8, 8,  1, 0, 0}, touch(3,3,3,2,2,2, 0,0,0,8,8,8, 2,2,2))
          end)
        end)
      end)

      describe('on tunnels', function()
        it('returns the coordinates of the item when it starts touching the other, and the normal', function()
          assert.same({-2, 3, 3, -1, 0, 0}, touch(-3, 3, 3,2,2,2, 0,0,0,8,8,8, 3,3,3))
          assert.same({ 8, 3, 3,  1, 0, 0}, touch( 9, 3, 3,2,2,2, 0,0,0,8,8,8, 3,3,3))
          assert.same({ 3,-2, 3,  0,-1, 0}, touch( 3,-3, 3,2,2,2, 0,0,0,8,8,8, 3,3,3))
          assert.same({ 3, 8, 3,  0, 1, 0}, touch( 3, 9, 3,2,2,2, 0,0,0,8,8,8, 3,3,3))
          assert.same({ 3, 3,-2,  0, 0,-1}, touch( 3, 3,-3,2,2,2, 0,0,0,8,8,8, 3,3,3))
          assert.same({ 3, 3, 8,  0, 0, 1}, touch( 3, 3, 9,2,2,2, 0,0,0,8,8,8, 3,3,3))
        end)
      end)
    end)
  end)

  describe('slide', function()
    it('slides on overlaps', function()
      assert.same({ -2,0.5,0.5, -1, 0, 0, -2, 4, 4}, slide(3,3,3,2,2,2, 0,0,0,8,8,8, 5,4,4))
      assert.same({0.5, -2,0.5,  0,-1, 0,  4,-2, 4}, slide(3,3,3,2,2,2, 0,0,0,8,8,8, 4,5,4))
      assert.same({0.5,0.5, -2,  0, 0,-1,  4, 4,-2}, slide(3,3,3,2,2,2, 0,0,0,8,8,8, 4,4,5))
      assert.same({  8,5.5,5.5,  1, 0, 0,  8, 2, 2}, slide(3,3,3,2,2,2, 0,0,0,8,8,8, 1,2,2))
      assert.same({5.5,  8,5.5,  0, 1, 0,  2, 8, 2}, slide(3,3,3,2,2,2, 0,0,0,8,8,8, 2,1,2))
      assert.same({5.5,5.5,  8,  0, 0, 1,  2, 2, 8}, slide(3,3,3,2,2,2, 0,0,0,8,8,8, 2,2,1))
    end)

    it('slides over tunnels', function()
      assert.same({ 8, 7, 7,  1, 0, 0,  8, 1, 1}, slide(10,10,10,2,2,2, 0,0,0,8,8,8, 4,1,1))
      assert.same({ 7, 8, 7,  0, 1, 0,  1, 8, 1}, slide(10,10,10,2,2,2, 0,0,0,8,8,8, 1,4,1))
      assert.same({ 7, 7, 8,  0, 0, 1,  1, 1, 8}, slide(10,10,10,2,2,2, 0,0,0,8,8,8, 1,1,4))
      assert.same({-2,-1,-1, -1, 0, 0, -2, 5, 5}, slide(-4,-4,-4,2,2,2, 0,0,0,8,8,8, 2,5,5))
      assert.same({-1,-2,-1,  0,-1, 0,  5,-2, 5}, slide(-4,-4,-4,2,2,2, 0,0,0,8,8,8, 5,2,5))
      assert.same({-1,-1,-2,  0, 0,-1,  5, 5,-2}, slide(-4,-4,-4,2,2,2, 0,0,0,8,8,8, 5,5,2))

      -- perfect corner case:
      assert.same({8,8,8, 1,0,0, 8,1,1}, slide(10,10,10,2,2,2, 0,0,0,8,8,8, 1,1,1))
    end)
  end)

  describe('bounce', function()
    it('bounces on overlaps', function()
      assert.same({ -2,0.5,0.5, -1, 0, 0, -9, 4, 4}, bounce(3,3,3,2,2,2, 0,0,0,8,8,8, 5,4,4))
      assert.same({0.5, -2,0.5,  0,-1, 0,  4,-9, 4}, bounce(3,3,3,2,2,2, 0,0,0,8,8,8, 4,5,4))
      assert.same({0.5,0.5, -2,  0, 0,-1,  4, 4,-9}, bounce(3,3,3,2,2,2, 0,0,0,8,8,8, 4,4,5))
      assert.same({  8,5.5,5.5,  1, 0, 0, 15, 2, 2}, bounce(3,3,3,2,2,2, 0,0,0,8,8,8, 1,2,2))
      assert.same({5.5,  8,5.5,  0, 1, 0,  2,15, 2}, bounce(3,3,3,2,2,2, 0,0,0,8,8,8, 2,1,2))
      assert.same({5.5,5.5,  8,  0, 0, 1,  2, 2,15}, bounce(3,3,3,2,2,2, 0,0,0,8,8,8, 2,2,1))
    end)

    it('bounces over tunnels', function()
      assert.same({ 8, 7, 7,  1, 0, 0, 12, 1, 1}, bounce(10,10,10,2,2,2, 0,0,0,8,8,8, 4,1,1))
      assert.same({ 7, 8, 7,  0, 1, 0,  1,12, 1}, bounce(10,10,10,2,2,2, 0,0,0,8,8,8, 1,4,1))
      assert.same({ 7, 7, 8,  0, 0, 1,  1, 1,12}, bounce(10,10,10,2,2,2, 0,0,0,8,8,8, 1,1,4))
      assert.same({-2,-1,-1, -1, 0, 0, -6, 5, 5}, bounce(-4,-4,-4,2,2,2, 0,0,0,8,8,8, 2,5,5))
      assert.same({-1,-2,-1,  0,-1, 0,  5,-6, 5}, bounce(-4,-4,-4,2,2,2, 0,0,0,8,8,8, 5,2,5))
      assert.same({-1,-1,-2,  0, 0,-1,  5, 5,-6}, bounce(-4,-4,-4,2,2,2, 0,0,0,8,8,8, 5,5,2))

      -- perfect corner case:
      assert.same({8,8,8, 1,0,0, 15,1,1}, bounce(10,10,10,2,2,2, 0,0,0,8,8,8, 1,1,1))
    end)
  end)
end)
