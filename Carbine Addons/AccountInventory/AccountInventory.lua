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

	Apollo.RegisterEventHandler("GenericEvent_ToggleAccountInventory", 	"OnAccountInventoryToggle", self)
	Apollo.RegisterEventHandler("AccountEntitlementUpdate", 			"OnAccountEntitlementUpdate", self)
	Apollo.RegisterEventHandler("AccountOperationResults", 				"OnAccountOperationResults", self) -- TODO

	Apollo.RegisterEventHandler("FriendshipRemove", 					"OnFriendshipRemove", self)

	Apollo.RegisterEventHandler("AccountPendingItemsUpdate", 			"RefreshInventory", self)
	Apollo.RegisterEventHandler("AccountInventoryUpdate", 				"RefreshInventory", self)
	Apollo.RegisterEventHandler("AchievementUpdated", 					"RefreshInventory", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 					"RefreshInventory", self)
	Apollo.RegisterEventHandler("SubZoneChanged", 						"RefreshInventory", self)
	Apollo.RegisterEventHandler("PathLevelUp", 							"RefreshInventory", self)

	-- self.nLastAccountBoundCount, from OnRestore()
end

function AccountInventory:OnAccountOperationResults(eOperationType, eResult)
	local bSuccess = eResult == CREDDExchangeLib.CodeEnumAccountOperationResult.Ok
	local strMessage = bSuccess and Apollo.GetString("MarketplaceCredd_TransactionSuccess") or Apollo.GetString(ktResultErrorCodeStrings[eResult])
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", strMessage)
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

function AccountInventory:OnAccountInventoryToggle()
	if not self.wndMain or not self.wndMain:IsValid() then
		self:SetupMainWindow()
	else
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function AccountInventory:OnAccountEntitlementUpdate()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	self:RefreshEntitlements()
end

