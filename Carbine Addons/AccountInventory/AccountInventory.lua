-----------------------------------------------------------------------------------------------
-- Client Lua Script for AccountInventory
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "AccountItemLib"
require "CREDDExchangeLib"
require "FriendshipLib"

local AccountInventory = {}

local knBoomBoxItemId = 44359
local keCreddType = -1 * AccountItemLib.CodeEnumAccountCurrency.CREDD -- Negative to avoid collision with ID 1
local keNameChangeType = -1 * AccountItemLib.CodeEnumAccountCurrency.NameChange -- Negative to avoid collision with ID 2
local keRealmTransferType = -1 * AccountItemLib.CodeEnumAccountCurrency.RealmTransfer -- Negative to avoid collision with ID 3

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

local ktCurrencies =
{
	[AccountItemLib.CodeEnumAccountCurrency.CREDD] =
	{
		eType = AccountItemLib.CodeEnumAccountCurrency.CREDD,
		strNum = "AccountInventory_NumCredd",
		strName = "AccountInventory_CREDD",
		strIcon = "IconSprites:Icon_ItemMisc_UI_Item_CREDD",
		strTooltip = "AccountInventory_CreddTooltip",
	},
	[AccountItemLib.CodeEnumAccountCurrency.NameChange] =
	{
		eType = AccountItemLib.CodeEnumAccountCurrency.NameChange,
		strNum = "AccountInventory_NumRenames",
		strName = "AccountInventory_NameChange",
		strIcon = "IconSprites:Icon_ItemMisc_GenericVoucher",
		strTooltip = "AccountInventory_NameChangeTooltip",
	},
	[AccountItemLib.CodeEnumAccountCurrency.RealmTransfer] =
	{
		eType = AccountItemLib.CodeEnumAccountCurrency.RealmTransfer,
		strNum = "AccountInventory_NumTransfers",
		strName = "AccountInventory_RealmTransfer",
		strIcon = "Icon_ItemMisc_Generic_isolinear_chip",
		strTooltip = "AccountInventory_RealmTransferTooltip",
	},
}

function AccountInventory:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWndRefs = {}

    return o
end

function AccountInventory:Init()
    Apollo.RegisterAddon(self)
end

function AccountInventory:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AccountInventory.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function AccountInventory:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local nLastAccountBoundCount = self.nLastAccountBoundCount
	local tSave =
	{
		nLastAccountBoundCount = nLastAccountBoundCount,
	}
	return tSave
end

function AccountInventory:OnRestore(eType, tSavedData)
	if tSavedData then
		if tSavedData.tLocation then
			self.nLastAccountBoundCount = tSavedData.nLastAccountBoundCount
		end
	end
end

function AccountInventory:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 			"OnInterfaceMenuListHasLoaded", self)

	Apollo.RegisterEventHandler("ChangeWorld", 							"OnChangeWorld", self)
	Apollo.RegisterEventHandler("GenericEvent_ToggleAccountInventory", 	"OnAccountInventoryToggle", self)
	Apollo.RegisterEventHandler("AccountEntitlementUpdate", 			"OnAccountEntitlementUpdate", self)
	Apollo.RegisterEventHandler("AccountOperationResults", 				"OnAccountOperationResults", self) -- TODO

	Apollo.RegisterEventHandler("FriendshipRemove", 					"OnFriendshipRemove", self)

	Apollo.RegisterEventHandler("AccountPendingItemsUpdate", 			"RefreshInventory", self)
	Apollo.RegisterEventHandler("AccountInventoryUpdate", 				"RefreshInventory", self)
	Apollo.RegisterEventHandler("UpdateInventory", 						"RefreshInventory", self)
	Apollo.RegisterEventHandler("AchievementUpdated", 					"RefreshInventory", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 					"RefreshInventory", self)
	Apollo.RegisterEventHandler("SubZoneChanged", 						"RefreshInventory", self)
	Apollo.RegisterEventHandler("PathLevelUp", 							"RefreshInventory", self)

	Apollo.RegisterTimerHandler("AccountInventory_RefreshInventory",	"OnAccountInventory_RefreshInventory", self)
	Apollo.CreateTimer("AccountInventory_RefreshInventory", 5, false)
	Apollo.StopTimer("AccountInventory_RefreshInventory")

	self.bRefreshInventoryThrottle = false

	-- self.nLastAccountBoundCount, from OnRestore()
end

function AccountInventory:OnInterfaceMenuListHasLoaded()
	local strIcon = "Icon_Windows32_UI_CRB_InterfaceMenu_Gift"
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_AccountInventory"), {"GenericEvent_ToggleAccountInventory", "", strIcon})
	self:OnRefreshInterfaceMenuAlert()
end

