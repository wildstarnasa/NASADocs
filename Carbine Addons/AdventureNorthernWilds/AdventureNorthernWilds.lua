-----------------------------------------------------------------------------------------------
-- Client Lua Script for NorthernWildsAdv
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
-- War of the Wilds UI

require "Window"
require "PublicEvent"

local NorthernWildsAdv = {}

local knSaveVersion = 2

function NorthernWildsAdv:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NorthernWildsAdv:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return false
	end
	
	local tSave = 
	{
		tAdventureInfo = self.tAdventureInfo,
		nSaveVersion = knSaveVersion,
	}
	
	return tSave
end

function NorthernWildsAdv:OnRestore(eType, tSavedData)
	self.tSavedData = tSavedData
	if tSavedData and tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tAdventureInfo then
		self.tSavedInfo = tSavedData.tAdventureInfo
	end
end

function NorthernWildsAdv:Init()
    Apollo.RegisterAddon(self)
end

function NorthernWildsAdv:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AdventureNorthernWilds.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function NorthernWildsAdv:OnDocumentReady()
	Apollo.RegisterEventHandler("NWADV_ShowUI", "UIShow", self)
    Apollo.RegisterEventHandler("NWADV_HideUI", "UIHide", self)
    Apollo.RegisterEventHandler("NWADV_UpdateProgress", "UIProgress", self)
    Apollo.RegisterEventHandler("NWADV_UpdateLevel", "UILevel", self)
    Apollo.RegisterEventHandler("NWADV_SkeechBases", "UISkeech", self)
    Apollo.RegisterEventHandler("NWADV_MoodieBases", "UIMoodie", self)
	Apollo.RegisterEventHandler("NWADV_MeleeShrine", "UIMeleeShrine", self)
	Apollo.RegisterEventHandler("NWADV_MagicShrine", "UIMagicShrine", self)
	Apollo.RegisterEventHandler("NWADV_HunterShrine", "UIHunterShrine", self)
	Apollo.RegisterEventHandler("NWADV_KillDeathRatio", "UIKDR", self)
	Apollo.RegisterEventHandler("OnInstanceResetResult", "ResetInstance", self)

	Apollo.RegisterEventHandler("ChangeWorld", "UIHide", self)
	
	local bIsNorthernWilds = false
	local tActiveEvents = PublicEvent.GetActiveEvents()
	for idx, peEvent in pairs(tActiveEvents) do
		if peEvent:GetEventType() == PublicEvent.PublicEventType_Adventure_NorthernWilds then
			bIsNorthernWilds = true
		end
	end
	
	self.tAdventureInfo = {}
	if bIsNorthernWilds and self.tSavedInfo and self.tSavedInfo.bIsShown then
		self:UIShow()
	end
end

function NorthernWildsAdv:ResetInstance()
	self.tSavedInfo = nil
	self.tAdventureInfo = {}
end

function NorthernWildsAdv:UIShow()
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "AdventureNorthernWildsForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Lore_NorthernWilds")})
		
		self.wndMain:FindChild("LeftAssetCostume"):SetCostumeToCreatureId(20668) -- TODO Hardcoded
		self.wndMain:FindChild("LeftAssetCostume"):SetModelSequence(150)
		self.wndMain:FindChild("RightAssetCostume"):SetCostumeToCreatureId(26431)
		self.wndMain:FindChild("RightAssetCostume"):SetModelSequence(150)
		
		if self.locSavedLocation then
			self.wndMain:MoveToLocation(self.locSavedLocation)
		end
	
		self.wndMain:Show(true)
		self.tAdventureInfo.bIsShown = true
		self:UILevel(0)
		self:UIProgress(0)
		
		if self.tSavedInfo then
			self:UILevel(self.tSavedInfo.nLevel or 0)
			self:UIProgress(self.tSavedInfo.nProgress or 0)
			self:UISkeech(self.tSavedInfo.nSkeech or 0)
			self:UIMoodie(self.tSavedInfo.nMoodie or 0)
			self:UIMeleeShrine(self.tSavedInfo.nPlayerMeleeUpgrade or 0, self.tSavedInfo.nEnemyMeleeUpgrade or 0)
			self:UIMagicShrine(self.tSavedInfo.nPlayerMagicUpgrade or 0, self.tSavedInfo.nEnemyMagicUpgrade or 0)
			self:UIHunterShrine(self.tSavedInfo.nPlayerHunterUpgrade or 0, self.tSavedInfo.nEnemyHunterUpgrade or 0)
		end
	end
end

function NorthernWildsAdv:UIHide()
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedLocation = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
	
	local nGroupCount = GroupLib:GetMemberCount()
	local bIsGroupInMatch = false
	
	for idx = 1, nGroupCount do
		if not bIsGroupInMatch and GroupLib.IsMemberInGroupInstance(idx) then
			bIsGroupInMatch = true
		end
	end

	if not MatchingGame:IsInMatchingGame() and not bIsGroupInMatch then
		self:ResetInstance()
	end
