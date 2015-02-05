-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChatLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "Unit"
require "Spell"
require "GameLib"
require "ChatSystemLib"
require "ChatChannelLib"
require "CombatFloater"
require "GroupLib"
require "FriendshipLib"
require "DatacubeLib"

local ChatLog = {}
local kcrInvalidColor = ApolloColor.new("InvalidChat")
local kcrValidColor = ApolloColor.new("white")
local knCountSpaces = 2
local kstrColorChatRegular 		= "ff7fffb9"
local kstrColorChatShout		= "ffd9eef7"
local kstrColorChatRoleplay 	= "ff58e3b0"
local kstrColorNonSelectedEntry = "UI_BtnTextHoloNormal"
local kstrBubbleFont 			= "CRB_Dialog"
local kstrDialogFont 			= "CRB_Dialog"
local kstrDialogFontRP 			= "CRB_Dialog_I"

local kstrGMIcon 				= "Icon_Windows_UI_GMIcon"
local knChannelListHeight = 275

local knWindowStayOnScreenOffset = 50

local knFadeTimerfrequency = 1
local knTimeToFade = 300
local knTimeToFadeAfterAction = 30

local knSaveVersion = 8
local knMaxRecentEntries = 10
local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "ItemQuality_Inferior",
	[Item.CodeEnumItemQuality.Average] 			= "ItemQuality_Average",
	[Item.CodeEnumItemQuality.Good] 			= "ItemQuality_Good",
	[Item.CodeEnumItemQuality.Excellent] 		= "ItemQuality_Excellent",
	[Item.CodeEnumItemQuality.Superb] 			= "ItemQuality_Superb",
	[Item.CodeEnumItemQuality.Legendary] 		= "ItemQuality_Legendary",
	[Item.CodeEnumItemQuality.Artifact]		 	= "ItemQuality_Artifact",
}

local karChannelTypeToColor = -- TODO Merge into one table like this
{
	[ChatSystemLib.ChatChannel_Command] 		= { Channel = "ChannelCommand", 		},
	[ChatSystemLib.ChatChannel_System] 			= { Channel = "ChannelSystem", 			},
	[ChatSystemLib.ChatChannel_Debug] 			= { Channel = "ChannelDebug", 			},
	[ChatSystemLib.ChatChannel_Say] 			= { Channel = "ChannelSay", 			},
	[ChatSystemLib.ChatChannel_Yell] 			= { Channel = "ChannelShout", 			},
	[ChatSystemLib.ChatChannel_Whisper] 		= { Channel = "ChannelWhisper", 		},
	[ChatSystemLib.ChatChannel_Party] 			= { Channel = "ChannelParty", 			},
	[ChatSystemLib.ChatChannel_Emote] 			= { Channel = "ChannelEmote", 			},
	[ChatSystemLib.ChatChannel_AnimatedEmote] 	= { Channel = "ChannelEmote", 			},
	[ChatSystemLib.ChatChannel_Zone] 			= { Channel = "ChannelZone", 			},
	[ChatSystemLib.ChatChannel_ZoneGerman]		= { Channel = "ChannelZone", 			},
	[ChatSystemLib.ChatChannel_ZoneFrench]		= { Channel = "ChannelZone", 			},
	[ChatSystemLib.ChatChannel_ZonePvP] 		= { Channel = "ChannelPvP", 			},
	[ChatSystemLib.ChatChannel_Trade] 			= { Channel = "ChannelTrade",			},
	[ChatSystemLib.ChatChannel_Guild] 			= { Channel = "ChannelGuild", 			},
	[ChatSystemLib.ChatChannel_GuildOfficer] 	= { Channel = "ChannelGuildOfficer",	},
	[ChatSystemLib.ChatChannel_Society] 		= { Channel = "ChannelCircle2",			},
	[ChatSystemLib.ChatChannel_Custom] 			= { Channel = "ChannelCustom", 			},
	[ChatSystemLib.ChatChannel_NPCSay] 			= { Channel = "ChannelNPC", 			},
	[ChatSystemLib.ChatChannel_NPCYell] 		= { Channel = "ChannelNPC",		 		},
	[ChatSystemLib.ChatChannel_NPCWhisper]		= { Channel = "ChannelNPC", 			},
	[ChatSystemLib.ChatChannel_Datachron] 		= { Channel = "ChannelNPC", 			},
	[ChatSystemLib.ChatChannel_Combat] 			= { Channel = "ChannelGeneral", 		},
	[ChatSystemLib.ChatChannel_Realm] 			= { Channel = "ChannelSupport", 		},
	[ChatSystemLib.ChatChannel_Loot] 			= { Channel = "ChannelLoot", 			},
	[ChatSystemLib.ChatChannel_PlayerPath] 		= { Channel = "ChannelGeneral", 		},
	[ChatSystemLib.ChatChannel_Instance] 		= { Channel = "ChannelInstance", 		},
	[ChatSystemLib.ChatChannel_WarParty] 		= { Channel = "ChannelWarParty",		},
	[ChatSystemLib.ChatChannel_WarPartyOfficer] = { Channel = "ChannelWarPartyOfficer", },
	[ChatSystemLib.ChatChannel_Advice] 			= { Channel = "ChannelAdvice", 			},
	[ChatSystemLib.ChatChannel_AdviceGerman]	= { Channel = "ChannelAdvice", 			},
	[ChatSystemLib.ChatChannel_AdviceFrench]	= { Channel = "ChannelAdvice", 			},
	[ChatSystemLib.ChatChannel_AccountWhisper] 	= { Channel = "ChannelAccountWisper", 	},
}

local ktChatResultOutputStrings =
{
	[ChatSystemLib.ChatChannelResult_DoesntExist] 			= Apollo.GetString("CRB_Channel_does_not_exist"),
	[ChatSystemLib.ChatChannelResult_BadPassword] 			= Apollo.GetString("CRB_Channel_password_incorrect"),
	[ChatSystemLib.ChatChannelResult_NoPermissions] 		= Apollo.GetString("CRB_Channel_no_permissions"),
	[ChatSystemLib.ChatChannelResult_NoSpeaking] 			= Apollo.GetString("CRB_Channel_no_speaking"),
	[ChatSystemLib.ChatChannelResult_Muted] 				= Apollo.GetString("CRB_Channel_muted"),
	[ChatSystemLib.ChatChannelResult_Throttled] 			= Apollo.GetString("CRB_Channel_throttled"),
	[ChatSystemLib.ChatChannelResult_NotInGroup] 			= Apollo.GetString("CRB_Not_in_group"),
	[ChatSystemLib.ChatChannelResult_NotInGuild] 			= Apollo.GetString("CRB_Channel_not_in_guild"),
	[ChatSystemLib.ChatChannelResult_NotInSociety] 			= Apollo.GetString("CRB_Channel_not_in_society"),
	[ChatSystemLib.ChatChannelResult_NotGuildOfficer] 		= Apollo.GetString("CRB_Channel_not_guild_officer"),
	[ChatSystemLib.ChatChannelResult_AlreadyMember] 		= Apollo.GetString("ChatLog_AlreadyInChannel"),
	[ChatSystemLib.ChatChannelResult_BadName] 				= Apollo.GetString("ChatLog_InvalidChannel"),
	[ChatSystemLib.ChatChannelResult_NotMember] 			= Apollo.GetString("ChatLog_TargetNotInChannel"),
	[ChatSystemLib.ChatChannelResult_NotInWarParty] 		= Apollo.GetString("ChatLog_NotInWarparty"),
	[ChatSystemLib.ChatChannelResult_NotWarPartyOfficer] 	= Apollo.GetString("ChatLog_NotWarpartyOfficer"),
	[ChatSystemLib.ChatChannelResult_InvalidMessageText] 	= Apollo.GetString("ChatLog_InvalidMessage"),
	[ChatSystemLib.ChatChannelResult_InvalidPasswordText] 	= Apollo.GetString("ChatLog_UseDifferentPassword"),
	[ChatSystemLib.ChatChannelResult_TruncatedText]			= Apollo.GetString("ChatLog_MessageTruncated"),
	[ChatSystemLib.ChatChannelResult_InvalidCharacterName]	= Apollo.GetString("ChatLog_InvalidCharacterName"),
	[ChatSystemLib.ChatChannelResult_GMMuted]				= Apollo.GetString("ChatLog_MutedByGm"),
	[ChatSystemLib.ChatChannelResult_MissingEntitlement]	= Apollo.GetString("ChatLog_MissingEntitlement"),
}

local ktChatActionOutputStrings =
{
	[ChatSystemLib.ChatChannelAction_PassOwner] 		= Apollo.GetString("ChatLog_PassedOwnership"),
	[ChatSystemLib.ChatChannelAction_AddModerator] 		= Apollo.GetString("ChatLog_MadeModerator"),
	[ChatSystemLib.ChatChannelAction_RemoveModerator] 	= Apollo.GetString("ChatLog_MadeMember"),
	[ChatSystemLib.ChatChannelAction_Muted] 			= Apollo.GetString("ChatLog_PlayerMuted"),
	[ChatSystemLib.ChatChannelAction_Unmuted] 			= Apollo.GetString("ChatLog_PlayerUnmuted"),
	[ChatSystemLib.ChatChannelAction_Kicked] 			= Apollo.GetString("ChatLog_PlayerKicked"),
	[ChatSystemLib.ChatChannelAction_AddPassword] 		= Apollo.GetString("ChatLog_PasswordAdded"),
	[ChatSystemLib.ChatChannelAction_RemovePassword] 	= Apollo.GetString("ChatLog_PasswordRemoved")
}

local ktChatJoinOutputStrings =
{
	[ChatSystemLib.ChatChannelResult_BadPassword] 			= Apollo.GetString("CRB_Channel_password_incorrect"),
	[ChatSystemLib.ChatChannelResult_AlreadyMember] 		= Apollo.GetString("ChatLog_AlreadyMember"),
	[ChatSystemLib.ChatChannelResult_BadName]				= Apollo.GetString("ChatLog_BadName"),
	[ChatSystemLib.ChatChannelResult_InvalidPasswordText] 	= Apollo.GetString("ChatLog_InvalidPasswordText"),
	[ChatSystemLib.ChatChannelResult_NoPermissions] 		= Apollo.GetString("CRB_Channel_no_permissions"),
	[ChatSystemLib.ChatChannelResult_TooManyCustomChannels]	= Apollo.GetString("ChatLog_TooManyCustom")
}

local ktDatacubeTypeStrings =
{
	[DatacubeLib.DatacubeType_Datacube]						= Apollo.GetString("ChatLog_Datacube"),
	[DatacubeLib.DatacubeType_Chronicle]					= Apollo.GetString("ChatLog_Chronicle"),
	[DatacubeLib.DatacubeType_Journal]						= Apollo.GetString("ChatLog_Journal")
}

local ktDefaultHolds = {}
ktDefaultHolds[ChatSystemLib.ChatChannel_Whisper] = true

function ChatLog:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function ChatLog:Init()
	Apollo.RegisterAddon(self, true, Apollo.GetString("ChatLog_ChatLogBtn"))
end

function ChatLog:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end
	local wndChatOptionsContent = self.wndChatOptions:FindChild("ChatOptionsContent")

	local nFoundFontSize = 2
	if self.wndChatOptions then
		if wndChatOptionsContent:FindChild("FontSizeSmall"):IsChecked() then
			nFoundFontSize = 1
		elseif wndChatOptionsContent:FindChild("FontSizeMedium"):IsChecked() then
			nFoundFontSize = 2
		elseif wndChatOptionsContent:FindChild("FontSizeLarge"):IsChecked() then
			nFoundFontSize = 3
		elseif wndChatOptionsContent:FindChild("FontSizeHuge"):IsChecked() then
			nFoundFontSize = 4
		end
	end


	local tSave =
	{
		tWindow = {},
		bEnableBGFade = self.bEnableBGFade,
		bEnableNCFade = self.bEnableNCFade,
		nBGOpacity = self.nBGOpacity,
		nFontSize = nFoundFontSize,
		bShowChannel = self.bShowChannel,
		bShowTimestamp = self.bShowTimestamp,
		bProfanityFilter = self.bProfanityFilter,
		eRoleplayOption = self.eRoleplayOption,
	}

	local arWindowGroupMap = {}
	local nCount = 0
	for key, wndChat in pairs(self.tChatWindows) do
		nCount = nCount + 1
		tSave.tWindow[nCount] = {}
		tSave.tWindow[nCount].tChatData = wndChat:GetData()
		tSave.tWindow[nCount].tStrings = wndChat:FindChild("Input"):GetHistoryStrings()
		tSave.tWindow[nCount].strTitle = wndChat:GetText()

		local nMatchingTabGroup = 0
		for idx, wndGroup in pairs(arWindowGroupMap) do
			if wndGroup:IsAttachedToTab(wndChat) then
				nMatchingTabGroup = idx
				break
			end
		end

		if nMatchingTabGroup == 0 then
			nMatchingTabGroup = #arWindowGroupMap + 1
			arWindowGroupMap[nMatchingTabGroup] = wndChat
		end

		tSave.tWindow[nCount].nTabGroup = nMatchingTabGroup
		tSave.tWindow[nCount].tWindowLocation = wndChat:GetLocation():ToTable()
	end

	tSave.nVersion = knSaveVersion
	return tSave
end

function ChatLog:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nVersion ~= knSaveVersion then
		return
	end

	if tSavedData.bEnableNCFade ~= nil then
		self.bEnableNCFade = tSavedData.bEnableNCFade
	end
	if tSavedData.bEnableBGFade ~= nil then
		self.bEnableBGFade = tSavedData.bEnableBGFade
	end
	if tSavedData.nBGOpacity ~= nil then
		self.nBGOpacity = tSavedData.nBGOpacity
	end
	if tSavedData.bShowChannel ~= nil then
		self.bShowChannel = tSavedData.bShowChannel
	end
	if tSavedData.bShowTimestamp ~= nil then
		self.bShowTimestamp = tSavedData.bShowTimestamp
	end
	if tSavedData.bProfanityFilter ~= nil then
		self.bProfanityFilter = tSavedData.bProfanityFilter
	end
	if tSavedData.eRoleplayOption then
		self.eRoleplayOption = tSavedData.eRoleplayOption
	end

	self.nFontSize = tSavedData.nFontSize
	if tSavedData.tWindow and #tSavedData.tWindow > 0 then
		self.tWindow = tSavedData.tWindow
	end
end

function ChatLog:OnConfigure() -- From ESC -> Options
	if self.wndChatOptions and self.wndChatOptions:IsValid() then
		self.wndChatOptions:Show(not self.wndChatOptions:IsVisible())
		self.wndChatOptions:ToFront()
	end
end

function ChatLog:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ChatLog.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	self.tRecent = {}
end

