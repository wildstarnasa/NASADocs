---------------------------------------------------------------------------------------------
-- Client Lua Script for GuildBank
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Money"

local GuildBank = {}

local kstrFontLog 				= "CRB_InterfaceMedium"
local knNumBankTabs				= 5
local knMaxBankSlots 			= 128
local knMaxBankTabNameLength 	= 20
local knVeryLargeNumber 		= 2147483640
local knMaxTransactionLimit 	= 2000000000 -- 2000 plat
local ktWithdrawLimit 			= {} -- Dynamic. But currently: 0, 1, 2, 5, 10, 25, 50, -1
local ktWhichPerksAreGuildTabs 	= -- TODO super hardcoded
{
	[GuildLib.Perk.BankTab1] 	= 1,
	[GuildLib.Perk.BankTab2] 	= 2,
	[GuildLib.Perk.BankTab3] 	= 3,
	[GuildLib.Perk.BankTab4] 	= 4,
	[GuildLib.Perk.BankTab5] 	= 5,
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

--[[ For reference, Permissions also attached to GetRanks()
bDisband, bRankCreate, bChangeRankPermissions, bSpendInfluence, bRankRename, bVote, bChangeMemberRank
bInvite, bKick, bEmblemAndStandard, bMemberChat, bCouncilChat, bBankTabRename, bNeighborhood
]]--

function GuildBank:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWndRefs = {}

    return o
end

function GuildBank:Init()
    Apollo.RegisterAddon(self)
end

function GuildBank:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildBank.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function GuildBank:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GuildBankerOpen", 			"GuildInitialize", self) -- notification you opened the bank.
	Apollo.RegisterEventHandler("GuildBankTab", 			"OnGuildBankTab", self) -- noficiation that a guild bank tab is loaded.
	Apollo.RegisterEventHandler("GuildBankItem", 			"OnGuildBankItem", self) -- noficiation of a change to a specific item that exists on a tab.
	Apollo.RegisterEventHandler("GuildRankChange", 			"OnGuildRankChange", self) -- notification that the ranks of the guild have changed.
	Apollo.RegisterEventHandler("GuildBankTabCount", 		"OnGuildBankTabCount", self)
	Apollo.RegisterEventHandler("GuildPerkUnlocked", 		"OnGuildBankTabCount", self)
	Apollo.RegisterEventHandler("GuildBankTabRename", 		"OnGuildBankTabRename", self) -- a bank tab was renamed.
	Apollo.RegisterEventHandler("GuildInfluenceAndMoney", 	"OnGuildInfluenceAndMoney", self) -- When influence or money is updated
	Apollo.RegisterEventHandler("GuildBankerClose", 		"OnCloseBank", self)
	Apollo.RegisterEventHandler("GuildBankLog", 			"OnGuildBankLog", self) -- When a bank log comes in
	Apollo.RegisterEventHandler("GuildChange", 				"OnGuildChange", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 		"OnPlayerCurrencyChanged", self)
	Apollo.RegisterTimerHandler("GuildCashTransSuccessText", 	"OnGuildCashTransSuccessText", self)

	self.tTabPerks = {}
end

function GuildBank:GuildInitialize()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end

	self.tWndRefs.wndSplit = nil

	local guildSelected = nil
	local nMyRank = nil
	local tMyRankData = nil
	
	for idx, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_Guild then
			nMyRank = guildCurr:GetMyRank()
			tMyRankData = guildCurr:GetRanks()[nMyRank]

			guildSelected = guildCurr
			break
		end
	end

	if not guildSelected or not nMyRank or not tMyRankData then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, Apollo.GetString("Guild_YouAreNotInAGuild"), "" )
		
		Event_CancelGuildBank()
		Event_CancelWarpartyBank()
		return
	end

	self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildBankForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.tWndRefs.wndMain, strName = Apollo.GetString("GuildBank_Title")})
	
	self.tWndRefs.wndMain:SetData(guildSelected)
	self.tWndRefs.wndMain:FindChild("PermissionsMain"):SetData(nMyRank)
	self.tWndRefs.wndMain:FindChild("BankTabBtnMgmt"):Enable(tMyRankData and (tMyRankData.bBankTabRename or tMyRankData.bSpendInfluence))
	
	self:Initialize(guildSelected)
end

function GuildBank:Reinitialize(guildToInit)

	if guildToInit ~= nil then
		if guildToInit:GetType() ~= GuildLib.GuildType_WarParty then
			local strCheckedTab
			for idx, wndTab in pairs(self.tWndRefs.wndMain:FindChild("BGTabsContainer"):GetChildren()) do
				if wndTab:IsChecked() then
					strCheckedTab = wndTab:GetName()
					break
				end
			end

            self:GuildInitialize()

			if strCheckedTab and strCheckedTab ~= "" then
				for idx, wndTab in pairs(self.tWndRefs.wndMain:FindChild("BGTabsContainer"):GetChildren()) do
					wndTab:SetCheck(wndTab:GetName() == strCheckedTab, true)
				end
			end

			if strCheckedTab == "BankTabBtnCash" then
				self:OnBankTabBtnCash()
			elseif strCheckedTab == "BankTabBtnVault" then
				self:OnBankTabBtnVault()
			elseif strCheckedTab == "BankTabBtnPermissions" then
				self:OnBankTabBtnPermissions()
			elseif strCheckedTab == "BankTabBtnMgmt" then
				self:OnBankTabBtnMgmt()
			elseif strCheckedTab == "BankTabBtnLog" then
				self:OnBankTabBtnLog()
			end
		end
	elseif self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end
end

