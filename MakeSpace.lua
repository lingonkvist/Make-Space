-- MakeSpace: entry point
-- Registers events, initialises saved variables, hooks bag frames.

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local function rescanAll()
  MakeSpace.Scanner.ScanAll()
  MakeSpace.Overlay.UpdateAll()
  -- Looting changes your bags a moment after the loot event, so the plan (and
  -- with it the marks, banner and tooltips) only becomes right on this scan.
  if MakeSpace.Scanner.HasLoot and MakeSpace.Scanner.HasLoot() then
    MakeSpace.Overlay.UpdateLoot()
  end
end

-- Bursts of events (item info arriving for a whole bag, several bag updates
-- in a row) become a single rescan a moment later.
local RESCAN_DELAY_SECONDS = 0.15
local rescanPending = false

local function rescanSoon()
  if not (C_Timer and C_Timer.After) then
    rescanAll()
    return
  end
  if rescanPending then return end
  rescanPending = true
  C_Timer.After(RESCAN_DELAY_SECONDS, function()
    rescanPending = false
    rescanAll()
  end)
end

-- A bank tab the client draws that MakeSpace did not know about: scan it.
MakeSpace.Bags.onNewBankBag = function() rescanSoon() end

-- Auctionator fills its price database while the auction house is open and nothing
-- tells us, so hook where a price is stored and rescan shortly after, once per burst.
local AUCTION_PRICES_RESCAN_DELAY_SECONDS = 2
local auctionPricesPending = false
local auctionatorHooked = false

local function auctionPricesChanged()
  if auctionPricesPending or not (C_Timer and C_Timer.After) then return end
  auctionPricesPending = true
  C_Timer.After(AUCTION_PRICES_RESCAN_DELAY_SECONDS, function()
    auctionPricesPending = false
    MakeSpace.Live.ClearCache()
    rescanAll()
  end)
end

local function hookAuctionatorPrices()
  if auctionatorHooked then return end
  local database = _G.Auctionator and _G.Auctionator.Database
  if not (database and database.SetPrice and hooksecurefunc) then return end
  if pcall(hooksecurefunc, database, "SetPrice", auctionPricesChanged) then
    auctionatorHooked = true
  end
end

local function invalidateAndRescan()
  MakeSpace.Scanner.ClearCache()
  rescanAll()
end

-- A new level changes what is outdated. The client can still report the old
-- level for a moment after the event, so the bags are scanned once more after
-- a short wait.
local LEVEL_UP_RESCAN_DELAY_SECONDS = 2
local function onPlayerLevelUp()
  invalidateAndRescan()
  if not (C_Timer and C_Timer.After) then return end
  C_Timer.After(LEVEL_UP_RESCAN_DELAY_SECONDS, invalidateAndRescan)
end

-- Loot window: read it, work out what is worth a slot, repaint. LOOT_SLOT_CLEARED
-- carries the slot just taken; the client may still report its item and Blizzard
-- re-lays the rows after the event, so repaint now and on the next frame.
-- Fast-loot addons fire a burst of these events in one frame: the first does the
-- full rescan, the rest only note it and the next-frame pass covers them.
local lootStats = { events = 0, scans = 0, lastScanMs = nil }
MakeSpace.LootStats = lootStats
local lootRepaintQueued, lootEventsWaiting = false, false

local function timedRescan()
  local started = debugprofilestop and debugprofilestop()
  rescanAll()
  lootStats.scans = lootStats.scans + 1
  if started then lootStats.lastScanMs = debugprofilestop() - started end
end

