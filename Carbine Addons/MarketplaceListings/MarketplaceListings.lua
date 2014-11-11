-----------------------------------------------------------------------------------------------
-- Client Lua Script for MarketplaceListings
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Money"
require "MarketplaceLib"
require "CommodityOrder"

local MarketplaceListings = {}

local ktTimeRemaining =
{
	[ItemAuction.CodeEnumAuctionRemaining.Expiring]		= Apollo.GetString("MarketplaceAuction_Expiring"),
	[ItemAuction.CodeEnumAuctionRemaining.LessThanHour]	= Apollo.GetString("MarketplaceAuction_LessThanHour"),
	[ItemAuction.CodeEnumAuctionRemaining.Short]		= Apollo.GetString("MarketplaceAuction_Short"),
	[ItemAuction.CodeEnumAuctionRemaining.Long]			= Apollo.GetString("MarketplaceAuction_Long"),
	[ItemAuction.CodeEnumAuctionRemaining.Very_Long]	= Apollo.GetString("MarketplaceAuction_VeryLong")
}

function MarketplaceListings:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function MarketplaceListings:Init()
    Apollo.RegisterAddon(self)
end

function MarketplaceListings:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MarketplaceListings.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function MarketplaceListings:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleMarketplaceListings", 	"OnToggle", self)
	Apollo.RegisterEventHandler("ToggleAuctionList", 						"OnToggle", self)

	Apollo.RegisterEventHandler("OwnedItemAuctions", 						"OnOwnedItemAuctions", self)
	Apollo.RegisterEventHandler("OwnedCommodityOrders", 					"OnOwnedCommodityOrders", self)
	Apollo.RegisterEventHandler("CREDDExchangeInfoResults", 				"OnCREDDExchangeInfoResults", self)

	Apollo.RegisterEventHandler("CommodityAuctionRemoved", 					"OnCommodityAuctionRemoved", self)
	Apollo.RegisterEventHandler("CommodityAuctionFilledPartial", 			"OnCommodityAuctionUpdated", self)
	Apollo.RegisterEventHandler("PostCommodityOrderResult", 				"OnPostCommodityOrderResult", self)

	Apollo.RegisterEventHandler("ItemAuctionWon", 							"OnItemAuctionRemoved", self)
	Apollo.RegisterEventHandler("ItemAuctionOutbid", 						"OnItemAuctionRemoved", self)
	Apollo.RegisterEventHandler("ItemAuctionExpired", 						"OnItemAuctionRemoved", self)
	Apollo.RegisterEventHandler("ItemCancelResult", 						"OnItemCancelResult", self)
	Apollo.RegisterEventHandler("ItemAuctionBidPosted", 					"OnItemAuctionUpdated", self)
	Apollo.RegisterEventHandler("PostItemAuctionResult", 					"OnItemAuctionResult", self)
	Apollo.RegisterEventHandler("ItemAuctionBidResult", 					"OnItemAuctionResult", self)

	Apollo.CreateTimer("MarketplaceUpdateTimer", 60, true)
	Apollo.StopTimer("MarketplaceUpdateTimer")

	self.tOrders = nil
	self.tAuctions = nil
	self.tCreddList = nil
end

function MarketplaceListings:OnInterfaceMenuListHasLoaded()
	local tData = { "InterfaceMenu_ToggleMarketplaceListings", "", "Icon_Windows32_UI_CRB_InterfaceMenu_MarketplaceListings" }
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_AuctionListings"), tData)
end

function MarketplaceListings:OnToggle()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	else
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "MarketplaceListingsForm", nil, self)
		self.wndMain:SetSizingMinimum(450, 300)
		self.wndMain:SetSizingMaximum(450, 1000)
		self.wndMain:Show(false, true)

		self.wndCreddHeader = Apollo.LoadForm(self.xmlDoc, "HeaderItem", self.wndMain:FindChild("MainScroll"), self)
		self.wndCreddHeader:FindChild("HeaderItemBtn"):SetCheck(true)

		self.wndAuctionBuyHeader = Apollo.LoadForm(self.xmlDoc, "HeaderItem", self.wndMain:FindChild("MainScroll"), self)
		self.wndAuctionBuyHeader:FindChild("HeaderItemBtn"):SetCheck(true)

		self.wndAuctionSellHeader = Apollo.LoadForm(self.xmlDoc, "HeaderItem", self.wndMain:FindChild("MainScroll"), self)
		self.wndAuctionSellHeader:FindChild("HeaderItemBtn"):SetCheck(true)

		self.wndCommodityHeader = Apollo.LoadForm(self.xmlDoc, "HeaderItem", self.wndMain:FindChild("MainScroll"), self)
		self.wndCommodityHeader:FindChild("HeaderItemBtn"):SetCheck(true)

		self:RequestData()

		Apollo.StartTimer("MarketplaceUpdateTimer")
		Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_AuctionListings"), nSaveVersion = 2 })
	end
