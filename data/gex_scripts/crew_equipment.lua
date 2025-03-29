if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
--local userdata_table = mods.multiverse.userdata_table

--any object capable of holding another object must have a function that passes down renderWrapping, and one for any other such operators.

--[[

Functions are built to deal with objects (renderable).

Object {x,y,getPos,height,width,visibilityFunction,renderFunction} --position is absolute on the global UI
--Button {onClick, enabledFunction} --enabled tells the button if it should work or not, some buttons have different render states based on this as well.
--Container {Objects} (Abstract, if that makes any sense.)
----Scroll Bar {internals={scrollUpButton, scrollDown, scrollBar, scrollCursor}}
----Button Group {padding?}
--]]
local ENHANCEMENTS_TAB_NAME = "crew_enhancements"
local EQUIPMENT_SUBTAB_INDEX = 1
local function NOOP() end

local mTabbedWindow = ""
local mTab = 1
local mPage = 1--used to calculate which crew are displayed in the equipment loadout slots.  basically mPage % slots per page. Or do the scrolly thing, it's easier than I thought.
--Objects to be rendered go here.  Visible buttons are clickable.
local mTopLevelRenderList = {}
local mHoveredButton = nil
local mClickedButton = nil --mouseUp will be called on this.

local function isWithinMask(x, y, mask)
    return mask and x >= mask.x and y >= mask.y and x <= mask.x + mask.w and y <= mask.y + mask.h
end

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
        if mousePos.x >= buttonMask.getPos().x and mousePos.x <= buttonMask.getPos().x + buttonMask.width and
               mousePos.y >= buttonMask.getPos().y and mousePos.y <= buttonMask.getPos().y + buttonMask.height then
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


local function buildContainer(x, y, width, height, visibilityFunction, renderFunction, objects)
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
        container.maskFunction = maskFunc
        for _, object in ipairs(objects) do
            object.setMaskFunction(combineMasks(container, object))
            object.setMaskFunction(combineMasks(container, object))
            --object.setMaskFunction(combineMasks(container, object))
        end
    end
    
    for _, object in ipairs(objects) do
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
    
    container = createObject(x, y, width, height, visibilityFunction, renderContainer)
    container[objects] = objects
    --pass the mask to contained objects
    container.setMaskFunction = setMaskFunction
    container.setMaskFunction(container.maskFunction)
    return container
end

--TODO do I need to invert the render order for containers?

