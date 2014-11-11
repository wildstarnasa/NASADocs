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
local knNewMissionRunnerTimeout = 30 --the number of pulses of the above timer before the "New" runner clears by itself
local knRate = 1

local ktTypeIconStrings =
{
	[PathMission.PathMissionType_Settler_Hub] 				= "Icon_Mission_Settler_DepotImprovements",
	[PathMission.PathMissionType_Settler_Infrastructure] 	= "Icon_Mission_Settler_InfastructureImprovements",
	[PathMission.PathMissionType_Settler_Mayor] 			= "Icon_Mission_Settler_Mayoral",
	[PathMission.PathMissionType_Settler_Sheriff] 			= "Icon_Mission_Settler_Posse",
	[PathMission.PathMissionType_Settler_Scout] 			= "Icon_Mission_Settler_Scout",
}

local karMissionTypeToFormattedString =
{
	[""]														= "", -- Valid error state
	[Apollo.GetString("SettlerMission_ExpansionKey")] 			= Apollo.GetString("SettlerMission_Expansion"),
	[Apollo.GetString("SettlerMission_CacheKey")] 				= Apollo.GetString("SettlerMission_Cache"),
	[Apollo.GetString("SettlerMission_ProjectKey")] 			= Apollo.GetString("SettlerMission_Project"),
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

	return o
end

function PathSettlerMain:Init()
	Apollo.RegisterAddon(self)
end

function PathSettlerMain:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathSettlerMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function PathSettlerMain:OnSave(eType)
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

function PathSettlerMain:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bAlreadySent = tSavedData.bSent
	end
end

function PathSettlerMain:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("Datachron_LoadPathSettlerContent", "OnLoadFromDatachron", self)
end

function PathSettlerMain:OnLoadFromDatachron()
	if self.tWndRefs.wndMain then -- stops double-loading
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer or unitPlayer:GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Settler then
		return
	end

	-- The parent is the globally defined datachron
	self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "SettlerMain", g_wndDatachron:FindChild("PathContainer"), self)
	self.tWndRefs.wndMissionList = self.tWndRefs.wndMain:FindChild("MissionList")

	Apollo.RegisterEventHandler("CharacterCreated", 			"ValidatePath", self)
	Apollo.RegisterEventHandler("ChangeWorld", 					"HelperResetUI", self)
	Apollo.RegisterEventHandler("PlayerResurrected", 			"HelperResetUI", self)
	Apollo.RegisterEventHandler("ShowResurrectDialog", 			"HelperResetUI", self)
	Apollo.RegisterEventHandler("SubZoneChanged", 				"HelperResetUI", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", 	"OnPlayerPathMissionDeactivate", self)

	--Notification Handlers
	Apollo.RegisterTimerHandler("NotificationShowTimer", 		"OnNotificationShowTimer", self)
	Apollo.RegisterTimerHandler("NotificationHideTimer", 		"OnNotificationHideTimer", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 	"OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPath_NotificationSent", 	"MissionNotificationRecieved", self)
	
	--self.tMissionListItems = {}

	self.tNewMissions = {}
	self.nLastActiveMissionCount = 0
	self.pepLast = nil
	self:HelperResetUI()

	if PlayerPathLib:GetPlayerPathType() == PlayerPathLib.PlayerPathType_Settler then
		self:ValidatePath()
	end
end

function PathSettlerMain:HelperResetUI()
	-- Note: This gets called from a variety of sources
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMissionList:DestroyChildren() -- Full Redraw
		self:OnPathUpdate()
	end
end

function PathSettlerMain:ValidatePath(unitPlayer)
	local unitPlayer = GameLib:GetPlayerUnit()
	if not unitPlayer or not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	elseif unitPlayer:GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Settler then
		return
	end

	Apollo.RegisterTimerHandler("MainTimer", 				"OnMainTimer", self) -- TODO: Refactor: Merge into PathUpdate
	Apollo.RegisterTimerHandler("Settler_PathUpdateTimer", 	"OnPathUpdate", self)
	Apollo.CreateTimer("Settler_PathUpdateTimer", 1, true)
end

---------------------------------------------------------------------------------------------------
-- Main update method
---------------------------------------------------------------------------------------------------

function PathSettlerMain:OnPathUpdate()

	if not PlayerPathLib or not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		Apollo.StopTimer("Settler_PathUpdateTimer");
		return
	elseif PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Settler then
		if self.tWndRefs.wndMain then
			self.tWndRefs.wndMain:Destroy()
			self.tWndRefs = {}
		end
		Apollo.StopTimer("Settler_PathUpdateTimer");
		return
	end

	-- Early outs for nothing to show here
	local pepEpisode = PlayerPathLib.GetCurrentEpisode()
	if not pepEpisode or GameLib.GetPlayerUnit():IsDead() then
		self.pepLast = nil
		self:HelperDrawNoEpisode()
		return
	end

	if self.pepLast ~= nil then -- double failsafe to ensure old missions are removed
		if self.pepLast ~= pepEpisode then
			self.pepLast = pepEpisode
			self:HelperResetUI()
		end
	else
		self.pepLast = pepEpisode
	end

	local tFullMissionList = pepEpisode:GetMissions()
	if not tFullMissionList or #tFullMissionList == 0 then
		self:HelperDrawNoEpisode()
		-- TODO: Hide mission windows
		return
	end

	---

	self.tWndRefs.wndMain:FindChild("EmptyLabel"):Show(false)

	-- Inline Sort Method
	local function SortMissionItems(pmData1, pmData2) -- GOTCHA: This needs to be declared before it's used
		if self:HelperMissionHasPriority(pmData1) and self:HelperMissionHasPriority(pmData2) then
			return pmData1:GetDistance() < pmData2:GetDistance()
		elseif self:HelperMissionHasPriority(pmData1) then
			return true
		elseif self:HelperMissionHasPriority(pmData2) then
			return false
		else
			return pmData1:GetDistance() < pmData2:GetDistance()
		end
	end
	
	table.sort(tFullMissionList, SortMissionItems)

	local bThereIsAMission = false
	local bThereIsACompleteHub = false
	local nRemainingMissions = 0
	local nActiveMissionCount = 0
	self:FactoryProduce(self.tWndRefs.wndMissionList, "ActiveMissionsHeader", "ActiveMissionsHeader")

	for idx, pmMission in ipairs(tFullMissionList) do
		local bMissionComplete = pmMission:IsComplete()
		local eMissionType = pmMission:GetType()
		if pmMission:GetMissionState() == PathMission.PathMissionState_NoMission then
			nRemainingMissions = nRemainingMissions + 1
		elseif eMissionType == PathMission.PathMissionType_Settler_Hub and bMissionComplete then
			bThereIsACompleteHub = true
			nActiveMissionCount = nActiveMissionCount + self:BuildListItem(pmMission)
		elseif eMissionType == PathMission.PathMissionType_Settler_Infrastructure and bMissionComplete then
			bThereIsACompleteHub = true
			nActiveMissionCount = nActiveMissionCount + self:BuildListItem(pmMission)
		elseif not bMissionComplete then
			bThereIsAMission = true
			nActiveMissionCount = nActiveMissionCount + self:BuildListItem(pmMission)
		end
	end

	if nActiveMissionCount == 0 then
		local wndAvailableMissions = self.tWndRefs.wndMain:FindChildByUserData("AvailableMissionsHeader")
		if wndAvailableMissions then
			local nLeft, nTop, nRight, nBottom = wndAvailableMissions:GetAnchorOffsets()
			wndAvailableMissions:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 22) -- TODO Hardcoded formatting, quick hack
		end
		self.tWndRefs.wndMissionList:FindChildByUserData("ActiveMissionsHeader"):Destroy()
	end
	self.tWndRefs.wndMissionList:ArrangeChildrenVert(0)

	-- Other Screens
	if bThereIsAMission then
		self.tWndRefs.wndMissionList:Show(true)
		self.tWndRefs.wndMain:FindChild("MissionsRemainingScreen"):Show(false)

		if not self.bAlreadySent then
			Event_FireGenericEvent("GenericEvent_RestoreDatachron")
			self.bAlreadySent = true
		end
	elseif bThereIsACompleteHub then -- no missions, but hub
		self.tWndRefs.wndMissionList:Show(true)
		self.tWndRefs.wndMain:FindChild("MissionsRemainingScreen"):Show(false)

	elseif nRemainingMissions > 0 then -- no missions, no hubs, not all complete
		self.tWndRefs.wndMissionList:Show(false)
		local wndMRS = self.tWndRefs.wndMain:FindChild("MissionsRemainingScreen")
		wndMRS:Show(true)
		wndMRS:FindChild("MissionsRemainingCount"):SetText(nRemainingMissions)
		wndMRS:FindChild("EpNameString"):SetText(pepEpisode:GetWorldZone())

	elseif not pepEpisode:IsComplete() then -- no missions, no hubs, not complete (shouldn't ever happen)
		self:HelperDrawNoEpisode()
	end

	-- TEMP HACK
	if self.nLastActiveMissionCount ~= nActiveMissionCount then
		self.nLastActiveMissionCount = nActiveMissionCount
		self.tWndRefs.wndMissionList:DestroyChildren()
		self:OnPathUpdate()
	end
end

---------------------------------------------------------------------------------------------------
-- Main Draw Method
---------------------------------------------------------------------------------------------------

function PathSettlerMain:BuildListItem(pmMission) -- the bool lets us draw hubs/infras that are completed
	if not pmMission then
		return
	end

	-- Stick a header in if not active
	local nActiveMissionCount = 0
	local bActive = self:HelperMissionHasPriority(pmMission)
	if bActive then
		nActiveMissionCount = nActiveMissionCount + 1
	else
		self:FactoryProduce(self.tWndRefs.wndMissionList, "AvailableMissionsHeader", "AvailableMissionsHeader")
	end

	local wndListItem = self:FactoryProduce(self.tWndRefs.wndMissionList, "SettlerListItem", pmMission)
	wndListItem:FindChild("ListItemBig"):SetData(pmMission)
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemCodexBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemCompleteBtn"):SetData(pmMission)
	wndListItem:FindChild("ListItemSubscreenBtn"):SetData(pmMission)

	local eType = pmMission:GetType()
	local strName = pmMission:GetName()
	
	local nColonPosition = string.find(strName, ": ") -- TODO HACK!
	local strMissionType = karMissionTypeToFormattedString[nColonPosition and string.sub(pmMission:GetName(), 0, nColonPosition) or ""] or ""
	local strListItemName = string.len(strMissionType) > 0 and string.sub(strName, nColonPosition + 2) or strName
	wndListItem:FindChild("ListItemBig"):SetTooltip(pmMission:GetSummary() or "")
	wndListItem:FindChild("ListItemIcon"):SetSprite(pmMission:IsComplete() and "Icon_Windows_UI_CRB_Checkmark" or ktTypeIconStrings[eType])
	wndListItem:FindChild("ListItemName"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"ff2f94ac\">"..strListItemName.."</P>")

	local bIsSettlerHub = eType == PathMission.PathMissionType_Settler_Hub
	wndListItem:FindChild("ListItemBigBtn"):Show(not bIsSettlerHub)
	wndListItem:FindChild("ListItemBigBlocker"):Show(bIsSettlerHub)

	
	-- Has Mouse
	local bHasMouse = wndListItem:FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndListItem:FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndListItem:FindChild("ListItemHintArrowArt"):Show(bHasMouse and not bIsSettlerHub)
	wndListItem:FindChild("ListItemIcon"):SetBGColor((bHasMouse and not bIsSettlerHub) and "44ffffff" or "ffffffff")
	wndListItem:FindChild("ListItemName"):SetTextColor(bHasMouse and ApolloColor.new("white") or ApolloColor.new("ff2f94ac"))

	-- Mission specific formatting
	local nTotal = 0
	local nCompleted = 0
	local bShowSubscreenBtn = false

	if eType == PathMission.PathMissionType_Settler_Hub or eType == PathMission.PathMissionType_Settler_Infrastructure then
		bShowSubscreenBtn = true

	elseif eType == PathMission.PathMissionType_Settler_Scout then
		local tInfo = pmMission:GetSettlerScoutInfo()
		wndListItem:FindChild("ListItemMeterBG"):Show(true)
		wndListItem:FindChild("ListItemMeter"):SetMax(1)
		wndListItem:FindChild("ListItemMeter"):SetProgress(tInfo.fRatio, knRate)
		wndListItem:FindChild("ListItemMeter"):EnableGlow(tInfo.fRatio > 0)
		wndListItem:FindChild("ListItemCompleteBtn"):Show(tInfo.fRatio >= 1)
		bShowSubscreenBtn = tInfo.fRatio < 1

	elseif eType == PathMission.PathMissionType_Settler_Mayor or eType == PathMission.PathMissionType_Settler_Sheriff then
		local tInfo = eType == PathMission.PathMissionType_Settler_Mayor and pmMission:GetSettlerMayorInfo() or pmMission:GetSettlerSheriffInfo()
		for strKey, tCurrInfo in pairs(tInfo) do
			if tCurrInfo.strDescription and string.len(tCurrInfo.strDescription) > 0 then -- Since we get all 8 (including nil) entries and this is how we filter
				nTotal = nTotal + 1
				nCompleted = tCurrInfo.bIsComplete and (nCompleted + 1) or nCompleted
			end
		end

		wndListItem:FindChild("ListItemProgressBG"):Show(true)
		local wndLIM = wndListItem:FindChild("ListItemProgress")
		wndLIM:SetMax(nTotal)
		wndLIM:SetProgress(nCompleted, knRate)
		wndLIM:EnableGlow(nCompleted > 0)
		bShowSubscreenBtn = true
	end

	wndListItem:FindChild("ListItemSubscreenBtn"):Show(bShowSubscreenBtn)

	-- Subtitle
	local strPercent = self:HelperComputeProgressText(eType, pmMission, nCompleted, nTotal)
	if string.len(strPercent) > 0 then
		wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">%s</P>", String_GetWeaselString(Apollo.GetString("ExplorerMissions_PercentSubtitle"),strPercent, strMissionType)))
	else
		wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">%s</P>", strMissionType))
	end

	-- Resize
	local nWidth, nHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(56, nTop + nHeight + 38))

	return nActiveMissionCount
