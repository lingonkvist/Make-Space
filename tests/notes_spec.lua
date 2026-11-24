-- MakeSpace: every tooltip line a note writes fits the width, and the titles follow the standard.

_G.MakeSpace = nil
dofile("src/notes.lua")

local MAX = MakeSpace.Notes.LINE_MAX
local LONG_QUEST = "[60] The Most Impressively Long Quest Name In The Entire Game"
local LONG_ITEM = "Heavy Mageweave Bandage Of The Eagle"
local MONEY = "99g 99s 99c"
local PRICE = "Vendor " .. MONEY .. ", auction up to 99g 99s"

-- Each note with its longest realistic inputs.
local YELLOWS = {
  { "outleveled_gear", true, 55, 59, 60 },
  { "outleveled_gear", false, 59, 59, 60 },
  { "outleveled_gear", false, 0, 59, 60 },
  { "quest_abandon" },
  { "quest_not_worth" },
  { "gray_worth", MONEY },
  { "no_known_use", MONEY },
  { "not_your_profession" },
  { "later_skill", "Leatherworking", 300 },
  { "later_level", 60 },
  { "later_used_from", "Leatherworking", 300 },
  { "later_quest", 60, LONG_QUEST },
  { "later_event", "Darkmoon Faire", LONG_QUEST },
  { "outleveled_reagent", "Leatherworking", 300, true },
  { "outleveled_reagent", "Leatherworking", 300, false },
  { "auction_it", PRICE, false },
  { "open_it" },
  { "no_mana", "Warriors" },
  { "no_use_stat", "Warriors", "Intellect" },
  { "low_level_consumable", "potion", 60, 60, LONG_ITEM },
  { "weak_bandage", 19, LONG_ITEM },
  { "weak_bandage", 19 },
  { "wrong_class_reagent", "Hunter, Mage, Priest only (world drop)" },
  { "other_faction_quest", "Alliance" },
  { "other_profession_reagent", { "Leatherworking", "Blacksmithing", "Engineering", "Tailoring", "Enchanting" } },
  { "library_book", "Alliance" },
  { "library_book", "Horde" },
  { "library_book" },
  { "shard_buff" },
  { "flagged" },
}

local GREENS = {
  { "quest_completed", LONG_QUEST },
  { "quest_completed" },
  { "quests_completed", 99 },
  { "vendor_reagent", { "Leatherworking", "Blacksmithing" } },
  { "vendor_reagent", { "Leatherworking", "Blacksmithing", "Engineering" } },
  { "no_known_use" },
  { "worse_than_equipped" },
  { "class_cannot", "Warriors", "wear cloth", 60 },
  { "vendor_beats_auction", MONEY, MONEY, false },
  { "vendor_gray", MONEY },
  { "cheapest_gray", MONEY },
  { "cheap_to_rebuy", "Used from Leatherworking 300" },
  { "worth_little", "Outleveled reagent" },
  { "worth_little", "Not your profession" },
  { "outleveled_gear", 59, 59, 60 },
  { "outleveled_gear", 0, 59, 60 },
}

local function lengthsOf(text)
  local longest = 0
  for part in tostring(text):gmatch("[^\n]+") do longest = math.max(longest, #part) end
  return longest
end

describe("Notes: width", function()
  -- Collected, so a failure names every note that is too wide at once.
  it("fits every yellow's title and detail in one line each", function()
    local problems = {}
    for _, case in ipairs(YELLOWS) do
      local _, heading = MakeSpace.Notes.Get(unpack(case))
      if #heading.title > MAX then problems[#problems + 1] = case[1] .. " title: " .. heading.title end
      if heading.detail and (heading.detail:find("\n", 1, true) or #heading.detail > MAX) then
        problems[#problems + 1] = case[1] .. " detail (" .. #heading.detail .. "): " .. heading.detail
      end
    end
    assert.are.equal("", table.concat(problems, " | "))
  end)

  it("fits every green's reason and detail", function()
    local problems = {}
    for _, case in ipairs(GREENS) do
      local reason, detail = MakeSpace.Notes.Green(unpack(case))
      if lengthsOf(reason) > MAX then problems[#problems + 1] = case[1] .. " reason: " .. reason end
      if detail and lengthsOf(detail) > MAX then problems[#problems + 1] = case[1] .. " detail: " .. detail end
    end
    assert.are.equal("", table.concat(problems, " | "))
  end)
end)

describe("Notes: standard", function()
  it("never repeats the title's word in the detail", function()
    for _, case in ipairs(YELLOWS) do
      local _, heading = MakeSpace.Notes.Get(unpack(case))
      if heading.title == "Needed later" and heading.detail then
        assert.is_nil(heading.detail:lower():find("need", 1, true), heading.detail)
      end
    end
  end)

  it("cuts a name at the width, trims the space, and leaves a short one alone", function()
    local cut = MakeSpace.Notes.Cut
    assert.are.equal("Rise of the Silithid Hive...", cut("Rise of the Silithid Hive Mind", 28))
    assert.are.equal("Large Boar...", cut("Large Boar Tusks", 14))
    assert.are.equal("Short", cut("Short", 28))
  end)
end)
