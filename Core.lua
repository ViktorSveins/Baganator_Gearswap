local ADDON_NAME = ...

local DISPLAY_NAME = "Baganator Gearswap"
local DB_VERSION = 1

local addon = {}
_G.BaganatorGearswap = addon

local EQUIPMENT_SLOTS = {
  {id = 1, token = "HeadSlot", label = HEADSLOT, aliases = {"head", "helm", "helmet"}},
  {id = 2, token = "NeckSlot", label = NECKSLOT, aliases = {"neck", "necklace"}},
  {id = 3, token = "ShoulderSlot", label = SHOULDERSLOT, aliases = {"shoulder", "shoulders"}},
  {id = 4, token = "ShirtSlot", label = SHIRTSLOT, aliases = {"shirt"}},
  {id = 5, token = "ChestSlot", label = CHESTSLOT, aliases = {"chest", "robe"}},
  {id = 6, token = "WaistSlot", label = WAISTSLOT, aliases = {"waist", "belt"}},
  {id = 7, token = "LegsSlot", label = LEGSSLOT, aliases = {"legs", "pants"}},
  {id = 8, token = "FeetSlot", label = FEETSLOT, aliases = {"feet", "boots"}},
  {id = 9, token = "WristSlot", label = WRISTSLOT, aliases = {"wrist", "bracer", "bracers"}},
  {id = 10, token = "HandsSlot", label = HANDSSLOT, aliases = {"hands", "gloves"}},
  {id = 11, token = "Finger0Slot", label = FINGER0SLOT, aliases = {"finger1", "ring1", "finger 1", "ring 1"}},
  {id = 12, token = "Finger1Slot", label = FINGER1SLOT, aliases = {"finger2", "ring2", "finger 2", "ring 2"}},
  {id = 13, token = "Trinket0Slot", label = TRINKET0SLOT, aliases = {"trinket1", "trinket 1"}},
  {id = 14, token = "Trinket1Slot", label = TRINKET1SLOT, aliases = {"trinket2", "trinket 2"}},
  {id = 15, token = "BackSlot", label = BACKSLOT, aliases = {"back", "cloak"}},
  {id = 16, token = "MainHandSlot", label = MAINHANDSLOT, aliases = {"mainhand", "main hand", "mh", "weapon"}},
  {id = 17, token = "SecondaryHandSlot", label = SECONDARYHANDSLOT, aliases = {"offhand", "off hand", "oh", "shield"}},
  {id = 18, token = "RangedSlot", label = RANGEDSLOT, aliases = {"ranged", "relic", "wand", "thrown"}},
  {id = 19, token = "TabardSlot", label = TABARDSLOT, aliases = {"tabard"}},
}

local SLOT_BY_ID = {}
local SLOT_BY_ALIAS = {}
local SLOT_ORDER = {}

for _, slot in ipairs(EQUIPMENT_SLOTS) do
  SLOT_BY_ID[slot.id] = slot
  SLOT_BY_ALIAS[tostring(slot.id)] = slot
  SLOT_BY_ALIAS[slot.token:lower()] = slot
  SLOT_BY_ALIAS[(slot.label or slot.token):lower()] = slot
  for _, alias in ipairs(slot.aliases) do
    SLOT_BY_ALIAS[alias] = slot
  end
end

-- Follow the standard character sheet: left column top-to-bottom, right column
-- top-to-bottom, then weapons left-to-right.
SLOT_ORDER = {1, 2, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18}
local ASSIGNMENT_SLOT_ORDER = {1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18}

local INVTYPE_TO_SLOTS = {
  INVTYPE_HEAD = {[1] = true},
  INVTYPE_NECK = {[2] = true},
  INVTYPE_SHOULDER = {[3] = true},
  INVTYPE_BODY = {[4] = true},
  INVTYPE_CHEST = {[5] = true},
  INVTYPE_ROBE = {[5] = true},
  INVTYPE_WAIST = {[6] = true},
  INVTYPE_LEGS = {[7] = true},
  INVTYPE_FEET = {[8] = true},
  INVTYPE_WRIST = {[9] = true},
  INVTYPE_HAND = {[10] = true},
  INVTYPE_FINGER = {[11] = true, [12] = true},
  INVTYPE_TRINKET = {[13] = true, [14] = true},
  INVTYPE_CLOAK = {[15] = true},
  INVTYPE_WEAPON = {[16] = true, [17] = true},
  INVTYPE_SHIELD = {[17] = true},
  INVTYPE_2HWEAPON = {[16] = true},
  INVTYPE_WEAPONMAINHAND = {[16] = true},
  INVTYPE_WEAPONOFFHAND = {[17] = true},
  INVTYPE_HOLDABLE = {[17] = true},
  INVTYPE_RANGED = {[18] = true},
  INVTYPE_THROWN = {[18] = true},
  INVTYPE_RANGEDRIGHT = {[18] = true},
  INVTYPE_RELIC = {[18] = true},
  INVTYPE_TABARD = {[19] = true},
}

local BAG_IDS = {
  [Enum and Enum.BagIndex and Enum.BagIndex.Backpack or 0] = true,
  [Enum and Enum.BagIndex and Enum.BagIndex.Bag_1 or 1] = true,
  [Enum and Enum.BagIndex and Enum.BagIndex.Bag_2 or 2] = true,
  [Enum and Enum.BagIndex and Enum.BagIndex.Bag_3 or 3] = true,
  [Enum and Enum.BagIndex and Enum.BagIndex.Bag_4 or 4] = true,
}

