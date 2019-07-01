#****************************************************************************
#**
#**  File     :  /cdimage/units/UAB2301/UAB2301_script.lua
#**  Author(s):  John Comes, David Tomandl, Jessica St. Croix
#**
#**  Summary  :  Aeon Heavy Gun Tower Script
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

local AStructureUnit = import('/lua/aeonunits.lua').AStructureUnit
local ConversionGun = import('/mods/ExperimentalsExpanded/lua/ExperimentalsExpandedWeapons.lua').ConversionWeapon
local util = import('/lua/utilities.lua')

PAB2301 = Class(AStructureUnit) {
    Weapons = {
        MainGun = Class(ConversionGun) {
			FxMuzzleFlash = {
				'/effects/emitters/oblivion_cannon_flash_04_emit.bp',
				'/effects/emitters/oblivion_cannon_flash_05_emit.bp',
				'/effects/emitters/oblivion_cannon_flash_06_emit.bp',
			},
        }
    },
	
	FxAmbient = {
		'/effects/emitters/seraphim_being_built_ambient_01_emit.bp',
		'/effects/emitters/seraphim_being_built_ambient_02_emit.bp',
		'/effects/emitters/seraphim_being_built_ambient_03_emit.bp',
		'/effects/emitters/seraphim_being_built_ambient_04_emit.bp',
		'/effects/emitters/seraphim_being_built_ambient_05_emit.bp',
	},
	
	FxConvert = '/effects/emitters/unit_upgrade_ambient_02_emit.bp',
	
	TurretSlider = nil,
	BarrelSlider = nil,
	FrontLSlider = nil,
	FrontRSlider = nil,
	BackLSlider = nil,
	BackRSlider = nil,
	
	IsUnpacked = false, -- used to determine if the turret is stowed
	ChangeTargetForced = false,
	CurrentTarget = nil,
	
	ConvertRotor = nil,
	AmbientBag = {},
	
	OnStartBeingBuilt = function(self, builder, layer)
		AStructureUnit.OnStartBeingBuilt(self, builder, layer)
		self:RotateFix()
	end,
	
	OnStopBeingBuilt = function(self, builder, layer)
		AStructureUnit.OnStopBeingBuilt(self, builder, layer)
		
		self.TurretSlider = CreateSlider(self, 'Turret_Barrel', 0, 0, -1, 1)
		self.BarrelSlider = CreateSlider(self, 'Barrel', 0, 0, 0, 1)
		self.FrontLSlider = CreateSlider(self, 'Front_Left', 0, 0, 0, 0.15)
		self.FrontRSlider = CreateSlider(self, 'Front_Right', 0, 0, 0, 0.15)
		self.BackLSlider = CreateSlider(self, 'Back_Left', 0, 0, 0, 0.15)
		self.BackRSlider = CreateSlider(self, 'Back_Right', 0, 0, 0, 0.15)
		
		CreateSlider(self, 'Turret', 0, 0, 1, 10) -- move the turret point forward, compensated with the turret barrel moving backward
		
		self:ForkThread(self.UnpackTurret)
		self:ForkThread(self.ConvertEnemiesThread)
		self:ForkThread(self.WatchManualTargettingThread)
		
		self.ConvertRotor = CreateEmitterAtEntity(self, self:GetArmy(), self.FxConvert):OffsetEmitter(0, 1, 0):ScaleEmitter(1)
		self.ConvertRotor:SetEmitterCurveParam('ROTATION_RATE_CURVE', 2, 0)
		
		self:RotateFix()
	end,
	
	OnKilled = function(self, instigator, type, overkillRatio)
		-- clean up the ambient hover effects
		for _,v in self.AmbientBag do
			v:Destroy()
		end
		if self.ConvertRotor then
			self.ConvertRotor:Destroy()
		end
		AStructureUnit.OnKilled(self, instigator, type, overkillRatio)
	end,
	
	WatchManualTargettingThread = function(self)
		-- we check for a target being set to the unit
		local currentTargetId = nil
		local newTargetId = nil
		while not self:BeenDestroyed() do
			if self:GetTargetEntity() then
				newTargetId = self:GetTargetEntity():GetEntityId()
			end
			if currentTargetId ~= newTargetId and newTargetId ~= nil then
				-- we have a new, non-nil target
				self:GetWeaponByLabel('MainGun'):SetTargetEntity(GetEntityById(newTargetId))
				currentTargetId = newTargetId
				LOG('LOYALTY CANNON: manual retarget to ' .. currentTargetId)
				self.ChangeTargetForced = true
				self.CurrentTarget = currentTargetId
			end
			WaitSeconds(0.5)
		end
	end,
	
	-- This function monitors the maingun and tracks the targets it is firing on, converting them as necessary
	ConvertEnemiesThread = function(self)
		#local conversionWeapon = self.Weapons.MainGun
		
		local newTargetId = nil
		
		local chargeTime = 0
		local chargeTimeTarget = 30
		
		local bp = self:GetBlueprint()
		
		while not self:BeenDestroyed() do -- this thread runs as long as we are alive
			if self:GetWeaponByLabel('MainGun'):GetCurrentTarget() or self.ChangeTargetForced then
				-- we have registered a target, get the id of it to confirm if it is the same or different
				newTargetId = self:GetWeaponByLabel('MainGun'):GetCurrentTarget():GetEntityId()
				if not IsUnit(GetEntityById(newTargetId)) then
					newTargetId = self.CurrentTarget
				end
				
				#LOG('Got a target in range: ' .. newTargetId)
				if self.CurrentTarget == newTargetId and self.CurrentTarget ~= nil and self.ChangeTargetForced ~= true then
					-- same target, don't change anything
					chargeTime = chargeTime + 0.5
					if chargeTime > chargeTimeTarget then
						-- convert the entity to our army
						chargeTime = 0
						chargeTimeTarget = 25
						-- send the unit
						ChangeUnitArmy(GetEntityById(self.CurrentTarget), self:GetAIBrain():GetArmyIndex())
					else
						self.ConvertRotor:SetEmitterCurveParam('ROTATION_RATE_CURVE', 10 + math.floor((chargeTime/chargeTimeTarget)*10), math.floor((chargeTime/chargeTimeTarget)*300))
					end
				else
					-- change target to the new one
					chargeTime = 0
					self.CurrentTarget = newTargetId
					chargeTimeTarget = bp.LoyaltyConversion.BaseTime + (GetEntityById(self.CurrentTarget):GetBlueprint().Economy.BuildCostMass/400)
					LOG('LOYALTY CANNON: Attempting capture of unit ' .. self.CurrentTarget .. ' with time ' .. chargeTimeTarget .. ' ticks. IsUnit:' .. string.format("%s", tostring(IsUnit(GetEntityById(self.CurrentTarget)))))
				end
				self.ChangeTargetForced = false
			else
				-- we have no current target
				self.ConvertRotor:SetEmitterCurveParam('ROTATION_RATE_CURVE', 2, 0)
			end
			WaitSeconds(0.25)
		end
	end,
	
	UnpackTurret = function(self)
		-- initiate the unpack
		self:OpenBottomPanels()
		WaitSeconds(1)
		self.TurretSlider:SetGoal(0, 2, -1)
		WaitSeconds(3)
		self.BarrelSlider:SetGoal(0, 0, 1)
		self:CloseBottomPanels()
		self.IsUnpacked = true
		-- create the ambient hover effects
		local army = self:GetArmy()
		for _,v in self.FxAmbient do
			local fx = CreateEmitterAtEntity(self, army, v):ScaleEmitter(1.25)
			table.insert(self.AmbientBag, fx:OffsetEmitter(0, 0.9, 0))
		end
	end,
	
	#PackTurret = function(self)
	#	-- initiate the pack
	#	self.IsUnpacked = false
	#	self:OpenBottomPanels()
	#	self.BarrelSlider:SetGoal(0, 0, 0)
	#	WaitSeconds(1)
	#	self.TurretSlider:SetGoal(0, 0, -1)
	#	WaitSeconds(3)
	#	self:CloseBottomPanels()
	#	-- clean up the ambient hover effects
	#	for _,v in self.AmbientBag do
	#		v:Destroy()
	#	end
	#end,
	
	OpenBottomPanels = function(self)
		self.FrontLSlider:SetGoal(-0.2, 0, 0.2)
		self.FrontRSlider:SetGoal(0.2, 0, 0.2)
		self.BackLSlider:SetGoal(-0.3, 0, -0.05)
		self.BackRSlider:SetGoal(0.3, 0, -0.05)
	end,
	
	CloseBottomPanels = function(self)
		self.FrontLSlider:SetGoal(0, 0, 0)
		self.FrontRSlider:SetGoal(0, 0, 0)
		self.BackLSlider:SetGoal(0, 0, 0)
		self.BackRSlider:SetGoal(0, 0, 0)
	end,
	
	-- override the pointing towards the middle behaviour to prevent random crap
	RotateFix = function(self)
		self:SetRotation(0)
    end,
}

TypeClass = PAB2301