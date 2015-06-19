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

local PathExplorerMissions = {}

function PathExplorerMissions:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function PathExplorerMissions:Init()
	Apollo.RegisterAddon(self)
end

function PathExplorerMissions:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathExplorerMissions.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PathExplorerMissions:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterLoaded", self)

	local unitPlayer = GameLib:GetPlayerUnit()
	if unitPlayer and unitPlayer:GetPlayerPathType() == PlayerPathLib.PlayerPathType_Explorer then
		self:OnCharacterLoaded()
	end
end

function PathExplorerMissions:OnCharacterLoaded()
	local unitPlayer = GameLib:GetPlayerUnit()
	if unitPlayer and unitPlayer:GetPlayerPathType() == PlayerPathLib.PlayerPathType_Explorer then
		Apollo.RegisterEventHandler("LoadExplorerMission", "LoadFromList", self)

		Apollo.RegisterEventHandler("ChangeWorld", 								"HelperResetUI", self)
		Apollo.RegisterEventHandler("PlayerResurrected", 						"HelperResetUI", self)
		Apollo.RegisterEventHandler("ShowResurrectDialog", 						"HelperResetUI", self)
		Apollo.RegisterEventHandler("PlayerPathExplorerPowerMapFailed", 		"OnExplorerPowerMapFailed", self)
		Apollo.RegisterEventHandler("PlayerPathExplorerPowerMapExited", 		"OnExplorerPowerMapExited", self)
		Apollo.RegisterEventHandler("PlayerPathExplorerPowerMapStarted", 		"OnExplorerPowerMapStarted", self)
		Apollo.RegisterEventHandler("PlayerPathExplorerPowerMapWaiting", 		"OnExplorerPowerMapWaiting", self)
		Apollo.RegisterEventHandler("PlayerPathExplorerScavengerHuntStarted", 	"DisplayExplorerHuntNotice", self)
		Apollo.RegisterEventHandler("UnitTextBubbleCreate",						"OnTextBubbleToggled", self)
		Apollo.RegisterEventHandler("UnitTextBubblesDestroyed",					"OnTextBubbleToggled", self)
		Apollo.RegisterTimerHandler("PowerMapExactlyOneSecond", 				"OnPowerMapExactlyOneSecond", self) -- Hacky: This updates self.nPowerMapDespawnTimer
		Apollo.RegisterTimerHandler("MissionsUpdateTimer", 						"OnMissionsUpdateTimer", self)
		Apollo.CreateTimer("MissionsUpdateTimer", 0.05, true)

		-- BUG: These flash on the screen for whatever reason if loaded later
		self.wndExplorerHuntNotice = Apollo.LoadForm(self.xmlDoc, "ExplorerHuntNotice", self, self)
		self.wndExplorerHuntNotice:Show(false, true)

		self.wndPowerMapRangeFinder = Apollo.LoadForm(self.xmlDoc, "PowerMapRangeFinder", "InWorldHudStratum", self)
		self.wndPowerMapRangeFinder:Show(false, true)

		self.nPowerMapDespawnTimer = -1
		self.bTextBubbleShown = false
		self.idMissionUnit = nil
	end
end

function PathExplorerMissions:LoadFromList(pmMission)
	if self.wndMain then
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PathExplorerMissionMain", nil, self)
	self.wndMain:SetData(pmMission)
	
	local strKeybind = GameLib.GetKeyBinding("PathAction")
	 
	if strKeybind ~= Apollo.GetString("InputKey_Unbound") then
		self.wndMain:FindChild("VistaPlaceButton"):SetText(Apollo.GetString("CRB_Place") .. "(" .. strKeybind .. ")") 
	else 
		self.wndMain:FindChild("VistaPlaceButton"):SetText(Apollo.GetString("CRB_Place"))
	end

	self.nLastNodeSoundValue = nil
end

-- Note: This gets called from a variety of sources
function PathExplorerMissions:HelperResetUI()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

-- Note: This gets called from a variety of sources
function PathExplorerMissions:DoAPathAction()
	PlayerPathLib.PathAction()
end

---------------------------------------------------------------------------------------------------
-- Main Update Timer
---------------------------------------------------------------------------------------------------

