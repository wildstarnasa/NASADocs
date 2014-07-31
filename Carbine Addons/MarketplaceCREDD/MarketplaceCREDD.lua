-----------------------------------------------------------------------------------------------
-- Client Lua Script for MarketplaceCREDD
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "AccountItemLib"
require "CREDDExchangeLib"
require "CREDDExchangeOrder"

local MarketplaceCREDD = {}

local ktResultErrorCodeStrings =
{
	[CREDDExchangeLib.CodeEnumAccountOperationResult.GenericFail] = "MarketplaceCredd_Error_GenericFail",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.DBError] = "MarketplaceCredd_Error_GenericFail",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidOffer] = "MarketplaceCredd_Error_InvalidOffer",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidPrice] = "MarketplaceCredd_Error_InvalidPrice",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NotEnoughCurrency] = "GenericError_Vendor_NotEnoughCash",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NeedTransaction] = "MarketplaceCredd_Error_GenericFail",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidAccountItem] = "MarketplaceAuction_InvalidItem",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidPendingItem] = "MarketplaceAuction_InvalidItem",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidInventoryItem] = "MarketplaceAuction_InvalidItem",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoConnection] = "MarketplaceCredd_Error_Connection",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoCharacter] = "MarketplaceCredd_Error_GenericFail",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.AlreadyClaimed] = "MarketplaceCredd_Error_AlreadyClaimed",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.MaxEntitlementCount] = "MarketplaceCredd_Error_MaxEntitlement",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoRegift] = "MarketplaceCredd_Error_CantGift",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoGifting] = "MarketplaceCredd_Error_CantGift",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidFriend] = "MarketplaceCredd_Error_InvalidFriend",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidCoupon] = "MarketplaceCredd_Error_InvalidCoupon",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.CannotReturn] = "MarketplaceCredd_Error_CantReturn",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.Prereq] = "MarketplaceCredd_Error_Prereq",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.CREDDExchangeNotLoaded] = "MarketplaceCredd_Error_Busy",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoCREDD] = "MarketplaceCredd_Error_NoCredd",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.NoMatchingOrder] = "MarketplaceCredd_Error_NoMatch",
	[CREDDExchangeLib.CodeEnumAccountOperationResult.InvalidCREDDOrder] = "MarketplaceCredd_Error_GenericFail",
}

local ktLogTypeStrings =
{
	[AccountItemLib.CodeEnumAccountOperation.SellCREDD] = "MarketplaceCredd_Log_SellOrderCreated",
	[AccountItemLib.CodeEnumAccountOperation.BuyCREDD] = "MarketplaceCredd_Log_BuyOrderCreated",
	[AccountItemLib.CodeEnumAccountOperation.SellCREDDComplete] = "MarketplaceCredd_Log_SellOrderComplete",
	[AccountItemLib.CodeEnumAccountOperation.BuyCREDDComplete] = "MarketplaceCredd_Log_BuyOrderComplete",
	[AccountItemLib.CodeEnumAccountOperation.CancelCREDDOrder] = "MarketplaceCredd_Log_CancelOrder",
}

local knMaxPlat = 9999999999 -- 9999 plat

function MarketplaceCREDD:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWindowMap = {}

    return o
end

function MarketplaceCREDD:Init()
    Apollo.RegisterAddon(self)
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
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 	"OnInterfaceMenuListHasLoaded", self)
end

function MarketplaceCREDD:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("MarketplaceCredd_Title"), {"ToggleCREDDExchangeWindow", "", "Icon_Windows32_UI_CRB_InterfaceMenu_Credd"})
end

