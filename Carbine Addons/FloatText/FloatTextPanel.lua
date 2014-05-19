-----------------------------------------------------------------------------------------------
-- Client Lua Script for FloatTextPanel
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "DialogSys"
require "Quest"
require "QuestLib"
require "MailSystemLib"
require "Sound"
require "GameLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "CommunicatorLib"
require "Unit"
require "Spell"
require "CombatFloater"
require "Unit"
require "Challenges"
require "ChallengesLib"

local FloatTextPanel = {}
local kstrSubPanelFont = "CRB_InterfaceLarge_B"
local kstrSubPanelFontBacked = "CRB_InterfaceMedium"
local kcrQuestFontColor = "ffffffff"
local kcrPathFontColor = "ffff8000"
local kcrBodyFontColor = "ffffffff"
local kcrBodyFontColorBacked = "ff7fffb9"
local kfFirstMessageDelay = 0.75 -- how long do we want to stall the first floater; gives them time to amass and clear other notices
local kfFramerateRefreshRate = 0.1 -- how often do we update our framerate?

local kfMessageSpawnDelay = 1.85 --from the sprite
local kfMessageDespawnDelay = 0.26 --from the sprite

local karPathMissionLabels =
{
	Apollo.GetString("FloatText_SoldierMissionUnlocked"),
	Apollo.GetString("FloatText_SettlerMissionUnlocked"),
	Apollo.GetString("FloatText_ScientistMissionUnlocked"),
	Apollo.GetString("FloatText_ExplorerMissionUnlocked")
}

local karChallengeSprites =
{
	[ChallengesLib.ChallengeType_Combat] = "CRB_ChallengeTrackerSprites:sprChallengeTypeKillLarge",
	[ChallengesLib.ChallengeType_Ability] = "CRB_ChallengeTrackerSprites:sprChallengeTypeSkillLarge",
	[ChallengesLib.ChallengeType_General] = "CRB_ChallengeTrackerSprites:sprChallengeTypeGenericLarge",
	[ChallengesLib.ChallengeType_Item] = "CRB_ChallengeTrackerSprites:sprChallengeTypeLootLarge",
}

function FloatTextPanel:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function FloatTextPanel:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- FloatTextPanel OnLoad
-----------------------------------------------------------------------------------------------

