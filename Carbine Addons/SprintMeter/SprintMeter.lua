-----------------------------------------------------------------------------------------------
-- Client Lua Script for SprintMeter
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "GameLib"
require "Apollo"
require "HazardsLib"

local SprintMeter = {}
local knDashResource = 7 -- the resource hooked to dodges (TODO replace with enum)

function SprintMeter:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function SprintMeter:Init()
	Apollo.RegisterAddon(self)
end

function SprintMeter:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("SprintMeter.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function SprintMeter:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	--Apollo.RegisterEventHandler("HazardEnabled", 			"OnHazardEnable", self)
	--Apollo.RegisterEventHandler("HazardRemoved", 			"OnHazardRemove", self)
	--Apollo.RegisterEventHandler("HazardUpdated", 			"OnHazardUpdate", self)
	Apollo.RegisterEventHandler("BreathChanged",			"OnBreathChanged", self)
	Apollo.RegisterEventHandler("Breath_FlashEvent",		"OnBreath_FlashEvent", self) -- Drowning
	Apollo.RegisterEventHandler("ChangeWorld", 				"OnChangeWorld", self)
	Apollo.RegisterEventHandler("VarChange_FrameCount", 	"OnFrame", self)

	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", "OnTutorial_RequestUIAnchor", self)

	Apollo.RegisterTimerHandler("DashMeterGracePeriod", 	"OnDashMeterGracePeriod", self)
	Apollo.RegisterTimerHandler("SprintMeterGracePeriod", 	"OnSprintMeterGracePeriod", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "SprintMeterFormVert", "InWorldHudStratum", self)
	self.xmlDoc = nil

	self.tWindowMap =
	{
		["Backer"]						= 	self.wndMain:FindChild("Backer"),
		["ActiveIcon"]					=	self.wndMain:FindChild("ActiveIcon"),
		["SprintBG"]					=	self.wndMain:FindChild("SprintBG"),
		["SprintProgBar"]				=	self.wndMain:FindChild("SprintBG"):FindChild("ProgBar"),
		["SprintProgFlash"]				=	self.wndMain:FindChild("SprintBG"):FindChild("ProgFlash"),
		["DashBG"]						=	self.wndMain:FindChild("DashBG"),
		["DashProg1"]					=	self.wndMain:FindChild("DashBG"):FindChild("DashProg1"),
		["DashProg2"]					=	self.wndMain:FindChild("DashBG"):FindChild("DashProg2"),
		["DashProgFlash1"]				=	self.wndMain:FindChild("DashBG"):FindChild("DashProgFlash1"),
		["DashProgFlash2"]				=	self.wndMain:FindChild("DashBG"):FindChild("DashProgFlash2"),
		["HazardsArrangeHorz"]			=	self.wndMain:FindChild("HazardsArrangeHorz"),
		["HazardsRadiationMain"]		=	self.wndMain:FindChild("HazardsRadiationMain"),
		["HazardsRadiationProgBar"]		=	self.wndMain:FindChild("HazardsRadiationMain"):FindChild("HazardsProgBar"),
		["HazardsRadiationProgFlash"]	=	self.wndMain:FindChild("HazardsRadiationMain"):FindChild("HazardsProgFlash"),
		["HazardsRadiationText"]		=	self.wndMain:FindChild("HazardsRadiationMain"):FindChild("HazardsText"),
		["HazardsTemperatureMain"]		=	self.wndMain:FindChild("HazardsTemperatureMain"),
		["HazardsTemperatureProgBar"]	=	self.wndMain:FindChild("HazardsTemperatureMain"):FindChild("HazardsProgBar"),
		["HazardsTemperatureProgFlash"]	=	self.wndMain:FindChild("HazardsTemperatureMain"):FindChild("HazardsProgFlash"),
		["HazardsTemperatureText"]		=	self.wndMain:FindChild("HazardsTemperatureMain"):FindChild("HazardsText"),
		["HazardsBreathMain"]			=	self.wndMain:FindChild("HazardsBreathMain"),
		["HazardsBreathProgBar"]		=	self.wndMain:FindChild("HazardsBreathMain"):FindChild("HazardsProgBar"),
		["HazardsBreathProgFlash"]		=	self.wndMain:FindChild("HazardsBreathMain"):FindChild("HazardsProgFlash"),
		["HazardsBreathText"]			=	self.wndMain:FindChild("HazardsBreathMain"):FindChild("HazardsText"),
	}
	self.tWindowMap["DashBG"]:Show(false, true)
	self.tWindowMap["SprintBG"]:Show(false, true)
	self.tWindowMap["ActiveIcon"]:Show(false, true)

	self.bIsMoveable = nil
	self.bJustFilledDash = false
	self.bJustFilledSprint = false
	self.nLastDashValue = 0
	self.nLastSprintValue = 0
end

function SprintMeter:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = Apollo.GetString("SprintMeter_SprintMeter"), nSaveVersion = 3 })
end

