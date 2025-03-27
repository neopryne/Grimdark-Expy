if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
--local userdata_table = mods.multiverse.userdata_table

--any object capable of holding another object must have a function that passes down renderWrapping, and one for any other such operators.

--[[
tools that increase the things you can do in a scope
tools that translate between scopes (dac, monitor, microphone, speakers)

Functions are built to deal with objects (renderable).

Object {x,y,getPos,height,width,visibilityFunction,renderFunction} --position is absolute on the global UI
--Button {onClick, enabledFunction} --enabled tells the button if it should work or not, some buttons have different render states based on this as well.
--Container {Objects} (Abstract, if that makes any sense.)
----Scroll Bar {internals={scrollUpButton, scrollDown, scrollBar, scrollCursor}}
----Button Group {padding?}

getPos()
    return {x=x, y=y}
end

tab_name, subtab_index-- no, this is a VISIBILITY FUNCTION
renderFunction()
    if self.visibilityFunction() then
        renderSelf()
        renderContents()
    end
end

onClickFunction(mousePos)
    if self.visibilityFunction() then
        if insideSelf(mousePos) then
            triggerSelfFunction
        end
    end
end

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

--In order to handle partial rendering, objects would need offsets from each side, and I'm not doing that.
--ok it's a bit involved but it's worth it and doing it right will make future scroll bars way easier.
--basically you need to register elements (buttons) inside the scroll bar, and then as it scrolls it will update their positions.
--also...you need to put their onRenders inside a stencil. 
--to do that, we have this wrap the functions of each button assigned to the scroll bar.

--Define the size of the scroll window
--Fixed size for scroll bar width and button height.
--It is responsible for shifting the position of the thing it is rendering and putting the stencil around it.

--Objects must be registered somehow with the topLevelRenderList to appear, be visible, and thus be interacted with.
--All items constructed from this point down are objects.

--Basic things that are visible, but have no other features.
--Render functions for pure objects should return false or it will break the button logic.
local function createObject(x, y, width, height, visibilityFunction, renderFunction)
    local function renderObject()
        --print("should render? ", visibilityFunction())
        if visibilityFunction() then
            return renderFunction()
        end
    end
    
    local function getPosition()
        --print("getPosition x ", x, " y ", y)
        return {x=x, y=y}
    end
    
    return {x=x, y=y, getPos=getPosition, width=width, height=height, visibilityFunction=visibilityFunction, renderFunction=renderObject}
end

--onClick(x, y): args being passed are global position of the cursor when click occurs.
local function buildButton(x, y, width, height, visibilityFunction, renderFunction, onClick)--todo order changed, update calls.
    local function buttonClick(x1, y1)
        if visibilityFunction then
            --todo idk if I should have this in here or out in the main render logic.
            --it's easier to find hovered things in the main render loop.
            --This version would click all hovered buttons in a stack.  That version has layering.
            --the question is, can I get layering from an intrinsic?
            --probably not, it requires knowing about other items.
            onClick(x1, y1)
        end
    end
    
    local button --todo make sure this gets picked up by the next function correctly, this is supposed to make it set itself as the global hovered button.
    local function renderObject()
        local hovering = false
        local mousePos = Hyperspace.Mouse.position
        if mousePos.x >= button.getPos().x and mousePos.x <= button.getPos().x + button.width and
               mousePos.y >= button.getPos().y and mousePos.y <= button.getPos().y + button.height then
            hovering = true
            if not (mHoveredButton == button) then
                print("button_hovered ", button)
                mHoveredButton = button
            end
        end
        renderFunction()
        return hovering
    end
    
    button = createObject(x, y, width, height, visibilityFunction, renderObject)
    button[onClick] = buttonClick
    return button
end

--malboge, befunge, metalisp, trevino

--this is the level that handles the stencil rendering adjustments.  
--todo I don't think this handles buttons going outside of the container properly.
--when the container moves, so should all buttons under it.  This requires hooking modifying the x/y positions of this object.
--oh, containers automatically add their position to all objects under them each tick.
--that solves this, but how to do that so that an object's position is still meaningful?
--I could do 
--If I take the limitation that you can't take something out of a container once it's inside it (kind of implicit already), then I can add a getPos() to objects that 
--containers will modify for their contents.
--[[
oldGetPos = object.getPos
object.getPos = oldGetPos + myGetPos
--]]
--in this way, getPos will be absolute, while x and y will be relative to whatever container an object is inside (or absolute if top level)
local function buildContainer(x, y, width, height, visibilityFunction, renderFunction, objects)
    local container
    --Append container rendering behavior to whatever function the user wants (if any) to show up as the container's background.
    local function renderContainer()
        renderFunction()
        local hovering = false
        --todo Render contents, shifting window to cut off everything outside it., setting hovering to true as in the tab render
        local i = 1
        for _, object in ipairs(objects) do
            --print("render object"..i)
            if object.renderFunction() then
                hovering = true
            end
            i = i + 1
        end
        
        return hovering
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
            if ((object.getPos().x > container.getPos().x + container.width) or (object.getPos().x + object.width < container.getPos().x) or
                (object.getPos().y > container.getPos().y + container.height) or (object.getPos().y + object.height < container.getPos().y)) then
                return false
            else
                return oldVisibilityFunction()
            end
        end
        object.visibilityFunction = containedVisibilityFunction
    end
    
    container = createObject(x, y, width, height, visibilityFunction, renderContainer)
    container[objects] = objects
    return container
end

local function createVerticalScrollBar()
    --return {contents={}, x, y, height, width, }
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
function solidRectRenderFunction(objectGetter, glColor)
    return function()
        local object = objectGetter()
        Graphics.CSurface.GL_DrawRect(object.getPos().x, object.getPos().y, object.width, object.height, glColor)
    end
end


local b1
local function b1Getter() return b1 end
b1 = buildButton(0, 0, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(b1Getter, Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end)
local b2
local function b2Getter() return b2 end
b2 = buildButton(0, 49, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(b2Getter, Graphics.GL_Color(1, 0, 1, 1)), 
        function() print("thing dided2") end)
local c1 = buildContainer(50, 0, 100, 100, tabOneStandardVisibility, NOOP, {b1, b2})
local b3
local function b3Getter() return b3 end
b3 = buildButton(300, 400, 50, 50, tabOneStandardVisibility, solidRectRenderFunction(b3Getter, Graphics.GL_Color(1, 0, 0, 1)),
        function() print("thing dided") end)

table.insert(mTopLevelRenderList, c1)
table.insert(mTopLevelRenderList, b3)

--local inventoryGrid = createButtonsInGrid(ENHANCEMENTS_TAB_NAME, EQUIPMENT_SUBTAB_INDEX, 50, 50, 200, 300, 40, 40, 10, 10)
--sButtonList = lwl.tableMerge(sButtonList, inventoryGrid)




--this makes the z-ordering of buttons based on the order of the sButtonList, Lower values on top.
function renderObjects()
    --print("render objects")
    local hovering = false
    
    Graphics.CSurface.GL_PushMatrix()
    local i = 1
    for _, object in ipairs(mTopLevelRenderList) do
        --print("render object"..i)
        if object.renderFunction() then
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
        end

        return Defines.Chain.CONTINUE
    end)

    script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_UP, function(x,y) 
        --[[if mouseDownPos then
            mouseDownPos = nil
            lastMousePos = nil
            --drop held item.  If not near a slot for it, put it back where it started.  Actually it never moved until you finish placing it somewhere else.
        end--]]
        return Defines.Chain.CONTINUE
    end)
end


--uh, a function for selling these??  curently does not exist.  low priority but would be nice integration

