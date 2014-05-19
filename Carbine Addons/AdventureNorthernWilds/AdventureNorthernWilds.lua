-----------------------------------------------------------------------------------------------
-- Client Lua Script for NorthernWildsAdv
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "PublicEvent"

local NorthernWildsAdv = {}

local knSaveVersion = 1

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
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc

	local tSave = self.tAdventureInfo
	tSave.tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil
	tSave.nSaveVersion = knSaveVersion
	
	return tSave
end

function NorthernWildsAdv:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	local bIsNorthernWilds = false
	local tActiveEvents = PublicEvent.GetActiveEvents()
	
	for idx, peEvent in pairs(tActiveEvents) do
		if peEvent:GetEventType() == PublicEvent.PublicEventType_Adventure_NorthernWilds then
			bIsNorthernWilds = true
		end
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedLocation = WindowLocation.new(tSavedData.tWindowLocation)
	end
	self.tAdventureInfo = {}
	if bIsNorthernWilds and tSavedData.bIsShown then
		self:UIShow()
		self:UILevel(tSavedData.nLevel or 0)
		self:UIProgress(tSavedData.nProgress or 0)
		self:UISkeech(tSavedData.nSkeech or 0)
		self:UIMoodie(tSavedData.nMoodie or 0)
		self:UIMeleeShrine(tSavedData.nPlayerMeleeUpgrade or 0, tSavedData.nEnemyMeleeUpgrade or 0)
		self:UIMagicShrine(tSavedData.nPlayerMagicUpgrade or 0, tSavedData.nEnemyMagicUpgrade or 0)
		self:UIHunterShrine(tSavedData.nPlayerHunterUpgrade or 0, tSavedData.nEnemyHunterUpgrade or 0)
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

	Apollo.RegisterEventHandler("ChangeWorld", "UIHide", self)
	
	if not self.tAdventureInfo then 
		self.tAdventureInfo = {}
	end
end

function NorthernWildsAdv:UIShow()
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "AdventureNorthernWildsForm", nil, self)
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
	end
end

function NorthernWildsAdv:UIHide()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	self.locSavedLocation = self.wndMain:GetLocation()
	self.wndMain:Destroy()
	self.tAdventureInfo = {}
end

function NorthernWildsAdv:UIProgress(nCurrentProgress)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	self.tAdventureInfo.nProgress = nCurrentProgress

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
	
	self.tAdventureInfo.nLevel = nCurrentLevel

	if nCurrentLevel and nCurrentLevel < 10 then
		self.wndMain:FindChild("LevelBarBG:LevelProgressText"):SetData(nCurrentLevel)
	else
		self.wndMain:FindChild("LevelBarBG:LevelProgressText"):SetData(-1)
	end
end

function NorthernWildsAdv:UISkeech(nCurrentSkeech)
	if not self.wndMain or not self.wndMain:IsValid() then
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
	if not self.wndMain or not self.wndMain:IsValid() then
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
-----------------------------------------------------------------------------------------------
-- NorthernWildsAdv Instance
-----------------------------------------------------------------------------------------------
local NorthernWildsAdvInst = NorthernWildsAdv:new()
NorthernWildsAdvInst:Init()
