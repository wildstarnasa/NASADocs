-----------------------------------------------------------------------------------------------
-- Client Lua Script for PathSoldierMissions
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
require "SoldierEvent"

local PathSoldierMissions = {}

function PathSoldierMissions:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function PathSoldierMissions:Init()
	Apollo.RegisterAddon(self)
end

function PathSoldierMissions:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathSoldierMissions.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PathSoldierMissions:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("Datachron_LoadPathSoldierContent", 		"OnLoadFromDatachron", self)

	-- For quest hold outs, these are randomly listened to. TODO: investigate proper use of these events
	Apollo.RegisterEventHandler("Datachron_ToggleHoldoutContent", 			"OnLoadFromDatachron", self)
	Apollo.RegisterEventHandler("Datachron_LoadQuestHoldoutContent", 		"OnLoadFromDatachron", self)
end

function PathSoldierMissions:OnLoadFromDatachron()
	Apollo.RegisterEventHandler("LoadSoldierMission", "LoadFromList", self)

	Apollo.RegisterEventHandler("PlayerPathSoldierNewWhackAMoleBurrows", 	"OnPlayerPathSoldierNewWhackAMoleBurrows", self)
	Apollo.RegisterEventHandler("SoldierHoldoutStatus", 					"OnSoldierHoldoutStatusStart", self)
	Apollo.RegisterEventHandler("SoldierHoldoutNextWave", 					"OnSoldierHoldoutNextWave", self)
	Apollo.RegisterEventHandler("SoldierHoldoutDeath",						"OnSoldierHoldoutDeath", self)
	Apollo.RegisterEventHandler("SoldierHoldoutEnd", 						"OnExitSoldierMissionMain", self)
	Apollo.RegisterEventHandler("ChangeWorld", 								"OnExitSoldierMissionMain", self)

	Apollo.RegisterTimerHandler("SoldierHoldout_CleanWhackAMole",	"OnSoldierHoldout_CleanWhackAMole", self)
	Apollo.RegisterTimerHandler("IncomingWarning", 					"OnIncomingWarning", self)
	Apollo.RegisterTimerHandler("SoldierTimer", 					"OnSoldierTimer", self)
	Apollo.RegisterTimerHandler("DoAFlashTimer10", 					"DoAFlash", self)
	Apollo.RegisterTimerHandler("DoAFlashTimer6", 					"DoAFlash", self)
	Apollo.RegisterTimerHandler("DoAFlashTimer3", 					"DoAFlash", self)

	Apollo.CreateTimer("SoldierTimer", 0.4, true)
	Apollo.StartTimer("SoldierTimer")

	self.tWndWhackAMole = {}
	self.bFirstTowerDefenseLoad = true

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PathSoldierMissionMain", g_wndDatachron:FindChild("PathContainer"), self)

	local pepEpisode = PlayerPathLib.GetCurrentEpisode()
	if pepEpisode then
		local tFullMissionList = pepEpisode:GetMissions()
		for idx, pmCurrMission in pairs(tFullMissionList) do
			if pmCurrMission:GetMissionState() == PathMission.PathMissionState_Started then
				local seHoldout = pmCurrMission:GetSoldierHoldout()
				if seHoldout then
					self:OnSoldierHoldoutStatusStart(seHoldout)
				end
			end
		end
	end
end

function PathSoldierMissions:OnExitSoldierMissionMain()
	-- The event and close button route here. The fail message drawing is handled in PathSoldierMain.lua.
	if not self.wndMain then return end
	Event_FireGenericEvent("Datachron_SoldierMissionsClosed")
	self.wndMain:Show(false)
	self.wndMain:SetData(nil)
end

function PathSoldierMissions:LoadFromList(seArgEvent)
	-- TODO: Note we can technically have different missions going at once
	self.wndMain:SetData(seArgEvent)
	self.wndMain:Show(true)
	self.wndMain:ToFront()

	self.wndMain:FindChild("Timed"):Show(false)
	self.wndMain:FindChild("Defend"):Show(false)
	self.wndMain:FindChild("Assault"):Show(false)
	self.wndMain:FindChild("BossFrame"):Show(false)
	self.wndMain:FindChild("SolIncoming"):Show(false)
