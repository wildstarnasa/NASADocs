-----------------------------------------------------------------------------------------------
-- Client Lua Script for WarpartyBank
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Money"

local WarpartyBank = {}

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

local knUsePermissionAll		= 8 -- TODO super hard coded hack
local knUsePermissionNone		= 1 -- TODO super hard coded hack

--[[ Permissions also attached to GetRanks()
bDisband, bRankCreate, bChangeRankPermissions, bSpendInfluence, bRankRename, bVote, bChangeMemberRank
bInvite, bKick, bEmblemAndStandard, bMemberChat, bCouncilChat, bBankTabRename, bNeighborhood
]]--

function WarpartyBank:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function WarpartyBank:Init()
    Apollo.RegisterAddon(self)
end

function WarpartyBank:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("WarpartyBank.xml")
    self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function WarpartyBank:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end

    Apollo.RegisterEventHandler("WarPartyBankerOpen", 		"WarPartyInitialize", self) -- notification you opened the WarParty bank.
    Apollo.RegisterEventHandler("GuildBankTab", 			"OnGuildBankTab", self) -- noficiation that a guild bank tab is loaded.
    Apollo.RegisterEventHandler("GuildBankItem", 			"OnGuildBankItem", self) -- noficiation of a change to a specific item that exists on a tab.
    Apollo.RegisterEventHandler("GuildRankChange", 			"OnGuildRankChange", self) -- notification that the ranks of the guild have changed.
    Apollo.RegisterEventHandler("GuildBankTabCount", 		"OnGuildBankTabCount", self)
    Apollo.RegisterEventHandler("GuildBankTabRename", 		"OnGuildBankTabRename", self) -- a bank tab was renamed.
    Apollo.RegisterEventHandler("GuildInfluenceAndMoney", 	"OnGuildInfluenceAndMoney", self) -- When influence or money is updated
    Apollo.RegisterEventHandler("GuildBankerClose", 		"CloseBank", self)
    Apollo.RegisterEventHandler("GuildBankLog", 			"OnGuildBankLog", self) -- When a bank log comes in

    -- todo
    --Apollo.RegisterEventHandler("GuildBankWithdraw", "OnBankTabBtnCash", self) -- notification your bank withdrawn counts have changed

    Apollo.RegisterEventHandler("PlayerCurrencyChanged", 		"OnPlayerCurrencyChanged", self)

    self.tTabPerks = {}
end

function WarpartyBank:WarPartyInitialize()
    if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
    end

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildBankForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("WarpartyBank_Title")})

    local guildWarparty = nil
    for idx, guildCurr in pairs(GuildLib.GetGuilds()) do
        if guildCurr:GetType() == GuildLib.GuildType_WarParty then
            local nMyRank = guildCurr:GetMyRank()
            guildWarparty = guildCurr
            self.wndMain:SetData(guildCurr)
			self.wndMain:FindChild("PermissionsMain"):SetData(nMyRank)
            break
        end
    end	
	
    self:Initialize(guildWarparty)
end

function WarpartyBank:Reinitialize(guildToInit)
    if guildToInit ~= nil then
        if guildToInit:GetType() == GuildLib.GuildType_WarParty then
            self:WarPartyInitialize()
        end
    elseif self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
    end
end

function WarpartyBank:Initialize(guildOwner)
    local tGuildPerks = guildOwner:GetPerks()

    self:HelperLoadTabPerks(guildOwner)

    local nBankTabCount = guildOwner:GetBankTabCount()
    for idx, nLimit in pairs(GuildLib.GetBankWithdrawLimits()) do
        ktWithdrawLimit[idx] = nLimit
    end

    self.strTransferType = nil
    self.tCurrentDragData = nil

    self.wndMain:FindChild("BankTabBtnVault"):Enable(nBankTabCount > 0)
    self.wndMain:FindChild("BankTabBtnPermissions"):Enable(nBankTabCount > 0)
    --self.wndMain:FindChild("BankTabBtnCash"):AttachWindow(self.wndMain:FindChild("CashScreenMain"))
    self.wndMain:FindChild("BankTabBtnVault"):AttachWindow(self.wndMain:FindChild("BankScreenMain"))
	self.wndMain:FindChild("BankTabBtnPermissions"):AttachWindow(self.wndMain:FindChild("PermissionsMain"))
	
	--Hide windows without fade
	self.wndMain:FindChild("BankScreenMain"):Show(false, true)
	self.wndMain:FindChild("PermissionsMain"):Show(false, true)
	
	self.wndMain:FindChild("GuildWarCoinsAmount"):SetAmount(guildOwner:GetWarCoins(), true)
	self.wndMain:FindChild("GuildWarCoinsAmount"):SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
	self.wndMain:FindChild("GuildWarCoinsAmount"):Show(true)
	
	if self.wndMain:FindChild("BankTabBtnVault"):IsEnabled() then
		self.wndMain:FindChild("BankTabBtnVault"):SetCheck(true)
		self:OnBankTabBtnVault()
	end
