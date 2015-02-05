-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Challenges"
require "ChallengesLib"

local Challenges = {}
local LuaEnumTabState =
{
	Empty = -1,
	Fail = -2,
	Reward = -3
}

local karTierIdxToWindowName =
{
	"TrackerBronzeContainer:TrackerBronzeTotalText",
	"TrackerSilverContainer:TrackerSilverTotalText",
	"TrackerGoldContainer:TrackerGoldTotalText"
}

local LuaEnumTypeToTabNumber =
{
	[ChallengesLib.ChallengeType_Combat] 	= 1,
	[ChallengesLib.ChallengeType_General] 	= 2,
	["default"]								= 3,
	[ChallengesLib.ChallengeType_Ability] 	= 4,
}

local kstrBrightRed 			= "fffb2f35"	-- Tabs
local kstrBrightGreen 			= "ff37ff00"
local kstrFadedBlue 			= "ff659fad"	-- Timer
local kstrBrightBlue 			= "ff32ffff"
local kstrBigTimerFontPath 		= "CRB_HeaderGigantic_O"
local kstrSmallTimerFontPath 	= "CRB_HeaderTiny"
local kfReallyLongAutoHideTime 	= 30
local kfReallyShortAutoHideTime = 10
local kfWaitBeforeAutoPromotion = 0.005
local kstrFailTabTest 			= Apollo.GetString("Challenges_Fail")
local kstrPassTabTest			= Apollo.GetString("CRB_Pass")

function Challenges:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Challenges:Init()
	Apollo.RegisterAddon(self)
end

function Challenges:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Challenges.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("ChallengeUpdated", "OnChallengeUpdated", self)
end

function Challenges:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("WindowManagementReady", 		"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("ChallengeAbandon", 			"OnChallengeAbandon", self)
	Apollo.RegisterEventHandler("ChallengeLeftArea", 			"OnChallengeLeftArea", self)
	Apollo.RegisterEventHandler("ChallengeFailTime", 			"OnChallengeFailTime", self)
    Apollo.RegisterEventHandler("ChallengeFailArea", 			"OnChallengeFailArea", self)
	Apollo.RegisterEventHandler("ChallengeActivate", 			"OnChallengeActivate", self)
	Apollo.RegisterEventHandler("ChallengeCompleted", 			"OnChallengeCompleted", self)
	Apollo.RegisterEventHandler("ChallengeFailGeneric", 		"OnChallengeFailGeneric", self)
	Apollo.RegisterEventHandler("ChallengeAreaRestriction", 	"OnChallengeAreaRestriction", self)
	Apollo.RegisterEventHandler("ChallengeTypeAlreadyActive", 	"OnChallengeTypeAlreadyActive", self)
	Apollo.RegisterEventHandler("ChallengeFailSound", 			"OnChallengeFailSound", self)
	Apollo.RegisterEventHandler("ChallengeCompletedSound", 		"OnChallengeCompletedSound", self)
	Apollo.RegisterEventHandler("ChallengeTierAchieved", 		"OnChallengeTierAchieved", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 	"OnTutorial_RequestUIAnchor", self)

	-- Challenge Log Event
    Apollo.RegisterEventHandler("ChallengeLogStartBtn", 		"OnScreenStartButton", self)

	-- Challenge Reward Spinner Events
	Apollo.RegisterEventHandler("ChallengeReward_SpinEnd", 		"OnChallengeReward_SpinEnd", self)
	Apollo.RegisterEventHandler("ChallengeReward_SpinBegin", 	"OnChallengeReward_SpinBegin", self)
	
	self.timerMax = ApolloTimer.Create(20.0, false, "OnChallengeReward_SpinEnd", self)
	self.timerMax:Stop()
	self.bRewardWheelSpinning = false

	-- Tracker Timers
	self.timerAutoHideLong = ApolloTimer.Create(kfReallyLongAutoHideTime, false, "OnAutoHideTimer", self)
	self.timerAutoHideLong:Stop()
	
	self.timerAutoHideShort = ApolloTimer.Create(kfReallyShortAutoHideTime, false, "OnAutoHideTimer", self)
	self.timerAutoHideShort:Stop()

	self.timerRepeating = ApolloTimer.Create(0.100, true, "OnRepeatingTimer", self)
	self.bStopRepeatingTimer = false
	
	--timers currently can't be started during their callbacks, because of a Code bug.
	--as a work around, will re-assign the references to the timers in their callbacks.
	self.timerAreaLeft = ApolloTimer.Create(0.500, false, "UpdateLeftAreaTime", self)
	self.timerAreaLeft:Stop()

	-- UI Windows
	self.wndTracker 			= Apollo.LoadForm(self.xmlDoc, "ChallengeTracker", "FixedHudStratum", self)
	self.wndTracker:Show(false, true)
	self.wndLeftArea 			= Apollo.LoadForm(self.xmlDoc, "ChallengeLeftArea", "FixedHudStratum", self)
	self.wndLeftArea:Show(false, true)
	self.wndMinimized 			= Apollo.LoadForm(self.xmlDoc, "ChallengeMinimized", "FixedHudStratum", self)
	self.wndMinimized:Show(false, true)
	self.wndBigDisplay 			= self.wndTracker:FindChild("BigDisplay")
	self.wndCompletedDisplay 	= self.wndTracker:FindChild("CompletedDisplay")

	self.xmlDoc = nil
	if self.locSavedWindowLoc then
		self.wndTracker:MoveToLocation(self.locSavedWindowLoc)
		self.wndMinimized:MoveToLocation(self.locSavedWindowLoc)
	end

	-- We rely on this table to be indexed 1, 2, 3, 4. We will use the index of the first entry to be 1 throughout the code.
	local wndTrackerTabContainer = self.wndTracker:FindChild("TrackerTabContainer")
	self.tWndTrackerTabs =
	{
		wndTrackerTabContainer:FindChild("TrackerTab1"),
		wndTrackerTabContainer:FindChild("TrackerTab2"),
		wndTrackerTabContainer:FindChild("TrackerTab3"),
		wndTrackerTabContainer:FindChild("TrackerTab4")
	}

	for key, wndCurr in pairs(self.tWndTrackerTabs) do
		wndCurr:SetData(LuaEnumTabState.Empty)
	end

	-- Class Variables
	self.tCompletedMessages 				= {}
	self.tUnlockedChallengeList 			= {}
	self.tActiveChallenges					= {}
	self.clgActive 							= nil
	self.idCurrTabSelection 				= -1
	self.nLastChallengeIdForFlash 			= 0		-- For the white update flash when you go from 1/5 to 2/5 complete
	self.nPassCountForAutoPromote 			= 0		-- The number of timer passes before we will auto promote
	self.bReallyLongAutoHideTimerActive 	= false
	self.bReallyShortAutoHideTimerActive 	= false

	if self.tSavedChallenges then
		for idx, idChallenge in pairs(self.tSavedChallenges) do
			self:OnChallengeUpdated(idChallenge)
		end
	end

	self:OnRepeatingTimer()
end

function Challenges:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndTracker, strName = Apollo.GetString("Challenges")})
end

----------------------------------------------------------------------------------------------------------
-- Challenge Left Area
----------------------------------------------------------------------------------------------------------

function Challenges:OnChallengeLeftArea(idChallenge, strHeader, strDescription, bShow)
	self.wndLeftArea:Show(bShow)
	Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", bShow)

	-- Look up type
	if not self.tUnlockedChallengeList or self:GetTableSize(self.tUnlockedChallengeList) == 0 then
		return
	end
	local tCurrChallenge = self.tUnlockedChallengeList[idChallenge]

	if bShow then
		if not tCurrChallenge or not tCurrChallenge:IsActivated() then
			self.wndLeftArea:Show(false)
			Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
			return
		end

        local wndLeftHeader = self.wndLeftArea:FindChild("LeftAreaHeader")
		wndLeftHeader:SetAML(string.format("<P Font=\"CRB_HeaderSmall\">%s</P>", strHeader))
		wndLeftHeader:SetHeightToContentHeight()
		if wndLeftHeader:GetHeight() >= 40 then
			local nLeft, nTop, nRight, nBottom = wndLeftHeader:GetAnchorOffsets()
			wndLeftHeader:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 40)
			wndLeftHeader:SetAML(string.format("<P Font=\"CRB_InterfaceMedium\">%s</P>", strHeader))
		end
		
		local wndLeftAreaDescription = self.wndLeftArea:FindChild("LeftAreaDescription")
		wndLeftAreaDescription:SetAML(string.format("<P Font=\"CRB_InterfaceMedium\">%s</P>", strDescription))
		wndLeftAreaDescription:SetHeightToContentHeight()
		if wndLeftAreaDescription:GetHeight() >= 55 then
			local nLeft, nTop, nRight, nBottom = wndLeftAreaDescription:GetAnchorOffsets()
			wndLeftAreaDescription:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 55)
			wndLeftAreaDescription:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\">%s</P>", strDescription))
		end
		
		self.wndLeftArea:FindChild("LeftAreaTypeIcon"):SetSprite(self:CalculateIconPath(tCurrChallenge:GetType()))
		self.wndLeftArea:FindChild("LeftAreaTypeIcon"):SetTooltip(self:CalculateIconTooltip(tCurrChallenge:GetType()))
        self.idLeftArea = idChallenge

        self:UpdateLeftAreaTime()
	elseif tCurrChallenge and tCurrChallenge:IsActivated() then
		self:ShowTracker() -- Go back to tracker
	end
