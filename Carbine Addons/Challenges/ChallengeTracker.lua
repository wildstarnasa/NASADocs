-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "ChallengesLib"

local kstrChallengeQuesttMarker = "000ChallengeContent"
local kstrLightGrey = "ffb4b4b4"

local knUXHideIfTooMany = 3 --By default lets minimize optional categories if there's more than 2 children so it's not overwhelming.
local knXCursorOffset = 10
local knYCursorOffset = 25

local kstrObjectiveType =  Apollo.GetString("Challenges")

local karTypeToFormattedString =
{
	[ChallengesLib.ChallengeType_Combat] 				= "Challenges_CombatChallenge",
	[ChallengesLib.ChallengeType_Ability] 					= "Challenges_AbilityChallenge",
	[ChallengesLib.ChallengeType_General] 				= "Challenges_GeneralChallenge",
	[ChallengesLib.ChallengeType_Item] 					= "Challenges_ItemChallenge",
	[ChallengesLib.ChallengeType_ChecklistActivate] 	= "Challenges_ActivateChallenge",
}

local karTierIdxToWindowName =
{
	[0] = "",
	[1] = "Bronze",
	[2] = "Silver",
	[3] = "Gold",
}

local karTierIdxToTextColor =
{
	[0] = "UI_WindowTextDefault",
	[1] = "xkcdBronze",
	[2] = "xkcdSilver",
	[3] = "xkcdPaleGold",
}

local karTierIdxToStarSprite =
{
	[0] = "Challenges:sprChallenges_starBlack",
	[1] = "Challenges:sprChallenges_starBronze",
	[2] = "Challenges:sprChallenges_starSilver",
	[3] = "Challenges:sprChallenges_starGold",
}

local karTierIdxToMedalSprite =
{
	[0] = "",
	[1] = "CRB_ChallengeTrackerSprites:sprChallengeTierBronze32",
	[2] = "CRB_ChallengeTrackerSprites:sprChallengeTierSilver32",
	[3] = "CRB_ChallengeTrackerSprites:sprChallengeTierGold32",
}

local ChallengeTracker = {}
function ChallengeTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	
	o.tMinimized = { }
	o.tCategories = { }
	o.tHidden = { }
	
	o.bFilterLimit = true
	o.bFilterDistance = true
	o.nMaxMissionLimit = 3
	o.nMaxMissionDistance = 300
	o.bShowChallenges = true
	o.tChallengeCompare = { }
	o.tLootChallenges = { }
	
    return o
end

function ChallengeTracker:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- ChallengeTracker OnLoad
-----------------------------------------------------------------------------------------------

function ChallengeTracker:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ChallengeTracker.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ChallengeTracker:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	return
	{
		tMinimized 				 = self.tMinimized,
		tHidden					 = self.tHidden,
		bShowChallenges		 = self.bShowChallenges,
		nMaxMissionLimit		 = self.nMaxMissionLimit,
		nMaxMissionDistance = self.nMaxMissionDistance,
		bFilterLimit				 = self.bFilterLimit,
		bFilterDistance		 = self.bFilterDistance,
	}
end

function ChallengeTracker:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	if tSavedData.tMinimized ~= nil then
		self.tMinimized = tSavedData.tMinimized
	end
	
	if tSavedData.tHidden ~= nil then
		self.tHidden = tSavedData.tHidden
	end
	
	if tSavedData.bShowChallenges ~= nil then
		self.bShowChallenges = tSavedData.bShowChallenges
	end
	
	if tSavedData.nMaxMissionLimit ~= nil then
		self.nMaxMissionLimit = tSavedData.nMaxMissionLimit
	end
	
	if tSavedData.nMaxMissionDistance ~= nil then
		self.nMaxMissionDistance = tSavedData.nMaxMissionDistance
	end
	
	if tSavedData.bFilterLimit ~= nil then
		self.bFilterLimit = tSavedData.bFilterLimit
	end
	
	if tSavedData.bFilterDistance ~= nil then
		self.bFilterDistance = tSavedData.bFilterDistance
	end
end

function ChallengeTracker:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Event_FireGenericEvent("ObjectiveTracker_RequestParent")

	Apollo.RegisterEventHandler("ObjectiveTrackerLoaded",		"OnObjectiveTrackerLoaded", self)
	Apollo.RegisterEventHandler("ObjectiveTracker_ButtonAdded", "OnObjectiveTracker_ButtonAdded", self)
	
	Apollo.RegisterEventHandler("ChallengeUpdated",				"OnChallengeUpdated", self)
	Apollo.RegisterEventHandler("ChallengeLeftArea", 				"OnChallengeUpdated", self)
	
	Apollo.RegisterEventHandler("ChallengeActivate", 				"OnChallengeActivateSound", self)
	Apollo.RegisterEventHandler("ChallengeAbandon", 				"OnChallengeAbandonSound", self)
	Apollo.RegisterEventHandler("ChallengeFailSound", 				"OnChallengeFailSound", self)
	Apollo.RegisterEventHandler("ChallengeCompletedSound", 	"OnChallengeCompletedSound", self)
	Apollo.RegisterEventHandler("ChallengeTierAchieved", 		"OnChallengeTierAchieved", self)
	
	Apollo.RegisterEventHandler("ToggleShowChallenges", 	"OnToggleShowChallenges", self)
	Apollo.RegisterEventHandler("ToggleChallengeOptions", 	"OnToggleChallengeOptions", self)
	
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 	"OnTutorial_RequestUIAnchor", self)
	
	self.wndActiveChallenges = Apollo.LoadForm(self.xmlDoc, "ActiveChallenges", "FixedHudStratumLow", self)
	self.wndActiveChallenges:Show(false)
