-----------------------------------------------------------------------------------------------
-- Client Lua Script for Character
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "Spell"
require "Item"
require "CharacterTitle"
require "AttributeMilestonesLib"

local Character = {}

local knNumCostumes = 10

--Really need an enum for these
--Numbers come from EItemSlot
local karCostumeSlotNames = -- string name, then id, then button art
{
	{"Weapon", 		GameLib.CodeEnumItemSlots.Weapon, 			"CharacterWindowSprites:btn_Armor_HandsNormal", },
	{"Head", 		GameLib.CodeEnumItemSlots.Head, 			"CharacterWindowSprites:btnCh_Armor_Head", 	},
	{"Shoulder", 	GameLib.CodeEnumItemSlots.Shoulder, 		"CharacterWindowSprites:btnCh_Armor_Shoulder", 	},
	{"Chest", 		GameLib.CodeEnumItemSlots.Chest, 			"CharacterWindowSprites:btnCh_Armor_Chest", },
	{"Hands", 		GameLib.CodeEnumItemSlots.Hands, 			"CharacterWindowSprites:btnCh_Armor_Hands", },
	{"Legs", 		GameLib.CodeEnumItemSlots.Legs, 			"CharacterWindowSprites:btnCh_Armor_Legs", 	},
	{"Feet", 		GameLib.CodeEnumItemSlots.Feet, 			"CharacterWindowSprites:btnCh_Armor_Feet", 	},
}

local ktSlotWindowNameToTooltip =
{
	["HeadSlot"] 				= Apollo.GetString("Character_HeadEmpty"),
	["ShoulderSlot"] 			= Apollo.GetString("Character_ShoulderEmpty"),
	["ChestSlot"] 				= Apollo.GetString("Character_ChestEmpty"),
	["HandsSlot"] 				= Apollo.GetString("Character_HandsEmpty"),
	["LegsSlot"] 				= Apollo.GetString("Character_LegsEmpty"),
	["FeetSlot"]				= Apollo.GetString("Character_FeetEmpty"),
	["ToolSlot"] 				= Apollo.GetString("Character_ToolEmpty"),
	["WeaponAttachmentSlot"] 	= Apollo.GetString("Character_AttachmentEmpty"),
	["SupportSystemSlot"] 		= Apollo.GetString("Character_SupportEmpty"),
	["GadgetSlot"] 				= Apollo.GetString("Character_GadgetEmpty"),
	["AugmentSlot"] 			= Apollo.GetString("Character_KeyEmpty"),
	["ImplantSlot"] 			= Apollo.GetString("Character_ImplantEmpty"),
	["ShieldSlot"] 				= Apollo.GetString("Character_ShieldEmpty"),
	["WeaponSlot"] 				= Apollo.GetString("Character_WeaponEmpty"),
}

local ktAttributeIconsText =
{
	[Unit.CodeEnumProperties.Dexterity] 					= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Finesse", 			Apollo.GetString("CRB_Finesse")},
	[Unit.CodeEnumProperties.Technology] 					= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Technology", 		Apollo.GetString("CRB_Tech_Attribute")},
	[Unit.CodeEnumProperties.Magic] 						= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Moxie", 			Apollo.GetString("CRB_Moxie")},
	[Unit.CodeEnumProperties.Wisdom] 						= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Insight", 			Apollo.GetString("UnitPropertyInsight")},
	[Unit.CodeEnumProperties.Stamina] 						= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Grit", 				Apollo.GetString("CRB_Grit")},
	[Unit.CodeEnumProperties.Strength] 						= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_BruteForce", 		Apollo.GetString("CRB_Brutality")},

	[Unit.CodeEnumProperties.AssaultPower] 					= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_AssaultPower", 		Apollo.GetString("CRB_Assault_Power")},
	[Unit.CodeEnumProperties.SupportPower] 					= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_SupportPower", 		Apollo.GetString("CRB_Support_Power")},
	[Unit.CodeEnumProperties.Rating_AvoidReduce] 			= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Strikethrough", 	Apollo.GetString("CRB_Strikethrough_Rating")},
	[Unit.CodeEnumProperties.Rating_CritChanceIncrease] 	= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_CriticalHit", 		Apollo.GetString("CRB_Critical_Chance")},
	[Unit.CodeEnumProperties.RatingCritSeverityIncrease] 	= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_CriticalSeverity", 	Apollo.GetString("CRB_Critical_Severity")},
	[Unit.CodeEnumProperties.Rating_AvoidIncrease] 			= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Deflect", 			Apollo.GetString("CRB_Deflect_Rating")},
	[Unit.CodeEnumProperties.Rating_CritChanceDecrease] 	= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_DeflectCritical", 	Apollo.GetString("CRB_Deflect_Critical_Hit_Rating")},
	[Unit.CodeEnumProperties.ManaPerFiveSeconds] 			= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Recovery", 			Apollo.GetString("CRB_Attribute_Recovery_Rating")},
	[Unit.CodeEnumProperties.HealthRegenMultiplier] 		= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Recovery", 			Apollo.GetString("CRB_Health_Regen_Factor")},
	[Unit.CodeEnumProperties.BaseHealth] 					= {"ClientSprites:Icon_Windows_UI_CRB_Attribute_Health", 			Apollo.GetString("CRB_Health_Max")},
}

local karClassToString =
{
	[GameLib.CodeEnumClass.Warrior] 		= Apollo.GetString("ClassWarrior"),
	[GameLib.CodeEnumClass.Engineer] 		= Apollo.GetString("ClassEngineer"),
	[GameLib.CodeEnumClass.Esper] 			= Apollo.GetString("ClassESPER"),
	[GameLib.CodeEnumClass.Medic] 			= Apollo.GetString("ClassMedic"),
	[GameLib.CodeEnumClass.Stalker] 		= Apollo.GetString("ClassStalker"),
	[GameLib.CodeEnumClass.Spellslinger] 	= Apollo.GetString("ClassSpellslinger"),
}

local karClassToIcon =
{
	[GameLib.CodeEnumClass.Warrior] 		= "IconSprites:Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "IconSprites:Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "IconSprites:Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "IconSprites:Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "IconSprites:Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Spellslinger] 	= "IconSprites:Icon_Windows_UI_CRB_Spellslinger",
}

local ktPathToString =
{
  [PlayerPathLib.PlayerPathType_Soldier]    = Apollo.GetString("PlayerPathSoldier"),
  [PlayerPathLib.PlayerPathType_Settler]    = Apollo.GetString("PlayerPathSettler"),
  [PlayerPathLib.PlayerPathType_Scientist]  = Apollo.GetString("PlayerPathScientist"),
  [PlayerPathLib.PlayerPathType_Explorer]   = Apollo.GetString("PlayerPathExplorer"),
}

local ktPathToIcon =
{
  [PlayerPathLib.PlayerPathType_Soldier]    = "CRB_PlayerPathSprites:spr_Path_Soldier_Stretch",
  [PlayerPathLib.PlayerPathType_Settler]    = "CRB_PlayerPathSprites:spr_Path_Settler_Stretch",
  [PlayerPathLib.PlayerPathType_Scientist]  = "CRB_PlayerPathSprites:spr_Path_Scientist_Stretch",
  [PlayerPathLib.PlayerPathType_Explorer]   = "CRB_PlayerPathSprites:spr_Path_Explorer_Stretch",
}

local karFactionToString =
{
	[Unit.CodeEnumFaction.ExilesPlayer] 	= Apollo.GetString("CRB_Exile"),
	[Unit.CodeEnumFaction.DominionPlayer] 	= Apollo.GetString("CRB_Dominion"),
}

local karFactionToIcon =
{
	[Unit.CodeEnumFaction.ExilesPlayer] 	= "charactercreate:sprCharC_Ico_Exile_Lrg",
	[Unit.CodeEnumFaction.DominionPlayer] 	= "charactercreate:sprCharC_Ico_Dominion_Lrg",
}

local karRaceToString =
{
	[GameLib.CodeEnumRace.Human] 	= Apollo.GetString("RaceHuman"),
	[GameLib.CodeEnumRace.Granok] 	= Apollo.GetString("RaceGranok"),
	[GameLib.CodeEnumRace.Aurin] 	= Apollo.GetString("RaceAurin"),
	[GameLib.CodeEnumRace.Draken] 	= Apollo.GetString("RaceDraken"),
	[GameLib.CodeEnumRace.Mechari] 	= Apollo.GetString("RaceMechari"),
	[GameLib.CodeEnumRace.Chua] 	= Apollo.GetString("RaceChua"),
	[GameLib.CodeEnumRace.Mordesh] 	= Apollo.GetString("CRB_Mordesh"),
}

function Character:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Character:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies =
	{
		"MountCustomization",
		"Reputation"
	}

    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function Character:OnDependencyError(strDep, strError)
	-- if you don't care about this dependency, return true.
	-- if you return false, or don't define this function
	-- any Addons/Packages that list you as a dependency
	-- will also receive a dependency error

	if strDep == "MountCustomization" or strDep == "Reputation" then
	   return true
	end

	return false
