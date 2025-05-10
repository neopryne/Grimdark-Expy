if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwcco = mods.lightweight_crew_change_observer
local lwsil = mods.lightweight_self_indexing_list
local lwce = mods.lightweight_crew_effects
lwce.RequestInitialization()

--local userdata_table = mods.multiverse.userdata_table
if not lwl then
    error("Lightweight Lua was not patched, or was patched after Grimdark Expy.  Install it properly or face undefined behavior.")
end

--[[
TODO give different crew types different equipment slots.  Uniques and humans get all of them.  Likely elites as well.
Humans get two slots, but they get to pick.
Cognitives get wildcard slots.

--Also note that due to how I've constructed this, items may stick around after the crew using them has died, so I need to make sure the calls don't error.
--]]

----------------------------------------------------DEFINES----------------------
local TAG = "LW Crew Equips"
local function NOOP() end
local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local TYPE_WEAPON = "Weapon"
local TYPE_ARMOR = "Armor"
local TYPE_TOOL = "Tool"
local EQUIPMENT_ICON_SIZE = 30
local GEX_CREW_ID = "GEX_crewId"
--todo a button that makes items for testing

local WEAPON_BUTTON_SUFFIX = "_weapon_button"
local ARMOR_BUTTON_SUFFIX = "_armor_button"
local TOOL_BUTTON_SUFFIX = "_tool_button"
local INVENTORY_BUTTON_PREFIX = "inventory_button_"
local NO_ITEM_SELECTED_TEXT = "--- None Selected ---"

local mEquipmentList = {}
local KEY_NUM_EQUIPS = "GEX_CURRENT_EQUIPMENT_TOTAL"
local KEY_EQUIPMENT_GENERATING_INDEX = "GEX_EQUIPMENT_GENERATING_INDEX_"
local KEY_EQUIPMENT_ASSIGNMENT = "GEX_EQUIPMENT_ASSIGNMENT_"

local mSetupFinished = false
local mCrewChangeObserver = lwcco.createCrewChangeObserver(lwl.filterOwnshipTrueCrew)
local mCrewListContainer
local mEquipmentGenerationTable = {}
local mNameToItemIndexTable = {}
local mTabbedWindow = ""
local mTab = 1
local mGlobal = Hyperspace.Global.GetInstance()
--Items must be added to this list when they are created or loaded
local mItemList = lwsil.SelfIndexingList:new()
local mCrewLineHeight = 30
local mCrewLinePadding = 10
local mCrewRowPadding = 10
local mCrewLineNameWidth = 90
local mCrewLineTextSize = 11
local mTabTop = 139
local mEquipmentTabTop = mTabTop + EQUIPMENT_ICON_SIZE
local mItemsSoldValue = 0
local mItemsSold = 0

local mDescriptionHeader
local mDescriptionTextBox
local mInventoryButtons = {}
local mScaledLocalTime = 0
local mFrameCounter = 0

local inventoryRows = 5
local inventoryColumns = 6
local persistEquipment

--local mPage = 1--used to calculate which crew are displayed in the equipment loadout slots.  basically mPage % slots per page. Or do the scrolly thing, it's easier than I thought.
local function generateStandardVisibilityFunction(tabName, subtabIndex)
    return function()
        --print(tabName, mTab, subtabIndex, mTabbedWindow)
        --return true
        return mTab == subtabIndex and mTabbedWindow == tabName
    end
end
local tabOneStandardVisibility = generateStandardVisibilityFunction(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX)

--todo maybe helper functions to build items?  idk im not happy with this yet.
local function buildItemBuilder(name, itemType, renderFunction, description, onCreate, onTick, onEquip, onRemove, onPersist, onLoad, sellValue)
    local generating_index = #mEquipmentGenerationTable + 1
    return function()
        local builtItem = lwui.buildItem(name, itemType, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE,
                tabOneStandardVisibility, renderFunction, description, onCreate, onTick, onEquip, onRemove)
        builtItem.generating_index = generating_index
        builtItem.sellValue = sellValue
        builtItem.onPersist = onPersist
        builtItem.onLoad = onLoad
        mNameToItemIndexTable[name] = generating_index
        mItemList:append(builtItem)
        --print("built item, item list now has ", mItemList.length)
        return builtItem
    end
end

------------------------------------INVENTORY FILTER FUNCTIONS----------------------------------------------------------

local function inventoryFilterFunctionAny(item)
    return true
end

local function inventoryFilterFunctionWeapon(item)
    return (item ~= nil and item.itemType == TYPE_WEAPON)
end

local function inventoryFilterFunctionArmor(item)
    return (item ~= nil and item.itemType == TYPE_ARMOR)
end

local function inventoryFilterFunctionTool(item)
    return (item ~= nil and item.itemType == TYPE_TOOL)
end

local function inventoryFilterFunctionEquipment(item)
    return inventoryFilterFunctionWeapon(item) or 
            inventoryFilterFunctionArmor(item) or inventoryFilterFunctionTool(item)
end

------------------------------------END INVENTORY FILTER FUNCTIONS----------------------------------------------------------
--Consider putting a row on top with the names of the column things.
--  Name, Weapon, Armor, Tool


------------------------------------ITEM STORAGE FUNCTIONS----------------------------------------------------------
--returns true if the item was able to be added, and false if there was no room.  Called when loading persisted inventory items or when obtaining new ones.
--todo I could make some buttons you can buy that don't get cleared upon starting a new run.  Final battle tension.
--todo Gift of Equipment, one random item, starts unlocked.  Greater boon, two random items.

local function resetPersistedValues()
    Hyperspace.metaVariables[KEY_NUM_EQUIPS] = 0
end

local function clearIButton(iButton)
    if iButton == nil then return end
    iButton.item = nil
end

local function resetInventory()
    resetPersistedValues()
    --Clear persisted values, remove all items from crew and inventory.
    for _, iButton in ipairs(mInventoryButtons) do
        clearIButton(iButton)
    end
    
    for _, crewContainer in ipairs(mCrewListContainer.objects) do
        for _, iButton in ipairs(crewContainer.objects) do
            if (iButton.className == "inventoryButton") then
                clearIButton(iButton)
            end
        end
    end
    mItemList = lwsil.SelfIndexingList:new()
    mCrewListContainer.objects = {} --todo this removes starting crew, find a better way to do whatever this is.
