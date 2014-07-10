
-- Copyright 2014 David Mentler


include( "struct.lua" )
include( "physmesh.lua" )

include( "bsp_constants.lua" )


-- Header
t_lump	= struct( 
	t_int,	"off",
	t_int,	"len",
	t_int,	"version",
	
	skip( 4 )
)

t_header = struct(
	t_int,					"ident",
	t_int,					"version",
	array( t_lump, 64 ),	"lumps",
	t_int,					"revision"
)

-- Content
t_plane = struct(
	t_vector, 	"normal",
	t_float,	"dist",
	t_int,		"type"
)

t_brushside = struct(
	t_short,	"plane",
	t_short,	"texinfo",
	t_short,	"dispinfo",
	t_short,	"bevel"
)

t_brush = struct(
	t_int,	"side_base",
	t_int,	"side_count",
	t_int,	"contents"
)

lump_planes		= lump( LUMP_PLANES, t_plane )

lump_brushes	= lump( LUMP_BRUSHES, t_brush )
lump_brushsides	= lump( LUMP_BRUSHSIDES, t_brushside )


local stream = file.Open( "maps/" .. game.GetMap() .. ".bsp", "rb", "GAME" )


if ( stream != nil ) then
	timer.Simple(0, function() stream:Close() end )
end


-- Read header
local header = t_header( stream )

-- Read raw entity data
local lump_ents = header.lumps[LUMP_ENTITIES +1]

stream:Seek( lump_ents.off )

local ents_raw	= stream:Read( lump_ents.len )


-- Decode entity data
local ents	= {}
local index = 1

ents_raw:gsub( "{(.-)}", function( entry )
	local data = {}

	entry:gsub( "\"(.-)\"%s*\"(.-)\"", function( key, value )
		local prev = data[key]
		
		if !prev then
			data[key] = value
		else
			if type(prev) == "table" then
				table.insert( prev, value )
			else
				data[key] = { prev, value }
			end
		end
	end )

	ents[index] = data
	index = index +1
end )


-- Read raw plane data
local planes = lump_planes( stream, header )

local brush_sides 	= lump_brushsides( stream, header )
local brush_raw		= lump_brushes( stream, header )

-- Relink brushes
local brushes = {}

for index, raw in pairs( brush_raw ) do
	if ( bit.band( raw.contents, CONTENTS_DETAIL ) == 0 ) then
		continue
	end
	
	local brush = {}
	
	local off   = raw.side_base
	local count = raw.side_count
	
	for index = 1, count do
		brush[index] = planes[ brush_sides[off + index].plane +1 ]
	end
	
	brushes[index] = physmesh.PlanesToConvex( brush )
end



local wire 	= Material( "models/wireframe" )


hook.Add( "PostDrawOpaqueRenderables", "BSP - DrawBrushes", function()
	render.SetMaterial( wire )

	for _, brush in pairs( brushes ) do
		local tris = #brush /3
		
		mesh.Begin( MATERIAL_TRIANGLES, tris )
		
		for index = 1, #brush do
			mesh.Position( brush[index] )
			mesh.AdvanceVertex()
		end
		
		mesh.End()
	end
end )