function FloatTextPanel:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("FloatTextPanel.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function FloatTextPanel:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("Death", "OnDeath", self)
	Apollo.RegisterEventHandler("QuestInit", "OnQuestInit", self)
	Apollo.RegisterEventHandler("QuestFloater", "OnQuestNotice", self)
	Apollo.RegisterEventHandler("SettlerHubReward", "OnSettlerHubReward", self)
	Apollo.RegisterEventHandler("EpisodeStateChanged", "OnEpisodeStateChanged", self)
	Apollo.RegisterEventHandler("AchievementUpdated", "OnAchievementUpdated", self)
	Apollo.RegisterEventHandler("AlertAchievement", "OnAchievementNotice", self)
	Apollo.RegisterEventHandler("AlertTitle", "OnTitletNotice", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", "OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUpdate", "OnPlayerPathUpdated", self) -- specific mission update, send the mission
	Apollo.RegisterTimerHandler("FirstMessageDelaySub", "OnFirstMessageDelaySub", self)
	Apollo.RegisterTimerHandler("DelayAlertMain", "OnDelayAlertMain", self)
	Apollo.RegisterTimerHandler("DelayAlertMainAnim", "OnDelayAlertMainAnim", self)
	Apollo.RegisterTimerHandler("MessageTimerMain", "OnMessageTimerMain", self)
	Apollo.RegisterTimerHandler("MessageTimerMainDelay", "OnMessageTimerMainDelay", self)
	Apollo.RegisterTimerHandler("DelayExpiredMain", "OnDelayExpiredMain", self)
	Apollo.RegisterEventHandler("ToggleFramerate", "OnToggleFramerate", self)
	Apollo.RegisterTimerHandler("FramerateRefreshTimer", "OnFramerateRefreshTimer", self)
	Apollo.RegisterEventHandler("HintArrowDistanceUpdate", "OnHintArrowDistanceUpdate", self)

    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "FloaterPanel", nil, self)
	self.wndPrimaryParent = Apollo.LoadForm(self.xmlDoc, "FloaterPanelLower", nil, self)
	self.wndPrimary = self.wndPrimaryParent:FindChild("MainPanel")
	self.wndPrimaryParent:FindChild("Anim_OpenBurst"):SetSprite("")
	self.wndPrimaryParent:FindChild("Anim_CloseBurst"):SetSprite("")
	self.wndPrimaryParent:FindChild("Anim_MessageBacker"):SetSprite("")
	self.wndPrimary:Show(false)
	self.bShowingAlertMain = false

	self.tMainWindowDurations = {}
	self.tMainWindow =
	{
		self.wndPrimary:FindChild("MainContent_Episode"),
		self.wndPrimary:FindChild("MainContent_Zone"), -- DEPRECATED
		self.wndPrimary:FindChild("MainContent_Dead"),
		self.wndPrimary:FindChild("MainContent_Level"),
		self.wndPrimary:FindChild("MainContent_Settler"),
		self.wndPrimary:FindChild("MainContent_Path"),
		self.wndPrimary:FindChild("MainContent_PathEpisode"),
		self.wndPrimary:FindChild("MainContent_Achievement"),
		self.wndPrimary:FindChild("MainContent_ChallengeUnlock")
	}
	self.tMainWindowDurations =
	{
		4.000, -- durations for each message type; 1 is episode
		4.000, -- zone
		4.000, -- dead
		0.000, -- level
		8.000, -- Settler
		4.000, -- path level
		4.000, -- path ep completed
		4.500, -- Achievement unlocked
		4.000, -- challenge unlock
	}
	self.tQueueMain = {nFirst = 0, nLast = -1}

	self.wndSecondary = self.wndMain:FindChild("SubPanel")
	self.wndSecondary:Show(false)
	self.bShowingAlertSub = false
	self.tSubWindow = {}
	self.tSubWindowDurations = {}
	self.tSubWindow =
	{
		self.wndSecondary:FindChild("SubContent_Objective"),
		self.wndSecondary:FindChild("SubContent_Title"),
		self.wndSecondary:FindChild("SubContent_MissionUnlock"),
		self.wndSecondary:FindChild("SubContent_Mission"),
		self.wndSecondary:FindChild("SubContent_Mission"),
	}
	self.tSubWindowDurations =
	{
		2.8, -- quest objective
		3.8, -- title objective
		5.0, -- mission unlock
		5.0, -- mission advance
		5.0, -- mission complete
	}
	self.tQueueSub = {nFirst = 0, nLast = -1}

	-- maintain a table of completed missions so we don't double-up floaters (the UI will get two calls: 1. last progression 2. completion call)
	self.tCompletedMissions = {}
	self.bIsCharacterLoaded = GameLib.IsCharacterLoaded()
	self.iDisplayedTypeSub = 0 -- used to pass along what we're showing currently
	self.missionLastCompleted = nil

	self.bFirstMessageDelaySub = false
	self.bEmptyQueueSub = true

	self.wndFramerate = Apollo.LoadForm(self.xmlDoc, "FramerateDisplay", nil, self)
	self.wndFramerate:Show(false, true)

	Apollo.CreateTimer("FramerateRefreshTimer", kfFramerateRefreshRate, true)

	self.wndHintArrowDistance = Apollo.LoadForm(self.xmlDoc ,"HintArrowDistanceDisplay", nil, self)
	self.wndHintArrowDistance:Show(false, true)
	self.xmlDoc = nil
end

function FloatTextPanel:OnAdvanceErrorTimer()
	self.tErrors[3] = nil
	self.tErrors[3] = self.tErrors[2]
	self.tErrors[2] = self.tErrors[1]

	if self.tErrors[1] ~= nil then
		self.tErrors[1] = nil
	end

	local bStillQueued = false
	for idx = 1, 3 do
		if self.tErrors[idx] ~= nil then
			self.tErrorsWnd[idx]:SetText(self.tErrors[idx])
			bStillQueued = true
		else
			self.tErrorsWnd[idx]:SetText("")
		end
	end

	if bStillQueued == true then
		Apollo.CreateTimer("AdvanceErrorTimer", 0.10, false)
	end
end

function FloatTextPanel:OnQuestInit()
	self.bIsCharacterLoaded = true
end

function FloatTextPanel:OnEpisodeStateChanged(idEpisode, eOldState, eNewState)
	if not self.bIsCharacterLoaded or eNewState ~= Episode.EpisodeState_Active then
		return
	end

	local episodeCurr = QuestLib.GetEpisode(idEpisode)
	if episodeCurr and not episodeCurr:IsTaskOnly() then
		Event_FireGenericEvent("PopupText_ShowEpisodeAlert", episodeCurr:GetTitle())
		--self:AddToQueueMain(1, episode:GetTitle())
	end
end

function FloatTextPanel:OnDeath()
	self:AddToQueueMain(3, Apollo.GetString("Player_Dead"))
end

function FloatTextPanel:OnSettlerHubReward(strText)
	self:AddToQueueMain(5, strText)
end

function FloatTextPanel:OnAchievementNotice(strAchievement)
	self:AddToQueueMain(8, strAchievement)
end

function FloatTextPanel:OnAchievementUpdated(achUpdated)
	if self.tMainWindow and self.tMainWindow[8] then
		self.tMainWindow[8]:SetData(achUpdated)
	end
end

function FloatTextPanel:OnMainContent_AchievementMouseUp(wndHandler, wndControl)
	Event_FireGenericEvent("FloatTextPanel_ToggleAchievementWindow", wndHandler:GetData())
end

---------------------------------------------------------------------------------------------------
-- Primary Timer Structure
---------------------------------------------------------------------------------------------------

function FloatTextPanel:AddToQueueMain(eAlertType, strAlertString)
	local nLast = self.tQueueMain.nLast + 1
	self.tQueueMain.nLast = nLast
	self.tQueueMain[nLast] = {iType = eAlertType, strMessage = strAlertString}

	if not self.bShowingAlertMain then
		self:ProcessAlertsMain()
	end
end

function FloatTextPanel:ProcessAlertsMain()
	self:ClearFieldsMain()

	local nFirst = self.tQueueMain.nFirst
	if nFirst > self.tQueueMain.nLast then
		return
	end

	-- Delay for the sprite to draw
	self.wndPrimaryParent:FindChild("Anim_OpenBurst"):SetSprite("CRB_Anim_WindowBirth:Burst_Open")
	self.wndPrimaryParent:FindChild("Anim_MessageBacker"):SetSprite("CRB_Anim_WindowBirth:BracketOpen")
	Apollo.CreateTimer("DelayAlertMain", kfMessageSpawnDelay - 1.2, false) -- makes the text fade on sooner
	Apollo.CreateTimer("DelayAlertMainAnim", kfMessageSpawnDelay, false)
end

function FloatTextPanel:OnDelayAlertMain()
	local nFirst = self.tQueueMain.nFirst
	local t = self.tQueueMain[nFirst]
	self.tQueueMain[nFirst] = nil
	self.tQueueMain.nFirst = nFirst + 1

	self:DisplayAlertMain(t.iType, t.strMessage)
end

function FloatTextPanel:OnDelayAlertMainAnim()
	self.wndPrimaryParent:FindChild("Anim_MessageBacker"):SetSprite("CRB_Anim_WindowBirth:BracketLoop")
end

function FloatTextPanel:DisplayAlertMain(iType, strInfo)
	if iType == 6 or iType == 7 then -- Path notice
		if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Soldier then
			self.tMainWindow[iType]:FindChild("BackerSprite2"):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Soldier")
		elseif PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Settler then
			self.tMainWindow[iType]:FindChild("BackerSprite2"):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Colonist")
		elseif PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Explorer then
			self.tMainWindow[iType]:FindChild("BackerSprite2"):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Explorer")
		elseif PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Scientist then
			self.tMainWindow[iType]:FindChild("BackerSprite2"):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Scientist")
		else
			self.tMainWindow[iType]:FindChild("BackerSprite2"):SetSprite("")
		end
	end

	if iType == 8 then
		Sound.Play(Sound.PlayUIAchievementGranted)
	end

	if iType == 9 then
		local eChallengeType = strInfo:GetType()
		local strUnlockType = ""
		self.tMainWindow[iType]:FindChild("BackerSprite2"):SetSprite(karChallengeSprites[nChallengeType])

		if eChallengeType == ChallengesLib.ChallengeType_Combat then
			strUnlockType = Apollo.GetString("FloatText_CombatChallengeHeader")
		elseif eChallengeType == ChallengesLib.ChallengeType_Ability then
			strUnlockType = Apollo.GetString("FloatText_AbilityChallengeHeader")
		elseif eChallengeType == ChallengesLib.ChallengeType_General then
			strUnlockType = Apollo.GetString("FloatText_GeneralChallengeHeader")
		elseif eChallengeType == ChallengesLib.ChallengeType_Item then
			strUnlockType = Apollo.GetString("FloatText_ItemChallengeHeader")
		end

		self.tMainWindow[iType]:FindChild("Text2"):SetText(strUnlockType)

		strInfo = strInfo:GetName() -- convert to string for use below
	end

	self.bShowingAlertMain = true

	-- TODO REFACTOR
	self.wndPrimaryParent:Invoke()
	self.wndPrimary:Show(true)
	self.tMainWindow[iType]:Show(true)
	self.tMainWindow[iType]:FindChild("Text"):SetText(strInfo)

	self:StartMessageTimerMain(self.tMainWindowDurations[iType])
end

function FloatTextPanel:StartMessageTimerMain(fDuration) -- showing
	Apollo.CreateTimer("MessageTimerMain", fDuration, false)
end

function FloatTextPanel:OnMessageTimerMain() -- clear the text and still before running the clearing animation
	self.wndPrimary:Show(false)
	Apollo.CreateTimer("MessageTimerMainDelay", 0.500, false)
end

function FloatTextPanel:OnMessageTimerMainDelay() -- clearing animation, set the process delay
	self.wndPrimaryParent:FindChild("Anim_MessageBacker"):SetSprite("CRB_Anim_WindowBirth:BracketClose")
	Apollo.CreateTimer("DelayExpiredMain", kfMessageDespawnDelay, false)
end

function FloatTextPanel:OnDelayExpiredMain()
	self.wndPrimaryParent:FindChild("Anim_CloseBurst"):SetSprite("CRB_Anim_WindowBirth:Burst_Close")
	self.bShowingAlertMain = false
	self:ProcessAlertsMain()
end

function FloatTextPanel:OnToggleFramerate()
	self.wndFramerate:Show(not self.wndFramerate:IsShown())
end

function FloatTextPanel:OnFramerateRefreshTimer()
	if not self.wndFramerate:IsShown() then
		return
	end

	self.wndFramerate:SetText(math.floor(GameLib.GetFrameRate()*10)*0.1 .. " " .. Apollo.GetString("CRB_FPS"))
end

function FloatTextPanel:OnHintArrowDistanceUpdate(fDistance)
	local bShow = Apollo.GetConsoleVariable("ui.showHintArrowDistance") and fDistance ~= -1
	self.wndHintArrowDistance:Show(bShow, false, bShow and 0.1 or 0.3)

	if bShow then
		local strMeterAppended = String_GetWeaselString(Apollo.GetString("CRB_Distance"), math.max(1, math.floor(fDistance)))
		self.wndHintArrowDistance:SetText(fDistance == -1 and "" or strMeterAppended)
	end
end

function FloatTextPanel:ClearFieldsMain() --clear everything
	for i = 1, #self.tMainWindow do
		self.tMainWindow[i]:FindChild("Text"):SetText("")
		self.tMainWindow[i]:Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Secondary FloatTextPanelForm Functions
-----------------------------------------------------------------------------------------------

function FloatTextPanel:OnQuestNotice(unitTarget, strMessage, questCurr) -- uses a ML window
	local strWeasel = String_GetWeaselString(Apollo.GetString("FloatText_QuestNotice"), strMessage)
	local strFormatted = string.format("<P Font=\"%s\" Align=\"Center\" TextColor=\"%s\">%s</P>", kstrSubPanelFont, kcrBodyFontColor, strWeasel)

	local bMatch = false
	for idx, message in pairs(self.tQueueSub) do
		if type(message) == "table" then
			if questCurr ~= nil and message.iType == 1 and message.content ~= nil and questCurr:GetTitle() == message.content:GetTitle() then
				bMatch = true
				message.strMessage = strFormatted
			end
		end
	end

	if not bMatch then
		self:AddToQueueSub(1, strFormatted, questCurr)
	end
end

function FloatTextPanel:OnTitletNotice(strMessage)
	self:AddToQueueSub(2, strMessage)
end

function FloatTextPanel:OnPlayerPathMissionUnlocked(mission) -- uses a ML window
	local strMissionTitle = mission:GetName()
	local strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFontBacked, kcrBodyFontColorBacked, strMissionTitle)
	local strFormatted = string.format("<P Align=\"Center\">%s</P>", strBody)

	-- see if we already have unlock messages.
	local bMatch = false
	for idx, message in pairs(self.tQueueSub) do
		if type(message) == "table" then
			if message.iType == 3 then
				bMatch = true
				local strMultiple = "-- " .. Apollo.GetString("CRB_Several_New_Missions_Added") .. " --"
				strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFontBacked, kcrBodyFontColorBacked, strMultiple)
				strFormatted = string.format("<P Align=\"Center\">%s</P>", strBody)
				message.strMessage = strFormatted
				message.tContent = nil
			end
		end
	end

	if not bMatch then
		self:AddToQueueSub(3, strFormatted, mission)
	end
