
local function getInfluence( index, frac )
	local binomial = ( index == 1 and 2 or 1 )

	return binomial * frac^index * (1-frac)^(2-index)
end

function quake.CalcPatchVertex( patch, fracX, fracY )
	local pX, pY, pZ = 0, 0, 0
	local nX, nY, nZ = 0, 0, 0
	
	local cR, cG, cB = 0, 0, 0
	
	local pU, 	pV 	= 0, 0
	local pLU,	pLV	= 0, 0
	
	for y = 0, 2 do
		for x = 0, 2 do
			local scale = getInfluence(y, fracY)*getInfluence(x, fracX)
			
			if ( scale != 0 ) then
				local control = patch[y +1][x +1]
			
				local color	 = control.color
				local pos	 = control.pos
				local normal = control.normal
				
				pX = pX + pos.x * scale
				pY = pY + pos.y * scale
				pZ = pZ + pos.z * scale
				
				cR = cR + color.r * scale
				cG = cG + color.g * scale
				cB = cB + color.b * scale
				
				nX = nX + normal.x * scale
				nY = nY + normal.y * scale
				nZ = nZ + normal.z * scale
				
				pU = pU + control.u * scale
				pV = pV + control.v * scale

				pLU = pLU + control.light_u * scale
				pLV = pLV + control.light_v * scale
			end
		end
	end
	
	return { 
		pos 	= Vector( pX, pY, pZ ), 
		normal 	= Vector( nX, nY, nZ ),
		color 	= Color( cR, cG, cB ),

		u = pU,
		v = pV,
		
		light_u = pLU,
		light_v = pLV
	}
end