function AccountInventory:OnRefreshInterfaceMenuAlert()
	local bShowHighlight = false
	local nAlertCount = #AccountItemLib.GetPendingAccountSingleItems() -- Escrow Only, Doesn't consider UI restrictions (e.g. no name)
	for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
		nAlertCount = nAlertCount + #tPendingAccountItemGroup.items
	end

	for idx, tAccountItem in pairs(AccountItemLib.GetAccountItems()) do
		if tAccountItem.item and tAccountItem.item:GetItemId() == knBoomBoxItemId then
			nAlertCount = nAlertCount + 1
			if tAccountItem.cooldown and tAccountItem.cooldown == 0 then
				bShowHighlight = true -- Always highlight if a boom box is ready to go
			end
		end
	end

	if not bShowHighlight and self.nLastAccountBoundCount then
		bShowHighlight = self.nLastAccountBoundCount ~= nAlertCount
	end

	if nAlertCount == 0 then
		Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", Apollo.GetString("InterfaceMenu_AccountInventory"), {false, "", 0})
	else
		Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", Apollo.GetString("InterfaceMenu_AccountInventory"), {bShowHighlight, "", nAlertCount})
	end
	self.nLastAccountBoundCount = nAlertCount
end

function AccountInventory:OnAccountEntitlementUpdate()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	self:RefreshEntitlements()
end

function AccountInventory:OnAccountInventoryToggle()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		self:SetupMainWindow()
	else
		self:OnDestroy()
	end
end

function AccountInventory:OnClose(wndHandler, wndControl)
	if wndHandler == wndControl then
		self:OnDestroy()
	end
end

function AccountInventory:OnChangeWorld()
	self:OnDestroy()
end

function AccountInventory:OnDestroy()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.locSavedWindowLoc = self.tWndRefs.wndMain:GetLocation()
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end
end

function AccountInventory:OnAccountOperationResults(eOperationType, eResult)
	local bSuccess = eResult == CREDDExchangeLib.CodeEnumAccountOperationResult.Ok
	local strMessage = ""
	if bSuccess then
		strMessage = Apollo.GetString("MarketplaceCredd_TransactionSuccess")
	elseif ktResultErrorCodeStrings[eResult] then
		strMessage = Apollo.GetString(ktResultErrorCodeStrings[eResult])
	else
		strMessage = Apollo.GetString("MarketplaceCredd_Error_GenericFail")
	end
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", strMessage)

	-- Immediately close if you redeemed CREDD, so we can see the spell effect
	if bSuccess and eOperationType == CREDDExchangeLib.CodeEnumAccountOperation.CREDDRedeem then
		self:OnDestroy()
		return
	end
end

-----------------------------------------------------------------------------------------------
-- Main
-----------------------------------------------------------------------------------------------

function AccountInventory:SetupMainWindow()
	self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "AccountInventoryForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.tWndRefs.wndMain, strName = Apollo.GetString("AccountInv_TitleText")})
	Event_ShowTutorial(GameLib.CodeEnumTutorial.General_AccountServices)

	--Menu buttons
	self.tWndRefs.wndInventoryBtn = self.tWndRefs.wndMain:FindChild("InventoryBtn")
	self.tWndRefs.wndEntitlementsBtn = self.tWndRefs.wndMain:FindChild("EntitlementsBtn")

	--Containers
	self.tWndRefs.wndInventory = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory")
	self.tWndRefs.wndInventoryGift = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryGift")
	self.tWndRefs.wndInventoryClaimConfirm = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryClaimConfirm")
	self.tWndRefs.wndInventoryTakeConfirm = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryTakeConfirm")
	self.tWndRefs.wndInventoryRedeemCreddConfirm = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryRedeemCreddConfirm")
	self.tWndRefs.wndInventoryGiftConfirm = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryGiftConfirm")
	self.tWndRefs.wndInventoryGiftReturnConfirm = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryGiftReturnConfirm")
	self.tWndRefs.wndEntitlements = self.tWndRefs.wndMain:FindChild("ContentContainer:Entitlements")

	--Inventory
	self.tWndRefs.wndEscrowGridContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:EscrowGridContainer")
	self.tWndRefs.wndInventoryGridContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:InventoryGridContainer")
	self.tWndRefs.wndInventoryClaimBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:ClaimBtn")
	self.tWndRefs.wndInventoryGiftBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:GiftBtn")
	self.tWndRefs.wndInventoryTakeBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:TakeBtn")
	self.tWndRefs.wndInventoryRedeemCreddBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:RedeemBtn")
	self.tWndRefs.wndInventoryReturnBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:ReturnBtn")
	self.tWndRefs.wndInventoryFilterMultiBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:InventoryFilterMultiBtn")
	self.tWndRefs.wndInventoryFilterLockedBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:Inventory:InventoryFilterLockedBtn")

	--Inventory Confirm
	self.tWndRefs.wndPendingClaimContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryClaimConfirm:PendingClaimContainer")
	self.tWndRefs.wndInventoryTakeConfirmContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryTakeConfirm:TakeContainer")
	self.tWndRefs.wndInventoryCreddRedeemConfirmContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryRedeemCreddConfirm:RedeemContainer")

	--Inventory Gift
	self.tWndRefs.wndInventoryGiftFriendContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryGift:FriendContainer")
	self.tWndRefs.wndInventoryGiftFriendSelectBtn = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryGift:GiftBtn")
	self.tWndRefs.wndInventoryGiftConfirmItemContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryGiftConfirm:InventoryGiftConfirmItemContainer")
	self.tWndRefs.wndInventoryGiftReturnConfirmItemContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:InventoryGiftReturnConfirm:InventoryGiftReturnContainer")

	--Entitlements
	self.tWndRefs.wndAccountGridContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:Entitlements:AccountGridContainer")
	self.tWndRefs.wndCharacterGridContainer = self.tWndRefs.wndMain:FindChild("ContentContainer:Entitlements:CharacterGridContainer")

	self.tWndRefs.wndMain:SetSizingMinimum(700, 480)
	self.tWndRefs.wndMain:SetSizingMaximum(1920, 1080)
	self.tWndRefs.wndInventoryBtn:SetCheck(true) -- Default check
	self.tWndRefs.wndInventoryGift:Show(false, true)
	self.tWndRefs.wndInventoryTakeConfirm:Show(false, true)
	self.tWndRefs.wndInventoryGiftConfirm:Show(false, true)
	self.tWndRefs.wndInventoryClaimConfirm:Show(false, true)
	self.tWndRefs.wndInventoryGiftReturnConfirm:Show(false, true)
	self.tWndRefs.wndInventoryRedeemCreddConfirm:Show(false, true)
	self.tWndRefs.wndInventoryFilterMultiBtn:SetCheck(true)
	self.tWndRefs.wndInventoryFilterLockedBtn:SetCheck(true)

	if self.locSavedWindowLoc then
		self.tWndRefs.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.unitPlayer = GameLib.GetPlayerUnit()

	self:RefreshInventory()
	self:RefreshEntitlements()
