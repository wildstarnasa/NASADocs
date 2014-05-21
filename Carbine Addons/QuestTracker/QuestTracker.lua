-----------------------------------------------------------------------------------------------
-- Client Lua Script for QuestTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "QuestLib"

local QuestTracker = {}
local tMinimized = {}
local knMaxZombieEventCount 	= 7
local knQuestProgBarFadeoutTime = 10
local kstrPublicEventMarker 	= "Public Event"
local ktNumbersToLetters		=
{
	Apollo.GetString("QuestTracker_ObjectiveA"),
	Apollo.GetString("QuestTracker_ObjectiveB"),
	Apollo.GetString("QuestTracker_ObjectiveC"),
	Apollo.GetString("QuestTracker_ObjectiveD"),
	Apollo.GetString("QuestTracker_ObjectiveE"),
	Apollo.GetString("QuestTracker_ObjectiveF"),
	Apollo.GetString("QuestTracker_ObjectiveG"),
	Apollo.GetString("QuestTracker_ObjectiveH"),
	Apollo.GetString("QuestTracker_ObjectiveI"),
	Apollo.GetString("QuestTracker_ObjectiveJ"),
	Apollo.GetString("QuestTracker_ObjectiveK"),
	Apollo.GetString("QuestTracker_ObjectiveL")
}
local karPathToString =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= Apollo.GetString("CRB_Soldier"),
	[PlayerPathLib.PlayerPathType_Settler] 		= Apollo.GetString("CRB_Settler"),
	[PlayerPathLib.PlayerPathType_Scientist] 	= Apollo.GetString("CRB_Scientist"),
	[PlayerPathLib.PlayerPathType_Explorer] 	= Apollo.GetString("CRB_Explorer")
}

local kstrRed 		= "ffff4c4c"
local kstrGreen 	= "ff2fdc02"
local kstrYellow 	= "fffffc00"
local kstrLightGrey = "ffb4b4b4"
local kstrHighlight = "ffffe153"

local ktConToColor =
{
	[0] 												= "ffffffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Grey] 		= "ff9aaea3",
	[Unit.CodeEnumLevelDifferentialAttribute.Green] 	= "ff37ff00",
	[Unit.CodeEnumLevelDifferentialAttribute.Cyan] 		= "ff46ffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Blue] 		= "ff3052fc",
	[Unit.CodeEnumLevelDifferentialAttribute.White] 	= "ffffffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Yellow] 	= "ffffd400", -- Yellow
	[Unit.CodeEnumLevelDifferentialAttribute.Orange] 	= "ffff6a00", -- Orange
	[Unit.CodeEnumLevelDifferentialAttribute.Red] 		= "ffff0000", -- Red
	[Unit.CodeEnumLevelDifferentialAttribute.Magenta] 	= "fffb00ff", -- Purp
}

local ktConToString =
{
	[0] 												= Apollo.GetString("Unknown_Unit"),
	[Unit.CodeEnumLevelDifferentialAttribute.Grey] 		= Apollo.GetString("QuestLog_Trivial"),
	[Unit.CodeEnumLevelDifferentialAttribute.Green] 	= Apollo.GetString("QuestLog_Easy"),
	[Unit.CodeEnumLevelDifferentialAttribute.Cyan] 		= Apollo.GetString("QuestLog_Simple"),
	[Unit.CodeEnumLevelDifferentialAttribute.Blue] 		= Apollo.GetString("QuestLog_Standard"),
	[Unit.CodeEnumLevelDifferentialAttribute.White] 	= Apollo.GetString("QuestLog_Average"),
	[Unit.CodeEnumLevelDifferentialAttribute.Yellow] 	= Apollo.GetString("QuestLog_Moderate"),
	[Unit.CodeEnumLevelDifferentialAttribute.Orange] 	= Apollo.GetString("QuestLog_Tough"),
	[Unit.CodeEnumLevelDifferentialAttribute.Red] 		= Apollo.GetString("QuestLog_Hard"),
	[Unit.CodeEnumLevelDifferentialAttribute.Magenta] 	= Apollo.GetString("QuestLog_Impossible")
}

local ktPvPEventTypes =
{
	[PublicEvent.PublicEventType_PVP_Arena] 					= true,
	[PublicEvent.PublicEventType_PVP_Warplot] 					= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Cannon] 		= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Vortex] 		= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Sabotage] 	= true,
	[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] 	= true,
}

function QuestTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function QuestTracker:Init()
    Apollo.RegisterAddon(self)
end

function QuestTracker:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("QuestTracker.xml")
	Apollo.RegisterEventHandler("InterfaceOptionsLoaded", 			"OnDocumentReady", self)
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function QuestTracker:OnDocumentReady()
	if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() or not g_InterfaceOptionsLoaded or self.wndMain then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementReady", 					"OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("WindowManagementUpdate", 					"OnWindowManagementUpdate", self)
	Apollo.RegisterEventHandler("OptionsUpdated_QuestTracker", 				"OnOptionsUpdated", self)

	self.tMinimized =
	{
		tQuests = {},
		tEpisode = {},
	}

	Apollo.RegisterTimerHandler("QuestTrackerBlinkTimer", 					"OnQuestTrackerBlinkTimer", self)

	Apollo.CreateTimer("QuestTrackerBlinkTimer", 4, false)
	Apollo.StopTimer("QuestTrackerBlinkTimer")

	-- Code events, mostly to remove completed/finished quests
	-- TODO: an event needs to wndQuest:FindChild("ObjectiveContainer"):DestroyChildren() when moving to complete/botched
	Apollo.RegisterEventHandler("EpisodeStateChanged", 						"DestroyAndRedraw", self)
	Apollo.RegisterEventHandler("QuestStateChanged", 						"OnQuestStateChanged", self)
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 					"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("GenericEvent_QuestLog_TrackBtnClicked", 	"OnDestroyQuestObject", self) -- This is an event from QuestLog
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 				"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterEventHandler("Communicator_ShowQuestMsg",				"OnShowCommMsg", self)

	-- Public Events
	Apollo.RegisterEventHandler("PublicEventEnd", 							"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventLeave", 						"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventStart", 						"OnPublicEventStart", self)
	Apollo.RegisterEventHandler("PublicEventObjectiveUpdate", 				"OnPublicEventUpdate", self)
	Apollo.RegisterEventHandler("PVPMatchFinished", 						"OnLeavePvP", self)
	Apollo.RegisterEventHandler("MatchExited", 								"OnLeavePvP", self)

	-- Formatting events
	Apollo.RegisterEventHandler("DatachronRestored", 						"OnDatachronRestored", self)
	Apollo.RegisterEventHandler("DatachronMinimized", 						"OnDatachronMinimized", self)
	Apollo.RegisterEventHandler("GenericEvent_ChallengeTrackerToggled", 	"OnGenericEvent_ChallengeTrackerToggled", self)
	Apollo.RegisterEventHandler("QuestLog_ToggleLongQuestText", 			"OnToggleLongQuestText", self)

	-- Checking Player Death (can't turn in quests if dead)
	Apollo.RegisterEventHandler("PlayerResurrected", 						"OnPlayerResurrected", self)
	Apollo.RegisterEventHandler("ShowResurrectDialog", 						"OnShowResurrectDialog", self)

	Apollo.RegisterTimerHandler("QuestTrackerRedrawTimer", 					"RedrawAll", self)
	Apollo.RegisterTimerHandler("OneSecTimer", 								"RedrawTimed", self)
	Apollo.RegisterTimerHandler("QuestTracker_EarliestProgBarTimer", 		"OnQuestTracker_EarliestProgBarTimer", self)
	
	Apollo.CreateTimer("QuestTrackerRedrawTimer", 0.2, false)
	Apollo.StopTimer("QuestTrackerRedrawTimer")

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "QuestTrackerForm", "FixedHudStratum", self)
	self.wndMain:SetSizingMinimum(345, 120)
	self.bMoveable = self.wndMain:IsStyleOn("Moveable")

	local unitPlayer = GameLib.GetPlayerUnit()
	self.bQuestTrackerByDistance 		= g_InterfaceOptions.Carbine.bQuestTrackerByDistance
	self.nQuestCounting 				= 0
	self.strPlayerPath 					= ""
	self.nFlashThisQuest 				= nil
	self.bPlayerIsDead 					= unitPlayer and unitPlayer:IsDead() or false
	self.bDrawPvPScreenOnly 			= false
	self.bDrawDungeonScreenOnly 		= false
	self.tZombiePublicEvents 			= {}
	self.tActiveProgBarQuests 			= {}
	self.ZombieTimerMax					= 120 -- Time it takes for a zombie PE to dissapear
	self.tClickBlinkingQuest			= nil
	self.tHoverBlinkingQuest			= nil
	self.bMaximized						= false
	self.bRedrawQueued					= false
	self.tQuestsQueuedForDestroy		= {}
	self.tPublicEventsToRedraw			= {}
	self.tTimedQuests					= {}
	self.tTimedObjectives				= {}
	self.tTimedEvents					= {}
	self.tTimedEventObjectives			= {}
	self.tQueuedCommMessages			= {}
	self.bChallengeVisible				= nil -- TODO: Challenges is firing the toggle event for basically any event that happens regardless of whether or not it toggled. Once this is fixed, we can remove this state storage var.
	
	self:InitializeWindowMeasuring()
	self:RedrawAll()
