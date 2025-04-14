if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwcco = mods.lightweight_crew_change_observer
local lwsil = mods.lightweight_self_indexing_list
--local userdata_table = mods.multiverse.userdata_table

--[[
--TODO my scroll nub scaling math is very off.

Upon starting a new run, delete all inventory.


Recovering items upon crew loss is probably impossible.
If a crew dies to damage without clonebay, we should be able to save the items though.
TODO give different crew types different equipment slots.  Uniques and humans get all of them.  Likely elites as well.

--Also note that due to how I've constructed this, items may stick around after the crew using them has died, so I need to make sure the calls don't error.
--]]

----------------------------------------------------LIBRARY FUNCTIONS END----------------------
local function NOOP() end
local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local TYPE_WEAPON = "type_weapon"
local TYPE_ARMOR = "type_armor"
local TYPE_TOOL = "type_tool"
local EQUIPMENT_ICON_SIZE = 30 --todo adjust as is good
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
local mCrewChangeObserver = lwcco.createCrewChangeObserver()
local mCrewListContainer
local mEquipmentGenerationTable = {}
local mNameToItemIndexTable = {}
local mTabbedWindow = ""
local mTab = 1
local mGlobal = Hyperspace.Global.GetInstance()
--Items must be added to this list when they are created or loaded
local mItemList = lwsil.SelfIndexingList:new()
local mCrewLineHeight = 30
local mCrewLinePadding = 20
local mCrewRowPadding = 10
local mCrewLineNameWidth = 90
local mCrewLineTextSize = 11
local mTabTop = 139
local mEquipmentTabTop = mTabTop + EQUIPMENT_ICON_SIZE

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
local function buildItemBuilder(name, itemType, renderFunction, description, onCreate, onTick)
    local generating_index = #mEquipmentGenerationTable + 1
    return function()
        local builtItem = lwui.buildItem(name, itemType, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE,
                tabOneStandardVisibility, renderFunction, description, onCreate, onTick)
        builtItem.generating_index = generating_index
        mNameToItemIndexTable[name] = generating_index
        print("built item from index ", generating_index)
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

local function buttonAddInventory(button, item)
    --todo set the something to -1 I guess
    item.assigned_slot = -1
    persistEquipment()
end

local function buttonAddCrewmem(button, item)
    item.assigned_slot = button[GEX_CREW_ID]
    persistEquipment()
end

------------------------------------END INVENTORY FILTER FUNCTIONS----------------------------------------------------------
--Consider putting a row on top with the names of the column things.
--  Name, Weapon, Armor, Tool


------------------------------------ITEM STORAGE FUNCTIONS----------------------------------------------------------
--returns true if the item was able to be added, and false if there was no room.  Called when loading persisted inventory items or when obtaining new ones.
local function addToInventory(item)
    for _, iButton in ipairs(mInventoryButtons) do
        if (iButton.addItem(item)) then
            return true
        end
    end
    return false
end

local function addToCrew(item, crewId)
    for _, crewContainer in ipairs(mCrewListContainer.objects) do
        print("checking row ", crewContainer[GEX_CREW_ID])
        if (crewContainer[GEX_CREW_ID] == crewId) then
            print("crew found, adding ", item.name)
            for _, iButton in ipairs(crewContainer.objects) do
                if (iButton.className == "inventoryButton") then
                    print("trying to add item to ", iButton.className)
                    if iButton.addItem(item) then
                        return true
                    end
                end
            end
        end
    end
    return false
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
    print("persisting ", numEquipment, " items")
    local successes = 0
    for i=1,numEquipment do
        local equipment = mItemList:get(i)
        if (equipment.generating_index == nil) or (equipment.assigned_slot == nil) then
            print("ERROR: could not persist item: incomplete values.")
        else
            successes = successes + 1
            print("persisting ", equipment.name, " genIndx ", equipment.generating_index, " slot ", equipment.assigned_slot)
            Hyperspace.metaVariables[KEY_EQUIPMENT_GENERATING_INDEX..successes] = equipment.generating_index --todo create this
            Hyperspace.metaVariables[KEY_EQUIPMENT_ASSIGNMENT..successes] = equipment.assigned_slot--todo I need to set this value properly
        end
    end
    Hyperspace.metaVariables[KEY_NUM_EQUIPS] = successes
    print("persisted ", successes , " out of ", numEquipment)
end

local function resetPersistedValues()
    Hyperspace.metaVariables[KEY_NUM_EQUIPS] = 0
end

