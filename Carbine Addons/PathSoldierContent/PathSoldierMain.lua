-----------------------------------------------------------------------------------------------
-- Client Lua Script for PathSoldierMain
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "PlayerPathLib"
require "SoldierEvent"
require "PathEpisode"
require "DialogSys"
require "Quest"
require "GameLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"

local PathSoldierMain = {}
local kstrLightGrey = "ffb4b4b4"
local kstrPathQuesttMarker = "90PathContent"
local kstrTrackerAddonName = "CRB_Soldier"
local knNewMissionRunnerTimeout = 6 --the number of pulses of the above timer before the "New" runner clears by itself

local karMissionTypeToFormattedString =
{
	[""] = "",
	[Apollo.GetString("SoldierMission_AssassinationKey")] 	= Apollo.GetString("SoldierMission_Assassination"),
	[Apollo.GetString("SoldierMission_DefendKey")] 			= Apollo.GetString("SoldierMission_Defend"),
	[Apollo.GetString("SoldierMission_DemolitionKey")] 		= Apollo.GetString("SoldierMission_Demolition"),
	[Apollo.GetString("SoldierMission_FirstStrikeKey")] 		= Apollo.GetString("SoldierMission_FirstStrike"),
	[Apollo.GetString("SoldierMission_HoldoutKey")] 		= Apollo.GetString("SoldierMission_Holdout"),
	[Apollo.GetString("SoldierMission_RescueOpsKey")] 	= Apollo.GetString("SoldierMission_RescueOps"),
	[Apollo.GetString("SoldierMission_SecurityKey")] 		= Apollo.GetString("SoldierMission_Security"),
	[Apollo.GetString("SoldierMission_SwatKey")] 			= Apollo.GetString("SoldierMission_Swat"),
}

local knSaveVersion = 1

function PathSoldierMain:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.bAlreadySent = false
	
	o.wndMain = nil
	o.nLastActiveMissionCount = 0
	o.bShowingNotice = false
	o.tNewMissions = {}
	
	o.bShowOutOfZone = true
	o.bFilterLimit = true
	o.bFilterDistance = true
	o.bShowPathMissions = true
	o.nMaxMissionDistance = 300
	o.nMaxMissionLimit = 3

    return o
end

function PathSoldierMain:Init()
    Apollo.RegisterAddon(self)
end

function PathSoldierMain:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathSoldierMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 

	Apollo.RegisterEventHandler("SetPlayerPath", "OnSetPlayerPath", self)
end

function PathSoldierMain:OnSetPlayerPath()
	if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Soldier then
		self:OnPathLoaded()
	elseif self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		
		local tData = {
			["strAddon"] = Apollo.GetString(kstrTrackerAddonName),
		}

		Event_FireGenericEvent("ObjectiveTracker_RemoveAddOn", tData)
	end
end

function PathSoldierMain:OnSave(eType)
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

function PathSoldierMain:OnRestore(eType, tSavedData)
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

function PathSoldierMain:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	self:OnPathLoaded()
end

function PathSoldierMain:OnPathLoaded()
	if self.bPathLoaded then return end
	if self.xmlDoc == nil then return end
	if PlayerPathLib.GetPlayerPathType() == nil then return end	
	if PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Soldier then return end
	
	Apollo.RegisterEventHandler("SoldierHoldoutEnd", 				"OnSoldierHoldoutEnd", self)
	Apollo.RegisterEventHandler("SoldierHoldoutStatus", 			"OnCloseResultScreen", self)
	Apollo.RegisterEventHandler("SoldierHoldoutNextWave", 		"OnCloseResultScreen", self)
	Apollo.RegisterTimerHandler("SoldierResultTimeout", 			"OnCloseResultScreen", self)

	self.wndHoldoutResult = Apollo.LoadForm(self.xmlDoc, "HoldoutResult", "FixedHudStratum", self)

	local pepEpisode = PlayerPathLib.GetCurrentEpisode()
	if pepEpisode then
		local tFullMissionList = pepEpisode:GetMissions()
		for idx, pmCurrMission in pairs(tFullMissionList) do
			if pmCurrMission:GetMissionState() == PathMission.PathMissionState_Started then
				local seHoldout = pmCurrMission:GetSoldierHoldout()
				if seHoldout then
					Event_FireGenericEvent("LoadSoldierMission", seHoldout)
				end
			end
		end
	end
	
	Apollo.RegisterEventHandler("ChangeWorld", 							"OnCloseResultScreen", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 		"OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", 	"OnPlayerPathMissionDeactivate", self)
	
	Apollo.RegisterEventHandler("ToggleShowPathMissions", 			"OnToggleShowPathMissions", self)
	Apollo.RegisterEventHandler("ToggleShowPathOptions", 			"DrawContextMenu", self)

	Apollo.RegisterEventHandler("ObjectiveTrackerLoaded", 			"OnObjectiveTrackerLoaded", self)
	
	Event_FireGenericEvent("ObjectiveTracker_RequestParent")
	
	self.bPathLoaded = true
