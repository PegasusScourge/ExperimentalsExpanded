#****************************************************************************
#**
#**  File     :  /mods/ExperimentalsExpanded/units/PSL0202/PSL0202_script.lua
#**
#**  Summary  :  Seraphim Heavy Bot Script
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
local SWalkingLandUnit = import('/lua/seraphimunits.lua').SWalkingLandUnit
local MicroTeleporter = import ('/mods/ExperimentalsExpanded/lua/UnitEquipment.lua').MicroTeleporter
local SDFAireauBolterWeapon = import('/lua/seraphimweapons.lua').SDFAireauBolterWeapon02

-- We're basically a bigger ilshavoh

PSL0202 = Class(SWalkingLandUnit) {
	Weapons = {
        MainGun = Class(SDFAireauBolterWeapon) {},
    },

	OnStopBeingBuilt = function(self,builder,layer)
		SWalkingLandUnit.OnStopBeingBuilt(self,builder,layer)
		
		-- create our teleporter
		local bp = self:GetBlueprint().MicroTeleporter
		self.Teleporter = MicroTeleporter {
			Owner = self,
			AttachBone = bp.AttachBone,
			TeleportRange = bp.Range,
		}
		self.Trash:Add(self.Teleporter)
		
		self.UnitComplete = true
	end,
	
	OnTeleportUnit = function(self, teleporter, location, orientation)
		if self.Teleporter:InterceptTeleport(teleporter, location, orientation) then
			SWalkingLandUnit.OnTeleportUnit(self, teleporter, location, orientation)
		end
	end,
	
	-- See /lua/sim/Unit.lua for the teleport functions!
	
	#UpdateTeleportProgress = function(self, progress)
	#	if self.Teleporter:InterceptTeleport() then
	#		SWalkingLandUnit.UpdateTeleportProgress(self, progress)
	#	end
	#end,

}
TypeClass = PSL0202