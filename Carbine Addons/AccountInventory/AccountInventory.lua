-----------------------------------------------------------------------------------------------
-- Client Lua Script for AccountInventory
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "AccountItemLib"
require "CREDDExchangeLib"
require "FriendshipLib"

local ktLogTypeStrings =
{
	[AccountItemLib.CodeEnumAccountOperation.ClaimPending] = "Claim Pending",
	[AccountItemLib.CodeEnumAccountOperation.ReturnPending] = "Return Pending",
	[AccountItemLib.CodeEnumAccountOperation.TakeItem] = "Take Item",
	[AccountItemLib.CodeEnumAccountOperation.GiftItem] = "Gift Item",
	[AccountItemLib.CodeEnumAccountOperation.RedeemCoupon] = "Redeem Coupon",
	[AccountItemLib.CodeEnumAccountOperation.SellCREDD] = "Sell CREDD order created",
	[AccountItemLib.CodeEnumAccountOperation.BuyCREDD] = "Buy CREDD order created",
	[AccountItemLib.CodeEnumAccountOperation.CancelCREDDOrder] = "Cancel CREDD order",
	[AccountItemLib.CodeEnumAccountOperation.SellCREDDComplete] = "Sell CREDD order filled",
	[AccountItemLib.CodeEnumAccountOperation.BuyCREDDComplete] = "Buy CREDD order filled",
}

local knSaveVersion = 0
local AccountInventory = {}

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

	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	local tSave =
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion
	}

	return tSave
end

function AccountInventory:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function AccountInventory:OnDocumentReady()
	if self.xmlDoc == nill then
		return
	end

    Apollo.RegisterSlashCommand("ai", "OnAccountInventoryOn", self)

	Apollo.RegisterEventHandler("GenericEvent_OpenAccountInventory", 	"OnAccountInventoryOn", self)
	Apollo.RegisterEventHandler("AccountPendingItemsUpdate", 			"OnAccountPendingItemsUpdate", self)
	Apollo.RegisterEventHandler("AccountInventoryUpdate", 				"OnAccountInventoryUpdate", self)
	Apollo.RegisterEventHandler("AccountEntitlementUpdate", 			"OnAccountEntitlementUpdate", self)
	Apollo.RegisterEventHandler("CREDDOperationHistoryResults", 		"OnCREDDOperationHistoryResults", self)
	Apollo.RegisterEventHandler("AccountOperationResults", 				"OnAccountOperationResults", self)
end

function AccountInventory:OnAccountInventoryOn()
	if self.wndMain == nil then
		self:SetupMainWindow()
	else
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function AccountInventory:OnAccountPendingItemsUpdate()
	self:RefreshInventory()
end

function AccountInventory:OnAccountInventoryUpdate()
	self:RefreshInventory()
end

function AccountInventory:OnAccountEntitlementUpdate()
	if self.wndMain == nil or not self.wndMain:IsValid() then
		return
	end

	self:RefreshEntitlements()
end

function AccountInventory:OnAccountOperationResults(eOperationType, eResult)

end

function AccountInventory:OnCREDDOperationHistoryResults(tHistory)
	self.wndLogRefreshBtn:Enable(true)
	self.wndLogRefreshBtn:SetCheck(false)

	self.wndLogContainer:DestroyChildren()

	for idx, tEntry in pairs(tHistory) do
		local wndEntry = Apollo.LoadForm(self.xmlDoc, "LogEntryBasicForm", self.wndLogContainer, self)
		wndEntry:FindChild("Name"):SetText(ktLogTypeStrings[tEntry.eOperation])
		wndEntry:FindChild("TimeStamp"):SetText(self:HelperLogConvertToTimeString(tEntry.nLogAge))
	end

	self.wndLogContainer:ArrangeChildrenVert(0)
end

function AccountInventory:OnClose()
	if self.wndMain ~= nil and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end

	self.wndMain = nil
end

-----------------------------------------------------------------------------------------------
-- Other Functions
-----------------------------------------------------------------------------------------------