function AccountInventory:OnClose(wndHandler, wndControl)
	if wndHandler == wndControl and self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function AccountInventory:SetupMainWindow()
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "AccountInventoryForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("AccountInv_TitleText")})
	Event_ShowTutorial(GameLib.CodeEnumTutorial.General_AccountServices)

	--Menu buttons
	self.wndInventoryBtn = self.wndMain:FindChild("InventoryBtn")
	self.wndEntitlementsBtn = self.wndMain:FindChild("EntitlementsBtn")

	--Containers
	self.wndInventory = self.wndMain:FindChild("ContentContainer:Inventory")
	self.wndInventoryGift = self.wndMain:FindChild("ContentContainer:InventoryGift")
	self.wndInventoryClaimConfirm = self.wndMain:FindChild("ContentContainer:InventoryClaimConfirm")
	self.wndInventoryTakeConfirm = self.wndMain:FindChild("ContentContainer:InventoryTakeConfirm")
	self.wndInventoryRedeemCreddConfirm = self.wndMain:FindChild("ContentContainer:InventoryRedeemCreddConfirm")
	self.wndInventoryGiftConfirm = self.wndMain:FindChild("ContentContainer:InventoryGiftConfirm")
	self.wndInventoryGiftReturnConfirm = self.wndMain:FindChild("ContentContainer:InventoryGiftReturnConfirm")
	self.wndEntitlements = self.wndMain:FindChild("ContentContainer:Entitlements")

	--Inventory
	self.wndEscrowGridContainer = self.wndMain:FindChild("ContentContainer:Inventory:EscrowGridContainer")
	self.wndInventoryGridContainer = self.wndMain:FindChild("ContentContainer:Inventory:InventoryGridContainer")
	self.wndInventoryClaimBtn = self.wndMain:FindChild("ContentContainer:Inventory:ClaimBtn")
	self.wndInventoryGiftBtn = self.wndMain:FindChild("ContentContainer:Inventory:GiftBtn")
	self.wndInventoryTakeBtn = self.wndMain:FindChild("ContentContainer:Inventory:TakeBtn")
	self.wndInventoryRedeemCreddBtn = self.wndMain:FindChild("ContentContainer:Inventory:RedeemBtn")
	self.wndInventoryReturnBtn = self.wndMain:FindChild("ContentContainer:Inventory:ReturnBtn")

	--Inventory Confirm
	self.wndPendingClaimContainer = self.wndMain:FindChild("ContentContainer:InventoryClaimConfirm:PendingClaimContainer")
	self.wndInventoryTakeConfirmContainer = self.wndMain:FindChild("ContentContainer:InventoryTakeConfirm:TakeContainer")
	self.wndInventoryCreddRedeemConfirmContainer = self.wndMain:FindChild("ContentContainer:InventoryRedeemCreddConfirm:RedeemContainer")

	--Inventory Gift
	self.wndInventoryGiftFriendContainer = self.wndMain:FindChild("ContentContainer:InventoryGift:FriendContainer")
	self.wndInventoryGiftFriendSelectBtn = self.wndMain:FindChild("ContentContainer:InventoryGift:GiftBtn")
	self.wndInventoryGiftConfirmItemContainer = self.wndMain:FindChild("ContentContainer:InventoryGiftConfirm:InventoryGiftConfirmItemContainer")
	self.wndInventoryGiftReturnConfirmItemContainer = self.wndMain:FindChild("ContentContainer:InventoryGiftReturnConfirm:InventoryGiftReturnContainer")

	--Entitlements
	self.wndAccountGridContainer = self.wndMain:FindChild("ContentContainer:Entitlements:AccountGridContainer")
	self.wndCharacterGridContainer = self.wndMain:FindChild("ContentContainer:Entitlements:CharacterGridContainer")

	self.wndMain:SetSizingMinimum(640, 480)
	self.wndMain:SetSizingMaximum(1920, 1080)
	self.wndInventoryBtn:SetCheck(true) -- Default check
	self.wndInventoryGift:Show(false, true)
	self.wndInventoryTakeConfirm:Show(false, true)
	self.wndInventoryGiftConfirm:Show(false, true)
	self.wndInventoryClaimConfirm:Show(false, true)
	self.wndInventoryGiftReturnConfirm:Show(false, true)
	self.wndInventoryRedeemCreddConfirm:Show(false, true)

	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.unitPlayer = GameLib.GetPlayerUnit()

	self:RefreshInventory()
	self:RefreshEntitlements()
end

function AccountInventory:OnInventoryCheck(wndHandler, wndControl, eMouseButton)
	self:OnInventoryUncheck()
	self.wndInventory:Show(true)
end

function AccountInventory:OnInventoryUncheck(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(false)
	self.wndInventoryGift:Show(false)
	self.wndInventoryGiftConfirm:Show(false)
	self.wndInventoryClaimConfirm:Show(false)
	self.wndInventoryTakeConfirm:Show(false)
	self.wndInventoryGiftReturnConfirm:Show(false)
end

function AccountInventory:OnEntitlementsCheck(wndHandler, wndControl, eMouseButton)
	self:OnEntitlementsUncheck()
	self.wndEntitlements:Show(true)
end

function AccountInventory:OnEntitlementsUncheck(wndHandler, wndControl, eMouseButton)
	self.wndEntitlements:Show(false)
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
	wndGroup:FindChild("ItemGiftableIcon"):Show(tPendingAccountItem.canGift)

	local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroup:FindChild("ItemContainer"), self)
	wndObject:SetData(tPendingAccountItem)
	wndObject:FindChild("Name"):SetText("") -- Done at ItemButton if single, Only used by Groups
	wndObject:FindChild("Icon"):SetSprite(bShowLock and "CRB_AMPs:spr_AMPs_LockStretch_Blue" or strIcon)

	-- Infinity icon
	local bMultiClaim = (wndParent == self.wndInventoryGridContainer and tPendingAccountItem.multiClaim) or (wndParent == self.wndEscrowGridContainer and tPendingAccountItem.multiRedeem)
	if bMultiClaim then
		wndGroup:FindChild("ItemMultiIcon"):Show(not tPendingAccountItem.cooldown)
		wndGroup:FindChild("ItemMultiText"):Show(tPendingAccountItem.cooldown and tPendingAccountItem.cooldown > 0)
		wndGroup:FindChild("ItemMultiText"):SetText(tPendingAccountItem.cooldown and self:HelperCooldown(tPendingAccountItem.cooldown) or "")
	end
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
	wndGroup:FindChild("ItemGiftableIcon"):Show(tPendingAccountItemGroup.canGift)

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

		-- Infinity icon
		if (wndParent == self.wndInventoryGridContainer and tPendingAccountItem.multiClaim) or (wndParent == self.wndEscrowGridContainer and tPendingAccountItem.multiRedeem) then
			wndGroup:FindChild("ItemMultiIcon"):Show(true)
			wndGroup:FindChild("ItemMultiIcon"):SetText(tPendingAccountItem.canClaim and Apollo.GetString("AccountInventory_InfinitySign") or self:HelperCooldown(tPendingAccountItem.cooldown))
		end
		wndGroup:FindChild("ItemIconArrangeVert"):ArrangeChildrenVert(1)

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

