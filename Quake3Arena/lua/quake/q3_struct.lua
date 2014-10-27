
-- Decoder functions
local File = FindMetaTable( "File" )

local t_byte	= File.ReadByte
local t_int		= File.ReadLong
local t_float	= File.ReadFloat

local t_vector	= function( stream )
	return Vector( 
		stream:ReadFloat(), 
		stream:ReadFloat(), 
		stream:ReadFloat() 
	)
end

local t_normal	= function( stream )
	return t_vector( stream ):GetNormalized()
end

local t_color	= function( stream )
	return Color( 
		stream:ReadByte(),
		stream:ReadByte(),
		stream:ReadByte(),
		stream:ReadByte()
	)
end

local t_uv	= function( stream, obj, key )
	obj[key .. 'u']	= stream:ReadFloat()
	obj[key .. 'v']	= stream:ReadFloat()
end

local t_ivector = function( stream )
	return Vector( 
		stream:ReadLong(), 
		stream:ReadLong(), 
		stream:ReadLong() 
	)
end

local function t_string( len )
	return function( stream )
		local raw = stream:Read( len )
	
		for index = raw:len(), 1, -1 do
			local byte = string.byte( raw[index] )
		
			if ( byte != 0 ) then
				return raw:sub( 0, index )
			end
		end
		
		error()
	end
end


local function struct( ... )
	local struct 	= { ... }
	local limit	 	= table.getn( struct )
	
	return function( stream )
		local obj = {}
		
		for vIndex = 1, limit, 2 do
			local decoder = struct[vIndex +0]
			local key     = struct[vIndex +1]
			
			local value = decoder( stream, obj, key )
			
			if key then
				obj[key] = value
			end
		end
		
		return obj
	end
end

local function skip( len )
	return function( stream )
		stream:Skip( len )
	end
end


-- Quake structs
quake.struct = {}

do	-- BSP info

	quake.struct.Node = struct(
		t_int,	"plane",
		
		t_int,	"child0",
		t_int,	"child1",
		
		t_ivector,	"mins",
		t_ivector,	"maxs"
	)
	quake.struct.Leaf = struct(
		t_int,	"cluster",
		t_int,	"area",
		
		t_ivector,	"mins",
		t_ivector,	"maxs",
		
		t_int,	"lface_off",
		t_int,	"lface_num",
		
		t_int,	"lbrush_off",
		t_int,	"lbrush_num"
	)

	quake.struct.LeafFace	= t_int
	quake.struct.LeafBrush	= t_int
	
end

do	-- Physics info

	quake.struct.Plane = struct(
		t_vector,	"normal",
		t_float,	"dist"
	)
	quake.struct.Brush = struct( 
		t_int,	"side_off",
		t_int,	"side_num",
		
		t_int,	"texture"
	)
	quake.struct.BSide = struct(
		t_int,	"plane",
		t_int,	"texture"
	)

end

do	-- Vismesh info
	
	quake.struct.Texture = struct(
		t_string( 64 ),	"name",
		
		t_int,	"flags",
		t_int,	"cflags"
	)

	quake.struct.Vertex = struct(	
		t_vector,	"pos",
		t_uv,		"",
		t_uv,		"light_",
		
		t_normal,	"normal",
		t_color,	"color"
	)
	quake.struct.MVertex = t_int

	quake.struct.Face = struct(
		t_int,	"texture",
		
		t_int,	"effect",
		t_int,	"type",
		
		t_int,	"vertex_off",
		t_int,	"vertex_num",
		
		t_int,	"mvertex_off",
		t_int,	"mvertex_num",
		
		t_int,	"lightmap",
		
		skip( (0 + 2 + 2 + 3+ 2*3 + 3) *4 ), nil,

		t_int,	"patchX",
		t_int,	"patchY"
	)


	quake.struct.Model = struct(
		t_vector,	"mins",
		t_vector,	"maxs",
		
		t_int,	"face_off",
		t_int,	"face_num",
		
		t_int,	"brush_off",
		t_int,	"brush_num"
	)

end
