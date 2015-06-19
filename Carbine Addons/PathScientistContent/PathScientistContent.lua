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
local kstrLightGrey = "ffb4b4b4"
local kstrPathQuesttMarker = "90PathContent"
local kstrTrackerAddonName = "CRB_Scientist"

local karMissionTypeToFormattedString =
{
	[""]														= "", -- Valid error state
	[Apollo.GetString("ScientistMission_AnalysisKey")]			= Apollo.GetString("ScientistMission_Analysis"),
	[Apollo.GetString("ScientistMission_ArchaeologyKey")]		= Apollo.GetString("ScientistMission_Archaeology"),
	[Apollo.GetString("ScientistMission_BiologyKey")]			= Apollo.GetString("ScientistMission_Biology"),
	[Apollo.GetString("ScientistMission_BotanyKey")]			= Apollo.GetString("ScientistMission_Botany"),
	[Apollo.GetString("ScientistMission_CatalogKey")]			= Apollo.GetString("ScientistMission_Catalog"),
	[Apollo.GetString("ScientistMission_ChemistryKey")]			= Apollo.GetString("ScientistMission_Chemistry"),
	[Apollo.GetString("ScientistMission_DatacubeKey")]		= Apollo.GetString("ScientistMission_Datacube"),
	[Apollo.GetString("ScientistMission_DiagnosticsKey")]		= Apollo.GetString("ScientistMission_Diagnostics"),
	[Apollo.GetString("ScientistMission_ExperimentationKey")]	= Apollo.GetString("ScientistMission_Experimentation"),
	[Apollo.GetString("ScientistMission_FieldStudyKey")]		= Apollo.GetString("ScientistMission_FieldStudy"),
	[Apollo.GetString("ScientistMission_SpecimenSurveyKey")]	= Apollo.GetString("ScientistMission_SpecimenSurvey"),
}

--PlayerPath Constants
local PlayerPath = {}
local kfNewMissionRunnerTimeout 	= 15 --the number of pulses of the above timer before the "New" runner clears by itself

local knSaveVersion = 1

function PathScientistContent:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.bAlreadySent = false
	
	o.wndMain 			= nil
	o.tNewMissions 	= {}
	o.bCompiling 		= false
	o.bShowingNotice = false
	
	o.bShowOutOfZone = true
	o.bFilterLimit = true
	o.bFilterDistance = true
	o.bShowPathMissions = true
	o.nMaxMissionDistance = 0
	o.nMaxMissionLimit = 3

	return o
end

function PathScientistContent:Init()
	Apollo.RegisterAddon(self)
end

function PathScientistContent:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathScientistContent.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("SetPlayerPath", "OnSetPlayerPath", self)
end

function PathScientistContent:OnSetPlayerPath()
	if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Scientist then
		self:OnPathLoaded()
	elseif self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		
		local tData = {
			["strAddon"] = Apollo.GetString(kstrTrackerAddonName),
		}

		Event_FireGenericEvent("ObjectiveTracker_RemoveAddOn", tData)
	end
end

function PathScientistContent:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSave =
	{
		nSaveVersion = knSaveVersion,
		bSent = self.bAlreadySent,
		bMinimized = self.bMinimized,
		bMinimizedActive = self.bMinimizedActive,
		bMinimizedAvailable = self.bMinimizedAvailable,
		bMinimizedScanBot = self.bMinimizedScanBot,
		bShowPathMissions = self.bShowPathMissions,
		nMaxMissionDistance = self.nMaxMissionDistance,
		nMaxMissionLimit = self.nMaxMissionLimit,
		bShowOutOfZone = self.bShowOutOfZone,
		bFilterLimit = self.bFilterLimit,
		bFilterDistance = self.bFilterDistance,
	}

	return tSave
end