function AccountInventory:RefreshInventory()
	self:OnRefreshInterfaceMenuAlert() -- Happens even if wndMain hasn't loaded

	if self.wndMain == nil or not self.wndMain:IsValid() then
		return
	end

	local nInventoryGridScrollPos = self.wndInventoryGridContainer:GetVScrollPos()
	local nEscrowGridScrollPos = self.wndEscrowGridContainer:GetVScrollPos()
	self.wndInventoryGridContainer:DestroyChildren()
	self.wndEscrowGridContainer:DestroyChildren()

	-- Currencies
	for idx, tCurrData in pairs(ktCurrencies) do
		local nCurrencyCount = AccountItemLib.GetAccountCurrency(tCurrData.eType)
		if nCurrencyCount > 0 then
			local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", self.wndInventoryGridContainer, self)
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
		local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", self.wndInventoryGridContainer, self)
		wndGroup:SetData({bIsGroup = false, tData = tBoomBoxData})
		wndGroup:FindChild("ItemButton"):SetText(String_GetWeaselString(Apollo.GetString("MarketplaceCommodity_MultiItem"), nBoomBoxCount, tBoomBoxData.item:GetName()))
		wndGroup:FindChild("ItemMultiText"):Show(tBoomBoxData.cooldown and tBoomBoxData.cooldown > 0)
		wndGroup:FindChild("ItemMultiText"):SetText(tBoomBoxData.cooldown and self:HelperCooldown(tBoomBoxData.cooldown) or "")
		wndGroup:FindChild("ItemIconArrangeVert"):ArrangeChildrenVert(1)

		local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroup:FindChild("ItemContainer"), self)
		wndObject:SetData(tBoomBoxData)
		wndObject:FindChild("Name"):SetText("")
		wndObject:FindChild("Icon"):SetSprite(tBoomBoxData.item:GetIcon())
	end

	-- Separator if we added at least one
	if next(self.wndInventoryGridContainer:GetChildren()) then
		Apollo.LoadForm(self.xmlDoc, "InventoryHorizSeparator", self.wndInventoryGridContainer, self)
	end

	-- Account Bound
	for idx, tAccountItem in pairs(AccountItemLib.GetAccountItems()) do
		if not tAccountItem.item or tAccountItem.item:GetItemId() ~= knBoomBoxItemId then
			self:HelperAddPendingSingleToContainer(self.wndInventoryGridContainer, tAccountItem)
		end
	end
	self.wndInventoryGridContainer:ArrangeChildrenVert(0)
	self.wndInventoryGridContainer:SetVScrollPos(nInventoryGridScrollPos)

	-- Escrow Singles
	for idx, tPendingAccountItem in pairs(AccountItemLib.GetPendingAccountSingleItems()) do
		self:HelperAddPendingSingleToContainer(self.wndEscrowGridContainer, tPendingAccountItem)
	end

	-- Escrow Groups
	for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
		self:HelperAddPendingGroupToContainer(self.wndEscrowGridContainer, tPendingAccountItemGroup)
	end
	self.wndEscrowGridContainer:ArrangeChildrenVert(0)
	self.wndEscrowGridContainer:SetVScrollPos(nEscrowGridScrollPos)

	self:RefreshInventoryActions()
