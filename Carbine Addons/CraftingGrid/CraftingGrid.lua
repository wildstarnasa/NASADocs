-----------------------------------------------------------------------------------------------
-- Client Lua Script for CraftingGrid
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CraftingLib"

local CraftingGrid = {}

local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "ItemQuality_Inferior",
	[Item.CodeEnumItemQuality.Average] 			= "ItemQuality_Average",
	[Item.CodeEnumItemQuality.Good] 			= "ItemQuality_Good",
	[Item.CodeEnumItemQuality.Excellent] 		= "ItemQuality_Excellent",
	[Item.CodeEnumItemQuality.Superb] 			= "ItemQuality_Superb",
	[Item.CodeEnumItemQuality.Legendary] 		= "ItemQuality_Legendary",
	[Item.CodeEnumItemQuality.Artifact]		 	= "ItemQuality_Artifact",
}

local ktItemRarityToBorderSprite =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "CRB_Tooltips:sprTooltip_SquareFrame_Silver",
	[Item.CodeEnumItemQuality.Average] 			= "CRB_Tooltips:sprTooltip_SquareFrame_White",
	[Item.CodeEnumItemQuality.Good] 			= "CRB_Tooltips:sprTooltip_SquareFrame_Green",
	[Item.CodeEnumItemQuality.Excellent] 		= "CRB_Tooltips:sprTooltip_SquareFrame_Blue",
	[Item.CodeEnumItemQuality.Superb] 			= "CRB_Tooltips:sprTooltip_SquareFrame_Purple",
	[Item.CodeEnumItemQuality.Legendary] 		= "CRB_Tooltips:sprTooltip_SquareFrame_Orange",
	[Item.CodeEnumItemQuality.Artifact]		 	= "CRB_Tooltips:sprTooltip_SquareFrame_Pink",
}

local ktstrAxisToIcon =
{
	[CraftingLib.CodeEnumTradeskill.Architect] =
	{
		"sprCoord_Icon_ArchitectFunction",
		"sprCoord_Icon_ArchitectSynthetic",
		"sprCoord_Icon_ArchitectForm",
		"sprCoord_Icon_ArchitectOrganic",
		"sprCoord_Icon_NorthEastArrow",
		"sprCoord_Icon_SouthEastArrow",
		"sprCoord_Icon_NorthWestArrow",
		"sprCoord_Icon_SouthWestArrow",
	},
	[CraftingLib.CodeEnumTradeskill.Augmentor] =
	{
		"sprCoord_Icon_TechWater",
		"sprCoord_Icon_TechWind",
		"sprCoord_Icon_TechFire",
		"sprCoord_Icon_TechEarth",
		"sprCoord_Icon_NorthEastArrow",
		"sprCoord_Icon_SouthEastArrow",
		"sprCoord_Icon_NorthWestArrow",
		"sprCoord_Icon_SouthWestArrow",
	},
	[CraftingLib.CodeEnumTradeskill.Cooking] =
	{
		"sprCoord_Icon_CookingSpicy",
		"sprCoord_Icon_CookingSavory",
		"sprCoord_Icon_CookingSour",
		"sprCoord_Icon_CookingSweet",
		"sprCoord_Icon_NorthEastArrow",
		"sprCoord_Icon_SouthEastArrow",
		"sprCoord_Icon_NorthWestArrow",
		"sprCoord_Icon_SouthWestArrow",
	},
}

local ktHitZoneToAxisId =
{	-- GOTCHA: Since it's based on axis names, 1234 are the first and this doesn't matchup with CraftingLib.CodeEnumCraftingDirection
	["HitZone_Center"]	=	-1,
	["HitZone_E"]		=	1,
	["HitZone_N"]		=	2,
	["HitZone_W"]		=	3,
	["HitZone_S"]		=	4,
	["HitZone_NE"]		=	5,
	["HitZone_SE"]		=	6,
	["HitZone_NW"]		=	7,
	["HitZone_SW"]		=	8,
}

local ktAdditiveAxisToAllowed =
{
	{true,true,true,false,false},	-- East
	{true,true,false,true,false},	-- North
	{true,false,true,true,false},	-- West
	{false,true,true,true,false},	-- South
	{true,true,false,false,true},	-- North East
	{false,true,true,false,true},	-- South East
	{true,false,false,true,true},	-- North West
	{false,false,true,true,true},	-- South West
}

local ktLastAttemptHotOrColdString =
{
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Cold] 	= Apollo.GetString("CoordCrafting_Cold"),
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Warm] 	= Apollo.GetString("CoordCrafting_Warm"),
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Hot] 		= Apollo.GetString("CoordCrafting_Hot"),
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Success] 	= Apollo.GetString("CoordCrafting_Success"),
}

local ktHotOrColdToSprite =
{
	[CraftingLib.CodeEnumCraftingDirection.N]	=	"sprCoord_Direction_N",
	[CraftingLib.CodeEnumCraftingDirection.NE]	=	"sprCoord_Direction_NE",
	[CraftingLib.CodeEnumCraftingDirection.E]	=	"sprCoord_Direction_E",
	[CraftingLib.CodeEnumCraftingDirection.SE]	=	"sprCoord_Direction_SE",
	[CraftingLib.CodeEnumCraftingDirection.S]	=	"sprCoord_Direction_S",
	[CraftingLib.CodeEnumCraftingDirection.SW]	=	"sprCoord_Direction_SW",
	[CraftingLib.CodeEnumCraftingDirection.W]	=	"sprCoord_Direction_W",
	[CraftingLib.CodeEnumCraftingDirection.NW]	=	"sprCoord_Direction_NW",
}

function CraftingGrid:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	return o
end

function CraftingGrid:Init()
    Apollo.RegisterAddon(self)
end

function CraftingGrid:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CraftingGrid.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function CraftingGrid:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_CraftingResume_CloseCraftingWindows", "ExitAndReset", self)
	Apollo.RegisterEventHandler("GenericEvent_BotchCraft", 							"ExitAndReset", self)
	Apollo.RegisterEventHandler("GenericEvent_CraftingSummaryIsFinished", 			"OnCloseBtn", self)
	Apollo.RegisterEventHandler("GenericEvent_StartCraftingGrid", 					"OnGenericEvent_StartCraftingGrid", self)
	Apollo.RegisterEventHandler("CraftingDiscoveryHotCold", 						"OnCraftingDiscoveryHotCold", self)
	Apollo.RegisterEventHandler("CraftingSchematicLearned", 						"OnCraftingSchematicLearned", self)
	Apollo.RegisterEventHandler("CraftingUpdateCurrent", 							"OnCraftingUpdateCurrent", self)
	Apollo.RegisterEventHandler("UpdateInventory", 									"RedrawAll", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 							"RedrawCash", self)

	Apollo.RegisterTimerHandler("CraftingGrid_CraftBtnTimer", 						"OnCraftingGrid_CraftBtnTimer", self)
	Apollo.RegisterEventHandler("CraftingInterrupted",								"OnCraftingGrid_CraftBtnTimer", self)
	Apollo.CreateTimer("CraftingGrid_CraftBtnTimer", 3.25, false)
	Apollo.StopTimer("CraftingGrid_CraftBtnTimer")

	Apollo.RegisterTimerHandler("CraftingGrid_TimerCraftingStationCheck", 			"OnCraftingGrid_TimerCraftingStationCheck", self)
	Apollo.CreateTimer("CraftingGrid_TimerCraftingStationCheck", 1, true)

	self.wndArrowTutorial = -1 -- This is -1 if not set yet, then 0 after it's been set (and we no longer ever want to show it)

	-- This data exists past Destroy/Initialize (TODO: Move to OnSave/Restore)
	self.strPendingLastMarkerTooltip = ""
	self.tLastMarkersList = {}
