-----------------------------------------------------------------------------------------------
-- Client Lua Script for MatchTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "MatchingGame"

local MatchTracker = {}

local ktRavelIdToCTFWindowName =
{
	[0] = "CTFNeutralFlag",
	[1] = "CTFExilesHaveFlag",
	[2] = "CTFDomHaveFlag",
	[9] = "CTFStolenFlag",
}

local ktHoldLineObjectiveCountToName =
{
	[0] = Apollo.GetString("MatchTracker_CrucibleOfBlood"),
	[1] = Apollo.GetString("MatchTracker_ChamberOfGreatDark"),
	[2] = Apollo.GetString("MatchTracker_CourtOfJudges"),
}

local ktHoldLinePoint1 =
{
	[0] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_1", Apollo.GetString("MatchTracker_CrucibleOfBlood"), 	ApolloColor.new("fffff97f")},
	[1] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 		ApolloColor.new("UI_BtnTextRedNormal")},
	[2] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 		ApolloColor.new("UI_BtnTextRedNormal")},
	[3] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 		ApolloColor.new("UI_BtnTextRedNormal")},
}

local ktHoldLinePoint2 =
{
	[0] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_2", Apollo.GetString("MatchTracker_ChamberOfGreatDark"), 	ApolloColor.new("UI_TextHoloTitle")},
	[1] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_1", Apollo.GetString("MatchTracker_ChamberOfGreatDark"), 	ApolloColor.new("fffff97f")},
	[2] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 			ApolloColor.new("UI_BtnTextRedNormal")},
	[3] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 			ApolloColor.new("UI_BtnTextRedNormal")},
}

local ktHoldLinePoint3 =
{
	[0] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_2", Apollo.GetString("MatchTracker_CourtOfJudges"), ApolloColor.new("UI_TextHoloTitle")},
	[1] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_2", Apollo.GetString("MatchTracker_CourtOfJudges"), ApolloColor.new("UI_TextHoloTitle")},
	[2] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_1", Apollo.GetString("MatchTracker_CourtOfJudges"), ApolloColor.new("fffff97f")},
	[3] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 	 ApolloColor.new("UI_BtnTextRedNormal")},
}

local knSaveVersion = 1

function MatchTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.eSelectedType = nil
	o.eSelectedDesc = nil
	o.fTimeRemaining = 0
	o.fTimeInQueue = 0
	o.eMyTeam = 0

    return o
end

function MatchTracker:Init()
    Apollo.RegisterAddon(self)
end

function MatchTracker:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local bIsHoldTheLine = false
	local bIsCTF = false
	
	local tActiveEvents = PublicEvent.GetActiveEvents()
	
	for idx, peEvent in pairs(tActiveEvents) do
		if peEvent:GetEventType() == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine then
			bIsHoldTheLine = true
		end
		
		if peEvent:GetEventType() == PublicEvent.PublicEventType_PVP_Battleground_Vortex then
			bIsCTF = true
		end
	end
	
	local locHTLLocation = self.wndHoldLineFloater and self.wndHoldLineFloater:GetLocation() or self.locSavedWindowLoc
	
	local tSaved = 
	{
		tHTLWindowLocation = locHTLLocation and locHTLLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
		tSavedCTFFlags = 
		{
			bNeutral = self.wndMatchTracker and self.wndMatchTracker:FindChild("CTFNeutralFlag"):IsVisible() or nil,
			bDominion = self.wndMatchTracker and self.wndMatchTracker:FindChild("CTFDomHaveFlag"):IsVisible() or nil,
			bStolen = self.wndMatchTracker and self.wndMatchTracker:FindChild("CTFStolenFlag"):IsVisible() or nil,
			bExiles = self.wndMatchTracker and self.wndMatchTracker:FindChild("CTFExilesHaveFlag"):IsVisible() or nil
		},
	}
	
	return tSaved
end

function MatchTracker:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	self.tSavedData = tSavedData
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	local bIsHoldTheLine = false
	local bIsCTF = false

	local tActiveEvents = PublicEvent.GetActiveEvents()
	self.tActiveEvents = tActiveEvents

	for idx, peEvent in pairs(tActiveEvents) do
		if peEvent:GetEventType() == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine then
			bIsHoldTheLine = true
		end

		if peEvent:GetEventType() == PublicEvent.PublicEventType_PVP_Battleground_Vortex then
			bIsCTF = true
		end
	end

	if bIsHoldTheLine and tSavedData.tHTLWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tHTLWindowLocation)
	end

	if bIsCTF and tSavedData.tSavedCTFFlags then
		self.tSavedCTFFlags = tSavedData.tSavedCTFFlags
	end
