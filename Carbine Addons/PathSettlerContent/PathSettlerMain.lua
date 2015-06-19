-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeLog
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
require "AbilityBook"

local PathSettlerMain = {}
local kstrLightGrey = "ffb4b4b4"
local kstrPathQuesttMarker = "90PathContent"
local kstrTrackerAddonName = "CRB_Settler"
local knNewMissionRunnerTimeout = 30 --the number of pulses of the above timer before the "New" runner clears by itself
local knRate = 1

local ktTypeIconStrings =
{
	[PathMission.PathMissionType_Settler_Hub] 				= "Icon_Mission_Settler_DepotImprovements",
	[PathMission.PathMissionType_Settler_Infrastructure] = "Icon_Mission_Settler_InfastructureImprovements",
	[PathMission.PathMissionType_Settler_Mayor] 			= "Icon_Mission_Settler_Mayoral",
	[PathMission.PathMissionType_Settler_Sheriff] 			= "Icon_Mission_Settler_Posse",
	[PathMission.PathMissionType_Settler_Scout] 			= "Icon_Mission_Settler_Scout",
}

local karMissionTypeToFormattedString =
{
	[""]														= "", -- Valid error state
	[Apollo.GetString("SettlerMission_ExpansionKey")] 			= Apollo.GetString("SettlerMission_Expansion"),
	[Apollo.GetString("SettlerMission_CacheKey")] 				= Apollo.GetString("SettlerMission_Cache"),
	[Apollo.GetString("SettlerMission_ProjectKey")] 				= Apollo.GetString("SettlerMission_Project"),
	[Apollo.GetString("SettlerMission_CivilServiceKey")] 		= Apollo.GetString("SettlerMission_CivilService"),
	[Apollo.GetString("SettlerMission_PublicSafetyKey")] 		= Apollo.GetString("SettlerMission_PublicSafety"),
}

local knSaveVersion = 1

function PathSettlerMain:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.bAlreadySent = false
	o.tWndRefs = {}
	
	o.tNewMissions = {}
	o.nLastActiveMissionCount = 0
	
	o.bShowOutOfZone = true
	o.bFilterLimit = true
	o.bFilterDistance = true
	o.bShowPathMissions = true
	o.nMaxMissionDistance = 300
	o.nMaxMissionLimit = 3
	o.bToggleOnGoingProjects = true

	return o
end

function PathSettlerMain:Init()
	Apollo.RegisterAddon(self)
end

function PathSettlerMain:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathSettlerMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 

	Apollo.RegisterEventHandler("SetPlayerPath", "OnSetPlayerPath", self)
end

function PathSettlerMain:OnSetPlayerPath()
	if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Settler then
		self:OnPathLoaded()
	elseif self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		
		local tData = {
			["strAddon"] = Apollo.GetString(kstrTrackerAddonName),
		}

		Event_FireGenericEvent("ObjectiveTracker_RemoveAddOn", tData)
	end
end
function PathSettlerMain:OnSave(eType)
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
		bMinimizedOnGoing = self.bMinimizedOnGoing,
		bShowPathMissions = self.bShowPathMissions,
		nMaxMissionDistance = self.nMaxMissionDistance,
		nMaxMissionLimit = self.nMaxMissionLimit,
		bToggleOnGoingProjects = self.bToggleOnGoingProjects,
		bShowOutOfZone = self.bShowOutOfZone,
		bFilterLimit = self.bFilterLimit,
		bFilterDistance = self.bFilterDistance,
	}

	return tSave
end

function PathSettlerMain:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bAlreadySent = tSavedData.bSent
		self.bMinimized = tSavedData.bMinimized
		self.bMinimizedActive = tSavedData.bMinimizedActive
		self.bMinimizedAvailable = tSavedData.bMinimizedAvailable
		self.bMinimizedOnGoing = tSavedData.bMinimizedOnGoing
		
		if tSavedData.bShowPathMissions ~= nil then
			self.bShowPathMissions = tSavedData.bShowPathMissions
		end
		
		if tSavedData.nMaxMissionDistance ~= nil then
			self.nMaxMissionDistance = tSavedData.nMaxMissionDistance
		end
		
		if tSavedData.nMaxMissionLimit ~= nil then
			self.nMaxMissionLimit = tSavedData.nMaxMissionLimit
		end
		
		if tSavedData.bToggleOnGoingProjects ~= nil then
			self.bToggleOnGoingProjects = tSavedData.bToggleOnGoingProjects
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

