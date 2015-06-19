-----------------------------------------------------------------------------------------------
-- Client Lua Script for FriendsList
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "FriendshipLib"
require "math"
require "string"
require "ChatSystemLib"
require "PlayerPathLib"
require "HousingLib"

local NeighborsList = {}

local ktClassIcon =
{
	[GameLib.CodeEnumClass.Medic] 			= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Esper] 			= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Warrior] 		= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Stalker] 		= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Engineer] 		= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Icon_Windows_UI_CRB_Spellslinger",
}

local ktClassName =
{
	[GameLib.CodeEnumClass.Medic]			= Apollo.GetString("CRB_Medic"),
	[GameLib.CodeEnumClass.Esper]			= Apollo.GetString("CRB_Esper"),
	[GameLib.CodeEnumClass.Warrior]			= Apollo.GetString("CRB_Warrior"),
	[GameLib.CodeEnumClass.Stalker] 		= Apollo.GetString("ClassStalker"),
	[GameLib.CodeEnumClass.Engineer]		= Apollo.GetString("CRB_Engineer"),
	[GameLib.CodeEnumClass.Spellslinger]	= Apollo.GetString("CRB_Spellslinger"),
}

local ktPathName =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= Apollo.GetString("PlayerPathSoldier"),
	[PlayerPathLib.PlayerPathType_Settler] 		= Apollo.GetString("PlayerPathSettler"),
	[PlayerPathLib.PlayerPathType_Scientist] 	= Apollo.GetString("PlayerPathExplorer"),
	[PlayerPathLib.PlayerPathType_Explorer] 	= Apollo.GetString("PlayerPathScientist"),
}

local kstrPathIcon =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= "Icon_Windows_UI_CRB_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "Icon_Windows_UI_CRB_Colonist",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "Icon_Windows_UI_CRB_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "Icon_Windows_UI_CRB_Explorer",
}

local karHousingResults =
{
	HousingLib.HousingResult_Neighbor_Success,
	HousingLib.HousingResult_Neighbor_RequestTimedOut,
	HousingLib.HousingResult_Neighbor_RequestAccepted,
	HousingLib.HousingResult_Neighbor_RequestDeclined,
	HousingLib.HousingResult_Neighbor_PlayerNotFound,
	HousingLib.HousingResult_Neighbor_PlayerNotOnline,
	HousingLib.HousingResult_Neighbor_PlayerNotAHomeowner,
	HousingLib.HousingResult_Neighbor_PlayerDoesntExist,
	HousingLib.HousingResult_Neighbor_InvalidNeighbor,
	HousingLib.HousingResult_Neighbor_AlreadyNeighbors,
	HousingLib.HousingResult_Neighbor_NoPendingInvite,
	HousingLib.HousingResult_Neighbor_InvitePending,
	HousingLib.HousingResult_Neighbor_PlayerWrongFaction,
	HousingLib.HousingResult_Neighbor_Full,
	HousingLib.HousingResult_Neighbor_PlayerIsIgnored,
	HousingLib.HousingResult_Neighbor_IgnoredByPlayer,
	HousingLib.HousingResult_Neighbor_MissingEntitlement,
	HousingLib.HousingResult_Neighbor_PrivilegeRestricted,
	HousingLib.HousingResult_Visit_Private,
	HousingLib.HousingResult_Visit_Ignored,
	HousingLib.HousingResult_Visit_InvalidWorld,
	HousingLib.HousingResult_Visit_Failed,
}

local knSaveVersion = 1

local kcrOnline = ApolloColor.new("UI_TextHoloBodyHighlight")
local kcrOffline = ApolloColor.new("UI_BtnTextGrayNormal")
local kcrNeutral = ApolloColor.new("gray")

function NeighborsList:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NeighborsList:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local locInviteLocation = self.wndInvite and self.wndInvite:GetLocation() or self.locSavedInviteLoc

	local tSave =
	{
		tInviteLocation = locInviteLocation and locInviteLocation:ToTable() or nil,
		bInviteShown = self.wndInvite and self.wndInvite:IsValid() and self.wndInvite:IsShown(),
		strInviterName = self.strInviterName,
		nSaveVersion = knSaveVersion,
	}

	return tSave
end

function NeighborsList:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.tInviteLocation then
		self.locSavedInviteLoc = WindowLocation.new(tSavedData.tInviteLocation)
	end

	if tSavedData.bInviteShown and tSavedData.strInviterName then
		self.strInviterName = tSavedData.strInviterName
	end

	self.tSavedData = tSavedData
end

function NeighborsList:Init()
    Apollo.RegisterAddon(self)
