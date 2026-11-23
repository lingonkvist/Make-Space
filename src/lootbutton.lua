-- MakeSpace: the delete button on the loot window.
-- While the make-room plan has bag items to delete, a button under the loot window
-- deletes the first of them per click (the game allows one delete per click); the
-- next click takes the next. Hovering lists them all. Game calls come in as a table
-- so the logic is testable.

MakeSpace = MakeSpace or {}
MakeSpace.LootButton = {}

local PREFIX = "|cff54de7d[Make Space]|r "

-- A long name is cut so the text fits the button as it is.
local BUTTON_NAME_MAX = 20

--- The button text: the item this click deletes, and how many more are planned.
-- @param count number  how many bag items the plan deletes
-- @param name string|nil  the first item's name
function MakeSpace.LootButton.Label(count, name)
  local text = "Delete " .. (name and MakeSpace.MakeRoom.ShortName(name, BUTTON_NAME_MAX) or "item")
  if count > 1 then text = text .. " +" .. (count - 1) end
  return text
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
  local title = #rows > 1 and "Bags full: each click deletes the top one" or "Bags full: makes room for loot"
  return { title = title, rows = rows }
end

--- Delete the first planned item, if its slot still holds the item and stack size
-- it was planned for, so a changed bag never loses something else.
-- @param deletes table  list of { bag, slot, itemID, count }
-- @param api table  { cursorHasItem, itemAt, pickup, delete, clearCursor }
-- @return number, string|nil  how many were deleted (0 or 1), and why not
function MakeSpace.LootButton.Run(deletes, api)
  local planned = deletes[1]
  if not planned then return 0, nil end
  if api.cursorHasItem() then return 0, "your cursor is holding something" end
  local id, count = api.itemAt(planned.bag, planned.slot)
  if id ~= planned.itemID or (count or 1) ~= (planned.count or 1) then
    return 0, "your bags changed, so the list was out of date"
  end
  api.pickup(planned.bag, planned.slot)
  pcall(api.delete)
  if api.cursorHasItem() then
    -- The game did not take the delete: put the item back and say so.
    api.clearCursor()
    return 0, "the game did not allow the delete"
  end
  return 1, nil
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
local BUTTON_WIDTH = 170
local MIN_BUTTON_WIDTH = BUTTON_WIDTH

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
  local _, problem = MakeSpace.LootButton.Run(deletes, gameApi())
  if problem then print(PREFIX .. "Nothing deleted: " .. problem .. ".") end
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
  local text = frame.GetFontString and frame:GetFontString()
  if text then frame:SetWidth(math.max(MIN_BUTTON_WIDTH, text:GetStringWidth() + 30)) end
  frame:ClearAllPoints()
  frame:SetPoint("TOP", LootFrame, "BOTTOM", 0, -4)
  frame:Show()
end
