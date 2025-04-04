if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
--local userdata_table = mods.multiverse.userdata_table
--TODO fullscreen position math needs fixing.

--any object capable of holding another object must have a function that passes down renderWrapping, and one for any other such operators.
--todo I broke everything somehow

--[[

Functions are built to deal with objects (renderable).
Objects are tables, so you can add fields to them as you see fit.

Internal fields:
getPos() --Call to get an table {x=x, y=y}.  This is the absolute position of the object on screen.

Object {x,y,getPos,height,width,visibilityFunction,renderFunction} --x and y are relative to the containing object, or the global UI if top level.
--Button {onClick, enabledFunction} --enabled tells the button if it should work or not, some buttons have different render states based on this as well.
--Container {Objects} (Abstract, if that makes any sense.)
----Scroll Bar {internals={scrollUpButton, scrollDown, scrollBar, scrollCursor}} (barWidth?  maybe I'll make a scroll bar graphics template, and include the base package with this.)
----Button Group {padding?}

special
(means I have to stretch the nub for these, it will include renderFunctions for the buttons that get image assets)
scroll buttons must be square.  That's the law, it will throw you an error otherwise.
--ScrollBarGraphicAssets(scrollUp, nubImage, renderScrollButton)
--]]
local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local TYPE_WEAPON = "type_weapon"
local TYPE_ARMOR = "type_armor"
local TYPE_TOOL = "type_tool"
local function NOOP() end

local function isWithinMask(mousePos, mask)
    return mousePos.x >= mask.getPos().x and mousePos.x <= mask.getPos().x + mask.width and
           mousePos.y >= mask.getPos().y and mousePos.y <= mask.getPos().y + mask.height
end

local mTabbedWindow = ""
local mTab = 1
--local mPage = 1--used to calculate which crew are displayed in the equipment loadout slots.  basically mPage % slots per page. Or do the scrolly thing, it's easier than I thought.
--Objects to be rendered go here.  Visible buttons are clickable.
local mTopLevelRenderList = {}
local mHoveredButton = nil
local mHoveredScrollContainer = nil
local mClickedButton = nil --mouseUp will be called on this.

local function generateStandardVisibilityFunction(tabName, subtabIndex)
    return function()
        --print(tabName, mTab, subtabIndex, mTabbedWindow)
        --return true
        return mTab == subtabIndex and mTabbedWindow == tabName
    end
end
local tabOneStandardVisibility = generateStandardVisibilityFunction(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX)


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





--todo the base renderFunction needs to take a mask, but I don't think any of the object versions need to, they all pass themselves as the argument to it.
--

--Define the size of the scroll window
--Fixed size for scroll bar width and button height.
--It is responsible for shifting the position of the thing it is rendering and putting the stencil around it.

--Objects must be registered somehow with the topLevelRenderList to appear, be visible, and thus be interacted with.
--All items constructed from this point down are objects.

--Basic things that are visible, but have no other features.
--Render functions for pure objects should return false or it will break the button logic.
local function createObject(x, y, width, height, visibilityFunction, renderFunction)
    local object = {}
    local function renderObject(mask)
        --print("should render? ", visibilityFunction())
        if not object.visibilityFunction then
            print("ERROR: vis func for object ", object.getPos().x, ", ", object.getPos().y, " is nil!")
            return true
        end
        if object.visibilityFunction() then
            return renderFunction(object.maskFunction())
        end
    end
    
    local function getPosition()
        --print("getPosition x ", x, " y ", y)
        return {x=object.x, y=object.y}
    end
    
    local function maskFunctionNoOp() --mask has only x, y, width, height, can't be concave with current settings.
        return object
    end
    
    local function setMaskFunction(maskFunc)
        object.maskFunction = maskFunc
    end
    
    object.x = x
    object.y = y
    object.getPos = getPosition
    object.width = width
    object.height = height
    object.visibilityFunction = visibilityFunction --still using this for tab-based visibility, just not positonal vis.
    object.renderFunction = renderObject
    object.setMaskFunction = setMaskFunction
    object.maskFunction = maskFunctionNoOp --call this each frame to get the mask to pass to render func.
    return object
end

--onClick(x, y): args being passed are global position of the cursor when click occurs.
local function buildButton(x, y, width, height, visibilityFunction, renderFunction, onClick, onRelease)--todo order changed, update calls.
    if not (onRelease) then onRelease = NOOP end
    if not (onClick) then onClick = NOOP end
    local button
    local function buttonClick(x1, y1)
        if button.visibilityFunction then
            onClick(x1, y1)
        end
    end
    
    local function renderButton(mask)
        local hovering = false
        local mousePos = Hyperspace.Mouse.position
        local buttonMask = button.maskFunction()
        if isWithinMask(mousePos, buttonMask) then
            hovering = true
            if not (mHoveredButton == button) then
                print("button_hovered ", button)
                mHoveredButton = button
            end
        end
        renderFunction(button.maskFunction())
        return hovering
    end
    
    button = createObject(x, y, width, height, visibilityFunction, renderButton)
    button.onClick = buttonClick
    button.onRelease = onRelease
    return button
end

--todo move
--a mask is an object, so this also returns an function that returns an object.
local function combineMasks(object1, object2)
    local maskFunction1 = object1.maskFunction --in the base case, these masks are the objects themselves, and will have all properties of an object.
    local maskFunction2 = object2.maskFunction
    
    local function combinedMaskFunction()
        local mask1 = maskFunction1() --in the base case, these masks are the objects themselves, and will have all properties of an object.
        local mask2 = maskFunction2()
        local x1 = mask1.getPos().x
        local y1 = mask1.getPos().y
        local x2 = mask2.getPos().x
        local y2 = mask2.getPos().y
        local x = math.max(x1, x2)
        local y = math.max(y1, y2)
        local width = math.max(0, math.min(x1 + mask1.width, x2 + mask2.width) - x)
        local height = math.max(0, math.min(y1 + mask1.height, y2 + mask2.height) - y)
        --print("combinedMask: ", x, y, width, height, " xs ", x1, x2, " ys ", y1 , y2)
        local combinedMask = createObject(x, y, width, height, NOOP, NOOP)
        return combinedMask
    end
    
    return combinedMaskFunction
end

--Once a scroll bar is created, adding things to it means adding things to the content container.
--This requires a dynamic container update method.  Probably worth having.
--.addObject(object)
--no way to remove objects currently.  Do it with your visFunc, I guess.
local function buildContainer(x, y, width, height, visibilityFunction, renderFunction, objects, renderOutsideBounds)
    local container
    --Append container rendering behavior to whatever function the user wants (if any) to show up as the container's background.
    local function renderContainer(mask)
        renderFunction(container.maskFunction())
        local hovering = false
        --todo Render contents, shifting window to cut off everything outside it., setting hovering to true as in the tab render
        --This will obfuscate the fact that buttons are wonky near container edges, so I should TODO go back and fix this.
        
        local i = 1
        for _, object in ipairs(objects) do
            --print("render object at ", object.getPos().x, ", ", object.getPos().y)
            if object.renderFunction(object.maskFunction()) then
                hovering = true
            end
            i = i + 1
        end
        return hovering
    end
    
    --This should be called once the thing is created with the default maskFunction
    local function setMaskFunction(maskFunc)
        if container.renderOutsideBounds then return end
        container.maskFunction = maskFunc
        for _, object in ipairs(objects) do
            object.setMaskFunction(combineMasks(container, object))
            object.setMaskFunction(combineMasks(container, object))
            --object.setMaskFunction(combineMasks(container, object))
        end
    end
    
    local function containObject(object)
        --adjust getPos
        local oldGetPos = object.getPos
        function containedGetPos()
            local newX = container.getPos().x + oldGetPos().x
            local newY = container.getPos().y + oldGetPos().y
            --print("containedGetPos newX ", newX, "newy ", newY, " getPos function ", object.getPos)
            return {x=newX, y=newY}
        end
        object.getPos = containedGetPos
        --adjust visibilityFunction
        --object is only visible if partially inside container.
        local oldVisibilityFunction = object.visibilityFunction
        function containedVisibilityFunction()
            local retVal = false
            if container.renderOutsideBounds then return true end
            if ((object.getPos().x > container.getPos().x + container.width) or (object.getPos().x + object.width < container.getPos().x) or
                (object.getPos().y > container.getPos().y + container.height) or (object.getPos().y + object.height < container.getPos().y)) then
                retVal = false
            else
                if (not oldVisibilityFunction) then
                    print("ERROR: vis func for contained object ", object.getPos().x, ", ", object.getPos().y, " is nil!")
                    return true
                end
                retVal = oldVisibilityFunction()
            end
            --print("Called containing vis function ", retVal)
            return retVal
        end
        object.visibilityFunction = containedVisibilityFunction
    end
    
    local function addObject(object, resizeToFit) --adds the given object to the container, expanding container to accomodate it if resizeToFit.
        if (resizeToFit) then
            container.height = math.max(container.height, object.y + object.height)
            container.width = math.max(container.width, object.x + object.width)
        end
        containObject(object)
        table.insert(container.objects, object)
    end
    --TODO test this works.
    
    --Finish the constructor
    for _, object in ipairs(objects) do
        containObject(object)
    end
    container = createObject(x, y, width, height, visibilityFunction, renderContainer)
    container[objects] = objects
    container.addObject = addObject 
    --pass the mask to contained objects
    container.renderOutsideBounds = renderOutsideBounds
    container.setMaskFunction = setMaskFunction
    container.setMaskFunction(container.maskFunction)
    return container
end


local SCROLL_NUB_BIGNUM = 500--todo change
--TODO do I need to invert the render order for containers?

--TODO fullscreen causes button hold issues, fix this.

--scroll bars are a two-leveled container.  This one goes up and down.
--container
----scroll buttons
----scroll bar
----scroll nub
----content (This is an object you pass in to the scroll bar, it will be cut off horiz if it's too large.)
--Content is a single item with a y coordinate of 0. It can have variable size, and can be longer than the scroll container, but not wider.

--TODO adding objects doesn't work yet because it doesn't resize the contentContainer to fit them.  Fix this.
--actually add a resizeToFit argument to 
local function createVerticalScrollContainer(x, y, width, height, visibilityFunction, content)
    local barWidth = 12
    local scrollIncrement = 30
    --scrollValue is absolute position of the scroll bar.
    local scrollContainer
    local contentContainer
    local scrollBar
    local scrollUpButton
    local scrollDownButton
    local scrollNub
    local function scrollUp()
        scrollContainer.scrollValue = scrollContainer.scrollValue + scrollIncrement
    end
    local function scrollDown()
        scrollContainer.scrollValue = scrollContainer.scrollValue - scrollIncrement
    end
    
    local function nubClicked() --Don't use the values passed here, they break when resizing the window.  Use the one Hyperspace gives you.
        local mousePos = Hyperspace.Mouse.position
        scrollNub.mouseTracking = true
        scrollNub.mouseOffset = mousePos.y - scrollNub.getPos().y
        print("mouse offset: ", mousePos.y - scrollNub.getPos().y, " mousePos ", mousePos.y, " scrollNub ", scrollNub.getPos().y)
    end
    local function nubReleased()
        scrollNub.mouseTracking = false
    end
    
    local function nubMinPos()
        return barWidth
    end
        
    local function nubMaxPos()
        return math.max(nubMinPos(), scrollContainer.height - (barWidth + scrollNub.height))
    end
    
    local function minWindowScroll()
        return 0
    end
    
    local function maxWindowScroll()
        return math.max(minWindowScroll(), content.height - contentContainer.height)
    end
    
    --TODO test scroll bar with too small thing inside.
    --todo I don't think this math is right...  Check that scroll makes things do right numbers.
    local function scrollToNub(scrollValue)
        return nubMinPos() + ((scrollValue - minWindowScroll()) / math.max(1, (maxWindowScroll() - minWindowScroll())) * (nubMaxPos() - nubMinPos()))
    end
    
    local function nubToScroll(nubPosition)
        return minWindowScroll() + ((nubPosition - nubMinPos()) / math.max(1, (nubMaxPos() - nubMinPos())) * (maxWindowScroll() - minWindowScroll()))
    end
    
    scrollBar = createObject(width - barWidth, 0, barWidth, height, visibilityFunction,
        solidRectRenderFunction(Graphics.GL_Color(.5, .5, .5, .8)))
    --TODO disable buttons if scrolling is impossible?
    scrollUpButton = buildButton(width - barWidth, 0, barWidth, barWidth, visibilityFunction,
        solidRectRenderFunction(Graphics.GL_Color(0, 1, 1, 1)), scrollDown, NOOP)
    scrollDownButton = buildButton(width - barWidth, height - barWidth, barWidth, barWidth, visibilityFunction,
        solidRectRenderFunction(Graphics.GL_Color(0, 1, 1, 1)), scrollUp, NOOP)
    scrollNub = buildButton(width - barWidth, barWidth, barWidth, barWidth, visibilityFunction,
        solidRectRenderFunction(Graphics.GL_Color(.4, .1, 1, 1)), nubClicked, nubReleased)
    scrollNub.mouseTracking = false
    
    --todo nub should change size based on scrollDelta, clamped to barWidth and  contentContainer.height - (barWidth * 2)
    local function renderContent()
        local mousePos = Hyperspace.Mouse.position
        if isWithinMask(mousePos, scrollContainer.maskFunction()) then
            mHoveredScrollContainer = scrollContainer
        end
        
        --need to fix my scrollbar math.
        local scrollWindowRange = maxWindowScroll() - minWindowScroll()
        --scrollbar slider size TODO fix this math too.
        scrollNub.height = scrollContainer.height / math.max(1, scrollWindowRange)
        scrollNub.height = math.max(barWidth, math.min(contentContainer.height - (barWidth * 2), scrollNub.height))
        
        if (scrollNub.mouseTracking) then
            scrollNub.y = mousePos.y - scrollContainer.y - scrollNub.mouseOffset
             --clamp to bar length TODO nub centering
            --math out
            scrollContainer.scrollValue = nubToScroll(scrollNub.y)
        end
        
        --print("scrollValue: ", scrollContainer.scrollValue, " maxValue ", maxWindowScroll()) --todo one of these shouldn't be needed if I'm converting right.  the other one I think.
        scrollContainer.scrollValue = math.max(minWindowScroll(), math.min(maxWindowScroll(), scrollContainer.scrollValue))
        --TODO convert scrollValue to nubPos and apply to
        scrollNub.y = scrollToNub(scrollContainer.scrollValue)
        --scrollNub.y = math.max(nubMinPos(), math.min(nubMaxPos(), scrollNub.y))
        --print("scrollValue: ", scrollContainer.scrollValue, " nubPos ", scrollNub.y, "nubMaxPos ", nubMaxPos())
        
        content.y = -scrollContainer.scrollValue
        --print("Rendering content level")
    end
    
    
    contentContainer = buildContainer(0, 0, width - barWidth, height, visibilityFunction, renderContent, {content}, false)
    scrollContainer = buildContainer(x, y, width, height, visibilityFunction, solidRectRenderFunction(Graphics.GL_Color(.2, .8, .8, .3)),
        {contentContainer, scrollBar, scrollUpButton, scrollDownButton, scrollNub}, false)
    scrollContainer.scrollValue = barWidth
    scrollContainer.scrollUp = scrollUp
    scrollContainer.scrollDown = scrollDown
    
    return scrollContainer
end




--


--array of buttons for inventory slots.  If they are full, they render the item they hold on top of them. (ill define items later)  Their onClick returns the item they hold, if any, and makes it render on the cursor until the cursor is released, at which point it tries to move to the highlighted button if it can hold it, and otherwise snaps back to the one it came from.
function createButtonGridFromSize(visibilityFunction, x, y, width, height, button_width, button_height, padding, total_buttons, onClick)
    local buttons = {}
    local cols = math.floor((width + padding) / (button_width + padding))  -- Number of columns that fit
    local rows = math.ceil(total_buttons / cols)  -- Total rows needed
    
    for i = 0, total_buttons - 1 do
        local col = i % cols
        local row = math.floor(i / cols)

        local button_x = x + col * (button_width + padding)
        local button_y = y + row * (button_height + padding)

        table.insert(buttons, buildButton(button_x, button_y, button_width, button_height, visibilityFunction, onClick, 
            function()
                Graphics.CSurface.GL_DrawRect(button_x, button_y, button_width, button_height, Graphics.GL_Color(0, 1, 1, 1))
            end
        ))
    end
    return buttons
end

--Define either rows or columns, not both.  Set the other negative.
--todo rows, columns.  Currently assumes 1 column vertical downwards.
--Returns a container that is large enough to hold the given buttons.
function createButtonGridFromButtons(visibilityFunction, x, y, padding, buttons)
    
end

--hey uh b1 was only moving horiz when I direct registered it to a scroll bar.
--needs a pointer to an object, not the object itself.
function solidRectRenderFunction(glColor)
    return function(mask)
        Graphics.CSurface.GL_DrawRect(mask.getPos().x, mask.getPos().y, mask.width, mask.height, glColor)
    end
end


local b1
b1 = buildButton(0, 0, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end, NOOP)
local b2 = buildButton(0, 49, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 0, 1, 1)), 
        function() print("thing dided2") end, NOOP)

