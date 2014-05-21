-----------------------------------------------------------------------------------------------
-- Client Lua Script for Warplots
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "PublicEvent"

local Warplots = {}

local LuaEnumBlueTeamInfo =
{
	Energy 			= 1495,
	Nanopacks 		= 2463,
	GeneratorNorth 	= 1387,
	GeneratorSouth 	= 1388,
}

local LuaEnumRedTeamInfo = 
{
	Energy 			= 1494,
	Nanopacks 		= 2441,
	GeneratorNorth 	= 1389,
	GeneratorSouth 	= 1390,
}

local LuaEnumControlPoints =
{
	BlueNorth 	= 1605,
	RedNorth 	= 1606,
	Center 		= 1607,
	BlueSouth 	= 1608,
	RedSouth 	= 1609,
}


function Warplots:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Warplots:Init()
	Apollo.RegisterAddon(self)
end

function Warplots:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Warplots.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Warplots:OnDocumentReady()
	if not self.xmlDoc then
		return
	end
	
	Apollo.RegisterTimerHandler("WarPlot_OneSecMatchTimer", "OnWarPlotOneSecMatchTimer", self)
	
	Apollo.RegisterEventHandler("ChangeWorld", 				"OnChangeWorld", self)
	Apollo.RegisterEventHandler("PublicEventStart",			"CheckForWarplot", self)
	Apollo.RegisterEventHandler("MatchEntered", 			"CheckForWarplot", self)
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "WarplotsMain", "FixedHudStratumLow", self)
	self.wndMain:Show(false)
	
	self.wndRedBar = self.wndMain:FindChild("RedBar")
	self.wndBlueBar = self.wndMain:FindChild("BlueBar")
	
	self.wndRedGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Generator1"), self)
	self.wndRedGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Generator2"), self)
	self.wndBlueGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Generator1"), self)
	self.wndBlueGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Generator2"), self)
	
	Apollo.CreateTimer("WarPlot_OneSecMatchTimer", 1.0, true)
	Apollo.StopTimer("WarPlot_OneSecMatchTimer")
	
	self.tBlueInfo = {}
	self.tRedInfo = {}
	self.tControlPointInfo = {}
	self.peMatch = nil
	
	if MatchingGame.IsInMatchingGame() or MatchingGame.IsInPVPGame() then
		self:CheckForWarplot()
	end
end

function Warplots:OnChangeWorld()
	self.wndMain:Show(false)
	Apollo.StopTimer("WarPlot_OneSecMatchTimer")
	self.peMatch = nil
end

function Warplots:OnWarPlotOneSecMatchTimer()	
	if not self.peMatch then
		self:CheckForWarplot()
		return
	end
	
	self.wndMain:Show(true)
	
	-- Building Red Team's Info
	self:DrawEnergy(self.tRedInfo[LuaEnumRedTeamInfo.Energy], self.wndRedBar, self.wndMain:FindChild("Red:CurrentProgress"))
	self.wndMain:FindChild("Red:CurrencyValue"):SetText(self.tRedInfo[LuaEnumRedTeamInfo.Nanopacks]:GetCount()) -- Nanopacks
	self:DrawGenerator(self.tRedInfo[LuaEnumRedTeamInfo.GeneratorNorth], self.wndRedGeneratorN, "Red")
	self:DrawGenerator(self.tRedInfo[LuaEnumRedTeamInfo.GeneratorSouth], self.wndRedGeneratorS, "Red")
	
	-- Building Blue Team's Info
	self:DrawEnergy(self.tBlueInfo[LuaEnumBlueTeamInfo.Energy], self.wndBlueBar, self.wndMain:FindChild("Blue:CurrentProgress"))
	self.wndMain:FindChild("Blue:CurrencyValue"):SetText(self.tBlueInfo[LuaEnumBlueTeamInfo.Nanopacks]:GetCount()) -- Nanopacks
	self:DrawGenerator(self.tBlueInfo[LuaEnumBlueTeamInfo.GeneratorNorth], self.wndBlueGeneratorN, "Blue")
	self:DrawGenerator(self.tBlueInfo[LuaEnumBlueTeamInfo.GeneratorSouth], self.wndBlueGeneratorS, "Blue")
	
	-- Draw Control Points
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.BlueNorth], self.wndMain:FindChild("BlueN"), 1)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.RedNorth], self.wndMain:FindChild("RedN"), 2)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.Center], self.wndMain:FindChild("Center"), 3)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.BlueSouth], self.wndMain:FindChild("BlueS"), 4)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.RedSouth], self.wndMain:FindChild("RedS"), 5)
end

