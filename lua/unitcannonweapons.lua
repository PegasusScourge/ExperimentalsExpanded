#****************************************************************************
#**
#**  File     :  /lua/terranweapons.lua
#**  Author(s):  John Comes, David Tomandl, Gordon Duclos
#**
#**  Summary  :  Terran-specific weapon definitions
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

local WeaponFile = import('/lua/sim/DefaultWeapons.lua')
local DefaultProjectileWeapon = WeaponFile.DefaultProjectileWeapon

local EffectTemplate = import('/mods/ExperimentalsExpanded/lua/ArkEffectTemplates.lua')

local Weapon = import('/lua/sim/Weapon.lua').Weapon

UnitCannonWeapon = Class(DefaultProjectileWeapon) {
    FxMuzzleFlash = EffectTemplate.TIFArtilleryMuzzleFlash,
	
	VariableTable = {},
	UnitTable = {},
	
	OnCreate = function(self)
		DefaultProjectileWeapon.OnCreate(self)
		LOG('On CREATE')
		local parentUnit = self.unit
		local unitID = parentUnit.EntityId
		-- Create an entry at the index of unitID in the unit table and the variable table to hold our data
		self.UnitTable[unitID] = {['defaultentry']=1}
		self.VariableTable[unitID] = {['numUnits']=0,['maxHooks']=21,['usedHooks']=0}
	end,
	
	AddUnit = function(self)
		local parentUnit = self.unit
		local unitID = parentUnit.EntityId
		local unit = self.unit.UnitBeingBuilt
		table.insert(self.UnitTable[unitID], 1, unit)
		-- LOG('UNIT_CANNON: Unit was added to weapon, unit=', unit, ' and entry in table=', self.UnitTable[unitID][1])
		-- LOG('UNIT_CANNON: UnitTable=', self.UnitTable[unitID], ' and cannonWeapon=', self)
		self.VariableTable[unitID].numUnits = self.VariableTable[unitID].numUnits + 1
		self.UpdateHooksUsed(self)
		
		-- print('Hooks used ', self.GetNumberOfHooksUsed(self), ' out of ', self.GetMaxNumberOfHooks(self))
	end,
	
	NumberOfUnitsToFire = function(self)
		local parentUnit = self.unit
		local unitID = parentUnit.EntityId
		return self.VariableTable[unitID].numUnits
	end,
	
	-- Number of hooks increases as the tier number for each unit
	UpdateHooksUsed = function(self)
		local parentUnit = self.unit
		local unitID = parentUnit.EntityId
		-- LOG('UpdateHooks called ------------------------------------------------------------------------')
		self.VariableTable[unitID].usedHooks = 0
		local tier = 0
		local uT = self.UnitTable[unitID]
		for key,unit in pairs(uT) do
			if unit ~= nil then
				if EntityCategoryContains(categories.BUILTBYTIER1FACTORY, unit) then
					tier = 1
				elseif EntityCategoryContains(categories.BUILTBYTIER2FACTORY, unit) then
					tier = 2
				elseif EntityCategoryContains(categories.BUILTBYTIER3FACTORY, unit) then
					tier = 3
				end
				if tier == 0 then
					-- LOG('UNIT LOADED THAT DOESN\'T HAVE A TIER!')
					-- Default to tier 3 unit
					tier = 3
				#else
					-- LOG('Unit tier in update hooks=', tier)
				end
			
				self.VariableTable[unitID].usedHooks = self.VariableTable[unitID].usedHooks + tier
			end
		end
		-- LOG('UpdateHooks ended ------------------------------------------------------------------------')
	end,
	
	GetNumberOfHooksUsed = function(self)
		local parentUnit = self.unit
		local unitID = parentUnit.EntityId
		return self.VariableTable[unitID].usedHooks
	end,
	
	GetMaxNumberOfHooks = function(self)
		local parentUnit = self.unit
		local unitID = parentUnit.EntityId
		return self.VariableTable[unitID].maxHooks
	end,
	
	-- Changed to load the unit bp onto the projectile
	CreateProjectileAtMuzzle = function(self, muzzle, unit)
		local parentUnit = self.unit
		local unitID = parentUnit.EntityId
		local proj = DefaultProjectileWeapon.CreateProjectileAtMuzzle(self, muzzle)
		-- LOG('UNIT_CANNON: Unit has been fired from cannon, unit=', unit)
		self.VariableTable[unitID].numUnits = self.VariableTable[unitID].numUnits - 1
		proj.AddUnitToCarry(proj, unit:GetBlueprint())
		unit:Destroy()
	end,
	
	RackSalvoFiringState = State {
        WeaponWantEnabled = true,
        WeaponAimWantEnabled = true,

        RenderClockThread = function(self, rof)
            local clockTime = rof
            local totalTime = clockTime
            while clockTime > 0.0 and 
                  not self:BeenDestroyed() and 
                  not self.unit:IsDead() do
                self.unit:SetWorkProgress( 1 - clockTime / totalTime )
                clockTime = clockTime - 0.1
                WaitSeconds(0.1)                            
            end
        end,
    
        Main = function(self)
			-- Changed from original?
			local parentUnit = self.unit
			local unitID = parentUnit.EntityId
			
            self.unit:SetBusy(true)
            local bp = self:GetBlueprint()
            -- LOG("Weapon " .. bp.DisplayName .. " entered RackSalvoFiringState.")
            self:DestroyRecoilManips()
            local numRackFiring = self.CurrentRackSalvoNumber
            -- This is done to make sure that when racks fire together, they fire together.
            if bp.RackFireTogether == true then
                numRackFiring = table.getsize(bp.RackBones)
            end

            -- Fork timer counter thread carefully....
            if not self:BeenDestroyed() and 
               not self.unit:IsDead() then
                if bp.RenderFireClock and bp.RateOfFire > 0 then
                    local rof = 1 / bp.RateOfFire                
                    self:ForkThread(self.RenderClockThread, rof)                
                end
            end

            -- Most of the time this will only run once, the only time it doesn't is when racks fire together.
            while self.CurrentRackSalvoNumber <= numRackFiring and not self.HaltFireOrdered do
                local rackInfo = bp.RackBones[self.CurrentRackSalvoNumber]
                local numMuzzlesFiring = bp.MuzzleSalvoSize
                if bp.MuzzleSalvoDelay == 0 then
                    numMuzzlesFiring = table.getn(rackInfo.MuzzleBones)
                end
                local muzzleIndex = 1
                for i = 1, numMuzzlesFiring do
                    if self.HaltFireOrdered then
                        continue
                    end
                    local muzzle = rackInfo.MuzzleBones[muzzleIndex]
                    if rackInfo.HideMuzzle == true then
                        self.unit:ShowBone(muzzle, true)
                    end
                    if bp.MuzzleChargeDelay and bp.MuzzleChargeDelay > 0 then
                        if bp.Audio.MuzzleChargeStart then
                            self:PlaySound(bp.Audio.MuzzleChargeStart)
                        end
                        self:PlayFxMuzzleChargeSequence(muzzle)
                        if bp.NotExclusive then
                            self.unit:SetBusy(false)
                        end
                        WaitSeconds(bp.MuzzleChargeDelay)
                        if bp.NotExclusive then
                            self.unit:SetBusy(true)
                        end
                    end
                    self:PlayFxMuzzleSequence(muzzle)                    
                    if rackInfo.HideMuzzle == true then
                        self.unit:HideBone(muzzle, true)
                    end
                    if self.HaltFireOrdered then
                        continue
                    end
					
					-- -------------------------------------------------------------------------------------------------------------------------- CHANGED CODE FROM ORIGINAL
					local unitPopped = table.remove(self.UnitTable[unitID],1)
					-- LOG('UNIT_CANNON: Unit has been popped from table for firing, unitPopped=', unitPopped)
                    self:CreateProjectileAtMuzzle(muzzle, unitPopped)
                    -- --------------------------------------------------------------------------------------------------------------------------
					
					-- Decrement the ammo if they are a counted projectile
                    if bp.CountedProjectile == true then
                        if bp.NukeWeapon == true then
                            self.unit:NukeCreatedAtUnit()
                            self.unit:RemoveNukeSiloAmmo(1)
                        else
                            self.unit:RemoveTacticalSiloAmmo(1)
                        end
                    end
                    muzzleIndex = muzzleIndex + 1
                    if muzzleIndex > table.getn(rackInfo.MuzzleBones) then
                        muzzleIndex = 1
                    end
                    if bp.MuzzleSalvoDelay > 0 then
                        if bp.NotExclusive then
                            self.unit:SetBusy(false)
                        end
                        WaitSeconds(bp.MuzzleSalvoDelay)
                        if bp.NotExclusive then
                            self.unit:SetBusy(true)
                        end         
                    end
                end

                self:PlayFxRackReloadSequence()
                if self.CurrentRackSalvoNumber <= table.getn(bp.RackBones) then
                    self.CurrentRackSalvoNumber = self.CurrentRackSalvoNumber + 1
                end
            end

            self:DoOnFireBuffs()

            self.FirstShot = false

            self:StartEconomyDrain()

            self:OnWeaponFired()

            # We can fire again after reaching here
            self.HaltFireOrdered = false

            if self.CurrentRackSalvoNumber > table.getn(bp.RackBones) then
                self.CurrentRackSalvoNumber = 1
                if bp.RackSalvoReloadTime > 0 then
                    ChangeState(self, self.RackSalvoReloadState)
                elseif bp.RackSalvoChargeTime > 0 then
                    ChangeState(self, self.IdleState)
                elseif bp.CountedProjectile == true and bp.WeaponUnpacks == true then
                    ChangeState(self, self.WeaponPackingState)
                elseif bp.CountedProjectile == true and not bp.WeaponUnpacks then
                    ChangeState(self, self.IdleState)
                else
                    ChangeState(self, self.RackSalvoFireReadyState)
                end
            elseif bp.CountedProjectile == true and not bp.WeaponUnpacks then
                ChangeState(self, self.IdleState)
            elseif bp.CountedProjectile == true and bp.WeaponUnpacks == true then
                ChangeState(self, self.WeaponPackingState)
            else
                ChangeState(self, self.RackSalvoFireReadyState)
            end
        end,

        OnLostTarget = function(self)
            Weapon.OnLostTarget(self)
            local bp = self:GetBlueprint()
            if bp.WeaponUnpacks == true then
                ChangeState(self, self.WeaponPackingState)
            end
        end,

        # Set a bool so we won't fire if the target reticle is moved
        OnHaltFire = function(self)
            self.HaltFireOrdered = true
        end,
    },
}