end

function AccountInventory:RefreshInventoryActions()
	local wndSelectedPendingItem
	for idx, wndPendingItem in pairs(self.wndEscrowGridContainer:GetChildren()) do
		if wndPendingItem:FindChild("ItemButton") and wndPendingItem:FindChild("ItemButton"):IsChecked() then
			wndSelectedPendingItem = wndPendingItem
			break
		end
	end

	local wndSelectedItem
	for idx, wndItem in pairs(self.wndInventoryGridContainer:GetChildren()) do
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

	self.wndInventoryClaimBtn:Enable(bPendingCanClaim)
	self.wndInventoryClaimBtn:SetData(tSelectedPendingData)

	self.wndInventoryGiftBtn:Enable(bPendingCanGift)
	self.wndInventoryGiftBtn:SetData(tSelectedPendingData)
	self.wndInventoryGiftBtn:Show(not bPendingCanReturn)

	self.wndInventoryReturnBtn:Enable(bPendingCanReturn)
	self.wndInventoryReturnBtn:SetData(tSelectedPendingData)
	self.wndInventoryReturnBtn:Show(bPendingCanReturn)

	-- Check if currency
	local bCanBeClaimed = true
	if tSelectedData and type(tSelectedData) == "table" and tSelectedData.item and tSelectedData.item:GetItemId() == knBoomBoxItemId then
		bCanBeClaimed = true
	elseif tSelectedData and type(tSelectedData) == "table" and tSelectedData.tData then
		bCanBeClaimed = tSelectedData.tData ~= keCreddType and tSelectedData.tData ~= keNameChangeType and tSelectedData.tData ~= keRealmTransferType
	elseif tSelectedData and type(tSelectedData) == "number" then
		bCanBeClaimed = tSelectedData ~= keCreddType and tSelectedData ~= keNameChangeType and tSelectedData ~= keRealmTransferType
	end

	-- It's an item, check pre-reqs
	if bCanBeClaimed and tSelectedData and tSelectedData.tData and tSelectedData.tData.prereqId > 0 then
		local tPrereqInfo = GameLib.GetPlayerUnit():GetPrereqInfo(tSelectedData.tData.prereqId)
		bCanBeClaimed = tPrereqInfo and tPrereqInfo.bIsMet and tSelectedData.tData.canClaim
	end

	self.wndInventoryTakeBtn:Enable(tSelectedData and bCanBeClaimed)
	self.wndInventoryTakeBtn:SetData(tSelectedData)
	self.wndInventoryTakeBtn:Show(tSelectedData ~= keCreddType)
	self.wndInventoryRedeemCreddBtn:Show(tSelectedData == keCreddType)
end

function AccountInventory:OnPendingInventoryItemCheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryActions()
end

function AccountInventory:OnPendingInventoryItemcUncheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryActions()
end

function AccountInventory:OnPendingClaimBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventoryClaimConfirm:SetData(wndControl:GetData())
	self:RefreshPendingConfirm()

	--self.wndInventory:Show(false)
	self.wndInventoryClaimConfirm:Show(true)
end

function AccountInventory:OnPendingGiftBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventoryGift:SetData(wndControl:GetData())
	self:RefreshInventoryGift()

	self.wndInventory:Show(false)
	self.wndInventoryGift:Show(true)
end

