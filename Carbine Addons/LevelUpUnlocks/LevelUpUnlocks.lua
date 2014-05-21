-----------------------------------------------------------------------------------------------
-- Client Lua Script for LevelUpUnlocks
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Apollo"

local LevelUpUnlocks = {}

local knMaxLevel = 50
local knMaxPathLevel = 30
local knAutoHideReminderTime = 250
local knSaveVersion = 8

local ktUnlockMapping =
{
	[""] 													= 0,
	[GameLib.LevelUpUnlockType.Dungeon_New] 				= GameLib.CodeEnumInputAction.GroupFinder,						-- Dungeons:New Dungeon
	[GameLib.LevelUpUnlockType.Adventure_New] 				= GameLib.CodeEnumInputAction.GroupFinder,						-- Adventures: New Adventure
	[GameLib.LevelUpUnlockType.Content_Zone] 				= GameLib.CodeEnumInputAction.WorldMap,							-- Content: New Zones
	[GameLib.LevelUpUnlockType.Content_Feature] 			= 0,															-- Content: New Feature
	[GameLib.LevelUpUnlockType.Class_Feature] 				= 0, 															-- Classes: New Feature
	[GameLib.LevelUpUnlockType.Class_Ability] 				= 0, 															-- Classes: New Ability
	[GameLib.LevelUpUnlockType.Class_LAS_Slot] 				= GameLib.CodeEnumInputAction.LimitedActionSetBuilder, 			-- Classes: New LAS Slot
	[GameLib.LevelUpUnlockType.Class_Improvement] 			= GameLib.CodeEnumInputAction.LimitedActionSetBuilder, 			-- Classes: Improvement
	[GameLib.LevelUpUnlockType.PvP_Feature] 				= 0,															-- PVP: New Feature
	[GameLib.LevelUpUnlockType.PvP_Battleground] 			= GameLib.CodeEnumInputAction.GroupFinder,						-- PVP: New Battleground
	[GameLib.LevelUpUnlockType.Gear_Slot] 					= GameLib.CodeEnumInputAction.CharacterPanel,					-- Gear: New Gear Slot
	[GameLib.LevelUpUnlockType.Raid_20] 					= 0,															-- Raids: New 20-man
	[GameLib.LevelUpUnlockType.Raid_40] 					= 0,															-- Raids: New 40-man
	[GameLib.LevelUpUnlockType.Content_Capital] 			= GameLib.CodeEnumInputAction.WorldMap,							-- Content: Capital Cities
	[GameLib.LevelUpUnlockType.Class_Tier] 					= 0, 															-- Classes: New Tier
	[GameLib.LevelUpUnlockType.Path_Spell] 					= GameLib.CodeEnumInputAction.LimitedActionSetBuilder,			-- Path: Spell
	[GameLib.LevelUpUnlockType.Path_Title] 					= GameLib.CodeEnumInputAction.CharacterPanel, 					-- Path
	[GameLib.LevelUpUnlockType.Path_Quest] 					= 0, 															-- Path
	[GameLib.LevelUpUnlockType.Path_Item] 					= 0, 															-- Path
	[GameLib.LevelUpUnlockType.Path_ScanBot] 				= 0, 															-- Path
	[GameLib.LevelUpUnlockType.Social_Feature] 				= GameLib.CodeEnumInputAction.Social,							-- Social: New Feature
	[GameLib.LevelUpUnlockType.General_Feature] 			= 0,															-- General: New Feature
	[GameLib.LevelUpUnlockType.General_Expanded_Feature] 	= 0,															-- General: New Unlock of Existing Feature
}