function PathSettlerMain:OnDocumentReady()
	if self.xmlDoc == nil then return end
	
	self:OnPathLoaded()
end

function PathSettlerMain:OnPathLoaded()
	if self.bPathLoaded then return end
	if self.xmlDoc == nil then return end
	if PlayerPathLib.GetPlayerPathType() == nil then return end	
	if PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Settler then return end
	
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 		"OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", 	"OnPlayerPathMissionDeactivate", self)
	
	Apollo.RegisterEventHandler("ToggleShowPathMissions", 			"OnToggleShowPathMissions", self)
	Apollo.RegisterEventHandler("ToggleShowPathOptions", 			"DrawContextMenu", self)

	Apollo.RegisterEventHandler("ObjectiveTrackerLoaded", 			"OnObjectiveTrackerLoaded", self)
	
	Event_FireGenericEvent("ObjectiveTracker_RequestParent")
	
	self.bPathLoaded = true
end

function PathSettlerMain:OnObjectiveTrackerLoaded(wndForm)
	if not wndForm or not wndForm:IsValid() then return end
	
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		Apollo.RemoveEventHandler("ObjectiveTrackerLoaded", self)
		return
	end
	
	self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "MissionList", wndForm, self)	
	self.tWndRefs.wndMain:SetData(kstrPathQuesttMarker) --QuestTracker sort index
	
	local tData = {
		["strAddon"]				= Apollo.GetString(kstrTrackerAddonName),
		["strEventMouseLeft"]	= "ToggleShowPathMissions", 
		["strEventMouseRight"]	= "ToggleShowPathOptions",
		["strIcon"]					= "spr_ObjectiveTracker_IconPathSettler",
		["strDefaultSort"]			= kstrPathQuesttMarker,
	}
	
	Apollo.RegisterEventHandler("ObjectiveTrackerUpdated", "OnPathUpdate", self)
	Event_FireGenericEvent("ObjectiveTracker_NewAddOn", tData)
	self:OnPathUpdate()
end

function PathSettlerMain:OnToggleShowPathMissions()
	self.bShowPathMissions = not self.bShowPathMissions
	
	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- Main update method
---------------------------------------------------------------------------------------------------

