
-- Copyright 2014 David Mentler


include( "struct.lua" )

local function link_single( decoder, name, isLocal )
	return function( stream, obj, base )
		local pos = stream:Tell()
		
		local offset = obj[name]
		
		stream:Seek( isLocal and (base + offset) or offset )
		local value = decoder( stream )

		stream:Seek( pos )
		return value
	end
end

local function link_dynamic( decoder, name, isLocal )
	return function( stream, obj, base )
		local pos = stream:Tell()
		
		local array = {}
		
		local limit  = obj[name .. "Count"]
		local offset = obj[name .. "Offset"]
		
	--	obj[name .. "Count"]  = nil
	--	obj[name .. "Offset"] = nil
		
		stream:Seek( isLocal and (base + offset) or offset )
		for index = 1, limit do
			array[index] = decoder( stream )
		end

		stream:Seek( pos )
		return array
	end
end

local mdl_texture	= struct(
	t_int,	"nameOffset",
	t_int,	"used",
	
	t_int,	nil,	-- unknown
	t_int,	nil,	-- materialP
	t_int,	nil,	-- clientMaterialP
	
	array( t_int, 8 ),	nil,	-- unknown
	
	link_single( t_string, "nameOffset", true ), "name"
)
local mdl_texture_path	= struct(
	t_int,	"pathOffset",
	
	link_single( t_string, "pathOffset", false ), "path"
)

local mdl_mesh		= struct(
	t_int,	"materialIndex",
	t_int,	"modelOffset",
	
	t_int,	"vertexCount",
	t_int,	"vertexIndexStart",
	
	t_int,	"flexCount",
	t_int,	"flexOffset",
	
	t_int,	"materialType",
	t_int,	"materialParam",
	
	t_int,	"id",
	
	t_vector,	"center",
	
	t_int,	nil, -- "modelVertexDataP",
	
	array( t_int, 8 ),	"lodVertexCount",
	array( t_int, 8 ),	nil
)
local mdl_model		= struct(
	str( 64 ),	"name",
	t_int,		"type",
	
	t_float,	"boundingRadius",
	
	t_int,	"meshCount",
	t_int,	"meshOffset",
	
	t_int,	"vertexCount",
	t_int,	"vertexOffset",
	
	link_dynamic( mdl_mesh, "mesh", true ), "meshes"
)
local mdl_bodypart	= struct(
	t_int,	"nameOffset",
	t_int,	"modelCount",
	
	t_int,	"base",
	t_int,	"modelOffset",
	
	link_dynamic( mdl_model, "model", true ), "models"
)
local mdl_header 	= struct(
	t_int,	"id",
	t_int,	"version",
	
	t_int,	"checksum",
	
	str( 64 ),	"name",
	t_int,		"fsize",
	
	t_vector,	"eyePosition",
	t_vector,	"illuminationPosition",
	
	t_vector,	"hullMinPosition",
	t_vector,	"hullMaxPosition",
	
	t_vector,	"viewBoundingBoxMin",
	t_vector,	"viewBoundingBoxMax",
	
	t_int,	"flags",
	
	t_int,	"boneCount",
	t_int,	"boneOffset",
	
	t_int,	"boneControllerCount",
	t_int,	"boneControllerOffset",
	
	t_int,	"hitboxSetCount",
	t_int,	"hitboxSetOffset",
	
	t_int,	"localAnimationCount",
	t_int,	"localAnimationOffset",
	
	t_int,	"localSequenceCount",
	t_int,	"localSequenceOffset",
	
	t_int,	"activityListVersion",
	
	t_int,	"eventsIndexed",
	
	t_int,	"textureCount",
	t_int,	"textureOffset",
	
	t_int,	"texturePathCount",
	t_int,	"texturePathOffset",
	
	t_int,	"skinReferenceCount",
	t_int,	"skinFamilyCount",
	t_int,	"skinFamilyOffset",
	
	t_int,	"bodyPartCount",
	t_int,	"bodyPartOffset",
	
	link_dynamic( mdl_bodypart, "bodyPart", false ), "parts",
	
	link_dynamic( mdl_texture,		"texture",		false ), "textures",
	link_dynamic( mdl_texture_path, "texturePath",	false ), "paths"
)