local function loadPersistedEquipment()
    local numEquipment = Hyperspace.metaVariables[KEY_NUM_EQUIPS]
    print("loading ", numEquipment, " items")
    for i=1,numEquipment do
        local generationTableIndex = Hyperspace.metaVariables[KEY_EQUIPMENT_GENERATING_INDEX..i]
        print("index ", generationTableIndex)
        local item = mEquipmentGenerationTable[generationTableIndex]()
        local position = Hyperspace.metaVariables[KEY_EQUIPMENT_ASSIGNMENT..i]
        print("loading ", item.name, " genIndx ", item.generating_index, " slot ", item.assigned_slot)
        if position == -1 then
            if (addToInventory(item)) then
                --mItemList:append(item)
            end
        else
            --mItemList:append(item)
            if not addToCrew(item, position) then
                print("ERROR: Failed to load item ", item.name)
            end
        end
        print("loaded item ", item.name, position)
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
    local nameText = lwui.buildFixedTextBox(0, 0, mCrewLineNameWidth, mCrewLineHeight, tabOneStandardVisibility, mCrewLineTextSize)
    nameText.text = crewmem:GetName()
    local weaponButton = lwui.buildInventoryButton(crewmem.extend.selfId..WEAPON_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.inventoryButtonDefault, inventoryFilterFunctionWeapon, buttonAddCrewmem)
    local armorButton = lwui.buildInventoryButton(crewmem.extend.selfId..ARMOR_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.inventoryButtonDefault, inventoryFilterFunctionArmor, buttonAddCrewmem)
    local toolButton = lwui.buildInventoryButton(crewmem.extend.selfId..TOOL_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.inventoryButtonDefault, inventoryFilterFunctionTool, buttonAddCrewmem)
    local horizContainer = lwui.buildHorizontalContainer(3, 0, 100, mCrewLineHeight, tabOneStandardVisibility, NOOP,
        {nameText, weaponButton, armorButton, toolButton}, true, false, mCrewLinePadding)
    --kind of dirty to apply it to all of these but it's not that bad.
    horizContainer[GEX_CREW_ID] = crewmem.extend.selfId
    weaponButton[GEX_CREW_ID] = crewmem.extend.selfId
    armorButton[GEX_CREW_ID] = crewmem.extend.selfId
    toolButton[GEX_CREW_ID] = crewmem.extend.selfId
    return horizContainer
end

local function buildCrewEquipmentScrollBar()
    local crewScrollBar

    local ownshipManager = mGlobal:GetShipManager(0)
    local playerCrew = lwl.getAllMemberCrew(ownshipManager)
    
    local verticalContainer = lwui.buildVerticalContainer(0, 0, 300, 20, tabOneStandardVisibility, NOOP,
        {nameText, weaponButton, armorButton, toolButton}, false, true, mCrewRowPadding)
    for i=1,#playerCrew do
        verticalContainer.addObject(buildCrewRow(playerCrew[i]))
    end
    
    return verticalContainer
end

local function constructEnhancementsLayout()
    --[[
    local t1 = lwui.buildDynamicHeightTextBox(0, 0, 120, 40, tabOneStandardVisibility, 12)
    t1.text = "Ok so this is a pretty long text box that's probably going to overflow the bounds of the text that created it lorum donor kit mama, consecutur rivus alterna nunc provinciamus."
    local c1 = lwui.buildContainer(700, 60, 60, 60, tabOneStandardVisibility, 
        lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, .3)), {t1}, false, false)
    lwui.addTopLevelObject(c1)--]]
    
    
    local ib1 = lwui.buildInventoryButton(name, 300, 30, EQUIPMENT_ICON_SIZE + 2, EQUIPMENT_ICON_SIZE + 2, tabOneStandardVisibility,
    lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryFilterFunctionEquipment, NOOP)--todo remove this testing element
    ib1.addItem(mEquipmentGenerationTable[2]())--mNameToItemIndexTable["Seal Head"]]())--todo make a table of names to indexes.  or maybe just randomly pick one every time.

    --Left hand side
    mCrewListContainer = buildCrewEquipmentScrollBar()
    local crewListScrollWindow = lwui.buildVerticalScrollContainer(341, mEquipmentTabTop, 265, 370, tabOneStandardVisibility, mCrewListContainer, lwui.defaultScrollBarSkin)
    lwui.addTopLevelObject(crewListScrollWindow)
    lwui.addTopLevelObject(ib1)
    local nameHeader = lwui.buildFixedTextBox(340, mTabTop, 260, 26, tabOneStandardVisibility, 16)
    nameHeader.text = "   Name          Weapon   Armor   Tool"
    lwui.addTopLevelObject(nameHeader)
    
        --653, 334
        --Lower right corner
    mDescriptionHeader = lwui.buildFixedTextBox(660, 348, 215, 40, tabOneStandardVisibility, 18)
    mDescriptionHeader.text = NO_ITEM_SELECTED_TEXT
    lwui.addTopLevelObject(mDescriptionHeader)
    mDescriptionTextBox = lwui.buildDynamicHeightTextBox(0, 0, 215, 90, tabOneStandardVisibility, 10)
    local descriptionTextScrollWindow = lwui.buildVerticalScrollContainer(643, 384, 260, 150, tabOneStandardVisibility, mDescriptionTextBox, lwui.testScrollBarSkin)
    local longString = "Ok so this is a pretty long text box that's probably going to overflow the bounds of the text that created it lorum donor kit mama, consecutur rivus alterna nunc provinciamus."
    mDescriptionTextBox.text = longString
    lwui.addTopLevelObject(descriptionTextScrollWindow)

    --Upper right corner
    --It's a bunch of inventory buttons, representing how many slots you have to hold this stuff you don't have equipped currently.
    --When things get added to the inventory, they'll find the first empty slot here.   So I need to group these buttons in a list somewhere.
    local inventoryHeader = lwui.buildFixedTextBox(622, mTabTop, 225, 26, tabOneStandardVisibility, 14)
    inventoryHeader.text = "Inventory"
    lwui.addTopLevelObject(inventoryHeader)
    lwui.addTopLevelObject(buildInventoryContainer())
    print("stuff readied")
