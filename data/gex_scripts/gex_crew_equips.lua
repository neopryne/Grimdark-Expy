if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwsb = mods.lightweight_statboosts
local lwce = mods.lightweight_crew_effects
local cel = mods.crew_equipment_library

local Brightness = mods.brightness
local get_room_at_location = mods.multiverse.get_room_at_location
local userdata_table = mods.multiverse.userdata_table

--As library, needs to reject things with duplicate names, pop error. lib in lwl, GEXPy uses lib and adds the items.
--I probably need to hash out custom persist stuff first.
if not cel then
    error("Crew Equipment Library was not patched, or was patched after Grimdark Expy.  Install it properly or face undefined behavior.")
end
----------------------------------------------------DEFINES----------------------

local TYPE_WEAPON = cel.TYPE_WEAPON
local TYPE_ARMOR = cel.TYPE_ARMOR
local TYPE_TOOL = cel.TYPE_TOOL

--[[
--Crew name list
Swankerdino
Swankerpino
Bing Chillin
--]]




-----------------------------------------HELPER FUNCTIONS---------------------------------

---comment
---@param item table
---@param crewmem Hyperspace.CrewMember
---@param doOnJump function Takes (item, crewmem)
local function onJump(item, crewmem, doOnJump)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        doOnJump(item, crewmem)
    end
    item.jumping = Hyperspace.ships(0).bJumping
end


local function getTickSize(item, crewmem, baseValue)
    local crewTable = userdata_table(crewmem, "mods.gex.crew_modifiers")
    crewTable.tickMult = lwl.setIfNil(crewTable.tickMult, 1)
    return baseValue * crewTable.tickMult
end

------------------------------------ITEM DEFINITIONS----------------------------------------------------------
--Only the player can use items.
-------------------SHREDDER CUFFS------------------
local function ShredderCuffs(item, crewmem)
    if crewmem.bFighting and crewmem.bSharedSpot then
        local ownshipManager = Hyperspace.ships(0)
        local foeShipManager = Hyperspace.ships(1)
        local foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y)
        for _,foe in ipairs(foes_at_point) do
            foe:DirectModifyHealth(getTickSize(item, crewmem, -.05))
        end
    end
end
-------------------SEAL HEAD------------------
local function SealHead(item, crewmem)
    if item.stunCounter == nil then
        item.stunCounter = 0
    end
    if crewmem.bFighting and crewmem.bSharedSpot then
        item.stunCounter = item.stunCounter + getTickSize(item, crewmem, .005)
        if (item.stunCounter > 1) then
            item.stunCounter = 0
            local ownshipManager = Hyperspace.ships(0)
            local foeShipManager = Hyperspace.ships(1)
            local foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y)
            for _,foe in ipairs(foes_at_point) do
                foe.fStunTime = foe.fStunTime + .3
            end
        end
    end
end
--equinoid tools scale off bp and have +3 mult when applied to horse.
-------------------CHICAGO TYPEWRITER------------------
local function ChicagoTypewriter(item, crewmem)
    if (item.manningWeapons == nil) then item.manningWeapons = false end
    --print(crewmem:GetName(), "using skill ", crewmem.usingSkill)
    local manningWeapons = crewmem.iManningId == lwl.SYS_WEAPONS() and crewmem.currentShipId == crewmem.iShipId
    --Specifically for weapons and drones, this needs to be if they're standing in the room, which is what this checks.  Other versions can check usingSkill.
    --bBoostable was already true.  You could do interesting stuff with setting this to false for enemy systems as a minor effect.
    if manningWeapons ~= item.manningWeapons then
        if manningWeapons then
            Hyperspace.ships.player.weaponSystem:UpgradeSystem(1)
        else
            Hyperspace.ships.player.weaponSystem:UpgradeSystem(-1)
        end
    end
    item.manningWeapons = manningWeapons
end

local function ChicagoTypewriterRemove(item, crewmem)
    if item.manningWeapons then
        Hyperspace.ships.player.weaponSystem:UpgradeSystem(-1)
        item.manningWeapons = false
    end
end
-------------------BALLANCEATOR------------------
local function Ballanceator(item, crewmem)
    local dpt = getTickSize(item, crewmem, .185)
    if (crewmem:GetIntegerHealth() > crewmem:GetMaxHealth() / 2) then
        crewmem:DirectModifyHealth(-dpt)
    else
        crewmem:DirectModifyHealth(dpt)
    end
end
-------------------HELLION HALBERD------------------
local function HellionHalberd(item, crewmem)
    if crewmem.bFighting and crewmem.bSharedSpot then
        --foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y) --coords are relative to the first manager.
        --foes_at_point = lwl.getFoesAtPoint(crewmem, crewmem.x, crewmem.y) --this is actually harder to implement as it involves converting points in mainspace to one of the ships.
        for _,foe in ipairs(lwl.getFoesAtSelf(crewmem)) do
            lwce.applyBleed(foe, getTickSize(item, crewmem, 21))
        end
    end
end
-------------------PEPPY BISMOL------------------
local function PeppyBismolEquip(item, crewmem)
    item.appliedBoost = lwsb.addStatBoost(Hyperspace.CrewStat.POWER_RECHARGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_ADD, .6, lwl.generateCrewFilterFunction(crewmem))
end

local function PeppyBismolRemove(item, crewmem)
    lwsb.removeStatBoost(item.appliedBoost)
end
-------------------Medkit------------------
local function MedkitEquip(item, crewmem)
    item.appliedBoost = lwsb.addStatBoost(Hyperspace.CrewStat.MAX_HEALTH, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_ADD, 20, lwl.generateCrewFilterFunction(crewmem))
end
local function MedkitRemove(item, crewmem)
    lwsb.removeStatBoost(item.appliedBoost)
end
-------------------Graft Armor------------------
local function GraftArmorEquip(item, crewmem)
    item.healthBoost = lwsb.addStatBoost(Hyperspace.CrewStat.MAX_HEALTH, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_ADD, 5, lwl.generateCrewFilterFunction(crewmem))
    item.stunBoost = lwsb.addStatBoost(Hyperspace.CrewStat.STUN_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_MULTIPLY, 0.5, lwl.generateCrewFilterFunction(crewmem))
    lwce.addResist(crewmem, lwce.KEY_BLEED, 1)
end

local function GraftArmorRemove(item, crewmem)
    lwsb.removeStatBoost(item.healthBoost)
    lwsb.removeStatBoost(item.stunBoost)
    lwce.addResist(crewmem, lwce.KEY_BLEED, -1)
