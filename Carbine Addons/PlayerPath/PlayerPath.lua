-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "PathMission"
require "GameLib"

-- TODO Hardcoded Colors for Items
local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 			= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= ApolloColor.new("ItemQuality_Artifact"),
}

local ktPathMissionTypeSprites =
{
	[PlayerPathLib.PlayerPathType_Scientist] =
	{
		[PathMission.PathMissionType_Scientist_FieldStudy]   		= "Icon_Mission_Scientist_FieldStudy",
		[PathMission.PathMissionType_Scientist_DatacubeDiscovery] 	= "Icon_Mission_Scientist_DatachronDiscovery",
		[PathMission.PathMissionType_Scientist_SpecimenSurvey] 		= "Icon_Mission_Scientist_SpecimenSurvey",
		[PathMission.PathMissionType_Scientist_Experimentation] 	= "Icon_Mission_Scientist_ReverseEngineering",
		["default"] 												= "Icon_Mission_Scientist_ScanMineral",
	},

	[PlayerPathLib.PlayerPathType_Settler] =
	{
		[PathMission.PathMissionType_Settler_Scout] 				= "Icon_Mission_Settler_Scout",
		[PathMission.PathMissionType_Settler_Sheriff] 				= "Icon_Mission_Settler_Posse",
		[PathMission.PathMissionType_Settler_Mayor] 				= "Icon_Mission_Settler_Mayoral",
		[PathMission.PathMissionType_Settler_Hub] 					= "Icon_Mission_Settler_DepotImprovements",
		[PathMission.PathMissionType_Settler_Infrastructure] 		= "Icon_Mission_Settler_InfastructureImprovements",
		["default"] 												= "Icon_Mission_Settler_DepotImprovements",
	},

	[PlayerPathLib.PlayerPathType_Soldier] =
	{
		[PathMission.PathMissionType_Soldier_SWAT] 					= "Icon_Mission_Soldier_Swat",
		[PathMission.PathMissionType_Soldier_Rescue] 				= "Icon_Mission_Soldier_Rescue",
		[PathMission.PathMissionType_Soldier_Demolition] 			= "Icon_Mission_Soldier_Demolition",
		[PathMission.PathMissionType_Soldier_Assassinate] 			= "Icon_Mission_Soldier_Assassinate",
		["default"] 												= "Icon_Mission_Soldier_Swat",
	},

	[PlayerPathLib.PlayerPathType_Explorer] =
	{
		[PathMission.PathMissionType_Explorer_Vista] 				= "Icon_Mission_Explorer_Vista",
		[PathMission.PathMissionType_Explorer_PowerMap] 			= "Icon_Mission_Explorer_PowerMap",
		[PathMission.PathMissionType_Explorer_Area] 				= "Icon_Mission_Explorer_ClaimTerritory",
		[PathMission.PathMissionType_Explorer_Door] 				= "Icon_Mission_Explorer_ActivateChecklist",
		[PathMission.PathMissionType_Explorer_ExploreZone] 			= "Icon_Mission_Explorer_ExploreZone",
		[PathMission.PathMissionType_Explorer_ScavengerHunt] 		= "Icon_Mission_Explorer_ScavengerHunt",
		[PathMission.PathMissionType_Explorer_ActivateChecklist] 	= "Icon_Mission_Explorer_ActivateChecklist",
		["default"] 												= "Icon_Mission_Explorer_ExploreZone",
	},
}

local ktPathMissionSubtypeSprites =
{
	[PlayerPathLib.PlayerPathType_Scientist] =
	{
		[PathMission.ScientistCreatureType_Tech] 					= "Icon_Mission_Scientist_ScanTech",
		[PathMission.ScientistCreatureType_Flora] 					= "Icon_Mission_Scientist_ScanPlant",
		[PathMission.ScientistCreatureType_Fauna] 					= "Icon_Mission_Scientist_ScanCreature",
		[PathMission.ScientistCreatureType_Mineral] 				= "Icon_Mission_Scientist_ScanMineral",
		[PathMission.ScientistCreatureType_Magic] 					= "Icon_Mission_Scientist_ScanMagic",
		[PathMission.ScientistCreatureType_History] 				= "Icon_Mission_Scientist_ScanHistory",
		[PathMission.ScientistCreatureType_Elemental] 				= "Icon_Mission_Scientist_ScanElemental",
	},

	[PlayerPathLib.PlayerPathType_Soldier] =
	{
		[PathMission.PathSoldierEventType_Holdout] 					= "Icon_Mission_Soldier_HoldoutConquer",
		[PathMission.PathSoldierEventType_TowerDefense] 			= "Icon_Mission_Soldier_HoldoutFortify",
		[PathMission.PathSoldierEventType_Defend] 					= "Icon_Mission_Soldier_HoldoutProtect",
		[PathMission.PathSoldierEventType_Timed] 					= "Icon_Mission_Soldier_HoldoutTimed",
		[PathMission.PathSoldierEventType_TimedDefend] 				= "Icon_Mission_Soldier_HoldoutProtect",
		[PathMission.PathSoldierEventType_WhackAMole] 				= "Icon_Mission_Soldier_HoldoutRushDown",
		[PathMission.PathSoldierEventType_WhackAMoleTimed] 			= "Icon_Mission_Soldier_HoldoutRushDown",
		[PathMission.PathSoldierEventType_StopTheThieves] 			= "Icon_Mission_Soldier_HoldoutSecurity",
		[PathMission.PathSoldierEventType_StopTheThievesTimed] 		= "Icon_Mission_Soldier_HoldoutSecurity",
	},
}

