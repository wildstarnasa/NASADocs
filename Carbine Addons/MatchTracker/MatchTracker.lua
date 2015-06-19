-----------------------------------------------------------------------------------------------
-- Client Lua Script for MatchTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "MatchingGame"

local MatchTracker = {}

--Colors
local kcrAttack = ApolloColor.new("ffff3030")
local kcrDefend = ApolloColor.new("ff30ff30")

local LuaEnumTeam = 
{
	Red 	= 0,
	Blue 	= 1,
	Neutral = 2,
	Stolen 	= 9,
}

local ktRavelIdToCTFWindowName =
{
	[LuaEnumTeam.Red] 		= "CTFRedHaveFlag",
	[LuaEnumTeam.Blue] 		= "CTFBlueHaveFlag",
	[LuaEnumTeam.Neutral] 	= "CTFNeutralFlag",
	[LuaEnumTeam.Stolen] 	= "CTFStolenFlag",
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
	[1] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 		ApolloColor.new("xkcdReddish")},
	[2] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 		ApolloColor.new("xkcdReddish")},
	[3] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 		ApolloColor.new("xkcdReddish")},
}

local ktHoldLinePoint2 =
{
	[0] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_2", Apollo.GetString("MatchTracker_ChamberOfGreatDark"), 	ApolloColor.new("UI_TextHoloTitle")},
	[1] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_1", Apollo.GetString("MatchTracker_ChamberOfGreatDark"), 	ApolloColor.new("fffff97f")},
	[2] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 			ApolloColor.new("xkcdReddish")},
	[3] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 			ApolloColor.new("xkcdReddish")},
}

local ktHoldLinePoint3 =
{
	[0] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_2", Apollo.GetString("MatchTracker_CourtOfJudges"), ApolloColor.new("UI_TextHoloTitle")},
	[1] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_2", Apollo.GetString("MatchTracker_CourtOfJudges"), ApolloColor.new("UI_TextHoloTitle")},
	[2] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_1", Apollo.GetString("MatchTracker_CourtOfJudges"), ApolloColor.new("fffff97f")},
	[3] = {"ClientSprites:Icon_ItemMisc_UI_Item_Crafting_Special_3", Apollo.GetString("MatchTracker_Catpured"), 	 ApolloColor.new("xkcdReddish")},
}