function PathExplorerMissions:OnMissionsUpdateTimer()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() or GameLib.GetPlayerUnit():IsDead() then
		return
	end

	local eType = self.wndMain:GetData():GetType()
	if eType == PathMission.PathMissionType_Explorer_Vista then
		self:OnVistaUpdateTimer()
	elseif eType == PathMission.PathMissionType_Explorer_Area then
		self:OnClaimUpdateTimer()
	elseif eType == PathMission.PathMissionType_Explorer_PowerMap then
		self:OnPowerMapUpdateTimer()
	elseif eType == PathMission.PathMissionType_Explorer_ScavengerHunt then
		self:OnScavengerUpdateTimer()
	end
end

---------------------------------------------------------------------------------------------------
-- Claim Territory
---------------------------------------------------------------------------------------------------

function PathExplorerMissions:OnClaimCloseClick()
	self:HelperResetUI()
end

function PathExplorerMissions:OnClaimLocateBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() and wndHandler:GetData():ShowHintArrow() then
		Sound.Play(Sound.PlayUIExplorerActivateGuideArrow)
	end
end

function PathExplorerMissions:OnClaimPlaceBtn(wndHandler, wndControl)
	Event_FireGenericEvent("PlayerPath_NotificationSent", 3, self.wndMain:GetData():GetName()) -- Send a completed mission event
	PlayerPathLib.PathAction()
	self:OnClaimCloseClick() -- Also close out the screen
end

function PathExplorerMissions:OnClaimHintBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		PlayerPathLib.ExplorerShowHint(wndHandler:GetData())
	end
end

function PathExplorerMissions:OnClaimUpdateTimer() -- TODO: Merge these into one timer
	if not self.wndMain or not self.wndMain:GetData() then return end

	local pmClaimMission = self.wndMain:GetData()
	local tNodeInfo = pmClaimMission:GetExplorerNodeInfo()

	self.wndMain:FindChild("ClaimContainer"):Show(true)
	self.wndMain:FindChild("ClaimHintButton"):SetData(pmClaimMission)
	self.wndMain:FindChild("ClaimLocateButton"):SetData(pmClaimMission)
	self.wndMain:FindChild("ClaimBar"):SetProgress(tNodeInfo.fRatio)
	self.wndMain:FindChild("ClaimHintButton"):Show(PlayerPathLib.CanExplorerShowHint(pmClaimMission))
	self.wndMain:FindChild("ClaimPlaceButton"):Enable(tNodeInfo.fRatio >= 1)
	self.wndMain:FindChild("ClaimLocateButton"):Enable(tNodeInfo.fRatio < 1)
	self.wndMain:FindChild("ClaimLocateButtonShade"):Show(tNodeInfo.fRatio >= 1)
	self.wndMain:FindChild("ClaimTitle"):SetText(String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), pmClaimMission:GetName(), pmClaimMission:GetNumCompleted(), pmClaimMission:GetNumNeeded()))
	self.wndMain:FindChild("ClaimArrangeHorz"):ArrangeChildrenHorz(1)
end

---------------------------------------------------------------------------------------------------
-- Vista
---------------------------------------------------------------------------------------------------

function PathExplorerMissions:OnVistaCloseClick()
	self:HelperResetUI()
end