end

-- This will be repeatedly called by itself once started and until it finishes
function Challenges:UpdateLeftAreaTime()
	local strTimeRemaining = ChallengesLib.GetTimeRemaining(self.idLeftArea, ChallengesLib.ChallengeTimerFlags_Active)
	local strCountdown = ChallengesLib.GetTimeRemaining(self.idLeftArea, ChallengesLib.ChallengeTimerFlags_LeftArea)
	self.timerAreaLeft:Stop()

	if strTimeRemaining < strCountdown then
		strCountdown = strTimeRemaining
	end

	if strCountdown ~= nil and strCountdown ~= ":" and strCountdown ~= "" then
        self.wndLeftArea:FindChild("LeftAreaTimeCountdown"):SetText(strCountdown)
		--timers currently can't be started during their callbacks, because of a Code bug.
		self.timerAreaLeft = ApolloTimer.Create(0.500, false, "UpdateLeftAreaTime", self)
	else
		self.wndLeftArea:Show(false)
		Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
    end
end

function Challenges:OnHideLeftAreaWindow(wndHandler, wndControl)
	ChallengesLib.AbandonChallenge(self.idLeftArea)
	self.wndLeftArea:Show(false)
	Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
end

----------------------------------------------------------------------------------------------------------
-- Challenge Abandon
----------------------------------------------------------------------------------------------------------

function Challenges:OnChallengeTypeAlreadyActive(idToActivate, idToAbandon)
	-- Swap challenges, picking up a challenge from the wild won't activate this
	-- Careful, this fires OnChallengeAbandon's event, so make sure that is safe
	ChallengesLib.AbandonChallenge(idToAbandon)
	self:ActivateChallengeAndTracker(idToActivate)
	self:ClearText()
end

function Challenges:OnTrackerAbandonButton(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end
	ChallengesLib.AbandonChallenge(wndHandler:GetData():GetId())
	Event_FireGenericEvent("ChallengeAbandonConfirmed")
	-- This eventually fires a ChallengeAbandon event back to here, which is below
end

function Challenges:OnChallengeAbandon(idChallenge, strDescription)
	local strHeader = Apollo.GetString("Challenges_Abandoned")
	if self.tUnlockedChallengeList and self.tUnlockedChallengeList[idChallenge] then
		strHeader = String_GetWeaselString(Apollo.GetString("Challenges_AbandonedSpecific"), self.tUnlockedChallengeList[idChallenge]:GetName())
	end
	self:AddCompletedMessage(idChallenge, strHeader, Apollo.GetString("Challenges_YouAbandoned"), 0, LuaEnumTabState.Fail)
	Sound.Play(Sound.PlayChallengeQuestCancelled)
end

----------------------------------------------------------------------------------------------------------
-- Global Events From Challenge Log and Challenge Reward Screen
----------------------------------------------------------------------------------------------------------

function Challenges:OnScreenStartButton(idChallengeArg)
	if not idChallengeArg or type(idChallengeArg) ~= "number" then
		return
	end
	self:StartTracker(idChallengeArg)
end

function Challenges:OnChallengeReward_SpinEnd()
	self.timerMax:Stop()
	self.bRewardWheelSpinning = false
end

function Challenges:OnChallengeReward_SpinBegin()
	self.timerMax:Start()
	self.bRewardWheelSpinning = true
end

----------------------------------------------------------------------------------------------------------
-- Event Handlers for CPP Events
----------------------------------------------------------------------------------------------------------

function Challenges:OnChallengeCompleted(idChallenge, strHeader, strDescription, fDuration)
	self:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, LuaEnumTabState.Reward)

end

function Challenges:OnChallengeFailGeneric(challenge, strHeader, strDescription, fDuration)
	local idChallenge = challenge:GetId()
	if self.idLeftArea == idChallenge then -- Also hide the warning window
		self.timerAreaLeft:Stop()
		self.wndLeftArea:Show(false)
		Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
	end

	if self.tUnlockedChallengeList and self.tUnlockedChallengeList[idChallenge] and self.tUnlockedChallengeList[idChallenge]:GetCurrentTier() > 0 then
		self:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, LuaEnumTabState.Reward)
	else
		self:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, LuaEnumTabState.Fail)
	end
end

function Challenges:OnChallengeFailTime(challenge, strHeader, strDescription, fDuration)
	local idChallenge = challenge:GetId()
	if self.idLeftArea == idChallenge then -- Also hide the warning window
		self.timerAreaLeft:Stop()
		self.wndLeftArea:Show(false)
		Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
	end

	if self.tUnlockedChallengeList and self.tUnlockedChallengeList[idChallenge] and self.tUnlockedChallengeList[idChallenge]:GetCurrentTier() > 0 then
		self:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, LuaEnumTabState.Reward)
	else
		self:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, LuaEnumTabState.Fail)
	end
end

function Challenges:OnChallengeFailArea(chalFailed, strHeader, strDescription, fDuration)
	local idChallenge = chalFailed:GetId()

	-- Abstaining from fail message here
	if self.idLeftArea == idChallenge then -- Also hide the warning window
		self.timerAreaLeft:Stop()
		self.wndLeftArea:Show(false)
		if not self.wndTracker:IsShown() then
			Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
		end
		self.idLeftArea = 0
	end

	if self.tUnlockedChallengeList and self.tUnlockedChallengeList[idChallenge] and self.tUnlockedChallengeList[idChallenge]:GetCurrentTier() > 0 then
		self:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, LuaEnumTabState.Reward)
	else
		self:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, LuaEnumTabState.Fail)
	end
	self:ClearText()
end

