-----------------------------------------------------------------------------------------------
-- Client Lua Script for Sabotage
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "PublicEvent"

local Sabotage = {}

local knSaveVersion = 1
local knMaxTimer = 90000
local knSlotOrder = 
{
	{4,3,2,1},
	{1,2,3,4},
}

local LuaEnumBlueTeamInfo =
{
	Health		= 1711,
}

local knBlueTeamId = 4

local LuaEnumRedTeamInfo = 
{
	Health 		= 1710,
}

local knRedTeamId = 5

local LuaEnumControlPoints =
{
	Center 		= 1415,
	East 			= 1416,
	West 		= 1417,
}


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
	
	self.tBombCarriers = { }
end

function Sabotage:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	local tSaved = 
	{
		tBombCarriers = self.tBombCarriers,
		nSaveVersion = knSaveVersion,
	}
	
	return tSaved
end

function Sabotage:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tBombCarriers then
		self.tBombCarriers = tSavedData.tBombCarriers
	end
end

function Sabotage:OnDocumentReady()
	if not self.xmlDoc then
		return
	end
	
	Apollo.RegisterTimerHandler("Sabotage_OneSecMatchTimer", "OnWarPlotOneSecMatchTimer", self)
	
	Apollo.RegisterEventHandler("ChangeWorld", 				"OnChangeWorld", self)
	Apollo.RegisterEventHandler("PublicEventStart",			"CheckForSabotage", self)
	Apollo.RegisterEventHandler("MatchEntered", 			"CheckForSabotage", self)
	Apollo.RegisterEventHandler("PublicEventBombStatus",	"OnSabotageBombCarrier", self)
	Apollo.RegisterEventHandler("PublicEventBombDropped",	"OnSabotageBombDropped", self)
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "SabotageMain", "FixedHudStratumLow", self)
	self.wndMain:Show(false)
	
	self.wndRedBar = self.wndMain:FindChild("RedBar")
	self.wndBlueBar = self.wndMain:FindChild("BlueBar")
	
	self.wndBombs = 
	{
		Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Bomb1"), self),
		Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Red:Bomb2"), self),
		Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Bomb1"), self),
		Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", self.wndMain:FindChild("Blue:Bomb2"), self),
	}
	
	for idx, wndBomb in pairs(self.wndBombs) do
		wndBomb:FindChild("Timer"):SetMax(100)
		wndBomb:Show(false)
	end
	
	Apollo.CreateTimer("Sabotage_OneSecMatchTimer", 1.0, true)
	Apollo.StopTimer("Sabotage_OneSecMatchTimer")
	
	self.tBlueInfo = {}
	self.tRedInfo = {}
	self.tControlPointInfo = {}
	self.peMatch = nil
	
	if MatchingGame.IsInMatchingGame() or MatchingGame.IsInPVPGame() then
		self:CheckForSabotage()
	end
end

function Sabotage:OnChangeWorld()
	self.wndMain:Show(false)
	Apollo.StopTimer("Sabotage_OneSecMatchTimer")
	self.peMatch = nil
	
	self.tBombCarriers = { }
end

function Sabotage:OnWarPlotOneSecMatchTimer()
	if not self.peMatch then
		self:CheckForSabotage()
		return
	end
	
	self.wndMain:Show(true)
	
	-- Building Red Team's Info
	self:DrawHealth(self.tRedInfo[LuaEnumRedTeamInfo.Health], self.wndRedBar, self.wndMain:FindChild("Red:CurrentProgress"))
	
	-- Building Blue Team's Info
	self:DrawHealth(self.tBlueInfo[LuaEnumBlueTeamInfo.Health], self.wndBlueBar, self.wndMain:FindChild("Blue:CurrentProgress"))
	
	local tSlots = {}
	for idx, tData in pairs(self.tBombCarriers) do
		if not tSlots[idx] then
			for k, idx2 in pairs(knSlotOrder[tData.eTeam]) do
				if not self.wndBombs[idx2]:GetData() or self.wndBombs[idx2]:GetData().idCarrier == idx then
					if tData.wndBomb and tData.wndBomb ~= self.wndBombs[idx2] then
						tData.wndBomb:SetData(nil)
						tData.wndBomb:SetSprite("")
						tData.wndBomb:FindChild("Carrier"):SetText("")
						tData.wndBomb:FindChild("TimeRemaining"):SetText("")
						tData.wndBomb:FindChild("Timer"):SetProgress(0)
						tData.wndBomb:Show(false)
					end
					
					tData.nTimer = tData.nTimer - 1000
					tData.wndBomb = self.wndBombs[idx2]
					
					self.wndBombs[idx2]:SetData(tData)
					self:DrawBomb(self.wndBombs[idx2])
					tSlots[idx] = true
					break
				end
			end
		end
	end

	-- Draw Control Points
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.Center], self.wndMain:FindChild("Center"), 3)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.West], self.wndMain:FindChild("West"), 2)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.East], self.wndMain:FindChild("East"), 4)
end

