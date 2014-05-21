-----------------------------------------------------------------------------------------------
-- Client Lua Script for AccountServices
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "CharacterScreenLib"
require "AccountItemLib"

local AccountServices = {}
local keFireOnPaidTransfer = "Transfer" -- Random Enum (GOTCHA: Free doesn't need to worry about this)
local keFireOnRename = "Rename" -- Random Enum
local keFireOnCredd = "Credd" -- Random Enum

local ktRealmPopToString =
{
	Apollo.GetString("RealmPopulation_Low"),
	Apollo.GetString("RealmPopulation_Medium"),
	Apollo.GetString("RealmPopulation_High"),
	Apollo.GetString("RealmPopulation_Full"),
}

local ktRealmTransferResults =
{
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_InvalidRealm]		=	"AccountServices_Error_InvalidRealm",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferOk]							=	"AccountServices_Error_Ok",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_ServerDown]			=	"AccountServices_Error_ServerDown",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterOnline]		=	"AccountServices_Error_CharacterOnline",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_InvalidCharacter]	=	"AccountServices_Error_InvalidCharacter",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterLocked]		=	"AccountServices_Error_CharacterLocked",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_NoCurrency]			=	"AccountServices_Error_NoCurrency",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_DbError]				=	"AccountServices_Error_DbError",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_HasAuction]			=	"AccountServices_Error_HasAuction",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_InGuild]				=	"AccountServices_Error_InGuild",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_HasCREDDExchange]	=	"AccountServices_Error_HasCREDDExchange",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterBusy]		=	"AccountServices_Error_CharacterBusy",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterCooldown]	=	"AccountServices_Error_CharacterCooldown",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_HasMail]				=	"AccountServices_Error_HasMail",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_ServerFull]			=	"AccountServices_Error_ServerFull",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_Money]				=	"AccountServices_Error_TooMuchMoney",
}

function AccountServices:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function AccountServices:Init()
    Apollo.RegisterAddon(self)
end

function AccountServices:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AccountServices.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function AccountServices:DebugPrint(strMessage)
	if self.wndDebugPrint and self.wndDebugPrint:IsValid() then self.wndDebugPrint:Destroy() end
	self.wndDebugPrint = Apollo.LoadForm(self.xmlDoc, "DebugPrint", "AccountServices", self)
	self.wndDebugPrint:SetText(tostring(strMessage))
	self.wndDebugPrint:Show(true)
end

function AccountServices:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("AccountItemUpdate", 				"RedrawAll", self) -- Global catch all method
	Apollo.RegisterEventHandler("CharacterRename", 					"OnCharacterRename", self)
	Apollo.RegisterEventHandler("RealmTransferResult", 				"OnRealmTransferResult", self)
	Apollo.RegisterEventHandler("TransferDestinationRealmList", 	"OnTransferDestinationRealmList", self)

	Apollo.RegisterEventHandler("Pregame_CreationToSelection", 		"OnPregame_CreationToSelection", self)
	Apollo.RegisterEventHandler("Pregame_CharacterSelected", 		"OnPregame_CharacterSelected", self)
	Apollo.RegisterEventHandler("OpenCharacterCreateBtn", 			"OnOpenCharacterCreateBtn", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "AccountServicesForm", "AccountServices", self)
	self.wndMinimized = Apollo.LoadForm(self.xmlDoc, "MinimizedPicker", "AccountServices", self)

	self.wndMainPicker = self.wndMain:FindChild("MainPicker")
	self.wndCreddFlyout = self.wndMain:FindChild("CreddFlyout")
	self.wndRenameFlyout = self.wndMain:FindChild("RenameFlyout")
	self.wndPaidTransferFlyout = self.wndMain:FindChild("PaidTransferFlyout")
	self.wndFreeTransferFlyout = self.wndMain:FindChild("FreeTransferFlyout")
	self.wndMainPicker:FindChild("AvailablePaidCreddBtn"):AttachWindow(self.wndCreddFlyout)
	self.wndMainPicker:FindChild("AvailablePaidRenameBtn"):AttachWindow(self.wndRenameFlyout)
	self.wndMainPicker:FindChild("AvailablePaidRealmBtn"):AttachWindow(self.wndPaidTransferFlyout)
	self.wndMainPicker:FindChild("AvailableFreeRealmBtn"):AttachWindow(self.wndFreeTransferFlyout)

	self.wndErrorMessage = nil
	self.wndRenameConfirm = nil
	self.wndTransferConfirm = nil
	self.wndGroupBindConfirm = nil

	self:RedrawAll() -- We need to call this on start up and with AccountItemUpdate, so it'll draw no matter what

	self.bFireCreddOnUpdate = nil
	self.strFireRenameOnUpdate = nil
	self.nFirePaidTransferOnUpdate = nil

	self.nCharacterSelectedId = 0
	self.strCharacterSelectedName = nil
	self.bCharacterRequiresRename = false