function PathScientistContent:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bAlreadySent = tSavedData.bSent
		self.bMinimized = tSavedData.bMinimized
		self.bMinimizedActive = tSavedData.bMinimizedActive
		self.bMinimizedAvailable = tSavedData.bMinimizedAvailable
		self.bMinimizedScanBot = tSavedData.bMinimizedScanBot
		
		if tSavedData.bShowPathMissions ~= nil then
			self.bShowPathMissions = tSavedData.bShowPathMissions
		end
		
		if tSavedData.nMaxMissionDistance ~= nil then
			self.nMaxMissionDistance = tSavedData.nMaxMissionDistance
		end
		
		if tSavedData.nMaxMissionLimit ~= nil then
			self.nMaxMissionLimit = tSavedData.nMaxMissionLimit
		end
		
		if tSavedData.bShowOutOfZone ~= nil then
			self.bShowOutOfZone = tSavedData.bShowOutOfZone
		end
		
		if tSavedData.bFilterLimit ~= nil then
			self.bFilterLimit = tSavedData.bFilterLimit
		end
		
		if tSavedData.bFilterDistance ~= nil then
			self.bFilterDistance = tSavedData.bFilterDistance
		end
	end
end

function PathScientistContent:OnDocumentReady()
	if self.xmlDoc == nil then return end
	
	self:OnPathLoaded()
end

function PathScientistContent:OnPathLoaded()
	if self.bPathLoaded then return end
	if self.xmlDoc == nil then return end
	if PlayerPathLib.GetPlayerPathType() == nil then return end	
	if PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Scientist then return end
	
	self.wndCheckList = Apollo.LoadForm(self.xmlDoc, "ScientistChecklistContainer", nil, self)
	
	Apollo.RegisterTimerHandler("ScanBotCoolDownTimer", 					"OnScanBotCoolDownTimer", self)
	Apollo.RegisterTimerHandler("NotificationShowTimer", 						"OnNotificationShowTimer", self)
	Apollo.RegisterTimerHandler("NotificationHideTimer", 						"OnNotificationHideTimer", self)
	Apollo.RegisterTimerHandler("IncrementScanBotCoolDown", 				"OnIncrementScanBotCoolDown", self)
	
	Apollo.RegisterEventHandler("PlayerPathScientistScanData", 			"OnScientistScanData", self)
	Apollo.RegisterEventHandler("PlayerPathScientistScanBotCooldown", 	"OnPlayerPathScientistScanBotCooldown", self)
	
	Apollo.RegisterEventHandler("Mount",												"DrawBotButtons", self)
	Apollo.RegisterEventHandler("PlayerPathScientistScanBotDeployed",		"DrawBotButtons", self)
	Apollo.RegisterEventHandler("PlayerPathScientistScanBotDespawned",	"DrawBotButtons", self)

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
	
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 		"OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", 	"OnPlayerPathMissionDeactivate", self)
	
	Apollo.RegisterEventHandler("ToggleShowPathMissions", 			"OnToggleShowPathMissions", self)
	Apollo.RegisterEventHandler("ToggleShowPathOptions", 			"DrawContextMenu", self)

	Apollo.RegisterEventHandler("ObjectiveTrackerLoaded", 			"OnObjectiveTrackerLoaded", self)
	
	Event_FireGenericEvent("ObjectiveTracker_RequestParent")
	self.bPathLoaded = true
end