end

local function addToInventory(item)
    local oldSlotValue = item.assigned_slot
    for _, iButton in ipairs(mInventoryButtons) do
        if (iButton.addItem(item)) then --implicitly calls buttonAddInventory
            return true
        end
    end
    return false
end

local function iButtonTryUnequipPrevious(button, item)
    if item.assigned_slot ~= nil and item.assigned_slot >= 0 then
        --print("added from crew ", item.assigned_slot)
        local crewmem = lwl.getCrewById(item.assigned_slot)
        if crewmem then
            item.onRemove(item, crewmem)
        else
            lwl.logError(TAG, "Could not find crewmember with id "..item.assigned_slot)
        end
    end
end

local function deleteItem(button, item)
    iButtonTryUnequipPrevious(button, item)
    mItemList:remove(item._index)
    button.item = nil
    item.assigned_slot = -2 --destroyed
    persistEquipment()
end

local function trashItem(button, item) --From scrap it came, and to scrap it can return.
    Hyperspace.ships(0):ModifyScrapCount(item.sellValue, false)
    Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
    mItemsSold = mItemsSold + 1
    mItemsSoldValue = mItemsSoldValue + item.sellValue
    deleteItem(button, item)
end

local function buttonAddInventory(button, item)
    iButtonTryUnequipPrevious(button, item)
    item.assigned_slot = -1
    persistEquipment()
end

local function getCrewButton(crewId, itemType)
    for _, crewContainer in ipairs(mCrewListContainer.objects) do
        --print("checking row ", crewContainer[GEX_CREW_ID])
        if (crewContainer[GEX_CREW_ID] == crewId) then
            --print("crew found, adding ", item.name)
            for _, iButton in ipairs(crewContainer.objects) do
                --print("checking for buttons ", iButton.className)
                if (iButton.className == "inventoryButton") then--todo expose these values
                    if (iButton.itemType == itemType) then
                        return iButton
                    end
                end
            end
        end
    end
end

local function addToCrew(item, crewId) --find the button to add it to and call that.
    --print("addToCrew")
    local button = getCrewButton(crewId, item.itemType)
    return button.addItem(item)
end

local function getEquippedItem(crewId, itemType)
    local button = getCrewButton(crewId, itemType)
    return button.item
end

local function buttonAddToCrew(button, item)
    --print("buttonaddToCrew")
    iButtonTryUnequipPrevious(button, item)
    local crewmem = lwl.getCrewById(button[GEX_CREW_ID])
    --print("added ", item.name, " to ", crewmem:GetName())
    if (item.fromLoad) then --Do the unequip that should have happened when we quit the game.
        item.fromLoad = nil
        item.onRemove(item, crewmem)
    end
    item.onEquip(item, crewmem)
    item.assigned_slot = button[GEX_CREW_ID]
    if mSetupFinished then
        Hyperspace.Sounds:PlaySoundMix("upgradeSystem", -1, false)
    end
    persistEquipment()
end

local function getCrewEquipment(crewmem)
    local equipment = {}
    if not mCrewListContainer then
        --print("equipment not set up yet")
        return {}
    end
    for _, crewContainer in ipairs(mCrewListContainer.objects) do
        --print("checking row ", crewContainer[GEX_CREW_ID], "against ", crewmem.extend.selfId)
        if (crewContainer[GEX_CREW_ID] == crewmem.extend.selfId) then
            --print("crew found")
            for _, iButton in ipairs(crewContainer.objects) do
                --print("checking ", iButton.className)
                if (iButton.className == "inventoryButton") then
                    --print("item ", iButton.item)
                    if (iButton.item ~= nil) then
                        table.insert(equipment, iButton.item)
                    end
                end
            end
        end
    end
    return equipment
end

persistEquipment = function()
    local numEquipment = mItemList.length
    --print("persisting ", numEquipment, " items")
    local successes = 0
    for i=1,numEquipment do
        local equipment = mItemList:get(i)
        if (equipment.generating_index == nil) or (equipment.assigned_slot == nil) then
            lwl.logError(TAG, "Could not persist "..equipment.name..": incomplete values.")
            --print(equipment.generating_index, equipment.assigned_slot)
        else
            successes = successes + 1
            --print("persisting ", equipment.name, " genIndx ", equipment.generating_index, " slot ", equipment.assigned_slot)
            Hyperspace.metaVariables[KEY_EQUIPMENT_GENERATING_INDEX..successes] = equipment.generating_index --todo create this
            Hyperspace.metaVariables[KEY_EQUIPMENT_ASSIGNMENT..successes] = equipment.assigned_slot--todo I need to set this value properly
        end
    end
    Hyperspace.metaVariables[KEY_NUM_EQUIPS] = successes
    --print("persisted ", successes , " out of ", numEquipment)
end

local function loadPersistedEquipment()
    local numEquipment = Hyperspace.metaVariables[KEY_NUM_EQUIPS]
    --print("loading ", numEquipment, " items")
    for i=1,numEquipment do
        local generationTableIndex = Hyperspace.metaVariables[KEY_EQUIPMENT_GENERATING_INDEX..i]
        --print("index ", generationTableIndex)
        local item = mEquipmentGenerationTable[generationTableIndex]()
        local position = Hyperspace.metaVariables[KEY_EQUIPMENT_ASSIGNMENT..i]
        --print("loading ", item.name, " genIndx ", item.generating_index, " slot ", position)
        if position == nil then 
            position = -2
            item.assigned_slot = -2
        end
        if position == -1 then
            addToInventory(item)
        else
            item.fromLoad = true
            if not addToCrew(item, position) then
                lwl.logError(TAG, "Failed to load item "..item.name)
            end
        end
        --print("loaded item ", item.name, position)
    end
end
------------------------------------END ITEM STORAGE FUNCTIONS----------------------------------------------------------