end

function MarketplaceListings:OnDestroy()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
		Apollo.StopTimer("MarketplaceUpdateTimer")
	end
end

function MarketplaceListings:RequestData()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.wndMain:FindChild("MainScroll"):Show(false)
	self.wndMain:FindChild("WaitScreen"):Show(true)
	for idx, wndCurr in pairs({ self.wndCreddHeader, self.wndAuctionBuyHeader, self.wndAuctionSellHeader, self.wndCommodityHeader }) do
		wndCurr:FindChild("HeaderItemList"):DestroyChildren()
	end

	MarketplaceLib.RequestOwnedCommodityOrders() -- Leads to OwnedCommodityOrders
	MarketplaceLib.RequestOwnedItemAuctions() -- Leads to OwnedItemAuctions
	CREDDExchangeLib.RequestExchangeInfo() -- Leads to OnCREDDExchangeInfoResults
end

function MarketplaceListings:RedrawData()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.wndMain:FindChild("MainScroll"):Show(false)
	self.wndMain:FindChild("WaitScreen"):Show(true)
	for idx, wndCurr in pairs({ self.wndCreddHeader, self.wndAuctionBuyHeader, self.wndAuctionSellHeader, self.wndCommodityHeader }) do
		wndCurr:FindChild("HeaderItemList"):DestroyChildren()
	end

	if self.tOrders ~= nil then
		self:OnOwnedCommodityOrders(self.tOrders)
	end
	if self.tAuctions ~= nil then
		self:OnOwnedItemAuctions(self.tAuctions)
	end
	if self.tCreddList ~= nil then
		self:OnCREDDExchangeInfoResults({}, self.tCreddList)
	end
end

function MarketplaceListings:OnOwnedItemAuctions(tAuctions)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.tAuctions = tAuctions

	for nIdx, aucCurrent in pairs(tAuctions) do
		if aucCurrent and ItemAuction.is(aucCurrent) then
			self:BuildAuctionOrder(nIdx, aucCurrent, aucCurrent:IsOwned() and self.wndAuctionSellHeader:FindChild("HeaderItemList") or self.wndAuctionBuyHeader:FindChild("HeaderItemList"))
		end
	end

	self:SharedDrawMain()
end

function MarketplaceListings:OnOwnedCommodityOrders(tOrders)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.tOrders = tOrders

	for nIdx, tCurrOrder in pairs(tOrders) do
		self:BuildCommodityOrder(nIdx, tCurrOrder, self.wndCommodityHeader:FindChild("HeaderItemList"))
	end

	self:SharedDrawMain()
end

function MarketplaceListings:OnCREDDExchangeInfoResults(arMarketStats, arOrders)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.tCreddList = arOrders

	for nIdx, tCurrOrder in pairs(self.tCreddList) do
		self:BuildCreddOrder(nIdx, tCurrOrder, self.wndCreddHeader:FindChild("HeaderItemList"))
	end

	self:SharedDrawMain()
end

