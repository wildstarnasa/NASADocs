-----------------------------------------------------------------------------------------------
-- Client Lua Script for HUDInteract
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local HUDInteract = {}

function HUDInteract:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function HUDInteract:Init()
    Apollo.RegisterAddon(self)
end

function HUDInteract:OnLoad() -- OnLoad then GetAsyncLoad then OnRestore
	self.xmlDoc = XmlDoc.CreateFromFile("HUDInteract.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function HUDInteract:OnDocumentReady()
	if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_HUDAlerts_ToggleInteractPopoutText", 		"OnToggleInteractPopoutText", self)
	Apollo.RegisterEventHandler("GenericEvent_HideInteractPrompt", 						"HideInteractWindows", self)
	Apollo.RegisterEventHandler("ChangeWorld", 											"HideInteractWindows", self)
	Apollo.RegisterEventHandler("LogOut", 												"HideInteractWindows", self)
	Apollo.RegisterEventHandler("KeyBindingKeyChanged", 								"OnKeyBindingUpdated", self) -- Interact Only
	Apollo.RegisterEventHandler("InteractiveUnitChanged", 								"OnInteractiveUnitChanged", self)
	Apollo.RegisterEventHandler("TargetUnitChanged", 									"OnVerifyTargetStillValid", self)
	Apollo.RegisterEventHandler("UnitDestroyed", 										"OnVerifyTargetStillValid", self)
	Apollo.RegisterEventHandler("Dialog_ShowState", 									"OnDialog_ShowState", self)
	Apollo.RegisterEventHandler("Dialog_Close", 										"OnDialog_Close", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDInteract", 							"OnOptionsUpdated", self)

	-- Stun Events
	Apollo.RegisterEventHandler("ActivateCCStateStun", 									"OnActivateCCStateStun", self)
	Apollo.RegisterEventHandler("RemoveCCStateStun", 									"OnRemoveCCStateStun", self)

	self.wndInteractMarkerOnUnit = Apollo.LoadForm(self.xmlDoc, "InteractionOnUnit", "InWorldHudStratum", self)
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "InteractForm", "FixedHudStratum", self)
	self.xmlDoc = nil

	self.unitInteract = nil

	self:OnOptionsUpdated()
end

function HUDInteract:OnOptionsUpdated()
	if g_InterfaceOptions and g_InterfaceOptions.Carbine.bInteractTextOnUnit ~= nil then
		self.bInteractTextOnUnit = g_InterfaceOptions.Carbine.bInteractTextOnUnit
	else
		self.bInteractTextOnUnit = false
	end

	if self.wndInteractMarkerOnUnit and self.wndInteractMarkerOnUnit:IsValid() then
		self.wndInteractMarkerOnUnit:FindChild("InteractionOnUnitPopout"):Show(self.bInteractTextOnUnit)
		self:HideInteractWindows()
	end
end

-----------------------------------------------------------------------------------------------
-- CC
-----------------------------------------------------------------------------------------------

function HUDInteract:OnActivateCCStateStun()
	self.wndMain:Show(false)
end

function HUDInteract:OnRemoveCCStateStun()
	self.wndMain:Show(self.wndMain:GetData())
end

-----------------------------------------------------------------------------------------------
-- Interact
-----------------------------------------------------------------------------------------------

function HUDInteract:OnInteractiveUnitChanged(unitArg, strArg)
	local strKeybind = GameLib.GetKeyBinding("Interact")
	if strKeybind == Apollo.GetString("HUDAlert_Unbound") then -- Don't show interact
		return
	end

	self.unitInteract = unitArg

	-- HUD Alert Interact
	local bHideLootWhileVacuum = GameLib.CanVacuum() and unitArg and unitArg:GetLoot()
	if bHideLootWhileVacuum or unitArg == nil or strArg == nil then
		self:HideInteractWindows()
		return
	elseif self.bInteractTextOnUnit then
		local strKeybindFullText = string.len(strArg) == 0 and Apollo.GetString("HUDAlert_Interact") or strArg
		local nTextWidth = Apollo.GetTextWidth("CRB_InterfaceMedium_O", strKeybindFullText)
		local nLeft, nTop, nRight, nBottom = self.wndInteractMarkerOnUnit:FindChild("InteractionOnUnitPopout"):GetAnchorOffsets()
		self.wndInteractMarkerOnUnit:FindChild("InteractionOnUnitPopout"):SetAnchorOffsets(nLeft, nTop, math.max(50, nLeft + nTextWidth + 8), nBottom)
		self.wndInteractMarkerOnUnit:FindChild("InteractionOnUnitFullText"):SetText(strKeybindFullText)
	elseif not self.bDialogWindowUp then
		local strKeybindFullText = string.len(strArg) == 0 and Apollo.GetString("HUDAlert_Interact") or strArg
		self.wndMain:Show(true)
		self.wndMain:FindChild("AlertItemKeybindText"):SetText(strKeybind)
		self.wndMain:FindChild("KeybindFullText"):SetText(strKeybindFullText)
		self.wndMain:FindChild("AlertItemIcon"):SetSprite("CRB_HUDAlerts:sprAlert_Interact") -- This is a Cycle 0 animation

		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		local nTextWidth = Apollo.GetTextWidth("CRB_InterfaceMedium_O", strKeybindFullText)
		self.wndMain:SetAnchorOffsets(nLeft, nTop, math.max(75, nLeft + nTextWidth + 28), nBottom)
	end

	-- Marker on the unit
	local unitTarget = GameLib.GetTargetUnit()
	if unitArg and unitArg ~= unitTarget then
		self.wndMain:SetData(unitArg)
		self.wndInteractMarkerOnUnit:Show(true)
		--self.wndMain:FindChild("AlertItemTransition"):SetSprite("sprAlert_SectionGlowRingFlash")
		self.wndInteractMarkerOnUnit:SetUnit(unitArg, 8)
	else
		self.wndMain:SetData(nil)
		self.wndInteractMarkerOnUnit:Show(false)
	end
end

function HUDInteract:OnVerifyTargetStillValid(unitArg)
	if not self.wndInteractMarkerOnUnit or not self.wndInteractMarkerOnUnit:IsValid() or not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
		return
	end

	if not unitArg or unitArg == self.wndMain:GetData() then
		self.wndInteractMarkerOnUnit:Show(false)
	end
end

function HUDInteract:HideInteractWindows() -- A generic event also routes here
	self.wndMain:Show(false)
	self.wndMain:SetData(false)
	self.wndInteractMarkerOnUnit:Show(false)
end

function HUDInteract:OnKeyBindingUpdated(strKeybind) -- Interact Only
	if strKeybind ~= Apollo.GetString("HUDAlert_Interact") then
		return
	end

	local interactBind = GameLib.GetKeyBinding(Apollo.GetString("HUDAlert_Interact"))
	if interactBind == Apollo.GetString("HUDAlert_Unbound") then -- Don't show interact
		self:HideInteractWindows()
	else
		self.wndMain:FindChild("AlertItemKeybind"):SetText(interactBind)
	end
end

function HUDInteract:OnDialog_ShowState(eState, tQuest) -- Hide Interact during Quest Dialog
	if eState == DialogSys.DialogState_Inactive then
		return
	end

	local tResponseList = DialogSys.GetResponses(tQuest and tQuest:GetId() or 0)
	if tResponseList and #tResponseList > 0 then
		self.bDialogWindowUp = true
		self:HideInteractWindows()
	end
end

function HUDInteract:OnDialog_Close() -- Hide Interact during Quest Dialog
	self.bDialogWindowUp = false
	if self.unitInteract ~= nil then
		self.wndMain:Show(not self.bInteractTextOnUnit)
		self.wndInteractMarkerOnUnit:Show(self.bInteractTextOnUnit)
	end
end

-----------------------------------------------------------------------------------------------
-- Interaction
-----------------------------------------------------------------------------------------------

function HUDInteract:OnAlertItemMouseEnter(wndHandler, wndControl)
	local wndParent = wndHandler:GetParent()
	wndParent:FindChild("AlertItemHover"):Show(true)
end

function HUDInteract:OnAlertItemMouseExit(wndHandler, wndControl)
	local wndParent = wndHandler:GetParent()
	wndParent:FindChild("AlertItemHover"):Show(false)
end

function HUDInteract:OnToggleInteractPopoutText(bToggle)
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("AlertPopout") then
		self.wndMain:FindChild("AlertPopout"):Show(bToggle, not bToggle)
		self.wndMain:FindChild("AlertItemKeybind"):SetSprite(bToggle and "sprAlert_Square_Blue" or "sprAlert_Square_Black")
	end
end

local HUDInteractInst = HUDInteract:new()
HUDInteractInst:Init()
en