function Warplots:DrawEnergy(peoEnergy, wndBar, wndProgress)
	local nMaxEnergy = peoEnergy:GetRequiredCount()
	local nCurrentEnergy = peoEnergy:GetCount()
		
	wndBar:SetMax(nMaxEnergy)
	wndBar:SetProgress(nCurrentEnergy)
	wndBar:SetTooltip(string.format("%s / %s", Apollo.FormatNumber(nCurrentEnergy, 0, true), Apollo.FormatNumber(nMaxEnergy, 0, true)))
	wndProgress:SetText(Apollo.FormatNumber(nCurrentEnergy / nMaxEnergy * 100, 1, true).."%")
end

function Warplots:DrawGenerator(peoGenerator, wndParent, strTeamColor)
	local nCurrentHP = peoGenerator:GetCount()
	local nMaxHP = peoGenerator:GetRequiredCount()
	local nHealthPCT = nCurrentHP / nMaxHP * 100
	local wndHealth = wndParent:FindChild("HealthTint")
			
	wndParent:Show(true)
			
	if nCurrentHP > 0 then
		wndParent:SetSprite(nHealthPCT > 20 and "spr_WarPlots_Generator_" .. strTeamColor or "anim_WarPlots_Generator_" .. strTeamColor)
		wndParent:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 1, true).."%")
	else
		wndParent:SetSprite("spr_WarPlots_Generator_Inactive")
		wndParent:FindChild("HealthValue"):SetText("")
	end
			
	wndHealth:SetMax(100)
	wndHealth:SetProgress(nCurrentHP)
	wndHealth:SetTooltip(Apollo.FormatNumber(nCurrentHP))
	wndHealth:SetFullSprite("spr_WarPlots_Generator_Fill" .. strTeamColor)
end

function Warplots:DrawControlPoint(peoControlPoint, wndPoint, nIndex)		
	wndPoint:SetMax(100)
	wndPoint:SetProgress(100)
	wndPoint:SetFullSprite(peoControlPoint:GetOwningTeam() == 0 and "" or peoControlPoint:GetOwningTeam() == 6 and "spr_WarPlots_CP" .. nIndex .. "_RedCap" or "spr_WarPlots_CP" .. nIndex .. "_BlueCap")
end

function Warplots:CheckForWarplot()
	if not MatchingGame:GetPVPMatchState() or self.peMatch then
		return
	end

	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		if eType == PublicEvent.PublicEventType_PVP_Warplot then
			self.peMatch = peCurrent
			
			for idx, idObjective in pairs(LuaEnumBlueTeamInfo) do
				self.tBlueInfo[idObjective] = self.peMatch:GetObjective(idObjective)
			end
			
			for idx, idObjective in pairs(LuaEnumRedTeamInfo) do
				self.tRedInfo[idObjective] = self.peMatch:GetObjective(idObjective)
			end
			
			for idx, idObjective in pairs(LuaEnumControlPoints) do
				self.tControlPointInfo[idObjective] = self.peMatch:GetObjective(idObjective)
			end
			
			Apollo.StartTimer("WarPlot_OneSecMatchTimer")
			return
		end
	end
	
	return
end

local WarplotsInstance = Warplots:new()
WarplotsInstance:Init()