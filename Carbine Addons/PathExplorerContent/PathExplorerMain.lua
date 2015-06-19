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

local PathExplorerMain = {}
local kstrLightGrey = "ffb4b4b4"
local kstrPathQuesttMarker = "90PathContent"
local kstrTrackerAddonName = "CRB_Explorer"
local knNewMissionRunnerTimeout = 1 --the number of pulses of the above timer before the "New" runner clears by itself
local knRate = 1

local ktExplorerMissionTypeIcons =
{
	[PathMission.PathMissionType_Explorer_Vista] 				= "Icon_Mission_Explorer_Vista",
	[PathMission.PathMissionType_Explorer_PowerMap] 			= "Icon_Mission_Explorer_PowerMap",
	[PathMission.PathMissionType_Explorer_Area] 				= "Icon_Mission_Explorer_ClaimTerritory",
	[PathMission.PathMissionType_Explorer_Door] 				= "Icon_Mission_Explorer_ActivateChecklist",
	[PathMission.PathMissionType_Explorer_ExploreZone] 			= "Icon_Mission_Explorer_ExploreZone",
	[PathMission.PathMissionType_Explorer_ScavengerHunt] 		= "Icon_Mission_Explorer_ScavengerHunt",
	[PathMission.PathMissionType_Explorer_ActivateChecklist] 	= "Icon_Mission_Explorer_ActivateChecklist",
}

local karMissionTypeToFormattedString =
{
	[""]														= "", -- Valid error state
	[Apollo.GetString("ExplorerMission_CartographyKey")]		= Apollo.GetString("ExplorerMission_Cartography"),
	[Apollo.GetString("ExplorerMission_SurveillanceKey")]		= Apollo.GetString("ExplorerMission_Surveillance"),
	[Apollo.GetString("ExplorerMission_ExpeditionKey")]			= Apollo.GetString("ExplorerMission_Expedition"),
	[Apollo.GetString("ExplorerMission_OperationsKey")]			= Apollo.GetString("ExplorerMission_Operations"),
	[Apollo.GetString("ExplorerMission_ExplorationKey")]		= Apollo.GetString("ExplorerMission_Exploration"),
	[Apollo.GetString("ExplorerMission_StakingClaimKey")]		= Apollo.GetString("ExplorerMission_StakingClaim"),
	[Apollo.GetString("ExplorerMission_ScavengerHuntKey")]		= Apollo.GetString("ExplorerMission_ScavengerHunt"),
	[Apollo.GetString("ExplorerMission_InvestigationKey")]		= Apollo.GetString("ExplorerMission_Investigation"),
	[Apollo.GetString("ExplorerMission_TrackingKey")]			= Apollo.GetString("ExplorerMission_Tracking"),
}

local knSaveVersion = 1

function PathExplorerMain:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.bAlreadySent = false
	
	o.wndMain = nil
	o.tNewMissions = {}
	o.nLastActiveMissionCount = 0
	
	o.bShowOutOfZone = true
	o.bFilterLimit = true
	o.bFilterDistance = true
	o.bShowPathMissions = true
	o.nMaxMissionDistance = 300
	o.nMaxMissionLimit = 3

	return o
end

function PathExplorerMain:Init()
	Apollo.RegisterAddon(self)
end

function PathExplorerMain:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathExplorerMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("SetPlayerPath", "OnSetPlayerPath", self)
end

function PathExplorerMain:OnSetPlayerPath()
	if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Explorer then
		self:OnPathLoaded()
	elseif self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		
		local tData = {
			["strAddon"] = Apollo.GetString(kstrTrackerAddonName),
		}

		Event_FireGenericEvent("ObjectiveTracker_RemoveAddOn", tData)
	end
end

function PathExplorerMain:OnSave(eType)
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
		bShowPathMissions = self.bShowPathMissions,
		nMaxMissionDistance = self.nMaxMissionDistance,
		nMaxMissionLimit = self.nMaxMissionLimit,
		bShowOutOfZone = self.bShowOutOfZone,
		bFilterLimit = self.bFilterLimit,
		bFilterDistance = self.bFilterDistance,
	}

	return tSave
