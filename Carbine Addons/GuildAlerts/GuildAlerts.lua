-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildAlerts
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "ChatSystemLib"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"

local knTypeString = 1
local knTypeFunction = 2

local ktResultMap = {
	[GuildLib.GuildResult_Success] = { nType = knTypString, value = Apollo.GetString("GuildResult_Success"), arParameters = { } },
	[GuildLib.GuildResult_AtMaxGuildCount] = { nType = knTypeString, value = Apollo.GetString("GuldResult_AtMaxCount"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_MaxWarPartyCount] = { nType = knTypeString, value = Apollo.GetString("GuldResult_AtMaxCount"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_AtMaxCircleCount] = { nType = knTypeString, value = Apollo.GetString("GuldResult_AtMaxCount"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_MaxArenaTeamCount] = { nType = knTypeString, value = Apollo.GetString("GuildResult_MaxArenaTeamForSize"), arParameters = { } },
	[GuildLib.GuildResult_CannotModifyResidenceWithActiveGame] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), arParameters = { "strResidence" } },
	[GuildLib.GuildResult_GenericActiveGameFailure] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_CannotChangeRanksWithActiveGame] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_CannotChangePermissionsWithActiveGame] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_CannotEditBankWithActiveGame] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_InvalidGuildName] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidGuildName"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_NotInThatGuild] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotInThatGuild"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_UnknownCharacter] = { nType = knTypeString, value = Apollo.GetString("GuildResult_UnknownCharacter"), arParameters = { "tName" } },
	[GuildLib.GuildResult_CharacterCannotJoinMoreGuilds] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CharacterMaxGuilds"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_CharacterAlreadyHasAGuildInvite] = { nType = knTypeString, value = Apollo.GetString("GuildResult_AlreadyHasInvite"), arParameters = { "tName" } },
	[GuildLib.GuildResult_CharacterInvited] = { nType = knTypeString, value = Apollo.GetString("GuildResult_AlreadyInvited"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_GuildmasterCannotLeaveGuild] = { nType = knTypeString, value = Apollo.GetString("GuildResult_GuildmasterCannotLeave"), arParameters = { "strGuildMaster", "strGuildType" } },
	[GuildLib.GuildResult_CharacterNotInYourGuild] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotInYourGuild"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_CannotKickHigherOrEqualRankedMember] = { nType = knTypeString, value = Apollo.GetString("GuildResult_UnableToKick"), arParameters = { "tName" } },
	[GuildLib.GuildResult_KickedMember] = { nType = knTypeString, value = Apollo.GetString("GuildResult_HasBeenKicked"), arParameters = { "tName" } },
	[GuildLib.GuildResult_NoPendingInvites] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NoPendingInvites"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_PendingInviteExpired] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InviteExpired"), arParameters = { "tName" } },
	[GuildLib.GuildResult_CannotPromoteMemberAboveYourRank] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotPromote"), arParameters = { "tName" } },
	[GuildLib.GuildResult_PromotedToGuildMaster] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PromotedToLeader"), arParameters = { "tName", "strGuildMaster" } },
	[GuildLib.GuildResult_PromotedMember] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PlayerPromoted"), arParameters = { "tName" } },
	[GuildLib.GuildResult_CanOnlyDemoteLowerRankedMembers] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotDemote"), arParameters = { "tName" } },
	[GuildLib.GuildResult_MemberIsAlreadyLowestRank] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotDemoteLowestRank"), arParameters = { "tName" } },
	[GuildLib.GuildResult_DemotedMember] = { nType = knTypeString, value = Apollo.GetString("GuildResult_MemberDemoted"), arParameters = { "tName" } },
	[GuildLib.GuildResult_InvalidRank] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidRank"), arParameters = { "tRank" } },
	[GuildLib.GuildResult_InvalidRankName] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidRankName"), arParameters = { "strGuildType", "tName" } },
	[GuildLib.GuildResult_CanOnlyDeleteEmptyRanks] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CanOnlyDeleteEmptyRank"), arParameters = { } },
	[GuildLib.GuildResult_VoteAlreadyInProgress] = { nType = knTypeString, value = Apollo.GetString("GuildResult_VoteInProgress"), arParameters = { } },
	[GuildLib.GuildResult_AlreadyCastAVote] = { nType = knTypeString, value = Apollo.GetString("GuildResult_AlreadyVoted"), arParameters = { } },
	[GuildLib.GuildResult_InvalidElection] = { nType = knTypeString, value = Apollo.GetString("GuildResult_VoteInvalidated"), arParameters = { "tName" } },
	[GuildLib.GuildResult_VoteFailedToPass] = { nType = knTypeString, value = Apollo.GetString("GuildResult_VoteFailed"), arParameters = { "tName" } },
	[GuildLib.GuildResult_NoVoteInProgress] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NoVoteInProgress"), arParameters = { } },
	[GuildLib.GuildResult_MemberAlreadyGuildMaster] = { nType = knTypeString, value = Apollo.GetString("GuildResult_AlreadyLeader"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_VoteStarted] = { nType = knTypeString, value = Apollo.GetString("GuildResult_VoteStarted"), arParameters = { "strGuildType", "tName" } },
	[GuildLib.GuildResult_InviteAccepted] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PlayerJoined"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_InviteDeclined] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InviteDeclined"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_GuildNameUnavailable] = { nType = knTypeString, value = Apollo.GetString("GuildRegistration_NameUnavailable"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_GuildDisbanded] = { nType = knTypeString, value = Apollo.GetString("GuildResult_Disbanded"), arParameters = { "tName" } },
	[GuildLib.GuildResult_RankModified] = { nType = knTypeString, value = Apollo.GetString("GuildResult_RankModified"), arParameters = { "tRank", "tName" } },
	[GuildLib.GuildResult_RankCreated] = { nType = knTypeString, value = Apollo.GetString("GuildResult_RankCreated"), arParameters = { "tName" } },
	[GuildLib.GuildResult_RankDeleted] = { nType = knTypeString, value = Apollo.GetString("GuildResult_RankDeleted"), arParameters = { "tRank", "tName" } },
	[GuildLib.GuildResult_UnableToProcess] = { nType = knTypeString, value = Apollo.GetString("GuildResult_UnableToProcess"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_MemberQuit] = { nType = knTypeString, value = Apollo.GetString("GuildResult_MemberQuit"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_Voted] = { nType = knTypeString, value = Apollo.GetString("GuildResult_Voted"), arParameters = { "tName" } },
	[GuildLib.GuildResult_VotePassed] = { nType = knTypeString, value = Apollo.GetString("GuildResult_VotePassed"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_GuildLoading] = { nType = knTypeString, value = Apollo.GetString("GuildResult_Loading"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_KickedYou] = { nType = knTypeString, value = Apollo.GetString("GuildResult_YouHaveBeenKicked"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_CanOnlyModifyRanksBelowYours] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CanOnlyModifyLowerRanks"), arParameters = { } },
	[GuildLib.GuildResult_YouQuit] = { nType = knTypeString, value = Apollo.GetString("GuildResult_YouLeft"), arParameters = { "tName" } },
	[GuildLib.GuildResult_YouJoined] = { nType = knTypeString, value = Apollo.GetString("GuildResult_YouJoined"), arParameters = { "tName" } },
	[GuildLib.GuildResult_RankRenamed] = { nType = knTypeString, value = Apollo.GetString("GuildResult_RankRenamed"), arParameters = { "tRank", "tName" } },
	[GuildLib.GuildResult_MemberOnline] = { nType = knTypeString, value = Apollo.GetString("GuildResult_MemberOnline"), arParameters = { "tName" } },
	[GuildLib.GuildResult_MemberOffline] = { nType = knTypeString, value = Apollo.GetString("GuildResult_MemberOffline"), arParameters = { "tName" } },
	[GuildLib.GuildResult_CannotInviteGuildFull] = { nType = knTypeString, value = Apollo.GetString("GuildResult_GuildFull"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_VoteTooRecentToHaveAnother] = { nType = knTypeString, value = Apollo.GetString("GuildResult_TooSoonToVote"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_NotInAGuild] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotInAGuild"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_InvalidFlags] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidFlags"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_StandardChanged] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BannerChanged"),	arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_NotAGuild] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotAGuild"), arParameters = { } },
	[GuildLib.GuildResult_InvalidStandard] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidBanner"),	arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_YouCreated] = { nType = knTypeString, value = Apollo.GetString("GuildResult_GuildCreated"), arParameters = { "tName" } },
	[GuildLib.GuildResult_VendorOutOfRange] = { nType = knTypeString, value = Apollo.GetString("GuildDesigner_OutOfRange"), arParameters = { } },
	[GuildLib.GuildResult_NotABankTab] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotABankTab"), arParameters = { } },
	[GuildLib.GuildResult_BankerOutOfRange] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankerOutOfRange"), arParameters = { } },
	[GuildLib.GuildResult_NoBank] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NoBank"), arParameters = { } },
	[GuildLib.GuildResult_BankTabAlreadyLoaded] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabAlreadyLoaded"), arParameters = { } },
	[GuildLib.GuildResult_NoBankItemSelected ] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NoBankItemSelected"), arParameters = { } },
	[GuildLib.GuildResult_BankItemMoved] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankItemMoved"), arParameters = { } },
	[GuildLib.GuildResult_RankLacksRankRenamePermission] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NoRenamePermission"), arParameters = { } },
	[GuildLib.GuildResult_InvalidBankTabName] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidBankTabName"), arParameters = { "tName" } },
	[GuildLib.GuildResult_CannotWithdrawBankItem] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CanNotWithdrawBankItem"), arParameters = { } },
	[GuildLib.GuildResult_BankTabNotLoaded] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabNotLoaded"), arParameters = { "tRank" } },
	[GuildLib.GuildResult_CannotDepositBankItem] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotDepositItem"), arParameters = { } },
	[GuildLib.GuildResult_AlreadyAMember] = { nType = knTypeString, value = Apollo.GetString("GuildResult_AlreadyAMember"), arParameters = { "tName" } },
	[GuildLib.GuildResult_BankTabWithdrawsExceeded] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankWithdrawsExceeded"), arParameters = { } },
	[GuildLib.GuildResult_BankTabNotVisible] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabNotVisible"), arParameters = { } },
	[GuildLib.GuildResult_BankTabDoesNotAcceptDeposits] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabDoesNotAcceptDeposits"), arParameters = { } },
	[GuildLib.GuildResult_BankTabRequiresAuthenticator] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabRequiresAuthenticator"), arParameters = { } },
	[GuildLib.GuildResult_BankTabCannotWithdraw] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabCannotWithdraw"), arParameters = { } },
	[GuildLib.GuildResult_InsufficientInfluence] = { nType = knTypeString, value = Apollo.GetString("GuildDesigner_NotEnoughInfluence"), arParameters = { } },
	[GuildLib.GuildResult_RequiresPrereq] = { nType = knTypeString, value = Apollo.GetString("GuildResult_RequiresPrereq"), arParameters = { } },
	[GuildLib.GuildResult_BankTabBought] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabBought"), arParameters = { "tName" } },
	[GuildLib.GuildResult_ExceededMoneyWithdrawLimitToday] = { nType = knTypeString, value = Apollo.GetString("GuildResult_WithdrawLimitExceeded"), arParameters = { } },
	[GuildLib.GuildResult_InsufficientMoneyInGuild] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotEnoughMoneyInGuild"), arParameters = { } },
	[GuildLib.GuildResult_InsufficientMoneyOnCharacter] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotEnoughMoneyOnCharacter"), arParameters = { } },
	[GuildLib.GuildResult_NotEnoughRenown] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotEnoughRenown"), arParameters = { } },
	[GuildLib.GuildResult_CannotDisbandTeamWithActiveGame] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotDisbandWithActiveGame"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_CannotLeaveTeamWithActiveGame] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotLeaveTeamWithActiveGame"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_CannotRemoveFromTeamWithActiveGame] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotKickWithActiveGame"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_InsufficientWarCoins] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InsufficientWarCoins"), arParameters = { } },
	[GuildLib.GuildResult_PerkDoesNotExist] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PerkDoesNotExist"), arParameters = { } },
	[GuildLib.GuildResult_PerkIsAlreadyUnlocked] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PerkAlreadyUnlocked"), arParameters = { } },
	[GuildLib.GuildResult_PerkIsAlreadyActive] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PerkIsAlreadyActive"), arParameters = { } },
	[GuildLib.GuildResult_RequiresPerkPurchase] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PerkPrereqNotMet"), arParameters = { } },
	[GuildLib.GuildResult_PerkNotActivateable] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PerkCanNotActivate"), arParameters = { } },
	[GuildLib.GuildResult_PrivilegeRestricted] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PrivilegeRestricted"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_InvalidMessageOfTheDay] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidMotD"), arParameters = { } },
	[GuildLib.GuildResult_InvalidMemberNote] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidNote"), arParameters = { } },
	[GuildLib.GuildResult_InsufficentMembers] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InsufficientMembers"), arParameters = { } },
	[GuildLib.GuildResult_NotAWarParty] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotAWarParty"), arParameters = { } },
	[GuildLib.GuildResult_RequiresAchievement] = { nType = knTypeString, value = Apollo.GetString("GuildResult_PerkRequiresAchievement"), arParameters = { } },
	[GuildLib.GuildResult_NotAValidWarPartyItem] = { nType = knTypeString, value = Apollo.GetString("GuildResult_NotAValidWarPartyItem"), arParameters = { } },
	[GuildLib.GuildResult_InvalidGuildInfo] = { nType = knTypeString, value = Apollo.GetString("GuildResult_InvalidGuildInfo"), arParameters = { } },
	[GuildLib.GuildResult_NotEnoughCredits] = { nType = knTypeString, value = Apollo.GetString("GuildRegistration_NeedMoreCredit"), arParameters = { } },
	[GuildLib.GuildResult_CannotDeleteDefaultRanks] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotDeleteDefaultRanks"), arParameters = { "tRank" } },
	[GuildLib.GuildResult_DuplicateRankName] = { nType = knTypeString, value = Apollo.GetString("GuildResult_DuplicateRankName"), arParameters = { "tName" } },
	[GuildLib.GuildResult_InviteSent] = { nType = knTypeString, value = Apollo.GetString("Guild_InviteSent"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_BankTabInvalidPermissions] = { nType = knTypeString, value = Apollo.GetString("GuildResult_BankTabInvalidPermissions"), arParameters = { "tName", "strGuildType" } },
	[GuildLib.GuildResult_Busy] = { nType = knTypeString, value = Apollo.GetString("GuildResult_Busy"), arParameters = { "strGuildType" } },
	[GuildLib.GuildResult_CannotCreateWhileInQueue] = { nType = knTypeString, value = Apollo.GetString("GuildResult_CannotCreateWhileInQueue"), arParameters = { } },
	[GuildLib.GuildResult_RenameNotAvailable] = { nType = knTypeString, value = Apollo.GetString("GuildResult_RenameNotAvailable"), arParameters = { } },
	[GuildLib.GuildResult_RankLacksSufficientPermissions] = { nType = knTypeFunction, value = function(bIntercepted) return bIntercepted and Apollo.GetString("GuildDesigner_NoPermissions") or Apollo.GetString("GuildResult_InsufficientPermissions") end, arParameters = { "bIntercepted" } },
	[GuildLib.GuildResult_NotHighEnoughLevel] = { nType = knTypeFunction, value = function(eGuildType, strGuildType)
		local strResult
		if eGuildType and (eGuildType == GuildLib.GuildType_ArenaTeam_2v2 or eGuildType == GuildLib.GuildType_ArenaTeam_3v3 or eGuildType == GuildLib.GuildType_ArenaTeam_5v5) then
			strResult = Apollo.GetString("ArenaTeamRegistration_NotHighEnoughLevel")
		elseif eGuildType and (eGuildType == GuildLib.GuildType_Guild) then
			strResult = String_GetWeaselString(Apollo.GetString("GuildRegistration_NotHighEnoughLevel"), strGuildType, GuildLib.GetMinimumLevel(eGuildType))
		elseif eGuildType and (eGuildType == GuildLib.GuildType_WarParty) then
			strResult = String_GetWeaselString(Apollo.GetString("Warparty_NotHighEnoughLevel"), Apollo.GetString("Guild_GuildTypeWarparty"), GuildLib.GetMinimumLevel(eGuildType))
		else
			strResult = Apollo.GetString("CRB_LevelRequirementsNotMet")
		end
		return strResult
	end, arParameters = { "eGuildType", "strGuildType" } },
}


