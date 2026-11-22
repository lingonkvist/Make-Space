-- MakeSpace: the delete button on the loot window.
-- While the make-room plan has bag items to delete, a button under the loot
-- window deletes exactly those, in one click. Hovering it lists them.
-- The logic is plain functions that take their game calls as a table, so it
-- can be tested without the game.

MakeSpace = MakeSpace or {}
MakeSpace.LootButton = {}

local PREFIX = "|cff54de7d[Make Space]|r "

-- A long name is cut so the text fits the button as it is.
local BUTTON_NAME_MAX = 14

--- The button text.
-- @param count number  how many bag items it deletes
-- @param name string|nil  the item's name, used when it is the only one
function MakeSpace.LootButton.Label(count, name)
  if count == 1 and name then return "Delete " .. MakeSpace.MakeRoom.ShortName(name, BUTTON_NAME_MAX) end
  return "Delete " .. count .. (count == 1 and " item" or " items")
end

--- The hover lines: a title, then one row per item with what it sells for.
-- @param deletes table  list of { name, itemID, count, value }
-- @return table  { title = string, rows = { { left, right }, ... } }
function MakeSpace.LootButton.TooltipLines(deletes)
  local rows = {}
  for _, planned in ipairs(deletes) do
    local name = planned.name or ("item " .. tostring(planned.itemID))
    if (planned.count or 1) > 1 then name = name .. " x" .. planned.count end
    local right = (planned.value or 0) > 0 and MakeSpace.Verdict.FormatMoney(planned.value) or ""
    rows[#rows + 1] = { left = name, right = right }
  end
  return { title = "Bags full: makes room for loot", rows = rows }
end

--- Delete the planned items. Nothing is deleted unless every one still holds
-- the item and stack size it was planned for, so a bag that changed since the
-- last scan never loses something else.
-- @param deletes table  list of { bag, slot, itemID, count }
-- @param api table  { cursorHasItem, itemAt(bag, slot) -> id, count,
--                     pickup(bag, slot), delete(), clearCursor() }
-- @return number, string|nil  how many were deleted, and why it stopped
function MakeSpace.LootButton.Run(deletes, api)
  if api.cursorHasItem() then return 0, "your cursor is holding something" end
  for _, planned in ipairs(deletes) do
    local id, count = api.itemAt(planned.bag, planned.slot)
    if id ~= planned.itemID or (count or 1) ~= (planned.count or 1) then
      return 0, "your bags changed, so the list was out of date"
    end
  end
  local deleted = 0
  for _, planned in ipairs(deletes) do
    api.pickup(planned.bag, planned.slot)
    pcall(api.delete)
    if api.cursorHasItem() then
      -- The game did not take the delete: put the item back and say so.
      api.clearCursor()
      return deleted, "the game did not allow the delete"
    end
    deleted = deleted + 1
  end
  return deleted, nil
end

-- The real game calls.
local function gameApi()
  return {
    cursorHasItem = function() return CursorHasItem and CursorHasItem() end,
    itemAt = function(bag, slot)
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if not info then return nil end
      return info.itemID, info.stackCount
    end,
    pickup = function(bag, slot) C_Container.PickupContainerItem(bag, slot) end,
    delete = function() DeleteCursorItem() end,
    clearCursor = function() ClearCursor() end,
  }
end

local button
local BUTTON_WIDTH = 160

local function showTooltip(self)
  if not GameTooltip then return end
  local lines = MakeSpace.LootButton.TooltipLines(MakeSpace.Scanner.PlannedDeletes())
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(lines.title, 1, 1, 1)
  for _, row in ipairs(lines.rows) do
    GameTooltip:AddDoubleLine(row.left, row.right, 1, 0.82, 0, 1, 1, 1)
  end
  GameTooltip:Show()
end

local function onClick()
  local deletes = MakeSpace.Scanner.PlannedDeletes()
  if #deletes == 0 then return end
  local _, problem = MakeSpace.LootButton.Run(deletes, gameApi())
  if problem then print(PREFIX .. "Nothing more deleted: " .. problem .. ".") end
end

local function buttonFrame()
  if button then return button end
  if not CreateFrame then return nil end
  button = CreateFrame("Button", "MakeSpaceDeleteButton", UIParent, "UIPanelButtonTemplate")
  button:SetFrameStrata("DIALOG")
  button:SetSize(BUTTON_WIDTH, 24)
  button:SetScript("OnClick", onClick)
  button:SetScript("OnEnter", showTooltip)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  button:Hide()
  return button
end

--- Show the button under the loot window while there is something to delete,
-- hide it otherwise. Called whenever the loot window is repainted.
function MakeSpace.LootButton.Update()
  local summary = MakeSpace.Scanner.MakeRoomSummary()
  local visible = summary.active and summary.deletes > 0
      and LootFrame and LootFrame:IsShown()
  local frame = visible and buttonFrame()
  if not frame then
    if button then button:Hide() end
    return
  end
  frame:SetText(MakeSpace.LootButton.Label(summary.deletes, summary.deleteNames and summary.deleteNames[1]))
  frame:ClearAllPoints()
  frame:SetPoint("TOP", LootFrame, "BOTTOM", 0, -4)
  frame:Show()
end
