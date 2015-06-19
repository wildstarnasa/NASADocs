-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildRoster
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "ChatSystemLib"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"
require "GameLib"

local GuildRoster = {}
local knMaxNumberOfCircles = 5
local crGuildNameLengthError = ApolloColor.new("AlertOrangeYellow")
local crGuildNameLengthGood = ApolloColor.new("UI_TextHoloBodyCyan")

function GuildRoster:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWndRefs = {}

    return o
end

function GuildRoster:Init()
    Apollo.RegisterAddon(self)
end

function GuildRoster:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildRoster.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	self.tRoster = nil
	self.strPlayerName = nil
	self.bViewingRemovedGuild = false
	
	self.strSelectedName = nil
	self.nSelectedIndex = 0
	
	self.bShowOffline = true
	self.bRosterSortAsc = true
	self.strRosterSort = "RosterSortBtnName"
end

function GuildRoster:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local tSavedData =
	{
		bShowOffline = self.bShowOffline,
		bRosterSortAsc = self.bRosterSortAsc,
		strRosterSort = self.strRosterSort
	}

	return tSavedData
end

function GuildRoster:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	if tSavedData.bShowOffline ~= nil then
		self.bShowOffline = tSavedData.bShowOffline
	end
	
	if tSavedData.bRosterSortAsc then
		self.bRosterSortAsc = tSavedData.bRosterSortAsc
	end
	
	if tSavedData.strRosterSort then
		self.strRosterSort = tSavedData.strRosterSort
	end
end

function GuildRoster:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
    Apollo.RegisterEventHandler("Guild_ToggleRoster",               "OnToggleRoster", self)
	Apollo.RegisterEventHandler("GuildWindowHasBeenClosed", 		"OnClose", self)
	
	Apollo.RegisterEventHandler("GuildRoster",                      "OnGuildRoster", self)
	Apollo.RegisterEventHandler("GuildMemberChange",                "OnGuildMemberChange", self)  -- General purpose update method
	Apollo.RegisterEventHandler("GuildRankChange",					"OnGuildRankChange", self)
end

function GuildRoster:Initialize(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then
		return
	end
	
	local wndMain = Apollo.LoadForm(self.xmlDoc, "GuildRosterForm", wndParent, self)
	self.tWndRefs.wndMain = wndMain
    self.tWndRefs.wndEditRankPopout = wndMain:FindChild("EditRankPopout")
	self.tWndRefs.wndRosterOptionBtnAdd = wndMain:FindChild("RosterOptionBtnAdd")
	self.tWndRefs.wndRosterOptionBtnRemove = wndMain:FindChild("RosterOptionBtnRemove")
	self.tWndRefs.wndRosterOptionBtnDemote = wndMain:FindChild("RosterOptionBtnDemote")
	self.tWndRefs.wndRosterOptionBtnPromote = wndMain:FindChild("RosterOptionBtnPromote")
	self.tWndRefs.wndRosterOptionBtnLeaveFlyout = wndMain:FindChild("RosterOptionBtnLeaveFlyout")
	self.tWndRefs.wndRosterBottom = wndMain:FindChild("RosterBottom")
	self.tWndRefs.wndPermissionContainer = wndMain:FindChild("PermissionContainer")
	
	wndMain:Show(true)
	
	wndMain:FindChild(self.strRosterSort):SetCheck(true)
	self.tWndRefs.wndRosterBottom:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	self.tWndRefs.wndRosterOptionBtnAdd:AttachWindow(wndMain:FindChild("AddMemberContainer"))
	self.tWndRefs.wndRosterOptionBtnLeaveFlyout:AttachWindow(wndMain:FindChild("LeaveFlyoutBtnContainer"))
	self.tWndRefs.wndRosterOptionBtnRemove:AttachWindow(wndMain:FindChild("RemoveMemberContainer"))
	wndMain:FindChild("RosterOptionBtnEditNotes"):AttachWindow(wndMain:FindChild("EditNotesContainer"))

	wndMain:FindChild("OptionsBtn"):AttachWindow(wndMain:FindChild("AdvancedOptionsContainer"))
	wndMain:FindChild("ShowOffline"):SetCheck(self.bShowOffline)

	local wndPermissionContainer = self.tWndRefs.wndPermissionContainer
	for idx, tPermission in pairs(GuildLib.GetPermissions(GuildLib.GuildType_Guild)) do
		local wndPermission = Apollo.LoadForm(self.xmlDoc, "PermissionEntry", wndPermissionContainer, self)
		local wndPermissionBtn = wndPermission:FindChild("PermissionBtn")
		wndPermissionBtn:SetText("       " .. tPermission.strName) -- TODO REMOVE HARDCODE
		wndPermission:SetData(tPermission)
		
		if tPermission.strDescription ~= nil and tPermission.strDescription ~= "" then
			wndPermission:SetTooltip(tPermission.strDescription)
		end
	end
	wndPermissionContainer:ArrangeChildrenVert()
	
	wndMain:SetData(guildOwner)
	wndMain:FindChild("EditNotesEditbox"):SetMaxTextLength(GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildMemberNote))
