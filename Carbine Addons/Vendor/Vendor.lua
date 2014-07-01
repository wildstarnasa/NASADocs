-----------------------------------------------------------------------------------------------
-- Client Lua Script
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "string"
require "math"
require "Sound"
require "Item"
require "Money"
require "GameLib"

local Vendor = {}

local kstrTabBuy     	= "VendorTab0"
local kstrTabSell    	= "VendorTab1"
local kstrTabBuyback 	= "VendorTab2"
local kstrTabRepair  	= "VendorTab3"
local knMaxGuildLimit 	= 2000000000 -- 2000 plat

local knHeaderContainerMinHeight = 8

local ktVendorRespondEvent =
{
	-- Stackable items send the StackSplit reason when they are being sold
	[Item.CodeEnumItemUpdateReason.StackSplit]	= Apollo.GetString("Vendor_Bought"),
	[Item.CodeEnumItemUpdateReason.Vendor] 		= Apollo.GetString("Vendor_Bought"),
	[Item.CodeEnumItemUpdateReason.Buyback] 	= Apollo.GetString("Vendor_BoughtBack"),
}

function Vendor:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	o.tFactoryCache = {}
	o.idOpenedGroup = nil
	
	return o
end

function Vendor:Init()
	Apollo.RegisterAddon(self, false, "", {"Util"})
end

function Vendor:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Vendor.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Vendor:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementReady", 		"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("UpdateInventory", 				"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("VendorItemsUpdated", 			"OnVendorItemsUpdated", self)
	Apollo.RegisterEventHandler("BuybackItemsUpdated", 			"OnBuybackItemsUpdated", self)
	Apollo.RegisterEventHandler("CloseVendorWindow", 			"OnCloseVendorWindow", self)
	Apollo.RegisterEventHandler("InvokeVendorWindow", 			"OnInvokeVendorWindow", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 		"OnPlayerCurrencyChanged", self)

	-- Return events for buy/sell/repair
	Apollo.RegisterEventHandler("GenericError", 				"OnGenericError", self)
	Apollo.RegisterEventHandler("ItemDurabilityUpdate", 		"OnItemDurabilityUpdate", self)
	Apollo.RegisterEventHandler("ItemAdded", 					"OnItemAdded", self)
	Apollo.RegisterEventHandler("ItemRemoved", 					"OnItemRemoved", self)

	-- Guild events
	Apollo.RegisterEventHandler("GuildChange",					"OnGuildChange", self)
	Apollo.RegisterEventHandler("GuildBankWithdraw",			"OnGuildChange", self)
	Apollo.RegisterEventHandler("GuildWarCoinsChanged",			"OnPlayerCurrencyChanged", self)

    Apollo.RegisterTimerHandler("AlertMessageTimer", 			"OnAlertMessageTimer", self)
	Apollo.CreateTimer("AlertMessageTimer", 4.0, false)
	Apollo.StopTimer("AlertMessageTimer")

	self.wndVendor = Apollo.LoadForm(self.xmlDoc, "VendorWindow", nil, self)
	self.wndVendor:FindChild(kstrTabBuy):SetCheck(true)
	self.wndVendor:FindChild("GuildRepairBtn"):Enable(false)
	self.wndVendor:Show(false, true)

	self.wndItemContainer = self.wndVendor:FindChild("LeftSideContainer:ItemsList")
	self.wndBagWindow = self.wndVendor:FindChild("BagWindow")

	self.tAltCurrency = nil
	self.tDefaultSelectedItem = nil

	self.tVendorItems = {}
	self.tItemWndList = {}
	self.tBuybackItems = {}
	self.tRepairableItems = {}
end

function Vendor:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndVendor, strName = Apollo.GetString("CRB_Vendor")})
end

-----------------------------------------------------------------------------------------------

function Vendor:OnInvokeVendorWindow(unitArg) -- REFACTOR
	Event_FireGenericEvent("VendorInvokedWindow")

	local bIsRepairVendor = IsRepairVendor(unitArg)
	self.wndVendor:Show(true)
	self.wndVendor:SetData(unitArg)
	self.wndVendor:FindChild("VendorName"):SetText(unitArg:GetName())
	self.wndVendor:FindChild("VendorPortrait"):SetCostume(unitArg)
	self.wndVendor:FindChild("VendorPortrait"):SetModelSequence(150)

	self.wndVendor:FindChild(kstrTabBuy):SetCheck(true)
	self.wndVendor:FindChild(kstrTabSell):SetCheck(false)
	self.wndVendor:FindChild(kstrTabBuyback):SetCheck(false)
	self.wndVendor:FindChild(kstrTabRepair):SetCheck(false)
	self.wndVendor:FindChild(kstrTabRepair):Enable(bIsRepairVendor)

	if bIsRepairVendor then
		self:RefreshRepairTab()
	end

	self:RedrawFully()
end

function Vendor:OnUpdateInventory()
	self:Redraw()
end

function Vendor:OnVendorItemsUpdated()
	self:Redraw()
end

function Vendor:OnBuybackItemsUpdated()
	self:RefreshBuyBackTab()
	self:Redraw()
end

function Vendor:OnPlayerCurrencyChanged()
	self.wndVendor:FindChild("Cash"):SetAmount(GameLib.GetPlayerCurrency(), false)
	if self.wndVendor:FindChild("AltCurrency"):IsShown() and self.tAltCurrency then
		self.wndVendor:FindChild("AltCurrency"):SetAmount(GameLib.GetPlayerCurrency(self.tAltCurrency.eMoneyType, self.tAltCurrency.eAltType), false)
	end

	self:Redraw()
end

---------------------------------------------------------------------------------------------------
-- Main Update Method
---------------------------------------------------------------------------------------------------

function Vendor:RedrawFully()
	if not self.wndVendor or not self.wndVendor:IsShown() then
		return
	end

	local nVScrollPos = self.wndItemContainer:GetVScrollPos()
	self.wndItemContainer:DestroyChildren()

	self:DisableBuyButton()

	self:Redraw()
	self:RefreshBuyBackTab()

	self.wndItemContainer:SetVScrollPos(nVScrollPos)
	self:OnPlayerCurrencyChanged()

	if not self.tDefaultSelectedItem then
		return
	end

	for key, wndHeader in pairs(self.wndItemContainer:GetChildren()) do
		for key2, wndItem in pairs(wndHeader:FindChild("VendorHeaderContainer"):GetChildren()) do
			local tData = wndItem:GetData()
			if tData ~= nil and tData.idUnique == self.tDefaultSelectedItem.idUnique then -- GOTCHA: We can't == compare item objects, but we can compare .id
				wndItem:FindChild("VendorListItemBtn"):SetCheck(true)
				self:FocusOnVendorListItem(wndItem:GetData())
				break
			end
		end
	end