end

function AccountInventory:OnInventoryCheck(wndHandler, wndControl, eMouseButton)
	self:OnInventoryUncheck()
	self.tWndRefs.wndInventory:Show(true)
end

function AccountInventory:OnInventoryUncheck(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventory:Show(false)
	self.tWndRefs.wndInventoryGift:Show(false)
	self.tWndRefs.wndInventoryGiftConfirm:Show(false)
	self.tWndRefs.wndInventoryClaimConfirm:Show(false)
	self.tWndRefs.wndInventoryTakeConfirm:Show(false)
	self.tWndRefs.wndInventoryGiftReturnConfirm:Show(false)
end

function AccountInventory:OnEntitlementsCheck(wndHandler, wndControl, eMouseButton)
	self:OnEntitlementsUncheck()
	self.tWndRefs.wndEntitlements:Show(true)
end

function AccountInventory:OnEntitlementsUncheck(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndEntitlements:Show(false)
end

--[[
Inventory
]]--

function AccountInventory:HelperAddPendingSingleToContainer(wndParent, tPendingAccountItem)
	local strName = ""
	local strIcon = ""
	local strTooltip = ""
	local tPrereqInfo = self.unitPlayer and self.unitPlayer:GetPrereqInfo(tPendingAccountItem.prereqId) or nil
	local bShowLock = tPrereqInfo and not tPrereqInfo.bIsMet

	if tPendingAccountItem.item then
		strName = tPendingAccountItem.item:GetName()
		strIcon = tPendingAccountItem.item:GetIcon()
		-- No strTooltip Needed
	elseif tPendingAccountItem.entitlement and string.len(tPendingAccountItem.entitlement.name) > 0 then
		strName = String_GetWeaselString(Apollo.GetString("AccountInventory_EntitlementPrefix"), tPendingAccountItem.entitlement.name)
		strIcon = tPendingAccountItem.entitlement.icon or strIcon
		strTooltip = tPendingAccountItem.description
	elseif tPendingAccountItem.accountCurrency then
		strName = Apollo.GetString(ktCurrencies[tPendingAccountItem.accountCurrency.accountCurrencyEnum].strName or "")
		strIcon = tPendingAccountItem.icon
		strTooltip = Apollo.GetString(ktCurrencies[tPendingAccountItem.accountCurrency.accountCurrencyEnum].strTooltip or "")
	else -- Error Case
		return
	end

	local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", wndParent, self)
	wndGroup:SetData({bIsGroup = false, tData = tPendingAccountItem})
	wndGroup:FindChild("ItemButton"):SetText(strName)
	wndGroup:FindChild("ItemIconGiftable"):Show(tPendingAccountItem.canGift)

	local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroup:FindChild("ItemContainer"), self)
	wndObject:SetData(tPendingAccountItem)
	wndObject:FindChild("Name"):SetText("") -- Done at ItemButton if single, Only used by Groups
	wndObject:FindChild("Icon"):SetSprite(bShowLock and "CRB_AMPs:spr_AMPs_LockStretch_Blue" or strIcon)

	-- Icons for the number of redempetions / cooldowns
	if tPendingAccountItem.multiRedeem or tPendingAccountItem.multiRedeem then -- Should be only multiRedeem
		local bShowCooldown = tPendingAccountItem.cooldown and tPendingAccountItem.cooldown > 0
		wndGroup:FindChild("ItemIconText"):Show(bShowCooldown)
		wndGroup:FindChild("ItemIconText"):SetText(bShowCooldown and self:HelperCooldown(tPendingAccountItem.cooldown) or "")
	end
	wndGroup:FindChild("ItemIconOnceOnly"):Show(not tPendingAccountItem.multiRedeem and not tPendingAccountItem.multiRedeem) -- Should be only multiRedeem
	wndGroup:FindChild("ItemIconArrangeVert"):ArrangeChildrenVert(1)

	-- Tooltip
	if bShowLock then
		wndObject:SetTooltip(tPrereqInfo.strText)
	elseif tPendingAccountItem.item then
		Tooltip.GetItemTooltipForm(self, wndObject, tPendingAccountItem.item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	else
		wndObject:SetTooltip(strTooltip or "")
	end

	local nHeight = wndGroup:FindChild("ItemContainer"):ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndGroup:GetAnchorOffsets()
	wndGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 10)
end

function AccountInventory:HelperAddPendingGroupToContainer(wndParent, tPendingAccountItemGroup)
	local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", wndParent, self)
	wndGroup:SetData({bIsGroup = true, tData = tPendingAccountItemGroup})
	wndGroup:FindChild("ItemButton"):SetText("")
	wndGroup:FindChild("ItemIconGiftable"):Show(tPendingAccountItemGroup.canGift)

	local wndGroupContainer = wndGroup:FindChild("ItemContainer")
	for idx, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroupContainer, self)
		wndObject:SetData(tPendingAccountItem)

		local strName = ""
		local strIcon = ""
		local strTooltip = ""
		local tPrereqInfo = self.unitPlayer and self.unitPlayer:GetPrereqInfo(tPendingAccountItem.prereqId) or nil
		local bShowLock = tPrereqInfo and not tPrereqInfo.bIsMet

		if tPendingAccountItem.item then
			strName = tPendingAccountItem.item:GetName()
			strIcon = tPendingAccountItem.item:GetIcon()
			-- No strTooltip Needed
		elseif tPendingAccountItem.entitlement and string.len(tPendingAccountItem.entitlement.name) > 0 then
			strName = tPendingAccountItem.entitlement.name
			strIcon = tPendingAccountItem.entitlement.icon
			strTooltip = tPendingAccountItem.description
		elseif tPendingAccountItem.accountCurrency then
			strName = Apollo.GetString(ktCurrencies[tPendingAccountItem.accountCurrency.accountCurrencyEnum].strName or "")
			strIcon = ktCurrencies[tPendingAccountItem.accountCurrency.accountCurrencyEnum].strIcon or ""
			strTooltip = Apollo.GetString(ktCurrencies[tPendingAccountItem.accountCurrency.accountCurrencyEnum].strTooltip or "")
		else -- Error Case
			wndObject:Destroy()
			break
		end
		wndObject:FindChild("Name"):SetText(strName)
		wndObject:FindChild("Icon"):SetSprite(bShowLock and "CRB_AMPs:spr_AMPs_LockStretch_Blue" or strIcon)

		-- Tooltip
		if bShowLock then
			wndObject:SetTooltip(tPrereqInfo.strText)
		elseif tPendingAccountItem.item then
			Tooltip.GetItemTooltipForm(self, wndObject, tPendingAccountItem.item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		else
			wndObject:SetTooltip(strTooltip)
		end
	end

	if #wndGroupContainer:GetChildren() == 0 then -- Error Case
		wndGroup:Destroy()
		return
	end

	local nHeight = wndGroupContainer:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndGroup:GetAnchorOffsets()
	wndGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 10)
