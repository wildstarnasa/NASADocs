-----------------------------------------------------------------------------------------------
-- Client Lua Script for Sabotage
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "PublicEvent"

local Sabotage = {}

function Sabotage:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Sabotage:Init()
	Apollo.RegisterAddon(self)
end

function Sabotage:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Sabotage.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Sabotage:OnDocumentReady()
	if not self.xmlDoc then
		return
	end
	
	Apollo.RegisterTimerHandler("Sabotage_OneSecMatchTimer", "OnSabotageOneSecMatchTimer", self)
	Apollo.RegisterTimerHandler("Sabotage_LoadTimer", 		"OnSabotageLoadTimer", self)
	
	Apollo.RegisterEventHandler("MatchEntered", 			"OnSabotageLoadTimer", self)
	Apollo.RegisterEventHandler("MatchExited", 				"OnSabotageLoadTimer", self)
	Apollo.RegisterEventHandler("ChangeWorld", 				"OnChangeWorld", self)
	
	self.nLoadAttempts = 10
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "SabotageMain", "FixedHudStratumLow", self)
	self.wndMain:Show(false)
	
	self.wndRedBar = self.wndMain:FindChild("RedBar")
	self.wndBlueBar = self.wndMain:FindChild("BlueBar")
	
	self.wndRedGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Generator1"), self)
	self.wndRedGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Generator2"), self)
	self.wndBlueGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Generator1"), self)
	self.wndBlueGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Generator2"), self)
	
	Apollo.CreateTimer("Sabotage_LoadTimer", 0.5, false)
	Apollo.CreateTimer("Sabotage_OneSecMatchTimer", 1.0, true)
	
	Apollo.StopTimer("Sabotage_OneSecMatchTimer")
	
	if MatchingGame.IsInMatchingGame() or MatchingGame.IsInPVPGame() then
		self:OnSabotageLoadTimer()
	end
end

function Sabotage:OnChangeWorld()
	self:HideEverything()
	self.nLoadAttempts = 10
	Apollo.StartTimer("Sabotage_LoadTimer")
end

function Sabotage:OnSabotageLoadTimer()
	if not self:CheckForSabotage() then
		if self.nLoadAttempts > 0 then
			Apollo.StartTimer("Sabotage_LoadTimer")
		end
		
		self.nLoadAttempts = self.nLoadAttempts - 1
		self:HideEverything()
	else
		Apollo.StopTimer("Sabotage_LoadTimer")
		Apollo.StartTimer("Sabotage_OneSecMatchTimer")
	end
end