local b4 = buildButton(400, 400, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 1, 0, 1)),
        function() print("thing dided") end, NOOP)

local c1 = buildContainer(20, 0, 100, 200, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {b1, b2}, false)
--c2 = buildContainer(50, 100, 200, 200, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {c1})
local b3 = buildButton(300, 400, 25, 10, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end, NOOP)

local s1 = createVerticalScrollContainer(300, 300, 200, 100, tabOneStandardVisibility, c1)

table.insert(mTopLevelRenderList, s1)
table.insert(mTopLevelRenderList, b3)
--local inventoryGrid = createButtonsInGrid(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX, 50, 50, 200, 300, 40, 40, 10, 10)
--sButtonList = lwl.tableMerge(sButtonList, inventoryGrid)

--it's rendering regardless of visibility.  Fix this.

--uh a function that takes some saved states about a button and transfers it to the mouse kind of not really, just puts it in a semi-state where releasing on another iButton will put it in that one.

local function inventoryStorageFunctionGeneric(item)
    return true
end

local function inventoryStorageFunctionEqipment(item)
    return (item.type == TYPE_EQUIPMENT)
end

local function inventoryStorageFunctionArmor(item)
    return (item.type == TYPE_ARMOR)
end

local function inventoryStorageFunctionTool(item)
    return (item.type == TYPE_TOOL)
