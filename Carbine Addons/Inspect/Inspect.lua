require "Sound"
require "GameLib"
require "Spell"
require "Item"


local Inspect = {}

local knNumCostumes = 6
local kcrLabelColorNormal 		= CColor.new(47/255, 148/255, 172/255, 1.0)
local kcrPointColorNormal 		= CColor.new(49/255, 252/255, 246/255, 1.0)
local kcrLabelColorAvailable 	= CColor.new(255/255, 128/255, 0/255, 1.0)
local kcrPointColorAvailable 	= CColor.new(255/255, 128/255, 0/255, 1.0)
local kcrLabelColorHighlight 	= CColor.new(255/255, 213/255, 64/255, 1.0)
local kcrPointColorHighlight 	= CColor.new(255/255, 213/255, 64/255, 1.0)

local karCostumeSlotNames = -- string name, then id, then button art
{
	{"Head", 		GameLib.CodeEnumItemSlots.Head, "CharacterWindowSprites:btnCh_Armor_Head",},
	{"Shoulder", 	GameLib.CodeEnumItemSlots.Shoulder, "CharacterWindowSprites:btnCh_Armor_Shoulder",},
	{"Chest", 		GameLib.CodeEnumItemSlots.Chest, "CharacterWindowSprites:btnCh_Armor_Chest",},
	{"Hands", 		GameLib.CodeEnumItemSlots.Hands, "CharacterWindowSprites:btnCh_Armor_Hands",},
	{"Legs", 		GameLib.CodeEnumItemSlots.Legs, "CharacterWindowSprites:btnCh_Armor_Legs",},
	{"Feet", 		GameLib.CodeEnumItemSlots.Feet, "CharacterWindowSprites:btnCh_Armor_Feet",},
}

local kstrCostumeEquippedSlot = Apollo.GetString("Character_CostumeSlotShown")
local kstrCostumeHiddenSlot = Apollo.GetString("Character_CostumeSlotHidden")

local ktSlotWindowNameToTooltip = 
{
	["HeadSlot"] 				= Apollo.GetString("Character_HeadEmpty"),
	["ShoulderSlot"] 			= Apollo.GetString("Character_ShoulderEmpty"),
	["ChestSlot"] 				= Apollo.GetString("Character_ChestEmpty"),
	["HandsSlot"] 				= Apollo.GetString("Character_HandsEmpty"),
	["LegsSlot"] 				= Apollo.GetString("Character_LegsEmpty"),
	["FeetSlot"] 				= Apollo.GetString("Character_FeetEmpty"),
	["ToolSlot"] 				= Apollo.GetString("Character_ToolEmpty"),
	["WeaponAttachmentSlot"] 	= Apollo.GetString("Character_AttachmentEmpty"),
	["SupportSystemSlot"] 		= Apollo.GetString("Character_SupportEmpty"),
	["GadgetSlot"] 				= Apollo.GetString("Character_GadgetEmpty"),
	["AugmentSlot"] 			= Apollo.GetString("Character_AugmentEmpty"),
	["ImplantSlot"] 			= Apollo.GetString("Character_ImplantEmpty"),
	["ShieldSlot"] 				= Apollo.GetString("Character_ShieldEmpty"),
	["WeaponSlot"] 				= Apollo.GetString("Character_WeaponEmpty"),
}

--These Should Be Enums
--arProperties can be nil
local ktCharacterSecondaryStats = 
{
	[7]  = Apollo.GetString("CRB_Health_Description"),
	[8]  = Apollo.GetString("Character_MaxShieldTooltip"),
	[9]  = Apollo.GetString("Character_DeflectTooltip"),
	[10] = Apollo.GetString("Character_StrikethroughTooltip"),
	[11] = Apollo.GetString("Character_CritTooltip"),
	[12] = Apollo.GetString("Character_CritDeflectTooltip"),
	[16] = Apollo.GetString("Character_ArmorTooltip"),
	[17] = Apollo.GetString("Character_PhysMitTooltip"),
	[18] = Apollo.GetString("Character_TechMitTooltip"),
	[19] = Apollo.GetString("Character_MagicMitTooltip"),
	[21] = Apollo.GetString("Character_CritSevTooltip"),
	[22] = Apollo.GetString("Character_CombatRecoveryTooltip")
}

-- TODO: localize these
local karPrimaryStatStrings = 
{
	{Apollo.GetString("AttributeStrength"), 	String_GetWeaselString(Apollo.GetString("Character_PrimaryStat"), Apollo.GetString("AttributeStrength"))},
	{Apollo.GetString("AttributeDexterity"), 	String_GetWeaselString(Apollo.GetString("Character_PrimaryStat"), Apollo.GetString("AttributeDextarity"))},
	{Apollo.GetString("AttributeMagic"), 		String_GetWeaselString(Apollo.GetString("Character_PrimaryStat"), Apollo.GetString("AttributeMagic"))},
	{Apollo.GetString("CRB_Tech"), 				String_GetWeaselString(Apollo.GetString("Character_PrimaryStat"), Apollo.GetString("CRB_Tech"))},
	{Apollo.GetString("AttributeWisdom"), 		String_GetWeaselString(Apollo.GetString("Character_PrimaryStat"), Apollo.GetString("AttributeWisdom"))},
	{Apollo.GetString("AttributeStamina"), 		Apollo.GetString("Character_PrimaryStam")}
}