function AccountInventory:SetupMainWindow()
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "AccountInventoryForm", nil, self)

	--Menu buttons
	self.wndInventoryBtn = self.wndMain:FindChild("MenuContainer:InventoryBtn")
	self.wndEntitlementsBtn = self.wndMain:FindChild("MenuContainer:EntitlementsBtn")
	self.wndLogsBtn = self.wndMain:FindChild("MenuContainer:LogsBtn")

	self.wndInventoryBtn:SetCheck(true) -- Default check

	--Containers
	self.wndInventory = self.wndMain:FindChild("ContentContainer:Inventory")
	self.wndInventoryGift = self.wndMain:FindChild("ContentContainer:InventoryGift")
	self.wndInventoryClaimConfirm = self.wndMain:FindChild("ContentContainer:InventoryClaimConfirm")
	self.wndInventoryTakeConfirm = self.wndMain:FindChild("ContentContainer:InventoryTakeConfirm")
	self.wndInventoryGiftConfirm = self.wndMain:FindChild("ContentContainer:InventoryGiftConfirm")
	self.wndInventoryGiftReturnConfirm = self.wndMain:FindChild("ContentContainer:InventoryGiftReturnConfirm")
	self.wndEntitlements = self.wndMain:FindChild("ContentContainer:Entitlements")
	self.wndLog = self.wndMain:FindChild("ContentContainer:Log")

	self.wndInventoryGift:Show(false)
	self.wndInventoryGiftConfirm:Show(false)
	self.wndInventoryClaimConfirm:Show(false)
	self.wndInventoryTakeConfirm:Show(false)
	self.wndInventoryGiftReturnConfirm:Show(false)
	
	--Currency
	self.wndClaimedCredd = self.wndMain:FindChild("ContentContainer:Inventory:CurrencyContainer:ClaimedCredd")
	self.wndClaimedTransfers = self.wndMain:FindChild("ContentContainer:Inventory:CurrencyContainer:ClaimedTransfers")

	--Inventory
	self.wndEscrowGridContainer = self.wndMain:FindChild("ContentContainer:Inventory:EscrowGridContainer")
	self.wndInventoryGridContainer = self.wndMain:FindChild("ContentContainer:Inventory:InventoryGridContainer")
	self.wndInventoryClaimBtn = self.wndMain:FindChild("ContentContainer:Inventory:ClaimBtn")
	self.wndInventoryGiftBtn = self.wndMain:FindChild("ContentContainer:Inventory:GiftBtn")
	self.wndInventoryTakeBtn = self.wndMain:FindChild("ContentContainer:Inventory:TakeBtn")
	self.wndInventoryReturnBtn = self.wndMain:FindChild("ContentContainer:Inventory:ReturnBtn")

	--Inventory Claim Confirm
	self.wndPendingClaimContainer = self.wndMain:FindChild("ContentContainer:InventoryClaimConfirm:PendingClaimContainer")

	--Inventory Take Confirm
	self.wndInventoryTakeConfirmContainer = self.wndMain:FindChild("ContentContainer:InventoryTakeConfirm:TakeContainer")

	--Inventory Gift
	self.wndInventoryGiftFriendContainer = self.wndMain:FindChild("ContentContainer:InventoryGift:FriendContainer")
	self.wndInventoryGiftFriendSelectBtn = self.wndMain:FindChild("ContentContainer:InventoryGift:GiftBtn")

	--Inventory Gift Confirm
	self.wndInventoryGiftConfirmItemContainer = self.wndMain:FindChild("ContentContainer:InventoryGiftConfirm:InventoryGiftConfirmItemContainer")

	--Inventory Gift Return Confirm
	self.wndInventoryGiftReturnConfirmItemContainer = self.wndMain:FindChild("ContentContainer:InventoryGiftReturnConfirm:ItemContainer")

	--Entitlements
	self.wndAccountGridContainer = self.wndMain:FindChild("ContentContainer:Entitlements:AccountGridContainer")
	self.wndCharacterGridContainer = self.wndMain:FindChild("ContentContainer:Entitlements:CharacterGridContainer")

	--Log
	self.wndLogContainer = self.wndMain:FindChild("ContentContainer:Log:LogContainer")
	self.wndLogRefreshBtn = self.wndMain:FindChild("ContentContainer:Log:RefreshLogBtn")

	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self:RefreshCurrency()
	self:RefreshInventory()
	self:RefreshEntitlements()
	CREDDExchangeLib.GetCREDDHistory()
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

function AccountInventory:OnLogCheck(wndHandler, wndControl, eMouseButton)
	self:OnLogUncheck()
	self.wndLog:Show(true)
end

function AccountInventory:OnLogUncheck(wndHandler, wndControl, eMouseButton)
	self.wndLog:Show(false)
end