end

function WarpartyBank:CloseBank()
    if self.wndMain ~= nil then
		self.wndMain:Destroy()
    end
	
	Event_CancelWarpartyBank()
end

-----------------------------------------------------------------------------------------------
-- Vault Items
-----------------------------------------------------------------------------------------------

function WarpartyBank:OnBankTabBtnVault(wndHandler, wndControl)
    self:HelperUpdateHeaderText(String_GetWeaselString(Apollo.GetString("WarpartyBank_TitleWithTabName"), Apollo.GetString("WarpartyBank_Items")))
    self.wndMain:FindChild("MainBankNoVisibility"):Show(false)
    local guildOwner = self.wndMain:GetData()
    guildOwner:OpenBankTab(1)
end

function WarpartyBank:OnBankTabMouseEnter(wndHandler, wndControl)
    if self.tCurrentDragData and wndHandler:IsEnabled() then
        for idx, wndCurr in pairs(self.wndMain:FindChild("TopRowBankTabItems"):GetChildren()) do
            wndCurr:SetCheck(wndCurr == wndHandler)
        end
        self:OnBankTabCheck(wndHandler, wndControl)
    end
end

function WarpartyBank:OnBankTabUncheck(wndHandler, wndControl)
    self.wndMain:FindChild("SharedBGMainFrame"):Show(true)
    self.wndMain:FindChild("MainBankNoVisibility"):Show(false)
    self:HelperEmptyMainBankScrollbar(false)
end

function WarpartyBank:OnGuildBankTab(guildOwner, nTab)
    if not self.wndMain or not self.wndMain:IsValid() then 
		return 
	end

	local tRanksTable = guildOwner:GetRanks()
	local tMyRankData = tRanksTable[guildOwner:GetMyRank()]
	local tMyRankDataPermissions = tMyRankData.arBankTab[nTab]

	self.wndMain:FindChild("BankScreenMain"):Show(true)
	self.wndMain:FindChild("SharedBGMainFrame"):Show(false)
	if not self.tCurrentDragData then
		self:DoFlashAnimation()
	end

	-- See if Visible
	if not tMyRankData or not tMyRankDataPermissions or not tMyRankDataPermissions.bVisible then
		self:HelperUpdateHeaderText()
		self:HelperEmptyMainBankScrollbar(false)
		self.wndMain:FindChild("MainBankNoVisibility"):Show(true)
		return
	end

	-- Withdraw Limit
	local nWithdrawalAmount = ktWithdrawLimit[tMyRankDataPermissions.idWithdrawLimit]

	local strHeaderText = String_GetWeaselString(Apollo.GetString("WarpartyBank_TitleWithTabName"), guildOwner:GetBankTabName(nTab))
	if tostring(nWithdrawlAmount) ~= "-1" then
		local nAmountWithdrawnToday = guildOwner:GetBankTabItemWithdrawnToday(nTab)
		local tWithdrawalInfo = {["name"] = Apollo.GetString("GuildBank_Withdrawal"), ["count"] = math.max(0, nWithdrawalAmount - nAmountWithdrawnToday)}

		strHeaderText = String_GetWeaselString(Apollo.GetString("GuildBank_LimitedWithdrawalsCounter"), strHeaderText, tWithdrawalInfo)
	end
	self:HelperUpdateHeaderText(strHeaderText)

    -- All Slots
    self:HelperEmptyMainBankScrollbar(true)
    self.wndMain:FindChild("MainBankScrollbar"):SetData(nTab)
    for idx, tCurrData in ipairs(guildOwner:GetBankTab(nTab)) do -- This doesn't hit the server, but we can still use GuildBankItem for updating afterwards
        self:HelperDrawBankItem(tCurrData.itemInSlot, nTab, tCurrData.nIndex)
    end
    self.wndMain:FindChild("MainBankScrollbar"):ArrangeChildrenTiles(0)
