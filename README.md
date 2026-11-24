# Make Space

Debloat your bags. Colored dots on your bag items show what to delete, vendor, bank or keep.

Bags fill up with things you are not sure about: a quest item with no quest left, a reagent for a profession you do not have, armor your class cannot wear, a green that might be worth listing. None of it is gray, so junk addons ignore it. Make Space checks each item against your quests, professions, class, level and what it sells for, and puts a dot in the corner when it has a clear answer.

| Dot | Meaning |
|---|---|
| Green (round) | Safe to delete, or safe to vendor when it has a sell price. The tooltip says which, and why. |
| Yellow (diamond) | Worth a glance. The tooltip says what to look at. |
| None | No signal: Make Space does not know, or you still need the item. |

Hover an item for the reason. On an item with no dot, the tooltip names the quest that still needs it (unless it is more than 10 levels from acceptable) or the professions that use it. A quest item with no quest for you in the data says "Quest item, no quest found".

## What gets a dot

### Green

- Quest items whose quests are all done.
- Vendor-sold reagents for professions you do not have, and class reagents for other classes.
- Bound gear 20 or more levels below you (rare and better stay yellow). Gear with a Use effect, proc or special Equip effect is left alone.
- White armor your class cannot wear (yet), or that you have outgrown because you wear green or better in that slot.
- White weapons your class can never learn, and ammo for a class with no matching ranged weapon. Follows Forever's own skill data (rogues use axes there).
- The cheapest gray. Deleting it lights the next. At a vendor, every gray that sells lights green (its price in the tooltip).
- Trade goods that no recipe or quest uses.
- Worth very little: recipes and reagents you cannot use (or have outleveled) when the auction pays too little to list and the whole slot sells for under 50c (5c per level above 10). A missing price never counts.
- Tradable green gear (not for Enchanters) that auctions for about what a vendor pays: "Safe to vendor", with both prices shown.

### Yellow

- Bound gear 10 to 19 levels below you, and rare gear far below you.
- Tradable green gear that auctions for clearly more than a vendor: "Consider auctioning".
- Unused trade goods or a gray that sell for a fair price.
- Things to open: clams, loot bags, and lockboxes (for a rogue who can Pick Lock).
- Recipes for a profession you do not have (unbound ones).
- **Needed later:** recipes more than 25 skill points above you, and reagents more than 50 above you (25 once you have stopped leveling that profession for 6 hours). A profession counts as idle after 12 hours without a skill gain and a new play session. Also a reagent whose next use is far ahead once your skill is past an earlier one. A listed stack that costs next to nothing to buy again (about half the value where a gray stops being plain junk) gets a green instead: `Cheap to rebuy, used from Cooking 145`.
- **Outleveled reagents:** once the last recipe that uses the item (directly, or through what it is turned into) has turned green. Copper bars stay safe while bronze still needs them. A quest that wants the item does not hold the hint back; the tooltip adds a quest row instead.
- **Outleveled consumables:** food, drink, potions, elixirs, flasks and stat scrolls that need a level 10 or more below yours (15 from level 55). Food, drink and stat scrolls only when your bags hold a better one you can use. Potions say which to use instead: `Best for you: Major Healing Potion (level 45)`. Items with their own level limit, non-stat elixirs and food with an effect are left alone. A quest you could still take that wants the item is named under the hint.
- Bandages that heal under 20% of your health (`Heals 9% of your health`), with your best known bandage named when you have one.
- Mana potions, drinks and Intellect scrolls for classes that cannot use them.
- Dropped crafting materials that none of your professions use (once both primary slots are taken; not for Cooking, First Aid or Fishing materials).
- Quest items for the other faction only.
- Library books, with who to hand them in to.
- Blood Shards on a Horde character: 4 to Mangletooth for a buff.
- Items for a quest far below your level, or one you cannot accept for another 10 levels: needed later. Darkmoon Faire and holiday quest items get that hint at any level, naming the event.
- Anything you mark yellow yourself.

A tradable green loses its dot when the auction pays clearly more than a vendor, and the tooltip says why in one line (`Vendor 5c, auction up to 8s`).

### Never a dot

Anything that could still matter: reagents with a recipe use (apart from the hints above), items a quest needs or starts, profession tools, the Hearthstone, soul shards, containers, gems and keys, and ammo your class can use. Consumables get a dot only in the yellow cases above. Items you marked "No dot" never do.

## Auction prices

Make Space ships auction data for Forever, so it can tell vendor trash from gear worth listing. It never scans the auction house in game.

- **Per market.** Prices are kept per region and faction; a Horde player on EU is judged by EU Horde listings only. If your market cannot be told, tradable items get no green.
- **The price used** is the cheap end of each auction house (25th percentile), taken across the houses in your market. Lone high listings are trimmed, and gear with random suffixes (of the Eagle) is priced per version.
- **Worth a trip** when 95% of the auction price (after the cut) clears the vendor price by a margin that grows smoothly with the vendor price, plus 1s for the trip. Otherwise the green stands.
- **Enchanters** are never told to vendor green gear, since it can be disenchanted.
- **Freshness.** After 14 days a price-based green is withheld, so an outdated addon goes quiet instead of wrong. From day 8 the login message counts the days left, and `/makespace status` shows the age. Items that cannot be auctioned, and items with a fresh Auctionator price, are unaffected.
- **Refreshed with each release.** A weekly workflow opens a pull request with new prices. `tools/build_auction_prices.py` writes one file per region and faction in `data/`, because the packager skips files over 500 KB.