local GuildAlerts = {}

function GuildAlerts:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GuildAlerts:Init()
    Apollo.RegisterAddon(self)
end

function GuildAlerts:OnLoad()
	self.tIntercept = nil
	Apollo.RegisterEventHandler("GuildResult", "OnGuildResult", self) -- game client initiated events
	Apollo.RegisterEventHandler("GuildResultInterceptRequest", "OnGuildResultInterceptRequest", self) -- lua initiated events
	Apollo.RegisterEventHandler("GuildMessageOfTheDay", "OnGuildMessageOfTheDay", self)
end

-----------------------------------------------------------------------------------------------
-- GuildAlerts Event Handlers
-----------------------------------------------------------------------------------------------

function GuildAlerts:OnGuildResultInterceptRequest( eGuildType, wndIntercept, arResultSet )
	if eGuildType == nil then
		-- needs a valid guild type to process request.
		return
	end

	if wndIntercept == nil then
		-- if no window is given than this is a request to clear a previous request.
		if self.tIntercept and self.tIntercept.eGuildType == eGuildType then
			self.tIntercept = nil
		end
		return
	end

	self.tIntercept = {}
	self.tIntercept.wndIntercept = wndIntercept
	self.tIntercept.eGuildType = eGuildType
	self.tIntercept.arResultSet = arResultSet
