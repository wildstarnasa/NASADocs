-----------------------------------------------------------------------------------------------
-- Client Lua Script for HUDAlerts
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Apollo"
require "CommunicatorLib"
require "DatacubeLib"
require "PathEpisode"
require "QuestLib"

local HUDAlerts = {}

function HUDAlerts:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function HUDAlerts:Init()
	Apollo.RegisterAddon(self)
end

function HUDAlerts:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("HUDAlerts.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function HUDAlerts:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	-- Loot Events
	Apollo.RegisterEventHandler("CanVacuumChange", 								"OnCanVacuumChanged", self)
	Apollo.RegisterEventHandler("UpdateInventory", 								"OnUpdateInventory", self)

	-- Durability Events
	Apollo.RegisterEventHandler("CharacterCreated", 							"ShowDurabilityAlert", self)
	Apollo.RegisterEventHandler("ItemDurabilityUpdate", 						"ShowDurabilityAlert", self)
	Apollo.RegisterTimerHandler("HUDAlerts_HideDurabilityTimer", 				"OnHUDAlerts_HideDurabilityTimer", self)

	-- Datacube Events
	Apollo.RegisterEventHandler("GenericEvent_Collections_StopDatacube", 		"OnStopPlayingDatacube", self)
	Apollo.RegisterEventHandler("DatacubePlaybackEnded", 						"OnStopPlayingDatacube", self)
	Apollo.RegisterEventHandler("DatacubeUpdated", 								"OnDatacubeUpdated", self)

	Apollo.RegisterTimerHandler("HUDAlerts_MaxPlayDatacubeTrackTime", 			"OnStopPlayingDatacube", self)
	Apollo.RegisterTimerHandler("HUDAlerts_PlayDatacubeTrack", 					"OnHUDAlerts_PlayDatacubeTrack", self)

	-- DatachronCall Events
	Apollo.RegisterEventHandler("DatachronCallIncoming", 						"OnDatachronCallIncoming", self)
	Apollo.RegisterEventHandler("DatachronCallCleared", 						"OnDatachronCallCleared", self)
	Apollo.RegisterEventHandler("DatachronCallMissed", 							"OnDatachronCallMissed", self)
	Apollo.RegisterTimerHandler("HUDAlerts_DatachronCallExpired", 				"OnHUDAlerts_DatachronCallExpired", self) -- Timer

	-- Challenge Events
	Apollo.RegisterEventHandler("ChallengeUnlocked", 							"OnChallengeUnlocked", self)
	Apollo.RegisterTimerHandler("HUDAlerts_ChallengeTimerExpired", 				"OnHUDAlerts_ChallengeTimerExpired", self) -- Timer

	-- Quest Events
	Apollo.RegisterEventHandler("QuestStateChanged", 							"RebuildQuestList", self)
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 						"RebuildQuestList", self)
	Apollo.RegisterEventHandler("Communicator_ShowQuestMsg",					"RebuildQuestList", self)

	-- Stun Events
	Apollo.RegisterEventHandler("ActivateCCStateStun", 							"OnActivateCCStateStun", self)
	Apollo.RegisterEventHandler("RemoveCCStateStun", 							"OnRemoveCCStateStun", self)

	-- Other Events
	Apollo.RegisterTimerHandler("HUDAlerts_DelayedInitialize", 					"OnHUDAlerts_DelayedInitialize", self) -- Timer for Quest and DatachronCall
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 					"OnTutorial_RequestUIAnchor", self)
	Apollo.CreateTimer("HUDAlerts_DelayedInitialize", 5, false)

	-- load our forms
	self.wndAlertContainer 		= Apollo.LoadForm(self.xmlDoc, "AlertContainer", "FixedHudStratum", self)
	self.wndLootAlert 			= self.wndAlertContainer:FindChild("LootAlert")
	self.wndCallAlert 			= self.wndAlertContainer:FindChild("CallAlert")
	self.wndChallengeAlert 		= self.wndAlertContainer:FindChild("ChallengeAlert")
	self.wndDatacubeAlert 		= self.wndAlertContainer:FindChild("DatacubeAlert")
	self.wndDurabilityAlert 	= self.wndAlertContainer:FindChild("DurabilityAlert")
	self.wndQuestCompleteAlert 	= self.wndAlertContainer:FindChild("QuestCompleteAlert")
	
	self.wndLootAlert:Show(false, true)
	self.wndCallAlert:Show(false, true)
	self.wndChallengeAlert:Show(false, true)
	self.wndDatacubeAlert:Show(false, true)
	self.wndDurabilityAlert:Show(false, true)
	self.wndQuestCompleteAlert:Show(false, true)

	self.wndHiddenBagWindow		= self.wndAlertContainer:FindChild("HiddenBagWindow")
	self.wndAlertContainer:FindChild("QuestCompleteMenuBtn"):AttachWindow(self.wndAlertContainer:FindChild("QuestMenuFrame"))

	-- Variables
	self.bHideDurabilityTimer = false
