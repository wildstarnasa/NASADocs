-----------------------------------------------------------------------------------------------
-- Client Lua Script for PathScientistContent
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "DialogSys"
require "Quest"
require "MailSystemLib"
require "Sound"
require "GameLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "ScientistScanBotProfile"

local PathScientistContent = {}

local karMissionTypeToFormattedString =
{
	[""]														= "", -- Valid error state
	[Apollo.GetString("ScientistMission_AnalysisKey")]			= Apollo.GetString("ScientistMission_Analysis"),
	[Apollo.GetString("ScientistMission_ArchaeologyKey")]		= Apollo.GetString("ScientistMission_Archaeology"),
	[Apollo.GetString("ScientistMission_BiologyKey")]			= Apollo.GetString("ScientistMission_Biology"),
	[Apollo.GetString("ScientistMission_BotanyKey")]			= Apollo.GetString("ScientistMission_Botany"),
	[Apollo.GetString("ScientistMission_CatalogKey")]			= Apollo.GetString("ScientistMission_Catalog"),
	[Apollo.GetString("ScientistMission_ChemistryKey")]			= Apollo.GetString("ScientistMission_Chemistry"),
	[Apollo.GetString("ScientistMission_DiagnosticsKey")]		= Apollo.GetString("ScientistMission_Diagnostics"),
	[Apollo.GetString("ScientistMission_ExperimentationKey")]	= Apollo.GetString("ScientistMission_Experimentation"),
	[Apollo.GetString("ScientistMission_FieldStudyKey")]		= Apollo.GetString("ScientistMission_FieldStudy"),
	[Apollo.GetString("ScientistMission_SpecimenSurveyKey")]	= Apollo.GetString("ScientistMission_SpecimenSurvey"),
}

--PlayerPath Constants
local PlayerPath = {}
local kstrListItemPercentStartTag 	= "<P Font=\"CRB_HeaderTiny\" TextColor=\"UI_TextHoloBodyHighlight\" Align=\"Center\">"
local kfPathRefreshTimer 			= 2.0
local kfNewMissionRunnerTimeout 	= 15 --the number of pulses of the above timer before the "New" runner clears by itself

local knSaveVersion = 1

function PathScientistContent:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.bAlreadySent = false

	return o
end

function PathScientistContent:Init()
	Apollo.RegisterAddon(self)
end

function PathScientistContent:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathScientistContent.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function PathScientistContent:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSave =
	{
		bSent = self.bAlreadySent,
		nSaveVersion = knSaveVersion,
	}

	return tSave
end

function PathScientistContent:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bAlreadySent = tSavedData.bSent
	end
end

function PathScientistContent:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("Datachron_LoadPathScientistContent", "OnLoadFromDatachron", self)
end

function PathScientistContent:OnLoadFromDatachron()
	if self.wndMain then -- stops double-loading
		return
	end

	Apollo.CreateTimer("PathUpdateTimer", kfPathRefreshTimer, true)

	Apollo.RegisterTimerHandler("PathUpdateTimer", 						"OnScientistPathUpdate", self)
	Apollo.RegisterTimerHandler("ScanBotCoolDownTimer", 				"OnScanBotCoolDownTimer", self)
	Apollo.RegisterTimerHandler("NotificationShowTimer", 				"OnNotificationShowTimer", self)
	Apollo.RegisterTimerHandler("NotificationHideTimer", 				"OnNotificationHideTimer", self)
	Apollo.RegisterTimerHandler("IncrementScanBotCoolDown", 			"OnIncrementScanBotCoolDown", self)

	Apollo.RegisterEventHandler("PlayerPathScientistScanData", 			"OnScientistScanData", self)
	Apollo.RegisterEventHandler("Datachron_TogglePathContent", 			"OnTogglePathContent", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 			"OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPath_NotificationSent", 			"MissionNotificationRecieved", self)
	Apollo.RegisterEventHandler("PlayerPathScientistScanBotCooldown", 	"OnPlayerPathScientistScanBotCooldown", self)
	Apollo.RegisterEventHandler("SubZoneChanged", 						"ClearMissionList", self)

	self.tFieldStudySubType =
	{
		[PathMission.Behavior_Sleep] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Sleeping",
		[PathMission.Behavior_Love] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Love",
		[PathMission.Behavior_Working] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Working",
		[PathMission.Behavior_Hunting] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Hunting",
		[PathMission.Behavior_Scared] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Scared",
		[PathMission.Behavior_Aggressive] 	= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Aggressive",
		[PathMission.Behavior_Food] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Hungry",
		[PathMission.Behavior_Happy] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Playful",
		[PathMission.Behavior_Singing] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Singing",
		[PathMission.Behavior_Injured] 		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Injured",
		[PathMission.Behavior_Guarding]		= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Guarding",
		[PathMission.Behavior_Socializing] 	= "ClientSprites:Icon_Windows_UI_CRB_FieldStudy_Social",
	}

	self.tNewMissions 		= {}
	self.bCompiling 		= false
	self.bShowingNotice 	= false

	self.wndMain 		= Apollo.LoadForm(self.xmlDoc, "ScientistDatachron", g_wndDatachron:FindChild("PathContainer"), self) -- The parent is the globally defined datachron
	self.wndTopLevel 	= Apollo.LoadForm(self.xmlDoc, "ScientistDatachronTopLevel", g_wndDatachron:FindChild("PathContainerTopLevel"), self)

	self:UpdateUITimer()