end

function CraftingGrid:OnCraftingGrid_TimerCraftingStationCheck()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("BGCraftingStationBlocker"):Show(not CraftingLib.IsAtCraftingStation())
	end
end

function CraftingGrid:OnGenericEvent_StartCraftingGrid(idSchematic)
	if not idSchematic then
		return
	end

	self:Initialize()
	self.wndMain:SetData(idSchematic)
	self:BuildNewGrid(idSchematic)
	self:RedrawAll()

	Sound.Play(Sound.PlayUIWindowCraftingOpen)

	Event_ShowTutorial(GameLib.CodeEnumTutorial.CoordinateCrafting)
end

function CraftingGrid:Initialize()
	if self.wndMain and self.wndMain:IsValid() then
		return
	end

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "CraftingGridForm", nil, self)
	self.wndMain:FindChild("ShowTutorialsBtn"):Enable(false)
	self.wndAdditiveEstimate = nil
	self.wndMarker = nil

	self.bFullDestroyNeeded = false -- Either Catalysts, or Discovery Success so far
	self.nMaxY, self.nMaxX, self.nMinX, self.nMinY = nil
	self.tAdditivesAdded = {}
	self.tWndCircles = {}
end

-----------------------------------------------------------------------------------------------
-- Main Drawing
-----------------------------------------------------------------------------------------------

