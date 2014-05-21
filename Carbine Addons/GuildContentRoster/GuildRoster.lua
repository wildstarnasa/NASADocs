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
local crGuildNameLengthError = ApolloColor.new("red")
local crGuildNameLengthGood = ApolloColor.new("ffffffff")

function GuildRoster:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GuildRoster:Init()
    Apollo.RegisterAddon(self)
end

function GuildRoster:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildRoster.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function GuildRoster:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
    Apollo.RegisterEventHandler("Guild_ToggleRoster",               "OnToggleRoster", self)
	Apollo.RegisterEventHandler("GuildWindowHasBeenClosed", 		"OnClose", self)
	
	Apollo.RegisterEventHandler("GuildRoster",                      "OnGuildRoster", self)
	Apollo.RegisterEventHandler("GuildMemberChange",                "OnGuildMemberChange", self)  -- General purpose update method
	Apollo.RegisterEventHandler("GuildRankChange",					"OnGuildRankChange", self)

	self.tRoster = nil
	self.strPlayerName = nil
	self.bViewingRemovedGuild = false
end

function GuildRoster:Initialize(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then
		return
	end
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildRosterForm", wndParent, self)
    self.wndEditRankPopout = self.wndMain:FindChild("EditRankPopout")
	self.wndMain:Show(true)

	self.wndMain:FindChild("RosterBottom"):ArrangeChildrenHorz(0)
	self.wndMain:FindChild("RosterOptionBtnAdd"):AttachWindow(self.wndMain:FindChild("AddMemberContainer"))
	self.wndMain:FindChild("RosterOptionBtnLeave"):AttachWindow(self.wndMain:FindChild("LeaveBtnContainer"))
	self.wndMain:FindChild("RosterOptionBtnRemove"):AttachWindow(self.wndMain:FindChild("RemoveMemberContainer"))
	self.wndMain:FindChild("RosterOptionBtnEditNotes"):AttachWindow(self.wndMain:FindChild("EditNotesContainer"))
	self.wndMain:FindChild("EditRanksButton"):AttachWindow(self.wndEditRankPopout)
	
	local wndPermissionContainer = self.wndMain:FindChild("PermissionContainer")
	for idx, tPermission in pairs(GuildLib.GetPermissions(GuildLib.GuildType_Guild)) do
		local wndPermission = Apollo.LoadForm(self.xmlDoc, "PermissionEntry", wndPermissionContainer, self)
		local wndPermissionBtn = wndPermission:FindChild("PermissionBtn")
		wndPermissionBtn:SetText("       " .. tPermission.strName) -- TODO REMOVE HARDCODE
		wndPermission:SetData(tPermission)
	end
	wndPermissionContainer:ArrangeChildrenVert()
	
	self.wndMain:SetData(guildOwner)
end

function GuildRoster:OnToggleRoster(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then
		return
	end
	
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize(wndParent)
	else
		self.wndMain:Show(true)
	end

	guildOwner:RequestMembers()
	self:FullRedrawOfRoster()
end

function GuildRoster:OnClose()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

-----------------------------------------------------------------------------------------------
-- Roster Methods
-----------------------------------------------------------------------------------------------

function GuildRoster:FullRedrawOfRoster()
	if self.wndMain == nil or not self.wndMain:IsValid() or not self.wndMain:GetData() then
		return
	end

	local guildCurr = self.wndMain:GetData()
	if guildCurr == nil then
		return
	end
	
	local eMyRank = guildCurr:GetMyRank()

	if self.wndMain and self.wndMain:FindChild("PromoteMemberContainer"):IsShown() then
		self:OnRosterPromoteMemberCloseBtn()
	end

	self:BuildRosterList(guildCurr, self:SortRoster(self.wndMain:FindChild("RosterHeaderContainer"):GetData(), "RosterSortBtnName"))
	
	self.wndEditRankPopout:FindChild("RankContainer"):DestroyChildren()
	
	local nCurrentRankCount = 1
	local arRanks = guildCurr:GetRanks()
	if arRanks == nil then
		return
	end
	
	for idx, tRankInfo in ipairs(arRanks) do
		if tRankInfo.bValid then
			local wndRank = Apollo.LoadForm(self.xmlDoc, "RankEntry", self.wndEditRankPopout:FindChild("RankContainer"), self)
			wndRank:SetData({ nRankId = idx, tRankInfo = tRankInfo, bNew = false })
			wndRank:FindChild("OptionString"):SetText(tRankInfo.strName)
			nCurrentRankCount = nCurrentRankCount + 1
		end
		
		if next(arRanks, idx) == nil and nCurrentRankCount < #arRanks and arRanks[eMyRank].bRankCreate then
			local wndRank = Apollo.LoadForm(self.xmlDoc, "AddRankEntry", self.wndEditRankPopout:FindChild("RankContainer"), self)
		end
	end

	self.wndEditRankPopout:FindChild("RankContainer"):ArrangeChildrenVert()
end

function GuildRoster:OnGuildRoster(guildCurr, tRoster) -- Event from CPP
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("RosterGrid"):DeleteAll()
		self:BuildRosterList(guildCurr, self:SortRoster(tRoster, "RosterSortBtnName")) -- "RosterSortBtnName" is the default sort method to use	
		self.tRoster = tRoster
	end
end

function GuildRoster:BuildRosterList(guildCurr, tRoster)
	if self.wndMain == nil or not self.wndMain:IsValid() or not self.wndMain:GetData() then
		return
	end
		
	if not guildCurr or tRoster == nil or #tRoster == 0 then
		return
	end

	local tRanks = guildCurr:GetRanks()
	if tRanks == nil then
		return --New guild and we have not yet recieved the data
	end
	
	local wndGrid = self.wndMain:FindChild("RosterGrid")
	wndGrid:DeleteAll() -- TODO remove this for better performance eventually

	for key, tCurr in pairs(tRoster) do
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

		if self.strPlayerName == tCurr.strName then
			self.wndMain:FindChild("EditNotesEditbox"):SetText(tCurr.strNote)
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
		wndGrid:SetCellDoc(iCurrRow, 8, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..tCurr.strNote.."</T>")
		wndGrid:SetCellLuaData(iCurrRow, 8, String_GetWeaselString(Apollo.GetString("GuildRoster_ActiveNoteTooltip"), tCurr.strName, string.len(tCurr.strNote) > 0 and tCurr.strNote or "N/A")) -- For tooltip
	end

	self.wndMain:FindChild("AddMemberYesBtn"):SetData(self.wndMain:FindChild("AddMemberEditBox"))
	self.wndMain:FindChild("AddMemberEditBox"):SetData(self.wndMain:FindChild("AddMemberEditBox")) -- Since they have the same event handler
	self.wndMain:FindChild("RosterHeaderContainer"):SetData(tRoster)

	self:ResetRosterMemberButtons()
end

function GuildRoster:OnRosterGridItemClick(wndControl, wndHandler, iRow, iCol, eMouseButton)
	local wndData = self.wndMain:FindChild("RosterGrid"):GetCellData(iRow, 1)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndData and wndData.strName and wndData.strName ~= GameLib.GetPlayerUnit():GetName() then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", self.wndMain, wndData.strName)
		return
	end

	if self.wndMain:FindChild("RosterGrid"):GetData() == wndData then
		self.wndMain:FindChild("RosterGrid"):SetData(nil)
		self.wndMain:FindChild("RosterGrid"):SetCurrentRow(0) -- Deselect grid
	else
		self.wndMain:FindChild("RosterGrid"):SetData(wndData)
	end
	
	self:ResetRosterMemberButtons()
end

function GuildRoster:OnAddRankBtnSignal(wndControl, wndHandler)
	local wndEditRankPopout = self.wndEditRankPopout
	local wndSettings = wndEditRankPopout:FindChild("RankSettingsEntry")
	local guildCurr = self.wndMain:GetData()
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
	local wndPermissionContainer = self.wndMain:FindChild("PermissionContainer")
	for key, wndPermission in pairs(wndPermissionContainer:GetChildren()) do
		wndPermission:FindChild("PermissionBtn"):SetCheck(false)
	end

	self:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
end

function GuildRoster:OnRemoveRankBtnSignal(wndHandler, wndControl)
	-- TODO REFACTOR OUT GETPARENT
	local wndParent = wndHandler:GetParent()
	local wndSettings = self.wndEditRankPopout:FindChild("RankSettingsEntry")
	local tRank = wndParent:GetData()
	local guildCurr = self.wndMain:GetData()
	local tMyRankPermissions = guildCurr:GetRanks()[guildCurr:GetMyRank()]

	wndSettings:Show(true)
	wndSettings:SetData(tRank)
	wndSettings:FindChild("OptionString"):SetText(tRank.tRankInfo.strName)
	wndSettings:FindChild("RankPopoutOkBtn"):Enable(tMyRankPermissions.bChangeRankPermissions or tMyRankPermissions.bRankRename)
	wndSettings:FindChild("RankSettingsNameBlocker"):Show(not tMyRankPermissions.bRankRename)
	wndSettings:FindChild("PermissionContainerBlocker"):Show(not tMyRankPermissions.bChangeRankPermissions)

	local wndPermissionContainer = self.wndMain:FindChild("PermissionContainer")
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
	local wndEditRankPopout = self.wndEditRankPopout
	local wndSettings = wndEditRankPopout:FindChild("RankSettingsEntry")
	local bNew = wndControl:GetParent():GetData().bNew
	local tRankInfo = wndControl:GetParent():GetData().tRankInfo
	local nRankId = wndControl:GetParent():GetData().nRankId
	local guildCurr = self.wndMain:GetData()

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
	for key, wndPermission in pairs(self.wndMain:FindChild("PermissionContainer"):GetChildren()) do
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
	local guildCurr = self.wndMain:GetData()
	guildCurr:RemoveRank(self.wndEditRankPopout:FindChild("RankSettingsEntry"):GetData().nRankId)
	self.wndEditRankPopout:FindChild("RankSettingsEntry"):Show(false)
end

function GuildRoster:OnRankSettingsNameChanging(wndControl, wndHandler, text)
	self:HelperValidateAndRefreshRankSettingsWindow()
end

function GuildRoster:OnRankSettingsPermissionBtn(wndControl, wndHandler)
	self:HelperValidateAndRefreshRankSettingsWindow()
end

function GuildRoster:HelperValidateAndRefreshRankSettingsWindow()
	local wndSettings = self.wndEditRankPopout:FindChild("RankSettingsEntry")
	local wndLimit = wndSettings:FindChild("Limit")
	local tRankInfo = wndSettings:GetData()
	local bNew = tRankInfo.bNew
	local strName = wndSettings:FindChild("OptionString"):GetText()
	
	if wndLimit ~= nil then
		local nNameLength = string.len(strName or "")
		
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
end

function GuildRoster:OnRankSettingsCloseBtn(wndControl, wndHandler)
	self.wndEditRankPopout:FindChild("RankContainer"):Show(true)
	self.wndEditRankPopout:FindChild("RankSettingsEntry"):Show(false)
end

function GuildRoster:OnGuildRankChange(guildCurr)
	if not self.wndMain or guildCurr ~= self.wndMain:GetData() then
		return
	end
	self:FullRedrawOfRoster()
end

function GuildRoster:OnRankPopoutCloseBtn(wndControl, wndHandler)
	self.wndEditRankPopout:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Bottom Panel Roster Actions
-----------------------------------------------------------------------------------------------

function GuildRoster:ResetRosterMemberButtons()
	-- Defaults
	self.wndMain:FindChild("RosterOptionBtnAdd"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnRemove"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnDemote"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnPromote"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnAdd"):SetCheck(false)
	self.wndMain:FindChild("RosterOptionBtnRemove"):SetCheck(false)
	self.wndMain:FindChild("RosterOptionBtnDemote"):SetCheck(false)
	self.wndMain:FindChild("RosterOptionBtnPromote"):SetCheck(false)
	self.wndMain:FindChild("RosterOptionBtnLeave"):SetCheck(false)

	-- Enable member options based on Permissions (note Code will also guard against this) -- TODO
	local guildCurr = self.wndMain:GetData()
	local eMyRank = guildCurr:GetMyRank()
	if guildCurr and eMyRank then
		local tMyRankPermissions = guildCurr:GetRanks()[eMyRank]
		local bSomeRowIsPicked = self.wndMain:FindChild("RosterGrid"):GetCurrentRow()
		local bTargetIsUnderMyRank = bSomeRowIsPicked and eMyRank < self.wndMain:FindChild("RosterGrid"):GetData().nRank

		self.wndMain:FindChild("RosterOptionBtnRemove"):Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)
		self.wndMain:FindChild("RosterOptionBtnPromote"):Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)
		self.wndMain:FindChild("RosterOptionBtnDemote"):Enable(bSomeRowIsPicked and bTargetIsUnderMyRank and self.wndMain:FindChild("RosterGrid"):GetData().nRank ~= 10) -- Can't go below 10

		self.wndMain:FindChild("RosterOptionBtnAdd"):Show(tMyRankPermissions and tMyRankPermissions.bInvite)
		self.wndMain:FindChild("RosterOptionBtnRemove"):Show(tMyRankPermissions and tMyRankPermissions.bKick)
		self.wndMain:FindChild("RosterOptionBtnDemote"):Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)
		self.wndMain:FindChild("RosterOptionBtnPromote"):Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)

		if tMyRankPermissions.bDisband then
			self.wndMain:FindChild("RosterOptionBtnLeave"):SetText(Apollo.GetString("Circles_Disband"))
		else
			self.wndMain:FindChild("RosterOptionBtnLeave"):SetText(Apollo.GetString("Circles_Leave"))
		end
	end

	-- If it is just one button, arrange to the right instead
	if self.wndMain:FindChild("RosterOptionBtnAdd"):IsShown() or self.wndMain:FindChild("RosterOptionBtnRemove"):IsShown() then
		self.wndMain:FindChild("RosterBottom"):ArrangeChildrenHorz(0)
	else
		self.wndMain:FindChild("RosterBottom"):ArrangeChildrenHorz(0)
	end