function ChatLog:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("WindowManagementReady", 		"OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("WindowManagementUpdate", 		"OnWindowManagementUpdate", self)

	Apollo.RegisterEventHandler("ChatMessage", 					"OnChatMessage", self)
	Apollo.RegisterEventHandler("ChatFlag", 					"OnChatFlag", self)
	Apollo.RegisterEventHandler("ChatZone", 					"OnChatZone", self)
	Apollo.RegisterEventHandler("ChatResult", 					"OnChatResult", self)
	Apollo.RegisterEventHandler("ChatTellFailed", 				"OnChatTellFailed", self)
	Apollo.RegisterEventHandler("ChatAccountTellFailed",		"OnChatAccountTellFailed", self)
	Apollo.RegisterEventHandler("AccountSupportTicketResult", 	"OnAccountSupportTicketResult", self)
	Apollo.RegisterEventHandler("ChatJoin", 					"OnChatJoin", self)
	Apollo.RegisterEventHandler("ChatLeave", 					"OnChatLeave", self)
	Apollo.RegisterEventHandler("ChatList", 					"OnChatList", self)
	Apollo.RegisterEventHandler("ChatAction", 					"OnChatAction", self)
	Apollo.RegisterEventHandler("ChatJoinResult", 				"OnChatJoinResult", self)
	Apollo.RegisterEventHandler("CombatLogItemDestroy", 		"OnCombatLogItemDestroy", self) -- duplicated in combat log too
	Apollo.RegisterEventHandler("CombatLogModifying", 			"OnCombatLogModifying", self) -- duplicated in combat log too
	Apollo.RegisterEventHandler("CombatLogCrafting", 			"OnCombatLogCrafting", self) -- duplicated in combat log too
	Apollo.RegisterEventHandler("CombatLogDatacube",			"OnCombatLogDatacube", self)
	Apollo.RegisterEventHandler("ItemSentToCrate", 				"OnItemSentToCrate", self)
	Apollo.RegisterEventHandler("HarvestItemsSentToOwner", 		"OnHarvestItemsSentToOwner", self)
	Apollo.RegisterEventHandler("LuaChatLogMessage", 			"OnLuaChatLogMessage", self)
	Apollo.RegisterEventHandler("PlayedTime",					"OnPlayedtime", self)
	Apollo.RegisterEventHandler("ChatReply",					"OnChatReply", self)
	Apollo.RegisterEventHandler("CombatLogLoot", 				"OnCombatLogLoot", self)
	Apollo.RegisterEventHandler("GenericEvent_LinkItemToChat", 	"OnGenericEvent_LinkItemToChat", self)

	Apollo.RegisterEventHandler("TradeSkillSigilResult", 				"OnTradeSkillSigilResult", self)
	Apollo.RegisterEventHandler("GenericEvent_LootChannelMessage", 		"OnGenericEvent_LootChannelMessage", self)
	Apollo.RegisterEventHandler("GenericEvent_SystemChannelMessage", 	"OnGenericEvent_SystemChannelMessage", self)
	Apollo.RegisterEventHandler("Event_EngageWhisper", 					"OnEvent_EngageWhisper", self)
	Apollo.RegisterEventHandler("GenericEvent_QuestLink", 				"OnGenericEvent_QuestLink", self)
	Apollo.RegisterEventHandler("GenericEvent_ArchiveArticleLink", 		"OnGenericEvent_ArchiveArticleLink", self)
	Apollo.RegisterEventHandler("GenericEvent_ChatLogWhisper", 			"OnGenericEvent_ChatLogWhisper", self)
	Apollo.RegisterEventHandler("Event_EngageAccountWhisper",			"OnEvent_EngageAccountWhisper", self)
	Apollo.RegisterEventHandler("SuggestedMenuResult",					"OnSuggestedMenuResult", self)

	Apollo.RegisterEventHandler("VarChange_FrameCount",					"OnChatLineTimer", self)

	self.timerFade = ApolloTimer.Create(knFadeTimerfrequency, true, "OnChatLineFadeTimer", self)

	self.nCurrentTimeMS = GameLib.GetGameTime()
	self.nChatIndex = 0

	self.arChatColor =
	{
		[ChatSystemLib.ChatChannel_Command] 		= ApolloColor.new("ChatCommand"),
		[ChatSystemLib.ChatChannel_System] 			= ApolloColor.new("ChatSystem"),
		[ChatSystemLib.ChatChannel_Debug] 			= ApolloColor.new("ChatDebug"),
		[ChatSystemLib.ChatChannel_Say] 			= ApolloColor.new("ChatSay"),
		[ChatSystemLib.ChatChannel_Yell] 			= ApolloColor.new("ChatShout"),
		[ChatSystemLib.ChatChannel_Whisper] 		= ApolloColor.new("ChatWhisper"),
		[ChatSystemLib.ChatChannel_Party] 			= ApolloColor.new("ChatParty"),
		[ChatSystemLib.ChatChannel_AnimatedEmote] 	= ApolloColor.new("ChatEmote"),
		[ChatSystemLib.ChatChannel_Zone] 			= ApolloColor.new("ChatZone"),
		[ChatSystemLib.ChatChannel_ZoneGerman]		= ApolloColor.new("ChatZone"),
		[ChatSystemLib.ChatChannel_ZoneFrench]		= ApolloColor.new("ChatZone"),
		[ChatSystemLib.ChatChannel_ZonePvP] 		= ApolloColor.new("ChatPvP"),
		[ChatSystemLib.ChatChannel_Trade] 			= ApolloColor.new("ChatTrade"),
		[ChatSystemLib.ChatChannel_Guild] 			= ApolloColor.new("ChatGuild"),
		[ChatSystemLib.ChatChannel_GuildOfficer] 	= ApolloColor.new("ChatGuildOfficer"),
		[ChatSystemLib.ChatChannel_Society] 		= ApolloColor.new("ChatCircle2"),
		[ChatSystemLib.ChatChannel_Custom] 			= ApolloColor.new("ChatCustom"),
		[ChatSystemLib.ChatChannel_NPCSay] 			= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_NPCYell] 		= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_NPCWhisper] 		= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_Datachron] 		= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_Combat] 			= ApolloColor.new("ChatGeneral"),
		[ChatSystemLib.ChatChannel_Realm] 			= ApolloColor.new("ChatSupport"),
		[ChatSystemLib.ChatChannel_Loot] 			= ApolloColor.new("ChatLoot"),
		[ChatSystemLib.ChatChannel_Emote] 			= ApolloColor.new("ChatEmote"),
		[ChatSystemLib.ChatChannel_PlayerPath] 		= ApolloColor.new("ChatGeneral"),
		[ChatSystemLib.ChatChannel_Instance] 		= ApolloColor.new("ChatInstance"),
		[ChatSystemLib.ChatChannel_WarParty] 		= ApolloColor.new("ChatWarParty"),
		[ChatSystemLib.ChatChannel_WarPartyOfficer] = ApolloColor.new("ChatWarPartyOfficer"),
		[ChatSystemLib.ChatChannel_Advice] 			= ApolloColor.new("ChatAdvice"),
		[ChatSystemLib.ChatChannel_AdviceGerman]	= ApolloColor.new("ChatAdvice"),
		[ChatSystemLib.ChatChannel_AdviceFrench]	= ApolloColor.new("ChatAdvice"),
		[ChatSystemLib.ChatChannel_AccountWhisper]	= ApolloColor.new("ChatAccountWisper"),
	}

	self.tAllViewedChannels = {}
	self.tChatWindows		= {}
	self.tLinks 			= {}
	self.nNextLinkIndex 	= 1
	self.nMaxChatLines 		= 256
	self.twndItemLinkTooltips = {}

	self.tEmotes = {}
	local tEmotes = ChatSystemLib.GetEmotes()
	for idx, strEmote in pairs(tEmotes) do
		self.tEmotes[strEmote] = strEmote
	end

	---------------OPTIONS---------------
	self.wndChatOptions = Apollo.LoadForm(self.xmlDoc, "ChatOptionsForm", nil, self)

	local wndOptionsContainer = self.wndChatOptions:FindChild("TwoOptionsContainer")

	wndOptionsContainer:FindChild("SaveToLogOn"):SetCheck(Apollo.GetConsoleVariable("chat.saveLog"))
	wndOptionsContainer:FindChild("SaveToLogOff"):SetCheck(not Apollo.GetConsoleVariable("chat.saveLog"))
	self.wndChatOptions:FindChild("ChatOptionsContent:RoleplayViewToggle_3"):SetCheck(true)
	self.wndChatOptions:Show(false)

	-- Profanity Filter Option
	if self.bProfanityFilter == nil then
		self.bProfanityFilter = true
	end

	wndOptionsContainer:FindChild("ProfanityOn"):SetData(true)
	wndOptionsContainer:FindChild("ProfanityOff"):SetData(false)
	wndOptionsContainer:FindChild("ProfanityOn"):SetCheck(self.bProfanityFilter) -- Default
	wndOptionsContainer:FindChild("ProfanityOff"):SetCheck(not self.bProfanityFilter)

	for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels()) do
		local eChannelType = channelCurrent:GetType()
		if eChannelType == ChatSystemLib.ChatChannel_Whisper then
			self.channelWhisper = channelCurrent
		elseif eChannelType == ChatSystemLib.ChatChannel_AccountWhisper then
			self.channelAccountWhisper = channelCurrent
		elseif eChannelType == ChatSystemLib.ChatChannel_Say then
			self.channelSay = channelCurrent
		elseif eChannelType == ChatSystemLib.ChatChannel_Loot then
			self.channelLoot = channelCurrent
		end

		channelCurrent:SetProfanity(self.bProfanityFilter)
	end

	-- Font Options
	self.strFontOption 		= "CRB_InterfaceMedium"
	self.strAlienFontOption = "CRB_AlienMedium"
	self.strRPFontOption 	= "CRB_InterfaceMedium_I"

	local wndChatOptionsContent = self.wndChatOptions:FindChild("ChatOptionsContent")
	wndChatOptionsContent:FindChild("FontSizeSmall"):SetData({ strNormal = "CRB_InterfaceSmall", strAlien = "CRB_AlienSmall", strRP = "CRB_InterfaceSmall_I" })
	wndChatOptionsContent:FindChild("FontSizeMedium"):SetData({ strNormal = "CRB_InterfaceMedium", strAlien = "CRB_AlienMedium", strRP = "CRB_InterfaceMedium_I" })
	wndChatOptionsContent:FindChild("FontSizeLarge"):SetData({ strNormal = "CRB_InterfaceLarge", strAlien = "CRB_AlienLarge", strRP = "CRB_InterfaceLarge_I" })
	wndChatOptionsContent:FindChild("FontSizeHuge"):SetData({ strNormal = "CRB_Interface16", strAlien = "CRB_AlienHuge", strRP = "CRB_Interface16_I" })
	wndChatOptionsContent:FindChild("FontSizeMedium"):SetCheck(true) -- Default

	-- Channel Options
	local wndOptionsContainer = self.wndChatOptions:FindChild("TwoOptionsContainer")
	if self.bShowChannel == nil then
		self.bShowChannel = true
	end
	wndOptionsContainer:FindChild("ChannelShow"):SetData(true)
	wndOptionsContainer:FindChild("ChannelShowOff"):SetData(false)
	wndOptionsContainer:FindChild("ChannelShow"):SetCheck(self.bShowChannel)  -- Default
	wndOptionsContainer:FindChild("ChannelShowOff"):SetCheck(not self.bShowChannel)

	-- Timestamp
	if self.bShowTimestamp == nil then
		self.bShowTimestamp = true
	end
	wndOptionsContainer:FindChild("TimestampShow"):SetData(true)
	wndOptionsContainer:FindChild("TimestampShowOff"):SetData(false)
	wndOptionsContainer:FindChild("TimestampShow"):SetCheck(self.bShowTimestamp) -- Default
	wndOptionsContainer:FindChild("TimestampShowOff"):SetData(not self.bShowTimestamp)

	-- Background
	if self.bEnableBGFade == nil then
		self.bEnableBGFade = true
	end
	wndOptionsContainer:FindChild("EnableFadeBtn"):SetData(true)
	wndOptionsContainer:FindChild("DisableFadeBtn"):SetData(false)
	wndOptionsContainer:FindChild("EnableFadeBtn"):SetCheck(self.bEnableBGFade) -- Default
	wndOptionsContainer:FindChild("DisableFadeBtn"):SetCheck(not self.bEnableBGFade)
	
	
	-- Player Chat Bubbles
	self.bEnablePlayerBubbles = Apollo.GetConsoleVariable("unit.playerTextBubbleEnabled") or false
	wndOptionsContainer:FindChild("EnablePlayerChatBubblesBtn"):SetData(true)
	wndOptionsContainer:FindChild("DisablePlayerChatBubblesBtn"):SetData(false)
	wndOptionsContainer:FindChild("EnablePlayerChatBubblesBtn"):SetCheck(self.bEnablePlayerBubbles) -- Default
	wndOptionsContainer:FindChild("DisablePlayerChatBubblesBtn"):SetCheck(not self.bEnablePlayerBubbles)
	
	-- NPC Chat Bubbles
	self.bEnableNPCBubbles = Apollo.GetConsoleVariable("unit.npcTextBubbleEnabled") or false
	wndOptionsContainer:FindChild("EnableNPCChatBubblesBtn"):SetData(true)
	wndOptionsContainer:FindChild("DisableNPCChatBubblesBtn"):SetData(false)
	wndOptionsContainer:FindChild("EnableNPCChatBubblesBtn"):SetCheck(self.bEnableNPCBubbles) -- Default
	wndOptionsContainer:FindChild("DisableNPCChatBubblesBtn"):SetCheck(not self.bEnableNPCBubbles)
	

	if not self.nBGOpacity then
		self.nBGOpacity = self.wndChatOptions:FindChild("BGOpacity:BGOpacitySlider"):GetValue()
	else
		self.wndChatOptions:FindChild("BGOpacity:BGOpacitySlider"):SetValue(self.nBGOpacity)
	end

	-- Default Channels
	self.tCombatChannels = {}
	self.tDefaultChannels = {}

	for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels() or {}) do
		local eType = channelCurrent:GetType()
		if eType ~= ChatSystemLib.ChatChannel_Combat then
			self.tDefaultChannels[channelCurrent:GetUniqueId()] = true
		end

		if eType == ChatSystemLib.ChatChannel_System or eType == ChatSystemLib.ChatChannel_Combat then
			self.tCombatChannels[channelCurrent:GetUniqueId()] = true
		end
	end

	if not self.tWindow then
		local wndChat = self:NewChatWindow(Apollo.GetString("CRB_Chat"), self.tDefaultChannels, false)
		local wndCombat = self:NewChatWindow(Apollo.GetString("ChatType_Combat"), self.tCombatChannels, true)
		wndChat:AttachTab(wndCombat, false)
	end

	self.tChatQueue = Queue:new()

	if not self.eRoleplayOption then
		self.eRoleplayOption = 3 -- by default, no RP shown
	end
	wndChatOptionsContent:SetRadioSel("RoleplayViewToggle", self.eRoleplayOption)
	self.tLastWhisperer = nil -- last person to whisper to you

	-------------------------------------OnRestoreSection-------------------------------------
	if self.nFontSize ~= nil then
		local strFontControlName = "FontSizeMedium"

		local wndChatOptionsContent = self.wndChatOptions:FindChild("ChatOptionsContent")

		wndChatOptionsContent:FindChild("FontSizeSmall"):SetCheck(self.nFontSize == 1)
		wndChatOptionsContent:FindChild("FontSizeMedium"):SetCheck(self.nFontSize == 2)
		wndChatOptionsContent:FindChild("FontSizeLarge"):SetCheck(self.nFontSize == 3)
		wndChatOptionsContent:FindChild("FontSizeHuge"):SetCheck(self.nFontSize == 4)

		if self.nFontSize == 1 then
			strFontControlName = "FontSizeSmall"
		elseif self.nFontSize == 2 then
			strFontControlName = "FontSizeMedium"
		elseif self.nFontSize == 3 then
			strFontControlName = "FontSizeLarge"
		elseif self.nFontSize == 4 then
			strFontControlName = "FontSizeHuge"
		end

		local wndFontControl = self.wndChatOptions:FindChild("ChatOptionsContent:" .. strFontControlName)
		self:OnFontSizeOption(wndFontControl, wndFontControl)
	end

	local arWindowGroupMap = {}
	for key, tWindowInfo in ipairs(self.tWindow or {}) do
		if self.tChatWindows[key] == nil then
			local bCombatLog = false

			if tWindowInfo.tChatData.bCombatLog ~= nil then
				bCombatLog = tWindowInfo.tChatData.bCombatLog
			end

			self:NewChatWindow(tWindowInfo.strTitle, tWindowInfo.tChatData.tViewedChannels or self.tDefaultChannels, tWindowInfo.tChatData.bCombatLog)
		end

		local wndChat = self.tChatWindows[key]
		if tWindowInfo.tStrings ~= nil then
			for idx, strHistory in pairs(tWindowInfo.tStrings) do
				wndChat:FindChild("Input"):AddHistoryString(strHistory)
			end
		end

		if tWindowInfo.strTitle ~= nil then
			if tWindowInfo.strTitle == "Chat" then
				tWindowInfo.strTitle = Apollo.GetString("CRB_Chat")
			elseif tWindowInfo.strTitle == "Combat" then
				tWindowInfo.strTitle = Apollo.GetString("ChatType_Combat")
			else
				wndChat:SetText(tWindowInfo.strTitle)
			end
		end

		if tWindowInfo.tWindowLocation then
			wndChat:Detach()
		end

		if self.bEnableNCFade ~= nil and self.bEnableBGFade ~= nil then
			wndChat:SetStyle("AutoFadeNC", self.bEnableNCFade)
			if self.bEnableNCFade then wndChat:SetNCOpacity(1) end

			wndChat:SetStyle("AutoFadeBG", self.bEnableBGFade)
			if self.bEnableBGFade then wndChat:SetBGOpacity(1) end
		end

		if self.nBGOpacity ~= nil then
			wndChat:FindChild("BGArt"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
			wndChat:FindChild("BGArt_SidePanel"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
			wndChat:FindChild("BGArt_ResizeHandle"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
		end

		local nMatchingTabGroup = 0
		for idx, wndGroup in pairs(arWindowGroupMap) do
			if idx == tWindowInfo.nTabGroup then
				nMatchingTabGroup = idx
				break
			end
		end

		if nMatchingTabGroup == 0 then
			nMatchingTabGroup = tWindowInfo.nTabGroup
			arWindowGroupMap[tWindowInfo.nTabGroup] = wndChat
		else
			arWindowGroupMap[tWindowInfo.nTabGroup]:AttachTab(wndChat)
		end
	end

	if self.wndChatOptions then
		local wndOptionsContainer = self.wndChatOptions:FindChild("TwoOptionsContainer")
		wndOptionsContainer:FindChild("EnableFadeBtn"):SetCheck(self.bEnableBGFade)
		wndOptionsContainer:FindChild("DisableFadeBtn"):SetCheck(not self.bEnableBGFade)
		self.wndChatOptions:FindChild("BGOpacity:BGOpacitySlider"):SetValue(self.nBGOpacity)
		wndOptionsContainer:FindChild("ChannelShow"):SetCheck(self.bShowChannel)
		wndOptionsContainer:FindChild("ChannelShowOff"):SetCheck(not self.bShowChannel)
		wndOptionsContainer:FindChild("TimestampShow"):SetCheck(self.bShowTimestamp)
		wndOptionsContainer:FindChild("TimestampShowOff"):SetCheck(not self.bShowTimestamp)
		wndOptionsContainer:FindChild("ProfanityOn"):SetCheck(self.bProfanityFilter)
		wndOptionsContainer:FindChild("ProfanityOff"):SetCheck(not self.bProfanityFilter)
		Apollo.SetConsoleVariable("chat.filter", self.bProfanityFilter)

		for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels() or {}) do
			channelCurrent:SetProfanity(self.bProfanityFilter)
		end
	end
end

function ChatLog:OnWindowManagementUpdate(tSettings)
	--OnWindowManagementUpdate will fire WHENEVER the window moves and when reset button is pressed.
	--The time we care about is when the window is NOT moving, which is when the reset button is pressed.
	if not tSettings or tSettings.bHasMoved then
		return
	end

	for key, wndChat in pairs(self.tChatWindows) do
		--the "name" of the chat/combat tabs are the text on the window, tSettings.strName is the tab to reset.
		if wndChat:GetText() == tSettings.strName and #self.tChatWindows > 1 then
			--make sure not to attach window to itself, and make sure that index is atleast 1
			local nIndexToAttach = (key  % #self.tChatWindows) + 1
			self.tChatWindows[nIndexToAttach]:AttachTab(wndChat, false)
			break
		end
	end
end

function ChatLog:OnWindowManagementReady()
	for key, wndChat in pairs(self.tChatWindows) do
		Event_FireGenericEvent("WindowManagementAdd", {wnd = wndChat, strName = wndChat:GetText(), bIsTabWindow = true})
	end

	if self.wndChatOptions and self.wndChatOptions:FindChild("BGHeaderText") then
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndChatOptions, strName = self.wndChatOptions:FindChild("BGHeaderText"):GetText(), nSaveVersion=5})
	end
end

function ChatLog:NewChatWindow(strTitle, tViewedChannels, bCombatLog, channelCurrent)
	local wndChatWindow = Apollo.LoadForm(self.xmlDoc, "ChatWindow", "FixedHudStratumHigh", self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = wndChatWindow, strName = strTitle, bIsTabWindow = true})

	wndChatWindow:SetSizingMinimum(240, 240)
	wndChatWindow:SetStyle("AutoFadeNC", self.bEnableBGFade)
	wndChatWindow:SetStyle("AutoFadeBG", self.bEnableBGFade)
	wndChatWindow:FindChild("BGArt"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
	wndChatWindow:FindChild("BGArt_SidePanel"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
	wndChatWindow:FindChild("BGArt_ResizeHandle"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
	wndChatWindow:SetText(strTitle)
	wndChatWindow:Show(true)
	wndChatWindow:FindChild("InputTypeBtn"):AttachWindow(wndChatWindow:FindChild("InputWindow"))
	wndChatWindow:FindChild("EmoteBtn"):AttachWindow(wndChatWindow:FindChild("EmoteMenu"))
	wndChatWindow:FindChild("Options"):AttachWindow(wndChatWindow:FindChild("OptionsSubForm"))
    wndChatWindow:FindChild("OptionsSubForm"):SetData(wndChatWindow)
	--Store the initial input window size
	self.nInputMenuLeft, self.nInputMenuTop, self.nInputMenuRight, self.nInputMenuBottom = wndChatWindow:FindChild("InputWindow"):GetAnchorOffsets()

	local tChatData = {}
	tChatData.wndForm = wndChatWindow
	tChatData.tViewedChannels = {}

	tChatData.tMessageQueue = Queue:new()
	tChatData.tChildren = Queue:new()

	local wndChatChild = wndChatWindow:FindChild("Chat")
	for idx = 1, self.nMaxChatLines do
		local wndChatLine = Apollo.LoadForm(self.xmlDoc, "ChatLine", wndChatChild, self)
		wndChatLine:SetData({ ["nLine"]=idx, ["nAddedTime"]=knTimeToFade, ["bFading"]=false })
		wndChatLine:Show(false)
		tChatData.tChildren:Push(wndChatLine)
	end
	tChatData.nNextIndex = self.nMaxChatLines + 1

	local tChannels = bCombatLog and self.tCombatChannels or tViewedChannels
	tChatData.wndForm:FindChild("BGArt_ChatBackerIcon"):Show(bCombatLog)

	for key, value in pairs(tChannels) do
		tChatData.tViewedChannels[key] = value
	end

	tChatData.bCombatLog = bCombatLog
	wndChatWindow:SetData(tChatData)

	if not bCombatLog then
		for key, value in pairs(tViewedChannels) do
			if value then
				self:HelperAddChannelToAll(key)
			end
		end
	end

	tChatData.channelCurrent = channelCurrent or self:HelperFindAViewedChannel()

	local wndInput = wndChatWindow:FindChild("Input")
	if tChatData.channelCurrent then
		tChatData.crText = self.arChatColor[tChatData.channelCurrent:GetType()]
		wndInput:SetPrompt(tChatData.channelCurrent:GetCommand())
		wndInput:SetPromptColor(tChatData.crText)
	else
		wndInput:SetPrompt("X")
		wndInput:SetPromptColor(kcrInvalidColor)
	end

	tChatData.wndOptions = tChatData.wndForm:FindChild("OptionsSubForm")
	tChatData.wndOptions:Show(false)

	if #self.tChatWindows >= 1 then
		wndChatWindow:FindChild("CloseBtn"):Show(true)
	else
		wndChatWindow:FindChild("CloseBtn"):Show(false)
	end

	table.insert(self.tChatWindows, wndChatWindow)

	local nWindowCount = #self.tChatWindows
	if not self.tChatWindows[1]:FindChild("CloseBtn"):IsShown() and nWindowCount > 1 then
		self.tChatWindows[1]:FindChild("CloseBtn"):Show(true)
	end

	return wndChatWindow
end

function ChatLog:OnLuaChatLogMessage(strArgMessage, tArgFlags)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, strArgMessage, "")
end

-----------------------------------------------------------------------------------------------
-- Duplicated in Combat Log
-----------------------------------------------------------------------------------------------

function ChatLog:OnCombatLogItemDestroy(tEventArgs)
	if tEventArgs.itemDestroyed == nil then
		return
	end

	local strResult = String_GetWeaselString(Apollo.GetString("ChatLog_DestroyItem"), tEventArgs.itemDestroyed:GetChatLinkString())
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult, "")
end

function ChatLog:OnCombatLogCrafting(tEventArgs)
	if tEventArgs.itemCrafted == nil then
		return
	end

	local strResult = String_GetWeaselString(Apollo.GetString("ChatLog_CraftItem"), tEventArgs.itemCrafted:GetChatLinkString())
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult, "")
end