end

function PathExplorerMain:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bAlreadySent = tSavedData.bSent
		self.bMinimized = tSavedData.bMinimized
		self.bMinimizedActive = tSavedData.bMinimizedActive
		self.bMinimizedAvailable = tSavedData.bMinimizedAvailable
		
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

function PathExplorerMain:OnDocumentReady()
	if self.xmlDoc == nil then return end
	
	self:OnPathLoaded()
end

function PathExplorerMain:OnPathLoaded()
	if self.bPathLoaded then return end
	if self.xmlDoc == nil then return end
	if PlayerPathLib.GetPlayerPathType() == nil then return end	
	if PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Explorer then return end
	
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 		"OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", 	"OnPlayerPathMissionDeactivate", self)
	
	Apollo.RegisterEventHandler("ToggleShowPathMissions", 			"OnToggleShowPathMissions", self)
	Apollo.RegisterEventHandler("ToggleShowPathOptions", 			"DrawContextMenu", self)
	
	Apollo.RegisterEventHandler("ObjectiveTrackerLoaded", 			"OnObjectiveTrackerLoaded", self)
	
	Event_FireGenericEvent("ObjectiveTracker_RequestParent")
	
	self.bPathLoaded = true
end

function PathExplorerMain:OnObjectiveTrackerLoaded(wndForm)
	if not wndForm or not wndForm:IsValid() then return end
	
	if self.wndMain and self.wndMain:IsValid() then
		Apollo.RemoveEventHandler("ObjectiveTrackerLoaded", self)
		return
	end
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "MissionList", wndForm, self)	
	self.wndMain:SetData(kstrPathQuesttMarker) --QuestTracker sort index
	
	local tData = {
		["strAddon"]				= Apollo.GetString(kstrTrackerAddonName),
		["strEventMouseLeft"]	= "ToggleShowPathMissions", 
		["strEventMouseRight"]	= "ToggleShowPathOptions",
		["strIcon"]					= "spr_ObjectiveTracker_IconPathExplorer",
		["strDefaultSort"]			= kstrPathQuesttMarker,
	}
	
	Apollo.RegisterEventHandler("ObjectiveTrackerUpdated", "OnPathUpdate", self)
	Event_FireGenericEvent("ObjectiveTracker_NewAddOn", tData)
	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- Main Draw Method
---------------------------------------------------------------------------------------------------

