-----------------------------------------------------------------------------------------------
-- Client Lua Script for ReportPlayer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "GroupLib"
require "P2PTrading"
require "MatchingGame"
require "ChatSystemLib"
require "FriendshipLib"
require "MailSystemLib"
require "IncidentReportLib"

local ReportPlayer = {}

function ReportPlayer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ReportPlayer:Init()
    Apollo.RegisterAddon(self)
end

function ReportPlayer:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ReportPlayer.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ReportPlayer:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",				"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleReportPlayer", 		"OnToggleFromInterfaceMenu", self)
	Apollo.RegisterSlashCommand("report", 									"OnToggleFromInterfaceMenu", self)

	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerPvP", 			"OnReportPlayerPvP", self) -- Special case, report object is already made
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerUnit", 			"OnReportPlayerUnit", self) -- 1 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerChat", 			"OnReportPlayerChat", self) -- 1 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerMail", 			"OnReportPlayerMail", self) -- 1 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerTrade", 			"OnReportPlayerTrade", self) -- 0 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerGuildInvite", 	"OnReportPlayerGuildInvite", self) -- 0 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerCircleInvite", 	"OnReportPlayerGuildInvite", self) -- 0 arg (GOTCHA: Reuses guild)
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerArenaInvite", 	"OnReportPlayerGuildInvite", self) -- 0 arg (GOTCHA: Reuses guild)
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerWarpartyInvite", 	"OnReportPlayerGuildInvite", self) -- 0 arg (GOTCHA: Reuses guild)
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerGroupInvite", 	"OnReportPlayerGroupInvite", self) -- 1 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerNeighborInvite", 	"OnReportPlayerNeighborInvite", self) -- 0 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerFriendInvite", 	"OnReportPlayerFriendInvite", self) -- 1 arg

	Apollo.RegisterTimerHandler("ReportPlayer_OneSecondTimer",				"OnReportPlayer_OneSecondTimer", self)

	self.wndMain = nil
	self.wndNamePicker = nil
end

function ReportPlayer:OnInterfaceMenuListHasLoaded()
	local tData = { "InterfaceMenu_ToggleReportPlayer", "", "IconSprites:Icon_Windows32_UI_CRB_InterfaceMenu_ReportPlayer" }
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("ReportPlayer_Title"), tData)
end

-----------------------------------------------------------------------------------------------
-- Report Chat
-----------------------------------------------------------------------------------------------

function ReportPlayer:OnReportPlayerPvP(rptParticipant)
	self:BuildReportConfirmation(rptParticipant, Apollo.GetString("ReportPlayer_GenericReportUnavailable"))
end

function ReportPlayer:OnReportPlayerUnit(unitTarget)
	if unitTarget == nil then
		return
	end

	self:BuildReportConfirmation(unitTarget:PrepareInfractionReport(), Apollo.GetString("ReportPlayer_GenericReportUnavailable"), unitTarget)
end

function ReportPlayer:OnReportPlayerChat(nReportId)
	if nReportId == nil then
		return
	end

	self:BuildReportConfirmation(ChatSystemLib.PrepareInfractionReport(nReportId), Apollo.GetString("Chat_ReportUnavailable"))
end

function ReportPlayer:OnReportPlayerMail(msgMail)
	if not MailSystemLib.is(msgMail) then
		return
	end

	self:BuildReportConfirmation(msgMail:PrepareInfractionReport(), Apollo.GetString("Mail_ReportUnavailable"))
end

function ReportPlayer:OnReportPlayerFriendInvite(nInviteId)
	if nInviteId == nil then
		return
	end

	self:BuildReportConfirmation(FriendshipLib.PrepareInfractionReportInvite(nInviteId), Apollo.GetString("ReportPlayer_InviteReportUnavailable"))
end

function ReportPlayer:OnReportPlayerGuildInvite() -- GOTCHA: Includes Circle, Warparties, and Arena (as they are all guild lib)
	self:BuildReportConfirmation(GuildLib.PrepareInfractionReportInvite(), Apollo.GetString("ReportPlayer_InviteReportUnavailable"))
end

function ReportPlayer:OnReportPlayerNeighborInvite()
	self:BuildReportConfirmation(HousingLib.PrepareInfractionReport(), Apollo.GetString("ReportPlayer_InviteReportUnavailable"))
end

