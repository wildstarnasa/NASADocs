-----------------------------------------------------------------------------------------------
-- Client Lua Script for Runecrafting
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CraftingLib"
require "GameLib"
require "Item"

local knNumRandomRerollFlavor = 4
local knLevelRequirement = 15

local karElementsToSprite =
{
	[Item.CodeEnumRuneType.Air]		= { strBtn = "sprRunecrafting_Btn_Air", 	strBright = "Icon_Windows_UI_RuneSlot_Air_Used",	strFade = "Icon_Windows_UI_RuneSlot_Air_Empty" },
	[Item.CodeEnumRuneType.Fire]	= { strBtn = "sprRunecrafting_Btn_Fire", 	strBright = "Icon_Windows_UI_RuneSlot_Fire_Used",	strFade = "Icon_Windows_UI_RuneSlot_Fire_Empty" },
	[Item.CodeEnumRuneType.Water]	= { strBtn = "sprRunecrafting_Btn_Water", 	strBright = "Icon_Windows_UI_RuneSlot_Water_Used",	strFade = "Icon_Windows_UI_RuneSlot_Water_Empty" },
	[Item.CodeEnumRuneType.Earth]	= { strBtn = "sprRunecrafting_Btn_Earth", 	strBright = "Icon_Windows_UI_RuneSlot_Earth_Used",	strFade = "Icon_Windows_UI_RuneSlot_Earth_Empty" },
	[Item.CodeEnumRuneType.Logic]	= { strBtn = "sprRunecrafting_Btn_Logic", 	strBright = "Icon_Windows_UI_RuneSlot_Logic_Used",	strFade = "Icon_Windows_UI_RuneSlot_Logic_Empty" },
	[Item.CodeEnumRuneType.Life]	= { strBtn = "sprRunecrafting_Btn_Life", 	strBright = "Icon_Windows_UI_RuneSlot_Life_Used",	strFade = "Icon_Windows_UI_RuneSlot_Life_Empty" },
	[Item.CodeEnumRuneType.Fusion]	= { strBtn = "sprRunecrafting_Btn_Fusion", 	strBright = "Icon_Windows_UI_RuneSlot_Fusion_Used",	strFade = "Icon_Windows_UI_RuneSlot_Fusion_Empty" },
	[Item.CodeEnumRuneType.Omni]	= { strBtn = "sprRunecrafting_Btn_Omni", 	strBright = "Icon_Windows_UI_RuneSlot_Omni_Used",	strFade = "Icon_Windows_UI_RuneSlot_Omni_Empty" },
}

local karElementalsToMetal =
{
	[Item.CodeEnumRuneType.Air]		= { strIcon = "sprRunecrafting_Air_Colored", 	strBright = "sprRunecrafting_Air",		strFade = "sprRunecrafting_AirFade" },
	[Item.CodeEnumRuneType.Fire]	= { strIcon = "sprRunecrafting_Fire_Colored", 	strBright = "sprRunecrafting_Fire",		strFade = "sprRunecrafting_FireFade" },
	[Item.CodeEnumRuneType.Water]	= { strIcon = "sprRunecrafting_Water_Colored", 	strBright = "sprRunecrafting_Water",	strFade = "sprRunecrafting_WaterFade" },
	[Item.CodeEnumRuneType.Earth]	= { strIcon = "sprRunecrafting_Earth_Colored", 	strBright = "sprRunecrafting_Earth",	strFade = "sprRunecrafting_EarthFade" },
	[Item.CodeEnumRuneType.Logic]	= { strIcon = "sprRunecrafting_Logic_Colored", 	strBright = "sprRunecrafting_Logic",	strFade = "sprRunecrafting_LogicFade" },
	[Item.CodeEnumRuneType.Life]	= { strIcon = "sprRunecrafting_Life_Colored", 	strBright = "sprRunecrafting_Life",		strFade = "sprRunecrafting_LifeFade" },
	[Item.CodeEnumRuneType.Fusion]	= { strIcon = "sprRunecrafting_Fusion_Colored", strBright = "sprRunecrafting_Fusion",	strFade = "sprRunecrafting_FusionFade" },
	[Item.CodeEnumRuneType.Omni]	= { strIcon = "sprRunecrafting_Omni_Colored", 	strBright = "sprRunecrafting_Omni",		strFade = "sprRunecrafting_OmniFade" },
}

local karElementsToName =
{
	[Item.CodeEnumRuneType.Air]		= { strLetter = "A",	strName = Apollo.GetString("CRB_Air") },
	[Item.CodeEnumRuneType.Fire]	= { strLetter = "F",	strName = Apollo.GetString("CRB_Fire") },
	[Item.CodeEnumRuneType.Water]	= { strLetter = "W",	strName = Apollo.GetString("CRB_Water") },
	[Item.CodeEnumRuneType.Earth]	= { strLetter = "E",	strName = Apollo.GetString("CRB_Earth") },
	[Item.CodeEnumRuneType.Logic]	= { strLetter = "O",	strName = Apollo.GetString("CRB_Logic") },
	[Item.CodeEnumRuneType.Life]	= { strLetter = "L",	strName = Apollo.GetString("CRB_Life") },
	[Item.CodeEnumRuneType.Fusion]	= { strLetter = "U",	strName = Apollo.GetString("CRB_Fusion") },
	[Item.CodeEnumRuneType.Omni]	= { strLetter = "",		strName = Apollo.GetString("CRB_Omni") },
}

local karElementsToId = -- TODO: Replace with enums
{
	[Item.CodeEnumRuneType.Fire]		= 131,
	[Item.CodeEnumRuneType.Water]		= 132,
	[Item.CodeEnumRuneType.Earth]		= 133,
	[Item.CodeEnumRuneType.Air]			= 134,
	[Item.CodeEnumRuneType.Life]		= 135,
	[Item.CodeEnumRuneType.Logic]		= 136,
	[Item.CodeEnumRuneType.Fusion]		= 137,
	[Item.CodeEnumRuneType.Omni]		= 0,
}

local ktAttributeToText =
{
	[Unit.CodeEnumProperties.Dexterity] 					= Apollo.GetString("CRB_Finesse"),
	[Unit.CodeEnumProperties.Technology] 					= Apollo.GetString("CRB_Tech_Attribute"),
	[Unit.CodeEnumProperties.Magic] 						= Apollo.GetString("CRB_Moxie"),
	[Unit.CodeEnumProperties.Wisdom] 						= Apollo.GetString("UnitPropertyInsight"),
	[Unit.CodeEnumProperties.Stamina] 						= Apollo.GetString("CRB_Grit"),
	[Unit.CodeEnumProperties.Strength] 						= Apollo.GetString("CRB_Brutality"),

	[Unit.CodeEnumProperties.Armor] 						= Apollo.GetString("CRB_Armor") ,
	[Unit.CodeEnumProperties.ShieldCapacityMax] 			= Apollo.GetString("CBCrafting_Shields"),

	[Unit.CodeEnumProperties.AssaultPower] 					= Apollo.GetString("CRB_Assault_Power"),
	[Unit.CodeEnumProperties.SupportPower] 					= Apollo.GetString("CRB_Support_Power"),
	[Unit.CodeEnumProperties.Rating_AvoidReduce] 			= Apollo.GetString("CRB_Strikethrough_Rating"),
	[Unit.CodeEnumProperties.Rating_CritChanceIncrease] 	= Apollo.GetString("CRB_Critical_Chance"),
	[Unit.CodeEnumProperties.RatingCritSeverityIncrease] 	= Apollo.GetString("CRB_Critical_Severity"),
	[Unit.CodeEnumProperties.Rating_AvoidIncrease] 			= Apollo.GetString("CRB_Deflect_Rating"),
	[Unit.CodeEnumProperties.Rating_CritChanceDecrease] 	= Apollo.GetString("CRB_Deflect_Critical_Hit_Rating"),
	[Unit.CodeEnumProperties.ManaPerFiveSeconds] 			= Apollo.GetString("CRB_Attribute_Recovery_Rating"),
	[Unit.CodeEnumProperties.HealthRegenMultiplier] 		= Apollo.GetString("CRB_Health_Regen_Factor"),
	[Unit.CodeEnumProperties.BaseHealth] 					= Apollo.GetString("CRB_Health_Max"),

	[Unit.CodeEnumProperties.ResistTech] 					= Apollo.GetString("Tooltip_ResistTech"),
	[Unit.CodeEnumProperties.ResistMagic]					= Apollo.GetString("Tooltip_ResistMagic"),
	[Unit.CodeEnumProperties.ResistPhysical]				= Apollo.GetString("Tooltip_ResistPhysical"),

	[Unit.CodeEnumProperties.PvPOffensiveRating] 			= Apollo.GetString("Tooltip_PvPOffense"),
	[Unit.CodeEnumProperties.PvPDefensiveRating]			= Apollo.GetString("Tooltip_PvPDefense"),
}