end

function QuestTracker:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("CRB_QuestTracker")})
end

function QuestTracker:OnWindowManagementUpdate(tSettings)
	local bOldHasMoved = self.bHasMoved
	local bOldMoveable = self.bMoveable
	
	if tSettings and tSettings.wnd and tSettings.wnd == self.wndMain then
		self.bMoveable = self.wndMain:IsStyleOn("Moveable")
		self.bHasMoved = tSettings.bHasMoved
		
		self.wndMain:FindChild("Background"):SetSprite(self.bMoveable and "BK3:UI_BK3_Holo_InsetFlyout" or "")
		self.wndMain:SetStyle("Sizable", self.bMoveable and self.bHasMoved)
	end
	
	if bOldHasMoved ~= self.bHasMoved then
		self:RedrawAll()
		
		if not bMaximized then
			self:OnDatachronMinimized(self.nDatachronShift)
		else
			self:OnDatachronRestored(self.nDatachronShift)
		end
	end
end

function QuestTracker:InitializeWindowMeasuring() -- Try not to run these OnLoad as they may be expensive
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "EpisodeGroupItem", nil, self)
	self.knInitialEpisodeGroupHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "EpisodeItem", nil, self)
	self.knInitialEpisodeHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "QuestItem", nil, self)
	self.knInitialQuestControlBackerHeight = wndMeasure:FindChild("ControlBackerBtn"):GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "QuestObjectiveItem", nil, self)
	self.knInitialQuestObjectiveHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "SpellItem", nil, self)
	self.knInitialSpellItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "EventItem", nil, self)
	self.knMinHeightEventItem = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	if self.strPlayerPath == "" then
		local ePlayPathType = PlayerPathLib.GetPlayerPathType()
		if ePlayPathType then
			self.strPlayerPath = karPathToString[ePlayerPathType]
		end
	end
end

function QuestTracker:OnOptionsUpdated()
	self.bQuestTrackerByDistance = g_InterfaceOptions.Carbine.bQuestTrackerByDistance
end

function QuestTracker:ResizeEpisodes()
	-- Sort
	local function HelperSortEpisodes(a,b)
		if a:FindChild("EpisodeTitle") and b:FindChild("EpisodeTitle") then
			return a:FindChild("EpisodeTitle"):GetData() < b:FindChild("EpisodeTitle"):GetData()
		elseif b:GetName() == "SwapToQuests" then
			return true
		end
		return false
	end

	for idx1, wndEpisodeGroup in pairs(self.wndMain:FindChild("QuestTrackerScroll"):GetChildren()) do
		if wndEpisodeGroup:GetName() == "EpisodeGroupItem" then
			-- Resize List
			self:OnResizeEpisodeGroup(wndEpisodeGroup)
			wndEpisodeGroup:FindChild("EpisodeGroupContainer"):ArrangeChildrenVert(0, HelperSortEpisodes)
		elseif wndEpisodeGroup:GetName() == "EpisodeItem" then
			-- Resize List
			self:OnResizeEpisode(wndEpisodeGroup)
			wndEpisodeGroup:FindChild("EpisodeQuestContainer"):ArrangeChildrenVert(0, HelperSortEpisodes)
		end
	end

	local nAlign = self.bHasMoved and 0 or 2
	
	self.wndMain:FindChild("QuestTrackerScroll"):ArrangeChildrenVert(nAlign, function(a,b)
		if a:GetName() == "EpisodeGroupItem" and b:GetName() == "EpisodeGroupItem" then
			return a:GetData() < b:GetData()
		elseif b:GetName() == "SwapToQuests" then
			return true
		end
		return false
	end)
end

function QuestTracker:OnQuestTrackerBlinkTimer()
	self.tClickBlinkingQuest:SetActiveQuest(false)
	self.tClickBlinkingQuest = nil

	if self.tHoverBlinkingQuest then
		self.tHoverBlinkingQuest:ToggleActiveQuest()
	end
end

-----------------------------------------------------------------------------------------------
-- Main Redraw Methods
-----------------------------------------------------------------------------------------------

function QuestTracker:QueueQuestForDestroy(queQuest)
	table.insert(self.tQuestsQueuedForDestroy, queQuest)
end

function QuestTracker:RequestRedrawAll()
	if not self.bRedrawQueued then
		self.bRedrawQueued = true
		Apollo.StartTimer("QuestTrackerRedrawTimer")
	end
end

function QuestTracker:DestroyAndRedraw()
	self.wndMain:FindChild("QuestTrackerScroll"):DestroyChildren()
	self.tPublicEventsToRedraw = {}
	self.tTimedQuests = {}
	self.tTimedObjectives = {}
	self.tTimedEvents = {}
	self.tTimedEventObjectives = {}
	self:RedrawAll()
end

function QuestTracker:RedrawTimed()
	for index, tEventInfo in pairs(self.tTimedEvents) do
		if tEventInfo.peEvent:IsActive() and tEventInfo.wndTitleFrame and tEventInfo.wndTitleFrame:IsValid() then
			local strTitle = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", kstrLightGrey, tEventInfo.peEvent:GetName())
			strTitle = self:HelperPrefixTimeString(math.max(0, math.floor((tEventInfo.peEvent:GetTotalTime() - tEventInfo.peEvent:GetElapsedTime()) / 1000)), strTitle)
			tEventInfo.wndTitleFrame:SetAML(strTitle)
		else
			table.remove(self.tTimedEvents, index)
		end
	end
	
	for index, tEventObjectiveInfo in pairs(self.tTimedEventObjectives) do
		if tEventObjectiveInfo.peEvent:IsActive() and tEventObjectiveInfo.wndObjective and tEventObjectiveInfo.wndObjective:IsValid() and tEventObjectiveInfo.wndObjective:FindChild("QuestObjectiveBtn") ~= nil then
			tEventObjectiveInfo.wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildEventObjectiveTitleString(tEventObjectiveInfo.peEvent, tEventObjectiveInfo.peoObjective, true))
			tEventObjectiveInfo.wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildEventObjectiveTitleString(tEventObjectiveInfo.peEvent, tEventObjectiveInfo.peoObjective))
		else
			table.remove(self.tTimedEventObjectives, index)
		end
	end

	if not self.bDrawPvPScreenOnly and not self.bDrawDungeonScreenOnly then
		for index, tQuestInfo in pairs(self.tTimedQuests) do
			if tQuestInfo.wndTitleFrame ~= nil then
				local strTitle = self:HelperBuildTimedQuestTitle(tQuestInfo.queQuest)
				tQuestInfo.wndTitleFrame:SetAML(strTitle)
			else
				table.remove(self.tTimedQuests, index)
			end
		end
		
		for index, tObjectiveInfo in pairs(self.tTimedObjectives) do
			if tObjectiveInfo.wndObjective ~= nil and tObjectiveInfo.wndObjective:FindChild("QuestObjectiveBtn") ~= nil then
				tObjectiveInfo.wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildObjectiveTitleString(tObjectiveInfo.queQuest, tObjectiveInfo.tObjective, true))
				tObjectiveInfo.wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildObjectiveTitleString(tObjectiveInfo.queQuest, tObjectiveInfo.tObjective))
			else
				table.remove(self.tTimedObjectives, index)
			end
		end
	end
end

function QuestTracker:RedrawAll()
	Apollo.StopTimer("QuestTrackerRedrawTimer")
	self.bRedrawQueued = false
	
	self:HelperFindAndDestroyQuests()
	
	if #self.tZombiePublicEvents > 0 then
		self:DrawPublicEpisodes()
	elseif #PublicEvent.GetActiveEvents() > 0 then
		self:DrawPublicEpisodes()
	elseif self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker) then
		-- Safety (should rarely fire): If we're out of events and the window is still around, switch views.
		self.bDrawDungeonScreenOnly = false
		self.bDrawPvPScreenOnly = false
		self:DestroyAndRedraw()
		return
	end

	if not self.bDrawPvPScreenOnly and not self.bDrawDungeonScreenOnly then
		local wndEpisodeGroup

		self.nQuestCounting = 0
		for idx, epiEpisode in pairs(QuestLib.GetTrackedEpisodes(self.bQuestTrackerByDistance)) do
			wndEpisodeGroup = nil
			if epiEpisode:IsWorldStory() then
				wndEpisodeGroup = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeGroupItem", "1EGWorld")
				wndEpisodeGroup:FindChild("EpisodeGroupTitle"):SetText(Apollo.GetString("QuestTracker_WorldStory"))
			elseif epiEpisode:IsZoneStory() then
				if GameLib.IsInWorldZone(epiEpisode:GetZoneId()) then
					wndEpisodeGroup = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeGroupItem", "2EGZone")
					wndEpisodeGroup:FindChild("EpisodeGroupTitle"):SetText(Apollo.GetString("QuestTracker_ZoneStory"))
				end
			elseif epiEpisode:IsRegionalStory() then
				if GameLib.IsInWorldZone(epiEpisode:GetZoneId()) then
					wndEpisodeGroup = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeGroupItem", "3EGRegional")
					wndEpisodeGroup:FindChild("EpisodeGroupTitle"):SetText(Apollo.GetString("QuestTracker_RegionalStory"))
				end
			else -- task
				local wndTaskGroup = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeGroupItem", "4EGTask")
				wndTaskGroup:FindChild("EpisodeGroupTitle"):SetText(Apollo.GetString("QuestTracker_Tasks"))

				self:DrawEpisodeQuests(epiEpisode, wndTaskGroup:FindChild("EpisodeGroupContainer"))
			end

			if wndEpisodeGroup ~= nil then
				self:DrawEpisode(idx, epiEpisode, wndEpisodeGroup:FindChild("EpisodeGroupContainer"))
			end
		end

		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("1EGWorld")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("2EGZone")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("3EGRegional")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("4EGTask")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
	end
	
	self:ResizeEpisodes()