------------------------------------GUI CREATION----------------------------------------------------------
local function buildInventoryContainer()
    local verticalContainer = lwui.buildVerticalContainer(655, mEquipmentTabTop, 300, 20, tabOneStandardVisibility, NOOP,
            {}, false, true, 7)
    for i=1,inventoryRows do
        local horizContainer = lwui.buildHorizontalContainer(0, 0, 100, mCrewLineHeight, tabOneStandardVisibility, NOOP,
            {}, true, false, 7)
        for j=1,inventoryColumns do
            local buttonNum = ((i - 1) * inventoryRows) + j
            local button = lwui.buildInventoryButton(WEAPON_BUTTON_SUFFIX..buttonNum, 0, 0, mCrewLineHeight, mCrewLineHeight,
                    tabOneStandardVisibility, lwui.inventoryButtonDefault,
                    inventoryFilterFunctionEquipment, buttonAddInventory)
            horizContainer.addObject(button)
            table.insert(mInventoryButtons, button)
        end
        verticalContainer.addObject(horizContainer)
    end
    return verticalContainer
end 

--todo toggle active buttons based on crew type.
local function buildCrewRow(crewmem)
    local anim = lwui.buildObject(0, 0, mCrewLineHeight, mCrewLineHeight, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, .2, .2, .3)))
    local nameText = lwui.buildFixedTextBox(0, 0, mCrewLineNameWidth, mCrewLineHeight, tabOneStandardVisibility, NOOP, mCrewLineTextSize)
    nameText.text = crewmem:GetName()
    local weaponButton = lwui.buildInventoryButton(crewmem.extend.selfId..WEAPON_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.inventoryButtonDefault, inventoryFilterFunctionWeapon, buttonAddToCrew)
    local armorButton = lwui.buildInventoryButton(crewmem.extend.selfId..ARMOR_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.inventoryButtonDefault, inventoryFilterFunctionArmor, buttonAddToCrew)
    local toolButton = lwui.buildInventoryButton(crewmem.extend.selfId..TOOL_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.inventoryButtonDefault, inventoryFilterFunctionTool, buttonAddToCrew)
    weaponButton.itemType = TYPE_WEAPON
    armorButton.itemType = TYPE_ARMOR
    toolButton.itemType = TYPE_TOOL
    local horizContainer = lwui.buildHorizontalContainer(3, 0, 100, mCrewLineHeight, tabOneStandardVisibility, NOOP,
        {anim, nameText, weaponButton, armorButton, toolButton}, true, false, mCrewLinePadding)
    --kind of dirty to apply it to all of these but it's not that bad.
    horizContainer[GEX_CREW_ID] = crewmem.extend.selfId
    weaponButton[GEX_CREW_ID] = crewmem.extend.selfId
    armorButton[GEX_CREW_ID] = crewmem.extend.selfId
    toolButton[GEX_CREW_ID] = crewmem.extend.selfId
    return horizContainer
end

local function buildCrewEquipmentScrollBar()
    return lwui.buildVerticalContainer(0, 0, 300, 20, tabOneStandardVisibility, NOOP,
        {nameText, weaponButton, armorButton, toolButton}, false, true, mCrewRowPadding)
end

local function constructEnhancementsLayout()
--mNameToItemIndexTable["Seal Head"]] ())--todo make a table of names to indexes.  or maybe just randomly pick one every time.

    --Left hand side
    mCrewListContainer = buildCrewEquipmentScrollBar()
    local crewListScrollWindow = lwui.buildVerticalScrollContainer(341, mEquipmentTabTop, 290, 370, tabOneStandardVisibility, mCrewListContainer, lwui.defaultScrollBarSkin)
    lwui.addTopLevelObject(crewListScrollWindow, "TABBED_WINDOW")
    --lwui.addTopLevelObject(ib1)
    local nameHeader = lwui.buildFixedTextBox(340, mTabTop, 260, 26, tabOneStandardVisibility, NOOP, 16)
    nameHeader.text = "       Name             Weapon Armor Tool"
    lwui.addTopLevelObject(nameHeader, "TABBED_WINDOW")
    
        --653, 334
        --Lower right corner
    mDescriptionHeader = lwui.buildFixedTextBox(645, 348, 225, 35, tabOneStandardVisibility, NOOP, 18)--TODO AALL FIX
    mDescriptionHeader.text = NO_ITEM_SELECTED_TEXT
    lwui.addTopLevelObject(mDescriptionHeader, "TABBED_WINDOW")
    mDescriptionTextBox = lwui.buildDynamicHeightTextBox(0, 0, 245, 90, tabOneStandardVisibility, NOOP, 10)
    local descriptionTextScrollWindow = lwui.buildVerticalScrollContainer(643, 384, 260, 150, tabOneStandardVisibility, mDescriptionTextBox, lwui.testScrollBarSkin)
    lwui.addTopLevelObject(descriptionTextScrollWindow, "TABBED_WINDOW")

    --Upper right corner
    --It's a bunch of inventory buttons, representing how many slots you have to hold this stuff you don't have equipped currently.
    --When things get added to the inventory, they'll find the first empty slot here.   So I need to group these buttons in a list somewhere.
    local inventoryHeader = lwui.buildFixedTextBox(622, mTabTop, 220, 26, tabOneStandardVisibility, NOOP, 14)
    inventoryHeader.text = "Inventory"
    lwui.addTopLevelObject(inventoryHeader, "TABBED_WINDOW")
    lwui.addTopLevelObject(buildInventoryContainer(), "TABBED_WINDOW")
    local trashY = 70
    local trashX = 876
    local trashButton = lwui.buildInventoryButton("TrashItemButton", trashX, 280 + trashY, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.spriteRenderFunction("items/trash.png"), inventoryFilterFunctionAny, trashItem)
    lwui.addTopLevelObject(trashButton, "TABBED_WINDOW")
    local trashHeader = lwui.buildFixedTextBox(trashX - 2, 252 + trashY, 60, 35, tabOneStandardVisibility, NOOP, 16)
    trashHeader.text = "Sell"
    lwui.addTopLevelObject(trashHeader, "TABBED_WINDOW")
    
    --print("stuff readied")
end

--[[
Number of equipment currently in use
equipment_N: gives the index of the equipment generating function array used to make this equipment.
equipment_location_N: gives -2 if no longer in use, -1 for inventory slot, or crewId if attached to a crew member.
that's it, no fancy saving or loading stuff.
--]]
------------------------------------END GUI CREATION----------------------------------------------------------

