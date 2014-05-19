-----------------------------------------------------------------------------------------------
-- Client Lua Script for ProgressLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

local ProgressLog = {}

local knSaveVersion = 1

function ProgressLog:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ProgressLog:Init()
    Apollo.RegisterAddon(self)
end

function ProgressLog:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local locWindowLocation = g_wndProgressLog and g_wndProgressLog:GetLocation() or self.locSavedLocation

	local tSave =
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}

	return tSave
end

function ProgressLog:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.tWindowLocation then
		self.locSavedLocation = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function ProgressLog:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ProgressLog.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ProgressLog:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("ToggleCodex", "OnProgressLogOn", self)
	Apollo.RegisterEventHandler("ToggleQuestLog", "ToggleQuestLog", self)
	Apollo.RegisterEventHandler("ToggleProgressLog", "OnProgressLogOn", self)
	Apollo.RegisterEventHandler("ToggleChallengesWindow", "ToggleChallenges", self)
	Apollo.RegisterEventHandler("ToggleAchievementWindow", "ToggleAchievements", self)

	Apollo.RegisterEventHandler("ShowQuestLog", "ToggleQuestLogFromCall", self)
	Apollo.RegisterEventHandler("FloatTextPanel_ToggleAchievementWindow", "ToggleAchievementsWithData", self)
	Apollo.RegisterEventHandler("PlayerPathShow", "TogglePlayerPath", self) 
	Apollo.RegisterEventHandler("PlayerPathShow_NoHide", "ShowPlayerPath", self )
	Apollo.RegisterEventHandler("PlayerPathShowWithData", "TogglePlayerPathWithData", self) -- TODO No longer used

    g_wndProgressLog = Apollo.LoadForm(self.xmlDoc, "ProgressLogForm", nil, self)
	g_wndProgressLog:Show(false, true)
	
	self.xmlDoc = nil
	if self.locSavedLocation then
		g_wndProgressLog:MoveToLocation(self.locSavedLocation)
	end
    self.wndOptions = g_wndProgressLog:FindChild("FilterContainer")

	self.tContent = {}
	for idx = 1, 4 do
		self.tContent[idx] = g_wndProgressLog:FindChild("ContentWnd_" .. idx)
		self.tContent[idx]:Show(false)
	end

	Event_FireGenericEvent("ProgressLogLoaded")
	self.nLastSelection = -1
end

function ProgressLog:OnProgressLogOn() --general toggle
	if g_wndProgressLog:IsShown() then
		g_wndProgressLog:Show(false)
		Event_FireGenericEvent("CodexWindowHasBeenClosed")
	else
		Event_ShowTutorial(GameLib.CodeEnumTutorial.Codex)
		--g_wndProgressLog:Show(true) -- Don't turn on just yet, the other calls will toggle visibility.

		self.nLastSelection = self.nLastSelection or 1

		if self.nLastSelection == 1 then
			self:ToggleQuestLog()
		elseif self.nLastSelection == 2 then
			self:TogglePlayerPath()
		elseif self.nLastSelection == 3 then
			self:ToggleChallenges()
		elseif self.nLastSelection == 4 then
			self:ToggleAchievements()
		else self:ToggleQuestLog() end
	end
end