local ktPvPEventTypes =
{
	[PublicEvent.PublicEventType_PVP_Warplot] 					= 1,
	[PublicEvent.PublicEventType_PVP_Battleground_Vortex] 		= 1,
	[PublicEvent.PublicEventType_PVP_Arena] 					= 1,
	[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] 	= 1,
	[PublicEvent.PublicEventType_PVP_Battleground_Sabotage] 	= 1,
	[PublicEvent.PublicEventType_PVP_Battleground_Cannon] 		= 1,
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
	
	o.tWndRefs = {}

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
			bNeutral = self.tWndRefs.wndMatchTracker and self.tWndRefs.wndMatchTracker:FindChild("CTFNeutralFlag"):IsVisible() or nil,
			bRed = self.tWndRefs.wndMatchTracker and self.tWndRefs.wndMatchTracker:FindChild("CTFRedHaveFlag"):IsVisible() or nil,
			bStolen = self.tWndRefs.wndMatchTracker and self.tWndRefs.wndMatchTracker:FindChild("CTFStolenFlag"):IsVisible() or nil,
			bBlue = self.tWndRefs.wndMatchTracker and self.tWndRefs.wndMatchTracker:FindChild("CTFBlueHaveFlag"):IsVisible() or nil
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
	
	Apollo.RegisterEventHandler("MatchEntered", 				"OnMatchEntered", self)
	Apollo.RegisterEventHandler("MatchExited", 					"OnMatchExited", self)
	Apollo.RegisterEventHandler("ChangeWorld", 					"OnMatchExited", self)
	Apollo.RegisterEventHandler("MatchingPvpInactivityAlert", 	"OnMatchPvpInactivityAlert", self)
	
	self.timerTeamAlert = ApolloTimer.Create(5.0, false, "OnHideTeamAlert", self)
	self.timerTeamAlert:Stop()
	
	self:ResetTracker()
end

function MatchTracker:ResetTracker()
	if self.tWndRefs.wndMatchTracker ~= nil and self.tWndRefs.wndMatchTracker:IsValid() then -- stops double-loading
		return
	end

	if self.wndHoldLineFloater and self.wndHoldLineFloater:IsValid() then
		self.locSavedWindowLoc = self.wndHoldLineFloater:GetLocation()
		self.wndHoldLineFloater:Destroy()
	end
	
	self.tWndRefs.wndMatchTracker 	= Apollo.LoadForm(self.xmlDoc, "MatchTracker", "FixedHudStratum", self)
	
	self.match 					= nil
	self.wndHoldLineFloater 	= nil
	self.nHTLHintArrow 			= nil
	self.nHTLTimeToBeat 		= 0
	self.nHTLCaptureMod			= 0
	self.bHTLAttacking 			= false

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
	
	Apollo.RegisterEventHandler("PublicEventEnd",						"OnPublicEventEnd", self)

	-- CTF Events
	Apollo.RemoveEventHandler("PvP_CTF_FlagSpawned",				self)
	Apollo.RemoveEventHandler("PvP_CTF_NeutralDespawned",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagDropped",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagRecovered",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagCollected",				self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagStolenDroppedCollected",	self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagStolen",					self)
	Apollo.RemoveEventHandler("PvP_CTF_FlagSocketed",				self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagSpawned", 					"OnCTFFlagSpawned", self)
	Apollo.RegisterEventHandler("PvP_CTF_NeutralDespawned", 				"OnCTFFlagDespawned", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagDropped", 					"OnCTFFlagDropped", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagRecovered", 				"OnCTFFlagRecovered", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagCollected", 				"OnCTFFlagCollected", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagStolenDroppedCollected", 	"OnCTFFlagStolenDroppedCollected", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagStolen", 					"OnCTFFlagStollen", self)
	Apollo.RegisterEventHandler("PvP_CTF_FlagSocketed", 				"OnCTFFlagSocketed", self)

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
	self.tWndRefs.tMatchWnd = {
		[PublicEvent.PublicEventType_PVP_Arena] 					= self.tWndRefs.wndMatchTracker:FindChild("DeathMatchInfo"),
		[PublicEvent.PublicEventType_PVP_Battleground_Vortex] 		= self.tWndRefs.wndMatchTracker:FindChild("CTFMatchInfo"),
		[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] 	= self.tWndRefs.wndMatchTracker:FindChild("HoldLineMatchInfo"),
	}
	
	if self.tSavedCTFFlags then
		self.tWndRefs.wndMatchTracker:FindChild("CTFNeutralFlag"):Show(self.tSavedCTFFlags.bNeutral or false)
		self.tWndRefs.wndMatchTracker:FindChild("CTFRedHaveFlag"):Show(self.tSavedCTFFlags.bRed or false)
		self.tWndRefs.wndMatchTracker:FindChild("CTFStolenFlag"):Show(self.tSavedCTFFlags.bStolen or false)
		self.tWndRefs.wndMatchTracker:FindChild("CTFBlueHaveFlag"):Show(self.tSavedCTFFlags.bBlue or false)
		self.tWndRefs.wndMatchTracker:FindChild("CTFAlertContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.Middle)
	end

	-- Initialization/Formatting
	self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_Vortex]:FindChild("CTFStolenFlag"):SetData(0)
	self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_Vortex]:FindChild("CTFNeutralFlag"):SetData(0)
	self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_Vortex]:FindChild("CTFRedHaveFlag"):SetData(0)
	self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_Vortex]:FindChild("CTFBlueHaveFlag"):SetData(0)

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
	if self.tWndRefs.wndMatchTracker ~= nil and self.tWndRefs.wndMatchTracker:IsValid() then
		self.tWndRefs.wndMatchTracker:Destroy()
		self.tWndRefs = {}
	end
	if self.wndHoldLineFloater and self.wndHoldLineFloater:IsValid() then
		self.locSavedWindowLoc = self.wndHoldLineFloater:GetLocation()
		self.wndHoldLineFloater:Destroy()
		self.wndHoldLineFloater = nil
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
	
	self.peMatch = nil
	self.tZombieEvent = nil
end

function MatchTracker:OnMatchPvpInactivityAlert(nRemainingTimeMs)
	local nSeconds = nRemainingTimeMs / 1000 
	local strMsg = String_GetWeaselString(Apollo.GetString("Matching_PvpInactivityAlert"), nSeconds)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strMsg)
