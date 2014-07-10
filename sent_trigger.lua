
-- Copyright 2014 David Mentler


AddCSLuaFile()
 
DEFINE_BASECLASS( "base_anim" )
 
ENT.Spawnable   = false
ENT.AdminOnly   = false
 
function ENT:Initialize()
 
	if ( SERVER ) then
		self:SetModel( "models/hunter/blocks/cube2x2x2.mdl" )
	
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
		
		self:SetNotSolid( true )
		self:SetTrigger( true )
	end

end
 