end


function FloatTextPanel:OnPlayerPathUpdated(mission) -- uses a ML window

	if mission:IsComplete() == true then -- we don't care about formatting if they're complete

		if self.tCompletedMissions[mission:GetName()] == true then -- TODO: Not key off the name...
			return -- we've already gotten a signal for this mission
		end

		self.tCompletedMissions[mission:GetName()] = true

		local strMissionTitle = mission:GetName()

		local strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrBodyFontColor, strMissionTitle)
		local strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_MissionCompleted"), strBody))
		local strFormatted = string.format("<P Align=\"Center\">%s</P>", strTitle)

		--self:AddToQueueSub(5, strFormatted, mission)
		self:HelperReplaceOrAddMission(5, strFormatted, mission, true)
	else

		-- Check/destroy other messages about this mission

		if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Soldier then
			self:PathUpdateMessageSoldier(mission)
		elseif PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Settler then
			self:PathUpdateMessageSettler(mission)
		elseif PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Scientist then
			self:PathUpdateMessageScientist(mission)
		elseif PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Explorer then
			self:PathUpdateMessageExplorer(mission)
		else
		end
	end
end

function FloatTextPanel:PathUpdateMessageSoldier(mission) -- uses a ML window
	local strMissionTitle = mission:GetName()
	local nNumNeeded = mission:GetNumNeeded()
	local nNumCompleted = mission:GetNumCompleted()
	local strTitle = ""
	local strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrBodyFontColor, String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), strMissionTitle, nNumCompleted, nNumNeeded))

	if nNumCompleted == 0 then -- mission was just activated
		return
	end

	if mission:GetType() == PathMission.PathMissionType_Soldier_Demolition then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_DemolitionMission"), strBody))
	elseif mission:GetType() == PathMission.PathMissionType_Soldier_Assassinate then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_AssassinateMission"), strBody))
	elseif mission:GetType() == PathMission.PathMissionType_Soldier_SWAT then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_SWATMission"), strBody))
	elseif mission:GetType() == PathMission.PathMissionType_Soldier_Rescue then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_RescueMission"), strBody))
	else
		return
	end

	local strFormatted = string.format("<P Align=\"Center\">%s</P>", strTitle)
	self:HelperReplaceOrAddMission(4, strFormatted, mission)
