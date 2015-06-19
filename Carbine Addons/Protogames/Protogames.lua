-----------------------------------------------------------------------------------------------
-- Client Lua Script for Protogames
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "PublicEvent"

local Protogames = {}

local LuaEnumObjectives =
{
	TotalPoints	= 4351,
	RoomPoints	= 4352,
	Multiplier 	= 4353,
	Room			= 4659,
	Boss1		= 4660,
	Boss2		= 4661,
	Boss3		= 4662,
}

local tBossProgressSprites =
{
	[0] = "Protogames:spr_Protogames_Icon_BossInactive",	-- 0 - Incomplete
	[1] = "Protogames:spr_Protogames_Icon_MedalFailed",	-- 1 - No Medal
	[2] = "Protogames:spr_Protogames_Icon_MedalBronze",	-- 2 - Bronze Medal
	[3] = "Protogames:spr_Protogames_Icon_MedalSiilver",	-- 3 - Silver Medal
	[4] = "Protogames:spr_Protogames_Icon_MedalGold",		-- 4 - Gold Medal
}

function Protogames:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Protogames:Init()
	Apollo.RegisterAddon(self)
end

function Protogames:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Protogames.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	
	self:ResetData()
end

function Protogames:OnDocumentReady()
	if not self.xmlDoc then
		return
	end
	
	Apollo.RegisterEventHandler("ChangeWorld", 		"Reset", self)
	Apollo.RegisterEventHandler("PublicEventStart",	"CheckForProtogames", self)
	Apollo.RegisterEventHandler("MatchEntered", 	"CheckForProtogames", self)
	
	Apollo.RegisterEventHandler("Protogames_EventTally", 				"OnProtogames_EventTally", self)
	Apollo.RegisterEventHandler("Protogames_PersonalPoint", 			"OnProtogames_PersonalPoint", self)
	
	Apollo.RegisterTimerHandler("Protogames_OneSecMatchTimer", 	"OnProtogamesOneSecMatchTimer", self)
	
	self.wndMain 				= Apollo.LoadForm(self.xmlDoc, "ProtogamesMain", "FixedHudStratum", self)
	self.wndTallyContainer 	= Apollo.LoadForm(self.xmlDoc, "ProtogamesTallyContainer", "FixedHudStratumHigh", self)
	
	Apollo.CreateTimer("Protogames_OneSecMatchTimer",  1.0, true)
	
	if not self:CheckForProtogames() then
		self:Reset()
	end
end

function Protogames:Reset()
	self.wndTallyContainer:DestroyChildren()
	self.wndTallyContainer:Show(false)
	self.wndMain:Show(false)
	Apollo.StopTimer("Protogames_OneSecMatchTimer")
	
	self:ResetData()
end

function Protogames:ResetData()
	self.tObjectives = {}
	self.peMatch = nil
	self.tTallyMessages = {}
	self.tTallyTimers = {}
	self.nLastRoom = 0
end

function Protogames:OnProtogames_EventTally(nMsgId, nPoints)
	local wndMessage = Apollo.LoadForm(self.xmlDoc, "ProtogamesTallyMessage", self.wndTallyContainer, self)
	wndMessage:SetText(string.format(
		"%s%s+%s", 
		Apollo.GetString(nMsgId), 
		Apollo.GetString("Chat_ColonBreak"), 
		Apollo.FormatNumber(nPoints, 0, true)
	))
	
	local timerTallyCleanup = ApolloTimer.Create(5.0, false, "OnTallyCleanUpTimer", self)
	timerTallyCleanup:Start()
	
	table.insert(self.tTallyTimers, timerTallyCleanup)
	table.insert(self.tTallyMessages, wndMessage)
	
	self.wndTallyContainer:ArrangeChildrenVert(0)
end

function Protogames:OnTallyCleanUpTimer()
	local wndMessage = self.tTallyMessages[1]
	if wndMessage and wndMessage:IsValid() then
		wndMessage:Destroy()
	end
	
	table.remove(self.tTallyTimers, 1)
	table.remove(self.tTallyMessages, 1)
	
	self.wndTallyContainer:ArrangeChildrenVert(0)
end