end

function WarpartyBank:HelperDrawBankItem(itemDrawing, nTab, nInventorySlot)
    local wndBankSlot = self.wndMain:FindChild("MainBankScrollbar"):FindChildByUserData(nInventorySlot)
    wndBankSlot:FindChild("BankItemIcon"):SetData(itemDrawing)
    wndBankSlot:FindChild("BankItemIcon"):SetSprite(itemDrawing:GetIcon())
    self:HelperBuildItemTooltip(wndBankSlot:FindChild("BankItemIcon"), itemDrawing)

    local nStackCount = itemDrawing:GetStackCount()
    if nStackCount ~= 1 then
        wndBankSlot:FindChild("BankItemIcon"):SetText(nStackCount)
    end
end

function WarpartyBank:OnGuildBankItem(guildOwner, nTab, nInventorySlot, itemUpdated, bRemoved)
    if not self.wndMain or not self.wndMain:IsValid() or nTab ~= self.wndMain:FindChild("MainBankScrollbar"):GetData() then return end -- Viewing same tab page
    if bRemoved then
        local wndItem = self.wndMain:FindChild("MainBankScrollbar"):FindChildByUserData(nInventorySlot)
        wndItem:FindChild("BankItemIcon"):SetData(nil)
        wndItem:FindChild("BankItemIcon"):SetText("")
        wndItem:FindChild("BankItemIcon"):SetSprite("")
        wndItem:FindChild("BankItemIcon"):SetTooltip("")
    else -- Changed or Added
        self:HelperDrawBankItem(itemUpdated, nTab, nInventorySlot)
    end
end

function WarpartyBank:OnBankItemBeginDragDrop(wndHandler, wndControl) -- BankItemIcon
    if wndHandler ~= wndControl then return false end

    local guildOwner = self.wndMain:GetData()
    local itemSelected = wndHandler:GetData()
    if itemSelected then
        local nTransferStackCount = 0 -- 0 is default for the whole stack.
        self.strTransferType = guildOwner:BeginBankItemTransfer(itemSelected, nTransferStackCount) -- returns nil if item is bogus or "guild" can't do bank operations. (it is a circle or something)
        if self.strTransferType ~= nil then
            Apollo.BeginDragDrop(wndControl, self.strTransferType, itemSelected:GetIcon(), 0)
        end
    end
    self.tCurrentDragData = itemSelected

    -- TODO Verify deposit permissions
end

function WarpartyBank:OnBankItemQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType)
    if wndHandler ~= wndControl then
        return Apollo.DragDropQueryResult.PassOn
    elseif strType == "DDGuildBankItem" or strType == "DDWarPartyBankItem" or strType == "DDBagItem" then -- Should change to an enum?
        return Apollo.DragDropQueryResult.Accept
    else
        return Apollo.DragDropQueryResult.Ignore
    end
end

function WarpartyBank:OnBankItemDragDropEnd() -- Any UI
    self:OnBankItemDragDropCancel()
end

function WarpartyBank:OnBankItemDragDropCancel() -- Also called from UI
    self.tCurrentDragData = nil
end

function WarpartyBank:OnBankItemEndDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nBagSlot) -- Bank Icon
    if not wndHandler or not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        self:OnBankItemDragDropCancel()
        return false
    end

    local guildOwner = self.wndMain:GetData()
    local nDestinationSlot = wndControl:GetParent():GetData() -- TODO refactor. BankItemIcon -> BankItem -> nIndex
    local nDestinationTab = self.wndMain:FindChild("MainBankScrollbar"):GetData()

    if strType == self.strTransferType then -- be sure to check, it could be a dd operation from a warparty or something.
        guildOwner:EndBankItemTransfer(nDestinationTab, nDestinationSlot)

    elseif strType == "DDBagItem" and nBagSlot then
        local itemDepositing = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nBagSlot)
        if itemDepositing ~= nil then
            local nQuantity = 1 -- TODO, split stack functionality
            guildOwner:BeginBankItemTransfer(itemDepositing, nQuantity)
            guildOwner:EndBankItemTransfer(nDestinationTab, nDestinationSlot)
        end
    end

    self:OnBankItemDragDropCancel()
    return false