end

function AccountServices:RedrawAll()
	self:HelperCheckTriggers()

	local bLoadLapsedAccount = CharacterScreenLib.GetSubscriptionExpired()
	if bLoadLapsedAccount then
		self.wndBlackFill = Apollo.LoadForm(self.xmlDoc, "FullScreenBlackFill", "AccountServices", self)
		self.wndBlackFill:Invoke()

		self.wndLapsedPopup = Apollo.LoadForm(self.xmlDoc, "LapsedAccountWithCREDD", "AccountServices", self)
		self.wndLapsedPopup:Invoke()

		self.wndLapsedBlocker = Apollo.LoadForm(self.xmlDoc, "LapsedButtonBlocker", "AccountServices", self)
		self.wndLapsedBlocker:Invoke()
	end

	-- Count Account Bound options
	local nCreddEscrow = 0
	local nRenameEscrow = 0
	local nTransferEscrow = 0
	local nCreddBound = AccountItemLib.GetAccountCurrency(PreGameLib.CodeEnumAccountCurrency.CREDD) or 0
	local nRenameBound = AccountItemLib.GetAccountCurrency(PreGameLib.CodeEnumAccountCurrency.NameChange) or 0
	local nTransferBound = AccountItemLib.GetAccountCurrency(PreGameLib.CodeEnumAccountCurrency.RealmTransfer) or 0

	-- Note: When claiming from a group to Account Bound, we'll have to warn a player that they will get the entire group.
	local tFlattenedTable = {}
	for idx, tPendingAccountItem in pairs(AccountItemLib.GetPendingAccountSingleItems()) do
		table.insert(tFlattenedTable, tPendingAccountItem)
	end

	for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
		for idx2, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
			table.insert(tFlattenedTable, tPendingAccountItem)
		end
	end

	for idx, tPendingAccountItem in pairs(tFlattenedTable) do
		if tPendingAccountItem.accountCurrency then
			local ePendingType = tPendingAccountItem.accountCurrency.accountCurrencyEnum
			nCreddEscrow = ePendingType == PreGameLib.CodeEnumAccountCurrency.CREDD and (nCreddEscrow + 1) or nCreddEscrow
			nRenameEscrow = ePendingType == PreGameLib.CodeEnumAccountCurrency.NameChange and (nRenameEscrow + 1) or nRenameEscrow
			nTransferEscrow = ePendingType == PreGameLib.CodeEnumAccountCurrency.RealmTransfer and (nTransferEscrow + 1) or nTransferEscrow
		end
	end

	-- Initialize if > 0
	local tMyRealmInfo = CharacterScreenLib.GetRealmInfo()
	local bCanFreeRealmTransfer = tMyRealmInfo and tMyRealmInfo.bFreeRealmTransfer or nil
	if bCanFreeRealmTransfer or math.max(nCreddBound, nCreddEscrow, nRenameBound, nRenameEscrow, nTransferBound, nTransferEscrow) > 0 then
		local bDefaultMinimized = false -- TODO, Console Variable or saved setting
		self.wndMain:Show(not bDefaultMinimized, true)
		self.wndMinimized:Show(bDefaultMinimized, true)

		self:DrawCreddFlyout(nCreddBound, nCreddEscrow)
		self:DrawRenameFlyout(nRenameBound, nRenameEscrow)
		self:DrawFreeTransferFlyout()
		self:DrawPaidTransferFlyout(nTransferBound, nTransferEscrow)

		local wndMainPickerButtonList = self.wndMainPicker:FindChild("AvailableScroll")
		local tWindowNameToSubtitle =
		{
			["AvailableFreeRealmBtn"]	=	{ Apollo.GetString("AccountServices_NumRealmsAvailable"), bCanFreeRealmTransfer and 1 or 0 }, -- Just for enabling
			["AvailablePaidRealmBtn"]	=	{ Apollo.GetString("AccountServices_NumAvailable"), nTransferBound +  nTransferEscrow },
			["AvailablePaidRenameBtn"]	=	{ Apollo.GetString("AccountServices_NumAvailable"), nRenameBound + nRenameEscrow },
			["AvailablePaidCreddBtn"]	=	{ Apollo.GetString("AccountServices_NumAvailableCREDDExplain"), nCreddBound + nCreddEscrow },
		}
		for strButtonName, tData in pairs(tWindowNameToSubtitle) do
			local bValid = tonumber(tData[2]) > 0
			local wndCurrButton = wndMainPickerButtonList:FindChild(strButtonName)
			wndCurrButton:FindChild("AvailableBtnSubtitle"):SetTextColor(bValid and ApolloColor.new("UI_TextHoloBodyCyan") or ApolloColor.new("UI_TextMetalBodyHighlight"))
			wndCurrButton:FindChild("AvailableBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(tData[1], tData[2]))
			wndCurrButton:Show(bValid)
		end
		wndMainPickerButtonList:FindChild("AvailablePaidRenameBtn"):Enable(not self.bCharacterRequiresRename)

		wndMainPickerButtonList:ArrangeChildrenVert(0)
	end
end

-----------------------------------------------------------------------------------------------
-- Main Picker
-----------------------------------------------------------------------------------------------

function AccountServices:OnPregame_CharacterSelected(tData)
	local tSelected = tData.tSelected
	self.nCharacterSelectedId = tData.nId
	self.strCharacterSelectedName = tSelected and tSelected.strName or ""
	self.bCharacterRequiresRename = tSelected and tSelected.bRequiresRename

	if self.wndMainPicker and self.wndMainPicker:FindChild("AvailableScroll") then
		self.wndMainPicker:FindChild("AvailableScroll"):FindChild("AvailablePaidRenameBtn"):Enable(not self.bCharacterRequiresRename)
	end

	self:OnRenameCloseBtn()
	self:OnCreddFlyoutCloseBtn()
	self:OnPaidTransferFlyoutCloseBtn()
end

function AccountServices:OnOpenCharacterCreateBtn() -- Generic Event, not a btn click
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() then
		self.wndMain:Close()
		if self.wndMinimized and self.wndMinimized:IsValid() then
			self.wndMinimized:Invoke()
		end
	end
	if self.wndMinimized and self.wndMinimized:IsValid() then
		self.wndMinimized:FindChild("ShowMainPicker"):Enable(false)
	end
end

function AccountServices:OnPregame_CreationToSelection() -- Generic Event, not a btn click
	if self.wndMinimized and self.wndMinimized:IsValid() then
		self.wndMinimized:FindChild("ShowMainPicker"):Enable(true)
	end
end

function AccountServices:OnShowMainPicker(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Invoke()
	end
	if self.wndMinimized and self.wndMinimized:IsValid() then
		self.wndMinimized:Close()
	end
end

function AccountServices:OnHideMainPicker(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Close()
	end
	if self.wndMinimized and self.wndMinimized:IsValid() then
		self.wndMinimized:Invoke()
	end
end

-----------------------------------------------------------------------------------------------
-- Credd
-----------------------------------------------------------------------------------------------

function AccountServices:DrawCreddFlyout(nCreddBound, nCreddEscrow)
	local bBoundEnable = nCreddBound > 0
	local bEscrowEnable = nCreddEscrow > 0
	self.wndCreddFlyout:FindChild("CreddPaymentBound"):Show(bBoundEnable)
	self.wndCreddFlyout:FindChild("CreddPaymentEscrow"):Show(bEscrowEnable)
	self.wndCreddFlyout:FindChild("CreddPaymentBound"):SetCheck(bBoundEnable)
	self.wndCreddFlyout:FindChild("CreddPaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	self.wndCreddFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nCreddBound))
	self.wndCreddFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nCreddEscrow))
	self.wndCreddFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndCreddFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndCreddFlyout:FindChild("CreddPaymentArrangeVert"):ArrangeChildrenVert(0)
end

function AccountServices:OnCreddFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndCreddFlyout and self.wndCreddFlyout:IsValid() then
		self.wndCreddFlyout:Close()
		self.bFireCreddOnUpdate = nil
	end
end

function AccountServices:OnCreddConfirmBtn(wndHandler, wndControl)
	local bUsingEscrow = self.wndCreddFlyout:FindChild("CreddPaymentEscrow"):IsChecked()
	local tEscrowData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.CREDD)

	if bGiftableGroup then
		local wndGroupBindConfirm = self:ShowGroupBindConfirmation(tEscrowData)
		wndGroupBindConfirm:SetData({ eType = keFireOnCredd })
	else
		self:ShowCreddRedemptionConfirmation(tEscrowData)
	end

	self.wndCreddFlyout:Close()
end

function AccountServices:ShowCreddRedemptionConfirmation(tEscrowData)
	if self.wndCreddConfirm and self.wndCreddConfirm:IsValid() then
		self.wndCreddConfirm:Destroy()
	end

	if self.wndLapsedPopup and self.wndLapsedPopup:IsValid() then
		self.wndLapsedPopup:Destroy()
	end

	-- The actual confirmation button will need to be protected
	self.wndCreddConfirm = Apollo.LoadForm(self.xmlDoc, "RedeemCREDDConfirmation", "AccountServices", self)
	self.wndCreddConfirm:FindChild("RedeemCREDDYesBtn"):SetData(tEscrowData and tEscrowData.index)
	self.wndCreddConfirm:Invoke()
end

function AccountServices:OnRedeemCREDDYesBtn(wndHandler, wndControl)
	if self.wndBlackFill and self.wndBlackFill:IsValid() then
		self.wndBlackFill:Destroy()
	end

	if self.wndLapsedBlocker and self.wndLapsedBlocker:IsValid() then
		self.wndLapsedBlocker:Destroy()
	end

	if self.wndLapsedPopup and self.wndLapsedPopup:IsValid() then
		self.wndLapsedPopup:Destroy()
	end

	if self.wndCreddConfirm and self.wndCreddConfirm:IsValid() then
		self.wndCreddConfirm:Destroy()
	end

	if self.wndCreddFlyout:FindChild("CreddPaymentEscrow"):IsChecked() then
		local nEscrowIndex = wndHandler:GetData()
		AccountItemLib.ClaimPendingSingleItem(nEscrowIndex) -- HelperCatchTriggers will catch the event, detect a non nil self.bFireCreddOnUpdate, then call Redeem
		self.bFireCreddOnUpdate = true
	else
		AccountItemLib.RedeemCREDD()
	end
end

function AccountServices:OnCloseRedeemConfirmation(wndHandler, wndControl)
	if self.wndCreddConfirm and self.wndCreddConfirm:IsValid() then
		self.bFireCreddOnUpdate = nil
		self.wndCreddConfirm:Destroy()
	end
end

-----------------------------------------------------------------------------------------------
-- Rename
-----------------------------------------------------------------------------------------------

function AccountServices:DrawRenameFlyout(nRenameBound, nRenameEscrow)
	local bBoundEnable = nRenameBound > 0
	local bEscrowEnable = nRenameEscrow > 0
	self.wndRenameFlyout:FindChild("RenameConfirmBtn"):Enable(false)
	self.wndRenameFlyout:FindChild("RenamePaymentBound"):Show(bBoundEnable)
	self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):Show(bEscrowEnable)
	self.wndRenameFlyout:FindChild("RenamePaymentBound"):SetCheck(bBoundEnable)
	self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	self.wndRenameFlyout:FindChild("RenameInputBox"):SetPrompt(Apollo.GetString("AccountServices_NewName"))
	self.wndRenameFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nRenameBound))
	self.wndRenameFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nRenameEscrow))
	self.wndRenameFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndRenameFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndRenameFlyout:FindChild("RenamePaymentArrangeVert"):ArrangeChildrenVert(0)
