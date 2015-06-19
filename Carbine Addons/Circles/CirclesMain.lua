-----------------------------------------------------------------------------------------------
-- Client Lua Script for Circles
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "ChatSystemLib"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"

local Circles = {}
local knMaxNumberOfCircles = 5
local crGuildNameLengthError = ApolloColor.new("AlertOrangeYellow")
local crGuildNameLengthGood = ApolloColor.new("UI_TextHoloBodyCyan")

function Circles:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWndRefs = {}

    return o
end

function Circles:Init()
    Apollo.RegisterAddon(self)
end

function Circles:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CirclesMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Circles:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	if tSavedData.bShowOffline then
		self.bShowOffline = tSavedData.bShowOffline
	end
end

function Circles:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_InitializeCircles",	"OnGenericEvent_InitializeCircles", self)
	Apollo.RegisterEventHandler("GenericEvent_DestroyCircles", 		"OnGenericEvent_DestroyCircles", self)
	Apollo.RegisterEventHandler("GuildRoster", 						"OnGuildRoster", self)
	Apollo.RegisterEventHandler("GuildResult", 						"OnGuildResult", self)
	Apollo.RegisterEventHandler("GuildInfluenceAndMoney", 			"UpdateInfluenceAndMoney", self)
	Apollo.RegisterEventHandler("GuildMemberChange", 				"OnGuildMemberChange", self)  -- General purpose update method
	Apollo.RegisterEventHandler("GuildRankChange",					"OnGuildRankChange", self)
	Apollo.RegisterEventHandler("GuildInvite",						"OnCircleInvite", self)

	self.timerUpdateOffline = ApolloTimer.Create(30.000, true, "OnOfflineTimeUpdate", self)
	self.timerUpdateOffline:Stop()
	
	self.timerAlert = ApolloTimer.Create(3.0, false, "OnCircleAlertDisplayTimer", self)
	self.timerAlert:Stop()
	
end

function Circles:OnGenericEvent_InitializeCircles(wndParent, guildCurr)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "CirclesMainForm", wndParent, self)
	end

	local wndRosterScreen = self.tWndRefs.wndMain:FindChild("RosterScreen")
	local wndRosterBottom = wndRosterScreen:FindChild("RosterBottom")
	local wndRosterEditNotesBtn = wndRosterScreen:FindChild("RosterOptionBtnEditNotes")
	local wndRosterRemoveBtn = wndRosterBottom:FindChild("RosterOptionBtnRemove")
	local wndRosterAddBtn = wndRosterBottom:FindChild("RosterOptionBtnAdd")
	wndRosterBottom:ArrangeChildrenHorz(2)
	
	wndRosterAddBtn:AttachWindow(wndRosterAddBtn:FindChild("AddMemberContainer"))
	self.tWndRefs.wndMain:FindChild("RosterOptionBtnLeaveFlyout"):AttachWindow(self.tWndRefs.wndMain:FindChild("LeaveFlyoutBtnContainer"))
	wndRosterRemoveBtn:AttachWindow(wndRosterRemoveBtn:FindChild("RemoveMemberContainer"))
	wndRosterEditNotesBtn:AttachWindow(wndRosterEditNotesBtn:FindChild("EditNotesContainer"))
	wndRosterEditNotesBtn:Enable(true)
	wndRosterEditNotesBtn:FindChild("EditNotesContainer:EditNotesEditBoxBG:EditNotesEditbox"):SetMaxTextLength(GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildMemberNote))
	wndRosterScreen:FindChild("RankPopout:RankSettingsEntry:Name:OptionString"):SetMaxTextLength(GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildRankName))
	local wndAdvancedOptions = self.tWndRefs.wndMain:FindChild("RosterScreen:AdvancedOptionsContainer")
	self.tWndRefs.wndMain:FindChild("RosterScreen:BGOptionsHolder:OptionsBtn"):AttachWindow(wndAdvancedOptions)
	wndAdvancedOptions:FindChild("ShowOffline"):SetCheck(self.bShowOffline)
	
	self.bViewingRemovedGuild = false

	local wndPermissionContainer = wndRosterScreen:FindChild("RankPopout:RankSettingsEntry:Permissions:PermissionContainer")
	local arPermissionWindows = wndPermissionContainer:GetChildren()
	if not arPermissionWindows or #arPermissionWindows <= 0 then
		for idx, tPermission in pairs(GuildLib.GetPermissions(GuildLib.GuildType_Circle)) do
			local wndPermission = Apollo.LoadForm(self.xmlDoc, "PermissionEntry", wndPermissionContainer, self)
			local wndPermissionBtn = wndPermission:FindChild("PermissionBtn")
			wndPermissionBtn:SetText("       " .. tPermission.strName)
			wndPermission:SetData(tPermission)
			
			if tPermission.strDescription ~= nil and tPermission.strDescription ~= "" then
				wndPermission:SetTooltip(tPermission.strDescription)
			end
		end
	end
	
	wndPermissionContainer:ArrangeChildrenVert()

	self.tWndRefs.wndRankPopout = wndRosterScreen:FindChild("RankPopout")

	self.timerUpdateOffline:Start()
	self.tWndRefs.wndMain:SetData(guildCurr)
	self.tWndRefs.wndMain:Show(true)
	self:FullRedrawOfRoster()