end

function GuildRoster:OnRosterAddMemberClick(wndHandler, wndControl)
	self.wndMain:FindChild("AddMemberEditBox"):SetFocus()
end

function GuildRoster:OnRosterRemoveMemberClick(wndHandler, wndControl)
	self.wndMain:FindChild("RemoveMemberLabel"):SetText(String_GetWeaselString(Apollo.GetString("Circles_KickConfirmation"), self.wndMain:FindChild("RosterGrid"):GetData().strName))
end

function GuildRoster:OnRosterPromoteMemberClick(wndHandler, wndControl) -- wndHandler is "RosterOptionBtnPromote"
	-- This one is different, it'll fire right away unless promoting to leader
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterGrid"):GetData()
	if tMember.nRank == 2 then
		self.wndMain:FindChild("PromoteMemberContainer"):Show(true)
		self.wndMain:FindChild("RosterOptionBtnPromote"):SetCheck(true)
	else
		guildCurr:Promote(tMember.strName) -- TODO: More error checking
		self.wndMain:FindChild("PromoteMemberContainer"):Show(false)
		self.wndMain:FindChild("RosterOptionBtnPromote"):SetCheck(false)
	end
end

function GuildRoster:OnRosterEditNoteSave(wndHandler, wndControl)
	wndHandler:SetFocus()
	self:OnRosterEditNotesCloseBtn()

	local guildCurr = self.wndMain:GetData()
	guildCurr:SetMemberNoteSelf(self.wndMain:FindChild("EditNotesEditbox"):GetText())
