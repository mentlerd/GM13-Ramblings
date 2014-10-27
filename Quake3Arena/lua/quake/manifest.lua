
include "physmesh.lua"

include "q3_globals.lua"
include "q3_struct.lua"
include "q3_bezier.lua"

include "q3_decoder.lua"

include "q3_lightmap.lua"
include "q3_vismesh.lua"


local path = "data/pak0/maps/q3dm1.bsp"

MAP = quake.DecodeMap(file.Open( path, "rb", "GAME" ))

if !LIGHTMAP then

	surface.CreateFont( "LightmapWarning", {
		font = "Arial",
		size = 30,
		weight = 500,
	} )

	LIGHTMAP = GetRenderTarget( "quake_lightmap_" .. path, 128 *8, 128 *2, false )

	local index  = 0
	local stream = file.Open( path, "rb", "GAME" )
		stream:Seek( MAP.light_off )

	local dummy = CreateMaterial( "QuakeMapDebug", "UnlitGeneric", {
		["$basetexture"] 		= "models/debug/debugwhite", 	
	} )
	dummy:SetTexture( "$basetexture", LIGHTMAP )

	hook.Add( "HUDPaint", "Q3: RenderLightmaps", function()
		draw.SimpleText( "Rendering lightmaps. The lag you experience will be gone shortly", "LightmapWarning", 10, 10, color_white )
	
		if index >= MAP.light_num then
			stream:Close()
			
			hook.Remove( "HUDPaint", "Q3: RenderLightmaps" )
			return
		end
		
		local baseX = ( index%8 ) *128
		local baseY = math.floor( index/8 ) *128
		
		render.PushRenderTarget( LIGHTMAP )
		render.SetViewPort( baseX, baseY, 128, 128 )
		
		cam.Start2D()
		
		surface.SetDrawColor( 255, 255, 255, 255 )
		surface.DrawRect( 0, 0, 128, 128 )
		
		for y = 0, 127 do
			for x = 0, 127 do
				surface.SetDrawColor( stream:ReadByte(), stream:ReadByte(), stream:ReadByte() )
				surface.DrawRect( x, y, 1, 1 )
			end
		end
		
		cam.End2D()
		
		render.PopRenderTarget()
		
		index = index +1
	end )

end
	

TEXTURES	= {}
MESH_LIST	= {}

local function getTextureID( name )
	local name = name:match( "(.*)%." ) or name
	
	-- HACK: Cut shader parameters
	local param = name:match( "_[0-9]+K" )
	if ( param ) then
		name = name:sub( 0, -param:len() -1 )
	end
	
	if ( name:EndsWith( "_trans" ) ) then
		name = name:sub( 0, -7 ) 
	end
	
	return name
end

-- Load textures
for index, data in pairs( MAP.textures ) do	
	local name	= data.name
	local path	= "data/pak0/" .. getTextureID( name ) .. ".png"
	
	local texture  = Material( path, "unlitgeneric smooth noclamp mips" )
	
	if ( texture:IsError() ) then
		print( "Unable to load separate texture: '" .. path .. "'" )
	else
		local material = CreateMaterial( name .. "_c", "LightmappedGeneric", {
			["$basetexture"] 		= texture:GetTexture("$basetexture"):GetName(),
			["$vertexcolor"] 		= 1,
		} )
	
		TEXTURES[index] = material
	end
end

-- Render map faces
local function lazyTable( tbl, key )
	local value = tbl[key]

	if !value then
		value    = {}
		tbl[key] = value
	end

	return value
end

for _, face in pairs( MAP.faces ) do	
	if face.type != TYPE_BILLBOARD then	
		local meshID 	= face.texture +1
		local mesh		= lazyTable( MESH_LIST, meshID )
		
		quake.RenderFace( MAP, face, mesh )
	end
end

-- Render map IMeshes
for index, vertexes in pairs( MESH_LIST ) do
	local count = #vertexes
	local tris	= count /3
	
	if ( count > 32768 ) then
		print("Warning! Skipped mesh due to too many vertexes")
		continue
	end

	MESH_LIST[index] = Mesh( TEXTURES[index] or wireframe )
	mesh.Begin( MESH_LIST[index], MATERIAL_TRIANGLES, tris )
	
	for index = 1, count do
		local vertex = vertexes[index]
		
		mesh.Position( vertex.pos )
		mesh.Normal( vertex.normal )
		mesh.Color( vertex.color.r, vertex.color.g, vertex.color.b, vertex.color.a )
		
		mesh.TexCoord( 0, vertex.u,			vertex.v )
		mesh.TexCoord( 1, vertex.light_u,	vertex.light_v )
		
		mesh.AdvanceVertex()
	end
	
	mesh.End()
end

-- Render scene
local matrix = Matrix()
local scale	= Vector(1,1,1) * 0.2

local wireframe = Material( "models/wireframe" )

local dummy = CreateMaterial( "q3lightmap2", "UnlitGeneric", {
	["$basetexture"] 		= LIGHTMAP,
	["$vertexcolor"] 		= 1,
} )

hook.Add( "PostDrawOpaqueRenderables", "quake", function()
	local anchor = ents.FindByModel( "models/props_c17/canister01a.mdl" )[1]
	
--[[
	for _, ent in pairs( ents.GetAll() ) do
		if ent:GetModel() == "models/props_c17/canister01a.mdl" then
			anchor = ent
			break
		end
	end
	
	if !IsValid( anchor ) then return end
	
	local origin = anchor:LocalToWorld( Vector( 0, 0, -64 ) )
	local angles = anchor:GetAngles()
	
	matrix:SetAngles( angles )
	matrix:SetTranslation( origin )
]]--
	
--	matrix:SetTranslation( Vector( -3800, 1150, -15700 ) )	

	matrix:SetTranslation( Vector( 0, 0, 400 ) )

	cam.PushModelMatrix( matrix )
		
		-- Render map IMeshes
		render.SetLightmapTexture( LIGHTMAP )
		
		for index, mesh in pairs( MESH_LIST ) do
			if !TEXTURES[index] then
				continue
			end

			local material = TEXTURES[index] or wireframe
			
			if ( mesh.Draw ) then
				render.SetMaterial( material )
				render.SetLightmapTexture( LIGHTMAP )
	
				mesh:Draw()
			end
		end
		
	/*
		-- Debug brushes
		render.SetMaterial( wireframe )

		local len = #MAP.brushes
		for index = 1, len do
			local verts = MAP.brushes[index].mesh
			local count = #verts

			mesh.Begin( MATERIAL_TRIANGLES, count /3 )

				for index = 1, count do
					mesh.Position( verts[index] )
					mesh.AdvanceVertex()
				end

			mesh.End()
		end
	*/

	cam.PopModelMatrix()
	
	hook.Call( "PostDrawQuake" )
end )

concommand.Add( "quake_removedebug", function()
	hook.Remove( "PostDrawOpaqueRenderables", "quake" )
end )