end

function Circles:OnGenericEvent_DestroyCircles()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end
end

function Circles:OnClose()
	self.timerAlert:Stop()
	self.timerUpdateOffline:Stop()
	self.tWndRefs.wndMain:FindChild("AlertMessage"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Roster Methods
-----------------------------------------------------------------------------------------------

function Circles:FullRedrawOfRoster()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local guildCurr = self.tWndRefs.wndMain:GetData()
	local eMyRank = guildCurr:GetMyRank()
	local wndRosterScreen = self.tWndRefs.wndMain:FindChild("RosterScreen")

	wndRosterScreen:Show(true)

	if wndRosterScreen and wndRosterScreen:FindChild("RosterBottom:RosterOptionBtnPromote:PromoteMemberContainer"):IsShown() then
		self:OnRosterPromoteMemberCloseBtn()
	end
	
	guildCurr:RequestMembers() -- This will send back an event "GuildRoster"

	local wndRankPopout = wndRosterScreen:FindChild("RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	wndRankContainer:DestroyChildren()

	local nCurrentRankCount = 1
	local arRanks = guildCurr:GetRanks()
	if arRanks then
		for idx, tRankInfo in ipairs(arRanks) do
			if tRankInfo.bValid then
				local wndRank = Apollo.LoadForm(self.xmlDoc, "RankEntry", wndRankContainer, self)
				wndRank:SetData({ nRankIdx = idx, tRankData = tRankInfo, bNew = false })
				wndRank:FindChild("Name:OptionString"):SetText(tRankInfo.strName)
				wndRank:FindChild("ModifyRankBtn"):Show(arRanks[eMyRank].bChangeRankPermissions)

				nCurrentRankCount = nCurrentRankCount + 1
			end

			if next(arRanks, idx) == nil and nCurrentRankCount < #arRanks and arRanks[eMyRank].bRankCreate then
				local wndRank = Apollo.LoadForm(self.xmlDoc, "AddRankEntry", wndRankContainer, self)
			end
		end
	end

	wndRankContainer:ArrangeChildrenVert()
end

function Circles:OnGuildRoster(guildCurr, tRoster) -- Event from CPP
	if guildCurr:GetType() ~= GuildLib.GuildType_Circle or not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end
	
	if guildCurr == self.tWndRefs.wndMain:GetData() then -- Since Circles and Guild can be up at the same time
		self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid"):DeleteAll()
		self:BuildRosterList(guildCurr, self:SortRoster(tRoster, "RosterSortBtnName")) -- "RosterSortBtnName" is the default sort method to use
	end

	self.tRoster = tRoster
end

function Circles:BuildRosterList(guildCurr, tRoster)
	if not guildCurr or #tRoster == 0 then
		return
	end

	local tRanks = guildCurr:GetRanks()
	local wndGrid = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid")
	wndGrid:DeleteAll() -- TODO remove this for better performance eventually

	for key, tCurr in pairs(tRoster) do
		if self.bShowOffline or tCurr.fLastOnline == 0 then
			local strIcon = "CRB_DEMO_WrapperSprites:btnDemo_CharInvisibleNormal"
			if tCurr.nRank == 1 then -- Special icons for guild leader and council (TEMP Placeholder)
				strIcon = "CRB_Basekit:kitIcon_Holo_Profile"
			elseif tCurr.nRank == 2 then
				strIcon = "CRB_Basekit:kitIcon_Holo_Actions"
			end

			local strRank = Apollo.GetString("Circles_UnknownRank")
			if tRanks[tCurr.nRank] and tRanks[tCurr.nRank].strName then
				strRank = tRanks[tCurr.nRank].strName
			end

			local strTextColor = "UI_TextHoloBodyHighlight"
			if tCurr.fLastOnline ~= 0 then -- offline
				strTextColor = "UI_BtnTextGrayNormal"
			end
			
			if not self.strPlayerName then
				self.strPlayerName = GameLib.GetPlayerUnit():GetName()
			end

			local wndEditNoteBtn = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterOptionBtnEditNotes")
			if not wndEditNoteBtn:IsChecked() and self.strPlayerName == tCurr.strName then
				wndEditNoteBtn:FindChild("EditNotesContainer:EditNotesEditBoxBG:EditNotesEditbox"):SetText(tCurr.strNote)
			end

			local iCurrRow = wndGrid:AddRow("")
			wndGrid:SetCellLuaData(iCurrRow, 1, tCurr)
			wndGrid:SetCellImage(iCurrRow, 1, strIcon)
			wndGrid:SetCellDoc(iCurrRow, 2, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strTextColor, tCurr.strName))
			wndGrid:SetCellDoc(iCurrRow, 3, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strTextColor, strRank))
			wndGrid:SetCellDoc(iCurrRow, 4, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strTextColor, tCurr.nLevel))
			wndGrid:SetCellDoc(iCurrRow, 5, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strTextColor, tCurr.strClass))
			wndGrid:SetCellDoc(iCurrRow, 6, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strTextColor, self:HelperConvertPathToString(tCurr.ePathType)))
			wndGrid:SetCellDoc(iCurrRow, 7, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strTextColor, self:HelperConvertToTime(tCurr.fLastOnline)))
			
			wndGrid:SetCellDoc(iCurrRow, 8, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">".. FixXMLString(tCurr.strNote) .."</T>")
			wndGrid:SetCellLuaData(iCurrRow, 8, String_GetWeaselString(Apollo.GetString("GuildRoster_ActiveNoteTooltip"), tCurr.strName, string.len(tCurr.strNote) > 0 and tCurr.strNote or "N/A")) -- For tooltip
		end
	end
	
	local wndAddContainer = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnAdd:AddMemberContainer")
	local wndAddMemberEditBox = wndAddContainer:FindChild("AddMemberEditBox")
	wndAddContainer:FindChild("AddMemberYesBtn"):SetData(wndAddMemberEditBox)
	wndAddMemberEditBox:SetData(wndAddMemberEditBox) -- Since they have the same event handler
	self.tWndRefs.wndMain:FindChild("RosterScreen:RosterHeaderContainer"):SetData(tRoster)

	self:ResetRosterMemberButtons()