function GuildBank:Initialize(guildOwner)
	local tGuildPerks = guildOwner:GetPerks()
	local tMyRankData = guildOwner:GetRanks()[guildOwner:GetMyRank()]

	self:HelperLoadTabPerks(guildOwner)

	local nBankTabCount = guildOwner:GetBankTabCount()
	for idx = 1, knNumBankTabs do
		local wndBankTab = self.tWndRefs.wndMain:FindChild("BankTabBtn"..idx)
		local wndBankTabLog = self.tWndRefs.wndMain:FindChild("BankTabLogBtn"..idx)
		local strBankTabName = guildOwner:GetBankTabName(idx)
		if not strBankTabName or string.len(strBankTabName) == 0 then
			strBankTabName = Apollo.GetString("GuildBank_BankTab")
		end
		wndBankTab:SetText(strBankTabName)
		wndBankTabLog:SetText(strBankTabName)

		wndBankTab:SetData(idx)
		wndBankTabLog:SetData(idx)

		wndBankTab:Enable(idx <= nBankTabCount)
		wndBankTabLog:Enable(idx <= nBankTabCount and tMyRankData and tMyRankData.bBankTabLog)
	end

	for idx, nLimit in pairs(GuildLib.GetBankWithdrawLimits()) do
		ktWithdrawLimit[idx] = nLimit
	end

	self.tWndRefs.wndMain:FindChild("MoneyTabLogBtn"):SetData(-1)
	self.tWndRefs.wndMain:FindChild("RepairTabLogBtn"):SetData(-2)

	self.strTransferType = nil
	self.tCurrentDragData = nil

	self.tWndRefs.wndMain:FindChild("BankTabBtnLog"):Enable(true)
	self.tWndRefs.wndMain:FindChild("BankTabBtnVault"):Enable(true)
	self.tWndRefs.wndMain:FindChild("BankTabBtnPermissions"):Enable(true)
	self.tWndRefs.wndMain:FindChild("PermissionsMoneyCashWindow"):SetAmountLimit(knMaxTransactionLimit)
	self.tWndRefs.wndMain:FindChild("PermissionsRepairCashWindow"):SetAmountLimit(knMaxTransactionLimit)
	self.tWndRefs.wndMain:FindChild("PlayerWithdrawAmountWindow"):SetAmountLimit(knMaxTransactionLimit)
	self.tWndRefs.wndMain:FindChild("GuildCashInteractEditCashWindow"):SetAmountLimit(knMaxTransactionLimit)
	self.tWndRefs.wndMain:FindChild("BankTabBtnCash"):AttachWindow(self.tWndRefs.wndMain:FindChild("CashScreenMain"))
	self.tWndRefs.wndMain:FindChild("BankTabBtnLog"):AttachWindow(self.tWndRefs.wndMain:FindChild("BankLogScreenMain"))
	self.tWndRefs.wndMain:FindChild("BankTabBtnMgmt"):AttachWindow(self.tWndRefs.wndMain:FindChild("LeaderScreenMain"))
	self.tWndRefs.wndMain:FindChild("BankTabBtnVault"):AttachWindow(self.tWndRefs.wndMain:FindChild("BankScreenMain")) -- TEMP
	self.tWndRefs.wndMain:FindChild("BankTabBtnPermissions"):AttachWindow(self.tWndRefs.wndMain:FindChild("PermissionsMain"))

	self:OnBankTabBtnCash()
end

function GuildBank:OnCloseBank()
	if self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
	end
	
		self.tWndRefs = {}
	end

function GuildBank:OnCloseBtnSignal(wndHandler, wndControl, eMouseButton)
	self:OnCloseBank()

	Event_CancelGuildBank()
	Event_CancelWarpartyBank()
end

-----------------------------------------------------------------------------------------------
-- Vault Items
-----------------------------------------------------------------------------------------------

function GuildBank:OnBankTabBtnVault(wndHandler, wndControl)
	self:HelperUpdateHeaderText(Apollo.GetString("GuildBank_Title"))

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local nGuildBankTabNum = guildOwner:GetBankTabCount()

	if nGuildBankTabNum ~= 0 then

		for idx, wndCurr in pairs(self.tWndRefs.wndMain:FindChild("TopRowBankTabItems"):GetChildren()) do
			if idx == 1 then
				self:OnBankTabCheck(wndCurr, wndCurr)
			end
			wndCurr:SetCheck(idx == 1)
		end
	else
		self.tWndRefs.wndMain:FindChild("wndNoBankTabsMessage"):SetText(Apollo.GetString("Bank_NoBankTabsMessage"))
		self.tWndRefs.wndMain:FindChild("wndNoBankTabsMessage"):Show(true)
		self.tWndRefs.wndMain:FindChild("bnkManagementButtonNoTab"):Show(true)
	end

end

function GuildBank:OnBankTabMouseEnter(wndHandler, wndControl)
	if self.tCurrentDragData and wndHandler:IsEnabled() then
		for idx, wndCurr in pairs(self.tWndRefs.wndMain:FindChild("TopRowBankTabItems"):GetChildren()) do
			wndCurr:SetCheck(wndCurr == wndHandler)
		end
		self:OnBankTabCheck(wndHandler, wndControl)
	end
end

function GuildBank:OnBankTabCheck(wndHandler, wndControl)

	local guildOwner = self.tWndRefs.wndMain:GetData()

	local nGuildBankTabNum = guildOwner:GetBankTabCount()

	if nGuildBankTabNum ~= 0 then
		self.tWndRefs.wndMain:FindChild("MainBankNoVisibility"):Show(false)
		guildOwner:OpenBankTab(wndHandler:GetData()) -- Will call OnGuildBankTab
	else
		self.tWndRefs.wndMain:FindChild("wndNoBankTabsMessage"):SetText(Apollo.GetString("Bank_NoBankTabsMessage"))
		self.tWndRefs.wndMain:FindChild("wndNoBankTabsMessage"):Show(true)
		self.tWndRefs.wndMain:FindChild("bnkManagementButtonNoTab"):Show(true)
	end
end

function GuildBank:OnBankTabUncheck(wndHandler, wndControl)

	local guildOwner = self.tWndRefs.wndMain:GetData()
	if guildOwner then
		guildOwner:CloseBankTab()
	end

	self.tWndRefs.wndMain:FindChild("SharedBGMainFrame"):Show(true)
	self.tWndRefs.wndMain:FindChild("MainBankNoVisibility"):Show(false)
	self.tWndRefs.wndMain:FindChild("wndNoBankTabsMessage"):Show(false)
	self.tWndRefs.wndMain:FindChild("bnkManagementButtonNoTab"):Show(false)
	self:HelperEmptyMainBankScrollbar(false)
end

function GuildBank:OnGuildBankTab(guildOwner, nTab)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	local tRanksTable = guildOwner:GetRanks()
	local tMyRankData = tRanksTable[guildOwner:GetMyRank()]
	local tMyRankDataPermissions = tMyRankData.arBankTab[nTab]

	self.tWndRefs.wndMain:FindChild("BankScreenMain"):Show(true)
	self.tWndRefs.wndMain:FindChild("SharedBGMainFrame"):Show(false)
	if not self.tCurrentDragData then
		self:DoFlashAnimation()
	end

	-- See if Visible
	if not tMyRankData or not tMyRankDataPermissions or not tMyRankDataPermissions.bVisible then
		self:HelperUpdateHeaderText()
		self:HelperEmptyMainBankScrollbar(false)
		self.tWndRefs.wndMain:FindChild("MainBankNoVisibility"):Show(true)
		return
	end

	-- Withdraw Limit
	local nWithdrawalAmount = ktWithdrawLimit[tMyRankDataPermissions.idWithdrawLimit]

	local strHeaderText = String_GetWeaselString(Apollo.GetString("GuildBank_TitleWithTabName"), guildOwner:GetBankTabName(nTab))
	if nWithdrawalAmount ~= -1 then
		local nAmountWithdrawnToday = guildOwner:GetBankTabItemWithdrawnToday(nTab)
		local tWithdrawalInfo =
		{
			["name"] = Apollo.GetString("GuildBank_Withdrawal"),
			["count"] = math.max(0, nWithdrawalAmount - nAmountWithdrawnToday)
		}

		strHeaderText = String_GetWeaselString(Apollo.GetString("GuildBank_LimitedWithdrawalsCounter"), strHeaderText, tWithdrawalInfo)
	end
	self:HelperUpdateHeaderText(strHeaderText)

	-- All Slots
	self:HelperEmptyMainBankScrollbar(true)
	self.tWndRefs.wndMain:FindChild("MainBankScrollbar"):SetData(nTab)
	for idx, tCurrData in ipairs(guildOwner:GetBankTab(nTab)) do -- This doesn't hit the server, but we can still use GuildBankItem for updating afterwards
		self:HelperDrawBankItem(tCurrData.itemInSlot, nTab, tCurrData.nIndex)
	end
	self.tWndRefs.wndMain:FindChild("MainBankScrollbar"):ArrangeChildrenTiles(0)