function MarketplaceCREDD:Initialize()
	Apollo.RegisterEventHandler("CREDDOperationHistoryResults", "OnCREDDOperationHistoryResults", self)
	Apollo.RegisterEventHandler("CREDDExchangeWindowClose", 	"OnCREDDExchangeWindowClose", self)
	Apollo.RegisterEventHandler("CREDDExchangeInfoResults", 	"OnCREDDExchangeInfoResults", self)
	Apollo.RegisterEventHandler("AccountOperationResults", 		"OnCREDDExchangeOperationResults", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 		"RefreshBoundCredd", self)
	Apollo.RegisterEventHandler("AccountInventoryUpdate", 		"RefreshBoundCredd", self)
	Apollo.RegisterEventHandler("AccountInventoryUpdate", 		"RefreshEscrow", self)

	Apollo.RegisterTimerHandler("HidePostResultNotification",	"OnHidePostResultNotification", self)
	Apollo.CreateTimer("HidePostResultNotification", 2, false)
	Apollo.StopTimer("HidePostResultNotification")

	local wndMain = Apollo.LoadForm(self.xmlDoc, "MarketplaceCREDDForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = wndMain, strName = Apollo.GetString("MarketplaceCredd_Title")})
	Event_ShowTutorial(GameLib.CodeEnumTutorial.General_CREDD)

	self.tWindowMap =
	{
		["Main"]								=	wndMain,
		["HeaderBuyBtn"]						=	wndMain:FindChild("HeaderBuyBtn"),
		["HeaderBuyBtn"]						=	wndMain:FindChild("HeaderBuyBtn"),
		["HeaderLogBtn"]						=	wndMain:FindChild("HeaderLogBtn"),
		["HeaderSellBtn"]						=	wndMain:FindChild("HeaderSellBtn"),
		["HeaderSellCount"]						=	wndMain:FindChild("HeaderSellCount"),
		["RefreshMarketBtn"]					=	wndMain:FindChild("RefreshMarketBtn"),
		["RefreshAnimation"]					=	wndMain:FindChild("RefreshAnimation"),
		["WaitingScreen"]						=	wndMain:FindChild("CommonAlertMessages:WaitingScreen"),
		["LogMain"]								=	wndMain:FindChild("LogMain"),
		["LogScroll"]							=	wndMain:FindChild("LogScroll"),
		["ActNowPrice"]							=	wndMain:FindChild("ActNowPrice"),
		["ActLaterPrice"]						=	wndMain:FindChild("ActLaterPrice"),
		["ActNowNoCashIcon"]					=	wndMain:FindChild("ActNowNoCashIcon"),
		["ActLaterNoCashIcon"]					=	wndMain:FindChild("ActLaterNoCashIcon"),
		["CreateSellNowBtn"]					=	wndMain:FindChild("CreateSellNowBtn"),
		["CreateSellOrderBtn"]					=	wndMain:FindChild("CreateSellOrderBtn"),
		["CreateBuyNowBtn"]						=	wndMain:FindChild("CreateBuyNowBtn"),
		["CreateBuyOrderBtn"]					=	wndMain:FindChild("CreateBuyOrderBtn"),
		["OpenInventoryBtn"]					=	wndMain:FindChild("MetalRowFrame:OpenInventoryBtn"),
		["OpenListingsBtn"]						=	wndMain:FindChild("MetalRowFrame:OpenListingsBtn"),
		["MoreMarketStats"]						=	wndMain:FindChild("MoreMarketStats"),
		["MainBuyContainer"]					=	wndMain:FindChild("MainBuyContainer"),
		["MainSellContainer"]					=	wndMain:FindChild("MainSellContainer"),
		["ConfirmationBlocker"]					=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker"),
		["ConfirmationTitle"]					=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationTitle"),
		["ConfirmationSubtitle"]				=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationSubtitle"),
		["ConfirmationBigCash"]					=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationBigCash"),
		["ConfirmationBigText"]					=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationBigText"),
		["ConfirmationTaxText"]					=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationTaxText"),
		["ConfirmationTaxCash"]					=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationTaxCash"),
		["ConfirmationBaseText"]				=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationBaseText"),
		["ConfirmationBaseCash"]				=	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationBaseCash"),
		["PostResultNotification"]				=	wndMain:FindChild("CommonAlertMessages:PostResultNotification"),
		["PostResultNotificationCheck"]			=	wndMain:FindChild("CommonAlertMessages:PostResultNotification:PostResultNotificationCheck"),
		["PostResultNotificationLabel"]			=	wndMain:FindChild("CommonAlertMessages:PostResultNotification:PostResultNotificationLabel"),
		["PostResultNotificationSubText"]		=	wndMain:FindChild("CommonAlertMessages:PostResultNotification:PostResultNotificationSubText"),
		["ConfirmationYesBtn"]					= 	wndMain:FindChild("CommonAlertMessages:ConfirmationBlocker:ConfirmationYesBtn"),
	}

	self.tWindowMap["HeaderLogBtn"]:AttachWindow(self.tWindowMap["LogMain"])
	self.tWindowMap["HeaderBuyBtn"]:SetCheck(true)
	self.tWindowMap["ConfirmationBlocker"]:Show(false, true)
	self.tWindowMap["PostResultNotification"]:Show(false, true)
	self.tWindowMap["ActNowPrice"]:SetAmountLimit(knMaxPlat)
	self.tWindowMap["ActLaterPrice"]:SetAmountLimit(knMaxPlat)

	if self.locSavedWindowLoc then
		wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.arOrders = nil
end

function MarketplaceCREDD:OnToggleCREDDExchangeWindow()
	local wndMain = self.tWindowMap["Main"]
	if not wndMain or not wndMain:IsValid() then
		self:Initialize()
		wndMain = self.tWindowMap["Main"]
	end

	wndMain:Show(not wndMain:IsShown())
	if wndMain:IsShown() then
		wndMain:ToFront()
		CREDDExchangeLib.RequestExchangeInfo() -- Leads to OnCREDDExchangeInfoResults
	end
end

function MarketplaceCREDD:OnClose(wndHandler, wndControl, eMouseButton)
	if wndHandler == wndControl then
		if self.tWindowMap["Main"] ~= nil and self.tWindowMap["Main"]:IsValid() then
			self.tWindowMap["Main"]:Destroy()
		end
		self.tWindowMap = {}
		Event_CancelCREDDExchange()
	end
end

function MarketplaceCREDD:OnOpenListingsBtn(wndHandler, wndControl)
	Event_FireGenericEvent("InterfaceMenu_ToggleMarketplaceListings")
end

function MarketplaceCREDD:OnOpenInventoryBtn(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_ToggleAccountInventory")
end

-----------------------------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------------------------

function MarketplaceCREDD:OnHeaderLogCheck(wndHandler, wndControl) -- Same Radio Group as OnHeaderTabCheck
	self.tWindowMap["ConfirmationBlocker"]:Show(false)
	CREDDExchangeLib.GetCREDDHistory() -- Leads to OnCREDDExchangeInfoResults
end

function MarketplaceCREDD:OnHeaderTabCheck(wndHandler, wndControl)
	self.tWindowMap["ConfirmationBlocker"]:Show(false)
	CREDDExchangeLib.RequestExchangeInfo() -- Leads to OnCREDDExchangeInfoResults
end

function MarketplaceCREDD:OnRefreshMarketBtn(wndHandler, wndControl, eMouseButton)
	self.tWindowMap["RefreshAnimation"]:SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self.tWindowMap["RefreshMarketBtn"]:Enable(false)
	CREDDExchangeLib.RequestExchangeInfo() -- Leads to OnCREDDExchangeInfoResults
end

function MarketplaceCREDD:OnCREDDExchangeInfoResults(arMarketStats, arOrders) -- Main Redraw
	local wndMain = self.tWindowMap["Main"]
	if not wndMain or not wndMain:IsValid() or not wndMain:IsVisible() then
		return
	end

	local tBuyOrderData = arMarketStats.arBuyOrderPrices[1]
	local tSellOrderData = arMarketStats.arSellOrderPrices[1]
	local bBuyTabChecked = self.tWindowMap["HeaderBuyBtn"]:IsChecked()
	self.tWindowMap["WaitingScreen"]:Show(false)
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
	wndMarketData:FindChild("MarketDataFormLabel"):SetText(Apollo.GetString("MarketplaceCredd_TopBuyOrder"))
	wndMarketData:FindChild("MarketDataFormLabel"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetAmount(tBuyOrderData.monPrice, false)
	self.tWindowMap["MainBuyContainer"]:ArrangeChildrenVert(0)

	self.tWindowMap["MainSellContainer"]:DestroyChildren()
	local wndMarketData = Apollo.LoadForm(self.xmlDoc, "MarketDataForm", self.tWindowMap["MainSellContainer"], self)
	wndMarketData:FindChild("MarketDataFormLabel"):SetText(Apollo.GetString("MarketplaceCredd_TopSellOrder"))
	wndMarketData:FindChild("MarketDataFormLabel"):SetTextColor(ApolloColor.new("ffc2e57f"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetTextColor(ApolloColor.new("ffc2e57f"))
	wndMarketData:FindChild("MarketDataFormPrice"):SetAmount(tSellOrderData.monPrice, false)
	self.tWindowMap["MainSellContainer"]:ArrangeChildrenVert(0)

	-- Allow refresh btn to be clicked again
	self.tWindowMap["RefreshMarketBtn"]:Enable(true)
	self.tWindowMap["MoreMarketStats"]:SetData(arMarketStats) -- For OnGenerateTooltipFullStats

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

	local strText = nCreddEscrow > 0 and String_GetWeaselString(Apollo.GetString("MarketplaceCredd_AccountInventoryCount"), nCreddEscrow) or Apollo.GetString("AccountInv_TitleText")
	local strTooltip = nCreddEscrow > 0 and Apollo.GetString("MarketplaceCredd_HaveInventoryTooltip") or Apollo.GetString("MarketplaceCredd_OpenInventoryTooltip")
	self.tWindowMap["OpenInventoryBtn"]:SetText(strText)
	self.tWindowMap["OpenInventoryBtn"]:SetTooltip(strTooltip)
end

function MarketplaceCREDD:RefreshBoundCredd()
	local wndMain = self.tWindowMap["Main"]
	if wndMain and wndMain:IsValid() and wndMain:IsVisible() then
		local nPlayerCash = GameLib.GetPlayerCurrency():GetAmount()
		local bBuyTabChecked = self.tWindowMap["HeaderBuyBtn"]:IsChecked()
		local nNumBound = AccountItemLib.GetAccountCurrency(AccountItemLib.CodeEnumAccountCurrency.CREDD)
		self.tWindowMap["HeaderSellCount"]:Show(nNumBound > 0)
		self.tWindowMap["HeaderSellCount"]:SetText(nNumBound > 0 and nNumBound or "")
		self.tWindowMap["HeaderSellCount"]:SetTooltip(String_GetWeaselString(Apollo.GetString("MarketplaceCredd_SellNumAvailable"), nNumBound))

		-- Enable/Disable Btns
		local nNowAmount = self.tWindowMap["ActNowPrice"]:GetAmount()
		self.tWindowMap["ActNowNoCashIcon"]:Show(bBuyTabChecked and nNowAmount > nPlayerCash)
		self.tWindowMap["CreateBuyNowBtn"]:Enable(bBuyTabChecked and nNowAmount <= nPlayerCash and nNowAmount > 0)
		self.tWindowMap["CreateSellNowBtn"]:Enable(nNowAmount > 0 and nNumBound > 0)

		local nLaterAmount = self.tWindowMap["ActLaterPrice"]:GetAmount()
		self.tWindowMap["ActLaterNoCashIcon"]:Show(bBuyTabChecked and nLaterAmount > nPlayerCash)
		self.tWindowMap["CreateBuyOrderBtn"]:Enable(bBuyTabChecked and nLaterAmount <= nPlayerCash and nLaterAmount > 0)
		self.tWindowMap["CreateSellOrderBtn"]:Enable(nLaterAmount > 0 and nNumBound > 0)
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
			strBuy = self.tWindowMap["Main"]:FindChild("HiddenCashWindow"):GetAMLDocForAmount(nBuyPrice, true, "UI_TextHoloBody", "CRB_InterfaceSmall", 0) -- 2nd is skip zeroes, 5th is align left
		else
			strBuy = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">" .. Apollo.GetString("CRB_NoData") .. "</P>"
		end

		local strSell = ""
		local nSellPrice = tStats.arSellOrderPrices[nRowIdx].monPrice:GetAmount()
		if nSellPrice > 0 then
			strSell = self.tWindowMap["Main"]:FindChild("HiddenCashWindow"):GetAMLDocForAmount(nSellPrice, true, "ffc2e57f", "CRB_InterfaceSmall", 0) -- 2nd is skip zeroes, 5th is align left
		else
			strSell = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffc2e57f\">" .. Apollo.GetString("CRB_NoData") .. "</P>"
		end

		local wndRow = wndFullStats:FindChild("FullStatsGrid"):AddRow("")
		local strCount = String_GetWeaselString(Apollo.GetString("MarketplaceCommodity_Top"), tStats.arBuyOrderPrices[nRowIdx].nCount)
		wndFullStats:FindChild("FullStatsGrid"):SetCellDoc(wndRow, 1, "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloTitle\">" .. strCount .. "</P>")
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

	local wndCurrAmount = nil
	local bBuy = false
	local bNow = false
	if strWindowName == "CreateBuyNowBtn" then
		wndCurrAmount = self.tWindowMap["ActNowPrice"]
		strTitle = Apollo.GetString("MarketplaceCommodity_BuyNow")
		strBigText = Apollo.GetString("MarketplaceCredd_FinalLabel")
		strSubtitle = ""
		bBuy = true
		bNow = true
	elseif strWindowName == "CreateSellNowBtn" then
		wndCurrAmount = self.tWindowMap["ActNowPrice"]
		strTitle = Apollo.GetString("MarketplaceCommodity_SellNow")
		strBigText = Apollo.GetString("MarketplaceCredd_ProfitLabel")
		strSubtitle = Apollo.GetString("MarketplaceCredd_ConfirmationSubtitle")
		bNow = true
	elseif strWindowName == "CreateBuyOrderBtn" then
		wndCurrAmount = self.tWindowMap["ActLaterPrice"]
		strTitle = Apollo.GetString("MarketplaceCredd_BuyOrder")
		strBigText = Apollo.GetString("MarketplaceCredd_FinalLabel")
		strSubtitle = ""
		bBuy = true
	elseif strWindowName == "CreateSellOrderBtn" then
		wndCurrAmount = self.tWindowMap["ActLaterPrice"]
		strTitle = Apollo.GetString("MarketplaceCredd_SellOrder")
		strBigText = Apollo.GetString("MarketplaceCredd_ProfitLabel")
		strSubtitle = Apollo.GetString("MarketplaceCredd_ConfirmationSubtitle")
	end

	self.tWindowMap["ConfirmationBlocker"]:Show(true)
	self.tWindowMap["ConfirmationBlocker"]:SetData(strWindowName)
	self.tWindowMap["ConfirmationTitle"]:SetText(strTitle)
	self.tWindowMap["ConfirmationSubtitle"]:SetText(strSubtitle)

	local nCurrAmount = wndCurrAmount:GetAmount()
	self.tWindowMap["ConfirmationTaxText"]:Show(bBuy)
	self.tWindowMap["ConfirmationTaxCash"]:Show(bBuy)
	self.tWindowMap["ConfirmationBaseText"]:Show(bBuy)
	self.tWindowMap["ConfirmationBaseCash"]:Show(bBuy)

	self.tWindowMap["ConfirmationTaxCash"]:SetAmount(nCurrAmount * 0.05)
	self.tWindowMap["ConfirmationBaseCash"]:SetAmount(nCurrAmount)
	self.tWindowMap["ConfirmationBigCash"]:SetAmount(bBuy and (nCurrAmount * 1.05) or nCurrAmount)
	
	self.tWindowMap["ConfirmationBigText"]:SetText(strBigText)
	self.tWindowMap["ConfirmationYesBtn"]:SetActionData(GameLib.CodeEnumConfirmButtonType.CREDDExchangeSubmit, bBuy, wndCurrAmount:GetCurrency(), bNow)
end

function MarketplaceCREDD:OnCREDDExchangeOrderSubmitted(wndHandler, wndControl)
	self.tWindowMap["ActNowPrice"]:SetAmount(0)
	self.tWindowMap["ActLaterPrice"]:SetAmount(0)
	self.tWindowMap["WaitingScreen"]:Show(true)
	self.tWindowMap["ConfirmationBlocker"]:Show(false)
	self.tWindowMap["RefreshAnimation"]:SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")

	CREDDExchangeLib.RequestExchangeInfo()
end

function MarketplaceCREDD:OnCREDDExchangeOperationResults(eOperationType, eResult)
	if self.tWindowMap["WaitingScreen"] then
		local bSuccess = eResult == CREDDExchangeLib.CodeEnumAccountOperationResult.Ok
		self.tWindowMap["WaitingScreen"]:Show(false)
		self.tWindowMap["PostResultNotification"]:Show(true)
		self.tWindowMap["PostResultNotificationLabel"]:SetText(bSuccess and Apollo.GetString("CRB_Success") or Apollo.GetString("CRB_Error"))
		self.tWindowMap["PostResultNotificationCheck"]:SetSprite(bSuccess and "Icon_Windows_UI_CRB_Checkmark" or "LootCloseBox")
		self.tWindowMap["PostResultNotificationSubText"]:SetText(bSuccess and Apollo.GetString("MarketplaceCredd_TransactionSuccess") or Apollo.GetString(ktResultErrorCodeStrings[eResult]))
	end
	
	Apollo.StartTimer("HidePostResultNotification")
	self:RefreshBoundCredd()
end

function MarketplaceCREDD:OnHidePostResultNotification() -- Both Timer and Mouse Click
	if self.tWindowMap["PostResultNotification"] then
		self.tWindowMap["PostResultNotification"]:Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Log
-----------------------------------------------------------------------------------------------

function MarketplaceCREDD:OnCREDDOperationHistoryResults(tHistory)
	if not self.tWindowMap["LogScroll"] or not self.tWindowMap["LogScroll"]:IsValid() or not self.tWindowMap["LogScroll"]:IsVisible() then
		return
	end

	-- Sort table
	table.sort(tHistory, function(a,b) return a.nLogAge < b.nLogAge end)

	self.tWindowMap["LogScroll"]:DestroyChildren()
	for idx, tEntry in pairs(tHistory) do
		local wndEntry = Apollo.LoadForm(self.xmlDoc, "LogEntryBasicForm", self.tWindowMap["LogScroll"], self)
		wndEntry:FindChild("LogName"):SetText(Apollo.GetString(ktLogTypeStrings[tEntry.eOperation] or ""))
		wndEntry:FindChild("LogTimeStamp"):SetText(self:HelperLogConvertToTimeString(tEntry.nLogAge))

		if tEntry.monAmount and tEntry.monAmount:GetAmount() > 0 then
			local nLeft, nTop, nRight, nBottom = wndEntry:GetAnchorOffsets()
			wndEntry:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 50)
			wndEntry:FindChild("LogCashWindow"):Show(true)
			wndEntry:FindChild("LogCashWindow"):SetAmount(tEntry.monAmount)
		end
	end

	if #self.tWindowMap["LogScroll"]:GetChildren() == 0 then
		local wndEntry = Apollo.LoadForm(self.xmlDoc, "LogEntryBasicForm", self.tWindowMap["LogScroll"], self)
		wndEntry:FindChild("LogName"):SetText(Apollo.GetString("MarketplaceCredd_NoLogEntries"))
		wndEntry:FindChild("LogTimeStamp"):SetText("")
	end

	self.tWindowMap["LogScroll"]:ArrangeChildrenVert(0)
end

function MarketplaceCREDD:HelperLogConvertToTimeString(nDays)
	local tTimeData =
	{
		["name"]	= "",
		["count"]	= nil,
	}

	local nYears = math.floor(nDays / 365)
	local nMonths = math.floor(nDays / 30)
	local nWeeks = math.floor(nDays / 7)
	local nDaysRounded = math.floor(nDays / 1)
	local fHours = nDays * 24
	local nHoursRounded = math.floor(fHours)
	local nMinutes = math.floor(fHours * 60)

	if nYears > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Year")
		tTimeData["count"] = nYears
	elseif nMonths > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Month")
		tTimeData["count"] = nMonths
	elseif nWeeks > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Week")
		tTimeData["count"] = nWeeks
	elseif nDaysRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Day")
		tTimeData["count"] = nDaysRounded
	elseif nHoursRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Hour")
		tTimeData["count"] = nHoursRounded
	elseif nMinutes > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = nMinutes
	else
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = 1
	end

	return String_GetWeaselString(Apollo.GetString("AccountInventory_LogTime"), tTimeData)
end

local MarketplaceCREDDInst = MarketplaceCREDD:new()
MarketplaceCREDDInst:Init()
