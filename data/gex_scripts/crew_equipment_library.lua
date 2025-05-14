if (not mods) then mods = {} end
mods.crew_equipment_library = {}
local cel = mods.crew_equipment_library
local cels = mods.crew_equipment_library_slots
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwcco = mods.lightweight_crew_change_observer
local lwsil = mods.lightweight_self_indexing_list
local lwce = mods.lightweight_crew_effects
lwce.RequestInitialization()

--As library, needs to reject things with duplicate names, pop error. lib in lwl, GEXPy uses lib and adds the items.
--I probably need to hash out custom persist stuff first.
if not lwl then
    error("Lightweight Lua was not patched, or was patched after Crew Equipment Library.  Install it properly or face undefined behavior.")
end

--[[

--Also note that due to how I've constructed this, items may stick around after the crew using them has died, so I need to make sure the calls don't error.
crew observer breaks sometimes and there's a memory leak, possibly in effects.
--]]

----------------------------------------------------DEFINES----------------------
local TAG = "LW Crew Equips"
local function NOOP() end
local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local TYPE_WEAPON = "Weapon"
local TYPE_ARMOR = "Armor"
local TYPE_TOOL = "Tool"
local TYPE_NONE = "None"
local TYPE_ANY = "Any"
local TYPE_SPACER = "Spacer"
local EQUIPMENT_ICON_SIZE = 30
local GEX_CREW_ID = "GEX_crewId"
local ERROR_RENDER_FUNCTION = lwui.spriteRenderFunction("items/CEL_ERROR.png") --todo add

--local INVENTORY_BUTTON_PREFIX = "inventory_button_"
local NO_ITEM_SELECTED_TEXT = "--- None Selected ---"

local mEquipmentList = {}
local KEY_NUM_EQUIPS = "GEX_CURRENT_EQUIPMENT_TOTAL"
local KEY_EQUIPMENT_GENERATING_INDEX = "GEX_EQUIPMENT_GENERATING_INDEX_"
local KEY_EQUIPMENT_ASSIGNMENT = "GEX_EQUIPMENT_ASSIGNMENT_"

--Do not modify these, actually maybe add a copy getter or something.
cel.mNameToItemIndexTable = {}
cel.mItemList = lwsil.SelfIndexingList:new()

local mSetupFinished = false
local mCrewChangeObserver = lwcco.createCrewChangeObserver(lwl.filterOwnshipTrueCrew)
local mCrewListContainer
local mEquipmentGenerationTable = {}
local mSecretIndices = {}
local mTabbedWindow = ""
local mTab = 1
local mGlobal = Hyperspace.Global.GetInstance()
--Items must be added to this list when they are created or loaded
local 
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

local inventoryRows = 5
local inventoryColumns = 6
cel.persistEquipment


local function itemTryUnequipPrevious(item)
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
------------------------------------API----------------------------------------------------------

local function buildBlueprintFromDefinition(itemDef)--45 c cvgbhbhyh bbb
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
    local secret = lwl.setIfNil(itemDef.secret, false)
    return buildItemBuilder(name, itemType, renderFunction, description, onCreate, onTick, onEquip, onRemove, onPersist, onLoad, sellValue, secret)
end