end

-----------------------------------------------------------------------------------------------
-- MatchTracker OnLoad
-----------------------------------------------------------------------------------------------

function MatchTracker:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MatchTracker.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function MatchTracker:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("Datachron_LoadPvPContent", 	"OnLoadFromDatachron", self)
	Apollo.RegisterEventHandler("MatchEntered", 				"OnMatchEntered", self)
	Apollo.RegisterEventHandler("MatchExited", 					"OnMatchExited", self)
	Apollo.RegisterEventHandler("ChangeWorld", 					"OnMatchExited", self)
	Apollo.RegisterEventHandler("MatchingPvpInactivityAlert", 	"OnMatchPvpInactivityAlert", self)
end

function MatchTracker:OnLoadFromDatachron()
	if self.wndMatchTracker and self.wndMatchTracker:IsValid() then -- stops double-loading
		return
	end

	if self.wndHoldLineFloater and self.wndHoldLineFloater:IsValid() then
		self.locSavedWindowLoc = self.wndHoldLineFloater:GetLocation()
		self.wndHoldLineFloater:Destroy()
	end
	
	self.wndMatchTracker 	= Apollo.LoadForm(self.xmlDoc, "MatchTracker", "FixedHudStratum", self)
	self.match = nil
	self.wndHoldLineFloater = nil
	self.nHTLHintArrow 		= nil
	self.nHTLTimeToBeat 	= 0
	self.nHTLCaptureMod		= 0
	self.bHTLAttacking 		= false

	Apollo.CreateTimer("OneSecMatchTimer", 1.0, true)
	Apollo.StopTimer("OneSecMatchTimer")
	Apollo.RemoveEventHandler("OneSecMatchTimer", self)
	Apollo.RegisterTimerHandler("OneSecMatchTimer", 					"OnOneSecMatchTimer", self)
	
	Apollo.RemoveEventHandler("PVPMatchFinished",			self)
	Apollo.RemoveEventHandler("PVPMatchStateUpdated",		self)
	Apollo.RemoveEventHandler("PVPDeathmatchPoolUpdated",	self)
	Apollo.RegisterEventHandler("PVPMatchFinished", 					"OnPVPMatchFinished", self)
	Apollo.RegisterEventHandler("PVPMatchStateUpdated", 				"OnOneSecMatchTimer", self) -- For Immediate updating
	Apollo.RegisterEventHandler("PVPDeathmatchPoolUpdated", 			"OnOneSecMatchTimer", self) -- For Immediate updating

	-- CTF Events
	Apollo.RemoveEventHandler("PvP_CTF_FlagSpawned",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagDropped",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagRecovered",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagCollected",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagStolenDroppedCollected",	self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagStolen",					self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagSocketed",				self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagSpawned", 					"OnCTFFlagSpawned", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagDropped", 					"OnCTFFlagDropped", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagRecovered", 				"OnCTFFlagRecovered", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagCollected", 				"OnCTFFlagCollected", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagStolenDroppedCollected", 	"OnCTFFlagStolenDroppedCollected", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagStolen", 					"HelperCTFPlusOneFlag", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagSocketed", 				"HelperCTFMinusOneFlag", self)

	-- Hold the Line
	Apollo.RemoveEventHandler("PvP_HTL_TimeToBeat", 		self)
	Apollo.RemoveEventHandler("PvP_HTL_Respawn", 			self)
	Apollo.RemoveEventHandler("PvP_HTL_CaptureModifier", 	self)
	Apollo.RemoveEventHandler("PvP_HTL_PrepPhase",			self)
	Apollo.RegisterEventHandler("PvP_HTL_TimeToBeat", 					"OnHTLTimeToBeat", self)
	Apollo.RegisterEventHandler("PvP_HTL_Respawn", 						"OnHTLRespawn", self)
	Apollo.RegisterEventHandler("PvP_HTL_CaptureModifier", 				"OnHTLCaptureMod", self)
	Apollo.RegisterEventHandler("PvP_HTL_PrepPhase",					"OnHTLPrepPhase", self)

	-- Load window types
	self.arMatchWnd =
	{
		self.wndMatchTracker:FindChild("DeathMatchInfo"),
		self.wndMatchTracker:FindChild("CTFMatchInfo"),
		self.wndMatchTracker:FindChild("HoldLineMatchInfo"),
	}	
	
	if self.tSavedCTFFlags then
		self.wndMatchTracker:FindChild("CTFNeutralFlag"):Show(self.tSavedCTFFlags.bNeutral or false)
		self.wndMatchTracker:FindChild("CTFDomHaveFlag"):Show(self.tSavedCTFFlags.bDominion or false)
		self.wndMatchTracker:FindChild("CTFStolenFlag"):Show(self.tSavedCTFFlags.bStolen or false)
		self.wndMatchTracker:FindChild("CTFExilesHaveFlag"):Show(self.tSavedCTFFlags.bExiles or false)
		self.wndMatchTracker:FindChild("CTFAlertContainer"):ArrangeChildrenVert(1)
	end

	-- Initialization/Formatting
	self.arMatchWnd[2]:FindChild("CTFStolenFlag"):SetData(0)
	self.arMatchWnd[2]:FindChild("CTFNeutralFlag"):SetData(0)
	self.arMatchWnd[2]:FindChild("CTFDomHaveFlag"):SetData(0)
	self.arMatchWnd[2]:FindChild("CTFExilesHaveFlag"):SetData(0)

	if MatchingGame.IsInMatchingGame() or MatchingGame.IsInPVPGame() then
		self:OnMatchEntered()
	end
end

function MatchTracker:OnMatchEntered()
	if MatchingGame:IsInPVPGame() then
		Apollo.StartTimer("OneSecMatchTimer")
	end
end

function MatchTracker:OnMatchExited()
	Apollo.StopTimer("OneSecMatchTimer")
	if self.wndMatchTracker and self.wndMatchTracker:IsValid() then
		self.wndMatchTracker:Destroy()
	end
	if self.wndHoldLineFloater and self.wndHoldLineFloater:IsValid() then
		self.locSavedWindowLoc = self.wndHoldLineFloater:GetLocation()
		self.wndHoldLineFloater:Destroy()
	end
	self.nHTLTimeToBeat = 0
	if self.tLastResTeam then
		for idx = 1,2 do
			self.tLastResTeam[idx].nAmount = -1
			self.tLastResTeam[idx].nCount = 0
			self.tLastResTeam[idx].nTrend = 0
			self.tLastResTeam[idx].nTrendOverall = 0
		end
	end
end

function MatchTracker:OnMatchPvpInactivityAlert(nRemainingTimeMs)
	local nSeconds = nRemainingTimeMs / 1000 
	local strMsg = String_GetWeaselString(Apollo.GetString("Matching_PvpInactivityAlert"), nSeconds)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strMsg)