function PathExplorerMissions:OnVistaLocateClick(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() and wndHandler:GetData():ShowHintArrow() then
		Sound.Play(Sound.PlayUIExplorerActivateGuideArrow)
	end
end

function PathExplorerMissions:OnVistaPlaceBtn(wndHandler, wndControl)
	PlayerPathLib.PathAction()
	self:OnVistaCloseClick() -- Also close out the screen
end

function PathExplorerMissions:OnVistaUpdateTimer()
	if not self.wndMain or not self.wndMain:GetData() then return end

	local pmVistaMission = self.wndMain:GetData()
	self.wndMain:FindChild("VistaContainer"):Show(true)
	self.wndMain:FindChild("VistaTitle"):SetText(pmVistaMission:GetName())

	local tNode = pmVistaMission:GetExplorerNodeInfo()
	local nNumCompleted = 0
	if tNode then
		for nCurrNumCompleted = 1, tNode.nMaxStates do -- node.state is the max number of states (assumed to be 4 for now)
			nNumCompleted = nNumCompleted + 1
		end

		self.wndMain:FindChild("VistaLocateButton"):SetData(pmVistaMission)
		self.wndMain:FindChild("VistaPlaceButton"):Enable(tNode.bCanPlace)
		self.wndMain:FindChild("VistaLocateButtonShade"):Show(tNode.bCanPlace)
		self.wndMain:FindChild("VistaLocateButton"):Enable(not tNode.bCanPlace)

		if not tNode.bIsCompleted then
			self:SetUplinkSound(tNode.nMaxStates)
		end
	end

	self.wndMain:FindChild("VistaUplinkNode"):FindChild("Bucket_1"):Show(nNumCompleted >= 1)
	self.wndMain:FindChild("VistaUplinkNode"):FindChild("Bucket_2"):Show(nNumCompleted >= 2)
	self.wndMain:FindChild("VistaUplinkNode"):FindChild("Bucket_3"):Show(nNumCompleted >= 3)
	self.wndMain:FindChild("VistaUplinkNode"):FindChild("Bucket_4"):Show(nNumCompleted >= 4)
end

function PathExplorerMissions:SetUplinkSound(nArg)
	if self.nLastNodeSoundValue == nArg then
		return
	end

	if nArg >= 0 or nArg <= 4 then
		self.nLastNodeSoundValue = nArg
	end

	if nArg == 0 then
		Sound.Play(Sound.PlayUIExplorerSignalDetection0)
	elseif nArg == 1 then
		Sound.Play(Sound.PlayUIExplorerSignalDetection1)
	elseif nArg == 2 then
		Sound.Play(Sound.PlayUIExplorerSignalDetection2)
	elseif nArg == 3 then
		Sound.Play(Sound.PlayUIExplorerSignalDetection3)
	elseif nArg == 4 then
		Sound.Play(Sound.PlayUIExplorerSignalDetection4)
	end
end

---------------------------------------------------------------------------------------------------
-- Scavenger Initial Clue Display
---------------------------------------------------------------------------------------------------

function PathExplorerMissions:OnHuntCloseBtn()
	self.wndExplorerHuntNotice:Show(false)
end

function PathExplorerMissions:DisplayExplorerHuntNotice(pmMission)
    if pmMission:GetNumNeeded() == 0 then return end

    local unitCreature = pmMission:GetExplorerHuntStartCreature()
	self.wndExplorerHuntNotice:Show(true)
	self.wndExplorerHuntNotice:SetData(pmMission)
	self.wndExplorerHuntNotice:FindChild("HuntCloseBtn"):SetData(0)
	self.wndExplorerHuntNotice:FindChild("HuntHeader"):SetText(Creature_GetName(unitCreature))
	self.wndExplorerHuntNotice:FindChild("HuntDescription"):SetText(pmMission:GetExplorerHuntStartText())
end

-- The Next Button also routes here
function PathExplorerMissions:PlayerPathExplorerHuntNoticeUpdate()
	-- GOTCHA: We need to +1 as C++ indexes at 0 while Lua indexes at 1
	local pmMission = self.wndExplorerHuntNotice:GetData()
	local nMaxNumClue = pmMission:GetNumNeeded()
	local nCurrentClue = self.wndExplorerHuntNotice:FindChild("HuntCloseBtn"):GetData()

	if nCurrentClue + 1 == nMaxNumClue then
		self.wndExplorerHuntNotice:FindChild("HuntNextBtn"):SetText(Apollo.GetString("CRB_Close"))
	else
		self.wndExplorerHuntNotice:FindChild("HuntNextBtn"):SetText(Apollo.GetString("ExplorerMissions_NextClue"))
	end

	if nCurrentClue >= nMaxNumClue then
		self.wndExplorerHuntNotice:Show(false)
	else
		self.wndExplorerHuntNotice:FindChild("HuntCloseBtn"):SetData(nCurrentClue + 1)
		self.wndExplorerHuntNotice:FindChild("HuntDescription"):SetText(String_GetWeaselString(Apollo.GetString("ExplorerMissions_ClueDescription"), nCurrentClue + 1, nMaxNumClue, pmMission:GetExplorerClueString(nCurrentClue)))
	end
end

---------------------------------------------------------------------------------------------------
-- Scavenger Hunt
---------------------------------------------------------------------------------------------------

function PathExplorerMissions:OnScavengerCloseClick()
	self:HelperResetUI()
end

function PathExplorerMissions:OnScavengerClueItemClick(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler:GetData() then
		return
	end
	local nClue = wndControl:GetData()
	local pmMission = self.wndMain:GetData()
	pmMission:ShowExplorerClueHintArrow(nClue)
end

function PathExplorerMissions:OnScavengerUpdateTimer()
	if not self.wndMain or not self.wndMain:GetData() then
		return
	end

	local pmMission = self.wndMain:GetData()
	local wndScav = self.wndMain:FindChild("ScavengerContainer")
	wndScav:Show(true)

	-- Just exit if we are finished
	if pmMission:GetNumCompleted() == pmMission:GetNumNeeded() then
		self:OnScavengerCloseClick()
		return
	end

	-- Clue List
	local nHighestRatio = 0
	local bEnableDigBtn = false
	local nVScrollPos = wndScav:FindChild("ScavClueContainer"):GetVScrollPos()

	wndScav:FindChild("ScavClueContainer"):DestroyChildren() -- TODO: Stop Destroying all children
	for idx = 0, (pmMission:GetNumNeeded() - 1) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "ScavengerClueItem", wndScav:FindChild("ScavClueContainer"), self)
		wndCurr:SetData(idx) -- Save the clue index for showing the hint arrow

		local nRatio = pmMission:GetExplorerClueRatio(idx)

		if nRatio > 0 then
			wndCurr:FindChild("ScavengerClueItemBG"):SetSprite("CRB_Basekit:kitBtn_List_HoloFlyby")
			if nRatio > nHighestRatio then
				nHighestRatio = nRatio
			end
			if pmMission:GetExplorerClueType(idx) == PathMission.ExplorerScavengerClueType_Dig then
				bEnableDigBtn = true
			end
		end

		wndCurr:FindChild("ScavengerClueCheck"):Show(pmMission:GetExplorerClueStatus(idx))
		wndCurr:FindChild("ScavengerClueCheckBack"):Show(not pmMission:GetExplorerClueStatus(idx))

		-- Resize Text
		wndCurr:FindChild("ScavengerClueName"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">%s</P>", pmMission:GetExplorerClueString(idx)))
		wndCurr:FindChild("ScavengerClueName"):SetHeightToContentHeight()
		local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
		local nLeft2, nTop2, nRight2, nBottom2 = wndCurr:FindChild("ScavengerClueName"):GetAnchorOffsets()
		if nBottom2 > nBottom then
			wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nBottom2 + 8)
		end

		wndCurr:FindChild("ScavengerClueItemBG"):ArrangeChildrenHorz(0)
	end
	wndScav:FindChild("ScavClueContainer"):ArrangeChildrenVert(0)
	wndScav:FindChild("ScavClueContainer"):SetVScrollPos(nVScrollPos)

	-- Bucket
	wndScav:FindChild("ScavDigButtonContainer"):Show(bEnableDigBtn)