end

function NeighborsList:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("NeighborsList.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function NeighborsList:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("GenericEvent_InitializeNeighbors", "OnGenericEvent_InitializeNeighbors", self)
	Apollo.RegisterEventHandler("GenericEvent_DestroyNeighbors", 	"OnGenericEvent_DestroyNeighbors", self)
	Apollo.RegisterEventHandler("HousingNeighborInviteRecieved", 	"OnNeighborInviteRecieved", self)

	Apollo.CreateTimer("Neighbors_MessageDisplayTimer", 4.000, false)
	Apollo.StopTimer("Neighbors_MessageDisplayTimer")

	if self.strInviterName then
		self:OnNeighborInviteRecieved(self.strInviterName)
	end
end

function NeighborsList:OnGenericEvent_InitializeNeighbors(wndParent)
	if self.wndMain and self.wndMain:IsValid() then
		return
	end

	Apollo.RegisterEventHandler("HousingResultInterceptResponse", 		"OnHousingResultInterceptResponse", self)
	Apollo.RegisterEventHandler("HousingNeighborUpdate", 				"RefreshList", self)
	Apollo.RegisterEventHandler("HousingNeighborsLoaded", 				"RefreshList", self)
	Apollo.RegisterEventHandler("HousingNeighborInviteAccepted", 		"OnNeighborInviteAccepted", self)
	Apollo.RegisterEventHandler("HousingNeighborInviteDeclined", 		"OnNeighborInviteDeclined", self)
	Apollo.RegisterEventHandler("HousingPrivacyUpdated", 				"OnPrivacyUpdated", self)
	Apollo.RegisterEventHandler("ChangeWorld", 							"OnChangeWorld", self)

    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "FriendsListForm", wndParent, self)
    self.wndMain:Show(true)
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.wndListContainer = self.wndMain:FindChild("ListContainer")
	self.wndMain:FindChild("AddMemberCloseBtn"):SetData(self.wndMain:FindChild("AddWindow"))
	self.wndMain:FindChild("AddBtn"):AttachWindow(self.wndMain:FindChild("AddBtn"):FindChild("AddWindow"))

	self.wndLastSelected = nil
	self:OnShow()
end

function NeighborsList:OnGenericEvent_DestroyNeighbors()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
		self.wndLastSelected = nil
	end
end

-----------------------------------------------------------------------------------------------
-- FriendsList Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
function NeighborsList:OnShow()
	for _, wndOld in pairs(self.wndListContainer:GetChildren()) do
		wndOld:FindChild("FriendBtn"):SetCheck(false)
	end

	self:RefreshList()
	self.wndMain:Show(true)
	self.wndMain:ToFront()

	Event_FireGenericEvent("HousingResultInterceptRequest", self.wndMain, karHousingResults )
end

function NeighborsList:OnChangeWorld()
	if self.wndMain then
		self.wndMain:Show(true)
	end
end

function NeighborsList:OnNeighborSortToggle(wndHandler, wndControl)
	local bChecked = wndHandler:IsChecked()
	local strLastChecked = wndHandler:GetName()
	self.fnSort = nil

	if strLastChecked == "Label_Friend" then
		if bChecked then
			self.fnSort = function(a,b) return (a.strCharacterName > b.strCharacterName) end
		else
			self.fnSort = function(a,b) return (a.strCharacterName < b.strCharacterName) end
		end
	elseif strLastChecked == "Label_Roommate" then
		if bChecked then
			self.fnSort = function(a,b) return (a.ePermissionNeighbor > b.ePermissionNeighbor) end
		else
			self.fnSort = function(a,b) return (a.ePermissionNeighbor < b.ePermissionNeighbor) end
		end
	elseif strLastChecked == "Label_Level" then
		if bChecked then
			self.fnSort = function(a,b) return (a.nLevel > b.nLevel) end
		else
			self.fnSort = function(a,b) return (a.nLevel < b.nLevel) end
		end
	elseif strLastChecked == "Label_Class" then
		if bChecked then
			self.fnSort = function(a,b) return (ktClassName[a.nClassId] > ktClassName[b.nClassId]) end
		else
			self.fnSort = function(a,b) return (ktClassName[a.nClassId] < ktClassName[b.nClassId]) end
		end
	elseif strLastChecked == "Label_Path" then
		if bChecked then
			self.fnSort = function(a,b) return (ktPathName[a.nPathId] > ktPathName[b.nPathId]) end
		else
			self.fnSort = function(a,b) return (ktPathName[a.nPathId] < ktPathName[b.nPathId]) end
		end
	elseif strLastChecked == "Label_LastOnline" then
		if bChecked then
			self.fnSort = function(a,b) return (a.fLastOnline < b.fLastOnline) end
		else
			self.fnSort = function(a,b) return (a.fLastOnline > b.fLastOnline) end
		end
	end

	self:RefreshList()
