-----------------------------------------------------------------------------------------------
-- Client Lua Script for OptionsInterface
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

-- Settings are saved in a g_InterfaceOptions table. This allows 3rd party add-ons to carry over settings instantly if they reimplement an add-on.

local OptionsInterface = {}

local knWindowStayOnScreenOffset = 100

local knSaveVersion = 5

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
	self.tTrackedWindows = {}
	self.tTrackedWindowsByName = {}
	
	self.bUIScaleTimerActive = false
	self.bConstrainWindows 	 = true
	
	self:HelperSetUpGlobalIfNil()
	
	-- Set up defaults
	g_InterfaceOptions.Carbine.bSpellErrorMessages 			= true
	g_InterfaceOptions.Carbine.bFilterGuildInvite			= true
	g_InterfaceOptions.Carbine.bHealthBarFlashes 			= true
	g_InterfaceOptions.Carbine.bQuestTrackerByDistance 		= true
	g_InterfaceOptions.Carbine.bInteractTextOnUnit 			= false
	g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible = true
	g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests 		= false
	
	self.xmlDoc = XmlDoc.CreateFromFile("OptionsInterface.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function OptionsInterface:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementAdd",					"OnWindowManagementAdd", self)
	Apollo.RegisterEventHandler("ResolutionChanged",					"OnResolutionChanged", self)
	Apollo.RegisterEventHandler("ApplicationWindowSizeChanged",			"OnApplicationWindowSizeChanged", self)
	Apollo.RegisterEventHandler("TopLevelWindowMove",					"OnTopLevelWindowMove", self)
	
	Apollo.RegisterTimerHandler("OptionsInterface_FailSafe", 			"OnFailSafe", self)
	Apollo.RegisterTimerHandler("OptionsInterface_UIScaleDelayTimer", 	"OnUIScaleDelayTimer", self)
	
	Apollo.CreateTimer("OptionsInterface_UIScaleDelayTimer", 1.3, false)
	Apollo.StopTimer("OptionsInterface_UIScaleDelayTimer")
	
	self.wndInterface = Apollo.LoadForm(self.xmlDoc, "OptionsInterfaceForm", nil, self)
	self.wndInterface:Show(false, true)
	self.wndInterface:FindChild("GeneralBtn"):SetCheck(true)
	
	if not g_InterfaceOptionsLoaded then
		Apollo.CreateTimer("OptionsInterface_FailSafe", 2, false) -- Allow this to fire
	end
	
	Apollo.RegisterTimerHandler("WindowManagementLoadTimer", "OnWindowManagementLoadTimer", self)
	Apollo.CreateTimer("WindowManagementLoadTimer", 1.0, false)
	Apollo.StartTimer("WindowManagementLoadTimer")
	
	self.bResizeTimerRunning = false
	Apollo.RegisterTimerHandler("WindowManagementResizeTimer", "OnWindowManagementResizeTimer", self)
	Apollo.CreateTimer("WindowManagementResizeTimer", 1.0, false)
	
	self.wndInterface:FindChild("ConstrainToScreen"):SetCheck(self.bConstrainWindows)
	
	if g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible ~= GameLib.AreQuestUnitCalloutsVisible() then
		GameLib.ToggleQuestUnitCallouts()
	end

	GameLib.SetIgnoreDuelRequests(g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests)
end

function OptionsInterface:OnWindowManagementLoadTimer()
	Event_FireGenericEvent("WindowManagementReady")
end

function OptionsInterface:OnWindowManagementResizeTimer()
	self.bResizeTimerRunning = false
	self:ReDrawTrackedWindows()
end

function OptionsInterface:OnRestore(eType, tSavedData)	
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		g_InterfaceOptions = tSavedData.tSavedInterfaceOptions
		
		if tSavedData.tTrackedWindowsByName then
			self.tTrackedWindowsByName = tSavedData.tTrackedWindowsByName
		end
		
		if tSavedData.bConstrainWindows then
			self.bConstrainWindows = tSavedData.bConstrainWindows
		end
	end

	self:HelperSetUpGlobalIfNil()
	
	if g_InterfaceOptions.Carbine.bSpellErrorMessages == nil then
		g_InterfaceOptions.Carbine.bSpellErrorMessages = kbDefaultSpellErrorMessages
	end
	
	if g_InterfaceOptions.Carbine.bFilterGuildInvite == nil then
		g_InterfaceOptions.Carbine.bFilterGuildInvite = kbDefaultFilterGuildInvite
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
	
	local tSavedData = 
	{
		nSaveVersion = knSaveVersion,
		tSavedInterfaceOptions = g_InterfaceOptions,
		tTrackedWindowsByName = self.tTrackedWindowsByName,
		bConstrainWindows = self.bConstrainWindows,
	}
	return tSavedData
