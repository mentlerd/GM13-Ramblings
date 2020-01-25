
-- Raytrace
local X = Vector( 1, 0, 0 )
local Y = Vector( 0, 1, 0 )
local Z = Vector( 0, 0, 1 )

local abs	= math.abs
local min	= math.min

local floor	= math.floor
local ceil  = math.ceil


local function sign( n )
	return n > 0 and 1 or n < 0 and -1 or 0
end

local function trace( origin, normal, limit, grid, cback )
	local fX = floor( origin.x /grid )*grid + ( normal.x > 0 and grid or 0 )
	local fY = floor( origin.y /grid )*grid + ( normal.y > 0 and grid or 0 )
	local fZ = floor( origin.z /grid )*grid + ( normal.z > 0 and grid or 0 )
	
	local dX = ( fX - origin.x )/normal.x
	local dY = ( fY - origin.y )/normal.y
	local dZ = ( fZ - origin.z )/normal.z

	local sX = grid/ abs( normal.x )
	local sY = grid/ abs( normal.y )
	local sZ = grid/ abs( normal.z )
	
	local cX = dX
	local cY = dY
	local cZ = dZ
	
	local dist = 0
	
	for i = 0, limit do
		local step = min( cX, cY, cZ )
			
		cX = cX - step
		cY = cY - step
		cZ = cZ - step
	
		dist = dist + step
		
		local hit = origin + normal * dist		
		local dir = nil
		
		if ( cX == 0 ) then dir = X * sign( normal.x )	cX = sX end
		if ( cY == 0 ) then dir = Y * sign( normal.y )	cY = sY end
		if ( cZ == 0 ) then	dir = Z * sign( normal.z )	cZ = sZ end
		
		local x = ceil( hit.x / grid - dir.x * 0.5 )
		local y = ceil( hit.y / grid - dir.y * 0.5 )
		local z = ceil( hit.z / grid - dir.z * 0.5 )
		
		if ( cback( x, y, z, dir ) ) then
			
			local pos = Vector(x -1,y -1,z -1)*grid + Vector(grid,grid,grid)/2	
			
			render.DrawWireframeBox( pos, Angle(), -Vector(grid,grid,grid)/2, Vector(grid,grid,grid)/2, Color( 255, 0, 0 ), true )
			render.DrawLine( hit, hit - dir * 8, Color(30, 230, 30))
			
			return x, y, z, dir, hit
		end
	end
end


sides = {
	-- Label,	Normal,					Plane indices	Opposite
	{ "UP",		Vector( 0, 0,  1 ),		5, 4, 6, 3,			2 },
	{ "DOWN",	Vector( 0, 0, -1 ),		5, 3, 6, 4,			1 },
	
	{ "LEFT",	Vector( 0,  1, 0 ), 	1, 6, 2, 5,			4 },
	{ "RIGHT",	Vector( 0, -1, 0 ), 	1, 5, 2, 6,			3 },	
	
	{ "FRONT",	Vector(  1, 0, 0 ), 	1, 3, 2, 4,			6 },
	{ "BACK",	Vector( -1, 0, 0 ), 	1, 4, 2, 3,			5 },
}