function strRound(fValue, nDecimalPlaces)
    return tonumber(string.format("%." .. (nDecimalPlaces or 0) .. "f", fValue))
end

local ksprMiniBackerOff = "kitBtn_Holo_CircleSmallNormal"
local ksprMiniBackerOn = "kitBtn_Holo_CircleSmallPressed"

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

local ktClassToAssaultPowerString = 
{
	[GameLib.CodeEnumClass.Medic] 			= Apollo.GetString("AttributeStrength"),
	[GameLib.CodeEnumClass.Esper] 			= Apollo.GetString("AttributeMagic"),
	[GameLib.CodeEnumClass.Warrior]			= Apollo.GetString("AttributeStrength"),
	[GameLib.CodeEnumClass.Stalker] 		= Apollo.GetString("AttributeDexterity"),
	[GameLib.CodeEnumClass.Engineer] 		= Apollo.GetString("AttributeDexterity"),
	[GameLib.CodeEnumClass.Spellslinger] 	= Apollo.GetString("AttributeDexterity"),
}

local ktClassToSupportPowerString = 
{
	[GameLib.CodeEnumClass.Medic] 			= Apollo.GetString("CRB_Tech"),
	[GameLib.CodeEnumClass.Esper] 			= Apollo.GetString("AttributeWisdom"),
	[GameLib.CodeEnumClass.Warrior] 		= Apollo.GetString("CRB_Tech"),
	[GameLib.CodeEnumClass.Stalker] 		= Apollo.GetString("CRB_Tech"),
	[GameLib.CodeEnumClass.Engineer] 		= Apollo.GetString("AttributeWisdom"),
	[GameLib.CodeEnumClass.Spellslinger] 	= Apollo.GetString("AttributeWisdom"),
}

local ktGuildDisplays =
{
	[GuildLib.GuildType_Guild]			= Apollo.GetString("Inspect_GuildDisplay"),
	[GuildLib.GuildType_Circle]			= Apollo.GetString("Inspect_CircleDisplay"),
	[GuildLib.GuildType_ArenaTeam_2v2]	= Apollo.GetString("Inspect_2v2ArenaDisplay"),
	[GuildLib.GuildType_ArenaTeam_3v3]	= Apollo.GetString("Inspect_3v3ArenaDisplay"),
	[GuildLib.GuildType_ArenaTeam_5v5]	= Apollo.GetString("Inspect_5v5ArenaDisplay"),
	[GuildLib.GuildType_WarParty]		= Apollo.GetString("Inspect_WarpartyDisplay")
}

function Inspect:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.listAttributes = {}

	return o
end

function Inspect:Init()
	Apollo.RegisterAddon(self)
end

