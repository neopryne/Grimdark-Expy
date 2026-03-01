--[[
This is the start of an ambitious project, Which aims to create a player controlled drone.
Alt to fire, ctrl for bullettime, which is only active when the drone is powered.
Bullettime is only checked for if the drone is equipped.

The drone creates drone bullets when you fire out of it.  It wraps around the screen on the player side.
It's really stupid, and not something anyone would ever want to use, so I should only do this if I really care about it.
Which I don't think I do.


How do I embed conditionals in language?  Like this if that, otherwise this other thing.



I want to show a database of things, and which tools make things significantly easier.

At this point, it's a lot about database 
{name=Tahini, hassle={{requirements={}, level=Medium}, {requirements={FoodProcessor}, level=Low}}}



All menu options put you back sensibly.
Sensors
    AIM (not installed)
        Install AIM
        Free install
    





Projectile Tracking:
7scrap, 1 drone part/missile/fuel
Each level lets you track an additional projectile, and see where it will impact.
You get one level for free when you install it.






]]

--Thing that lets you install the AIM submodule for free
--Not sure what that's going to be yet.  Maybe having an ECM suite will do it.  Otherwise it's like 30scrap and three drone parts.
--Unlocked if this is greater than zero
local KEY_PLAYERVAR_AIM_INSTALLED = "AIM_INSTALLED"
--How many projectile projections can be tracked at once.
local KEY_PLAYERVAR_AIM_PROJECTILE_TRACKING = "AIM_PROJECTILE_TRACKING"
--How good it is at predicting where enemy crew are headed.  Higher levels give more accurate predictions. 5 gives perfect info.
local KEY_PLAYERVAR_AIM_INTRUDER_MICRO = "AIM_INTRUDER_MICRO"
--

local sIntruderMicroMaxLevel = 5


local function trackProjectile(projectile)
    
end

local function projectileTracking()
    local trackingLevel = lwl.setIfNil(Hyperspace.playerVariables[KEY_PLAYERVAR_AIM_PROJECTILE_TRACKING], 0)
    --Return early if you don't find any more projectiles.
    ---For all projectiles
    ---if any are on your screen and are enemy
    ---If trackingLevel is more than tracked projectiles, track that one, else abort.
end

local function intruderMicro()
    
end


--Not stable time.
script.on_internal_event(Defines.InternalEvents_ON_TICK, function()
    projectileTracking()
    intruderMicro()
end)




