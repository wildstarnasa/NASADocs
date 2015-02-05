-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildAlerts
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "ChatSystemLib"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"

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
	
	local tName = {["strLiteral"] = strName}
	local tRank = {["strLiteral"] = strRank}

--[[
	-- TODO remove these strings

	ArenaRegister_ResultBusy
	GuildRegistration_GuildBusy
	GuildRegistration_YouJoinedGuild
	GuildRegistration_NeedMoreRenown
	GuildResult_VendorOutOfRange
	GuildRegistration_GuildCreated
	GuildDesigner_InvalidStandard
	GuildDesigner_SystemError
	ArenaRegister_ResultNameUnavailable
	GuildDesigner_NameUnavailable
	GuildResult_NameUnavailable
	GuildDesigner_InvalidRankName
	GuildDesigner_InvalidRank
	GuildRegistration_InvalidName
	GuildDesigner_InvalidGuildName
	ArenaRegister_ResultInvaidName
	GuildRegistration_CannotCreate
	ArenaRegister_ResultMaxCount
	GuildResult_MaxGuilds
	GuildResult_MaxCircles
]]--


	if eResult == GuildLib.GuildResult_Success then									strResult = Apollo.GetString("GuildResult_Success")

	elseif eResult == GuildLib.GuildResult_AtMaxGuildCount then 					strResult = String_GetWeaselString(Apollo.GetString("GuldResult_AtMaxCount"), strGuildType)
	elseif eResult == GuildLib.GuildResult_MaxWarPartyCount then 					strResult = String_GetWeaselString(Apollo.GetString("GuldResult_AtMaxCount"), strGuildType)
	elseif eResult == GuildLib.GuildResult_AtMaxCircleCount then 					strResult = String_GetWeaselString(Apollo.GetString("GuldResult_AtMaxCount"), strGuildType)
	elseif eResult == GuildLib.GuildResult_MaxArenaTeamCount then 					strResult = Apollo.GetString("GuildResult_MaxArenaTeamForSize")

    elseif eResult == GuildLib.GuildResult_CannotModifyResidenceWithActiveGame then strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), strResidence)
	elseif eResult == GuildLib.GuildResult_GenericActiveGameFailure then 			strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), strGuildType)
	elseif eResult == GuildLib.GuildResult_CannotChangeRanksWithActiveGame then 	strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), strGuildType)
	elseif eResult == GuildLib.GuildResult_CannotChangePermissionsWithActiveGame then strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), strGuildType)
	elseif eResult == GuildLib.GuildResult_CannotEditBankWithActiveGame then 		strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotModifyWithActiveGame"), strGuildType)

	elseif eResult == GuildLib.GuildResult_InvalidGuildName then					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InvalidGuildName"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_NotInThatGuild then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_NotInThatGuild"), strGuildType)
	elseif eResult == GuildLib.GuildResult_RankLacksSufficientPermissions then 		strResult = bIntercepted and Apollo.GetString("GuildDesigner_NoPermissions") or Apollo.GetString("GuildResult_InsufficientPermissions")
	elseif eResult == GuildLib.GuildResult_UnknownCharacter then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_UnknownCharacter"), tName)
	elseif eResult == GuildLib.GuildResult_CharacterCannotJoinMoreGuilds then 		strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CharacterMaxGuilds"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_CharacterAlreadyHasAGuildInvite then		strResult = String_GetWeaselString(Apollo.GetString("GuildResult_AlreadyHasInvite"), tName)
	elseif eResult == GuildLib.GuildResult_CharacterInvited then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_AlreadyInvited"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_GuildmasterCannotLeaveGuild then 		strResult = String_GetWeaselString(Apollo.GetString("GuildResult_GuildmasterCannotLeave"), strGuildMaster, strGuildType)
	elseif eResult == GuildLib.GuildResult_CharacterNotInYourGuild then				strResult = String_GetWeaselString(Apollo.GetString("GuildResult_NotInYourGuild"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_CannotKickHigherOrEqualRankedMember then	strResult = String_GetWeaselString(Apollo.GetString("GuildResult_UnableToKick"), tName)
	elseif eResult == GuildLib.GuildResult_KickedMember then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_HasBeenKicked"), tName)
	elseif eResult == GuildLib.GuildResult_NoPendingInvites then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_NoPendingInvites"), strGuildType)
	elseif eResult == GuildLib.GuildResult_PendingInviteExpired then 				strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InviteExpired"), tName)
	elseif eResult == GuildLib.GuildResult_CannotPromoteMemberAboveYourRank then 	strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotPromote"),	tName)
	elseif eResult == GuildLib.GuildResult_PromotedToGuildMaster then 				strResult = String_GetWeaselString(Apollo.GetString("GuildResult_PromotedToLeader"), tName, strGuildMaster)
	elseif eResult == GuildLib.GuildResult_PromotedMember then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_PlayerPromoted"), tName)
	elseif eResult == GuildLib.GuildResult_CanOnlyDemoteLowerRankedMembers then 	strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotDemote"), tName)
	elseif eResult == GuildLib.GuildResult_MemberIsAlreadyLowestRank then 			strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotDemoteLowestRank"), tName)
	elseif eResult == GuildLib.GuildResult_DemotedMember then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_MemberDemoted"), tName)
	elseif eResult == GuildLib.GuildResult_InvalidRank then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InvalidRank"), tRank)
	elseif eResult == GuildLib.GuildResult_InvalidRankName then						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InvalidRankName"), strGuildType, tName)
	elseif eResult == GuildLib.GuildResult_CanOnlyDeleteEmptyRanks then				strResult = Apollo.GetString("GuildResult_CanOnlyDeleteEmptyRank")
	elseif eResult == GuildLib.GuildResult_VoteAlreadyInProgress then 				strResult = Apollo.GetString("GuildResult_VoteInProgress")
	elseif eResult == GuildLib.GuildResult_AlreadyCastAVote then 					strResult = Apollo.GetString("GuildResult_AlreadyVoted")
	elseif eResult == GuildLib.GuildResult_InvalidElection then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_VoteInvalidated"), tName)
	elseif eResult == GuildLib.GuildResult_VoteFailedToPass then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_VoteFailed"), tName)
	elseif eResult == GuildLib.GuildResult_NoVoteInProgress then 					strResult = Apollo.GetString("GuildResult_NoVoteInProgress")
	elseif eResult == GuildLib.GuildResult_MemberAlreadyGuildMaster then 			strResult = String_GetWeaselString(Apollo.GetString("GuildResult_AlreadyLeader"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_VoteStarted then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_VoteStarted"), strGuildType, tName)
	elseif eResult == GuildLib.GuildResult_InviteAccepted then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_PlayerJoined"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_InviteDeclined then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InviteDeclined"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_GuildNameUnavailable then  				strResult = String_GetWeaselString(Apollo.GetString("GuildRegistration_NameUnavailable"), strGuildType)
	elseif eResult == GuildLib.GuildResult_GuildDisbanded then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_Disbanded"), tName)
	elseif eResult == GuildLib.GuildResult_RankModified then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_RankModified"), tRank, tName)
	elseif eResult == GuildLib.GuildResult_RankCreated then							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_RankCreated"), tName)
	elseif eResult == GuildLib.GuildResult_RankDeleted then							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_RankDeleted"), tRank, tName)
	elseif eResult == GuildLib.GuildResult_UnableToProcess then						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_UnableToProcess"), strGuildType)
	elseif eResult == GuildLib.GuildResult_MemberQuit then 							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_MemberQuit"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_Voted then 								strResult = String_GetWeaselString(Apollo.GetString("GuildResult_Voted"), tName)
	elseif eResult == GuildLib.GuildResult_VotePassed then 							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_VotePassed"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_GuildLoading then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_Loading"), strGuildType)
	elseif eResult == GuildLib.GuildResult_KickedYou then 							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_YouHaveBeenKicked"),	strGuildType)
	elseif eResult == GuildLib.GuildResult_CanOnlyModifyRanksBelowYours then 		strResult = Apollo.GetString("GuildResult_CanOnlyModifyLowerRanks")
	elseif eResult == GuildLib.GuildResult_YouQuit then 							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_YouLeft"), tName)
	elseif eResult == GuildLib.GuildResult_YouJoined then 							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_YouJoined"),	tName)
	elseif eResult == GuildLib.GuildResult_RankRenamed then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_RankRenamed"), tRank, tName)
	elseif eResult == GuildLib.GuildResult_MemberOnline then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_MemberOnline"), tName)
	elseif eResult == GuildLib.GuildResult_MemberOffline then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_MemberOffline"),	tName)
	elseif eResult == GuildLib.GuildResult_CannotInviteGuildFull then 				strResult = String_GetWeaselString(Apollo.GetString("GuildResult_GuildFull"),	tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_VoteTooRecentToHaveAnother then 			strResult = String_GetWeaselString(Apollo.GetString("GuildResult_TooSoonToVote"),	strGuildType)
	elseif eResult == GuildLib.GuildResult_NotInAGuild then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_NotInAGuild"), strGuildType)
	elseif eResult == GuildLib.GuildResult_InvalidFlags then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InvalidFlags"), strGuildType)
	elseif eResult == GuildLib.GuildResult_StandardChanged then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_BannerChanged"),	strGuildType)
	elseif eResult == GuildLib.GuildResult_NotAGuild then 							strResult = Apollo.GetString("GuildResult_NotAGuild")
	elseif eResult == GuildLib.GuildResult_InvalidStandard then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InvalidBanner"),	strGuildType)
	elseif eResult == GuildLib.GuildResult_YouCreated then 							strResult = String_GetWeaselString(Apollo.GetString("GuildResult_GuildCreated"), tName)
	elseif eResult == GuildLib.GuildResult_VendorOutOfRange then 					strResult = Apollo.GetString("GuildDesigner_OutOfRange")
	elseif eResult == GuildLib.GuildResult_NotABankTab then 						strResult = Apollo.GetString("GuildResult_NotABankTab")
	elseif eResult == GuildLib.GuildResult_BankerOutOfRange then 					strResult = Apollo.GetString("GuildResult_BankerOutOfRange")
	elseif eResult == GuildLib.GuildResult_NoBank then 								strResult = Apollo.GetString("GuildResult_NoBank")
	elseif eResult == GuildLib.GuildResult_BankTabAlreadyLoaded then 				strResult = Apollo.GetString("GuildResult_BankTabAlreadyLoaded")
	elseif eResult == GuildLib.GuildResult_NoBankItemSelected  then 				strResult = Apollo.GetString("GuildResult_NoBankItemSelected")
	elseif eResult == GuildLib.GuildResult_BankItemMoved then 						strResult = Apollo.GetString("GuildResult_BankItemMoved")
	elseif eResult == GuildLib.GuildResult_RankLacksRankRenamePermission then 		strResult = Apollo.GetString("GuildResult_NoRenamePermission")
	elseif eResult == GuildLib.GuildResult_InvalidBankTabName then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_InvalidBankTabName"), tName)
	elseif eResult == GuildLib.GuildResult_CannotWithdrawBankItem then 				strResult = Apollo.GetString("GuildResult_CanNotWithdrawBankItem")
	elseif eResult == GuildLib.GuildResult_BankTabNotLoaded then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_BankTabNotLoaded"), tRank)
	elseif eResult == GuildLib.GuildResult_CannotDepositBankItem then 				strResult = Apollo.GetString("GuildResult_CannotDepositItem")
	elseif eResult == GuildLib.GuildResult_AlreadyAMember and (eGuildType == GuildLib.GuildType_ArenaTeam_2v2 or eGuildType == GuildLib.GuildType_ArenaTeam_3v3 or eGuildType == GuildLib.GuildType_ArenaTeam_5v5) then strResult = String_GetWeaselString(Apollo.GetString("TeamResult_AlreadyAMember"), tName)
	elseif eResult == GuildLib.GuildResult_AlreadyAMember then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_AlreadyAMember"), tName)
	elseif eResult == GuildLib.GuildResult_BankTabWithdrawsExceeded then 			strResult = Apollo.GetString("GuildResult_BankWithdrawsExceeded")
	elseif eResult == GuildLib.GuildResult_BankTabNotVisible then 					strResult = Apollo.GetString("GuildResult_BankTabNotVisible")
	elseif eResult == GuildLib.GuildResult_BankTabDoesNotAcceptDeposits then 		strResult = Apollo.GetString("GuildResult_BankTabDoesNotAcceptDeposits")
	elseif eResult == GuildLib.GuildResult_BankTabRequiresAuthenticator then 		strResult = Apollo.GetString("GuildResult_BankTabRequiresAuthenticator")
	elseif eResult == GuildLib.GuildResult_BankTabCannotWithdraw then 				strResult = Apollo.GetString("GuildResult_BankTabCannotWithdraw")
	elseif eResult == GuildLib.GuildResult_InsufficientInfluence then				strResult = Apollo.GetString("GuildDesigner_NotEnoughInfluence")
	elseif eResult == GuildLib.GuildResult_RequiresPrereq then 						strResult = Apollo.GetString("GuildResult_RequiresPrereq")
	elseif eResult == GuildLib.GuildResult_BankTabBought then 						strResult = String_GetWeaselString(Apollo.GetString("GuildResult_BankTabBought"), tName)
	elseif eResult == GuildLib.GuildResult_ExceededMoneyWithdrawLimitToday then 	strResult = Apollo.GetString("GuildResult_WithdrawLimitExceeded")
	elseif eResult == GuildLib.GuildResult_InsufficientMoneyInGuild then 			strResult = Apollo.GetString("GuildResult_NotEnoughMoneyInGuild")
	elseif eResult == GuildLib.GuildResult_InsufficientMoneyOnCharacter then 		strResult = Apollo.GetString("GuildResult_NotEnoughMoneyOnCharacter")
	elseif eResult == GuildLib.GuildResult_NotEnoughRenown then                     strResult = Apollo.GetString("GuildResult_NotEnoughRenown")
	elseif eResult == GuildLib.GuildResult_CannotDisbandTeamWithActiveGame then 	strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotDisbandWithActiveGame"), strGuildType)
	elseif eResult == GuildLib.GuildResult_CannotLeaveTeamWithActiveGame then 		strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotLeaveTeamWithActiveGame"), strGuildType)
	elseif eResult == GuildLib.GuildResult_CannotRemoveFromTeamWithActiveGame then 	strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotKickWithActiveGame"), strGuildType)
	elseif eResult == GuildLib.GuildResult_InsufficientWarCoins then 				strResult = Apollo.GetString("GuildResult_InsufficientWarCoins")
	elseif eResult == GuildLib.GuildResult_PerkDoesNotExist then 					strResult = Apollo.GetString("GuildResult_PerkDoesNotExist")
	elseif eResult == GuildLib.GuildResult_PerkIsAlreadyUnlocked then 				strResult = Apollo.GetString("GuildResult_PerkAlreadyUnlocked")
	elseif eResult == GuildLib.GuildResult_PerkIsAlreadyActive then 				strResult = Apollo.GetString("GuildResult_PerkIsAlreadyActive")
	elseif eResult == GuildLib.GuildResult_RequiresPerkPurchase then 				strResult = Apollo.GetString("GuildResult_PerkPrereqNotMet")
	elseif eResult == GuildLib.GuildResult_PerkNotActivateable then 				strResult = Apollo.GetString("GuildResult_PerkCanNotActivate")
	elseif eResult == GuildLib.GuildResult_PrivilegeRestricted then 				strResult = String_GetWeaselString(Apollo.GetString("GuildResult_PrivilegeRestricted"), strGuildType)
	
	--The only way we can get this result and have eGuildType to be nil is if we're invited to a warparty
	elseif eResult == GuildLib.GuildResult_NotHighEnoughLevel then					if eGuildType and (eGuildType == GuildLib.GuildType_ArenaTeam_2v2 or eGuildType == GuildLib.GuildType_ArenaTeam_3v3 or eGuildType == GuildLib.GuildType_ArenaTeam_5v5) then
																						strResult = Apollo.GetString("ArenaTeamRegistration_NotHighEnoughLevel")
																					elseif eGuildType and (eGuildType == GuildLib.GuildType_Guild) then
																						strResult = String_GetWeaselString(Apollo.GetString("GuildRegistration_NotHighEnoughLevel"), strGuildType, GuildLib.GetMinimumLevel(eGuildType))
																					elseif eGuildType and (eGuildType == GuildLib.GuildType_WarParty) then
																						strResult = String_GetWeaselString(Apollo.GetString("Warparty_NotHighEnoughLevel"), Apollo.GetString("Guild_GuildTypeWarparty"), GuildLib.GetMinimumLevel(GuildLib.GuildType_WarParty))
																					else 
																						strResult = Apollo.GetString("CRB_LevelRequirementsNotMet")
																					end																					
																					
	elseif eResult == GuildLib.GuildResult_InvalidMessageOfTheDay then 				strResult = Apollo.GetString("GuildResult_InvalidMotD")
	elseif eResult == GuildLib.GuildResult_InvalidMemberNote then 					strResult = Apollo.GetString("GuildResult_InvalidNote")
	elseif eResult == GuildLib.GuildResult_InsufficentMembers then 					strResult = Apollo.GetString("GuildResult_InsufficientMembers")
	elseif eResult == GuildLib.GuildResult_NotAWarParty then 						strResult = Apollo.GetString("GuildResult_NotAWarParty")
	elseif eResult == GuildLib.GuildResult_RequiresAchievement then 				strResult = Apollo.GetString("GuildResult_PerkRequiresAchievement")
	elseif eResult == GuildLib.GuildResult_NotAValidWarPartyItem then				strResult = Apollo.GetString("GuildResult_NotAValidWarPartyItem")
	elseif eResult == GuildLib.GuildResult_InvalidGuildInfo then 					strResult = Apollo.GetString("GuildResult_InvalidGuildInfo")
	elseif eResult == GuildLib.GuildResult_NotEnoughCredits then					strResult = Apollo.GetString("GuildRegistration_NeedMoreCredit")
	elseif eResult == GuildLib.GuildResult_CannotDeleteDefaultRanks then 			strResult = String_GetWeaselString(Apollo.GetString("GuildResult_CannotDeleteDefaultRanks"), tRank)
	elseif eResult == GuildLib.GuildResult_DuplicateRankName then 					strResult = String_GetWeaselString(Apollo.GetString("GuildResult_DuplicateRankName"), tName)
	elseif eResult == GuildLib.GuildResult_InviteSent then 							strResult = String_GetWeaselString(Apollo.GetString("Guild_InviteSent"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_BankTabInvalidPermissions then			strResult = String_GetWeaselString(Apollo.GetString("GuildResult_BankTabInvalidPermissions"), tName, strGuildType)
	elseif eResult == GuildLib.GuildResult_Busy then								strResult = String_GetWeaselString(Apollo.GetString("GuildResult_Busy"), strGuildType)
	elseif eResult == GuildLib.GuildResult_CannotCreateWhileInQueue then			strResult = Apollo.GetString("GuildResult_CannotCreateWhileInQueue")
	elseif eResult == GuildLib.GuildResult_RenameNotAvailable then					strResult = Apollo.GetString("GuildResult_RenameNotAvailable")
	end

	return strResult
end

-----------------------------------------------------------------------------------------------
-- GuildAlerts Instance
-----------------------------------------------------------------------------------------------
local GuildAlertsInst = GuildAlerts:new()
GuildAlertsInst:Init()
xtId="Group_RallyMember3">
                        <Event Name="MouseEnter" Function="OnOptionsWindowBtnMouseEnter"/>
                        <Event Name="MouseExit" Function="OnOptionsWindowBtnMouseExit"/>
                    </Control>
                </Control>
                <Control Class="Button" Base="CRB_Basekit:kitBtn_List_Holo" Font="CRB_InterfaceMedium_O" ButtonType="Check" RadioGroup="GroupDisplayOptions_LocalRadioGroup_RallyingSpecific" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="72" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="0" BAnchorOffset="96" DT_VCENTER="1" DT_CENTER="0" Name="MentoringSpecificBtn4" BGColor="white" TextColor="white" NormalTextColor="UI_BtnTextHoloNormal" PressedTextColor="UI_BtnTextHoloPressed" FlybyTextColor="UI_BtnTextHoloFlyby" PressedFlybyTextColor="UI_BtnTextHoloPressedFlyby" DisabledTextColor="UI_BtnTextHoloDisabled" Sprite="" Picture="0" Text="" TextId="" Tooltip="" RadioDisallowNonSelection="1" GlobalRadioGroup="" TooltipColor="">
                    <Event Name="ButtonCheck" Function="OnMentorSpecificPerson"/>
                    <Control Class="Window" LAnchorPoint="1" LAnchorOffset="-21" TAnchorPoint="0" TAnchorOffset="4" RAnchorPoint="1" RAnchorOffset="-4" BAnchorPoint="1" BAnchorOffset="-4" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="CheckIcon" BGColor="white" TextColor="white" Picture="1" IgnoreMouse="1" Sprite="ClientSprites:Icon_Windows_UI_CRB_Checkmark" Visible="0" TooltipColor="" Tooltip="" NewControlDepth="1" HideInEditor="1"/>
                    <Control Class="Window" LAnchorPoint="0" LAnchorOffset="12" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="-20" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Font="CRB_InterfaceMedium" Text="" Template="Default" Name="SubOptionsBtnText" BGColor="white" TextColor="UI_TextHoloBody" TooltipColor="" DT_VCENTER="1" TextId="Group_RallyMember4">
                        <Event Name="MouseEnter" Function="OnOptionsWindowBtnMouseEnter"/>
                        <Event Name="MouseExit" Function="OnOptionsWindowBtnMouseExit"/>
                    </Control>
                </Control>
                <Control Class="Button" Base="CRB_Basekit:kitBtn_List_Holo" Font="CRB_InterfaceMedium_O" ButtonType="Check" RadioGroup="" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="1" TAnchorOffset="-24" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" DT_VCENTER="1" DT_CENTER="0" Name="MentoringStopBtn" BGColor="white" TextColor="white" NormalTextColor="UI_BtnTextHoloNormal" PressedTextColor="UI_BtnTextHoloPressed" FlybyTextColor="UI_BtnTextHoloFlyby" PressedFlybyTextColor="UI_BtnTextHoloPressedFlyby" DisabledTextColor="UI_BtnTextHoloDisabled" Sprite="" Picture="0" Text="" TextId="" Tooltip="" RadioDisallowNonSelection="1" GlobalRadioGroup="" TooltipColor="" Visible="1" HideInEditor="0">
                    <Event Name="ButtonCheck" Function="OnStopMentoringBtn"/>
                    <Control Class="Window" LAnchorPoint="1" LAnchorOffset="-21" TAnchorPoint="0" TAnchorOffset="4" RAnchorPoint="1" RAnchorOffset="-4" BAnchorPoint="1" BAnchorOffset="-4" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="C