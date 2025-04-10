if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
--local userdata_table = mods.multiverse.userdata_table

--[[
--TODO my scroll nub scaling math is very off.


For the things I need for the UI to actually work, upon your crew list changing, (#crew changes, I think this works with people getting kicked off),
the crew scrollbar is regenerated.  Or at least the content is wiped and replaced with a new button list.
--Uh.  Maybe not, we do need to keep track of who has which equipment, and this is something we need to put in metatables as well.
The metavars should probably be the source of truth for who has what, and I rebuild the tables to reflect that.
Otherwise I could see messing up to easily.
--Probably a list of items and who owns them (-1 for inventory)
--No, that doesn't allow for duplicates.
Each crew will have three slots, which will be used for tracking what equipment they have in those slots.
Inventory will be INVENTORY_TYPE_N and hold the same.
Inventory is a lot easier to keep track of, as I know when that value changes.
    Once a crew is no longer on the ship, delete their inventory.
    Upon starting a new run, delete all inventory.

Here's how I build my memory:
NumCrew = n
GEX_CREW_[1-N]: IDs of those crewmembers
GEX_CREW_[ID]_[TYPE]: ID of equipment of that type equipped to crewmember.
Actually besides the type line, this is strong enough to put in LWL and consume it in MSCP, SICC, and GEX (this).

only need to build this list when opening this menu for the first time.  

here we get to the part that kind of conflicts when you have a GUI pushing up against active inventory.  I really don't want to rebuild Items, because each item should be something that persists with the users of said item.  I don't need to rebuild the inventory window, that can stay since it never gets invalidated.
However, the crew list is a different story.  I need to make sure that the people who are there are supposed to be there.  Recovering items upon crew loss is probably impossible.
If a crew dies to damage without clonebay, we should be able to save the items though.
This is enough of an issue that I probably need to put something into the library to handle this.  Incongruity between seen and felt reality.
TODO give different crew types different equipment slots.  Uniques and humans get all of them.  Likely elites as well.

currentItems[]: all item instances in the player's possession.  Each item instance will have a link back to the kind of item it is, or be generated from such a function.
There is a need to have a library that tracks which crew you have.  This is currently hard.
Basically, it should keep track of the crewIds on your ship, and understand how to update itself if that list changes.
It lets users register the point that they know about, and tells them what changed since then.
As usual, I'll build it inside this and pull it into lwl after its tested.
I don't need all this hooha if I can update the crew list in real time.  Then I don't have to recreate the whole thing from scratch each time, which is much better in many ways.
However, there's no getting around needing to reconstruct the UI upon loading.

--Also note that due to how I've constructed this, items may stick around after the crew using them has died, so I need to make sure the calls don't error.
--]]

--class needed for item storage, move this to lwl once things work.
local SelfIndexingList = {}
SelfIndexingList.__index = SelfIndexingList

function SelfIndexingList:new()
	local list = {
		items = {},
		length = 0
	}
	setmetatable(list, self)
	return list
end

-- Append a new item
function SelfIndexingList:append(item)
	self.length = self.length + 1
	item._index = self.length
	self.items[self.length] = item
end

-- Remove an item by index
function SelfIndexingList:remove(index)
	if index < 1 or index > self.length then return end

	table.remove(self.items, index)
	self.length = self.length - 1

	-- Reassign indices
	for i = index, self.length do
		self.items[i]._index = i
	end
end

-- Get item by index
function SelfIndexingList:get(index)
	return self.items[index]
end

-- Get item by index
function SelfIndexingList:size()
	return self.length
end

-- Print all items' indices
function SelfIndexingList:print()
	for i, item in ipairs(self.items) do
		print(i, "=>", item._index)
	end
end


local function getNewElements(newSet, initialSet)
    elements = {}
    for _, newElement in ipairs(newSet) do
        local wasPresent = false
        for _, oldElement in ipairs(initialSet) do
            if (oldElement == newElement) then
                wasPresent = true
                break
            end
        end
        if not wasPresent then
            table.insert(elements, newElement)
        end
    end
    
    return elements
end

local mCrewChangeObservers = {}
if (script) then
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        --Initialization code
        if not mGlobal then
            mGlobal = Hyperspace.Global.GetInstance()
        end
        local ownshipManager = mGlobal:GetShipManager(0)
        if (ownshipManager) then
            --update mCrewIds
            local playerCrew = lwl.getAllMemberCrew(ownshipManager)
            for _, crewChangeObserver in ipairs(mCrewChangeObservers) do
                crewChangeObserver.crew = {}
                for i=1,#playerCrew do
                    table.insert(crewChangeObserver.crew, playerCrew[i])--todo check if this compares correctly.
                end
            end
        end
    end)