end

function ChallengeTracker:OnObjectiveTrackerLoaded(wndForm)
	if not wndForm or not wndForm:IsValid() then
		return
	end
	
	if self.wndTracker then
		local wndParent = self.wndTracker:GetParent()
		
		if not wndParent or not wndParent:IsValid() or wndParent ~= wndForm then
			self.wndTracker:Destroy()
			self.wndTracker = nil
		end
	end
	
	if not self.wndTracker then
		self.wndTracker = Apollo.LoadForm(self.xmlDoc, "Container", wndForm, self)
		
		local strKey = self.wndTracker:FindChild("Title"):GetText()
		self.wndTracker:FindChild("MinimizeBtn"):SetData(strKey)
		self.wndTracker:FindChild("MinimizeBtn"):SetCheck(self.tMinimized[strKey])
		self.wndTracker:FindChild("MinimizeBtn"):Show(self.tMinimized[strKey])
		self.wndTracker:SetData(kstrChallengeQuesttMarker)
		self.wndTrackerContent = self.wndTracker:FindChild("Content")
		self.knInitialEpisodeGroupHeight = self.wndTracker:GetHeight()
		
		self.wndTrackerActive = Apollo.LoadForm(self.xmlDoc, "Category", self.wndTrackerContent, self)
		self.wndTrackerActive:SetData({strKey = Apollo.GetString("QuestLog_Active"), bCanHide = false})
		self.wndTrackerActiveContent = self.wndTrackerActive:FindChild("Content")
		
		self.wndTrackerLoot = Apollo.LoadForm(self.xmlDoc, "Category", self.wndTrackerContent, self)
		self.wndTrackerLoot:SetData({strKey = Apollo.GetString("Challenges_LootRewards"), bCanHide = false})
		self.wndTrackerLootContent = self.wndTrackerLoot:FindChild("Content")
		
		self.wndTrackerAvailable = Apollo.LoadForm(self.xmlDoc, "Category", self.wndTrackerContent, self)
		self.wndTrackerAvailable:SetData({strKey = Apollo.GetString("ChallengeUnlockedHeader"), bCanHide = true})
		self.wndTrackerAvailableContent = self.wndTrackerAvailable:FindChild("Content")
		
		self.wndTrackerRepeat = Apollo.LoadForm(self.xmlDoc, "Category", self.wndTrackerContent, self)
		self.wndTrackerRepeat:SetData({strKey = Apollo.GetString("Challenges_Repeatable"), bCanHide = true})
		self.wndTrackerRepeatContent = self.wndTrackerRepeat:FindChild("Content")
		
		local tData = {
			["strAddon"]				= kstrObjectiveType,
			["strEventMouseLeft"]	= "ToggleShowChallenges", 
			["strEventMouseRight"]	= "ToggleChallengeOptions", 
			["strIcon"]					= "spr_ObjectiveTracker_IconChallenge",
			["strDefaultSort"]			= kstrChallengeQuesttMarker,
		}
		
		Apollo.RegisterEventHandler("ObjectiveTrackerUpdated", "TrackChallenges", self)
		Event_FireGenericEvent("ObjectiveTracker_NewAddOn", tData)
		self:TrackChallenges()
	end
end

