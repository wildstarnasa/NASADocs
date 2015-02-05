-----------------------------------------------------------------------------------------------
-- Client Lua Script for XPBar
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "GameLib"
require "GroupLib"
require "PlayerPathLib"

local XPBar = {}
local knMaxLevel = 50 -- TODO: Replace with a variable from code
local knMaxPathLevel = 30 -- TODO: Replace this with a non hardcoded value

local ktPathIcon = {
	[PlayerPathLib.PlayerPathType_Soldier] 		= "HUD_ClassIcons:spr_Icon_HUD_Path_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "HUD_ClassIcons:spr_Icon_HUD_Path_Settler",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "HUD_ClassIcons:spr_Icon_HUD_Path_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 		= "HUD_ClassIcons:spr_Icon_HUD_Path_Explorer",
}

local c_arPathStrings = {
	[PlayerPathLib.PlayerPathType_Soldier] 		= "CRB_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "CRB_Settler",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "CRB_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "CRB_Explorer",
}

local kstrRed = "ffff4040"
local kstrOrange = "ffffd100"
local kstrBlue = "ff32fcf6"
local kstrDarkBlue = "ff209d99"

function XPBar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function XPBar:Init()
    Apollo.RegisterAddon(self)
end

function XPBar:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("XPBar.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function XPBar:OnDocumentReady()
	Apollo.RegisterEventHandler("ChangeWorld", 					"OnClearCombatFlag", self)
	Apollo.RegisterEventHandler("ShowResurrectDialog", 			"OnClearCombatFlag", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnEnteredCombat", self)
	
	Apollo.RegisterEventHandler("Group_MentorRelationship", 	"RedrawAll", self)
	Apollo.RegisterEventHandler("CharacterCreated", 			"RedrawAll", self)
	Apollo.RegisterEventHandler("UnitPvpFlagsChanged", 			"RedrawAll", self)
	Apollo.RegisterEventHandler("UnitNameChanged", 				"RedrawAll", self)
	Apollo.RegisterEventHandler("PersonaUpdateCharacterStats", 	"RedrawAll", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 			"RedrawAll", self)
	Apollo.RegisterEventHandler("UI_XPChanged", 				"OnXpChanged", self)
	Apollo.RegisterEventHandler("UpdatePathXp", 				"OnXpChanged", self)
	Apollo.RegisterEventHandler("ElderPointsGained", 			"OnXpChanged", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDPreferences","RedrawAll", self)
	
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 		"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("UpdateInventory", 				"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("PersonaUpdateCharacterStats",	"OnUpdateInventory", self)

	self.wndArt = Apollo.LoadForm(self.xmlDoc, "BaseBarCornerArt", "FixedHudStratum", self)
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "BaseBarCornerForm", "FixedHudStratum", self)
	self.wndXPLevel = self.wndMain:FindChild("XPButton")
	self.wndPathLevel = self.wndMain:FindChild("PathButton")
	
	self.wndInvokeForm = Apollo.LoadForm(self.xmlDoc, "InventoryInvokeForm", "FixedHudStratum", self)
	self.wndQuestItemNotice = self.wndInvokeForm:FindChild("QuestItemNotice")
	self.wndInvokeButton = self.wndInvokeForm:FindChild("InvokeBtn")
	
	self.bInCombat = false
	self.bOnRedrawCooldown = false
	
	Apollo.RegisterTimerHandler("BaseBarCorner_RedrawCooldown", "RedrawCooldown", self)
	Apollo.CreateTimer("BaseBarCorner_RedrawCooldown", 1, false)
	Apollo.StopTimer("BaseBarCorner_RedrawCooldown")

	if GameLib.GetPlayerUnit() ~= nil then
		self:RedrawAll()
	end
	
	self.xmlDoc = nil
end

function XPBar:RedrawCooldown()
	Apollo.StopTimer("BaseBarCorner_RedrawCooldown")
	self.bOnRedrawCooldown = false
	self:RedrawAllPastCooldown()
end

function XPBar:RedrawAll()
	if not self.bOnRedrawCooldown then
		self.bOnRedrawCooldown = true
		self:RedrawAllPastCooldown()
	end

	Apollo.StartTimer("BaseBarCorner_RedrawCooldown")
end

function XPBar:RedrawAllPastCooldown()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end

	local strName = unitPlayer:GetName()
	local tStats = unitPlayer:GetBasicStats()
	local tMyGroupData = GroupLib.GetGroupMember(1)

	-- XP/EP Progress Bar and Tooltip
	local strXPorEP = ""
	local strTooltip = ""
	local strPathXP = ""
	local strPathTooltip = ""
	
	if tStats.nLevel == knMaxLevel then -- TODO: Hardcoded max level
		self:RedrawEP()
		strTooltip = self:ConfigureEPTooltip(unitPlayer)
		self.wndMain:FindChild("ElderGems"):Show(true)
	else
		strXPorEP = String_GetWeaselString(Apollo.GetString("BaseBar_XPBracket"), self:RedrawXP())
		strTooltip = self:ConfigureXPTooltip(unitPlayer)
		self.wndMain:FindChild("ElderGems"):Show(false)
	end
	
	--Path XP Progress Bar and Tooltip
	strPathXP = String_GetWeaselString(Apollo.GetString("BaseBar_PathBracket"), self:RedrawPathXP())
	strPathTooltip = self:ConfigurePathXPTooltip(unitPlayer)

	-- If grouped, Mentored by
	if tMyGroupData and #tMyGroupData.tMentoredBy ~= 0 then
		strName = String_GetWeaselString(Apollo.GetString("BaseBar_MenteeAppend"), strName)
		for idx, nMentorGroupIdx in pairs(tMyGroupData.tMentoredBy) do
			local tTargetGroupData = GroupLib.GetGroupMember(nMentorGroupIdx)
			if tTargetGroupData then
				strTooltip = "<P Font=\"CRB_InterfaceSmall_O\">"..String_GetWeaselString(Apollo.GetString("BaseBar_MenteeTooltip"), tTargetGroupData.strCharacterName).."</P>"..strTooltip
			end
		end
	end

	-- If grouped, Mentoring
	if tMyGroupData and tMyGroupData.bIsMentoring then -- unitPlayer:IsMentoring() -- tStats.effectiveLevel ~= 0 and tStats.effectiveLevel ~= tStats.level
		strName = String_GetWeaselString(Apollo.GetString("BaseBar_MentorAppend"), strName, tStats.nEffectiveLevel)
		local tTargetGroupData = GroupLib.GetGroupMember(tMyGroupData.nMenteeIdx)
		if tTargetGroupData then
			strTooltip = "<P Font=\"CRB_InterfaceSmall_O\">"..String_GetWeaselString(Apollo.GetString("BaseBar_MentorTooltip"), tTargetGroupData.strCharacterName).."</P>"..strTooltip
		end
	end

	-- If in an instance (or etc.) and Rallied
	if unitPlayer:IsRallied() and tStats.nEffectiveLevel ~= tStats.nLevel then
		strName = String_GetWeaselString(Apollo.GetString("BaseBar_RallyAppend"), strName, tStats.nEffectiveLevel)
		strTooltip = "<P Font=\"CRB_InterfaceSmall_O\">"..Apollo.GetString("BaseBar_YouAreRallyingTooltip").."</P>"..strTooltip
	end

	-- PvP
	local tPvPFlagInfo = GameLib.GetPvpFlagInfo()
	if tPvPFlagInfo and tPvPFlagInfo.bIsFlagged then
		strName = String_GetWeaselString(Apollo.GetString("BaseBar_PvPAppend"), strName)
	end

	self.wndXPLevel:SetText(String_GetWeaselString(strXPorEP))
	self.wndPathLevel:SetText(strPathXP)

	self.wndMain:FindChild("XPBarContainer"):SetBGColor(self.bInCombat and ApolloColor.new("66ffffff") or ApolloColor.new("white"))
	self.wndMain:FindChild("XPBarContainer"):SetTooltip(strTooltip)
	self.wndXPLevel:SetTooltip(strTooltip)
	
	self.wndMain:FindChild("PathBarContainer"):SetTooltip(strPathTooltip)
	self.wndPathLevel:SetTooltip(strPathTooltip)
	
	--Toggle Visibility based on ui preference
	local nVisibility = Apollo.GetConsoleVariable("hud.xpBarDisplay")
	
	if nVisibility == 1 then -- always on
		self.wndMain:Show(true)
	elseif nVisibility == 2 then --always off
		self.wndMain:Show(false)
	elseif nVisibility == 3 then --on in combat
		self.wndMain:Show(unitPlayer:IsInCombat())	
	elseif nVisibility == 4 then --on out of combat
		self.wndMain:Show(not unitPlayer:IsInCombat())
	else
		--If the player has any XP draw the bars and set the preference to 1 automatically.
		--else hide the bar until the player earns some XP, then trigger a tutorial prompt
		self.wndMain:Show(false)
	end
	
	self.wndArt:Show(true)
	self:OnUpdateInventory()
end

-----------------------------------------------------------------------------------------------
-- Path XP
-----------------------------------------------------------------------------------------------

function XPBar:RedrawPathXP()
	if not PlayerPathLib then
		return 0
	end
	
	local nCurrentLevel = PlayerPathLib.GetPathLevel()
	local nNextLevel = math.min(knMaxPathLevel, nCurrentLevel + 1)

	local nLastLevelXP = PlayerPathLib.GetPathXPAtLevel(nCurrentLevel)
	local nCurrentXP =  PlayerPathLib.GetPathXP() - nLastLevelXP
	local nNeededXP = PlayerPathLib.GetPathXPAtLevel(nNextLevel) - nLastLevelXP
	
	local wndPathBarFill = self.wndMain:FindChild("PathBarContainer:PathBarFill")
	wndPathBarFill:SetMax(nNeededXP)
	wndPathBarFill:SetProgress(nCurrentXP)
	
	local ePathId = PlayerPathLib.GetPlayerPathType()
	local wndPathIcon = self.wndMain:FindChild("PathIcon")
	wndPathIcon:SetSprite(ktPathIcon[ePathId])
	
	if nNeededXP == 0 then
		wndPathBarFill:SetMax(100)
		wndPathBarFill:SetProgress(100)
		return 100
	end
	
	return nCurrentXP / nNeededXP * 100
end

function XPBar:ConfigurePathXPTooltip(unitPlayer)
	if not PlayerPathLib then
		return ""
	end
	
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end
	
	local strPathType = c_arPathStrings[unitPlayer:GetPlayerPathType()] or ""
	
	local nCurrentLevel = PlayerPathLib.GetPathLevel()
	local nNextLevel = math.min(knMaxPathLevel, nCurrentLevel + 1)

	local nLastLevelXP = PlayerPathLib.GetPathXPAtLevel(nCurrentLevel)
	local nCurrentXP =  PlayerPathLib.GetPathXP() - nLastLevelXP
	local nNeededXP = PlayerPathLib.GetPathXPAtLevel(nNextLevel) - nLastLevelXP
	
	local strTooltip = nNeededXP > 0 and string.format("<P Font=\"CRB_InterfaceSmall_O\">%s</P>", String_GetWeaselString(Apollo.GetString("Base_XPValue"), Apollo.FormatNumber(nCurrentXP, 0, true), Apollo.FormatNumber(nNeededXP, 0, true), nCurrentXP / nNeededXP * 100)) or ""
	
	return string.format("<P Font=\"CRB_InterfaceSmall_O\">%s %s%s</P>%s", Apollo.GetString(strPathType), Apollo.GetString("CRB_Level_"), nCurrentLevel, strTooltip)
end

-----------------------------------------------------------------------------------------------
-- Elder Points (When at max level)
-----------------------------------------------------------------------------------------------

function XPBar:RedrawEP()
	local nCurrentEP = GetPeriodicElderPoints()
	local nEPDailyMax = GameLib.ElderPointsDailyMax
	local nRestedEP = GetRestXp() 							-- amount of rested xp
	local nRestedEPPool = GetRestXpKillCreaturePool() 		-- amount of rested xp remaining from creature kills

	if not nCurrentEP or not nEPDailyMax or not nRestedEP then
		return
	end
	
	local wndXPBarFill = self.wndMain:FindChild("XPBarContainer:XPBarFill")
	local wndRestXPBarFill = self.wndMain:FindChild("XPBarContainer:RestXPBarFill")
	local wndRestXPBarGoal = self.wndMain:FindChild("XPBarContainer:RestXPBarGoal")

	wndXPBarFill:SetMax(nEPDailyMax)
	wndXPBarFill:SetProgress(nCurrentEP)

	-- Rest Bar and Goal (where it ends)
	wndRestXPBarFill:SetMax(nEPDailyMax)
	wndRestXPBarFill:Show(nRestedEP and nRestedEP > 0)
	if nRestedEP and nRestedEP > 0 then
		wndRestXPBarFill:SetProgress(math.min(nEPDailyMax, nCurrentEP + nRestedEP))
	end

	local bShowRestEPGoal = nRestedEP and nRestedEPPool and nRestedEP > 0 and nRestedEPPool > 0
	wndRestXPBarGoal:SetMax(nEPDailyMax)
	wndRestXPBarGoal:Show(bShowRestEPGoal)
	if bShowRestEPGoal then
		wndRestXPBarGoal:SetProgress(math.min(nEPDailyMax, nCurrentEP + nRestedEPPool))
	end

	return nCurrentEP / nEPDailyMax * 100
end

function XPBar:ConfigureEPTooltip(unitPlayer)
	local nCurrentEP = GetElderPoints()
	local nCurrentToDailyMax = GetPeriodicElderPoints()
	local nEPToAGem = GameLib.ElderPointsPerGem
	local nEPDailyMax = GameLib.ElderPointsDailyMax

	local nRestedEP = GetRestXp() 							-- amount of rested xp
	local nRestedEPPool = GetRestXpKillCreaturePool() 		-- amount of rested xp remaining from creature kills

	if not nCurrentEP or not nEPToAGem or not nEPDailyMax then
		return
	end

	-- Top String
	local strTooltip = String_GetWeaselString(Apollo.GetString("BaseBar_ElderPointsPercent"), Apollo.FormatNumber(nCurrentEP, 0, true), Apollo.FormatNumber(nEPToAGem, 0, true), nCurrentEP / nEPToAGem * 100)
	if nCurrentEP == nEPDailyMax then
		strTooltip = "<P Font=\"CRB_InterfaceSmall_O\">" .. strTooltip .. "</P><P Font=\"CRB_InterfaceSmall_O\">" .. Apollo.GetString("BaseBar_ElderPointsAtMax") .. "</P>"
	else
		local strDailyMax = String_GetWeaselString(Apollo.GetString("BaseBar_ElderPointsWeeklyMax"), Apollo.FormatNumber(nCurrentToDailyMax, 0, true), Apollo.FormatNumber(nEPDailyMax, 0, true), nCurrentToDailyMax / nEPDailyMax * 100)
		strTooltip = "<P Font=\"CRB_InterfaceSmall_O\">" .. strTooltip .. "</P><P Font=\"CRB_InterfaceSmall_O\">" .. strDailyMax .. "</P>"
	end

	-- Rested
	if nRestedEP > 0 then
		local strRestLineOne = String_GetWeaselString(Apollo.GetString("Base_EPRested"), Apollo.FormatNumber(nRestedEP, 0, true), nRestedEP / nEPDailyMax * 100)
		strTooltip = string.format("%s<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffda69ff\">%s</P>", strTooltip, strRestLineOne)

		if nCurrentEP + nRestedEPPool > nEPDailyMax then
			strTooltip = string.format("%s<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffda69ff\">%s</P>", strTooltip, Apollo.GetString("Base_EPRestedEndsAfterLevelTooltip"))
		else
			local strRestLineTwo = String_GetWeaselString(Apollo.GetString("Base_EPRestedPoolTooltip"), Apollo.FormatNumber(nRestedEPPool, 0, true), ((nRestedEPPool + nCurrentEP)  / nEPDailyMax) * 100)
			strTooltip = string.format("%s<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffda69ff\">%s</P>", strTooltip, strRestLineTwo)
		end
	end
	
	return string.format("<P Font=\"CRB_InterfaceSmall_O\">%s%s</P>%s", Apollo.GetString("CRB_Level_"), unitPlayer:GetLevel(), strTooltip)
end

-----------------------------------------------------------------------------------------------
-- XP (When less than level 50)
-----------------------------------------------------------------------------------------------

function XPBar:RedrawXP()
	local nCurrentXP = GetXp() - GetXpToCurrentLevel() 		-- current amount of xp into the current level
	local nNeededXP = GetXpToNextLevel() 					-- total amount needed to move through current level
	local nRestedXP = GetRestXp() 							-- amount of rested xp
	local nRestedXPPool = GetRestXpKillCreaturePool() 		-- amount of rested xp remaining from creature kills

	if not nCurrentXP or not nNeededXP or not nNeededXP or not nRestedXP then
		return
	end
	
	local wndXPBarFill = self.wndMain:FindChild("XPBarContainer:XPBarFill")
	local wndRestXPBarFill = self.wndMain:FindChild("XPBarContainer:RestXPBarFill")
	local wndRestXPBarGoal = self.wndMain:FindChild("XPBarContainer:RestXPBarGoal")

	wndXPBarFill:SetMax(nNeededXP)
	wndXPBarFill:SetProgress(nCurrentXP)

	wndRestXPBarFill:SetMax(nNeededXP)
	wndRestXPBarFill:Show(nRestedXP and nRestedXP > 0)
	if nRestedXP and nRestedXP > 0 then
		wndRestXPBarFill:SetProgress(math.min(nNeededXP, nCurrentXP + nRestedXP))
	end

	wndRestXPBarGoal:SetMax(nNeededXP)
	wndRestXPBarGoal:Show(nRestedXP and nRestedXPPool and nRestedXP > 0 and nRestedXPPool > 0)
	if nRestedXP and nRestedXPPool and nRestedXP > 0 and nRestedXPPool > 0 then
		wndRestXPBarGoal:SetProgress(math.min(nNeededXP, nCurrentXP + nRestedXPPool))
	end

	return nCurrentXP / nNeededXP * 100
end

function XPBar:ConfigureXPTooltip(unitPlayer)
	local nCurrentXP = GetXp() - GetXpToCurrentLevel() 		-- current amount of xp into the current level
	local nNeededXP = GetXpToNextLevel() 					-- total amount needed to move through current level
	local nRestedXP = GetRestXp() 							-- amount of rested xp
	local nRestedXPPool = GetRestXpKillCreaturePool() 		-- amount of rested xp remaining from creature kills

	if not nCurrentXP or not nNeededXP or not nNeededXP or not nRestedXP then
		return
	end

	local strTooltip = string.format("<P Font=\"CRB_InterfaceSmall_O\">%s</P>", String_GetWeaselString(Apollo.GetString("Base_XPValue"), Apollo.FormatNumber(nCurrentXP, 0, true), Apollo.FormatNumber(nNeededXP, 0, true), nCurrentXP / nNeededXP * 100))
	if nRestedXP > 0 then
		local strRestLineOne = String_GetWeaselString(Apollo.GetString("Base_XPRested"), Apollo.FormatNumber(nRestedXP, 0, true), nRestedXP / nNeededXP * 100)
		strTooltip = string.format("%s<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffda69ff\">%s</P>", strTooltip, strRestLineOne)

		if nCurrentXP + nRestedXPPool > nNeededXP then
			strTooltip = string.format("%s<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffda69ff\">%s</P>", strTooltip, Apollo.GetString("Base_XPRestedEndsAfterLevelTooltip"))
		else
			local strRestLineTwo = String_GetWeaselString(Apollo.GetString("Base_XPRestedPoolTooltip"), Apollo.FormatNumber(nRestedXPPool, 0, false), ((nRestedXPPool + nCurrentXP)  / nNeededXP) * 100)
			strTooltip = string.format("%s<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffda69ff\">%s</P>", strTooltip, strRestLineTwo)
		end
	end
	
	return string.format("<P Font=\"CRB_InterfaceSmall_O\">%s%s</P>%s", Apollo.GetString("CRB_Level_"), unitPlayer:GetLevel(), strTooltip)
end

-----------------------------------------------------------------------------------------------
-- Events to Redraw All
-----------------------------------------------------------------------------------------------

function XPBar:OnEnteredCombat(unitArg, bInCombat)
	if unitArg == GameLib.GetPlayerUnit() then
		self.bInCombat = bInCombat
		self:RedrawAll()
	end
end

function XPBar:OnClearCombatFlag()
	self.bInCombat = false
	self:RedrawAll()
end

function XPBar:OnXpChanged()
	if GetXp() == 0 then
		return
	end
	
	local nVisibility = Apollo.GetConsoleVariable("hud.xpBarDisplay")
	
	--NEW Player Experience: Set the xp bars to Always Show once you've started earning experience.
	if nVisibility == nil or nVisibility < 1 then
		--Trigger a HUD Tutorial
		Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "xpBarDisplay")
	end
	
	self:RedrawAll()
end

function XPBar:OnPathClicked()
	Event_FireGenericEvent("PlayerPathShow")
end

function XPBar:OnXpClicked()
	Event_FireGenericEvent("ToggleCharacterWindow")
end

function XPBar:OnUpdateInventory()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end
	
	self.wndInvokeForm:FindChild("MainCashWindow"):SetAmount(GameLib.GetPlayerCurrency(), false)
	self.wndMain:FindChild("ElderGems"):SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.ElderGems), true)

	local nOccupiedInventory = #unitPlayer:GetInventoryItems() or 0
	local nTotalInventory = GameLib.GetTotalInventorySlots() or 0
	local nAvailableInventory = nTotalInventory - nOccupiedInventory

	local strOpenColor = ""
	if nOccupiedInventory == nTotalInventory then
		strOpenColor = kstrRed
		self.wndInvokeButton:ChangeArt("HUD_BottomBar:btn_HUD_InventoryFull")
	elseif nOccupiedInventory >= nTotalInventory - 3 then
		strOpenColor = kstrOrange
		self.wndInvokeButton:ChangeArt("HUD_BottomBar:btn_HUD_Inventory")
	else
		strOpenColor = kstrBlue
		self.wndInvokeButton:ChangeArt("HUD_BottomBar:btn_HUD_Inventory")
	end

	local strPrefix = ""
	
	if nOccupiedInventory < 10 then strPrefix = "<T TextColor=\"00000000\">.</T>" end
	local strAMLCode = string.format("%s<T Font=\"CRB_Pixel\" Align=\"Right\" TextColor=\"%s\">%s<T TextColor=\"%s\">/%s</T></T>", strPrefix, strOpenColor, nOccupiedInventory, kstrDarkBlue, nTotalInventory)
	self.wndInvokeForm:FindChild("InvokeBtn"):SetText(tostring(nAvailableInventory))	
	self.wndInvokeForm:FindChild("InvokeBtn"):SetTooltip(strAMLCode)

	self.wndQuestItemNotice:Show(GameLib.DoAnyItemsBeginQuest())