### With Auctionator

If you run Auctionator, Make Space uses its live prices for items it saw in the last 3 days. The tooltip then says "auction about" instead of "auction up to".

- Judged on the typical reading of the last 3 days, not the latest scan, so one lone listing never lifts the price.
- Reaches further than the snapshot: blue gear can get "Safe to vendor", and items the snapshot cannot price can be judged.
- A live price far below the snapshot (under half) is ignored unless several days agree on it, since Auctionator records the lowest listing. `/makespace why` says when this happens.
- Random-suffix items can lower the snapshot's price only to 60% of it.
- A price must belong to exactly this item, and without a snapshot price it must be from today or yesterday.
- A price 4 to 14 days old is not trusted to judge, but a clearly low one still stops a hint from suggesting the auction house.

Without Auctionator, nothing changes.

## In the bank

Dots work in the bank and warband bank. Since people bank things on purpose, a verdict stays only when it holds for any character. Anything that depends on your professions, class or quests is at most yellow, "Needed later" and vendor hints are dropped, and "Consider auctioning" stays. Grays are thinned like in your bags.

## Making room for loot

When the loot window is open and your bags cannot hold everything:

- The cheapest junk in your bags glows green, and every other dot goes quiet.
- Loot worth a slot gets a green check ("Take it"): quest items, and anything worth more than the cheapest junk.
- Other loot gets a red X ("Skip it").
- A button under the loot window (`Delete Torn Rag +1`) deletes the first glowing item per click, since the game allows one delete per click. Click again for the next. Hover it for the list and prices. Nothing is deleted if your bags changed since the last scan.
- When there is nothing to click, one line above the loot window says why.
- Deleting a glowing item yourself moves the glow to the next cheapest.

Loot and junk are weighed by vendor price, or by the auction price after its cut when Auctionator has a recent price the last few days agree on. Old, single-reading or per-version prices are not used. Soulbound items count at vendor price. Loot that joins a stack you carry needs no slot, and quiver, ammo and profession bags do not count as room.

Item links in chat get the blue info (what a crafting item is used for, which quests need it) but no verdict, since it is not your item.

## Commands

`/makespace` and `/bagwise` are the same.

- **Alt-right-click** an item in your bags: **Default**, **Safe to delete**, **Worth a glance** or **No dot**. Marks are kept account-wide.
- `/makespace mark green|yellow|none|default [item]`: the same as a command (`keep` = `mark none`, `flag` = `mark yellow`, `reset` = `mark default`). `[item]` is a shift-clicked link, an ID or a name.
- `/makespace list`: your marked items.
- `/makespace summary`: what the dots add up to, for example `9 green (2g 14s at a vendor), 5 yellow`.
- `/makespace why [item]`: why an item does or does not get a dot.
- `/makespace report`: copyable report of your bags, verdicts and setup, for bug reports.
- `/makespace loot`: what the make-room plan sees (with a loot window open).
- `/makespace status`, `bank`, `glow`: version and counts, what the bank looks like to Make Space, and a test of the delete glow.
- `/makespace tiers`: checks the potion and bandage tiers behind `Best for you` against your game.

## Compatibility

Blizzard bags and bank, Baganator (with Syndicator), EllesmereUI Bags and Bagnon. WoW Forever (Interface 16001).

## Reporting a bug

Run `/makespace report` and paste it, with the bag addon you use. For one wrong item add `/makespace why [item]`. For a missing glow add `/makespace loot` with the loot window open.

## Development

See `DESIGN.md` for the principles, the invariants and the ideas we turned down, and why.

- Tests: `python3 -I tests/run_tests.py [name]` (needs `lupa`; a name runs only matching specs). `node tools/check_globals.js` catches stray globals. CI runs both.
- `src/verdict.lua` decides and is pure. Use `Verdict.Judge` (named answer); `Evaluate` returns the same by position.
- `src/notes.lua` holds the wording of every yellow (reason, title, detail). `src/safety.lua` holds the protections that veto a green. `src/bank.lua` turns a verdict into what the bank shows.
- `src/auction.lua` joins the live price, the snapshot and the curves in `src/curves.lua`. A new price rule goes there, a new per-kind setting in `curves.lua`.
- `src/scanner.lua` is the only module that reads the game and caches verdicts. Add any new verdict input to its cache key.
- `src/overlay.lua` paints dots and glows, `src/tooltip.lua` adds hover text, `src/makeroom.lua` plans the deletes (pure), `src/lootbutton.lua` is the delete button.
- `tools/` rebuilds the data in `data/` (auction prices, reagent professions, weapon skills, locked items, consumable tiers, library books, quest availability) and the textures. Most scripts have a `--selftest`, which CI runs.
- Release: bump `## Version` in `MakeSpace.toc`, tag, and let the packager build it.

## License

Make Space is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This addon includes data derived from QuestieDB (https://github.com/Questie/QuestieDB), which is also licensed under the GPLv3.

Copyright (C) 2026 lingonkvist