local ktUnlockActions =
{
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AMPSystem, 					strEvent = "LevelUpUnlock_AMPSystem" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_TierPointSystem, 			strEvent = "LevelUpUnlock_TierPointSystem" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.GroupFinder_General, 				strEvent = "LevelUpUnlock_GroupFinder_General" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.GroupFinder_Dungeons, 				strEvent = "LevelUpUnlock_GroupFinder_Dungeons" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.GroupFinder_Adventures, 				strEvent = "LevelUpUnlock_GroupFinder_Adventures" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.GroupFinder_Arenas, 					strEvent = "LevelUpUnlock_GroupFinder_Arenas" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.GroupFinder_Warplots, 				strEvent = "LevelUpUnlock_GroupFinder_Warplots" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_CostumeSlot2, 				strEvent = "LevelUpUnlock_Character_CostumeSlot2" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_CostumeSlot3, 				strEvent = "LevelUpUnlock_Character_CostumeSlot3" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_CostumeSlot4, 				strEvent = "LevelUpUnlock_Character_CostumeSlot4" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_CostumeSlot5, 				strEvent = "LevelUpUnlock_Character_CostumeSlot5" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_CostumeSlot6, 				strEvent = "LevelUpUnlock_Character_CostumeSlot6" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Inventory_Salvage, 					strEvent = "LevelUpUnlock_Inventory_Salvage" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Customization_Mount, 				strEvent = "LevelUpUnlock_Customization_Mount" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Customization_Scanbot, 				strEvent = "LevelUpUnlock_Customization_Scanbot" }, --TODO
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_CostumeSystem, 			strEvent = "LevelUpUnlock_Character_CostumeSystem" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapAdventure_Astrovoid, 		strEvent = "LevelUpUnlock_WorldMapAdventure_Astrovoid" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapAdventure_Galeras, 			strEvent = "LevelUpUnlock_WorldMapAdventure_Galeras" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapAdventure_Hycrest, 			strEvent = "LevelUpUnlock_WorldMapAdventure_Hycrest" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapAdventure_Malgrave, 			strEvent = "LevelUpUnlock_WorldMapAdventure_Malgrave" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapAdventure_NorthernWilds,		strEvent = "LevelUpUnlock_WorldMapAdventure_NorthernWilds" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapAdventure_Whitevale, 		strEvent = "LevelUpUnlock_WorldMapAdventure_Whitevale" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AMPPoint, 					strEvent = "LevelUpUnlock_AMPPoint" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_NewTierPoint, 				strEvent = "LevelUpUnlock_NewTierPoint" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_LASSlot2, 					strEvent = "LevelUpUnlock_LASSlot2" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_LASSlot3, 					strEvent = "LevelUpUnlock_LASSlot3" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_LASSlot4, 					strEvent = "LevelUpUnlock_LASSlot4" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_LASSlot5, 					strEvent = "LevelUpUnlock_LASSlot5" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_LASSlot6, 					strEvent = "LevelUpUnlock_LASSlot6" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_LASSlot7, 					strEvent = "LevelUpUnlock_LASSlot7" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_LASSlot8, 					strEvent = "LevelUpUnlock_LASSlot8" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AbilityTier2, 				strEvent = "LevelUpUnlock_AbilityTier2" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AbilityTier3, 				strEvent = "LevelUpUnlock_AbilityTier3" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AbilityTier4, 				strEvent = "LevelUpUnlock_AbilityTier4" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AbilityTier5, 				strEvent = "LevelUpUnlock_AbilityTier5" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AbilityTier6, 				strEvent = "LevelUpUnlock_AbilityTier6" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AbilityTier7, 				strEvent = "LevelUpUnlock_AbilityTier7" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Builder_AbilityTier8, 				strEvent = "LevelUpUnlock_AbilityTier8" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapCapital_Thayd, 				strEvent = "LevelUpUnlock_WorldMapCapital_Thayd" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapCapital_Illium, 				strEvent = "LevelUpUnlock_WorldMapCapital_Illium" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Algoroc, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Algoroc" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Auroria, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Auroria" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Celestion,			strEvent = "LevelUpUnlock_WorldMapNewZone_Celestion" },
	{ strField = "nId",		eValue = GameLib.LevelUpUnlock.WorldMapNewZone_CrimsonIsle, 		strEvent = "LevelUpUnlock_WorldMapNewZone_CrimsonIsle" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Deradune, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Deradune" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Ellevar, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Ellevar" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_EverstarGrove, 		strEvent = "LevelUpUnlock_WorldMapNewZone_EverstarGrove" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Farside, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Farside" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Galeras, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Galeras" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Grimvault, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Grimvault" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_LevianBay, 			strEvent = "LevelUpUnlock_WorldMapNewZone_LevianBay" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Malgrave, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Malgrave" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_NorthernWilds, 		strEvent = "LevelUpUnlock_WorldMapNewZone_NorthernWilds" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Whitevale, 			strEvent = "LevelUpUnlock_WorldMapNewZone_Whitevale" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapNewZone_Wilderrun,			strEvent = "LevelUpUnlock_WorldMapNewZone_Wilderrun" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapDungeon_Stormtalon, 			strEvent = "LevelUpUnlock_WorldMapDungeon_Stormtalon" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapDungeon_KelVoreth, 			strEvent = "LevelUpUnlock_WorldMapDungeon_KelVoreth" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapDungeon_Skullcano, 			strEvent = "LevelUpUnlock_WorldMapDungeon_Skullcano" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.WorldMapDungeon_SwordMaiden, 		strEvent = "LevelUpUnlock_WorldMapDungeon_SwordMaiden" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_Gadgets, 			strEvent = "LevelUpUnlock_Character_GearSlot_Gadgets" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_Gloves, 			strEvent = "LevelUpUnlock_Character_GearSlot_Gloves" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_Helm, 			strEvent = "LevelUpUnlock_Character_GearSlot_Helm" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_Implants, 		strEvent = "LevelUpUnlock_Character_GearSlot_Implants" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_RaidKey, 			strEvent = "LevelUpUnlock_Character_GearSlot_RaidKey" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_Shield, 			strEvent = "LevelUpUnlock_Character_GearSlot_Shield" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_Shoulders, 		strEvent = "LevelUpUnlock_Character_GearSlot_Shoulders" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_SupportSystem, 	strEvent = "LevelUpUnlock_Character_GearSlot_SupportSystem" },
	{ strField = "nId", 	eValue = GameLib.LevelUpUnlock.Character_GearSlot_WeaponAttachment,	strEvent = "LevelUpUnlock_Character_GearSlot_WeaponAttachment" },
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.Class_Attribute, 				strEvent = "LevelUpUnlock_Class_Attribute" },
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.Class_Ability, 					strEvent = "LevelUpUnlock_Class_Ability" }, --TODO
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.Path_Item, 						strEvent = "LevelUpUnlock_Path_Item" },
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.Path_Quest, 						strEvent = "LevelUpUnlock_Path_Quest" },
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.Path_ScanBot, 					strEvent = "LevelUpUnlock_Path_ScanBot" },
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.Path_Spell, 						strEvent = "LevelUpUnlock_Path_Spell" },
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.Path_Title, 						strEvent = "LevelUpUnlock_Path_Title" },
	{ strField = "nType",	eValue = GameLib.LevelUpUnlockType.PvP_Battleground, 				strEvent = "LevelUpUnlock_PvP_Battleground" },
}