local PlayerPath 					= {}
local knMaxLevel 					= 30 -- TODO: Replace this with a non hardcoded value
local kcrNormalTextColor 			= CColor.new(192/255, 192/255, 192/255, 1.0)
local kcrHighlightTextColor 		= CColor.new(1.0, 128/255, 0, 1.0)
local kstrMissionDescriptionText 	= "ffffeca0"
local knAutoScrollPadding			= 30

function PlayerPath:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function PlayerPath:Init()
	Apollo.RegisterAddon(self)
end

function PlayerPath:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PlayerPath.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function PlayerPath:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	
	Apollo.RegisterEventHandler("PL_TogglePlayerPath", 					"OnPathShowFromPL", self)
	Apollo.RegisterEventHandler("SetPlayerPath", 						"SetPlayerPath", self)
	Apollo.RegisterEventHandler("PathLevelUp", 							"OnRedrawLevels", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUpdate", 				"UpdateUIFromEvent", self) -- specific mission update, send the mission
	Apollo.RegisterEventHandler("PlayerPathRefresh", 					"UpdateUIFromEvent", self) -- generic update for things like episode change; no info sent
	Apollo.RegisterEventHandler("UpdatePathXp", 						"UpdateUIFromEvent", self)
	Apollo.RegisterEventHandler("DatachronPanel_PlayerPathShow", 		"OnShowFromDatachron", self)
	Apollo.RegisterTimerHandler("MissionHighlightTimer", 				"OnMissionHighlightTimer", self)
end

function PlayerPath:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_PathLog"), {"PlayerPathShow", "Path", "Icon_Windows32_UI_CRB_InterfaceMenu_Path"})
end

function PlayerPath:OnPathShowFromPL(pepEpisode)
	if not self.wndMissionLog then
		self:Initialize()
	end

	if not PathEpisode.is(pepEpisode) then
		self:PathRefresh(nil, true)
	else
		self:PathRefresh(pepEpisode, false)
	end

	self:OnRedrawLevels(nil)
end

function PlayerPath:OnShowFromDatachron(pmMission) -- used to open to a specific mission
	if not self.wndMissionLog then
		self:Initialize()
	end

	if pmMission and (not self.pmHighlightedMission or self.pmHighlightedMission ~= pmMission) then
		self.pmHighlightedMission = pmMission
		Apollo.StopTimer("MissionHighlightTimer")
		Apollo.CreateTimer("MissionHighlightTimer", 8.5, false)
	end
	self:HelperCheckTheFirstCategory()
	--full redraw because the path log may be showing paths from a different zone
	self:PathRefresh(nil, true)

	Event_FireGenericEvent("PlayerPathShow_NoHide") -- if PLog is visible, jump to that tab. If not, open it, then jump to that tab. This will have to go into Codex code
end

function PlayerPath:Initialize()
	self.wndMissionLog = Apollo.LoadForm(self.xmlDoc, "MissionLog", g_wndProgressLog:FindChild("ContentWnd_2"), self)
	self.wndMissionLog:FindChild("ZoneDropdownBtn"):AttachWindow(self.wndMissionLog:FindChild("ZoneDropdownContainer"))
	self.wndMissionLog:FindChild("EpisodeRewardRedeem"):Enable(false) -- TODO TEMP
	self.wndMissionLog:Show(true)

	self.ePlayerPath = PlayerPathLib.GetPlayerPathType() -- NOTE: This will require a player to reloadui when swapping paths
	self.pmHighlightedMission = nil

	self:PathRefresh(nil, true)
	self:OnRedrawLevels(nil)
end

----------------------------------------------------------------------------------------------------------
-- Simple Event Handlers
----------------------------------------------------------------------------------------------------------

function PlayerPath:UpdateUIFromEvent() -- Arguments for this can vary
	self:PathRefresh(nil, true)
end

function PlayerPath:OnBigZoneBtnPress(wndHandler, wndControl)
	if not wndControl or not wndControl:GetData() then
		return 
	end
	self:HelperCheckTheFirstCategory(wndControl)
	self:PathRefresh(self.tLastZoneBtnPress, true)
	self.pmHighlightedMission = nil
	self.wndMissionLog:FindChild("ZoneDropdownBtn"):SetCheck(false)
	self.wndMissionLog:FindChild("ZoneDropdownContainer"):Show(false)
	self.wndMissionLog:FindChild("MissionList"):SetVScrollPos(0)
	self.wndMissionLog:FindChild("MissionList"):ArrangeChildrenVert(0)
	
end

function PlayerPath:HelperCheckTheFirstCategory(wndControl)--optional parameter
	if not wndControl then
		--came from the datachron, which has the missions from the current zone, which is
		--what is displayed when setting self.tLastZoneBtnPress to nil
		local tMissionListChildren = self.wndMissionLog:FindChild("MissionList"):GetChildren()
		if tMissionListChildren and tMissionListChildren[1] then
			local wndHeaderBtn = tMissionListChildren[1]:FindChild("HeaderBtn")
			if not wndHeaderBtn:IsChecked() then
				tMissionListChildren[1]:FindChild("HeaderBtn"):SetCheck(true)
			end
			self.tLastZoneBtnPress = nil
		end
	else
		--came from big zone button press
		self.tLastZoneBtnPress = wndControl:GetData()
	end
end

function PlayerPath:OnExpandCategories(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	--handles resizing
	self.strLastExpanded = wndControl:FindChild("HeaderBtnText"):GetText()

	self:PathRefresh(self.tLastZoneBtnPress, false)
end

function PlayerPath:OnCollapseCategories(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	local wndParent = wndControl:GetParent()
	local wndContainer = wndParent:FindChild("HeaderContainer")

	local nHeight = 0
	for idx, wndMission in pairs(wndContainer:GetChildren()) do
		nHeight = nHeight + wndMission:GetHeight()
	end
	
	local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
	wndParent:SetAnchorOffsets(nLeft, nTop, nRight, nBottom - nHeight)
	wndContainer:DestroyChildren()
	self.wndMissionLog:FindChild("MissionList"):ArrangeChildrenVert(0)
end

function PlayerPath:OnLootEpisodeRewards(wndHandler, wndControl)
	local pepEpisode = wndControl:GetData()

	if pepEpisode ~= nil then
		--episode:AcceptRewards()
		Event_FireGenericEvent("ToggleCodex")
		Event_FireGenericEvent("PlayerPath_EpisodeRewardsLootedLog")
	end
end

function PlayerPath:OnMissionHighlightTimer()
	if not self.pmHighlightedMission then
		return
	end

	local wnd = self.wndMissionLog:FindChild("MissionList"):FindChildByUserData(self.pmHighlightedMission)
	if wnd ~= nil then
		wnd:FindChild("MissionItemHighlightRunner"):Show(false)
	end
	self.pmHighlightedMission = nil
end

function PlayerPath:OnMissionHighlightMouseDown(wndHandler, wndControl)
	wndHandler:Show(false) -- wndHandler is "MissionItemHighlightRunner"
	self.pmHighlightedMission = nil
end

----------------------------------------------------------------------------------------------------------
-- Main Draw and Update Methods
----------------------------------------------------------------------------------------------------------

function PlayerPath:PathRefresh(pepEpisode, bFullRedraw) -- A lot of events route here, with the first argument not necessarily valid
	-- TODO Hardcoded formatting
	if not self.wndMissionLog then
		return
	end

	-- Use the passed in episode if possible, else just use the current
	local pepSelectedEpisode = pepEpisode
	if not pepSelectedEpisode then
		pepSelectedEpisode = PlayerPathLib.GetCurrentEpisode()
	end

	-- Populate Dropdown
	local tEpisodeList = PlayerPathLib.GetEpisodes()
	if not tEpisodeList then
		return
	end

	local nPercent = 0
	local strWorldZone = ""
	self.wndMissionLog:FindChild("ZoneDropdownList"):DestroyChildren()
	for key, pepCurrEpisode in pairs(tEpisodeList) do
		local wndBigZone = Apollo.LoadForm(self.xmlDoc, "BigZoneItem", self.wndMissionLog:FindChild("ZoneDropdownList"), self)
		strWorldZone = pepCurrEpisode:GetWorldZone() if not strWorldZone or strWorldZone == "" then strWorldZone = Apollo.GetString("PlayerPath_UntitledZone") end

		local tMissions = pepCurrEpisode:GetMissions()
		if #tMissions > 0 then nPercent = math.floor(100 * pepCurrEpisode:GetNumCompleted() / #tMissions) end
		wndBigZone:FindChild("BigZoneTitle"):SetText(strWorldZone .. " - " .. nPercent .. "%")
		wndBigZone:FindChild("BigZoneBtn"):SetData(pepCurrEpisode)

		-- Selected Episode specific formatting
		if pepSelectedEpisode and pepSelectedEpisode:GetWorldZone() == pepCurrEpisode:GetWorldZone() then
			self.wndMissionLog:FindChild("ZoneUpdateText"):SetText(strWorldZone .. " - " .. nPercent .. "%")
			wndBigZone:FindChild("BigZoneBtn"):SetCheck(true)
		end
	end
	self.wndMissionLog:FindChild("ZoneDropdownList"):ArrangeChildrenVert(0)

	-- Zone Description
	if pepSelectedEpisode and pepSelectedEpisode:GetSummary() then
		self.wndMissionLog:FindChild("EpisodeSummary"):SetText(pepSelectedEpisode:GetSummary())
	else
		self.wndMissionLog:FindChild("EpisodeSummary"):SetText("")
	end

	if not pepSelectedEpisode then
		return
	end

	-- Zone Rewards
	local bFoundAReward = false
	local bEpisodeRewardPending = false --tSelectedEpisode:HasPendingReward()
	self.wndMissionLog:FindChild("EpisodeRewardList"):DestroyChildren()
    for idx, tReward in ipairs(pepSelectedEpisode:GetRewards()) do
		bFoundAReward = true
        local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", self.wndMissionLog:FindChild("EpisodeRewardList"), self)
		self:DrawRewardItem(idx, wndReward, tReward)
		wndReward:FindChild("RewardLootedIcon"):Show(not bEdpisodeRewardPending and pepSelectedEpisode:IsComplete()) -- exists, but looted
    end

	self.wndMissionLog:FindChild("EpisodeRewardList"):Show(bFoundAReward)
	self.wndMissionLog:FindChild("EpisodeRewardList"):ArrangeChildrenVert()
	self.wndMissionLog:FindChild("EpisodeRewardRedeem"):SetData(pepSelectedEpisode)
	self.wndMissionLog:FindChild("EpisodeRewardRedeem"):Enable(bEpisodeRewardPending)

	self:DrawMissions(pepSelectedEpisode, bFullRedraw)
end

----------------------------------------------------------------------------------------------------------
-- Rank Levels
----------------------------------------------------------------------------------------------------------

function PlayerPath:OnTopRightResetBtn(wndHandler, wndControl)
	self.wndMissionLog:FindChild("TopRight"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self:OnRedrawLevels(nil)
end

function PlayerPath:OnTopRightUpOrDownClick(wndHandler, wndControl)
	self:OnRedrawLevels(wndHandler:GetData())
end

function PlayerPath:OnRedrawLevels(nArgPreviewLevel)
	if not self.wndMissionLog then
		return
	end

	local nCurrentXP = PlayerPathLib.GetPathXP()
	local nCurrentLevel = PlayerPathLib.GetPathLevel()
	local nLeftSideXP = PlayerPathLib.GetPathXPAtLevel(nCurrentLevel)

	local nNextLevel = math.min(knMaxLevel, nCurrentLevel + 1)
	if nArgPreviewLevel then
		nNextLevel = math.min(knMaxLevel, nArgPreviewLevel)
	end
	local nNextXP = PlayerPathLib.GetPathXPAtLevel(nNextLevel)

	local strXPNeededColor = "ffb80000"
	if nNextLevel > nCurrentLevel then
		self.wndMissionLog:FindChild("TopRightText"):SetTextColor(ApolloColor.new("ffb80000"))
	else
		self.wndMissionLog:FindChild("TopRightText"):SetTextColor(ApolloColor.new("ff82ffbb"))
		strXPNeededColor = "ff82ffbb"
	end

	if nCurrentLevel == (nNextLevel - 1) then
		self.wndMissionLog:FindChild("TopRightLabel"):SetText(Apollo.GetString("PlayerPath_NextRank"))
	else
		self.wndMissionLog:FindChild("TopRightLabel"):SetText(Apollo.GetString("PlayerPath_ViewedRank"))
	end

	local nUpBtn = nNextLevel + 1
	if nUpBtn == (knMaxLevel + 1) then
		nUpBtn = 1
	end -- These loop around

	local nDownBtn = nNextLevel - 1
	if nDownBtn == 0 then
		nDownBtn = knMaxLevel
	end

	self.wndMissionLog:FindChild("TopRightUpBtn"):SetData(nUpBtn)
	self.wndMissionLog:FindChild("TopRightDownBtn"):SetData(nDownBtn)

	self.wndMissionLog:FindChild("TopLeftText"):SetText(nCurrentLevel)
	local strXPValue = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff82ffbb\">%s</T>", nCurrentXP)
	local strXPLabel = String_GetWeaselString(Apollo.GetString("PlayerPath_PathXP"), strXPValue)
	self.wndMissionLog:FindChild("TopXPLeftText"):SetText(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff5f6662\">%s</T>", strXPLabel))

	self.wndMissionLog:FindChild("TopRightText"):SetText(nNextLevel)

	strXPValue = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strXPNeededColor, nNextXP)
	strXPLabel = String_GetWeaselString(Apollo.GetString("PlayerPath_NeededXP"), strXPValue)
	self.wndMissionLog:FindChild("TopXPRightText"):SetText(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff5f6662\">%s</T>", strXPLabel))

	self.wndMissionLog:FindChild("TopXPProgressBar"):SetMax(math.max(nCurrentXP - nLeftSideXP, nNextXP - nLeftSideXP))
	self.wndMissionLog:FindChild("TopXPProgressBar"):SetProgress(nCurrentXP - nLeftSideXP)
	self.wndMissionLog:FindChild("TopXPProgressBar"):EnableGlow(nCurrentXP ~= 0 and nCurrentXP - nLeftSideXP ~= (math.max(nCurrentXP - nLeftSideXP, nNextXP - nLeftSideXP)))

	self.wndMissionLog:FindChild("TopLeftBigIcon"):SetSprite(self:HelperFindTopBigIcon(nCurrentLevel, nCurrentLevel))
	self.wndMissionLog:FindChild("TopRightBigIcon"):SetSprite(self:HelperFindTopBigIcon(nNextLevel, nCurrentLevel))

	-- Rewards
	self.wndMissionLog:FindChild("TopLeftRewardsContainer"):DestroyChildren()
	self.wndMissionLog:FindChild("TopRightRewardsContainer"):DestroyChildren()

	local tPathData = PlayerPathLib.GetPathLevelData(nCurrentLevel)
	if tPathData then
		for idx, tCurrReward in pairs(tPathData.tRewards) do
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "TopRewardItem", self.wndMissionLog:FindChild("TopLeftRewardsContainer"), nil)
			self:DrawRewardItem(idx, wndCurr, tCurrReward)
		end
	end

	tPathData = PlayerPathLib.GetPathLevelData(nNextLevel)
	if tPathData then
		for idx, tCurrReward in pairs(tPathData.tRewards) do
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "TopRewardItem", self.wndMissionLog:FindChild("TopRightRewardsContainer"), nil)
			self:DrawRewardItem(idx, wndCurr, tCurrReward)
		end
	end

	self.wndMissionLog:FindChild("TopLeftRewardsContainer"):ArrangeChildrenVert(0)
	self.wndMissionLog:FindChild("TopRightRewardsContainer"):ArrangeChildrenVert(0)