end

function PathSoldierMain:OnObjectiveTrackerLoaded(wndForm)
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
		["strIcon"]					= "spr_ObjectiveTracker_IconPathSoldier",
		["strDefaultSort"]			= kstrPathQuesttMarker,
	}
	
	Apollo.RegisterEventHandler("ObjectiveTrackerUpdated", "OnPathUpdate", self)
	Event_FireGenericEvent("ObjectiveTracker_NewAddOn", tData)
	self:OnPathUpdate()
end

-----------------------------------------------------------------------------------------------
-- Main
-----------------------------------------------------------------------------------------------

function PathSoldierMain:OnPathUpdate()
	if not self.wndMain or not self.wndMain:IsValid() then
		Event_FireGenericEvent("ObjectiveTracker_RequestParent")
		return
	end
	
	-- Inline Sort Method
	local function SortMissionItems(tMission1, tMission2) -- GOTCHA: This needs to be declared before it's used
		local bQuestTrackerByDistance = g_InterfaceOptions and g_InterfaceOptions.Carbine.bQuestTrackerByDistance
		
		local nMission1Distance = tMission1:GetDistance()
		local nMission2Distance = tMission2:GetDistance()
		local bMission1Active = tMission1:IsStarted()
		local bMission2Active = tMission2:IsStarted()

		--Priority 1: Started Missions. Priority 2: Distance
		if bMission1Active and bMission2Active then
			if bQuestTrackerByDistance then
				return nMission1Distance < nMission2Distance
			else
				local aMissionType, aMissionName = unpack(self:HelperGetMissionName(tMission1:GetName()))
				local bMissionType, bMissionName = unpack(self:HelperGetMissionName(tMission2:GetName()))
		
				return aMissionName < bMissionName
			end
		elseif bMission1Active then
			return true
		elseif bMission2Active then
			return false
		elseif bQuestTrackerByDistance then
			return nMission1Distance < nMission2Distance
		else
			local aMissionType, aMissionName = unpack(self:HelperGetMissionName(tMission1:GetName()))
			local bMissionType, bMissionName = unpack(self:HelperGetMissionName(tMission2:GetName()))
		
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

	-- If we have an episode, start looking for missions
	local nRemainingMissions = 0
	local bThereIsAMission = false
	local nActiveMissions = 0
	local nAvailableMissions = 0
	
	self.wndMain:DestroyChildren()
	self.wndContainer 			= self:FactoryProduce(self.wndMain, "Container", "Container")
	self.wndContainer:FindChild("MinimizeBtn"):SetCheck(self.bMinimized)
	self.wndContainer:FindChild("MinimizeBtn"):Show(self.bMinimized)
	
	self.wndActiveHeader   	= self:FactoryProduce(self.wndContainer:FindChild("Content"), "Category", "ActiveMissionsHeader")
	self.wndAvailableHeader	= self:FactoryProduce(self.wndContainer:FindChild("Content"), "Category", "AvailableMissionsHeader")
	
	for idx, pmCurrMission in pairs(tFullMissionList) do
		local eState = pmCurrMission:GetMissionState()
		if eState == PathMission.PathMissionState_NoMission then
			nRemainingMissions = nRemainingMissions + 1
		elseif eState == PathMission.PathMissionState_Complete and self.wndMain:FindChildByUserData(pmCurrMission) then
			self.wndMain:FindChildByUserData(pmCurrMission):Destroy()
		elseif eState == PathMission.PathMissionState_Started or eState == PathMission.PathMissionState_Unlocked then
			if (not self.bFilterLimit or self.nMaxMissionLimit > nAvailableMissions + nActiveMissions) and (not self.bFilterDistance or pmCurrMission:GetDistance() < self.nMaxMissionDistance) then
				local bActive = pmCurrMission:IsStarted()
				nActiveMissions = bActive and nActiveMissions + 1 or nActiveMissions
				nAvailableMissions = bActive and nAvailableMissions or nAvailableMissions + 1

				-- Draw Item
				local wndParent = bActive and self.wndActiveHeader or self.wndAvailableHeader
				local wndListItem = self:FactoryProduce(wndParent:FindChild("Content"), "ListItem", pmCurrMission)
				self:UpdateListitem(wndListItem, pmCurrMission)
				bThereIsAMission = true
			end
		end
	end

	-- Resize Containers
	local strTitle = nRemainingMissions > 0 and string.format("%s [%s %s]", Apollo.GetString("ZoneCompletion_Soldier"), nRemainingMissions, Apollo.GetString("PlayerPath_Undiscovered")) or Apollo.GetString("ZoneCompletion_Soldier")
	self.wndContainer:FindChild("Title"):SetText(strTitle)
	if not bThereIsAMission then
		self.wndContainer:FindChild("MinimizeBtn"):SetAnchorOffsets(0,0,0,0)
	end
	
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
	
	--Display the container if there are missions or undiscovered missions and you're out of the Arkship.
	local nContainerHeight = (bThereIsAMission or (nRemainingMissions > 0 and GameLib.GetPlayerUnit():GetLevel() > 2)) and self:OnResizeContainer(self.wndContainer) or 0
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nContainerHeight)
	self.wndMain:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	self.wndMain:RecalculateContentExtents()

	-- Runners
	for idx, v in pairs(self.tNewMissions) do -- run our "new pmMission" table
		v.nCount = v.nCount + 1 -- iterate the nCount on all

		if v.nCount >= knNewMissionRunnerTimeout then -- if beyond max pulse nCount, remove.
			local wnd = self.wndMain:FindChildByUserData(v.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(false) -- redundant hiding to ensure it's gone
			end
			table.remove(self.tNewMissions, idx)
		else -- show runner
			local wnd = self.wndMain:FindChildByUserData(v.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(true)
			end
		end
	end

	if bThereIsAMission then
		if not self.bAlreadySent then
			self.bAlreadySent = true
		end
	end

	-- TEMP HACK
	if self.nLastActiveMissionCount ~= nActiveMissions then
		self.nLastActiveMissionCount = nActiveMissions
		self.wndMain:DestroyChildren()
		self:OnPathUpdate()
	end
	
	local tData = {
		["strAddon"]	= Apollo.GetString(kstrTrackerAddonName),
		["strText"]		= nActiveMissions + nAvailableMissions,
		["bChecked"]	= self.bShowPathMissions,
	}

	Event_FireGenericEvent("ObjectiveTracker_UpdateAddOn", tData)
end

function PathSoldierMain:OnResizeContainer(wndContainer)
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

function PathSoldierMain:OnPlayerPathMissionDeactivate(pmMission)
	if self.wndMain and self.wndMain:FindChildByUserData(pmMission) then
		self.wndMain:FindChildByUserData(pmMission):Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- Mission Notifications (Unlocked, completed, episode completed)
---------------------------------------------------------------------------------------------------
function PathSoldierMain:OnPlayerPathMissionUnlocked(pmMission) -- new pmMission, so we want to add a runner
	local t = {}
	t.pmMission = pmMission
	t.nCount = 0
	table.insert(self.tNewMissions, t)

	self:OnPathUpdate()
end

-----------------------------------------------------------------------------------------------
-- Main Draw Method
-----------------------------------------------------------------------------------------------

function PathSoldierMain:UpdateListitem(wndListItem, pmCurrMission)
	if pmCurrMission:GetName() == "" then
		wndListItem:Show(false)
		return
	end

	local eMissionType = pmCurrMission:GetType()
	local nColonPosition = string.find(pmCurrMission:GetName(), ": ") or -1 -- TODO HACK!
	local strItemSprite = self:HelperComputeIconPath(eMissionType, pmCurrMission:GetSubType())
	local strMissionType, strMissionName = unpack(self:HelperGetMissionName(pmCurrMission:GetName()))
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemCodexBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemSubscreenBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemSpell"):Show(pmCurrMission:GetSpell())
	wndListItem:FindChild("ListItemSpell"):SetContentId(pmCurrMission:GetSpell() and pmCurrMission or 0)
	wndListItem:FindChild("ListItemName"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\""..kstrLightGrey.."\">"..strMissionName.."</P>")
	wndListItem:FindChild("ListItemIcon"):SetSprite(strItemSprite)
	wndListItem:FindChild("ListItemBigBtn"):SetTooltip(pmCurrMission:GetSummary() or "")

	-- Has Mouse
	local bHasMouse = wndListItem:FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndListItem:FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndListItem:FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	wndListItem:FindChild("ListItemIcon"):SetBGColor(bHasMouse and "44ffffff" or "ffffffff")
	wndListItem:FindChild("ListItemName"):SetTextColor(bHasMouse and ApolloColor.new("white") or ApolloColor.new("UI_TextHoloTitle"))

	-- Flash?
	local nNeeded = pmCurrMission:GetNumNeeded()
	local nCompleted = pmCurrMission:GetNumCompleted()
	if wndListItem:FindChild("ListItemFlash"):GetData() and wndListItem:FindChild("ListItemFlash"):GetData() < nCompleted then
		wndListItem:FindChild("ListItemFlash"):SetData(nCompleted)
		wndListItem:FindChild("ListItemFlash"):SetSprite("ClientSprites:WhiteFlash")
	end

	-- Subtitle
	local strHoldoutParameter = ""
	if eMissionType == PathMission.PathMissionType_Soldier_Demolition and pmCurrMission:GetSubType() == PathMission.SoldierActivateMode_DelayedChecklist and nCompleted == nNeeded then
		strHoldoutParameter = ""
	elseif eMissionType == PathMission.PathMissionType_Soldier_Holdout then
		strHoldoutParameter = self:DrawExtraHoldoutListItemData(wndListItem, pmCurrMission)
	else
		strHoldoutParameter = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s<T TextColor=\"ffffffff\">/%s</T></T>", nCompleted, nNeeded)
	end
	
	strMissionType = strHoldoutParameter == "" and strMissionType or string.format("(%s) %s", strHoldoutParameter, strMissionType)
	wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", strMissionType))	
	
	-- Resize
	local nWidth, nHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	local nBottomOffset = 32--bProgressShown and 56 or 32
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(nTop, nTop + nHeight + nBottomOffset))
end