--[[	wndScav:FindChild("ScavBucketContainer"):FindChild("Bucket_1"):Show(nHighestRatio > 0)
	wndScav:FindChild("ScavBucketContainer"):FindChild("Bucket_2"):Show(nHighestRatio > 0.3)
	wndScav:FindChild("ScavBucketContainer"):FindChild("Bucket_3"):Show(nHighestRatio > 0.6)
	wndScav:FindChild("ScavBucketContainer"):FindChild("Bucket_4"):Show(nHighestRatio > 0.9)--]]

	-- Meter
	local wndMeter
	if not bEnableDigBtn then
		wndMeter = wndScav:FindChild("ScavProximityMeterLong")
		wndScav:FindChild("ScavProximityMeterShort"):Show(false)
	else
		wndMeter = wndScav:FindChild("ScavProximityMeterShort")
		wndScav:FindChild("ScavProximityMeterLong"):Show(false)
	end

	wndMeter:Show(true)
	wndScav:FindChild("ScavDigButtonContainer"):Show(bEnableDigBtn)
	wndMeter:FindChild("ProximityMeterFill"):SetMax(1)
	wndMeter:FindChild("ProximityMeterFill"):SetProgress(nHighestRatio)
	wndMeter:FindChild("CheckOverlay"):Show(nHighestRatio > .95)
	wndMeter:FindChild("CheckBase"):Show(nHighestRatio <= .95)
end

---------------------------------------------------------------------------------------------------
-- Power Map
---------------------------------------------------------------------------------------------------


function PathExplorerMissions:OnPowerMapCloseClick()
	self.wndPowerMapRangeFinder:Show(false)
	self:HelperResetUI()
end