end

function PathScientistContent:ClearMissionList()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("MissionList"):DestroyChildren()
		self:OnCollapseChecklistClick()
		self:OnScientistPathUpdate()
	end
end

function PathScientistContent:UpdateUITimer()
	if self.wndMain:FindChild("ChecklistContainer"):IsShown() then
		self:PopulateChecklistContainer(self.wndMain:FindChild("ChecklistContainer"):GetData())
	else
		self:DrawBotButtons()
	end
end

function PathScientistContent:OnTogglePathContent(ePathType)
	if ePathType == PlayerPathLib.PlayerPathType_Scientist then
		self.wndMain:Show(true)
	else
		self.wndMain:Show(false)
	end
end

---------------------------------------------------------------------------------------------------
-- Mission Notifications (Unlocked, completed, episode completed)
---------------------------------------------------------------------------------------------------

function PathScientistContent:MissionNotificationRecieved(eType, strName)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndNotification = self.wndMain:FindChild("MissionNotification")
	if eType ~= 2 and self.bShowingNotice then
		return
	end

	if eType == 1 then -- Unlock notice
		wndNotification:FindChild("NewMissionContent"):FindChild("MissionName"):SetText("- " .. strName .. " -")
		wndNotification:FindChild("NewMissionContent"):Show(true)
	elseif eType == 2 then -- Completion notice
		self.wndMain:FindChild("MissionList"):DestroyChildren() -- Force a full redraw -- TODO: This should be moved elsewhere
		wndNotification:FindChild("CompletedMissionContent"):FindChild("MissionName"):SetText("- " .. strName .. " -")
		wndNotification:FindChild("CompletedMissionContent"):Show(true)
	end

	self.bShowingNotice = true
	--wndNotification:Show(true)
	Apollo.CreateTimer("NotificationShowTimer", 1.8, false)
end

function PathScientistContent:OnNotificationShowTimer()
	self.wndMain:FindChild("MissionNotification"):Show(false)
	Apollo.CreateTimer("NotificationHideTimer", 0.3, false)
end

function PathScientistContent:OnNotificationHideTimer()
	local wndNotification = self.wndMain:FindChild("MissionNotification")
	wndNotification:FindChild("NewMissionContent"):Show(false)
	wndNotification:FindChild("CompletedMissionContent"):Show(false)

	self.bShowingNotice = false
end

function PathScientistContent:OnPlayerPathMissionUnlocked(pmMission) -- new mission, so we want to add a runner
	local tMissionInfo =
	{
		pmMission 	= pmMission,
		nCount 		= 0,
	}
	table.insert(self.tNewMissions, tMissionInfo)

	self:OnScientistPathUpdate()
end

----------------------------------------------------------------------------------------
-- Scientist Events
----------------------------------------------------------------------------------------

function PathScientistContent:OnScientistScanData(tScannedUnits)
	if PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Scientist then
		return
	end

    if not self.tScannedItems then
        self.tScannedItems = {}
    end

    for idx, tScanInfo in ipairs(tScannedUnits) do
        tScanInfo.nDisplayCount = 0
        table.insert(self.tScannedItems, tScanInfo)
    end
end