function cel.insertItemDefinition(itemDef)
    table.insert(mEquipmentGenerationTable, buildBlueprintFromDefinition(itemDef))
    --print("Adding ", itemDef.name, " with index", #mEquipmentGenerationTable) 
end

--returns the first found button with the given name item
function cel.getCrewButtonWithItem(crewId, itemName)
    for _, crewContainer in ipairs(mCrewListContainer.objects) do
        print("checking row ", crewContainer[GEX_CREW_ID], ", total rows", #mCrewListContainer.objects)
        if (crewContainer[GEX_CREW_ID] == crewId) then
            print("crew found, looking for button that has", itemName)
            for _, iButton in ipairs(crewContainer.objects) do
                print("checking for buttons ", iButton.className)
                if (iButton.className == "inventoryButton") then--todo expose these values
                    print("Item is", iButton.item)
                    if (iButton.item) then
                        print("Name is", iButton.item.name, "checking against", itemName)
                        if iButton.item.name == itemName then
                            return iButton
                        end
                    end
                end
            end
        end
    end
end

function cel.crewHasItem(crewId, itemName)
    local button = cel.getCrewButtonWithItem(crewId, itemName)
    return (button ~= nil)
end

function cel.getCurrentEquipment()
    
end

function cel.deleteItem(button, item)
    itemTryUnequipPrevious(item)
    cel.mItemList:remove(item._index)
    if button then
        button.item = nil
    end
    item.assigned_slot = -2 --destroyed
    cel.persistEquipment()
end

------------------------------------END API----------------------------------------------------------

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
local function buildItemBuilder(name, itemType, renderFunction, description, onCreate, onTick, onEquip, onRemove, onPersist, onLoad, sellValue, secret)
    local generating_index = #mEquipmentGenerationTable + 1
    cel.mNameToItemIndexTable[name] = generating_index
    print("Added key", name, "value", cel.mNameToItemIndexTable[name])
    return function()
        local builtItem = lwui.buildItem(name, itemType, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE,
                tabOneStandardVisibility, renderFunction, description, onCreate, onTick, onEquip, onRemove)
        builtItem.generating_index = generating_index
        builtItem.sellValue = sellValue
        builtItem.onPersist = onPersist
        builtItem.onLoad = onLoad
        cel.mItemList:append(builtItem)
        if secret then
            table.insert(mSecretIndices, generating_index)
        end
        --print("built item, item list now has ", mItemList.length)
        return builtItem
    end
end

------------------------------------INVENTORY FILTER FUNCTIONS----------------------------------------------------------

local function inventoryFilterFunctionAny(item)
    return true
end

local function generateStandardFilterFunction(itemType)
   return function(item)
       --print("checking ", item.name, item.itemType, "against", itemType)
       return (item ~= nil and item.itemType == itemType)
   end
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
    cel.mItemList = lwsil.SelfIndexingList:new()
    mCrewListContainer.objects = {} --todo this removes starting crew, find a better way to do whatever this is.
end

--The first argument is unused, but needs to be there
local function trashItem(button, item) --From scrap it came, and to scrap it can return.
    Hyperspace.ships(0):ModifyScrapCount(item.sellValue, false)
    Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
    mItemsSold = mItemsSold + 1
    mItemsSoldValue = mItemsSoldValue + item.sellValue
    cel.deleteItem(button, item)
end

--Does not remove item from previous location
local function addToInventory(item)
    local oldSlotValue = item.assigned_slot
    for _, iButton in ipairs(mInventoryButtons) do
        if (iButton.addItem(item)) then --implicitly calls buttonAddInventory
            return true
        end
    end
    trashItem(nil, item)
    return false
end

local function buttonAddInventory(button, item)
    itemTryUnequipPrevious(item)
    item.assigned_slot = -1
    cel.persistEquipment()
end

--todo this has issues, and solving them will likely restore stability to a good place.
--Id of crew to check, filter function to use, if you need only empty buttons.
local function getCrewButton(crewId, item, requireEmpty)
    for _, crewContainer in ipairs(mCrewListContainer.objects) do
        print("checking row ", crewContainer[GEX_CREW_ID])
        if (crewContainer[GEX_CREW_ID] == crewId) then
            print("crew found, looking for button that can hold", item.itemType)
            for _, iButton in ipairs(crewContainer.objects) do
                print("checking for buttons ", iButton.className)
                if (iButton.className == "inventoryButton") then--todo expose these values
                    if (iButton.allowedItemsFunction(item)) then
                        if requireEmpty then
                            if not iButton.item then
                                return iButton
                            end
                        else
                            return iButton
                        end
                    end
                end
            end
        end
    end
    --error("GEX Could not find crew button!")
end

local function addToCrew(item, crewId) --find the button to add it to and call that.
    --needs to iterate through all crew buttons.
    local requireEmpty = true
    local button = getCrewButton(crewId, item, requireEmpty)
    if not button then return false end
    return button.addItem(item) --todo these two are failing with nil stuff
end

local function buttonAddToCrew(button, item)
    --print("buttonaddToCrew")
    itemTryUnequipPrevious(item)
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
    cel.persistEquipment()
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

cel.persistEquipment = function()
    local numEquipment = cel.mItemList.length
    --print("persisting ", numEquipment, " items")
    local successes = 0
    for i=1,numEquipment do
        local equipment = cel.mItemList:get(i)
        if (equipment.generating_index == nil) or (equipment.assigned_slot == nil) then
            print(TAG, "ERROR: Could not persist "..equipment.name..": incomplete values.", equipment.generating_index, equipment.assigned_slot)
            --deleteItem(nil, equipment) breaks badly
            --print(equipment.generating_index, equipment.assigned_slot)
        else
            successes = successes + 1
            --print("persisting ", equipment.name, " genIndx ", equipment.generating_index, " slot ", equipment.assigned_slot)
            Hyperspace.metaVariables[KEY_EQUIPMENT_GENERATING_INDEX..successes] = equipment.generating_index
            Hyperspace.metaVariables[KEY_EQUIPMENT_ASSIGNMENT..successes] = equipment.assigned_slot--todo I need to set this value properly
            equipment.onPersist(equipment, successes)
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
        print("custom loading", item.name, i)
        item.onLoad(item, i)
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
                lwl.logError(TAG, "Failed to load item "..item.name.." into position "..position)
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
            local button = lwui.buildInventoryButton(buttonNum, 0, 0, mCrewLineHeight, mCrewLineHeight,
                    tabOneStandardVisibility, lwui.inventoryButtonDefault,
                    inventoryFilterFunctionAny, buttonAddInventory, NOOP)
            horizContainer.addObject(button)
            table.insert(mInventoryButtons, button)
        end
        verticalContainer.addObject(horizContainer)
    end
    return verticalContainer
end

local function buildIButton(filterFunction, renderFunction, itemTypes, crewId)
    local standardButton = lwui.buildInventoryButton("", 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, renderFunction, filterFunction, buttonAddToCrew, NOOP)
    standardButton[GEX_CREW_ID] = crewId
    return standardButton
end

local function buildSingleButton(crewmem, buttonType)
    local object
    local crewId = crewmem.extend.selfId
    if buttonType == TYPE_NONE then
        object = lwui.buildObject(0, 0, mCrewLineHeight, mCrewLineHeight, tabOneStandardVisibility,
            lwui.inventoryButtonDefaultDisabled)
    elseif buttonType == TYPE_WEAPON or buttonType == TYPE_ARMOR or buttonType == TYPE_TOOL then
        object = buildIButton(generateStandardFilterFunction(buttonType),
            lwui.inventoryButtonDefault, buttonType, crewId)
        --todo if limit
    elseif buttonType == TYPE_ANY then
        object = buildIButton(inventoryFilterFunctionAny, lwui.inventoryButtonFadedGayDefault, buttonType, crewId)
        object[GEX_CREW_ID] = crewId
    elseif buttonType == TYPE_SPACER then
        object = lwui.buildObject(0, 0, mCrewLineHeight/2 - mCrewLinePadding, mCrewLineHeight, tabOneStandardVisibility, NOOP)
    else
        error("GEX Unknown button type", buttonType)
    end
    return object
end

local function buildCrewRow(crewmem)
    local anim = lwui.buildObject(0, 0, mCrewLineHeight, mCrewLineHeight, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, .2, .2, .3)))
    local nameText = lwui.buildFixedTextBox(0, 0, mCrewLineNameWidth, mCrewLineHeight, tabOneStandardVisibility, NOOP, mCrewLineTextSize)
    nameText.text = crewmem:GetName()
    
    local horizContainer = lwui.buildHorizontalContainer(3, 0, 100, mCrewLineHeight, tabOneStandardVisibility, NOOP,
        {anim, nameText}, true, false, mCrewLinePadding)
    horizContainer[GEX_CREW_ID] = crewmem.extend.selfId
    
    local slotsDefinition = cels.getCrewSlots(crewmem.extend:GetDefinition().race)
    for _,defType in ipairs(slotsDefinition) do
        horizContainer.addObject(buildSingleButton(crewmem, defType))
    end
    return horizContainer
