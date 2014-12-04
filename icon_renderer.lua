
-- Copyright 2014 David Mentler

local iconW = 128
local iconH = 128


-- The icon is rendered to this
local iconRT  = GetRenderTarget( "icon_rt", iconW, iconH )
local iconMat = CreateMaterial(  "icon_rt", "UnlitGeneric", {
	[ "$basetexture" ] = iconRT:GetName(),
	[ "$vertexalpha" ] = 1,
} )


-- The model is rendered to this
local modelRT  = GetRenderTarget( "model_rt", iconW, iconH )
local modelMat = CreateMaterial( "icon_shadow", "UnlitGeneric", {
	[ "$basetexture" ] = modelRT:GetName(),
	[ "$alphatest" ] = 1
} )


-- Tiled background
local iconStripe = Material( "tshop_icon/stripe.png",  "smooth noclamp" )
local iconError  = Material( "tshop_icon/unknown.png", "smooth" )

-- Stencil 'library'
local stencil = {
	Clear 			= render.ClearStencil,
	ClearBuffers 	= render.ClearBuffersObeyStencil,

	Enable 			= render.SetStencilEnable,
	ReferenceValue 	= render.SetStencilReferenceValue,

	CompareFunction = render.SetStencilCompareFunction,

	PassOperation 	= render.SetStencilPassOperation,
	FailOperation 	= render.SetStencilFailOperation,
	ZFailOperation 	= render.SetStencilZFailOperation
}


function render.ClearTransparent()
	render.OverrideAlphaWriteEnable( true, true )
	
	render.Clear( 0,0,0, 0 )
	
	render.OverrideAlphaWriteEnable( false )
end


local function isError( path )
	return !file.Exists( path, "GAME" )	-- TODO: Ehh
end


local function renderOutline( border, step )
	for ang = 0, math.pi *2, step do
		local x = math.sin( ang ) *border
		local y = math.cos( ang ) *border

		surface.DrawTexturedRect( x, y, iconW, iconH )
	end
end

function tshop.RenderModelIcon( model, scene )
	local cModel = ClientsideModel( model, RENDERGROUP_BOTH )

	if !scene then
		scene = PositionSpawnIcon( cModel, vector_origin )
	end

	local view  = {
		type = "3D",

		origin = scene.origin,
		angles = scene.angles,

		x = 0,
		y = 0,
		w = iconW,
		h = iconH,

		aspect = iconW/iconH,
		fov    = scene.fov
	}

	render.SetStencilWriteMask( 7 ) -- Fix halo lib
	render.SetStencilTestMask( 7 )

	-- Render model
	if isError( model ) then
		modelMat:SetTexture( "$basetexture", iconError:GetTexture("$basetexture") )
	else
		modelMat:SetTexture( "$basetexture", modelRT )

		render.PushRenderTarget( modelRT )

			render.Clear( 0,0,0, 255 )
			render.ClearDepth()

			cam.Start( view )

				-- Fill RT where we draw
				stencil.Clear()
				stencil.Enable( true )

				stencil.ReferenceValue( 1 )

				stencil.PassOperation( STENCIL_REPLACE )
				stencil.FailOperation( STENCIL_KEEP )
				stencil.ZFailOperation( STENCIL_KEEP )

				stencil.CompareFunction( STENCIL_ALWAYS )

				-- Render model
				render.OverrideAlphaWriteEnable( true, false )
					
					cModel:DrawModel()
					cModel:Remove()

				render.OverrideAlphaWriteEnable( false )
		
				-- Hack to make the RT transparent
				stencil.CompareFunction( STENCIL_NOTEQUAL )
				stencil.ClearBuffers( 0,0,0, 0 )

				stencil.Enable( false )

			cam.End()
		render.PopRenderTarget()
	end

	-- Render icon
	do
		render.PushRenderTarget( iconRT )
			render.SetViewPort( 0, 0, iconW, iconH )

			render.ClearTransparent()
			render.ClearDepth()

			cam.Start2D()

				-- Setup the shadow icon to work with
				surface.SetMaterial( modelMat )
				surface.SetDrawColor( 255, 255, 255 )

				stencil.Clear()
				stencil.Enable( true )

				-- Stencil pass
				do
					stencil.CompareFunction( STENCIL_NEVER )

					stencil.PassOperation( STENCIL_REPLACE )
					stencil.FailOperation( STENCIL_REPLACE )
					stencil.ZFailOperation( STENCIL_REPLACE )

					-- Render outer outline (black)
					stencil.ReferenceValue( 2 )
					renderOutline( 10, 0.1 )

					-- Render inner border (black)
					surface.DrawOutlinedRect( 4, 4, iconW -8, iconH -8 )

					
					-- Render middle outline (transparent)
					stencil.ReferenceValue( 1 )
					renderOutline( 6, 0.1 )


					-- Render inner outline (black)
					stencil.ReferenceValue( 3 )
					renderOutline( 3, 0.1 )


					-- Render outer border (black)
					stencil.ReferenceValue( 4 )
					surface.DrawOutlinedRect( 0, 0, iconW,    iconH    )
					surface.DrawOutlinedRect( 1, 1, iconW -2, iconH -2 )


					-- Render middle border (transparent)
					stencil.ReferenceValue( 1 )

					surface.DrawOutlinedRect( 2, 2, iconW -4, iconH -4 )
					surface.DrawOutlinedRect( 3, 3, iconW -6, iconH -6 )


					-- Stencil is read only from now
					stencil.PassOperation( STENCIL_KEEP )
					stencil.FailOperation( STENCIL_KEEP )
					stencil.ZFailOperation( STENCIL_KEEP )
				end

				-- Background pass
				do
					-- Paint stripes where it is not transparent
					stencil.ReferenceValue( 0 )
					stencil.CompareFunction( STENCIL_EQUAL )

					surface.SetDrawColor( 40, 40, 40, 140 )
					surface.DrawRect( 0, 0, iconW, iconH )

					surface.SetMaterial( iconStripe )
					surface.SetDrawColor( 0, 0, 0 )

					local u = iconW / 64
					local v = iconH / 64

					surface.DrawTexturedRectUV( 0, 0, iconW, iconH, 0, 0, u, v )
				end

				-- Outline pass
				do
					-- Paint black where outlines are
					stencil.ReferenceValue( 1 )
					stencil.CompareFunction( STENCIL_LESS )
					
					surface.SetDrawColor( 0,0,0 )
					surface.DrawRect( 0, 0, iconW, iconH )

					-- Blur the outlines a bit
					stencil.CompareFunction( STENCIL_ALWAYS )

					render.BlurRenderTarget( iconRT, 1, 1, 2 )
				end

				-- Foreground pass
				do
					stencil.ReferenceValue( 3 )
					stencil.CompareFunction( STENCIL_EQUAL )

					surface.SetMaterial( modelMat )
					surface.SetDrawColor( 255, 255, 255 )

					surface.DrawTexturedRect( 0, 0, iconW, iconH )
				end

				stencil.Enable( false )

			cam.End2D()
		render.PopRenderTarget()
	end

	return iconMat
end