end

-- Closing the Pop Up Bubbles
function GuildRoster:OnRosterAddMemberCloseBtn()
	self.wndMain:FindChild("AddMemberEditBox"):SetText("")
	self.wndMain:FindChild("AddMemberContainer"):Show(false)
end

function GuildRoster:OnRosterPromoteMemberCloseBtn()
	self.wndMain:FindChild("PromoteMemberContainer"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnPromote"):SetCheck(false) -- Since we aren't using AttachWindow
end

function GuildRoster:OnRosterRemoveMemberCloseBtn()
	self.wndMain:FindChild("RemoveMemberContainer"):Show(false)
end

function GuildRoster:OnRosterLeaveCloseBtn()
	self.wndMain:FindChild("LeaveBtnContainer"):Show(false)
end

function GuildRoster:OnRosterEditNotesCloseBtn()
	self.wndMain:FindChild("EditNotesContainer"):Show(false)
end

-- Saying Yes to the Pop Up Bubbles
function GuildRoster:OnAddMemberYesClick(wndHandler, wndControl) -- wndHandler is 'AddMemberEditBox' or 'AddMemberYesBtn', and its data is 'AddMemberEditBox'
	local guildCurr = self.wndMain:GetData()
	local wndEditBox = wndHandler:GetData()

	if wndEditBox and wndEditBox:GetData() and string.len(wndEditBox:GetText()) > 0 then -- TODO: Additional string validation
		guildCurr:Invite(wndEditBox:GetText())
	end
	self:OnRosterAddMemberCloseBtn()
end

function GuildRoster:OnRosterPromoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'PromoteMemberYesBtn'
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterGrid"):GetData()
	guildCurr:PromoteMaster(tMember.strName)
	self:OnRosterPromoteMemberCloseBtn()
end

function GuildRoster:OnRosterDemoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RosterOptionBtnDemote' data should be guildCurr
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterGrid"):GetData()
	guildCurr:Demote(tMember.strName)
	-- Note: Demote has no pop out
end

function GuildRoster:OnRosterRemoveMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RemoveMemberYesBtn'
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterGrid"):GetData()
	guildCurr:Kick(tMember.strName)
	self:OnRosterRemoveMemberCloseBtn()
end

function GuildRoster:OnRosterLeaveYesClick(wndHandler, wndControl) -- wndHandler is "LeaveBtnYesBtn"
	local guildCurr = self.wndMain:GetData()
	if guildCurr then
		if guildCurr:GetRanks()[guildCurr:GetMyRank()].bDisband then
			guildCurr:Disband()
		else
			guildCurr:Leave()
		end
		Event_FireGenericEvent("GenericEvent_ClearGuild")
	end
end

function GuildRoster:OnGuildMemberChange( guildCurr )
	if guildCurr and guildCurr:GetType() == GuildLib.GuildType_Guild then
		guildCurr:RequestMembers()
		self:FullRedrawOfRoster()
	end
end

-----------------------------------------------------------------------------------------------
-- Roster Sorting
-----------------------------------------------------------------------------------------------

function GuildRoster:OnRosterSortToggle(wndHandler, wndControl)
	self:BuildRosterList(self.wndMain:GetData(), self:SortRoster(self.wndMain:FindChild("RosterHeaderContainer"):GetData(), wndHandler:GetName()))
end

function GuildRoster:SortRoster(tArg, strLastClicked)
	-- TODO: Two tiers of sorting. E.g. Clicking Name then Path will give Paths sorted first, then Names sorted second
	if not tArg then return end
	local tResult = tArg

	if self.wndMain:FindChild("RosterSortBtnName"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.strName > b.strName) end)
	elseif self.wndMain:FindChild("RosterSortBtnRank"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.nRank > b.nRank) end)
	elseif self.wndMain:FindChild("RosterSortBtnLevel"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.nLevel < b.nLevel) end) -- Level we want highest to lowest
	elseif self.wndMain:FindChild("RosterSortBtnClass"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.strClass > b.strClass) end)
	elseif self.wndMain:FindChild("RosterSortBtnPath"):IsChecked() then
		table.sort(tResult, function(a,b) return (self:HelperConvertPathToString(a.ePathType) > self:HelperConvertPathToString(b.ePathType)) end) -- TODO: Potentially expensive?
	elseif self.wndMain:FindChild("RosterSortBtnOnline"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.fLastOnline < b.fLastOnline) end)
	elseif self.wndMain:FindChild("RosterSortBtnNote"):IsChecked() then
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

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GuildRoster:OnGenerateGridTooltip(wndHandler, wndControl, eType, iRow, iColumn)
	-- If the note column 7, draw a special tooltip
	wndHandler:SetTooltip(self.wndMain:FindChild("RosterGrid"):GetCellData(iRow + 1, 8) or "") -- TODO: Remove this hardcoded
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