function CraftingGrid:RedrawAll()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self:RedrawCash()

	local idSchematic = self.wndMain:GetData()
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	local tSchematicInfo = CraftingLib.GetSchematicInfo(idSchematic)
	local bCurrentCraftStarted = tCurrentCraft and tCurrentCraft.nSchematicId == idSchematic

	-- Build List of Variants
	local wndVariantsParent = self.wndMain:FindChild("VariantsList")
	for idx, tCurrSubRecipe in pairs(tSchematicInfo.tSubRecipes) do
		local bHitThisSubSchematic = bCurrentCraftStarted and tCurrentCraft.nSubSchematicId == tCurrSubRecipe.nSchematicId
		self:BuildVariantItem(wndVariantsParent, tCurrSubRecipe.itemOutput, tCurrSubRecipe, bHitThisSubSchematic)
	end
	self.wndMain:FindChild("VariantsListLabel"):Show(wndVariantsParent:ArrangeChildrenVert(0) > 0)

	-- Bottom Right Item Output
	self.wndMain:FindChild("VariantsCurrentBox"):DestroyChildren()
	local bHitAnySubSchematic = bCurrentCraftStarted and tCurrentCraft.nSchematicId ~= 0 and tCurrentCraft.nSubSchematicId ~= 0
	local tSubSchematicInfo = bHitAnySubSchematic and CraftingLib.GetSchematicInfo(tCurrentCraft.nSubSchematicId) or tSchematicInfo
	self:BuildVariantItem(self.wndMain:FindChild("VariantsCurrentBox"), tSubSchematicInfo.itemOutput, false, false)
	self.wndMain:FindChild("VariantsCurrentBox"):SetData(tSubSchematicInfo.itemOutput)

	-- POTENTIAL EXIT: Not Known
	self.wndMain:FindChild("BGNotKnownBlocker"):Show(false)
	if not tSchematicInfo.bIsKnown and not tSchematicInfo.bIsOneUse then
		self.wndMain:FindChild("BGNotKnownBlocker"):Show(true)
		return
	end

	-- Count Raw Materials
	local bHasEnoughRawMaterials = true
	self.wndMain:FindChild("CraftMaterialsList"):DestroyChildren()
	for idx, tMaterial in pairs(tSchematicInfo.tMaterials) do
		if  tMaterial.itemMaterial:GetBackpackCount() < tMaterial.nAmount then
			bHasEnoughRawMaterials = false
			break
		end
	end

	-- POTENTIAL EXIT: Enough Materials Blocker
	local wndBlockerParent = self.wndMain:FindChild("BGBlockers")
	wndBlockerParent:FindChild("BGNoMaterialsBlocker"):Show(not bCurrentCraftStarted and not bHasEnoughRawMaterials)
	if not bCurrentCraftStarted and not bHasEnoughRawMaterials then
		wndBlockerParent:FindChild("BGNoMaterialsList"):DestroyChildren()
		for idx, tMaterial in pairs(tSchematicInfo.tMaterials) do
			local nBackpackCount = tMaterial.itemMaterial:GetBackpackCount()
			local wndNoMaterials = Apollo.LoadForm(self.xmlDoc, "RawMaterialsItem", wndBlockerParent:FindChild("BGNoMaterialsList"), self)
			wndNoMaterials:FindChild("RawMaterialsIcon"):SetTextColor("ffff0000")
			wndNoMaterials:FindChild("RawMaterialsIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nBackpackCount, tMaterial.nAmount))
			wndNoMaterials:FindChild("RawMaterialsIcon"):SetSprite(tMaterial.itemMaterial:GetIcon())
			wndNoMaterials:FindChild("RawMaterialsNotEnough"):Show(nBackpackCount < tMaterial.nAmount)
			self:HelperBuildItemTooltip(wndNoMaterials, tMaterial.itemMaterial)
		end
		wndBlockerParent:FindChild("BGNoMaterialsList"):ArrangeChildrenHorz(1)
		return
	end

	-- Preview Only (Catalysts)
	local wndCatalystList = wndBlockerParent:FindChild("CatalystGlobalList")
	if not bCurrentCraftStarted then
		wndCatalystList:DestroyChildren()

		-- No Catalyst Option
		local wndNoCatalysts = Apollo.LoadForm(self.xmlDoc, "CatalystItem", wndCatalystList, self)
		wndNoCatalysts:SetTooltip(Apollo.GetString("CraftingGrid_DoNotUseCatalyst"))
		wndNoCatalysts:SetCheck(true)
		wndNoCatalysts:SetData(false)

		-- Catalysts
		for idx, tItemData in pairs(CraftingLib.GetAvailableCatalysts(tSchematicInfo.eTradeskillId, idSchematic)) do
			local itemCatalyst = tItemData.itemCatalyst
			if itemCatalyst:GetGlobalCatalystInfo() then
				local wndCurr = Apollo.LoadForm(self.xmlDoc, "CatalystItem", wndCatalystList, self)
				wndCurr:SetData(itemCatalyst) -- For OnCatalystItemToggle
				--wndCurr:SetTextColor(karEvalColors[itemCatalyst:GetItemQuality()])
				wndCurr:SetText(String_GetWeaselString(Apollo.GetString("CraftingGrid_CatalystCountAndName"), tItemData.nCount, itemCatalyst:GetName()))
				self:HelperBuildItemTooltip(wndCurr, itemCatalyst)
			end
		end
		wndCatalystList:SetText(#wndCatalystList:GetChildren() == 0 and Apollo.GetString("CoordCrafting_NoCatalystsInInv") or "")
		wndCatalystList:ArrangeChildrenVert(0)
	end
	wndBlockerParent:FindChild("CatalystContainer"):Show(#wndCatalystList:GetChildren() > 0)
	wndBlockerParent:FindChild("BGPreviewOnlyBlocker"):Show(not bCurrentCraftStarted)
	wndBlockerParent:FindChild("BGPreviewOnlyBlocker"):FindChild("PreviewStartCraftBtn"):SetData(idSchematic)

	-- Previous Last Attempt Markers
	for idx = 1, 9000 do
		if self.wndMain:FindChild("CoordinateSchematic"):FindChild("GridLastMarker") then
			self.wndMain:FindChild("CoordinateSchematic"):FindChild("GridLastMarker"):Destroy()
		else
			break
		end
	end

	-- Last Attempt Markers
	if self.tLastMarkersList and self.tLastMarkersList[idSchematic] then
		for idx, tCurrData in pairs(self.tLastMarkersList[idSchematic]) do
			-- Build multi line tooltip
			local strLastTooltip = Apollo.GetString("CoordCrafting_NoExtraMats")
			if tCurrData.strTooltip then
				strLastTooltip = string.format("<P Font=\"CRB_InterfaceSmall_O\">%s</P>", tCurrData.strHotOrCold or "")
				strLastTooltip = string.format("%s<P Font=\"CRB_InterfaceSmall_O\">%s</P>", strLastTooltip, tCurrData.strTooltip)
			end

			-- Marker
			local nLastTopLeftX = tCurrData.nPosX or 0
			local nLastTopLeftY = tCurrData.nPosY or 0
			local wndLastMarker = Apollo.LoadForm(self.xmlDoc, "GridLastMarker", self.wndMain:FindChild("CoordinateSchematic"), self)
			wndLastMarker:SetAnchorPoints(nLastTopLeftX, nLastTopLeftY, nLastTopLeftX, nLastTopLeftY)
			wndLastMarker:SetSprite(ktHotOrColdToSprite[tCurrData.eDirection])
			wndLastMarker:SetTooltip(strLastTooltip)
			wndLastMarker:ToFront()
		end
	end

	-- Continue drawing (implictly we have enough materials)
	self:RedrawAllDetailed(idSchematic, tSchematicInfo, tCurrentCraft, bCurrentCraftStarted)
end

function CraftingGrid:BuildVariantItem(wndParent, itemRecipe, tSchem, bHitThisSubSchematic)
	local wndSubrecipe = self:LoadByName("VariantItem", wndParent, "VariantItem"..itemRecipe:GetItemId())
	wndSubrecipe:FindChild("VariantHitItAnim"):Show(bHitThisSubSchematic)
	wndSubrecipe:FindChild("VariantItemName"):SetText(bHitThisSubSchematic and "" or itemRecipe:GetName())
	wndSubrecipe:FindChild("VariantItemRarity"):SetSprite(ktItemRarityToBorderSprite[itemRecipe:GetItemQuality()])

	if tSchem and tSchem.bIsUndiscovered then
		wndSubrecipe:FindChild("VariantItemIcon"):SetBGColor(ApolloColor.new("UI_TextHoloTitle"))
		wndSubrecipe:FindChild("VariantItemIcon"):SetSprite("Icon_Mission_Explorer_ScavengerHunt")
		wndSubrecipe:FindChild("VariantItemIcon"):SetTooltip(Apollo.GetString("CraftingGrid_DiscoverableVariantTooltip"))
	elseif tSchem and not tSchem.bIsKnown then
		wndSubrecipe:FindChild("VariantItemIcon"):SetBGColor(ApolloColor.new("white"))
		wndSubrecipe:FindChild("VariantItemIcon"):SetSprite("CRB_AMPs:spr_AMPs_LockStretch_Blue")
		wndSubrecipe:FindChild("VariantItemIcon"):SetTooltip(tSchem.achSource and Apollo.GetString("CraftingGrid_NotKnownVariantTooltip") or Apollo.GetString("CoordCrafting_UnlockTooltipRecipe"))
	else
		wndSubrecipe:FindChild("VariantItemIcon"):SetBGColor(ApolloColor.new("white"))
		wndSubrecipe:FindChild("VariantItemIcon"):SetSprite(itemRecipe:GetIcon())
		wndSubrecipe:FindChild("VariantItemIcon"):SetTooltip("")
		self:HelperBuildItemTooltip(wndSubrecipe:FindChild("VariantItemIcon"), itemRecipe)
	end

	-- Determine direction, if not the base
	if tSchem then
		wndSubrecipe:FindChild("VariantItemIcon"):SetData(self:HelperDetermineAdditiveDirection(tSchem)) -- For OnVariantItemIconClick, to auto open the correct recipe category
	end
end

function CraftingGrid:RedrawAllDetailed(idSchematic, tSchematicInfo, tCurrentCraft, bCurrentCraftStarted)
	-- Grid Glows
	local bHitACircle = false
	if bCurrentCraftStarted and tCurrentCraft.nSubSchematicId then
		for idx2, wndCurr in pairs(self.tWndCircles) do
			local bCurrCircleHit = bCurrentCraftStarted and wndCurr:GetData() and wndCurr:GetData().nSchematicId == tCurrentCraft.nSubSchematicId
			wndCurr:FindChild("GridCircleHitItAnim"):Show(bCurrCircleHit)
			bHitACircle = bHitACircle or bCurrCircleHit
		end
	end
	self.wndMain:FindChild("SuccessRobot"):Show(bHitACircle, false, 2.5)

	-- Build marker (if not already built, such as from a resume)
	if bCurrentCraftStarted and not bHitACircle and (tCurrentCraft.fVectorY ~= 0 and tCurrentCraft.fVectorX ~= 0) then
		self:HelperBuildMarker()
	end

	-- Materials Counting
	local wndCraftMaterialsList = self.wndMain:FindChild("CraftMaterialsList")
	for idx = 1, tSchematicInfo.nMaxAdditives do
		local itemAdditive = self.tAdditivesAdded[idx]
		local wndAdditiveMaterial = Apollo.LoadForm(self.xmlDoc, "CraftMaterialsItem", wndCraftMaterialsList, self)
		wndAdditiveMaterial:FindChild("CraftMaterialsCircle"):SetText(idx)

		if self.wndMarker then
			if itemAdditive then
				self.wndMarker:SetSprite(itemAdditive:GetIcon())
			end
			self.wndMarker:FindChild("GridMarkerCircle"):SetTextColor(ApolloColor.new("UI_BtnTextRedNormal"))
			self.wndMarker:FindChild("GridMarkerCircle"):SetSprite("Crafting_CoordSprites:sprCoord_SmallCircle_Red")
		end

		-- Material Numbered List
		if not bCurrentCraftStarted or idx > tCurrentCraft.nAdditiveCount then -- Empty Slot
			wndAdditiveMaterial:FindChild("CraftMaterialsTitle"):SetText("")
			wndAdditiveMaterial:SetTooltip("")
		elseif itemAdditive then -- Added
			wndAdditiveMaterial:FindChild("CraftMaterialsTitle"):SetText(itemAdditive:GetName())
			self:HelperBuildItemTooltip(wndAdditiveMaterial, itemAdditive)
		else -- Old Craft
			wndAdditiveMaterial:FindChild("CraftMaterialsTitle"):SetText(Apollo.GetString("CoordCrafting_LeftoverAdditive"))
			wndAdditiveMaterial:SetTooltip(Apollo.GetString("CoordCrafting_LeftoverAdditive"))
		end

		-- Last stop
		if bCurrentCraftStarted and bHitACircle and idx == tCurrentCraft.nAdditiveCount then
			wndAdditiveMaterial:FindChild("CraftMaterialsTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGreenNormal"))
			wndAdditiveMaterial:FindChild("CraftMaterialsCircle"):SetTextColor(ApolloColor.new("UI_BtnTextGreenNormal"))
			wndAdditiveMaterial:FindChild("CraftMaterialsCircle"):SetSprite("Crafting_CoordSprites:sprCoord_SmallCircle_Green")
			Sound.Play(Sound.PlayUICraftingCoordinateHit)
		elseif bCurrentCraftStarted and idx == tCurrentCraft.nAdditiveCount and tSchematicInfo.nMaxAdditives == tCurrentCraft.nAdditiveCount then
			wndAdditiveMaterial:FindChild("CraftMaterialsTitle"):SetTextColor(ApolloColor.new("UI_BtnTextRedNormal"))
			wndAdditiveMaterial:FindChild("CraftMaterialsCircle"):SetTextColor(ApolloColor.new("UI_BtnTextRedNormal"))
			wndAdditiveMaterial:FindChild("CraftMaterialsCircle"):SetSprite("Crafting_CoordSprites:sprCoord_SmallCircle_Red")
			Sound.Play(Sound.PlayUICraftingCoordinateMiss)
		end
	end
	wndCraftMaterialsList:ArrangeChildrenVert(0)

	-- Additives Store Direction Set Up
	local tTradeskillInfo = CraftingLib.GetTradeskillInfo(tSchematicInfo.eTradeskillId)
	local tAxisNames = tTradeskillInfo.tAxisNames
	tAxisNames[5] = String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[1], tAxisNames[2])
	tAxisNames[6] = String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[1], tAxisNames[4])
	tAxisNames[7] = String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[3], tAxisNames[2])
	tAxisNames[8] = String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[3], tAxisNames[4])

	-- Additives Store Prices Set Up
	local nPlayerMoneyInCopper = GameLib.GetPlayerCurrency():GetAmount()
	local tListAdditives = CraftingLib.GetAvailableAdditives(tSchematicInfo.eTradeskillId, idSchematic)
	table.sort(tListAdditives, function(a,b) return a:GetBuyPrice():GetAmount() < b:GetBuyPrice():GetAmount() end) -- Apparently this can change mid craft

	-- Additives Store Draw
	for eAxis, strAxisName in pairs(tAxisNames) do -- R, T, L, B
		local wndAdditiveHeader = self:LoadByName("AdditiveHeader", self.wndMain:FindChild("AdditiveList"), "AdditiveHeader"..strAxisName)
		wndAdditiveHeader:FindChild("AdditiveHeaderIcon"):SetSprite(ktstrAxisToIcon[tSchematicInfo.eTradeskillId][eAxis] or "")
		wndAdditiveHeader:FindChild("AdditiveHeaderBtnText"):SetText(strAxisName)

		if wndAdditiveHeader:FindChild("AdditiveHeaderBtn"):IsChecked() then
			for idx2, itemCurr in pairs(tListAdditives) do
				local tAdditive = itemCurr:GetAdditiveInfo()
				if self:HelperVerifyAxis(ktAdditiveAxisToAllowed[eAxis], tAdditive.fVectorX, tAdditive.fVectorY) then
					-- Build Additive Item
					local nAdditivePrice = itemCurr:GetBuyPrice():GetAmount()
					local bCanAfford = nPlayerMoneyInCopper > nAdditivePrice
					local wndCurr = self:LoadByName("AdditiveItem", wndAdditiveHeader:FindChild("AdditiveHeaderItems"), "AdditiveItem"..itemCurr:GetItemId())
					wndCurr:SetData(itemCurr)
					wndCurr:FindChild("AdditiveMouseCatcher"):SetData(itemCurr)
					wndCurr:FindChild("AdditiveCashWindow"):SetAmount(nAdditivePrice)
					wndCurr:FindChild("AdditiveCashWindow"):SetTextColor(bCanAfford and ApolloColor.new("UI_BtnTextGoldListPressed") or ApolloColor.new("AddonError"))
					wndCurr:FindChild("AdditiveIcon"):SetSprite(bCanAfford and itemCurr:GetIcon() or "ClientSprites:LootCloseBox")
					wndCurr:FindChild("AdditiveTitleText"):SetAML("<P Font=\"CRB_InterfaceMedium_BO\" TextColor=\"UI_BtnTextGoldListPressed\">"..itemCurr:GetName().."</P>")

					-- Resize
					local nTextWidth, nTextHeight = wndCurr:FindChild("AdditiveTitleText"):SetHeightToContentHeight()
					local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
					wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(30, nTextHeight + 10))
				end
			end
		else
			wndAdditiveHeader:FindChild("AdditiveHeaderItems"):DestroyChildren()
		end
	end

	-- Resize Additive List
	for idx, wndAdditiveHeader in pairs(self.wndMain:FindChild("AdditiveList"):GetChildren()) do
		local nCheckedPadding = wndAdditiveHeader:FindChild("AdditiveHeaderBtn"):IsChecked() and 56 or 40
		local nChildrenHeight = wndAdditiveHeader:FindChild("AdditiveHeaderItems"):ArrangeChildrenVert(0)
		local nLeft, nTop, nRight, nBottom = wndAdditiveHeader:GetAnchorOffsets()
		wndAdditiveHeader:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nChildrenHeight + nCheckedPadding)
	end
	self.wndMain:FindChild("AdditiveList"):ArrangeChildrenVert(0)

	-- Enable craft button only if there is enough room in inventory
	local bHaveBagSpace = self.wndMain:FindChild("HiddenBagWindow"):GetTotalEmptyBagSlots() > 0
	self.wndMain:FindChild("CraftBtn"):Enable(bHaveBagSpace)
	if bHaveBagSpace then
		self.wndMain:FindChild("CraftBtn"):SetText(Apollo.GetString("ActivationPrompt_CraftingStation"))
	else
		self.wndMain:FindChild("CraftBtn"):SetText(Apollo.GetString("ItemSetInventory_InventoryFull"))
	end

	-- Hide if at max
	local bReadyToCraft = bCurrentCraftStarted and tCurrentCraft.nAdditiveCount == tSchematicInfo.nMaxAdditives
	self.wndMain:FindChild("AdditiveListBlocker"):Show(bReadyToCraft)
	self.wndMain:FindChild("HelperText_ReadyToCraft"):Show(bReadyToCraft)
