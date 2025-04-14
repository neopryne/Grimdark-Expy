--[[
This is the file that is a library of effects that can go on crew, and also tracking which crew have which effects applied to them.  This will live within LWL.
todo add toggle to let effects be affected by time dilation

effect
    value
    onTick()
    onRender() --you shouldn't put functional logic here

--]]
if (not mods) then mods = {} end
mods.lightweight_crew_effects = {}
local lwce = mods.lightweight_crew_effects
local lwl = mods.lightweight_lua
--Tracks an internal list of all crew, updates it when crew are lost or gained.
--Not impelmenting persistance as a core feature.  You feel like reloading to clear statuses, go for it.
local function NOOP() end

--A crew object will look something like this effect_crew = {crewmem=, bleed={}, effect2={}}
local crewList = {}
local scaledLocalTime = 0
--A fun thing might look at how many effects are on a given crew.  It should be easy to get the list of effects on a given crew.  PRetty sure it is as written.

--Strongly recommend that if you're creating effects with this, add them to this library instead of your mod if they don't have too many dependencies.
function lwce.createCrewEffect(name, onTick, onRender)
    return {name, onTick, onRender}
end


local function tickBleed(effect_crew, bleed)
    effect_crew.crewmem:DirectModifyHealth(-.03)
    bleed.value = bleed.value - 1
    if (bleed.value < 0) then
        effect_crew.bleed = nil
    end
end

lwce.bleed = lwce.createCrewEffect("bleed", tickBleed, NOOP)



local function tickEffects()
    for _,effect_crew in ipairs(crewList) do
        for key,effect in ipairs(effect_crew) do
            if not (key == "crewmem") then
                effect.onTick()
            end
        end
    end
end

--todo scale to real time, ie convert to 30ticks/second rather than frames.
if (script) then
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        scaledLocalTime = scaledLocalTime + (Hyperspace.FPS.SpeedFactor * 16)
        if (scaledLocalTime > 1) then
            tickEffects()
            scaledLocalTime = 0
        end
    end)
end