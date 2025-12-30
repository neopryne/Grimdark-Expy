local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local get_room_at_location = mods.multiverse.get_room_at_location
local Brightness = mods.brightness
local lwl = mods.lightweight_lua
local lwsb = mods.lightweight_statboosts
local lwst = mods.lightweight_stable_time

if not mods.nightfall then
    mods.nightfall = {}
end
mods.nightfall.program = {}
local np = mods.nightfall.program

---TODO renaming this to program
local TABLE_NAME_HACK = "mods.nightfall.hack_2.0"
local VERY_SMALL_NUMBER = .000001 --todo move this to crew definition.
local TURBO_SPEED = 999999

local function nearestCardinalAngle(angle)
    local index = lwl.round(angle / (math.pi / 2)) % 4
    return index * (math.pi / 2)
end

local function getTeleportLocation(crewmem)
    local crewPos = crewmem:GetPosition()
    local shipManager = Hyperspace.ships(crewmem.currentShipId)
    local immediateHeading = lwl.getAngle(crewPos, crewmem:GetNextGoal())
    local snappedAngle = nearestCardinalAngle(immediateHeading)
    local currentRoom = get_room_at_location(shipManager, crewPos, true)
    local currentSlot = lwl.slotIdAtPoint(crewPos, shipManager)
    local currentSlotCenter = lwl.slotCenter(crewmem.currentShipId, currentRoom, currentSlot)

    --Snap to nearest 90* angle
    --Return the center of the tile #TILE_SIZE above you
    return lwl.getPoint(currentSlotCenter, snappedAngle, lwl.TILE_SIZE())
end

local function getMissingHealth(crewmem)
    return crewmem.health.second - crewmem.health.first
end


--[[
hack: {type=parent, child=hackChild, image=hack2.0, maxSize=4, }
hackChild {type=child, image=hackchildimage, }
program definition: {self, child}
]]

---comment
---@param crewmem any
---@param programDefinition table {name=string}
---@return table
np.createProgram = function(crewmem, programDefinition)
    local program = {}

    program.realCrew = crewmem
    program.immediateChild = nil
    program.topLevelParent = nil
    program.moveTimer = 0
    program.moveEvery = 170
    program.teleportLocation = nil
    program.speedBoostId = nil

    ---Actually, a program only needs to know the next child in line, doesn't it?
    ---Well, I guess it needs to know the total size, to prevent spawning new forks forever
    ---But that's fine, each node just needs to know which one it is in the line, and the total size this program can be.
    ---This does mean that 
    local function doctor()
        ---Transfer all damage to the last node
        ---When children die, they have a listener registered that removes them from their parent.
        ---Children are noclone, noslot crew. They have no gexpy slots.  They are immune to crew loss events.
        local eldestChild = program.children[#program.children]
        local totalDamage = getMissingHealth(program.realCrew)
        for _,child in ipairs(program.children) do
            totalDamage = totalDamage + getMissingHealth(child.realCrew)
        end
        eldestChild.realCrew.health.first = eldestChild.realCrew.health.second - totalDamage
        --todo make sure this child always exists when we expect it to.
    end

    local function programMovement()
        if program.moveTimer == 0 then
            --teleport if the unit (still) has a destination.
            program.moveTimer = program.moveTimer + 1 --todo plus move speed modifier.
            lwsb.removeStatBoostAllowNil(program.speedBoostId)
            if lwl.isMoving(program.realCrew) and program.teleportLocation then
                --todo teleport all children also
                program.realCrew:SetPosition(program.teleportLocation)
                program.teleportLocation = nil
            end
            --Set the speed to near zero.
        elseif program.moveTimer == program.moveEvery then
            --Set move speed high, mark target location
            program.moveTimer = 0
            program.speedBoostId = lwsb.addStatBoost(Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, TURBO_SPEED, lwl.generateCrewFilterFunction(program.realCrew))
            program.teleportLocation = getTeleportLocation(program.realCrew)
            --TODO boost and set tele locations for children.
        else
            program.moveTimer = program.moveTimer + 1
        end
    end

    --only parents should call their doctor/move methods then chain through children.
    if (program.type == "parent") then
        program.onTick = function() --no reason this is a field, changing it does nothing.
            programMovement()
            doctor()
        end
        lwst.registerOnTick("nightfall_"..programDefinition.name..program.realCrew.extend.selfId, program.onTick, false)
    end

    return program
end














