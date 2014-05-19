-----------------------------------------------------------------------------------------------
-- Client Lua Script for MarketplaceCREDD
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CREDDExchangeLib"
require "CREDDExchangeOrder"

local MarketplaceCREDD = {}

local ktResultErrorCodeStrings =
{
	[CREDDExchangeLib.CodeEnumAccountOperationResult.GenericFail] = "Generic Failure.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.DBError] = "Generic Failure.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidOffer] = "Invalid order.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidPrice] = "Invalid price.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NotEnoughCurrency] = "Not enough currency.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NeedTransaction] = "Need transaction",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidAccountItem] = "Invalid account item.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidPendingItem] = "Invalid escrow item.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidInventoryItem] = "Invalid item.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoConnection] = "No connection.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoCharacter] = "No character.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.AlreadyClaimed] = "Already claimed",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.MaxEntitlementCount] = "At max entitement count.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoRegift] = "No regift.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoGifting] = "No gifting.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidFriend] = "Invalid friend.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidCoupon] = "Invalid coupon.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.CannotReturn] = "Can't return.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.Prereq] = "Prereq not met.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.CREDDExchangeNotLoaded] = "C.R.E.D.D. Exchange is busy. Please try again.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoCREDD] = "Not enough C.R.E.D.D. for order.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoMatchingOrder] = "Could not find matching market order. Someone may have already claimed it at your price.",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidCREDDOrder] = "Invalid C.R.E.D.D. order."
}

local knSaveVersion = 1
local knMaxPlat = 9999999999 -- 9999 plat
local kMaxPlayerCreddOrders = 20

function MarketplaceCREDD:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function MarketplaceCREDD:Init()
    Apollo.RegisterAddon(self)
end

function MarketplaceCREDD:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	local tSaved =
	{
		tLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion
	}
	return tSaved
end

function MarketplaceCREDD:OnRestore(eType, tSavedData)
	self.nSaveVersion = tSavedData.nSaveVersion
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.tLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tLocation)
	end
end

function MarketplaceCREDD:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MarketplaceCREDD.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function MarketplaceCREDD:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("ToggleCREDDExchangeWindow", 	"OnToggleCREDDExchangeWindow", self)
end