end

function Character:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Character.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

-- TODO: Refactor, if costumes is enough code it can be separated into another add-on. Also it'll give it more modability anyways.
function Character:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",						"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady",							"OnWindowManagementReady", self)
	
	Apollo.RegisterTimerHandler("Character_DelayedPlayerTitleChange", 				"OnDrawEditNamePopout", self) -- TODO: replace with a guild update event

	Apollo.RegisterEventHandler("PersonaUpdateCharacterStats", 						"OnPersonaUpdateCharacterStats", self)
	Apollo.RegisterEventHandler("ToggleCharacterWindow", 							"OnToggleCharacterWindow", self)
	Apollo.RegisterEventHandler("PlayerTitleChange", 								"DrawNames", self)
	Apollo.RegisterEventHandler("PlayerTitleUpdate", 								"OnDrawEditNamePopout", self)
	Apollo.RegisterEventHandler("Death", 											"DrawAttributes", self)
	Apollo.RegisterEventHandler("GuildChange", 										"OnGuildChange", self)
	Apollo.RegisterEventHandler("ItemConfirmSoulboundOnEquip",						"OnItemConfirmSoulboundOnEquip", self)
	--Apollo.RegisterEventHandler("ShowItemInDressingRoom", 						"OnShowItemInDressingRoom", self)

	-- Open Tab UIs
	Apollo.RegisterEventHandler("ToggleReputationInterface", 						"OnToggleReputation", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenReputation", 						"OnGenericEvent_OpenReputation", self)
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleSets", 						"OnInterfaceMenu_ToggleSets", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenMountCustomize", 					"OnGenericEvent_OpenMountCustomize", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Customization_Mount",				"OnGenericEvent_OpenMountCustomize", self)
	Apollo.RegisterEventHandler("MountUnlocked",									"OnGenericEvent_OpenMountCustomize", self)
	Apollo.RegisterEventHandler("PetFlairUnlocked", 								"OnPetFlairUnlocked", self) -- Eventually routes to OnGenericEvent_OpenMountCustomize

	-- TODO: There is capability to differentiate between the events later
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_CostumeSystem",			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_CostumeSlot2", 			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_CostumeSlot3", 			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_CostumeSlot4", 			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_CostumeSlot5", 			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_CostumeSlot6", 			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_Gadgets",			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_Gloves",			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_Helm",			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_Implants",		"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_RaidKey",			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_Shield",			"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_Shoulders",		"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_SupportSystem",	"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Character_GearSlot_WeaponAttachment","OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Class_Attribute",					"OnLevelUpUnlock_Character_Generic", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Path_Title",							"OnLevelUpUnlock_Character_Generic", self)

	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 		"OnTutorial_RequestUIAnchor", self)

	self.wndCharacter 				= Apollo.LoadForm(self.xmlDoc, "CharacterWindow", nil, self)
	self.wndCostume 				= self.wndCharacter:FindChild("CharFrame_BGArt:Costume")

	self.wndBonusFrame				= self.wndCharacter:FindChild("BonusFrame")
	self.wndCharacterTitles			= self.wndCharacter:FindChild("CharacterTitles")
	self.wndCharacterStats			= self.wndCharacter:FindChild("CharacterStats")
	self.wndCharacterMounts			= self.wndCharacter:FindChild("CharacterMounts")
	self.wndCharacterReputation		= self.wndCharacter:FindChild("CharacterReputation")
	self.wndCharacterReputationList	= self.wndCharacter:FindChild("CharacterReputationList")

	self.wndCharacter:FindChild("CharacterTitleBtn"):AttachWindow(self.wndCharacterTitles)
	self.wndCharacter:FindChild("BonusTab"):AttachWindow(self.wndBonusFrame)
	self.wndCharacter:FindChild("CharacterStatsBtn"):AttachWindow(self.wndCharacterStats)
	self.wndCharacter:FindChild("CharacterMountsBtn"):AttachWindow(self.wndCharacterMounts)
	self.wndCharacter:FindChild("CharacterReputationBtn"):AttachWindow(self.wndCharacterReputation)
	self.wndCharacter:FindChild("TitleSelectionBtn"):AttachWindow(self.wndCharacter:FindChild("NameEditTitleContainer"))
	self.wndCharacter:FindChild("ClassTitleGuild"):AttachWindow(self.wndCharacter:FindChild("NameEditGuildTagContainer"))

	self.wndCharacter:Show(false)

	self.wndSoulbindConfirm	= Apollo.LoadForm(self.xmlDoc, "SoulbindConfirm", nil, self)
	self.wndSoulbindConfirm:Show(false, true)

	self.bStatsValid 		= false
	self.listAttributes 	= {}
	self.tOffensiveStats 	= {}
	self.tDefensiveStats 	= {}
	self.wCostumeCheckBtn = self.wndCharacter:FindChild("CharFrame_BGArt:BGArt_HeaderFrame:SelectCostumeWindowToggle")
	self.wndCostumeSelectionList = self.wndCharacter:FindChild("CharFrame_BGArt:CostumeBtnHolder")
	self.wndCostumeSelectionList:Show(false)

	local wndVisibleSlots = self.wndCharacter:FindChild("VisibleSlots")
	self.arSlotsWindowsByName = -- each one has the slot name and then the corresponding UI window
	{
		{Apollo.GetString("InventorySlot_Head"), 			wndVisibleSlots:FindChild("HeadSlot")}, -- TODO: No enum to compare to code
		{Apollo.GetString("InventorySlot_Shoulder"), 		wndVisibleSlots:FindChild("ShoulderSlot")},
		{Apollo.GetString("InventorySlot_Chest"), 			wndVisibleSlots:FindChild("ChestSlot")},
		{Apollo.GetString("InventorySlot_Hands"), 			wndVisibleSlots:FindChild("HandsSlot")},
		{Apollo.GetString("InventorySlot_Legs"), 			wndVisibleSlots:FindChild("LegsSlot")},
		{Apollo.GetString("InventorySlot_Feet"), 			wndVisibleSlots:FindChild("FeetSlot")},
		{Apollo.GetString("InventorySlot_WeaponPrimary"), 	wndVisibleSlots:FindChild("WeaponSlot")}
	}

	-- Costumes
	self.wndCostumeFrame = self.wndCharacter:FindChild("CostumeEditFrame")
	self.wndCostumeFrame:Show(false)

	self.tCostumeBtns = {}
	self.nCostumeCount = GameLib.GetCostumeCount()

	for idx = 1, knNumCostumes do
		self.tCostumeBtns[idx] = self.wndCostumeSelectionList:FindChild("CostumeBtn"..idx)
		self.tCostumeBtns[idx]:SetData(idx)
		self.tCostumeBtns[idx]:Show( idx <= self.nCostumeCount)
	end

	self.nCurrentCostume = nil
	self.arCostumeSlots = {}

	for idx, tInfo in ipairs(karCostumeSlotNames) do
		local wndCostumeEntry = Apollo.LoadForm(self.xmlDoc, "CostumeEntryForm", self.wndCostumeFrame:FindChild("CostumeListContainer"), self)
		wndCostumeEntry:FindChild("CostumeSlot"):ChangeArt(tInfo[3])

		wndCostumeEntry:FindChild("CostumeSlot"):SetData(tInfo[2])
		if tInfo[2] == GameLib.CodeEnumItemSlots.Weapon then
			wndCostumeEntry:FindChild("VisibleBtn"):Enable(false)
			wndCostumeEntry:FindChild("VisibleBtn:VisibleBtnIcon"):SetBGColor(ApolloColor.new("UI_BtnTextHoloDisabled"))
		else
			wndCostumeEntry:FindChild("VisibleBtn"):SetData(tInfo[2])
		end
		wndCostumeEntry:FindChild("VisibleBtn"):SetData(tInfo[2])
		wndCostumeEntry:FindChild("ImprintCurrent"):SetData(tInfo[2])
		wndCostumeEntry:FindChild("RemoveSlotBtn"):SetData(tInfo[2])
		self.arCostumeSlots[tInfo[2]] = wndCostumeEntry
	end

	self.wndCostumeFrame:FindChild("CostumeListContainer"):ArrangeChildrenVert()

	self.wndCharacter:FindChild("PrimaryAttributeTab"):SetCheck(true)
	self.wndCharacter:FindChild("SecondaryAttributeFrame"):Show(false)
	self.wndCharacter:FindChild("BonusFrame"):Show(false)

	local wndMilestoneContainer = self.wndCharacter:FindChild("MilestoneContainer")
	wndMilestoneContainer:Show(true)

	-- Milestones
	-- Make an enum for the string keys?
	self.arMilestones =  -- window, then attribute enum for comparison
	{
		["strength"] 	= {"", Unit.CodeEnumProperties.Strength, 	1},
		["dexterity"] 	= {"", Unit.CodeEnumProperties.Dexterity, 	2},
		["technology"] 	= {"", Unit.CodeEnumProperties.Technology, 	4},
		["magic"]		= {"", Unit.CodeEnumProperties.Magic, 		3},
		["wisdom"] 		= {"", Unit.CodeEnumProperties.Wisdom, 		5},
		["stamina"] 	= {"", Unit.CodeEnumProperties.Stamina, 	6},
	}

	for iSeq = 1, 6 do
		for idx, tMilestoneInfo in pairs(self.arMilestones) do
			if tMilestoneInfo[3] == iSeq then
				local wndMilestone = Apollo.LoadForm(self.xmlDoc, "AttributeMilestoneEntry", wndMilestoneContainer, self)
				tMilestoneInfo[1] = wndMilestone
			end
		end
	end

	wndMilestoneContainer:ArrangeChildrenVert(0)
	self:UpdateMilestones()

	-- Guild Holo
	local wndHolomarkContainer = self.wndCharacter:FindChild("CharacterTitles:NameEditGuildHolomarkContainer")
	wndHolomarkContainer:FindChild("GuildHolomarkLeftBtn"):SetCheck(GameLib.GetGuildHolomarkVisible(GameLib.GuildHolomark.Left))
    wndHolomarkContainer:FindChild("GuildHolomarkRightBtn"):SetCheck(GameLib.GetGuildHolomarkVisible(GameLib.GuildHolomark.Right))
    wndHolomarkContainer:FindChild("GuildHolomarkBackBtn"):SetCheck(GameLib.GetGuildHolomarkVisible(GameLib.GuildHolomark.Back))
	local bDisplayNear = GameLib.GetGuildHolomarkDistance()
	if bDisplayNear then
	    wndHolomarkContainer:SetRadioSel("GuildHolomarkDistance", 1)
	else
	    wndHolomarkContainer:SetRadioSel("GuildHolomarkDistance", 2)
    end