end

-----------------------------------------------------------------------------------------------
-- Cash
-----------------------------------------------------------------------------------------------

function WarpartyBank:OnPlayerCurrencyChanged()
    if self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("CashScreenMain"):IsVisible() then
        self.wndMain:FindChild("CashScreenMain:GuildCashMiddleBG:GuildWarCoinsAmount"):SetAmount(self.wndMain:GetData():GetWarCoins())
    end
end

function WarpartyBank:OnGuildInfluenceAndMoney(guildOwner, nInfluence, monCash)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:FindChild("CashScreenMain"):IsVisible() or self.wndMain:GetData() ~= guildOwner then
        return
    end
	self.wndMain:FindChild("GuildWarCoinsAmount"):SetAmount(guildOwner:GetWarCoins())
end

-----------------------------------------------------------------------------------------------
-- Tab Permissions
-----------------------------------------------------------------------------------------------

function WarpartyBank:OnBankTabBtnPermissions(wndHandler, wndControl)
    self:DrawTabPermissions()
end

function WarpartyBank:OnPermissionsResetBtn(wndHandler, wndControl)
    self:DrawTabPermissions()
end

function WarpartyBank:OnGuildRankChange() -- C++ Event
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() or not self.wndMain:FindChild("PermissionsMain"):IsShown() then
        return
    end
    self:DrawTabPermissions()
end

function WarpartyBank:OnPermissionsCurrentBtnLeftRight(wndHandler, wndControl)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end

    local guildOwner = self.wndMain:GetData()
    local tRankTable = guildOwner:GetRanks()
    local nPreviousRank = self.wndMain:FindChild("PermissionsMain"):GetData()

    if wndHandler:GetName() == "PermissionsCurrentRightBtn" then
        for iRank, tRankData in pairs(tRankTable) do
            if iRank > nPreviousRank and tRankData.bValid then
                self.wndMain:FindChild("PermissionsMain"):SetData(iRank)
                break
            end
        end
    else
        for iRank = #tRankTable, 1, -1 do
            local tRankData = tRankTable[iRank]
            if iRank < nPreviousRank and tRankData.bValid then
                self.wndMain:FindChild("PermissionsMain"):SetData(iRank)
                break
            end
        end
    end

    self:DrawTabPermissions()
end

function WarpartyBank:DrawTabPermissions()
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end

    self.wndMain:SetFocus()
    self:HelperUpdateHeaderText(String_GetWeaselString(Apollo.GetString("WarpartyBank_TitleWithTabName"), Apollo.GetString("GuildBank_PermissionsLabel")))

    local guildOwner = self.wndMain:GetData()
    local wndParent = self.wndMain:FindChild("PermissionsMain")
    local nGuildRank = self.wndMain:FindChild("PermissionsMain"):GetData()
    local tRanksTable = guildOwner:GetRanks()
    local nTabCount = guildOwner:GetBankTabCount()
    local tCurrRankData = tRanksTable[nGuildRank]
    local bCanEditRanks = tRanksTable[guildOwner:GetMyRank()].bChangeRankPermissions

    if not tCurrRankData then
        return
    end

    wndParent:FindChild("PermissionsSaveBtn"):Enable(false)
    wndParent:FindChild("PermissionsSaveBtn"):Show(bCanEditRanks)
    wndParent:FindChild("PermissionsResetBtn"):Show(bCanEditRanks)
    wndParent:FindChild("PermissionsCurrentLeftBtn"):Show(nGuildRank > 1)
    wndParent:FindChild("PermissionsCurrentRightBtn"):Show(nGuildRank < 10)
    wndParent:FindChild("PermissionsGridNamesVisible2"):Show(nTabCount > 1)
    wndParent:FindChild("PermissionsGridNamesDeposit2"):Show(nTabCount > 1)
    wndParent:FindChild("PermissionsGridNamesWithdraw2"):Show(nTabCount > 1)
    wndParent:FindChild("PermissionsCurrentRankText"):SetText(String_GetWeaselString(Apollo.GetString("GuildBank_PermissionsAppend"), tCurrRankData.strName))

    -- Tabs
    wndParent:FindChild("PermissionsGridRowItems"):DestroyChildren()
    for idx = 1, nTabCount do
        self:BuildPermissionIndividualTab(wndParent, guildOwner, bCanEditRanks, tCurrRankData, idx)
    end
    wndParent:FindChild("PermissionsGridRowItems"):ArrangeChildrenTiles(1)
