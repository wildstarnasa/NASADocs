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

local ktParticipantKeys = 
{
	[PublicEvent.PublicEventType_PVP_Arena] =
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

	[PublicEvent.PublicEventType_PVP_Warplot] =
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

	[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] =
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
	[PublicEvent.PublicEventType_PVP_Battleground_Vortex] =
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
	[PublicEvent.PublicEventType_PVP_Battleground_Sabotage] =
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
	[PublicEvent.PublicEventType_WorldEvent] 					= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_Astrovoid] 			= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_Farside] 			= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_Galeras] 			= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_Hycrest]				= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_LevianBay] 			= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_Malgrave] 			= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_NorthernWilds] 		= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_Skywatch] 			= "PublicEventGrid",
	[PublicEvent.PublicEventType_Adventure_Whitevale] 			= "PublicEventGrid",
	[PublicEvent.PublicEventType_Dungeon] 						= "PublicEventGrid",
	[PublicEvent.PublicEventType_Shiphand]						= "PublicEventGrid",
}

local ktPvEInstancedEvents =
{
	[PublicEvent.PublicEventType_Adventure_Astrovoid] 		= true,
	[PublicEvent.PublicEventType_Adventure_Farside] 		= true,
	[PublicEvent.PublicEventType_Adventure_Galeras] 		= true,
	[PublicEvent.PublicEventType_Adventure_Hycrest]			= true,
	[PublicEvent.PublicEventType_Adventure_LevianBay] 		= true,
	[PublicEvent.PublicEventType_Adventure_Malgrave] 		= true,
	[PublicEvent.PublicEventType_Adventure_NorthernWilds] 	= true,
	[PublicEvent.PublicEventType_Adventure_Skywatch] 		= true,
	[PublicEvent.PublicEventType_Adventure_Whitevale] 		= true,
	[PublicEvent.PublicEventType_Dungeon] 					= true,
	[PublicEvent.PublicEventType_Shiphand]					= true,
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
	[PublicEvent.PublicEventRewardTier_None] 	= {strText = Apollo.GetString("PublicEventStats_NoMedal"), 		strSprite = "CRB_ChallengeTrackerSprites:sprChallengeTierRed"},
	[PublicEvent.PublicEventRewardTier_Bronze] 	= {strText = Apollo.GetString("PublicEventStats_BronzeMedal"), 	strSprite = "CRB_ChallengeTrackerSprites:sprChallengeTierBronze"},
	[PublicEvent.PublicEventRewardTier_Silver] 	= {strText = Apollo.GetString("PublicEventStats_SilverMedal"), 	strSprite = "CRB_ChallengeTrackerSprites:sprChallengeTierSilver"},
	[PublicEvent.PublicEventRewardTier_Gold] 	= {strText = Apollo.GetString("PublicEventStats_GoldMedal"), 	strSprite = "CRB_ChallengeTrackerSprites:sprChallengeTierGold"},
}

local karRandomFailStrings =
{
	"PublicEventStats_RandomNoPassFlavor_1",
	"PublicEventStats_RandomNoPassFlavor_2",
	"PublicEventStats_RandomNoPassFlavor_3",
}

local karRandomPassStrings =
{
	"PublicEventStats_RandomNoFailFlavor_1",
	"PublicEventStats_RandomNoFailFlavor_2",
	"PublicEventStats_RandomNoFailFlavor_3",
}

local knXCursorOffset = 10
local knYCursorOffset = 25
local kstrDungeonGoldIcon = "<T Image=\"sprChallengeTierGold\"></T><T TextColor=\"0\">.</T>"
local kstrDungeonBronzeIcon = "<T Image=\"sprChallengeTierBronze\"></T><T TextColor=\"0\">.</T>"

function PublicEventStats:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PublicEventStats.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PublicEventStats:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	math.randomseed(os.time())

    Apollo.RegisterEventHandler("GenericEvent_OpenEventStats", 			"OnToggleEventStats", self)
    Apollo.RegisterEventHandler("GenericEvent_OpenEventStatsZombie", 	"InitializeZombie", self)
	Apollo.RegisterEventHandler("ResolutionChanged", 					"OnResolutionChanged", self)
	Apollo.RegisterEventHandler("WarPartyMatchResults", 				"OnWarPartyMatchResults", self)
	Apollo.RegisterEventHandler("PVPMatchFinished", 					"OnPVPMatchFinished", self)
	Apollo.RegisterEventHandler("PublicEventStart",						"OnPublicEventStart", self)
	Apollo.RegisterEventHandler("PublicEventEnd", 						"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventLeave", 					"OnPublicEventLeave", self)
	Apollo.RegisterEventHandler("ChangeWorld", 							"OnChangeWorld", self)
	Apollo.RegisterEventHandler("GuildWarCoinsChanged",					"OnGuildWarCoinsChanged", self)
	Apollo.RegisterEventHandler("PublicEventLiveStatsUpdate",			"OnLiveStatsUpdate", self)

	self.wndScoreboard = nil
	self.wndAdventure = nil
	self.wndDungeonMedalsForm = nil
	self.wndPvPContextMenu = nil
	
	self.tTrackedStats = nil
	self.tZombieStats = nil
	self.peActiveEvent = nil
	self.arTeamNames = {}
	self.tWarplotResults  = {}
	
	self.timerRedrawInfo = ApolloTimer.Create(1.0, true, "UpdateGrid", self)
	self.timerRedrawInfo:Stop()

	local tActiveEvents = PublicEvent.GetActiveEvents()
	for idx, peEvent in pairs(tActiveEvents) do
		self:OnPublicEventStart(peEvent)
	end
end