function PathScientistContent:OnObjectiveTrackerLoaded(wndForm)
	if not wndForm or not wndForm:IsValid() then return end
	
	if self.wndMain and self.wndMain:IsValid() then
		Apollo.RemoveEventHandler("ObjectiveTrackerLoaded", self)
		return
	end
	
	if self.wndMain and self.wndMain:GetParent() == nil then
		self.wndActiveHeader:Destroy()
		self.wndActiveHeader = nil
		
		self.wndAvailableHeader:Destroy()
		self.wndAvailableHeader = nil
		
		self.wndTopLevel:Destroy()
		self.wndTopLevel = nil
		
		self.wndContainer:Destroy()
		self.wndContainer = nil
		
		self.wndMain:Destroy()
		self.wndMain = nil
	end
	
	if not self.wndMain then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "MissionList", wndForm, self)
		self.wndMain:SetData(kstrPathQuesttMarker) --QuestTracker sort index
	end
	
	if not self.wndContainer then
		self.wndContainer 		 = self:FactoryProduce(self.wndMain, "Container", "Container")
	end
	
	if not self.wndActiveHeader then
		self.wndActiveHeader = self:FactoryProduce(self.wndContainer:FindChild("Content"), "Category", "ActiveMissionsHeader")
	end
	
	if not self.wndAvailableHeader then
		self.wndAvailableHeader = self:FactoryProduce(self.wndContainer:FindChild("Content"), "Category", "AvailableMissionsHeader")
	end
	
	if not self.wndTopLevel then
		self.wndTopHeader	= self:FactoryProduce(self.wndContainer:FindChild("Content"), "Category", "ScanbotHeader")
		self.wndTopLevel 	= self:FactoryProduce(self.wndTopHeader:FindChild("Content"), "ScanbotContent", "ScanbotContent")
	end
	
	local tData = {
		["strAddon"]				= Apollo.GetString(kstrTrackerAddonName),
		["strEventMouseLeft"]	= "ToggleShowPathMissions", 
		["strEventMouseRight"]	= "ToggleShowPathOptions",
		["strIcon"]					= "spr_ObjectiveTracker_IconPathScientist",
		["strDefaultSort"]			= kstrPathQuesttMarker,
	}
	
	Apollo.RegisterEventHandler("ObjectiveTrackerUpdated", "OnPathUpdate", self)
	Event_FireGenericEvent("ObjectiveTracker_NewAddOn", tData)
	self:OnPathUpdate()
end

function PathScientistContent:UpdateUITimer()
	if self.wndCheckList and self.wndCheckList:IsValid() and self.wndCheckList:IsShown() then
		self:PopulateChecklistContainer(self.wndCheckList:GetData())
	end
	
	self:DrawBotButtons()
end

function PathScientistContent:OnPlayerPathMissionUnlocked(pmMission) -- new mission, so we want to add a runner
	local tMissionInfo =
	{
		pmMission 	= pmMission,
		nCount 		= 0,
	}
	
	table.insert(self.tNewMissions, tMissionInfo)
	self:OnPathUpdate()
end

----------------------------------------------------------------------------------------
-- Scientist Events
----------------------------------------------------------------------------------------

function PathScientistContent:OnScientistScanData(tScannedUnits)
	if not tScannedUnits then return end
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

function PathScientistContent:OnControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("MinimizeBtn"):Show(true)
	end
end

function PathScientistContent:OnControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		local wndBtn = wndHandler:FindChild("MinimizeBtn")
		wndBtn:Show(wndBtn:IsChecked())
	end
end

function PathScientistContent:OnMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	self.bMinimized 			= self.wndContainer:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedAvailable = self.wndAvailableHeader:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedActive	= self.wndActiveHeader:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedScanBot = self.wndTopHeader:FindChild("MinimizeBtn"):IsChecked()
	
	self:OnPathUpdate()
end

function PathScientistContent:OnPlayerPathScientistScanBotCooldown(fTime) -- iTime is cooldown time in MS (5250)
	if fTime == nil then return end
	
	fTime = math.max(1, fTime) -- TODO TEMP Lua Hack until fTime is valid
	Apollo.CreateTimer("ScanBotCoolDownTimer", fTime, false)

	Apollo.CreateTimer("IncrementScanBotCoolDown", fTime / 100, true)

	self.wndTopLevel:FindChild("BotCooldownBar"):Show(true)
	self.wndTopLevel:FindChild("BotCooldownBar"):SetData(0)
	self.wndTopLevel:FindChild("BotCooldownBar"):SetProgress(0)
	self.wndTopLevel:FindChild("SciProfileSummonBtn"):Enable(false)
	self.wndTopLevel:FindChild("SciProfileSummonBtn"):SetTooltip(Apollo.GetString("ScientistMission_Summon"))
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