end

function MatchTracker:OnShowTeamAlert(peEvent)
	local wndMessage = self.tWndRefs.wndMatchTracker:FindChild("PrepPhase")
	local bIsBlueTeam = MatchingGame.GetPVPMatchState().eMyTeam == LuaEnumTeam.Blue
	wndMessage:SetText(bIsBlueTeam and Apollo.GetString("MatchTracker_AlertBlue") or Apollo.GetString("MatchTracker_AlertRed"))
	wndMessage:SetTextColor(bIsBlueTeam and "UI_TextHoloBodyHighlight" or "UI_WindowTextRed")
	wndMessage:Show(true)
	
	self.timerTeamAlert:Set(5.0, false)
	self.timerTeamAlert:Start()
end

function MatchTracker:OnHideTeamAlert()
	self.tWndRefs.wndMatchTracker:FindChild("PrepPhase"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Main Timer
-----------------------------------------------------------------------------------------------

function MatchTracker:OnOneSecMatchTimer()
	if not self.tWndRefs.wndMatchTracker or not self.tWndRefs.wndMatchTracker:IsValid() then
		self:ResetTracker()
	end

	local tMatchState = MatchingGame:GetPVPMatchState()
	if not tMatchState then
		return
	end
	
	self.tWndRefs.wndMatchTracker:Show(true)
	self.tWndRefs.wndMatchTracker:FindChild("TimerLabel"):SetText(self:HelperTimeString(tMatchState.fTimeRemaining))
	self.tWndRefs.wndMatchTracker:FindChild("MessageBlockerFrame"):Show(tMatchState.eState == MatchingGame.PVPGameState.Finished or tMatchState.eState == MatchingGame.PVPGameState.Preparation)
	
	if not self.peMatch then
		for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
			local eType = peCurrent:GetEventType()
			
			if eType == PublicEvent.PublicEventType_PVP_Battleground_Vortex then
				self.peMatch = peCurrent
				self:SetupFlags(tMatchState)
				self:OnShowTeamAlert(peCurrent)
				break
			elseif eType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine or eType == PublicEvent.PublicEventType_PVP_Arena then
				self.peMatch = peCurrent
				break
			elseif eType == PublicEvent.PublicEventType_PVP_Warplot or PublicEvent.PublicEventType_PVP_Battleground_Sabotage then
				self.peMatch = peCurrent
				self:OnShowTeamAlert(peCurrent)
				break
			end
		end
	end

	if tMatchState.eState == MatchingGame.PVPGameState.Preparation then
		self.tWndRefs.wndMatchTracker:FindChild("BGArt"):Show(false)
		self:HideHoldLineScreen()
		return
	elseif tMatchState.eState == MatchingGame.PVPGameState.Finished then
		self.tWndRefs.wndMatchTracker:FindChild("BGArt"):Show(true)
		return
	end

	-- Look through events. ASSUME: Only one PvP event at a time
	if self.peMatch then
		local eType = self.peMatch:GetEventType()
		
		if eType == PublicEvent.PublicEventType_PVP_Battleground_Vortex then
			self:DrawCTFScreen(self.peMatch)
		elseif eType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine then
			self:DrawHoldLineScreen(self.peMatch)
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
		self.wndHoldLineFloater = nil
	end
	if not self.tWndRefs.wndMatchTracker or not self.tWndRefs.wndMatchTracker:IsValid() then
		self:ResetTracker()
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

	self.tWndRefs.wndMatchTracker:FindChild("MessageBlockerFrame"):Show(true)
	self.tWndRefs.wndMatchTracker:FindChild("BGArt"):Show(true)
	self.tWndRefs.wndMatchTracker:FindChild("TimerLabel"):SetText("")
end

function MatchTracker:OnMatchLeaveBtn(wndHandler, wndControl)
	if MatchingGame.IsInMatchingGame() then
		MatchingGame.LeaveMatchingGame()
	end
end

-----------------------------------------------------------------------------------------------
-- CTF Events
-----------------------------------------------------------------------------------------------
function MatchTracker:SetupFlags(tMatchState)
	local strLeftSprite = "ClientSprites:Icon_Mission_Explorer_ClaimTerritory"
	local strRightSprite = "ClientSprites:Icon_Mission_Explorer_ClaimTerritory_TEMP_Red"
	
	if tMatchState.eMyTeam == LuaEnumTeam.Red then
		strLeftSprite = "ClientSprites:Icon_Mission_Explorer_ClaimTerritory_TEMP_Red"
		strRightSprite = "ClientSprites:Icon_Mission_Explorer_ClaimTerritory"
	end
	
	local tLeftChildren = self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_Vortex]:FindChild("CTFLeftFrame"):GetChildren()
	local tRightChildren = self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_Vortex]:FindChild("CTFRightFrame"):GetChildren()
		
	for idx = 1, #tLeftChildren do
		tLeftChildren[idx]:SetSprite(strLeftSprite)
		tRightChildren[idx]:SetSprite(strRightSprite)
	end
