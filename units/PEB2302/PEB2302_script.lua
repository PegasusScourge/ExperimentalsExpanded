#****************************************************************************
#**
#**  File     :  /cdimage/units/UEB2302/UEB2302_script.lua
#**  Author(s):  John Comes, David Tomandl, Jessica St. Croix
#**
#**  Summary  :  UEF Long Range Artillery Script
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

# PEGASUS SCOURGE EDIT FOR ARK UNIT CANNON

local TStructureUnit = import('/lua/terranunits.lua').TStructureUnit
local UnitCannonW = import('/mods/ExperimentalsExpanded/lua/unitcannonweapons.lua').UnitCannonWeapon

local Unit = import('/lua/sim/Unit.lua').Unit

PEB2302 = Class(TStructureUnit) {
    Weapons = {
        MainGun = Class(UnitCannonW) {
            FxMuzzleFlashScale = 3,
			UnitTable = {},
			numUnits = 0,
			maxHooks = 21,
			usedHooks = 0,
        }
    },
	
	########################
	#
	# Handles the building of the units and the storage. Copied from the Atlantis
	#
	########################
	
	BuildAttachBone = 'Turret',
	
	WeaponHasUnitSpace = true,
	WeaponHookSpace = 21,
	
	OnStopBeingBuilt = function(self,builder,layer)
		TStructureUnit.OnStopBeingBuilt(self,builder,layer)
        ChangeState(self, self.IdleState)
		self.SetWeaponEnabledByLabel(self, 'MainGun', false)
		
		self:ForkThread(self.UpdateCannonThread)
		-- self.Trash:Add(self.UpdateCannonThread)
    end,

    OnFailedToBuild = function(self,builder,layer)
		TStructureUnit.OnFailedToBuild(self,builder,layer)
		WARN("UNIT_CANNON: Detected failed to build")
        ChangeState(self, self.IdleState)
    end,
	
	# Checks if we have units to fire, if we do we enable the weapon
	UpdateCannonThread = function(self)
		local MainG = self.GetWeaponByLabel(self, 'MainGun')
		
		while true do
			WaitSeconds(0.2)
			local numu = MainG:NumberOfUnitsToFire(MainG)
			#print("number of units: ", numu)
			if numu > 0 then
				self.SetWeaponEnabledByLabel(self, 'MainGun', true)
			else
				self.SetWeaponEnabledByLabel(self, 'MainGun', false)
			end
			
			MainG:UpdateHooksUsed(MainG)
			local hooksLeft = MainG:GetMaxNumberOfHooks(MainG) - MainG:GetNumberOfHooksUsed(MainG)
			if hooksLeft > 0 then
				if not self.WeaponHasUnitSpace then
					self.WeaponHasUnitSpace = true
					self:SetProductionActive(true)
					self:RestoreBuildRestrictions()
					self:RequestRefreshUI()
				end
				self.WeaponHookSpace = hooksLeft
			else
				self.WeaponHasUnitSpace = false
			end
		end
	end,
	
	# Updates the unit list for the weapons
	AddUnitForWeaponToCarry = function(self, unit)
		local MainG = self.GetWeaponByLabel(self, 'MainGun')
		MainG:AddUnit(MainG)
		#LOG("UNIT_CANNON: Added blueprint to weapon: ", unit)
	end,
	
	IdleState = State {
        Main = function(self)
            self:DetachAll(self.BuildAttachBone)
            self:SetBusy(false)
        end,

        OnStartBuild = function(self, unitBuilding, order)
			local MainG = self.GetWeaponByLabel(self, 'MainGun')
			MainG:UpdateHooksUsed(MainG)
			local hooksLeft = MainG:GetMaxNumberOfHooks(MainG) - MainG:GetNumberOfHooksUsed(MainG)
			if hooksLeft > 0 then
				self.WeaponHasUnitSpace = true
				self.WeaponHookSpace = hooksLeft
			else
				self.WeaponHasUnitSpace = false
			end
		
			TStructureUnit.OnStartBuild(self, unitBuilding, order)
            self.UnitBeingBuilt = unitBuilding
			
			local tier = 0
			if EntityCategoryContains(categories.BUILTBYTIER1FACTORY, self.UnitBeingBuilt) then
				tier = 1
			elseif EntityCategoryContains(categories.BUILTBYTIER2FACTORY, self.UnitBeingBuilt) then
				tier = 2
			elseif EntityCategoryContains(categories.BUILTBYTIER3FACTORY, self.UnitBeingBuilt) then
				tier = 3
			end
			if tier == 0 then
				#LOG('UNIT LOADED THAT DOESN\'T HAVE A TIER!')
				# Default to tier 3 unit
				tier = 3
			#else
				#LOG('Unit tier in cannon build test=', tier)
			end
			
			local nextHookUse = MainG:GetNumberOfHooksUsed(MainG) + tier
			if nextHookUse >= MainG:GetMaxNumberOfHooks(MainG) then
				self:SetProductionActive(false)
				self:AddBuildRestriction(categories.ALLUNITS)
				self:RequestRefreshUI()
			end
			#if nextHookUse < MainG:GetMaxNumberOfHooks(MainG) then
			#	self:SetProductionActive(true)
			#	self:RestoreBuildRestrictions()
			#	self:RequestRefreshUI()
			#end
			
			#LOG('UNIT_CANNON: Unit has started build ok, has been transfered to UnitBeingBuilt:', self.UnitBeingBuilt)
			ChangeState(self, self.BuildingState)
			#LOG('UNIT_CANNON: entering building state')
        end,
    },

    BuildingState = State {
        Main = function(self)
            local unitBuilding = self.UnitBeingBuilt
            self:SetBusy(true)
            local bone = self.BuildAttachBone
            self:DetachAll(bone)
            unitBuilding:HideBone(0, true)
            self.UnitDoneBeingBuilt = false
        end,

        OnStopBuild = function(self, unitBeingBuilt)
            TStructureUnit.OnStopBuild(self, unitBeingBuilt)
            ChangeState(self, self.FinishedBuildingState)
			#LOG('UNIT_CANNON: entering finished building state')
        end,
    },

    FinishedBuildingState = State {
        Main = function(self)
            self:SetBusy(true)
            local unitBuilding = self.UnitBeingBuilt
			self.UnitDoneBeingBuilt = true
            unitBuilding:DetachFrom(true)
            self:DetachAll(self.BuildAttachBone)
			
			self:MarkWeaponsOnTransport(unitBuilding, true)
			if unitBuilding:ShieldIsOn() then
				unitBuilding:DisableShield()
				unitBuilding:DisableDefaultToggleCaps()
			end
			
			self:AddUnitToStorage(unitBuilding)
			self.AddUnitForWeaponToCarry(self, self.UnitBeingBuilt)
            self:SetBusy(false)
            self:RequestRefreshUI()
			-- LOG('UNIT_CANNON: UnitBeingBuilt has completed build, and is now in weapon (UnitBeingBuilt =', tostring(unitBuilding), ')')
            ChangeState(self, self.IdleState)
			#LOG('UNIT_CANNON: entering idle state')
        end,

    },
}

TypeClass = PEB2302