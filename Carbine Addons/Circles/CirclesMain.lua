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
local crGuildNameLengthError = ApolloColor.new("red")
local crGuildNameLengthGood = ApolloColor.new("ffffffff")

function Circles:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function Circles:Init()
    Apollo.RegisterAddon(self)
end

function Circles:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CirclesMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	Apollo.RegisterEventHandler("InterfaceOptionsLoaded", "OnDocumentReady", self)
end

function Circles:OnDocumentReady()
	if  self.xmlDoc == nil or not g_InterfaceOptionsLoaded then
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

	Apollo.RegisterTimerHandler("CircleAlertDisplayTimer", "OnCircleAlertDisplayTimer", self)
	Apollo.RegisterTimerHandler("OfflineTimeUpdate", "OnOfflineTimeUpdate", self)
	
	Apollo.CreateTimer("OfflineTimeUpdate", 30.000, true)
	Apollo.StopTimer("OfflineTimeUpdate")
	
	Apollo.CreateTimer("CircleAlertDisplayTimer", 3.0, false)
	Apollo.StopTimer("CircleAlertDisplayTimer")
end

function Circles:OnGenericEvent_InitializeCircles(wndParent, guildCurr)
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "CirclesMainForm", wndParent, self)
	end

	local wndRosterScreen = self.wndMain:FindChild("RosterScreen")
	local wndRosterBottom = wndRosterScreen:FindChild("RosterBottom")
	wndRosterBottom:ArrangeChildrenHorz(2)
	wndRosterBottom:FindChild("RosterOptionBtnAdd"):AttachWindow(wndRosterBottom:FindChild("RosterOptionBtnAdd:AddMemberContainer"))
	wndRosterBottom:FindChild("RosterOptionBtnLeave"):AttachWindow(wndRosterBottom:FindChild("RosterOptionBtnLeave:LeaveBtnContainer"))
	wndRosterBottom:FindChild("RosterOptionBtnRemove"):AttachWindow(wndRosterBottom:FindChild("RosterOptionBtnRemove:RemoveMemberContainer"))
	--self.wndMain:FindChild("RosterOptionBtnPromote"):AttachWindow(self.wndMain:FindChild("PromoteMemberContainer")) -- No Attach Window, we're doing this one manually
	--wndRosterBottom:FindChild("RosterOptionBtnViewAlts"):AttachWindow(wndRosterScreen:FindChild("RosterPopout"))
	
	self.bViewingRemovedGuild = false

	local wndPermissionContainer = wndRosterScreen:FindChild("RankPopout:RankSettingsEntry:Permissions:PermissionContainer")
	for idx, tPermission in pairs(GuildLib.GetPermissions(GuildLib.GuildType_Circle)) do
		local wndPermission = Apollo.LoadForm(self.xmlDoc, "PermissionEntry", wndPermissionContainer, self)
		local wndPermissionBtn = wndPermission:FindChild("PermissionBtn")
		wndPermissionBtn:SetText("       " .. tPermission.strName)

		wndPermission:SetData(tPermission)
	end
	wndPermissionContainer:ArrangeChildrenVert()

	self.wndRankPopout = wndRosterScreen:FindChild("RankPopout")

	Apollo.StartTimer("OfflineTimeUpdate")
	self.wndMain:SetData(guildCurr)
	self.wndMain:Show(true)
	self:FullRedrawOfRoster()
end

function Circles:OnGenericEvent_DestroyCircles()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end
end

