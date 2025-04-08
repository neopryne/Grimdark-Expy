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
                crewChangeObserver.crewIds = {}
                for i=1,#playerCrew do
                    table.insert(crewChangeObserver.crewIds, playerCrew[i].extend.selfId)
                end
            end
        end
    end)
end
--move this to a library
function createCrewChangeObserver()
    local crewChangeObserver = {}
    crewChangeObserver.crewIds = {}
    crewChangeObserver.lastSeenIds = {}

    --actually no, just return a new object to all consumers so they don't conflict.
    local function saveLastSeenState()
        crewChangeObserver.lastSeenIds = lwl.deepCopyTable(crewChangeObserver.crewIds)
    end
    --local function hasStateChanged()
    --Return arrays of the crew diff from last save.
    local function getAddedCrew()
        return getNewElements(crewChangeObserver.crewIds, crewChangeObserver.lastSeenIds)
    end
    local function getRemovedCrew()
        return getNewElements(crewChangeObserver.lastSeenIds, crewChangeObserver.crewIds)
    end
    
    crewChangeObserver.saveLastSeenState = saveLastSeenState
    crewChangeObserver.getAddedCrew = getAddedCrew
    crewChangeObserver.getRemovedCrew = getRemovedCrew
    table.insert(mCrewChangeObservers, crewChangeObserver)
    return crewChangeObserver
end





local function NOOP() end
local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local TYPE_WEAPON = "type_weapon"
local TYPE_ARMOR = "type_armor"
local TYPE_TOOL = "type_tool"
local EQUIPMENT_ICON_SIZE = 30 --todo adjust as is good

local mCrewChangeObserver = createCrewChangeObserver()

local mTabbedWindow = ""
local mTab = 1
local mGlobal = Hyperspace.Global.GetInstance()

--local mPage = 1--used to calculate which crew are displayed in the equipment loadout slots.  basically mPage % slots per page. Or do the scrolly thing, it's easier than I thought.
local function generateStandardVisibilityFunction(tabName, subtabIndex)
    return function()
        --print(tabName, mTab, subtabIndex, mTabbedWindow)
        --return true
        return mTab == subtabIndex and mTabbedWindow == tabName
    end
end
local tabOneStandardVisibility = generateStandardVisibilityFunction(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX)

------------------------------------ITEM DEFINITIONS----------------------------------------------------------
--TODO need to make an array (enum) of these so I can get to them by index, the only thing I can store in a metavar.
local three_way = lwui.buildItem("Three-Way", TYPE_WEAPON, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 1, .8, 1)),
        "Hit two more people at the cost of decreased damage.", NOOP, NOOP)
local seal_head = lwui.buildItem("Seal Head", TYPE_ARMOR, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .8, 1, 1)),
        "The headbutts it enables are an effective counter to and ridicule you might come under from wearing such odd headgear.", NOOP, NOOP)
local netgear = lwui.buildItem("Netgear", TYPE_TOOL, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, 1, 1, 1)),
        "It's gear made of nets.  Also serves as a wireless access point. Cooldown: two minutes.  Deploy nets in a room to slow all movement through it for twenty five seconds by 60%.  Single use for some reason.", NOOP, NOOP)
print("seal head is: ", seal_head.itemType)

------------------------------------INVENTORY FILTER FUNCTIONS----------------------------------------------------------

local function inventoryStorageFunctionAny(item)
    return true
end

local function inventoryStorageFunctionWeapon(item)
    return (item ~= nil and item.itemType == TYPE_WEAPON)
end

local function inventoryStorageFunctionArmor(item)
    return (item ~= nil and item.itemType == TYPE_ARMOR)
end

local function inventoryStorageFunctionTool(item)
    return (item ~= nil and item.itemType == TYPE_TOOL)
end

local function inventoryStorageFunctionEquipment(item)
    return inventoryStorageFunctionWeapon(item) or 
            inventoryStorageFunctionArmor(item) or inventoryStorageFunctionTool(item)
end




local function animRenderFunction(animation)
    
    
end
--Consider putting a row on top with the names of the column things.