end

----------------------------------------------------------------------------------------------------------
-- Missions
----------------------------------------------------------------------------------------------------------

function PlayerPath:DrawMissions(tSelectedEpisode, bFullRedraw)
	if bFullRedraw then
		if self.wndAvailable and self.wndAvailable:IsValid() then
			self.wndAvailable:Destroy()
		end
		
		self.wndAvailable = self:FactoryProduce(self.wndMissionLog:FindChild("MissionList"), "MissionContainerForm", Apollo.GetString("CRB_CallbackAvailable"))
		self.wndAvailable:FindChild("HeaderBtn"):SetCheck(true)
		
		if self.wndCompleted and self.wndCompleted:IsValid() then
			self.wndCompleted:Destroy()
		end
		
		self.wndCompleted = self:FactoryProduce(self.wndMissionLog:FindChild("MissionList"), "MissionContainerForm", Apollo.GetString("QuestCompleted"))
		
		self:HelperDrawCategoryMissions(self.wndAvailable, tSelectedEpisode)
		self:HelperDrawCategoryMissions(self.wndCompleted, tSelectedEpisode)
	else
		--REDRAW Some category
		local tMissionListChildren = self.wndMissionLog:FindChild("MissionList"):GetChildren()
		local wndRedraw = nil
		if self.strLastExpanded then
			local bAvailableContainer = self.strLastExpanded == Apollo.GetString("CRB_CallbackAvailable") 
			wndRedraw = bAvailableContainer and tMissionListChildren[1]  or tMissionListChildren[2]
		end
		
		if wndRedraw then
			self:HelperDrawCategoryMissions(wndRedraw, tSelectedEpisode)
			self.strLastExpanded = nil
		end
	end

	self:ResizeItems()