------------------------------------------------------------------------------------
-----    Live Stat Scoreboards
------------------------------------------------------------------------------------
function PublicEventStats:OnToggleEventStats(peEvent)
	if self.wndScoreboard and self.wndScoreboard:IsShown() then
		self.timerRedrawInfo:Stop()
		self.wndScoreboard:Close()
	else
		self.tTrackedStats = peEvent:GetLiveStats()
		
		if not self.wndScoreboard then
			self:InitializeScoreboard(peEvent)
		end
		self.timerRedrawInfo:Start()
		
		-- Allow the PublicEventLiveStatsUpdate to fire
		peEvent:RequestScoreboard(true)
		self:UpdateGrid()
		self.wndScoreboard:Invoke()
	end
end

function PublicEventStats:OnPublicEventStart(peEvent)
	-- Clear any stats we were holding onto
	self.tZombieStats = nil
	
	-- If it doesn't have live stats (PvE instances), we don't need to track it in real time
	if peEvent:HasLiveStats() then
		self.tTrackedStats = peEvent:GetLiveStats()
		self.peActiveEvent = peEvent
		
		peEvent:RequestScoreboard(true)
		if not self.wndScoreboard then
			self:InitializeScoreboard(peEvent)
		end
	end
end

function PublicEventStats:InitializeScoreboard(peEvent)
	local tStats = self.tTrackedStats or self.tZombieStats or peEvent:GetLiveStats()
	
	-- We won't get far without stats to draw
	if not tStats or not tStats.arParticipantStats or #tStats.arParticipantStats == 0 then
		return
	end
	
	if not self.wndScoreboard or not self.wndScoreboard:IsValid() then
		self.wndScoreboard = Apollo.LoadForm(self.xmlDoc , "PublicEventStatsForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndScoreboard, strName = Apollo.GetString("Tutorials_PublicEvents")})
	end
	
	-- Primarily for when the timer is fired
	if not peEvent and self.peActiveEvent then
		peEvent = self.tZombieStats and self.tZombieStats.peEvent or self.peActiveEvent
	else
		self.peActiveEvent = peEvent
	end

	local eEventType = peEvent:GetEventType()
	local wndParent = self.wndScoreboard:FindChild(ktEventTypeToWindowName[eEventType])

	local wndGrid = wndParent
	if ktPvPEvents[eEventType] then
		wndGrid = wndParent:FindChild("PvPTeamGridBot")

		for idx = 1, wndGrid:GetColumnCount() do
			wndGrid:SetColumnText(idx, Apollo.GetString(ktEventTypeToColumnNameList[eEventType][idx]))
		end

		wndGrid = wndParent:FindChild("PvPTeamGridTop")
	end

	local nMaxScoreboardWidth = self.wndScoreboard:GetWidth() - wndGrid:GetWidth() + 15 -- Magic number for the width of the scroll bar
	for idx = 1, wndGrid:GetColumnCount() do
		nMaxScoreboardWidth = nMaxScoreboardWidth + wndGrid:GetColumnWidth(idx)
		wndGrid:SetColumnText(idx, Apollo.GetString(ktEventTypeToColumnNameList[eEventType][idx])) 
	end

	self.wndScoreboard:SetSizingMinimum(640, 500)
	self.wndScoreboard:SetSizingMaximum(nMaxScoreboardWidth, 800)

	self.strMyName = GameLib.GetPlayerUnit():GetName()
	
	if ktPvPEvents[eEventType] then
		local wndHeaderTop 	= wndParent:FindChild("PvPTeamHeaderTop")
		local wndHeaderBot 	= wndParent:FindChild("PvPTeamHeaderBot")
		local wndGridTop 	= wndParent:FindChild("PvPTeamGridTop")
		local wndGridBot 	= wndParent:FindChild("PvPTeamGridBot")
		
		local tMatchState = MatchingGame:GetPVPMatchState()

		for key, tCurr in pairs(tStats.arTeamStats) do
			local wndHeader = nil
			if not wndHeaderTop:GetData() or tCurr.strTeamName == wndHeaderTop:GetData() then
				wndHeaderTop:SetData(tCurr.strTeamName)
				wndHeader = wndHeaderTop
			elseif not wndHeaderBot:GetData() or tCurr.strTeamName == wndHeaderBot:GetData() then
				wndHeaderBot:SetData(tCurr.strTeamName)
				wndHeader = wndHeaderBot
			end
			
			if wndHeader then
				self:CheckTeamName(key, wndHeader, tStats, tMatchState)
			end
		end
	-- Set up reward info for zombie world event stats
	end
	
	if tStats.eRewardTier and tStats.eRewardType and not ktPvPEvents[eEventType] then
		self.wndScoreboard:FindChild("BGRewardTierIcon"):SetSprite(ktRewardTierInfo[tStats.eRewardTier].strSprite)
		self.wndScoreboard:FindChild("BGRewardTierFrame"):SetText(ktRewardTierInfo[tStats.eRewardTier].strText)
	else
		self.wndScoreboard:FindChild("BGRewardTierIcon"):SetSprite("")
		self.wndScoreboard:FindChild("BGRewardTierFrame"):SetText("")
	end

	self.wndScoreboard:Show(false)
end

-- Fires from the quest tracker's PublicEvent Tracker
function PublicEventStats:InitializeZombie(tZombieEvent)
	self.tZombieStats = tZombieEvent.tStats
	self:InitializeScoreboard(tZombieEvent.peEvent)
	self:UpdateGrid()
	self.wndScoreboard:Invoke()
end

function PublicEventStats:UpdateGrid() -- self.wndScoreboard guaranteed valid and visible
	if self.wndScoreboard then
		for key, wndCurr in pairs(self.wndScoreboard:FindChild("MainGridContainer"):GetChildren()) do
			wndCurr:Show(false)
		end

		local eEventType = self.peActiveEvent:GetEventType()
		
		local wndGrid = nil
		
		if ktEventTypeToWindowName[eEventType] then
			wndGrid = self.wndScoreboard:FindChild(ktEventTypeToWindowName[eEventType])
		end

		-- Determine which type of window to use
		if ktPvPEvents[eEventType] then
			self:HelperBuildPvPSharedGrids(wndGrid, eEventType)
		else
			self:BuildPublicEventGrid(wndGrid)
		end

		-- Title Text (including timer)
		local strTitleText = ""
		if self.peActiveEvent:IsActive() and self.peActiveEvent:GetElapsedTime() then
			strTitleText = String_GetWeaselString(Apollo.GetString("PublicEventStats_TimerHeader"), self.peActiveEvent:GetName(), self:HelperConvertTimeToString(self.peActiveEvent:GetElapsedTime()))
		elseif self.tZombieStats and self.tZombieStats.nElapsedTime then
			strTitleText = String_GetWeaselString(Apollo.GetString("PublicEventStats_FinishTime"), self.peActiveEvent:GetName(), self:HelperConvertTimeToString(self.tZombieStats.nElapsedTime))
		end
		self.wndScoreboard:FindChild("EventTitleText"):SetText(strTitleText)

		if wndGrid then
			wndGrid:Show(true)
		end
	end
end


function PublicEventStats:OnLiveStatsUpdate(peEvent)
	if peEvent and peEvent:IsActive() then
		self.tTrackedStats = peEvent:GetLiveStats()
	end
	
	-- Changing the resolution
	if self.bResolutionChanged and self.wndScoreboard then
		self.bResolutionChanged = false
		local nLeft, nTop, nRight, nBottom = self.wndScoreboard:GetAnchorOffsets()
		if Apollo.GetDisplaySize().nWidth <= 1400 then
			self.wndScoreboard:SetAnchorOffsets(nLeft, nTop, nLeft + 650, nBottom)
		else
			self.wndScoreboard:SetAnchorOffsets(nLeft, nTop, nLeft + 800, nBottom)
		end
	end
end

------------------------------------------------------------------------------------
-----    PvP Specific Functions
------------------------------------------------------------------------------------

function PublicEventStats:CheckTeamName(eMatchTeam, wndHeader, tLiveStats, tMatchState)
	local crTitleColor = ApolloColor.new("ff7fffb9")
	local strTeamName = (tMatchState and tMatchState.arTeams and tMatchState.arTeams[eMatchTeam] and tMatchState.arTeams[eMatchTeam].strName) or (tLiveStats and tLiveStats.arTeamStats and tLiveStats.arTeamStats[eMatchTeam] and tLiveStats.arTeamStats[eMatchTeam].strTeamName) or ""
	self.arTeamNames[eMatchTeam] = strTeamName
	
	wndHeader:FindChild("PvPHeaderTitle"):SetTextColor(crTitleColor)
	wndHeader:FindChild("PvPHeaderTitle"):SetText(strTeamName)
end

function PublicEventStats:HelperBuildPvPSharedGrids(wndParent, eEventType)
	-- If we're storing stats, use those instead
	if self.tZombieStats then
		self.tTrackedStats = self.tZombieStats
	end
	
	-- If we don't have any tracked stats or invalid tracked stats, bail.
	if not self.tTrackedStats or not self.tTrackedStats.arTeamStats or not self.tTrackedStats.arParticipantStats then
		return
	end

	-- Get some windows.
	local wndGridTop 	= wndParent:FindChild("PvPTeamGridTop")
	local wndGridBot 	= wndParent:FindChild("PvPTeamGridBot")
	local wndHeaderTop 	= wndParent:FindChild("PvPTeamHeaderTop")
	local wndHeaderBot 	= wndParent:FindChild("PvPTeamHeaderBot")

	-- Get some variables
	local nVScrollPosTop 	= wndGridTop:GetVScrollPos()
	local nVScrollPosBot 	= wndGridBot:GetVScrollPos()
	local nSortedColumnTop 	= wndGridTop:GetSortColumn() or 1
	local nSortedColumnBot 	= wndGridBot:GetSortColumn() or 1
	local bAscendingTop 	= wndGridTop:IsSortAscending()
	local bAscendingBot 	= wndGridBot:IsSortAscending()

	-- Clear the grids to redraw them
	wndGridTop:DeleteAll()
	wndGridBot:DeleteAll()

	-- Get the info for the match
	local tMatchState = MatchingGame:GetPVPMatchState()
	local wndHeader = nil
	
	for idx, tCurr in pairs(self.tTrackedStats.arTeamStats) do
		if tCurr.strTeamName == wndHeaderTop:GetData() then
			wndHeader = wndHeaderTop
		elseif tCurr.strTeamName == wndHeaderBot:GetData() then
			wndHeader = wndHeaderBot
		end
		
		if wndHeader then
			-- ... and set up the header.
			local strHeaderText = self.arTeamNames[key] or ""
			local strDamage	= String_GetWeaselString(Apollo.GetString("PublicEventStats_Damage"), Apollo.FormatNumber(tCurr.nDamage, 0, true))
			local strHealed	= String_GetWeaselString(Apollo.GetString("PublicEventStats_Healing"), Apollo.FormatNumber(tCurr.nHealed, 0, true))
			
			if tCurr.bIsMyTeam then
				self.strMyPublicEventTeam = tCurr.strTeamName
			end

			-- Setting up the team names / headers
			if eEventType == PublicEvent.PublicEventType_PVP_Battleground_Vortex or eEventType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine or eEventType == PublicEvent.PublicEventType_PVP_Battleground_Sabotage then
				local strKDA = String_GetWeaselString(Apollo.GetString("PublicEventStats_KDA"), tCurr.nKills, tCurr.nDeaths, tCurr.nAssists)
				strHeaderText = String_GetWeaselString(Apollo.GetString("PublicEventStats_PvPHeader"), strKDA, strDamage, strHealed)
			elseif eEventType == PublicEvent.PublicEventType_PVP_Arena then
				strHeaderText = String_GetWeaselString(Apollo.GetString("PublicEventStats_ArenaHeader"), strDamage, strHealed) -- TODO, Rating Change when support is added
			elseif eEventType == PublicEvent.PublicEventType_PVP_Warplot then
				if self.tWarplotResults and self.tWarplotResults[key] then
					strHeaderText = String_GetWeaselString(Apollo.GetString("PEStats_WarPartyTeamStats"), self.tWarplotResults[key].nRating, self.tWarplotResults[key].nDestroyedPlugs, self.tWarplotResults[key].nRepairCost, self.tWarplotResults[key].nWarCoinsEarned)
				else
					strHeaderText = ""
				end
			end

			wndHeader:FindChild("PvPHeaderText"):SetText(strHeaderText)
		end
	end

	-- For each player ...
	for key, tParticipant in pairs(self.tTrackedStats.arParticipantStats) do
		-- ... figure out which window their team is on, ...
		local wndGrid = nil
		if tParticipant.strTeamName == wndHeaderTop:GetData() then
			wndGrid = wndGridTop
		elseif tParticipant.strTeamName == wndHeaderBot:GetData() then
			wndGrid = wndGridBot
		end

		-- Custom Stats
		if wndGrid then
			-- ... determine what "Custom" means, ...
			if eEventType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine then
				for idx, tCustomTable in pairs(tParticipant.arCustomStats) do
					if tCustomTable.strName == Apollo.GetString("PublicEventStats_SecondaryPointCaptured") then
						tParticipant.nCustomNodesCaptured = tCustomTable.nValue or 0
					end
				end
			elseif eEventType == PublicEvent.PublicEventType_PVP_Battleground_Vortex then
				for idx, tCustomTable in pairs(tParticipant.arCustomStats) do
					if idx == 1 then
						tParticipant.nCustomFlagsPlaced = tCustomTable.nValue or 0
					else
						tParticipant.bCustomFlagsStolen = tCustomTable.nValue or 0
					end
				end
			end

			-- ... set up Player Reporting, ...
			local rptInfraction = tParticipant.rptParticipant
			if not rptInfraction then
				rptInfraction = self.peActiveEvent:PrepareInfractionReport(key)
			end

			local nCurrRow = self:HelperGridFactoryProduce(wndGrid, tParticipant.strName) -- GOTCHA: This is an integer
			wndGrid:SetCellLuaData(nCurrRow, 1, tParticipant.strName)
			wndGrid:SetCellLuaData(nCurrRow, 2, tParticipant.strTeamName == self.strMyPublicEventTeam and rptInfraction)

			-- ... figure out the stats, ...
			for idx, strParticipantKey in pairs(ktParticipantKeys[eEventType]) do
				local oValue = tParticipant[strParticipantKey]
				local strClassIcon = idx == 1 and kstrClassToMLIcon[tParticipant.eClass] or ""
				local strAppend = ""
				
				if type(oValue) == "number" then
					wndGrid:SetCellSortText(nCurrRow, idx, string.format("%8d", oValue))
					strAppend = Apollo.FormatNumber(oValue)
				elseif type(oValue) == "string" then
					wndGrid:SetCellSortText(nCurrRow, idx, oValue or "")
					strAppend = oValue
				end
				
				-- ... and add the stats to the grid.
				wndGrid:SetCellDoc(nCurrRow, idx, string.format("<T Font=\"CRB_InterfaceSmall\">%s%s</T>", strClassIcon, strAppend))
			end
		end
	end

	-- Reset scroll and sort info
	wndGridTop:SetVScrollPos(nVScrollPosTop)
	wndGridBot:SetVScrollPos(nVScrollPosBot)
	wndGridTop:SetSortColumn(nSortedColumnTop, bAscendingTop)
	wndGridBot:SetSortColumn(nSortedColumnBot, bAscendingBot)
	self.wndScoreboard:FindChild("PvPLeaveMatchBtn"):Show(self.tZombieStats or (tMatchState and tMatchState.eState == MatchingGame.PVPGameState.Finished))
	self.wndScoreboard:FindChild("PvPSurrenderMatchBtn"):Show(not self.tZombieStats and eEventType == "WarPlot")
end

function PublicEventStats:OnPvPGridClick(wndHandler, wndControl, iRow, iCol, eMouseButton)
	local strName = wndHandler:GetCellData(iRow, 1)
	local rptParticipant = wndHandler:GetCellData(iRow, 2)
	
	-- If you right click on another player ... 
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and strName and strName ~= self.strMyName then
		-- ... close any existing context menu, ...
		self:OnContextMenuPlayerClosed()

		-- ... open a new context menu, ...
		self.wndPvPContextMenu = Apollo.LoadForm(self.xmlDoc, "ContextMenuPlayerForm", "TooltipStratum", self)
		self.wndPvPContextMenu:FindChild("BtnReportPlayer"):Show(false)
		self.wndPvPContextMenu:FindChild("BtnAddRival"):SetData(strName)
		self.wndPvPContextMenu:Invoke()

		-- ... and move it into place.
		local nHeight = self.wndPvPContextMenu:FindChild("ButtonList"):ArrangeChildrenVert(0)
		local nLeft, nTop, nRight, nBottom = self.wndPvPContextMenu:GetAnchorOffsets()
		self.wndPvPContextMenu:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 60)

		local tCursor = Apollo.GetMouse()
		self.wndPvPContextMenu:Move(tCursor.x - knXCursorOffset, tCursor.y - knYCursorOffset, self.wndPvPContextMenu:GetWidth(), self.wndPvPContextMenu:GetHeight())
	end