end

function GuildRoster:OnToggleRoster(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then
		return
	end
	
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		self:Initialize(wndParent)
		
		guildOwner:RequestMembers()
		self:FullRedrawOfRoster(false)
	else
		self.tWndRefs.wndMain:Show(true)
	end
end

function GuildRoster:OnClose()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end
end

-----------------------------------------------------------------------------------------------
-- Roster Methods
-----------------------------------------------------------------------------------------------

function GuildRoster:FullRedrawOfRoster(bDrawRoster)
	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end

	local guildCurr = self.tWndRefs.wndMain:GetData()
	if guildCurr == nil then
		return
	end
	
	local eMyRank = guildCurr:GetMyRank()

	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:FindChild("PromoteMemberContainer"):IsShown() then
		self:OnRosterPromoteMemberCloseBtn()
	end

	if bDrawRoster then
		self:BuildRosterList(guildCurr, self:SortRoster(self.tWndRefs.wndMain:FindChild("RosterHeaderContainer"):GetData()))
	end
	
	self.tWndRefs.wndEditRankPopout:FindChild("RankContainer"):DestroyChildren()
	
	local nCurrentRankCount = 1
	local arRanks = guildCurr:GetRanks()
	if arRanks == nil then
		return
	end
	
	for idx, tRankInfo in ipairs(arRanks) do
		if tRankInfo.bValid then
			local wndRank = Apollo.LoadForm(self.xmlDoc, "RankEntry", self.tWndRefs.wndEditRankPopout:FindChild("RankContainer"), self)
			wndRank:SetData({ nRankId = idx, tRankInfo = tRankInfo, bNew = false })
			wndRank:FindChild("OptionString"):SetText(tRankInfo.strName)
			nCurrentRankCount = nCurrentRankCount + 1
		end
		
		if next(arRanks, idx) == nil and nCurrentRankCount < #arRanks and arRanks[eMyRank].bRankCreate then
			local wndRank = Apollo.LoadForm(self.xmlDoc, "AddRankEntry", self.tWndRefs.wndEditRankPopout:FindChild("RankContainer"), self)
		end
	end

	self.tWndRefs.wndEditRankPopout:FindChild("RankContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
end

function GuildRoster:OnGuildRoster(guildCurr, tRoster) -- Event from CPP
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() and guildCurr == self.tWndRefs.wndMain:GetData() then
		self.tWndRefs.wndMain:FindChild("RosterGrid"):DeleteAll()
		self:BuildRosterList(guildCurr, self:SortRoster(tRoster)) -- "RosterSortBtnName" is the default sort method to use	
		self.tRoster = tRoster
	end
end

function GuildRoster:BuildRosterList(guildCurr, tRoster)
	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:GetData() then
		return
	end
		
	if not guildCurr or tRoster == nil or #tRoster == 0 then
		return
	end

	local tRanks = guildCurr:GetRanks()
	if tRanks == nil then
		return --New guild and we have not yet recieved the data
	end
	
	local wndGrid = self.tWndRefs.wndMain:FindChild("RosterGrid")
	local tSelectedRow = nil
	
	wndGrid:DeleteAll() -- TODO remove this for better performance eventually
	
	local tRosterDiff = self:CompareRoster(tRoster)
	
	for key, tCurr in pairs(tRosterDiff) do
		tCurr.nRowIndex = key
		
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
				strRank = FixXMLString(strRank)
			end

			local strTextColor = "UI_TextHoloBodyHighlight"
			if tCurr.fLastOnline ~= 0 then -- offline
				strTextColor = "UI_BtnTextGrayNormal"
			end

			if not self.strPlayerName then
				self.strPlayerName = GameLib.GetPlayerUnit():GetName()
			end

			local wndNoteEditBox = self.tWndRefs.wndMain:FindChild("EditNotesEditbox")
			if self.strPlayerName == tCurr.strName and not wndNoteEditBox:IsShown() then
				wndNoteEditBox:SetText(tCurr.strNote)
			end
			
			if self.strSelectedName == tCurr.strName then
				tSelectedRow = tCurr
			end
			
			local iCurrRow = wndGrid:AddRow("")
			wndGrid:SetCellLuaData(iCurrRow, 1, tCurr)
			wndGrid:SetCellImage(iCurrRow, 1, strIcon)
			wndGrid:SetCellDoc(iCurrRow, 2, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..tCurr.strName.."</T>")
			wndGrid:SetCellDoc(iCurrRow, 3, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..strRank.."</T>")
			wndGrid:SetCellDoc(iCurrRow, 4, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..tCurr.nLevel.."</T>")
			wndGrid:SetCellDoc(iCurrRow, 5, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..tCurr.strClass.."</T>")
			wndGrid:SetCellDoc(iCurrRow, 6, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..self:HelperConvertPathToString(tCurr.ePathType).."</T>")
			wndGrid:SetCellDoc(iCurrRow, 7, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..self:HelperConvertToTime(tCurr.fLastOnline).."</T>")			
			
			wndGrid:SetCellDoc(iCurrRow, 8, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">".. FixXMLString(tCurr.strNote) .."</T>")
			wndGrid:SetCellLuaData(iCurrRow, 8, String_GetWeaselString(Apollo.GetString("GuildRoster_ActiveNoteTooltip"), tCurr.strName, string.len(tCurr.strNote) > 0 and tCurr.strNote or "N/A")) -- For tooltip
		end
	end
	
	self.tWndRefs.wndMain:FindChild("AddMemberYesBtn"):SetData(self.tWndRefs.wndMain:FindChild("AddMemberEditBox"))
	self.tWndRefs.wndMain:FindChild("AddMemberEditBox"):SetData(self.tWndRefs.wndMain:FindChild("AddMemberEditBox")) -- Since they have the same event handler
	self.tWndRefs.wndMain:FindChild("RosterHeaderContainer"):SetData(tRoster)

	self:HelperSelectRow(tSelectedRow)
end

function GuildRoster:CompareRoster(tRoster)
	if not self.tCurrentRoster then
		return tRoster
	end
	
	local tChangedMembers = {}
	
	for idx, tMemberData in pairs(tRoster) do
		if not self.tMemberMap[tMemberData.strName] then
			tChangedMembers[strName] = tMemberData
		end
		
		local tChangedInfo = {}
		local bChanged = false
		local nSortedIdx = self.tMemberMap[tMemberData.strName]
		local tCurrentMemberData = self.tCurrentRoster[tSortedIdx]
		
		if tMemberData.fLastOnline ~= tCurrentMemberData.fLastOnline then
			tChangedInfo.fLastOnline = tMemberData.fLastOnline
			bChanged = true
		end
		if tMemberData.nLevel ~= tCurrentMemberData.nLevel then
			tChangedInfo.nLevel = tMemberData.nLevel
			bChanged = true
		end
		if tMemberData.nRank ~= tCurrentMemberData.nRank then
			tChangedInfo.nRank = tMemberData.nRank
			bChanged = true
		end
		
		if bChanged then
			tChangedMembers[tMemberData.strName] = tChangedInfo
		end
	end

	return tChangedMembers
end

function GuildRoster:OnRosterGridItemClick(wndControl, wndHandler, iRow, iCol, eMouseButton)
	local wndGrid = self.tWndRefs.wndMain:FindChild("RosterGrid")
	local tRowData = wndGrid:GetCellData(iRow, 1)
	
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and tRowData and tRowData.strName and tRowData.strName ~= GameLib.GetPlayerUnit():GetName() then
		local unitTarget = nil
		local tOptionalCharacterData = { guildCurr = self.tWndRefs.wndMain:GetData(), tPlayerGuildData = tRowData }
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", self.tWndRefs.wndMain, tRowData.strName, unitTarget, tOptionalCharacterData)
		return
	end
	
	if wndGrid:GetData() == tRowData then
		tRowData = nil
	end
	
	self.strSelectedName = tRowData and tRowData.strName or nil
	self.nSelectedIndex = tRowData and tRowData.nRowIndex or 0
	wndGrid:SetData(tRowData)
	if tRowData then
		self:ResetRosterMemberButtons()
	else
		wndGrid:SetCurrentRow(self.nSelectedIndex)
	end
end

function GuildRoster:HelperSelectRow(tRowData)
	self.strSelectedName = tRowData and tRowData.strName or nil
	self.nSelectedIndex = tRowData and tRowData.nRowIndex or 0
	
	local wndGrid = self.tWndRefs.wndMain:FindChild("RosterGrid")
	wndGrid:SetData(tRowData)
	wndGrid:SetCurrentRow(self.nSelectedIndex)
	wndGrid:EnsureCellVisible(self.nSelectedIndex, 0)
	
	self:ResetRosterMemberButtons()
end

function GuildRoster:OnAddRankBtnSignal(wndControl, wndHandler)
	local wndEditRankPopout = self.tWndRefs.wndEditRankPopout
	local wndSettings = wndEditRankPopout:FindChild("RankSettingsEntry")
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local arRanks = guildCurr:GetRanks()

	local nFirstInactiveRank = nil
	for idx, tRankInfo in ipairs(arRanks) do
		if not tRankInfo.bValid then
			nFirstInactiveRank = { nRankId = idx, tRankInfo = tRankInfo, bNew = true }
			break
		end
	end

	if nFirstInactiveRank == nil then
		return
	end

	wndSettings:Show(true)
	wndSettings:SetData(nFirstInactiveRank)

	--Default to nothing
	wndSettings:FindChild("OptionString"):SetText("")
	local wndPermissionContainer = self.tWndRefs.wndPermissionContainer
	for key, wndPermission in pairs(wndPermissionContainer:GetChildren()) do
		wndPermission:FindChild("PermissionBtn"):SetCheck(false)
	end
	self:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
end

function GuildRoster:OnRemoveRankBtnSignal(wndHandler, wndControl)
	-- TODO REFACTOR OUT GETPARENT
	local wndParent = wndHandler:GetParent()
	local wndSettings = self.tWndRefs.wndEditRankPopout:FindChild("RankSettingsEntry")
	local tRank = wndParent:GetData()
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMyRankPermissions = guildCurr:GetRanks()[guildCurr:GetMyRank()]

	wndSettings:Show(true)
	wndSettings:SetData(tRank)
	wndSettings:FindChild("OptionString"):SetText(tRank.tRankInfo.strName)
	wndSettings:FindChild("RankPopoutOkBtn"):Enable(tMyRankPermissions.bChangeRankPermissions or tMyRankPermissions.bRankRename)
	wndSettings:FindChild("RankSettingsNameBlocker"):Show(not tMyRankPermissions.bRankRename)
	wndSettings:FindChild("PermissionContainerBlocker"):Show(tRank.nRankId == 1 or not tMyRankPermissions.bChangeRankPermissions)

	local wndPermissionContainer = self.tWndRefs.wndPermissionContainer
	for idx, wndPermission in pairs(wndPermissionContainer:GetChildren()) do
		wndPermission:FindChild("PermissionBtn"):SetCheck(tRank.tRankInfo[wndPermission:GetData().strLuaVariable])
	end

	local nRankMemberCount = 0
	local nRankMemberOnlineCount = 0
	for idx, tMemberInfo in ipairs(self.tRoster) do
		if tMemberInfo.nRank == tRank.nRankId then
			nRankMemberCount = nRankMemberCount + 1
			if tMemberInfo.fLastOnline == 0 then
				nRankMemberOnlineCount = nRankMemberOnlineCount + 1
			end
		end
	end

	local bCanDelete = tMyRankPermissions.bRankCreate and nRankMemberCount == 0
	wndSettings:FindChild("RankDeleteBtn"):Show(bCanDelete)
	wndSettings:FindChild("MemberCount"):Show(not bCanDelete)
	wndSettings:FindChild("MemberCount"):SetText(String_GetWeaselString(Apollo.GetString("Guild_RankDeleteMemberCount"), nRankMemberCount)) -- TODO localize member vs members

	self:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
end

function GuildRoster:OnRankSettingsSaveBtn(wndControl, wndHandler)
	-- TODO REFACTOR OUT GETPARENT
	local wndEditRankPopout = self.tWndRefs.wndEditRankPopout
	local wndSettings = wndEditRankPopout:FindChild("RankSettingsEntry")
	local bNew = wndControl:GetParent():GetData().bNew
	local tRankInfo = wndControl:GetParent():GetData().tRankInfo
	local nRankId = wndControl:GetParent():GetData().nRankId
	local guildCurr = self.tWndRefs.wndMain:GetData()

	wndEditRankPopout:FindChild("RankContainer"):Show(true)
	wndSettings:Show(false)

	local strName = wndSettings:FindChild("OptionString"):GetText()
	if strName ~= tRankInfo.strName then
		if bNew then
			guildCurr:AddRank(nRankId, strName)
		else
			guildCurr:RenameRank(nRankId, strName)
		end
		tRankInfo.strName = strName
	end

	local bDirtyRank = false
	for key, wndPermission in pairs(self.tWndRefs.wndPermissionContainer:GetChildren()) do
		local bPermissionChecked = wndPermission:FindChild("PermissionBtn"):IsChecked()
		if tRankInfo[wndPermission:GetData().strLuaVariable] ~= bPermissionChecked then
			bDirtyRank = true
		end

		tRankInfo[wndPermission:GetData().strLuaVariable] = wndPermission:FindChild("PermissionBtn"):IsChecked()
	end

	if bDirtyRank then
		guildCurr:ModifyRank(nRankId, tRankInfo)
	end

	-- TODO REFACTOR OUT GETPARENT
	wndControl:GetParent():SetData(tRankInfo)
	--TODO update list display name for rank name
end

function GuildRoster:OnRankSettingsDeleteBtn(wndControl, wndHandler)
	local guildCurr = self.tWndRefs.wndMain:GetData()
	guildCurr:RemoveRank(self.tWndRefs.wndEditRankPopout:FindChild("RankSettingsEntry"):GetData().nRankId)
	self.tWndRefs.wndEditRankPopout:FindChild("RankSettingsEntry"):Show(false)
end

function GuildRoster:OnRankSettingsNameChanging(wndControl, wndHandler, text)
	self:HelperValidateAndRefreshRankSettingsWindow()
end

function GuildRoster:OnRankSettingsPermissionBtn(wndControl, wndHandler)
	self:HelperValidateAndRefreshRankSettingsWindow()
end

function GuildRoster:HelperValidateAndRefreshRankSettingsWindow()
	local wndSettings = self.tWndRefs.wndEditRankPopout:FindChild("RankSettingsEntry")
	local wndLimit = wndSettings:FindChild("Limit")
	local tRankInfo = wndSettings:GetData()
	local bNew = tRankInfo.bNew
	local strName = wndSettings:FindChild("OptionString"):GetText()
	
	if wndLimit ~= nil then
		local nNameLength = GetUnicodeStringLength(strName or "")
		
		wndLimit:SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nNameLength, GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName)))
		
		if nNameLength < 1 or nNameLength > GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName) then
			wndLimit:SetTextColor(crGuildNameLengthError)
		else
			wndLimit:SetTextColor(crGuildNameLengthGood)
		end
	end
	
	local bNameValid = strName ~= nil and strName ~= "" and GameLib.IsTextValid(strName, GameLib.CodeEnumUserText.GuildRankName, GameLib.CodeEnumUserTextFilterClass.Strict)
	local bNameChanged = strName ~= tRankInfo.tRankInfo.strName

	local bPermissionChanged = false
	for key, wndPermission in pairs(wndSettings:FindChild("PermissionContainer"):GetChildren()) do
		local bPermissionChecked = wndPermission:FindChild("PermissionBtn"):IsChecked()
		if tRankInfo.tRankInfo[wndPermission:GetData().strLuaVariable] ~= bPermissionChecked then
			bPermissionChanged = true
			break
		end
	end
	
	--New ranks only require a valid name otherwise require the name to change (while still valid) or the permissions change
	wndSettings:FindChild("RankPopoutOkBtn"):Enable((bNew and bNameValid) or (not bNew and bNameValid and (bNameChanged or bPermissionChanged)))
	wndSettings:FindChild("ValidAlert"):Show(not bNameValid)
