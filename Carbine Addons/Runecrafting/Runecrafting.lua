-----------------------------------------------------------------------------------------------
-- Client Lua Script for Runecrafting
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CraftingLib"
require "GameLib"
require "Item"
local knLevelRequirement = 15

local karSigilElementsToSprite =
{
	[Item.CodeEnumSigilType.Air]		= { strName = Apollo.GetString("CRB_Air"),		strBright = "sprRunecrafting_Air",		strFade = "sprRunecrafting_AirFade" },
	[Item.CodeEnumSigilType.Fire]		= { strName = Apollo.GetString("CRB_Fire"),		strBright = "sprRunecrafting_Fire",		strFade = "sprRunecrafting_FireFade" },
	[Item.CodeEnumSigilType.Water]		= { strName = Apollo.GetString("CRB_Water"),	strBright = "sprRunecrafting_Water",	strFade = "sprRunecrafting_WaterFade" },
	[Item.CodeEnumSigilType.Earth]		= { strName = Apollo.GetString("CRB_Earth"),	strBright = "sprRunecrafting_Earth",	strFade = "sprRunecrafting_EarthFade" },
	[Item.CodeEnumSigilType.Logic]		= { strName = Apollo.GetString("CRB_Logic"),	strBright = "sprRunecrafting_Logic",	strFade = "sprRunecrafting_LogicFade" },
	[Item.CodeEnumSigilType.Life]		= { strName = Apollo.GetString("CRB_Life"),		strBright = "sprRunecrafting_Life",		strFade = "sprRunecrafting_LifeFade" },
	[Item.CodeEnumSigilType.Fusion]		= { strName = Apollo.GetString("CRB_Fusion"),	strBright = "sprRunecrafting_Fusion",	strFade = "sprRunecrafting_FusionFade" },
	[Item.CodeEnumSigilType.Omni]		= { strName = Apollo.GetString("CRB_Omni"),		strBright = "sprRunecrafting_Omni",		strFade = "sprRunecrafting_OmniFade" },
	--[Item.CodeEnumSigilType.Shadow]	= { strName = Apollo.GetString(""),	"",	"" }
}