function AccountInventory:OnInventoryTakeBtn(wndHandler, wndControl, eMouseButton)
	local tTakeData = wndHandler:GetData()
	self.wndInventoryTakeConfirm:SetData(tTakeData)
	self.wndInventoryTakeConfirmContainer:DestroyChildren()
	self.wndInventoryTakeConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountTakeItem, tTakeData.tData.index)

	self:HelperAddPendingSingleToContainer(self.wndInventoryTakeConfirmContainer, tTakeData.tData)

	self.wndInventory:Show(false)
	self.wndInventoryTakeConfirm:Show(true)

	for idx, wndCurr in pairs(self.wndInventoryTakeConfirmContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
		end
	end
end

function AccountInventory:OnInventoryRedeemCreddBtn(wndHandler, wndControl, eMouseButton)
	local tCurrData = ktCurrencies[AccountItemLib.CodeEnumAccountCurrency.CREDD]
	self.wndInventoryRedeemCreddConfirm:SetData(tCurrData)
	self.wndInventoryCreddRedeemConfirmContainer:DestroyChildren()
	self.wndInventoryRedeemCreddConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountCreddRedeem)

	local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", self.wndInventoryCreddRedeemConfirmContainer, self)
	wndGroup:SetData(-1 * tCurrData.eType)
	wndGroup:FindChild("ItemButton"):SetText(String_GetWeaselString(Apollo.GetString(tCurrData.strNum), 1))

	local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroup:FindChild("ItemContainer"), self)
	wndObject:SetData(-1 * tCurrData.eType)
	wndObject:FindChild("Name"):SetText("")
	wndObject:FindChild("Icon"):SetSprite(tCurrData.strIcon)
	wndObject:SetTooltip(Apollo.GetString(tCurrData.strTooltip or ""))

	self.wndInventory:Show(false)
	self.wndInventoryRedeemCreddConfirm:Show(true)
end

function AccountInventory:OnPendingReturnBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventoryGiftReturnConfirm:SetData(wndControl:GetData())
	self:RefreshInventoryGiftReturnConfirm()

	self.wndInventory:Show(false)
	self.wndInventoryGiftReturnConfirm:Show(true)
end

--[[
Inventory Claim Confirm
]]--

