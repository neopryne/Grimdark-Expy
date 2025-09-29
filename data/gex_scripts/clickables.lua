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
local mNaiButton

local function setNaiMode(mode)
    if mode then
        Hyperspace.playerVariables[GEX_NAI_MODE_KEY] = 1
    else
        Hyperspace.playerVariables[GEX_NAI_MODE_KEY] = 0
    end
end

local function hangarVisibilityFunction()
    return Hyperspace.ships.player ~= nil and Hyperspace.ships.player.iCustomizeMode == 2
end

--todo this is a more complex render function that requires three images loaded dynamically.
local function naiButtonRender()
    
end

--mNaiButton = lwui.buildButton(300, 100, 30, 30, lwui.alwaysOnVisibilityFunction, renderFunction, onClick, onRelease)


--wither has requested a blood mod and it's really easy.
--Add the meat popsicle, a clickable that adds blood splatters to the game.  Further iterations would have different bloods for different species.
--Base kind just has like 7 types of human blood pool that fades over time, aoe2 style.
--Actually, what I should do is make an options menu for gexpy where you can choose which parts of it to enable.
--Stored in metavars so it persists always.
--[[Ok, we're going back to lwui and making these changes.  That means I can also make the changes that are needed for lwcel --that should have been its name --to get rid of its hardcodes.
anyway, adding a blank menu to lwl, that anything that uses it can append to easilly.






]]

--todo onload, smash hull if nai.

local mIsInitialized = false

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    --Initialization code
    if mIsInitialized or (not Hyperspace.ships(0)) or lwl.isPaused() then return end

    mIsInitialized = true
    if Hyperspace.playerVariables[GEX_NAI_MODE_KEY] > 0 then
        Hyperspace.ships.player.ship.hullIntegrity.second = 15
    end
end)

script.on_init(function()
    print("loading nai")
    mIsInitialized = false
end)

--nai mode should be set by a metavar in the xml.
--START_BEACON_PREP_OPTIONS
--START_BEACON_PREP_OPTIONS_25

local function modifyCheck(locationEvent)
    --check nai mode then return end
    --print("Event: ", locationEvent.eventName)
    if locationEvent.eventName == START_BEACON_EVENT_NAME then
    lwl.printEvent(locationEvent)
    Hyperspace.ships.player.ship.hullIntegrity.second = 15
    local choices = locationEvent:GetChoices()
        print("Found options")
        for choice in vter(choices) do
            if true then--Hyperspace.playerVariables[GEX_NAI_MODE_KEY] > 0 then
                print("nai enabled, doing...")
                local crewEvent = choice.event
                if crewEvent.eventName == START_CREW_EVENT_NAME then
                    --todo changing crew type doesn't work, just add a new option that gives you a crystal and switch which one is hidden depending.
                    --todo (never doing) set var directly instead of using an augment.
                    print("Found crew option")
                    choice.requirement.min_level = 99
                    --crewEvent.crewType = CRYSTAL_NAME
                    --crewEvent.crewBlue = CRYSTAL_BLUEPRINT
                end
                if crewEvent.eventName == NAI_CREW_EVENT_NAME then
                    print("Found new crew option")
                    choice.requirement.min_level = 1
                end
            else
                print("not nai mode")
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(locationEvent)
        modifyCheck(locationEvent)
    end)