end

function GuildBank:HelperDrawBankItem(itemDrawing, nTab, nInventorySlot)
	if not self.tWndRefs.tBankItemSlots or not self.tWndRefs.tBankItemSlots[nInventorySlot] then
		return
	end

	local wndBankSlot = self.tWndRefs.tBankItemSlots[nInventorySlot]
	wndBankSlot:FindChild("BankItemIcon"):SetData(itemDrawing)
	wndBankSlot:FindChild("BankItemIcon"):SetSprite(itemDrawing:GetIcon())
	self:HelperBuildItemTooltip(wndBankSlot:FindChild("BankItemIcon"), itemDrawing)

	local nStackCount = itemDrawing:GetStackCount()
	if nStackCount ~= 1 then
		wndBankSlot:FindChild("BankItemIcon"):SetText(nStackCount)
	end
end

function GuildBank:OnGuildBankItem(guildOwner, nTab, nInventorySlot, itemUpdated, bRemoved)
	if not self.tWndRefs.tBankItemSlots or
	   not self.tWndRefs.tBankItemSlots[nInventorySlot] or
	   not self.tWndRefs.wndMain or
	   not self.tWndRefs.wndMain:IsValid() or
	   nTab ~= self.tWndRefs.wndMain:FindChild("MainBankScrollbar"):GetData() then

		return
	end -- Viewing same tab page

	if bRemoved then
		local wndItem = self.tWndRefs.tBankItemSlots[nInventorySlot]
		wndItem:FindChild("BankItemIcon"):SetData(nil)
		wndItem:FindChild("BankItemIcon"):SetText("")
		wndItem:FindChild("BankItemIcon"):SetSprite("")
		wndItem:FindChild("BankItemIcon"):SetTooltip("")
	else -- Changed or Added
		self:HelperDrawBankItem(itemUpdated, nTab, nInventorySlot)
	end
end

function GuildBank:OnBankItemMouseButtonDown(wndHandler, wndControl, eMouseButton, bDoubleClick)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and self.tWndRefs.wndMain:GetData() and wndHandler:GetData() then
		local guildOwner = self.tWndRefs.wndMain:GetData()
		local itemSelected = wndHandler:GetData() -- wndHandler is BankItemIcon
		guildOwner:MoveBankItemToInventory(itemSelected)
		Event_FireGenericEvent("GuildBank_ShowPersonalInventory")
	elseif eMouseButton == GameLib.CodeEnumInputMouse.Left and Apollo.IsShiftKeyDown() then
		local itemSelected = wndHandler:GetData()
		self:CreateSplitWindow(itemSelected, wndHandler)
	elseif eMouseButton == GameLib.CodeEnumInputMouse.Left then
		self:OnBankItemBeginDragDrop(wndHandler, wndControl)
	end
end

function GuildBank:OnBankItemBeginDragDrop(wndHandler, wndControl, nTransferStackCount) -- BankItemIcon
	if wndHandler ~= wndControl then
		return false
	end

	if nTransferStackCount == nil then
		nTransferStackCount  = 0 -- 0 is default for the whole stack.
	end

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local itemSelected = wndHandler:GetData()
	if itemSelected then
		self.strTransferType = guildOwner:BeginBankItemTransfer(itemSelected, nTransferStackCount) -- returns nil if item is bogus or "guild" can't do bank operations. (it is a circle or something)
		if self.strTransferType ~= nil then
			Apollo.BeginDragDrop(wndControl, self.strTransferType, itemSelected:GetIcon(), 0)
		end
	end
	self.tCurrentDragData = itemSelected

	-- TODO Verify deposit permissions
end

function GuildBank:OnBankItemQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType)
	if wndHandler ~= wndControl then
		return Apollo.DragDropQueryResult.PassOn
	elseif strType == "DDGuildBankItem" or strType == "DDBagItem" then -- Should change to an enum?
		return Apollo.DragDropQueryResult.Accept
	else
		return Apollo.DragDropQueryResult.Ignore
	end
end

function GuildBank:OnBankItemDragDropClear() -- Any UI
	self:OnBankItemDragDropCancel()
end

function GuildBank:OnBankItemDragDropEnd() -- Any UI
	self:OnBankItemDragDropCancel()
end

function GuildBank:OnBankItemDragDropCancel() -- Also called from UI
	self.tCurrentDragData = nil
end

function GuildBank:OnBankItemEndDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nBagSlot) -- Bank Icon
	if not wndHandler or not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() or wndSource == wndHandler then
		self:OnBankItemDragDropCancel()
		return false
	end

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local nDestinationSlot = wndControl:GetParent():GetData() -- TODO refactor. BankItemIcon -> BankItem -> nIndex
	local nDestinationTab = self.tWndRefs.wndMain:FindChild("MainBankScrollbar"):GetData()

	if strType == self.strTransferType then -- be sure to check, it could be a dd operation from a warparty or something.
		guildOwner:EndBankItemTransfer(nDestinationTab, nDestinationSlot)

	elseif strType == "DDBagItem" and nBagSlot then
		local itemDepositing = self.tWndRefs.wndMain:FindChild("HiddenBagWindow"):GetItem(nBagSlot)
		if itemDepositing ~= nil then
			local nQuantity = 0 -- TODO, split stack functionality  (0 is default for the whole stack)
			guildOwner:BeginBankItemTransfer(itemDepositing, nQuantity)
			guildOwner:EndBankItemTransfer(nDestinationTab, nDestinationSlot)
		end
	end

	self:OnBankItemDragDropCancel()
	return false
end

-----------------------------------------------------------------------------------------------
-- Split Window
-----------------------------------------------------------------------------------------------