function LevelUpUnlocks:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function LevelUpUnlocks:Init()
    Apollo.RegisterAddon(self)
end

function LevelUpUnlocks:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local locReminderLocation = self.wndLevelUpUnlockReminder and self.wndLevelUpUnlockReminder:GetLocation() or self.locSavedReminderLoc
	local locMainLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedMainLoc

	local tSaved =
	{
		tReminderLocation = locReminderLocation and locReminderLocation:ToTable() or nil,
		tMainLocation = locMainLocation and locMainLocation:ToTable() or nil,
		nSavedVersion = knSaveVersion,
	}
	return tSaved
end

function LevelUpUnlocks:OnRestore(eType, tSavedData)
	self.tSavedData = tSavedData
	if not tSavedData or tSavedData.nSavedVersion ~= knSaveVersion then
		return
	end

	if tSavedData.tReminderLocation then
		self.locSavedReminderLoc = WindowLocation.new(tSavedData.tReminderLocation)
	end

	if tSavedData.tMainLocation then
		self.locSavedMainLoc = WindowLocation.new(tSavedData.tMainLocation)
	end
end

function LevelUpUnlocks:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("LevelUpUnlocks.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function LevelUpUnlocks:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 	"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("PathLevelUp", 					"OnPathLevelUp", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 			"OnPlayerLevelChange", self)
	Apollo.RegisterEventHandler("ToggleLevelUpUnlocks", 		"DisplayLevelUpUnlockPermanentWindow", self)
	Apollo.RegisterEventHandler("CharacterCreated", 			"Initialize", self)

	Apollo.RegisterTimerHandler("LevelUp_ReminderAutoHide", 	"OnClose", self)
	Apollo.CreateTimer("LevelUp_ReminderAutoHide", knAutoHideReminderTime, false)
	Apollo.StopTimer("LevelUp_ReminderAutoHide")

	self.wndMain = nil
	self.wndPermanent = nil
	self.wndLevelUpUnlockReminder = nil

	self.wndPermanentLocX = nil
	self.wndPermanentLocY = nil

	if GameLib.GetPlayerUnit() then
		self:Initialize()
	end
end

function LevelUpUnlocks:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_LevelUpUnlocks"), {"ToggleLevelUpUnlocks", "", "Icon_Windows32_UI_CRB_InterfaceMenu_LevelUpUnlock"})
end

function LevelUpUnlocks:Initialize()
	local tPending = GameLib.GetPendingLevelUpUnlocks()
	if tPending and next(tPending) then -- At least one item
		self:OnCloseToReminder()
	end
end

function LevelUpUnlocks:OnPlayerLevelChange(nLevel)
	GameLib.GetUnlocksForLevel(nLevel, GameLib.LevelUpUnlockSystem.Level)
	self:OnClose()
	self:OnCloseToReminder()
end

function LevelUpUnlocks:OnPathLevelUp(nLevel)
	GameLib.GetUnlocksForLevel(nLevel, GameLib.LevelUpUnlockSystem.Path)
	self:OnClose()
	self:OnCloseToReminder()
end

-----------------------------------------------------------------------------------------------
-- Drawing
-----------------------------------------------------------------------------------------------

function LevelUpUnlocks:DisplayLevelUpUnlockPermanentWindow(nSpecificLevel)
	if not self.wndPermanent or not self.wndPermanent:IsValid() then
		self.wndPermanent = Apollo.LoadForm(self.xmlDoc, "LevelUpUnlockPermanent", nil, self)
		if self.wndPermanentLocX ~= nil and self.wndPermanentLocY ~= nil then
			self.wndPermanent:Move(self.wndPermanentLocX, self.wndPermanentLocY, self.wndPermanent:GetWidth(), self.wndPermanent:GetHeight())
		end
	end

	-- Path or Level
	local bShowPath = self.wndPermanent:FindChild("LevelUpPathFilterBtn"):IsChecked()
	if not nSpecificLevel then
		nSpecificLevel = bShowPath and (PlayerPathLib.GetPathLevel() + 1) or (GameLib.GetPlayerLevel() + 1)
	end
	nSpecificLevel = bShowPath and math.min(knMaxPathLevel, nSpecificLevel) or math.min(knMaxLevel, nSpecificLevel)

	self.wndPermanent:FindChild("LevelUpPickerBtn"):SetData(nSpecificLevel)
	self.wndPermanent:FindChild("LevelUpPickerBtn"):AttachWindow(self.wndPermanent:FindChild("LevelUpPickerListFrame"))
	self.wndPermanent:FindChild("LevelUpPickerBtnText"):SetText(String_GetWeaselString(Apollo.GetString("LevelUpUnlocks_LevelNum"), nSpecificLevel))
	self.wndPermanent:FindChild("LevelUpPathFilterBtn"):SetCheck(bShowPath)
	self.wndPermanent:FindChild("LevelUpLevelFilterBtn"):SetCheck(not bShowPath)

	-- List Items
	self.wndPermanent:FindChild("LevelUpItemContainer"):DestroyChildren()
	local nSystem = bShowPath and GameLib.LevelUpUnlockSystem.Path or GameLib.LevelUpUnlockSystem.Level
	for idx, tUnlock in pairs(GameLib.GetUnlocksForLevel(nSpecificLevel, nSystem, true) or {}) do
		local wndUnlockItem = self:BuildLevelItem(tUnlock, self.wndPermanent:FindChild("LevelUpItemContainer"), nSpecificLevel)
		--wndUnlockItem:FindChild("LevelUpItemBtn"):Enable(false)
	end
	self.wndPermanent:FindChild("LevelUpItemContainer"):ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)

	-- Level Picker
	self.wndPermanent:FindChild("LevelUpPickerList"):DestroyChildren()
	local nLevelPickerMax = bShowPath and knMaxPathLevel or knMaxLevel
	for idx = 2, nLevelPickerMax do -- TODO: Hardcoded Max Level
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "LevelNumberBtn", self.wndPermanent:FindChild("LevelUpPickerList"), self)
		wndCurr:SetData(idx)
		wndCurr:SetText(String_GetWeaselString(Apollo.GetString("LevelUpUnlocks_LevelNum"), idx))
	end
	self.wndPermanent:FindChild("LevelUpPickerList"):ArrangeChildrenVert(0)
	self.wndPermanent:FindChild("LevelUpPickerList"):SetVScrollPos((nSpecificLevel - 1) * 30) -- 30 is hardcoded formatting of the list item height