function PathScientistContent:OnPathUpdate()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	self:UpdateUITimer()
	
	-- Inline Sort Method
	local function SortMissionItems(pmData1, pmData2) -- GOTCHA: This needs to be declared before it's used
		if g_InterfaceOptions and g_InterfaceOptions.Carbine.bQuestTrackerByDistance then
			return pmData1:GetDistance() < pmData2:GetDistance()
		else
			local aMissionType, aMissionName = unpack(self:HelperGetMissionName(pmData1:GetName()))
			local bMissionType, bMissionName = unpack(self:HelperGetMissionName(pmData2:GetName()))
		
			return aMissionName < bMissionName 
		end
	end

	local pepEpisode = PlayerPathLib.GetCurrentEpisode()
	local tFullMissionList = {}
	for _, pepAll in ipairs(PlayerPathLib.GetEpisodes()) do
		local tMissionList = pepAll and pepAll:GetMissions() or {}
		
		for _, pepCurrent in ipairs(tMissionList) do
			if not self.bShowOutOfZone and pepAll ~= pepEpisode then
				--Ignore out of zone missions.
			elseif pepCurrent:GetType() == PathMission.PathMissionType_Settler_Infrastructure and pepCurrent:IsComplete() and pepAll ~= pepEpisode then
				--Ignore out of zone Infrastructure missions.
			elseif pepCurrent:GetMissionState() == PathMission.PathMissionState_NoMission and pepAll ~= pepEpisode then
				--Ignore out of zone undiscovered missions.
			else
				table.insert(tFullMissionList, pepCurrent)
			end
		end
	end
	
	table.sort(tFullMissionList, SortMissionItems)

	self.wndActiveHeader:FindChild("Content"):DestroyChildren()
	self.wndAvailableHeader:FindChild("Content"):DestroyChildren()
	
	-- Draw list items
	local bThereIsAMission = false
	local nAvailableMissions = 0
	local nActiveMissions = 0
	local nRemainingMissions = 0
	for idx, pmCurrMission in ipairs(tFullMissionList) do
		if pmCurrMission:GetMissionState() == PathMission.PathMissionState_NoMission then
			nRemainingMissions = nRemainingMissions + 1
		elseif pmCurrMission:GetMissionState() == PathMission.PathMissionState_Unlocked or pmCurrMission:GetMissionState() == PathMission.PathMissionState_Started then
			if (not self.bFilterLimit or self.nMaxMissionLimit > nAvailableMissions + nActiveMissions) and (not self.bFilterDistance or pmCurrMission:GetDistance() < self.nMaxMissionDistance) then
				local bActive = pmCurrMission:GetNumCompleted() > 0
				local wndParent = bActive and self.wndActiveHeader:FindChild("Content") or self.wndAvailableHeader:FindChild("Content")
				local wndListItem = self:FactoryProduce(wndParent, "ListItem", pmCurrMission)
				self:DrawListItem(wndListItem, pmCurrMission)
				
				bThereIsAMission = true
				nAvailableMissions = bActive and nAvailableMissions or nAvailableMissions + 1
				nActiveMissions = bActive and nActiveMissions + 1 or nActiveMissions
			end
		end
	end
	
	-- Resize Containers
	self.wndTopHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedScanBot)
	self.wndTopHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedScanBot)
	self:OnResizeContainer(self.wndTopHeader)
	
	local strTitle = nRemainingMissions > 0 and string.format("%s [%s %s]", Apollo.GetString("ZoneCompletion_Scientist"), nRemainingMissions, Apollo.GetString("PlayerPath_Undiscovered")) or Apollo.GetString("ZoneCompletion_Scientist")
	self.wndContainer:FindChild("Title"):SetText(strTitle)
	self.wndContainer:FindChild("MinimizeBtn"):SetCheck(self.bMinimized)
	self.wndContainer:FindChild("MinimizeBtn"):Show(self.bMinimized)
	
	strTitle = nActiveMissions ~= 1 and string.format("%s [%s]", Apollo.GetString("ExplorerMissions_ActiveMissions"), nActiveMissions) or Apollo.GetString("ExplorerMissions_ActiveMissions")
	self.wndActiveHeader:Show(nActiveMissions > 0)
	self.wndActiveHeader:FindChild("Title"):SetText(strTitle)
	self.wndActiveHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedActive)
	self.wndActiveHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedActive)
	self:OnResizeContainer(self.wndActiveHeader)
	
	strTitle = nAvailableMissions ~= 1 and string.format("%s [%s]", Apollo.GetString("ExplorerMissions_AvailableMissions"), nAvailableMissions) or Apollo.GetString("ExplorerMissions_AvailableMissions")
	self.wndAvailableHeader:Show(nAvailableMissions > 0)
	self.wndAvailableHeader:FindChild("Title"):SetText(strTitle)
	self.wndAvailableHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedAvailable)
	self.wndAvailableHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedAvailable)
	self:OnResizeContainer(self.wndAvailableHeader)
	
	local nContainerHeight = self:OnResizeContainer(self.wndContainer)
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nContainerHeight)
	self.wndMain:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	self.wndMain:RecalculateContentExtents()

	-- Runner
	for idx, tMissionInfo in pairs(self.tNewMissions) do -- run our "new mission" table
		tMissionInfo.nCount = tMissionInfo.nCount + 1 -- iterate the count on all

		local wndListItem = self.wndMain:FindChildByUserData(tMissionInfo.pmMission)
		if wndListItem then
			wndListItem:GetParent():FindChild("ListItemNewRunner"):Show(tMissionInfo.nCount < kfNewMissionRunnerTimeout)
		end

		if tMissionInfo.nCount >= kfNewMissionRunnerTimeout then -- if beyond max pulse count, remove
			table.remove(self.tNewMissions, idx)
		end
	end

	local tData = {
		["strAddon"]	= Apollo.GetString(kstrTrackerAddonName),
		["strText"]		= nActiveMissions + nAvailableMissions,
		["bChecked"]	= self.bShowPathMissions,
	}

	Event_FireGenericEvent("ObjectiveTracker_UpdateAddOn", tData)
