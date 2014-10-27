
local function lump( decoder, key )
	if ( !decoder ) then return end

	return function( stream, lump, map )
		local limit = lump.offset + lump.length
		
		local data	= {}
		local index	= 1
		
		while( stream:Tell() < limit ) do
			data[index] = decoder( stream )
			index		= index +1
		end
		
		map[key] = data
	end
end

quake.lump_decoders = {
	[ LUMP_ENTITIES ]	= function( stream, lump, map )
		local raw = stream:Read( lump.length )
		local ents = {}
		
		local lines = raw:Split( "\n" )
		local entry = {}
		
		for index, line in ipairs( lines ) do
			line = line:Trim()
			
			if ( line == "{" or line == "" ) then
				-- SKIP
			elseif ( line == "}" ) then
				table.insert( ents, entry )
				entry = {}
			else
				local key, value = line:match( [["(.+)"%s*"(.+)"]] )
			
				if ( key ) then
					entry[key] = value
				end
			end
		end
		
		map.entities = ents
	end, 
	
	[ LUMP_NODES ] = lump( quake.struct.Node,	"nodes" ),
	[ LUMP_LEAFS ] = lump( quake.struct.Leaf,	"leafs" ),
	
	[ LUMP_LEAF_FACES ] 	= lump( quake.struct.LeafFace,	"leaf_faces" ),
	[ LUMP_LEAF_BRUSHES ] 	= lump( quake.struct.LeafBrush,	"leaf_brush" ),
	

	[ LUMP_TEXTURES ]		= lump( quake.struct.Texture, 	"textures" ),
		
	[ LUMP_VERTEXES ]		= lump( quake.struct.Vertex, 	"verts" ),
	[ LUMP_MESH_VERTEXES ] 	= lump( quake.struct.MVertex, 	"mverts" ),

	[ LUMP_PLANES ]			= lump( quake.struct.Plane,		"planes" ),
	[ LUMP_BRUSHES ]	 	= lump( quake.struct.Brush,		"brushes" ),
	[ LUMP_BRUSH_SIDES ] 	= lump( quake.struct.BSide, 	"bsides" ),
	
	[ LUMP_MODELS ]			= lump( quake.struct.Model, 	"models" ),
	[ LUMP_FACES ]			= lump( quake.struct.Face, 		"faces" ),
	
	[ LUMP_LIGHTMAPS ]		= function( stream, lump, map )
		map.light_off	= lump.offset
		map.light_num	= lump.length / (128*128 *3)
	end 
}

local function relinkByIndex( list, key, from )
	for _, entry in pairs( list ) do
		entry[key] = from[ entry[key] +1 ]
	end
end

function quake.DecodeMap( stream )
	stream:Seek( 0 ) -- Just in case

	local magic		= assert( stream:Read(4), 	 BSP_MAGIC,   "Magic map signature does not match" )
	local version	= assert( stream:ReadLong(), BSP_VERSION, "Version mismatch" )

	-- Lumps
	local lumps = {}
	local map = {}

	for index = 1, BSP_LUMP_COUNT do
		lumps[index] = {
			id		= index -1,
			offset	= stream:ReadLong(),
			length	= stream:ReadLong()
		}
	end

	for index, lump in pairs( lumps ) do
		local decoder = quake.lump_decoders[lump.id]
		
		if ( decoder ) then	
			stream:Seek( lump.offset )
			decoder( stream, lump, map )
		end
	end

	stream:Close()
	
	-- Relink BSP tree
	for _, node in pairs( map.nodes ) do
		local child0 = node.child0
		local child1 = node.child1
		
		node.child0 = ( child0 < 0 and map.leafs[ -(child0+1) +1 ] or map.nodes[ child0 +1 ] )
		node.child1 = ( child1 < 0 and map.leafs[ -(child1+1) +1 ] or map.nodes[ child1 +1 ] )
	end
	
	-- Rebuild brush structure
	relinkByIndex( map.bsides, "plane",   map.planes )
	relinkByIndex( map.bsides, "texture", map.textures )

	for _, brush in pairs( map.brushes ) do
		local off = brush.side_off
		local num = brush.side_num

		local planes = {}

		for index = 1, num do
			local bside = map.bsides[ off + index ]

			brush[index]  = bside
			planes[index] = bside.plane
		end

		brush.mesh = physmesh.PlanesToConvex( planes )

		brush.side_off = nil
		brush.side_num = nil
	end

	return map
end