function ChallengeTracker:TrackChallenges()
	if not self.wndTracker or not self.wndTracker:IsValid() then
		return
	end
	
	self.wndTrackerActiveContent:DestroyChildren()
	self.wndTrackerLootContent:DestroyChildren()
	self.wndTrackerAvailableContent:DestroyChildren()
	self.wndTrackerRepeatContent:DestroyChildren()
	
	-- Inline Sort Method
	local function SortChallenges(clgA, clgB) -- GOTCHA: This needs to be declared before it's used
		--local bQuestTrackerByDistance = g_InterfaceOptions and g_InterfaceOptions.Carbine.bQuestTrackerByDistance
		if clgA:GetTimer() == 0 and clgB:GetTimer() == 0 then
			return clgA:GetDistance() < clgB:GetDistance()
		else
			return clgA:GetTimer() < clgB:GetTimer()
		end
	end
	
	self.tActiveChallenges = {}
	local nChallengesShown = 0
	local nChallengesFiltered = 0
	local nLootableChallenges = 0
	local tChallengesSorted = {}
	local tChallenges = ChallengesLib.GetActiveChallengeList()
	for _, clgCurrent in pairs(tChallenges) do
		if clgCurrent:GetTimer() then
			table.insert(tChallengesSorted, clgCurrent)
		end
	end
	
	table.sort(tChallengesSorted, SortChallenges)
	for _, clgCurrent in ipairs(tChallengesSorted) do
		local nZoneId = clgCurrent:GetZoneInfo() and clgCurrent:GetZoneInfo().idZone or 0
		
		--and GameLib.IsZoneInZone(GameLib.GetCurrentZoneId(), nZoneId)
		local wndParent = nil
	
		if clgCurrent:IsActivated() then
			wndParent = self.wndTrackerActiveContent
			table.insert(self.tActiveChallenges, clgCurrent)
			
			self.tLootChallenges[clgCurrent:GetId()] = clgCurrent
		elseif clgCurrent:ShouldCollectReward() then
			nLootableChallenges = nLootableChallenges + 1
			wndParent = self.wndTrackerLootContent
		else
			if (not self.bFilterLimit or nChallengesFiltered < self.nMaxMissionLimit) and (not self.bFilterDistance or clgCurrent:GetDistance() < self.nMaxMissionDistance) then
				wndParent = clgCurrent:GetCompletionCount() > 0 
					and self.wndTrackerRepeatContent 
					or self.wndTrackerAvailableContent
			
				nChallengesFiltered = nChallengesFiltered + 1
			end
		end
		
		if wndParent then
			nChallengesShown = nChallengesShown + self:BuildTrackerListItem(clgCurrent, wndParent)
		end
	end
	
	self:BuildContainer(self.wndTrackerActive)
	self:BuildContainer(self.wndTrackerLoot)
	self:BuildContainer(self.wndTrackerAvailable)
	self:BuildContainer(self.wndTrackerRepeat)
	self:BuildActiveListItems()
	
	self:ResizeContainer(self.wndTracker)
	self.wndTracker:Show(nChallengesShown > 0 and self.bShowChallenges)
	
	local tData = {
		["strAddon"]	= kstrObjectiveType,
		["strText"]		= nChallengesShown,
		["bChecked"]	= self.bShowChallenges,
	}

	Event_FireGenericEvent("ObjectiveTracker_UpdateAddOn", tData)
end

function ChallengeTracker:OnObjectiveTracker_ButtonAdded(tData)
	if not tData or tData.strAddon ~= kstrObjectiveType then
		return
	end

	self.tObjectiveTrackerBtnRect = tData.tRect
end

function ChallengeTracker:BuildContainer(wndContainer)
	local tData = wndContainer:GetData()
	local strKey = tData.strKey
	local nChallengesShown = #wndContainer:FindChild("Content"):GetChildren()
	local strTitle = nChallengesShown ~= 1 and string.format("%s [%s]", strKey, nChallengesShown) or strKey
	local bMinimize = false
	
	if self.tMinimized[strKey] == nil then
		bMinimize = tData.bCanHide and #wndContainer:FindChild("Content"):GetChildren() > knUXHideIfTooMany
	else
		bMinimize = self.tMinimized[strKey]
	end
	
	self.tCategories[strKey] = {strKey = tData.strKey, bCanHide=tData.bCanHide, strTitle = strTitle}
	wndContainer:FindChild("Title"):SetText(strTitle)
	wndContainer:FindChild("MinimizeBtn"):SetData(strKey)
	wndContainer:FindChild("MinimizeBtn"):SetCheck(bMinimize)
	wndContainer:FindChild("MinimizeBtn"):Show(bMinimize)
	self:ResizeContainer(wndContainer:FindChild("Content"))
	self:ResizeContainer(wndContainer)

	wndContainer:Show(nChallengesShown > 0)
end

