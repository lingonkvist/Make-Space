-- The entry point's loot handling: a loot window with no items (gold) must not
-- cost a full bag scan, and one with items must still get one.

local handlers, scans, lootUpdates, hasLoot, planActive, opened, bagsShown

local function loadEntry()
  scans, lootUpdates, hasLoot = 0, 0, false
  planActive, opened, bagsShown = false, 0, false
  handlers = nil
  _G.CreateFrame = function()
    return {
      RegisterEvent = function() end,
      UnregisterEvent = function() end,
      SetScript = function(_, name, fn) if name == "OnEvent" then handlers = fn end end,
    }
  end
  _G.C_Timer = nil
  _G.OpenAllBags = function() opened = opened + 1 end
  _G.CloseAllBags = nil
  _G.ContainerFrameCombinedBags = { IsShown = function() return bagsShown end }
  _G.MakeSpaceDB = nil
  _G.MakeSpace = {
    Bags = {},
    Scanner = {
      ScanAll = function() scans = scans + 1 end,
      ClearCache = function() end,
      HasLoot = function() return hasLoot end,
      RefreshLoot = function() end,
      ClearLoot = function() hasLoot = false end,
      MakeRoomSummary = function() return { active = planActive } end,
    },
    Overlay = {
      UpdateAll = function() end,
      UpdateLoot = function() lootUpdates = lootUpdates + 1 end,
      SetVendorOpen = function() end,
    },
  }
  dofile("MakeSpace.lua")
end

local frameStandIn = { RegisterEvent = function() end, UnregisterEvent = function() end }
local function fire(event, ...) handlers(frameStandIn, event, ...) end

describe("Entry point: loot events", function()
  it("does not scan the bags for a window with no items", function()
    loadEntry()
    fire("LOOT_OPENED")
    fire("LOOT_SLOT_CLEARED", 1)
    fire("LOOT_CLOSED")
    assert.are.equal(0, scans)
  end)

  it("does not read the auto-loot flag of LOOT_OPENED as a cleared slot", function()
    loadEntry()
    local cleared = "unset"
    _G.MakeSpace.Scanner.RefreshLoot = function(slot) cleared = slot end
    fire("LOOT_OPENED", 1, false)
    assert.is_nil(cleared)
    fire("LOOT_SLOT_CLEARED", 2)
    assert.are.equal(2, cleared)
  end)

  it("scans when the window opens with items in it", function()
    loadEntry()
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = true end
    fire("LOOT_OPENED")
    assert.are.equal(1, scans)
  end)

  it("scans when the last item is taken, so the plan is taken down", function()
    loadEntry()
    hasLoot = true
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = false end
    fire("LOOT_SLOT_CLEARED", 1)
    assert.are.equal(1, scans)
    -- the banner and button come down with one repaint, not several
    assert.are.equal(1, lootUpdates)
  end)

  it("repaints the loot window twice while loot remains: now, and after Blizzard lays the rows out", function()
    loadEntry()
    local later = {}
    _G.C_Timer = { After = function(_, fn) later[#later + 1] = fn end }
    hasLoot = true
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = true end
    fire("LOOT_SLOT_CLEARED", 1)
    assert.are.equal(1, lootUpdates)
    assert.are.equal(1, #later)
    later[1]()
    assert.are.equal(2, lootUpdates)
    _G.C_Timer = nil
  end)

  it("a burst of loot events in one frame costs one rescan now and one after", function()
    loadEntry()
    local later = {}
    _G.C_Timer = { After = function(_, fn) later[#later + 1] = fn end }
    hasLoot = true
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = true end
    fire("LOOT_OPENED")
    fire("LOOT_SLOT_CLEARED", 1)
    fire("LOOT_SLOT_CLEARED", 2)
    fire("LOOT_SLOT_CLEARED", 3)
    assert.are.equal(1, scans)
    assert.are.equal(1, #later)
    later[1]()
    assert.are.equal(2, scans) -- the events that arrived meanwhile are covered
    assert.are.equal(4, _G.MakeSpace.LootStats.events)
    assert.are.equal(2, _G.MakeSpace.LootStats.scans)
    _G.C_Timer = nil
  end)

  it("no extra rescan after the frame when nothing else arrived", function()
    loadEntry()
    local later = {}
    _G.C_Timer = { After = function(_, fn) later[#later + 1] = fn end }
    hasLoot = true
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = true end
    fire("LOOT_OPENED")
    later[1]()
    assert.are.equal(1, scans)
    _G.C_Timer = nil
  end)

  it("takes the banner down at once when the last item is taken in a burst", function()
    loadEntry()
    local later = {}
    _G.C_Timer = { After = function(_, fn) later[#later + 1] = fn end }
    hasLoot = true
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = true end
    fire("LOOT_OPENED")
    local before = lootUpdates
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = false end
    fire("LOOT_SLOT_CLEARED", 1)
    assert.are.equal(before + 1, lootUpdates)
    _G.C_Timer = nil
  end)

  it("scans when the window closes with items left, and not otherwise", function()
    loadEntry()
    hasLoot = true
    fire("LOOT_CLOSED")
    assert.are.equal(1, scans)
    fire("LOOT_CLOSED")
    assert.are.equal(1, scans)
  end)

  it("always repaints the loot window parts on close, so the banner and button come down", function()
    loadEntry()
    fire("LOOT_CLOSED")
    fire("LOOT_CLOSED")
    assert.are.equal(2, lootUpdates)
  end)
end)

describe("Entry point: the bags are left alone", function()
  it("never opens them, even when the make-room plan is active", function()
    loadEntry()
    planActive = true
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = true end
    fire("LOOT_OPENED")
    fire("LOOT_SLOT_CLEARED", 1)
    fire("LOOT_CLOSED")
    assert.are.equal(0, opened)
  end)

  it("still scans for the plan when the window opens with items", function()
    loadEntry()
    planActive = true
    _G.MakeSpace.Scanner.RefreshLoot = function() hasLoot = true end
    fire("LOOT_OPENED")
    assert.are.equal(1, scans)
  end)

  it("drops the old open-the-bags setting from saved variables", function()
    loadEntry()
    _G.MakeSpaceDB = { autoOpenBags = true }
    fire("ADDON_LOADED", "MakeSpace")
    assert.is_nil(_G.MakeSpaceDB.autoOpenBags)
  end)
end)

-- Leave no stand-ins behind for the specs that run after this one.
describe("Entry point: cleanup", function()
  it("removes the globals this spec set", function()
    _G.ContainerFrameCombinedBags = nil
    _G.OpenAllBags = nil
    _G.CloseAllBags = nil
    _G.MakeSpaceDB = nil
    _G.MakeSpace = nil
    assert.is_nil(_G.ContainerFrameCombinedBags)
  end)
end)