end

--[[
Items are tables with the following properties

type: describes what kind of thing the item is, used for determing which inventory buttons can hold which kinds of items.
name: what exactly you have stored in that slot.
renderFunction: hopefully a png that's the same size as their button.


--]]

--visibility function inherited from the button they're attached to.
local function createItem(name, itemType, renderFunction)
    
    return {name=name, itemType=itemType, renderFunction=renderFunction}
end


--I might actually put this in the UI library, it's pretty useful.
local function createInventoryButton(name, x, y, height, width, visibilityFunction, renderFunction, allowedItemsFunction)
    --todo custom logic has to go somewhere else, as these need to work even when the button isn't rendered.
    local button
    
    local function onClick()
        button.item.trackMouse = true
    end
    
    local function onRelease()
        local mousePos = Hyperspace.Mouse.position
        button.item.trackMouse = false
        if (mHoveredButton and mHoveredButton.addItem) then
            if (mHoveredButton.addItem(button.item)) then
                button.item = nil
            end
        end
    end
    
    local function addItem(item)
        if button.item then
            return false
        end
        if allowedItemsFunction(item) then
            button.item = item
            return true
        end
        return false
    end
    
    button = buildButton(x, y, height, width, visibilityFunction, renderFunction, onClick, onRelease)
    button.addItem = addItem
    button.allowedItemsFunction = allowedItemsFunction
    
    
    return button
    --make the item render with the mouse when mouse down on it.