function ChatLog:OnCombatLogDatacube(tEventArgs)
	local strResult = ktDatacubeTypeStrings[tEventArgs.eDatacubeType]
	if tEventArgs.eDatacubeType == DatacubeLib.DatacubeType_Journal and tEventArgs.bHasPieces then
		strResult = Apollo.GetString("ChatLog_MultiJournal")
	end
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult, "")
end

function ChatLog:OnCombatLogModifying(tEventArgs)
	if tEventArgs.itemHost == nil or tEventArgs.itemAdded == nil or tEventArgs.itemRemoved == nil then
		return
	end

	local strResult = String_GetWeaselString(Apollo.GetString("ChatLog_ModItem"), tEventArgs.itemHost:GetChatLinkString(), tEventArgs.itemAdded:GetChatLinkString(), tEventArgs.itemRemoved:GetChatLinkString())
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult, "")
end

-----------------------------------------------------------------------------------------------

function ChatLog:OnChatMessage(channelCurrent, tMessage)
	-- tMessage has bAutoResponse, bGM, bSelf, strSender, strRealmName, nPresenceState, arMessageSegments, unitSource, bShowChatBubble, bCrossFaction, nReportId

	-- arMessageSegments is an array of tables.  Each table representsa part of the message + the formatting for that segment.
	-- This allows us to signal font (alien text for example) changes mid stream.
	-- local example = arMessageSegments[1]
	-- example.strText is the text
	-- example.bAlien == true if alien font set
	-- example.bRolePlay == true if this is rolePlay Text.  RolePlay text should only show up for people in roleplay mode, and non roleplay text should only show up for people outside it.

	-- to use: 	{#}toggles alien on {*}toggles rp on. Alien is still on {!}resets all format codes.


	-- There will be a lot of chat messages, particularly for combat log.  If you make your own chat log module, you will want to batch
	-- up several at a time and only process lines you expect to see.

	local tQueuedMessage = {}
	tQueuedMessage.tMessage = tMessage
	tQueuedMessage.eChannelType = channelCurrent:GetType()
	tQueuedMessage.strChannelName = channelCurrent:GetName()
	tQueuedMessage.strChannelCommand = channelCurrent:GetCommand()
	tQueuedMessage.idChannel = channelCurrent:GetUniqueId()

	-- handle unit bubble if needed.
	if tQueuedMessage.tMessage.unitSource and tQueuedMessage.tMessage.bShowChatBubble then
		self:HelperGenerateChatMessage(tQueuedMessage)
		if tQueuedMessage.xmlBubble then
			tMessage.unitSource:AddTextBubble(tQueuedMessage.xmlBubble)
		end
	end

	self:HelperQueueMessage(tQueuedMessage)
end

function ChatLog:HelperQueueMessage(tQueuedMessage)
	-- queue message on windows.
	for key, wndChat in pairs(self.tChatWindows) do
		if wndChat:GetData().tViewedChannels[tQueuedMessage.idChannel] then -- check flags for filtering
			self.bQueuedMessages = true
			wndChat:GetData().tMessageQueue:Push(tQueuedMessage)
		end
	end
end

function ChatLog:HelperCheckForEmptyString(strText)
	local strFirstChar
	local bHasText = false

	strFirstChar = string.find(strText, "%S")

	bHasText = strFirstChar ~= nil and string.len(strFirstChar) > 0
	return bHasText
end

function ChatLog:OnChatFlag( channelUpdated )
	-- example
	-- local bIsOwner = channelUpdated:IsOwner()
	-- local bIsModerator = channelUpdated:IsModerator()
	-- local bIsMuted = channelUpdated:IsMuted()
end

function ChatLog:OnChatZone( description )
	-- TODO
	--local zoneName = description
end


function ChatLog:OnChatResult(channelSender, eResult)
	local strMessage = Apollo.GetString("CombatFloaterType_Error")
	local strChanName = ""

	if channelSender == nil or channelSender:GetName() == "" then
		strChanName = Apollo.GetString("Unknown_Unit")
	else
		strChanName = channelSender:GetName()
	end

	if ktChatResultOutputStrings[eResult] then
		if eResult == ChatSystemLib.ChatChannelResult_NotInGroup and GroupLib.InGroup() and GroupLib.InInstance() then
			strMessage = Apollo.GetString("ChatLog_UseInstanceChannel")
		else
			strMessage = String_GetWeaselString(ktChatResultOutputStrings[eResult], strMessage, strChanName)
		end
	else
		strMessage = String_GetWeaselString(Apollo.GetString("ChatLog_UndefinedMessage"), strMessage, eResult, strChanName)
	end

	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, strMessage, "" )
end

function ChatLog:OnChatTellFailed( channel, strCharacterTo )
	strMessage = String_GetWeaselString(Apollo.GetString("CRB_Whisper_Error"), Apollo.GetString("CombatFloaterType_Error"), strCharacterTo, Apollo.GetString("CRB_Whisper_Error_Reason"))
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, strMessage, "" )
	self:RemoveFromRecent(strCharacterTo)
end

function ChatLog:OnChatAccountTellFailed( channel, strCharacterTo )
	strMessage = String_GetWeaselString(Apollo.GetString("CRB_Whisper_Error"), Apollo.GetString("CombatFloaterType_Error"), strCharacterTo, Apollo.GetString("CRB_Account_Whisper_Error_Reason"))
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, strMessage, "" )
	self:RemoveFromRecent(strCharacterTo)
end

function ChatLog:OnAccountSupportTicketResult( channelSource, bSuccess )
	if( bSuccess ) then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, Apollo.GetString("PlayerTicket_TicketSent"), "")
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, Apollo.GetString("PlayerTicket_TicketFailed"), "")
	end
end

