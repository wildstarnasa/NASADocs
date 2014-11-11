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
local kfPathRefreshTimer = 1.0
local knNewMissionRunnerTimeout = 30 --the number of pulses of the above timer before the "New" runner clears by itself

local karMissionTypeToFormattedString =
{
	[PathMission.PathMissionType_Soldier_Assassinate] 	= "SoldierMission_Assassination",
	[PathMission.PathMissionType_Soldier_Demolition] 	= "SoldierMission_Demolition",
	[PathMission.PathMissionType_Soldier_Rescue] 		= "SoldierMission_RescueOps",
	[PathMission.PathMissionType_Soldier_SWAT] 			= "SoldierMission_Swat",
}

local karHoldoutTypeToFormattedString =
{
	[PathMission.PathSoldierEventType_Holdout] 				= "SoldierMission_Holdout",
	[PathMission.PathSoldierEventType_Defend] 				= "SoldierMission_Defend",
	[PathMission.PathSoldierEventType_Timed] 				= "SoldierMission_Holdout",
	[PathMission.PathSoldierEventType_TimedDefend] 			= "SoldierMission_Holdout",
	[PathMission.PathSoldierEventType_WhackAMole] 			= "SoldierMission_FirstStrike",
	[PathMission.PathSoldierEventType_WhackAMoleTimed]		= "SoldierMission_FirstStrike",
	[PathMission.PathSoldierEventType_StopTheThieves] 		= "SoldierMission_Security",
	[PathMission.PathSoldierEventType_StopTheThievesTimed] 	= "SoldierMission_Security",
}

local knSaveVersion = 1

function PathSoldierMain:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.bAlreadySent = false

    return o
end

function PathSoldierMain:Init()
    Apollo.RegisterAddon(self)
end

function PathSoldierMain:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathSoldierMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function PathSoldierMain:OnSave(eType)
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

function PathSoldierMain:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bAlreadySent = tSavedData.bSent
	end
end

function PathSoldierMain:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("Datachron_LoadPathSoldierContent", "OnLoadFromDatachron", self)
	Apollo.RegisterEventHandler("Datachron_LoadQuestHoldoutContent", "OnLoadFromDatachron", self)
end