end

function Vendor:Redraw()
	if not self.wndVendor or not self.wndVendor:IsShown() then
		return
	end

	local tUpdateInfo = nil
	if self.wndVendor:FindChild(kstrTabBuy):IsChecked() then
		tUpdateInfo = self:UpdateVendorItems()
	elseif self.wndVendor:FindChild(kstrTabSell):IsChecked() then
		tUpdateInfo = self:UpdateSellItems()
	elseif self.wndVendor:FindChild(kstrTabBuyback):IsChecked() then
		tUpdateInfo = self:UpdateBuybackItems()
	elseif self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
		tUpdateInfo = self:UpdateRepairableItems()
	end
	
	--[[local tInvItems = GameLib.GetPlayerUnit():GetInventoryItems()
	local jCount = 0
		for _, val in pairs(tInvItems) do
		if val.itemInBag:GetItemCategory() == 94 then	--Junk ID
			jCount = jCount + 1
		end
	end
	
	self.wndVendor:FindChild("SellJunkBtn"):SetText("Sell Junk (" .. jCount ..")")
		
	if self.wndVendor:FindChild(kstrTabSell):IsChecked() and jCount > 0 then
		self.wndVendor:FindChild("SellJunkBtn"):Show(true)
		self.wndVendor:FindChild("SellJunkBtn"):Enable(true)
	elseif self.wndVendor:FindChild(kstrTabSell):IsChecked() and jCount <= 0 then
		self.wndVendor:FindChild("SellJunkBtn"):Show(true)	
		self.wndVendor:FindChild("SellJunkBtn"):Enable(false)		
	else
		self.wndVendor:FindChild("SellJunkBtn"):Show(false)
	end]]--
	
	local bFullRedraw = tUpdateInfo and tUpdateInfo.tUpdatedItems and (tUpdateInfo.bChanged or tUpdateInfo.bItemCountChanged or tUpdateInfo.bGroupCountChanged)
	if bFullRedraw then
		local nVScrollPos = self.wndItemContainer:GetVScrollPos()
		self.wndItemContainer:DestroyChildren()
		self:DisableBuyButton()
		
		self:DrawHeaderAndItems(tUpdateInfo.tUpdatedItems, tUpdateInfo.bChanged)
	
		self.wndItemContainer:SetVScrollPos(nVScrollPos)
	else
		self:DrawHeaderAndItems(tUpdateInfo.tUpdatedItems, tUpdateInfo.bChanged)
	end

	self:OnGuildChange() -- Also check Guild Repair
end

function Vendor:DrawHeaderAndItems(tVendorList, bChanged)
	for idHeader, tHeaderValue in pairs(tVendorList) do
		local wndCurr = self:FactoryCacheProduce(self.wndItemContainer, "VendorHeaderItem", "H"..idHeader)
		wndCurr:SetData(tHeaderValue)
		if self.idOpenedGroup == nil then
			self.idOpenedGroup = tHeaderValue.idGroup
		end
		wndCurr:FindChild("VendorHeaderBtn"):SetCheck(self.idOpenedGroup == tHeaderValue.idGroup)
		wndCurr:FindChild("VendorHeaderName"):SetText(tHeaderValue.strName)

		if wndCurr:FindChild("VendorHeaderBtn"):IsChecked() then
			self:DrawListItems(wndCurr:FindChild("VendorHeaderContainer"), tHeaderValue.tItems)
		end
		self:SizeHeader(wndCurr)
	end

	self.wndItemContainer:ArrangeChildrenVert(0)

	-- TODO: Advanced item info in frame
	-- TODO: Destroy advanced item info if nothing is selected
end

function Vendor:SizeHeader(wndHeader)
	local wndVendorHeaderContainer = wndHeader:FindChild("VendorHeaderContainer")

	-- Children, if checked
	local nOnGoingHeight = math.max(knHeaderContainerMinHeight, wndVendorHeaderContainer:ArrangeChildrenVert(0))

	-- Resize
	local nLeft, nTop, nRight, nBottom = wndVendorHeaderContainer:GetAnchorOffsets()
	wndVendorHeaderContainer:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOnGoingHeight)
	local nLeft2, nTop2, nRight2, nBottom2 = wndHeader:GetAnchorOffsets()
	wndHeader:SetAnchorOffsets(nLeft2, nTop2, nRight2, nTop2 + nOnGoingHeight + 57) -- Padding to the container and below it -- TODO Hardcoded formatting
end

