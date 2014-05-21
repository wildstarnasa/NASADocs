-----------------------------------------------------------------------------------------------
-- Client Lua Script for HealthShieldBar
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "Apollo"
require "GameLib"
require "Spell"
require "Unit"
require "Item"

local HealthShieldBar = {}

function HealthShieldBar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function HealthShieldBar:Init()
    Apollo.RegisterAddon(self)
end

local knEvadeResource = 7 -- the resource hooked to dodges (TODO replace with enum)

local eEnduranceFlash =
{
	EnduranceFlashZero = 1,
	EnduranceFlashOne = 2,
	EnduranceFlashTwo = 3,
	EnduranceFlashThree = 4,
}

function HealthShieldBar:OnLoad() -- OnLoad then GetAsyncLoad then OnRestore
	self.xmlDoc = XmlDoc.CreateFromFile("HealthShieldBar.xml")
	Apollo.RegisterEventHandler("InterfaceOptionsLoaded", "OnDocumentReady", self)
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 

end

function HealthShieldBar:OnDocumentReady()
	if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() or not g_InterfaceOptionsLoaded or self.wndMain then
		return
	end
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 			"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 					"OnEnteredCombat", self)
	Apollo.RegisterEventHandler("RefreshHealthShieldBar", 				"OnFrameUpdate", self)	

	Apollo.RegisterTimerHandler("HealthShieldBarTimer", 				"OnFrameUpdate", self)
	Apollo.RegisterTimerHandler("EnduranceDisplayTimer", 				"OnEnduranceDisplayTimer", self)

	Apollo.CreateTimer("HealthShieldBarTimer", 0.5, true)
	--Apollo.CreateTimer("EnduranceDisplayTimer", 30, false) --TODO: Fix(?) This is perma-killing the display when DT dashing is disabled via the toggle

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "HealthShieldBarForm", "FixedHudStratum", self)

	self.wndEndurance = self.wndMain:FindChild("EnduranceContainer")
	self.wndDisableDash = self.wndEndurance:FindChild("DisableDashToggleContainer")

	self.bInCombat = false
	self.eEnduranceState = eEnduranceFlash.EnduranceFlashZero
	self.bEnduranceFadeTimer = false

	-- For flashes
	self.nLastEnduranceValue = 0

	-- todo: make this selective
	self.wndEndurance:Show(false, true)

	self.xmlDoc = nil
	self:OnFrameUpdate()
end

function HealthShieldBar:OnFrameUpdate()
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then
		return
	end

	-- Evades
	local nEvadeCurr = unitPlayer:GetResource(knEvadeResource)
	local nEvadeMax = unitPlayer:GetMaxResource(knEvadeResource)
	self:UpdateEvades(nEvadeCurr, nEvadeMax)

	-- Evade Blocker
	-- TODO: Store this and only update when needed
	local bShowDoubleTapToDash = Apollo.GetConsoleVariable("player.showDoubleTapToDash")
	local bSettingDoubleTapToDash = Apollo.GetConsoleVariable("player.doubleTapToDash")

	self.wndDisableDash:Show(bShowDoubleTapToDash)
	self.wndEndurance:FindChild("EvadeFlashSprite"):Show(bShowDoubleTapToDash and bSettingDoubleTapToDash)
	self.wndEndurance:FindChild("EvadeDisabledBlocker"):Show(bShowDoubleTapToDash and not bSettingDoubleTapToDash)
	self.wndDisableDash:FindChild("DisableDashToggleFlash"):Show(bShowDoubleTapToDash and not bSettingDoubleTapToDash)
	self.wndDisableDash:FindChild("DisableDashToggle"):SetCheck(bShowDoubleTapToDash and not bSettingDoubleTapToDash)
	self.wndDisableDash:SetTooltip(bSettingDoubleTapToDash and Apollo.GetString("HealthBar_DisableDoubleTapEvades") or Apollo.GetString("HealthBar_EnableDoubletapTooltip"))

	-- Show/Hide EnduranceEvade UI
	if self.bInCombat or nRunCurr ~= nRunMax or nEvadeCurr ~= nEvadeMax or bShowDoubleTapToDash then
		Apollo.StopTimer("EnduranceDisplayTimer")
		self.bEnduranceFadeTimer = false
		self.wndEndurance:Show(true, true)
	elseif not self.bEnduranceFadeTimer then
		Apollo.StopTimer("EnduranceDisplayTimer")
		Apollo.StartTimer("EnduranceDisplayTimer")
		self.bEnduranceFadeTimer = true
	end
	
	--Toggle Visibility based on ui preference
	local unitPlayer = GameLib.GetPlayerUnit()
	local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")
	
	if nVisibility == 1 then --always on
		self.wndMain:Show(true)
	elseif nVisibility == 2 then --always off
		self.wndMain:Show(false)
	elseif nVisibility == 3 then --on in combat
		self.wndMain:Show(unitPlayer:IsInCombat())	
	elseif nVisibility == 4 then --on out of combat
		self.wndMain:Show(not unitPlayer:IsInCombat())
	else
		self.wndMain:Show(false)
	end
	
	--hide evade UI while in a vehicle.
	if unitPlayer:IsInVehicle() then
		self.wndMain:Show(false)
	end
end