function PathSoldierMain:OnLoadFromDatachron()
	Apollo.RegisterEventHandler("ChangeWorld", 						"OnCloseResultScreen", self)
	Apollo.RegisterEventHandler("SoldierHoldoutEnd", 				"OnSoldierHoldoutEnd", self)
	Apollo.RegisterEventHandler("SoldierHoldoutStatus", 			"OnCloseResultScreen", self)
	Apollo.RegisterEventHandler("SoldierHoldoutNextWave", 			"OnCloseResultScreen", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", 		"OnPlayerPathMissionDeactivate", self)
	Apollo.RegisterEventHandler("Datachron_SoldierMissionsClosed", 	"OnDatachron_SoldierMissionsClosed", self)
	Apollo.RegisterEventHandler("CreatedCharacter", 				"OnCharacterLoaded", self)
	Apollo.RegisterEventHandler("SubZoneChanged",					"HelperResetUI", self)
	Apollo.RegisterTimerHandler("SoldierResultTimeout", 			"OnCloseResultScreen", self)

	--Notification Handlers
	Apollo.RegisterTimerHandler("NotificationShowTimer", 			"OnNotificationShowTimer", self)
	Apollo.RegisterTimerHandler("NotificationHideTimer", 			"OnNotificationHideTimer", self)
	Apollo.RegisterEventHandler("PlayerPath_NotificationSent", 		"MissionNotificationRecieved", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", 		"OnPlayerPathMissionUnlocked", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PathSoldierMain", g_wndDatachron:FindChild("PathContainer"), self)

	-- Notification Assets
	self.wndMain:FindChild("MissionNotification"):Show(false)
	self.nLastActiveMissionCount = 0
	self.knMaxMissionDistance = 800
	self.bShowingNotice = false
	self.tNewMissions = {}

	if PlayerPathLib.GetPlayerPathType() == PlayerPathLib.PlayerPathType_Soldier then
		self:OnCharacterLoaded()
	end
end

function PathSoldierMain:OnCharacterLoaded()
	local unitPlayer = GameLib:GetPlayerUnit()
	if not unitPlayer or not self.wndMain or not self.wndMain:IsValid() then
		return
	elseif unitPlayer:GetPlayerPathType() and PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Soldier then
		if self.wndMain then
			self.wndMain:Show(false)
		end
		return
	end
	
	local pepEpisode = PlayerPathLib.GetCurrentEpisode()
	if pepEpisode then
		local tFullMissionList = pepEpisode:GetMissions()
		for idx, pmCurrMission in pairs(tFullMissionList) do
			if pmCurrMission:GetMissionState() == PathMission.PathMissionState_Started then
				local seHoldout = pmCurrMission:GetSoldierHoldout()
				if seHoldout then
					self.wndMain:Enable(false)
					Event_FireGenericEvent("LoadSoldierMission", seHoldout)
				end
			end
		end
	end		

	Apollo.RegisterTimerHandler("MainTimer", "OnMainTimer", self)
	Apollo.CreateTimer("MainTimer", kfPathRefreshTimer, true)
end

function PathSoldierMain:HelperResetUI()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("MissionList"):DestroyChildren() -- Full Redraw
		self:OnMainTimer()
	end
end

-----------------------------------------------------------------------------------------------
-- Main
-----------------------------------------------------------------------------------------------

function PathSoldierMain:OnMainTimer()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	elseif PlayerPathLib.GetPlayerPathType() and PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Soldier then
		if self.wndMain then
			self.wndMain:Show(false)
			self.wndMain:FindChild("MissionList"):DestroyChildren()
		end
		return
	end
	
	self.wndMain:FindChild("EmptyLabel"):Show(false)
	self.wndMain:FindChild("MissionList"):Show(false)
	self.wndMain:FindChild("CompletedScreen"):Show(false)
	self.wndMain:FindChild("MissionsRemainingScreen"):Show(false)

	local pepEpisode = PlayerPathLib.GetCurrentEpisode()
	if not pepEpisode then
		self.wndMain:FindChild("EmptyLabel"):Show(true)
		return
	end

	if pepEpisode:IsComplete() then
		self.wndMain:FindChild("SolResult"):Show(false) -- Hide the result so we can show rewards right away
		self.wndMain:FindChild("CompletedScreen"):Show(true)
		self.wndMain:FindChild("CompletedScreen"):FindChild("EpNameString"):SetText(pepEpisode:GetWorldZone())
		return
	end

	-- Inline Sort Method
	local tFullMissionList = pepEpisode:GetMissions()
	local function SortMissionItems(tMission1, tMission2) -- GOTCHA: This needs to be declared before it's used
		local nMission1Distance = tMission1:GetDistance()
		local nMission2Distance = tMission2:GetDistance()
		local bMission1Active = tMission1:IsStarted() and nMission1Distance < self.knMaxMissionDistance
		local bMission2Active = tMission2:IsStarted() and nMission2Distance < self.knMaxMissionDistance

		--Priority 1: Started Missions. Priority 2: Distance
		if bMission1Active and bMission2Active then
			return nMission1Distance < nMission2Distance
		elseif bMission1Active then
			return true
		elseif bMission2Active then
			return false
		else
			return nMission1Distance < nMission2Distance
		end
	end
	table.sort(tFullMissionList, SortMissionItems)

	-- If we have an episode, start looking for missions
	local nRemainingMissions = 0
	local bThereIsAMission = false
	local nActiveMissionCount = 0
	
	for idx, pmCurrMission in pairs(tFullMissionList) do
		local eState = pmCurrMission:GetMissionState()
		if eState == PathMission.PathMissionState_Started or eState == PathMission.PathMissionState_Unlocked then
			self:FactoryProduce(self.wndMain:FindChild("MissionList"), "ActiveMissionsHeader", "ActiveMissionsHeader")
			break
		end
	end

	for idx, pmCurrMission in pairs(tFullMissionList) do
		local eState = pmCurrMission:GetMissionState()
		if eState == PathMission.PathMissionState_NoMission then
			nRemainingMissions = nRemainingMissions + 1
		elseif eState == PathMission.PathMissionState_Complete and self.wndMain:FindChild("MissionList"):FindChildByUserData(pmCurrMission) then
			self.wndMain:FindChild("MissionList"):FindChildByUserData(pmCurrMission):Destroy()
		elseif eState == PathMission.PathMissionState_Started or eState == PathMission.PathMissionState_Unlocked then
			-- Stick a header in if not active
			local bActive = pmCurrMission:IsStarted() and pmCurrMission:GetDistance() < self.knMaxMissionDistance
			if bActive then
				nActiveMissionCount = nActiveMissionCount + 1
			else
				self:FactoryProduce(self.wndMain:FindChild("MissionList"), "AvailableMissionsHeader", "AvailableMissionsHeader")
			end

			-- Draw Item
			local wndListItem = self:FactoryProduce(self.wndMain:FindChild("MissionList"), "SoldierListItem", pmCurrMission)
			self:UpdateListitem(wndListItem, pmCurrMission)
			bThereIsAMission = true
		end
	end

	if nActiveMissionCount == 0 then
		local wndAvailableMissions = self.wndMain:FindChildByUserData("AvailableMissionsHeader")
		if wndAvailableMissions then
			local nLeft, nTop, nRight, nBottom = wndAvailableMissions:GetAnchorOffsets()
			wndAvailableMissions:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 22) -- TODO Hardcoded formatting, quick hack
		end
		local wndActiveMissionsHeader = self.wndMain:FindChild("MissionList"):FindChildByUserData("ActiveMissionsHeader")
		if wndActiveMissionsHeader ~= nil then
			wndActiveMissionsHeader:Destroy()
		end
	end
	self.wndMain:FindChild("MissionList"):ArrangeChildrenVert(0)

	-- Runners
	for idx, v in pairs(self.tNewMissions) do -- run our "new pmMission" table
		v.nCount = v.nCount + 1 -- iterate the nCount on all

		if v.nCount >= knNewMissionRunnerTimeout then -- if beyond max pulse nCount, remove.
			local wnd = self.wndMain:FindChild("MissionList"):FindChildByUserData(v.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(false) -- redundant hiding to ensure it's gone
			end
			table.remove(self.tNewMissions, idx)
		else -- show runner
			local wnd = self.wndMain:FindChild("MissionList"):FindChildByUserData(v.pmMission)
			if wnd ~= nil then
				wnd:FindChild("ListItemNewRunner"):Show(true)
			end
		end
	end

	-- Final Screens
	self.wndMain:FindChild("MissionList"):Show(bThereIsAMission)
	self.wndMain:FindChild("CompletedScreen"):Show(nRemainingMissions == 0 and not bThereIsAMission)
	self.wndMain:FindChild("MissionsRemainingScreen"):Show(nRemainingMissions > 0 and not bThereIsAMission)

	if bThereIsAMission then
		if not self.bAlreadySent then
			Event_FireGenericEvent("GenericEvent_RestoreDatachron")
			self.bAlreadySent = true
		end
	elseif nRemainingMissions > 0 then
		self.wndMain:FindChild("MissionsRemainingScreen"):FindChild("MissionsRemainingCount"):SetText(nRemainingMissions)
		self.wndMain:FindChild("MissionsRemainingScreen"):FindChild("EpNameString"):SetText(pepEpisode:GetWorldZone())
	end

	-- TEMP HACK
	if self.nLastActiveMissionCount ~= nActiveMissionCount then
		self.nLastActiveMissionCount = nActiveMissionCount
		self.wndMain:FindChild("MissionList"):DestroyChildren()
		self:OnMainTimer()
	end
end

function PathSoldierMain:OnPlayerPathMissionDeactivate(pmMission)
	if self.wndMain and self.wndMain:FindChild("MissionList"):FindChildByUserData(pmMission) then
		self.wndMain:FindChild("MissionList"):FindChildByUserData(pmMission):Destroy()
	end
end

function PathSoldierMain:OnDatachron_SoldierMissionsClosed()
	self.wndMain:Show(true)
	self.wndMain:Enable(true)
end

---------------------------------------------------------------------------------------------------
-- Mission Notifications (Unlocked, completed, episode completed)
---------------------------------------------------------------------------------------------------

function PathSoldierMain:MissionNotificationRecieved(nType, strName)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndNotification = self.wndMain:FindChild("MissionNotification")
	if nType ~= 2 and (self.bShowingNotice or not wndNotification) then
		return
	end


	if nType == 1 then -- Unlock notice
		wndNotification:FindChild("NewMissionContent"):FindChild("MissionName"):SetText("- " .. strName .. " -")
		wndNotification:FindChild("NewMissionContent"):Show(true)
	end

	self.bShowingNotice = true
	--wndNotification:Show(true)
	Apollo.CreateTimer("NotificationShowTimer", 1.8, false)
end

function PathSoldierMain:OnNotificationShowTimer()
	if not self.wndMain or not self.wndMain:IsValid() then return end
	self.wndMain:FindChild("MissionNotification"):Show(false)
	Apollo.CreateTimer("NotificationHideTimer", 0.3, false)
end

function PathSoldierMain:OnNotificationHideTimer()
	if not self.wndMain or not self.wndMain:IsValid() then return end
	local wndNotification = self.wndMain:FindChild("MissionNotification")
	wndNotification:FindChild("NewMissionContent"):Show(false)

	self.bShowingNotice = false
end

function PathSoldierMain:OnPlayerPathMissionUnlocked(pmMission) -- new pmMission, so we want to add a runner
	local t = {}
	t.pmMission = pmMission
	t.nCount = 0
	table.insert(self.tNewMissions, t)

	self:OnMainTimer()
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
	local strMissionTypeKey = eMissionType ~= PathMission.PathMissionType_Soldier_Holdout and karMissionTypeToFormattedString[eMissionType] or karHoldoutTypeToFormattedString[pmCurrMission:GetSubType()]
	local strMissionType = strMissionTypeKey and Apollo.GetString(strMissionTypeKey) or ""
	local strItemSprite = self:HelperComputeIconPath(eMissionType, pmCurrMission:GetSubType())
	local strListItemName = string.len(strMissionType) > 0 and string.sub(pmCurrMission:GetName(), nColonPosition + 2) or pmCurrMission:GetName()
	wndListItem:FindChild("ListItemBigBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemCodexBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemSubscreenBtn"):SetData(pmCurrMission)
	wndListItem:FindChild("ListItemSpell"):Show(pmCurrMission:GetSpell())
	wndListItem:FindChild("ListItemSpell"):SetContentId(pmCurrMission:GetSpell() and pmCurrMission or 0)
	wndListItem:FindChild("ListItemName"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloTitle\">"..strListItemName.."</P>")
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
		local strColor = nCompleted == 0 and "ff2f94ac" or "ff31fcf6"
		strHoldoutParameter = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s<T TextColor=\"ff2f94ac\">/%s</T></T>", strColor, nCompleted, nNeeded)
	end
	
	strMissionType = strHoldoutParameter == "" and strMissionType or string.format("(%s) %s", strHoldoutParameter, strMissionType)
	wndListItem:FindChild("ListItemSubtitle"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">%s</P>", strMissionType))	
	-- Resize
	local nWidth, nHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(56, nTop + nHeight + 38))
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

	local strParamColor = "ff2f94ac"
	if seEvent:GetState() == PathMission.PlayerPathSoldierEventMode_Active then
		strParamColor = "ff31fcf6"
	end

	return string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strParamColor, strHoldoutParameter) -- Align=\"Center\"