local registeredButtons = setmetatable({}, {__mode = "k"})
local selectedSlotID = 1
local assigning = false
local cycleMode = false
local switching = false
local switchQueue = {}
local statusFrame
local assignmentFrame
local hoveredBagButton
local SelectSlot
local SetAssigning
local ShowAssignmentUI
local UpdateAssignmentUI
local UpdateButton
local SetBagHoverHighlight
local ClearBagHoverHighlight
local safeSortRegistered = false
local safeSortState
local SAFE_SORT_ID = "baganator_gearswap"

local function Message(text)
  print(LINK_FONT_COLOR:WrapTextInColorCode(DISPLAY_NAME) .. ": " .. text)
end

local function MappingKey(equipSlotID)
  return tostring(equipSlotID)
end

local function LocationKey(bagID, slotID)
  return tostring(bagID) .. ":" .. tostring(slotID)
end

local function EnsureDB()
  if type(BAGANATOR_GEARSWAP_DB) ~= "table" then
    BAGANATOR_GEARSWAP_DB = {}
  end
  BAGANATOR_GEARSWAP_DB.version = DB_VERSION
  BAGANATOR_GEARSWAP_DB.mappings = BAGANATOR_GEARSWAP_DB.mappings or {}
  BAGANATOR_GEARSWAP_DB.options = BAGANATOR_GEARSWAP_DB.options or {}
  if BAGANATOR_GEARSWAP_DB.options.showEmptySlotIcons == nil then
    BAGANATOR_GEARSWAP_DB.options.showEmptySlotIcons = true
  end
  if BAGANATOR_GEARSWAP_DB.options.showAssignedBorders == nil then
    BAGANATOR_GEARSWAP_DB.options.showAssignedBorders = true
  end
  if BAGANATOR_GEARSWAP_DB.options.autoUseSafeSort == nil then
    BAGANATOR_GEARSWAP_DB.options.autoUseSafeSort = true
  end
end

local function GetDB()
  EnsureDB()
  return BAGANATOR_GEARSWAP_DB
end

local function GetSlotIcon(equipSlotID)
  local slot = SLOT_BY_ID[equipSlotID]
  if not slot then
    return nil
  end
  return select(2, GetInventorySlotInfo(slot.token))
end

local function GetSlotLabel(equipSlotID)
  local slot = SLOT_BY_ID[equipSlotID]
  return slot and slot.label or ("Slot " .. tostring(equipSlotID))
end

local function ParseEquipSlot(text)
  if text == nil or text == "" then
    return nil
  end
  text = strtrim(text:lower():gsub("[_%-]+", " "))
  text = text:gsub("%s+", " ")
  return SLOT_BY_ALIAS[text]
end

local function BuildLocationMap()
  local result = {}
  for equipSlotIDText, location in pairs(GetDB().mappings) do
    local equipSlotID = tonumber(equipSlotIDText)
    if equipSlotID and location and location.bagID and location.slotID then
      result[LocationKey(location.bagID, location.slotID)] = equipSlotID
    end
  end
  return result
end

local function HasMappings()
  return next(GetDB().mappings) ~= nil
end

local function GetBaganatorProfile()
  if type(BAGANATOR_CONFIG) ~= "table" or type(BAGANATOR_CONFIG.Profiles) ~= "table" then
    return nil
  end
  return BAGANATOR_CONFIG.Profiles[BAGANATOR_CURRENT_PROFILE] or BAGANATOR_CONFIG.Profiles.DEFAULT
end

local function GetBaganatorSortMethod()
  local profile = GetBaganatorProfile()
  return profile and profile.sort_method or "type"
end

local function SetBaganatorSortMethod(method)
  local profile = GetBaganatorProfile()
  if not profile then
    return false
  end
  if profile.sort_method == method then
    return true
  end
  profile.sort_method = method
  if Baganator and Baganator.CallbackRegistry then
    Baganator.CallbackRegistry:TriggerEvent("SettingChanged", "sort_method")
  end
  return true
end

local function UpdateSafeSortSelection()
  local db = GetDB()
  if not db.options.autoUseSafeSort or not safeSortRegistered then
    return
  end

  if HasMappings() then
    local current = GetBaganatorSortMethod()
    if current and current ~= SAFE_SORT_ID then
      db.options.previousSortMethod = current
      if SetBaganatorSortMethod(SAFE_SORT_ID) then
        Message("Baganator sort method set to Gearswap-safe.")
      end
    end
  elseif db.options.previousSortMethod then
    local previous = db.options.previousSortMethod
    db.options.previousSortMethod = nil
    if GetBaganatorSortMethod() == SAFE_SORT_ID and SetBaganatorSortMethod(previous) then
      Message("Baganator sort method restored to " .. previous .. ".")
    end
  end
end

