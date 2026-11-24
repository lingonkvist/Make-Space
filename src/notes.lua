-- MakeSpace: the words behind every yellow verdict, defined once in three parts:
--   title   two to four words, no numbers: the opinion, as a fact about the item
--           ("Needed later", "Not your profession"), not an instruction. An action
--           is allowed only where the item has one obvious thing to do (Open it,
--           Library book, Trade for a buff, Consider auctioning). Constant per
--           situation, so the tooltip heading is predictable.
--   detail  the one fact behind the title ("Requires level 30"), or nil when the
--           item's own tooltip already says it. Lines are joined with "\n".
--   reason  one factual sentence for the report and /makespace why. May carry
--           numbers. Never a hint about what else to do (the price line says that).
-- A tooltip is title, detail, then at most one price or source line: three lines or
-- fewer (DESIGN.md). Every line is written to fit LINE_MAX characters; names are cut
-- with Cut, lists name two and count the rest. The same idea always gets the same words:
--   Requires X       a requirement (level, skill), as the item's own tooltip says it
--   Used by X        who uses it; Used from X: the skill where a use starts
--   Best for you: X  the better one to use instead
--   Hand in to X     where to take it
--   Vendor Xs, auction up to Ys   the money line
-- Do not repeat a word the title already says ("Needed later" is not followed by "Needs").
-- A rule returns the heading with its verdict, so the tooltip never guesses it.
MakeSpace = MakeSpace or {}
MakeSpace.Notes = {
  -- The reason of a green that only says the stack is worth next to nothing. The
  -- tooltip leaves it out when a price line under the heading already shows it.
  WORTH_LITTLE_REASON = "Worth very little",
  -- Title of the hints for an item you cannot use yet but will. Pointless once the
  -- item is in the bank, so the bank view drops anything with this title.
  NEEDED_LATER_TITLE = "Needed later",
  -- The width every tooltip line is written to fit, in characters. Wider lines stretch
  -- the whole tooltip past the item's own text.
  LINE_MAX = 45,
}
local NEEDED_LATER = MakeSpace.Notes.NEEDED_LATER_TITLE

--- Cut a name so a line fits: "Rise of the Silithid Hive..." (trailing space trimmed).
function MakeSpace.Notes.Cut(text, max)
  if #text <= max then return text end
  return (text:sub(1, max - 3):gsub("%s+$", "")) .. "..."
end
local Cut = MakeSpace.Notes.Cut
local MARKED = "Marked by you"

-- Hints whose whole point is "you cannot use this, so it may sell". When the
-- auction pays next to nothing and the stack is worth next to nothing, such a
-- hint can turn into "worth very little" (see runRule in verdict.lua).
local HINTS_AT_AUCTION = { not_your_profession = true, other_profession_reagent = true }

local function capitalize(text)
  return (text:gsub("^%l", string.upper))
end

-- The facts of an outleveled piece of gear, for the yellow's detail and the green's reason.
-- The required level is named when there is a real one (level 1 is every item's floor,
-- so it says nothing). The item level joins it when it is the higher one (it decided),
-- and stands alone otherwise.
-- "You are N" only goes with a required level: an item level is not a character level.
local function gearFacts(required, itemLevel, you)
  if itemLevel > required then
    return required > 1 and ("Requires level " .. required .. ", item level " .. itemLevel)
        or ("Item level " .. itemLevel)
  end
  return "Requires level " .. required .. ", you are " .. you
end

local function lowerFirst(text)
  return (text:gsub("^%u", string.lower))
end

-- A hint that an item will be needed later: the reason says when, the detail what.
local function neededLater(when, detail)
  return "Needed later, " .. when, NEEDED_LATER, detail
end

