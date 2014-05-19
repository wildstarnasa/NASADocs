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

local eHealthColor =
{
	HealthInRed = 1,
	HealthInOrange = 2,
	HealthInGreen = 3
}

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
	Apollo.RegisterTimerHandler("CCArmorBrokenDisplayTimer", 			"OnCCArmorBrokenDisplayTimer", self)
	Apollo.RegisterTimerHandler("HealthShieldBar_FlashThrottleTimer", 	"OnFlashThrottleTimer", self)	

	Apollo.RegisterSlashCommand("addon_healthwarn", "OnHealthWarnSlashCommand", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HealthShieldBar", "OnOptionsUpdated", self)
	

	Apollo.CreateTimer("HealthShieldBarTimer", 0.5, true)
	--Apollo.CreateTimer("EnduranceDisplayTimer", 30, false) --TODO: Fix(?) This is perma-killing the display when DT dashing is disabled via the toggle
	Apollo.CreateTimer("CCArmorBrokenDisplayTimer", 3, false)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "HealthShieldBarForm", "FixedHudStratum", self)

	self.wndHealth = self.wndMain:FindChild("HealthBar")
	self.wndMaxAbsorb = self.wndMain:FindChild("MaxAbsorbBar")
	self.wndMaxShield = self.wndMain:FindChild("MaxShieldBar")
	self.wndCurrShield = self.wndMain:FindChild("CurrShieldBar")
	self.wndCurrAbsorb = self.wndMain:FindChild("CurrAbsorbBar")
	self.wndFlashShield = self.wndMain:FindChild("CurrShieldFlash")
	self.wndFlashAbsorb = self.wndMain:FindChild("CurrAbsorbFlash")
	self.wndFlashHealth = self.wndMain:FindChild("HealthBarFlash")
	self.wndEndurance = self.wndMain:FindChild("EnduranceContainer")
	self.wndDisableDash = self.wndEndurance:FindChild("DisableDashToggleContainer")
	self.wndCCArmor = self.wndMain:FindChild("CCArmorContainer")

	self.nBarWidth = self.wndHealth:GetWidth()
	self.bInCombat = false
	self.fHealthWarn = 0.4
	self.fHealthWarn2 = 0.6
	self.eHealthState = eHealthColor.HealthInGreen
	self.eEnduranceState = eEnduranceFlash.EnduranceFlashZero
	self.bEnduranceFadeTimer = false
	self.bBrokenCCArmorFadeTimer = false
	self.nLastCCArmorValue = 0

	-- For flashes
	self.bHealthBarFlashes = g_InterfaceOptions.Carbine.bHealthBarFlashes
	self.bFlashThrottle = false
	self.nLastHealthCurr = -1
	self.nLastShieldCurr = -1
	self.nLastAbsorbCurr = -1
	self.nLastEnduranceValue = 0

	-- todo: make this selective
	self.wndEndurance:Show(false, true)

	self.xmlDoc = nil
	self:OnFrameUpdate()
end

function HealthShieldBar:OnOptionsUpdated()
	self.bHealthBarFlashes = g_InterfaceOptions.Carbine.bHealthBarFlashes
end

function HealthShieldBar:OnHealthWarnSlashCommand(strArg1, strArg2)
	local nArg = tonumber(strArg2) -- This slash command will change self.nHealthWarn until reloadui
	if nArg and nArg > 1 and nArg < 100 then
		self.fHealthWarn = nArg / 100
	elseif nArg and nArg < 1 and nArg > 0 then
		self.fHealthWarn = nArg
	end
end