end

-----------------------------------------------------------------------------------------------
-----    Context Menu Functions
-----------------------------------------------------------------------------------------------

-- Why does this even have its own special edge case context menu?
function PublicEventStats:OnContextMenuAddRival(wndHandler, wndControl)
	local strTarget = wndHandler:GetData()
	FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Rival, strTarget)
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("Social_AddedToRivals"), strTarget))
	self:OnContextMenuPlayerClosed()
end

function PublicEventStats:OnContextMenuReportPlayer(wndHandler, wndControl)
	local rptParticipant = wndHandler:GetData()
	Event_FireGenericEvent("GenericEvent_ReportPlayerPvP", rptParticipant)
	self:OnContextMenuPlayerClosed()
end

function PublicEventStats:OnContextMenuPlayerClosed(wndHandler, wndControl)
	if self.wndPvPContextMenu and self.wndPvPContextMenu:IsValid() then
		self.wndPvPContextMenu:Destroy()
		self.wndPvPContextMenu = nil
	end
end

-----------------------------------------------------------------------------------------------
-----    Public Event Specific Functions
-----------------------------------------------------------------------------------------------

function PublicEventStats:BuildPublicEventGrid(wndGrid)
	-- Save scroll info
	local nVScrollPos = wndGrid:GetVScrollPos()
	local nSortedColumn = wndGrid:GetSortColumn() or 1
	local bAscending = wndGrid:IsSortAscending()
	local tStats = self.tTrackedStats or self.tZombieStats
	 -- TODO remove this for better performance eventually
	wndGrid:DeleteAll()
	
	-- If we don't have stats, close the window.
	if not tStats then
		self.wndScoreboard:Close()
	end
	
	-- Set up each player's stats
	for strKey, tCurr in pairs(tStats.arParticipantStats) do
		if tCurr.strName and tCurr.strName ~= "" then
			local wndCurrRow = self:HelperGridFactoryProduce(wndGrid, tCurr.strName) -- GOTCHA: This is an integer
			wndGrid:SetCellLuaData(wndCurrRow, 1, tCurr.strName)
			
			local strName = (tCurr.strName and tCurr.strName ~= "") and tCurr.strName or Apollo.GetString("PublicEventStats_Total")
			
			-- index is the column that the value will be applied to
			local tAttributes = {strName, tCurr.nContributions, tCurr.nDamage, tCurr.nDamageReceived, tCurr.nHealed, tCurr.nHealingReceived}			
			
			for idx, oValue in pairs(tAttributes) do
				local strText
				if type(oValue) == "number" then
					wndGrid:SetCellSortText(wndCurrRow, idx, string.format("%8d", oValue))
					strText = Apollo.FormatNumber(oValue)
				else
					wndGrid:SetCellSortText(wndCurrRow, idx, oValue)
					strText = oValue
				end
				wndGrid:SetCellDoc(wndCurrRow, idx, "<T Font=\"CRB_InterfaceSmall\">" .. strText .. "</T>")
			end
		end
	end

	-- Reset the scroll and sort info
	wndGrid:SetVScrollPos(nVScrollPos)
	wndGrid:SetSortColumn(nSortedColumn, bAscending)
	self.wndScoreboard:FindChild("PvPLeaveMatchBtn"):Show(false)
	self.wndScoreboard:FindChild("PvPSurrenderMatchBtn"):Show(false)