end

function AccountInventory:OnAccountInventory_RefreshInventory()
	Apollo.StopTimer("AccountInventory_RefreshInventory")
	self.bRefreshInventoryThrottle = false
end

function AccountInventory:RefreshInventory()
	if not self.bRefreshInventoryThrottle then
		self.bRefreshInventoryThrottle = true
		Apollo.StartTimer("AccountInventory_RefreshInventory")
		self:OnRefreshInterfaceMenuAlert() -- Happens even if wndMain hasn't loaded
	end

	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	local nInventoryGridScrollPos = self.tWndRefs.wndInventoryGridContainer:GetVScrollPos()
	local nEscrowGridScrollPos = self.tWndRefs.wndEscrowGridContainer:GetVScrollPos()
	self.tWndRefs.wndInventoryGridContainer:DestroyChildren()
	self.tWndRefs.wndEscrowGridContainer:DestroyChildren()

	-- Currencies
	for idx, tCurrData in pairs(ktCurrencies) do
		local nCurrencyCount = AccountItemLib.GetAccountCurrency(tCurrData.eType)
		if nCurrencyCount > 0 then
			local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", self.tWndRefs.wndInventoryGridContainer, self)
			wndGroup:SetData(-1 * tCurrData.eType) -- Don't need to care about bIsGroup or anything
			wndGroup:FindChild("ItemButton"):SetText(String_GetWeaselString(Apollo.GetString(tCurrData.strNum), nCurrencyCount))

			local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroup:FindChild("ItemContainer"), self)
			wndObject:SetData(-1 * tCurrData.eType) -- To avoid collision with ID 1,2,3
			wndObject:FindChild("Name"):SetText("")
			wndObject:FindChild("Icon"):SetSprite(tCurrData.strIcon)
			wndObject:SetTooltip(Apollo.GetString(tCurrData.strTooltip or ""))
		end
	end

	-- Boom Boxes (Account Bound only, not Escrow)
	local nBoomBoxCount = 0
	local tBoomBoxData = nil
	for idx, tAccountItem in pairs(AccountItemLib.GetAccountItems()) do
		if tAccountItem.item and tAccountItem.item:GetItemId() == knBoomBoxItemId then
			tBoomBoxData = tAccountItem
			nBoomBoxCount = nBoomBoxCount + 1
		end
	end

	if nBoomBoxCount > 0 then
		local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", self.tWndRefs.wndInventoryGridContainer, self)
		wndGroup:SetData({bIsGroup = false, tData = tBoomBoxData})
		wndGroup:FindChild("ItemButton"):SetText(String_GetWeaselString(Apollo.GetString("MarketplaceCommodity_MultiItem"), nBoomBoxCount, tBoomBoxData.item:GetName()))
		wndGroup:FindChild("ItemIconText"):Show(tBoomBoxData.cooldown and tBoomBoxData.cooldown > 0)
		wndGroup:FindChild("ItemIconText"):SetText(tBoomBoxData.cooldown and self:HelperCooldown(tBoomBoxData.cooldown) or "")
		wndGroup:FindChild("ItemIconArrangeVert"):ArrangeChildrenVert(1)

		local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroup:FindChild("ItemContainer"), self)
		wndObject:SetData(tBoomBoxData)
		wndObject:FindChild("Name"):SetText("")
		wndObject:FindChild("Icon"):SetSprite(tBoomBoxData.item:GetIcon())
	end

	-- Separator if we added at least one
	if next(self.tWndRefs.wndInventoryGridContainer:GetChildren()) then
		Apollo.LoadForm(self.xmlDoc, "InventoryHorizSeparator", self.tWndRefs.wndInventoryGridContainer, self)
	end

	-- Account Bound Inventory
	local bShowMulti = self.tWndRefs.wndInventoryFilterMultiBtn:IsChecked()
	local bShowLocked = self.tWndRefs.wndInventoryFilterLockedBtn:IsChecked()
	for idx, tAccountItem in pairs(AccountItemLib.GetAccountItems()) do
		if not tAccountItem.item or tAccountItem.item:GetItemId() ~= knBoomBoxItemId then
			local bFilterFinalResult = bShowMulti or (not tAccountItem.multiRedeem and not tAccountItem.multiRedeem) -- Bracket should be only multiRedeem
			if bFilterFinalResult and not bShowLocked then
				local tPrereqInfo = self.unitPlayer and self.unitPlayer:GetPrereqInfo(tAccountItem.prereqId) or nil
				bFilterFinalResult = tPrereqInfo and tPrereqInfo.bIsMet
			end

			if bFilterFinalResult then
			self:HelperAddPendingSingleToContainer(self.tWndRefs.wndInventoryGridContainer, tAccountItem)
			end
		end
	end
	self.tWndRefs.wndInventoryGridContainer:ArrangeChildrenVert(0)
	self.tWndRefs.wndInventoryGridContainer:SetVScrollPos(nInventoryGridScrollPos)

	-- Escrow Singles
	for idx, tPendingAccountItem in pairs(AccountItemLib.GetPendingAccountSingleItems()) do
		self:HelperAddPendingSingleToContainer(self.tWndRefs.wndEscrowGridContainer, tPendingAccountItem)
	end

	-- Escrow Groups
	for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
		self:HelperAddPendingGroupToContainer(self.tWndRefs.wndEscrowGridContainer, tPendingAccountItemGroup)
	end
	self.tWndRefs.wndEscrowGridContainer:ArrangeChildrenVert(0)
	self.tWndRefs.wndEscrowGridContainer:SetVScrollPos(nEscrowGridScrollPos)

	self:RefreshInventoryActions()