function PathExplorerMissions:OnExplorerPowerMapStarted(mission, unitTarget)
	self.wndPowerMapRangeFinder:SetData(unitTarget)
	self.bTextBubbleShown = unitTarget:HasTextBubble()
end

function PathExplorerMissions:OnExplorerPowerMapExited(pmMission)
	-- This is if you leave the starting area with the screen up
	self:OnPowerMapCloseClick()
end

function PathExplorerMissions:OnPowerMapUpdateTimer()
	if not self.wndMain or not self.wndMain:GetData() then
		return
	end

	local pmPowerMapMission = self.wndMain:GetData()
	self.wndMain:FindChild("PowerMapContainer"):Show(true)

	-- Early exit if we are done (since there's no win event)
	if pmPowerMapMission:IsComplete() then
		self:OnPowerMapCloseClick()
		return
	end

	local bPowerMapReadyState = pmPowerMapMission:IsExplorerPowerMapReady()
	self.wndMain:FindChild("PowerMapStartBtn"):Show(bPowerMapReadyState)
	self.wndMain:FindChild("PowerMapReadyMsg"):Show(bPowerMapReadyState)
	self.wndMain:FindChild("PowerMapActiveContainer"):Show(not bPowerMapReadyState)

	if bPowerMapReadyState then
		local strReady = pmPowerMapMission:GetExplorerPowerMapReadyText()
		self.wndMain:FindChild("PowerMapReadyMsg"):SetText(strReady)
		return
	end

	local tPowerMap = pmPowerMapMission:GetExplorerPowerMapInfo()
	if not tPowerMap then
		return
	end

	local wndPowerMapContainer = self.wndMain:FindChild("PowerMapActiveContainer")

	-- Completion Counting, if necessary
	if tPowerMap.nNeeded > 0 then
		wndPowerMapContainer:FindChild("ProgressText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), tPowerMap.nCompleted, tPowerMap.nNeeded))
	end
	wndPowerMapContainer:FindChild("PowerMapProgressC"):Show(tPowerMap.nNeeded > 0)

	-- Wait despawn timer, if necessary
	if tPowerMap.bIsWaiting then
		wndPowerMapContainer:FindChild("DespawnText"):SetAML("<P Align=\"Center\">"..self:CalculateMLTimeText(self.nPowerMapDespawnTimer).."</P>")
		wndPowerMapContainer:FindChild("PowerMapProgressFlash"):Show(tPowerMap.nNeeded ~= tPowerMap.nCompleted and tPowerMap.nNeeded > 0)
		wndPowerMapContainer:SetSprite("PlayerPathContent_TEMP:spr_PathExpPowerMapRedBG")
	else
		wndPowerMapContainer:SetSprite("")
		wndPowerMapContainer:FindChild("DespawnText"):SetAML("")
	end
	wndPowerMapContainer:FindChild("PowerMapDespawnC"):Show(tPowerMap.bIsWaiting)
	wndPowerMapContainer:FindChild("PowerMapSignalC"):Show(not tPowerMap.bIsWaiting)


	-- Range Text and Range Finder on Target
	self:PositionPowerMapRangeFinder(self.wndPowerMapRangeFinder, self.wndPowerMapRangeFinder:GetData(), tPowerMap.bIsWaiting, tPowerMap.fRatio)

	--wndPowerMapContainer:ArrangeChildrenVert(1)
end

function PathExplorerMissions:PositionPowerMapRangeFinder(wndPowerMapRangeFinder, unitTarget, bIsWaiting, nRatio)
	if not unitTarget or not unitTarget:GetPosition() then
		return
	end
	wndPowerMapRangeFinder:Show(not self.bTextBubbleShown)
	wndPowerMapRangeFinder:SetUnit(unitTarget, 1) -- TODO 1 is EModelAttachment.ModelAttachment_NAME

	-- Range to target
	posTarget = unitTarget:GetPosition()
	posPlayer = GameLib.GetPlayerUnit():GetPosition()
	local nDistance = math.floor(math.sqrt(math.pow((posTarget.x - posPlayer.x), 2) + math.pow((posTarget.y - posPlayer.y), 2) + math.pow((posTarget.z - posPlayer.z), 2)))
	wndPowerMapRangeFinder:FindChild("RangeFinderText"):SetText(string.format("%s m", nDistance))
	self.wndMain:FindChild("PowerMapContainer"):FindChild("PowerMapRangeText"):SetText(String_GetWeaselString(Apollo.GetString("ExplorerMissions_DistanceNumber"), nDistance))

	-- Color
	local nRatioColor = CColor.new(0, 1, 0, 1)
	local nRatioSprite = "CRB_NameplateSprites:sprNp_HealthBarFriendly"
	if nRatio and nRatio > 0.66 then
		nRatioColor = CColor.new(1, 0, 0, 1)
		nRatioSprite = "CRB_NameplateSprites:sprNp_HealthBarHostile"
	elseif nRatio and nRatio > 0.33 then
		nRatioColor = CColor.new(248/255, 185/255, 54/255, 1)
		nRatioSprite = "CRB_NameplateSprites:sprNp_HealthBarNeutral"
	end
	wndPowerMapRangeFinder:FindChild("RangeFinderText"):SetTextColor(nRatioColor)
	self.wndMain:FindChild("PowerMapContainer"):FindChild("PowerMapRangeText"):SetTextColor(nRatioColor)

	-- Progress Bar
	wndPowerMapRangeFinder:FindChild("RangeFinderProgress"):Show(not bIsWaiting)
	wndPowerMapRangeFinder:FindChild("RangeFinderProgress"):SetProgress(nRatio)
	wndPowerMapRangeFinder:FindChild("RangeFinderProgress"):SetFullSprite(nRatioSprite)

	-- Datachron Progress Bar
	if not bIsWaiting then
		self.wndMain:FindChild("PowerMapContainer"):FindChild("DistanceProgressBar"):SetProgress(nRatio)
		self.wndMain:FindChild("PowerMapContainer"):FindChild("DistanceProgressBar"):SetFullSprite(nRatioSprite)
	end

	-- Despawn Warning
	wndPowerMapRangeFinder:FindChild("RangeFinderDespawnWarning"):Show(bIsWaiting)
end

function PathExplorerMissions:OnExplorerPowerMapWaiting(pmMission, nVictoryDelay)
	Apollo.CreateTimer("PowerMapExactlyOneSecond", 1, true)
	Apollo.StartTimer("PowerMapExactlyOneSecond")
	self.nPowerMapDespawnTimer = nVictoryDelay
end

function PathExplorerMissions:OnPowerMapExactlyOneSecond()
	self.nPowerMapDespawnTimer = self.nPowerMapDespawnTimer - 1000
	if self.nPowerMapDespawnTimer <= 0 then
		Apollo.StopTimer("PowerMapExactlyOneSecond")
	end
end

function PathExplorerMissions:OnExplorerPowerMapFailed(mission)
	if not self.wndMain or not self.wndMain:IsValid() then return end
	Event_FireGenericEvent("PlayerPath_NotificationSent", 4, self.wndMain:GetData():GetName()) -- Send a failed mission event
	self.wndPowerMapRangeFinder:Show(false)
	self:HelperResetUI()
end

function PathExplorerMissions:OnTextBubbleToggled(unitSpeaking, strText)
	if (self.wndPowerMapRangeFinder:GetData() and self.wndPowerMapRangeFinder:GetData() == unitSpeaking) or
		(self.idMissionUnit and self.idMissionUnit == unitSpeaking:GetId()) then

		if strText and strText ~= "" then
			self.bTextBubbleShown = true
		else
			self.bTextBubbleShown = false
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function PathExplorerMissions:CalculateMLTimeText(nMilliseconds)
	if nMilliseconds < 0 then
		return ""
	end

	local nInSeconds = math.floor(nMilliseconds / 1000)
	local strPrefix = ""
	local strTime = ""

	if nInSeconds < 60 then
		strPrefix = "00:" -- Will display as 00: + 59
		strTime = string.format("%02.f", nInSeconds)
	else
		local nMins = string.format("%02.f", math.floor(nInSeconds / 60))
		local nSecs = string.format("%02.f", math.floor(nInSeconds - (nMins * 60)))
		strTime = nMins .. ":" .. nSecs
	end

    return string.format("<T Align=\"Center\"><T Font=\"CRB_HeaderGigantic\" TextColor=\"aaaa0000\">%s</T><T Font=\"CRB_HeaderGigantic\" TextColor=\"eeee0000\">%s</T></T>", strPrefix, strTime)
end

function PathExplorerMissions:FactoryProduce(wndParent, strFormName, tObject)
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
local PathExplorerMissionsInst = PathExplorerMissions:new()
PathExplorerMissionsInst:Init()