local function GetNextUnassignedSlotID(afterSlotID)
  local startIndex = 1
  for index, slotID in ipairs(ASSIGNMENT_SLOT_ORDER) do
    if slotID == afterSlotID then
      startIndex = index + 1
      break
    end
  end

  for offset = 0, #ASSIGNMENT_SLOT_ORDER - 1 do
    local index = ((startIndex + offset - 1) % #ASSIGNMENT_SLOT_ORDER) + 1
    local slotID = ASSIGNMENT_SLOT_ORDER[index]
    if GetDB().mappings[MappingKey(slotID)] == nil then
      return slotID
    end
  end
end

local function IsBagSlotButton(button)
  if not button or not button.GetParent or not button.GetID then
    return false
  end
  local parent = button:GetParent()
  if not parent or not parent.GetID then
    return false
  end
  local bagID = parent:GetID()
  local slotID = button:GetID()
  return BAG_IDS[bagID] == true and type(slotID) == "number" and slotID >= 1
end

local function GetButtonLocation(button)
  if not IsBagSlotButton(button) then
    return nil, nil
  end
  return button:GetParent():GetID(), button:GetID()
end

local function CreateBorder(button)
  local border = CreateFrame("Frame", nil, button)
  border:SetAllPoints(button.icon or button)
  border:SetFrameLevel(button:GetFrameLevel() + 8)
  border:Hide()

  local function Line(point1, point2, width, height)
    local texture = border:CreateTexture(nil, "OVERLAY")
    texture:SetColorTexture(0.1, 0.75, 1, 0.95)
    texture:SetPoint(point1)
    texture:SetPoint(point2)
    texture:SetSize(width, height)
    return texture
  end

  border.top = Line("TOPLEFT", "TOPRIGHT", 0, 2)
  border.bottom = Line("BOTTOMLEFT", "BOTTOMRIGHT", 0, 2)
  border.left = Line("TOPLEFT", "BOTTOMLEFT", 2, 0)
  border.right = Line("TOPRIGHT", "BOTTOMRIGHT", 2, 0)
  return border
end

local function EnsureButtonOverlay(button)
  if button.BaganatorGearswap then
    return
  end

  local overlayParent = button.icon or button
  local emptyIcon = button:CreateTexture(nil, "ARTWORK", nil, 2)
  emptyIcon:SetAllPoints(overlayParent)
  emptyIcon:SetAlpha(0.45)
  emptyIcon:Hide()

  local badge = button:CreateTexture(nil, "OVERLAY", nil, 7)
  badge:SetSize(15, 15)
  badge:SetPoint("BOTTOMRIGHT", overlayParent, "BOTTOMRIGHT", -1, 1)
  badge:SetAlpha(0.95)
  badge:Hide()

  local capture = CreateFrame("Button", nil, button)
  capture:SetAllPoints(overlayParent)
  capture:SetFrameLevel(button:GetFrameLevel() + 10)
  capture:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  capture:EnableMouse(false)
  capture:Hide()

  capture:SetScript("OnClick", function(_, mouseButton)
    local bagID, slotID = GetButtonLocation(button)
    if not bagID then
      return
    end

    if mouseButton == "RightButton" then
      addon.ClearLocation(bagID, slotID)
    else
      addon.AssignSlot(selectedSlotID, bagID, slotID)
      if cycleMode then
        local nextSlotID = GetNextUnassignedSlotID(selectedSlotID)
        if nextSlotID then
          SelectSlot(nextSlotID)
          SetAssigning(true)
        else
          Message("Cycle assignment complete.")
        end
      end
    end
  end)

  capture:SetScript("OnEnter", function()
    local bagID, slotID = GetButtonLocation(button)
    if bagID then
      if assignmentFrame then
        assignmentFrame.hint:SetText("Left-click: assign " .. GetSlotLabel(selectedSlotID))
        assignmentFrame.clearHint:SetText("Right-click: clear bag slot")
        assignmentFrame.mappedCountText:SetText("Bag " .. bagID .. ", slot " .. slotID)
      end
      SetBagHoverHighlight(button)
    end
    GameTooltip:Hide()
    capture:SetScript("OnUpdate", function()
      GameTooltip:Hide()
    end)
  end)
  capture:SetScript("OnLeave", function()
    capture:SetScript("OnUpdate", nil)
    GameTooltip:Hide()
    ClearBagHoverHighlight(button)
    UpdateAssignmentUI()
  end)

  button.BaganatorGearswap = {
    emptyIcon = emptyIcon,
    badge = badge,
    border = CreateBorder(button),
    capture = capture,
  }
end

function UpdateButton(button)
  if not button or not button.BaganatorGearswap then
    return
  end

  local ui = button.BaganatorGearswap
  ui.emptyIcon:Hide()
  ui.badge:Hide()
  ui.border:Hide()
  ui.capture:Hide()
  ui.capture:EnableMouse(false)

  local bagID, slotID = GetButtonLocation(button)
  if not bagID then
    return
  end

  if assigning then
    ui.capture:Show()
    ui.capture:EnableMouse(true)
  end

  local equipSlotID = BuildLocationMap()[LocationKey(bagID, slotID)]
  if not equipSlotID then
    if hoveredBagButton == button then
      ui.border:Show()
    end
    return
  end

  local icon = GetSlotIcon(equipSlotID)
  local hasItem = button.BGR and button.BGR.itemID ~= nil
  if not hasItem then
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    hasItem = info and info.itemID ~= nil
  end

  if GetDB().options.showAssignedBorders then
    ui.border:Show()
  end

  if hasItem then
    ui.badge:SetTexture(icon)
    ui.badge:Show()
  elseif GetDB().options.showEmptySlotIcons then
    ui.emptyIcon:SetTexture(icon)
    ui.emptyIcon:Show()
  end

  if hoveredBagButton == button then
    ui.border:Show()
  end
end

function SetBagHoverHighlight(button)
  if hoveredBagButton and hoveredBagButton ~= button then
    local previousButton = hoveredBagButton
    hoveredBagButton = nil
    UpdateButton(previousButton)
  end

  hoveredBagButton = button
  if button and button.BaganatorGearswap then
    button.BaganatorGearswap.border:Show()
  end
end

function ClearBagHoverHighlight(button)
  if hoveredBagButton ~= button then
    return
  end

  hoveredBagButton = nil
  UpdateButton(button)
end

local function RefreshButtons()
  for button in pairs(registeredButtons) do
    UpdateButton(button)
  end
  if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
    Baganator.API.RequestItemButtonsRefresh({Baganator.Constants.RefreshReason.ItemWidgets})
  end
end

local function HookButton(button)
  if registeredButtons[button] then
    return
  end
  registeredButtons[button] = true
  EnsureButtonOverlay(button)

  if button.SetItemDetails and not button.BaganatorGearswapHooked then
    hooksecurefunc(button, "SetItemDetails", function(hookedButton)
      UpdateButton(hookedButton)
    end)
    button:HookScript("OnShow", function(hookedButton)
      UpdateButton(hookedButton)
    end)
    button.BaganatorGearswapHooked = true
  end

  UpdateButton(button)
end

function addon.AssignSlot(equipSlotID, bagID, slotID)
  if not SLOT_BY_ID[equipSlotID] then
    Message("Unknown equipment slot.")
    return
  end
  if not BAG_IDS[bagID] then
    Message("Only backpack and equipped bag slots can be assigned.")
    return
  end
  if slotID < 1 or slotID > C_Container.GetContainerNumSlots(bagID) then
    Message("That bag slot doesn't exist.")
    return
  end

  local db = GetDB()
  for slotKey, location in pairs(db.mappings) do
    if tonumber(slotKey) ~= equipSlotID and location.bagID == bagID and location.slotID == slotID then
      db.mappings[slotKey] = nil
    end
  end
  db.mappings[MappingKey(equipSlotID)] = {bagID = bagID, slotID = slotID}
  Message(GetSlotLabel(equipSlotID) .. " assigned to bag " .. bagID .. ", slot " .. slotID .. ".")
  UpdateSafeSortSelection()
  RefreshButtons()
end

function addon.ClearSlot(equipSlotID)
  if GetDB().mappings[MappingKey(equipSlotID)] then
    GetDB().mappings[MappingKey(equipSlotID)] = nil
    Message(GetSlotLabel(equipSlotID) .. " mapping cleared.")
    UpdateSafeSortSelection()
    RefreshButtons()
  end
end

function addon.ClearLocation(bagID, slotID)
  local removed = false
  for slotKey, location in pairs(GetDB().mappings) do
    if location.bagID == bagID and location.slotID == slotID then
      GetDB().mappings[slotKey] = nil
      removed = true
    end
  end
  if removed then
    Message("Mapping cleared from bag " .. bagID .. ", slot " .. slotID .. ".")
    UpdateSafeSortSelection()
    RefreshButtons()
  end
end

function SetAssigning(state)
  local changed = assigning ~= state
  assigning = state
  if UpdateAssignmentUI then
    UpdateAssignmentUI()
  end
  if changed then
    Message(assigning and ("Assignment mode: click a Baganator bag slot for " .. GetSlotLabel(selectedSlotID) .. ".") or "Assignment mode off.")
  end
  RefreshButtons()
end

function SelectSlot(equipSlotID)
  if not SLOT_BY_ID[equipSlotID] then
    return
  end
  selectedSlotID = equipSlotID
  if UpdateAssignmentUI then
    UpdateAssignmentUI()
  end
  if assigning then
    Message("Now assigning " .. GetSlotLabel(selectedSlotID) .. ".")
  end
end

local function SelectNextSlot(delta)
  local index = 1
  for i, slotID in ipairs(ASSIGNMENT_SLOT_ORDER) do
    if slotID == selectedSlotID then
      index = i
      break
    end
  end
  index = index + delta
  if index < 1 then
    index = #ASSIGNMENT_SLOT_ORDER
  elseif index > #ASSIGNMENT_SLOT_ORDER then
    index = 1
  end
  SelectSlot(ASSIGNMENT_SLOT_ORDER[index])
end

local function IsLocationLocked(location)
  if location.bagID then
    local info = C_Container.GetContainerItemInfo(location.bagID, location.slotID)
    return info and info.isLocked
  elseif IsInventoryItemLocked then
    return IsInventoryItemLocked(location.equipSlotID)
  end
  return false
end

local function IsCompatible(equipSlotID, itemLink)
  if not itemLink then
    return false, "missing item link"
  end
  if IsEquippableItem and not IsEquippableItem(itemLink) then
    return false, "item is not equippable"
  end
  local invType = select(4, C_Item.GetItemInfoInstant(itemLink))
  if invType and INVTYPE_TO_SLOTS[invType] and not INVTYPE_TO_SLOTS[invType][equipSlotID] then
    return false, "item is for a different equipment slot"
  end
  return true
end

local function IsTwoHander(itemLink)
  return itemLink and select(4, C_Item.GetItemInfoInstant(itemLink)) == "INVTYPE_2HWEAPON"
end

local function GetContainerItemLinkSafe(bagID, slotID)
  if C_Container and C_Container.GetContainerItemLink then
    return C_Container.GetContainerItemLink(bagID, slotID)
  end
  return GetContainerItemLink(bagID, slotID)
end

local function GetContainerItemInfoSafe(bagID, slotID)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if info then
      return info
    end
  end

  local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bagID, slotID)
  if not itemID and link then
    itemID = tonumber(link:match("item:(%d+)"))
  end
  return {
    iconFileID = texture,
    stackCount = count,
    isLocked = locked,
    quality = quality,
    isReadable = readable,
    hasLoot = lootable,
    hyperlink = link,
    isFiltered = isFiltered,
    hasNoValue = noValue,
    itemID = itemID,
  }
