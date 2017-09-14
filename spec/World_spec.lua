local bump = require 'bump-3dpd'

describe('World', function()
  local world

  before_each(function()
    world = bump.newWorld()
  end)

  local collect = function(t, field_name)
    local res = {}
    for i,v in ipairs(t) do res[i] = v[field_name] end
    return res
  end

  local sorted = function(array)
    table.sort(array)
    return array
  end

  describe(':add', function()
    it('requires something + 6 numbers', function()
      assert.error(function() world:add({}) end)
      assert.error(function() world:add({}, 40) end)
      assert.error(function() world:add() end)
    end)

    it('returns the added item', function()
      local item = {}
      assert.equals(item, world:add(item, 1,1,1,1,1,1))
    end)

    it('throws an error if the object was already added', function()
      local obj = world:add({}, 0,0,0,10,10,10)
      assert.error(function() world:add(obj, 0,0,0,10,10,10) end)
    end)

    describe('when the world is empty', function()
      it('creates as many cells as needed to hold the item', function()
        world:add({}, 0,0,0,10,10,10) -- adds one cell
        assert.equal(1, world:countCells())

        world:add({}, 100,100,100,10,10,10) -- adds a separate single cell
        assert.equal(2, world:countCells())

        world:add({}, 0,0,0,100,10,10) -- occupies 2 cells, but just adds one (the other is already added)
        assert.equal(3, world:countCells())

        world:add({}, 300,300,300,64,64,64) -- adds 8 new cells
        assert.equal(11, world:countCells())
      end)
    end)
  end)

  describe(':update', function()
    describe('when the object is not there', function()
      it('throws an error', function()
        assert.is_error(function() world:update({}, 0,0) end)
      end)
    end)

    it('updates the object', function()
      local a = world:add({}, 0,0,0,10,10,10)
      world:update(a, 40,40,40, 20,20,20)
      assert.same({40,40,40,20,20,20}, {world:getCube(a)})
    end)

    describe('when no width or height or depth is given', function()
      it('takes width and height and depth from its previous value', function()
        local a = world:add({}, 0,0,0, 10,10,10)
        world:update(a, 5,5,5)
        assert.same({5,5,5, 10,10,10}, {world:getCube(a)})
      end)
    end)

    describe('when the object stays in the same group of cells', function()
      it('does not invoke remove and add', function()
        local a = world:add({}, 0,0,0, 10,10,10)

        spy.on(world, 'remove')
        spy.on(world, 'add')

        world:update(a, 1,1,1, 11,11,11)

        assert.spy(world.remove).was.called(0)
        assert.spy(world.add).was.called(0)
      end)
    end)
  end)

  describe(':project', function()
    it('throws an error if when not given a rect', function()
      assert.error(function() world:project() end)
    end)

    describe('when the world is empty', function()
      it('returns an empty list of collisions', function()
        assert.same(world:project({}, 1,2,3,4,5,6), {})
      end)
    end)

    describe('when the world is not empty', function()
      it('returns a list of collisions', function()
        world:add({'a'}, 0,0,0, 10,10,10)
        world:add({'c'}, 15,15,15, 10,10,10)
        assert.same(1, #world:project({}, 5,5,5, 1,1,1))
      end)

      describe('when next future X, Y, & Z are passed', function()
        it('still handles intersections as before', function()
          world:add({'a'}, 0,0,0, 2,2,2)
          assert.same(1, #world:project({}, 1,1,1,2,2,2, 1,1,1))
        end)

        it('detects and tags tunneling correctly', function()
          world:add({'a'},  1,0,0, 2,1,1)
          assert.same(1, #world:project({}, -5,0,0, 4,1,1, 5,0,0))
        end)

        it('detects the case where an object was touching another without intersecting, and then penetrates', function()
          world:add({'b'}, 0,0,0, 32,100,100)
          assert.same(1, #world:project({}, 32,50,50, 20,20,20, 30,50,50))
        end)

        it('returns a list of collisions sorted by ti', function()
          world:add({'b'}, 70,0,0, 10,10,10)
          world:add({'c'}, 50,0,0, 10,10,10)
          world:add({'d'}, 90,0,0, 10,10,10)

          local col = world:project({}, 110,0,0, 10,10,10, 10,0,0)

          assert.same(collect(col, 'ti'), {0.1, 0.3, 0.5})
        end)
      end) -- when FutureX & Y are passed

      describe('the filter param', function()
        it('deactivates collisions when filter returns false', function()
          world:add({'b'}, 70,0,0, 10,10,10)
          world:add({'c'}, 50,0,0, 10,10,10)
          local d = world:add({'d'}, 90,0,0, 10,10,10)

          local filter = function(item, obj)
            return obj ~= d and "touch"
          end
          local cols = world:project({}, 110,0,0, 10,10,10, 10,0,0, filter)

          assert.same(2, #cols)
        end)
      end)
    end)
  end)

  describe(':remove', function()
    it('throws an error if the item does not exist', function()
      assert.error(function() world:remove({}) end)
    end)

    it('makes the item disappear from the world', function()
      local a = world:add({'a'}, 2,2,2, 6,6,6)
      assert.same(1, #world:project({}, 0,0,0,10,10,10))
      world:remove(a)
      assert.same(0, #world:project({}, 0,0,0,10,10,10))
    end)

    it('marks empty cells & rows for deallocation', function()
      local _ = world:add({'a'}, 0,0,0, 10,10,10)
      local b = world:add({'b'}, 200,200,200, 10,10,10)

      assert.same(2, world:countCells())
      assert.same('table', type(world.cells[4]))
      assert.same('table', type(world.cells[4][4]))
      assert.same('table', type(world.cells[4][4][4]))

      world:remove(b)

      assert.same(2, world:countCells())
      assert.same('table', type(world.cells[4]))
      assert.same('table', type(world.cells[4][4]))
      assert.same('table', type(world.cells[4][4][4]))

      collectgarbage('collect')

      assert.same(1, world:countCells())
      assert.same('table', type(world.cells[4])) --    TODO: Cell planes should be garbage collected.
      assert.same('table', type(world.cells[4][4])) -- TODO: Cell rows should be garbage collected.
      assert.same(nil, world.cells[4][4][4])
    end)
  end)

  describe(':toCell', function()
    it('returns the coordinates of the cell containing a point', function()
      assert.same({1,1,1}, {world:toCell(0,0,0)})
      assert.same({1,1,1}, {world:toCell(63.9,63.9,63,9)})
      assert.same({2,2,2}, {world:toCell(64,64,64)})
      assert.same({0,0,0}, {world:toCell(-1,-1,-1)})
    end)
  end)

  describe(':toWorld', function()
    it('returns the world left,top corner of the given cell', function()
      assert.same({0,0,0}, {world:toWorld(1,1,1)})
      assert.same({64,64,64}, {world:toWorld(2,2,2)})
      assert.same({-128,-64,0}, {world:toWorld(-1,0,1)})
    end)
  end)

  describe(':queryCube', function()
    it('throws an error when given an invalid rect', function()
      assert.error(function() world:queryCube(0,0,0,-1,-1,-1) end)
    end)

    it('returns nothing when the world is empty', function()
      assert.same(world:queryCube(0,0,0,1,1,1), {})
    end)

    describe('when the world has items', function()
      local a, b, c, d

      before_each(function()
        a = world:add('a', 10,0,0, 10,10,10)
        b = world:add('b', 70,0,0, 10,10,10)
        c = world:add('c', 50,0,0, 10,10,10)
        d = world:add('d', 90,0,0, 10,10,10)
      end)

      it('returns the items inside/partially inside the given rect', function()
        assert.same({b,c},     sorted(world:queryCube(55,5,5, 20,20,20)))
        assert.same({a,b,c,d}, sorted(world:queryCube(0,5,5, 100,20,20)))
      end)

      it('only returns the items for which filter returns true', function()
        local filter = function(other)
          return other == a or other == b or other == d
        end
        assert.same({b},     sorted(world:queryCube(55,5,5, 20,20,20, filter)))
        assert.same({a,b,d}, sorted(world:queryCube(0,5,5, 100,20,20, filter)))
      end)
    end)
  end)

  describe(':queryPoint', function()
    it('returns nothing when the world is empty', function()
      assert.same(world:queryPoint(0,0,0), {})
    end)
    describe('when the world has items', function()
      local a, b, c

      before_each(function()
        a = world:add('a', 10,0,0, 10,10,10)
        b = world:add('b', 15,0,0, 10,10,10)
        c = world:add('c', 20,0,0, 10,10,10)
      end)

      it('returns the items inside/partially inside the given rect', function()
        assert.same({},    sorted(world:queryPoint( 4,5,5)))
        assert.same({a},   sorted(world:queryPoint(14,5,5)))
        assert.same({a,b}, sorted(world:queryPoint(16,5,5)))
        assert.same({b,c}, sorted(world:queryPoint(21,5,5)))
        assert.same({c},   sorted(world:queryPoint(26,5,5)))
        assert.same({},    sorted(world:queryPoint(31,5,5)))
      end)

      it('the items are ignored when filter is present and returns false for them', function()
        local filter = function(other) return other ~= b end
        assert.same({},  world:queryPoint( 4,5,5, filter))
        assert.same({a}, world:queryPoint(14,5,5, filter))
        assert.same({a}, world:queryPoint(16,5,5, filter))
        assert.same({c}, world:queryPoint(21,5,5, filter))
        assert.same({c}, world:queryPoint(26,5,5, filter))
        assert.same({},  world:queryPoint(31,5,5, filter))
      end)
    end)
  end)

  describe(':querySegment', function()
    it('returns nothing when the world is empty', function()
      assert.same(world:querySegment(0,0,0,1,1,1), {})
    end)

    it('does not touch borders', function()
      world:add({'a'}, 10,0,0, 5,5,5)
      world:add({'c'}, 20,0,0, 5,5,5)

      assert.same({}, world:querySegment( 0,5,0, 10,0,0))
      assert.same({}, world:querySegment(15,5,0, 20,0,0))
      assert.same({}, world:querySegment(26,5,0, 25,0,0))
    end)

    describe("when the world has items", function()
      local a, b, c

      before_each(function()
        a = world:add('a',  5,0,0, 5,10,10)
        b = world:add('b', 15,0,0, 5,10,10)
        c = world:add('c', 25,0,0, 5,10,10)
      end)

      it('returns the items touched by the segment, sorted by touch order', function()
        assert.same({a},     world:querySegment( 0,5,5, 11,5,5))
        assert.same({a,b},   world:querySegment( 0,5,5, 17,5,5))
        assert.same({a,b,c}, world:querySegment( 0,5,5, 30,5,5))
        assert.same({b,c},   world:querySegment(17,5,5, 26,5,5))
        assert.same({c},     world:querySegment(22,5,5, 26,5,5))

        assert.same({a},     world:querySegment(11,5,5,  0,5,5))
        assert.same({b,a},   world:querySegment(17,5,5,  0,5,5))
        assert.same({c,b,a}, world:querySegment(30,5,5,  0,5,5))
        assert.same({c,b},   world:querySegment(26,5,5, 17,5,5))
        assert.same({c},     world:querySegment(26,5,5, 22,5,5))
      end)

      it('filters out items when filter does not return true for them', function()
        local filter = function(other)
          return other ~= a and other ~= c
        end

        assert.same({},  world:querySegment( 0,5,5, 11,5,5, filter))
        assert.same({b}, world:querySegment( 0,5,5, 17,5,5, filter))
        assert.same({b}, world:querySegment( 0,5,5, 30,5,5, filter))
        assert.same({b}, world:querySegment(17,5,5, 26,5,5, filter))
        assert.same({},  world:querySegment(22,5,5, 26,5,5, filter))

        assert.same({},  world:querySegment(11,5,5,  0,5,5, filter))
        assert.same({b}, world:querySegment(17,5,5,  0,5,5, filter))
        assert.same({b}, world:querySegment(30,5,5,  0,5,5, filter))
        assert.same({b}, world:querySegment(26,5,5, 17,5,5, filter))
        assert.same({},  world:querySegment(26,5,5, 22,5,5, filter))
      end)
    end)
  end)

  describe(":hasItem", function()
    it('returns wether the world has an item', function()
      local item = {}

      assert.is_false(world:hasItem(item))
      world:add(item, 0,0,0,1,1,1)
      assert.is_true(world:hasItem(item))
    end)

    it('does not throw errors with non-tables or nil', function()

      assert.is_false(world:hasItem(false))
      assert.is_false(world:hasItem(1))
      assert.is_false(world:hasItem("hello"))
      assert.is_false(world:hasItem())
    end)
  end)

  describe(":getItems", function()
    it('returns all the items in the world', function()
      local a,b = 'a','b'
      world:add(a, 1,1,1,1,1,1)
      world:add(b, 2,2,2,2,2,2)
      local items, len = world:getItems()
      table.sort(items)
      assert.same({'a', 'b'}, items)
      assert.equals(2, len)
    end)
  end)

  describe(":countItems", function()
    it('counts the items in the world', function()
      world:add({}, 1,1,1,1,1,1)
      world:add({}, 2,2,2,2,2,2)
      local count = world:countItems()
      assert.equals(2, count)
    end)
  end)

  describe(":move", function()
    local a

    before_each(function()
      a = world:add('a', 0,0,0, 1,1,1)
    end)

    describe('when there are no collisions', function()
      it('it moves the object, and returns zero collisions', function()
        local x, y, z, cols, len = world:move(a, 1,1,1)

        assert.same(1, x)
        assert.same(1, y)
        assert.same(1, z)
        assert.same({}, cols)
        assert.same(0, len)
      end)
    end)

    describe('when touching', function()
      it('returns a collision with the first item it touches', function()
        world:add('b', 0,2,0, 1,1,1)
        world:add('c', 0,3,0, 1,1,1)
        local x,y,z,cols,len = world:move(a, 0,5,0, function() return 'touch' end)

        assert.same({x,y,z}, {0,1,0})
        assert.equals(1, len)
        assert.same({'b'}, collect(cols, 'other'))
        assert.same({'touch'}, collect(cols, 'type'))
        assert.same({0,1,0, 1,1,1}, {world:getCube(a)})
      end)
    end)

    describe('when crossing', function()
      it('returns a collision with every item it crosses', function()
        world:add('b', 0,2,0, 1,1,1)
        world:add('c', 0,3,0, 1,1,1)
        local x,y,z,cols,len = world:move(a, 0,5,0, function() return 'cross' end)

        assert.same({x,y,z}, {0,5,0})
        assert.equals(2, len)
        assert.same(collect(cols, 'other'), {'b', 'c'})
        assert.same(collect(cols, 'type'),  {'cross', 'cross'})
        assert.same({0,5,0,1,1,1}, {world:getCube(a)})
      end)
    end)

    describe('when sliding', function()
      it('slides with every element (2d version)', function()
        world:add('b', 0,2,0, 1,2,1)
        world:add('c', 2,1,0, 1,1,1)
        local x,y,z,cols,len = world:move(a, 5,5,0, function() return 'slide' end)

        assert.same({1,5,0}, {x,y,z})
        assert.equals(1, len)
        assert.same(collect(cols, 'other'), {'c'})
        assert.same(collect(cols, 'type'),  {'slide'})
        assert.same({1,5,0, 1,1,1}, {world:getCube(a)})
      end)

      it('slides with every element (3d version)', function()
        world:add('b', 0,2,0, 1,2,5)
        world:add('c', 2,1,0, 1,1,5)
        world:add('d', 0,0,4, 5,5,1)
        local x,y,z,cols,len = world:move(a, 5,5,5, function() return 'slide' end)

        assert.same({1,5,3}, {x,y,z}) -- commented out for now
        assert.equals(2, len)
        assert.same(collect(cols, 'other'), {'c', 'd'})
        assert.same(collect(cols, 'type'),  {'slide', 'slide'})
        assert.same({1,5,3, 1,1,1}, {world:getCube(a)})
      end)
    end)

    describe('when bouncing', function()
      it('bounces on each element',function()
        world:add('b', 0,2,0, 1,2,1)
        local x,y,z,cols,len = world:move(a, 0,5,0, function() return 'bounce' end)

        assert.same({x,y,z}, {0,-3, 0})
        assert.equal(1, len)
        assert.same(collect(cols, 'other'), {'b'})
        assert.same(collect(cols, 'type'),  {'bounce'})
        assert.same({0,-3,0, 1,1,1}, {world:getCube(a)})
      end)
    end)
  end)
end)