function decodeMDL( path )
	local stream = file.Open( path .. ".mdl", "rb", "GAME" )
	local header = mdl_header( stream )

	stream:Close()
	return header
end



local vvd_header	= struct(
	t_int,	"id",
	
	t_int,	"version",
	t_int,	"checksum",
	
	t_int,	"lodCount",
	array( t_int, 8 ),	"lodVertexCount",
	
	t_int,	"fixupCount",
	t_int,	"fixupTableOffset",
	
	t_int,	"vertexDataOffset",
	t_int,	"tangentDataOffset"
)
local vvd_vertex	= struct(
	array( t_float, 3 ),	nil, -- "boneWeights"
	array( t_byte,  3 ),	nil, -- "bones"
	
	t_byte,	nil, -- "boneCount"
	
	t_vector,	"pos",
	t_vector,	"normal",
	t_float,	"u",
	t_float,	"v"
)

function decodeVVD( path )
	local stream = file.Open( path .. ".vvd", "rb", "GAME" )
	
	local header = vvd_header( stream )
	local verts  = {}
	
	stream:Seek( header.vertexDataOffset )
	for index = 1, header.lodVertexCount[1] do
		verts[index] = vvd_vertex( stream )
	end
	
	stream:Close()
	
	header.verts = verts
	return header
end




local vtx_vertex = struct(
	array( t_byte, 3 ),	nil,	-- boneWeightIndexes
	
	t_byte,	"boneCount",
	t_short, "vertIndex",	-- originalMeshVertexIndex
	
	array( t_byte, 3 ), nil		-- boneIds	
)
local vtx_strip = struct(
	t_int,	"indexCount",
	t_int,	"indexMeshIndex",
	
	t_int,	"vertexCount",
	t_int,	"vertexMeshIndex",
	
	t_short,	nil,	-- boneCount
	t_byte,		nil,	-- flags
	
	t_int,		nil,
	t_int,		nil
)
local vtx_strip_group = struct(
	t_int,	"vertexCount",
	t_int,	"vertexOffset",
	
	t_int,	"indexCount",
	t_int,	"indexOffset",
	
	t_int,	"stripCount",
	t_int,	"stripOffset",
	
	t_byte,	"flags",
	
	link_dynamic( t_short,   "index", true ), "indexes",
	
	link_dynamic( vtx_strip,  "strip",  true ), "strips",
	link_dynamic( vtx_vertex, "vertex", true ), "verts"
)
local vtx_mesh = struct(
	t_int,	"stripGroupCount",
	t_int,	"stripGroupOffset",
	
	t_byte,	"flags",
	
	link_dynamic( vtx_strip_group, "stripGroup", true ), "groups"
)
local vtx_lod = struct(
	t_int,	"meshCount",
	t_int,	"meshOffset",
	
	t_float,	"switchPoint",
	
	link_dynamic( vtx_mesh, "mesh", true ), "meshes"
)
local vtx_model = struct( 
	t_int,	"lodCount",
	t_int,	"lodOffset",
	
	link_dynamic( vtx_lod, "lod", true ), "lods"
)
local vtx_bodypart = struct(
	t_int,	"modelCount",
	t_int,	"modelOffset",
	
	link_dynamic( vtx_model, "model", true ), "models"
)
local vtx_header = struct(
	t_int,	"version",
	
	t_int,	"vertexCacheSize",
	
	t_short,	"maxBonesPerStrip",
	t_short,	"maxBonesPerTri",
	t_int,	"maxBonesPerVertex",
	
	t_int,	"checksum",
	
	t_int,	"lodCount",
	t_int,	nil,	-- ???
	
	t_int,	"bodyPartCount",
	t_int,	"bodyPartOffset",
	
	link_dynamic( vtx_bodypart, "bodyPart", false ), "parts"
)

function decodeVTX( path )
	local stream = file.Open( path .. ".dx80.vtx", "rb", "GAME" )
	local header = vtx_header( stream )
	
	stream:Close()
	return header
end