end

function LevelUpUnlocks:DisplayLevelUpUnlockDetailsWindow() -- Also from XML, such as the fanfare window
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "LevelUpUnlockDetails", nil, self)
		if self.locSavedMainLoc then
			self.wndMain:MoveToLocation(self.locSavedMainLoc)
		end
	end

	local nPlayerLevel = GameLib.GetPlayerLevel()
	local nPathLevel = PlayerPathLib.GetPathLevel()

	-- List Items
	local nVScrollPos = self.wndMain:FindChild("LevelUpItemContainer"):GetVScrollPos()
	self.wndMain:FindChild("LevelUpItemContainer"):DestroyChildren()
	self.wndMain:FindChild("PathUpItemContainer"):DestroyChildren()

	for idx, tUnlock in pairs(GameLib.GetPendingLevelUpUnlocks() or {}) do
		if tUnlock.nSystem == GameLib.LevelUpUnlockSystem.Path then
			self:BuildLevelItem(tUnlock, self.wndMain:FindChild("PathUpItemContainer"), nPathLevel)
		else
			self:BuildLevelItem(tUnlock, self.wndMain:FindChild("LevelUpItemContainer"), nPlayerLevel)
		end
	end

	-- Rest of the formatting
	self.wndMain:FindChild("BGLevelPathSeparator"):Show(false)
	self.wndMain:FindChild("PathUpHeaderLevelText"):SetText(nPathLevel)
	self.wndMain:FindChild("PathUpItemContainer"):ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)
	self.wndMain:FindChild("LevelUpHeaderLevelText"):SetText(nPlayerLevel)
	self.wndMain:FindChild("LevelUpItemContainer"):ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)
	self.wndMain:FindChild("LevelUpItemContainer"):SetVScrollPos(nVScrollPos)

	-- Resize
	local bPathUpVisible = #self.wndMain:FindChild("PathUpItemContainer"):GetChildren() > 0
	local bLevelUpVisible = #self.wndMain:FindChild("LevelUpItemContainer"):GetChildren() > 0
	local nPathLeft, nPathTop, nPathRight, nPathBottom = self.wndMain:FindChild("PathUpFrame"):GetAnchorOffsets()
	local nLevelLeft, nLevelTop, nLevelRight, nLevelBottom = self.wndMain:FindChild("LevelUpFrame"):GetAnchorOffsets()
	if bPathUpVisible and bLevelUpVisible then
		self.wndMain:FindChild("LevelUpFrame"):SetAnchorOffsets(nLevelLeft, 70, nLevelRight, 330)
		self.wndMain:FindChild("PathUpFrame"):SetAnchorOffsets(nPathLeft, 340, nPathRight, 599)
		self.wndMain:FindChild("BGLevelPathSeparator"):Show(true)
	elseif bLevelUpVisible then
		self.wndMain:FindChild("LevelUpFrame"):SetAnchorOffsets(nLevelLeft, 70, nLevelRight, 599)
		self.wndMain:FindChild("PathUpFrame"):SetAnchorOffsets(nPathLeft, 0, nPathRight, 0)
	elseif bPathUpVisible then
		self.wndMain:FindChild("LevelUpFrame"):SetAnchorOffsets(nLevelLeft, 0, nLevelRight, 0)
		self.wndMain:FindChild("PathUpFrame"):SetAnchorOffsets(nPathLeft, 70, nPathRight, 599)
	else
		self:OnClose()
	end
