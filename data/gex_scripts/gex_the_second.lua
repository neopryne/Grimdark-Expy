if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwst = mods.lightweight_stable_time
local lwui = mods.lightweight_user_interface
local lwsb = mods.lightweight_statboosts
local lweb = mods.lightweight_event_broadcaster
local lwce = mods.lightweight_crew_effects
local cel = mods.crew_equipment_library
local cels = mods.crew_equipment_library_slots
local gex = mods.grimdark_equipment
local fusionFires

local Brightness = mods.brightness
local get_room_at_location = mods.multiverse.get_room_at_location
local userdata_table = mods.multiverse.userdata_table

local TAG = "mods.grimdark_equipment"
--As library, needs to reject things with duplicate names, pop error. lib in lwl, GEXPy uses lib and adds the items.
--I probably need to hash out custom persist stuff first.
if not cel then
    error("Crew Equipment Library was not patched, or was patched after Grimdark Expy.  Install it properly or face undefined behavior.")
end
if not mods.fusion then
    lwl.logError(TAG, "Fusion was not patched, or was patched after Grimdark Expy.  Some items will not work properly.")
else
    fusionFires = mods.fusion.custom_fires
end

--#region --------------------------------------------------DEFINES----------------------

local mGlobal = Hyperspace.Global.GetInstance()
local mSoundControl = mGlobal:GetSoundControl()

local TYPE_WEAPON = cels.TYPE_WEAPON
local TYPE_ARMOR = cels.TYPE_ARMOR
local TYPE_TOOL = cels.TYPE_TOOL
--#endregion


--#region Red Tearstone Ring
local function generateAttackBoostFunction(crewmem)
    return function()
        --scale up to 50% damage at 20% health.
        local healthFraction = crewmem.health.first / crewmem.health.second
        local boost = .625 - (.625 * healthFraction)
        boost = math.min(.5, boost)
        return 1 + boost
    end
end

local function RtsrEquip(item, crewmem)
    local filterFunction = lwl.generateCrewFilterFunction(crewmem)
    item.damageBoost = lwsb.addStatBoost(Hyperspace.CrewStat.DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_MULTIPLY, generateAttackBoostFunction(crewmem), filterFunction)
end

local function RtsrRemove(item, crewmem)
    lwsb.removeStatBoostAllowNil(item.damageBoost)