end

function NeighborsList:RefreshList()

	local nPrevId = nil
	for key, wndOld in pairs(self.wndListContainer:GetChildren()) do
		if wndOld:FindChild("FriendBtn"):IsChecked() then
			nPrevId = wndOld:GetData().nId
		end
	end

	self.wndListContainer:DestroyChildren()

	local tNeighbors = HousingLib.GetNeighborList() or {}

	if self.fnSort then
		table.sort(tNeighbors, self.fnSort)
	end

	for key, tCurrNeighbor in pairs(tNeighbors) do
		local wndListItem = Apollo.LoadForm(self.xmlDoc, "FriendForm", self.wndListContainer, self)
		wndListItem:SetData(tCurrNeighbor) -- set the full table since we have no direct lookup for neighbors
		wndListItem:FindChild("Name"):SetText(tCurrNeighbor.strCharacterName)
		wndListItem:FindChild("Class"):SetSprite(ktClassIcon[tCurrNeighbor.nClassId])
		wndListItem:FindChild("Class"):SetTooltip(ktClassName[tCurrNeighbor.nClassId] or "")
		wndListItem:FindChild("Path"):SetSprite(kstrPathIcon[tCurrNeighbor.nPathId])
		wndListItem:FindChild("Path"):SetTooltip(ktPathName[tCurrNeighbor.nPathId] or "")
		wndListItem:FindChild("Level"):SetText(tCurrNeighbor.nLevel)

		if nPrevId ~= nil then
			wndListItem:FindChild("FriendBtn"):SetCheck(tCurrNeighbor.nId == nPrevId)
		end

		wndListItem:FindChild("RoommateIcon"):Show(tCurrNeighbor.ePermissionNeighbor == HousingLib.NeighborPermissionLevel.Roommate)
		if tCurrNeighbor.ePermissionNeighbor == HousingLib.NeighborPermissionLevel.Roommate then
			wndListItem:FindChild("RoommateIcon"):SetTooltip(Apollo.GetString("Neighbors_RoommateTooltip"))
		end

		wndListItem:FindChild("AccountIcon"):Show(tCurrNeighbor.ePermissionNeighbor == HousingLib.NeighborPermissionLevel.Account)
		if tCurrNeighbor.ePermissionNeighbor == HousingLib.NeighborPermissionLevel.Account then
			wndListItem:FindChild("AccountIcon"):SetTooltip(Apollo.GetString("Neighbors_RoommateAccountTooltip"))
		end

		local strColorToUse = kcrOffline
		if tCurrNeighbor.fLastOnline == 0 then -- online / check for strWorldZone
			strColorToUse = kcrOnline
			wndListItem:FindChild("LastOnline"):SetText(Apollo.GetString("Neighbors_Online"))
		else
			wndListItem:FindChild("LastOnline"):SetText(self:HelperConvertToTime(tCurrNeighbor.fLastOnline))
		end

		wndListItem:FindChild("Name"):SetTextColor(strColorToUse)
		wndListItem:FindChild("Level"):SetTextColor(strColorToUse)
		wndListItem:FindChild("LastOnline"):SetTextColor(strColorToUse)
	end

	-- set scroll
	self.wndListContainer:ArrangeChildrenVert()
	self:UpdateControls()
end

function NeighborsList:UpdateControls()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndControls = self.wndMain:FindChild("Controls")
	local tCurr = nil

	for key, wndListItem in pairs(self.wndListContainer:GetChildren()) do
		if wndListItem:FindChild("FriendBtn"):IsChecked() then
			tCurr = wndListItem:GetData()
			if tCurr.ePermissionNeighbor == HousingLib.NeighborPermissionLevel.Roommate then
				wndControls:FindChild("ModifyPermissionsBtn"):SetText(Apollo.GetString("Neighbors_SetToNormal"))
			else
				wndControls:FindChild("ModifyPermissionsBtn"):SetText(Apollo.GetString("Neighbors_SetToRoommate"))
			end
		end
	end


	
	-- must be on my skymap to visit; must be on someone else's to return (add button)
	wndControls:FindChild("VisitBtn"):Enable(HousingLib.IsHousingWorld())
	wndControls:FindChild("VisitDisabledBlocker"):Show(not HousingLib.IsHousingWorld())
	if not tCurr or not tCurr.nId then
		wndControls:FindChild("ModifyPermissionsBtn"):Enable(false)
		wndControls:FindChild("VisitBtn"):Enable(false)
		return
	end

	wndControls:FindChild("ModifyPermissionsBtn"):Enable(tCurr.ePermissionNeighbor ~= HousingLib.NeighborPermissionLevel.Account)
	wndControls:FindChild("VisitBtn"):Enable(HousingLib.IsHousingWorld())
	wndControls:FindChild("ModifyPermissionsBtn"):SetData(tCurr)
	wndControls:FindChild("VisitBtn"):SetData(tCurr)