end

-----------------------------------------------------------------------------------------------
-- Main Timer
-----------------------------------------------------------------------------------------------

function MatchTracker:OnOneSecMatchTimer()
	if not self.wndMatchTracker or not self.wndMatchTracker:IsValid() then
		self:OnLoadFromDatachron()
	end

	local tMatchState = MatchingGame:GetPVPMatchState()
	if not tMatchState then
		return
	end
	
	self.wndMatchTracker:Show(true)
	self.wndMatchTracker:FindChild("TimerLabel"):SetText(self:HelperTimeString(tMatchState.fTimeRemaining))
	self.wndMatchTracker:FindChild("MessageBlockerFrame"):Show(tMatchState.eState == MatchingGame.PVPGameState.Finished or tMatchState.eState == MatchingGame.PVPGameState.Preparation)

	if tMatchState.eState == MatchingGame.PVPGameState.Preparation then
		self.wndMatchTracker:FindChild("MatchLeaveBtn"):Show(false)
		return
	elseif tMatchState.eState == MatchingGame.PVPGameState.Finished then
		self.wndMatchTracker:FindChild("MatchLeaveBtn"):Show(true)
		return
	end

	-- Look through events. ASSUME: Only one PvP event at a time
	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		if eType == PublicEvent.PublicEventType_PVP_Battleground_Vortex then
			self:DrawCTFScreen(peCurrent)
			self.match = peCurrent
		elseif eType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine then
			self:DrawHoldLineScreen(peCurrent)
			self.match = peCurrent
		else
			self.match = nil
			-- TODO: Other types
		end
	end

	-- Special case for Deathmatch, it doesn't live in events
	if tMatchState.eRules == MatchingGame.Rules.DeathmatchPool then
		self:DrawDeathmatchScreen()
	end
end

-----------------------------------------------------------------------------------------------
-- Blocker Screen (Match Finished, Match Waiting To Start)
-----------------------------------------------------------------------------------------------