function PathScientistContent:OnMouseEnter(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	if wndHandler:GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:HighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathScientistContent:OnMouseExit(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	if wndHandler:GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:UnhighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathScientistContent:OnPlayerPathScientistScanBotCooldown(fTime) -- iTime is cooldown time in MS (5250)
	fTime = math.max(1, fTime) -- TODO TEMP Lua Hack until fTime is valid
	Apollo.CreateTimer("ScanBotCoolDownTimer", fTime, false)

	Apollo.CreateTimer("IncrementScanBotCoolDown", fTime / 100, true)

	self.wndTopLevel:FindChild("BotCooldownBar"):Show(true)
	self.wndTopLevel:FindChild("BotCooldownBar"):SetData(0)
	self.wndTopLevel:FindChild("BotCooldownBar"):SetProgress(0)

	self.wndTopLevel:FindChild("SciProfileSummonBtn"):Enable(false)
end

function PathScientistContent:OnIncrementScanBotCoolDown()
	local nCurrent = math.min(1, self.wndTopLevel:FindChild("BotCooldownBar"):GetData())
	self.wndTopLevel:FindChild("BotCooldownBar"):SetMax(1)
	-- NOTE: these values aren't really derived and will have to be adjusted based on the bot's cooldown
	self.wndTopLevel:FindChild("BotCooldownBar"):SetProgress(nCurrent + 0.013)
	self.wndTopLevel:FindChild("BotCooldownBar"):SetData(nCurrent + 0.013)
end

function PathScientistContent:OnScanBotCoolDownTimer()
	Apollo.StopTimer("ScanBotCoolDownTimer")
	Apollo.StopTimer("IncrementScanBotCoolDown")
	Event_FireGenericEvent("ScanBotCooldownComplete")

	self.wndTopLevel:FindChild("BotCooldownBar"):Show(false)
	self.wndTopLevel:FindChild("SciProfileSummonBtn"):Enable(true)
end

---------------------------------------------------------------------------------------------------
-- Scientist
---------------------------------------------------------------------------------------------------

function PathScientistContent:OnScientistPathUpdate()
	self:UpdateUITimer()

	local pepCurrent = PlayerPathLib.GetCurrentEpisode()
	local tMissions = self:GetEpisodeSortedByDistance(pepCurrent)

	if not tMissions then
		self.wndMain:FindChild("MissionList"):Show(false)
		self.wndMain:FindChild("CompletedScreen"):Show(false)
		self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)
		return
	end

	-- Check for completion, return if the episode is done
	if pepCurrent:IsComplete() then
		local wndComplete = self.wndMain:FindChild("CompletedScreen")
		wndComplete:Show(true)
		wndComplete:FindChild("LootEpisodeBtn"):SetData(pepCurrent)
		--wndComplete:FindChild("LootEpisodeBtn"):Show(pepCurrent:HasPendingReward())
		--wndComplete:FindChild("LootBtnFraming"):Show(pepCurrent:HasPendingReward())
		wndComplete:FindChild("EpNameString"):SetText(pepCurrent:GetWorldZone())
		return
	else
		self.wndMain:FindChild("CompletedScreen"):Show(false)
	end

	-- Draw list items
	local nNumMissions = 0
	local nRemainingMissions = 0
	for idx, pmCurrMission in ipairs(tMissions) do
		if pmCurrMission:GetMissionState() == PathMission.PathMissionState_Unlocked or pmCurrMission:GetMissionState() == PathMission.PathMissionState_Started then
			nNumMissions = nNumMissions + 1
			local wndListItem = self:FactoryProduce(self.wndMain:FindChild("MissionList"), "ScientistListItem", pmCurrMission)
			self:DrawListItem(wndListItem, pmCurrMission)
		end

		if pmCurrMission:GetMissionState() == PathMission.PathMissionState_NoMission then
			nRemainingMissions = nRemainingMissions + 1
		end
	end

	-- Runner
	for idx, tMissionInfo in pairs(self.tNewMissions) do -- run our "new mission" table
		tMissionInfo.nCount = tMissionInfo.nCount + 1 -- iterate the count on all

		local wndListItem = self.wndMain:FindChild("MissionList"):FindChildByUserData(tMissionInfo.pmMission)
		if wndListItem then
			wndListItem:FindChild("ListItemNewRunner"):Show(tMissionInfo.nCount < kfNewMissionRunnerTimeout)
		end

		if tMissionInfo.nCount >= kfNewMissionRunnerTimeout then -- if beyond max pulse count, remove
			table.remove(self.tNewMissions, idx)
		end
	end

	local bDeeperScreensVisible = self.wndMain:FindChild("ChecklistContainer"):IsShown()
	if nNumMissions == 0 then
		self.wndMain:FindChild("MissionList"):Show(false)
		if nRemainingMissions > 0 then
			self.wndMain:FindChild("MissionsRemainingScreen"):Show(not bDeeperScreensVisible)
			self.wndMain:FindChild("MissionsRemainingScreen"):FindChild("MissionsRemainingCount"):SetText(nRemainingMissions)
			self.wndMain:FindChild("MissionsRemainingScreen"):FindChild("EpNameString"):SetText(pepCurrent:GetWorldZone())
		else
			self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)
		end
	else
		self.wndMain:FindChild("MissionList"):Show(not bDeeperScreensVisible)
		self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)

		if not self.bAlreadySent then
			Event_FireGenericEvent("GenericEvent_RestoreDatachron")
			self.bAlreadySent = true
		end
	end

	self.wndMain:FindChild("MissionList"):ArrangeChildrenVert()