function ChatLog:OnChatJoin( channelJoined )
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, String_GetWeaselString(Apollo.GetString("ChatLog_JoinChannel"),  channelJoined:GetName()), "" );

	-- ChatJoin event is called both on startup and on join.

	for idx, wndChatWindow in pairs(self.tChatWindows) do
		wndChatWindow:FindChild("InputWindow"):Close()

		-- explicit check for nil, it means we have have no saved setting for this channel displaying in this window.

		local tChatData = wndChatWindow:GetData()
		if not tChatData.bCombatLog and tChatData.tViewedChannels[channelJoined:GetUniqueId()] == nil then
			self:HelperAddChannelToAll(channelJoined:GetUniqueId())
			tChatData.tViewedChannels[channelJoined:GetUniqueId()] = true
		end
	end
end

function ChatLog:OnChatLeave( channelLeft, bKicked, bBanned )
	if( bBanned ) then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, String_GetWeaselString(Apollo.GetString("ChatLog_BannedFromChannel"), channelLeft:GetName()), "" );
	elseif( bKicked ) then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, String_GetWeaselString(Apollo.GetString("ChatLog_KickedFromChannel"), channelLeft:GetName()), "" );
	else
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, String_GetWeaselString(Apollo.GetString("ChatLog_LeftChannel"), channelLeft:GetName()), "" );
	end

	for idx, wndChatWindow in pairs(self.tChatWindows) do
		local tChatData = wndChatWindow:GetData()

		if tChatData.channelCurrent == channelLeft then
			tChatData.channelCurrent = self.channelSay
			tChatData.crText = self.arChatColor[ ChatSystemLib.ChatChannel_Say ]

			local wndInput = wndChatWindow:FindChild("Input")
			wndInput:SetPrompt(tChatData.channelCurrent:GetCommand())
			wndInput:SetPromptColor(tChatData.crText)
		end
	end
end

function ChatLog:OnChatList( channelSource )
	local tMembers = channelSource:GetMembers()
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, Apollo.GetString("ChatLog_MemberList"), ""  );
	for idx = 1,#tMembers do
		local strDesc = ""
		if tMembers[idx].bIsChannelOwner then
			strDesc = String_GetWeaselString(Apollo.GetString("ChatLog_ChannelOwner"), strDesc)
		end
		if tMembers[idx].bIsModerator then
			strDesc = String_GetWeaselString(Apollo.GetString("ChatLog_ChannelModerator"), strDesc)
		end
		if tMembers[idx].bIsMuted then
			strDesc = String_GetWeaselString(Apollo.GetString("ChatLog_Muted"), strDesc)
		end

		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, tMembers[idx].strMemberName .. strDesc, "" )
	end
end

function ChatLog:OnChatAction( channelSource, eAction, strActor, strActedOn )
	local strMessage = ""
	local strChanName = ""

	if channelSource == nil or channelSource:GetName() == "" then
		strChanName = Apollo.GetString("Unknown_Unit")
	else
		strChanName = channelSource:GetName()
	end

	if ktChatActionOutputStrings[eAction] then
		strMessage = String_GetWeaselString(ktChatActionOutputStrings[eAction], strChanName, strActor, strActedOn)
	else
		strMessage = String_GetWeaselString(Apollo.GetString("ChatLog_UndefinedMessage"), Apollo.GetString("CombatFloaterType_Error"), eAction, strChanName)
	end

	if strMessage then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, strMessage, "" )
	end
end

function ChatLog:OnChatJoinResult( strChanName, eResult )
	local strMessage = Apollo.GetString("CombatFloaterType_Error")

	if strChanName == nil or strChanName == "" then
		strChanName = Apollo.GetString("Unknown_Unit")
	end

	if ktChatJoinOutputStrings[eResult] then
		strMessage = String_GetWeaselString(ktChatJoinOutputStrings[eResult], strMessage, strChanName)
	else
		strMessage = String_GetWeaselString(Apollo.GetString("ChatLog_UndefinedMessage"), strMessage, eResult, strChanName)
	end

	if strMessage then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, strMessage, "" )
	end
end

function ChatLog:OnChatLineTimer()
	nCurrentTimeMS = GameLib.GetGameTime()
	local nDeltaTimeMS = nCurrentTimeMS - self.nCurrentTimeMS
	self.nCurrentTimeMS = nCurrentTimeMS
	if nDeltaTimeMS < 0 then
		nDeltaTimeMS = 33
	end

	if self.bQueuedMessages then
		self.bQueuedMessages = false

		for key, wndChat in pairs(self.tChatWindows) do
			if not wndChat:GetData().tMessageQueue:Empty() then
				self:ShowQueuedMessages(wndChat, nDeltaTimeMS)
				self.bQueuedMessages = self.bQueuedMessages or not wndChat:GetData().tMessageQueue:Empty()
			end
		end
	end
end

function ChatLog:ShowQueuedMessages(wndForm, nDeltaTimeMS)
	local tChatData = wndForm:GetData()
	local wndChatList = wndForm:FindChild("Chat")

	local nLineCount = tChatData.tChildren:GetSize()
	-- we only show tChatData.tChildren:GetSize() chat lines at once.
	while tChatData.tMessageQueue:GetSize() > nLineCount do
		tChatData.tMessageQueue:Pop()
	end

	local nMessages = nLineCount * nDeltaTimeMS
	if nMessages < 1 then
		nMessages = 1
	end

	-- grab queued message and put it into oldest chat line window. Move window to bottom. Only do 20 at a time.
	local bPrettyItUp = false
	for iCount = 1, nMessages do
		if tChatData.tMessageQueue:GetSize() == 0 then
			break;
		end
		bPrettyItUp = true
		local tQueuedMessage = tChatData.tMessageQueue:Pop()
		self:HelperGenerateChatMessage(tQueuedMessage)

		if tQueuedMessage.eChannelType == ChatSystemLib.ChatChannel_AccountWhisper then
			self.channelReply = self.channelAccountWhisper
		elseif tQueuedMessage.eChannelType == ChatSystemLib.ChatChannel_Whisper then
			self.channelReply = self.channelWhisper
		end

		local wndChatLine = tChatData.tChildren:Pop()
		wndChatLine:SetData({ ["nLine"]=tChatData.nNextIndex, ["nAddedTime"]=knTimeToFade, ["bFading"]=false })
		wndChatLine:SetOpacity(1, 0)
		wndChatLine:Show(true)
		if tQueuedMessage.strMessage then
			wndChatLine:SetText( tQueuedMessage.strMessage )
		elseif tQueuedMessage.xml then
			wndChatLine:SetDoc( tQueuedMessage.xml )
		end
		wndChatLine:SetHeightToContentHeight()

		tChatData.nNextIndex = tChatData.nNextIndex + 1
		tChatData.tChildren:Push(wndChatLine)

		wndChatList:SendChildToBottom(wndChatLine, true)
	end

	if bPrettyItUp then
		self:PrettyItUp(wndForm)
	end
end

function ChatLog:PrettyItUp(wndForm)
	local wndChatList = wndForm:FindChild("Chat")
	local bAtBottom = false
	local nPos = wndChatList:GetVScrollPos()

	if nPos == wndChatList:GetVScrollRange() then
		bAtBottom = true
	end

	-- arrange children
	wndChatList:ArrangeChildrenVert(0)

	if bAtBottom then
		wndChatList:SetVScrollPos(wndChatList:GetVScrollRange())
	end
end

function ChatLog:OnChatLineFadeTimer()
	for idx, wndChat in pairs(self.tChatWindows) do
		self:RunChatWindowFade(wndChat)
	end
end

function ChatLog:RunChatWindowFade(wndChat)
	local tChatData = wndChat:GetData()
	local wndChatList = wndChat:FindChild("Chat")
	local wndInput = wndChat:FindChild("Input")
	local strInput = wndInput:GetText()
	local bForceOpaque = (wndChatList:GetVScrollPos() ~= wndChatList:GetVScrollRange())
		or (strInput ~= nil and strInput ~= "")
		or wndChat:ContainsMouse()
		or not self.bEnableBGFade

	for idx, wndChatLine in pairs(tChatData.tChildren:GetItems()) do
		if wndChatLine:IsShown() then
			local tChatLineData = wndChatLine:GetData()

			if bForceOpaque then
				wndChatLine:SetOpacity(1, 0)
			else
				local nTimeLeft = tChatLineData.nAddedTime - knFadeTimerfrequency
				tChatLineData.nAddedTime = nTimeLeft
				if nTimeLeft <= 0 then
					wndChatLine:SetOpacity(0.2, 1)
				end
			end
			
			wndChatLine:SetData(tChatLineData)
		end
	end
end

function ChatLog:OnMouseEnter(wndHandler, wndControl, x, y)
	if wndHandler ~= wndControl then
		return
	end
	self:RunChatWindowFade(wndControl)
end

function ChatLog:ChatActionTaken(wndChat)
	local tChatData = wndChat:GetData()

	for idx, wndChatLine in pairs(tChatData.tChildren:GetItems()) do
		if wndChatLine:IsShown() then
			local tChatLineData = wndChatLine:GetData()
			tChatLineData.nAddedTime = math.max(knTimeToFadeAfterAction, tChatLineData.nAddedTime)
			wndChatLine:SetData(tChatLineData)
		end
	end
end

function ChatLog:OnNodeClick(wndHandler, wndControl, strNode, tAttributes, eMouseButton)
	-- can only report players who are not yourself, which matches who we want this menu for.
	if strNode == "Source" and eMouseButton == GameLib.CodeEnumInputMouse.Right and tAttributes.strCharacterName and tAttributes.strCrossFaction then
		local bCross = tAttributes.strCrossFaction == "true"--sending boolean
		local nReportId = nil
		if tAttributes ~= nil and tAttributes.nReportId ~= nil then
			nReportId = tAttributes.nReportId
		end
		local tOptionalData = {nReportId = tAttributes.nReportId, bCrossFaction = bCross}
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", wndHandler, tAttributes.strCharacterName, nil, tOptionalData)
		return true
	end

	if strNode == "Link" then

		-- note, tAttributes.nLinkIndex is a string value, instead of the int we passed in because it was saved
		-- 	out as xml text then read back in.
		local nIndex = tonumber(tAttributes.strIndex)

		if self.tLinks[nIndex] and
			( self.tLinks[nIndex].uItem or self.tLinks[nIndex].uQuest or self.tLinks[nIndex].uArchiveArticle ) then

			if Apollo.IsShiftKeyDown() then

				local wndEdit = self:HelperGetCurrentEditbox()

				-- pump link to the chat line
				if wndEdit then
					self:HelperAppendLink( wndEdit, self.tLinks[nIndex] )
				end
			else
				if self.tLinks[nIndex].uItem then

					local bWindowExists = false
					for idx, wndCur in pairs(self.twndItemLinkTooltips or {}) do
						if wndCur:GetData() == self.tLinks[nIndex].uItem then
							bWindowExists = true
							break
						end
					end

					if bWindowExists == false then
						local wndChatItemToolTip = Apollo.LoadForm("ChatLog.xml", "TooltipWindow", nil, self)
						wndChatItemToolTip:SetData(self.tLinks[nIndex].uItem)

						table.insert(self.twndItemLinkTooltips, wndChatItemToolTip)

						local itemEquipped = self.tLinks[nIndex].uItem:GetEquippedItemForItemType()

						local wndLink = Tooltip.GetItemTooltipForm(self, wndControl, self.tLinks[nIndex].uItem, {bPermanent = true, wndParent = wndChatItemToolTip, bSelling = false, bNotEquipped = true})

						local nLeftWnd, nTopWnd, nRightWnd, nBottomWnd = wndChatItemToolTip:GetAnchorOffsets()
						local nLeft, nTop, nRight, nBottom = wndLink:GetAnchorOffsets()

						wndChatItemToolTip:SetAnchorOffsets(nLeftWnd, nTopWnd, nLeftWnd + nRight + 15, nBottom + 75)

						if itemEquipped then
							wndChatItemToolTip:SetTooltipDoc(nil)
							Tooltip.GetItemTooltipForm(self, wndChatItemToolTip, itemEquipped, {bPrimary = true, bSelling = false, bNotEquipped = false})
						end
					end

				elseif self.tLinks[nIndex].uQuest then
					Event_FireGenericEvent("ShowQuestLog", wndHandler:GetData()) -- Codex (todo: deprecate this)
					Event_FireGenericEvent("GenericEvent_ShowQuestLog", self.tLinks[nIndex].uQuest)
				elseif self.tLinks[nIndex].uArchiveArticle then
					Event_FireGenericEvent("HudAlert_ToggleLoreWindow")
					Event_FireGenericEvent("GenericEvent_ShowGalacticArchive", self.tLinks[nIndex].uArchiveArticle)
				end
			end
		end
	end

	return false
end

function ChatLog:OnCloseItemTooltipWindow(wndHandler, wndControl)
	local wndParent = wndControl:GetParent()
	local itemData = wndParent:GetData()

	for idx, wndCur in pairs(self.twndItemLinkTooltips) do
		if wndCur:GetData() == itemData then
			table.remove(self.twndItemLinkTooltips, idx)
		end
	end

	wndParent:Destroy()
end

function ChatLog:OnEvent_EngageAccountWhisper(strDisplayName, strCharacterName, strRealmName)
	local wndEdit = self:HelperGetCurrentEditbox()
	self.tAccountWhisperContex =
	{
		["strDisplayName"]		= strDisplayName,
		["strCharacterName"]	= strCharacterName,
		["strRealmName"]		= strRealmName,
	}
	local strOutput = String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), Apollo.GetString("ChatType_AccountTell"), strDisplayName)
	wndEdit:SetText(strOutput)
	wndEdit:SetFocus()
	wndEdit:SetSel(strOutput:len(), -1)
	self:OnInputChanged(nil, wndEdit, strOutput)
end

function ChatLog:OnEvent_EngageWhisper(strPlayerName)
	local wndEdit = self:HelperGetCurrentEditbox()

	local strOutput = String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), Apollo.GetString("ChatType_Tell"), strPlayerName)
	wndEdit:SetText(strOutput)
	wndEdit:SetFocus()
	wndEdit:SetSel(strOutput:len(), -1)
	self:OnInputChanged(nil, wndEdit, strOutput)
end

function ChatLog:OnChatReply()

	local wndParent = nil
	for idx, wndCurr in pairs(self.tChatWindows) do
		if wndCurr and wndCurr:IsValid() then
			wndParent = wndCurr
			break
		end
	end

	if not wndParent then
		return
	end

	if not self.tRecent or not self.tRecent[1] then
		return
	end

	--get the name of the first person on the recent, which will be either a character or account name
	local strTarget = self.tRecent[1].strCharacterName
	local strOutput = ""
	if self.channelReply then
		strOutput = String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), self.channelReply:GetAbbreviation(), strTarget)
	end

	local wndEdit = wndParent:FindChild("Input")
	wndEdit:SetText(strOutput)
	wndEdit:SetFocus()
	wndEdit:SetSel(strOutput:len(), -1)
	self:OnInputChanged(nil, wndEdit, strOutput)
end

function ChatLog:OnGenericEvent_ChatLogWhisper(strTarget)
	local wndParent = nil
	for idx, wndCurr in pairs(self.tChatWindows) do
		if wndCurr and wndCurr:IsValid() and wndCurr:GetData() and not wndCurr:GetData().bCombatLog then
			wndParent = wndCurr
			break
		end
	end

	if not wndParent then
		return
	end

	if not strTarget and self.tLastWhisperer and self.tLastWhisperer.strCharacterName then
		strTarget = self.tLastWhisperer.strCharacterName
	end

	local wndEdit = wndParent:FindChild("Input")
	local strOutput = String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), Apollo.StringToLower(Apollo.GetString("ChatType_Tell")), strTarget)
	wndEdit:SetText(strOutput)
	wndEdit:SetFocus()
	wndEdit:SetSel(strOutput:len(), -1)
	self:OnInputChanged(nil, wndEdit, strOutput)