function ReportPlayer:OnReportPlayerTrade()
	self:BuildReportConfirmation(P2PTrading.PrepareInfractionReport(), Apollo.GetString("ReportPlayer_GenericReportUnavailable"))
end

function ReportPlayer:OnReportPlayerGroupInvite(nTimeLeft)
	self:BuildReportConfirmation(GroupLib.PrepareInfractionReportInvite(), Apollo.GetString("ReportPlayer_InviteReportUnavailable"))
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("Timer"):SetData(nTimeLeft)
		Apollo.CreateTimer("ReportPlayer_OneSecondTimer", 1, false)
		Apollo.StartTimer("ReportPlayer_OneSecondTimer")
		self:OnReportPlayer_OneSecondTimer()
	end
end

-- There is also OnNameSelectedBtn

-----------------------------------------------------------------------------------------------
-- Name Input (This is an in between UI if opening from nothing)
-----------------------------------------------------------------------------------------------

function ReportPlayer:OnToggleFromInterfaceMenu()
	if self.wndNamePicker and self.wndNamePicker:IsValid() then
		self.wndNamePicker:Destroy()
	end

	self.wndNamePicker = Apollo.LoadForm(self.xmlDoc, "ReportPlayerNamePicker", nil, self)
	self.wndNamePicker:FindChild("CustomInputBtn"):Enable(false)

	for idx = 1, 2 do
		local strName = GameLib.GetLastTargetedPlayerName(idx) or ""
		self.wndNamePicker:FindChild("LastTargetTooltipExplain"..idx):Show(strName and string.len(strName) > 0)
		self.wndNamePicker:FindChild("LastTargetName"..idx):SetText(strName)
		self.wndNamePicker:FindChild("LastTargetBtn"..idx):Enable(strName and string.len(strName) > 0)
		self.wndNamePicker:FindChild("LastTargetBtn"..idx):SetData(idx)
	end

	self.wndNamePicker:FindChild("CustomInputEditBox"):SetMaxTextLength(GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.CharacterName))
end

function ReportPlayer:OnCustomInputEditBoxChanged(wndHandler, wndControl)
	local strInput = wndHandler:GetText() or ""
	self.wndNamePicker:FindChild("CustomInputBtn"):SetData(strInput)
	self.wndNamePicker:FindChild("CustomInputBtn"):Enable(strInput and string.len(strInput) > 0)
end

function ReportPlayer:OnNameSelectedBtn(wndHandler, wndControl)
	local oInput = wndHandler:GetData()
	self:BuildReportConfirmation(GameLib.PrepareInfractionReport(oInput), Apollo.GetString("ReportPlayer_GenericReportUnavailable"))
	self:OnNamePickerClose()
end

-----------------------------------------------------------------------------------------------
-- Report Confirmation
-----------------------------------------------------------------------------------------------

