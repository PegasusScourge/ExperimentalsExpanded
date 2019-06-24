#****************************************************************************
#**
#**  File     : /lua/terranprojectiles.lua
#**  Author(s): John Comes, Gordon Duclos, Matt Vainio
#**
#**  Summary  :
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
#------------------------------------------------------------------------
#  TERRAN PROJECTILES SCRIPTS
#------------------------------------------------------------------------
local Projectile = import('/lua/sim/projectile.lua').Projectile
local DefaultProjectileFile = import('/lua/sim/defaultprojectiles.lua')
local EmitterProjectile = DefaultProjectileFile.EmitterProjectile
local OnWaterEntryEmitterProjectile = DefaultProjectileFile.OnWaterEntryEmitterProjectile
local SingleBeamProjectile = DefaultProjectileFile.SingleBeamProjectile
local SinglePolyTrailProjectile = DefaultProjectileFile.SinglePolyTrailProjectile
local MultiPolyTrailProjectile = DefaultProjectileFile.MultiPolyTrailProjectile
local SingleCompositeEmitterProjectile = DefaultProjectileFile.SingleCompositeEmitterProjectile
local Explosion = import('/lua/defaultexplosions.lua')
local DepthCharge = import('/lua/defaultantiprojectile.lua').DepthCharge
local util = import('/lua/utilities.lua')

local EffectTemplate = import('/mods/ExperimentalsExpanded/lua/ArkEffectTemplates.lua')

#------------------------------------------------------------------------
#  PROJECTILES
#------------------------------------------------------------------------
UnitCannonProjectile = Class(SinglePolyTrailProjectile) {
	FxImpactTrajectoryAligned = false,
    PolyTrail = '/effects/emitters/antimatter_polytrail_01_emit.bp',
    PolyTrailOffset = 0,

    # Hit Effects
    FxImpactUnit = EffectTemplate.TAntiMatterShellHit01,
    FxImpactProp = EffectTemplate.TAntiMatterShellHit01,
    FxImpactLand = EffectTemplate.TAntiMatterShellHit01,
    FxLandHitScale = 1,
    FxImpactUnderWater = {},
    FxSplatScale = 8,

	-- Standard non spawning behaviour of the system
    OnImpact = function(self, targetType, targetEntity)
        local army = self:GetArmy()
        if targetType == 'Terrain' then
            CreateDecal( self:GetPosition(), util.GetRandomFloat(0,2*math.pi), 'nuke_scorch_001_normals', '', 'Alpha Normals', self.FxSplatScale, self.FxSplatScale, 150, 50, army )
            CreateDecal( self:GetPosition(), util.GetRandomFloat(0,2*math.pi), 'nuke_scorch_002_albedo', '', 'Albedo', self.FxSplatScale * 2, self.FxSplatScale * 2, 150, 50, army )
            self:ShakeCamera(20, 1, 0, 1)
        end
        local pos = self:GetPosition()
        DamageArea(self, pos, self.DamageData.DamageRadius, 1, 'Force', true)
        DamageArea(self, pos, self.DamageData.DamageRadius, 1, 'Force', true)
        EmitterProjectile.OnImpact(self, targetType, targetEntity)
    end,
}
UnitCannonProjectile02 = Class(UnitCannonProjectile) {
	PolyTrail = '/effects/emitters/default_polytrail_07_emit.bp',
	
	unitCarried = nil,

    # Hit Effects
    FxImpactUnit = EffectTemplate.TAntiMatterShellHit02,
    FxImpactProp = EffectTemplate.TAntiMatterShellHit02,
    FxImpactLand = EffectTemplate.TAntiMatterShellHit02,

	AddUnitToCarry = function(self, unit)
		self.unitCarried = unit
		#LOG("Projectile gained unit BP: ", unit)
		#print("Projectile gained unit BP: ", unit)
		
		#LOG("In table")
		#for key,value in pairs(unit) do LOG(key,value) end
	end,
	
    OnImpact = function(self, targetType, targetEntity)
        local army = self:GetArmy()
        CreateLightParticle( self, -1, army, 16, 6, 'glow_03', 'ramp_antimatter_02' )
        if targetType == 'Terrain' then
            CreateDecal( self:GetPosition(), util.GetRandomFloat(0,2*math.pi), 'nuke_scorch_001_normals', '', 'Alpha Normals', self.FxSplatScale, self.FxSplatScale, 150, 30, army )
            CreateDecal( self:GetPosition(), util.GetRandomFloat(0,2*math.pi), 'nuke_scorch_002_albedo', '', 'Albedo', self.FxSplatScale * 2, self.FxSplatScale * 2, 150, 30, army )
            self:ShakeCamera(20, 1, 0, 1)
        end
        local pos = self:GetPosition()
        DamageArea(self, pos, self.DamageData.DamageRadius, 1, 'Force', true)
        DamageArea(self, pos, self.DamageData.DamageRadius, 1, 'Force', true)
		
		-- Release the stored unit
		-- Check for no unit
		if self.unitCarried['BlueprintId'] then
			local unit = CreateUnit2(self.unitCarried['BlueprintId'], army, 'land', pos['x'], pos['z'], 0)
			-- print("Projectile released unit using BP: ", self.unitCarried)
			-- print('Impacted ', targetType)
			if targetType == 'Shield' then
				-- Unit hit shield, so we destroy and create wreckage. Also calculate the damage the shield should take
				unit:CreateWreckage(0.8)
				
				-- DEBUG: List the stuff thats in this projectile
				-- LOG("Unit data")
				-- for k,v in pairs(self) do LOG(tostring(k) .. "\t" .. type(v) .. "\t" .. tostring(v)) end
				-- LOG("Damage Data:")
				-- for k,v in pairs(self.DamageData) do LOG(tostring(k) .. "\t" .. type(v) .. "\t" .. tostring(v)) end
				-- LOG("Buffs Data:")
				-- for k,v in pairs(self.DamageData.Buffs) do LOG(tostring(k) .. "\t" .. type(v) .. "\t" .. tostring(v)) end
				
				local baseDamage = self.DamageData.DamageAmount
				local calcdDmg = baseDamage
				local percyBP = GetUnitBlueprintByName("XEL0305")
				local dmgCap = 2000 -- This is the maximum damage of the shell
				local referenceMass = 100
				
				-- If we get a valid bp we continue using the dmg cap
				if percyBP then
					referenceMass = percyBP.Economy.BuildCostMass
				else
					WARN("UNIT_CANNON: No percival blueprint was found, forced damage cap to base dmg")
					dmgCap = baseDamage
				end
				
				local droppedUnitMass = GetBlueprint(unit).Economy.BuildCostMass
				
				if droppedUnitMass == 0 then
					droppedUnitMass = 1
				end
				
				-- Do the calc
				calcdDmg = math.ceil(dmgCap * (droppedUnitMass/referenceMass))
				if calcdDmg < baseDamage then
					calcdDmg = baseDamage
				end
				if calcdDmg > dmgCap then
					calcdDmg = dmgCap
				end
				
				-- Apply our damage calc
				self.DamageData.DamageAmount = calcdDmg
				
				LOG("UNIT_CANNON: RefMass: " .. tostring(referenceMass) .. "\tUnit mass: " .. droppedUnitMass .. "\tNew dmg: " .. calcdDmg)
				
				IssueDestroySelf( {unit} )
			end
		else
			-- We shot a dud?
			WARN("UNIT_CANNON: nil unit shot! Somehow....")
			self.DamageData.DamageAmount = 0
		end
		-- End nil unit check
		
		-- Do the vanilla impact
		EmitterProjectile.OnImpact(self, targetType, targetEntity)
    end,
}

