-----------------------------------------------------------------------------------------------
-- Client Lua Script for Nameplates
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "ChallengesLib"
require "Unit"
require "GameLib"
require "Apollo"
require "PathMission"
require "Quest"
require "Episode"
require "math"
require "string"
require "DialogSys"
require "PublicEvent"
require "PublicEventObjective"
require "CommunicatorLib"
require "Tooltip"
require "GroupLib"
require "PlayerPathLib"
require "GuildLib"
require "GuildTypeLib"

local HUD = {}

local knSaveVersion = 1

function HUD:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    
	return o
end

function HUD:Init()
    Apollo.RegisterAddon(self, true)
end

function HUD:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLocation
	
	local tSave =
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	
	return tSave
end

function HUD:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		if tSavedData.tWindowLocation then
			self.locSavedWindowLocation = WindowLocation.new(tSavedData.tWindowLocation)
		end
	end
end

function HUD:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("HUD.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function HUD:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("OptionsUpdated_HUDTriggerTutorial", "OnTriggerTutorial", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDPreferences", "InitializeControls", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "HUDForm", nil, self)
	self.wndMain:Show(false)
	
	if self.locSavedWindowLocation then
		self.wndMain:MoveToLocation(self.locSavedWindowLocation)
	end
	
	self.wndTutorial = Apollo.LoadForm(self.xmlDoc, "HUDTutorial", nil, self)
	self.wndTutorial:Show(false)
	self.xmlDoc= nil
	
	
	self.mapDDParents = {
		--hud options
		{
			wnd = self.wndMain:FindChild("DropToggleMyUnitFrame"),
			consoleVar = "hud.myUnitFrameDisplay",
			radio = "HUDMyUnitFrameGroup",
			tutorialLabel = "OptionsHUD_MyUnitFrameLabel",
			tutorialDesc = "OptionsHUD_MyUnitFrameTutorial",
		},
		{
			wnd = self.wndMain:FindChild("DropToggleFocusTargetFrame"),
			consoleVar = "hud.focusTargetFrameDisplay",
			radio = "HUDFocusTargetFrameGroup"
		},
		{
			wnd = self.wndMain:FindChild("DropToggleTargetOfTargetFrame"),
			consoleVar = "hud.targetOfTargetFrameDisplay",
			radio = "HUDTargetOfTargetFrameGroup"
		},
		{
			wnd = self.wndMain:FindChild("DropToggleSkillsBar"),
			consoleVar = "hud.skillsBarDisplay",
 			radio = "HUDSkillsGroup",
			tutorialLabel = "OptionsHUD_SkillsBarLabel",
			tutorialDesc = "OptionsHUD_SkillsBarTutorial",
		},
		{
			wnd = self.wndMain:FindChild("DropToggleResource"),
			consoleVar = "hud.resourceBarDisplay",
 			radio = "HUDResourceGroup"
		},
		{
			wnd = self.wndMain:FindChild("DropToggleSecondaryLeft"),
			consoleVar = "hud.secondaryLeftBarDisplay",
			radio = "HUDSecondaryLeftGroup"},
		{
			wnd = self.wndMain:FindChild("DropToggleSecondaryRight"),
			consoleVar = "hud.secondaryRightBarDisplay",
			radio = "HUDSecondaryRightGroup"},
		{
			wnd = self.wndMain:FindChild("DropToggleXP"),
			consoleVar = "hud.xpBarDisplay",
 			radio = "HUDXPGroup",
			tutorialLabel = "OptionsHUD_XPLabel",
			tutorialDesc = "OptionsHUD_XPTutorial",
		},
		{
			wnd = self.wndMain:FindChild("DropToggleMount"),
			consoleVar = "hud.mountButtonDisplay",
			radio = "HUDMountGroup"
		},
		{
			wnd = self.wndMain:FindChild("DropToggleTime"),
			consoleVar = "hud.timeDisplay",
			radio = "HUDTimeGroup"
		},
		{
			wnd = self.wndMain:FindChild("DropToggleHealthText"),
			consoleVar = "hud.healthTextDisplay",
			radio = "HUDHealthTextGroup"
		},
	}
	
	for idx, wndDD in pairs(self.mapDDParents) do
		wndDD.wnd:AttachWindow(wndDD.wnd:FindChild("ChoiceContainer"))
		wndDD.wnd:FindChild("ChoiceContainer"):Show(false)
	end
	
	self:InitializeControls()
	self:InitializeTutorialControls()
