
-- Copyright 2014 David Mentler


function link_locals( list, whitelist )
	local refs = {}

	for _, func in pairs( list ) do
		local nups = debug.getinfo( func, 'u' ).nups
		
		for index = 1, nups do
			local name = debug.getupvalue( func, index )
			
			if ( whitelist[name] ) then
				local ref = refs[ name ]
			
				if ( !ref ) then
					refs[ name ] = { 
						func  = func, 
						index = index 
					}
				else
					debug.upvaluejoin( func, index, ref.func, ref.index )
				end
			end			
		end
	end
end

move = {}

include( "moduleA.lua" )
include( "moduleB.lua" )

local m_Player
local m_Origin

function move.Entry( ply, origin )
	m_Player = ply
	m_Origin = origin
end


link_locals( move, {
	m_Player	= true,
	m_Origin	= true,
	m_Velocity	= true
} )