end

function FloatTextPanel:PathUpdateMessageSettler(mission) -- uses a ML window
	local strMissionTitle = mission:GetName()
	local nNumNeeded = mission:GetNumNeeded()
	local nNumCompleted = mission:GetNumCompleted()
	local strTitle = ""
	local strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrBodyFontColor, String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), strMissionTitle, nNumCompleted, nNumNeeded))

	if nNumCompleted == 0 then -- mission was just activated
		return
	end

	if mission:GetType() == PathMission.PathMissionType_Settler_Hub then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_HubMission"), strBody))
	elseif mission:GetType() == PathMission.PathMissionType_Settler_Infrastructure then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_InfrastructureMission"), strBody))
	else
		return
	end

	local strFormatted = string.format("<P Align=\"Center\">%s</P>", strTitle)
	self:HelperReplaceOrAddMission(4, strFormatted, mission)
end

function FloatTextPanel:PathUpdateMessageScientist(mission) -- uses a ML window
	
	local strMissionTitle = mission:GetName()
	local nNumNeeded = mission:GetNumNeeded()	-- a percent out of 100
	local nNumCompleted = mission:GetNumCompleted()	-- a percent out of 100
	local strTitle = ""
	local strBlankSpace = string.format("<T Font=\"%s\" TextColor=\"00ffffff\">%s</T>", kstrSubPanelFont, "-")
	local strCount = ""

	if nNumCompleted == 0 then -- mission was just activated; might not do this here since we're dealing in percents
		return
	end

	if mission:GetType() == PathMission.PathMissionType_Scientist_Scan then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, Apollo.GetString("FloatText_ScanMission"))
		strCount = String_GetWeaselString(Apollo.GetString("FloatText_MissionProgressPercent"), strMissionTitle, nNumCompleted)
	elseif mission:GetType() == PathMission.PathMissionType_Scientist_ScanChecklist then -- TODO: Number based after CPP change
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, Apollo.GetString("FloatText_ChecklistMission"))
		strCount = String_GetWeaselString(Apollo.GetString("FloatText_MissionProgressPercent"), strMissionTitle, nNumCompleted)
	elseif mission:GetType() == PathMission.PathMissionType_Scientist_FieldStudy then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, Apollo.GetString("FloatText_FieldStudy"))
		strCount = String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), strMissionTitle, nNumCompleted, nNumNeeded)
	elseif mission:GetType() == PathMission.PathMissionType_Scientist_SpecimenSurvey then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, Apollo.GetString("FloatText_SpecimenSurvey"))
		strCount = String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), strMissionTitle, nNumCompleted, nNumNeeded)
	else
		return
	end

	local strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrBodyFontColor, strCount)
	strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(strTitle, strBody))
	local strFormatted = string.format("<P Align=\"Center\">%s</P>", strTitle)
	self:HelperReplaceOrAddMission(4, strFormatted, mission)
