local ItemWindowSubclass = {}
local ItemWindowSubclassRegistrarInst = {}

function ItemWindowSubclass:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

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
    if not itemCurr or (not Item.isInstance(itemCurr)  and not Item.isData(itemCurr)) then
	    self:SetItemData(#ItemWindowSubclassRegistrarInst.arQualityColors + 1, "")
	    return
	end
	if itemCurr then
		local eQuality = Item.GetDetailedInfo(itemCurr).tPrimary.eQuality
		if eQuality == 0 then
			eQuality = itemCurr:GetItemQuality()
		end
		self:SetItemData(eQuality, itemCurr:GetIcon())
	end
end

function ItemWindowSubclass:SetItemData(eQuality, strIcon)
	self.eQuality = eQuality
	self.strIcon = strIcon
	self.wnd:SetSprite(self.strIcon)
	if self.tPixieOverlay == nil then
		self.tPixieOverlay = {
			strSprite = "UI_BK3_ItemQualityWhite",
			loc = {fPoints = {0, 0, 1, 1}, nOffsets = {0, 0, 0, 0}},
			cr = ItemWindowSubclassRegistrarInst.arQualityColors[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualityColors))]
		}
		self.tPixieOverlay.id = self.wnd:AddPixie(self.tPixieOverlay)
	else
		self.tPixieOverlay.cr = ItemWindowSubclassRegistrarInst.arQualityColors[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualityColors))]
		self.wnd:UpdatePixie(self.tPixieOverlay.id, self.tPixieOverlay)
	end

end

-----------------------------------------------------------------------------------------------
-- ItemWindowSubclassRegistrar Instance
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-- ItemWindowSubclassRegistrarModule Definition
-----------------------------------------------------------------------------------------------
local ItemWindowSubclassRegistrar = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ItemWindowSubclassRegistrar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.arQualityColors = {
		ApolloColor.new("ItemQuality_Inferior"),
		ApolloColor.new("ItemQuality_Average"),
		ApolloColor.new("ItemQuality_Good"),
		ApolloColor.new("ItemQuality_Excellent"),
		ApolloColor.new("ItemQuality_Superb"),
		ApolloColor.new("ItemQuality_Legendary"),
		ApolloColor.new("ItemQuality_Artifact"),
		ApolloColor.new("00000000")
	}

    return o
end

function ItemWindowSubclassRegistrar:Init()
    Apollo.RegisterAddon(self)
    Apollo.RegisterWindowSubclass("ItemWindowSubclass", self, 
		{
			-- {strEvent="WindowEvent", strFunction="OnWindowEvent"},
		})

end


-----------------------------------------------------------------------------------------------
-- ItemWindowSubclassRegistrar:OnLoad
-----------------------------------------------------------------------------------------------
function ItemWindowSubclassRegistrar:OnLoad()
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
	if Apollo.IsWindowSubclassRegistered("ItemWindowSubclass") then
	end
end

function ItemWindowSubclassRegistrar:SubclassWindow(wndNew, strSubclass, strParam)
	local subclass = ItemWindowSubclass:new({wnd = wndNew})
	wndNew:SetWindowSubclass(subclass, strParam)
end



ItemWindowSubclassRegistrarInst = ItemWindowSubclassRegistrar:new()
ItemWindowSubclassRegistrarInst:Init()
