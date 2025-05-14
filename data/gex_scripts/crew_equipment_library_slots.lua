mods.crew_equipment_library_slots = {}
local cels = mods.crew_equipment_library_slots

local TYPE_WEAPON = "Weapon"
local TYPE_ARMOR = "Armor"
local TYPE_TOOL = "Tool"
local TYPE_NONE = "None" --greyed out
local TYPE_SPACER = "Spacer" --half width, not a button
local TYPE_ANY = "Any" --wildcard
cels.TYPE_WEAPON = TYPE_WEAPON
cels.TYPE_ARMOR = TYPE_ARMOR
cels.TYPE_TOOL = TYPE_TOOL
cels.TYPE_ANY = TYPE_ANY
cels.TYPE_NONE = TYPE_NONE
cels.TYPE_SPACER = TYPE_SPACER

local SLOTS_ALL = {TYPE_WEAPON, TYPE_ARMOR, TYPE_TOOL}--default.  For this reason, most uniques and all morphs are off the list.
local SLOTS_NONE = {TYPE_NONE, TYPE_NONE, TYPE_NONE}
local SLOTS_NOWEAPON = {TYPE_NONE, TYPE_ARMOR, TYPE_TOOL}
local SLOTS_NOTOOL = {TYPE_WEAPON, TYPE_ARMOR, TYPE_NONE}
local SLOTS_NOARMOR = {TYPE_WEAPON, TYPE_NONE, TYPE_TOOL}
local SLOTS_ONLYWEAPON = {TYPE_WEAPON, TYPE_NONE, TYPE_NONE}
local SLOTS_ANYTWO = {TYPE_SPACER, TYPE_ANY, TYPE_ANY} --todo this is the hardest because it requires additonal logic, mostly for rendering 
local SLOTS_WILDCARD = {TYPE_ANY, TYPE_ANY, TYPE_ANY}
local CREW_STAT_TABLE

cels.SLOTS_ALL = SLOTS_ALL
cels.SLOTS_NONE = SLOTS_NONE
cels.SLOTS_NOWEAPON = SLOTS_NOWEAPON
cels.SLOTS_NOTOOL = SLOTS_NOTOOL
cels.SLOTS_NOARMOR = SLOTS_NOARMOR
cels.SLOTS_ONLYWEAPON = SLOTS_ONLYWEAPON
cels.SLOTS_ANYTWO = SLOTS_ANYTWO

------------------------------------API----------------------------------------------------------
---Add a new crew type, or change the slots of an existing one.
---@param raceName string
---@param slots table of CELS TYPE_ values.  You can use the predefined onces or create your own.
function cels.setRaceSlotDefinition(raceName, slots)
    CREW_STAT_TABLE[race] = slots
end

---If not found, defaults to the standard three.  Mostly for use by CEL internally.  
---@param race string
---@return table
function cels.getCrewSlots(race)
    local slotTypes = CREW_STAT_TABLE[race]
    if slotTypes then
        return slotTypes
    else
        return SLOTS_ALL
    end
end
------------------------------------END API----------------------------------------------------------

