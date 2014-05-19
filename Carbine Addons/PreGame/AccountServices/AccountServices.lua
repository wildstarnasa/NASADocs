-----------------------------------------------------------------------------------------------
-- Client Lua Script for AccountServices
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "CharacterScreenLib"
require "AccountItemLib"

local AccountServices = {}
local keTransferOnCredd = "Transfer" -- Random Enum
local keFireOnRename = "Rename" -- Random Enum
local keFireOnCredd = "Credd" -- Random Enum

local ktRealmPopToString =
{
	Apollo.GetString("RealmPopulation_Low"),
	Apollo.GetString("RealmPopulation_Medium"),
	Apollo.GetString("RealmPopulation_High"),
	Apollo.GetString("RealmPopulation_Full"),
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
	local wndDebugPrint = Apollo.LoadForm(self.xmlDoc, "DebugPrint", "AccountServices", self)
	wndDebugPrint:SetText(wndDebugPrint:GetText() .. "\n" .. tostring(strMessage))
	wndDebugPrint:Show(true)
end

function AccountServices:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("AccountItemUpdate", 				"RedrawAll", self) -- Global catch all method
	Apollo.RegisterEventHandler("CharacterRename", 					"OnCharacterRename", self)
	Apollo.RegisterEventHandler("RealmTrasnferResult", 				"OnRealmTransferResult", self)
	Apollo.RegisterEventHandler("TransferDestinationRealmList", 	"OnTransferDestinationRealmList", self)
	--Apollo.RegisterEventHandler("SubscriptionUpdatedEvent", 		"OnSubscriptionUpdatedEvent", self) -- TODO: This isn't a real event yet

	Apollo.RegisterEventHandler("Pregame_CreationToSelection", 		"OnPregame_CreationToSelection", self)
	Apollo.RegisterEventHandler("Pregame_CharacterSelected", 		"OnPregame_CharacterSelected", self)
	Apollo.RegisterEventHandler("OpenCharacterCreateBtn", 			"OnOpenCharacterCreateBtn", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "AccountServicesForm", "AccountServices", self)
	self.wndMinimized = Apollo.LoadForm(self.xmlDoc, "MinimizedPicker", "AccountServices", self)

	self:RedrawAll() -- We need to call this on start up and with AccountItemUpdate, so it'll draw no matter what

	self.bFireRenameOnUpdate = nil
	self.bFireCreddOnUpdate = nil
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
	local bCanFreeRealmTransfer = false -- TODO: tMyRealmInfo and tMyRealmInfo.bFreeRealmTransfer or nil
	if bCanFreeRealmTransfer or math.max(nCreddBound, nCreddEscrow, nRenameBound, nRenameEscrow, nTransferBound, nTransferEscrow) > 0 then
		local bDefaultMinimized = false -- TODO, Console Variable or saved setting
		self.wndMain:Show(not bDefaultMinimized, true)
		self.wndMinimized:Show(bDefaultMinimized, true)

		self.wndCreddFlyout = self:DrawCreddFlyout(nCreddBound, nCreddEscrow)
		self.wndRenameFlyout = self:DrawRenameFlyout(nRenameBound, nRenameEscrow)
		self.wndTransferFlyout = self:DrawTransferFlyout(nTransferBound, nTransferEscrow)
		self.wndMainPicker = self.wndMain:FindChild("MainPicker")
		self.wndMainPicker:FindChild("AvailablePaidCreddBtn"):AttachWindow(self.wndCreddFlyout)
		self.wndMainPicker:FindChild("AvailablePaidRenameBtn"):AttachWindow(self.wndRenameFlyout)
		self.wndMainPicker:FindChild("AvailablePaidRealmBtn"):AttachWindow(self.wndTransferFlyout)
		-- TODO More Windows

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
		wndMainPickerButtonList:ArrangeChildrenVert(0)
	end
end

-----------------------------------------------------------------------------------------------
-- Main Picker
-----------------------------------------------------------------------------------------------

function AccountServices:OnPregame_CharacterSelected(nId, strName)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("CharacterPortrait"):SetData(nId)
		self.wndMain:FindChild("CharacterName"):SetData(strName)
		self.wndMain:FindChild("CharacterName"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_ServicesFor"), strName))

		if CharacterScreenLib then
			CharacterScreenLib.ApplyCharacterToCostumeWindow(nId, self.wndMain:FindChild("CharacterPortrait"))
		end

		self:OnRenameCloseBtn()
		-- TODO MORE
	end
end

function AccountServices:OnOpenCharacterCreateBtn() -- Generic Event, not a btn click
	self:OnHideMainPicker()
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

function AccountServices:OnSubscriptionUpdatedEvent() -- TODO: This needs to be a code event, currently this is a button
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
end

function AccountServices:OnCloseRedeemConfirmation(wndHandler, wndControl)
	if self.wndCreddConfirm and self.wndCreddConfirm:IsValid() then
		self.wndCreddConfirm:Destroy()
	end
end

-----------------------------------------------------------------------------------------------
-- Credd
-----------------------------------------------------------------------------------------------

function AccountServices:DrawCreddFlyout(nCreddBound, nCreddEscrow)
	local bBoundEnable = nCreddBound > 0
	local bEscrowEnable = nCreddEscrow > 0
	local wndCreddFlyout = self.wndMain:FindChild("CreddFlyout")
	wndCreddFlyout:FindChild("CreddPaymentBound"):Show(bBoundEnable)
	wndCreddFlyout:FindChild("CreddPaymentEscrow"):Show(bEscrowEnable)
	wndCreddFlyout:FindChild("CreddPaymentBound"):SetCheck(bBoundEnable)
	wndCreddFlyout:FindChild("CreddPaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	wndCreddFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nCreddBound))
	wndCreddFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nCreddEscrow))
	wndCreddFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	wndCreddFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	wndCreddFlyout:FindChild("CreddPaymentArrangeVert"):ArrangeChildrenVert(0)
	return wndCreddFlyout
end

function AccountServices:OnCreddFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndCreddFlyout and self.wndCreddFlyout:IsValid() then
		self.wndCreddFlyout:Close()
	end
end

function AccountServices:OnCreddConfirmBtn(wndHandler, wndControl)
	local bUsingEscrow = self.wndCreddFlyout:FindChild("CreddPaymentEscrow"):IsChecked()
	local tPaymentData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.CREDD)

	local strText = wndHandler:GetData()
	local nCharacterId = self.wndMain:FindChild("CharacterPortrait"):GetData()
	if not nCharacterId then
		return
	end

	if bGiftableGroup then
		local wndGroupBindConfirm = self:ShowGroupBindConfirmation(tPaymentData)
		wndGroupBindConfirm:SetData({ keFireOnCredd, true})
	elseif bUsingEscrow then
		AccountItemLib.ClaimPendingSingleItem(tPaymentData.index)
		self.bFireCreddOnUpdate = true
	else
		--AccountItemLib.RedeemCREDD() -- TODO: We might not need any data for Credd
		-- Show the universal confirmation dialog
		self:ShowCreddRedemptionConfirmation()
	end

	self.wndCreddFlyout:Close()