end

--move this to a library.  Making this track crew for better utility
function createCrewChangeObserver()
    local crewChangeObserver = {}
    crewChangeObserver.crew = {}
    crewChangeObserver.lastSeenCrew = {}

    --actually no, just return a new object to all consumers so they don't conflict.
    local function saveLastSeenState()
        crewChangeObserver.lastSeenCrew = lwl.deepCopyTable(crewChangeObserver.crew)
    end
    --local function hasStateChanged()
    --Return arrays of the crew diff from last save.
    local function getAddedCrew()
        return getNewElements(crewChangeObserver.crew, crewChangeObserver.lastSeenCrew)
    end
    local function getRemovedCrew()
        return getNewElements(crewChangeObserver.lastSeenCrew, crewChangeObserver.crew)
    end
    
    crewChangeObserver.saveLastSeenState = saveLastSeenState
    crewChangeObserver.getAddedCrew = getAddedCrew
    crewChangeObserver.getRemovedCrew = getRemovedCrew
    table.insert(mCrewChangeObservers, crewChangeObserver)
    return crewChangeObserver
end


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

local mEquipmentList = {}
local KEY_NUM_EQUIPS = "GEX_CURRENT_EQUIPMENT_TOTAL"
local KEY_EQUIPMENT_GENERATING_INDEX = "GEX_EQUIPMENT_GENERATING_INDEX_"
local KEY_EQUIPMENT_ASSIGNMENT = "GEX_EQUIPMENT_ASSIGNMENT_"

local mSetupFinished = false
local mCrewChangeObserver = createCrewChangeObserver()
local mCrewListContainer
local mEquipmentGenerationTable = {}
local mNameToItemIndexTable = {}
local mTabbedWindow = ""
local mTab = 1
local mGlobal = Hyperspace.Global.GetInstance()
--Items must be added to this list when they are created or loaded
local mItemList = SelfIndexingList:new()
local mCrewLineHeight = 30
local mCrewLinePadding = 20
local mCrewRowPadding = 10
local mCrewLineNameWidth = 90
local mCrewLineTextSize = 11

local mInventoryButtons = {}

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

------------------------------------ITEM DEFINITIONS----------------------------------------------------------
--TODO need to make an array (enum) of these so I can get to them by index, the only thing I can store in a metavar.
--todo this doesn't have access to the index of the thing properly, I should just make a thing that gets and incs itself.
table.insert(mEquipmentGenerationTable, buildItemBuilder("Three-Way", TYPE_WEAPON, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 1, .8, 1)), "Hit two more people at the cost of decreased damage.", NOOP, NOOP))
table.insert(mEquipmentGenerationTable, buildItemBuilder("Seal Head", TYPE_ARMOR, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .8, 1, 1)), "The headbutts it enables are an effective counter to the ridicule you might encounter for wearing such odd headgear.", NOOP, NOOP))
local netgear = lwui.buildItem("Netgear", TYPE_TOOL, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, 1, 1, 1)),
        "A small disk which when deployed releases entangling nets.  Also serves as a wireless access point. Cooldown: two minutes.  Deploy nets in a room to slow all movement through it for twenty five seconds by 60%.  Single use for some reason.", NOOP, NOOP)


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