--  Name, Weapon, Armor, Tool

local WEAPON_BUTTON_SUFFIX = "_weapon_button"
local ARMOR_BUTTON_SUFFIX = "_armor_button"
local TOOL_BUTTON_SUFFIX = "_tool_button"
local INVENTORY_BUTTON_PREFIX = "inventory_button_"

local crewLineHeight = 30
local crewLinePadding = 20
local crewRowPadding = 10
local crewLineNameWidth = 90
local crewLineTextSize = 11

local inventoryButtons = {}


local inventoryRows = 5
local inventoryColumns = 6
local function buildInventoryContainer()
    local verticalContainer = lwui.buildVerticalContainer(655, 137, 300, 20, tabOneStandardVisibility, NOOP,
            {}, false, true, 7)
    for i=1,inventoryRows do
        local horizContainer = lwui.buildHorizontalContainer(0, 0, 100, crewLineHeight, tabOneStandardVisibility, NOOP,
            {}, true, false, 7)
        for j=1,inventoryColumns do
            local buttonNum = ((i - 1) * inventoryRows) + j
            local button = lwui.buildInventoryButton(WEAPON_BUTTON_SUFFIX..buttonNum, 0, 0, crewLineHeight, crewLineHeight,
                    tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionEquipment)
            horizContainer.addObject(button)
            table.insert(inventoryButtons, button)
        end
        verticalContainer.addObject(horizContainer)
    end
    return verticalContainer
end


local function buildCrewEquipmentScrollBar()
    local crewScrollBar

    local ownshipManager = mGlobal:GetShipManager(0)
    local playerCrew = lwl.getAllMemberCrew(ownshipManager)
    
    local verticalContainer = lwui.buildVerticalContainer(0, 0, 300, 20, tabOneStandardVisibility, NOOP,
        {nameText, weaponButton, armorButton, toolButton}, false, true, crewRowPadding)
    
    for i=1,#playerCrew do
        local crewmem = playerCrew[i]
        local nameText = lwui.buildFixedTextBox(0, 0, crewLineNameWidth, crewLineHeight, tabOneStandardVisibility, crewLineTextSize)
        nameText.text = crewmem:GetName()
        local weaponButton = lwui.buildInventoryButton(crewmem.extend.selfId..WEAPON_BUTTON_SUFFIX, 0, 0, crewLineHeight, crewLineHeight,
            tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionWeapon)
        local armorButton = lwui.buildInventoryButton(crewmem.extend.selfId..ARMOR_BUTTON_SUFFIX, 0, 0, crewLineHeight, crewLineHeight,
            tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionArmor)
        local toolButton = lwui.buildInventoryButton(crewmem.extend.selfId..TOOL_BUTTON_SUFFIX, 0, 0, crewLineHeight, crewLineHeight,
            tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionTool)
        local horizContainer = lwui.buildHorizontalContainer(3, 0, 100, crewLineHeight, tabOneStandardVisibility, NOOP,
            {nameText, weaponButton, armorButton, toolButton}, true, false, crewLinePadding)
        verticalContainer.addObject(horizContainer)
    end
    --create a linear array of things.  This means containers need a render outside boundaries argument.
    --renderContentOutsideBounds
    
    return verticalContainer
end

