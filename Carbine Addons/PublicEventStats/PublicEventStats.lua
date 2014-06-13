-----------------------------------------------------------------------------------------------
-- Client Lua Script for PublicEventStats
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "PublicEvent"
require "MatchingGame"

local PublicEventStats = {}

function PublicEventStats:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PublicEventStats:Init()
    Apollo.RegisterAddon(self)
end

local knMaxWndMainWidth = 800


local ktParticipantKeys = -- Can swap to event type id's, but this just saves space
{
	["Arena"] =
	{
		"strName",
		"nKills",
		"nDeaths",
		"nAssists",
		"nDamage",
		"nHealed",
		"nDamageReceived",
		"nHealingReceived",
		"nSaves"
	},

	["WarPlot"] =
	{
		"strName",
		"nKills",
		"nDeaths",
		"nAssists",
		"nDamage",
		"nHealed",
		"nDamageReceived",
		"nHealingReceived",
		"nSaves",
		"nKillStreak"
	},

	["HoldTheLine"] =
	{
		"strName",
		"nKills",
		"nDeaths",
		"nAssists",
		"nCustomNodesCaptured",
		"nDamage",
		"nHealed",
		"nDamageReceived",
		"nHealingReceived",
		"nSaves",
		"nKillStreak"
	},
	["CTF"] =
	{
		"strName",
		"nKills",
		"nDeaths",
		"nAssists",
		"nCustomFlagsPlaced",
		"bCustomFlagsStolen",
		"nDamage",
		"nHealed",
		"nDamageReceived",
		"nHealingReceived",
		"nSaves",
		"nKillStreak"
	},
	["Sabotage"] =
	{
		"strName",
		"nKills",
		"nDeaths",
		"nAssists",
		"nDamage",
		"nHealed",
		"nDamageReceived",
		"nHealingReceived",
		"nSaves",
		"nKillStreak"
	}
}

local kstrClassToMLIcon =
{
	[GameLib.CodeEnumClass.Warrior] 		= "<T Image=\"CRB_Raid:sprRaid_Icon_Class_Warrior\"></T> ",
	[GameLib.CodeEnumClass.Engineer] 		= "<T Image=\"CRB_Raid:sprRaid_Icon_Class_Engineer\"></T> ",
	[GameLib.CodeEnumClass.Esper] 			= "<T Image=\"CRB_Raid:sprRaid_Icon_Class_Esper\"></T> ",
	[GameLib.CodeEnumClass.Medic] 			= "<T Image=\"CRB_Raid:sprRaid_Icon_Class_Medic\"></T> ",
	[GameLib.CodeEnumClass.Stalker] 		= "<T Image=\"CRB_Raid:sprRaid_Icon_Class_Stalker\"></T> ",
	[GameLib.CodeEnumClass.Spellslinger] 	= "<T Image=\"CRB_Raid:sprRaid_Icon_Class_Spellslinger\"></T> ",
}

local ktPvPEvents =
{
	[PublicEvent.PublicEventType_PVP_Arena] 					= true,
	[PublicEvent.PublicEventType_PVP_Warplot] 					= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Vortex] 		= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Cannon] 		= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Sabotage]		= true,
	[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] 	= true,
}

local ktEventTypeToWindowName =
{
	[PublicEvent.PublicEventType_PVP_Arena] 					= "PvPArenaContainer",
	[PublicEvent.PublicEventType_PVP_Warplot] 					= "PvPWarPlotContainer",
	[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] 	= "PvPHoldContainer",
	[PublicEvent.PublicEventType_PVP_Battleground_Vortex] 		= "PvPCTFContainer",
	[PublicEvent.PublicEventType_PVP_Battleground_Sabotage] 	= "PvPSaboContainer",
	[PublicEvent.PublicEventType_WorldEvent] 					= "PublicEventGrid", -- TODO
	[PublicEvent.PublicEventType_Dungeon] 						= "PublicEventGrid", -- TODO
}

