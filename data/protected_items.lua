-- Items the game data cannot tell us are in use.
--
-- Hand-kept. Each entry is an item with a real use that no recipe, quest or
-- reagent table records: new Forever mechanics, camp objects and the like.
-- Safety never lets a rule call these safe to delete, and the tooltip shows
-- the note so the dot's silence is explained. Add an entry when the trade
-- goods audit (tools/audit_trade_goods.py) turns up something that is used.

MakeSpace      = MakeSpace or {}
MakeSpace.Data = MakeSpace.Data or {}

MakeSpace.Data.ProtectedItems = {
  -- Herbalism camp items (Forever): the Greenhouse (Herbalism 140) grows herbs
  -- from seeds, the Seed Hybridizer (Herbalism 300) combines seeds into the
  -- next tier. Both are placed beside a campfire.
  [268415] = "Plant in a Greenhouse, or combine in a Seed Hybridizer", -- Commonplace Herb Seeds
  [268416] = "Plant in a Greenhouse, or combine in a Seed Hybridizer", -- Uncommon Herb Seeds
  [268417] = "Plant in a Greenhouse, or combine in a Seed Hybridizer", -- Unusual Herb Seeds
  [268418] = "Plant in a Herbalism Greenhouse (camp item)", -- Scarce Herb Seeds
  -- Artisan crates (Forever): a Waylaid Crate uses up crafted goods from one
  -- profession group and becomes a Sealed Artisan Crate, which is handed in to your
  -- faction's trade representative for the currency that buys profession recipes.
  [248549] = "Fill with crafted goods, turn in for recipes",
  [248682] = "Fill with crafted goods, turn in for recipes",
  [248683] = "Fill with crafted goods, turn in for recipes",
  [248684] = "Fill with crafted goods, turn in for recipes",
  [248685] = "Fill with crafted goods, turn in for recipes",
  [248686] = "Fill with crafted goods, turn in for recipes",
  [248687] = "Fill with crafted goods, turn in for recipes",
  [248688] = "Fill with crafted goods, turn in for recipes",
  [248689] = "Fill with crafted goods, turn in for recipes",
  [248690] = "Fill with crafted goods, turn in for recipes",
  [248691] = "Fill with crafted goods, turn in for recipes",
  [248692] = "Fill with crafted goods, turn in for recipes",
  [248693] = "Fill with crafted goods, turn in for recipes",
  [248694] = "Fill with crafted goods, turn in for recipes",
  [248695] = "Fill with crafted goods, turn in for recipes",
  [248696] = "Fill with crafted goods, turn in for recipes",
  [248697] = "Fill with crafted goods, turn in for recipes",
  [248698] = "Fill with crafted goods, turn in for recipes",
  [248699] = "Fill with crafted goods, turn in for recipes",
  [248702] = "Fill with crafted goods, turn in for recipes",
  [248703] = "Fill with crafted goods, turn in for recipes",
  [248704] = "Fill with crafted goods, turn in for recipes",
  [248705] = "Fill with crafted goods, turn in for recipes",
  [248706] = "Fill with crafted goods, turn in for recipes",
  [248707] = "Fill with crafted goods, turn in for recipes",
  [248708] = "Fill with crafted goods, turn in for recipes",
  [248709] = "Fill with crafted goods, turn in for recipes",
  [248710] = "Fill with crafted goods, turn in for recipes",
  [248711] = "Fill with crafted goods, turn in for recipes",
  [248712] = "Fill with crafted goods, turn in for recipes",
  [248713] = "Fill with crafted goods, turn in for recipes",
  [248768] = "Hand in to your faction's trade representative",
  [248773] = "Hand in to your faction's trade representative",
  [248778] = "Hand in to your faction's trade representative",
  -- Keys: a quest reward that does a job. Deleting it means going back for it.
  [9173] = "Needed to use the Gnomeregan teleporter in Booty Bay", -- Goblin Transponder
  -- Reagents whose only recipe has no skill data, so the reagent tables skip it
  -- (it would read as "starts at 1"). The recipe is still real.
  [10577]  = "Engineering item, use not found", -- Goblin Mortar
  [252948] = "Cooking ingredient, use not found", -- Forever cooking ingredient, recipe has no skill data
  -- Forever cooking ingredients no recipe in the data uses. Forever may use them
  -- somewhere the data does not reach, so no rule may call them safe.
  [247815] = "Cooking ingredient, use not found", -- Crude Fruit Pulp
  [249802] = "Cooking ingredient, use not found", -- Grainy Fruit Pulp
  [249803] = "Cooking ingredient, use not found", -- Tangy Fruit Pulp

  -- Forever secrets and the like, from a community-researched list.
  -- The rules would call some of these safe (a level 15 sword at level 60, or a
  -- gray key), so each is held back and the tooltip says what it is. Where an
  -- item is not listed, its purpose was not confirmed.
  [276561] = "Secret: use in Ambermill Town Hall", -- Black Tome
  [275989] = "Secret: use at the rune in City of Dalaran", -- Tome of Dalaran
  [276188] = "Part of the Dawn Waker secret", -- Eluvi'ana
  [282315] = "Part of the Dawn Waker secret", -- Ancient Hilt
  [272313] = "Part of the Dawn Waker secret", -- Ancient Hilt (quest item)
  [282337] = "Part of the Dawn Waker secret", -- Befouled Water Globe
  [16408] = "Part of the Dawn Waker secret", -- Befouled Water Globe (older ID)
  [282699] = "Part of the Dawn Waker secret", -- Cleansed Water Globe
  [282406] = "Opens Narassin's Strongbox (Dawn Waker secret)", -- Azsharan Key
  [282404] = "Part of the Dawn Waker secret", -- Narassin's Tome
  [282548] = "Cleansing reagent, Dawn Waker secret", -- Star of Elune
  [282547] = "Cleansing reagent, Dawn Waker secret", -- Abyssal Mote
  [282431] = "Cleansing reagent, Dawn Waker secret", -- Tears of Anguish
  [211527] = "Unroll outdoors for bonus rested XP", -- Cozy Sleeping Bag
  [216619] = "Restores lost rest time when used", -- Student Fodder
  [281350] = "Part of an unsolved Forever secret", -- Keystone Fragment
  [284092] = "Part of an unsolved Forever secret", -- Keystone Fragment
  [284093] = "Part of an unsolved Forever secret", -- Keystone Fragment
  [281358] = "Part of an unsolved Forever secret", -- Stone Key
  [271745] = "Part of an unsolved Horde secret", -- Bloody Map
  -- Found by the trade goods audit
  [11099] = "Smelts into Dark Iron Bars at the Black Forge", -- Dark Iron Ore
  [273295] = "Forever seasonal item, use unknown", -- Seasonal Fish Steaks
}
