-- MakeSpace: what a verdict means once the item is in the bank.
-- People bank things on purpose, often for another character. A verdict stays as it
-- is only when it holds for any character; one that depends on this character's
-- professions, class or quests is capped at a yellow reminder; one that only says
-- what to do with an item not yet banked is dropped. Unknown rules get the cautious
-- treatment.
MakeSpace = MakeSpace or {}

local BANK_KEEPS = {
  level_gap = true,     -- soulbound, so it cannot go to an alt
  poor_quality = true,
  no_recipe_use = true, -- nothing uses it, whoever you play
  openable = true,
  marked = true, -- your own mark holds wherever the item is
}
local BANK_DROPS = {
  trivial_quest_item = true, -- you cannot abandon a quest from the bank
  other_profession_reagent = true, -- the bank is where mats for another character wait
}

-- Their greens only say "vendor it" (worth very little, or about the vendor
-- price): a hint for something already banked, and banked for a reason, so
-- the green is dropped. A yellow from the same rule is still shown.
local BANK_DROPS_GREEN = {
  sell_at_vendor = true, -- a vendor suggestion is not needed in the bank (the auction hint is)
  recipe = true,
  outleveled_reagent = true,
  distant_reagent = true,
}

-- A green whose reason is a full line (a quest and "(completed)") has no title of its
-- own, so the bank names the yellow it becomes from the rule.
local BANK_TITLES = {
  quest_objective_done = "Quest completed",
  quest_starter_done = "Quest completed",
}

--- Turn a verdict result into what the bank should show. The warband bank is for
-- sharing between characters, so nothing that depends on the item being bound is
-- kept there.
-- @param result table|nil  { verdict, reason, detail, tag, rule }
-- @param isWarband boolean|nil
-- @return table|nil  a fresh table (results are shared between slots), or the same
--   nil/empty result when there is nothing to show
function MakeSpace.Verdict.ForBank(result, isWarband)
  if not result or not result.verdict then return result end
  if result.heading and result.heading.title == MakeSpace.Notes.NEEDED_LATER_TITLE then return {} end
  if BANK_DROPS[result.rule] then return {} end
  if result.verdict == "green" and BANK_DROPS_GREEN[result.rule] then return {} end
  -- Nobody needs a vendor suggestion for something already banked.
  if BANK_KEEPS[result.rule] and not (isWarband and result.rule == "level_gap") then
    return { verdict = result.verdict, reason = result.reason, detail = result.detail,
             tag = result.tag, rule = result.rule, heading = result.heading, sellable = false,
             auctionNote = result.auctionNote, auctionNoteLive = result.auctionNoteLive }
  end
  -- A green has no heading of its own, so the yellow is named by the same
  -- words the bag shows under "Safe to delete": "Quest completed", and so on.
  return { verdict = "yellow", reason = result.reason, detail = result.detail,
           tag = result.tag, rule = result.rule,
           heading = result.heading
               or (BANK_TITLES[result.rule] and { title = BANK_TITLES[result.rule],
                   detail = result.reason ~= BANK_TITLES[result.rule] and result.reason or nil })
               or { title = result.reason },
           auctionNote = result.auctionNote, auctionNoteLive = result.auctionNoteLive }
end