end

function GuildRoster:OnPlayerNoteChanged(wndControl, wndHandler, strNewNote)
	if wndControl ~= wndHandler then 
		return
	end
	local wndNote = self.tWndRefs.wndMain:FindChild("EditNotesContainer")
	local bValid = GameLib.IsTextValid(strNewNote or "", GameLib.CodeEnumUserText.GuildMemberNote, GameLib.CodeEnumUserTextFilterClass.Strict)
	
	wndNote:FindChild("EditNotesYesBtn"):Enable(bValid)
	wndNote:FindChild("StatusValidAlert"):Show(not bValid)
end

function GuildRoster:OnEditNoteBtn(wndControl, wndHandler)
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

function GuildRoster:OnRanksButtonSignal(wndControl, wndHandler)
	
	local wndRankPopout = self.tWndRefs.wndEditRankPopout
	local bShow = not wndRankPopout:IsShown()
	wndRankPopout:Show(bShow)
	self.tWndRefs.wndMain:FindChild("AdvancedOptionsContainer"):Show(false)

end

function GuildRoster:OnRankSettingsCloseBtn(wndControl, wndHandler)
	self.tWndRefs.wndEditRankPopout:FindChild("RankContainer"):Show(true)
	self.tWndRefs.wndEditRankPopout:FindChild("RankSettingsEntry"):Show(false)
