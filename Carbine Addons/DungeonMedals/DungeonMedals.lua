-----------------------------------------------------------------------------------------------
-- Client Lua Script for Protogames
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "PublicEvent"

local DungeonMedals = {}

local kstrNoMedal		= "Protogames:spr_Protogames_Icon_MedalFailed"
local kstrBronzeMedal	= "Protogames:spr_Protogames_Icon_MedalBronze"
local kstrSilverMedal	= "Protogames:spr_Protogames_Icon_MedalSilver"
local kstrGoldMedal		= "Protogames:spr_Protogames_Icon_MedalGold"

local LuaEnumObjectives =
{
	StormtalonPoints			= 4717,
	StormtalonBronze			= 4718,
	StormtalonSilver			= 4719,
	StormtalonGold				= 4720,

	KelVorethPoints				= 4721,
	KelVorethBronze				= 4722,
	KelVorethSilver				= 4723,
	KelVorethGold				= 4724,

	SkullcanoPoints  			= 4725,
	SkullcanoBronze  			= 4726,
	SkullcanoSilver  			= 4727,
	SkullcanoGold  				= 4728,
	
	TorineSanctuaryPoints		= 4729,
	TorineSanctuaryBronze		= 4730,
	TorineSanctuarySilver		= 4731,
	TorineSanctuaryGold			= 4732,
}

function DungeonMedals:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function DungeonMedals:Init()
	Apollo.RegisterAddon(self)
end

function DungeonMedals:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("DungeonMedals.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	
	self:InitializeVars()
end

function DungeonMedals:InitializeVars()
	self.nTimeElapsed = 0
	self.nPointDelta = 0
	self.nPoints	= 0
	self.nBronze = 0
	self.nSilver = 0
	self.nGold = 0
	self.bMatchStarted = false
	self.tObjectives = {}
	self.peMatch = nil
end

function DungeonMedals:OnDocumentReady()
	if not self.xmlDoc then
		return
	end
	
	Apollo.RegisterEventHandler("ChangeWorld", 		"Reset", self)
	Apollo.RegisterEventHandler("PublicEventStart",	"CheckForDungeon", self)
	Apollo.RegisterEventHandler("MatchEntered", 	"CheckForDungeon", self)
	
	Apollo.RegisterEventHandler("Dungeons_IncreasePoints", 			"OnDungeons_IncreasePoints", self)
	
	Apollo.RegisterTimerHandler("DungeonMedals_OneSecMatchTimer", 	"OnOneSecTimer", self)
	
	Apollo.CreateTimer("DungeonMedals_OneSecMatchTimer",  1.0, true)
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "DungeonMedalsMain", "FixedHudStratum", self)
	
	if not self:CheckForDungeon() then
		self:Reset()
	end
end

function DungeonMedals:Reset()
	self.wndMain:Show(false)
	Apollo.StopTimer("DungeonMedals_OneSecMatchTimer")
	
	self:InitializeVars()
end

function DungeonMedals:OnDungeons_IncreasePoints(nPoints)
	if self.timerPointsCleanup then
		self.timerPointsCleanup:Stop()
	end
	
	self.timerPointsCleanup = ApolloTimer.Create(1.5, false, "OnPointsCleanUpTimer", self)
	self.timerPointsCleanup:Start()
	
	if self.wndPoints then
		self.wndPoints:Destroy()
	end
	
	self.nPointDelta = self.nPointDelta + nPoints
	self.wndPoints = Apollo.LoadForm(self.xmlDoc, "DungeonMedalsPlusPoints", "FixedHudStratumLow", self)
	self.wndPoints:SetData(nPoints)
	self.wndPoints:SetText("+"..tostring(Apollo.FormatNumber(self.nPointDelta, 0, true)))
	self.wndPoints:Show(true, false, 1.0)
	
	self:UpdatePoints()
end