end

function QuestTracker:DrawEpisode(idx, epiEpisode, wndParent)
	local wndEpisode = self:FactoryProduce(wndParent, "EpisodeItem", epiEpisode)
	wndEpisode:FindChild("EpisodeTitle"):SetData(idx) -- For sorting
	wndEpisode:FindChild("EpisodeMinimizeBtn"):SetData(epiEpisode:GetId())

	if self.tMinimized.tEpisode[epiEpisode:GetId()] then
		wndEpisode:FindChild("EpisodeMinimizeBtn"):SetCheck(true)
	end

	if wndEpisode:FindChild("EpisodeMinimizeBtn") and wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked() then
		wndEpisode:FindChild("EpisodeTitle"):SetText("> " .. epiEpisode:GetTitle())
		wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("8031fcf6"))

		-- Flash if we are told to
		if self.nFlashThisQuest then
			for key, queQuest in pairs(epiEpisode:GetTrackedQuests()) do
				self.nQuestCounting = self.nQuestCounting + 1
				if self.nFlashThisQuest == queQuest then
					self.nFlashThisQuest = nil
					wndEpisode:FindChild("EpisodeTitle"):SetSprite("sprTrk_ObjectiveUpdatedAnim")
				end
			end
		else
			for key, queQuest in pairs(epiEpisode:GetTrackedQuests()) do
				self.nQuestCounting = self.nQuestCounting + 1
			end
		end
	elseif wndEpisode:FindChild("EpisodeMinimizeBtn") then
		wndEpisode:FindChild("EpisodeTitle"):SetText(epiEpisode:GetTitle())
		wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("UI_BtnTextHoloNormal"))

		self:DrawEpisodeQuests(epiEpisode, wndEpisode:FindChild("EpisodeQuestContainer"))
	end
end

function QuestTracker:DrawEpisodeQuests(epiEpisode, wndContainer)
	for nIdx, queQuest in pairs(epiEpisode:GetTrackedQuests(0, self.bQuestTrackerByDistance)) do
		self.nQuestCounting = self.nQuestCounting + 1 -- TODO replace with nIdx or something eventually
		self:DrawQuest(self.nQuestCounting, queQuest, wndContainer)
	end

	-- Inline Sort Method
	local function SortQuestTrackerScroll(a, b)
		if not a or not b or not a:FindChild("QuestNumber") or not b:FindChild("QuestNumber") then return true end
		return (tonumber(a:FindChild("QuestNumber"):GetText()) or 0) < (tonumber(b:FindChild("QuestNumber"):GetText()) or 0)
	end

	wndContainer:ArrangeChildrenVert(0, SortQuestTrackerScroll)
end

function QuestTracker:DrawQuest(nIdx, queQuest, wndParent)
	local wndQuest = self:FactoryProduce(wndParent, "QuestItem", queQuest)
	
	if wndQuest:FindChild("QuestOpenLogBtn"):GetData() then
		return
	end
	
	-- Quest Title	
	local strTitle = queQuest:GetTitle()
	local eQuestState = queQuest:GetState()
	if eQuestState == Quest.QuestState_Botched then
		strTitle = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrRed, String_GetWeaselString(Apollo.GetString("QuestTracker_Failed"), strTitle))
	elseif eQuestState == Quest.QuestState_Achieved then
		strTitle = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrGreen,String_GetWeaselString(Apollo.GetString("QuestTracker_Complete"), strTitle))
	elseif (eQuestState == Quest.QuestState_Accepted or eQuestState == Quest.QuestState_Achieved) and queQuest:IsQuestTimed() then
		strTitle = self:HelperBuildTimedQuestTitle(queQuest)
		table.insert(self.tTimedQuests, { queQuest = queQuest, wndTitleFrame = wndQuest:FindChild("TitleText") })
	else
		local strColor = self.tActiveProgBarQuests[queQuest:GetId()] and "ffffffff" or kstrLightGrey
		local crLevelConDiff = ktConToColor[queQuest:GetColoredDifficulty() or 0]
		strTitle = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s </T><T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">[%s]</T>", strColor, strTitle, crLevelConDiff, queQuest:GetConLevel())
	end
	
	wndQuest:FindChild("TitleText"):SetAML(strTitle)
	wndQuest:FindChild("TitleText"):SetHeightToContentHeight()
		
	wndQuest:FindChild("QuestOpenLogBtn"):SetData(queQuest)
	wndQuest:FindChild("QuestCallbackBtn"):SetData(queQuest)
	wndQuest:FindChild("ControlBackerBtn"):SetData(wndQuest)
	wndQuest:FindChild("QuestCloseBtn"):SetData({["wndQuest"] = wndQuest, ["tQuest"] = queQuest})
	wndQuest:FindChild("MinimizeBtn"):SetData(queQuest:GetId())

	-- Flash if we are told to
	if self.nFlashThisQuest == queQuest then
		self.nFlashThisQuest = nil
		wndQuest:SetSprite("sprWinAnim_BirthSmallTemp")
	end

	if queQuest:GetId() and self.tMinimized.tQuests[queQuest:GetId()] then
		wndQuest:FindChild("MinimizeBtn"):SetCheck(true)
	end

	-- Quest spell
	if queQuest:GetSpell() then
		local wndSpellItem = self:FactoryProduce(wndQuest:FindChild("ObjectiveContainer"), "SpellItem", "SpellItem")
		wndSpellItem:FindChild("SpellItemBtn"):Show(true)
		wndSpellItem:FindChild("SpellItemBtn"):SetContentId(queQuest) -- GOTCHA: Normally we use the spell id, but here we use the quest object
		wndSpellItem:FindChild("SpellItemText"):SetText(String_GetWeaselString(Apollo.GetString("QuestTracker_UseQuestAbility"), GameLib.GetKeyBinding("CastObjectiveAbility")))
	end

	-- Conditional drawing
	wndQuest:FindChild("QuestNumberUpdateHighlight"):Show(self.tActiveProgBarQuests[queQuest:GetId()] ~= nil)
	wndQuest:FindChild("QuestNumber"):SetText(nIdx)
	wndQuest:FindChild("QuestNumber"):SetTextColor(ApolloColor.new("ff31fcf6"))
	wndQuest:FindChild("QuestCompletedBacker"):Show(false)
	wndQuest:FindChild("QuestNumberBackerArt"):SetBGColor(CColor.new(1,1,1,1))
	wndQuest:FindChild("QuestNumberBackerArt"):SetSprite("sprQT_NumBackerNormal")
	wndQuest:FindChild("ObjectiveContainer"):Show(not wndQuest:FindChild("MinimizeBtn"):IsChecked())

	-- State depending drawing
	if wndQuest:FindChild("MinimizeBtn"):IsChecked() then
		wndQuest:FindChild("QuestNumber"):SetTextColor(CColor.new(.5, .5, .5, .8))
		wndQuest:FindChild("QuestNumberBackerArt"):SetBGColor(CColor.new(.5, .5, .5, .8))

	elseif eQuestState == Quest.QuestState_Botched then
		self:HelperShowQuestCallbackBtn(wndQuest, queQuest, "sprQT_NumBackerFailed", "CRB_QuestTrackerSprites:btnQT_QuestFailed")
		wndQuest:FindChild("QuestNumber"):SetTextColor(ApolloColor.new(kstrRed))

	elseif eQuestState == Quest.QuestState_Achieved then
		self:HelperShowQuestCallbackBtn(wndQuest, queQuest, "sprQT_NumBackerCompleted", "CRB_QuestTrackerSprites:btnQT_QuestRedeem")
		wndQuest:FindChild("QuestNumber"):SetTextColor(ApolloColor.new("ff7fffb9"))

		-- Achieve objective only has one
		local wndObjective = self:FactoryProduce(wndQuest:FindChild("ObjectiveContainer"), "QuestObjectiveItem", "ObjectiveCompleted")
		wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildObjectiveTitleString(queQuest, tObjective, true))
		wndObjective:FindChild("QuestObjectiveBtn"):SetData({["queOwner"] = queQuest, ["nObjectiveIdx"] = nil})
		wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildObjectiveTitleString(queQuest))

	else
		-- Potentially multiple objectives if not minimized or in the achieved/botched state
		for idObjective, tObjective in pairs(queQuest:GetVisibleObjectiveData()) do
			if tObjective.nCompleted < tObjective.nNeeded then
				local wndObjective = self:FactoryProduce(wndQuest:FindChild("ObjectiveContainer"), "QuestObjectiveItem", idObjective)
				self:DrawQuestObjective(wndQuest, wndObjective, queQuest, tObjective)
				
				if queQuest:IsObjectiveTimed(tObjective.nIndex) then
					table.insert(self.tTimedObjectives, { queQuest = queQuest, tObjective = tObjective, wndObjective = wndObjective })
				end
			end
		end
	end

	wndQuest:FindChild("ObjectiveContainer"):ArrangeChildrenVert(0)
