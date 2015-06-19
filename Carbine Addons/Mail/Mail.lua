require "Window"
require "MailSystemLib"
require "GameLib"
require "Apollo"

local Mail 			= {}
local MailCompose 	= {}
local MailReceived 	= {}

local kstrNewMailIcon 	= "Icon_Windows_UI_NewMail"
local kstrReadMailIcon 	= "Icon_Windows_UI_ReadMail"
local kstrGMIcon 		= "Icon_Windows_UI_GMIcon"
local kstrPCIcon 		= "Icon_Windows_UI_PCIcon"
local kstrNPCIcon 		= "Icon_Windows_UI_NPCIcon"

local kstrInvalidAttachmentIcon = "ClientSprites:WhiteFlash"

local kcrAttachmentIconValidColor 	= ApolloColor.new("UI_TextHoloBodyCyan")
local kcrAttachmentIconInvalidColor = ApolloColor.new("xkcdReddish")

local kcrTextDefaultColor 	= CColor.new(0.7, 0.7, 0.7, 1.0)
local kcrTextWarningColor 	= CColor.new(0.7, 0.7, 0.0, 1.0)
local kcrTextExpiringColor 	= CColor.new(0.7, 0.0, 0.0, 1.0)

local knOpenMailThreshold = 5

local knSaveVersion = 1

function Mail:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function Mail:Init()
	Apollo.RegisterAddon(self, false, "", {"Util"})
end

function Mail:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	strId = next(self.tOpenMailMessages)

	local locMessageWindowLocation = strId and self.tOpenMailMessages[strId].wndMain and self.tOpenMailMessages[strId].wndMain:GetLocation() or self.locSavedMessageWindowLoc
	local tSave =
	{
		tMessageLocation = locMessageWindowLocation and locMessageWindowLocation:ToTable() or nil,
		nSavedVersion = knSaveVersion,
	}

	return tSave
end

function Mail:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSavedVersion  == knSaveVersion then
		if tSavedData.tMessageLocation then
			self.locSavedMessageWindowLoc = WindowLocation.new(tSavedData.tMessageLocation)
		end
	end
end