end

local function PickupContainerItemSafe(bagID, slotID)
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bagID, slotID)
  else
    PickupContainerItem(bagID, slotID)
  end
end

local function GetContainerItemGUIDSafe(bagID, slotID)
  if ItemLocation and C_Item and C_Item.GetItemGUID then
    local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if location and C_Item.DoesItemExist(location) then
      return C_Item.GetItemGUID(location)
    end
  end
end

local function CompareSortValues(a, b)
  if a == b then
    return nil
  elseif a == nil then
    return false
  elseif b == nil then
    return true
  elseif type(a) == "string" and type(b) == "string" then
    return a < b
  else
    return a < b
  end
end

local function BuildSafeSortItem(bagID, slotID, originalIndex)
  local info = GetContainerItemInfoSafe(bagID, slotID)
  if not info or not info.itemID then
    return nil
  end

  local itemLink = info.hyperlink or GetContainerItemLinkSafe(bagID, slotID)
  local guid = GetContainerItemGUIDSafe(bagID, slotID)
  if not guid then
    return nil, "item GUIDs are unavailable"
  end

  local itemName, _, quality, itemLevel = GetItemInfo(itemLink or info.itemID)
  local classID, subClassID = select(6, C_Item.GetItemInfoInstant(itemLink or info.itemID))
  local invType = C_Item.GetItemInventoryTypeByID(info.itemID) or 0

  return {
    bagID = bagID,
    slotID = slotID,
    guid = guid,
    itemID = info.itemID,
    itemLink = itemLink,
    originalIndex = originalIndex,
    priority = info.itemID == 6948 and 0 or 1000,
    classID = classID or 999,
    invType = invType,
    subClassID = subClassID or 999,
    quality = -(quality or 0),
    itemLevel = -(itemLevel or 0),
    itemName = (itemName or itemLink or tostring(info.itemID)):lower(),
  }