end

function WarpartyBank:BuildPermissionIndividualTab(wndParent, guildOwner, bCanEditRanks, tCurrRankData, nBankTab)
    local wndTab = Apollo.LoadForm(self.xmlDoc, "PermissionsGridRow", wndParent:FindChild("PermissionsGridRowItems"), self)
    local idWithdrawLimit = tCurrRankData.arBankTab[nBankTab].idWithdrawLimit
    local strBankTabName = guildOwner:GetBankTabName(nBankTab)
    local strSpriteVisible = "ClientSprites:LootCloseBox"
    local strSpriteDeposit = "ClientSprites:LootCloseBox"
	local strSpriteUse = "ClientSprites:LootCloseBox"
	
    if tCurrRankData.arBankTab[nBankTab].bVisible then
        strSpriteVisible = "ClientSprites:Icon_Windows_UI_CRB_Checkmark"
    end
    if tCurrRankData.arBankTab[nBankTab].bDeposit then
        strSpriteDeposit = "ClientSprites:Icon_Windows_UI_CRB_Checkmark"
    end
    if not strBankTabName or string.len(strBankTabName) == 0 then
        strBankTabName = Apollo.GetString("GuildBank_BankTab")
    end
    if idWithdrawLimit == knUsePermissionAll then
		strSpriteUse = "ClientSprites:Icon_Windows_UI_CRB_Checkmark"
    end
	
    wndTab:FindChild("PermissionGridBtnVisible"):SetData(wndTab)
    wndTab:FindChild("PermissionGridBtnDeposit"):SetData(wndTab)
	wndTab:FindChild("PermissionGridBtnUse"):SetData(wndTab)
    
    wndTab:FindChild("PermissionGridIconVisible"):SetData(tCurrRankData.arBankTab[nBankTab].bVisible)
    wndTab:FindChild("PermissionGridIconDeposit"):SetData(tCurrRankData.arBankTab[nBankTab].bDeposit)
	wndTab:FindChild("PermissionGridIconUse"):SetData(idWithdrawLimit)
	
    wndTab:FindChild("PermissionsGridRowText"):SetText(strBankTabName)
    wndTab:FindChild("PermissionGridIconUse"):SetSprite(strSpriteUse)
    wndTab:FindChild("PermissionGridIconVisible"):SetSprite(strSpriteVisible)
    wndTab:FindChild("PermissionGridIconDeposit"):SetSprite(strSpriteDeposit)
	
    wndTab:FindChild("PermissionGridBtnVisible"):Show(bCanEditRanks)
    wndTab:FindChild("PermissionGridBtnDeposit"):Show(bCanEditRanks)
    wndTab:FindChild("PermissionGridBtnUse"):Show(bCanEditRanks)
end

function WarpartyBank:OnPermissionGridBtnVisibleDeposit(wndHandler, wndControl)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end

    local wndTab = wndHandler:GetData()
    local strIcon = "PermissionGridIconVisible"
	local bChangingVisible = true
    if wndHandler:GetName() == "PermissionGridBtnDeposit" then -- NAME HACK
		if not wndTab:FindChild(strIcon):GetData() then
			-- prevent changing if not visible
			return
		end
        strIcon = "PermissionGridIconDeposit"
		bChangingVisible = false
	end

    if wndTab:FindChild(strIcon):GetData() then
        wndTab:FindChild(strIcon):SetSprite("ClientSprites:LootCloseBox")
    else
        wndTab:FindChild(strIcon):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Checkmark")
    end
    wndTab:FindChild(strIcon):SetData(not wndTab:FindChild(strIcon):GetData())
    self.wndMain:FindChild("PermissionsSaveBtn"):Enable(true)
	if bChangingVisible then
		if wndTab:FindChild(strIcon):GetData() then
			wndTab:FindChild("PermissionGridBtnDeposit"):Enable(true)
			wndTab:FindChild("PermissionGridBtnUse"):Enable(true)
		else
			wndTab:FindChild("PermissionGridBtnDeposit"):Enable(false)
			wndTab:FindChild("PermissionGridIconDeposit"):SetData(false)
    	    wndTab:FindChild("PermissionGridIconDeposit"):SetSprite("ClientSprites:LootCloseBox")
			wndTab:FindChild("PermissionGridBtnUse"):Enable(false)
			wndTab:FindChild("PermissionGridIconUse"):SetData(knUsePermissionNone)
	        wndTab:FindChild("PermissionGridIconUse"):SetSprite("ClientSprites:LootCloseBox")
		end
	end
