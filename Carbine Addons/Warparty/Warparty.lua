-----------------------------------------------------------------------------------------------
-- Client Lua Script for Warparty
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GuildLib"
require "GuildTypeLib"
require "GroupLib"
require "GameLib"

local Warparty = {}

local crGuildNameLengthError = ApolloColor.new("red")
local crGuildNameLengthGood = ApolloColor.new("ffffffff")
local knSaveVersion = 2

function Warparty:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function Warparty:Init()
    Apollo.RegisterAddon(self)
end

function Warparty:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locMainLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedMainLoc
	local locInviteLocation = self.wndWarpartyInvite and self.wndWarpartyInvite:GetLocation() or self.locSavedInviteLoc
	
	local tSaved = 
	{
		tMainLocation = locMainLocation and locMainLocation:ToTable() or nil,
		tInviteLocation = locInviteLocation and locInviteLocation:ToTable() or nil,
		bInviteSent = self.wndWarpartyInvite and self.wndWarpartyInvite:IsValid() and self.wndWarpartyInvite:IsShown() or false,
		strWarpartyName = self.strSavedWarpartyName,
		strInvitorName = self.strSavedInvitorName,
		nSaveVersion = knSaveVersion,
	}
	
	return tSaved
end

function Warparty:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tMainLocation then
		self.locSavedMainLoc = WindowLocation.new(tSavedData.tMainLocation)
	end
	
	if tSavedData.tInviteLocation then
		self.locSavedInviteLoc = WindowLocation.new(tSavedData.tInviteLocation)
	end
	
	if tSavedData.bInviteSent then
		self.tInviteSent = true
		self.tStrWarpartyName = tSavedData.strWarpartyName
		self.tStrInvitorName = tSavedData.strInvitorName
	end
end

function Warparty:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("Warparty.xml")
    self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Warparty:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end

	-- The roster portion of this has been moved to the Circles for now (as they did the same thing). TODO: Cleaning up this add-on

	Apollo.RegisterEventHandler("Event_ShowWarpartyInfo",           "OnShowWarpartyInfo", self)
	Apollo.RegisterEventHandler("GuildInvite", 						"OnGuildInvite", self)  -- notification you got a guild/circle invite
	Apollo.RegisterEventHandler("GuildResult", 						"OnGuildResult", self)  -- notification about an action that occured with the guild (Likely from self)
	Apollo.RegisterEventHandler("GuildRoster", 						"OnGuildRoster", self)  -- notification that a guild roster was recieved.
	Apollo.RegisterEventHandler("GuildLoaded",						"OnGuildLoaded", self)  -- notification that your guild or a society has loaded.
	Apollo.RegisterEventHandler("GuildPvp", 						"OnGuildPvp", self) 	-- notification that the pvp standings of the guild has changed.	
	Apollo.RegisterEventHandler("GuildMemberChange", 				"OnGuildMemberChange", self)  -- General purpose update method
	Apollo.RegisterTimerHandler("ReloadCooldownTimer", 				"OnReloadCooldownTimer", self)
	Apollo.RegisterEventHandler("GenericEvent_RegisterWarparty", 	"OnClose", self)
	Apollo.RegisterEventHandler("GuildRankChange",					"OnGuildRankChange", self)
	
	self.bOkayToReload = true

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "WarpartyForm", nil, self)
	self.wndMain:Show(false, true)

    if self.wndMain and self.locSavedMainLoc then
		self.wndMain:MoveToLocation(self.locSavedMainLoc)
	end

	self.wndMain:FindChild("Controls"):ArrangeChildrenHorz(2)
	
	local wndPermissionContainer = self.wndMain:FindChild("PermissionContainer")
	for idx, tPermission in pairs(GuildLib.GetPermissions(GuildLib.GuildType_WarParty)) do
		local wndPermission = Apollo.LoadForm(self.xmlDoc, "PermissionEntry", wndPermissionContainer, self)
		local wndPermissionBtn = wndPermission:FindChild("PermissionBtn")
		wndPermissionBtn:SetText(tPermission.strName)
		wndPermission:SetData(tPermission)
	end
	wndPermissionContainer:ArrangeChildrenVert()
	
	self.wndRankPopout = self.wndMain:FindChild("RankPopout")

	if self.tInviteSent then
		self:OnGuildInvite( self.tStrWarpartyName, self.tStrInvitorName, GuildLib.GuildType_WarParty )
		self.wndWarpartyInvite:Show(true)
	end