------------------------------------REALTIME EVENTS----------------------------------------------------------
local function tickEquipment()
    local ownshipManager = Hyperspace.ships(0)
    if not ownshipManager then return end
    local playerCrew = lwl.getAllMemberCrewFromFactory(lwl.filterOwnshipTrueCrew)
    for _,crewmem in ipairs(playerCrew) do
        local equips = getCrewEquipment(crewmem)
        --print("ticking", crewmem:GetName(), "has ", #equips, "equipment")
        for _,item in ipairs(equips) do
            --print("ticking", crewmem:GetName(), crewmem.extend.selfId, "'s", item.name)
            item.onTick(item, crewmem)
        end
    end
end


script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not lwl.isPaused() then
        --[[ formula to turn ticks into 1/32 second
        16 / speedFactor = ticks per second
        tps * functor = 32
        --]]
        mScaledLocalTime = mScaledLocalTime + (Hyperspace.FPS.SpeedFactor * 16 / 10)
        if (mScaledLocalTime > 1) then
            tickEquipment()
            mScaledLocalTime = 0
        end
    end
    if not mScaledLocalTime == 0 then return end
    if not mCrewChangeObserver.isInitialized() then return end
    if not mSetupFinished then
        --resetPersistedValues() --todo remove
        constructEnhancementsLayout()
    end
    
    --Update crew table
    local addedCrew = mCrewChangeObserver.getAddedCrew()
    local removedCrew = mCrewChangeObserver.getRemovedCrew()
    for _, crewId in ipairs(removedCrew) do
        --print("eq crew removed id ", crewId)
        local removedLines = {}
        --remove existing row
        for _, crewContainer in ipairs(mCrewListContainer.objects) do
            --print("checking row ", crewContainer[GEX_CREW_ID])
            if (crewContainer[GEX_CREW_ID] == crewId) then
                --print("found match! ")
                --print("there were N crew ", #mCrewListContainer.objects)
                table.insert(removedLines, crewContainer)
                mCrewListContainer.objects = lwl.getNewElements(mCrewListContainer.objects, {crewContainer})--todo this is kind of experimental
                --print("there are now N crew ", #mCrewListContainer.objects)
            end
        end
        --remove all the items in removedLines
        for _, line in ipairs(removedLines) do
            for _, button in ipairs(line.objects) do
                if (button.item) then
                    if (math.random() > .7) then --maybe you saved it?
                        addToInventory(button.item)
                    else
                        deleteItem(button, item)
                    end
                end
            end
        end
    end
    for _, crewId in ipairs(addedCrew) do
        local crewmem = lwl.getCrewById(crewId)
        --print("eq crew added ", crewId, crewmem:GetName())
        mCrewListContainer.addObject(buildCrewRow(crewmem))
    end
    
    if not mSetupFinished then
        loadPersistedEquipment()
        mSetupFinished = true
    end
    --print("equipment saving last seen state")
    mCrewChangeObserver.saveLastSeenState()
end)

script.on_render_event(Defines.RenderEvents.TABBED_WINDOW, function()
end, function(tabName)
    if not mSetupFinished then return end
    --might need to put this in the reset category.
    --print("tab name "..tabName)
    if tabName == ENHANCEMENTS_TAB_NAME then
        --description rendering, last hovered item will persist until window refreshed.
        local buttonContents = nil
        if (lwui.mHoveredButton ~= nil) then
            buttonContents = lwui.mHoveredButton.item
        end
        if (lwui.mClickedButton ~= nil) then
            buttonContents = lwui.mClickedButton.item
        end
        if (buttonContents) then
            mDescriptionHeader.text = buttonContents.name
            mDescriptionTextBox.text = "Type: "..buttonContents.itemType.."\n"..buttonContents.description.."\nSell Value: "..buttonContents.sellValue.."~"
        end
        
        if not (mTabbedWindow == ENHANCEMENTS_TAB_NAME) then
            mDescriptionHeader.text = NO_ITEM_SELECTED_TEXT
            mDescriptionTextBox.text = ""
        end
    end
    mTabbedWindow = tabName
end)
------------------------------------END REALTIME EVENTS----------------------------------------------------------
------------------------------------ITEM DEFINITIONS----------------------------------------------------------
--Only the player can use items.
-------------------SHREDDER CUFFS------------------
local function ShredderCuffs(item, crewmem)
    if crewmem.bFighting and crewmem.bSharedSpot then
        local ownshipManager = Hyperspace.ships(0)
        local foeShipManager = Hyperspace.ships(1)
        foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y)
        for _,foe in ipairs(foes_at_point) do
            foe:DirectModifyHealth(-.05)
        end
    end
end
-------------------SEAL HEAD------------------
local function SealHead(item, crewmem)
    if item.stunCounter == nil then
        item.stunCounter = 0
    end
    if crewmem.bFighting and crewmem.bSharedSpot then
        item.stunCounter = item.stunCounter + .005
        if (item.stunCounter > 1) then
            item.stunCounter = 0
            local ownshipManager = Hyperspace.ships(0)
            local foeShipManager = Hyperspace.ships(1)
            foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y)
            for _,foe in ipairs(foes_at_point) do
                foe.fStunTime = foe.fStunTime + .3
            end
        end
    end
end
--equinoid tools scale off bp and have +3 mult when applied to horse.
-------------------CHICAGO TYPEWRITER------------------
local function ChicagoTypewriter(item, crewmem)
    if (item.manningWeapons == nil) then item.manningWeapons = false end
    --print(crewmem:GetName(), "using skill ", crewmem.usingSkill)
    local manningWeapons = crewmem.iManningId == lwl.SYS_WEAPONS() and crewmem.currentShipId == crewmem.iShipId
    --Specifically for weapons and drones, this needs to be if they're standing in the room, which is what this checks.  Other versions can check usingSkill.
    --bBoostable was already true.  You could do interesting stuff with setting this to false for enemy systems as a minor effect.
    if manningWeapons ~= item.manningWeapons then
        if manningWeapons then
            Hyperspace.ships.player.weaponSystem:UpgradeSystem(1)
        else
            Hyperspace.ships.player.weaponSystem:UpgradeSystem(-1)
        end
    end
    item.manningWeapons = manningWeapons