function Vendor:DrawListItems(wndParent, tItems)
	for key, tCurrItem in pairs(tItems) do
		if not tCurrItem.bFutureStock then
			local wndCurr = self:FactoryCacheProduce(wndParent, "VendorListItem", "I"..tCurrItem.idUnique)
			wndCurr:FindChild("VendorListItemBtn"):SetData(tCurrItem)
			wndCurr:FindChild("VendorListItemTitle"):SetText(tCurrItem.strName)
			wndCurr:FindChild("VendorListItemCantUse"):Show(self:HelperPrereqFailed(tCurrItem))

			if tCurrItem.eType == Item.CodeEnumLootItemType.StaticItem then
				wndCurr:FindChild("VendorListItemIcon"):GetWindowSubclass():SetItem(tCurrItem.itemData)
			else
				wndCurr:FindChild("VendorListItemIcon"):SetSprite(tCurrItem.strIcon)
			end

			local monPrice = nil
			if tCurrItem.itemData then
				local itemData = tCurrItem.itemData
				if self.wndVendor:FindChild(kstrTabSell):IsChecked() or self.wndVendor:FindChild(kstrTabBuyback):IsChecked()then
					monPrice = itemData:GetSellPrice():Multiply(tCurrItem.nStackSize)
				elseif self.wndVendor:FindChild(kstrTabBuy):IsChecked() then
					monPrice = itemData:GetBuyPrice():Multiply(tCurrItem.nStackSize)
				elseif self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
					monPrice = Money.new(Money.CodeEnumCurrencyType.Credits)
					monPrice:SetAmount(itemData:GetRepairCost())
				end
	    	elseif tCurrItem.splData then
				monPrice = Money.new(tCurrItem.tPriceInfo.eCurrencyType1)
				monPrice:SetAmount(tCurrItem.tPriceInfo.nAmount1)
				monPrice:Multiply(tCurrItem.nStackSize)
				if tCurrItem.tPriceInfo.eAltType1 then
					monPrice:SetAltType(tCurrItem.tPriceInfo.eAltType1)
				end
			end

			if tCurrItem.nStackSize > 1 then
				wndCurr:FindChild("VendorListItemIcon"):SetText(tCurrItem.nStackSize)
			elseif tCurrItem.nStockCount > 0 and self.wndVendor:FindChild(kstrTabBuy):IsChecked() then
				wndCurr:FindChild("VendorListItemIcon"):SetText(String_GetWeaselString(Apollo.GetString("Vendor_LimitedItemCount"), tCurrItem.nStockCount))
			end
			
			-- Costs
			if monPrice and monPrice:GetMoneyType() ~= Money.CodeEnumCurrencyType.Credits then
				self.tAltCurrency = {}
				self.tAltCurrency.eMoneyType = monPrice:GetMoneyType()
				self.tAltCurrency.eAltType = monPrice:GetAltType()
			end

			local wndCash = wndCurr:FindChild("VendorListItemCashWindow")
			if monPrice then
				wndCash:SetAmount(monPrice, true)
			else
				wndCash:SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
				wndCash:SetAmount(0, true)
			end

			if self:HelperRecipeAlreadyKnown(tCurrItem) then
				wndCurr:FindChild("VendorListItemTitle"):SetText(String_GetWeaselString(Apollo.GetString("Vendor_KnownRecipe"), wndCurr:FindChild("VendorListItemTitle"):GetText()))
			end

			local bTextColorRed = self:HelperIsTooExpensive(tCurrItem) or self:HelperPrereqBuyFailed(tCurrItem)
			wndCurr:FindChild("VendorListItemTitle"):SetTextColor(bTextColorRed and "UI_WindowTextRed" or "UI_TextHoloBody")
			wndCurr:FindChild("VendorListItemCashWindow"):SetTextColor(bTextColorRed and "UI_WindowTextRed" or "white")
		end
	end

	-- After iterating
	if self.tAltCurrency then
		self.wndVendor:FindChild("AltCurrency"):SetAmount(GameLib.GetPlayerCurrency(self.tAltCurrency.eMoneyType, self.tAltCurrency.eAltType))
		self.wndVendor:FindChild("AltCurrency"):Show(true, true)
		self.wndVendor:FindChild("YourCashLabel"):Show(false)
		self.wndVendor:FindChild("CashBagBG"):ArrangeChildrenVert(0)
	else
		self.wndVendor:FindChild("AltCurrency"):Show(false)
		self.wndVendor:FindChild("YourCashLabel"):Show(true)
		self.wndVendor:FindChild("CashBagBG"):ArrangeChildrenVert(0)
	end

	local nHeight = wndParent:ArrangeChildrenVert(0)
	return nHeight
end

function Vendor:EnableBuyButton(tData)
	self:HideRestockingFee()
	self.wndVendor:FindChild("Buy"):Enable(true)
	self.wndVendor:FindChild("Buy"):SetData(tData)
end

function Vendor:DisableBuyButton(bDontClear)
	self:HideRestockingFee()

	if self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
		local nRepairAllCost = GameLib.GetRepairAllCost()
		self.wndVendor:FindChild("Buy"):Enable(nRepairAllCost > 0 and nRepairAllCost <= GameLib.GetPlayerCurrency():GetAmount())
	elseif bDontClear or self.tDefaultSelectedItem == nil then
		self.wndVendor:FindChild("Buy"):Enable(false)
	end

	if not bDontClear then
		self.wndVendor:FindChild("Buy"):SetData(nil)
	end

	self:SetBuyButtonText()
end

function Vendor:OnVendorListItemCheck(wndHandler, wndControl) -- TODO REFACTOR
    if not wndHandler or not wndHandler:GetData() then
		return
	end

	local tItemData = wndHandler:GetData()
	self.tDefaultSelectedItem = nil -- Erase the default selection now
	self:FocusOnVendorListItem(tItemData)
end

function Vendor:OnVendorListItemUncheck(wndHandler, wndControl) -- TODO REFACTOR
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	self.tDefaultSelectedItem = nil -- Erase the default selection now
	self:DisableBuyButton()
	self:OnGuildChange()
end