end

function Warparty:OnClose()
	Apollo.StopTimer("RetryLoadingGuilds")
	self.wndMain:Close()
end

-----------------------------------------------------------------------------------------------
-- Warparty Functions
-----------------------------------------------------------------------------------------------
function Warparty:OnShowWarpartyInfo(tPos)

	self.wndMain:FindChild("RosterGrid"):DeleteAll() -- Reset UI when kicked or etc
		
	local bGuildTableIsEmpty = true
	local strPlayerName = GameLib.GetPlayerUnit():GetName()
	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_WarParty then
			local strRank = Apollo.GetString("Warparty_Member")
			if guildCurr:GetMyRank() == 1 then
				strRank = Apollo.GetString("Warparty_Leader")
			end

			self.wndMain:FindChild("SubHeader"):SetText(String_GetWeaselString(Apollo.GetString("Warparty_Header"), strRank))
			self.wndMain:FindChild("Header"):SetText(guildCurr:GetName())
			self.wndMain:FindChild("Header"):SetTextColor(ApolloColor.new("ff2f94ac"))
			self.wndMain:SetData(guildCurr)
			self:UpdatePvpRating()
			guildCurr:RequestMembers()		
			
			self.wndMain:Show(true)
			self.wndMain:ToFront()
			return
		end
	end
	
	-- you're not on a warparty
	self.wndMain:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Bottom Panel Roster Actions
-----------------------------------------------------------------------------------------------

function Warparty:ResetRosterMemberButtons()
	self.wndMain:FindChild("AddMemberContainer"):Show(false)
	self.wndMain:FindChild("RemoveMemberContainer"):Show(false)
	self.wndMain:FindChild("DisbandContainer"):Show(false)
	self.wndMain:FindChild("LeaveContainer"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnDemote"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnPromote"):Show(false)
	self.wndMain:FindChild("RosterDisbandBtn"):SetCheck(false)
	self.wndMain:FindChild("RosterLeaveBtn"):SetCheck(false)
	self.wndMain:FindChild("RosterOptionBtnDemote"):SetCheck(false)
	self.wndMain:FindChild("RosterOptionBtnPromote"):SetCheck(false)
	
	-- Defaults
	self.wndMain:FindChild("RosterOptionBtnAdd"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnRemove"):Show(false)

	self.wndMain:FindChild("RosterLeaveBtn"):Show(true)
	self.wndMain:FindChild("RosterOptionBtnInvite"):Show(true)
	self.wndMain:FindChild("RosterDisbandBtn"):Show(false)
	
	local guildOwner = self.wndMain:FindChild("AddMemberEditBox"):GetData()
	if guildOwner and guildOwner:GetMyRank() then
		local tMyRankPermissions	= guildOwner:GetRanks()[guildOwner:GetMyRank()]
		local bSomeRowIsPicked 		= self.wndMain:FindChild("RosterGrid"):GetCurrentRow()
		local tMemberInfo 			= self.wndMain:FindChild("RosterGrid"):GetData()
		local bTargetIsUnderMyRank 	= bSomeRowIsPicked and guildOwner:GetMyRank() < tMemberInfo.nRank
		local bValidUnit 			= bSomeRowIsPicked and tMemberInfo.fLastOnline == 0 and tMemberInfo.strName ~= GameLib.GetPlayerUnit():GetName()
		
		self.wndMain:FindChild("RosterOptionBtnRemove"):Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)

		self.wndMain:FindChild("RosterOptionBtnAdd"):Show(tMyRankPermissions and tMyRankPermissions.bInvite)
		self.wndMain:FindChild("RosterOptionBtnRemove"):Show(tMyRankPermissions and tMyRankPermissions.bKick)

		self.wndMain:FindChild("RosterOptionBtnPromote"):Enable(bSomeRowIsPicked and bTargetIsUnderMyRank)
		self.wndMain:FindChild("RosterOptionBtnDemote"):Enable(bSomeRowIsPicked and bTargetIsUnderMyRank and self.wndMain:FindChild("RosterGrid"):GetData().nRank ~= 10) -- Can't go below 10
		self.wndMain:FindChild("RosterOptionBtnDemote"):Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)
		self.wndMain:FindChild("RosterOptionBtnPromote"):Show(tMyRankPermissions and tMyRankPermissions.bChangeMemberRank)
		
		self.wndMain:FindChild("RosterDisbandBtn"):Show(guildOwner:GetMyRank() == 1)
		self.wndMain:FindChild("RosterLeaveBtn"):Show(guildOwner:GetMyRank() ~= 1)
	
		local bCanInvite = not GroupLib.InGroup() or GroupLib.AmILeader() or GroupLib.GetGroupMember(1).bCanInvite
		self.wndMain:FindChild("RosterOptionBtnInvite"):Enable(bValidUnit and bCanInvite)	
	end
	
	self.wndMain:FindChild("Controls"):ArrangeChildrenHorz(1)
