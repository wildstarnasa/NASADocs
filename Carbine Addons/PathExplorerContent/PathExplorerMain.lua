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
local knNewMissionRunnerTimeout = 30 --the number of pulses of the above timer before the "New" runner clears by itself
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

	return o
end

function PathExplorerMain:Init()
	Apollo.RegisterAddon(self)
end

function PathExplorerMain:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathExplorerMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PathExplorerMain:OnSave(eType)
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

function PathExplorerMain:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bAlreadySent = tSavedData.bSent
	end
end

function PathExplorerMain:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("Datachron_LoadPathExplorerContent", "OnLoadFromDatachron", self)
end

function PathExplorerMain:OnLoadFromDatachron()
	if self.wndMain then -- stops double-loading
		return
	end

	-- The parent is the globally defined datachron
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ExplorerMain", g_wndDatachron:FindChild("PathContainer"), self)


	Apollo.RegisterEventHandler("ChangeWorld", 			"HelperResetUI", self)
	Apollo.RegisterEventHandler("PlayerResurrected", 	"HelperResetUI", self)
	Apollo.RegisterEventHandler("ShowResurrectDialog", 	"HelperResetUI", self)
	Apollo.RegisterEventHandler("SubZoneChanged", 		"HelperResetUI", self)
	Apollo.RegisterEventHandler("CharacterCreated", 	"ValidatePath", self)


	--Notification Handlers
	Apollo.RegisterTimerHandler("NotificationShowTimer", 		"OnNotificationShowTimer", self)
	Apollo.RegisterTimerHandler("NotificationHideTimer", 		"OnNotificationHideTimer", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 	"OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPath_NotificationSent", 	"MissionNotificationRecieved", self)


	self.tNewMissions = {}
	self.nLastActiveMissionCount = 0

	self:HelperResetUI()

	if GameLib.GetPlayerUnit() then
		self:ValidatePath()
	end
end

function PathExplorerMain:HelperResetUI()
	-- Note: This gets called from a variety of sources
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("MissionList"):DestroyChildren() -- Full Redraw
		self:OnPathUpdate()
	end
end

function PathExplorerMain:ValidatePath()
	if not PlayerPathLib or not self.wndMain or not self.wndMain:IsValid() then
		return
	elseif PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Explorer then
		if self.wndMain then
			self.wndMain:Destroy()
			self.wndMain = nil
		end
		return
	end

	Apollo.RegisterTimerHandler("OneSecTimer", 				"OnMainTimer", self) -- TODO: Refactor: Merge into PathUpdate
	Apollo.RegisterTimerHandler("Explorer_PathUpdateTimer",	"OnPathUpdate", self)
	Apollo.CreateTimer("Explorer_PathUpdateTimer", 1, false)
end

---------------------------------------------------------------------------------------------------
-- Main Draw Method
---------------------------------------------------------------------------------------------------

