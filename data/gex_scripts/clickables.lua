local vter = mods.multiverse.vter

local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface

local mGlobal = Hyperspace.Global.GetInstance()
local mBlueprintManager = mGlobal:GetBlueprints()
--todo can this be here?
local CRYSTAL_NAME = "crystal"
local NAI_CREW_EVENT_NAME = "GEX_NAI_STARTING_CREW"
local START_BEACON_EVENT_NAME = "START_BEACON_PREP_OPTIONS"
local START_CREW_EVENT_NAME = "START_BEACON_PREP_OPTIONS 25"
local GEX_NAI_MODE_KEY = "GEX_MASOCHISMODE"
local CRYSTAL_BLUEPRINT = mBlueprintManager:GetCrewBlueprint(CRYSTAL_NAME)

local X_POS = 102
local Y_POS = 81
local BUTTON_SIZE = 30
local HOVER_OFFSET = 4

local mNaiButton
local mIsInitialized = false
local mRenderHelp = false
local mNaiMode = 0

local function hangarVisibilityFunction()
    return Hyperspace.ships.player ~= nil and Hyperspace.ships.player.iCustomizeMode == 2
end

local function naiClicked()
    mNaiMode = 1 - mNaiMode
    Hyperspace.playerVariables[GEX_NAI_MODE_KEY] = 1 - lwl.setIfNil(Hyperspace.playerVariables[GEX_NAI_MODE_KEY], 0)
end

local function helpTextVisibilityFunction()
    return mRenderHelp
end

mNaiButton = lwui.buildToggleButton(X_POS, Y_POS, BUTTON_SIZE, BUTTON_SIZE, hangarVisibilityFunction,
        lwui.toggleButtonRenderFunction("CustomUI/nai_wa_off.png", "CustomUI/nai_wa_off_hover.png",
                "CustomUI/nai_wa.png", "CustomUI/nai_wa_hover.png"), naiClicked)
mNaiButton.naiModeHelpButton = true
local mHelpTextBox = lwui.buildDynamicHeightTextBox(X_POS + BUTTON_SIZE + HOVER_OFFSET, Y_POS, 330, 125, helpTextVisibilityFunction, lwui.solidRectRenderFunction(Graphics.GL_Color(.1, .1, .1, .8)), 11)
mHelpTextBox.text = "A sigil of an unknown god that menaces with wisps of void. It bears an engraving: 'Does't thou desire difficulty?' \n\nNai mode: Your ship will have 15 hull, and can recruit a crystal instead of a human at the starting beacon. Do you dare come and have a go?  To test your hardness against the scales?"
lwui.addTopLevelObject(mNaiButton, "MOUSE_CONTROL_PRE")
lwui.addTopLevelObject(mHelpTextBox, "MOUSE_CONTROL_PRE")

--We don't get this for free, so we have to add it outselves.
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if lwui.mHoveredObject then
        if lwui.mHoveredObject.naiModeHelpButton then
            mRenderHelp = true
            return
        end
    end
    mRenderHelp = false
    end)

--Ship hull change
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if mIsInitialized or (not Hyperspace.ships(0)) or lwl.isPaused() then return end

    mIsInitialized = true
    if Hyperspace.playerVariables[GEX_NAI_MODE_KEY] > 0 then
        Hyperspace.ships.player.ship.hullIntegrity.second = 15
    end
end)

--Start Beacon Event Crew Modification
local function modifyCheck(locationEvent)
    --print("Event: ", locationEvent.eventName)
    if locationEvent.eventName == START_BEACON_EVENT_NAME then
        if mNaiMode == 0 then return end
        Hyperspace.playerVariables[GEX_NAI_MODE_KEY] = 1
        --lwl.printEvent(locationEvent)
        local choices = locationEvent:GetChoices()
        --print("Found options")
        for choice in vter(choices) do
            --print("nai enabled, doing...")
            local crewEvent = choice.event
            if crewEvent.eventName == START_CREW_EVENT_NAME then
                --todo changing crew type doesn't work, just add a new option that gives you a crystal and switch which one is hidden depending.
                --todo (never doing) set var directly instead of using an augment.
                --print("Found crew option")
                choice.requirement.min_level = 99
                --crewEvent.crewType = CRYSTAL_NAME
                --crewEvent.crewBlue = CRYSTAL_BLUEPRINT
            end
            if crewEvent.eventName == NAI_CREW_EVENT_NAME then
                --print("Found new crew option")
                choice.requirement.min_level = 1
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(locationEvent)
        modifyCheck(locationEvent)
    end)


local mHasOE = false
local mHasDD = false
local mHasLI = false
--Reset on restart
script.on_init(function()
    --Check for mods known to contain additional systems that normally replace existing ones.
    ---Currently DD, OE, LI
    ---This way you don't have to worry about load order
    ---they might not expose stuff to say that they're installed, so check.
    mIsInitialized = false
end)

--[[
OE systems: extra shields (cloaking)
DD systems: none?
LI systems: ablative armor (shields), ion thing (battery), infusions (med/clonebay)
]]


---------------------------------Here lies the system stuff---------------------------------------
---Lily's additions has code to check the ship systems, check that
---todo add map ship icons to all the ships I made