local Runecrafting = {}

function Runecrafting:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Runecrafting:Init()
    Apollo.RegisterAddon(self)
end

function Runecrafting:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Runecrafting.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Runecrafting:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	math.randomseed(os.time())

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 					"OnInterfaceMenuListHasLoaded", self)
	-- Apollo.RegisterEventHandler("WindowManagementReady", 					"OnWindowManagementReady", self) -- Temporarily disabled

	Apollo.RegisterEventHandler("GenericEvent_RightClick_OpenEngraving", 		"OnOpenEquipTab", self)
	Apollo.RegisterEventHandler("GenericEvent_InterfaceMenu_OpenEngraving", 	"OnOpenEquipTab", self)
	Apollo.RegisterEventHandler("GenericEvent_CraftingResume_OpenEngraving", 	"OnOpenCraftingResume", self)
	Apollo.RegisterEventHandler("GenericEvent_CraftingSummary_Closed", 			"OnCloseSummary", self)
	Apollo.RegisterEventHandler("GenericEvent_CraftingResume_CloseEngraving", 	"OnClose", self)
	Apollo.RegisterEventHandler("TradeskillEngravingStationClose", 				"OnClose", self)
	Apollo.RegisterEventHandler("UpdateInventory", 								"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 					"OnRedrawAllFromUI", self)
	Apollo.RegisterEventHandler("ItemModified", 								"OnRedrawAllFromUI", self)

	Apollo.RegisterTimerHandler("Runecrafting_RerollDelay",						"OnRedrawAllFromUI", self)
	Apollo.CreateTimer("Runecrafting_RerollDelay", 1.5, false)
	Apollo.StopTimer("Runecrafting_RerollDelay")

	Apollo.RegisterTimerHandler("Runecrafting_ConfirmPopupDelay",				"OnRunecrafting_ConfirmPopupDelay", self)
	Apollo.CreateTimer("Runecrafting_ConfirmPopupDelay", 0.15, false)
	Apollo.StopTimer("Runecrafting_ConfirmPopupDelay")

	self.timerCraftingSation = ApolloTimer.Create(1.0, true, "OnRunecrafting_TimerStationCheck", self)

	Apollo.RegisterEventHandler("DragDropSysBegin", 							"OnSystemBeginDragDrop", self)
	Apollo.RegisterEventHandler("DragDropSysEnd", 								"OnSystemEndDragDrop", self)
end

function Runecrafting:OnInterfaceMenuListHasLoaded()
	local tData = { "GenericEvent_InterfaceMenu_OpenEngraving", "", "Icon_Windows32_UI_CRB_InterfaceMenu_Runecrafting" }
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("EngravingStation_RunecraftingTitle"), tData)
end

function Runecrafting:OnWindowManagementReady()
	--Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("EngravingStation_RunecraftingTitle")})
end

function Runecrafting:OnOpenEquipTab(itemArg) -- Optional Arg
	self:Initialize()
	self.wndMain:FindChild("ToggleRuneCreation"):SetCheck(false)
	self.wndMain:FindChild("ToggleEquipRunes"):SetCheck(true)
	self:RedrawAll(itemArg)
end

function Runecrafting:OnOpenCraftingResume()
	self:Initialize()
	self:RedrawAll()
	self.tWindowMap["RerollItemTitle"]:SetText(Apollo.GetString("EngravingStation_RuneSlotRerollTitleResume"))
end

function Runecrafting:Initialize()
	if self.wndMain and self.wndMain:IsValid() then
		return
	end

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "RunecraftingForm", nil, self)

	self.wndMain:FindChild("BGFrame"):FindChild("ShowTutorialsBtn"):Enable(false)
	self.wndMain:FindChild("RuneCreationContainer"):FindChild("RuneCreationCraftBtn"):Enable(false)
	self.wndMain:FindChild("ToggleRuneCreation"):AttachWindow(self.wndMain:FindChild("RuneCreationContainer"))
	self.wndMain:FindChild("ToggleEquipRunes"):AttachWindow(self.wndMain:FindChild("EquipRunesContainer"))

	self.tWindowMap =
	{
		["PostCraftBlocker"]			= self.wndMain:FindChild("BGFrame:PostCraftBlocker"),
		["CraftingSummaryContainer"]	= self.wndMain:FindChild("BGFrame:PostCraftBlocker:CraftingSummaryContainer"),
		["RerollBlocker"]				= self.wndMain:FindChild("BGFrame:RerollBlocker"),
		["RerollInitCastBarBG"]			= self.wndMain:FindChild("BGFrame:RerollBlocker:RerollInitCastBarBG"),
		["RerollDoneCastBarBG"]			= self.wndMain:FindChild("BGFrame:RerollBlocker:RerollDoneCastBarBG"),
		["RerollBlockerHoloBG"]			= self.wndMain:FindChild("BGFrame:RerollBlocker:RerollBlockerHoloBG"),
		["RerollItemTitle"]				= self.wndMain:FindChild("BGFrame:RerollBlocker:RerollBlockerHoloBG:RerollItemTitle"),
		["RuneCreationName"]			= self.wndMain:FindChild("RuneCreationContainer:RuneCreationBottom:RuneCreationName"),
		["RuneCreationNoStationBG"]		= self.wndMain:FindChild("RuneCreationContainer:RuneCreationBottom:RuneCreationNoStationBG"),
		["RuneCreationNoSignal"]		= self.wndMain:FindChild("RuneCreationContainer:RuneCreationBottom:RuneCreationNoStationBG:RuneCreationNoSignal"),
		["RuneCreationNoSignalText"]	= self.wndMain:FindChild("RuneCreationContainer:RuneCreationBottom:RuneCreationNoStationBG:RuneCreationNoSignalText"),
	}

	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "EquipmentItem", nil, self)
	self.knEquipmentItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "TypeTierItem", nil, self)
	self.knDefaultTypeTierItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	-- Variables
	self.bAllowClicks = true
	self.itemDragging = nil
	self.wndCurrentConfirmPopup = nil

	local bRequirementMet = true
	local nPlayerLevel = GameLib.GetPlayerLevel()
	if nPlayerLevel and nPlayerLevel < knLevelRequirement then
		self.wndMain:FindChild("RuneCreationItemList"):SetTextColor(ApolloColor.new("UI_WindowTextCraftingRedCapacitor"))
		self.wndMain:FindChild("RuneCreationItemList"):SetText(String_GetWeaselString(Apollo.GetString("Runecrafting_LevelRequirementNotMet"), knLevelRequirement))
		bRequirementMet = false
	else
		self.wndMain:FindChild("RuneCreationItemList"):SetTextColor(ApolloColor.new("UI_TextHoloBodyHighlight"))
		self.wndMain:FindChild("RuneCreationItemList"):SetText(Apollo.GetString("Runecrafting_StartingHelperTip"))
	end

	-- Initialize Elements
	local wndParent = self.wndMain:FindChild("RuneCreationElementList")
	for idx, eElement in pairs(Item.CodeEnumRuneType) do
		if eElement ~= Item.CodeEnumRuneType.Omni then -- There are no Omni runes, so skip
			local wndCurr = self:LoadByName("RuneCreationElementItem", wndParent, idx)
			wndCurr:FindChild("RuneCreationElementBtn"):SetData(eElement)
			wndCurr:FindChild("RuneCreationElementBtn"):Enable(bRequirementMet)
			wndCurr:FindChild("RuneCreationElementIcon"):SetSprite(karElementalsToMetal[eElement].strFade)
			wndCurr:FindChild("RuneCreationElementName"):SetText(karElementsToName[eElement].strName)
			wndCurr:FindChild("RuneCreationElementName"):SetTextColor("WindowTitleColor")
		end
	end
	wndParent:ArrangeChildrenVert(0, function(a,b) return a:GetName() < b:GetName() end)