function MarketplaceListings:SharedDrawMain()
	local nNumChildren = #self.wndMain:FindChild("MainScroll"):GetChildren()

	self.wndMain:Show(true)
	self.wndMain:FindChild("MainScroll"):Show(true)
	self.wndMain:FindChild("WaitScreen"):Show(false)

	-- Resizing
	local tHeaders =
	{
		{ strTitle = "Marketplace_CreddLimit",		wnd = self.wndCreddHeader, 			nLimit = 0 }, -- No limit for CREDD
		{ strTitle = "Marketplace_AuctionLimitBuy", wnd = self.wndAuctionBuyHeader, 	nLimit = 0 }, -- No limit for Auction Bids
		{ strTitle = "Marketplace_AuctionLimit", 	wnd = self.wndAuctionSellHeader,	nLimit = MarketplaceLib.kMaxPlayerAuctions },
		{ strTitle = "Marketplace_CommodityLimit", 	wnd = self.wndCommodityHeader, 		nLimit = MarketplaceLib.kMaxPlayerCommodityOrders },
	}
	for idx, tHeaderData in pairs(tHeaders) do
		local wndCurr = tHeaderData.wnd
		local nChildren = #wndCurr:FindChild("HeaderItemList"):GetChildren()
		if nChildren == 0 then
			wndCurr:Show(false)
		else
			local nHeight = wndCurr:FindChild("HeaderItemList"):ArrangeChildrenVert(0)
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + (wndCurr:FindChild("HeaderItemBtn"):IsChecked() and nHeight or 0) + 41)
			wndCurr:Show(true)
		end
		wndCurr:FindChild("HeaderItemBtn"):SetText(String_GetWeaselString(Apollo.GetString(tHeaderData.strTitle), nChildren, tHeaderData.nLimit))
	end

	self.wndMain:FindChild("MainScroll"):SetText(nNumChildren == 0 and Apollo.GetString("MarketplaceListings_NoActiveListings") or "")
	self.wndMain:FindChild("MainScroll"):ArrangeChildrenVert(0)
end

function MarketplaceListings:OnHeaderItemToggle(wndHandler, wndControl)
	self:SharedDrawMain()
end

-----------------------------------------------------------------------------------------------
-- Item Drawing
-----------------------------------------------------------------------------------------------