end

function FloatTextPanel:PathUpdateMessageExplorer(mission)	 -- uses a ML window
	local strMissionTitle = mission:GetName()
	local nNumNeeded = mission:GetNumNeeded()
	local nNumCompleted = mission:GetNumCompleted()
	local strTitle = ""
	local strBlankSpace = string.format("<T Font=\"%s\" TextColor=\"00ffffff\">%s</T>", kstrSubPanelFont, "-")
	local strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrBodyFontColor, String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), strMissionTitle, nNumCompleted, nNumNeeded))

	if nNumCompleted == 0 then -- mission was just activated
		return
	end

	if mission:GetType() == PathMission.PathMissionType_Explorer_ActivateChecklist then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_ActivateChecklistMission"), strBody))
	elseif mission:GetType() == PathMission.PathMissionType_Explorer_Area then
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_ClaimMission"), strBody))
	elseif mission:GetType() == PathMission.PathMissionType_Explorer_ScavengerHunt then
		strBody = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrBodyFontColor, String_GetWeaselString(Apollo.GetString("FloatText_ScavengerProgress"), strMissionTitle, nNumCompleted, nNumNeeded))
		strTitle = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrSubPanelFont, kcrPathFontColor, String_GetWeaselString(Apollo.GetString("FloatText_ScavengerMission"), strBody))
	else
		return
	end

	local strFormatted = string.format("<P Align=\"Center\">%s</P>", strTitle)
	self:HelperReplaceOrAddMission(4, strFormatted, mission)