end

function GuildRoster:OnGuildRankChange(guildCurr)
	if not self.tWndRefs.wndMain or guildCurr ~= self.tWndRefs.wndMain:GetData() then
		return
	end
	
	self:FullRedrawOfRoster(true)
end

function GuildRoster:OnRankPopoutCloseBtn(wndControl, wndHandler)
	self.tWndRefs.wndEditRankPopout:Show(false)
end

function GuildRoster:OnOfflineBtn(wndHandler, wndControl)
	self.bShowOffline = wndControl:IsChecked()
	
	self:FullRedrawOfRoster(true)
end

-----------------------------------------------------------------------------------------------
-- Bottom Panel Roster Actions
-----------------------------------------------------------------------------------------------

function GuildRoster:ResetRosterMemberButtons()
	-- Enable member options based on Permissions (note Code will also guard against this) -- TODO
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local eMyRank = guildCurr:GetMyRank()
	if guildCurr and eMyRank then
		local wndRosterGrid = self.tWndRefs.wndMain:FindChild("RosterGrid")
	
		local tMyRankPermissions = guildCurr:GetRanks()[eMyRank]
		local bSomeRowIsPicked = wndRosterGrid:GetCurrentRow()
		local bTargetIsUnderMyRank = bSomeRowIsPicked and eMyRank < wndRosterGrid:GetData().nRank

		self.tWndRefs.wndRosterOptionBtnRemove:Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)
		self.tWndRefs.wndRosterOptionBtnPromote:Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)
		self.tWndRefs.wndRosterOptionBtnDemote:Enable(bSomeRowIsPicked and bTargetIsUnderMyRank and wndRosterGrid:GetData().nRank ~= 10) -- Can't go below 10

		self.tWndRefs.wndRosterOptionBtnAdd:Show(tMyRankPermissions and tMyRankPermissions.bInvite)
		self.tWndRefs.wndRosterOptionBtnRemove:Show(tMyRankPermissions and tMyRankPermissions.bKick)
		self.tWndRefs.wndRosterOptionBtnDemote:Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)
		self.tWndRefs.wndRosterOptionBtnPromote:Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)

		if tMyRankPermissions.bDisband then
			self.tWndRefs.wndRosterOptionBtnLeaveFlyout:SetText(Apollo.GetString("GuildRoster_DisbandGuild"))
		else
			self.tWndRefs.wndRosterOptionBtnLeaveFlyout:SetText(Apollo.GetString("GuildRoster_LeaveGuild"))
		end
	else
		self.tWndRefs.wndRosterOptionBtnAdd:Show(false)
		self.tWndRefs.wndRosterOptionBtnRemove:Show(false)
		self.tWndRefs.wndRosterOptionBtnDemote:Show(false)
		self.tWndRefs.wndRosterOptionBtnPromote:Show(false)
		self.tWndRefs.wndRosterOptionBtnAdd:SetCheck(false)
		self.tWndRefs.wndRosterOptionBtnRemove:SetCheck(false)
		self.tWndRefs.wndRosterOptionBtnDemote:SetCheck(false)
		self.tWndRefs.wndRosterOptionBtnPromote:SetCheck(false)
		self.tWndRefs.wndRosterOptionBtnLeaveFlyout:SetCheck(false)
	end

	-- If it is just one button, arrange to the right instead
	if self.tWndRefs.wndRosterOptionBtnAdd:IsShown() or self.tWndRefs.wndRosterOptionBtnRemove:IsShown() then
		self.tWndRefs.wndRosterBottom:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	else
		self.tWndRefs.wndRosterBottom:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	end