end

function PlayerPath:HelperDrawCategoryMissions(wndRedraw, tSelectedEpisode)
	if not wndRedraw then
		return
	end

	local strCategory = wndRedraw:FindChild("HeaderBtnText"):GetText()
	local bIsAvailableContainer = strCategory == Apollo.GetString("CRB_CallbackAvailable")
	local nComplete = 0
	local nToUnlock = 0
	local nAlreadyFound = 0

	local wndNewContainer = self:FactoryProduce(self.wndMissionLog:FindChild("MissionList"), "MissionContainerForm", strCategory)
	wndRedraw:FindChild("HeaderContainer"):DestroyChildren()

	local bSelectedFound = false
	local nAutoScrollHeight = -1 * (wndNewContainer:FindChild("HeaderBtn"):GetHeight() + knAutoScrollPadding)--initial padding
	for key, pmMission in ipairs(tSelectedEpisode:GetMissions()) do
		if pmMission:GetMissionState() == PathMission.PathMissionState_NoMission then
			nToUnlock = nToUnlock + 1
		else
			nAlreadyFound = nAlreadyFound + 1
			local bIsComplete = pmMission:IsComplete()
			if bIsComplete then
				nComplete = nComplete + 1
			end

			if (bIsComplete and not bIsAvailableContainer) or (not bIsComplete and bIsAvailableContainer) then
				local wndCurr = Apollo.LoadForm(self.xmlDoc, "MissionListItem", wndNewContainer:FindChild("HeaderContainer"), self)
				self:DrawMissionItem(wndCurr, pmMission)
				if not bSelectedFound then
					nAutoScrollHeight = nAutoScrollHeight + wndCurr:GetHeight()
				end
				if wndCurr:FindChild("MissionItemHighlightRunner"):IsShown() then
					bSelectedFound = true
				end	
			end
		end
	end
	
	--The scroll position should be set after the container has finished creating and resizing the categories.
	if bSelectedFound then
		self.nSetScrollPos = nAutoScrollHeight
	end

	wndNewContainer:Show((bIsAvailableContainer and nAlreadyFound - nComplete > 0) or (nComplete > 0))
	
	if bIsAvailableContainer then
		wndNewContainer:FindChild("HeaderBtn"):SetCheck(true)
	end

	self.wndMissionLog:FindChild("EmptyLabel"):Show(nAlreadyFound == 0)
	self.wndMissionLog:FindChild("EpisodeCompletedValue"):SetText(nComplete.."/"..nAlreadyFound)
	self.wndMissionLog:FindChild("EpisodeUndiscoveredValue"):SetText(nToUnlock)
