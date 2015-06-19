local ItemWindowSubclass = {}
local ItemWindowSubclassRegistrarInst = {}

function ItemWindowSubclass:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ItemWindowSubclass:OnAttached(wnd, strParam)
end

function ItemWindowSubclass:OnDetached(wnd)
end

function ItemWindowSubclass:OnDestroyed(wnd)
end

function ItemWindowSubclass:OnHide(wnd)
end

function ItemWindowSubclass:OnShow(wnd)
end

function ItemWindowSubclass:OnShowing(wnd, fShown)
end

function ItemWindowSubclass:OnHiding(wnd, fShown)
end

function ItemWindowSubclass:OnShowComplete(wnd)
end

function ItemWindowSubclass:OnHideComplete(wnd)
end

function ItemWindowSubclass:SetItem(itemCurr)
    if not itemCurr or (not Item.isInstance(itemCurr) and not Item.isData(itemCurr)) then
	    self:SetItemData(itemCurr, #ItemWindowSubclassRegistrarInst.arQualityColors + 1, "")
	    return
	end
	if itemCurr then
		local eQuality = Item.GetDetailedInfo(itemCurr).tPrimary.eQuality
		if eQuality == 0 then
			eQuality = itemCurr:GetItemQuality()
		end
		self:SetItemData(itemCurr, eQuality, itemCurr:GetIcon())
	end
end

function ItemWindowSubclass:SetItemData(itemCurr, eQuality, strIcon)
	self.eQuality = eQuality
	self.strIcon = strIcon
	self.wnd:SetData(itemCurr) -- Can be nil
	self.wnd:SetSprite(self.strIcon)
	if self.tPixieOverlay == nil then
		self.tPixieOverlay =
		{
			strSprite = ItemWindowSubclassRegistrarInst.arQualitySprites[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualitySprites))],
			loc = {fPoints = {0, 0, 1, 1}, nOffsets = {0, 0, 0, 0}},
			--cr = ItemWindowSubclassRegistrarInst.arQualityColors[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualityColors))]
		}
		self.tPixieOverlay.id = self.wnd:AddPixie(self.tPixieOverlay)
	else
		self.tPixieOverlay.strSprite = ItemWindowSubclassRegistrarInst.arQualitySprites[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualitySprites))]
		--self.tPixieOverlay.cr = ItemWindowSubclassRegistrarInst.arQualityColors[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualityColors))]
		self.wnd:UpdatePixie(self.tPixieOverlay.id, self.tPixieOverlay)
	end
end

function ItemWindowSubclass:OnMouseButtonUp(wndHandler, wndControl, eMouseButton)
	if wndHandler and wndHandler == wndControl then
		local itemArg = self.wnd:GetData()
		local bCorrectKey = eMouseButton == GameLib.CodeEnumInputMouse.Right and (Apollo.IsShiftKeyDown() or Apollo.IsControlKeyDown() or Apollo.IsAltKeyDown())
		if bCorrectKey and itemArg and (Item.isInstance(itemArg) or Item.isData(itemCurr)) then
			Event_FireGenericEvent("GenericEvent_ContextMenuItem", itemArg)
			return
		end
	end
end

local ItemWindowSubclassRegistrar = {}

function ItemWindowSubclassRegistrar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.arQualityColors =
	{
		ApolloColor.new("ItemQuality_Inferior"),
		ApolloColor.new("ItemQuality_Average"),
		ApolloColor.new("ItemQuality_Good"),
		ApolloColor.new("ItemQuality_Excellent"),
		ApolloColor.new("ItemQuality_Superb"),
		ApolloColor.new("ItemQuality_Legendary"),
		ApolloColor.new("ItemQuality_Artifact"),
		ApolloColor.new("00000000")
	}

	o.arQualitySprites =
	{
		"UI_RarityBorder_Grey",
		"UI_RarityBorder_White",
		"UI_RarityBorder_Green",
		"UI_RarityBorder_Blue",
		"UI_RarityBorder_Purple",
		"UI_RarityBorder_Orange",
		"UI_RarityBorder_Pink",
		"UI_RarityBorder_White",
	}

    return o
end

function ItemWindowSubclassRegistrar:Init()
    Apollo.RegisterAddon(self)
	local tEventHandlers =
	{
		{strEvent = "MouseButtonUp", strFunction = "OnMouseButtonUp"},
	}
	Apollo.RegisterWindowSubclass("ItemWindowSubclass", self, tEventHandlers)
end

-----------------------------------------------------------------------------------------------
-- ItemWindowSubclassRegistrar:OnLoad
-----------------------------------------------------------------------------------------------

function ItemWindowSubclassRegistrar:OnLoad()

end

function ItemWindowSubclassRegistrar:SubclassWindow(wndNew, strSubclass, strParam)
	local subclass = ItemWindowSubclass:new({wnd = wndNew})
	wndNew:SetWindowSubclass(subclass, strParam)
end

ItemWindowSubclassRegistrarInst = ItemWindowSubclassRegistrar:new()
ItemWindowSubclassRegistrarInst:Init()