end

function Character:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Character"), {"ToggleCharacterWindow", "CharacterPanel", "Icon_Windows32_UI_CRB_InterfaceMenu_Character"})
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Reputation"), {"GenericEvent_OpenReputation", "Reputation", "Icon_Windows32_UI_CRB_InterfaceMenu_Character"})
end

function Character:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndCharacter, strName = Apollo.GetString("InterfaceMenu_Character")})
end

-----------------------------------------------------------------------------------------------
-- Opening / Closing / Tab Visibility Checks
-----------------------------------------------------------------------------------------------

function Character:OnToggleCharacterWindow()
	if not self.wndCharacter:IsVisible() then
		self:ShowCharacterWindow()
	else
		self.wndCharacter:Show(false)
		Event_FireGenericEvent("CharacterWindowHasBeenClosed")
		Sound.Play(Sound.PlayUI01ClosePhysical)
	end
end


function Character:OnPetFlairUnlocked(petFlair)
	local eFlairType = petFlair:GetFlairType()
	if eFlairType == PetCustomizationLib.PetFlairType_GroundMountFront or eFlairType == PetCustomizationLib.PetFlairType_GroundMountBack
		or eFlairType == PetCustomizationLib.PetFlairType_GroundMountSide or eFlairType == PetCustomizationLib.PetFlairType_HoverMountFront
		or eFlairType == PetCustomizationLib.PetFlairType_HoverMountBack or eFlairType == PetCustomizationLib.PetFlairType_HoverMountSide then
		self:OnGenericEvent_OpenMountCustomize()
	end
end

function Character:OnGenericEvent_OpenMountCustomize()
	self:ShowCharacterWindow()

	if not self.wndCharacterReputation:IsShown() then
		Event_FireGenericEvent("GenericEvent_InitializeMountsCustomization", self.wndCharacterMounts)
	end

	self.wndCharacterTitles:Show(false)
	self.wndCharacterStats:Show(false)
	self.wndCharacterMounts:Show(true)
	self.wndCharacterReputation:Show(false)
	Event_FireGenericEvent("GenericEvent_DestroyReputation")
end

function Character:OnToggleReputation()
	if not self.wndCharacter:IsVisible() then
		self:OnGenericEvent_OpenReputation()
	else
		self.wndCharacter:Show(false)
		Event_FireGenericEvent("CharacterWindowHasBeenClosed")
		Sound.Play(Sound.PlayUI01ClosePhysical)
	end
end

function Character:OnGenericEvent_OpenReputation()
	self:ShowCharacterWindow()

	if not self.wndCharacterReputation:IsShown() then
		Event_FireGenericEvent("GenericEvent_InitializeReputation", self.wndCharacterReputationList)
	end

	self.wndCharacterTitles:Show(false)
	self.wndCharacterStats:Show(false)
	self.wndCharacterMounts:Show(false)
	self.wndCharacterReputation:Show(true)
	Event_FireGenericEvent("GenericEvent_DestroyMountsCustomization")
end

function Character:OnCharacterMountsCheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_InitializeMountsCustomization", self.wndCharacterMounts)
end

function Character:OnCharacterMountsUncheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_DestroyMountsCustomization")
end

function Character:OnCharacterReputationCheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_InitializeReputation", self.wndCharacterReputationList)
end

function Character:OnCharacterReputationUncheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_DestroyReputation")
end

-----------------------------------------------------------------------------------------------
-- Other UI Visibility
-----------------------------------------------------------------------------------------------

function Character:OnNameEditClearTitleBtn()
	CharacterTitle.SetTitle(nil)
end

function Character:ShowCharacterWindow()
	local unitPlayer = GameLib.GetPlayerUnit()

	self.wndCharacter:Show(true)

	self.nCostumeCount = GameLib.GetCostumeCount()
	for idx = 1, knNumCostumes do
		self.wndCharacter:FindChild("CostumeBtn" .. idx):SetCheck(false)
		self.wndCharacter:FindChild("CostumeBtn" .. idx):SetText(String_GetWeaselString(Apollo.GetString("Character_CostumeNum"), idx)) -- TODO: this will be a real name at some point
		self.wndCharacter:FindChild("CostumeBtn" .. idx):Show(idx <= self.nCostumeCount)
	end

	local nLeft, nTop, nRight, nBottom = self.wndCharacter:FindChild("CostumeBtnHolder"):GetAnchorOffsets()
	self.wndCharacter:FindChild("CostumeBtnHolder"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + (74 + 28 * self.nCostumeCount))

	self.wndCostumeSelectionList:Show(false)
	self.wndCharacterStats:Show(true)
	self.wndCharacterTitles:Show(false)
	self.wndCharacterReputation:Show(false)
	self.wndCharacterMounts:Show(false)
	self.wndCostumeFrame:Show(false)
	self.wndCharacter:ToFront()
	self:UpdateCostumeSlotIcons()
	self:UpdateMilestones()
	self:DrawAttributes()
	self:DrawNames()

	self.wndCostume:SetCostume(unitPlayer)
	self.wndCostume:SetSheathed(self.wndCharacter:FindChild("SetSheatheBtn"):IsChecked())

	Event_FireGenericEvent("CharacterWindowHasBeenToggled")
	Sound.Play(Sound.PlayUI68OpenPanelFromKeystrokeVirtual)
	Event_ShowTutorial(GameLib.CodeEnumTutorial.CharacterPanel)
end

function Character:OnCostumeBtnToggle(wndHandler, wndCtrl)
	if wndHandler ~= wndCtrl then
		return false
	end

	self.nCurrentCostume = nil

local wndCostumeHolder = self.wndCharacter:FindChild("CharFrame_BGArt:CostumeBtnHolder")
	for idx = 1, knNumCostumes do
		if wndCostumeHolder:FindChild("CostumeBtn"..idx):IsChecked() then
			self.nCurrentCostume = idx
		end
	end

	self.wCostumeCheckBtn:SetCheck(false)
	self.wndCostumeSelectionList:Show(false)
	GameLib.SetCostumeIndex(self.nCurrentCostume)
	self:UpdateCostumeSlotIcons()
	Event_FireGenericEvent("CharacterPanel_CostumeUpdated")

	return true
end

function Character:OnEditCostumeBtnToggle(wndHandler, wndCtrl) -- keeping these separate as we may make you not have to wear the costume to update it in the future
	self.nCurrentCostume = nil

	self.wndCostumeEditList:Show(false)

	if self.nCurrentCostume ~= nil then
		GameLib.SetCostumeIndex(self.nCurrentCostume)
	end

	self:UpdateCostumeSlotIcons()
end

function Character:OnNoCostumeBtn()
	self.wCostumeCheckBtn:SetCheck(false)
	self.wndCostumeSelectionList:Show(false)
	self.wndCostumeFrame:Show(false)
	self.nCurrentCostume = nil
	GameLib.SetCostumeIndex(self.nCurrentCostume)
	self:UpdateCostumeSlotIcons()
	Event_FireGenericEvent("CharacterPanel_CostumeUpdated")
end

function Character:OnCloseCostumeBtn()
	self.wndCostumeSelectionList:Show(false)
	self.wCostumeCheckBtn:SetCheck(false)
	self.nCurrentCostume = nil
