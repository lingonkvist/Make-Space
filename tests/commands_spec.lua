-- MakeSpace: command parsing and override list tests

_G.MakeSpace = nil
_G.MakeSpaceDB = { version = 1 }
_G.MakeSpaceAccountDB = { marks = {} }

dofile("src/overrides.lua")
dofile("src/curves.lua")
dofile("src/auction.lua")
dofile("src/commands.lua")

describe("Commands.TierLines", function()
  local saved
  local function lines(api)
    return table.concat(MakeSpace.Commands.TierLines(api), "\n")
  end

  it("checks every item against what the game says", function()
    saved = MakeSpace.Data and MakeSpace.Data.ConsumableTiers
    MakeSpace.Data = MakeSpace.Data or {}
    dofile("data/consumable_tiers.lua")
    local info = {
      [3928] = { "Superior Healing Potion", 35, 0 },
      [13446] = { "Major Healing Potion", 50, 0 },     -- needs more than the table says
      [1710] = { "Greater Healing Potion", 21, 1 },    -- binds when picked up
      [929] = { "Healing Pot", 12, 0 },                -- called something else
    }
    local text = lines({
      itemInfo = function(id) local row = info[id]; if row then return row[1], row[2], row[3] end end,
      isKnown = function(spell) return false end,
    })
    assert.is_truthy(text:find("Superior Healing Potion (level 35): 3928 ok", 1, true))
    assert.is_truthy(text:find("13446 needs level 50", 1, true))
    assert.is_truthy(text:find("1710 binds when picked up", 1, true))
    assert.is_truthy(text:find('929 is called "Healing Pot"', 1, true))
    assert.is_truthy(text:find("118 not loaded yet", 1, true))
    assert.is_truthy(text:find("Run this again in a moment", 1, true))
  end)

  it("says which bandage recipes you know and which is the best", function()
    local recipe, id
    for _, bandage in ipairs(MakeSpace.Data.ConsumableTiers.bandages) do
      if bandage.name == "Wool Bandage" then recipe, id = bandage.recipe, bandage.id end
    end
    local text = lines({
      itemInfo = function() end,
      isKnown = function(spell) return spell == recipe end,
      bestBandageID = id,
    })
    assert.is_truthy(text:find("Wool Bandage (" .. id .. "), recipe " .. recipe .. ": known", 1, true))
    assert.is_truthy(text:find("Linen Bandage", 1, true))
    assert.is_truthy(text:find(": not known", 1, true))
    assert.is_truthy(text:find("Best bandage you can make: Wool Bandage", 1, true))
  end)

  it("cannot check recipes when the game has no such call, and has none then", function()
    local text = lines({ itemInfo = function() end })
    assert.is_truthy(text:find(": cannot check", 1, true))
    assert.is_truthy(text:find("Best bandage you can make: none", 1, true))
    MakeSpace.Data.ConsumableTiers = saved
  end)

  it("has nothing to say without tier data", function()
    assert.are.equal("No tier data is loaded.", lines({ itemInfo = function() end }))
  end)
end)

describe("Commands.ParseItemID", function()
  it("reads the ID out of a shift-clicked item link", function()
    local link = "|cff1eff00|Hitem:2589::::::::60:::::|h[Linen Cloth]|h|r"

    assert.are.equal(2589, MakeSpace.Commands.ParseItemID(link))
  end)

  it("accepts a bare numeric ID", function()
    assert.are.equal(2589, MakeSpace.Commands.ParseItemID("2589"))
  end)

  it("resolves a name through the injected lookup", function()
    local lookup = function(name)
      if name == "Linen Cloth" then return "|Hitem:2589::|h[Linen Cloth]|h" end
    end

    assert.are.equal(2589, MakeSpace.Commands.ParseItemID("Linen Cloth", lookup))
  end)

  it("returns nil for an unknown name or empty text", function()
    local lookup = function() return nil end

    assert.is_nil(MakeSpace.Commands.ParseItemID("Nonsense", lookup))
    assert.is_nil(MakeSpace.Commands.ParseItemID(""))
    assert.is_nil(MakeSpace.Commands.ParseItemID(nil))
  end)
end)