end

function AccountInventory:RefreshInventoryActions()
	local wndSelectedPendingItem
	for idx, wndPendingItem in pairs(self.tWndRefs.wndEscrowGridContainer:GetChildren()) do
		if wndPendingItem:FindChild("ItemButton") and wndPendingItem:FindChild("ItemButton"):IsChecked() then
			wndSelectedPendingItem = wndPendingItem
			break
		end
	end

	local wndSelectedItem
	for idx, wndItem in pairs(self.tWndRefs.wndInventoryGridContainer:GetChildren()) do
		if wndItem:FindChild("ItemButton") and wndItem:FindChild("ItemButton"):IsChecked() then -- Could be a divider
			wndSelectedItem = wndItem
			break
		end
	end

	local tSelectedPendingData = wndSelectedPendingItem ~= nil and wndSelectedPendingItem:GetData() or nil
	local tSelectedData = wndSelectedItem ~= nil and wndSelectedItem:GetData() or nil
	local bPendingCanClaim = tSelectedPendingData ~= nil and tSelectedPendingData.tData.canClaim
	local bPendingCanGift = tSelectedPendingData ~= nil and tSelectedPendingData.tData.canGift
	local bPendingCanReturn = tSelectedPendingData ~= nil and tSelectedPendingData.tData.canReturn

	self.tWndRefs.wndInventoryClaimBtn:Enable(bPendingCanClaim)
	self.tWndRefs.wndInventoryClaimBtn:SetData(tSelectedPendingData)

	self.tWndRefs.wndInventoryGiftBtn:Enable(bPendingCanGift)
	self.tWndRefs.wndInventoryGiftBtn:SetData(tSelectedPendingData)
	self.tWndRefs.wndInventoryGiftBtn:Show(not bPendingCanReturn)

	self.tWndRefs.wndInventoryReturnBtn:Enable(bPendingCanReturn)
	self.tWndRefs.wndInventoryReturnBtn:SetData(tSelectedPendingData)
	self.tWndRefs.wndInventoryReturnBtn:Show(bPendingCanReturn)

	-- Check if currency
	local bCanBeClaimed = true
	if tSelectedData and type(tSelectedData) == "table" and tSelectedData.tData and tSelectedData.tData.item and tSelectedData.tData.item:GetItemId() == knBoomBoxItemId then -- If BoomBox
		bCanBeClaimed = tSelectedData.tData.cooldown == 0
	elseif tSelectedData and type(tSelectedData) == "table" and tSelectedData.tData then -- If Credd/NameChange/RealmTransfer
		bCanBeClaimed = tSelectedData.tData ~= keCreddType and tSelectedData.tData ~= keNameChangeType and tSelectedData.tData ~= keRealmTransferType
	elseif tSelectedData and type(tSelectedData) == "number" then -- Redundant check if Credd/NameChange/RealmTransfer
		bCanBeClaimed = tSelectedData ~= keCreddType and tSelectedData ~= keNameChangeType and tSelectedData ~= keRealmTransferType
	end

	-- It's an item, check pre-reqs
	if bCanBeClaimed and tSelectedData and tSelectedData.tData and tSelectedData.tData.prereqId > 0 then
		local tPrereqInfo = GameLib.GetPlayerUnit():GetPrereqInfo(tSelectedData.tData.prereqId)
		bCanBeClaimed = tPrereqInfo and tPrereqInfo.bIsMet and tSelectedData.tData.canClaim
	end

	self.tWndRefs.wndInventoryTakeBtn:Enable(tSelectedData and bCanBeClaimed)
	self.tWndRefs.wndInventoryTakeBtn:SetData(tSelectedData)
	self.tWndRefs.wndInventoryTakeBtn:Show(tSelectedData ~= keCreddType)
	self.tWndRefs.wndInventoryRedeemCreddBtn:Show(tSelectedData == keCreddType)