function GuildBank:CreateSplitWindow(item, wndParent)
	if not item then return end

	if self.tWndRefs.wndSplit and self.tWndRefs.wndSplit:IsValid() then
		self.tWndRefs.wndSplit:Destroy()
	end

	self.tWndRefs.wndSplit = Apollo.LoadForm(self.xmlDoc, "SplitStackContainer", wndParent, self)

	local nStackCount = item:GetStackCount()
	if nStackCount < 2 then
		self.tWndRefs.wndSplit:Show(false)
		return
	end
	self.tWndRefs.wndSplit:SetData(wndParent)
	self.tWndRefs.wndSplit:FindChild("SplitValue"):SetValue(1)
	self.tWndRefs.wndSplit:FindChild("SplitValue"):SetMinMax(1, nStackCount - 1)
	self.tWndRefs.wndSplit:Show(true)
end

function GuildBank:OnSplitStackCloseClick()
	if self.tWndRefs.wndSplit == nil or not self.tWndRefs.wndSplit:IsValid() then
		return
	end

	self.tWndRefs.wndSplit:Show(false)
	self.tWndRefs.wndSplit:Destroy()
	self.tWndRefs.wndSplit = nil
end

function GuildBank:OnSplitStackConfirm(wndHandler, wndCtrl)
	local wndParent = self.tWndRefs.wndSplit:GetData()
	self.tWndRefs.wndSplit:Show(false)
	self:OnBankItemBeginDragDrop(wndParent, wndParent, self.tWndRefs.wndSplit:FindChild("SplitValue"):GetValue())
end

-----------------------------------------------------------------------------------------------
-- Cash
-----------------------------------------------------------------------------------------------

function GuildBank:OnBankTabBtnCash()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	self.tWndRefs.wndMain:SetFocus()
	self:HelperUpdateHeaderText(String_GetWeaselString(Apollo.GetString("GuildBank_TitleWithTabName"), Apollo.GetString("GuildBank_MoneyAppend")))

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local wndParent = self.tWndRefs.wndMain:FindChild("CashScreenMain")

	local nTransactionAmount = wndParent:FindChild("GuildCashInteractEditCashWindow"):GetAmount()
	wndParent:FindChild("GuildCashDeposit"):Enable(nTransactionAmount > 0)
	wndParent:FindChild("GuildCashWithdraw"):Enable(nTransactionAmount > 0)
	wndParent:FindChild("GuildCashInteractEditHelpText"):Show(nTransactionAmount == 0)

	wndParent:FindChild("GuildCashAmountWindow"):SetAmount(guildOwner:GetMoney())
	wndParent:FindChild("GuildInfluenceAmount"):SetText(String_GetWeaselString(Apollo.GetString("GuildBank_GuildInfluence"), guildOwner:GetInfluence()))

	local tMyRankData = guildOwner:GetRanks()[guildOwner:GetMyRank()]
	local nAmountWithdrawnToday = guildOwner:GetBankMoneyWithdrawnToday()
	local nMyWithdrawalToday = nAmountWithdrawnToday:GetAmount()
	local nMyWithdrawLimit = tMyRankData.monBankWithdrawLimit:GetAmount()

	wndParent:FindChild("PlayerWithdrawCant"):Show(nMyWithdrawLimit == 0)
	wndParent:FindChild("PlayerWithdrawNoLimit"):Show(nMyWithdrawLimit >= knVeryLargeNumber) -- There might actually be a limit > 2100 (e.g. 6000 plat), but we'll just show No Limit
	wndParent:FindChild("PlayerWithdrawAmountWindow"):Show(nMyWithdrawLimit < knVeryLargeNumber and nMyWithdrawLimit ~= 0)

	local strTooltip = ""
	if nMyWithdrawLimit >= knVeryLargeNumber then
		strTooltip = String_GetWeaselString(Apollo.GetString("GuildBank_NoMoneyLimit"), nMyWithdrawalToday, tMyRankData.strName)
	elseif nMyWithdrawLimit == 0 then
		strTooltip = String_GetWeaselString(Apollo.GetString("GuildBank_RankCantTakeMoney"), tMyRankData.strName)
	else
		strTooltip = String_GetWeaselString(Apollo.GetString("GuildBank_CurrentMoneyWithdrawn"), nMyWithdrawalToday, nMyWithdrawLimit, tMyRankData.strName)
	end
	wndParent:FindChild("PlayerWithdrawAmountLabel"):SetTooltip(strTooltip)

	local nMyWithdrawlAmountLeft = (nMyWithdrawLimit - nMyWithdrawalToday)
	local nWithdrawlAmount = self.tWndRefs.wndMain:FindChild("GuildCashInteractEditCashWindow"):GetCurrency()

	if self.nWithdrawlAmount then
		nMyWithdrawlAmountLeft =  nMyWithdrawlAmountLeft - self.nWithdrawlAmount
		self.nWithdrawlAmount = 0;
	end

	if nMyWithdrawlAmountLeft < 0 then
		nMyWithdrawlAmountLeft = 0
	end

	wndParent:FindChild("PlayerWithdrawAmountWindow"):SetAmount(nMyWithdrawlAmountLeft)
	wndParent:FindChild("PlayerDepositAvailableWindow"):SetAmount(GameLib.GetPlayerCurrency())
end

function GuildBank:OnGuildCashDeposit(wndHandler, wndControl)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local guildOwner = self.tWndRefs.wndMain:GetData()
	guildOwner:DepositMoney(self.tWndRefs.wndMain:FindChild("GuildCashInteractEditCashWindow"):GetCurrency())
	self.tWndRefs.wndMain:FindChild("GuildCashInteractEditCashWindow"):SetAmount(0, true)
	self:OnBankTabBtnCash()
	wndHandler:SetFocus()
end

function GuildBank:OnGuildCashWithdraw(wndHandler, wndControl)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local guildOwner = self.tWndRefs.wndMain:GetData()
	guildOwner:WithdrawMoney(self.tWndRefs.wndMain:FindChild("GuildCashInteractEditCashWindow"):GetCurrency())
	self.nWithdrawlAmount = self.tWndRefs.wndMain:FindChild("GuildCashInteractEditCashWindow"):GetAmount()
	self.tWndRefs.wndMain:FindChild("GuildCashInteractEditCashWindow"):SetAmount(0, true)
	self:OnBankTabBtnCash()
	wndHandler:SetFocus()
end

function GuildBank:OnGuildCashInteractEditCashWindow(wndHandler, wndControl) -- GuildCashInteractEditCashWindow
	local nTransactionAmount = wndHandler:GetAmount()
	local wndParent = self.tWndRefs.wndMain:FindChild("CashScreenMain")
	wndParent:FindChild("GuildCashDeposit"):Enable(nTransactionAmount > 0)
	wndParent:FindChild("GuildCashWithdraw"):Enable(nTransactionAmount > 0)
	wndParent:FindChild("GuildCashInteractEditHelpText"):Show(nTransactionAmount == 0)