function ReportPlayer:BuildReportConfirmation(rptInfraction, strFail, unitTarget) -- rptInfraction can be nil
	self:ClearReportConfirmation()

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "ReportPlayerMain", nil, self)
	wndCurr:SetData(rptInfraction)
	self.wndMain = wndCurr

	local bPvPSource = rptInfraction and rptInfraction:GetSource() == IncidentReportLib.CodeEnumReportPlayerSource.PvpMatch
	local bUnitSource = rptInfraction and rptInfraction:GetSource() == IncidentReportLib.CodeEnumReportPlayerSource.InWorld
	local bStringSource = rptInfraction and rptInfraction:GetSource() == IncidentReportLib.CodeEnumReportPlayerSource.Default
	local bValidPvPReport = MatchingGame.IsInPVPGame() and (not bUnitSource or not unitTarget or unitTarget:GetFaction() == GameLib.GetPlayerUnit():GetFaction())

	-- Options picker if from InWorld or GameLib, else BodyText
	wndCurr:FindChild("TypeInWarning"):Show(bStringSource)
	wndCurr:FindChild("OptionsPicker"):Show(bUnitSource or bPvPSource or bStringSource)
	wndCurr:FindChild("BodyTextScroll"):Show(not (bUnitSource or bPvPSource or bStringSource))

	if bPvPSource or bUnitSource or bStringSource then
		local wndOptionsPicker = wndCurr:FindChild("OptionsPicker")
		wndOptionsPicker:SetData(rptInfraction)
		wndOptionsPicker:FindChild("OptionsAFKPVPBtn"):Show(bValidPvPReport) -- You can't report the enemy team afk
		wndOptionsPicker:FindChild("OptionsAFKPVPBtn"):SetCheck(bPvPSource)
		wndOptionsPicker:FindChild("OptionsBottingBtn"):SetCheck(bUnitSource or bStringSource)
		wndOptionsPicker:FindChild("OptionsSpamBtn"):SetText(bStringSource and Apollo.GetString("ReportPlayer_SpamTypeIn") or Apollo.GetString("ReportPlayer_Spam"))
		wndOptionsPicker:FindChild("OptionsAFKPVPBtn"):SetText(bStringSource and Apollo.GetString("ReportPlayer_AFKPvPTypeIn") or Apollo.GetString("ReportPlayer_AFKPvP"))
		wndOptionsPicker:FindChild("OptionsBottingBtn"):SetText(bStringSource and Apollo.GetString("ReportPlayer_BottingTypeIn") or Apollo.GetString("ReportPlayer_Botting"))
		wndOptionsPicker:FindChild("OptionsCheatingBtn"):SetText(bStringSource and Apollo.GetString("ReportPlayer_CheatingTypeIn") or Apollo.GetString("ReportPlayer_Cheating"))
		wndOptionsPicker:FindChild("OptionsSpamBtn"):SetData(IncidentReportLib.CodeEnumReportPlayerReason.Spam)
		wndOptionsPicker:FindChild("OptionsAFKPVPBtn"):SetData(IncidentReportLib.CodeEnumReportPlayerReason.AFK)
		wndOptionsPicker:FindChild("OptionsBottingBtn"):SetData(IncidentReportLib.CodeEnumReportPlayerReason.Bot)
		wndOptionsPicker:FindChild("OptionsCheatingBtn"):SetData(IncidentReportLib.CodeEnumReportPlayerReason.Cheat)
		wndOptionsPicker:FindChild("OptionsOpenSupportBtn"):SetData(rptInfraction and rptInfraction:GetName() or "")

		local nHeight = wndOptionsPicker:ArrangeChildrenVert(1)
		local nLeft, nTop, nRight, nBottom = wndOptionsPicker:GetAnchorOffsets()
		wndOptionsPicker:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 10)
		wndOptionsPicker:ArrangeChildrenVert(1)
	else
		wndCurr:FindChild("BodyText"):SetTextRaw(rptInfraction and rptInfraction:GetDescription() or strFail)
		wndCurr:FindChild("BodyText"):SetHeightToContentHeight()
		wndCurr:FindChild("BodyTextScroll"):ArrangeChildrenVert(0)
	end

	-- Shared between them
	wndCurr:FindChild("NoButton"):Show(rptInfraction ~= nil)
	wndCurr:FindChild("YesButton"):Show(rptInfraction ~= nil)
	wndCurr:FindChild("CancelButton"):Show(rptInfraction == nil)
	wndCurr:FindChild("IgnorePlayerCheckbox"):Show(rptInfraction ~= nil)

	wndCurr:FindChild("IgnorePlayerCheckbox"):SetCheck(true)
	if rptInfraction then
		rptInfraction:SetPermanentIgnore(self.wndMain:FindChild("IgnorePlayerCheckbox"):IsChecked())
		wndCurr:FindChild("YesButton"):SetActionData(GameLib.CodeEnumConfirmButtonType.ReportPlayer, rptInfraction)
	end
	wndCurr:FindChild("IgnorePlayerCheckbox"):SetData(rptInfraction)

	-- Name shown only sometimes
	wndCurr:FindChild("NameInput"):Show(bPvPSource or bUnitSource or bStringSource)
	wndCurr:FindChild("NameInputEditBox"):SetText(rptInfraction and rptInfraction:GetName() or "")

	-- Resize
	local nHeight = wndCurr:FindChild("ContentContainerArrangeVert"):ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
	wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 235)
end

function ReportPlayer:OnIgnorePlayerCheckboxToggle(wndHandler, wndControl)
	local rptInfraction = wndHandler:GetData()
	if wndHandler ~= wndControl or not rptInfraction then
		return
	end
	rptInfraction:SetPermanentIgnore(wndHandler:IsChecked())
end

function ReportPlayer:OnReportReasonChange(wndHandler, wndControl)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local rptInfraction = self.wndMain:FindChild("OptionsPicker"):GetData()
	if not rptInfraction then
		return
	end

	rptInfraction:SetReason(wndHandler:GetData())
	self.wndMain:FindChild("YesButton"):SetActionData(GameLib.CodeEnumConfirmButtonType.ReportPlayer, rptInfraction)
