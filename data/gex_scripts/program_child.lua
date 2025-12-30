local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local get_room_at_location = mods.multiverse.get_room_at_location
local Brightness = mods.brightness
local lwl = mods.lightweight_lua

if not mods.nightfall then
    mods.nightfall = {}
end
mods.nightfall.program_child = {}
local npc = mods.nightfall.program_child


--#region ChildController
local function tickProgram(parent)
    --Ugh, so the parent node actually controlls the list of all the children and their actions?
    ---Once I get that done I should break the child behavior out into its own class for better infosep.
    for _,child in ipairs(parent.children) do
        child.onTick()
    end
    --The parent is responsible for ensuring that only the oldest child 
end


local function registerChild(parent, child)
    
    lwl.safe_script.on_render_event() --find the right layer for crew


end









--#endregion



--The jump move behavior is going to be a hard area, might need a delay and super speed, or teleporting, or...
---Because the health bars are going to move around if I do it like that.
---So what I need is the right very large number to make someone move basically one square.
---But that breaks down when moving diagonally, so I think I just make them move really slow, and teleport them every while in their facing direction, snapping to 45* angles.
---90* actually.  This always works, just use the major facing direction from the crew.
---







npc.createNpc = function (program)
    local image = program.childImage --todo actually programs just define a child image.
    local parent = program
    registerChild(program, self)

    local image = Brightness.create_particle(image, whatever)
    ---image.persists = true todo

end






--These crew are unselectable but controllable, so that they don't have a mind of their own but cannot be controlled, and I can do my own AI on them.

--[[
This is a class, and the hack passes itself to make versions of this.


]]
