end

-----------------------------------------------------------------------------------------------
-- Rename
-----------------------------------------------------------------------------------------------

function AccountServices:DrawRenameFlyout(nRenameBound, nRenameEscrow)
	local bBoundEnable = nRenameBound > 0
	local bEscrowEnable = nRenameEscrow > 0
	local wndRenameFlyout = self.wndMain:FindChild("RenameFlyout")
	wndRenameFlyout:FindChild("RenameConfirmBtn"):Enable(false)
	wndRenameFlyout:FindChild("RenamePaymentBound"):Show(bBoundEnable)
	wndRenameFlyout:FindChild("RenamePaymentEscrow"):Show(bEscrowEnable)
	wndRenameFlyout:FindChild("RenamePaymentBound"):SetCheck(bBoundEnable)
	wndRenameFlyout:FindChild("RenamePaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	wndRenameFlyout:FindChild("RenameInputBox"):SetPrompt(self.wndMain:FindChild("CharacterName"):GetData() or Apollo.GetString("AccountServices_NewName"))
	wndRenameFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nRenameBound))
	wndRenameFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nRenameEscrow))
	wndRenameFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	wndRenameFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	wndRenameFlyout:FindChild("RenamePaymentArrangeVert"):ArrangeChildrenVert(0)
	return wndRenameFlyout