function PathExplorerMain:BuildListItem(pmCurrMission)
	if not pmCurrMission then
		return
	end

	local wndListItem = self:FactoryProduce(self.wndMain:FindChild("MissionList"), "ExplorerListItem", pmCurrMission)
	wndListItem:FindChild("ListItemMeter"):SetMax(1)
	wndListItem:FindChild("RightCompleteBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemCodexBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemSubscreenBtn"):SetData(pmCurrMission)

	local eMissionType = pmCurrMission:GetType()
	local nColonPosition = string.find(pmCurrMission:GetName(), ": ") -- TODO HACK!
	local strMissionType = karMissionTypeToFormattedString[nColonPosition and string.sub(pmCurrMission:GetName(), 0, nColonPosition) or ""] or ""
	local strListItemName = string.len(strMissionType) > 0 and string.sub(pmCurrMission:GetName(), nColonPosition + 2) or pmCurrMission:GetName()
	wndListItem:FindChild("ListItemBigBtn"):SetTooltip(pmCurrMission:GetSummary() or "")
	wndListItem:FindChild("ListItemIcon"):SetSprite(ktExplorerMissionTypeIcons[eMissionType])
	wndListItem:FindChild("ListItemName"):SetAML(string.format("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloTitle\">%s</P>", strListItemName))

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
		nProgressBar = pmCurrMission:GetExplorerNodeInfo().fRatio
		wndListItem:FindChild("ListItemMeterBG"):Show(true)

	elseif eType == PathMission.PathMissionType_Explorer_Vista and pmCurrMission:GetExplorerNodeInfo() then
		bShowSubscreenBtn = true
		nProgressBar = pmCurrMission:GetExplorerNodeInfo().fRatio
		wndListItem:FindChild("ListItemMeterBG"):Show(true)

	elseif eType == PathMission.PathMissionType_Explorer_ScavengerHunt then
		bShowSubscreenBtn = pmCurrMission:IsStarted()
		wndListItem:FindChild("ListItemMeterBG"):Show(bShowSubscreenBtn)
		wndListItem:FindChild("ListItemSubscreenBtn"):Show(bShowSubscreenBtn)

		if bShowSubscreenBtn then
			for idx = 0, pmCurrMission:GetNumNeeded() - 1 do
				if pmCurrMission:GetExplorerClueRatio(idx) > nProgressBar then
					nProgressBar = pmCurrMission:GetExplorerClueRatio(idx)
				end
			end
		end
	end

	wndListItem:FindChild("ListItemMeter"):SetProgress(nProgressBar, knRate)
	wndListItem:FindChild("ListItemMeter"):EnableGlow(nProgressBar > 0)
	wndListItem:FindChild("RightCompleteBtn"):Show(nProgressBar >= 1) -- If done
	wndListItem:FindChild("ListItemIcon"):SetSprite(ktExplorerMissionTypeIcons[eType])
	wndListItem:FindChild("ListItemSubscreenBtn"):Show(bShowSubscreenBtn and not wndListItem:FindChild("RightCompleteBtn"):IsShown()) -- Hide if complete is shown

	-- Subtitle
	local strPercent = self:HelperComputeProgressText(eType, pmCurrMission) or ""
	if string.len(strPercent) > 0 then
		strMissionType = String_GetWeaselString(Apollo.GetString("ExplorerMissions_PercentSubtitle"),  strPercent, strMissionType)
	end

	wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">%s</P>", strMissionType))


	-- Resize
	local nWidth, nHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(56, nTop + nHeight + 37))
end

function PathExplorerMain:OnListItemMouseEnter(wndHandler, wndControl)
	self:OnPathUpdate()
end

function PathExplorerMain:OnListItemMouseExit(wndHandler, wndControl)
	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- Main update method
---------------------------------------------------------------------------------------------------