function PathExplorerMain:BuildListItem(pmCurrMission, wndParent)
	if not pmCurrMission then
		return 0
	end

	local wndListItem = self:FactoryProduce(wndParent, "ListItem", pmCurrMission)
	wndListItem:SetData(pmCurrMission)
	wndListItem:FindChild("ListItemMeter"):SetMax(1)
	wndListItem:FindChild("ListItemCompleteBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemCodexBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemSubscreenBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemMouseCatcher"):SetData(pmCurrMission)

	local eMissionType = pmCurrMission:GetType()
	local strMissionType, strMissionName = unpack(self:HelperGetMissionName(pmCurrMission:GetName()))
	wndListItem:FindChild("ListItemBigBtn"):SetTooltip(pmCurrMission:GetSummary() or "")
	wndListItem:FindChild("ListItemIcon"):SetSprite(ktExplorerMissionTypeIcons[eMissionType])
	wndListItem:FindChild("ListItemName"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\""..kstrLightGrey.."\">"..strMissionName.."</P>")

	-- Has Mouse
	local bHasMouse = wndListItem:FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndListItem:FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndListItem:FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	wndListItem:FindChild("ListItemIcon"):SetBGColor(bHasMouse and "44ffffff" or "ffffffff")
	wndListItem:FindChild("ListItemName"):SetTextColor(bHasMouse and ApolloColor.new("white") or ApolloColor.new("UI_TextHoloTitle"))

	-- Mission specific formatting
	local nProgressBar = 0
	local bShowSubscreenBtn = false
	local eType = pmCurrMission:GetType()

	if eType == PathMission.PathMissionType_Explorer_PowerMap then
		bShowSubscreenBtn = self:HelperMissionHasPriority(pmCurrMission)

	elseif eType == PathMission.PathMissionType_Explorer_Area and pmCurrMission:GetExplorerNodeInfo() then
		bShowSubscreenBtn = true

	elseif eType == PathMission.PathMissionType_Explorer_Vista and pmCurrMission:GetExplorerNodeInfo() then
		bShowSubscreenBtn = true

	elseif eType == PathMission.PathMissionType_Explorer_ScavengerHunt then
		bShowSubscreenBtn = pmCurrMission:IsStarted()

		if bShowSubscreenBtn then
			for idx = 0, pmCurrMission:GetNumNeeded() - 1 do
				if pmCurrMission:GetExplorerClueRatio(idx) > nProgressBar then
					nProgressBar = pmCurrMission:GetExplorerClueRatio(idx)
				end
			end
		end
	end
	
	nProgressBar = pmCurrMission and pmCurrMission:GetExplorerNodeInfo() and pmCurrMission:GetExplorerNodeInfo().fRatio or 0
	wndListItem:FindChild("ListItemMeterBG"):Show(nProgressBar > 0)
	--wndListItem:FindChild("ListItemMeter"):SetProgress(nProgressBar, knRate)
	wndListItem:FindChild("ListItemMeter"):SetProgress(nProgressBar)
	wndListItem:FindChild("ListItemMeter"):EnableGlow(nProgressBar > 0)
	wndListItem:FindChild("ListItemCompleteBtn"):Show(nProgressBar >= 1) -- If done
	wndListItem:FindChild("ListItemIcon"):SetSprite(ktExplorerMissionTypeIcons[eType])

	-- Subtitle
	local strPercent = self:HelperComputeProgressText(eType, pmCurrMission) or ""
	if string.len(strPercent) > 0 then
		strMissionType = String_GetWeaselString(Apollo.GetString("ExplorerMissions_PercentSubtitle"),  strPercent, strMissionType)
	end

	wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", strMissionType))

	-- Resize
	local nWidth, nHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	local nBottomOffset = nProgressBar > 0 and 56 or 32
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(nTop, nTop + nHeight + nBottomOffset))
	
	return 1
end