-- TODO: Refactor, if costumes is enough code it can be separated into another add-on. Also it'll give it more modability anyways.
function Inspect:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Inspect.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function Inspect:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("Inspect", "OnInspect", self)
	Apollo.RegisterEventHandler("UnitTitleChange", "OnUnitTitleChange", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)

	--Apollo.RegisterEventHandler("ShowItemInDressingRoom", "OnShowItemInDressingRoom", self)

	self.wndCharacter = Apollo.LoadForm(self.xmlDoc, "CharacterWindow", nil, self)
	self.wndCharacter:Show(false)
	self.wndCostume = self.wndCharacter:FindChild("Costume")
	self.wndTitleFrame = self.wndCharacter:FindChild("TitleListFrame")
	self.wndTitleFrame:Show(false)
	self.wndCharacter:FindChild("TitleSelectButton"):AttachWindow(self.wndTitleFrame)
	self.wndCharacter:FindChild("TitleSelectButton"):Show(false)
	self.wndCharacter:FindChild("SelectCostumeWindowToggle"):Show(false)
	self.wndCharacter:FindChild("EditCostumeToggle"):Show(false)
	if self.locSavedWindowLoc then
		self.wndCharacter:MoveToLocation(self.locSavedWindowLoc)
	end

	self.bStatsValid = false
	self.tOffensiveStats = {}
	self.tDefensiveStats = {}
	self.wndCostumeSelectionList = self.wndCharacter:FindChild("CostumeBtnHolder")
	self.wndCostumeSelectionList:Show(false)

	self.arSlotsWindowsByName = -- each one has the slot name and then the corresponding UI window
	{
		{Apollo.GetString("InventorySlot_Head"), 			self.wndCharacter:FindChild("HeadSlot")}, -- TODO: No enum to compare to code
		{Apollo.GetString("InventorySlot_Shoulder"), 		self.wndCharacter:FindChild("ShoulderSlot")},
		{Apollo.GetString("InventorySlot_Chest"), 			self.wndCharacter:FindChild("ChestSlot")},
		{Apollo.GetString("InventorySlot_Hands"), 			self.wndCharacter:FindChild("HandsSlot")},
		{Apollo.GetString("InventorySlot_Legs"), 			self.wndCharacter:FindChild("LegsSlot")},
		{Apollo.GetString("InventorySlot_Feet"), 			self.wndCharacter:FindChild("FeetSlot")},
		{Apollo.GetString("InventorySlot_WeaponPrimary"), 	self.wndCharacter:FindChild("WeaponSlot")}
	}

	-- working here. replace icons of equipment with inspected equipment.
	-- generate tool tip based on equiped your equiped item and theirs.
	-- dont allow drag / drop
	
	local tSlotToWindowName = {}
	
	self.arSlotWindowsById = 
	{
		[GameLib.CodeEnumEquippedItems.Chest] 				= self.wndCharacter:FindChild("ChestSlot"),
		[GameLib.CodeEnumEquippedItems.Legs] 				= self.wndCharacter:FindChild("LegsSlot"),
		[GameLib.CodeEnumEquippedItems.Head] 				= self.wndCharacter:FindChild("HeadSlot"),
		[GameLib.CodeEnumEquippedItems.Shoulder] 			= self.wndCharacter:FindChild("ShoulderSlot"),
		[GameLib.CodeEnumEquippedItems.Feet] 				= self.wndCharacter:FindChild("FeetSlot"),
		[GameLib.CodeEnumEquippedItems.Hands] 				= self.wndCharacter:FindChild("HandsSlot"),
		[GameLib.CodeEnumEquippedItems.WeaponTool] 			= self.wndCharacter:FindChild("ToolSlot"),
		[GameLib.CodeEnumEquippedItems.WeaponAttachment] 	= self.wndCharacter:FindChild("WeaponAttachmentSlot"),
		[GameLib.CodeEnumEquippedItems.System] 				= self.wndCharacter:FindChild("SupportSystemSlot"),
		[GameLib.CodeEnumEquippedItems.Augment] 			= self.wndCharacter:FindChild("AugmentSlot"),
		[GameLib.CodeEnumEquippedItems.Implant] 			= self.wndCharacter:FindChild("ImplantSlot"),
		[GameLib.CodeEnumEquippedItems.Gadget] 				= self.wndCharacter:FindChild("GadgetSlot"),
		[GameLib.CodeEnumEquippedItems.Shields] 			= self.wndCharacter:FindChild("ShieldSlot"),
		[GameLib.CodeEnumEquippedItems.WeaponPrimary] 		= self.wndCharacter:FindChild("WeaponSlot"),
	}
	
	self.arSlotCoverWindowById = {}
	for nSlotId, wndSlot in pairs( self.arSlotWindowsById ) do
		self.arSlotCoverWindowById[nSlotId] = Apollo.LoadForm(self.xmlDoc, "InspectCover", wndSlot, self) 		
		self.arSlotCoverWindowById[nSlotId]:Show(true)
		self.arSlotCoverWindowById[nSlotId]:SetData(nSlotId) -- used in GenerateTooltip
	end
		
	self.wndCostumeFrame = self.wndCharacter:FindChild("CostumeEditFrame")
	self.wndCostumeFrame:Show(false)

	self.tCostumeBtns = {}

	for idx = 1, knNumCostumes do
		self.tCostumeBtns[idx] = self.wndCharacter:FindChild("CostumeBtn"..idx)
		self.tCostumeBtns[idx]:SetData(idx)
	end

	self.nCurrentCostume = nil
	self.arCostumeSlots = {}
	self.tCostumeSlotOverlays = {}

	for idx, tSlotInfo in ipairs(karCostumeSlotNames) do
		local wndCostumeEntry = Apollo.LoadForm(self.xmlDoc, "CostumeEntryForm", self.wndCostumeFrame:FindChild("CostumeListContainer"), self)
		wndCostumeEntry:FindChild("CostumeSlot"):ChangeArt(tSlotInfo[3])
		wndCostumeEntry:FindChild("CostumeSlot"):SetData(tSlotInfo[2])
		wndCostumeEntry:FindChild("VisibleBtn"):SetData(tSlotInfo[2])
		self.arCostumeSlots[tSlotInfo[2]] = wndCostumeEntry
		
		-- These are shown on the character window
		self.tCostumeSlotOverlays[idx] = self.wndCharacter:FindChild("CostumeItemOverlay" .. idx)
		self.tCostumeSlotOverlays[idx]:SetData(idx)
		self.tCostumeSlotOverlays[idx]:Show(false)
	end
	
	self.wndCostumeFrame:FindChild("CostumeListContainer"):ArrangeChildrenVert()

	self.wndCharacter:FindChild("PrimaryAttributeTab"):SetCheck(true)
	self.wndCharacter:FindChild("MilestoneContainer"):Show(true)
	self.wndCharacter:FindChild("SecondaryAttributeFrame"):Show(false)

	self.arMilestones =  -- window, then attribute enum for comparison
	{
		["strength"] 	= {"", Unit.CodeEnumProperties.Strength, 	1},
		["dexterity"] 	= {"", Unit.CodeEnumProperties.Dexterity, 	2},
		["technology"] 	= {"", Unit.CodeEnumProperties.Technology, 	4},
		["magic"] 		= {"", Unit.CodeEnumProperties.Magic, 		3},
		["wisdom"] 		= {"", Unit.CodeEnumProperties.Wisdom, 		5},
		["stamina"]		= {"", Unit.CodeEnumProperties.Stamina, 	6},
	}

	for iSeq = 1, 6 do
		for idx, tEntry in pairs(self.arMilestones) do
			if tEntry[3] == iSeq then
				local wndMilestone = Apollo.LoadForm(self.xmlDoc, "AttributeMilestoneEntry", self.wndCharacter:FindChild("MilestoneContainer"), self)
				tEntry[1] = wndMilestone
			end
		end
	end

	self.wndCharacter:FindChild("MilestoneContainer"):ArrangeChildrenVert()