end
-------------------It's Terrible!------------------
local function statusTestEquip(item, crewmem)
    lwce.applyBleed(crewmem, 3)
    lwce.applyConfusion(crewmem, 3)
    lwce.applyTeleportitis(crewmem, 3)
    --print("Applying corruption!")
    lwce.applyCorruption(crewmem, .2)
end
local function statusTest(item, crewmem)
    lwce.applyBleed(crewmem, getTickSize(item, crewmem, 1))
    lwce.applyConfusion(crewmem, getTickSize(item, crewmem, 1))
    lwce.applyTeleportitis(crewmem, getTickSize(item, crewmem, 1))
    --lwce.applyCorruption(crewmem, .1)
end
local function statusTestRemove(item, crewmem)
    --print("Removing corruption!")
    lwce.applyCorruption(crewmem, -.2)
end
-------------------Omelas Generator------------------
local function OmelasGeneratorEquip(item, crewmem) --mAYBE MAKE THIS CURSED.  Also this is broken and does not remove power properly, possibly upon exiting the game.  I should check the typewriter as well.  I need to call the onRemove methods of all items when quitting the game.  No such hook exists.
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    powerManager.currentPower.second = powerManager.currentPower.second + 4
end

local function OmelasGenerator(item, crewmem)
    lwce.applyCorruption(crewmem, getTickSize(item, crewmem, .006))
end

local function OmelasGeneratorRemove(item, crewmem)
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    powerManager.currentPower.second = powerManager.currentPower.second - 4
end
-------------------Ferrogenic Exsanguinator------------------
local function FerrogenicExsanguinator(item, crewmem)
    --If crew repairing a system, apply bleed and repair system more.
    if crewmem:RepairingSystem() and not crewmem:RepairingFire() then
        local currentShipManager = Hyperspace.ships(crewmem.currentShipId)
        local systemId = crewmem.iManningId
        local system = currentShipManager:GetSystem(systemId)
        system:PartialRepair(getTickSize(item, crewmem, 12.5), false)
        lwce.applyBleed(crewmem, getTickSize(item, crewmem, 3.2))
    end
end
-------------------Egg------------------  --Any internal status, beyond just is this thing equipped, needs a custom persist/load to handle that.
local KEY_EGG_VALUE = "egg_value"
local function loadEgg(item, metaVarIndex)
    item.sellValue = math.floor(lwl.setIfNil(Hyperspace.metaVariables[KEY_EGG_VALUE..metaVarIndex], 0))
    --print("loaded egg", item.sellValue, metaVarIndex)
end

local function persistEgg(item, metaVarIndex)
    --print("persist egg", item.sellValue, metaVarIndex)
    Hyperspace.metaVariables[KEY_EGG_VALUE..metaVarIndex] = item.sellValue
end

local function EggOnJump(item, crewmem)
    item.sellValue = item.sellValue + getTickSize(item, crewmem, 3)
    cel.persistEquipment()
end

local function Egg(item, crewmem)
    onJump(item, crewmem, EggOnJump)
end
-------------------Myocardial Overcharger------------------
local KEY_MYOCARDIAL_OVERCHARGER_VALUE = "myocardial_overcharger_value"
local function generateMyocardialOverchargerOnSell(item)
    return function(_)
        item.itemsSold = item.itemsSold + 1
    end
end

local function generateMyocardialOverchargerValueFunction(item)
    return function()
        return item.itemsSold * 5
    end
end

local function persistMyocardialOvercharger(item, metaVarIndex)
    Hyperspace.metaVariables[KEY_MYOCARDIAL_OVERCHARGER_VALUE..metaVarIndex] = item.itemsSold
end

local function loadMyocardialOvercharger(item, metaVarIndex)
    item.itemsSold = lwl.setIfNil(Hyperspace.metaVariables[KEY_MYOCARDIAL_OVERCHARGER_VALUE..metaVarIndex], 0)
end

local function MyocardialOverchargerCreate(item)
    item.itemsSold = 0
    cel.registerListener(cel.ITEM_SOLD_EVENT, generateMyocardialOverchargerOnSell(item))
    item.valueFunction = generateMyocardialOverchargerValueFunction(item)
end

local function MyocardialOverchargerRender(item, crewmem)
    item.sellValue = math.floor(6 + (item.valueFunction() / 5))
end

local function MyocardialOverchargerEquip(item, crewmem)
    item.appliedBoost = lwsb.addStatBoost(Hyperspace.CrewStat.MAX_HEALTH, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_ADD, item.valueFunction, lwl.generateCrewFilterFunction(crewmem))
end

local function MyocardialOverchargerRemove(item, crewmem)
    lwsb.removeStatBoost(item.appliedBoost)