function PathExplorerMain:OnPathUpdate()
	if not PlayerPathLib or not self.wndMain or not self.wndMain:IsValid() then
		return
	elseif PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Explorer then
		if self.wndMain then
			self.wndMain:Destroy()
			self.wndMain = nil
		end
		return
	end

	Apollo.CreateTimer("Explorer_PathUpdateTimer", 1, false)

	local pepCurrent = PlayerPathLib.GetCurrentEpisode()
	if not pepCurrent or GameLib.GetPlayerUnit():IsDead() then
		self.wndMain:FindChild("EmptyLabel"):Show(true)
		self.wndMain:FindChild("MissionList"):DestroyChildren()
		self.wndMain:FindChild("MissionList"):RecalculateContentExtents()
		return
	end

	local tFullMissionList = pepCurrent:GetMissions()
	if not tFullMissionList or #tFullMissionList == 0 then
		self.wndMain:FindChild("EmptyLabel"):Show(true)
		self.wndMain:FindChild("CompletedScreen"):Show(false)
		self.wndMain:FindChild("MissionList"):Show(false)
		self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)
		self.wndMain:FindChild("MissionList"):DestroyChildren()
		self.wndMain:FindChild("MissionList"):RecalculateContentExtents()
		-- TODO: Hide mission windows
		return
	end

	self.wndMain:FindChild("EmptyLabel"):Show(false)

	-- Check for episode completion before building the lists; we'll have to move this to beneath the builder stuff if relics stay (to show their panel)
	if pepCurrent:IsComplete() then
		self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)
		-- TODO: Hide mission windows

		local wndComplete = self.wndMain:FindChild("CompletedScreen")
		wndComplete:Show(true)
		wndComplete:FindChild("EpNameString"):SetText(pepCurrent:GetWorldZone())
		return
	end

	-- Inline Sort Method
	local function SortMissionItems(pepData1, pepData2) -- GOTCHA: This needs to be declared before it's used
		if self:HelperMissionHasPriority(pepData1) and self:HelperMissionHasPriority(pepData2) then
			return pepData1:GetDistance() < pepData2:GetDistance()
		elseif self:HelperMissionHasPriority(pepData1) then
			return true
		elseif self:HelperMissionHasPriority(pepData2) then
			return false
		else
			return pepData1:GetDistance() < pepData2:GetDistance()
		end
	end
	table.sort(tFullMissionList, SortMissionItems)

	local bThereIsAMission = false
	local nActiveMissionCount = 0
	local iRemainingMissions = 0
	self:FactoryProduce(self.wndMain:FindChild("MissionList"), "ActiveMissionsHeader", "ActiveMissionsHeader")

	for _, pmMission in ipairs(tFullMissionList) do
		if pmMission:GetMissionState() == PathMission.PathMissionState_NoMission then
			iRemainingMissions = iRemainingMissions + 1
		elseif not pmMission:IsComplete() then
			-- Stick a header in if not active
			if self:HelperMissionHasPriority(pmMission) then
				nActiveMissionCount = nActiveMissionCount + 1
			else
				self:FactoryProduce(self.wndMain:FindChild("MissionList"), "AvailableMissionsHeader", "AvailableMissionsHeader")
			end

			self:BuildListItem(pmMission)
			bThereIsAMission = true
		end
	end

	if nActiveMissionCount == 0 then
		self.wndMain:FindChild("MissionList"):FindChildByUserData("ActiveMissionsHeader"):Destroy()
	end
	self.wndMain:FindChild("MissionList"):Show(bThereIsAMission)
	self.wndMain:FindChild("MissionList"):ArrangeChildrenVert(0)

	-- Other Screens
	if bThereIsAMission then
		self.wndMain:FindChild("MissionList"):Show(true)
		self.wndMain:FindChild("CompletedScreen"):Show(false)
		self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)

		if not self.bAlreadySent then
			Event_FireGenericEvent("GenericEvent_RestoreDatachron")
			self.bAlreadySent = true
		end
	else -- no missions
		self.wndMain:FindChild("MissionList"):Show(false)
		self.wndMain:FindChild("CompletedScreen"):Show(false)
		-- TODO: hide other missions?

		if iRemainingMissions > 0 then
			self.wndMain:FindChild("MissionsRemainingScreen"):Show(true)
			self.wndMain:FindChild("MissionsRemainingScreen"):FindChild("MissionsRemainingCount"):SetText(iRemainingMissions)
			self.wndMain:FindChild("MissionsRemainingScreen"):FindChild("EpNameString"):SetText(pepCurrent:GetWorldZone())
		else
			self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)
		end
	end

	-- TEMP HACK
	if self.nLastActiveMissionCount ~= nActiveMissionCount then
		self.nLastActiveMissionCount = nActiveMissionCount
		self.wndMain:FindChild("MissionList"):DestroyChildren()
		self:OnPathUpdate()
	end
end

---------------------------------------------------------------------------------------------------
-- Mission Notifications (Unlocked, completed, episode completed)
---------------------------------------------------------------------------------------------------

