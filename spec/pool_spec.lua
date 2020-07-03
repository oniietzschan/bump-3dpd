local Bump = require('bump-3dpd')

describe('table pool functions', function()
  it('freeTable and fetchTable should reuse tables', function()
    local tableA = Bump.fetchTable()
    local tableB = Bump.fetchTable()
    Bump.freeTable(tableA)
    Bump.freeTable(tableB)
    local tableC = Bump.fetchTable()
    local tableD = Bump.fetchTable()
    assert.is_true(tableB == tableC)
    assert.is_true(tableA == tableD)
  end)

  it('freeTable should clear all attributes', function()
    local t = Bump.fetchTable()
    t[1] = 1
    t[2] = 2
    t[4] = 4
    t.key = 'value'

    Bump.freeTable(t)
    assert.is_nil(t[1])
    assert.is_nil(t[2])
    assert.is_nil(t[4])
    assert.is_nil(t.key)
  end)

  describe('freeCollisions should clear numeric keys', function()
    local cols = Bump.fetchTable()
    cols[1] = Bump.fetchTable()
    cols[2] = Bump.fetchTable()
    local colA = cols[1]
    local colB = cols[2]
    colA.item = {}
    colA.touchX = 11
    colA.touchY = 22
    colB.item = {}
    colB.touchX = 11
    colB.touchY = 22

    Bump.freeCollisions(cols)
    assert.is_nil(cols[1])
    assert.is_nil(cols[2])
    assert.is_nil(colA.item)
    assert.is_nil(colA.touchX)
    assert.is_nil(colA.touchY)
    assert.is_nil(colB.item)
    assert.is_nil(colB.touchX)
    assert.is_nil(colB.touchY)
  end)

  describe('Methods on World should work too...', function()
    local world = Bump.newWorld()

    local cols = world.fetchTable()
    cols[1] = world.fetchTable()
    local col = cols[1]
    col.item = {}

    world.freeCollisions(cols)
    assert.is_nil(cols[1])
    assert.is_nil(col.item)
  end)
end)
