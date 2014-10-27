
local function getVertex( map, index, face )
	local vertex = map.verts[ index ]
		vertex = table.Copy( vertex )
	
	-- TODO: This is temporary
	local light = face.lightmap
	
	local offX = (light % 8) /8
	local offY = math.floor( light / 8 ) /2
	
	vertex.light_u	= vertex.light_u /8 + offX
	vertex.light_v	= vertex.light_v /2 + offY

	vertex.color	= Color( 40, 40, 40 )
	
	return vertex
end
local function getMVertex( map, base, index, face )	
	local off = map.mverts[ index ] +1
	
	return getVertex( map, base + off, face )
end


local function renderFacePolygon( map, face, mesh )
	local off = face.vertex_off
	local num = face.vertex_num
	
	local base = getVertex( map, off +1, face )
	local last = getVertex( map, off +2, face )
	
	for index = 3, num do
		local curr = getVertex( map, off + index, face )
	
		table.insert( mesh, base )
		table.insert( mesh, last )
		table.insert( mesh, curr )
	
		last = curr
	end
end

local function renderFacePatch( map, face, mesh )
	local off = face.vertex_off
	local num = face.vertex_num
	
	local countX = face.patchX -- These are vertex counts!
	local countY = face.patchY

	local controls = {{},{},{}}
	
	for yIndex = 0, countY -2, 2 do -- yIndex, and xIndex are the top right vertex indexes
		for xIndex = 0, countX -2, 2 do
			local offset = off + yIndex * countX + xIndex +1
			
			-- Get patch control points
			for y = 0, 2 do
				for x = 0, 2 do
					controls[y +1][x +1] = getVertex( map, offset + countX * y + x, face )
				end
			end
			
			-- Calculate vertexes
			local iter = map.patch_res or 4
			
			local procX = 1/iter
			local procY = 1/iter
			
			local history = {}
			local index = 1
			
			-- Add subvertexes
			for fracY = 0, 1, procY do
				for fracX = 0, 1, procX do
					local point = quake.CalcPatchVertex( controls, fracX, fracY )
					
					local ahead		= history[index +1]	-- All points are from the above line
					local above 	= history[index]
					
					if ( above and ahead ) then
						table.insert( mesh, ahead )
						table.insert( mesh, above )
						table.insert( mesh, point )
					end
					
					local behind	= history[index -1] -- Behind from the same line
					
					if ( above and behind ) then
						table.insert( mesh, point )
						table.insert( mesh, above )
						table.insert( mesh, behind )
					end
					
					history[index] = point
					index = index +1
				end
				
				index = 1
			end

			-- End of single Bezier patch
		end
	end
end

local function renderFaceMesh( map, face, mesh )
	local vOff = face.vertex_off
		
	local mOff = face.mvertex_off
	local num  = face.mvertex_num
	
	for index = 1, num, 3 do
		table.insert( mesh, getMVertex( map, vOff, mOff + index, face ) )
		table.insert( mesh, getMVertex( map, vOff, mOff + index +1, face ) )
		table.insert( mesh, getMVertex( map, vOff, mOff + index +2, face ) )
	end
end


function quake.RenderFace( map, face, mesh )
	local f_type = face.type
	
	if     ( f_type == TYPE_POLYGON ) then renderFacePolygon( map, face, mesh )
	elseif ( f_type == TYPE_PATCH )   then renderFacePatch( map, face, mesh )
	elseif ( f_type == TYPE_MESH )    then renderFaceMesh( map, face, mesh )
	end
end