end

-----------------------------------------------------------------------------------------------
-----    End of Match Functions
-----------------------------------------------------------------------------------------------

-- If you leave the match, stop showing who won so we can reset it for the next match.
function PublicEventStats:OnPublicEventLeave(peEnding, eReason)
	if self.wndScoreboard and self.wndScoreboard:IsValid() then
		self.wndScoreboard:FindChild("Header:BGPvPWinnerTopBar"):Show(false)
	end
end

-- Notably not fired for warplots
function PublicEventStats:OnPVPMatchFinished(eWinner, eReason, nDeltaTeam1, nDeltaTeam2)
	-- If the window is already shown, bail.
	if not self.wndScoreboard or not self.wndScoreboard:IsValid() or not self.wndScoreboard:IsShown() then
		return
	end

	-- For every PvP event type other than warplots...
	local eEventType = self.peActiveEvent:GetEventType()
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

	if eWinner == MatchingGame.Winner.Draw then
		strMessage = Apollo.GetString("PublicEventStats_Draw")
	elseif eMyTeam == eWinner then
		strMessage = Apollo.GetString("PublicEventStats_ArenaVictory")
	else
		strMessage = Apollo.GetString("PublicEventStats_ArenaDefeat")
	end

	-- Display rating changes for Rated BGs(?), Warplots(?), and Arena Teams
	local arRatingDelta = nil
	if nDeltaTeam1 and nDeltaTeam2 then
		arRatingDelta =
		{
			nDeltaTeam1,
			nDeltaTeam2
		}
	end
	
	-- Special header formatting for arena teams
	if tMatchState and eEventType == PublicEvent.PublicEventType_PVP_Arena and tMatchState.arTeams then
		local strMyArenaTeamName = ""
		local strOtherArenaTeamName = ""
		local wndHeaderTop 	= self.wndScoreboard:FindChild("MainGridContainer:PvPArenaContainer:PvPTeamHeaderTop")
		local wndHeaderBot 	= self.wndScoreboard:FindChild("MainGridContainer:PvPArenaContainer:PvPTeamHeaderBot")
		for idx, tCurr in pairs(tMatchState.arTeams) do
			local strDelta = ""
			if arRatingDelta then
				if tCurr.nDelta < 0 then
					strDelta = String_GetWeaselString(Apollo.GetString("PublicEventStats_NegDelta"), math.abs(arRatingDelta[idx]))
				elseif tCurr.nDelta > 0 then
					strDelta = String_GetWeaselString(Apollo.GetString("PublicEventStats_PosDelta"), math.abs(arRatingDelta[idx]))
				end
			end
			
			local strTeamName = String_GetWeaselString(Apollo.GetString("PublicEventStats_RatingChange"), tCurr.strName or self.tLiveStats.arTeamStats[tCurr.nTeam].strTeamName, tCurr.nRating + arRatingDelta[idx], strDelta)

			if eMyTeam == tCurr.nTeam then
				strMyArenaTeamName = strTeamName
			else
				strOtherArenaTeamName = strTeamName
			end
		end

		if wndHeaderTop:GetData() == self.strMyPublicEventTeam then
			wndHeaderTop:FindChild("PvPHeaderTitle"):SetText(strMyArenaTeamName)
			wndHeaderBot:FindChild("PvPHeaderTitle"):SetText(strOtherArenaTeamName)
		else
			wndHeaderTop:FindChild("PvPHeaderTitle"):SetText(strOtherArenaTeamName)
			wndHeaderBot:FindChild("PvPHeaderTitle"):SetText(strMyArenaTeamName)
		end
	end

	-- Show the result bar
	self.wndScoreboard:FindChild("BGPvPWinnerTopBar"):Show(true) -- Hidden when wndScoreboard is destroyed from OnClose
	self.wndScoreboard:FindChild("BGPvPWinnerTopBarArtText"):SetText(strMessage)
	self.wndScoreboard:FindChild("BGPvPWinnerTopBarArtText"):SetTextColor(strColor)