function HealthShieldBar:UpdateEvades(nEvadeValue, nEvadeMax)
	local strSpriteFull = "spr_HUD_Dodge2"
	local nMaxTick = math.floor(nEvadeMax/100)
	local nMaxState = eEnduranceFlash.EnduranceFlashTwo

	if nMaxTick == 3 then
		strSpriteFull = "spr_HUD_Dodge3"
		nMaxState = eEnduranceFlash.EnduranceFlashThree
	end
	
	local nTickValue = nEvadeValue % 100 == 0 and 100 or nEvadeValue % 100
	self.wndEndurance:FindChild("EvadeProgress"):SetMax(100)
	self.wndEndurance:FindChild("EvadeProgress"):SetProgress(nTickValue)

	if nEvadeValue >= nEvadeMax then -- all full
		self.wndEndurance:FindChild("EvadeFullSprite"):SetSprite(strSpriteFull)

		if self.nEnduranceState ~= nMaxState then
			self.nEnduranceState = nMaxState
			self.wndEndurance:FindChild("EvadeFlashSprite"):SetSprite("sprResourceBar_DodgeFlashFull")
		end
	elseif math.floor(nEvadeValue/100) < 1 then -- none ready
		self.wndEndurance:FindChild("EvadeFullSprite"):SetSprite("")

		if self.nEnduranceState ~= eEnduranceFlash.EnduranceFlashZero then
			self.nEnduranceState = eEnduranceFlash.EnduranceFlashZero
			self.wndEndurance:FindChild("EvadeFlashSprite"):SetSprite("sprResourceBar_DodgeFlashHalf")
		end
	else -- one ready, one filling
		if nMaxState == eEnduranceFlash.EnduranceFlashThree then
			if nEvadeValue >= 200 and nEvadeValue < 300 then
				self.wndEndurance:FindChild("EvadeFullSprite"):SetSprite("spr_HUD_Dodge2")
				if self.nEnduranceState ~= eEnduranceFlash.EnduranceFlashTwo then
					if self.nEnduranceState == eEnduranceFlash.EnduranceFlashThree then
						self.wndEndurance:FindChild("EvadeFlashSprite"):SetSprite("sprResourceBar_DodgeFlashFull")
					else
						self.wndEndurance:FindChild("EvadeFlashSprite"):SetSprite("sprResourceBar_DodgeFlashHalf")
					end
					self.nEnduranceState = eEnduranceFlash.EnduranceFlashTwo
				end
			elseif nEvadeValue >= 100 and nEvadeValue < 200 then
				self.wndEndurance:FindChild("EvadeFullSprite"):SetSprite("spr_HUD_Dodge1")
				if self.nEnduranceState ~= eEnduranceFlash.EnduranceFlashOne then
					self.wndEndurance:FindChild("EvadeFlashSprite"):SetSprite("sprResourceBar_DodgeFlashHalf")
					self.nEnduranceState = eEnduranceFlash.EnduranceFlashOne
				end
			else
				self.wndEndurance:FindChild("EvadeFullSprite"):SetSprite("")
			end
		else
			self.wndEndurance:FindChild("EvadeFullSprite"):SetSprite("spr_HUD_Dodge1")
			if self.nEnduranceState == eEnduranceFlash.EnduranceFlashZero then
				self.nEnduranceState = eEnduranceFlash.EnduranceFlashOne
				self.wndEndurance:FindChild("EvadeFlashSprite"):SetSprite("sprResourceBar_DodgeFlashHalf")
			elseif self.nEnduranceState == eEnduranceFlash.EnduranceFlashTwo then
				self.nEnduranceState = eEnduranceFlash.EnduranceFlashOne
				self.wndEndurance:FindChild("EvadeFlashSprite"):SetSprite("sprResourceBar_DodgeFlashFull")
			end
		end
	end

	local strEvadeTooltop = Apollo.GetString(Apollo.GetConsoleVariable("player.doubleTapToDash") and "HealthBar_EvadeDoubleTapTooltip" or "HealthBar_EvadeKeyTooltip")
	local strDisplayTooltip = String_GetWeaselString(strEvadeTooltop, math.floor(nEvadeValue / 100), math.floor(nEvadeMax / 100))
	self.wndEndurance:FindChild("EvadeFullSprite"):SetTooltip(strDisplayTooltip)

	self.nLastEnduranceValue = nEvadeValue
end

function HealthShieldBar:OnEnteredCombat(unit, bInCombat)
	if unit == GameLib.GetPlayerUnit() then
		self.bInCombat = bInCombat
	end
end

function HealthShieldBar:OnEnduranceDisplayTimer()
	self.bEnduranceFadeTimer = false
	self.wndEndurance:Show(false)
end

function HealthShieldBar:OnMouseButtonDown(wnd, wndControl, iButton, nX, nY, bDouble)
	if iButton == 0 then -- Left Click
		GameLib.SetTargetUnit(GameLib.GetPlayerUnit())
	end
	return true -- stop propogation
end

function HealthShieldBar:OnDisableDashToggle(wndHandler, wndControl)
	Apollo.SetConsoleVariable("player.doubleTapToDash", not wndControl:IsChecked())
	self.wndEndurance:FindChild("EvadeDisabledBlocker"):Show(not wndControl:IsChecked())
	self.wndEndurance:FindChild("EvadeProgress"):Show(not wndControl:IsChecked())
	self.wndDisableDash:FindChild("DisableDashToggleFlash"):Show(not wndControl:IsChecked())
	self:OnFrameUpdate()
end

function HealthShieldBar:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.DashMeter then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.ClassResource then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.HealthBar then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.ShieldBar then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

local HealthShieldBarInst = HealthShieldBar:new()
HealthShieldBarInst:Init()