end

function NorthernWildsAdv:UIProgress(nCurrentProgress)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	if nCurrentProgress > 0 then
		self.tAdventureInfo.nProgress = nCurrentProgress
	end

	local wndLevelProgressBar = self.wndMain:FindChild("LevelBarBG:LevelProgressBar")
	wndLevelProgressBar:SetMax(100)
	wndLevelProgressBar:SetProgress(nCurrentProgress)
	local wndLevelProgressText = self.wndMain:FindChild("LevelBarBG:LevelProgressText")
	local nLevel = wndLevelProgressText:GetData() or 0
	if nLevel == -1 then
		wndLevelProgressText:SetText(Apollo.GetString("NWAdventure_MaxLvl"))
	else
		wndLevelProgressText:SetText(String_GetWeaselString(Apollo.GetString("NWAdventure_LevelProgress"), nLevel, nCurrentProgress))
	end
end

function NorthernWildsAdv:UILevel(nCurrentLevel)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	if nCurrentLevel >= 0 then
		self.tAdventureInfo.nLevel = nCurrentLevel
	end

	if nCurrentLevel and nCurrentLevel < 10 then
		self.wndMain:FindChild("LevelBarBG:LevelProgressText"):SetData(nCurrentLevel)
	else
		self.wndMain:FindChild("LevelBarBG:LevelProgressText"):SetData(-1)
	end
end

function NorthernWildsAdv:UISkeech(nCurrentSkeech)
	if not self.wndMain or not self.wndMain:IsValid() or not nCurrentSkeech then
		return
	end
	self.wndMain:FindChild("LeftNumber"):SetText(nCurrentSkeech)

	tObjectiveInfo =
	{
		["count"] = nCurrentSkeech,
		["name"] = Apollo.GetString("NWAdventure_Totem"),
	}
	
	self.tAdventureInfo.nSkeech = nCurrentSkeech
	
	local strObjective = String_GetWeaselString(Apollo.GetString("CRB_MultipleNoNumber"), tObjectiveInfo)
	self.wndMain:FindChild("LeftNumberLabel"):SetText(strObjective)
end

function NorthernWildsAdv:UIMoodie(nCurrentMoodie)
	if not self.wndMain or not self.wndMain:IsValid() or not nCurrentMoodie then
		return
	end
	self.wndMain:FindChild("RightNumber"):SetText(nCurrentMoodie)

	tObjectiveInfo =
	{
		["count"] = nCurrentMoodie,
		["name"] = Apollo.GetString("NWAdventure_Totem"),
	}
	
	self.tAdventureInfo.nMoodie = nCurrentMoodie
	
	local strObjective = String_GetWeaselString(Apollo.GetString("CRB_MultipleNoNumber"), tObjectiveInfo)

	self.wndMain:FindChild("RightNumberLabel"):SetText(strObjective)
end

function NorthernWildsAdv:UIMeleeShrine(nPlayerUp, nEnemyUp)	-- Show Shrine upgrades for players and champions (0 = no upgrade, 1-2 = specific upgrade)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if nPlayerUp == 0 then
		self.wndMain:FindChild("LeftWndMeleeUpgrade1"):Show(false)
		self.wndMain:FindChild("LeftWndMeleeUpgrade2"):Show(false)
	elseif nPlayerUp == 1 then
		self.wndMain:FindChild("LeftWndMeleeUpgrade1"):Show(true)
		self.wndMain:FindChild("LeftWndMeleeUpgrade2"):Show(false)
	elseif nPlayerUp == 2 then
		self.wndMain:FindChild("LeftWndMeleeUpgrade1"):Show(false)
		self.wndMain:FindChild("LeftWndMeleeUpgrade2"):Show(true)
	end

	if nEnemyUp == 0 then
		self.wndMain:FindChild("RightWndMeleeUpgrade1"):Show(false)
		self.wndMain:FindChild("RightWndMeleeUpgrade2"):Show(false)
	elseif nEnemyUp == 1 then
		self.wndMain:FindChild("RightWndMeleeUpgrade1"):Show(true)
		self.wndMain:FindChild("RightWndMeleeUpgrade2"):Show(false)
	elseif nEnemyUp == 2 then
		self.wndMain:FindChild("RightWndMeleeUpgrade1"):Show(false)
		self.wndMain:FindChild("RightWndMeleeUpgrade2"):Show(true)
	end
	
	self.tAdventureInfo.nPlayerMeleeUpgrade = nPlayerUp
	self.tAdventureInfo.nEnemyMeleeUpgrade = nEnemyUp
end