function MatchTracker:OnPVPMatchFinished(eWinner, eReason)
	if self.wndHoldLineFloater and self.wndHoldLineFloater:IsValid() then
		self.locSavedWindowLoc = self.wndHoldLineFloater:GetLocation()
		self.wndHoldLineFloater:Destroy()
	end
	if not self.wndMatchTracker or not self.wndMatchTracker:IsValid() then
		self:OnLoadFromDatachron()
	end

	local tMatchState = MatchingGame:GetPVPMatchState()
	local nMyTeam = nil
	if tMatchState then
		eMyTeam = tMatchState.eMyTeam
	end

	local strMessage = Apollo.GetString("MatchTracker_MatchOver")
	if eMyTeam == eWinner and eReason == MatchingGame.MatchEndReason.Forfeit then
		strMessage = Apollo.GetString("MatchTracker_EnemyForfeit")
	elseif eMyTeam ~= eWinner and eReason == MatchingGame.MatchEndReason.Forfeit then
		strMessage = Apollo.GetString("MatchTracker_YouForfeit")
	elseif MatchingGame.Winner.Draw == eWinner then
		strMessage = Apollo.GetString("MatchTracker_Draw")
	elseif eMyTeam == eWinner then
		strMessage = Apollo.GetString("MatchTracker_Victory")
	elseif eMyTeam ~= eWinner then
		strMessage = Apollo.GetString("MatchTracker_Defeat")
	end

	self.wndMatchTracker:FindChild("MessageBlockerFrame"):Show(true)
	self.wndMatchTracker:FindChild("MatchLeaveBtn"):Show(true)
	self.wndMatchTracker:FindChild("TimerLabel"):SetText("")
end

function MatchTracker:OnMatchLeaveBtn(wndHandler, wndControl)
	if MatchingGame.IsInMatchingGame() then
		MatchingGame.LeaveMatchingGame()
	end
end

-----------------------------------------------------------------------------------------------
-- CTF Events
-----------------------------------------------------------------------------------------------

function MatchTracker:OnCTFFlagCollected(nArg) -- This is picking up a neutral flag
	self:HelperCTFMinusOneFlag(0)		--neutral flag was grabbed
	self:HelperCTFPlusOneFlag(nArg)	--One side gains a flag
end

function MatchTracker:OnCTFFlagStolenDroppedCollected(nArg) -- This is someone picking up/relaying a stolen flag
	self:HelperCTFMinusOneFlag(9)		--Stolen flag is no longer stolen
	self:HelperCTFPlusOneFlag(nArg)	--New owner for the flag
end

function MatchTracker:OnCTFFlagRecovered(nArg) -- This is a stolen flag despawning
	self:HelperCTFMinusOneFlag(9)
end

function MatchTracker:OnCTFFlagSpawned(nArg)
	self:HelperCTFMinusOneFlag(0) -- GOTCHA: Guaranteed that an in transit dropped neutral flag can be wiped when a new one spawns, removing the need of a FlagDespawn event
	self:HelperCTFPlusOneFlag(0)
end

function MatchTracker:OnCTFFlagDropped(nArg)
	if nArg == 1 then
		self:HelperCTFMinusOneFlag(2)  --Dominion loses flag
		self:HelperCTFPlusOneFlag(9)	--One flag is stolen
	elseif nArg == 2 then
		self:HelperCTFMinusOneFlag(1)	--Exiles lose flag
		self:HelperCTFPlusOneFlag(9)	--One flag is stolen
	elseif nArg == 3 then
		self:HelperCTFMinusOneFlag(2)	--Dominion loses flag
		self:HelperCTFPlusOneFlag(0)	--Flag is on the ground
	elseif nArg == 4 then
		self:HelperCTFMinusOneFlag(1)	--Exiles lose flag
		self:HelperCTFPlusOneFlag(0)	--Flag is on the ground
	end
end

function MatchTracker:HelperCTFPlusOneFlag(nArg)
	local strWindowName = ktRavelIdToCTFWindowName[nArg]
	if strWindowName then
		self.wndMatchTracker:FindChild(strWindowName):Show(true)
		self.wndMatchTracker:FindChild(strWindowName):SetData(self.wndMatchTracker:FindChild(strWindowName):GetData() + 1)
		self.wndMatchTracker:FindChild("CTFAlertContainer"):ArrangeChildrenVert(1)
	end
end

function MatchTracker:HelperCTFMinusOneFlag(nArg)
	local strWindowName = ktRavelIdToCTFWindowName[nArg]
	if strWindowName then
		self.wndMatchTracker:FindChild(strWindowName):SetData(math.max(0, self.wndMatchTracker:FindChild(strWindowName):GetData() - 1))
	end
	self.wndMatchTracker:FindChild("CTFNeutralFlag"):Show(self.wndMatchTracker:FindChild("CTFNeutralFlag"):GetData() > 0)
	self.wndMatchTracker:FindChild("CTFDomHaveFlag"):Show(self.wndMatchTracker:FindChild("CTFDomHaveFlag"):GetData() > 0)
	self.wndMatchTracker:FindChild("CTFStolenFlag"):Show(self.wndMatchTracker:FindChild("CTFStolenFlag"):GetData() > 0)
	self.wndMatchTracker:FindChild("CTFExilesHaveFlag"):Show(self.wndMatchTracker:FindChild("CTFExilesHaveFlag"):GetData() > 0)
	self.wndMatchTracker:FindChild("CTFAlertContainer"):ArrangeChildrenVert(1)