describe("Item marks", function()
  it("one mark per item: the last one set wins", function()
    MakeSpace.Overrides.Set(100, "yellow", "Thing")
    MakeSpace.Overrides.Set(100, "none", "Thing")

    assert.is_truthy(MakeSpace.Overrides.IsKept(100))
    assert.is_false(MakeSpace.Overrides.IsFlagged(100))
    assert.are.equal("none", MakeSpace.Overrides.Get(100))

    MakeSpace.Overrides.Set(100, "green")

    assert.is_truthy(MakeSpace.Overrides.IsMarkedGreen(100))
    assert.are.equal("Thing", MakeSpaceAccountDB.marks[100].name) -- the name stays
  end)

  it("default or nil goes back to the normal rules, and says whether anything changed", function()
    MakeSpace.Overrides.Set(200, "none", "Thing")

    assert.is_true(MakeSpace.Overrides.Set(200, "default"))
    assert.is_false(MakeSpace.Overrides.Set(200, nil))
    assert.is_nil(MakeSpace.Overrides.Get(200))
    assert.is_true(MakeSpace.Overrides.Set(201, "green"))
    assert.is_true(MakeSpace.Overrides.Set(201, nil))
    assert.is_false(MakeSpace.Overrides.Set(201, nil))
  end)

  it("an unknown mark is refused", function()
    assert.is_false(MakeSpace.Overrides.Set(300, "purple"))
    assert.is_nil(MakeSpace.Overrides.Get(300))
  end)

  it("counts the marks of each kind", function()
    MakeSpaceAccountDB.marks = {}
    MakeSpace.Overrides.Set(1, "green")
    MakeSpace.Overrides.Set(2, "green")
    MakeSpace.Overrides.Set(3, "none")

    local counts = MakeSpace.Overrides.Counts()
    assert.are.equal(2, counts.green)
    assert.are.equal(0, counts.yellow)
    assert.are.equal(1, counts.none)
  end)
end)

describe("Commands.SplitInput", function()
  it("splits a command from its argument at the first space", function()
    local cmd, argument = MakeSpace.Commands.SplitInput("  keep Linen Cloth ")
    assert.are.equal("keep", cmd)
    assert.are.equal("Linen Cloth", argument)
  end)

  it("splits where a shift-clicked link starts when there is no space", function()
    local link = "|cnIQ1:|Hitem:5060::::::::24:1488::::::|h[Thieves' Tools]|h|r"
    local cmd, argument = MakeSpace.Commands.SplitInput("why" .. link)
    assert.are.equal("why", cmd)
    assert.are.equal(5060, MakeSpace.Commands.ParseItemID(argument))
  end)

  it("treats an empty message as no command", function()
    assert.are.equal("", (MakeSpace.Commands.SplitInput("")))
    assert.are.equal("", (MakeSpace.Commands.SplitInput(nil)))
  end)
end)

describe("Commands.SummaryLine", function()
  MakeSpace.Verdict = MakeSpace.Verdict or {}
  MakeSpace.Verdict.FormatMoney = MakeSpace.Verdict.FormatMoney or function(copper) return copper .. "c" end

  it("says greens with their vendor value and yellows", function()
    local line = MakeSpace.Commands.SummaryLine({ green = 9, yellow = 5, greenValue = 214 })
    assert.are.equal("9 green (214c at a vendor), 5 yellow", line)
  end)

  it("leaves out what is zero", function()
    assert.are.equal("5 yellow", MakeSpace.Commands.SummaryLine({ green = 0, yellow = 5, greenValue = 0 }))
    assert.are.equal("2 green (30c at a vendor)", MakeSpace.Commands.SummaryLine({ green = 2, yellow = 0, greenValue = 30 }))
  end)

  it("gives nothing when nothing is marked", function()
    assert.is_nil(MakeSpace.Commands.SummaryLine({ green = 0, yellow = 0, greenValue = 0 }))
  end)
end)