end

-- Only fired for warplots
function PublicEventStats:OnWarPartyMatchResults(tWarplotResults)
	-- The event gives us all the info we need to create a decent header
	if self.wndScoreboard and self.wndScoreboard:IsValid() then
		self.tWarplotResults = tWarplotResults
		for idx, tTeamStats in pairs(tWarplotResults or {}) do
			local strStats = String_GetWeaselString(Apollo.GetString("PEStats_WarPartyTeamStats"), tTeamStats.nRating, tTeamStats.nDestroyedPlugs, tTeamStats.nRepairCost, tTeamStats.nWarCoinsEarned)
			self.wndScoreboard:FindChild("PvPWarPlotContainer"):FindChild(idx == 1 and "PvPTeamHeaderTop" or "PvPTeamHeaderBot"):FindChild("PvPHeaderText"):SetData(strStats)
		end
		self.wndScoreboard:FindChild("PvPSurrenderMatchBtn"):Show(false)
	end
end

-- Post a chat message whenever War Coins change
function PublicEventStats:OnGuildWarCoinsChanged(guildOwner, nAmountGained)
	if nAmountGained > 0 then
		local strResult = String_GetWeaselString(Apollo.GetString("PEStats_WarcoinsGained"), nAmountGained)
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, strResult, "")
	end