local NOTES = {
  outleveled_gear = function(very, required, itemLevel, you)
    -- The tooltip keeps one title for all wordings: the detail says which.
    local lead = very and "Very low " or "Low "
    local facts = gearFacts(required, itemLevel, you)
    if itemLevel > required then
      local reason = required > 1
          and (lead .. "level gear (requires " .. required .. ", item level " .. itemLevel .. ", you are " .. you .. ")")
          or (lead .. "item level (" .. itemLevel .. " for level " .. you .. ")")
      return reason, "Outleveled gear", facts
    end
    return lead .. "level gear (requires " .. required .. ", you are " .. you .. ")", "Outleveled gear", facts
  end,
  quest_abandon = function()
    return "Quest in your log is far below you", "Outleveled quest", "Consider abandoning it"
  end,
  quest_not_worth = function()
    return "Quest is far below you", "Outleveled quest", "Probably not worth it"
  end,
  gray_worth = function(value)
    -- Only the cheapest gray keeps a dot, so it is always "the cheapest". The
    -- detail line is the reason itself, worded like the green gray's; the title
    -- says why it is not green.
    local reason = "Cheapest gray, sells for " .. value
    return reason, "Gray worth selling", reason
  end,
  no_known_use = function(value)
    return "Not used for any quest or recipe, sells for " .. value, "No known use", nil
  end,
  not_your_profession = function()
    return "You don't have this profession", "Not your profession", nil
  end,
  later_skill = function(profession, skill)
    return neededLater("at " .. profession .. " " .. skill, "Requires " .. profession .. " " .. skill)
  end,
  later_level = function(level)
    return neededLater("at level " .. level, "Requires level " .. level)
  end,
  later_used_from = function(profession, skill)
    return neededLater("from " .. profession .. " " .. skill, "Used from " .. profession .. " " .. skill)
  end,
  later_quest = function(level, label)
    return neededLater("quest requires level " .. level,
        label and Cut(label, MakeSpace.Notes.LINE_MAX) or ("Requires level " .. level))
  end,
  later_event = function(event, label)
    local lead = capitalize(event)
    return neededLater("for a " .. event .. " quest",
        label and (lead .. ": " .. Cut(label, MakeSpace.Notes.LINE_MAX - #lead - 2)) or lead)
  end,
  outleveled_reagent = function(profession, skill, green)
    -- With the green point known, say where the last recipe turns green.
    local rest = green and ("recipes turn green at " .. profession .. " " .. skill)
        or (profession .. " recipes use it up to " .. skill)
    return "Outleveled, " .. rest, "Outleveled reagent", capitalize(rest)
  end,
  auction_it = function(priceText, isLive)
    -- The detail is the price line itself ("Vendor 3s, auction up to 8s"). A live
    -- price is Auctionator's own, which its tooltip already shows right above, so
    -- only a snapshot price (a number Auctionator does not show) repeats it here.
    return "Consider auctioning (" .. lowerFirst(priceText) .. ")",
        "Consider auctioning", (not isLive) and priceText or nil
  end,
  open_it = function()
    return "Open it, the contents may stack", "Open it", "Contents may stack"
  end,
  no_mana = function(who)
    -- The item's own name says "Mana", so the heading only has to say it is no use to you.
    return who .. " have no mana", "Useless to " .. who, nil
  end,
  no_use_stat = function(who, stat)
    return who .. " get nothing from " .. stat, "Useless to " .. who, nil
  end,
  low_level_consumable = function(noun, level, you, better)
    -- The detail is only the better one to use, when there is one: the item's own
    -- tooltip says its level and you know yours.
    return "Outleveled " .. noun .. " (level " .. level .. ", you are " .. you .. ")",
        "Outleveled " .. noun, better and Cut("Best for you: " .. better, MakeSpace.Notes.LINE_MAX) or nil
  end,
  weak_bandage = function(percent, better)
    local heals = "Heals " .. percent .. "% of your health"
    -- With a better bandage the detail is one line: what it heals, then what to use.
    local detail = better and Cut("Heals " .. percent .. "%, best for you: " .. better,
        MakeSpace.Notes.LINE_MAX) or heals
    return "Weak bandage, " .. heals:lower(), "Weak bandage", detail
  end,
  wrong_class_reagent = function(whole)
    return whole, "Wrong class reagent", whole
  end,
  other_faction_quest = function(other)
    return "Only used by " .. other .. " quests", other .. "-only quest item", nil
  end,
  other_profession_reagent = function(professions)
    -- Two names and a count of the rest, so the line stays short however many use it.
    local list = table.concat(professions, ", ", 1, math.min(#professions, 2))
    if #professions > 2 then list = list .. " +" .. (#professions - 2) end
    return "Only used by professions you don't have", "Not your profession", "Used by " .. list
  end,
  library_book = function(faction)
    local where = "the librarian in Stormwind or Undercity"
    local short = "Stormwind or Undercity"
    if faction == "Alliance" then
      where, short = "Garion Wendell in Stormwind", "Garion Wendell, Stormwind"
    elseif faction == "Horde" then
      where, short = "Owen Thadd in Undercity", "Owen Thadd, Undercity"
    end
    return "Library book, hand it in to " .. where, "Library book", "Hand in to " .. short
  end,
  shard_buff = function()
    return "Trade 4 of these to Mangletooth for a buff in the Barrens", "Trade for a buff",
        "Mangletooth, Camp Taurajo"
  end,
  flagged = function()
    return "You marked this item", MARKED, nil
  end,
}


--- Look up a note: returns the full reason and a heading { title, detail }.
-- @param key string  a key of NOTES
function MakeSpace.Notes.Get(key, ...)
  local reason, title, detail = NOTES[key](...)
  return reason, { title = title, detail = detail, hintsAuction = HINTS_AT_AUCTION[key] or nil }
end

-- The words behind every green. A green has no heading (the tooltip says "Safe to
-- delete" and shows the reason under it), so each note gives a reason and, where
-- there is one, a detail.
local GREEN_NOTES = {
  quest_completed = function(label)
    -- One line: the quest, then that it is done. Without a name, just that it is done.
    if not label then return "Quest completed" end
    local suffix = " (completed)"
    return Cut(label, MakeSpace.Notes.LINE_MAX - #suffix) .. suffix
  end,
  quests_completed = function(count)
    return "All " .. count .. " quests completed"
  end,
  vendor_reagent = function(professions)
    -- professions is the list that uses it, or nil when only the skill lines are known.
    if not professions then return "Vendor reagent" end
    local named = "Vendor reagent (" .. table.concat(professions, ", ") .. ")"
    if #professions >= 3 or #named > MakeSpace.Notes.LINE_MAX then
      return "Vendor reagent (" .. #professions .. " professions)"
    end
    return named
  end,
  no_known_use = function()
    return "Not used for any quest or recipe"
  end,
  worse_than_equipped = function()
    return "Worse than your equipped gear"
  end,
  class_cannot = function(who, what, level)
    -- what is "wear plate" or "use axes"; level is when they can start, if ever.
    return who .. " can't " .. what .. (level and (" until level " .. level) or "")
  end,
  vendor_beats_auction = function(vendorText, auctionText, isLive)
    return "Vendor " .. vendorText .. ", auction " .. (isLive and "about " or "up to ") .. auctionText
  end,
  vendor_gray = function(valueText)
    return "Gray, sells for " .. valueText
  end,
  cheapest_gray = function(valueText)
    return "Cheapest gray, " .. (valueText and ("sells for " .. valueText) or "no vendor value")
  end,
  cheap_to_rebuy = function(detail)
    -- detail is what the item is for ("Used from Cooking 145"): the green says why it
    -- is still safe to delete, which is that buying it again costs next to nothing.
    return "Cheap to rebuy, " .. lowerFirst(detail)
  end,
  worth_little = function(title)
    -- title is what the hint was ("Outleveled reagent"), so the green says why.
    local little = MakeSpace.Notes.WORTH_LITTLE_REASON
    return title and (title .. ", " .. little:lower()) or little
  end,
  marked = function()
    return MARKED
  end,
  outleveled_gear = function(required, itemLevel, you)
    return gearFacts(required, itemLevel, you)
  end,
}

--- Look up the words of a green: returns the reason and a detail (or nil).
-- @param key string  a key of GREEN_NOTES
function MakeSpace.Notes.Green(key, ...)
  return GREEN_NOTES[key](...)
end