CREW_STAT_TABLE = {
    human=SLOTS_ANYTWO,
    human_humanoid=SLOTS_ANYTWO,
    human_engineer=SLOTS_ANYTWO,
    human_medic=SLOTS_ANYTWO,
    human_rebel_medic=SLOTS_ANYTWO,
    human_soldier=SLOTS_ANYTWO,
    human_technician=SLOTS_ALL,
    human_mfk=SLOTS_WILDCARD,
    human_legion=SLOTS_WILDCARD,
    human_legion_pyro=SLOTS_WILDCARD,
    unique_cyra=SLOTS_WILDCARD,
    unique_tully=SLOTS_WILDCARD,
    unique_vance=SLOTS_WILDCARD,
    unique_haynes=SLOTS_ALL,
    unique_jerry=SLOTS_ANYTWO,
    unique_jerry_gun=SLOTS_WILDCARD,
    unique_jerry_pony=SLOTS_WILDCARD,
    unique_jerry_pony_crystal=SLOTS_WILDCARD,
    unique_leah=SLOTS_WILDCARD,
    unique_leah_mfk=SLOTS_WILDCARD,
    unique_ellie=SLOTS_ONLYWEAPON,
    unique_ellie_stephan=SLOTS_ANYTWO,
    unique_ellie_lvl1=SLOTS_ONLYWEAPON,
    unique_ellie_lvl2=SLOTS_ONLYWEAPON,
    unique_ellie_lvl3=SLOTS_ONLYWEAPON,
    unique_ellie_lvl4=SLOTS_ONLYWEAPON,
    unique_ellie_lvl5=SLOTS_ONLYWEAPON,
    unique_ellie_lvl6=SLOTS_ONLYWEAPON,
    human_angel=SLOTS_WILDCARD,
    --Orchid
    orchid=SLOTS_NOWEAPON,
    orchid_caretaker=SLOTS_NOWEAPON,
    orchid_praetor=SLOTS_NOWEAPON,
    orchid_vampweed=SLOTS_NOWEAPON,
    orchid_cultivator=SLOTS_NOWEAPON,
    unique_tyerel=SLOTS_NOWEAPON,
    unique_mayeb=SLOTS_NOWEAPON,
    unique_ivar=SLOTS_ALL,
    --Engi
    engi=SLOTS_NOWEAPON,
    engi_separatist=SLOTS_NOWEAPON,
    engi_separatist_nano=SLOTS_NOWEAPON,
    engi_defender=SLOTS_NOWEAPON,
    unique_turzil=SLOTS_ALL,
    --Zoltan
    zoltan=SLOTS_NOARMOR,
    zoltan_monk=SLOTS_NOWEAPON,
    zoltan_peacekeeper=SLOTS_ALL,
    zoltan_devotee=SLOTS_NOARMOR, --duskbringer
    zoltan_martyr=SLOTS_NOARMOR,
    unique_devorak=SLOTS_ALL,
    unique_anurak=SLOTS_ALL,
    zoltan_osmian=SLOTS_NOARMOR,
    --Rock
    rock=SLOTS_NOTOOL,
    rock_outcast=SLOTS_NOTOOL,
    rock_cultist=SLOTS_NOTOOL,
    rock_commando=SLOTS_ALL,
    rock_crusader=SLOTS_ALL,
    rock_paladin=SLOTS_ALL,
    --rock_elder=CREW_STAT_DEFINITIONS.,
    unique_symbiote=SLOTS_ALL,
    unique_vortigon=SLOTS_ALL,
    unique_tuco=SLOTS_ALL,
    unique_ariadne=SLOTS_ALL,
    --Mantis
    mantis=SLOTS_NOTOOL,
    mantis_suzerain=SLOTS_NOTOOL,
    mantis_free=SLOTS_NOTOOL,
    mantis_free_chaos=SLOTS_NOTOOL,
    mantis_warlord=SLOTS_NOTOOL,
    mantis_bishop=SLOTS_NOTOOL,
    unique_kaz=SLOTS_ALL,
    unique_freddy=SLOTS_ALL,
    unique_freddy_fedora=SLOTS_ALL,
    unique_freddy_jester=SLOTS_ALL,
    unique_freddy_sombrero=SLOTS_ALL,
    unique_freddy_twohats=SLOTS_ALL,
    --Crystal
    crystal=SLOTS_NOTOOL,
    crystal_liberator=SLOTS_ALL,
    crystal_sentinel=SLOTS_ALL,
    unique_ruwen=SLOTS_ALL,
    unique_dianesh=SLOTS_ALL,
    unique_obyn=SLOTS_ALL,
    nexus_obyn_cel=SLOTS_ALL,
    --Slug
    slug=SLOTS_NOARMOR,
    slug_hektar=SLOTS_NOARMOR,
    slug_hektar_box=SLOTS_NOARMOR,
    slug_saboteur=SLOTS_ALL,
    slug_clansman=SLOTS_ALL,
    slug_ranger=SLOTS_ALL,
    slug_knight=SLOTS_ALL,
    unique_billy=SLOTS_ALL,
    unique_billy_box=SLOTS_ALL,
    unique_nights=SLOTS_ALL,
    unique_slocknog=SLOTS_ALL,
    unique_irwin=SLOTS_ALL,
    unique_irwin_demon=SLOTS_ALL,
    unique_sylvan=SLOTS_ALL,
    --todo I don't know enough about these, giving them all sylvan stats for now.
    nexus_sylvan_cel=SLOTS_ALL,
    nexus_sylvan_gman=SLOTS_ALL,
    bucket=SLOTS_ALL,
    sylvanrick=SLOTS_ALL,
    sylvansans=SLOTS_ALL,
    saltpapy=SLOTS_ALL,
    sylvanleah=SLOTS_ALL,
    sylvanrebel=SLOTS_ALL,
    dylan=SLOTS_ALL,
    nexus_pants=SLOTS_ALL,
    prime=SLOTS_ALL,--TODO
    sylvan1d=SLOTS_ALL,
    sylvanclan=SLOTS_ALL,
    beans=SLOTS_ALL,
    --Leech
    leech=SLOTS_NOARMOR,
    leech_ampere=SLOTS_NOARMOR,
    unique_tonysr=SLOTS_ALL,
    unique_tyrdeo=SLOTS_ALL,
    unique_tyrdeo_bird=SLOTS_NONE,
    unique_alkram=SLOTS_ALL,
    --Siren
    siren=SLOTS_NOARMOR,
    siren_harpy=SLOTS_NOARMOR,
    --Shell
    shell=SLOTS_NOWEAPON,
    shell_scientist=SLOTS_NOWEAPON,
    shell_mechanic=SLOTS_NOWEAPON,
    shell_guardian=SLOTS_ALL,
    shell_radiant=SLOTS_ALL,
    unique_alkali=SLOTS_ALL,
    --Lanius
    lanius=SLOTS_NOTOOL,
    lanius_welder=SLOTS_ALL,
    lanius_augmented=SLOTS_NOTOOL,
    unique_anointed=SLOTS_NOTOOL,
    unique_eater=SLOTS_ALL,
    --Ghost
    phantom=SLOTS_NOARMOR,
    phantom_alpha=SLOTS_ALL,
    phantom_goul=SLOTS_NOARMOR,
    phantom_goul_alpha=SLOTS_ALL,
    phantom_mare=SLOTS_NOARMOR,
    phantom_mare_alpha=SLOTS_ALL,
    phantom_wraith=SLOTS_NOARMOR,
    phantom_wraith_alpha=SLOTS_ALL,
    unique_dessius=SLOTS_ALL,
    --Spider
    spider=SLOTS_NOTOOL,
    spider_weaver=SLOTS_NOWEAPON,
    spider_hatch=SLOTS_NONE,
    unique_queen=SLOTS_ALL, --El spidro guigante
    spider_venom=SLOTS_ALL,
    spider_venom_chaosm=SLOTS_ALL,
    tinybug=SLOTS_NONE,
    --Lizard thing
    lizard=SLOTS_NOTOOL,
    unique_guntput=SLOTS_ALL,
    unique_metyunt=SLOTS_NOWEAPON,
    --Pony
    pony=SLOTS_NOTOOL,
    pony_tamed=SLOTS_NOTOOL,
    ponyc=SLOTS_ALL,
    pony_engi=SLOTS_ALL,
    pony_engi_nano=SLOTS_ALL,
    pony_engi_chaos=SLOTS_ALL,
    pony_engi_nano_chaos=SLOTS_ALL,
    --Cognitive
    cognitive=SLOTS_ALL,
    cognitive_automated=SLOTS_ALL,
    cognitive_advanced=SLOTS_ALL,
    cognitive_advanced_automated=SLOTS_ALL,
    --todo FR cogs
    --Obelisk
    obelisk=SLOTS_ALL,
    obelisk_royal=SLOTS_ALL,
    unique_wither=SLOTS_ALL,
    -- :)
    gnome=SLOTS_NONE,
    --Judges
    unique_judge_thest=SLOTS_ALL, --If I ever come back to this, four slots or something.
    unique_judge_corby=SLOTS_ALL,
    unique_judge_wakeson=SLOTS_ALL,
    --EE?
    --[[
    eldritch_spawn
    --Forgotten Races
    snowman=CREW_STAT_DEFINITIONS.SNOWMAN,
    snowman_chaos=CREW_STAT_DEFINITIONS.SNOWMAN_CHAOS,
    fr_lavaman=CREW_STAT_DEFINITIONS.LAVAMAN,
    fr_commonwealth
    fr_spherax
    fr_unique_billvan=CREW_STAT_DEFINITIONS.SYLVAN,
    fr_unique_billvan_box=CREW_STAT_DEFINITIONS.SYLVAN,
    fr_unique_sammy=CREW_STAT_DEFINITIONS.SAMMY,
    fr_unique_sammy_buff=CREW_STAT_DEFINITIONS.SAMMY,
    
    fr_gozer
    fr_CE_avatar
    fr_errorman
    fr_sylvan_cel=CREW_STAT_DEFINITIONS.SYLVAN
    fr_obyn_cel=CREW_STAT_DEFINITIONS.OBYN
    fr_withered
    fr_enhanced
    fr_proto_cognitive
    fr_proto_cognitive_automated
    fr_experimental_cognitive
    fr_experimental_cognitive_automated
    fr_unique_mantis_queen --laarkip
    fr_salt
    fr_zoltan_osmian_hologram_weak
    fr_wither_hologram
    fr_specter
    fr_ghostly_drone
    fr_snowman_smart--]]
    --Diamonds
    fr_golden_diamond=SLOTS_NOTOOL,
    fr_copper_diamond=SLOTS_NOWEAPON,
    fr_adamantine_diamond=SLOTS_NOWEAPON,
    fr_golden_operator=SLOTS_NOTOOL,
    fr_copper_operator=SLOTS_NOWEAPON,
    fr_adamantine_operator=SLOTS_NOWEAPON,
    --fr_techno_operator={INTELLECT=4, logic=2, encylopedia=2, PSYCHE=4, PHYSIQUE=4, endurance=1, pain_threshold=1, MOTORICS=4, composure=-4}, --morph of all three
    --Elemental Lanius
    --[[
    ips_holo
    ips_unique_sona

    ips_drone_manner
    ips_technomanner
    cooking
    --]]
    
    --Darkest Desire
    --Deep Ones
    deepone=SLOTS_NOTOOL,
    deeponecultist=SLOTS_NOWEAPON,
    --unique_thescarred=CREW_STAT_DEFINITIONS.THE_SCARRED,
    --unique_thescarredascended=CREW_STAT_DEFINITIONS.THE_SCARRED_ASCENDED,
    enlightened_horror=SLOTS_NONE,----like hektar, not doing all these right now.
    enlightened_horror_a=SLOTS_NONE,
    enlightened_horror_b=SLOTS_NONE,
    enlightened_horror_c=SLOTS_NONE,
    enlightened_horror_ad=SLOTS_NONE,
    enlightened_horror_ae=SLOTS_NONE,
    enlightened_horror_af=SLOTS_NONE,
    enlightened_horror_ag=SLOTS_NONE,
    enlightened_horror_bd=SLOTS_NONE,
    enlightened_horror_be=SLOTS_NONE,
    enlightened_horror_bf=SLOTS_NONE,
    enlightened_horror_bg=SLOTS_NONE,
    enlightened_horror_cd=SLOTS_NONE,
    enlightened_horror_ce=SLOTS_NONE,
    enlightened_horror_cf=SLOTS_NONE,
    enlightened_horror_cg=SLOTS_NONE,
    enlightened_horror_adj=SLOTS_NONE,
    enlightened_horror_aej=SLOTS_NONE,
    enlightened_horror_afj=SLOTS_NONE,
    enlightened_horror_agj=SLOTS_NONE,
    enlightened_horror_bdj=SLOTS_NONE,
    enlightened_horror_bej=SLOTS_NONE,
    enlightened_horror_bfj=SLOTS_NONE,
    enlightened_horror_bgj=SLOTS_NONE,
    enlightened_horror_cdj=SLOTS_NONE,
    enlightened_horror_cej=SLOTS_NONE,
    enlightened_horror_cfj=SLOTS_NONE,
    enlightened_horror_cgj=SLOTS_NONE,
    ddnightmare_rift=SLOTS_NONE,
    ddnightmare_rift_a=SLOTS_NONE,
    ddnightmare_rift_b=SLOTS_NONE,
    ddnightmare_rift_c=SLOTS_NONE,
    ddnightmare_rift_ad=SLOTS_NONE,
    ddnightmare_rift_ae=SLOTS_NONE,
    ddnightmare_rift_af=SLOTS_NONE,
    ddnightmare_rift_ag=SLOTS_NONE,
    ddnightmare_rift_bd=SLOTS_NONE,
    ddnightmare_rift_be=SLOTS_NONE,
    ddnightmare_rift_bf=SLOTS_NONE,
    ddnightmare_rift_bg=SLOTS_NONE,
    ddnightmare_rift_cd=SLOTS_NONE,
    ddnightmare_rift_ce=SLOTS_NONE,
    ddnightmare_rift_cf=SLOTS_NONE,
    ddnightmare_rift_cg=SLOTS_NONE,
    ddnightmare_rift_adj=SLOTS_NONE,
    ddnightmare_rift_aej=SLOTS_NONE,
    ddnightmare_rift_afj=SLOTS_NONE,
    ddnightmare_rift_agj=SLOTS_NONE,
    ddnightmare_rift_bdj=SLOTS_NONE,
    ddnightmare_rift_bej=SLOTS_NONE,
    ddnightmare_rift_bfj=SLOTS_NONE,
    ddnightmare_rift_bgj=SLOTS_NONE,
    ddnightmare_rift_cdj=SLOTS_NONE,
    ddnightmare_rift_cej=SLOTS_NONE,
    ddnightmare_rift_cfj=SLOTS_NONE,
    ddnightmare_rift_cgj=SLOTS_NONE,
    spacetear=SLOTS_NONE,
    darkgodtendrils=SLOTS_NONE,
    nightmarish_crawler=SLOTS_NONE,--TODO MAYBE ILL ADD THESE
    nightmarish_terror=SLOTS_NONE,
    nightmarish_priest=SLOTS_NONE,
    nightmarish_greaterpriest=SLOTS_NONE,
    nightmarish_stalker=SLOTS_NONE,
    nightmarish_engi=SLOTS_NONE,
    nightmarish_greatercrawler=SLOTS_NONE,
    nightmarish_mass=SLOTS_NONE,
    nightmarish_greatermass=SLOTS_NONE,
    nightmarish_martyr=SLOTS_NONE,
    nightmarish_greatermartyr=SLOTS_NONE,
    
    --Morph
    --[[
    happyholidays
    happyholidays_healing
    --Engi
    
    --Hektar Expansion
    slug_hektar_elite=SLOTS_NOWEAPON,--eh. they're not _that elite.
    
    --ARI_MECH  I don't know what the fuck that thing is
    --[[
    mutant
    clone_soldier
    --]]
    --TNE
    --AEA
    aea_acid_soldier=SLOTS_NOARMOR,
    --[[
    aea_old_1
    aea_old_unique_1
    aea_old_unique_2
    aea_old_unique_3
    aea_old_unique_4
    aea_old_unique_5
    aea_bird_avali
    aea_bird_illuminant
    aea_bird_unique
    --]]
    fff_f22=SLOTS_ONLYWEAPON,
    fff_buffer=SLOTS_NOWEAPON,
    fff_omen=SLOTS_ALL,
    --[[ ALL
    easter_brick=CREW_STAT_DEFINITIONS.ROCKMAN,
    easter_coomer=CREW_STAT_DEFINITIONS.HUMAN_SOLDIER,
    easter_bubby=CREW_STAT_DEFINITIONS.HUMAN_ENGINEER,
    easter_tommy=CREW_STAT_DEFINITIONS.HUMAN_MEDIC,
    easter_sunkist=CREW_STAT_DEFINITIONS.PONY,
    easter_angel=CREW_STAT_DEFINITIONS.GAS_QUEEN
    --]]
}