end

------------------------------------------------------------------------------------
-----  General Use Functions
------------------------------------------------------------------------------------

function PublicEventStats:OnResolutionChanged()
	self.bResolutionChanged = true -- Delay so we can get the new oValue
end

-- When the public event ends, show the appropriate screen
function PublicEventStats:OnPublicEventEnd(peEnding, eReason, tStats)
	local eEventType = peEnding:GetEventType()
	self.peActiveEvent = peEnding
	self.tZombieStats = tStats
	
	if ktPvPEvents[eEventType] then
		if not self.wndScoreboard then
			self:InitializeScoreboard(peEnding)
		end
		self:UpdateGrid()
		self.wndScoreboard:Invoke()
	elseif ktPvEInstancedEvents[eEventType] then
		self:BuildAdventuresSummary()
		self.wndAdventure:Invoke()
	end
end

-- When we change zones, destroy the window and clear the info
function PublicEventStats:OnChangeWorld()
	if self.wndScoreboard and self.wndScoreboard:IsValid() then
		self.wndScoreboard:FindChild("BGPvPWinnerTopBarArtText"):SetText("")
		self.wndScoreboard:Destroy()
		self.wndScoreboard = nil
	end
	self.timerRedrawInfo:Stop()
	self.tZombieStats = nil
	self.tTrackedStats = nil
	self:OnClose()
end

function PublicEventStats:OnClose(wndHandler, wndControl) -- Also AdventureCloseBtn
	if self.wndScoreboard then
		local peCurrent = self.wndScoreboard:GetData() and self.wndScoreboard:GetData().peEvent
		if peCurrent then
			peCurrent:RequestScoreboard(false)
		end

		self.wndScoreboard:Close()
	end
	if self.wndAdventure then
		self.wndAdventure:Destroy()
		self.wndAdventure = nil
	end
	if self.wndDungeonMedalsForm and self.wndDungeonMedalsForm:IsValid() then
		self.wndDungeonMedalsForm:Destroy()
		self.wndDungeonMedalsForm = nil
	end
	self.timerRedrawInfo:Stop()
end