end

local function SortSafeSortItems(items, isReverse)
  table.sort(items, function(a, b)
    local keys = {"priority", "classID", "invType", "subClassID", "quality", "itemLevel", "itemName", "itemID", "originalIndex"}
    for _, key in ipairs(keys) do
      local result = CompareSortValues(a[key], b[key])
      if result ~= nil then
        if isReverse then
          return not result
        end
        return result
      end
    end
    return false
  end)
end

local function BuildSafeSortState(isReverse)
  local assignedLocations = BuildLocationMap()
  local locations = {}
  local items = {}
  local skippedAssigned = 0
  local skippedUnidentifiable = 0

  for bagID in pairs(BAG_IDS) do
    local numSlots = C_Container.GetContainerNumSlots(bagID)
    for slotID = 1, numSlots do
      local key = LocationKey(bagID, slotID)
      if assignedLocations[key] then
        skippedAssigned = skippedAssigned + 1
      else
        local location = {bagID = bagID, slotID = slotID, key = key}
        local item, reason = BuildSafeSortItem(bagID, slotID, #locations + 1)
        if item then
          table.insert(locations, location)
          table.insert(items, item)
        elseif reason then
          skippedUnidentifiable = skippedUnidentifiable + 1
        else
          table.insert(locations, location)
        end
      end
    end
  end

  table.sort(locations, function(a, b)
    if a.bagID == b.bagID then
      return isReverse and a.slotID > b.slotID or a.slotID < b.slotID
    end
    return isReverse and a.bagID > b.bagID or a.bagID < b.bagID
  end)
  SortSafeSortItems(items, isReverse)

  local desiredByLocation = {}
  for index, item in ipairs(items) do
    desiredByLocation[locations[index].key] = item.guid
  end

  return {
    locations = locations,
    desiredByLocation = desiredByLocation,
    skippedAssigned = skippedAssigned,
    skippedUnidentifiable = skippedUnidentifiable,
    started = GetTime(),
    moves = 0,
  }
end

local function ScanSafeSortLocations(state)
  local currentByLocation = {}
  local locationByGUID = {}
  local emptyLocations = {}

  for _, location in ipairs(state.locations) do
    local info = GetContainerItemInfoSafe(location.bagID, location.slotID)
    if info and info.isLocked then
      return nil, nil, nil, true
    end
    if info and info.itemID then
      local guid = GetContainerItemGUIDSafe(location.bagID, location.slotID)
      if guid then
        currentByLocation[location.key] = guid
        locationByGUID[guid] = location
      end
    else
      table.insert(emptyLocations, location)
    end
  end

  return currentByLocation, locationByGUID, emptyLocations, false
end

local function ContinueSafeSort()
  local state = safeSortState
  if not state then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    safeSortState = nil
    Message("Gearswap-safe sort stopped: combat lockdown.")
    return
  end
  if CursorHasItem and CursorHasItem() then
    safeSortState = nil
    Message("Gearswap-safe sort stopped: cursor is holding an item.")
    return
  end
  if GetTime() - state.started > 15 then
    safeSortState = nil
    Message("Gearswap-safe sort stopped: timed out waiting for bag moves.")
    return
  end

  local currentByLocation, locationByGUID, emptyLocations, locked = ScanSafeSortLocations(state)
  if locked then
    C_Timer.After(0.15, ContinueSafeSort)
    return
  end

  for _, location in ipairs(state.locations) do
    local currentGUID = currentByLocation[location.key]
    local desiredGUID = state.desiredByLocation[location.key]
    if currentGUID ~= desiredGUID then
      local source
      if desiredGUID then
        source = locationByGUID[desiredGUID]
      elseif #emptyLocations > 0 then
        source = location
        location = emptyLocations[1]
      end

      if not source then
        safeSortState = nil
        Message("Gearswap-safe sort stopped: an item moved unexpectedly.")
        return
      end

      ClearCursor()
      PickupContainerItemSafe(source.bagID, source.slotID)
      PickupContainerItemSafe(location.bagID, location.slotID)
      ClearCursor()

      state.moves = state.moves + 1
      C_Timer.After(0.2, ContinueSafeSort)
      return
    end
  end

  safeSortState = nil
  local details = state.skippedAssigned .. " assigned slot" .. (state.skippedAssigned == 1 and "" or "s") .. " preserved."
  if state.skippedUnidentifiable > 0 then
    details = details .. " " .. state.skippedUnidentifiable .. " item(s) were left in place because no item GUID was available."
  end
  Message("Gearswap-safe sort complete; " .. details)
  RefreshButtons()
end

function addon.SortBagsPreservingAssignments(isReverse)
  if safeSortState then
    Message("Gearswap-safe sort is already running.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    Message("Cannot sort bags in combat.")
    return
  end
  if CursorHasItem and CursorHasItem() then
    Message("Cannot sort bags while the cursor is holding an item.")
    return
  end

  safeSortState = BuildSafeSortState(isReverse)
  if safeSortState.skippedAssigned == 0 then
    Message("Gearswap-safe sort running with no assigned slots to preserve.")
  end
  ContinueSafeSort()
end

local function BuildSwitchQueue()
  local queue = {}
  local offhandRoutedForTwoHander = false
  for _, equipSlotID in ipairs(SLOT_ORDER) do
    local location = GetDB().mappings[MappingKey(equipSlotID)]
    if location then
      local bagID, slotID = location.bagID, location.slotID
      if BAG_IDS[bagID] and slotID >= 1 and slotID <= C_Container.GetContainerNumSlots(bagID) then
        local info = C_Container.GetContainerItemInfo(bagID, slotID)
        if info and info.itemID and not info.isLocked then
          local itemLink = info.hyperlink or GetContainerItemLinkSafe(bagID, slotID)
          local ok, reason = IsCompatible(equipSlotID, itemLink)
          if ok then
            if equipSlotID == 16 and IsTwoHander(itemLink) and GetInventoryItemID("player", 17) and not offhandRoutedForTwoHander then
              local offhandLocation = GetDB().mappings[MappingKey(17)]
              local offhandDestinationInfo = offhandLocation and C_Container.GetContainerItemInfo(offhandLocation.bagID, offhandLocation.slotID)
              if offhandLocation and BAG_IDS[offhandLocation.bagID] and offhandLocation.slotID >= 1 and
                  offhandLocation.slotID <= C_Container.GetContainerNumSlots(offhandLocation.bagID) and
                  (not offhandDestinationInfo or offhandDestinationInfo.itemID == nil) then
                table.insert(queue, {
                  kind = "unequip",
                  equipSlotID = 17,
                  bagID = offhandLocation.bagID,
                  slotID = offhandLocation.slotID,
                })
                offhandRoutedForTwoHander = true
              else
                Message("Skipping " .. GetSlotLabel(equipSlotID) .. ": current offhand needs an empty assigned offhand bag slot.")
                ok = false
              end
            end
            if ok then
              table.insert(queue, {kind = "swap", equipSlotID = equipSlotID, bagID = bagID, slotID = slotID, itemLink = itemLink})
            end
          else
            Message("Skipping " .. GetSlotLabel(equipSlotID) .. ": " .. reason .. ".")
          end
        end
      end
    end
  end
  return queue
end

local function FinishSwitch(message)
  switching = false
  switchQueue = {}
  if statusFrame then
    statusFrame:SetScript("OnUpdate", nil)
  end
  if message then
    Message(message)
  end
  RefreshButtons()
end

local function ContinueSwitch()
  if not switching then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    FinishSwitch("Gear switch stopped: combat lockdown.")
    return
  end
  if CursorHasItem and CursorHasItem() then
    FinishSwitch("Gear switch stopped: cursor is holding an item.")
    return
  end

  local op = table.remove(switchQueue, 1)
  if not op then
    FinishSwitch("Gear switch complete.")
    return
  end

  if IsLocationLocked({bagID = op.bagID, slotID = op.slotID}) or IsLocationLocked({equipSlotID = op.equipSlotID}) then
    table.insert(switchQueue, 1, op)
    C_Timer.After(0.15, ContinueSwitch)
    return
  end

  if op.kind == "unequip" then
    local destinationInfo = C_Container.GetContainerItemInfo(op.bagID, op.slotID)
    if destinationInfo and destinationInfo.itemID then
      FinishSwitch("Gear switch stopped: assigned " .. GetSlotLabel(op.equipSlotID) .. " bag slot is no longer empty.")
      return
    end

    if not GetInventoryItemID("player", op.equipSlotID) then
      C_Timer.After(0.05, ContinueSwitch)
      return
    end

    ClearCursor()
    PickupInventoryItem(op.equipSlotID)
    if CursorHasItem() then
      C_Container.PickupContainerItem(op.bagID, op.slotID)
    end

    if CursorHasItem() then
      FinishSwitch("Gear switch stopped: couldn't place " .. GetSlotLabel(op.equipSlotID) .. " in its assigned bag slot.")
      return
    end

    C_Timer.After(0.25, ContinueSwitch)
    return
  end

  local info = C_Container.GetContainerItemInfo(op.bagID, op.slotID)
  if not info or not info.itemID then
    C_Timer.After(0.05, ContinueSwitch)
    return
  end

  ClearCursor()
  C_Container.PickupContainerItem(op.bagID, op.slotID)
  if not CursorHasItem() then
    Message("Skipping " .. GetSlotLabel(op.equipSlotID) .. ": item could not be picked up.")
    C_Timer.After(0.05, ContinueSwitch)
    return
  end

  PickupInventoryItem(op.equipSlotID)
  if CursorHasItem() then
    C_Container.PickupContainerItem(op.bagID, op.slotID)
  end

  if CursorHasItem() then
    FinishSwitch("Gear switch stopped: couldn't place swapped item back in its bag slot.")
    return
  end

  C_Timer.After(0.25, ContinueSwitch)
end

function addon.Switch()
  if switching then
    Message("Gear switch is already running.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    Message("Cannot switch gear in combat.")
    return
  end
  if CursorHasItem and CursorHasItem() then
    Message("Cannot switch gear while the cursor is holding an item.")
    return
  end

  switchQueue = BuildSwitchQueue()
  if #switchQueue == 0 then
    Message("No mapped bag slots currently contain switchable gear.")
    return
  end

  switching = true
  ContinueSwitch()
end

local function PrintMappings()
  local any = false
  for _, equipSlotID in ipairs(SLOT_ORDER) do
    local location = GetDB().mappings[MappingKey(equipSlotID)]
    if location then
      any = true
      Message(GetSlotLabel(equipSlotID) .. " -> bag " .. location.bagID .. ", slot " .. location.slotID)
    end
  end
  if not any then
    Message("No mappings configured.")
  end
end

local function PrintHelp()
  Message("/bgswap assign - open assignment mode")
  Message("/bgswap swap - swap gear from assigned bag slots")
  Message("/bgswap clear - clear all assigned slots")
end

local function HighlightBagLocation(bagID, slotID)
  for button in pairs(registeredButtons) do
    local buttonBagID, buttonSlotID = GetButtonLocation(button)
    if buttonBagID == bagID and buttonSlotID == slotID and button.BaganatorGearswap then
      button.BaganatorGearswap.border:Show()
    end
  end
end

local function CreateSlotButton(parent, equipSlotID, point, relativeTo, relativePoint, x, y)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(42, 42)
  button:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
  button.equipSlotID = equipSlotID

  button.bg = button:CreateTexture(nil, "BACKGROUND")
  button.bg:SetAllPoints()
  button.bg:SetTexture("Interface\\Buttons\\UI-Quickslot2")

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 5, -5)
  button.icon:SetPoint("BOTTOMRIGHT", -5, 5)
  button.icon:SetTexture(GetSlotIcon(equipSlotID))
  button.icon:SetDesaturated(true)
  button.icon:SetAlpha(0.8)

  button.selection = button:CreateTexture(nil, "OVERLAY")
  button.selection:SetAllPoints()
  button.selection:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  button.selection:SetBlendMode("ADD")
  button.selection:Hide()

  button.mapped = button:CreateTexture(nil, "OVERLAY")
  button.mapped:SetPoint("BOTTOMRIGHT", -1, 1)
  button.mapped:SetSize(15, 15)
  button.mapped:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  button.mapped:Hide()

  button.hoverLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.hoverLabel:SetPoint("BOTTOM", button, "TOP", 0, 2)
  button.hoverLabel:SetText(GetSlotLabel(equipSlotID))
  button.hoverLabel:Hide()

  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      addon.ClearSlot(equipSlotID)
      UpdateAssignmentUI()
      return
    end

    SelectSlot(equipSlotID)
    SetAssigning(true)
  end)
  button:SetScript("OnEnter", function(self)
    local mapping = GetDB().mappings[MappingKey(equipSlotID)]
    self.hoverLabel:Show()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(GetSlotLabel(equipSlotID))
    if mapping then
      GameTooltip:AddLine("Mapped to bag " .. mapping.bagID .. ", slot " .. mapping.slotID, 0.6, 0.8, 1)
      HighlightBagLocation(mapping.bagID, mapping.slotID)
    else
      GameTooltip:AddLine("Not mapped", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Left-click to assign this equipment slot", 1, 1, 1)
    GameTooltip:AddLine("Right-click to clear this equipment slot", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    button.hoverLabel:Hide()
    GameTooltip:Hide()
    RefreshButtons()
  end)

  return button
end

local function CreateAssignmentFrame()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local frame = CreateFrame("Frame", "BaganatorGearswapAssignmentFrame", UIParent, template)
  frame:SetSize(386, 390)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = {left = 8, right = 8, top = 8, bottom = 8},
    })
  end

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText(DISPLAY_NAME)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)
  frame:SetScript("OnShow", function()
    SetAssigning(true)
  end)
  frame:SetScript("OnHide", function()
    SetAssigning(false)
  end)
  table.insert(UISpecialFrames, frame:GetName())

  local bodyAnchor = CreateFrame("Frame", nil, frame)
  bodyAnchor:SetSize(1, 1)
  bodyAnchor:SetPoint("TOP", frame, "TOP", 0, -202)

  local centerPanel = CreateFrame("Frame", nil, frame, template)
  centerPanel:SetSize(172, 156)
  centerPanel:SetPoint("CENTER", bodyAnchor, "CENTER", 0, 0)
  if centerPanel.SetBackdrop then
    centerPanel:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      tile = true,
      tileSize = 16,
      insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    centerPanel:SetBackdropColor(0, 0, 0, 0.45)
  end

  local hint = centerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOP", 0, -14)
  hint:SetWidth(150)
  hint:SetJustifyH("CENTER")
  hint:SetText("Select gear, then click a bag slot.")
  frame.hint = hint

  local clearHint = centerPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  clearHint:SetPoint("TOP", hint, "BOTTOM", 0, -7)
  clearHint:SetText("right-click icon to clear")
  frame.clearHint = clearHint

  frame.selectedText = centerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.selectedText:SetPoint("TOP", clearHint, "BOTTOM", 0, -14)
  frame.selectedText:SetWidth(150)
  frame.selectedText:SetJustifyH("CENTER")

  frame.mappedCountText = centerPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.mappedCountText:SetPoint("TOP", frame.selectedText, "BOTTOM", 0, -5)
  frame.mappedCountText:SetWidth(150)
  frame.mappedCountText:SetJustifyH("CENTER")

  frame.slotButtons = {}
  local function Add(equipSlotID, angleDegrees)
    local angle = math.rad(angleDegrees)
    local radius = 140
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    frame.slotButtons[equipSlotID] = CreateSlotButton(frame, equipSlotID, "CENTER", bodyAnchor, "CENTER", x, y)
  end

  for index, equipSlotID in ipairs(ASSIGNMENT_SLOT_ORDER) do
    Add(equipSlotID, 90 - ((index - 1) * 360 / #ASSIGNMENT_SLOT_ORDER))
  end

  local cycleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  cycleButton:SetSize(92, 22)
  cycleButton:SetPoint("TOP", frame.mappedCountText, "BOTTOM", 0, -14)
  cycleButton:SetText("Cycle: Off")
  cycleButton:SetScript("OnClick", function()
    cycleMode = not cycleMode
    UpdateAssignmentUI()
    Message("Cycle assignment " .. (cycleMode and "enabled." or "disabled."))
  end)
  frame.cycleButton = cycleButton

  return frame
end

function UpdateAssignmentUI()
  if not assignmentFrame then
    return
  end

  assignmentFrame.cycleButton:SetText(cycleMode and "Cycle: On" or "Cycle: Off")
  assignmentFrame.hint:SetText(assigning and "Click bag slot to assign." or "Select gear, then click a bag slot.")
  assignmentFrame.clearHint:SetText("right-click icon to clear")
  assignmentFrame.selectedText:SetText((assigning and "Assigning: " or "Selected: ") .. GetSlotLabel(selectedSlotID))

  local mappedCount = 0
  for _, equipSlotID in ipairs(ASSIGNMENT_SLOT_ORDER) do
    if GetDB().mappings[MappingKey(equipSlotID)] ~= nil then
      mappedCount = mappedCount + 1
    end
  end
  assignmentFrame.mappedCountText:SetText(mappedCount .. " / " .. #ASSIGNMENT_SLOT_ORDER .. " mapped")

  for equipSlotID, button in pairs(assignmentFrame.slotButtons) do
    local selected = equipSlotID == selectedSlotID
    local mapped = GetDB().mappings[MappingKey(equipSlotID)] ~= nil
    button.selection:SetShown(selected)
    button.mapped:SetShown(mapped)
    button.icon:SetDesaturated(not selected and not mapped)
    button.icon:SetAlpha(selected and 1 or (mapped and 0.88 or 0.42))
  end
end

function ShowAssignmentUI()
  if not assignmentFrame then
    assignmentFrame = CreateAssignmentFrame()
  end
  if not assignmentFrame.slotButtons[selectedSlotID] then
    selectedSlotID = ASSIGNMENT_SLOT_ORDER[1]
  end
  UpdateAssignmentUI()
  assignmentFrame:Show()
end

local function SlashHandler(input)
  input = strtrim(input or "")
  local command, rest = input:match("^(%S*)%s*(.-)$")
  command = (command or ""):lower()
  rest = strtrim(rest or "")

  if command == "" or command == "help" then
    PrintHelp()
  elseif command == "swap" then
    addon.Switch()
  elseif command == "assign" then
    ShowAssignmentUI()
  elseif command == "clear" then
    GetDB().mappings = {}
    Message("All mappings cleared.")
    UpdateSafeSortSelection()
    RefreshButtons()
    UpdateAssignmentUI()
  else
    PrintHelp()
  end
end

local function RegisterBaganatorIntegration()
  if not Baganator or not Baganator.API or not Baganator.API.Skins then
    Message("Baganator API not available.")
    return
  end

  if not safeSortRegistered and Baganator.API.RegisterContainerSort and Baganator.API.Constants and Baganator.API.Constants.ContainerType then
    Baganator.API.RegisterContainerSort("Gearswap-safe", "baganator_gearswap", function(isReverse, containerType)
      if containerType == Baganator.API.Constants.ContainerType.Backpack then
        addon.SortBagsPreservingAssignments(isReverse)
      else
        Message("Gearswap-safe sorting only supports the backpack.")
      end
    end)
    safeSortRegistered = true
    UpdateSafeSortSelection()
  end

  Baganator.API.Skins.RegisterListener(function(details)
    if details.regionType == "ItemButton" and details.region then
      HookButton(details.region)
    end
  end)

  for _, details in ipairs(Baganator.API.Skins.GetAllFrames()) do
    if details.regionType == "ItemButton" and details.region then
      HookButton(details.region)
    end
  end

end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, eventName, loadedAddon)
  if eventName == "ADDON_LOADED" and loadedAddon == ADDON_NAME then
    EnsureDB()
    SLASH_BAGANATORGEARSWAP1 = "/bgswap"
    SLASH_BAGANATORGEARSWAP2 = "/baganatorgearswap"
    SlashCmdList.BAGANATORGEARSWAP = SlashHandler
  elseif eventName == "PLAYER_LOGIN" then
    statusFrame = CreateFrame("Frame")
    RegisterBaganatorIntegration()
    RefreshButtons()
  end
end)