end

function QuestTracker:DrawQuestObjective(wndQuest, wndObjective, queQuest, tObjective)
	wndObjective:FindChild("QuestObjectiveBtn"):SetData({["queOwner"] = queQuest, ["nObjectiveIdx"] = tObjective.nIndex})
	wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildObjectiveTitleString(queQuest, tObjective, true))
	wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildObjectiveTitleString(queQuest, tObjective))

	-- Progress
	if self.tActiveProgBarQuests[queQuest:GetId()] and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
		local wndObjectiveProg = self:FactoryProduce(wndObjective, "QuestProgressItem", "QuestProgressItem")
		local nCompleted = tObjective.nCompleted
		local nNeeded = tObjective.nNeeded
		wndObjectiveProg:FindChild("QuestProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("QuestProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("QuestProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
	elseif wndObjective:FindChild("QuestProgressItem") then
		wndObjective:FindChild("QuestProgressItem"):Destroy()
		self:RedrawAll() -- TODO: this sucks, we trigger a redraw all while we're in the middle of already redrawing all
	end

	-- Objective Spell Item
	if queQuest:GetSpell(tObjective.nIndex) then
		local wndSpellBtn = self:FactoryProduce(wndObjective, "SpellItemObjectiveBtn", "SpellItemObjectiveBtn"..tObjective.nIndex)
		wndSpellBtn:SetContentId(queQuest, tObjective.nIndex)
	end
end

function QuestTracker:DrawPublicEpisodes()
	local tPublicEvents = PublicEvent.GetActiveEvents()
	if self.bDrawPvPScreenOnly or self.bDrawDungeonScreenOnly then
		self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
	elseif not self.wndMain:FindChild("SwapToPvP") and not self.wndMain:FindChild("SwapToDungeons") then
		for key, peEvent in pairs(tPublicEvents) do
			if not self.bDrawPvPScreenOnly and ktPvPEventTypes[peEvent:GetEventType()] then
				self.bDrawPvPScreenOnly = true
				self:DestroyAndRedraw()
				self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
				return
			end
			if not self.bDrawDungeonScreenOnly and peEvent:GetEventType() == PublicEvent.PublicEventType_Dungeon then
				self.bDrawDungeonScreenOnly = true
				self:DestroyAndRedraw()
				self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
				return
			end
		end
	end

	local wndEpisode = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeItem", kstrPublicEventMarker)
	wndEpisode:FindChild("EpisodeTitle"):SetData(-1) -- For sorting, will compare vs Quests

	if wndEpisode:FindChild("EpisodeMinimizeBtn") and wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked() then
		wndEpisode:FindChild("EpisodeTitle"):SetText("> " .. Apollo.GetString("QuestTracker_Events"))
		wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("8031fcf6"))
		return
	end

	wndEpisode:FindChild("EpisodeTitle"):SetText(Apollo.GetString("QuestTracker_Events"))
	wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("UI_BtnTextHoloNormal"))

	-- Events
	local nAlphabetNumber = 0
	for key, peEvent in pairs(tPublicEvents) do
		nAlphabetNumber	= nAlphabetNumber + 1
		self:DrawEvent(wndEpisode:FindChild("EpisodeQuestContainer"), peEvent, nAlphabetNumber)
	end

	-- Trim zombies to max size
	if #self.tZombiePublicEvents > knMaxZombieEventCount then
		table.remove(self.tZombiePublicEvents, 1)
	end

	-- Check Zombie Timer
	for key, tZombieEvent in pairs(self.tZombiePublicEvents) do
		tZombieEvent["nTimer"] = tZombieEvent["nTimer"] - 1
		if tZombieEvent["nTimer"] <= 0 then
			table.remove(self.tZombiePublicEvents, key)
			self:DestroyAndRedraw()
			return
		end
	end

	-- Now Draw Completed Events
	for key, tZombieEvent in pairs(self.tZombiePublicEvents) do
		nAlphabetNumber	= nAlphabetNumber + 1
		self:DrawZombieEvent(wndEpisode:FindChild("EpisodeQuestContainer"), tZombieEvent, nAlphabetNumber)
	end

	-- Inline Sort Method
	local function SortEventTrackerScroll(a, b)
		if not Window.is(a) or not Window.is(b) or not a:IsValid() or not b:IsValid() then
			return false
		end
		return a:FindChild("EventLetter"):GetText() < b:FindChild("EventLetter"):GetText()
	end

	wndEpisode:FindChild("EpisodeQuestContainer"):ArrangeChildrenVert(0, SortEventTrackerScroll)
end

function QuestTracker:DrawEvent(wndParent, peEvent, nAlphabetNumber)
	local wndEvent = self:FactoryProduce(wndParent, "EventItem", peEvent)
	
	if wndEvent:FindChild("ShowEventStatsBtn"):GetData() and not self.tPublicEventsToRedraw[peEvent:GetName()] then
		return
	end
	
	self.tPublicEventsToRedraw[peEvent:GetName()] = false
	wndEvent:FindChild("ShowEventStatsBtn"):SetData(peEvent)
	wndEvent:FindChild("QuestMouseCatcher"):SetData(wndEvent)

	-- Event Title
	local strTitle = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", kstrLightGrey, peEvent:GetName())
	if peEvent:GetTotalTime() > 0 and peEvent:IsActive() then
		strTitle = self:HelperPrefixTimeString(math.max(0, math.floor((peEvent:GetTotalTime() - peEvent:GetElapsedTime()) / 1000)), strTitle)
		table.insert(self.tTimedEvents, { peEvent = peEvent, wndTitleFrame = wndEvent:FindChild("TitleText") })
	end
	wndEvent:FindChild("TitleText"):SetAML(strTitle)
	wndEvent:FindChild("TitleText"):SetHeightToContentHeight()

	-- Conditional Drawing
	wndEvent:FindChild("EventStatsBacker"):Show(peEvent:HasLiveStats())
	wndEvent:FindChild("EventLetter"):SetText(ktNumbersToLetters[nAlphabetNumber])
	wndEvent:FindChild("EventLetter"):SetTextColor(ApolloColor.new("ff31fcf6"))
	wndEvent:FindChild("EventLetterBacker"):SetBGColor(CColor.new(1,1,1,1))

	if wndEvent:FindChild("MinimizeBtn"):IsChecked() then
		wndEvent:FindChild("EventLetter"):SetTextColor(CColor.new(.5, .5, .5, .8))
		wndEvent:FindChild("EventLetterBacker"):SetBGColor(CColor.new(.5, .5, .5, .8))
	else
		-- Draw the Objective, or delete if it's still around
		for idObjective, peoObjective in pairs(peEvent:GetObjectives()) do
			if peoObjective:GetStatus() == PublicEventObjective.PublicEventStatus_Active and not peoObjective:IsHidden() then
				local wndObjective = self:FactoryProduce(wndEvent:FindChild("ObjectiveContainer"), "QuestObjectiveItem", peoObjective)
				self:DrawEventObjective(wndObjective, peEvent, idObjective, peoObjective)
			elseif wndEvent:FindChild("ObjectiveContainer"):FindChildByUserData(peoObjective) then
				wndEvent:FindChild("ObjectiveContainer"):FindChildByUserData(peoObjective):Destroy()
			end
		end

		-- Inline Sort Method
		local function SortEventObjectivesTrackerScroll(a, b)
			if not Window.is(a) or not Window.is(b) or not a:IsValid() or not b:IsValid() or not a:GetData() or not b:GetData() then
				return false
			end
			return a:GetData():GetCategory() < b:GetData():GetCategory()
		end

		wndEvent:FindChild("ObjectiveContainer"):ArrangeChildrenVert(0, SortEventObjectivesTrackerScroll)
	end
end