function MarketplaceListings:BuildAuctionOrder(nIdx, aucCurrent, wndParent)
	local tItem = aucCurrent:GetItem()
	local wndCurr = self:FactoryProduce(wndParent, "AuctionItem", aucCurrent)

	local bIsOwnAuction = aucCurrent:IsOwned()
	local nCount = aucCurrent:GetCount()
	local nBidAmount = aucCurrent:GetCurrentBid():GetAmount()
	local nMinBidAmount = aucCurrent:GetMinBid():GetAmount()
	local nBuyoutAmount = aucCurrent:GetBuyoutPrice():GetAmount()
	local strPrefix = bIsOwnAuction and Apollo.GetString("MarketplaceListings_AuctionPrefix") or Apollo.GetString("MarketplaceListings_BiddingPrefix")
	local eTimeRemaining = MarketplaceLib.kCommodityOrderListTimeDays

	if bIsOwnAuction then
		wndCurr:FindChild("AuctionTimeLeftText"):SetText(self:HelperFormatTimeString(aucCurrent:GetExpirationTime()))
		wndCurr:FindChild("ListExpiresIconRed"):Show(false)
		wndCurr:FindChild("ListExpiresIconGreen"):Show(true)
		wndCurr:FindChild("AuctionTimeLeftText"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
	elseif eTimeRemaining == ItemAuction.CodeEnumAuctionRemaining.Very_Long then
		wndCurr:FindChild("AuctionTimeLeftText"):SetTextRaw(String_GetWeaselString(Apollo.GetString("MarketplaceAuction_VeryLong"), kstrAuctionOrderDuration))
		wndCurr:FindChild("AuctionTimeLeftText"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
		wndCurr:FindChild("ListExpiresIconRed"):Show(false)
		wndCurr:FindChild("ListExpiresIconGreen"):Show(true)
	else
		wndCurr:FindChild("AuctionTimeLeftText"):SetTextRaw(ktTimeRemaining[eTimeRemaining])
		wndCurr:FindChild("AuctionTimeLeftText"):SetTextColor(ApolloColor.new("xkcdReddish"))
		wndCurr:FindChild("ListExpiresIconRed"):Show(true)
		wndCurr:FindChild("ListExpiresIconGreen"):Show(false)
	end

	wndCurr:FindChild("AuctionCancelBtn"):SetData(aucCurrent)
	wndCurr:FindChild("AuctionCancelBtn"):Enable(nBidAmount == 0)
	wndCurr:FindChild("AuctionCancelBtn"):Show(bIsOwnAuction)
	wndCurr:FindChild("AuctionCancelBtnTooltipHack"):Show(bIsOwnAuction and nBidAmount ~= 0)
	wndCurr:FindChild("AuctionPrice"):SetAmount(nBidAmount, true) -- 2nd arg is bInstant
	wndCurr:FindChild("BuyoutPrice"):SetAmount(nBuyoutAmount, true) -- 2nd arg is bInstant
	wndCurr:FindChild("MinimumPrice"):SetAmount(nMinBidAmount, true) -- 2nd arg is bInstant
	wndCurr:FindChild("AuctionBigIcon"):SetSprite(tItem:GetIcon())
	wndCurr:FindChild("AuctionIconAmountText"):SetText(nCount == 1 and "" or nCount)
	wndCurr:FindChild("AuctionItemName"):SetText(String_GetWeaselString(strPrefix, tItem:GetName()))
	Tooltip.GetItemTooltipForm(self, wndCurr:FindChild("AuctionBigIcon"), tItem, {bPrimary = true, bSelling = false, itemCompare = tItem:GetEquippedItemForItemType()})

	wndCurr:FindChild("AuctionItemName"):SetHeightToContentHeight()
	local AuctionItemNameHeight = wndCurr:FindChild("AuctionItemName"):GetHeight()
	local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
	wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + AuctionItemNameHeight + 80) -- 80 is bottom content
end

function MarketplaceListings:BuildCommodityOrder(nIdx, aucCurrent, wndParent)
	local tItem = aucCurrent:GetItem()
	local wndCurr = self:FactoryProduce(wndParent, "CommodityItem", aucCurrent)

	-- Tint a different color if Buy
	local nCount = aucCurrent:GetCount()
	local strPrefix = aucCurrent:IsBuy() and Apollo.GetString("CRB_Buy") or Apollo.GetString("CRB_Sell")
	wndCurr:FindChild("CommodityCancelBtn"):SetData(aucCurrent)
	wndCurr:FindChild("CommodityBuyBG"):Show(aucCurrent:IsBuy())
	wndCurr:FindChild("CommoditySellBG"):Show(not aucCurrent:IsBuy())
	wndCurr:FindChild("CommodityBigIcon"):SetSprite(tItem:GetIcon())
	wndCurr:FindChild("CommodityIconAmountText"):SetText(nCount == 1 and "" or nCount)
	wndCurr:FindChild("CommodityItemName"):SetText(String_GetWeaselString(Apollo.GetString("MarketplaceListings_AuctionLabel"), strPrefix, tItem:GetName()))
	wndCurr:FindChild("CommodityPrice"):SetAmount(aucCurrent:GetPricePerUnit():GetAmount(), true) -- 2nd arg is bInstant
	wndCurr:FindChild("CommodityTimeLeftText"):SetText(self:HelperFormatTimeString(aucCurrent:GetExpirationTime()))
	Tooltip.GetItemTooltipForm(self, wndCurr:FindChild("CommodityBigIcon"), tItem, {bPrimary = true, bSelling = false, itemCompare = tItem:GetEquippedItemForItemType()})

	wndCurr:FindChild("CommodityItemName"):SetHeightToContentHeight()
	local CommodityItemNameHeight = wndCurr:FindChild("CommodityItemName"):GetHeight()
	local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
	if wndCurr:FindChild("CommodityItemName"):GetHeight() > 25 then
		wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + CommodityItemNameHeight + 50) -- 50 is bottom content
	end

end

function MarketplaceListings:BuildCreddOrder(nIdx, aucCurrent, wndParent)
	local wndCurr = self:FactoryProduce(wndParent, "CreddItem", aucCurrent)
	wndCurr:FindChild("CreddCancelBtn"):SetData(aucCurrent)
	wndCurr:FindChild("CreddLabel"):SetText(aucCurrent:IsBuy() and Apollo.GetString("MarketplaceCredd_BuyLabel") or Apollo.GetString("MarketplaceCredd_SellLabel"))
	wndCurr:FindChild("CreddPrice"):SetAmount(aucCurrent:GetPrice(), true) -- 2nd arg is bInstant
	wndCurr:FindChild("CreddTimeLeftText"):SetText(self:HelperFormatTimeString(aucCurrent:GetExpirationTime()))
end