function SprintMeter:OnFrame()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end

	local bPlayerDead = unitPlayer:IsDead()
	local nRunCurr = unitPlayer:GetResource(0)
	local nRunMax = unitPlayer:GetMaxResource(0)
	local bAtMaxSprint = nRunCurr == nRunMax or bPlayerDead

	-- Sprint
	if self.nLastSprintValue ~= nRunCurr then
		self.tWindowMap["SprintProgBar"]:SetMax(nRunMax)
		self.tWindowMap["SprintProgBar"]:SetProgress(nRunCurr, self.tWindowMap["SprintBG"]:IsVisible() and nRunMax or 0)
		self.tWindowMap["ActiveIcon"]:SetSprite(self.nLastSprintValue < nRunCurr and "IconSprites:Icon_Windows32_UI_Hazards_Sprint" or "IconSprites:Icon_Windows32_UI_Hazards_SprintFlash")
		self.nLastSprintValue = nRunCurr
	end

	if bAtMaxSprint and not self.bJustFilledSprint and self.tWindowMap["SprintBG"]:IsVisible() then
		self.bJustFilledSprint = true
		Apollo.StopTimer("SprintMeterGracePeriod")
		Apollo.CreateTimer("SprintMeterGracePeriod", 0.4, false)
		self.tWindowMap["SprintProgFlash"]:SetSprite("SprintMeter:sprVerticalBar_Flash")
	elseif not bAtMaxSprint then
		self.bJustFilledSprint = false
		Apollo.StopTimer("SprintMeterGracePeriod")
	end
	self.tWindowMap["SprintBG"]:Show(not bAtMaxSprint or self.bJustFilledSprint, not bAtMaxSprint)

	-- Dash
	local nDashCurr = unitPlayer:GetResource(knDashResource)
	local nDashMax = unitPlayer:GetMaxResource(knDashResource)
	local bAtMaxDash = nDashCurr == nDashMax or bPlayerDead
	if self.nLastDashValue ~= nDashCurr then
		local nHalfDash = nDashMax / 2
		self.tWindowMap["DashProg1"]:SetMax(nHalfDash)
		self.tWindowMap["DashProg1"]:SetProgress(nDashCurr)
		self.tWindowMap["DashProg2"]:SetMax(nHalfDash)
		self.tWindowMap["DashProg2"]:SetProgress(nDashCurr - nHalfDash)
		if nDashCurr >= nHalfDash and self.nLastDashValue < nHalfDash then
			self.tWindowMap["DashProgFlash1"]:SetSprite("SprintMeter:sprDashBot_Flash")
		end
		self.nLastDashValue = nDashCurr
	end

	if bAtMaxDash and not self.bJustFilledDash and self.tWindowMap["DashBG"]:IsVisible() then
		self.bJustFilledDash = true
		Apollo.StopTimer("DashMeterGracePeriod")
		Apollo.CreateTimer("DashMeterGracePeriod", 0.4, false)
		self.tWindowMap["DashProgFlash2"]:SetSprite("SprintMeter:sprDashTop_Flash")
	elseif not bAtMaxDash then
		self.bJustFilledDash = false
		Apollo.StopTimer("DashMeterGracePeriod")
	end
	self.tWindowMap["DashBG"]:Show(not bAtMaxDash or self.bJustFilledDash, not bAtMaxDash)

	-- Icon is shared between Dash and Sprint
	local bShowActiveIcon = not bPlayerDead and (nRunCurr < nRunMax or nDashCurr < nDashMax)
	self.tWindowMap["ActiveIcon"]:Show(bShowActiveIcon or self.bJustFilledSprint or self.bJustFilledDash, not bShowActiveIcon)

	-- Hazards
	self.tWindowMap["HazardsRadiationMain"]:Show(false)
	self.tWindowMap["HazardsTemperatureMain"]:Show(false)

	for idx, tActiveHazard in ipairs(HazardsLib.GetHazardActiveList()) do
		if tActiveHazard.eHazardType == HazardsLib.HazardType_Radiation then
			self.tWindowMap["HazardsRadiationProgBar"]:SetMax(tActiveHazard.fMaxValue)
			self.tWindowMap["HazardsRadiationProgBar"]:SetProgress(tActiveHazard.fMeterValue)
			self.tWindowMap["HazardsRadiationText"]:SetText(math.floor(math.min(99, tActiveHazard.fMeterValue / tActiveHazard.fMaxValue * 100)).."%")
			self.tWindowMap["HazardsRadiationMain"]:SetTooltip(string.len(tActiveHazard.strTooltip) > 0 and tActiveHazard.strTooltip or HazardsLib.GetHazardDisplayString(tActiveHazard.nId))
			self.tWindowMap["HazardsRadiationMain"]:Show(true)
		end
		if tActiveHazard.eHazardType == HazardsLib.HazardType_Temperature then
			self.tWindowMap["HazardsTemperatureProgBar"]:SetMax(tActiveHazard.fMaxValue)
			self.tWindowMap["HazardsTemperatureProgBar"]:SetProgress(tActiveHazard.fMeterValue)
			self.tWindowMap["HazardsTemperatureText"]:SetText(math.floor(math.min(99, tActiveHazard.fMeterValue / tActiveHazard.fMaxValue * 100)).."%")
			self.tWindowMap["HazardsTemperatureMain"]:SetTooltip(string.len(tActiveHazard.strTooltip) > 0 and tActiveHazard.strTooltip or HazardsLib.GetHazardDisplayString(tActiveHazard.nId))
			self.tWindowMap["HazardsTemperatureMain"]:Show(true)
		end
	end

	if not bPlayerDead and (self.tWindowMap["HazardsRadiationMain"]:IsShown() or self.tWindowMap["HazardsTemperatureMain"]:IsShown()) then
		self.tWindowMap["HazardsArrangeHorz"]:ArrangeChildrenHorz(2)
	end

	-- Window Management
	local bCanMove = self.wndMain:IsStyleOn("Moveable")
	if bCanMove ~= self.bIsMoveable then
		self.bIsMoveable = bCanMove
		self.wndMain:SetStyle("IgnoreMouse", not self.bIsMoveable)
		self.tWindowMap["Backer"]:Show(self.bIsMoveable)
	end