function Vendor:OnVendorListItemMouseDown(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if (eMouseButton == GameLib.CodeEnumInputMouse.Left and bDoubleClick) or eMouseButton == GameLib.CodeEnumInputMouse.Right then -- left double click or right click
	    if not Apollo.IsControlKeyDown() then
   			self:OnVendorListItemCheck(wndHandler, wndControl)
			if self.wndVendor:FindChild("Buy"):IsEnabled() then
				self:OnBuy(self.wndVendor:FindChild("Buy"), self.wndVendor:FindChild("Buy")) -- hackish, simulate a buy button click
				self.tDefaultSelectedItem = nil
			end
		else
		    -- item preview
		    -- Check if this item is a decor item
		    if not wndHandler or not wndHandler:GetData() then return end
		    local tItemPreview = wndHandler:GetData()
		    if tItemPreview and tItemPreview.itemData then
		        local itemCurr = tItemPreview.itemData
		        if itemCurr:GetHousingDecorInfoId() ~= nil and itemCurr:GetHousingDecorInfoId() ~= 0 then
					Event_FireGenericEvent("DecorPreviewOpen", itemCurr:GetHousingDecorInfoId())
				else
					Event_FireGenericEvent("ShowItemInDressingRoom", itemCurr)
				end
			end
		end
		return true
	end
end

function Vendor:SelectNextItemInLine(tItem)
	--[[ No longer desired functionality, the entire stack sells on the click
	-- If there's more in the stack, use the same item still
	if tItem.stackSize > 1 then
		self.tDefaultSelectedItem = tItem
		return
	end
	]]--

	-- Look for the item's window in the list
	local wndPrev = nil
	for key, wndHeader in pairs(self.wndItemContainer:GetChildren()) do
		wndPrev = wndHeader:FindChild("VendorHeaderContainer"):FindChildByUserData(tItem)
		if wndPrev then
			break
		end
	end

	if not wndPrev then
		return
	end

	-- Now that we found the window, find the next sibling in the list
	local nNextItem = -1
	for nCurr, wndCurr in pairs(wndPrev:GetParent():GetChildren()) do -- TODO HACKish, though GetParent():GetChildren() might be safe
		if nNextItem == nCurr then
			self.tDefaultSelectedItem = wndCurr:GetData() -- We'll let the redraw re-select the item for us
		elseif wndCurr == wndPrev then
			nNextItem = nCurr + 1
		end
	end
end

function Vendor:FocusOnVendorListItem(tVendorItem)
	local nMostCanBuy = 100
	if tVendorItem.nStackSize == 1 then
		nMostCanBuy = 1
	elseif tVendorItem.nStockCount ~= 0 then
		nMostCanBuy = tVendorItem.nStockCount
	end

	self:EnableBuyButton(tVendorItem)

	-- TODO: Take second currency into account
	local nPrice = 0
	if tVendorItem.tPriceInfo then
		nPrice = tVendorItem.tPriceInfo.nAmount1 * tVendorItem.nStackSize
	end

	if self.wndVendor:FindChild(kstrTabBuy):IsChecked() and nPrice > 0 then
		local nPlayerAmount = GameLib.GetPlayerCurrency(tVendorItem.tPriceInfo.eCurrencyType1, tVendorItem.tPriceInfo.eAltType1):GetAmount()
		nMostCanBuy = math.min(nMostCanBuy, math.floor(nPlayerAmount / nPrice))
		if nMostCanBuy == 0 then
			self:DisableBuyButton(true)
		end
	end

	if self.wndVendor:FindChild(kstrTabBuyback):IsChecked() or self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
		local nPlayerAmount = GameLib.GetPlayerCurrency(tVendorItem.tPriceInfo.eCurrencyType1, tVendorItem.tPriceInfo.eAltType1):GetAmount()
		if nPrice > nPlayerAmount then
			self:DisableBuyButton(true)
		end
	elseif tVendorItem.bFutureStock or not tVendorItem.bMeetsPreq then
		self:DisableBuyButton(true)
	end

	local strStack = ""
	if self.wndVendor:FindChild(kstrTabBuy):IsChecked() and tVendorItem.nStackSize > 1 then
		strStack = String_GetWeaselString(Apollo.GetString("Vendor_ItemCount"), tVendorItem.nStackSize)
	end
	self:SetBuyButtonText(strStack)
end

---------------------------------------------------------------------------------------------------
-- Alert Message Handlers
---------------------------------------------------------------------------------------------------

function Vendor:OnItemAdded(itemBought, nCount, eReason)
	if self.wndVendor and self.wndVendor:IsShown() and ktVendorRespondEvent[eReason] then
		local strItem = nCount > 1 and String_GetWeaselString(Apollo.GetString("CombatLog_MultiItem"), nCount, itemBought:GetName()) or itemBought:GetName()
		self:ShowAlertMessageContainer(String_GetWeaselString(ktVendorRespondEvent[eReason] or Apollo.GetString("Vendor_Bought"), strItem), false)
		Sound.Play(Sound.PlayUIVendorBuy)
	end
end

function Vendor:OnItemRemoved(itemSold, nCount, eReason)
	if self.wndVendor and self.wndVendor:IsShown() and ktVendorRespondEvent[eReason] then
		local strMessage = nCount > 1 and String_GetWeaselString(Apollo.GetString("CombatLog_MultiItem"), nCount, itemSold:GetName()) or itemSold:GetName()
		self:ShowAlertMessageContainer(String_GetWeaselString(Apollo.GetString("Vendor_Sold"), strMessage), false)
		Sound.Play(Sound.PlayUIVendorSell)
	end
end

function Vendor:OnGenericError(eError, strMessage)

	local tPurchaseFailEvent =  -- index is enums to respond to, value is optional (UNLOCALIZED) replacement string (otherwise the passed string is used)
	{
		[GameLib.CodeEnumGenericError.DbFailure] 						= "",
		[GameLib.CodeEnumGenericError.Item_BadId] 						= "",
		[GameLib.CodeEnumGenericError.Vendor_StackSize] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_SoldOut] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_UnknownItem] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_FailedPreReq] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_NotAVendor]				= "",
		[GameLib.CodeEnumGenericError.Vendor_TooFar] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_BadItemRec] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_NotEnoughToFillQuantity] 	= "",
		[GameLib.CodeEnumGenericError.Vendor_NotEnoughCash] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_UniqueConstraint] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_ItemLocked] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_IWontBuyThat] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_NoQuantity] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_BagIsNotEmpty] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_CuratorOnlyBuysRelics] 	= "",
		[GameLib.CodeEnumGenericError.Vendor_CannotBuyRelics] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_NoBuyer] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_NoVendor] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_Buyer_NoActionCC] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_Vendor_NoActionCC] 		= "",
		[GameLib.CodeEnumGenericError.Vendor_Vendor_Disposition] 		= "",
		[GameLib.CodeEnumGenericError.Item_InventoryFull] 				= "",
		[GameLib.CodeEnumGenericError.Item_UnknownItem] 				= "",
		[GameLib.CodeEnumGenericError.Item_QuestViolation] 				= "",
		[GameLib.CodeEnumGenericError.Item_Unique] 						= "",
		[GameLib.CodeEnumGenericError.Faction_NotEnoughRep] 			= "",
	}

	if self.wndVendor and self.wndVendor:IsShown() and tPurchaseFailEvent[eError] then
		if tPurchaseFailEvent[eError] ~= "" then
			strMessage = tPurchaseFailEvent[eError]
		end
		self:ShowAlertMessageContainer(strMessage, true)
	end
end

function Vendor:OnItemDurabilityUpdate(itemCurr, nOldValue)
	local nNewValue = itemCurr:GetDurability()
	if self.wndVendor and self.wndVendor:IsShown() and nNewValue > nOldValue then
		self:DisableBuyButton()
		self.tRepairableItems = nil
		self:Redraw()

		self:ShowAlertMessageContainer(Apollo.GetString("Vendor_RepairsComplete"), false)
	end
end

function Vendor:ShowAlertMessageContainer(strMessage, bFailed)
	self.wndVendor:FindChild("AlertMessageText"):SetText(strMessage)
	self.wndVendor:FindChild("AlertMessageTitleSucceed"):Show(not bFailed)
	self.wndVendor:FindChild("AlertMessageTitleFail"):Show(bFailed)
	self.wndVendor:FindChild("AlertMessageContainer"):Show(false, true)
	self.wndVendor:FindChild("AlertMessageContainer"):Show(true)

	Apollo.StopTimer("AlertMessageTimer")
	Apollo.StartTimer("AlertMessageTimer")
end

function Vendor:HideRestockingFee()
	local strMessage = Apollo.GetString("Vendor_RestockAlert")

	if self.wndVendor:FindChild("AlertMessageText"):GetText() == strMessage then
		self.wndVendor:FindChild("AlertMessageContainer"):Show(false)
	end
end

function Vendor:ProcessingRestockingFee(tItemData)
	if not tItemData or not tItemData.itemData or not tItemData.itemData:HasRestockingFee() then
		return false
	end

	local strMessage = Apollo.GetString("Vendor_RestockAlert")
	local wndAlertMessageText = self.wndVendor:FindChild("AlertMessageText")

	if wndAlertMessageText:GetText() == strMessage and wndAlertMessageText:IsVisible() then
		return false
	end

	wndAlertMessageText:SetText(strMessage)
	self.wndVendor:FindChild("AlertMessageTitleSucceed"):Show(false)
	self.wndVendor:FindChild("AlertMessageTitleFail"):Show(false)
	self.wndVendor:FindChild("AlertMessageContainer"):Show(false, true)
	self.wndVendor:FindChild("AlertMessageContainer"):Show(true)
	return true