function QuestTracker:DrawZombieEvent(wndParent, tZombieEvent, nAlphabetNumber)
	local wndEvent = self:FactoryProduce(wndParent, "ZombieEventItem", tZombieEvent.peEvent)
	wndEvent:FindChild("QuestCallbackBtn"):SetData(wndEvent)
	wndEvent:FindChild("QuestMouseCatcher"):SetData(wndEvent)

	-- Conditional Drawing
	wndEvent:FindChild("EventLetter"):SetText(ktNumbersToLetters[nAlphabetNumber])
	wndEvent:FindChild("EventLetterBacker"):SetBGColor("white")

	if wndEvent:FindChild("MinimizeBtn"):IsChecked() then
		wndEvent:FindChild("EventLetter"):SetTextColor(CColor.new(.5, .5, .5, .8))
		wndEvent:FindChild("EventLetterBacker"):SetBGColor(CColor.new(.5, .5, .5, .8))
	end

	-- Win or Loss formatting here
	local strTitle = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s</T>", tZombieEvent.peEvent:GetName())
	if tZombieEvent.eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteFailure then
		local strFailed = String_GetWeaselString(Apollo.GetString("QuestTracker_Failed"), strTitle)
		wndEvent:FindChild("EventLetter"):SetTextColor(ApolloColor.new(kstrRed))
		wndEvent:FindChild("EventLetterBacker"):SetSprite("sprQT_NumBackerFailedPE")
		wndEvent:FindChild("QuestCallbackBtn"):ChangeArt("CRB_QuestTrackerSprites:btnQT_QuestFailed")
		wndEvent:FindChild("TitleText"):SetAML(string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrRed, strFailed))

	elseif tZombieEvent.eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteSuccess then
		local strComplete = String_GetWeaselString(Apollo.GetString("QuestTracker_Complete"), strTitle)
		wndEvent:FindChild("EventLetter"):SetTextColor(ApolloColor.new(kstrGreen))
		wndEvent:FindChild("EventLetterBacker"):SetSprite("sprQT_NumBackerCompletedPE")
		wndEvent:FindChild("QuestCallbackBtn"):ChangeArt("CRB_QuestTrackerSprites:btnQT_QuestRedeem")
		wndEvent:FindChild("TitleText"):SetAML(string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrGreen, strComplete))
	end
end

function QuestTracker:DrawEventObjective(wndObjective, peEvent, idObjective, peoObjective)
	wndObjective:FindChild("QuestObjectiveBtn"):SetData({["peoObjective"] = peoObjective })
	wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildEventObjectiveTitleString(peEvent, peoObjective, true))
	wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildEventObjectiveTitleString(peEvent, peoObjective))

	if peoObjective:GetTotalTime() > 0 then
		table.insert(self.tTimedEventObjectives, { peEvent = peEvent, peoObjective = peoObjective, wndObjective = wndObjective })
	end
	
	-- Progress Bar
	if peoObjective:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_ContestedArea then
		local nPercent = peoObjective:GetContestedAreaRatio()
		if peoObjective:GetContestedAreaOwningTeam() == 0 then
			nPercent = (nPercent + 100.0) * 0.5
		end

		local wndObjectiveProg = self:FactoryProduce(wndObjective, "PublicProgressItem", "PublicProgressItem")
		wndObjectiveProg:FindChild("PublicProgressBar"):SetMax(100)
		wndObjectiveProg:FindChild("PublicProgressBar"):SetProgress(nPercent)
		wndObjectiveProg:FindChild("PublicProgressBar"):EnableGlow(false)
		wndObjectiveProg:FindChild("PublicProgressText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nPercent)))

	elseif peoObjective:ShowPercent() or peoObjective:ShowHealthBar() then
		local wndObjectiveProg = self:FactoryProduce(wndObjective, "PublicProgressItem", "PublicProgressItem")
		local nCompleted = peoObjective:GetCount()
		local nNeeded = peoObjective:GetRequiredCount()
		wndObjectiveProg:FindChild("PublicProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("PublicProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("PublicProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
		wndObjectiveProg:FindChild("PublicProgressText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nCompleted / nNeeded * 100)))
	end

	-- Objective Spell Item
	if peoObjective:GetSpell() then
		local wndSpellBtn = self:FactoryProduce(wndObjective, "SpellItemObjectiveBtn", idObjective)
		wndSpellBtn:SetContentId(peoObjective)
	end
end

function QuestTracker:OnShowCommMsg(idMsg, idCaller, queUpdated, strText)
	local tCommInfo = self.tQueuedCommMessages and self.tQueuedCommMessages[queUpdated:GetId()] or nil
	if tCommInfo then
		self:HelperShowQuestCallbackBtn(tCommInfo.wndQuest, tCommInfo.queQuest, tCommInfo.strNumberBackerArt, tCommInfo.strCallbackBtnArt)
	end
end

-----------------------------------------------------------------------------------------------
-- Main Resize Method
-----------------------------------------------------------------------------------------------

function QuestTracker:OnResizeEpisodeGroup(wndEpisodeGroup)
	local nOngoingGroupCount = self.knInitialEpisodeGroupHeight

	for idx, wndEpisode in pairs(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) do
		if wndEpisode:GetName() == "EpisodeItem" then
			nOngoingGroupCount = nOngoingGroupCount + self:OnResizeEpisode(wndEpisode)
		elseif wndEpisode:GetName() == "QuestItem" then
			nOngoingGroupCount = nOngoingGroupCount + self:OnResizeQuest(wndEpisode)
		end
	end

	local nLeft, nTop, nRight, nBottom = wndEpisodeGroup:GetAnchorOffsets()
	wndEpisodeGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOngoingGroupCount)
end

function QuestTracker:OnResizeEpisode(wndEpisode)
	local nOngoingTopCount = self.knInitialEpisodeHeight
	if not wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked() then
		for idx1, wndQuest in pairs(wndEpisode:FindChild("EpisodeQuestContainer"):GetChildren()) do
			nOngoingTopCount = nOngoingTopCount + self:OnResizeQuest(wndQuest)
		end
	end

	local nLeft, nTop, nRight, nBottom = wndEpisode:GetAnchorOffsets()
	wndEpisode:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOngoingTopCount)
	wndEpisode:FindChild("EpisodeQuestContainer"):Show(not wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked())
	return nOngoingTopCount
end

function QuestTracker:OnResizeQuest(wndQuest)
	local nQuestTextWidth, nQuestTextHeight = wndQuest:FindChild("TitleText"):SetHeightToContentHeight()
	local nResult = math.max(self.knInitialQuestControlBackerHeight, nQuestTextHeight + 4) -- for lower g height
	if wndQuest:FindChild("ControlBackerBtn") then
		local nLeft, nTop, nRight, nBottom = wndQuest:FindChild("ControlBackerBtn"):GetAnchorOffsets()
		wndQuest:FindChild("ControlBackerBtn"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nResult)
	end

	if wndQuest:FindChild("ObjectiveContainer") then -- Todo refactor
		local nLeft, nTop, nRight, nBottom = wndQuest:FindChild("ObjectiveContainer"):GetAnchorOffsets()
		wndQuest:FindChild("ObjectiveContainer"):SetAnchorOffsets(nLeft, nResult, nRight, nBottom)
		wndQuest:FindChild("ObjectiveContainer"):Show(not wndQuest:FindChild("MinimizeBtn"):IsChecked())
		wndQuest:FindChild("ObjectiveContainer"):ArrangeChildrenVert(0)
	end

	-- If expanded and valid, make it bigger
	if wndQuest:FindChild("ObjectiveContainer") and not wndQuest:FindChild("MinimizeBtn"):IsChecked() then
		for idx2, wndObj in pairs(wndQuest:FindChild("ObjectiveContainer"):GetChildren()) do
			local nObjTextHeight = self.knInitialQuestObjectiveHeight

			-- If there's the spell icon is bigger, use that instead
			if wndObj:FindChild("SpellItemObjectiveBtn") or wndObj:GetName() == "SpellItem" then
				nObjTextHeight = math.max(nObjTextHeight, self.knInitialSpellItemHeight)
			end

			-- If the text is bigger, use that instead
			if wndObj:FindChild("QuestObjectiveText") then
				local nLocalWidth, nLocalHeight = wndObj:FindChild("QuestObjectiveText"):SetHeightToContentHeight()
				nObjTextHeight = math.max(nObjTextHeight, nLocalHeight + 4) -- for lower g height

				-- Fake V-Align to match the button if it's just one line of text
				if wndObj:FindChild("SpellItemObjectiveBtn") and nLocalHeight < 20 then
					local nLeft, nTop, nRight, nBottom = wndObj:FindChild("QuestObjectiveText"):GetAnchorOffsets()
					wndObj:FindChild("QuestObjectiveText"):SetAnchorOffsets(nLeft, 9, nRight, nBottom)
				end
			end

			-- Also add extra height for Progress Bars
			if wndObj:FindChild("QuestProgressItem") then
				nObjTextHeight = nObjTextHeight + wndObj:FindChild("QuestProgressItem"):GetHeight()
			elseif wndObj:FindChild("PublicProgressItem") then
				nObjTextHeight = nObjTextHeight + wndObj:FindChild("PublicProgressItem"):GetHeight()
			end

			local nLeft, nTop, nRight, nBottom = wndObj:GetAnchorOffsets()
			wndObj:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nObjTextHeight)
			nResult = nResult + nObjTextHeight
		end
		wndQuest:FindChild("ObjectiveContainer"):ArrangeChildrenVert(0)
	elseif wndQuest:FindChild("ObjectiveContainer") then
		nResult = nResult + 4 -- Minimized needs +4
	end

	local nLeft, nTop, nRight, nBottom = wndQuest:GetAnchorOffsets()
	wndQuest:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(nResult, self.knMinHeightEventItem))
	return math.max(nResult, self.knMinHeightEventItem)