end

function WarpartyBank:OnPermissionGridBtnUse(wndHandler, wndControl)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end
	
	local wndTab = wndHandler:GetData()
	local wndPermissionGridIconUse = wndTab:FindChild("PermissionGridIconUse")

	if not wndTab:FindChild("PermissionGridIconVisible"):GetData() then
		-- prevent changing if not visible
		return
	end
	
	if wndPermissionGridIconUse:GetData() == knUsePermissionNone then
		wndPermissionGridIconUse:SetData(knUsePermissionAll)
		wndPermissionGridIconUse:SetSprite("ClientSprites:Icon_Windows_UI_CRB_Checkmark")
	else
		wndPermissionGridIconUse:SetData(knUsePermissionNone)
		wndPermissionGridIconUse:SetSprite("ClientSprites:LootCloseBox")
	end
	
	self.wndMain:FindChild("PermissionsSaveBtn"):Enable(true)
end

function WarpartyBank:OnPermissionsSaveBtn(wndHandler, wndControl)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then return end

    local guildOwner = self.wndMain:GetData()
    local wndParent = self.wndMain:FindChild("PermissionsMain")
    local nGuildRank = wndParent:GetData()
    local tPermissions = {}

    for iTab, wndTab in pairs(self.wndMain:FindChild("PermissionsGridRowItems"):GetChildren()) do
        tPermissions[iTab] = {}
        tPermissions[iTab].bAuthenticator = false -- TODO
        tPermissions[iTab].bVisible = wndTab:FindChild("PermissionGridIconVisible"):GetData()
        tPermissions[iTab].bDeposit = wndTab:FindChild("PermissionGridIconDeposit"):GetData()
        tPermissions[iTab].idWithdrawLimit = wndTab:FindChild("PermissionGridIconUse"):GetData()
    end

    -- isnt iTab out of scope?
    guildOwner:SetBankTabPermissions(nGuildRank, iTab, tPermissions) -- Calls OnGuildRankChange
end

-----------------------------------------------------------------------------------------------
-- Leader Permissions
-----------------------------------------------------------------------------------------------

function WarpartyBank:OnBankTabBtnMgmt()
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end

    self.wndMain:SetFocus()
    self:HelperUpdateHeaderText(String_GetWeaselString(Apollo.GetString("WarpartyBank_TitleWithTabName"), Apollo.GetString("GuildBank_Management")))

    local guildOwner = self.wndMain:GetData()
    local wndParent = self.wndMain:FindChild("LeaderScreenMain")
    local nGuildInfluence = guildOwner:GetInfluence()
    wndParent:FindChild("MgmtBankTabInfluenceText"):SetText(String_GetWeaselString(Apollo.GetString("GuildBank_GuildInfluence"), nGuildInfluence))

    self:HelperLoadTabPerks(guildOwner)

    -- Tabs
    wndParent:FindChild("MgmtBankTabContainer"):DestroyChildren()

    local nTabCounter = 1
    if guildOwner:GetType() == GuildLib.GuildType_WarParty then
        for idx = 1, guildOwner:GetBankTabCount() do
            local wndCurr = nil
            local strBankTabName = guildOwner:GetBankTabName(nTabCounter)
            if not strBankTabName or string.len(strBankTabName) == 0 then
                strBankTabName = Apollo.GetString("GuildBank_BankTab")
            end
            wndCurr = Apollo.LoadForm(self.xmlDoc, "LeaderOptionsTabItemOld", wndParent:FindChild("MgmtBankTabContainer"), self)
            wndCurr:SetData(nTabCounter)
            wndCurr:FindChild("LeaderOptionsEditBox"):SetData(wndCurr)
            wndCurr:FindChild("LeaderOptionsEditBox"):SetText(strBankTabName)
            wndCurr:FindChild("LeaderOptionsTabRenameBtn"):SetData(wndCurr)
            wndCurr:FindChild("LeaderOptionsTabRenameBtn"):Enable(false)
            nTabCounter = nTabCounter + 1
        end
    end
    wndParent:FindChild("MgmtBankTabContainer"):ArrangeChildrenVert(0)
    --wndParent:FindChild("MgmtBankTabContainer"):ArrangeChildrenVert(0, function(a,b) return ktWhichPerksAreGuildTabs[a:GetData()] < ktWhichPerksAreGuildTabs[b:GetData()] end)
