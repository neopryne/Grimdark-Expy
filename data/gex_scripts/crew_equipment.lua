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
--lwUI

local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local TYPE_WEAPON = "type_weapon"
local TYPE_ARMOR = "type_armor"
local TYPE_TOOL = "type_tool"
local function NOOP() end
local MIN_FONT_SIZE = 5

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

--todo this can't dyanmically update based on the values of object1 and object2?  I mean it should, that's what the mask function does.
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
--.
--[[
addObject(object): call this if you need to add something to the container after creation.
renderOutsideBounds: if true, objects will render even if out of bounds of the container.
sizeToContent: if true, the container will dynamically adjust itself to the smallest sizes that hold all of its contents.
--]]
local function buildContainer(x, y, width, height, visibilityFunction, renderFunction, objects, renderOutsideBounds, sizeToContent)
    local container
    --Append container rendering behavior to whatever function the user wants (if any) to show up as the container's background.
    local function renderContainer(mask)
        renderFunction(container.maskFunction())
        local hovering = false
        --todo Render contents, shifting window to cut off everything outside it., setting hovering to true as in the tab render
        --This will obfuscate the fact that buttons are wonky near container edges, so I should TODO go back and fix this.
        
        local i = 1
        for _, object in ipairs(objects) do
            if (container.sizeToContent) then
                container.height = math.max(container.height, object.y + object.height)
                container.width = math.max(container.width, object.x + object.width)
            end
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
            --object.setMaskFunction(combineMasks(container, object))
            --object.setMaskFunction(combineMasks(container, object))
        end
    end
    
    local function addObject(object)
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
        table.insert(container.objects, object)
    end

    container = createObject(x, y, width, height, visibilityFunction, renderContainer)
    container.objects = {}
    for _, object in ipairs(objects) do
        addObject(object)
    end
    container.addObject = addObject
    --pass the mask to contained objects
    container.renderOutsideBounds = renderOutsideBounds
    container.sizeToContent = sizeToContent
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
--Don't make me tap the sign, though this setup means containers have to be willing to be dynamically sized as well if you want more than one item here.

--TODO adding objects doesn't work yet because it doesn't resize the contentContainer to fit them.  Fix this.
--scroll bars always grow to fit their content, if you want one that doesn't, ping me.
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
    scrollContainer.contentContainer = contentContainer
    
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

--[[
Items are tables with the following properties

itemType: describes what kind of thing the item is, used for determing which inventory buttons can hold which kinds of items. (type is a reserved word)
name: what exactly you have stored in that slot.
renderFunction: hopefully a png that's the same size as their button.

todo iterate through items attached to people.  This is probably a property of the people list, not the item.
The name of the item is for lookup in the mechanical table of items.
A mechanical item knows lots of things about itself, and maybe is important for lots of stuff.

--]]

--visibility function inherited from the button they're attached to.
--containingButton is the inventoryButton that holds this item.  render won't be called if this is nil as said button is the thing that calls it.
--onTick takes no arguments, onCreate is passed the item being created so it can modify it.
--TODO needs two mask functions, one for when it's being held, and its mask is itself.  One for when it is not being held, and its mask is its containing button's mask.
local function createItem(name, itemType, width, height, visibilityFunction, renderFunction, description, onCreate, onTick)
    local item
    local function itemRender()
        if (item.trackMouse) then
            local mousePos = Hyperspace.Mouse.position
            item.x = mousePos.x
            item.y = mousePos.y
        else
            item.x = item.containingButton.getPos().x
            item.y = item.containingButton.getPos().y
        end
        renderFunction(item.maskFunction())
    end
    
    local function itemMask()
        if item.trackMouse then
            return item
        else
            --This works because items only render when attached to an intentoryButton, so it will never be nil here.
            return item.containingButton.maskFunction()
        end
    end
    
    item = createObject(0, 0, width, height, visibilityFunction, itemRender)
    item.name = name
    item.itemType = itemType
    item.description = description
    item.onCreate = onCreate
    item.onTick = onTick
    item.maskFunction = itemMask
    
    item.onCreate(item)
    return item
end