-- necessary until we can either get column names for a compare/swap or a way to set localized strings in XML for columns
local ktEventTypeToColumnNameList =
{
	[PublicEvent.PublicEventType_PVP_Arena] =
	{
		"PublicEventStats_Name",
		"PublicEventStats_Kills",
		"PublicEventStats_Deaths",
		"PublicEventStats_Assists",
		"PublicEventStats_DamageDone",
		"PublicEventStats_HealingDone",
		"PublicEventStats_DamageTaken",
		"PublicEventStats_HealingTaken",
		"PublicEventStats_Saves"
	},
	[PublicEvent.PublicEventType_PVP_Warplot] =
	{
		"PublicEventStats_Name",
		"PublicEventStats_Kills",
		"PublicEventStats_Deaths",
		"PublicEventStats_Assists",
		"PublicEventStats_DamageDone",
		"PublicEventStats_HealingDone",
		"PublicEventStats_DamageTaken",
		"PublicEventStats_HealingTaken",
		"PublicEventStats_Saves",
		"PublicEventStats_KillStreak"
	},
	[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] =
	{
		"PublicEventStats_Name",
		"PublicEventStats_Kills",
		"PublicEventStats_Deaths",
		"PublicEventStats_Assists",
		"PublicEventStats_Captures",
		"PublicEventStats_DamageDone",
		"PublicEventStats_HealingDone",
		"PublicEventStats_DamageTaken",
		"PublicEventStats_HealingTaken",
		"PublicEventStats_Saves",
		"PublicEventStats_KillStreak"
	},
	[PublicEvent.PublicEventType_PVP_Battleground_Vortex] =
	{
		"PublicEventStats_Name",
		"PublicEventStats_Kills",
		"PublicEventStats_Deaths",
		"PublicEventStats_Assists",
		"PublicEventStats_Captures",
		"PublicEventStats_Stolen",
		"PublicEventStats_DamageDone",
		"PublicEventStats_HealingDone",
		"PublicEventStats_DamageTaken",
		"PublicEventStats_HealingTaken",
		"PublicEventStats_Saves",
		"PublicEventStats_KillStreak"
	},
	[PublicEvent.PublicEventType_PVP_Battleground_Sabotage] =
	{
		"PublicEventStats_Name",
		"PublicEventStats_Kills",
		"PublicEventStats_Deaths",
		"PublicEventStats_Assists",
		"PublicEventStats_DamageDone",
		"PublicEventStats_HealingDone",
		"PublicEventStats_DamageTaken",
		"PublicEventStats_HealingTaken",
		"PublicEventStats_Saves",
		"PublicEventStats_KillStreak"
	},
	[PublicEvent.PublicEventType_WorldEvent] =
	{
		"PublicEventStats_Name",
		"PublicEventStats_Contribution",
		"PublicEventStats_DamageDone",
		"PublicEventStats_DamageTaken",
		"PublicEventStats_HealingDone",
		"PublicEventStats_HealingTaken"
	},
	[PublicEvent.PublicEventType_Dungeon] =
	{
		"PublicEventStats_Name",
		"PublicEventStats_Contribution",
		"PublicEventStats_DamageDone",
		"PublicEventStats_DamageTaken",
		"PublicEventStats_HealingDone",
		"PublicEventStats_HealingTaken"
	},
}

local ktAdventureListStrIndexToIconSprite =  -- Default: ClientSprites:Icon_SkillMind_UI_espr_moverb
{
	["nKills"] 		= "IconSprites:Icon_BuffDebuff_Assault_Power_Buff",
	["nDeaths"] 	= "IconSprites:Icon_BuffWarplots_deployable",
	["nDamage"] 	= "IconSprites:Icon_BuffWarplots_strikethrough",
	["nHealed"] 	= "IconSprites:Icon_BuffDebuff_Support_Power_Buff",
}

local ktRewardTierInfo =
{
	[PublicEvent.PublicEventRewardTier_None] 	= {Apollo.GetString("PublicEventStats_NoMedal"), 		""},
	[PublicEvent.PublicEventRewardTier_Bronze] 	= {Apollo.GetString("PublicEventStats_BronzeMedal"), 	"CRB_CurrencySprites:sprCashCopper"},
	[PublicEvent.PublicEventRewardTier_Silver] 	= {Apollo.GetString("PublicEventStats_SilverMedal"), 	"CRB_CurrencySprites:sprCashSilver"},
	[PublicEvent.PublicEventRewardTier_Gold] 	= {Apollo.GetString("PublicEventStats_GoldMedal"), 		"CRB_CurrencySprites:sprCashGold"},
}

function PublicEventStats:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PublicEventStats.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PublicEventStats:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

    Apollo.RegisterEventHandler("GenericEvent_OpenEventStats", 			"OnToggleEventStats", self)
    Apollo.RegisterEventHandler("GenericEvent_OpenEventStatsZombie", 	"InitializeZombie", self)
	Apollo.RegisterEventHandler("ResolutionChanged", 					"OnResolutionChanged", self)
	Apollo.RegisterEventHandler("WarPartyMatchResults", 				"OnWarPartyMatchResults", self)
	Apollo.RegisterEventHandler("PVPMatchFinished", 					"OnPVPMatchFinished", self)
	Apollo.RegisterEventHandler("PublicEventStart",						"OnPublicEventStart", self)
	Apollo.RegisterEventHandler("PublicEventEnd", 						"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventLeave", 					"OnPublicEventLeave", self)
	Apollo.RegisterEventHandler("ChangeWorld", 							"OnClose", self)
	Apollo.RegisterEventHandler("GuildWarCoinsChanged",					"OnGuildWarCoinsChanged", self)

	Apollo.RegisterTimerHandler("UpdateTimer", 							"OnOneSecTimer", self)
	Apollo.CreateTimer("UpdateTimer", 1, true)
	Apollo.StopTimer("UpdateTimer")

	self.wndMain = nil
	self.wndAdventure = nil

	local tActiveEvents = PublicEvent.GetActiveEvents()
	for idx, peEvent in pairs(tActiveEvents) do
		self:OnPublicEventStart(peEvent)
	end
end

function PublicEventStats:OnToggleEventStats()
	if self.wndMain:IsShown() then
		self.wndMain:Close()
		Apollo.StopTimer("UpdateTimer")
	else
		self.wndMain:GetData().peEvent:RequestScoreboard(true)
		self.wndMain:Invoke()
		self:OnOneSecTimer()
		Apollo.StartTimer("UpdateTimer")
	end
end

function PublicEventStats:OnPublicEventStart(peEvent)
	local eType = peEvent:GetEventType()
	if peEvent:HasLiveStats() then
		local tLiveStats = peEvent:GetLiveStats()
		self:Initialize(peEvent, peEvent:GetMyStats(), tLiveStats.arTeamStats, tLiveStats.arParticipantStats)
	end
end