end

function ChatLog:OnEmoteCheck(wndHandler, wndControl)
	local wndEmotes = wndControl:GetParent():FindChild("EmoteMenu")
	local wndContainer = wndEmotes:FindChild("EmoteMenuContent")
	local tEmotes = ChatSystemLib.GetEmotes()

	if wndHandler:IsChecked() then
		local nScrollPosition = wndContainer:GetVScrollPos() or 0
		wndContainer:DestroyChildren()

		for idx, strEmote in pairs(tEmotes) do
			if strEmote ~= "" and strEmote ~= nil then
				local wnd = Apollo.LoadForm(self.xmlDoc, "EmoteMenuEntry", wndContainer, self)
				wnd:SetText(String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), strEmote))
				wnd:SetData(strEmote)
			end
		end

		wndContainer:ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)
		wndContainer:SetVScrollPos(nScrollPosition)
	end
	wndEmotes:GetParent():FindChild("CloseBtn"):Enable(not wndHandler:IsChecked())
end

function ChatLog:OnEmoteMenuClosed(wndHandler, wndControl)
	local wndParent = wndHandler:GetParent()
	wndParent:FindChild("CloseBtn"):Enable(true)
	wndHandler:Close()
end

function ChatLog:OnEmoteMenuClose(wndHandler, wndControl)
	local wndGrandparent = wndControl:GetParent():GetParent()
	wndGrandparent:FindChild("EmoteBtn"):SetCheck(false)
	wndGrandparent:FindChild("CloseBtn"):Enable(true)
	wndControl:GetParent():Close()
end

function ChatLog:OnEmoteMenuEntry(wndHandler, wndControl)
	local strEmote = wndControl:GetData()
	local wndParent = wndControl:GetParent():GetParent()
	local wndEdit = wndParent:GetParent():FindChild("Input")
	local wndToggle = wndParent:GetParent():FindChild("EmoteBtn")
	local strEntry = String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), strEmote)
	wndEdit:SetText(strEntry)
	wndEdit:SetFocus()
	wndEdit:SetSel(strEntry:len(), -1)
	wndParent:Show(false)
	wndToggle:SetCheck(false)

	self:OnInputChanged(nil, wndEdit, strEntry)
end

function ChatLog:HelperLoadSetRules(luaSubclass)
	if not luaSubclass then
		return
	end

	local tRules = {}
	if self.channelWhisper and self.channelAccountWhisper then 
		tRules[Apollo.StringToLower(self.channelAccountWhisper:GetCommand())] = {}
		tRules[Apollo.StringToLower(self.channelWhisper:GetCommand())] = {}
	end
	
	local eNot 				= luaSubclass:GetEnumNot()
	local eOr 				= luaSubclass:GetEnumOr()
	local eAnd 				= luaSubclass:GetEnumAnd()
	
	local eFriends 			= luaSubclass:GetEnumFriends()
	local eAccountFriends 	= luaSubclass:GetEnumAccountFriends()
	local eNeighbors 		= luaSubclass:GetEnumNeighbors()
	local eGroups 			= luaSubclass:GetEnumGroups()
	local eRecent 			= luaSubclass:GetEnumRecent()

	if not eNot or not eOr or not eAnd or not eFriends or not eAccountFriends or not eNeighbors or not eGroups or not eRecent then
		return
	end

	tRules[Apollo.StringToLower(Apollo.GetString("Command_Neighbor_Invite"))] 				= {eOperator = eNot, arRelationFilters = {eNeighbors}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Neighbor_Remove"))] 				= {arRelationFilters = {eNeighbors}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Group_Invite"))] 					= {eOperator = eNot, arRelationFilters = {eGroups}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Group_Join"))] 					= {eOperator = eNot, arRelationFilters = {eGroups}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_Friend"))] 			= {eOperator = eNot, arRelationFilters = {eFriends}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_Unfriend"))] 			= {arRelationFilters = {eFriends}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_FriendAccount"))] 		= {eOperator = eNot, arRelationFilters = {eAccountFriends}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_UnfriendAccount"))]	= {arRelationFilters = {eAccountFriends}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_Ignore"))] 			= {eOperator = eAnd, arRelationFilters = {eRecent, {eOperator = eNot, arRelationFilters = {eAccountFriends}}}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_Rival"))] 				= {}--May want to come back and keep track of this also
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_Unrival"))] 			= {}--May want to come back and keep track of this also
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_Accept"))] 			= {eOperator = eNot, arRelationFilters = {eFriends}}
	tRules[Apollo.StringToLower(Apollo.GetString("Command_Friendship_Decline"))] 			= {eOperator = eNot, arRelationFilters = {eFriends}}

	return tRules
end

function ChatLog:OnSuggestedMenuResult(tInfo, nTextBoxId)
	local wndEdit = self:HelperGetCurrentEditbox()
	if not wndEdit or nTextBoxId ~= wndEdit:GetId() or not tInfo then
		return
	end

	--this section will auto correct the channel if it was a communication command, otherwise use original.
	local tInput = ChatSystemLib.SplitInput(wndEdit:GetText())
	local strCommand = ""
	local strExtraSpace = " "
	local eChannelType = nil
	if tInput and tInput.channelCommand ~= self.channelAccountWhisper and tInput.channelCommand  ~= self.channelWhisper then
		strCommand 	  = tInput.strCommand
		eChannelType  = tInput.channelCommand:GetType()
		bExtraSpace   = false
		strExtraSpace = ""
	elseif tInfo.bAccountFriends then
		strCommand    = self.channelAccountWhisper:GetAbbreviation()
		eChannelType  = ChatSystemLib.ChatChannel_AccountWhisper
	else
		strCommand    = self.channelWhisper:GetAbbreviation()
		eChannelType  = ChatSystemLib.ChatChannel_Whisper
	end

	local strOutput = "/"..strCommand.." "..tInfo.strCharacterName..strExtraSpace
	wndEdit:SetText(strOutput)
	local eChannelColorType = eChannelType or tInput and tInput.channelCommand:GetType()
	wndEdit:SetTextColor(self.arChatColor[eChannelColorType] or ApolloColor.new("white"))
	wndEdit:SetFocus()
	wndEdit:SetSel(strOutput:len(), -1)
end

function ChatLog:OnCloseChatWindow(wndHandler, wndControl)
	local wndForm = wndControl:GetParent()
	local tChatData = wndForm:GetData()

	if tChatData ~= nil then -- remove this window's channels from the total list
		for idx, value in pairs(tChatData.tViewedChannels) do
			if tChatData.tViewedChannels[idx] then
			self:HelperRemoveChannelFromAll(idx)
		end
	end
	end

	for idx = 1,#self.tChatWindows do
		if self.tChatWindows[idx] == wndForm then
			table.remove(self.tChatWindows, idx)
		end
		if #self.tChatWindows == 1 then
			self.tChatWindows[1]:FindChild("CloseBtn"):Show(false)
		end
	end

	wndForm:Detach()
	wndForm:Destroy()
end

function ChatLog:OnChatInputReturn(wndHandler, wndControl, strText)
	if wndControl:GetName() == "Input" then
		local wndForm = wndControl:GetParent()
		strText = self:HelperReplaceLinks(strText, wndControl:GetAllLinks())

		local wndInput = wndForm:FindChild("Input")

		local luaSubclass = wndControl:GetWindowSubclass()
		if luaSubclass and luaSubclass:IsSuggestedMenuShown() then
			luaSubclass:OnEditBoxReturn(wndHandler, wndControl)
			return
		end
		wndControl:SetText("")
		if self.eRoleplayOption == 2 then
			wndControl:SetText(Apollo.GetString("ChatLog_RPMarker"))
		end

		local tChatData = wndForm:GetData()
		local bViewedChannel = true
		local tInput = ChatSystemLib.SplitInput(strText)
		if strText ~= "" and strText ~= Apollo.GetString("ChatLog_RPMarker") and strText ~= Apollo.GetString("ChatLog_Marker") then
			local channelCurrent = tInput.channelCommand or tChatData.channelCurrent
			self.channelLastChannel = channelCurrent
			if channelCurrent:GetType() == ChatSystemLib.ChatChannel_Command then
				if tInput.bValidCommand then -- good command
					ChatSystemLib.Command( strText )
				else	-- bad command
					local strFailString = String_GetWeaselString(Apollo.GetString("ChatLog_UnknownCommand"), Apollo.GetString("CombatFloaterType_Error"), {strLiteral = tInput.strCommand})
					ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, strFailString, "" )
					wndInput:SetText(String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), {strLiteral = tInput.strCommand}, {strLiteral = tInput.strMessage}))
					wndInput:SetFocus()
					local strSubmitted = wndForm:FindChild("Input"):GetText()
					wndInput:SetSel(strSubmitted:len(), -1)
					return
				end
			else
				tChatData.channelCurrent = channelCurrent
				bViewedChannel = self:VerifyChannelVisibility(channelCurrent, tInput, wndForm)
			end
		end

		--updating the string for the prompt to tell you the whisper target.
		local strPromptText = tChatData.channelCurrent:GetCommand()
		local eChannelType = tChatData.channelCurrent:GetType()
		if self.strLastTarget and (eChannelType == ChatSystemLib.ChatChannel_Whisper or eChannelType == ChatSystemLib.ChatChannel_AccountWhisper) then
			strPromptText = strPromptText.. " " .. self.strLastTarget
		end

		local crText = self.arChatColor[tChatData.channelCurrent:GetType()] or ApolloColor.new("white")
		wndForm:GetData().crText = crText
		wndInput:SetPrompt(strPromptText)--here add name if whisper
		wndInput:SetPromptColor(crText)
		wndInput:SetTextColor(crText)

		if bViewedChannel ~= true then
			wndInput:SetTextColor(kcrInvalidColor)
			wndInput:SetPrompt("X " .. tInput.strCommand)
		end
		
		self:ChatActionTaken(wndControl:GetParent())
	end
end


function ChatLog:VerifyChannelVisibility(channelChecking, tInput, wndChat)
	local tChatData = wndChat:GetData()

	if self.tAllViewedChannels[channelChecking:GetUniqueId()] ~= nil then -- see if this channelChecking is viewed
		local strMessage = tInput.strMessage
		if channelChecking:GetType() == ChatSystemLib.ChatChannel_AccountWhisper then
			if self.tAccountWhisperContex then
				local strCharacterAndRealm = self.tAccountWhisperContex.strCharacterName .. "@" .. self.tAccountWhisperContex.strRealmName
				strMessage = string.gsub(strMessage, self.tAccountWhisperContex.strDisplayName, strCharacterAndRealm, 1)
			end
		end

		-- if there is a str command, they are changing the channel, or whisper target
		--the target can be the same as the last target
		if tInput.strCommand ~= "" then
			self.strLastTarget = ""
		end

		local strSend = ""
		if self.strLastTarget and self.strLastTarget ~= "" then --use last whispered as the target
			strSend = self.strLastTarget.." "..strMessage
		else --updating last whispered for next messages
			strSend = strMessage

			local strPattern = "" --using regex pattern
			if channelChecking:GetType() == ChatSystemLib.ChatChannel_Whisper then
				--find a space, any number of alphabet characters, and then another space
				strPattern = "%s%a*%s*"
			elseif channelChecking:GetType() == ChatSystemLib.ChatChannel_AccountWhisper then
				--since account names only are one word, find a space
				strPattern = "%s"
			end
			local nPlaceHolder, nIndexOfPatternSpace = string.find(strSend, strPattern)
			if strPattern ~= "" and nIndexOfPatternSpace then
				self.strLastTarget = string.sub(strSend, 0, nIndexOfPatternSpace -1)--gets the name of the target
			end
		end

		channelChecking:Send(strSend)
		return true
	else
		local wndInput = wndChat:FindChild("Input")

		strMessage = String_GetWeaselString(Apollo.GetString("CRB_Message_not_sent_you_are_not_viewing"), channelChecking:GetName())
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Command, strMessage, "" )
		wndInput:SetText(String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), tInput.strCommand, tInput.strMessage))
		wndInput:SetFocus()
		local strSubmitted = wndInput:GetText()
		wndInput:SetSel(strSubmitted:len(), -1)
		return false
	end
end

function ChatLog:InsertIntoRecent(strInsertName, bAccountFriends)
	--check and see if name was already in tRecent
	local nRemoveIndex = -1
	for idx, tInfo in pairs(self.tRecent) do
		if tInfo.strCharacterName == strInsertName then
			nRemoveIndex = idx
			break
		end
	end
	if nRemoveIndex ~= -1 then --already had this person
		table.remove(self.tRecent, nRemoveIndex)
	end

	if #self.tRecent > knMaxRecentEntries then
		table.remove(self.tRecent, knMaxRecentEntries)--remove the last
	end
	table.insert(self.tRecent, 1, {strCharacterName = strInsertName, bAccountFriends = bAccountFriends})

	Event_FireGenericEvent("UpdateRecent", self.tRecent)
end

function ChatLog:RemoveFromRecent(strCharacterName)
	if self.tRecent[strCharacterName] then
		self.tRecent[strCharacterName] = nil
	end
	Event_FireGenericEvent("UpdateRecent", self.tRecent)
end

function ChatLog:OnWindowGainedFocus(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	wndHandler:SetSel(wndHandler:GetText():len(), -1)
end

function ChatLog:OnInputChanged(wndHandler, wndControl, strText)
	local wndForm = wndControl:GetParent()

	if wndControl:GetName() ~= "Input" then
		return
	end

	for idx, wndChat in pairs(self.tChatWindows) do
		wndChat:FindChild("Input"):SetData(false)
	end
	wndControl:SetData(true)

	local wndForm = wndControl:GetParent()
	local wndInput = wndForm:FindChild("Input")

	if Apollo.StringToLower(strText) == Apollo.GetString("ChatLog_Reply") and self.tLastWhisperer and self.tLastWhisperer.strCharacterName ~= "" then
		local strName = self.tLastWhisperer.strCharacterName
		local channel = self.channelWhisper
		if self.tLastWhisperer.eChannelType == ChatSystemLib.ChatChannel_AccountWhisper then
			channel = self.channelAccountWhisper

			self.tAccountWhisperContex =
			{
				["strDisplayName"]		= self.tLastWhisperer.strDisplayName,
				["strCharacterName"]	= self.tLastWhisperer.strCharacterName,
				["strRealmName"]		= self.tLastWhisperer.strRealmName,
			}
			strName = self.tLastWhisperer.strDisplayName
		end

		local strWhisper = String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), channel:GetAbbreviation(), strName)
		wndInput:SetPrompt(channel:GetCommand())
		wndInput:SetPromptColor(self.arChatColor[self.tLastWhisperer.eChannelType])
		wndInput:SetTextColor(self.arChatColor[self.tLastWhisperer.eChannelType])
		wndInput:SetText(strWhisper)
		wndInput:SetFocus()
		wndInput:SetSel(strWhisper:len(), -1)
		return
	end

	local tChatData = wndForm:GetData()
	local tInput = ChatSystemLib.SplitInput(strText)
	local channelInput = tInput.channelCommand or tChatData.channelCurrent
	local crText = self.arChatColor[channelInput:GetType()] or ApolloColor.new("white")
	wndInput:SetStyleEx("PromptColor", crText)
	wndInput:SetTextColor(crText)

	if channelInput:GetType() == ChatSystemLib.ChatChannel_Command then -- command or emote
		if tInput.bValidCommand then
			if not self.tEmotes[tInput.strCommand] then
				wndInput:SetPrompt(String_GetWeaselString(Apollo.GetString("CRB_CurlyBrackets"), "", tInput.strCommand))
				wndInput:SetPromptColor(kcrValidColor)
				wndInput:SetTextColor(kcrValidColor)
			end
		else
			--if there was a last channel, use that. otherwise default to say.
			wndInput:SetPrompt(self.channelLastChannel and self.channelLastChannel:GetCommand() or self.channelSay:GetCommand())
		end
	else -- chatting in a channel; check for visibility
		if self.tAllViewedChannels[ channelInput:GetType() ] ~= nil then -- channel is viewed
			wndInput:SetPrompt(channelInput:GetCommand())
		else -- channel is hidden
			wndInput:SetPrompt(String_GetWeaselString(Apollo.GetString("ChatLog_Invalid"), channelInput:GetCommand()))
			wndInput:SetPromptColor(kcrInvalidColor)
		end
	end
	
	local luaSubclass = wndInput:GetWindowSubclass()
	if luaSubclass and tInput then
		if not self.tSuggestedFilterRules then
			self.tSuggestedFilterRules = self:HelperLoadSetRules(luaSubclass)
		end

		if tInput.bValidCommand then
			strCommandName = tInput.channelCommand and tInput.channelCommand:GetCommand() ~= "" and tInput.channelCommand:GetCommand() or tInput.strCommand
		end

		if strCommandName ~= "" then
			local strLowerCaseCommand = Apollo.StringToLower(strCommandName)
			if self.tSuggestedFilterRules and self.tSuggestedFilterRules[strLowerCaseCommand] then
				local strPlaceHolder, nCountSpaces = string.gsub(strText, " ", " ")
				if tInput.bValidCommand and nCountSpaces <= knCountSpaces then
					local tSuggestFilterInfo = self.tSuggestedFilterRules[strLowerCaseCommand]
					self.tLastFilteredInfo = tSuggestFilterInfo
					luaSubclass:SetFilters(tSuggestFilterInfo)
					luaSubclass:OnEditBoxChanged(wndHandler, wndControl, tInput.strMessage)
				elseif tInput.bValidCommand and nCountSpaces > knCountSpaces or not tInput.bValidCommand and luaSubclass:IsSuggestedMenuShown() then
					luaSubclass:HideSuggestedMenu()
				end
			end
		end
	end
