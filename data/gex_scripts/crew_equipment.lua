if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwcco = mods.lightweight_crew_change_observer
local lwsil = mods.lightweight_self_indexing_list
local lwce = mods.lightweight_crew_effects
--local userdata_table = mods.multiverse.userdata_table

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
local mCrewChangeObserver = lwcco.createCrewChangeObserver("crew", 0)
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
local scaledLocalTime = 0

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
        --print("built item from index ", generating_index)
        mItemList:append(builtItem)
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
    mCrewListContainer.objects = {}
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

local function trashItem(button, item) --From scrap it came, and to scrap it can return.
    iButtonTryUnequipPrevious(button, item)
    mItemList:remove(item._index)
    button.item = nil
    item.assigned_slot = -2 --destroyed
    Hyperspace.ships(0):ModifyScrapCount(item.sellValue, false)
    Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
    mItemsSold = mItemsSold + 1
    mItemsSoldValue = mItemsSoldValue + item.sellValue
end

local function buttonAddInventory(button, item)
    iButtonTryUnequipPrevious(button, item)
    item.assigned_slot = -1
    persistEquipment()
end

local function addToCrew(item, crewId) --find the button to add it to and call that.
    --print("addToCrew")
    for _, crewContainer in ipairs(mCrewListContainer.objects) do
        --print("checking row ", crewContainer[GEX_CREW_ID])
        if (crewContainer[GEX_CREW_ID] == crewId) then
            --print("crew found, adding ", item.name)
            for _, iButton in ipairs(crewContainer.objects) do
                --print("checking for buttons ", iButton.className)
                if (iButton.className == "inventoryButton") then
                    if (iButton.addItem(item)) then
                        return true
                    end
                end
            end
        end
    end
    return false
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
        --print("loading ", item.name, " genIndx ", item.generating_index, " slot ", item.assigned_slot)
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
    local crewScrollBar

    local ownshipManager = Hyperspace.ships(0)
    local playerCrew = lwl.getAllMemberCrew(ownshipManager, "crew")
    
    local verticalContainer = lwui.buildVerticalContainer(0, 0, 300, 20, tabOneStandardVisibility, NOOP,
        {nameText, weaponButton, armorButton, toolButton}, false, true, mCrewRowPadding)
    for i=1,#playerCrew do
        verticalContainer.addObject(buildCrewRow(playerCrew[i]))
    end
    
    return verticalContainer
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
    local playerCrew = lwl.getAllMemberCrew(ownshipManager, "crew")
    for _,crewmem in ipairs(playerCrew) do
        local equips = getCrewEquipment(crewmem)
        --print("ticking", crewmem:GetName(), "has ", #equips, "equipment")
        for _,item in ipairs(equips) do
            --print("ticking", crewmem:GetName(), "'s", item.name)
            item.onTick(item, crewmem)
        end
    end
end

local knownCrew = 0

if (script) then
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        if not Hyperspace.ships(0) then return end
        if not mCrewChangeObserver.isInitialized() then print("lwce obby not init") return end
        if lwl.isPaused() then return end
        if not mSetupFinished then
            --resetPersistedValues() --todo remove
            --print("Setting up items")
            constructEnhancementsLayout()
            mCrewChangeObserver.saveLastSeenState() --hey what?
            loadPersistedEquipment()
            mSetupFinished = true
        end
            --[[ formula to turn ticks into 1/32 second
            16 / speedFactor = ticks per second
            tps * functor = 32
            --]]
        scaledLocalTime = scaledLocalTime + (Hyperspace.FPS.SpeedFactor * 16)
        if (scaledLocalTime > 1) then
            tickEquipment()
            scaledLocalTime = 0
        end
        
        --Update crew table
        local addedCrew = mCrewChangeObserver.getAddedCrew()
        local removedCrew = mCrewChangeObserver.getRemovedCrew()
        for _, crewId in ipairs(removedCrew) do
            local crewmem = lwl.getCrewById(crewId)
            if crewmem then
                --print("removing ", crewmem:GetName())
                local removedLines = {}
                --remove existing row
                for _, crewContainer in ipairs(mCrewListContainer.objects) do
                    --print("checking row ", crewContainer[GEX_CREW_ID])
                    if (crewContainer[GEX_CREW_ID] == crewmem.extend.selfId) then
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
                                mItemList:remove(button.item._index)
                                button.item.onRemove(button.item) --todo could be a source of errors, or maybe I just always have to check for crewmem to be nil here.
                            --print("removed item ", button.item._index)
                            end
                        end
                    end
                end
            end
        end
        for _, crewId in ipairs(addedCrew) do
            local crewmem = lwl.getCrewById(crewId)
            --print("adding ", crewmem:GetName())
            mCrewListContainer.addObject(buildCrewRow(crewmem))
        end
        
        --print("EQUIPMENT: Compare ", #mCrewListContainer.objects, knownCrew, knownCrew == #mCrewListContainer.objects)
        if not (knownCrew == #mCrewListContainer.objects) then
            local crewString = ""
            for i=1,#mCrewListContainer.objects do
                crewString = crewString..(lwl.getCrewById(mCrewListContainer.objects[i][GEX_CREW_ID]):GetName())
            end
            --print("EQUIPMENT: There are now this many crew known about: ", #mCrewListContainer.objects, crewString)
            knownCrew = #mCrewListContainer.objects
        end

        if (#addedCrew > 0 or #removedCrew > 0) then
            --print("num crew changed since last update ", addedCrew, removedCrew)
            persistEquipment()
        end
        mCrewChangeObserver.saveLastSeenState()
    end)
    
    script.on_render_event(Defines.RenderEvents.TABBED_WINDOW, function()
    end, function(tabName)
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
end
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
            foe:DirectModifyHealth(-.005)
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

local function ChicagoTypewriterUnequip(item, crewmem)
    if item.manningWeapons then
        Hyperspace.ships.player.weaponSystem:UpgradeSystem(-1)
    end
end
-------------------BALLANCEATOR------------------
local function Ballanceator(item, crewmem)
    local dpt = .085
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
            lwce.applyBleed(foe, 2.1)--per tick  todo sometimes doesn't work.  also statuses sometimes don't teleport right.  Applying to enemy crew seems to not work now.
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
    lwce.applyBleed(crewmem, 2)
    lwce.applyConfusion(crewmem, 2)
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
    lwce.applyCorruption(crewmem, .0006)
end

local function OmelasGeneratorRemove(item, crewmem)
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    powerManager.currentPower.second = powerManager.currentPower.second - 4
end
-------------------Ferrogenic Exsanguinator------------------
local function FerrogenicExsanguinator(item, crewmem)
    --If crew repairing a system, apply bleed and repair system more.
    if crewmem:RepairingSystem() then
        local currentShipManager = Hyperspace.ships(crewmem.currentShipId)
        local systemId = crewmem.iManningId
        local system = currentShipManager:GetSystem(systemId)
        system:PartialRepair(.95, false)
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
--[[
todo persist status effects on crew
Torpor Projector
Noted, so teleporting really messes with this.  Furthermore why are the effects dipping to 1 while the equipment stays at 2?  
Determination -- Getting hit charges your abilities.
Inflatable muscles -- while about 1/3 health, extra damage
Medbot Injector -- Health recharge passive
Orgainc Impulse Grafts -- Armor: +5 hp, immunity to bleed, 60% stun resist.
I guess I need status definitions so people know what they do.  Bleed is easy, the others less so.

Interface Scrambler -- Removes manning bonus from all enemy systems and prevents them from being manned.
Purple Thang -- censored, inflicts confusion.
omalas dynamo: crew provides 4 bars of green power to your ship, but slowly stacks corruption until it kills them.  This is not removed upon cloning.
    Actually maybe I make it so if you die with corruption, you die for real.  Or like, corruption% chance you don't revive.  5 corruption is already kind of a lot of damage.
Holy Symbol: lots of icons, 90% corruption resist [miku, hand grenade, (), hl2 logo, random objects]
Scrap Harm: Scrap gain increased by 10%, but gaining scrap makes crew bleed and go crazy. (automate)
A fun thing might look at how many effects are on a given crew.  It should be easy to get the list of effects on a given crew.  PRetty sure it is as written.
Compactifier -- armor, Equipped crew is noslot.
  30% system resist to the room you're in
Galpegar
Noctus
The Thunderskin  --Crew cannot fight and gains 100 (double?) health. When in a room with injured allies, bleeds profusely and heals them.  Needs statboost for the cannot fight probably.

Sthenic Venom
Item that get stronger the more items you sell.
--todo item onLoad onPersist methods for things that need to save stuff

--Crew name list
Swankerdino
Swankerpino
Bing Chillin
--]]
local ERROR_RENDER_FUNCTION = lwui.spriteRenderFunction("items/Untitled.png")
------------------------------------ITEM DEFINITIONS----------------------------------------------------------
local function insertItemDefinition(itemDef)
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
    table.insert(mEquipmentGenerationTable, buildItemBuilder(name, itemType, renderFunction, description, onCreate, onTick, onEquip, onRemove, onPersist, onLoad, sellValue))
end

--Only add to the bottom, changing the order is breaking.
insertItemDefinition({name="Shredder Cuffs", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/SpikedCuffs.png"), description="Looking sharp.  Extra damage in melee.", onTick=ShredderCuffs, sellValue=3})
insertItemDefinition({name="Seal Head", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/SealHead.png"), description="The headbutts it enables are an effective counter to the ridicule you might encounter for wearing such odd headgear.", onTick=SealHead})
insertItemDefinition({name="Chicago Typewriter", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/ChicagoTypewriter.png"), description="Lots of oomph in these keystrokes.  Adds a bar when manning weapons.", onTick=ChicagoTypewriter, onRemove=ChicagoTypewriterUnequip})
insertItemDefinition({name="Ballancator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Ballancator.png"), description="As all things should be.  Strives to keep its wearer at exactly half health.", onTick=Ballanceator})
insertItemDefinition({name="Hellion Halberd", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/halberd.png"), description="A vicious weapon that leaves its victems with gaping wounds that bleed profusely.", onTick=HellionHalberd})
insertItemDefinition({name="Peppy Bismol (DUD)", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/peppy_bismol.png"), description="'With Peppy Bismol, nothing will be able to keep you down!'  Increases active ability charge rate.", onTick=PeppyBismol})
insertItemDefinition({name="Medkit", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/medkit.png"), description="Packed full of what whales you.  +15 max health.", onEquip=MedkitEquip, onRemove=MedkitRemove})
insertItemDefinition({name="Orgainc Impulse Grafts (DUD)", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/graft_armor.png"), description="Quickly rights abnormal status conditions. +5 max health, bleed immunity, stun resist.", onTick=GraftArmor, onEquip=GraftArmorEquip, onRemove=GraftArmorRemove})
insertItemDefinition({name="Testing Status Tool", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Untitled.png"), description="ALL OF THEM!!!", onTick=statusTest, onEquip=statusTestEquip, onRemove=statusTestRemove, sellValue=15})
insertItemDefinition({name="Omelas Generator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/leaves_of_good_fortune.png"), description="Power, at any cost.  Equiped crew adds four ship power but slowly stacks corruption.", onTick=OmelasGenerator, onEquip=OmelasGeneratorEquip, onRemove=OmelasGeneratorRemove})
insertItemDefinition({name="Ferrogenic Exsanguinator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/grafted.png"), description="'The machine god requires a sacrifice of blood, and I give it gladly.'  Biomechanical tendrils wrap around this crew, extracting their life force to hasten repairs.", onTick=FerrogenicExsanguinator})
insertItemDefinition({name="Egg", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/egg.png"), description="Gains 3 sell value each jump.", onTick=Egg, sellValue=0})
insertItemDefinition({name="Myocardial Overcharger (DUD)", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/brain_gang.png"), description="Grows in power with each item sold.", onTick=MyocardialOvercharger, onEquip=MyocardialOverchargerEquip, onRemove=MyocardialOverchargerRemove})
insertItemDefinition({name="Holy Symbol", itemType=TYPE_WEAPON, renderFunction=HolySymbolRender(), description="Renders its wearer nigh impervious to corruption.", onEquip=HolySymbolEquip, onRemove=HolySymbolRemove, sellValue=10})

------------------------------------END ITEM DEFINITIONS----------------------------------------------------------
-----------------------------------------WAYS TO GET ITEMS---------------------------------------------------------------
function gex_give_item(index)
    local equip = mEquipmentGenerationTable[index]()
    addToInventory(equip)
    return equip
end

function gex_give_all_items()
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
        resetInventory()
        end)


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