function Mail:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MailForms.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Mail:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("SubZoneChanged", 			"CalculateMailAlert", self)
	Apollo.RegisterEventHandler("AvailableMail", 			"OnAvailableMail", self)
	Apollo.RegisterEventHandler("UnavailableMail", 			"OnUnavailableMail", self)
	Apollo.RegisterEventHandler("RefreshMail", 				"OnRefreshMail", self)
	Apollo.RegisterEventHandler("ToggleMailWindow", 		"ToggleWindow", self)
	Apollo.RegisterEventHandler("MailRead",					"OnMailRead", self)
	Apollo.RegisterEventHandler("MailBoxActivate", 			"OnMailBoxActivate", self)
	Apollo.RegisterEventHandler("MailBoxDeactivate", 		"OnMailBoxDeactivate", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 	"OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("MailResult",				"OnMailResult", self)
	Apollo.RegisterEventHandler("MailAddAttachment",		"OnMailAddAttachment", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", "OnTutorial_RequestUIAnchor", self)

	Apollo.RegisterSlashCommand("ToggleMailWindow", 		"ToggleWindow", self)	--Don't know if we have this in the C

	self.wndMain		= Apollo.LoadForm(self.xmlDoc, "MailForm", nil, self) --Our main form.
	self.wndMailList 	= self.wndMain:FindChild("MailWindow")  --The window that populates with the mail items
	self.wndErrorMsg 	= nil
	self.wndToggleAllBtn = self.wndMain:FindChild("ToggleAllBtn")
	
	self.wndActionsBtn = self.wndMain:FindChild("ActionsBtn")
	self.wndActionPopout = self.wndActionsBtn:FindChild("PopoutFrame")
	self.wndActionsBtn:AttachWindow(self.wndActionPopout)
	
	self.wndDeleteBtn = self.wndActionPopout:FindChild("PopoutList:DeleteBtn")
	self.wndTakeBtn = self.wndActionPopout:FindChild("PopoutList:TakeBtn")
	self.wndMarkReadBtn = self.wndActionPopout:FindChild("PopoutList:MarkReadBtn")
	
	self.wndConfirmDeleteBlocker = self.wndMain:FindChild("ConfirmDeleteBlocker")
	self.wndConfirmOpenBlocker = self.wndMain:FindChild("ConfirmOpenBlocker")
	self.wndConfirmTakeBlocker = self.wndMain:FindChild("ConfirmTakeBlocker")
	
	self.wndActionsBtn:Enable(false) -- start disabled as no mail starts checked
	
	self.wndMain:Show(false)
	self.tMailItemWnds = {}
	self.tOpenMailMessages = {}
	self.arMailToUpdate = {}
	self.arMailToOpen = {}
	self.nCascade = 0
	self.strPendingCOD = ""
	
	self.timerMailUpdateDelay = ApolloTimer.Create(0.5, true, "UpdateMailItemsTimer", self)

	self:CalculateMailAlert()
end

function Mail:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Mail"), {"ToggleMailWindow", "Mail", "Icon_Windows32_UI_CRB_InterfaceMenu_Mail"})
	self:CalculateMailAlert()
end

function Mail:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_Mail")})
end

function Mail:OnPlayerCurrencyChanged()
	if self.luaComposeMail ~= nil then
		self.luaComposeMail:OnPlayerCurrencyChanged()
	end

	for idx, luaOpenMail in pairs(self.tOpenMailMessages) do
		luaOpenMail:OnPlayerCurrencyChanged()
	end
end

function Mail:OpenMailWindow()
	if not self.wndMain:IsShown() then
		self.wndMain:Invoke()
	end
	self.wndConfirmDeleteBlocker:Show(false)
	self.wndMain:ToFront()
	Sound.Play(Sound.PlayUI68OpenPanelFromKeystrokeVirtual)
	self:PopulateList()
	Event_FireGenericEvent("MailWindowHasBeenToggled")
	Event_ShowTutorial(GameLib.CodeEnumTutorial.MailMenu)
end

function Mail:CloseMailWindow()
	self:CalculateMailAlert()
	self.wndMain:Close()
	Sound.Play(Sound.PlayUI01ClosePhysical)
	Event_FireGenericEvent("MailWindowHasBeenClosed")
	Event_CancelMail()
end

function Mail:OnMainMailWindowClosed(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	for idx, wndMail in pairs(self.tMailItemWnds) do
		if wndMail:IsValid() then
			wndMail:FindChild("SelectMarker"):SetCheck(false)
		end
	end
	self.wndToggleAllBtn:SetCheck(false)
	self:RefreshActionsButton()
end

function Mail:ToggleWindow()
	if self.wndMain:IsShown() then
		self:CloseMailWindow()
	else
		self:OpenMailWindow()
	end

	if self.luaComposeMail ~= nil then
		self.luaComposeMail:UpdateControls()
	end
end

function Mail:OnMailBoxActivate()
	self:OpenMailWindow()
end

function Mail:OnMailBoxDeactivate()
	if self.luaComposeMail ~= nil then
		self.luaComposeMail:UpdateControls()
	end
end

function Mail:DestroyList()
	for idx, wndListItem in pairs(self.tMailItemWnds) do
		wndListItem:Destroy()
	end
	self.tMailItemWnds = {}
end

function Mail.SortMailItems(a, b)
	local bIsAGm = a:GetSenderType() == MailSystemLib.EmailType_GMMail
	local bIsBGm = b:GetSenderType() == MailSystemLib.EmailType_GMMail
	if bIsAGm == bIsBGm then
		return a:GetExpirationTime() > b:GetExpirationTime()
	end
	return bIsAGm
end

function Mail.SortMailWindows(wndA, wndB)
	local a = wndA:GetData()
	local b = wndB:GetData()

	local bIsAGm = a:GetSenderType() == MailSystemLib.EmailType_GMMail
	local bIsBGm = b:GetSenderType() == MailSystemLib.EmailType_GMMail
	if bIsAGm == bIsBGm then
		return a:GetExpirationTime() > b:GetExpirationTime()
	end
	return bIsAGm
end

function Mail:CascadeWindow(wndMailItem)
	local nLeft, nTop, nRight, nBottom = wndMailItem:GetRect()
	local nWidth = nRight - nLeft
	local nHeight = nBottom - nTop

	local tDisplay = Apollo.GetDisplaySize()
	if tDisplay and tDisplay.nWidth and tDisplay.nHeight then
		local nMaxLeft = tDisplay.nWidth - nWidth
		local nMaxTop = tDisplay.nHeight - nHeight

		local nNewLeft = nLeft + self.nCascade * 25
		local nNewTop = nTop + self.nCascade * 25

		nNewLeft = nNewLeft <= nMaxLeft and nNewLeft or nMaxLeft
		nNewTop = nNewTop <= nMaxTop and nNewTop or nMaxTop

		wndMailItem:Move(nNewLeft, nNewTop, nWidth, nHeight)

		self.nCascade = self.nCascade + 1
		if self.nCascade == 8 then
			self.nCascade = 0
		end
	end
end

function Mail:PopulateList()
	local arMessages = MailSystemLib.GetInbox()

	local tCurrentMail = {}
	for strId, wndMail in pairs(self.tMailItemWnds) do
		tCurrentMail[strId] = wndMail
	end

	-- setup new MailItemWnds for primary mail pannel.
	for idx, msgMail in pairs(arMessages) do
		local strId = msgMail:GetIdStr()
	
		local wndMailItem = self.tMailItemWnds[strId]
		if wndMailItem == nil or not wndMailItem:IsValid() then
			wndMailItem = Apollo.LoadForm(self.xmlDoc, "MailItem", self.wndMailList, self)
			wndMailItem:Show(false, true)
			
			self.wndToggleAllBtn:SetCheck(false)
		end
		wndMailItem:SetData(msgMail)
		
		self:AddMailToUpdateTime(strId, wndMailItem)

		self.tMailItemWnds[strId] = wndMailItem
		tCurrentMail[strId] = nil
	end
	
	for strId, wndMail in pairs(tCurrentMail) do
		self.tMailItemWnds[strId]:Destroy()
		self.tMailItemWnds[strId] = nil
		
		if self.tOpenMailMessages[strId] ~= nil then
			self.tOpenMailMessages[strId].wndMain:Destroy()
			self.tOpenMailMessages[strId] = nil
		end
	end

	self.wndMailList:ArrangeChildrenVert(0, Mail.SortMailWindows)
	self:CalculateMailAlert()
	
	self:RefreshActionsButton()
end

function Mail:AddMailToUpdateTime(strId, wndMail)
	self.arMailToUpdate[strId] = wndMail
	self.timerMailUpdateDelay:Start()
end

function Mail:AddMailToOpenTimer(mail)
	if mail == nil then
		return
	end
	
	local strId = mail:GetIdStr()
	if strId == nil then
		return
	end

	self.arMailToOpen[strId] = mail
	self.timerMailUpdateDelay:Start()
end

function Mail:UpdateMailItemsTimer()
	local nCurrentTime = GameLib.GetTickCount()
	
	if next(self.arMailToUpdate) ~= nil then
		local tSorted = {}
		for idx, wndMail in pairs(self.arMailToUpdate) do
			if wndMail:IsValid() then
				tSorted[#tSorted + 1] = wndMail:GetData()
			end
		end
		table.sort(tSorted, Mail.SortMailItems)
		
		for idx, mail in pairs(tSorted) do
			local strId = mail:GetIdStr()
			local wndMail = self.arMailToUpdate[strId]
			if wndMail:IsValid() then
				self:UpdateListItem(wndMail, wndMail:GetData())
				wndMail:Show(true)
			end
			
			self.arMailToUpdate[strId] = nil
			
			if GameLib.GetTickCount() - nCurrentTime > 100 then
				self.wndMailList:ArrangeChildrenVert(0, Mail.SortMailWindows)
				return
			end
		end
		
		self.wndMailList:ArrangeChildrenVert(0, Mail.SortMailWindows)
	end
	
	local arMailOpened = {}
	
	local idxMailToOpen = next(self.arMailToOpen)
	while idxMailToOpen ~= nil do
		local mailToOpen = self.arMailToOpen[idxMailToOpen]
		self.arMailToOpen[idxMailToOpen] = nil
		
		self:OpenReceivedMessage(mailToOpen)
		arMailOpened[#arMailOpened + 1] = mailToOpen
		
		if GameLib.GetTickCount() - nCurrentTime > 100 then
			MailSystemLib.MarkMultipleMessagesAsRead(arMailOpened)
			return
		end
		idxMailToOpen = next(self.arMailToOpen)
	end
	if #arMailOpened > 0 then
		MailSystemLib.MarkMultipleMessagesAsRead(arMailOpened)
	end
	
	self.timerMailUpdateDelay:Stop()
end

function Mail:CalculateMailAlert()
	local nUnreadMessages = 0
	for idx, tMessage in pairs(MailSystemLib.GetInbox()) do
		local tMessageInfo = tMessage:GetMessageInfo()

		if tMessageInfo and not tMessageInfo.bIsRead then
			nUnreadMessages = nUnreadMessages + 1
		end
	end

	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", Apollo.GetString("InterfaceMenu_Mail"), {nUnreadMessages > 0, nil, nUnreadMessages})
end

function Mail:OnAvailableMail(arItems, bNewMail)
	-- arItems has a list of new mail available from MailSystemLib.GetInbox()
	-- bNewMail is true when one of the mail is a new item.

	if not self.wndMain:IsVisible() then
		self:CalculateMailAlert()
		return
	end

	self:PopulateList()
end

function Mail:OnUnavailableMail(arMailIds)
	-- list of id strings that are no longer available from MailSystemLib.GetInbox()
	if not self.wndMain:IsVisible() then
		self:CalculateMailAlert()
		return
	end

	local nScrollPos = self.wndMailList:GetVScrollPos()
	
	local bChangeMade = false
	for idx, strMailId in pairs(arMailIds) do
		if self.tMailItemWnds[strMailId] ~= nil then
			self.tMailItemWnds[strMailId]:Destroy()
			self.tMailItemWnds[strMailId] = nil
			bChangeMade = true
		end
	end
	
	if bChangeMade then
		self.wndMailList:ArrangeChildrenVert()
		self.wndMailList:SetVScrollPos(nScrollPos)
	
		self:CalculateMailAlert()
	end
end

function Mail:OnRefreshMail(strMailId)
	if not self.wndMain:IsVisible() then
		return
	end

	if self.tMailItemWnds[strMailId] ~= nil then
		self:AddMailToUpdateTime(strMailId, self.tMailItemWnds[strMailId])
	end
	
	if self.tOpenMailMessages[strMailId] ~= nil then
		self.tOpenMailMessages[strMailId]:UpdateControls()
	end

	self.strPendingCOD = ""
end

function Mail:OnMailRead(strMailId)
	if self.tMailItemWnds[strMailId] ~= nil then
		self:AddMailToUpdateTime(strMailId, self.tMailItemWnds[strMailId])
	end
end

function Mail:OnMailResult(eResult)
	local tMailResultError =
	{
		[GameLib.CodeEnumGenericError.Mail_CannotFindPlayer] 			= 	"GenericError_Mail_CannotFindPlayer",
		[GameLib.CodeEnumGenericError.Mail_FailedToCreate] 				= 	"GenericError_Mail_FailedToCreate",
		[GameLib.CodeEnumGenericError.Mail_InsufficientFunds] 			= 	"GenericError_Mail_InsufficientFunds",
		[GameLib.CodeEnumGenericError.Mail_MailBoxOutOfRange] 			= 	"GenericError_Mail_MailBoxOutOfRange",
		[GameLib.CodeEnumGenericError.Mail_UniqueExists] 				= 	"GenericError_Mail_UniqueExists",
		[GameLib.CodeEnumGenericError.Mail_NoAttachment] 				= 	"GenericError_Mail_NoAttachment",
		[GameLib.CodeEnumGenericError.Player_CannotWhileInCombat] 		= 	"GenericError_Player_CannotWhileInCombat",
		[GameLib.CodeEnumGenericError.Mail_Busy] 						= 	"GenericError_Mail_Busy",
		[GameLib.CodeEnumGenericError.Mail_DoesNotExist] 				= 	"GenericError_Mail_DoesNotExist",
		[GameLib.CodeEnumGenericError.Mail_CannotDelete] 				= 	"GenericError_Mail_CannotDelete",
		[GameLib.CodeEnumGenericError.Mail_InvalidInventorySlot] 		= 	"GenericError_Mail_InvalidInventorySlot",
		[GameLib.CodeEnumGenericError.Mail_CannotTransferItem] 			= 	"GenericError_Mail_CannotTranferItem",
		[GameLib.CodeEnumGenericError.Mail_InvalidText] 				= 	"GenericError_Mail_InvalidText",
		[GameLib.CodeEnumGenericError.Mail_CanNotHaveCoDAndGift] 		= 	"GenericError_Mail_CanNotHaveCoDAndGift",
		[GameLib.CodeEnumGenericError.Mail_CannotMailSelf] 				= 	"GenericError_Mail_CannotMailSelf",
		[GameLib.CodeEnumGenericError.Mail_CannotReturn] 				= 	"GenericError_Mail_CannotReturn",
		[GameLib.CodeEnumGenericError.Item_InventoryFull]				=   "GenericError_Item_InventoryFull",
		[GameLib.CodeEnumGenericError.MissingEntitlement]				=   "GenericError_Mail_GuestAccount",
		[GameLib.CodeEnumGenericError.Mail_Squelched] 					= 	"GenericError_Mail_Squelched"
	}

	local tMailHeaderError =
	{
		[GameLib.CodeEnumGenericError.Item_InventoryFull]				=	"CRB_Mail"
	}

	if tMailResultError[eResult] then
		if self.wndErrorMsg == nil then
			self.wndErrorMsg = Apollo.LoadForm(self.xmlDoc, "ErrorMessage", nil, self)
		end

		local strErrorHeader = tMailHeaderError[eResult] and Apollo.GetString(tMailHeaderError[eResult]) or Apollo.GetString("CRB_Mail_ErrorGeneric")
		self.wndErrorMsg:FindChild("ErrorMessageHeader"):SetText(strErrorHeader)
		local wndErrorMessageBodyText = self.wndErrorMsg:FindChild("ErrorMessageBodyText")
		
		local nOrigHeight = wndErrorMessageBodyText:GetHeight()
		wndErrorMessageBodyText:SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">"..Apollo.GetString(tMailResultError[eResult]).."</P>")
		wndErrorMessageBodyText:SetHeightToContentHeight()
		local nNewHeight = wndErrorMessageBodyText:GetHeight()
		
		--If enough text to require a resizing then make bigger.
		if nOrigHeight < nNewHeight then
			local nLeft, nTop, nRight, nBottom = self.wndErrorMsg:GetAnchorOffsets()
			self.wndErrorMsg:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + (nNewHeight - nOrigHeight))
		end
		self.wndErrorMsg:Invoke()
	end
end

function Mail:OnMailAddAttachment(nValue)
	-- this is done here incase someone wants to make
	if self.luaComposeMail ~= nil then
		self.luaComposeMail:WindowToFront()
		self.luaComposeMail:OnMailAddAttachment(nValue)
	end
end

function Mail:OnCloseErrorBtn(wndHandler, wndControl)
	if self.wndErrorMsg then
		self.wndErrorMsg:Close()
		self.wndErrorMsg:Destroy()
		self.wndErrorMsg = nil
	else
		local wndParent = wndControl:GetParent()
		wndParent:Close()
		wndParent:Destroy()
	end
end


--------------------/Mail Form Controls/-----------------------------
function Mail:RefreshActionsButton()
	local bCanTake = false
	local bCanDelete = false
	local bHasSelection = false
	local bCanMarkRead = false
	
	for idx, wndMail in pairs(self.tMailItemWnds) do
		local mail = wndMail:GetData()
		local tInfo = mail:GetMessageInfo()
		if tInfo ~= nil then
			bHasSelection = bHasSelection or wndMail:FindChild("SelectMarker"):IsChecked()
			bCanTake = bCanTake or (MailSystemLib.AtMailbox() and (tInfo.monGift:GetAmount() > 0 or #tInfo.arAttachments > 0))
			bCanDelete = bCanDelete or (tInfo.monGift:GetAmount() == 0 and #tInfo.arAttachments == 0 and tInfo.monCod:GetAmount() == 0)
			bCanMarkRead = bCanMarkRead or not tInfo.bIsRead
		end
	end
	
	self.wndActionsBtn:Enable(bHasSelection)
	self.wndDeleteBtn:Enable(bCanDelete)
	self.wndTakeBtn:Enable(bCanTake)
	self.wndMarkReadBtn:Enable(bCanMarkRead)
end

function Mail:OnSelectAll()
	for idx, wndMail in pairs(self.tMailItemWnds) do
		wndMail:FindChild("SelectMarker"):SetCheck(true)
	end
	
	self:RefreshActionsButton()
end

function Mail:OnDeselectAll()
	for idx, wndMail in pairs(self.tMailItemWnds) do
		wndMail:FindChild("SelectMarker"):SetCheck(false)
	end
	
	self:RefreshActionsButton()
end

function Mail:ComposeMail()
	if self.luaComposeMail ~= nil then
		self.luaComposeMail:WindowToFront()
	else
		self.luaComposeMail = MailCompose:new()
		self.luaComposeMail:Init(self)
	end
end

--------------------/Mail List Item Controls/-----------------------------
function Mail:OnItemCheck()
	Sound.Play(Sound.PlayUI19SelectStoreItemVirtual)
	self:RefreshActionsButton()
end

function Mail:OnItemUncheck()
	Sound.Play(Sound.PlayUI19SelectStoreItemVirtual)
	self.wndToggleAllBtn:SetCheck(false)
	
	self:RefreshActionsButton()
end

function Mail:UpdateListItem(wndMailItem, msgMail)
	if msgMail == nil then
		return
	end
	tMsgInfo = msgMail:GetMessageInfo()
	if tMsgInfo == nil then
		return
	end

	wndMailItem:FindChild("NameText"):SetText(tMsgInfo.strSenderName)

	local strSubject
	if tMsgInfo.monGift:GetAmount() > 0 then
		strSubject = String_GetWeaselString(Apollo.GetString("Mail_MoneyAttachedPrefix"), {strLiteral = tMsgInfo.strSubject})
	else
		strSubject = tMsgInfo.strSubject
	end
	wndMailItem:FindChild("SubjectText"):SetText(strSubject)


	wndMailItem:FindChild("DateText"):SetText(Apollo.GetString("CRB__days"))
	wndMailItem:FindChild("NewMailOverlay"):Show(not tMsgInfo.bIsRead)
	if tMsgInfo.bIsRead then
		wndMailItem:FindChild("Icon"):SetSprite(kstrReadMailIcon)
	else
		wndMailItem:FindChild("Icon"):SetSprite(kstrNewMailIcon)
	end
	if tMsgInfo.eSenderType == MailSystemLib.EmailType_GMMail then
		wndMailItem:FindChild("SenderIcon"):SetSprite(kstrGMIcon)
	elseif tMsgInfo.eSenderType == MailSystemLib.EmailType_Creature then
		wndMailItem:FindChild("SenderIcon"):SetSprite(kstrNPCIcon)
	else
		wndMailItem:FindChild("SenderIcon"):SetSprite(kstrPCIcon)
	end

	local strExpires = ""
	local crText = kcrTextDefaultColor
	if tMsgInfo.fExpirationTime < 0.0 then
		strExpires = Apollo.GetString("CRB_Expired")
		crText = kcrTextExpiringColor
	elseif tMsgInfo.fExpirationTime < 1.0 then
		local fHours = tMsgInfo.fExpirationTime * 24.0
		if fHours < 1.0 then
			local fMinutes = fHours * 60.0
			strExpires = string.format(Apollo.GetString("CRB_0f_minutes"), fMinutes)
		else
			strExpires = string.format(Apollo.GetString("CRB_0f_hours"), fHours)
		end
		crText = kcrTextExpiringColor
	else
		strExpires = string.format(Apollo.GetString("CRB_0f_days"), tMsgInfo.fExpirationTime)
		if tMsgInfo.fExpirationTime < 11.0 then
			crText = kcrTextExpiringColor
		elseif tMsgInfo.fExpirationTime < 16.0 then
			crText = kcrTextWarningColor
		end
	end
	wndMailItem:FindChild("DateText"):SetText(strExpires)
	wndMailItem:FindChild("DateText"):SetTextColor(crText)

	wndMailItem:FindChild("CODOverlay"):Show(not tMsgInfo.monCod:IsZero())

	for idx = 1, 10 do
		local tAttachment = tMsgInfo.arAttachments[idx]
		local strChild = "AttachedItem" .. tostring(idx)
		local wndListItem = wndMailItem:FindChild(strChild)
		if tAttachment ~= nil and wndListItem ~= nil then
			if tAttachment.itemAttached ~= nil then
				wndListItem:SetSprite(tAttachment.itemAttached:GetIcon())
			else
				wndListItem:SetSprite("ClientSprites:WhiteFlash")
				wndListItem:SetTooltipDoc(nil)
				wndListItem:Show(true)
			end
			wndListItem:GetWindowSubclass():SetItem(tAttachment.itemAttached)
			wndListItem:SetData(tAttachment)
		else
			wndListItem:Show(false)
		end
	end
end

function Mail:OnMailItemClick(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	local wndItem = wndHandler:GetParent()
	local msgMail = wndItem:GetData()

	tMessageInfo = msgMail:GetMessageInfo()
	if tMessageInfo ~= nil then
		self:AddMailToOpenTimer(msgMail)
	end
end

function Mail:OpenReceivedMessage(msgMail)
	local strId = msgMail:GetIdStr()
	
	if self.tOpenMailMessages[strId] ~= nil then
		if self.tOpenMailMessages[strId].wndMain:IsValid() then
			self.tOpenMailMessages[strId]:WindowToFront()
		else
			self.tOpenMailMessages[strId] = nil
		end
	else
		self.tOpenMailMessages[strId] = MailReceived:new()
		self.tOpenMailMessages[strId]:Init(self, msgMail)
	end
end

function Mail:OnTooltipAttachment( wndHandler, wndControl, eToolTipType, x, y )
	if wndHandler ~= wndControl then
		return
	end

	local tAttachment = wndControl:GetData()
	if tAttachment ~= nil and tAttachment.itemAttached ~= nil then
		Tooltip.GetItemTooltipForm(self, wndControl, tAttachment.itemAttached, { bPrimary = true, bSelling = false, itemModData = tAttachment.itemModData, nStackCount = tAttachment.nStackCount})
	end
end


function Mail:OnOpenMailBtn(wndHandler, wndControl, eMouseButton)
	self:OpenSelectedMail(false)
end

function Mail:OnConfirmOpenBtn(wndHandler, wndControl, eMouseButton)
	self:OpenSelectedMail(true)
	self.wndConfirmOpenBlocker:Close()
end

function Mail:OpenSelectedMail(bConfirmed)
	local nCount = 0
	local tSelected = {}
	for strId, wndMail in pairs(self.tMailItemWnds) do
		if wndMail:FindChild("SelectMarker"):IsChecked() then
			tSelected[strId] = wndMail
			nCount = nCount + 1
		end
	end
	
	self.wndActionPopout:Close()
	
	if not bConfirmed and nCount > knOpenMailThreshold then
		self.wndConfirmOpenBlocker:FindChild("MessageBody"):SetText(String_GetWeaselString(Apollo.GetString("Mail_ActionConfirmDelete"), tostring(nCount)))
		self.wndConfirmOpenBlocker:Invoke()
		return
	end
	
	for strId, wndMail in pairs(tSelected) do
		local msgMail = wndMail:GetData()
		tMessageInfo = msgMail:GetMessageInfo()
		if tMessageInfo ~= nil then
			self:AddMailToOpenTimer(msgMail)
		end
	end
end

function Mail:OnCancelOpenBtn(wndHandler, wndControl, eMouseButton)
	self.wndConfirmOpenBlocker:Close()
end


function Mail:OnDeleteMailBtn(wndHandler, wndControl, eMouseButton)
	self:DeleteSelectedMail(false)
end

function Mail:OnConfirmDeleteBtn(wndHandler, wndControl, eMouseButton)
	self:DeleteSelectedMail(true)
	self.wndConfirmDeleteBlocker:Close()
end

function Mail:DeleteSelectedMail(bConfirmed)
	local tSelectedMail = {}
	for strId, wndMail in pairs(self.tMailItemWnds) do
		if wndMail:FindChild("SelectMarker"):IsChecked() then
			tSelectedMail[#tSelectedMail + 1] = wndMail:GetData()
		end
	end

	self.wndActionPopout:Close()
	
	if not bConfirmed then
		self.wndConfirmDeleteBlocker:FindChild("MessageBody"):SetText(String_GetWeaselString(Apollo.GetString("Mail_ActionConfirmDelete"), tostring(#tSelectedMail)))
		self.wndConfirmDeleteBlocker:Invoke()
		return
	end
	
	MailSystemLib.DeleteMultipleMessages(tSelectedMail)
end

function Mail:OnCancelDeleteBtn(wndHandler, wndControl, eMouseButton)
	self.wndConfirmDeleteBlocker:Close()
end


function Mail:OnTakeMailBtn(wndHandler, wndControl, eMouseButton)
	self:TakeSelectedMail(false)
end

function Mail:OnConfirmTakeBtn(wndHandler, wndControl, eMouseButton)
	self:TakeSelectedMail(true)
	self.wndConfirmTakeBlocker:Close()
end

function Mail:TakeSelectedMail(bConfirmed)
	local tSelectedMail = {}
	for strId, wndMail in pairs(self.tMailItemWnds) do
		if wndMail:FindChild("SelectMarker"):IsChecked() then
			tSelectedMail[#tSelectedMail + 1] = wndMail:GetData()
		end
	end

	self.wndActionPopout:Close()
	
	if not bConfirmed then
		self.wndConfirmTakeBlocker:FindChild("MessageBody"):SetText(String_GetWeaselString(Apollo.GetString("Mail_ActionConfirmTake"), tostring(#tSelectedMail)))
		self.wndConfirmTakeBlocker:Invoke()
		return
	end
	
	MailSystemLib.TakeAllAttachmentsFromMultipleMessages(tSelectedMail)
end

function Mail:OnCancelTakeBtn(wndHandler, wndControl, eMouseButton)
	self.wndConfirmTakeBlocker:Close()
end


function Mail:OnMarkReadMailBtn(wndHandler, wndControl, eMouseButton)
	self.wndActionPopout:Close()

	local tSelectedMail = {}
	for strId, wndMail in pairs(self.tMailItemWnds) do
		if wndMail:FindChild("SelectMarker"):IsChecked() then
			local msgMail = wndMail:GetData()
			tSelectedMail[#tSelectedMail + 1] = msgMail
		end
	end
	
	if #tSelectedMail > 0 then
		MailSystemLib.MarkMultipleMessagesAsRead(tSelectedMail)
	end
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------

function Mail:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.Mail then return end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end


--------------------/Compose Controls/-----------------------------
function MailCompose:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function MailCompose:Init(luaMailSystem)
	if  luaMailSystem.xmlDoc == nil then
		return
	end
	Apollo.LinkAddon(luaMailSystem, self)

	self.luaMailSystem 			= luaMailSystem
	self.tMyBlocks 				= {}
	self.wndMain 				= Apollo.LoadForm(self.luaMailSystem.xmlDoc, "ComposeMessage", nil, self) --The compose mail form.
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Mail_ComposeLabel"), nSaveVersion=2})
	
	Apollo.RegisterEventHandler("SuggestedMenuResult",					"OnSuggestedMenuResult", self)

	self.wndNameEntry 			= self.wndMain:FindChild("NameEntryText")  --The player inputs the recipient here
	self.wndRealmEntry 			= self.wndMain:FindChild("RealmEntryText")  --The player inputs the recipient here
	self.wndSubjectEntry 		= self.wndMain:FindChild("SubjectEntryText")  --The player inputs the subject here
	self.wndMessageEntryText 	= self.wndMain:FindChild("MessageEntryText")  --The player inputs the message here
	self.wndCashEntryBlock 		= self.wndMain:FindChild("CashEntryBlock")  --Blocker stays on until the player hits Send Money or COD
	self.wndGoldEntryText 		= self.wndMain:FindChild("GoldEntryText")  --The system supplies the mail cost here
	self.wndCashSendBtn 		= self.wndMain:FindChild("CashSendBtn")  --For disabling send/request money radio's.
	self.wndCashCODBtn 			= self.wndMain:FindChild("CashCODBtn")  --For disabling send/request money radio's.
	self.wndCashWindow 			= self.wndMain:FindChild("CashWindow")
	self.wndCostWindow 			= self.wndMain:FindChild("MailCostWindow") -- for the cost of sending the message.
	self.wndSendBtn 			= self.wndMain:FindChild("SendBtn")
	self.wndArtAttLabel 		= self.wndMain:FindChild("ArtAttLabel")
	self.wndAttachmentBlocker 	= self.wndMain:FindChild("AttachmentMailboxBlocker")
	self.wndInstantDelivery 	= self.wndMain:FindChild("InstantDeliveryBtn")
	self.wndHourDelivery		= self.wndMain:FindChild("HourDeliveryBtn")
	self.wndDayDelivery			= self.wndMain:FindChild("DayDeliveryBtn")
	
	local luaSubclass = self.wndNameEntry:GetWindowSubclass()
	if luaSubclass then
		local eNot 	= luaSubclass:GetEnumNot()
		local eAccountFriends 	= luaSubclass:GetEnumAccountFriends()
		if eNot and eAccountFriends then
			luaSubclass:SetFilters({eOperator = eNot, arRelationFilters = {eAccountFriends}})
		end
	end

	self.wndRealmEntry:SetText(GameLib.GetRealmName())

	self.wndCashSendBtn:SetCheck(false)
	self.wndCashCODBtn:SetCheck(false)
	self.wndCashWindow:Enable(false)
	self.wndCashEntryBlock:Show(true)

	if self.luaMailSystem.locSavedComposeWindowLoc then
		self.wndMain:MoveToLocation(self.luaMailSystem.locSavedComposeWindowLoc)
	end
	self.arWndAttachmentIcon = {}
	self.arAttachments = {}

	for idx = 1, 10 do
		local strChild = "SlotBack." .. tostring(idx)
		local wndComposeAttachment = self.wndMain:FindChild(strChild)
		wndComposeAttachment:SetData(idx)
		self.arWndAttachmentIcon[idx] = wndComposeAttachment:FindChild("Icon")
	end

	self.nDeliverySpeed = MailSystemLib.MailDeliverySpeed_Hour
	self.wndHourDelivery:SetCheck(true)

	self.luaMailSystem:CascadeWindow(self.wndMain)

	self:UpdateControls()
	self:WindowToFront()
end

function MailCompose:SetFields(strTo, strRealm, strSubject, strBody)
	if strTo ~= nil then
		self.wndNameEntry:SetText(strTo)
		MailCompose.LimitTextEntry(self.wndNameEntry, MailSystemLib.GetNameCharacterLimit())
		self.wndMessageEntryText:SetFocus()
	end

	if strRealm ~= nil then
		self.wndRealmEntry:SetText(strRealm)
		MailCompose.LimitTextEntry(self.wndRealmEntry, MailSystemLib.GetRealmCharacterLimit())
	end

	if strSubject ~= nil then
		self.wndSubjectEntry:SetText(strSubject)
		MailCompose.LimitTextEntry(self.wndSubjectEntry, MailSystemLib.GetSubjectCharacterLimit())
	end

	if strBody ~= nil then
		self.wndMessageEntryText:SetText(strBody)
		MailCompose.LimitTextEntry(self.wndMessageEntryText, MailSystemLib.GetMessageCharacterLimit() - 1)
	end

end

function MailCompose:WindowToFront()
	self.wndMain:Show(true)
	self.wndMain:ToFront()
	self.wndNameEntry:SetFocus()
end

function MailCompose:OnQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)

	if self.wndMain ~= wndHandler then
		return Apollo.DragDropQueryResult.PassOn
	end

	if strType == "DDBagItem" then
		if #self.arAttachments > 10 then
			return Apollo.DragDropQueryResult.Invalid
		end
		return Apollo.DragDropQueryResult.Accept
	end

	return Apollo.DragDropQueryResult.Invalid
end

function MailCompose:OnDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)

	if self.wndMain ~= wndHandler or strType ~= "DDBagItem" then
		return
	end

	self:AppendAttachment(nValue)
end

function MailCompose:OnMailAddAttachment(nValue)
	self:AppendAttachment(nValue)
end

function MailCompose:AppendAttachment(nValue)
	local nNewPos = #self.arAttachments + 1
	if nNewPos > MailSystemLib.GetAttachmentMaxCount() then
		return
	end

	for idx, nAttachmentValue in pairs( self.arAttachments ) do
		if nAttachmentValue == nValue then
			return
		end
	end
	
	--Not allowed to send soulbound items.
	local itemAttach = Item.GetItemFromInventoryLoc(nValue)
	if itemAttach and itemAttach:IsSoulbound() then
		self.luaMailSystem:OnMailResult(GameLib.CodeEnumGenericError.Mail_CannotTransferItem)
		return
	end

	GameLib.GetPlayerUnit():LockInventorySlot(nValue)

	self.tMyBlocks[nValue] = nValue


	self.arAttachments[nNewPos] = nValue
	self:UpdateControls()
end

function MailCompose:OnCashAmountChanged()
	self:UpdateControls()
end


function MailCompose:UpdateControls()
	local bAtMailbox = MailSystemLib.AtMailbox()

	if not bAtMailbox and (self.wndCashCODBtn:IsChecked() or self.wndCashSendBtn:IsChecked()) then
		self.wndCashCODBtn:SetCheck(false)
		self.wndCashSendBtn:SetCheck(false)
		self.wndCashWindow:SetAmount(0)
    end
	self.wndAttachmentBlocker:Show(not bAtMailbox)


	-- update attachment icons
	local bHasAttachments = false
	for idx, wndIcon in pairs(self.arWndAttachmentIcon) do
		local itemAttachment = MailSystemLib.GetItemFromInventoryId(self.arAttachments[idx])

		if itemAttachment ~= nil then
			wndIcon:SetSprite(itemAttachment:GetIcon())
			wndIcon:SetText(tostring(itemAttachment:GetStackCount()))
			wndIcon:GetWindowSubclass():SetItem(itemAttachment)
			Tooltip.GetItemTooltipForm(self, wndIcon, itemAttachment, { bPrimary = true, bSelling = false })
			bHasAttachments = true
		else
			wndIcon:SetSprite("")
			wndIcon:SetText("")
			wndIcon:SetTooltipDoc(nil)
			GameLib:GetPlayerUnit():UnlockInventorySlot(self.arAttachments[idx])
			if self.arAttachments[idx] ~= nil then
				self.tMyBlocks[self.arAttachments[idx]] = nil
			end
			wndIcon:GetWindowSubclass():SetItem(itemAttachment)
			self.arAttachments[idx] = nil
		end
	end

	if #self.arAttachments == 0 then
    	self.wndCashCODBtn:Enable(false)
		self.wndCashCODBtn:SetCheck(false)

		self.wndInstantDelivery:Enable(false)
		self.wndHourDelivery:Enable(false)
		self.wndDayDelivery:Enable(false)

		if not self.wndCashSendBtn:IsChecked() then
			self.wndCashEntryBlock:Show(true)
			self.wndCashWindow:Enable(false)
			self.wndCashWindow:SetAmount(0)
		end
	else
    	self.wndCashCODBtn:Enable(bAtMailbox)

		self.wndInstantDelivery:Enable(true)
		self.wndHourDelivery:Enable(true)
		self.wndDayDelivery:Enable(true)
	end

    if self.wndCashCODBtn:IsEnabled() then
        self.wndCashCODBtn:SetTextColor(kcrAttachmentIconValidColor)
		nCOD = self.wndCashWindow:GetAmount()
    else
        self.wndCashCODBtn:SetTextColor(kcrAttachmentIconInvalidColor)
    end

	local monCoD = 0
	local monGift = 0
	if self.wndCashCODBtn:IsChecked() then
		monCoD = self.wndCashWindow:GetCurrency()
	elseif self.wndCashSendBtn:IsChecked() then
		monGift = self.wndCashWindow:GetCurrency()
	end

	local strTo = self.wndNameEntry:GetText()
	local strRealm = self.wndRealmEntry:GetText()
	local strSubject = self.wndSubjectEntry:GetText()
	local strMessage = self.wndMessageEntryText:GetText()

	-- Enable / Disable Send
	local bSubjectValid = GameLib.IsTextValid(strSubject, GameLib.CodeEnumUserText.MailSubject, GameLib.CodeEnumUserTextFilterClass.Strict)
	self.wndMain:FindChild("InvalidSubjectInputWarning"):Show(string.len(strSubject) > 0 and not bSubjectValid)

	local bBodyValid = GameLib.IsTextValid(strMessage, GameLib.CodeEnumUserText.MailBody, GameLib.CodeEnumUserTextFilterClass.Strict)
	self.wndMain:FindChild("InvalidBodyInputWarning"):Show(string.len(strMessage) > 0 and not bBodyValid)

	local bCanSend = strTo ~= "" and strRealm ~= "" and strSubject ~= "" and strMessage ~= "" and (not bHasAttachments or bAtMailbox)
	self.wndSendBtn:Enable(bCanSend and bSubjectValid and bBodyValid)

	-- Limit entry
	MailCompose.LimitTextEntry(self.wndNameEntry, MailSystemLib.GetNameCharacterLimit())
	MailCompose.LimitTextEntry(self.wndRealmEntry, MailSystemLib.GetRealmCharacterLimit())
	MailCompose.LimitTextEntry(self.wndSubjectEntry, MailSystemLib.GetSubjectCharacterLimit())
	MailCompose.LimitTextEntry(self.wndMessageEntryText, MailSystemLib.GetMessageCharacterLimit() - 1)

	self.wndCostWindow:SetAmount(MailSystemLib.GetSendCost(self.nDeliverySpeed, self.arAttachments))

	strTo = self.wndNameEntry:GetText()
	strRealm = self.wndRealmEntry:GetText()
	strSubject = self.wndSubjectEntry:GetText()
	strMessage = self.wndMessageEntryText:GetText()

	self.wndSendBtn:SetActionData(GameLib.CodeEnumConfirmButtonType.SendMail, strTo, strRealm, strSubject, strMessage, self.arAttachments, self.nDeliverySpeed, monCoD, monGift)
end

function MailCompose.LimitTextEntry(wndCompose, nCharacterLimit)

	local strCurrent = wndCompose:GetText()
	if string.len(strCurrent) > nCharacterLimit then
		local strNew = string.sub(strCurrent, 0, nCharacterLimit)
		wndCompose:SetText(strNew)
		wndCompose:SetSel(nCharacterLimit, nCharacterLimit)
	end
end

function MailCompose:OnInfoChanged(wndHandler, wndControl, strText)
	if wndControl ~= wndHandler then
		return
	end

	local luaSubclass = wndControl:GetWindowSubclass()
	if luaSubclass then
		luaSubclass:OnEditBoxChanged(wndHandler, wndControl, strText)
	end

	self:UpdateControls()
end

function MailCompose:OnEmailSent(wndHandler, wndControl, bSuccess)
	if bSuccess then
		self.wndMain:Close()
	end
end


function MailCompose:OnClosed(wndHandler)
	for key, nInventoryLoc in pairs(self.tMyBlocks) do
		GameLib.GetPlayerUnit():UnlockInventorySlot(nInventoryLoc)
	end

	if self.wndMain ~= nil then
		self.luaMailSystem.locSavedComposeWindowLoc = self.wndMain:GetLocation()
		self.luaMailSystem.luaComposeMail = nil
	end

	Apollo.UnlinkAddon(self.luaMailSystem, self)
end

function MailCompose:OnSuggestedMenuResult(tInfo, nTextBoxId)
	if nTextBoxId ~= self.wndNameEntry:GetId() or not tInfo then
		return
	end
	
	if tInfo.strCharacterName then
		self.wndNameEntry:SetText(tInfo.strCharacterName)
		self.wndSubjectEntry:SetFocus()
	end
end

function MailCompose:OnClickAttachment(wndHandler, wndControl)

	if wndHandler ~= wndControl then
		return
	end

	local iAttach = wndHandler:GetData()
	if iAttach == nil then
		return
	end

	GameLib:GetPlayerUnit():UnlockInventorySlot(self.arAttachments[iAttach])
	self.arAttachments[iAttach] = nil
	for idx = iAttach, 10 do
		if idx < 10 then
			self.arAttachments[idx] = self.arAttachments[idx + 1]
		else
			self.arAttachments[idx] = nil
		end
	end

	self:UpdateControls()
end

function MailCompose:OnCancelBtn(wndHandler, wndControl)
	if wndControl ~= wndHandler then
		return
	end
	self.wndMain:Close()
end


--Controls for sending money. Not running these as a Radio group, as we need the player to be able to Uncheck both
function MailCompose:OnMoneyCODCheck(wndHandler, wndControl)
	if wndControl ~= wndHandler then
		return
	end

	self.wndCashSendBtn:SetCheck(false)
	self.wndCashEntryBlock:Show(true)
	self.wndCashWindow:Enable(true)
	self.wndCashWindow:SetFocus()
	self.wndCashWindow:SetAmountLimit(9999999)
	self:UpdateControls()
end

function MailCompose:OnMoneyCODUncheck(wndHandler, wndControl)
	if wndControl ~= wndHandler then
		return
	end

	self.wndCashEntryBlock:Show(true)
	self.wndCashWindow:Enable(false)
	self.wndCashWindow:ClearFocus()
	self.wndCashWindow:SetAmount(0)
	self:UpdateControls()
end

function MailCompose:OnMoneySendCheck(wndHandler, wndControl)
	if wndControl ~= wndHandler then
		return
	end

	self.wndCashCODBtn:SetCheck(false)
	self.wndCashEntryBlock:Show(true)
	self.wndCashWindow:Enable(true)
	self.wndCashWindow:SetFocus()
	self.wndCashWindow:SetAmountLimit(GameLib.GetPlayerCurrency())
	self:UpdateControls()
end

function MailCompose:OnMoneySendUncheck(wndHandler, wndControl)
	if wndControl ~= wndHandler then
		return
	end

	self.wndCashEntryBlock:Show(true)
	self.wndCashWindow:Enable(false)
	self.wndCashWindow:ClearFocus()
	self.wndCashWindow:SetAmount(0)
	self:UpdateControls()
end


function MailCompose:OnPlayerCurrencyChanged()
	self.wndCashWindow:SetAmountLimit(GameLib.GetPlayerCurrency())
end


function MailCompose:OnInstantDeliveryCheck( wndHandler, wndControl, eMouseButton )
	self.nDeliverySpeed = MailSystemLib.MailDeliverySpeed_Instant
	self.wndCostWindow:SetAmount(MailSystemLib.GetSendCost(self.nDeliverySpeed, self.arAttachments))
	self:UpdateControls()
end


function MailCompose:OnHourDeliveryCheck( wndHandler, wndControl, eMouseButton )
	self.nDeliverySpeed = MailSystemLib.MailDeliverySpeed_Hour
	self.wndCostWindow:SetAmount(MailSystemLib.GetSendCost(self.nDeliverySpeed, self.arAttachments))
	self:UpdateControls()
end


function MailCompose:OnDayDeliveryCheck( wndHandler, wndControl, eMouseButton )
	self.nDeliverySpeed = MailSystemLib.MailDeliverySpeed_Day
	self.wndCostWindow:SetAmount(MailSystemLib.GetSendCost(self.nDeliverySpeed, self.arAttachments))
	self:UpdateControls()
end


--------------------/Received Message Controls/-----------------------------

function MailReceived:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function MailReceived:Init(luaMailSystem, msgMail) -- Reading, not composing

	if luaMailSystem.xmlDoc == nil then
		return
	end

	if msgMail == nil then
		return
	end

	Apollo.LinkAddon(luaMailSystem, self)

	local tMessageInfo = msgMail:GetMessageInfo()

	if tMessageInfo == nil then
		return
	end

	self.luaMailSystem = luaMailSystem
	self.msgMail = msgMail

	self.wndMain = Apollo.LoadForm(self.luaMailSystem.xmlDoc, "MailMessage", nil, self)

	self.arWndAttachmentIcon = {}

	if self.luaMailSystem.locSavedMessageWindowLoc then
		self.wndMain:MoveToLocation(self.luaMailSystem.locSavedMessageWindowLoc)
	end

	for idx = 1, 10 do
		local wndItemSlotBack = self.wndMain:FindChild("ItemSlotBack." .. tostring(idx))
		self.arWndAttachmentIcon[idx] = wndItemSlotBack:FindChild("Icon")
	end

	self.wndAcceptCODBtn 		= self.wndMain:FindChild("AcceptCODBtn")
	self.wndCODCash				= self.wndMain:FindChild("CODCash")
	self.wndCODFrame 			= self.wndMain:FindChild("CODFrame")
	self.wndGift 				= self.wndMain:FindChild("Gift")
	self.wndReceiveTakeCashBtn 	= self.wndMain:FindChild("ReceiveTakeCashBtn")
	self.wndReceiveReplyBtn 	= self.wndMain:FindChild("ReceiveReplyBtn") -- not active if npc mail
	self.wndReceiveReturnBtn 	= self.wndMain:FindChild("ReceiveReturnBtn") -- not enabled if ncp mail
	self.wndReceiveDeleteBtn 	= self.wndMain:FindChild("ReceiveDeleteBtn") -- not enabled if attachments (cant delete mail with attachments.  Take attachment or return to sender.)

	self.wndMain:Show(false, true)
	self.luaMailSystem:CascadeWindow(self.wndMain)

	self.wndMain:FindChild("NameText"):SetText(tMessageInfo.strSenderName)
	self.wndMain:FindChild("SubjectText"):SetText(tMessageInfo.strSubject)
	self.wndMain:FindChild("MessageText"):SetText(tMessageInfo.strBody)

	if tMessageInfo.eSenderType == MailSystemLib.EmailType_GMMail then
		self.wndMain:FindChild("SenderIcon"):SetSprite(kstrGMIcon)
	elseif tMessageInfo.eSenderType == MailSystemLib.EmailType_Creature then
		self.wndMain:FindChild("SenderIcon"):SetSprite(kstrNPCIcon)
	else
		self.wndMain:FindChild("SenderIcon"):SetSprite(kstrPCIcon)
	end

	if tMessageInfo.eSenderType ~= MailSystemLib.EmailType_Character then
		self.wndMain:FindChild("ReportSpam"):Show(false)
	elseif not tMessageInfo.bIsReturnable then
		self.wndMain:FindChild("ReportSpam"):Enable(false)
	end

	if tMessageInfo.monCod:GetAmount() == 0 then
		self.wndCODFrame:Show(false)
		self.wndReceiveReplyBtn:Show(true)
		self.wndReceiveReturnBtn:Show(true)	
	end

	self:UpdateControls()
	self:WindowToFront()

end

function MailReceived:WindowToFront()
	self.wndMain:Show(true)
	self.wndMain:ToFront()
end

function MailReceived:UpdateControls()
	local bAtMailbox = MailSystemLib.AtMailbox()
	local tMessageInfo = self.msgMail:GetMessageInfo()
	if tMessageInfo == nil then
		self.wndMain:Close()
		return
	end

	self.wndMain:FindChild("ReceiveReturnBtn"):Enable(tMessageInfo.bIsReturnable)
	self.wndMain:FindChild("ReportSpam"):Enable(tMessageInfo.bIsReturnable)

	for idx, wndIcon in pairs(self.arWndAttachmentIcon) do
		local tAttachment = tMessageInfo.arAttachments[idx]
		if tAttachment ~= nil then
			wndIcon:GetWindowSubclass():SetItem(tAttachment.itemAttached)
			wndIcon:SetData(idx)
			wndIcon:SetText(tostring(tAttachment.nStackCount))
			wndIcon:GetParent():SetData(tAttachment.nServerIndex) -- parent handles take attachment call, needs to know what server index.
			wndIcon:GetParent():SetBGColor(CColor.new(1.0, 1.0, 1.0, 1.0))

			if bAtMailbox then
				wndIcon:SetBGColor(kcrAttachmentIconValidColor) -- Todo: figure out proper formatting here.
			else
				wndIcon:SetBGColor(kcrAttachmentIconInvalidColor)
			end

		else
			wndIcon:SetSprite("")
			wndIcon:SetText("")
			wndIcon:SetTooltipDoc(nil)
			wndIcon:GetParent():SetData(nil)
			wndIcon:GetParent():SetBGColor(CColor.new(1.0, 1.0, 1.0, 0.4))
			wndIcon:GetWindowSubclass():SetItem(nil)
		end
	end

	local nAttachmentCount = #tMessageInfo.arAttachments
	local bHasAttachments = nAttachmentCount > 0

	self.wndReceiveDeleteBtn:Enable(nAttachmentCount == 0)
	self.wndReceiveReplyBtn:Enable(MailReceived:CanReply(tMessageInfo))

	-- sent money
	if tMessageInfo.monGift:IsZero() then -- no money sent
		self.wndReceiveTakeCashBtn:Enable(false)
		self.wndReceiveTakeCashBtn:Show(false)
		self.wndGift:SetAmount(0, true)
		self.wndGift:Show(false)
	else
		self.wndReceiveTakeCashBtn:Show(true)
		self.wndReceiveDeleteBtn:Enable(false)
		bHasAttachments = true
		self.wndGift:SetMoneySystem(tMessageInfo.monGift:GetMoneyType())
		self.wndGift:SetAmount(tMessageInfo.monGift)
		self.wndGift:Show(true)
	end

	if not tMessageInfo.monCod:IsZero() and nAttachmentCount > 0 then -- is this a COD message
		local monCash = GameLib.GetPlayerCurrency(tMessageInfo.monCod:GetMoneyType())
		self.wndCODFrame:Show(true)
		self.wndReceiveReplyBtn:Show(false)
		self.wndReceiveReturnBtn:Show(false)
		self.wndCODCash:SetAmount(tMessageInfo.monCod)
		self.wndAcceptCODBtn:Enable(monCash:GetAmount() >= tMessageInfo.monCod:GetAmount() and MailSystemLib.AtMailbox())
		self.wndMain:FindChild("CODCostText"):Show(not MailSystemLib.AtMailbox())
		if monCash:GetAmount() >= tMessageInfo.monCod:GetAmount() then
			self.wndCODCash:SetTextColor(kcrAttachmentIconValidColor)
		else
			self.wndCODCash:SetTextColor(kcrAttachmentIconInvalidColor)
		end
		self.wndReceiveTakeCashBtn:Enable(false)
	else -- NOT a COD message
		self.wndReceiveTakeCashBtn:Enable(true)
		self.wndCODFrame:Show(false)
		self.wndReceiveReplyBtn:Show(true)
		self.wndReceiveReturnBtn:Show(true)
	end

	-- format attach frame if needed
	if not bHasAttachments then -- remove attachment panel
		self.wndMain:FindChild("ArtBG_AttachmentAssets"):Show(false)
		self.wndReceiveTakeCashBtn:Show(false)

		local nLeftMessage, nTopMessage, nRightMessage, nBottomMessage = self.wndMain:FindChild("MessageText"):GetAnchorOffsets()
		self.wndMain:FindChild("MessageText"):SetAnchorOffsets(nLeftMessage, nTopMessage, nRightMessage, nBottomMessage)
	end
end

function MailReceived:OnCloseBtn(wndHandler, wndControl)
	self.wndMain:Close()
end

function MailReceived:OnClosed(wndHandler)
	local strId = self.msgMail:GetIdStr()
	Apollo.UnlinkAddon(self.luaMailSystem, self)
	self.luaMailSystem.tOpenMailMessages[self.msgMail:GetIdStr()] = nil
end

function MailReceived:OnClickAttachment(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	local iServer = wndHandler:GetData()
	if iServer == nil then
		return
	end

	self.msgMail:TakeAttachment(iServer)
	-- Timer UpdateControl handles changes to message if it occures
	
	local tMessageInfo = self.msgMail:GetMessageInfo()
	local arAttachmentWindows = self.wndMain:FindChild("BaseArt:ArtContentBack:ArtBG_AttachmentAssets"):GetChildren()
	for idx, wndAttachment in pairs(arAttachmentWindows) do
		if wndAttachment:FindChild("Icon") then
			wndAttachment:FindChild("Icon"):SetTooltipDoc(nil)
		end
	end

	self:UpdateControls()
end

function MailReceived:OnTooltipAttachment( wndHandler, wndControl, eToolTipType, x, y )
	if wndHandler ~= wndControl then
		return
	end
	local tMessageInfo = self.msgMail:GetMessageInfo()
	
	if tMessageInfo then
		local tAttachment = tMessageInfo.arAttachments[wndControl:GetData()]
		if tAttachment ~= nil and tAttachment.itemAttached ~= nil then
			Tooltip.GetItemTooltipForm(self, wndControl, tAttachment.itemAttached, { bPrimary = true, bSelling = false, itemModData = tAttachment.itemModData, nStackCount = tAttachment.nStackCount })
		end
	end
end

function MailReceived:OnTakeCashBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	self.msgMail:TakeMoney()

	self:UpdateControls()
end

function MailReceived:OnTakeAllBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	self.msgMail:TakeAllAttachments()

	self:UpdateControls()
end

function MailReceived:CanReply(tMessageInfo)
	return tMessageInfo ~= nil and tMessageInfo.eSenderType == MailSystemLib.EmailType_Character and tMessageInfo.eSenderType ~= nil
end

function MailReceived:OnReplyBtn()

	local tMessageInfo = self.msgMail:GetMessageInfo()
	if tMessageInfo == nil then
		return
	end

	if not MailReceived:CanReply(tMessageInfo) then
		return
	end

	local strNewSubject = Apollo.GetString("Mail_ReplyPrepend")
	if( tMessageInfo.strSubject ~= nil ) then
		strNewSubject = String_GetWeaselString(strNewSubject, {strLiteral = tMessageInfo.strSubject})
	end

	local strNewBody = Apollo.GetString("Mail_InlineReplyPrepend")
	if(tMessageInfo.strBody ~= nil ) then
		strNewBody = String_GetWeaselString(strNewBody, {strLiteral = tMessageInfo.strBody})
	end

	self.luaMailSystem:ComposeMail()
	self.luaMailSystem.luaComposeMail:SetFields( tMessageInfo.strSenderName, nil, strNewSubject, strNewBody )

end

function MailReceived:OnReturnBtn(wndHandler, wndControl)
	--Returns the message with any unaccepted money/items.
	if wndHandler ~= wndControl then
		return
	end

	self.msgMail:ReturnToSender()
	self:OnCloseBtn()
end

function MailReceived:OnDeleteBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	self.msgMail:DeleteMessage()
	
	self.wndMain:Close()
	self:OnClosed()
end

function MailReceived:OnSubCloseBtn(wndHandler, wndControl)
	self.wndMain:FindChild("Frame"):GetParent():Show(false)
end

function MailReceived:OnAcceptCODBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	--Accepts and pays the COD cost, removes the blocker.
	self.msgMail:PayCoD()
	Mail.strPendingCOD = self.msgMail:GetIdStr()
	-- Timer UpdateControl handles changes to message if it occures

	self:UpdateControls()
end

function MailReceived:OnRejectCODBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	--Rejects the COD cost, returns the message to sender.
	self.msgMail:ReturnToSender()
	
	self:OnCloseBtn()
end

function MailReceived:OnPlayerCurrencyChanged()
	self:UpdateControls()
end

function MailReceived:OnReportSpamBtn(wndHandler, wndControl, eMouseButton)
	Event_FireGenericEvent("GenericEvent_ReportPlayerMail", self.msgMail)
end


---------------------------------------------------------------------------------------------------
-- MailForm Functions
---------------------------------------------------------------------------------------------------
Mail:Init()
local MailInstance = Mail:new()