end

function GuildRoster:OnRosterAddMemberClick(wndHandler, wndControl)
	self.tWndRefs.wndMain:FindChild("AddMemberEditBox"):SetFocus()
end

function GuildRoster:OnRosterRemoveMemberClick(wndHandler, wndControl)
	self.tWndRefs.wndMain:FindChild("RemoveMemberName"):SetText(self.tWndRefs.wndMain:FindChild("RosterGrid"):GetData().strName)
end

function GuildRoster:OnRosterPromoteMemberClick(wndHandler, wndControl) -- wndHandler is "RosterOptionBtnPromote"
	-- This one is different, it'll fire right away unless promoting to leader
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterGrid"):GetData()
	if tMember.nRank == 2 then
		self.tWndRefs.wndMain:FindChild("PromoteMemberContainer"):Show(true)
		self.tWndRefs.wndRosterOptionBtnPromote:SetCheck(true)
	else
		guildCurr:Promote(tMember.strName) -- TODO: More error checking
		self.tWndRefs.wndMain:FindChild("PromoteMemberContainer"):Show(false)
		self.tWndRefs.wndRosterOptionBtnPromote:SetCheck(false)
	end
end

function GuildRoster:OnRosterEditNoteSave(wndHandler, wndControl)
	wndHandler:SetFocus()
	self.tWndRefs.wndMain:FindChild("EditNotesContainer"):Close()

	local guildCurr = self.tWndRefs.wndMain:GetData()
	guildCurr:SetMemberNoteSelf(self.tWndRefs.wndMain:FindChild("EditNotesEditbox"):GetText())