function PublicEventStats:Initialize(peEvent, tStatsSelf, tStatsTeam, tStatsParticipants, tZombieStats)
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc , "PublicEventStatsForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Tutorials_PublicEvents")})
	end

	local eEventType = peEvent:GetEventType()
	local wndParent = self.wndMain:FindChild(ktEventTypeToWindowName[eEventType])

	local wndGrid = wndParent

	if wndGrid:GetName() ~= "PublicEventGrid" then
		wndGrid = wndParent:FindChild("PvPTeamGridBot")

		for idx = 1, wndGrid:GetColumnCount() do
			wndGrid:SetColumnText(idx, Apollo.GetString(ktEventTypeToColumnNameList[eEventType][idx]))
		end

		wndGrid = wndParent:FindChild("PvPTeamGridTop")
	end

	local nMaxWndMainWidth = self.wndMain:GetWidth() - wndGrid:GetWidth() + 15 -- Magic number for the width of the scroll bar
	for idx = 1, wndGrid:GetColumnCount() do
		nMaxWndMainWidth = nMaxWndMainWidth + wndGrid:GetColumnWidth(idx)
		wndGrid:SetColumnText(idx, Apollo.GetString(ktEventTypeToColumnNameList[eEventType][idx]))
	end

	self.wndMain:SetSizingMinimum(500, 500)
	self.wndMain:SetSizingMaximum(nMaxWndMainWidth, 800)

	local tData =
	{
		peEvent = peEvent,
		tStatsSelf = tStatsSelf or {},
		tStatsTeam = tStatsTeam or {},
		tStatsParticipants = tStatsParticipants or {}
	}

	self.wndMain:SetData(tData)
	self.wndMain:Show(false)
	self.tZombieStats = tZombieStats -- note: this will be nil be default
	peEvent:RequestScoreboard(true)

	self:OnOneSecTimer()
end

function PublicEventStats:InitializeZombie(tZombieEvent)
	self:Initialize(tZombieEvent.peEvent, tZombieEvent.tStats, tZombieEvent.tStats.arTeamStats, tZombieEvent.tStats.arParticipantStats, tZombieEvent.tStats)
	self.wndMain:Invoke()
	Apollo.StartTimer("UpdateTimer")
end

function PublicEventStats:OnResolutionChanged()
	self.bResolutionChanged = true -- Delay so we can get the new value
end

function PublicEventStats:OnPublicEventLeave(peEnding, eReason)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("Header:BGPvPWinnerTopBar"):Show(false)
		Apollo.StopTimer("UpdateTimer")
	end
end

function PublicEventStats:OnPublicEventEnd(peEnding, eReason, tStats)
	Apollo.StopTimer("UpdateTimer")

	local eEventType = peEnding:GetEventType()

	if not self.nEventCount then
		self.nEventCount = 1
	else
		self.nEventCount = self.nEventCount + 1
	end

	local tViewableData = {nEventCount = nEventCount, eEventType = eEventType, tStats = tStats}

	if ktPvPEvents[eEventType] then
		self:Initialize(peEnding, tStats.arPersonalStats, tStats.arTeamStats, tStats.arParticipantStats, tStats)
		self.wndMain:Invoke()
	elseif eEventType == PublicEvent.PublicEventType_SubEvent or eEventType == PublicEvent.PublicEventType_WorldEvent then
		-- TODO; currently handled from Quest Tracker toggle
	else -- Adventures
		self:OnClose()
		self.tZombieStats = tStats -- Needs to be before BuildAdventuresSummary
		self:BuildAdventuresSummary(self:HelperBuildCombinedList(tStats.arPersonalStats, tStats.arTeamStats, tStats.arParticipantStats), peEnding)
	end
end

-----------------------------------------------------------------------------------------------
-- Main Draw Method
-----------------------------------------------------------------------------------------------

function PublicEventStats:OnOneSecTimer()
	if not self.wndMain or not self.wndMain:IsValid() then
		Apollo.StopTimer("UpdateTimer")
		return
	end

	local peCurrent = self.wndMain:GetData().peEvent
	local eEventType = peCurrent:GetEventType()
	local tLiveStats = nil

	if not self.tZombieStats then
		tLiveStats = peCurrent:GetLiveStats()
	end

	if tLiveStats and peCurrent:IsActive() then
		local tData =
		{
			peEvent = peCurrent,
			tStatsSelf = peCurrent:GetMyStats(),
			tStatsTeam = tLiveStats.arTeamStats,
			tStatsParticipants = tLiveStats.arParticipantStats
		}
		self.wndMain:SetData(tData)
		self:Redraw()
	elseif ktPvPEvents[eEventType] or eEventType == PublicEvent.PublicEventType_WorldEvent then
		if self.wndMain:GetData() then
			self:Redraw()
		end
	end

	if self.bResolutionChanged then
		self.bResolutionChanged = false
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		if Apollo.GetDisplaySize().nWidth <= 1400 then
			self.wndMain:SetAnchorOffsets(nLeft, nTop, nLeft + 650, nBottom)
		else
			self.wndMain:SetAnchorOffsets(nLeft, nTop, nLeft + 800, nBottom)
		end
	end
end

