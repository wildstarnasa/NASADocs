-----------------------------------------------------------------------------------------------
-- Client Lua Script for OptionsInterface
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

-- Settings are saved in a g_InterfaceOptions table. This allows 3rd party add-ons to carry over settings instantly if they reimplement an add-on.

local OptionsInterface = {}

local kbDefaultSpellErrorMessages 		= true
local kbDefaultHealthBarFlashes 		= true
local kbDefaultQuestTrackerByDistance 	= true
local kbDefaultInteractTextOnUnit 		= false
local knWindowStayOnScreenOffset = 50

local knSaveVersion = 2

function OptionsInterface:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function OptionsInterface:Init()
    Apollo.RegisterAddon(self, true)
end

function OptionsInterface:OnLoad() -- OnLoad then GetAsyncLoad then OnRestore
	self.xmlDoc = XmlDoc.CreateFromFile("OptionsInterface.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function OptionsInterface:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("ResolutionChanged",					"OnResolutionChanged", self)
	
	Apollo.RegisterTimerHandler("OptionsInterface_FailSafe", 			"OnFailSafe", self)
	Apollo.RegisterTimerHandler("OptionsInterface_UIScaleDelayTimer", 	"OnUIScaleDelayTimer", self)
	
	Apollo.CreateTimer("OptionsInterface_UIScaleDelayTimer", 1.3, false)
	Apollo.StopTimer("OptionsInterface_UIScaleDelayTimer")
	self.bUIScaleTimerActive = false
	
	
	
	self.wndInterface = Apollo.LoadForm(self.xmlDoc, "OptionsInterfaceForm", nil, self)
	self.wndInterface:Show(false, true)
	
	if self.locSavedWindowLoc then
		self.wndInterface:MoveToLocation(self.locSavedWindowLoc)
	end
	
	self.xmlDoc = nil
	
	if not g_InterfaceOptionsLoaded then
		Apollo.CreateTimer("OptionsInterface_FailSafe", 2, false) -- Allow this to fire
	end
end

function OptionsInterface:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		g_InterfaceOptions = tSavedData.tSavedInterfaceOptions
		
		if tSavedData.tWindowLocation then
			self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
		end
	end

	self:HelperSetUpGlobalIfNil()

	if g_InterfaceOptions.Carbine.bSpellErrorMessages == nil then
		g_InterfaceOptions.Carbine.bSpellErrorMessages = kbDefaultSpellErrorMessages
	end

	if g_InterfaceOptions.Carbine.bHealthBarFlashes == nil then
		g_InterfaceOptions.Carbine.bHealthBarFlashes = kbDefaultHealthBarFlashes
	end

	if g_InterfaceOptions.Carbine.bQuestTrackerByDistance == nil then
		g_InterfaceOptions.Carbine.bQuestTrackerByDistance = kbDefaultQuestTrackerByDistance
	end

	if g_InterfaceOptions.Carbine.bInteractTextOnUnit == nil then
		g_InterfaceOptions.Carbine.bInteractTextOnUnit = kbDefaultInteractTextOnUnit
	end
	
	local bAreCalloutsVisible = GameLib.AreQuestUnitCalloutsVisible()
	
	if g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible == nil then
		g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible = bAreCalloutsVisible
	elseif g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible ~= bAreCalloutsVisible then
		GameLib.ToggleQuestUnitCallouts()
	end
	
	local bIsIgnoringDuelRequests = GameLib.IsIgnoringDuelRequests()
	
	if g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests == nil then
		g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests = bIsIgnoringDuelRequests
	elseif g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests ~= bIsIgnoringDuelRequests then
		GameLib.SetIgnoreDuelRequests(g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests)
	end
	
	g_InterfaceOptionsLoaded = true
	Event_FireGenericEvent("InterfaceOptionsLoaded")

	-- Set up other add-ons
	Apollo.RegisterEventHandler("CharacterFlagsUpdated", "OnCharacterFlagsUpdated", self) -- TODO refactor
	Event_FireGenericEvent("OptionsUpdated_HealthShieldBar")
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
	Event_FireGenericEvent("OptionsUpdated_HUDInteract")
	Event_FireGenericEvent("OptionsUpdated_Floaters")
end

function OptionsInterface:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	self:HelperSetUpGlobalIfNil()
	
	local locWindowLocation = self.wndInterface and self.wndInterface:GetLocation() or self.locSavedWindowLoc

	local tSavedData = 
	{
		tSavedInterfaceOptions = g_InterfaceOptions,
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	return tSavedData
end

function OptionsInterface:OnFailSafe()
	if not g_InterfaceOptionsLoaded then
		self:OnRestore(GameLib.CodeEnumAddonSaveLevel.Character, nil)
		Event_FireGenericEvent("InterfaceOptionsLoaded")
	end
end

function OptionsInterface:OnClose()
	self.wndInterface:Close()
end

function OptionsInterface:OnConfigure() -- From ESC -> Options
	self.wndInterface:Show(true)
	self.wndInterface:FindChild("InvertMouse"):SetCheck(Apollo.GetConsoleVariable("camera.invertMouse"))
	self.wndInterface:FindChild("ClickToMove"):SetCheck(Apollo.GetConsoleVariable("player.clickToMove"))
	self.wndInterface:FindChild("MoveToActivate"):SetCheck(Apollo.GetConsoleVariable("player.moveToActivate"))
	self.wndInterface:FindChild("StickyTargeting"):SetCheck(Apollo.GetConsoleVariable("player.stickyTargeting"))
	self.wndInterface:FindChild("SpellTooltipLocation"):SetCheck(Apollo.GetConsoleVariable("ui.actionBarTooltipsOnCursor"))

	local fTooltip = Apollo.GetConsoleVariable("ui.TooltipDelay") or 0
	self.wndInterface:FindChild("TooltipDelaySliderBar"):SetValue(fTooltip)
	self.wndInterface:FindChild("TooltipDelayLabel"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_TooltipDelay"), fTooltip))

	local fUIScale = Apollo.GetConsoleVariable("ui.Scale") or 1
	self.wndInterface:FindChild("UIScaleSliderBar"):SetValue(fUIScale)
	self.wndInterface:FindChild("UIScaleLabel"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_UIScale"), fUIScale))

	self:HelperSetUpGlobalIfNil()

	-- Set up defaults (GOTCHA: Handle if 1/4 are nil, e.g. if we add more options later)
	if g_InterfaceOptions.Carbine.bSpellErrorMessages == nil then
		g_InterfaceOptions.Carbine.bSpellErrorMessages = kbDefaultSpellErrorMessages
	end

	if g_InterfaceOptions.Carbine.bHealthBarFlashes == nil then
		g_InterfaceOptions.Carbine.bHealthBarFlashes = kbDefaultHealthBarFlashes
	end

	if g_InterfaceOptions.Carbine.bQuestTrackerByDistance == nil then
		g_InterfaceOptions.Carbine.bQuestTrackerByDistance = kbDefaultQuestTrackerByDistance
	end

	if g_InterfaceOptions.Carbine.bInteractTextOnUnit == nil then
		g_InterfaceOptions.Carbine.bInteractTextOnUnit = kbDefaultInteractTextOnUnit
	end
	
	if g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible == nil then
		g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible = GameLib.AreQuestUnitCalloutsVisible()
	end
	
	if g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests == nil then
		g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests = GameLib.IsIgnoringDuelRequests()
	end
	
	
	self.wndInterface:FindChild("IgnoreDuelRequests"):SetCheck(g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests)
	self.wndInterface:FindChild("ToggleQuestMarkers"):SetCheck(g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible)
	self.wndInterface:FindChild("SpellErrorMessages"):SetCheck(g_InterfaceOptions.Carbine.bSpellErrorMessages)
	self.wndInterface:FindChild("HealthBarFlashes"):SetCheck(g_InterfaceOptions.Carbine.bHealthBarFlashes)
	self.wndInterface:FindChild("QuestTrackerByDistance"):SetCheck(g_InterfaceOptions.Carbine.bQuestTrackerByDistance)
	self.wndInterface:FindChild("InteractTextOnUnit"):SetCheck(g_InterfaceOptions.Carbine.bInteractTextOnUnit)
end

function OptionsInterface:HelperSetUpGlobalIfNil()
	if not g_InterfaceOptions or g_InterfaceOptions == nil then
		g_InterfaceOptions = {}
		g_InterfaceOptions.Carbine = {}
	elseif g_InterfaceOptions.Carbine == nil then -- GOTCHA: Use nil specifically and don't check for false
		g_InterfaceOptions.Carbine = {}
	end
end

function OptionsInterface:OnResolutionChanged(nScreenWidth, nScreenHeight)
	local nLeft, nTop, nRight, nBottom = self.wndInterface:GetRect()
	local nWidth = nRight - nLeft
	local nHeight = nBottom - nTop
	
	if nBottom < 0 then
		nBottom = knWindowStayOnScreenOffset
		nTop = -nHeight + knWindowStayOnScreenOffset
	end
	
	if  nTop > nScreenHeight then
		nBottom = nScreenHeight + nHeight - knWindowStayOnScreenOffset
		nTop = nScreenHeight - knWindowStayOnScreenOffset
	end
	
	if nRight < 0 then
		nRight = knWindowStayOnScreenOffset
		nLeft = -nWidth + knWindowStayOnScreenOffset
	end
	
	if  nLeft > nScreenWidth then
		nRight = nScreenWidth + nWidth - knWindowStayOnScreenOffset
		nLeft = nScreenWidth - knWindowStayOnScreenOffset
	end
	
	self.wndInterface:Move(nLeft, nTop, nWidth, nHeight)
end

-----------------------------------------------------------------------------------------------
-- Buttons
-----------------------------------------------------------------------------------------------

function OptionsInterface:OnCharacterFlagsUpdated()
	if self.wndInterface == nil or not self.wndInterface:IsShown() then
		return
	end
	self.wndInterface:FindChild("IgnoreDuelRequests"):SetCheck(GameLib.IsIgnoringDuelRequests())
end

function OptionsInterface:OnInvertMouse(wndHandler, wndControl)
	Apollo.SetConsoleVariable("camera.invertMouse", wndControl:IsChecked())
end

function OptionsInterface:OnClickToMove(wndHandler, wndControl)
	Apollo.SetConsoleVariable("player.clickToMove", wndControl:IsChecked())
end

function OptionsInterface:OnMoveToActivate(wndHandler, wndControl)
	Apollo.SetConsoleVariable("player.moveToActivate", wndControl:IsChecked())
end

function OptionsInterface:OnMappedOptionsQuestCallouts(wndHandler, wndControl)
	GameLib.ToggleQuestUnitCallouts()
	g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible = GameLib.AreQuestUnitCalloutsVisible()
end

function OptionsInterface:OnMappedOptionsSetIgnoreDuels(wndHandler, wndControl)
	GameLib.SetIgnoreDuelRequests(true)
	g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests = GameLib.IsIgnoringDuelRequests()
end

function OptionsInterface:OnMappedOptionsUnsetIgnoreDuels(wndHandler, wndControl)
	GameLib.SetIgnoreDuelRequests(false)
	g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests = GameLib.IsIgnoringDuelRequests()
end

function OptionsInterface:OnTargetOfTargetToggle(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_ToggleNameplate_bDrawToT", wndHandler:IsChecked())
end

function OptionsInterface:OnStickyTargetingToggle(wndHandler, wndControl)
	Apollo.SetConsoleVariable("player.stickyTargeting", wndControl:IsChecked())
end

function OptionsInterface:OnUIScaleSliderBarChanged(wndHandler, wndControl, fValue)
	self.wndInterface:FindChild("UIScaleLabel"):SetData(fValue)
	self.wndInterface:FindChild("UIScaleLabel"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_UIScale"), fValue))
	if not self.bUIScaleTimerActive then
		self.bUIScaleTimerActive = true
		Apollo.StopTimer("OptionsInterface_UIScaleDelayTimer")
		Apollo.StartTimer("OptionsInterface_UIScaleDelayTimer", fValue)
	end
end

function OptionsInterface:OnUIScaleDelayTimer(fValue)	
	if not fValue then
		fValue = self.wndInterface:FindChild("UIScaleLabel"):GetData() or 1
	end
	Apollo.SetConsoleVariable("ui.Scale", fValue)
	self.bUIScaleTimerActive = false
end

function OptionsInterface:OnTooltipDelaySliderBarChanged(wndHandler, wndControl, fValue)
	self.wndInterface:FindChild("TooltipDelayLabel"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_TooltipDelay"), fValue))
	Apollo.SetConsoleVariable("ui.TooltipDelay", fValue)
end

function OptionsInterface:OnToggleSpellIconTooltip(wndHandler, wndControl)
	Apollo.SetConsoleVariable("ui.actionBarTooltipsOnCursor", wndControl:IsChecked())
	Event_FireGenericEvent("Options_UpdateActionBarTooltipLocation")
end

function OptionsInterface:OnToggleSpellErrorMessages(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bSpellErrorMessages = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_Floaters")
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_SpellErrorToggle"), tostring(wndControl:IsChecked())))
end

function OptionsInterface:OnHealthBarFlashes(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bHealthBarFlashes = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_HealthShieldBar")
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_HealthFlashesToggle"), tostring(wndControl:IsChecked())))
end

function OptionsInterface:OnToggleQuestTrackerByDistance(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bQuestTrackerByDistance = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_DistanceSortingToggle"), tostring(wndHandler:IsChecked())))
end

function OptionsInterface:OnToggleInteractTextOnUnit(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bInteractTextOnUnit = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_HUDInteract")
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", Apollo.GetString("HUDAlert_InteractTextVisibilityChanged"), tostring(wndHandler:IsChecked()))
end

local OptionsInterfaceInst = OptionsInterface:new()
OptionsInterfaceInst:Init()
