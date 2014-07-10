
-- Copyright 2014 David Mentler


function skip( count )
	return function( stream )
		stream:Skip( count )
	end
end

function array( decoder, count )
	return function( stream )
		local array = {}
		
		for index = 1, count do
			array[index] = decoder( stream )
		end
		
		return array
	end
end

function str( size )
	return function( stream )
		local raw = stream:Read( size )
		
		if ( !raw ) then
			error( "EOF" )
		end
		
		for index = 1, size do
			if ( raw:byte( index ) == 0 ) then
				return raw:sub( 1, index -1 )
			end
		end
	
		error( "Missing null terminator" )
	end
end

function struct( ... ) 
	local struct = {}
	local args   = { ... }
	
	for index = 1, #args, 2 do
		local entry = {}
		
		entry.decoder	= args[index +0]
		entry.member	= args[index +1]
		
		table.insert( struct, entry )
	end
	
	return function( stream )
		local base = stream:Tell()
		local obj  = {}
		
		for _, entry in pairs ( struct ) do
			local value = entry.decoder( stream, obj, base )
		
			if ( entry.member ) then
				obj[ entry.member ] = value
			end
		end
		
		return obj
	end
end

function lump( id, content )
	return function( stream, header )
		local data  = {}
		local index = 1
		
		local lump	= header.lumps[id +1]
		local limit = lump.off + lump.len
		
		stream:Seek( lump.off )
		while ( stream:Tell() < limit ) do
			data[index] = content( stream )
			index = index +1
		end
		
		return data
	end
end



local _R = debug.getregistry()

t_int		= _R.File.ReadLong
t_byte		= _R.File.ReadByte
t_char		= _R.File.ReadByte
t_short		= _R.File.ReadShort
t_float		= _R.File.ReadFloat
t_double	= _R.File.ReadDouble

t_vector	= function( stream )
	return Vector( stream:ReadFloat(), stream:ReadFloat(), stream:ReadFloat() )	
end

t_string	= function( stream )
	local raw = ""
	
	for i = 0, 256 do
		local chr = stream:ReadByte()
		
		if ( chr == 0 ) then
			return raw
		end
		
		raw = raw .. string.char( chr )
	end
	
	error( "Null terminated string over 256 long" )
end