end

-----------------------------------------------------------------------------------------------
-- FriendsListForm Button Functions
-----------------------------------------------------------------------------------------------

function NeighborsList:OnFriendBtn(wndHandler, wndControl, eMouseButton)
	local tCurrNeighbor = wndControl:GetParent():GetData()

	if tCurrNeighbor == nil then
		return false
	end
	if self.wndLastSelected then
		self.wndLastSelected:SetCheck(false)
	end

	self.wndLastSelected = wndHandler
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", self.wndMain, tCurrNeighbor.strCharacterName)
		return
	end

	self:UpdateControls()
end

function NeighborsList:OnFriendBtnUncheck(wndHandler, wndControl, eMouseButton)
	local tCurrNeighbor = wndControl:GetParent():GetData()

	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		wndControl:SetCheck(true)
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", self.wndMain, tCurrNeighbor.strCharacterName)
		return
	end

	if tCurrNeighbor == nil then
		return false
	end
	self.wndLastSelected = nil
	self:UpdateControls()
end

-- Add Sub-Window Functions
function NeighborsList:OnAddBtn(wndHandler, wndControl)
	local wndAdd = wndControl:FindChild("AddWindow")
	wndAdd:FindChild("AddMemberEditBox"):SetText("")
	wndAdd:FindChild("AddMemberEditBox"):SetFocus()
	wndAdd:Show(true)
end

function NeighborsList:OnAddMemberYesClick( wndHandler, wndControl )
	local wndParent = wndControl:GetParent()
	local strName = wndParent:FindChild("AddMemberEditBox"):GetText()

	if strName ~= nil and strName ~= "" then
		HousingLib.NeighborInviteByName(strName)
		Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("Social_AddedToNeighbors"), strName))
	end
	wndControl:GetParent():Show(false)
end

-- Modify Sub-Window Functions
function NeighborsList:OnModifyBtn(wndHandler, wndControl)

	local tCurrNeighbor = wndControl:GetData()
	if tCurrNeighbor == nil then
		return
	end
	local wndControls = self.wndMain:FindChild("Controls")
	local wndModify = wndControl:FindChild("ModifyWindow")
	wndModify:SetData(tCurrNeighbor)
	-- set the permissions button
	if tCurrNeighbor.ePermissionNeighbor == HousingLib.NeighborPermissionLevel.Roommate then
		wndControls:FindChild("ModifyPermissionsBtn"):SetText(Apollo.GetString("Neighbors_SetToNormal"))
	else
		wndControls:FindChild("ModifyPermissionsBtn"):SetText(Apollo.GetString("Neighbors_SetToRoommate"))
	end

	wndModify:Show(true)
end

function NeighborsList:OnModifyPermissionsBtn(wndHandler, wndControl)
	local tCurr = wndControl:GetData()
	
	if tCurr == nil then
		return
	end

	if tCurr ~= nil and tCurr.ePermissionNeighbor == HousingLib.NeighborPermissionLevel.Roommate then
		HousingLib.NeighborSetPermission(tCurr.nId, HousingLib.NeighborPermissionLevel.Normal)
		self.wndMain:FindChild("ModifyPermissionsBtn"):SetText(Apollo.GetString("Neighbors_SetToRoommate"))
	else
		HousingLib.NeighborSetPermission(tCurr.nId, HousingLib.NeighborPermissionLevel.Roommate)
		self.wndMain:FindChild("ModifyPermissionsBtn"):SetText(Apollo.GetString("Neighbors_SetToNormal"))
	end
	
	for key, wndListItem in pairs(self.wndListContainer:GetChildren()) do
		wndListItem:FindChild("FriendBtn"):SetCheck(false)
	end
end

-- Visit Sub-Window Functions
function NeighborsList:OnVisitBtn(wndHandler, wndControl)
	local tCurrNeighbor = wndControl:GetData()
	local wndVisit = wndControl:FindChild("VisitWindow")
	if tCurrNeighbor == nil then
		return
	end
	wndVisit:SetData(tCurrNeighbor)
	wndVisit:Show(true)