local karSigilElementsToId = -- TODO: Replace with enums
{
	[Item.CodeEnumSigilType.Fire]		= 131,
	[Item.CodeEnumSigilType.Water]		= 132,
	[Item.CodeEnumSigilType.Earth]		= 133,
	[Item.CodeEnumSigilType.Air]		= 134,
	[Item.CodeEnumSigilType.Life]		= 135,
	[Item.CodeEnumSigilType.Logic]		= 136,
	[Item.CodeEnumSigilType.Fusion]		= 137,
	[Item.CodeEnumSigilType.Omni]		= 0,
	--[Item.CodeEnumSigilType.Shadow]	= ,
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

local knSaveVersion = 3

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
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("GenericEvent_CraftingResume_OpenEngraving", 	"OnGenericEvent_CraftingResume_OpenEngraving", self)
	Apollo.RegisterEventHandler("GenericEvent_CraftingResume_CloseEngraving", 	"OnClose", self)
	Apollo.RegisterEventHandler("TradeskillEngravingStationClose", 				"OnClose", self)
	Apollo.RegisterEventHandler("UpdateInventory", 								"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 					"RedrawAll", self)
	Apollo.RegisterEventHandler("ItemModified", 								"RedrawAll", self)

	Apollo.RegisterTimerHandler("Runecrafting_InitializeDelay",					"RedrawAll", self)
	Apollo.CreateTimer("Runecrafting_InitializeDelay", 1, false)
	Apollo.StopTimer("Runecrafting_InitializeDelay")

	Apollo.RegisterTimerHandler("Runecrafting_ConfirmPopupDelay",				"OnRunecrafting_ConfirmPopupDelay", self)
	Apollo.CreateTimer("Runecrafting_ConfirmPopupDelay", 0.15, false)
	Apollo.StopTimer("Runecrafting_ConfirmPopupDelay")

	Apollo.RegisterEventHandler("DragDropSysBegin", 							"OnSystemBeginDragDrop", self)
	Apollo.RegisterEventHandler("DragDropSysEnd", 								"OnSystemEndDragDrop", self)
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

	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "EquipmentItem", nil, self)
	self.knEquipmentItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "TypeTierItem", nil, self)
	self.knDefaultTypeTierItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	-- Variables
	self.bAllowClicks = true
	self.bDragging = false
	self.itemDragging = nil
	self.wndCurrentConfirmPopup = nil

	local bRequirementMet = true
	local nPlayerLevel = GameLib.GetPlayerLevel()
	if nPlayerLevel < knLevelRequirement then
		self.wndMain:FindChild("RuneCreationItemList"):SetTextColor(ApolloColor.new("UI_WindowTextCraftingRedCapacitor"))
		self.wndMain:FindChild("RuneCreationItemList"):SetText(String_GetWeaselString(Apollo.GetString("Runecrafting_LevelRequirementNotMet"),  knLevelRequirement))
		bRequirementMet = false
	else
		self.wndMain:FindChild("RuneCreationItemList"):SetTextColor(ApolloColor.new("UI_TextHoloBodyHighlight"))
		self.wndMain:FindChild("RuneCreationItemList"):SetText(Apollo.GetString("Runecrafting_StartingHelperTip"))
	end

	-- Initialize Elements
	local wndParent = self.wndMain:FindChild("RuneCreationElementList")
	for idx, eElement in pairs(Item.CodeEnumSigilType) do
		if eElement ~= Item.CodeEnumSigilType.Omni then -- There are no Omni runes, so skip
			local wndCurr = self:LoadByName("RuneCreationElementItem", wndParent, idx)
			wndCurr:FindChild("RuneCreationElementBtn"):SetData(eElement)
			wndCurr:FindChild("RuneCreationElementBtn"):Enable(bRequirementMet)
			wndCurr:FindChild("RuneCreationElementIcon"):SetSprite(karSigilElementsToSprite[eElement].strFade)
			wndCurr:FindChild("RuneCreationElementName"):SetText(karSigilElementsToSprite[eElement].strName)
			wndCurr:FindChild("RuneCreationElementName"):SetTextColor("WindowTitleColor")
		end
	end
	wndParent:ArrangeChildrenVert(0, function(a,b) return a:GetName() < b:GetName() end)
end

