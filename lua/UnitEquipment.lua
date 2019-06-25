#****************************************************************************
#**
#**  File     :  /mods/ExperimentalsExpanded/lua/UnitEquipment.lua
#**  Author(s):  PegasusScourge
#**
#**  Summary  :  Adds custom UnitEquipment for units in the game
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

local Entity = import('/lua/sim/Entity.lua').Entity
local Unit = import('/lua/sim/Unit.lua').Unit

-- The basic equipment class, attaches to an object and stays there
BasicEquipment = Class(Entity)
{
	OnCreate = function(self, spec)
        Entity.OnCreate(self, spec)
        self.Owner = spec.Owner
        self.AttachBone = spec.AttachBone
        self:AttachTo(spec.Owner, spec.AttachBone)
		
		-- explain what we have
		LOG('Basic equipment attached, here are the values and information available on the Entity we were attached to')
		LOG('Attached to ' .. string.format("%s", tostring(spec.AttachBone)))
		LOG('Members:')
		for key,value in pairs(Entity) do
			LOG("found member " .. key .. ' with value ' .. string.format("%s", tostring(value)));
		end
    end,

    OnDestroy = function(self)
		Entity.OnDestroy(self)
    end,
}

-- MicroTeleporter equipment
MicroTeleporter = Class(BasicEquipment)
{
	OnCreate = function(self, spec)
		BasicEquipment.OnCreate(self,spec)
		self.TeleportRange = spec.TeleportRange or 100
		
		-- Give our parent unit the teleport capability
		self.Owner:AddCommandCap('RULEUCC_Teleport')
	end,
	
	InterceptTeleport = function(self, teleporter, location, orientation)
		-- get the location of the unit teleporting
		local teleporterLocation = teleporter:GetPosition()
		location[2] = teleporterLocation[2] -- put ourselves on a level playing field for all intents and purposes. For some reason the 2D distance calc sometimes takes this into effect???
		
		#print('Teleporter intercepted, to (' .. location[1] .. ',' .. location[2] .. ',' .. location[3] .. ')')
		#print('Teleporter intercepted, from (' .. teleporterLocation[1] .. ',' .. teleporterLocation[2] .. ',' .. teleporterLocation[3] .. ')')
		
		-- check if the distance is within the allowed teleport range
		local dist = VDist2(location[1], location[2], teleporterLocation[1], teleporterLocation[2])
		
		if dist < self.TeleportRange then 
			return true
		end
		#print('Unable to teleport. ' .. math.round(dist) .. ' out of range. (Range: ' .. self.TeleportRange .. ')')
		return false
	end,

}