function PathSettlerMain:OnPathUpdate()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		Event_FireGenericEvent("ObjectiveTracker_RequestParent")
		return
	end
	
	-- Inline Sort Method
	local function SortMissionItems(pmData1, pmData2) -- GOTCHA: This needs to be declared before it's used
		local bQuestTrackerByDistance = g_InterfaceOptions and g_InterfaceOptions.Carbine.bQuestTrackerByDistance
		
		if self:HelperMissionHasPriority(pmData1) and self:HelperMissionHasPriority(pmData2) then
			if bQuestTrackerByDistance then
				return pmData1:GetDistance() < pmData2:GetDistance()
			else
				local aMissionType, aMissionName = unpack(self:HelperGetMissionName(pmData1:GetName()))
				local bMissionType, bMissionName = unpack(self:HelperGetMissionName(pmData2:GetName()))
		
				return aMissionName < bMissionName
			end
		elseif self:HelperMissionHasPriority(pmData1) then
			return true
		elseif self:HelperMissionHasPriority(pmData2) then
			return false
		elseif bQuestTrackerByDistance then
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
		
		if pepAll:GetName() ~= "" then
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
	end
	
	table.sort(tFullMissionList, SortMissionItems)

	local bThereIsAMission = false
	local bThereIsACompleteHub = false
	local nRemainingMissions = 0
	local nActiveMissionCount = 0
	local nAvailableMissionCount = 0
	local nCompleteMissionsCount = 0
	local nNumMissions = 0
	
	self.tWndRefs.wndMain:DestroyChildren()
	self.tWndRefs.wndContainer 			= self:FactoryProduce(self.tWndRefs.wndMain, "Container", "Container")
	self.tWndRefs.wndContainer:FindChild("MinimizeBtn"):SetCheck(self.bMinimized)
	self.tWndRefs.wndContainer:FindChild("MinimizeBtn"):Show(self.bMinimized)
	
	self.tWndRefs.wndActiveHeader   	= self:FactoryProduce(self.tWndRefs.wndContainer:FindChild("Content"), "Category", "ActiveMissionsHeader")
	self.tWndRefs.wndAvailableHeader	= self:FactoryProduce(self.tWndRefs.wndContainer:FindChild("Content"), "Category", "AvailableMissionsHeader")
	self.tWndRefs.wndOnGoingHeader	= self:FactoryProduce(self.tWndRefs.wndContainer:FindChild("Content"), "Category", "OnGoingMissionsHeader")
	
	for idx, pmMission in ipairs(tFullMissionList) do
		local bMissionComplete = pmMission:IsComplete()
		local eMissionType = pmMission:GetType()
		local bActive = self:HelperMissionHasPriority(pmMission)
		local wndParent = bActive and self.tWndRefs.wndActiveHeader or self.tWndRefs.wndAvailableHeader
		
		if pmMission:GetMissionState() == PathMission.PathMissionState_NoMission then
			nRemainingMissions = nRemainingMissions + 1
		elseif eMissionType == PathMission.PathMissionType_Settler_Infrastructure and bMissionComplete then
			bThereIsACompleteHub = true
			
			if self.bToggleOnGoingProjects then
				nNumMissions = nNumMissions + self:BuildListItem(pmMission, self.tWndRefs.wndOnGoingHeader)
				nCompleteMissionsCount = nCompleteMissionsCount + 1
			end
		elseif not bMissionComplete then
			if (not self.bFilterLimit or nAvailableMissionCount < self.nMaxMissionLimit) and (not self.bFilterDistance or pmMission:GetDistance() < self.nMaxMissionDistance) then
				bThereIsAMission = true
				
				nNumMissions = nNumMissions + self:BuildListItem(pmMission, wndParent)
				nActiveMissionCount = bActive and nActiveMissionCount + 1 or nActiveMissionCount
				nAvailableMissionCount = not bActive and nAvailableMissionCount + 1 or nAvailableMissionCount
			end
		end
	end
	
	-- Resize Containers
	local strTitle = nRemainingMissions > 0 and string.format("%s [%s %s]", Apollo.GetString("ZoneCompletion_Settler"), nRemainingMissions, Apollo.GetString("PlayerPath_Undiscovered")) or Apollo.GetString("ZoneCompletion_Settler")
	self.tWndRefs.wndContainer:FindChild("Title"):SetText(strTitle)
	if nNumMissions == 0 then
		self.tWndRefs.wndContainer:FindChild("MinimizeBtn"):SetAnchorOffsets(0,0,0,0)
	end
	
	strTitle = nActiveMissionCount ~= 1 and string.format("%s [%s]", Apollo.GetString("ExplorerMissions_ActiveMissions"), nActiveMissionCount) or Apollo.GetString("ExplorerMissions_ActiveMissions")
	self.tWndRefs.wndActiveHeader:Show(nActiveMissionCount > 0)
	self.tWndRefs.wndActiveHeader:FindChild("Title"):SetText(strTitle)
	self.tWndRefs.wndActiveHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedActive)
	self.tWndRefs.wndActiveHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedActive)
	self:OnResizeContainer(self.tWndRefs.wndActiveHeader)
	
	strTitle = nAvailableMissionCount ~= 1 and string.format("%s [%s]", Apollo.GetString("ExplorerMissions_AvailableMissions"), nAvailableMissionCount) or Apollo.GetString("ExplorerMissions_AvailableMissions")
	self.tWndRefs.wndAvailableHeader:Show(nAvailableMissionCount > 0)
	self.tWndRefs.wndAvailableHeader:FindChild("Title"):SetText(strTitle)
	self.tWndRefs.wndAvailableHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedAvailable)
	self.tWndRefs.wndAvailableHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedAvailable)
	self:OnResizeContainer(self.tWndRefs.wndAvailableHeader)
	
	strTitle = nCompleteMissionsCount ~= 1 and string.format("%s [%s]", Apollo.GetString("SettlerMission_OnGoing"), nCompleteMissionsCount) or Apollo.GetString("SettlerMission_OnGoing")
	self.tWndRefs.wndOnGoingHeader:Show(nCompleteMissionsCount > 0)
	self.tWndRefs.wndOnGoingHeader:FindChild("Title"):SetText(strTitle)
	self.tWndRefs.wndOnGoingHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedOnGoing)
	self.tWndRefs.wndOnGoingHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedOnGoing)
	self:OnResizeContainer(self.tWndRefs.wndOnGoingHeader)
	
	--Display the container if there are missions or undiscovered missions and you're out of the Arkship.
	local nContainerHeight = (bThereIsAMission or nCompleteMissionsCount > 0 or (nRemainingMissions > 0 and GameLib.GetPlayerUnit():GetLevel() > 2)) and self:OnResizeContainer(self.tWndRefs.wndContainer) or 0
	local nLeft, nTop, nRight, nBottom = self.tWndRefs.wndMain:GetAnchorOffsets()
	self.tWndRefs.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nContainerHeight)
	self.tWndRefs.wndMain:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	self.tWndRefs.wndMain:RecalculateContentExtents()
	
	-- TEMP HACK
	if self.nLastActiveMissionCount ~= nActiveMissionCount then
		self.nLastActiveMissionCount = nActiveMissionCount
		self.tWndRefs.wndMain:DestroyChildren()
		self:OnPathUpdate()
	end
	
	local tData = {
		["strAddon"]	= Apollo.GetString(kstrTrackerAddonName),
		["strText"]		= nActiveMissionCount + nAvailableMissionCount,
		["bChecked"]	= self.bShowPathMissions,
	}

	Event_FireGenericEvent("ObjectiveTracker_UpdateAddOn", tData)