function Runecrafting:OnClose(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end

	Event_CancelEngravingStation()
end

function Runecrafting:OnGenericEvent_CraftingResume_OpenEngraving()
	self:Initialize()
	Apollo.StartTimer("Runecrafting_InitializeDelay") -- Will do RedrawAll()
end

function Runecrafting:OnRedrawAllFromUI(wndHandler, wndControl)
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

function Runecrafting:RedrawAll()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	if self.wndMain:FindChild("ToggleRuneCreation"):IsChecked() then
		self:RedrawCreation()
	elseif self.wndMain:FindChild("ToggleEquipRunes"):IsChecked() then
		self:RedrawEquipment()
	end
end

function Runecrafting:RedrawEquipment()
	local wndParent = self.wndMain:FindChild("MainItemList")
	local nVScrollPos = wndParent:GetVScrollPos()
	wndParent:DestroyChildren()

	for idx, tCurrItem in pairs(CraftingLib.GetValidGlyphableItems(true, false)) do -- 1st arg is Equipped
		if tCurrItem then
			self:NewEquipmentItem(tCurrItem, wndParent, true)
		end
	end

	for idx, tCurrItem in pairs(CraftingLib.GetValidGlyphableItems(false, true)) do -- 2nd arg is Inventory
		if tCurrItem then
			self:NewEquipmentItem(tCurrItem, wndParent)
		end
	end

	wndParent:ArrangeChildrenVert(0)
	wndParent:SetVScrollPos(nVScrollPos)
	wndParent:RecalculateContentExtents()
	wndParent:SetText(#self.wndMain:FindChild("MainItemList"):GetChildren() == 0 and Apollo.GetString("EngravingStation_NoInscribableItems") or "")
end

function Runecrafting:RedrawCreation()
	-- Determine element filter
	local eElementFilter = nil
	for idx, wndCurr in pairs(self.wndMain:FindChild("RuneCreationElementList"):GetChildren()) do
		local wndCurrBtn = wndCurr:FindChild("RuneCreationElementBtn")
		wndCurrBtn:FindChild("RuneCreationElementIcon"):SetSprite(karSigilElementsToSprite[wndCurrBtn:GetData()].strFade)
		wndCurrBtn:FindChild("RuneCreationElementIconBright"):SetSprite(karSigilElementsToSprite[wndCurrBtn:GetData()].strBright)
		wndCurrBtn:FindChild("RuneCreationElementIconBright"):Show(wndCurrBtn:IsChecked(), false, 0.4)

		if wndCurrBtn and wndCurrBtn:IsChecked() then
			eElementFilter = karSigilElementsToId[wndCurrBtn:GetData()] or nil
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
		tSchematicList[strItemType][idx] = { tCurrSchematic, tSchematicInfo }
	end

	-- Draw Runes
	local wndCreateARuneParent = self.wndMain:FindChild("RuneCreationItemList")
	for strItemType, tRuneList in pairs(tSchematicList) do
		local wndTypeTier = self:LoadByName("TypeTierItem", wndCreateARuneParent, "TypeTierItem"..strItemType)
		wndTypeTier:FindChild("TypeTierItemLabel"):SetText(strItemType)
		wndTypeTier:FindChild("TypeTierItemBtn"):SetData(wndTypeTier)
		wndTypeTier:FindChild("TypeTierItemBtn"):SetCheck(false)
		wndTypeTier:SetData(tRuneList)
	end

	-- Check the first in list, after sorting
	wndCreateARuneParent:SetText("")
	wndCreateARuneParent:ArrangeChildrenVert(0, function(a,b) return a:GetName() < b:GetName() end)
	local wndFirst = wndCreateARuneParent:GetChildren()[1]
	if wndFirst then
		wndFirst:FindChild("TypeTierItemBtn"):SetCheck(true)
		self:DrawCreateRuneContents(wndFirst)
	end

	self:ResizeCreateRunes()
end

function Runecrafting:DrawCreateRuneContents(wndParent)
	local tRuneList = wndParent:GetData()

	for idx2, tPackedData in pairs(tRuneList) do
		local tCurrSchematic = tPackedData[1]
		local tSchematicInfo = tPackedData[2]
		local tItemGlyphInfo = tSchematicInfo.itemOutput:GetGlyphInfo()

		-- Check Materials
		local bHasMaterials = true
		for idx2, tMaterialData in pairs(tSchematicInfo.tMaterials) do
			if tMaterialData.nAmount > tMaterialData.itemMaterial:GetBackpackCount() then
				bHasMaterials = false
				break
			end
		end

		-- Formatting
		local wndCurr = self:LoadByName("NewRuneItem", wndParent:FindChild("TypeTierItemContainer"), "NewRuneItem"..tCurrSchematic.nSchematicId)
		wndCurr:FindChild("NewRuneMoreInfoBtn"):SetData(tSchematicInfo)
		wndCurr:FindChild("NewRuneMoreInfoName"):SetData(bHasMaterials)
		wndCurr:FindChild("NewRuneMoreInfoName"):SetText(tCurrSchematic.strName)
		wndCurr:FindChild("NewRuneMoreInfoName"):SetTextColor(bHasMaterials and "UI_BtnTextBlueNormal" or "UI_BtnTextRedNormal")
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

	for idx2, tData in pairs(tSchematicInfo.tMaterials) do
		local itemMaterial = tData.itemMaterial
		local bNotEnough = itemMaterial:GetBackpackCount() < tData.nAmount
		local wndMaterial = self:LoadByName("RawMaterialsItem", wndParent:FindChild("RuneCreationMaterialsList"), "RawMaterialsItem"..itemMaterial:GetName())
		wndMaterial:FindChild("RawMaterialsIcon"):SetSprite(itemMaterial:GetIcon())
		wndMaterial:FindChild("RawMaterialsIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), itemMaterial:GetBackpackCount(), tData.nAmount))
		wndMaterial:FindChild("RawMaterialsNotEnough"):Show(bNotEnough)
		Tooltip.GetItemTooltipForm(self, wndMaterial, itemMaterial, {bSelling = false})

		if bNotEnough then
			wndParent:FindChild("RuneCreationCraftBtn"):Enable(false)
		end
	end
	wndParent:FindChild("RuneCreationMaterialsList"):ArrangeChildrenHorz(0)
end

function Runecrafting:OnNewRuneMoreInfoCheck(wndHandler, wndControl) -- NewRuneMoreInfoBtn, data is tSchematicInfo
	if wndHandler ~= wndControl then
		return
	end

	wndHandler:FindChild("NewRuneMoreInfoName"):SetTextColor(ApolloColor.new("UI_BtnTextBluePressed"))

	local tSchematicInfo = wndHandler:GetData()
	local wndParent = self.wndMain:FindChild("RuneCreationContainer"):FindChild("RuneCreationBottom")
	wndParent:FindChild("RuneCreationMaterialsList"):DestroyChildren()
	wndParent:FindChild("RuneCreationCraftBtn"):SetData(tSchematicInfo.nSchematicId)
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
	wndHandler:FindChild("NewRuneMoreInfoName"):SetTextColor(wndHandler:FindChild("NewRuneMoreInfoName"):GetData() and "UI_BtnTextBlueNormal" or "UI_BtnTextRedNormal")
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

function Runecrafting:OnRuneCreationCraftBtn(wndHandler, wndControl)
	CraftingLib.CraftItem(wndHandler:GetData()) -- Schematic Id
	self:OnClose()
end

-----------------------------------------------------------------------------------------------
-- Equipment
-----------------------------------------------------------------------------------------------

function Runecrafting:NewEquipmentItem(itemSource, wndParent, bEquipped)
	local wndItem = Apollo.LoadForm(self.xmlDoc, "EquipmentItem", wndParent, self)
	wndItem:FindChild("EquipmentItemCantUseIcon"):Show(self:HelperPrereqFailed(itemSource))
	wndItem:FindChild("EquipmentItemIcon"):SetSprite(itemSource:GetIcon())

	if bEquipped then
		Tooltip.GetItemTooltipForm(self, wndItem:FindChild("EquipmentItemIcon"), itemSource, { bPrimary = true, bSelling = false })
		wndItem:FindChild("EquipmentItemName"):SetText(String_GetWeaselString(Apollo.GetString("Runecrafting_EquippedPrefix"), itemSource:GetName()))
	else
		local itemEquipped = itemSource and itemSource:GetEquippedItemForItemType() or nil
		Tooltip.GetItemTooltipForm(self, wndItem:FindChild("EquipmentItemIcon"), itemSource, { bPrimary = true, bSelling = false, itemCompare = itemEquipped })
		wndItem:FindChild("EquipmentItemName"):SetText(itemSource:GetName())
	end

	-- Sigils
	wndItem:FindChild("EquipmentItemSigilContainer"):DestroyChildren()
	local tSigilData = itemSource:GetSigils()
	if tSigilData and tSigilData.bIsDefined then
		local bFirstLockedSlot = true
		for idx, tCurrSigil in pairs(tSigilData.arSigils) do
			local wndSigil = self:LoadByName(tCurrSigil.bUnlocked and "SigilSlot" or "SigilLockedSlot", wndItem:FindChild("EquipmentItemSigilContainer"), "SigilSlot"..idx)
			wndSigil:FindChild("SigilSlotBtn"):SetData({ idx, tCurrSigil, itemSource })
			wndSigil:FindChild("SigilSlotType"):SetSprite(karSigilElementsToSprite[tCurrSigil.eType].strFade)

			-- This is how "strong" a socket is. Current design has this diminish the more slots there are (so an 8 slot drop isn't significantly better than a 7 slot drop)
			local tDetailedInfo = itemSource:GetDetailedInfo()
			if tDetailedInfo and tDetailedInfo.tPrimary.tSigils then
				local tRelevantSlotBudgetData = tDetailedInfo.tPrimary.tSigils.arSigils[idx]
				local strRelevantSlotBudgePercent = math.floor(tRelevantSlotBudgetData.nPercent * 100).."%"
				wndSigil:FindChild("SigilSlotEfficiency"):SetText(strRelevantSlotBudgePercent == "100%" and "Max" or strRelevantSlotBudgePercent)
				wndSigil:FindChild("SigilSlotEfficiency"):SetTextColor((tCurrSigil.bUnlocked or bFirstLockedSlot) and ApolloColor.new("UI_TextHoloBody") or ApolloColor.new("UI_TextMetalBody"))
			end

			-- Different formatting and text for different button states
			local tSigilItemData = Item.GetDataFromId(tCurrSigil.idGlyph)
			if tSigilItemData and wndSigil:FindChild("SigilSlotIcon") then
				wndSigil:FindChild("SigilSlotIcon"):SetSprite(tSigilItemData:GetIcon())
				self:HelperBuildItemTooltip(wndSigil, tSigilItemData)
			elseif tCurrSigil.bUnlocked then
				wndSigil:SetTooltip(String_GetWeaselString(Apollo.GetString("EngravingStation_AvailableSlot"), tCurrSigil.strName))
			elseif bFirstLockedSlot then
				bFirstLockedSlot = false
				wndSigil:FindChild("SigilFakeLockIcon"):Show(true)
				wndSigil:SetTooltip(String_GetWeaselString(Apollo.GetString("EngravingStation_LockedSlot"), tCurrSigil.strName))
			else
				wndSigil:FindChild("SigilSlotBtn"):Enable(false)
				wndSigil:SetTooltip(Apollo.GetString("EngravingStation_LockedChildSlot"))
			end
		end
	end
	wndItem:FindChild("EquipmentItemSigilContainer"):ArrangeChildrenHorz(0)
end

function Runecrafting:OnUnlockConfirmYes(wndHandler, wndControl)
	local nSlotIndex = wndHandler:GetData()[1]
	local itemSource = wndHandler:GetData()[3] -- Data is passed along, origates from SigilSlotBtn and is { idx, tCurrSigil, itemSource }
	CraftingLib.UnlockSigil(itemSource, nSlotIndex)
	self:OnCurrentConfirmPopupClose()
end

function Runecrafting:OnClearConfirmYes(wndHandler, wndControl)
	local nSlotIndex = wndHandler:GetData()[1]
	local itemSource = wndHandler:GetData()[3] -- Data is passed along, origates from SigilSlotBtn and is { idx, tCurrSigil, itemSource }
	CraftingLib.ClearSigil(itemSource, nSlotIndex)
	self:OnCurrentConfirmPopupClose()
end

-----------------------------------------------------------------------------------------------
-- wndCurrentConfirmPopup
-----------------------------------------------------------------------------------------------

function Runecrafting:OnSigilLockedSlotBtn(wndHandler, wndControl) -- SigilSlotBtn of SigilLockedSlot
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
	self:HelperResizeConfirmPopup(wndHandler)
end

function Runecrafting:OnSigilSlotBtn(wndHandler, wndControl) -- SigilSlotBtn of SigilLockedSlot
	if not self.bAllowClicks then
		return
	end
	
	local nSlotIndex = wndHandler:GetData()[1]
	local tCurrSigil = wndHandler:GetData()[2]
	local itemSource = wndHandler:GetData()[3]

	self:OnCurrentConfirmPopupClose()

	if self.itemDragging and self.itemDragging:GetGlyphInfo().eType ~= tCurrSigil.eType then
		return Apollo.DragDropQueryResult.Accept -- HACK
	end

	if tCurrSigil.idGlyph == 0 then
		self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "AddPicker", self.wndMain, self)
		for idx, itemGlyph in pairs(CraftingLib.GetValidGlyphItems()) do
			local tItemGlyphInfo = itemGlyph:GetGlyphInfo()
			if self:HelperDoSigilAndGlyphMatch(tItemGlyphInfo, tCurrSigil) then
				local wndGlyph = self:LoadByName("GlyphPickerItem", self.wndCurrentConfirmPopup:FindChild("AddPickerList"), "AddPickerList"..idx..itemGlyph:GetName())
				wndGlyph:FindChild("GlyphPickerBtn"):SetData({wndHandler, itemGlyph})
				wndGlyph:FindChild("GlyphPickerText"):SetText(itemGlyph:GetName())
				wndGlyph:FindChild("GlyphPickerIcon"):SetSprite(itemGlyph:GetIcon())
				wndGlyph:FindChild("GlyphPickerIcon"):SetText(itemGlyph:GetBackpackCount())
				self:HelperBuildItemTooltip(wndGlyph, itemGlyph)
			end
		end
		local bHasItems = #self.wndCurrentConfirmPopup:FindChild("AddPickerList"):GetChildren() > 0
		self.wndCurrentConfirmPopup:FindChild("AddPickerList"):ArrangeChildrenTiles(0)
		self.wndCurrentConfirmPopup:FindChild("AddPickerList"):SetText(bHasItems and "" or Apollo.GetString("EngravingStation_NoRunesFound"))
	else
		local tEngravingInfo = CraftingLib.GetEngravingInfo(itemSource)
		local tCurrentCosts = tEngravingInfo.tClearInfo.arCosts[nSlotIndex]
		self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "ClearConfirm", self.wndMain, self)
		self.wndCurrentConfirmPopup:FindChild("ClearConfirmYes"):SetData(wndHandler:GetData())
		self.wndCurrentConfirmPopup:FindChild("ClearCashWindow"):SetAmount(tCurrentCosts and tCurrentCosts.monCost or 0)
	end
	self:HelperResizeConfirmPopup(wndHandler)

	return Apollo.DragDropQueryResult.Accept -- HACK
end

function Runecrafting:OnGlyphPickerBtn(wndHandler, wndControl)
	self:DrawGlyphAddConfirm(wndHandler:GetData()[1], wndHandler:GetData()[2])
end

function Runecrafting:DrawGlyphAddConfirm(wndHandler, itemGlyph)
	local nSlotIndex = wndHandler:FindChild("SigilSlotBtn"):GetData()[1]
	local itemSource = wndHandler:FindChild("SigilSlotBtn"):GetData()[3]
	self:OnCurrentConfirmPopupClose()

	-- What the glyph will add to the item, if successful
	local tItemEffectData = itemSource:GetGlyphBonus(itemGlyph, nSlotIndex)
	local strItemEffect = String_GetWeaselString(Apollo.GetString("EngravingStation_EffectIfSuccessful"), tItemEffectData.nValue or 0, ktAttributeToText[tItemEffectData.eProperty])

	-- Draw Window
	self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "AddConfirm", self.wndMain, self)
	self.wndCurrentConfirmPopup:FindChild("AddConfirmYes"):SetData({ nSlotIndex, itemGlyph, itemSource }) -- GOTCHA: Different 2nd argument than normal
	self.wndCurrentConfirmPopup:FindChild("AddConfirmItemEffect"):SetText(strItemEffect)
	self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"):SetSprite(itemGlyph:GetIcon())
	self.wndCurrentConfirmPopup:FindChild("AddConfirmText"):Show(itemSource:IsSoulbound())
	self.wndCurrentConfirmPopup:FindChild("AddConfirmSoulboundWarning"):Show(not itemSource:IsSoulbound())
	self:HelperBuildItemTooltip(self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"), itemGlyph)
	self:HelperResizeConfirmPopup(wndHandler)
end

function Runecrafting:DrawGlyphReplaceConfirm(wndHandler, itemGlyph)
	local nSlotIndex = wndHandler:FindChild("SigilSlotBtn"):GetData()[1]
	local itemSource = wndHandler:FindChild("SigilSlotBtn"):GetData()[3]
	local tEngravingInfo = CraftingLib.GetEngravingInfo(itemSource)
	local tCurrentCosts = tEngravingInfo.tClearInfo.arCosts[nSlotIndex]
	self:OnCurrentConfirmPopupClose()

	-- Draw Window
	self.wndCurrentConfirmPopup = Apollo.LoadForm(self.xmlDoc, "ReplaceConfirm", self.wndMain, self)
	self.wndCurrentConfirmPopup:FindChild("AddConfirmYes"):SetData({ nSlotIndex, itemGlyph, itemSource }) -- GOTCHA: Different 2nd argument than normal
	self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"):SetSprite(itemGlyph:GetIcon())
	self.wndCurrentConfirmPopup:FindChild("ClearCashWindow"):SetAmount(tCurrentCosts and tCurrentCosts.monCost or 0)
	self:HelperBuildItemTooltip(self.wndCurrentConfirmPopup:FindChild("AddConfirmIcon"), itemGlyph)
	self:HelperResizeConfirmPopup(wndHandler)
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

function Runecrafting:HelperResizeConfirmPopup(wndOrigin)
	local wndIter = wndOrigin
	local wndExit = wndOrigin:GetFrame()
	local nTotalX, nTotalY = 0, 0

	for idx = 1, 99 do
	local nIterTrap = 0
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

function Runecrafting:OnSystemBeginDragDrop()
	self.bDragging = true
end

function Runecrafting:OnSystemEndDragDrop()
	self.bDragging = false
end

function Runecrafting:OnSigilSlotQueryDragDrop(wndHandler, wndControl, x, y, wndSource, strType, nDragInventoryItemIdx, eResult)
	local itemSource = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx)
	if itemSource and strType == "DDBagItem" then
		local tCurrSigil = wndHandler:GetData()[2]
		local tItemGlyphInfo = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx):GetGlyphInfo()
		if tCurrSigil.eType and tItemGlyphInfo then
			return Apollo.DragDropQueryResult.Accept
		end
	end
	return Apollo.DragDropQueryResult.Ignore
