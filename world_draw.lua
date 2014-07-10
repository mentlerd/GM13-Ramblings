
-- Copyright 2014 David Mentler


AddCSLuaFile()

include( "physmesh.lua" )

if SERVER then

	util.AddNetworkString( "ConvexEntry" )
	util.AddNetworkString( "ConvexFinish" )

	local mesh  = game.GetWorld():GetPhysicsObject():GetMeshConvexes()
	local count = #mesh
	
	for k, convex in pairs( mesh ) do
		timer.Simple( k/500, function()
	
			net.Start( "ConvexEntry" )
				net.WriteUInt( k, 16 )
				net.WriteTable( convex )
			net.Broadcast()
			
			print( k .. "/" .. count )
		end )
	end

	timer.Simple( count/500 +1, function()
		net.Start( "ConvexFinish" )
		net.Broadcast()
	end )
	
else

	g_WorldConvexes 	= g_WorldConvexes or {}	
	g_ConvexPlanes		= {}
	
	local function BuildConvexCache()
		for index, convex in pairs( g_WorldConvexes ) do
			local planes 	= physmesh.ConvexToPlanes( convex )
			local outline 	= physmesh.PlanesToOutline( planes )
	
			for index, plane in pairs( planes ) do
				planes[index].outline = outline[index]
			end
	
			g_ConvexPlanes[index] = planes
		end
	end
	
	BuildConvexCache()
	
	net.Receive( "ConvexFinish", BuildConvexCache )
	net.Receive( "ConvexEntry", function()
		local id		= net.ReadUInt( 16 )
		local convex	= net.ReadTable()
		
		g_WorldConvexes[id] = convex
	end )
	
	
	
	local render_DrawLine = render.DrawLine
	
	local WHITE = Color( 255, 255, 255, 255 )
	
	local WIRE	= Material( "models/wireframe" )
	local SOLID = Material( "models/debug/debugwhite" )
	
	
	hook.Add( "PostDrawOpaqueRenderables", "DrawWorld", function()
		local scale = 1

		local anchor = ents.FindByClass( "prop_physics" )[1]
			anchor = IsValid( anchor ) and anchor:GetPos() or vector_origin
		
		local radius = 64
		
		local hW = 64
		local hT = 64
		
		render.SetMaterial( WIRE )
	--	render.DrawSphere( anchor, radius, 8, 8, WHITE )
		
		local C_XPOS = physmesh.ToPlane( anchor + Vector(  1,0,0 )*hW, -Vector(  1,0,0 ) )
		local C_XNEG = physmesh.ToPlane( anchor + Vector( -1,0,0 )*hW, -Vector( -1,0,0 ) )
		
		local CI_XPOS = physmesh.ToPlane( anchor + Vector(  1,0,0 )*hW,  Vector(  1,0,0 ) )
		local CI_XNEG = physmesh.ToPlane( anchor + Vector( -1,0,0 )*hW,  Vector( -1,0,0 ) )
		
		local C_ZPOS = physmesh.ToPlane( anchor + Vector( 0,0, 1 )*hT,  -Vector(  0,0, 1 ) )
		local C_ZNEG = physmesh.ToPlane( anchor + Vector( 0,0,-1 )*hT,  -Vector(  0,0,-1 ) )
		
		
		local clips = {
			{ C_XPOS },
			{ C_XNEG },
			{ C_ZPOS, CI_XPOS, CI_XNEG },
			{ C_ZNEG, CI_XPOS, CI_XNEG },
		}
		
		for _, planes in pairs( g_ConvexPlanes ) do
			
			-- Rough inside check
			local inside = true
			
			for id, plane in pairs( planes ) do
				local normal 	= plane.normal
				local dist		= plane.dist
				
				local proj = normal:Dot( anchor - normal * dist ) / normal:Dot( normal )
				
				if ( radius < proj ) then
					inside = false
					break
				end
			end
		
			if ( not inside ) then
				continue
			end
		
			-- Cut shit
			for _, clip in pairs( clips ) do
				local copy = table.Copy( planes )
				
				for id, extra in pairs( clip ) do
					table.insert( copy, extra )
				end
				
				local convex = physmesh.PlanesToConvex( copy )
				
				local tris = #convex /3
				
				mesh.Begin( MATERIAL_TRIANGLES, tris )
				
					for index = 1, #convex do
						mesh.Position( convex[index] + Vector( 0, -0.1, 0 ) )
						mesh.AdvanceVertex()
					end
				
				mesh.End()
						
			--[[
				local verts = #convex
				
				for index = 1, verts, 3 do
					local A = convex[index +0]
					local B = convex[index +1]
					local C = convex[index +2]
					
					render_DrawLine( A, B )
					render_DrawLine( B, C )
					render_DrawLine( C, A )
				end
			]]--
			end
				
		--[[
				local clipped = physmesh.PlanesToOutline( planes )
				
				for _, outline in pairs( clipped ) do
					local count	  = #outline
					
					local base = outline[1]
					local last = base
					
					for index = 2, count +1 do
						local curr = outline[index] or base
						
						render_DrawLine( last *scale, curr *scale, color )
						last = curr
					end
				end
		]]--
		
		--[[
			-- Color intersecting convexes
			local color = inside and Color( 255, 0, 0 ) or WHITE
			
			for id, plane in pairs( planes ) do
				
				-- Skip non horizontal planes
				if ( !plane.normal:IsEqualTol( Vector( 0, 0, 1 ), 0.01 ) ) then
			--		continue
				end
				
				-- Render outline
				local outline = plane.outline
				local count	  = #outline
				
				local base = outline[1]
				local last = base
				
				for index = 2, count +1 do
					local curr = outline[index] or base
					
					render_DrawLine( last *scale, curr *scale, color )
					last = curr
				end
				
			end
		]]--
			
		end
		
	end )
	
end