function PathExplorerMain:OnListItemMouseEnter(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	
	local pmCurrMission = wndControl:GetData()
	local bShowSubscreenBtn =
		(pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_PowerMap 
			and self:HelperMissionHasPriority(pmCurrMission))
		or
			pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_Area and pmCurrMission:GetExplorerNodeInfo()
		or
			pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_Vista and pmCurrMission:GetExplorerNodeInfo()
		or
			(pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_ScavengerHunt
				and pmCurrMission:IsStarted())
	
	wndControl:GetParent():FindChild("ListItemSubscreenBtn"):Show(
		bHasMouse 
		and bShowSubscreenBtn 
		and not wndControl:GetParent():FindChild("ListItemCompleteBtn"):IsShown()
	) -- Hide if complete is shown
	
	if bHasMouse then
		Apollo.RemoveEventHandler("ObjectiveTrackerUpdated", self)
	end
end

function PathExplorerMain:OnListItemMouseExit(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	
	local pmCurrMission = wndControl:GetData()
	local bShowSubscreenBtn =
		(pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_PowerMap 
			and self:HelperMissionHasPriority(pmCurrMission))
		or
			pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_Area and pmCurrMission:GetExplorerNodeInfo()
		or
			pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_Vista and pmCurrMission:GetExplorerNodeInfo()
		or
			(pmCurrMission:GetType() == PathMission.PathMissionType_Explorer_ScavengerHunt
				and pmCurrMission:IsStarted())
	
	wndControl:GetParent():FindChild("ListItemSubscreenBtn"):Show(
		bHasMouse 
		and bShowSubscreenBtn 
		and not wndControl:GetParent():FindChild("ListItemCompleteBtn"):IsShown()
	) -- Hide if complete is shown
	
	if not bHasMouse then
		Apollo.RegisterEventHandler("ObjectiveTrackerUpdated", "OnPathUpdate", self)
	end
end

---------------------------------------------------------------------------------------------------
-- Main update method
---------------------------------------------------------------------------------------------------

function PathExplorerMain:OnPathUpdate()
	if not self.wndMain or not self.wndMain:IsValid() then
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
	local nActiveMissionCount = 0
	local nRemainingMissions = 0
	local nAvailableMissionCount = 0
	
	self.wndMain:DestroyChildren()
	self.wndContainer 			= self:FactoryProduce(self.wndMain, "Container", "Container")
	self.wndContainer:FindChild("MinimizeBtn"):SetCheck(self.bMinimized)
	self.wndContainer:FindChild("MinimizeBtn"):Show(self.bMinimized)
	
	self.wndActiveHeader   	= self:FactoryProduce(self.wndContainer:FindChild("Content"), "Category", "ActiveMissionsHeader")
	self.wndAvailableHeader	= self:FactoryProduce(self.wndContainer:FindChild("Content"), "Category", "AvailableMissionsHeader")
	
	local nFilteredMissions = 0
	for _, pmMission in ipairs(tFullMissionList) do
		if pmMission:GetMissionState() == PathMission.PathMissionState_NoMission then
			nRemainingMissions = nRemainingMissions + 1
		elseif not pmMission:IsComplete() and (not self.bFilterLimit or nFilteredMissions < self.nMaxMissionLimit) and (not self.bFilterDistance or pmMission:GetDistance() < self.nMaxMissionDistance) then
			-- Stick a header in if not active
			if self:HelperMissionHasPriority(pmMission) then
				local nCount = self:BuildListItem(pmMission, self.wndActiveHeader:FindChild("Content"))
				nActiveMissionCount = nActiveMissionCount + nCount
				nFilteredMissions = nFilteredMissions + nCount
			else
				local nCount = self:BuildListItem(pmMission, self.wndAvailableHeader:FindChild("Content"))
				nAvailableMissionCount = nAvailableMissionCount + nCount
				nFilteredMissions = nFilteredMissions + nCount
			end
			
			bThereIsAMission = nActiveMissionCount + nAvailableMissionCount > 0
		end
	end
	
	-- Resize Containers
	local strTitle = nRemainingMissions > 0 and string.format("%s [%s %s]", Apollo.GetString("ZoneCompletion_Explorer"), nRemainingMissions, Apollo.GetString("PlayerPath_Undiscovered")) or Apollo.GetString("ZoneCompletion_Explorer")
	self.wndContainer:FindChild("Title"):SetText(strTitle)
	if not bThereIsAMission then
		self.wndContainer:FindChild("MinimizeBtn"):SetAnchorOffsets(0,0,0,0)
	end
	
	strTitle = nActiveMissionCount ~= 1 and string.format("%s [%s]", Apollo.GetString("ExplorerMissions_ActiveMissions"), nActiveMissionCount) or Apollo.GetString("ExplorerMissions_ActiveMissions")
	self.wndActiveHeader:Show(nActiveMissionCount > 0)
	self.wndActiveHeader:FindChild("Title"):SetText(strTitle)
	self.wndActiveHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedActive)
	self.wndActiveHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedActive)
	self:OnResizeContainer(self.wndActiveHeader)
	
	strTitle = nAvailableMissionCount ~= 1 and string.format("%s [%s]", Apollo.GetString("ExplorerMissions_AvailableMissions"), nAvailableMissionCount) or Apollo.GetString("ExplorerMissions_AvailableMissions")
	self.wndAvailableHeader:Show(nAvailableMissionCount > 0)
	self.wndAvailableHeader:FindChild("Title"):SetText(strTitle)
	self.wndAvailableHeader:FindChild("MinimizeBtn"):SetCheck(self.bMinimizedAvailable)
	self.wndAvailableHeader:FindChild("MinimizeBtn"):Show(self.bMinimizedAvailable)
	self:OnResizeContainer(self.wndAvailableHeader)
	
	--Display the container if there are missions or undiscovered missions and you're out of the Arkship.
	local nContainerHeight = (bThereIsAMission or (nRemainingMissions > 0 and GameLib.GetPlayerUnit():GetLevel() > 2)) and self:OnResizeContainer(self.wndContainer) or 0
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nContainerHeight)
	self.wndMain:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	self.wndMain:RecalculateContentExtents()

	-- TEMP HACK
	if self.nLastActiveMissionCount ~= nActiveMissionCount then
		self.nLastActiveMissionCount = nActiveMissionCount
		self.wndMain:DestroyChildren()
		self:OnPathUpdate()
	end
	
	local tData = {
		["strAddon"]	= Apollo.GetString(kstrTrackerAddonName),
		["strText"]		= nActiveMissionCount + nAvailableMissionCount,
		["bChecked"]	= self.bShowPathMissions,
	}

	Event_FireGenericEvent("ObjectiveTracker_UpdateAddOn", tData)
