-----------------------------------------------------------------------------------------------
-- Client Lua Script for Warplots
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "PublicEvent"

local Warplots = {}

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
	
	Apollo.RegisterTimerHandler("WarPlot_OneSecLoadTimer", 	"OnWarPlotOneSecLoadTimer", self)
	Apollo.RegisterEventHandler("ChangeWorld", 				"OnChangeWorld", self) -- From code
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "WarplotsMain", nil, self)
	self.wndMain:Show(false)
	
	self.wndRedBar = self.wndMain:FindChild("RedBar")
	self.wndBlueBar = self.wndMain:FindChild("BlueBar")
	
	self.wndRedGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Generator1"), self)
	self.wndRedGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Generator2"), self)
	self.wndBlueGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Generator1"), self)
	self.wndBlueGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Generator2"), self)
	
	Apollo.CreateTimer("WarPlot_OneSecLoadTimer", 1.0, false)
	Apollo.CreateTimer("WarPlot_OneSecMatchTimer", 2.0, true)
	Apollo.StopTimer("WarPlot_OneSecMatchTimer")
end

function Warplots:OnChangeWorld()
	if self:CheckForWarplot() == nil then
		Apollo.StopTimer("WarPlot_OneSecMatchTimer")
		self.wndMain:Show(false)
	else
		Apollo.StartTimer("WarPlot_OneSecMatchTimer")
		Apollo.RegisterTimerHandler("WarPlot_OneSecMatchTimer", "OnWarPlot_OneSecMatchTimer", self)
	end
end

function Warplots:OnWarPlotOneSecLoadTimer()
	self:OnChangeWorld()
	
	Apollo.StopTimer("OnWarPlot_OneSecLoadTimer")
end

function Warplots:OnWarPlot_OneSecMatchTimer()
	if self.peMatch == nil then
		self.peMatch = self:CheckForWarplot()
		self.arPeObjectives = self:CheckForWarplotObjectives(self.peMatch)
	end
	
	if not self.peMatch or not self.arPeObjectives then
		return
	end
	
	self.wndMain:Show(true)
	
	for idx, peoCurrent in pairs(self.arPeObjectives) do
		local eObjectiveType = peoCurrent:GetObjectiveType()
		local eObjectiveId = peoCurrent:GetObjectiveId()
		local nCurrValue = peoCurrent:GetCount()
		local nMaxValue = peoCurrent:GetRequiredCount()
		
		local bTeamName = Apollo.GetString(peoCurrent:GetTeam() == self.peMatch:GetJoinedTeam() and "MatchTracker_MyTeam" or "MatchTracker_EnemyTeam")
		local rTeamName = Apollo.GetString(peoCurrent:GetTeam() == self.peMatch:GetJoinedTeam() and "MatchTracker_MyTeam" or "MatchTracker_EnemyTeam")
			
		if eObjectiveId == 1494 then --Red Energy
			self.wndRedBar:SetMax(nMaxValue)
			self.wndRedBar:SetProgress(nCurrValue)
			self.wndRedBar:SetTooltip(string.format("%s / %s", Apollo.FormatNumber(nCurrValue, 0, true), Apollo.FormatNumber(nMaxValue, 0, true)))
			self.wndMain:FindChild("Red:CurrentProgress"):SetText(Apollo.FormatNumber(nCurrValue / nMaxValue * 100, 1, true).."%")
		elseif eObjectiveId == 1495 then --Blue Energy
			self.wndBlueBar:SetMax(nMaxValue)
			self.wndBlueBar:SetProgress(nCurrValue)
			self.wndBlueBar:SetTooltip(string.format("%s / %s", Apollo.FormatNumber(nCurrValue, 0, true), Apollo.FormatNumber(nMaxValue, 0, true)))
			self.wndMain:FindChild("Blue:CurrentProgress"):SetText(Apollo.FormatNumber(nCurrValue / nMaxValue * 100, 1, true).."%")
		elseif eObjectiveId == 2441 then --Red Nano
			self.wndMain:FindChild("Red:CurrencyValue"):SetText(nCurrValue)-- .. " - ".. rTeamName)
		elseif eObjectiveId == 2463 then --Blue Nano
			self.wndMain:FindChild("Blue:CurrencyValue"):SetText(nCurrValue)-- .. " - " .. nCurrValue)
		elseif eObjectiveId == 1605 then --Blue North CP
			local wndCP = self.wndMain:FindChild("BlueN")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == self.peMatch:GetJoinedTeam() and "HologramSprites:HoloIndicator_Green" or "HologramSprites:HoloIndicator_Red")
		elseif eObjectiveId == 1606 then --Red North CP
			local wndCP = self.wndMain:FindChild("RedN")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == self.peMatch:GetJoinedTeam() and "HologramSprites:HoloIndicator_Green" or "HologramSprites:HoloIndicator_Red")
		elseif eObjectiveId == 1607 then --Center CP
			local wndCP = self.wndMain:FindChild("Center")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == self.peMatch:GetJoinedTeam() and "HologramSprites:HoloIndicator_Green" or "HologramSprites:HoloIndicator_Red")
		elseif eObjectiveId == 1608 then --Blue South CP
			local wndCP = self.wndMain:FindChild("BlueS")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == self.peMatch:GetJoinedTeam() and "HologramSprites:HoloIndicator_Green" or "HologramSprites:HoloIndicator_Red")
		elseif eObjectiveId == 1609 then --Red South CP
			local wndCP = self.wndMain:FindChild("RedS")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == self.peMatch:GetJoinedTeam() and "HologramSprites:HoloIndicator_Green" or "HologramSprites:HoloIndicator_Red")			
		elseif eObjectiveId == 1387 then --Blue Generator N
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndBlueGeneratorN:FindChild("HealthTint")
			
			self.wndBlueGeneratorN:Show(true)
			self.wndBlueGeneratorN:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 0, true).."%")
			
			wndHealth:SetMax(nMaxValue)
			wndHealth:SetProgress(nCurrValue)
			
			if (nHealthPCT) <= 30 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthRed")
			elseif (nHealthPCT) <= 50 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthYellow")
			else
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthGreen")
			end
		elseif eObjectiveId == 1388 then --Blue Generator S
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndBlueGeneratorS:FindChild("HealthTint")
			
			self.wndBlueGeneratorS:Show(true)
			self.wndBlueGeneratorS:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 0, true).."%")
			
			wndHealth:SetMax(nMaxValue)
			wndHealth:SetProgress(nCurrValue)
			
			if (nHealthPCT) <= 30 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthRed")
			elseif (nHealthPCT) <= 50 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthYellow")
			else
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthGreen")
			end
		elseif eObjectiveId == 1389 then --Red Generator N
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndRedGeneratorN:FindChild("HealthTint")
			
			self.wndRedGeneratorN:Show(true)
			self.wndRedGeneratorN:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 0, true).."%")
			
			wndHealth:SetMax(nMaxValue)
			wndHealth:SetProgress(nCurrValue)
			
			if (nHealthPCT) <= 30 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthRed")
			elseif (nHealthPCT) <= 50 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthYellow")
			else
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthGreen")
			end
		elseif eObjectiveId == 1390 then --Red Generator S
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndRedGeneratorS:FindChild("HealthTint")
			
			self.wndRedGeneratorS:Show(true)
			self.wndRedGeneratorS:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 0, true).."%")
			
			wndHealth:SetMax(nMaxValue)
			wndHealth:SetProgress(nCurrValue)
			
			if (nHealthPCT) <= 30 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthRed")
			elseif (nHealthPCT) <= 50 then
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthYellow")
			else
				wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthGreen")
			end
		end
	end