end

function HUD:OnConfigure()
	self.wndMain:Show(true)
end

function HUD:OnTriggerTutorial(controlKey)
	local consoleVar = "hud."..controlKey
	self.tTutorialControl = nil;
	
	for idx, wndDD in pairs(self.mapDDParents) do
		if wndDD.consoleVar == consoleVar then
			self.tTutorialControl = wndDD
		end
	end
	
	if self.tTutorialControl == nil then
		return
	end
	
	self.nTutorialPref = 1
	Apollo.SetConsoleVariable(consoleVar, 1)
	Event_FireGenericEvent("OptionsUpdated_HUDPreferences")	
	
	--self.wndTutorial:FindChild("ControlText"):SetText(Apollo.GetString(self.tTutorialControl.tutorialLabel))
	--self.wndTutorial:FindChild("BodyText"):SetText(Apollo.GetString(self.tTutorialControl.tutorialDesc))	
	--self.wndTutorial:Show(true)
end

-----------------------------------------------------------------------------------------------
-- NameplatesForm Functions
-----------------------------------------------------------------------------------------------

function HUD:InitializeControls()
	for idx, parent in pairs(self.mapDDParents) do
		if parent.wnd ~= nil and parent.consoleVar ~= nil and parent.radio ~= nil then

			local arBtns = parent.wnd:FindChild("ChoiceContainer"):GetChildren()

			for idxBtn = 1, #arBtns do
				arBtns[idxBtn]:SetCheck(false)
			end

			self.wndMain:SetRadioSel(parent.radio, Apollo.GetConsoleVariable(parent.consoleVar))
			if arBtns[Apollo.GetConsoleVariable(parent.consoleVar)] ~= nil then
				arBtns[Apollo.GetConsoleVariable(parent.consoleVar)]:SetCheck(true)
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

function HUD:InitializeTutorialControls()
	local tutorialDD = self.wndTutorial:FindChild("DropToggle")
	
	tutorialDD:AttachWindow(tutorialDD:FindChild("ChoiceContainer"))
	tutorialDD:FindChild("ChoiceContainer"):Show(false)
	
	local arBtns = tutorialDD:FindChild("ChoiceContainer"):GetChildren()

	for idxBtn = 1, #arBtns do
		if idxBtn == 1 then
			tutorialDD:SetText(arBtns[idxBtn]:GetText())
			arBtns[idxBtn]:SetCheck(true)	
		else
			arBtns[idxBtn]:SetCheck(false)
		end
	end
end

function HUD:OnHUDRadio(wndHandler, wndControl)
	for idx, wndDD in pairs(self.mapDDParents) do
		if wndDD.wnd == wndControl:GetParent():GetParent() then
			Apollo.SetConsoleVariable(wndDD.consoleVar, wndControl:GetParent():GetRadioSel(wndDD.radio))
			wndControl:GetParent():GetParent():SetText(wndControl:GetText())
			
			break
		end
	end
	
	Event_FireGenericEvent("OptionsUpdated_HUDPreferences")
	wndControl:GetParent():Close()
end

function HUD:OnHUDTutorialRadio(wndHandler, wndControl)
	local tutorialDD = self.wndTutorial:FindChild("DropToggle")
	local arBtns = tutorialDD:FindChild("ChoiceContainer"):GetChildren()
	
	for idxBtn = 1, #arBtns do
		if arBtns[idxBtn] == wndControl then
			self.nTutorialPref = idxBtn
		end
	end

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

-- when the OK button is clicked
function HUD:OnOK()
	self.wndMain:Show(false) -- hide the window
end

-- when the Cancel button is clicked
function HUD:OnCancel()
	self.wndMain:Show(false) -- hide the window
end

function HUD:OnTutorialOK()
	local tutorialDD = self.wndTutorial:FindChild("DropToggle")
	
	Apollo.SetConsoleVariable(
		self.tTutorialControl.consoleVar, 
		self.nTutorialPref
	)

	Event_FireGenericEvent("OptionsUpdated_HUDPreferences")
	self.wndTutorial:Show(false) -- hide the window
end

-----------------------------------------------------------------------------------------------
-- Nameplates Instance
-----------------------------------------------------------------------------------------------
local NameplatesInst = HUD:new()
NameplatesInst:Init()