end

function AccountServices:OnRenameCloseBtn(wndHandler, wndControl)
	if self.wndRenameFlyout and self.wndRenameFlyout:IsValid() then
		self.wndRenameFlyout:FindChild("RenameInputCheck"):SetSprite("sprCharC_NameCheckNo")
		self.wndRenameFlyout:FindChild("RenameInputBox"):SetText("")
		self.wndRenameFlyout:Close()
		self.strFireRenameOnUpdate = nil
	end
end

function AccountServices:OnRenameInputBoxChanged(wndHandler, wndControl)
	local strText = wndHandler:GetText() or ""
	local bTextValid = CharacterScreenLib.IsCharacterNameValid(strText)
	self.wndRenameFlyout:FindChild("RenameConfirmBtn"):SetData(strText)
	self.wndRenameFlyout:FindChild("RenameConfirmBtn"):Enable(bTextValid)
	self.wndRenameFlyout:FindChild("RenameInputCheck"):Show(string.len(strText) > 0)
	self.wndRenameFlyout:FindChild("RenameInputCheck"):SetSprite(bTextValid and "sprCharC_NameCheckYes" or "sprCharC_NameCheckNo")
end

function AccountServices:OnRenameConfirmBtn(wndHandler, wndControl)
	local bUsingEscrow = self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):IsChecked()
	local tEscrowData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.NameChange)

	local nCharacterId = self.nCharacterSelectedId
	if not nCharacterId then
		return
	end

	if bGiftableGroup then
		local wndGroupBindConfirm = self:ShowGroupBindConfirmation(tEscrowData)
		wndGroupBindConfirm:SetData({ eType = keFireOnRename, strText = strText })
	else
		self:ShowRenameConfirmation(wndHandler:GetData(), tEscrowData)
	end

	self.wndRenameFlyout:Close()