function Circles:OnClose()
	Apollo.StopTimer("CircleAlertDisplayTimer")
	Apollo.StopTimer("OfflineTimeUpdate")
	self.wndMain:FindChild("AlertMessage"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Roster Methods
-----------------------------------------------------------------------------------------------

function Circles:FullRedrawOfRoster()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
		return
	end

	local guildCurr = self.wndMain:GetData()
	local eMyRank = guildCurr:GetMyRank()
	local wndRosterScreen = self.wndMain:FindChild("RosterScreen")

	wndRosterScreen:Show(true)

	if wndRosterScreen and wndRosterScreen:FindChild("RosterBottom:RosterOptionBtnPromote:PromoteMemberContainer"):IsShown() then
		self:OnRosterPromoteMemberCloseBtn()
	end

	self.wndMain:FindChild("CircleRegistrationWnd"):Show(false)
	self.wndMain:FindChild("BGFrame:HeaderTitleText"):SetText(guildCurr:GetName())
	--if guildCurr:GetType() == GuildLib.GuildType_Guild then
	--	self.wndMain:FindChild("HeaderTitleText"):SetText(guildCurr:GetName().." ("..guildCurr:GetInfluence().." Influence)")
	--end

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
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
		return
	end
	
	if guildCurr == self.wndMain:GetData() then -- Since Circles and Guild can be up at the same time
		self.wndMain:FindChild("RosterScreen:RosterGrid"):DeleteAll()
		self:BuildRosterList(guildCurr, self:SortRoster(tRoster, "RosterSortBtnName")) -- "RosterSortBtnName" is the default sort method to use
	end

	self.tRoster = tRoster
end

function Circles:BuildRosterList(guildCurr, tRoster)
	if not guildCurr or #tRoster == 0 then
		return
	end

	local tRanks = guildCurr:GetRanks()
	local wndGrid = self.wndMain:FindChild("RosterScreen:RosterGrid")
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
		end

		local strTextColor = "UI_TextHoloBodyHighlight"
		if tCurr.fLastOnline ~= 0 then -- offline
			strTextColor = "UI_BtnTextGrayNormal"
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
	end
	local wndAddContainer = self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnAdd:AddMemberContainer")
	local wndAddMemberEditBox = wndAddContainer:FindChild("AddMemberEditBox")
	wndAddContainer:FindChild("AddMemberYesBtn"):SetData(wndAddMemberEditBox)
	wndAddMemberEditBox:SetData(wndAddMemberEditBox) -- Since they have the same event handler
	self.wndMain:FindChild("RosterScreen:RosterHeaderContainer"):SetData(tRoster)

	self:ResetRosterMemberButtons()
end

function Circles:OnRosterGridItemClick(wndControl, wndHandler, iRow, iCol, eMouseButton)
	local wndRosterGrid = self.wndMain:FindChild("RosterScreen:RosterGrid")
	local wndData = wndRosterGrid:GetCellData(iRow, 1)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndData and wndData.strName and wndData.strName ~= GameLib.GetPlayerUnit():GetName() then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", self.wndMain, wndData.strName)
		return
	end

	if wndRosterGrid:GetData() == wndData then
		self.wndMain:FindChild("RosterScreen:RosterPopout"):Show(false)
		wndRosterGrid:SetData(nil)
		wndRosterGrid:SetCurrentRow(0) -- Deselect grid
	else
		wndRosterGrid:SetData(wndData)
	end

	if self.wndMain:FindChild("RosterScreen:RosterPopout"):IsShown() then
		self:DrawRosterPopout()
	else
		self:ResetRosterMemberButtons()
	end
end

-----------------------------------------------------------------------------------------------
-- Rank Methods
-----------------------------------------------------------------------------------------------

function Circles:OnRanksButtonSignal()
	local wndRankPopout = self.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndRankSettings = wndRankPopout:FindChild("RankSettingsEntry")

	local bShow = not wndRankPopout:IsShown()

	wndRankPopout:Show(bShow)
	wndRankContainer:Show(bShow)
	wndRankSettings:Show(false)
end

function Circles:OnAddRankBtnSignal(wndControl, wndHandler)
	local wndRankPopout = self.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")
	local guildCurr = self.wndMain:GetData()
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
	local wndPermissionContainer = self.wndMain:FindChild("RosterScreen:RankPopout:RankSettingsEntry:Permissions:PermissionContainer")
	for key, wndPermission in pairs(wndPermissionContainer:GetChildren()) do
		wndPermission:FindChild("PermissionBtn"):SetCheck(false)
	end

	self:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
end

function Circles:OnRemoveRankBtnSignal(wndControl, wndHandler)
	local wndRankContainer = self.wndRankPopout:FindChild("RankContainer")
	local wndSettings = self.wndRankPopout:FindChild("RankSettingsEntry")
	local wndSettings = self.wndRankPopout:FindChild("RankSettingsEntry")
	local nRankIdx = wndControl:GetParent():GetData().nRankIdx
	local tRank = wndControl:GetParent():GetData().tRankData
	local guildCurr = self.wndMain:GetData()
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

	wndSettings:FindChild("Delete"):Show(bCanDelete)
	wndSettings:FindChild("MemberCount"):Show(not bCanDelete)
	wndSettings:FindChild("MemberCount"):SetText(String_GetWeaselString(Apollo.GetString("Guild_MemberCount"), nRankMemberCount, nRankMemberOnlineCount))

	self:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
end

function Circles:OnRankSettingsSaveBtn(wndControl, wndHandler)
	local wndRankPopout = self.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")
	local bNew = wndControl:GetParent():GetData().bNew
	local tRank = wndControl:GetParent():GetData().tRankData
	local nRankIdx = wndControl:GetParent():GetData().nRankIdx
	local guildCurr = self.wndMain:GetData()

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
	local wndRankPopout = self.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")

	local nRankIdx = wndSettings:GetData().nRankIdx
	local guildCurr = self.wndMain:GetData()

	guildCurr:RemoveRank(nRankIdx)

	wndRankContainer:Show(true)
	wndSettings:Show(false)
end

function Circles:OnRankSettingsNameChanging(wndControl, wndHandler, strText)
	self:HelperValidateAndRefreshRankSettingsWindow(self.wndRankPopout:FindChild("RankSettingsEntry"))
end

function Circles:OnRankSettingsPermissionBtn(wndControl, wndHandler)
	self:HelperValidateAndRefreshRankSettingsWindow(self.wndRankPopout:FindChild("RankSettingsEntry"))
end

function Circles:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
	local wndLimit = wndSettings:FindChild("Name:Limit")
	local tRank = wndSettings:GetData()
	local strName = wndSettings:FindChild("Name:OptionString"):GetText()

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
end

function Circles:OnRankSettingsCloseBtn(wndControl, wndHandler)
	local wndRankPopout = self.wndMain:FindChild("RosterScreen:RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")

	wndRankPopout:FindChild("RankContainer"):Show(true)
	wndSettings:Show(false)
end

function Circles:OnGuildRankChange(guildCurr)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	if guildCurr ~= self.wndMain:GetData() then
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

function Circles:ResetRosterMemberButtons()
	-- Defaults
	local wndRosterBottom = self.wndMain:FindChild("RosterScreen:RosterBottom")
	local wndAddBtn = wndRosterBottom:FindChild("RosterOptionBtnAdd")
	local wndRemoveBtn = wndRosterBottom:FindChild("RosterOptionBtnRemove")
	local wndDemoteBtn = wndRosterBottom:FindChild("RosterOptionBtnDemote")
	local wndPromoteBtn = wndRosterBottom:FindChild("RosterOptionBtnPromote")
	local wndLeaveBtn = wndRosterBottom:FindChild("RosterOptionBtnLeave")

	wndAddBtn:Show(false)
	wndRemoveBtn:Show(false)
	wndDemoteBtn:Show(false)
	wndPromoteBtn:Show(false)
	wndAddBtn:SetCheck(false)
	wndRemoveBtn:SetCheck(false)
	wndDemoteBtn:SetCheck(false)
	wndPromoteBtn:SetCheck(false)
	wndLeaveBtn:SetCheck(false)

	-- Enable member options based on Permissions (note Code will also guard against this) -- TODO
	local guildCurr = self.wndMain:GetData()
	local eMyRank = guildCurr:GetMyRank()

	if guildCurr and eMyRank then
		local wndRosterGrid = self.wndMain:FindChild("RosterScreen:RosterGrid")
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
			wndLeaveBtn:SetText(Apollo.GetString("Circles_Disband"))
		else
			wndLeaveBtn:SetText(Apollo.GetString("Circles_Leave"))
		end
	end

	-- If it is just one button, arrange to the right instead
	if wndAddBtn:IsShown() or wndRemoveBtn:IsShown() then
		wndRosterBottom:ArrangeChildrenHorz(2)
	else
		wndRosterBottom:ArrangeChildrenHorz(2)
	end
end

-----------------------------------------------------------------------------------------------
-- Member permissions updating buttons
-----------------------------------------------------------------------------------------------

function Circles:OnRosterAddMemberClick(wndHandler, wndControl)
	self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnAdd:AddMemberContainer:AddMemberEditBox"):SetFocus()
end

function Circles:OnRosterRemoveMemberClick(wndHandler, wndControl)
	self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnRemove:RemoveMemberContainer:RemoveMemberLabel"):SetText(String_GetWeaselString(Apollo.GetString("Circles_KickConfirmation"), self.wndMain:FindChild("RosterScreen:RosterGrid"):GetData().strName))
end

function Circles:OnRosterPromoteMemberClick(wndHandler, wndControl) -- wndHandler is "RosterOptionBtnPromote"
	-- This one is different, it'll fire right away unless promoting to leader
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()
	local wndPromoteBtn = self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnPromote")
	if tMember.nRank == 2 then
		wndPromoteBtn:FindChild("PromoteMemberContainer"):Show(true)
		wndPromoteBtn:SetCheck(true)
	else
		guildCurr:Promote(tMember.strName) -- TODO: More error checking
		wndPromoteBtn:FindChild("PromoteMemberContainer"):Show(false)
		wndPromoteBtn:SetCheck(false)
	end
end

-- Closing the Pop Up Bubbles
function Circles:OnRosterAddMemberCloseBtn()
	local wndAddMemberContainer = self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnAdd:AddMemberContainer")
	wndAddMemberContainer:FindChild("AddMemberEditBox"):SetText("")
	wndAddMemberContainer:Show(false)
end

function Circles:OnRosterPromoteMemberCloseBtn()
	local wndPromoteBtn = self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnPromote")
	wndPromoteBtn:FindChild("PromoteMemberContainer"):Show(false)
	wndPromoteBtn:SetCheck(false) -- Since we aren't using AttachWindow
end

function Circles:OnRosterRemoveMemberCloseBtn()
	self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnRemove:RemoveMemberContainer"):Show(false)
end

function Circles:OnRosterLeaveCloseBtn()
	self.wndMain:FindChild("RosterScreen:RosterBottom:RosterOptionBtnLeave:LeaveBtnContainer"):Show(false)
end

-- Saying Yes to the Pop Up Bubbles
function Circles:OnAddMemberYesClick(wndHandler, wndControl) -- wndHandler is 'AddMemberEditBox' or 'AddMemberYesBtn', and its data is 'AddMemberEditBox'
	local guildCurr = self.wndMain:GetData()
	local wndEditBox = wndHandler:GetData()

	if wndEditBox and wndEditBox:GetData() and string.len(wndEditBox:GetText()) > 0 then -- TODO: Additional string validation
		guildCurr:Invite(wndEditBox:GetText())
	end
	self:OnRosterAddMemberCloseBtn()
end

function Circles:OnRosterPromoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'PromoteMemberYesBtn'
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()

	guildCurr:PromoteMaster(tMember.strName)
	self:OnRosterPromoteMemberCloseBtn()
end

function Circles:OnRosterDemoteMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RosterOptionBtnDemote' data should be guildCurr
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()
	guildCurr:Demote(tMember.strName)
	-- Note: Demote has no pop out
end

function Circles:OnRosterRemoveMemberYesClick(wndHandler, wndControl) -- wndHandler is 'RemoveMemberYesBtn'
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterScreen:RosterGrid"):GetData()
	guildCurr:Kick(tMember.strName)
	self:OnRosterRemoveMemberCloseBtn()
end

function Circles:OnRosterLeaveYesClick(wndHandler, wndControl) -- wndHandler is "LeaveBtnYesBtn"
	local guildCurr = self.wndMain:GetData()
	if guildCurr and guildCurr:GetMyRank() == 1 then
		guildCurr:Disband()
	elseif guildCurr then
		guildCurr:Leave()
	end
	wndHandler:GetParent():Close()
	self.wndMain:Close()
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
if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
	return
end
	local tRoster = self.wndMain:GetData():RequestMembers()
	local wndGrid = self.wndMain:FindChild("RosterScreen:RosterGrid")

	if tRoster then
		for key, tCurr in pairs(tRoster) do
			local strTextColor = "ffffffff"
			if tCurr.fLastOnline ~= 0 then -- offline
				strTextColor = "9d9d9d9d"
			end

			wndGrid:SetCellDoc(key, 7, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..self:HelperConvertToTime(tCurr.fLastOnline).."</T>")
		end
	end
end

-----------------------------------------------------------------------------------------------
-- OnGuildResult
-----------------------------------------------------------------------------------------------

function Circles:OnGuildResult(guildCurr, strName, nRank, eResult)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		return
	end
	-- Reload UI when a circle is made
	if guildCurr and guildCurr:GetType() == GuildLib.GuildType_Circle then
		local guildViewed = self.wndMain:GetData()
		self.bViewingRemovedGuild = false -- is the affected guild shown?

		if guildViewed ~= nil and self.wndMain:IsShown() and self.wndMain:FindChild("RosterScreen"):IsShown() and guildViewed:GetName() == strName then
			self.bViewingRemovedGuild = true -- we need to redraw in these instances
		end

		-- if you've been kicked, left, or disbanded a circle and you're viewing it
		if eResult == GuildLib.GuildResult_KickedYou and self.wndMain:IsShown() then
			self.wndMain:FindChild("AlertMessage"):FindChild("MessageAlertText"):SetText(Apollo.GetString("Circles_Ouch"))
			self.wndMain:FindChild("AlertMessage"):FindChild("MessageBodyText"):SetText(String_GetWeaselString(Apollo.GetString("Circles_Kicked"), strName))
			self.wndMain:FindChild("AlertMessage"):Invoke()
			Apollo.StartTimer("CircleAlertDisplayTimer")
		elseif eResult == GuildLib.GuildResult_YouQuit and self.wndMain:IsShown() then
			self.wndMain:FindChild("AlertMessage"):FindChild("MessageAlertText"):SetText(Apollo.GetString("Circles_Bye"))
			self.wndMain:FindChild("AlertMessage"):FindChild("MessageBodyText"):SetText(String_GetWeaselString(Apollo.GetString("Circles_LeftCircle"), strName))
			self.wndMain:FindChild("AlertMessage"):Invoke()
			Apollo.StartTimer("CircleAlertDisplayTimer")
		elseif eResult == GuildLib.GuildResult_GuildDisbanded and self.wndMain:IsShown() then
			self.wndMain:FindChild("AlertMessage"):FindChild("MessageAlertText"):SetText(Apollo.GetString("Circles_CircleDisbanded"))
			self.wndMain:FindChild("AlertMessage"):FindChild("MessageBodyText"):SetText(String_GetWeaselString(Apollo.GetString("Circles_YouDisbanded"), strName))
			self.wndMain:FindChild("AlertMessage"):Invoke()
			Apollo.StartTimer("CircleAlertDisplayTimer")
		end
	end
end

function Circles:OnCircleAlertDisplayTimer()
	self.wndMain:FindChild("AlertMessage"):Show(false)
	self.wndMain:Close()
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

	if self:FilterRequest(strInvitor) then
		self.wndCircleInvite = Apollo.LoadForm(self.xmlDoc, "CircleInviteConfirmation", nil, self)
		self.wndCircleInvite:FindChild("CircleInviteLabel"):SetText(String_GetWeaselString(Apollo.GetString("Guild_IncomingCircleInvite"), strGuildName, strInvitorName))
		self.wndCircleInvite:FindChild("FilterBtn"):SetCheck(g_InterfaceOptions.Carbine.bFilterGuildInvite)
		self.wndCircleInvite:ToFront()
	else
		GuildLib.Decline()
	end
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

function Circles:OnFilterBtn(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bFilterGuildInvite = wndHandler:IsChecked()
end

-----------------------------------------------------------------------------------------------
-- Roster Sorting
-----------------------------------------------------------------------------------------------

function Circles:OnRosterSortToggle(wndHandler, wndControl)
	self:BuildRosterList(self.wndMain:GetData(), self:SortRoster(self.wndMain:FindChild("RosterScreen:RosterHeaderContainer"):GetData(), wndHandler:GetName()))
end

function Circles:SortRoster(tArg, strLastClicked)
	-- TODO: Two tiers of sorting. E.g. Clicking Name then Path will give Paths sorted first, then Names sorted second
	if not tArg then
		return
	end

	local tResult = tArg
	local wndHeaderContainer = self.wndMain:FindChild("RosterScreen:RosterHeaderContainer")

	if wndHeaderContainer:FindChild("RosterSortBtnName"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.strName > b.strName) end)
	elseif wndHeaderContainer:FindChild("RosterSortBtnRank"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.nRank > b.nRank) end)
	elseif wndHeaderContainer:FindChild("RosterSortBtnLevel"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.nLevel < b.nLevel) end) -- Level we want highest to lowest
	elseif wndHeaderContainer:FindChild("RosterSortBtnClass"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.strClass > b.strClass) end)
	elseif wndHeaderContainer:FindChild("RosterSortBtnPath"):IsChecked() then
		table.sort(tResult, function(a,b) return (self:HelperConvertPathToString(a.ePathType) > self:HelperConvertPathToString(b.ePathType)) end) -- TODO: Potentially expensive?
	elseif wndHeaderContainer:FindChild("RosterSortBtnOnline"):IsChecked() then
		table.sort(tResult, function(a,b) return (a.fLastOnline < b.fLastOnline) end)
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
		end
	end

	return tResult
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------
function Circles:FilterRequest(strInvitor)
	if not g_InterfaceOptions.Carbine.bFilterGuildInvite then
		return true
	end
	
	local bPassedFilter = false
	
	local tRelationships = GameLib.SearchRelationshipStatusByCharacterName(strInvitor)
	if tRelationships and (tRelationships.tFriend or tRelationships.tAccountFriend or tRelationships.tGuilds or tRelationships.nGuildIndex) then
		bPassedFilter = true
	end
	
	return bPassedFilter
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