end

function AccountServices:OnRenameCloseBtn(wndHandler, wndControl)
	if self.wndRenameFlyout and self.wndRenameFlyout:IsValid() then
		self.wndRenameFlyout:FindChild("RenameInputBox"):SetText("")
		self.wndRenameFlyout:Close()
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
	local tPaymentData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.NameChange)

	local strText = wndHandler:GetData()
	local nCharacterId = self.wndMain:FindChild("CharacterPortrait"):GetData()
	if not nCharacterId then
		return
	end

	if bGiftableGroup then
		local tRelevantCreddDataToPassOn = { true } -- TODO, if needed
		local wndGroupBindConfirm = self:ShowGroupBindConfirmation(tPaymentData)
		wndGroupBindConfirm:SetData({ keFireOnRename, tRelevantCreddDataToPassOn })
	elseif bUsingEscrow then
		AccountItemLib.ClaimPendingSingleItem(tPaymentData.index)
		self.bFireRenameOnUpdate = { nCharacterId, strText }
	else
		CharacterScreenLib.RenameCharacter(nCharacterId, strText) -- May lead to OnCharacterRename fail, handled by CharacterSelect.lua
	end

	self.wndRenameFlyout:Close()
end

-----------------------------------------------------------------------------------------------
-- Transfer
-----------------------------------------------------------------------------------------------