function PublicEventStats:Redraw() -- self.wndMain guaranteed valid and visible
	local tData = self.wndMain:GetData()
	local peCurrent = tData.peEvent
	local tStatsSelf = tData.tStatsSelf
	local tStatsTeam = tData.tStatsTeam
	local tStatsParticipants = tData.tStatsParticipants
	local tMegaList = self:HelperBuildCombinedList(tStatsSelf, tStatsTeam, tStatsParticipants)

	for key, wndCurr in pairs(self.wndMain:FindChild("MainGridContainer"):GetChildren()) do
		wndCurr:Show(false)
	end

	local eEventType = peCurrent:GetEventType()
	local wndGrid = self.wndMain:FindChild(ktEventTypeToWindowName[eEventType])

	if eEventType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine then
		self:HelperBuildPvPSharedGrids(wndGrid, tMegaList, "HoldTheLine")
	elseif eEventType == PublicEvent.PublicEventType_PVP_Battleground_Vortex then
		self:HelperBuildPvPSharedGrids(wndGrid, tMegaList, "CTF")
	elseif eEventType == PublicEvent.PublicEventType_PVP_Warplot then
		self:HelperBuildPvPSharedGrids(wndGrid, tMegaList, "WarPlot")
	elseif eEventType == PublicEvent.PublicEventType_PVP_Arena then
		self:HelperBuildPvPSharedGrids(wndGrid, tMegaList, "Arena")
	elseif eEventType == PublicEvent.PublicEventType_PVP_Battleground_Sabotage then
		self:HelperBuildPvPSharedGrids(wndGrid, tMegaList, "Sabotage")
	elseif eEventType == PublicEvent.PublicEventType_WorldEvent then
		self:BuildPublicEventGrid(wndGrid, tMegaList) -- TODO (polish)
	elseif eEventType == PublicEvent.PublicEventType_Dungeon then
		self:BuildPublicEventGrid(wndGrid, tMegaList) -- TODO
	end

	-- Title Text (including timer)
	local strTitleText = ""
	if peCurrent:IsActive() and peCurrent:GetElapsedTime() then
		strTitleText = String_GetWeaselString(Apollo.GetString("PublicEventStats_TimerHeader"), peCurrent:GetName(), self:HelperConvertTimeToString(peCurrent:GetElapsedTime()))
	elseif self.tZombieStats and self.tZombieStats.nElapsedTime then
		strTitleText = String_GetWeaselString(Apollo.GetString("PublicEventStats_FinishTime"), peCurrent:GetName(), self:HelperConvertTimeToString(self.tZombieStats.nElapsedTime))
	end
	self.wndMain:FindChild("EventTitleText"):SetText(strTitleText)

	-- Rewards (on zombie only)
	if not peCurrent:IsActive() and self.tZombieStats and self.tZombieStats.eRewardTier and
	peCurrent:GetEventType() == PublicEvent.PublicEventType_WorldEvent and self.tZombieStats.eRewardType ~= 0  then -- TODO: ENUM!!
		self.wndMain:FindChild("BGRewardTierFrame"):SetText(ktRewardTierInfo[self.tZombieStats.eRewardTier][1])
		self.wndMain:FindChild("BGRewardTierIcon"):SetSprite(ktRewardTierInfo[self.tZombieStats.eRewardTier][2])
	else
		self.wndMain:FindChild("BGRewardTierFrame"):SetText("")
	end

	if wndGrid then
		wndGrid:Show(true)
	end
end

-----------------------------------------------------------------------------------------------
-- Grid Building
-----------------------------------------------------------------------------------------------