end


local function buildCrewEquipmentScrollBar()
    local crewScrollBar
    
    --create a linear array of things.  This means containers need a render outside boundaries argument.
    --renderContentOutsideBounds
    
    return crewScrollBar
end



--this makes the z-ordering of buttons based on the order of the sButtonList, Lower values on top.
function renderObjects()
    --todo test code to animate movement
    b1.x = b1.x + 1
    if (b1.x > 100) then
        b1.x = 0
    end
    b1.y = b1.y + 1
    if (b1.y > 202) then
        b1.y = 0
    end
    
    local hovering = false
    
    Graphics.CSurface.GL_PushMatrix()
    local i = 1
    for _, object in ipairs(mTopLevelRenderList) do
        --print("render object"..i)
        if object.renderFunction(object.maskFunction()) then
            hovering = true
        end
        i = i + 1
    end
    if not hovering then
        mHoveredButton = nil
    end
    Graphics.CSurface.GL_PopMatrix()
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
        renderObjects()
    end)

--yeah, select those items and hold them!
    script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y)
        print("click, button_hovered ", mHoveredButton)
        if mHoveredButton then
            print("clicked ", mHoveredButton)
            mHoveredButton.onClick(x, y)
            mClickedButton = mHoveredButton
        end

        return Defines.Chain.CONTINUE
    end)

    script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_UP, function(x,y)
        if (mClickedButton) then
            mClickedButton.onRelease()
            mClickedButton = nil
        end
        return Defines.Chain.CONTINUE
    end)

--[[
TODO add this when hyperspace adds the event for scrolling
    script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_UP, function(x,y)
        if (mHoveredScrollContainer) then
            mHoveredScrollContainer.scrollDown()
        end
        return Defines.Chain.CONTINUE
    end)
--todo add scroll wheel scrolling to scroll bars, prioritizing the lowest level one.
--]]
end


--uh, a function for selling these??  curently does not exist.  low priority but would be nice integration