function PathSoldierMain:DrawExtraHoldoutListItemData(wndListItem, pmCurrMission)
	wndListItem:FindChild("ListItemSubscreenBtn"):Show(pmCurrMission:IsStarted()) -- Subscreen for hold out only

	local seEvent = pmCurrMission:GetSoldierHoldout()
	if not seEvent then
		return
	end

	local eEventState = seEvent:GetState()
	if eEventState == PathMission.PlayerPathSoldierEventMode_InitialDelay then
		wndListItem:FindChild("ListItemFlash"):SetSprite("ClientSprites:WhiteFlash")
	end

	local strHoldoutParameter = ""
	local eEventType = seEvent:GetType()
	if eEventType == PathMission.PathSoldierEventType_Timed 
		or eEventType == PathMission.PathSoldierEventType_TimedDefend
		or eEventType == PathMission.PathSoldierEventType_WhackAMoleTimed
		or eEventType == PathMission.PathSoldierEventType_StopTheThievesTimed then
		if eEventState == PathMission.PlayerPathSoldierEventMode_Active then
			strHoldoutParameter = self:HelperCalcTime(seEvent:GetMaxTime() - seEvent:GetElapsedTime())
		else
			strHoldoutParameter = self:HelperCalcTime(seEvent:GetMaxTime())
		end

	elseif eEventType == PathMission.PathSoldierEventType_Holdout 
		or eEventType == PathMission.PathSoldierEventType_Defend 
		or eEventType == PathMission.PathSoldierEventType_TowerDefense 
		or eEventType == PathMission.PathSoldierEventType_StopTheThieves 
		or eEventType == PathMission.PathSoldierEventType_WhackAMole then
		if eEventState == PathMission.PlayerPathSoldierEventMode_Active then
			strHoldoutParameter = (seEvent:GetWaveCount() - seEvent:GetWavesReleased()) .. "x"
		else
			strHoldoutParameter = seEvent:GetWaveCount() .. "x"
		end
	end

	local strParamColor = "ffffffff" --"ff2f94ac"
	-- if seEvent:GetState() == PathMission.PlayerPathSoldierEventMode_Active then
		-- strParamColor = "ff31fcf6"
	-- end

	return string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strParamColor, strHoldoutParameter) -- Align=\"Center\"
