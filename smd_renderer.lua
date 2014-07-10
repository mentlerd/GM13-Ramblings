
-- Copyright 2014 David Mentler


-- Lets do this ....
local model		= "models/props_wasteland/laundry_dryer002"
local material	= Material( "models/props_wasteland/laundry_machines002" )

MDL	= decodeMDL( model )
VVD	= decodeVVD( model )
VTX	= decodeVTX( model )

if ( VVD.fixupCount != 0 ) then
	error( "The model has fixup tables!" )
end

local wire = Material( "models/wireframe" )

local function mesh_Vertex( vertex )
	mesh.Position( vertex.pos )
	mesh.Normal( vertex.normal )
	mesh.TexCoord( 0, vertex.u, vertex.v )
	
	mesh.AdvanceVertex()
end

hook.Add( "PostDrawOpaqueRenderables", "DrawVVD", function()
	local lods = VTX.parts[1].models[1].lods
	
	local base = lods[ math.floor( CurTime() )%( #lods -1 ) +1 ]
	
	if !base then return end
	
	local indexes 	= base.meshes[1].groups[1].indexes
	local verts		= base.meshes[1].groups[1].verts

	local tris = #indexes /3

	render.SetMaterial( material )
	render.SuppressEngineLighting( true )
	
	mesh.Begin( MATERIAL_TRIANGLES, tris )
		
	for triBase = 1, #indexes, 3 do
		local A = VVD.verts[ verts[ indexes[triBase +0] +1 ].vertIndex +1 ]
		local B = VVD.verts[ verts[ indexes[triBase +1] +1 ].vertIndex +1 ]
		local C = VVD.verts[ verts[ indexes[triBase +2] +1 ].vertIndex +1 ]
		
		mesh_Vertex( A ) 
		mesh_Vertex( B ) 
		mesh_Vertex( C )		
	end

	mesh.End()

	
	render.SuppressEngineLighting( false )
end )
