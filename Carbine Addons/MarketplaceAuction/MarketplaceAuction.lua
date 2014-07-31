-----------------------------------------------------------------------------------------------
-- Client Lua Script for MarketplaceAuction
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Money"
require "Item"
require "Unit"
require "MarketplaceLib"
require "ItemAuction"

local MarketplaceAuction = {}

-- Note: These are item levels, not player levels
local knMinLevel = 1
local knMaxLevel = 60 -- TODO: Replace with a variable from code

local knMaxPlat = 9999999999 -- 9999 plat
local knMinRarity = Item.CodeEnumItemQuality.Inferior
local knMaxRarity = Item.CodeEnumItemQuality.Artifact
local kstrAuctionOrderDuration = MarketplaceLib.kItemAuctionListTimeDays

--[[ For Reference, Filters
	MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterPropertyMin },
	MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterPropertyMax },	-- Unused
	MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterLevel },
	MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterQuality },
	MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterGlyphSlot },
	MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterBuyoutMax },
]]--

local ktSortOptionsNameToEnum =
{
	["SortFlyoutStat"] 		= MarketplaceLib.AuctionSort.Property,
	["SortOptionsTimeLH"] 	= MarketplaceLib.AuctionSort.TimeLeft,
	["SortOptionsTimeHL"] 	= MarketplaceLib.AuctionSort.TimeLeft,
	["SortOptionsBidLH"] 	= MarketplaceLib.AuctionSort.MinBid,
	["SortOptionsBidHL"] 	= MarketplaceLib.AuctionSort.MinBid,
	["SortOptionsBuyoutLH"] = MarketplaceLib.AuctionSort.Buyout,
	["SortOptionsBuyoutHL"] = MarketplaceLib.AuctionSort.Buyout,
}

local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "ItemQuality_Inferior",
	[Item.CodeEnumItemQuality.Average] 			= "ItemQuality_Average",
	[Item.CodeEnumItemQuality.Good] 			= "ItemQuality_Good",
	[Item.CodeEnumItemQuality.Excellent] 		= "ItemQuality_Excellent",
	[Item.CodeEnumItemQuality.Superb] 			= "ItemQuality_Superb",
	[Item.CodeEnumItemQuality.Legendary] 		= "ItemQuality_Legendary",
	[Item.CodeEnumItemQuality.Artifact]		 	= "ItemQuality_Artifact",
}