--I might actually put this in the UI library, it's pretty useful.
--todo is this also a container for the item?
local function createInventoryButton(name, x, y, height, width, visibilityFunction, renderFunction, allowedItemsFunction)
    --todo custom logic has to go somewhere else, as these need to work even when the button isn't rendered.
    local button
    
    local function onClick()
        if (button.item) then
            button.item.trackMouse = true
        end
    end
    
    local function onRelease()
        local mousePos = Hyperspace.Mouse.position
        if (button.item) then
            button.item.trackMouse = false
            if (mHoveredButton and mHoveredButton.addItem) then
                if (mHoveredButton.addItem(button.item)) then
                    button.item = nil
                end
            end
        end
    end
    
    local function addItem(item)
        if button.item then
            print("iButton already contains ", button.item.name)
            return false
        end
        if allowedItemsFunction(item) then
            button.item = item
            item.containingButton = button
            print("added item ",  button.item.name)
            return true
        end
        print("item type not allowed.")
        return false
    end
    
    local function buttonRender()
        renderFunction(button.maskFunction())
        if (button.item) then
            --print("rendering item ", button.item.name)
            button.item.renderFunction(button.item.maskFunction())
        end
    end
    
    button = buildButton(x, y, height, width, visibilityFunction, buttonRender, onClick, onRelease)
    button.addItem = addItem
    button.allowedItemsFunction = allowedItemsFunction
    
    
    return button
end


local function buildCrewEquipmentScrollBar()
    local crewScrollBar
    
    --create a linear array of things.  This means containers need a render outside boundaries argument.
    --renderContentOutsideBounds
    
    return crewScrollBar
end

--todo some kind of typewriter print function you can pass in to text boxes.
--No actually it's just a field they have.

--todo some kind of a text box.  easy_printAutoNewlines lets me contstrain width, probably need a stencil for height.

--Internal fields:  text, what this will display.  I could do something clever where it tries to shrink the font size if it's too big, or another thing where I only put these inside scroll windows which would be pretty clever.
--This needs to set its height dynamically and be used inside a scroll bar, or change font size dynamically.
--This one actually is local, the other ones are what I'll expose for use.
--textColor (GL_Color) controls the color of the text.
local function createTextBox(x, y, height, width, visibilityFunction, renderFunction, fontSize)
    local textBox
    
    local function renderText(mask)
        renderFunction()
        --todo stencil this out, text has no interactivity so it's fine. based on mask.
        Graphics.CSurface.GL_PushStencilMode()
        Graphics.CSurface.GL_SetStencilMode(1,1,1)
        Graphics.CSurface.GL_ClearAll()
        Graphics.CSurface.GL_SetStencilMode(1,1,1)
        Graphics.CSurface.GL_PushMatrix()
        --Stencil of the size of the box
        Graphics.CSurface.GL_DrawRect(mask.getPos().x, mask.getPos().y, mask.width, mask.height, textBox.textColor)
        Graphics.CSurface.GL_PopMatrix()
        Graphics.CSurface.GL_SetStencilMode(2,1,1)
        --Actually print the text
        Graphics.freetype.easy_printAutoNewlines(textBox.fontSize, textBox.getPos().x, textBox.getPos().y, textBox.width, textBox.text)
        Graphics.CSurface.GL_SetStencilMode(0,1,1)
        Graphics.CSurface.GL_PopStencilMode()
    end
    
    textBox = createObject(x, y, height, width, visibilityFunction, renderText)
    textBox.text = ""
    textBox.fontSize = fontSize
    textBox.textColor = Graphics.GL_Color(1, 1, 1, 1)
    return textBox
end

--Minimum font size is five, choosing smaller will make it bigger than five.
--You can put this one inside of a scroll window for good effect
local function createDynamicHeightTextBox(x, y, height, width, visibilityFunction, fontSize)
    local textBox
    local function expandingRenderFunction()
        local lowestY = Graphics.freetype.easy_printAutoNewlines(textBox.fontSize, 5000, textBox.getPos().y, textBox.width, textBox.text).y
        textBox.height = lowestY - textBox.getPos().y
    end
    
    textBox = createTextBox(x, y, height, width, visibilityFunction, expandingRenderFunction, fontSize)
    return textBox
end