function MarketplaceCREDD:Initialize()
	Apollo.RegisterEventHandler("CREDDExchangeWindowClose", 	"OnCREDDExchangeWindowClose", self)
	Apollo.RegisterEventHandler("CREDDExchangeInfoResults", 	"OnCREDDExchangeInfoResults", self)
	Apollo.RegisterEventHandler("AccountOperationResults", 		"OnCREDDExchangeOperationResults", self)
	Apollo.RegisterEventHandler("AccountInventoryUpdate", 		"RefreshBoundCredd", self)
	Apollo.RegisterEventHandler("AccountInventoryUpdate", 		"RefreshEscrow", self)

	Apollo.RegisterTimerHandler("HidePostResultNotification",	"OnHidePostResultNotification", self)
	Apollo.CreateTimer("HidePostResultNotification", 2, false)
	Apollo.StopTimer("HidePostResultNotification")

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "MarketplaceCREDDForm", nil, self)
	self.wndOpenOrders = Apollo.LoadForm(self.xmlDoc, "MarketplaceListingsForm", nil, self)

	self.tWindowMap =
	{
		["HeaderBuyBtn"]						=	self.wndMain:FindChild("HeaderBuyBtn"),
		["HeaderBuyBtn"]						=	self.wndMain:FindChild("HeaderBuyBtn"),
		["HeaderSellBtn"]						=	self.wndMain:FindChild("HeaderSellBtn"),
		["RefreshMarketBtn"]					=	self.wndMain:FindChild("RefreshMarketBtn"),
		["RefreshAnimation"]					=	self.wndMain:FindChild("RefreshAnimation"),
		["WaitingScreen"]						=	self.wndMain:FindChild("CommonAlertMessages:WaitingScreen"),
		["ActNowPrice"]							=	self.wndMain:FindChild("ActNowPrice"),
		["ActLaterPrice"]						=	self.wndMain:FindChild("ActLaterPrice"),
		["CreateSellNowBtn"]					=	self.wndMain:FindChild("CreateSellNowBtn"),
		["CreateSellOrderBtn"]					=	self.wndMain:FindChild("CreateSellOrderBtn"),
		["CreateBuyNowBtn"]						=	self.wndMain:FindChild("CreateBuyNowBtn"),
		["CreateBuyOrderBtn"]					=	self.wndMain:FindChild("CreateBuyOrderBtn"),
		["AccountBoundText"]					=	self.wndMain:FindChild("AccountBoundText"),
		["EscrowText"]							=	self.wndMain:FindChild("EscrowText"),
		["OpenListingsBtn"]						=	self.wndMain:FindChild("OpenListingsBtn"),
		["MoreMarketStats"]						=	self.wndMain:FindChild("MoreMarketStats"),
		["MainBuyContainer"]					=	self.wndMain:FindChild("MainBuyContainer"),
		["MainSellContainer"]					=	self.wndMain:FindChild("MainSellContainer"),
		["ConfirmationBlocker"]					=	self.wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker"),
		["ConfirmationTitle"]					=	self.wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationTitle"),
		["ConfirmationSubtitle"]				=	self.wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationSubtitle"),
		["ConfirmationBigCash"]					=	self.wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationBigCash"),
		["ConfirmationBigText"]					=	self.wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationBigText"),
		["ConfirmationTaxText"]					=	self.wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationTaxText"),
		["ConfirmationTaxCash"]					=	self.wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationTaxCash"),
		["PostResultNotification"]				=	self.wndMain:FindChild("CommonAlertMessages:PostResultNotification"),
		["PostResultNotificationCheck"]			=	self.wndMain:FindChild("CommonAlertMessages:PostResultNotification:PostResultNotificationCheck"),
		["PostResultNotificationLabel"]			=	self.wndMain:FindChild("CommonAlertMessages:PostResultNotification:PostResultNotificationLabel"),
		["PostResultNotificationSubText"]		=	self.wndMain:FindChild("CommonAlertMessages:PostResultNotification:PostResultNotificationSubText"),
	}
	self.tWindowMap["ActNowPrice"]:SetAmountLimit(knMaxPlat)
	self.tWindowMap["ActLaterPrice"]:SetAmountLimit(knMaxPlat)

	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.tWindowMap["HeaderBuyBtn"]:SetCheck(true)

	self.arOrders = nil
end

function MarketplaceCREDD:OnToggleCREDDExchangeWindow()
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end

	self.wndMain:Show(not self.wndMain:IsShown())
	if self.wndMain:IsShown() then
		self.wndMain:ToFront()
		CREDDExchangeLib.RequestExchangeInfo() -- Leads to OnCREDDExchangeInfoResults
	end
end

function MarketplaceCREDD:OnClose(wndHandler, wndControl, eMouseButton)
	if wndHandler == wndControl then
		self.wndMain:Destroy()
		-- TODO needs a
		--Event_CancelAuctionhouse()
		--Event_CancelCommodities()
	end
end

function MarketplaceCREDD:OnOpenListingsBtn(wndHandler, wndControl)
	Event_FireGenericEvent("InterfaceMenu_ToggleMarketplaceListings")
end

-----------------------------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------------------------

function MarketplaceCREDD:OnHeaderTabCheck(wndHandler, wndControl)
	CREDDExchangeLib.RequestExchangeInfo() -- Leads to OnCREDDExchangeInfoResults
end

function MarketplaceCREDD:OnRefreshMarketBtn(wndHandler, wndControl, eMouseButton)
	self.tWindowMap["RefreshAnimation"]:SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self.tWindowMap["RefreshMarketBtn"]:Enable(false)
	CREDDExchangeLib.RequestExchangeInfo() -- Leads to OnCREDDExchangeInfoResults