function AccountServices:DrawTransferFlyout(nTransferBound, nTransferEscrow)
	local bBoundEnable = nTransferBound > 0
	local bEscrowEnable = nTransferEscrow > 0

	local strCharacterName = self.wndMain:FindChild("CharacterName"):GetData() or ""
	local wndTransferFlyout = self.wndMain:FindChild("TransferFlyout")
	wndTransferFlyout:FindChild("TransferPaymentBound"):Show(bBoundEnable)
	wndTransferFlyout:FindChild("TransferPaymentEscrow"):Show(bEscrowEnable)
	wndTransferFlyout:FindChild("TransferPaymentBound"):SetCheck(bBoundEnable)
	wndTransferFlyout:FindChild("TransferPaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	wndTransferFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nTransferBound))
	wndTransferFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nTransferEscrow))
	wndTransferFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	wndTransferFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	wndTransferFlyout:FindChild("TransferPaymentArrangeVert"):ArrangeChildrenVert(0)

	-- TODO
	wndTransferFlyout:FindChild("TransferConfirmBtn"):Enable(false) -- TEMP
	--wndTransferFlyout:FindChild("TransferChecklistText"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_ReadyToTransfer"), strCharacterName))

	CharacterScreenLib.GetRealmTransferDestinations() -- Leads to TransferDestinationRealmList
	return wndTransferFlyout
end

function AccountServices:OnTransferDestinationRealmList(tRealmList)
	if not self.wndTransferFlyout and not self.wndTransferFlyout:IsValid() then
		return
	end

	-- Helper Method
	local function HelperGridFactoryProduce(wndGrid, tTargetComparison)
		for nRow = 1, wndGrid:GetRowCount() do
			if wndGrid:GetCellLuaData(nRow, 1) == tTargetComparison then -- GetCellLuaData args are row, col
				return nRow
			end
		end
		return wndGrid:AddRow("") -- GOTCHA: This is a row number
	end

	-- Build Grid
	local tMyRealmInfo = CharacterScreenLib.GetRealmInfo()
	local wndGrid = self.wndMain:FindChild("TransferFlyout:TransferGrid")
	for idx, tCurr in pairs(tRealmList) do
		-- Realm Name + Character Count
		local strRealmName = tCurr.strName
		if tMyRealmInfo.strName == tCurr.strName then
			strRealmName = "<T Image=\"CRB_Basekit:kitIcon_Holo_Forward\"></T>" .. PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RealmNameNum"), tCurr.strName, tCurr.nCount)
		elseif tCurr.nCount > 0 then
			strRealmName = "<T Image=\"CRB_Basekit:kitIcon_Holo_Profile\"></T>" .. PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RealmNameNum"), tCurr.strName, tCurr.nCount)
		end

		-- Saves repeating code
		local tCellStrings =
		{
			strRealmName,
			tCurr.nRealmPVPType == PreGameLib.CodeEnumRealmPVPType.PVP and Apollo.GetString("RealmSelect_PvP") or Apollo.GetString("RealmSelect_PvE"),
			ktRealmPopToString[tCurr.nPopulation + 1],
			tCurr.bIsFree and Apollo.GetString("CRB_Yes") or Apollo.GetString("CRB_No"),
		}

		local wndCurrRow = HelperGridFactoryProduce(wndGrid, tCurr.strName) -- GOTCHA: This is an integer
		wndGrid:SetCellLuaData(wndCurrRow, 1, tCurr.strName)
		for idx, strCellString in pairs(tCellStrings) do
			wndGrid:SetCellSortText(wndCurrRow, idx, strCellString)
			wndGrid:SetCellDoc(wndCurrRow, idx, string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>", strCellString))
		end
	end
end

function AccountServices:OnTransferGridClick(wndHandler, wndControl, iRow, iCol, eMouseButton)
	local wndGrid = self.wndMain:FindChild("TransferFlyout:TransferGrid")
	local wndData = wndGrid:GetCellData(iRow, 1)

	local bClicked = wndGrid:GetData() ~= wndData
	if bClicked then
		wndGrid:SetData(wndData)
	else
		wndGrid:SetData(nil)
		wndGrid:SetCurrentRow(0) -- Deselect grid
	end

	self.wndTransferFlyout:FindChild("TransferConfirmBtn"):Enable(bClicked and false) -- TODO
end

function AccountServices:OnRealmTransferResult(eResult) -- Same enum as OnCharacterRename
	-- PreGameLib.CodeEnumCharacterModifyResults.RenameFailed_Internal
	-- TODO
end

function AccountServices:OnTransferFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndTransferFlyout and self.wndTransferFlyout:IsValid() then
		self.wndTransferFlyout:Close()
	end
end

function AccountServices:OnTransferConfirmBtn(wndHandler, wndControl)
	local bUsingEscrow = self.wndTransferFlyout:FindChild("TransferPaymentEscrow"):IsChecked()
	local tPaymentData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.RealmTransfer)

	local strText = wndHandler:GetData()
	local nCharacterId = self.wndMain:FindChild("CharacterPortrait"):GetData()
	if not nCharacterId then
		return
	end

	if bGiftableGroup then
		local wndGroupBindConfirm = self:ShowGroupBindConfirmation(tPaymentData)
		wndGroupBindConfirm:SetData({ keTransferOnCredd, true})
	elseif bUsingEscrow then
		AccountItemLib.ClaimPendingSingleItem(tPaymentData.index)
		self.bFireTransferOnUpdate = true
	else
		-- TODO Not yet implemented
	end

	self.wndCreddFlyout:Close()
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

-----------------------------------------------------------------------------------------------
-- Confirmations
-----------------------------------------------------------------------------------------------

function AccountServices:HelperCheckTriggers()
	if self.bFireRenameOnUpdate ~= nil then
		CharacterScreenLib.RenameCharacter(self.bFireRenameOnUpdate[1], self.bFireRenameOnUpdate[2])
		self.bFireRenameOnUpdate = nil
		return
	end

	if self.bFireCreddOnUpdate ~= nil then
		--AccountItemLib.RedeemCREDD() -- TODO: self.bFireCreddOnUpdate if needed
		-- Show the universal confirmation dialog
		self:ShowCreddRedemptionConfirmation()
		self.bFireCreddOnUpdate = nil
		return
	end

	if self.bFireTransferOnUpdate ~= nil then
		-- TODO Not yet implemented
		self.bFireTransferOnUpdate = nil
		return
	end
end

function AccountServices:HelperDeterminePayment(bUsingEscrow, ePendingTypeRequested)
	local tPaymentData = nil
	local bGiftableGroup = bUsingEscrow

	-- First see if we have singles we can just use
	if bGiftableGroup then
		for idx, tPendingAccountItem in pairs(AccountItemLib.GetPendingAccountSingleItems()) do
			if tPendingAccountItem.accountCurrency and tPendingAccountItem.accountCurrency.accountCurrencyEnum == ePendingTypeRequested then
				tPaymentData = tPendingAccountItem
				bGiftableGroup = false
				break
			end
		end
	end

	-- If no single tons, then pick the smallest group to use
	if bGiftableGroup then
		local nSmallestNumber = 0
		for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
			for idx2, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
				if tPendingAccountItem.accountCurrency and tPendingAccountItem.accountCurrency.accountCurrencyEnum == ePendingTypeRequested then
					local nCurrCount = #tPendingAccountItemGroup.items
					if nSmallestNumber == 0 or nCurrCount < nSmallestNumber then
						nSmallestNumber = nCurrCount
						tPaymentData = tPendingAccountItemGroup
					end
				end
			end
		end
	end

	return tPaymentData, bGiftableGroup
end

function AccountServices:ShowGroupBindConfirmation(tPaymentData) -- In this case tPaymentData is a tPendingAccountItemGroup (instead of a tPendingAccountItem)
	-- The actual confirmation button will need to be protected
	self.wndGroupBindConfirm = Apollo.LoadForm(self.xmlDoc, "GroupBindConfirmation", "AccountServices", self)
	self.wndGroupBindConfirm:Invoke()
	self.wndGroupBindConfirm:FindChild("GroupBindTitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_BindGroupPurchases"), #tPaymentData.items))
	self.wndGroupBindConfirm:FindChild("GroupBindYesBtn"):SetData(tPaymentData)
	return self.wndGroupBindConfirm
end

function AccountServices:OnGroupBindYesBtn(wndHandler, wndControl) -- In this case tPaymentData is a tPendingAccountItemGroup (instead of a tPendingAccountItem)
	local tPaymentData = wndHandler:GetData()
	AccountItemLib.ClaimPendingItemGroup(tPaymentData.index)

	if self.wndGroupBindConfirm:GetData()[1] == keFireOnRename then
		self.bFireRenameOnUpdate = self.wndGroupBindConfirm:GetData()[2]
	elseif self.wndGroupBindConfirm:GetData()[1] == keFireOnCredd then
		self.bFireCreddOnUpdate = self.wndGroupBindConfirm:GetData()[2]
	end
	-- TODO More Windows
	self.wndGroupBindConfirm:Destroy()
end

function AccountServices:OnGroupBindNoBtn(wndHandler, wndControl)
	self.wndGroupBindConfirm:Destroy()
end

function AccountServices:ShowCreddRedemptionConfirmation()
	if self.wndCreddConfirm and self.wndCreddConfirm:IsValid() then
		self.wndCreddConfirm:Destroy()
	end

	if self.wndLapsedPopup and self.wndLapsedPopup:IsValid() then
		self.wndLapsedPopup:Destroy()
	end

	-- The actual confirmation button will need to be protected
	self.wndCreddConfirm = Apollo.LoadForm(self.xmlDoc, "RedeemCREDDConfirmation", "AccountServices", self)
	self.wndCreddConfirm:Invoke()
end

local AccountServicesInst = AccountServices:new()
AccountServicesInst:Init()