function AccountInventory:RefreshPendingConfirm()
	local tSelectedPendingData = self.wndInventoryClaimConfirm:GetData()
	self.wndPendingClaimContainer:DestroyChildren()

	local nIndex = tSelectedPendingData.tData.index
	local bIsGroup = tSelectedPendingData.bIsGroup

	self.wndInventoryClaimConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountClaimItem, nIndex, bIsGroup)

	if tSelectedPendingData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.wndPendingClaimContainer, tSelectedPendingData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.wndPendingClaimContainer, tSelectedPendingData.tData)
	end

	for idx, wndCurr in pairs(self.wndPendingClaimContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
		end
	end
end

function AccountInventory:OnAccountPendingItemsClaimed(wndHandler, wndControl)
	self:RefreshInventory()
	self.wndInventory:Show(true)
	self.wndInventoryClaimConfirm:Show(false)
end

function AccountInventory:OnPendingConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(true)
	self.wndInventoryClaimConfirm:Show(false)
end

--[[
Inventory Take Confirm
]]--

function AccountInventory:OnAccountPendingItemTook(wndHandler, wndControl)
	self:RefreshInventory()
	self.wndInventory:Show(true)
	self.wndInventoryTakeConfirm:Show(false)
end

function AccountInventory:OnInventoryTakeConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(true)
	self.wndInventoryTakeConfirm:Show(false)
end

--[[
Inventory Credd Redeem Confirm
]]--

function AccountInventory:OnAccountCREDDRedeemed(wndHandler, wndControl)
	self:RefreshInventory()
	self.wndInventory:Show(true)
	self.wndInventoryRedeemCreddConfirm:Show(false)
end

function AccountInventory:OnInventoryCreddRedeemConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(true)
	self.wndInventoryRedeemCreddConfirm:Show(false)
end

--[[
Inventory Gift
]]--


function AccountInventory:OnFriendshipRemove()
	if not self.wndInventoryGift or not self.wndInventoryGift:IsValid() then
		return
	end
	self.wndInventoryGift:Show(false)
end

function AccountInventory:RefreshInventoryGift()
	local tSelectedPendingData = self.wndInventoryGift:GetData()

	self.wndInventoryGiftFriendContainer:DestroyChildren()
	for idx, tFriend in pairs(FriendshipLib.GetAccountList()) do
		local wndFriend = Apollo.LoadForm(self.xmlDoc, "FriendForm", self.wndInventoryGiftFriendContainer, self)
		wndFriend:SetData(tFriend)
		wndFriend:FindChild("FriendNote"):SetTooltip(tFriend.strPrivateNote or "")
		wndFriend:FindChild("FriendNote"):Show(string.len(tFriend.strPrivateNote or "") > 0)
		wndFriend:FindChild("FriendButton"):SetText(String_GetWeaselString(Apollo.GetString("AccountInventory_AccountFriendPrefix"), tFriend.strCharacterName))
	end
	for idx, tFriend in pairs(FriendshipLib.GetList()) do
		local wndFriend = Apollo.LoadForm(self.xmlDoc, "FriendForm", self.wndInventoryGiftFriendContainer, self)
		wndFriend:SetData(tFriend)
		wndFriend:FindChild("FriendNote"):SetTooltip(tFriend.strNote or "")
		wndFriend:FindChild("FriendNote"):Show(string.len(tFriend.strNote or "") > 0)
		wndFriend:FindChild("FriendButton"):SetText(tFriend.strCharacterName)
	end
	-- TODO: Include the note as well

	self.wndInventoryGiftFriendContainer:SetText(next(self.wndInventoryGiftFriendContainer:GetChildren()) and "" or Apollo.GetString("AccountInventory_NoFriendsToGiftTo"))
	self.wndInventoryGiftFriendContainer:ArrangeChildrenVert(0)
	self:RefreshInventoryGiftActions()
end

function AccountInventory:RefreshInventoryGiftActions()
	local wndSelectedFriend

	for idx, wndFriend in pairs(self.wndInventoryGiftFriendContainer:GetChildren()) do
		if wndFriend:FindChild("FriendButton"):IsChecked() then
			wndSelectedFriend = wndFriend
			break
		end
	end

	self.wndInventoryGiftFriendSelectBtn:Enable(wndSelectedFriend ~= nil)
end

function AccountInventory:OnFriendCheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryGiftActions()
end

function AccountInventory:OnFriendUncheck(wndHandler, wndControl, eMouseButton)
	self:RefreshInventoryGiftActions()
end

function AccountInventory:OnPendingSelectFriendGiftBtn(wndHandler, wndControl, eMouseButton)
	local tSelectedPendingData = self.wndInventoryGift:GetData()

	local wndSelectedFriend
	for idx, wndFriend in pairs(self.wndInventoryGiftFriendContainer:GetChildren()) do
		if wndFriend:FindChild("FriendButton"):IsChecked() then
			wndSelectedFriend = wndFriend
			break
		end
	end

	tSelectedPendingData.tFriend = wndSelectedFriend:GetData()
	self.wndInventoryGiftConfirm:SetData(tSelectedPendingData)

	self:RefreshInventoryGiftConfirm()
	self.wndInventoryGift:Show(false)
	self.wndInventoryGiftConfirm:Show(true)
end

function AccountInventory:OnPendingGiftCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(true)
	self.wndInventoryGift:Show(false)
end

function AccountInventory:RefreshEntitlements()
	self.wndAccountGridContainer:DestroyChildren()
	for idx, tEntitlement in pairs(AccountItemLib.GetAccountEntitlements()) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "EntitlementsForm", self.wndAccountGridContainer, self)
		wndObject:FindChild("EntitlementIcon"):SetSprite(string.len(tEntitlement.icon) > 0 and tEntitlement.icon or "IconSprites:Icon_Windows_UI_CRB_Checkmark")
		wndObject:FindChild("EntitlementName"):SetText(tEntitlement.name)
		wndObject:SetTooltip(tEntitlement.description)
		if tEntitlement.maxCount > 1 then
			wndObject:FindChild("EntitlementCount"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), tEntitlement.count, tEntitlement.maxCount))
		end
	end
	self.wndAccountGridContainer:ArrangeChildrenVert(0)

	--[[
	self.wndCharacterGridContainer:DestroyChildren()
	for idx, tEntitlement in pairs(AccountItemLib.GetCharacterEntitlements()) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "EntitlementsForm", self.wndCharacterGridContainer, self)
		wndObject:FindChild("EntitlementIcon"):SetSprite(string.len(tEntitlement.icon) > 0 and tEntitlement.icon or "IconSprites:Icon_Windows_UI_CRB_Checkmark")
		wndObject:FindChild("EntitlementName"):SetText(tEntitlement.name)
		wndObject:SetTooltip(tEntitlement.description)
		if tEntitlement.maxCount > 1 then
			wndObject:FindChild("EntitlementCount"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), tEntitlement.count, tEntitlement.maxCount))
		end
	end
	self.wndCharacterGridContainer:ArrangeChildrenVert(0)
	]]--