end

function AccountServices:ShowRenameConfirmation(strText, tEscrowData)
	self.wndRenameConfirm = Apollo.LoadForm(self.xmlDoc, "RenameConfirmation", "AccountServices", self)
	self.wndRenameConfirm:FindChild("RenameExplanation"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RenameExplanation"), strText))
	self.wndRenameConfirm:FindChild("RenameYesBtn"):SetData({ strText = strText, nEscrowIndex = tEscrowData and tEscrowData.index })
	self.wndRenameConfirm:Invoke()
end

function AccountServices:OnRenameYesBtn(wndHandler, wndControl)
	local strText = wndHandler:GetData().strText
	local nEscrowIndex = wndHandler:GetData().nEscrowIndex

	if self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):IsChecked() then
		AccountItemLib.ClaimPendingSingleItem(nEscrowIndex)
		self.strFireRenameOnUpdate = strText
		-- HelperCatchTriggers will catch the event, detect a non nil self.strFireRenameOnUpdate, then call Rename
	else
		CharacterScreenLib.RenameCharacter(self.nCharacterSelectedId, strText)
	end
	self.wndRenameConfirm:Destroy()
end

function AccountServices:OnRenameNoBtn(wndHandler, wndControl)
	self.strFireRenameOnUpdate = nil
	self.wndRenameConfirm:Destroy()