end

local function buildCrewEquipmentScrollBar()
    return lwui.buildVerticalContainer(0, 0, 300, 20, tabOneStandardVisibility, NOOP, {}, false, true, mCrewRowPadding)
end

local function constructEnhancementsLayout()
    --Left hand side
    mCrewListContainer = buildCrewEquipmentScrollBar()
    local crewListScrollWindow = lwui.buildVerticalScrollContainer(341, mEquipmentTabTop, 290, 370, tabOneStandardVisibility, mCrewListContainer, lwui.defaultScrollBarSkin)
    lwui.addTopLevelObject(crewListScrollWindow, "TABBED_WINDOW")
    --lwui.addTopLevelObject(ib1)
    local nameHeader = lwui.buildFixedTextBox(340, mTabTop, 260, 26, tabOneStandardVisibility, NOOP, 16)
    nameHeader.text = "       Name             Weapon Armor Tool"
    lwui.addTopLevelObject(nameHeader, "TABBED_WINDOW")
    
    --Lower right corner
    mDescriptionHeader = lwui.buildFixedTextBox(645, 348, 225, 35, tabOneStandardVisibility, NOOP, 18)--TODO AALL FIX
    mDescriptionHeader.text = NO_ITEM_SELECTED_TEXT
    lwui.addTopLevelObject(mDescriptionHeader, "TABBED_WINDOW")
    mDescriptionTextBox = lwui.buildDynamicHeightTextBox(0, 0, 245, 90, tabOneStandardVisibility, NOOP, 10)
    local descriptionTextScrollWindow = lwui.buildVerticalScrollContainer(643, 384, 260, 150, tabOneStandardVisibility, mDescriptionTextBox, lwui.testScrollBarSkin)
    lwui.addTopLevelObject(descriptionTextScrollWindow, "TABBED_WINDOW")

    --Upper right corner
    --It's a bunch of inventory buttons, representing how many slots you have to hold this stuff you don't have equipped currently.
    local inventoryHeader = lwui.buildFixedTextBox(622, mTabTop, 220, 26, tabOneStandardVisibility, NOOP, 14)
    inventoryHeader.text = "Inventory"
    lwui.addTopLevelObject(inventoryHeader, "TABBED_WINDOW")
    lwui.addTopLevelObject(buildInventoryContainer(), "TABBED_WINDOW")
    local trashY = 70
    local trashX = 876
    local trashButton = lwui.buildInventoryButton("TrashItemButton", trashX, 280 + trashY, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.spriteRenderFunction("items/trash.png"), inventoryFilterFunctionAny, trashItem, NOOP)
    lwui.addTopLevelObject(trashButton, "TABBED_WINDOW")
    local trashHeader = lwui.buildFixedTextBox(trashX - 2, 252 + trashY, 60, 35, tabOneStandardVisibility, NOOP, 16)
    trashHeader.text = "Sell"
    lwui.addTopLevelObject(trashHeader, "TABBED_WINDOW")
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
    if not lwce.isInitialized() then return end
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
                        cel.deleteItem(button, item)
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

function gex_remove_all_items()
    if mSetupFinished then
        resetInventory()
    end
    resetPersistedValues()
end

function gex_give_random_item(includeSecrets)
    if #mEquipmentGenerationTable == 0 then return end
    --todo avoid the secret stuff, then I can have my tiered up items and eat them too.
    local genIndex = math.random(1, #mEquipmentGenerationTable)
    if not includeSecrets then
        while #lwl.getNewElements({genIndex}, mSecretIndices) == 0 do
            print("Rolled a secret, rerolling", genIndex)
            genIndex = math.random(1, #mEquipmentGenerationTable)
        end
        print("Found something that was not a secret", genIndex)
    else
        print("Found something that could be a secret", genIndex)
    end
    
    return gex_give_item(genIndex)
end

--[[
After winning a battle, a chance to give one item.  Scales with TopScore.sector.  
--]]
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
    local itemChance = 0
    itemChance = itemChance + (event.stuff.scrap * .005)
    itemChance = itemChance + (event.stuff.fuel * .01)
    itemChance = itemChance + (event.stuff.drones * .026)
    itemChance = itemChance + (event.stuff.missiles * .023)
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
        gex_remove_all_items()
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