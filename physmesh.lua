
-- Copyright 2014 David Mentler


-- Vector meta
local meta = FindMetaTable( "Vector" )
 
function meta:ProjectOnto( vec )
	return self:Dot(vec) / vec:Dot(vec) * vec
end


physmesh = {}
 
-- Point, Normal -> Plane
function physmesh.ToPlane( point, normal )     
	local proj	      = point:ProjectOnto( normal )
	local dist	      = proj:Length()
	       
	-- Projection is in the opposite direction
	if ( !normal:IsEqualTol( proj:GetNormalized(), 0.01 ) ) then
		dist = -dist
	end
 
	return { normal = normal, dist = dist }
end
 
-- Convex triangles -> Planes
function physmesh.ConvexToPlanes( convex )
	local planes = {}
       
	local count     = #convex
       
	for index = 1, count, 3 do
		local a = convex[index  ].pos
		local b = convex[index+1].pos
		local c = convex[index+2].pos
	       
		local normal    = (c-a):Cross(b-a):GetNormalized()
	       
		local proj	      = a:ProjectOnto( normal )
		local dist	      = proj:Length()
	       
		-- Projection is in the opposite direction
		if ( !normal:IsEqualTol( proj:GetNormalized(), 0.01 ) ) then
			dist = -dist
		end
			       
		-- Search for a plane with similar aspects
		local isMerged = false
	       
		for _, plane in pairs( planes ) do
			if ( normal:IsEqualTol( plane.normal, 0.05 ) and math.abs( dist - plane.dist ) < 1 ) then
				isMerged = true
				break
			end
		end
       
		if ( !isMerged ) then  
			table.insert( planes, { normal = normal, dist = dist } )
		end    
	end
       
	return planes
end
 
-- Planes -> Convex triangles
local function isClipped( vector, cnormal, cdist )
	local cpos = cnormal * cdist
	local off  = vector:ProjectOnto( cnormal ) - cpos

	return off:Dot( cnormal ) > 0
end
 
function physmesh.PlanesToConvex( planes )
	local mesh = {}
 
	for index, plane in pairs( planes ) do
		local normal    = plane.normal
	       
		local pos	       = normal * plane.dist
		local angle	     = normal:Angle()
	       
		local axisX = angle:Right() * 100000
		local axisY = angle:Up() * 100000
	       
		local vertexes = {
			pos - axisX + axisY,
			pos + axisX + axisY,
			       
			pos + axisX - axisY,
			pos - axisX - axisY,
		}
	       
		for cindex, cplane in pairs( planes ) do
			if ( cindex == index ) then continue end
       
			local cnormal   = cplane.normal
				       
	--[[    TODO: Parallel planes can clip each other entirely, this comparison could be extremely cheap!
			if ( cnormal == normal or cnormal == -normal ) then
				continue
			end
	]]--
       
			local cdist	     = cplane.dist
			local cpos	      = cnormal * cdist
		       
			local lastVertex	= vertexes[ #vertexes ]
			local lastIsClipped     = isClipped( lastVertex, cnormal, cdist )
	       
			local newVertexes = {}
		       
			for index, vertex in pairs( vertexes ) do
				local isClipped = isClipped( vertex, cnormal, cdist )
		       
				if ( isClipped != lastIsClipped ) then
					local ray = lastVertex - vertex
					local hit = util.IntersectRayWithPlane( vertex, ray, cpos, cnormal )
				       
					table.insert( newVertexes, hit )
				end
				       
				if ( !isClipped ) then
					table.insert( newVertexes, vertex )
				end
			       
				lastVertex	      = vertex
				lastIsClipped   = isClipped
			end
		       
			vertexes = newVertexes
		       
			if ( #vertexes == 0 ) then
				break -- The entire plane got clipped
			end
		end
	       
		-- Insert into physics mesh
		local count = #vertexes
		local baseVertex = vertexes[ 1 ]
		local lastVertex = vertexes[ 2 ]
	       
		for index = 3, count do
			local currVertex = vertexes[ index ]
	       
			table.insert( mesh, baseVertex )
			table.insert( mesh, currVertex )
			table.insert( mesh, lastVertex )
		       
			lastVertex = currVertex
		end	    
	end
 
	return mesh
end
 
function physmesh.PlanesToOutline( planes )
	local mesh = {}
 
	for index, plane in pairs( planes ) do
		local normal    = plane.normal
	       
		local pos	       = normal * plane.dist
		local angle	     = normal:Angle()
	       
		local axisX = angle:Right() * 50000
		local axisY = angle:Up() * 50000
	       
		local vertexes = {
			pos - axisX + axisY,
			pos + axisX + axisY,
			       
			pos + axisX - axisY,
			pos - axisX - axisY,
		}
	       
		for cindex, cplane in pairs( planes ) do
			if ( cindex == index ) then continue end
       
			local cnormal   = cplane.normal
				       
	--[[    TODO: Parallel planes can clip each other entirely, this comparison could be extremely cheap!
			if ( cnormal == normal or cnormal == -normal ) then
				continue
			end
	]]--
       
			local cdist	     = cplane.dist
			local cpos	      = cnormal * cdist
		       
			local lastVertex	= vertexes[ #vertexes ]
			local lastIsClipped     = isClipped( lastVertex, cnormal, cdist )
	       
			local newVertexes = {}
		       
			for index, vertex in pairs( vertexes ) do
				local isClipped = isClipped( vertex, cnormal, cdist )
		       
				if ( isClipped != lastIsClipped ) then
					local ray = lastVertex - vertex
					local hit = util.IntersectRayWithPlane( vertex, ray, cpos, cnormal )
				       
					table.insert( newVertexes, hit )
				end
				       
				if ( !isClipped ) then
					table.insert( newVertexes, vertex )
				end
			       
				lastVertex	      = vertex
				lastIsClipped   = isClipped
			end
		       
			vertexes = newVertexes
		       
			if ( #vertexes == 0 ) then
				break -- The entire plane got clipped
			end
		end
	       
		-- Insert into physics mesh
		mesh[index] = vertexes
	       
	end
 
	return mesh
end