function HealthShieldBar:OnFrameUpdate()
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then
		return
	end

	local tStats = unitPlayer:GetBasicStats()
	if tStats == nil then
		return
	end

	local nHealthMax = tStats.nMaxHealth
	local nHealthCurr = tStats.nHealth
	local nShieldMax = unitPlayer:GetShieldCapacityMax()
	local nShieldCurr = unitPlayer:IsShieldOverloaded() and nShieldMax or unitPlayer:GetShieldCapacity() -- If overloaded, use max instead (for art reasons)
	local nAbsorbMax = unitPlayer:GetAbsorptionMax()
	local nAbsorbCurr = nAbsorbMax > 0 and unitPlayer:GetAbsorptionValue() or 0
	local nTotalMax = nHealthMax + nShieldMax + nAbsorbMax

	-- Shield, Absorb, and Health Flash (Before Resizing) TODO: FIX THIS OPTION
	if self.bHealthBarFlashes then
		if self.nLastShieldCurr < nShieldCurr and nShieldCurr == nShieldMax then
			self.wndFlashShield:SetSprite("sprResourceBar_ShieldFlash")
		end

		if self.nLastShieldCurr > 0 and self.nLastShieldCurr > nShieldCurr and not self.bFlashThrottle then
			self.bFlashThrottle = true
			Apollo.CreateTimer("HealthShieldBar_FlashThrottleTimer", 3, false)
			self.wndFlashShield:SetSprite("sprResourceBar_ShieldFlash")
		end
		self.nLastShieldCurr = nShieldCurr

		if self.nLastAbsorbCurr > 0 and self.nLastAbsorbCurr > nAbsorbCurr and not self.bFlashThrottle then
			self.bFlashThrottle = true
			Apollo.CreateTimer("HealthShieldBar_FlashThrottleTimer", 3, false)
			self.wndFlashAbsorb:SetSprite("sprResourceBar_ShieldFlash")
		end
		self.nLastAbsorbCurr = nAbsorbCurr

		if self.nLastHealthCurr > 0 and self.nLastHealthCurr > nHealthCurr and not self.bFlashThrottle then
			self.bFlashThrottle = true
			Apollo.CreateTimer("HealthShieldBar_FlashThrottleTimer", 1.5, false)
			self.wndFlashHealth:SetSprite("ClientSprites:WhiteFlash")
		end
		self.nLastHealthCurr = nHealthCurr
	end

	-- Text Labels
	local strHealthText = nHealthCurr == nHealthMax and tostring(nHealthMax) or String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), nHealthCurr, nHealthMax)
	local strShieldText = ""
	if nShieldCurr ~= 0 and nShieldMax ~= 0 and nShieldCurr ~= nShieldMax then
		strShieldText = String_GetWeaselString(Apollo.GetString("HealthBar_HealthTextPartialShield"), strHealthText, nShieldCurr, nShieldMax)
	elseif nShieldCurr ~= 0 and nShieldMax ~= 0 then
		strShieldText = String_GetWeaselString(Apollo.GetString("HealthBar_HealthTextFullShield"), strHealthText, nShieldMax)
	end
	self.wndMain:FindChild("HealthText"):SetText((nShieldCurr == 0 or nShieldMax == 0) and strHealthText or strShieldText)

	-- Tooltips
	if nShieldCurr > nShieldMax then
		nShieldCurr = nShieldMax
	end
	
	local strHealthTooltip = String_GetWeaselString(Apollo.GetString("HealthBar_Health"), nHealthCurr, nHealthMax)
	local strShieldTooltip = String_GetWeaselString(Apollo.GetString("HealthBar_Shields"), nShieldCurr, nShieldMax)
	local strAbsorbTooltip = String_GetWeaselString(Apollo.GetString("HealthBar_Absorb"), nAbsorbCurr, nAbsorbMax)
	self.wndMain:FindChild("HealthBar"):SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>",
	String_GetWeaselString(Apollo.GetString("HealthBar_HealthShieldTooltip"), strHealthTooltip, strShieldTooltip, "")))
	self.wndMain:FindChild("MaxShieldBar"):SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>",
	String_GetWeaselString(Apollo.GetString("HealthBar_HealthShieldTooltip"), strShieldTooltip, strHealthTooltip, "")))
	self.wndMain:FindChild("MaxAbsorbBar"):SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>",
	String_GetWeaselString(Apollo.GetString("HealthBar_HealthShieldTooltip"), strAbsorbTooltip, strShieldTooltip, strHealthTooltip)))

	-- Bars
	self.wndHealth:Show(nHealthCurr > 0)
	self.wndMaxShield:Show(nHealthCurr > 0)
	self.wndCurrShield:Show(nHealthCurr > 0)
	self.wndMaxAbsorb:Show(nHealthCurr > 0 and nAbsorbMax > 0)

	-- Health Bar Color
	if (nHealthCurr / nHealthMax) < self.fHealthWarn then
		if self.eHealthState ~= eHealthColor.HealthInRed then
			self.eHealthState = eHealthColor.HealthInRed
			self.wndHealth:SetSprite("sprResourceBar_RedProgBar")
			self.wndMain:FindChild("HealthBarEdgeGlow"):SetSprite("sprResourceBar_RedEdgeGlow")
		end
	elseif (nHealthCurr / nHealthMax) < self.fHealthWarn2 then
		if self.eHealthState ~= eHealthColor.HealthInOrange then
			self.eHealthState = eHealthColor.HealthInOrange
			self.wndHealth:SetSprite("sprResourceBar_OrangeProgBar")
			self.wndMain:FindChild("HealthBarEdgeGlow"):SetSprite("sprResourceBar_OrangeEdgeGlow")
		end
	else
		if self.eHealthState ~= eHealthColor.HealthInGreen then
			self.eHealthState = eHealthColor.HealthInGreen
			self.wndHealth:SetSprite("sprResourceBar_GreenProgBar")
			self.wndMain:FindChild("HealthBarEdgeGlow"):SetSprite("sprResourceBar_GreenEdgeGlow")
		end
	end

	-- Scaling
	local nPointHealthRight = self.nBarWidth * (nHealthCurr / nTotalMax)
	local nPointShieldMid 	= self.nBarWidth * ((nHealthCurr + nShieldCurr) / nTotalMax)
	local nPointShieldRight = self.nBarWidth * ((nHealthCurr + nShieldMax) / nTotalMax)
	local nPointAbsorbMid 	= self.nBarWidth * ((nHealthCurr + nShieldMax + nAbsorbCurr) / nTotalMax)
	local nPointAbsorbRight = self.nBarWidth * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax)

	if nShieldMax > 0 and nShieldMax / nTotalMax < 0.1 then
		local nMinShieldSize = 0.1 -- HARDCODE: Minimum shield bar length for formatting
		nPointHealthRight = self.nBarWidth * math.min(1 - nMinShieldSize, nHealthCurr / nTotalMax) -- Health is normal, but caps at nMinShieldSize
		nPointShieldRight = self.nBarWidth * math.min(1, (nHealthCurr / nTotalMax) + nMinShieldSize) -- If not 1, the size is thus healthbar + hard minimum
	end

	self.wndMain:FindChild("HealthBarEdgeGlow"):Show(nShieldMax ~= 0)
	self.wndCurrShield:FindChild("ShieldBarEdgeGlow"):Show(nShieldCurr < nShieldMax or nAbsorbMax > 0)
	self.wndCurrAbsorb:FindChild("AbsorbBarEdgeGlow"):Show(nAbsorbMax > 0 and nAbsorbCurr < nAbsorbMax)

	self.wndHealth:SetAnchorOffsets(0, 0, nPointHealthRight, 0)

	self.wndCurrShield:SetAnchorOffsets(nPointHealthRight, 0, nPointShieldMid, 0)
	self.wndFlashShield:SetAnchorOffsets(nPointHealthRight, 0, nPointShieldMid, 0)
	self.wndMaxShield:SetAnchorOffsets(nPointHealthRight, 0, nPointShieldRight, 0)

	self.wndCurrAbsorb:SetAnchorOffsets(nPointShieldRight, 0, nPointAbsorbMid, 0)
	self.wndFlashAbsorb:SetAnchorOffsets(nPointShieldRight, 0, nPointAbsorbMid, 0)
	self.wndMaxAbsorb:SetAnchorOffsets(nPointShieldRight, 0, nPointAbsorbRight, 0)

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

	--Interrupt Armor
	self:UpdateCCArmor(unitPlayer:GetInterruptArmorValue(), unitPlayer:GetInterruptArmorMax())
	
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