end

function PlayerPath:ResizeItems()
	if self.wndAvailable:FindChild("HeaderBtn"):IsChecked() then
		local nHeight = 0
		for idx, wndCurr in pairs(self.wndAvailable:FindChild("HeaderContainer"):GetChildren()) do
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			nHeight = nHeight + (nBottom - nTop)
		end
		local nLeft, nTop, nRight, nBottom = self.wndAvailable:GetAnchorOffsets()
		self.wndAvailable:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 65)
		self.wndAvailable:FindChild("HeaderContainer"):ArrangeChildrenVert(0)
		self.wndAvailable:FindChild("HeaderContainer"):Show(true)
	else
		self.wndAvailable:FindChild("HeaderContainer"):Show(false)
	end

	if self.wndCompleted:FindChild("HeaderBtn"):IsChecked() then
		nHeight = 0
		for idx, wndCurr in pairs(self.wndCompleted:FindChild("HeaderContainer"):GetChildren()) do
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			nHeight = nHeight + (nBottom - nTop)
		end
		nLeft, nTop, nRight, nBottom = self.wndCompleted:GetAnchorOffsets()
		self.wndCompleted:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 65)
		self.wndCompleted:FindChild("HeaderContainer"):ArrangeChildrenVert(0)
		self.wndCompleted:FindChild("HeaderContainer"):Show(true)
	else
		self.wndCompleted:FindChild("HeaderContainer"):Show(false)
	end

	self.wndMissionLog:FindChild("MissionList"):ArrangeChildrenVert(0)
	
	if self.nSetScrollPos then
		self.wndMissionLog:FindChild("MissionList"):SetVScrollPos(self.nSetScrollPos)
		self.nSetScrollPos = nil
	end
