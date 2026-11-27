-- Items that are only there to be read.
--
-- Hand-kept. Each entry is an item with no use left: lore books and manuals whose
-- text is on any wiki and that nothing asks for. The value is the reason the
-- tooltip shows, kept to one short line. Safety still holds back anything a quest
-- asks for, so an entry cannot hide a quest item. Add an entry only after the
-- game data shows no use effect, no quest it starts and no hand-in for the item.

MakeSpace      = MakeSpace or {}
MakeSpace.Data = MakeSpace.Data or {}

MakeSpace.Data.ReadOnlyItems = {
  -- Rewards of A Tale Spun Around the Fire (Horde, quest 96078) and Findings for
  -- the Explorer's League (Alliance). Kin'weelay in Stranglethorn Vale also sells
  -- them for 1c. Readable text, no use effect, no quest to start.
  [270312] = "Lore only", -- Translated Tale of I'lalai
  [270313] = "Lore only", -- Tale of I'lalai in Zandali
  [272124] = "Lore only", -- Translated Tale of I'lalai (Loremaster Dibbs)
  -- Un'Goro: reward of Making Sense of It. The pylons work without the book.
  [11482] = "Reference only, pylons work without it", -- Crystal Pylon User's Manual
}