--Font shrinks to accomidate text, I don't think this one looks as good generally, but I wanted to make it available.
local function createFixedTextBox(x, y, height, width, visibilityFunction, maxFontSize)
    local textBox
    local function scalingFontRenderFunction()
        --textBox.text = textBox.text.."f"
        if (#textBox.text > textBox.lastLength) then
            textBox.lastLength = #textBox.text
            --check if reduction needed
            --print offscreen to avoid clutter
            while ((textBox.fontSize > MIN_FONT_SIZE) and
                    (Graphics.freetype.easy_printAutoNewlines(textBox.fontSize, 5000, textBox.getPos().y, textBox.width, textBox.text).y > textBox.getPos().y + textBox.height)) do
                textBox.fontSize = textBox.fontSize - 1
            end
        elseif (#textBox.text < textBox.lastLength) then
            textBox.lastLength = #textBox.text
            --check if we can increase size
            while ((textBox.fontSize < textBox.maxFontSize) and
                    (Graphics.freetype.easy_printAutoNewlines(textBox.fontSize, 5000, textBox.getPos().y, textBox.width, textBox.text).y < textBox.getPos().y + textBox.height)) do
                textBox.fontSize = textBox.fontSize + 1
            end
        end
    end
    
    textBox = createTextBox(x, y, height, width, visibilityFunction, scalingFontRenderFunction, maxFontSize)
    textBox.maxFontSize = maxFontSize
    textBox.lastLength = #textBox.text
    return textBox
end


--In the crew loop, each crew will check the items assigned to them and call their onTick functions, (pass themselves in?)
--It is the job of the items to do everything wrt their functionality.

local EQUIPMENT_ICON_SIZE = 30

local three_way = createItem("Three-Way", TYPE_WEAPON, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 1, .8, 1)),
        "Hit two more people at the cost of decreased damage.", NOOP, NOOP)
local seal_head = createItem("Seal Head", TYPE_ARMOR, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, .8, 1, 1)),
        "The headbutts it enables are an effective counter to and ridicule you might come under from wearing such odd headgear.", NOOP, NOOP)
local netgear = createItem("Three-Way", TYPE_TOOL, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(.8, 1, 1, 1)),
        "It's gear made of nets.  Also serves as a wireless access point. Cooldown: two minutes.  Deploy nets in a room to slow all movement through it for twenty five seconds by 60%.  Single use for some reason.", NOOP, NOOP)
        
--[[
    onCreate()
        --set up variables specific to this object's implementation.  Check that this is actually a good way of doing this, vs decoupling the object instance from the logic it uses
        --That version would involve each crewmem looking up their equipped items in the persisted values, and is probably better as a first guess at what a good model looks like.
        If it isn't, we can just combine the objects.
    end
    
    onTick()
        if (item.crewmem) then
            --do item stuff
        end
    end
    
    
--]]


--TODO update scroll bar sizes dynamically to accomidate text boxes (and other things)



local ib1 = createInventoryButton(name, 300, 30, EQUIPMENT_ICON_SIZE + 2, EQUIPMENT_ICON_SIZE + 2, tabOneStandardVisibility,
    solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionEquipment)
local ib2 = createInventoryButton(name, 0, 0, EQUIPMENT_ICON_SIZE + 2, EQUIPMENT_ICON_SIZE + 2, tabOneStandardVisibility,
    solidRectRenderFunction(Graphics.GL_Color(1, .5, 0, 1)), inventoryStorageFunctionEquipment)
ib1.addItem(seal_head)
local t1 = createDynamicHeightTextBox(0, 40, 60, 90, tabOneStandardVisibility, 8)
local longString = "Ok so this is a pretty long text box that's probably going to overflow the bounds of the text that created it lorum donor kit mama, consecutur rivus alterna nunc provinciamus."
t1.text = longString
print(t1.height)


local b1
b1 = buildButton(0, 0, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end, NOOP)
local b2 = buildButton(0, 49, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 0, 1, 1)), 
        function() print("thing dided2") end, NOOP)

local b4 = buildButton(400, 400, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 1, 0, 1)),
        function() print("thing dided") end, NOOP)

local c1 = buildContainer(20, 0, 10, 10, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {ib2, t1}, false, true)
--c2 = buildContainer(50, 100, 200, 200, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {c1})
local b3 = buildButton(300, 400, 25, 10, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end, NOOP)

local s1 = createVerticalScrollContainer(300, 300, 200, 100, tabOneStandardVisibility, c1)
print("c1: ", c1.height)
print("some other values: ", s1.contentContainer.height) --content height should never change, it's the virtual size of the thing inside, which I'm supposed to be updating on but also clearly isn't updating itself.  So.

table.insert(mTopLevelRenderList, s1)
table.insert(mTopLevelRenderList, b3)
table.insert(mTopLevelRenderList, ib1)
--table.insert(mTopLevelRenderList, t1)
--local inventoryGrid = createButtonsInGrid(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX, 50, 50, 200, 300, 40, 40, 10, 10)



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
--not any time soon,