end

function Circles:OnRosterGridItemClick(wndControl, wndHandler, iRow, iCol, eMouseButton)
	local wndRosterGrid = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid")
	local wndData = wndRosterGrid:GetCellData(iRow, 1)
	
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndData and wndData.strName and wndData.strName ~= GameLib.GetPlayerUnit():GetName() then
		local unitTarget = nil
		local tOptionalCharacterData = { guildCurr = self.tWndRefs.wndMain:GetData(), tPlayerGuildData = wndData }
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", self.tWndRefs.wndMain, wndData.strName, unitTarget, tOptionalCharacterData)
		return
	end

	if wndRosterGrid:GetData() == wndData then
		self.tWndRefs.wndMain:FindChild("RosterScreen:RosterPopout"):Show(false)
		wndRosterGrid:SetData(nil)
		wndRosterGrid:SetCurrentRow(0) -- Deselect grid
	else
		wndRosterGrid:SetData(wndData)
	end

	if self.tWndRefs.wndMain:FindChild("RosterScreen:RosterPopout"):IsShown() then
		self:DrawRosterPopout()
	else
		self:ResetRosterMemberButtons()
	end
end

-----------------------------------------------------------------------------------------------
-- Rank Methods
-----------------------------------------------------------------------------------------------

function Circles:OnRanksButtonSignal()
	local wndRankPopout = self.tWndRefs.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndRankSettings = wndRankPopout:FindChild("RankSettingsEntry")

	local bShow = not wndRankPopout:IsShown()

	wndRankPopout:Show(bShow)
	wndRankContainer:Show(bShow)
	wndRankSettings:Show(false)
	self.tWndRefs.wndMain:FindChild("AdvancedOptionsContainer"):Show(false)
end

function Circles:OnAddRankBtnSignal(wndControl, wndHandler)
	local wndRankPopout = self.tWndRefs.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local arRanks = guildCurr:GetRanks()

	local tFirstInactiveRank = nil
	for idx, tRank in ipairs(arRanks) do
		if not tRank.bValid then
			tFirstInactiveRank = { nRankIdx = idx, tRankData = tRank, bNew = true }
			break
		end
	end

	if tFirstInactiveRank == nil then
		return
	end

	wndRankContainer:Show(false)
	wndSettings:Show(true)
	wndSettings:SetData(tFirstInactiveRank)

	--Default to nothing
	wndSettings:FindChild("Name:OptionString"):SetText("")
	local wndPermissionContainer = self.tWndRefs.wndMain:FindChild("RosterScreen:RankPopout:RankSettingsEntry:Permissions:PermissionContainer")
	for key, wndPermission in pairs(wndPermissionContainer:GetChildren()) do
		wndPermission:FindChild("PermissionBtn"):SetCheck(false)
	end

	--won't have members when creating
	wndSettings:FindChild("Delete"):Show(false)
	wndSettings:FindChild("MemberCount"):Show(false)
	
	self:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
end

