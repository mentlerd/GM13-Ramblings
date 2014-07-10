
-- Copyright 2014 David Mentler

AddCSLuaFile()
 
DEFINE_BASECLASS( "base_anim" )
 
ENT.PrintName   = "Illusion"
ENT.Author      = "MDave"

ENT.Category    = "Dev Stuff"
 
ENT.Spawnable   = true
ENT.AdminOnly   = false
 
ENT.RenderGroup = RENDERGROUP_TRANSALPHA
 
function ENT:SpawnFunction( ply, tr, ClassName )
	if ( not tr.Hit ) then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 10;

	local ent = ents.Create( ClassName )
		ent:SetPos( SpawnPos )
		ent:Spawn()

	return ent
end

function ENT:Initialize()
 
	if ( SERVER ) then
	--	self:SetModel( "models/hunter/blocks/cube2x2x025.mdl" )

		self:SetModel( "models/hunter/blocks/cube2x2x025.mdl" )
	
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
		
		if !IsValid( g_Illusion ) then
			g_Illusion = ents.Create( "prop_physics" )
			
			g_Illusion:SetModel( "models/hunter/misc/lift2x2.mdl" )	
			g_Illusion:Spawn()
		
			g_Illusion:DropToFloor()
		
			local phys = g_Illusion:GetPhysicsObject()
				phys:EnableMotion( false )
				
			g_Trigger = ents.Create( "sent_trigger" )
			g_Trigger:SetPos( g_Illusion:LocalToWorld( Vector( 10, 0, 48 ) ) )
			g_Trigger:Spawn()
			
			g_Trigger:SetNoDraw( true )
			g_Trigger:SetParent( g_Illusion )
			
			g_Illusion:DeleteOnRemove( g_Trigger )
		end
	end
 
end

function reset( ply )
	ply:SetViewOffset( Vector( 0, 0, 64 ) )
	ply:SetViewOffsetDucked( Vector( 0, 0, 28 ) )
	ply:SetCurrentViewOffset( Vector( 0, 0, 64 ) )
end

function ENT:Touch( ply )
	local pos = self:WorldToLocal( ply:GetPos() )
	
	local x = pos.x
	local y = pos.y
	local z = pos.z
	
	pos.x = 53 + 16
	pos.y = -y
	pos.z =  x
	
	pos = g_Illusion:LocalToWorld( pos + g_Illusion:OBBCenter() )
	
	debugoverlay.Line( g_Illusion:GetPos(), pos, 8 )
	
	local offset = pos - ply:GetPos()
	
	ply:SetViewOffset( ply:GetViewOffset() - offset )
	ply:SetViewOffsetDucked( ply:GetViewOffsetDucked() - offset )
	ply:SetCurrentViewOffset( ply:GetCurrentViewOffset() - offset )
	
	ply:SetPos( pos )

end

function ENT:EndTouch( ply )

end

function ENT:Think()
end

if CLIENT then

	local tall	= 47.4
	local width	= 24.4

	local white = Material("models/debug/debugwhite");

	g_Model = g_Model or ClientsideModel( "models/hunter/misc/lift2x2.mdl" )
	g_Model:SetNoDraw( true )

	function ENT:DrawMask()
		local pos	= self:GetPos()
		local ang	= self:GetAngles()
		
		local up	= ang:Forward()
		local right	= ang:Right()
		
		-- Offset to wall
		pos = pos + ang:Up() * -6
		
		render.SetMaterial( white )
		render.DrawQuad( 
			pos + up *  tall + right * -width,
			pos + up *  tall + right *  width,
			pos + up * -tall + right *  width,
			pos + up * -tall + right * -width
		)	
	end

	function ENT:Draw()
		
		local ground   = LocalPlayer():GetGroundEntity()
		local override = IsValid(ground) and ground:GetModel() == "models/hunter/misc/lift2x2.mdl"
		
		if ( !override ) then
			render.ClearStencil();
			render.SetStencilEnable( true );
			render.SetStencilCompareFunction( STENCIL_ALWAYS );
			render.SetStencilPassOperation( STENCIL_REPLACE );
			render.SetStencilFailOperation( STENCIL_KEEP );
			render.SetStencilZFailOperation( STENCIL_KEEP );
			render.SetStencilWriteMask( 1 );
			render.SetStencilTestMask( 1 );
			render.SetStencilReferenceValue( 1 );

			self:DrawMask()
			
			render.SetStencilCompareFunction( STENCIL_EQUAL );
		end
		
		render.ClearBuffersObeyStencil( 0, 0, 0, 0, true );
		
		local lift = g_Model
		
		local pos = self:LocalToWorld( Vector( 48, 0, -53 ) )
		local ang = self:LocalToWorldAngles( Angle( -90, 0, 0 ) )
		
		lift:SetRenderOrigin( pos )
		lift:SetRenderAngles( ang )

		lift:DrawModel()
		
		render.SetStencilEnable( false );

	--	render.SetBlend( 0.5 )
	--	self:DrawModel()
	end

end