end

function AccountServices:OnCharacterRename(nRenameResult, strName)
	if nRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameOk and self.wndMainPicker and self.wndMainPicker:FindChild("AvailableScroll") then
		self.wndMainPicker:FindChild("AvailableScroll"):FindChild("AvailablePaidRenameBtn"):Enable(true)
	end
end

-----------------------------------------------------------------------------------------------
-- Transfer
-----------------------------------------------------------------------------------------------

function AccountServices:OnMainPickerFreeRealmCheck(wndHandler, wndControl)
	CharacterScreenLib.GetRealmTransferDestinations(false) -- Leads to TransferDestinationRealmList
end

function AccountServices:OnMainPickerPaidRealmCheck(wndHandler, wndControl)
	CharacterScreenLib.GetRealmTransferDestinations(true) -- Leads to TransferDestinationRealmList
end

function AccountServices:OnTransferDestinationRealmList(tRealmList)
	if not self.wndPaidTransferFlyout and not self.wndPaidTransferFlyout:IsValid() then
		return
	end

	-- Helper Method
	local function HelperGridFactoryProduce(wndGrid, tTargetComparisonId)
		for nRow = 1, wndGrid:GetRowCount() do
			local tRealmData = wndGrid:GetCellLuaData(nRow, 1)
			if tRealmData and tRealmData.nRealmId == tTargetComparisonId then -- GetCellLuaData args are row, col
				return nRow
			end
		end
		return wndGrid:AddRow("") -- GOTCHA: This is a row number
	end

	local bFree = self.wndFreeTransferFlyout:IsVisible() -- If Free, show everything
	local tMyRealmInfo = CharacterScreenLib.GetRealmInfo()
	-- local bFreeRealmTransferSource = tMyRealmInfo and tMyRealmInfo.bFreeRealmTransfer or false -- Not needed currently

	-- Build Grid
	local tMyRealmInfo = CharacterScreenLib.GetRealmInfo()
	local wndGrid = self.wndPaidTransferFlyout:IsVisible() and self.wndPaidTransferFlyout:FindChild("PaidTransferGrid") or self.wndFreeTransferFlyout:FindChild("FreeTransferGrid")
	for idx, tCurr in pairs(tRealmList) do
		if (bFree or not tCurr.bIsFree) and tMyRealmInfo.strName ~= tCurr.strName then
			-- Strings for Cell 1,2,3 respectively
			local strRealmType = tCurr.nRealmPVPType == PreGameLib.CodeEnumRealmPVPType.PVP and Apollo.GetString("RealmSelect_PvP") or Apollo.GetString("RealmSelect_PvE")
			local strLongRealm = "<T Image=\"CRB_Basekit:kitIcon_Holo_Profile\"></T>"..PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RealmNameNum"), tCurr.strName, tCurr.nCount)
			local tCellStrings =
			{
				tCurr.nCount > 0 and strLongRealm or tCurr.strName,
				strRealmType,
				ktRealmPopToString[tCurr.nPopulation + 1],
				tCurr.strNote,
			}

			local wndCurrRow = HelperGridFactoryProduce(wndGrid, tCurr.nRealmId) -- GOTCHA: This is an integer
			wndGrid:SetCellLuaData(wndCurrRow, 1, tCurr)
			for idx, strCellString in pairs(tCellStrings) do
				wndGrid:SetCellSortText(wndCurrRow, idx, strCellString)
				wndGrid:SetCellDoc(wndCurrRow, idx, string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>", strCellString))
			end
		end
	end

	wndGrid:SetColumnText(1, Apollo.GetString("CRB_Name"))
	wndGrid:SetColumnText(2, Apollo.GetString("AccountServices_TypeColHeader"))
	wndGrid:SetColumnText(3, Apollo.GetString("AccountServices_PopHeader"))
	wndGrid:SetColumnText(4, Apollo.GetString("AccountServices_NoteHeader"))
	wndGrid:SetSortColumn(1, true) -- Sort 1st column Ascending
end

function AccountServices:ShowTransferConfirmation(bPaid, nRealmId, strRealm, tEscrowData) -- 4th arg nil for Free Transfers/Account Bound
	if self.wndTransferConfirm and self.wndTransferConfirm:IsValid() then
		self.wndTransferConfirm:Destroy()
	end

	local strPayment = bPaid and Apollo.GetString("AccountServices_PaidRealmTransfer") or Apollo.GetString("AccountServices_FreeRealmTransfer")
	local strExplanation = PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_TransferExplanation"), self.strCharacterSelectedName, strRealm, strPayment)
	self.wndTransferConfirm = Apollo.LoadForm(self.xmlDoc, "TransferConfirmation", "AccountServices", self)
	self.wndTransferConfirm:FindChild("PaidTransferYesBtn"):SetData({ nRealmId = nRealmId, nEscrowIndex = tEscrowData and tEscrowData.index })
	self.wndTransferConfirm:FindChild("FreeTransferYesBtn"):SetData({ nRealmId = nRealmId })
	self.wndTransferConfirm:FindChild("FreeTransferYesBtn"):Show(not bPaid)
	self.wndTransferConfirm:FindChild("PaidTransferYesBtn"):Show(bPaid)
	self.wndTransferConfirm:FindChild("TransferTitle"):SetText(strPayment)
	self.wndTransferConfirm:FindChild("TransferExplanation"):SetText(strExplanation)
	self.wndTransferConfirm:Invoke()
end

function AccountServices:OnFreeTransferYesBtn(wndHandler, wndControl) -- wndHandler is FreeTransferYesBtn, Data is nRealmId
	local bPaid = false
	-- Free won't need to care about nEscrowIndex
	CharacterScreenLib.RealmTransfer(self.nCharacterSelectedId, wndHandler:GetData().nRealmId, bPaid)
	self.wndTransferConfirm:Destroy()
end

function AccountServices:OnPaidTransferYesBtn(wndHandler, wndControl) -- wndHandler is TransferYesBtn, Data is nRealmId
	local bPaid = true
	local nRealmId = wndHandler:GetData().nRealmId
	local nEscrowIndex = wndHandler:GetData().nEscrowIndex

	if self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):IsChecked() then
		AccountItemLib.ClaimPendingSingleItem(nEscrowIndex)
		self.nFirePaidTransferOnUpdate = nRealmId
		-- HelperCatchTriggers will catch the event, detect a non nil self.nFirePaidTransferOnUpdate, then call Transfer
	else
		CharacterScreenLib.RealmTransfer(self.nCharacterSelectedId, nRealmId, bPaid)
	end
	self.wndTransferConfirm:Destroy()