end

function Runecrafting:OnSigilSlotDragDrop(wndHandler, wndControl, x, y, wndSource, strType, nDragInventoryItemIdx, bDragDropHasBeenReset)
	local itemSource = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx)
	if itemSource and strType == "DDBagItem" then
		local tCurrSigil = wndHandler:GetData()[2]
		local tItemGlyphInfo = self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx):GetGlyphInfo()
		if self:HelperDoSigilAndGlyphMatch(tItemGlyphInfo, tCurrSigil) then
			if tCurrSigil.idGlyph == 0 then -- No rune in slot
				self:DrawGlyphAddConfirm(wndHandler:GetParent(), self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx))
			else -- Replace rune in slot
				self:DrawGlyphReplaceConfirm(wndHandler:GetParent(), self.wndMain:FindChild("HiddenBagWindow"):GetItem(nDragInventoryItemIdx))
			end
		end
		return false
	end
	return true
end

function Runecrafting:OnAddConfirmYes(wndHandler, wndControl) -- Potentially from drag drop or from picker
	local nSlotIndex = wndHandler:GetData()[1]
	local itemGlyph = wndHandler:GetData()[2] -- GOTCHA: This is an item object, not the normal table of data
	local itemSource = wndHandler:GetData()[3]

	local tSigilData = itemSource:GetSigils()
	if tSigilData and tSigilData.bIsDefined then
		local tListOfGlyphs = {}
		for idx, tCurrSigil in pairs(tSigilData.arSigils) do
			if tCurrSigil.bUnlocked then
				tListOfGlyphs[idx] = tCurrSigil.idGlyph
			end
		end
		tListOfGlyphs[nSlotIndex] = itemGlyph:GetItemId() -- Replace with the desired
		CraftingLib.InstallGlyphs(itemSource, tListOfGlyphs)
	end
	self:OnCurrentConfirmPopupClose()