end

function PathExplorerMain:OnResizeContainer(wndContainer)
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
-- Mission Notifications (Unlocked, completed, episode completed)
---------------------------------------------------------------------------------------------------

function PathExplorerMain:OnPlayerPathMissionUnlocked(pmMission) -- new mission, so we want to add a runner
	local t = {}
	t.pmMission = pmMission
	t.nCount = 0
	table.insert(self.tNewMissions, t)

	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- UI Interactions
---------------------------------------------------------------------------------------------------

function PathExplorerMain:OnListItemSubscreenBtn(wndHandler, wndControl) -- wndHandler is "RightSubscreenBtn" and its data is the mission object
	if wndHandler ~= wndControl or not wndHandler:GetData() then
		return
	end
	Event_FireGenericEvent("LoadExplorerMission", wndHandler:GetData())
end

function PathExplorerMain:OnListItemHintArrow(wndControl, wndHandler)
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	local pmMission = wndHandler:GetData()
	if wndHandler:FindChild("ListItemNewRunner") and wndHandler:FindChild("ListItemNewRunner"):IsShown() then -- "new" runner is visible
		wndHandler:FindChild("ListItemNewRunner"):Show(false)

		for idx, tMissionInfo in pairs(self.tNewMissions) do
			if pmMission == tMissionInfo.pmMission then
				table.remove(self.tNewMissions, idx)
			end
		end
	end

	-- What a list item click should do
	local eType = pmMission:GetType()
	if eType == PathMission.PathMissionType_Explorer_Vista and pmMission:GetExplorerNodeInfo() and pmMission:GetExplorerNodeInfo().fRatio > 1 then
		PlayerPathLib.PathAction()
	elseif eType == PathMission.PathMissionType_Explorer_Area and pmMission:GetExplorerNodeInfo() and pmMission:GetExplorerNodeInfo().fRatio > 1 then
		Event_FireGenericEvent("PlayerPath_NotificationSent", 3, pmMission:GetName()) -- Send a completed mission event
		PlayerPathLib.PathAction()
	elseif eType == PathMission.PathMissionType_Explorer_PowerMap and self:HelperMissionHasPriority(pmMission) then
		Event_FireGenericEvent("LoadExplorerMission", pmMission)
	else
		pmMission:ShowHintArrow()
	end
end