function ChallengeTracker:BuildActiveListItems()
	local wndContent = self.wndActiveChallenges:FindChild("Content")
	wndContent:DestroyChildren()
	
	for _, clgCurrent in pairs(self.tActiveChallenges) do
		local wndListItem = Apollo.LoadForm(self.xmlDoc, "ActiveChallenge", wndContent, self)
		wndListItem:SetData(clgCurrent:GetId())
		wndListItem:FindChild("Description"):SetData(clgCurrent)
		
		self:UpdateActiveListItem(wndListItem)
	end
	
	wndContent:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.Middle)
	self.wndActiveChallenges:Show(#self.tActiveChallenges > 0)
end

function ChallengeTracker:UpdateActiveListItem(wndListItem)
	if not wndListItem or not wndListItem:IsValid() then
		return
	end
	
	local clgCurrent = wndListItem:FindChild("Description"):GetData()
	wndListItem:FindChild("CloseBtn"):SetData(clgCurrent:GetId())
	
	local nTotal = clgCurrent:GetTotalCount()
	local nCurrent = clgCurrent:GetCurrentCount()
	local nCurrentTier = clgCurrent:GetCurrentTier() + 1
	local nTimeLimit = clgCurrent:GetDuration()
	local nCurrentTime = clgCurrent:GetTimer()
	local nTimeElappsed = math.abs(nCurrentTime - nTimeLimit)
	local nTimeLeftArea = ChallengesLib.GetTimeRemaining(clgCurrent:GetId(), ChallengesLib.ChallengeTimerFlags_LeftArea)
	
	local strLeftArea = nTimeLeftArea > 0 and nTimeLeftArea < nCurrentTime and string.format("\n\n%s %s", Apollo.GetString("ChallengeLeftArea"), self:HelperConvertToTime(nTimeLeftArea)) or ""
	local strDesc = clgCurrent:GetDescription() .. strLeftArea
	wndListItem:FindChild("Timer"):SetText(self:HelperConvertToTime(nCurrentTime))
	wndListItem:FindChild("Description"):SetText(strDesc)
	
	local wndTimeRemaining = wndListItem:FindChild("TimeRemaining")
	wndTimeRemaining:SetMax(nTimeLimit)
	
	if math.abs(nCurrentTime - wndTimeRemaining:GetProgress()) > 100 then
		wndTimeRemaining:SetProgress(nCurrentTime)
	else
		wndTimeRemaining:SetProgress(nCurrentTime, 1.5)
	end
	
	local bTieredChallenge = clgCurrent:GetAllTierCounts() and #clgCurrent:GetAllTierCounts() > 1
	local tTimerDeltas = {}
	for iTierIdx = #clgCurrent:GetAllTierCounts(), 0, -1 do
		local nCurrTier = clgCurrent:GetAllTierCounts()[iTierIdx+1] and clgCurrent:GetAllTierCounts()[iTierIdx+1]["nGoalCount"] or 0
		
		tTimerDeltas[iTierIdx] = nCurrTier
	end
	
	for iTierIdx, tCurrTier in pairs(clgCurrent:GetAllTierCounts()) do
		local bShowTimedTier = bTieredChallenge
		local wndCurrTier = wndListItem:FindChild(karTierIdxToWindowName[iTierIdx] or "")
		if not wndCurrTier then
			break
		end

		local nTierLimit = tCurrTier["nGoalCount"]
		local wndLimit = wndCurrTier:FindChild("Limit")
		local strText = ""
		if clgCurrent:IsTimeTiered() then
			local nTierTimeRemaining = math.max(0, nTimeLimit-nTierLimit-nTimeElappsed)
			bShowTimedTier = nTierTimeRemaining > 1
			strText = self:HelperConvertToTime(nTierTimeRemaining, true)
			
			nCurrentTier = nTimeElappsed < nTimeLimit - nTierLimit and iTierIdx or nCurrentTier
			if iTierIdx == nCurrentTier then
				nTotal = math.abs(nTimeLimit - tTimerDeltas[iTierIdx]  - nTierLimit)
				nCurrent = math.abs(nTimeLimit - nTierLimit - nTimeElappsed)
			end
		elseif iTierIdx == (nCurrentTier) then -- Active tier
			strText = nTierLimit == 100 and String_GetWeaselString(Apollo.GetString("CRB_Percent"), nTierLimit) or nTierLimit
		else -- Implict not active
			strText = nTierLimit == 100 and "" or nTierLimit
		end
		
		wndLimit:SetText(strText)
		--wndCurrTier:FindChild("Completed"):Show(clgCurrent:GetCurrentTier() >= iTierIdx)
		wndCurrTier:Show(bShowTimedTier and bTieredChallenge and #clgCurrent:GetAllTierCounts() >= iTierIdx)
	end
	
	--nCurrentTier = nTimeLeftArea > 0 and 0 or nCurrentTier
	wndListItem:FindChild("CurrentMedal"):SetSprite(bTieredChallenge and karTierIdxToMedalSprite[nCurrentTier] or "")
	
	local wndCurrentStatus = wndListItem:FindChild("CurrentStatus")
	if nCurrent == 0 and nTotal == 1 then
		wndCurrentStatus:SetText("")
	elseif nCurrent == 0 and nTotal == 0 then
		wndCurrentStatus:SetText("")
	elseif nTotal == 100 then
		wndCurrentStatus:SetText(String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nCurrent / nTotal * 100)))
	elseif clgCurrent:IsTimeTiered() then
		wndCurrentStatus:SetText(self:HelperConvertToTime(nCurrent))
	else
		wndCurrentStatus:SetText(string.format("%s / %s", nCurrent, nTotal))
	end
	
	wndCurrentStatus:SetTextColor(ApolloColor.new(karTierIdxToTextColor[nCurrentTier]))
	
	local wndMedalStanding = wndListItem:FindChild("MedalStanding")
	wndMedalStanding:SetEmptySprite(karTierIdxToStarSprite[nCurrentTier-1])
	wndMedalStanding:SetFillSprite(karTierIdxToStarSprite[nCurrentTier])
	wndMedalStanding:SetMax(nTotal)
	wndMedalStanding:SetProgress(nCurrent)
