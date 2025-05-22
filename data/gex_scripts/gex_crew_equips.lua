if (not mods) then mods = {} end
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwce = mods.lightweight_crew_effects
local cel = mods.crew_equipment_library
local Brightness = mods.brightness

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

------------------------------------ITEM DEFINITIONS----------------------------------------------------------
--Only the player can use items.
-------------------SHREDDER CUFFS------------------
local function ShredderCuffs(item, crewmem)
    if crewmem.bFighting and crewmem.bSharedSpot then
        local ownshipManager = Hyperspace.ships(0)
        local foeShipManager = Hyperspace.ships(1)
        foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y)
        for _,foe in ipairs(foes_at_point) do
            foe:DirectModifyHealth(-.05)
        end
    end
end
-------------------SEAL HEAD------------------
local function SealHead(item, crewmem)
    if item.stunCounter == nil then
        item.stunCounter = 0
    end
    if crewmem.bFighting and crewmem.bSharedSpot then
        item.stunCounter = item.stunCounter + .005
        if (item.stunCounter > 1) then
            item.stunCounter = 0
            local ownshipManager = Hyperspace.ships(0)
            local foeShipManager = Hyperspace.ships(1)
            foes_at_point = lwl.get_ship_crew_point(ownshipManager, foeShipManager, crewmem.x, crewmem.y)
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
    end
end
-------------------BALLANCEATOR------------------
local function Ballanceator(item, crewmem)
    local dpt = .085
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
            lwce.applyBleed(foe, 21)--per tick  todo sometimes doesn't work.  also statuses sometimes don't teleport right.  Applying to enemy crew seems to not work now.
        end
    end
end
-------------------PEPPY BISMOL------------------
local function PeppyBismol(item, crewmem)
    --requires stat boost HS
end
-------------------Medkit------------------
local function MedkitEquip(item, crewmem)
    crewmem.health.second = crewmem.health.second + 15
end
local function MedkitRemove(item, crewmem)
    crewmem.health.second = crewmem.health.second - 15
end
-------------------Graft Armor------------------
local function GraftArmorEquip(item, crewmem)
    crewmem.health.second = crewmem.health.second + 5
    lwce.addResist(crewmem, lwce.KEY_BLEED, 1)
end
local function GraftArmor(item, crewmem)
    --requires statboost HS
end
local function GraftArmorRemove(item, crewmem)
    crewmem.health.second = crewmem.health.second - 5
    lwce.addResist(crewmem, lwce.KEY_BLEED, -1)
end
-------------------It's Terrible!------------------
local function statusTestEquip(item, crewmem)
    lwce.applyBleed(crewmem, 3)
    lwce.applyConfusion(crewmem, 3)
    --print("Applying corruption!")
    lwce.applyCorruption(crewmem, .2)
end
local function statusTest(item, crewmem)
    lwce.applyBleed(crewmem, 1)
    lwce.applyConfusion(crewmem, 1)
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
    lwce.applyCorruption(crewmem, .006)
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
        system:PartialRepair(12.5, false)
        lwce.applyBleed(crewmem, 3.2)
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