end

function PathSoldierMissions:OnSoldierHoldoutStatusStart(seArgEvent)
	self:LoadFromList(seArgEvent)
	-- One time messages, as long as it's not tower defense's building state
	if not (seArgEvent:GetType() == PathMission.PathSoldierEventType_TowerDefense and seArgEvent:GetState() == PathMission.PlayerPathSoldierEventMode_Setup) then
		self.wndMain:FindChild("SolIncoming"):Show(true)
		self.wndMain:FindChild("SolIncoming"):FindChild("IncomingText"):SetText(Apollo.GetString("CRB_Holdout_starting"))
		Apollo.CreateTimer("IncomingWarning", 2.5, false)
	end

	if seArgEvent:GetState() ~= PathMission.PlayerPathSoldierEventMode_Setup then
		local wndAssault = self.wndMain:FindChild("Assault")
		wndAssault:FindChild("TimerAndCountArrangeVert"):Show(true)
		wndAssault:FindChild("DeathNoticeContainer"):Show(false)
	end
end

---------------------------------------------------------------------------------------------------
-- Timer and Mission Drawing
---------------------------------------------------------------------------------------------------

function PathSoldierMissions:OnSoldierTimer()
	if not self.wndMain or not self.wndMain:GetData() then return end

	local seEvent = self.wndMain:GetData()
	local eType = seEvent:GetType()

	-- Route to appropriate draw method
	if eType == PathMission.PathSoldierEventType_Timed or eType == PathMission.PathSoldierEventType_WhackAMoleTimed then
		self:DrawMissionTimed(seEvent)

	elseif eType == PathMission.PathSoldierEventType_Holdout or eType == PathMission.PathSoldierEventType_WhackAMole then
		self:DrawMissionAssault(seEvent)

	elseif eType == PathMission.PathSoldierEventType_Defend or eType == PathMission.PathSoldierEventType_TimedDefend then
		self:DrawMissionDefense(seEvent)

	elseif eType == PathMission.PathSoldierEventType_StopTheThieves or eType == PathMission.PathSoldierEventType_StopTheThievesTimed then
		self:DrawMissionStopThieves(seEvent)

	elseif eType == PathMission.PathSoldierEventType_TowerDefense then
		if seEvent:GetState() == PathMission.PlayerPathSoldierEventMode_Setup then
			self:DrawMissionBuilding(seEvent)
		else
			self:DrawMissionTowerDefense(seEvent)
		end
	end
end

function PathSoldierMissions:DrawMissionTimed(seEvent)
	-- WhackAMoleTimed and StopThievesTimed also uses this method to set up, then overwrites afterwards
	local nElapsedTime = seEvent:GetMaxTime() - seEvent:GetElapsedTime()
	self.wndMain:FindChild("Timed"):Show(true)
	self.wndMain:FindChild("Timed"):FindChild("CountContainer"):Show(false)
	self.wndMain:FindChild("Timed"):FindChild("TimerText"):SetText(self:HelperCalcTime(nElapsedTime))
	self.wndMain:FindChild("Timed"):FindChild("TimedMeter"):SetProgress(nElapsedTime)
	self.wndMain:FindChild("Timed"):FindChild("TimedMeter"):SetMax(seEvent:GetMaxTime())
	self.wndMain:FindChild("Timed"):FindChild("TimerAndCountArrangeVert"):ArrangeChildrenVert(0)
end