function HealthShieldBar:UpdateCCArmor(nCurr, nMax)
	if nMax == 0 and self.nLastCCArmorValue == 0 and not self.bBrokenCCArmorFadeTimer then
		self.wndCCArmor:Show(false)
		return
	else
		self.wndCCArmor:Show(true, true)
	end

	-- States
	if nMax == -1 then -- impervious
		self.wndCCArmor:SetSprite("sprResourceBar_InterruptFullShield")
		self.wndCCArmor:FindChild("CCRing"):SetSprite("")
		self.wndCCArmor:FindChild("CCText"):SetText("")
	elseif nCurr == 0 and nMax > 0 then -- just broke
		self.wndCCArmor:SetSprite("sprResourceBar_InterruptBroken")
		self.wndCCArmor:FindChild("CCRing"):SetSprite("sprResourceBar_InterruptCircleRed")
		self.wndCCArmor:FindChild("CCText"):SetText("")
		self.wndCCArmor:FindChild("CCArmorFlash"):SetSprite("sprResourceBar_InterruptCircleFlash")
		self.bBrokenCCArmorFadeTimer = true

		Apollo.StopTimer("CCArmorBrokenDisplayTimer")
		Apollo.StartTimer("CCArmorBrokenDisplayTimer")
	elseif nMax > 0 then -- have armor
		self.wndCCArmor:SetSprite("sprResourceBar_InterruptBG")
		self.wndCCArmor:FindChild("CCRing"):SetSprite("sprResourceBar_InterruptCircleBlue")
		self.wndCCArmor:FindChild("CCText"):SetText(nCurr)
		self.bBrokenCCArmorFadeTimer = false
	end

	if nCurr < self.nLastCCArmorValue and nCurr ~= 0 and nCurr ~= -1 then
		self.wndCCArmor:FindChild("CCArmorFlash"):SetSprite("sprResourceBar_InterruptCircleFlash")
	end

	self.nLastCCArmorValue = nCurr
end

function HealthShieldBar:OnEnteredCombat(unit, bInCombat)
	if unit == GameLib.GetPlayerUnit() then
		self.bInCombat = bInCombat
	end
end

function HealthShieldBar:OnCCArmorBrokenDisplayTimer()
	self.bBrokenCCArmorFadeTimer = false
end

function HealthShieldBar:OnFlashThrottleTimer()
	self.bFlashThrottle = false
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