end

function MarketplaceCREDD:OnCREDDExchangeInfoResults(arMarketStats, arOrders) -- Main Redraw
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	local tBuyOrderData = arMarketStats.arBuyOrderPrices[1]
	local tSellOrderData = arMarketStats.arSellOrderPrices[1]
	local bBuyTabChecked = self.tWindowMap["HeaderBuyBtn"]:IsChecked()
	self.tWindowMap["CreateSellOrderBtn"]:Show(not bBuyTabChecked)
	self.tWindowMap["CreateSellNowBtn"]:Show(not bBuyTabChecked)
	self.tWindowMap["CreateBuyOrderBtn"]:Show(bBuyTabChecked)
	self.tWindowMap["CreateBuyNowBtn"]:Show(bBuyTabChecked)
	self.tWindowMap["ActNowPrice"]:SetAmount(bBuyTabChecked and tSellOrderData.monPrice or tBuyOrderData.monPrice)
	self.tWindowMap["ActNowPrice"]:SetTextColor(bBuyTabChecked and ApolloColor.new("ffc2e57f") or ApolloColor.new("UI_TextHoloBody"))
	self.tWindowMap["ActLaterPrice"]:SetAmount(0)
	self.tWindowMap["ActLaterPrice"]:SetTextColor(bBuyTabChecked and ApolloColor.new("ffc2e57f") or ApolloColor.new("UI_TextHoloBody"))

	-- Price Stats
	self.tWindowMap["MainBuyContainer"]:DestroyChildren()
	local wndMarketData = Apollo.LoadForm(self.xmlDoc, "MarketDataForm", self.tWindowMap["MainBuyContainer"], self)
	wndMarketData:FindChild("MarketDataFormLabel"):SetText("Top Buy Order")
	wndMarketData:FindChild("MarketDataFormLabel"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetAmount(tBuyOrderData.monPrice, false)
	self.tWindowMap["MainBuyContainer"]:ArrangeChildrenVert(0)

	self.tWindowMap["MainSellContainer"]:DestroyChildren()
	local wndMarketData = Apollo.LoadForm(self.xmlDoc, "MarketDataForm", self.tWindowMap["MainSellContainer"], self)
	wndMarketData:FindChild("MarketDataFormLabel"):SetText("Top Sell Order") -- TODO LOCALIZE (hardcoded string for translation)
	wndMarketData:FindChild("MarketDataFormLabel"):SetTextColor(ApolloColor.new("ffc2e57f"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetTextColor(ApolloColor.new("ffc2e57f"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetAmount(tSellOrderData.monPrice, false)
	self.tWindowMap["MainSellContainer"]:ArrangeChildrenVert(0)

	-- Allow refresh btn to be clicked again
	self.tWindowMap["RefreshMarketBtn"]:Enable(true)
	self.tWindowMap["MoreMarketStats"]:SetData(arMarketStats) -- For OnGenerateTooltipFullStats

	-- TODO Refactor the need of this for listings
	self.tWindowMap["OpenListingsBtn"]:SetText(String_GetWeaselString(Apollo.GetString("MarketplaceCommodity_OrderLimitCount"), #arOrders, kMaxPlayerCreddOrders))
	self.arOrders = arOrders

	self:RefreshBoundCredd()
	self:RefreshEscrow()
end

function MarketplaceCREDD:RefreshEscrow()
	-- Escrow
	local tFlattenedTable = {}
	for idx, tPendingAccountItem in pairs(AccountItemLib.GetPendingAccountSingleItems()) do
		table.insert(tFlattenedTable, tPendingAccountItem)
	end

	for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
		for idx2, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
			table.insert(tFlattenedTable, tPendingAccountItem)
		end
	end

	local nCreddEscrow = 0
	for idx, tPendingAccountItem in pairs(tFlattenedTable) do
		if tPendingAccountItem.accountCurrency and tPendingAccountItem.accountCurrency.accountCurrencyEnum == AccountItemLib.CodeEnumAccountCurrency.CREDD then
			nCreddEscrow = nCreddEscrow + 1
		end
	end
	self.tWindowMap["EscrowText"]:SetText(String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nCreddEscrow))
end

function MarketplaceCREDD:RefreshBoundCredd()
	-- TODO: Requires 2FA to Buy CREDD.
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() then
		local nNumBound = AccountItemLib.GetAccountCurrency(AccountItemLib.CodeEnumAccountCurrency.CREDD)
		self.tWindowMap["AccountBoundText"]:SetText(String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nNumBound))

		-- Enable/Disable Btns
		local nNowAmount = self.tWindowMap["ActNowPrice"]:GetAmount()
		self.tWindowMap["CreateSellNowBtn"]:Enable(nNowAmount > 0 and nNumBound > 0)
		self.tWindowMap["CreateBuyNowBtn"]:Enable(nNowAmount > 0 and nNumBound > 0)

		local nLaterAmount = self.tWindowMap["ActLaterPrice"]:GetAmount()
		self.tWindowMap["CreateSellOrderBtn"]:Enable(nLaterAmount > 0 and nNumBound > 0)
		self.tWindowMap["CreateBuyOrderBtn"]:Enable(nLaterAmount > 0 and nNumBound > 0)
	end
end

function MarketplaceCREDD:OnCashInputChanged(wndHandler, wndControl)
	wndHandler:SetText(math.max(0, tonumber(wndHandler:GetAmount() or 0)))
	self:RefreshBoundCredd() -- Will validate the buttons
end

function MarketplaceCREDD:OnGenerateTooltipFullStats(wndHandler, wndControl, eType, nX, nY) -- Same as from Commodity Exchange
	local tStats = wndHandler:GetData()
	if not tStats then
		return
	end

	local nLastCount = 0
	local wndFullStats = wndHandler:LoadTooltipForm("MarketplaceCREDD.xml", "FullStatsFrame", self)
	for nRowIdx = 1, 3 do
		local strBuy = ""
		local nBuyPrice = tStats.arBuyOrderPrices[nRowIdx].monPrice:GetAmount()
		if nBuyPrice > 0 then
			strBuy = self.wndMain:FindChild("HiddenCashWindow"):GetAMLDocForAmount(nBuyPrice, true, "ff2f94ac", "CRB_InterfaceSmall", 0) -- 2nd is skip zeroes, 5th is align left
		else
			strBuy = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">" .. Apollo.GetString("CRB_NoData") .. "</P>"
		end

		local strSell = ""
		local nSellPrice = tStats.arSellOrderPrices[nRowIdx].monPrice:GetAmount()
		if nSellPrice > 0 then
			strSell = self.wndMain:FindChild("HiddenCashWindow"):GetAMLDocForAmount(nSellPrice, true, "ff2f94ac", "CRB_InterfaceSmall", 0) -- 2nd is skip zeroes, 5th is align left
		else
			strSell = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">" .. Apollo.GetString("CRB_NoData") .. "</P>"
		end

		local wndRow = wndFullStats:FindChild("FullStatsGrid"):AddRow("")
		local strCount = String_GetWeaselString(Apollo.GetString("MarketplaceCommodity_Top"), tStats.arBuyOrderPrices[nRowIdx].nCount)
		wndFullStats:FindChild("FullStatsGrid"):SetCellDoc(wndRow, 1, "<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">" .. strCount .. "</P>")
		wndFullStats:FindChild("FullStatsGrid"):SetCellDoc(wndRow, 2, strBuy)
		wndFullStats:FindChild("FullStatsGrid"):SetCellDoc(wndRow, 3, strSell)
	end
end

function MarketplaceCREDD:OnMoreMarketStatsMouseExit(wndHandler, wndControl)
	wndHandler:SetTooltipDoc(nil)
end

-----------------------------------------------------------------------------------------------
-- Confirmation
-----------------------------------------------------------------------------------------------

function MarketplaceCREDD:OnConfirmationClose(wndHandler, wndControl)
	self.tWindowMap["ConfirmationBlocker"]:Show(false)
end

function MarketplaceCREDD:OnCreddTransactionBtn(wndHandler, wndControl, eMouseButton)
	wndHandler:SetFocus()
	local strWindowName = wndHandler:GetName()

	local strTitle = ""
	local strBigText = ""
	local strSubtitle = ""
	local nCurrAmount = 0
	if strWindowName == "CreateBuyNowBtn" then
		nCurrAmount = self.tWindowMap["ActNowPrice"]:GetAmount()
		strTitle = Apollo.GetString("MarketplaceCommodity_BuyNow")
		strBigText = Apollo.GetString("MarketplaceCredd_BuyLabel")
	elseif strWindowName == "CreateSellNowBtn" then
		nCurrAmount = self.tWindowMap["ActNowPrice"]:GetAmount()
		strTitle = Apollo.GetString("MarketplaceCommodity_SellNow")
		strBigText = Apollo.GetString("MarketplaceCredd_SellLabel")
	elseif strWindowName == "CreateBuyOrderBtn" then
		nCurrAmount = self.tWindowMap["ActLaterPrice"]:GetAmount()
		strTitle = Apollo.GetString("MarketplaceCredd_BuyOrder")
		strBigText = Apollo.GetString("MarketplaceCredd_BuyLabel")
		strSubtitle = Apollo.GetString("MarketplaceCredd_Duration48h")
	elseif strWindowName == "CreateSellOrderBtn" then
		nCurrAmount = self.tWindowMap["ActLaterPrice"]:GetAmount()
		strTitle = Apollo.GetString("MarketplaceCredd_SellOrder")
		strBigText = Apollo.GetString("MarketplaceCredd_SellLabel")
		strSubtitle = Apollo.GetString("MarketplaceCredd_Duration48h")
	end

	self.tWindowMap["ConfirmationBlocker"]:Show(true)
	self.tWindowMap["ConfirmationBlocker"]:SetData(strWindowName)
	self.tWindowMap["ConfirmationTitle"]:SetText(strTitle)
	self.tWindowMap["ConfirmationSubtitle"]:SetText(strSubtitle)
	self.tWindowMap["ConfirmationBigText"]:SetText(strBigText)
	self.tWindowMap["ConfirmationBigCash"]:SetAmount(nCurrAmount)
	self.tWindowMap["ConfirmationTaxText"]:Show(strSubtitle ~= "")
	self.tWindowMap["ConfirmationTaxCash"]:Show(strSubtitle ~= "")
	self.tWindowMap["ConfirmationTaxCash"]:SetAmount(nCurrAmount * 0.05) -- TODO! Replace with code enums
end

function MarketplaceCREDD:OnConfirmationYesBtn(wndHandler, wndControl)
	local nAmount = self.tWindowMap["ConfirmationBigCash"]:GetCurrency()
	local strWindowName = self.tWindowMap["ConfirmationBlocker"]:GetData()
	if strWindowName == "CreateBuyNowBtn" or strWindowName == "CreateBuyOrderBtn" then
		CREDDExchangeLib.BuyCREDD(nAmount, strWindowName == "CreateBuyNowBtn")
	else
		CREDDExchangeLib.SellCREDD(nAmount, strWindowName == "CreateSellNowBtn")
	end

	self.tWindowMap["ActNowPrice"]:SetAmount(0)
	self.tWindowMap["ActLaterPrice"]:SetAmount(0)
	self.tWindowMap["WaitingScreen"]:Show(true)
	self.tWindowMap["ConfirmationBlocker"]:Show(false)
	self.tWindowMap["RefreshAnimation"]:SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")

	CREDDExchangeLib.RequestExchangeInfo()
end

function MarketplaceCREDD:OnCREDDExchangeOperationResults(eOperationType, eResult)
	local bSuccess = eResult == 0 -- TODO Replace with enums
	local strFailMessage = ktResultErrorCodeStrings[eResult] or ""
	self.tWindowMap["WaitingScreen"]:Show(false)
	self.tWindowMap["PostResultNotification"]:Show(true)
	self.tWindowMap["PostResultNotificationLabel"]:SetText(bSuccess and "Success" or "Error")
	self.tWindowMap["PostResultNotificationCheck"]:SetSprite(bSuccess and "Icon_Windows_UI_CRB_Checkmark" or "LootCloseBox")
	self.tWindowMap["PostResultNotificationSubText"]:SetText(bSuccess and "Transaction Successful" or strFailMessage)
	Apollo.StartTimer("HidePostResultNotification")
	self:RefreshBoundCredd()
end

function MarketplaceCREDD:OnHidePostResultNotification() -- Both Timer and Mouse Click
	self.tWindowMap["PostResultNotification"]:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Listings
-----------------------------------------------------------------------------------------------

function MarketplaceCREDD:OnOpenMarketListingsBtn(wndHandler, wndControl, eMouseButton)
	self.wndOpenOrders:Show(not self.wndOpenOrders:IsShown())
	if self.wndOpenOrders:IsShown() then
		self.wndOpenOrders:ToFront()

		local wndScroll = self.wndOpenOrders:FindChild("ListingMainScroll")
		wndScroll:DestroyChildren()

		for idx, orderCurr in pairs(self.arOrders) do
			local bIsBuy = orderCurr:IsBuy()
			local wndMarketOrder = Apollo.LoadForm(self.xmlDoc, "MarketListingForm", wndScroll, self)
			wndMarketOrder:FindChild("CancelBtn"):SetData(orderCurr)
			wndMarketOrder:FindChild("BuyBG"):Show(bIsBuy)
			wndMarketOrder:FindChild("SellBG"):Show(not bIsBuy)
			wndMarketOrder:FindChild("Price"):SetAmount(orderCurr:GetPrice())
			wndMarketOrder:FindChild("ItemName"):SetText(bIsBuy and "Buy" or "Sell")
			wndMarketOrder:FindChild("TimeLeftText"):SetText(self:HelperFormatTimeString(orderCurr:GetExpirationTime()))
		end
		wndScroll:ArrangeChildrenVert(0)
	end
end

function MarketplaceCREDD:HelperFormatTimeString(oExpirationTime)
	local strResult = ""
	local nInSeconds = math.floor(math.abs(Time.SecondsElapsed(oExpirationTime))) -- CLuaTime object
	local nDays = math.floor(nInSeconds / 86400)
	local nHours = math.floor(nInSeconds / 3600)
	local nMins = math.floor(nInSeconds / 60 - (nHours * 60))

	if nDays > 0 then
		strResult = String_GetWeaselString(Apollo.GetString("MarketplaceListings_Hours"), nDays)
	elseif nHours > 0 then
		strResult = String_GetWeaselString(Apollo.GetString("MarketplaceListings_Hours"), nHours)
	elseif nMins > 0 then
		strResult = String_GetWeaselString(Apollo.GetString("MarketplaceListings_Minutes"), nMins)
	else
		strResult = Apollo.GetString("MarketplaceListings_LessThan1m")
	end
	return strResult
end

function MarketplaceCREDD:OnMarketOrderCancelBtn(wndHandler, wndControl, eMouseButton)
	CREDDExchangeLib.CancelOrder(wndControl:GetData())
end

function MarketplaceCREDD:OnCloseOrdersBtn(wndHandler, wndControl, eMouseButton)
	self.wndOpenOrders:Show(false)
end

local MarketplaceCREDDInst = MarketplaceCREDD:new()
MarketplaceCREDDInst:Init()
