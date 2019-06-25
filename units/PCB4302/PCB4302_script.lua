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
local CAMEMPMissileWeapon = import('/lua/cybranweapons.lua').CAMEMPMissileWeapon
local EffectTemplate = import('/lua/EffectTemplates.lua')
local Entity = import('/lua/sim/Entity.lua').Entity
local GetRandomFloat = import('/lua/utilities.lua').GetRandomFloat

local StrategicMissileRedirect = Class(Entity)
{
	-- Override the normal tracking method
	WaitingState = State{
        OnCollisionCheck = function(self, other)
            #LOG('*DEBUG MISSILE REDIRECT COLLISION CHECK')
            if EntityCategoryContains(categories.STRATEGIC, other) -- Checks for nukes here
                        and other != self.EnemyProj and IsEnemy( self:GetArmy(), other:GetArmy() ) then
                self.Enemy = other:GetLauncher()
                self.EnemyProj = other
				
                ChangeState(self, self.RedirectingState)
            end
            return false
        end,
    },
	
	RedirectBeams = {'/effects/emitters/particle_cannon_beam_01_emit.bp', '/effects/emitters/particle_cannon_beam_02_emit.bp'},
    EndPointEffects = {'/effects/emitters/particle_cannon_end_01_emit.bp',},
    
    #AttachBone = function( AttachBone )
    #    self:AttachTo(spec.Owner, self.AttachBone)
    #end, 

    OnCreate = function(self, spec)
        Entity.OnCreate(self, spec)
        #LOG('*DEBUG MISSILEREDIRECT START BEING CREATED')
        self.Owner = spec.Owner
        self.Radius = spec.Radius
        self.RedirectRateOfFire = spec.RedirectRateOfFire or 1
        self:SetCollisionShape('Sphere', 0, 0, 0, self.Radius)
        self:SetDrawScale(self.Radius)
        self.AttachBone = spec.AttachBone
        self:AttachTo(spec.Owner, spec.AttachBone)
        ChangeState(self, self.WaitingState)
        #LOG('*DEBUG MISSILEREDIRECT DONE BEING CREATED')
    end,

    OnDestroy = function(self)
		if self.GuidanceThread then
			self.GuidanceThread:Destroy()
            self.GuidanceThread = nil
			
			self.EnemyProj:Destroy()
		end
	
		Entity.OnDestroy(self)
        ChangeState(self, self.DeadState)
    end,

    DeadState = State {
        Main = function(self)
        end,
    },

	RedirectingState = State{
		Main = function(self)
			if not self or self:BeenDestroyed() or
			   not self.EnemyProj or self.EnemyProj:BeenDestroyed() or
			   not self.Owner or self.Owner.Dead then
				if self then
					ChangeState(self, self.WaitingState)
				end

				return
			end
			
			-- create particles
			local activeBeams = {}
		
			for k, v in self.RedirectBeams do
				table.insert(activeBeams, AttachBeamEntityToEntity(self.EnemyProj, -1, self.Owner, self.AttachBone, self:GetArmy(), v))
			end
			#self.Trash:Add(activeBeams)

			if self.Enemy then
				-- Set collision to friends active so that when the missile reaches its source it can deal damage.
				self.EnemyProj.CollideFriendly = true
				self.EnemyProj.DamageData.DamageFriendly = true
				self.EnemyProj.DamageData.DamageSelf = true
				LOG(self.EnemyProj.DamageData)
			end

			if not self.EnemyProj:BeenDestroyed() then
				local proj = self.EnemyProj
				local launcher = self.Enemy
				
				-- Change the nuke to our side, so that our nukedef won't target it and the enemies will
				-- ChangeUnitArmy(proj, GetArmyBrain(self:GetArmy()):GetArmyIndex()) -- Only works for units, not projectiles

				if proj.MoveThread then
					KillThread(proj.MoveThread)
					proj.MoveThread = nil
				end
				
				proj:ForkThread(function()
					local projPos = proj:GetPosition()
					local launcherPos = launcher:GetPosition()
					local launcherAbove = launcherPos
					
					local flightHeight = 100
					
					-- configure the target points
					local flightPath = projPos
					flightPath[2] = GetSurfaceHeight(projPos[1], projPos[3]) + flightHeight
					launcherAbove[2] = GetSurfaceHeight(launcherPos[1], launcherPos[3]) + flightHeight
					
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

					proj:SetLifetime(120)
					proj:SetCollideSurface(true)
					
					proj:SetNewTargetGround(flightPath)
					if proj.MoveThread then
						KillThread(proj.MoveThread)
						proj.MoveThread = nil
						print('Caught NUKE GUIDANCE THREAD')
					end
					
					proj:SetTurnRate(47.52)
					proj:TrackTarget(true)
					
					print('Boomerang: ascent phase')
					WaitSeconds(4)
					
					
					print('Boomerang: cruise phase, tgt height ' .. flightHeight)
					proj:SetNewTargetGround(launcherAbove)
					proj:SetTurnRate(47.52)
					proj:TrackTarget(true)
					
					while not proj:BeenDestroyed() do
						
						if proj.MoveThread then
							KillThread(proj.MoveThread)
							proj.MoveThread = nil
							print('Caught NUKE GUIDANCE THREAD')
						end
						
						if proj:GetDistanceToTarget() < 32 then
							proj:SetNewTargetGround(launcherPos)
							WaitSeconds(1)
							proj:SetTurnRate(47.52)
						else
							proj:SetNewTargetGround(launcherAbove)
							WaitSeconds(0.25)
							proj:SetTurnRate(55)
						end
					end
				end)
			end

			WaitSeconds(1 / self.RedirectRateOfFire)
			-- make sure we release beams we own
			for k, v in activeBeams do
				v:Destroy()
			end

			ChangeState(self, self.WaitingState)
		end,

		OnCollisionCheck = function(self, other)
			return false
		end,
	},
}

PCB4302 = Class(CStructureUnit) {

    OnStopBeingBuilt = function(self,builder,layer)
        CStructureUnit.OnStopBeingBuilt(self,builder,layer)
        local bp = self:GetBlueprint().Defense.AntiNuke
        local antiMissile = StrategicMissileRedirect {
            Owner = self,
            Radius = bp.Radius,
            AttachBone = bp.AttachBone,
            RedirectRateOfFire = bp.RedirectRateOfFire
        }
        self.Trash:Add(antiMissile)
		self:SetConsumptionPerSecondEnergy(self:GetBlueprint().Economy.MaintenanceConsumptionPerSecondEnergy)
        self.UnitComplete = true
		
		#LOG('Entity members:')
		#for key,value in pairs(Entity) do
		#	LOG("found member " .. key);
		#end
    end,
}

TypeClass = PCB4302

-- wseoijhsdihjbwdiu342895r98w 9o88942890r 908fyu238452u0r w980fyuwe08 5 a\efafafadfafafafas