end

function ChallengeTracker:BuildTrackerListItem(clgCurrent, wndParent)
	local strKey = wndParent:GetParent():GetData().strKey
	
	if strKey and not self.tHidden[strKey] then
		if not self.bShowChallenges then return 1 end
		
		local wndListItem = Apollo.LoadForm(self.xmlDoc, "ListItem", wndParent, self)
			
		wndListItem:SetData(clgCurrent:GetId())
		wndListItem:FindChild("ListItemBigBtn"):SetData(clgCurrent)
		wndListItem:FindChild("ListItemGearBtn"):SetData(clgCurrent)
		
		self:OnChallengeUpdated(clgCurrent:GetId())
		return 1
	end
	
	return 0
end

function ChallengeTracker:UpdateTrackerListItem(wndListItem)
	if not wndListItem or not wndListItem:IsValid() then
		return
	end
	
	local clgCurrent = wndListItem:FindChild("ListItemBigBtn"):GetData()
	local strChallengeType = Apollo.GetString(karTypeToFormattedString[clgCurrent:GetType()])
	local strTime =  clgCurrent:GetTimer() > 0 and "("..self:HelperConvertToTime(clgCurrent:GetTimer())..") " or ""	
	local strTooltip = string.format(
		"<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloTitle\">%s%s</P>"..
		"<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>",
		strChallengeType, 
		Apollo.GetString("Chat_ColonBreak"), 
		clgCurrent:GetDescription()
	)
	
	local strSubTitle = wndListItem:GetParent() == self.wndTrackerActiveContent and strTooltip or ""
	wndListItem:FindChild("ListItemBigBtn"):SetData(clgCurrent)
	wndListItem:FindChild("ListItemBigBtn"):SetTooltip(strTooltip)
	wndListItem:FindChild("ListItemName"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\""..kstrLightGrey.."\">"..strTime..clgCurrent:GetName().."</P>")
	wndListItem:FindChild("ListItemSubtitle"):SetAML(strSubTitle)
	wndListItem:FindChild("ListItemIcon"):SetSprite(self:CalculateIconPath(clgCurrent:GetType()))
	wndListItem:FindChild("ListItemHasLoot"):Show(clgCurrent:ShouldCollectReward())
	
	wndListItem:FindChild("ListItemSpell"):Show(clgCurrent:GetType() == ChallengesLib.ChallengeType_Ability)
	if clgCurrent:GetType() == ChallengesLib.ChallengeType_Ability then
		wndListItem:FindChild("ListItemSpell"):SetContentId(clgCurrent)
	end
	
	-- Resize
	local nNameWidth, nNameHeight = wndListItem:FindChild("ListItemName"):SetHeightToContentHeight()
	local nTitleWidth, nTitleHeight = wndListItem:FindChild("ListItemSubtitle"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndListItem:GetAnchorOffsets()
	wndListItem:SetAnchorOffsets(nLeft, nTop, nRight, math.max(nTop, nTop + nNameHeight + nNameHeight + nTitleHeight))
end

function ChallengeTracker:ResizeContainer(wndContainer)
	if not wndContainer or not wndContainer:IsValid() then
		return 0
	end
	
	local nOngoingGroupHeight = self.bShowChallenges and self.knInitialEpisodeGroupHeight or 0
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

function ChallengeTracker:CalculateIconPath(eType)
    local strIconPath = "CRB_GuildSprites:sprChallengeTypeGenericTiny"
	
	if eType == ChallengesLib.ChallengeType_Combat then     -- Combat
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeKillTiny"
	elseif eType == ChallengesLib.ChallengeType_Ability then -- Ability
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeSkillTiny"
	elseif eType == ChallengesLib.ChallengeType_General then -- General
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeGenericTiny"
	elseif eType == ChallengesLib.ChallengeType_Item then -- Items
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeLootTiny"
	end
    
	return strIconPath
end

function ChallengeTracker:HelperConvertToTime(nInSeconds, bReturnZero)
	if not bReturnZero and nInSeconds == 0 then
		return ""
	end
	
	local strResult = ""
	local nHours = math.floor(nInSeconds / 3600)
	local nMins = math.floor(nInSeconds / 60 - (nHours * 60))
	local nSecs = string.format("%02.f", math.floor(nInSeconds - (nHours * 3600) - (nMins * 60)))

	if nHours ~= 0 then
		strResult = nHours .. ":" .. nMins .. ":" .. nSecs
	else
		strResult = nMins .. ":" .. nSecs
	end

	return strResult
end

function ChallengeTracker:OnChallengeUpdated(nChallengeId)
	local wndTracked = self.wndTrackerContent:FindChildByUserData(nChallengeId)
	local wndActive = self.wndActiveChallenges:FindChildByUserData(nChallengeId)
	
	if wndTracked and wndTracked:IsValid() then
		local clgCurrent = wndTracked:FindChild("ListItemBigBtn"):GetData()
		local tPrevious = self.tChallengeCompare[clgCurrent:GetId()]
		
		--determine if we need to resort or change parents. note the things being checked here should
		--match what's being done to determine the parent.
		local	bRedrawAll = false
		if tPrevious then
			bRedrawAll = clgCurrent:IsActivated() ~= tPrevious.bIsActivated
			or clgCurrent:ShouldCollectReward() ~= tPrevious.bShouldCollectReward
			or clgCurrent:GetCompletionCount() ~= tPrevious.bGetCompletionCount
			or (clgCurrent:GetTimer() == 0 and tPrevious.nCurrentTime ~= 0)
		end
		
		self.tChallengeCompare[clgCurrent:GetId()] = 
		{
			bIsActivated				= clgCurrent:IsActivated(),
			bShouldCollectReward	= clgCurrent:ShouldCollectReward(),
			bGetCompletionCount	= clgCurrent:GetCompletionCount(),
			nCurrentTime				= clgCurrent:GetTimer(),
		}
		
		if bRedrawAll then
			self:TrackChallenges()
			return
		else
			self:UpdateTrackerListItem(wndTracked)
			if wndActive and wndActive:IsValid() then
				self:UpdateActiveListItem(wndActive)
			end
		end
	else
		self:TrackChallenges()
	end
	
	if not self.unitPlayer or not self.unitPlayer:IsValid() then
		self.unitPlayer = GameLib.GetPlayerUnit()
	end
	
	local bIsInCombat = self.unitPlayer ~= nil and self.unitPlayer:IsInCombat()
	if not bIsInCombat and #self.tActiveChallenges == 0 then
		for _, clgCurrent in pairs(self.tLootChallenges) do
			self:LootChallenge(clgCurrent)
		end
	end
end

function ChallengeTracker:LootChallenge(clgCurrent)
	local nChallengeId = clgCurrent:GetId()
	
	if clgCurrent:ShouldCollectReward() then
		Event_FireGenericEvent("ChallengeRewardShow", nChallengeId)
	end
						
	if self.tLootChallenges[nChallengeId] then
		self.tLootChallenges[nChallengeId] = nil
	end
end

function ChallengeTracker:OnGearBtn(wndHandler, wndControl, eMouseButton)
	if not wndHandler or not wndHandler:GetData() then
		return
	end
	
	self:DrawContextMenu(wndHandler:GetData())
end

function ChallengeTracker:OnListItemMouseEnter(wndHandler, wndControl)
	local bHasMouse = wndHandler:ContainsMouse()
	wndHandler:GetParent():FindChild("ListItemGearBtn"):Show(bHasMouse)
	
	if bHasMouse then
		Apollo.RemoveEventHandler("ObjectiveTrackerUpdated", self)
	end
end

function ChallengeTracker:OnListItemMouseExit(wndHandler, wndControl)
	local bHasMouse = wndHandler:ContainsMouse()
	wndHandler:GetParent():FindChild("ListItemGearBtn"):Show(bHasMouse)
	
	if not bHasMouse then
		Apollo.RegisterEventHandler("ObjectiveTrackerUpdated",	"TrackChallenges", self)
	end
end

function ChallengeTracker:OnControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("MinimizeBtn"):Show(true)
	end
end

function ChallengeTracker:OnControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		local wndBtn = wndHandler:FindChild("MinimizeBtn")
		wndBtn:Show(wndBtn:IsChecked())
	end
end

function ChallengeTracker:OnMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self:DrawContextMenuOptions()
		
		--This is a hack. Right clicking on a checkbox control still toggles the checked state, which I don't want here.
		wndHandler:SetCheck(not wndHandler:IsChecked())
	else
		self.tMinimized[wndHandler:GetData()] = wndHandler:IsChecked()
	
		self:TrackChallenges()
	end
end

function ChallengeTracker:OnListItemHintArrow(wndHandler, wndControl, eMouseButton)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local clgCurrent = wndHandler:GetData()
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self:DrawContextMenu(clgCurrent)
	elseif clgCurrent:ShouldCollectReward() then
		self:LootChallenge(clgCurrent)
		
		ChallengesLib.ShowHintArrow(clgCurrent:GetId())
	else
		ChallengesLib.ShowHintArrow(clgCurrent:GetId())
	end
end

-----------------------------------------------------------------------------------------------
-- Right Click
-----------------------------------------------------------------------------------------------
function ChallengeTracker:CloseContextMenu() -- From a variety of source
	if self.wndContextMenu and self.wndContextMenu:IsValid() then
		self.wndContextMenu:Destroy()
		self.wndContextMenu = nil
		
		return true
	end
	
	return false
end

function ChallengeTracker:DrawContextMenu(clgCurrent)
	if self:CloseContextMenu() then return end

	self.wndContextMenu = Apollo.LoadForm(self.xmlDoc, "ContextMenu", nil, self)
	self.wndContextMenu:FindChild("RightClickOpenLogBtn"):SetData(clgCurrent)
	self.wndContextMenu:FindChild("RightClickRestartBtn"):SetData(clgCurrent)
	self.wndContextMenu:FindChild("RightClickRestartBtn"):SetText(clgCurrent:IsActivated() and Apollo.GetString("QuestLog_AbandonBtn") or Apollo.GetString("Options_RestartConfirm"))
	self.wndContextMenu:FindChild("RightClickLootRewardstBtn"):SetData(clgCurrent)
	self.wndContextMenu:FindChild("RightClickLootRewardstBtn"):Enable(clgCurrent:ShouldCollectReward())
	self.wndContextMenu:FindChild("RightClickHideBtn"):SetData(clgCurrent)
	self.wndContextMenu:FindChild("RightClickHideBtn"):Enable(false)
	
	local tCursor = Apollo.GetMouse()
	local nWidth = self.wndContextMenu:GetWidth()
	self.wndContextMenu:Move(tCursor.x - nWidth + knXCursorOffset, tCursor.y - knYCursorOffset, nWidth, self.wndContextMenu:GetHeight())
end

function ChallengeTracker:HelperDrawContextMenuSubOptions(wndIgnore)
	if self.wndContextMenuOptions and self.wndContextMenuOptions:IsValid() then
		self.wndContextMenuOptionsContent = self.wndContextMenuOptions:FindChild("DynamicContent")
		self.wndContextMenuOptionsContent:DestroyChildren()
		
		local wndToggleOnChallenges = self.wndContextMenuOptions:FindChild("ToggleOnChallenges")
		local wndToggleFilterLimit = self.wndContextMenuOptions:FindChild("ToggleFilterLimit")
		local wndMissionLimitEditBox = self.wndContextMenuOptions:FindChild("MissionLimitEditBox")
		local wndToggleFilterDistance = self.wndContextMenuOptions:FindChild("ToggleFilterDistance")
		local wndMissionDistanceEditBox = self.wndContextMenuOptions:FindChild("MissionDistanceEditBox")
	
		wndToggleOnChallenges:SetCheck(self.bShowChallenges)		
		wndToggleFilterLimit:SetCheck(self.bFilterLimit)
		wndToggleFilterDistance:SetCheck(self.bFilterDistance)
		
		if not wndIgnore or wndIgnore and wndIgnore ~= wndMissionLimitEditBox then
			wndMissionLimitEditBox:SetText(self.bFilterLimit and self.nMaxMissionLimit or 0)
		end
		
		if not wndIgnore or wndIgnore and wndIgnore ~= wndMissionDistanceEditBox then
			wndMissionDistanceEditBox:SetText(self.bFilterDistance and self.nMaxMissionDistance or 0)
		end
			
		local nHeight = self.wndContextMenuOptions:GetHeight()
		for strKey, tData in pairs(self.tCategories) do
			if tData.bCanHide then
				local wndEntry = Apollo.LoadForm(self.xmlDoc, "ContextMenuButtonLarge", self.wndContextMenuOptionsContent, self)
				local wndBtn = wndEntry:FindChild("RightClickBtn")
				
				wndBtn:SetData(strKey)
				wndBtn:SetCheck(self.bShowChallenges and not self.tHidden[strKey])
				wndBtn:Enable(self.bShowChallenges)
				wndBtn:SetText(tData.strTitle)
				
				nHeight = nHeight + wndBtn:GetHeight()
			end
		end
		
		self.wndContextMenuOptionsContent:ArrangeChildrenVert()
		
		return nHeight
	end
	
	return 0
end

function ChallengeTracker:CloseContextMenuOptions() -- From a variety of source
	if self.wndContextMenuOptions and self.wndContextMenuOptions:IsValid() then
		self.wndContextMenuOptions:Destroy()
		self.wndContextMenuOptions = nil
		
		return true
	end
	
	return false
end

function ChallengeTracker:DrawContextMenuOptions()
	local nXCursorOffset = -36
	local nYCursorOffset = 5
	
	if self:CloseContextMenuOptions() then return end

	self.wndContextMenuOptions = Apollo.LoadForm(self.xmlDoc, "ContextMenuOptions", nil, self)
	
	local nWidth = self.wndContextMenuOptions:GetWidth()
	local nHeight = self:HelperDrawContextMenuSubOptions()
		
	local tCursor = Apollo.GetMouse()
	self.wndContextMenuOptions:Move(
		tCursor.x - nWidth - nXCursorOffset,
		tCursor.y - nHeight - nYCursorOffset,
		nWidth,
		nHeight
	)
end

function ChallengeTracker:OnToggleChallengeOptions()
	self:DrawContextMenuOptions()
end

function ChallengeTracker:OnToggleShowChallenges()
	self.bShowChallenges = not self.bShowChallenges
	
	self:HelperDrawContextMenuSubOptions()
	self:TrackChallenges()
end

function ChallengeTracker:OnToggleFilterLimit()
	self.bFilterLimit = not self.bFilterLimit
	
	self:HelperDrawContextMenuSubOptions()
	self:TrackChallenges()
end

function ChallengeTracker:OnToggleFilterDistance()
	self.bFilterDistance = not self.bFilterDistance
	
	self:HelperDrawContextMenuSubOptions()
	self:TrackChallenges()
end

function ChallengeTracker:OnMissionLimitEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionLimit = tonumber(wndControl:GetText()) or 0
	self.bFilterLimit = self.nMaxMissionLimit > 0
	
	self:HelperDrawContextMenuSubOptions(wndControl)
	self:TrackChallenges()
end

function ChallengeTracker:OnMissionDistanceEditBoxChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	self.nMaxMissionDistance = tonumber(wndControl:GetText()) or 0
	self.bFilterDistance = self.nMaxMissionDistance > 0
	
	self:HelperDrawContextMenuSubOptions(wndControl)
	self:TrackChallenges()
end

function ChallengeTracker:OnRightClickOptionBtn(wndHandler, wndControl)
	strKey = wndHandler and wndHandler:IsValid() and wndHandler:GetData()
	
	if not strKey then
		return
	end
	
	self.tHidden[strKey] = not self.tHidden[strKey]
	self:TrackChallenges()
end

function ChallengeTracker:OnRightClickBtn(wndHandler, wndControl)
	strKey = wndHandler and wndHandler:IsValid() and wndHandler:GetData()
	
	if not strKey then
		return
	end
	
	self.tHidden[strKey] = not self.tHidden[strKey]
	self:TrackChallenges()
	self:CloseContextMenu(self.wndContextMenuOptions)
end

function ChallengeTracker:OnRightClickOpenLogBtn(wndHandler, wndControl, eMouseButton) -- wndHandler is "RightClickOpenLogBtn" and its data is tQuest
	Event_FireGenericEvent("ShowQuestLog", wndHandler:GetData()) -- Codex (todo: deprecate this)
	Event_FireGenericEvent("ChallengesShow_NoHide", wndHandler:GetData()) -- ChallengeLog
	
	self:CloseContextMenu()
end

function ChallengeTracker:OnRightClickLootRewardsBtn(wndHandler, wndControl)
	clgCurrent = wndHandler:GetData()
	self:LootChallenge(clgCurrent)
	
	self:CloseContextMenu()
end

function ChallengeTracker:OnRightClickRestartBtn(wndHandler, wndControl)
	clgCurrent = wndHandler:GetData()
	
	if clgCurrent:IsActivated() then
		ChallengesLib.AbandonChallenge(clgCurrent:GetId())
	else
		ChallengesLib.ShowHintArrow(clgCurrent:GetId())
		ChallengesLib.ActivateChallenge(clgCurrent:GetId())
	end
	
	self:CloseContextMenu()
end

function ChallengeTracker:OnCloseBtnClick(wndHandler, wndControl)
	if not wndHandler or not wndHandler:IsValid() then
		return
	end
	
	ChallengesLib.AbandonChallenge(wndHandler:GetData())
end

function ChallengeTracker:OnChallengeMouseEnter(wndHandler, wndControl)
	if not wndHandler or not wndHandler:IsValid() then
		return
	end
	
	wndHandler:FindChild("CloseBtn"):Show(wndHandler:ContainsMouse())
end

function ChallengeTracker:OnChallengeMouseExit(wndHandler, wndControl)
	if not wndHandler or not wndHandler:IsValid() then
		return
	end
	
	wndHandler:FindChild("CloseBtn"):Show(wndHandler:ContainsMouse())
end

function ChallengeTracker:OnGenerateSpellTooltip( wndHandler, wndControl, eType, splSource )
	if eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, splSource)
	end