end

-----------------------------------------------------------------------------------------------
-- UI Interaction
-----------------------------------------------------------------------------------------------

function QuestTracker:OnQuestCloseBtn(wndHandler, wndControl) -- wndHandler is "QuestCloseBtn" and its data is { wndQuest, tQuest }
	local queQuest = wndHandler:GetData().tQuest
	queQuest:SetActiveQuest(false)

	if queQuest:GetState() == Quest.QuestState_Botched then
		queQuest:Abandon()
	else
		queQuest:ToggleTracked()
	end
	
	self:QueueQuestForDestroy(queQuest)
	self:RedrawAll()
end

function QuestTracker:OnMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	if wndHandler:GetData() then
		self.tMinimized.tQuests[wndHandler:GetData()] = true
	end

	self:RedrawAll()
end

function QuestTracker:OnMinimizedBtnUnChecked(wndHandler, wndControl, eMouseButton)
	if wndHandler:GetData() then
		self.tMinimized.tQuests[wndHandler:GetData()] = nil
	end

	self:RedrawAll()
end

function QuestTracker:OnEpisodeMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	if wndHandler:GetData() then
		self.tMinimized.tEpisode[wndHandler:GetData()] = true
	end

	self:RedrawAll()
end

function QuestTracker:OnEpisodeMinimizedBtnUnChecked(wndHandler, wndControl, eMouseButton)
	if wndHandler:GetData() then
		self.tMinimized.tEpisode[wndHandler:GetData()] = nil
	end

	self:RedrawAll()
end

function QuestTracker:OnQuestOpenLogBtn(wndHandler, wndControl) -- wndHandler should be "QuestOpenLogBtn" and its data is tQuest
	Event_FireGenericEvent("ShowQuestLog", wndHandler:GetData()) -- Codex (todo: deprecate this)
	Event_FireGenericEvent("GenericEvent_ShowQuestLog", wndHandler:GetData()) -- QuestLog
end

function QuestTracker:OnQuestCallbackBtn(wndHandler, wndControl) -- wndHandler is "QuestCallbackBtn" and its data is tQuest
	CommunicatorLib.CallContact(wndHandler:GetData())
end

function QuestTracker:OnShowEventStatsBtn(wndHandler, wndControl) -- wndHandler is "ShowEventStatsBtn" and its data is tEvent
	local peEvent = wndHandler:GetData() -- GOTCHA: Event Object is set up differently than the tZombieEvent table
	if peEvent and peEvent:HasLiveStats() then
		local tLiveStats = peEvent:GetLiveStats()
		Event_FireGenericEvent("GenericEvent_OpenEventStats", peEvent, peEvent:GetMyStats(), tLiveStats.arTeamStats, tLiveStats.arParticipantStats)
	end
end

function QuestTracker:OnEventCallbackBtn(wndHandler, wndControl) -- wndHandler is "QuestCallbackBtn" and its data is wndEvent
	local wndEvent = wndHandler:GetData()
	for idx, tZombieEvent in pairs(self.tZombiePublicEvents) do
		if tZombieEvent.peEvent and tZombieEvent.peEvent == wndEvent:GetData() then
			if tZombieEvent.peEvent:GetEventType() == PublicEvent.PublicEventType_WorldEvent then
				Event_FireGenericEvent("GenericEvent_OpenEventStatsZombie", tZombieEvent)
			end

			table.remove(self.tZombiePublicEvents, idx)
			self:DestroyAndRedraw()
			return
		end
	end
end

function QuestTracker:OnQuestHintArrow(wndHandler, wndControl, eMouseButton) -- wndHandler is "ControlBackerBtn" (can be from EventItem) and its data is wndQuest
	local wndQuest = wndHandler:GetData()

	if not wndQuest:FindChild("MinimizeBtn"):ContainsMouse() and (not wndQuest:FindChild("QuestCloseBtn") or not wndQuest:FindChild("QuestCloseBtn"):ContainsMouse()) then
		if eMouseButton == GameLib.CodeEnumInputMouse.Right and Apollo.IsShiftKeyDown() then
			Event_FireGenericEvent("GenericEvent_QuestLink", wndQuest:GetData())
		else
			wndQuest:GetData():ShowHintArrow()

			if self.tClickBlinkingQuest then
				Apollo.StopTimer("QuestTrackerBlinkTimer")
				self.tClickBlinkingQuest:SetActiveQuest(false)
			elseif self.tHoverBlinkingQuest then
				self.tHoverBlinkingQuest:SetActiveQuest(false)
			end

			if Quest.is(wndQuest:GetData()) then
				self.tClickBlinkingQuest = wndQuest:GetData()
				self.tClickBlinkingQuest:ToggleActiveQuest()
				Apollo.StartTimer("QuestTrackerBlinkTimer")
			end
		end
	end
end

function QuestTracker:OnQuestObjectiveHintArrow(wndHandler, wndControl, eMouseButton) -- "QuestObjectiveBtn" (can be from EventItem), data is { tQuest, tObjective.index }
	local tData = wndHandler:GetData()
	if tData and tData.peoObjective then
		tData.peoObjective:ShowHintArrow() -- Objectives do NOT default to parent if it fails
	elseif tData and tData.queOwner then
		tData.queOwner:ShowHintArrow(tData.nObjectiveIdx)

		if self.tClickBlinkingQuest then
			Apollo.StopTimer("QuestTrackerBlinkTimer")
			self.tClickBlinkingQuest:SetActiveQuest(false)
		elseif self.tHoverBlinkingQuest then
			self.tHoverBlinkingQuest:SetActiveQuest(false)
		end

		if Quest.is(tData.queOwner) then
			self.tClickBlinkingQuest = tData.queOwner
			self.tClickBlinkingQuest:ToggleActiveQuest()
			Apollo.StartTimer("QuestTrackerBlinkTimer")
		end
	end

	return true -- Stop Propagation so the Quest Hint Arrow won't eat this call
end

-----------------------------------------------------------------------------------------------
-- Mouse Enter/Exits
-----------------------------------------------------------------------------------------------

function QuestTracker:OnQuestItemMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:GetData() and Quest.is(wndHandler:GetData()) then
		self.tHoverBlinkingQuest = wndHandler:GetData()

		if self.tClickBlinkingQuest == nil then
			self.tHoverBlinkingQuest:ToggleActiveQuest()
		end
	end
end

function QuestTracker:OnQuestItemMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:GetData() and Quest.is(wndHandler:GetData()) then
		if self.tClickBlinkingQuest == nil and self.tHoverBlinkingQuest then
			self.tHoverBlinkingQuest:SetActiveQuest(false)
		end

		self.tHoverBlinkingQuest = nil
	end
end

function QuestTracker:OnQuestNumberBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("QuestNumberBackerGlow"):Show(true)
	end
end

function QuestTracker:OnQuestNumberBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("QuestNumberBackerGlow"):Show(false)
	end
end

function QuestTracker:OnControlBackerMouseEnter(wndHandler, wndControl) -- "ControlBackerBtn" of Quest or Event
	if wndHandler == wndControl then
		local wndQuest = wndHandler:GetData()
		local queQuest = wndQuest and wndQuest:GetData() or nil
		wndHandler:FindChild("MinimizeBtn"):Show(not queQuest or queQuest:GetState() ~= Quest.QuestState_Botched )
		if wndHandler:FindChild("QuestCloseBtn") then
			wndHandler:FindChild("QuestCloseBtn"):Show(true)
		end
	end
end

function QuestTracker:OnControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("MinimizeBtn"):Show(false)
		if wndHandler:FindChild("QuestCloseBtn") then
			wndHandler:FindChild("QuestCloseBtn"):Show(false)
		end
	end
end

function QuestTracker:OnEpisodeControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("EpisodeMinimizeBtn"):Show(true)
	end
end

function QuestTracker:OnEpisodeControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("EpisodeMinimizeBtn"):Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Code Events (mostly removing zombies)
-----------------------------------------------------------------------------------------------

function QuestTracker:OnShowResurrectDialog()
	unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self.bPlayerIsDead = unitPlayer:IsDead()
	end
end

function QuestTracker:OnPlayerResurrected()
	self.bPlayerIsDead = false
end

