-- MakeSpace: the words behind every yellow verdict, defined once in three parts:
--   reason  one sentence for the report and /makespace why. May carry numbers.
--           Never a hint about what else to do (the price line says that).
--   title   two to four words, no numbers. Constant per situation, so the tooltip
--           heading is predictable.
--   detail  the one fact or action behind the title ("Needs level 30"), or nil when
--           the item's own tooltip already says it. Lines are joined with "\n".
-- A rule returns the heading with its verdict, so the tooltip never guesses it.
MakeSpace = MakeSpace or {}
MakeSpace.Notes = {
  -- The reason of a green that only says the stack is worth next to nothing. The
  -- tooltip leaves it out when a price line under the heading already shows it.
  WORTH_LITTLE_REASON = "Worth very little",
  -- Title of the hints that tell you to bank an item. Pointless once the item
  -- is in the bank, so the bank view drops anything with this title.
  BANK_IT_TITLE = "Bank it",
}
local BANK_IT = MakeSpace.Notes.BANK_IT_TITLE
local MARKED = "Marked by you"

-- Hints whose whole point is "you cannot use this, so it may sell". When the
-- auction pays next to nothing and the stack is worth next to nothing, such a
-- hint can turn into "worth very little" (see runRule in verdict.lua).
local HINTS_AT_AUCTION = { not_your_profession = true, other_profession_reagent = true }

local function capitalize(text)
  return (text:gsub("^%l", string.upper))
end

-- The facts of an outleveled piece of gear, for the yellow's detail and the green's reason.
local function gearFacts(isItemLevel, n, you)
  return (isItemLevel and "Item level " or "Required level ") .. n .. ", you are " .. you
end

local function lowerFirst(text)
  return (text:gsub("^%u", string.lower))
end

-- A hint to bank an item: the reason is the detail in a sentence.
local function bankIt(detail)
  return "Bank it, " .. lowerFirst(detail), BANK_IT, detail
end

local NOTES = {
  outleveled_gear = function(very, isItemLevel, n, you)
    -- The tooltip keeps one title for all four wordings: the detail says which.
    local lead = very and "Very low " or "Low "
    if isItemLevel then
      return lead .. "item level (" .. n .. " for level " .. you .. ")", "Outleveled gear",
          gearFacts(true, n, you)
    end
    return lead .. "level gear (needs " .. n .. ", you are " .. you .. ")", "Outleveled gear",
        gearFacts(false, n, you)
  end,
  quest_abandon = function()
    return "Quest is far below you, consider abandoning it", "Outleveled quest", "Consider abandoning it"
  end,
  quest_not_worth = function()
    return "Quest is far below you, probably not worth taking", "Outleveled quest", "Probably not worth it"
  end,
  gray_worth = function(value)
    -- Only the cheapest gray keeps a dot, so it is always "the cheapest". The
    -- detail line is the reason itself, worded like the green gray's; the title
    -- says why it is not green.
    local reason = "Cheapest gray, sells for " .. value
    return reason, "Save for vendor", reason
  end,
  no_known_use = function(value)
    return "Not used for any quest or recipe, sells for " .. value, "No known use", nil
  end,
  not_your_profession = function()
    return "You don't have this profession", "Not your profession", nil
  end,
  bank_skill = function(profession, skill)
    return bankIt("Needs " .. profession .. " " .. skill)
  end,
  bank_level = function(level)
    return bankIt("Needs level " .. level)
  end,
  bank_used_from = function(profession, skill)
    return bankIt("Used from " .. profession .. " " .. skill)
  end,
  bank_quest = function(level, label)
    return "Bank it, quest needs level " .. level, BANK_IT, label or ("Needs level " .. level)
  end,
  bank_event = function(event, label)
    return "Bank it, for a " .. event .. " quest", BANK_IT,
        label and (capitalize(event) .. ": " .. label) or capitalize(event)
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
        "Outleveled " .. noun, better and ("Best for you: " .. better) or nil
  end,
  weak_bandage = function(percent, better)
    local heals = "Heals " .. percent .. "% of your health"
    return "Weak bandage, " .. heals:lower(), "Weak bandage",
        better and (heals .. "\nBest for you: " .. better) or heals
  end,
  wrong_class_reagent = function(whole)
    return whole, "Wrong class reagent", whole
  end,
  other_faction_quest = function(other)
    return "Only used by " .. other .. " quests", other .. "-only quest item", nil
  end,
  other_profession_reagent = function(professions)
    local list
    if #professions > 3 then
      list = #professions .. " professions"
    else
      list = table.concat(professions, ", ")
    end
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
    return "Quest completed", label
  end,
  quests_completed = function(count)
    return "All " .. count .. " quests completed"
  end,
  vendor_reagent = function(professions)
    -- professions is the list that uses it, or nil when only the skill lines are known.
    if not professions then return "Vendor reagent" end
    if #professions >= 3 then return "Vendor reagent (" .. #professions .. " professions)" end
    return "Vendor reagent (" .. table.concat(professions, ", ") .. ")"
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
  cheapest_gray = function(valueText)
    return "Cheapest gray, " .. (valueText and ("sells for " .. valueText) or "no vendor value")
  end,
  worth_little = function(title)
    -- title is what the hint was ("Outleveled reagent"), so the green says why.
    local little = MakeSpace.Notes.WORTH_LITTLE_REASON
    return title and (title .. ", " .. little:lower()) or little
  end,
  marked = function()
    return MARKED
  end,
  outleveled_gear = function(isItemLevel, n, you)
    return gearFacts(isItemLevel, n, you)
  end,
}

--- Look up the words of a green: returns the reason and a detail (or nil).
-- @param key string  a key of GREEN_NOTES
function MakeSpace.Notes.Green(key, ...)
  return GREEN_NOTES[key](...)
end