end

function Character:OnVisibleBtnCheck(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local bVisible = wndControl:IsChecked()
	local iSlot = wndControl:GetData()

	if self.nCurrentCostume ~= nil and self.nCurrentCostume ~= 0 then
		GameLib.SetCostumeSlotVisible(self.nCurrentCostume, iSlot, bVisible)

	end

	self:UpdateCostumeSlotIcons()
end

function Character:OnImprintCurrent(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	if uItemToImprint ~= nil then
		GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), uItemToImprint:GetInventoryId())
	end

	self:UpdateCostumeSlotIcons()
end

function Character:OnRemoveSlotBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), -1)
	self:UpdateCostumeSlotIcons()
end

function Character:UpdateCostumeSlotIcons()
	-- this is our update function; it's used to repopulate the slots on the costume window (when shown) and mark what slots on the character
	-- window are effected by a costume piece (when shown)

	self.nCostumeCount = GameLib.GetCostumeCount()
	self.nCurrentCostume = GameLib.GetCostumeIndex()

	local wndCostumeHolder = self.wndCharacter:FindChild("CharFrame_BGArt:CostumeBtnHolder")
	local wndHeaderFrame = self.wndCharacter:FindChild("CharFrame_BGArt:BGArt_HeaderFrame")

	-- update all btns so the UI's move in sync; happens AFTER the costume is set.
	for idx = 1, knNumCostumes do -- update the costume window to match
		local wndCostumeBtn = wndCostumeHolder:FindChild("CostumeBtn" .. idx)
		wndCostumeBtn:SetCheck(false)
		wndCostumeBtn:Show( idx <= self.nCostumeCount )
	end

	if self.nCurrentCostume ~= nil and self.nCurrentCostume > 0 then
		local unitPlayer = GameLib.GetPlayerUnit()
		local tEquipped = {}
		for key, itemEquipped in pairs(unitPlayer:GetEquippedItems()) do
			if itemEquipped ~= nil then
				tEquipped[itemEquipped:GetSlot()] = itemEquipped
			end
		end

		local wndCurrentCostume = wndCostumeHolder:FindChild("CostumeBtn" .. self.nCurrentCostume)

		wndCurrentCostume:SetCheck(true)
		wndCostumeHolder:FindChild("ClearCostumeBtn"):SetCheck(false)

		local strName = wndCurrentCostume:GetText()

		--wndHeaderFrame:FindChild("SelectCostumeWindowToggle"):SetText(strName)
		wndHeaderFrame:FindChild("EditCostumeToggle"):Show(true)

		for idx, wndSlot in pairs(self.arCostumeSlots) do
			local strIcon = GameLib.GetCostumeItemIcon(self.nCurrentCostume, idx) or ""
			local bShown = GameLib.IsCostumeSlotVisible(self.nCurrentCostume, idx)
			local wndCostumeIcon = wndSlot:FindChild("CostumeSlot:CostumeIcon")

			wndSlot:FindChild("VisibleBtn"):SetCheck(bShown)
			wndSlot:FindChild("HiddenBlocker"):Show(not bShown)
			wndSlot:FindChild("RemoveSlotBtn"):Enable(strIcon ~= "")
			wndCostumeIcon:SetSprite(strIcon)

			local wndCostumeIconCurrent = self.arCostumeSlots[idx]:FindChild("BGArt:BG_IconFrameCurrent:CostumeIconCurrent")
			if tEquipped[idx - 1] ~= nil then
				wndSlot:FindChild("ImprintCurrent"):Enable(true)
			else
				wndSlot:FindChild("ImprintCurrent"):Enable(false)

			end

			if self.wndCostumeFrame:IsShown() then
				self.wndCostumeFrame:FindChild("CostumeListLabel"):SetText(String_GetWeaselString(Apollo.GetString("Character_EditingCostume", self.nCurrentCostume)))

				if bShown == false then
					wndCostumeIcon:SetSprite("ClientSprites:LootCloseBox")
				end
			end
		end
	else
		--wndHeaderFrame:FindChild("SelectCostumeWindowToggle"):SetText(Apollo.GetString("Character_NoCostume"))
		wndHeaderFrame:FindChild("EditCostumeToggle"):Show(false)
		self.wndCharacter:FindChild("ClearCostumeBtn"):SetCheck(true)
	end

	wndHeaderFrame:FindChild("EditCostumeToggle"):SetCheck(self.wndCostumeFrame:IsShown())
end

function Character:OnCostumeSlotQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if wndHandler ~= wndControl then
		return Apollo.DragDropQueryResult.PassOn
	end
	if strType == "DDBagItem" then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

function Character:OnCostumeSlotDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if wndHandler ~= wndControl then
		return false
	end

	GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), nValue)
	self:UpdateCostumeSlotIcons()
end

function Character:OnRemoveItemBtn(wndHandler, wndControl)
	--TODO: Need a method for removing items

	--[[if wndHandler ~= wndControl then
		return false
	end

	GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetParent():GetData(), nil)
	self:UpdateCostumeSlotIcons()--]]
end

function Character:OnEditCostumeCheck(wndHandler, wndControl)
	if wndControl:IsChecked() then
		self.nCurrentCostume = GameLib.GetCostumeIndex()
		if self.nCurrentCostume == nil then
			return false
		end

		local unitPlayer = GameLib.GetPlayerUnit()
		self.wndCostumeFrame:Show(true)
	else
		self.wndCostumeFrame:Show(false)
	end
	self:UpdateCostumeSlotIcons()  -- sets the toggle for us
end

function Character:CostumeSelectionWindowCheck()
	self.wndCostumeSelectionList:Show(true)
end

function Character:CostumeSelectionWindowUnCheck()
	self.wndCostumeSelectionList:Show(false)
end

function Character:OnPersonaUpdateCharacterStats()
	if self.wndCharacter:IsShown() then
		self:DrawAttributes()
		self:UpdateMilestones()
		if self.nCurrentCostume > 0 then
			self:UpdateCostumeSlotIcons()
		end
	end

	--Needs to check if it's a weapon. If so, play weapon sound.
	--self:OnOffenseDefenseTab()
end

function Character:OnClose()
	self.wndCharacter:Show(false)
	Event_FireGenericEvent("CharacterWindowHasBeenClosed")
end

function Character:OnCostumeClose()
	self.wndCostumeFrame:Show(false)
	self:UpdateCostumeSlotIcons()
end

function Character:OnPrimaryAttributeTabBtn()
	self.wndCharacter:FindChild("MilestoneContainer"):Show(true)
	self.wndCharacter:FindChild("SecondaryAttributeFrame"):Show(false)
	self.wndBonusFrame:Show(false)
end

function Character:OnSecondaryAttributeTabBtn()
	self.wndCharacter:FindChild("MilestoneContainer"):Show(false)
	self.wndCharacter:FindChild("SecondaryAttributeFrame"):Show(true)
	self.wndBonusFrame:Show(false)
end

function Character:OnBonusTabBtn(wndHandler, wndControl)
	self.wndCharacter:FindChild("MilestoneContainer"):Show(false)
	self.wndCharacter:FindChild("SecondaryAttributeFrame"):Show(false)
	self.wndBonusFrame:Show(true)
	Event_FireGenericEvent("InterfaceMenu_ToggleSets", self.wndBonusFrame)
	
end