end

function OptionsInterface:OnGeneralOptionsCheck(wndHandler, wndControl)
	self.wndInterface:FindChild("Content:General"):Show(true)
	self.wndInterface:FindChild("Content:WindowContent"):Show(false)
end

function OptionsInterface:OnWindowOptionsCheck(wndHandler, wndControl)
	self.wndInterface:FindChild("Content:General"):Show(false)
	self.wndInterface:FindChild("Content:WindowContent"):Show(true)
end

function OptionsInterface:OnFailSafe()
	if not g_InterfaceOptionsLoaded then
		self:OnRestore(GameLib.CodeEnumAddonSaveLevel.Character, nil)
	end
end

function OptionsInterface:OnClose()
	self.wndInterface:Close()
end

function OptionsInterface:OnConfigure() -- From ESC -> Options
	self.wndInterface:MoveToLocation((self.wndInterface:GetOriginalLocation()))
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
	
	self.wndInterface:FindChild("IgnoreDuelRequests"):SetCheck(g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests)
	self.wndInterface:FindChild("ToggleQuestMarkers"):SetCheck(g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible)
	self.wndInterface:FindChild("SpellErrorMessages"):SetCheck(g_InterfaceOptions.Carbine.bSpellErrorMessages)
	self.wndInterface:FindChild("GuildInviteFilter"):SetCheck(g_InterfaceOptions.Carbine.bFilterGuildInvite)
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

-----------------------------------------------------------------------------------------------
-- Window Tracking
-----------------------------------------------------------------------------------------------

function OptionsInterface:OnWindowManagementAdd(tSettings)
	if tSettings and tSettings.wnd and tSettings.wnd:IsValid() and tSettings.strName and string.len(tSettings.strName) > 0 then
		tSettings.tDefaultLoc = tSettings.wnd:GetLocation():ToTable()
		tSettings.bHasMoved = false
		tSettings.bActiveEntry = true
		tSettings.bMoveable = tSettings.wnd:IsStyleOn("Moveable")
		tSettings.bRequireMetaKeyToMove = tSettings.wnd:IsStyleOn("RequireMetaKeyToMove")
		
		-- Remove the entry if it already existed previously.
		for idx, tOldSettings in pairs(self.tTrackedWindows) do
			if tOldSettings.strName == tSettings.strName then
				if tOldSettings.wndForm ~= nil and tOldSettings.wndForm:IsValid() then
					tOldSettings.wndForm:Destroy()
				end
				tOldSettings.wndForm = nil
				self.tTrackedWindows[idx] = nil
			end
		end
		
		if self.tTrackedWindowsByName[tSettings.strName] then
			tSettings.bMoveable = self.tTrackedWindowsByName[tSettings.strName].bMoveable
			tSettings.bRequireMetaKeyToMove = self.tTrackedWindowsByName[tSettings.strName].bRequireMetaKeyToMove
			tSettings.tCurrentLoc = self.tTrackedWindowsByName[tSettings.strName].tCurrentLoc
			
			tSettings.wnd:SetStyle("Moveable", tSettings.bMoveable)
			tSettings.wnd:SetStyle("RequireMetaKeyToMove", tSettings.bRequireMetaKeyToMove)
			tSettings.wnd:MoveToLocation(WindowLocation.new(tSettings.tCurrentLoc))
		end
		
		self.tTrackedWindows[tSettings.wnd:GetId()] = tSettings
	end
	
	self:ReDrawTrackedWindows()
end