end

function MatchTracker:OnCTFFlagCollected(nArg) -- This is picking up a neutral flag
	self:HelperCTFMinusOneFlag(LuaEnumTeam.Neutral)		--neutral flag was grabbed
	self:HelperCTFPlusOneFlag(nArg == LuaEnumTeam.Blue and LuaEnumTeam.Blue or LuaEnumTeam.Red) --One side gains a flag
end

function MatchTracker:OnCTFFlagStolenDroppedCollected(nArg) -- This is someone picking up/relaying a stolen flag
	self:HelperCTFMinusOneFlag(LuaEnumTeam.Stolen)		--Stolen flag is no longer stolen
	self:HelperCTFPlusOneFlag(nArg == LuaEnumTeam.Blue and LuaEnumTeam.Blue or LuaEnumTeam.Red) --One side gains a flag
end

function MatchTracker:OnCTFFlagRecovered(nArg) -- This is a stolen flag despawning
	self:HelperCTFMinusOneFlag(LuaEnumTeam.Stolen)
end

function MatchTracker:OnCTFFlagSpawned(nArg)
	self:HelperCTFPlusOneFlag(LuaEnumTeam.Neutral)
end

function MatchTracker:OnCTFFlagDespawned()
	self:HelperCTFMinusOneFlag(LuaEnumTeam.Neutral)
end

function MatchTracker:OnCTFFlagDropped(nArg)
	if nArg == 1 then--Blue Team stole Red's Flag
		self:HelperCTFMinusOneFlag(LuaEnumTeam.Red)  --Red loses flag
		self:HelperCTFPlusOneFlag(LuaEnumTeam.Stolen)	--One flag is stolen
	elseif nArg == 2 then--Red Team stole Blue's Flag
		self:HelperCTFMinusOneFlag(LuaEnumTeam.Blue)	--Blue lose flag
		self:HelperCTFPlusOneFlag(LuaEnumTeam.Stolen)	--One flag is stolen
	elseif nArg == 3 then--Blue Team Dropped Neutral Flag
		self:HelperCTFMinusOneFlag(LuaEnumTeam.Blue)	--Red loses flag
		self:HelperCTFPlusOneFlag(LuaEnumTeam.Neutral)	--Flag is on the ground
	elseif nArg == 4 then--Red Team Dropped Neutral Flag
		self:HelperCTFMinusOneFlag(LuaEnumTeam.Red)	--Blue lose flag
		self:HelperCTFPlusOneFlag(LuaEnumTeam.Neutral)	--Flag is on the ground
	end
end

function MatchTracker:OnCTFFlagStollen(nArg)
	self:HelperCTFPlusOneFlag(nArg == LuaEnumTeam.Blue and LuaEnumTeam.Blue or LuaEnumTeam.Red) --One side steals a flag
end

function MatchTracker:OnCTFFlagSocketed(nArg)
	self:HelperCTFMinusOneFlag(nArg == LuaEnumTeam.Blue and LuaEnumTeam.Blue or LuaEnumTeam.Red) --One side sockets a flag
end

function MatchTracker:HelperCTFPlusOneFlag(nArg)
	local strWindowName = ktRavelIdToCTFWindowName[nArg]
	if strWindowName then
		local nAmount = self.tWndRefs.wndMatchTracker:FindChild(strWindowName):GetData() + 1
		self.tWndRefs.wndMatchTracker:FindChild(strWindowName):SetData(nAmount)
	end
	self:ShowAppropriateMessages()