function QuestTracker:OnToggleLongQuestText(bToggle)
	self.bShowLongQuestText = bToggle
end

function QuestTracker:OnQuestStateChanged(queQuest, eState)
	if not self.wndMain then
		return
	end

	if eState == Quest.QuestState_Completed or eState == Quest.QuestState_Abandoned or eState == Quest.QuestState_Botched or eState == Quest.QuestState_Unknown then
		self:QueueQuestForDestroy(queQuest)
	else
		self.nFlashThisQuest = queQuest
	end

	self:RequestRedrawAll()
end

function QuestTracker:OnQuestObjectiveUpdated(queQuest, nObjective)
	if not queQuest or not queQuest:IsTracked() or queQuest:ObjectiveIsVisible(nObjective) == false then
		return
	end

	self.tActiveProgBarQuests[queQuest:GetId()] = os.clock()
	Apollo.CreateTimer("QuestTracker_EarliestProgBarTimer", knQuestProgBarFadeoutTime, false)
	-- GOTCHA: Apollo quirk, if you don't StopTimer before this, only the earliest is caught. So check and refire event in the handler.

	self:OnDestroyQuestObject(queQuest)
end

function QuestTracker:OnQuestTracker_EarliestProgBarTimer()
	-- GOTCHA: Apollo quirk, only the earliest is caught. So check and refire event if applicable.
	local nComparisonTime = os.clock()
	local nLowestTime = 9000
	for nCurrQuestId, nCurrTime in pairs(self.tActiveProgBarQuests) do
		if (nCurrTime + knQuestProgBarFadeoutTime) < (nComparisonTime + 1) then -- Plus one for safety
			self.tActiveProgBarQuests[nCurrQuestId] = nil
		else
			local nDifference = (nCurrTime + knQuestProgBarFadeoutTime) - nComparisonTime
			nLowestTime = nDifference < nLowestTime and nDifference or nLowestTime
		end
	end

	if nLowestTime ~= 9000 then
		Apollo.CreateTimer("QuestTracker_EarliestProgBarTimer", nLowestTime, false)
	end
end

function QuestTracker:OnDestroyQuestObject(queQuest)
	self.nFlashThisQuest = queQuest
	self:QueueQuestForDestroy(queQuest)
	self:RedrawAll()
end

function QuestTracker:OnDatachronRestored(nDatachronShift)
	self.nDatachronShift = nDatachronShift
	
	if not self.wndMain or self.bMaximized or self.bHasMoved then
		return
	end

	self.bMaximized = true

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nBottom - nDatachronShift)
	self:RedrawAll()
end

function QuestTracker:OnDatachronMinimized(nDatachronShift)
	self.nDatachronShift = nDatachronShift
	
	if not self.wndMain or not self.bMaximized or self.bHasMoved then
		return
	end

	self.bMaximized = false

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + nDatachronShift)
	self:RedrawAll()
end

function QuestTracker:OnGenericEvent_ChallengeTrackerToggled(bVisible)
	if not self.wndMain or self.bChallengeVisible == bVisible or self.bHasMoved then
		return
	end

	self.bChallengeVisible = bVisible
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, bVisible and 340 or 208, nRight, nBottom)
	self:RedrawAll()
end

-----------------------------------------------------------------------------------------------
-- Public Events
-----------------------------------------------------------------------------------------------

function QuestTracker:OnPublicEventStart(peEvent)
	-- Remove from zombie list if we're restarting it
	for idx, tZombieEvent in pairs(self.tZombiePublicEvents) do
		if tZombieEvent.peEvent == peEvent then
			self.tZombiePublicEvents[idx] = nil
			local wndPublicEvent = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker)
			if wndPublicEvent then
				local wndEvent = wndPublicEvent:FindChildByUserData(peEvent)
				if wndEvent then
					wndEvent:Destroy()
					self:OnEventDestroyed(peEvent)
				end
			end
			break
		end
	end
	self:RequestRedrawAll()
end

function QuestTracker:OnPublicEventEnd(peEvent, eReason, tStats)
	-- Add to list, or delete if we left the area
	if (eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteSuccess or eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteFailure)
	and peEvent:GetEventType() ~= PublicEvent.PublicEventType_SubEvent then
		table.insert(self.tZombiePublicEvents, {["peEvent"] = peEvent, ["eReason"] = eReason, ["tStats"] = tStats, ["nTimer"] = self.ZombieTimerMax})
	end

	-- Delete existing
	local wndPublicEvent = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker)
	if wndPublicEvent then
		local wndEvent = wndPublicEvent:FindChildByUserData(peEvent)
		if wndEvent then
			wndEvent:Destroy()
			self:OnEventDestroyed(peEvent)
		end
	end
	self:RequestRedrawAll()
end

function QuestTracker:OnPublicEventUpdate(tObjective)
	if tObjective:GetEvent() then
		self.tPublicEventsToRedraw[tObjective:GetEvent():GetName()] = true
		self:RequestRedrawAll()
	end
end

-----------------------------------------------------------------------------------------------
-- String Building
-----------------------------------------------------------------------------------------------

function QuestTracker:HelperShowQuestCallbackBtn(wndQuest, queQuest, strNumberBackerArt, strCallbackBtnArt)
	wndQuest:FindChild("QuestNumberBackerArt"):SetSprite(strNumberBackerArt)
	
	local tContactInfo = queQuest:GetContactInfo()
	
	if not queQuest:IsCommunicatorReceived() or queQuest:IsCommunicatorReceivedFromRec() then
		if not tContactInfo then
			self.tQueuedCommMessages[queQuest:GetId()] = {wndQuest = wndQuest, queQuest = queQuest, strNumberBackerArt = strNumberBackerArt, strCallbackBtnArt = strCallbackBtnArt}
			return
		else
			self.tQueuedCommMessages[queQuest:GetId()] = nil
		end
	end
	
	if not tContactInfo or not tContactInfo.strName or string.len(tContactInfo.strName) <= 0 then
		return
	end

	local strName = String_GetWeaselString(Apollo.GetString("QuestTracker_ContactName"), tContactInfo.strName)
	wndQuest:FindChild("QuestCompletedBacker"):Show(true)
	wndQuest:FindChild("QuestCallbackBtn"):ChangeArt(strCallbackBtnArt)
	wndQuest:FindChild("QuestCallbackBtn"):Enable(not self.bPlayerIsDead)
	wndQuest:FindChild("QuestCallbackBtn"):SetTooltip(string.format("<P Font=\"CRB_InterfaceMedium\">%s</P>", strName))
end

function QuestTracker:HelperBuildTimedQuestTitle(queQuest)
	local strTitle = queQuest:GetTitle()
	strTitle = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", kstrLightGrey, strTitle)
	strTitle = self:HelperPrefixTimeString(math.max(0, math.floor(queQuest:GetQuestTimeRemaining() / 1000)), strTitle)
	
	return strTitle
end

function QuestTracker:BuildObjectiveTitleString(queQuest, tObjective, bIsTooltip)
	local strResult = ""

	-- Early exit for completed
	if queQuest:GetState() == Quest.QuestState_Achieved then
		strResult = queQuest:GetCompletionObjectiveShortText()
		if bIsTooltip or self.bShowLongQuestText or not strResult or string.len(strResult) <= 0 then
			strResult = queQuest:GetCompletionObjectiveText()
		end
		return string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", strResult)
	end

	-- Use short form or reward text if possible
	local strShortText = queQuest:GetObjectiveShortDescription(tObjective.nIndex)
	if self.bShowLongQuestText or bIsTooltip then
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", tObjective.strDescription)
	elseif strShortText and string.len(strShortText) > 0 then
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", strShortText)
	end

	-- Prefix Optional or Progress if it hasn't been finished yet
	if tObjective.nCompleted < tObjective.nNeeded then
		local strPrefix = ""
		if tObjective and not tObjective.bIsRequired then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", Apollo.GetString("QuestLog_Optional"))
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		end

		-- Use Percent if Progress Bar
		if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
			local strColor = self.tActiveProgBarQuests[queQuest:GetId()] and kstrHighlight or "ffffffff"
			local strPercentComplete = String_GetWeaselString(Apollo.GetString("QuestTracker_PercentComplete"), tObjective.nCompleted)
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", strColor, strPercentComplete)
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		elseif tObjective.nNeeded > 1 then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s</T>", String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), tObjective.nCompleted, tObjective.nNeeded))
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		end
	end

	-- Prefix time for timed objectives
	if queQuest:IsObjectiveTimed(tObjective.nIndex) then
		strResult = self:HelperPrefixTimeString(math.max(0, math.floor(queQuest:GetObjectiveTimeRemaining(tObjective.nIndex) / 1000)), strResult)
	end

	return strResult
end

