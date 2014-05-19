-----------------------------------------------------------------------------------------------
-- Client Lua Script for RaidFrameMasterLoot
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local RaidFrameMasterLoot = {}

local knSaveVersion = 3

function RaidFrameMasterLoot:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RaidFrameMasterLoot:Init()
    Apollo.RegisterAddon(self)
end

function RaidFrameMasterLoot:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSaved = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	
	return tSaved
end

function RaidFrameMasterLoot:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function RaidFrameMasterLoot:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RaidFrameMasterLoot.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function RaidFrameMasterLoot:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("GenericEvent_Raid_ToggleMasterLoot", "Initialize", self)
end

function RaidFrameMasterLoot:Initialize(bShow)
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end

	if not bShow then
		return
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "RaidFrameMasterLootForm", nil, self)
	self.wndMain:SetSizingMinimum(self.wndMain:GetWidth(), self.wndMain:GetHeight())
	self.wndMain:SetSizingMaximum(self.wndMain:GetWidth(), 1000)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self:InitializeGroupSettings()
end

-----------------------------------------------------------------------------------------------
-- Group Options
-----------------------------------------------------------------------------------------------

function RaidFrameMasterLoot:InitializeGroupSettings()
	local tLootRules = GroupLib.GetLootRules()

	local tUnderMapping =
	{
		[GroupLib.LootRule.Master] 				= "UnderThresMasterBtn",
		[GroupLib.LootRule.RoundRobin] 			= "UnderThresRRBtn",
		[GroupLib.LootRule.FreeForAll] 			= "UnderThresFFABtn",
		[GroupLib.LootRule.NeedBeforeGreed] 	= "UnderThresNvGBtn",
	}

	local tOverMapping =
	{
		[GroupLib.LootRule.Master] 				= "OverThresMasterBtn",
		[GroupLib.LootRule.RoundRobin] 			= "OverThresRRBtn",
		[GroupLib.LootRule.FreeForAll] 			= "OverThresFFABtn",
		[GroupLib.LootRule.NeedBeforeGreed] 	= "OverThresNvGBtn",
	}

	local tHarvestMapping =
	{
		[GroupLib.HarvestLootRule.RoundRobin]  	= "HarvestThresRRBtn",
		[GroupLib.HarvestLootRule.FirstTagger] 	= "HarvestThresFFABtn",
	}

	local tItemMapping =
	{
		[Item.CodeEnumItemQuality.Inferior] 	= 1,
		[Item.CodeEnumItemQuality.Average] 		= 1,
		[Item.CodeEnumItemQuality.Good] 		= 2,
		[Item.CodeEnumItemQuality.Excellent] 	= 3,
		[Item.CodeEnumItemQuality.Superb] 		= 4,
		[Item.CodeEnumItemQuality.Legendary] 	= 5,
		[Item.CodeEnumItemQuality.Artifact] 	= 6
	}

	if tUnderMapping[tLootRules.eNormalRule] then
		self.wndMain:FindChild(tUnderMapping[tLootRules.eNormalRule]):SetCheck(true)
	end

	if tOverMapping[tLootRules.eThresholdRule] then
		self.wndMain:FindChild(tOverMapping[tLootRules.eThresholdRule]):SetCheck(true)
	end

	if tHarvestMapping[tLootRules.eHarvestRule] then
		self.wndMain:FindChild(tHarvestMapping[tLootRules.eHarvestRule]):SetCheck(true)
	end

	for eValue, nIdx in pairs(tItemMapping) do
		if eValue == tLootRules.eThresholdQuality then
			self.wndMain:FindChild("ItemThresBtn"..nIdx):SetCheck(true)
		end
	end
end

function RaidFrameMasterLoot:OnSetLootUnderThresCheck(wndHandler, wndControl)
	local tLootRules =
	{
		["UnderThresMasterBtn"] = GroupLib.LootRule.Master,
		["UnderThresNvGBtn"] 	= GroupLib.LootRule.NeedBeforeGreed,
		["UnderThresRRBtn"] 	= GroupLib.LootRule.RoundRobin,
		["UnderThresFFABtn"] 	= GroupLib.LootRule.FreeForAll,
	}

	if tLootRules[wndHandler:GetName()] then
		local tCurrRules = GroupLib.GetLootRules()
		GroupLib.SetLootRules(tLootRules[wndHandler:GetName()], tCurrRules.eThresholdRule, tCurrRules.eThresholdQuality, tCurrRules.eHarvestRule)
	end
end

function RaidFrameMasterLoot:OnSetLootOverThresCheck(wndHandler, wndControl)
	local tLootRules =
	{
		["OverThresMasterBtn"] 	= GroupLib.LootRule.Master,
		["OverThresNvGBtn"] 	= GroupLib.LootRule.NeedBeforeGreed,
		["OverThresRRBtn"] 		= GroupLib.LootRule.RoundRobin,
		["OverThresFFABtn"] 	= GroupLib.LootRule.FreeForAll,
	}

	if tLootRules[wndHandler:GetName()] then
		local tCurrRules = GroupLib.GetLootRules()
		GroupLib.SetLootRules(tCurrRules.eNormalRule, tLootRules[wndHandler:GetName()], tCurrRules.eThresholdQuality, tCurrRules.eHarvestRule)
	end
end

function RaidFrameMasterLoot:OnSetHarvestRulesCheck(wndHandler, wndControl)
	local tLootRules =
	{
		["HarvestThresRRBtn"] 	= GroupLib.HarvestLootRule.RoundRobin,
		["HarvestThresFFABtn"] 	= GroupLib.HarvestLootRule.FirstTagger,
	}

	if tLootRules[wndHandler:GetName()] then
		local tCurrRules = GroupLib.GetLootRules()
		GroupLib.SetLootRules(tCurrRules.eNormalRule, tCurrRules.eThresholdRule, tCurrRules.eThresholdQuality, tLootRules[wndHandler:GetName()])
	end
end

function RaidFrameMasterLoot:OnSetLootItemThresCheck(wndHandler, wndControl)
	local tItemMapping =
	{
		["ItemThresBtn1"] = Item.CodeEnumItemQuality.Average,
		["ItemThresBtn2"] = Item.CodeEnumItemQuality.Good,
		["ItemThresBtn3"] = Item.CodeEnumItemQuality.Excellent,
		["ItemThresBtn4"] = Item.CodeEnumItemQuality.Superb,
		["ItemThresBtn5"] = Item.CodeEnumItemQuality.Legendary,
		["ItemThresBtn6"] = Item.CodeEnumItemQuality.Artifact
	}

	if tItemMapping[wndHandler:GetName()] then
		local tCurrRules = GroupLib.GetLootRules()
		GroupLib.SetLootRules(tCurrRules.eNormalRule, tCurrRules.eThresholdRule, tItemMapping[wndHandler:GetName()], tCurrRules.eHarvestRule)
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function RaidFrameMasterLoot:OnOptionsCloseBtn()
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		Event_FireGenericEvent("GenericEvent_Raid_UncheckMasterLoot")
	end
end

function RaidFrameMasterLoot:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

local RaidFrameMasterLootInst = RaidFrameMasterLoot:new()
RaidFrameMasterLootInst:Init()