end

function GuildBank:OnPlayerCurrencyChanged()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() and self.tWndRefs.wndMain:FindChild("CashScreenMain"):IsVisible() then
		self.tWndRefs.wndMain:FindChild("CashScreenMain"):FindChild("PlayerDepositAvailableWindow"):SetAmount(GameLib.GetPlayerCurrency())
	end
end

function GuildBank:OnGuildInfluenceAndMoney(guildOwner, nInfluence, monCash)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:FindChild("CashScreenMain"):IsVisible() or self.tWndRefs.wndMain:GetData() ~= guildOwner then
		return
	end
	self.tWndRefs.wndMain:FindChild("GuildCashAmountWindow"):SetAmount(guildOwner:GetMoney())
	self.tWndRefs.wndMain:FindChild("GuildInfluenceAmount"):SetText(String_GetWeaselString(Apollo.GetString("GuildBank_GuildInfluence"), guildOwner:GetInfluence()))
	self.tWndRefs.wndMain:FindChild("GuildCashTransSuccessText"):Show(true)
	Apollo.CreateTimer("GuildCashTransSuccessText", 1.5, false)
end

function GuildBank:OnGuildCashTransSuccessText()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:FindChild("GuildCashTransSuccessText") then
		return
	end
	self.tWndRefs.wndMain:FindChild("GuildCashTransSuccessText"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Tab Permissions
-----------------------------------------------------------------------------------------------

function GuildBank:OnBankTabBtnPermissions(wndHandler, wndControl)
	self:DrawTabPermissions()
end

function GuildBank:OnPermissionsResetBtn(wndHandler, wndControl)
	self:DrawTabPermissions()
end

function GuildBank:OnGuildRankChange() -- C++ Event
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() or not self.tWndRefs.wndMain:FindChild("PermissionsMain"):IsShown() then
		return
	end
	self:DrawTabPermissions()
end

function GuildBank:OnPermissionsMoneyCashWindow(wndHandler, wndControl) -- PermissionsMoneyCashWindow
	self.tWndRefs.wndMain:FindChild("PermissionsSaveBtn"):Enable(true)
	if not wndHandler:GetAmount() or wndHandler:GetAmount() == 0 then
		wndHandler:GetParent():SetText(Apollo.GetString("GuildBank_CantWithdrawMoney")) -- PermissionsMoneyBG
	else
		wndHandler:GetParent():SetText("") -- PermissionsMoneyBG
	end
end

function GuildBank:OnPermissionsRepairCashWindow(wndHandler, wndControl) -- PermissionsRepairCashWindow
	self.tWndRefs.wndMain:FindChild("PermissionsSaveBtn"):Enable(true)
	if not wndHandler:GetAmount() or wndHandler:GetAmount() == 0 then
		wndHandler:GetParent():SetText(Apollo.GetString("GuildBank_NoRepairAllowed")) -- PermissionsRepairBG
	else
		wndHandler:GetParent():SetText("") -- PermissionsRepairBG
	end
end

function GuildBank:OnPermissionsCurrentBtnLeftRight(wndHandler, wndControl)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local tRankTable = guildOwner:GetRanks()
	local nPreviousRank = self.tWndRefs.wndMain:FindChild("PermissionsMain"):GetData()

	if wndHandler:GetName() == "PermissionsCurrentRightBtn" then
		for iRank, tRankData in pairs(tRankTable) do
			if iRank > nPreviousRank and tRankData.bValid then
				self.tWndRefs.wndMain:FindChild("PermissionsMain"):SetData(iRank)
				break
			end
		end
	else
		for iRank = #tRankTable, 1, -1 do
			local tRankData = tRankTable[iRank]
			if iRank < nPreviousRank and tRankData.bValid then
				self.tWndRefs.wndMain:FindChild("PermissionsMain"):SetData(iRank)
				break
			end
		end
	end

	self:DrawTabPermissions()
end

function GuildBank:DrawTabPermissions()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	self.tWndRefs.wndMain:SetFocus()
	self:HelperUpdateHeaderText(String_GetWeaselString(Apollo.GetString("GuildBank_TitleWithTabName"), Apollo.GetString("GuildBank_PermissionsLabel")))

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local wndParent = self.tWndRefs.wndMain:FindChild("PermissionsMain")
	local nGuildRank = self.tWndRefs.wndMain:FindChild("PermissionsMain"):GetData()
	local tRanksTable = guildOwner:GetRanks()
	local nTabCount = guildOwner:GetBankTabCount()
	local tCurrRankData = tRanksTable[nGuildRank]
	local bCanEditRanks = tRanksTable[guildOwner:GetMyRank()].bChangeRankPermissions

	if not tCurrRankData then
		return
	end

	local nWithdrawMoneyLimit = tCurrRankData.monBankWithdrawLimit:GetAmount()
	wndParent:FindChild("PermissionsSaveBtn"):Enable(false)
	wndParent:FindChild("PermissionsSaveBtn"):Show(bCanEditRanks)
	wndParent:FindChild("PermissionsResetBtn"):Show(bCanEditRanks)
	wndParent:FindChild("PermissionsCurrentLeftBtn"):Show(nGuildRank > 1)
	wndParent:FindChild("PermissionsCurrentRightBtn"):Show(nGuildRank < 10)
	wndParent:FindChild("PermissionsMoneyCashWindow"):Enable(bCanEditRanks)
	wndParent:FindChild("PermissionsMoneyCashWindow"):SetData(nWithdrawMoneyLimit)
	wndParent:FindChild("PermissionsMoneyCashWindow"):SetAmount(nWithdrawMoneyLimit)
	local nRepairLimit = tCurrRankData.monBankRepairLimit:GetAmount()
	wndParent:FindChild("PermissionsRepairCashWindow"):Enable(bCanEditRanks)
	wndParent:FindChild("PermissionsRepairCashWindow"):SetData(nRepairLimit)
	wndParent:FindChild("PermissionsRepairCashWindow"):SetAmount(nRepairLimit)
	wndParent:FindChild("PermissionsCurrentRankText"):SetText(String_GetWeaselString(Apollo.GetString("GuildBank_PermissionsAppend"), tCurrRankData.strName))

	if not nWithdrawMoneyLimit or nWithdrawMoneyLimit == 0 then
		wndParent:FindChild("PermissionsMoneyBG"):SetText(Apollo.GetString("GuildBank_CantWithdrawMoney"))
	else
		wndParent:FindChild("PermissionsMoneyBG"):SetText("")
	end

	if not nRepairLimit or nRepairLimit == 0 then
		wndParent:FindChild("PermissionsRepairBG"):SetText(Apollo.GetString("GuildBank_NoRepairAllowed"))
	else
		wndParent:FindChild("PermissionsRepairBG"):SetText("")
	end
	-- Tabs
	wndParent:FindChild("PermissionsGridRowItems"):DestroyChildren()
	for idx = 1, nTabCount do
		self:BuildPermissionIndividualTab(wndParent, guildOwner, bCanEditRanks, tCurrRankData, idx)
	end
	wndParent:FindChild("PermissionsGridRowItems"):ArrangeChildrenTiles(1)
end

function GuildBank:BuildPermissionIndividualTab(wndParent, guildOwner, bCanEditRanks, tCurrRankData, nBankTab)
	local wndTab = Apollo.LoadForm(self.xmlDoc, "PermissionsGridRow", wndParent:FindChild("PermissionsGridRowItems"), self)
	local idWithdrawLimit = tCurrRankData.arBankTab[nBankTab].idWithdrawLimit
	local strBankTabName = guildOwner:GetBankTabName(nBankTab)
	local strSpriteVisible = "ClientSprites:LootCloseBox"
	local strSpriteDeposit = "ClientSprites:LootCloseBox"
	local strWithdraw = ktWithdrawLimit[idWithdrawLimit]
	if tCurrRankData.arBankTab[nBankTab].bVisible then
		strSpriteVisible = "ClientSprites:Icon_Windows_UI_CRB_Checkmark"
	end
	if tCurrRankData.arBankTab[nBankTab].bDeposit then
		strSpriteDeposit = "ClientSprites:Icon_Windows_UI_CRB_Checkmark"
	end
	if not strBankTabName or string.len(strBankTabName) == 0 then
		strBankTabName = Apollo.GetString("GuildBank_BankTab")
	end
	if strWithdraw == -1 then
		strWithdraw = Apollo.GetString("GuildBank_WithdrawAll")
	end

	wndTab:FindChild("PermissionGridBtnVisible"):SetData(wndTab)
	wndTab:FindChild("PermissionGridBtnDeposit"):SetData(wndTab)
	wndTab:FindChild("PermissionGridBtnSubWithdraw"):SetData(wndTab)
	wndTab:FindChild("PermissionGridBtnPlusWithdraw"):SetData(wndTab)
	wndTab:FindChild("PermissionGridTextWithdraw"):SetData(idWithdrawLimit)
	wndTab:FindChild("PermissionGridIconVisible"):SetData(tCurrRankData.arBankTab[nBankTab].bVisible)
	wndTab:FindChild("PermissionGridIconDeposit"):SetData(tCurrRankData.arBankTab[nBankTab].bDeposit)

	wndTab:FindChild("PermissionsGridRowText"):SetText(strBankTabName)
	wndTab:FindChild("PermissionGridTextWithdraw"):SetText(strWithdraw)
	wndTab:FindChild("PermissionGridIconVisible"):SetSprite(strSpriteVisible)
	wndTab:FindChild("PermissionGridIconDeposit"):SetSprite(strSpriteDeposit)

	wndTab:FindChild("PermissionGridBtnVisible"):Show(bCanEditRanks)
	wndTab:FindChild("PermissionGridBtnDeposit"):Show(bCanEditRanks)
	wndTab:FindChild("PermissionGridBtnSubWithdraw"):Show(bCanEditRanks)
	wndTab:FindChild("PermissionGridBtnPlusWithdraw"):Show(bCanEditRanks)

	-- Button is visible if leader, disabled if at max range
	wndTab:FindChild("PermissionGridBtnSubWithdraw"):Enable(bCanEditRanks and idWithdrawLimit > 1)
	wndTab:FindChild("PermissionGridBtnPlusWithdraw"):Enable(bCanEditRanks and idWithdrawLimit < #ktWithdrawLimit)
end

function GuildBank:OnPermissionGridBtnWithdrawPlusSub(wndHandler, wndControl) -- PermissionGridBtnPlusWithdraw or PermissionGridBtnSubWithdraw
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local wndTab = wndHandler:GetData()
	local nPreviousValue = wndTab:FindChild("PermissionGridTextWithdraw"):GetData()
	local nNewValue = nPreviousValue - 1
	if wndHandler:GetName() == "PermissionGridBtnPlusWithdraw" then
		nNewValue = nPreviousValue + 1
	end

	local strResult = ktWithdrawLimit[nNewValue]
	if strResult == -1 then
		strResult = Apollo.GetString("GuildBank_WithdrawAll")
	end

	wndTab:FindChild("PermissionGridTextWithdraw"):SetText(strResult)
	wndTab:FindChild("PermissionGridTextWithdraw"):SetData(nNewValue)
	wndTab:FindChild("PermissionGridBtnSubWithdraw"):Enable(nNewValue > 1)
	wndTab:FindChild("PermissionGridBtnPlusWithdraw"):Enable(nNewValue < #ktWithdrawLimit)
	self.tWndRefs.wndMain:FindChild("PermissionsSaveBtn"):Enable(true)
end

function GuildBank:OnPermissionGridBtnVisibleDeposit(wndHandler, wndControl) -- PermissionGridIconVisible or PermissionGridIconDeposit
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local wndTab = wndHandler:GetData()
	local strIcon = "PermissionGridIconVisible"
	if wndHandler:GetName() == "PermissionGridBtnDeposit" then -- NAME HACK
		strIcon = "PermissionGridIconDeposit"
	end

	if wndTab:FindChild(strIcon):GetData() then
		wndTab:FindChild(strIcon):SetSprite("ClientSprites:LootCloseBox")
	else
		wndTab:FindChild(strIcon):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Checkmark")
	end
	wndTab:FindChild(strIcon):SetData(not wndTab:FindChild(strIcon):GetData())
	self.tWndRefs.wndMain:FindChild("PermissionsSaveBtn"):Enable(true)
end

function GuildBank:OnPermissionsSaveBtn(wndHandler, wndControl)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then return end

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local wndParent = self.tWndRefs.wndMain:FindChild("PermissionsMain")
	local nGuildRank = wndParent:GetData()
	local tPermissions = {}

	local nTabCount = 0
	for iTab, wndTab in pairs(self.tWndRefs.wndMain:FindChild("PermissionsGridRowItems"):GetChildren()) do
		tPermissions[iTab] =
		{
			bAuthenticator = false, -- TODO
			bVisible = wndTab:FindChild("PermissionGridIconVisible"):GetData(),
			bDeposit = wndTab:FindChild("PermissionGridIconDeposit"):GetData(),
			idWithdrawLimit = wndTab:FindChild("PermissionGridTextWithdraw"):GetData(),
		}

		nTabCount = nTab
	end

	-- isnt iTab out of scope?
	guildOwner:SetBankTabPermissions(nGuildRank, iTab, tPermissions) -- Calls OnGuildRankChange

	if wndParent:FindChild("PermissionsMoneyCashWindow"):GetData() ~= wndParent:FindChild("PermissionsMoneyCashWindow"):GetAmount() then
		guildOwner:SetRankBankMoneyLimit(nGuildRank, wndParent:FindChild("PermissionsMoneyCashWindow"):GetCurrency() or 0) -- Calls OnGuildRankChange
	end

	if wndParent:FindChild("PermissionsRepairCashWindow"):GetData() ~= wndParent:FindChild("PermissionsRepairCashWindow"):GetAmount() then
		guildOwner:SetRankBankRepairLimit(nGuildRank, wndParent:FindChild("PermissionsRepairCashWindow"):GetCurrency() or 0) -- Calls OnGuildRankChange
	end
end

-----------------------------------------------------------------------------------------------
-- Log (Temp)
-----------------------------------------------------------------------------------------------

function GuildBank:OnBankTabBtnLog(wndHandler, wndControl)
	self:HelperUpdateHeaderText(String_GetWeaselString(Apollo.GetString("GuildBank_TitleWithTabName"), Apollo.GetString("GuildBank_Log")))
	self.tWndRefs.wndMain:FindChild("SharedBGMainFrame"):Show(false)

	self.tWndRefs.wndMain:FindChild("MoneyTabLogBtn"):SetCheck(true)
	self.tWndRefs.wndMain:FindChild("RepairTabLogBtn"):SetCheck(false)
	self.tWndRefs.wndMain:FindChild("BankTabLogBtn1"):SetCheck(false)
	self.tWndRefs.wndMain:FindChild("BankTabLogBtn2"):SetCheck(false)
	self.tWndRefs.wndMain:FindChild("BankTabLogBtn3"):SetCheck(false)
	self.tWndRefs.wndMain:FindChild("BankTabLogBtn4"):SetCheck(false)
	self.tWndRefs.wndMain:FindChild("BankTabLogBtn5"):SetCheck(false)

	local guildOwner = self.tWndRefs.wndMain:GetData()
	guildOwner:RequestMoneyLogs()
end

function GuildBank:OnGuildBankLog(guildOwner, arLogs)
	local xml = XmlDoc.new()
	local crText = ApolloColor.new("UI_TextMetalBody")

	for idx, tLog in ipairs(arLogs) do
		local strBeginning = self:HelperConvertToTime(tLog.fOccuredAgoDays)..": "..tLog.strName..": "
		xml:AddLine(strBeginning, ApolloColor.new("UI_TextMetalBodyHighlight"), kstrFontLog, "Left")

		if tLog.uMoneyDeposit then
			xml:AppendText(Apollo.GetString("CRB_GuildBankMoneyDepositLog") .. " ", crText, kstrFontLog)
			tLog.uMoneyDeposit:AppendToTooltip(xml)
		elseif tLog.uMoneyWithdraw then
			xml:AppendText(Apollo.GetString("CRB_GuildBankMoneyWithdrewLog") .. " ", crText, kstrFontLog)
			strText = tLog.uMoneyWithdraw:AppendToTooltip(xml)
		elseif tLog.uRepairWithdraw then
			xml:AppendText(Apollo.GetString("CRB_GuildBankMoneyWithdrewLog") .. " ", crText, kstrFontLog)
			strText = tLog.uRepairWithdraw:AppendToTooltip(xml)
		elseif tLog.uItemDeposit then
			xml:AppendText(Apollo.GetString("CRB_GuildBankMoneyDepositLog") .. " ", crText, kstrFontLog)
			xml:AppendText("[" .. tLog.uItemDeposit:GetName() .. "]", karEvalColors[tLog.uItemDeposit:GetItemQuality()], kstrFontLog)
			if tLog.nStack then
				xml:AppendText("x" .. tLog.nStack, crText, kstrFontLog)
			end
		elseif tLog.uItemWithdraw then
			xml:AppendText(Apollo.GetString("CRB_GuildBankMoneyWithdrewLog") .. " ", crText, kstrFontLog)
			xml:AppendText("[" .. tLog.uItemWithdraw:GetName() .. "]", karEvalColors[tLog.uItemWithdraw:GetItemQuality()], kstrFontLog)
			if tLog.nStack then
				xml:AppendText("x" .. tLog.nStack, crText, kstrFontLog)
			end
		end
	end

	self.tWndRefs.wndMain:FindChild("BankLogText"):SetDoc(xml)
end

function GuildBank:OnBankLogTabCheck(wndHandler, wndControl)
	self.tWndRefs.wndMain:FindChild("BankLogText"):SetText("")

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local eTab = wndHandler:GetData()
	if eTab == -1 then
		guildOwner:RequestMoneyLogs() -- Get the money logs
	elseif eTab == -2 then
		guildOwner:RequestRepairLogs() -- Get the repair logs
	else
		guildOwner:RequestBankLogs(eTab) -- Get the bank logs for that tab
	end
end

-----------------------------------------------------------------------------------------------
-- Leader Permissions
-----------------------------------------------------------------------------------------------

function GuildBank:OnBankTabBtnMgmt()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	self.tWndRefs.wndMain:SetFocus()
	self:HelperUpdateHeaderText(String_GetWeaselString(Apollo.GetString("GuildBank_TitleWithTabName"), Apollo.GetString("GuildBank_Management")))

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local wndParent = self.tWndRefs.wndMain:FindChild("LeaderScreenMain")
	local nGuildInfluence = guildOwner:GetInfluence()
	wndParent:FindChild("MgmtBankTabInfluenceText"):SetText(String_GetWeaselString(Apollo.GetString("GuildBank_GuildInfluence"), nGuildInfluence))

	self:HelperLoadTabPerks(guildOwner)

	-- Tabs
	wndParent:FindChild("MgmtBankTabContainer"):DestroyChildren()

	local nTabCounter = 1
	if guildOwner:GetType() ~= GuildLib.GuildType_WarParty then
		local tMyRankData = guildOwner:GetRanks()[guildOwner:GetMyRank()]

		local bBankTabRename = tMyRankData and tMyRankData.bBankTabRename
		local bSpendInfluence = tMyRankData and tMyRankData.bSpendInfluence

		for idx, tCurrPerk in pairs(self.tTabPerks) do
			-- if ktWhichPerksAreGuildTabs[tCurrPerk.nId] then -- GOTCHA: Don't use idx or nTabCounter, as they will not line up
				local wndCurr = nil
				local strBankTabName = guildOwner:GetBankTabName(nTabCounter)
				if tCurrPerk.bIsUnlocked then
					if not strBankTabName or string.len(strBankTabName) == 0 then
						strBankTabName = Apollo.GetString("GuildBank_BankTab")
					end
					wndCurr = Apollo.LoadForm(self.xmlDoc, "LeaderOptionsTabItemOld", wndParent:FindChild("MgmtBankTabContainer"), self)
					wndCurr:SetData(nTabCounter)
					wndCurr:FindChild("LeaderOptionsEditBox"):SetData(wndCurr)
					wndCurr:FindChild("LeaderOptionsEditBox"):SetText(strBankTabName)
					wndCurr:FindChild("LeaderOptionsEditBox"):Enable(bBankTabRename)
					wndCurr:FindChild("LeaderOptionsTabRenameBtn"):SetData(wndCurr)
					wndCurr:FindChild("LeaderOptionsTabRenameBtn"):Enable(false)
				else
					if not strBankTabName or string.len(strBankTabName) == 0 then
						strBankTabName =  Apollo.GetString("GuildBank_LockedTab")
					end
					wndCurr = Apollo.LoadForm(self.xmlDoc, "LeaderOptionsTabItemNew", wndParent:FindChild("MgmtBankTabContainer"), self)
					wndCurr:SetData(nTabCounter)
					wndCurr:FindChild("LeaderOptionsSubText"):SetText(String_GetWeaselString(Apollo.GetString("GuildBank_GuildInfluence"), tCurrPerk.nPurchaseInfluenceCost))
					wndCurr:FindChild("LeaderOptionsTabName"):SetText(strBankTabName)
					wndCurr:FindChild("LeaderOptionsTabBuyBtn"):SetData(tCurrPerk.idPerk)
					wndCurr:FindChild("LeaderOptionsTabBuyBtn"):Enable(bSpendInfluence and tCurrPerk.nPurchaseInfluenceCost <= nGuildInfluence)
				end
				nTabCounter = nTabCounter + 1
			-- end
		end
	end
	wndParent:FindChild("MgmtBankTabContainer"):ArrangeChildrenVert(0)
end

function GuildBank:OnBankTabBtnMgmtAssist()
	self.tWndRefs.wndMain:FindChild("BankTabBtnMgmt"):SetCheck(true)
	self:OnBankTabBtnMgmt()
	self.tWndRefs.wndMain:FindChild("BankTabBtnVault"):SetCheck(false)
	self:OnBankTabUncheck()
end

function GuildBank:OnLeaderOptionsEditBoxChanged(wndHandler, wndControl)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local wndParent = wndHandler:GetData()
	local strInput = wndHandler:GetText()
	if string.len(strInput) > knMaxBankTabNameLength then
		wndHandler:SetText(string.sub(strInput, 0, knMaxBankTabNameLength))
		wndHandler:SetSel(knMaxBankTabNameLength)
	end

	if strInput and string.len(strInput) > 0 then
		local bIsTextValid = GameLib.IsTextValid(strInput, GameLib.CodeEnumUserText.GuildBankTabName, GameLib.CodeEnumUserTextFilterClass.Strict)
		wndParent:FindChild("LeaderOptionsTabRenameBtn"):Enable(bIsTextValid)
		wndParent:FindChild("LeaderOptionsRenameValidAlert"):Show(not bIsTextValid)
	else
		wndParent:FindChild("LeaderOptionsTabRenameBtn"):Enable(false)
	end
end

function GuildBank:OnLeaderOptionsTabRenameBtn(wndHandler, wndControl)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local guildOwner = self.tWndRefs.wndMain:GetData()
	local wndParent = wndHandler:GetData()
	guildOwner:RenameBankTab(wndParent:GetData(), wndParent:FindChild("LeaderOptionsEditBox"):GetText()) -- Fires GuildBankTabRename
end

function GuildBank:OnGuildBankTabRename(guildOwner)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end
	self:Reinitialize(guildOwner)
end

function GuildBank:OnLeaderOptionsTabBuyBtn(wndHandler, wndControl)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end
	local guildOwner = self.tWndRefs.wndMain:GetData()
	guildOwner:PurchasePerk(wndHandler:GetData()) -- Will call GuildBankTabCount
end

function GuildBank:OnGuildBankTabCount()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end
	local guildOwner = self.tWndRefs.wndMain:GetData()
	self:Reinitialize(guildOwner)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GuildBank:HelperEmptyMainBankScrollbar(bShow)
	local wndMainBankScrollbar = self.tWndRefs.wndMain:FindChild("MainBankScrollbar")

	if not self.tWndRefs.tBankItemSlots then
		self.tWndRefs.tBankItemSlots = {}
	end

	for idx = 1, knMaxBankSlots do
		if not self.tWndRefs.tBankItemSlots[idx] then
			self.tWndRefs.tBankItemSlots[idx] = Apollo.LoadForm(self.xmlDoc, "BankItem", wndMainBankScrollbar, self)
		end
		local wndItem = self.tWndRefs.tBankItemSlots[idx]
		wndItem:SetData(idx)
		local wndBankItemIcon = wndItem:FindChild("BankItemIcon")
		if wndBankItemIcon ~= nil then
			wndBankItemIcon:SetData(nil)
			wndBankItemIcon:SetText("")
			wndBankItemIcon:SetSprite("")
		end
		wndItem:Show(bShow)
	end
	self.tWndRefs.wndMain:FindChild("MainBankScrollbar"):RecalculateContentExtents()
end

function GuildBank:HelperUpdateHeaderText(strNewHeader)
	local strFinalHeader = strNewHeader
	if not strNewHeader or string.len(strNewHeader) == 0 then
		strFinalHeader = Apollo.GetString("GuildBank_Title")
	end
	self.tWndRefs.wndMain:FindChild("BGHeaderText"):SetText(strFinalHeader)
end

function GuildBank:DoFlashAnimation()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	self.tWndRefs.wndMain:FindChild("FlashAnimation"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
end

function GuildBank:HelperBuildItemTooltip(wndArg, itemCurrent)
	wndArg:SetTooltipDoc(nil)
	local itemEquipped = itemCurrent:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurrent, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
end

function GuildBank:HelperLoadTabPerks(guildOwner)
	local tGuildPerks = guildOwner:GetPerks()
	for idx, tCurrPerk in pairs(tGuildPerks) do
		if ktWhichPerksAreGuildTabs[tCurrPerk.idPerk] then
			self.tTabPerks[ktWhichPerksAreGuildTabs[tCurrPerk.idPerk]] = tCurrPerk
		end
	end
end

function GuildBank:HelperConvertToTime(nDays)
	tTimeData =
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

	return String_GetWeaselString(Apollo.GetString("CRB_TimeOffline"), tTimeData)
end

function GuildBank:OnGuildChange()
	for idx, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_Guild then
			return
		end
	end

	self:OnCloseBank()
end

local GuildBankInst = GuildBank:new()
GuildBankInst:Init()