function QuestTracker:BuildEventObjectiveTitleString(queQuest, peoObjective, bIsTooltip)
	-- Use short form or reward text if possible
	local strResult = ""
	local strShortText = peoObjective:GetShortDescription()
	if strShortText and string.len(strShortText) > 0 and not bIsTooltip then
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", strShortText)
	else
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", peoObjective:GetDescription())
	end

	-- Progress Brackets and Time if Active
	if peoObjective:GetStatus() == PublicEventObjective.PublicEventStatus_Active then
		local nCompleted = peoObjective:GetCount()
		local eCategory = peoObjective:GetCategory()
		local eType = peoObjective:GetObjectiveType()
		local nNeeded = peoObjective:GetRequiredCount()

		-- Prefix Brackets
		local strPrefix = ""
		if nNeeded == 0 and (eType == PublicEventObjective.PublicEventObjectiveType_Exterminate or eType == PublicEventObjective.PublicEventObjectiveType_DefendObjectiveUnits) then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_Remaining"), nCompleted))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_DefendObjectiveUnits and not peoObjective:ShowPercent() and not peoObjective:ShowHealthBar() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_Remaining"), (nCompleted - nNeeded + 1)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_Turnstile then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_WaitingForMore"), math.abs(nCompleted - nNeeded)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_ParticipantsInTriggerVolume then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>",  String_GetWeaselString(Apollo.GetString("QuestTracker_WaitingForMore"), math.abs(nCompleted - nNeeded)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_TimedWin then
			-- Do Nothing
		elseif nNeeded > 1 and not peoObjective:ShowPercent() and not peoObjective:ShowHealthBar() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), nCompleted, nNeeded))
		end

		if strPrefix ~= "" then
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
			strPrefix = ""
		end

		-- Prefix Time
		if peoObjective:IsBusy() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s </T>", kstrYellow, Apollo.GetString("QuestTracker_Paused"))
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
			strPrefix = ""
		elseif peoObjective:GetTotalTime() > 0 then
			local strColorOverride = nil
			if peoObjective:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_TimedWin then
				strColorOverride = kstrGreen
			end
			strResult = self:HelperPrefixTimeString(math.max(0, math.floor((peoObjective:GetTotalTime() - peoObjective:GetElapsedTime()) / 1000)), strResult, strColorOverride)
		end

		-- Extra formatting
		if eCategory == PublicEventObjective.PublicEventObjectiveCategory_PlayerPath then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), self.strPlayerPath or Apollo.GetString("CRB_Path")))
		elseif eCategory == PublicEventObjective.PublicEventObjectiveCategory_Optional then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", Apollo.GetString("QuestTracker_OptionalTag"))
		elseif eCategory == PublicEventObjective.PublicEventObjectiveCategory_Challenge then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", Apollo.GetString("QuestTracker_ChallengeTag"))
		end

		if strPrefix ~= "" then
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		end
	end
	return strResult
end

-----------------------------------------------------------------------------------------------
-- PvP
-----------------------------------------------------------------------------------------------

function QuestTracker:OnLeavePvP()
	self.bDrawPvPScreenOnly = false
	if self.wndMain:FindChild("SwapToPvP") and self.wndMain:FindChild("SwapToPvP"):IsValid() then
		self.wndMain:FindChild("SwapToPvP"):Destroy()
	end
	if self.wndMain:FindChild("SwapToQuests") and self.wndMain:FindChild("SwapToQuests"):IsValid() then
		self.wndMain:FindChild("SwapToQuests"):Destroy()
	end
	self:DestroyAndRedraw()
end

function QuestTracker:OnSwapToPvPBtn() -- Also from code
	self.bDrawPvPScreenOnly = true
	if self.wndMain:FindChild("SwapToPvP") and self.wndMain:FindChild("SwapToPvP"):IsValid() then
		self.wndMain:FindChild("SwapToPvP"):Destroy()
	end
	self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
	self:DestroyAndRedraw()
end

function QuestTracker:OnSwapToDungeonsBtn() -- Also from code
	self.bDrawDungeonScreenOnly = true
	if self.wndMain:FindChild("SwapToDungeons") and self.wndMain:FindChild("SwapToDungeons"):IsValid() then
		self.wndMain:FindChild("SwapToDungeons"):Destroy()
	end
	self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
	self:DestroyAndRedraw()
end

function QuestTracker:OnSwapToQuestsBtn()
	if self.bDrawPvPScreenOnly then
		self.bDrawPvPScreenOnly = false
		self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToPvP", "SwapToPvP")
	end

	if self.bDrawDungeonScreenOnly then -- TODO investigate what happens when both are active
		self.bDrawDungeonScreenOnly = false
		self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToDungeons", "SwapToDungeons")
	end

	if self.wndMain:FindChild("SwapToQuests") and self.wndMain:FindChild("SwapToQuests"):IsValid() then
		self.wndMain:FindChild("SwapToQuests"):Destroy()
	end
	self:RedrawAll() -- GOTCHA: Don't destroy, we check for SwapToPvPBtn being valid later
end

function QuestTracker:OnGenerateTooltip(wndControl, wndHandler, eType, arg1, arg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemInstance then -- Doesn't need to compare to item equipped
		if Tooltip ~= nil and Tooltip.GetItemTooltipForm~= nil then
			Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
		end
	elseif eType == Tooltip.TooltipGenerateType_ItemData then -- Doesn't need to compare to item equipped
		if Tooltip ~= nil and Tooltip.GetItemTooltipForm~= nil then
			Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
		end
	elseif eType == Tooltip.TooltipGenerateType_GameCommand then
		xml = XmlDoc.new()
		xml:AddLine(arg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Macro then
		xml = XmlDoc.new()
		xml:AddLine(arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
		end
	elseif eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(arg2)
		wndControl:SetTooltipDoc(xml)
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function QuestTracker:HelperPrefixTimeString(fTime, strAppend, strColorOverride)
	local fSeconds = fTime % 60
	local fMinutes = fTime / 60
	local strColor = kstrYellow
	if strColorOverride then
		strColor = strColorOverride
	elseif fMinutes < 1 and fSeconds <= 30 then
		strColor = kstrRed
	end
	local strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">(%d:%.02d)</T>", strColor, fMinutes, fSeconds)
	return String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strAppend)
end

function QuestTracker:HelperFindAndDestroyQuests()
	if not #self.tQuestsQueuedForDestroy then
		return
	end
		
	for idx1, wndEpGroup in pairs(self.wndMain:FindChild("QuestTrackerScroll"):GetChildren()) do
		if wndEpGroup:GetName() == "EpisodeGroupItem" then
			for idx2, wndEp in pairs(wndEpGroup:FindChild("EpisodeGroupContainer"):GetChildren()) do
				for key, queQuest in pairs(self.tQuestsQueuedForDestroy) do
					if wndEp:GetName() == "EpisodeItem" then
						local wndQuest = wndEp:FindChild("EpisodeQuestContainer"):FindChildByUserData(queQuest)
						if wndQuest then
							wndQuest:Destroy()
	
							if wndEp:GetData() ~= kstrPublicEventMarker and next(wndEp:GetData():GetTrackedQuests()) == nil then
								wndEp:Destroy()
							end
	
							if next(wndEpGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
								wndEpGroup:Destroy()
							end
	
							table.remove(self.tQuestsQueuedForDestroy, key)
							if #self.tQuestsQueuedForDestroy == 0 then
								return
							end
							
							self:OnQuestDestroyed(queQuest)
						end
					elseif wndEp:GetName() == "QuestItem" and wndEp:GetData() == queQuest then
						wndEp:Destroy()
	
						if next(wndEpGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
							wndEpGroup:Destroy()
						end
	
						table.remove(self.tQuestsQueuedForDestroy, key)
						if #self.tQuestsQueuedForDestroy == 0 then
							return
						end
						
						self:OnQuestDestroyed(queQuest)
					end
				end
			end
		end
	end
	
	-- anything left in this list doesn't exist anymore
	self.tQuestsQueuedForDestroy = {}
end

function QuestTracker:OnQuestDestroyed(queQuest)
	for index, tQuestInfo in pairs(self.tTimedQuests) do
		if tQuestInfo.queQuest == queQuest then
			table.remove(self.tTimedQuests, index)
		end
	end
	
	for index, tObjectiveInfo in pairs(self.tTimedObjectives) do
		if tObjectiveInfo.queQuest == queQuest then
			table.remove(self.tTimedObjectives, index)
		end
	end
	
	self.tQueuedCommMessages[queQuest:GetId()] = nil
end

function QuestTracker:OnEventDestroyed(peEvent)
	for index, tEventInfo in pairs(self.tTimedEvents) do
		if tEventInfo.peEvent == peEvent then
			table.remove(self.tTimedEvents, index)
		end
	end
	
	for index, tEventObjectiveInfo in pairs(self.tTimedEventObjectives) do
		if tEventObjectiveInfo.peEvent == peEvent then
			table.remove(self.tTimedEventObjectives, index)
		end
	end
end

function QuestTracker:FactoryProduce(wndParent, strFormName, tObject)
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function QuestTracker:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.QuestTracker or eAnchor == GameLib.CodeEnumTutorialAnchor.QuestCommunicatorReceived then

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

local QuestTrackerInst = QuestTracker:new()
QuestTrackerInst:Init()