end

function Runecrafting:OnRunecrafting_TimerStationCheck() -- Hackish: These are async from the rest of the UI (and definitely can't handle data being set)
	if self.wndMain and self.wndMain:IsValid() then
		local bAtStation = CraftingLib.IsAtEngravingStation()
		self.tWindowMap["RuneCreationNoStationBG"]:Show(not bAtStation)
		self.tWindowMap["RuneCreationNoSignal"]:Show(not bAtStation and self.tWindowMap["RuneCreationName"]:GetText() == "")
		self.tWindowMap["RuneCreationNoSignalText"]:Show(not bAtStation and self.tWindowMap["RuneCreationName"]:GetText() == "")
	end
end

function Runecrafting:OnCloseFromUI(wndHandler, wndControl)
	if wndHandler == wndControl then
		self:OnClose()
	end
end

function Runecrafting:OnClose()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
		self.tWindowMap = nil
	end

	Event_CancelEngravingStation()
end

function Runecrafting:OnRedrawAllFromUI()
	self:RedrawAll()
end

function Runecrafting:OnRuneCreationElementToggle(wndHandler, wndControl)
	for idx, wndCurr in pairs(self.wndMain:FindChild("RuneCreationElementList"):GetChildren()) do
		if wndCurr:FindChild("RuneCreationElementName") then
			wndCurr:FindChild("RuneCreationElementName"):SetTextColor(wndCurr:FindChild("RuneCreationElementBtn"):IsChecked() and "UI_WindowTitleYellow" or "WindowTitleColor")
		end
	end

	self.wndMain:FindChild("RuneCreationItemList"):SetText(Apollo.GetString("Runecrafting_StartingHelperTip"))
	self.wndMain:FindChild("RuneCreationItemList"):DestroyChildren() -- May be able to refactor this
	self.wndMain:FindChild("RuneCreationItemList"):RecalculateContentExtents()
	self:ResetRuneCreationBottom()
	self:RedrawAll()
end

-----------------------------------------------------------------------------------------------
-- Main Draw Method
-----------------------------------------------------------------------------------------------

function Runecrafting:RedrawAll(itemToOpenTo)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	if self.wndMain:FindChild("ToggleRuneCreation"):IsChecked() then
		self:RedrawCreation()
	elseif self.wndMain:FindChild("ToggleEquipRunes"):IsChecked() then
		self:RedrawEquipment(itemToOpenTo)
	end

	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	if tCurrentCraft and tCurrentCraft.arSlotTypes and not self.tWindowMap["RerollDoneCastBarBG"]:IsShown() then
		self:RedrawRerollBlocker(tCurrentCraft)
	elseif not self.tWindowMap["RerollInitCastBarBG"]:IsShown() then
		self.tWindowMap["RerollBlocker"]:Show(false)
		self.tWindowMap["RerollDoneCastBarBG"]:Show(false)
	end
end

function Runecrafting:RedrawRerollBlocker(tCurrentCraft)
	self.tWindowMap["RerollBlocker"]:Show(true)
	self.tWindowMap["RerollBlockerHoloBG"]:Show(true)
	self.tWindowMap["RerollInitCastBarBG"]:Show(false)

	local itemSelected = tCurrentCraft.itemSelected
	local tRuneData = itemSelected:GetRuneSlots()
	local tPreviousRune = tRuneData.arRuneSlots[tCurrentCraft.nSlotIndex]

	local eSlot1 = tCurrentCraft.arSlotTypes[1]
	local eSlot2 = tCurrentCraft.arSlotTypes[2]
	local wndRerollBlocker = self.tWindowMap["RerollBlocker"]
	wndRerollBlocker:FindChild("RerollElementLeftBtn"):SetData(eSlot1)
	wndRerollBlocker:FindChild("RerollElementLeftBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.RuneSlotFinishReroll, eSlot1)
	wndRerollBlocker:FindChild("RerollElementRightBtn"):SetData(eSlot2)
	wndRerollBlocker:FindChild("RerollElementRightBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.RuneSlotFinishReroll, eSlot2)
	wndRerollBlocker:FindChild("RerollElementAbandonBtn"):SetData(tCurrentCraft.nSchematicId)
	wndRerollBlocker:FindChild("RerollElementAbandonBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.CraftingAbandon)

	-- Formatting
	local strDescription = String_GetWeaselString(Apollo.GetString("EngravingStation_SlotPreviously"), tCurrentCraft.nSlotIndex, karElementsToName[tPreviousRune.eType].strName)
	wndRerollBlocker:FindChild("RerollElementLeftIcon"):SetSprite(karElementsToSprite[eSlot1].strBtn)
	wndRerollBlocker:FindChild("RerollElementRightIcon"):SetSprite(karElementsToSprite[eSlot2].strBtn)
	wndRerollBlocker:FindChild("RerollElementAbandonIcon"):SetSprite(karElementsToSprite[tPreviousRune.eType].strBtn)
	wndRerollBlocker:FindChild("RerollElementAbandonBtn"):SetText("")
	wndRerollBlocker:FindChild("RerollItemName"):SetText(itemSelected:GetName())
	wndRerollBlocker:FindChild("RerollItemDescription"):SetText(strDescription)
	wndRerollBlocker:FindChild("RerollItemIcon"):SetSprite(itemSelected:GetIcon())
	Tooltip.GetItemTooltipForm(self, wndRerollBlocker:FindChild("RerollItemIcon"), itemSelected, {bSelling = false})

	-- Random Quip
	local tRandomElement = { karElementsToName[eSlot1].strLetter, karElementsToName[eSlot2].strLetter }
	local strRandom = Apollo.GetString("Runecrafting_RandomFlavor_"..tRandomElement[math.random(1,2)]..math.random(1, knNumRandomRerollFlavor)) or ""
	wndRerollBlocker:FindChild("RerollSpeechText"):SetText(strRandom)
end

function Runecrafting:RedrawEquipment(itemToOpenTo)
	local wndScroll = self.wndMain:FindChild("MainItemList")
	local nVScrollPos = wndScroll:GetVScrollPos()
	wndScroll:DestroyChildren()

	local nScrollHeightCounter = 0
	local nScrollHeightOverride = 0
	for idx, tCurrItem in pairs(CraftingLib.GetItemsWithRuneSlots(true, false)) do -- 1st arg is Equipped
		if tCurrItem == itemToOpenTo then
			nScrollHeightOverride = nScrollHeightCounter
		end

		if tCurrItem then
			self:NewEquipmentItem(tCurrItem, wndScroll, true)
			nScrollHeightCounter = nScrollHeightCounter + self.knEquipmentItemHeight
		end
	end

	for idx, tCurrItem in pairs(CraftingLib.GetItemsWithRuneSlots(false, true)) do -- 2nd arg is Inventory
		if tCurrItem == itemToOpenTo then
			nScrollHeightOverride = nScrollHeightCounter
		end

		if tCurrItem then
			self:NewEquipmentItem(tCurrItem, wndScroll)
			nScrollHeightCounter = nScrollHeightCounter + self.knEquipmentItemHeight
		end
	end

	wndScroll:ArrangeChildrenVert(0)
	wndScroll:SetVScrollPos(nScrollHeightOverride > 0 and nScrollHeightOverride or nVScrollPos)
	wndScroll:RecalculateContentExtents()
	wndScroll:SetText(#self.wndMain:FindChild("MainItemList"):GetChildren() == 0 and Apollo.GetString("EngravingStation_NoInscribableItems") or "")
end

function Runecrafting:RedrawCreation()
	-- Determine element filter
	local eElementFilter = nil
	for idx, wndCurr in pairs(self.wndMain:FindChild("RuneCreationElementList"):GetChildren()) do
		local wndCurrBtn = wndCurr:FindChild("RuneCreationElementBtn")
		wndCurrBtn:FindChild("RuneCreationElementIcon"):SetSprite(karElementalsToMetal[wndCurrBtn:GetData()].strFade)
		wndCurrBtn:FindChild("RuneCreationElementIconBright"):SetSprite(karElementalsToMetal[wndCurrBtn:GetData()].strBright)
		wndCurrBtn:FindChild("RuneCreationElementIconBright"):Show(wndCurrBtn:IsChecked(), false, 0.4)

		if wndCurrBtn and wndCurrBtn:IsChecked() then
			eElementFilter = karElementsToId[wndCurrBtn:GetData()] or nil
		end
	end

	if not eElementFilter then
		return
	end

	-- Prebuild the table
	local tSchematicList = {}
	for idx, tCurrSchematic in pairs(CraftingLib.GetSchematicList(CraftingLib.CodeEnumTradeskill.Runecrafting, eElementFilter, nil, false)) do
		local tSchematicInfo = CraftingLib.GetSchematicInfo(tCurrSchematic.nSchematicId)
		local strItemType = tSchematicInfo.itemOutput:GetItemTypeName() -- This will be Earth Tier 1, Earth Tier 2, etc.
		if not tSchematicList[strItemType] then
			tSchematicList[strItemType] = {}
		end
		tSchematicList[strItemType][idx] = { tCurrSchematic = tCurrSchematic, tSchematicInfo = tSchematicInfo }
	end

	-- Draw Runes
	local wndPrevChecked = nil
	local wndCreateARuneParent = self.wndMain:FindChild("RuneCreationItemList")
	for strItemType, tRuneList in pairs(tSchematicList) do
		local wndTypeTier = self:LoadByName("TypeTierItem", wndCreateARuneParent, "TypeTierItem"..strItemType)
		wndTypeTier:FindChild("TypeTierItemLabel"):SetText(strItemType)
		wndTypeTier:FindChild("TypeTierItemBtn"):SetData(wndTypeTier)
		wndTypeTier:FindChild("TypeTierItemContainer"):DestroyChildren()
		wndTypeTier:SetData(tRuneList)

		if wndTypeTier:FindChild("TypeTierItemBtn"):IsChecked() then
			wndPrevChecked = wndTypeTier
		end
		wndTypeTier:FindChild("TypeTierItemBtn"):SetCheck(false)
	end

	-- Check the first in list, after sorting
	wndCreateARuneParent:SetText("")
	wndCreateARuneParent:ArrangeChildrenVert(0, function(a,b) return a:GetName() < b:GetName() end)
	if wndPrevChecked then
		wndPrevChecked:FindChild("TypeTierItemBtn"):SetCheck(true)
		self:DrawCreateRuneContents(wndPrevChecked)
	else
		local wndFirst = wndCreateARuneParent:GetChildren()[1]
		if wndFirst then
			wndFirst:FindChild("TypeTierItemBtn"):SetCheck(true)
			self:DrawCreateRuneContents(wndFirst)
		end
	end

	self:ResizeCreateRunes()
end

function Runecrafting:DrawCreateRuneContents(wndParent)
	local tRuneList = wndParent:GetData()

	for idx2, tPackedData in pairs(tRuneList) do
		local tCurrSchematic = tPackedData.tCurrSchematic
		local tSchematicInfo = tPackedData.tSchematicInfo

		-- Check Materials
		local bHasMaterials = true
		for idx2, tMaterialData in pairs(tSchematicInfo.tMaterials) do
			if tMaterialData.nAmount > (tMaterialData.itemMaterial:GetBackpackCount() + tMaterialData.itemMaterial:GetBankCount()) then
				bHasMaterials = false
				break
			end
		end

		-- Formatting
		local wndCurr = self:LoadByName("NewRuneItem", wndParent:FindChild("TypeTierItemContainer"), "NewRuneItem"..tCurrSchematic.nSchematicId)
		wndCurr:FindChild("NewRuneMoreInfoBtn"):SetData(tSchematicInfo)
		wndCurr:FindChild("NewRuneMoreInfoName"):SetData(bHasMaterials)
		wndCurr:FindChild("NewRuneMoreInfoName"):SetText(tCurrSchematic.strName)
		wndCurr:FindChild("NewRuneMoreInfoName"):SetTextColor(bHasMaterials and "UI_BtnTextBlueNormal" or "xkcdReddish")
		wndCurr:FindChild("NewRuneMoreInfoIcon"):SetSprite(bHasMaterials and "sprRunecrafting_BulletPoint_Green" or "sprRunecrafting_BulletPoint_Red")
		Tooltip.GetItemTooltipForm(self, wndCurr, tSchematicInfo.itemOutput, {bSelling = false})
	end
end

function Runecrafting:OnTypeTierItemCheck(wndHandler, wndControl)
	local wndParent = wndHandler:GetData()
	self:DrawCreateRuneContents(wndParent)
	self:ResizeCreateRunes()
end

function Runecrafting:OnTypeTierItemUncheck(wndHandler, wndControl)
	local wndParent = wndHandler:GetData()
	wndParent:FindChild("TypeTierItemContainer"):DestroyChildren()
	self:ResizeCreateRunes()
end

function Runecrafting:ResizeCreateRunes()
	local function SortTypeTierItemContainer(a,b)
		if not a or not b or not a:FindChild("NewRuneMoreInfoName") or not b:FindChild("NewRuneMoreInfoName") then return true end
		return a:FindChild("NewRuneMoreInfoName"):GetText() < b:FindChild("NewRuneMoreInfoName"):GetText()
	end

	for idx, wndCurr in pairs(self.wndMain:FindChild("RuneCreationItemList"):GetChildren()) do
		local nHeight = 0
		if wndCurr:FindChild("TypeTierItemBtn"):IsChecked() then
			nHeight = wndCurr:FindChild("TypeTierItemContainer"):ArrangeChildrenVert(0, SortTypeTierItemContainer)
		else
			nHeight = wndCurr:FindChild("TypeTierItemContainer"):ArrangeChildrenVert(0)
		end

		local nExtra = wndCurr:FindChild("TypeTierItemBtn"):IsChecked() and 3 or 0
		local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
		wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + nExtra + self.knDefaultTypeTierItemHeight)
	end
	self.wndMain:FindChild("RuneCreationItemList"):ArrangeChildrenVert(0, function(a,b) return a:GetName() < b:GetName() end)
end

-----------------------------------------------------------------------------------------------
-- Rune Creation Items
-----------------------------------------------------------------------------------------------

function Runecrafting:OnUpdateInventory()
	self:HelperRefreshBottomMaterials()
	self:RedrawAll()
end

function Runecrafting:HelperRefreshBottomMaterials()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndParent = self.wndMain:FindChild("RuneCreationContainer"):FindChild("RuneCreationBottom")
	local tSchematicInfo = wndParent:GetData()
	if not tSchematicInfo then
		return
	end

	local bCanMake = true
	for idx2, tData in pairs(tSchematicInfo.tMaterials) do
		local itemMaterial = tData.itemMaterial
		local nOwnedCount = itemMaterial:GetBackpackCount() + itemMaterial:GetBankCount()
		local bNotEnough = nOwnedCount < tData.nAmount
		local wndMaterial = self:LoadByName("RawMaterialsItem", wndParent:FindChild("RuneCreationMaterialsList"), "RawMaterialsItem"..itemMaterial:GetName())
		wndMaterial:FindChild("RawMaterialsIcon"):SetSprite(itemMaterial:GetIcon())
		wndMaterial:FindChild("RawMaterialsIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), nOwnedCount, tData.nAmount))
		wndMaterial:FindChild("RawMaterialsNotEnough"):Show(bNotEnough)
		Tooltip.GetItemTooltipForm(self, wndMaterial, itemMaterial, {bSelling = false})

		if bNotEnough then
			bCanMake = false
			wndParent:FindChild("RuneCreationCraftBtn"):Enable(false)
		end
	end
	wndParent:FindChild("RuneCreationMaterialsList"):ArrangeChildrenHorz(0)
	wndParent:FindChild("RuneCreationChatBtn"):SetData({ tSchematicInfo = tSchematicInfo, bCanMake = bCanMake })
end

function Runecrafting:OnRuneCreationChatBtn(wndHandler, wndControl)
	local bCanMake = wndHandler:GetData().bCanMake
	local tSchematicInfo = wndHandler:GetData().tSchematicInfo

	local strResult = ""
	if bCanMake then
		for idx, tMaterialData in pairs(tSchematicInfo.tMaterials) do
			local nTotal = tMaterialData.itemMaterial:GetBackpackCount() + tMaterialData.itemMaterial:GetBankCount()
			strResult = strResult .. String_GetWeaselString(Apollo.GetString("Runecrafting_NOutOfNName"),  nTotal, tMaterialData.nAmount, tMaterialData.itemMaterial:GetName())
		end
	else
		for idx, tMaterialData in pairs(tSchematicInfo.tMaterials) do
			local nTotal = tMaterialData.itemMaterial:GetBackpackCount() + tMaterialData.itemMaterial:GetBankCount()
			if nTotal < tMaterialData.nAmount then
				strResult = strResult .. String_GetWeaselString(Apollo.GetString("Runecrafting_NMaterials"), tMaterialData.nAmount, tMaterialData.itemMaterial:GetName())
			end
		end
	end
	strResult = String_GetWeaselString(Apollo.GetString("Runecrafting_MaterialsOutput"), tSchematicInfo.itemOutput:GetName(), string.sub(strResult, 0, #strResult - 2))
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", strResult)
end

function Runecrafting:OnNewRuneMoreInfoCheck(wndHandler, wndControl) -- NewRuneMoreInfoBtn, data is tSchematicInfo
	if wndHandler ~= wndControl then
		return
	end

	wndHandler:FindChild("NewRuneMoreInfoName"):SetTextColor(ApolloColor.new("UI_BtnTextBluePressed"))

	local tSchematicInfo = wndHandler:GetData()
	local wndParent = self.wndMain:FindChild("RuneCreationContainer"):FindChild("RuneCreationBottom")
	wndParent:FindChild("RuneCreationMaterialsList"):DestroyChildren()
	wndParent:FindChild("RuneCreationCraftBtn"):SetData(tSchematicInfo)
	wndParent:FindChild("RuneCreationCraftBtn"):Enable(true)
	wndParent:FindChild("RuneCreationName"):SetText(tSchematicInfo.strName)
	wndParent:FindChild("RuneCreationMaterialsContainer"):Show(true)
	wndParent:SetData(tSchematicInfo)

	self:HelperRefreshBottomMaterials()
end

function Runecrafting:OnNewRuneMoreInfoUncheck(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	wndHandler:FindChild("NewRuneMoreInfoName"):SetTextColor(wndHandler:FindChild("NewRuneMoreInfoName"):GetData() and "UI_BtnTextBlueNormal" or "xkcdReddish")
	self:ResetRuneCreationBottom()
end

function Runecrafting:ResetRuneCreationBottom()
	local wndParent = self.wndMain:FindChild("RuneCreationContainer"):FindChild("RuneCreationBottom")
	wndParent:FindChild("RuneCreationMaterialsList"):DestroyChildren()
	wndParent:FindChild("RuneCreationMaterialsContainer"):Show(false)
	wndParent:FindChild("RuneCreationCraftBtn"):Enable(false)
	wndParent:FindChild("RuneCreationName"):SetText("")
	wndParent:SetData(nil)
end

function Runecrafting:OnRuneCreationCraftBtn(wndHandler, wndControl) -- RuneCreationCraftBtn
	local tSchematicInfo = wndHandler:GetData()

	-- Order is important, must clear first
	Event_FireGenericEvent("GenericEvent_ClearCraftSummary")

	-- Build summary screen list
	local strSummaryMsg = Apollo.GetString("CoordCrafting_LastCraftTooltip")
	for idx, tData in pairs(tSchematicInfo.tMaterials) do
		local itemCurr = tData.itemMaterial
		local tPluralName =
		{
			["name"] = itemCurr:GetName(),
			["count"] = tonumber(tData.nAmount)
		}
		strSummaryMsg = strSummaryMsg .. "\n" .. String_GetWeaselString(Apollo.GetString("CoordCrafting_SummaryCount"), tPluralName)
	end
	Event_FireGenericEvent("GenericEvent_CraftSummaryMsg", strSummaryMsg)

	-- Craft
	CraftingLib.CraftItem(tSchematicInfo.nSchematicId)

	-- Post Craft Effects
	Event_FireGenericEvent("GenericEvent_StartCraftCastBar", self.tWindowMap["CraftingSummaryContainer"], tSchematicInfo.itemOutput)
	self.tWindowMap["PostCraftBlocker"]:Show(true)
end

function Runecrafting:OnCloseSummary()
	if self.tWindowMap and self.tWindowMap["PostCraftBlocker"] and self.tWindowMap["PostCraftBlocker"]:IsValid() then
		self.tWindowMap["PostCraftBlocker"]:Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Equipment
-----------------------------------------------------------------------------------------------

function Runecrafting:NewEquipmentItem(itemSource, wndParent, bEquipped)
	local wndItem = Apollo.LoadForm(self.xmlDoc, "EquipmentItem", wndParent, self)
	wndItem:FindChild("EquipmentItemCantUseIcon"):Show(self:HelperPrereqFailed(itemSource))
	wndItem:FindChild("EquipmentItemName"):SetText(itemSource:GetName())
	wndItem:FindChild("EquipmentItemIcon"):SetSprite(itemSource:GetIcon())
	wndItem:FindChild("EquipmentItemEquippedBrackets"):Show(bEquipped)

	if bEquipped then
		Tooltip.GetItemTooltipForm(self, wndItem:FindChild("EquipmentItemIcon"), itemSource, { bPrimary = true, bSelling = false })
	else
		local itemEquipped = itemSource and itemSource:GetEquippedItemForItemType() or nil
		Tooltip.GetItemTooltipForm(self, wndItem:FindChild("EquipmentItemIcon"), itemSource, { bPrimary = true, bSelling = false, itemCompare = itemEquipped })
	end

	-- Runes if valid
	wndItem:FindChild("EquipmentItemRuneSlotContainer"):DestroyChildren()
	local tRuneData = itemSource:GetRuneSlots()
	if not tRuneData or not tRuneData.bIsDefined then
		return
	end

	-- Existing Runes
	local bFirstLockedSlot = true
	local tEngravingInfo = CraftingLib.GetEngravingInfo(itemSource)
	local tRerollInfo = tEngravingInfo.tRerollInfo

	for nSlotIndex, tCurrRuneSlot in pairs(tRuneData.arRuneSlots) do
		local tRuneslotItemData = Item.GetDataFromId(tCurrRuneSlot.idRune)
		local wndRuneSlot = self:LoadByName(tCurrRuneSlot.bUnlocked and "RuneSlotItem" or "RuneSlotLockedItem", wndItem:FindChild("EquipmentItemRuneSlotContainer"), "RuneSlotItem"..nSlotIndex)
		wndRuneSlot:FindChild("RuneSlotBtn"):SetData({ nSlotIndex, tCurrRuneSlot, itemSource })
		wndRuneSlot:FindChild("RuneSlotType"):SetSprite(karElementsToSprite[tCurrRuneSlot.eType][tRuneslotItemData and "strBright" or "strFade"])

		if wndRuneSlot:FindChild("RuneSlotFakeLockIcon") then
			wndRuneSlot:FindChild("RuneSlotFakeLockIcon"):Show(not tCurrRuneSlot.bUnlocked)
		end

		-- This is how "strong" a socket is. Current design has this diminish the more slots there are (so an 8 slot drop isn't significantly better than a 7 slot drop)
		local tDetailedInfo = itemSource:GetDetailedInfo()
		if tDetailedInfo and tDetailedInfo.tPrimary.tRunes then
			local tRelevantSlotBudgetData = tDetailedInfo.tPrimary.tRunes.arRuneSlots[nSlotIndex]
			wndRuneSlot:FindChild("RuneSlotEfficiency"):SetText(math.floor(tRelevantSlotBudgetData.nPercent * 100).."%")
			wndRuneSlot:FindChild("RuneSlotEfficiency"):SetTextColor((tCurrRuneSlot.bUnlocked or bFirstLockedSlot) and "UI_TextMetalGoldHighlight" or "UI_TextMetalBody")
		end

		-- Reroll indicator
		local bOmniSlot = tCurrRuneSlot.eType == Item.CodeEnumRuneType.Omni
		local nReagentCost = (tRerollInfo and tRerollInfo.arCosts[nSlotIndex]) and tRerollInfo.arCosts[nSlotIndex].nReagents or 0
		if wndRuneSlot:FindChild("RuneSlotRerollAllowed") then
			wndRuneSlot:FindChild("RuneSlotRerollAllowed"):Show(nReagentCost > 0 and not bOmniSlot)
		end

		-- Different formatting and text for different button states
		if tRuneslotItemData then
			self:HelperBuildItemTooltip(wndRuneSlot, tRuneslotItemData)
		elseif tCurrRuneSlot.bUnlocked and bOmniSlot then
			wndRuneSlot:SetTooltip(Apollo.GetString("EngravingStation_OmniSlotAnyRune"))
		elseif tCurrRuneSlot.bUnlocked and nReagentCost > 0 then
			wndRuneSlot:SetTooltip(String_GetWeaselString(Apollo.GetString("EngravingStation_AvailableOrRerollSlot"), tCurrRuneSlot.strName))
		elseif tCurrRuneSlot.bUnlocked then
			wndRuneSlot:SetTooltip(String_GetWeaselString(Apollo.GetString("EngravingStation_AvailableSlot"), tCurrRuneSlot.strName))
		elseif bFirstLockedSlot then
			bFirstLockedSlot = false
			wndRuneSlot:SetTooltip(String_GetWeaselString(Apollo.GetString("EngravingStation_LockedSlot"), tCurrRuneSlot.strName))
		else
			wndRuneSlot:FindChild("RuneSlotBtn"):Enable(false)
			wndRuneSlot:SetTooltip(Apollo.GetString("EngravingStation_LockedChildSlot"))
		end
	end

	-- Append Rune
	local tAddData = tEngravingInfo.tAddInfo
	if tAddData then
		local wndAppend = self:LoadByName("RuneSlotAppendItem", wndItem:FindChild("EquipmentItemRuneSlotContainer"), "RuneSlotAppendItem") -- Add one at a time
		wndAppend:SetTooltip(String_GetWeaselString(Apollo.GetString("EngravingStation_AddSlotTooltip"), tAddData.nMaximumSigils))
		wndAppend:FindChild("RuneSlotAppendBtn"):SetData({ tAddData = tAddData, itemSource = itemSource })
	end

	wndItem:FindChild("EquipmentItemRuneSlotContainer"):ArrangeChildrenHorz(0)
end

function Runecrafting:OnAppendConfirmYes(wndHandler, wndControl)
	local itemSource = wndHandler:GetData()
	CraftingLib.AddRuneSlot(itemSource)
	self:OnCurrentConfirmPopupClose()
end

function Runecrafting:OnRerollConfirmYes(wndHandler, wndControl)
	local nSlotIndex = wndHandler:GetData()[1]
	local itemSource = wndHandler:GetData()[3] -- Data is passed along, origates from RuneSlotBtn and is { nSlotIndex, tCurrRuneSlot, itemSource }

	-- Update UIs
	self.tWindowMap["RerollItemTitle"]:SetText(Apollo.GetString("EngravingStation_RuneSlotRerollTitle"))
	self:OnCurrentConfirmPopupClose()
	self:HelperPostRerollTransition(self.tWindowMap["RerollInitCastBarBG"])
	Apollo.StartTimer("Runecrafting_RerollDelay")
end

function Runecrafting:OnRerollElementPickedBtn(wndHandler, wndControl) -- From RerollElementLeftBtn or RerollElementRightBtn
	self:HelperPostRerollTransition(self.tWindowMap["RerollDoneCastBarBG"])
end

function Runecrafting:OnRerollElementAbandonBtn(wndHandler, wndControl)
	self:HelperPostRerollTransition(self.tWindowMap["RerollDoneCastBarBG"])
end

function Runecrafting:HelperPostRerollTransition(wndCastBar)
	self.tWindowMap["RerollBlockerHoloBG"]:Show(false)
	self.tWindowMap["RerollBlocker"]:Show(true, true)
	wndCastBar:Show(true)
end

function Runecrafting:OnUnlockConfirmYes(wndHandler, wndControl)
	local nSlotIndex = wndHandler:GetData()[1]
	local itemSource = wndHandler:GetData()[3] -- Data is passed along, origates from RuneSlotBtn and is { nSlotIndex, tCurrRuneSlot, itemSource }
	CraftingLib.UnlockRuneSlot(itemSource, nSlotIndex)
	self:OnCurrentConfirmPopupClose()
end

function Runecrafting:OnClearConfirmYes(wndHandler, wndControl)
	local nSlotIndex = wndHandler:GetData()[1]
	local itemSource = wndHandler:GetData()[3] -- Data is passed along, origates from RuneSlotBtn and is { nSlotIndex, tCurrRuneSlot, itemSource }
	CraftingLib.ClearRuneSlot(itemSource, nSlotIndex)
	self:OnCurrentConfirmPopupClose()
end

-----------------------------------------------------------------------------------------------
-- wndCurrentConfirmPopup
-----------------------------------------------------------------------------------------------

function Runecrafting:OnRuneSlotBtn(wndHandler, wndControl) -- RuneSlotBtn of RuneSlotLockedItem
	if not self.bAllowClicks then
		return
	end

	local nSlotIndex = wndHandler:GetData()[1]
	local tCurrRuneSlot = wndHandler:GetData()[2]
	local itemSource = wndHandler:GetData()[3]
	local tEngravingInfo = CraftingLib.GetEngravingInfo(itemSource)
	local tRerollInfo = tEngravingInfo.tRerollInfo
	local tClearInfo = tEngravingInfo.tClearInfo

	self:OnCurrentConfirmPopupClose()

	if self.itemDragging and self.itemDragging:GetRuneInfo().eType ~= tCurrRuneSlot.eType then
		return Apollo.DragDropQueryResult.Accept -- HACK
	end

	if tCurrRuneSlot.idRune == 0 then
		local unitPlayer = GameLib.GetPlayerUnit()
		local nPlayerLevel = unitPlayer:GetLevel()
		local eClassId =  unitPlayer:GetClassId()

		-- Reroll possible?
		local nReagentCost = (tRerollInfo and tRerollInfo.arCosts[nSlotIndex]) and tRerollInfo.arCosts[nSlotIndex].nReagents or 0
		local bRerollPossible = tCurrRuneSlot.eType ~= Item.CodeEnumRuneType.Omni and nReagentCost > 0
		local strAddPickerText = bRerollPossible and Apollo.GetString("EngravingStation_AddRerollPicker") or Apollo.GetString("EngravingStation_AddPickerLabel")

		-- Build form
		self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "AddPicker", self.wndMain, self)
		self.wndCurrentConfirmPopup:FindChild("AddPickerText"):SetText(strAddPickerText)

		for idx, itemRune in pairs(CraftingLib.GetValidRuneItems(itemSource, nSlotIndex)) do
			local tItemRuneInfo = itemRune:GetRuneInfo()
			if self:HelperCheckElementMatch(tItemRuneInfo, tCurrRuneSlot) then
				local wndRune = self:LoadByName("RunePickerItem", self.wndCurrentConfirmPopup:FindChild("AddPickerList"), "AddPickerList"..idx..itemRune:GetName())
				wndRune:FindChild("RunePickerItemBtn"):SetData({ wndHandler = wndHandler, itemSource = itemSource, itemRune = itemRune, nSlotIndex = nSlotIndex, bReroll = false })
				wndRune:FindChild("RunePickerItemText"):SetText(itemRune:GetName())
				wndRune:FindChild("RunePickerItemIcon"):SetSprite(itemRune:GetIcon())
				wndRune:FindChild("RunePickerItemIcon"):SetText(itemRune:GetBackpackCount() + itemRune:GetBankCount())
				self:HelperBuildItemTooltip(wndRune:FindChild("RunePickerItemIcon"), itemRune)

				-- Check validity of rune
				local tRequiredClass = itemRune:GetRequiredClass()
				local tItemEffectData = itemSource:GetGlyphBonus(itemRune, nSlotIndex)
				local bMatchingClass = false
				for idx, result in pairs(tRequiredClass) do -- As of now only going to have one result in this table, but if runes will have more than one class option
					if result.idClassReq == eClassId then
						bMatchingClass = true
						break
					end
				end

				local bFailed = false
				local strErrorMessage =  ""
				if #tRequiredClass > 0 and not bMatchingClass then
					strErrorMessage = Apollo.GetString("PrerequisiteComp_Class")
					bFailed = true
				elseif nPlayerLevel < itemRune:GetRequiredLevel() then
					strErrorMessage = Apollo.GetString("PrerequisiteComp_Level")
					bFailed = true
				elseif not tItemEffectData.nValue then -- Catch all
					strErrorMessage = Apollo.GetString("Runecrafting_NoDuplicateRunes")
					bFailed = true
				end

				if bFailed then
					wndRune:FindChild("RunePickerItemText"):SetTextColor(ApolloColor.new("ffda2a00"))
					wndRune:FindChild("RunePickerItemText"):SetTooltip(strErrorMessage)
				end

				wndRune:FindChild("RunePickerItemDisabled"):Show(bFailed)
				wndRune:FindChild("RunePickerItemBtn"):Enable(not bFailed)
			end
		end

		if bRerollPossible then
			local nReagentCost = tRerollInfo.arCosts[nSlotIndex] and tRerollInfo.arCosts[nSlotIndex].nReagents or 0 -- Currently hardcoded to only have one Reagent cost
			local wndReroll = self:LoadByName("RunePickerItem", self.wndCurrentConfirmPopup:FindChild("AddPickerList"), "Reroll")
			wndReroll:FindChild("RunePickerItemBtn"):SetData({ wndHandler = wndHandler, itemSource = itemSource, nSlotIndex = nSlotIndex, bReroll = true })
			wndReroll:FindChild("RunePickerItemText"):SetText(Apollo.GetString("EngravingStation_ClickToReroll"))
			wndReroll:FindChild("RunePickerItemIcon"):SetSprite(tRerollInfo.itemReagent:GetIcon())
			wndReroll:FindChild("RunePickerItemIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), tRerollInfo.nReagentCount, nReagentCost))
			wndReroll:FindChild("RunePickerItemIcon"):SetTextColor(tRerollInfo.nReagentCount >= nReagentCost and "white" or "xkcdReddish")
			self:HelperBuildItemTooltip(wndReroll:FindChild("RunePickerItemIcon"), tRerollInfo.itemReagent)
		end

		local bHasItems = #self.wndCurrentConfirmPopup:FindChild("AddPickerList"):GetChildren() > 0
		self.wndCurrentConfirmPopup:FindChild("AddPickerList"):ArrangeChildrenVert(0, function(a,b) return not b:FindChild("RunePickerItemBtn"):IsEnabled() end)
		self.wndCurrentConfirmPopup:FindChild("AddPickerList"):SetText(bHasItems and "" or Apollo.GetString("EngravingStation_NoRunesFound"))
	else
		local tCurrentCosts = tClearInfo.arCosts[nSlotIndex]
		self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "ClearConfirm", self.wndMain, self)
		self.wndCurrentConfirmPopup:FindChild("ClearConfirmYes"):SetData(wndHandler:GetData())
		self.wndCurrentConfirmPopup:FindChild("ClearCashWindow"):SetAmount(tCurrentCosts and tCurrentCosts.nReagents or 0)
	end
	self:HelperRepositionConfirmPopup(wndHandler)

	return Apollo.DragDropQueryResult.Accept -- HACK
end

function Runecrafting:OnRuneSlotAppendBtn(wndHandler, wndControl) -- RuneSlotAppendBtn of RuneSlotAppendItem
	if not self.bAllowClicks then
		return
	end

	local tAddData = wndHandler:GetData().tAddData
	local itemSource = wndHandler:GetData().itemSource
	local itemReagent = tAddData.itemReagent

	self:OnCurrentConfirmPopupClose()
	self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "AppendConfirm", self.wndMain, self)
	self.wndCurrentConfirmPopup:FindChild("AppendConfirmYes"):SetData(itemSource)
	self.wndCurrentConfirmPopup:FindChild("AppendConfirmYes"):Enable(tAddData.nReagentCount >= tAddData.tCost.nReagents)
	self.wndCurrentConfirmPopup:FindChild("AppendMaterialIcon"):SetSprite(itemReagent:GetIcon())
	self.wndCurrentConfirmPopup:FindChild("AppendMaterialIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), tAddData.nReagentCount, tAddData.tCost.nReagents))
	self.wndCurrentConfirmPopup:FindChild("AppendMaterialIcon"):SetTextColor(tAddData.nReagentCount >= tAddData.tCost.nReagents and "white" or "xkcdReddish")
	self.wndCurrentConfirmPopup:FindChild("SoulboundWarning"):Show(not itemSource:IsSoulbound())
	self:HelperBuildItemTooltip(self.wndCurrentConfirmPopup:FindChild("AppendMaterialIcon"), itemReagent)
	self:HelperRepositionConfirmPopup(wndHandler)
end

function Runecrafting:OnRuneSlotLockedBtn(wndHandler, wndControl) -- RuneSlotBtn of RuneSlotLockedItem
	if not self.bAllowClicks then
		return
	end

	local nSlotIndex = wndHandler:GetData()[1]
	local itemSource = wndHandler:GetData()[3]
	local tEngravingInfo = CraftingLib.GetEngravingInfo(itemSource)
	local tCurrentCosts = tEngravingInfo.tUnlockInfo.tCost

	self:OnCurrentConfirmPopupClose()
	self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "UnlockConfirm", self.wndMain, self)
	self.wndCurrentConfirmPopup:FindChild("UnlockConfirmYes"):SetData(wndHandler:GetData())
	self.wndCurrentConfirmPopup:FindChild("UnlockCashWindow"):SetAmount(tCurrentCosts and tCurrentCosts.monCost or 0)
	self.wndCurrentConfirmPopup:FindChild("SoulboundWarning"):Show(not itemSource:IsSoulbound())
	self:HelperRepositionConfirmPopup(wndHandler)
end

function Runecrafting:OnRunePickerItemBtn(wndHandler, wndControl)
	local tData = wndHandler:GetData()
	if tData.bReroll then
		self:DrawRuneRerollConfirm(tData.wndHandler, tData.itemSource, tData.nSlotIndex)
	else
		self:DrawAddRuneConfirm(tData.wndHandler, tData.itemSource, tData.nSlotIndex, tData.itemRune)
	end
end

function Runecrafting:DrawRuneRerollConfirm(wndHandler, itemSource, nSlotIndex)
	if not self.bAllowClicks then
		return
	end

	local tEngravingInfo = CraftingLib.GetEngravingInfo(itemSource)
	local tRerollInfo = tEngravingInfo.tRerollInfo
	local nReagentCost = tRerollInfo.arCosts[nSlotIndex] and tRerollInfo.arCosts[nSlotIndex].nReagents or 0 -- Currently hardcoded to only have one Reagent cost

	local bHaveMats = tRerollInfo.nReagentCount >= nReagentCost
	self:OnCurrentConfirmPopupClose()
	self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "RerollConfirm", self.wndMain, self)
	self.wndCurrentConfirmPopup:FindChild("RerollConfirmYes"):SetData(wndHandler:GetData())
	self.wndCurrentConfirmPopup:FindChild("RerollConfirmYes"):Enable(bHaveMats)
	if bHaveMats then
		self.wndCurrentConfirmPopup:FindChild("RerollConfirmYes"):SetActionData(GameLib.CodeEnumConfirmButtonType.RuneSlotReroll, itemSource, nSlotIndex)
	end
	self.wndCurrentConfirmPopup:FindChild("SoulboundWarning"):Show(not itemSource:IsSoulbound())
	self.wndCurrentConfirmPopup:FindChild("RerollMaterialIcon"):SetSprite(tRerollInfo.itemReagent:GetIcon())
	self.wndCurrentConfirmPopup:FindChild("RerollMaterialIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), tRerollInfo.nReagentCount, nReagentCost))
	self.wndCurrentConfirmPopup:FindChild("RerollMaterialIcon"):SetTextColor(bHaveMats and "white" or "xkcdReddish")
	self:HelperBuildItemTooltip(self.wndCurrentConfirmPopup:FindChild("RerollMaterialIcon"), tRerollInfo.itemReagent)
	self:HelperRepositionConfirmPopup(wndHandler)
end

function Runecrafting:DrawAddRuneConfirm(wndHandler, itemSource, nSlotIndex, itemRune)
	self:OnCurrentConfirmPopupClose()

	-- What the rune will add to the item, if successful
	local tItemEffectData = itemSource:GetGlyphBonus(itemRune, nSlotIndex)
	local strItemEffect = String_GetWeaselString(Apollo.GetString("EngravingStation_EffectIfSuccessful"), tItemEffectData.nValue or 0, ktAttributeToText[tItemEffectData.eProperty])

	-- Draw Window
	self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "AddConfirm", self.wndMain, self)
	self.wndCurrentConfirmPopup:FindChild("AddConfirmYes"):SetData({ nSlotIndex, itemRune, itemSource }) -- GOTCHA: Different 2nd argument than normal
	self.wndCurrentConfirmPopup:FindChild("AddConfirmItemEffect"):SetText(strItemEffect)
	self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"):SetSprite(itemRune:GetIcon())
	self.wndCurrentConfirmPopup:FindChild("SoulboundWarning"):Show(not itemSource:IsSoulbound())
	self:HelperBuildItemTooltip(self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"), itemRune)
	self:HelperRepositionConfirmPopup(wndHandler)
end

function Runecrafting:DrawRuneReplaceConfirm(wndHandler, itemRune)
	local nSlotIndex = wndHandler:FindChild("RuneSlotBtn"):GetData()[1]
	local itemSource = wndHandler:FindChild("RuneSlotBtn"):GetData()[3]
	local tEngravingInfo = CraftingLib.GetEngravingInfo(itemSource)
	local tCurrentCosts = tEngravingInfo.tClearInfo.arCosts[nSlotIndex]
	self:OnCurrentConfirmPopupClose()

	-- Draw Window
	self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "ReplaceConfirm", self.wndMain, self)
	self.wndCurrentConfirmPopup:FindChild("AddConfirmYes"):SetData({ nSlotIndex, itemRune, itemSource }) -- GOTCHA: Different 2nd argument than normal
	self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"):SetSprite(itemRune:GetIcon())
	self.wndCurrentConfirmPopup:FindChild("ReplaceCashWindow"):SetAmount(tCurrentCosts and tCurrentCosts.nReagents or 0)
	self:HelperBuildItemTooltip(self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"), itemRune)
	self:HelperRepositionConfirmPopup(wndHandler)
end

function Runecrafting:OnCurrentConfirmPopupClose(wndHandler, wndControl)
	if self.wndCurrentConfirmPopup and self.wndCurrentConfirmPopup:IsValid() then
		self.wndCurrentConfirmPopup:Destroy()
		self.wndCurrentConfirmPopup = nil
		Apollo.StartTimer("Runecrafting_ConfirmPopupDelay")
		self.bAllowClicks = false
	end
end

function Runecrafting:OnRunecrafting_ConfirmPopupDelay()
	self.bAllowClicks = true
end

function Runecrafting:HelperRepositionConfirmPopup(wndOrigin)
	local wndIter = wndOrigin
	local wndExit = wndOrigin:GetFrame()
	local nTotalX, nTotalY = 0, 0

	for idx = 1, 99 do
		if not wndIter or wndIter == wndExit then
			break
		end

		local x, y = wndIter:GetPos()
		nTotalX = nTotalX + x
		nTotalY = nTotalY + y
		wndIter = wndIter:GetParent()
	end

	local wndPopup = self.wndCurrentConfirmPopup
	local nLeft, nTop, nRight, nBottom = wndPopup:GetAnchorOffsets()
	wndPopup:SetAnchorOffsets(nTotalX + nLeft, nTotalY + nTop, nTotalX + nRight, nTotalY + nBottom)
	wndPopup:ToFront()
end

-----------------------------------------------------------------------------------------------
-- Drag Drop Events
-----------------------------------------------------------------------------------------------

function Runecrafting:OnRuneSlotQueryDragDrop(wndHandler, wndControl, x, y, wndSource, strType, nDragInventoryItemIdx, eResult)
	local itemSource = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx)
	if itemSource and strType == "DDBagItem" then
		local tCurrRuneSlot = wndHandler:GetData()[2]
		local tItemRuneInfo = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx):GetRuneInfo()
		if tCurrRuneSlot.eType and tItemRuneInfo then
			return Apollo.DragDropQueryResult.Accept
		end
	end
	return Apollo.DragDropQueryResult.Ignore
end

function Runecrafting:OnRuneSlotDragDrop(wndHandler, wndControl, x, y, wndSource, strType, nDragInventoryItemIdx, bDragDropHasBeenReset)
	local itemSource = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx)
	if itemSource and strType == "DDBagItem" then
		local tCurrRuneSlot = wndHandler:GetData()[2]
		local tItemRuneInfo = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx):GetRuneInfo()
		if self:HelperCheckElementMatch(tItemRuneInfo, tCurrRuneSlot) then
			if tCurrRuneSlot.idRune == 0 then -- No rune in slot
				self:DrawAddRuneConfirm(wndHandler:GetParent(), self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx))
			else -- Replace rune in slot
				self:DrawRuneReplaceConfirm(wndHandler:GetParent(), self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx))
			end
		end
		return false
	end
	return true
end

function Runecrafting:OnAddConfirmYes(wndHandler, wndControl) -- Potentially from drag drop or from picker
	local nSlotIndex = wndHandler:GetData()[1]
	local itemRune = wndHandler:GetData()[2] -- GOTCHA: This is an item object, not the normal table of data
	local itemSource = wndHandler:GetData()[3]

	local tRuneData = itemSource:GetRuneSlots()
	if tRuneData and tRuneData.bIsDefined then
		local tListOfRunes = {}
		for idx, tCurrRuneSlot in pairs(tRuneData.arRuneSlots) do
			if tCurrRuneSlot.bUnlocked then
				tListOfRunes[idx] = tCurrRuneSlot.idRune
			end
		end
		tListOfRunes[nSlotIndex] = itemRune:GetItemId() -- Replace with the desired
		CraftingLib.InstallRuneIntoSlot(itemSource, tListOfRunes)
	end
	self:OnCurrentConfirmPopupClose()
end

function Runecrafting:OnReplaceConfirmYes( wndHandler, wndControl, eMouseButton )
	local nSlotIndex = wndHandler:GetData()[1]
	local itemRune = wndHandler:GetData()[2] -- GOTCHA: This is an item object, not the normal table of data
	local itemSource = wndHandler:GetData()[3]

	local tRuneData = itemSource:GetRuneSlots()
	if tRuneData and tRuneData.bIsDefined then
		local tListOfRunes = {}
		for idx, tCurrRuneSlot in pairs(tRuneData.arRuneSlots) do
			if tCurrRuneSlot.bUnlocked then
				tListOfRunes[idx] = tCurrRuneSlot.idRune
			end
		end
		tListOfRunes[nSlotIndex] = itemRune:GetItemId() -- Replace with the desired
		CraftingLib.ClearRuneSlot(itemSource, nSlotIndex)
		CraftingLib.InstallRuneIntoSlot(itemSource, tListOfRunes)
	end

	self:OnCurrentConfirmPopupClose()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function Runecrafting:HelperCheckElementMatch(tItemRuneInfo, tRuneSlot)
	return tRuneSlot.eType == Item.CodeEnumRuneType.Omni or tItemRuneInfo.eType == Item.CodeEnumRuneType.Omni or tItemRuneInfo.eType == tRuneSlot.eType
end

function Runecrafting:HelperPrereqFailed(tCurrItem)
	return tCurrItem and tCurrItem:IsEquippable() and not tCurrItem:CanEquip()
end

function Runecrafting:HelperBuildItemTooltip(wndArg, itemCurr)
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, { bPrimary = true, bSelling = false, itemCompare = itemCurr:GetEquippedItemForItemType() })
end

function Runecrafting:LoadByName(strForm, wndParent, strCustomName)
	local wndNew = wndParent:FindChild(strCustomName)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strForm, wndParent, self)
		wndNew:SetName(strCustomName)
	end
	return wndNew
end

local RunecraftingInst = Runecrafting:new()
RunecraftingInst:Init()
