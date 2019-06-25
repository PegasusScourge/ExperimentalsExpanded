#****************************************************************************
#**
#**  File     :  /units/XSL0202/XSL0202_script.lua
#**
#**  Summary  :  Seraphim Heavy Bot Script
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
#local SWalkingLandUnit = import('/lua/seraphimunits.lua').SWalkingLandUnit
local MicroTeleporter = import ('/mods/ExperimentalsExpanded/lua/UnitEquipment.lua').MicroTeleporter
#local SDFAireauBolterWeapon = import('/lua/seraphimweapons.lua').SDFAireauBolterWeapon02

local originalXSL0202 = import('/units/XSL0202/XSL0202_script.lua').XSL0202

XSL0202 = Class(originalXSL0202) {
	#Weapons = {
    #    MainGun = Class(SDFAireauBolterWeapon) {}
    #},

	OnStopBeingBuilt = function(self,builder,layer)
		SWalkingLandUnit.OnStopBeingBuilt(self,builder,layer)
		
		-- create our teleporter
		local bp = self:GetBlueprint().MicroTeleporter
		self.Teleporter = MicroTeleporter {
			Owner = self,
			AttachBone = nil,
			TeleportRange = 90,
		}
		self.Trash:Add(self.Teleporter)
		
		self.UnitComplete = true
	end,
	
	OnTeleportUnit = function(self, teleporter, location, orientation)
		if self.Teleporter:InterceptTeleport(teleporter, location, orientation) then
			originalXSL0202.OnTeleportUnit(self, teleporter, location, orientation)
		end
	end,
	
	-- See /lua/sim/Unit.lua for the teleport functions!
	
	#UpdateTeleportProgress = function(self, progress)
	#	if self.Teleporter:InterceptTeleport() then
	#		originalXSL0202.UpdateTeleportProgress(self, progress)
	#	end
	#end,

}
TypeClass = XSL0202