end

-----------------------------------------------------------------------------------------------
-- Result Screen
-----------------------------------------------------------------------------------------------
function PathSoldierMain:OnSoldierHoldoutEnd(seArgEvent, eReason)
	local strReason = ""
	local strResult = ""
	local strResultColor = ""
	
	if eReason == PathMission.PlayerPathSoldierResult_Success then	
		Sound.Play(Sound.PlayUISoldierHoldoutAchieved)
		strResult =  Apollo.GetString("CRB_VICTORY")
		strResultColor = CColor.new(132/255, 1, 0, 1)
		
		local tWaveInfo = { ["count"] = seArgEvent:GetWaveCount(), ["name"] = Apollo.GetString("CRB_Wave") }
		
		local tEventTypeToVictoryMessage =
		{
			[PathMission.PathSoldierEventType_StopTheThieves] 		= "wavedefense",
			[PathMission.PathSoldierEventType_TowerDefense] 			= "wavedefense",
			[PathMission.PathSoldierEventType_WhackAMole] 				= "wavedefense",
			[PathMission.PathSoldierEventType_Defend] 					= "wavedefense",
			[PathMission.PathSoldierEventType_StopTheThievesTimed] = "timed",
			[PathMission.PathSoldierEventType_WhackAMoleTimed] 		= "timed",
			[PathMission.PathSoldierEventType_TimedDefend] 				= "timed",
			[PathMission.PathSoldierEventType_Timed] 						= "timed",
		}

		local eType = seArgEvent:GetType()
		if eType == PathMission.PathSoldierEventType_Holdout then

			-- The string is "You have taken control of the holdout and defeated $+(1)"
			-- The DB will plural $+(1) to either "1 wave" or "2 waves"

			strReason = String_GetWeaselString(Apollo.GetString("CRB_Youve_taken_the_control_of_the_Holdout"), tWaveInfo)

			--strReason = strReason .. "! " .. Apollo.GetString("CRB_Great_execution") -- TODO: Need to update this punctation. Not sure if we want to be super excited.

		elseif tEventTypeToVictoryMessage[eType] == "wavedefense" then
			strReason = String_GetWeaselString(Apollo.GetString("CRB_You_maintained_a_successful_defense_"), tWaveInfo)

		elseif tEventTypeToVictoryMessage[eType] == "timed" then
			strReason = String_GetWeaselString(Apollo.GetString("CRB_You_defended_yourself_for_"),self:HelperCalcTime(seArgEvent:GetMaxTime()))
		end
	else
		Sound.Play(Sound.PlayUISoldierHoldoutFailed)
		strResult =  Apollo.GetString("CRB_Holdout_Failed")
		strResultColor = CColor.new(209/255, 0, 0, 1)
		
		local tFailReasonStrings =
		{
			[PathMission.PlayerPathSoldierResult_ScriptCancel] 			= "CRB_Whoops_Cancelled_by_script",
			[PathMission.PlayerPathSoldierResult_FailUnknown] 			= "CRB_Whoops_Somethings_gone_wrong_here",
			[PathMission.PlayerPathSoldierResult_FailDeath] 				= "CRB_Your_defenses_werent_enough_this_tim",
			[PathMission.PlayerPathSoldierResult_FailTimeOut] 			= "CRB_Time_has_expired_Remember_haste_make",
			[PathMission.PlayerPathSoldierResult_FailLeaveArea] 			= "CRB_The_Holdouts_initiator_fled_in_terro",
			[PathMission.PlayerPathSoldierResult_FailDefenceDeath] 		= "CRB_Your_defenses_werent_enough_this_tim",
			[PathMission.PlayerPathSoldierResult_FailLostResources] 	= "CRB_Your_defenses_werent_enough_this_tim",
			[PathMission.PlayerPathSoldierResult_FailNoParticipants] 	= "CRB_The_Holdouts_initiator_fled_in_terro",
			[PathMission.PlayerPathSoldierResult_FailParticipation]		= "CRB_Holdout_Failed",
		}

		strReason = Apollo.GetString(tFailReasonStrings[eReason])
	end

	self.wndHoldoutResult:Show(true)
	self.wndHoldoutResult:FindChild("ResultText"):SetTextColor(strResultColor)
	self.wndHoldoutResult:FindChild("ResultText"):SetText(strResult)
	self.wndHoldoutResult:FindChild("ReasonText"):SetText(strReason)

	Apollo.CreateTimer("SoldierResultTimeout", 5.0, false)
	Apollo.StartTimer("SoldierResultTimeout")
