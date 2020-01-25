
-- Copyright 2020 David Mentler


-- Enums

WL_NONE		= 0
WL_FEET		= 1
WL_WAIST	= 2
WL_EYES		= 3

-- Localized for fast access

local ZERO = Vector()

local bit_bnot		= bit.bnot
local bit_band		= bit.band
local bit_bor		= bit.bor
local bit_bxor		= bit.bxor

local math_min			= math.min
local math_max			= math.max
local math_sqrt			= math.sqrt

local math_Clamp			= math.Clamp

local util_TraceHull		= util.TraceHull
local util_PointContents	= util.PointContents



-- Vector metatable extensions
do
	local meta = FindMetaTable( "Vector" )
	
	function meta:Copy()
		return Vector( self.x, self.y, self.z )
	end
	
	function meta:Size( len )
		self:Normalize()
		
		self.x = self.x * len
		self.y = self.y * len
		self.z = self.z * len
		
		return self
	end
end

-- Player metatable extensions
do
	
	local function Accessor( meta, varname, name, def )
		meta[ "Set" .. name ] = function( self, var ) 		 self[varname] = var  end
		meta[ "Get" .. name ] = function( self		) return self[varname] or def end
	end
	
	local meta = FindMetaTable( "Player" )
	
	function meta:GetPlayerSolidMask()
		return MASK_PLAYERSOLID
	end
	
	Accessor( meta, "m_WaterType",  "WaterType" )
	Accessor( meta, "m_WaterLevel", "WaterLevel" )
	
	Accessor( meta, "m_BaseVelocity",	 "BaseVelocity" )
	Accessor( meta, "m_SurfaceFriction", "SurfaceFriction" )
	
	function meta:InWater()	
		return self.m_WaterLevel > WL_NONE 
	end
	
	function meta:AdjustBaseVelocity( delta )
		self:SetBaseVelocity( self:GetBaseVelocity() + delta )
	end
	
	function meta:GetGravityFactor()
		local grav = self:GetGravity()
		
		return grav == 0 and 1 or grav
	end

	-- Move state flags
	Accessor( meta, "m_Ducked",		"Ducked" )			-- This replaces the FL_DUCKING engine flag
	Accessor( meta, "m_Ducking",	"DuckingState" )
	
	-- Timers used while moving

	Accessor( meta, "m_DuckTime", 		"DuckTime" )
	Accessor( meta, "m_JumpTime",		"JumpTime" )

	Accessor( meta, "m_DuckJumpTime", 	"DuckJumpTime"  )
	Accessor( meta, "m_WaterJumpTime",	"WaterJumpTime" )
	
	Accessor( meta, "m_SwimSoundTime",	"SwimSoundTime" )

	function meta:ReduceMoveTimers()
		local delta = 1000 * FrameTime()
		
		self.m_DuckTime		 = math_max( self.m_DuckTime - delta, 0 )
		self.m_JumpTime		 = math_max( self.m_JumpTime - delta, 0 )
		
		self.m_DuckJumpTime	 = math_max( self.m_DuckJumpTime  - delta, 0 )
		self.m_SwimSoundTime = math_max( self.m_SwimSoundTime - delta, 0 )
	end
	
end

-- Utility functions

local function isFlagSet( num, mask )
	return bit_band( num, mask ) != 0
end

local function isWater( mask )
	return bit_band( mask, MASK_WATER ) != 0
end

local function VectorMA( add, scale, vec )
	return add + vec:GetNormalized() * scale
end

-- Shared variables for easier access

local mv_Player
local mv_Object

local mv_Origin
local mv_Velocity

local mv_FrameTime

local mv_Buttons
local mv_OldButtons

-- Overridable functions

local function GetPlayerMins( ducked )
	return mv_Player:OBBMins()
end