end

function WarpartyBank:OnLeaderOptionsEditBoxChanged(wndHandler, wndControl)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end

    local wndParent = wndHandler:GetData()
    wndParent:FindChild("LeaderOptionsTabRenameBtn"):Enable(true)

    local strEntry = wndHandler:GetText()
    if string.len(strEntry) > knMaxBankTabNameLength then
        wndHandler:SetText(string.sub(strEntry, 0, knMaxBankTabNameLength))
        wndHandler:SetSel(knMaxBankTabNameLength)
    end
end

function WarpartyBank:OnLeaderOptionsTabRenameBtn(wndHandler, wndControl)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end

    local guildOwner = self.wndMain:GetData()
    local wndParent = wndHandler:GetData()
    guildOwner:RenameBankTab(wndParent:GetData(), wndParent:FindChild("LeaderOptionsEditBox"):GetText()) -- Fires GuildBankTabRename
end

function WarpartyBank:OnGuildBankTabRename(guildOwner)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end
    self:Reinitialize(guildOwner)
end

function WarpartyBank:OnLeaderOptionsTabBuyBtn(wndHandler, wndControl)
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end

    local guildOwner = self.wndMain:GetData()
    guildOwner:PurchasePerk(wndHandler:GetData()) -- Will call GuildBankTabCount
end

function WarpartyBank:OnGuildBankTabCount()
    if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
        return
    end
    local guildOwner = self.wndMain:GetData()
    self:Reinitialize(guildOwner)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function WarpartyBank:HelperEmptyMainBankScrollbar(bShow)
    for idx = 1, knMaxBankSlots do
        local wndItem = self:FactoryProduce(self.wndMain:FindChild("MainBankScrollbar"), "BankItem", idx)
        wndItem:FindChild("BankItemIcon"):SetData(nil)
        wndItem:FindChild("BankItemIcon"):SetText("")
        wndItem:FindChild("BankItemIcon"):SetSprite("")
        wndItem:Show(bShow)
    end
    self.wndMain:FindChild("MainBankScrollbar"):RecalculateContentExtents()
end

function WarpartyBank:HelperUpdateHeaderText(strNewHeader)
    local strFinalHeader = strNewHeader
    if not strNewHeader or string.len(strNewHeader) == 0 then
        strFinalHeader = Apollo.GetString("WarpartyBank_Title")
    end
    self.wndMain:FindChild("BGHeaderText"):SetText(strFinalHeader)
end

function WarpartyBank:DoFlashAnimation()
    if not self.wndMain or not self.wndMain:IsValid() then
        return
    end
    self.wndMain:FindChild("FlashAnimation"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
end

function WarpartyBank:HelperBuildItemTooltip(wndArg, itemCurrent)
    --wndArg:SetTooltipDoc(nil)
    local itemEquipped = itemCurrent:GetEquippedItemForItemType()
    Tooltip.GetItemTooltipForm(self, wndArg, itemCurrent, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
    --if itemEquipped ~= nil then
    --    Tooltip.GetItemTooltipForm(self, wndArg, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = itemCurrent})
    --end
end

function WarpartyBank:HelperLoadTabPerks(guildOwner)
    local tGuildPerks = guildOwner:GetPerks()
    for idx, tCurrPerk in pairs(tGuildPerks) do
        if ktWhichPerksAreGuildTabs[tCurrPerk.nId] then
            self.tTabPerks[ktWhichPerksAreGuildTabs[tCurrPerk.nId]] = tCurrPerk
        end
    end
end

function WarpartyBank:FactoryProduce(wndParent, strFormName, tObject)
    local wnd = wndParent:FindChildByUserData(tObject)
    if not wnd then
        wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
        wnd:SetData(tObject)
    end
    return wnd
end

function WarpartyBank:HelperConvertToTime(nDays)

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


local WarpartyBankInst = WarpartyBank:new()
WarpartyBankInst:Init()