function AccountInventory:RefreshCurrency()
	local nClaimedCredd = AccountItemLib.GetAccountCurrency(AccountItemLib.CodeEnumAccountCurrency.CREDD)
	self.wndClaimedCredd:SetText("Credd: "..nClaimedCredd)

	local nClaimedTransfers = AccountItemLib.GetAccountCurrency(AccountItemLib.CodeEnumAccountCurrency.RealmTransfer)
	self.wndClaimedTransfers:SetText("Transfers: "..nClaimedTransfers)
end

--[[
Inventory
]]--

function AccountInventory:HelperAddPendingSingleToContainer(wndContainer, tPendingAccountItem)
	local strName = "Error"
	local strIcon = tPendingAccountItem.icon
	local strDesc = tPendingAccountItem.description or ""

	local ktAccountCurrencyToString =
	{
		[AccountItemLib.CodeEnumAccountCurrency.CREDD] 			= "C.R.E.D.D.",
		[AccountItemLib.CodeEnumAccountCurrency.NameChange] 	= "Name Change",
		[AccountItemLib.CodeEnumAccountCurrency.RealmTransfer]	= "Realm Transfer",
	}

	if tPendingAccountItem.item ~= nil then
		strName = tPendingAccountItem.item:GetName()
		strIcon = tPendingAccountItem.item:GetIcon()
	elseif tPendingAccountItem.entitlement ~= nil then
		strName = tPendingAccountItem.entitlement.name
		strIcon = tPendingAccountItem.entitlement.icon or strIcon
	elseif tPendingAccountItem.accountCurrency ~= nil then
		strName = ktAccountCurrencyToString[tPendingAccountItem.accountCurrency.accountCurrencyEnum] or "Unknown Currency"
	end

	local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", wndContainer, self)
	wndGroup:SetData({bIsGroup=false, tData = tPendingAccountItem})

	local wndGroupContaner = wndGroup:FindChild("ItemContainer")
	local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroupContaner, self)
	wndObject:SetData(tPendingAccountItem)

	wndObject:FindChild("Name"):SetText(strName)
	wndObject:FindChild("Details"):SetText(strDesc)
	wndObject:FindChild("Icon"):SetSprite(strIcon)

	local nHeight = wndGroupContaner:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndGroupContaner:GetAnchorOffsets()
	wndGroupContaner:SetAnchorOffsets(nLeft, nTop, nRight, nTop+nHeight)

	local nLeft, nTop, nRight, nBottom = wndGroup:GetAnchorOffsets()
	wndGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop+nHeight+11)
end

function AccountInventory:HelperAddPendingGroupToContainer(wndContainer, tPendingAccountItemGroup)
	local wndGroup = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupForm", wndContainer, self)
	wndGroup:SetData({bIsGroup=true, tData = tPendingAccountItemGroup})

	local wndGroupContaner = wndGroup:FindChild("ItemContainer")
	for idx, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "InventoryPendingGroupItemForm", wndGroupContaner, self)
		wndObject:SetData(tPendingAccountItem)

		if tPendingAccountItem.item ~= nil then
			wndObject:FindChild("Name"):SetText(tPendingAccountItem.item:GetName())
			wndObject:FindChild("Icon"):SetSprite(tPendingAccountItem.item:GetIcon())
		elseif tPendingAccountItem.entitlement ~= nil then
			wndObject:FindChild("Name"):SetText(tPendingAccountItem.entitlement.name)
			wndObject:FindChild("Icon"):SetSprite(tPendingAccountItem.entitlement.icon)
		else
			wndObject:FindChild("Name"):SetText("Error")
		end
	end
	local nHeight = wndGroupContaner:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndGroupContaner:GetAnchorOffsets()
	wndGroupContaner:SetAnchorOffsets(nLeft, nTop, nRight, nTop+nHeight)

	local nLeft, nTop, nRight, nBottom = wndGroup:GetAnchorOffsets()
	wndGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop+nHeight+11)
end

function AccountInventory:RefreshInventory()
	if self.wndMain == nil or not self.wndMain:IsValid() then
		return
	end

	self.wndEscrowGridContainer:DestroyChildren()
	for idx, tPendingAccountItem in pairs(AccountItemLib.GetPendingAccountSingleItems()) do
		self:HelperAddPendingSingleToContainer(self.wndEscrowGridContainer, tPendingAccountItem)
	end

	for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
		self:HelperAddPendingGroupToContainer(self.wndEscrowGridContainer, tPendingAccountItemGroup)
	end
	self.wndEscrowGridContainer:ArrangeChildrenVert(0)

	self.wndInventoryGridContainer:DestroyChildren()
	for idx, tAccountItem in pairs(AccountItemLib.GetAccountItems()) do
		self:HelperAddPendingSingleToContainer(self.wndInventoryGridContainer, tAccountItem)
	end
	self.wndInventoryGridContainer:ArrangeChildrenVert(0)

	self:RefreshInventoryActions()