end

function HUDAlerts:OnHUDAlerts_DelayedInitialize() -- TODO HACK: This needs to dodge QuestLib not loading and the DatachronCallCleared GenericEvent
	self:OnCanVacuumChanged(GameLib.CanVacuum())
	self:ShowDurabilityAlert()
	self:RebuildQuestList()

	-- Check Missed Calls
	for idx, questCallback in ipairs(Quest:GetCallbackList(true) or {}) do
		if questCallback:GetState() == Quest.QuestState_Mentioned then
			self:OnDatachronCallMissed()
			break
		end
	end

	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnActivateCCStateStun()
	self.wndAlertContainer:Show(false)
end

function HUDAlerts:OnRemoveCCStateStun()
	self.wndAlertContainer:Show(true)
end

function HUDAlerts:OnHoverGlowMouseEnter(wndHandler, wndControl)
	if wndHandler:FindChild("AlertPopout") then
		wndHandler:FindChild("AlertPopout"):Show(true)
	end
	if wndHandler:FindChild("AlertItemHover") then
		wndHandler:FindChild("AlertItemHover"):Show(true)
	end
	if wndHandler:FindChild("AlertItemKeybind") then
		wndHandler:FindChild("AlertItemKeybind"):SetSprite("CRB_HUDAlerts:sprAlert_Square_Blue")
	end
	Event_FireGenericEvent("GenericEvent_HUDAlerts_ToggleInteractPopoutText", false)
end

function HUDAlerts:OnHoverGlowMouseExit(wndHandler, wndControl)
	if wndHandler:FindChild("AlertPopout") then
		wndHandler:FindChild("AlertPopout"):Show(false, true)
	end
	if wndHandler:FindChild("AlertItemHover") then
		wndHandler:FindChild("AlertItemHover"):Show(false, true)
	end
	if wndHandler:FindChild("AlertItemKeybind") then
		wndHandler:FindChild("AlertItemKeybind"):SetSprite("CRB_HUDAlerts:sprAlert_Square_Black")
	end

	local bNothingChecked = true
	for idx, wndCurr in pairs(self.wndAlertContainer:GetChildren()) do
		if wndCurr:FindChild("AlertItemHover") and wndCurr:FindChild("AlertItemHover"):IsShown() then
			bNothingChecked = false
			break
		end
	end
	Event_FireGenericEvent("GenericEvent_HUDAlerts_ToggleInteractPopoutText", bNothingChecked)
end

function HUDAlerts:ShowAndInitializeAlert(wndAlert)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
	wndAlert:Show(true)
	wndAlert:FindChild("AlertPopout"):Show(false, true)
	wndAlert:FindChild("AlertItemHover"):Show(false, true)
	wndAlert:FindChild("AlertItemKeybind"):SetSprite("sprAlert_Square_Black")
	wndAlert:FindChild("AlertItemTransition"):SetSprite("sprWinAnim_BirthSmallTemp")
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnUpdateInventory()
	if not self.wndLootAlert or not self.wndLootAlert:IsValid() then
		return
	end

	local bFullInventory = self.wndHiddenBagWindow:GetTotalEmptyBagSlots() == 0
	self.wndLootAlert:FindChild("LootFullBagIndicator"):Show(bFullInventory)
	self.wndLootAlert:FindChild("AlertPopout"):Show(bFullInventory or self.wndLootAlert:FindChild("AlertPopout"):IsShown())
	self.wndLootAlert:FindChild("AlertPopoutText"):SetText(bFullInventory and Apollo.GetString("HUDAlert_FullInventory") or Apollo.GetString("HUDAlert_VacuumLoot"))
end