end

---------------------------------------------------------------------------------------------------
-- Sound FX
---------------------------------------------------------------------------------------------------

function ChallengeTracker:OnChallengeActivateSound(challenge)
	Sound.Play(Sound.PlayUIChallengeStarted)
end

function ChallengeTracker:OnChallengeAbandonSound(idChallenge, strDescription)
	Sound.Play(Sound.PlayChallengeQuestCancelled)
end

function ChallengeTracker:OnChallengeFailSound(idChallenge)
	Sound.Play(Sound.PlayUIChallengeFailed)
end

function ChallengeTracker:OnChallengeCompletedSound(idChallenge)
	Sound.Play(Sound.PlayUIChallengeComplete)
end

function ChallengeTracker:OnChallengeTierAchieved(idChallenge, nTier)
	if nTier == 1 then
		Sound.Play(Sound.PlayUIChallengeBronze)
	elseif nTier == 2 then
		Sound.Play(Sound.PlayUIChallengeSilver)
	elseif nTier == 3 then
		Sound.Play(Sound.PlayUIChallengeGold)
	end
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function ChallengeTracker:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.Challenge or not self.tObjectiveTrackerBtnRect then
		return
	end

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, self.tObjectiveTrackerBtnRect)
end

local ChallengeTrackerInst = ChallengeTracker:new()
ChallengeTrackerInst:Init()