end

function PlayerPath:DrawMissionItem(wnd, pmMission)
	local bComplete = pmMission:IsComplete()

	local strSummary = "???"
	local strExtraText = ""
	if bComplete and pmMission:GetCompletedString() ~= "" then
		strSummary = pmMission:GetCompletedString()
	elseif not bComplete and pmMission:GetSummary() ~= "" then
		strSummary = pmMission:GetSummary()
		strExtraText = pmMission:GetUnlockString()
	end
	
	local tSettlerReward = pmMission:GetSettlerMayorInfo()
	local tSettlerRewardSheriff = pmMission:GetSettlerSheriffInfo()	
	
	if tSettlerReward ~= nil and tSettlerReward.titleReward ~= nil  then
		wnd:FindChild("PathRewardIcon"):Show(true)
		wnd:FindChild("PathRewardIcon"):SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("Achievements_RewardTitle"), tSettlerReward.titleReward:GetTitle())))
	end
	
	if tSettlerRewardSheriff ~= nil and tSettlerRewardSheriff .arTitles ~= nil  then
		wnd:FindChild("PathRewardIcon"):Show(true)
		wnd:FindChild("PathRewardIcon"):SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("Achievements_RewardTitle"), tSettlerRewardSheriff .arTitles:GetTitle())))
	end
	
	if pmMission:IsComplete() then
		wnd:FindChild("MissionItemIcon"):SetSprite("MissionLog_TEMP:spr_TEMP_MLog_CheckMark") -- todo hardcoded formatting
	else
		wnd:FindChild("MissionItemIcon"):SetSprite(self:HelperComputeIconPath(pmMission))
	end
	
	wnd:SetData(pmMission)
	wnd:FindChild("MissionItemName"):SetText(pmMission:GetName())
				
	wnd:FindChild("MissionItemProgress"):Show(not bComplete)
	wnd:FindChild("MissionItemProgress"):SetTextColor(kcrNormalTextColor)
	wnd:FindChild("MissionItemProgress"):SetText(self:HelperComputeMissionProgress(pmMission))
	wnd:FindChild("MissionItemHighlightRunner"):Show(pmMission == self.pmHighlightedMission)
	wnd:FindChild("MissionItemSummary"):SetText(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</P>", strSummary))
	wnd:FindChild("MissionItemExtraText"):SetText(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBodyCyan\">%s</P>", strExtraText))

	-- Resize
	local nTextWidth1, nTextHeight1 = wnd:FindChild("MissionItemSummary"):SetHeightToContentHeight()
	local nTextWidth2, nTextHeight2 = wnd:FindChild("MissionItemExtraText"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wnd:GetAnchorOffsets()
	wnd:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nTextHeight1 + nTextHeight2 + 50)

	-- Shift Mission Extra Text below ItemSummary
	local nBottomOfItemSummary = nTextHeight1 + 40
	nLeft, nTop, nRight, nBottom = wnd:FindChild("MissionItemExtraText"):GetAnchorOffsets()
	wnd:FindChild("MissionItemExtraText"):SetAnchorOffsets(nLeft, nBottomOfItemSummary, nRight, nBottomOfItemSummary + nTextHeight2)

	return nHeight
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function PlayerPath:OnGenerateTooltip(wndHandler, wndControl, eType, arg1, arg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemData and arg1 then
		Tooltip.GetItemTooltipForm(self, wndControl, arg1, {bPrimary = true, bSelling = self.bVendorOpen, itemCompare = arg1:GetEquippedItemForItemType()}, arg2)
	elseif eType == Tooltip.TooltipGenerateType_Reputation then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1:GetMoneyString(), CColor.new(1, 1, 1, 1), "CRB_InterfaceMedium")
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
	end

    if xml then
        wndControl:SetTooltipDoc(xml)
    end