end

function Vendor:OnAlertMessageTimer()
	Apollo.StopTimer("AlertMessageTimer")
	self.wndVendor:FindChild("AlertMessageContainer"):Show(false)
end

function Vendor:RefreshBuyBackTab()
	local tNewBuybackItems = self.wndVendor:GetData():GetBuybackItems()

	local nCount = 0
	if tNewBuybackItems ~= nil then
		nCount = #tNewBuybackItems
	end
	if nCount == 0 then
		self.wndVendor:FindChild(kstrTabBuyback):SetText(Apollo.GetString("CRB_Buyback"))
	else
		self.wndVendor:FindChild(kstrTabBuyback):SetText(String_GetWeaselString(Apollo.GetString("Vendor_TabLabelMultiple"), Apollo.GetString("CRB_Buyback"), nCount))
	end
end

function Vendor:RefreshRepairTab()
	local tNewRepairableItems = {}
	if IsRepairVendor(self.wndVendor:GetData()) then
		tNewRepairableItems = self.wndVendor:GetData():GetRepairableItems()
		for idx, tItem in pairs(tNewRepairableItems or {}) do
			tItem.idUnique = tItem.idLocation
		end
	end
	
	local nCount = tNewRepairableItems and #tNewRepairableItems or 0

	if nCount == 0 then
		self.wndVendor:FindChild(kstrTabRepair):SetText(Apollo.GetString("CRB_Repair"))
	else
		self.wndVendor:FindChild(kstrTabRepair):SetText(String_GetWeaselString(Apollo.GetString("Vendor_TabLabelMultiple"), Apollo.GetString("CRB_Repair"), nCount))
	end
end

---------------------------------------------------------------------------------------------------
-- Old Buy vs Sell vs Etc. Update Methods
-- TODO: Refactor this entire thing
---------------------------------------------------------------------------------------------------

function Vendor:UpdateVendorItems() -- TODO: Old code
	if not self.wndVendor:GetData() then -- Get Data should be the Vendor Unit
		return
	end

	local tVendorGroups = self.wndVendor:GetData():GetVendorGroups()
	local tNewVendorItems = self.wndVendor:GetData():GetVendorItems()
	local tNewVendorItemsByGroup = self:ArrangeGroups(tNewVendorItems, tVendorGroups)

	local bChanged = false
	local bItemCountChanged = false
	local bGroupCountChanged = false
	if self.tVendorItemsByGroup == nil or not self:TableEquals(tNewVendorItemsByGroup, self.tVendorItemsByGroup) then
		bChanged = true
		bItemCountChanged = #tNewVendorItems ~= (self.tVendorItems ~= nil and #self.tVendorItems or 0)
		bGroupCountChanged = #tNewVendorItemsByGroup ~= (self.tVendorItemsByGroup ~= nil and #self.tVendorItemsByGroup or 0)
		self.tVendorItems = tNewVendorItems
		self.tVendorItemsByGroup = tNewVendorItemsByGroup
	end

	local tReturn = {}
	tReturn.bChanged = bChanged
	tReturn.bItemCountChanged = bItemCountChanged
	tReturn.bGroupCountChanged = bGroupCountChanged
	tReturn.tUpdatedItems = self.tVendorItemsByGroup

	return tReturn
end

---------------------------------------------------------------------------------------------------
function Vendor:UpdateSellItems()
	if not self.wndVendor:GetData() then -- Get Data should be the Vendor Unit
		return
	end

	local tInvItems = GameLib.GetPlayerUnit():GetInventoryItems()
	local tNewSellItems = {}
	for key, tItemData in ipairs(tInvItems) do
		local itemCurr = self:ItemToVendorSellItem(tItemData.itemInBag, 1)
		if itemCurr then
			table.insert(tNewSellItems, itemCurr)
		end
	end

	local tSellGroups = {{idGroup = 1, strName = "Backpack"}}
	local tNewSellItemsByGroup = self:ArrangeGroups(tNewSellItems, tSellGroups)

	local bChanged = false
	local bItemCountChanged = false
	local bGroupCountChanged = false
	if self.tSellItemsByGroup == nil or not self:TableEquals(tNewSellItemsByGroup, self.tSellItemsByGroup) then
		bChanged = true
		bItemCountChanged = #tNewSellItems ~= (self.tSellItems ~= nil and #self.tSellItems or 0)
		bGroupCountChanged = #tNewSellItemsByGroup ~= (self.tSellItemsByGroup ~= nil and #self.tSellItemsByGroup or 0)
		self.tSellItems = tNewSellItems
		self.tSellItemsByGroup = tNewSellItemsByGroup
	end

	local tReturn = {}
	tReturn.bChanged = bChanged
	tReturn.bItemCountChanged = bItemCountChanged
	tReturn.bGroupCountChanged = bGroupCountChanged
	tReturn.tUpdatedItems = self.tSellItemsByGroup

	return tReturn
end

---------------------------------------------------------------------------------------------------
function Vendor:UpdateBuybackItems()
	if not self.wndVendor:GetData() then -- Get Data should be the Vendor Unit
		return
	end

	local tNewBuybackItems = self.wndVendor:GetData():GetBuybackItems()
	local tNewBuybackItemsByGroup = self:ArrangeGroups(tNewBuybackItems)

	self:RefreshBuyBackTab()

	local bChanged = false
	local bItemCountChanged = false
	local bGroupCountChanged = false
	if self.tBuybackItemsByGroup == nil or not self:TableEquals(tNewBuybackItemsByGroup, self.tBuybackItemsByGroup) then
		bChanged = true
		bItemCountChanged = #tNewBuybackItems ~= (self.tBuybackItems ~= nil and #self.tBuybackItems or 0)
		bGroupCountChanged = #tNewBuybackItemsByGroup ~= (self.tBuybackItemsByGroup ~= nil and #self.tBuybackItemsByGroup or 0)
		self.tBuybackItems = tNewBuybackItems
		self.tBuybackItemsByGroup = tNewBuybackItemsByGroup
	end

	local tReturn = {}
	tReturn.bChanged = bChanged
	tReturn.bItemCountChanged = bItemCountChanged
	tReturn.bGroupCountChanged = bGroupCountChanged
	tReturn.tUpdatedItems = self.tBuybackItemsByGroup

	return tReturn
end