function DungeonMedals:UpdatePoints()
	if self.peMatch then
		self.nPoints			= self.peoPoints and self.peoPoints:GetCount() > 0 and self.peoPoints:GetCount() or self.nPoints	
		self.nBronze		= self.peoBronze and self.peoBronze:GetCount() > 0 and self.peoBronze:GetCount() or self.nBronze
		self.nSilver			= self.peoSilver and self.peoSilver:GetCount() > 0 and self.peoSilver:GetCount() or self.nSilver
		self.nGold			= self.peoGold and self.peoGold:GetCount() > 0 and self.peoGold:GetCount() or self.nGold
	end
	
	local strVisible	= "ffffffff"
	local strDim		= "66ffffff"
	
	-- Bronze - Tier 1
	self.wndMain:FindChild("Bronze"):SetTooltip(Apollo.FormatNumber(self.nBronze, 0, true))
	self.wndMain:FindChild("Bronze"):SetBGColor(self.nPoints >= self.nBronze and strVisible or strDim)
	self.wndMain:FindChild("Tier1"):FindChild("Active"):Show(self.nPoints < self.nBronze)
	self.wndMain:FindChild("Tier1"):FindChild("ProgressBar"):SetMax(self.nBronze)
	self.wndMain:FindChild("Tier1"):FindChild("ProgressBar"):SetProgress(math.min(self.nBronze, self.nPoints))
	self.wndMain:FindChild("Tier1"):FindChild("ProgressBar"):SetBarColor(self.nPoints >= self.nBronze and strDim or strVisible)
	
	-- Silver - Tier 2
	self.wndMain:FindChild("Silver"):SetTooltip(Apollo.FormatNumber(self.nSilver, 0, true))
	self.wndMain:FindChild("Silver"):SetBGColor(self.nPoints >= self.nSilver and strVisible or strDim)
	self.wndMain:FindChild("Tier2"):FindChild("Active"):Show(self.nPoints >= self.nBronze and self.nPoints < self.nSilver)
	self.wndMain:FindChild("Tier2"):FindChild("ProgressBar"):SetMax(self.nSilver - self.nBronze)
	self.wndMain:FindChild("Tier2"):FindChild("ProgressBar"):SetProgress(self.nPoints > self.nBronze and math.min(self.nSilver, self.nPoints - self.nBronze) or 0)
	self.wndMain:FindChild("Tier2"):FindChild("ProgressBar"):SetBarColor(self.nPoints >= self.nSilver and strDim or strVisible)

	-- Gold - Tier 3
	self.wndMain:FindChild("Gold"):SetTooltip(Apollo.FormatNumber(self.nGold, 0, true))
	self.wndMain:FindChild("Gold"):SetBGColor(self.nPoints >= self.nGold and strVisible or strDim)
	self.wndMain:FindChild("Tier3"):FindChild("Active"):Show(self.nPoints >= self.nSilver and self.nPoints < self.nGold)
	self.wndMain:FindChild("Tier3"):FindChild("ProgressBar"):SetMax(self.nGold - self.nSilver)
	self.wndMain:FindChild("Tier3"):FindChild("ProgressBar"):SetProgress(self.nPoints > self.nSilver and math.min(self.nGold, self.nPoints - self.nSilver) or 0)
	self.wndMain:FindChild("Tier3"):FindChild("ProgressBar"):SetBarColor(self.nPoints >= self.nGold and strDim or strVisible)
end

function DungeonMedals:OnPointsCleanUpTimer()
	local nLeft, nTop, nRight, nBottom = self.wndPoints:GetAnchorOffsets()
	local tLoc = WindowLocation.new({ fPoints = { 0.5, 0, 0.5, 0 }, nOffsets = { nLeft-50, nTop-50, nRight-50, nTop-50 }})
	
	self.wndPoints:TransitionMove(tLoc, 1.0)
	self.wndPoints:Show(false, false, 1.0)
	self.nPointDelta = 0
end

function DungeonMedals:OnOneSecTimer()
	if not self.bMatchStarted then
		self:CheckForDungeon()
		return
	end
	
	if self.peMatch then
		self.nTimeElapsed = self.peMatch:GetElapsedTime() > 0 and math.ceil(self.peMatch:GetElapsedTime() / 1000) or self.nTimeElapsed
	end
	
	local nTime		= self.nTimeElapsed --+3600 (testing hour formatting)
	local nHours		= math.floor(nTime / 3600)
	local nMinutes	= math.floor((nTime - (nHours * 3600)) / 60)
	local nSeconds 	= nTime - (nHours * 3600) - (nMinutes * 60)
	
	local strTime 		= nHours > 0 
		and string.format("%02d:%02d:%02d", nHours, nMinutes, nSeconds) 
		or string.format("%02d:%02d", nMinutes, nSeconds)
	
	self.wndMain:FindChild("Time"):SetText(strTime)
	self.wndMain:FindChild("Points"):SetText(Apollo.FormatNumber(self.nPoints, 0, true))
	
	self.wndMain:Show(self.nTimeElapsed > 0)
end

