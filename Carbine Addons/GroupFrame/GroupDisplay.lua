-----------------------------------------------------------------------------------------------
-- Client Lua Script for GroupDisplayOptions
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "GroupLib"
require "GameLib"
require "Tooltip"
require "PlayerPathLib"
require "ChatSystemLib"
require "MatchingGame"

local GroupDisplay = {}

local ktInvitePathIcons = -- NOTE: ID's are zero-indexed in CPP
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= "Icon_Windows_UI_CRB_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "Icon_Windows_UI_CRB_Colonist",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "Icon_Windows_UI_CRB_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "Icon_Windows_UI_CRB_Explorer"
}

local ktSmallInvitePathIcons = -- NOTE: ID's are zero-indexed in CPP
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= "Icon_Windows_UI_CRB_Soldier_Small",
	[PlayerPathLib.PlayerPathType_Settler] 		= "Icon_Windows_UI_CRB_Colonist_Small",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "Icon_Windows_UI_CRB_Scientist_Small",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "Icon_Windows_UI_CRB_Explorer_Small"
}

local ktInviteClassIcons =
{
	[GameLib.CodeEnumClass.Warrior] 			= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 			= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Esper]				= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic]				= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 			= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Spellslinger]	 	= "Icon_Windows_UI_CRB_Spellslinger"
}

local ktIdToClassTooltip =
{
	[GameLib.CodeEnumClass.Esper] 			= "CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "ClassStalker",
	[GameLib.CodeEnumClass.Warrior] 		= "CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "CRB_Spellslinger",
}

local karMessageIconString =
{
	"MessageIcon_Sent",
	"MessageIcon_Deny",
	"MessageIcon_Accept",
	"MessageIcon_Joined",
	"MessageIcon_Left",
	"MessageIcon_Promoted",
	"MessageIcon_Kicked",
	"MessageIcon_Disbanded",
	"MessageIcon_Error"
}

local ktMessageIcon =
{
	Sent 		= 1,
	Deny 		= 2,
	Accept 		= 3,
	Joined 		= 4,
	Left 		= 5,
	Promoted 	= 6,
	Kicked 		= 7,
	Disbanded 	= 8,
	Error 		= 9
}