-----------------------------------------------------------------------------------------------
-----    Match Ending and Closing methods
-----------------------------------------------------------------------------------------------
function PublicEventStats:OnPvPLeaveMatchBtn(wndHandler, wndControl)
	if MatchingGame.IsInMatchingGame() then
		if self.wndScoreboard then
			self.wndScoreboard:FindChild("Header:BGPvPWinnerTopBar"):Show(false)
			self.wndScoreboard:Close()
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
-----    Adventures Summary
-----------------------------------------------------------------------------------------------

function PublicEventStats:BuildAdventuresSummary() -- Also Dungeons
	if not self.tZombieStats or not self.peActiveEvent then
		return
	end
	
	self.wndAdventure = Apollo.LoadForm(self.xmlDoc , "AdventureEventStatsForm", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndAdventure, strName = Apollo.GetString("MatchMaker_Adventures")})

	local tPersonalStats = self.peActiveEvent:GetMyStats()
	local tScore = {["nDamage"] = 0, ["nHealed"] = 0, ["nDeaths"] = 0}

	-- Add Custom to score tracker
	for idx, tStat in pairs(tPersonalStats.arCustomStats) do
		if tStat.nValue and tStat.nValue > 0 then
			tScore[tStat.strName] = 0
			tPersonalStats[tStat.strName] = tStat.nValue
		end
	end

	-- Count times beaten by other participants
	for key, tCurr in pairs(self.tZombieStats.arParticipantStats) do
		tScore = self:HelperCompareAdventureScores(tPersonalStats, tCurr, tScore)
	end

	-- Convert to an interim table for sorting
	local tSortedTable = self:HelperSortTableForAdventuresSummary(tScore)
	self.wndAdventure:FindChild("AwardsContainer"):DestroyChildren()
	for key, tData in pairs(tSortedTable) do
		local strIndex = tData.strKey
		local nValue = tData.nValue
		if #self.wndAdventure:FindChild("AwardsContainer"):GetChildren() < 3 then
			local nValueForString = math.abs(0 - nValue) + 1
			--local wndListItem = Apollo.LoadForm(self.xmlDoc , "AdventureListItem", self.wndAdventure:FindChild("AwardsContainer"), self)
			local strDisplayText = ""
			local strLabelText = nil
			if strIndex == "nDeaths" then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardLiving"), nValueForString)
				strDisplayText = Apollo.GetString("PublicEventStats_Deaths")
			elseif strIndex == "nHealed" and tPersonalStats.nHealed > 0 then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardOther"), nValueForString, Apollo.GetString("PublicEventStats_Heals"))
				strDisplayText = Apollo.GetString("PublicEventStats_Heals")
			elseif strIndex == "nDamage" and tPersonalStats.nDamage > 0 then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardOther"), nValueForString, Apollo.GetString("CRB_Damage"))
				strDisplayText = Apollo.GetString("CRB_Damage")
			elseif nValue > 0 and tPersonalStats[strIndex] and tPersonalStats[strIndex] > 0 then
				strLabelText = String_GetWeaselString(Apollo.GetString("PublicEventStats_AwardOther"), nValueForString, strIndex)
			end
			if strLabelText then
				local wndListItem = Apollo.LoadForm(self.xmlDoc , "AdventureListItem", self.wndAdventure:FindChild("AwardsContainer"), self)
				wndListItem:FindChild("AdventureListTitle"):SetText(strLabelText)
				wndListItem:FindChild("AdventureListDetails"):SetText((tPersonalStats[strIndex] or 0) .. " " .. strDisplayText)
				wndListItem:FindChild("AdventureListIcon"):SetSprite(ktAdventureListStrIndexToIconSprite[strIndex] or "Icon_SkillMind_UI_espr_moverb") -- TODO hardcoded formatting
			end
		end
	end

	self.wndAdventure:FindChild("AwardsContainer"):ArrangeChildrenVert(0)

	-- Reward Tier
	if self.tZombieStats and self.tZombieStats.eRewardTier and self.tZombieStats.eRewardType ~= 0 then -- TODO: ENUM!!
		self.wndAdventure:FindChild("RewardTierMessage"):SetText(ktRewardTierInfo[self.tZombieStats.eRewardTier].strText)
		self.wndAdventure:FindChild("RewardTierIcon"):SetSprite(ktRewardTierInfo[self.tZombieStats.eRewardTier].strSprite)
		
	else
		local wndMedalContainer = self.wndAdventure:FindChild("BGBottom")
		wndMedalContainer:FindChild("RewardTierIcon"):Show(false)
		wndMedalContainer:FindChild("OpenDungeonMedalsBtn"):Show(false)
		wndMedalContainer:FindChild("RewardTierMessage"):SetText(Apollo.GetString("PublicEventStats_NoDungeonMedals"))
	end

	-- Time in title
	if self.tZombieStats then
		local strTime = self:HelperConvertTimeToString(self.tZombieStats.nElapsedTime)
		local strTitle = String_GetWeaselString(Apollo.GetString("PublicEventStats_PlayerStats"), self.peActiveEvent:GetName())
		self.wndAdventure:FindChild("AdventureTitle"):SetText(String_GetWeaselString(Apollo.GetString("PublicEventStats_TimerHeader"), strTitle, strTime))
	else
		self.wndAdventure:FindChild("AdventureTitle"):SetText(String_GetWeaselString(Apollo.GetString("PublicEventStats_PlayerStats"), self.peActiveEvent:GetName()))
	end

	self.wndAdventure:FindChild("OpenDungeonMedalsBtn"):SetData(self.peActiveEvent)
	self.wndAdventure:FindChild("OpenDungeonMedalsBtn"):Show(self.peActiveEvent:GetEventType() == PublicEvent.PublicEventType_Dungeon)