end

function PathScientistContent:OnResizeContainer(wndContainer)
	if not self.bShowPathMissions or not wndContainer or not wndContainer:IsValid() then
		return 0
	end
	
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, wndContainer:GetName(), nil, self)
	local nOngoingGroupHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()
	
	local wndContent = wndContainer:FindChild("Content")
	local wndMinimize = wndContainer:FindChild("MinimizeBtn")
	
	if wndMinimize and not wndMinimize:IsChecked() then
		for idx, wndChild in pairs(wndContent:GetChildren()) do
			if wndChild and wndChild:IsValid() and wndChild:IsShown() then
				nOngoingGroupHeight = nOngoingGroupHeight + wndChild:GetHeight()
			end
		end
	end
	
	local nLeft, nTop, nRight, nBottom = wndContainer:GetAnchorOffsets()
	wndContainer:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOngoingGroupHeight)
	wndContent:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	wndContent:RecalculateContentExtents()
	
	return nOngoingGroupHeight
end

function PathScientistContent:OnLocateBtn()
	local unitScanbot = PlayerPathLib:ScientistGetScanBotUnit()
	if unitScanbot then
		unitScanbot:ShowHintArrow()
	end
end

---------------------------------------------------------------------------------------------------
-- Main Draw Method
---------------------------------------------------------------------------------------------------