end

-- The buttons
function Warparty:OnRosterAddMemberClick(wndHandler, wndControl)
	self:ResetRosterMemberButtons()
	self.wndMain:FindChild("AddMemberContainer"):Show(wndHandler:IsChecked())
	if wndHandler:IsChecked() then
		self.wndMain:FindChild("AddMemberEditBox"):SetFocus()
	end
end

function Warparty:OnRosterRemoveMemberClick(wndHandler, wndControl)
	self:ResetRosterMemberButtons()
	self.wndMain:FindChild("RemoveMemberContainer"):Show(wndHandler:IsChecked())
	if wndHandler:IsChecked() then
		self.wndMain:FindChild("RemoveMemberLabel"):SetText(String_GetWeaselString(Apollo.GetString("Circles_KickConfirmation"), self.wndMain:FindChild("RosterGrid"):GetData().strName))
	end
end

-- The Pop Up Bubbles
function Warparty:OnRosterAddMemberCloseBtn() -- The Window Close Event can also route here
	self.wndMain:FindChild("AddMemberEditBox"):SetText("")
	self.wndMain:FindChild("AddMemberContainer"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnAdd"):SetCheck(false)
end

function Warparty:OnRosterRemoveMemberCloseBtn() -- The Window Close Event can also route here
	self.wndMain:FindChild("RemoveMemberContainer"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnRemove"):SetCheck(false)
end

function Warparty:OnRosterRemoveMemberYesClick(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then -- wndHandler is 'RemoveMemberYesBtn' with data guild
		wndHandler:GetData():Kick(self.wndMain:FindChild("RosterGrid"):GetData().strName)
	end
	self:OnRosterRemoveMemberCloseBtn()
end

function Warparty:OnAddMemberEditBoxReturn(wndHandler, wndControl, strText)
	if wndHandler and wndHandler:GetData() and string.len(strText) > 0 then -- wndHandler is 'AddMemberEditBox' with data uGuild
		-- TODO: Additional string validation
		wndHandler:GetData():Invite(strText)
	end
	self:OnRosterAddMemberCloseBtn()
end

function Warparty:OnAddMemberConfirmBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetParent():FindChild("AddMemberEditBox") then
		local wndEditBox = wndHandler:GetParent():FindChild("AddMemberEditBox")

		if wndEditBox and wndEditBox:GetData() and string.len(wndEditBox:GetText()) > 0 then
			-- TODO: Additional string validation
			wndEditBox:GetData():Invite(wndEditBox:GetText())
		end
	end
	self:OnRosterAddMemberCloseBtn()
end

-- Disband/Leave functions
function Warparty:OnConfirmDisbandBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		wndHandler:GetData():Disband()
	end
end

function Warparty:OnDisbandContainerCloseBtn(wndHandler, wndControl)
	self.wndMain:FindChild("RosterDisbandBtn"):FindChild("DisbandContainer"):Show(false)
	self.wndMain:FindChild("RosterDisbandBtn"):SetCheck(false)
end

function Warparty:OnConfirmLeaveBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		wndHandler:GetData():Leave()
	end
end

function Warparty:OnLeaveContainerCloseBtn(wndHandler, wndControl)
	self.wndMain:FindChild("RosterLeaveBtn"):FindChild("LeaveContainer"):Show(false)
	self.wndMain:FindChild("RosterLeaveBtn"):SetCheck(false)
end

function Warparty:OnRosterLeaveBtn(wndHandler, wndControl)
	wndControl:FindChild("LeaveContainer"):Show(true)
end

function Warparty:OnRosterDisbandBtn(wndHandler, wndControl)
	wndControl:FindChild("DisbandContainer"):Show(true)
end

function Warparty:OnInviteToGroupClick(wndHandler, wndControl)
	local tMemberInfo = self.wndMain:FindChild("RosterGrid"):GetData()
	
	if self.wndMain:FindChild("RosterGrid"):GetCurrentRow() and tMemberInfo ~= nil then
		GroupLib.Invite(tMemberInfo.strName)
	end
end

-----------------------------------------------------------------------------------------------
-- Roster Methods -- TODO: Move this into its own addon if it gets too large
-----------------------------------------------------------------------------------------------

function Warparty:OnGuildRoster(guildOwner, tRoster) -- Event from CPP
	if guildOwner == self.wndMain:GetData() then 
		self:BuildRosterList(guildOwner, tRoster) -- Third argument is the default sorting method
	end
	
	self.tRoster = tRoster
end

function Warparty:BuildRosterList(guildOwner, tRoster)
	if not guildOwner or #tRoster == 0 then 
		return
	end

	local tRanks = guildOwner:GetRanks()
	local wndGrid = self.wndMain:FindChild("RosterGrid")
	wndGrid:DeleteAll() -- TODO remove this
	
	local nSlots = 0 -- default is 40v40	
	local nSlotsMax = 80 -- default is 40v40


	for key, tCurrMember in pairs(tRoster) do
		local strIcon = "CRB_DEMO_WrapperSprites:btnDemo_CharInvisibleNormal"
		if tCurrMember.nRank == 1 then -- Special icons for warparty leader
			strIcon = "CRB_Basekit:kitIcon_Holo_Profile"
		elseif tCurrMember.nRank == 2 then
			strIcon = "CRB_Basekit:kitIcon_Holo_Actions"
		end
		
		-- TODO: This should be an enum
		local strSpriteToUse = "CRB_GroupSprites:sprGrp_MFrameIcon_Axe"
		if tCurrMember.strClass == Apollo.GetString("ClassWarrior") then 
			strSpriteToUse = "Icon_Windows_UI_CRB_Warrior"
		elseif tCurrMember.strClass == Apollo.GetString("ClassEngineer") then 
			strSpriteToUse = "Icon_Windows_UI_CRB_Engineer"
		elseif tCurrMember.strClass == Apollo.GetString("ClassESPER") then 
			strSpriteToUse = "Icon_Windows_UI_CRB_Esper"
		elseif tCurrMember.strClass == Apollo.GetString("ClassMedic") then 
			strSpriteToUse = "Icon_Windows_UI_CRB_Medic"
		elseif tCurrMember.strClass == Apollo.GetString("ClassStalker") then 
			strSpriteToUse = "Icon_Windows_UI_CRB_Stalker"
		elseif tCurrMember.strClass == Apollo.GetString("ClassSpellslinger") then 
			strSpriteToUse = "Icon_Windows_UI_CRB_Spellslinger"
		end		
		

		local iCurrRow = wndGrid:AddRow("")
		local strFormatting = "<T Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">" -- online 
		if tCurrMember.fLastOnline ~= 0 then -- offline
			strFormatting = "<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">" 
		end
		
		wndGrid:SetCellLuaData(iCurrRow, 1, tCurrMember)
		wndGrid:SetCellImage(iCurrRow, 1, strIcon)
		wndGrid:SetCellDoc(iCurrRow, 2, strFormatting ..tCurrMember.strName.."</T>")
		wndGrid:SetCellImage(iCurrRow, 3, strSpriteToUse)
		wndGrid:SetCellDoc(iCurrRow, 4, strFormatting ..self:HelperConvertToTime(tCurrMember.fLastOnline).."</T>")	

		nSlots = nSlots + 1		
	end
	
	if nSlotsMax - nSlots > 0 then
		for idx = 1, nSlotsMax - nSlots do
			local iCurrRow = wndGrid:AddRow("")
			wndGrid:SetCellDoc(iCurrRow, 2, "<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff237083\">" ..Apollo.GetString("Warparty_Available").."</T>")
			wndGrid:EnableRow(iCurrRow, false)
		end
	end
	
	if 10 - nSlotsMax > 0 then
		for idx = nSlotsMax + 1, 10 do
			local iCurrRow = wndGrid:AddRow("")
			wndGrid:EnableRow(iCurrRow, false)
		end
	end	
	
	self.wndMain:FindChild("AddMemberEditBox"):SetData(guildOwner)
	self.wndMain:FindChild("RemoveMemberYesBtn"):SetData(guildOwner)

	self.wndMain:FindChild("RosterLeaveBtn"):FindChild("ConfirmLeaveBtn"):SetData(guildOwner)
	self.wndMain:FindChild("RosterDisbandBtn"):FindChild("ConfirmDisbandBtn"):SetData(guildOwner)

	self:ResetRosterMemberButtons()
	
	local guildCurr = self.wndMain:GetData()
	local eMyRank = guildCurr:GetMyRank()
	
	local wndRankPopout = self.wndMain:FindChild("RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	wndRankContainer:DestroyChildren()
	
	local nCurrentRankCount = 1
	local arRanks = guildCurr:GetRanks()
	for idx, tRank in ipairs(arRanks) do
		if tRank.bValid then		
			local wndRank = Apollo.LoadForm(self.xmlDoc, "RankEntry", wndRankContainer, self)
			wndRank:SetData({ nRankIdx = idx, bNew = false })
			wndRank:FindChild("OptionString"):SetText(tRank.strName)
			wndRank:FindChild("ModifyRankBtn"):Show(arRanks[eMyRank].bChangeRankPermissions)
			
			nCurrentRankCount = nCurrentRankCount + 1
		end
		
		if next(arRanks, idx) == nil and nCurrentRankCount < #arRanks and arRanks[eMyRank].bRankCreate then
			local wndRank = Apollo.LoadForm(self.xmlDoc, "AddRankEntry", wndRankContainer, self)
		end
	end
	
	wndRankContainer:ArrangeChildrenVert()
end

function Warparty:OnRosterGridItemClick(wndControl, wndHandler, iRow, iCol)
	local wndData = self.wndMain:FindChild("RosterGrid"):GetCellData(iRow, 1)
	if self.wndMain:FindChild("RosterGrid"):GetData() == wndData then
		self.wndMain:FindChild("RosterGrid"):SetData(nil)
		self.wndMain:FindChild("RosterGrid"):SetCurrentRow(0) -- Deselect grid
	else
		self.wndMain:FindChild("RosterGrid"):SetData(wndData)
	end

	self:ResetRosterMemberButtons()
end

function Warparty:OnGuildPvp(guildCurrent)
	if guildCurrent == self.wndMain:GetData() then
		self:UpdatePvpRating()
	end
end

function Warparty:UpdatePvpRating()
	local guildOwner = self.wndMain:GetData()
	if guildOwner == nil then
		return
	end
	
	local tPvPRatings = guildOwner:GetPvpRatings()
	if tPvPRatings == nil then
		return
	end
	
	self.wndMain:FindChild("Header"):SetText(String_GetWeaselString(Apollo.GetString("Warparty_Rating"), guildOwner:GetName(), tPvPRatings.nRating))
end

-----------------------------------------------------------------------------------------------
-- Warparty Invite Window
-----------------------------------------------------------------------------------------------

function Warparty:OnGuildInvite( strGuildName, strInvitorName, eGuildType )
	if eGuildType == GuildLib.GuildType_WarParty then
		self.wndWarpartyInvite = Apollo.LoadForm(self.xmlDoc, "WarpartyInviteConfirmation", nil, self)
		self.wndWarpartyInvite:FindChild("WarpartyInviteLabel"):SetText(String_GetWeaselString(Apollo.GetString("Warparty_InvitedBy"), strGuildName, strInvitorName))
		
		if self.locSavedInviteLoc then
			self.wndWarpartyInvite:MoveToLocation(self.locSavedInviteLoc)
		end
		self.strSavedWarpartyName = strGuildName
		self.strSavedInvitorName = strInvitorName
		
		self.wndWarpartyInvite:Show(true)
	else
		return
	end
	self.wndWarpartyInvite:ToFront()
end

function Warparty:OnWarpartyInviteAccept(wndHandler, wndControl)
	GuildLib.Accept()
	if self.wndWarpartyInvite then
		self.locSavedIniviteLoc = self.wndWarpartyInvite:GetLocation()
		self.wndWarpartyInvite:Destroy()
	end
end

function Warparty:OnWarpartyInviteDecline() -- This can come from a variety of sources
	GuildLib.Decline()
	
	if self.wndWarpartyInvite then
		self.locSavedInviteLoc = self.wndWarpartyInvite:GetLocation()
		self.wndWarpartyInvite:Destroy()
	end
end

-----------------------------------------------------------------------------------------------
-- Feedback Messages
-----------------------------------------------------------------------------------------------

function Warparty:OnGuildMemberChange(guildCurrent)
	if self.bOkayToReload and (guildCurrent:GetType() == GuildLib.GuildType_WarParty) and self.wndMain:IsShown() then
		self.wndMain:Show(false)
		self:OnShowWarpartyInfo()
		self.bOkayToReload = false
		Apollo.CreateTimer("ReloadCooldownTimer", 1, false)
		Apollo.StartTimer("ReloadCooldownTimer")
	end
end

function Warparty:OnReloadCooldownTimer()
	Apollo.StopTimer("ReloadCooldownTimer")
	self.bOkayToReload = true
end

function Warparty:OnGuildResult( guildSender, strName, nRank, eResult)
	if guildSender == nil or guildSender:GetType() ~= GuildLib.GuildType_WarParty then
		return
	end

	-- Reload UI when a WarParty is made
	if eResult == GuildLib.GuildResult_YouJoined then
		self.wndMain:Show(false)
		self:OnShowWarpartyInfo()
	elseif eResult == GuildLib.GuildResult_YouQuit or eResult == GuildLib.GuildResult_KickedYou or eResult == GuildLib.GuildResult_GuildDisbanded then
		self.wndMain:Show(false)
	elseif eResult == GuildLib.GuildResult_PendingInviteExpired and self.wndWarpartyInvite and self.wndWarpartyInvite:IsValid() then
		self.locSavedInviteLoc = self.wndWarpartyInvite:GetLocation()
		self.wndWarpartyInvite:Destroy()
	elseif self.wndMain:IsShown() then -- TODO: TEMP, request members again on an update
		guildSender:RequestMembers()
	end
end

function Warparty:HelperConvertToTime(nDays)
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


-----------------------------------------------------------------------------------------------
-- Rank Methods
-----------------------------------------------------------------------------------------------

function Warparty:OnRanksButtonSignal()
	local wndRankPopout = self.wndMain:FindChild("RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndRankSettings = wndRankPopout:FindChild("RankSettingsEntry")
	
	local bShow = not wndRankPopout:IsShown()
	
	wndRankPopout:Show(bShow)
	wndRankContainer:Show(bShow)
	wndRankSettings:Show(false)
end

function Warparty:OnAddRankBtnSignal(wndControl, wndHandler)
	local wndRankPopout = self.wndMain:FindChild("RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")
	wndSettings:FindChild("Delete"):Show(false)
	wndSettings:FindChild("MemberCount"):Show(false)
	local guildCurr = self.wndMain:GetData()
	local arRanks = guildCurr:GetRanks()
	
	local nFirstInactiveRank = nil
	for idx, tRank in ipairs(arRanks) do
		if not tRank.bValid then
			nFirstInactiveRank = { nRankIdx = idx, bNew = true }
			break
		end
	end
	
	if nFirstInactiveRank == nil then
		return
	end

	wndRankContainer:Show(false)
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

function Warparty:OnRemoveRankBtnSignal(wndControl, wndHandler)
	local wndRankContainer = self.wndRankPopout:FindChild("RankContainer")
	local wndSettings = self.wndRankPopout:FindChild("RankSettingsEntry")
	local nRankIdx = wndControl:GetParent():GetData().nRankIdx
	local guildCurr = self.wndMain:GetData()
	local arRanks = guildCurr:GetRanks()
	local eMyRank = guildCurr:GetMyRank()
	local tRank = arRanks[nRankIdx]		
	
	wndRankContainer:Show(false)
	wndSettings:SetData(wndControl:GetParent():GetData())
	wndSettings:Show(true)
	
	wndSettings:FindChild("OptionString"):SetText(tRank.strName)
	local wndPermissionContainer = self.wndMain:FindChild("PermissionContainer")
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

function Warparty:OnRankSettingsSaveBtn(wndControl, wndHandler)
	local wndRankPopout = self.wndMain:FindChild("RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")
	local tSettingsData = wndSettings:GetData()
	local guildCurr = self.wndMain:GetData()
	local tRank = guildCurr:GetRanks()[tSettingsData.nRankIdx]
	
	wndRankPopout:FindChild("RankContainer"):Show(true)
	wndSettings:Show(false)

	local strName = wndSettings:FindChild("OptionString"):GetText()
	if strName ~= tRank.strName then
		if tSettingsData.bNew then
			guildCurr:AddRank(tSettingsData.nRankIdx, strName)
		else
			guildCurr:RenameRank(tSettingsData.nRankIdx, strName)
		end
		tRank.strName = strName
	end
	
	local bDirtyRank = false
	for key, wndPermission in pairs(self.wndMain:FindChild("PermissionContainer"):GetChildren()) do
		local bPermissionChecked = wndPermission:FindChild("PermissionBtn"):IsChecked()
		if tRank[wndPermission:GetData().strLuaVariable] ~= bPermissionChecked then
			bDirtyRank = true
		end
		
		tRank[wndPermission:GetData().strLuaVariable] = wndPermission:FindChild("PermissionBtn"):IsChecked()
	end
	
	if bDirtyRank then
		guildCurr:ModifyRank(tSettingsData.nRankIdx, tRank)
	end
	
	wndSettings:SetData(tRank)
	--TODO update list display name for rank name
end

function Warparty:OnRankSettingsDeleteBtn(wndControl, wndHandler)
	local wndRankPopout = self.wndMain:FindChild("RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = self.wndMain:FindChild("RankPopout"):FindChild("RankSettingsEntry")

	local nRankIdx = wndSettings:GetData().nRankIdx
	local guildCurr = self.wndMain:GetData()
	
	guildCurr:RemoveRank(nRankIdx)
	
	wndRankContainer:Show(true)
	wndSettings:Show(false)
end

function Warparty:OnRankSettingsNameChanging(wndControl, wndHandler, strText)
	self:HelperValidateAndRefreshRankSettingsWindow(self.wndRankPopout:FindChild("RankSettingsEntry"))
end

function Warparty:OnRankSettingsPermissionBtn(wndControl, wndHandler)
	self:HelperValidateAndRefreshRankSettingsWindow(self.wndRankPopout:FindChild("RankSettingsEntry"))
end

function Warparty:HelperValidateAndRefreshRankSettingsWindow(wndSettings)
	local wndLimit = wndSettings:FindChild("Limit")
	local tRank = wndSettings:GetData()
	local strName = wndSettings:FindChild("OptionString"):GetText()
	
	if wndLimit ~= nil then
		local nNameLength = string.len(strName or "")
		
		wndLimit:SetText(string.format("(%d/%d)", nNameLength, GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName)))
		
		if nNameLength < 1 or nNameLength > GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName) then
			wndLimit:SetTextColor(crGuildNameLengthError)
		else
			wndLimit:SetTextColor(crGuildNameLengthGood)
		end
	end
	
	local bNameValid = strName ~= nil and strName ~= "" and GameLib.IsTextValid(strName, GameLib.CodeEnumUserText.GuildRankName, GameLib.CodeEnumUserTextFilterClass.Strict)
	local bNameChanged = strName ~= tRank.strName
	
	local bPermissionChanged = false
	for key, wndPermission in pairs(wndSettings:FindChild("PermissionContainer"):GetChildren()) do
		local bPermissionChecked = wndPermission:FindChild("PermissionBtn"):IsChecked()
		if tRank[wndPermission:GetData().strLuaVariable] ~= bPermissionChecked then
			bPermissionChanged = true
			break
		end
	end
	
	wndSettings:FindChild("RankPopoutOkBtn"):Enable((bNew and bNameValid) or (not bNew and bNameValid and (bNameChanged or bPermissionChanged)))
end

function Warparty:OnRankSettingsCloseBtn(wndControl, wndHandler)
	local wndRankPopout = self.wndMain:FindChild("RankPopout")
	local wndRankContainer = wndRankPopout:FindChild("RankContainer")
	local wndSettings = wndRankPopout:FindChild("RankSettingsEntry")

	wndRankPopout:FindChild("RankContainer"):Show(true)
	wndSettings:Show(false)
end

function Warparty:OnGuildRankChange(guildCurr)
	if guildCurr ~= self.wndMain:GetData() then
		return
	end
	self:OnGuildMemberChange(guildCurr)
end

function Warparty:OnRankPopoutCloseBtn(wndControl, wndHandler)
	local wndParent = wndControl:GetParent()
	wndParent:Show(false)
end

---------------------------------------------------------------------------------------------------
-- WarpartyForm Functions
---------------------------------------------------------------------------------------------------

function Warparty:OnRosterPromoteMemberCloseBtn( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("PromoteMemberContainer"):Show(false)
	self.wndMain:FindChild("RosterOptionBtnPromote"):SetCheck(false)
end

function Warparty:OnRosterDemoteMemberClick( wndHandler, wndControl, eMouseButton )
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterGrid"):GetData()
	guildCurr:Demote(tMember.strName)
end

function Warparty:OnRosterPromoteMemberClick( wndHandler, wndControl, eMouseButton )
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

function Warparty:OnRosterPromoteMemberYesClick( wndHandler, wndControl, eMouseButton )
	local guildCurr = self.wndMain:GetData()
	local tMember = self.wndMain:FindChild("RosterGrid"):GetData()
	
	guildCurr:PromoteMaster(tMember.strName)
	self:OnRosterPromoteMemberCloseBtn()
end

-----------------------------------------------------------------------------------------------
-- Warparty Instance
-----------------------------------------------------------------------------------------------
local WarpartyInst = Warparty:new()
WarpartyInst:Init()
