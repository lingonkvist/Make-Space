-- The loot window delete button: its text, its hover list, and the delete run.

_G.MakeSpace = nil
_G.MakeSpaceDB = { version = 1 }
_G.MakeSpaceAccountDB = { marks = {} }

dofile("data/vendor_reagents.lua")
dofile("data/reagent_professions.lua")
dofile("data/class_reagents.lua")
dofile("data/quest_items.lua")
dofile("data/weapon_skills.lua")
dofile("src/safety.lua")
dofile("src/notes.lua")
dofile("src/curves.lua")
dofile("src/auction.lua")
dofile("src/live.lua")
dofile("src/verdict.lua")
dofile("src/makeroom.lua")
dofile("src/lootbutton.lua")

local function planned(bag, slot, id, count)
  return { bag = bag, slot = slot, itemID = id, count = count or 1, name = "Item " .. id, value = 40 }
end

-- A fake game: bags[bag][slot] = { id, count }.
local function fakeGame(bags)
  local game = { deleted = {}, held = nil, cleared = 0, blocked = false }
  game.api = {
    cursorHasItem = function() return game.held ~= nil end,
    itemAt = function(bag, slot)
      local entry = bags[bag] and bags[bag][slot]
      if not entry then return nil end
      return entry.id, entry.count
    end,
    pickup = function(bag, slot) game.held = { bag = bag, slot = slot } end,
    delete = function()
      if game.blocked then return end -- the game ignores it, the cursor keeps the item
      bags[game.held.bag][game.held.slot] = nil
      game.deleted[#game.deleted + 1] = game.held.bag .. ":" .. game.held.slot
      game.held = nil
    end,
    clearCursor = function() game.cleared = game.cleared + 1; game.held = nil end,
  }
  return game
end

describe("LootButton text", function()
  it("says how many items it deletes", function()
    assert.are.equal("Delete 1 item", MakeSpace.LootButton.Label(1))
    assert.are.equal("Delete 3 items", MakeSpace.LootButton.Label(3))
  end)

  it("names the item when it is the only one, cut short if the name is long", function()
    assert.are.equal("Delete Torn Rag", MakeSpace.LootButton.Label(1, "Torn Rag"))
    assert.are.equal("Delete Greater Sca...",
      MakeSpace.LootButton.Label(1, "Greater Scarlet Crusader Gauntlets"))
    assert.are.equal("Delete 2 items", MakeSpace.LootButton.Label(2, "Torn Rag"))
  end)

  it("lists each item with its price, and the stack size when it is more than one", function()
    local lines = MakeSpace.LootButton.TooltipLines({
      { name = "Broken Fang", itemID = 1, count = 1, value = 2 },
      { name = "Gray Pelt", itemID = 2, count = 3, value = 120 },
    })
    assert.are.equal("Bags full: makes room for loot", lines.title)
    assert.are.equal("Broken Fang", lines.rows[1].left)
    assert.are.equal("2c", lines.rows[1].right)
    assert.are.equal("Gray Pelt x3", lines.rows[2].left)
    assert.are.equal("1s 20c", lines.rows[2].right)
  end)

  it("falls back to the item id while the name is not known", function()
    local lines = MakeSpace.LootButton.TooltipLines({ { itemID = 77, count = 1, value = 0 } })
    assert.are.equal("item 77", lines.rows[1].left)
    assert.are.equal("", lines.rows[1].right)
  end)
end)

describe("LootButton.Run", function()
  it("deletes every planned item and reports no problem", function()
    local game = fakeGame({ [0] = { [1] = { id = 10, count = 1 }, [2] = { id = 20, count = 3 } } })
    local deleted, problem = MakeSpace.LootButton.Run(
      { planned(0, 1, 10), planned(0, 2, 20, 3) }, game.api)
    assert.are.equal(2, deleted)
    assert.is_nil(problem)
    assert.are.equal("0:1", game.deleted[1])
    assert.are.equal("0:2", game.deleted[2])
  end)

  it("works in combat too, the bag check is what keeps it safe", function()
    local game = fakeGame({ [0] = { [1] = { id = 10, count = 1 } } })
    local deleted, problem = MakeSpace.LootButton.Run({ planned(0, 1, 10) }, game.api)
    assert.are.equal(1, deleted)
    assert.is_nil(problem)
  end)

  it("does nothing while the cursor holds something", function()
    local game = fakeGame({ [0] = { [1] = { id = 10, count = 1 } } })
    game.held = { bag = 9, slot = 9 }
    local deleted = MakeSpace.LootButton.Run({ planned(0, 1, 10) }, game.api)
    assert.are.equal(0, deleted)
    assert.are.equal(0, #game.deleted)
  end)

  it("deletes nothing at all if any slot no longer holds what was planned", function()
    local game = fakeGame({ [0] = { [1] = { id = 10, count = 1 }, [2] = { id = 99, count = 1 } } })
    local deleted, problem = MakeSpace.LootButton.Run(
      { planned(0, 1, 10), planned(0, 2, 20) }, game.api)
    assert.are.equal(0, deleted)
    assert.is_truthy(problem:find("bags changed", 1, true))
    assert.are.equal(0, #game.deleted) -- the first one was fine, and still stayed
  end)

  it("treats a changed stack size as a changed bag", function()
    local game = fakeGame({ [0] = { [1] = { id = 10, count = 5 } } })
    local deleted = MakeSpace.LootButton.Run({ planned(0, 1, 10, 3) }, game.api)
    assert.are.equal(0, deleted)
    assert.are.equal(0, #game.deleted)
  end)

  it("an emptied slot counts as changed", function()
    local game = fakeGame({ [0] = {} })
    local deleted = MakeSpace.LootButton.Run({ planned(0, 1, 10) }, game.api)
    assert.are.equal(0, deleted)
  end)

  it("puts the item back and says so when the game blocks the delete", function()
    local game = fakeGame({ [0] = { [1] = { id = 10, count = 1 }, [2] = { id = 20, count = 1 } } })
    game.blocked = true
    local deleted, problem = MakeSpace.LootButton.Run(
      { planned(0, 1, 10), planned(0, 2, 20) }, game.api)
    assert.are.equal(0, deleted)
    assert.is_truthy(problem:find("did not allow", 1, true))
    assert.are.equal(1, game.cleared)
    assert.is_nil(game.held)
  end)

  it("a delete that errors is handled like a blocked one", function()
    local game = fakeGame({ [0] = { [1] = { id = 10, count = 1 } } })
    game.api.delete = function() error("blocked") end
    local deleted, problem = MakeSpace.LootButton.Run({ planned(0, 1, 10) }, game.api)
    assert.are.equal(0, deleted)
    assert.is_truthy(problem)
  end)
end)

describe("LootButton.Update", function()
  local shown, text, anchoredTo, summary

  local function stubGame(lootShown)
    shown, text, anchoredTo = false, nil, nil
    _G.UIParent = {}
    _G.LootFrame = { IsShown = function() return lootShown end }
    _G.CreateFrame = function()
      return {
        SetFrameStrata = function() end, SetSize = function() end, SetScript = function() end,
        SetText = function(_, value) text = value end,
        ClearAllPoints = function() end,
        SetPoint = function(_, _, relativeTo) anchoredTo = relativeTo end,
        Show = function() shown = true end,
        Hide = function() shown = false end,
      }
    end
    MakeSpace.Scanner = { MakeRoomSummary = function() return summary end }
  end

  it("shows under the loot window while there is something to delete", function()
    summary = { active = true, deletes = 2 }
    stubGame(true)
    MakeSpace.LootButton.Update()
    assert.are.equal(true, shown)
    assert.are.equal("Delete 2 items", text)
    assert.are.equal(_G.LootFrame, anchoredTo)
  end)

  it("names a single item", function()
    summary = { active = true, deletes = 1, deleteNames = { "Torn Rag" } }
    stubGame(true)
    MakeSpace.LootButton.Update()
    assert.are.equal("Delete Torn Rag", text)
  end)

  it("hides again when the plan has nothing to delete", function()
    summary = { active = true, deletes = 1 }
    stubGame(true)
    MakeSpace.LootButton.Update()
    summary = { active = true, deletes = 0 }
    MakeSpace.LootButton.Update()
    assert.are.equal(false, shown)
  end)

  it("hides when the loot window is gone", function()
    summary = { active = true, deletes = 1 }
    stubGame(true)
    MakeSpace.LootButton.Update()
    _G.LootFrame = { IsShown = function() return false end }
    MakeSpace.LootButton.Update()
    assert.are.equal(false, shown)
  end)

  it("never shows when the plan is not active", function()
    summary = { active = false, deletes = 3 }
    stubGame(true)
    MakeSpace.LootButton.Update()
    assert.are.equal(false, shown)
  end)

  it("removes the globals this spec set", function()
    _G.LootFrame, _G.CreateFrame, _G.UIParent = nil, nil, nil
    assert.is_nil(_G.LootFrame)
  end)
end)