end

function PathSettlerMain:OnResizeContainer(wndContainer)
	if not self.bShowPathMissions or not wndContainer or not wndContainer:IsValid() then
		return 0
	end
	
	local nOngoingGroupHeight = wndContainer:GetHeight()
	local wndContent = wndContainer:FindChild("Content")
	local wndMinimize = wndContainer:FindChild("MinimizeBtn")
	
	if wndMinimize and not wndMinimize:IsChecked() then
		for idx, wndChild in pairs(wndContent:GetChildren()) do
			if wndChild:IsShown() then
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

---------------------------------------------------------------------------------------------------
-- Main Draw Method
---------------------------------------------------------------------------------------------------

function PathSettlerMain:BuildListItem(pmMission, wndParent) -- the bool lets us draw hubs/infras that are completed
	if not pmMission then
		return 0
	end

	local wndListItem = self:FactoryProduce(wndParent:FindChild("Content"), "ListItem", pmMission)
	wndListItem:FindChild("ListItemBig"):SetData(pmMission)
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemCodexBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemCompleteBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemSubscreenBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemMouseCatcher"):SetData(pmMission)

	local eType = pmMission:GetType()
	local strMissionType, strMissionName = unpack(self:HelperGetMissionName(pmMission:GetName()))
	wndListItem:FindChild("ListItemBig"):SetTooltip(pmMission:GetSummary() or "")
	wndListItem:FindChild("ListItemIcon"):SetSprite(ktTypeIconStrings[eType])
	wndListItem:FindChild("ListItemName"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\""..kstrLightGrey.."\">"..strMissionName.."</P>")

	local bIsSettlerHub = eType == PathMission.PathMissionType_Settler_Hub
	wndListItem:FindChild("ListItemBigBtn"):Show(not bIsSettlerHub)
	wndListItem:FindChild("ListItemBigBlocker"):Show(bIsSettlerHub)
	
	-- Has Mouse
	local bHasMouse = wndListItem:FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndListItem:FindChild("ListItemCodexBtn"):Show(bHasMouse)
		 wndListItem:FindChild("ListItemHintArrowArt"):Show(bHasMouse and not bIsSettlerHub)

	-- Mission specific formatting
	local nTotal = 0
	local nCompleted = 0
	local bProgressShown = false
	
	if eType == PathMission.PathMissionType_Settler_Scout then
		local tInfo = pmMission:GetSettlerScoutInfo()
		
		bProgressShown = tInfo.fRatio > 0
		wndListItem:FindChild("ListItemMeterBG"):Show(bProgressShown)
		wndListItem:FindChild("ListItemMeter"):SetMax(1)
		wndListItem:FindChild("ListItemMeter"):SetProgress(tInfo.fRatio, knRate)
		wndListItem:FindChild("ListItemMeter"):EnableGlow(tInfo.fRatio > 0)
		wndListItem:FindChild("ListItemCompleteBtn"):Show(tInfo.fRatio >= 1)
	elseif eType == PathMission.PathMissionType_Settler_Infrastructure then
		local tInfrastructure = PlayerPathLib.GetInfrastructureStatusForMission(pmMission)
		local nCurrent = tInfrastructure.nRemainingTime > 0 and tInfrastructure.nRemainingTime or tInfrastructure.nPercent
		local nMax 	= tInfrastructure.nRemainingTime > 0 and tInfrastructure.nMaxTime or 100
		
		bProgressShown = tInfrastructure.nPercent > 0 and tInfrastructure.nPercent < 100
		wndListItem:FindChild("ListItemProgressBG"):Show(bProgressShown)
		wndListItem:FindChild("ListItemProgress"):SetMax(nMax)
		wndListItem:FindChild("ListItemProgress"):SetProgress(nCurrent)
	elseif eType == PathMission.PathMissionType_Settler_Mayor or eType == PathMission.PathMissionType_Settler_Sheriff then
		local tInfo = eType == PathMission.PathMissionType_Settler_Mayor and pmMission:GetSettlerMayorInfo() or pmMission:GetSettlerSheriffInfo() or {}
		for strKey, tCurrInfo in pairs(tInfo) do
			if tCurrInfo.strDescription and string.len(tCurrInfo.strDescription) > 0 then -- Since we get all 8 (including nil) entries and this is how we filter
				nTotal = nTotal + 1
				nCompleted = tCurrInfo.bIsComplete and (nCompleted + 1) or nCompleted
			end
		end

		-- bProgressShown = nCompleted > 0
		-- local wndLIM = wndListItem:FindChild("ListItemProgress")
		-- wndListItem:FindChild("ListItemProgressBG"):Show(bProgressShown)
		-- wndLIM:SetMax(nTotal)
		-- wndLIM:SetProgress(nCompleted)
		-- wndLIM:EnableGlow(nCompleted > 0)
	end

	-- Subtitle
	local strPercent = self:HelperComputeProgressText(eType, pmMission, nCompleted, nTotal)
	if string.len(strPercent) > 0 then
		wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("ExplorerMissions_PercentSubtitle"),strPercent, strMissionType)))
	else
		wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", strMissionType))
	end

	-- Resize
	local nWidth, nHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	local nBottomOffset = bProgressShown and 56 or 32
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(nTop, nTop + nHeight + nBottomOffset))
	
	return 1