---------------------------------------------------------------------------------------------------
function Vendor:UpdateRepairableItems()
	if not self.wndVendor:GetData() then -- Get Data should be the Vendor Unit
		return
	end

	local tNewRepairableItems = {}
	if IsRepairVendor(self.wndVendor:GetData()) then
		tNewRepairableItems = self.wndVendor:GetData():GetRepairableItems()
		for idx, tItem in pairs(tNewRepairableItems or {}) do
			tItem.idUnique = tItem.idLocation
		end
	end

	local tNewRepairableItemsByGroup = self:ArrangeGroups(tNewRepairableItems)
	
	self:RefreshRepairTab()

	local bChanged = false
	local bItemCountChanged = false
	local bGroupCountChanged = false
	if self.tRepairableItemsByGroup == nil or not self:TableEquals(tNewRepairableItemsByGroup, self.tRepairableItemsByGroup) then
		bChanged = true
		bItemCountChanged = #tNewRepairableItems ~= (self.tRepairableItems ~= nil and #self.tRepairableItems or 0)
		bGroupCountChanged = #tNewRepairableItemsByGroup ~= (self.tRepairableItemsByGroup ~= nil and #self.tRepairableItemsByGroup or 0)
		self.tRepairableItems = tNewRepairableItems
		self.tRepairableItemsByGroup = tNewRepairableItemsByGroup
	end

	local tReturn = {}
	tReturn.bChanged = bChanged
	tReturn.bItemCountChanged = bItemCountChanged
	tReturn.bGroupCountChanged = bGroupCountChanged
	tReturn.tUpdatedItems = self.tRepairableItemsByGroup

	return tReturn
end

---------------------------------------------------------------------------------------------------
-- Simple UI Methods
---------------------------------------------------------------------------------------------------

function Vendor:OnWindowClosed()
	Event_CancelVending()
end

function Vendor:OnCloseBtn()
	self.wndVendor:Close()
end

function Vendor:OnCloseVendorWindow()
	self.wndVendor:Close()
end

-----------------------------------------------------------------------------------------------
-- Guild
-----------------------------------------------------------------------------------------------

function Vendor:OnGuildChange() -- Catch All method to validate Guild Repair
	if not self.wndVendor or not self.wndVendor:IsValid() or not self.wndVendor:IsVisible() then
		return
	end

	local tMyGuild = nil
	for idx, tGuild in pairs(GuildLib.GetGuilds()) do
		if tGuild:GetType() == GuildLib.GuildType_Guild then
			tMyGuild = tGuild
			break
		end
	end

	local bIsRepairing = self.wndVendor:FindChild(kstrTabRepair):IsChecked()

	-- The following code allows for tMyGuild to be nil
	local nLeft, nTop, nRight, nBottom = self.wndVendor:FindChild("LeftSideContainer"):GetAnchorOffsets()
	self.wndVendor:FindChild("LeftSideContainer"):SetAnchorOffsets(nLeft, nTop, nRight, (tMyGuild and bIsRepairing) and -84 or -84) -- TODO HACKY: Hardcoded formatting
	self.wndVendor:FindChild("GuildRepairContainer"):Show(tMyGuild and bIsRepairing)

	if tMyGuild then -- If not valid, it won't be shown anyways
		local tMyRankData = tMyGuild:GetRanks()[tMyGuild:GetMyRank()]
		
		local nAvailableFunds
		local nRepairRemainingToday = math.min(knMaxGuildLimit, tMyRankData.monBankRepairLimit:GetAmount()) - tMyGuild:GetBankMoneyRepairToday():GetAmount()
		if tMyGuild:GetMoney():GetAmount() <= nRepairRemainingToday then
			nAvailableFunds = tMyGuild:GetMoney():GetAmount()
		else
			nAvailableFunds = nRepairRemainingToday
		end

		self.wndVendor:FindChild("GuildRepairFundsCashWindow"):SetAmount(math.max(0, nAvailableFunds))

		local repairableItems = self.wndVendor:GetData():GetRepairableItems()
		local bHaveItemsToRepair = #repairableItems > 0
		
		-- Check if you have enough and text color accordingly
		local nRepairAllCost = 0
		for key, tCurrItem in pairs(repairableItems) do
			local tCurrPrice = math.max(tCurrItem.tPriceInfo.nAmount1, tCurrItem.tPriceInfo.nAmount2) * tCurrItem.nStackSize
			nRepairAllCost = nRepairAllCost + tCurrPrice
		end
		local bSufficientFunds = nRepairAllCost <= nAvailableFunds
		
		-- Enable / Disable button
		local tCurrItem = self.wndVendor:FindChild("Buy"):GetData()
		if tCurrItem and tCurrItem.tPriceInfo then
			local tCurrPrice = math.max(tCurrItem.tPriceInfo.nAmount1, tCurrItem.tPriceInfo.nAmount2) * tCurrItem.nStackSize
			bSufficientFunds = tCurrPrice <= nAvailableFunds
		end
		
		self.wndVendor:FindChild("GuildRepairBtn"):Enable(nRepairRemainingToday > 0 and bHaveItemsToRepair and bSufficientFunds)
		self.wndVendor:FindChild("GuildRepairFundsCashWindow"):SetTextColor(bSufficientFunds and ApolloColor.new("UI_TextMetalBodyHighlight") or ApolloColor.new("red"))

		self.wndVendor:FindChild("GuildRepairBtn"):SetData(tMyGuild)
	end
end