end

function PlayerPath:HelperComputeMissionProgress(pmMission)
	local strResult = ""
	local eMissionType = pmMission:GetType()
	local nNumNeeded = pmMission:GetNumNeeded()
	local nNumCompleted = pmMission:GetNumCompleted()

	if self.ePlayerPath == PlayerPathLib.PlayerPathType_Soldier then
		if eMissionType == PathMission.PathMissionType_Soldier_Holdout and pmMission:GetSoldierHoldout() then
			local seEvent = pmMission:GetSoldierHoldout()
			local eType = seEvent:GetType()
			if eType == PathMission.PathSoldierEventType_Holdout 
				or eType == PathMission.PathSoldierEventType_Defend 
				or eType == PathMission.PathSoldierEventType_TowerDefense
				or eType == PathMission.PathSoldierEventType_StopTheThieves then
				strResult = String_GetWeaselString(Apollo.GetString("ChallengeReward_Multiplier"), seEvent:GetWaveCount())
			elseif eType == PathMission.PathSoldierEventType_Timed 
				or eType == PathMission.PathSoldierEventType_TimedDefend 
				or eType == PathMission.PathSoldierEventType_WhackAMoleTimed
				or eType == PathMission.PathSoldierEventType_StopTheThievesTimed then
				strResult = self:HelperCalcTime(seEvent:GetMaxTime()/1000)
			end
		elseif nNumNeeded > 0 then
			strResult = nNumCompleted .. "/" .. nNumNeeded
		end

	elseif self.ePlayerPath == PlayerPathLib.PlayerPathType_Explorer then

		if eMissionType == PathMission.PathMissionType_Explorer_ExploreZone then
			if pmMission:IsComplete() then
				strResult = String_GetWeaselString(Apollo.GetString("CRB_Percent"), 100)
			else
				strResult = String_GetWeaselString(Apollo.GetString("CRB_Percent"), pmMission:GetNumCompleted())
			end
		elseif nNumNeeded > 0 then
			strResult = nNumCompleted .. "/" .. nNumNeeded
		end

	elseif self.ePlayerPath == PlayerPathLib.PlayerPathType_Settler then

		if eMissionType == PathMission.PathMissionType_Settler_Hub or PathMission.PathMissionType_Settler_Infrastructure then
			strResult = nNumCompleted .. "/" .. nNumNeeded
		end
	end

	return strResult
end