end

function Inspect:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndCharacter, strName = Apollo.GetString("ContextMenu_Inspect")})
end

function Inspect:OnInspect(unitInspecting, arItems)
	self.unitInspecting = unitInspecting;
	
	self.arItemBySlot = {}
	for key, itemEquipped in pairs( arItems ) do
		self.arItemBySlot[ itemEquipped:GetSlot() ] = itemEquipped
	end
	
	if unitInspecting and unitInspecting:GetUnitProperties() == nil then
		local unitPlayer = GameLib.GetPlayerUnit()
		if unitPlayer and unitPlayer:IsInCombat() then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, Apollo.GetString("Inspect_YouAreInCombat"), "")
		else 
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, Apollo.GetString("Inspect_CrossFactionInPvP"), "")
		end
		unitInspecting = nil
	end
	
	if unitInspecting == nil  then
		self.wndCharacter:Show(false)
		Event_FireGenericEvent("InspectWindowHasBeenClosed")
		Sound.Play(Sound.PlayUI01ClosePhysical)
		return
	end

	if not self.wndCharacter:IsVisible() then
		Sound.Play(Sound.PlayUI68OpenPanelFromKeystrokeVirtual)
		self.wndCostumeSelectionList:Show(false)

		for idx = 1, knNumCostumes do
			self.wndCharacter:FindChild("CostumeBtn"..idx):Show(false)
		end

		self.wndCostumeFrame:Show(false)
		self.wndCharacter:Show(true)

		self.wndCharacter:ToFront()
		Event_FireGenericEvent("InspectWindowHasBeenToggled")
	end

	self:UpdateCostumeSlotIcons()
	self:DrawAttributes()

	self.wndCostume:SetCostume(unitInspecting)
	self.wndCostume:SetSheathed(self.wndCharacter:FindChild("SetSheatheBtn"):IsChecked())
	self:OnUnitTitleChange(self.unitInspecting)
end

function Inspect:OnCostumeBtnToggle(wndHandler, wndControl)
	if wndHandler ~= wndControl then 
		return false 
	end
	return true
end

function Inspect:OnEditCostumeBtnToggle(wndHandler, wndControl) -- keeping these separate as we may make you not have to wear the costume to update it in the future
	if wndHandler ~= wndControl then 
		return false 
	end
	return true
end

function Inspect:OnVisibleBtnCheck(wndHandler, wndControl)
	if wndHandler ~= wndControl then 
		return false 
	end
	return true;
end


function Inspect:UpdateCostumeSlotIcons()
-- this is our update function; it's used to repopulate the slots on the costume window (when shown) and mark what slots on the character
-- window are effected by a costume piece (when shown)

	for idx = 1, 6 do
		self.tCostumeSlotOverlays[idx]:Show(false)
	end
end

function Inspect:OnCostumeSlotQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, fValue)
	if wndHandler ~= wndControl then
		return Apollo.DragDropQueryResult.PassOn
	end
	return Apollo.DragDropQueryResult.Ignore
end

function Inspect:OnCostumeSlotDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, fValue)
	if wndHandler ~= wndControl then
		return false
	end
end

function Inspect:OnSlotClick(wndControl, wndHandler, eButton, nX, nY)
	--Sound.Play(Sound.PlayUI49EquipClothingArmorVirtual)
end

function Inspect:OnClose()
	self.wndCharacter:Show(false)
	Event_FireGenericEvent("CharacterWindowHasBeenClosed")
end

function Inspect:GetStatColor(fCurrent, fBase)
	if fCurrent > fBase then
		return CColor.new(0.0, 1.0, 0, 1.0)
	end
	if fCurrent < fBase then
		return CColor.new(1.0, 0.0, 0.0, 1.0)
	end
	return CColor.new(1.0, 1.0, 1.0, 1.0)
end

function Inspect:OnPrimaryAttributeTabBtn()
	self.wndCharacter:FindChild("MilestoneContainer"):Show(true)
	self.wndCharacter:FindChild("SecondaryAttributeFrame"):Show(false)
end

function Inspect:OnSecondaryAttributeTabBtn()
	self.wndCharacter:FindChild("MilestoneContainer"):Show(false)
	self.wndCharacter:FindChild("SecondaryAttributeFrame"):Show(true)
end