function Sabotage:OnSabotageOneSecMatchTimer()
	if not self.peMatch then
		self.peMatch = self:CheckForSabotage()
		self.arPeObjectives = self:CheckForSabotageObjectives(self.peMatch)
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
		
		if eObjectiveId == 1710 then --Dominion Generator
			self.wndRedBar:SetMax(nMaxValue)
			self.wndRedBar:SetProgress(nCurrValue)
			
			self.wndMain:FindChild("Red:CurrentProgress"):SetText(Apollo.FormatNumber(nCurrValue / nMaxValue * 100, 1, true).."%")
		elseif eObjectiveId == 1711 then --Exile Generator
			self.wndBlueBar:SetMax(nMaxValue)
			self.wndBlueBar:SetProgress(nCurrValue)
			
			self.wndMain:FindChild("Blue:CurrentProgress"):SetText(Apollo.FormatNumber(nCurrValue / nMaxValue * 100, 1, true).."%")
		elseif eObjectiveId == 1415 then --Center CP
			local wndCP = self.wndMain:FindChild("Center")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == 5 and "spr_WarPlots_CP3_RedCap" or "spr_WarPlots_CP3_BlueCap")
		elseif eObjectiveId == 1416 then --East CP
			local wndCP = self.wndMain:FindChild("East")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == 5 and "spr_WarPlots_CP4_RedCap" or "spr_WarPlots_CP4_BlueCap")
		elseif eObjectiveId == 1417 then --West CP
			local wndCP = self.wndMain:FindChild("West")
			
			wndCP:SetMax(100)
			wndCP:SetProgress(100)
			wndCP:SetFullSprite(peoCurrent:GetOwningTeam() == 0 and "" or peoCurrent:GetOwningTeam() == 5 and "spr_WarPlots_CP2_RedCap" or "spr_WarPlots_CP2_BlueCap")
		elseif eObjectiveId == 1839 then -- Exile Bomb
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndBlueGeneratorN:FindChild("HealthTint")
			
			self.wndBlueGeneratorN:Show(true)
			
			if nCurrValue > 0 then
				self.wndBlueGeneratorN:SetSprite(nHealthPCT > 20 and "spr_WarPlots_Generator_Blue" or "anim_WarPlots_Generator_Blue")
				self.wndBlueGeneratorN:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 1, true).."%")
			else
				self.wndBlueGeneratorN:SetSprite("spr_WarPlots_Generator_Inactive")
				self.wndBlueGeneratorN:FindChild("HealthValue"):SetText("")
			end
			
			wndHealth:SetMax(100)
			wndHealth:SetProgress(nCurrValue)
			wndHealth:SetTooltip(Apollo.FormatNumber(nCurrValue))
			wndHealth:SetFullSprite("spr_WarPlots_Generator_FillBlue")
		elseif eObjectiveId == 1840 then --Dominion Bomb
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndBlueGeneratorS:FindChild("HealthTint")
			
			self.wndBlueGeneratorS:Show(true)
			
			if nCurrValue > 0 then
				self.wndBlueGeneratorS:SetSprite(nHealthPCT > 20 and "spr_WarPlots_Generator_Blue" or "anim_WarPlots_Generator_Blue")
				self.wndBlueGeneratorS:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 1, true).."%")
			else
				self.wndBlueGeneratorS:SetSprite("spr_WarPlots_Generator_Inactive")
				self.wndBlueGeneratorS:FindChild("HealthValue"):SetText("")
			end
			
			wndHealth:SetMax(100)
			wndHealth:SetProgress(nCurrValue)
			wndHealth:SetTooltip(Apollo.FormatNumber(nCurrValue))
			wndHealth:SetFullSprite("spr_WarPlots_Generator_FillBlue")
		elseif eObjectiveId == 1389 then --Red Generator N
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndRedGeneratorN:FindChild("HealthTint")
			
			self.wndRedGeneratorN:Show(true)
			
			if nCurrValue > 0 then
				self.wndRedGeneratorN:SetSprite(nHealthPCT > 20 and "spr_WarPlots_Generator_Red" or "anim_WarPlots_Generator_Red")
				self.wndRedGeneratorN:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 1, true).."%")
			else
				self.wndRedGeneratorN:SetSprite("spr_WarPlots_Generator_Inactive")
				self.wndRedGeneratorN:FindChild("HealthValue"):SetText("")
			end
			
			wndHealth:SetMax(100)
			wndHealth:SetProgress(nCurrValue)
			wndHealth:SetTooltip(Apollo.FormatNumber(nCurrValue))
			wndHealth:SetFullSprite("spr_WarPlots_Generator_FillRed")
		elseif eObjectiveId == 1390 then --Red Generator S
			local nHealthPCT = nCurrValue / nMaxValue * 100
			local wndHealth = self.wndRedGeneratorS:FindChild("HealthTint")
			
			self.wndRedGeneratorS:Show(true)
			
			if nCurrValue > 0 then
				self.wndRedGeneratorS:SetSprite(nHealthPCT > 20 and "spr_WarPlots_Generator_Red" or "anim_WarPlots_Generator_Red")
				self.wndRedGeneratorS:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 1, true).."%")
			else
				self.wndRedGeneratorS:SetSprite("spr_WarPlots_Generator_Inactive")
				self.wndRedGeneratorS:FindChild("HealthValue"):SetText("")
			end
			
			wndHealth:SetMax(100)
			wndHealth:SetProgress(nCurrValue)
			wndHealth:SetTooltip(Apollo.FormatNumber(nCurrValue))
			wndHealth:SetFullSprite("spr_WarPlots_Generator_FillRed")
		end
	end
end

function Sabotage:HideEverything()
	self.wndMain:Show(false)
	Apollo.StopTimer("Sabotage_OneSecMatchTimer")
end

function Sabotage:CheckForSabotage()
	if not MatchingGame:GetPVPMatchState() then
		return
	end
	
	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		
		if eType == PublicEvent.PublicEventType_PVP_Battleground_Sabotage then
			return peCurrent
		end
	end
	
	return
end

function Sabotage:CheckForSabotageObjectives(peMatch)
	if not peMatch then
		return nil
	end

	local arResult = {}
	
	table.insert(arResult, peMatch:GetObjective(1415)) -- Center CP
	table.insert(arResult, peMatch:GetObjective(1416)) -- East CP
	table.insert(arResult, peMatch:GetObjective(1417)) -- West CP
	
	table.insert(arResult, peMatch:GetObjective(1710)) -- Dom Generator
	table.insert(arResult, peMatch:GetObjective(1711)) -- Exile Generator
	
	--table.insert(arResult, peMatch:GetObjective(1839)) -- Exile Bomb
	--table.insert(arResult, peMatch:GetObjective(1840)) -- Dominion Bomb
	
	-- If one of these fails then don't get any of them.
	for idx, peoCurrent in pairs(arResult) do
		if not peoCurrent then
			return nil
		end
	end
	
	return arResult
end

local SabotageInstance = Sabotage:new()
SabotageInstance:Init()