local karEvalString =
{
	[Item.CodeEnumItemQuality.Inferior] 		= Apollo.GetString("CRB_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= Apollo.GetString("CRB_Average"),
	[Item.CodeEnumItemQuality.Good] 			= Apollo.GetString("CRB_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= Apollo.GetString("CRB_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= Apollo.GetString("CRB_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= Apollo.GetString("CRB_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= Apollo.GetString("CRB_Artifact"),
}

local ktTimeRemaining =
{
	[ItemAuction.CodeEnumAuctionRemaining.Expiring]		= Apollo.GetString("MarketplaceAuction_Expiring"),
	[ItemAuction.CodeEnumAuctionRemaining.LessThanHour]	= Apollo.GetString("MarketplaceAuction_LessThanHour"),
	[ItemAuction.CodeEnumAuctionRemaining.Short]		= Apollo.GetString("MarketplaceAuction_Short"),
	[ItemAuction.CodeEnumAuctionRemaining.Long]			= Apollo.GetString("MarketplaceAuction_Long"),
	--[ItemAuction.CodeEnumAuctionRemaining.Very_Long]	= Apollo.GetString("MarketplaceAuction_VeryLong") -- Uses string weasel to stick a number in
}

local kAuctionPostResultToString =
{
	-- [MarketplaceLib.AuctionPostResult.Ok] 					= "", -- String Weasel with MarketplaceAuction_PostAccepted and the item name
	[MarketplaceLib.AuctionPostResult.Item_BadId] 				= Apollo.GetString("MarketplaceAuction_CantPostInvalidItem"),
	[MarketplaceLib.AuctionPostResult.NotEnoughToFillQuantity] 	= Apollo.GetString("GenericError_Vendor_NotEnoughToFillQuantity"),
	[MarketplaceLib.AuctionPostResult.NotEnoughCash] 			= Apollo.GetString("GenericError_Vendor_NotEnoughCash"),
	[MarketplaceLib.AuctionPostResult.NotReady] 				= Apollo.GetString("MarketplaceAuction_TechnicalDifficulties"), -- Correct error?
	[MarketplaceLib.AuctionPostResult.CannotFillOrder] 			= Apollo.GetString("MarketplaceAuction_TechnicalDifficulties"),
	[MarketplaceLib.AuctionPostResult.TooManyOrders] 			= Apollo.GetString("MarketplaceAuction_MaxOrders"),
	[MarketplaceLib.AuctionPostResult.OrderTooBig] 				= Apollo.GetString("MarketplaceAuction_OrderTooBig"),
	[MarketplaceLib.AuctionPostResult.NotFound] 				= Apollo.GetString("MarketplaceAuction_NotFound"),
	[MarketplaceLib.AuctionPostResult.BidTooLow] 				= Apollo.GetString("MarketplaceAuction_BidTooLow"),
	[MarketplaceLib.AuctionPostResult.BidTooHigh] 				= Apollo.GetString("MarketplaceAuction_BidTooHigh"),
	[MarketplaceLib.AuctionPostResult.OwnItem] 					= Apollo.GetString("MarketplaceAuction_AlreadyBid"), -- Correct error?
	[MarketplaceLib.AuctionPostResult.AlreadyHasBid] 			= Apollo.GetString("MarketplaceAuction_AlreadyBid"),
	[MarketplaceLib.AuctionPostResult.ItemAuctionDisabled] 		= Apollo.GetString("MarketplaceAuction_AuctionDisabled"),
	[MarketplaceLib.AuctionPostResult.CommodityDisabled] 		= Apollo.GetString("MarketplaceAuction_CommodityDisabled"),
	[MarketplaceLib.AuctionPostResult.DbFailure] 				= Apollo.GetString("MarketplaceAuction_TechnicalDifficulties"),
	[MarketplaceLib.AuctionPostResult.NotFound] 				= Apollo.GetString("MarketplaceAuction_ItemNotFoundBoughtByAnother"),
}

function MarketplaceAuction:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function MarketplaceAuction:Init()
    Apollo.RegisterAddon(self)
end

function MarketplaceAuction:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MarketplaceAuction.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("OwnedItemAuctions", 			"OnOwnedItemAuctions", self)
	self.nOwnedAuctionCount = 0
end

function MarketplaceAuction:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	-- Window events
	Apollo.RegisterEventHandler("ToggleAuctionWindow", 			"OnToggleAuctionWindow", self)
	Apollo.RegisterEventHandler("AuctionWindowClose", 			"OnDestroy", self)

	-- Chat Log Events
	Apollo.RegisterEventHandler("ItemAuctionWon", 				"OnItemAuctionWon", self)
	Apollo.RegisterEventHandler("ItemAuctionOutbid", 			"OnItemAuctionOutbid", self)
	Apollo.RegisterEventHandler("ItemAuctionExpired", 			"OnItemAuctionExpired", self)

	-- Result Events
	Apollo.RegisterEventHandler("ItemAuctionSearchResults", 	"OnItemAuctionSearchResults", self)
	Apollo.RegisterEventHandler("PostItemAuctionResult", 		"OnPostItemAuctionResult", self)
	Apollo.RegisterEventHandler("ItemAuctionBidResult", 		"OnItemAuctionBidResult", self)
	Apollo.RegisterEventHandler("ItemCancelResult", 			"OnItemCancelResult", self)

	-- Other events
	Apollo.RegisterEventHandler("UpdateInventory", 				"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged",		"OnPlayerCurrencyChanged", self)

	-- Timers
	Apollo.RegisterTimerHandler("PostResultTimer", 				"OnPostResultTimer", self)
end

function MarketplaceAuction:OnWindowClosed(wndHandler, wndControl)
	if wndHandler == wndControl then
		self:OnDestroy()
	end
end

function MarketplaceAuction:OnDestroy()
	if self.wndMain and self.wndMain:IsValid() then
		self:OnSearchClearBtn()
		self.wndMain:Destroy()
		self.wndMain = nil
	end

	Event_CancelAuctionhouse()
end

function MarketplaceAuction:OnToggleAuctionWindow()
	if AccountItemLib.CodeEnumEntitlement.EconomyParticipation and AccountItemLib.GetEntitlementCount(AccountItemLib.CodeEnumEntitlement.EconomyParticipation) == 0 then
		Event_FireGenericEvent("GenericEvent_SystemChannelMessage", Apollo.GetString("CRB_FeatureDisabledForGuests"))
		return
	end

	if self.wndMain and self.wndMain:IsValid() then
		self:OnDestroy()
	else
		self:Initialize()
	end
end

function MarketplaceAuction:OnPlayerCurrencyChanged()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndPlayerCashWindow:SetAmount(GameLib.GetPlayerCurrency())
		self:ToggleAndInitializeBuyOrSell() -- TODO: Gate if this spams
	end
end

function MarketplaceAuction:Initialize()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "MarketplaceAuctionForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("MarketplaceAuction_AuctionHouse")})

	self.wndOrderLimitText = self.wndMain:FindChild("OpenMarketListingsTitle")
	self.wndPlayerCashWindow = self.wndMain:FindChild("PlayerCashWindow")

	self.wndMain:SetSizingMinimum(self.wndMain:GetWidth(), 600)
	self.wndMain:SetSizingMaximum(1600, 1600)

	local wndSort = self.wndMain:FindChild("SortContainer")
	wndSort:FindChild("SortOptionsStatOpener"):AttachWindow(wndSort:FindChild("SortFlyoutStatContainer"))
	wndSort:FindChild("SortOptionsBtn"):AttachWindow(self.wndMain:FindChild("SortOptionsContainer"))
	wndSort:FindChild("SortOptionsTimeLH"):SetCheck(true)

	self.wndMain:FindChild("HeaderBuyBtn"):AttachWindow(self.wndMain:FindChild("BuyContainer"))
	self.wndMain:FindChild("HeaderSellBtn"):AttachWindow(self.wndMain:FindChild("SellContainer"))
	self.wndMain:FindChild("FilterOptionsBtn"):AttachWindow(self.wndMain:FindChild("FilterOptionsContainer"))

	self.wndMain:FindChild("HeaderBuyBtn"):SetCheck(true)
	self.wndMain:FindChild("BottomBidBtn"):Enable(false)
	self.wndMain:FindChild("BottomBuyoutBtn"):Enable(false)
	self.wndMain:FindChild("BottomBidPriceUpBtn"):Enable(false)
	self.wndMain:FindChild("BottomBidPriceDownBtn"):Enable(false)
	self.wndMain:FindChild("BuySearchFirstBtn"):Enable(false)
	self.wndMain:FindChild("BuySearchPrevBtn"):Enable(false)
	self.wndMain:FindChild("BuySearchNextBtn"):Enable(false)
	self.wndMain:FindChild("BuySearchLastBtn"):Enable(false)
	self.wndMain:FindChild("PostResultNotification"):Show(false, true)
	self.wndMain:FindChild("SellContainer"):FindChild("CreateBidInputBox"):SetAmountLimit(knMaxPlat)
	self.wndMain:FindChild("SellContainer"):FindChild("CreateBuyoutInputBox"):SetAmountLimit(knMaxPlat) -- 9999 plat

	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "CategoryTopItem", nil, self)
	self.nDefaultWndTopHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	self.nCurPage = nil
	self.nTotalResults = nil
	self.nSearchId = nil -- TODO REFACTOR: Can delete
	self.strSearchEnum = nil -- TODO REFACTOR: Can delete

	self:InitializeCategories()
	self:OnResizeCategories()
	self:InitializeBuyFilters()
	self:OnPlayerCurrencyChanged() -- Will call main update method
	MarketplaceLib.RequestOwnedItemAuctions()

	Sound.Play(Sound.PlayUIWindowAuctionHouseOpen)
end

function MarketplaceAuction:InitializeCategories()
	-- Armor Hack (nId == 1)
	local wndParent = self.wndMain:FindChild("MainCategoryContainer")
	for idx1, tMidData in ipairs(MarketplaceLib.GetAuctionableCategories(1)) do
		local wndTop = Apollo.LoadForm(self.xmlDoc, "CategoryTopItem", wndParent, self)
		wndTop:FindChild("CategoryTopBtn"):SetData(wndTop)
		wndTop:FindChild("CategoryTopBtn"):SetCheck(idx1 == 1) -- Check the first item found
		wndTop:FindChild("CategoryTopText"):SetText(tMidData.strName)

		-- Add an "All" button
		local wndAllBtn = Apollo.LoadForm(self.xmlDoc, "CategoryMidItem", wndTop:FindChild("CategoryTopList"), self)
		wndAllBtn:FindChild("CategoryMidBtnText"):SetText(Apollo.GetString("CRB_All"))
		wndAllBtn:FindChild("CategoryMidBtn"):SetData({ tMidData.nId, "Mid" })
		wndAllBtn:SetName("CategoryMidItem_All")

		-- Check the first "All" button found
		if idx1 == 1 then
			self.nSearchId = tMidData.nId
			self.strSearchEnum = "Mid"
			wndAllBtn:FindChild("CategoryMidBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))
			wndAllBtn:FindChild("CategoryMidBtn"):SetCheck(true)
		end

		for idx2, tBotData in pairs(MarketplaceLib.GetAuctionableTypes(tMidData.nId) or {}) do
			if string.len(tBotData.strName) > 0 then
				local wndCurr = Apollo.LoadForm(self.xmlDoc, "CategoryMidItem", wndTop:FindChild("CategoryTopList"), self)
				wndCurr:FindChild("CategoryMidBtnText"):SetText(tBotData.strName)
				wndCurr:FindChild("CategoryMidBtn"):SetData({ tBotData.nId, "Bot" })
			end
		end
	end

	-- Draw Families then Merge Categories/Types
	for idx1, tTopData in ipairs(MarketplaceLib.GetAuctionableFamilies()) do
		if tTopData.nId > 1 then
			local wndTop = Apollo.LoadForm(self.xmlDoc, "CategoryTopItem", wndParent, self)
			wndTop:FindChild("CategoryTopBtn"):SetData(wndTop)
			wndTop:FindChild("CategoryTopText"):SetText(tTopData.strName)

			-- Add an "All" button
			local wndAllBtn = Apollo.LoadForm(self.xmlDoc, "CategoryMidItem", wndTop:FindChild("CategoryTopList"), self)
			wndAllBtn:FindChild("CategoryMidBtnText"):SetText(Apollo.GetString("CRB_All"))
			wndAllBtn:FindChild("CategoryMidBtn"):SetData({ tTopData.nId, "Top" })
			wndAllBtn:SetName("CategoryMidItem_All")

			-- Build a list of children
			local tFullMidList = {}
			for idx2, tMidData in pairs(MarketplaceLib.GetAuctionableCategories(tTopData.nId) or {}) do
				local tBottomList = MarketplaceLib.GetAuctionableTypes(tMidData.nId) or {}
				if #tBottomList == 0 then
					-- TODO: This should actually never happen. Once data is fixed, consider removing this code.
					table.insert(tFullMidList, { tMidData.nId, tMidData.strName, "Mid" })
				else
					-- If the bottom is empty, use the middle. Else, use the bottom and ignore the middle.
					for idx3, tBotData in pairs(tBottomList) do
						table.insert(tFullMidList, { tBotData.nId, tBotData.strName, "Bot" })
					end
				end
			end

			-- Use the list of children to draw button
			for idx, tData in pairs(tFullMidList) do
				if string.len(tData[2]) > 0 then
					local wndCurr = Apollo.LoadForm(self.xmlDoc, "CategoryMidItem", wndTop:FindChild("CategoryTopList"), self)
					wndCurr:FindChild("CategoryMidBtnText"):SetText(tData[2])
					wndCurr:FindChild("CategoryMidBtn"):SetData({ tData[1], tData[3] })
				end
			end
		end
	end
end

function MarketplaceAuction:InitializeBuyFilters()
	local wndFilter = self.wndMain:FindChild("FilterContainer")
	wndFilter:FindChild("FilterOptionsStatBtn1"):AttachWindow(wndFilter:FindChild("FilterFlyoutStatContainer1"))
	wndFilter:FindChild("FilterOptionsStatBtn2"):AttachWindow(wndFilter:FindChild("FilterFlyoutStatContainer2"))
	wndFilter:FindChild("FilterOptionsStatBtn3"):AttachWindow(wndFilter:FindChild("FilterFlyoutStatContainer3"))

	wndFilter:FindChild("FilterOptionsRarityMaxContainer"):FindChild("FilterOptionsRarityUpBtn"):SetData(self.wndMain:FindChild("FilterOptionsRarityMaxContainer"))
	wndFilter:FindChild("FilterOptionsRarityMaxContainer"):FindChild("FilterOptionsRarityDownBtn"):SetData(self.wndMain:FindChild("FilterOptionsRarityMaxContainer"))
	wndFilter:FindChild("FilterOptionsRarityMaxContainer"):FindChild("FilterOptionsRarityUpBtn"):Enable(false)

	wndFilter:FindChild("FilterOptionsRarityMinContainer"):FindChild("FilterOptionsRarityUpBtn"):SetData(self.wndMain:FindChild("FilterOptionsRarityMinContainer"))
	wndFilter:FindChild("FilterOptionsRarityMinContainer"):FindChild("FilterOptionsRarityDownBtn"):SetData(self.wndMain:FindChild("FilterOptionsRarityMinContainer"))
	wndFilter:FindChild("FilterOptionsRarityMinContainer"):FindChild("FilterOptionsRarityDownBtn"):Enable(false)

	wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelUpBtn"):SetData(self.wndMain:FindChild("FilterOptionsLevelMaxContainer"))
	wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelDownBtn"):SetData(self.wndMain:FindChild("FilterOptionsLevelMaxContainer"))
	wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelUpBtn"):Enable(false)

	wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelUpBtn"):SetData(self.wndMain:FindChild("FilterOptionsLevelMinContainer"))
	wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelDownBtn"):SetData(self.wndMain:FindChild("FilterOptionsLevelMinContainer"))
	wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelDownBtn"):Enable(false)

	wndFilter:FindChild("FilterOptionsRarityMaxContainer"):SetData(Item.CodeEnumItemQuality.Artifact) -- Most of Rarity Square is set up in XML
	wndFilter:FindChild("FilterOptionsRarityMinContainer"):SetData(Item.CodeEnumItemQuality.Inferior)
	wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelEditBox"):SetText(knMaxLevel)
	wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelEditBox"):SetText(knMinLevel)

	local tItemProperties = MarketplaceLib.GetItemProperties()
	table.sort(tItemProperties, function (a, b) return a.nSortOrder < b.nSortOrder end)

	-- Any Stat
	for idx = 1, 3 do
		local wndFilterList = wndFilter:FindChild("FilterFlyoutStatList"..idx)

		local wndAllStat = Apollo.LoadForm(self.xmlDoc, "FilterFlyoutStat", wndFilterList, self)
		wndAllStat:SetText(Apollo.GetString("MarketplaceAuction_AnyStat"))
		wndAllStat:SetData({ idx, false, false })

		-- Stats
		for idx2, tProperty in ipairs(tItemProperties) do
			local wndCurrStat = Apollo.LoadForm(self.xmlDoc, "FilterFlyoutStat", wndFilterList, self)
			wndCurrStat:SetData({ idx, MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterPropertyMin, tProperty.nId })
			wndCurrStat:SetText(tProperty.strDisplayName)
		end

		-- Runes
		for strKey, nGlyph in pairs(Item.CodeEnumSigilType) do
			local wndCurrStat = Apollo.LoadForm(self.xmlDoc, "FilterFlyoutStat", wndFilterList, self)
			wndCurrStat:SetData({ idx, MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterGlyphSlot, nGlyph })
			wndCurrStat:SetText(String_GetWeaselString(Apollo.GetString("Tooltips_RuneSlot"), strKey))
		end

		wndFilterList:ArrangeChildrenVert(0)
		local nLeft, nTop, nRight, nBottom = wndFilter:FindChild("FilterFlyoutStatContainer"..idx):GetAnchorOffsets()
		wndFilter:FindChild("FilterFlyoutStatContainer"..idx):SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
	end

	-- Sorting (GOTCHA: FilterContainer is anchored to the bottom for more than enough room, SortContainer will be resized to the list though)
	local wndSort = self.wndMain:FindChild("SortContainer")
	local wndStatList = wndSort:FindChild("SortFlyoutList")
	for idx, tProperty in ipairs(tItemProperties) do
		local wndCurrStat = Apollo.LoadForm(self.xmlDoc, "SortFlyoutStat", wndStatList, self)
		wndCurrStat:SetText(tProperty.strDisplayName)
		wndCurrStat:SetData(tProperty.nId)
	end

	wndStatList:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndSort:GetAnchorOffsets()
	wndSort:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
end

function MarketplaceAuction:OnResizeCategories()
	for idx, wndTop in pairs(self.wndMain:FindChild("MainCategoryContainer"):GetChildren()) do
		local nListHeight = wndTop:FindChild("CategoryTopBtn"):IsChecked() and (wndTop:FindChild("CategoryTopList"):ArrangeChildrenVert(0) + 15) or 0
		local nLeft, nTop, nRight, nBottom = wndTop:GetAnchorOffsets()
		wndTop:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nListHeight + self.nDefaultWndTopHeight)
	end

	self.wndMain:FindChild("MainCategoryContainer"):ArrangeChildrenVert(0)
end

function MarketplaceAuction:OnRefreshBtn(wndHandler, wndControl) -- Also from lua and multiple XML buttons
	self.wndMain:FindChild("RefreshAnimation"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self:ToggleAndInitializeBuyOrSell()
end

function MarketplaceAuction:OnHeaderBtnToggle(wndHandler, wndControl)
	self:ToggleAndInitializeBuyOrSell()
end

function MarketplaceAuction:ToggleAndInitializeBuyOrSell()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local bIsBuyChecked = self.wndMain:FindChild("HeaderBuyBtn"):IsChecked()
	local bIsSellChecked = self.wndMain:FindChild("HeaderSellBtn"):IsChecked()
	self.wndMain:FindChild("BuyContainer"):Show(bIsBuyChecked)
	self.wndMain:FindChild("SellContainer"):Show(bIsSellChecked)

	self.wndMain:FindChild("BuyContainer"):FindChild("SearchResultList"):DestroyChildren()
	self.wndMain:FindChild("SellContainer"):FindChild("SellSimilarItemsList"):DestroyChildren()

	local wndFilter = self.wndMain:FindChild("FilterContainer")
	self.wndMain:FindChild("SortFlyoutStatContainer"):Show(false) -- Needs to be closed even when SortOptionsContainer is opened
	self.wndMain:FindChild("SortOptionsContainer"):Show(false)
	wndFilter:FindChild("FilterOptionsContainer"):Show(false)
	wndFilter:FindChild("FilterClearBtn"):Show(wndFilter:FindChild("FilterClearBtn"):GetData() or false) -- GOTCHA: Visibility update is delayed until a manual reset

	self.wndMain:FindChild("SearchResultList"):SetText("")

	if bIsBuyChecked then
		self:InitializeBuy()
	elseif bIsSellChecked then
		self:InitializeSell()
	end

	self:OnRowSelectBtnUncheck()
end

-----------------------------------------------------------------------------------------------
-- Search
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnSearchEditBoxChanged(wndHandler, wndControl) -- SearchEditBox
	self.wndMain:FindChild("SearchClearBtn"):Show(string.len(wndHandler:GetText() or "") > 0)
end

function MarketplaceAuction:OnSearchClearBtn(wndHandler, wndControl)
	self.wndMain:FindChild("SearchEditBox"):SetText("")
	self.wndMain:FindChild("SearchClearBtn"):Show(false)
	self.wndMain:FindChild("SearchClearBtn"):SetFocus()
	self:OnRefreshBtn()
end

function MarketplaceAuction:OnSearchCommitBtn(wndHandler, wndControl) -- Also SearchEditBox's WindowKeyReturn
	self.wndMain:FindChild("SearchClearBtn"):SetFocus()
	self:OnRefreshBtn()
end

-----------------------------------------------------------------------------------------------
-- Sorting
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnSortOptionsUseableToggle(wndHandler, wndControl) -- SortFlyoutStat and SortOptionsTimeLH and etc
	local wndSort = self.wndMain:FindChild("SortContainer")

	-- Sort Data
	local strBtnName = wndHandler:GetName() -- Relies on exact window naming
	local tSortData =
	{
		nPropertySort 	= wndHandler:GetData() or false, -- Only non nil for SortFlyoutStat
		eAuctionSort 	= ktSortOptionsNameToEnum[strBtnName] or MarketplaceLib.AuctionSort.TimeLeft,
		bReverse 		= (strBtnName == "SortFlyoutStat" or strBtnName == "SortOptionsTimeHL" or strBtnName == "SortOptionsBidHL" or strBtnName == "SortOptionsBuyoutHL"),
	}
	wndSort:FindChild("SortOptionsBtn"):SetData(tSortData)

	-- Checkmarks
	for idx, wndCurr in pairs(wndSort:FindChild("SortOptionsContainer"):GetChildren()) do
		if wndCurr:FindChild("SortOptionsCheck") then
			wndCurr:FindChild("SortOptionsCheck"):SetSprite("")
		end
	end
	for idx, wndCurr in pairs(wndSort:FindChild("SortFlyoutList"):GetChildren()) do
		if wndCurr:FindChild("SortOptionsCheck") then
			wndCurr:FindChild("SortOptionsCheck"):SetSprite("")
		end
	end

	-- Valid checkmarks
	if strBtnName == "SortFlyoutStat" then
		wndSort:FindChild("SortOptionsStatOpener"):FindChild("SortOptionsCheck"):SetSprite(wndHandler:IsChecked() and "sprCharC_NameCheckYes" or "")
		wndSort:FindChild("SortOptionsStatOpener"):SetText(wndHandler:IsChecked() and wndHandler:GetText() or Apollo.GetString("EngravingStation_Stat"))
	else
		wndSort:FindChild("SortOptionsStatOpener"):SetText(Apollo.GetString("EngravingStation_Stat"))
	end
	wndHandler:FindChild("SortOptionsCheck"):SetSprite(wndHandler:IsChecked() and "sprCharC_NameCheckYes" or "")

	self:OnRefreshBtn()
end

-----------------------------------------------------------------------------------------------
-- Filtering
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnFilterFlyoutStatBtn(wndHandler, wndControl) -- FilterFlyoutStat, data is { nNameIdx, eType, nValue }
	if wndHandler:GetData() then
		local nButtonNameIdx = wndHandler:GetData()[1]
		local eType = wndHandler:GetData()[2]
		local wndStatBtn = self.wndMain:FindChild("FilterContainer"):FindChild("FilterOptionsStatBtn" .. nButtonNameIdx)
		wndStatBtn:SetText(wndHandler:GetText())

		if eType then
			wndStatBtn:SetData({ wndHandler:GetData()[1], wndHandler:GetData()[2], wndHandler:GetData()[3] })
		else
			wndStatBtn:SetData(false)
		end
	end

	local wndFilter = self.wndMain:FindChild("FilterContainer")
	wndFilter:FindChild("FilterFlyoutStatContainer1"):Show(false)
	wndFilter:FindChild("FilterFlyoutStatContainer2"):Show(false)
	wndFilter:FindChild("FilterFlyoutStatContainer3"):Show(false)
	wndFilter:FindChild("FilterClearBtn"):SetData(true)
end

function MarketplaceAuction:OnFilterEditBoxChanged(wndHandler, wndControl) -- Shared between Rarity and Level Up and Max Buyout CashWindow
	local wndEditBox = wndHandler:GetParent():FindChild("FilterOptionsLevelEditBox")
	self:HelperCheckValidValues(wndEditBox)
	self.wndMain:FindChild("FilterContainer"):FindChild("FilterClearBtn"):SetData(true) -- GOTCHA: It will flag as dirty bit when the Refresh event gets called
end

function MarketplaceAuction:OnFilterOptionsRarityUpBtn(wndHandler, wndControl)
	self:OnHelperFilterRarityEditBox(wndHandler:GetData(), true)
end

function MarketplaceAuction:OnFilterOptionsRarityDownBtn(wndHandler, wndControl)
	self:OnHelperFilterRarityEditBox(wndHandler:GetData(), false)
end

function MarketplaceAuction:OnFilterOptionsLevelUpBtn(wndHandler, wndControl)
	self:OnHelperFilterLevelEditBox(wndHandler:GetData(), true)
end

function MarketplaceAuction:OnFilterOptionsLevelDownBtn(wndHandler, wndControl)
	self:OnHelperFilterLevelEditBox(wndHandler:GetData(), false)
end

function MarketplaceAuction:OnHelperFilterLevelEditBox(wndParent, bAdd)
	local nOldValue = tonumber(wndParent:FindChild("FilterOptionsLevelEditBox"):GetText()) or 1
	local nNewValue = math.min(knMaxLevel, math.max(knMinLevel, bAdd and nOldValue + 1 or nOldValue - 1))

	wndParent:SetFocus()
	wndParent:FindChild("FilterOptionsLevelEditBox"):SetText(nNewValue)

	local wndEditBox = wndParent:FindChild("FilterOptionsLevelEditBox")
	self:HelperCheckValidValues(wndEditBox)

	self.wndMain:FindChild("FilterContainer"):FindChild("FilterClearBtn"):SetData(true) -- GOTCHA: Not wndParent
end

function MarketplaceAuction:OnHelperFilterRarityEditBox(wndParent, bAdd)
	local nOldValue = tonumber(wndParent:GetData()) or 1
	local nNewValue = math.min(knMaxRarity, math.max(knMinRarity, bAdd and nOldValue + 1 or nOldValue - 1))

	wndParent:SetFocus()
	wndParent:SetData(nNewValue)
	wndParent:FindChild("FilterOptionsRaritySquare"):SetTooltip(karEvalString[nNewValue] or "")
	wndParent:FindChild("FilterOptionsRaritySquare"):SetBGColor(karEvalColors[nNewValue] or "")

	self.wndMain:FindChild("FilterContainer"):FindChild("FilterClearBtn"):SetData(true) -- GOTCHA: Not wndParent

	-- Need to update both, as toggling one can disable a button in the other window
	local wndMin = self.wndMain:FindChild("FilterContainer"):FindChild("FilterOptionsRarityMinContainer")
	local wndMax = self.wndMain:FindChild("FilterContainer"):FindChild("FilterOptionsRarityMaxContainer")
	local nLowestShared = math.min(wndMax:GetData(), wndMin:GetData())
	local nHighestShared = math.max(wndMax:GetData(), wndMin:GetData())
	wndMin:FindChild("FilterOptionsRarityUpBtn"):Enable(wndMin:GetData() < knMaxRarity and wndMin:GetData() ~= nHighestShared)
	wndMin:FindChild("FilterOptionsRarityDownBtn"):Enable(wndMin:GetData() > knMinRarity)
	wndMax:FindChild("FilterOptionsRarityUpBtn"):Enable(wndMax:GetData() < knMaxRarity)
	wndMax:FindChild("FilterOptionsRarityDownBtn"):Enable(wndMax:GetData() > knMinRarity and wndMax:GetData() ~= nLowestShared)


	--self:HelperCheckValidValues()
end

function MarketplaceAuction:OnFilterOptionsUseableToggle(wndHandler, wndControl)
	local bIsChecked = wndHandler:IsChecked()
	wndHandler:SetText(bIsChecked and Apollo.GetString("MarketplaceAuction_CanUse") or Apollo.GetString("MarketplaceAuction_AnyItem"))
	self.wndMain:FindChild("FilterClearBtn"):SetData(bIsChecked or self.wndMain:FindChild("FilterClearBtn"):GetData()) -- Uncheck to false only if already also false
	self:OnRefreshBtn()
end

function MarketplaceAuction:OnResetFilterBtn(wndHandler, wndControl)
	local wndFilter = self.wndMain:FindChild("FilterContainer")
	wndFilter:FindChild("FilterOptionsStatBtn1"):SetData(false)
	wndFilter:FindChild("FilterFlyoutStatContainer1"):Show(false)
	wndFilter:FindChild("FilterOptionsStatBtn1"):SetText(Apollo.GetString("MarketplaceAuction_AnyStat"))

	wndFilter:FindChild("FilterOptionsStatBtn2"):SetData(false)
	wndFilter:FindChild("FilterFlyoutStatContainer2"):Show(false)
	wndFilter:FindChild("FilterOptionsStatBtn2"):SetText(Apollo.GetString("MarketplaceAuction_AnyStat"))

	wndFilter:FindChild("FilterOptionsStatBtn3"):SetData(false)
	wndFilter:FindChild("FilterFlyoutStatContainer3"):Show(false)
	wndFilter:FindChild("FilterOptionsStatBtn3"):SetText(Apollo.GetString("MarketplaceAuction_AnyStat"))

	wndFilter:FindChild("FilterOptionsRarityMinContainer"):SetData(Item.CodeEnumItemQuality.Inferior)
	wndFilter:FindChild("FilterOptionsRarityMaxContainer"):SetData(Item.CodeEnumItemQuality.Artifact)
	wndFilter:FindChild("FilterOptionsRarityMinContainer"):FindChild("FilterOptionsRaritySquare"):SetTooltip(karEvalString[Item.CodeEnumItemQuality.Inferior])
	wndFilter:FindChild("FilterOptionsRarityMaxContainer"):FindChild("FilterOptionsRaritySquare"):SetTooltip(karEvalString[Item.CodeEnumItemQuality.Artifact])
	wndFilter:FindChild("FilterOptionsRarityMinContainer"):FindChild("FilterOptionsRaritySquare"):SetBGColor(karEvalColors[Item.CodeEnumItemQuality.Inferior])
	wndFilter:FindChild("FilterOptionsRarityMaxContainer"):FindChild("FilterOptionsRaritySquare"):SetBGColor(karEvalColors[Item.CodeEnumItemQuality.Artifact])

	wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelEditBox"):SetText(knMinLevel)
	wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelEditBox"):SetText(knMaxLevel)
	wndFilter:FindChild("FilterOptionsUseable"):SetText(Apollo.GetString("MarketplaceAuction_AnyItem"))
	wndFilter:FindChild("FilterOptionsUseable"):SetCheck(false)
	wndFilter:FindChild("FilterClearBtn"):SetData(false)

	self:OnRefreshBtn()
end

function MarketplaceAuction:OnFilterOptionsWindowClosed(wndHandler, wndControl)
	if wndHandler == wndControl and self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("FilterClearBtn"):GetData() then
		self:OnRefreshBtn()
	end
end

function MarketplaceAuction:HelperCheckValidValues(wndChanged)
	local wndFilterOptions = self.wndMain:FindChild("BuyContainer:AdvancedOptionsContainer:FilterContainer:FilterOptionsContainer")
	local wndMinLevelFilter = wndFilterOptions:FindChild("FilterOptionsLevelMinContainer:FilterOptionsLevelEditBox")
	local wndMaxLevelFilter = wndFilterOptions:FindChild("FilterOptionsLevelMaxContainer:FilterOptionsLevelEditBox")
	local nMinLevelValue = tonumber(wndMinLevelFilter:GetText()) or knMinLevel
	local nMaxLevelValue = tonumber(wndMaxLevelFilter:GetText()) or knMaxLevel
	local bMinChanged = false
	local bMaxChanged = false

	if wndChanged == wndMinLevelFilter then
		if nMinLevelValue < knMinLevel then
			nMinLevelValue = knMinLevel
			bMinChanged = true
		elseif nMinLevelValue >= knMaxLevel then
			nMinLevelValue = knMaxLevel
			bMinChanged = true
		end
		if nMinLevelValue > nMaxLevelValue then
			nMinLevelValue = nMaxLevelValue
			bMinChanged = true
		end
	end

	if wndChanged == wndMaxLevelFilter then
		if nMaxLevelValue < knMinLevel then
			nMaxLevelValue = knMinLevel
			bMaxChanged = true
		elseif nMaxLevelValue >= knMaxLevel then
			nMaxLevelValue = knMaxLevel
			bMaxChanged = true
		end
		if nMinLevelValue > nMaxLevelValue and ((nMinLevelValue >= 10 and nMaxLevelValue >= 10)) then
			nMaxLevelValue = nMinLevelValue
			bMaxChanged = true
		end
	end

	wndFilterOptions:FindChild("FilterOptionsRefreshBtn"):Enable(nMaxLevelValue >= nMinLevelValue)

	if bMinChanged then
		wndMinLevelFilter:SetText(nMinLevelValue)
	end
	if bMaxChanged then
		wndMaxLevelFilter:SetText(nMaxLevelValue)
	end

	wndFilterOptions:FindChild("FilterOptionsLevelMinContainer:FilterOptionsLevelUpBtn"):Enable(nMinLevelValue < knMaxLevel and nMinLevelValue < nMaxLevelValue)
	wndFilterOptions:FindChild("FilterOptionsLevelMinContainer:FilterOptionsLevelDownBtn"):Enable(nMinLevelValue > knMinLevel)
	wndFilterOptions:FindChild("FilterOptionsLevelMaxContainer:FilterOptionsLevelUpBtn"):Enable(nMaxLevelValue < knMaxLevel)
	wndFilterOptions:FindChild("FilterOptionsLevelMaxContainer:FilterOptionsLevelDownBtn"):Enable(nMaxLevelValue > knMinLevel and nMaxLevelValue > nMinLevelValue)
end

-----------------------------------------------------------------------------------------------
-- Advanced Filtering
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:GetBuyFilterOptions()
	-- NOTE: There is support for MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterPropertyMax, but we currently aren't using it
	local tOptions = {}

	-- Equippable Filtering
	if self.wndMain:FindChild("FilterContainer"):FindChild("FilterOptionsUseable"):IsChecked() then
		table.insert(tOptions, { nType = MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterEquippableBy }) -- This can receive more arguments such as Race or Class
	end

	-- Level Filtering
	local wndFilter = self.wndMain:FindChild("FilterContainer")
	local nLevelMin = tonumber(wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelEditBox"):GetText()) or knMinLevel
	local nLevelMax = tonumber(wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelEditBox"):GetText()) or knMaxLevel
	if nLevelMin == knMinLevel then
		wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelDownBtn"):Enable(false)
		wndFilter:FindChild("FilterOptionsLevelMinContainer"):FindChild("FilterOptionsLevelEditBox"):SetText(nLevelMin)
	end
	if nLevelMax == knMaxLevel then
		wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelUpBtn"):Enable(false)
		wndFilter:FindChild("FilterOptionsLevelMaxContainer"):FindChild("FilterOptionsLevelEditBox"):SetText(nLevelMax)
	end
	if nLevelMin ~= knMinLevel or nLevelMax ~= knMaxLevel then
		table.insert(tOptions, { nType = MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterLevel, nMin = nLevelMin, nMax = nLevelMax })
	end

	-- Max Buyout Price
	local nMaxBuyout = tonumber(wndFilter:FindChild("FilterOptionsBuyoutCash"):GetAmount()) or 0
	if nMaxBuyout > 0 then
		table.insert(tOptions, { nType = MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterBuyoutMax, monMax = wndFilter:FindChild("FilterOptionsBuyoutCash"):GetCurrency() })
	end
	--wndFilter:FindChild("FilterOptionsBuyoutCashHelpText"):Show(nMaxBuyout == 0)

	-- Rarity
	local eRarityMin = wndFilter:FindChild("FilterOptionsRarityMinContainer"):GetData()
	local eRarityMax = wndFilter:FindChild("FilterOptionsRarityMaxContainer"):GetData()
	if eRarityMin and eRarityMax then
		table.insert(tOptions, { nType = MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterQuality, nMin = eRarityMin, nMax = eRarityMax })
	end

	-- Runes or Stats
	-- The min values can be increased and it should work, our default UI will just use 1 though
	for idx = 1, 3 do
		local tStatBtnData = wndFilter:FindChild("FilterOptionsStatBtn"..idx):GetData() -- Data can be nil, which is valid
		local nStatType = tStatBtnData and tStatBtnData[2] or nil
		local eStatProperty = tStatBtnData and tStatBtnData[3] or nil
		if eStatProperty and nStatType == MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterPropertyMin then
			table.insert(tOptions, { nType = nStatType, eProperty = eStatProperty, fMin = 1 })
		elseif eStatProperty and nStatType == MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterGlyphSlot then
			table.insert(tOptions, { nType = nStatType, eMicrochipType = eStatProperty, nMin = 1 })
		end
	end

	return tOptions
end

-----------------------------------------------------------------------------------------------
-- Main Buy Draw
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:InitializeBuy()
	local arFilters = self:GetBuyFilterOptions()

	local nSearchId = self.nSearchId
	local strSearchEnum = self.strSearchEnum
	local strSearchQuery = tostring(self.wndMain:FindChild("SearchEditBox"):GetText())

	local tSortData = self.wndMain:FindChild("SortOptionsBtn"):GetData()
	local eAuctionSort = tSortData and tSortData.eAuctionSort or MarketplaceLib.AuctionSort.TimeLeft
	local bReverseSort = tSortData and tSortData.bReverse or false
	local nPropertySort = tSortData and tSortData.nPropertySort or false

	self.fnLastSearch = function(nPage)
		self.wndMain:FindChild("SearchResultList"):SetVScrollPos(0)
		self.wndMain:FindChild("SearchResultList"):DestroyChildren()
		self.wndMain:FindChild("BuySearchFirstBtn"):Enable(false)
		self.wndMain:FindChild("BuySearchPrevBtn"):Enable(false)
		self.wndMain:FindChild("BuySearchNextBtn"):Enable(false)
		self.wndMain:FindChild("BuySearchLastBtn"):Enable(false)

		if #arFilters > MarketplaceLib.kAuctionSearchMaxFilters then
			self.wndMain:FindChild("SearchResultTooManyResults"):SetText(Apollo.GetString("MarketplaceAuction_TooManyFilters"))
		elseif strSearchQuery and string.len(strSearchQuery) > 0 then
			local nFamilyId, nCategoryId, nTypeId = 0, 0, 0 -- strSearchEnum can be nil, at which point it will be a global search
			if strSearchEnum == "Top" then
				nFamilyId = nSearchId
			elseif strSearchEnum == "Mid" then
				nCategoryId = nSearchId
			elseif strSearchEnum == "Bot" then
				nTypeId = nSearchId
			end

			-- Exit early if too many items in the search
			local tPackagedData = {}
			--local strTooManyResults = ""
			for idx, tData in pairs(MarketplaceLib.SearchAuctionableItems(strSearchQuery, nFamilyId, nCategoryId, nTypeId)) do -- This is a local call and won't hit the server
				if #tPackagedData > MarketplaceLib.kAuctionSearchMaxIds then
					break
				else
					--strTooManyResults = strTooManyResults .. "\n" .. tData.strName
					table.insert(tPackagedData, tData.nId or 0)
				end
			end

			if #tPackagedData > MarketplaceLib.kAuctionSearchMaxIds then
				self.wndMain:FindChild("SearchResultList"):SetText(Apollo.GetString("MarketplaceAuction_TooManyResults"))
			elseif #tPackagedData > 0 then
				MarketplaceLib.RequestItemAuctionsByItems(tPackagedData, nPage, eAuctionSort, bReverseSort, arFilters, nil, nil, nPropertySort)
			else
				self.wndMain:FindChild("SearchResultList"):SetText(Apollo.GetString("MarketplaceAuction_SearchNotPossible"))
			end
		elseif strSearchEnum == "Top" then
			MarketplaceLib.RequestItemAuctionsByFamily(nSearchId, nPage, eAuctionSort, bReverseSort, arFilters, nil, nil, nPropertySort)
		elseif strSearchEnum == "Mid" then
			MarketplaceLib.RequestItemAuctionsByCategory(nSearchId, nPage, eAuctionSort, bReverseSort, arFilters, nil, nil, nPropertySort)
		elseif strSearchEnum == "Bot" then
			MarketplaceLib.RequestItemAuctionsByType(nSearchId, nPage, eAuctionSort, bReverseSort, arFilters, nil, nil, nPropertySort)
		end
	end

	self.fnLastSearch(0)
end

function MarketplaceAuction:OnItemAuctionSearchResults(nPage, nTotalResults, tAuctions)
	-- This is the second stage of drawing, where we have received data for the windows from code
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndParent = nil
	local bBuyTab = self.wndMain:FindChild("HeaderBuyBtn"):IsChecked()
	if bBuyTab then
		wndParent = self.wndMain:FindChild("BuyContainer"):FindChild("SearchResultList")
	else
		wndParent = self.wndMain:FindChild("SellContainer"):FindChild("SellRightSide"):FindChild("SellSimilarItemsList")
	end
	wndParent:DestroyChildren()

	-- Main Draw
	for idx, aucCurr in ipairs(tAuctions) do
		self:BuildListItem(aucCurr, wndParent, bBuyTab)
	end
	wndParent:ArrangeChildrenVert(0)

	-- Pages (if buy). For sell, just ignore.
	if bBuyTab then
		self.nCurPage = nPage
		self.nTotalResults = nTotalResults

		local bHasPages = nTotalResults > MarketplaceLib.kAuctionSearchPageSize
		local bIsLast = (nPage + 1) * MarketplaceLib.kAuctionSearchPageSize >= nTotalResults
		self.wndMain:FindChild("BuyPageBtnContainer"):Show(bHasPages)
		self.wndMain:FindChild("BuySearchFirstBtn"):Enable(nPage > 0)
		self.wndMain:FindChild("BuySearchPrevBtn"):Enable(nPage > 0)
		self.wndMain:FindChild("BuySearchNextBtn"):Enable(not bIsLast)
		self.wndMain:FindChild("BuySearchLastBtn"):Enable(not bIsLast)

		-- Resize and update
		local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
		wndParent:SetAnchorOffsets(nLeft, nTop, nRight, bHasPages and -32 or 0)

		-- Not found text
		local bNoResults = #wndParent:GetChildren() == 0
		if bNoResults and self.wndMain:FindChild("FilterContainer"):FindChild("FilterClearBtn"):GetData() then
			self.wndMain:FindChild("SearchResultList"):SetText(Apollo.GetString("Tradeskills_NoResults").."\n"..Apollo.GetString("MarketplaceAuction_TryClearingFilter"))
		elseif bNoResults then
			self.wndMain:FindChild("SearchResultList"):SetText(Apollo.GetString("Tradeskills_NoResults"))
		else
			self.wndMain:FindChild("SearchResultList"):SetText("")
		end
	end
end

function MarketplaceAuction:BuildListItem(aucCurr, wndParent, bBuyTab)
	local itemCurr = aucCurr:GetItem()
	local bIsOwnAuction = aucCurr:IsOwned()
	local nBuyoutPrice = aucCurr:GetBuyoutPrice():GetAmount()
	local nDefaultBid = math.max(aucCurr:GetMinBid():GetAmount(), aucCurr:GetCurrentBid():GetAmount())

	local strFormToLoad = "BuyNowItem"
	if nBuyoutPrice == 0 then
		strFormToLoad = "BidOnlyItem"
	elseif nDefaultBid >= nBuyoutPrice then
		strFormToLoad = "BuyOnlyItem"
	end

	local wnd = Apollo.LoadForm(self.xmlDoc, strFormToLoad, wndParent, self)
	wnd:SetData(aucCurr)
	wnd:FindChild("RowSelectBtn"):SetData(aucCurr)
	wnd:FindChild("RowSelectBtn"):Show(bBuyTab)
	wnd:FindChild("ListName"):SetText(itemCurr:GetName())
	wnd:FindChild("ListIcon"):SetSprite(itemCurr:GetIcon())
	wnd:FindChild("ListIcon"):SetText(aucCurr:GetCount() <= 1 and "" or aucCurr:GetCount())

	local eTimeRemaining = aucCurr:GetTimeRemainingEnum()
	if bIsOwnAuction then
		wnd:FindChild("ListExpires"):SetText(self:HelperFormatTimeString(aucCurr:GetExpirationTime()))
		wnd:FindChild("ListExpiresIcon"):SetSprite("Market:UI_Auction_Icon_TimeGreen")
		wnd:FindChild("ListExpires"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))

	elseif eTimeRemaining == ItemAuction.CodeEnumAuctionRemaining.Very_Long then
		wnd:FindChild("ListExpires"):SetTextRaw(String_GetWeaselString(Apollo.GetString("MarketplaceAuction_VeryLong"), kstrAuctionOrderDuration))
		wnd:FindChild("ListExpires"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
		wnd:FindChild("ListExpiresIcon"):Show("Market:UI_Auction_Icon_TimeGreen")

	else
		wnd:FindChild("ListExpires"):SetTextRaw(ktTimeRemaining[eTimeRemaining])
		wnd:FindChild("ListExpires"):SetTextColor(ApolloColor.new("xkcdDullRed"))
		wnd:FindChild("ListExpiresIcon"):Show("Market:UI_Auction_Icon_TimeRed")
	end
	wnd:FindChild("OwnAuctionLabel"):Show(bIsOwnAuction)
	wnd:FindChild("TopBidAuctionLabel"):Show(aucCurr:IsTopBidder())

	if wnd:FindChild("BidPrice") then
		wnd:FindChild("BidPrice"):SetAmount(nDefaultBid)
	end

	if wnd:FindChild("BuyNowPrice") then
		local bCanAffordBuyNow = self.wndPlayerCashWindow:GetAmount() >= nBuyoutPrice
		wnd:FindChild("BuyNowPrice"):SetAmount(nBuyoutPrice)
		wnd:FindChild("BuyNowPrice"):SetTextColor(bCanAffordBuyNow and "UI_TextHoloTitle" or "UI_BtnTextRedNormal")
	end
end

function MarketplaceAuction:OnRowSelectBtnUncheck(wndHandler, wndControl)
	local wndParent = self.wndMain:FindChild("BuyContainer"):FindChild("BuyBottomContainer")

	wndParent:SetData(nil)
	wndParent:FindChild("BottomBuyName"):SetText("")
	wndParent:FindChild("BottomBuyIcon"):SetSprite("")
	wndParent:FindChild("BottomBuyIconBG"):Show(false)
	wndParent:FindChild("BottomBidResetBtn"):Show(false)

	wndParent:FindChild("BottomBidBtn"):Enable(false)
	wndParent:FindChild("BottomBuyoutBtn"):Enable(false)
	wndParent:FindChild("BottomBidPrice"):Enable(false)
	wndParent:FindChild("BottomBidPriceUpBtn"):Enable(false)
	wndParent:FindChild("BottomBidPriceDownBtn"):Enable(false)
	wndParent:FindChild("BottomBuyoutPrice"):SetAmount(0)
	wndParent:FindChild("BottomBidPrice"):SetAmount(0)
end

function MarketplaceAuction:OnRowSelectBtnCheck(wndHandler, wndControl)
	local aucCurr = wndHandler:GetData()
	local itemCurr = aucCurr:GetItem()
	if not itemCurr then
		return
	end

	local nDefaultBid = math.max(aucCurr:GetMinBid():GetAmount(), aucCurr:GetCurrentBid():GetAmount())
	local wndParent = self.wndMain:FindChild("BuyContainer"):FindChild("BuyBottomContainer")

	wndParent:SetData(aucCurr)
	wndParent:FindChild("BottomBuyName"):SetText(itemCurr:GetName())
	wndParent:FindChild("BottomBuyIcon"):SetSprite(itemCurr:GetIcon())
	wndParent:FindChild("BottomBuyIconBG"):Show(true)

	wndParent:FindChild("BottomBidBtn"):SetData(wndParent)
	wndParent:FindChild("BottomBuyoutBtn"):SetData(wndParent)
	wndParent:FindChild("BottomBidPrice"):SetData(wndParent)
	wndParent:FindChild("BottomBidResetBtn"):SetData(wndParent)
	wndParent:FindChild("BottomBidPriceUpBtn"):SetData(wndParent)
	wndParent:FindChild("BottomBidPriceDownBtn"):SetData(wndParent)

	wndParent:FindChild("BottomBidPrice"):Enable(true)
	wndParent:FindChild("BottomBidPrice"):SetAmount(nDefaultBid)
	wndParent:FindChild("BottomBuyoutPrice"):SetAmount(aucCurr:GetBuyoutPrice():GetAmount())

	self:HelperValidateBidEditBoxInput()
end

-----------------------------------------------------------------------------------------------
-- Buy Btns
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnItemAuctionBuyOrderSubmitted(bSuccess)
end

function MarketplaceAuction:OnBidPriceUpBtn(wndHandler, wndControl)
	local wndParent = wndHandler:GetData()
	local aucCurr = wndParent:GetData()
	self:OnHelperBidPriceEditBox(wndParent, aucCurr, true)
end

function MarketplaceAuction:OnBidPriceDownBtn(wndHandler, wndControl)
	local wndParent = wndHandler:GetData()
	local aucCurr = wndParent:GetData()
	self:OnHelperBidPriceEditBox(wndParent, aucCurr, false)
end

function MarketplaceAuction:OnHelperBidPriceEditBox(wndParent, aucCurr, bAdd)
	local nOldValue = tonumber(wndParent:FindChild("BottomBidPrice"):GetAmount()) or 1
	local nNewValue = math.min(knMaxPlat, math.max(0, bAdd and nOldValue + 1 or nOldValue - 1))

	wndParent:SetFocus()
	wndParent:FindChild("BottomBidResetBtn"):Show(true)
	wndParent:FindChild("BottomBidPrice"):SetAmount(nNewValue)

	self:HelperValidateBidEditBoxInput()
end

function MarketplaceAuction:OnBidResetBtn(wndHandler, wndControl)
	local wndParent = wndHandler:GetData()
	local aucCurr = wndParent:GetData()

	local nDefaultBid = math.max(aucCurr:GetMinBid():GetAmount(), aucCurr:GetCurrentBid():GetAmount())
	wndParent:FindChild("BottomBidResetBtn"):Show(false)
	wndParent:FindChild("BottomBidPriceUpBtn"):Enable(nDefaultBid < aucCurr:GetBuyoutPrice():GetAmount())
	wndParent:FindChild("BottomBidPriceDownBtn"):Enable(false)
	wndParent:FindChild("BottomBuyoutPrice"):SetTextColor(ApolloColor.new("UI_WindowTitleGray"))
	wndParent:FindChild("BottomBidPrice"):SetTextColor(ApolloColor.new("UI_WindowTitleGray"))
	wndParent:FindChild("BottomBidPrice"):SetAmount(nDefaultBid)
	wndParent:SetFocus()

	self:HelperValidateBidEditBoxInput()
end

function MarketplaceAuction:OnBidPriceAmountChanged(wndHandler, wndControl) -- BidPrice, data is parent
	wndHandler:SetText(math.max(0, tonumber(wndHandler:GetAmount() or 0)))

	local wndParent = wndHandler:GetData()
	wndParent:FindChild("BottomBidResetBtn"):Show(true)
	self:HelperValidateBidEditBoxInput()
end

function MarketplaceAuction:HelperValidateBidEditBoxInput()
	local wndParent = self.wndMain:FindChild("BuyContainer"):FindChild("BuyBottomContainer")
	local aucCurr = wndParent:GetData()

	local bValidBidPrice = true
	local nPlayerCash = self.wndPlayerCashWindow:GetAmount()
	local nMinBidPrice = aucCurr:GetMinBid():GetAmount()
	local nCurrBidPrice = aucCurr:GetCurrentBid():GetAmount()
	local nBuyoutPrice = aucCurr:GetBuyoutPrice():GetAmount()
	local nAttemptPrice = wndParent:FindChild("BottomBidPrice"):GetAmount()

	-- Up Down Arrows
	if nAttemptPrice < nMinBidPrice or nAttemptPrice < nCurrBidPrice or nAttemptPrice > nPlayerCash then
		bValidBidPrice = false
		wndParent:FindChild("BottomBidPriceUpBtn"):Enable(true)
		wndParent:FindChild("BottomBidPriceDownBtn"):Enable(false)
	elseif nBuyoutPrice > 0 and nBuyoutPrice < nAttemptPrice then
		bValidBidPrice = false
		wndParent:FindChild("BottomBidPriceUpBtn"):Enable(false)
		wndParent:FindChild("BottomBidPriceDownBtn"):Enable(true)
	else
		wndParent:FindChild("BottomBidPriceUpBtn"):Enable(nAttemptPrice < nBuyoutPrice)
		wndParent:FindChild("BottomBidPriceDownBtn"):Enable(nAttemptPrice > nMinBidPrice and nAttemptPrice > nCurrBidPrice)
	end

	-- Buttons
	local bBidOnly = false
	local bBuyoutOnly = false
	local nDefaultBid = math.max(nMinBidPrice, nCurrBidPrice)
	if nBuyoutPrice == 0 then
		bBidOnly = true
	elseif nDefaultBid >= nBuyoutPrice then
		bBuyoutOnly = true
	end

	local bCanBuyout = not bBidOnly and not aucCurr:IsOwned() and nBuyoutPrice <= nPlayerCash
	wndParent:FindChild("BottomBuyoutBtn"):Enable(bCanBuyout)
	if bCanBuyout then
		wndParent:FindChild("BottomBuyoutBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.MarketplaceAuctionBuySubmit, aucCurr, true)
	end

	wndParent:FindChild("BottomBuyoutPrice"):SetTextColor(bCanBuyout and "UI_WindowTitleGray" or "UI_BtnTextRedNormal")
	wndParent:FindChild("BottomBidPrice"):SetTextColor(bValidBidPrice and "UI_WindowTitleGray" or "UI_BtnTextRedNormal")

	local bCanBid = not bBuyoutOnly and bValidBidPrice and not aucCurr:IsTopBidder() and not aucCurr:IsOwned()
	wndParent:FindChild("BottomBidBtn"):Enable(bCanBid)
	if bCanBid then
		local monBidPrice = wndParent:FindChild("BottomBidPrice"):GetCurrency()
		wndParent:FindChild("BottomBidBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.MarketplaceAuctionBuySubmit, aucCurr, false, monBidPrice)
	end
end

-----------------------------------------------------------------------------------------------
-- Category Buttons
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnCategoryTopBtnCheck(wndHandler, wndControl) -- CategoryTopBtn
	self.wndMain:SetGlobalRadioSel("MarketplaceAuction_CategoryMidBtn_GlobalRadioGroup", -1)

	self.nSearchId = nil
	self.strSearchEnum = nil

	local wndParent = wndHandler:GetData()
	if wndHandler:IsChecked() and wndParent then
		local wndAllBtn = wndParent:FindChild("CategoryTopList") and wndParent:FindChild("CategoryTopList"):FindChild("CategoryMidItem_All") or nil
		if wndAllBtn then
			wndAllBtn:FindChild("CategoryMidBtn"):SetCheck(true)
			wndAllBtn:FindChild("CategoryMidBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))

			-- TODO Refactor these out if possible
			self.nSearchId = wndAllBtn:FindChild("CategoryMidBtn"):GetData()[1]
			self.strSearchEnum = wndAllBtn:FindChild("CategoryMidBtn"):GetData()[2]
		end
	end

	self:OnRefreshBtn()
	self:OnResizeCategories()
end

function MarketplaceAuction:OnCategoryTopBtnUncheck(wndHandler, wndControl) -- CategoryTopBtn
	self.wndMain:SetGlobalRadioSel("MarketplaceAuction_CategoryMidBtn_GlobalRadioGroup", -1)

	self.nSearchId = nil
	self.strSearchEnum = nil

	self:OnResizeCategories()
end

function MarketplaceAuction:OnCategoryMidBtnCheck(wndHandler, wndControl)
	wndHandler:FindChild("CategoryMidBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))

	-- TODO refactor these variables
	self.nSearchId = wndHandler:GetData()[1]
	self.strSearchEnum = wndHandler:GetData()[2]
	self:OnRefreshBtn()
end

function MarketplaceAuction:OnCategoryMidBtnUncheck(wndHandler, wndControl)
	wndHandler:FindChild("CategoryMidBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
end

-----------------------------------------------------------------------------------------------
-- Sell Mode
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnUpdateInventory()
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("HeaderSellBtn"):IsChecked() then
		self:InitializeSell()
	end
end

function MarketplaceAuction:InitializeSell()
	self.wndMain:FindChild("SellLeftSideItemList"):DestroyChildren()

	local unitPlayer = GameLib.GetPlayerUnit()
	for idx, itemCurr in ipairs(unitPlayer:GetAuctionableItems()) do
		if itemCurr and itemCurr:IsAuctionable() then
			local wndCurr = self:LoadByName("SellListItem", self.wndMain:FindChild("SellLeftSideItemList"), "SellListItem"..itemCurr:GetName())
			wndCurr:SetData(itemCurr)
			wndCurr:SetName(itemCurr:GetName())
			wndCurr:FindChild("ListItemTitle"):SetText(itemCurr:GetName())
			wndCurr:FindChild("ListItemIcon"):SetSprite(itemCurr:GetIcon())
		end
	end

	local bListIsEmpty = #self.wndMain:FindChild("SellLeftSideItemList"):GetChildren() == 0
	self.wndMain:FindChild("SellLeftSideItemList"):ArrangeChildrenVert(0, function (a,b) return a:GetName() < b:GetName() end)
	self.wndMain:FindChild("SellLeftSideItemList"):SetText(bListIsEmpty and Apollo.GetString("MarketplaceAuction_NoItemsToSell") or "")
end

function MarketplaceAuction:OnSellListItemCheck(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler:FindChild("ListItemTitle") then
		return
	end

	local itemSelling = wndHandler:GetData()
	if not itemSelling or not itemSelling:IsAuctionable() then -- TODO: Error handling?
		return
	end

	local wndParent = self.wndMain:FindChild("SellRightSide")
	wndParent:FindChild("CreateSellOrderBtn"):SetData(itemSelling)

	wndParent:Show(true)
	wndParent:FindChild("BigIcon"):SetSprite(itemSelling:GetIcon())
	wndParent:FindChild("BigItemName"):SetText(itemSelling:GetName())

	wndParent:FindChild("CreateBidInputBox"):SetTooltip("")
	wndParent:FindChild("CreateBidInputBox"):SetTextColor(ApolloColor.new("White"))
	wndParent:FindChild("CreateBuyoutInputBox"):SetTooltip("")
	wndParent:FindChild("CreateBuyoutInputBox"):SetTextColor(ApolloColor.new("White"))
	wndParent:FindChild("CreateSellOrderCostBox"):SetTooltip("")
	wndParent:FindChild("CreateSellOrderCostBox"):SetTextColor(ApolloColor.new("White"))
	self:HelperBuildItemTooltip(wndParent:FindChild("BigIcon"), itemSelling)

	local nVendorPrice = 1
	if itemSelling:GetSellPrice() and itemSelling:GetSellPrice():GetAmount() > 0 then
		nVendorPrice = itemSelling:GetSellPrice():GetAmount()
	end

	wndParent:FindChild("CreateBidInputBox"):SetAmount(nVendorPrice)
	wndParent:FindChild("CreateBidInputBox"):SetData(nVendorPrice) -- Min price to break even
	wndParent:FindChild("CreateBuyoutInputBox"):SetAmount(nVendorPrice + 1)
	wndParent:FindChild("CreateBuyoutInputBox"):SetData(nVendorPrice + 1) -- Min price to break even
	wndParent:FindChild("CreateSellOrderCostBox"):SetAmount(MarketplaceLib.GetItemAuctionCost(itemSelling))
	wndParent:FindChild("CreateSellListingLength"):SetText(String_GetWeaselString(Apollo.GetString("MarketplaceAuction_ListingLength"), kstrAuctionOrderDuration))

	wndHandler:FindChild("ListItemTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))

	self:ValidateSellOrder()

	-- Return in OnItemAuctionSearchResults
	-- Options are hardcoded
	local nPage = 0
	local bReverseSort = true
	MarketplaceLib.RequestItemAuctionsByItems({ itemSelling:GetItemId() }, nPage, MarketplaceLib.AuctionSort.Buyout, bReverseSort, nil, nil, nil, nil)
end

function MarketplaceAuction:OnSellListItemUncheck(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler:FindChild("ListItemTitle") then
		return
	end

	wndHandler:FindChild("ListItemTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGrayListNormal"))
	self.wndMain:FindChild("SellRightSide"):Show(false)
end

function MarketplaceAuction:OnCreateBidInputBoxChanged(wndHandler, wndControl)
	self:ValidateSellOrder()
end

function MarketplaceAuction:OnCreateBuyoutInputBoxChanged(wndHandler, wndControl)
	self:ValidateSellOrder()
end

function MarketplaceAuction:ValidateSellOrder() -- CreateSellOrderBtn data is oItemInstance
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndSellOrderBtn = self.wndMain:FindChild("SellContainer"):FindChild("CreateSellOrderBtn")
	local wndBidInputBox = self.wndMain:FindChild("SellContainer"):FindChild("CreateBidInputBox")
	local wndBuyoutInputBox = self.wndMain:FindChild("SellContainer"):FindChild("CreateBuyoutInputBox")
	local wndBidErrorIcon = self.wndMain:FindChild("SellContainer"):FindChild("CreateBidErrorIcon")

	local itemMerchendice = wndSellOrderBtn:GetData()
	local monBidPrice = wndBidInputBox:GetCurrency() -- not an integer
	local monBuyoutPrice = wndBuyoutInputBox:GetCurrency() -- not an integer

	wndBidErrorIcon:Show(false)
	wndBidInputBox:SetTextColor("white")
	wndBuyoutInputBox:SetTextColor("white")

	local bValidSellOrder = true
	if not itemMerchendice or not itemMerchendice:isInstance() or not itemMerchendice:IsAuctionable() then
		bValidSellOrder = false
		self:OnPostCustomMessage(Apollo.GetString("MarketplaceAuction_InvalidItem"), false, 4)

	elseif not monBidPrice or monBidPrice:GetAmount() < 1 then
		bValidSellOrder = false
		wndBidErrorIcon:Show(true)
		wndBidErrorIcon:SetTooltip(Apollo.GetString("MarketplaceAuction_InvalidPrice"))
		wndBidInputBox:SetTextColor("AddonError")

	elseif monBuyoutPrice:GetAmount() > 0 and monBidPrice:GetAmount() > monBuyoutPrice:GetAmount() then
		bValidSellOrder = false
		wndBidErrorIcon:Show(true)
		wndBidErrorIcon:SetTooltip(Apollo.GetString("MarketplaceAuction_BidHigherThanBuyout"))
		wndBidInputBox:SetTextColor("AddonError")
	end

	wndSellOrderBtn:Enable(bValidSellOrder)
	if bValidSellOrder then
		wndSellOrderBtn:SetActionData(GameLib.CodeEnumConfirmButtonType.MarketplaceAuctionSellSubmit, itemMerchendice, monBidPrice, monBuyoutPrice)
	end
end

function MarketplaceAuction:OnItemAuctionSellOrderSubmitted(wndHandler, wndControl)
	self.wndMain:FindChild("SellLeftSideItemList"):DestroyChildren()
	self.wndMain:FindChild("SellRightSide"):Show(false)
	self:ToggleAndInitializeBuyOrSell()
end

function MarketplaceAuction:OnBuySearchListItemMouseEnter(wndHandler, wndControl) -- Build on mouse enter and not every hit to save computation time
	if wndHandler == wndControl and wndHandler:GetData() then
		local aucCurr = wndHandler:GetData()
		self:HelperBuildItemTooltip(wndHandler:FindChild("ListIcon"), aucCurr:GetItem())
	end
end

function MarketplaceAuction:OnBuySearchListItemMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:FindChild("ListIcon") then
		wndHandler:FindChild("ListIcon"):SetTooltipDoc(nil)
	end
end

function MarketplaceAuction:OnSellListItemMouseEnter(wndHandler, wndControl) -- ListItem, data should be an item
	-- Build on mouse enter and not every hit to save computation time
	self:HelperBuildItemTooltip(wndHandler:FindChild("ListItemIcon"), wndHandler:GetData())
end

-----------------------------------------------------------------------------------------------
-- Result Notification
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnPostItemAuctionResult(eAuctionPostResult, aucCurr)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local bResultOK = eAuctionPostResult == MarketplaceLib.AuctionPostResult.Ok
	local strMessage = bResultOK and String_GetWeaselString(Apollo.GetString("MarketplaceAuction_PostAccepted"), aucCurr:GetItem():GetName()) or Apollo.GetString("UnknownError")
	self:OnPostCustomMessage(kAuctionPostResultToString[eAuctionPostResult] or strMessage, bResultOK, 4)

	if bResultOK then
		self:UpdateOrderLimit(self.nOwnedAuctionCount + 1)
	end
end

function MarketplaceAuction:OnItemAuctionBidResult(eAuctionBidResult, aucCurr)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local bResultOK = eAuctionBidResult == MarketplaceLib.AuctionPostResult.Ok
	local strMessage = bResultOK and String_GetWeaselString(Apollo.GetString("MarketplaceAuction_BidAccepted"), aucCurr:GetItem():GetName()) or Apollo.GetString("UnknownError")
	self:OnPostCustomMessage(kAuctionPostResultToString[eAuctionBidResult] or strMessage, bResultOK, 4)

	if eAuctionBidResult == MarketplaceLib.AuctionPostResult.Ok then
		self.fnLastSearch(self.nCurPage)
	elseif eAuctionBidResult == MarketplaceLib.AuctionPostResult.NotFound then
		self.fnLastSearch(self.nCurPage)
	end
end

function MarketplaceAuction:OnItemCancelResult(eAuctionEventType, aucCurr)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if eAuctionEventType ~= MarketplaceLib.AuctionPostResult.Ok then
		return
	end

	self:UpdateOrderLimit(self.nOwnedAuctionCount - 1)
end

function MarketplaceAuction:OnPostCustomMessage(strMessage, bResultOK, nDuration)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local strTitle = bResultOK and Apollo.GetString("CRB_Success") or Apollo.GetString("MarketplaceAuction_ErrorLabel")
	self.wndMain:FindChild("PostResultNotification"):Show(true)
	self.wndMain:FindChild("PostResultNotification"):SetTooltip(strTitle)
	self.wndMain:FindChild("PostResultNotificationSubText"):SetText(strMessage)
	self.wndMain:FindChild("PostResultNotificationCheck"):SetSprite(bResultOK and "Icon_Windows_UI_CRB_Checkmark" or "LootCloseBox")
	self.wndMain:FindChild("PostResultNotificationLabel"):SetTextColor(bResultOK and ApolloColor.new("ff7fffb9") or ApolloColor.new("ffb80000"))
	self.wndMain:FindChild("PostResultNotificationLabel"):SetText(strTitle)

	Apollo.StopTimer("PostResultTimer")
	Apollo.CreateTimer("PostResultTimer", nDuration, false)
end

function MarketplaceAuction:OnPostResultTimer()
	if self.wndMain and self.wndMain:IsValid() then
		Apollo.StopTimer("PostResultTimer")
		self.wndMain:FindChild("PostResultNotification"):Show(false)
	end
end

function MarketplaceAuction:OnItemAuctionWon(aucCurrent)
	local bValidItem = aucCurrent and aucCurrent:GetItem()
	local strItemName = bValidItem and aucCurrent:GetItem():GetName() or ""
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("MarketplaceAuction_WonMessage"), strItemName))

	if aucCurrent:IsOwned() then
		self:UpdateOrderLimit(self.nOwnedAuctionCount - 1)
	end
end

function MarketplaceAuction:OnItemAuctionOutbid(aucCurrent)
	local bValidItem = aucCurrent and aucCurrent:GetItem()
	local strItemName = bValidItem and aucCurrent:GetItem():GetName() or ""
	local strBid = aucCurrent:GetCurrentBid():GetMoneyString()
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("MarketplaceAuction_OutbidMessage"), strItemName, strBid))
end

function MarketplaceAuction:OnItemAuctionExpired(aucCurrent)
	-- TODO: Investigate if this spams if someone puts up 10+ auctions in the span of a few seconds
	local bValidItem = aucCurrent and aucCurrent:GetItem()
	local strItemName = bValidItem and aucCurrent:GetItem():GetName() or ""
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("MarketplaceAuction_ExpiredMessage"), strItemName))

	if aucCurrent:IsOwned() then
		self:UpdateOrderLimit(self.nOwnedAuctionCount - 1)
	end
end

-----------------------------------------------------------------------------------------------
-- Buy Page Helpers
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnBuySearchFirstBtn(wndHandler, wndControl)
	self.fnLastSearch(0)
end

function MarketplaceAuction:OnBuySearchPrevBtn(wndHandler, wndControl)
	if self.nCurPage > 0 then
		self.fnLastSearch(self.nCurPage - 1)
	end
end

function MarketplaceAuction:OnBuySearchNextBtn(wndHandler, wndControl)
	self.fnLastSearch(self.nCurPage + 1)
end

function MarketplaceAuction:OnBuySearchLastBtn(wndHandler, wndControl)
	self.fnLastSearch(math.floor(self.nTotalResults / MarketplaceLib.kAuctionSearchPageSize))
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function MarketplaceAuction:OnPostResultNotificationClick(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:Show(false)
	end
end

function MarketplaceAuction:OnOpenMarketListingsBtn(wndHandler, wndControl)
	Event_FireGenericEvent("InterfaceMenu_ToggleMarketplaceListings")
end

function MarketplaceAuction:OnOwnedItemAuctions(tAuctions) -- From MarketplaceLib.RequestOwnedItemAuctions()
	local nCount = 0
	for nIdx, tCurrOrder in pairs(tAuctions) do
		if tCurrOrder and tCurrOrder:IsOwned() then -- TODO: Eventually show bids?
			nCount = nCount + 1
		end
	end

	self:UpdateOrderLimit(nCount)
end

function MarketplaceAuction:UpdateOrderLimit(nCount)
	if nCount < 0 then
		self.nOwnedAuctionCount = 0
	else
		self.nOwnedAuctionCount = nCount
	end

	if self.wndOrderLimitText then
		self.wndOrderLimitText:SetText(String_GetWeaselString(Apollo.GetString("MarketplaceCommodity_OrderLimitCount"), self.nOwnedAuctionCount, MarketplaceLib.kMaxPlayerAuctions))
	end
end

function MarketplaceAuction:OnGenericEditBoxMouseDown(wndHandler, wndControl)
	wndHandler:SetStyleEx("SkipZeroes", false)
end

function MarketplaceAuction:OnGenericEditBoxLoseFocus(wndHandler, wndControl)
	wndHandler:SetStyleEx("SkipZeroes", true)
end

function MarketplaceAuction:HelperBuildItemTooltip(wndArg, itemSource, itemModData)
	Tooltip.GetItemTooltipForm(self, wndArg, itemSource, {bPrimary = true, bSelling = false, itemModData = itemModData, itemCompare = itemSource:GetEquippedItemForItemType()})
end

function MarketplaceAuction:HelperFormatTimeString(oExpirationTime)
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

function MarketplaceAuction:LoadByName(strForm, wndParent, strCustomName)
	local wndNew = wndParent:FindChild(strCustomName)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strForm, wndParent, self)
		wndNew:SetName(strCustomName)
	end
	return wndNew
end

local MarketplaceAuctionInst = MarketplaceAuction:new()
MarketplaceAuctionInst:Init()