function Circles:OnViewRankBtnSignal(wndControl, wndHandler)
	local wndRankContainer = self.tWndRefs.wndRankPopout:FindChild("RankContainer")
	local wndSettings = self.tWndRefs.wndRankPopout:FindChild("RankSettingsEntry")
	local nRankIdx = wndControl:GetParent():GetData().nRankIdx
	local tRank = wndControl:GetParent():GetData().tRankData
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local arRanks = guildCurr:GetRanks()
	local eMyRank = guildCurr:GetMyRank()

	wndRankContainer:Show(false)
	wndSettings:SetData(wndControl:GetParent():GetData())
	wndSettings:Show(true)

	wndSettings:FindChild("Name:OptionString"):SetText(tRank.strName)
	local wndPermissionContainer = wndSettings:FindChild("Permissions:PermissionContainer")
	for key, wndPermission in pairs(wndPermissionContainer:GetChildren()) do
		wndPermission:FindChild("PermissionBtn"):SetCheck(tRank[wndPermission:GetData().strLuaVariable])
	end

	local nRankMemberCount = 0
	local nRankMemberOnlineCount = 0
	for idx, tMember in ipairs(self.tRoster) do
		if tMember.nRank == nRankIdx then
			nRankMemberCount = nRankMemberCount + 1

			if tMember.fLastOnline == 0 then
				nRankMemberOnlineCount = nRankMemberOnlineCount + 1
			end
		end
	end

	local bCanDelete = arRanks[eMyRank].bRankCreate and nRankIdx ~= 1 and nRankIdx ~= 2 and nRankIdx ~= 10 and nRankMemberCount == 0
	wndSettings:FindChild("Permissions:PermissionContainerBlocker"):Show(nRankIdx == 1)

	wndSettings:FindChild("Delete"):Show(bCanDelete)
	wndSettings:FindChild("MemberCount"):Show(true)
	wndSettings:FindChild("MemberCount"):SetText(String_GetWeaselString(Apollo.GetString("Guild_MemberCount"), nRankMemberCount, nRankMemberOnlineCount))

	self:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
end

function Circles:OnRankSettingsSaveBtn(wndControl, wndHandler)
	local wndRankPopout = self.tWndRefs.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")
	local bNew = wndControl:GetParent():GetData().bNew
	local tRank = wndControl:GetParent():GetData().tRankData
	local nRankIdx = wndControl:GetParent():GetData().nRankIdx
	local guildCurr = self.tWndRefs.wndMain:GetData()

	wndRankPopout:FindChild("RankContainer"):Show(true)
	wndSettings:Show(false)

	local strName = wndSettings:FindChild("Name:OptionString"):GetText()
	if strName ~= tRank.strName then
		if bNew then
			guildCurr:AddRank(nRankIdx, strName)
		else
			guildCurr:RenameRank(nRankIdx, strName)
		end
		tRank.strName = strName
	end

	local bDirtyRank = false
	for key, wndPermission in pairs(wndSettings:FindChild("Permissions:PermissionContainer"):GetChildren()) do
		local bPermissionChecked = wndPermission:FindChild("PermissionBtn"):IsChecked()
		if tRank[wndPermission:GetData().strLuaVariable] ~= bPermissionChecked then
			bDirtyRank = true
		end

		tRank[wndPermission:GetData().strLuaVariable] = wndPermission:FindChild("PermissionBtn"):IsChecked()
	end

	if bDirtyRank then
		guildCurr:ModifyRank(nRankIdx, tRank)
	end

	wndControl:GetParent():SetData(tRank)
	--TODO update list display name for rank name
end

function Circles:OnRankSettingsDeleteBtn(wndControl, wndHandler)
	local wndRankPopout = self.tWndRefs.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")

	local nRankIdx = wndSettings:GetData().nRankIdx
	local guildCurr = self.tWndRefs.wndMain:GetData()

	guildCurr:RemoveRank(nRankIdx)

	wndRankContainer:Show(true)
	wndSettings:Show(false)
end

function Circles:OnRankSettingsNameChanging(wndControl, wndHandler, strText)
	self:HelperValidateAndRefreshRankSettingsWindow(self.tWndRefs.wndRankPopout:FindChild("RankSettingsEntry"))
end

function Circles:OnRankSettingsPermissionBtn(wndControl, wndHandler)
	self:HelperValidateAndRefreshRankSettingsWindow(self.tWndRefs.wndRankPopout:FindChild("RankSettingsEntry"))
end

function Circles:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
	local wndLimit = wndSettings:FindChild("Name:Limit")
	local tRank = wndSettings:GetData()
	local strName = wndSettings:FindChild("Name:OptionString"):GetText()

	if wndLimit ~= nil then
		local nNameLength = string.len(strName or "")

		wndLimit:SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nNameLength, GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildRankName)))
		wndLimit:SetTextColor(nNameLength < 1 and crGuildNameLengthError or crGuildNameLengthGood)
	end

	local bNameValid = strName ~= nil and strName ~= "" and GameLib.IsTextValid(strName, GameLib.CodeEnumUserText.GuildRankName, GameLib.CodeEnumUserTextFilterClass.Strict)
	local bNameChanged = strName ~= tRank.strName

	local bPermissionChanged = false
	for key, wndPermission in pairs(wndSettings:FindChild("Permissions:PermissionContainer"):GetChildren()) do
		local bPermissionChecked = wndPermission:FindChild("PermissionBtn"):IsChecked()
		if tRank.tRankData[wndPermission:GetData().strLuaVariable] ~= bPermissionChecked then
			bPermissionChanged = true
			break
		end
	end

	wndSettings:FindChild("RankPopoutOkBtn"):Enable((bNew and bNameValid) or (not bNew and bNameValid and (bNameChanged or bPermissionChanged)))
	wndSettings:FindChild("StatusValidAlert"):Show(not bNameValid)