end

function AccountInventory:OnPendingInventoryItemCheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryActions()
end

function AccountInventory:OnPendingInventoryItemUncheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryActions()
end

function AccountInventory:OnInventoryFilterToggle(wndHandler, wndControl)
	self.tWndRefs.wndInventoryGridContainer:SetVScrollPos(0)
	self.tWndRefs.wndInventoryGridContainer:SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self:RefreshInventory()
end

function AccountInventory:OnPendingClaimBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventoryClaimConfirm:SetData(wndControl:GetData())
	self:RefreshPendingConfirm()

	--self.tWndRefs.wndInventory:Show(false)
	self.tWndRefs.wndInventoryClaimConfirm:Show(true)
end

function AccountInventory:OnPendingGiftBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventoryGift:SetData(wndControl:GetData())
	self:RefreshInventoryGift()

	self.tWndRefs.wndInventory:Show(false)
	self.tWndRefs.wndInventoryGift:Show(true)
end

function AccountInventory:OnInventoryTakeBtn(wndHandler, wndControl, eMouseButton)
	local tTakeData = wndHandler:GetData()
	self.tWndRefs.wndInventoryTakeConfirm:SetData(tTakeData)
	self.tWndRefs.wndInventoryTakeConfirmContainer:DestroyChildren()
	self.tWndRefs.wndInventoryTakeConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountTakeItem, tTakeData.tData.index)

	self:HelperAddPendingSingleToContainer(self.tWndRefs.wndInventoryTakeConfirmContainer, tTakeData.tData)

	self.tWndRefs.wndInventory:Show(false)
	self.tWndRefs.wndInventoryTakeConfirm:Show(true)

	for idx, wndCurr in pairs(self.tWndRefs.wndInventoryTakeConfirmContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
		end
	end
end

function AccountInventory:OnInventoryRedeemCreddBtn(wndHandler, wndControl, eMouseButton)
	local tCurrData = ktCurrencies[AccountItemLib.CodeEnumAccountCurrency.CREDD]
	self.tWndRefs.wndInventoryRedeemCreddConfirm:SetData(tCurrData)
	self.tWndRefs.wndInventoryCreddRedeemConfirmContainer:DestroyChildren()
	self.tWndRefs.wndInventoryRedeemCreddConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountCreddRedeem)

	local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", self.tWndRefs.wndInventoryCreddRedeemConfirmContainer, self)
	wndGroup:SetData(-1 * tCurrData.eType)
	wndGroup:FindChild("ItemButton"):SetText(String_GetWeaselString(Apollo.GetString(tCurrData.strNum), 1))

	local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroup:FindChild("ItemContainer"), self)
	wndObject:SetData(-1 * tCurrData.eType)
	wndObject:FindChild("Name"):SetText("")
	wndObject:FindChild("Icon"):SetSprite(tCurrData.strIcon)
	wndObject:SetTooltip(Apollo.GetString(tCurrData.strTooltip or ""))

	self.tWndRefs.wndInventory:Show(false)
	self.tWndRefs.wndInventoryRedeemCreddConfirm:Show(true)
end

function AccountInventory:OnPendingReturnBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventoryGiftReturnConfirm:SetData(wndControl:GetData())
	self:RefreshInventoryGiftReturnConfirm()

	self.tWndRefs.wndInventory:Show(false)
	self.tWndRefs.wndInventoryGiftReturnConfirm:Show(true)
end

--[[
Inventory Claim Confirm
]]--