local function GetPlayerMaxs( ducked )

	-- If not speficied, default to current state
	if ( ducked == nil ) then
		ducked = mv_Player.m_Ducked
	end

	local maxs = Vector( 16, 16, 72 ) -- TODO: Why hardcoded?! :(
	
	if ( ducked ) then
		maxs.z = 36
	end
	
	return maxs
end

local tdata = {}

local function TracePlayerBBox( start, endpos, mask, group )
	tdata.start		= start
	tdata.endpos	= endpos
	
	tdata.mask		= mask	or mv_Player:GetPlayerSolidMask()
	
	tdata.filter	= mv_Player
		
	tdata.mins		= GetPlayerMins()
	tdata.maxs		= GetPlayerMaxs()
	
	-- Ignore world and walls?
	local ground = mv_Player:GetGroundEntity()
	
	if ( IsValid( ground ) and ground:GetModel():match( "plate" ) ) then
		tdata.ignoreworld = true
	else
		tdata.ignoreworld = false
	end
	
	return util_TraceHull( tdata )
end

local function TryTouchGround( start, endpos, mask, group )
	return TracePlayerBBox( start, endpos, mask, group )
end

local function CanAccelerate()
	return true
end

local function CanUnDuck()
	local newOrigin = mv_Origin

	if ( mv_Player:GetGroundEntity() != NULL ) then
		newOrigin = newOrigin + (GetPlayerMins( true ) - GetPlayerMins( false ))
	else
	
		-- If in air while letting go of crouch, make sure we can offset the origin to
		-- make up for crouching
		local hullNormal = GetPlayerMaxs( false ) - GetPlayerMins( false )
		local hullDuck 	 = GetPlayerMaxs( true )  - GetPlayerMins( true )
		
		local delta = hullNormal - hullDuck
		
		newOrigin = newOrigin - delta
	end
	
	-- Check if there is space to stand up (fake that we are standing)
	mv_Player.m_Ducked = false
	local trace = TracePlayerBBox( newOrigin, newOrigin )
	mv_Player.m_Ducked = true
	
	return !trace.StartSolid and trace.Fraction == 1
end

local function GetCurrentGravity()
	return 600
end

local function GetAirSpeedCap()
	return 30
end

-- Movesystem methods

local function SimpleSpline( value )
	local squared = value * value
	
	return ( 3 * squared - 2 * squared * value )
end

local function ClipVelocity( vector, normal, bounce )

	-- Determine how far to slide along the given plane, based off the direction
	local backoff = vector:Dot( normal ) * bounce
	
	vector = vector - normal*backoff
	
	-- Iterate once to make sure we are not moving trough the plane
	local adjust = vector:Dot( normal )
	
	if ( adjust < 0 ) then
		vector = vector - normal * adjust
	end
	
	return vector
end

local function ValidateVelocity()

	-- Make sure none of the compontents exceed sv_maxvelocity
	local sv_maxvelocity = 3500		-- TODO: Make this a convar
	
	mv_Velocity.x = math_Clamp( mv_Velocity.x, -sv_maxvelocity, sv_maxvelocity )
	mv_Velocity.y = math_Clamp( mv_Velocity.y, -sv_maxvelocity, sv_maxvelocity )
	mv_Velocity.z = math_Clamp( mv_Velocity.z, -sv_maxvelocity, sv_maxvelocity )

end

local function ApplyBaseVelocity()
	mv_Velocity = mv_Velocity + mv_Player:GetBaseVelocity()
end

local function RemoveBaseVelocity()
	mv_Velocity = mv_Velocity - mv_Player:GetBaseVelocity()
end


local function Friction()

	-- Calculate speed
	local speed = mv_Velocity:Length()
	
	-- Do not care to apply on low speed
	if ( speed < 0.1 ) then
		return
	end

	-- Apply ground friction
	local drop = 0
	
	if ( mv_Player:GetGroundEntity() != NULL ) then
		local sv_friction  = 8	-- TODO: Make these a convar
		local sv_stopspeed = 10
		
		local friction  = sv_friction * mv_Player.m_SurfaceFriction
		local control	= sv_stopspeed > speed and sv_stopspeed or speed
		
		drop = math_max( control * friction * mv_FrameTime, 0 )
	end
	
	-- Scale the velocity
	local newspeed = speed - drop
	
	if ( newspeed != speed ) then
		mv_Velocity:Size( newspeed )
	end
end

local function AcceleratePlayer( inAir )

	-- Determine movement angles
	local moveAngs	= mv_Object:GetMoveAngles()
	
	local vForward	= moveAngs:Forward()
	local vRight	= moveAngs:Right()
	
	-- Zero Z components
	vForward.z	= 0
	vRight.z	= 0
	
	-- Determine velocity
	local wishvel	= mv_Object:GetForwardSpeed() * vForward 
					+ mv_Object:GetSideSpeed()    * vRight
					
	local wishdir	= wishvel:GetNormalized()
	local wishspeed	= wishvel:Length()
	
	-- Clamp to max speed
	local sMax = mv_Object:GetMaxSpeed()
	
	if ( wishspeed != 0 and wishspeed > sMax ) then
		wishvel   = wishvel * (sMax/wishspeed)
		wishspeed = sMax
	end
	
	
	-- Reduce added speed by the amount of veer
	local addspeed = wishspeed - mv_Velocity:DotProduct( wishdir )
	
	-- If not going to add any speed then we are done
	if ( addspeed <= 0 ) then
		return
	end
	
	-- Do inAir specific adjusting
	local factor = 0
	
	if ( inAir ) then	
		-- Cap air speed
		wishspeed = math_min( wishspeed, GetAirSpeedCap() )
		
		factor = 10	-- sv_airaccelerate	TODO: Make this a convar
	else
		factor = 10	-- sv_accelerate 	TODO: Make this a convar
	end
	
	-- Determine amount of acceleration
	local accelspeed = wishspeed * mv_Player.m_SurfaceFriction * mv_FrameTime * factor
	
	-- Cap at addspeed
	accelspeed = math_min( accelspeed, addspeed )
	
	-- Adjust velocity
	mv_Velocity = mv_Velocity + accelspeed * wishdir
	
end

local function SetGroundEntity( ground )
	mv_Player:SetGroundEntity( ground )
end

local function CheckWater()

	-- Pick a spot just above the players feet
	local mins = GetPlayerMins()
	local maxs = GetPlayerMaxs()
	
	local spot = mv_Origin + ( mins + maxs ) /2
		spot.z = mv_Origin.z + mins.z +1
	
	-- Assume that we are not in water, at all
	mv_Player:SetWaterType( CONTENTS_EMPTY )
	mv_Player:SetWaterLevel( WL_NONE )
	
	-- Query point contents
	local flags = util_PointContents( spot )
	
	-- In water?
	if isWater( flags ) then
		
		-- Set water type/depth
		mv_Player:SetWaterType( flags )
		mv_Player:SetWaterLevel( WL_FEET )
		
		-- Now check the point that is at the hulls midpoint
		spot.z = mv_Origin.z + ( mins.z + maxs.z ) /2
		
		if isWater( util_PointContents( spot ) ) then
			
			-- Set a higher water level, and query against the eye position
			mv_Player:SetWaterLevel( WL_WAIST )
			
			spot = mv_Origin + mv_Player:GetViewOffset()
			
			if isWater( util_PointContents( spot ) ) then
				
				-- 'Fully' submerged
				mv_Player:SetWaterLevel( WL_EYES )
				
			end
		end
	
		-- Adjust velocity based on fluid current
		local current = bit_band( flags, MASK_CURRENT )
		
		if ( current != 0 ) then
			local force = Vector()
		
			-- Figure out current direction
			if bit_band( current, CONTENTS_CURRENT_0   ) then force.x =  1	end
			if bit_band( current, CONTENTS_CURRENT_90  ) then force.y =  1	end
			if bit_band( current, CONTENTS_CURRENT_180 ) then force.x = -1	end
			if bit_band( current, CONTENTS_CURRENT_270 ) then force.y = -1	end
			
			if bit_band( current, CONTENTS_CURRENT_UP   ) then force.z =  1	end
			if bit_band( current, CONTENTS_CURRENT_DOWN ) then force.z = -1	end

			-- Scale force, depending on depth
			mv_Player:AdjustBaseVelocity( force:Size( mv_Player:GetWaterLevel() *50 ) )
		end
		
	end
	
	return mv_Player:InWater()
end

local function CategorizePosition()
		
	-- Reset surface friction
	mv_Player.m_SurfaceFriction = 1

	-- Update this before anything else, as we may get stuck 
	-- on the bottom of the water otherwise
	CheckWater()
	
	-- Observers have no ground entity
	if ( mv_Player:GetObserverMode() != OBS_MODE_NONE ) then
		return
	end
	
	-- Check Z axis velocity if we are moving upwards, then we have no ground
	local velZ = mv_Velocity.z
	
	local movingUp 			= velZ > 0
	local movingUpRapidly	= velZ > 140	-- NON_JUMP_VELOCITY
		
	if ( movingUpRapidly || ( movingUp and mv_Player:GetMoveType() == MOVETYPE_LADDER ) ) then
		SetGroundEntity( NULL )
	else
	
		-- Try and move down
		local point = mv_Origin + Vector( 0, 0, -2 )
		
		local trace = TryTouchGround( mv_Origin, point )
		
		-- Not on ground, or at a too steep plane
		if ( trace.Entity == NULL or trace.HitNormal.z < 0.7 ) then
	
			-- Test quadrants, to see if one of them has a shllower slope to stand on
			-- TODO: TryTouchGroundInQuadrants
			
			SetGroundEntity( NULL )
			
			-- Lower surface friction
			if ( mv_Velocity.z > 0 and mv_Player:GetMoveType() != MOVETYPE_NOCLIP ) then
				mv_Player.m_SurfaceFriction = 0.25
			end
		else	
			SetGroundEntity( trace.Entity )
		end
		
	end

end



local function CheckJumpButton()

	-- TODO: Ply dead, water jumping

	-- TODO: In water, jumping out
	
	-- See if waterjumping, if so then decrement time and return
	-- TODO: This actually never happens? Even the SDK has a bug here
	if ( mv_Player.m_WaterJumpTime > 0 ) then	
		mv_Player.m_WaterJumpTime = mv_Player.m_WaterJumpTime - mv_FrameTime * 1000
		
		return false
	end
	
	-- If we are in the water most of the way
	if ( mv_Player:GetWaterLevel() > WL_WAIST ) then
		
		-- Swimming, not jumping
		SetGroundEntity( NULL )
		
		-- Apply velocity based on water contents
		local water = mv_Player:GetWaterType()
		
		if ( water == CONTENTS_WATER ) then
			mv_Velocity.z = 100
		elseif ( water == CONTENTS_SLIME ) then
			mv_Velocity.z = 80
		end
		
		-- Play swimming sound
		if ( mv_Player.SwimSoundTime <= 0 ) then
			mv_Player.SwimSoundTime = 1000
			
			-- TODO: Play sound
		end
		
		return false
	end
	
	-- No more effect
	if ( mv_Player:GetGroundEntity() == NULL ) then
		mv_OldButtons = bit_bor( mv_OldButtons, IN_JUMP )
		
		return false
	end
	
	-- Don't pogo stick
	if ( isFlagSet( mv_OldButtons, IN_JUMP ) ) then
		return false
	end
	
	-- Cannot jump in the duck transition
	if ( mv_Player.m_Ducking and mv_Player.m_Ducked ) then
		return false
	end
	
	-- Still updating the eye position
	if ( mv_Player.m_DuckJumpTime > 0 ) then
		return false
	end
	
	-- In the air now
	SetGroundEntity( NULL )
	
	-- TODO: Step sound
	mv_Player:SetAnimation( PLAYER_JUMP )
	
	local groundFactor = 1
	
	-- TODO: Surface data
	
--	local accel = math_sqrt( 2 * GetCurrentGravity() * ( 21 ) ) -- GAMEMOVEMENT_JUMP_HEIGHT
	local accel = mv_Player:GetJumpPower()
	
	-- Accelerate upward
	local startZ = mv_Velocity.z
	
	if ( mv_Player.m_Ducking or mv_Player.m_Ducked ) then
		mv_Velocity.z = 				groundFactor * accel
	else
		mv_Velocity.z = mv_Velocity.z + groundFactor * accel
	end
	
	mv_Player.m_JumpTime = 510		-- GAMEMOVEMENT_JUMP_TIME
	
	-- TODO: Gravity, jumptime
	
	-- Flag that we jumped
	mv_OldButtons = bit_bor( mv_OldButtons, IN_JUMP )
	return true
end



-- Position adjusting code

local function StayOnGround()

	-- Offset positions a bit, so it fits the player anatomy
	local start = mv_Origin:Copy()
	local feet	= mv_Origin:Copy()

	start.z = start.z + 2
	feet.z	= feet.z  - mv_Player:GetStepSize()
	
	-- See how far up we can go without getting stuck
	local trace = TracePlayerBBox( mv_Origin, start )
		start = trace.HitPos
	
	-- Now trace down from a known safe position
	local trace = TracePlayerBBox( start, feet )
	
	if ( trace.Fraction > 0 and		-- must go somewhere
		 trace.Fraction < 1 and		-- must hit something
		 !trace.StartSolid	and		-- can't be embeeded in solid
		 trace.HitNormal.z > 0.7	-- can't hit a steep slope we can't stand on anyway
		) then
		
		-- Adjust position
		mv_Origin = trace.HitPos
	end

end

local function TryPlayerMove( origin, velocity )
	local maxBumps 	= 4	

	local mv_Origin		= origin:Copy()
	local mv_Velocity 	= velocity:Copy()
	
	local timeLeft	= mv_FrameTime

	local cPlanes	= {}
	local cPlaneNum	= 0
	
	local allFrac = 0
	
	for bump = 1, maxBumps do
		
		-- Already stopped
		if ( mv_Velocity:LengthSqr() == 0 ) then
			break
		end
	
		-- Assume we can reach the target in one step
		local target = mv_Origin + mv_Velocity * timeLeft
	
		-- Check how far it goes
		local trace = TracePlayerBBox( mv_Origin, target )
		
		-- Started in solid, we are stuck there. Zero the velocity and stop bumping
		if ( trace.StartSolid ) then
			mv_Velocity = ZERO
			break
		end
	
		-- If we moved some portion of the distance, add it to the fraction,
		-- and reset the plane counter
		if ( trace.Fraction > 0 ) then
			
			-- TODO: The SDK here refers to a bug, where the player might end up stuck in a displacement.
			--			maybe I should implement that? 
		
			mv_Origin = trace.HitPos
			cPlaneNum = 0
		end
		
		-- Record progress and decrease timeLeft
		allFrac  = allFrac + trace.Fraction
		timeLeft = timeLeft * ( 1 - trace.Fraction )
	
		-- Managed to move in one step, stop bumping
		if ( trace.Fraction == 1 ) then
			break
		end
	
		-- TODO: Save the entity that blocked us
		-- TODO: What is blocking? blocked flags
	
	
		-- Add blocking plane to the plane list
		cPlaneNum = cPlaneNum +1
		cPlanes[cPlaneNum] = trace.HitNormal
	
		-- Modify velocity so it does not intersect with each plane
		local pIndex = 1
		local cIndex = 1
		
		while ( pIndex <= cPlaneNum ) do
			mv_Velocity = ClipVelocity( mv_Velocity, cPlanes[pIndex], 1 )
		
			-- Check if we are now moving against an other plane
			cIndex = 1
			
			while ( cIndex <= cPlaneNum ) do	
				if ( mv_Velocity:Dot( cPlanes[cIndex] ) < 0 ) then
					-- We are going against this plane, uh oh
					break
				end
				
				cIndex = cIndex +1
			end
			
			-- Did not have to clip anything, so we are fine
			if ( cIndex > cPlaneNum ) then
				break
			end
			
			pIndex = pIndex +1
		end
		
		-- Check if clipping did not work out a compatible direction
		if ( pIndex > cPlaneNum +1 ) then
		
			if ( cPlaneNum != 2 ) then	
				-- Can't work it out, stuck
				mv_Velocity = ZERO
				break	
			end
		
			-- Only two planes, move along the crease
			local dir = cPlanes[1]:Cross( cPlanes[2] )
				dir:Normalize()
		
			mv_Velocity = dir * dir:Dot( mv_Velocity )
		end
		
		-- If the new velocity is against the original
		if( mv_Velocity:Dot( velocity ) < 0 ) then
			
			-- Stop to avoid oscillation
			mv_Velocity = ZERO
			break
		end
		
	end

	-- Did not move even a little?
	if ( allFrac <= 0 ) then
		mv_Velocity = ZERO
	end
	
	-- TODO: Check if the player slammed into a wall
	
	return mv_Origin, mv_Velocity
end


-- Duck, and all of its bullshit

local function SetDuckedEyeOffset( frac )
	local normal	= mv_Player:GetViewOffset()
	local ducked	= mv_Player:GetViewOffsetDucked()
	
	local delta		= normal - ducked

	mv_Player:SetCurrentViewOffset( normal - delta * frac )
end

local function FixPlayerCrouchStuck( upward )
	
	-- First check if we are even stuck at all
	local trace = TracePlayerBBox( mv_Origin, mv_Origin )
	
	if ( trace.Entity == NULL ) then
		return
	end
	
	-- Try to find a safe position to unduck
	local origin = mv_Origin:Copy()
	
	-- Do attempts in a 36 unit tall area
	for index = 1, 36 do
		origin.z = origin.z + ( upward and 1 or -1 )
	
		local trace = TracePlayerBBox( origin, origin )
	
		-- Not stuck here! Set as new origin and finish
		if ( trace.Entity == NULL ) then
			mv_Origin = origin
			return
		end
	end
	
end

local function FinishDuck()

	-- Change view
	SetDuckedEyeOffset( 1 )
	
	-- Fudge for collision bug
	if ( mv_Player:GetGroundEntity() != NULL ) then
		-- TODO: This is always zero?
		
		mv_Origin = mv_Origin + ( GetPlayerMins( true ) - GetPlayerMins( false ) )
	else
	
		-- Offset origin by the duck distance
		local normalHull = GetPlayerMaxs( false ) - GetPlayerMins( false )
		local duckHull	 = GetPlayerMaxs( true )	 - GetPlayerMins( true )
	
		local delta	= normalHull - duckHull
		
		mv_Origin = mv_Origin + delta
		
	end
	
	-- Set flags, and change view offset
	mv_Player:AddFlags( FL_DUCKING )
	
	mv_Player.m_Ducked	= true
	mv_Player.m_Ducking	= false

	-- Fix getting stuck
	FixPlayerCrouchStuck( true )
	
	-- Recategorize position, since the origin might have changed
	CategorizePosition()
	
end

local function FinishUnDuck()

	-- Change view
	SetDuckedEyeOffset( 0 )
	
	-- Fudge for collision bug
	if ( mv_Player:GetGroundEntity() != NULL ) then
		-- TODO: This is always zero?
		
		mv_Origin = mv_Origin + ( GetPlayerMins( true ) - GetPlayerMins( false ) )
	else
	
		-- Offset origin by the duck distance
		local normalHull = GetPlayerMaxs( false ) - GetPlayerMins( false )
		local duckHull	 = GetPlayerMaxs( true )  - GetPlayerMins( true )
	
		local delta	= normalHull - duckHull
		
		mv_Origin = mv_Origin - delta
		
	end


	-- Set flags, and change view offset
	mv_Player:RemoveFlags( FL_DUCKING )
	
	mv_Player.m_Ducked	= false
	mv_Player.m_Ducking	= false
	
	FixPlayerCrouchStuck()
	
	-- Recategorize position, since the origin might have changed
	CategorizePosition()
	
end

local function HandleDuck()
	
	-- Check buttons
	local buttonDelta	= bit_bxor( mv_OldButtons, mv_Buttons )
	
	local buttonsUp		= bit_band( buttonDelta, mv_OldButtons )
	local buttonsDown	= bit_band( buttonDelta, mv_Buttons )
	
	-- Check to see if we are in the air
	local inAir		= mv_Player:GetGroundEntity() == NULL
	local inDuck	= mv_Player.m_Ducked
	
	local inJump		= mv_Player.m_JumpTime 		> 0
	local inDuckJump	= mv_Player.m_DuckJumpTime  > 0
	
	-- Update buttons first
	if ( isFlagSet( mv_Buttons, IN_DUCK ) ) then
		mv_OldButtons = bit_bor( mv_OldButtons, IN_DUCK )
	end
	
	-- TODO: Crop speed of ducking players
	
	-- If the player is holding down the duck button, the player is in duck transition, ducking, or duck-jumping.
	if ( isFlagSet( mv_Buttons, IN_DUCK ) or mv_Player.m_Ducking or inDuck or inJump ) then
				
		-- Duck
		if ( isFlagSet( mv_Buttons, IN_DUCK ) or inJump ) then
			
			-- Have the duck button pressed, but the player currently isn't in the duck position.
			if ( isFlagSet( buttonsDown, IN_DUCK ) and !inDuck and !inDuckJump ) then
				mv_Player.m_DuckTime = 1000 -- GAMEMOVEMENT_DUCK_TIME
				mv_Player.m_Ducking	 = true
			end
		
			-- The player is in duck transition and not duck-jumping.
			if ( mv_Player.m_Ducking and !inDuckJump ) then
				local timeleft = math_max( 0, 1000 - mv_Player.m_DuckTime )
				
				if ( timeleft > 200 or inDuck or inAir ) then	-- TIME_TO_DUCK
					FinishDuck()
				else
					-- Calc parametric time
					SetDuckedEyeOffset( SimpleSpline( timeleft /200 ) )	-- TIME_TO_DUCK
				end
			end
		
			-- Jumping
			if ( inJump ) then
				
				-- TODO: WTF is an UnDuckJump ? Only seems to occur when maxclients == 1
				
			end
		
		else	-- Unduck (or attempt to)
			
			-- TODO: WTF is an UnDuckJump ? Only seems to occur when maxclients == 1
			
			-- In duck jump
			if ( mv_Player.m_DuckJumpTime > 0 ) then
				return
			end
			
			-- Try to unduck
			if ( inAir or mv_Player.m_Ducking or mv_Player.m_Ducked ) then
		
				-- The duck button is released, but we are not in "duck" and we are not in the air - unduck transition
				if ( isFlagSet( buttonsUp, IN_DUCK ) ) then
					
					if ( inDuck and !inJump ) then	
						mv_Player.m_DuckTime = 1000 	-- GAMEMOVEMENT_DUCK_TIME
					else 
			
						-- Invert time if release before fully ducked!
						if ( mv_Player.m_Ducking and !inDuck ) then
						
							local elapsed = 1000 - mv_Player.m_DuckTime	-- GAMEMOVEMENT_DUCK_TIME
						
							local frac   = elapsed / 200	-- TIME_TO_DUCK
							local remain = frac * 200		-- TIME_TO_UNDUCK
							
							mv_Player.m_DuckTime = 1000 - 200 + remain	-- GAMEMOVEMENT_DUCK_TIME - UNDUCK_MILISEC + remairingUnduckMiliseconds
						
						end
					
					end
				end
			
				-- Check to see if we are allowed to unduck
				if ( CanUnDuck() ) then
				
					if ( mv_Player.m_Ducking or mv_Player.m_Ducked ) then
						local timeleft = math_max( 0, 1000 - mv_Player.m_DuckTime )
				
						if ( timeleft > 200 or ( inAir and !inJump ) ) then	-- TIME_TO_UNDUCK
							FinishUnDuck()
						else
							SetDuckedEyeOffset( SimpleSpline( 1 - timeleft /200 ) )	-- TIME_TO_UNDUCK
							mv_Player.m_Ducking = true
						end
					end
				
				else
					
					-- Still under something that prevents us from unducking, reset the timer
					-- to make sure we unduck once we exit the tunnel/whatever was blocking us
					if ( mv_Player.m_DuckTime != 1000 ) then
						SetDuckedEyeOffset( 1 )
					
						mv_Player.m_DuckTime	= 1000
						mv_Player.m_Ducked		= true
						mv_Player.m_Ducking		= false
						
						mv_Player:AddFlags( FL_DUCKING )
					end
					
				end
				
			end
			
		end
	
	end
	
end


-- Movement nature

local function StepMove()

	-- Try sliding both on ground and up by 16 units,
	--  take the one that got farther
	
	-- Slide down
	local downOrigin, downVelocity = TryPlayerMove( mv_Origin, mv_Velocity )
	
	-- Move up by the step height, and slide again
	local stair = mv_Origin:Copy()
		stair.z = stair.z + mv_Player:GetStepSize()
	
	local trace = TracePlayerBBox( mv_Origin, stair )
	
	if ( !trace.StartSolid ) then	
		stair = trace.HitPos
	end
	
	-- Slide up
	local upOrigin, upVelocity = TryPlayerMove( stair, mv_Velocity )

	-- Move down a stair (attempt to)
	stair   = upOrigin:Copy()
	stair.z = stair.z - mv_Player:GetStepSize()
	
	local trace = TracePlayerBBox( upOrigin, stair )
	
	-- If we are not on the ground, then use the slide over this attempt
	if ( trace.HitNormal.z < 0.7 ) then	
		mv_Origin	= downOrigin
		mv_Velocity	= downVelocity

		return
	end
	
	-- Compare the two distances
	local distDown	= ( mv_Origin - downOrigin ):LengthSqr()
	local distUp	= ( mv_Origin - upOrigin   ):LengthSqr()
		
	if ( distDown >= distUp ) then		
		mv_Origin	= downOrigin
		mv_Velocity	= downVelocity
	else			
		mv_Origin	= upOrigin
		mv_Velocity	= upVelocity
	end
	
end

local function WalkMove()
	
	-- Process wished velocity, and accelerate
	AcceleratePlayer( false )
	
	-- Add in any base velocity now
	ApplyBaseVelocity()
	
	-- Check minimal speed
	local speed = mv_Velocity:Length()
	
	if ( speed < 1 ) then
		mv_Velocity = ZERO		
		return
	end
	
	-- First just try moving to the destination
	local dest = mv_Origin + mv_Velocity * mv_FrameTime

	local trace = TracePlayerBBox( mv_Origin, dest )

	-- If made it all the way, then copy the trace end as player position
	if ( trace.Fraction == 1 ) then
		mv_Origin = trace.HitPos
		
		-- Remove base velocity, then do a ground check
		RemoveBaseVelocity()
		StayOnGround()
		return
	end

	-- Do step move (move up steps, or slide)
	StepMove()
	
	-- Remove base velocity, then do a ground check
	RemoveBaseVelocity()
	StayOnGround()
end

local function AirMove()

	-- Process wished velocity, and accelerate
	AcceleratePlayer( true )
	
	-- Add in any base velocity now
	ApplyBaseVelocity()
	
	-- Just let the player fly
	mv_Origin, mv_Velocity = TryPlayerMove( mv_Origin, mv_Velocity )
	
end

local function WaterMove()

end

local function FullWalkMove()
		
	-- Start by adding gravity
	if ( !CheckWater() ) then
		
		-- TODO: Pull out base velocity?
		mv_Velocity.z = mv_Velocity.z - GetCurrentGravity() * mv_Player:GetGravityFactor() * 0.5 * mv_FrameTime
		
	end
	
	-- If we are swimming in the water, see if we are nudging against a place we can jump out
	-- of, and if so, start a jump
	if ( mv_Player.m_WaterLevel >= WL_WAIST ) then
	
		if ( mv_Player.m_WaterLevel == WL_WAIST ) then
			-- TODO: CheckWaterJump
		end
	
		-- If we are falling down, then we are no longer trying to jump out of the water
		if ( mv_Velocity.z < 0 ) then
			mv_Player.m_WaterJumpTime = 0
		end
		
		-- Check jump
		if ( isFlagSet( mv_Buttons, IN_JUMP ) ) then
			CheckJumpButton()	
		end
		
		-- Perform regular water movement
		WaterMove()
		
		-- Redetermine position vars
		CategorizePosition()
		
		-- If we are on the ground, then no downward velocity
		if ( mv_Player:GetGroundEntity() != NULL ) then
			mv_Velocity.z = 0
		end
	else
	
		-- Was the jump button pressed?
		if ( isFlagSet( mv_Buttons, IN_JUMP ) ) then
			CheckJumpButton()	
		end

		-- Friction should be handled before any base velocity is added
		if ( mv_Player:GetGroundEntity() != NULL ) then
			mv_Velocity.z = 0
		
			Friction()
		end

		ValidateVelocity()
		
		-- Move!
		if ( mv_Player:GetGroundEntity() != NULL ) then
			WalkMove()
		else
			AirMove()
		end

		-- Redetermine position vars		
		CategorizePosition()
		ValidateVelocity()

		-- If we are on the ground, then no downward velocity
		if ( mv_Player:GetGroundEntity() != NULL ) then
			mv_Velocity.z = 0		
		else
			
			mv_Velocity.z = mv_Velocity.z - GetCurrentGravity() * mv_Player:GetGravityFactor() * 0.5 * mv_FrameTime
			
		end
		
	end
end


AddCSLuaFile()

print( "--- Movesystem Reloaded --" )

hook.Add( "Move", "SourceMovesystemOverride", function( ply, mv )
	
	if true then
		return	-- Yeah, do nothing for the time being
	end
	
	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		debugoverlay.Cross( mv:GetOrigin(), 4, 4 )
	
		if !ply.m_DuckTime then
			-- Init move variables
			ply.m_SurfaceFriction	= 1

			ply.m_Ducked	= false
			ply.m_Ducking	= false
			
			ply.m_DuckTime	= 0
			ply.m_JumpTime	= 0
			
			ply.m_DuckJumpTime	= 0
			ply.m_WaterJumpTime	= 0
			
			ply.m_SwimSoundTime	= 0
			ply.m_ViewOffset = Vector()

		
			ply:SetBaseVelocity( Vector( 0, 0, 0 ) )
		end
	
		mv_Player	= ply
		mv_Object	= mv

		mv_Origin	= mv:GetOrigin()
		mv_Velocity	= mv:GetVelocity()

		mv_FrameTime	= FrameTime()
		
		mv_Buttons		= mv:GetButtons()
		mv_OldButtons	= mv:GetOldButtons()
		
		ply:ReduceMoveTimers()
			
		HandleDuck()
		FullWalkMove()
	
		mv:SetVelocity( mv_Velocity )
		mv:SetOrigin( mv_Origin )

		mv:SetButtons( mv_Buttons )
		mv:SetOldButtons( mv_OldButtons )
			
		return true
	end	
end )