end

function SprintMeter:OnBreathChanged(nBreath)
	local nBreathMax = 100
	if nBreath == nBreathMax then
		if self.tWindowMap["HazardsBreathMain"]:IsVisible() then -- So we don't constantly arrange horz needlessly
			self.tWindowMap["HazardsBreathMain"]:Show(false)
			self.tWindowMap["HazardsArrangeHorz"]:ArrangeChildrenHorz(2)
		end
		self.tWindowMap["HazardsBreathMain"]:Show(false)
		return
	end

	self.tWindowMap["HazardsBreathProgBar"]:SetMax(nBreathMax)
	self.tWindowMap["HazardsBreathText"]:SetText(nBreath.."%")

	if not self.tWindowMap["HazardsBreathMain"]:IsVisible() then
		self.tWindowMap["HazardsBreathMain"]:Show(true)
		self.tWindowMap["HazardsBreathProgBar"]:SetProgress(nBreath)
		self.tWindowMap["HazardsArrangeHorz"]:ArrangeChildrenHorz(2)
	else
		self.tWindowMap["HazardsBreathProgBar"]:SetProgress(nBreath, nBreathMax)
	end
end

function SprintMeter:OnBreath_FlashEvent()
	self.tWindowMap["HazardsBreathProgFlash"]:SetSprite("SprintMeter:sprHazards_Flash")
end

function SprintMeter:OnSprintMeterGracePeriod()
	Apollo.StopTimer("SprintMeterGracePeriod")
	self.bJustFilledSprint = false
	self.tWindowMap["SprintBG"]:Show(false)
end

function SprintMeter:OnDashMeterGracePeriod()
	Apollo.StopTimer("DashMeterGracePeriod")
	self.bJustFilledDash = false
	self.tWindowMap["DashBG"]:Show(false)
end

function SprintMeter:OnChangeWorld()
	self.tWindowMap["HazardsBreathMain"]:Show(false)
	--self.tWindowMap["HazardsRadiationMain"]:Show(false) -- Shouldn't need this with OnFrame
	--self.tWindowMap["HazardsTemperatureMain"]:Show(false)
end

function SprintMeter:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.SprintMeter then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

local SprintMeterInst = SprintMeter:new()
SprintMeterInst:Init()
