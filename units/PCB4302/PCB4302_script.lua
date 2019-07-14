#****************************************************************************
#**
#**  File     :  /mods/ExperimentalsExpanded/units/PCB4302/PCB4302_script.lua
#**  Author(s):  PegasusScourge
#**
#**  Summary  :  Cybran Strategic Missile Reflection Script
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

-- Based off the Cybran Antinuke and the Loyalist code

local CStructureUnit = import('/lua/cybranunits.lua').CStructureUnit
local BoomerangCollisionBeamWeapon = import('/mods/ExperimentalsExpanded/lua/ExperimentalsExpandedWeapons.lua').BoomerangCollisionBeamWeapon
local EffectTemplate = import('/lua/EffectTemplates.lua')
local Entity = import('/lua/sim/Entity.lua').Entity
local GetRandomFloat = import('/lua/utilities.lua').GetRandomFloat

PCB4302 = Class(CStructureUnit) {

	Weapons = {
        BoomerangWeapon = Class(BoomerangCollisionBeamWeapon) {
            FxMuzzleFlash = EffectTemplate.CAntiNukeLaunch01,
            
            IdleState = State(BoomerangCollisionBeamWeapon.IdleState) {
                OnGotTarget = function(self)
                    local bp = self:GetBlueprint()
                    #only say we've fired if the parent fire conditions are met
                    if (bp.WeaponUnpackLockMotion != true or (bp.WeaponUnpackLocksMotion == true and not self.unit:IsUnitState('Moving'))) then
                        if (bp.CountedProjectile == false) or self:CanFire() then
                             nukeFiredOnGotTarget = true
                        end
                    end
                    BoomerangCollisionBeamWeapon.IdleState.OnGotTarget(self)
                end,
                # uses OnGotTarget, so we shouldn't do this.
                OnFire = function(self)
                    if not nukeFiredOnGotTarget then
                        BoomerangCollisionBeamWeapon.IdleState.OnFire(self)
                    end
                    nukeFiredOnGotTarget = false
                    
                    self:ForkThread(function()
                        self.unit:SetBusy(true)
                        WaitSeconds(1/self.unit:GetBlueprint().Weapon[1].RateOfFire + .2)
                        self.unit:SetBusy(false)
                    end)
                end,
            },
        },
    },

    OnStopBeingBuilt = function(self,builder,layer)
        CStructureUnit.OnStopBeingBuilt(self,builder,layer)
		
		-- start drain thread
		self:SetMaintenanceConsumptionActive()
		self:ForkThread(self.WatchEconomyThread)
		
		-- start the target watch thread
		self:ForkThread(self.TargetWatchThread)
		
        self.UnitComplete = true
		
		#LOG('Entity members:')
		#for key,value in pairs(Entity) do
		#	LOG("found member " .. key);
		#end
    end,
	
	WatchEconomyThread = function(self)
		while not self:BeenDestroyed() do
			WaitSeconds(0.5)
			self.CanRedirect = true
			local fraction = self:GetResourceConsumed()
			while fraction == 1 do
				WaitSeconds(0.5)
				fraction = self:GetResourceConsumed()
			end
			self.CanRedirect = false
		end
	end,
	
	TargetWatchThread = function(self)
		local newTargetId = nil
		local currentTargetId = nil
		
		local myWeapon = self:GetWeaponByLabel('BoomerangWeapon')
		local bp = self:GetBlueprint().Weapon[1]
		local proj = nil
		
		while not self:BeenDestroyed() do
			if not self:BeenDestroyed() then
				if myWeapon.GetCurrentTarget ~= nil and myWeapon:GetCurrentTarget() then
					newTargetId = myWeapon:GetCurrentTarget():GetEntityId()
					LOG('Newtargetid: ' .. tostring(newTargetId))
					print('Newtargetid: ' .. tostring(newTargetId))
					if currentTargetId ~= newTargetId and newTargetId ~= nil then
						-- New nuke target got
						print('New nuke target of ' .. tostring(newTargetId))
						LOG('New nuke target of ' .. tostring(newTargetId))
						currentTargetId = newTargetId
						
						proj = GetEntityById(currentTargetId)
						-- fork the redirect thread
						proj:ForkThread(self.RedirectThread, proj)
						
						print(tostring(1.0 / bp.RateOfFire))
						WaitSeconds((1.0 / bp.RateOfFire))
					elseif newTargetId == nil then
						print('Nuke target is nil')
					elseif currentTargetId == newTargetId then
						print('Still targeting ' .. tostring(currentTargetId))
						LOG('Still targeting ' .. tostring(currentTargetId))
					end
				end
				
				if currentTargetId ~= nil and proj ~= nil then
					if proj:BeenDestroyed() then
						currentTargetId = nil
						proj = nil
					end
				end
			end
			WaitSeconds(0.25)
		end
	end,
	
	RedirectThread = function(self, proj)
		local launcher = proj:GetLauncher()
		
		local lifetime = 120
		if launcher == nil then
			launcher = proj
			lifetime = 10
		end
		
		local projPos = proj:GetPosition()
		local launcherPos = launcher:GetPosition()
		local launcherAbove = launcher:GetPosition()
		
		local flightHeight = 100
		
		-- configure the target points
		local flightPath = projPos
		flightPath[2] = GetSurfaceHeight(projPos[1], projPos[3]) + flightHeight
		launcherAbove[2] = GetSurfaceHeight(launcherPos[1], launcherPos[3]) + flightHeight
		launcherPos[2] = launcherPos[2] - 0.02 --put us slightly below the terrain with our aim
		
		if launcherPos[1] < projPos[1] then
			flightPath[1] = flightPath[1] - 20
		else
			flightPath[1] = flightPath[1] + 20
		end
		if launcherPos[3] < projPos[3] then
			flightPath[3] = flightPath[3] - 20
		else
			flightPath[3] = flightPath[3] + 20
		end


		LOG('DEBUG projectile pos ' .. projPos[1] .. ' ' .. projPos[2] .. ' ' .. projPos[3])
		LOG('DEBUG flightpath ' .. flightPath[1] .. ' ' .. flightPath[2] .. ' ' .. flightPath[3])
		LOG('DEBUG launcherpos ' .. launcherPos[1] .. ' ' .. launcherPos[2] .. ' ' .. launcherPos[3] .. ' w/flightpath height as cruise tgt')

		proj:SetLifetime(lifetime)
		proj:SetCollideSurface(true)
		
		proj:SetNewTargetGround(flightPath)
		if proj.MoveThread then
			KillThread(proj.MoveThread)
			proj.MoveThread = nil
			#print('Caught NUKE GUIDANCE THREAD')
		end
		
		proj:SetTurnRate(47.52)
		proj:TrackTarget(true)
		
		print('Boomerang: ascent phase')
		WaitSeconds(4)
		
		print('Boomerang: cruise phase, tgt height ' .. flightHeight)
		proj:SetNewTargetGround(launcherAbove)
		proj:SetTurnRate(47.52)
		proj:TrackTarget(true)
		proj:SetAcceleration(0)
		
		local finalApproach = false
		local redirectMaxTime = 80 -- after this many seconds of redirecting, force a terminal descent
		local redirectAtTime = GetGameTimeSeconds()
		local dist = 9999
		while not proj:BeenDestroyed() do
			projPos = proj:GetPosition()
			dist = VDist2(projPos[1], projPos[3], launcherAbove[1], launcherAbove[3])
			
			LOG('DEBUG nuke distance to target: ' .. tostring(dist))
			print('DEBUG nuke distance to target: ' .. tostring(dist))
			
			if proj.MoveThread then
				KillThread(proj.MoveThread)
				proj.MoveThread = nil
				#print('Caught NUKE GUIDANCE THREAD')
			end
			
			-- after redirectMaxTime seconds, force the missile to enter final approach
			if dist < 35 or GetGameTimeSeconds() > (redirectAtTime + redirectMaxTime) then
				finalApproach = true
				LOG('DEBUG final approach circumstances met')
				print('DEBUG final approach circumstances met')
			end
			if finalApproach == true and launcher ~= self then
				proj:SetNewTarget(launcher)
				proj:SetTurnRate(47.52)
			else
				proj:SetNewTargetGround(launcherAbove)
				proj:SetTurnRate(55)
			end
			WaitSeconds(0.25)
		end
	end,
}

TypeClass = PCB4302

