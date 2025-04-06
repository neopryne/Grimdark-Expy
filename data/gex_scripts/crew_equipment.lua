if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
--local userdata_table = mods.multiverse.userdata_table

--[[

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

--]]
local function NOOP() end
local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local TYPE_WEAPON = "type_weapon"
local TYPE_ARMOR = "type_armor"
local TYPE_TOOL = "type_tool"
local EQUIPMENT_ICON_SIZE = 30 --todo adjust as is good

local mTabbedWindow = ""
local mTab = 1
--local mPage = 1--used to calculate which crew are displayed in the equipment loadout slots.  basically mPage % slots per page. Or do the scrolly thing, it's easier than I thought.

local function generateStandardVisibilityFunction(tabName, subtabIndex)
    return function()
        --print(tabName, mTab, subtabIndex, mTabbedWindow)
        --return true
        return mTab == subtabIndex and mTabbedWindow == tabName
    end
end
local tabOneStandardVisibility = generateStandardVisibilityFunction(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX)

------------------------------------INVENTORY FILTER FUNCTIONS----------------------------------------------------------

local function inventoryStorageFunctionAny(item)
    return true
end

local function inventoryStorageFunctionWeapon(item)
    return (item.itemType == TYPE_WEAPON)
end

local function inventoryStorageFunctionArmor(item)
    return (item.itemType == TYPE_ARMOR)
end

local function inventoryStorageFunctionTool(item)
    return (item.itemType == TYPE_TOOL)
end

local function inventoryStorageFunctionEquipment(item)
    return inventoryStorageFunctionWeapon(item) or 
            inventoryStorageFunctionArmor(item) or inventoryStorageFunctionTool(item)
end



local function buildCrewEquipmentScrollBar()
    local crewScrollBar
    
    --create a linear array of things.  This means containers need a render outside boundaries argument.
    --renderContentOutsideBounds
    
    return crewScrollBar
end


if (script) then
    script.on_render_event(Defines.RenderEvents.TABBED_WINDOW, function() 
        --inMenu = true --todo why?
    end, function(tabName)
        --print("tab name "..tabName)
        if tabName == ENHANCEMENTS_TAB_NAME then
            if not (mTabbedWindow == ENHANCEMENTS_TAB_NAME) then
                --do reset stuff
                --TODO create the crew scroll bar from persisted values
            end
        end
        mTabbedWindow = tabName
    end)
end

--In the crew loop, each crew will check the items assigned to them and call their onTick functions, (pass themselves in?)
--It is the job of the items to do everything wrt their functionality.

------------------------------------ITEM DEFINITIONS----------------------------------------------------------
local three_way = lwui.buildItem("Three-Way", TYPE_WEAPON, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 1, .8, 1)),
        "Hit two more people at the cost of decreased damage.", NOOP, NOOP)
local seal_head = lwui.buildItem("Seal Head", TYPE_ARMOR, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, .8, 1, 1)),
        "The headbutts it enables are an effective counter to and ridicule you might come under from wearing such odd headgear.", NOOP, NOOP)
local netgear = lwui.buildItem("Three-Way", TYPE_TOOL, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(.8, 1, 1, 1)),
        "It's gear made of nets.  Also serves as a wireless access point. Cooldown: two minutes.  Deploy nets in a room to slow all movement through it for twenty five seconds by 60%.  Single use for some reason.", NOOP, NOOP)
        




local ib1 = lwui.buildInventoryButton(name, 300, 30, EQUIPMENT_ICON_SIZE + 2, EQUIPMENT_ICON_SIZE + 2, tabOneStandardVisibility,
    lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionEquipment)
local ib2 = lwui.buildInventoryButton(name, 0, 0, EQUIPMENT_ICON_SIZE + 2, EQUIPMENT_ICON_SIZE + 2, tabOneStandardVisibility,
    lwui.solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionEquipment)
ib1.addItem(seal_head)
local t1 = lwui.buildDynamicHeightTextBox(0, 40, 60, 90, tabOneStandardVisibility, 8)
local longString = "Ok so this is a pretty long text box that's probably going to overflow the bounds of the text that created it lorum donor kit mama, consecutur rivus alterna nunc provinciamus."
t1.text = longString
print(t1.height)


local b1
b1 = lwui.buildButton(0, 0, 50, 50, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end, NOOP)
local b2 = lwui.buildButton(0, 49, 50, 50, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 0, 1, 1)), 
        function() print("thing dided2") end, NOOP)

local b4 = lwui.buildButton(400, 400, 50, 50, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 1, 0, 1)),
        function() print("thing dided") end, NOOP)

local c1 = lwui.buildVerticalContainer(20, 0, 10, 10, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {t1, ib2}, false, true, 10)
--[[c1.addObject(t1)
c1.addObject(ib2)
c1.addObject(b4)
--]]
--c2 = buildContainer(50, 100, 200, 200, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {c1})
local b3 = lwui.buildButton(300, 400, 25, 10, tabOneStandardVisibility, lwui.solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end, NOOP)

local s1 = lwui.buildVerticalScrollContainer(300, 300, 200, 100, tabOneStandardVisibility, c1)
print("c1: ", c1.height)
print("some other values: ", s1.contentContainer.height) --content height should never change, it's the virtual size of the thing inside, which I'm supposed to be updating on but also clearly isn't updating itself.  So.

lwui.addTopLevelObject(s1)
lwui.addTopLevelObject(b3)
lwui.addTopLevelObject(ib1)





--uh, a function for selling these??  curently does not exist.  low priority but would be nice integration
--not any time soon,