end

function CraftingGrid:RedrawCash()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	self.wndMain:FindChild("BGPlayerCashWindow"):SetAmount(GameLib.GetPlayerCurrency(), true)
end

-----------------------------------------------------------------------------------------------
-- Craft Btn
-----------------------------------------------------------------------------------------------

function CraftingGrid:OnPreviewStartCraftBtn(wndHandler, wndControl) -- PreviewStartCraftBtn, data is idSchematic
	local idSchematic = wndHandler:GetData()
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	if not tCurrentCraft or tCurrentCraft.nSchematicId == 0 then -- Start if it hasn't started already (i.e. just clicking craft button)
		CraftingLib.CraftItem(idSchematic, self.wndMain:FindChild("CatalystGlobalList"):GetData()) -- 2nd arg is catalyst, and can be nil
	end

	-- We need a complete redraw for catalysts
	if self.wndMain:FindChild("CatalystGlobalList"):GetData() then
		self.bFullDestroyNeeded = true
	end
	Event_FireGenericEvent("GenericEvent_StartCraftingGrid", idSchematic)
end

function CraftingGrid:OnCraftingUpdateCurrent()
	if self.bFullDestroyNeeded then
		self.bFullDestroyNeeded = false
		local idSchematic = self.wndMain:GetData()
		self.wndMain:Destroy()
		Event_FireGenericEvent("GenericEvent_StartCraftingGrid", idSchematic)
	else
		self:RedrawAll()
	end