end

-----------------------------------------------------------------------------------------------
-- UI Events/Buttons
-----------------------------------------------------------------------------------------------

function PathSettlerMain:OnListItemMouseEnter(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	
	local pmMission = wndControl:GetData()
	wndControl:GetParent():FindChild("ListItemSubscreenBtn"):Show(bHasMouse and not (pmMission and pmMission:GetType() == PathMission.PathMissionType_Settler_Scout and pmMission:GetSettlerScoutInfo().fRatio >= 1))
	
	if bHasMouse then
		Apollo.RemoveEventHandler("ObjectiveTrackerUpdated", self)
	end
end

function PathSettlerMain:OnListItemMouseExit(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	
	local pmMission = wndControl:GetData()
	wndControl:GetParent():FindChild("ListItemSubscreenBtn"):Show(bHasMouse and not (pmMission and pmMission:GetType() == PathMission.PathMissionType_Settler_Scout and pmMission:GetSettlerScoutInfo().fRatio >= 1))
	
	if not bHasMouse then
		Apollo.RegisterEventHandler("ObjectiveTrackerUpdated",	"OnPathUpdate", self)
	end
end

function PathSettlerMain:OnListItemHintArrow(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local pmMission = wndHandler:GetData()
	local wndINR = wndHandler:FindChild("ListItemNewRunner")
	if wndINR ~= nil and wndINR:IsShown() then -- "new" runner is visible
		wndINR:Show(false)

		for idx, tMissionInfo in pairs(self.tNewMissions) do
			if pmMission == tMissionInfo.pmMission then
				table.remove(self.tNewMissions, idx)
			end
		end
	end

	if pmMission:GetType() == PathMission.PathMissionType_Settler_Scout and pmMission:GetSettlerScoutInfo() and pmMission:GetSettlerScoutInfo().fRatio >= 1 then
		Event_FireGenericEvent("PlayerPath_NotificationSent", 3, pmMission:GetName()) -- Send an objective completed event
		PlayerPathLib.PathAction()
	else
		pmMission:ShowHintArrow()
	end
end

function PathSettlerMain:OnListItemSubscreenBtn(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local pmMission = wndHandler:GetData()
	Event_FireGenericEvent("LoadSettlerMission", pmMission)
end

function PathSettlerMain:OnListItemOpenCodex(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	local pmMission = wndHandler:GetData()
	Event_FireGenericEvent("DatachronPanel_PlayerPathShow", pmMission)
end

function PathSettlerMain:OnMouseEnter(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then return end
	if ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:HighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathSettlerMain:OnMouseExit(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then return end
	if ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:UnhighlightRegionsByUserData(wndHandler:GetData())
	end
end

-----------------------------------------------------------------------------------------------
-- Other Screens
-----------------------------------------------------------------------------------------------

function PathSettlerMain:OnPlayerPathMissionDeactivate(pmMission)
	if PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Settler then
		return
	end

	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:FindChildByUserData(pmMission) then
		self.tWndRefs.wndMain:FindChildByUserData(pmMission):Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- Mission Notifications (Unlocked, completed, episode completed)
---------------------------------------------------------------------------------------------------
function PathSettlerMain:OnPlayerPathMissionUnlocked(pmMission) -- new mission, so we want to add a runner
	local t = {}
	t.pmMission = pmMission
	t.nCount = 0
	table.insert(self.tNewMissions, t)
	self:OnPathUpdate()
end

function PathSettlerMain:OnMouseEnter(wndHandler, wndControl) -- TODO: This doesn't work?
	if not wndHandler or not wndHandler:GetData() then return end

	if wndHandler:GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:HighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathSettlerMain:OnMouseExit(wndHandler, wndControl) -- TODO: This doesn't work?
	if not wndHandler or not wndHandler:GetData() then return end

	if wndHandler:GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:UnhighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathSettlerMain:OnControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("MinimizeBtn"):Show(true)
	end
end

function PathSettlerMain:OnControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		local wndBtn = wndHandler:FindChild("MinimizeBtn")
		wndBtn:Show(wndBtn:IsChecked())
	end
end

function PathSettlerMain:OnMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	self.bMinimized 			= self.tWndRefs.wndContainer:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedActive 	= self.tWndRefs.wndActiveHeader:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedAvailable = self.tWndRefs.wndAvailableHeader:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedOnGoing 	= self.tWndRefs.wndOnGoingHeader:FindChild("MinimizeBtn"):IsChecked()
	
	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function PathSettlerMain:HelperGetMissionName(strName)
	local nColonPosition = string.find(strName, ": ") -- TODO HACK!
	local strMissionType = karMissionTypeToFormattedString[nColonPosition and string.sub(strName, 0, nColonPosition) or ""] or ""
	
	return {
		strMissionType,
		string.len(strMissionType) > 0 and string.sub(strName, nColonPosition + 2) or strName
	}
end

function PathSettlerMain:HelperMissionHasPriority(pmMission)
	if not pmMission or not pmMission:GetDistance() then 
		return false
	end

	--TODO: Possibly other mission types might also have priority
	local eType = pmMission:GetType()
	if eType == PathMission.PathMissionType_Settler_Scout then
		return pmMission:GetSettlerScoutInfo() and pmMission:GetSettlerScoutInfo().fRatio > 0.1
	end

	return false
end

function PathSettlerMain:HelperComputeProgressText(eType, pmMission, nCompleted, nTotal)
	local strResult = ""
	if pmMission:IsComplete() and eType == PathMission.PathMissionType_Settler_Infrastructure then
		local tInfrastructure = PlayerPathLib.GetInfrastructureStatusForMission(pmMission)
		
		local nCurrent = tInfrastructure.nRemainingTime > 0 and tInfrastructure.nRemainingTime or tInfrastructure.nCurrentCount
		local nMax 	= tInfrastructure.nRemainingTime > 0 and tInfrastructure.nMaxTime or tInfrastructure.nMaxCount
		
		if tInfrastructure.nRemainingTime > 0 then
			strResult = string.format("%s%s", Apollo.GetString("CRB_Time_Remaining_2"), self:HelperConvertToTime(nCurrent))
		elseif tInfrastructure.nCurrentCount == 0 and tInfrastructure.nMaxCount == 0 then
			strResult = Apollo.GetString("SettlerMission_Inactive")
		else
			strResult = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nCurrent, nMax)
		end
	elseif pmMission:IsComplete() then
		strResult = Apollo.GetString("CRB_Complete")
	elseif eType == PathMission.PathMissionType_Settler_Hub or eType == PathMission.PathMissionType_Settler_Infrastructure or eType == PathMission.PathMissionType_Settler_Scout then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), pmMission:GetNumCompleted(), pmMission:GetNumNeeded())
	elseif eType == PathMission.PathMissionType_Settler_Mayor or eType == PathMission.PathMissionType_Settler_Sheriff then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nCompleted, nTotal)
	end
	
	return strResult
end

function PathSettlerMain:HelperConvertToTime(nInMilliSeconds, bReturnZero)
	if not bReturnZero and nInMilliSeconds == 0 then
		return ""
	end
	
	local strResult = ""
	local nInSeconds = nInMilliSeconds / 1000
	local nHours = math.floor(nInSeconds / 3600)
	local nMins = math.floor(nInSeconds / 60 - (nHours * 60))
	local strHours = string.format("%02.f", nHours)
	local strMins = string.format("%02.f", nMins)
	local strSecs = string.format("%02.f", math.floor(nInSeconds - (nHours * 3600) - (nMins * 60)))

	if nHours > 24 then
		strResult = String_GetWeaselString(Apollo.GetString("HousingLandscape_DaysHours"), nHours / 24, nHours - (nHours / 24) * 24)
	elseif nHours ~= 0 then
		strResult = strHours .. ":" .. strMins
	else
		strResult = strMins .. ":" .. strSecs
	end

	return strResult
end

function PathSettlerMain:FactoryProduce(wndParent, strFormName, tObject)
	local wnd = wndParent and wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

-----------------------------------------------------------------------------------------------
-- Right Click
-----------------------------------------------------------------------------------------------
function PathSettlerMain:CloseContextMenu() -- From a variety of source
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:Destroy()
		self.wndContextMenu = nil
		
		return true
	end
	
	return false
end

function PathSettlerMain:DrawContextMenu()
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

function PathSettlerMain:DrawContextMenuSubOptions(wndIgnore)
	if not self.wndContextMenu or not self.wndContextMenu:IsValid() then
		return
	end
	
	self.wndContextMenu:FindChild("ToggleOnPathMissions"):SetCheck(self.bShowPathMissions)
	self.wndContextMenu:FindChild("ToggleOnGoingProjects"):SetCheck(self.bShowPathMissions and self.bToggleOnGoingProjects)
	self.wndContextMenu:FindChild("ToggleOnGoingProjects"):Enable(self.bShowPathMissions)	
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

function PathSettlerMain:OnToggleShowPathMissions()
	self.bShowPathMissions = not self.bShowPathMissions
	
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:FindChild("ToggleOnPathMissions"):SetCheck(self.bShowPathMissions)
		self.wndContextMenu:FindChild("ToggleOnGoingProjects"):SetCheck(self.bShowPathMissions and self.bToggleOnGoingProjects)
		self.wndContextMenu:FindChild("ToggleOnGoingProjects"):Enable(self.bShowPathMissions)
	end
end

function PathSettlerMain:OnToggleFilterZone()
	self.bShowOutOfZone = not self.bShowOutOfZone
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathSettlerMain:OnToggleFilterLimit()
	self.bFilterLimit = not self.bFilterLimit
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathSettlerMain:OnToggleFilterDistance()
	self.bFilterDistance = not self.bFilterDistance
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathSettlerMain:OnToggleOnGoingProjects(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.bToggleOnGoingProjects = not self.bToggleOnGoingProjects
	self:OnPathUpdate()
end

function PathSettlerMain:OnMissionLimitEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionLimit = tonumber(wndControl:GetText()) or 0
	self.bFilterLimit = self.nMaxMissionLimit > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

function PathSettlerMain:OnMissionDistanceEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionDistance = tonumber(wndControl:GetText()) or 0
	self.bFilterDistance = self.nMaxMissionDistance > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

local PathSettlerMainInst = PathSettlerMain:new()
PathSettlerMainInst:Init()