end

function ReportPlayer:OnReportPlayerComplete(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("IgnorePlayerCheckbox"):IsChecked() then
		local rptInfraction = self.wndMain:FindChild("OptionsPicker"):GetData()
		local strTarget = rptInfraction and rptInfraction:GetName() or ""
		Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("Social_AddedToIgnore"), strTarget))
		--FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Ignore, strTarget) -- Intentionally not doing this, will be handled in SetPermanentIgnore
	end
	self:ClearReportConfirmation()
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", Apollo.GetString("ReportPlayer_Confirmation"))
end

function ReportPlayer:OnOptionsOpenSupportBtn(wndHandler, wndControl)
	local wndIgnorePlayerCheckBox = self.wndMain:FindChild("IgnorePlayerCheckbox")
	local rptInfraction = self.wndMain:FindChild("OptionsPicker"):GetData()
	local strTarget = rptInfraction and rptInfraction:GetName() or ""

	Event_FireGenericEvent("GenericEvent_OpenReportPlayerTicket", String_GetWeaselString(Apollo.GetString("ReportPlayer_OpenTicketFor"), wndHandler:GetData()), wndIgnorePlayerCheckBox and wndIgnorePlayerCheckBox:IsChecked(), strTarget)
	self:ClearReportConfirmation()
end

function ReportPlayer:ReportChat_WindowClosed(wndHandler)
	self:ClearReportConfirmation()
end

function ReportPlayer:ReportChat_NoPicked(wndHandler, wndControl)
	self:ClearReportConfirmation()
end

function ReportPlayer:ClearReportConfirmation() -- From a variety of sources
	if self.wndMain and self.wndMain:IsValid() then
		local rptInfraction = self.wndMain:GetData()
		if rptInfraction and rptInfraction:GetSource() == IncidentReportLib.CodeEnumReportPlayerSource.PartyRequest then
			GroupLib.DeclineInvite()
		elseif rptInfraction and rptInfraction:GetSource() == IncidentReportLib.CodeEnumReportPlayerSource.TradeRequest then
			P2PTrading.DeclineInvite()
		elseif rptInfraction and rptInfraction:GetSource() == IncidentReportLib.CodeEnumReportPlayerSource.GuildRequest then
			GuildLib.Decline()
		end
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function ReportPlayer:OnNamePickerClose() -- From a variety of sources
	if self.wndNamePicker and self.wndNamePicker:IsValid() then
		self.wndNamePicker:Destroy()
		self.wndNamePicker = nil
	end
end

function ReportPlayer:OnReportPlayer_OneSecondTimer()
	Apollo.StopTimer("ReportPlayer_OneSecondTimer")
	if self.wndMain and self.wndMain:IsValid() then
		local nLastTime = self.wndMain:FindChild("Timer"):GetData() or 1
		self.wndMain:FindChild("Timer"):SetData(nLastTime - 1)
		self.wndMain:FindChild("Timer"):SetText(String_GetWeaselString(Apollo.GetString("ReportPlayer_InviteLasts"), string.format("%d:%02d", math.floor(nLastTime / 60), math.floor(nLastTime % 60))))

		if nLastTime <= 0 then
			self:ClearReportConfirmation()
		else
			Apollo.StartTimer("ReportPlayer_OneSecondTimer")
		end
	end
end

local ReportPlayerInst = ReportPlayer:new()
ReportPlayerInst:Init()
Point="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" AutoSetText="0" UseValues="0" RelativeToClient="1" SetTextToProgress="0" DT_CENTER="1" DT_VCENTER="1" ProgressEmpty="" ProgressFull="CRB_Raid:sprRaidTear_BigShieldProgBar" TooltipType="OnCursor" Name="CurrShieldBar" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" BarColor="" Sprite="" IgnoreMouse="1" ProgressEdgeGlow="" EdgeGlow="1" NoClipEdgeGlow="0" Picture="1"/>
            </Control>
        </Control>
        <Control Class="Window" Font="Thick" LAnchorPoint="0" LAnchorOffset="34" TAnchorPoint="0" TAnchorOffset="26" RAnchorPoint="1" RAnchorOffset="12" BAnchorPoint="0" BAnchor