end

function MatchTracker:HelperCTFMinusOneFlag(nArg)
	local strWindowName = ktRavelIdToCTFWindowName[nArg]
	if strWindowName then
		local nAmount = math.max(0, self.tWndRefs.wndMatchTracker:FindChild(strWindowName):GetData() - 1)
		self.tWndRefs.wndMatchTracker:FindChild(strWindowName):SetData(nAmount)
	end
	self:ShowAppropriateMessages()
end

function MatchTracker:ShowAppropriateMessages()
	local bShowRed = self.tWndRefs.wndMatchTracker:FindChild("CTFRedHaveFlag"):GetData() > 0
	local bShowBlue = self.tWndRefs.wndMatchTracker:FindChild("CTFBlueHaveFlag"):GetData() > 0
	local bShowStolen = self.tWndRefs.wndMatchTracker:FindChild("CTFStolenFlag"):GetData() > 0
	local bShowNeutral = self.tWndRefs.wndMatchTracker:FindChild("CTFNeutralFlag"):GetData() > 0
	
	self.tWndRefs.wndMatchTracker:FindChild("CTFRedHaveFlag"):Show(bShowRed )
	self.tWndRefs.wndMatchTracker:FindChild("CTFBlueHaveFlag"):Show(bShowBlue)
	self.tWndRefs.wndMatchTracker:FindChild("CTFStolenFlag"):Show(bShowStolen)
	self.tWndRefs.wndMatchTracker:FindChild("CTFNeutralFlag"):Show(bShowNeutral)
	self.tWndRefs.wndMatchTracker:FindChild("CTFAlertContainer"):Show(bShowRed or bShowBlue or bShowStolen or bShowNeutral)
	self.tWndRefs.wndMatchTracker:FindChild("CTFAlertContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.Middle)
end

-----------------------------------------------------------------------------------------------
-- Death Match
-----------------------------------------------------------------------------------------------

function MatchTracker:DrawDeathmatchScreen()
	local tMatchState = MatchingGame:GetPVPMatchState()
	if not tMatchState or tMatchState.eRules ~= MatchingGame.Rules.DeathmatchPool then
		return
	end

	self:HelperClearMatchesExcept(PublicEvent.PublicEventType_PVP_Arena)
	local wndInfo = self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Arena]
	local eMyTeam = tMatchState.eMyTeam
	local nLivesTeam1 = tMatchState.tLivesRemaining.nTeam1
	local nLivesTeam2 = tMatchState.tLivesRemaining.nTeam2

	local strOldCount1 = wndInfo:FindChild("MyTeam"):GetText()
	local strOldCount2 = wndInfo:FindChild("OtherTeam"):GetText()

	if eMyTeam == MatchingGame.Team.Team1 then
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

	self:HelperClearMatchesExcept(PublicEvent.PublicEventType_PVP_Battleground_Vortex)
	local wndInfo = self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_Vortex]
	wndInfo:SetData(peMatch)

	local eTeam = MatchingGame.GetPVPMatchState().eMyTeam
	local bIsBlue = eTeam == LuaEnumTeam.Blue
	for idObjective, peoCurrent in pairs(peMatch:GetObjectives()) do
		local wndToUse = wndInfo:FindChild("CTFLeftFrame")
		
		if peoCurrent:GetTeam() ~= peMatch:GetJoinedTeam() then
			wndToUse = wndInfo:FindChild("CTFRightFrame")
		end

		for idx = 1, peoCurrent:GetRequiredCount() do
			local wndFlag = wndToUse:FindChild("FlagIcon" .. idx)
			
			if wndFlag and idx > peoCurrent:GetCount() then
				wndFlag:SetBGColor(ApolloColor.new("ff444444"))
			elseif wndFlag then
				wndFlag:SetBGColor(ApolloColor.new("ffffffff"))
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Hold The Line
-----------------------------------------------------------------------------------------------
function MatchTracker:HideHoldLineScreen()
	self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine]:Show(false)
	if self.wndHoldLineFloater and self.wndHoldLineFloater:IsShown() then
		self.wndHoldLineFloater:Destroy()
		self.wndHoldLineFloater = nil
	end
end

