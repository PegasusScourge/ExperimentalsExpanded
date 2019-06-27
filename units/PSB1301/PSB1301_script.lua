#****************************************************************************
#**
#**  File     :  /data/units/XSB1301/XSB1301_script.lua
#**  Author(s):  Jessica St. Croix, Greg Kohne
#**
#**  Summary  :  Seraphim T3 Power Generator Script
#**
#**  Copyright © 2007 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
local SStructureUnit = import('/lua/seraphimunits.lua').SStructureUnit
local Entity = import('/lua/sim/Entity.lua').Entity
local util = import('/lua/utilities.lua')

local EmtBpPath = '/mods/ExperimentalsExpanded/effects/Emitters/'

PSB1301 = Class(SStructureUnit) {
    #AmbientEffects = 'ST3PowerAmbient',
	
	TeleEffect = {
		EmtBpPath .. 'teleport_rising_mist_01_psb1301_emit.bp',
		EmtBpPath .. '_test_commander_gate_explosion_02_psb1301_emit.bp',
		EmtBpPath .. '_test_commander_gate_explosion_05_psb1301_emit.bp',
	},
	STeleport = {
		EmtBpPath .. 'seraphim_teletower_ambient_01_emit.bp',
		EmtBpPath .. 'seraphim_teletower_ambient_02_emit.bp',
		EmtBpPath .. 'seraphim_teletower_ambient_04_emit.bp',
	},
	
	FxBeamStartPoint = {
		'/units/DSLK004/effects/seraphim_electricity_emit.bp'
	},
	FxBeam = {
        '/units/DSLK004/effects/seraphim_lightning_beam_01_emit.bp',
    },
    FxBeamEndPoint = {
        '/units/DSLK004/effects/seraphim_lightning_hit_01_emit.bp',
        #'/units/DSLK004/effects/seraphim_lightning_hit_02_emit.bp',
        #'/units/DSLK004/effects/seraphim_lightning_hit_03_emit.bp',
        #'/units/DSLK004/effects/seraphim_lightning_hit_04_emit.bp',
    },
	
	BallRotor = nil,
	BallSlider = nil,
	BallSliderRestPosition = -25,
	BallRotorNormalSpeed = 2,
	BallSliderTeleportPosition = -42,
	BallRotorTeleportSpeed = 100,
	
	firedBeams = {},
	beamFx = {},
	chargeEffects = {},
	nearbyUnits = {},
	
	TeleportingUnits = false,
    
    OnStopBeingBuilt = function(self, builder, layer)
        SStructureUnit.OnStopBeingBuilt(self, builder, layer)
		self.BallRotor = CreateRotator(self, 'Orb', 'y', nil, 0, self.BallRotorNormalSpeed, 300)
		self.BallSlider = CreateSlider(self, 'Orb', 0, self.BallSliderRestPosition, 0, 15)
        self.Trash:Add(self.BallRotor)
		self.Trash:Add(self.BallSlider)
		
		-- disabled the cloakfield, this is used to show the teleport range
		-- idea and execution courtesy of Blackops Unleashed (Exavier Macbeth, lt_hawkeye, orangeknight - Revamped 2016 by IceDreamer)
		self:DisableUnitIntel('unitScript', 'CloakField')
		
		-- display all the categories we can address 
		#LOG('Categories:')
		#for key,value in pairs(categories) do
		#	LOG("found member " .. key .. ' with value ' .. string.format("%s", tostring(value)));
		#end
    end,
	
	OnTeleportUnit = function(self, teleporter, location, orientation)
		if self.TeleportingUnits then
			-- we are already teleporting units! terminate the effects etc
			self:ForceCancelTeleport()
		else
			self:ForkThread(self.TeleportUnitsThread, teleporter, location, orientation)
		end
		
		#-- fail our own teleport just in case
		#self.OnFailedTeleport(self)
	end,
	
	OnKilled = function(self, instigator, type, overkillRatio)
		-- cause the ball to fall to the ground
		self.BallSlider:SetGoal(0, -5, 0)
		self.BallSlider:SetSpeed(40)
		
		self:ForceCancelTeleport()
		
		SStructureUnit.OnKilled(self, instigator, type, overkillRatio)
	end,
	
	TeleportUnitsThread = function(self, teleporter, location, orientation)
		
		local brain = self:GetAIBrain()
		local bp = self:GetBlueprint()
		local detectedUnits = brain:GetUnitsAroundPoint(categories.LAND, self:GetPosition(), bp.TeleportTower.TeleportRange)
		
		-- create a new unit list and reduce to allowed units
		self.nearbyUnits = {}
		for _,u in detectedUnits do
			if IsUnit(u) then
				if self:IsValidUnit(u) and self:GetArmy() == u:GetArmy() then -- check for valid type and army of unit
					table.insert(self.nearbyUnits, u)
				end
			end
		end
		
		local numNearbyUnits = table.getn(self.nearbyUnits)
		#print('Found ' .. numNearbyUnits .. ' units nearby')
		
		if numNearbyUnits == 0 then 
			-- we can't actually teleport anything, so just return
			return
		end
		
		self.TeleportingUnits = true
		local army = self:GetArmy()
	
		-- start the teleport noise
		self:PlayUnitAmbientSound('TeleportWub')
		
		-- create emitters and add to the bag
		for _,v in self.STeleport do
			local em = CreateEmitterAtEntity(self, army, v)
			table.insert(self.chargeEffects, em)
		end
		WaitSeconds(0.4)
		-- create emitters again, for two layers
		for _,v in self.TeleEffect do
			local em = CreateEmitterAtEntity(self, army, v)
			table.insert(self.chargeEffects, em)
		end
		
		-- speed up the orb and rise it
		if self.BallRotor then
			self.BallRotor:SetTargetSpeed(self.BallRotorTeleportSpeed)
		end
		if self.BallSlider then
			self.BallSlider:SetGoal(0, self.BallSliderTeleportPosition, 0)
		end
		
		self:ForkThread(self.FireBeamsThread, self.nearbyUnits, self.FxBeam, self.FxBeamStartPoint, self.FxBeamEndPoint, 'Orb')
		
		LOG('Teleporter: to = (' .. location[1] .. ', ' .. location[2] .. ', ' .. location[3] .. ')')
		LOG('Teleporter: orientation = (' .. orientation[1] .. ', ' .. orientation[2] .. ', ' .. orientation[3] .. ')')
		LOG('Teleporting ' .. numNearbyUnits .. ' units')
		
		-- issue teleports for the units
		local randomizedDif = 6.2
		for _,unit in self.nearbyUnits do
			IssueClearCommands({unit})
			LOG('Teleporting unit to ' .. (location[1] + util.GetRandomFloat(-randomizedDif, randomizedDif)) .. ', 0, ' .. (location[3] + util.GetRandomFloat(-5, 5)) .. ')')
			unit:OnTeleportUnit(unit, {location[1] + util.GetRandomFloat(-randomizedDif, randomizedDif), 0 , location[3] + util.GetRandomFloat(-5, 5)}, orientation)
		end
		
		while self.TeleportingUnits do
			WaitSeconds(1)
		end
		
		-- end the teleport
		self.TeleportingUnits = false
		
		-- destroy emitters
		self:DestroyEmitters(self.chargeEffects)
		
		-- spin down the orb to normal speed and lower
		if self.BallRotor then
			self.BallRotor:SetTargetSpeed(self.BallRotorNormalSpeed)
		end
		if self.BallSlider then
			self.BallSlider:SetGoal(0, self.BallSliderRestPosition, 0)
		end
		
		-- stop the teleport noise
		self:StopUnitAmbientSound('TeleportWub')
	
		-- clear unit list
		self.nearbyUnits = {}
	end,
	
	DestroyEmitters = function(self, emitters)
		for _,v in emitters do
			v:Destroy()
		end
	end,
	
	ForceCancelTeleport = function(self)
		self:DestroyEmitters(self.firedBeams)
		self:DestroyEmitters(self.beamFx)
		self:DestroyEmitters(self.chargeEffects)
		
		-- nullify the teleport thread
		self.TeleportingUnits = false
		
		-- stop units teleporting
		for _,u in self.nearbyUnits do
			if not u:BeenDestroyed() then
				u:OnFailedTeleport()
			end
		end
		self.nearbyUnits = {}
	end,
	
	FireBeamsThread = function(self, units, fx, fxstart, fxend, startbone)
		-- create the beams
		local army = self:GetArmy()
		
		-- create the start emission
		for _,v in fxstart do
			local em = CreateEmitterAtBone(self, startbone, army, v)
			table.insert(self.beamFx, em)
		end
	
		#-- create the end emission
		#for _,u in units do
		#	for _,v in fxend do
		#		local em = CreateAttachedEmitter(u, nil, army, v)
		#		table.insert(beamFx, em)
		#	end
		#end
		
		local unitsTeleporting = 0
		
		-- track the unit ids that are teleporting, so we can give them a correct sign off
		local teleportingIDs = {}
		
		WaitSeconds(1)
		
		while self.TeleportingUnits do
			unitsTeleporting = 0
			for _,u in units do
				local id = u:GetEntityId()
				if not u:BeenDestroyed() and u.UnitBeingTeleported then
					-- check to see if unit is already in teleport ids
					if not teleportingIDs[id] then
						teleportingIDs[id] = 1
					end
					
					for _,v in fx do
						local em = nil
						if util.GetRandomInt(0,2) == 1 then -- Randomly select 0, 1 or 2. 1/3rd of the time, the lightning bolt goes FROM the unit instead of TO. Just for fun visuals
							em = CreateBeamEntityToEntity(u, nil, self, nil, army, v)
						else
							em = CreateBeamEntityToEntity(self, nil, u, nil, army, v)
						end
						table.insert(self.firedBeams, em)
						unitsTeleporting = unitsTeleporting + 1
					end
				else
					-- check to see if unit is in teleport ids
					if teleportingIDs[id] ~= nil then
						if teleportingIDs[id] == 1 then
							teleportingIDs[id] = 0
							
							-- fire a farewell beam
							for _,v in fx do
								local em = CreateBeamEntityToEntity(self, nil, u, nil, army, v)
								table.insert(self.firedBeams, em)
							end
							self:PlayUnitSound('TeleportSend')
						end
					end
				end
			end
			
			if unitsTeleporting == 0 then 
				self.TeleportingUnits = false
			else
				-- each beam fired costs 100 energy and 1 mass per tick
				CreateEconomyEvent(self, unitsTeleporting * 100, unitsTeleporting, 0.5)
				
				-- play the teleport bolt sound
				self:PlayUnitSound('TeleportBolt')
			end
			
			WaitSeconds(0.5)
		end
		self:DestroyEmitters(self.beamFx)
		self:DestroyEmitters(self.firedBeams)
	end,
	
	IsValidUnit = function(self, u)
		-- categories.SHOULDNOTTELEPORT is employed on blueprint merges where we don't want the unit to be able to teleport specifically, if another category doesn't cover it
		return EntityCategoryContains(categories.LAND, u) and not EntityCategoryContains(categories.SHOULDNOTTELEPORT, u) and not EntityCategoryContains(categories.EXPERIMENTAL, u) and not EntityCategoryContains(categories.STRUCTURE, u) and not EntityCategoryContains(categories.COMMAND, u) and not EntityCategoryContains(categories.SUBCOMMANDER, u)
	end,
}

TypeClass = PSB1301