end

function Runecrafting:OnReplaceConfirmYes( wndHandler, wndControl, eMouseButton )
	local nSlotIndex = wndHandler:GetData()[1]
	local itemGlyph = wndHandler:GetData()[2] -- GOTCHA: This is an item object, not the normal table of data
	local itemSource = wndHandler:GetData()[3]

	local tSigilData = itemSource:GetSigils()
	if tSigilData and tSigilData.bIsDefined then
		local tListOfGlyphs = {}
		for idx, tCurrSigil in pairs(tSigilData.arSigils) do
			if tCurrSigil.bUnlocked then
				tListOfGlyphs[idx] = tCurrSigil.idGlyph
			end
		end
		tListOfGlyphs[nSlotIndex] = itemGlyph:GetItemId() -- Replace with the desired
		CraftingLib.ClearSigil(itemSource, nSlotIndex)
		CraftingLib.InstallGlyphs(itemSource, tListOfGlyphs)
	end

	self:OnCurrentConfirmPopupClose()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function Runecrafting:HelperDoSigilAndGlyphMatch(tItemGlyphInfo, tSigil)
	return tSigil.eType == Item.CodeEnumSigilType.Omni or tItemGlyphInfo.eType == Item.CodeEnumSigilType.Omni or tItemGlyphInfo.eType == tSigil.eType
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