end

function ChatLog:FindAnInputWindow()
	for idx, wnd in pairs(self.tChatWindows) do
		wnd:FindChild("Input"):SetData(false)
	end
end

function ChatLog:OnAddWindow(wndHandler, wndControl)
	local wndForm = wndControl:GetParent() -- TODO refactor
	local wndAdd = wndForm:FindChild("AddTabSubForm")
	local bShown = wndAdd:IsShown()


	for key, wndChat in pairs(self.tChatWindows) do
		if wndChat:FindChild("AddTabSubForm"):IsShown() then
			wndChat:FindChild("AddTabSubForm"):Show(false)
		end
	end

	if not bShown then
		wndAdd:Invoke()
	else
		wndAdd:Close()
	end
end

function ChatLog:OnAddTabSubFormClose(wndHandler, wndControl)
	local wndForm = wndControl:GetParent() -- TODO refactor
	wndForm:FindChild("AddTabSubForm"):Close()
end

function ChatLog:OnAddNewTabChat(wndHandler, wndControl) -- this is when a tab; each is its own window
	wndControl:GetParent():Close()
	self.nChatIndex = self.nChatIndex + 1

	local wndForm = wndControl:GetParent():GetParent() -- TODO refactor
	local tData = wndForm:GetData()
	local strName = String_GetWeaselString(Apollo.GetString("ChatLog_SecondChannel"), Apollo.GetString("CRB_Chat"), self.nChatIndex)

	local tChannelsToView = tData.bCombatLog and self.tCombatChannels or tData.tViewedChannels

	-- needs to take it from the main form of toggled from a combat window (idx == 1)
	if wndForm:FindChild("BGArt_ChatBackerIcon"):IsShown() then
		for idx, wndChat in pairs(self.tChatWindows) do
			local tChatData = wndChat:GetData()
			if not wndChat:FindChild("BGArt_ChatBackerIcon"):IsShown() then
				tChannelsToView = tChatData.tViewedChannels
				break
			end
		end
	end

	local wndNewForm = self:NewChatWindow(strName, tChannelsToView, false, tData.channelCurrent)

	wndForm:AttachTab(wndNewForm, true)
	wndNewForm:FindChild("Options"):SetCheck(true)

	self:OnSettings(wndNewForm:FindChild("Options"), wndNewForm:FindChild("Options"))
end

function ChatLog:OnAddNewTabCombat(wndHandler, wndControl) -- this is when a tab; each is its own window
	wndControl:GetParent():Close()
	self.nChatIndex = self.nChatIndex + 1

	local wndForm = wndControl:GetParent():GetParent()
	local tData = wndForm:GetData()
	local strName = String_GetWeaselString(Apollo.GetString("ChatLog_SecondChannel"), Apollo.GetString("ChatType_Combat"), self.nChatIndex)
	local wndNewForm = self:NewChatWindow(strName, tData.tViewedChannels, true, tData.channelCurrent)

	wndForm:AttachTab(wndNewForm, true)
	wndNewForm:FindChild("Options"):SetCheck(true)

	self:OnSettingsCombat(wndNewForm:FindChild("Options"), wndNewForm:FindChild("Options"))
end

function ChatLog:OnSaveLog(wndHandler, wndControl)
	wndControl:Enable(false)
end

function ChatLog:GetDisplayNameForChannel(strChannel)
	return strChannel
end

function ChatLog:AddChannelTypeToList(tData, wndList, channel)
	local wndChannelItem = Apollo.LoadForm(self.xmlDoc, "ChatType", wndList, self)
	wndChannelItem:FindChild("TypeName"):SetText(channel:GetName())
	wndChannelItem:SetData(channel:GetUniqueId())
	wndChannelItem:FindChild("ViewCheck"):SetCheck(tData.tViewedChannels[channel:GetUniqueId()] or false)
end

function ChatLog:OnViewCheck(wndHandler, wndControl)
	local wndChannel = wndControl:GetParent()
	local wndOptions = wndChannel:GetParent():GetParent():GetParent()
	local eChannelId = wndChannel:GetData()
	local tData = wndOptions:GetData()

	if tData == nil then
		return
	end

	if tData.tViewedChannels[eChannelId] then
		tData.tViewedChannels[eChannelId] = false
		self:HelperRemoveChannelFromAll(eChannelId)
	else
		tData.tViewedChannels[eChannelId] = true
		self:HelperAddChannelToAll(eChannelId)
	end
end

function ChatLog:OnChatTitleChanged(wndHandler, wndControl, strNewTitle)
	local tData = wndControl:GetParent():GetParent():GetParent():GetParent():GetData()
	tData.wndForm:SetText(strNewTitle)
end

function ChatLog:OnOptionsSubFormClosed( wndHandler, wndControl )
	if wndHandler ~= wndControl then return end

	local wndForm = wndControl:GetData()
	wndForm:FindChild("Input"):Show(true)
end

function ChatLog:OnSettings(wndHandler, wndControl)
	local wndForm = wndControl:GetParent()
	local tData = wndForm:GetData()

	if wndForm:FindChild("BGArt_ChatBackerIcon"):IsShown() then
		self:OnSettingsCombat(wndForm:FindChild("Options"), wndForm:FindChild("Options"))
		return
	end

	if not wndControl:IsChecked() then
		tData.wndOptions:Show(false)
		wndForm:FindChild("Input"):Show(true)
	else
		if wndForm:FindChild("EmoteMenu"):IsVisible() then
			wndForm:FindChild("EmoteMenu"):Show(false)
			wndForm:FindChild("EmoteBtn"):SetCheck(false)
		end

		if wndForm:FindChild("InputWindow"):IsVisible() then
			wndForm:FindChild("InputWindow"):Show(false)
			wndForm:FindChild("InputTypeBtn"):SetCheck(false)
		end

		self:DrawSettings(wndForm)
	end
end

function ChatLog:OnSettingsCombat(wndHandler, wndControl)
	local wndForm = wndControl:GetParent()
	local tData = wndForm:GetData()

	if not wndControl:IsChecked() then
		tData.wndOptions:Show(false)
		wndForm:FindChild("Input"):Show(true)
	else
		if wndForm:FindChild("EmoteMenu"):IsVisible() then
			wndForm:FindChild("EmoteMenu"):Show(false)
			wndForm:FindChild("EmoteBtn"):SetCheck(false)
		end

		if wndForm:FindChild("InputWindow"):IsVisible() then
			wndForm:FindChild("InputWindow"):Show(false)
			wndForm:FindChild("InputTypeBtn"):SetCheck(false)
		end

		self:DrawSettingsCombat(wndForm)
	end
end

function ChatLog:DrawSettings(wndForm)
	local tData = wndForm:GetData()

	tData.wndOptions:Show(true)

	local wndList = tData.wndOptions:FindChild("ChatTypesList")
	wndList:DestroyChildren()
	wndList:RecalculateContentExtents()

	local wndNameEntry = Apollo.LoadForm(self.xmlDoc, "ChatNameEntry", wndList, self)
	wndNameEntry:FindChild("Name"):SetText(wndForm:GetText())

	--wndNameEntry:FindChild("Name"):SetSel(0, -1)
	--wndNameEntry:FindChild("Name"):SetFocus()

	local tChannels = ChatSystemLib.GetChannels()

	local wndCat = Apollo.LoadForm(self.xmlDoc, "ChatCategory", wndList, self)
	for idx, channelCurrent in ipairs(tChannels) do
		self:AddChannelTypeToList(tData, wndList, channelCurrent)
	end

	local tCustomChannels = {}
	for idx, channelViewed in pairs(tChannels) do -- gives us our viewed channels
		if channelViewed:GetType() == ChatSystemLib.ChatChannel_Custom then
			table.insert(tCustomChannels, channelViewed)
		end
	end

	local wndCustomHeader = Apollo.LoadForm(self.xmlDoc, "CustomChatCategory", wndList, self)
	--wndCustomHeader:FindChild("FramingAccent"):Show(#tCustomChannels > 0)

	local wndAddJoinChannel = wndCustomHeader:FindChild("AddJoinForm")
	wndCustomHeader:FindChild("AddJoinCustomChannel"):AttachWindow(wndAddJoinChannel)
	wndAddJoinChannel:FindChild("AddJoinConfirmBtn"):Enable(false)
	wndAddJoinChannel:Show(false)

	if #tCustomChannels > 0 then
		for idxCustom, channelCustom in pairs(tCustomChannels) do
			local wndCustomChannel = Apollo.LoadForm(self.xmlDoc, "ChatTypeCustom", wndList, self)
			wndCustomChannel:FindChild("LeaveCustomChannelBtn"):SetData(channelCustom)
			wndCustomChannel:FindChild("TypeName"):SetText(String_GetWeaselString(Apollo.GetString("ChatLog_ChannelCommand"), channelCustom:GetCommand(), channelCustom:GetName()))
		end
	end

	wndList:ArrangeChildrenVert()
	tData.wndOptions:SetOpacity(0.9)
	wndForm:FindChild("Input"):Show(false)
end

function ChatLog:DrawSettingsCombat(wndForm)
	local tData = wndForm:GetData()

	tData.wndOptions:Show(true)

	local wndList = tData.wndOptions:FindChild("ChatTypesList")
	wndList:DestroyChildren()
	wndList:RecalculateContentExtents()

	local wndNameEntry = Apollo.LoadForm(self.xmlDoc, "ChatNameEntry", wndList, self)
	wndNameEntry:FindChild("Name"):SetText(wndForm:GetText())

	--wndNameEntry:FindChild("Name"):SetSel(0, -1)
	--wndNameEntry:FindChild("Name"):SetFocus()

	local wndCat = Apollo.LoadForm(self.xmlDoc, "ChatCategory", wndList, self)
	for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels()) do
		if self.tCombatChannels[channelCurrent:GetType()] then
			self:AddChannelTypeToList(tData, wndList, channelCurrent)
		end
	end

	wndList:ArrangeChildrenVert()
	tData.wndOptions:SetOpacity(0.9)
	wndForm:FindChild("Input"):Show(false)
end

function ChatLog:OnBeginChat(wndHandler, wndControl)
	wndControl:GetParent():FindChild("Input"):SetFocus()
end

function ChatLog:OnItemSentToCrate(itemSentToCrate, nCount)
	if itemSentToCrate == nil or nCount == 0 then
		return
	end
	local tFlags = {ChatFlags_Loot=true}
	local strMessage = String_GetWeaselString(Apollo.GetString("ChatLog_ToHousingCrate"), {["count"] = nCount, ["name"] = itemSentToCrate:GetName()})
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Loot, strMessage, "" )
end

function ChatLog:OnHarvestItemsSentToOwner(arSentToOwner)
	for _, tSent in ipairs(arSentToOwner) do
		if tSent.item then
			local strMessage = String_GetWeaselString(Apollo.GetString("Housing_HarvestingLoot"), {["count"] = tSent.nCount, ["name"] = tSent.item:GetName()})
			ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Loot, strMessage, "" )
		end
	end
end

function ChatLog:OnGenericEvent_LootChannelMessage(strMessage)
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_Loot, strMessage, "" )
end

function ChatLog:OnGenericEvent_SystemChannelMessage(strMessage)
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, strMessage, "" )
end

function ChatLog:OnGenericEvent_LinkItemToChat(itemLinked)
	if itemLinked == nil then
		return
	end

	tLink = {}
	tLink.uItem = itemLinked
	tLink.strText = String_GetWeaselString(Apollo.GetString("CRB_Brackets"), itemLinked:GetName())

	local wndEdit = self:HelperGetCurrentEditbox()

	-- pump link to the chat line
	if wndEdit then
		self:HelperAppendLink( wndEdit, tLink )
	end
end

function ChatLog:OnCombatLogLoot(tEventArgs)
	local strResult = ""
	if tEventArgs.monLoot then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_LootReceived"), tEventArgs.monLoot:GetMoneyString())
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult)
	end

	if tEventArgs.nItemAmount > 0 and tEventArgs.itemLoot then
		local strArgItemName = tEventArgs.itemLoot:GetName()
		local strItemName = Apollo.GetString("CombatLog_SpellUnknown")
		if strArgItemName and strArgItemName ~= "" then
			strItemName = strArgItemName
		end

		if tEventArgs.nItemAmount > 1 then
			strItemName = String_GetWeaselString(Apollo.GetString("CombatLog_MultiItem"), tEventArgs.nItemAmount, strItemName)
		end

		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_LootReceived"), strItemName)

		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult)
	end
end

function ChatLog:OnPlayedtime(strCreationDate, strPlayedTime, strPlayedLevelTime, strPlayedSessionTime, dateCreation, nSecondsPlayed, nSecondsLevel, nSecondsSession)
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, strCreationDate, "" )
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, strPlayedTime, "" )
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, strPlayedLevelTime, "" )
	ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, strPlayedSessionTime, "" )
end

function ChatLog:OnGenericEvent_QuestLink(queLinked)
	if queLinked == nil or not Quest.is(queLinked) then
		return
	end

	local tLink = {}
	tLink.uQuest = queLinked
	tLink.strText = String_GetWeaselString(Apollo.GetString("CRB_Brackets"), queLinked:GetTitle())

	local wndEdit = self:HelperGetCurrentEditbox()

	-- pump link to the chat line
	if wndEdit then
		self:HelperAppendLink(wndEdit, tLink)
	end
end