end

function GuildAlerts:OnGuildResult(guildSender, strName, nRank, eResult )
	local strAlertMessage = self:GenerateAlert( guildSender, strName, nRank, eResult )

	if self:IsIntercepted( guildSender, eResult ) then
		Event_FireGenericEvent("GuildResultInterceptResponse", guildSender, self.tIntercept.eGuildType, eResult, self.tIntercept.wndIntercept, strAlertMessage)
		self.tIntercept = nil
	elseif guildSender and guildSender:GetChannel() then
		guildSender:GetChannel():Post(strAlertMessage, "")
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strAlertMessage, "")
	end
	
	if eResult == GuildLib.GuildResult_MemberOnline then
		Sound.Play(Sound.PlayUISocialFriendAlert)
	end
end

function GuildAlerts:OnGuildMessageOfTheDay(guildSender)
	guildSender:GetChannel():Post(guildSender:GetMessageOfTheDay(), Apollo.GetString("GuildInfo_MessageOfTheDay"))
end
-----------------------------------------------------------------------------------------------
-- GuildAlerts Functions
-----------------------------------------------------------------------------------------------

function GuildAlerts:IsIntercepted( guildSender, eResult )
	if self.tIntercept == nil then
		return false
	end

	if guildSender and guildSender:GetType() ~= self.tIntercept.eGuildType then
		return false
	end

	if self.tIntercept.arResultSet then
		for nIdx,eFilterResult in pairs(self.tIntercept.arResultSet) do
			if eFilterResult == eResult then
				-- match found
				return true
			end
		end
		-- match not found
		return false
	end

	-- no need to filter
	return true