function AccountInventory:RefreshPendingConfirm()
	local tSelectedPendingData = self.tWndRefs.wndInventoryClaimConfirm:GetData()
	self.tWndRefs.wndPendingClaimContainer:DestroyChildren()

	local nIndex = tSelectedPendingData.tData.index
	local bIsGroup = tSelectedPendingData.bIsGroup

	self.tWndRefs.wndInventoryClaimConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountClaimItem, nIndex, bIsGroup)

	if tSelectedPendingData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.tWndRefs.wndPendingClaimContainer, tSelectedPendingData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.tWndRefs.wndPendingClaimContainer, tSelectedPendingData.tData)
	end

	for idx, wndCurr in pairs(self.tWndRefs.wndPendingClaimContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
		end
	end
end

function AccountInventory:OnAccountPendingItemsClaimed(wndHandler, wndControl)
	self:RefreshInventory()
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryClaimConfirm:Show(false)
end

function AccountInventory:OnPendingConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryClaimConfirm:Show(false)
end

--[[
Inventory Take Confirm
]]--

function AccountInventory:OnAccountPendingItemTook(wndHandler, wndControl)
	self:RefreshInventory()
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryTakeConfirm:Show(false)
end

function AccountInventory:OnInventoryTakeConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryTakeConfirm:Show(false)
end

--[[
Inventory Credd Redeem Confirm
]]--

function AccountInventory:OnAccountCREDDRedeemed(wndHandler, wndControl)
	self:RefreshInventory()
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryRedeemCreddConfirm:Show(false)
end

function AccountInventory:OnInventoryCreddRedeemConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryRedeemCreddConfirm:Show(false)
end

--[[
Inventory Gift
]]--


function AccountInventory:OnFriendshipRemove()
	if not self.tWndRefs.wndInventoryGift or not self.tWndRefs.wndInventoryGift:IsValid() then
		return
	end
	self.tWndRefs.wndInventoryGift:Show(false)
end

function AccountInventory:RefreshInventoryGift()
	local tSelectedPendingData = self.tWndRefs.wndInventoryGift:GetData()

	self.tWndRefs.wndInventoryGiftFriendContainer:DestroyChildren()
	for idx, tFriend in pairs(FriendshipLib.GetAccountList()) do
		local wndFriend = Apollo.LoadForm(self.xmlDoc, "FriendForm", self.tWndRefs.wndInventoryGiftFriendContainer, self)
		wndFriend:SetData(tFriend)
		wndFriend:FindChild("FriendNote"):SetTooltip(tFriend.strPrivateNote or "")
		wndFriend:FindChild("FriendNote"):Show(string.len(tFriend.strPrivateNote or "") > 0)
		wndFriend:FindChild("FriendButton"):SetText(String_GetWeaselString(Apollo.GetString("AccountInventory_AccountFriendPrefix"), tFriend.strCharacterName))
	end
	for idx, tFriend in pairs(FriendshipLib.GetList()) do
		if tFriend.bFriend then -- Not Ignore or Rival
			local wndFriend = Apollo.LoadForm(self.xmlDoc, "FriendForm", self.tWndRefs.wndInventoryGiftFriendContainer, self)
			wndFriend:SetData(tFriend)
			wndFriend:FindChild("FriendNote"):SetTooltip(tFriend.strNote or "")
			wndFriend:FindChild("FriendNote"):Show(string.len(tFriend.strNote or "") > 0)
			wndFriend:FindChild("FriendButton"):SetText(tFriend.strCharacterName)
		end
	end
	-- TODO: Include the note as well

	self.tWndRefs.wndInventoryGiftFriendContainer:SetText(next(self.tWndRefs.wndInventoryGiftFriendContainer:GetChildren()) and "" or Apollo.GetString("AccountInventory_NoFriendsToGiftTo"))
	self.tWndRefs.wndInventoryGiftFriendContainer:ArrangeChildrenVert(0)
	self:RefreshInventoryGiftActions()
end

function AccountInventory:RefreshInventoryGiftActions()
	local wndSelectedFriend

	for idx, wndFriend in pairs(self.tWndRefs.wndInventoryGiftFriendContainer:GetChildren()) do
		if wndFriend:FindChild("FriendButton"):IsChecked() then
			wndSelectedFriend = wndFriend
			break
		end
	end

	self.tWndRefs.wndInventoryGiftFriendSelectBtn:Enable(wndSelectedFriend ~= nil)
end

function AccountInventory:OnFriendCheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryGiftActions()
end

function AccountInventory:OnFriendUncheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryGiftActions()
end

function AccountInventory:OnPendingSelectFriendGiftBtn(wndHandler, wndControl, eMouseButton)
	local tSelectedPendingData = self.tWndRefs.wndInventoryGift:GetData()

	local wndSelectedFriend
	for idx, wndFriend in pairs(self.tWndRefs.wndInventoryGiftFriendContainer:GetChildren()) do
		if wndFriend:FindChild("FriendButton"):IsChecked() then
			wndSelectedFriend = wndFriend
			break
		end
	end

	tSelectedPendingData.tFriend = wndSelectedFriend:GetData()
	self.tWndRefs.wndInventoryGiftConfirm:SetData(tSelectedPendingData)

	self:RefreshInventoryGiftConfirm()
	self.tWndRefs.wndInventoryGift:Show(false)
	self.tWndRefs.wndInventoryGiftConfirm:Show(true)
end

function AccountInventory:OnPendingGiftCancelBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryGift:Show(false)
end

function AccountInventory:RefreshEntitlements()
	self.tWndRefs.wndAccountGridContainer:DestroyChildren()
	for idx, tEntitlement in pairs(AccountItemLib.GetAccountEntitlements()) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "EntitlementsForm", self.tWndRefs.wndAccountGridContainer, self)
		wndObject:FindChild("EntitlementIcon"):SetSprite(string.len(tEntitlement.icon) > 0 and tEntitlement.icon or "IconSprites:Icon_Windows_UI_CRB_Checkmark")
		wndObject:FindChild("EntitlementName"):SetText(tEntitlement.name)
		wndObject:SetTooltip(tEntitlement.description)
		if tEntitlement.maxCount > 1 then
			wndObject:FindChild("EntitlementCount"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), tEntitlement.count, tEntitlement.maxCount))
		end
	end
	self.tWndRefs.wndAccountGridContainer:ArrangeChildrenVert(0)

	--[[
	self.tWndRefs.wndCharacterGridContainer:DestroyChildren()
	for idx, tEntitlement in pairs(AccountItemLib.GetCharacterEntitlements()) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "EntitlementsForm", self.tWndRefs.wndCharacterGridContainer, self)
		wndObject:FindChild("EntitlementIcon"):SetSprite(string.len(tEntitlement.icon) > 0 and tEntitlement.icon or "IconSprites:Icon_Windows_UI_CRB_Checkmark")
		wndObject:FindChild("EntitlementName"):SetText(tEntitlement.name)
		wndObject:SetTooltip(tEntitlement.description)
		if tEntitlement.maxCount > 1 then
			wndObject:FindChild("EntitlementCount"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), tEntitlement.count, tEntitlement.maxCount))
		end
	end
	self.tWndRefs.wndCharacterGridContainer:ArrangeChildrenVert(0)
	]]--
