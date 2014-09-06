-----------------------------------------------------------------------------------------------
-- Client Lua Script for FriendsList
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "GameLib"
require "FriendshipLib"
require "math"
require "string"
require "ChatSystemLib"
require "PlayerPathLib"

local FriendsList = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local eProfanityFilter = GameLib.CodeEnumUserTextFilterClass.Strict

local LuaCodeEnumTabTypes =
{
	Friend = 1,
	Rival = 2,
	Ignore = 3,
	Suggested = 4
}

local karFriendTypes =
{
	Friend = 1,
	Account = 2,
	AccountInvite = 3,
	Rival = 4,
	Ignore = 5,
	Suggested = 6,
	FriendInvite = 7
}

local ktClass =
{
	[GameLib.CodeEnumClass.Medic] 			= Apollo.GetString("ClassMedic"),
	[GameLib.CodeEnumClass.Esper] 			= Apollo.GetString("CRB_Esper"),
	[GameLib.CodeEnumClass.Warrior] 		= Apollo.GetString("ClassWarrior"),
	[GameLib.CodeEnumClass.Stalker] 		= Apollo.GetString("ClassStalker"),
	[GameLib.CodeEnumClass.Engineer] 		= Apollo.GetString("ClassEngineer"),
	[GameLib.CodeEnumClass.Spellslinger] 	= Apollo.GetString("ClassSpellslinger"),
}

local ktClassIcon =
{
	[GameLib.CodeEnumClass.Medic] 			= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Esper] 			= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Warrior] 		= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Stalker]			= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Engineer] 		= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Icon_Windows_UI_CRB_Spellslinger",
}

local ktPath =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= Apollo.GetString("PlayerPathSoldier"),
	[PlayerPathLib.PlayerPathType_Settler] 		= Apollo.GetString("PlayerPathSettler"),
	[PlayerPathLib.PlayerPathType_Scientist] 	= Apollo.GetString("PlayerPathScientist"),
	[PlayerPathLib.PlayerPathType_Explorer] 	= Apollo.GetString("PlayerPathExplorer"),
}

local ktPathIcon =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= "Icon_Windows_UI_CRB_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "Icon_Windows_UI_CRB_Colonist",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "Icon_Windows_UI_CRB_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "Icon_Windows_UI_CRB_Explorer",
}

local ktFaction =
{
	[Unit.CodeEnumFaction.DominionPlayer] = Apollo.GetString("CRB_Dominion"),
	[Unit.CodeEnumFaction.ExilesPlayer] = Apollo.GetString("CRB_Exiles")
}

local ktListNames =
{
	Apollo.GetString("Friends_FriendsBtn"),
	Apollo.GetString("Friends_RivalsBtn"),
	Apollo.GetString("Friends_IgnoredBtn"),
	Apollo.GetString("Friends_SuggestedBtn"),
}

local ktTypesIntoEnums =  -- converts list idx to usable enum
{
	FriendshipLib.CharacterFriendshipType_Friend,
	FriendshipLib.CharacterFriendshipType_Rival,
	FriendshipLib.CharacterFriendshipType_Ignore,
}

local kcrColorOnline 	= ApolloColor.new("UI_TextHoloBodyHighlight")
local kcrColorOffline 	= ApolloColor.new("UI_BtnTextGrayNormal")
local kcrColorNeutral 	= ApolloColor.new("gray")
local kcrColorDominion 	= ApolloColor.new("xkcdAmber")
local kcrColorExile 	= ApolloColor.new("ff0893fe")
local kcrColorMessage	= ApolloColor.new("UI_TextHoloTitle")

local karStatusColors =
{
	[FriendshipLib.AccountPresenceState_Available]	= ApolloColor.new("green"),
	[FriendshipLib.AccountPresenceState_Away]		= ApolloColor.new("yellow"),
	[FriendshipLib.AccountPresenceState_Busy]		= ApolloColor.new("red"),
	[FriendshipLib.AccountPresenceState_Invisible]	= ApolloColor.new("gray"),
}

local karStatusText =
{
	[FriendshipLib.AccountPresenceState_Available]	= Apollo.GetString("Circles_Online"),
	[FriendshipLib.AccountPresenceState_Away]		= Apollo.GetString("Friends_StatusAwayBtn"),
	[FriendshipLib.AccountPresenceState_Busy]		= Apollo.GetString("Friends_StatusBusyBtn"),
	--[FriendshipLib.AccountPresenceState_Invisible]	= Apollo.GetString("Friends_StatusInvisibleBtn"),
}

-- Color was not being used in function.  If added, structure should look like = {strMessage = <String>, crColor = <Color>},
local ktFriendshipResult =
{
	[FriendshipLib.FriendshipResult_PlayerNotFound] 				= Apollo.GetString("Friends_PlayerNotFound"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_RealmNotFound] 					= Apollo.GetString("Friends_RealmNotFound"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_RequestDenied] 					= Apollo.GetString("Friends_RequestDenied"), 				--crColor = kcrColorMessage},
	[FriendshipLib.FriendshipResult_PlayerAlreadyFriend] 			= Apollo.GetString("Friends_AlreadyFriendsMsg"), 			--crColor = kcrColorMessage},
	[FriendshipLib.FriendshipResult_PlayerOffline] 					= Apollo.GetString("Friends_PlayerOffline"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_FriendshipNotFound] 			= Apollo.GetString("Friends_NotFound"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_InvalidType] 					= Apollo.GetString("Friends_InvalidType"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_RequestNotFound] 				= Apollo.GetString("Friends_RequestNotFound"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_RequestTimedOut] 				= Apollo.GetString("Friends_RequestTimeOut"), 				--crColor = kcrColorMessage},
	[FriendshipLib.FriendshipResult_Busy] 							= Apollo.GetString("Friends_BusyMsg"), 						--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_InvalidNote] 					= Apollo.GetString("Friends_InvalidNote"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_MaxFriends] 					= Apollo.GetString("Friends_MaxFriends"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_MaxRivals] 						= Apollo.GetString("Friends_MaxRivals"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_MaxIgnored] 					= Apollo.GetString("Friends_MaxIgnored"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_UnableToProcess] 				= Apollo.GetString("Friends_CannotProcess"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerNotFriend] 				= Apollo.GetString("Friends_PlayerNotFound"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerConsideringOtherFriend] 	= Apollo.GetString("Friends_MultipleRequests"), 			--crColor = kcrColorMessage},
	[FriendshipLib.FriendshipResult_RequestSent] 					= Apollo.GetString("Friends_RequestSent"), 					--crColor = kcrColorMessage},
	[FriendshipLib.FriendshipResult_PlayerAlreadyRival] 			= Apollo.GetString("Friends_AlreadyRival"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerAlreadyNeighbor] 			= Apollo.GetString("Friends_AlreadyNeighbor"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerAlreadyIgnored] 			= Apollo.GetString("Friends_AlreadyIgnored"), 				--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerOnIgnored] 				= Apollo.GetString("Friends_PlayerIgnored"), 				--crColor = kcrColorMessage},
	[FriendshipLib.FriendshipResult_PlayerNotRival] 				= Apollo.GetString("Friends_NotRival"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerNotIgnored] 				= Apollo.GetString("Friends_NotIgnored"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerNotNeighbor] 				= Apollo.GetString("Friends_NotNeighbor"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_PlayerNotOfThisRealm] 			= Apollo.GetString("Friends_NotOnRealm"), 					--crColor = kcrColorDominion},
	[FriendshipLib.FriendshipResult_FriendsBlocked] 				= Apollo.GetString("Friends_BlockingRequests"), 			--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_CannotInviteSelf] 				= Apollo.GetString("Friends_CannotInviteSelf"), 			--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_ThrottledRequest] 				= Apollo.GetString("Friends_ThrottledRequest"), 			--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_ContainsProfanity] 				= Apollo.GetString("Friends_ContainsProfanity"), 			--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_InvalidPublicNote] 				= Apollo.GetString("Friends_InvalidPublicNote"), 			--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_InvalidPublicDisplayName] 		= Apollo.GetString("Friends_InvalidPublicDisplayName"), 	--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_BlockedForStrangers] 			= Apollo.GetString("Friends_BlockedForStrangers"), 			--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_InvalidEmail] 					= Apollo.GetString("Friends_InvalidPublicDisplayName"), 	--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_InvalidAutoResponse] 			= Apollo.GetString("Friends_InvalidAutoResponse"),		 	--crColor = kcrColorMessage}
	[FriendshipLib.FriendshipResult_NameUnavailable]				= Apollo.GetString("Friends_NameUnavailable"),			 	--crColor = kcrColorMessage}
}

local ktSortButtonToFuncMap =
{
	["RosterSortBtnType"] = "SortType",
	["RosterSortBtnName"] = "SortName",
	["RosterSortBtnLevel"] = "SortLevel",
	["RosterSortBtnClass"] = "SortClass",
	["RosterSortBtnPath"] = "SortPath",
	["RosterSortBtnOnline"] = "SortStatus",
	["RosterSortBtnNote"] = "SortNote",
}

local ktWindowNameSortRanking =
{
	["AccountFriendInviteForm"] = 1,
	["FriendInviteForm"] = 2,
	["AccountFriendForm"] = 3,
	["FriendForm"] = 4,
	["RivalForm"] = 5,
	["SuggestedForm"] = 6,
	["IgnoredForm"] = 7,
}

local knSaveVersion = 1

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function FriendsList:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- indexing to call against the radio buttons
	o.arFriends 		= {}
	o.arRivals 			= {}
	o.arIgnored 		= {}
	o.arSuggested 		= {}
	o.arAccountFriends	= {}
	o.arAccountInvites	= {}
	o.arInvites			= {}

	o.arListTypes =
	{
		o.arFriends,
		o.arRivals,
		o.arIgnored,
		o.arSuggested,
	}
	
	o.arLastSorts = 
	{
		[LuaCodeEnumTabTypes.Friend] = {"", "Special"},
		[LuaCodeEnumTabTypes.Rival] = {"", "Special"},
		[LuaCodeEnumTabTypes.Ignore] = {"", "Special"},
		[LuaCodeEnumTabTypes.Suggested] = {"", "Special"},
	}
	
	o.tWndRefs = {}

    return o
end

function FriendsList:Init()
	Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- FriendsList OnLoad
-----------------------------------------------------------------------------------------------
function FriendsList:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("FriendsList.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function FriendsList:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_InitializeFriends", "OnGenericEvent_InitializeFriends", self)
	Apollo.RegisterEventHandler("GenericEvent_DestroyFriends", "OnGenericEvent_DestroyFriends", self)
	
	-- load our forms
	Apollo.RegisterEventHandler("FriendshipResult", 						"OnFriendshipResult", self)
	Apollo.RegisterEventHandler("FriendshipLoaded", 						"OnFriendshipLoaded", self)
	Apollo.RegisterEventHandler("FriendshipAdd", 							"OnFriendshipAdd", self)
	Apollo.RegisterEventHandler("FriendshipUpdate", 						"OnFriendshipUpdate", self)
	Apollo.RegisterEventHandler("FriendshipUpdateOnline", 					"OnFriendshipUpdateOnline", self)
	Apollo.RegisterEventHandler("FriendshipRemove", 						"OnFriendshipRemove", self)
	Apollo.RegisterEventHandler("FriendshipLocation", 						"OnFriendshipLocation", self)
	Apollo.RegisterEventHandler("FriendshipRequest", 						"OnFriendshipRequest", self)
	Apollo.RegisterEventHandler("FriendshipRequestWithdrawn", 				"OnFriendshipRequestWithdrawn", self)
	Apollo.RegisterEventHandler("FriendshipSuggestedAdd", 					"OnFriendshipSuggestedAdd", self)
	Apollo.RegisterEventHandler("FriendshipSuggestedUpdate", 				"OnFriendshipSuggestedUpdate", self)
	Apollo.RegisterEventHandler("FriendshipSuggestedRemove", 				"OnFriendshipSuggestedRemove", self)
	Apollo.RegisterEventHandler("FriendshipInvitesRecieved",  				"OnFriendshipInvitesRecieved", self)
    Apollo.RegisterEventHandler("FriendshipInviteRemoved",   				"OnFriendshipInviteRemoved", self)
	Apollo.RegisterEventHandler("FriendshipAccountInvitesRecieved",  		"OnFriendshipAccountInvitesRecieved", self)
    Apollo.RegisterEventHandler("FriendshipAccountInviteRemoved",   		"OnFriendshipAccountInviteRemoved", self)
	Apollo.RegisterEventHandler("FriendshipAccountFriendsRecieved",  		"OnFriendshipAccountFriendsRecieved", self)
    Apollo.RegisterEventHandler("FriendshipAccountFriendRemoved",   		"OnFriendshipAccountFriendRemoved", self)
	Apollo.RegisterEventHandler("FriendshipAccountCharacterLevelUpdate",  	"OnFriendshipAccountCharacterLevelUpdate", self)
	Apollo.RegisterEventHandler("FriendshipAccountDataUpdate",  			"OnFriendshipAccountDataUpdate", self)
	Apollo.RegisterEventHandler("FriendshipAccountPersonalStatusUpdate",  	"OnFriendshipAccountPersonalStatusUpdate", self)
	Apollo.RegisterEventHandler("EventGeneric_ConfirmRemoveAccountFriend", 	"OnEventGeneric_ConfirmRemoveAccountFriend", self)

	Apollo.RegisterTimerHandler("Friends_MessageDisplayTimer", 				"OnMessageDisplayTimer", self)
	Apollo.RegisterTimerHandler("UpdateLocationsTimer", 					"OnUpdateLocationsTimer", self)
	Apollo.RegisterTimerHandler("UpdateLastOnlineTimer", 					"OnUpdateLastOnlineTimer", self)