local function constructEnhancementsLayout()
    local ib1 = lwui.buildInventoryButton(name, 300, 30, EQUIPMENT_ICON_SIZE + 2, EQUIPMENT_ICON_SIZE + 2, tabOneStandardVisibility,
    lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionEquipment)
    ib1.addItem(seal_head) --TODO this seems to not be being added properly.
    
    
    --It's a bunch of inventory buttons, representing how many slots you have to hold this stuff you don't have equipped currently.
    --When things get added to the inventory, they'll find the first empty slot here.   So I need to group these buttons in a list somewhere.
    
    
    --Lower right corner
    local descriptionTextBox = lwui.buildDynamicHeightTextBox(0, 0, 215, 90, tabOneStandardVisibility, 10)
    local descriptionTextScrollWindow = lwui.buildVerticalScrollContainer(643, 384, 260, 150, tabOneStandardVisibility, descriptionTextBox, lwui.testScrollBarSkin)
    local longString = "Ok so this is a pretty long text box that's probably going to overflow the bounds of the text that created it lorum donor kit mama, consecutur rivus alterna nunc provinciamus."
    descriptionTextBox.text = longString



    local b3 = lwui.buildButton(300, 400, 25, 10, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
            function() print("thing dided") end, NOOP)

    --Left hand side
    local crewListScrollWindow = lwui.buildVerticalScrollContainer(341, 139, 265, 400, tabOneStandardVisibility, buildCrewEquipmentScrollBar(), lwui.testScrollBarSkin)

    lwui.addTopLevelObject(crewListScrollWindow)
    lwui.addTopLevelObject(descriptionTextScrollWindow)
    lwui.addTopLevelObject(ib1)
    --Upper right corner
    lwui.addTopLevelObject(buildInventoryContainer())
    print("stuff readied")
end


local mSetupFinished = false

local mEquipmentList = {}
local KEY_NUM_EQUIPS = "GEX_CURRENT_EQUIPMENT_TOTAL"
local KEY_EQUIPMENT_GENERATING_INDEX = "GEX_EQUIPMENT_GENERATING_INDEX_"
local KEY_EQUIPMENT_ASSIGNMENT = "GEX_EQUIPMENT_ASSIGNMENT_"

local function persistEquipment()
    local numEquipment = #mEquipmentList
    Hyperspace.metaVariables[KEY_NUM_EQUIPS] = numEquipment
    for i=1,numEquipment do
        local equipment = mItemList[i]
        Hyperspace.metaVariables[KEY_EQUIPMENT_GENERATING_INDEX..i] = equipment.generating_index --todo probably a better way to do this
        Hyperspace.metaVariables[KEY_EQUIPMENT_ASSIGNMENT..i] = equipment.assigned_slot
    end
end

local function loadPersistedEquipment()
    local numEquipment = Hyperspace.metaVariables[KEY_NUM_EQUIPS]
    for i=1,numEquipment do
        local generationTableIndex = Hyperspace.metaVariables[KEY_EQUIPMENT_GENERATING_INDEX..i]
        local equip = equipmentGenerationTable[generationTableIndex]()
        local position = Hyperspace.metaVariables[KEY_EQUIPMENT_ASSIGNMENT..i]
        if position == -1 then
            addToInventory(equip)
        else
            --figure out how to get it onto its person.
        end
    end
end


--[[
Everything except for which equipment goes where is something we can build without special data structures storing things.
With that in mind, I propose a new format
Number of equipment currently in use
equipment_N: gives the index of the equipment generating function array used to make this equipment.
equipment_location_N: gives -1 for inventory slot, or crewId if attached to a crew member.
that's it, no fancy saving or loading stuff.
--]]

if (script) then
    script.on_render_event(Defines.RenderEvents.TABBED_WINDOW, function() 
        --inMenu = true --todo why?
    end, function(tabName)
        --might need to put this in the reset category.
        if not mSetupFinished then
            print("Setting up items")
            mSetupFinished = true
            constructEnhancementsLayout()
            mCrewChangeObserver.saveLastSeenState()
            --loadPersistedEquipment()
        end
        --print("tab name "..tabName)
        if tabName == ENHANCEMENTS_TAB_NAME then
            if not (mTabbedWindow == ENHANCEMENTS_TAB_NAME) then
                --todo rebuild based on missing/added crew
                local addedCrew = mCrewChangeObserver.getAddedCrew()
                local removedCrew = mCrewChangeObserver.getRemovedCrew()
                for i=1,#removedCrew do
                    --remove existing row
                end
                for i=1,#addedCrew do
                    --add new row
                end
                mCrewChangeObserver.saveLastSeenState()
            end
            
            --Persist equipment status
            --persistEquipment()
        end
        mTabbedWindow = tabName
    end)
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