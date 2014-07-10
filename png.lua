
-- Copyright 2014 David Mentler

if SERVER then
	AddCSLuaFile()
	return
end
 
include( "circular_queue.lua" )
 
png     = png or {}
 
png.cModel      = png.cModel or ClientsideModel( "models/props_borealis/bluebarrel001.mdl", RENDERGROUP_TRANSLUCENT  )
png.cPanel      = png.cPanel or vgui.Create( "ModelImage" )
 
png.queue       = png.queue or CircularQueue( 128 )
 
local rTable = {
	ent = png.cModel,
	
	cam_pos = Vector(),
	cam_ang = Angle(),
	cam_fov = 90
}
 
-- Init cModel, cPanel
local model     = png.cModel
	model:SetNoDraw( true )
       
local panel     = png.cPanel
	panel:SetVisible( false )
       
	panel:SetMouseInputEnabled( false )
	panel:SetKeyboardInputEnabled( false )
 
	panel:SetSize( 32, 32 )
 
-- Internal functions
local function Render( name, wide, tall, func )
	-- Apply RenderOverride
	model.RenderOverride = func
       
	-- Make the icon render to the png file ( You MUST set the fake model LAST! )  
	panel:SetSize( wide, tall )
	panel:SetModel( "png/" .. name )
 
	panel:RebuildSpawnIconEx( rTable )
       
	return png.GetPath( name, wide, tall )
end
 
local function ProcessQueue()
	local queue     = png.queue
 
	if ( queue:IsEmpty() ) then return end
       
	local top = queue:Peek()
       
	-- Pop finished
	local path = top.path
       
	if ( path ) then       
		if ( top.cback ) then
			pcall( top.cback, path )
		end
	       
		queue:Pop()
		top = queue:Peek()
	       
		if ( !top ) then
			return
		end
	end
	       
	-- Process next
	if ( top.PreRender ) then
		local ok, err = pcall( top.PreRender, top )
	       
		if ( !ok ) then
			print( "PreRender failed: " .. err )
		end
		
		-- Delay rendering
		if ( err == false ) then
			return
		end
	end
       
	path = Render( top.name, top.w, top.h, top.func )
       
	if ( isfunction( top.cback ) ) then
		top.path = path	 -- Callback on next frame
	else
		queue:Pop()		     -- Pop
	end
end
 
hook.Add( "HUDPaint", "RenderToPNG", ProcessQueue )
 
-- API
function png.GetPath( name, wide, tall )
	local path = "spawnicons/png/" .. name:lower()
	local tall = tall or wide
       
	if ( wide == tall ) then
		if ( wide != 64 ) then
			path = path .. "_" .. wide
		end
	else
		path = path .. wide .. "x" .. tall
	end
    
	return path .. ".png"
end
 
function png.Render( name, wide, tall, func, cback )
	local entry = {
		name = name,
	       
		w = wide,
		h = tall,
	       
		func = func,
		cback = cback,
	}
 
	if ( !png.queue ) then
		png.queue = { entry }
		return entry
	end
       
	png.queue:Add( entry )
	return entry
end
 
function png.GetOrRender( name, wide, tall, func, cback )
	local path = png.GetPath( name, wide, tall )
       
	if ( !file.Exists( "materials/" .. path, "MOD" ) ) then
		png.Render( name, wide, tall, func, cback )
	else
		if ( isfunction( cback ) ) then
			cback( path )
		end
	end
end