end

function PathScientistContent:OnLocateBtn()
	local unitScanbot = PlayerPathLib:ScientistGetScanBotUnit()
	if unitScanbot then
		unitScanbot:ShowHintArrow()
	end
end

function PathScientistContent:TurnOffThenOn()
	Apollo.StopTimer("TurnOffThenOn")
	self.bCompiling = false
	PlayerPathLib.ScientistToggleScanBot()
end

---------------------------------------------------------------------------------------------------
-- Main Draw Method
---------------------------------------------------------------------------------------------------

function PathScientistContent:DrawListItem(wndListItem, pmDrawing)
	local nNumCompleted = pmDrawing:GetNumCompleted()
	local eType = pmDrawing:GetType()
	local strTooltip = pmDrawing:GetSummary()
	if string.len(strTooltip) <= 0 then
		strTooltip = pmDrawing:GetName()
	end

	wndListItem:SetData(pmDrawing)
	wndListItem:FindChild("ListIconBtn"):SetData(pmDrawing)
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmDrawing)
	wndListItem:FindChild("ListItemName"):SetText(pmDrawing:GetName())
	wndListItem:SetTooltip(string.format("<P Font=\"CRB_InterfaceMedium\">%s</P>", strTooltip))

	-- Adjust height to match text
	local nNameHeight = wndListItem:FindChild("ListItemName"):GetHeight()
	wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	if wndListItem:FindChild("ListItemName"):GetHeight() > nNameHeight then
	
		-- Adjust height of parent
		local nLeft,nTop,nRight,nBottom = wndListItem:GetAnchorOffsets()
		wndListItem:SetAnchorOffsets(nLeft,nTop,nRight,nBottom + wndListItem:FindChild("ListItemName"):GetHeight() - nNameHeight)
	end
	
	-- Icon Type
	local strScientistIcon = pmDrawing:GetScientistIcon()
	if eType == PathMission.PathMissionType_Scientist_Scan or eType == PathMission.PathMissionType_Scientist_ScanChecklist then
		local eSubType = pmDrawing:GetSubType()

		if eSubType == PathMission.ScientistCreatureType_Tech then
			strScientistIcon = "Icon_Mission_Scientist_ScanTech"
		elseif eSubType == PathMission.ScientistCreatureType_Flora then
			strScientistIcon = "Icon_Mission_Scientist_ScanPlant"
		elseif eSubType == PathMission.ScientistCreatureType_Fauna then
			strScientistIcon = "Icon_Mission_Scientist_ScanCreature"
		elseif eSubType == PathMission.ScientistCreatureType_Mineral then
			strScientistIcon = "Icon_Mission_Scientist_ScanMineral"
		end

	elseif eType == PathMission.PathMissionType_Scientist_FieldStudy then
		strScientistIcon = "Icon_Mission_Scientist_FieldStudy"
	elseif eType == PathMission.PathMissionType_Scientist_DatacubeDiscovery then
		strScientistIcon = "Icon_Mission_Scientist_DatachronDiscovery"
	elseif eType == PathMission.PathMissionType_Scientist_SpecimenSurvey then
		strScientistIcon = "Icon_Mission_Scientist_SpecimenSurvey"
	elseif eType == PathMission.PathMissionType_Scientist_Experimentation then
		strScientistIcon = "Icon_Mission_Scientist_ReverseEngineering"
	end

	wndListItem:FindChild("ListItemIcon"):SetSprite(strScientistIcon)
	-- Custom Formatting for progress bar missions
	if eType == PathMission.PathMissionType_Scientist_FieldStudy or eType == PathMission.PathMissionType_Scientist_SpecimenSurvey or eType == PathMission.PathMissionType_Scientist_DatacubeDiscovery then
		wndListItem:FindChild("ChecklistExpandBtn"):SetData(pmDrawing)
		wndListItem:FindChild("ListItemMeter"):SetMax(pmDrawing:GetNumNeeded())
		wndListItem:FindChild("ListItemMeter"):SetProgress(nNumCompleted)
		wndListItem:FindChild("ListItemPercent"):SetAML(string.format("%s%s</P>", kstrListItemPercentStartTag, String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nNumCompleted, pmDrawing:GetNumNeeded())))
	else
		wndListItem:FindChild("ListItemMeter"):SetMax(pmDrawing:GetNumNeeded())
		wndListItem:FindChild("ListItemMeter"):SetProgress(nNumCompleted)
		wndListItem:FindChild("ListItemPercent"):SetAML(string.format("%s%.0f", kstrListItemPercentStartTag, nNumCompleted) .. "%</P>")
	end
	wndListItem:FindChild("ChecklistExpandBtn"):Show(eType == PathMission.PathMissionType_Scientist_FieldStudy or eType == PathMission.PathMissionType_Scientist_SpecimenSurvey)


	-- TODO HACKISH to find the first entry to display a flash
	if not self.tScannedItems then
		return
	end

	local nUpdateCount = 0
	for idx = 1, #self.tScannedItems do
		local tScanData = self.tScannedItems[idx]
		if tScanData and tScanData.nDisplayCount > 3 then
			table.remove(self.tScannedItems, idx)
		end

		if tScanData and tScanData.strName == pmDrawing:GetName() then
			nUpdateCount = nUpdateCount + tScanData.nReceived
			tScanData.nDisplayCount = tScanData.nDisplayCount + 1

			if tScanData and tScanData.nDisplayCount == 1 then
				-- Flash for the first display iteration only
				wndListItem:FindChild("ListItemFlash"):SetSprite("ClientSprites:WhiteFlash")
			end
		end
	end


	if nUpdateCount > 0 then
		wndListItem:FindChild("ListItemPercent"):SetAML(string.format("<P Font=\"CRB_HeaderTiny\" TextColor=\"ffffffff\" Align=\"Center\">+%s", nUpdateCount) .. "%</P>")
	end
