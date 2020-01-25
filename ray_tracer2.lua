
local R = Color( 230, 30, 30 )
local G = Color( 30, 230, 30 )
local B = Color( 30, 30, 230 )

local P = Color( 230, 30, 230 )

local X = Vector( 1, 0, 0 )
local Y = Vector( 0, 1, 0 )
local Z = Vector( 0, 0, 1 )

local function drawLine( a, b, color )
	render.DrawLine( a, b, color or W, false )
end
local function drawCross( v, size, color )
	size	= size  or 4
	
	drawLine( v + X*size, v - X*size, color or R )
	drawLine( v + Y*size, v - Y*size, color or G )
	drawLine( v + Z*size, v - Z*size, color or B )	
end
local function drawNormal( v, normal, len, color )
	len = len or 32

	drawLine( v, v + normal * len, color )
	drawCross( v, 1, color )
end

local function drawText( v, text, color )
	local scr = v:ToScreen()
	
	if ( scr.visible ) then
		cam.Start2D()
			draw.SimpleText( tostring(text), "BudgetLabel", scr.x, scr.y, color or W, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		cam.End2D()
	end
end

local function getAnchor()
	local prop = ents.FindByClass( "prop_physics" )[1]
	
	if IsValid( prop ) then
		return prop:GetPos(), prop:GetUp()
	end
end


local abs	= math.abs
local floor	= math.floor
local min	= math.min

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
		
		local x = floor( hit.x / grid - dir.x * 0.5 )
		local y = floor( hit.y / grid - dir.y * 0.5 )
		local z = floor( hit.z / grid - dir.z * 0.5 )
		
		local pos = Vector(x,y,z)*grid + Vector(grid,grid,grid)/2	
		render.DrawWireframeBox( pos, Angle(), -Vector(grid,grid,grid)/2, Vector(grid,grid,grid)/2, color, true )
		
		drawNormal( hit, dir, 6, color )
	end
end

local S = 32


hook.Add( "PostDrawOpaqueRenderables", "TraceTest", function()
	local origin, normal = getAnchor()
	
	if ( !origin ) then return end
	
	trace( origin, normal, 25, S )
	
--[[
	drawNormal( origin, normal, 512, P )

	local fX = floor( origin.x /S )*S + ( normal.x > 0 and 1 or 0 ) *S
	local fY = floor( origin.y /S )*S + ( normal.y > 0 and 1 or 0 ) *S
	local fZ = floor( origin.z /S )*S + ( normal.z > 0 and 1 or 0 ) *S
	
--	drawNormal( Vector( fX, origin.y, origin.z ), X * sign( normal.x ), S, R )
--	drawNormal( Vector( origin.x, fY, origin.z ), Y * sign( normal.y ), S, G )
--	drawNormal( Vector( origin.x, origin.y, fZ ), Z * sign( normal.z ), S, B )
	
	local dX = ( fX - origin.x )/normal.x
	local dY = ( fY - origin.y )/normal.y
	local dZ = ( fZ - origin.z )/normal.z

	local sX = S/ abs( normal.x )
	local sY = S/ abs( normal.y )
	local sZ = S/ abs( normal.z )
	
	
	local cX = dX
	local cY = dY
	local cZ = dZ
	
	local dist = 0
	
	for i = 0, 12 do
		local step = min( cX, cY, cZ )
			
		cX = cX - step
		cY = cY - step
		cZ = cZ - step
	
		dist = dist + step
		
		local hit	= origin + normal * dist
		
		local dir	 = nil
		local color  = nil
		
		if ( cX == 0 ) then color = R	dir = X * -sign( normal.x )	cX = sX end
		if ( cY == 0 ) then color = G	dir = Y * -sign( normal.y ) cY = sY end
		if ( cZ == 0 ) then	color = B	dir = Z * -sign( normal.z ) cZ = sZ end
		
		local box = hit - dir*S/2
		
		local hX, hY, hZ = floor( box.x /S )*S, floor( box.y /S )*S, floor( box.z /S )*S
		
		local pos = Vector( hX, hY, hZ ) + Vector(S,S,S)/2
		
		render.DrawWireframeBox( pos, Angle(), -Vector(S,S,S)/2, Vector(S,S,S)/2, color, true )
		
		drawNormal( hit, dir, 6, color )
	--	drawText( hit, i, color )
	end
]]--

end )