end

function Warplots:OnViewEventStatsBtn(wndHandler, wndControl) -- ViewEventStatsBtn
	for idx, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		if peCurrent:HasLiveStats() then
			local eType = peCurrent:GetEventType()
			if eType == PublicEvent.PublicEventType_PVP_Warplot or eType == PublicEvent.PublicEventType_PVP_Battleground_Vortex or eType == PublicEvent.PublicEventType_PVP_Arena
			or eType == PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine or eType == PublicEvent.PublicEventType_PVP_Battleground_Sabotage
			or eType == PublicEvent.PublicEventType_PVP_Battleground_Cannon then
				local tLiveStats = peCurrent:GetLiveStats()
				Event_FireGenericEvent("GenericEvent_OpenEventStats", peCurrent, peCurrent:GetMyStats(), tLiveStats.arTeamStats, tLiveStats.arParticipantStats)
				return
			end
		end
	end
end

function Warplots:CheckForWarplot()
	if not MatchingGame:GetPVPMatchState() then
		return
	end
	
	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		
		if eType == PublicEvent.PublicEventType_PVP_Warplot then
			return peCurrent
		end
	end
	
	return
end

function Warplots:CheckForWarplotObjectives( peMatch )
	if not peMatch then
		return nil
	end

	local arResult = {}
	
	table.insert(arResult, peMatch:GetObjective(1494)) -- Red Energy
	table.insert(arResult, peMatch:GetObjective(1495)) -- Blue Energy
	table.insert(arResult, peMatch:GetObjective(2441)) -- Red Nano
	table.insert(arResult, peMatch:GetObjective(2463)) -- Blue Nano
	table.insert(arResult, peMatch:GetObjective(1605)) -- Blue North CP
	table.insert(arResult, peMatch:GetObjective(1606)) -- Red North CP
	table.insert(arResult, peMatch:GetObjective(1607)) -- Center CP
	table.insert(arResult, peMatch:GetObjective(1608)) -- Blue South CP
	table.insert(arResult, peMatch:GetObjective(1609)) -- Red South CP
	table.insert(arResult, peMatch:GetObjective(1387)) -- Blue Generator N
	table.insert(arResult, peMatch:GetObjective(1388)) -- Blue Generator S
	table.insert(arResult, peMatch:GetObjective(1389)) -- Red Generator N
	table.insert(arResult, peMatch:GetObjective(1390)) -- Red Generator S
	
	-- If one of these fails then don't get any of them.
	for idx, peoCurrent in pairs(arResult) do
		if not peoCurrent then
			return nil
		end
	end
	
	return arResult
end

local WarplotsInstance = Warplots:new()
WarplotsInstance:Init()