local ktActionResultStrings =
{
	[GroupLib.ActionResult.LeaveFailed] 					= {strMsg = Apollo.GetString("Group_LeaveFailed"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.DisbandFailed]					= {strMsg = Apollo.GetString("Group_DisbandFailed"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.KickFailed] 						= {strMsg = Apollo.GetString("Group_KickFailed"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.PromoteFailed] 					= {strMsg = Apollo.GetString("Group_PromoteFailed"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.FlagsFailed] 					= {strMsg = Apollo.GetString("Group_FlagsFailed"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.MemberFlagsFailed] 				= {strMsg = Apollo.GetString("Group_MemberFlagsFailed"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.NotInGroup] 						= {strMsg = Apollo.GetString("Group_NotInGroup"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.ChangeSettingsFailed]			= {strMsg = Apollo.GetString("Group_SettingsFailed"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.MentoringInvalidMentor] 			= {strMsg = Apollo.GetString("Group_MentorInvalid"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.MentoringInvalidMentee] 			= {strMsg = Apollo.GetString("Group_MenteeInvalid"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.InvalidGroup] 					= {strMsg = Apollo.GetString("Group_InvalidGroup"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.MentoringSelf] 					= {strMsg = Apollo.GetString("Group_MentorSelf"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.ReadyCheckFailed] 				= {strMsg = Apollo.GetString("Group_ReadyCheckFailed"), 		strIcon = ktMessageIcon.Accept},
	[GroupLib.ActionResult.MentoringNotAllowed] 			= {strMsg = Apollo.GetString("Group_MentorDisabled"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.MarkingNotPermitted] 			= {strMsg = Apollo.GetString("Group_CantMark"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.InvalidMarkIndex] 				= {strMsg = Apollo.GetString("Group_InvalidMarkIndex"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.InvalidMarkTarget] 				= {strMsg = Apollo.GetString("Group_InvalidMarkTarget"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.MentoringInCombat] 				= {strMsg = Apollo.GetString("Group_MentoringInCombat"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.MentoringLowestLevel]			= {strMsg = Apollo.GetString("Group_LowestLevel"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.ActionResult.AlreadyInGroupInstance]			= {strMsg = Apollo.GetString("AlreadyInGroupInstance"), 		strIcon = ktMessageIcon.Error},
}

local ktInviteResultStrings =
{
	[GroupLib.Result.Sent] 					= {strMsg = Apollo.GetString("GroupInviteSent"), 				strIcon = ktMessageIcon.Sent},
	[GroupLib.Result.NoPermissions] 		= {strMsg = Apollo.GetString("GroupInviteNoPermission"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.Result.PlayerNotFound]		= {strMsg = Apollo.GetString("GroupPlayerNotFound"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.Result.RealmNotFound] 		= {strMsg = Apollo.GetString("GroupRealmNotFound"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Grouped] 				= {strMsg = Apollo.GetString("GroupPlayerAlreadyGrouped"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Pending] 				= {strMsg = Apollo.GetString("GroupInvitePending"), 			strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.ExpiredInviter] 		= {strMsg = Apollo.GetString("GroupInviteExpired"), 			strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.ExpiredInvitee] 		= {strMsg = Apollo.GetString("GroupYourInviteExpired"), 		strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.InvitedYou] 			= {strMsg = Apollo.GetString("CRB_GroupInviteAlreadyInvited"), 	strIcon = ktMessageIcon.Error},
	[GroupLib.Result.IsInvited] 			= {strMsg = Apollo.GetString("Group_AlreadyInvited"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.Result.NoInvitingSelf] 		= {strMsg = Apollo.GetString("Group_NoSelfInvite"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Full] 					= {strMsg = Apollo.GetString("Group_GroupFull"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.RoleFull] 				= {strMsg = Apollo.GetString("Group_RoleFull"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Declined] 				= {strMsg = Apollo.GetString("GroupInviteDeclined"), 			strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.Accepted] 				= {strMsg = Apollo.GetString("Group_InviteAccepted"), 			strIcon = ktMessageIcon.Accept},
	[GroupLib.Result.NotAcceptingRequests] 	= {strMsg = Apollo.GetString("Group_NotAcceptingRequests"), 	strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.Busy]				 	= {strMsg = Apollo.GetString("Group_Busy"), 					strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.PrivilegeRestricted] 	= {strMsg = Apollo.GetString("Group_Invite_PrivilegeRestricted"),strIcon = ktMessageIcon.Deny},
}

local ktJoinRequestResultStrings =
{
	[GroupLib.Result.Sent] 					= {strMsg = Apollo.GetString("GroupJoinRequestSent"), 				strIcon = ktMessageIcon.Sent},
	[GroupLib.Result.PlayerNotFound]		= {strMsg = Apollo.GetString("GroupPlayerNotFound"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.RealmNotFound] 		= {strMsg = Apollo.GetString("GroupRealmNotFound"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Grouped] 				= {strMsg = Apollo.GetString("GroupJoinRequestGroup"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Pending] 				= {strMsg = Apollo.GetString("GroupJoinRequestPending"), 			strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.ExpiredInviter] 		= {strMsg = Apollo.GetString("GroupJoinRequestExpired"), 			strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.ExpiredInvitee] 		= {strMsg = Apollo.GetString("GroupYourJoinRequestExpired"), 		strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.InvitedYou] 			= {strMsg = Apollo.GetString("CRB_GroupJoinAlreadyRequested"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.Result.NoInvitingSelf] 		= {strMsg = Apollo.GetString("Group_NoSelfJoinRequest"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Full] 					= {strMsg = Apollo.GetString("Group_GroupFull"), 					strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Declined] 				= {strMsg = Apollo.GetString("GroupJoinRequestDenied"), 			strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.Accepted] 				= {strMsg = Apollo.GetString("Group_JoinRequestAccepted"), 			strIcon = ktMessageIcon.Accept},
	[GroupLib.Result.ServerControlled] 		= {strMsg = Apollo.GetString("Group_JoinRequest_ServerControlled"), strIcon = ktMessageIcon.Error},
	[GroupLib.Result.GroupNotFound] 		= {strMsg = Apollo.GetString("Group_JoinRequest_GroupNotFound"), 	strIcon = ktMessageIcon.Error},
	[GroupLib.Result.NotAcceptingRequests] 	= {strMsg = Apollo.GetString("Group_NotAcceptingRequests"), 		strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.Busy]				 	= {strMsg = Apollo.GetString("Group_Busy"), 						strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.SentToLeader]		 	= {strMsg = Apollo.GetString("Group_SentToLeader"), 				strIcon = ktMessageIcon.Sent},
	[GroupLib.Result.LeaderOffline]		 	= {strMsg = Apollo.GetString("Group_LeaderOffline"), 				strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.WrongFaction]		 	= {strMsg = Apollo.GetString("GroupWrongFaction"), 					strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.PrivilegeRestricted]	= {strMsg = Apollo.GetString("Group_Join_PrivilegeRestricted"), 	strIcon = ktMessageIcon.Deny},
}

local ktReferralStrings =
{
	[GroupLib.Result.PlayerNotFound]		= {strMsg = Apollo.GetString("GroupPlayerNotFound"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.RealmNotFound] 		= {strMsg = Apollo.GetString("GroupRealmNotFound"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Grouped] 				= {strMsg = Apollo.GetString("GroupPlayerAlreadyGrouped"), 			strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Pending] 				= {strMsg = Apollo.GetString("GroupInvitePending"), 				strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.ExpiredInviter] 		= {strMsg = Apollo.GetString("GroupJoinRequestExpired"), 			strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.ExpiredInvitee] 		= {strMsg = Apollo.GetString("GroupYourJoinRequestExpired"), 		strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.InvitedYou] 			= {strMsg = Apollo.GetString("CRB_GroupJoinAlreadyRequested"), 		strIcon = ktMessageIcon.Error},
	[GroupLib.Result.NoInvitingSelf] 		= {strMsg = Apollo.GetString("Group_NoSelfInvite"), 				strIcon = ktMessageIcon.Error},
	[GroupLib.Result.Full] 					= {strMsg = Apollo.GetString("Group_GroupFull"), 					strIcon = ktMessageIcon.Error},
	[GroupLib.Result.NotAcceptingRequests] 	= {strMsg = Apollo.GetString("Group_NotAcceptingRequests"), 		strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.Busy]				 	= {strMsg = Apollo.GetString("Group_Busy"), 						strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.SentToLeader]		 	= {strMsg = Apollo.GetString("Group_SentToLeader"), 				strIcon = ktMessageIcon.Sent},
	[GroupLib.Result.LeaderOffline]		 	= {strMsg = Apollo.GetString("Group_LeaderOffline"), 				strIcon = ktMessageIcon.Deny},
	[GroupLib.Result.Declined]		 		= {strMsg = Apollo.GetString("GroupInviteRequestDeclined"), 		strIcon = ktMessageIcon.Deny},
}

local ktGroupLeftResultStrings =
{
	[GroupLib.RemoveReason.Kicked] 			= {strMsg = Apollo.GetString("Group_Kicked"), 			strIcon = ktMessageIcon.Kicked},
	[GroupLib.RemoveReason.VoteKicked] 		= {strMsg = Apollo.GetString("Group_Kicked"), 			strIcon = ktMessageIcon.Kicked},
	[GroupLib.RemoveReason.Left] 			= {strMsg = Apollo.GetString("InstancePartyLeave"), 	strIcon = ktMessageIcon.Left},
	[GroupLib.RemoveReason.Disband] 		= {strMsg = Apollo.GetString("GroupDisband"), 			strIcon = ktMessageIcon.Disbanded},
	[GroupLib.RemoveReason.RemovedByServer] = {strMsg = Apollo.GetString("Group_KickedByServer"), 	strIcon = ktMessageIcon.Left},
}

local ktLootRules =
{
	[GroupLib.LootRule.Master] 			= Apollo.GetString("Group_MasterLoot"),
	[GroupLib.LootRule.RoundRobin] 		= Apollo.GetString("Group_RoundRobin"),
	[GroupLib.LootRule.NeedBeforeGreed] = Apollo.GetString("Group_NeedBeforeGreed"),
	[GroupLib.LootRule.FreeForAll] 		= Apollo.GetString("Group_FFA")
}

local ktHarvestLootRules =
{
	[GroupLib.HarvestLootRule.FirstTagger] 		= Apollo.GetString("Group_FFA"),
	[GroupLib.HarvestLootRule.RoundRobin] 		= Apollo.GetString("Group_RoundRobin"),
}

local ktLootThreshold =
{
	[Item.CodeEnumItemQuality.Inferior] 		= Apollo.GetString("CRB_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= Apollo.GetString("CRB_Average"),
	[Item.CodeEnumItemQuality.Good] 			= Apollo.GetString("CRB_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= Apollo.GetString("CRB_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= Apollo.GetString("CRB_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= Apollo.GetString("CRB_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]	 		= Apollo.GetString("CRB_Artifact")
}

local ktDifficulty =
{
	[GroupLib.Difficulty.Normal] 	= Apollo.GetString("CRB_Normal"),
	[GroupLib.Difficulty.Veteran] 	= Apollo.GetString("CRB_Veteran")
}

local kstrRaidMarkerToSprite =
{
	"Icon_Windows_UI_CRB_Marker_Bomb",
	"Icon_Windows_UI_CRB_Marker_Ghost",
	"Icon_Windows_UI_CRB_Marker_Mask",
	"Icon_Windows_UI_CRB_Marker_Octopus",
	"Icon_Windows_UI_CRB_Marker_Pig",
	"Icon_Windows_UI_CRB_Marker_Chicken",
	"Icon_Windows_UI_CRB_Marker_Toaster",
	"Icon_Windows_UI_CRB_Marker_UFO",
}

local kfMessageDuration = 3.000
local kfDelayDuration 	= 0.010
local knInviteTimeout 	= 29 -- how long until an invite times out (display only, minus one to give code time to start)
local knMentorTimeout 	= 29 -- how long until an invite times out (display only, minus one to give code time to start)
local knGroupMax 		= 5  -- max number of people in a group
local knInviteMax 		= knGroupMax - 1 -- how many people can be invited
local knSaveVersion 	= 1

---------------------------------------------------------------------------------------------------
-- GroupDisplay initialization
---------------------------------------------------------------------------------------------------
function GroupDisplay:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.GroupMemberCount 				= 0
	o.nGroupMemberClicked 			= nil
	o.tGroupUnits 					= {}

	return o
end

function GroupDisplay:Init()
	Apollo.RegisterAddon(self)
end

function GroupDisplay:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local locInviteLocation = self.wndGroupInviteDialog and self.wndGroupInviteDialog:GetLocation() or self.locSavedInviteLoc
	local locMentorLocation = self.wndMentor and self.wndMentor:GetLocation() or self.locSavedMentorLoc

	local tSave =
	{
		tInviteLocation 			= locInviteLocation and locInviteLocation:ToTable() or nil,
		tMentorLocation 			= locMentorLocation and locMentorLocation:ToTable() or nil,
		bNeverShowRaidConvertNotice = self.bNeverShowRaidConvertNotice or false,
		fInviteTimerStart 			= self.fInviteTimerStartTime,
		strInviterName 				= self.strInviterName,
		fMentorTimerStart			= self.fMentorTimerStartTime,
		nSaveVersion 				= knSaveVersion,
	}

	return tSave
end

function GroupDisplay:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	self.bNeverShowRaidConvertNotice = tSavedData.bNeverShowRaidConvertNotice or false

	if tSavedData.tInviteLocation then
		self.locSavedInviteLoc = WindowLocation.new(tSavedData.tInviteLocation)
	end

	if tSavedData.tMentorLocation then
		self.locSavedMentorLoc = WindowLocation.new(tSavedData.tMentorLocation)
	end

	if tSavedData.fInviteTimerStart then
		local tInviteData = GroupLib.GetInvite()
		if tInviteData and #tInviteData > 0 then
			self.fInviteTimerStartTime = tSavedData.fInviteTimerStart
			self.strInviterName = tSavedData.strInviterName or ""
		end
	end

	if tSavedData.fMentorTimerStart then
		local tMentorData = GroupLib.GetMentoringList()
		if tMentorData and #tMentorData > 0 then
			self.fMentorTimerStartTime = tSavedData.fMentorTimerStart
		end
	end
end

---------------------------------------------------------------------------------------------------
-- GroupDisplay EventHandlers
---------------------------------------------------------------------------------------------------
function GroupDisplay:OnLoad()
	self.xmlOptionsDoc = XmlDoc.CreateFromFile("GroupDisplayOptions.xml")
	self.xmlDoc = XmlDoc.CreateFromFile("GroupDisplay.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function GroupDisplay:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("Group_Invited",			"OnGroupInvited", self)				-- ( name )
	Apollo.RegisterEventHandler("Group_Invite_Result",		"OnGroupInviteResult", self)		-- ( name, result )
	Apollo.RegisterEventHandler("Group_JoinRequest",		"OnGroupJoinRequest", self)			-- ( name )
	Apollo.RegisterEventHandler("Group_Referral",			"OnGroupReferral", self)			-- ( nMemberIndex, name )
	Apollo.RegisterEventHandler("Group_Request_Result",		"OnGroupRequestResult", self)		-- ( name, result, bIsJoin )
	Apollo.RegisterEventHandler("Group_Join",				"OnGroupJoin", self)				-- ()
	Apollo.RegisterEventHandler("Group_Add",				"OnGroupAdd", self)					-- ( name )
	Apollo.RegisterEventHandler("Group_Remove",				"OnGroupRemove", self)				-- ( name, reason )
	Apollo.RegisterEventHandler("Group_Left",				"OnGroupLeft", self)				-- ( reason )

	Apollo.RegisterEventHandler("Group_MemberFlagsChanged",	"OnGroupMemberFlags", self)			-- ( nMemberIndex, bIsFromPromotion, tChangedFlags)

	Apollo.RegisterEventHandler("Group_MemberPromoted",		"OnGroupMemberPromoted", self)		-- ( name, bSelf )
	Apollo.RegisterEventHandler("Group_Operation_Result",	"OnGroupOperationResult", self)		-- ( name, action )
	Apollo.RegisterEventHandler("Group_Updated",			"OnGroupUpdated", self)				-- ()
	Apollo.RegisterEventHandler("Group_FlagsChanged",		"OnGroupUpdated", self)				-- ()
	Apollo.RegisterEventHandler("Group_LootRulesChanged",	"OnGroupLootRulesChanged", self)	-- ()
	Apollo.RegisterEventHandler("Group_AcceptInvite",		"OnGroupAcceptInvite", self)		-- ()
	Apollo.RegisterEventHandler("Group_DeclineInvite",		"OnGroupDeclineInvite", self)		-- ()
	Apollo.RegisterEventHandler("Group_Mentor",				"OnGroupMentor", self)				-- ( tMemberList, bAlreadyMentoring )
	Apollo.RegisterEventHandler("Group_MentorLeftAOI",		"OnGroupMentorLeftAOI", self)		-- ( nTimeUntilMentoringDisabled, bClearUI )
	Apollo.RegisterEventHandler("LootRollUpdate",			"OnLootRollUpdate", self)			-- ()

	Apollo.RegisterEventHandler("Group_ReadyCheck",			"OnGroupReadyCheck", self)			-- ( nMemberIndex, strMessage )

	Apollo.RegisterEventHandler("RaidInfoResponse",			"OnRaidInfoResponse", self)			-- ( arRaidInfo )

	Apollo.RegisterEventHandler("MasterLootUpdate",			"OnMasterLootUpdate", 	self)

	Apollo.RegisterTimerHandler("InviteTimer", 				"OnInviteTimer", self)
	Apollo.RegisterTimerHandler("GroupMessageDelayTimer", 	"ProcessAlerts", self)
	Apollo.RegisterTimerHandler("GroupMessageTimer", 		"OnGroupMessageTimer", self)
	Apollo.RegisterTimerHandler("MentorTimer", 				"OnMentorTimer", self)
	Apollo.RegisterTimerHandler("MentorAOITimer", 			"OnMentorAOITimer", self)

	Apollo.RegisterTimerHandler("GroupUpdateTimer", 		"OnUpdateTimer", self)
	Apollo.CreateTimer("GroupUpdateTimer", 0.050, true)
	Apollo.StopTimer("GroupUpdateTimer")

	Apollo.RegisterEventHandler("GenericEvent_AttachWindow_GroupDisplayOptions", 	"AttachWindowGroupDisplayOptions", self)
	Apollo.RegisterEventHandler("GenericEvent_ShowConfirmLeaveDisband", 			"ShowConfirmLeaveDisband", self)

	---------------------------------------------------------------------------------------------------
	-- GroupDisplay Member Variables
	---------------------------------------------------------------------------------------------------
	self.wndGroupHud 			= Apollo.LoadForm(self.xmlDoc, "GroupHud", "FixedHudStratum", self)
	self.wndGroupHud:Show(false, true)
	self.wndLeaveGroup 			= self.wndGroupHud:FindChild("GroupHudLeaveDialog")
	self.wndLeaveGroup:Show(false,true)
	self.wndGroupMessage 		= self.wndGroupHud:FindChild("GroupHudMessage")
	self.tMessageQueue 			= Queue:new()

	self.wndGroupPortraitContainer = self.wndGroupHud:FindChild("GroupPortraitContainer")

	self.wndGroupInviteDialog 	= Apollo.LoadForm(self.xmlDoc, "GroupInviteDialog", nil, self)
	self.wndGroupInviteDialog:Show(false, true)
	if self.locSavedInviteLoc then
		self.wndGroupInviteDialog:MoveToLocation(self.locSavedInviteLoc)
	end

	self.wndInviteMemberList 	= self.wndGroupInviteDialog:FindChild("InviteMemberList")
	self.nInviteTimer 			= knInviteTimeout

	self.eChatChannel 			= ChatSystemLib.ChatChannel_Party

	self.wndGroupInviteDialog:Show(false)
	if self.fInviteTimerStartTime then
		self:OnGroupInvited(self.strInviterName)
	end

	self.tGroupWndPortraits 	= {}

	self.eInstanceDifficulty 	= GroupLib.GetInstanceDifficulty()
	self.tLootRules	 			= GroupLib.GetLootRules()

	self.wndMentor 				= Apollo.LoadForm(self.xmlDoc, "GroupMentorDialog", nil, self)
	self.wndMentor:Show(false, true)
	if self.locSavedMentorLoc then
		self.wndMentor:MoveToLocation(self.locSavedMentorLoc)
	end

	if self.fMentorTimerStartTime then
		self:OnGroupMentor(GroupLib.GetMentoringList(), GameLib:GetPlayerUnit():IsMentoring(), false)
	end

	self.wndMentorAOI			= Apollo.LoadForm(self.xmlDoc, "GroupMentorLeftAoIDialog", nil, self)
	self.wndMentorAOI:Show(false, true)
	self.wndRequest				= Apollo.LoadForm(self.xmlDoc, "GroupRequestDialog", nil, self)
	self.wndRequest:Show(false, true)
	--self.unitGroupMemberClicked = nil


	self:OnGroupUpdated()

	---------------------------------------------------------------------------------------------------
	-- GroupDisplay Setup
	---------------------------------------------------------------------------------------------------

	for idx = 1, #karMessageIconString do
		self.wndGroupMessage:FindChild(karMessageIconString[idx]):Show(false)
	end

	self.wndRequest:Show(false)

	Event_FireGenericEvent("GenericEvent_InitializeGroupLeaderOptions", self.wndGroupHud:FindChild("GroupControlsBtn"))
	-- TEMP HACK: Try again in case this loads first
	Apollo.RegisterTimerHandler("GroupDisplayOptions_TEMP", "GroupDisplayOptions_TEMP", self)
	Apollo.CreateTimer("GroupDisplayOptions_TEMP", 3, false)
	Apollo.StartTimer("GroupDisplayOptions_TEMP")

	if GroupLib.InGroup() then
		if GroupLib.InRaid() then
			self:OnUpdateTimer()
		else
			Apollo.StartTimer("GroupUpdateTimer")
		end
	end
end

function GroupDisplay:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndGroupHud, strName = Apollo.GetString("Group_CurrentGroup")})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndGroupInviteDialog, strName = Apollo.GetString("CRB_Invite_To_Group")})
end

function GroupDisplay:GroupDisplayOptions_TEMP()
	-- TEMP HACK: Try again in case this loads first
	Event_FireGenericEvent("GenericEvent_InitializeGroupLeaderOptions", self.wndGroupHud:FindChild("GroupControlsBtn"))
end

---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

function GroupDisplay:LoadPortrait(idx)
	local wndHud = Apollo.LoadForm(self.xmlDoc, "GroupPortraitHud", self.wndGroupPortraitContainer)

	self.tGroupWndPortraits[idx] =
	{
		idx 						= idx,
		wndHud 						= wndHud,
		wndLeader 					= wndHud:FindChild("Leader"),
		wndName 					= wndHud:FindChild("Name"),
		wndClass 					= wndHud:FindChild("Class"),
		wndHealth 					= wndHud:FindChild("Health"),
		wndShields 					= wndHud:FindChild("Shields"),
		wndMaxShields 				= wndHud:FindChild("MaxShields"),
		wndMaxAbsorb 				= wndHud:FindChild("MaxAbsorbBar"),
		wndLowHealthFlash			= wndHud:FindChild("LowHealthFlash"),
		wndPathIcon 				= wndHud:FindChild("PathIcon"),
		wndOffline					= wndHud:FindChild("Offline"),
		wndDeadIndicator			= wndHud:FindChild("DeadIndicator"),
		wndGroupPortraitHealthBG	= wndHud:FindChild("GroupPortraitHealthBG"),
		wndGroupDisabledFrame		= wndHud:FindChild("GroupDisabledFrame"),
		wndGroupPortraitBtn			= wndHud:FindChild("GroupPortraitBtn"),
		wndMark						= wndHud:FindChild("Mark")
	}

	self.tGroupWndPortraits[idx].wndHud:Show(false)

	-- We apparently resize bars rather than set progress
	self:SetBarValue(self.tGroupWndPortraits[idx].wndHealth, 0, 100, 100)
	self:SetBarValue(self.tGroupWndPortraits[idx].wndShields, 0, 100, 100)

	if self.nFrameLeft == nil then
		self.nFrameLeft, self.nFrameTop, self.nFrameRight, self.nFrameBottom = self.tGroupWndPortraits[idx].wndHealth:GetAnchorOffsets()
		self.nShieldFrameLeft, self.nShieldFrameTop, self.nShieldFrameRight, self.nShieldFrameBottom = self.tGroupWndPortraits[idx].wndShields:GetAnchorOffsets()
		self.nMaxShieldFrameLeft, self.nMaxShieldFrameTop, self.nMaxShieldFrameRight, self.nMaxShieldFrameBottom = self.tGroupWndPortraits[idx].wndMaxShields:GetAnchorOffsets()
		self.nMaxAbsorbFrameLeft, self.nMaxAbsorbFrameTop, self.nMaxAbsorbFrameRight, self.nMaxAbsorbFrameBottom = self.tGroupWndPortraits[idx].wndMaxAbsorb:GetAnchorOffsets()
	end

	self.tGroupWndPortraits[idx].wndHud:SetData(idx)
	self.tGroupWndPortraits[idx].wndGroupPortraitBtn:SetData(idx)

	self:HelperResizeGroupContents()
end

---------------------------------------------------------------------------------------------------
-- Recieved an Invitation
---------------------------------------------------------------------------------------------------

function GroupDisplay:OnGroupInvited(strInviterName) -- builds the invite when I recieve it
	ChatSystemLib.PostOnChannel(self.eChatChannel, String_GetWeaselString(Apollo.GetString("GroupInvite"), strInviterName), "")
	self.strInviterName = strInviterName

	self.wndInviteMemberList:DestroyChildren()

	local arInvite = GroupLib.GetInvite()
	for idx, tMemberInfo in ipairs(arInvite) do-- display group members in an invite
		if tMemberInfo ~= nil then
			local wndEntry = ""
			if tMemberInfo.bIsLeader then -- choose a frame
				wndEntry = Apollo.LoadForm(self.xmlDoc, "GroupInviteLeader", self.wndInviteMemberList, self)
			else
				wndEntry = Apollo.LoadForm(self.xmlDoc, "GroupInviteMember", self.wndInviteMemberList, self)
			end

			wndEntry:FindChild("InviteMemberLevel"):SetText(tMemberInfo.nLevel)
			wndEntry:FindChild("InviteMemberName"):SetText(tMemberInfo.strCharacterName)
			wndEntry:FindChild("InviteMemberPathIcon"):SetSprite(ktInvitePathIcons[tMemberInfo.ePathType])

			local strSpriteToUse = "CRB_GroupSprites:sprGrp_MFrameIcon_Axe"
			if ktInviteClassIcons[tMemberInfo.eClassId] then
				strSpriteToUse = ktInviteClassIcons[tMemberInfo.eClassId]
			end

			wndEntry:FindChild("InviteMemberClass"):SetSprite(strSpriteToUse)
		end
	end

	local nOpenSlots = knInviteMax - table.getn(arInvite) -- how many slots are open
	if nOpenSlots > 0 then -- make sure it's not running a negative
		for nBlankEntry = 1, nOpenSlots do -- populate the interface
			local wndBlankEntry = Apollo.LoadForm(self.xmlDoc, "GroupInviteBlank", self.wndInviteMemberList, self)
		end
	end
	self.wndInviteMemberList:ArrangeChildrenVert()

	if not self.fInviteTimerStartTime then
		self.fInviteTimerStartTime = os.clock()
	end

	self.fInviteTimerDelta = os.clock() - self.fInviteTimerStartTime
	self.wndGroupInviteDialog:FindChild("Timer"):SetText("")
	local strTime = string.format("%d:%02d", math.floor(self.fInviteTimerDelta / 60), math.ceil(30 - (self.fInviteTimerDelta % 60)))
	self.wndGroupInviteDialog:FindChild("Timer"):SetText(String_GetWeaselString(Apollo.GetString("Group_ExpiresTimer"), strTime))
	Apollo.CreateTimer("InviteTimer", 1.000, true)

	 self.wndGroupInviteDialog:Invoke(true)
	 Sound.Play(Sound.PlayUISocialPartyInviteSent)
end

function GroupDisplay:OnGroupJoinRequest(strInviterName) -- builds the invite when I recieve it
	-- undone need token passed as context
	-- a join message means that someone has requested to join our existing party
	local str = String_GetWeaselString(Apollo.GetString("GroupJoinRequest"), strInviterName)
	self.wndRequest:FindChild("Title"):SetText(str)
	self.wndRequest:Show(true)
	ChatSystemLib.PostOnChannel(self.eChatChannel, str, "")
end

function GroupDisplay:OnGroupReferral(nMemberIndex, strTarget) -- builds the invite when I receive it
	-- undone need token passed as context
	-- a join message means that someone has requested to join our existing party
	local str = String_GetWeaselString(Apollo.GetString("GroupReferral"), strTarget)
	self.wndRequest:FindChild("Title"):SetText(str)
	self.wndRequest:Show(true)
	ChatSystemLib.PostOnChannel(self.eChatChannel, str, "")
end

function GroupDisplay:OnInviteTimer()
	self.fInviteTimerDelta = self.fInviteTimerDelta + 1
	if self.fInviteTimerDelta <= 31 then
		local strTime = string.format("%d:%02d", math.floor(self.fInviteTimerDelta / 60), math.ceil(30 - (self.fInviteTimerDelta % 60)))
		self.wndGroupInviteDialog:FindChild("Timer"):SetText(String_GetWeaselString(Apollo.GetString("Group_ExpiresTimer"), strTime))
	else
		self.wndGroupInviteDialog:FindChild("Timer"):SetText("X")
	end
end

function GroupDisplay:OnGroupInviteDialogAccept()
	GroupLib.AcceptInvite()
	self.wndGroupInviteDialog:Show(false)
	self.fInviteTimerStartTime = nil
	Apollo.StopTimer("InviteTimer")
	Sound.Play(Sound.PlayUISocialPartyInviteAccept)
end

function GroupDisplay:OnGroupInviteDialogDecline()
	GroupLib.DeclineInvite()
	self.wndGroupInviteDialog:Show(false)
	self.fInviteTimerStartTime = nil
	Apollo.StopTimer("InviteTimer")
	Sound.Play(Sound.PlayUISocialPartyInviteDecline)
end

function GroupDisplay:OnReportGroupInviteSpamBtn()
	Event_FireGenericEvent("GenericEvent_ReportPlayerGroupInvite", 30 - self.fInviteTimerDelta) -- Order is important
	-- GroupLib.DeclineInvite() -- Do NOT decline the invite. The report system needs it still valid for full details.
	self.wndGroupInviteDialog:Show(false)
	self.fInviteTimerStartTime = nil
	Apollo.StopTimer("InviteTimer")
end

function GroupDisplay:OnRaidInfoResponse(arRaidInfo)
	if #arRaidInfo == 0 then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, Apollo.GetString("Command_UsageRaidInfoNone"), "" )
		return
	end

	for _, tRaidInfo in ipairs(arRaidInfo) do

		-- tRaidInfo.strWorldName can be nil
		-- tRaidInfo.strSavedInstanceId is a string with a large number
		-- tRaidInfo.nWorldId is the id of the instance
		-- tRaidInfo.strDateExpireUTC is string of the full date the lock resets.
		-- tRaidInfo.fDaysFromNow is relative time from now that the lock resets.

		local strMessage = String_GetWeaselString(Apollo.GetString("Command_UsageRaidInfo"), tRaidInfo.strWorldName or "", tRaidInfo.strSavedInstanceId, tRaidInfo.strDateExpireUTC )
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, strMessage, "" )
	end
end

---------------------------------------------------------------------------------------------------
-- Group Formatting
---------------------------------------------------------------------------------------------------

function GroupDisplay:DestroyGroup()
	for idx, tMemberInfo in pairs(self.tGroupWndPortraits) do -- This is essentially self.wndGroupPortraitContainer:DestroyChildren()
		if tMemberInfo.wndHud and tMemberInfo.wndHud:IsValid() then
			tMemberInfo.wndHud:Destroy()
		end
		self.tGroupWndPortraits[idx] = nil
	end

	Apollo.StopTimer("GroupUpdateTimer")

	local nMemberCount = GroupLib.GetMemberCount()
	if nMemberCount <= 1 then
		return
	end

	Apollo.StartTimer("GroupUpdateTimer")

	self:OnGroupUpdated()
end

function GroupDisplay:PostChangeToChannel(nPrevValue, nNextValue, tDescriptionTable, strChangeString, strUnknownChangeString)
	if nPrevValue ~= nNextValue then
		if tDescriptionTable[nNextValue] ~= nil then
			ChatSystemLib.PostOnChannel(self.eChatChannel, String_GetWeaselString(strChangeString, tDescriptionTable[nNextValue]), "") --lua placeholder string
		else
			ChatSystemLib.PostOnChannel(self.eChatChannel, strUnknownChangeString, "") --lua placeholder string
		end
	end
end

function GroupDisplay:OnGroupUpdated()
	if GroupLib.InRaid() then
		return
	end

	for idx, tPortrait in pairs(self.tGroupWndPortraits) do
		tPortrait.wndHud:Show(false)
	end

	if GroupLib.InInstance() then
		self.eChatChannel = ChatSystemLib.ChatChannel_Instance;
	else
		self.eChatChannel = ChatSystemLib.ChatChannel_Party;
	end

	if self.bDisplayedRaid == nil and GroupLib.InRaid() then
		self.bDisplayedRaid = true
		ChatSystemLib.PostOnChannel(self.eChatChannel, Apollo.GetString("Group_BecomeRaid"), "") --lua placeholder string

		if self.wndRaidNotice and self.wndRaidNotice:IsValid() then
			self.wndRaidNotice:Destroy()
			self.wndRaidNotice = nil
		end

		if self.bNeverShowRaidConvertNotice == false then
			self.wndRaidNotice = Apollo.LoadForm(self.xmlOptionsDoc, "RaidConvertedForm", nil, self)
			self.wndRaidNotice:Show(true)
			self.wndRaidNotice:ToFront()
		end
	end

	self.eInstanceDifficulty = GroupLib.GetInstanceDifficulty()

	self:PostChangeToChannel(self.eInstanceDifficulty, GroupLib.GetInstanceDifficulty(), ktDifficulty, Apollo.GetString("Group_DifficultyChangedTo"), Apollo.GetString("Group_DifficultyChangedDefault"))

	-- Attach the portrait form to each hud slot.

	if GroupLib.InGroup() and GroupLib.GetMemberCount() == 0 then
		self.bDisplayedRaid = nil
		self:HelperResizeGroupContents()
		return
	end

	local unitMe = GameLib.GetPlayerUnit()
	if unitMe == nil then
		return
	end

	self.nGroupMemberCount = GroupLib.GetMemberCount()

	local nCount = 0
	if self.nGroupMemberCount > 0 then
		for idx = 1, self.nGroupMemberCount do
			local tMemberInfo = GroupLib.GetGroupMember(idx)
			if tMemberInfo ~= nil then
				if self.tGroupWndPortraits[idx] == nil then
					self:LoadPortrait(idx)
				end
				self.tGroupWndPortraits[idx].wndHud:Show(true)

				nCount = nCount + 1
			end
		end
	end

	if nCount == 0 then
		self:CloseGroupHUD()
	else
		self.wndGroupHud:FindChild("GroupControlsBtn"):Show(true)
		--self.wndGroupHud:FindChild("GroupBagBtn"):Show(true) -- TODO TEMP DISABLED
		self.wndGroupHud:Show(true)
	end

	self:HelperResizeGroupContents()
end

function GroupDisplay:OnGroupLootRulesChanged()
	if GroupLib.InRaid() then
		return
	end

	local tNewLootRules = GroupLib.GetLootRules()

	self:PostChangeToChannel(self.tLootRules.eNormalRule, tNewLootRules.eNormalRule, ktLootRules, Apollo.GetString("Group_LootChangedTo"), Apollo.GetString("Group_LootChangedDefault"))
	self:PostChangeToChannel(self.tLootRules.eThresholdRule, tNewLootRules.eThresholdRule, ktLootRules, Apollo.GetString("Group_ThresholdRuleChangedTo"), Apollo.GetString("Group_ThresholdRuleChangedDefault"))
	self:PostChangeToChannel(self.tLootRules.eThresholdQuality, tNewLootRules.eThresholdQuality, ktLootThreshold, Apollo.GetString("Group_ThresholdQualityChangedTo"), Apollo.GetString("Group_ThresholdQualityChangedDefault"))
	self:PostChangeToChannel(self.tLootRules.eHarvestRule, tNewLootRules.eHarvestRule, ktHarvestLootRules, Apollo.GetString("Group_HarvestLootChangedTo"), Apollo.GetString("Group_HarvestLootChangedDefault"))

	self.tLootRules = tNewLootRules
end

function GroupDisplay:OnGroupControlsCheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_UpdateGroupLeaderOptions")
end

function GroupDisplay:OnGroupPortraitClick(wndHandler, wndControl, eMouseButton)
	local tInfo = wndHandler:GetData()
	local nMemberIdx = tInfo[1]
	local strName = tInfo[2] -- In case they run out of range and we lose the unitMember

	local unitMember = GroupLib.GetUnitForGroupMember(nMemberIdx) --returns nil when the member is out of range among other reasons
	if nMemberIdx and unitMember then
		GameLib.SetTargetUnit(unitMember)
	end

	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", wndHandler, strName, unitMember) -- unitMember is optional
	end
end

function GroupDisplay:OnGroupBagBtn()
	Event_FireGenericEvent("GenericEvent_ToggleGroupBag")
end

function GroupDisplay:OnMasterLootUpdate()
	local tMasterLoot = GameLib.GetMasterLoot()
	if tMasterLoot and #tMasterLoot > 0 then
		self.wndGroupHud:FindChild("GroupBagBtn"):Show(true)
		self.wndGroupHud:FindChild("GroupBagBtn"):Enable(true)
	else
		self.wndGroupHud:FindChild("GroupBagBtn"):Show(false)
		self.wndGroupHud:FindChild("GroupBagBtn"):Enable(false)
	end
end

---------------------------------------------------------------------------------------------------
-- Per Player Options Menu (Promote/Kick/etc.)
---------------------------------------------------------------------------------------------------

function GroupDisplay:OnKick()
	if self.nGroupMemberClicked == nil then
		return
	end
	GroupLib.Kick(self.nGroupMemberClicked, "")
end

function GroupDisplay:OnLocate()
	if self.nGroupMemberClicked == nil then
		return
	end
	local unitMember = GroupLib.GetUnitForGroupMember(self.nGroupMemberClicked)
	if unitMember then
		unitMember:ShowHintArrow()
	end
end

function GroupDisplay:OnPromote()
	if self.nGroupMemberClicked == nil then
		return
	end
	GroupLib.Promote(self.nGroupMemberClicked, "")
end

function GroupDisplay:ShowConfirmLeaveDisband(nType)
	self.wndLeaveGroup:FindChild("ConfirmLeaveBtn"):Show(false)
	self.wndLeaveGroup:FindChild("ConfirmDisbandBtn"):Show(false)
	if nType == 0 then --disband
		self.wndLeaveGroup:FindChild("LeaveText"):SetText(Apollo.GetString("CRB_Are_you_sure_you_want_to_disband_this_group"))
		self.wndLeaveGroup:FindChild("ConfirmDisbandBtn"):Show(true)
	else
		self.wndLeaveGroup:FindChild("LeaveText"):SetText(Apollo.GetString("CRB_Are_you_sure_you_want_to_leave_this_group"))
		self.wndLeaveGroup:FindChild("ConfirmLeaveBtn"):Show(true)
	end

	self.wndLeaveGroup:Invoke()
	self:HelperResizeGroupContents()
end

function GroupDisplay:OnLeaveGroup()
	self:ShowConfirmLeaveDisband(1)
end

function GroupDisplay:OnDisbandGroup()
	self:ShowConfirmLeaveDisband(0)
end

function GroupDisplay:OnConfirmLeave()
	GroupLib.LeaveGroup()
	self:DestroyGroup()
end

function GroupDisplay:OnConfirmDisband()
	if GroupLib.AmILeader() and not GroupLib.InInstance() then
		GroupLib.DisbandGroup()
		self:DestroyGroup()
	end
end

function GroupDisplay:OnCancelLeave()
	self.wndLeaveGroup:Close()
	self:HelperResizeGroupContents()
end

---------------------------------------------------------------------------------------------------
-- Format Members
---------------------------------------------------------------------------------------------------
function GroupDisplay:DrawMemberPortrait(tPortrait, tMemberInfo)
	if tPortrait == nil or tMemberInfo == nil then
		return
	end

	local unitMember = GroupLib.GetUnitForGroupMember(tPortrait.idx)
	local tMemberVisibility = GroupLib.GetMemberVisibility(tPortrait.idx)
	local bRightPhase = tPortrait.idx == 1 or (tMemberVisibility.bCanISee and tMemberVisibility.bCanSeeMe)
	local bOutOfRange = not unitMember

    local strName = tMemberInfo.strCharacterName
	if not tMemberInfo.bIsOnline then
        strName = String_GetWeaselString(Apollo.GetString("Group_OfflineMember"), strName)
	elseif not bRightPhase then
		strName = String_GetWeaselString(Apollo.GetString("Group_WrongPhaseMember"), strName)
	elseif bOutOfRange then
		strName = String_GetWeaselString(Apollo.GetString("Group_OutOfRangeMember"), strName)
    end

	if tMemberInfo.bTank then
		strName = String_GetWeaselString(Apollo.GetString("Group_TankTag"), strName)
	elseif tMemberInfo.bHealer then
		strName = String_GetWeaselString(Apollo.GetString("Group_HealerTag"), strName)
	elseif tMemberInfo.bDPS then
		strName = String_GetWeaselString(Apollo.GetString("Group_DPSTag"), strName)
	end

	local bDead = tMemberInfo.nHealth == 0 and tMemberInfo.nHealthMax ~= 0
	if bDead then
		tPortrait.wndName:SetTextColor(ApolloColor.new("xkcdReddish"))
	elseif bOutOfRange or not tMemberInfo.bIsOnline then
		tPortrait.wndName:SetTextColor(ApolloColor.new("UI_WindowTitleGray"))
	else
		tPortrait.wndName:SetTextColor(ApolloColor.new("ff7effb8"))
	end

	self.tGroupWndPortraits[tPortrait.idx].wndGroupPortraitBtn:SetData({ tPortrait.idx, tMemberInfo.strCharacterName })
	tPortrait.wndName:SetText(strName)
	tPortrait.wndLeader:Show(tMemberInfo.bIsLeader)
	tPortrait.wndClass:Show(tMemberInfo.bIsOnline)
	tPortrait.wndPathIcon:Show(tMemberInfo.bIsOnline)
	tPortrait.wndOffline:Show(not tMemberInfo.bIsOnline)
	tPortrait.wndLowHealthFlash:Show(tMemberInfo.bIsOnline)
	tPortrait.wndDeadIndicator:Show(bDead)
	tPortrait.wndGroupPortraitHealthBG:Show(tMemberInfo.nHealth > 0)
	tPortrait.wndGroupDisabledFrame:Show(bOutOfRange)
	tPortrait.wndGroupPortraitBtn:ChangeArt(bOutOfRange and "CRB_DEMO_WrapperSprites:btnDemo_CharInvisible" or "CRB_GroupFrame:sprGroup_Btn_Holo")

	local unitTarget = GameLib.GetTargetUnit()
	tPortrait.wndGroupPortraitBtn:SetCheck(unitTarget and unitTarget == unitMember) --tPortrait.unitMember

	tPortrait.wndHud:FindChild("GroupPortraitArrangeVert"):ArrangeChildrenVert(1)

	if tMemberInfo.nHealth > 0 then
		self:HelperUpdateHealth(tPortrait, tMemberInfo)
	end

	-- Set the Path Icon
	local strPathSprite = ""
	if ktSmallInvitePathIcons[tMemberInfo.ePathType] then
		strPathSprite = ktSmallInvitePathIcons[tMemberInfo.ePathType]
	end
	tPortrait.wndPathIcon:SetSprite(strPathSprite)

	local nLevel = tMemberInfo.nEffectiveLevel > 0 and tMemberInfo.nEffectiveLevel or tMemberInfo.nLevel
	local strClass = Apollo.GetString(ktIdToClassTooltip[tMemberInfo.eClassId])
	local strClassSprite = ""
	if ktInviteClassIcons[tMemberInfo.eClassId] then
		strClassSprite = ktInviteClassIcons[tMemberInfo.eClassId]
	end
	tPortrait.wndClass:SetSprite(strClassSprite)
	tPortrait.wndClass:SetTooltip(String_GetWeaselString(Apollo.GetString("CRB_LevelCLass"), nLevel, strClass))

	tPortrait.wndMark:Show(tMemberInfo.nMarkerId ~= 0)
	if tMemberInfo.nMarkerId ~= 0 then
		tPortrait.wndMark:SetSprite(kstrRaidMarkerToSprite[tMemberInfo.nMarkerId])
	end
end

function GroupDisplay:HelperUpdateHealth(tPortrait, tMemberInfo)
	local nHealthCurr 	= tMemberInfo.nHealth
	local nHealthMax 	= tMemberInfo.nHealthMax
	local nShieldCurr 	= tMemberInfo.nShield
	local nShieldMax	= tMemberInfo.nShieldMax
	local nAbsorbMax 	= tMemberInfo.nAbsorptionMax
	local nAbsorbCurr 	= 0
	if nAbsorbMax > 0 then
		nAbsorbCurr = tMemberInfo.nAbsorption
	end

	local nTotalMax = nHealthMax + nShieldMax + nAbsorbMax
	tPortrait.wndLowHealthFlash:Show(nHealthCurr ~= 0 and nHealthCurr / nHealthMax <= 0.25)

	-- Scaling
	local nPointHealthRight = self.nFrameRight * (nHealthCurr / nTotalMax)
	local nPointShieldRight = self.nFrameRight * ((nHealthCurr + nShieldMax) / nTotalMax)
	local nPointAbsorbRight = self.nFrameRight * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax)

	if nShieldMax > 0 and nShieldMax / nTotalMax < 0.2 then
		local nMinShieldSize = 0.2 -- HARDCODE: Minimum shield bar length is 20% of total for formatting
		nPointHealthRight = self.nFrameRight * math.min(1 - nMinShieldSize, nHealthCurr / nTotalMax) -- Health is normal, but caps at 80%
		nPointShieldRight = self.nFrameRight * math.min(1, (nHealthCurr / nTotalMax) + nMinShieldSize) -- If not 1, the size is thus healthbar + hard minimum
	end

	-- Resize
	tPortrait.wndShields:EnableGlow(nShieldCurr > 0 and nShieldCurr ~= nShieldMax)
	self:SetBarValue(tPortrait.wndShields, 0, nShieldCurr, nShieldMax) -- Only the Curr Shield really progress fills
	self:SetBarValue(tPortrait.wndMaxAbsorb:FindChild("CurrAbsorbBar"), 0, nAbsorbCurr, nAbsorbMax)
	tPortrait.wndHealth:SetAnchorOffsets(self.nFrameLeft, self.nFrameTop, nPointHealthRight, self.nFrameBottom)
	tPortrait.wndMaxShields:SetAnchorOffsets(nPointHealthRight - 10, self.nMaxShieldFrameTop, nPointShieldRight + 6, self.nMaxShieldFrameBottom)
	tPortrait.wndMaxAbsorb:SetAnchorOffsets(nPointShieldRight - 14, self.nMaxAbsorbFrameTop, nPointAbsorbRight + 6, self.nMaxAbsorbFrameBottom)

	-- Bars
	tPortrait.wndShields:Show(nHealthCurr > 0)
	tPortrait.wndHealth:Show(nHealthCurr / nTotalMax > 0.01) -- TODO: Temp The sprite draws poorly this low.
	tPortrait.wndMaxShields:Show(nHealthCurr > 0 and nShieldMax > 0)
	tPortrait.wndMaxAbsorb:Show(nHealthCurr > 0 and nAbsorbMax > 0)
end

function GroupDisplay:SetBarValue(wndBar, fMin, fValue, fMax)
	wndBar:SetMax(fMax)
	wndBar:SetFloor(fMin)
	wndBar:SetProgress(fValue)
end

---------------------------------------------------------------------------------------------------
-- OnUpdateTimer
---------------------------------------------------------------------------------------------------

function GroupDisplay:OnUpdateTimer(strVar, nValue)
	if GroupLib.InRaid() then -- TODO: Refactor, also free up memory
		if self.wndGroupHud and self.wndGroupHud:IsValid() and self.wndGroupHud:IsShown() then
			self.wndGroupHud:Show(false, true)
			Apollo.StopTimer("GroupUpdateTimer")
		end
		return
	end

	self.nGroupMemberCount = nMemberCount
	if self.nGroupMemberCount == 0 then
		if not self.wndLeaveGroup:IsShown() and not self.wndGroupMessage:IsShown() then
			self.wndGroupHud:Show(false, true)
		end
		return
	end

	self:OnMasterLootUpdate()
	self.wndGroupHud:FindChild("GroupWrongInstance"):Show(GroupLib.CanGotoGroupInstance())

	-- TODO: This should probably be moved to the other on frame timer
	local nMemberCount = GroupLib.GetMemberCount()
	if self.nGroupMemberCount ~= nMemberCount then
		self:OnGroupUpdated()
	end

	if self.nGroupMemberCount ~= nil then
		for idx = 1, self.nGroupMemberCount do
			local tMemberInfo = GroupLib.GetGroupMember(idx)
			if tMemberInfo ~= nil then
				if self.tGroupWndPortraits[idx] == nil then
					self:LoadPortrait(idx)
				end
				self:DrawMemberPortrait(self.tGroupWndPortraits[idx], tMemberInfo)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Message Calls/Events/Signals
---------------------------------------------------------------------------------------------------

-- TODO: Refactor all below this

function GroupDisplay:OnGroupAdd(strMemberName) -- Someone else joined my group
	local strMsg = String_GetWeaselString(Apollo.GetString("GroupJoin"), strMemberName)
	self:AddToQueue(ktMessageIcon.Accept, strMsg)
	self:OnGroupUpdated()
end

function GroupDisplay:OnGroupJoin() -- I joined a group
	self:OnGroupUpdated()
	local strMsg = String_GetWeaselString(Apollo.GetString("GroupJoined"))
	self:AddToQueue(ktMessageIcon.Sent, strMsg)

	self.eInstanceDifficulty = GroupLib.GetInstanceDifficulty()
	self.eLootRules = GroupLib.GetLootRules()

	if GroupLib.InRaid() then
		self:OnUpdateTimer()
	else
		Apollo.StartTimer("GroupUpdateTimer")
	end
end

function GroupDisplay:OnGroupRemove(strMemberName, eReason) -- someone else left the group

	if eReason == GroupLib.RemoveReason.Kicked or eReason == GroupLib.RemoveReason.VoteKicked then
		local strMsg = String_GetWeaselString(Apollo.GetString("Group_KickedPlayer"), strMemberName)
		self:AddToQueue(ktMessageIcon.Kicked, strMsg)
	elseif 	eReason == GroupLib.RemoveReason.Left or eReason == GroupLib.RemoveReason.Disband or
			eReason == GroupLib.RemoveReason.RemovedByServer or eReason == GroupLib.RemoveReason.Disconnected then

		local strMsg = String_GetWeaselString(Apollo.GetString("GroupLeft"), strMemberName)
		self:AddToQueue(ktMessageIcon.Left, strMsg)
	end

	self:OnGroupUpdated()
end

function GroupDisplay:OnGroupMemberPromoted(strMemberName, bSelf) -- I've been promoted
	if bSelf then
		local strMsg = String_GetWeaselString(Apollo.GetString("GroupPromotePlayer"))
		self:AddToQueue(ktMessageIcon.Promoted, strMsg)
	else
		local strMsg = String_GetWeaselString(Apollo.GetString("GroupPromoteOther"),strMemberName)
		self:AddToQueue(ktMessageIcon.Promoted, strMsg)
	end
	self:OnGroupUpdated()
end

function GroupDisplay:OnGroupOperationResult(strMemberName, eResult)
	if ktActionResultStrings[eResult] then
		local strMsg = ktActionResultStrings[eResult].strMsg
		if string.find(ktActionResultStrings[eResult].strMsg, "%$1n") then
			strMsg = String_GetWeaselString(ktActionResultStrings[eResult].strMsg, strMemberName)
		end

		if GroupLib.InRaid() and eAction == GroupLib.ActionResult.FlagsFailed then
			strMsg = String_GetWeaselString(Apollo.GetString("Group_AppendInRaid"), strMsg)
		end

		self:AddToQueue(ktActionResultStrings[eResult].strIcon, strMsg)
	end
end

function GroupDisplay:OnGroupAcceptInvite() -- I've accepted an invitation
	self.wndGroupInviteDialog:Show(false)
end

function GroupDisplay:OnGroupDeclineInvite() -- I've declined an invitation
	self.wndGroupInviteDialog:Show(false)
end

function GroupDisplay:OnLootRollUpdate()
--[[
	local tLootRolls = GameLib.GetLootRolls()
	for idx, tLoot in ipairs(tLootRolls) do
		--GameLib.RollOnLoot(tLoot.lootId, true)
	end
]]--
end

function GroupDisplay:OnGroupLeft(eReason)
	local unitMe = GameLib.GetPlayerUnit()
	if unitMe == nil then
		return
    end

	local strMsg = ktGroupLeftResultStrings[eReason].strMsg

	if eReason == GroupLib.RemoveReason.Left and self.eChatChannel == ChatSystemLib.ChatChannel_Party then
		strMsg = Apollo.GetString("GroupLeave")
	end

	self:AddToQueue(ktGroupLeftResultStrings[eReason].strIcon, strMsg)

	self.wndRequest:Show(false)
	self.wndLeaveGroup:Show(false)

	self:DestroyGroup()
end

function GroupDisplay:OnGroupMemberFlags(nMemberIndex, bIsFromPromotion, tChangedFlags)
	local tMember = GroupLib.GetGroupMember(nMemberIndex)
	if tMember == nil then
		return
	end

	local bSelf = nMemberIndex == 1

	local bIsFromPromotionOrRaidAssistant = bIsFromPromotion or tChangedFlags.bRaidAssistant

	if tChangedFlags.bCanKick then
		local strMsg = ""
		local strPermission = Apollo.GetString("Group_KickPermission")

		if not bIsFromPromotionOrRaidAssistant then
			if tMember.bCanKick then
				strMsg = Apollo.GetString("Group_Enabled")
			else
				strMsg = Apollo.GetString("Group_Disabled")
			end

			if bSelf then
				strMsg = String_GetWeaselString(Apollo.GetString("Group_PermissionsChangedSelf"), strPermission, strMsg)
			elseif GroupLib.AmILeader() then
				strMsg = String_GetWeaselString(Apollo.GetString("Group_PermissionsChangedOther"), strMsg, tMember.strCharacterName, strPermission)
			end
			self:AddToQueue(ktMessageIcon.Promoted, strMsg)
		end
	end

	if tChangedFlags.bCanInvite and not bIsFromPromotionOrRaidAssistant then
		local strMsg = ""
		local strPermission = Apollo.GetString("Group_InvitePermission")

		if tMember.bCanInvite then
			strMsg = Apollo.GetString("Group_Enabled")
		else
			strMsg = Apollo.GetString("Group_Disabled")
		end

		if bSelf then
			strMsg = String_GetWeaselString(Apollo.GetString("Group_PermissionsChangedSelf"), strPermission, strMsg)
		elseif GroupLib.AmILeader() then
			strMsg = String_GetWeaselString(Apollo.GetString("Group_PermissionsChangedOther"), strMsg, tMember.strCharacterName, strPermission)
		end
		self:AddToQueue(ktMessageIcon.Promoted, strMsg)
	end


	if tChangedFlags.bDisconnected then
		if tMember.bDisconnected then
			local strMsg = String_GetWeaselString(Apollo.GetString("Group_CharacterDisconnected"), tMember.strCharacterName)
			self:AddToQueue(ktMessageIcon.Joined, strMsg)
		else
			local strMsg = String_GetWeaselString(Apollo.GetString("Group_CharacterConnected"), tMember.strCharacterName)
			self:AddToQueue(ktMessageIcon.Left, strMsg)
		end
		self:OnGroupUpdated()
	end

	if tChangedFlags.bMainTank and not bIsFromPromotion then
		local strRole = Apollo.GetString("Group_MainTank")
		local strMsg = ""

		if tMember.bMainTank then
			strMsg = Apollo.GetString("Group_GainsRole")
		else
			strMsg = Apollo.GetString("Group_LosesRole")
		end

		strMsg = String_GetWeaselString(strMsg, tMember.strCharacterName, strRole)
		ChatSystemLib.PostOnChannel(self.eChatChannel, strMsg, "")
	end

	if tChangedFlags.bMainAssist and not bIsFromPromotion then
		local strRole = Apollo.GetString("Group_MainAssist")
		local strMsg = ""

		if tMember.bMainAssist then
			strMsg = Apollo.GetString("Group_GainsRole")
		else
			strMsg = Apollo.GetString("Group_LosesRole")
		end

		strMsg = String_GetWeaselString(strMsg, tMember.strCharacterName, strRole)
		ChatSystemLib.PostOnChannel(self.eChatChannel, strMsg, "")
	end

	if tChangedFlags.bRaidAssistant and not bIsFromPromotion then
		local strRole = Apollo.GetString("Group_RaidAssist")
		local strMsg = ""

		if tMember.bRaidAssistant then
			strMsg = Apollo.GetString("Group_GainsRole")
		else
			strMsg = Apollo.GetString("Group_LosesRole")
		end

		strMsg = String_GetWeaselString(strMsg, tMember.strCharacterName, strRole)
		ChatSystemLib.PostOnChannel(self.eChatChannel, strMsg, "")
	end

	if tChangedFlags.bRoleLocked then
		-- TODO: To lower spam, just show this message once
		if bSelf then
			local strMsg = ""

			if tMember.bRoleLocked then
				strMsg = Apollo.GetString("Group_RaidRoleLock")
			else
				strMsg = Apollo.GetString("Group_RaidRoleUnlock")
			end

			ChatSystemLib.PostOnChannel(self.eChatChannel, strMsg, "")
		end
	end

	if tChangedFlags.bCanMark then
		if not bIsFromPromotionOrRaidAssistant then
			local strMsg = ""

			if tMember.bCanMark then
				strMsg = String_GetWeaselString(Apollo.GetString("Group_CanMark"), tMember.strCharacterName)
			else
				strMsg = String_GetWeaselString(Apollo.GetString("Group_CanNotMark"), tMember.strCharacterName)
			end

			ChatSystemLib.PostOnChannel(self.eChatChannel, strMsg, "")
		end
	end

end


function GroupDisplay:OnGroupReadyCheck(nMemberIndex, strMessage)
	local tMember = GroupLib.GetGroupMember(nMemberIndex)

	local strName = ""
	if tMember then
		strName = tMember.strCharacterName
	end

	ChatSystemLib.PostOnChannel( self.eChatChannel, String_GetWeaselString(Apollo.GetString("Group_ReadyCheckStarted"), strName, {["strLiteral"] = strMessage}), "" )
end


function GroupDisplay:OnGroupInviteResult(strCharacterName, eResult)

	Apollo.DPF("GroupDisplay:OnGroupInviteResult")

    local unitMe = GameLib.GetPlayerUnit()
    if unitMe == nil then
		return
    end

	if ktInviteResultStrings[eResult] then
		local strMsg = ktInviteResultStrings[eResult].strMsg

		if string.find(ktInviteResultStrings[eResult].strMsg, "%$1n") then
			strMsg = String_GetWeaselString(ktInviteResultStrings[eResult].strMsg, strCharacterName)
		end

		self:AddToQueue(ktInviteResultStrings[eResult].strIcon, strMsg)

		if eResult == GroupLib.Result.ExpiredInvitee then
			self.fInviteTimerStartTime = nil
			self.wndGroupInviteDialog:Show(false)
		end
	end
end

function GroupDisplay:OnGroupRequestResult(strCharacterName, eResult, bIsJoin)
	Apollo.DPF("GroupDisplay:OnGroupRequestResult")

    local unitMe = GameLib.GetPlayerUnit()
    if unitMe == nil then
		return
    end

	if bIsJoin then
		if ktJoinRequestResultStrings[eResult] then
			local strMsg = ktJoinRequestResultStrings[eResult].strMsg

			if string.find(ktJoinRequestResultStrings[eResult].strMsg, "%$1n") then
				strMsg = String_GetWeaselString(ktJoinRequestResultStrings[eResult].strMsg, strCharacterName)
			end

			self:AddToQueue(ktJoinRequestResultStrings[eResult].strIcon, strMsg)

			if eResult == GroupLib.Result.ExpiredInvitee then
				self.wndRequest:Show(false)
			end
		end
	else
		if ktReferralStrings[eResult] then
			local strMsg = ktReferralStrings[eResult].strMsg

			if string.find(ktReferralStrings[eResult].strMsg, "%$1n") then
				strMsg = String_GetWeaselString(ktReferralStrings[eResult].strMsg, strCharacterName)
			end

			self:AddToQueue(ktReferralStrings[eResult].strIcon, strMsg)

			if eResult == GroupLib.Result.ExpiredInvitee then
				self.wndRequest:Show(false)
			end
		end
	end
end

function GroupDisplay:CloseGroupHUD() -- see if the HUD can be closed
	if (GroupLib.InGroup() and GroupLib.GetMemberCount() > 0) or not self.tMessageQueue:Empty() then
		return
	end

	self.wndGroupHud:Close()
end

---------------------------------------------------------------------------------------------------
-- Message Queue
---------------------------------------------------------------------------------------------------
function GroupDisplay:AddToQueue(nMessageIcon, strMessageText)
	local tMessageInfo = {nIcon = nMessageIcon, strText = strMessageText}
	self.tMessageQueue:Push(tMessageInfo)

	ChatSystemLib.PostOnChannel(self.eChatChannel, strMessageText, "")

	if self.wndGroupMessage:IsVisible() == true then
		return
	else
		self:ProcessAlerts()
	end
end

function GroupDisplay:ProcessAlerts()
	self:ClearFields()

	if self.tMessageQueue:Empty() then
		self:HelperResizeGroupContents()
		self:CloseGroupHUD()
		return
	end

	local tMessage = self.tMessageQueue:Pop()
	self:DisplayAlert(tMessage.nIcon, tMessage.strText)
end

function GroupDisplay:DisplayAlert(nMessageIcon, strMessageText)
	if strMessageText == nil then
		self:ProcessAlerts()
		return
	end

	self.wndGroupMessage:FindChild(karMessageIconString[nMessageIcon]):Show(true)
	self.wndGroupMessage:FindChild("MessageText"):SetText(strMessageText)

	if not GroupLib.InGroup() then -- message when not grouped
		self.wndGroupHud:FindChild("GroupControlsBtn"):Show(false)
		--self.wndGroupHud:FindChild("GroupBagBtn"):Show(false) -- TODO TEMP DISABLED
		self.wndGroupHud:Show(true)
	end

	self.wndGroupMessage:Invoke()
	self:HelperResizeGroupContents()

	self.wndGroupMessage:FindChild("MessageBirthAnimation"):ToFront()
	self.wndGroupMessage:FindChild("MessageBirthAnimation"):SetSprite("sprWinAnim_BirthSmallTemp")

	Apollo.CreateTimer("GroupMessageTimer", kfMessageDuration, false)
end

---------------------------------------------------------------------------------------------------
function GroupDisplay:OnGroupMessageTimer()
	self.wndGroupMessage:FindChild("MessageBirthAnimation"):ToFront()
	self.wndGroupMessage:FindChild("MessageBirthAnimation"):SetSprite("sprWinAnim_BirthSmallTemp")

	self.wndGroupMessage:Show(false)
	self:HelperResizeGroupContents()
	Apollo.CreateTimer("GroupMessageDelayTimer", kfDelayDuration, false) -- routes back to process alerts
end

---------------------------------------------------------------------------------------------------
function GroupDisplay:ClearFields() --clear everything
	for idx =1, #karMessageIconString do
		self.wndGroupMessage:FindChild(karMessageIconString[idx]):Show(false)
	end
	self.wndGroupMessage:FindChild("MessageText"):SetText("")
	self.wndGroupMessage:FindChild("MessageBirthAnimation"):SetSprite("")
end

function GroupDisplay:OnGroupWrongInstance()
	GroupLib.GotoGroupInstance()
end

---------------------------------------------------------------------------------------------------
-- HELPER
---------------------------------------------------------------------------------------------------

function GroupDisplay:HelperResizeGroupContents()
	local nOnGoingHeight = 0
	for key, wndCurr in pairs(self.wndGroupPortraitContainer:GetChildren()) do
		if wndCurr:IsShown() then
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			nOnGoingHeight = nOnGoingHeight + (nBottom - nTop)
		end
	end
	self.wndGroupPortraitContainer:ArrangeChildrenVert()
	self.wndGroupPortraitContainer:SetAnchorOffsets(0, 0, 0, nOnGoingHeight)

	if self.wndGroupMessage:IsShown() then
		local nLeft, nTop, nRight, nBottom = self.wndGroupMessage:GetAnchorOffsets()
		nOnGoingHeight = nOnGoingHeight + (nBottom - nTop)
	end

	if self.wndLeaveGroup:IsShown() then
		local nLeft, nTop, nRight, nBottom = self.wndLeaveGroup:GetAnchorOffsets()
		nOnGoingHeight = nOnGoingHeight + (nBottom - nTop)
	end

	self.wndGroupHud:FindChild("GroupArrangeVert"):ArrangeChildrenVert(0)

	local nLeft, nTop, nRight, nBottom = self.wndGroupHud:GetAnchorOffsets()
	self.wndGroupHud:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOnGoingHeight + 47) -- TODO Hard coded formatting
end

---------------------------------------------------------------------------------------------------
-- MENTORING
---------------------------------------------------------------------------------------------------

function GroupDisplay:OnGroupMentor(tMemberList, bCurrentlyMentoring, bUpdateOnly)
	-- if this is just an update, only continue if the window is currently shown
	if not self.wndMentor:IsShown() and bUpdateOnly then
		return
	end

	self.wndMentor:FindChild("MentorMemberList"):DestroyChildren()
	self.tMentorItems = {}

	-- display the passed-in data
	local nMemberCount = table.getn(tMemberList)
	for idx = 1, nMemberCount do
		if tMemberList[idx].unitMentee ~= nil then
			local wndEntry = Apollo.LoadForm(self.xmlDoc, "GroupMentorItem", self.wndMentor:FindChild("MentorMemberList"), self)
			wndEntry:FindChild("MentorMemberBtn"):SetData(tMemberList[idx].unitMentee)
			wndEntry:FindChild("MentorMemberLevel"):SetText(tMemberList[idx].tMemberInfo.nLevel)
			wndEntry:FindChild("MentorMemberName"):SetText(tMemberList[idx].tMemberInfo.strCharacterName)
			wndEntry:FindChild("MentorMemberPathIcon"):SetSprite(ktInvitePathIcons[tMemberList[idx].tMemberInfo.ePathType])

			local strClassSprite = ""
			if ktInviteClassIcons[tMemberList[idx].tMemberInfo.eClassId] then
				strClassSprite = ktInviteClassIcons[tMemberList[idx].tMemberInfo.eClassId]
			end

			wndEntry:FindChild("MentorMemberClass"):SetSprite(strClassSprite)

			self.tMentorItems[idx] = wndEntry
		end
	end

	-- fill in any blank entries
	local nOpenSlots = 4 - (nMemberCount - 1) -- window max less count minus one (the player, who isn't shown)
	if nOpenSlots > 0 then -- make sure it's not running a negative
		for nBlankEntry = 1, nOpenSlots do -- populate the interface
			local wndBlankEntry = Apollo.LoadForm(self.xmlDoc, "GroupInviteBlank", self.wndMentor:FindChild("MentorMemberList"), self)
		end
	end

	self.wndMentor:FindChild("MentorMemberList"):ArrangeChildrenVert()

	self.wndMentor:FindChild("MentorPlayerBtn"):Enable(false) -- never a case where this is enabled off the bat
	self.wndMentor:FindChild("CancelMentoringBtn"):Enable(bCurrentlyMentoring)

	if not self.fMentorTimerStartTime then
		self.fMentorTimerStartTime = os.clock()
	end

	self.fMentorTimerDiff = os.clock() - self.fMentorTimerStartTime


	local strTime = string.format("%d:%02d", math.floor((knMentorTimeout - self.fMentorTimerDiff) / 60), math.floor((knMentorTimeout - self.fMentorTimerDiff) % 60))
	self.wndMentor:FindChild("Timer"):SetText(String_GetWeaselString(Apollo.GetString("Group_ExpiresTimer"), strTime))
	self.wndMentor:FindChild("Timer"):SetData(knMentorTimeout)
	Apollo.CreateTimer("MentorTimer", 1.000, false)

	self.wndMentor:Show(true)
end

function GroupDisplay:OnToggleMentorItem(wndHandler, wndCtrl)
	-- this is the list item that has a player. We'll want to save this so the "Mentor Player" button can be activated
	local unitStudent = wndCtrl:GetData()

	if unitStudent == nil then -- no idea how that would happen but whatever
		return
	end

	for idx, wndCurr in pairs(self.tMentorItems) do
		local unitData = wndCurr:FindChild("MentorMemberBtn"):GetData()
		wndCurr:FindChild("MentorMemberBtn"):SetCheck(unitStudent == unitData)
	end

	self.wndMentor:FindChild("MentorPlayerBtn"):SetData(unitStudent)
	self.wndMentor:FindChild("MentorPlayerBtn"):Enable(true)
end

function GroupDisplay:OnMentorPlayerBtn(wndHandler, wndCtrl)
	-- this is the button for mentoring a player selected in the list
	local unitStudent = wndCtrl:GetData()

	if unitStudent == nil then
		return
	end

	GroupLib.AcceptMentoring(unitStudent)

	self.wndMentor:Show(false)
	self.fMentorTimerStartTime = nil
	Apollo.StopTimer("MentorTimer")
end

function GroupDisplay:OnCancelMentoringBtn(wndHandler, wndCtrl)
	-- this is the button for canceling the mentoring status of this player
	GroupLib.CancelMentoring()

	self.wndMentor:Show(false)
	self.fMentorTimerStartTime = nil
	Apollo.StopTimer("MentorTimer")
end

function GroupDisplay:OnMentorCloseBtn(wndHandler, wndCtrl)
	self.wndMentor:Show(false)
	self.fMentorTimerStartTime = nil
	Apollo.StopTimer("MentorTimer")

	GroupLib.CloseMentoringDialog()
end

function GroupDisplay:OnMentorTimer()
	-- This is the timer that's shown on the window

	self.fMentorTimerDiff = self.fMentorTimerDiff + 1
	if self.fMentorTimerDiff <= knMentorTimeout then
		local strTime = string.format("%d:%02d", math.floor((knMentorTimeout - self.fMentorTimerDiff) / 60), math.ceil((knMentorTimeout - self.fMentorTimerDiff) % 60))
		self.wndMentor:FindChild("Timer"):SetText(String_GetWeaselString(Apollo.GetString("Group_ExpiresTimer"), strTime))
		self.wndMentor:FindChild("Timer"):SetData(self.fMentorTimerDiff)
		Apollo.StartTimer("MentorTimer")
	else
		Event_FireGenericEvent("GenericEvent_SystemChannelMessage", Apollo.GetString("GroupDisplay_MentorWindowTimedOut"))
		self:OnMentorCloseBtn()
	end
end

function GroupDisplay:OnGroupMentorLeftAOI(nTimeUntilMentoringDisabled, bClearUI)
	if bClearUI then
		self.wndMentorAOI:Show(false)
		Apollo.StopTimer("MentorAOITimer")
		return
	end

	local strTime = string.format("%d:%02d", math.floor(nTimeUntilMentoringDisabled / 60), math.floor(nTimeUntilMentoringDisabled % 60))
	self.wndMentorAOI:FindChild("Timer"):SetText(String_GetWeaselString(Apollo.GetString("Group_ExpiresTimer"), strTime))
	self.wndMentorAOI:FindChild("Timer"):SetData(nTimeUntilMentoringDisabled)
	Apollo.CreateTimer("MentorAOITimer", 1.000, false)

	self.wndMentorAOI:Show(true)
end

function GroupDisplay:OnMentorAOICloseBtn()
	self.wndMentorAOI:Show(false)
	Apollo.StopTimer("MentorAOITimer")

	GroupLib.CloseMentoringAOIDialog()
end

function GroupDisplay:OnMentorAOITimer()
	-- This is the timer that's shown on the window
	local nTimerValue = self.wndMentorAOI:FindChild("Timer"):GetData()
	nTimerValue = nTimerValue - 1
	if nTimerValue >= 0 then
		local strTime = string.format("%d:%02d", math.floor(nTimerValue / 60), math.floor(nTimerValue % 60))
		self.wndMentorAOI:FindChild("Timer"):SetText(String_GetWeaselString(Apollo.GetString("Group_ExpiresTimer"), strTime))
		self.wndMentorAOI:FindChild("Timer"):SetData(nTimerValue)
		Apollo.CreateTimer("MentorAOITimer", 1.000, false)
	else
		self:OnMentorAOICloseBtn()
	end
end

function GroupDisplay:OnAcceptRequest()
	self.wndRequest:Show(false)
	GroupLib.AcceptRequest()
end

function GroupDisplay:OnDenyRequest()
	self.wndRequest:Show(false)
	GroupLib.DenyRequest()
end

---------------------------------------------------------------------------------------------------
-- RaidConvertedForm Functions
---------------------------------------------------------------------------------------------------

function GroupDisplay:OnRaidOkay( wndHandler, wndControl, eMouseButton )
	if self.wndRaidNotice and self.wndRaidNotice:IsValid() then
		local wndDoNotShowAgain = self.wndRaidNotice:FindChild("NeverShowAgainButton")
		if wndDoNotShowAgain:IsChecked() then
			self.bNeverShowRaidConvertNotice = true
		end

		self.wndRaidNotice:Destroy()
		self.wndRaidNotice = nil
	end
end

---------------------------------------------------------------------------------------------------
-- GroupDisplay instance
---------------------------------------------------------------------------------------------------
local GroupFrameInst = GroupDisplay:new()
GroupDisplay:Init()