end

-- Closing the Pop Up Bubbles
function GuildRoster:OnRosterAddMemberCloseBtn()
	self.tWndRefs.wndMain:FindChild("AddMemberEditBox"):SetText("")
	self.tWndRefs.wndMain:FindChild("AddMemberContainer"):Show(false)
end

function GuildRoster:OnRosterPromoteMemberCloseBtn()
	self.tWndRefs.wndMain:FindChild("PromoteMemberContainer"):Show(false)
	self.tWndRefs.wndRosterOptionBtnPromote:SetCheck(false) -- Since we aren't using AttachWindow
end

function GuildRoster:OnRosterRemoveMemberCloseBtn()
	self.tWndRefs.wndMain:FindChild("RemoveMemberContainer"):Show(false)
end

function GuildRoster:OnRosterLeaveCloseBtn()
	self.tWndRefs.wndMain:FindChild("LeaveFlyoutBtnContainer"):Show(false)
end

-- Saying Yes to the Pop Up Bubbles
function GuildRoster:OnAddMemberYesClick(wndHandler, wndControl) -- wndHandler is 'AddMemberEditBox' or 'AddMemberYesBtn', and its data is 'AddMemberEditBox'
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local wndEditBox = wndHandler:GetData()

	if wndEditBox and wndEditBox:GetData() and string.len(wndEditBox:GetText()) > 0 then -- TODO: Additional string validation
		guildCurr:Invite(wndEditBox:GetText())
	end
	self:OnRosterAddMemberCloseBtn()