function Inspect:DrawAttributes()
	if self.unitInspecting == nil then
		return
	end

	if not self.wndCharacter:IsShown() then
		return
	end

	-- note, arProperties can be nil
	local arProperties = self.unitInspecting:GetUnitProperties()
	self:UpdateMilestones()


			
	for idx = 7,20 do -- todo: hardcoded count
		if self.wndCharacter:FindChild("StatValue" .. tostring(idx)) then
			self.wndCharacter:FindChild("StatValue" .. tostring(idx)):SetText("")
		end

		if self.wndCharacter:FindChild("StatLabel" .. tostring(idx)) then
			self.wndCharacter:FindChild("StatLabel" .. tostring(idx)):SetTooltip("")
		end
	end

	------- Assault/Support Power ------------
	local idClass = self.unitInspecting:GetClassId()
	self.wndCharacter:FindChild("AttributeValue1"):SetText(math.floor(self.unitInspecting:GetAssaultPower() or 0))
	self.wndCharacter:FindChild("AttributeValue1"):SetTooltip(Apollo.GetString("Character_AssaultTooltip"))
	self.wndCharacter:FindChild("AttributeName1"):SetTooltip(Apollo.GetString("Character_AssaultTooltip"))
	
	self.wndCharacter:FindChild("AttributeValue2"):SetText(math.floor(self.unitInspecting:GetSupportPower() or 0))
	self.wndCharacter:FindChild("AttributeValue2"):SetTooltip(Apollo.GetString("Character_SupportTooltip"))
	self.wndCharacter:FindChild("AttributeName2"):SetTooltip(Apollo.GetString("Character_SupportTooltip"))

	---------- Ratings ------------	
	-- TODO: Swap to just loading in forms instead of having the 20+ StatValue forms in xml
	local tCharacterSecondaryStats = 
	{
		[7] 	= math.ceil(self.unitInspecting:GetMaxHealth()) or 0,
		[8] 	= math.ceil(self.unitInspecting:GetShieldCapacityMax()) or 0,
		[9] 	= math.floor((self.unitInspecting:GetDeflectChance() or 0) * 10000) / 100,
		[10] 	= math.floor((self.unitInspecting:GetStrikethroughChance() or 0) * 10000) / 100,
		[11] 	= math.floor((self.unitInspecting:GetCritChance() or 0)* 10000) / 100,
		[12] 	= math.floor((self.unitInspecting:GetDeflectCritChance() or 0) * 10000) / 100,
		[16] 	= arProperties and math.floor(arProperties.Armor.fValue) or 0,
		[17] 	= math.floor((self.unitInspecting:GetPhysicalMitigation() or 0) * 10000) / 100,
		[18] 	= math.floor((self.unitInspecting:GetTechMitigation() or 0) * 10000) /100,
		[19] 	= math.floor((self.unitInspecting:GetMagicMitigation() or 0) * 10000) / 100,
		[21] 	= math.floor((self.unitInspecting:GetCritSeverity() or 0) * 10000) / 100,
		[22] 	= 2 * (self.unitInspecting:GetManaRegenInCombat() or 0),
	}

	for idx, nCurrValue in pairs(tCharacterSecondaryStats) do
		local strSuffix = ""
		if idx == 22 then --or nIdx == 23 then
			strSuffix = Apollo.GetString("Inspect_PerSec")
		elseif idx >= 9 and idx <= 21 and idx ~= 16 then
			strSuffix = Apollo.GetString("CRB_PercentFloat")
		end

		if strSuffix ~= "" then
			self.wndCharacter:FindChild("StatValue"..idx):SetText(String_GetWeaselString(strSuffix, nCurrValue))
		else
			self.wndCharacter:FindChild("StatValue"..idx):SetText(nCurrValue)
		end
		self.wndCharacter:FindChild("StatValue"..idx):SetTooltip(self:HelperBuildSecondaryTooltips(idx, arProperties))
		self.wndCharacter:FindChild("StatLabel"..idx):SetTooltip(self:HelperBuildSecondaryTooltips(idx, arProperties))
	end

	-- PvP
	local strNumberNotPercent1 = string.format("%.01f", self.unitInspecting:GetPvPOffenseRating() or 0)
	local strNumberNotPercent2 = string.format("%.01f", self.unitInspecting:GetPvPDefenseRating() or 0)
	local strPvPStatTooltip1 = String_GetWeaselString(Apollo.GetString("Character_PvPOffenseTooltip"), strNumberNotPercent1)
	local strPvPStatTooltip2 = String_GetWeaselString(Apollo.GetString("Character_PvPDefenseTooltip"), strNumberNotPercent2)
	self.wndCharacter:FindChild("PvPStatLabel1"):SetTooltip(strPvPStatTooltip1)
	self.wndCharacter:FindChild("PvPStatValue1"):SetTooltip(strPvPStatTooltip1)
	self.wndCharacter:FindChild("PvPStatLabel2"):SetTooltip(strPvPStatTooltip2)
	self.wndCharacter:FindChild("PvPStatValue2"):SetTooltip(strPvPStatTooltip2)
	self.wndCharacter:FindChild("PvPStatValue1"):SetText(string.format("%.02f", math.floor((self.unitInspecting:GetPvPOffensePercent() or 0) * 10000) / 100).."%")
	self.wndCharacter:FindChild("PvPStatValue2"):SetText(string.format("%.02f", math.floor((self.unitInspecting:GetPvPDefensePercent() or 0) * 10000) / 100).."%")

	---------- Durability ------------
	
	for iSlot = 1, #self.arSlotsWindowsByName do
		local wndItemSlot = self.arSlotsWindowsByName[iSlot][2]
		wndItemSlot:FindChild("DurabilityMeter"):SetProgress(0)
		wndItemSlot:FindChild("DurabilityAlert"):Show(false)
		wndItemSlot:FindChild("DurabilityBlocker"):Show(false)
	end

	local nDamageMin = 0
	local nDamageMax = 0
	local nDelay = 0

	if self.unitInspecting ~= nil then
		local tItems = self.arItemBySlot
		for idx, itemCurr in pairs(tItems) do

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
	
	-- cover existing items in equipment slot with items on inspected character.
	for nSlot, wndSlotCover in pairs(self.arSlotCoverWindowById) do
		if self.arItemBySlot[nSlot] then
			wndSlotCover:SetSprite(self.arItemBySlot[nSlot]:GetIcon())
		else
			wndSlotCover:SetSprite(self.arSlotWindowsById[nSlot]:GetSprWhenEmpty())
		end
	end

