-----------------------------------------------------------------------------------------------
-- Client Lua Script for OptionsInterface
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

-- Settings are saved in a g_InterfaceOptions table. This allows 3rd party add-ons to carry over settings instantly if they reimplement an add-on.

local OptionsInterface = {}

local knSaveVersion = 6

function OptionsInterface:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function OptionsInterface:Init()
    Apollo.RegisterAddon(self, true, Apollo.GetString("CRB_Interface"))
end

function OptionsInterface:OnLoad() -- OnLoad then GetAsyncLoad then OnRestore
	self.tTrackedWindows = {}
	self.tTrackedWindowsByName = {}

	self.bUIScaleTimerActive = false
	self.bConstrainWindows 	 = true

	self:HelperSetUpGlobalIfNil()

	-- Set up defaults
	g_InterfaceOptions.Carbine.bSpellErrorMessages 			= true
	g_InterfaceOptions.Carbine.bShowTutorials				= true
	g_InterfaceOptions.Carbine.bQuestTrackerByDistance 		= true
	g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom		= true
	g_InterfaceOptions.Carbine.bInteractTextOnUnit 			= false
	g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible = true
	g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests 		= false
	g_InterfaceOptions.Carbine.eShareChallengePreference 	= GameLib.SharedChallengePreference.AutoAccept

	self.xmlDoc = XmlDoc.CreateFromFile("OptionsInterface.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function OptionsInterface:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	if tSavedData  then -- and tSavedData.nSaveVersion == knSaveVersion
		g_InterfaceOptions = tSavedData.tSavedInterfaceOptions
		self:HelperSetUpGlobalIfNil()
		
		if tSavedData.tTrackedWindowsByName then
			self.tTrackedWindowsByName = tSavedData.tTrackedWindowsByName
		end

		if tSavedData.bConstrainWindows then
			self.bConstrainWindows = tSavedData.bConstrainWindows
		end
	end
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

function OptionsInterface:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("WindowManagementAdd",			"OnWindowManagementAdd", self)
	Apollo.RegisterEventHandler("ResolutionChanged",					"OnResolutionChanged", self)
	Apollo.RegisterEventHandler("ApplicationWindowSizeChanged",	"OnApplicationWindowSizeChanged", self)
	Apollo.RegisterEventHandler("TopLevelWindowMove",				"OnTopLevelWindowMove", self)
	Apollo.RegisterEventHandler("CharacterFlagsUpdated", 			"OnCharacterFlagsUpdated", self)

	Apollo.RegisterEventHandler("ChallengeLog_UpdateShareChallengePreference", 	"OnUpdateShareChallengePreference", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDTriggerTutorial", 			"OnTriggerTutorial", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDPreferences", 				"InitializeControls", self)

	Apollo.RegisterTimerHandler("OptionsInterface_UIScaleDelayTimer", 			"OnUIScaleDelayTimer", self)

	Apollo.CreateTimer("OptionsInterface_UIScaleDelayTimer", 1.3, false)
	Apollo.StopTimer("OptionsInterface_UIScaleDelayTimer")

	self.wndInterface = Apollo.LoadForm(self.xmlDoc, "OptionsInterfaceForm", nil, self)
	self.wndInterface:Show(false, true)
	self.wndInterface:FindChild("GeneralBtn"):SetCheck(true)

	Apollo.RegisterTimerHandler("WindowManagementLoadTimer", "OnWindowManagementLoadTimer", self)
	Apollo.CreateTimer("WindowManagementLoadTimer", 1.0, false)

	self.bResizeTimerRunning = false
	Apollo.RegisterTimerHandler("WindowManagementResizeTimer", "OnWindowManagementResizeTimer", self)
	Apollo.CreateTimer("WindowManagementResizeTimer", 1.0, false)
	Apollo.StopTimer("WindowManagementResizeTimer")

	Apollo.RegisterTimerHandler("WindowManagementAddAllWindowsTimer", "ReDrawTrackedWindows", self)
	Apollo.CreateTimer("WindowManagementAddAllWindowsTimer", 0.5, false)
	Apollo.StopTimer("WindowManagementAddAllWindowsTimer")

	self.wndInterface:FindChild("ConstrainToScreen"):SetCheck(self.bConstrainWindows)

	if g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible ~= GameLib.AreQuestUnitCalloutsVisible() then
		GameLib.ToggleQuestUnitCallouts()
	end

	-- GOTCHA: This doesn't actually persist between sessions, so we have to set it each time
	GameLib.SetSharedChallengePreference(g_InterfaceOptions.Carbine.eShareChallengePreference or 0)

	GameLib.SetIgnoreDuelRequests(g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests)

	if g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible ~= GameLib.AreQuestUnitCalloutsVisible() then
		GameLib.ToggleQuestUnitCallouts()
	end

	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
	Event_FireGenericEvent("OptionsUpdated_HUDInteract")
	Event_FireGenericEvent("OptionsUpdated_Floaters")

	self.mapDDParents = {
		--hud options
		{
			wnd = self.wndInterface:FindChild("DropToggleMyUnitFrame"),
			nConsoleVar = "hud.myUnitFrameDisplay",
			strRadioGroup = "HUDMyUnitFrameGroup",
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleFocusTargetFrame"),
			nConsoleVar = "hud.focusTargetFrameDisplay",
			strRadioGroup = "HUDFocusTargetFrameGroup"
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleTargetOfTargetFrame"),
			nConsoleVar = "hud.targetOfTargetFrameDisplay",
			strRadioGroup = "HUDTargetOfTargetFrameGroup"
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleSkillsBar"),
			nConsoleVar = "hud.skillsBarDisplay",
 			strRadioGroup = "HUDSkillsGroup",
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleResource"),
			nConsoleVar = "hud.resourceBarDisplay",
 			strRadioGroup = "HUDResourceGroup"
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleSecondaryLeft"),
			nConsoleVar = "hud.secondaryLeftBarDisplay",
			strRadioGroup = "HUDSecondaryLeftGroup"},
		{
			wnd = self.wndInterface:FindChild("DropToggleSecondaryRight"),
			nConsoleVar = "hud.secondaryRightBarDisplay",
			strRadioGroup = "HUDSecondaryRightGroup"},
		{
			wnd = self.wndInterface:FindChild("DropToggleXP"),
			nConsoleVar = "hud.xpBarDisplay",
 			strRadioGroup = "HUDXPGroup",
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleMount"),
			nConsoleVar = "hud.mountButtonDisplay",
			strRadioGroup = "HUDMountGroup"
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleTime"),
			nConsoleVar = "hud.timeDisplay",
			strRadioGroup = "HUDTimeGroup"
		},
		{
			wnd = self.wndInterface:FindChild("DropToggleHealthText"),
			nConsoleVar = "hud.healthTextDisplay",
			strRadioGroup = "HUDHealthTextGroup"
		},
	}

	for idx, wndDD in pairs(self.mapDDParents) do
		wndDD.wnd:AttachWindow(wndDD.wnd:FindChild("ChoiceContainer"))
		wndDD.wnd:FindChild("ChoiceContainer"):Show(false)
	end

	self:InitializeControls()
end

function OptionsInterface:OnWindowManagementLoadTimer()
	Event_FireGenericEvent("WindowManagementReady")
end

function OptionsInterface:OnWindowManagementResizeTimer()
	self.bResizeTimerRunning = false
	self:ReDrawTrackedWindows()
end

function OptionsInterface:OnGeneralOptionsCheck(wndHandler, wndControl)
	self.wndInterface:FindChild("Content:General"):Show(true)
	self.wndInterface:FindChild("Content:HUD"):Show(false)
	self.wndInterface:FindChild("Content:WindowContent"):Show(false)
end

function OptionsInterface:OnHUDOptionsCheck(wndHandler, wndControl)
	self.wndInterface:FindChild("Content:General"):Show(false)
	self.wndInterface:FindChild("Content:HUD"):Show(true)
	self.wndInterface:FindChild("Content:WindowContent"):Show(false)
end

function OptionsInterface:OnWindowOptionsCheck(wndHandler, wndControl)
	self.wndInterface:FindChild("Content:General"):Show(false)
	self.wndInterface:FindChild("Content:HUD"):Show(false)
	self.wndInterface:FindChild("Content:WindowContent"):Show(true)
end

function OptionsInterface:OnClose()
	self.wndInterface:Close()
end

function OptionsInterface:OnConfigure() -- From ESC -> Options
	self.wndInterface:MoveToLocation((self.wndInterface:GetOriginalLocation()))
	self.wndInterface:Invoke()
	self.wndInterface:FindChild("InvertMouse"):SetCheck(Apollo.GetConsoleVariable("camera.invertMouse"))

	local fTooltip = Apollo.GetConsoleVariable("ui.TooltipDelay") or 0
	self.wndInterface:FindChild("TooltipDelaySliderBar"):SetValue(fTooltip)
	self.wndInterface:FindChild("TooltipDelayLabel"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_TooltipDelay"), fTooltip))

	local fUIScale = Apollo.GetConsoleVariable("ui.Scale") or 1
	self.wndInterface:FindChild("UIScaleSliderBar"):SetValue(fUIScale)
	self.wndInterface:FindChild("UIScaleLabel"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_UIScale"), fUIScale))

	self.wndInterface:FindChild("IgnoreDuelRequests"):SetCheck(g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests)
	self.wndInterface:FindChild("ToggleQuestMarkers"):SetCheck(g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible)
	self.wndInterface:FindChild("SpellErrorMessages"):SetCheck(g_InterfaceOptions.Carbine.bSpellErrorMessages)
	self.wndInterface:FindChild("ChallengeSharePreference"):SetCheck(g_InterfaceOptions.Carbine.eShareChallengePreference == GameLib.SharedChallengePreference.Prompt)
	self.wndInterface:FindChild("QuestTrackerByDistance"):SetCheck(g_InterfaceOptions.Carbine.bQuestTrackerByDistance)
	self.wndInterface:FindChild("QuestAlignTop"):SetCheck(not g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom)
	self.wndInterface:FindChild("QuestAlignBottom"):SetCheck(g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom)

	self.wndInterface:FindChild("InteractTextOnUnit"):SetCheck(g_InterfaceOptions.Carbine.bInteractTextOnUnit)
	self.wndInterface:FindChild("ShowTutorials"):SetCheck(g_InterfaceOptions.Carbine.bShowTutorials)
end

function OptionsInterface:HelperSetUpGlobalIfNil()
	if not g_InterfaceOptions or g_InterfaceOptions == nil then
		g_InterfaceOptions = {}
		g_InterfaceOptions.Carbine = {}
	elseif g_InterfaceOptions.Carbine == nil then -- GOTCHA: Use nil specifically and don't check for false
		g_InterfaceOptions.Carbine = {}
	end
end

function OptionsInterface:InitializeControls()
	for idx, parent in pairs(self.mapDDParents) do
		if parent.wnd ~= nil and parent.nConsoleVar ~= nil and parent.strRadioGroup ~= nil then

			local arBtns = parent.wnd:FindChild("ChoiceContainer"):GetChildren()

			for idxBtn = 1, #arBtns do
				arBtns[idxBtn]:SetCheck(false)
			end

			self.wndInterface:SetRadioSel(parent.strRadioGroup, Apollo.GetConsoleVariable(parent.nConsoleVar))
			if arBtns[Apollo.GetConsoleVariable(parent.nConsoleVar)] ~= nil then
				arBtns[Apollo.GetConsoleVariable(parent.nConsoleVar)]:SetCheck(true)
			end

			local strLabel = Apollo.GetString("Options_Unspecified")
			for idxBtn = 1, #arBtns do
				if arBtns[idxBtn]:IsChecked() then
					strLabel = arBtns[idxBtn]:GetText()
				end
			end

			parent.wnd:SetText(strLabel)
		end
	end
end

function OptionsInterface:OnHUDRadio(wndHandler, wndControl)
	for idx, wndDD in pairs(self.mapDDParents) do
		if wndDD.wnd == wndControl:GetParent():GetParent() then
			Apollo.SetConsoleVariable(wndDD.nConsoleVar, wndControl:GetParent():GetRadioSel(wndDD.strRadioGroup))
			wndControl:GetParent():GetParent():SetText(wndControl:GetText())
			break
		end
	end

	Event_FireGenericEvent("OptionsUpdated_HUDPreferences")
	wndControl:GetParent():Show(false)
end

function OptionsInterface:OnTriggerTutorial(controlKey)
	Apollo.SetConsoleVariable("hud."..controlKey, 1)

	Event_FireGenericEvent("OptionsUpdated_HUDPreferences")
end

function OptionsInterface:OnUpdateShareChallengePreference(ePreference)
	GameLib.SetSharedChallengePreference(ePreference) -- This is not saved on the client or server
	g_InterfaceOptions.Carbine.eShareChallengePreference = ePreference
end

-----------------------------------------------------------------------------------------------
-- Window Tracking
-----------------------------------------------------------------------------------------------

function OptionsInterface:OnWindowManagementAdd(tSettings)
	if tSettings and tSettings.wnd and tSettings.wnd:IsValid() and tSettings.strName and string.len(tSettings.strName) > 0 then
		tSettings.tDefaultLoc = tSettings.wnd:GetLocation():ToTable()
		tSettings.bHasMoved = false
		tSettings.bActiveEntry = true
		tSettings.bRequireMetaKeyToMove = tSettings.wnd:IsStyleOn("RequireMetaKeyToMove")
		tSettings.nSaveVersion = tSettings.nSaveVersion or 1

		if not tSettings.bIsTabWindow then
			tSettings.bMoveable = tSettings.wnd:IsStyleOn("Moveable")
		else
			tSettings.bMoveable = not tSettings.wnd:IsLocked()
		end

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

		local tTrackedWindow = self.tTrackedWindowsByName[tSettings.strName]
		if tTrackedWindow and tTrackedWindow.nSaveVersion == tSettings.nSaveVersion then
			tSettings.bMoveable = tTrackedWindow.bMoveable
			tSettings.bRequireMetaKeyToMove = tTrackedWindow.bRequireMetaKeyToMove
			tSettings.tCurrentLoc = tTrackedWindow.tCurrentLoc

			tSettings.wnd:SetStyle("Moveable", tSettings.bMoveable)
			
			local nScreenWidth, nScreenHeight = Apollo:GetScreenSize()
			local nMaxWidth, nMaxHeight = tSettings.wnd:GetSizingMaximum()
			
			nMaxWidth = nMaxWidth > 0 and math.min(nMaxWidth, nScreenWidth) or nScreenWidth
			nMaxHeight = nMaxHeight > 0 and math.min(nMaxHeight, nScreenHeight) or nScreenHeight
			
			tSettings.wnd:SetSizingMaximum(nMaxWidth, nScreenHeight)

			if tSettings.bIsTabWindow then
				tSettings.wnd:Lock(not tSettings.bMoveable)
			end

			tSettings.wnd:SetStyle("RequireMetaKeyToMove", tSettings.bRequireMetaKeyToMove)
			tSettings.wnd:MoveToLocation(WindowLocation.new(tSettings.tCurrentLoc))
		end

		self.tTrackedWindows[tSettings.wnd:GetId()] = tSettings
	end

	Apollo.StopTimer("WindowManagementAddAllWindowsTimer")
	Apollo.StartTimer("WindowManagementAddAllWindowsTimer")
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
		local strConstrainLabelOutput = nil
		local tDisplay = Apollo.GetDisplaySize()
		if tDisplay and tDisplay.nWidth and tDisplay.nHeight then
			local strConstrainLabel = String_GetWeaselString(Apollo.GetString("CRB_OptionsInterface_Constrain"), tDisplay.nWidth, tDisplay.nHeight)
			local tRect = {}
			tRect.l, tRect.t, tRect.r, tRect.b = wndTracked:GetRect()
			local nWidth = tRect.r - tRect.l
			local nHeight = tRect.b - tRect.t
			local nDeltaX = 0
			local nDeltaY = 0

			local nCurrentX, nCurrentY = wndTracked:GetPos()
			nDeltaX = nCurrentX >= 0 and 0 or nCurrentX * -1
			nDeltaY = nCurrentY >= 0 and 0 or nCurrentY * -1
			strConstrainLabelOutput = strConstrainLabel 
			nDeltaX = nCurrentX + nWidth > tDisplay.nWidth and tDisplay.nWidth - nCurrentX - nWidth or nDeltaX
			nDeltaY = nCurrentY + nHeight > tDisplay.nHeight and tDisplay.nHeight - nCurrentY - nHeight or nDeltaY

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
		end

		self.tTrackedWindowsByName[tSettings.strName] = {
			strName							= tSettings.strName,
			tCurrentLoc					= tSettings.tCurrentLoc,
			bMoveable						= tSettings.bMoveable,
			bRequireMetaKeyToMove 	= tSettings.bRequireMetaKeyToMove,
			nSaveVersion					= tSettings.nSaveVersion
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

		self.wndInterface:FindChild("ConstrainToScreen"):SetText(strConstrainLabelOutput)

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

		if tSettings.bIsTabWindow then
			tSettings.wnd:Lock(not tSettings.bMoveable)
		end

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
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_InvertMouseToggle"), tostring(wndControl:IsChecked())))
end

function OptionsInterface:OnMappedOptionsQuestCallouts(wndHandler, wndControl)
	GameLib.ToggleQuestUnitCallouts()
	g_InterfaceOptions.Carbine.bAreQuestUnitCalloutsVisible = GameLib.AreQuestUnitCalloutsVisible()
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_QuestCalloutsToggle"), tostring(wndControl:IsChecked())))
end

function OptionsInterface:OnMappedOptionsSetIgnoreDuels(wndHandler, wndControl)
	GameLib.SetIgnoreDuelRequests(true)
	g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests = GameLib.IsIgnoringDuelRequests()
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_IgnoreDuelsToggle"), tostring(true)))
end

function OptionsInterface:OnMappedOptionsUnsetIgnoreDuels(wndHandler, wndControl)
	GameLib.SetIgnoreDuelRequests(false)
	g_InterfaceOptions.Carbine.bIsIgnoringDuelRequests = GameLib.IsIgnoringDuelRequests()
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_IgnoreDuelsToggle"), tostring(false)))
end

function OptionsInterface:OnTargetOfTargetToggle(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_ToggleNameplate_bDrawToT", wndHandler:IsChecked())
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

function OptionsInterface:OnToggleChallengeSharePreference(wndHandler, wndControl)	
	g_InterfaceOptions.Carbine.eShareChallengePreference = wndHandler:IsChecked() and GameLib.SharedChallengePreference.Prompt or GameLib.SharedChallengePreference.AutoAccept
	GameLib.SetSharedChallengePreference(g_InterfaceOptions.Carbine.eShareChallengePreference)
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_ChallengeShareToggle"), tostring(wndControl:IsChecked())))
end

function OptionsInterface:OnToggleTutorials(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bShowTutorials = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_ShowTutorials")
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_TutorialsToggle"), tostring(wndHandler:IsChecked())))
end

function OptionsInterface:OnToggleQuestTrackerByDistance(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bQuestTrackerByDistance = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("InterfaceOptions_DistanceSortingToggle"), tostring(wndHandler:IsChecked())))
end

function OptionsInterface:OnToggleQuestTrackerAlignTop(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom = not wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
end

function OptionsInterface:OnToggleQuestTrackerAlignBottom(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
end

function OptionsInterface:OnToggleInteractTextOnUnit(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bInteractTextOnUnit = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_HUDInteract")
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", Apollo.GetString("HUDAlert_InteractTextVisibilityChanged"), tostring(wndHandler:IsChecked()))
end

local OptionsInterfaceInst = OptionsInterface:new()
OptionsInterfaceInst:Init()
