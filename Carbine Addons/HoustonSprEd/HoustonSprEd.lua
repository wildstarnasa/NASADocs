

-- Client lua script
require "Window"
require "Apollo"

local HoustonSprEd = {}


function HoustonSprEd:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function HoustonSprEd:Init()
	Apollo.RegisterAddon(self)
end

function HoustonSprEd:OnLoad()
	--Apollo.DPF("In Spred:OnLoad")
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)

	self.wndButtonViewGroup = Apollo.LoadForm("SprEdForms.xml", "ButtonView", nil, self)
	self.wndButtonViewGroup:Show(false)
	self.wndButtonView = self.wndButtonViewGroup:FindChild("View")
	self.wndButtons = {}
	self.wndButtons[1] = self.wndButtonView:FindChild("ButtonPress")
	self.wndButtons[2] = self.wndButtonView:FindChild("ButtonCheckBox")
	self.wndButtons[3] = self.wndButtonView:FindChild("ButtonDisabled")

	self.wndButtonTitle = self.wndButtonViewGroup:FindChild("Title")
	self.wndButtonTitles = {}
	self.wndButtonTitles [1] = self.wndButtonTitle:FindChild("TitlePress")
	self.wndButtonTitles [2] = self.wndButtonTitle:FindChild("TitleCheckBox")
	self.wndButtonTitles [3] = self.wndButtonTitle:FindChild("TitleDisabled")

	self.wndIconButtonViewGroup = Apollo.LoadForm("SprEdForms.xml", "IconButtonView", nil, self)
	self.wndIconButtonViewGroup:Show(false)
	self.wndIconButtonView = self.wndIconButtonViewGroup:FindChild("View")
	self.wndIconButtonSprites = {}
	self.wndIconButtonSprites[1] = self.wndIconButtonView:FindChild("UnderSprite")
	self.wndIconButtonSprites[2] = self.wndIconButtonView:FindChild("IconSprite")
	self.wndIconButtonSprites[3] = self.wndIconButtonView:FindChild("OverNormal")
	self.wndIconButtonSprites[4] = self.wndIconButtonView:FindChild("OverPressed")
	self.wndIconButtonSprites[5] = self.wndIconButtonView:FindChild("OverFlyby")
	self.wndIconButtonSprites[6] = self.wndIconButtonView:FindChild("OverPressedFlyby")
	self.wndIconButtonSprites[7] = self.wndIconButtonView:FindChild("OverDisabled")

	self.nIconLeft, self.nIconTop, self.nIconRight, self.nIconBottom = self.wndIconButtonViewGroup:GetRect()
	
	self.wndFramePreviewGroup = Apollo.LoadForm("SprEdForms.xml", "FramePreview", nil, self)
	self.wndSpriteViewGroup = Apollo.LoadForm("SprEdForms.xml", "SpriteView", nil, self)
	
	self:ResizeButtonView()
	self:ResizeIconButtonView()
	self:OnSpriteViewMove()
end

function HoustonSprEd:OnFrame()
	local nLeft, nTop, nRight, nBottom = self.wndIconButtonViewGroup:GetRect()
	if nLeft ~= self.nIconLeft or nTop ~= self.nIconTop or nBottom ~= self.nIconBottom or nRight ~= self.nRight then
		self:ResizeIconButtonView()
		self.nIconLeft, self.nIconTop, self.nIconRight, self.nIconBottom = self.wndIconButtonViewGroup:GetRect()
	end
end

function HoustonSprEd:OnLayerQueryDragDrop(wndHandler, wndControl, x, y, wndSource, strType, hNode)
	if strType == "Sprite" then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Invalid
end

function HoustonSprEd:OnLayerDragDrop(wndHandler, wndControl, x, y, wndTree, strType, hNode)
	OnLayerDragDrop(wndHandler, wndControl, x, y, wndTree, strType, hNode)
end


function HoustonSprEd:OnQueryBeginDragDropSpriteList(wndHandler, wndControl, x, y)

	local hNode = wndControl:HitTest(x, y)
	if hNode ~= nil then
		local strText = wndControl:GetNodeText(hNode)
		if strText == nil then
			return false
		end
		strSprite = "HoustonSprEd:" .. strText
		Apollo.BeginDragDrop(wndControl, "Sprite", strSprite, hNode)
		return true
	end
	return false
end

function HoustonSprEd:OnIconDragDropCancel()
	OnIconDragDropCancel()
end

function HoustonSprEd:OnIconDragDrop(wndControl, wndHandler, x, y, wndSource, strType, hNode)
	OnIconDragDrop(wndControl, wndHandler, x, y, wndSource, strType, hNode)
end

function HoustonSprEd:OnIconQueryDragDrop(wnd, wndControl, x, y, wndSource, pszType, nData)

	--Apollo.DPF("OnIconQueryDragDrop");
	if pszType == "Sprite" then	
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