end

function AccountInventory:RefreshInventoryActions()
	local wndSelectedPendingItem
	for idx, wndPendingItem in pairs(self.wndEscrowGridContainer:GetChildren()) do
		if wndPendingItem:FindChild("Button"):IsChecked() then
			wndSelectedPendingItem = wndPendingItem
			break
		end
	end
	local tSelectedPendingData = wndSelectedPendingItem ~= nil and wndSelectedPendingItem:GetData() or nil

	local wndSelectedItem
	for idx, wndItem in pairs(self.wndInventoryGridContainer:GetChildren()) do
		if wndItem:FindChild("Button"):IsChecked() then
			wndSelectedItem = wndItem
			break
		end
	end
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

	self.wndInventoryTakeBtn:Enable(tSelectedData ~= nil and tSelectedData.tData.canClaim)
	self.wndInventoryTakeBtn:SetData(tSelectedData)
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
	self.wndInventoryTakeConfirm:SetData(wndControl:GetData())
	self:RefreshInventoryTakeConfirm()

	self.wndInventory:Show(false)
	self.wndInventoryTakeConfirm:Show(true)
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

	if tSelectedPendingData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.wndPendingClaimContainer, tSelectedPendingData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.wndPendingClaimContainer, tSelectedPendingData.tData)
	end
end

function AccountInventory:OnPendingConfirmBtn(wndHandler, wndControl, eMouseButton)
	local tSelectedPendingData = self.wndInventoryClaimConfirm:GetData()

	if tSelectedPendingData.bIsGroup then
		AccountItemLib.ClaimPendingItemGroup(tSelectedPendingData.tData.index)
	else
		AccountItemLib.ClaimPendingSingleItem(tSelectedPendingData.tData.index)
	end

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

function AccountInventory:RefreshInventoryTakeConfirm()
	local tSelectedData = self.wndInventoryTakeConfirm:GetData()
	self.wndInventoryTakeConfirmContainer:DestroyChildren()

	self:HelperAddPendingSingleToContainer(self.wndInventoryTakeConfirmContainer, tSelectedData.tData)
end

function AccountInventory:OnInventoryTakeConfirmBtn(wndHandler, wndControl, eMouseButton)
	local tSelectedData = self.wndInventoryTakeConfirm:GetData()

	AccountItemLib.TakeAccountItem(tSelectedData.tData.index)

	self:RefreshInventory()
	self.wndInventory:Show(true)
	self.wndInventoryTakeConfirm:Show(false)
end

function AccountInventory:OnInventoryTakeConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(true)
	self.wndInventoryTakeConfirm:Show(false)
end

--[[
Inventory Gift
]]--

function AccountInventory:RefreshInventoryGift()
	local tSelectedPendingData = self.wndInventoryGift:GetData()

	self.wndInventoryGiftFriendContainer:DestroyChildren()
	for idx, tFriend in pairs(FriendshipLib.GetAccountList()) do
		local wndFriend = Apollo.LoadForm(self.xmlDoc, "FriendForm", self.wndInventoryGiftFriendContainer, self)
		wndFriend:SetData(tFriend)
		wndFriend:FindChild("Button"):SetText(tFriend.strCharacterName)
	end
	for idx, tFriend in pairs(FriendshipLib.GetList()) do
		local wndFriend = Apollo.LoadForm(self.xmlDoc, "FriendForm", self.wndInventoryGiftFriendContainer, self)
		wndFriend:SetData(tFriend)
		wndFriend:FindChild("Button"):SetText(tFriend.strCharacterName)
	end

	self.wndInventoryGiftFriendContainer:ArrangeChildrenVert(0)
	self:RefreshInventoryGiftActions()
end

function AccountInventory:RefreshInventoryGiftActions()
	local wndSelectedFriend

	for idx, wndFriend in pairs(self.wndInventoryGiftFriendContainer:GetChildren()) do
		if wndFriend:FindChild("Button"):IsChecked() then
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
		if wndFriend:FindChild("Button"):IsChecked() then
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

--[[
Inventory Gift Confirm
]]--