end

function PathScientistContent:DrawBotButtons()
	local bHasBot = PlayerPathLib.ScientistHasScanBot()
	local strScanBinding = ""
	if bHasBot then
		local unitBot = PlayerPathLib.ScientistGetScanBotUnit()
		if unitBot then
			self.wndTopLevel:FindChild("SciScannerBotHealth"):SetMax(unitBot:GetMaxHealth())
			self.wndTopLevel:FindChild("SciScannerBotHealth"):SetProgress(unitBot:GetHealth())
		end
		local strKeybind = GameLib.GetKeyBinding("PathAction")
		strScanBinding = strKeybind == "<Unbound>" and "" or "("..strKeybind..")"
	elseif self.wndTopLevel:FindChild("SciScannerBotStatus"):GetText() ~= Apollo.GetString("CRB_Compiling") then -- TODO String Comparison
		self.wndTopLevel:FindChild("SciScannerBotStatus"):SetText(Apollo.GetString("CRB_No_Scanner_Bot_Deployed"))
	end

	self.wndTopLevel:FindChild("SciScannerBotHealth"):Show(bHasBot)
	self.wndTopLevel:FindChild("SciScannerBotStatus"):Show(not bHasBot)
	self.wndTopLevel:FindChild("SciScanBtn"):SetText(String_GetWeaselString(Apollo.GetString("ScientistMission_ScanBtn"), strScanBinding))
	self.wndTopLevel:FindChild("SciScanBtn"):Enable(bHasBot and not self.bCompiling)
	self.wndTopLevel:FindChild("SciProfileSummonBtn"):Enable(not self.wndTopLevel:FindChild("BotCooldownBar"):IsShown())

	self.wndTopLevel:FindChild("SciLocateBtn"):Enable(bHasBot)
	self.wndTopLevel:FindChild("SciConfigureBtn"):Enable(true)