end

function PathSoldierMain:OnCloseResultScreen()
	if self.wndHoldoutResult and self.wndHoldoutResult:IsValid() then
		self.wndHoldoutResult:Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- UI Events/Buttons
-----------------------------------------------------------------------------------------------

function PathSoldierMain:OnListItemMouseEnter(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	
	if bHasMouse then
		Apollo.RemoveEventHandler("ObjectiveTrackerUpdated", self)
	end
end

function PathSoldierMain:OnListItemMouseExit(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	wndControl:GetParent():FindChild("ListItemCodexBtn"):Show(bHasMouse)
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
	
	if not bHasMouse then
		Apollo.RegisterEventHandler("ObjectiveTrackerUpdated",	"OnPathUpdate", self)
	end
end

function PathSoldierMain:OnListItemHintArrow(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local pmMission = wndHandler:GetData()
	pmMission:ShowHintArrow()
end


function PathSoldierMain:OnListItemSubscreenBtn(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local pmMission = wndHandler:GetData()
	if pmMission and pmMission:IsStarted() then
		local seEvent = pmMission:GetSoldierHoldout()
		if seEvent then
			Event_FireGenericEvent("LoadSoldierMission", seEvent)
		end
	end
end

function PathSoldierMain:OnListItemOpenCodex(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	local pmMission = wndHandler:GetData()
	Event_FireGenericEvent("DatachronPanel_PlayerPathShow", pmMission)
end

function PathSoldierMain:OnLootEpisodeBtn(wndHandler, wndControl)
	local pepEpisode = wndHandler:GetData()
	if pepEpisode then
		--pepEpisode:AcceptRewards()
		Event_FireGenericEvent("PlayerPath_EpisodeRewardsLootedDatachron")
	end
end

function PathSoldierMain:OnMouseEnter(wndHandler, wndControl) -- TODO: This doesn't work?
	if not wndHandler or not wndHandler:GetData() then return end

	if wndHandler:GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:HighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathSoldierMain:OnMouseExit(wndHandler, wndControl) -- TODO: This doesn't work?
	if not wndHandler or not wndHandler:GetData() then return end

	if wndHandler:GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:UnhighlightRegionsByUserData(wndHandler:GetData())
	end
end

function PathSoldierMain:OnControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("MinimizeBtn"):Show(true)
	end
end

function PathSoldierMain:OnControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		local wndBtn = wndHandler:FindChild("MinimizeBtn")
		wndBtn:Show(wndBtn:IsChecked())
	end
end

function PathSoldierMain:OnMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	self.bMinimized 			= self.wndContainer:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedActive 	= self.wndActiveHeader:FindChild("MinimizeBtn"):IsChecked()
	self.bMinimizedAvailable = self.wndAvailableHeader:FindChild("MinimizeBtn"):IsChecked()
	
	self:OnPathUpdate()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function PathSoldierMain:HelperGetMissionName(strName)
	local nColonPosition = string.find(strName, ": ") -- TODO HACK!
	local strMissionType = karMissionTypeToFormattedString[nColonPosition and string.sub(strName, 0, nColonPosition) or ""] or ""
	
	return {
		strMissionType,
		string.len(strMissionType) > 0 and string.sub(strName, nColonPosition + 2) or strName
	}
end

function PathSoldierMain:HelperComputeIconPath(eType, eSubType)
	local strResult = ""
	
	local tMissionTypeIcons =
	{
		[PathMission.PathMissionType_Soldier_SWAT] 			= "Icon_Mission_Soldier_Swat",
		[PathMission.PathMissionType_Soldier_Rescue] 		= "Icon_Mission_Soldier_Rescue",
		[PathMission.PathMissionType_Soldier_Demolition] 	= "Icon_Mission_Soldier_Demolition",
		[PathMission.PathMissionType_Soldier_Assassinate] 	= "Icon_Mission_Soldier_Assassinate",
	}
	
	if eType == PathMission.PathMissionType_Soldier_Holdout then
		local tHoldoutTypeIcons =
		{
			[PathMission.PathSoldierEventType_Holdout] 				= "Icon_Mission_Soldier_HoldoutConquer", -- Confusing, but there is a holdout subtype of holdout main type
			[PathMission.PathSoldierEventType_TowerDefense] 		= "Icon_Mission_Soldier_HoldoutFortify",
			[PathMission.PathSoldierEventType_Defend] 				= "Icon_Mission_Soldier_HoldoutProtect",
			[PathMission.PathSoldierEventType_Timed]  				= "Icon_Mission_Soldier_HoldoutTimed",
			[PathMission.PathSoldierEventType_TimedDefend] 			= "Icon_Mission_Soldier_HoldoutProtect", -- Duplicate, Assume Timed is the same icon
			[PathMission.PathSoldierEventType_WhackAMole] 			= "Icon_Mission_Soldier_HoldoutRushDown",
			[PathMission.PathSoldierEventType_WhackAMoleTimed] 		= "Icon_Mission_Soldier_HoldoutRushDown", -- Duplicate, Assume Timed is the same icon
			[PathMission.PathSoldierEventType_StopTheThieves] 		= "Icon_Mission_Soldier_HoldoutSecurity",
			[PathMission.PathSoldierEventType_StopTheThievesTimed] 	= "Icon_Mission_Soldier_HoldoutSecurity" -- Duplicate, Assume Timed is the same icon
		}
	
		strResult = tHoldoutTypeIcons[eSubType]
	elseif tMissionTypeIcons[eType] then
		strResult = tMissionTypeIcons[eType]
	end
	return strResult
end

function PathSoldierMain:HelperCalcTime(nMilliseconds)
	local nSecs = nMilliseconds / 1000
	return string.format("%d:%02d", math.floor(nSecs / 60), math.floor(nSecs % 60))
end

function PathSoldierMain:OnGenerateSpellTooltip(wndControl, wndHandler, eType, arg1, arg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
	elseif eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(arg2)
		wndControl:SetTooltipDoc(xml)
	end
end

function PathSoldierMain:FactoryProduce(wndParent, strFormName, tObject)
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
function PathSoldierMain:CloseContextMenu() -- From a variety of source
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:Destroy()
		self.wndContextMenu = nil
		
		return true
	end
	
	return false
end

function PathSoldierMain:DrawContextMenu()
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

function PathSoldierMain:DrawContextMenuSubOptions(wndIgnore)
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

function PathSoldierMain:OnToggleShowPathMissions()
	self.bShowPathMissions = not self.bShowPathMissions
	
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:FindChild("ToggleOnPathMissions"):SetCheck(self.bShowPathMissions)
	end
end

function PathSoldierMain:OnToggleFilterZone()
	self.bShowOutOfZone = not self.bShowOutOfZone
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathSoldierMain:OnToggleFilterLimit()
	self.bFilterLimit = not self.bFilterLimit
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathSoldierMain:OnToggleFilterDistance()
	self.bFilterDistance = not self.bFilterDistance
	
	self:DrawContextMenuSubOptions()
	self:OnPathUpdate()
end

function PathSoldierMain:OnMissionLimitEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionLimit = tonumber(wndControl:GetText()) or 0
	self.bFilterLimit = self.nMaxMissionLimit > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

function PathSoldierMain:OnMissionDistanceEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionDistance = tonumber(wndControl:GetText()) or 0
	self.bFilterDistance = self.nMaxMissionDistance > 0
	
	self:DrawContextMenuSubOptions(wndControl)
	self:OnPathUpdate()
end

local PathSoldierMainInst = PathSoldierMain:new()
PathSoldierMainInst:Init()