end

function GuildAlerts:GenerateAlert(guildSender, strName, nRank, eResult )
	local strResult = String_GetWeaselString(Apollo.GetString("Guild_UnknownResult"), eResult) -- just in case

	local eGuildType = nil
	if guildSender then
		eGuildType = guildSender:GetType()
	elseif self.tIntercept then
		eGuildType = self.tIntercept.eGuildType
	end

	local strGuildType = nil
	if eGuildType == GuildLib.GuildType_Circle then
		strGuildType = Apollo.GetString("Guild_GuildTypeCircle")
	elseif eGuildType == GuildLib.GuildType_ArenaTeam_2v2 or eGuildType == GuildLib.GuildType_ArenaTeam_3v3 or eGuildType == GuildLib.GuildType_ArenaTeam_5v5 then
		strGuildType = Apollo.GetString("Guild_GuildTypeArena")
	elseif eGuildType == GuildLib.GuildType_WarParty then
		strGuildType = Apollo.GetString("Guild_GuildTypeWarparty")
	else --if eGuildType == GuildLib.GuildType_Guild then
		strGuildType = Apollo.GetString("Guild_GuildTypeGuild")
	end

	local bIntercepted = self:IsIntercepted( guildSender, eResult )

	local strResidence = Apollo.GetString("Guild_ResidenceNameDefault")
	if eGuildType == GuildLib.GuildType_WarParty then
		strResidence = Apollo.GetString("CRB_Warplot")
	end

	local strRank = ""
	
	local strGuildMaster = nil
	if guildSender then
		strGuildMaster = guildSender:GetRanks()[1].strName
		
		if nRank and nRank ~= 0 then
			strRank = guildSender:GetRanks()[nRank].strName
			if not strRank or not string.len(strRank) then
				strRank = '#' .. tostring(nRank)
			end
		end
	end

	strName = tostring(strName) -- just in case.

	local tAllParameters =
	{
		["tName"] = { ["strLiteral"] = strName },
		["tRank"] = { ["strLiteral"] = strRank },
		["strGuildType"] = strGuildType,
		["strGuildMaster"] = strGuildMaster,
		["strResidence"] = strResidence,
		["bIntercepted"] = bIntercepted,
		["eGuildType"] = eGuildType
	}
	
	local tEntry = ktResultMap[eResult]
	if tEntry ~= nil then
		local arParameters = {}
		for idx, strParameter in pairs(tEntry.arParameters) do
			arParameters[#arParameters + 1] = tAllParameters[strParameter]
		end
		
		if tEntry.nType == knTypeString then
			if #arParameters == 0 then
				strResult = tEntry.value
			else
				strResult = String_GetWeaselString(tEntry.value, unpack(arParameters))
			end
		elseif tEntry.nType == knTypeFunction then
			strResult = tEntry.value(unpack(arParameters))
		end
	end
	
	return strResult
end

-----------------------------------------------------------------------------------------------
-- GuildAlerts Instance
-----------------------------------------------------------------------------------------------
local GuildAlertsInst = GuildAlerts:new()
GuildAlertsInst:Init()