end

--[[
Everything except for which equipment goes where is something we can build without special data structures storing things.
With that in mind, I propose a new format
Number of equipment currently in use
equipment_N: gives the index of the equipment generating function array used to make this equipment.
equipment_location_N: gives -2 if no longer in use, -1 for inventory slot, or crewId if attached to a crew member.
that's it, no fancy saving or loading stuff.
--]]

local function printCrewIds()
    local ownshipManager = mGlobal:GetShipManager(0)
    if (ownshipManager) then
        --update mCrewIds
        local playerCrew = lwl.getAllMemberCrew(ownshipManager)
        for i=1,#playerCrew do
            local crewmem = playerCrew[i]
            print(crewmem:GetName(), " has id ", crewmem.extend.selfId)
        end
    end
end
------------------------------------END GUI CREATION----------------------------------------------------------

------------------------------------REALTIME EVENTS----------------------------------------------------------
local function tickEquipment()
    local ownshipManager = mGlobal:GetShipManager(0)
    if not ownshipManager then return end
    local playerCrew = lwl.getAllMemberCrew(ownshipManager)
    for _,crewmem in ipairs(playerCrew) do
        local equips = getCrewEquipment(crewmem)
        --print("ticking", crewmem:GetName(), "has ", #equips, "equipment")
        for _,item in ipairs(equips) do
            --print("ticking", crewmem:GetName(), "'s", item.name)
            item.onTick(item, crewmem)
        end
    end
end

if (script) then
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        if not mGlobal:GetShipManager(0) then return end
        if not mSetupFinished then
            printCrewIds()
            --resetPersistedValues() --todo remove
            print("Setting up items")
            mSetupFinished = true
            constructEnhancementsLayout()
            mCrewChangeObserver.saveLastSeenState()
            loadPersistedEquipment()
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
    end)
    
    script.on_render_event(Defines.RenderEvents.TABBED_WINDOW, function() 
        --inMenu = true --todo why?
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
                mDescriptionTextBox.text = buttonContents.description
            end
            
            if not (mTabbedWindow == ENHANCEMENTS_TAB_NAME) then
                mDescriptionHeader.text = NO_ITEM_SELECTED_TEXT
                mDescriptionTextBox.text = ""
                --rebuild based on missing/added crew
                local addedCrew = mCrewChangeObserver.getAddedCrew()
                local removedCrew = mCrewChangeObserver.getRemovedCrew()
                for _, crewmem in ipairs(removedCrew) do
                    print("removing ", crewmem:GetName())
                    local removedLines = {}
                    --remove existing row
                    for _, crewContainer in ipairs(mCrewListContainer.objects) do
                        print("checking row ", crewContainer[GEX_CREW_ID])
                        if (crewContainer[GEX_CREW_ID] == crewmem.extend.selfId) then
                            print("found match! ")
                            print("there were N crew ", #mCrewListContainer.objects)
                            table.insert(removedLines, crewContainer)
                            mCrewListContainer.objects = lwl.getNewElements(mCrewListContainer.objects, {crewContainer})--todo this is kind of experimental
                            print("there are now N crew ", #mCrewListContainer.objects)
                        end
                    end
                    --remove all the items in removedLines
                    for _, line in ipairs(removedLines) do
                        for _, button in ipairs(line.objects) do
                            if (button.item) then
                                mItemList:remove(button.item._index)
                                print("removed item ", button.item._index)
                            end
                        end
                    end
                    --needs remove any equipped items from the mItemList, then re-persist data.
                end
                for i=1,#addedCrew do
                    for _, crewmem in ipairs(addedCrew) do
                        mCrewListContainer.addObject(buildCrewRow(crewmem))
                    end
                end
                
                if (#addedCrew > 0 or #removedCrew > 0) then
                    print("num crew changed since last update")
                    persistEquipment()
                end
                mCrewChangeObserver.saveLastSeenState()
            end
        end
        mTabbedWindow = tabName
    end)--todo persist after tab window closed, probably. not on jump.
end
------------------------------------END REALTIME EVENTS----------------------------------------------------------

--todo dps to damage per fulltick converter
--[[
Ballanceator armor: As all things should be.  If crew is below half health, heal them for 1, otherwise, damage them
--]]

--maybe I want a onEquip/onUnequip methods?  Maybe I don't need onCreate and I can just do like if _ = nil create _.
local function sealHead(item, crewmem)
    --
end

local function Ballanceator(item, crewmem)
    local dpt = .085
    if (crewmem:GetIntegerHealth() > crewmem:GetMaxHealth() / 2) then
        crewmem:DirectModifyHealth(-dpt)
    else
        crewmem:DirectModifyHealth(dpt)
    end
end
------------------------------------ITEM DEFINITIONS----------------------------------------------------------
--TODO need to make an array (enum) of these so I can get to them by index, the only thing I can store in a metavar.
--todo this doesn't have access to the index of the thing properly, I should just make a thing that gets and incs itself.
table.insert(mEquipmentGenerationTable, buildItemBuilder("Three-Way", TYPE_WEAPON, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 1, .8, 1)), "Hit two more people at the cost of decreased damage.", NOOP, NOOP))
table.insert(mEquipmentGenerationTable, buildItemBuilder("Seal Head", TYPE_ARMOR, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .8, 1, 1)), "The headbutts it enables are an effective counter to the ridicule you might encounter for wearing such odd headgear.", NOOP, NOOP))
table.insert(mEquipmentGenerationTable, buildItemBuilder("Gas Mask", TYPE_TOOL, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, 1, 1, 1)), "Old construction, but still just as airtight as ever.  Confers immunity to shell gas.", NOOP, NOOP))
table.insert(mEquipmentGenerationTable, buildItemBuilder("Ballancator", TYPE_ARMOR, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, .8, 1, 1)), "As all things should be.  Strives to keep its wearer at exactly half health.", NOOP, Ballanceator))