end
local RED_TEARSTONE_RING_DEFINITION = {name="Red Tearstone Ring", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/rtsr.png"), description="A small ring, with a brilliant red gem.  Said to provide aid in times of need.\nBoosts attack scaling with missing health, up to a 50% increase at 20% health.", onEquip=RtsrEquip, onRemove=RtsrRemove}

--#endregion

--#region Inferno Core
local fireImage
if mods.fusion then
    fireImage = Hyperspace.Resources:GetImageId("custom_fires/inferno_flames.png")
end

--TODO popup an image of the item(s) you get when you get them.  Have a queue of items to show and do it in order like steam achivements.  Plus a bit of background.
--Maybe a name.
--These are lwui objects that have a custom render function that uses their images.  This will require the Brightness primatives manager.  maybe that can wait.

--Add some balancing parameters to how often you get items, such that rainbow mode gives you three items each sector but disables them otherwise.
--And smoothing parameters.

--If I want to use scorch, it should be a visual effect every so often, a pulse of scorch.

local function InfernoCore(item, crewmem)
    if mods.fusion then
        local shipManager = Hyperspace.ships(crewmem.currentShipId)
        local roomNum = get_room_at_location(shipManager, crewmem:GetPosition(), true)
        local room = lwl.getRoomById(crewmem.currentShipId, roomNum)
        local scaleFactor = gex.scaleEffect(nil, crewmem, 1)
        for fire in fusionFires.fires(room, shipManager) do
            --if fire.fStartTimer > 0 then
                local fireExtend = fusionFires.get_fire_extend(fire) --I can't actually tell if this works
                fireExtend.systemDamageMultiplier = fireExtend.systemDamageMultiplier * 2 * scaleFactor
                fireExtend.spreadSpeedMultiplier = fireExtend.spreadSpeedMultiplier + (.01 * scaleFactor)
                --fireExtend.deathSpeedMultiplier = roomFireData[1]
                fireExtend.oxygenDrainMultiplier = fireExtend.deathSpeedMultiplier * 2 * scaleFactor
                fireExtend.animationSpeedMultiplier = fireExtend.deathSpeedMultiplier * 2 * scaleFactor
                fireExtend.replacementSheet = fireImage
                --print("Boosting fire", fire, "start timer", fire.fStartTimer, "death timer", fire.fDeathTimer, "o2", fire.fOxygen, "image", fireImage)
            --end
        end
    end
end

local function InfernoCoreEquip(item, crewmem)
    local filterFunction = lwl.generateCrewFilterFunction(crewmem)
    item.fireResistBoost = lwsb.addStatBoost(Hyperspace.CrewStat.FIRE_DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, 0, filterFunction)
end

local function InfernoCoreRemove(item, crewmem)
    lwsb.removeStatBoostAllowNil(item.fireResistBoost)
end

local INFERNO_CORE_DEFINITION = {name="Inferno Core", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/inferno_core.png"), description="An ancient glowing orb, cool to the touch, wild, but crafted with care. --Burn; Not up, not out.\nGrants complete fire resistance and expedites nearby flames.", onEquip=InfernoCoreEquip, onRemove=InfernoCoreRemove, onTick=InfernoCore}
--#endregion
--#region Strange Present
-------------------Strange Present------------------
local function StrangePresentCreate(item)
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
    cel.deleteItem(item.button, item)
end

local STRANGE_PRESENT_DEFINITION = {name="Strange Present", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/CEL_ERROR.png"),
    description="It seems almost alive... (YOU SHOULD NEVER SEE THIS)", onCreate=StrangePresentCreate}
-- a small chance each jump to spawn another?  No, that will be a different thing.  Then more things that care about the number of things you have.
--#endregion



--#region -------------------Lootbox------------------
--[[
A lootbox has: lock, contents, modifiers.
easy: -1
medium: 0
hard: 1
challenging: 2
epic: 3
]]
--todo the locks might be hard to do without making different items for each lock, then using a spawner for them.

local function jumpsLock(item, crewmem, difficulty)
    local numJumps = math.random(1,3) + difficulty
    item.lockProgress = 0

    return function (item, crewmem, difficulty)
        gex.onJump(item, crewmem, function (item, crewmem)
            item.lockProgress = item.lockProgress + 1
            if (item.lockProgress >= numJumps) then
                item.unlocked = true
            end
        end)
    end
end

local sLockFunctions = {jumpsLock}

local function randomLock(difficulty)
    return lwl.getRandomValue(sLockFunctions)
end



local function itemContents(item, crewmem, difficulty)
    gex_give_random_item(false)
end

local sContentsFunctions = {itemContents}

local function randomContents(difficulty)
    return lwl.getRandomValue(sContentsFunctions)
end

--todo modifiers

local function randomModifier()
    return {} --none, idk how modifiers work yet, ignore for now.  Modifiers affect difficulty, and so are created before the rewards but after the lock.
end

local function LootBoxTick(item, crewmem)
    
    item.tickLock(item, crewmem)
    if item.unlocked then
        --destroy and give items.
        item.rewards(item, crewmem)
        cel.deleteItem(item.button, item)
    end

    --do something with modifiers.?  maybe pass them to tickLock and giveContents?  implicitly, since they're on the item.
end


local function LootBoxCreate(item)
    
end


--todo need to persist and load the different parts of the crate.  indexed if saved, random if not.
local LOOT_BOX_DEFINITION = {name="Strange Present", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/CEL_ERROR.png"),
    description="It seems almost alive... (YOU SHOULD NEVER SEE THIS)", onCreate=StrangePresentCreate}


--#endregion





cel.insertItemDefinition(RED_TEARSTONE_RING_DEFINITION)
--cel.insertItemDefinition(STRANGE_PRESENT_DEFINITION) --todo I need to figure out how to make a crew trigger an event on death.
cel.insertItemDefinition(INFERNO_CORE_DEFINITION)
print("Item distribution:", lwl.dumpObject(cel.itemTypeDistribution))


--[[
effects:polymorphitis --Once I figure out how to make multiple race stat boosts not crash the game
        heartache?

Volatile Hypercells: uses 
--how to get dynamic list of all crew types in the game
Wait that thing bliz was talking about doens't work for this.
Upon reaching 0 hp, consume this item to regenerate as a random race.
LIST_CREW_ALL_CRAPBUCKET union
Chaotic Hypercells --Uses LIST_CREW_UNIQUE_CRAPBUCKET or LIST_CREW_ALL_CRAPBUCKET
Super chaos: Uses every race, even the summons.


Items that make themselves not secret when the correct addons are installed:
    Spell Jam
    This refreshing snack allows an additional use of any equipped spells.
    (actually just gives vampweed cultists an additional charge to all abilities.)
A crew that has a list of all crew they've killed, and will transform into them upon death.

todo persist status effects on crewe
Torpor Projector 
Determination -- Getting hit charges your abilities.
Medbot Injector -- armor, Health recharge passive

An active that gives you a random amount of teleportitis.

Cursed equipment that turns your crew into a lump of rocks. \hj
Interface Scrambler -- Removes manning bonus from all enemy systems and prevents them from being manned.
Holy Symbol: [hand grenade, (), hl2 logo, random objects]
A fun thing might look at how many effects are on a given crew.  It should be easy to get the list of effects on a given crew.  PRetty sure it is as written.
  30% system resist to the room you're in
Galpegar
Noctus
The Thunderskin  --Crew cannot fight and gains 100 health. When in a room with injured allies, bleeds profusely and heals them.  Needs statboost for the cannot fight probably.
The Sun in Rags
A cursed item that autoequips
--todo item onLoad onPersist methods for things that need to save stuff
Blood is Mine, something else I forgot for art assets
FTF Discette
Right Eye of Argupel
A collection of the latest tracks from backwater bombshell Futanari Titwhore Fiasco
crew gets for each equiped crew
equipped crew get for each equipment on them
living bomb
Violent Artist
Besplator
I need a number for how many ticks are in a second.

Library for text effects, with a list of text effects, like rainbow and trans text like qud has.  Arc made some, but people haven't libraried it yet.

Item: User Manual
    Creates one of several user manuals on create, destroys itself.  These are consumables? that give the user one extra level of skill.
    They all have the same image, but different descriptions.

Item that spawns an immobile crew that can't fight and is hostile/invader for you to punch to get an item.

Giftbox: lots of things!  No sell value, but might give you stuff when it dies...
Confounding Crate: Spawns with a  Give it to a crew to work on opening.
Crates have a number of attributes:
    The locking mechanism.  This can be one of:
        A random chance to open each jump
        A set number (some crew are better at seeing this than others?)
        A specific unlock condition that must be met
    The contents
            It actually figures out what it's going to give you when it spawns, and that determines things like time till open
            Each type of contents has a different randomization method of figuring out what it's going to give you, and each lock takes the total value and does something with it.
        1-3 random items
        holy shit it's a guy
        loot (v high value)
        augments?
    A set of modifiers:
        Transparent: you can see what's inside
        Opulent: worth more, and if you open it you can sell the box.
        Cursed: Triggers a curse effect when opened.  Opening it inflicts lots of Corrupted on the crew that opened it, or triggers a gnome effect, or turns into a curse item that you can't remove.
        Ghostly: Crew opening it cannot be targeted.
        Noxious: drains hp while equipped
        Charged: one bar of zoltan power, but also occasionally ions the current room.
        Rusty: easier to open, some of the internals have decayed to scrap.  You get told what's unsalvageable.
        Unsettling: lowers your stability when opened.
        Booby-trapped: May deal hull damage when opened, (will check and use crew's interfacing stat if this exists), else 70% chance of failure.
        Haunted: Chases your crew around the ship


An item that stacks with itself when you place it on itself... Render func's going to be hard for that one...
Maybe it gets brighter each level?  A thing that you feed other things to power it up...


using userdata tables for the things that go on characters.
Inferno Core -- Tool, Fire immunity, Increases burn speed of fires in the same room.
RTSR -- Attack buff that scales with %missing health.

A lot of programming is saying, "how can I do this but like that instead?" in the smallest possible semantic structure.

--]]--45 c cvgbhbhyh bbb