end

function LevelUpUnlocks:BuildLevelItem(tUnlock, wndParent, nCurrentLevel)

	local eInputAction = ktUnlockMapping[tUnlock.nType] or ktUnlockMapping[""]
	local strInputAction = ""
	if eInputAction ~= 0 then
		strInputAction = GameLib.GetInputActionNameByEnum( eInputAction )
	end

	local wndHeader = self:FactoryProduce(wndParent, "LevelUpHeader", strInputAction )

	-- Items
	local strItalics = (tUnlock.nLevel ~= nCurrentLevel and tUnlock.nLevel ~= -1) and String_GetWeaselString(Apollo.GetString("LevelUpUnlocks_FromLevel"), tUnlock.nLevel) or ""
	local wndUnlockItem = Apollo.LoadForm(self.xmlDoc, "LevelUpItem", wndHeader:FindChild("LevelUpHeaderItems"), self)
	wndUnlockItem:FindChild("LevelUpItemMouseCatcher"):SetData(wndUnlockItem)
	wndUnlockItem:FindChild("LevelUpActionBtn"):SetData(tUnlock)
	wndUnlockItem:FindChild("LevelUpItemIcon"):SetSprite(tUnlock.strIcon)
	wndUnlockItem:FindChild("LevelUpItemItalics"):SetText(tostring(tUnlock.strHeader)..strItalics)
	wndUnlockItem:FindChild("LevelUpItemDescription"):SetText(tUnlock.strDescription)

	-- Header
	local nHeight = wndHeader:FindChild("LevelUpHeaderItems"):ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndHeader:GetAnchorOffsets()
	wndHeader:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 65)

	if string.len(strInputAction) > 0 then
		wndHeader:FindChild("LevelUpHeaderText"):SetText(String_GetWeaselString(Apollo.GetString("LevelUpUnlocks_TypeHeader"), strInputAction, GameLib.GetKeyBindingByEnum(eInputAction)))
	end

	return wndUnlockItem