function Sabotage:OnSabotageBombCarrier(nTimeInMs, unitCarrier, idTeam)
	if not unitCarrier then
		return
	end
	
	local idCarrier = unitCarrier:GetId()
	
	local eTeam = (idTeam == knBlueTeamId) and 1 or 2
	if self.tBombCarriers[idCarrier] == nil then
		self.tBombCarriers[idCarrier] = {nTimer = nTimeInMs, idCarrier = idCarrier, eTeam = eTeam}
	else
		self.tBombCarriers[idCarrier].nTimer = nTimeInMs
	end
end

function Sabotage:OnSabotageBombDropped(idCarrier)
	if not idCarrier then
		return
	end
	
	if self.tBombCarriers[idCarrier] then
		local wndBomb = self.tBombCarriers[idCarrier].wndBomb
	
		if wndBomb then
			wndBomb:SetData(nil)
			wndBomb:SetSprite("")
			wndBomb:FindChild("Carrier"):SetText("")
			wndBomb:FindChild("TimeRemaining"):SetText("")
			wndBomb:FindChild("Timer"):SetProgress(0)
			wndBomb:Show(false)
		end
		
		self.tBombCarriers[idCarrier] = nil
	end
end

function Sabotage:DrawHealth(peoHealth, wndBar, wndProgress)
	local nMaxHealth = peoHealth:GetRequiredCount()
	local nCurrentHealth = peoHealth:GetCount()
	local strTeam = Apollo.GetString(peoHealth:GetTeam() ~= self.peMatch:GetJoinedTeam() and "MatchTracker_MyTeam" or "MatchTracker_EnemyTeam")
		
	wndBar:Show(nCurrentHealth > 0)
	wndBar:SetMax(nMaxHealth)
	wndBar:SetProgress(nCurrentHealth)
	wndBar:SetStyleEx("EdgeGlow", nCurrentHealth > 0 and nCurrentHealth < nMaxHealth)
	wndBar:SetTooltip(string.format("%s: %s / %s", strTeam, Apollo.FormatNumber(nCurrentHealth, 0, true), Apollo.FormatNumber(nMaxHealth, 0, true)))
	
	wndProgress:Show(nCurrentHealth > 0)
	wndProgress:SetText(Apollo.FormatNumber(nCurrentHealth / nMaxHealth * 100, 1, true).."%")
end

function Sabotage:DrawBomb(wndBomb)
	if not wndBomb then
		return
	end
	
	local tData = wndBomb:GetData()
	local strCarrier = ""
	local peoHealth = nil
	
	if tData then	
		local nCurrentTime = tData.nTimer
		local nTimerPCT = nCurrentTime / knMaxTimer * 100
		local wndTimer = wndBomb:FindChild("Timer")
		
		if nCurrentTime <= 0 then
			self:OnSabotageBombDropped(tData.idCarrier)
			return
		end
		
		if tData.eTeam == 1 then
			wndBomb:FindChild("Bomb"):SetSprite("spr_WarPlots_Bomb_Blue")
			wndTimer:SetFullSprite("spr_WarPlots_Generator_FillBlue")
		else
			wndBomb:FindChild("Bomb"):SetSprite("spr_WarPlots_Bomb_Red")
			wndTimer:SetFullSprite("spr_WarPlots_Generator_FillRed")
		end
		
		if tData.idCarrier then
			local unitCarrier = GameLib.GetUnitById(tData.idCarrier)
			strCarrier = unitCarrier and unitCarrier:GetName() or ""
		end
		
		wndTimer:SetProgress(nTimerPCT)
		wndTimer:SetTooltip(Apollo.FormatNumber(nCurrentTime/1000))
		
		wndBomb:FindChild("Carrier"):SetText(strCarrier)
		wndBomb:FindChild("TimeRemaining"):SetText(Apollo.FormatNumber(nCurrentTime/1000, 0, true))
		wndBomb:Invoke()
	end