local function buildInventoryContainer()
    local verticalContainer = lwui.buildVerticalContainer(655, 137, 300, 20, tabOneStandardVisibility, NOOP,
            {}, false, true, 7)
    for i=1,inventoryRows do
        local horizContainer = lwui.buildHorizontalContainer(0, 0, 100, mCrewLineHeight, tabOneStandardVisibility, NOOP,
            {}, true, false, 7)
        for j=1,inventoryColumns do
            local buttonNum = ((i - 1) * inventoryRows) + j
            local button = lwui.buildInventoryButton(WEAPON_BUTTON_SUFFIX..buttonNum, 0, 0, mCrewLineHeight, mCrewLineHeight,
                    tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)),
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
        tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryFilterFunctionWeapon, buttonAddCrewmem)
    local armorButton = lwui.buildInventoryButton(crewmem.extend.selfId..ARMOR_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryFilterFunctionArmor, buttonAddCrewmem)
    local toolButton = lwui.buildInventoryButton(crewmem.extend.selfId..TOOL_BUTTON_SUFFIX, 0, 0, mCrewLineHeight, mCrewLineHeight,
        tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryFilterFunctionTool, buttonAddCrewmem)
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
    local ib1 = lwui.buildInventoryButton(name, 300, 30, EQUIPMENT_ICON_SIZE + 2, EQUIPMENT_ICON_SIZE + 2, tabOneStandardVisibility,
    lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryFilterFunctionEquipment, NOOP)
    ib1.addItem(mEquipmentGenerationTable[2]())--mNameToItemIndexTable["Seal Head"]]())--todo make a table of names to indexes.

    --Lower right corner
    local descriptionTextBox = lwui.buildDynamicHeightTextBox(0, 0, 215, 90, tabOneStandardVisibility, 10)
    local descriptionTextScrollWindow = lwui.buildVerticalScrollContainer(643, 384, 260, 150, tabOneStandardVisibility, descriptionTextBox, lwui.testScrollBarSkin)
    local longString = "Ok so this is a pretty long text box that's probably going to overflow the bounds of the text that created it lorum donor kit mama, consecutur rivus alterna nunc provinciamus."
    descriptionTextBox.text = longString



    local b3 = lwui.buildButton(300, 400, 25, 10, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
            function() print("thing dided") end, NOOP)

    --Left hand side
    mCrewListContainer = buildCrewEquipmentScrollBar()
    local crewListScrollWindow = lwui.buildVerticalScrollContainer(341, 139, 265, 400, tabOneStandardVisibility, mCrewListContainer, lwui.defaultScrollBarSkin)

    lwui.addTopLevelObject(crewListScrollWindow)
    lwui.addTopLevelObject(descriptionTextScrollWindow)
    lwui.addTopLevelObject(ib1)
    --Upper right corner
    --It's a bunch of inventory buttons, representing how many slots you have to hold this stuff you don't have equipped currently.
    --When things get added to the inventory, they'll find the first empty slot here.   So I need to group these buttons in a list somewhere.
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

if (script) then
    script.on_render_event(Defines.RenderEvents.TABBED_WINDOW, function() 
        --inMenu = true --todo why?
    end, function(tabName)
        --might need to put this in the reset category.
        if not mSetupFinished then
            printCrewIds()
            --resetPersistedValues() --todo remove
            print("Setting up items")
            mSetupFinished = true
            constructEnhancementsLayout()
            mCrewChangeObserver.saveLastSeenState()
            loadPersistedEquipment()
        end
        --print("tab name "..tabName)
        if tabName == ENHANCEMENTS_TAB_NAME then
            if not (mTabbedWindow == ENHANCEMENTS_TAB_NAME) then
                --todo rebuild based on missing/added crew
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
                            mCrewListContainer.objects = getNewElements(mCrewListContainer.objects, {crewContainer})--todo this is kind of experimental
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

--In the crew loop, each crew will check the items assigned to them and call their onTick functions, (pass themselves in?)
--It is the job of the items to do everything wrt their functionality.


        
    --Needing to rebuild these tables a lot is why we rely on the _persisted_ values as the source of truth for equipment status.
    --We do this on opening the tab if it's not set up, so that we make sure everything checks out.


    --[[might revisit this if someone tells me what these methods do.
    local anim = crewmem.crewAnim.anims[1] --TODO I guess we can cycle through these to be fancy but ok
    --render animation somewhere
    --decent chance this fucks up the crew animation, but I want to know what it does.
    anim.position = Hyperspace.Pointf(400, 0)
    anim:OnRender(1f, Graphics.GL_Color(1, 1, 1, 1), false)--]]

--uh, a function for selling these??  curently does not exist.  low priority but would be nice integration
--not any time soon,