end

----------------------------------------------------------------------------------------
-- UI Buttons
----------------------------------------------------------------------------------------

function PathScientistContent:OnScanBtn()
	if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Scientist then
		PlayerPathLib.PathAction()
		self:UpdateUITimer() -- Update Button Text Immediately
	end
end

function PathScientistContent:HelperCloseAllWindows()
	self.wndMain:FindChild("MissionList"):Show(false)
	self.wndMain:FindChild("ChecklistContainer"):Show(false)
	self.wndTopLevel:FindChild("DatachronScientistBottom"):Show(false)
end

function PathScientistContent:OnOpenConfigureScreenBtn()
	Event_FireGenericEvent("GenericEvent_ToggleScanBotCustomize")
end

function PathScientistContent:OnExpandChecklistClick(wndHandler, wndControl) -- wndHandler is ChecklistExpandBtn and its data is a mission
	if not wndHandler or not wndHandler:GetData() then return end
	self:HelperCloseAllWindows()
	self.wndMain:FindChild("ChecklistContainer"):Show(true)
	self.wndMain:FindChild("ChecklistContainer"):SetData(wndHandler:GetData())
	self.wndMain:FindChild("ChecklistItemContainer"):DestroyChildren() -- TODO: Move this somewhere more appropriate
	self:UpdateUITimer()
end

function PathScientistContent:OnCollapseChecklistClick()
	self:HelperCloseAllWindows()
	self.wndMain:FindChild("MissionList"):Show(true)
	self.wndTopLevel:FindChild("DatachronScientistBottom"):Show(true)
	self:UpdateUITimer()
end

----------------------------------------------------------------------------------------
-- Control Panel and List Item Buttons
----------------------------------------------------------------------------------------

function PathScientistContent:OnSummonBotMouseEnter(wndHandler, wndControl)
	if PlayerPathLib.ScientistHasScanBot() then
		wndHandler:SetText(Apollo.GetString("ScientistMission_Dismiss"))
	else
		wndHandler:SetText(Apollo.GetString("ScientistMission_Summon"))
	end
end

function PathScientistContent:OnSummonBotMouseExit(wndHandler, wndControl)
	wndHandler:SetText("")
end

function PathScientistContent:OnSummonBotBtn(wndHandler, wndControl)
	local bHasBot = PlayerPathLib.ScientistHasScanBot()
	if bHasBot then
		self.wndTopLevel:FindChild("SciScannerBotStatus"):SetText(Apollo.GetString("CRB_No_Scanner_Bot_Deployed"))
		self:HelperCloseAllWindows()
		self.wndMain:FindChild("MissionList"):Show(true)
		self.wndTopLevel:FindChild("DatachronScientistBottom"):Show(true)
		self:UpdateUITimer()
	end

	self.wndTopLevel:FindChild("SciScanBtn"):Enable(not bHasBot)
	self.wndTopLevel:FindChild("SciLocateBtn"):Enable(not bHasBot)
	self.wndTopLevel:FindChild("SciConfigureBtn"):Enable(not bHasBot)

	PlayerPathLib.ScientistToggleScanBot() -- Summon the bot
end

function PathScientistContent:OnListItemClick(wndControl, wndHandler)
	if not wndHandler or wndHandler:GetId() ~= wndControl:GetId() then -- handler is "ListItemBigBtn" and its data should be a mission object
		return
	end

	local pmListData = wndHandler:GetData()
	if pmListData == nil then
		return
	end

	if wndHandler:FindChild("ListItemNewRunner"):IsShown() then -- "new" runner is visible
		wndHandler:FindChild("ListItemNewRunner"):Show(false)

		for idx, tMissionInfo in pairs(self.tNewMissions) do
			if pmListData == tMissionInfo.pmMission then
				table.remove(self.tNewMissions, idx)
			end
		end
	end

	pmListData:ShowHintArrow()
end