end

function Circles:OnRankSettingsCloseBtn(wndControl, wndHandler)
	local wndRankPopout = self.tWndRefs.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")

	wndRankPopout:FindChild("RankContainer"):Show(true)
	wndSettings:Show(false)
end

function Circles:OnGuildRankChange(guildCurr)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	
	if guildCurr ~= self.tWndRefs.wndMain:GetData() then
		return
	end
	self:FullRedrawOfRoster()
end

function Circles:OnRankPopoutCloseBtn(wndControl, wndHandler)
	local wndParent = wndControl:GetParent()
	wndParent:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Bottom Panel Roster Actions
-----------------------------------------------------------------------------------------------

function Circles:OnOfflineBtn(wndHandler, wndControl)
	self.bShowOffline = wndControl:IsChecked()
	
	self:FullRedrawOfRoster()
end

function Circles:ResetRosterMemberButtons()
	-- Defaults
	local wndRosterBottom = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom")
	local wndAddBtn = wndRosterBottom:FindChild("RosterOptionBtnAdd")
	local wndRemoveBtn = wndRosterBottom:FindChild("RosterOptionBtnRemove")
	local wndDemoteBtn = wndRosterBottom:FindChild("RosterOptionBtnDemote")
	local wndPromoteBtn = wndRosterBottom:FindChild("RosterOptionBtnPromote")
	local wndLeaveFlyoutBtn = self.tWndRefs.wndMain:FindChild("AdvancedOptionsContainer"):FindChild("RosterOptionBtnLeaveFlyout")

	-- Enable member options based on Permissions (note Code will also guard against this) -- TODO
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local eMyRank = guildCurr:GetMyRank()

	if guildCurr and eMyRank then
		local wndRosterGrid = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid")
		local tMyRankPermissions = guildCurr:GetRanks()[eMyRank]
		local bSomeRowIsPicked = wndRosterGrid:GetCurrentRow()
		local bTargetIsUnderMyRank = bSomeRowIsPicked and eMyRank < wndRosterGrid:GetData().nRank

		wndRemoveBtn:Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)
		wndPromoteBtn:Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)
		wndDemoteBtn:Enable(bSomeRowIsPicked and bTargetIsUnderMyRank and wndRosterGrid:GetData().nRank ~= 10) -- Circles can't go below 10

		wndAddBtn:Show(tMyRankPermissions and tMyRankPermissions.bInvite)
		wndRemoveBtn:Show(tMyRankPermissions and tMyRankPermissions.bKick)
		wndDemoteBtn:Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)
		wndPromoteBtn:Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)

		if eMyRank == 1 then
			wndLeaveFlyoutBtn:SetText(Apollo.GetString("Circles_Disband"))
		else
			wndLeaveFlyoutBtn:SetText(Apollo.GetString("Circles_Leave"))
		end
	else
		wndAddBtn:Show(false)
		wndRemoveBtn:Show(false)
		wndDemoteBtn:Show(false)
		wndPromoteBtn:Show(false)
		wndAddBtn:SetCheck(false)
		wndRemoveBtn:SetCheck(false)
		wndDemoteBtn:SetCheck(false)
		wndPromoteBtn:SetCheck(false)
		wndLeaveFlyoutBtn:SetCheck(false)
	end

	wndRosterBottom:ArrangeChildrenHorz(0)
end

-----------------------------------------------------------------------------------------------
-- Member permissions updating buttons
-----------------------------------------------------------------------------------------------

function Circles:OnRosterAddMemberClick(wndHandler, wndControl)
	self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnAdd:AddMemberContainer:AddMemberEditBox"):SetFocus()
end

function Circles:OnRosterRemoveMemberClick(wndHandler, wndControl)
	self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnRemove:RemoveMemberContainer:RemoveMemberLabel"):SetText(String_GetWeaselString(Apollo.GetString("Circles_KickConfirmation"), self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid"):GetData().strName))
end

function Circles:OnRosterPromoteMemberClick(wndHandler, wndControl) -- wndHandler is "RosterOptionBtnPromote"
	-- This one is different, it'll fire right away unless promoting to leader
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()
	local wndPromoteBtn = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnPromote")
	if tMember.nRank == 2 then
		wndPromoteBtn:FindChild("PromoteMemberContainer"):Show(true)
		wndPromoteBtn:SetCheck(true)
	else
		guildCurr:Promote(tMember.strName) -- TODO: More error checking
		wndPromoteBtn:FindChild("PromoteMemberContainer"):Show(false)
		wndPromoteBtn:SetCheck(false)
	end
end

function Circles:OnRosterEditNoteSave(wndHandler, wndControl)
	wndHandler:SetFocus()
	self.tWndRefs.wndMain:FindChild("EditNotesContainer"):Close()

	local guildCurr = self.tWndRefs.wndMain:GetData()
	guildCurr:SetMemberNoteSelf(self.tWndRefs.wndMain:FindChild("EditNotesEditbox"):GetText())