end

function NeighborsList:OnVisitConfirmBtn(wndHandler, wndControl)
	--local wndParent = wndControl:GetParent()
	local tCurrNeighbor = wndControl:GetData()

	if tCurrNeighbor ~= nil then
		HousingLib.VisitNeighborResidence(tCurrNeighbor.nId)
	end

	--wndParent:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Draw Helpers
-----------------------------------------------------------------------------------------------

function NeighborsList:HelperConvertToTime(nDays)
	if nDays == 0 then
		return Apollo.GetString("Neighbors_Online")
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
-- FEEDBACK WINDOW
-----------------------------------------------------------------------------------------------

function NeighborsList:OnHousingResultInterceptResponse( eResult, wndIntercept, strAlertMsg )
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if wndIntercept ~= self.wndMain or not strAlertMsg then
		return
	end

	if self.wndMain:IsShown() then
		-- (Re)start the timer and show the window. We're not queuing these since they come as results of direct action
		Event_FireGenericEvent("GenericEvent_SystemChannelMessage", strAlertMsg)
		Apollo.StopTimer("Neighbors_MessageDisplayTimer")
		Apollo.StartTimer("Neighbors_MessageDisplayTimer")
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, String_GetWeaselString(Apollo.GetString("Neighbors_FriendsListError"), strAlertMsg), "")
	end
end


-----------------------------------------------------------------------------------------------
-- Neighbor Invite Window
-----------------------------------------------------------------------------------------------
function NeighborsList:OnNeighborInviteRecieved(strName)
	if self.wndInvite and self.wndInvite:IsValid() then
		self.wndInvite:Destroy()
	end

	self.strInviterName = strName

	self.wndInvite = Apollo.LoadForm(self.xmlDoc, "NeighborInviteConfirmation", nil, self)
	self.wndInvite:FindChild("NeighborInviteLabel"):SetText(String_GetWeaselString(Apollo.GetString("Neighbors_InviteReceived"), strName))
	self.wndInvite:Invoke()

	if self.locSavedInviteLoc then
		self.wndInvite:MoveToLocation(self.locSavedInviteLoc)
	end
end

function NeighborsList:OnNeighborInviteAccept(wndHandler, wndControl)
	HousingLib.NeighborInviteAccept()
	if self.wndInvite then
		self.locSavedInviteLoc = self.wndInvite:GetLocation()
		self.wndInvite:Destroy()
	end
end

function NeighborsList:OnReportInviteSpamBtn(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_ReportPlayerNeighborInvite")
	self:OnNeighborInviteDecline()
end

function NeighborsList:OnNeighborInviteDecline() -- This can come from a variety of sources
	HousingLib.NeighborInviteDecline()
	if self.wndInvite then
		self.locSavedInviteLoc = self.wndInvite:GetLocation()
		self.wndInvite:Destroy()
	end
end

function NeighborsList:OnNeighborInviteAccepted(strName)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.strInviterName = nil

	if self.wndInvite then
		self.locSavedInviteLoc = self.wndInvite:GetLocation()
		self.wndInvite:Destroy()
	end

    local strMessage = Apollo.GetString("Neighbors_InviteAcceptedSelf")
    if string.len(strName) > 1 then
        strMessage = String_GetWeaselString(Apollo.GetString("Neighbors_InviteAccepted"), strName)
    end
	if self.wndMain:IsShown() then
	    self:OnHousingResultInterceptResponse(HousingLib.HousingResult_Neighbor_RequestAccepted, self.wndMain, strMessage)
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strMessage, "")
	end
end

function NeighborsList:OnNeighborInviteDeclined(strName)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.strInviterName = nil

	if self.wndInvite then
		self.locSavedInviteLoc = self.wndInvite:GetLocation()
		self.wndInvite:Destroy()
	end

    local strMessage = Apollo.GetString("Neighbors_InvitationExpired")
    if string.len(strName) > 1 then
        strMessage = String_GetWeaselString(Apollo.GetString("Neighbors_RequestDeclined"), strName)
    end
	if self.wndMain:IsShown() then
	    self:OnHousingResultInterceptResponse(HousingLib.HousingResult_Neighbor_RequestDeclined, self.wndMain, strMessage)
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strMessage, "")
	end
end

-- Closing the Pop Up Bubbles
function NeighborsList:OnSubCloseBtn(wndHandler)
	wndHandler:GetParent():Close()
end

local NeighborsListInst = NeighborsList:new()
NeighborsList:Init()