function AccountInventory:RefreshInventoryGiftConfirm()
	local tSelectedData = self.wndInventoryGiftConfirm:GetData()
	self.wndInventoryGiftConfirmItemContainer:DestroyChildren()

	if tSelectedData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.wndInventoryGiftConfirmItemContainer, tSelectedData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.wndInventoryGiftConfirmItemContainer, tSelectedData.tData)
	end
end

function AccountInventory:OnPendingGiftConfirmBtn(wndHandler, wndControl, eMouseButton)
	local tSelectedPendingData = self.wndInventoryGiftConfirm:GetData()

	if tSelectedPendingData.bIsGroup and tSelectedPendingData.tFriend.bFriend then
		AccountItemLib.GiftPendingItemGroupToCharacter(tSelectedPendingData.tData.index, tSelectedPendingData.tFriend.nId)
	elseif tSelectedPendingData.tFriend.bFriend then
		AccountItemLib.GiftPendingItemToCharacter(tSelectedPendingData.tData.index, tSelectedPendingData.tFriend.nId)
	elseif tSelectedPendingData.bIsGroup then
		AccountItemLib.GiftPendingItemGroupToAccount(tSelectedPendingData.tData.index, tSelectedPendingData.tFriend.nId)
	else
		AccountItemLib.GiftPendingItemToAccount(tSelectedPendingData.tData.index, tSelectedPendingData.tFriend.nId)
	end

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

	if tSelectedData.bIsGroup then
		self:HelperAddPendingGroupToContainer(self.wndInventoryGiftReturnConfirmItemContainer, tSelectedData.tData)
	else
		self:HelperAddPendingSingleToContainer(self.wndInventoryGiftReturnConfirmItemContainer, tSelectedData.tData)
	end
end

function AccountInventory:OnPendingGiftReturnConfirmBtn(wndHandler, wndControl, eMouseButton)
	local tSelectedData = self.wndInventoryGiftReturnConfirm:GetData()

	if tSelectedData.bIsGroup then
		AccountItemLib.ReturnPendingItemGroup(tSelectedData.tData.index)
	else
		AccountItemLib.ReturnPendingSingleItem(tSelectedData.tData.index)
	end

	self:RefreshInventory()
	self.wndInventory:Show(true)
	self.wndInventoryGiftReturnConfirm:Show(false)
end

function AccountInventory:OnPendingGiftReturnConfirmCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndInventory:Show(true)
	self.wndInventoryGiftReturnConfirm:Show(false)
end

--[[
Entitlements
]]--

function AccountInventory:RefreshEntitlements()
	self.wndAccountGridContainer:DestroyChildren()
	for idx, tEntitlement in pairs(AccountItemLib.GetAccountEntitlements()) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "EntitlementsForm", self.wndAccountGridContainer, self)
		wndObject:FindChild("Icon"):SetSprite(tEntitlement.icon)
		wndObject:FindChild("Name"):SetText(tEntitlement.name)
		wndObject:FindChild("Button"):SetTooltip(tEntitlement.description)
		if tEntitlement.maxCount > 1 then
			wndObject:FindChild("Count"):SetText(tEntitlement.count.."/"..tEntitlement.maxCount)
		end
	end
	self.wndAccountGridContainer:ArrangeChildrenVert(0)

	self.wndCharacterGridContainer:DestroyChildren()
	for idx, tEntitlement in pairs(AccountItemLib.GetCharacterEntitlements()) do
		local wndObject = Apollo.LoadForm(self.xmlDoc, "EntitlementsForm", self.wndCharacterGridContainer, self)
		wndObject:FindChild("Icon"):SetSprite(tEntitlement.icon)
		wndObject:FindChild("Name"):SetText(tEntitlement.name)
		wndObject:FindChild("Button"):SetTooltip(tEntitlement.description)
		if tEntitlement.maxCount > 1 then
			wndObject:FindChild("Count"):SetText(tEntitlement.count.."/"..tEntitlement.maxCount)
		end
	end
	self.wndCharacterGridContainer:ArrangeChildrenVert(0)
end

--[[
Log
]]--

function AccountInventory:OnRefreshLogsBtn(wndHandler, wndControl, eMouseButton)
	CREDDExchangeLib.GetCREDDHistory()
	self.wndLogRefreshBtn:Enable(false)
end









function AccountInventory:HelperLogConvertToTimeString(nDays)
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


local AccountInventoryInst = AccountInventory:new()
AccountInventoryInst:Init()