function OptionsInterface:ReDrawTrackedWindows()
	local wndContainer = self.wndInterface:FindChild("Content:WindowContent:List")
	
	if not wndContainer then return end
	
	wndContainer:DestroyChildren()
	
	nIndex = 0
	for idx, tSettings in pairs(self.tTrackedWindows) do
		nIndex = nIndex + 1
		
		if self.tTrackedWindows[tSettings.wnd:GetId()] and tSettings.bActiveEntry then
			if tSettings.wndForm ~= nil and tSettings.wndForm:IsValid() then
				tSettings.wndForm:Destroy()
			end
			tSettings.wndForm = Apollo.LoadForm(self.xmlDoc, "WindowEntry", wndContainer, self)
			
			self:UpdateTrackedWindow(tSettings.wnd)
		else
			table.remove(self.tTrackedWindowsByName, nIndex)
		end
	end
	
	wndContainer:ArrangeChildrenVert(0, function(a,b) return (a:FindChild("WindowName"):GetText() < b:FindChild("WindowName"):GetText()) end)
end

function OptionsInterface:HasMoved(tSettings)
	local tCurrentOffsets = tSettings.tCurrentLoc.nOffsets
	local tDefaultOffsets = tSettings.tDefaultLoc.nOffsets
	
	return 
		tCurrentOffsets[1] ~= tDefaultOffsets[1] or
		tCurrentOffsets[2] ~= tDefaultOffsets[2]
end

function OptionsInterface:UpdateTrackedWindow(wndTracked)
	local tSettings = self.tTrackedWindows[wndTracked:GetId()]
	local strXColor = ApolloColor.new("UI_TextHoloBodyCyan")
	local strYColor = ApolloColor.new("UI_TextHoloBodyCyan")
	
	if tSettings and tSettings.bActiveEntry then
		local nX, nY = wndTracked:GetPos()
		tSettings.tCurrentLoc = wndTracked:GetLocation():ToTable()
		
		local nScreenWidth, nScreenHeight = Apollo:GetScreenSize()
		local strConstrainLabel = String_GetWeaselString(Apollo.GetString("CRB_OptionsInterface_Constrain"), nScreenWidth, nScreenHeight)
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = wndTracked:GetRect()
		local nWidth = tRect.r - tRect.l
		local nHeight = tRect.b - tRect.t
		local nDeltaX = 0
		local nDeltaY = 0
		
		local nCurrentX, nCurrentY = wndTracked:GetPos()
		nDeltaX = nCurrentX >= 0 and 0 or nCurrentX * -1
		nDeltaY = nCurrentY >= 0 and 0 or nCurrentY * -1
		
		nDeltaX = nCurrentX + nWidth > nScreenWidth and nScreenWidth - nCurrentX - nWidth or nDeltaX
		nDeltaY = nCurrentY + nHeight > nScreenHeight and nScreenHeight - nCurrentY - nHeight or nDeltaY
		
		strXColor = nDeltaX == 0 and ApolloColor.new("UI_TextHoloBodyCyan") or ApolloColor.new("UI_WindowTextCraftingRedCapacitor")
		strYColor = nDeltaY == 0 and ApolloColor.new("UI_TextHoloBodyCyan") or ApolloColor.new("UI_WindowTextCraftingRedCapacitor")
		
		local tOffsets = tSettings.tCurrentLoc.nOffsets
		local tPoints = tSettings.tCurrentLoc.fPoints
		
		if self.bConstrainWindows then	
			tSettings.tCurrentLoc.nOffsets = {
				tOffsets[1] + nDeltaX,
				tOffsets[2] + nDeltaY,
				tOffsets[3] + nDeltaX,
				tOffsets[4] + nDeltaY,
			}
		end
		
		self.tTrackedWindowsByName[tSettings.strName] = {
			strName					= tSettings.strName, 
			tCurrentLoc				= tSettings.tCurrentLoc,
			bMoveable				= tSettings.bMoveable,
			bRequireMetaKeyToMove 	= tSettings.bRequireMetaKeyToMove,
		}
		
		wndTracked:MoveToLocation(WindowLocation.new(tSettings.tCurrentLoc))
		
		tSettings.bHasMoved = self:HasMoved(tSettings)
		
		if tSettings.wndForm then
			tSettings.wndForm:FindChild("WindowName"):SetText(tSettings.strName)
			tSettings.wndForm:FindChild("X:EditBox"):SetText(nX)
			tSettings.wndForm:FindChild("X:EditBox"):SetData(tSettings)
			tSettings.wndForm:FindChild("X:EditBox"):Enable(false)
			tSettings.wndForm:FindChild("X:EditBox"):SetTextColor(strXColor)
			tSettings.wndForm:FindChild("Y:EditBox"):SetText(nY)
			tSettings.wndForm:FindChild("Y:EditBox"):SetData(tSettings)
			tSettings.wndForm:FindChild("Y:EditBox"):Enable(false)
			tSettings.wndForm:FindChild("Y:EditBox"):SetTextColor(strYColor)
			tSettings.wndForm:FindChild("ResetBtn"):SetData(tSettings)
			tSettings.wndForm:FindChild("ResetBtn"):Enable(tSettings.bHasMoved)
			tSettings.wndForm:FindChild("Moveable"):SetCheck(tSettings.bMoveable)
			tSettings.wndForm:FindChild("Moveable"):SetData(tSettings)
			tSettings.wndForm:FindChild("MoveableKey"):SetCheck(tSettings.bRequireMetaKeyToMove)
			tSettings.wndForm:FindChild("MoveableKey"):SetData(tSettings)
		end
		
		self.wndInterface:FindChild("ConstrainToScreen"):SetText(strConstrainLabel)
		
		Event_FireGenericEvent("WindowManagementUpdate", tSettings)
	end