end

-- Closing the Pop Up Bubbles
function Circles:OnRosterAddMemberCloseBtn()
	local wndAddMemberContainer = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnAdd:AddMemberContainer")
	wndAddMemberContainer:FindChild("AddMemberEditBox"):SetText("")
	wndAddMemberContainer:Show(false)
end

function Circles:OnRosterPromoteMemberCloseBtn()
	local wndPromoteBtn = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnPromote")
	wndPromoteBtn:FindChild("PromoteMemberContainer"):Show(false)
	wndPromoteBtn:SetCheck(false) -- Since we aren't using AttachWindow
end

function Circles:OnRosterRemoveMemberCloseBtn()
	self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnRemove:RemoveMemberContainer"):Show(false)
end

function Circles:OnRosterLeaveCloseBtn()
	self.tWndRefs.wndMain:FindChild("LeaveFlyoutBtnContainer"):Show(false)
end

function Circles:OnPlayerNoteChanged(wndHandler, wndControl, strNewNote)
	if wndControl ~= wndHandler then 
		return 
	end
	local wndNote = self.tWndRefs.wndMain:FindChild("EditNotesContainer")
	local bValid = GameLib.IsTextValid(strNewNote or "", GameLib.CodeEnumUserText.GuildMemberNote, GameLib.CodeEnumUserTextFilterClass.Strict)
	
	wndNote:FindChild("EditNotesYesBtn"):Enable(bValid)
	wndNote:FindChild("StatusValidAlert"):Show(not bValid)
end

function Circles:OnEditNoteBtn(wndHandler, wndControl)
	if wndControl ~= wndHandler then 
		return 
	end
	local wndNote = self.tWndRefs.wndMain:FindChild("EditNotesContainer")
	for key, tCurr in pairs(self.tRoster) do
		if self.strPlayerName == tCurr.strName then
			wndNote:FindChild("EditNotesEditbox"):SetText(tCurr.strNote)
		end
	end
	wndNote:FindChild("EditNotesYesBtn"):Enable(false)
	wndNote:FindChild("StatusValidAlert"):Show(false)
end

-- Saying Yes to the Pop Up Bubbles
function Circles:OnAddMemberYesClick(wndHandler, wndControl) -- wndHandler is 'AddMemberEditBox' or 'AddMemberYesBtn', and its data is 'AddMemberEditBox'
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local wndEditBox = wndHandler:GetData()

	if wndEditBox and wndEditBox:GetData() and string.len(wndEditBox:GetText()) > 0 then -- TODO: Additional string validation
		guildCurr:Invite(wndEditBox:GetText())
	end
	self:OnRosterAddMemberCloseBtn()
end

function Circles:OnRosterPromoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'PromoteMemberYesBtn'
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()

	guildCurr:PromoteMaster(tMember.strName)
	self:OnRosterPromoteMemberCloseBtn()
end

function Circles:OnRosterDemoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RosterOptionBtnDemote' data should be guildCurr
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()
	guildCurr:Demote(tMember.strName)
	-- Note: Demote has no pop out
end

function Circles:OnRosterRemoveMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RemoveMemberYesBtn'
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()
	guildCurr:Kick(tMember.strName)
	self:OnRosterRemoveMemberCloseBtn()
end

function Circles:OnRosterLeaveYesClick(wndHandler, wndControl) -- wndHandler is "LeaveBtnYesBtn"
	local guildCurr = self.tWndRefs.wndMain:GetData()
	if guildCurr and guildCurr:GetMyRank() == 1 then
		guildCurr:Disband()
	elseif guildCurr then
		guildCurr:Leave()
	end
	self.tWndRefs.wndMain:FindChild("AdvancedOptionsContainer"):Close()
	self.tWndRefs.wndMain:FindChild("LeaveFlyoutBtnContainer"):Show(false)
	self.tWndRefs.wndMain:Close()
end

-----------------------------------------------------------------------------------------------
-- OnGuildMemberChange
-----------------------------------------------------------------------------------------------

function Circles:OnGuildMemberChange( guildCurr )
	if guildCurr and guildCurr:GetType() == GuildLib.GuildType_Circle  or GuildLib.GuildType_Guild then
		self:FullRedrawOfRoster()
	end
end

function Circles:OnOfflineTimeUpdate()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end
	
	local wndGrid = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterGrid")
	local nSelectedRow = wndGrid:GetCurrentRow()
	
	local wndRosterBottom = self.tWndRefs.wndMain:FindChild("RosterScreen:RosterBottom")
	local wndAddBtn = wndRosterBottom:FindChild("RosterOptionBtnAdd")
	local wndRemoveBtn = wndRosterBottom:FindChild("RosterOptionBtnRemove")

	local bAddSelected = wndAddBtn:IsChecked()
	local wndRemoveSelected = wndRemoveBtn:IsChecked()
	
	-- Calling RequestMembers will fire the GuildRoster event, which tends to reset a lot of the things we have selected.
	self.tWndRefs.wndMain:GetData():RequestMembers()
	
	wndGrid:SetCurrentRow(nSelectedRow or 0)
	
	wndAddBtn:SetCheck(bAddSelected)
	wndRemoveBtn:SetCheck(bRemoveSelected)