local function onLootChanged(self, clearedSlot)
  local hadLoot = MakeSpace.Scanner.HasLoot()
  MakeSpace.Scanner.RefreshLoot(clearedSlot)
  -- Gold, or a window with no items before or after: the bags did not change
  -- and there is no plan to make, so a full scan would only cost time. This is
  -- most loot windows when farming.
  if not (hadLoot or MakeSpace.Scanner.HasLoot()) then return end
  lootStats.events = lootStats.events + 1
  if not MakeSpace.Scanner.HasLoot() then
    -- Last item taken: bring the banner and button down, nothing more to lay out.
    timedRescan()
    MakeSpace.Overlay.UpdateLoot()
    return
  end
  if lootRepaintQueued then
    lootEventsWaiting = true
    return
  end
  timedRescan() -- repaints the loot window itself while loot remains
  if C_Timer and C_Timer.After then
    lootRepaintQueued = true
    C_Timer.After(0, function()
      lootRepaintQueued = false
      if lootEventsWaiting then
        lootEventsWaiting = false
        timedRescan()
      end
      MakeSpace.Overlay.UpdateLoot()
    end)
  end
end

-- The bags are never opened from here (Forever's gamepad UI blocks addon code that
-- does); the banner names what to delete. LOOT_OPENED's first argument is the
-- auto-loot flag, not a cleared slot.
local function onLootOpened(self)
  lootStats.events, lootStats.scans, lootStats.lastScanMs = 0, 0, nil
  onLootChanged(self, nil)
end

local function onLootClosed()
  local hadLoot = MakeSpace.Scanner.HasLoot()
  MakeSpace.Scanner.ClearLoot()
  -- Only a window that had items left has marks and a plan to take down.
  if hadLoot then rescanAll() end
  -- Always: the banner and the delete button come down with the window.
  MakeSpace.Overlay.UpdateLoot()
end

local function onAddonLoaded(self, addonName)
  if addonName ~= "MakeSpace" then return end

  -- Fill in anything missing, so a saved file from an older version (or one
  -- edited by hand) never leaves a nil list for the rest of the addon to trip on.
  MakeSpaceDB = MakeSpaceDB or {}
  MakeSpaceAccountDB = MakeSpaceAccountDB or {}
  MakeSpaceAccountDB.marks = MakeSpaceAccountDB.marks or {}
  MakeSpaceDB.autoOpenBags = nil -- opening the bags for loot was removed
  MakeSpaceDB.version = MakeSpaceDB.version or 1

  self:UnregisterEvent("ADDON_LOADED")
end

local function onPlayerLogin(self)
  self:RegisterEvent("BAG_UPDATE_DELAYED")
  self:RegisterEvent("PLAYER_LEVEL_UP")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  self:RegisterEvent("QUEST_TURNED_IN")
  -- Registering an event a client does not have is an error, and it would stop
  -- the rest of the setup. These two only refresh quest hints, so try them safely.
  pcall(self.RegisterEvent, self, "QUEST_ACCEPTED")
  pcall(self.RegisterEvent, self, "QUEST_REMOVED")
  self:RegisterEvent("SKILL_LINES_CHANGED")
  self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  -- A learned recipe can change the bandage the hints suggest. Tried safely: it
  -- only refreshes a hint.
  pcall(self.RegisterEvent, self, "SPELLS_CHANGED")
  self:RegisterEvent("LOOT_OPENED")
  self:RegisterEvent("LOOT_SLOT_CLEARED")
  self:RegisterEvent("LOOT_CLOSED")
  self:RegisterEvent("MERCHANT_SHOW")
  self:RegisterEvent("MERCHANT_CLOSED")
  -- The bank can only be read while it is open. Which of these a client has
  -- differs, and an unknown event must not stop the rest of the setup.
  for _, bankEvent in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
      "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
      "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" }) do
    pcall(self.RegisterEvent, self, bankEvent)
  end

  -- Hook every bag frame's Show so dots appear when bags open: the frame pool is
  -- shared, any frame can hold any bag. Includes the combined-bags frame and
  -- EllesmereUI Bags.
  for _, bagFrame in ipairs(MakeSpace.Overlay.BagWindows()) do
    bagFrame:HookScript("OnShow", rescanAll)
  end

  -- Auction prices are kept per region and faction. Without both, the
  -- addon cannot tell what a tradable item sells for, and says nothing.
  local function read(call, ...)
    local ok, value = pcall(call, ...)
    return ok and value or nil
  end
  MakeSpace.Market.Select(
    MakeSpace.Market.RegionOf(GetNormalizedRealmName and read(GetNormalizedRealmName),
      GetCurrentRegion and read(GetCurrentRegion)),
    UnitFactionGroup and read(UnitFactionGroup, "player"))

  hookAuctionatorPrices()
  -- Auctionator may load after MakeSpace, and its database is made at the first
  -- auction house visit on some builds: try again whenever the house opens.
  -- Closing it also settles prices a scan was still storing.
  pcall(self.RegisterEvent, self, "AUCTION_HOUSE_SHOW")
  pcall(self.RegisterEvent, self, "AUCTION_HOUSE_CLOSED")

  MakeSpace.Tooltip.Init()
  MakeSpace.Commands.Init()
  MakeSpace.Overlay.Init() -- <-- Registers the Baganator corner widget

  print("|cff54de7d[Make Space]|r v" .. MakeSpace.Commands.Version()
    .. " loaded. Type /makespace help for commands.")

  local okNow, now = pcall(time)
  local notice = okNow and MakeSpace.Curves.SnapshotNotice(
    MakeSpace.Curves.SnapshotAgeDays(MakeSpace.Data and MakeSpace.Data.AuctionPricesDate, now))
  if notice then print("|cff54de7d[Make Space]|r " .. notice) end