function DungeonMedals:CheckForDungeon()
	if self.bMatchStarted then
		return true
	end
	
	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		
		if eType == PublicEvent.PublicEventType_Dungeon then
			for idx, idObjective in pairs(LuaEnumObjectives) do
				self.tObjectives[idObjective] = peCurrent:GetObjective(idObjective)
			end
			
			self.peoPoints = 
					self.tObjectives[LuaEnumObjectives.StormtalonPoints]
				or self.tObjectives[LuaEnumObjectives.KelVorethPoints]
				or self.tObjectives[LuaEnumObjectives.SkullcanoPoints]
				or self.tObjectives[LuaEnumObjectives.TorineSanctuaryPoints]
				
			self.peoBronze = 
					self.tObjectives[LuaEnumObjectives.StormtalonBronze]
				or self.tObjectives[LuaEnumObjectives.KelVorethBronze]
				or self.tObjectives[LuaEnumObjectives.SkullcanoBronze]
				or self.tObjectives[LuaEnumObjectives.TorineSanctuaryBronze]
				
			self.peoSilver = 
					self.tObjectives[LuaEnumObjectives.StormtalonSilver]
				or self.tObjectives[LuaEnumObjectives.KelVorethSilver]
				or self.tObjectives[LuaEnumObjectives.SkullcanoSilver]
				or self.tObjectives[LuaEnumObjectives.TorineSanctuarySilver]
				
			self.peoGold = 
					self.tObjectives[LuaEnumObjectives.StormtalonGold]
				or self.tObjectives[LuaEnumObjectives.KelVorethGold]
				or self.tObjectives[LuaEnumObjectives.SkullcanoGold]
				or self.tObjectives[LuaEnumObjectives.TorineSanctuaryGold]
				
			self.bMatchStarted = self.peoPoints ~= nil
			if self.bMatchStarted then
				self.peMatch = peCurrent
				
				Apollo.StartTimer("DungeonMedals_OneSecMatchTimer")
				self:UpdatePoints()
				return true
			end
		end
	end
	
	return false
end

local DungeonMedalsInstance = DungeonMedals:new()
DungeonMedalsInstance:Init()ÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿºÖ   Vÿÿ      ÿÿ,c   _ù6    €&ÿÿ,c  ^Uø   ¢äÿÿc .UUût    ÿÿc  
•ÿÿ      ÿÿ¾÷   ÿÿ      ÿÿÿÿªªªªø     ÿÿcWp€ øIÒ$˜€]ïìbUUUX  I’$I‚$cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        ëZ  @@@@        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ?	‘$I’$cëZÿÿÿÿºœ$I’$cëZÿÿÿÿø$I’$•­ìb/UUUø `»I’$šÖëZUUUø @nI’$ßÿëZ UUUø 0I’$ßÿc õUUø   I$ÿÿc ÿUUø   ‰$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿëZ ÿUUø   vœ$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ®$ÿÿ,c ÿUUø   ¶›$ÿÿëZ ÿUUø   ¶$ÿÿc ÿUUø   ¶$ßÿëZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ÿÿëZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   vœ$ßÿËZ ÿUUø   öÿÿËZ ¿••ÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªÿÿ      ßÿ²” €€@ø   "É$ßÿËZ ÿUUø   $›$ßÿËZ ÿUUø   6™$ßÿËZ ÿUUø   ¶$ÿÿëZ ÿUUø   ¶$ßÿëZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿëZ ÿUUø   %™$ßÿËZ ÿUUø   $™$ßÿËZ ÿUUø   ´$ßÿËZ ÿUUø   &™$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶›$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   v›$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿ,c ÿUUø   ¶$ÿÿëZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ·$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶›$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   ¶$ßÿËZ ÿUUø   Oœ$ßÿËZ ÿUUø   N’$ßÿëZ _UUø   I’$¾÷c€UUUø  lI’$ºÖëZ UUUø °‘I’$óœëZhUUUø ä'I’$cëZÿÿÿÿº$I’$cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ‹‰‘$I’$cëZÿÿÿÿø I$ßÿëZ-UUUø   ˜ÿÿc ÕUÿï     ßÿ-k  µÿÿ      ÿÿ0„@   ø`È   ÿÿ,cUVp øI’${0ÓœëZUUUT        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        ëZ  @@@@        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿø	‘‰‘ûŞc•ÕUÿÿ      ÿÿ¾÷   ÿÿ      ÿÿÿÿªªªªÿÿ      ÿÿÿÿªªªªø    
(ÿÿ,c@`P\^Hò$I’$cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ        cëZÿÿÿÿ