-----------------------------------------------------------------------------------------------
-- UI Interaction (mostly to cancel order)
-----------------------------------------------------------------------------------------------

function MarketplaceListings:OnCancelBtn(wndHandler, wndControl)
	local aucCurrent = wndHandler:GetData()
	if self.wndConfirmDelete == nil or not self.wndConfirmDelete:IsValid() then
		self.wndConfirmDelete = Apollo.LoadForm(self.xmlDoc, "ConfirmDelete", self.wndMain:FindChild("ConfirmBlocker"), self)
	end
	self.wndMain:FindChild("ConfirmBlocker"):Show(true)
	self.wndConfirmDelete:Invoke()

	self.wndConfirmDelete:FindChild("CancelCommodityConfirmBtn"):Show(wndHandler:GetName() == "CommodityCancelBtn")
	self.wndConfirmDelete:FindChild("CancelAuctionConfirmBtn"):Show(wndHandler:GetName() == "AuctionCancelBtn")
	self.wndConfirmDelete:FindChild("CancelCREDDListingBtn"):Show(wndHandler:GetName() == "CreddCancelBtn")

	if wndHandler:GetName() == "CommodityCancelBtn" then
		self.wndConfirmDelete:FindChild("CancelCommodityConfirmBtn"):SetData(aucCurrent)
		self.wndConfirmDelete:FindChild("Title"):SetText(Apollo.GetString("MarketplaceListings_CancelCommodityConfirm"))

	elseif wndHandler:GetName() == "AuctionCancelBtn" then
		self.wndConfirmDelete:FindChild("CancelAuctionConfirmBtn"):SetData(aucCurrent)
		self.wndConfirmDelete:FindChild("Title"):SetText(Apollo.GetString("MarketplaceListings_CancelAuctionConfirm"))

	else
		self.wndConfirmDelete:FindChild("CancelCREDDListingBtn"):SetData(aucCurrent)
		self.wndConfirmDelete:FindChild("Title"):SetText(Apollo.GetString("MarketplaceListings_CancelCREDDConfirm"))
	end
end