end

-----------------------------------------------------------------------------------------------
-- Death Match
-----------------------------------------------------------------------------------------------

function MatchTracker:DrawDeathmatchScreen()
	local tMatchState = MatchingGame:GetPVPMatchState()
	if not tMatchState or tMatchState.eRules ~= MatchingGame.Rules.DeathmatchPool then
		return
	end

	self:HelperClearMatchesExcept(1)
	local wndInfo = self.arMatchWnd[1]
	local tMyTeam = tMatchState.eMyTeam
	local nLivesTeam1 = tMatchState.tLivesRemaining.nTeam1
	local nLivesTeam2 = tMatchState.tLivesRemaining.nTeam2

	local strOldCount1 = wndInfo:FindChild("MyTeam"):GetText()
	local strOldCount2 = wndInfo:FindChild("OtherTeam"):GetText()

	if tMyTeam == MatchingGame.Team.Team1 then
		wndInfo:FindChild("MyTeam"):SetText(nLivesTeam1)
		wndInfo:FindChild("OtherTeam"):SetText(nLivesTeam2)
	else
		strOldCount2 = wndInfo:FindChild("MyTeam"):GetText()
		strOldCount1 = wndInfo:FindChild("OtherTeam"):GetText()
		wndInfo:FindChild("MyTeam"):SetText(nLivesTeam2)
		wndInfo:FindChild("OtherTeam"):SetText(nLivesTeam1)
	end
	
	if tonumber(strOldCount1) ~= nLivesTeam1 or tonumber(strOldCount2) ~= nLivesTeam2 then
		wndInfo:FindChild("AlertFlash"):SetSprite("CRB_Basekit:kitAccent_Glow_BlueFlash")
	end
end

-----------------------------------------------------------------------------------------------
-- CTF
-----------------------------------------------------------------------------------------------

function MatchTracker:DrawCTFScreen(peMatch)
	if not peMatch then
		return
	end

	self:HelperClearMatchesExcept(2)
	local wndInfo = self.arMatchWnd[2]
	wndInfo:SetData(peMatch)

	for idObjective, peoCurrent in pairs(peMatch:GetObjectives()) do
		local wndToUse = wndInfo:FindChild("CTFExileFrame")

		local bIsExile = GameLib.GetPlayerUnit():GetFaction() == 391
		local bMyTeam = peoCurrent:GetTeam() == peMatch:GetJoinedTeam()
		if (bMyTeam and not bIsExile) or (not bMyTeam and bIsExile)  then
			wndToUse = wndInfo:FindChild("CTFDomFrame")
		end

		for idx = 1, peoCurrent:GetRequiredCount() do
			if wndToUse:FindChild("FlagIcon" .. idx) and idx > peoCurrent:GetCount() then
				wndToUse:FindChild("FlagIcon" .. idx):SetBGColor(ApolloColor.new("ff444444"))
			elseif wndToUse:FindChild("FlagIcon" .. idx) then
				wndToUse:FindChild("FlagIcon" .. idx):SetBGColor(ApolloColor.new("ffffffff"))
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Hold The Line
-----------------------------------------------------------------------------------------------