function Protogames:OnProtogames_PersonalPoint(nPoints)
	if self.timerPointsCleanup then
		self.timerPointsCleanup:Stop()
	end
	
	self.timerPointsCleanup = ApolloTimer.Create(1.5, false, "OnPointsCleanUpTimer", self)
	self.timerPointsCleanup:Start()
	
	if self.wndPoints then
		self.wndPoints:Destroy()
	end
	
	self.wndPoints = Apollo.LoadForm(self.xmlDoc, "ProtogamesPlusPoints", "FixedHudStratumLow", self)
	self.wndPoints:SetText("+"..Apollo.FormatNumber(nPoints, 0, true))
	self.wndPoints:Show(true, false, 1.0)
end

function Protogames:OnPointsCleanUpTimer()
	local nLeft, nTop, nRight, nBottom = self.wndPoints:GetAnchorOffsets()
	local tLoc = WindowLocation.new({ fPoints = { 0.5, 0, 0.5, 0 }, nOffsets = { 0, nTop-50, 0, nTop-50 }})
	self.wndPoints:TransitionMove(tLoc, 1.0)
	self.wndPoints:Destroy()
end

function Protogames:OnProtogamesOneSecMatchTimer()
	if not self.peMatch then
		self:CheckForProtogames()
		return
	end
	
	local nRoom = self.tObjectives[LuaEnumObjectives.Room]:GetCount() or 0
	if nRoom >= self.nLastRoom then
		self:DrawCounter(self.tObjectives[LuaEnumObjectives.TotalPoints], self.wndMain:FindChild("Total"))
		self:DrawCounter(self.tObjectives[LuaEnumObjectives.RoomPoints], self.wndMain:FindChild("Room"))
		self:DrawCounter(self.tObjectives[LuaEnumObjectives.Multiplier], self.wndMain:FindChild("Bonus"), "x")
		
		self:DrawRoom(
			self.tObjectives[LuaEnumObjectives.Room], 
			self.tObjectives[LuaEnumObjectives.Boss1], 
			self.tObjectives[LuaEnumObjectives.Boss2],
			self.tObjectives[LuaEnumObjectives.Boss3]
		)
		
		self.nLastRoom = nRoom
	end
end

function Protogames:DrawRoom(peoRoom, peoBoss1, peoBoss2, peoBoss3)
	for i=1, peoRoom:GetRequiredCount() do
		local wndRoom = self.wndMain:FindChild("Room"..tostring(i))
		local strSprite = "Protogames:spr_Protogames_Cell_Incomplete"
		
		if i < peoRoom:GetCount() then
			strSprite = "Protogames:spr_Protogames_Cell_Complete"
		elseif i == peoRoom:GetCount() then
			strSprite ="Protogames:spr_Protogames_Cell_Active"
		else
			strSprite = "Protogames:spr_Protogames_Cell_Incomplete"
		end

		-- Boss Rooms
		if i == 2 then
			strSprite = peoRoom:GetCount() == 2 and "Protogames:spr_Protogames_Icon_BossActive" or tBossProgressSprites[peoBoss1:GetCount()]
		elseif i == 4 then
			strSprite = peoRoom:GetCount() == 4 and "Protogames:spr_Protogames_Icon_BossActive" or tBossProgressSprites[peoBoss2:GetCount()]
		elseif i == 6 then
			strSprite = peoRoom:GetCount() == 6 and "Protogames:spr_Protogames_Icon_BossActive" or tBossProgressSprites[peoBoss3:GetCount()]
		end
		
		if wndRoom and wndRoom:IsValid() then
			wndRoom:SetSprite(strSprite)
		end
	end
	
	local bShow = peoRoom:GetCount() > 0
	self.wndMain:Show(bShow)
	self.wndTallyContainer:Show(bShow)
end

function Protogames:DrawCounter(peoCounter, wndBar, strSuffix)
	local nMaxCounter = peoCounter:GetRequiredCount()
	local nCurrentCounter = peoCounter:GetCount()
	strSuffix = strSuffix and strSuffix or ""
		
	wndBar:SetText(string.format("%s%s", Apollo.FormatNumber(nCurrentCounter, 0, true), strSuffix))
end

function Protogames:CheckForProtogames()
	if self.peMatch then
		return true
	end
	
	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		
		if eType == PublicEvent.PublicEventType_Dungeon then
			for idx, idObjective in pairs(LuaEnumObjectives) do
				self.tObjectives[idObjective] = peCurrent:GetObjective(idObjective)
			end
			
			if self.tObjectives[LuaEnumObjectives.TotalPoints] ~= nil then
				self.peMatch = peCurrent
				Apollo.StartTimer("Protogames_OneSecMatchTimer")
				return true
			end
		end
	end
	
	return false
end

local ProtogamesInstance = Protogames:new()
ProtogamesInstance:Init()