end

function AccountServices:OnTransferConfirmNoBtn(wndHandler, wndControl)
	self.nFirePaidTransferOnUpdate = nil
	self.wndTransferConfirm:Destroy()
end

-----------------------------------------------------------------------------------------------
-- Free Transfer
-----------------------------------------------------------------------------------------------

function AccountServices:DrawFreeTransferFlyout()
	self.wndFreeTransferFlyout:FindChild("FreeTransferConfirmBtn"):Enable(false) -- Until grid is clicked
end

function AccountServices:OnFreeTransferGridClick(wndHandler, wndControl, iRow, iCol, eMouseButton)
	local wndGrid = self.wndFreeTransferFlyout:FindChild("FreeTransferGrid")
	local tRealmData = wndGrid:GetCellData(iRow, 1)
	local nRealmId = tRealmData.nRealmId

	local bClicked = wndGrid:GetData() ~= nRealmId
	if bClicked then
		wndGrid:SetData(nRealmId)
	else
		wndGrid:SetData(nil)
		wndGrid:SetCurrentRow(0) -- Deselect grid
	end

	self.wndFreeTransferFlyout:FindChild("FreeTransferConfirmBtn"):Enable(bClicked)
	self.wndFreeTransferFlyout:FindChild("FreeTransferConfirmBtn"):SetData({ nRealmId = nRealmId, strRealm = tRealmData.strName or "" })
	-- Clicking a grid row enables a button that will do FreeTransferConfirmBtn which will do ShowTransferConfirmation
end