end

-----------------------------------------------------------------------------------------------
-- Result Screen
-----------------------------------------------------------------------------------------------
function PathSoldierMain:OnSoldierHoldoutEnd(seArgEvent, eReason)
	self.wndMain:FindChild("SolResult"):Show(true)

	local strReason = ""
	if eReason == PathMission.PlayerPathSoldierResult_Success then	
		Sound.Play(Sound.PlayUISoldierHoldoutAchieved)
		self.wndMain:FindChild("SolResult"):FindChild("ResultText"):SetTextColor(CColor.new(132/255, 1, 0, 1))
		self.wndMain:FindChild("SolResult"):FindChild("ResultText"):SetText(Apollo.GetString("CRB_VICTORY"))

		local tWaveInfo = { ["count"] = seArgEvent:GetWaveCount(), ["name"] = Apollo.GetString("CRB_Wave") }
		
		local tEventTypeToVictoryMessage =
		{
			[PathMission.PathSoldierEventType_StopTheThieves] 		= "wavedefense",
			[PathMission.PathSoldierEventType_TowerDefense] 		= "wavedefense",
			[PathMission.PathSoldierEventType_WhackAMole] 			= "wavedefense",
			[PathMission.PathSoldierEventType_Defend] 				= "wavedefense",
			[PathMission.PathSoldierEventType_StopTheThievesTimed] 	= "timed",
			[PathMission.PathSoldierEventType_WhackAMoleTimed] 		= "timed",
			[PathMission.PathSoldierEventType_TimedDefend] 			= "timed",
			[PathMission.PathSoldierEventType_Timed] 				= "timed",
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
		self.wndMain:FindChild("SolResult"):FindChild("ResultText"):SetTextColor(CColor.new(209/255, 0, 0, 1))
		self.wndMain:FindChild("SolResult"):FindChild("ResultText"):SetText(Apollo.GetString("CRB_Holdout_Failed"))
		
		local tFailReasonStrings =
		{
			[PathMission.PlayerPathSoldierResult_ScriptCancel] 			= "CRB_Whoops_Cancelled_by_script",
			[PathMission.PlayerPathSoldierResult_FailUnknown] 			= "CRB_Whoops_Somethings_gone_wrong_here",
			[PathMission.PlayerPathSoldierResult_FailDeath] 			= "CRB_Your_defenses_werent_enough_this_tim",
			[PathMission.PlayerPathSoldierResult_FailTimeOut] 			= "CRB_Time_has_expired_Remember_haste_make",
			[PathMission.PlayerPathSoldierResult_FailLeaveArea] 		= "CRB_The_Holdouts_initiator_fled_in_terro",
			[PathMission.PlayerPathSoldierResult_FailDefenceDeath] 		= "CRB_Your_defenses_werent_enough_this_tim",
			[PathMission.PlayerPathSoldierResult_FailLostResources] 	= "CRB_Your_defenses_werent_enough_this_tim",
			[PathMission.PlayerPathSoldierResult_FailNoParticipants] 	= "CRB_The_Holdouts_initiator_fled_in_terro",
			[PathMission.PlayerPathSoldierResult_FailParticipation]		= "CRB_Holdout_Failed",
		}

		strReason = Apollo.GetString(tFailReasonStrings[eReason])
	end


	self.wndMain:FindChild("SolResult"):FindChild("ReasonText"):SetText(strReason)

	Apollo.CreateTimer("SoldierResultTimeout", 15.0, false)
	Apollo.StartTimer("SoldierResultTimeout")
end

function PathSoldierMain:OnCloseResultScreen()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("SolResult"):Show(false)
		self.wndMain:FindChild("MissionList"):DestroyChildren()
	end
end

-----------------------------------------------------------------------------------------------
-- UI Events/Buttons
-----------------------------------------------------------------------------------------------

function PathSoldierMain:OnListItemMouseEnter(wndHandler, wndControl)
	self:OnMainTimer()
end

function PathSoldierMain:OnListItemMouseExit(wndHandler, wndControl)
	self:OnMainTimer()
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
			self.wndMain:Enable(false)
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

	-- Remove runner
	--[[
	if wndCtrl:GetParent():FindChild("ListItemNewRunner"):IsShown() then -- "new" runner is visible
		wndCtrl:GetParent():FindChild("ListItemNewRunner"):Show(false)

		for idx, v in pairs(self.tNewMissions) do
			if pmMission == v.pmMission then
				table.remove(self.tNewMissions, idx)
			end
		end
	end
	]]--
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

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

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
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

local PathSoldierMainInst = PathSoldierMain:new()
PathSoldierMainInst:Init()