function PlayerPath:HelperComputeIconPath(pmMission)
	local eType = pmMission:GetType()
	local eSubType = pmMission:GetSubType()

	-- TODO: Hardcoded Sprite Referencing
	local strIconPath = ""

	if ktPathMissionTypeSprites[self.ePlayerPath][eType] then
		strIconPath = ktPathMissionTypeSprites[self.ePlayerPath][eType]
	elseif (eType == PathMission.PathMissionType_Scientist_Scan or
		eType == PathMission.PathMissionType_Scientist_ScanChecklist or
		eType == PathMission.PathMissionType_Soldier_Holdout) then

		strIconPath = ktPathMissionSubtypeSprites[self.ePlayerPath][eSubType]
	else
		strIconPath = ktPathMissionTypeSprites[self.ePlayerPath]["default"]
	end
	return strIconPath
end

function PlayerPath:DrawRewardItem(idx, wndReward, tReward) -- TODO: This is for zone completion, remove it when possible
	if not wndReward or not tReward then return end

	if tReward.eType == PlayerPathLib.PathRewardType_Item then
		wndReward:FindChild("RewardItemName"):SetTextColor(karEvalColors[tReward.itemReward:GetItemQuality()])
		wndReward:FindChild("RewardItemName"):SetText(tReward.itemReward:GetName())
		wndReward:FindChild("RewardItemIcon"):SetItemInfo(tReward.itemReward, tReward.nCount)
	elseif tReward.eType == PlayerPathLib.PathRewardType_Spell then
		wndReward:FindChild("RewardItemName"):SetText(tReward.splReward:GetName())
		wndReward:FindChild("RewardItemIcon"):SetSpellInfo(tReward.splReward)
		wndReward:FindChild("RewardItemIcon"):SetTooltip("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">"..tReward.splReward:GetName().."</P>")
	elseif tReward.eType == PlayerPathLib.PathRewardType_Quest then
		wndReward:FindChild("RewardItemName"):SetText(tReward.queReward:GetTitle())
		wndReward:FindChild("RewardItemIcon"):SetSprite("ClientSprites:UI_Temp_Quest")
		wndReward:FindChild("RewardItemIcon"):SetTooltip("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">"..tReward.queReward:GetTitle().."</P>")
	elseif tReward.eType == PlayerPathLib.PathRewardType_Title then
		wndReward:FindChild("RewardItemName"):SetText(String_GetWeaselString(Apollo.GetString("PlayerPath_Title"), tReward.strTitleName))
		wndReward:FindChild("RewardItemIcon"):SetSprite("ClientSprites:Icon_ItemMisc_letter_0001")
		wndReward:FindChild("RewardItemIcon"):SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s</P>", String_GetWeaselString(Apollo.GetString("PlayerPath_Title"), tReward.strTitleName)))
	elseif tReward.eType == PlayerPathLib.PathRewardType_ScanBot then
		wndReward:FindChild("RewardItemName"):SetText(String_GetWeaselString(Apollo.GetString("PlayerPath_Scanbot"), tReward.sbpReward:GetName()))
		wndReward:FindChild("RewardItemIcon"):SetSprite("ClientSprites:Icon_ItemMisc_letter_0001")
		wndReward:FindChild("RewardItemIcon"):SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s</P>", String_GetWeaselString(Apollo.GetString("PlayerPath_Title"), tReward.sbpReward:GetName())))
	end
end

function PlayerPath:HelperFindTopBigIcon(nArgLevel, nArgCurrentLevel)
	-- HACK: Rather than build an array, we're just going to rely on filenames
	local strPath = ""
	if self.ePlayerPath == PlayerPathLib.PlayerPathType_Settler then strPath = "Settler"
	elseif self.ePlayerPath == PlayerPathLib.PlayerPathType_Soldier then strPath = "Soldier"
	elseif self.ePlayerPath == PlayerPathLib.PlayerPathType_Explorer then strPath = "Explorer"
	elseif self.ePlayerPath == PlayerPathLib.PlayerPathType_Scientist then strPath = "Scientist"
	end

	local strRankCategory = "_MissionRank_03"
	if nArgLevel < 10 then
		strRankCategory = "_MissionRank_01"
	elseif nArgLevel < 20 then
		strRankCategory = "_MissionRank_02"
	end

	local strDisabledOrNot = ""
	if nArgLevel > nArgCurrentLevel then
		strDisabledOrNot = "_Disabled"
	end

	return "Icon_Windows_UI_CRB_" .. strPath .. strRankCategory .. strDisabledOrNot
end

function PlayerPath:HelperCalcTime(fSeconds)
	if fSeconds <= 0 then return "" end
	local nSecs = math.floor(fSeconds % 60)
	local nMins = math.floor(fSeconds / 60)
	return string.format("%d:%02d", nMins, nSecs)
end

function PlayerPath:FactoryProduce(wndParent, strFormName, strCategoryName)
	local wndNew = wndParent:FindChildByUserData(strCategoryName)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(strCategoryName)
		wndNew:FindChild("HeaderBtnText"):SetText(strCategoryName)
	end
	
	return wndNew
end

----------------------------------------------------------------------------------------------------------
-- Global
----------------------------------------------------------------------------------------------------------
local PlayerPathInstance = PlayerPath:new()
PlayerPathInstance:Init()
