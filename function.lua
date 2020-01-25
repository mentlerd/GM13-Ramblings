
AddCSLuaFile()

-- Localize for quick access
local debug_getinfo		= debug.getinfo
local debug_getupvalue	= debug.getupvalue


-- Override function metatable
local func = function() end
local meta = debug.getmetatable( func )

if !meta then
	meta = {}
	meta.__index = function( self, key )
		local raw = rawget( meta, key )
		
		if !raw then
			error( "bad key to function index (valid metakey expected)", 2 )
		end
		
		return raw
	end

	debug.setmetatable( func, meta )
end

-- New metafunctions

function meta:info( filter )
	return debug_getinfo( self, filter )
end

function meta:src()
	local info  = debug_getinfo( self, 'S' )
	local raw	= file.Read( info.short_src, "GAME" )

	if raw then
		local offset = info.linedefined
		local limit	 = info.lastlinedefined
	
		local line = 0
		
		raw = string.gsub( raw, "(.-)\n", function( a )
			line = line +1
			
			if ( line < offset or limit < line ) then
				return ""
			end
		end )
	end
	
	return raw
end

function meta:origin()
	local info   = debug_getinfo( self, 'S' )
	local origin = info.short_src .. ":"
	
	if info.linedefined == info.lastlinedefined then
		origin = origin .. info.linedefined
	else
		origin = origin .. "[" .. info.linedefined .. "-" .. info.lastlinedefined .. "]"
	end
	
	return origin
end

function meta:upvals()
	local info = debug_getinfo( self, 'u' )
	local ups  = {}
	
	for index = 1, info.nups do
		local name, value = debug_getupvalue( self, index )
		
		ups[name] = value
	end
	
	return ups
end