function MatchTracker:DrawHoldLineScreen(peMatch)
	if not peMatch then return end

	if not self.wndHoldLineFloater or not self.wndHoldLineFloater:IsValid() then
		self.wndHoldLineFloater = Apollo.LoadForm(self.xmlDoc, "HoldTheLinePvPForm", nil, self)
		
		if self.locSavedWindowLoc then
			self.wndHoldLineFloater:MoveToLocation(self.locSavedWindowLoc)
		end
	end

	self:HelperClearMatchesExcept(3)
	local wndDatachron = self.arMatchWnd[3]
	local wndFloat = self.wndHoldLineFloater
	local strTitleText = ""
	local nTotalTime = 0;
	wndDatachron:SetData(peMatch)
	
	--1420 - PvP Hold The Line Volume Capture Point 1
	peoCurrent = peMatch:GetObjective(1420)
	--1002 - PvP Hold The Line Capture Point 1a
	peoEastCapturePoint = peMatch:GetObjective(1002)
	--1003 - PvP Hold The Line Capture Point 1b 
	peoWestCapturePoint = peMatch:GetObjective(1003)	
	
	--1300 - PvP Hold The Line Volume Capture Point 2 
	if peoCurrent:GetRequiredCount() == 0 then
		peoCurrent = peMatch:GetObjective(1300)
		
		--1312 - PvP Hold The Line Capture Point 2a
		peoEastCapturePoint = peMatch:GetObjective(1312)
		--1313 - PvP Hold The Line Capture Point 2b 
		peoWestCapturePoint = peMatch:GetObjective(1313)
	end
	
	--1421 - PvP Hold The Line Volume Capture Point 3 
	if peoCurrent:GetRequiredCount() == 0 then
		peoCurrent = peMatch:GetObjective(1421)
		
		--1401 - PvP Hold The Line Capture Point 3a
		peoEastCapturePoint = peMatch:GetObjective(1401)
		--1402 - PvP Hold The Line Capture Point 3b
		peoWestCapturePoint = peMatch:GetObjective(1402)
	end
	
	if peoCurrent ~= nil then
		local nLastValue = wndFloat:FindChild("MainProgBar"):GetData() or 0
		local nCurrValue = peoCurrent:GetCount()
		local nMaxValue = peoCurrent:GetRequiredCount()
		
		wndFloat:FindChild("TitleText"):SetData(nCurrValue)
		wndFloat:FindChild("MainProgBar"):SetData(nCurrValue)
		wndFloat:FindChild("MainProgBar"):SetMax(nMaxValue)
		wndFloat:FindChild("MainProgBar"):SetProgress(nCurrValue, 1.5)
		
		if nLastValue <= 0 or nLastValue > nCurrValue then
			wndFloat:FindChild("MainProgBar"):SetProgress(nCurrValue)
		end

		if not self.nHTLHintArrow or self.nHTLHintArrow ~= peoCurrent then
			wndDatachron:FindChild("HoldLineMouseCatcher"):SetData(peoCurrent)
			self.nHTLHintArrow = peoCurrent
			self.nHTLHintArrow:ShowHintArrow()
		end
		
		local bExileIsAttacking = false;
		local bIsExile = MatchingGame.GetPVPMatchState().eMyTeam == 0
		local bMyTeam = peoCurrent:GetTeam() == peMatch:GetJoinedTeam()
		if (bMyTeam and bIsExile) or (not bMyTeam and not bIsExile)  then
			bExileIsAttacking = true;
		end
		
		--setup textures
		if nCurrValue <= 0 or nCurrValue == nil or nCurrValue > 99 or nLastValue <= 0 then
			if bExileIsAttacking then
				wndFloat:FindChild("ProgressFrame"):SetSprite("spr_HoldTheLine_BlueFrame")
				wndFloat:FindChild("Charge1"):SetSprite("spr_HoldTheLine_BlueCharge1")
				wndFloat:FindChild("Charge2"):SetSprite("spr_HoldTheLine_BlueCharge2")
				wndFloat:FindChild("animCharge1"):SetSprite("spr_HoldTheLine_animBlueSpark1")
				wndFloat:FindChild("animCharge2"):SetSprite("spr_HoldTheLine_animBlueSpark2")
				wndFloat:FindChild("Completed1"):SetSprite("spr_HoldTheLine_BlueCheckLeft")
				wndFloat:FindChild("Completed2"):SetSprite("spr_HoldTheLine_BlueCheckRight")
				wndFloat:FindChild("ProgressFrame"):SetSprite("spr_HoldTheLine_BlueFrame")
				wndFloat:FindChild("MainProgBar"):SetFullSprite("spr_HoldTheLine_BlueFill")
				wndFloat:FindChild("TitleText"):SetTextColor("ff81ffef");
				
				if bIsExile then
					wndFloat:FindChild("SecondaryArrow1"):SetSprite("spr_HoldTheLine_IconBlueOffense")
					wndFloat:FindChild("SecondaryArrow2"):SetSprite("spr_HoldTheLine_IconBlueOffense")
				else
					wndFloat:FindChild("SecondaryArrow1"):SetSprite("spr_HoldTheLine_IconRedDefense")
					wndFloat:FindChild("SecondaryArrow2"):SetSprite("spr_HoldTheLine_IconRedDefense")
				end

			else
				wndFloat:FindChild("ProgressFrame"):SetSprite("spr_HoldTheLine_RedFrame")
				wndFloat:FindChild("Charge1"):SetSprite("spr_HoldTheLine_RedCharge1")
				wndFloat:FindChild("Charge2"):SetSprite("spr_HoldTheLine_RedCharge2")
				wndFloat:FindChild("animCharge1"):SetSprite("spr_HoldTheLine_animRedSpark1")
				wndFloat:FindChild("animCharge2"):SetSprite("spr_HoldTheLine_animRedSpark2")
				wndFloat:FindChild("Completed1"):SetSprite("spr_HoldTheLine_RedCheckLeft")
				wndFloat:FindChild("Completed2"):SetSprite("spr_HoldTheLine_RedCheckRight")
				wndFloat:FindChild("ProgressFrame"):SetSprite("spr_HoldTheLine_RedFrame")
				wndFloat:FindChild("MainProgBar"):SetFullSprite("spr_HoldTheLine_RedFill")
				wndFloat:FindChild("TitleText"):SetTextColor("fffaef91");
				
				if bIsExile then
					wndFloat:FindChild("SecondaryArrow1"):SetSprite("spr_HoldTheLine_IconBlueDefense")
					wndFloat:FindChild("SecondaryArrow2"):SetSprite("spr_HoldTheLine_IconBlueDefense")
				else
					wndFloat:FindChild("SecondaryArrow1"):SetSprite("spr_HoldTheLine_IconRedOffense")
					wndFloat:FindChild("SecondaryArrow2"):SetSprite("spr_HoldTheLine_IconRedOffense")
				end
			end
		end
	end
	
	wndFloat:FindChild("Charge1"):SetOpacity(0.15)
	wndFloat:FindChild("Charge2"):SetOpacity(0.15)
	
	if peoEastCapturePoint ~= nil then
		wndFloat:FindChild("Completed1"):Show(peoEastCapturePoint:GetCount() == peoEastCapturePoint:GetRequiredCount())
		wndFloat:FindChild("Charge1"):Show(peoEastCapturePoint:GetCount() == peoEastCapturePoint:GetRequiredCount())
		wndFloat:FindChild("animCharge1"):Show(peoEastCapturePoint:GetCount() == peoEastCapturePoint:GetRequiredCount())
		wndFloat:FindChild("SecondaryArrow1"):Show(peoEastCapturePoint:GetCount() == 1)
	end
	
	if peoWestCapturePoint ~= nil then
		wndFloat:FindChild("Completed2"):Show(peoWestCapturePoint:GetCount() == peoWestCapturePoint:GetRequiredCount())
		wndFloat:FindChild("Charge2"):Show(peoWestCapturePoint:GetCount() == peoWestCapturePoint:GetRequiredCount())
		wndFloat:FindChild("animCharge2"):Show(peoWestCapturePoint:GetCount() == peoWestCapturePoint:GetRequiredCount())
		wndFloat:FindChild("SecondaryArrow2"):Show(peoWestCapturePoint:GetCount() == 1)
	end
	
	peoScriptCurrent = peMatch:GetObjective(970)

	local nCount = peoScriptCurrent:GetCount()
	local nPercent =  wndFloat:FindChild("TitleText"):GetData() or 0
	strTitleText = String_GetWeaselString(Apollo.GetString("MatchTracker_ObjectiveProgress"), nPercent, ktHoldLineObjectiveCountToName[nCount])

	if peoScriptCurrent:GetTeam() == peMatch:GetJoinedTeam() then
		wndDatachron:FindChild("HoldLineTitle"):SetText(Apollo.GetString("MatchTracker_YouAreAttacking"))
		wndDatachron:FindChild("HoldLineTitle"):SetTextColor("ffff3030")
	else
		wndDatachron:FindChild("HoldLineTitle"):SetText(Apollo.GetString("MatchTracker_YouAreDefending"))
		wndDatachron:FindChild("HoldLineTitle"):SetTextColor("ff30ff30")
	end

	for idx, tData in pairs({ktHoldLinePoint1, ktHoldLinePoint2, ktHoldLinePoint3}) do
		wndDatachron:FindChild("HoldLineIcon" .. idx):SetSprite(tData[nCount][1])
		wndDatachron:FindChild("HoldLineText" .. idx):SetText(tData[nCount][2])
		wndDatachron:FindChild("HoldLineText" .. idx):SetTextColor(tData[nCount][3])
	end
	
	nTotalTime = peoScriptCurrent:GetTotalTime() / 1000;
	self.wndMatchTracker:FindChild("TimerLabel"):SetText(self:HelperTimeString((peoScriptCurrent:GetTotalTime() - peoScriptCurrent:GetElapsedTime()) / 1000))
	self.wndHoldLineFloater:FindChild("TimerText"):SetText(self:HelperTimeString((peoScriptCurrent:GetTotalTime() - peoScriptCurrent:GetElapsedTime()) / 1000))
	
	wndFloat:FindChild("TitleTextRight"):SetText("")
	wndFloat:FindChild("CaptureModText"):SetText(string.format("%s%s", self.nHTLCaptureMod, "x"))
	
	local tMatchState = MatchingGame:GetPVPMatchState()
	if self.nHTLTimeToBeat and self.nHTLTimeToBeat > 0 and tMatchState and self.bHTLAttacking then
		strTimerText = String_GetWeaselString(Apollo.GetString("MatchTracker_FinalRoundTimer"), self:HelperTimeString(tMatchState.fTimeRemaining))
		wndFloat:FindChild("TitleTextRight"):SetText(String_GetWeaselString(Apollo.GetString("MatchTracker_TimeToBeat"), self:HelperTimeString(nTotalTime - self.nHTLTimeToBeat)))
	elseif self.nHTLTimeToBeat and self.nHTLTimeToBeat > 0 and tMatchState then
		strTimerText = String_GetWeaselString(Apollo.GetString("MatchTracker_FinalRoundTimer"), self:HelperTimeString(tMatchState.fTimeRemaining))
		wndFloat:FindChild("TitleTextRight"):SetText(String_GetWeaselString(Apollo.GetString("MatchTracker_HoldTheLineTimer"), self:HelperTimeString(nTotalTime - self.nHTLTimeToBeat)))
	elseif tMatchState and tMatchState.fTimeRemaining > 0 then
		wndFloat:FindChild("TitleTextRight"):SetText(String_GetWeaselString(Apollo.GetString("MatchTracker_StartTimer"), self:HelperTimeString(tMatchState.fTimeRemaining)))
	elseif tMatchState then
		--strTitleTextRight = Apollo.GetString("MatchTracker_Waiting")
	else
		--strTitleTextRight = Apollo.GetString("MatchTracker_MatchProgressWaiting")
	end
	
	wndFloat:FindChild("TitleText"):SetText(strTitleText)