end

local function ChicagoTypewriterRemove(item, crewmem)
    if item.manningWeapons then
        Hyperspace.ships.player.weaponSystem:UpgradeSystem(-1)
    end
end
-------------------BALLANCEATOR------------------
local function Ballanceator(item, crewmem)
    local dpt = .85
    if (crewmem:GetIntegerHealth() > crewmem:GetMaxHealth() / 2) then
        crewmem:DirectModifyHealth(-dpt)
    else
        crewmem:DirectModifyHealth(dpt)
    end
end
-------------------HELLION HALBERD------------------
local function HellionHalberd(item, crewmem)
    if crewmem.bFighting and crewmem.bSharedSpot then
        --foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y) --coords are relative to the first manager.
        --foes_at_point = lwl.getFoesAtPoint(crewmem, crewmem.x, crewmem.y) --this is actually harder to implement as it involves converting points in mainspace to one of the ships.
        for _,foe in ipairs(lwl.getFoesAtSelf(crewmem)) do
            lwce.applyBleed(foe, 21)--per tick  todo sometimes doesn't work.  also statuses sometimes don't teleport right.  Applying to enemy crew seems to not work now.
        end
    end
end
-------------------PEPPY BISMOL------------------
local function PeppyBismol(item, crewmem)
    --requires stat boost HS
end
-------------------Medkit------------------
local function MedkitEquip(item, crewmem)
    crewmem.health.second = crewmem.health.second + 15
end
local function MedkitRemove(item, crewmem)
    crewmem.health.second = crewmem.health.second - 15
end
-------------------Graft Armor------------------
local function GraftArmorEquip(item, crewmem)
    crewmem.health.second = crewmem.health.second + 5
    lwce.addResist(crewmem, lwce.KEY_BLEED, 1)
end
local function GraftArmor(item, crewmem)
    --requires statboost HS
end
local function GraftArmorRemove(item, crewmem)
    crewmem.health.second = crewmem.health.second - 5
    lwce.addResist(crewmem, lwce.KEY_BLEED, -1)
end
-------------------It's Terrible!------------------
local function statusTestEquip(item, crewmem)
    lwce.applyBleed(crewmem, 3)
    lwce.applyConfusion(crewmem, 3)
    --print("Applying corruption!")
    lwce.applyCorruption(crewmem, .2)
end
local function statusTest(item, crewmem)
    lwce.applyBleed(crewmem, 1)
    lwce.applyConfusion(crewmem, 1)
    --lwce.applyCorruption(crewmem, .1)
end
local function statusTestRemove(item, crewmem)
    --print("Removing corruption!")
    lwce.applyCorruption(crewmem, -.2)
end
-------------------Omelas Generator------------------
local function OmelasGeneratorEquip(item, crewmem) --mAYBE MAKE THIS CURSED.  Also this is broken and does not remove power properly, possibly upon exiting the game.  I should check the typewriter as well.  I need to call the onRemove methods of all items when quitting the game.  No such hook exists.
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    powerManager.currentPower.second = powerManager.currentPower.second + 4
end

local function OmelasGenerator(item, crewmem)
    lwce.applyCorruption(crewmem, .006)
end

local function OmelasGeneratorRemove(item, crewmem)
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    powerManager.currentPower.second = powerManager.currentPower.second - 4
end
-------------------Ferrogenic Exsanguinator------------------
local function FerrogenicExsanguinator(item, crewmem)
    --If crew repairing a system, apply bleed and repair system more.
    if crewmem:RepairingSystem() and not crewmem:RepairingFire() then
        local currentShipManager = Hyperspace.ships(crewmem.currentShipId)
        local systemId = crewmem.iManningId
        local system = currentShipManager:GetSystem(systemId)
        system:PartialRepair(12.5, false)
        lwce.applyBleed(crewmem, 3.2)
    end
