
-- Copyright 2014 David Mentler


if SERVER then
	AddCSLuaFile()

	RunConsoleCommand( "sv_allowcslua", "1" )
	
	util.AddNetworkString( "lua_sync" )
	util.AddNetworkString( "lua_cmd" )
	
	net.Receive( "lua_cmd", function( _, ply )
		local cmd		= net.ReadString()
		local params 	= net.ReadTable()
		local raw		= net.ReadString()
		
		MsgN( "Received lua_cmd '" .. cmd .. "' from " .. ply:Nick() )
			
		if ( cmd:sub( 1, 3 ) == "lua" ) then
			concommand.Run( ply, cmd, params, raw )
		end
	end )
end

function string.fit( str, size, char )
	local len 	= str:len()
	local char	= char or " "
	
	if ( len <= size ) then
		return str .. string.rep( char, size - len )
	else
		return str:sub( 0, size -3 ) .. " .." 
	end
end

function getLuaValue( input )
	local func = CompileString( "return " .. input, "lua_getValue" )
	
	return func()
end

do
	grep_color = Color( 255, 10, 10 )
	
	function MsgGrep( str, grep )
		if ( !grep ) then
			Msg( str )
		else			
			local split = string.Split( str, grep )
			local count = #split
			
			Msg( split[1] )
			
			for index = 2, count do
				MsgC( grep_color, grep )
				Msg( split[index]:sub( 0, -1 ) )
			end
		end
	end

	function PrintTableGrep( tbl, grep, ident, done )	
		local ident	= ident	or 0
		local done	= done 	or {}

		local prefix 	= string.rep( " ", ident )
		
		-- Calculate key inset
		local keys	= {}
		local len 	= 4
		
		for key in pairs( tbl ) do
			len = math.max( len, tostring( key ):len() )
			table.insert( keys, key )
		end
		
		ident = ident + len
		
		table.sort( keys, function( a, b )
			if ( isnumber( a ) and isnumber( b ) ) then
				return a < b
			end
		
			return tostring( a ) < tostring( b )
		end )
		
		local limit = 100000
		
		for _, key in pairs( keys ) do
			local value	= tbl[key]
			local key 	= tostring( key )
			
			if ( istable( value ) && not done[value] ) then
				done[value] = true
			
				Msg( prefix )		
				MsgGrep( key, grep )
				MsgN( ":" )
				
				PrintTableGrep( value, grep, ident, done )
			else
				if ( limit > 0 ) then
					Msg( prefix )
					MsgGrep( key:fit( len ), grep )
					Msg( " = " )
					
					MsgGrep( tostring( value ), grep )
					MsgN()					
				end
				
				limit = limit -1
			end
		end
		
		if ( limit < 0 ) then
			Msg( prefix )
			
			Msg( "... (" )
			Msg( -limit )
			Msg( " hidden)" )
			
			MsgN()
		end
	end

end

function parseGrep( raw )
	local lastPos	= nil
	local pos		= string.find( raw, "|" )
	
	while ( pos != nil ) do
		lastPos	= pos
		pos		= string.find( raw, "|", pos +1 )
	end
	
	if ( not lastPos ) then
		return raw
	else
		return raw:sub( 1, lastPos -1 ), raw:sub( lastPos +2 )
	end
end

local function addCommand( name, func, comp )
	if ( SERVER ) then
		concommand.Add( name, func, comp )
	else

		if ( !game.SinglePlayer() ) then		
			concommand.Add( name, function( player, cmd, params, raw )
				net.Start( "lua_cmd" )
					
					net.WriteString( cmd )
					net.WriteTable( params )
					net.WriteString( raw )
					
				net.SendToServer()
			end )
		end
		
		concommand.Add( name .. "_cl", func, comp )

	end
end

local env = { __ply = nil }	
	
do
	local function index( tbl, index )
		local value = rawget( _G, index )
			
		if ( !value ) then
			local ply = rawget( tbl, "__ply" )
			
			if ( index == "me" ) then
				return ply
			elseif ( index == "here" ) then
				return ply:GetPos()
			elseif ( index == "trace" ) then
				return ply:GetEyeTraceNoCursor()
			elseif ( index == "traceEnt" or index == "that" or index == "this" ) then
				return ply:GetEyeTraceNoCursor().Entity
			elseif ( index == "traceHit" ) then
				return ply:GetEyeTraceNoCursor().HitPos
			end
		end
		
		return value
	end
	
	setmetatable( env, { __index = index } )
end

addCommand( "lua", function( player, cmd, params, raw )	
	local raw, grep	= parseGrep( raw )
	local func 		= CompileString( "return " .. raw, "lua_ret", false )
	
	if ( isstring( func ) ) then -- Compile error. Try whitout 'return ' ..
		func = CompileString( raw, "lua_raw", false )
	end
	
	if ( isstring( func ) ) then
		print( "CompileError: " .. func:sub( 12 ) ) -- Cut lua_[ret|raw]:[0-9]:
	else	
		
		env.__ply = player
		debug.setfenv( func, env )
	
		local rets = { pcall( func ) }
		local succ = table.remove( rets, 1 )
	
		if ( !succ ) then
			print( "RuntimeError: " .. rets[1] )
		else
			PrintTableGrep( rets, grep )
		end
	end
end )

addCommand( "lua_enum", function( player, cmd, params, raw )
	local value		= tonumber( params[1] )
	
	local prefix	= ( params[2] or "*" ):upper()
	local realm		= ( params[3] and getLuaValue( params[3] ) ) or _G
	
	local len		= ( prefix != "*" and prefix:len() ) or 0

	for key, val in pairs( realm ) do
		if ( value == nil or val == value ) then
			
			if ( len == 0 or key:sub( 0, len ) == prefix ) then
				
				if value then
					print( key )
				else
					print( tostring( val ):fit( 8 ) .. " = " .. key )
				end
			end
			
		end
	end
end )
	
addCommand( "lua_func", function( player, cmd, params, raw )
	local value		= getLuaValue( raw )

	if ( isfunction( value ) ) then
		local info = debug.getinfo( value )
		
		if ( info.what == "=[C]" ) then
			print( "C Function" )
		else
			local lines = file.Read( info.short_src, "GAME" )
				lines = string.Explode( "\n", lines or "" )
			
			for lineID = info.linedefined, info.lastlinedefined do
				print( lines[lineID] )
			end
		end
	end
end )

--[[
	lua_sync
]]--
net.Receive( "lua_sync", function( len, ply )
	local global 	= net.ReadString()
	
	local typeID	= net.ReadUInt( 8 )
	local value		= net.ReadType( typeID )

	_G[ global ] = value
end )

addCommand( "lua_sync", function( player, cmd, params, raw )
	local global	= table.remove( params, 1 )
	local value		= getLuaValue( string.Implode( " ", params ) )

	if ( net.WriteVars[ TypeID( value ) ] == nil ) then
		print( "Couldn't snyc type: " .. type( value ) )
		return
	end
	
	net.Start( "lua_sync" )
		net.WriteString( global )
		net.WriteType( value )

	if SERVER then
		net.Send( player )
	else
		net.SendToServer()
	end
end )