function NorthernWildsAdv:UIMagicShrine(nPlayerUp, nEnemyUp)	-- Show Shrine upgrades for players and champions (0 = no upgrade, 1-2 = specific upgrade)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if nPlayerUp == 0 then
		self.wndMain:FindChild("LeftWndMagicUpgrade1"):Show(false)
		self.wndMain:FindChild("LeftWndMagicUpgrade2"):Show(false)
	elseif nPlayerUp == 1 then
		self.wndMain:FindChild("LeftWndMagicUpgrade1"):Show(true)
		self.wndMain:FindChild("LeftWndMagicUpgrade2"):Show(false)
	elseif nPlayerUp == 2 then
		self.wndMain:FindChild("LeftWndMagicUpgrade1"):Show(false)
		self.wndMain:FindChild("LeftWndMagicUpgrade2"):Show(true)
	end

	if nEnemyUp == 0 then
		self.wndMain:FindChild("RightWndMagicUpgrade1"):Show(false)
		self.wndMain:FindChild("RightWndMagicUpgrade2"):Show(false)
	elseif nEnemyUp == 1 then
		self.wndMain:FindChild("RightWndMagicUpgrade1"):Show(true)
		self.wndMain:FindChild("RightWndMagicUpgrade2"):Show(false)
	elseif nEnemyUp == 2 then
		self.wndMain:FindChild("RightWndMagicUpgrade1"):Show(false)
		self.wndMain:FindChild("RightWndMagicUpgrade2"):Show(true)
	end
	
	self.tAdventureInfo.nPlayerMagicUpgrade = nPlayerUp
	self.tAdventureInfo.nEnemyMagicUpgrade = nEnemyUp
end

function NorthernWildsAdv:UIHunterShrine(nPlayerUp, nEnemyUp)	-- Show Shrine upgrades for players and champions (0 = no upgrade, 1-2 = specific upgrade)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if nPlayerUp == 0 then
		self.wndMain:FindChild("LeftWndHuntUpgrade1"):Show(false)
		self.wndMain:FindChild("LeftWndHuntUpgrade2"):Show(false)
	elseif nPlayerUp == 1 then
		self.wndMain:FindChild("LeftWndHuntUpgrade1"):Show(true)
		self.wndMain:FindChild("LeftWndHuntUpgrade2"):Show(false)
	elseif nPlayerUp == 2 then
		self.wndMain:FindChild("LeftWndHuntUpgrade1"):Show(false)
		self.wndMain:FindChild("LeftWndHuntUpgrade2"):Show(true)
	end

	if nEnemyUp == 0 then
		self.wndMain:FindChild("RightWndHuntUpgrade1"):Show(false)
		self.wndMain:FindChild("RightWndHuntUpgrade2"):Show(false)
	elseif nEnemyUp == 1 then
		self.wndMain:FindChild("RightWndHuntUpgrade1"):Show(true)
		self.wndMain:FindChild("RightWndHuntUpgrade2"):Show(false)
	elseif nEnemyUp == 2 then
		self.wndMain:FindChild("RightWndHuntUpgrade1"):Show(false)
		self.wndMain:FindChild("RightWndHuntUpgrade2"):Show(true)
	end
	
	self.tAdventureInfo.nPlayerHunterUpgrade = nPlayerUp
	self.tAdventureInfo.nEnemyHunterUpgrade = nHunterUp
end

function NorthernWildsAdv:UIKDR(iKills, iDeaths)	-- Updates the kill death ratio
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

		self.wndMain:FindChild("KDRNumber"):SetText(iKills..":"..iDeaths)
end
-----------------------------------------------------------------------------------------------
-- NorthernWildsAdv Instance
-----------------------------------------------------------------------------------------------
local NorthernWildsAdvInst = NorthernWildsAdv:new()
NorthernWildsAdvInst:Init()
" TooltipType="OnCursor" Name="FatigueText" BGColor="white" TextColor="UI_TextHoloBody" TooltipColor="" TextId="" DT_CENTER="0" DT_VCENTER="1" IgnoreMouse="1" IgnoreTooltipDelay="1" Tooltip="" TooltipId="MalgraveAdv_FatigueTooltip" TooltipFont="CRB_InterfaceSmall_O" Picture="1" Sprite="IconSprites:Icon_Windows_UI_CRB_Adventure_Malgrave_Fatigue"/>
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="49" TAnchorPoint="1" TAnchorOffset="-47" RAnchorPoint="1" RAnchorOffset="-19" BAnchorPoint="1" BAnchorOffset="-22" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="FatigueBarBG" BGColor="white" TextColor="white" TooltipColor="" Sprite="CRB_Basekit:kitIProgBar_Holo_Base" Picture="1" IgnoreMouse="1" NewControlDepth="1" Tooltip="" TooltipFont="CRB_InterfaceSmall_O" TooltipId="MalgraveAdv_FatigueTooltip" IgnoreTooltipDelay="1">
            <Control Class="ProgressBar" Text="" LAnchorPoint="0" LAnchorOffset="10" TAnchorPoint="0" TAnchorOffset="5" RAnchorPoint="1" RAnchor