end

function FriendsList:OnGenericEvent_InitializeFriends(wndParent)
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		return
	end

    self.tWndRefs.wndMain 					= Apollo.LoadForm(self.xmlDoc, "FriendsListForm", wndParent, self)
	self.tWndRefs.wndListContainer 			= self.tWndRefs.wndMain:FindChild("ListContainer")
	self.tWndRefs.wndMessage				= self.tWndRefs.wndMain:FindChild("UpdateMessage")
	self.tWndRefs.wndStatusDropDownLabel 	= self.tWndRefs.wndMain:FindChild("StatusLabel")
	self.tWndRefs.wndStatusDropDownIcon 	= self.tWndRefs.wndMain:FindChild("StatusIcon")
	self.tWndRefs.wndControls 				= self.tWndRefs.wndMain:FindChild("SortContainer")
	self.tWndRefs.wndAddBtn 				= self.tWndRefs.wndControls:FindChild("AddBtn")
	self.tWndRefs.wndAccountAddBtn			= self.tWndRefs.wndControls:FindChild("AccountAddBtn")
	self.tWndRefs.wndModifyBtn 				= self.tWndRefs.wndControls:FindChild("ModifyBtn")
	self.tWndRefs.wndUnignoreBtn 			= self.tWndRefs.wndControls:FindChild("UnignoreBtn")
	self.tWndRefs.wndModifyNoteBtn 			= self.tWndRefs.wndControls:FindChild("ModifyNoteBtn")
	self.tWndRefs.wndModifySubFraming 		= self.tWndRefs.wndControls:FindChild("ModifySubFraming")
	self.tWndRefs.wndModifyFriendBtn		= self.tWndRefs.wndControls:FindChild("ModifyFriendBtn")
	self.tWndRefs.wndModifyRivalBtn 		= self.tWndRefs.wndControls:FindChild("ModifyRivalBtn")
	self.tWndRefs.wndModifyIgnoreBtn 		= self.tWndRefs.wndControls:FindChild("ModifyIgnoreBtn")
	self.tWndRefs.wndUnignoreWindow 		= self.tWndRefs.wndControls:FindChild("UnignoreWindow")
	self.tWndRefs.wndModifyWindow 			= self.tWndRefs.wndControls:FindChild("ModifyWindow")
	self.tWndRefs.wndAddWindow 				= self.tWndRefs.wndControls:FindChild("AddWindow")
	self.tWndRefs.wndAccountAddWindow 		= self.tWndRefs.wndControls:FindChild("AccountAddWindow")
	self.tWndRefs.wndNoteWindow 			= self.tWndRefs.wndControls:FindChild("NoteWindow")
	self.tWndRefs.wndAccountBlockBtn 		= self.tWndRefs.wndMain:FindChild("AccountBlockBtn")

	self.tWndRefs.wndMain:Show(true)
	self.tWndRefs.wndMessage:Show(true)
	if self.locSavedWindowLoc then
		self.tWndRefs.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.tWndRefs.tTabs = {}

	self.tWndRefs.arHeaders =
	{
		self.tWndRefs.wndMain:FindChild("RosterHeaderContainer"):FindChild("Controls_Friends"),
		self.tWndRefs.wndMain:FindChild("RosterHeaderContainer"):FindChild("Controls_Rivals"),
		self.tWndRefs.wndMain:FindChild("RosterHeaderContainer"):FindChild("Controls_Ignored"),
		self.tWndRefs.wndMain:FindChild("RosterHeaderContainer"):FindChild("Controls_Suggested"),
	}

	self.tWndRefs.wndMain:FindChild("ListBlocker"):Show(true)
	self.tWndRefs.wndMain:FindChild("BlockBtn"):SetCheck(not FriendshipLib.IsLocked())

	local bIgnoreAccountFriendInvites = FriendshipLib.GetPersonalStatus().bIgnoreStrangerInvites
	self.tWndRefs.wndAccountBlockBtn:SetCheck(not bIgnoreAccountFriendInvites)

	for idx = 1, #ktListNames do
		local wndTabBtn = self.tWndRefs.wndMain:FindChild("TabContainer"):FindChild("FriendTabBtn"..idx)
		wndTabBtn:SetData(idx)
		wndTabBtn:Enable(false)
		self.tWndRefs.tTabs[idx] = wndTabBtn
	end

	self.tWndRefs.wndMain:FindChild("TabContainer"):ArrangeChildrenHorz(1)

	self.tWndRefs.wndMain:FindChild("OptionsBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("OptionsBtnFlash"))
	self.tWndRefs.wndMain:FindChild("OptionsBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("AdvancedOptionsContainer"))
	self.tWndRefs.wndMain:FindChild("UnignoreBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("UnignoreBtn"):FindChild("UnignoreWindow"))
	self.tWndRefs.wndMain:FindChild("ModifyBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("ModifyBtn"):FindChild("ModifyWindow"))
	self.tWndRefs.wndMain:FindChild("ModifyNoteBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("ModifyNoteBtn"):FindChild("NoteWindow"))
	self.tWndRefs.wndMain:FindChild("SelfBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("SelfBtn"):FindChild("SelfWindow"))
	self.tWndRefs.wndMain:FindChild("SelfWindowChangeNoteBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("SelfWindowChangeNoteBtn"):FindChild("SelfNoteWindow"))
	self.tWndRefs.wndMain:FindChild("SelfModifyNameBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("SelfModifyNameBtn"):FindChild("NameWindow"))
	self.tWndRefs.wndMain:FindChild("ModifyRemoveBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("ModifyRemoveBtn"):FindChild("RemoveFriendWindow"))
	self.tWndRefs.wndMain:FindChild("AccountAddBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("AccountAddBtn"):FindChild("AccountAddWindow"))
	self.tWndRefs.wndMain:FindChild("AddBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("AddBtn"):FindChild("AddWindow"))
	self.tWndRefs.wndMain:FindChild("StatusDropdownBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("StatusDropdownArt"))

	self.tWndRefs.wndMain:FindChild("SelfWindowAvailableBtn"):SetData(FriendshipLib.AccountPresenceState_Available)
	self.tWndRefs.wndMain:FindChild("SelfWindowAwaylBtn"):SetData(FriendshipLib.AccountPresenceState_Away)
	self.tWndRefs.wndMain:FindChild("SelfWindowBusyBtn"):SetData(FriendshipLib.AccountPresenceState_Busy)


	self.wndRequest = Apollo.LoadForm(self.xmlDoc, "FriendRequestPopup", nil, self)
	self.wndRequest:Show(false)
		
	self.tWndRefs.wndMain:FindChild("MessageText"):Show(false)

		
	if FriendshipLib.IsLoaded() then
		self:OnFriendshipLoaded()
	end

	self.bTimerCreated = false

	self:UpdateControls()

	self:OnFriendsListOn()
end

function FriendsList:OnGenericEvent_DestroyFriends()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end
	
	Apollo.StopTimer("UpdateLastOnlineTimer")
end

function FriendsList:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSaved =
	{
		arLastSorts = self.arLastSorts,
		nSaveVersion = knSaveVersion,
	}
	return tSaved
end

function FriendsList:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.arLastSorts then
		self.arLastSorts = tSavedData.arLastSorts
	end
end

-----------------------------------------------------------------------------------------------
-- FriendsList Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
function FriendsList:OnFriendshipLoaded()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	self.tWndRefs.wndMain:FindChild("ListBlocker"):Show(false)
	for idx = 1, #self.tWndRefs.tTabs do
		self.tWndRefs.tTabs[idx]:Enable(true)
	end
end

function FriendsList:OnFriendsListOn()
	if not FriendshipLib.IsLoaded() then
		Apollo.StopTimer("UpdateLocationsTimer")
		Apollo.StopTimer("UpdateLastOnlineTimer")
		return
	end

	for key, tFriend in pairs(FriendshipLib.GetList()) do
		if tFriend.bIgnore == true then
			self.arIgnored[tFriend.nId] = tFriend
		else
			if tFriend.bFriend == true then
				self.arFriends[tFriend.nId] = tFriend
			end

			if tFriend.bRival == true then
				self.arRivals[tFriend.nId] = tFriend
			end
		end
	end

	for key, tSuggested in pairs(FriendshipLib.GetSuggestedList()) do
		self.arSuggested[tSuggested.nId] = tSuggested
	end

	for key, tFriend in pairs(FriendshipLib.GetAccountList()) do
		self.arAccountFriends[tFriend.nId] = tFriend
	end

	for key, tInvite in pairs(FriendshipLib.GetAccountInviteList()) do
		self.arAccountInvites[tInvite.nId] = tInvite
	end

	for key, tInvite in pairs(FriendshipLib.GetInviteList()) do
		self.arInvites[tInvite.nId] = tInvite
	end

	self.tWndRefs.tTabs[LuaCodeEnumTabTypes.Friend]:SetCheck(true)
	self.tWndRefs.arHeaders[LuaCodeEnumTabTypes.Friend]:Show(true)
	self:DrawControls(LuaCodeEnumTabTypes.Friend)
	for idx = 2, #self.tWndRefs.tTabs do
		self.tWndRefs.tTabs[idx]:SetCheck(false)
		self.tWndRefs.arHeaders[idx]:Show(false)
	end

	if not self.bTimerCreated then
		Apollo.CreateTimer("UpdateLocationsTimer", 10.000, true)
		Apollo.CreateTimer("UpdateLastOnlineTimer", 120, true)
		self.bTimerCreated = true
	else
		Apollo.StartTimer("UpdateLastOnlineTimer")
		Apollo.StartTimer("UpdateLocationsTimer")
	end

	self:DrawList(LuaCodeEnumTabTypes.Friend)
end

-----------------------------------------------------------------------------------------------
-- Friends List Updates (all types but suggested)
-----------------------------------------------------------------------------------------------
function FriendsList:OnFriendshipAdd(nFriendId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	local tFriend = FriendshipLib.GetById(nFriendId)
	local bViewingList = false

	if tFriend.bIgnore == true then
		self.arIgnored[nFriendId] = tFriend
		bViewingList = self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Ignore
	else
		if tFriend.bFriend == true then -- can be friend and rival
			self.arFriends[nFriendId] = tFriend
			bViewingList = self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Ignore and self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Suggested
		end

		if tFriend.bRival == true then
			self.arRivals[nFriendId] = tFriend
			bViewingList = self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Ignore and self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Suggested
		end
	end

	if bViewingList == true then
		self:HelperAddOrUpdateMemberWindow(nFriendId, tFriend)
		self:PerformLastSort()
	end
end

function FriendsList:OnFriendshipUpdate(nFriendId) -- Gotcha: will fire for every list the player is on, so removing might also have this event
	local nTab = self.tWndRefs.wndListContainer and self.tWndRefs.wndListContainer:GetData() or nil
	local tFriend = FriendshipLib.GetById( nFriendId )

	if tFriend.bIgnore == true then
		self.arIgnored[nFriendId] = tFriend
		if nTab and nTab == LuaCodeEnumTabTypes.Ignore then
			self:HelperAddOrUpdateMemberWindow(nFriendId, tFriend)
			self:PerformLastSort()
		end
	else
		self:OnFriendshipRemoveFromList(nFriendId, LuaCodeEnumTabTypes.Ignore)
	end

	if tFriend.bFriend == true then -- can be friend and rival
		self.arFriends[nFriendId] = tFriend
		if nTab and nTab == LuaCodeEnumTabTypes.Friend then
			self:HelperAddOrUpdateMemberWindow(nFriendId, tFriend)
			self:PerformLastSort()
		end
	else
		self:OnFriendshipRemoveFromList(nFriendId, LuaCodeEnumTabTypes.Friend)
	end

	if tFriend.bRival == true then
		self.arRivals[nFriendId] = tFriend
		if nTab and nTab == LuaCodeEnumTabTypes.Rival then
			self:HelperAddOrUpdateMemberWindow(nFriendId, tFriend)
			self:PerformLastSort()
		end
	else
		self:OnFriendshipRemoveFromList(nFriendId, LuaCodeEnumTabTypes.Rival)
	end

	FriendshipLib.InviteMarkSeen(nFriendId)
	Event_FireGenericEvent("EventGeneric_FriendInviteSeen", tInviteId)
end

function FriendsList:OnFriendshipUpdateOnline(nFriendId)

	local tFriend = FriendshipLib.GetById(nFriendId)
	self.arFriends[nFriendId] = tFriend

	if tFriend.bFriend == true and tFriend.strCharacterName and tFriend.strCharacterName ~= "" then
		if tFriend.fLastOnline == 0 then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, String_GetWeaselString(Apollo.GetString("Friends_HasComeOnline"), tFriend.strCharacterName), "")
		else
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, String_GetWeaselString(Apollo.GetString("Friends_HasGoneOffline"), tFriend.strCharacterName), "")
		end
		Sound.Play(Sound.PlayUISocialFriendAlert)
	end

	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end


	if self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Friend then -- only Friends draw this info
		for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
			if wndPlayerEntry:GetData() == nFriendId then
				self:HelperAddOrUpdateMemberWindow(nFriendId, tFriend)
				self:PerformLastSort()
			end
		end
	end
end

function FriendsList:OnFriendshipRemove(nFriendId) -- removes from all lists
	for idx = 1, #self.arListTypes do
		self:HelperRemoveMemberWindow(nFriendId, idx)	-- do all; the function will only search the one that's shown
		if self.arListTypes[idx][nFriendId] ~= nil then -- find the right one and remove it
			self.arListTypes[idx][nFriendId] = nil
		end
	end
end

function FriendsList:OnFriendshipRemoveFromList(nFriendId, nTab) -- removes from specific list
	self:HelperRemoveMemberWindow(nFriendId, nTab)	-- do all; the function will only search the one that's shown
	if self.arListTypes[nTab][nFriendId] ~= nil then -- find the right one and remove it
		self.arListTypes[nTab][nFriendId] = nil
	end
end

-----------------------------------------------------------------------------------------------
-- Location Updates
-----------------------------------------------------------------------------------------------

function FriendsList:OnUpdateLocationsTimer()
	if self.tWndRefs.wndMain == nil or self.tWndRefs.wndMain:IsShown() and self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end
	local tOnlineFriends = {}
	for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndPlayerEntry:GetData() ~= nil then
			local nFriendId = wndPlayerEntry:GetData()
			local tFriend = FriendshipLib.GetById(nFriendId) or FriendshipLib.GetAccountById(nFriendId)

			if tFriend ~= nil and tFriend.fLastOnline == 0 then -- online
				table.insert(tOnlineFriends, tFriend.nId)
			end
		end
	end

	FriendshipLib.GetLocations(tOnlineFriends)
end


function FriendsList:OnFriendshipLocation(tLocations)
	if self.tWndRefs.wndMain == nil or self.tWndRefs.wndMain:IsShown() and self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	for idx, tLocInfo in pairs(tLocations) do
		if tLocInfo.nId ~= nil and self.arListTypes[LuaCodeEnumTabTypes.Friend][tLocInfo.nId] ~= nil then
			for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
				if wndPlayerEntry:GetData() == tLocInfo.nId then
					local tFriend = FriendshipLib.GetById(tLocInfo.nId)
					self.arListTypes[LuaCodeEnumTabTypes.Friend][tLocInfo.nId] =  tFriend
					self:HelperDrawMemberWindowFriend(wndPlayerEntry, tFriend)
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Suggested List Updates
-----------------------------------------------------------------------------------------------
function FriendsList:OnFriendshipSuggestedAdd(nSuggestedId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	local tSuggested = FriendshipLib.GetSuggestedById(nSuggestedId)
	self.arSuggested[nSuggestedId] = tSuggested

	if self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Suggested then
		self:HelperAddOrUpdateMemberWindow(nSuggestedId, tSuggested)
		self:PerformLastSort()
	end
end

function FriendsList:OnFriendshipSuggestedUpdate(nSuggestedId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	local tSuggested = FriendshipLib.GetSuggestedById(nSuggestedId)
	self.arSuggested[nSuggestedId] = tSuggested -- overwrites the old data

	if self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Suggested then
		self:HelperAddOrUpdateMemberWindow(nSuggestedId, tSuggested)
		self:PerformLastSort()
	end
end

function FriendsList:OnFriendshipSuggestedRemove(nSuggestedId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	self.arSuggested[nSuggestedId] = nil

	if self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Suggested then
		for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
			if wndPlayerEntry:GetData() == nSuggestedId then
				wndPlayerEntry:Destroy()
				self:PerformLastSort()
				self:UpdateControls()
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- DRAW FUNCTIONS
-----------------------------------------------------------------------------------------------

function FriendsList:DrawList(nList) -- pass the list we're updating so we can call against all of them
	self.tWndRefs.wndListContainer:DestroyChildren()
	self.tWndRefs.wndListContainer:RecalculateContentExtents()
	self.tWndRefs.wndListContainer:SetData(nList)


	if nList == LuaCodeEnumTabTypes.Friend then
		for idx, tMemberInvite in pairs(self.arAccountInvites) do
			self:HelperAddOrUpdateMemberWindow(idx, tMemberInvite)
		end
		for idx, tMemberInvite in pairs(self.arInvites) do
			self:HelperAddOrUpdateMemberWindow(idx, tMemberInvite)
		end
		for idx, tMemberInfo in pairs(self.arAccountFriends) do
			self:HelperAddOrUpdateMemberWindow(idx, tMemberInfo)
		end
		for idx, tMemberInfo in pairs(self.arFriends) do
			self:HelperAddOrUpdateMemberWindow(idx, tMemberInfo)
		end
	else
		for idx, tMemberInfo in pairs(self.arListTypes[nList]) do
			self:HelperAddOrUpdateMemberWindow(idx, tMemberInfo)
		end
	end
	
	self:PerformLastSort()

	self:DrawControls(nList)
	self:UpdateControls()

	if nList == LuaCodeEnumTabTypes.Friend then
		self:OnUpdateLocationsTimer()
	end
end

function FriendsList:HelperAddOrUpdateMemberWindow(nFriendId, tFriend)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then -- May actually not be visible yet
		return
	end

	local wndNewListEntry = self:GetFriendshipWindowByFriendId(nFriendId)
	if wndNewListEntry == nil then
		if self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Friend then
			if self.arFriends[nFriendId] ~= nil then
				wndNewListEntry = self:FactoryProduce(self.tWndRefs.wndListContainer, "FriendForm", nFriendId)
			elseif self.arAccountFriends[nFriendId] ~= nil then
				wndNewListEntry = self:FactoryProduce(self.tWndRefs.wndListContainer, "AccountFriendForm", nFriendId)
			elseif self.arAccountInvites[nFriendId] ~= nil then
				wndNewListEntry = self:FactoryProduce(self.tWndRefs.wndListContainer, "AccountFriendInviteForm", nFriendId)
			elseif self.arInvites[nFriendId] ~= nil then
				wndNewListEntry = self:FactoryProduce(self.tWndRefs.wndListContainer, "FriendInviteForm", nFriendId)
			end
		elseif self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Ignore then
			wndNewListEntry = self:FactoryProduce(self.tWndRefs.wndListContainer, "IgnoredForm", nFriendId)
		elseif self.tWndRefs.wndListContainer:GetData() == LuaCodeEnumTabTypes.Rival  then
			wndNewListEntry = self:FactoryProduce(self.tWndRefs.wndListContainer, "RivalForm", nFriendId)
		else -- suggested
			wndNewListEntry = self:FactoryProduce(self.tWndRefs.wndListContainer, "SuggestedForm", nFriendId)
		end

		if wndNewListEntry == nil then
			self:UpdateControls()
			return
		end
		wndNewListEntry:SetData(nFriendId)
	end

	if wndNewListEntry:FindChild("Name") and tFriend.bTemporary then
		wndNewListEntry:FindChild("Name"):SetText(String_GetWeaselString(Apollo.GetString("Friends_TemporaryIgnoreName"), tFriend.strCharacterName))
	elseif wndNewListEntry:FindChild("Name") then
		wndNewListEntry:FindChild("Name"):SetText(tFriend.strCharacterName)
	end

	if wndNewListEntry:GetName() == "FriendForm" then
		self:HelperDrawMemberWindowFriend(wndNewListEntry, tFriend)
	elseif wndNewListEntry:GetName() == "RivalForm" then
		self:HelperDrawMemberWindowRival(wndNewListEntry, tFriend)
	elseif wndNewListEntry:GetName() == "SuggestedForm" then
		self:HelperDrawMemberWindowSuggested(wndNewListEntry, tFriend)
	elseif wndNewListEntry:GetName() == "IgnoredForm" then
		self:HelperDrawMemberWindowIgnore(wndNewListEntry, tFriend)
	elseif wndNewListEntry:GetName() == "AccountFriendForm" then
		self:HelperDrawMemberWindowAccountFriend(wndNewListEntry, tFriend)
	elseif wndNewListEntry:GetName() == "AccountFriendInviteForm" then
		self:HelperDrawMemberWindowAccountFriendInviteRequest(wndNewListEntry, tFriend)
	elseif wndNewListEntry:GetName() == "FriendInviteForm" then
		self:HelperDrawMemberWindowFriendInviteRequest(wndNewListEntry, tFriend)
	end

	self:UpdateControls()
end

function FriendsList:HelperRemoveMemberWindow(nFriendId, nList)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	if nList == self.tWndRefs.wndListContainer:GetData() then -- if we're showing this list
		for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
			if wndPlayerEntry:GetData() == nFriendId then
				wndPlayerEntry:Destroy()
				self:PerformLastSort()
				self:UpdateControls()
			end
		end
	end

	self:UpdateControls()
end

function FriendsList:DrawControls(nList)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	self.tWndRefs.wndAddBtn:Show(true)
	self.tWndRefs.wndAccountAddBtn:Show(false)
	--self.tWndRefs.wndModifyBtn:Show(true)
	self.tWndRefs.wndUnignoreBtn:Show(false)
	self.tWndRefs.wndModifyNoteBtn:Show(true)
	self.tWndRefs.wndModifySubFraming:Show(true)
	self.tWndRefs.wndModifyFriendBtn:Show(true)
	self.tWndRefs.wndModifyRivalBtn:Show(true)
	self.tWndRefs.wndModifyIgnoreBtn:Show(true)

	self.tWndRefs.wndUnignoreWindow:Show(false)
	self.tWndRefs.wndModifyWindow:Show(false)
	self.tWndRefs.wndAddWindow:Show(false)
	self.tWndRefs.wndAccountAddWindow:Show(false)
	self.tWndRefs.wndNoteWindow:Show(false)

	if nList == LuaCodeEnumTabTypes.Friend then
		self.tWndRefs.wndAccountAddBtn:Show(true)
	elseif nList == LuaCodeEnumTabTypes.Rival then
	elseif nList == LuaCodeEnumTabTypes.Ignore then
		self.tWndRefs.wndModifyBtn:Show(false)
		self.tWndRefs.wndUnignoreBtn:Show(true)
	elseif nList == LuaCodeEnumTabTypes.Suggested then
		self.tWndRefs.wndAddBtn:Show(false)
		self.tWndRefs.wndModifyNoteBtn:Show(false)
	end
	self.tWndRefs.wndMain:FindChild("SortContainer"):ArrangeChildrenHorz(2)
end


function FriendsList:OnFriendTabBtn(wndHandler, wndControl)
	if wndControl:GetData() == nil then
		return
	end

	local nList = wndControl:GetData()
	for idx = 1, #self.tWndRefs.tTabs do
		self.tWndRefs.tTabs[idx]:SetCheck(self.tWndRefs.tTabs[idx]:GetData() == nList)
		self.tWndRefs.arHeaders[idx]:Show(idx == nList)
	end

	self:DrawList(nList)
	self.tWndRefs.wndMain:FindChild("SortContainer"):ArrangeChildrenHorz(2)
	self:UpdateControls()
end

function FriendsList:UpdateControls()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	if self.tWndRefs.wndMain:FindChild("FriendTabBtn1"):IsChecked() then
		self:DrawControls(LuaCodeEnumTabTypes.Friend)
	elseif self.tWndRefs.wndMain:FindChild("FriendTabBtn2"):IsChecked() then	 -- Rival
		self:DrawControls(LuaCodeEnumTabTypes.Rival)
	elseif self.tWndRefs.wndMain:FindChild("FriendTabBtn3"):IsChecked() then -- Ignore
		self:DrawControls(LuaCodeEnumTabTypes.Ignore)
	elseif self.tWndRefs.wndMain:FindChild("FriendTabBtn4"):IsChecked() then	-- Suggested
		self:DrawControls(LuaCodeEnumTabTypes.Suggested)
		self:UpdateControlsSuggested()
		return
	end

	self.tWndRefs.wndModifyBtn:SetText(Apollo.GetString("Friends_Modify"))

	local tPersonalStatus = FriendshipLib.GetPersonalStatus()
	self.tWndRefs.wndStatusDropDownLabel:SetText(karStatusText[tPersonalStatus.nPresenceState])
	self.tWndRefs.wndStatusDropDownIcon:SetBGColor(karStatusColors[tPersonalStatus.nPresenceState])

	local tFriend = nil
	local strWindowName = nil

	local bFoundAtLeastOne = false
	for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndPlayerEntry:FindChild("FriendBtn"):IsChecked() then
			local nFriendId = wndPlayerEntry:GetData()
			tFriend = FriendshipLib.GetById(nFriendId) or FriendshipLib.GetAccountById(nFriendId)
			strWindowName = wndPlayerEntry:GetName()
			bFoundAtLeastOne = true
		end
	end

	self.tWndRefs.wndModifyBtn:Enable(bFoundAtLeastOne and strWindowName ~= "AccountFriendInviteForm" and strWindowName ~= "FriendInviteForm")
	self.tWndRefs.wndModifyNoteBtn:Enable(bFoundAtLeastOne and strWindowName ~= "AccountFriendInviteForm" and strWindowName ~= "FriendInviteForm")
	self.tWndRefs.wndUnignoreBtn:Enable(bFoundAtLeastOne and strWindowName ~= "AccountFriendInviteForm" and strWindowName ~= "FriendInviteForm")

	if tFriend then
		self.tWndRefs.wndModifyBtn:SetData(tFriend)
		self.tWndRefs.wndModifyNoteBtn:SetData(tFriend)
		self.tWndRefs.wndUnignoreBtn:SetData(tFriend)
	end

	self.tWndRefs.wndMain:FindChild("SortContainer"):ArrangeChildrenHorz(2)
end

function FriendsList:UpdateControlsSuggested()
	self.tWndRefs.wndModifyBtn:Show(true)
	local tFriend = nil
	local nList = self.tWndRefs.wndListContainer:GetData()
	self.tWndRefs.wndModifyBtn:SetText(Apollo.GetString("Friends_AddToList"))

	if nList ~= LuaCodeEnumTabTypes.Suggested then
		return
	end

	for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndPlayerEntry:FindChild("FriendBtn"):IsChecked() then
			local nFriendId = wndPlayerEntry:GetData()
			tFriend = FriendshipLib.GetSuggestedById(nFriendId)
		end
	end

	if tFriend == nil then
		self.tWndRefs.wndModifyBtn:Enable(false)
		return
	end

	self.tWndRefs.wndModifyBtn:Enable(true)
	self.tWndRefs.wndModifyBtn:SetData(tFriend)
	self.tWndRefs.wndModifyNoteBtn:SetData(tFriend)
end

-----------------------------------------------------------------------------------------------
-- Draw Helpers
-----------------------------------------------------------------------------------------------

function FriendsList:HelperDrawMemberWindowFriend(wndPlayerInfo, tFriend)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	self:HelperFormatPathAndClass(wndPlayerInfo, tFriend.nClassId, tFriend.nPathId)
	wndPlayerInfo:FindChild("Level"):SetText(tFriend.nLevel)
	self:HelperFormatNote(wndPlayerInfo:FindChild("NoteIcon"), tFriend.strNote)

	local crColorToUse = kcrColorOffline

	if tFriend.fLastOnline == 0 then -- online / check for strWorldZone
		crColorToUse = kcrColorOnline
		if tFriend.strWorldZone ~= nil and tFriend.strWorldZone ~= "" then
			wndPlayerInfo:FindChild("LastOnline"):SetTooltip(String_GetWeaselString(Apollo.GetString("Friends_CurrentLocation"), tFriend.strWorldZone))
			wndPlayerInfo:FindChild("LastOnline"):SetText(tFriend.strWorldZone)
		else
			wndPlayerInfo:FindChild("LastOnline"):SetTooltip("")
			wndPlayerInfo:FindChild("LastOnline"):SetText(Apollo.GetString("Friends_Online"))
		end

		-- if this friend is also an account friend, we should use that accounts status to determine our color
		local tRelatedAccountFriend = nil
		for idx,tSearchAccountFriend in pairs(FriendshipLib.GetAccountList()) do
			for idx, tSearchFriend in pairs(tSearchAccountFriend.arCharacters or {}) do
				if tSearchFriend.strCharacterName == tFriend.strCharacterName and tSearchFriend.strRealm == tFriend.strRealmName then
					tRelatedAccountFriend = tSearchAccountFriend
				end
			end
		end

		if tRelatedAccountFriend ~= nil then
			wndPlayerInfo:FindChild("StatusIcon"):SetBGColor(karStatusColors[tRelatedAccountFriend.nPresenceState])
		else
			wndPlayerInfo:FindChild("StatusIcon"):SetBGColor(karStatusColors[FriendshipLib.AccountPresenceState_Available])
		end
	else
		wndPlayerInfo:FindChild("LastOnline"):SetTooltip("")
		wndPlayerInfo:FindChild("LastOnline"):SetText(self:HelperConvertToTime(tFriend.fLastOnline))
		wndPlayerInfo:FindChild("StatusIcon"):SetBGColor(karStatusColors[FriendshipLib.AccountPresenceState_Invisible])
	end

	wndPlayerInfo:FindChild("Name"):SetTextColor(crColorToUse)
	wndPlayerInfo:FindChild("Level"):SetTextColor(crColorToUse)
	wndPlayerInfo:FindChild("LastOnline"):SetTextColor(crColorToUse)
end

function FriendsList:HelperDrawMemberWindowFriendInviteRequest(wnd, tInvite)
    if tInvite == nil then
        return
    end

	self:HelperFormatPathAndClass(wnd, tInvite.nClassId, tInvite.nPathId)
	wnd:FindChild("Level"):SetText(tInvite.nLevel)
	self:HelperFormatNote(wnd:FindChild("NoteIcon"), tInvite.strNote)

    if tInvite.fDaysUntilExpired ~= nil and tInvite.fDaysUntilExpired ~= 0 then
        wnd:FindChild("ExpireDate"):SetTooltip("")
        wnd:FindChild("ExpireDate"):SetText(self:HelperConvertToTimeTilExpired(tInvite.fDaysUntilExpired))
    else
        wnd:FindChild("ExpireDate"):SetTooltip("")
        wnd:FindChild("ExpireDate"):SetText(Apollo.GetString("Friends_Expired"))
    end

    wnd:FindChild("Name"):SetText(tInvite.strCharacterName)
	wnd:FindChild("IsNew"):Show(tInvite.bIsNew)
end

function FriendsList:HelperDrawMemberWindowIgnore(wndPlayerInfo, tFriend)
	wndPlayerInfo:FindChild("Faction"):SetText(ktFaction[tFriend.nFactionId])
	self:HelperFormatNote(wndPlayerInfo:FindChild("NoteIcon"), tFriend.strNote)
end

function FriendsList:HelperDrawMemberWindowAccountFriend(wnd, tFriend)
	if wnd == nil or tFriend == nil then
		return
	end

	local crColorToUse = kcrColorOffline

	local bIsOnline = tFriend.arCharacters ~= nil and tFriend.arCharacters[1] ~= nil
	if bIsOnline then
		crColorToUse = kcrColorOnline
		local tFirstFriendCharacter = tFriend.arCharacters[1]

		self:HelperFormatPathAndClass(wnd, tFirstFriendCharacter.nClassId, tFirstFriendCharacter.nPathId)
		wnd:FindChild("Level"):SetText(tFirstFriendCharacter.nLevel)

		if tFirstFriendCharacter.strRealm == GameLib:GetRealmName() then
			wnd:FindChild("Server"):SetText(tFirstFriendCharacter.strCharacterName)
		else
			wnd:FindChild("Server"):SetText(String_GetWeaselString(Apollo.GetString("Friends_RealmText"), tFirstFriendCharacter.strRealm))
		end

		wnd:FindChild("LastOnline"):SetTooltip(String_GetWeaselString(Apollo.GetString("Friends_CurrentLocation"), tFirstFriendCharacter.strWorldZone))
		wnd:FindChild("LastOnline"):SetText(tFirstFriendCharacter.strWorldZone)

		-- if this account friend is also a friend, we should use that accounts status to determine the friend's color
		for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
			if tFirstFriendCharacter.strCharacterName == wndPlayerEntry:FindChild("Name"):GetText() then
				local tLocFriend = FriendshipLib.GetById(wndPlayerEntry:GetData())
				if tLocFriend and tLocFriend.fLastOnline == 0 then
					wndPlayerEntry:FindChild("StatusIcon"):SetBGColor(karStatusColors[tFriend.nPresenceState])
				end
			end
		end

		else
			wnd:FindChild("LastOnline"):SetText(self:HelperConvertToTime(tFriend.fLastOnline))
			wnd:FindChild("Server"):SetText("")
	end

	wnd:FindChild("AccountFriendCharacterForm"):Show(bIsOnline)
	wnd:FindChild("StatusIcon"):SetBGColor(karStatusColors[tFriend.nPresenceState])
	wnd:FindChild("Name"):SetTextColor(crColorToUse)
	wnd:FindChild("Level"):SetTextColor(crColorToUse)
	wnd:FindChild("Server"):SetTextColor(crColorToUse)
	wnd:FindChild("LastOnline"):SetTextColor(crColorToUse)

	self:HelperFormatNote(wnd:FindChild("NoteIcon"), tFriend.strPrivateNote)
	self:HelperFormatNote(wnd:FindChild("PublicNoteIcon"), tFriend.strPublicNote)
end

function FriendsList:HelperDrawMemberWindowAccountFriendInviteRequest(wnd, tInvite)
    if tInvite == nil then
        return
    end

	self:HelperFormatNote(wnd:FindChild("NoteIcon"), tInvite.strNote)
    if tInvite.fDaysUntilExpired ~= nil and tInvite.fDaysUntilExpired ~= 0 then
        wnd:FindChild("ExpireDate"):SetTooltip("")
        wnd:FindChild("ExpireDate"):SetText(self:HelperConvertToTimeTilExpired(tInvite.fDaysUntilExpired))
    else
        wnd:FindChild("ExpireDate"):SetTooltip("")
        wnd:FindChild("ExpireDate"):SetText(Apollo.GetString("Friends_Expired"))
    end

    wnd:FindChild("Name"):SetText(tInvite.strDisplayName)
	wnd:FindChild("IsNew"):Show(tInvite.bIsNew)
end

function FriendsList:HelperDrawMemberWindowRival(wndPlayerInfo, tFriend)
	self:HelperFormatPathAndClass(wndPlayerInfo, tFriend.nClassId, tFriend.nPathId)
	self:HelperFormatNote(wndPlayerInfo:FindChild("NoteIcon"), tFriend.strNote)

	local crColorToUse = kcrColorDominion
	if tFriend.nFactionId == Unit.CodeEnumFaction.ExilesPlayer then -- exiles
		crColorToUse = kcrColorExile
		wndPlayerInfo:FindChild("Faction"):SetText(Apollo.GetString("Friends_ExilesFaction"))
	else
		wndPlayerInfo:FindChild("Faction"):SetText(Apollo.GetString("Friends_DominionFaction"))
	end

	wndPlayerInfo:FindChild("Name"):SetTextColor(crColorToUse)
	wndPlayerInfo:FindChild("Faction"):SetTextColor(crColorToUse)
end

function FriendsList:HelperDrawMemberWindowSuggested(wndPlayerInfo, tFriend)
	self:HelperFormatPathAndClass(wndPlayerInfo, tFriend.nClassId, tFriend.nPathId)
	wndPlayerInfo:FindChild("Level"):SetText(tFriend.nLevel)

	wndPlayerInfo:FindChild("Name"):SetTextColor(kcrColorNeutral)
	wndPlayerInfo:FindChild("Level"):SetTextColor(kcrColorNeutral)
end

function FriendsList:HelperFormatNote(wndNoteIcon, strNote)
	wndNoteIcon:Show(strNote ~= nil and strNote ~= "")
	wndNoteIcon:SetTooltip(strNote or "")
end

function FriendsList:HelperFormatPathAndClass(wndEntry, nClassId, nPathId)
	local wndClass = wndEntry:FindChild("Class")
	if wndClass ~= nil then
		if ktClassIcon[nClassId] ~= nil then
			wndClass:SetSprite(ktClassIcon[nClassId])
		end
		if ktClass[nClassId] ~= nil then
			wndClass:SetTooltip(ktClass[nClassId])
		end
	end

	local wndPath = wndEntry:FindChild("Path")
	if wndPath ~= nil then
		if ktPathIcon[nPathId] ~= nil then
			wndPath:SetSprite(ktPathIcon[nPathId])
		end
		if ktPath[nPathId] ~= nil then
			wndPath:SetTooltip(ktPath[nPathId])
		end
	end
end

function FriendsList:HelperConvertToTime(nDays)
	if nDays == 0 or nDays == nil then
		return Apollo.GetString("Friends_Online")
	end

	local tTimeData =
	{
		["name"]	= "",
		["count"]	= nil,
	}

	local nYears = math.floor(nDays / 365)
	local nMonths = math.floor(nDays / 30)
	local nWeeks = math.floor(nDays / 7)
	local nDaysRounded = math.floor(nDays / 1)
	local fHours = nDays * 24
	local nHoursRounded = math.floor(fHours)
	local nMinutes = math.floor(fHours * 60)

	if nYears > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Year")
		tTimeData["count"] = nYears
	elseif nMonths > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Month")
		tTimeData["count"] = nMonths
	elseif nWeeks > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Week")
		tTimeData["count"] = nWeeks
	elseif nDaysRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Day")
		tTimeData["count"] = nDaysRounded
	elseif nHoursRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Hour")
		tTimeData["count"] = nHoursRounded
	elseif nMinutes > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = nMinutes
	else
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = 1
	end

	return String_GetWeaselString(Apollo.GetString("CRB_TimeOffline"), tTimeData)
end

function FriendsList:HelperConvertToTimeTilExpired(nDays)
	local tTimeData =
	{
		["name"]	= "",
		["count"]	= nil,
	}

	local nYears = math.floor(nDays / 365)
	local nMonths = math.floor(nDays / 30)
	local nWeeks = math.floor(nDays / 7)
	local nDaysRounded = math.floor(nDays / 1)
	local fHours = nDays * 24
	local nHoursRounded = math.floor(fHours)
	local nMinutes = math.floor(fHours * 60)

	if nYears > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Year")
		tTimeData["count"] = nYears
	elseif nMonths > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Month")
		tTimeData["count"] = nMonths
	elseif nWeeks > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Week")
		tTimeData["count"] = nWeeks
	elseif nDaysRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Day")
		tTimeData["count"] = nDaysRounded
	elseif nHoursRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Hour")
		tTimeData["count"] = nHoursRounded
	elseif nMinutes > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = nMinutes
	else
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = 1
	end

	return String_GetWeaselString(Apollo.GetString("Friends_ExpiresText"), tTimeData)
end

-----------------------------------------------------------------------------------------------
-- FriendsListForm Button Functions
-----------------------------------------------------------------------------------------------

function FriendsList:OnAccountContextMenuOnlyBtn(wndHandler, wndControl) -- TODO REFACTOR: Can just store the name instead
	local idFriend = wndControl:GetParent():GetData()
	if idFriend == nil then
		return false
	end

	local tFriendData = FriendshipLib.GetAccountById(idFriend)
	if tFriendData == nil then
		return false
	end

	Event_FireGenericEvent("GenericEvent_NewContextMenuFriend", self.tWndRefs.wndMain, idFriend)
end

function FriendsList:OnContextMenuOnlyBtn(wndHandler, wndControl)
	local idFriend = wndControl:GetParent():GetData()
	if idFriend == nil then
		return false
	end

	local tFriendData = FriendshipLib.GetById(idFriend)
	if tFriendData == nil then
		return false
	end

	Event_FireGenericEvent("GenericEvent_NewContextMenuFriend", self.tWndRefs.wndMain, idFriend)
end

function FriendsList:OnAccountFriendBtn(wndHandler, wndControl) -- TODO REFACTOR: Can just store the name instead
	local idFriend = wndControl:GetParent():GetData()
	if idFriend == nil then
		return false
	end
	
	if self.wndSelectedFriend then
		self.wndSelectedFriend:SetCheck(false)
	end
	
	self.wndSelectedFriend = wndControl

	self:UpdateControls()
end

function FriendsList:OnFriendBtn(wndHandler, wndControl)
	local idFriend = wndControl:GetParent():GetData()
	if idFriend == nil then
		return false
	end
	
	if self.wndSelectedFriend then
		self.wndSelectedFriend:SetCheck(false)
	end
	
	self.wndSelectedFriend = wndControl

	self:UpdateControls()
end

function FriendsList:OnFriendBtnUncheck(wndHandler, wndControl)
	self.wndSelectedFriend = nil
	self:UpdateControls()
end

-- Add Sub-Window Functions
function FriendsList:OnAddBtn(wndHandler, wndControl)
	local wndAdd = wndControl:FindChild("AddWindow")

	wndAdd:FindChild("AddMemberNoteEditBox"):SetText("")
	wndAdd:FindChild("AddMemberEditBox"):SetText("")
	wndAdd:FindChild("AddMemberEditBox"):SetFocus()

	local wndAddMemberNoteEditBoxLabel = wndAdd:FindChild("AddMemberNoteEditBox"):FindChild("Label")
	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		wndAddMemberNoteEditBoxLabel:SetText(Apollo.GetString("Friends_NoteHeader"))
	else
		wndAddMemberNoteEditBoxLabel:SetText(Apollo.GetString("Friends_MessageHeader"))
	end
end

function FriendsList:OnAccountAddBtn(wndHandler, wndControl)
	local wndAccountAdd = wndControl:FindChild("AccountAddWindow")
	local strAlias = string.format("<T TextColor=\"UI_TextHoloBodyHighlight\">%s</T>", FriendshipLib.GetPersonalStatus().strDisplayName)
	
	wndAccountAdd:FindChild("AddMemberNoteEditBox"):SetText("")
	wndAccountAdd:FindChild("AddMemberByEmailEditBox"):SetText("")
	wndAccountAdd:FindChild("AddMemberEditBox"):SetText("")
	wndAccountAdd:FindChild("AddMemberRealmEditBox"):SetText("")
	wndAccountAdd:FindChild("AddMemberEditBox"):SetFocus()
	wndAccountAdd:FindChild("AccountInviteSentBy"):SetAML("<P TextColor=\"UI_TextHoloBody\">"..String_GetWeaselString(Apollo.GetString("FriendsList_AddAccountFromAlias"), strAlias).."</P>")
end

function FriendsList:OnAddMemberYesClick(wndHandler, wndControl)
	local wndAdd = wndControl:GetParent()
	local strName = wndAdd:FindChild("AddMemberEditBox"):GetText()

	local strAddFriendNote = wndAdd:FindChild("AddMemberNoteEditBox"):GetText() or nil
	local strAddFriendRealm = nil

	if wndAdd:FindChild("AddMemberRealmEditBox") ~= nil then
		wndAdd:FindChild("AddMemberRealmEditBox"):GetText()
	end

	if strName ~= nil and strName ~= "" then
		FriendshipLib.AddByName(ktTypesIntoEnums[self.tWndRefs.wndListContainer:GetData()], strName, strAddFriendRealm, strAddFriendNote)
	end
	wndControl:GetParent():Show(false)
end

function FriendsList:OnAccountAddMemberYesClick(wndHandler, wndControl)
	local wndAdd = self.tWndRefs.wndMain:FindChild("SortContainer:AccountAddBtn:AccountAddWindow")
	local strName = wndAdd:FindChild("AddMemberEditBox"):GetText()

	local strAddFriendNote = wndAdd:FindChild("AddMemberNoteEditBox"):GetText() or nil
	local strAddFriendRealm = nil

	if wndAdd:FindChild("AddMemberRealmEditBox") ~= nil then
		wndAdd:FindChild("AddMemberRealmEditBox"):GetText()
	end
	if strName ~= nil and strName ~= "" then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Account, strName, strAddFriendRealm, strAddFriendNote)

	else

		strName = wndAdd:FindChild("AddMemberByEmailEditBox"):GetText()
		if strName ~= nil and strName ~= "" then
			FriendshipLib.AccountAddByEmail(strName, strAddFriendNote)
		end
	end

	wndControl:GetParent():Show(false)
end

function FriendsList:OnSubCloseBtn(wndHandler, wndControl)
	wndControl:GetParent():Show(false)
end

-- Modify Sub-Window Functions
function FriendsList:OnModifyBtn(wndHandler, wndControl)
	local tFriend = wndControl:GetData()
	if tFriend == nil then
		return
	end

	local wndModify = wndControl:FindChild("ModifyWindow")
	wndModify:SetData(tFriend)

	wndModify:FindChild("RemoveFriendWindow"):SetData(tFriend)

	local nList = self.tWndRefs.wndListContainer:GetData()
	if nList == LuaCodeEnumTabTypes.Suggested then
		wndModify:FindChild("ModifyRemoveBtn"):SetText(Apollo.GetString("Friends_Remove"))
	elseif nList == LuaCodeEnumTabTypes.Friend then
		wndModify:FindChild("ModifyRemoveBtn"):SetText(Apollo.GetString("Friends_Remove"))
	else
		wndModify:FindChild("ModifyRemoveBtn"):SetText(String_GetWeaselString(Apollo.GetString("Friends_RemoveFromList"), ktListNames[nList]))
	end

	wndModify:FindChild("ModifyRemoveBtn"):Enable(nList ~= LuaCodeEnumTabTypes.Suggested)

	-- set up other options; Ignore is exclusive from these in code and doesn't draw on this window
	if tFriend.bFriend == true then
		wndModify:FindChild("ModifyFriendBtn"):SetText(Apollo.GetString("Friends_AlreadyFriend"))
		wndModify:FindChild("ModifyFriendBtn"):Enable(false)
	else
		if nList == LuaCodeEnumTabTypes.Rival and tFriend.nFactionId ~= GameLib.GetPlayerUnit():GetFaction() then
			wndModify:FindChild("ModifyFriendBtn"):SetText(Apollo.GetString("Friends_CantBeFriend"))
			wndModify:FindChild("ModifyFriendBtn"):Enable(false)
		else
			wndModify:FindChild("ModifyFriendBtn"):SetText(Apollo.GetString("Friends_AddToFriends"))
			wndModify:FindChild("ModifyFriendBtn"):Enable(true)
		end
	end

	if tFriend.bRival == true then
		wndModify:FindChild("ModifyRivalBtn"):SetText(Apollo.GetString("Friends_AlreadyRival"))
		wndModify:FindChild("ModifyRivalBtn"):Enable(false)
	else
		wndModify:FindChild("ModifyRivalBtn"):SetText(Apollo.GetString("Friends_AddToRivals"))
		wndModify:FindChild("ModifyRivalBtn"):Enable(true)
	end

	wndModify:Show(true)
end

function FriendsList:OnModifyFriendBtn(wndHandler, wndControl)
	local wndModify = wndControl:GetParent():GetParent()
	local tFriend = wndModify:GetData()

	if tFriend ~= nil then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Friend, tFriend.strCharacterName)
	end

	wndModify:Show(false)
end

function FriendsList:OnModifyRivalBtn(wndHandler, wndControl)
	local wndModify = wndControl:GetParent():GetParent()
	local tFriend = wndModify:GetData()

	if tFriend ~= nil then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Rival, tFriend.strCharacterName)
	end

	wndModify:Show(false)
end

function FriendsList:OnModifyIgnoreBtn(wndHandler, wndControl)
	local wndModify = wndControl:GetParent():GetParent()
	local tFriend = wndModify:GetData()

	if tFriend ~= nil then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Ignore, tFriend.strCharacterName)
	end

	wndModify:Show(false)
end

-- Unignore Sub-Window Functions
function FriendsList:OnUnignoreBtn(wndHandler, wndControl)
	local tFriend = wndControl:GetData()
	local wndUnignore = wndControl:FindChild("UnignoreWindow")
	if tFriend == nil then
		return
	end
	wndUnignore:SetData(tFriend)
	wndUnignore:Show(true)
end

function FriendsList:OnUnignoreConfirmBtn(wndHandler, wndControl)
	local wndUnignore = wndControl:GetParent()
	local tFriend = wndUnignore:GetData()

	if tFriend ~= nil then
		FriendshipLib.Remove(tFriend.nId, FriendshipLib.CharacterFriendshipType_Ignore) -- TODO: flip
	end

	wndUnignore:Show(false)
end

-- Note Sub-Window Functions
function FriendsList:OnNoteBtn(wndHandler, wndControl)
	local tFriend = wndControl:GetData()
	local wndNote = wndControl:FindChild("NoteWindow")
	if tFriend == nil then
		return
	end

	local wndEntry = self:GetFriendshipWindowByFriendId(tFriend.nId)

	local strNote
	if wndEntry:GetName() == "AccountFriendForm" then
		strNote = tFriend.strPrivateNote
	else
		strNote = tFriend.strNote
	end

	wndNote:SetData(tFriend)
	wndNote:FindChild("NoteEditBox"):SetText(strNote or "")

	local strSubmitted = wndNote:FindChild("NoteEditBox"):GetText()
	wndNote:FindChild("NoteEditBox"):SetFocus()
	wndNote:FindChild("NoteEditBox"):SetSel(0, -1)

	wndNote:FindChild("NoteConfirmBtn"):Enable(false)
	wndNote:Show(true)
end

function FriendsList:OnNoteWindowEdit(wndHandler, wndControl, strNewNote)
	local wndNote = wndControl:GetParent()
	local tFriend = wndNote:GetData()
	local strOldNote
	local bValid = false

	local wndEntry = self:GetFriendshipWindowByFriendId(tFriend.nId)

	if wndEntry:GetName() == "AccountFriendForm" then
		strOldNote = tFriend.strPrivateNote
		bValid = strNewNote ~= strOld and GameLib.IsTextValid(strNewNote or "", GameLib.CodeEnumUserText.FriendshipAccountPrivateNote, eProfanityFilter)
	else
		strOldNote = tFriend.strNote
		bValid = strNewNote ~= strOld and GameLib.IsTextValid(strNewNote or "", GameLib.CodeEnumUserText.FriendshipNote, eProfanityFilter)
	end

	wndNote:FindChild("NoteConfirmBtn"):Enable(bValid)

	if wndEntry:GetName() ~= "AccountFriendForm" then
		wndNote:FindChild("NoteEditBox"):SetTextColor(kcrColorOffline)
		if bValid == true then
			wndNote:FindChild("NoteEditBox"):SetTextColor(kcrColorOnline)
		end
	end
end

function FriendsList:OnNoteConfirmBtn(wndHandler, wndControl)
	local wndNote = wndControl:GetParent()
	local tFriend = wndNote:GetData()

	local wndSelectedEntry
	for key, wndFriendEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndFriendEntry:GetData() == tFriend.nId then
			wndSelectedEntry = wndFriendEntry
			break
		end
	end

	if tFriend ~= nil and wndSelectedEntry ~= nil then
		if wndSelectedEntry:GetName() == "AccountFriendForm" then
			FriendshipLib.SetFriendPrivateData(tFriend.nId, wndNote:FindChild("NoteEditBox"):GetText())
		else
			FriendshipLib.SetNote(tFriend.nId, wndNote:FindChild("NoteEditBox"):GetText())
		end
	end

	wndNote:Show(false)
	self.tWndRefs.wndModifyWindow:Show(false)
end

function FriendsList:OnBlockBtn(wndHandler, wndControl)
	local bBlocked = not wndControl:IsChecked() -- art is reversed
	FriendshipLib.SetLock(bBlocked)
end

function FriendsList:OnAccountBlockBtn(wndHandler, wndControl)
	local bBlocked = not wndControl:IsChecked() -- art is reversed

	if bBlocked ~= FriendshipLib.SetPersonalIgnoreStrangersState(bBlocked) then
		wndControl:SetCheck(bBlocked)
	end
end

function FriendsList:OnSelfNoteConfirmBtn( wndHandler, wndControl)
	local wndNote = wndControl:GetParent()

	FriendshipLib.SetPublicNote(wndNote:FindChild("SelfNoteEditBox"):GetText())

	wndNote:Show(false)
end

function FriendsList:OnSelfNoteBtn( wndHandler, wndControl)
	local wndNote = wndControl:FindChild("SelfNoteWindow")

	local strNote
	strNote = FriendshipLib.GetPersonalStatus().strPublicNote

	wndNote:SetData(tFriend)
	wndNote:FindChild("SelfNoteEditBox"):SetText(strNote or "")

	local strSubmitted = wndNote:FindChild("SelfNoteEditBox"):GetText()
	wndNote:FindChild("SelfNoteEditBox"):SetFocus()
	wndNote:FindChild("SelfNoteEditBox"):SetSel(0, -1)

	wndNote:FindChild("SelfNoteConfirmBtn"):Enable(false)
	wndNote:Show(true)
end

function FriendsList:OnSelfNoteWindowEdit( wndHandler, wndControl, strNewNote )
	local wndNote = wndControl:GetParent()
	local tFriend = wndNote:GetData()
	local strOldNote

	strOldNote = FriendshipLib.GetPersonalStatus().strPublicNote

	local bValid = strNewNote ~= strOldNote and GameLib.IsTextValid(strNewNote or "", GameLib.CodeEnumUserText.FriendshipAccountPublicNote, eProfanityFilter)
	wndNote:FindChild("SelfNoteConfirmBtn"):Enable(bValid)
end

function FriendsList:OnNameConfirmBtn( wndHandler, wndControl)
	local wndNote = wndControl:GetParent()

	FriendshipLib.SetPublicDisplayName(wndNote:FindChild("NameEditBox"):GetText())

	wndNote:Show(false)
	local wndModify = self.tWndRefs.wndMain:FindChild("ModifyWindow")
	if wndModify ~= nil then
		wndModify:Show(false)
	end
end

function FriendsList:OnNameWindowEdit( wndHandler, wndControl, strText )
	local wndNote = wndControl:GetParent()
	local strOldName = FriendshipLib.GetPersonalStatus().strDisplayName

	local bValid = strText ~= strOldName and strText ~= "" and GameLib.IsTextValid(strText, GameLib.CodeEnumUserText.FriendshipAccountName, eProfanityFilter)
	wndNote:FindChild("NameConfirmBtn"):Enable(bValid)
end

function FriendsList:OnNameBtn( wndHandler, wndControl)
	local tFriend = wndControl:GetData()
	local wndName = wndControl:FindChild("NameWindow")

	local strName = FriendshipLib.GetPersonalStatus().strDisplayName

	wndName:FindChild("NameEditBox"):SetText(strName or "")

	local strSubmitted = wndName:FindChild("NameEditBox"):GetText()
	wndName:FindChild("NameEditBox"):SetFocus()
	wndName:FindChild("NameEditBox"):SetSel(0, -1)

	wndName:FindChild("NameConfirmBtn"):Enable(false)
	wndName:Show(true)
end

function FriendsList:OnChangeAccountStatusBtn( wndHandler, wndControl)
	local newState = wndControl:GetData()
	local nPresenceState = FriendshipLib.SetPersonalPresenceState(newState)

	if newState ~= nPresenceState then
		self.tWndRefs.wndMain:FindChild("SelfWindowAvailableBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Available)
		self.tWndRefs.wndMain:FindChild("SelfWindowAwaylBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Away)
		self.tWndRefs.wndMain:FindChild("SelfWindowBusyBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Busy)
--		self.tWndRefs.wndMain:FindChild("SelfWindowInvisibleBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Invisible)
	end

end

function FriendsList:OnRemoveFriendConfirmBtn(wndHandler, wndControl)
	local wndConfirm = wndControl:GetParent()
	local tFriend = wndConfirm:GetData()

	local wndSelectedEntry
	for key, wndFriendEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndFriendEntry:GetData() == tFriend.nId then
			wndSelectedEntry = wndFriendEntry
			break
		end
	end

	if tFriend ~= nil and wndSelectedEntry ~= nil then
		if wndSelectedEntry:GetName() == "AccountFriendForm" then
			FriendshipLib.AccountRemove(tFriend.nId)
		else
			FriendshipLib.Remove(tFriend.nId, ktTypesIntoEnums[self.tWndRefs.wndListContainer:GetData()]) -- TODO:flip
		end
	end

	wndConfirm:Show(false)
	self.tWndRefs.wndModifyWindow:Show(false)
end

function FriendsList:OnStatusDropdownBtn( wndHandler, wndControl)
	local nPresenceState = FriendshipLib.GetPersonalStatus().nPresenceState

	self.tWndRefs.wndMain:FindChild("SelfWindowAvailableBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Available)
	self.tWndRefs.wndMain:FindChild("SelfWindowAwaylBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Away)
	self.tWndRefs.wndMain:FindChild("SelfWindowBusyBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Busy)
--	self.tWndRefs.wndMain:FindChild("SelfWindowInvisibleBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Invisible)
end

function FriendsList:OnStatusDropdownOptionBtn(wndHandler, wndControl)
	local newState = wndControl:GetData()
	local nPresenceState = FriendshipLib.SetPersonalPresenceState(newState)

	if newState ~= nPresenceState then
		self.tWndRefs.wndMain:FindChild("SelfWindowAvailableBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Available)
		self.tWndRefs.wndMain:FindChild("SelfWindowAwaylBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Away)
		self.tWndRefs.wndMain:FindChild("SelfWindowBusyBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Busy)
--		self.tWndRefs.wndMain:FindChild("SelfWindowInvisibleBtn"):SetCheck(nPresenceState == FriendshipLib.AccountPresenceState_Invisible)
	end

	self.tWndRefs.wndMain:FindChild("StatusDropdownArt"):Show(false)
	self:UpdateControls()
end

function FriendsList:OnEventGeneric_ConfirmRemoveAccountFriend(nFriendId)
	if self.wndConfirmRemoveAccountFriend == nil or not self.wndConfirmRemoveAccountFriend:IsValid() then
		self.wndConfirmRemoveAccountFriend = Apollo.LoadForm(self.xmlDoc, "ConfirmRemoveAccountFriendForm", nil, self)
	end

	self.wndConfirmRemoveAccountFriend:Invoke()
	self.wndConfirmRemoveAccountFriend:SetData(nFriendId)
end

function FriendsList:OnFriendSortToggle(wndHandler, wndControl, eMouseButton)
	local wndName = wndControl:GetName()
	local bDesc = true
	local eCurrentTab = self.tWndRefs.wndListContainer:GetData()
	local tLastSort = self.arLastSorts[eCurrentTab]
	local strLastSort = tLastSort[2]
	
	if strLastSort == wndName then
		bDesc = true
		self.arLastSorts[eCurrentTab] = {wndName, wndName.."2"}
	elseif strLastSort == wndName.."2" then
		self.tWndRefs.wndListContainer:ArrangeChildrenVert(0, function(wndLeft, wndRight)
			if eCurrentTab ~= LuaCodeEnumTabTypes.Friend then
				return self:SortDefaultOther(wndLeft, wndRight)
			else
				return self:SortDefaultFriends(wndLeft, wndRight)
			end
		end)
		self.arLastSorts[eCurrentTab] = {wndName, "Special"}
		wndControl:SetCheck(false)
		return
	else
		bDesc = false
		self.arLastSorts[eCurrentTab] = {wndName, wndName}
	end

	self.tWndRefs.wndListContainer:ArrangeChildrenVert(0, function(wndLeft, wndRight)
		if ktSortButtonToFuncMap[wndName] ~= nil then
			return self[ktSortButtonToFuncMap[wndName]](self, bDesc, wndLeft, wndRight)
		end
	end)
end

function FriendsList:PerformLastSort()
	local eCurrentTab = self.tWndRefs.wndListContainer:GetData()
	local tLastSort = self.arLastSorts[eCurrentTab]
	local strLastSort = tLastSort[2]
	local wndName = tLastSort[1] or ""
	local bDesc = true
	
	if strLastSort == wndName.."2" then
		bDesc = true
	elseif strLastSort == "Special" then
		self.tWndRefs.wndListContainer:ArrangeChildrenVert(0, function(wndLeft, wndRight)
			if eCurrentTab ~= LuaCodeEnumTabTypes.Friend then
				return self:SortDefaultOther(wndLeft, wndRight)
			else
				return self:SortDefaultFriends(wndLeft, wndRight)
			end
		end)
		if wndName ~= "" then
			self.tWndRefs.arHeaders[eCurrentTab]:FindChild(wndName):SetCheck(false)
		end
		return
	else
		bDesc = false
	end

	if wndName ~= "" then
		self.tWndRefs.arHeaders[eCurrentTab]:FindChild(wndName):SetCheck(true)
	end
	self.tWndRefs.wndListContainer:ArrangeChildrenVert(0, function(wndLeft, wndRight)
		if ktSortButtonToFuncMap[wndName] ~= nil then
			return self[ktSortButtonToFuncMap[wndName]](self, bDesc, wndLeft, wndRight)
		end
	end)
end

function FriendsList:SortDefaultOther(wndLeft, wndRight)
	return self:SortName(false, wndLeft, wndRight)
end

function FriendsList:SortDefaultFriends(wndLeft, wndRight)
	local strLeft = wndLeft:GetName()
	local strRight = wndRight:GetName()
	if strLeft == "AccountFriendInviteForm"
		or strRight == "AccountFriendInviteForm" 
		or strLeft == "FriendInviteForm" 
		or strRight == "FriendInviteForm" then
		
		return self:SortType(false, wndLeft, wndRight)
	end
	
	local idLeftFriend = wndLeft:GetData()
	local friendLeft = FriendshipLib.GetAccountById(idLeftFriend)
	
	local idRightFriend = wndRight:GetData()
	local friendRight = FriendshipLib.GetAccountById(idRightFriend)
	
	if friendLeft ~= nil and friendRight == nil then
		return true
	elseif friendLeft == nil and friendRight ~= nil then
		return false
	elseif friendLeft ~= nil and friendRight ~= nil then
		if friendLeft.fLastOnline == friendRight.fLastOnline then
			return self:SortName(false, wndLeft, wndRight)
		end
		
		local nLastOnlineLeft = friendLeft.fLastOnline or 0
		local nLastOnlineRight = friendRight.fLastOnline or 0
		
		return nLastOnlineLeft < nLastOnlineRight
	end
	
	friendLeft = FriendshipLib.GetById(idLeftFriend)
	friendRight = FriendshipLib.GetById(idRightFriend)
	
	local nLastOnlineLeft = friendLeft.fLastOnline or 0
	local nLastOnlineRight = friendRight.fLastOnline or 0
	
	if nLastOnlineLeft == nLastOnlineRight then
		return self:SortName(false, wndLeft, wndRight)
	end
	
	return nLastOnlineLeft < nLastOnlineRight
end

function FriendsList:SortType(bDesc, wndLeft, wndRight)
	local strLeft = wndLeft:GetName()
	local strRight = wndRight:GetName()

	if strLeft == strRight then
		return self:SortName(bDesc, wndLeft, wndRight)
	end
	
	if bDesc then
		return ktWindowNameSortRanking[strLeft] > ktWindowNameSortRanking[strRight]
	end
	return ktWindowNameSortRanking[strLeft] < ktWindowNameSortRanking[strRight]
end

function FriendsList:SortName(bDesc, wndLeft, wndRight)
	local strLeft = wndLeft:FindChild("Name"):GetText()
	local strRight = wndRight:FindChild("Name"):GetText()

	if bDesc then
		return strLeft > strRight
	end
	return strLeft < strRight
end

function FriendsList:SortLevel(bDesc, wndLeft, wndRight)
	local strNameLeft = wndLeft:GetName()
	local strNameRight = wndRight:GetName()
	
	local bInviteLeft = strNameLeft == "AccountFriendInviteForm" or strNameLeft == "FriendInviteForm"
	local bInviteRight = strNameRight == "AccountFriendInviteForm" or strNameRight == "FriendInviteForm"
	
	if bInviteLeft ~= bInviteRight then
		return bInviteLeft
	end
	if bInviteLeft and bInviteLeft == bInviteRight then
		return self:SortName(not bDesc, wndLeft, wndRight)
	end
	
	local idLeft = wndLeft:GetData()
	local idRight = wndRight:GetData()
	
	local nLevelLeft = 0
	local nLevelRight = 0
	
	local friendLeft = FriendshipLib.GetAccountById(idLeft)
	if friendLeft == nil then
		friendLeft = FriendshipLib.GetById(idLeft)
		if friendLeft ~= nil then
			nLevelLeft = friendLeft.nLevel or 0
		end
	else
		if friendLeft.fLastOnline == 0 then
			nLevelLeft = friendLeft.arCharacters[1].nLevel or 0
		end
	end
	local friendRight = FriendshipLib.GetAccountById(idRight)
	if friendRight == nil then
		friendRight = FriendshipLib.GetById(idRight)
		if friendRight ~= nil then
			nLevelRight = friendRight.nLevel or 0
		end
	else
		if friendRight.fLastOnline == 0 then
			nLevelRight = friendRight.arCharacters[1].nLevel or 0
		end
	end
	
	if nLevelLeft == nLevelRight then
		return self:SortName(bDesc, wndLeft, wndRight)
	end
	
	if bDesc then
		return nLevelLeft > nLevelRight
	end
	return nLevelLeft < nLevelRight
end

function FriendsList:SortClass(bDesc, wndLeft, wndRight)
	local strNameLeft = wndLeft:GetName()
	local strNameRight = wndRight:GetName()
	
	local bInviteLeft = strNameLeft == "AccountFriendInviteForm" or strNameLeft == "FriendInviteForm"
	local bInviteRight = strNameRight == "AccountFriendInviteForm" or strNameRight == "FriendInviteForm"
	
	if bInviteLeft ~= bInviteRight then
		return bInviteLeft
	end
	if bInviteLeft and bInviteLeft == bInviteRight then
		return self:SortName(not bDesc, wndLeft, wndRight)
	end
	
	local idLeft = wndLeft:GetData()
	local idRight = wndRight:GetData()
	
	local nClassLeft = -1
	local nClassRight = -1
	
	local friendLeft = FriendshipLib.GetAccountById(idLeft)
	if friendLeft == nil then
		friendLeft = FriendshipLib.GetById(idLeft)
		if friendLeft ~= nil then
			nClassLeft = friendLeft.nClassId or -1 
		end
	else
		if friendLeft.fLastOnline == 0 then
			nClassLeft = friendLeft.arCharacters[1].nClassId or -1
		end
	end
	local friendRight = FriendshipLib.GetAccountById(idRight)
	if friendRight == nil then
		friendRight = FriendshipLib.GetById(idRight)
		if friendRight ~= nil then
			nClassRight = friendRight.nClassId or -1
		end
	else
		if friendRight.fLastOnline == 0 then
			nClassRight = friendRight.arCharacters[1].nClassId or -1
		end
	end
	
	if nClassLeft == nClassRight then
		return self:SortName(bDesc, wndLeft, wndRight)
	end
	
	if bDesc then
		return (ktClass[nClassLeft] or "") < (ktClass[nClassRight] or "")
	end
	return (ktClass[nClassLeft] or "") > (ktClass[nClassRight] or "")
end

function FriendsList:SortPath(bDesc, wndLeft, wndRight)
	local strNameLeft = wndLeft:GetName()
	local strNameRight = wndRight:GetName()
	
	local bInviteLeft = strNameLeft == "AccountFriendInviteForm" or strNameLeft == "FriendInviteForm"
	local bInviteRight = strNameRight == "AccountFriendInviteForm" or strNameRight == "FriendInviteForm"
	
	if bInviteLeft ~= bInviteRight then
		return bInviteLeft
	end
	if bInviteLeft and bInviteLeft == bInviteRight then
		return self:SortName(not bDesc, wndLeft, wndRight)
	end

	local idLeft = wndLeft:GetData()
	local idRight = wndRight:GetData()
	
	local nPathLeft = -1
	local nPathRight = -1
	
	local friendLeft = FriendshipLib.GetAccountById(idLeft)
	if friendLeft == nil then
		friendLeft = FriendshipLib.GetById(idLeft)
		if friendLeft ~= nil then
			nPathLeft = friendLeft.nPathId or -1
		end
	else
		if friendLeft.fLastOnline == 0 then
			nPathLeft = friendLeft.arCharacters[1].nPathId or -1
		end
	end
	local friendRight = FriendshipLib.GetAccountById(idRight)
	if friendRight == nil then
		friendRight = FriendshipLib.GetById(idRight)
		if friendRight ~= nil then
			nPathRight = friendRight.nPathId or -1
		end
	else
		if friendRight.fLastOnline == 0 then
			nPathRight = friendRight.arCharacters[1].nPathId or -1
		end
	end
	
	if nPathLeft == nPathRight then
		return self:SortName(bDesc, wndLeft, wndRight)
	end
	
	if bDesc then
		return (ktPath[nPathLeft] or "") < (ktPath[nPathRight] or "")
	end
	return (ktPath[nPathLeft] or "") > (ktPath[nPathRight] or "")
end

function FriendsList:SortStatus(bDesc, wndLeft, wndRight)
	local strLeft = wndLeft:GetName()
	local strRight = wndRight:GetName()
	
	local idLeft = wndLeft:GetData()
	local idRight = wndRight:GetData()
	
	local bInviteLeft = strLeft == "AccountFriendInviteForm" or strLeft == "FriendInviteForm"
	local bInviteRight = strRight == "AccountFriendInviteForm" or strRight == "FriendInviteForm"
	
	if bInviteLeft ~= bInviteRight then
		return bInviteLeft
	end
	if bInviteLeft and bInviteLeft == bInviteRight then
		local inviteLeft = FriendshipLib.GetAccountInviteById(idLeft)
		if inviteLeft == nil then
			inviteLeft = FriendshipLib.GetInviteById(idLeft)
		end
		local inviteRight = FriendshipLib.GetAccountInviteById(idRight)
		if inviteRight == nil then
			inviteRight = FriendshipLib.GetInviteById(idRight)
		end
		
		local nDaysLeft = inviteLeft.fDaysUntilExpired or 0
		local nDaysRight = inviteRight.fDaysUntilExpired or 0
		
		if nDaysLeft == nDaysRight then
			return self:SortName(bDesc, wndLeft, wndRight)
		end
		
		if bDesc then
			return nDaysLeft > nDaysRight
		end
		return nDaysLeft < nDaysRight
	end
	
	local friendLeft = FriendshipLib.GetAccountById(idLeft)
	if friendLeft == nil then
		friendLeft = FriendshipLib.GetById(idLeft)
	end
	local friendRight = FriendshipLib.GetAccountById(idRight)
	if friendRight == nil then
		friendRight = FriendshipLib.GetById(idRight)
	end
	
	local nLastOnlineLeft = friendLeft.fLastOnline or 0
	local nLastOnlineRight = friendRight.fLastOnline or 0
	
	if nLastOnlineLeft == nLastOnlineRight then
		return self:SortName(bDesc, wndLeft, wndRight)
	end
	
	if bDesc then
		return nLastOnlineLeft > nLastOnlineRight
	end
	return nLastOnlineLeft < nLastOnlineRight
end

function FriendsList:SortNote(bDesc, wndLeft, wndRight)
	local strNameLeft = wndLeft:GetName()
	local strNameRight = wndRight:GetName()
	
	local bInviteLeft = strNameLeft == "AccountFriendInviteForm" or strNameLeft == "FriendInviteForm"
	local bInviteRight = strNameRight == "AccountFriendInviteForm" or strNameRight == "FriendInviteForm"
	
	if bInviteLeft ~= bInviteRight then
		return bInviteLeft
	end

	local bLeft = wndLeft:FindChild("NoteIcon"):IsShown()
	local bRight = wndRight:FindChild("NoteIcon"):IsShown()
	
	if bLeft == bRight then
		return self:SortName(bDesc, wndLeft, wndRight)
	end
	
	return bDesc ~= bLeft
end


-----------------------------------------------------------------------------------------------
-- FEEDBACK WINDOW
-----------------------------------------------------------------------------------------------

function FriendsList:OnFriendshipResult(strName, eResult)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	local strMessage = ktFriendshipResult[eResult] or String_GetWeaselString(Apollo.GetString("Friends_UnknownResult"), eResult)
	if self.tWndRefs.wndMain:IsShown() then
		-- (Re)start the timer and show the window. We're not queuing these since they come as results of direct action
		self.tWndRefs.wndMain:FindChild("MessageText"):SetText(strMessage)
		self.tWndRefs.wndMain:FindChild("MessageText"):Show(true)
		Apollo.StopTimer("Friends_MessageDisplayTimer")
		Apollo.CreateTimer("Friends_MessageDisplayTimer", 4, false)
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, String_GetWeaselString(Apollo.GetString("Friends_PreMessage"), strMessage), "")
	end
end

function FriendsList:OnMessageDisplayTimer()
	if self.tWndRefs.wndMain:FindChild("MessageText") then
		self.tWndRefs.wndMain:FindChild("MessageText"):Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Invitation Pop-Up
-----------------------------------------------------------------------------------------------

function FriendsList:OnFriendshipRequest(tRequest)
	self.wndRequest:FindChild("PlayerName"):SetText(tRequest.strCharacterName)
	self.wndRequest:FindChild("PathIcon"):SetSprite(ktPathIcon[tRequest.nPathId])
	self.wndRequest:FindChild("ClassIcon"):SetSprite(ktClassIcon[tRequest.nClassId])
	self.wndRequest:FindChild("PlayerLevel"):SetText(tRequest.nLevel)
	self.wndRequest:FindChild("Controls_Recieved"):Show(true, true)
	self.wndRequest:FindChild("Controls_Accept"):Show(false, true)
	self.wndRequest:FindChild("Controls_Reject"):Show(false, true)
	self.wndRequest:SetData(tRequest.nId)
	self.wndRequest:Show( true )
end

-----------------------------------------------------------------------------------------------
-- Friendslist OnFriendshipRequestWithdrawn
-----------------------------------------------------------------------------------------------

function FriendsList:OnFriendshipRequestWithdrawn(tRequest, eResult)
	self.wndRequest:Show(false)

	local strMessage = String_GetWeaselString(Apollo.GetString("Friends_RequestWithdrawn"), tRequest.strCharacterName)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strMessage, "")

	self:OnFriendshipResult( "", eResult )
end

---------------------------------------------------------------------------------------------------
-- FriendRequestPopup Functions
---------------------------------------------------------------------------------------------------

function FriendsList:OnButtonInitialYes(wndHandler, wndControl)
	local wndInvite = wndControl:GetParent():GetParent()

	wndInvite:FindChild("Controls_Recieved"):Show(false, true)
	wndInvite:FindChild("Controls_Accept"):Show(true)
	wndInvite:FindChild("Controls_Reject"):Show(false, true)
end

function FriendsList:OnButtonInitialNo(wndHandler, wndControl)
	local wndInvite = wndControl:GetParent():GetParent()

	wndInvite:FindChild("Controls_Recieved"):Show(false, true)
	wndInvite:FindChild("Controls_Accept"):Show(false, true)
	wndInvite:FindChild("Controls_Reject"):Show(true)
end

function FriendsList:OnAccept( wndHandler, wndControl)
	local wndInvite = wndControl:GetParent():GetParent()

	FriendshipLib.RespondToInvite(wndInvite:GetData(), FriendshipLib.FriendshipResponse_Mutual)
end

function FriendsList:OnOneWay( wndHandler, wndControl)
	local wndInvite = wndControl:GetParent():GetParent()

	FriendshipLib.RespondToInvite(wndInvite:GetData(), FriendshipLib.FriendshipResponse_Accept)
end

function FriendsList:OnDecline( wndHandler, wndControl)
	local wndInvite = wndControl:GetParent():GetParent()

	FriendshipLib.RespondToInvite(wndInvite:GetData(), FriendshipLib.FriendshipResponse_Decline)
end

function FriendsList:OnIgnore( wndHandler, wndControl)
	local wndInvite = wndControl:GetParent():GetParent()

	FriendshipLib.RespondToInvite(wndInvite:GetData(), FriendshipLib.FriendshipResponse_Ignore)
end

function FriendsList:OnInviteClose(wndHandler, wndControl)
	self.wndRequest:Close()
end

---------------------------------------------------------------------------------------------------
-- Account Friend Functions
---------------------------------------------------------------------------------------------------

function FriendsList:OnAccountFriendInviteBtn(wndHandler, wndControl)
    local tInviteId = wndControl:GetParent():GetData()
	if tInviteId == nil then
		return false
	end

	for key, wndInviteEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		wndInviteEntry:FindChild("FriendBtn"):SetCheck(wndInviteEntry:GetData() == tInviteId)
	end

	FriendshipLib.AccountInviteMarkSeen(tInviteId)
	Event_FireGenericEvent("EventGeneric_FriendInviteSeen", tInviteId)

	self:HelperDrawMemberWindowAccountFriendInviteRequest(wndControl:GetParent(), FriendshipLib.GetAccountInviteById(tInviteId))

	if self.wndSelectedFriend then
		self.wndSelectedFriend:SetCheck(false)
	end
	
	self.wndSelectedFriend = wndControl
	
	self:UpdateControls()
end

function FriendsList:OnAccountFriendInviteBtnUncheck(wndHandler, wndControl)
	self.wndSelectedFriend = nil
	self:UpdateControls()
end

function FriendsList:OnAcceptAccountFriendRequest(wndHandler, wndControl)
	local wndInvite = wndControl:GetParent()
    local tInviteId = wndInvite:GetData()
    if tInviteId ~= nil then
        FriendshipLib.AccountInviteRespond(tInviteId, true)
    end

	self:UpdateControls()
end

function FriendsList:OnRejectAccountFriendRequest(wndHandler, wndControl)
	local wndInvite = wndControl:GetParent()
    local tInviteId = wndInvite:GetData()
    if tInviteId ~= nil then
        FriendshipLib.AccountInviteRespond(tInviteId, false)
    end

	self:UpdateControls()
end

function FriendsList:OnFriendshipInvitesRecieved(tInviteList)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	for idx, tInvite in pairs(tInviteList) do
		self.arInvites[tInvite.nId] = tInvite
		-- We only want to add the invite to the window if we're on the Contacts tab
		if self.tWndRefs.wndMain:FindChild("FriendTabBtn1"):IsChecked() then
			self:HelperAddOrUpdateMemberWindow(tInvite.nId, tInvite)
		end
	end

	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then return end

	self:PerformLastSort()
	self:UpdateControls()
end

function FriendsList:OnFriendshipInviteRemoved(nId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	self.arInvites[nId] = nil

	for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndPlayerEntry:GetData() == nId then
			wndPlayerEntry:Destroy()
		end
	end

	if not self.tWndRefs.wndMain:IsShown() then
		return
	end
	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	self:PerformLastSort()
	self:UpdateControls()
end

-----------------------------------------------------------------------------------------------
-- Account Friend Events
-----------------------------------------------------------------------------------------------

function FriendsList:OnFriendshipAccountInvitesRecieved(tInviteList)
	for key, tInvite in pairs(tInviteList) do
		self.arAccountInvites[tInvite.nId] = tInvite
		self:HelperAddOrUpdateMemberWindow(tInvite.nId, tInvite)
	end

	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	self:PerformLastSort()
	self:UpdateControls()
end

function FriendsList:OnFriendshipAccountInviteRemoved(nId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	self.arAccountInvites[nId] = nil

	for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndPlayerEntry:GetData() == nId then
			wndPlayerEntry:Destroy()
		end
	end

	if not self.tWndRefs.wndMain:IsShown() then
		return
	end
	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	self:PerformLastSort()
	self:UpdateControls()
end

function FriendsList:OnFriendshipAccountFriendsRecieved(tFriendAccountList)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	for idx, tAccountFriend in ipairs(tFriendAccountList) do
		self.arAccountFriends[tAccountFriend.nId] = tAccountFriend
		self:HelperAddOrUpdateMemberWindow(tAccountFriend.nId, tAccountFriend)
	end

	if not self.tWndRefs.wndMain:IsShown() then
		return
	end
	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	self:PerformLastSort()
	self:UpdateControls()
end

function FriendsList:OnFriendshipAccountFriendRemoved(nId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsShown() then
		return
	end

	self.arAccountFriends[nId] = nil

	if not self.tWndRefs.wndMain:IsShown() then
		return
	end
	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	local wndPlayerEntry = self:GetFriendshipWindowByFriendId(nId)
	if wndPlayerEntry == nil then
		return
	end
	wndPlayerEntry:Destroy()

	self:PerformLastSort()
	self:UpdateControls()
end

function FriendsList:OnFriendshipAccountDataUpdate(nId)
	self:FriendshipAccountUpdate(nId)
end

function FriendsList:OnFriendshipAccountCharacterLevelUpdate(nId)
	self:FriendshipAccountUpdate(nId)
	-- TODO We will want to hook up something here to notify the player a friend just level'ed up
end

function FriendsList:OnFriendshipAccountPersonalStatusUpdate()
	self:UpdateControls()
end

-----------------------------------------------------------------------------------------------
-- Account Friend Operations
-----------------------------------------------------------------------------------------------

function FriendsList:GetFriendshipWindowByFriendId(nId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndListContainer then
		return
	end
	for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		if wndPlayerEntry:GetData() == nId then
			return wndPlayerEntry
		end
	end

	return nil
end

function FriendsList:FriendshipAccountUpdate(nId)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	if not self.tWndRefs.wndListContainer or self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	local wndPlayerEntry = self:GetFriendshipWindowByFriendId(nId)
	if wndPlayerEntry == nil then
		return
	end

	local tAccountFriendship = FriendshipLib.GetAccountById(nId)
	if tAccountFriendship ~= nil then
		self.arAccountFriends[nId] = tAccountFriendship
		self:HelperAddOrUpdateMemberWindow(nId, tAccountFriendship)
		self:UpdateControls()
	else
		self.arAccountFriends[nId] = tAccountFriendship
		wndPlayerEntry:Destroy()
	end

	self:PerformLastSort()
end

---------------------------------------------------------------------------------------------------
-- AccountFriendForm Functions
---------------------------------------------------------------------------------------------------

function FriendsList:OnUpdateLastOnlineTimer()
 	if self.tWndRefs.wndListContainer:GetData() ~= LuaCodeEnumTabTypes.Friend then
		return
	end

	for key, wndPlayerEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		local nFriendId = wndPlayerEntry:GetData()
		if nFriendId ~= nil then
			local tFriend = nil

			local strWindowName = wndPlayerEntry:GetName()
			if strWindowName == "FriendForm" then
				tFriend = FriendshipLib.GetById(nFriendId)
			elseif strWindowName == "AccountFriendForm" then
				tFriend = FriendshipLib.GetAccountById(nFriendId)
			elseif strWindowName == "AccountFriendInviteForm" then
				tFriend = FriendshipLib.GetAccountInviteById(nFriendId)
			elseif strWindowName == "FriendInviteForm" then
				tFriend = FriendshipLib.GetInviteById(nFriendId)
			end

			if tFriend ~= nil then
				self:HelperAddOrUpdateMemberWindow(nFriendId, tFriend)
			else
				Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("Friends_CouldNotFindFriend"), nFriendId))
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- FriendInviteForm Functions
---------------------------------------------------------------------------------------------------

function FriendsList:OnFriendInviteBtn( wndHandler, wndControl)
	local tInviteId = wndControl:GetParent():GetData()
	if tInviteId == nil then
		return false
	end

	for key, wndInviteEntry in pairs(self.tWndRefs.wndListContainer:GetChildren()) do
		wndInviteEntry:FindChild("FriendBtn"):SetCheck(wndInviteEntry:GetData() == tInviteId)
	end

	FriendshipLib.InviteMarkSeen(tInviteId)
	Event_FireGenericEvent("EventGeneric_FriendInviteSeen", tInviteId)

	self:HelperDrawMemberWindowFriendInviteRequest(wndControl:GetParent(), FriendshipLib.GetInviteById(tInviteId))

	if self.wndSelectedFriend then
		self.wndSelectedFriend:SetCheck(false)
	end
	
	self.wndSelectedFriend = wndControl
	
	self:UpdateControls()
end

function FriendsList:OnFriendInviteBtnUncheck(wndHandler, wndControl)
	self.wndSelectedFriend = nil
	self:UpdateControls()
end

---------------------------------------------------------------------------------------------------
-- ConfirmRemoveAccountFriendForm Functions
---------------------------------------------------------------------------------------------------

function FriendsList:OnConfirmRemoveAccountFriendFormNo( wndHandler, wndControl)
	local wndParent = wndControl:GetParent()
	if wndParent == nil then
		return
	end

	wndParent:Show(false)
	wndParent:Destroy()
end

function FriendsList:OnConfirmRemoveAccountFriendFormYes( wndHandler, wndControl)
	local wndParent = wndControl:GetParent()
	if wndParent == nil then
		return
	end

	FriendshipLib.AccountRemove(wndParent:GetData())
	wndParent:Show(false)
	wndParent:Destroy()
end


-----------------------------------------------------------------------------------------------
-- FriendsList Text Validation
-----------------------------------------------------------------------------------------------
function FriendsList:OnAddPlayerNoteChanging(wndControl, wndHandler, strText)
	local strFilteredString = string.sub(strText, 1 , 32)
	wndControl:SetText(strFilteredString)
	wndControl:SetSel(string.len(strFilteredString))
end

function FriendsList:FactoryProduce(wndParent, strFormName, tObject)
	-- Temporary hack so the parent doesn't return itself with FindChildByUserData
	local oData = wndParent:GetData()
	wndParent:SetData(nil)
	
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	wndParent:SetData(oData)
	
	return wndNew
end

-----------------------------------------------------------------------------------------------
-- FriendsList Instance
-----------------------------------------------------------------------------------------------
local FriendsListInst = FriendsList:new()
FriendsListInst:Init()