function HUDAlerts:OnCanVacuumChanged(bCanVacuum)
	local strKeybind = GameLib.GetKeyBinding("VacuumLoot")
	self.wndLootAlert:FindChild("AlertItemKeybindText"):SetText(strKeybind)
	self.wndLootAlert:FindChild("AlertItemKeybind"):Show(strKeybind ~= Apollo.GetString("HUDAlert_Unbound"))

	if not self.wndLootAlert:IsShown() and bCanVacuum then
		self.wndLootAlert:Show(bCanVacuum, true)
		self.wndLootAlert:FindChild("AlertItemTransition"):SetSprite("sprAlert_SectionGlowRingFlash")
	else
		self.wndLootAlert:Show(bCanVacuum)

	end

	self:OnUpdateInventory() -- Check Full Bag Indicator

	self.wndAlertContainer:ArrangeChildrenHorz(0)
	--self.wndLootAlert:FindChild("AlertItemTransition"):SetSprite("sprWinAnim_BirthSmallTemp") -- No Anim for vacuum
end

function HUDAlerts:OnDatachronCallIncoming()
	local strKeybind = GameLib.GetKeyBinding("Communicator")
	self.wndCallAlert:FindChild("AlertItemKeybindText"):SetText(strKeybind)
	self.wndCallAlert:FindChild("AlertItemKeybind"):Show(strKeybind ~= Apollo.GetString("HUDAlert_Unbound"))
	self.wndCallAlert:FindChild("AlertItemIcon"):SetSprite("CRB_HUDAlerts:sprAlert_CallIncoming")

	self:ShowAndInitializeAlert(self.wndCallAlert)
	Apollo.StopTimer("HUDAlerts_DatachronCallExpired")
	Apollo.CreateTimer("HUDAlerts_DatachronCallExpired", 60.0, false)
end

function HUDAlerts:OnDatachronCallMissed() -- Also from Initialize
	local strKeybind = GameLib.GetKeyBinding("Communicator")
	self.wndCallAlert:FindChild("AlertItemKeybindText"):SetText(strKeybind)
	self.wndCallAlert:FindChild("AlertItemKeybind"):Show(strKeybind ~= Apollo.GetString("HUDAlert_Unbound"))
	self.wndCallAlert:FindChild("AlertItemIcon"):SetSprite("CRB_HUDAlerts:sprAlert_CallMissed")

	self:ShowAndInitializeAlert(self.wndCallAlert)
	Apollo.StopTimer("HUDAlerts_DatachronCallExpired")
	Apollo.CreateTimer("HUDAlerts_DatachronCallExpired", 60.0, false)
end

function HUDAlerts:OnHUDAlerts_DatachronCallExpired()
	self.wndCallAlert:Show(false)
	self.wndQuestCompleteAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnDatachronCallCleared()
	self.wndCallAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnChallengeUnlocked(tArgChallenge)
	-- Only if we run into the case where an already active type is ongoing
	for _, tCurr in pairs(ChallengesLib.GetActiveChallengeList()) do
		if tCurr:IsActivated() and tCurr:GetType() == tArgChallenge:GetType() and tCurr:GetId() ~= tArgChallenge:GetId() then
			self:ShowChallengeHUDAlert(tArgChallenge)
			return
		end
	end
end

function HUDAlerts:ShowChallengeHUDAlert(tChallenge)
	self:ShowAndInitializeAlert(self.wndChallengeAlert)
	Apollo.CreateTimer("HUDAlerts_ChallengeTimerExpired", 60.0, false)
end

function HUDAlerts:OnHUDAlerts_ChallengeTimerExpired()
	self.wndChallengeAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

-----------------------------------------------------------------------------------------------
-- Quest Complete Frame
-----------------------------------------------------------------------------------------------