function ChatLog:OnGenericEvent_ArchiveArticleLink(artLinked)
	if artLinked == nil then
		return
	end

	local tLink = {}
	tLink.uArchiveArticle = artLinked
	tLink.strText = String_GetWeaselString(Apollo.GetString("CRB_Brackets"), artLinked:GetTitle())

	local wndEdit = self:HelperGetCurrentEditbox()

	-- pump link to the chat line
	if wndEdit then
		self:HelperAppendLink( wndEdit, tLink )
	end
end

function ChatLog:OnSaveBtn()
end

function ChatLog:OnInputTypeCheck(wndHandler, wndControl)
	local wndParent = wndControl:GetParent()
	local wndMenu = wndParent:FindChild("InputWindow")

	if wndHandler:IsChecked() then
		wndMenu:Invoke()
	else
		wndMenu:Close()
	end

	if wndHandler:IsChecked() then
		self:BuildInputTypeMenu(wndParent)
	end
end

function ChatLog:BuildInputTypeMenu(wndChat) -- setting this up externally so we can remove it from toggle at some point
	--local wndChannel = wndControl:GetParent()
	--local wndOptions = wndChat:GetParent():GetParent():GetParent()
	--local channelType = wndChannel:GetData()
	local tData = wndChat:GetData()

	if tData == nil then
		return
	end

	local wndInputMenu = wndChat:FindChild("InputWindow")
	local wndContent = wndInputMenu:FindChild("InputMenuContent")
	wndContent:DestroyChildren()

	local tChannels = ChatSystemLib.GetChannels()
	local nEntryHeight = 26 --height of the entry wnd
	local nCount = 0 --number of joined channels

	for idx, channelCurrent in pairs(tChannels) do -- gives us our viewed channels
		if self.tAllViewedChannels[channelCurrent:GetUniqueId()] ~= nil then
			if channelCurrent:GetCommand() ~= nil and channelCurrent:GetCommand() ~= "" then -- make sure it's a channelCurrent that can be spoken into
				local strCommand = channelCurrent:GetAbbreviation()

				if strCommand == "" or strCommand == nil then
					strCommand = channelCurrent:GetCommand()
				end

				local wndEntry = Apollo.LoadForm(self.xmlDoc, "InputMenuEntry", wndContent, self)

				local strType = ""
				if channelCurrent:GetType() == ChatSystemLib.ChatChannel_Custom then
					strType = Apollo.GetString("ChatLog_CustomLabel")
				end

				wndEntry:FindChild("NameText"):SetText(channelCurrent:GetName())
				wndEntry:FindChild("CommandText"):SetText(String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), strCommand))
				wndEntry:SetData(channelCurrent) -- set the channelCurrent

				local crText = self.arChatColor[channelCurrent:GetType()] or ApolloColor.new("white")
				wndEntry:FindChild("CommandText"):SetTextColor(crText)
				wndEntry:FindChild("NameText"):SetTextColor(crText)

				nCount = nCount + 1
			end
		end
	end

	if nCount == 0 then
		local wndEntry = Apollo.LoadForm(self.xmlDoc, "InputMenuEntry", wndContent, self)
		wndEntry:Enable(false)
		wndEntry:FindChild("NameText"):SetText(Apollo.GetString("CRB_No_Channels_Visible"))
		nCount = 1
	end

	nEntryHeight = nEntryHeight * nCount
	wndInputMenu:SetAnchorOffsets(self.nInputMenuLeft, math.max(-knChannelListHeight , self.nInputMenuTop - nEntryHeight), self.nInputMenuRight, self.nInputMenuBottom)

	wndContent:ArrangeChildrenVert()
end

function ChatLog:OnInputMenuEntry(wndHandler, wndControl)
	local channelCurrent = wndControl:GetData()
	local wndChat = wndControl:GetParent():GetParent():GetParent()
	local tChatData = wndChat:GetData()
	local wndInput = wndChat:FindChild("Input")
	local strText = wndInput:GetText()
	local strCommand = channelCurrent:GetAbbreviation()

	if strCommand == "" or strCommand == nil then
		strCommand = channelCurrent:GetCommand()
	end

	if strText == "" then
		strText = String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), strCommand.." ")
	else
		local tInput = ChatSystemLib.SplitInput(strText) -- get the existing message, ignore the old command
		strText = String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), strCommand).." "..tInput.strMessage
	end

	wndInput:SetText(strText)
	local crText = self.arChatColor[channelCurrent:GetType()] or ApolloColor.new("white")
	wndInput:SetTextColor(crText)
	wndInput:SetPrompt(channelCurrent:GetCommand())
	wndInput:SetPromptColor(crText)
	wndInput:SetFocus()
	wndInput:SetSel(strText:len(), -1)

	tChatData.channelCurrent = channelCurrent

	wndControl:GetParent():GetParent():Show(false)
	wndChat:FindChild("InputTypeBtn"):SetCheck(false)
end

function ChatLog:OnRoleplayBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local wndParent = wndControl:GetParent()
	self.eRoleplayOption = wndParent:GetRadioSel("RoleplayViewToggle")
	for idx, wndChat in pairs(self.tChatWindows) do
		if self.eRoleplayOption == 2 then
			wndChat:FindChild("Input"):SetText(Apollo.GetString("ChatLog_RPMarker"))
		else
			wndChat:FindChild("Input"):SetText("")
		end
	end
end

function ChatLog:OnLeaveCustomChannelBtn(wndHandler, wndControl)
	if wndControl:GetData() == nil then return end

	local wndChannel = wndControl:GetData()
	wndChannel:Leave()
	local wndParent = wndControl:GetParent()
	local wndChat = wndParent:GetParent():GetParent():GetParent() -- TODO REFACTOR
	wndChat:FindChild("Options"):SetCheck(false)
	wndChat:FindChild("OptionsSubForm"):Show(false)
	wndChat:FindChild("Input"):Show(true)
end