function PublicEventStats:HelperBuildPvPSharedGrids(wndParent, tMegaList, eEventType)
	if not tMegaList or not tMegaList.tStatsTeam or not tMegaList.tStatsParticipant then
		return
	end

	local wndGridTop 	= wndParent:FindChild("PvPTeamGridTop")
	local wndGridBot 	= wndParent:FindChild("PvPTeamGridBot")
	local wndHeaderTop 	= wndParent:FindChild("PvPTeamHeaderTop")
	local wndHeaderBot 	= wndParent:FindChild("PvPTeamHeaderBot")

	local nVScrollPosTop 	= wndGridTop:GetVScrollPos()
	local nVScrollPosBot 	= wndGridBot:GetVScrollPos()
	local nSortedColumnTop 	= wndGridTop:GetSortColumn() or 1
	local nSortedColumnBot 	= wndGridBot:GetSortColumn() or 1
	local bAscendingTop 	= wndGridTop:IsSortAscending()
	local bAscendingBot 	= wndGridBot:IsSortAscending()

	local tMatchState 	= MatchingGame:GetPVPMatchState()
	local strMyTeamName = ""

	for key, tCurr in pairs(tMegaList.tStatsTeam) do
		local wndHeader = nil
		if not wndHeaderTop:GetData() or wndHeaderTop:GetData() == tCurr.strTeamName then
			wndHeader = wndHeaderTop
			wndGridTop:SetData(tCurr.strTeamName)
			wndHeaderTop:SetData(tCurr.strTeamName)
		elseif not wndHeaderBot:GetData() or wndHeaderBot:GetData() == tCurr.strTeamName then
			wndHeader = wndHeaderBot
			wndGridBot:SetData(tCurr.strTeamName)
			wndHeaderBot:SetData(tCurr.strTeamName)
		end

		local strHeaderText = wndHeader:FindChild("PvPHeaderText"):GetData() or ""
		local crTitleColor = ApolloColor.new("ff7fffb9")
		local strDamage	= String_GetWeaselString(Apollo.GetString("PublicEventStats_Damage"), self:HelperFormatNumber(tCurr.nDamage))
		local strHealed	= String_GetWeaselString(Apollo.GetString("PublicEventStats_Healing"), self:HelperFormatNumber(tCurr.nHealed))

		-- Setting up the team names / headers
		if eEventType == "CTF" or eEventType == "HoldTheLine" or eEventType == "Sabotage" then
			if tCurr.strTeamName == "Exiles" then
				crTitleColor = ApolloColor.new("ff31fcf6")
			elseif tCurr.strTeamName == "Dominion" then
				crTitleColor = ApolloColor.new("ffb80000")
			end
			local strKDA = String_GetWeaselString(Apollo.GetString("PublicEventStats_KDA"), tCurr.nKills, tCurr.nDeaths, tCurr.nAssists)

			strHeaderText = String_GetWeaselString(Apollo.GetString("PublicEventStats_PvPHeader"), strKDA, strDamage, strHealed)
		elseif eEventType == "Arena" then
			strHeaderText = String_GetWeaselString(Apollo.GetString("PublicEventStats_ArenaHeader"), strDamage, strHealed) -- TODO, Rating Change when support is added
			if tCurr.bIsMyTeam then
				strMyTeamName = tCurr.strTeamName
			end
		elseif eEventType == "Warplot" then
			strHeaderText = wndHeader:FindChild("PvPHeaderText"):GetData() or ""
		end

		wndHeader:FindChild("PvPHeaderText"):SetText(strHeaderText)
		wndHeader:FindChild("PvPHeaderTitle"):SetTextColor(crTitleColor)
		wndHeader:FindChild("PvPHeaderTitle"):SetText(tCurr.strTeamName)
	end

	for key, tParticipant in pairs(tMegaList.tStatsParticipant) do
		local wndGrid = wndGridBot
		if wndGridTop:GetData() == tParticipant.strTeamName then
			wndGrid = wndGridTop
		end

		-- Custom Stats
		if eEventType == "HoldTheLine" then
			for idx, tCustomTable in pairs(tParticipant.arCustomStats) do
				if tCustomTable.strName == Apollo.GetString("PublicEventStats_SecondaryPointCaptured") then
					tParticipant.nCustomNodesCaptured = tCustomTable.nValue or 0
				end
			end
		elseif eEventType == "CTF" then
			for idx, tCustomTable in pairs(tParticipant.arCustomStats) do
				if idx == 1 then
					tParticipant.nCustomFlagsPlaced = tCustomTable.nValue or 0
				else
					tParticipant.bCustomFlagsStolen = tCustomTable.nValue or 0
				end
			end
		end
	end

	for key, tParticipant in pairs(tMegaList.tStatsParticipant) do
		local wndGrid = wndGridBot
		if wndGridTop:GetData() == tParticipant.strTeamName then
			wndGrid = wndGridTop
		end

		-- Custom Stats
		if eEventType == "HoldTheLine" then
			for idx, tCustomTable in pairs(tParticipant.arCustomStats) do
				if tCustomTable.strName == Apollo.GetString("PublicEventStats_SecondaryPointCaptured") then
					tParticipant.nCustomNodesCaptured = tCustomTable.nValue or 0
				end
			end
		elseif eEventType == "CTF" then
			for idx, tCustomTable in pairs(tParticipant.arCustomStats) do
				if idx == 1 then
					tParticipant.nCustomFlagsPlaced = tCustomTable.nValue or 0
				else
					tParticipant.bCustomFlagsStolen = tCustomTable.nValue or 0
				end
			end
		end


		local wndCurrRow = self:HelperGridFactoryProduce(wndGrid, tParticipant.strName) -- GOTCHA: This is an integer
		wndGrid:SetCellLuaData(wndCurrRow, 1, tParticipant.strName)
		for idx, strParticipantKey in pairs(ktParticipantKeys[eEventType]) do
			local value = tParticipant[strParticipantKey]
			if type(value) == "number" then
				wndGrid:SetCellSortText(wndCurrRow, idx, string.format("%8d", value))
			else
				wndGrid:SetCellSortText(wndCurrRow, idx, value or 0)
			end

			local strClassIcon = idx == 1 and kstrClassToMLIcon[tParticipant.eClass] or ""

			wndGrid:SetCellDoc(wndCurrRow, idx, string.format("<T Font=\"CRB_InterfaceSmall\">%s%s</T>", strClassIcon, self:HelperFormatNumber(value)))
		end
	end

	wndGridTop:SetVScrollPos(nVScrollPosTop)
	wndGridBot:SetVScrollPos(nVScrollPosBot)
	wndGridTop:SetSortColumn(nSortedColumnTop, bAscendingTop)
	wndGridBot:SetSortColumn(nSortedColumnBot, bAscendingBot)
	self.wndMain:FindChild("PvPLeaveMatchBtn"):Show(self.tZombieStats)
	self.wndMain:FindChild("PvPSurrenderMatchBtn"):Show(not self.tZombieStats and eEventType == "WarPlot")
end