end

function GuildRoster:OnRosterPromoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'PromoteMemberYesBtn'
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterGrid"):GetData()
	guildCurr:PromoteMaster(tMember.strName)
	self:OnRosterPromoteMemberCloseBtn()
end

function GuildRoster:OnRosterDemoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RosterOptionBtnDemote' data should be guildCurr
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterGrid"):GetData()
	guildCurr:Demote(tMember.strName)
	-- Note: Demote has no pop out
end

function GuildRoster:OnRosterRemoveMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RemoveMemberYesBtn'
	local guildCurr = self.tWndRefs.wndMain:GetData()
	local tMember = self.tWndRefs.wndMain:FindChild("RosterGrid"):GetData()
	guildCurr:Kick(tMember.strName)
	self:OnRosterRemoveMemberCloseBtn()
end

function GuildRoster:OnRosterLeaveYesClick(wndHandler, wndControl) -- wndHandler is "LeaveBtnYesBtn"
	local guildCurr = self.tWndRefs.wndMain:GetData()
	if guildCurr then
		if guildCurr:GetRanks()[guildCurr:GetMyRank()].bDisband then
			guildCurr:Disband()
		else
			guildCurr:Leave()
		end
		Event_FireGenericEvent("GenericEvent_ClearGuild")
	end
end