end

function FloatTextPanel:HelperReplaceOrAddMission(iType, strMessage, mission, bComplete)
	-- see if we already have a message about this mission. If we do, replace it with a later one.
	local bMatch = false
	for idx, message in pairs(self.tQueueSub) do
		if type(message) == "table" then
			if message.iType == 4 and message.tContent:GetName() == mission:GetName() then
				bMatch = true
				message.strMessage = strMessage
				if bComplete ~= nil and bComplete == true then
					-- replace with type 5
					message.iType = 5
				end
			end
		end
	end

	if not bMatch then
		self:AddToQueueSub(iType, strMessage, mission)
	end
end

---------------------------------------------------------------------------------------------------
-- Secondary Timer Structure
---------------------------------------------------------------------------------------------------

function FloatTextPanel:AddToQueueSub(iAlertType, strAlertString, tAlertContent)
	local t = {iType = iAlertType, strMessage = strAlertString, tContent = tAlertContent}
	local nLast = self.tQueueSub.nLast + 1
	self.tQueueSub.nLast = nLast
	self.tQueueSub[nLast] = t

	if self.bShowingAlertSub == true then
		return
	elseif self.bEmptyQueueSub then
		-- if the queue is empty, stall to let floaters amass
		Apollo.CreateTimer("FirstMessageDelaySub", kfFirstMessageDelay, false)
	elseif self.bFirstMessageDelaySub then -- if the delay is set, we'll get past this when the queue re-cycles
		self:ProcessAlertsSub()
	end