function PathScientistContent:DrawListItem(wndListItem, pmMission)
	local nNumCompleted = pmMission:GetNumCompleted()
	local strTooltip = pmMission:GetSummary()
	if string.len(strTooltip) <= 0 then
		strTooltip = pmMission:GetName()
	end
	
	local eType = pmMission:GetType()
	local strMissionType, strMissionName = unpack(self:HelperGetMissionName(pmMission:GetName()))
	
	wndListItem:SetData(pmMission)	
	wndListItem:FindChild("ListItemBig"):SetData(pmMission)
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemCodexBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemName"):SetText(strMissionName)
	wndListItem:SetTooltip(string.format("<P Font=\"CRB_InterfaceMedium\">%s</P>", strTooltip))

	-- Icon Type
	local strScientistIcon = pmMission:GetScientistIcon()
	if eType == PathMission.PathMissionType_Scientist_Scan or eType == PathMission.PathMissionType_Scientist_ScanChecklist then
		local eSubType = pmMission:GetSubType()

		if eSubType == PathMission.ScientistCreatureType_Tech then
			strScientistIcon = "Icon_Mission_Scientist_ScanTech"
		elseif eSubType == PathMission.ScientistCreatureType_Flora then
			strScientistIcon = "Icon_Mission_Scientist_ScanPlant"
		elseif eSubType == PathMission.ScientistCreatureType_Fauna then
			strScientistIcon = "Icon_Mission_Scientist_ScanCreature"
		elseif eSubType == PathMission.ScientistCreatureType_Mineral then
			strScientistIcon = "Icon_Mission_Scientist_ScanMineral"
		elseif eSubType == PathMission.ScientistCreatureType_Magic then
			strScientistIcon = "Icon_Mission_Scientist_ScanMagic"
		elseif eSubType == PathMission.ScientistCreatureType_History then
			strScientistIcon = "Icon_Mission_Scientist_ScanHistory"
		elseif eSubType == PathMission.ScientistCreatureType_Elemental then
			strScientistIcon = "Icon_Mission_Scientist_ScanElemental"
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
		wndListItem:FindChild("ListItemSubscreenBtn"):SetData(pmMission)
		wndListItem:FindChild("ListItemMeter"):SetMax(pmMission:GetNumNeeded())
		wndListItem:FindChild("ListItemMeter"):SetProgress(nNumCompleted)
		wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">(%s) %s</P>", String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nNumCompleted, pmMission:GetNumNeeded()), strMissionType))
	else
		wndListItem:FindChild("ListItemMeter"):SetMax(pmMission:GetNumNeeded())
		wndListItem:FindChild("ListItemMeter"):SetProgress(nNumCompleted)
		wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">(%.0f%%) %s</P>", nNumCompleted, strMissionType))
	end
	
	-- Resize
	local nWidth, nHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(nTop, nTop + nHeight + 32))

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

		if tScanData and tScanData.strName == pmMission:GetName() then
			nUpdateCount = nUpdateCount + tScanData.nReceived
			tScanData.nDisplayCount = tScanData.nDisplayCount + 1

			if tScanData and tScanData.nDisplayCount == 1 then
				-- Flash for the first display iteration only
				wndListItem:FindChild("ListItemFlash"):SetSprite("ClientSprites:WhiteFlash")
			end
		end
	end


	if nUpdateCount > 0 then
		wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_HeaderTiny\" TextColor=\"ffffffff\" Align=\"Center\">+%s", nUpdateCount) .. "%</P>")
	end
end

function PathScientistContent:DrawBotButtons()
	if not self.wndTopLevel or not self.wndTopLevel:IsValid() then
		return
	end
	
	local bHasBot = PlayerPathLib.ScientistHasScanBot()
	local bIsMounted = true
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		bIsMounted = unitPlayer:IsMounted()
	end
	
	local strKeybind = GameLib.GetKeyBinding("PathAction")
	local strScanBinding = strKeybind == "<Unbound>" and "" or "("..strKeybind..")" or ""
	local strAction = bHasBot and String_GetWeaselString(Apollo.GetString("ScientistMission_ScanBtn"), strScanBinding) or string.format("%s %s", Apollo.GetString("ScientistMission_Summon"), strScanBinding)
	
	local strTitle = string.format("%s: %s", Apollo.GetString("ScientistMission_ScanBot"), strAction)
	self.wndTopHeader:FindChild("Title"):SetText(strTitle)
	self.wndTopLevel:FindChild("SciScanBtn"):Show(bHasBot)
	self.wndTopLevel:FindChild("SciProfileSummonBtn"):Enable(not bIsMounted and not self.wndTopLevel:FindChild("BotCooldownBar"):IsShown())

	self.wndTopLevel:FindChild("SciLocateBtn"):Show(bHasBot)
	self.wndTopLevel:FindChild("SciConfigureBtn"):Show(bHasBot)
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

function PathScientistContent:OnOpenConfigureScreenBtn()
	Event_FireGenericEvent("GenericEvent_ToggleScanBotCustomize")
end