function PathExplorerMain:MissionNotificationRecieved(nType, strName)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndNotification = self.wndMain:FindChild("MissionNotification")
	if nType ~= 2 and (not wndNotification
	or wndNotification:FindChild("NewMissionContent"):IsShown()
	or wndNotification:FindChild("FailedMissionContent"):IsShown()
	or wndNotification:FindChild("CompletedMissionContent"):IsShown()) then
		return
	end

	if nType == 1 then -- Unlock notice
		wndNotification:FindChild("NewMissionContent"):FindChild("MissionName"):SetText("- " .. strName .. " -")
		wndNotification:FindChild("NewMissionContent"):Show(true)
	elseif nType == 2 then -- Completion notice
		self.wndMain:FindChild("MissionList"):DestroyChildren() -- Full Redraw -- TODO: Move this somewhere more appropriate
		-- TODO: We also need to re-sort when a mission goes active
		wndNotification:FindChild("CompletedMissionContent"):FindChild("NewMissionText"):SetText(Apollo.GetString("Nameplates_Mission"))
		wndNotification:FindChild("CompletedMissionContent"):FindChild("MissionName"):SetText("- " .. strName .. " -")
		wndNotification:FindChild("CompletedMissionContent"):Show(true)
	elseif nType == 3 then -- Objective completion notice
		wndNotification:FindChild("CompletedMissionContent"):FindChild("NewMissionText"):SetText(Apollo.GetString("CRB_Objective"))
		wndNotification:FindChild("CompletedMissionContent"):FindChild("MissionName"):SetText("- " .. strName .. " -")
		wndNotification:FindChild("CompletedMissionContent"):Show(true)
	elseif nType == 4 then -- Mission failed notice
		wndNotification:FindChild("FailedMissionContent"):FindChild("MissionName"):SetText("- " .. strName .. " -")
		wndNotification:FindChild("FailedMissionContent"):Show(true)
	end

	--wndNotification:Show(true)
	Apollo.CreateTimer("NotificationShowTimer", 1.800, false)
end

function PathExplorerMain:OnNotificationShowTimer()
	if not self.wndMain or not self.wndMain:IsValid() then return end
	self.wndMain:FindChild("MissionNotification"):Show(false)
	Apollo.CreateTimer("NotificationHideTimer", 0.300, false)
end

function PathExplorerMain:OnNotificationHideTimer()
	if not self.wndMain or not self.wndMain:IsValid() then return end
	local wndNotification = self.wndMain:FindChild("MissionNotification")
	wndNotification:FindChild("NewMissionContent"):Show(false)
	wndNotification:FindChild("FailedMissionContent"):Show(false)
	wndNotification:FindChild("CompletedMissionContent"):Show(false)
end

function PathExplorerMain:OnPlayerPathMissionUnlocked(pmMission) -- new mission, so we want to add a runner
	local t = {}
	t.pmMission = pmMission
	t.nCount = 0
	table.insert(self.tNewMissions, t)

	self:OnPathUpdate()
end

function PathExplorerMain:OnMainTimer() -- slower timer that updates the mission pulse
	-- Runner
	if not PlayerPathLib or not self.wndMain or not self.wndMain:IsValid() then
		return
	elseif PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Explorer then
		if self.wndMain then
			self.wndMain:Destroy()
			self.wndMain = nil
		end
		return
	end

	for idx, tMissionInfo in pairs(self.tNewMissions) do -- run our "new mission" table
		tMissionInfo.nCount = tMissionInfo.nCount + 1 -- iterate the count on all
		if tMissionInfo.nCount >= knNewMissionRunnerTimeout then -- if beyond max pulse count, remove; Explorer needs Nil gating for the zone-wide territory mission
			local wnd = self.wndMain:FindChild("MissionList"):FindChildByUserData(tMissionInfo.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(false) -- redundant hide to ensure it's gone
			end
			table.remove(self.tNewMissions, idx)
		else -- show runner
			local wnd = self.wndMain:FindChild("MissionList"):FindChildByUserData(tMissionInfo.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(true)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- UI Interactions
---------------------------------------------------------------------------------------------------

function PathExplorerMain:OnListItemRightArrowClick(wndHandler, wndControl) -- wndHandler is "RightSubscreenBtn" and its data is the mission object
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

	local pmMission = wndHandler:GetData()
	Event_FireGenericEvent("DatachronPanel_PlayerPathShow", pmMission)
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

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
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

---------------------------------------------------------------------------------------------------
-- Path Explorer instance
---------------------------------------------------------------------------------------------------
local PathExplorerMainInst = PathExplorerMain:new()
PathExplorerMainInst:Init()