end

function FloatTextPanel:OnFirstMessageDelaySub() -- Delay if this is the first message to give floaters time to build
	self:ProcessAlertsSub()
	self.bFirstMessageDelaySub = false
end

function FloatTextPanel:ProcessAlertsSub()
	self:ClearFieldsSub()

	local nFirst = self.tQueueSub.nFirst
	if nFirst > self.tQueueSub.nLast then
		self.bEmptyQueueSub = true
		return
	end
	local t = self.tQueueSub[nFirst]
	self.tQueueSub[nFirst] = nil
	self.tQueueSub.nFirst = nFirst + 1

	self.bEmptyQueueSub = false

	self:DisplayAlertSub(t.iType, t.strMessage, t.tContent)
end

function FloatTextPanel:DisplayAlertSub(iType, strMessage, tContent)
	self.iDisplayedTypeSub = iType
	self.bShowingAlertSub = true

	if iType == 3 then
		Event_FireGenericEvent("PopupText_ShowPathAlert", strMessage, tContent)
	else
		self.wndSecondary:Invoke()
		self.tSubWindow[iType]:Invoke()
		self.tSubWindow[iType]:FindChild("Text"):SetText(strMessage)
	end

	self:StartMessageTimerSub(iType, tContent)
end

function FloatTextPanel:StartMessageTimerSub(iType, tContent)
	local fDuration = self.tSubWindowDurations[iType]

	Apollo.CreateTimer("MessageTimerSub", fDuration, false)

	if not self.SubMessageHandlerSet then
		Apollo.RegisterTimerHandler("MessageTimerSub", "OnMessageTimerSub", self)
		self.SubMessageHandlerSet = true
	end

	if iType == 3 then -- mission unlocked
		if tContent ~= nil then
			Event_FireGenericEvent("PlayerPath_NotificationSent", 1, tContent:GetName()) -- 1 is unlock signal
		else -- multiple missions
			Event_FireGenericEvent("PlayerPath_NotificationSent", 1, Apollo.GetString("CRB_Several_New_Missions_Added"))
		end
	end

	if iType == 5 then -- mission completed; 4 (progression) sends no signals
		self.missionLastCompleted = tContent
		if tContent ~= nil then
			Event_FireGenericEvent("PlayerPath_NotificationSent", 2, tContent:GetName()) -- 2 is completed signal
		else
			Event_FireGenericEvent("PlayerPath_NotificationSent", 2, "")
		end
	end
end

function FloatTextPanel:OnMessageTimerSub()
	self.wndSecondary:Show(false)
	Apollo.CreateTimer("DelayExpiredSub", 0.400, false)
	if not self.bDelayHandlerSetSub then
		Apollo.RegisterTimerHandler("DelayExpiredSub", "OnDelayExpiredSub", self)
		self.bDelayHandlerSetSub = true
	end
end

function FloatTextPanel:OnDelayExpiredSub()
	self.bShowingAlertSub = false

	if self.iDisplayedTypeSub == 5 then -- done showing completion notice; we want to remove it from the table
		self.tCompletedMissions[self.missionLastCompleted:GetName()] = nil -- cleanup our completed table
	end

	self:ProcessAlertsSub()
end

function FloatTextPanel:ClearFieldsSub() --clear everything
	self.iDisplayedTypeSub = 0
	self.missionLastCompleted = nil

	for i = 1, #self.tSubWindow do
		self.tSubWindow[i]:FindChild("Text"):SetText("")
		self.tSubWindow[i]:Show(false)
	end
end

local FloatTextPanelInst = FloatTextPanel:new()
FloatTextPanelInst:Init()