function ProgressLog:OnCancel(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	g_wndProgressLog:Show(false)
	Event_FireGenericEvent("CodexWindowHasBeenClosed")
	Event_FireGenericEvent("PL_TabChanged")
end

function ProgressLog:ToggleQuestLog()
	if g_wndProgressLog:IsShown() and self.nLastSelection == 1 then
		g_wndProgressLog:Show(false)
		Event_FireGenericEvent("CodexWindowHasBeenClosed")
	else
		g_wndProgressLog:Show(true)
		g_wndProgressLog:ToFront()
		self.wndOptions:SetRadioSel("PLogOptions", 1)
		self:PLogOptionCheck(nil, nil, false)
	end
end

function ProgressLog:ToggleQuestLogFromCall(idQuest) -- the log uses this event to update AND set a quest (if clicked from the tracker)
	if idQuest == nil then -- we only want calls that pop the log with a quest selected
		return
	end
	g_wndProgressLog:Show(true)
	g_wndProgressLog:ToFront()
	self.wndOptions:SetRadioSel("PLogOptions", 1)
	self:PLogOptionCheck(nil, nil, true) -- this will allow us to open the log, but not override a set quest
end

function ProgressLog:TogglePlayerPath()
	if g_wndProgressLog:IsShown() and self.nLastSelection == 2 then
		g_wndProgressLog:Show(false)
	else
		self:ShowPlayerPath()
	end
end

function ProgressLog:ShowPlayerPath()
	g_wndProgressLog:Show(true)
	g_wndProgressLog:ToFront()
	self.wndOptions:SetRadioSel("PLogOptions", 2)
	self:PLogOptionCheck(nil, nil, false)
end

-- Right now this is from the HUD Alerts
function ProgressLog:TogglePlayerPathWithData(tUserData)
	g_wndProgressLog:Show(true)
	g_wndProgressLog:ToFront()
	self.wndOptions:SetRadioSel("PLogOptions", 2)
	self:PLogOptionCheck(nil, nil, false, tUserData)
end

function ProgressLog:ToggleChallenges()
	if g_wndProgressLog:IsShown() and self.nLastSelection == 3 then
		g_wndProgressLog:Show(false)
		Event_FireGenericEvent("CodexWindowHasBeenClosed")
	else
		g_wndProgressLog:Show(true)
		g_wndProgressLog:ToFront()
		self.wndOptions:SetRadioSel("PLogOptions", 3)
		self:PLogOptionCheck(nil, nil, false)
	end
end

function ProgressLog:ToggleAchievements()
	if g_wndProgressLog:IsShown() and self.nLastSelection == 4 then
		g_wndProgressLog:Show(false)
		Event_FireGenericEvent("CodexWindowHasBeenClosed")
	else
		g_wndProgressLog:Show(true)
		g_wndProgressLog:ToFront()
		self.wndOptions:SetRadioSel("PLogOptions", 4)
		self:PLogOptionCheck(nil, nil, false)
	end
end

function ProgressLog:ToggleAchievementsWithData(achReceived)
	g_wndProgressLog:Show(true)
	g_wndProgressLog:ToFront()
	self.wndOptions:SetRadioSel("PLogOptions", 4)
	self:PLogOptionCheck(nil, nil, false, achReceived)
end

function ProgressLog:PLogOptionCheck(wndHandler, wndControl, bToggledFromCall, tUserData)
	local nPLogOption = self.wndOptions:GetRadioSel("PLogOptions")
	if nPLogOption ~= 1 then -- the player's switched to anything but QuestLog (which auto-selects)
		Event_FireGenericEvent("PL_TabChanged") -- stops anything going on in the window
	end

	for idx = 1, 4 do
		self.tContent[idx]:Show(false)
	end

	if nPLogOption == 1 then --and not bToggledFromCall then
		Event_FireGenericEvent("ShowQuestLog")
	elseif nPLogOption == 2 then
		Event_FireGenericEvent("PL_TogglePlayerPath", tUserData)
	elseif nPLogOption == 3 then
		Event_FireGenericEvent("PL_ToggleChallengesWindow")
	elseif nPLogOption == 4 then
		Event_FireGenericEvent("PL_ToggleAchievementWindow", tUserArg)
	end

	self.nLastSelection = nPLogOption -- Save last selection
	self.tContent[nPLogOption]:Show(true)

	if not g_wndProgressLog:IsVisible() then -- in case it's responding to a key or Datachron toggle
		g_wndProgressLog:Show(true)
		g_wndProgressLog:ToFront()
	end
end

local ProgressLogInst = ProgressLog:new()
ProgressLogInst:Init()