end

-----------------------------------------------------------------------------------------------
-- OnGuildResult
-----------------------------------------------------------------------------------------------

function Circles:OnGuildResult(guildCurr, strName, nRank, eResult)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end
	-- Reload UI when a circle is made
	if guildCurr and guildCurr:GetType() == GuildLib.GuildType_Circle then
		local guildViewed = self.tWndRefs.wndMain:GetData()
		self.bViewingRemovedGuild = false -- is the affected guild shown?

		if guildViewed ~= nil and self.tWndRefs.wndMain:IsShown() and self.tWndRefs.wndMain:FindChild("RosterScreen"):IsShown() and guildViewed:GetName() == strName then
			self.bViewingRemovedGuild = true -- we need to redraw in these instances
		end

		-- if you've been kicked, left, or disbanded a circle and you're viewing it
		if eResult == GuildLib.GuildResult_KickedYou and self.tWndRefs.wndMain:IsShown() then
			self.tWndRefs.wndMain:FindChild("AlertMessage"):FindChild("MessageAlertText"):SetText(Apollo.GetString("Circles_Ouch"))
			self.tWndRefs.wndMain:FindChild("AlertMessage"):FindChild("MessageBodyText"):SetText(String_GetWeaselString(Apollo.GetString("Circles_Kicked"), strName))
			self.tWndRefs.wndMain:FindChild("AlertMessage"):Invoke()
			self.timerAlert:Start()
		elseif eResult == GuildLib.GuildResult_YouQuit and self.tWndRefs.wndMain:IsShown() then
			self.tWndRefs.wndMain:FindChild("AlertMessage"):FindChild("MessageAlertText"):SetText(Apollo.GetString("Circles_Bye"))
			self.tWndRefs.wndMain:FindChild("AlertMessage"):FindChild("MessageBodyText"):SetText(String_GetWeaselString(Apollo.GetString("Circles_LeftCircle"), strName))
			self.tWndRefs.wndMain:FindChild("AlertMessage"):Invoke()
			self.timerAlert:Start()
		elseif eResult == GuildLib.GuildResult_GuildDisbanded and self.tWndRefs.wndMain:IsShown() then
			self.tWndRefs.wndMain:FindChild("AlertMessage"):FindChild("MessageAlertText"):SetText(Apollo.GetString("Circles_CircleDisbanded"))
			self.tWndRefs.wndMain:FindChild("AlertMessage"):FindChild("MessageBodyText"):SetText(String_GetWeaselString(Apollo.GetString("Circles_YouDisbanded"), strName))
			self.tWndRefs.wndMain:FindChild("AlertMessage"):Invoke()
			self.timerAlert:Start()
		end
	end
end

function Circles:OnCircleAlertDisplayTimer()
	self.tWndRefs.wndMain:FindChild("AlertMessage"):Show(false)
	self.tWndRefs.wndMain:Close()
end

-----------------------------------------------------------------------------------------------
-- Circle Invite Window
-----------------------------------------------------------------------------------------------

function Circles:OnCircleInvite( strGuildName, strInvitorName, guildType )
	if guildType ~= GuildLib.GuildType_Circle then
		return
	end

	if self.wndCircleInvite ~= nil then
		self.wndCircleInvite:Destroy()
	end

	self.wndCircleInvite = Apollo.LoadForm(self.xmlDoc, "CircleInviteConfirmation", nil, self)
	self.wndCircleInvite:FindChild("CircleInviteLabel"):SetText(String_GetWeaselString(Apollo.GetString("Guild_IncomingCircleInvite"), strGuildName, strInvitorName))
	self.wndCircleInvite:ToFront()

end

function Circles:OnCircleInviteAccept(wndHandler, wndControl)
	GuildLib.Accept()
	if self.wndCircleInvite then
		self.wndCircleInvite:Destroy()
	end
end

function Circles:OnCircleInviteDecline() -- This can come from a variety of sources
	GuildLib.Decline()
	if self.wndCircleInvite then
		self.wndCircleInvite:Destroy()
	end
end

function Circles:OnReportCircleInviteSpamBtn()
	Event_FireGenericEvent("GenericEvent_ReportPlayerCircleInvite") -- Order is important
	--self:OnCircleInviteDecline()
	self.wndCircleInvite:Destroy()
end

-----------------------------------------------------------------------------------------------
-- Roster Sorting
-----------------------------------------------------------------------------------------------

function Circles:OnRosterSortToggle(wndHandler, wndControl)
	self:BuildRosterList(self.tWndRefs.wndMain:GetData(), self:SortRoster(self.tWndRefs.wndMain:FindChild("RosterScreen:RosterHeaderContainer"):GetData(), wndHandler:GetName()))