end
-------------------Egg------------------
local function Egg(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        item.sellValue = item.sellValue + 3
    end
    item.jumping = Hyperspace.ships(0).bJumping
end
-------------------Myocardial Overcharger------------------
local function MyocardialOvercharger(item, crewmem) --todo this kind of sucks because these custom values don't persist, leading to _issues_.
    item.sellValue = 6 + mItemsSold
    if not (item.sellValue == item.lastSellValue) then
        crewmem.health.second = crewmem.extend:GetDefinition().maxHealth + (mItemsSold * 5)
    end
    item.lastSellValue = item.sellValue
end
local function MyocardialOverchargerEquip(item, crewmem)
    item.storedHealth = crewmem.health.second
    crewmem.health.second = crewmem.extend:GetDefinition().maxHealth + (mItemsSold * 5)
end
local function MyocardialOverchargerRemove(item, crewmem)
    if item.storedHealth and item.storedHealth > 0 then
        crewmem.health.second = item.storedHealth
    else --reset crew health
        crewmem.health.second = crewmem.extend:GetDefinition().maxHealth
    end
end
-------------------Holy Symbol------------------
local function HolySymbolRender()
    local holySymbolIcons = {"holy_symbol_2.png", "holy_symbol_3.png"}
    local chosenIcon = holySymbolIcons[math.random(1,#holySymbolIcons)]
    return lwui.spriteRenderFunction("items/"..chosenIcon)
end

local function HolySymbolEquip(item, crewmem)
    lwce.addResist(crewmem, lwce.KEY_CORRUPTION, .9)
end

local function HolySymbolRemove(item, crewmem)
    lwce.addResist(crewmem, lwce.KEY_CORRUPTION, -.9)
end
-------------------Interfangilator------------------
-- This is actually way more complex because it requires tracking which enemy ship you are facing.
-- Reduces it by 1
local function InterfangilatorEquip(item, crewmem)--[[  TODO FIX when a new ship is jumping in.
    print("skill level", crewmem:GetSkillLevel(0))
    print("skill modifier", crewmem:GetSkillModifier(0))
    print("skill progress", crewmem:GetSkillProgress(0))
    print("skill from system", Hyperspace.CrewMember.GetSkillFromSystem(0))
    crewmem:MasterSkill(0)
    
    print("skill level", crewmem:GetSkillLevel(0))
    print("skill modifier", crewmem:GetSkillModifier(0))
    print("skill progress", crewmem:GetSkillProgress(0))
    print("skill from system", Hyperspace.CrewMember.GetSkillFromSystem(0))--]]
end

local function InterfangilatorApplyEffect(item, crewmem, value) --mostly checks crewmem values
    if crewmem.iManningId >= 0 and Hyperspace.ships.enemy and (crewmem.currentShipId == crewmem.iShipId) then
        local system = Hyperspace.ships.enemy:GetSystem(crewmem.iManningId)
        print("if applying", crewmem.iManningId, "system is", system, value)
        if system then
            local beforePower = system:GetPowerCap()
            print("before power", beforePower)
            system:UpgradeSystem(-value)
            item.storedValue = beforePower - system:GetPowerCap()
            --should also store damage status of the removed bars. may be hard.
        end
    end
end

local function InterfangilatorRemoveEffect(item, crewmem, value) --todo make this use item.system  --mostly checks item values
    if item.systemId and item.systemId >= 0 and Hyperspace.ships.enemy and (item.shipId == crewmem.iShipId) then
        local system = Hyperspace.ships.enemy:GetSystem(item.systemId)
        print("if removed", item.systemId, "system is", system, value)
        if system then
            system:UpgradeSystem(value)
            if system:CompletelyDestroyed() then
                system:SetDamage(0) --repair partial 100Xvalue
            end
        end
    end
end

local function Interfangilator(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        item.ready = true
        item.systemId = nil
    end
    item.jumping = Hyperspace.ships(0).bJumping
    
    if item.ready or ((item.system ~= crewmem.currentSystem) and (item.shipId == crewmem.iShipId)) then
        print("IFID is now ", crewmem.iManningId)
        InterfangilatorRemoveEffect(item, crewmem, 1)
        InterfangilatorApplyEffect(item, crewmem, 1)
        item.ready = false
    end
    item.systemId = crewmem.iManningId
    item.system = crewmem.currentSystem
    item.shipId = crewmem.currentShipId
end

local function InterfangilatorRemove(item, crewmem)
    InterfangilatorRemoveEffect(item, crewmem, item.storedValue)
end
-------------------Custom Interfangilator------------------
-- Reduces it by the crew's skill level in that system.
local function CustomInterfangilatorLevel(item, crewmem)
    return crewmem:GetSkillLevel(Hyperspace.CrewMember.GetSkillFromSystem(crewmem.iManningId)) - 1
end

local function CustomInterfangilator(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        item.ready = true
    end
    item.jumping = Hyperspace.ships(0).bJumping
    
    if item.ready or ((item.system ~= crewmem.currentSystem) and (item.shipId == crewmem.iShipId)) then
        print("CIFID is now ", crewmem.iManningId)
        --todo misbehaves if crew skilled up while active, but that happens like twice.
        item.storedValue = lwl.setIfNil(item.storedValue, CustomInterfangilatorLevel(item, crewmem))
        InterfangilatorRemoveEffect(item, crewmem, item.storedValue)
        item.storedValue = CustomInterfangilatorLevel(item, crewmem)
        InterfangilatorApplyEffect(item, crewmem, item.storedValue)
        item.ready = false
        item.systemId = crewmem.iManningId
    end
    item.systemId = crewmem.iManningId
    item.system = crewmem.currentSystem
    item.shipId = crewmem.currentShipId
end

local function CustomInterfangilatorRemove(item, crewmem)
    InterfangilatorRemoveEffect(item, crewmem, item.storedValue)
end
-------------------Compactifier------------------
local function CompactifierEquip(item, crewmem) --needs stat boost 1.20
    --item.wasNoslot = 
    --local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    --powerManager.currentPower.second = powerManager.currentPower.second + 4
end

local function CompactifierRemove(item, crewmem)
    if not item.wasNoslot then
        --crewmem
    end
end
-------------------INTERNECION CUBE------------------
local function InternecionCubeEquip(item, crewmem)
    item.value = 0
end

local MURDERBOT_LIST = {"NANOBOT_DEFENSE_SYSTEM", "LOCKED_NANOBOT_DEFENSE_SYSTEM", "IZD_NANOBOT_DEFENSE_SYSTEM", "HIDDEN IZD_NANOBOT_DEFENSE_SYSTEM", "FM_NO_IZD_MURDERBOTS", "DECREPIT_MURDERBOTS", "ANCIENT_MURDERBOTS", "ROYAL_MURDERBOTS", "AEA_NECRO_MURDERBOTS"}
local IC_on_TEXT = "Cute and lethal, this boodthirsty being will carve up your foes and sometimes you (in a good way). Damages all enemies in the same room when fighting. If crew is below full health, periodically stun and heal them."
local function InternecionCube(item, crewmem)
    local murderMultiplier = 1
    for _,murderAugName in ipairs(MURDERBOT_LIST) do
        murderMultiplier = murderMultiplier + Hyperspace.ships.player:HasAugmentation(murderAugName)
    end
    if murderMultiplier > 1 then
        item.description = IC_on_TEXT.." Boosted [X][X] "..murderMultiplier.." by MURDER!"
    else
        item.description = IC_on_TEXT
    end
    
    item.value = item.value + (.24 / murderMultiplier)
    if item.value > 100 then
        item.value = 0
        if crewmem.health.first < crewmem.health.second then
            crewmem.fStunTime = crewmem.fStunTime + 2.5 + murderMultiplier
            crewmem:DirectModifyHealth(28 * murderMultiplier)
        end
    end

    if crewmem.bFighting then
        lwl.damageEnemyCrewInSameRoom(crewmem, .07 * murderMultiplier, 0) --lwl might have issues if crew tag along after a jump todo fix?
        --todo damage everyone, increase heal.
    end
end
-------------------P.G.O------------------
local PGO_NAME = "Perfectly Generic Object"
local PGO_DESCRIPTION = "There's not much to say about this little green cube."
local PGO_SPRITE = "items/pgo.png"

local function PerfectlyGenericObjectCreate(item)
    gex_give_item(19)
    gex_give_item(19)
end

local PGO_DEFINITION = {name=PGO_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(PGO_SPRITE), description=PGO_DESCRIPTION}
local THREE_PGO_DEFINITION = {name=PGO_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(PGO_SPRITE), description=PGO_DESCRIPTION, onCreate=PerfectlyGenericObjectCreate}
-- a small chance each jump to spawn another?  No, that will be a different thing.  Then more things that care about the number of things you have.
-------------------Thief's Hand------------------
--todo They're gonna combine??
local VOID_RING_NAME = "Ring of Void (DUD)"
local THIEFS_HAND_DESCRIPTION_DORMANT = "Said to once belong to the greatest thief in the multiverse, this disembodied hand has the ability to steal from space itself!  The spoils though, are much less remarkable."
local THIEFS_HAND_DESCRIPTION_WOKEN = "Said to once belong to the greatest thief in the multiverse, this disembodied hand has the ability to steal from space itself!  Drawing on the ring's power, it pulls even the most obscure whatsits into existence."

local function ThiefsHand(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        if (getEquippedItem(crewmem.extend.selfId, TYPE_WEAPON).name == VOID_RING_NAME) then
            item.description = THIEFS_HAND_DESCRIPTION_WOKEN
            if (math.random() > .2) then
                gex_give_random_item()
            end
        else
            item.description = THIEFS_HAND_DESCRIPTION_DORMANT
            if (math.random() > .9) then
                createSinglePgo()
            end
        end
    end
    item.jumping = Hyperspace.ships(0).bJumping
end

-------------------Ring of Void------------------
--Thief's Hand now spawns all objects when equipped to the same person.  Also increases spawn chance to 80%.
--Weapon. Makes the wearer untargetable in combat, but unable to fight. (1.20)
local function VoidRing(item, crewmem)
    --todo
end

--[[
todo persist status effects on crew
Torpor Projector
Noted, so teleporting really messes with this.  Furthermore why are the effects dipping to 1 while the equipment stays at 2?  
Determination -- Getting hit charges your abilities.
Inflatable muscles -- while about 1/3 health, extra damage
Medbot Injector -- Health recharge passive
I guess I need status definitions so people know what they do.  Bleed is easy, the others less so.

Interface Scrambler -- Removes manning bonus from all enemy systems and prevents them from being manned.
Purple Thang -- censored, inflicts confusion.
    Or like, corruption% chance you don't revive.  5 corruption is already kind of a lot of damage.
Holy Symbol: lots of icons, 90% corruption resist [miku, hand grenade, (), hl2 logo, random objects]
Scrap Harm: Scrap gain increased by 10%, but gaining scrap makes crew bleed and go crazy. (automate)
A fun thing might look at how many effects are on a given crew.  It should be easy to get the list of effects on a given crew.  PRetty sure it is as written.
  30% system resist to the room you're in
Galpegar
Noctus
The Thunderskin  --Crew cannot fight and gains 100 (double?) health. When in a room with injured allies, bleeds profusely and heals them.  Needs statboost for the cannot fight probably.
Three Perfectly Generic Objects : on create, give it a value and then have it make one with value - 1
Sthenic Venom
A cursed item that autoequips
Item that get stronger the more items you sell.
--todo item onLoad onPersist methods for things that need to save stuff
Blood is Mine, something else I forgot for art assets
FTF Discette
A collection of the latest tracks from backwater bombshell Futanari Titwhore Fiasco


--Crew name list
Swankerdino
Swankerpino
Bing Chillin
--]]
local ERROR_RENDER_FUNCTION = lwui.spriteRenderFunction("items/Untitled.png")
------------------------------------ITEM DEFINITIONS----------------------------------------------------------
local function buildBlueprintFromDefinition(itemDef)
    --Required
    local name = lwl.setIfNil(itemDef.name, "FORGOT NAME!")
    local itemType = lwl.setIfNil(itemDef.itemType, TYPE_WEAPON)
    local renderFunction = lwl.setIfNil(itemDef.renderFunction, ERROR_RENDER_FUNCTION)
    local description = lwl.setIfNil(itemDef.description, "FORGOT DESCRIPTION!")
    --Optional
    local onCreate = lwl.setIfNil(itemDef.onCreate, NOOP)
    local onTick = lwl.setIfNil(itemDef.onTick, NOOP)
    local onEquip = lwl.setIfNil(itemDef.onEquip, NOOP)
    local onRemove = lwl.setIfNil(itemDef.onRemove, NOOP)
    local onPersist = lwl.setIfNil(itemDef.onPersist, NOOP)
    local onLoad = lwl.setIfNil(itemDef.onLoad, NOOP)
    local sellValue = lwl.setIfNil(itemDef.sellValue, 5)
    return buildItemBuilder(name, itemType, renderFunction, description, onCreate, onTick, onEquip, onRemove, onPersist, onLoad, sellValue)
end

local function insertItemDefinition(itemDef)
    table.insert(mEquipmentGenerationTable, buildBlueprintFromDefinition(itemDef))
    --print("Adding ", itemDef.name, " with index", #mEquipmentGenerationTable)
end
--print("numequips before (should be 0)", #mEquipmentGenerationTable)
--Only add to the bottom, changing the order is breaking.
insertItemDefinition({name="Shredder Cuffs", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/SpikedCuffs.png"), description="Looking sharp.  Extra damage in melee.", onTick=ShredderCuffs, sellValue=3})
insertItemDefinition({name="Seal Head", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/SealHead.png"), description="The headbutts it enables are an effective counter to the ridicule you might encounter for wearing such odd headgear.", onTick=SealHead})
insertItemDefinition({name="Chicago Typewriter", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/ChicagoTypewriter.png"), description="Lots of oomph in these keystrokes.  Adds a bar when manning weapons.", onTick=ChicagoTypewriter, onRemove=ChicagoTypewriterRemove})
insertItemDefinition({name="Ballancator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Ballancator.png"), description="As all things should be.  Strives to keep its wearer at exactly half health.", onTick=Ballanceator})
insertItemDefinition({name="Hellion Halberd", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/halberd.png"), description="A vicious weapon that leaves its victems with gaping wounds that bleed profusely.", onTick=HellionHalberd})
insertItemDefinition({name="Peppy Bismol (DUD)", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/peppy_bismol.png"), description="'With Peppy Bismol, nothing will be able to keep you down!'  Increases active ability charge rate.", onTick=PeppyBismol})
insertItemDefinition({name="Medkit (DUD)", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/medkit.png"), description="Packed full of what whales you.  +15 max health.", onEquip=MedkitEquip, onRemove=MedkitRemove})
insertItemDefinition({name="Orgainc Impulse Grafts (DUD)", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/graft_armor.png"), description="Quickly rights abnormal status conditions. +5 max health, bleed immunity, stun resist.", onTick=GraftArmor, onEquip=GraftArmorEquip, onRemove=GraftArmorRemove})
insertItemDefinition({name="Testing Status Tool", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Untitled.png"), description="ALL OF THEM!!!", onTick=statusTest, onEquip=statusTestEquip, onRemove=statusTestRemove, sellValue=15})
insertItemDefinition({name="Omelas Generator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/leaves_of_good_fortune.png"), description="Power, at any cost.  Equiped crew adds four ship power but slowly stacks corruption.", onTick=OmelasGenerator, onEquip=OmelasGeneratorEquip, onRemove=OmelasGeneratorRemove})
insertItemDefinition({name="Ferrogenic Exsanguinator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/grafted.png"), description="'The machine god requires a sacrifice of blood, and I give it gladly.'  Biomechanical tendrils wrap around this crew, extracting their life force to hasten repairs.", onTick=FerrogenicExsanguinator})
insertItemDefinition({name="Egg", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/egg.png"), description="Gains 3 sell value each jump.", onTick=Egg, sellValue=0})
insertItemDefinition({name="Myocardial Overcharger (DUD)", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/brain_gang.png"), description="Grows in power with each item sold.", onTick=MyocardialOvercharger, onEquip=MyocardialOverchargerEquip, onRemove=MyocardialOverchargerRemove})
insertItemDefinition({name="Holy Symbol", itemType=TYPE_WEAPON, renderFunction=HolySymbolRender(), description="Renders its wearer nigh impervious to corruption.", onEquip=HolySymbolEquip, onRemove=HolySymbolRemove, sellValue=10})
insertItemDefinition({name="Interfangilator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/detector.png"), description="Attaches to the frequency signatures of matching enemy systems and inhibits them, reducing them by a bar.", onEquip=InterfangilatorEquip, onTick=Interfangilator, onRemove=InterfangilatorRemove})
insertItemDefinition({name="Custom Interfangilator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/custom_detector.png"), description="Their expertise becomes their sword, and enemy systems fall. An aftermarket model which scales based on the crew's skill level with the current system.", onEquip=InterfangilatorEquip, onTick=CustomInterfangilator, onRemove=CustomInterfangilatorRemove})
insertItemDefinition({name="Compactifier (DUD)", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/decrepit paper.png"), description="Nearly illegible documents stating that this crew 'Doesn't count'.", onEquip=CompactifierEquip, onRemove=CompactifierRemove})
insertItemDefinition({name="Internecion Cube", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/internecion_cube.png"), description=IC_on_TEXT, onEquip=InternecionCubeEquip, onTick=InternecionCube})
insertItemDefinition(PGO_DEFINITION)
insertItemDefinition(THREE_PGO_DEFINITION)
insertItemDefinition({name="Thief's Hand", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/thiefs_hand.png"), description=THIEFS_HAND_DESCRIPTION_DORMANT, onTick=ThiefsHand})
insertItemDefinition({name=VOID_RING_NAME, itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/ring_of_void.png"), description="Greater than what it seems.  Equipped crew can't fight or be targeted in combat."})
--print("numequips after", #mEquipmentGenerationTable)

------------------------------------END ITEM DEFINITIONS----------------------------------------------------------
-----------------------------------------WAYS TO GET ITEMS---------------------------------------------------------------
function gex_give_item(index)
    local equip = mEquipmentGenerationTable[index]()
    addToInventory(equip)
    return equip
end

function gex_give_all_items()
    print("giving ", #mEquipmentGenerationTable)
   for _,equipGen in ipairs(mEquipmentGenerationTable) do
       addToInventory(equipGen())
    end
end

function gex_give_random_item()
    if #mEquipmentGenerationTable == 0 then return end
    return gex_give_item(math.random(1, #mEquipmentGenerationTable))
end

--[[
After winning a battle, a chance to give one item.  Scales with TopScore.sector.  
--]]
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
    local itemChance = 0
    itemChance = itemChance + (event.stuff.scrap * .005)
    itemChance = itemChance + (event.stuff.fuel * .007)
    itemChance = itemChance + (event.stuff.drones * .012)
    itemChance = itemChance + (event.stuff.missiles * .01)
    itemChance = itemChance * mGlobal:GetScoreKeeper().currentScore.sector * .25
    
    if (math.random() < itemChance) then
        local equip = gex_give_random_item()
        event.stuff.scrap = math.max(0, event.stuff.scrap - 5)
        event.text.data = event.text.data.."\nUpon closer inspection, some of the scrap is actually a "..equip.name.."!"
    end
    --print("itemChancepre", itemChance)
    --print("itemChance", itemChance)
end)
script.on_game_event("START_BEACON_REAL", false, function()
        if mSetupFinished then
            resetInventory()
        end
        resetPersistedValues()
        end)


---------------------Things with Dependencies-----------------------------------
--In the crew loop, each crew will check the items assigned to them and call their onTick functions, (pass themselves in?)
--It is the job of the items to do everything wrt their functionality.
--"Cursed" items that can't be unequipped

        
    --Needing to rebuild these tables a lot is why we rely on the _persisted_ values as the source of truth for equipment status.
    --We do this on opening the tab if it's not set up, so that we make sure everything checks out.


    --[[
    might revisit this if someone tells me what these methods do.
    local anim = crewmem.crewAnim.anims[1] --TODO I guess we can cycle through these to be fancy but ok
    --render animation somewhere
    --decent chance this fucks up the crew animation, but I want to know what it does.
    anim.position = Hyperspace.Pointf(400, 0)
    anim:OnRender(1f, Graphics.GL_Color(1, 1, 1, 1), false)--]]

--uh, a function for selling these??  curently does not exist.  low priority but would be nice integration
--not any time soon,