
local PANEL = {}

PANEL.Grip    = 6
PANEL.Padding = 0

function PANEL:Init()
	self:SetMouseInputEnabled( true )
--	self:SetPaintBackground( false )

	self:SetSize( 64, 64 )
end

function PANEL:Setup( side, panel, tall )
	self:SetSide( side )
	self:SetTall( tall )
	
	panel:SetParent( self )
	panel:Dock( FILL )
end

function PANEL:SetSide( side )
	self.Align      =  side
	self.IsVertical = (side == LEFT or side == RIGHT)

	self:SetGripSize( 4 )

	return self
end

function PANEL:SetGripSize( size )
	self.Grip = size

	local align   = self.Align
	local padding = self.Padding 

	if align == TOP then
		self:DockPadding( padding, padding, padding, size )
	elseif align == RIGHT then
		self:DockPadding( size, padding, padding, padding )
	elseif align == LEFT then
		self:DockPadding( padding, padding, size, padding )
	elseif align == BOTTOM then
		self:DockPadding( padding, size, padding, padding )
	end

	self:Dock( align )
end

function PANEL:CanSizeAt( x, y )	
	local align = self.Align
	local grip  = self.Grip

	if align == TOP then
		return y >= self:GetTall() - grip
	elseif align == RIGHT then
		return x <= grip
	elseif align == LEFT then
		return x >= self:GetWide() - grip
	elseif align == BOTTOM then
		return y <= grip
	end
end

function PANEL:Paint()
end

function PANEL:OnMousePressed( code )
	if code != MOUSE_LEFT then return end

	local x, y = self:ScreenToLocal( gui.MousePos() )

	if self:CanSizeAt( x, y ) then
		self.Resizing = true
		self:MouseCapture( true )
	end
end

function PANEL:OnMouseReleased( code )
	if code != MOUSE_LEFT then return end
	
	self.Resizing = false
	self:MouseCapture( false )
end

function PANEL:OnCursorMoved( x, y )
	if self.Resizing then
		local align = self.Align

		if align == TOP then
			self:SetTall( y )
		elseif align == RIGHT then
			self:SetWide( self:GetWide() - x )
		elseif align == LEFT then
			self:SetWide( x )
		elseif align == BOTTOM then
			self:SetTall( self:GetTall() - y )
		end
	end

	if self.Resizing or self:CanSizeAt( x, y ) then
		self:SetCursor( self.IsVertical and "sizewe" or "sizens" )
	else
		self:SetCursor( "arrow" )
	end
end

vgui.Register( "DResizableDock", PANEL, "DPanel" )