function AccountServices:OnFreeTransferConfirmBtn(wndHandler, wndControl)
	local nRealmId = wndHandler:GetData().nRealmId
	local strRealm = wndHandler:GetData().strRealm
	local nCharacterId = self.nCharacterSelectedId
	if not nCharacterId then
		return
	end

	local bPaid = false
	self:ShowTransferConfirmation(bPaid, nRealmId, strRealm)
	self.wndFreeTransferFlyout:Close()
end

function AccountServices:OnFreeTransferFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndFreeTransferFlyout and self.wndFreeTransferFlyout:IsValid() then
		self.wndFreeTransferFlyout:Close()
	end
end

-----------------------------------------------------------------------------------------------
-- Paid Transfer
-----------------------------------------------------------------------------------------------

function AccountServices:DrawPaidTransferFlyout(nTransferBound, nTransferEscrow)
	local bBoundEnable = nTransferBound > 0
	local bEscrowEnable = nTransferEscrow > 0
	self.wndPaidTransferFlyout:FindChild("TransferPaymentBound"):Show(bBoundEnable)
	self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):Show(bEscrowEnable)
	self.wndPaidTransferFlyout:FindChild("TransferPaymentBound"):SetCheck(bBoundEnable)
	self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	self.wndPaidTransferFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nTransferBound))
	self.wndPaidTransferFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nTransferEscrow))
	self.wndPaidTransferFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndPaidTransferFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndPaidTransferFlyout:FindChild("TransferPaymentArrangeHorz"):ArrangeChildrenHorz(0)
	self.wndPaidTransferFlyout:FindChild("PaidTransferConfirmBtn"):Enable(false) -- Until grid is clicked
end

function AccountServices:OnPaidTransferGridClick(wndHandler, wndControl, iRow, iCol, eMouseButton)
	local wndGrid = self.wndPaidTransferFlyout:FindChild("PaidTransferGrid")
	local tRealmData = wndGrid:GetCellData(iRow, 1)
	local nRealmId = tRealmData.nRealmId

	local bClicked = wndGrid:GetData() ~= nRealmId
	if bClicked then
		wndGrid:SetData(nRealmId)
	else
		wndGrid:SetData(nil)
		wndGrid:SetCurrentRow(0) -- Deselect grid
	end

	self.wndPaidTransferFlyout:FindChild("PaidTransferConfirmBtn"):Enable(bClicked)
	self.wndPaidTransferFlyout:FindChild("PaidTransferConfirmBtn"):SetData({ nRealmId = nRealmId, strRealm = tRealmData.strName or "" })
	-- Clicking a grid row enables a button that will do FreeTransferConfirmBtn which will do ShowTransferConfirmation
end

function AccountServices:OnPaidTransferConfirmBtn(wndHandler, wndControl)
	local bUsingEscrow = self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):IsChecked()
	local tEscrowData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.RealmTransfer)

	local bPaid = true
	local nRealmId = wndHandler:GetData().nRealmId
	local strRealm = wndHandler:GetData().strRealm
	local nCharacterId = self.nCharacterSelectedId
	if not nCharacterId then
		return
	end

	if bGiftableGroup then
		local wndGroupBindConfirm = self:ShowGroupBindConfirmation(tEscrowData)
		wndGroupBindConfirm:SetData({ eType = keFireOnPaidTransfer, nRealmId = nRealmId })
	else
		self:ShowTransferConfirmation(bPaid, nRealmId, strRealm, tEscrowData)
	end

	self.wndPaidTransferFlyout:Close()
end

function AccountServices:OnPaidTransferFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndPaidTransferFlyout and self.wndPaidTransferFlyout:IsValid() then
		self.wndPaidTransferFlyout:Close()
	end
end

-----------------------------------------------------------------------------------------------
-- Confirmations
-----------------------------------------------------------------------------------------------

function AccountServices:HelperCheckTriggers()
	if self.strFireRenameOnUpdate ~= nil then
		CharacterScreenLib.RenameCharacter(self.nCharacterSelectedId, self.strFireRenameOnUpdate)
		self.strFireRenameOnUpdate = nil
		return
	end

	if self.bFireCreddOnUpdate ~= nil then
		AccountItemLib.RedeemCredd()
		self.bFireCreddOnUpdate = nil
		return
	end

	if self.nFirePaidTransferOnUpdate ~= nil then
		local bPaid = true
		CharacterScreenLib.RealmTransfer(self.nCharacterSelectedId, self.nFirePaidTransferOnUpdate, bPaid)
		self.nFirePaidTransferOnUpdate = nil
		return
	end
	-- Free Transfers not needed
end