--[[
function OnIconDragDrop(wnd, wndControl, x, y, wndSource, pszType, hNode)

	strMessage = "OnIconDragDrop (" .. x .. "," .. y .. ") Type='" .. pszType .. "' Data=" .. hNode;
	Apollo.DPF(strMessage);
	if pszType == "Sprite" then
		strSprite = "HoustonSprEd:" .. wndSource:GetNodeText(hNode);
		strMessage = "Sprite = " .. strSprite;
		Apollo.DPF(strMessage);
		wndControl:SetSprite(strSprite);
		return true;
	end

	return false;
end
--]]

---------------------------------------------------------------------------------------------------
-- ButtonView Functions
---------------------------------------------------------------------------------------------------

function HoustonSprEd:OnButtonViewMove()
	self:ResizeButtonView()
	OnPreviewMoved()
end

function HoustonSprEd:ResizeButtonView()
    
	local nMargin = 15
	local nGap = 5

	self:ResizeView( self.wndButtonView, self.wndButtons, nMargin, nGap )
    self:ResizeView( self.wndButtonTitle, self.wndButtonTitles, 0, 0 )

end

function HoustonSprEd:ResizeView( wndParent, arChildren, nMargin, nGap )

	local nChildenCount = #arChildren
	local nLeft, nTop, nRight, nBottom = wndParent:GetRect()
	local nWidth = nRight - nLeft
	local nHeight = nBottom - nTop
    local nChildWidth = ( nWidth - (nMargin*2) - (nGap*(nChildenCount-1)) )/nChildenCount 
    local nChildHeight = nHeight - (nMargin*2)

	local strOut;
	strOut = "Rect: " .. nLeft.. ", " .. nTop.. ", " .. nRight.. ", " .. nBottom
	strOut = strOut .. "\nChild: " .. nChildWidth .. " x " .. nChildHeight 

	local nChildLeft = nMargin
    local nChildTop = nMargin
	
	for i = 1, #arChildren do
		arChildren[i]:Move( nChildLeft, nChildTop, nChildWidth, nChildHeight )
		strOut = strOut .. "\nChild" .. i .. ": " .. nChildLeft .. ", " .. nChildTop
		nChildLeft = nChildLeft + nChildWidth + nGap
	end

	-- Apollo.DPF( strOut )

end


---------------------------------------------------------------------------------------------------
-- IconButtonView Functions
---------------------------------------------------------------------------------------------------
function HoustonSprEd:OnIconButtonViewMove()
	self:ResizeIconButtonView()
end

function HoustonSprEd:ResizeIconButtonView()
    
	local nMargin = 15
	local nGap = 5

	self:ResizeView( self.wndIconButtonView, self.wndIconButtonSprites, nMargin, nGap )

end

function HoustonSprEd:OnIconButtonViewShow( wndHandler, wndControl )
	self:ResizeIconButtonView()
end

function HoustonSprEd:OnIconButtonView()
end

---------------------------------------------------------------------------------------------------
-- SpriteView Functions
---------------------------------------------------------------------------------------------------

function HoustonSprEd:OnSpriteViewMove( wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom )
	
	local nLeft, nTop, nRight, nBottom = self.wndSpriteViewGroup:GetRect()
	if  nRight == nOldRight and nBottom == nOldBottom then
		return
	end
	
	local nPreviewLeft, nPreviewTop, nPreviewRight, nPreviewBottom = self.wndFramePreviewGroup:GetRect()
	
	self.wndFramePreviewGroup:Move( nRight+5, nPreviewTop, nRight-nLeft, nBottom-nTop )

	OnPreviewMoved()
end

---------------------------------------------------------------------------------------------------
-- FramePreview Functions
---------------------------------------------------------------------------------------------------

function HoustonSprEd:OnFramePreviewMove( wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom )

	local nLeft, nTop, nRight, nBottom = self.wndFramePreviewGroup:GetRect()
	if  nRight == nOldRight and nBottom == nOldBottom then
		return
	end
	
	local nSpriteViewLeft, nSpriteViewTop, nSpriteViewRight, nSpriteViewBottom = self.wndSpriteViewGroup:GetRect()
	
	
	self.wndSpriteViewGroup:Move( nSpriteViewLeft, nSpriteViewTop, ((nRight-nSpriteViewLeft-5)/2), nBottom-nTop )
	
	nSpriteViewLeft, nSpriteViewTop, nSpriteViewRight, nSpriteViewBottom = self.wndSpriteViewGroup:GetRect()
	self.wndFramePreviewGroup:Move( nSpriteViewRight+5, nTop, nRight-nSpriteViewRight-5, nBottom-nTop )
	
	OnPreviewMoved()
end

---------------------------------------------------------------------------------------------------
-- HoustonSprEd Instance
---------------------------------------------------------------------------------------------------

local SprEdInstance = HoustonSprEd:new()
HoustonSprEd:Init()