function PublicEventStats:BuildPublicEventGrid(wndGrid, tMegaList)
	local nVScrollPos = wndGrid:GetVScrollPos()
	local nSortedColumn = wndGrid:GetSortColumn() or 1
	local bAscending = wndGrid:IsSortAscending()
	 -- TODO remove this for better performance eventually
	 wndGrid:DeleteAll()

	for strKey, tCurrTable in pairs(tMegaList) do
		for key, tCurr in pairs(tCurrTable) do
			local wndCurrRow = self:HelperGridFactoryProduce(wndGrid, tCurr.strName) -- GOTCHA: This is an integer
			wndGrid:SetCellLuaData(wndCurrRow, 1, tCurr.strName)

			local tAttributes = {tCurr.strName, tCurr.nContributions, tCurr.nDamage, tCurr.nDamageReceived, tCurr.nHealed, tCurr.nHealingReceived}
			for idx, oValue in pairs(tAttributes) do
				if type(oValue) == "number" then
					wndGrid:SetCellSortText(wndCurrRow, idx, string.format("%8d", oValue))
				else
					wndGrid:SetCellSortText(wndCurrRow, idx, oValue)
				end
				wndGrid:SetCellDoc(wndCurrRow, idx, "<T Font=\"CRB_InterfaceSmall\">" .. self:HelperFormatNumber(oValue) .. "</T>")
			end
		end
	end

	wndGrid:SetVScrollPos(nVScrollPos)
	wndGrid:SetSortColumn(nSortedColumn, bAscending)
	self.wndMain:FindChild("PvPLeaveMatchBtn"):Show(false)
	self.wndMain:FindChild("PvPSurrenderMatchBtn"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Event Finished
-----------------------------------------------------------------------------------------------

function PublicEventStats:OnWarPartyMatchResults(tWarplotResults)
	if self.wndMain and self.wndMain:IsValid() then
		for idx, tTeamStats in pairs(tWarplotResults or {}) do
			local strStats = String_GetWeaselString(Apollo.GetString("PEStats_WarPartyTeamStats"), tTeamStats.nRating, tTeamStats.nDestroyedPlugs, tTeamStats.nRepairCost, tTeamStats.nWarCoinsEarned)
			self.wndMain:FindChild("PvPWarPlotContainer"):FindChild(idx == 1 and "PvPTeamHeaderTop" or "PvPTeamHeaderBot"):FindChild("PvPHeaderText"):SetData(strStats)
		end
		self.wndMain:FindChild("PvPSurrenderMatchBtn"):Show(false)
	end
end

function PublicEventStats:OnPVPMatchFinished(eWinner, eReason, nDeltaTeam1, nDeltaTeam2)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		return
	end

	local peMatch = self.wndMain:GetData().peEvent
	local eEventType = peMatch:GetEventType()
	if not ktPvPEvents[eEventType] or eEventType == PublicEvent.PublicEventType_PVP_Warplot then
		return
	end

	local strMessage = Apollo.GetString("PublicEventStats_MatchEnd")
	local strColor = ApolloColor.new("ff7fffb9")
	local tMatchState = MatchingGame:GetPVPMatchState()
	local eMyTeam = nil
	if tMatchState then
		eMyTeam = tMatchState.eMyTeam
	end

	if eEventType == PublicEvent.PublicEventType_PVP_Arena then
		if eMyTeam == eWinner then
			strMessage = Apollo.GetString("PublicEventStats_ArenaVictory")
		else
			strMessage = Apollo.GetString("PublicEventStats_ArenaDefeat")
		end
	else
		local bIsExile = GameLib.GetPlayerUnit():GetFaction() == 391 -- TODO SUPER HARDCODED, need enum
		if eWinner == MatchingGame.Winner.Draw then
			strColor = ApolloColor.new("ff9aaea3")
			strMessage = Apollo.GetString("PublicEventStats_Draw")
		elseif eMyTeam == eWinner and bIsExile then
			strColor = ApolloColor.new("ff31fcf6")
			strMessage = Apollo.GetString("PublicEventStats_ExileWins")
		elseif eMyTeam == eWinner and not bIsExile then
			strColor = ApolloColor.new("ffb80000")
			strMessage = Apollo.GetString("PublicEventStats_DominionWins")
		elseif eMyTeam ~= eWinner and bIsExile then
			strColor = ApolloColor.new("ffb80000")
			strMessage = Apollo.GetString("PublicEventStats_ExileLoses")
		elseif eMyTeam ~= eWinner and not bIsExile then
			strColor = ApolloColor.new("ff31fcf6")
			strMessage = Apollo.GetString("PublicEventStats_DominionLoses")
		end
	end

	if nDeltaTeam1 and nDeltaTeam2 then
		self.arRatingDelta =
		{
			nDeltaTeam1,
			nDeltaTeam2
		}
	end

	if tMatchState and eEventType == PublicEvent.PublicEventType_PVP_Arena and tMatchState.arTeams then
		local strMyArenaTeamName = ""
		local strOtherArenaTeamName = ""
		local strMyTeamName = ""
		local wndHeaderTop 	= self.wndMain:FindChild("MainGridContainer:PvPArenaContainer:PvPTeamHeaderTop")
		local wndHeaderBot 	= self.wndMain:FindChild("MainGridContainer:PvPArenaContainer:PvPTeamHeaderBot")
		for idx, tCurr in pairs(tMatchState.arTeams) do
			local strDelta = ""
			if self.arRatingDelta then
				if tCurr.nDelta < 0 then
					strDelta = String_GetWeaselString(Apollo.GetString("PublicEventStats_NegDelta"), math.abs(self.arRatingDelta[idx]))
				elseif tCurr.nDelta > 0 then
					strDelta = String_GetWeaselString(Apollo.GetString("PublicEventStats_PosDelta"), math.abs(self.arRatingDelta[idx]))
				end
			end

			if eMyTeam == tCurr.nTeam then
				strMyArenaTeamName = String_GetWeaselString(Apollo.GetString("PublicEventStats_RatingChange"), tCurr.strName, tCurr.nRating + self.arRatingDelta[idx], strDelta)
				strMySimpleTeamName = tCurr.strName
			else
				strOtherArenaTeamName = String_GetWeaselString(Apollo.GetString("PublicEventStats_RatingChange"), tCurr.strName, tCurr.nRating + self.arRatingDelta[idx], strDelta)
			end
		end

		if wndHeaderTop:GetData() == strMySimpleTeamName then
			wndHeaderTop:FindChild("PvPHeaderTitle"):SetText(strMyArenaTeamName)
			wndHeaderBot:FindChild("PvPHeaderTitle"):SetText(strOtherArenaTeamName)
		else
			wndHeaderTop:FindChild("PvPHeaderTitle"):SetText(strOtherArenaTeamName)
			wndHeaderBot:FindChild("PvPHeaderTitle"):SetText(strMyArenaTeamName)
		end
	end

	self.wndMain:FindChild("BGPvPWinnerTopBar"):Show(true) -- Hidden when wndMain is destroyed from OnClose
	self.wndMain:FindChild("BGPvPWinnerTopBarArtText"):SetText(strMessage)
	self.wndMain:FindChild("BGPvPWinnerTopBarArtText"):SetTextColor(strColor)
end

function PublicEventStats:OnGuildWarCoinsChanged(guildOwner, nAmountGained)
	if nAmountGained > 0 then
		local strResult = String_GetWeaselString(Apollo.GetString("PEStats_WarcoinsGained"), nAmountGained)
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult, "")
	end