end

function Sabotage:DrawControlPoint(peoControlPoint, wndPoint, nIndex)
	wndPoint:SetMax(100)
	wndPoint:SetProgress(100)
	wndPoint:SetFullSprite(peoControlPoint:GetOwningTeam() == 0 and "" or peoControlPoint:GetOwningTeam() == knRedTeamId and "spr_Warplots_CP" .. nIndex .. "_RedCap" or "spr_Warplots_CP" .. nIndex .. "_BlueCap")
end

function Sabotage:CheckForSabotage()
	if not MatchingGame:GetPVPMatchState() or self.peMatch then
		return
	end

	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		if eType == PublicEvent.PublicEventType_PVP_Battleground_Sabotage then
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
			
			Apollo.StartTimer("Sabotage_OneSecMatchTimer")
			return
		end
	end
	
	return
end

local SabotageInstance = Sabotage:new()
SabotageInstance:Init()trUnitName = unitTarget:GetName() -- specific to #7
					local strBracketText = Apollo.GetString("Nameplates_Missions") -- specific to #7
					if wndCurr:IsShown() then -- already have a tooltip
						tRewardString[eType] = string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</P>", tRewardString[eType], strMission)

					else
						tRewardString[eType] = string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"Yellow\">%s</P>"..
														 "<P Font=\"CRB_InterfaceMedium\">%s</P>", tRewardString[eType], String_GetWeaselString(Apollo.GetString("TargetFrame_HealthShieldText"), strUnitName, strBracketText), strMessage)
					end

					wndCurr:SetTooltip(tRewardString[eType])
				end

				if splSpell then
					local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, Unit.CodeEnumRewardInfoType.ScientistSpell)
					nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)
					if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
						Tooltip.GetSpellTooltipForm(self, wndCurr, splSpell)
					end
				end
			elseif eType == Unit.CodeEnumRewardInfoType.PublicEvent and not self:HelperFlagOrDefault(tFlags, "bHidePublicEvents", false) then
				local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eType)

				local peEvent = tRewardInfo[idx].peoObjective
				local strTitle = peEvent:GetEvent():GetName()
				local nCompleted = peEvent:GetCount()
				local nNeeded = peEvent:GetRequiredCount()

				nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)

				local strTempTitle = strTitle
				if peEvent:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_Exterminate then
					strTempTitle = String_GetWeaselString(Apollo.GetString("Nameplates_NumRemaining"), strTitle, nCompleted)
				elseif peEvent:ShowPercent() then
					strTempTitle = String_GetWeaselString(Apollo.GetString("Nameplates_PercentCompleted"), strTitle, nCompleted / nNeeded * 100)
				elseif peEvent:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_TimedWin then -- Very intentionally placed after the ShowPercent() check
					strTempTitle = String_GetWeaselString(Apollo.GetString("RewardInfo_PublicEventTimedWin"), strTitle, nCompleted * 1000, nNeeded * 1000)
				elseif nNeeded > 0 then 
					strTempTitle = String_GetWeaselString(Apollo.GetString("BuildMap_CategoryProgress"), strTitle, nCompleted, nNeeded)
				end

				tRewardString[eType] = string.format("%s<P Font=\"CRB_InterfaceMedium\">%s</P>", tRewardString[eType], strTempTitle)

				wndCurr:ToFront()				
				wndCurr:SetTooltip(tRewardString[eType])
			end
		end
	end

	if ( bIsRival and not self:HelperFlagOrDefault(tFlags, "bHideRivals", false) )
		or ( bIsFriend and not self:HelperFlagOrDefault(tFlags, "bHideFriends", false) )
		  or ( bIsAccountFriend and not self:HelperFlagOrDefault(tFlags, "bHideAccountFriends", false) ) then

		local eTempType = bIsRival and Unit.CodeEnumRewardInfoType.Rival or Unit.CodeEnumRewardInfoType.Friend
		local strTempType = bIsRival and "Ri