function PathScientistContent:OnListIconClick(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetId() ~= wndControl:GetId() then return end

	-- TODO Pass in argument to open to the right context
	local pmListData = wndControl:GetData()
	Event_FireGenericEvent("DatachronPanel_PlayerPathShow", pmListData)
	if wndControl:GetParent():FindChild("ListItemNewRunner"):IsShown() then -- "new" runner is visible
		wndControl:GetParent():FindChild("ListItemNewRunner"):Show(false)
		for idx, tMissionInfo in pairs(self.tNewMissions) do
			if pmListData == tMissionInfo.pmMission then
				table.remove(self.tNewMissions, idx)
			end
		end
	end

	return true	-- stop propagation
end

function PathScientistContent:OnListIconEnter(wndHandler, wndControl)
	if wndControl ~= wndHandler then return end
	--wndControl:FindChild("ListItemIconText"):SetText("?")
end

function PathScientistContent:OnListIconExit(wndHandler, wndControl)
	if wndControl ~= wndHandler then return end
	--wndControl:FindChild("ListItemIconText"):SetText("")
end

function PathScientistContent:OnLootEpisodeBtn(wndHandler, wndControl)
	if wndControl:GetData() then
		Event_FireGenericEvent("PlayerPath_EpisodeRewardsLootedDatachron")
	end
end

---------------------------------------------------------------------------------------------------
-- Field Study
---------------------------------------------------------------------------------------------------

function PathScientistContent:PopulateChecklistContainer(pmStudy)
	if not pmStudy then
		return
	end

	local tTableToUse = nil -- The two tables are set up the exact same
	local eMissionType = pmStudy:GetType()
	if eMissionType == PathMission.PathMissionType_Scientist_FieldStudy then
		tTableToUse = pmStudy:GetScientistFieldStudy()
	elseif eMissionType == PathMission.PathMissionType_Scientist_SpecimenSurvey then
		tTableToUse = pmStudy:GetScientistSpecimenSurvey()
	else
		return
	end

	local bAllItemsCompleted = true
	for idx, tDataTable in pairs(tTableToUse) do
		if tDataTable then
			local wndCurr = self:FactoryProduce(self.wndMain:FindChild("ChecklistItemContainer"), "ScientistChecklistItem", tDataTable.strName)
			if tDataTable.strName then
				wndCurr:FindChild("ChecklistItemName"):SetText(tDataTable.strName)
			end

			if tDataTable.bIsCompleted then
				wndCurr:FindChild("ChecklistCompleteCheck"):SetSprite("kitIcon_Complete")
			elseif eMissionType == PathMission.PathMissionType_Scientist_FieldStudy then
				wndCurr:FindChild("ScientistChecklistItemBtn"):Show(true)
				wndCurr:FindChild("ScientistChecklistItemBtn"):SetData({ pmStudy, idx })
				wndCurr:FindChild("ChecklistCompleteCheck"):SetSprite(self.tFieldStudySubType[tDataTable.eBehavior] or "kitIcon_InProgress")
				bAllItemsCompleted = false
			elseif eMissionType == PathMission.PathMissionType_Scientist_SpecimenSurvey then
				wndCurr:FindChild("ScientistChecklistItemBtn"):Show(true)
				wndCurr:FindChild("ScientistChecklistItemBtn"):SetData({ pmStudy, idx })
				wndCurr:FindChild("ChecklistCompleteCheck"):SetSprite("kitIcon_InProgress")
				bAllItemsCompleted = false
			end
		end
	end

	self.wndMain:FindChild("ChecklistTitle"):SetText(pmStudy:GetName())
	self.wndMain:FindChild("ChecklistItemContainer"):ArrangeChildrenVert(0)

	if bAllItemsCompleted then
		self:OnCollapseChecklistClick()
	end
end

function PathScientistContent:OnScientistChecklistItemBtn(wndHandler, wndControl)
	tMissionData = wndHandler:GetData()
	if tMissionData then
		local pmMission = tMissionData[1]
		local nIndex = tMissionData[2]

		pmMission:ShowPathChecklistHintArrow(nIndex)
	end
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function PathScientistContent:GetEpisodeSortedByDistance(pepCurrent)
	if not pepCurrent then
		return
	end

	local tMissions = pepCurrent:GetMissions()
	table.sort(tMissions, function(a, b) return a:GetDistance() < b:GetDistance() end)
    return tMissions
end

function PathScientistContent:FactoryProduce(wndParent, strFormName, tObject)
	local wndChild = wndParent:FindChildByUserData(tObject)
	if not wndChild then
		wndChild = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndChild:SetData(tObject)
	end
	return wndChild
end

local PathScientistContentInst = PathScientistContent:new()
PathScientistContentInst:Init()