end

--[[
Inventory Gift Confirm
]]--

function AccountInventory:RefreshInventoryGiftConfirm()
	local tSelectedData = self.tWndRefs.wndInventoryGiftConfirm:GetData()
	self.tWndRefs.wndInventoryGiftConfirmItemContainer:DestroyChildren()

	local nIndex = tSelectedData.tData.index
	local nFriendId = tSelectedData.tFriend.nId
	local bIsGroup = tSelectedData.bIsGroup
	self.tWndRefs.wndInventoryGiftConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountGiftItem, nIndex, bIsGroup, nFriendId)

	if tSelectedData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.tWndRefs.wndInventoryGiftConfirmItemContainer, tSelectedData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.tWndRefs.wndInventoryGiftConfirmItemContainer, tSelectedData.tData)
	end

	for idx, wndCurr in pairs(self.tWndRefs.wndInventoryGiftConfirmItemContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
			wndCurr:FindChild("ItemIconGiftable"):Show(false)
		end
	end
end

function AccountInventory:OnAccountPendingItemsGifted(wndHandler, wndControl)
	self:RefreshInventory()
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryGiftConfirm:Show(false)
end

function AccountInventory:OnPendingGiftConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventoryGift:Show(true)
	self.tWndRefs.wndInventoryGiftConfirm:Show(false)
end

--[[
Inventory Gift Return Confirm
]]--

function AccountInventory:RefreshInventoryGiftReturnConfirm()
	local tSelectedData = self.tWndRefs.wndInventoryGiftReturnConfirm:GetData()
	self.tWndRefs.wndInventoryGiftReturnConfirmItemContainer:DestroyChildren()

	local nIndex = tSelectedData.tData.index
	local bIsGroup = tSelectedData.bIsGroup
	self.tWndRefs.wndInventoryGiftReturnConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountGiftItemReturn, nIndex, bIsGroup)

	if tSelectedData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.tWndRefs.wndInventoryGiftReturnConfirmItemContainer, tSelectedData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.tWndRefs.wndInventoryGiftReturnConfirmItemContainer, tSelectedData.tData)
	end

	for idx, wndCurr in pairs(self.tWndRefs.wndInventoryGiftConfirmItemContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
			wndCurr:FindChild("ItemIconGiftable"):Show(false)
		end
	end
end

function AccountInventory:OnAccountPendingItemsReturned(wndHandler, wndControl)
	self:RefreshInventory()
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryGiftReturnConfirm:Show(false)
end

function AccountInventory:OnPendingGiftReturnConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.tWndRefs.wndInventory:Show(true)
	self.tWndRefs.wndInventoryGiftReturnConfirm:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function AccountInventory:HelperCooldown(nRawTime)
	local strResult = Apollo.GetString("CRB_LessThan1M")
	local nSeconds = math.floor(nRawTime / 1000)
	local nMinutes = math.floor(nSeconds / 60)
	local nHours = math.floor(nSeconds / 3600)
	local nDays = math.floor(nSeconds / 86400)

	if nDays > 1 then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_Days"), nDays)
	elseif nHours > 1 then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_Hours"), nHours)
	elseif nMinutes > 1 then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_Minutes"), nMinutes)
	end

	return strResult
end

local AccountInventoryInst = AccountInventory:new()
AccountInventoryInst:Init()