function PathScientistContent:OnListItemSubscreenBtn(wndHandler, wndControl) -- wndHandler is ListItemSubscreenBtn and its data is a mission
	if not wndHandler or not wndHandler:GetData() then return end
	self.wndCheckList:Show(true)
	self.wndCheckList:SetData(wndHandler:GetData())
	self.wndCheckList:FindChild("ChecklistItemContainer"):DestroyChildren() -- TODO: Move this somewhere more appropriate
	self:UpdateUITimer()
end

function PathScientistContent:OnCollapseChecklistClick()
	self.wndCheckList:Show(false)
	self:UpdateUITimer()
end

----------------------------------------------------------------------------------------
-- Control Panel and List Item Buttons
----------------------------------------------------------------------------------------

function PathScientistContent:OnSummonBotMouseEnter(wndHandler, wndControl)
	if PlayerPathLib.ScientistHasScanBot() then
		self.wndTopLevel:FindChild("SciProfileSummonBtn"):SetTooltip(Apollo.GetString("ScientistMission_Dismiss"))
	else
		self.wndTopLevel:FindChild("SciProfileSummonBtn"):SetTooltip(Apollo.GetString("ScientistMission_Summon"))
	end
end

function PathScientistContent:OnSummonBotMouseExit(wndHandler, wndControl)
	wndHandler:SetText("")
end

function PathScientistContent:OnSummonBotBtn(wndHandler, wndControl)
	PlayerPathLib.ScientistToggleScanBot()
end