end

-----------------------------------------------------------------------------------------------
-- Match Ending and Closing methods
-----------------------------------------------------------------------------------------------

function PublicEventStats:OnClose(wndHandler, wndControl) -- Also LeaveAdventureBtn, AdventureCloseBtn
	self.tZombieStats = nil
	if self.wndMain then
		local peCurrent = self.wndMain:GetData() and self.wndMain:GetData().peEvent
		if peCurrent then
			peCurrent:RequestScoreboard(false)
		end
		if ktEventTypeToWindowName[peCurrent:GetEventType()] then
			local wndGrid = self.wndMain:FindChild(ktEventTypeToWindowName[peCurrent:GetEventType()])
			local wndGridTop 	= wndGrid:FindChild("PvPTeamGridTop")
			local wndGridBot 	= wndGrid:FindChild("PvPTeamGridBot")

			if wndGridTop then
				wndGridTop:DeleteAll()
			end
			if wndGridBot then
				wndGridBot:DeleteAll()
			end
		end

		self.wndMain:Close()
		Apollo.StopTimer("UpdateTimer")
	end
	if self.wndAdventure then
		self.wndAdventure:Destroy()
	end
end

function PublicEventStats:OnPvPLeaveMatchBtn(wndHandler, wndControl)
	if MatchingGame.IsInMatchingGame() then
		if self.wndMain then
			self.wndMain:FindChild("Header:BGPvPWinnerTopBar"):Show(false)
			self.wndMain:Close()
		end
		MatchingGame.LeaveMatchingGame()
	end
end

function PublicEventStats:OnPvPSurrenderMatchBtn( wndHandler, wndControl, eMouseButton )
	if not MatchingGame.IsVoteSurrenderActive() then
		MatchingGame.InitiateVoteToSurrender()
	end
end

-----------------------------------------------------------------------------------------------
-- Adventures Summary
-----------------------------------------------------------------------------------------------

