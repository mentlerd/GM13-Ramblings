
-- Copyright 2014 David Mentler


AddCSLuaFile()

local vector 	= FindMetaTable( "Vector" )
local util		= util or {}

function vector:Size( size )
	return self:GetNormal() * size
end

function vector:ProjectOnto( vec )
	return self:Dot(vec) / vec:Dot(vec) * vec
end

function vector:ToScreenVector()
	local proj = self:ToScreen()
	
	return Vector( proj.x, proj.y, 0 ), proj.visible
end

function util.NearestPointToLine( lineStart, lineEnd, point, clamp )
	local a = point - lineStart
	local b = lineEnd - lineStart
	
	local frac = a:Dot(b) / b:Dot(b)
	if ( clamp ) then
		frac = math.Clamp( frac, 0, 1 )
	end
	
	-- point, frac
	return lineStart + b*frac, frac
end

function util.ToScreen( camPos, camAng, camFov, scrW, scrH, vec )
    local vDir = camPos - vec
     
    local fdp = camAng:Forward():Dot( vDir )
 
    if ( fdp == 0 ) then
        return 0, 0, false, false
    end
	
    local d = 4 * scrH / ( 6 * math.tan( math.rad( 0.5 * camFov ) ) ) 
    local vProj = ( d / fdp ) * vDir
     
    local x = 0.5 * scrW + camAng:Right():Dot( vProj )
    local y = 0.5 * scrH - camAng:Up():Dot( vProj )
     
	-- scrX, scrY, isVisible, isBehind
    return x, y, ( 0 < x && x < scrW && 0 < y && y < scrH ) && fdp < 0, fdp > 0
end