--scroll bars are a two-leveled container.  This one goes up and down.
--container
----scroll buttons
----scroll bar
----scroll nub
----contents (This is an object you pass in to the scroll bar, it will be cut off horiz if it's too large.)
--Contents should be a thing of variable size that can be longer than the scroll container, but not wider.
--Contents is a single item
local function createVerticalScrollContainer(x, y, width, height, visibilityFunction, content)
    local scrollValue = 0 --absolute position
    local barWidth = 12
    local scrollIncrement = 30
    
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
    
    local function nubClicked()
        scrollNub.mouseTracking = true
    end
    local function nubReleased()
        scrollNub.mouseTracking = false
    end
    
    --todo the render and click functions probably need to take a visibility mask that represents the part of the object inside render space.
    --Otherwise the container bleed stacks, and you can get massive areas of clickable, unrendered buttons.
    
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
    --TODO why does nub vanish when moving it?
    
    local function verticalMouseTracking()
        if (scrollNub.mouseTracking) then
            local mousePos = Hyperspace.Mouse.position
            local nubMaxPos = scrollContainer.y + scrollContainer.height - barWidth
            local nubMinPos = scrollContainer.y + barWidth
            local nubPos = math.max(nubMinPos, math.min(nubMaxPos, mousePos.y)) --clamp to bar length TODO bar length, nub size, nub centering
            --math out
            local nubPercent = (nubPos) / (nubMaxPos - nubMinPos)
            scrollContainer.scrollValue = nubPercent * content.height
            print(scrollContainer.scrollValue)
        end
        scrollNub.y = scrollContainer.scrollValue
    end
    
    local function renderContent()
        local minWindowScroll = 0
        local maxWindowScroll = scrollContainer.height - contentContainer.height
        scrollContainer.scrollValue = math.max(minWindowScroll, math.min(maxWindowScroll, scrollContainer.scrollValue))
        contentContainer.x = -scrollContainer.scrollValue
        verticalMouseTracking()
        --print("Rendering content level")
    end
    
    
    contentContainer = buildContainer(0, 0, width - barWidth, height, visibilityFunction, renderContent, {content})
    scrollContainer = buildContainer(x, y, width, height, visibilityFunction, solidRectRenderFunction(Graphics.GL_Color(.2, .8, .8, .3)),
        {contentContainer, scrollBar, scrollUpButton, scrollDownButton, scrollNub})
    scrollContainer.scrollValue = scrollValue
    
    return scrollContainer
end

--Inside this scroll bar is a vertical list of buttons, seperate from the scroll bar.
--local crewScrollBar = createVerticalScrollBar()

local function scrollBarRegister(scrollBar, button)
    
end

local function generateStandardVisibilityFunction(tabName, subtabIndex)
    return function()
        return mTab == subtabIndex and mTabbedWindow == tabName
    end
end

local tabOneStandardVisibility = generateStandardVisibilityFunction(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX)

--render tabs




--should have a function to render itself?


--array of buttons for inventory slots.  If they are full, they render the item they hold on top of them. (ill define items later)  Their onClick returns the item they hold, if any, and makes it render on the cursor until the cursor is released, at which point it tries to move to the highlighted button if it can hold it, and otherwise snaps back to the one it came from.
function createButtonGridFromSize(visibilityFunction, x, y, width, height, button_width, button_height, padding, total_buttons)
    local buttons = {}
    local cols = math.floor((width + padding) / (button_width + padding))  -- Number of columns that fit
    local rows = math.ceil(total_buttons / cols)  -- Total rows needed
    
    for i = 0, total_buttons - 1 do
        local col = i % cols
        local row = math.floor(i / cols)

        local button_x = x + col * (button_width + padding)
        local button_y = y + row * (button_height + padding)

        table.insert(buttons, buildButton(button_x, button_y, button_width, button_height,
            function()
                return true --todo fix
            end,
            function()
                print("Button clicked at (" .. button_x .. ", " .. button_y .. ")")
            end, function()
                Graphics.CSurface.GL_DrawRect(button_x, button_y, button_width, button_height, Graphics.GL_Color(0, 1, 1, 1))
            end
        ))
    end
    return buttons
end

--Define either rows or columns, not both.  Set the other negative.
--todo rows, columns.  Currently assumes 1 column vertical downwards.
function createButtonGridFromButtons(visibilityFunction, x, y, padding, buttons)
    
end

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

local c1 = buildContainer(20, 0, 100, 200, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {b1, b2})
--c2 = buildContainer(50, 100, 200, 200, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(0, 0, 1, .4)), {c1})
local b3 = buildButton(300, 400, 25, 10, tabOneStandardVisibility, solidRectRenderFunction(Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end, NOOP)

local s1 = createVerticalScrollContainer(300, 300, 200, 100, tabOneStandardVisibility, c1)

table.insert(mTopLevelRenderList, s1)
table.insert(mTopLevelRenderList, b3)
--local inventoryGrid = createButtonsInGrid(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX, 50, 50, 200, 300, 40, 40, 10, 10)
--sButtonList = lwl.tableMerge(sButtonList, inventoryGrid)

--it's rendering regardless of visibility.  Fix this.


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
    c1.x = c1.x + 1
    if (c1.x > 300) then
        c1.x = 0
    end
    --print("b1x: ", b1.x, " b1posx ", b1.getPos().x, "b1vis: ", b1.visibilityFunction())
    --print("render objects")
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

--todo add scroll wheel scrolling to scroll bars, prioritizing the lowest level one.
end


--uh, a function for selling these??  curently does not exist.  low priority but would be nice integration