end

function OptionsInterface:OnTopLevelWindowMove(wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom)
	self:UpdateTrackedWindow(wndControl)
end

function OptionsInterface:OnApplicationWindowSizeChanged(tSize)
	if self.bResizeTimerRunning then
		Apollo.StopTimer("WindowManagementResizeTimer")
	end
	
	Apollo.StartTimer("WindowManagementResizeTimer")
	self.bResizeTimerRunning = true
end

function OptionsInterface:OnResolutionChanged(nScreenWidth, nScreenHeight)
	if self.bResizeTimerRunning then
		Apollo.StopTimer("WindowManagementResizeTimer")
	end
	
	Apollo.StartTimer("WindowManagementResizeTimer")
	self.bResizeTimerRunning = true	
end

function OptionsInterface:OnResetAllBtn(wndHandler, wndControl)
	for idx, tSettings in pairs(self.tTrackedWindows) do
		self.tTrackedWindowsByName[tSettings.strName].tCurrentLoc = tSettings.tDefaultLoc
		tSettings.wnd:MoveToLocation(WindowLocation.new(tSettings.tDefaultLoc))
		
		self:UpdateTrackedWindow(tSettings.wnd)
	end
end

function OptionsInterface:OnResetBtn(wndHandler, wndControl)
	local tSettings = wndControl:GetData()
	
	if tSettings then
		self.tTrackedWindowsByName[tSettings.strName].tCurrentLoc = tSettings.tDefaultLoc
		tSettings.wnd:MoveToLocation(WindowLocation.new(tSettings.tDefaultLoc))
		
		self:UpdateTrackedWindow(tSettings.wnd)
	end
end

function OptionsInterface:OnConstrainToScreenChecked(wndHandler, wndControl)
	self.bConstrainWindows = not self.bConstrainWindows
end

function OptionsInterface:OnMoveableChecked(wndHandler, wndControl)
	local tSettings = wndControl:GetData()
	
	if tSettings then
		tSettings.bMoveable = not tSettings.bMoveable
		tSettings.bRequireMetaKeyToMove = tSettings.bRequireMetaKeyToMove and tSettings.bMoveable
		
		tSettings.wnd:SetStyle("Moveable", tSettings.bMoveable)
		tSettings.wnd:SetStyle("RequireMetaKeyToMove", tSettings.bRequireMetaKeyToMove)
		
		tSettings.wndForm:FindChild("MoveableKey"):SetCheck(tSettings.bRequireMetaKeyToMove)
		
		self:UpdateTrackedWindow(tSettings.wnd)
	end
end

function OptionsInterface:OnMoveableKeyChecked(wndHandler, wndControl)
	local tSettings = wndControl:GetData()
	
	if tSettings then
		tSettings.bRequireMetaKeyToMove = not tSettings.bRequireMetaKeyToMove
		tSettings.bMoveable = tSettings.bRequireMetaKeyToMove and true or tSettings.bMoveable
		
		tSettings.wnd:SetStyle("Moveable", tSettings.bMoveable)
		tSettings.wnd:SetStyle("RequireMetaKeyToMove", tSettings.bRequireMetaKeyToMove)
		
		tSettings.wndForm:FindChild("Moveable"):SetCheck(tSettings.bMoveable)
		
		self:UpdateTrackedWindow(tSettings.wnd)
	end
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

function OptionsInterface:OnToggleGuildInviteFilter(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bFilterGuildInvite = wndHandler:IsChecked()
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
