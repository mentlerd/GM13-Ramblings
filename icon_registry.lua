
-- Copyright 2014 David Mentler

include( "circular_queue.lua" )

tshop.IconQueue	= tshop.IconQueue or CircularQueue()
tshop.IconHash  = tshop.IconHash  or {}

local queue = tshop.IconQueue
local hash  = tshop.IconHash

local function getIconPath( model )
	return string.format( "spawnicons/tshop/%s.png", model:match( "(.+).mdl" ) )
end

local function getIconUID( model )
	return "tshop/" .. model:lower()
end


function tshop.RequestIcon( model, panel )
	local iconID  = getIconUID( model )
	local pending = hash[iconID]

	if pending then
		table.insert( pending, panel )
		return
	end

	-- Check if the icon exists
	local path = getIconPath( model )

	if file.Exists( "materials/" .. path, "MOD" ) then
		panel.Icon = Material( path )
		return
	end

	hash[iconID] = { panel }
	queue:Add( model )
end

do
	tshop.rIcon  = tshop.rIcon  or vgui.Create( "ModelImage" )
	tshop.rModel = tshop.rModel or ClientsideModel( "error" )

	local rIcon  = tshop.rIcon
	local rModel = tshop.rModel

	local rTable = {
		ent = rModel,
		
		cam_pos = Vector(),
		cam_ang = Angle(),
		cam_fov = 90
	}

	local rTexture


	rIcon:SetVisible( false )
	rIcon:SetSize( 64, 64 )

	rModel:SetNoDraw( true )

	function rModel:RenderOverride()
		if not rTexture then return end
		
		cam.Start2D()
			surface.SetMaterial( rTexture )
			surface.SetDrawColor( 255, 255, 255 )

			surface.DrawTexturedRect( 0, 0, 128, 128 )
		cam.End2D()
	end

	hook.Add( "HUDPaint", "TShop: ProcessIconQueue", function()
		if queue:IsEmpty() then
			return
		end

		-- Render icon
		local model = queue:Pop()

		rTexture = tshop.RenderModelIcon(model)

		rIcon:SetModel( getIconUID(model) )
		rIcon:RebuildSpawnIconEx( rTable )
	end )

	hook.Add( "SpawniconGenerated", "TShop: IconPopulate", function( model, image )
		local pending = hash[model]

		if pending then
			local path = image:gsub( "materials\\", "" )
			local icon = Material( path )

			-- Force the icon to refresh
			icon:GetTexture( "$basetexture" ):Download()

			for index, panel in ipairs( pending ) do
				panel.Icon = icon
			end

			hash[model] = nil
		end

		if !pending then
			print( model )
		end
	end )

end