-------- Custom Channel Functions ---------
function ChatLog:OnAddJoinCustomChannel(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local wndHeader = wndControl:GetParent()
	if wndControl:IsChecked() then
		wndHeader:FindChild("AddJoinForm"):Invoke()
	else
		wndHeader:FindChild("AddJoinForm"):Close()
	end
end

function ChatLog:OnAddJoinInputChanging(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local strInput = wndControl:GetText()
	local bNameValid = GameLib.IsTextValid(strInput, GameLib.CodeEnumUserText.ChatCustomChannelName, GameLib.CodeEnumUserTextFilterClass.Strict )

	local wndForm = wndControl:GetParent()
	wndForm:FindChild("AddJoinConfirmBtn"):Enable(self:HelperCheckForEmptyString(strInput) and bNameValid)
	wndForm:FindChild("InvalidInputWarning"):Show(self:HelperCheckForEmptyString(strInput) and not bNameValid)
end

function ChatLog:OnAddJoinCancelBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end
	local wndForm = wndControl:GetParent()
	wndForm:FindChild("AddJoinConfirmBtn"):Enable(false)
	wndForm:FindChild("AddJoinInput"):SetText("")
	wndForm:Show(false)
end

function ChatLog:OnAddJoinFormClose(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end
	wndControl:FindChild("AddJoinConfirmBtn"):Enable(false)
	wndControl:FindChild("AddJoinInput"):SetText("")
	wndControl:Close()
end

function ChatLog:OnAddJoinConfirmBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end
	local wndForm = wndControl:GetParent()
	local strName = wndForm:FindChild("AddJoinInput"):GetText()
	ChatSystemLib.JoinChannel(strName)

	local wndChat = wndForm:GetParent():GetParent():GetParent():GetParent() -- TODO REFACTOR
	wndChat:FindChild("Options"):SetCheck(false)
	wndChat:FindChild("OptionsSubForm"):Show(false)
	wndChat:FindChild("Input"):Show(true)
end

function ChatLog:OnFontSizeOption(wndHandler, wndControl)
	local tFontOption = wndControl:GetData()
	self.strFontOption = tFontOption.strNormal
	self.strAlienFontOption = tFontOption.strAlien
	self.strRPFontOption = tFontOption.strRP
end

function ChatLog:OnTimestamp(wndHandler, wndControl)
	self.bShowTimestamp = wndControl:GetData()
end

function ChatLog:OnProfanityFilter(wndHandler, wndControl)
	if wndHandler == wndControl then
		self.bProfanityFilter = wndControl:GetData()
		for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels()) do
			channelCurrent:SetProfanity(self.bProfanityFilter)
		end
		Apollo.SetConsoleVariable("chat.filter", self.bProfanityFilter)
	end
end

function ChatLog:OnChannelLabel(wndHandler, wndControl)
	self.bShowChannel = wndControl:GetData()
end

function ChatLog:OnBGFade(wndHandler, wndControl)
	local wndParent = wndControl:GetParent()
	self.bEnableBGFade = wndControl:GetData()
	self.bEnableNCFade = wndControl:GetData()

	local nCurrentGameTime = GameLib.GetGameTime()
	
	for idx, wndChatWindow in pairs(self.tChatWindows) do
		wndChatWindow:SetStyle("AutoFadeNC", self.bEnableNCFade)
		if self.bEnableNCFade then
			wndChatWindow:SetNCOpacity(1)
		end

		wndChatWindow:SetStyle("AutoFadeBG", self.bEnableBGFade)
		if self.bEnableBGFade then
			wndChatWindow:SetBGOpacity(1)
		end
	end
end

function ChatLog:OnBGDrawSlider(wndHandler, wndControl)
	self.nBGOpacity = self.wndChatOptions:FindChild("BGOpacity:BGOpacitySlider"):GetValue()

	for idx, wndChatWindow in pairs(self.tChatWindows) do
		wndChatWindow:FindChild("BGArt"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
		wndChatWindow:FindChild("BGArt_SidePanel"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
		wndChatWindow:FindChild("BGArt_ResizeHandle"):SetBGColor(CColor.new(1.0, 1.0, 1.0, self.nBGOpacity))
	end
end

function ChatLog:OnTogglePlayerChatBubbles(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	self.bEnablePlayerBubbles = wndHandler:GetData()
	Apollo.SetConsoleVariable("unit.playerTextBubbleEnabled", self.bEnablePlayerBubbles)
end


function ChatLog:OnToggleNPCChatBubbles(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	self.bEnableNPCBubbles = wndHandler:GetData()
	Apollo.SetConsoleVariable("unit.npcTextBubbleEnabled", self.bEnableNPCBubbles)
end

function ChatLog:OnSaveToLog(wndHandler, wndControl)
	if wndHandler == wndControl then
		local bValue = wndHandler:GetName() == "SaveToLogOn"
		Apollo.SetConsoleVariable("chat.saveLog", bValue)
		self.wndChatOptions:FindChild("SaveToLogOn"):SetCheck(bValue)
		self.wndChatOptions:FindChild("SaveToLogOff"):SetCheck(not bValue)
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function ChatLog:HelperGenerateChatMessage(tQueuedMessage)
	if tQueuedMessage.xml then
		return
	end

	local eChannelType = tQueuedMessage.eChannelType
	local tMessage = tQueuedMessage.tMessage

	-- Different handling for combat log
	if eChannelType == ChatSystemLib.ChatChannel_Combat then
		-- no formats in combat, roll it all up into one.
		local strMessage = ""
		for idx, tSegment in ipairs(tMessage.arMessageSegments) do
			strMessage = strMessage .. tSegment.strText
		end
		tQueuedMessage.strMessage = strMessage
		return
	end

	local xml = XmlDoc.new()

	local crText = self.arChatColor[eChannelType] or ApolloColor.new("white")
	local crChannel = ApolloColor.new(karChannelTypeToColor[eChannelType].Channel or "white")
	local crPlayerName = ApolloColor.new("ChatPlayerName")

	local strTime = ""
	if self.bShowTimestamp then
		strTime = self:HelperGetTimeStr()
	end

	local strWhisperName = tMessage.strSender
	if tMessage.strRealmName:len() > 0 and eChannelType ~= ChatSystemLib.ChatChannel_AccountWhisper then
		-- Name/Realm formatting needs to be very specific for cross realm chat to work
		strWhisperName = strWhisperName .. "@" .. tMessage.strRealmName
	end
	local strDisplayName = strWhisperName

	--strWhisperName must only be sender@realm, or friends equivelent name.

	local strPresenceState = ""
	if tMessage.bAutoResponse then
		strPresenceState = '('..Apollo.GetString("AutoResponse_Prefix")..')'
	end

	if tMessage.nPresenceState == FriendshipLib.AccountPresenceState_Away then
		strPresenceState = '<'..Apollo.GetString("Command_Friendship_AwayFromKeyboard")..'>'
	elseif tMessage.nPresenceState == FriendshipLib.AccountPresenceState_Busy then
		strPresenceState = '<'..Apollo.GetString("Command_Friendship_DoNotDisturb")..'>'
	end

	if eChannelType == ChatSystemLib.ChatChannel_Whisper then
		if not tMessage.bSelf then
			self.tLastWhisperer = { strCharacterName = strWhisperName, eChannelType = ChatSystemLib.ChatChannel_Whisper }--record the last incoming whisperer for quick response
		end
		Sound.Play(Sound.PlayUISocialWhisper)
		self:InsertIntoRecent(strWhisperName, false)
	elseif eChannelType == ChatSystemLib.ChatChannel_AccountWhisper then

		local tPreviousWhisperer = self.tLastWhisperer

		self.tLastWhisperer =
		{
			strCharacterName = tMessage.strSender,
			strRealmName = nil,
			strDisplayName = nil,
			eChannelType = ChatSystemLib.ChatChannel_AccountWhisper
		}

		local tAccountFriends = FriendshipLib.GetAccountList()
		for idx, tAccountFriend in pairs(tAccountFriends) do
			if tAccountFriend.arCharacters ~= nil then
				for idx, tCharacter in pairs(tAccountFriend.arCharacters) do
					if tCharacter.strCharacterName == tMessage.strSender and (tMessage.strRealmName:len() == 0 or tCharacter.strRealm == tMessage.strRealmName) then
						if not tMessage.bSelf or (tPreviousWhisperer and tPreviousWhisperer.strCharacterName == tMessage.strSender) then
							self.tLastWhisperer.strDisplayName = tAccountFriend.strCharacterName
							self.tLastWhisperer.strRealmName = tCharacter.strRealm
						end
						strDisplayName = tAccountFriend.strCharacterName
					end
				end
			end
		end
		Sound.Play(Sound.PlayUISocialWhisper)
		self:InsertIntoRecent(strDisplayName, true)
	end

	-- We build strings backwards, right to left
	if eChannelType == ChatSystemLib.ChatChannel_AnimatedEmote then -- emote animated channel gets special formatting
		xml:AddLine(strTime, crChannel, self.strFontOption, "Left")

	elseif eChannelType == ChatSystemLib.ChatChannel_Emote then -- emote channel gets special formatting
		xml:AddLine(strTime, crChannel, self.strFontOption, "Left")
		if strDisplayName:len() > 0 then
			if tMessage.bGM then
				xml:AppendImage(kstrGMIcon, 16, 16)
			end
			local strCross = tMessage.bCrossFaction and "true" or "false"--has to be a string or a number due to code restriction
			xml:AppendText(strDisplayName, crPlayerName, self.strFontOption, {strCharacterName = strWhisperName, nReportId = tMessage.nReportId, strCrossFaction = strCross}, "Source")
		end
		xml:AppendText(" ")
	else
		local strChannel
		if eChannelType == ChatSystemLib.ChatChannel_Society then
			strChannel = (string.format("%s ", String_GetWeaselString(Apollo.GetString("ChatLog_GuildCommand"), tQueuedMessage.strChannelName, tQueuedMessage.strChannelCommand))) --String DB removed empty characters at the end of string, so have to hardcode it here.
		else
			strChannel = String_GetWeaselString(Apollo.GetString("CRB_Brackets_Space"), tQueuedMessage.strChannelName)
		end

		if self.bShowChannel ~= true then
			strChannel = ""
		end

		xml:AddLine(strTime .. strChannel, crChannel, self.strFontOption, "Left")
		if strDisplayName:len() > 0 then

			local strWhisperNamePrefix = ""
			if eChannelType == ChatSystemLib.ChatChannel_Whisper or eChannelType == ChatSystemLib.ChatChannel_AccountWhisper then
				if tMessage.bSelf then
					strWhisperNamePrefix = Apollo.GetString("ChatLog_To")
				else
					strWhisperNamePrefix = Apollo.GetString("ChatLog_From")
				end
			end

			xml:AppendText( strWhisperNamePrefix, crText, self.strFontOption)

			if tMessage.bGM then
				xml:AppendImage(kstrGMIcon, 16, 16)
			end

			local strCross = tMessage.bCrossFaction and "true" or "false"--has to be a string or a number due to code restriction
			xml:AppendText( strDisplayName, crPlayerName, self.strFontOption, {strCharacterName = strWhisperName, nReportId = tMessage.nReportId , strCrossFaction = strCross}, "Source")
		end
		xml:AppendText( strPresenceState .. Apollo.GetString("Chat_ColonBreak"), crChannel, self.strFontOption, "Left")
	end

	local xmlBubble = nil
	if tMessage.bShowChatBubble then
		xmlBubble = XmlDoc.new() -- This is the speech bubble form
		xmlBubble:AddLine("", crChannel, self.strFontOption, "Center")
	end

	local bHasVisibleText = false
	for idx, tSegment in ipairs( tMessage.arMessageSegments ) do
		local strText = tSegment.strText
		local bAlien = tSegment.bAlien or tMessage.bCrossFaction
		local bShow = false

		if self.eRoleplayOption == 3 then
			bShow = not tSegment.bRolePlay
		elseif self.eRoleplayOption == 2 then
			bShow = tSegment.bRolePlay
		else
			bShow = true;
		end

		if bShow then
			local crChatText = crText;
			local crBubbleText = kstrColorChatRegular
			local strChatFont = self.strFontOption
			local strBubbleFont = kstrBubbleFont
			local tLink = {}


			if tSegment.uItem ~= nil then -- item link
				-- replace me with correct colors
				strText = String_GetWeaselString(Apollo.GetString("CRB_Brackets"), tSegment.uItem:GetName())
				crChatText = karEvalColors[tSegment.uItem:GetItemQuality()]
				crBubbleText = ApolloColor.new("white")

				tLink.strText = strText
				tLink.uItem = tSegment.uItem

			elseif tSegment.uQuest ~= nil then -- quest link
				-- replace me with correct colors
				strText = String_GetWeaselString(Apollo.GetString("CRB_Brackets"), tSegment.uQuest:GetTitle())
				crChatText = ApolloColor.new("green")
				crBubbleText = ApolloColor.new("green")

				tLink.strText = strText
				tLink.uQuest = tSegment.uQuest

			elseif tSegment.uArchiveArticle ~= nil then -- archive article
				-- replace me with correct colors
				strText = String_GetWeaselString(Apollo.GetString("CRB_Brackets"), tSegment.uArchiveArticle:GetTitle())
				crChatText = ApolloColor.new("ffb7a767")
				crBubbleText = ApolloColor.new("ffb7a767")

				tLink.strText = strText
				tLink.uArchiveArticle = tSegment.uArchiveArticle

			else
				if tSegment.bRolePlay then
					crBubbleText = kstrColorChatRoleplay
					strChatFont = self.strRPFontOption
					strBubbleFont = kstrDialogFontRP
				end

				if bAlien or tSegment.bProfanity then -- Weak filter. Note only profanity is scrambled.
					strChatFont = self.strAlienFontOption
					strBubbleFont = self.strAlienFontOption
				end
			end

			if next(tLink) == nil then
				if eChannelType == ChatSystemLib.ChatChannel_AnimatedEmote then
					local strCross = tMessage.bCrossFaction and "true" or "false"--has to be a string or a number due to code restriction
					xml:AppendText(strText, crChatText, strChatFont, {strCharacterName = strWhisperName, nReportId = tMessage.nReportId, strCrossFaction = strCross}, "Source")
				else
					xml:AppendText(strText, crChatText, strChatFont)
				end
			else
				local strLinkIndex = tostring( self:HelperSaveLink(tLink) )
				-- append text can only save strings as attributes.
				xml:AppendText(strText, crChatText, strChatFont, {strIndex=strLinkIndex} , "Link")
			end

			if xmlBubble then
				xmlBubble:AppendText(strText, crBubbleText, strBubbleFont) -- Format for bubble; regular
			end

			bHasVisibleText = bHasVisibleText or self:HelperCheckForEmptyString(strText)
		end
	end

	tQueuedMessage.bHasVisibleText = bHasVisibleText
	tQueuedMessage.xml = xml
	tQueuedMessage.xmlBubble = xmlBubble
end

function ChatLog:HelperGetTimeStr()
	--Toggle Visibility based on ui preference
	local nVisibility = Apollo.GetConsoleVariable("hud.TimeDisplay")

	local tTime = GameLib.GetLocalTime()
	strTime = (string.format("%02d:%02d", tostring(tTime.nHour), tostring(tTime.nMinute)))

	if nVisibility == 2 then --Local 12hr am/pm
		local nHour = tTime.nHour > 12 and tTime.nHour - 12 or tTime.nHour == 0 and 12 or tTime.nHour

		strTime = (string.format("%02d:%02d", tostring(nHour), tostring(tTime.nMinute)))
	elseif nVisibility == 3 then --Server 24hr
		tTime = GameLib.GetServerTime()

		strTime = (string.format("%02d:%02d", tostring(tTime.nHour), tostring(tTime.nMinute)))
	elseif nVisibility == 4 then --Server 12hr am/pm
		tTime = GameLib.GetServerTime()
		local nHour = tTime.nHour > 12 and tTime.nHour - 12 or tTime.nHour == 0 and 12 or tTime.nHour

		strTime = (string.format("%02d:%02d", tostring(nHour), tostring(tTime.nMinute)))
	end

	strTime = strTime.." "
	return strTime
end
function ChatLog:HelperSaveLink(tLink)
	self.tLinks[self.nNextLinkIndex] = tLink
	self.nNextLinkIndex = self.nNextLinkIndex + 1
	return self.nNextLinkIndex - 1
end

function ChatLog:HelperAppendLink( wndEdit, tLink )
	local tSelectedText = wndEdit:GetSel()

	wndEdit:AddLink( tSelectedText.cpCaret, tLink.strText, tLink )
	self:OnInputChanged(nil, wndEdit, wndEdit:GetText())
	wndEdit:SetFocus()
end

function ChatLog:HelperReplaceLinks(strText, arEditLinks)
	local strReplacedText = ""

	local nCurrentIdx = 1
	local nLastIdx = strText:len()
	while nCurrentIdx <= nLastIdx do
		local nNextIdx = nCurrentIdx + 1

		local bFound = false

		for nEditIdx, tEditLink in pairs( arEditLinks ) do
			if tEditLink.iMin <= nCurrentIdx and nCurrentIdx < tEditLink.iLim then

				if tEditLink.data.uItem then
					strReplacedText = strReplacedText .. tEditLink.data.uItem:GetChatLinkString()
				elseif tEditLink.data.uQuest then
					strReplacedText = strReplacedText .. tEditLink.data.uQuest:GetChatLinkString()
				elseif tEditLink.data.uArchiveArticle then
					strReplacedText = strReplacedText .. tEditLink.data.uArchiveArticle:GetChatLinkString()
				end

				if nNextIdx < tEditLink.iLim then
					nNextIdx = tEditLink.iLim
				end

				bFound = true
				break
			end
		end

		if bFound == false then
			strReplacedText = strReplacedText .. strText:sub(nCurrentIdx, nCurrentIdx)
		end

		nCurrentIdx = nNextIdx
	end

	return strReplacedText
end

function ChatLog:HelperAddChannelToAll(channelAdded)
	if self.tAllViewedChannels[channelAdded] ~= nil then
		self.tAllViewedChannels[channelAdded] = self.tAllViewedChannels[channelAdded] + 1
	else
		self.tAllViewedChannels[channelAdded] = 1
	end
end

function ChatLog:HelperRemoveChannelFromAll(channelRemoved)
	if self.tAllViewedChannels[channelRemoved] ~= nil then
		self.tAllViewedChannels[channelRemoved] = self.tAllViewedChannels[channelRemoved] - 1

		if self.tAllViewedChannels[channelRemoved] <= 0 then
			self.tAllViewedChannels[channelRemoved] = nil
			self:HelperRemoveChannelFromInputWindow(channelRemoved)
		end
	end
end

function ChatLog:HelperRemoveChannelFromInputWindow(channelRemoved) -- used when we've totally removed a channel
	for idx, wnd in pairs(self.tChatWindows) do
		local tChatData = wnd:GetData()

		if tChatData.channelCurrent:GetUniqueId() == channelRemoved then

			local channelNew = self:HelperFindAViewedChannel()
			local wndInput = wnd:FindChild("Input")

			if channelNew ~= nil then
				tChatData.channelCurrent = channelNew
				wndInput:SetPrompt(tChatData.channelCurrent:GetCommand())
				tChatData.crText = self.arChatColor[tChatData.channelCurrent:GetType()]
				wndInput:SetPromptColor(tChatData.crText)

				--TODO: Helper this since we do it other places
				local strText = wndInput:GetText()
				local strCommand = tChatData.channelCurrent:GetAbbreviation()

				if strCommand == "" or strCommand == nil then
					strCommand = tChatData.channelCurrent:GetCommand()
				end

				if strText == "" then
					strText =String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), strCommand.." ")
				else
					local tInput = ChatSystemLib.SplitInput(strText) -- get the existing message, ignore the old command
					strText = String_GetWeaselString(Apollo.GetString("ChatLog_MessageToPlayer"), strCommand).." "..tInput.strMessage
				end

				wndInput:SetText(strText)
				local crText = self.arChatColor[tChatData.channelCurrent:GetType()] or ApolloColor.new("white")
				wndInput:SetTextColor(crText)
				wndInput:SetFocus()
				wndInput:SetSel(strText:len(), -1)

			else
				wndInput:SetPrompt("X")
				wndInput:SetPromptColor(kcrInvalidColor)
			end
		end
	end
end

function ChatLog:HelperFindAViewedChannel()
	local channelNew = nil
	local nNewChannelIdx = nil
	local tBaseChannels = ChatSystemLib.GetChannels()
	local tChannelsWithInput = {}

	for idx, channelCurrent in pairs(tBaseChannels) do
		if channelCurrent:GetCommand() ~= nil and channelCurrent:GetCommand() ~= "" then
			tChannelsWithInput[channelCurrent:GetType()] = true
		end
	end

	for idx, channelCurrent in pairs(self.tAllViewedChannels) do
		if self.tAllViewedChannels[idx] ~= nil and tChannelsWithInput[idx] ~= nil then
			nNewChannelIdx = idx
			break
		end
	end

	if nNewChannelIdx == nil then
		nNewChannelIdx = ChatSystemLib.ChatChannel_Say
	end

	for idx, channelCurrent in ipairs(tBaseChannels) do
		if channelCurrent:GetType() == nNewChannelIdx then
			channelNew = channelCurrent
			break
		end
	end

	return channelNew
end

function ChatLog:HelperGetCurrentEditbox()
	local wndEdit
	-- find the last used chat window
	for idx, wndCurrent in pairs(self.tChatWindows) do
		local tData = wndCurrent:GetData()
		if tData and not tData.bCombatLog and wndCurrent:FindChild("Input"):GetData() then
			wndEdit = wndCurrent:FindChild("Input")
			break
		end
	end

	-- if none found, use the first on our list
	if wndEdit == nil then
		for idx, wndCurrent in pairs(self.tChatWindows) do
			local tData = wndCurrent:GetData()
			if tData and not tData.bCombatLog then
				wndEdit = wndCurrent:FindChild("Input")
				break
			end
		end
	end

	return wndEdit
end

-----------------------------------------------------------------------------------------------
-- Other Add-ons
-----------------------------------------------------------------------------------------------

function ChatLog:OnTradeSkillSigilResult(eResult)
	local tEnumTable = CraftingLib.CodeEnumTradeskillResult
	local kstrTradeskillResultTable =
	{
		[tEnumTable.Success] 					= Apollo.GetString("EngravingStation_Success"),
		[tEnumTable.InsufficentFund] 			= Apollo.GetString("EngravingStation_NeedMoreMoney"),
		[tEnumTable.InvalidItem] 				= Apollo.GetString("EngravingStation_InvalidItem"),
		[tEnumTable.InvalidSlot]			 	= Apollo.GetString("EngravingStation_InvalidSlot"),
		[tEnumTable.MissingEngravingStation] 	= Apollo.GetString("EngravingStation_StationTooFar"),
		[tEnumTable.Unlocked] 					= Apollo.GetString("EngravingStation_UnlockSuccessfull"),
		[tEnumTable.UnknownError] 				= Apollo.GetString("EngravingStation_Failure"),
		[tEnumTable.RuneExists] 				= Apollo.GetString("EngravingStation_ExistingRune"),
		[tEnumTable.MissingRune] 				= Apollo.GetString("EngravingStation_RuneMissing"),
		[tEnumTable.DuplicateRune]				= Apollo.GetString("EngravingStation_DuplicateRune"),
		[tEnumTable.AttemptFailed] 				= Apollo.GetString("EngravingStation_Failure"),
		[tEnumTable.RuneSlotLimit] 				= Apollo.GetString("EngravingStation_SlotLimitReached"),
	}

	Event_FireGenericEvent("GenericEvent_LootChannelMessage", kstrTradeskillResultTable[eResult])
end

local ChatLogInstance = ChatLog:new()
ChatLogInstance:Init()


int="0" TAnchorOffset="16" RAnchorPoint="1" RAnchorOffset="-13" BAnchorPoint="0" BAnchorOffset="35" RelativeToClient="1" Font="CRB_Header10" Text="Rank X (Max)" Template="Default" TooltipType="OnCursor" Name="AttributeRank" BGColor="white" TextColor="UI_TextHoloBodyCyan" TooltipColor="" TextId="" DT_VCENTER="0" DT_BOTTOM="0" NewControlDepth="3" DT_RIGHT="1" DT_CENTER="0" DT_WORDBREAK="1"/>
        <Control Class="Window" LAnchorPoint="1" LAnchorOffset="-41" TAnchorPoint="0" TAnchorOffset="35" RAnchorPoint="1" RAnchorOffset="-1" BAnchorPoint="0" BAnchorOffset="56" RelativeToClient="1" Font="CRB_Header9" Text="777" Template="Default" TooltipType="OnCursor" Name="MaxPoints" BGColor="white" TextColor="UI_TextHoloBody" TooltipColor="" TextId="" DT_VCENTER="1" DT_RIGHT="0" DT_CENTER="0" DT_BOTTOM="0" NewControlDepth="3" Tooltip=""/>
        <Control Class="ProgressBar" Text="" LAnchorPoint="0" LAnchorOffset="71" TAnchorPoint="0" TAnchorOffset="31" RAnchorPoint="0" RAnchorOffset="298" BAnchorPoint="0" BAnchorOffset="62" AutoSetText="0" UseValues="0" RelativeToClient="1" SetTextToProgress="1" DT_CENTER="1" DT_VCENTER="1" ProgressEmpty="" ProgressFull="CRB_Basekit:kitIProgBar_Holo_Fill" TooltipType="OnCursor" 