function PathExplorerMain:OnMouseEnter(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end
	if ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:HighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathExplorerMain:OnMouseExit(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end
	if ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:UnhighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathExplorerMain:OnListItemOpenCodex(wndHandler, wndControl) -- ListItemCodexBtn
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	Event_FireGenericEvent("DatachronPanel_PlayerPathShow", wndHandler:GetData())
end

function PathExplorerMain:OnControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("MinimizeBtn"):Show(true)
	end
end

function PathExplorerMain:OnControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		local wndBtn = wndHandler:FindChild("MinimizeBtn")
		wndBtn:Show(wndBtn:IsChecked())
	end
end

function PathExplorerMain:OnMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	self.bMinimized 			= self.wndContainer:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedActive 	= self.wndActiveHeader:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedAvailable = self.wndAvailableHeader:FindChild("MinimizeBtn"):IsChecked()
	
	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
function PathExplorerMain:HelperGetMissionName(strName)
	local nColonPosition = string.find(strName, ": ") -- TODO HACK!
	local strMissionType = karMissionTypeToFormattedString[nColonPosition and string.sub(strName, 0, nColonPosition) or ""] or ""
	
	return {
		strMissionType,
		string.len(strMissionType) > 0 and string.sub(strName, nColonPosition + 2) or strName
	}
end

function PathExplorerMain:HelperMissionHasPriority(pmMission)
	if not pmMission or not pmMission:GetDistance() then return end

	local eType = pmMission:GetType()
	if eType == PathMission.PathMissionType_Explorer_PowerMap then
		return pmMission:IsExplorerPowerMapActive() or pmMission:IsExplorerPowerMapReady()

	elseif eType == PathMission.PathMissionType_Explorer_Vista and pmMission:IsStarted() then
		return pmMission:GetExplorerNodeInfo() and pmMission:GetExplorerNodeInfo().nMaxStates ~= 0

	elseif eType == PathMission.PathMissionType_Explorer_Area then
		return pmMission:GetExplorerNodeInfo() and pmMission:GetExplorerNodeInfo().fRatio > 0.1

	elseif pmMission:GetType() == PathMission.PathMissionType_Explorer_ScavengerHunt then
		if pmMission:IsInArea() and not pmMission:IsStarted() then
			return true
		end

		for idx = 1, pmMission:GetNumNeeded() do
			if pmMission:GetExplorerClueRatio(idx) > 0 then
				return true
			end
		end
	end

	return false
end

function PathExplorerMain:HelperComputeProgressText(eType, pmMission)
	local strResult = ""
	if eType == PathMission.PathMissionType_Explorer_ExploreZone then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_Percent"), pmMission:GetNumCompleted())
	elseif eType == PathMission.PathMissionType_Explorer_PowerMap then
		strResult = String_GetWeaselString(Apollo.GetString("ChallengeReward_Multiplier"), math.max(1, pmMission:GetNumNeeded()))
	elseif eType == PathMission.PathMissionType_Explorer_Area or eType == PathMission.PathMissionType_Explorer_ScavengerHunt or eType == PathMission.PathMissionType_Explorer_ActivateChecklist then
		strResult = String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), pmMission:GetNumCompleted(), pmMission:GetNumNeeded())
	end
	return strResult
end

function PathExplorerMain:FactoryProduce(wndParent, strFormName, tObject)
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
function PathExplorerMain:CloseContextMenu() -- From a variety of source
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:Destroy()
		self.wndContextMenu = nil
		
		return true
	end
	
	return false
end

function PathExplorerMain:DrawContextMenu()
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

function PathExplorerMain:DrawContextMenuSubOptions(wndIgnore)
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

function PathExplorerMain:OnToggleShowPathMissions()
	self.bShowPathMissions = not self.bShowPathMissions
	
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:FindChild("ToggleOnPathMissions"):SetCheck(self.bShowPathMissions)
	end
end

function PathExplorerMain:OnToggleFilterZone()
	self.bShowOutOfZone = not self.bShowOutOfZone
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathExplorerMain:OnToggleFilterLimit()
	self.bFilterLimit = not self.bFilterLimit
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathExplorerMain:OnToggleFilterDistance()
	self.bFilterDistance = not self.bFilterDistance
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathExplorerMain:OnMissionLimitEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionLimit = tonumber(wndControl:GetText()) or 0
	self.bFilterLimit = self.nMaxMissionLimit > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

function PathExplorerMain:OnMissionDistanceEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionDistance = tonumber(wndControl:GetText()) or 0
	self.bFilterDistance = self.nMaxMissionDistance > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- Path Explorer instance
---------------------------------------------------------------------------------------------------
local PathExplorerMainInst = PathExplorerMain:new()
PathExplorerMainInst:Init()