function MatchTracker:DrawHoldLineScreen(peMatch)
	if not peMatch then return end

	if not self.wndHoldLineFloater or not self.wndHoldLineFloater:IsValid() then
		self.wndHoldLineFloater = Apollo.LoadForm(self.xmlDoc, "HoldTheLinePvPForm", nil, self)
		
		if self.locSavedWindowLoc then
			self.wndHoldLineFloater:MoveToLocation(self.locSavedWindowLoc)
		end
	end

	self:HelperClearMatchesExcept(PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine)
	local wndDatachron = self.tWndRefs.tMatchWnd[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine]
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
		
		local bBlueIsAttacking = false;
		local bIsBlue = MatchingGame.GetPVPMatchState().eMyTeam == LuaEnumTeam.Blue
		local bMyTeam = peoCurrent:GetTeam() == peMatch:GetJoinedTeam()
		if (bMyTeam and bIsBlue) or (not bMyTeam and not bIsBlue)  then
			bBlueIsAttacking = true;
		end
		
		--setup textures
		if nCurrValue <= 0 or nCurrValue == nil or nCurrValue > 99 or nLastValue <= 0 then
			if bBlueIsAttacking then
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
				
				if bIsBlue then
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
				
				if bIsBlue then
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

	local bAttacking = peoScriptCurrent:GetTeam() == peMatch:GetJoinedTeam()
	local wndHoldLineTitle = wndDatachron:FindChild("HoldLineTitle")
	wndHoldLineTitle:SetText(bAttacking and Apollo.GetString("MatchTracker_YouAreAttacking") or Apollo.GetString("MatchTracker_YouAreDefending"))
	wndHoldLineTitle:SetTextColor(bAttacking and kcrAttack or kcrDefend)
	

	for idx, tData in pairs({ktHoldLinePoint1, ktHoldLinePoint2, ktHoldLinePoint3}) do
		wndDatachron:FindChild("HoldLineIcon" .. idx):SetSprite(tData[nCount][1])
		wndDatachron:FindChild("HoldLineText" .. idx):SetText(tData[nCount][2])
		wndDatachron:FindChild("HoldLineText" .. idx):SetTextColor(tData[nCount][3])
	end
	
	nTotalTime = peoScriptCurrent:GetTotalTime() / 1000;
	self.tWndRefs.wndMatchTracker:FindChild("TimerLabel"):SetText(self:HelperTimeString((peoScriptCurrent:GetTotalTime() - peoScriptCurrent:GetElapsedTime()) / 1000))
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
	if self.peMatch ~= nil then
		self.nHTLCaptureMod = 0
		self:DrawHoldLineScreen(self.peMatch)
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function MatchTracker:OnPublicEventEnd(peEvent, eReason, tStats)
	if (eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteSuccess or eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteFailure)
	and ktPvPEventTypes[peEvent:GetEventType()] then
		self.tZombieEvent =
		{
			["peEvent"] = peEvent, 
			["eReason"] = eReason, 
			["tStats"] = tStats
		}
	end
end

function MatchTracker:OnViewEventStatsBtn(wndHandler, wndControl) -- ViewEventStatsBtn
	local peDisplay = nil
	local tDisplayedStats = nil
	if self.tZombieEvent then
		if ktPvPEventTypes[self.tZombieEvent.peEvent:GetEventType()] then
			peDisplay = self.tZombieEvent.peEvent
			tDisplayedStats = self.tZombieEvent.tStats
		end
		
	else		
		for idx, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
			if not peDisplay and peCurrent:HasLiveStats() then
				if ktPvPEventTypes[peCurrent:GetEventType()] then
					peDisplay = peCurrent
					tDisplayedStats = peCurrent:GetLiveStats()
				end
			end
		end
	end
	
	if peDisplay and tDisplayedStats then
		Event_FireGenericEvent("GenericEvent_OpenEventStats", peDisplay, peDisplay:GetMyStats(), tDisplayedStats.arTeamStats, tDisplayedStats.arParticipantStats)
	end
end

function MatchTracker:HelperClearMatchesExcept(nShow) -- hides all other window types
	for idx, wnd in pairs(self.tWndRefs.tMatchWnd) do
		wnd:Show(false)
	end

	if nShow ~= nil then
		self.tWndRefs.tMatchWnd[nShow]:Show(true)
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