end

function MatchTracker:OnHTLTimeToBeat(nSeconds, bAttacking)
	if self.wndHoldLineFloater and self.wndHoldLineFloater:IsValid() then
		self.nHTLTimeToBeat = nSeconds
		self.bHTLAttacking = bAttacking
	end
end

function MatchTracker:OnHoldLineMouseCatcherClick(wndHandler, wndControl)
	if wndHandler:GetData() then
		wndHandler:GetData():ShowHintArrow()
	end
end

function MatchTracker:OnHTLRespawn()
	if self.nHTLHintArrow then
		self.nHTLHintArrow:ShowHintArrow()
	end
end

function MatchTracker:OnHTLCaptureMod(nWhole, nDec)
	self.nHTLCaptureMod = nWhole + nDec / 100
end

function MatchTracker:OnHTLPrepPhase(bPreping)
	if self.match ~= nil then
		self:DrawHoldLineScreen(self.match)
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function MatchTracker:OnViewEventStatsBtn(wndHandler, wndControl) -- ViewEventStatsBtn
	for idx, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		if peCurrent:HasLiveStats() then
			local eType = peCurrent:GetEventType()
			if eType == PublicEvent.PublicEventType_PVP_Warplot or eType == PublicEvent.PublicEventType_PVP_Battleground_Vortex or eType == PublicEvent.PublicEventType_PVP_Arena
			or eType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine or eType == PublicEvent.PublicEventType_PVP_Battleground_Sabotage
			or eType == PublicEvent.PublicEventType_PVP_Battleground_Cannon then
				local tLiveStats = peCurrent:GetLiveStats()
				
				Event_FireGenericEvent("GenericEvent_OpenEventStats", peCurrent, peCurrent:GetMyStats(), tLiveStats.arTeamStats, tLiveStats.arParticipantStats)
				return
			end
		end
	end
end

function MatchTracker:HelperClearMatchesExcept(nShow) -- hides all other window types
	for idx = 1, #self.arMatchWnd do
		self.arMatchWnd[idx]:Show(false)
	end

	if nShow ~= nil then
		self.arMatchWnd[nShow]:Show(true)
	end
end

function MatchTracker:HelperTimeString(nTimeInSeconds)
	if nTimeInSeconds == nil or nTimeInSeconds <= 0 then
		return "--:--"
	end
	
	nTimeInSeconds = math.floor(nTimeInSeconds)
	local nMinutes = math.floor(nTimeInSeconds / 60)
	local nSeconds = math.floor(nTimeInSeconds % 60)
	if nSeconds < 10 then
		return nMinutes .. ":0" .. nSeconds
	end
	return nMinutes .. ":" .. nSeconds
end

-----------------------------------------------------------------------------------------------
-- MatchTracker Instance
-----------------------------------------------------------------------------------------------
local MatchTrackerInst = MatchTracker:new()
MatchTrackerInst:Init()