local vter = mods.multiverse.vter

local lwl = mods.lightweight_lua
--uh, there might be some things you need to do on load, like setting max hull again.

local fd

local mGlobal = Hyperspace.Global.GetInstance()
local mBlueprintManager = mGlobal:GetBlueprints()
--todo can this be here?
local CRYSTAL_NAME = "crystal"
local NAI_CREW_EVENT_NAME = "GEX_NAI_STARTING_CREW"
local START_BEACON_EVENT_NAME = "START_BEACON_PREP_OPTIONS"
local START_CREW_EVENT_NAME = "START_BEACON_PREP_OPTIONS 25"
local GEX_NAI_MODE_KEY = "GEX_MASOCHISMODE"
local CRYSTAL_BLUEPRINT = mBlueprintManager:GetCrewBlueprint(CRYSTAL_NAME)

local function activateNaiMode()
    --set metavar for nai mode.
    --ship hull max is less.
end
--todo onload, smash hull if nai.

local mIsInitialized = false

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    --Initialization code
    if mIsInitialized or (not Hyperspace.ships(0)) or lwl.isPaused() then return end

    mIsInitialized = true
    if Hyperspace.playerVariables[GEX_NAI_MODE_KEY] then
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