end

function Inspect:UpdateMilestones()
	if self.unitInspecting == nil then
		return
	end
	
	local tInfo = AttributeMilestonesLib.GetAttributeMilestoneInfo(self.unitInspecting:GetClassId())
	if tInfo.eResult == AttributeMilestonesLib.CodeEnumAttributeMilestoneResult.InvalidUnit or tInfo.eResult == AttributeMilestonesLib.CodeEnumAttributeMilestoneResult.UnknownClassId then
		return
	end

	for key, tEntry in pairs(tInfo.tMilestones) do
		if self.arMilestones[key] ~= nil then
			local wndMilestone = self.arMilestones[key][1]

			-- tCurrent can be nil
			local tCurrent = self.unitInspecting:GetUnitProperty(self.arMilestones[key][2])
			

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
			if #arRanksAndIds > 0 and tCurrent and tCurrent.fValue ~= nil then
				for idx = 1, #arRanksAndIds do  -- important! order matters for finding floor/ceiling

					if arRanksAndIds[idx] ~= nil then
						if tCurrent.fValue < arRanksAndIds[1][1] then -- rank "0"
							nRankMax = arRanksAndIds[1][1]
						elseif tCurrent.fValue >= arRanksAndIds[#arRanksAndIds][1] then -- above top rank
							bOutRanked = true
							nCurrentRank = #arRanksAndIds
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
				if bOutRanked == true then
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
				wndMilestone:FindChild("ProgressPoints"):SetProgress(tCurrent and (tCurrent.fValue - nRankFloor) or 0)
			end
			wndMilestone:FindChild("ProgressPoints"):SetStyleEx("EdgeGlow", bShowGlow)

			wndMilestone:FindChild("AttributeRank"):SetText(strRank)
			wndMilestone:FindChild("AttributeName"):SetText(tCurrent and (ktAttributeIconsText[tCurrent.idProperty][2] .. ": " .. math.floor(tCurrent.fValue) or 0) or "")
			wndMilestone:FindChild("AttributeNameIcon"):SetSprite(tCurrent and (ktAttributeIconsText[tCurrent.idProperty][1]) or "")
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

					if tCurrent and tMilestone.nRequiredAmount <= tCurrent.fValue then
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

				if tCurrent and tMilestone.bIsMini == true and tMilestone.nRequiredAmount <= tCurrent.fValue then
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
				id 				= tCurrent and tCurrent.idProperty or 0,
				tContributions 	= tContributions,
				tSecondaries 	= tEntry.tSecondaryStats,
			}

			wndMilestone:FindChild("AttributeNameIcon"):SetData(tCarriedData)
		end
	end
end