end

-- A vendor window changes which grays are green, so rescan before repainting.
local function vendorChanged(open)
  MakeSpace.Scanner.SetVendorOpen(open)
  MakeSpace.Scanner.ScanAll()
  MakeSpace.Overlay.SetVendorOpen(open)
end

local EVENT_HANDLERS = {
  ADDON_LOADED           = onAddonLoaded,
  PLAYER_LOGIN           = onPlayerLogin,
  BAG_UPDATE_DELAYED     = rescanSoon,
  GET_ITEM_INFO_RECEIVED = rescanSoon,
  PLAYER_LEVEL_UP        = onPlayerLevelUp,
  QUEST_TURNED_IN        = invalidateAndRescan,
  QUEST_ACCEPTED         = invalidateAndRescan,
  QUEST_REMOVED          = invalidateAndRescan,
  SKILL_LINES_CHANGED    = invalidateAndRescan,
  SPELLS_CHANGED         = function(self)
    -- Learning a recipe changes what every copy of it in the bags says.
    MakeSpace.Scanner.ForgetKnownRecipes()
    invalidateAndRescan(self)
  end,
  PLAYER_EQUIPMENT_CHANGED = invalidateAndRescan,
  LOOT_OPENED            = onLootOpened,
  LOOT_SLOT_CLEARED      = onLootChanged,
  LOOT_CLOSED            = onLootClosed,
  BANKFRAME_OPENED       = function()
    rescanSoon()
    -- Blizzard fills the bank panel after the event; paint once it has.
    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, function() MakeSpace.Overlay.UpdateAll() end)
    end
  end,
  AUCTION_HOUSE_SHOW     = hookAuctionatorPrices,
  AUCTION_HOUSE_CLOSED   = auctionPricesChanged,
  BANKFRAME_CLOSED       = rescanSoon,
  MERCHANT_SHOW          = function() vendorChanged(true) end,
  MERCHANT_CLOSED        = function() vendorChanged(false) end,
  PLAYERBANKSLOTS_CHANGED = rescanSoon,
  PLAYERBANKBAGSLOTS_CHANGED = rescanSoon,
  PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED = rescanSoon,
}

frame:SetScript("OnEvent", function(self, event, ...)
  local handler = EVENT_HANDLERS[event]
  if handler then handler(self, ...) end
end)