end

function XPBar:OnToggleFromDatachronIcon()
	Event_FireGenericEvent("InterfaceMenu_ToggleInventory")
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function XPBar:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.Inventory then return end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndInvokeForm:GetRect()

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

local BaseBarCornerInst = XPBar:new()
BaseBarCornerInst:Init()
Template="Default" TooltipType="OnCursor" Name="BankItem" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" Sprite="BK3:UI_BK3_Holo_InsetSimple" Picture="1" IgnoreMouse="1" HideInEditor="0" Tooltip="">
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="6" TAnchorPoint="0" TAnchorOffset="6" RAnchorPoint="1" RAnchorOffset="-6" BAnchorPoint="1" BAnchorOffset="-5" RelativeToClient="1" Font="CRB_InterfaceSmall_O" Text="" Template="Default" TooltipType="OnCursor" Name="BankItemIcon" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" Sprite="" Picture="1" IgnoreMouse="0" DT_RIGHT="1" DT_BOTTOM="1" Tooltip="">
            <Event Name="QueryDragDrop" Function="OnBankItemQueryDragDrop"/>
            <Event Name="DragDrop" Function="OnBankItemEndDragDrop"/>
            <Event Name="QueryBeginDragDrop" Function="OnBankItemBeginDragDrop"/>
            <Event Name="MouseButtonDown" Function="OnBankItemBeginDragDrop"/>
            <Event Name="DragDropCancel" Function="OnBankItemDragDropCancel"/>
            <Event Name="DragDropEnd" Function="OnBankItemDragDropEnd"/>
        </Control>
    </Form>
    <Form Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="0" RAnchorOffset="298" BAnchorPoint="0" BAnchorOffset="47" RelativeToClient="1" Font="CRB_InterfaceSmall_O" Text="" Template="Default" TooltipType="OnCursor" Name="PermissionsGridRow" BGColor="ffffffff" TextColor="ff2f94ac" TooltipColor="" Sprite="" Picture="1" IgnoreMouse="1" DT_VCENTER="1" TextId="" Tooltip="">
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="16" TAnchorPoint="0" TAnchorOffset="-2" RAnchorPoint="1" RAnchorOffset="-170" BAnchorPoint="1" BAnchorOffset="-4" RelativeToClient="1" Font="CRB_InterfaceSmall" Text="" Template="Default" TooltipType="OnCursor" Name="PermissionsGridRowText" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" DT_VCENTER="1" TextId="GuildBank_BankTab" DT_RIGHT="1" DT_WORDBREAK="1" Picture="0" IgnoreMouse="1" Sprite=""/>
        <Control Class="Window" LAnchorPoint=".5" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="-4" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="PermissionsGridRowBG" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" Sprite="CRB_Basekit:kitInnerFrame_Holo_SimpleInset" Picture="1" IgnoreMouse="1" Tooltip="">
            <Control Class="Button" Base="BK3:btnHolo_Check" Font="Thick" ButtonType="PushButton" RadioGroup="" LAnchorPoint="0" LAnchorOffset="12" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="0" RAnchorOffset="47" BAnchorPoint="1" BAnchorOffset="0" DT_VCENTER="1" DT_CENTER="1" TooltipType="OnCursor" Name="PermissionGridBtnVisible" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" NormalTextColor="ffffffff" PressedTextColor="ffffffff" FlybyTextColor="ffffffff" PressedFlybyTextColor="ffffffff" DisabledTextColor="ffffffff" Text="" RelativeToClient="1" TooltipFont="CRB_InterfaceSmall_O" Tooltip="" TooltipId="GuildBank_ToggleVisibility">
                <Event Name="ButtonSignal" Function="OnPermissionGridBtnVisibleDeposit"/>
            </Control>
            <Control Class="Button" Base="BK3:btnHolo_Check" Font="Thick" ButtonType="PushButton" RadioGroup="" LAnchorPoint="0.5" LAnchorOffset="-13" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="0.5" RAnchorOffset="22" BAnchorPoint="1" BAnchorOffset="0" DT_VCENTER="1" DT_CENTER="1" TooltipType="OnCursor" Name="PermissionGridBtnDeposit" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" NormalTextColor="ffffffff" PressedTextColor="ffffffff" FlybyTextColor="ffffffff" PressedFlybyTextColor="ffffffff" DisabledTextColor="ffffffff" Text="" RelativeToClient="1" Tooltip="" TooltipFont="CRB_Interfac