function Inspect:OnRankDisplayCheck(wndHandler, wndControl)
	if wndHandler ~= wndControl or wndControl:GetData() == nil then 
		return 
	end
	local tData = wndControl:GetData()

	if self.wndRankDisplay ~= nil then
		self.wndRankDisplay:Close()
		self.wndRankDisplay:Destroy()
	end

	self.wndRankDisplay = Apollo.LoadForm(self.xmlDoc, "RankDisplay", self.wndCharacter:FindChild("RankDisplayHook"), self)
	self.wndRankDisplay:FindChild("AttributeName"):SetText(ktAttributeIconsText[tData.id][2])
	self.wndRankDisplay:FindChild("AttributeNameIcon"):SetSprite(ktAttributeIconsText[tData.id][1])
	--wndControl:AttachWindow(self.wndRankDisplay)

	self.wndRankDisplay:FindChild("AttributeSecHeader"):SetText(String_GetWeaselString(Apollo.GetString("Character_AttributeHeader"), ktAttributeIconsText[tData.id][2]))

	local nSecondaryHeight = 0
	local wndSecondaries = self.wndRankDisplay:FindChild("AttributeSecondaries")

	for idx, tValue in pairs(tData.tSecondaries) do
		local wndSecondary = Apollo.LoadForm(self.xmlDoc, "RankSecondaryEntry", wndSecondaries, self)
		local nBonus = (math.floor(tValue.fBonus * 10)) / 10
		wndSecondary:FindChild("Text"):SetText(String_GetWeaselString(Apollo.GetString("Inspect_StatBonus"), nBonus, ktAttributeIconsText[tValue.eUnitProperty][2]))
		wndSecondary:FindChild("Text"):SetHeightToContentHeight()
		wndSecondary:FindChild("Icon"):SetSprite(ktAttributeIconsText[tValue.eUnitProperty][1])
		nSecondaryHeight = nSecondaryHeight + math.max(wndSecondary:FindChild("Text"):GetHeight(), 19)
	end

	local nAttributeLeft, nAttributeTop, nAttributeRight, nAttributeBottom = wndSecondaries:GetAnchorOffsets()
	wndSecondaries:SetAnchorOffsets(nAttributeLeft, nAttributeTop, nAttributeRight, nAttributeTop + nSecondaryHeight + 3)
	wndSecondaries:ArrangeChildrenVert()
	nAttributeLeft, nAttributeTop, nAttributeRight, nAttributeBottom = wndSecondaries:GetAnchorOffsets() -- used further down

	local wndDivider = Apollo.LoadForm(self.xmlDoc, "RankDivider", self.wndRankDisplay, self)
	local nDividerLeft, nDividerTop, nDividerRight, nDividerBottom = wndDivider:GetAnchorOffsets()
	wndDivider:SetAnchorOffsets(nDividerLeft, 5 + nAttributeBottom, nDividerRight, 6 + nAttributeBottom + nDividerBottom)
	nDividerLeft, nDividerTop, nDividerRight, nDividerBottom = wndDivider:GetAnchorOffsets() -- used further down

	local wndRankTiers = self.wndRankDisplay:FindChild("AttributeRanks")
	local nRankLeft, nRankTop, nRankRight, nRankBottom = wndRankTiers:GetAnchorOffsets()
	local nTierHeight = 0

	--[[if t.nRank == 0 then
		local wndUnlockDiv = Apollo.LoadForm("Inspect.xml", "RankUnlockDivider", wndRankTiers, self)
		wndUnlockDiv:FindChild("RankProgLabel"):SetText("Rank " .. 1)
		wndUnlockDiv:FindChild("ProgressBar"):SetFloor(0)
		wndUnlockDiv:FindChild("ProgressBar"):SetMax(100)
		wndUnlockDiv:FindChild("ProgressBar"):SetProgress(t.nPercent)
		nTierHeight = nTierHeight + wndUnlockDiv:GetHeight()
	end--]]

	for idx = 1, #tData.tRanks do
		if tData.tRanks[idx] and tData.tRanks[idx][2] then
			local wndTier = Apollo.LoadForm(self.xmlDoc, "RankTierEntry", wndRankTiers, self)
			local splMilestone = GameLib.GetSpell(tData.tRanks[idx][2])
			local strDesc = nil
			if splMilestone then
				strDesc = splMilestone:GetFlavor() --mmmmmmmmm
			end
			local strBodyColor = "ff2f94ac"
			local strTierColor = "002f94ac"


			if strDesc and string.len(strDesc) > 0 then
				if tData.value >= tData.tRanks[idx][1] then
					strBodyColor = "ffffffff"
					strTierColor = "ffffffff"
					wndTier:FindChild("RankEnumBaseUnder"):Show(false)
				end

				--wndTier:SetText(idx .. " - " .. t.tRanks[idx][2] .. " Needs: " ..  t.tRanks[idx][1])
				wndTier:FindChild("RankEnum"):SetText(string.format("<T Align=\"Center\" Font=\"CRB_HeaderHuge\" TextColor=\"%s\">%s</T>", strTierColor, idx))
				wndTier:FindChild("RankDesc"):SetText(string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", strBodyColor, strDesc))
				wndTier:FindChild("RankDesc"):SetHeightToContentHeight()
				local nDescLeft, nDescTop, nDescRight, nDescBottom = wndTier:FindChild("RankDesc"):GetAnchorOffsets()
				local nTierLeft, nTierTop, nTierRight, nTierBottom = wndTier:GetAnchorOffsets()
				nDescBottom =  math.max(nDescBottom, 40)
				wndTier:SetAnchorOffsets(nTierLeft, nTierTop, nTierRight, nDescBottom + 5)
				nTierHeight = nTierHeight + nDescBottom + 5
			end

			if idx == tData.nRank and idx ~= #tData.tRanks then
				local wndUnlockDiv = Apollo.LoadForm(self.xmlDoc, "RankUnlockDivider", wndRankTiers, self)
				wndUnlockDiv:FindChild("RankProgLabel"):SetText(String_GetWeaselString(Apollo.GetString("Inspect_Rank"), idx + 1))
				wndUnlockDiv:FindChild("ProgressBar"):SetFloor(0)
				wndUnlockDiv:FindChild("ProgressBar"):SetMax(100)
				wndUnlockDiv:FindChild("ProgressBar"):SetProgress(tData.nPercent)
				nTierHeight = nTierHeight + wndUnlockDiv:GetHeight()
			end
		end
	end

	wndRankTiers:SetAnchorOffsets(nRankLeft, nDividerBottom, nRankRight, nDividerBottom + nTierHeight)
	wndRankTiers:ArrangeChildrenVert()
	nRankLeft, nRankTop, nRankRight, nRankBottom = wndRankTiers:GetAnchorOffsets()

	local nWndLeft, nWndTop, nWndRight, nWndBottom = self.wndRankDisplay:GetAnchorOffsets()
	local nTotal = wndSecondaries:GetHeight() + wndDivider:GetHeight() + wndRankTiers:GetHeight() + 8 --extra padding for the frame
	local nHalf = (nWndTop + nAttributeTop + nTotal) / 2

	self.wndRankDisplay:SetAnchorOffsets(nWndLeft, -nHalf, nWndRight, nHalf)
end

function Inspect:OnRankDisplayClose(wndHandler, wndControl)
	if self.wndRankDisplay ~= nil then
		self.wndRankDisplay:Close()
		self.wndRankDisplay:Destroy()
	end
end

function Inspect:HelperBuildSecondaryTooltips(idx, arProperties)
	if idx <= 8 or idx == 16 then
		return ktCharacterSecondaryStats[idx]
	end

	--These Should Be Enums
	local tProperties = 
	{
		[9]  = string.format("%.01f", arProperties and arProperties.Rating_AvoidIncrease.fValue or 0),
		[10] = string.format("%.01f", arProperties and arProperties.Rating_AvoidReduce.fValue or 0),
		[11] = string.format("%.01f", arProperties and arProperties.Rating_CritChanceIncrease.fValue or 0),
		[12] = string.format("%.01f", arProperties and arProperties.Rating_CritChanceDecrease.fValue or 0),
		[17] = string.format("%.01f", arProperties and arProperties.ResistPhysical.fValue or 0),
		[18] = string.format("%.01f", arProperties and arProperties.ResistTech.fValue or 0),
		[19] = string.format("%.01f", arProperties and arProperties.ResistMagic.fValue or 0),
		[21] = string.format("%.01f", arProperties and arProperties.RatingCritSeverityIncrease.fValue or 0),
		[22] = string.format("%.01f", arProperties and arProperties.ManaPerFiveSeconds.fValue or 0),
	}

	return String_GetWeaselString(ktCharacterSecondaryStats[idx], tProperties[idx]) or ""
end

function Inspect:OnGenerateInspectTooltip(wndHandler, wndControl, eToolTipType, x, y)
	if wndHandler ~= wndControl then 
		return 
	end
	
	local nSlot = wndControl:GetData()
	
	-- the equipment windows are stilpl there, so we will use them to grab our item.
	local itemInspect = self.arItemBySlot[nSlot]
	
	local itemEquipped
	if self.arSlotWindowsById[nSlot] then
		itemEquipped = self.arSlotWindowsById[nSlot]:GetItem()
	end
	
	if itemInspect then -- or itemEquipped then	-- OLD	
		if itemInspect then
			Tooltip.GetItemTooltipForm(self, wndControl, itemInspect, {bPrimary = false, bSelling = false, itemCompare = itemEquipped})
		end
		
		--if itemEquipped then -- OLD
		--	Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = true, bSelling = false, itemCompare = itemInspect})
		--end
	else
		local strTooltip = ""
		if wndControl:GetName() then
			strTooltip = ktSlotWindowNameToTooltip[wndControl:GetName()]
		end
		if strTooltip then
			wndControl:SetTooltip("<P Font=\"CRB_InterfaceSmall_O\">"..strTooltip.."</P>")
		end
	end
	return true