end
-------------------Holy Symbol------------------
local function HolySymbolRender()
    local holySymbolIcons = {"holy_symbol_1.png", "holy_symbol_2.png", "holy_symbol_3.png"}
    local chosenIcon = holySymbolIcons[math.random(1,#holySymbolIcons)]
    return lwui.spriteRenderFunction("items/"..chosenIcon)
end

local function HolySymbolEquip(item, crewmem)
    --print("Holy symbol equipped!")
    lwce.addResist(crewmem, lwce.KEY_CORRUPTION, .9)
end

local function HolySymbolRemove(item, crewmem)
    --print("Holy symbol removed!")
    lwce.addResist(crewmem, lwce.KEY_CORRUPTION, -.9)
end
-------------------Interfangilator------------------
local KEY_INTERFANGILATOR_SUPPRESSION = "interfangilator_bars_suppressed"
local KEY_INTERFANGILATOR_PREVIOUS_DAMAGE = "interfangilator_previous_damage"
local function InterfangilatorLoad(item, metaVarIndex)
    item.storedValue = lwl.setIfNil(Hyperspace.metaVariables[KEY_INTERFANGILATOR_SUPPRESSION..metaVarIndex], 0)
    item.previousDamage = lwl.setIfNil(Hyperspace.metaVariables[KEY_INTERFANGILATOR_PREVIOUS_DAMAGE..metaVarIndex], 0)
    --print("loaded", item.name, item.storedValue, item.previousDamage)
end

local function InterfangilatorPersist(item, metaVarIndex)
    Hyperspace.metaVariables[KEY_INTERFANGILATOR_SUPPRESSION..metaVarIndex] = lwl.setIfNil(item.storedValue, 0)
    Hyperspace.metaVariables[KEY_INTERFANGILATOR_PREVIOUS_DAMAGE..metaVarIndex] = lwl.setIfNil(item.previousDamage, 0)
end

local function InterfangilatorApplyEffect(item, crewmem, value) --mostly checks crewmem values
    local targetShipManager = Hyperspace.ships(1 - crewmem.iShipId)
    if crewmem.iManningId >= 0 and targetShipManager and (crewmem.currentShipId == crewmem.iShipId) then
        local system = targetShipManager:GetSystem(crewmem.iManningId)
        if system then
            --print("if applying", value, "system is", system.name)
            local beforePower = system:GetPowerCap()
            --print("before power", beforePower)
            item.previousDamage = system.healthState.second - system.healthState.first
            system:UpgradeSystem(-math.min(value, system.healthState.second))
            item.storedValue = beforePower - system:GetPowerCap()
            local targetPosition = targetShipManager:GetRoomCenter(system:GetRoomId())
            item.roomEffect = Brightness.create_particle("particles/Interfangilator", 1, 60, targetPosition, 0, targetShipManager.iShipId, "SHIP_MANAGER")
            --print("Stored value ", item.storedValue, "system now has", system.healthState.second, "bars")
            item.roomEffect.persists = true
            --should also store damage status of the removed bars. may be hard.
            cel.persistEquipment()
        end
    end
end

local function removeRoomEffect(item)
    if item.roomEffect then
        Brightness.destroy_particle(item.roomEffect)
        item.roomEffect = nil
    end
end

--todo sseems like loading with an enemy system fully disabled crashes your save.  I could fix this by not 
--todo something is still wrong with loading this, a ship that used to have three bars now has two (custom)
local function InterfangilatorRemoveEffect(item, crewmem)
    --print("Removing effect", item.name, item.storedValue)
    local targetShipManager = Hyperspace.ships(1 - crewmem.iShipId)
    local sourceSystem = item.system
    sourceSystem = lwl.setIfNil(sourceSystem, crewmem.currentSystem)--If we just loaded, item.system will be nil but the crew knows where it is.
    if sourceSystem and targetShipManager and item.storedValue then
        local targetSystem = targetShipManager:GetSystem(sourceSystem:GetId())
        if targetSystem then
            --print("if removing ", targetSystem.name, item.storedValue)
            targetSystem:UpgradeSystem(item.storedValue)
            --print("if upgraded system by ", item.storedValue)
            if targetSystem:CompletelyDestroyed() then  
                if item.previousDamage then
                    targetSystem.healthState.first = math.min(item.storedValue, targetSystem.healthState.second - item.previousDamage)
                end
            end
        end
        removeRoomEffect(item)
        item.previousDamage = 0
        item.storedValue = 0
        cel.persistEquipment()
    end
end

local function InterfangilatorCommonCore(item, crewmem, strength)
    onJump(item, crewmem, function (item, crewmem)
        item.ready = true
        item.systemId = nil
    end)

    if (not Hyperspace.ships.enemy) or Hyperspace.ships.enemy.bDestroyed then --todo clean up this logic
        removeRoomEffect(item)
    end

    if item.ready or ((item.system ~= crewmem.currentSystem)) then
        item.storedValue = lwl.setIfNil(item.storedValue, strength)
        if not item.ready then
            InterfangilatorRemoveEffect(item, crewmem)
        else
            removeRoomEffect(item)
        end
        InterfangilatorApplyEffect(item, crewmem, strength)
        item.ready = false
    end
    item.system = crewmem.currentSystem
end


local function Interfangilator(item, crewmem)
    InterfangilatorCommonCore(item, crewmem, 1)
end

local function InterfangilatorRemove(item, crewmem)
    InterfangilatorRemoveEffect(item, crewmem)
end
-------------------Custom Interfangilator------------------
-- Reduces it by the crew's skill level in that system.
local function CustomInterfangilatorLevel(crewmem)
    return crewmem:GetSkillLevel(Hyperspace.CrewMember.GetSkillFromSystem(crewmem.iManningId)) - 1
end

local function CustomInterfangilator(item, crewmem) --todo misbehaves if crew skilled up while active, but that happens like twice.
    InterfangilatorCommonCore(item, crewmem, CustomInterfangilatorLevel(crewmem))
end
-------------------Compactifier------------------
local function CompactifierEquip(item, crewmem)
    item.appliedBoost = lwsb.addStatBoost(Hyperspace.CrewStat.NO_SLOT, lwsb.TYPE_BOOLEAN, lwsb.ACTION_SET, true, lwl.generateCrewFilterFunction(crewmem))
end

local function CompactifierRemove(item, crewmem)
    lwsb.removeStatBoost(item.appliedBoost)
end
-------------------INTERNECION CUBE------------------
local function InternecionCubeEquip(item, crewmem)
    item.value = 0
end

local MURDERBOT_LIST = {"NANOBOT_DEFENSE_SYSTEM", "LOCKED_NANOBOT_DEFENSE_SYSTEM", "IZD_NANOBOT_DEFENSE_SYSTEM", "HIDDEN IZD_NANOBOT_DEFENSE_SYSTEM", "FM_NO_IZD_MURDERBOTS", "DECREPIT_MURDERBOTS", "ANCIENT_MURDERBOTS", "ROYAL_MURDERBOTS", "AEA_NECRO_MURDERBOTS"}
local IC_on_TEXT = "Cute and lethal, this boodthirsty being will carve up your foes and sometimes you (in a good way). Damages all enemies in the same room when fighting. If crew is below full health, periodically stun and heal them."
local function InternecionCube(item, crewmem)
    local murderMultiplier = 1
    for _,murderAugName in ipairs(MURDERBOT_LIST) do
        murderMultiplier = murderMultiplier + Hyperspace.ships.player:HasAugmentation(murderAugName)
    end
    if murderMultiplier > 1 then
        item.description = IC_on_TEXT.." Boosted [X][X] "..murderMultiplier.." by MURDER!"
    else
        item.description = IC_on_TEXT
    end
    
    item.value = item.value + getTickSize(item, crewmem, (.24 + ((murderMultiplier - 1) / 3)))
    if item.value > 100 then
        item.value = 0
        if crewmem.health.first < crewmem.health.second then
            crewmem.fStunTime = crewmem.fStunTime + 2.5 + murderMultiplier
            crewmem:DirectModifyHealth(28 * murderMultiplier)
        end
    end

    if crewmem.bFighting then
        lwl.damageEnemyCrewInSameRoom(crewmem, getTickSize(item, crewmem,.07 * murderMultiplier), 0) --lwl might have issues if crew tag along after a jump todo fix?
        --todo damage everyone, increase heal.
    end
end
-------------------P.G.O------------------
local PGO_NAME = "Perfectly Generic Object"
local THREE_PGO_NAME = "a collection of little green cubes" --names need to be unique for the name to id table to work
local PGO_DESCRIPTION = "There's not much to say about this little green cube."
local PGO_SPRITE = "items/pgo.png"

local function PerfectlyGenericObjectCreate(item)
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
    cel.deleteItem(item.button, item)
end

local PGO_DEFINITION = {name=PGO_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(PGO_SPRITE), description=PGO_DESCRIPTION, secret=true}
local THREE_PGO_DEFINITION = {name=THREE_PGO_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(PGO_SPRITE),
    description=PGO_DESCRIPTION, onCreate=PerfectlyGenericObjectCreate}
-- a small chance each jump to spawn another?  No, that will be a different thing.  Then more things that care about the number of things you have.
-------------------Awoken Thief's Hand------------------
local AWOKEN_THIEFS_HAND_DESCRIPTION = "Said to once belong to the greatest thief in the multiverse, this disembodied hand has the ability to steal from space itself!  Empowered by the ring, it draws even the most obscure whatsits into existence."
local AWOKEN_THIEFS_HAND_NAME = "Awoken Rogue's Hand"

local function AwokenThiefsHand(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        if (math.random() > .46) then
            gex_give_random_item()
        end
    end
    item.jumping = Hyperspace.ships(0).bJumping
    --todo maybe add the base void ring effect.
end
-------------------Thief's Hand------------------
local VOID_RING_NAME = "Ring of Void"
local THIEFS_HAND_NAME = "Thief's Hand"
local THIEFS_HAND_DESCRIPTION_DORMANT = "Said to once belong to the greatest thief in the multiverse, this disembodied hand has the ability to steal from space itself!  The spoils though, are much less remarkable."

local function voidRingThiefsHandMerge(crewmem)
    local voidRingButton = cel.getCrewButtonWithItem(crewmem.extend.selfId, VOID_RING_NAME)
    local thiefsHandButton = cel.getCrewButtonWithItem(crewmem.extend.selfId, THIEFS_HAND_NAME)
    cel.deleteItem(voidRingButton, voidRingButton.item)
    cel.deleteItem(thiefsHandButton, thiefsHandButton.item)
    gex_give_item(cel.mNameToItemIndexTable[AWOKEN_THIEFS_HAND_NAME])
    Hyperspace.Sounds:PlaySoundMix("levelup", -1, false)
end

local function ThiefsHandEquip(item, crewmem)
    if (cel.crewHasItem(crewmem.extend.selfId, VOID_RING_NAME)) then
        voidRingThiefsHandMerge(crewmem)
    end
end

local function ThiefsHand(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        if (math.random() > .9) then
            gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
        end
    end
    item.jumping = Hyperspace.ships(0).bJumping
end
-------------------Ring of Void------------------
--Thief's Hand now spawns all objects when equipped to the same person.  Also increases spawn chance to 80%.
local function VoidRingEquip(item, crewmem)
    if (cel.crewHasItem(crewmem.extend.selfId, THIEFS_HAND_NAME)) then
        voidRingThiefsHandMerge(crewmem)
    end
    item.fightBoost = lwsb.addStatBoost(Hyperspace.CrewStat.CAN_FIGHT, lwsb.TYPE_BOOLEAN, lwsb.ACTION_SET, false, lwl.generateCrewFilterFunction(crewmem))
    item.targetableBoost = lwsb.addStatBoost(Hyperspace.CrewStat.VALID_TARGET, lwsb.TYPE_BOOLEAN, lwsb.ACTION_SET, false, lwl.generateCrewFilterFunction(crewmem))
end

local function VoidRingRemove(item, crewmem)
    lwsb.removeStatBoost(item.fightBoost)
    lwsb.removeStatBoost(item.targetableBoost)
end
-------------------Equinoid Tools------------------
local LIST_CREW_PONY = {"pony", "pony_tamed", "easter_sunkist", "unique_jerry_pony", "ponyc",
 "unique_jerry_pony_crystal", "pony_engi", "pony_engi_chaos", "pony_engi_nano", "pony_engi_nano_chaos", "fr_bonus_prince"}

--if conditions are met, destroy these and replace them with their true versions.
local YOUNG_DEPRESSEOR_NAME = "Strange Lump"
local YOUNG_DEPRESSEOR_TRUE_NAME = "Young Depressor"
local SUN_PILE_NAME = "Knobbly Mound"
local SUN_PILE_TRUE_NAME = "Sun Pile"
local MAW_SAWGE_NAME = "Toothy Plank"
local MAW_SAWGE_TRUE_NAME = "Maw Sawge"
local PRONGLER_NAME = "Hookish Staff"
local PRONGLER_TRUE_NAME = "Prongler"

local function equinoidCrewCondition()
    local playerCrew = lwl.getAllMemberCrewFromFactory(lwl.filterOwnshipTrueCrew)
    for _,crewmem in ipairs(playerCrew) do
        for _,ponyRace in ipairs(LIST_CREW_PONY) do
            if (crewmem.extend:GetDefinition().race == ponyRace) then
                return true
            end
        end
    end
    return false
end

local function itemTransform(condition, item, crewmem, newItemIndex)
    if condition(item, crewmem) then
        cel.deleteItem(item.containingButton, item)
        gex_give_item(newItemIndex)
    end
end

local function equinoidToolsOnJump(item, crewmem, trueName)
    itemTransform(equinoidCrewCondition, item, crewmem, cel.mNameToItemIndexTable[trueName])
end

local function StrangeLumpOnJump(item, crewmem)
    itemTransform(equinoidCrewCondition, item, crewmem, cel.mNameToItemIndexTable[YOUNG_DEPRESSEOR_TRUE_NAME])
end

local function KnobblyMoundOnJump(item, crewmem)
    itemTransform(equinoidCrewCondition, item, crewmem, cel.mNameToItemIndexTable[SUN_PILE_TRUE_NAME])
end

local function ToothyPlankOnJump(item, crewmem)
    itemTransform(equinoidCrewCondition, item, crewmem, cel.mNameToItemIndexTable[MAW_SAWGE_TRUE_NAME])
end

local function HookishStaffOnJump(item, crewmem)
    itemTransform(equinoidCrewCondition, item, crewmem, cel.mNameToItemIndexTable[PRONGLER_TRUE_NAME])
end

local function StrangeLumpEquip(item, crewmem)
    StrangeLumpOnJump(item, crewmem)
end

local function KnobblyMoundEquip(item, crewmem)
    KnobblyMoundOnJump(item, crewmem)
end

local function ToothyPlankEquip(item, crewmem)
    ToothyPlankOnJump(item, crewmem)
end

local function HookishStaffEquip(item, crewmem)
    HookishStaffOnJump(item, crewmem)
end

local function StrangeLump(item, crewmem)
    onJump(item, crewmem, StrangeLumpOnJump)
end

local function KnobblyMound(item, crewmem)
    onJump(item, crewmem, KnobblyMoundOnJump)
end

local function ToothyPlank(item, crewmem)
    onJump(item, crewmem, ToothyPlankOnJump)
end

local function HookishStaff(item, crewmem)
    onJump(item, crewmem, HookishStaffOnJump)
end

local YOUNG_DEPRESSEOR_SPRITE = "items/equinoid_tools_1.png"
local SUN_PILE_SPRITE = "items/equinoid_tools_2.png"
local MAW_SAWGE_PRITE = "items/equinoid_tools_4.png"
local PRONGLER_SPRITE = "items/equinoid_tools_3.png"

local STRANGE_LUMP_DESCRIPTION = "Its power is exceeded only by its mystery."
local KNOBBLY_MOUND_DESCRIPTION = "Its mystery is exceeded only by its power."
local TOOTHY_PLANK_DESCRIPTION = "A menagerie of twisty little protrusions, all different."
local HOOKISH_STAFF_DESCRIPTION = "It could be something like a coatrack, if you planted coatracks in the ground.  Or hung them from trees."

local YOUNG_DEPRESSEOR_DESCRIPTION = "Placed on rambunctious foals to calm them down. Equipped crew gains 60% damage resist, immunity to stun, mind control, and confusion, and can't fight."
local SUN_PILE_DESCRIPTION = "Absorbs sunlight and gets really hot.  Also tells time poorly.  Equipped crew breaks doors twice as fast and gains 50% fire resist."
local MAW_SAWGE_DESCRIPTION = "A nice treat after a long day on your hooves, the Maw Sawge allows equinoids to apply pressure to hard-to-reach spots."
local PRONGLER_DESCRIPTION = "Get prongled."

-------------------Young Depressor------------------
local function YoungDepressorEquip(item, crewmem)
    item.stunBoost = lwsb.addStatBoost(Hyperspace.CrewStat.STUN_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_MULTIPLY, 0, lwl.generateCrewFilterFunction(crewmem))
    item.mindBoost = lwsb.addStatBoost(Hyperspace.CrewStat.RESISTS_MIND_CONTROL, lwsb.TYPE_BOOLEAN, lwsb.ACTION_SET, true, lwl.generateCrewFilterFunction(crewmem))
    item.fightBoost = lwsb.addStatBoost(Hyperspace.CrewStat.CAN_FIGHT, lwsb.TYPE_BOOLEAN, lwsb.ACTION_SET, false, lwl.generateCrewFilterFunction(crewmem))
    item.damageResistBoost = lwsb.addStatBoost(Hyperspace.CrewStat.DAMAGE_TAKEN_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_MULTIPLY, .4, lwl.generateCrewFilterFunction(crewmem))
    lwce.addResist(crewmem, lwce.KEY_CONFUSION, 1)
    --Can't fight, MC, stun, and confusion immunity, damage resist.
end

local function YoungDepressorRemove(item, crewmem)
    lwsb.removeStatBoost(item.stunBoost)
    lwsb.removeStatBoost(item.mindBoost)
    lwsb.removeStatBoost(item.fightBoost)
    lwsb.removeStatBoost(item.damageResistBoost)
    lwce.addResist(crewmem, lwce.KEY_CONFUSION, -1)
end

-------------------Sun Pile------------------
local function SunPileEquip(item, crewmem)
    item.doorbustBoost = lwsb.addStatBoost(Hyperspace.CrewStat.DOOR_DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_MULTIPLY, 2, lwl.generateCrewFilterFunction(crewmem))
    item.fireResistBoost = lwsb.addStatBoost(Hyperspace.CrewStat.FIRE_DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_MULTIPLY, .5, lwl.generateCrewFilterFunction(crewmem))
end

local function SunPileRemove(item, crewmem)
    lwsb.removeStatBoost(item.doorbustBoost)
    lwsb.removeStatBoost(item.fireResistBoost)
end
-------------------Maw Sawge------------------
local function MawSawgeEquip(item, crewmem)
    --friendly regen up (for now, test on same crew only.)
    item.healBoost = lwsb.addStatBoost(Hyperspace.CrewStat.PASSIVE_HEAL_AMOUNT, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_ADD, 1, lwl.generateSameRoomAlliesFilterFunction(crewmem))
end

local function MawSawgeRemove(item, crewmem)
    lwsb.removeStatBoost(item.healBoost)
end
-------------------Prongler------------------
local function PronglerEquip(item, crewmem)
    --slow foes in the same room
    item.moveBoost = lwsb.addStatBoost(Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_NUMERIC_MULTIPLY, .4, lwl.generateSameRoomFoesFilterFunction(crewmem))
end

local function PronglerRemove(item, crewmem)
    lwsb.removeStatBoost(item.moveBoost)
end

local STRANGE_LUMP_DEFINITION = {name=YOUNG_DEPRESSEOR_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(YOUNG_DEPRESSEOR_SPRITE), description=STRANGE_LUMP_DESCRIPTION, onEquip=StrangeLumpEquip, onTick=StrangeLump, sellValue=3, secret=true}
local KNOBBLY_MOUND_DEFINITION = {name=SUN_PILE_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(SUN_PILE_SPRITE), description=KNOBBLY_MOUND_DESCRIPTION, onEquip=KnobblyMoundEquip, onTick=KnobblyMound, sellValue=3, secret=true}
local TOOTHY_PLANK_DEFINITION = {name=MAW_SAWGE_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(MAW_SAWGE_PRITE), description=TOOTHY_PLANK_DESCRIPTION, onEquip=ToothyPlankEquip, onTick=ToothyPlank, sellValue=3, secret=true}
local HOOKISH_STAFF_DEFINITION = {name=PRONGLER_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(PRONGLER_SPRITE), description=HOOKISH_STAFF_DESCRIPTION, onEquip=HookishStaffEquip, onTick=HookishStaff, sellValue=3, secret=true}

local YOUNG_DEPRESSEOR_DEFINITION = {name=YOUNG_DEPRESSEOR_TRUE_NAME, itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction(YOUNG_DEPRESSEOR_SPRITE), description=YOUNG_DEPRESSEOR_DESCRIPTION, onEquip=YoungDepressorEquip, onRemove=YoungDepressorRemove, secret=true}
local SUN_PILE_DEFINITION = {name=SUN_PILE_TRUE_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(SUN_PILE_SPRITE), description=SUN_PILE_DESCRIPTION, onEquip=SunPileEquip, onRemove=SunPileRemove, secret=true}
local MAW_SAWGE_DEFINITION = {name=MAW_SAWGE_TRUE_NAME, itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction(MAW_SAWGE_PRITE), description=MAW_SAWGE_DESCRIPTION, onEquip=MawSawgeEquip, onRemove=MawSawgeRemove, secret=true}
local PRONGLER_DEFINITION = {name=PRONGLER_TRUE_NAME, itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction(PRONGLER_SPRITE), description=PRONGLER_DESCRIPTION, onEquip=PronglerEquip, onRemove=PronglerRemove, secret=true}

--A fake object that represents four other objects.
local EQUINOID_TOOLS_NAME = "a set of strange objects"
local function EquinoidToolsCreate(item)
    gex_give_item(cel.mNameToItemIndexTable[YOUNG_DEPRESSEOR_NAME])
    gex_give_item(cel.mNameToItemIndexTable[SUN_PILE_NAME])
    gex_give_item(cel.mNameToItemIndexTable[MAW_SAWGE_NAME])
    gex_give_item(cel.mNameToItemIndexTable[PRONGLER_NAME])
    cel.deleteItem(item.button, item)
end
local EQUINOID_TOOLS_DEFINITION = {name=EQUINOID_TOOLS_NAME, onCreate=EquinoidToolsCreate}

-------------------Volatile Hypercells------------------

local function generateHypercellCrewList()
    return {"pony", "pony_engi"} --todo scrape the correct lists, or all crew types.
end
local HypercellCrewList = generateHypercellCrewList()

local function VolatileHypercells(item, crewmem)
    if (crewmem.health.first <= 0.1) then
        crewmem.bDead = false
        crewmem.health.first = 100
        local newType = HypercellCrewList[math.random(1, #HypercellCrewList)]
        local transformRace = Hyperspace.StatBoostDefinition()
        transformRace.stat = Hyperspace.CrewStat.TRANSFORM_RACE
        transformRace.stringValue = newType
        transformRace.value = true
        transformRace.cloneClear = false
        transformRace.jumpClear = false
        transformRace.boostType = Hyperspace.StatBoostDefinition_BoostType_SET
        transformRace.boostSource = Hyperspace.StatBoostDefinition_BoostSource_AUGMENT
        transformRace.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
        transformRace.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
        Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(transformRace), crewmem)
        Hyperspace.Sounds:PlaySoundMix("gex_cell_revive", 4, false)
        Hyperspace.Sounds:PlaySoundMix("gex_vial_break", 4, false)
        cel.deleteItem(item.button, item)
    end
end

--Ascendant Hypercells
--Chaotic Hypercells
-------------------Displacer Mace------------------
local GENERIC_DISPLACER_MACE_NAME = "mace with intricate aether circuits"
local DISPLACER_MACE_NAME = "Displacer Mace"
local CHAOTIC_DISPLACER_MACE_NAME = "Chaotic Displacer Mace"

local DISPLACER_MACE_TICK = .72
--I could create custom effect like things that 

local function DisplacerMaceCreate(item)
    if (math.random(1,2) == 1) then
        gex_give_item(cel.mNameToItemIndexTable[CHAOTIC_DISPLACER_MACE_NAME])
    else
        gex_give_item(cel.mNameToItemIndexTable[DISPLACER_MACE_NAME])
    end
    cel.deleteItem(item.button, item)
end

---maybe put in lwl if I end up liking this.
---@param crewmem Hyperspace.CrewMember
---@param validDestinations table of valid target ship ids
local function displaceCrew(crewmem, validDestinations)
    local shipId = validDestinations[math.random(#validDestinations)]
    if not Hyperspace.ships.enemy then
        shipId = 0
    end
    local shipManager = Hyperspace.ships(shipId)
    local newPoint = lwl.pointfToPoint(shipManager:GetRandomRoomCenter())
    local newRoom = get_room_at_location(shipManager, newPoint, false)
    local newSlot = lwl.randomSlotRoom(newRoom, shipManager.iShipId)
    --print("Teleporting", crewmem:GetName(), "to", newRoom, newSlot)
    crewmem.extend:InitiateTeleport(shipManager.iShipId, newRoom, newSlot)
    Hyperspace.Sounds:PlaySoundMix("teleport", 9, false)
end

local function DisplacerMaceGeneric(item, crewmem, validDestinations)
    --Get a random enemy in combat in the same room
    if crewmem.bFighting and crewmem.health.first >= 0.1 then
        item.value = item.value + getTickSize(item, crewmem, DISPLACER_MACE_TICK)
        --print("Mace", item.value)
        if item.value > 100 then
            item.value = 0
            local enemyCrewSameRoom = lwl.getSameRoomCrew(crewmem, lwl.generateOpposingCrewFilter(crewmem))
            --choose one at random to displace.
            if #enemyCrewSameRoom > 1 then error("GEX Displacer Mace -- Fighting nothing!") end
            local chosenFoe = enemyCrewSameRoom[math.random(#enemyCrewSameRoom)]
            --print("Displacing", chosenFoe:GetName())
            displaceCrew(chosenFoe, validDestinations)
        end
    end
end

local function DisplacerMaceEquip(item, crewmem)
    item.value = 0
end

local function DisplacerMace(item, crewmem)
    DisplacerMaceGeneric(item, crewmem, {crewmem.currentShipId})
end

local function ChaoticDisplacerMace(item, crewmem)
    DisplacerMaceGeneric(item, crewmem, {0,1})
end

local GENERIC_DISPLACER_MACE_DEFINITION = {name=GENERIC_DISPLACER_MACE_NAME, onCreate=DisplacerMaceCreate}
local DISPLACER_MACE_DEFINITION = {name=DISPLACER_MACE_NAME, itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/displacer_mace.png"), description="A futuristic design that looks heavier than it feels.  Banishes enemy crew to other parts of the ship.",  onEquip=DisplacerMaceEquip, onTick=DisplacerMace, secret=true}
local CHAOTIC_DISPLACER_MACE_DEFINITION = {name=CHAOTIC_DISPLACER_MACE_NAME, itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/displacer_mace_chaotic.png"), description="A futuristic design that looks heavier than it feels.  Banishes enemy crew to other parts of the ship.  The chaotic version can shunt victems off of the current ship.",  onEquip=DisplacerMaceEquip, onTick=ChaoticDisplacerMace, secret=true}
-------------------Overcloaker------------------
local function OvercloakerEquip(item, crewmem)
    local crewTable = userdata_table(crewmem, "mods.gex.crew_modifiers")
    crewTable.tickMult = lwl.setIfNil(crewTable.tickMult, 1)
    crewTable.tickMult = crewTable.tickMult + .5
end

local function OvercloakerRemove(item, crewmem)
    local crewTable = userdata_table(crewmem, "mods.gex.crew_modifiers")
    crewTable.tickMult = lwl.setIfNil(crewTable.tickMult, 1)
    crewTable.tickMult = crewTable.tickMult - .5
end





--[[
effects: teleportitis (foes only, this is a pain)
        slimed? (slow, reduce damage given)
        polymorphitis
        heartache?

Volatile Hypercells: uses 
--how to get dynamic list of all crew types in the game
Upon reaching 0 hp, consume this item to regenerate as a random race.
LIST_CREW_ALL_CRAPBUCKET union
Normal item: Hypercell Selector
Chaotic Hypercells --Uses LIST_CREW_UNIQUE_CRAPBUCKET or LIST_CREW_ALL_CRAPBUCKET
Super chaos: Uses every race, even the summons.


Items that make themselves not secret when the correct addons are installed:
    Spell Jam
    This refreshing snack allows an additional use of any equipped spells.
    (actually just gives vampweed cultists an additional charge to all abilities.)
A crew that has a list of all crew they've killed, and will transform into them upon death.

todo persist status effects on crew
Torpor Projector 
Determination -- Getting hit charges your abilities.
Inflatable muscles -- armor while about 1/3 health, extra damage
Medbot Injector -- armor, Health recharge passive
I guess I need status definitions so people know what they do.  Bleed is easy, the others less so.

Cursed equipment that turns your crew into a lump of rocks. \hj
Interface Scrambler -- Removes manning bonus from all enemy systems and prevents them from being manned.
    Or like, corruption% chance you don't revive.  5 corruption is already kind of a lot of damage.
Holy Symbol: [hand grenade, (), hl2 logo, random objects]
Scrap Harm: Scrap gain increased by 10%, but gaining scrap makes crew bleed and go crazy. (automate)
A fun thing might look at how many effects are on a given crew.  It should be easy to get the list of effects on a given crew.  PRetty sure it is as written.
  30% system resist to the room you're in
Galpegar
Noctus
The Thunderskin  --Crew cannot fight and gains 100 health. When in a room with injured allies, bleeds profusely and heals them.  Needs statboost for the cannot fight probably.
The Sun in Rags
A cursed item that autoequips
Item that get stronger the more items you sell.
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
Displacer Mace (spawns one)
    Normal:same ship
    Chaotic: any ship
I need a number for how many ticks are in a second.
Items just generally tick faster (armor)
Overclocker -- +movespeed (dud), faster item rate on equipped guy.

Item: User Manual
    Creates one of several user manuals on create, destroys itself.  These are tools that give the user one extra level of skill, statbuff needed.

Giftbox: lots of things!  No sell value, but might give you stuff when it dies...
An item that stacks with itself when you place it on itself... Render func's going to be hard for that one...
Maybe it gets brighter each level?  A thing that you feed other things to power it up...

Prongler: slows enemy crew in same room
Sun Pile: tool, 2x door break speed
Young Depressor: Crew gains MC immunity.
Maw Sawge: boosts regen rate of friendly crew in room (1.20)

using userdata tables for the things that go on characters.
Inferno Core -- Increases burn speed of fires in the same room.

--]]--45 c cvgbhbhyh bbb
cel.insertItemDefinition({name="Shredder Cuffs", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/SpikedCuffs.png"), description="Looking sharp.  Extra damage in melee.", onTick=ShredderCuffs, sellValue=3})
cel.insertItemDefinition({name="Seal Head", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/SealHead.png"), description="The headbutts it enables are an effective counter to the ridicule you might encounter for wearing such odd headgear.", onTick=SealHead})
cel.insertItemDefinition({name="Chicago Typewriter", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/ChicagoTypewriter.png"), description="Lots of oomph in these keystrokes.  Adds a bar when manning weapons.", onTick=ChicagoTypewriter, onRemove=ChicagoTypewriterRemove})
cel.insertItemDefinition({name="Ballancator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Ballancator.png"), description="As all things should be.  Strives to keep its wearer at exactly half health.", onTick=Ballanceator})
cel.insertItemDefinition({name="Hellion Halberd", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/halberd.png"), description="A vicious weapon that leaves its victems with gaping wounds that bleed profusely.", onTick=HellionHalberd})
cel.insertItemDefinition({name="Peppy Bismol", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/peppy_bismol.png"), description="'With Peppy Bismol, nothing will be able to keep you down!'  Increases active ability charge rate.", onEquip=PeppyBismolEquip, onRemove=PeppyBismolRemove})
cel.insertItemDefinition({name="Medkit", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/medkit.png"), description="Packed full of what whales you.  +20 max health.", onEquip=MedkitEquip, onRemove=MedkitRemove})
cel.insertItemDefinition({name="Organic Impulse Grafts", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/graft_armor.png"), description="Quickly rights abnormal status conditions. +5 max health, bleed immunity, 50% stun resist.", onTick=GraftArmor, onEquip=GraftArmorEquip, onRemove=GraftArmorRemove})
cel.insertItemDefinition({name="Testing Status Tool", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Untitled.png"), description="ALL OF THEM!!!  A complicated-looking device that inflicts its wearer with all manner of ill effects.  Thankfully, someone else wants it more than you do.", onTick=statusTest, onEquip=statusTestEquip, onRemove=statusTestRemove, sellValue=15})
cel.insertItemDefinition({name="Omelas Generator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/leaves_of_good_fortune.png"), description="Power, at any cost.  Equiped crew adds four ship power but slowly stacks corruption.", onTick=OmelasGenerator, onEquip=OmelasGeneratorEquip, onRemove=OmelasGeneratorRemove})
cel.insertItemDefinition({name="Ferrogenic Exsanguinator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/grafted.png"), description="'The machine god requires a sacrifice of blood, and I give it gladly.'  Biomechanical tendrils wrap around this crew, extracting their life force to hasten repairs.", onTick=FerrogenicExsanguinator})
cel.insertItemDefinition({name="Egg", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/egg.png"), description="Gains 3 sell value at the end of the round.", onTick=Egg, onLoad=loadEgg, onPersist=persistEgg, sellValue=0})
cel.insertItemDefinition({name="Myocardial Overcharger", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/brain_gang.png"), description="Grows in power with each item sold.", onCreate=MyocardialOverchargerCreate, onLoad=loadMyocardialOvercharger, onPersist=persistMyocardialOvercharger, onRender=MyocardialOverchargerRender, onEquip=MyocardialOverchargerEquip, onRemove=MyocardialOverchargerRemove})
cel.insertItemDefinition({name="Holy Symbol", itemType=TYPE_WEAPON, renderFunction=HolySymbolRender(), description="Renders its wearer nigh impervious to corruption (Not the DD kind).", onEquip=HolySymbolEquip, onRemove=HolySymbolRemove, sellValue=10})
cel.insertItemDefinition({name="Interfangilator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/detector.png"), description="Attaches to the frequency signatures of matching enemy system rooms and inhibits them, reducing them by a bar. [If you quit when an enemy system is red, this breaks your save.]", onRender=Interfangilator, onRemove=InterfangilatorRemove, onLoad=InterfangilatorLoad, onPersist=InterfangilatorPersist})
cel.insertItemDefinition({name="Custom Interfangilator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/custom_detector.png"), description="Their expertise becomes their sword, and enemy systems fall. An aftermarket model which scales based on the crew's skill level with the current system. [If you quit when an enemy system is red, this breaks your save.]", onRender=CustomInterfangilator, onRemove=InterfangilatorRemove, onLoad=InterfangilatorLoad, onPersist=InterfangilatorPersist})
cel.insertItemDefinition({name="Compactifier", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/decrepit paper.png"), description="Nearly illegible documents stating that this crew 'Doesn't count'.", onEquip=CompactifierEquip, onRemove=CompactifierRemove})
cel.insertItemDefinition({name="Internecion Cube", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/internecion_cube.png"), description=IC_on_TEXT, onEquip=InternecionCubeEquip, onTick=InternecionCube})
cel.insertItemDefinition(PGO_DEFINITION)
cel.insertItemDefinition(THREE_PGO_DEFINITION)
cel.insertItemDefinition({name="Thief's Hand", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/thiefs_hand.png"), description=THIEFS_HAND_DESCRIPTION_DORMANT, onEquip=ThiefsHandEquip, onTick=ThiefsHand})
cel.insertItemDefinition({name=VOID_RING_NAME, itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/ring_of_void.png"), description="More than it seems.  Equipped crew can't fight or be targeted in combat.", onEquip=VoidRingEquip, onRemove=VoidRingRemove, onTick=VoidRing})
cel.insertItemDefinition({name=AWOKEN_THIEFS_HAND_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/awoken_rogues_hand.png"), description=AWOKEN_THIEFS_HAND_DESCRIPTION, onTick=AwokenThiefsHand, sellValue=13, secret=true})
cel.insertItemDefinition(STRANGE_LUMP_DEFINITION)
cel.insertItemDefinition(KNOBBLY_MOUND_DEFINITION)
cel.insertItemDefinition(TOOTHY_PLANK_DEFINITION)
cel.insertItemDefinition(HOOKISH_STAFF_DEFINITION)
cel.insertItemDefinition(YOUNG_DEPRESSEOR_DEFINITION)
cel.insertItemDefinition(SUN_PILE_DEFINITION)
cel.insertItemDefinition(MAW_SAWGE_DEFINITION)
cel.insertItemDefinition(PRONGLER_DEFINITION)
cel.insertItemDefinition(EQUINOID_TOOLS_DEFINITION)
cel.insertItemDefinition({name="Volatile Hypercells", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/hypercells.png"), description="This vial of hyperactive growth substrate shatters on death, regenerating its holder as a random race.", onRender=VolatileHypercells})
cel.insertItemDefinition(GENERIC_DISPLACER_MACE_DEFINITION)
cel.insertItemDefinition(DISPLACER_MACE_DEFINITION)
cel.insertItemDefinition(CHAOTIC_DISPLACER_MACE_DEFINITION)
cel.insertItemDefinition({name="Overcloaker", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/overcloaker.png"), description="The supercharged fabric of this cloak fills the space around you with potential, drawing out the latent capabilities of your gear.  Other equipped items on this crew tick at 1.5x speed.", onEquip=OvercloakerEquip, onRemove=OvercloakerRemove})
--print("numequips after", #mEquipmentGenerationTable)





------------------------------------END ITEM DEFINITIONS----------------------------------------------------------
--todo doesn't work with anything that has multiple possible results.
if cel.addGuaranteedItemEvent then --backcompat with old library versions
    --cel.addGuaranteedItemEvent("DROPPOINT_CRAZYZOLTAN_PAY", cel.ITEM_ANY)
    --cel.addGuaranteedItemEvent("DROPPOINT_CACHE_OPEN", cel.ITEM_ANY)
    cel.addGuaranteedItemEvent("DROPPOINT_BULKY_SMUGGLER_HACK", cel.ITEM_ANY)
    cel.addGuaranteedItemEvent("S1_ZOLTAN_SHIELD_SEND_REPAIR", cel.ITEM_ANY)
    cel.addGuaranteedItemEvent("DROPPOINT_SHIP_TOXIN_FLUSHED", cel.ITEM_ANY)
    cel.addGuaranteedItemEvent("DROPPOINT_ESCAPE_POD_QUEST", cel.ITEM_ANY)
    cel.addGuaranteedItemEvent("DROPPOINT_SUPPLY_DEPOT_SHORTAGE_FUEL", cel.ITEM_ANY)
    cel.addGuaranteedItemEvent("DROPPOINT_SUPPLY_DEPOT_SHORTAGE_MISSILES", cel.ITEM_ANY)
    cel.addGuaranteedItemEvent("DROPPOINT_SUPPLY_DEPOT_SHORTAGE_DRONES", cel.ITEM_ANY)
else
    error("Warning: old crew equipment library version, GEX will not add guaranteed event items.")
end