function PathScientistContent:OnListItemMouseEnter(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	
	local pmMission = wndControl:GetParent():GetData()
	wndControl:GetParent():FindChild("ListItemSubscreenBtn"):Show(pmMission and (pmMission:GetType() == PathMission.PathMissionType_Scientist_FieldStudy or pmMission:GetType() == PathMission.PathMissionType_Scientist_SpecimenSurvey))
	
	if bHasMouse then
		Apollo.RemoveEventHandler("ObjectiveTrackerUpdated", self)
	end
end

function PathScientistContent:OnListItemMouseExit(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):SetBGOpacity(nOpacity)
	
	local pmMission = wndControl:GetParent():GetData()
	wndControl:GetParent():FindChild("ListItemSubscreenBtn"):Show(pmMission and (pmMission:GetType() == PathMission.PathMissionType_Scientist_FieldStudy or pmMission:GetType() == PathMission.PathMissionType_Scientist_SpecimenSurvey))
	
	if not bHasMouse then
		Apollo.RegisterEventHandler("ObjectiveTrackerUpdated",	"OnPathUpdate", self)
	end
end

function PathScientistContent:OnListItemHintArrow(wndControl, wndHandler)
	if not wndHandler or wndHandler:GetId() ~= wndControl:GetId() then -- handler is "ListItemBigBtn" and its data should be a mission object
		return
	end

	local pmListData = wndHandler:GetData()
	if pmListData == nil then
		return
	end

	if wndControl:GetParent():FindChild("ListItemNewRunner"):IsShown() then -- "new" runner is visible
		wndControl:GetParent():FindChild("ListItemNewRunner"):Show(false)

		for idx, tMissionInfo in pairs(self.tNewMissions) do
			if pmListData == tMissionInfo.pmMission then
				table.remove(self.tNewMissions, idx)
			end
		end
	end

	pmListData:ShowHintArrow()
end

function PathScientistContent:OnListItemOpenCodex(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetId() ~= wndControl:GetId() then return end

	-- TODO Pass in argument to open to the right context
	local pmListData = wndControl:GetData()
	Event_FireGenericEvent("DatachronPanel_PlayerPathShow", pmListData)
	if wndControl:GetParent():GetParent():FindChild("ListItemNewRunner"):IsShown() then -- "new" runner is visible
		wndControl:GetParent():GetParent():FindChild("ListItemNewRunner"):Show(false)
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
			local wndCurr = self:FactoryProduce(self.wndCheckList:FindChild("ChecklistItemContainer"), "ScientistChecklistItem", tDataTable.strName)
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

	self.wndCheckList:FindChild("ChecklistTitle"):SetText(pmStudy:GetName())
	self.wndCheckList:FindChild("ChecklistItemContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)

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

function PathScientistContent:HelperGetMissionName(strName)
	local nColonPosition = string.find(strName, ": ") -- TODO HACK!
	local strMissionType = karMissionTypeToFormattedString[nColonPosition and string.sub(strName, 0, nColonPosition) or ""] or ""
	
	return {
		strMissionType,
		string.len(strMissionType) > 0 and string.sub(strName, nColonPosition + 2) or strName
	}
end

function PathScientistContent:FactoryProduce(wndParent, strFormName, tObject)
	local wndChild = wndParent and wndParent:FindChildByUserData(tObject)
	if not wndChild then
		wndChild = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndChild:SetData(tObject)
	end
	return wndChild
end

-----------------------------------------------------------------------------------------------
-- Right Click
-----------------------------------------------------------------------------------------------
function PathScientistContent:CloseContextMenu() -- From a variety of source
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:Destroy()
		self.wndContextMenu = nil
		
		return true
	end
	
	return false
end

function PathScientistContent:DrawContextMenu()
	local nXCursorOffset = -36
	local nYCursorOffset = 5

	if self:CloseContextMenu() then
		return
	end

	self.wndContextMenu = Apollo.LoadForm(self.xmlDoc, "ContextMenu", nil, self)
	self:DrawContextMenuSubOptions()
			
	local tCursor = Apollo.GetMouse()
	local nWidth = self.wndContextMenu:GetWidth()
	local nHeight = self.wndContextMenu:GetHeight()
	
	self.wndContextMenu:Move(
		tCursor.x - nWidth - nXCursorOffset,
		tCursor.y - nHeight - nYCursorOffset,
		nWidth,
		nHeight
	)
end

function PathScientistContent:DrawContextMenuSubOptions(wndIgnore)
	if not self.wndContextMenu or not self.wndContextMenu:IsValid() then
		return
	end
	
	self.wndContextMenu:FindChild("ToggleOnPathMissions"):SetCheck(self.bShowPathMissions)
	self.wndContextMenu:FindChild("ToggleFilterZone"):SetCheck(self.bShowOutOfZone)
	self.wndContextMenu:FindChild("ToggleFilterLimit"):SetCheck(self.bFilterLimit)
	self.wndContextMenu:FindChild("ToggleFilterDistance"):SetCheck(self.bFilterDistance)
	
	local wndMissionLimitEditBox = self.wndContextMenu:FindChild("MissionLimitEditBox")
	local wndMissionDistanceEditBox = self.wndContextMenu:FindChild("MissionDistanceEditBox")
	
	if not wndIgnore or wndIgnore and wndIgnore ~= wndMissionLimitEditBox then
		wndMissionLimitEditBox:SetText(self.bFilterLimit and self.nMaxMissionLimit or 0)
	end
	
	if not wndIgnore or wndIgnore and wndIgnore ~= wndMissionDistanceEditBox then
		wndMissionDistanceEditBox:SetText(self.bFilterDistance and self.nMaxMissionDistance or 0)
	end
end

function PathScientistContent:OnToggleShowPathMissions()
	self.bShowPathMissions = not self.bShowPathMissions
	
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:FindChild("ToggleOnPathMissions"):SetCheck(self.bShowPathMissions)
	end
end

function PathScientistContent:OnToggleFilterZone()
	self.bShowOutOfZone = not self.bShowOutOfZone
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathScientistContent:OnToggleFilterLimit()
	self.bFilterLimit = not self.bFilterLimit
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathScientistContent:OnToggleFilterDistance()
	self.bFilterDistance = not self.bFilterDistance
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathScientistContent:OnMissionLimitEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionLimit = tonumber(wndControl:GetText()) or 0
	self.bFilterLimit = self.nMaxMissionLimit > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

function PathScientistContent:OnMissionDistanceEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionDistance = tonumber(wndControl:GetText()) or 0
	self.bFilterDistance = self.nMaxMissionDistance > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

local PathScientistContentInst = PathScientistContent:new()
PathScientistContentInst:Init()