end

function CraftingGrid:OnCraftBtn(wndHandler, wndControl) -- CraftBtn
	if wndHandler ~= wndControl then
		return
	end

	-- Save Last Attempt Data
	local nNewPosX, nNewPosY = 0.5, 0.5
	if self.wndMarker and self.wndMarker:IsValid() then
		nNewPosX, nNewPosY = self.wndMarker:GetAnchorPoints()
	end

	-- Save last Tooltip
	local strTooltipSaved = self.strPendingLastMarkerTooltip or ""
	if string.len(strTooltipSaved) == 0 then
		strTooltipSaved = Apollo.GetString("CraftingGrid_NoAdditivesUsed")
	end
	self.strPendingLastMarkerTooltip = ""

	-- Save to our LastMarkersList table
	local nSchematicId = self.wndMain:GetData()
	self.tPendingDiscoveryResultData =
	{
		--eDirection (This is Set Later)
		["nPosX"] = nNewPosX,
		["nPosY"] = nNewPosY,
		["idSchematic"] = nSchematicId,
		["strTooltip"] = strTooltipSaved,
		["strHotOrCold"] = Apollo.GetString("CoordCrafting_ViewLastCraft"),
	}

	-- Order is important, must clear first
	Event_FireGenericEvent("GenericEvent_ClearCraftSummary")
	if string.len(strTooltipSaved) > 0 then
		Event_FireGenericEvent("GenericEvent_CraftSummaryMsg", Apollo.GetString("CoordCrafting_ItemsUsedSummary") .. "\n" .. strTooltipSaved)
	end

	-- Now Craft
	CraftingLib.CompleteCraft()

	-- Post Craft Effects
	local itemOutput = self.wndMain:FindChild("VariantsCurrentBox"):GetData()
	Event_FireGenericEvent("GenericEvent_StartCraftCastBar", self.wndMain:FindChild("BGPostCraftBlocker"):FindChild("CraftingSummaryContainer"), itemOutput)
	self.wndMain:FindChild("BGPostCraftBlocker"):FindChild("MouseBlockerBtn"):Show(true)
	self.wndMain:FindChild("BGPostCraftBlocker"):FindChild("MouseBlocker"):Show(true)
	self.wndMain:FindChild("BGPostCraftBlocker"):Show(true)
	Apollo.StartTimer("CraftingGrid_CraftBtnTimer")
end

function CraftingGrid:OnCraftingGrid_CraftBtnTimer()
	Apollo.StopTimer("CraftingGrid_CraftBtnTimer")
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("BGPostCraftBlocker"):FindChild("MouseBlocker"):Show(false)
		self.wndMain:FindChild("BGPostCraftBlocker"):FindChild("MouseBlockerBtn"):Show(false)
	end
end

function CraftingGrid:OnCraftingSchematicLearned(idTradeskill, idSchematic)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local tSchematicInfo = CraftingLib.GetSchematicInfo(idSchematic)
	local nParentId = tSchematicInfo and tSchematicInfo.nParentSchematicId or idSchematic
	self.tLastMarkersList[idSchematic] = nil
	self.tLastMarkersList[nParentId] = nil
	self.bFullDestroyNeeded = true
end

function CraftingGrid:OnCraftingDiscoveryHotCold(eHotCold, eDirection)
	if eHotCold == CraftingLib.CodeEnumCraftingDiscoveryHotCold.Success then
		return
	end

	local tTempData = self.tPendingDiscoveryResultData
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	if tCurrentCraft and tCurrentCraft.nSchematicId and tTempData then
		--tPendingDiscoveryResultData has:
		--	["nPosX"] = nNewPosX,
		--	["nPosY"] = nNewPosY,
		--	["idSchematic"] = nSchematicId,
		--	["strTooltip"] = strTooltipSaved,
		--	["strHotOrCold"] = Apollo.GetString("CoordCrafting_ViewLastCraft"),
		tTempData.eDirection = eDirection
		tTempData.idSchematic = tCurrentCraft.nSchematicId
		tTempData.strHotOrCold = ktLastAttemptHotOrColdString[eHotCold]

		if not self.tLastMarkersList[tCurrentCraft.nSchematicId] then
			self.tLastMarkersList[tCurrentCraft.nSchematicId] = {}
		end
		table.insert(self.tLastMarkersList[tCurrentCraft.nSchematicId], tTempData)
	end
end

function CraftingGrid:OnAdditiveClick(wndHandler, wndControl) -- AdditiveItem, data is an itemData
	if wndHandler ~= wndControl then
		return
	end

	local itemData = wndHandler:GetData()
	local idSchematic = self.wndMain:GetData()
	if itemData then
		CraftingLib.AddAdditive(itemData)
		-- Success event will call: self:RedrawAll()

		local tCurrentCraft = CraftingLib.GetCurrentCraft()
		if tCurrentCraft then
			self.tAdditivesAdded[tCurrentCraft.nAdditiveCount + 1] = itemData
		end

		-- Add to new Last Attempt tooltip
		local tSchematicInfo = CraftingLib.GetSchematicInfo(idSchematic)
		if tCurrentCraft and tCurrentCraft.nAdditiveCount < tSchematicInfo.nMaxAdditives then
			self.strPendingLastMarkerTooltip = self.strPendingLastMarkerTooltip .. "\n" .. itemData:GetName()
		end

		self:HelperBuildMarker()
	end

	-- Wipe tutorial
	if self.wndArrowTutorial and self.wndArrowTutorial ~= -1 and self.wndArrowTutorial ~= 0 then
		self.wndArrowTutorial:Destroy()
		self.wndArrowTutorial = 0
	end

	-- Wipe 'ready to craft' message
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("HelperText_ReadyToCraft"):Show(false)
	end

	-- Wipe marker estimate
	if self.wndAdditiveEstimate and self.wndAdditiveEstimate:IsValid() then
		self.wndAdditiveEstimate:Destroy()
	end
end

function CraftingGrid:HelperBuildMarker()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	if not tCurrentCraft or tCurrentCraft.nAdditiveCount == 0 then
		return
	end

	-- Build Marker
	self.wndMarker = self:LoadByName("GridMarker", self.wndMain:FindChild("CoordinateSchematic"):FindChild("MarkerLayer"), "GridMarker"..tCurrentCraft.nAdditiveCount)
	self.wndMarker:FindChild("GridMarkerCircle"):SetText(tCurrentCraft.nAdditiveCount)

	local nAdjX = (-self.nMinX + tCurrentCraft.fVectorX) / (-self.nMinX + self.nMaxX)
	local nAdjY = 1.0 - (-self.nMinY + tCurrentCraft.fVectorY) / (-self.nMinY + self.nMaxY)
	self.wndMarker:SetAnchorPoints(nAdjX, nAdjY, nAdjX, nAdjY)

	-- Animate the Spawn Effect
	local nLeft, nTop, nRight, nBottom = self.wndMarker:FindChild("GridMarkerSpawnAnimation"):GetAnchorOffsets()
	local tLoc = WindowLocation.new({ fPoints = {0.5, 0.5, 0.5, 0.5}, nOffsets = { 0, 0, 0, 0 }})
	self.wndMarker:FindChild("GridMarkerSpawnAnimation"):TransitionMove(tLoc, 0.5)
	self.wndMarker:FindChild("GridMarkerSpawnAnimation"):Show(false, false, 5)