function Character:DrawAttributes()
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil or not self.wndCharacter:IsShown() then
		return
	end

	self.wndCharacter:FindChild("SecondaryAttributeFrame"):DestroyChildren()
	self.wndCharacter:FindChild("PermAttributeContainer"):DestroyChildren()

	local arProperties = unitPlayer:GetUnitProperties()
	local arPrimaryAttributes =
	{
		{
			{
				strName 	= Apollo.GetString("Character_MaxHealthLabel"),
				nValue 		= math.ceil(unitPlayer:GetMaxHealth()),
				strTooltip 	= Apollo.GetString("CRB_Health_Description")},
			{
				strName 	= Apollo.GetString("Character_MaxShieldLabel"),
				nValue 		= math.ceil(unitPlayer:GetShieldCapacityMax()),
				strTooltip 	= Apollo.GetString("Character_MaxShieldTooltip")},
			{
				strName 	= Apollo.GetString("AttributeAssaultPower"),
				nValue 		= math.floor(unitPlayer:GetAssaultPower()),
				strTooltip 	= Apollo.GetString("Character_AssaultTooltip")},
			{
				strName 	= Apollo.GetString("AttributeSupportPower"),
				nValue 		= math.floor(unitPlayer:GetSupportPower()),
				strTooltip 	= Apollo.GetString("Character_SupportTooltip")},
			{
				strName 	= Apollo.GetString("CRB_Armor"),
				nValue 		= math.floor(arProperties.Armor.fValue),
				strTooltip 	= Apollo.GetString("Character_ArmorTooltip")}
		}
	}

	local arSecondaryAttributes =
	{
		{
			{
				strName 	= Apollo.GetString("Character_StrikethroughLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetStrikethroughChance() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_StrikethroughTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.Rating_AvoidReduce).fValue))},
			{
				strName 	= Apollo.GetString("Character_CritChanceLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetCritChance() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_CritTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.Rating_CritChanceIncrease).fValue))},
			{
				strName 	= Apollo.GetString("Character_CritSeverityLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetCritSeverity() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_CritSevTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.RatingCritSeverityIncrease).fValue))},
			{
				strName 	= Apollo.GetString("Character_ArmorPenLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetIgnoreArmorBase() + 0.000005) * 10000) / 100)),
				strTooltip 	= Apollo.GetString("Character_ArmorPenTooltip")},
			{
				strName 	= Apollo.GetString("Character_ShieldPenLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetIgnoreShieldBase() + 0.000005) * 10000) / 100)),
				strTooltip 	= Apollo.GetString("Character_ShieldPenTooltip")},
			{
				strName 	= Apollo.GetString("Character_LifestealLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetBaseLifesteal() + 0.000005) * 10000) / 100)),
				strTooltip 	= Apollo.GetString("Character_LifestealTooltip")},
			{
				strName 	= Apollo.GetString("Character_HasteLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (-1 * math.floor((unitPlayer:GetCooldownReductionModifier() + 0.000005 - 1) * 10000) / 100)),
				strTooltip 	= Apollo.GetString("Character_HasteTooltip")}
		},
		{
			{
				strName 	= Apollo.GetString("Character_ShieldRegenPercentLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetShieldRegenPct() + 0.000005) * 10000) / 100)),
				strTooltip 	= Apollo.GetString("Character_ShieldRegenPercentTooltip")},
			{
				strName 	= Apollo.GetString("Character_ShieldRebootLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_SecondsLabel"), unitPlayer:GetShieldRebootTime() / 1000),
				strTooltip 	= Apollo.GetString("Character_ShieldRebootTooltip")
			}
		},
		{
			{
				strName 	= Apollo.GetString("Character_PhysicalMitLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetPhysicalMitigation() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_PhysMitTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.ResistPhysical).fValue))},
			{
				strName 	= Apollo.GetString("Character_TechMitLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetTechMitigation() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_TechMitTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.ResistTech).fValue))},
			{
				strName 	= Apollo.GetString("Character_MagicMitLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetMagicMitigation() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_MagicMitTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.ResistMagic).fValue))},
		},
		{
			{
				strName 	= Apollo.GetString("Character_DeflectLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetDeflectChance() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_DeflectTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.Rating_AvoidIncrease).fValue))},
			{
				strName 	= Apollo.GetString("Character_DeflectCritLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetDeflectCritChance() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_CritDeflectTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.Rating_CritChanceDecrease).fValue))},
			{
				strName 	= Apollo.GetString("Character_ResilianceLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((math.abs(unitPlayer:GetCCDurationModifier() -1) + 0.000005) * 10000) / 100)),
				strTooltip 	= Apollo.GetString("Character_ResilianceTooltip")}
		},
		{
			{
				strName 	= Apollo.GetString("Character_ManaRecoveryLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PerSecLabel"), unitPlayer:GetManaRegenInCombat() * 2),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_ManaRecoveryTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.ManaPerFiveSeconds).fValue))},
			{
				strName 	= Apollo.GetString("Character_ManaCostRedLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((math.abs(unitPlayer:GetManaCostModifier() -1) + 0.000005) * 10000) / 100)),
				strTooltip 	= Apollo.GetString("Character_ManaCostRedTooltip")}
		},
		{
			{
				strName 	= Apollo.GetString("Character_PvPOffenseLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetPvPOffensePercent() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_PvPOffenseTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.PvPOffensiveRating).fValue))},
			{
				strName 	= Apollo.GetString("Character_PvPDefLabel"),
				nValue 		= String_GetWeaselString(Apollo.GetString("Character_PercentAppendLabel"), (math.floor((unitPlayer:GetPvPDefensePercent() + 0.000005) * 10000) / 100)),
				strTooltip 	= String_GetWeaselString(Apollo.GetString("Character_PvPDefenseTooltip"), tostring(unitPlayer:GetUnitProperty(Unit.CodeEnumProperties.PvPDefensiveRating).fValue))},
		}
	}

	local wndParent = self.wndCharacter:FindChild("PermAttributeContainer")
	for idx, tCur in pairs (arPrimaryAttributes) do
		local wndItemHolder = Apollo.LoadForm(self.xmlDoc, "CalloutAtContHolder", wndParent , self)
		local nContainerLeft, nContainerTop, nContainerRight, nContainerBottom = wndParent:GetAnchorOffsets()

		local strIcon = ""
		for idxInner, tCurInner in pairs (arPrimaryAttributes[idx]) do
			self:PrimaryStatsDrawHelper(wndItemHolder , tCurInner.strName, tCurInner.nValue, strIcon, "UI_TextMetalGoldHighlight", tCurInner.strTooltip)
		end

		local nNewBottom = wndItemHolder:ArrangeChildrenVert()
		wndItemHolder:SetAnchorOffsets(nContainerLeft, nContainerTop + 5, nContainerRight, nNewBottom + 15 )
	end
	wndParent:ArrangeChildrenVert()

	local wndParent = self.wndCharacter:FindChild("SecondaryAttributeFrame")

	for idx, tCur in pairs (arSecondaryAttributes) do
		local wndItemContainer = Apollo.LoadForm(self.xmlDoc, "SecondaryAttributeContainer", wndParent, self)
		local wndItemHolder = Apollo.LoadForm(self.xmlDoc, "SecAtContHolder", wndItemContainer , self)
		local nContainerLeft, nContainerTop, nContainerRight, nContainerBottom = wndItemHolder:GetAnchorOffsets()

		local strIcon = ""
		for idxInner, tCurInner in pairs (arSecondaryAttributes[idx]) do
			self:SecondaryStatsDrawHelper(wndItemHolder , tCurInner.strName, tCurInner.nValue, strIcon, "ff39b5d4", tCurInner.strTooltip)
		end

		local nNewBottom = wndItemHolder:ArrangeChildrenVert()
		wndItemHolder:SetAnchorOffsets(nContainerLeft, nContainerTop, nContainerRight, nNewBottom )
		wndItemContainer:SetAnchorOffsets(nContainerLeft, nContainerTop, nContainerRight, nNewBottom + 11)
	end
	wndParent:ArrangeChildrenVert()

	---------- Durability ------------
	local unitPlayer = GameLib.GetPlayerUnit()
	for iSlot = 1, #self.arSlotsWindowsByName do
		local wndSlot = self.arSlotsWindowsByName[iSlot][2]
		wndSlot:FindChild("DurabilityMeter"):SetProgress(0)
		wndSlot:FindChild("DurabilityAlert"):Show(false)
		wndSlot:FindChild("DurabilityBlocker"):Show(false)
	end

	local nDamageMin = 0
	local nDamageMax = 0
	local nDelay = 0

	if unitPlayer ~= nil then
		local tItems = unitPlayer:GetEquippedItems()
		for idx, itemCurr in ipairs(tItems) do

			if itemCurr:GetSlotName() == self.arSlotsWindowsByName[7][1] then
				nDamageMin = itemCurr:GetWeaponDamageMin()
				nDamageMax = itemCurr:GetWeaponDamageMax()
				nDelay = (itemCurr:GetWeaponSpeed() / 1000)
			end

			local wndSlot = nil
			for iSlot = 1, #self.arSlotsWindowsByName do
				if itemCurr:GetSlotName() == self.arSlotsWindowsByName[iSlot][1] then
					wndSlot = self.arSlotsWindowsByName[iSlot][2]
				end
			end

			if wndSlot ~= nil then
				local nDurabilityMax = itemCurr:GetMaxDurability()
				local nDurabilityCurrent = itemCurr:GetDurability()
				local nDurabilityRation = (nDurabilityCurrent / nDurabilityMax)
				local bHasDurability = nDurabilityMax > 0

				wndSlot:FindChild("DurabilityBlocker"):Show(not bHasDurability)
				wndSlot:FindChild("DurabilityMeter"):Show(bHasDurability)
				wndSlot:FindChild("DurabilityMeter"):SetMax(nDurabilityMax)
				wndSlot:FindChild("DurabilityMeter"):SetProgress(nDurabilityCurrent)
				wndSlot:FindChild("DurabilityAlert"):Show(bHasDurability and nDurabilityRation <= .25)
			end
		end
	end
end

function Character:PrimaryStatsDrawHelper(wndContainer, name, value, strIcon, color, strTooltip)
	local wndItem = Apollo.LoadForm(self.xmlDoc, "CalloutAttributeItem", wndContainer, self)
	wndItem:FindChild("StatLabel"):SetAML(string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", color, name))
	wndItem:FindChild("StatValue"):SetAML(string.format("<P Font=\"CRB_InterfaceMedium_B\" Align=\"Right\" TextColor=\"%s\">%s</P>", color, value))

	if strIcon ~= "" then
		wndItem:FindChild("StatIcon"):SetSprite(strIcon)
		wndItem:FindChild("StatIcon"):Show(false)
	else
		wndItem:FindChild("StatIcon"):Show(false)
	end

	wndItem:SetTooltip(strTooltip)
end

function Character:SecondaryStatsDrawHelper(wndContainer, name, value, strIcon, color, strTooltip)
	local wndItem = Apollo.LoadForm(self.xmlDoc, "SecondaryAttributeItem", wndContainer, self)
	wndItem:FindChild("StatLabel"):SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", color, name))
	wndItem:FindChild("StatValue"):SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", color, value))

	if strIcon ~= "" then
		wndItem:FindChild("StatIcon"):SetSprite(strIcon)
		wndItem:FindChild("StatIcon"):Show(true)
	else
		wndItem:FindChild("StatIcon"):Show(false)
	end

	wndItem:SetTooltip(strTooltip)
end

function Character:UpdateMilestones()
	-- TODO: REFACTOR
	local tInfo = AttributeMilestonesLib.GetAttributeMilestoneInfo()
	if tInfo.eResult == AttributeMilestonesLib.CodeEnumAttributeMilestoneResult.InvalidUnit or tInfo.eResult == AttributeMilestonesLib.CodeEnumAttributeMilestoneResult.UnknownClassId then
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	for key, tEntry in pairs(tInfo.tMilestones) do
		if self.arMilestones[key] ~= nil then
			local wndMilestone = self.arMilestones[key][1]

			local tCurrent = unitPlayer:GetUnitProperty(self.arMilestones[key][2])
			if tCurrent == nil then
				return
			end

			-- get all main ranks, figure out where the player is; this will get passed when the "more info" button is pressed
			local arRanksAndIds = {}
			local nRankFloor = 0
			local nRankMax = 0
			local nCurrentRank = 0
			local bOutRanked = false
			local bShowGlow = true

			-- This sets up the tiers by finding a spell and its value (each spell marks the end of a tier)
			for iInterval, tData in pairs(tEntry.tAttributeMilestones) do
				if not tData.bIsMini and tData.nRequiredAmount ~= nil and tData.nRequiredAmount ~= 0 then
					local tMilestone = {tData.nRequiredAmount, tData.nSpellId}
					arRanksAndIds[tData.nTier + 1] = tMilestone
				end
			end

			-- note: this will break if a tier is missing (that should never happen)
			if #arRanksAndIds > 0 and tCurrent.fValue ~= nil then
				for idx = 1, #arRanksAndIds do  -- important! order matters for finding floor/ceiling

					if arRanksAndIds[idx] ~= nil then
						if tCurrent.fValue < arRanksAndIds[1][1] then -- rank "0"
							nRankMax = arRanksAndIds[1][1]
						elseif tCurrent.fValue >= arRanksAndIds[#arRanksAndIds][1] then -- above top rank
							bOutRanked = true
							nCurrentRank = #arRanksAndIds
							-- Set floor and max to last rank to show mini milestones
							nRankFloor = arRanksAndIds[nCurrentRank-1][1]
							nRankMax = arRanksAndIds[nCurrentRank][1]
						elseif tCurrent.fValue >= arRanksAndIds[idx][1] and tCurrent.fValue < arRanksAndIds[idx + 1][1] then
							nCurrentRank = idx
							nRankFloor = arRanksAndIds[idx][1]
							nRankMax = arRanksAndIds[idx + 1][1]
						end

						if tCurrent.fValue == arRanksAndIds[idx][1] or bOutRanked == true then -- don't show glow without bar
							bShowGlow = false
						end

					end
				end
			end

			local strRank = ""
			if nCurrentRank ~= 0 then
				if bOutRanked then
					strRank = String_GetWeaselString(Apollo.GetString("Character_RankMaxed"), nCurrentRank)
				else
					strRank = String_GetWeaselString(Apollo.GetString("Character_Rank"), nCurrentRank)
				end
			end

			if bOutRanked then -- max it without over-drawing
				wndMilestone:FindChild("ProgressPoints"):SetMax(1)
				wndMilestone:FindChild("ProgressPoints"):SetFloor(0)
				wndMilestone:FindChild("ProgressPoints"):SetProgress(1)
			else
				wndMilestone:FindChild("ProgressPoints"):SetMax(nRankMax - nRankFloor)
				wndMilestone:FindChild("ProgressPoints"):SetFloor(0)
				wndMilestone:FindChild("ProgressPoints"):SetProgress(tCurrent.fValue - nRankFloor)
			end
			wndMilestone:FindChild("ProgressPoints"):SetStyleEx("EdgeGlow", bShowGlow)

			wndMilestone:FindChild("AttributeRank"):SetText(strRank)
			wndMilestone:FindChild("AttributeName"):SetText(ktAttributeIconsText[tCurrent.idProperty][2] .. ": " .. math.floor(tCurrent.fValue) or 0)
			wndMilestone:FindChild("AttributeNameIcon"):SetSprite(ktAttributeIconsText[tCurrent.idProperty][1])
			wndMilestone:FindChild("CurrentPoints"):SetText(nRankFloor)
			wndMilestone:FindChild("MaxPoints"):SetText(math.floor(nRankMax))

			----------------------------------------------------------------------------
			-- Now set up mini-milestones just for the tiers we're in
			----------------------------------------------------------------------------
			local tContributions = {} -- used on the tooltip

			-- the container needs to be the same size as the progbar for this to work
			wndMilestone:FindChild("MiniMilestoneTicks"):DestroyChildren()
			local nLeft, nTop, nRight, nBottom = wndMilestone:FindChild("ProgressPoints"):GetAnchorOffsets()
			local nLength = nRight - nLeft
			local nSpan = nRankMax - nRankFloor

			for idxMini, tMilestone in pairs(tEntry.tAttributeMilestones) do
				if tMilestone.bIsMini == true and tMilestone.nRequiredAmount > nRankFloor and tMilestone.nRequiredAmount <= nRankMax then
					local nPosition = ((tMilestone.nRequiredAmount - nRankFloor) / (nRankMax - nRankFloor)) * nLength
					local wndMini = Apollo.LoadForm(self.xmlDoc, "MiniMilestoneEntry", wndMilestone:FindChild("MiniMilestoneTicks"), self)
					local nLeft2, nTop2, nRight2, nBottom2 = wndMini:GetAnchorOffsets()
					local nHalf = (nRight2 - nLeft2) / 2
					local strReqColor = "ffff5555"
					local strMiniReq = String_GetWeaselString(Apollo.GetString("Character_MiniMileReq"), tMilestone.nRequiredAmount, ktAttributeIconsText[tCurrent.idProperty][2])
					wndMini:SetAnchorOffsets(nPosition - nHalf, nTop2, nPosition + nHalf, nBottom2)

					if tMilestone.nRequiredAmount <= tCurrent.fValue then
						wndMini:FindChild("Icon"):SetBGColor(CColor.new(1,1,1,1))
						--wndMini:FindChild("Backer"):SetBGColor(CColor.new(0,0,0,1))
						wndMini:FindChild("Backer"):SetBGColor(ApolloColor.new("UI_BtnTextHoloPressedFlyby"))
						strReqColor = "ff999999"
					else
						wndMini:FindChild("Icon"):SetBGColor(CColor.new(.8,.8,.8,.7))
						--wndMini:FindChild("Backer"):SetBGColor(CColor.new(1,1,1,1))
						wndMini:FindChild("Backer"):SetBGColor(ApolloColor.new("UI_TextHoloBody"))
						strMiniReq = "x " .. strMiniReq
					end

					if ktAttributeIconsText[tMilestone.eUnitProperty] ~= nil then
						wndMini:FindChild("Icon"):SetSprite(ktAttributeIconsText[tMilestone.eUnitProperty][1])
					end

					local strMiniAmount = string.format("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">+%.2f %s</P>", tMilestone.fModifier, ktAttributeIconsText[tMilestone.eUnitProperty][2])
					strMiniReq = string.format("<P><P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P></P>", strReqColor, strMiniReq)
					wndMini:SetTooltip(strMiniAmount .. strMiniReq)
				end

				if tMilestone.bIsMini == true and tMilestone.nRequiredAmount <= tCurrent.fValue then
					if tContributions[tMilestone.eUnitProperty] ~= nil then
						tContributions[tMilestone.eUnitProperty] = tContributions[tMilestone.eUnitProperty] + tMilestone.fModifier
					else
						tContributions[tMilestone.eUnitProperty] = tMilestone.fModifier
					end
				end
			end

			--Give the data we need to the button for the tooltip:
			local tCarriedData =
			{
				id 				= tCurrent.idProperty,
				tContributions 	= tContributions,
				tSecondaries 	= tEntry.tSecondaryStats,
			}

			wndMilestone:FindChild("AttributeNameIcon"):SetData(tCarriedData)
		end
	end
end

function Character:OnAttributeIconToolip(wndHandler, wndControl, eType, arg1, arg2)
	if wndHandler ~= wndControl or wndControl:GetData() == nil then
		return
	end
	local tData = wndControl:GetData()

	local wndRankDisplay = wndControl:LoadTooltipForm("Character.xml", "MilestoneTooltip", self)
	wndRankDisplay:FindChild("AttributeName"):SetText(ktAttributeIconsText[tData.id][2])
	--wndRankDisplay:FindChild("AttributeNameIcon"):SetSprite(ktAttributeIconsText[tData.id][1])
	wndRankDisplay:FindChild("AttributeSecHeader"):SetText(String_GetWeaselString(Apollo.GetString("Character_AttributeHeader"), ktAttributeIconsText[tData.id][2]))

	-- Secondaries
	local nSecondaryHeight = 0
	local wndSecondaries = wndRankDisplay:FindChild("AttributeSecondaries")

	for idx, tValue in pairs(tData.tSecondaries) do
		local wndSecondary = Apollo.LoadForm(self.xmlDoc, "RankSecondaryEntry", wndSecondaries, self)
		local nBonus = string.format("%.02f", tValue.fBonus)
		wndSecondary:FindChild("RankSecondaryEntryText"):SetText("+" .. nBonus .. " " .. ktAttributeIconsText[tValue.eUnitProperty][2])
		wndSecondary:FindChild("RankSecondaryEntryText"):SetHeightToContentHeight()
		wndSecondary:FindChild("RankSecondaryEntryIcon"):SetSprite(ktAttributeIconsText[tValue.eUnitProperty][1])
		nSecondaryHeight = nSecondaryHeight + math.max(wndSecondary:FindChild("RankSecondaryEntryText"):GetHeight(), 19)
	end

	local nLeft1, nTop1, nRight1, nBottom1 = wndSecondaries:GetAnchorOffsets()
	wndSecondaries:SetAnchorOffsets(nLeft1, nTop1, nRight1, nTop1 + nSecondaryHeight + 3)
	wndSecondaries:ArrangeChildrenVert()

	-- Milestones
	local nMilestoneHeight = 0
	local wndMilestones = wndRankDisplay:FindChild("AttributeTotals")

	for idx, tValue in pairs(tData.tContributions) do
		local wndMilestone = Apollo.LoadForm(self.xmlDoc, "RankSecondaryEntry", wndMilestones, self)
		local nBonus = string.format("%.02f", tValue)
		wndMilestone:FindChild("RankSecondaryEntryText"):SetText("+" .. nBonus .. " " .. ktAttributeIconsText[idx][2])
		wndMilestone:FindChild("RankSecondaryEntryText"):SetHeightToContentHeight()
		wndMilestone:FindChild("RankSecondaryEntryIcon"):SetSprite(ktAttributeIconsText[idx][1])
		nMilestoneHeight = nMilestoneHeight + math.max(wndMilestone:FindChild("RankSecondaryEntryText"):GetHeight(), 19)
	end

	local nLeft2, nTop2, nRight2, nBottom2 = wndMilestones:GetAnchorOffsets()
	wndMilestones:SetAnchorOffsets(nLeft2, nTop2, nRight2, nTop2 + nMilestoneHeight + 3)
	wndMilestones:ArrangeChildrenVert()

	wndRankDisplay:FindChild("ArrangeVertContainer"):ArrangeChildrenVert()
	local bottomEntryL, bottomEntryT, bottomEntryR, bottomEntryB = wndMilestones:GetAnchorOffsets()
	local vertContL, vertContT, vertContR, vertContB = wndRankDisplay:FindChild("ArrangeVertContainer"):GetAnchorOffsets()

	wndRankDisplay:FindChild("ArrangeVertContainer"):SetAnchorOffsets(vertContL, vertContT, vertContR, vertContT + bottomEntryB)
	vertContL, vertContT, vertContR, vertContB = wndRankDisplay:FindChild("ArrangeVertContainer"):GetAnchorOffsets()

	local nWndLeft, nWndTop, nWndRight, nWndBottom = wndRankDisplay:GetAnchorOffsets()
	wndRankDisplay:SetAnchorOffsets(nWndLeft, nWndTop, nWndRight, vertContB + 11 )
end

function Character:HelperBuildSecondaryTooltips(idx, arProperties)
	local tCharacterSecondaryStats =
	{
	--[[[1] = Apollo.GetString("CRB_Strength_Description"),
		[2] = Apollo.GetString("CRB_Dexterity_Description"),
		[3] = Apollo.GetString("CRB_Magic_Description"),
		[4] = Apollo.GetString("CRB_Technology_Description"),
		[5] = Apollo.GetString("CRB_Wisdom_Description"),
		[6] = Apollo.GetString("CRB_Stamina_Description"),--]]
		[7] = Apollo.GetString("CRB_Health_Description"),
		[8] = Apollo.GetString("Character_MaxShieldTooltip"),
		[9] = Apollo.GetString("Character_DeflectTooltip"),
		[10] = Apollo.GetString("Character_StrikethroughTooltip"),
		[11] = Apollo.GetString("Character_CritTooltip"),
		[12] = Apollo.GetString("Character_CritDeflectTooltip"),
		[16] = Apollo.GetString("Character_ArmorTooltip"),
		[17] = Apollo.GetString("Character_PhysMitTooltip"),
		[18] = Apollo.GetString("Character_TechMitTooltip"),
		[19] = Apollo.GetString("Character_MagicMitTooltip"),
		[21] = Apollo.GetString("Character_CritSevTooltip"),
		[22] = Apollo.GetString("Character_CombatRecoveryTooltip"),
	}

	if idx <= 8 or idx == 16 then
		return tCharacterSecondaryStats[idx]
	end

	-- Using strings to show decimal value
	local tProperties =
	{
		[9] = string.format("%.2f", arProperties.Rating_AvoidIncrease.nValue),
		[10] = string.format("%.2f", arProperties.Rating_AvoidReduce.nValue),
		[11] = string.format("%.2f", arProperties.Rating_CritChanceIncrease.nValue),
		[12] = string.format("%.2f", arProperties.Rating_CritChanceDecrease.nValue),
		[17] = string.format("%.2f", arProperties.ResistPhysical.nValue),
		[18] = string.format("%.2f", arProperties.ResistTech.nValue),
		[19] = string.format("%.2f", arProperties.ResistMagic.nValue),
		[21] = string.format("%.2f", arProperties.RatingCritSeverityIncrease.nValue),
		[22] = string.format("%.2f", arProperties.ManaPerFiveSeconds.nValue),
	--	[23] = arProperties.ManaPerFiveSeconds.nValue,
	}

	return String_GetWeaselString(tCharacterSecondaryStats[idx], tProperties[idx]) or ""
end

function Character:OnGenerateTooltip(wndHandler, wndControl, eType, itemCurr, idx)
	if eType ~= Tooltip.TooltipGenerateType_ItemInstance then
		return
	end

	if itemCurr then
		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = self.bVendorOpen, itemCompare = false})
	else
		wndControl:SetTooltip(wndControl:GetName() and ("<P Font=\"CRB_InterfaceSmall_O\">" .. ktSlotWindowNameToTooltip[wndControl:GetName()] .. "</P>") or "")
	end
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------

function Character:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.Character then return end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndCharacter:GetRect()
	
	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

-----------------------------------------------------------------------------------------------
-- Name Editing
-----------------------------------------------------------------------------------------------

function Character:OnGuildHolomarkToggle(wndHandler, wndControl, eMouseButton)
	local bVisibleLeft = self.wndCharacter:FindChild("GuildHolomarkLeftBtn"):IsChecked()
	local bVisibleRight = self.wndCharacter:FindChild("GuildHolomarkRightBtn"):IsChecked()
	local bVisibleBack = self.wndCharacter:FindChild("GuildHolomarkBackBtn"):IsChecked()
	local bDisplayNear = self.wndCharacter:FindChild("NameEditGuildHolomarkContainer"):GetRadioSel("GuildHolomarkDistance") == 1
	GameLib.ShowGuildHolomark(bVisibleLeft, bVisibleRight, bVisibleBack, bDisplayNear)
end

function Character:OnTitleSelected(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	if wndHandler:IsChecked() then
		local ttlSelected = wndHandler:GetData()
		if CharacterTitle.CanUseTitle(ttlSelected) then
			CharacterTitle.SetTitle(ttlSelected)
		end
	else
		CharacterTitle.SetTitle(nil)
	end

	self:OnDrawEditNamePopout()
	Apollo.CreateTimer("Character_DelayedPlayerTitleChange", 1, false) -- Also DrawNames() in 1 second, for lag
	self.wndCharacter:FindChild("NameEditTitleContainer"):Close()
end

function Character:OnPickGuildTag(wndHandler, wndControl) -- GuildTagBtn
	wndHandler:GetData():SetAsNameplate()
	self.wndCharacter:FindChild("NameEditGuildTagContainer"):Close()

	self:OnDrawEditNamePopout()
	Apollo.CreateTimer("Character_DelayedPlayerTitleChange", 1, false) -- Also DrawNames() in 1 second, for lag
end

function Character:OnCharacterNameEditBtn(wndHandler, wndControl)
	self:OnDrawEditNamePopout()
end

function Character:DrawNames()
	local unitPlayer = GameLib.GetPlayerUnit()
	local tStats = unitPlayer:GetBasicStats()
	local strGuildName = unitPlayer:GetGuildName() or ""
	local strTitleName = unitPlayer:GetTitleOrName() or ""
	local strTitle = unitPlayer:GetTitle() or ""
	local strClass = karClassToString[unitPlayer:GetClassId()] or ""
	local strClassIcon = karClassToIcon[unitPlayer:GetClassId()] or ""
	local strFaction = karFactionToString[unitPlayer:GetFaction()] or ""
	local strFactionIcon = karFactionToIcon[unitPlayer:GetFaction()] or ""
	local strPath = ktPathToString[unitPlayer:GetPlayerPathType()] or ""
	local strPathIcon = ktPathToIcon[unitPlayer:GetPlayerPathType()] or ""

	-- Special coloring if mentored
	local strLevel = ""
	if tStats.nEffectiveLevel ~= 0 and tStats.nEffectiveLevel < tStats.nLevel then
		strLevel = "<T Font=\"CRB_HeaderLarge\" TextColor=\"UI_BtnTextRedNormal\" Align=\"Center\">"..tStats.nEffectiveLevel.."</T>"
	elseif tStats.nEffectiveLevel ~= 0 and tStats.nEffectiveLevel > tStats.nLevel then
		strLevel = "<T Font=\"CRB_HeaderLarge\" TextColor=\"UI_BtnTextGreenNormal\" Align=\"Center\">"..tStats.nEffectiveLevel.."</T>"
	else
		strLevel = tostring(tStats.nLevel)
	end

	-- Determine if Exile Human or Cassian
	local strResult = ""
	local nRaceID = unitPlayer:GetRaceId()
	local nFactionID = unitPlayer:GetFaction()
	if nRaceID == GameLib.CodeEnumRace.Human then
		if nFactionID == Unit.CodeEnumFaction.ExilesPlayer then
			strResult = String_GetWeaselString(Apollo.GetString("Character_Title"), strTitleName, strLevel, Apollo.GetString("CRB_ExileHuman"), strPath, strClass)
		elseif nFactionID == Unit.CodeEnumFaction.DominionPlayer then
			strResult = String_GetWeaselString(Apollo.GetString("Character_Title"), strTitleName, strLevel, strFaction, Apollo.GetString("CRB_Cassian"), strPath, strClass)
		end
	else
		strResult = String_GetWeaselString(Apollo.GetString("Character_Title"), strTitleName, strLevel, strFaction, karRaceToString[nRaceID], strPath, strClass)
	end

	self.wndCharacter:FindChild("BGArt_OverallFrame:PlayerName"):SetAML("<P Font=\"CRB_HeaderMedium\" TextColor=\"UI_WindowTitleYellow\" Align=\"Center\">"..strTitleName.."</P>")
	self.wndCharacter:FindChild("ClassTitleGuild"):SetText((string.len(strGuildName) > 0) and strGuildName or "")
	self.wndCharacter:FindChild("TitleSelectionBtn"):SetText((string.len(strTitle) > 0) and strTitle or "")
	self.wndCharacter:FindChild("CharDataLevelBig"):SetText(strLevel)
	self.wndCharacter:FindChild("CharDataClass"):SetText(strClass)
	self.wndCharacter:FindChild("CharDataClassIcon"):SetSprite(strClassIcon)
	self.wndCharacter:FindChild("CharDataPath"):SetText(strPath)
	self.wndCharacter:FindChild("CharDataPathIcon"):SetSprite(strPathIcon)
	self.wndCharacter:FindChild("CharDataFaction"):SetText(strFaction)
	self.wndCharacter:FindChild("CharDataFactionIcon"):SetSprite(strFactionIcon)
	self.wndCharacter:FindChild("CharDataRace"):SetText(karRaceToString[nRaceID])

end

function Character:OnGuildChange()
	self:OnDrawEditNamePopout()
end

function Character:OnDrawEditNamePopout()
	local strLastCat = nil
	local wndEnsureVisible = nil
	local tTitles = CharacterTitle.GetAvailableTitles()
	table.sort(tTitles, function(a,b) return a:GetCategory() < b:GetCategory() end)

	self.wndCharacterTitles:FindChild("NameEditTitleList"):DestroyChildren()
	for idx, titleCurr in pairs(tTitles) do
		local strCategory = titleCurr:GetCategory()
		if strCategory ~= strLastCat then
			local wndHeader = Apollo.LoadForm(self.xmlDoc, "NameEditTitleCategory", self.wndCharacterTitles:FindChild("NameEditTitleList"), self)
			wndHeader:FindChild("TitleCategoryText"):SetText(strCategory)
			strLastCat = strCategory
		end

		local wndTitle = Apollo.LoadForm(self.xmlDoc, "NameEditTitleButton", self.wndCharacterTitles:FindChild("NameEditTitleList"), self)
		wndTitle:FindChild("NameEditTitleButtonText"):SetText(titleCurr:GetTitle())
		wndTitle:SetData(titleCurr)

		if not CharacterTitle.CanUseTitle(titleCurr) then
			wndTitle:Enable(false)
		end

		if CharacterTitle.IsActiveTitle(titleCurr) then
			wndEnsureVisible = wndTitle
			wndTitle:SetCheck(true)
		end
	end

	self.wndCharacterTitles:FindChild("NameEditTitleList"):ArrangeChildrenVert()
	self.wndCharacterTitles:FindChild("NameEditTitleList"):EnsureChildVisible(wndEnsureVisible)

	-- Guild Tags
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end

	local bInAGuild = false
	local bInACircle = false
	local strGuildNameCompare = unitPlayer:GetGuildName() or ""
	self.wndCharacter:FindChild("NameEditGuildTagList"):DestroyChildren()
	for idx, guildCurr in pairs(GuildLib.GetGuilds()) do
		local strGuildName = guildCurr:GetName()
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "GuildTagBtn", self.wndCharacter:FindChild("NameEditGuildTagList"), self)
		wndCurr:Enable(true)
		wndCurr:SetData(guildCurr)
		wndCurr:SetCheck(strGuildName == strGuildNameCompare)
		wndCurr:FindChild("GuildTagBtnText"):SetText(strGuildName)

		if guildCurr:GetType() == GuildLib.GuildType_Guild then
			bInAGuild = true
		--	self.wndCharacter:FindChild("NameEditGuildHolomarkContainerTitle"):SetText(String_GetWeaselString(Apollo.GetString("Character_HolomarkVisibility"), strGuildName))
		elseif guildCurr:GetType() == GuildLib.GuildType_Circle then
			bInACircle = true
		end
	end
	self.wndCharacter:FindChild("NameEditGuildTagList"):ArrangeChildrenVert(0)
	--self.wndCharacter:FindChild("NameEditGuildTagContainer"):Show(bInAGuild)
	self.wndCharacter:FindChild("FrameGuild"):Show(bInAGuild or bInACircle)
	self.wndCharacter:FindChild("NameEditGuildHolomarkContainer"):Show(bInAGuild)

	self:DrawNames()
end

function Character:OnRotateRight()
	self.wndCostume:ToggleLeftSpin(true)
end

function Character:OnRotateRightCancel()
	self.wndCostume:ToggleLeftSpin(false)
end

function Character:OnRotateLeft()
	self.wndCostume:ToggleRightSpin(true)
end

function Character:OnRotateLeftCancel()
	self.wndCostume:ToggleRightSpin(false)
end

function Character:OnSheatheCheck(wndHandler, wndControl)
	self.wndCostume:SetSheathed(wndControl:IsChecked())
end

function Character:OnLevelUpUnlock_Character_Generic()
	-- TODO: I suppose there is capability to differentiate between the events later
	self:ShowCharacterWindow()
end

---------------------------------------------------------------------------------------------------
-- SoulbindConfirm Functions
---------------------------------------------------------------------------------------------------

function Character:OnItemConfirmSoulboundOnEquip(eEquipmentSlot, iDDItemEquip, iDDItemDestination)
	self.wndSoulbindConfirm:FindChild("ConfirmBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.EquipItem, iDDItemEquip, iDDItemDestination)
	self.wndSoulbindConfirm:Show(true)
	self.wndSoulbindConfirm:ToFront()
end

function Character:OnEquipConfirm()
	self.wndSoulbindConfirm:Show(false)
end

function Character:OnCancelSoulbindBtn( wndHandler, wndControl, eMouseButton )
	self.wndSoulbindConfirm:Show(false)
end

local CharacterInstance = Character:new()
CharacterInstance:Init()