function MarketplaceListings:OnAuctionCancelConfirmBtn(wndHandler, wndControl)
	local aucCurrent = wndHandler:GetData()
	if not aucCurrent then
		return
	end
	aucCurrent:Cancel()
	self.wndMain:FindChild("MainScroll"):Show(false)
	self.wndConfirmDelete:Destroy()
	self.wndMain:FindChild("RefreshBlocker"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthLargeTemp")
	self.wndMain:FindChild("ConfirmBlocker"):Show(false)
end

function MarketplaceListings:OnCommodityCancelConfirmBtn(wndHandler, wndControl)
	local aucCurrent = wndHandler:GetData()
	if not aucCurrent or not aucCurrent:IsPosted() then
		return
	end
	aucCurrent:Cancel()
	self.wndMain:FindChild("MainScroll"):Show(false)
	self.wndConfirmDelete:Destroy()
	self.wndMain:FindChild("RefreshBlocker"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthLargeTemp")
	self.wndMain:FindChild("ConfirmBlocker"):Show(false)
end

function MarketplaceListings:OnCreddCancelConfirmBtn(wndHandler, wndControl)
	local aucCurrent = wndHandler:GetData()
	if not aucCurrent or not aucCurrent:IsPosted() then
		return
	end
	CREDDExchangeLib.CancelOrder(aucCurrent)
	self:RequestData()
	self.wndConfirmDelete:Destroy()
	self.wndMain:FindChild("RefreshBlocker"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthLargeTemp")
	self.wndMain:FindChild("ConfirmBlocker"):Show(false)
end

function MarketplaceListings:OnCommodityItemSmallMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:FindChild("CommodityCancelBtn") then
		wndHandler:FindChild("CommodityCancelBtn"):Show(true)
	end
end

function MarketplaceListings:OnCommodityItemSmallMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:FindChild("CommodityCancelBtn") then
		wndHandler:FindChild("CommodityCancelBtn"):Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Auction/Commodity update events
-----------------------------------------------------------------------------------------------

function MarketplaceListings:OnCommodityAuctionRemoved(eAuctionEventType, oRemoved)
	-- TODO
	--if eAuctionEventType == MarketplaceLib.AuctionEventType.Fill then
	--elseif eAuctionEventType == MarketplaceLib.AuctionEventType.Expire then
	--elseif eAuctionEventType == MarketplaceLib.AuctionEventType.Cancel then
	--end

	if self.tOrders ~= nil then
		for nIdx, tCurrOrder in ipairs(self.tOrders) do
			if tCurrOrder == oRemoved then
				table.remove(self.tOrders, nIdx)
				break
			end
		end
		self:RedrawData()
	else
		self:RequestData()
	end
end

function MarketplaceListings:OnCommodityAuctionUpdated(oUpdated)
	if self.tOrders ~= nil then
		local bFound = false
		for nIdx, tCurrOrder in ipairs(self.tOrders) do
			if tCurrOrder == oUpdated then
				self.tOrders[nIdx] = oUpdated
				bFound = true
			end
		end
		if not bFound then
			table.insert(self.tOrders, oUpdated)
		end

		self:RedrawData()
	else
		self:RequestData()
	end
end

function MarketplaceListings:OnPostCommodityOrderResult(eAuctionResult, oAdded)
	if eAuctionResult ~= MarketplaceLib.AuctionPostResult.Ok or not oAdded:IsPosted() then
		return
	end

	if self.tOrders == nil then
		self.tOrders = {}
	end

	self:OnCommodityAuctionUpdated(oAdded)
end

function MarketplaceListings:OnItemAuctionRemoved(aucRemoved)
	if self.tAuctions ~= nil then
		for nIdx, aucCurrent in ipairs(self.tAuctions) do
			if aucCurrent == aucRemoved then
				table.remove(self.tAuctions, nIdx)
				break
			end
		end
		self:RedrawData()
	else
		self:RequestData()
	end
end

function MarketplaceListings:OnItemCancelResult(eAuctionResult, aucRemoved)
	if eAuctionResult == MarketplaceLib.AuctionPostResult.AlreadyHasBid then
		Event_FireGenericEvent("GenericEvent_LootChannelMessage", Apollo.GetString("MarketplaceListings_CantCancelHasBid"))
	end

	if eAuctionResult ~= MarketplaceLib.AuctionPostResult.Ok then
		return
	end

	self:OnItemAuctionRemoved(aucRemoved)
end

function MarketplaceListings:OnItemAuctionUpdated(aucUpdated)
	if self.tAuctions ~= nil then
		local bFound = false
		for nIdx, aucCurrent in ipairs(self.tAuctions) do
			if aucCurrent == aucUpdated then
				self.tAuctions[nIdx] = aucUpdated
				bFound = true
			end
		end
		if not bFound then
			table.insert(self.tAuctions, aucUpdated)
		end

		self:RedrawData()
	else
		self:RequestData()
	end
end

function MarketplaceListings:OnItemAuctionResult(eAuctionResult, aucAdded)
	if eAuctionResult ~= MarketplaceLib.AuctionPostResult.Ok then
		return
	end

	if self.tAuctions == nil then
		self.tAuctions = {}
	end

	self:OnItemAuctionUpdated(aucAdded)
end

function MarketplaceListings:OnItemListingClose(wndHandler, wndControl)
	if self.wndConfirmDelete and self.wndConfirmDelete:IsValid() then
		self.wndConfirmDelete:Destroy()
	end

	self.wndMain:FindChild("ConfirmBlocker"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function MarketplaceListings:HelperFormatTimeString(oExpirationTime)
	local strResult = ""
	local nInSeconds = math.floor(math.abs(Time.SecondsElapsed(oExpirationTime))) -- CLuaTime object
	local nHours = math.floor(nInSeconds / 3600)
	local nMins = math.floor(nInSeconds / 60 - (nHours * 60))

	if nHours > 0 then
		strResult = String_GetWeaselString(Apollo.GetString("MarketplaceListings_Hours"), nHours)
	elseif nMins > 0 then
		strResult = String_GetWeaselString(Apollo.GetString("MarketplaceListings_Minutes"), nMins)
	else
		strResult = Apollo.GetString("MarketplaceListings_LessThan1m")
	end
	return strResult
end

function MarketplaceListings:FactoryProduce(wndParent, strFormName, tObject) -- Using AuctionObjects
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

local MarketplaceListingsInst = MarketplaceListings:new()
MarketplaceListingsInst:Init()