end

-----------------------------------------------------------------------------------------------
-- UI Events/Buttons
-----------------------------------------------------------------------------------------------

function PathSettlerMain:OnListItemMouseEnter(wndHandler, wndControl)
	self:OnPathUpdate()
end

function PathSettlerMain:OnListItemMouseExit(wndHandler, wndControl)
	self:OnPathUpdate()
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

function PathSettlerMain:HelperDrawNoEpisode()
	self.tWndRefs.wndMain:FindChild("EmptyLabel"):Show(true)
	self.tWndRefs.wndMissionList:Show(false)
	self.tWndRefs.wndMain:FindChild("MissionsRemainingScreen"):Show(false)
	self.tWndRefs.wndMissionList:DestroyChildren()
	self.tWndRefs.wndMissionList:RecalculateContentExtents()
end

function PathSettlerMain:OnMainTimer() -- slower timer that updates the mission pulse
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	-- Runner
	for idx, tMissionInfo in pairs(self.tNewMissions) do -- run our "new mission" table
		tMissionInfo.nCount = tMissionInfo.nCount + 1 -- iterate the count on all
		if tMissionInfo.nCount >= knNewMissionRunnerTimeout then -- if beyond max pulse count, remove; Explorer needs Nil gating for the zone-wide territory mission
			local wnd = self.tWndRefs.wndMissionList:FindChildByUserData(tMissionInfo.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(false) -- redundant hide to ensure it's gone
			end
			table.remove(self.tNewMissions, idx)
		else -- show runner
			local wnd = self.tWndRefs.wndMissionList:FindChildByUserData(tMissionInfo.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(true)
			end
		end
	end
end

function PathSettlerMain:OnPlayerPathMissionDeactivate(pmMission)
	if PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Settler then
		return
	end

	if self.tWndRefs.wndMain and self.tWndRefs.wndMissionList:FindChildByUserData(pmMission) then
		self.tWndRefs.wndMissionList:FindChildByUserData(pmMission):Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- Mission Notifications (Unlocked, completed, episode completed)
---------------------------------------------------------------------------------------------------

function PathSettlerMain:MissionNotificationRecieved(nType, strName)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	local wndNotification = self.tWndRefs.wndMain:FindChild("MissionNotification")
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
		self.tWndRefs.wndMissionList:DestroyChildren() -- Full Redraw -- TODO: Move this somewhere more appropriate
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

function PathSettlerMain:OnNotificationShowTimer()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then return end
	self.tWndRefs.wndMain:FindChild("MissionNotification"):Show(false)
	Apollo.CreateTimer("NotificationHideTimer", 0.300, false)
end

function PathSettlerMain:OnNotificationHideTimer()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then return end
	local wndNotification = self.tWndRefs.wndMain:FindChild("MissionNotification")
	wndNotification:FindChild("NewMissionContent"):Show(false)
	wndNotification:FindChild("FailedMissionContent"):Show(false)
	wndNotification:FindChild("CompletedMissionContent"):Show(false)
end

function PathSettlerMain:OnPlayerPathMissionUnlocked(pmMission) -- new mission, so we want to add a runner
	local t = {}
	t.pmMission = pmMission
	t.nCount = 0
	table.insert(self.tNewMissions, t)
	self:OnPathUpdate()
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function PathSettlerMain:HelperMissionHasPriority(pmMission)
	if not pmMission or not pmMission:GetDistance() then 
		return 
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
	if pmMission:IsComplete() then
		strResult = Apollo.GetString("CRB_Complete")
	elseif eType == PathMission.PathMissionType_Settler_Hub or eType == PathMission.PathMissionType_Settler_Infrastructure or eType == PathMission.PathMissionType_Settler_Scout then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), pmMission:GetNumCompleted(), pmMission:GetNumNeeded())
	elseif eType == PathMission.PathMissionType_Settler_Mayor or eType == PathMission.PathMissionType_Settler_Sheriff then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nCompleted, nTotal)
	end
	return strResult
end

function PathSettlerMain:FactoryProduce(wndParent, strFormName, tObject)
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

local PathSettlerMainInst = PathSettlerMain:new()
PathSettlerMainInst:Init()