function Vendor:OnGuildRepairBtn(wndHandler, wndControl)
	local tMyGuild = wndHandler:GetData()
	local tItemData = self.wndVendor:FindChild("Buy"):GetData()

	if tMyGuild and tItemData and tItemData.idLocation then
		tMyGuild:RepairItemVendor(tItemData.idLocation)
		local eRepairCurrency = tItemData.tPriceInfo.eCurrencyType1
		local nRepairAmount = tItemData.tPriceInfo.nAmount1
		self.wndVendor:FindChild("AlertCost"):SetMoneySystem(eRepairCurrency)
		self.wndVendor:FindChild("AlertCost"):SetAmount(nRepairAmount)
	elseif tMyGuild then
		tMyGuild:RepairAllItemsVendor()
		local monRepairAllCost = GameLib.GetRepairAllCost()
		self.wndVendor:FindChild("AlertCost"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
		self.wndVendor:FindChild("AlertCost"):SetAmount(monRepairAllCost)
	end
	Sound.Play(Sound.PlayUIVendorRepair)
end

function Vendor:OnBuy(wndHandler, wndControl)
	if not wndHandler or not self.wndVendor:GetData() then
		return
	end

	local tItemData = wndHandler:GetData()
	if not self:ProcessingRestockingFee(tItemData) then
		self:FinalizeBuy(tItemData)
	end
end

function Vendor:FinalizeBuy(tItemData)
	if tItemData then
		local idItem = tItemData.idUnique
		if self.wndVendor:FindChild(kstrTabBuy):IsChecked() then
			BuyItemFromVendor(idItem, 1) -- TODO: quantity chooser
			self.tDefaultSelectedItem = tItemData
			self:ShowAlertMessageContainer(String_GetWeaselString(Apollo.GetString("Vendor_Bought"), tItemData.strName), false) -- TODO: This shouldn't be needed
			
			if tItemData.itemData then
				local monBuyPrice = tItemData.itemData:GetBuyPrice()
				self.wndVendor:FindChild("AlertCost"):SetAmount(monBuyPrice)
			end
		elseif self.wndVendor:FindChild(kstrTabSell):IsChecked() then
			SellItemToVendorById(idItem, tItemData.nStackSize)
			self:SelectNextItemInLine(tItemData)
			self:Redraw()
			
			if tItemData.itemData then
				local monSellPrice = tItemData.itemData:GetSellPrice():Multiply(tItemData.nStackSize)
				self.wndVendor:FindChild("AlertCost"):SetAmount(monSellPrice)
			end
		elseif self.wndVendor:FindChild(kstrTabBuyback):IsChecked() then
			BuybackItemFromVendor(idItem)
			self:SelectNextItemInLine(tItemData)
			
			if tItemData.itemData then
				local monBuyBackPrice = tItemData.itemData:GetSellPrice():Multiply(tItemData.nStackSize)
				self.wndVendor:FindChild("AlertCost"):SetAmount(monBuyBackPrice)
			end
		elseif self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
			local idLocation = tItemData.idLocation or nil
			if idLocation then
				RepairItemVendor(idLocation)
				local eRepairCurrency = tItemData.tPriceInfo.eCurrencyType1
				local nRepairAmount = tItemData.tPriceInfo.nAmount1
				self.wndVendor:FindChild("AlertCost"):SetMoneySystem(eRepairCurrency)
				self.wndVendor:FindChild("AlertCost"):SetAmount(nRepairAmount)
			else
				self:RepairAllHelper()
			end
			Sound.Play(Sound.PlayUIVendorRepair)
		end
	elseif self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
		self:RepairAllHelper()
		Sound.Play(Sound.PlayUIVendorRepair)
	else
		return
	end

	self.wndVendor:FindChild("VendorFlash"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
end

function Vendor:RepairAllHelper()
	RepairAllItemsVendor()
	local monRepairAllCost = GameLib.GetRepairAllCost()
	self.wndVendor:FindChild("AlertCost"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
	self.wndVendor:FindChild("AlertCost"):SetAmount(monRepairAllCost)
end

function Vendor:OnTabBtn(wndHandler, wndControl)
	if not wndHandler then return end
	self.wndItemContainer:DestroyChildren()
	self.tDefaultSelectedItem = nil
	self.idOpenedGroup = nil
	self:DisableBuyButton()
	self:Redraw()
end

function Vendor:SetBuyButtonText(strAppend)
	if not strAppend then
		strAppend = ""
	end

	local strCaption = "" -- TODO REFACTOR
	if self.wndVendor:FindChild(kstrTabBuy):IsChecked() then
		strCaption = Apollo.GetString("Vendor_Purchase")
	elseif self.wndVendor:FindChild(kstrTabSell):IsChecked() then
		strCaption = Apollo.GetString("Vendor_Sell")
	elseif self.wndVendor:FindChild(kstrTabBuyback):IsChecked() then
		strCaption = Apollo.GetString("Vendor_Purchase")
	elseif self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
		strCaption = Apollo.GetString(self.wndVendor:FindChild("Buy"):GetData() and "Vendor_Repair" or "Vendor_RepairAll")
	else
		strCaption = Apollo.GetString("Vendor_Purchase")
	end

	self.wndVendor:FindChild("Buy"):SetText(String_GetWeaselString(strCaption, strAppend))
	self.wndVendor:FindChild("GuildRepairBtn"):SetText(Apollo.GetString(self.wndVendor:FindChild("Buy"):GetData() and "Vendor_GuildRepair" or "Vendor_GuildRepairAll"))
end

---------------------------------------------------------------------------------------------------
-- Old code
---------------------------------------------------------------------------------------------------

function Vendor:ArrangeGroups(tItemList, tGroups)
	local tNewList = {
		tOther =
		{
			strName = Apollo.GetString("ChallengeTypeGeneral"),
			tItems = {}
		}
	} --, specials = {}, future = {} } }

	if not tGroups then
		tNewList.tOther.tItems = tItemList
		return tNewList
	end

	for idx, value in ipairs(tGroups) do
		if value.strName and string.len(value.strName) > 0 then
			tNewList[value.idGroup] = { strName = value.strName, tItems = {}, idGroup = value.idGroup } --, specials = {}, future = {} }
		end
	end

	for idx, value in ipairs(tItemList) do
		local tGroup = tNewList[value.idGroup] or tNewList.tOther
		table.insert(tGroup.tItems, value)
	end

	for key, value in pairs(tNewList) do
		if #value.tItems == 0 then -- + #v.specials + #v.future == 0 then
			tNewList[key] = nil
		end
	end
	return tNewList
end

function Vendor:ItemToVendorSellItem(itemCurr, nGroup)
	if not itemCurr then
		return nil
	end

	local nSellPrice = itemCurr:GetSellPrice()
	if not nSellPrice then
		return nil
	end

	if not nGroup then
		nGroup = 0
	end

	local tNewItem = {}
	tNewItem.idUnique = itemCurr:GetInventoryId()
	tNewItem.idItem = itemCurr:GetItemId()
	tNewItem.eType = itemCurr:GetItemType()
	tNewItem.nStackSize = itemCurr:GetStackCount()
	tNewItem.nStockCount = 0
	tNewItem.idGroupId = nGroup
	tNewItem.bMeetsPreq = true
	tNewItem.bIsSpecial = false
	tNewItem.bFutureStock = false
	--tNewItem.price = {amount1 = sellPrice.GetAmount(), currencyType1 = sellPrice:GetMoneyType(), amount2 = 0, currencyType2 = 1}
	tNewItem.itemData = itemCurr
	tNewItem.strIcon = itemCurr:GetIcon()
	tNewItem.strName = itemCurr:GetName()
	return tNewItem
end