function AccountServices:HelperDeterminePayment(bUsingEscrow, ePendingTypeRequested)
	local tEscrowData = nil
	local bGiftableGroup = bUsingEscrow

	-- First see if we have singles we can just use
	if bGiftableGroup then
		for idx, tPendingAccountItem in pairs(AccountItemLib.GetPendingAccountSingleItems()) do
			if tPendingAccountItem.accountCurrency and tPendingAccountItem.accountCurrency.accountCurrencyEnum == ePendingTypeRequested then
				tEscrowData = tPendingAccountItem
				bGiftableGroup = false
				break
			end
		end
	end

	-- If no singles, then pick the smallest group to use
	if bGiftableGroup then
		local nSmallestNumber = 0
		for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
			for idx2, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
				if tPendingAccountItem.accountCurrency and tPendingAccountItem.accountCurrency.accountCurrencyEnum == ePendingTypeRequested then
					local nCurrCount = #tPendingAccountItemGroup.items
					if nSmallestNumber == 0 or nCurrCount < nSmallestNumber then
						nSmallestNumber = nCurrCount
						tEscrowData = tPendingAccountItemGroup
					end
				end
			end
		end
	end

	return tEscrowData, bGiftableGroup
end

-----------------------------------------------------------------------------------------------
-- Error Messages
-----------------------------------------------------------------------------------------------

function AccountServices:OnErrorMessageClose(wndHandler, wndControl)
	if self.wndErrorMessage and self.wndErrorMessage:IsValid() then
		self.wndErrorMessage:Destroy()
	end
end

function AccountServices:OnRealmTransferResult(eResult)
	if self.wndErrorMessage and self.wndErrorMessage:IsValid() then
		self.wndErrorMessage:Destroy()
	end

	local bSuccess = eResult == PreGameLib.CodeEnumCharacterModifyResults.RealmTransferOk
	self.wndErrorMessage = Apollo.LoadForm(self.xmlDoc, "ErrorMessage", "AccountServices", self)
	self.wndErrorMessage:FindChild("ErrorMessageTitle"):SetText(bSuccess and Apollo.GetString("CRB_Success") or Apollo.GetString("CRB_Error"))
	self.wndErrorMessage:FindChild("ErrorMessageTitle"):SetTextColor(bSuccess and "UI_BtnTextGreenNormal" or "UI_BtnTextRedNormal")
	self.wndErrorMessage:FindChild("ErrorMessageBody"):SetText(Apollo.GetString(ktRealmTransferResults[eResult]))
end

-----------------------------------------------------------------------------------------------
-- Group Bind
-----------------------------------------------------------------------------------------------

function AccountServices:ShowGroupBindConfirmation(tEscrowData) -- In this case tEscrowData is a tPendingAccountItemGroup (instead of a tPendingAccountItem)
	-- The actual confirmation button will need to be protected
	self.wndGroupBindConfirm = Apollo.LoadForm(self.xmlDoc, "GroupBindConfirmation", "AccountServices", self)
	self.wndGroupBindConfirm:Invoke()
	self.wndGroupBindConfirm:FindChild("GroupBindTitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_BindGroupPurchases"), #tEscrowData.items))
	self.wndGroupBindConfirm:FindChild("GroupBindYesBtn"):SetData(tEscrowData.index)
	return self.wndGroupBindConfirm
end

function AccountServices:OnGroupBindYesBtn(wndHandler, wndControl) -- In this case tEscrowData is a tPendingAccountItemGroup (instead of a tPendingAccountItem)
	AccountItemLib.ClaimPendingItemGroup(wndHandler:GetData())

	if self.wndGroupBindConfirm:GetData().eType == keFireOnRename then
		self.bFireRenameOnUpdate = self.wndGroupBindConfirm:GetData().strText
	elseif self.wndGroupBindConfirm:GetData().eType == keFireOnCredd then
		self.bFireCreddOnUpdate = true
	elseif self.wndGroupBindConfirm:GetData().eType == keFireOnPaidTransfer then
		self.nFirePaidTransferOnUpdate = self.wndGroupBindConfirm:GetData().nRealmId
	end

	self.wndGroupBindConfirm:Destroy()
end

function AccountServices:OnGroupBindNoBtn(wndHandler, wndControl)
	self.wndGroupBindConfirm:Destroy()
end

-----------------------------------------------------------------------------------------------
-- Lapsed Account
-----------------------------------------------------------------------------------------------

function AccountServices:OnLapsedExitToLogin(wndHandler, wndControl)
	CharacterScreenLib.ExitToLogin()
end

function AccountServices:OnLapsedStartRedeemBtn(wndHandler, wndControl)
	-- Show the universal confirmation dialog
	self:ShowCreddRedemptionConfirmation()
end

local AccountServicesInst = AccountServices:new()
AccountServicesInst:Init()