end

-----------------------------------------------------------------------------------------------
-- Simple UI Interaction
-----------------------------------------------------------------------------------------------

function LevelUpUnlocks:OnLevelUpPickerBtn(wndHandler, wndControl) -- Dropdown button in Permanent UI, view another level
	self.wndPermanent:FindChild("LevelUpPickerListFrame"):Show(false)
	self:DisplayLevelUpUnlockPermanentWindow(wndHandler:GetData())
end

function LevelUpUnlocks:OnLevelUpFilterBtn(wndHandler, wndControl) -- Filter buttons in Permanent UI
	self:DisplayLevelUpUnlockPermanentWindow(self.wndPermanent:FindChild("LevelUpPickerBtn"):GetData())
end

function LevelUpUnlocks:OnLevelUpItemActionBtn(wndHandler, wndControl, eMouseButton)
	local tUnlock = wndHandler:GetData()
	GameLib.MarkLevelUpUnlockViewed(tUnlock.nId, true)
	self:DisplayLevelUpUnlockDetailsWindow()

	for idx, tAction in pairs(ktUnlockActions) do
		if tUnlock[tAction.strField] == tAction.eValue then
			Event_FireGenericEvent(tAction.strEvent, tUnlock.nExtraData)
		end
	end
end

function LevelUpUnlocks:OnLevelUpUnlocksMarkAllAsSeenBtn(wndHandler, wndControl, eMouseButton)
	for idx, tUnlock in pairs(GameLib.GetPendingLevelUpUnlocks() or {}) do
		GameLib.MarkLevelUpUnlockViewed(tUnlock.nId, true)
	end
	self:OnClose()
end

-----------------------------------------------------------------------------------------------
-- Clearing
-----------------------------------------------------------------------------------------------

function LevelUpUnlocks:OnCloseToDetailsWindow()
	self:OnClose()
	self:DisplayLevelUpUnlockDetailsWindow()
end

function LevelUpUnlocks:OnCloseToReminder() -- Also from XML
	self:OnClose()
	self.wndLevelUpUnlockReminder = Apollo.LoadForm(self.xmlDoc, "LevelUpUnlockReminder", nil, self)

	if self.locSavedReminderLoc then
		self.wndLevelUpUnlockReminder:MoveToLocation(self.locSavedReminderLoc)
	end

	Apollo.StartTimer("LevelUp_ReminderAutoHide")
end

function LevelUpUnlocks:OnCloseToPermanentWindow()
	if self.wndPermanent then
		self.wndPermanentLocX, self.wndPermanentLocY = self.wndPermanent:GetPos()
		self.wndPermanent:Destroy()
		self.wndPermanent = nil
	end
end

function LevelUpUnlocks:OnClose() -- Lots of things will call this
	Apollo.StopTimer("LevelUp_ReminderAutoHide")

	if self.wndMain then
		self.locSavedMainLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end

	if self.wndLevelUpUnlockReminder then
		self.locSavedReminderLoc = self.wndLevelUpUnlockReminder:GetLocation()
		self.wndLevelUpUnlockReminder:Destroy()
		self.wndLevelUpUnlockReminder = nil
	end
end

function LevelUpUnlocks:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

local LevelUpUnlocksInst = LevelUpUnlocks:new()
LevelUpUnlocksInst:Init()