function Vendor:OnVendorListItemGenerateTooltip(wndControl, wndHandler) -- wndHandler is VendorListItemIcon
	if wndHandler ~= wndControl then
		return
	end

	wndControl:SetTooltipDoc(nil)

	local tListItem = wndHandler:GetData()
	local itemData = tListItem.itemData

	if itemData then
		local tPrimaryTooltipOpts = {}

		if self.wndVendor:FindChild(kstrTabSell):IsChecked() then
			tPrimaryTooltipOpts.bSelling = true
		elseif self.wndVendor:FindChild(kstrTabBuy):IsChecked() then
			tPrimaryTooltipOpts.bBuying = true
			tPrimaryTooltipOpts.nPrereqVendorId = tListItem.idPrereq
		elseif self.wndVendor:FindChild(kstrTabBuyback):IsChecked() then
			tPrimaryTooltipOpts.bBuyback = true
			tPrimaryTooltipOpts.nPrereqVendorId = tListItem.idPrereq
		end

		tPrimaryTooltipOpts.bPrimary = true
		tPrimaryTooltipOpts.itemModData = tListItem.itemModData
		tPrimaryTooltipOpts.strMaker = tListItem.strMaker
		tPrimaryTooltipOpts.arGlyphIds = tListItem.arGlyphIds
		tPrimaryTooltipOpts.tGlyphData = tListItem.itemGlyphData
		tPrimaryTooltipOpts.itemCompare = itemData:GetEquippedItemForItemType()

		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetItemTooltipForm(self, wndControl, itemData, tPrimaryTooltipOpts, itemData.nStackSize)
		end
	else
		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetSpellTooltipForm(self, wndControl, tListItem.splData)
		end
	end
end

-- Deep table equality
function Vendor:TableEquals(tData1, tData2)
   if tData1 == tData2 then
       return true
   end
   local strType1 = type(tData1)
   local strType2 = type(tData2)
   if strType1 ~= strType2 then
	   return false
   end
   if strType1 ~= "table" or strType2 ~= "table" then
       return false
   end
   for key, value in pairs(tData1) do
       if value ~= tData2[key] and not self:TableEquals(value, tData2[key]) then
           return false
       end
   end
   for key in pairs(tData2) do
       if tData1[key] == nil then
           return false
       end
   end
   return true
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function Vendor:HelperRecipeAlreadyKnown(tCurrItem)
	local bAlreadyKnown = false

	if self.wndVendor:FindChild(kstrTabBuy):IsChecked() then
		if tCurrItem.itemData ~= nil then
			local tSpellOnItem = tCurrItem.itemData:GetActivateSpell()
			if tSpellOnItem then
				local tTradeskillReqs = tSpellOnItem:GetTradeskillRequirements()
				if tTradeskillReqs and tTradeskillReqs.bIsKnown then
					bAlreadyKnown = true
				end
			end
		end
	end
	return bAlreadyKnown
end

function Vendor:HelperIsTooExpensive(tCurrItem)
	if not tCurrItem.tPriceInfo then
		return false
	end
	
	local bTooExpensive = false

	if tCurrItem.tPriceInfo.nAmount1 > 0 then
		bTooExpensive = (tCurrItem.tPriceInfo.nAmount1 * tCurrItem.nStackSize) > GameLib.GetPlayerCurrency(tCurrItem.tPriceInfo.eCurrencyType1, tCurrItem.tPriceInfo.eAltType1):GetAmount()
	end
	if tCurrItem.tPriceInfo.nAmount2 > 0 then
		bTooExpensive = (tCurrItem.tPriceInfo.nAmount2 * tCurrItem.nStackSize) > GameLib.GetPlayerCurrency(tCurrItem.tPriceInfo.eCurrencyType2, tCurrItem.tPriceInfo.eAltType2):GetAmount()
	end

	return bTooExpensive
end

function Vendor:HelperPrereqFailed(tCurrItem)
	return tCurrItem.itemData and tCurrItem.itemData:IsEquippable() and not tCurrItem.itemData:CanEquip()
end

function Vendor:HelperPrereqBuyFailed(tCurrItem)
	local bPrereqFailed = false

	if not self.wndVendor:FindChild(kstrTabRepair):IsChecked() then
		bPrereqFailed = not tCurrItem.bMeetsPreq
	end

	return bPrereqFailed
end

function Vendor:FactoryCacheProduce(wndParent, strFormName, strKey)
	local wnd = self.tFactoryCache[strKey]
	if not wnd or not wnd:IsValid() then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		self.tFactoryCache[strKey] = wnd
	end
	
	for idx=1,#self.tFactoryCache do
		if not self.tFactoryCache[idx]:IsValid() then
			self.tFactoryCache[idx] = nil
		end
	end
	
	return wnd
end

---------------------------------------------------------------------------------------------------
-- VendorHeaderItem Functions
---------------------------------------------------------------------------------------------------

function Vendor:OnHeaderCheck(wndHandler, wndControl, eMouseButton)
	local wndParent = wndControl:GetParent()
	local tHeaderValue = wndParent:GetData()

	self.idOpenedGroup = tHeaderValue.idGroup
	
	if tHeaderValue.tItems then
		self:DrawListItems(wndParent:FindChild("VendorHeaderContainer"), tHeaderValue.tItems)
	end

	self:SizeHeader(wndParent)

	self.wndItemContainer:ArrangeChildrenVert(0)
	
	local nTop = ({wndParent:GetAnchorOffsets()})[2]
	self.wndItemContainer:SetVScrollPos(nTop)
end

function Vendor:OnHeaderUncheck(wndHandler, wndControl, eMouseButton)
	local wndParent = wndControl:GetParent()
	
	self.tDefaultSelectedItem = nil -- Erase the default selection now
	self:DisableBuyButton()
	self:OnGuildChange()
	
	wndParent:FindChild("VendorHeaderContainer"):DestroyChildren()
	
	self.idOpenedGroup = nil
	
	self:SizeHeader(wndParent)
	
	self.wndItemContainer:ArrangeChildrenVert(0)
	
	local nTop = ({wndParent:GetAnchorOffsets()})[2]
	self.wndItemContainer:SetVScrollPos(nTop)
end


--[[function Vendor:SellAllJunk( wndHandler, wndControl, eMouseButton )

	local tInvItems = GameLib.GetPlayerUnit():GetInventoryItems()

	local jCount = 0
		for _, val in pairs(tInvItems) do
		if val.itemInBag:GetItemCategory() == 94 then	--Junk ID
			SellItemToVendorById(val.itemInBag:GetInventoryId(), val.itemInBag:GetStackCount())
			jCount = jCount + 1
		end
	end
	
	if jCount > 0 then
		self:ShowAlertMessageContainer(jCount .. " " .. Apollo.GetString("vendor_junkitemssold"), false)
	end
end]]--
	
---------------------------------------------------------------------------
-- Vendor instance
---------------------------------------------------------------------------------------------------
local VendorInst = Vendor:new()
VendorInst:Init()