end

--[[
Inventory Gift Confirm
]]--

function AccountInventory:RefreshInventoryGiftConfirm()
	local tSelectedData = self.wndInventoryGiftConfirm:GetData()
	self.wndInventoryGiftConfirmItemContainer:DestroyChildren()

	local nIndex = tSelectedData.tData.index
	local nFriendId = tSelectedData.tFriend.nId
	local bIsGroup = tSelectedData.bIsGroup
	self.wndInventoryGiftConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountGiftItem, nIndex, bIsGroup, nFriendId)

	if tSelectedData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.wndInventoryGiftConfirmItemContainer, tSelectedData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.wndInventoryGiftConfirmItemContainer, tSelectedData.tData)
	end

	for idx, wndCurr in pairs(self.wndInventoryGiftConfirmItemContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
			wndCurr:FindChild("ItemGiftableIcon"):Show(false)
		end
	end
end

function AccountInventory:OnAccountPendingItemsGifted(wndHandler, wndControl)
	self:RefreshInventory()
	self.wndInventory:Show(true)
	self.wndInventoryGiftConfirm:Show(false)
end

function AccountInventory:OnPendingGiftConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventoryGift:Show(true)
	self.wndInventoryGiftConfirm:Show(false)
end

--[[
Inventory Gift Return Confirm
]]--

function AccountInventory:RefreshInventoryGiftReturnConfirm()
	local tSelectedData = self.wndInventoryGiftReturnConfirm:GetData()
	self.wndInventoryGiftReturnConfirmItemContainer:DestroyChildren()

	local nIndex = tSelectedData.tData.index
	local bIsGroup = tSelectedData.bIsGroup
	self.wndInventoryGiftReturnConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.AccountGiftItemReturn, nIndex, bIsGroup)

	if tSelectedData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.wndInventoryGiftReturnConfirmItemContainer, tSelectedData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.wndInventoryGiftReturnConfirmItemContainer, tSelectedData.tData)
	end

	for idx, wndCurr in pairs(self.wndInventoryGiftConfirmItemContainer:GetChildren()) do
		wndCurr:Enable(false)
		if wndCurr:FindChild("ItemButton") then
			wndCurr:FindChild("ItemButton"):ChangeArt("CRB_DEMO_WrapperSprites:btnDemo_CharInvisible")
			wndCurr:FindChild("ItemGiftableIcon"):Show(false)
		end
	end
end

function AccountInventory:OnAccountPendingItemsReturned(wndHandler, wndControl)
	self:RefreshInventory()
	self.wndInventory:Show(true)
	self.wndInventoryGiftReturnConfirm:Show(false)
end

function AccountInventory:OnPendingGiftReturnConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(true)
	self.wndInventoryGiftReturnConfirm:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function AccountInventory:HelperCooldown(nRawTime)
	local strResult = Apollo.GetString("CRB_LessThan1M")
	local nSeconds = math.floor(nRawTime / 10000)
	local nMinutes = math.floor(nSeconds / 60)
	local nHours = math.floor(nSeconds / 360)
	local nDays = math.floor(nSeconds / 8640)

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