local function Egg(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        item.sellValue = item.sellValue + 3
        cel.persistEquipment()
    end
    item.jumping = Hyperspace.ships(0).bJumping
end
-------------------Myocardial Overcharger------------------
local function MyocardialOvercharger(item, crewmem) --todo this kind of sucks because these custom values don't persist, leading to _issues_.
    item.sellValue = 6 + mItemsSold
    if not (item.sellValue == item.lastSellValue) then
        crewmem.health.second = crewmem.extend:GetDefinition().maxHealth + (mItemsSold * 5)
    end
    item.lastSellValue = item.sellValue
end
local function MyocardialOverchargerEquip(item, crewmem)
    item.storedHealth = crewmem.health.second
    crewmem.health.second = crewmem.extend:GetDefinition().maxHealth + (mItemsSold * 5)
end
local function MyocardialOverchargerRemove(item, crewmem)
    if item.storedHealth and item.storedHealth > 0 then
        crewmem.health.second = item.storedHealth
    else --reset crew health
        crewmem.health.second = crewmem.extend:GetDefinition().maxHealth
    end
end
-------------------Holy Symbol------------------
local function HolySymbolRender()
    local holySymbolIcons = {"holy_symbol_2.png", "holy_symbol_3.png"}
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
    print("loaded", item.name, item.storedValue, item.previousDamage)
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
            print("if applying", value, "system is", system.name)
            local beforePower = system:GetPowerCap()
            print("before power", beforePower)
            item.previousDamage = system.healthState.second - system.healthState.first
            system:UpgradeSystem(-value)
            item.storedValue = beforePower - system:GetPowerCap()
            local targetPosition = targetShipManager:GetRoomCenter(system:GetRoomId())
            item.roomEffect = Brightness.create_particle("particles/Interfangilator", 1, 60, targetPosition, 0, targetShipManager.iShipId, "SHIP_MANAGER")
            print("Stored value ", item.storedValue, "system now has", system.healthState.second, "bars")
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
    print("Removing effect", item.name, item.storedValue)
    local targetShipManager = Hyperspace.ships(1 - crewmem.iShipId)
    local sourceSystem = item.system
    sourceSystem = lwl.setIfNil(sourceSystem, crewmem.currentSystem)--If we just loaded, item.system will be nil but the crew knows where it is.
    if sourceSystem and targetShipManager and item.storedValue then
        local targetSystem = targetShipManager:GetSystem(sourceSystem:GetId())
        if targetSystem then
            print("if removing ", targetSystem.name, item.storedValue)
            targetSystem:UpgradeSystem(item.storedValue)
            print("if upgraded system by ", item.storedValue)
            if targetSystem:CompletelyDestroyed() then
                if item.previousDamage then
                    targetSystem.healthState.first = targetSystem.healthState.second - item.previousDamage
                end
            end
        end
        removeRoomEffect(item)
        item.previousDamage = 0
        item.storedValue = 0
        cel.persistEquipment()
    end
end

local function Interfangilator(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        item.ready = true
        item.systemId = nil
    end
    item.jumping = Hyperspace.ships(0).bJumping
    
    if (not Hyperspace.ships.enemy) or Hyperspace.ships.enemy.bDestroyed then --todo clean up this logic
        removeRoomEffect(item)
    end

    --print("if checking", item.ready, item.system ~= crewmem.currentSystem)
    if item.ready or ((item.system ~= crewmem.currentSystem))then
        --print("IFID is now ", crewmem.iManningId)
        InterfangilatorRemoveEffect(item, crewmem)
        InterfangilatorApplyEffect(item, crewmem, 1)
        item.ready = false
    end
    item.system = crewmem.currentSystem
    --[[if crewmem.currentSystem then
        local healthState = crewmem.currentSystem.healthState
        print("System health state is ", healthState.first, healthState.second)
    end]]
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
    if item.jumping and not Hyperspace.ships(0).bJumping then
        item.ready = true
    end
    item.jumping = Hyperspace.ships(0).bJumping
    
    if item.ready or ((item.system ~= crewmem.currentSystem)) then
        item.storedValue = lwl.setIfNil(item.storedValue, CustomInterfangilatorLevel(crewmem))
        InterfangilatorRemoveEffect(item, crewmem)
        InterfangilatorApplyEffect(item, crewmem, CustomInterfangilatorLevel(crewmem))
        item.ready = false
    end
    item.system = crewmem.currentSystem
end
-------------------Compactifier------------------
local function CompactifierEquip(item, crewmem) --needs stat boost 1.20
    --item.wasNoslot = 
    --local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    --powerManager.currentPower.second = powerManager.currentPower.second + 4
end

local function CompactifierRemove(item, crewmem)
    if not item.wasNoslot then
        --crewmem
    end
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
    
    item.value = item.value + (.24 / murderMultiplier)
    if item.value > 100 then
        item.value = 0
        if crewmem.health.first < crewmem.health.second then
            crewmem.fStunTime = crewmem.fStunTime + 2.5 + murderMultiplier
            crewmem:DirectModifyHealth(28 * murderMultiplier)
        end
    end

    if crewmem.bFighting then
        lwl.damageEnemyCrewInSameRoom(crewmem, .07 * murderMultiplier, 0) --lwl might have issues if crew tag along after a jump todo fix?
        --todo damage everyone, increase heal.
    end
end
-------------------P.G.O------------------
local PGO_NAME = "Perfectly Generic Object"
local THREE_PGO_NAME = "Perfectly Generic Object " --names need to be unique for the name to id table to work
local PGO_DESCRIPTION = "There's not much to say about this little green cube."
local PGO_SPRITE = "items/pgo.png"

local function PerfectlyGenericObjectCreate(item)
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
    gex_give_item(cel.mNameToItemIndexTable[PGO_NAME])
end

local PGO_DEFINITION = {name=PGO_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(PGO_SPRITE), description=PGO_DESCRIPTION, secret=true}
local THREE_PGO_DEFINITION = {name=THREE_PGO_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction(PGO_SPRITE),
    description=PGO_DESCRIPTION, onCreate=PerfectlyGenericObjectCreate}
-- a small chance each jump to spawn another?  No, that will be a different thing.  Then more things that care about the number of things you have.
-------------------Awoken Thief's Hand------------------
local AWOKEN_THIEFS_HAND_DESCRIPTION = "Said to once belong to the greatest thief in the multiverse, this disembodied hand has the ability to steal from space itself!  Empowered by the ring', it draws even the most obscure whatsits into existence."
local AWOKEN_THIEFS_HAND_NAME = "Awoken Rogue's Hand"

local function AwokenThiefsHand(item, crewmem)
    if item.jumping and not Hyperspace.ships(0).bJumping then
        if (math.random() > .2) then
            gex_give_random_item()
        end
    end
    item.jumping = Hyperspace.ships(0).bJumping
    --todo maybe add the base void ring effect.
end
-------------------Thief's Hand------------------
local VOID_RING_NAME = "Ring of Void (DUD)"
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
end

local function VoidRing(item, crewmem)
    --todo Makes the wearer untargetable in combat, but unable to fight. (1.20)
end
--[[
todo persist status effects on crew
Torpor Projector
Noted, so teleporting really messes with this.  Furthermore why are the effects dipping to 1 while the equipment stays at 2?  
Determination -- Getting hit charges your abilities.
Inflatable muscles -- while about 1/3 health, extra damage
Medbot Injector -- Health recharge passive
I guess I need status definitions so people know what they do.  Bleed is easy, the others less so.

Interface Scrambler -- Removes manning bonus from all enemy systems and prevents them from being manned.
Purple Thang -- censored, inflicts confusion.
    Or like, corruption% chance you don't revive.  5 corruption is already kind of a lot of damage.
Holy Symbol: [hand grenade, (), hl2 logo, random objects]
Scrap Harm: Scrap gain increased by 10%, but gaining scrap makes crew bleed and go crazy. (automate)
A fun thing might look at how many effects are on a given crew.  It should be easy to get the list of effects on a given crew.  PRetty sure it is as written.
  30% system resist to the room you're in
Galpegar
Noctus
The Thunderskin  --Crew cannot fight and gains 100 (double?) health. When in a room with injured allies, bleeds profusely and heals them.  Needs statboost for the cannot fight probably.
Sthenic Venom
A cursed item that autoequips
Item that get stronger the more items you sell.
--todo item onLoad onPersist methods for things that need to save stuff
Blood is Mine, something else I forgot for art assets
FTF Discette
Right Eye of Argupel
A collection of the latest tracks from backwater bombshell Futanari Titwhore Fiasco
--]]--45 c cvgbhbhyh bbb
cel.insertItemDefinition({name="Shredder Cuffs", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/SpikedCuffs.png"), description="Looking sharp.  Extra damage in melee.", onTick=ShredderCuffs, sellValue=3})
cel.insertItemDefinition({name="Seal Head", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/SealHead.png"), description="The headbutts it enables are an effective counter to the ridicule you might encounter for wearing such odd headgear.", onTick=SealHead})
cel.insertItemDefinition({name="Chicago Typewriter", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/ChicagoTypewriter.png"), description="Lots of oomph in these keystrokes.  Adds a bar when manning weapons.", onTick=ChicagoTypewriter, onRemove=ChicagoTypewriterRemove})
cel.insertItemDefinition({name="Ballancator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Ballancator.png"), description="As all things should be.  Strives to keep its wearer at exactly half health.", onTick=Ballanceator})
cel.insertItemDefinition({name="Hellion Halberd", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/halberd.png"), description="A vicious weapon that leaves its victems with gaping wounds that bleed profusely.", onTick=HellionHalberd})
cel.insertItemDefinition({name="Peppy Bismol (DUD)", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/peppy_bismol.png"), description="'With Peppy Bismol, nothing will be able to keep you down!'  Increases active ability charge rate.", onTick=PeppyBismol})
cel.insertItemDefinition({name="Medkit (DUD)", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/medkit.png"), description="Packed full of what whales you.  +15 max health.", onEquip=MedkitEquip, onRemove=MedkitRemove})
cel.insertItemDefinition({name="Orgainc Impulse Grafts (DUD)", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/graft_armor.png"), description="Quickly rights abnormal status conditions. +5 max health, bleed immunity, stun resist.", onTick=GraftArmor, onEquip=GraftArmorEquip, onRemove=GraftArmorRemove})
cel.insertItemDefinition({name="Testing Status Tool", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/Untitled.png"), description="ALL OF THEM!!!  A complicated-looking device that inflicts its wearer with all manner of ill effects.  Thankfully, someone else wants it more than you do.", onTick=statusTest, onEquip=statusTestEquip, onRemove=statusTestRemove, sellValue=15})
cel.insertItemDefinition({name="Omelas Generator", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/leaves_of_good_fortune.png"), description="Power, at any cost.  Equiped crew adds four ship power but slowly stacks corruption.", onTick=OmelasGenerator, onEquip=OmelasGeneratorEquip, onRemove=OmelasGeneratorRemove})
cel.insertItemDefinition({name="Ferrogenic Exsanguinator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/grafted.png"), description="'The machine god requires a sacrifice of blood, and I give it gladly.'  Biomechanical tendrils wrap around this crew, extracting their life force to hasten repairs.", onTick=FerrogenicExsanguinator})
cel.insertItemDefinition({name="Egg", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/egg.png"), description="Gains 3 sell value each jump.", onTick=Egg, onLoad=loadEgg, onPersist=persistEgg, sellValue=0})
cel.insertItemDefinition({name="Myocardial Overcharger (DUD)", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/brain_gang.png"), description="Grows in power with each item sold.", onTick=MyocardialOvercharger, onEquip=MyocardialOverchargerEquip, onRemove=MyocardialOverchargerRemove})
cel.insertItemDefinition({name="Holy Symbol", itemType=TYPE_WEAPON, renderFunction=HolySymbolRender(), description="Renders its wearer nigh impervious to corruption (Not the DD kind).", onEquip=HolySymbolEquip, onRemove=HolySymbolRemove, sellValue=10})
cel.insertItemDefinition({name="Interfangilator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/detector.png"), description="Attaches to the frequency signatures of matching enemy system rooms and inhibits them, reducing them by a bar.", onTick=Interfangilator, onRemove=InterfangilatorRemove, onLoad=InterfangilatorLoad, onPersist=InterfangilatorPersist})
cel.insertItemDefinition({name="Custom Interfangilator", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/custom_detector.png"), description="Their expertise becomes their sword, and enemy systems fall. An aftermarket model which scales based on the crew's skill level with the current system.", onTick=CustomInterfangilator, onRemove=InterfangilatorRemove, onLoad=InterfangilatorLoad, onPersist=InterfangilatorPersist})
cel.insertItemDefinition({name="Compactifier (DUD)", itemType=TYPE_ARMOR, renderFunction=lwui.spriteRenderFunction("items/decrepit paper.png"), description="Nearly illegible documents stating that this crew 'Doesn't count'.", onEquip=CompactifierEquip, onRemove=CompactifierRemove})
cel.insertItemDefinition({name="Internecion Cube", itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/internecion_cube.png"), description=IC_on_TEXT, onEquip=InternecionCubeEquip, onTick=InternecionCube})
cel.insertItemDefinition(PGO_DEFINITION)
cel.insertItemDefinition(THREE_PGO_DEFINITION)
cel.insertItemDefinition({name="Thief's Hand", itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/thiefs_hand.png"), description=THIEFS_HAND_DESCRIPTION_DORMANT, onEquip=ThiefsHandEquip, onTick=ThiefsHand})
cel.insertItemDefinition({name=VOID_RING_NAME, itemType=TYPE_WEAPON, renderFunction=lwui.spriteRenderFunction("items/ring_of_void.png"), description="More than it seems.  Equipped crew can't fight or be targeted in combat.", onEquip=VoidRingEquip, onTick=VoidRing})
cel.insertItemDefinition({name=AWOKEN_THIEFS_HAND_NAME, itemType=TYPE_TOOL, renderFunction=lwui.spriteRenderFunction("items/awoken_rogues_hand.png"), description=AWOKEN_THIEFS_HAND_DESCRIPTION, onTick=AwokenThiefsHand, sellValue=13, secret=true})
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