function PublicEventStats:BuildAdventuresSummary(tMegaList, peAdventure)
	self.wndAdventure = Apollo.LoadForm(self.xmlDoc , "AdventureEventStatsForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("MatchMaker_Adventures")})

	local wndCurr = self.wndAdventure
	local tSelf = tMegaList.tStatsSelf[1]
	local tScore = {["nDamage"] = 0, ["nHealed"] = 0, ["nDeaths"] = 0}

	-- Add Custom to score tracker
	for idx, tTable in pairs(tSelf.arCustomStats) do
		if tTable.nValue and tTable.nValue > 0 then
			tScore[tTable.strName] = 0
			tSelf[tTable.strName] = tTable.nValue
		end
	end

	-- Count times beaten by other participants
	for key, tCurr in pairs(tMegaList["tStatsParticipant"]) do
		tScore = self:HelperCompareAdventureScores(tSelf, tCurr, tScore)
	end

	-- Convert to an interim table for sorting
	local tSortedTable = self:HelperSortTableForAdventuresSummary(tScore)
	wndCurr:FindChild("AwardsContainer"):DestroyChildren()
	for key, tData in pairs(tSortedTable) do
		local strIndex = tData.strKey
		local nValue = tData.nValue
		if #wndCurr:FindChild("AwardsContainer"):GetChildren() < 3 then
			local nValueForString = math.abs(0 - nValue) + 1
			--local wndListItem = Apollo.LoadForm(self.xmlDoc , "AdventureListItem", wndCurr:FindChild("AwardsContainer"), self)
			local strDisplayText = ""
			local strLabelText = nil
			if strIndex == "nDeaths" then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardLiving"), nValueForString)
				strDisplayText = Apollo.GetString("PublicEventStats_Deaths")
			elseif strIndex == "nHealed" and tSelf.nHealed > 0 then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardOther"), nValueForString, Apollo.GetString("PublicEventStats_Heals"))
				strDisplayText = Apollo.GetString("PublicEventStats_Heals")
			elseif strIndex == "nDamage" and tSelf.nDamage > 0 then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardOther"), nValueForString, Apollo.GetString("CRB_Damage"))
				strDisplayText = Apollo.GetString("CRB_Damage")
			elseif nValue > 0 and tSelf[strIndex] and tSelf[strIndex] > 0 then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardOther"), nValueForString, strIndex)
			end
			if strLabelText then
				local wndListItem = Apollo.LoadForm(self.xmlDoc , "AdventureListItem", wndCurr:FindChild("AwardsContainer"), self)
				wndListItem:FindChild("AdventureListTitle"):SetText(strLabelText)
				wndListItem:FindChild("AdventureListDetails"):SetText((tSelf[strIndex] or 0) .. " " .. strDisplayText)
				wndListItem:FindChild("AdventureListIcon"):SetSprite(ktAdventureListStrIndexToIconSprite[strIndex] or "Icon_SkillMind_UI_espr_moverb") -- TODO hardcoded formatting
			end
		end
	end

	wndCurr:FindChild("AwardsContainer"):ArrangeChildrenVert(0)

	-- Reward Tier
	if self.tZombieStats and self.tZombieStats.eRewardTier and self.tZombieStats.eRewardType ~= 0 then -- TODO: ENUM!!
		wndCurr:FindChild("BGRewardTierFrame"):SetText(ktRewardTierInfo[self.tZombieStats.eRewardTier][1])
		wndCurr:FindChild("BGRewardTierIcon"):SetSprite(ktRewardTierInfo[self.tZombieStats.eRewardTier][2])
	else
		wndCurr:FindChild("BGRewardTierFrame"):SetText("")
	end

	if self.tZombieStats then
		local strTime = self:HelperConvertTimeToString(self.tZombieStats.nElapsedTime)
		local strTitle = String_GetWeaselString(Apollo.GetString("PublicEventStats_PlayerStats"), peAdventure:GetName())
		wndCurr:FindChild("BGTop"):SetText(String_GetWeaselString(Apollo.GetString("PublicEventStats_TimerHeader"), strTitle, strTime))
	else
		wndCurr:FindChild("BGTop"):SetText(String_GetWeaselString(Apollo.GetString("PublicEventStats_PlayerStats"), peAdventure:GetName()))
	end
end

function PublicEventStats:HelperCompareAdventureScores(tSelf, tCurr, tScore)
	if not self.nCount then
		self.nCount = 1
	else
		self.nCount = self.nCount + 1
	end

	if tCurr.nDeaths < tSelf.nDeaths then
		tScore.nDeaths = tScore.nDeaths + 1
	end
	if tCurr.nDamage > tSelf.nDamage then
		tScore.nDamage = tScore.nDamage + 1
	end
	if tCurr.nHealed > tSelf.nHealed then
		tScore.nHealed = tScore.nHealed + 1
	end

	for nStatsIdx, tTable in pairs(tCurr.arCustomStats) do
		for nStatsSelfIdx, tSelfTable in pairs(tSelf.arCustomStats) do
			local bValid = (nStatsIdx == nStatsSelfIdx) and (tTable.nValue > tSelfTable.nValue)
			if bValid then
				if not tScore[tTable.strName] then
					tScore[tTable.strName] = 0
				end
				tScore[tTable.strName] = tScore[tTable.strName] + 1
			end
		end
	end

	return tScore
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function PublicEventStats:HelperBuildCombinedList(tStatsSelf, tStatsTeam, tStatsParticipants)
	local tMegaList = {}
	tMegaList.tStatsSelf = {tStatsSelf}

	if tStatsTeam then
		for key, tCurr in pairs(tStatsTeam) do
			if not tMegaList.tStatsTeam then
				tMegaList.tStatsTeam = {}
			end
			table.insert(tMegaList.tStatsTeam, tCurr)
		end
	end

	if tStatsParticipants then
		for key, tCurr in pairs(tStatsParticipants) do
			if not tMegaList.tStatsParticipant then
				tMegaList.tStatsParticipant = {}
			end
			table.insert(tMegaList.tStatsParticipant, tCurr)
		end
	end
	return tMegaList
end

function PublicEventStats:HelperFormatNumber(nArg)
	if tonumber(nArg) and tonumber(nArg) > 10000 then
		nArg = String_GetWeaselString(Apollo.GetString("PublicEventStats_Thousands"), math.floor(nArg/1000))
	else
		nArg = tostring(nArg)
	end
	return nArg
	-- TODO: Consider trimming huge numbers into a more readable format
end

function PublicEventStats:HelperSortTableForAdventuresSummary(tScore)
	local tNewTable = {}
	for key, nValue in pairs(tScore) do
		table.insert(tNewTable, {strKey = key, nValue = nValue or 0})
	end
	table.sort(tNewTable, function(a,b) return a.nValue < b.nValue end)
	return tNewTable
end

function PublicEventStats:HelperConvertTimeToString(fTime)
	fTime = math.floor(fTime / 1000) -- TODO convert to full seconds

	return string.format("%d:%02d", math.floor(fTime / 60), math.floor(fTime % 60))
end

function PublicEventStats:HelperGridFactoryProduce(wndGrid, tTargetComparison)
	for nRow = 1, wndGrid:GetRowCount() do
		if wndGrid:GetCellLuaData(nRow, 1) == tTargetComparison then -- GetCellLuaData args are row, col
			return nRow
		end
	end
	return wndGrid:AddRow("") -- GOTCHA: This is a row number
end

local PublicEventStatsInst = PublicEventStats:new()
PublicEventStatsInst:Init()