function Challenges:OnChallengeAreaRestriction(idChallenge, strHeader, strDescription, fDuration)
	self.timerAutoHideLong:Stop()
	self.timerAutoHideLong:Start()

	local wndCompletedDescription = self.wndCompletedDisplay:FindChild("CompletedDescription")
	wndCompletedDescription:SetText(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</P>", strDescription))
	wndCompletedDescription:SetHeightToContentHeight()
	self.wndCompletedDisplay:FindChild("CompletedDescription"):SetData(strDescription) -- Remember this for later
end

function Challenges:OnChallengeActivate(challenge)
	-- The tracker actually doesn't care about this event. It will poll all challenge results on a timer regardless, which keeps it safe from reloadui.
	-- However, this does provide a good way to handle popping out of the minimized state
	self.wndTracker:Invoke()
	self.wndMinimized:Show(false)
	Sound.Play(Sound.PlayUIChallengeStarted)
	Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", true)

	self.timerRepeating:Start()
	if self.bReallyLongAutoHideTimerActive then
		self.timerAutoHideLong:Stop()
		self.bReallyLongAutoHideTimerActive = false
	end
	if self.bReallyShortAutoHideTimerActive then
		self.timerAutoHideShort:Stop()
		self.bReallyShortAutoHideTimerActive = false
	end
end

function Challenges:OnChallengeUpdated(idChallenge)
	if self.wndTracker:IsShown() or (self.wndLeftArea:IsShown() and idChallenge == self.idLeftArea) then
		return
	end

	if self.tUnlockedChallengeList then
		local bIsActive = false
		local clgUpdated = self.tUnlockedChallengeList[idChallenge]

		if clgUpdated then
			for idx, clgActive in pairs(self.tActiveChallenges) do
				if clgActive == clgUpdated then
					bIsActive = true
				end
			end

			if bIsActive then
				self:OnChallengeActivate(clgUpdated)
			end
		end
	else
		if not self.tSavedChallenges then
			self.tSavedChallenges = {}
		end
		table.insert(self.tSavedChallenges, idChallenge)
	end
end

----------------------------------------------------------------------------------------------------------
-- Simple UI buttons
----------------------------------------------------------------------------------------------------------

function Challenges:OnHintArrow(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then  -- wndHandler is TrackerHintButton
		return
	end
	ChallengesLib.ShowHintArrow(wndHandler:GetData():GetId())
end

function Challenges:OnLeftAreaHintArrow(wndHandler, wndControl)
	if not wndHandler then -- wndHandler is Left Area's TrackerHintButton
		return
	end
	ChallengesLib.ShowHintArrow(self.idLeftArea) -- Since the left area challenge object isn't available
end

function Challenges:OnTrackerMouseEnter(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() or not wndControl:FindChild("TrackerHintButton"):GetData() then
		return
	end
	wndHandler:FindChild("TrackerHintButton"):Show(wndHandler:FindChild("TrackerHintButton"):GetData():NeedsHintArrow())
	wndHandler:FindChild("TrackerAbandonButton"):Show(true)

	if wndControl:FindChild("TrackerHintButton"):GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:HighlightRegionsByUserData(ZoneMapLibrary.eObjectTypeChallenge, wndControl:FindChild("TrackerHintButton"):GetData())
	end
end

function Challenges:OnTrackerMouseExit(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() or not wndHandler:FindChild("TrackerAbandonButton") then
		return
	end
	wndHandler:FindChild("TrackerHintButton"):Show(false)
	wndHandler:FindChild("TrackerAbandonButton"):Show(false)

	if wndControl:FindChild("TrackerHintButton"):GetData() and ZoneMapLibrary and ZoneMapLibrary.wndZoneMap then
		ZoneMapLibrary.wndZoneMap:UnhighlightRegionsByUserData(ZoneMapLibrary.eObjectTypeChallenge, wndControl:FindChild("TrackerHintButton"):GetData())
	end
end

function Challenges:OnCompletedRetryPush(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetData() == -1 then
		return
	end
	self:ActivateChallengeAndTracker(wndHandler:GetData())
	ChallengesLib.ShowHintArrow(wndHandler:GetData())
end

function Challenges:OnCompletedLootPush(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() or wndHandler:GetData() == -1 then
		return
	end
	Event_FireGenericEvent("ChallengeRewardShow", wndHandler:GetData())
end

function Challenges:OnCompletedMessageClose(wndHandler, wndControl)
	if self.tWndTrackerTabs[self.idCurrTabSelection] then
		self.tWndTrackerTabs[self.idCurrTabSelection]:SetData(LuaEnumTabState.Empty)
	end
    table.remove(self.tCompletedMessages, self.idCurrTabSelection)
	self.wndCompletedDisplay:Show(false)
	self.wndBigDisplay:Show(true)
	self.clgActive = nil
	self.idCurrTabSelection = LuaEnumTabState.Empty -- It makes sense to deselect here and let auto promote take over

	self:AutoPromoteAnActiveTab()
end

----------------------------------------------------------------------------------------------------------
-- Challenge Tracker
----------------------------------------------------------------------------------------------------------

function Challenges:StartTracker(idChallenge)
    if not self.tUnlockedChallengeList or self:GetTableSize(self.tUnlockedChallengeList) == 0 then
		self.timerRepeating:Stop()
		return
	end
	local clgLocal = self.tUnlockedChallengeList[idChallenge]
	if not clgLocal or clgLocal == nil then
		return
	end

	local eType = clgLocal:GetType()

	if eType >= 3 then
		eType = "default"
	end

	self.idCurrTabSelection = LuaEnumTypeToTabNumber[eType]

    -- The timer will reinitialize things, so let's wipe artifacts
    self:ResetTabs()
    self.clgActive = clgLocal
    self.wndCompletedDisplay:Show(false)

	self.timerAutoHideLong:Stop()
	self.timerAutoHideShort:Stop()
	self.bReallyLongAutoHideTimerActive = false
	self.bReallyShortAutoHideTimerActive = false
end

-- This is the main update method for the tracker's logic
function Challenges:OnRepeatingTimer()
	local tChallengeData = ChallengesLib.GetActiveChallengeList()
	self.tUnlockedChallengeList = tChallengeData
	
	--if HideTracker was called from RepeatingTimer which is the callback from self.timerRepeating
	--then we don't want to stop the timer, which is what HideTracker can do.
	self.bStopRepeatingTimer = false
	-- Early Exit if invalid
	if not tChallengeData or self:GetTableSize(tChallengeData) == 0 then
		if self.wndBigDisplay:IsShown() and not self.wndCompletedDisplay:IsShown() then
			self:HideTracker()
		end
		return
	end

	-- Early Exit if minimized (a challenge start event will hide wndMinimized for us)
	if self.wndMinimized:IsShown() then
		return
	end

	local bThereIsACurrChallenge = false
	local bThereIsAnActiveChallenge = false

	-- Loop to find the challenge to draw for either the Active Challenge or the Completed Display Challenge
	for idx, clgCurrent in pairs(tChallengeData) do
		if clgCurrent:IsActivated() then
			bThereIsAnActiveChallenge = true
		end

		-- Note: We can have a valid tCurrChallengeId but a deactivated clgCurrent (for a fail message)
		if clgCurrent:IsActivated() and self.clgActive and self.clgActive:GetId() == idx then

			self:DrawActiveChallenge(idx, clgCurrent)

			-- Sanity check. There are some race conditions when a clgCurrent ends/finishes and sends more events from C++
			if self.idCurrTabSelection == -1 then
				local eType = clgCurrent:GetType()
				if eType >= 3 then
					eType = "default"
				end

				self.idCurrTabSelection = LuaEnumTypeToTabNumber[eType]
			end

			bThereIsACurrChallenge = true
		end

		-- Real time updating of area restriction
		local wndFailRetryBtn = self.wndCompletedDisplay:FindChild("FailContainer:FailRetryButton")
		local wndRewardRetryBtn = self.wndCompletedDisplay:FindChild("RewardContainer:RewardRetryButton")
		if self.wndCompletedDisplay:IsShown() and self.wndCompletedDisplay:GetData() ~= nil and self.wndCompletedDisplay:GetData():GetId() == idx then
			if clgCurrent:IsInCooldown() then
				wndFailRetryBtn:SetText(Apollo.GetString("Challenges_OnCooldown"))
				wndRewardRetryBtn:SetText(Apollo.GetString("Challenges_OnCooldown"))
			else
				wndFailRetryBtn:SetText(Apollo.GetString("Retry"))
				wndRewardRetryBtn:SetText(Apollo.GetString("Challenges_StartAgain"))
			end

			self.wndCompletedDisplay:FindChild("FailContainer:FailLootButton"):Enable(clgCurrent:ShouldCollectReward())
			self.wndCompletedDisplay:FindChild("RewardContainer:RewardLootButton"):Enable(clgCurrent:ShouldCollectReward() and not self.bRewardWheelSpinning)

			-- If subzone == 0 (no restriction), or in the subzone, then enable the button
			local idSubZone = clgCurrent:GetZoneRestrictionInfo().idSubZone
			local wndCompletedDescription = self.wndCompletedDisplay:FindChild("CompletedDescription")
			if idSubZone == 0 or GameLib.IsInWorldZone(idSubZone) or clgCurrent:ShouldCollectReward() then
				wndFailRetryBtn:Enable(not clgCurrent:ShouldCollectReward() and not clgCurrent:IsInCooldown())
				wndRewardRetryBtn:Enable(not clgCurrent:ShouldCollectReward() and not clgCurrent:IsInCooldown())
				wndCompletedDescription:SetText(wndCompletedDescription:GetData())
			else
				wndFailRetryBtn:Enable(false)
				wndRewardRetryBtn:Enable(false)
				wndCompletedDescription:SetText(Apollo.GetString("Challenges_AreaReq"))
			end
			
			wndCompletedDescription:SetHeightToContentHeight()
			if wndCompletedDescription:GetHeight() >= 55 then
				local nLeft, nTop, nRight, nBottom = wndCompletedDescription:GetAnchorOffsets()
				wndCompletedDescription:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 55)
				wndCompletedDescription:SetText(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">%s</P>", wndCompletedDescription:GetData()))
			end
	end
	end

	self:AutoPromoteAnActiveTab(bThereIsACurrChallenge, bThereIsAnActiveChallenge)

	self:DrawAllTabs(tChallengeData)

	-- Figure out if we should show or hide the tracker
	if self.wndLeftArea:IsShown() then
		self:HideTracker()
	elseif bThereIsAnActiveChallenge and not self.wndCompletedDisplay:IsShown() then
		self:ShowTracker()
	elseif not bThereIsAnActiveChallenge and not self.wndCompletedDisplay:IsShown() and self.wndBigDisplay:IsShown() then
		self:HideTracker()
	end

	if self.wndCompletedDisplay:IsShown() then
		self.wndBigDisplay:Show(false)
	end

	-- Promote a random challenge if there is no current challenge (for the big display)
	-- Note this will run for the first ever load
	if bThereIsAnActiveChallenge and not bThereIsACurrChallenge then
		for idx, clgCurrent in pairs(tChallengeData) do
			local bCurrentActivated = clgCurrent:IsActivated()
			if bCurrentActivated and self.nPassCountForAutoPromote < kfWaitBeforeAutoPromotion then
				self.nPassCountForAutoPromote = self.nPassCountForAutoPromote + 1
			elseif bCurrentActivated and self.nPassCountForAutoPromote >= kfWaitBeforeAutoPromotion then
				-- Looks like we're routing all clgCurrent id updating here or at the tracker tab buttons
				self.nPassCountForAutoPromote = 0
				self:StartTracker(idx)
				break
			end
		end
	elseif self.nPassCountForAutoPromote > 0 then
		self.nPassCountForAutoPromote = 0
	end

	-- Start autohide if needed
	local bAutoHideNeeded = self.wndTracker:IsShown() and self.wndCompletedDisplay:IsShown() and not bThereIsAnActiveChallenge
	if bAutoHideNeeded and not self.bReallyLongAutoHideTimerActive then
		self.timerAutoHideLong:Start()
		self.bReallyLongAutoHideTimerActive = true
	elseif bAutoHideNeeded and not self.bReallyShortAutoHideTimerActive and self:HelperAllChallengesInCooldown(tChallengeData) then
		self.timerAutoHideShort:Start()
		self.bReallyShortAutoHideTimerActive = true
	end

	-- TODO Remove this entirely
	-- The display anchor will appear when docked the tracker is within 25 pixels of the right screen edge
	--local nLeft, nTop, nRight, nBottom = self.wndTracker:GetAnchorOffsets()
	--local bRightScreenEdge = nRight < 25 and nRight > -2
	--self.wndTracker:FindChild("TrackerMinimizeButton"):Show(bRightScreenEdge or self.wndTracker:ContainsMouse())

	-- The minimized window will draw instead if the tracker is hidden
	self.wndMinimized:Show(not self.wndTracker:IsShown() and not self.wndLeftArea:IsShown())
end

function Challenges:OnWndTrackerMove(wndHandler, wndControl)
	local locWndTrackerLocation = self.wndTracker:GetLocation()
	self.wndMinimized:MoveToLocation(locWndTrackerLocation)
end

function Challenges:OnWndMinimizedMove(wndHandler, wndControl)
	local locWndMinimizedLocation = self.wndMinimized:GetLocation()
	self.wndTracker:MoveToLocation(locWndMinimizedLocation)
end

function Challenges:DrawActiveChallenge(idChallenge, clgActive)

local wndTrackerDesc = self.wndBigDisplay:FindChild("TrackerDescription")
local wndTrackerTitle = self.wndBigDisplay:FindChild("TrackerTitle")
	if self.wndTracker:IsShown() and self.wndBigDisplay:IsShown() then
		
		wndTrackerDesc:SetText(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</P>", clgActive:GetDescription()))
		wndTrackerDesc:SetHeightToContentHeight()
		wndTrackerDesc:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", clgActive:GetDescription()))
		wndTrackerTitle:SetText(string.format("<P Font=\"CRB_HeaderSmall\" TextColor=\"UI_TextHoloTitle\">%s</P>", clgActive:GetName()))
		wndTrackerTitle:SetHeightToContentHeight()
		wndTrackerTitle:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", clgActive:GetName()))
		
		local nLeft, nTop, nRight, nBottom = wndTrackerDesc:GetAnchorOffsets()

		if wndTrackerTitle:GetHeight() >= 40 then
			wndTrackerTitle:SetText(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloTitle\">%s</P>", clgActive:GetName()))
			wndTrackerTitle:SetHeightToContentHeight()
		end
		
		if wndTrackerDesc:GetHeight() >= 55 or nTop >= 60 then -- Will be  60+ if wndTrackerTitle is 3 lines tall
			wndTrackerDesc:SetText(string.format("<P Font=\"CRB_InterfaceTiny_BB\" TextColor=\"UI_TextHoloBody\">%s</P>", clgActive:GetDescription()))
		end
		
		local nLeft2, nTop2, nRight2, nBottom3 = wndTrackerTitle:GetAnchorOffsets()
		wndTrackerDesc:SetAnchorOffsets(nLeft, nBottom3 + 5, nRight, nBottom)
		self.wndBigDisplay:FindChild("TrackerTypeIcon"):SetSprite(self:CalculateIconPath(clgActive:GetType()))
		self.wndBigDisplay:FindChild("TrackerTypeIcon"):SetTooltip(self:CalculateIconTooltip(clgActive:GetType()))
		self.wndBigDisplay:FindChild("TrackerOutcroppingArt:TrackerBigCountdown"):SetAML(self:CalculateMLTimeText(clgActive, kstrBigTimerFontPath))
		self.wndBigDisplay:FindChild("TrackerHintButton"):SetData(clgActive)
		self.wndBigDisplay:FindChild("TrackerAbandonButton"):SetData(clgActive)
	end

	-- Medals
	-- TODO: Move this to a new system
	local bTieredChallenge = clgActive and clgActive:GetAllTierCounts() and #clgActive:GetAllTierCounts() > 1
	local wndTierContainer = self.wndBigDisplay:FindChild("TrackerTierIconContainer")

	wndTierContainer:Show(bTieredChallenge)
	wndTierContainer:FindChild("TierSkillContainer"):Show(clgActive:GetType() == ChallengesLib.ChallengeType_Ability)
	self.wndBigDisplay:FindChild("TrackerSkillContainer"):Show(clgActive:GetType() == ChallengesLib.ChallengeType_Ability)
	self.wndBigDisplay:FindChild("TrackerProgressContainer"):Show(not bTieredChallenge)

	local nTotal = clgActive:GetTotalCount()
	local nCurrent = clgActive:GetCurrentCount()
	local strPercent = String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nCurrent / nTotal * 100))

	if bTieredChallenge then
		self:DrawMedals(clgActive, wndTierContainer)

		local wndTierCurrentProgressContainer = wndTierContainer:FindChild("TierCurrentProgressContainer")
		-- Draw the big progress display
		if nCurrent == 0 and nTotal <= 1 then
			wndTierCurrentProgressContainer:FindChild("TierCurrentProgressText"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" Align=\"Center\" TextColor=\""..kstrFadedBlue.."\">--/--</P>")
		else
			wndTierCurrentProgressContainer:FindChild("TierCurrentProgressText"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" Align=\"Center\" TextColor=\""..kstrBrightBlue.."\">"..strPercent.."</P>")
		end
		wndTierCurrentProgressContainer:Show(nTotal ~= 0 and (nTotal ~= 100 or clgActive:IsTimeTiered()))

		-- Draw tier max's
		for iTierIdx, tCurrTier in pairs(clgActive:GetAllTierCounts()) do
			local wndCurrTier = wndTierContainer:FindChild(karTierIdxToWindowName[iTierIdx] or "")
			if not wndCurrTier then
				break
			end

			local strTier = tCurrTier["nGoalCount"]
			if clgActive:IsTimeTiered() then
				wndCurrTier:SetTextColor(kstrFadedBlue)
				wndCurrTier:SetText(self:HelperConvertToTime(strTier))
			elseif iTierIdx == (clgActive:GetCurrentTier() + 1) then -- Active tier
				wndCurrTier:SetTextColor(kstrBrightBlue)
				wndCurrTier:SetText(strTier == 100 and strPercent or strTier)
			else -- Implict not active
				wndCurrTier:SetTextColor(kstrFadedBlue)
				wndCurrTier:SetText(strTier == 100 and "" or strTier)
			end
		end

		-- Skill Spell
		if clgActive:GetType() == ChallengesLib.ChallengeType_Ability then
			wndTierContainer:FindChild("TierAbilityChallengeSkill"):SetContentId(clgActive)
		end
	else
		-- Draw the big progress display
		-- TODO need string weasel
		local strProgressText = ""
		if nCurrent == 0 and nTotal == 1 then
			strProgressText = string.format("<P Font=\"CRB_HeaderTiny\" TextColor=\"%s\" Align=\"Center\">--/--</P>", kstrFadedBlue)
		elseif nTotal == 100 then
			strProgressText = string.format("<P Font=\"CRB_HeaderTiny\" TextColor=\"%s\" Align=\"Center\">%s</P>", kstrBrightBlue, strPercent)
		else
			local strHighlighted = string.format("<T Font=\"CRB_HeaderTiny\" TextColor=\"%s\">%s</T>", kstrBrightBlue, nCurrent)
			strProgressText = string.format("<P Font=\"CRB_HeaderTiny\" TextColor=\"%s\" Align=\"Center\">%s/%s</P>", kstrFadedBlue, strHighlighted, nTotal)
		end
		self.wndBigDisplay:FindChild("TrackerProgressContainer:TrackerProgressText"):SetAML(strProgressText)

		-- Skill Spell
		if clgActive:GetType() == ChallengesLib.ChallengeType_Ability then
			self.wndBigDisplay:FindChild("AbilityChallengeSkill"):SetContentId(clgActive)
		end
	end

	-- Animate on any change after 0 -- TODO: Refactor
	if nCurrent ~= 0 and self.nLastChallengeIdForFlash == idChallenge then
		local wndTierCurrentProgressText = wndTierContainer:FindChild("TierCurrentProgressContainer:TierCurrentProgressText")
		local wndTrackerProgressText = self.wndBigDisplay:FindChild("TrackerProgressContainer:TrackerProgressText")

		if bTieredChallenge and nCurrent ~= wndTierCurrentProgressText:GetData() then
			wndTierCurrentProgressText:SetData(nCurrent)
			self.wndBigDisplay:FindChild("TrackerFlashAnimArt"):SetSprite("CRB_ChallengeTrackerSprites:sprChallengeStatusFlash")
		elseif not bTieredChallenge and nCurrent ~= wndTrackerProgressText:GetData() then
			wndTrackerProgressText:SetData(nCurrent)
			self.wndBigDisplay:FindChild("TrackerFlashAnimArt"):SetSprite("CRB_ChallengeTrackerSprites:sprChallengeStatusFlash")
		end
	end
	self.nLastChallengeIdForFlash = idChallenge
end

function Challenges:DrawCompletedMessage(nNewSelection, eRewardOrFailState)
	-- GOTCHA: table.remove SHIFTS down entries if indexed by numbers. Thus we use string key indices.
	local tCompletedStrings = self.tCompletedMessages[tostring(nNewSelection)]
    self.idCurrTabSelection = nNewSelection
    self.wndCompletedDisplay:Show(true)
	self.wndBigDisplay:Show(false)
	self:ClearText()

	-- Load up our tables for the strings and to determine type/rewards
    if tCompletedStrings == nil or tCompletedStrings == {} or #tCompletedStrings <= 0 then
		return
	end
	if not self.tUnlockedChallengeList or self:GetTableSize(self.tUnlockedChallengeList) == 0 then
		return
	end
	local clgCurrent = self.tUnlockedChallengeList[tCompletedStrings[1]]
	if not clgCurrent then
		return
	end

	-- Draw
	self.wndBigDisplay:FindChild("TrackerAbandonButton"):SetData(clgCurrent)
	self.wndCompletedDisplay:SetData(clgCurrent)
	
	local wndCompletedDescription = self.wndCompletedDisplay:FindChild("CompletedDescription")
	wndCompletedDescription:SetText(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</P>", tCompletedStrings[3]))
	wndCompletedDescription:SetHeightToContentHeight()	
	self.wndCompletedDisplay:FindChild("CompletedDescription"):SetData(tCompletedStrings[3]) -- Remember for later
	self.wndCompletedDisplay:FindChild("CompletedTypeIcon"):SetSprite(self:CalculateIconPath(clgCurrent:GetType()))
	self.wndCompletedDisplay:FindChild("CompletedTypeIcon"):SetTooltip(self:CalculateIconTooltip(clgCurrent:GetType()))

	-- Medals
	--[[local wndInlineIconContainer = self.wndTracker:FindChild("CompletedDisplay:TierInlineIconContainer")
	if clgCurrent and clgCurrent:GetAllTierCounts() and #clgCurrent:GetAllTierCounts() > 1 then
		self:DrawMedals(clgCurrent, wndInlineIconContainer)
		wndInlineIconContainer:FindChild("TierMedalContainer"):ArrangeChildrenHorz(1)
	else
		wndInlineIconContainer:Show(false)
	end]]--

	-- Fail/Reward specific formatting
	local wndFailContainer = self.wndCompletedDisplay:FindChild("FailContainer")
	local wndRewardContainer = self.wndCompletedDisplay:FindChild("RewardContainer")
	wndFailContainer:Show(eRewardOrFailState == LuaEnumTabState.Fail)
	wndRewardContainer:Show(eRewardOrFailState == LuaEnumTabState.Reward)
	self.wndCompletedDisplay:FindChild("CompletedCloseButton"):Show(eRewardOrFailState == LuaEnumTabState.Fail or eRewardOrFailState == LuaEnumTabState.Reward)
	wndRewardContainer:FindChild("RewardLootButton"):Enable(clgCurrent:ShouldCollectReward() and not self.bRewardWheelSpinning)

	local tZoneRestrictionInfo = clgCurrent:GetZoneRestrictionInfo()
	local idSubZone = tZoneRestrictionInfo and tZoneRestrictionInfo.idSubZone or nil
	if idSubZone == 0 or GameLib.IsInWorldZone(idSubZone) then
		wndFailContainer:FindChild("FailRetryButton"):Enable(not clgCurrent:ShouldCollectReward() and not clgCurrent:IsInCooldown())
		wndRewardContainer:FindChild("RewardRetryButton"):Enable(not clgCurrent:ShouldCollectReward() and not clgCurrent:IsInCooldown())
	else
		wndFailContainer:FindChild("FailRetryButton"):Enable(false)
		wndRewardContainer:FindChild("RewardRetryButton"):Enable(false)
	end

	local strCompletedSprite = ""
	local strHeaderColor = "UI_TextHoloTitle"
	local idChallenge = clgCurrent:GetId()
	if eRewardOrFailState == LuaEnumTabState.Reward then
		if clgCurrent:ShouldCollectReward() then
			wndRewardContainer:FindChild("RewardLootButton"):SetData(idChallenge)
		end
		wndRewardContainer:FindChild("RewardFlashAnimArt"):SetSprite("CRB_ChallengeTrackerSprites:sprChallengeStatusFlash")
		wndRewardContainer:FindChild("RewardRetryButton"):SetData(idChallenge)
		strCompletedSprite = "CRB_ChallengeTrackerSprites:sprChallengeStatusPass"
		strHeaderColor = "UI_TextHoloTitle"

	elseif eRewardOrFailState == LuaEnumTabState.Fail then
		if clgCurrent:ShouldCollectReward() then wndFailContainer:FindChild("FailLootButton"):SetData(idChallenge) end
		wndFailContainer:FindChild("FailRetryButton"):SetData(idChallenge)
		strCompletedSprite = "CRB_ChallengeTrackerSprites:sprChallengeStatusFail"
		strHeaderColor = "xkcdReddish"
	end
	self.wndCompletedDisplay:FindChild("CompletedStatus"):SetSprite(strCompletedSprite)
	
	local wndCompletedTitle = self.wndCompletedDisplay:FindChild("CompletedTitle")
	wndCompletedTitle:SetAML(string.format("<P Font=\"CRB_HeaderSmall\" TextColor=\"%s\">%s</P>", strHeaderColor, tCompletedStrings[2]))
	wndCompletedTitle:SetHeightToContentHeight()

	if wndCompletedTitle:GetHeight() >= 40 then
		local nLeft, nTop, nRight, nBottom = wndCompletedTitle:GetAnchorOffsets()
		wndCompletedTitle:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 40)
		wndCompletedTitle:SetAML(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</P>", strHeaderColor, tCompletedStrings[2]))
	end
end

function Challenges:AddCompletedMessage(idChallenge, strHeader, strDescription, fDuration, eRewardOrFailState)
	-- Save our reward strings for later use (not the best solution)
    local strTabId = "" -- GOTCHA: table.remove SHIFTS down entries if indexed by numbers. Thus we use string key indices.
    if idChallenge == self.tWndTrackerTabs[1]:GetData() then
		strTabId = "1"
    elseif idChallenge == self.tWndTrackerTabs[2]:GetData() then
		strTabId = "2"
    elseif idChallenge == self.tWndTrackerTabs[3]:GetData() then
		strTabId = "3"
    elseif idChallenge == self.tWndTrackerTabs[4]:GetData() then
		strTabId = "4"
    end

    if strTabId ~= "" then
        local tNewEntry =
		{
			idChallenge,
			strHeader,
			strDescription,
		}
		self.tCompletedMessages[strTabId] = tNewEntry
    end

    -- Also set reward state. But do no other logical actions. The timer will handle the rest.
	for key, wndTrackerTab in pairs(self.tWndTrackerTabs) do
		if wndTrackerTab:GetData() == idChallenge then
			wndTrackerTab:SetData(eRewardOrFailState)
		end
	end

    -- For an auto fail message display, we need to deselect when there's only one solo challenge (exactly 3 empty tabs)
    local nCountOfEmptyTabs = 0
	for key, wndTrackerTab in pairs(self.tWndTrackerTabs) do
		if wndTrackerTab:GetData() == LuaEnumTabState.Empty then
			nCountOfEmptyTabs = nCountOfEmptyTabs + 1
		end
	end

    if nCountOfEmptyTabs == 3 then
        self.idCurrTabSelection = -1
    end
end

function Challenges:DrawMedals(clgCurrent, wndTierContainer) -- wndTierContainer can be "TrackerTierIconContainer" or "TierInlineIconContainer"
	local nCurrentTier = clgCurrent:GetDisplayTier()
	local bIsTimeTiered = clgCurrent:IsTimeTiered()

	wndTierContainer:Show(true)
	local wndBronzeTracker = wndTierContainer:FindChild("TrackerBronzeContainer:TrackerBronze") or wndTierContainer:FindChild("TierMedalContainer:TrackerBronze")
	local wndSilverTracker = wndTierContainer:FindChild("TrackerSilverContainer:TrackerSilver") or wndTierContainer:FindChild("TierMedalContainer:TrackerSilver")
	local wndGoldTracker = wndTierContainer:FindChild("TrackerGoldContainer:TrackerGold") or wndTierContainer:FindChild("TierMedalContainer:TrackerGold")
	wndSilverTracker:Show(#clgCurrent:GetAllTierCounts() >= 2)
	wndGoldTracker:Show(#clgCurrent:GetAllTierCounts() >= 3)
	wndBronzeTracker:FindChild("TrackerBronzeCheckIcon"):Show(nCurrentTier > 0)
	wndSilverTracker:FindChild("TrackerSilverCheckIcon"):Show(nCurrentTier > 1)
	wndGoldTracker:FindChild("TrackerGoldCheckIcon"):Show(nCurrentTier > 2)
	wndBronzeTracker:FindChild("TrackerBronzeBG"):SetSprite("CRB_ChallengeTrackerSprites:btnChallengeTierBackerNormal")
	wndSilverTracker:FindChild("TrackerSilverBG"):SetSprite("CRB_ChallengeTrackerSprites:btnChallengeTierBackerNormal")
	wndGoldTracker:FindChild("TrackerGoldBG"):SetSprite("CRB_ChallengeTrackerSprites:btnChallengeTierBackerNormal")
	if nCurrentTier == 0 and not bIsTimeTiered then
		wndBronzeTracker:FindChild("TrackerBronzeBG"):SetSprite("CRB_ChallengeTrackerSprites:btnChallengeTierBackerPressed")
	elseif nCurrentTier == 1 and not bIsTimeTiered then
		wndSilverTracker:FindChild("TrackerSilverBG"):SetSprite("CRB_ChallengeTrackerSprites:btnChallengeTierBackerPressed")
	elseif nCurrentTier > 1 and not bIsTimeTiered then
		wndGoldTracker:FindChild("TrackerGoldBG"):SetSprite("CRB_ChallengeTrackerSprites:btnChallengeTierBackerPressed")
	end
end

----------------------------------------------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------------------------------------------

function Challenges:DrawAllTabs(tChallengeData)
	local tChallengeTabData = {}

	for key, clgCurrent in pairs(tChallengeData) do
		if clgCurrent:IsActivated() then
			-- ASSUMPTION: We slot according to type. This relies on only 4 clgCurrent types.
			-- Type 1 is the least frequent and put into tab 4, type 3 is the default and put into tab 3
			local eType = clgCurrent:GetType()

			if eType >= 3 then
				eType = "default"
			end

			tChallengeTabData[LuaEnumTypeToTabNumber[eType]] = clgCurrent
		end
	end

	-- Now draw all tabs, even if they are active or inactive (e.g. passed/failed). This means tDataForTab can be nil.
	self:HelperDrawTab(tChallengeTabData[1], 1)
	self:HelperDrawTab(tChallengeTabData[2], 2)
	self:HelperDrawTab(tChallengeTabData[3], 3)
	self:HelperDrawTab(tChallengeTabData[4], 4)

	self.wndTracker:FindChild("TrackerTabContainer"):ArrangeChildrenHorz(0) -- Slide tabs to the left
	self:ShowOrHideTabContainer(true)
end

function Challenges:HelperDrawTab(clgCurrent, idTab) 	-- Note: tDataForTab can be nil
	local wndTrackerTab = self.tWndTrackerTabs[idTab]
	local eState = wndTrackerTab:GetData()

	-- First initialize any active challenges into tabs
	-- ASSUMPTION: No challenge IDs (eState) below 0
	if clgCurrent and eState < 0 then
		eState = self:HelperInitializeTab(wndTrackerTab, clgCurrent, idTab) -- Note: will can update eState
	end

	-- Then draw state: hide if empty, pass/fail text, or time text
	if eState == LuaEnumTabState.Empty and wndTrackerTab:IsShown() then

		wndTrackerTab:Show(false)

	elseif eState == LuaEnumTabState.Fail or eState == LuaEnumTabState.Reward then
		local wndTrackerTabTimerText = wndTrackerTab:FindChild("TrackerTabTimeText")
		local strColor = ""
		local nTextWidth = ""
		local strMessage = "" -- Hardcode art paths for translation
		if eState == LuaEnumTabState.Reward then
			strColor = kstrBrightGreen
			strMessage = "<T TextColor=\"00000000\">.</T>" .. kstrPassTabTest
			nTextWidth = Apollo.GetTextWidth(kstrSmallTimerFontPath, kstrPassTabTest)
			wndTrackerTab:ChangeArt("CRB_ChallengeTrackerSprites:btnChallengeTabPassed")
		elseif eState == LuaEnumTabState.Fail then
			strColor = kstrBrightRed
			strMessage = "<T TextColor=\"00000000\">..</T>" .. kstrFailTabTest
			nTextWidth = Apollo.GetTextWidth(kstrSmallTimerFontPath, kstrFailTabTest)
			wndTrackerTab:ChangeArt("CRB_ChallengeTrackerSprites:btnChallengeTabFailed")
		end
		
		wndTrackerTabTimerText:SetAML(string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", kstrSmallTimerFontPath, strColor, strMessage))		

		if nTextWidth > wndTrackerTabTimerText:GetWidth() - 20 then -- -20 for icon spacing
			local nLeft, nTop, nRight, nBottom = wndTrackerTab:GetAnchorOffsets()
			wndTrackerTab:SetAnchorOffsets(nLeft, nTop, nLeft + nTextWidth + 40, nBottom)
		end

	elseif eState ~= LuaEnumTabState.Empty and clgCurrent then

		wndTrackerTab:FindChild("TrackerTabTimeText"):SetAML(self:CalculateMLTimeText(clgCurrent, kstrSmallTimerFontPath))
		local nLeft, nTop, nRight, nBottom = wndTrackerTab:GetAnchorOffsets()
		wndTrackerTab:SetAnchorOffsets(nLeft, nTop, nLeft + 68, nBottom)



	end

	-- Sanity Check: (since we can swap selects via code). This runs for all tabs and will deselect as well.
	wndTrackerTab:SetCheck(self.idCurrTabSelection == idTab)
end

function Challenges:HelperInitializeTab(wndTrackerTab, clgCurrent, idTab)
	local nPreviousTabState = 0
	local idChallenge = clgCurrent:GetId()

	-- Obviously order is important here
	if self.tWndTrackerTabs[idTab] then
		nPreviousTabState = self.tWndTrackerTabs[idTab]:GetData()
		self.tWndTrackerTabs[idTab]:SetData(idChallenge)
	end

    -- First draw over any fail or reward states with our new active one
	if nPreviousTabState == LuaEnumTabState.Fail or nPreviousTabState == LuaEnumTabState.Reward then
		if self.tWndTrackerTabs[idTab] then
			self.tWndTrackerTabs[idTab]:SetData(LuaEnumTabState.Empty)
		end
		table.remove(self.tCompletedMessages, idTab)
		self.wndCompletedDisplay:Show(false)
    end

	-- Now draw the default states for the tab
	wndTrackerTab:Show(true)
	wndTrackerTab:ChangeArt("CRB_ChallengeTrackerSprites:btnChallengeTab")
	wndTrackerTab:FindChild("TrackerTabIcon"):SetSprite(self:CalculateIconPath(clgCurrent:GetType(), true))

	return idChallenge
end

function Challenges:OnTrackTab1Push(wndHandler, wndControl)
	self:OnTrackerTabPush(wndHandler:GetData(), 1)
end

function Challenges:OnTrackTab2Push(wndHandler, wndControl)
	self:OnTrackerTabPush(wndHandler:GetData(), 2)
end

function Challenges:OnTrackTab3Push(wndHandler, wndControl)
	self:OnTrackerTabPush(wndHandler:GetData(), 3)
end

function Challenges:OnTrackTab4Push(wndHandler, wndControl)
	self:OnTrackerTabPush(wndHandler:GetData(), 4)
end

function Challenges:OnTrackerTabPush(idTabChallenge, nCurrentTabNumber)
    if idTabChallenge ~= LuaEnumTabState.Empty and idTabChallenge ~= LuaEnumTabState.Fail and idTabChallenge ~= LuaEnumTabState.Reward and self.idCurrTabSelection ~= nCurrentTabNumber then
        self:StartTracker(idTabChallenge) -- If you click a timer then promote it

	elseif idTabChallenge == LuaEnumTabState.Fail then
		self:DrawCompletedMessage(nCurrentTabNumber, LuaEnumTabState.Fail)

	elseif idTabChallenge == LuaEnumTabState.Reward then
		self:DrawCompletedMessage(nCurrentTabNumber, LuaEnumTabState.Reward)
    end
	self.idCurrTabSelection = nCurrentTabNumber -- New selection
end

function Challenges:AutoPromoteAnActiveTab()
	local bThereIsAnActiveChallenge = false
	local bThereIsAFailStateToBeRead = false
	local bThereIsARewardStateToBeRead = false

	self:GetActiveChallenges()
	if #self.tActiveChallenges ~= 0 then
		bThereIsAnActiveChallenge = true
	end

	for key, wndTrackerTab in pairs(self.tWndTrackerTabs) do
		if wndTrackerTab:GetData() == LuaEnumTabState.Fail then
			bThereIsAFailStateToBeRead = true
		end
		if wndTrackerTab:GetData() == LuaEnumTabState.Reward then
			bThereIsARewardStateToBeRead = true
		end
	end

	-- If we ONLY have fail states, promote a fail one
	if not bThereIsAnActiveChallenge and bThereIsAFailStateToBeRead and not self.wndCompletedDisplay:IsShown() then
		for iTab, wndTrackerTab in pairs(self.tWndTrackerTabs) do
			if wndTrackerTab:GetData() == LuaEnumTabState.Fail and (self.idCurrTabSelection == -1 or self.idCurrTabSelection == iTab) then
				self:DrawCompletedMessage(iTab, LuaEnumTabState.Fail)
			end
		end
	end

	-- If we ONLY have reward, promote a random reward one.
	if not bThereIsAnActiveChallenge and bThereIsARewardStateToBeRead and not self.wndCompletedDisplay:IsShown() then
		for iTab, wndTrackerTab in pairs(self.tWndTrackerTabs) do
			if wndTrackerTab:GetData() == LuaEnumTabState.Reward and (self.idCurrTabSelection == -1 or self.idCurrTabSelection == iTab) then
				self:DrawCompletedMessage(iTab, LuaEnumTabState.Reward)
			end
		end
	end

	--if not bThereIsAnActiveChallenge and not bThereIsARewardStateToBeRead and not
end

function Challenges:GenerateSpellTooltip( wndHandler, wndControl, eType, splSource )
	if eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, splSource)
	end
end

----------------------------------------------------------------------------------------------------------
-- Helper Methods For the Entire Class
----------------------------------------------------------------------------------------------------------

function Challenges:ActivateChallengeAndTracker(idChallenge)
	-- Start it in code
	ChallengesLib.ActivateChallenge(idChallenge)

	local tChallengeData = ChallengesLib.GetActiveChallengeList()
	if not tChallengeData or self:GetTableSize(tChallengeData) == 0 then
		return
	end
	for idx, challenge in pairs(tChallengeData) do
		if idx == idChallenge then
			-- If we did get a successful start, start the tracker too.
			self:StartTracker(idChallenge)
			break
		end
	end
end

function Challenges:CalculateMLTimeText(clgCurrent, strFontName)
    local strTime = ""
	local strPrefix = ""

    if clgCurrent ~= nil and clgCurrent:GetTimeStr() ~= nil then
        strTime = clgCurrent:GetTimeStr()
		if string.find(strTime, "00:") == 1 then
			strTime = string.gsub(strTime, "00:", "")
			strPrefix = "00:"	-- Will display as 00: + 59
		end
    end

    return string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T><T Font=\"%s\" TextColor=\"%s\" Align=\"Left\">%s</T>", strFontName, kstrFadedBlue, strPrefix, strFontName, kstrBrightBlue, strTime)
end

function Challenges:CalculateIconPath(eType, bUseSmallVersion)
	if bUseSmallVersion == nil then
		bUseSmallVersion = false
	end
    local strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeGenericLarge" -- Icon Path Hardcoding
	if eType == ChallengesLib.ChallengeType_Combat and bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeKillTiny"
	elseif eType == ChallengesLib.ChallengeType_Combat and not bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeKillLarge"
	elseif eType == ChallengesLib.ChallengeType_Ability and bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeSkillTiny"
	elseif eType == ChallengesLib.ChallengeType_Ability and not bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeSkillLarge"
	elseif eType == ChallengesLib.ChallengeType_General and bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeGenericTiny"
	elseif eType == ChallengesLib.ChallengeType_General and not bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeGenericLarge"
	elseif eType == ChallengesLib.ChallengeType_Item and bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeLootTiny"
	elseif eType == ChallengesLib.ChallengeType_Item and not bUseSmallVersion then
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeLootLarge"
	end
    return strIconPath
end

function Challenges:CalculateIconTooltip(eType)
	local strResult = ""

	local tInfo =
	{
		["name"] = "",
		["count"] = 1  --Want "Combat Challenge", not "Combat Challenges"
	}

	if eType == ChallengesLib.ChallengeType_Combat then
		tInfo["name"] = Apollo.GetString("Challenges_CombatChallenge")
	elseif eType == ChallengesLib.ChallengeType_Ability then
		tInfo["name"] = Apollo.GetString("Challenges_AbilityChallenge")
	elseif eType == ChallengesLib.ChallengeType_General then
		tInfo["name"] = Apollo.GetString("Challenges_GeneralChallenge")
	elseif eType == ChallengesLib.ChallengeType_Item then
		tInfo["name"] = Apollo.GetString("Challenges_ItemChallenge")
	elseif eType == ChallengesLib.ChallengeType_ChecklistActivate then
		tInfo["name"] = Apollo.GetString("Challenges_ActivateChallenge")
	end

	if tInfo["name"] ~= "" then
		strResult = String_GetWeaselString(Apollo.GetString("CRB_MultipleNoNumber"), tInfo)
	end

	return string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s</P>", strResult)
end

-- This method is here because lua's # operator is misleading
function Challenges:GetTableSize(tArg)
    local nCounter = 0
    if tArg ~= nil then
        for key, value in pairs(tArg) do
            nCounter = nCounter + 1
        end
    end
    return nCounter
end

----------------------------------------------------------------------------------------------------------
-- Clean Up UI Methods
----------------------------------------------------------------------------------------------------------

function Challenges:ShowTracker()
	self.wndTracker:Show(true) -- Keep the other show/hides as other things may toggle them off
	self.wndBigDisplay:Show(true)
    self:ShowOrHideTabContainer(true)
	Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", true)
end

function Challenges:HideTracker()
    self:ResetTabs()
    self.wndTracker:Show(false) -- keep the other hides as other methods may turn them back on
    self.wndBigDisplay:Show(false)
	self:ShowOrHideTabContainer(false)
	self.wndCompletedDisplay:Show(false)
	self.wndMinimized:Show(not self.wndMinimized:IsShown())

	if self.bStopRepeatingTimer then
		self.timerRepeating:Stop()
	end

	if not self.wndTracker:IsShown() and not self.wndLeftArea:IsShown() then
		Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
	end
end

function Challenges:ResetTabs()
	for key, wndTrackerTab in pairs(self.tWndTrackerTabs) do
		if wndTrackerTab:GetData() ~= LuaEnumTabState.Fail and wndTrackerTab:GetData() ~= LuaEnumTabState.Reward and wndTrackerTab:GetData() ~= self.idLeftArea then
			wndTrackerTab:SetData(LuaEnumTabState.Empty)
			wndTrackerTab:Show(false)
		end
	end
end

function Challenges:ClearText()
	self.wndBigDisplay:FindChild("TrackerTitle"):SetText("")
	self.wndBigDisplay:FindChild("TrackerTypeIcon"):SetSprite("")
	self.wndBigDisplay:FindChild("TrackerOutcroppingArt:TrackerBigCountdown"):SetAML("")
	self.wndBigDisplay:FindChild("TrackerDescription"):SetText("")
end

function Challenges:ShowOrHideTabContainer(bArgument)
    if bArgument then
        -- If only one is shown, just hide the solo tab
        local nCountOfEmptyTabs = 0
		for key, wndTrackerTab in pairs(self.tWndTrackerTabs) do
			if wndTrackerTab:GetData() == LuaEnumTabState.Empty then
				nCountOfEmptyTabs = nCountOfEmptyTabs + 1
			end
		end
        self.wndTracker:FindChild("TrackerTabContainer"):Show(nCountOfEmptyTabs ~= 3)  -- Hide when empty tabs = 3 = solo tab
    else
        self.wndTracker:FindChild("TrackerTabContainer"):Show(false)
    end
end

function Challenges:OnAutoHideTimer()
	self.timerAutoHideLong:Stop()
	self.timerAutoHideShort:Stop()
	self.bReallyLongAutoHideTimerActive = false
	self.bReallyShortAutoHideTimerActive = false

	for idx, wndTab in pairs(self.tWndTrackerTabs) do
		wndTab:SetData(LuaEnumTabState.Empty)
	end
	self.bStopRepeatingTimer = true
	self:HideTracker()
	self:OnBlankMinimizeClick() -- Reset the Minimized Window state
end

function Challenges:HelperAllChallengesInCooldown(tChallengeData)
	if not self.wndCompletedDisplay:GetData() then
		return false
	end

	local bResult = false
	for idx, clgCurrent in pairs(tChallengeData) do
		if self.wndCompletedDisplay:GetData():GetId() == idx and clgCurrent:IsInCooldown() and not clgCurrent:ShouldCollectReward() then
			bResult = true
		elseif self.wndCompletedDisplay:GetData():GetId() == idx then
			return false
		end
	end

	return bResult
end

function Challenges:HelperConvertToTime(nArg) -- nArg is passed in as 20000 for 20 seconds
	local strResult = ""
	local nInSeconds = math.floor(nArg / 1000)
	local nHours = math.floor(nInSeconds / 3600)
	local nMins = math.floor(nInSeconds / 60 - (nHours * 60))
	local nSecs = string.format("%02.f", math.floor(nInSeconds - (nHours * 3600) - (nMins * 60)))

	if nHours ~= 0 then
		strResult = nHours .. ":" .. nMins .. ":" .. nSecs
	elseif nMins ~= 0 then
		strResult = nMins .. ":" .. nSecs
	else
		strResult = ":" .. nSecs
	end

	return strResult
end

function Challenges:GetActiveChallenges()
	local tUnlockedChallenges = ChallengesLib.GetActiveChallengeList()
	local tActivatedChallenges = {}
	for idx, clgCurrent in pairs(tUnlockedChallenges) do
		if clgCurrent:IsActivated() then
			table.insert(tActivatedChallenges, clgCurrent)
		end
	end
	self.tActiveChallenges = tActivatedChallenges
end

----------------------------------------------------------------------------------------------------------
-- Minimized Screen
----------------------------------------------------------------------------------------------------------

function Challenges:OnMinimizedExpandClick(wndHandler, wndControl)
	local bThereIsSomethingToShow = false
	for idx, challenge in pairs(ChallengesLib.GetActiveChallengeList()) do
		if challenge:IsActivated() then
			bThereIsSomethingToShow = true
			break
		end
	end

	for key, wndTrackerTab in pairs(self.tWndTrackerTabs) do
		if wndTrackerTab:GetData() == LuaEnumTabState.Fail or wndTrackerTab:GetData() == LuaEnumTabState.Reward then
			bThereIsSomethingToShow = true
			break
		end
	end

	if bThereIsSomethingToShow then
		self:ShowTracker()
		self.wndMinimized:Show(false)
	else
		self:DrawBlankTrackerMessage()
	end
end

function Challenges:DrawBlankTrackerMessage()
	self.wndMinimized:SetStyle("Moveable", true)
	--self.wndMinimized:FindChild("MinimizedContents"):Show(false) -- TODO: Remove this entirely
	self.wndMinimized:FindChild("BlankTrackerMessage"):Show(true)
end

function Challenges:OnBlankMinimizeClick()
	self.wndMinimized:SetStyle("Moveable", false)
	--self.wndMinimized:FindChild("MinimizedContents"):Show(true) -- TODO: Remove this entirely
	self.wndMinimized:FindChild("BlankTrackerMessage"):Show(false)
end

function Challenges:OnBlankBtn()
	Event_FireGenericEvent("ToggleChallengesWindow")
end

function Challenges:OnTrackerMinimizeButton()
	self.timerAutoHideLong:Stop()
	self.timerAutoHideShort:Stop()
	self.bReallyLongAutoHideTimerActive = false
	self.bReallyShortAutoHideTimerActive = false
	self.wndTracker:Close() -- Just the tracker, we can't use HideTracker()
	self.wndMinimized:Show(true)
	self:OnBlankMinimizeClick() -- Reset it to MinimizedContents
	Event_FireGenericEvent("GenericEvent_ChallengeTrackerToggled", false)
end

function Challenges:OnChallengeFailSound(idChallenge)
	Sound.Play(Sound.PlayUIChallengeFailed)
end

function Challenges:OnChallengeCompletedSound(idChallenge)
	Sound.Play(Sound.PlayUIChallengeComplete)
end

function Challenges:OnChallengeTierAchieved(idChallenge, nTier)
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
function Challenges:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.Challenge then
		return
	end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndTracker:GetRect()
	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

local ChallengesInstance = Challenges:new()
ChallengesInstance:Init()
ÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª©	‘$I’$ÿÿÿÿªªªªô ĞI—$ÿÿÿÿªªªª÷f    ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªª÷f     0ÿÿÿÿªªªªô  ¬k’$ÿÿÿÿªªªª©`’$I’$ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª¢	‘$I’$ÿÿÿÿªªªªô `
É›$ÿÿÿÿªªªªô   Sÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªô    &:ÿÿÿÿªªªªô  Ñ}’$ÿÿÿÿªªªª¢`’$I’$ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª$I$I’$ÿÿÿÿªªªªô¼I’$ÿÿÿÿªªªªô 0 y—$ÿÿÿÿªªªªõ   wÿÿÿÿªªªªûî     ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûû      ÿÿÿÿªªªªûî      ÿÿÿÿªªªªõ    ´:ÿÿÿÿªªªªô  `ë“$ÿÿÿÿªªªªôÀÚ'I’$ÿÿÿÿªªªª$H’$I’$ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª³ï$I’$ÿÿÿÿªªªªô p—I’$ÿÿÿÿªªªªô   ‰›$ÿÿÿÿªªªªô   Ü”$ÿÿÿÿªªªªõ!    ßÿÿÿÿªªªªø|    »ÿÿÿÿªªªªúÁ    —ÿÿÿÿªªªªûì    
ÿÿÿÿªªªªûì     1ÿÿÿÿªªªªúÁ    À:ÿÿÿÿªªªªø|    P?ÿÿÿÿªªªªõ!    à?ÿÿÿÿªªªªô   Ú˜$ÿÿÿÿªªªªô  @u’$ÿÿÿÿªªªªô ÀúI’$ÿÿÿÿªªªª³XŸ$I’$ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª        ÿÿÿÿªªªª