end

function Circles:SortRoster(tArg, strLastClicked)
	-- TODO: Two tiers of sorting. E.g. Clicking Name then Path will give Paths sorted first, then Names sorted second
	if not tArg then return end
	local tResult = tArg

	if self.tWndRefs.wndMain:FindChild("RosterSortBtnName"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.strName > b.strName) end)
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnRank"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.nRank > b.nRank) end)
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnLevel"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.nLevel < b.nLevel) end) -- Level we want highest to lowest
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnClass"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.strClass > b.strClass) end)
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnPath"):IsChecked() then
		table.sort(tResult, function(a,b) return (self:HelperConvertPathToString(a.ePathType) > self:HelperConvertPathToString(b.ePathType)) end) -- TODO: Potentially expensive?
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnOnline"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.fLastOnline < b.fLastOnline) end)
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnNote"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.strNote < b.strNote) end)
	else
		-- Determine the last clicked with the second argument
		if strLastClicked == "RosterSortBtnName" then
			table.sort(tResult, function(a,b) return (a.strName < b.strName) end)
		elseif strLastClicked == "RosterSortBtnRank" then
			table.sort(tResult, function(a,b) return (a.nRank < b.nRank) end)
		elseif strLastClicked == "RosterSortBtnLevel" then
			table.sort(tResult, function(a,b) return (a.nLevel > b.nLevel) end)
		elseif strLastClicked == "RosterSortBtnClass" then
			table.sort(tResult, function(a,b) return (a.strClass < b.strClass) end)
		elseif strLastClicked == "RosterSortBtnPath" then
			table.sort(tResult, function(a,b) return (self:HelperConvertPathToString(a.ePathType) < self:HelperConvertPathToString(b.ePathType)) end)
		elseif strLastClicked == "RosterSortBtnOnline" then
			table.sort(tResult, function(a,b) return (a.fLastOnline > b.fLastOnline) end)
		elseif strLastClicked == "RosterSortBtnNote" then
			table.sort(tResult, function(a,b) return (a.strNote > b.strNote) end)
		end
	end

	return tResult
end


function Circles:OnOptionsCloseClick(wndControl)
	wndControl:GetParent():Close()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function Circles:OnGenerateGridTooltip(wndHandler, wndControl, eType, iRow, iColumn)
	-- If the note column 7, draw a special tooltip
	wndHandler:SetTooltip(self.tWndRefs.wndMain:FindChild("RosterGrid"):GetCellData(iRow + 1, 8) or "") -- TODO: Remove this hardcoded
end

function Circles:HelperConvertPathToString(ePath)
	local strResult = ""
	if ePath == PlayerPathLib.PlayerPathType_Soldier then
		strResult = Apollo.GetString("PlayerPathSoldier")
	elseif ePath == PlayerPathLib.PlayerPathType_Settler then
		strResult = Apollo.GetString("PlayerPathSettler")
	elseif ePath == PlayerPathLib.PlayerPathType_Explorer then
		strResult = Apollo.GetString("PlayerPathExplorer")
	elseif ePath == PlayerPathLib.PlayerPathType_Scientist then
		strResult = Apollo.GetString("PlayerPathScientist")
	end
	return strResult
end

function Circles:HelperConvertToTime(nDays)
	if nDays == 0 then
		return Apollo.GetString("ArenaRoster_Online")
	end

	if nDays == nil then
		return ""
	end

	local tTimeInfo = {["name"] = "", ["count"] = nil}

	if nDays >= 365 then -- Years
		tTimeInfo["name"] = Apollo.GetString("CRB_Year")
		tTimeInfo["count"] = math.floor(nDays / 365)
	elseif nDays >= 30 then -- Months
		tTimeInfo["name"] = Apollo.GetString("CRB_Month")
		tTimeInfo["count"] = math.floor(nDays / 30)
	elseif nDays >= 7 then
		tTimeInfo["name"] = Apollo.GetString("CRB_Week")
		tTimeInfo["count"] = math.floor(nDays / 7)
	elseif nDays >= 1 then -- Days
		tTimeInfo["name"] = Apollo.GetString("CRB_Day")
		tTimeInfo["count"] = math.floor(nDays)
	else
		local fHours = nDays * 24
		local nHoursRounded = math.floor(fHours)
		local nMin = math.floor(fHours*60)

		if nHoursRounded > 0 then
			tTimeInfo["name"] = Apollo.GetString("CRB_Hour")
			tTimeInfo["count"] = nHoursRounded
		elseif nMin > 0 then
			tTimeInfo["name"] = Apollo.GetString("CRB_Min")
			tTimeInfo["count"] = nMin
		else
			tTimeInfo["name"] = Apollo.GetString("CRB_Min")
			tTimeInfo["count"] = 1
		end
	end

	return String_GetWeaselString(Apollo.GetString("CRB_TimeOffline"), tTimeInfo)
end

local CirclesInst = Circles:new()
CirclesInst:Init()