end

function Inspect:OnUnitTitleChange(unitUpdated)
	if unitUpdated ~= self.unitInspecting then
		return
	end

	local strResult = ""
	local eGuildTagType = self.unitInspecting:GetGuildType()
	if eGuildTagType and ktGuildDisplays[eGuildTagType] ~= nil then
		strResultAffiliation = String_GetWeaselString(ktGuildDisplays[eGuildTagType], self.unitInspecting:GetAffiliationName())
		strResultName = String_GetWeaselString(Apollo.GetString("Inspect_Inspecting"), self.unitInspecting:GetTitleOrName())
		self.wndCharacter:FindChild("PlayerNameOnly"):SetText("")
		self.wndCharacter:FindChild("PlayerName"):SetText(strResultName)
		self.wndCharacter:FindChild("PlayerNameAffiliation"):SetText(strResultAffiliation)
	else
		strResult = String_GetWeaselString(Apollo.GetString("Inspect_Inspecting"), self.unitInspecting:GetTitleOrName())
		self.wndCharacter:FindChild("PlayerName"):SetText("")
		self.wndCharacter:FindChild("PlayerNameOnly"):SetText(strResult)
		self.wndCharacter:FindChild("PlayerNameAffiliation"):SetText("")
	end

end

function Inspect:OnRotateRight()
	self.wndCostume:ToggleLeftSpin(true)
end

function Inspect:OnRotateRightCancel()
	self.wndCostume:ToggleLeftSpin(false)
end

function Inspect:OnRotateLeft()
	self.wndCostume:ToggleRightSpin(true)
end

function Inspect:OnRotateLeftCancel()
	self.wndCostume:ToggleRightSpin(false)
end

function Inspect:OnSheatheCheck(wndHandler, wndControl)
	self.wndCostume:SetSheathed(wndControl:IsChecked())
end

local InspectInstance = Inspect:new()
InspectInstance:Init()