function PathSoldierMissions:DrawMissionDefense(seEvent)
	local wndAssault = self.wndMain:FindChild("Assault")
	local wndDefend = self.wndMain:FindChild("Defend")
	local nElapsedTime = seEvent:GetMaxTime() - seEvent:GetElapsedTime()

	local wndDefendContainer = wndDefend:FindChild("DefendContainer")
	local tDefendContainerChildren = wndDefendContainer:GetChildren()
	local nOldDefendCount = #tDefendContainerChildren

	local nUnitCount = 0
	for idx, unit in pairs(seEvent:GetDefendUnits()) do
		local wndEntry = wndDefendContainer:FindChildByUserData(idx)
		if wndEntry == nil then
			wndEntry = Apollo.LoadForm(self.xmlDoc, "DefendEntry", wndDefendContainer, self)
			wndEntry:SetData(idx)
			wndDefendContainer:ArrangeChildrenVert(0)
		end

		local nCurrHealth = unit:GetHealth()
		local nMaxHealth = unit:GetMaxHealth()

		if nCurrHealth and nMaxHealth then
			wndEntry:FindChild("DefendHealth"):SetMax(nMaxHealth)
			wndEntry:FindChild("DefendHealth"):SetProgress(nCurrHealth)
		end

		nUnitCount = nUnitCount + 1
	end

	if nUnitCount < nOldDefendCount then
		for nOldIdx = nUnitCount, nOldDefendCount do
			local wndEntry = wndDefendContainer:FindChildByUserData(nOldIdx)
			if wndEntry then
				wndEntry:Destroy()
			end
		end
	end

	wndDefend:Show(true)

	-- Shared
	local eType = seEvent:GetType()
	local bValidTimeLeftTypes = eType == PathMission.PathSoldierEventType_Defend
	if bValidTimeLeftTypes and nCurrWave == nTotalWaves and nElapsedTime ~= 0 then
		wndDefend:FindChild("TimerLabel"):SetText(Apollo.GetString("SoldierMission_TimeLeft"))
		wndDefend:FindChild("TimerText"):SetText(self:HelperCalcTime(nElapsedTime))
	elseif nElapsedTime == 0 or seEvent:IsBoss() then
		wndDefend:FindChild("TimerLabel"):SetText("")
		wndDefend:FindChild("TimerText"):SetText("")
	else
		wndDefend:FindChild("TimerLabel"):SetText(Apollo.GetString("SoldierMission_NextWaveLabel"))
		wndDefend:FindChild("TimerText"):SetText(self:HelperCalcTime(nElapsedTime))
	end
	
	if eType == PathMission.PathSoldierEventType_TimedDefend then
		wndDefend:FindChild("WaveMeter"):Show(false)
		wndDefend:FindChild("ProgressFrame"):Show(false)
		wndDefend:FindChild("WavesElapsed"):SetText(String_GetWeaselString(Apollo.GetString("SoldierMission_DefendTarget"), seEvent:GetDefendUnits()[1]:GetName()))
		wndDefend:FindChild("TimerLabel"):SetText(Apollo.GetString("SoldierMission_DefendLabel"))
	else
		local nProgress = seEvent:GetState() == PathMission.PlayerPathSoldierEventMode_Active and seEvent:GetWavesReleased() or 0

		wndDefend:FindChild("WaveMeter"):Show(true)
		wndDefend:FindChild("ProgressFrame"):Show(true)
		wndDefend:FindChild("WaveMeter"):SetMax(seEvent:GetWaveCount())
		wndDefend:FindChild("WaveMeter"):SetProgress(nProgress)
		wndDefend:FindChild("WavesElapsed"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Waves_Released"), nProgress, seEvent:GetWaveCount()))
	end

	self.wndMain:FindChild("BossFrame"):Show(seEvent:IsBoss())
end

function PathSoldierMissions:DrawMissionAssault(seEvent)
	-- WhackAMole, StopThieves, and TowerDefense also uses this method to set up, then overwrites afterwards
	local wndAssault = self.wndMain:FindChild("Assault")
	local nElapsedTime = seEvent:GetMaxTime() - seEvent:GetElapsedTime()

	wndAssault:Show(true)
	wndAssault:FindChild("CountContainer"):Show(false)
	wndAssault:FindChild("TimerAndCountArrangeVert"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("TowerDefenseContainer"):Show(false)

	-- Shared
	local eType = seEvent:GetType()
	local nTotalWaves = seEvent:GetWaveCount()
	local nCurrWave = seEvent:GetState() == PathMission.PlayerPathSoldierEventMode_Active and seEvent:GetWavesReleased() or 0
	wndAssault:FindChild("WaveMeter"):SetMax(nTotalWaves)
	wndAssault:FindChild("WaveMeter"):SetProgress(nCurrWave)
	wndAssault:FindChild("WavesElapsed"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Waves_Released"), nCurrWave, nTotalWaves))

	local bValidTimeLeftTypes = eType == PathMission.PathSoldierEventType_Holdout or eType == PathMission.PathSoldierEventType_WhackAMole
	if bValidTimeLeftTypes and nCurrWave == nTotalWaves and nElapsedTime ~= 0 then
		wndAssault:FindChild("TimerLabel"):SetText(Apollo.GetString("SoldierMission_TimeLeft"))
		wndAssault:FindChild("TimerText"):SetText(self:HelperCalcTime(nElapsedTime))
	elseif nElapsedTime == 0 or seEvent:IsBoss() then
		wndAssault:FindChild("TimerLabel"):SetText("")
		wndAssault:FindChild("TimerText"):SetText("")
	else
		wndAssault:FindChild("TimerLabel"):SetText(Apollo.GetString("SoldierMission_NextWaveLabel"))
		wndAssault:FindChild("TimerText"):SetText(self:HelperCalcTime(nElapsedTime))
	end

	self.wndMain:FindChild("BossFrame"):Show(seEvent:IsBoss())
end

function PathSoldierMissions:DrawMissionTowerDefense(seEvent)
	self:DrawMissionAssault(seEvent)

	-- TD Specific
	self.bFirstTowerDefenseLoad = true -- Reset the timers for flash
	self.wndMain:FindChild("TowerDefenseContainer"):Show(true)
	self.wndMain:FindChild("TowerDefenseText"):SetText(string.format(
		"<T Font=\"CRB_InterfaceMedium\" TextColor=\"ffcdba96\" Align=\"Center\">%s <T Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s/%s - %s/%s</T><T>",
		Apollo.GetString("SoldierMission_DefenseRemaining"), seEvent:GetDefendHealth(), seEvent:GetMaxDefendHealth(), seEvent:GetAuxiliaryHealth(), seEvent:GetMaxAuxiliaryHealth()))
end

function PathSoldierMissions:DrawMissionStopThieves(seEvent)
	local wndToUse = nil
	if seEvent:GetType() == PathMission.PathSoldierEventType_StopTheThieves then
		self:DrawMissionAssault(seEvent)
		wndToUse = self.wndMain:FindChild("Assault")
	elseif seEvent:GetType() == PathMission.PathSoldierEventType_StopTheThievesTimed then
		self:DrawMissionTimed(seEvent)
		wndToUse = self.wndMain:FindChild("Timed")
	end

	-- Stop Thieves Specific
	if seEvent:GetMaxTime() - seEvent:GetElapsedTime() ~= 0 then
		local nInTransit = 0
		local tEscapingUnits = seEvent:GetEscapingUnits()
		if tEscapingUnits then
			for _, unitCurr in pairs(tEscapingUnits) do
				nInTransit = nInTransit + 1
			end
		end

		wndToUse:FindChild("CountContainer"):Show(true)
		wndToUse:FindChild("CountText"):SetText(nInTransit + seEvent:GetAuxiliaryHealth() .. "/" .. seEvent:GetMaxAuxiliaryHealth())
		wndToUse:FindChild("TimerAndCountArrangeVert"):ArrangeChildrenVert(0)
	end
end

function PathSoldierMissions:DrawMissionBuilding(seEvent)
	local nTime = self:HelperCalcTime(seEvent:GetMaxTime() - seEvent:GetElapsedTime())
	self.wndMain:FindChild("SolIncoming"):Show(true)
	self.wndMain:FindChild("SolIncoming"):FindChild("IncomingText"):SetText(String_GetWeaselString(Apollo.GetString("SoldierMission_BuildTime"), nTime))

	-- This stays on screen until we clear it
	if self.bFirstTowerDefenseLoad then
		self.bFirstTowerDefenseLoad = false
		local nMaxTime = seEvent:GetMaxTime()
		Apollo.CreateTimer("DoAFlashTimer3", nMaxTime - 3.0, false)
		Apollo.CreateTimer("DoAFlashTimer6", nMaxTime - 6.0, false)
		Apollo.CreateTimer("DoAFlashTimer10", nMaxTime - 10.0, false)
	end
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------

function PathSoldierMissions:OnSoldierHoldoutNextWave(seArgEvent)
	if not self.wndMain then return end

	if not self.wndMain:GetData() then
		self.wndMain:SetData(seArgEvent)
	end

	local bIsBoss = seArgEvent:IsBoss()
	local eEventType = seArgEvent:GetType()

	-- Boss Drawing
	self.wndMain:FindChild("BossFrame"):Show(bIsBoss)
	if bIsBoss then
		Sound.Play(Sound.PlayUISoldierBossReleased)
	else
		Sound.Play(Sound.PlayUISoldierWaveReleased)
	end

	self:DoAFlash()
	self.wndMain:FindChild("SolIncoming"):Show(true)
	self.wndMain:FindChild("SolIncoming"):FindChild("IncomingText"):SetText(Apollo.GetString("CRB_Incoming!"))
	Apollo.CreateTimer("IncomingWarning", 2.0, false)
	Event_FireGenericEvent("GenericEvent_RestoreDatachron")
end

function PathSoldierMissions:OnIncomingWarning()
	if not self.wndMain then return end

	self:DoAFlash()
	self.wndMain:FindChild("SolIncoming"):Show(false)
	Sound.Play(Sound.PlayUISoldierHoldoutScreenFlashes)
end

function PathSoldierMissions:OnSoldierHoldoutDeath(seArgEvent)
	local wndAssault = self.wndMain:FindChild("Assault")
	wndAssault:FindChild("TimerAndCountArrangeVert"):Show(false)
	wndAssault:FindChild("DeathNoticeContainer"):Show(true)
end

function PathSoldierMissions:OnPlayerPathSoldierNewWhackAMoleBurrows(nDelayUntilPop, tUnits) -- This can happen more than once
	local bAddedSomething = false
	local unitPlayer = GameLib.GetPlayerUnit()
	for idx, unitCurr in pairs(tUnits or {}) do
		if unitCurr ~= unitPlayer and not self.tWndWhackAMole[unitCurr:GetId()] then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "WhackAMoleForm", "InWorldHudStratum", self)
			wndCurr:FindChild("WhackAMoleProgress"):SetMax(100)
			wndCurr:FindChild("WhackAMoleProgress"):SetProgress(100, 100 / nDelayUntilPop)
			wndCurr:SetUnit(unitCurr, 1) -- TODO 1 is EModelAttachment.ModelAttachment_NAME
			self.tWndWhackAMole[unitCurr:GetId()] = wndCurr
			bAddedSomething = true
		end
	end

	if bAddedSomething then
		Apollo.RemoveEventHandler("UnitDestroyed", self)
		Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
	end

	Apollo.StopTimer("SoldierHoldout_CleanWhackAMole")
	Apollo.CreateTimer("SoldierHoldout_CleanWhackAMole", nDelayUntilPop, false)
	Apollo.StartTimer("SoldierHoldout_CleanWhackAMole")
end

function PathSoldierMissions:OnSoldierHoldout_CleanWhackAMole()
	for idx, wndCurr in pairs(self.tWndWhackAMole) do
		if wndCurr and wndCurr:IsValid() then
			wndCurr:Destroy()
			wndCurr = nil
		end
	end

	self.tWndWhackAMole = {}
	Apollo.RemoveEventHandler("UnitDestroyed", self)
	Apollo.StopTimer("SoldierHoldout_CleanWhackAMole")
end

function PathSoldierMissions:OnUnitDestroyed(unitArg) -- Just for soldier whack a mole missions
	for nUnitIdx, wndCurr in pairs(self.tWndWhackAMole or {}) do
		if wndCurr and wndCurr:IsValid() and nUnitIdx == unitArg:GetId() then
			wndCurr:Destroy()
			wndCurr = nil
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Helper Methods
---------------------------------------------------------------------------------------------------

function PathSoldierMissions:DoAFlash()
	Event_FireGenericEvent("Datachron_FlashIndicators")
	self.wndMain:FindChild("WaveFlash"):SetSprite("WhiteFlash")
end

function PathSoldierMissions:HelperCalcTime(nTime)
	local nInSeconds = nTime / 1000
	return string.format("%d:%02d", math.floor(nInSeconds / 60), math.floor(nInSeconds % 60))
end

local PathSoldierMissionsInst = PathSoldierMissions:new()
PathSoldierMissionsInst:Init()
olDepth="1" HideInEditor="1" NoClip="0">
                <Event Name="GenerateTooltip" Function="OnGenerateSpellTooltip"/>
            </Control>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="10" TAnchorPoint="0" TAnchorOffset="12" RAnchorPoint="0" RAnchorOffset="44" BAnchorPoint="0" BAnchorOffset="46" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="ListItemHintArrowArt" BGColor="ffffffff" TextColor="ffffffff" Picture="1" Sprite="ClientSprites:Icon_Mission_Explorer_ScavengerHunt" IgnoreMouse="1" NewControlDepth="2" TooltipColor="" Tooltip="" Visible="0">
                <Pixie LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" Sprite="" BGColor="ffffffff" TextColor="black" Rotation="0" Font="Default"/>
                <Pixie LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" Sprite="" BGColor="white" TextColor="black" Rotation="0" Font="Default"/>
            </Control>
            <Control Class="MLWindow" LAnchorPoint="0" LAnchorOffset="51" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-51" BAnchorPoint="0" BAnchorOffset="26" RelativeToClient="1" Font="CRB_InterfaceMedium_B" Text="" Template="Default" Name="ListItemName" BGColor="ffffffff" TextColor="UI_TextHoloTitle" DT_VCENTER="0" DT_WORDBREAK="1" TextId="Challenges_NoProgress" IgnoreMouse="1" TooltipColor="" DT_CENTER="0" Tooltip=""/>
            <Control Class="MLWindow" LAnchorPoint="0" LAnchorOffset="51" TAnchorPoint="1" TAnchorOffset="-28" RAnchorPoint="1" RAnchorOffset="-51" BAnchorPoint="1" BAnchorOffset="10" RelativeToClient="1" Font="CRB_InterfaceSmall" Text="" Template="Default" TooltipType="OnCursor" Name="ListItemSubtitle" BGColor="ffffffff" TextColor="UI_TextHoloBodyCyan" TooltipColor="" DT_VCENTER="0" TextId="Challenges_NoProgress" DT_CENTER="0" IgnoreMouse="1"/>
            <Control Class="Button" Base="Crafting_CircuitSprites:btnCircuit_Holo_RightArrow" Font="Thick" ButtonType="PushButton" RadioGroup="" LAnchorPoint="1" LAnchorOffset="-51" TAnchorPoint="0" TAnchorOffset="6" RAnchorPoint="1" RAnchorOffset="-3" BAnchorPoint="0" BAnchorOffset="52" DT_VCENTER="1" DT_CENTER="1" Name="ListItemSubscreenBtn" BGColor="ffffffff" TextColor="ffffffff" NormalTextColor="ffffffff" PressedTextColor="ffffffff" FlybyTextColor="ffffffff" PressedFly