function HUDAlerts:DrawQuestCompleteAlert(tQuestsTracked)
	local strKeybind = GameLib.GetKeyBinding("Communicator")
	self.wndQuestCompleteAlert:FindChild("AlertItemKeybindText"):SetText(strKeybind)
	self.wndQuestCompleteAlert:FindChild("AlertItemKeybind"):Show(strKeybind ~= Apollo.GetString("HUDAlert_Unbound"))

	if tQuestsTracked then
		self.wndQuestCompleteAlert:FindChild("QuestMenuList"):DestroyChildren()
		for idx, tCurrQuest in pairs(tQuestsTracked) do
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "QuestCompleteItem", self.wndQuestCompleteAlert:FindChild("QuestMenuList"), self)
			wndCurr:FindChild("QuestCompleteItem"):SetData(tCurrQuest)

			-- Parent
			self.wndQuestCompleteAlert:FindChild("QuestCompleteBtn"):SetData(tCurrQuest)
			self.wndQuestCompleteAlert:FindChild("QuestCompleteMenuBtn"):Show(idx > 1)

			-- Resize to contents
			wndCurr:FindChild("QuestCompleteItemText"):SetAML("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff7fffb9\">"..tCurrQuest:GetTitle().."</P>")
			local nWidth, nHeight = wndCurr:FindChild("QuestCompleteItemText"):SetHeightToContentHeight()
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nHeight + 20) -- todo hardcoded padding above and below
		end
	end

	local nHeight = self.wndQuestCompleteAlert:FindChild("QuestMenuList"):ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = self.wndQuestCompleteAlert:FindChild("QuestMenuFrame"):GetAnchorOffsets()
	self.wndQuestCompleteAlert:FindChild("QuestMenuFrame"):SetAnchorOffsets(nLeft, nBottom - nHeight - 16, nRight, nBottom)

	self:ShowAndInitializeAlert(self.wndQuestCompleteAlert)
	self.wndQuestCompleteAlert:Show(tQuestsTracked and #tQuestsTracked > 0)

	Apollo.StopTimer("HUDAlerts_DatachronCallExpired")
	Apollo.CreateTimer("HUDAlerts_DatachronCallExpired", 600.0, false)
end

function HUDAlerts:RebuildQuestList()
	local tQuestsTracked = {}
	for idx, tEpisode in ipairs(QuestLib.GetTrackedEpisodes()) do
		for idx2, tCurrQuest in pairs(tEpisode:GetTrackedQuests()) do
			if tCurrQuest:GetState() == Quest.QuestState_Achieved then
				local tContactInfo = tCurrQuest:GetContactInfo()
				if tContactInfo and tContactInfo.strName and string.len(tContactInfo.strName) > 0 then -- Has a call back
					table.insert(tQuestsTracked, tCurrQuest)
				end
			end
		end
	end
	self:DrawQuestCompleteAlert(tQuestsTracked)
end

-----------------------------------------------------------------------------------------------
-- Datacube
-----------------------------------------------------------------------------------------------

function HUDAlerts:OnDatacubeUpdated(id, bIsVolume)
	if not id then
		return
	end

	local tDatacube = DatacubeLib.GetLastUpdatedDatacube(id, bIsVolume)
	if not tDatacube then
		return
	end

	-- Nothing until it's unlocked anyways
	if tDatacube.eDatacubeType == DatacubeLib.DatacubeType_Chronicle and not tDatacube.bIsComplete then
		return
	end

	local fDelay = 0.5 -- Per spec we need delay for the 'pick up' transition sound effect + animation
	if tDatacube.eDatacubeType == DatacubeLib.DatacubeType_Datacube then
		fDelay = 3.375
	end

	Apollo.StopTimer("HUDAlerts_PlayDatacubeTrack")
	Apollo.CreateTimer("HUDAlerts_PlayDatacubeTrack", fDelay, false)

	if not tDatacube.bHasSound then
		Apollo.StopTimer("HUDAlerts_MaxPlayDatacubeTrackTime")
		Apollo.CreateTimer("HUDAlerts_MaxPlayDatacubeTrackTime", 30, false)
	end

	self.wndDatacubeAlert:FindChild("DatacubeAlertBtn"):SetData(tDatacube)
	self:DrawDatacubePlayback(tDatacube)
end

function HUDAlerts:DrawDatacubePlayback(tDatacube) -- Also from eveents
	if not tDatacube then
		return
	end

	self:ShowAndInitializeAlert(self.wndDatacubeAlert)
	self.wndDatacubeAlert:FindChild("AlertItemIcon"):SetSprite(tDatacube.eDatacubeType == DatacubeLib.DatacubeType_Datacube and "sprAlert_Playback" or "sprAlert_Book")
	self.wndDatacubeAlert:FindChild("DatacubeAlertBtn"):SetData(tDatacube)
end

-----------------------------------------------------------------------------------------------
-- Durability:
-----------------------------------------------------------------------------------------------

function HUDAlerts:ShowDurabilityAlert() -- Also from events
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end

	local nBrokenItems = 0
	local nDamagedItems = 0
	for idx, item in ipairs(unitPlayer:GetEquippedItems()) do
		if item:GetMaxDurability() ~= 0 then
			local fDurabilityPercent = item:GetDurability() / item:GetMaxDurability()
			nBrokenItems = fDurabilityPercent == 0 and (nBrokenItems + 1) or nBrokenItems
			if not self.bHideDurabilityTimer then -- There is a "don't care" timer where we ignore damaged, if the player hides the alert
				nDamagedItems = fDurabilityPercent < 0.2 and (nDamagedItems + 1) or nDamagedItems
			end
		end
	end

	if nBrokenItems > 0 then -- Override "don't care" timer if we ever hit broken
		Apollo.StopTimer("HUDAlerts_HideDurabilityTimer")
		self.bHideDurabilityTimer = false
	end

	if nBrokenItems == 0 and nDamagedItems == 0 then
		self.wndDurabilityAlert:Show(false)
		self.wndAlertContainer:ArrangeChildrenHorz(0)
		return
	end

	local strKeybind = GameLib.GetKeyBinding("CharacterPanel")
	self.wndDurabilityAlert:FindChild("AlertItemKeybindText"):SetText(strKeybind)
	self.wndDurabilityAlert:FindChild("AlertItemKeybind"):Show(strKeybind ~= Apollo.GetString("HUDAlert_Unbound"))
	self.wndDurabilityAlert:FindChild("AlertPopoutText"):SetText(nBrokenItems > 0 and Apollo.GetString("HUDAlert_ItemsBroken") or Apollo.GetString("HUDAlert_ItemsDamaged"))
	self.wndDurabilityAlert:FindChild("AlertPopoutText"):SetTextColor(nBrokenItems > 0 and "ffff0000" or "ffffffff")
	self.wndDurabilityAlert:FindChild("DurabilityRunner"):Show(nBrokenItems > 0)

	self:ShowAndInitializeAlert(self.wndDurabilityAlert)
end

function HUDAlerts:OnHUDAlerts_HideDurabilityTimer()
	Apollo.StopTimer("HUDAlerts_HideDurabilityTimer")
	self.bHideDurabilityTimer = false
	self:ShowDurabilityAlert()
end

-----------------------------------------------------------------------------------------------
-- Btn Clicks
-----------------------------------------------------------------------------------------------

function HUDAlerts:OnChallengeAlertBtn(wndHandler, wndControl, eMouseButton)
	Apollo.StopTimer("HUDAlerts_ChallengeTimerExpired")
	if eMouseButton == GameLib.CodeEnumInputMouse.Left then
		Event_FireGenericEvent("ToggleChallengesWindow")
	end
	self.wndChallengeAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnDurabilityAlertBtn(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self.bHideDurabilityTimer = true
		Apollo.CreateTimer("HUDAlerts_HideDurabilityTimer", 600, false)
	elseif eMouseButton == GameLib.CodeEnumInputMouse.Left then
		Event_FireGenericEvent("ToggleCharacterWindow")
	end
	self.wndDurabilityAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnDatacubeAlertBtn(wndHandler, wndControl, eMouseButton) -- wndHandler is "DatacubeAlertBtn" and its data is a Datacube
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		DatacubeLib.StopDatacubeSound()
		Event_FireGenericEvent("GenericEvent_StopPlayingDatacube")
	else
		Event_FireGenericEvent("HudAlert_ToggleLoreWindow", wndHandler and wndHandler:GetData() or nil)
	end
	self.wndDatacubeAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnHUDAlerts_PlayDatacubeTrack()
	Apollo.StopTimer("HUDAlerts_PlayDatacubeTrack")
	local tDatacube = self.wndDatacubeAlert:FindChild("DatacubeAlertBtn"):GetData()
	if tDatacube then
		DatacubeLib.PlayDatacubeSound(tDatacube.nDatacubeId)
	end
end

function HUDAlerts:OnStopPlayingDatacube() -- Lots of events route here, including the natural playing end and manual end from collections
	Apollo.StopTimer("HUDAlerts_MaxPlayDatacubeTrackTime")
	self.wndDatacubeAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnCallAlertBtn(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("Datachron_HideCallPulse")
	else
		local tCallbackList = Quest:GetCallbackList(true)
		if tCallbackList and #tCallbackList > 0 then
			for idx, questCallback in ipairs(tCallbackList) do
				if questCallback:GetState() == Quest.QuestState_Mentioned then
					CommunicatorLib.CallContact(questCallback)
					break
				end
			end
		else
			CommunicatorLib.CallbackLastContact()
		end
	end

	self.wndCallAlert:Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

function HUDAlerts:OnQuestCompleteTurnIn(wndHandler, wndControl) -- wndHandler is "QuestCompleteItem" or "QuestCompleteBtn" and its data is tCurrQuest
	CommunicatorLib.CallContact(wndHandler:GetData())
	self.wndQuestCompleteAlert:FindChild("QuestMenuFrame"):Show(false)
	self.wndAlertContainer:ArrangeChildrenHorz(0)
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function HUDAlerts:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.HUDAlert then
		return
	end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndAlertContainer:GetRect()

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

local HUDAlertsInst = HUDAlerts:new()
HUDAlertsInst:Init()
G="1"/>
  