------------------------------------END ITEM DEFINITIONS----------------------------------------------------------
-----------------------------------------WAYS TO GET ITEMS---------------------------------------------------------------
function gex_give_equipment(index)
    local equip = mEquipmentGenerationTable[index]()
    addToInventory(equip)
    return equip
end

function gex_give_random_equip()
    if #mEquipmentGenerationTable == 0 then return end
    return gex_give_equipment(math.random(1, #mEquipmentGenerationTable))
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
        local equip = gex_give_random_equip()
        event.text.data = event.text.data.."\nYou find a "..equip.name.." mixed in with the scrap."
    end
    print("itemChancepre", itemChance)
    print("itemChance", itemChance)
end)


--In the crew loop, each crew will check the items assigned to them and call their onTick functions, (pass themselves in?)
--It is the job of the items to do everything wrt their functionality.
--"Cursed" items that can't be unequipped

        
    --Needing to rebuild these tables a lot is why we rely on the _persisted_ values as the source of truth for equipment status.
    --We do this on opening the tab if it's not set up, so that we make sure everything checks out.


    --[[
    local netgear = lwui.buildItem("Netgear", TYPE_TOOL, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, 1, 1, 1)),
        "A small disk which when deployed releases entangling nets.  Also serves as a wireless access point. Cooldown: two minutes.  Deploy nets in a room to slow all movement through it for twenty five seconds by 60%.  Single use for some reason.", NOOP, NOOP)
    Deeply fucked, requires me to have an active button for tools.  That sounds awful.  Actually it sounds not that bad, I'll circle back to this after I have some more items finished.
    
    might revisit this if someone tells me what these methods do.
    local anim = crewmem.crewAnim.anims[1] --TODO I guess we can cycle through these to be fancy but ok
    --render animation somewhere
    --decent chance this fucks up the crew animation, but I want to know what it does.
    anim.position = Hyperspace.Pointf(400, 0)
    anim:OnRender(1f, Graphics.GL_Color(1, 1, 1, 1), false)--]]

--uh, a function for selling these??  curently does not exist.  low priority but would be nice integration
--not any time soon,