function GuildRoster:OnGuildMemberChange(guildCurr)
	if guildCurr and guildCurr:GetType() == GuildLib.GuildType_Guild then
		guildCurr:RequestMembers()
		self:FullRedrawOfRoster(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Roster Sorting
-----------------------------------------------------------------------------------------------

function GuildRoster:OnRosterSortToggle(wndHandler, wndControl)
	local strLastClicked = self.strRosterSort
	--inverse the sort order if they column was clicked on again.
	wndHandler:SetCheck(true)
	self.strRosterSort = wndHandler:GetName()
	self.bRosterSortAsc = self.strRosterSort and self.strRosterSort ~= strLastClicked and true or not self.bRosterSortAsc
	
	self:BuildRosterList(self.tWndRefs.wndMain:GetData(), self:SortRoster(self.tWndRefs.wndMain:FindChild("RosterHeaderContainer"):GetData()))
end

function GuildRoster:SortRoster(tResult)
	if not tResult then return end
	
	if self.tWndRefs.wndMain:FindChild("RosterSortBtnRank"):IsChecked() then
		table.sort(tResult, self.bRosterSortAsc and function(a,b) return (a.nRank > b.nRank or a.nRank == b.nRank and a.strName < b.strName) end or function(a,b) return (a.nRank < b.nRank or a.nRank == b.nRank and a.strName < b.strName) end)
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnLevel"):IsChecked() then
		table.sort(tResult, self.bRosterSortAsc and function(a,b) return (a.nLevel > b.nLevel or a.nLevel == b.nLevel and a.strName < b.strName) end or function(a,b) return (a.nLevel < b.nLevel or a.nLevel == b.nLevel and a.strName < b.strName) end) -- Level we want highest to lowest
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnClass"):IsChecked() then
		table.sort(tResult, self.bRosterSortAsc and function(a,b) return (a.strClass < b.strClass or a.strClass == b.strClass and a.strName < b.strName) end or function(a,b) return (a.strClass > b.strClass or a.strClass == b.strClass and a.strName < b.strName) end)
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnPath"):IsChecked() then
		table.sort(tResult, self.bRosterSortAsc and function(a,b) return (self:HelperConvertPathToString(a.ePathType) > self:HelperConvertPathToString(b.ePathType) or a.ePathType == b.ePathType and a.strName < b.strName) end or function(a,b) return (self:HelperConvertPathToString(a.ePathType) < self:HelperConvertPathToString(b.ePathType) or a.ePathType == b.ePathType and a.strName < b.strName) end) -- TODO: Potentially expensive?
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnOnline"):IsChecked() then
		table.sort(tResult, self.bRosterSortAsc and function(a,b) return (a.fLastOnline < b.fLastOnline or a.fLastOnline == b.fLastOnline and a.strName < b.strName) end or function(a,b) return (a.fLastOnline > b.fLastOnline or a.fLastOnline == b.fLastOnline and a.strName < b.strName) end)
	elseif self.tWndRefs.wndMain:FindChild("RosterSortBtnNote"):IsChecked() then
		table.sort(tResult, self.bRosterSortAsc and function(a,b) return (a.strNote < b.strNote or a.strNote == b.strNote and a.strName < b.strName) end or function(a,b) return (a.strNote > b.strNote or a.strNote == b.strNote and a.strName < b.strName) end)
	else
		table.sort(tResult, self.bRosterSortAsc and function(a,b) return (a.strName < b.strName) end or function(a,b) return (a.strName > b.strName) end)
	end

	return tResult
end

function GuildRoster:OnOptionsCloseClick(wndControl)
	wndControl:GetParent():Close()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GuildRoster:OnGenerateGridTooltip(wndHandler, wndControl, eType, iRow, iColumn)
	-- If the note column 7, draw a special tooltip
	wndHandler:SetTooltip(self.tWndRefs.wndMain:FindChild("RosterGrid"):GetCellData(iRow + 1, 8) or "") -- TODO: Remove this hardcoded
end

function GuildRoster:HelperConvertPathToString(ePath)
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

function GuildRoster:HelperConvertToTime(fDays)
	if fDays == 0 then
		return Apollo.GetString("ArenaRoster_Online")
	end

	if fDays == nil then
		return ""
	end

	local tTimeInfo = {["name"] = "", ["count"] = nil}

	if fDays >= 365 then -- Years
		tTimeInfo["name"] = Apollo.GetString("CRB_Year")
		tTimeInfo["count"] = math.floor(fDays / 365)
	elseif fDays >= 30 then -- Months
		tTimeInfo["name"] = Apollo.GetString("CRB_Month")
		tTimeInfo["count"] = math.floor(fDays / 30)
	elseif fDays >= 7 then
		tTimeInfo["name"] = Apollo.GetString("CRB_Week")
		tTimeInfo["count"] = math.floor(fDays / 7)
	elseif fDays >= 1 then -- Days
		tTimeInfo["name"] = Apollo.GetString("CRB_Day")
		tTimeInfo["count"] = math.floor(fDays)
	else
		local fHours = fDays * 24
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

local GuildRosterInst = GuildRoster:new()
GuildRosterInst:Init()