end

-----------------------------------------------------------------------------------------------
-- UI Interaction
-----------------------------------------------------------------------------------------------

function CraftingGrid:OnCatalystItemToggle(wndHandler, wndControl) -- CatalystItem, data is itemCatalyst or nil
	self.wndMain:FindChild("CatalystGlobalList"):SetData(wndHandler:IsChecked() and wndHandler:GetData() or nil)
end

function CraftingGrid:ExitAndReset(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end
end

function CraftingGrid:OnCloseBtn(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()

		local tCurrentCraft = CraftingLib.GetCurrentCraft()
		if tCurrentCraft and tCurrentCraft.nSchematicId ~= 0 then
			Event_FireGenericEvent("GenericEvent_LootChannelMessage", Apollo.GetString("CoordCrafting_CraftingInterrupted"))
		end
	end
	Event_FireGenericEvent("AlwaysShowTradeskills")
end

function CraftingGrid:OnAdditiveMouseEnter(wndHandler, wndControl) -- AdditiveItem's AdditiveMouseCatcher, data is an itemData
	if wndHandler ~= wndControl then
		return
	end

	if self.wndAdditiveEstimate and self.wndAdditiveEstimate:IsValid() then
		self.wndAdditiveEstimate:Destroy()
		self.wndAdditiveEstimate = nil
	end

	local itemData = wndControl:GetData()
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	local tSchematicInfo = CraftingLib.GetSchematicInfo(self.wndMain:GetData())

	-- Early exit if nil or already at max additives
	if not tSchematicInfo or not itemData or (tCurrentCraft and tCurrentCraft.nAdditiveCount >= tSchematicInfo.nMaxAdditives) then
		return
	end

	-- Position and Radius Size
	local tAdditiveInfo = itemData:GetAdditiveInfo()
	local nAdjX = (-self.nMinX + (tCurrentCraft and tCurrentCraft.fVectorX or 0) + tAdditiveInfo.fVectorX) / (-self.nMinX + self.nMaxX)
	local nAdjY = 1.0 - (-self.nMinY + (tCurrentCraft and tCurrentCraft.fVectorY or 0) + tAdditiveInfo.fVectorY) / (-self.nMinY + self.nMaxY)
	local nRadiusAdjX = tAdditiveInfo.fRadius == 0 and 5 or (tAdditiveInfo.fRadius / self.nMaxX * self.wndMain:FindChild("CoordinateSchematic"):GetWidth() / 2.0)
	local nRadiusAdjY = tAdditiveInfo.fRadius == 0 and 5 or (tAdditiveInfo.fRadius / self.nMaxY * self.wndMain:FindChild("CoordinateSchematic"):GetHeight() / 2.0)

	self.wndAdditiveEstimate = Apollo.LoadForm(self.xmlDoc, "GridAdditiveEstimate", self.wndMain:FindChild("CoordinateSchematic"), self)
	self.wndAdditiveEstimate:SetAnchorPoints(nAdjX, nAdjY, nAdjX, nAdjY)
	self.wndAdditiveEstimate:SetAnchorOffsets(-nRadiusAdjX, -nRadiusAdjY, nRadiusAdjX, nRadiusAdjY)

	-- Different sprites for different sizes (so the art is more crisp)
	local strEstimate = "sprCoord_AdditivePreview"
	if nRadiusAdjX < 20 then
		strEstimate = "sprCoord_AdditivePreviewTiny"
	elseif nRadiusAdjX < 48 then
		strEstimate = "sprCoord_AdditivePreviewSmall"
	else
		strEstimate = "sprCoord_AdditivePreview"
	end
	self.wndAdditiveEstimate:SetSprite(strEstimate)

	self.wndAdditiveEstimate:ToFront()
end

function CraftingGrid:OnAdditiveListMouseExit(wndHandler, wndControl) -- AdditiveItem or Code
	if wndHandler == wndControl and self.wndAdditiveEstimate and self.wndAdditiveEstimate:IsValid() then
		self.wndAdditiveEstimate:Destroy()
	end
end

function CraftingGrid:OnAdditiveHeaderBtnToggle(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	if not wndHandler:IsChecked() then
		self.wndMain:FindChild("AdditiveList"):SetVScrollPos(0)
	end
	self:RedrawAll()
end

function CraftingGrid:OnMaterialsLockedItemBtn(wndHandler, wndControl) -- wndHandler is "MaterialsLockedItemBtn" and its data is achSource
	Event_FireGenericEvent("GenericEvent_OpenToSpecificTechTree", wndHandler:GetData())
end

-----------------------------------------------------------------------------------------------
-- Set Up
-----------------------------------------------------------------------------------------------

function CraftingGrid:BuildNewGrid(idSchematic)
	local tSchematicInfo = CraftingLib.GetSchematicInfo(idSchematic)
	if not tSchematicInfo then
		return
	end

	-- Math for max dimensions
	self.nMaxX = math.abs(tSchematicInfo.fVectorX) + tSchematicInfo.fRadius
	self.nMaxY = math.abs(tSchematicInfo.fVectorY) + tSchematicInfo.fRadius

	local knBuffer = 1.25
	local nCurr = math.max(self.nMaxX, self.nMaxY)
	for idx, tSchem in ipairs(tSchematicInfo.tSubRecipes) do
		if not tSchem.bIsUndiscovered then
			local nFarthestCircleX = math.abs(tSchem.fVectorX) + tSchem.fRadius
			local nFarthestCircleY = math.abs(tSchem.fVectorY) + tSchem.fRadius
			nCurr = math.max(nCurr, nFarthestCircleX * knBuffer, nFarthestCircleY * knBuffer)
		elseif tSchem.fDiscoveryDistanceMax > nCurr then
			nCurr = tSchem.fDiscoveryDistanceMax * knBuffer
		end
	end
	nCurr = math.max(2.5, nCurr)

	self.nMaxY = nCurr
	self.nMaxX = nCurr
	self.nMinX = -nCurr
	self.nMinY = -nCurr

	-- Discoverables
	for key, tSchem in ipairs(tSchematicInfo.tSubRecipes) do
		if tSchem.bIsUndiscovered then
			self:BuildNewDiscoverable(tSchem)
		end

		if tSchem.fDiscoveryDistanceMin then
			local wndMiddleArtHack = self.wndMain:FindChild("DiscoverablesMiddleArtHack")
			local nRadiusMinPixels = tSchem.fDiscoveryDistanceMin / self.nMaxX * self.wndMain:FindChild("CoordinateSchematic"):GetWidth() / 2.0
			wndMiddleArtHack:Show(nRadiusMinPixels >= (wndMiddleArtHack:GetWidth() / 2))
		end
	end

	-- Circles
	for key, wndCurr in ipairs(self.tWndCircles) do
		wndCurr:Destroy()
	end
	self.tWndCircles = {}
	for key, tSchem in ipairs(tSchematicInfo.tSubRecipes) do
		if not tSchem.bIsUndiscovered then
			table.insert(self.tWndCircles, self:BuildNewGridCircle(tSchem))
		end
	end

	-- Axis Labels
	local tInfo = CraftingLib.GetTradeskillInfo(tSchematicInfo.eTradeskillId)
	for eAxisIdx, strName in pairs({ "XAxisRightIcon", "YAxisTopIcon", "XAxisLeftIcon", "YAxisBottomIcon" }) do
		local wndCurrAxis = self.wndMain:FindChild(strName)
		wndCurrAxis:SetTooltip(tInfo.tAxisNames[eAxisIdx])
		wndCurrAxis:SetSprite(ktstrAxisToIcon[tSchematicInfo.eTradeskillId][eAxisIdx])
	end

	-- Marker
	local wndMarkerParent = self.wndMain:FindChild("CoordinateSchematic"):FindChild("MarkerLayer")
	if self.wndMarker then
		self.wndMarker:Destroy()
		self.wndMarker = nil
	end
	if wndMarkerParent:FindChild("GridMarker1") then
		wndMarkerParent:FindChild("GridMarker1"):Destroy()
	end
	if wndMarkerParent:FindChild("GridMarker2") then
		wndMarkerParent:FindChild("GridMarker2"):Destroy()
	end

	-- Reset
	self.tAdditivesAdded = {}
	self.wndMain:FindChild("SuccessRobot"):Show(false)
	self.wndMain:FindChild("BGPostCraftBlocker"):Show(false)
	self.wndMain:FindChild("AdditiveList"):DestroyChildren()
end

function CraftingGrid:OnVariantItemIconClick(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler:GetData() or wndHandler:GetData() == 0 then
		return
	end

	local eAxisId = wndHandler:GetData()
	for idx, wndCurr in pairs(self.wndMain:FindChild("AdditiveList"):GetChildren()) do
		if wndCurr:FindChild("AdditiveHeaderBtn") then
			wndCurr:FindChild("AdditiveHeaderBtn"):SetCheck(idx == eAxisId)
			wndCurr:FindChild("AdditiveHeaderFlash"):SetSprite(idx == eAxisId and "WhiteFlash" or "")
		end
	end
	self:RedrawAll()
end

function CraftingGrid:OnHitzoneClick(wndHandler, wndControl)
	local eAxisId = ktHitZoneToAxisId[wndHandler:GetName()] or 0
	if eAxisId == 0 then -- GOTCHA: Allow -1, which is the center
		return
	end

	for idx, wndCurr in pairs(self.wndMain:FindChild("AdditiveList"):GetChildren()) do
		if wndCurr:FindChild("AdditiveHeaderBtn") then
			wndCurr:FindChild("AdditiveHeaderBtn"):SetCheck(idx == eAxisId)
			wndCurr:FindChild("AdditiveHeaderFlash"):SetSprite(idx == eAxisId and "WhiteFlash" or "")
		end
	end
	self:RedrawAll()
end

function CraftingGrid:OnHitZoneMouseEnter(wndHandler, wndControl)
	local eAxisId = ktHitZoneToAxisId[wndHandler:GetName()] or 0
	if wndHandler ~= wndControl or eAxisId == 0 or eAxisId == -1 then
		return
	end

	for idx, wndCurr in pairs(self.wndMain:FindChild("AdditiveList"):GetChildren()) do
		if wndCurr:FindChild("AdditiveHeaderBtn") then
			wndCurr:FindChild("AdditiveHeaderFlyby"):Show(idx == eAxisId)
		end
	end
end

function CraftingGrid:OnHitZoneMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		for idx, wndCurr in pairs(self.wndMain:FindChild("AdditiveList"):GetChildren()) do
			if wndCurr:FindChild("AdditiveHeaderBtn") then
				wndCurr:FindChild("AdditiveHeaderFlyby"):Show(false)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Building Circles/Discoverables
-----------------------------------------------------------------------------------------------

function CraftingGrid:BuildNewDiscoverable(tSchem) -- discoveryAngle, discoveryDistanceMin, discoveryDistanceMax
	local fLocalRotation = tSchem.fDiscoveryAngle + 45
	local wndResult = Apollo.LoadForm(self.xmlDoc, "GridDiscoverableItem", self.wndMain:FindChild("Discoverables"), self)
	wndResult:SetData(tSchem)

	-- Size the discoverable area
	local calcCords = function(nCenter, nRotation)
		local nLocalRadians = -2 * math.pi * (nRotation / 360)
		local nX = (nCenter * (math.cos(nLocalRadians) - math.sin(nLocalRadians)))
		local nY = (nCenter * (math.sin(nLocalRadians) + math.cos(nLocalRadians)))
		return nX, nY
	end

	local nRadiusMax = tSchem.fDiscoveryDistanceMax / self.nMaxX * self.wndMain:FindChild("CoordinateSchematic"):GetWidth() / 2.0
	local nHalfRadiusMax = nRadiusMax / 2
	local nMaxX, nMaxY = calcCords(nHalfRadiusMax, fLocalRotation)

	local tDiscoveryRadius =
	{
		loc =
		{
			fPoints = { 0.5, 0.5, 0.5, 0.5 },
			nOffsets = { nMaxX-nHalfRadiusMax, nMaxY-nHalfRadiusMax, nMaxX+nHalfRadiusMax, nMaxY+nHalfRadiusMax },
		},
		fRotation = math.atan2(-nMaxY, -nMaxX) * (180/math.pi) + 225,
		strSprite = "sprCoord_DiscoverBG_Teal",
	}
	local nBgPixieId = wndResult:AddPixie(tDiscoveryRadius)

	local nRadiusMin = tSchem.fDiscoveryDistanceMin / self.nMaxX * self.wndMain:FindChild("CoordinateSchematic"):GetWidth() / 2.0
	local nHalfRadiusMin = nRadiusMin / 2
	local nMinX, nMinY = calcCords(nHalfRadiusMin, fLocalRotation)
	local tDiscoveryRadius =
	{
		loc =
		{
			fPoints = { 0.5, 0.5, 0.5, 0.5 },
			nOffsets = { nMinX-nHalfRadiusMin, nMinY-nHalfRadiusMin, nMinX+nHalfRadiusMin, nMinY+nHalfRadiusMin },
		},
		fRotation = math.atan2(-nMinY, -nMinX) * (180/math.pi) + 225,
		strSprite = "sprCoord_DiscoverBG_Mask",
	}
	local nInnerRadiusPixieId = wndResult:AddPixie(tDiscoveryRadius)

	return wndResult
end

function CraftingGrid:BuildNewGridCircle(tSchem) -- vectorX, vectorY, radius
	local wndResult = Apollo.LoadForm(self.xmlDoc, "GridCircle", self.wndMain:FindChild("Graph"), self)
	wndResult:SetData(tSchem)

	-- Resize and Position
	local nAdjX = (-self.nMinX + tSchem.fVectorX) / (-self.nMinX + self.nMaxX)
	local nAdjY = 1.0 - (-self.nMinY + tSchem.fVectorY) / (-self.nMinY + self.nMaxY)
	wndResult:SetAnchorPoints(nAdjX, nAdjY, nAdjX, nAdjY)

	local nRadiusAdjX = tSchem.fRadius / self.nMaxX * self.wndMain:FindChild("CoordinateSchematic"):GetWidth() / 2.0
	local nRadiusAdjY = tSchem.fRadius / self.nMaxY * self.wndMain:FindChild("CoordinateSchematic"):GetHeight() / 2.0
	wndResult:FindChild("GridCircleRadius"):SetAnchorOffsets(-nRadiusAdjX, -nRadiusAdjY, nRadiusAdjX, nRadiusAdjY)

	if nRadiusAdjX < 20 or nRadiusAdjX < 20 then
		wndResult:FindChild("GridCircleIcon"):SetAnchorOffsets(0, 0, 0, 0) -- Don't bother showing icon
	elseif nRadiusAdjX < 30 or nRadiusAdjY < 30 then
		local nRadiusIconX = nRadiusAdjY - 11
		local nRadiusIconY = nRadiusAdjY - 11
		wndResult:FindChild("GridCircleIcon"):SetAnchorOffsets(-nRadiusIconX, -nRadiusIconY, nRadiusIconX, nRadiusIconY)
	end

	-- Tooltip and Icon
	local itemCraft = tSchem.itemOutput
	if tSchem.bIsKnown or tSchem.bIsUndiscovered then
		local strTooltip = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff9d9d9d\">%s</P><P Font=\"CRB_InterfaceSmall_O\" TextColor=\"%s\">%s</P>",
		Apollo.GetString("CoordCrafting_LandInCircle"), karEvalColors[itemCraft:GetItemQuality()], itemCraft:GetName())
		if itemCraft:GetActivateSpell() then
			strTooltip = strTooltip.."<P Font=\"CRB_InterfaceSmall_O\">"..itemCraft:GetActivateSpell():GetFlavor().."</P>"
		elseif itemCraft:GetItemFlavor() then
			strTooltip = strTooltip.."<P Font=\"CRB_InterfaceSmall_O\">"..itemCraft:GetItemFlavor().."</P>"
		end
		wndResult:FindChild("GridCircleTooltipHack"):SetTooltip(strTooltip)
	else -- If not yet known and it's not a free to discover one, then show a lock icon
		local wndMaterialsLocked = Apollo.LoadForm(self.xmlDoc, "GridCircleLockedItem", wndResult, self)
		wndMaterialsLocked:ToFront()
		wndMaterialsLocked:FindChild("MaterialsLockedItemBtn"):Show(tSchem.achSource)
		wndMaterialsLocked:FindChild("MaterialsLockedItemBtn"):SetData(tSchem.achSource)
		if tSchem.achSource then
			local strMaterialsLockedLineOne = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff9d9d9d\">%s</P>", Apollo.GetString("CoordCrafting_UnlockTooltip"))
			local strMaterialsLockedLineTwo = string.format("<P Font=\"CRB_InterfaceSmall_O\">%s</P>", tSchem.itemOutput:GetName())
			wndMaterialsLocked:FindChild("MaterialsLockedItemMouseCatcher"):SetTooltip(strMaterialsLockedLineOne .. strMaterialsLockedLineTwo)
		else
			wndMaterialsLocked:FindChild("MaterialsLockedItemMouseCatcher"):SetTooltip(Apollo.GetString("CoordCrafting_UnlockTooltipRecipe"))
		end
	end
	wndResult:FindChild("GridCircleIcon"):SetSprite(itemCraft:GetIcon())

	-- One time tutorial
	if self.wndArrowTutorial == -1 then
		self.wndArrowTutorial = Apollo.LoadForm(self.xmlDoc, "Tutorial_SmallRightArrow", wndResult, self)
		local nTextWidth = Apollo.GetTextWidth("CRB_Interface9_O", Apollo.GetString("CraftingGrid_ReachAdditiveTutorial"))
		local nLeft, nTop, nRight, nBottom = self.wndArrowTutorial:GetAnchorOffsets()
		self.wndArrowTutorial:SetAnchorOffsets(nLeft, nTop, nLeft + nTextWidth + 72, nBottom)
	end

	return wndResult
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function CraftingGrid:HelperDetermineAdditiveDirection(tSchem)
	if tSchem.bIsUndiscovered then
		return 0
	end

	-- TODO Make this more accurate
	local eRoughAxisDirection = 0
	if tSchem.fVectorX > 0 and tSchem.fVectorY > 0 and tSchem.fVectorX > tSchem.fVectorY then
		eRoughAxisDirection = 1
	elseif tSchem.fVectorX > 0 and tSchem.fVectorY > 0 then
		eRoughAxisDirection = 2
	elseif tSchem.fVectorX > 0 then
		eRoughAxisDirection = 4
	elseif tSchem.fVectorX <= 0 and math.abs(tSchem.fVectorX) > math.abs(tSchem.fVectorY) then
		eRoughAxisDirection = 3
	elseif tSchem.fVectorX <= 0 and tSchem.fVectorY > 0 then
		eRoughAxisDirection = 2
	elseif tSchem.fVectorX <= 0 then
		eRoughAxisDirection = 4
	end
	return eRoughAxisDirection
end

function CraftingGrid:HelperVerifyAxis(tFilters, fVectorX, fVectorY)
	local bDisplay = true
	if tFilters[5] then -- Allow 0's
		if fVectorY > 0 and not tFilters[1] then
			bDisplay = false
		elseif fVectorX > 0 and not tFilters[2] then
			bDisplay = false
		elseif fVectorY < 0 and not tFilters[3] then
			bDisplay = false
		elseif fVectorX < 0 and not tFilters[4] then
			bDisplay = false
		end
	else
		if fVectorY >= 0 and not tFilters[1] then
			bDisplay = false
		elseif fVectorX >= 0 and not tFilters[2] then
			bDisplay = false
		elseif fVectorY <= 0 and not tFilters[3] then
			bDisplay = false
		elseif fVectorX <= 0 and not tFilters[4] then
			bDisplay = false
		end
	end
	return bDisplay
end

function CraftingGrid:HelperStringMoneyConvert(nInCopper)
	local strResult = ""
	if nInCopper >= 1000000 then -- 12345678 = 12p 34g 56s 78c
		strResult = String_GetWeaselString(Apollo.GetString("CRB_Platinum"), math.floor(nInCopper/1000000)) .. " "
	end
	if nInCopper >= 10000 then
		strResult = strResult .. String_GetWeaselString(Apollo.GetString("CRB_Gold"), math.floor(nInCopper % 1000000 / 10000)) .. " "
	end
	if nInCopper >= 100 then
		strResult = strResult .. String_GetWeaselString(Apollo.GetString("CRB_Silver"), math.floor(nInCopper % 10000 / 100)) .. " "
	end
	strResult = strResult .. String_GetWeaselString(Apollo.GetString("CRB_Copper"), math.floor(nInCopper % 100))
	return strResult
end

function CraftingGrid:HelperBuildItemTooltip(wndArg, itemCurr)
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, { bPrimary = true, bSelling = false })
end

function CraftingGrid:LoadByName(strForm, wndParent, strCustomName)
	local wndNew = wndParent:FindChild(strCustomName)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strForm, wndParent, self)
		wndNew:SetName(strCustomName)
	end
	return wndNew
end

local CraftingGridInst = CraftingGrid:new()
CraftingGridInst:Init()