end

function PublicEventStats:HelperCompareAdventureScores(tPersonalStats, tComparisonStats, tScore)
	if tComparisonStats.nDeaths < tPersonalStats.nDeaths then
		tScore.nDeaths = tScore.nDeaths + 1
	end
	if tComparisonStats.nDamage > tPersonalStats.nDamage then
		tScore.nDamage = tScore.nDamage + 1
	end
	if tComparisonStats.nHealed > tPersonalStats.nHealed then
		tScore.nHealed = tScore.nHealed + 1
	end

	for idx, tCompareStat in pairs(tComparisonStats.arCustomStats) do
		local tPersonalStat = tPersonalStats.arCustomStats[idx]
		if tPersonalStat and tCompareStat.nValue > tPersonalStat.nValue then
			if tScore[tCompareStat.strName] then
				tScore[tCompareStat.strName] = tScore[tCompareStat.strName] + 1
			else
				tScore[tCompareStat.strName] = 1
			end
		end
	end

	return tScore
end

-----------------------------------------------------------------------------------------------
-----    Dungeon Medals
-----------------------------------------------------------------------------------------------

function PublicEventStats:OnOpenDungeonMedalsBtn(wndHandler, wndControl)
	if self.wndDungeonMedalsForm and self.wndDungeonMedalsForm:IsValid() then
		self.wndDungeonMedalsForm:Destroy()
		self.wndDungeonMedalsForm = nil
	else
		self:BuildDungeonMedalScreen(wndHandler:GetData())
	end
end

function PublicEventStats:OnDungeonMedalsClose(wndHandler, wndControl)
	if self.wndDungeonMedalsForm and self.wndDungeonMedalsForm:IsValid() then
		self.wndDungeonMedalsForm:Destroy()
		self.wndDungeonMedalsForm = nil
	end
end

function PublicEventStats:BuildDungeonMedalScreen(peDungeon)
	if not self.tZombieStats or not self.tZombieStats.arObjectives then
		return
	end

	local strPass = ""
	local strFail = ""
	local nPass = 0
	local nTotal = 0
	for idx, tData in pairs(self.tZombieStats.arObjectives) do -- GOTCHA: Zombie Stats is needed as the event won't have :GetObjectives() when finished
		local peoObjective = tData.peoObjective
		local bPass = tData.eStatus == PublicEventObjective.PublicEventStatus_Succeeded -- Other states include Succeeded, Active, Inactive and Failed
		if not peoObjective:IsHidden() then
			-- Objective description, with fail safes
			local strObjective = string.len(peoObjective:GetShortDescription()) > 0 and peoObjective:GetShortDescription() or peoObjective:GetDescription()
			strObjective = string.len(strObjective) > 0 and strObjective or peoObjective:GetObjectiveId() -- Fail safe

			-- Different formatting based on pass/fail and challenge/objective
			local eCategory = peoObjective:GetCategory()
			if bPass and eCategory == PublicEventObjective.PublicEventObjectiveCategory_Challenge then
				strPass = strPass .. "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">" .. kstrDungeonGoldIcon .. " " .. strObjective .. "</P>"
			elseif eCategory == PublicEventObjective.PublicEventObjectiveCategory_Challenge then
				strFail = strFail .. "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">" .. kstrDungeonGoldIcon .. " " .. strObjective .. "</P>"
			elseif bPass and eCategory == PublicEventObjective.PublicEventObjectiveCategory_Optional then
				strPass = strPass .. "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">" .. kstrDungeonBronzeIcon .. " " .. strObjective .. "</P>"
			elseif eCategory == PublicEventObjective.PublicEventObjectiveCategory_Optional then
				strFail = strFail .. "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">" .. kstrDungeonBronzeIcon .. " " .. strObjective .. "</P>"
			end

			if eCategory == PublicEventObjective.PublicEventObjectiveCategory_Challenge or eCategory == PublicEventObjective.PublicEventObjectiveCategory_Optional then
				nTotal = nTotal + 1
				nPass = nPass + (bPass and 1 or 0)
			end
		end
	end

	-- Build and Resize Forms
	self.wndDungeonMedalsForm = Apollo.LoadForm(self.xmlDoc	, "DungeonMedalsForm", nil, self)
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsPassTitle"):SetText(String_GetWeaselString(Apollo.GetString("PublicEventStats_DungeonPassTitle"), tostring(nPass), tostring(nTotal)))
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsPassText"):SetAML(strPass)
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsPassText"):SetHeightToContentHeight()
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsPassScroll"):ArrangeChildrenVert(0)
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsNoPassMessage"):Show(nPass == 0)
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsNoPassMessage"):SetText(Apollo.GetString(karRandomFailStrings[math.random(1, #karRandomFailStrings)]) or "")

	self.wndDungeonMedalsForm:FindChild("DungeonMedalsFailTitle"):SetText(String_GetWeaselString(Apollo.GetString("PublicEventStats_DungeonFailTitle"), tostring(nTotal - nPass), tostring(nTotal)))
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsFailText"):SetAML(strFail)
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsFailText"):SetHeightToContentHeight()
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsFailScroll"):ArrangeChildrenVert(0)
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsNoFailMessage"):Show(nPass == nTotal)
	self.wndDungeonMedalsForm:FindChild("DungeonMedalsNoFailMessage"):SetText(Apollo.GetString(karRandomPassStrings[math.random(1, #karRandomPassStrings)]) or "")
end

-----------------------------------------------------------------------------------------------
-----    Helpers
-----------------------------------------------------------------------------------------------
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