voxels = {
	{
		{ 1 }
	}
}

	
--[[
		{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 1, 1, 1, 0, 0, 1, 1, 1, 0 },
		{ 0, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
		{ 0, 1, 1, 1, 0, 0, 1, 1, 1, 0 },
		{ 0, 1, 1, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 1, 1, 0, 1, 1, 0, 0, 0, 0 },
		{ 0, 1, 1, 0, 1, 1, 1, 1, 1, 0 },
		{ 0, 1, 1, 1, 0, 0, 0, 1, 1, 0 },
		{ 0, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
]]--


local function offset( x, y, z, dir )
	local off = sides[dir][2]
	
	return x + off.x, y + off.y, z + off.z
end

local function setOpenAt( x, y, z )
	local level = voxels[z] or {}
	local row	= level[y]  or {}
	
	voxels[z] = level
	level[y]  = row
	
	row[x] = 1
end

local function isOpenAt( x, y, z )
	return voxels[z] and voxels[z][y] and voxels[z][y][x] == 1
end

local function isSideSolid( x, y, z, dir )	
	return !isOpenAt( offset( x, y, z, dir ) )
end

local function getEdgeLength( x, y, z, dir, edge )
	if ( isSideSolid( x, y, z, edge ) ) then 
		return 18
	end
	
	local bX, bY, bZ = offset( x, y, z, dir )
	
	return isSideSolid( bX, bY, bZ, edge ) and 16 or 14
end


local white = Color( 200, 200, 200 )
local grey  = Color(  80,  80,  80 )


local function addQuadSide( tris, off, dir, flip )
	local side	 = sides[ dir ]
	local origin = off + side[2] * 16
	
	if ( flip ) then
		side = sides[ side[7] ]
	end
	
	-- Yuck
	local A = sides[ side[3] ][2] * 16
	local B = sides[ side[4] ][2] * 16
	local C = sides[ side[5] ][2] * 16
	local D = sides[ side[6] ][2] * 16
	
	table.insert( tris, { pos = origin + D + A, color = white, u = 0,    v = 0    } )
	table.insert( tris, { pos = origin + A + B, color = white, u = 0.25, v = 0    } )
	table.insert( tris, { pos = origin + B + C, color = white, u = 0.25, v = 0.25 } )
	
	table.insert( tris, { pos = origin + B + C, color = white, u = 0.25, v = 0.25 } )
	table.insert( tris, { pos = origin + C + D, color = white, u = 0,    v = 0.25 } )
	table.insert( tris, { pos = origin + D + A, color = white, u = 0,    v = 0    } )
end

local function addCellSide( tris, x, y, z, off, dir, flip )	
	local side	 = sides[ dir ]
	local origin = off + side[2] * 18
	
	if ( flip ) then
		side = sides[ side[7] ]
	end
	
	-- Yuck
	local A = sides[ side[3] ][2] * getEdgeLength( x, y, z, dir, side[3] )
	local B = sides[ side[4] ][2] * getEdgeLength( x, y, z, dir, side[4] )
	local C = sides[ side[5] ][2] * getEdgeLength( x, y, z, dir, side[5] )
	local D = sides[ side[6] ][2] * getEdgeLength( x, y, z, dir, side[6] )
	
	table.insert( tris, { pos = origin + D + A, color = grey, u = 0,    v = 0    } )
	table.insert( tris, { pos = origin + A + B, color = grey, u = 0.25, v = 0    } )
	table.insert( tris, { pos = origin + B + C, color = grey, u = 0.25, v = 0.25 } )
	
	table.insert( tris, { pos = origin + B + C, color = grey, u = 0.25, v = 0.25 } )
	table.insert( tris, { pos = origin + C + D, color = grey, u = 0,    v = 0.25 } )
	table.insert( tris, { pos = origin + D + A, color = grey, u = 0,    v = 0    } )
end

local function addCellSides( tris, x, y, z )
	if ( isOpenAt( x, y, z ) ) then
		local off = Vector( x, y, z ) * 32 + Vector( -16, -16, -16 )
		
		for side = 1, 6 do
			if ( isSideSolid( x, y, z, side ) ) then
				addQuadSide( tris, off, side, true )
				
				addCellSide( tris, x, y, z, off, side, true )
			end
		end
	end
end

local solid = CreateMaterial( "SpaceMapSolid", "UnlitGeneric", {
	["$basetexture"] 		= "sprops/sprops_grid_12x12", 	
    ["$vertexcolor"] 		= 1,
} )

local function build()
	local tris  = {}

	for z, level in pairs( voxels ) do
		for y, row in pairs( level ) do
			for x, _ in pairs( row ) do
				addCellSides( tris, x, y, z )
			end
		end
	end

	temp = Mesh()
	temp:BuildFromTriangles( tris )
end

build()

hook.Add( "PostDrawOpaqueRenderables", "P2Editor", function()
	render.SetMaterial( solid )
	
	temp:Draw()
end )


do
	local W = Color( 230, 230, 230 )

	local R = Color( 230, 50, 50 )
	local G = Color( 50, 230, 50 )
	local B = Color( 50, 50, 230 )

	local X = Vector( 1, 0, 0 )
	local Y = Vector( 0, 1, 0 )
	local Z = Vector( 0, 0, 1 )

	local function drawCross( pos, size, color )
		local size	= size or 1
			
		render.DrawLine( pos + X*size, pos - X*size, color or R )
		render.DrawLine( pos + Y*size, pos - Y*size, color or G )
		render.DrawLine( pos + Z*size, pos - Z*size, color or B )
	end

	local function drawLine( x, y, color )
		render.DrawLine( x, y, X or color )
	end
	local function drawNormal( pos, normal, len, color )
		local len	= len or 32
		local color = color or R

		drawCross( pos, nil, color )
		render.DrawLine( pos, pos + normal * len, color )
	end
	
	local state = false
	
	hook.Add( "PreDrawTranslucentRenderables", "TraceTest", function( _, inSkybox )
		if ( inSkybox ) then return end
			
		local origin = EyePos()
		local normal = EyeAngles():Forward()
		
		local x, y, z, dir = trace( origin, normal, 25, 32, function( x, y, z, normal )
			local hit = 0
	
			for index, side in pairs( sides ) do
				if ( side[2] == normal ) then
					hit = index
					break
				end
			end
			
			return isOpenAt( x, y, z ) and isSideSolid( x, y, z, hit )
		end )

		-- Please just work..	
		local left	= input.IsMouseDown( MOUSE_LEFT )
		local right	= input.IsMouseDown( MOUSE_RIGHT )
		
		local press = left or right
		
		if ( press and press != state ) then	
			local hit = 0
	
			for index, side in pairs( sides ) do
				if ( side[2] == dir ) then
					hit = index
					break
				end
			end
			
			if ( voxels[z] and voxels[z][y] ) then
				
				if ( right ) then
					voxels[z][y][x] = 0
				end
				
				if ( left ) then
					x, y, z = offset( x, y, z, hit )
				
					setOpenAt( x, y, z )
				end
				
				build()
			end
		end
		
		state = left or right
	end )
	
end

