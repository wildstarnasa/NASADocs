-----------------------------------------------------------------------------------------------
-- Client Lua Script for TradeskillSchematics
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CraftingLib"
require "AchievementsLib"

local TradeskillSchematics = {}

local karPowerCoreTierToString =
{
	[CraftingLib.CodeEnumTradeskillTier.Novice] 	= Apollo.GetString("CRB_Tradeskill_Quartz"),
	[CraftingLib.CodeEnumTradeskillTier.Apprentice] = Apollo.GetString("CRB_Tradeskill_Sapphire"),
	[CraftingLib.CodeEnumTradeskillTier.Journeyman] = Apollo.GetString("CRB_Tradeskill_Diamond"),
	[CraftingLib.CodeEnumTradeskillTier.Artisan] 	= Apollo.GetString("CRB_Tradeskill_Chrysalus"),
	[CraftingLib.CodeEnumTradeskillTier.Expert] 	= Apollo.GetString("CRB_Tradeskill_Starshard"),
	[CraftingLib.CodeEnumTradeskillTier.Master] 	= Apollo.GetString("CRB_Tradeskill_Hybrid"),
}

local kTradeskillIdToIcon =
{
	[CraftingLib.CodeEnumTradeskill.Survivalist]	=	"IconSprites:Icon_Achievement_UI_Tradeskills_Survivalist",
	[CraftingLib.CodeEnumTradeskill.Architect]		=	"IconSprites:Icon_Achievement_UI_Tradeskills_Architect",
	[CraftingLib.CodeEnumTradeskill.Fishing]		=	"",
	[CraftingLib.CodeEnumTradeskill.Mining]			=	"IconSprites:Icon_Achievement_UI_Tradeskills_Miner",
	[CraftingLib.CodeEnumTradeskill.Relic_Hunter]	=	"IconSprites:Icon_Achievement_UI_Tradeskills_RelicHunter",
	[CraftingLib.CodeEnumTradeskill.Cooking]		=	"IconSprites:Icon_Achievement_UI_Tradeskills_Cooking",
	[CraftingLib.CodeEnumTradeskill.Outfitter]		=	"IconSprites:Icon_Achievement_UI_Tradeskills_Outfitter",
	[CraftingLib.CodeEnumTradeskill.Armorer]		=	"IconSprites:Icon_Achievement_UI_Tradeskills_Armorer",
	[CraftingLib.CodeEnumTradeskill.Farmer]			=	"IconSprites:Icon_Achievement_UI_Tradeskills_Farmer",
	[CraftingLib.CodeEnumTradeskill.Weaponsmith]	=	"IconSprites:Icon_Achievement_UI_Tradeskills_WeaponCrafting",
	[CraftingLib.CodeEnumTradeskill.Tailor]			=	"IconSprites:Icon_Achievement_UI_Tradeskills_Tailor",
	[CraftingLib.CodeEnumTradeskill.Runecrafting]	=	"",
	[CraftingLib.CodeEnumTradeskill.Augmentor]		=	"IconSprites:Icon_Achievement_UI_Tradeskills_Technologist",
}

function TradeskillSchematics:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TradeskillSchematics:Init()
    Apollo.RegisterAddon(self)
end

function TradeskillSchematics:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	local tSavedData = self.tSavedData or {}
	return tSavedData
end

function TradeskillSchematics:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	self.tSavedData = tSavedData
end

function TradeskillSchematics:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TradeskillSchematics.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function TradeskillSchematics:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_InitializeSchematicsTree", 	"Initialize", self)
	Apollo.RegisterEventHandler("UpdateInventory", 							"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("CraftingSchematicLearned", 				"OnCraftingSchematicLearned", self)
	Apollo.RegisterEventHandler("TradeSkills_Learned", 						"OnTradeSkills_Learned", self)
	Apollo.RegisterEventHandler("TradeskillLearnedFromTHOR", 				"OnTradeSkills_Learned", self)

	Apollo.RegisterTimerHandler("Tradeskills_TimerCraftingStationCheck", "OnTimerCraftingStationCheck", self)
	Apollo.CreateTimer("Tradeskills_TimerCraftingStationCheck", 1, true)
end

function TradeskillSchematics:Initialize(wndParent, nSchematicId, strSearchQuery)
	if not self.wndMain or not self.wndMain:IsValid() then
		if self.tSavedData == nil then
			self.tSavedData = {}
		end

		if self.tSavedData.bFilterLocked == nil then
			self.tSavedData.bFilterLocked = false
		end

		if self.tSavedData.bFilterMats == nil then
			self.tSavedData.bFilterMats = false
		end

		self.wndMain = Apollo.LoadForm(self.xmlDoc, "TradeskillSchematicsForm", wndParent, self)
		self.wndMain:FindChild("LeftSideFilterLocked"):SetCheck(self.tSavedData.bFilterLocked)
		self.wndMain:FindChild("LeftSideFilterMaterials"):SetCheck(self.tSavedData.bFilterMats)

		self.wndLastBottomItemBtnBlue = nil
		self.bCoordCraft = false

		local wndMeasure = Apollo.LoadForm(self.xmlDoc, "TopLevel", nil, self)
		self.knTopLevelHeight = wndMeasure:GetHeight()
		wndMeasure:Destroy()

		wndMeasure = Apollo.LoadForm(self.xmlDoc, "MiddleLevel", nil, self)
		self.knMiddleLevelHeight = wndMeasure:GetHeight()
		wndMeasure:Destroy()

		wndMeasure = Apollo.LoadForm(self.xmlDoc, "BottomItem", nil, self)
		self.knBottomLevelHeight = wndMeasure:GetHeight()
		wndMeasure:Destroy()
	end

	self:FullRedraw(nSchematicId)

	local tSchematic = self.wndMain:FindChild("RightSide"):GetData() -- Won't be set at initialize
	if tSchematic then
		self:DrawSchematic(tSchematic)
	end

	if strSearchQuery and string.len(strSearchQuery) > 0 then
		self.wndMain:FindChild("RightSide"):Show(false)
		self.wndMain:FindChild("SearchTopLeftInputBox"):SetText(strSearchQuery)
		self:OnSearchTopLeftInputBoxChanged()
	end
end

function TradeskillSchematics:OnUpdateInventory()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then -- IsVisible() will consider parents as well
		return
	end

	self:OnSearchTopLeftInputBoxChanged()
	self:FullRedraw(nSchematicId)

	local tSchematic = self.wndMain:FindChild("RightSide"):GetData() -- Won't be set at initialize
	if tSchematic then
		self:DrawSchematic(tSchematic)
	end
end

function TradeskillSchematics:OnTradeSkills_Learned()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("LeftSideScroll"):DestroyChildren()
		self.wndMain:FindChild("RightSide"):SetData(nil)
		self.wndMain:FindChild("RightSide"):Show(false)
		self:FullRedraw()
	end
end

function TradeskillSchematics:OnCraftingSchematicLearned()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("RightSide"):Show(false)
		self:OnSearchTopLeftInputBoxChanged()
		self:FullRedraw()
	end
end

function TradeskillSchematics:RedrawFromUI(wndHandler, wndControl)
	self:FullRedraw()
end

function TradeskillSchematics:FullRedraw(nSchematicIdToOpen)
	-- Prebuild list
	local tTradeskills = {}
	for idx, tCurrTradeskill in ipairs(CraftingLib.GetKnownTradeskills()) do
		local tCurrTradeskillInfo = CraftingLib.GetTradeskillInfo(tCurrTradeskill.eId)
		if not tCurrTradeskillInfo.bIsHarvesting and tCurrTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Runecrafting then
			table.insert(tTradeskills, { tCurrTradeskill, tCurrTradeskillInfo })
		end
	end

	-- Since our top level is "Apprentice Weapon", "Novice Weapon" we use nTierIdx as the index instead of tTradeskill.id
	for idx, tCurrData in ipairs(tTradeskills) do
		local tCurrTradeskill = tCurrData[1]
		local tCurrTradeskillInfo = tCurrData[2]
		if tCurrTradeskillInfo.bIsHobby then
			local wndTop = self:LoadByName("TopLevel", self.wndMain:FindChild("LeftSideScroll"), tCurrTradeskill.eId)
			wndTop:FindChild("TopLevelBtnText"):SetText(tCurrTradeskill.strName)
			wndTop:FindChild("TopLevelIcon"):SetSprite(kTradeskillIdToIcon[tCurrTradeskill.eId])
			wndTop:FindChild("TopLevelBtn"):SetData({ tCurrTradeskill.eId, 0 }) -- ID is needed for GetSchematicList()

		elseif tCurrTradeskillInfo.bIsActive then
			local tMiddleCategories = AchievementsLib.GetTradeskillAchievementCategoryTree(tCurrTradeskill.eId)
			if tMiddleCategories then
				for nTierIdx = tCurrTradeskillInfo.eTier, 1, -1 do -- Start at current, then count down
					local tTier = tMiddleCategories.tSubGroups[nTierIdx]
					local wndTop = self:LoadByName("TopLevel", self.wndMain:FindChild("LeftSideScroll"), tTier.nSubGroupId)
					wndTop:FindChild("TopLevelBtnText"):SetText(tTier.strSubGroupName)
					wndTop:FindChild("TopLevelIcon"):SetSprite(kTradeskillIdToIcon[tCurrTradeskill.eId])
					wndTop:FindChild("TopLevelBtn"):SetData({ tCurrTradeskill.eId, nTierIdx }) -- ID is needed for GetSchematicList()
				end
			end
		end
	end

	local function HelperSortSchematicList(a, b)
		if not a or not b then -- TODO: Can be potentially nil?
			return true
		end

		if a.strItemTypeName and b.strItemTypeName and a.strItemTypeName == b.strItemTypeName then
			return a.strName < b.strName
		else
			return a.strItemTypeName < b.strItemTypeName
		end
	end

	-- Build the rest of the list if buttons are checked
	local tWndAndSchematicList = {}
	local bFilterLocked = self.wndMain:FindChild("LeftSideFilterLocked"):IsChecked()
	local bFilterMaterials = self.wndMain:FindChild("LeftSideFilterMaterials"):IsChecked()
	for idx, wndTop in pairs(self.wndMain:FindChild("LeftSideScroll"):GetChildren()) do
		local tTopLevelBtnData = wndTop:FindChild("TopLevelBtn"):GetData() -- {tCurrTradeskill.id, nIterationIdx}
		local tSchematicList = CraftingLib.GetSchematicList(tTopLevelBtnData[1], nil, tTopLevelBtnData[2], bFilterLocked)

		table.sort(tSchematicList, HelperSortSchematicList)
		tWndAndSchematicList[idx] = { wndTop = wndTop, tSchematicList = tSchematicList }
	end

	-- Iterate again, with a sorted and filtered list
	for idx, tData in pairs(tWndAndSchematicList) do
		local wndTop = tData.wndTop
		local tSchematicList = tData.tSchematicList
		for idx2, tSchematic in pairs(tSchematicList) do
			-- If told to open to a specific schematic
			if nSchematicIdToOpen and nSchematicIdToOpen == tSchematic.nSchematicId then
				self.wndMain:FindChild("RightSide"):SetData(tSchematic) -- Redraw will occur right after and pick this up
			elseif nSchematicIdToOpen then
				wndTop:FindChild("TopLevelBtn"):SetCheck(false)
			end

			-- Main drawing
			local bHaveMaterials, bValidOneUse = self:HelperHaveEnoughMaterials(tSchematic)
			if bValidOneUse and (bHaveMaterials or not bFilterMaterials) then
				local wndMiddle = self:LoadByName("MiddleLevel", wndTop:FindChild("TopLevelItems"), "M"..tSchematic.eItemType) -- So we don't run into ID collisions
				wndMiddle:FindChild("MiddleLevelBtn"):SetText(tSchematic.strItemTypeName)

				if wndMiddle:FindChild("MiddleLevelBtn"):IsChecked() then
					-- If we only draw the matching itemType then a filter updates needs a full redraw
					local bShowLock = not tSchematic.bIsKnown and not tSchematic.bIsOneUse
					local bShowMatsWarning = not bShowLock and not bHaveMaterials -- Implicit: If filtering by materials, this icon never shows
					local bOneTime = not bShowLock and bHaveMaterials and tSchematic.bIsOneUse
					local wndBottomItem = self:LoadByName("BottomItem", wndMiddle:FindChild("MiddleLevelItems"), "B"..tSchematic.nSchematicId)
					wndBottomItem:FindChild("BottomItemBtn"):SetData(tSchematic)
					wndBottomItem:FindChild("BottomItemBtn"):SetText(tSchematic.strName)
					wndBottomItem:FindChild("BottomItemLockIcon"):Show(bShowLock)
					wndBottomItem:FindChild("BottomItemOneTimeIcon"):Show(bOneTime)
					wndBottomItem:FindChild("BottomItemMatsWarningIcon"):Show(bShowMatsWarning)
				end
			end
		end
	end

	-- Clean anything without children
	for idx, wndTop in pairs(self.wndMain:FindChild("LeftSideScroll"):GetChildren()) do
		if wndTop:FindChild("TopLevelItems") and #wndTop:FindChild("TopLevelItems"):GetChildren() == 0 then
			wndTop:Destroy()
		end
	end

	self:ResizeTree()
end

function TradeskillSchematics:ResizeTree()
	local wndLeftSideScroll = self.wndMain:FindChild("LeftSideScroll")
	if not wndLeftSideScroll then
		return
	end

	local bFoundSelected = false
	local nScrollPos = 0
	for key, wndTop in pairs(wndLeftSideScroll:GetChildren()) do
		local nTopHeight = 6
		if wndTop:FindChild("TopLevelBtn"):IsChecked() then
			for key2, wndMiddle in pairs(wndTop:FindChild("TopLevelItems"):GetChildren()) do
				if wndMiddle:FindChild("MiddleLevelBtn"):IsChecked() then
					for key3, wndBot in pairs(wndMiddle:FindChild("MiddleLevelItems"):GetChildren()) do
						local wndBottomLevelBtn = wndBot:FindChild("BottomItemBtn")
						if Apollo.GetTextWidth("CRB_InterfaceMedium_B", wndBottomLevelBtn:GetText()) > wndBottomLevelBtn:GetWidth() then -- TODO QUICK HACK
							local nBottomLeft, nBottomTop, nBottomRight, nBottomBottom = wndBot:GetAnchorOffsets()
							wndBot:SetAnchorOffsets(nBottomLeft, nBottomTop, nBottomRight, nBottomTop + (self.knBottomLevelHeight * 1.5))
						end
					end
				else
					wndMiddle:FindChild("MiddleLevelItems"):DestroyChildren()
				end
				local nMiddleHeight = wndMiddle:FindChild("MiddleLevelItems"):ArrangeChildrenVert(0)
				if nMiddleHeight > 0 then
					nMiddleHeight = nMiddleHeight + 6
				end

				local nLeft, nTop, nRight, nBottom = wndMiddle:GetAnchorOffsets()
				wndMiddle:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.knMiddleLevelHeight + nMiddleHeight)
				wndMiddle:FindChild("MiddleLevelItems"):ArrangeChildrenVert(0)
				nTopHeight = nTopHeight + nMiddleHeight + 1
			end
			bFoundSelected = true
		else
			wndTop:FindChild("TopLevelItems"):DestroyChildren()
			nTopHeight = 0
		end

		local nMiddleHeight = #wndTop:FindChild("TopLevelItems"):GetChildren() * self.knMiddleLevelHeight
		local nLeft, nTop, nRight, nBottom = wndTop:GetAnchorOffsets()
		wndTop:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.knTopLevelHeight + nMiddleHeight + nTopHeight)
		wndTop:FindChild("TopLevelItems"):ArrangeChildrenVert(0)
		if not bFoundSelected then
			nScrollPos = nScrollPos + wndTop:GetHeight()
		end
	end

	wndLeftSideScroll:ArrangeChildrenVert(0)
	wndLeftSideScroll:RecalculateContentExtents()
	wndLeftSideScroll:SetVScrollPos(bFoundSelected and nScrollPos or 0)
end

-----------------------------------------------------------------------------------------------
-- Random UI Buttons and Main Draw Method
-----------------------------------------------------------------------------------------------

function TradeskillSchematics:OnTimerCraftingStationCheck()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local tSchematicInfo = nil
	local tSchematic = self.wndMain:FindChild("RightSide"):GetData()
	if tSchematic then
		tSchematicInfo = CraftingLib.GetSchematicInfo(tSchematic.nSchematicId)
	end

	local bIsAutoCraft = tSchematicInfo and tSchematicInfo.bIsAutoCraft
	local bIsAtCraftingStation = CraftingLib.IsAtCraftingStation()
	self.wndMain:FindChild("RightBottomCraftBtn"):Show(not bIsAutoCraft)
	self.wndMain:FindChild("RightBottomSimpleCraftBtn"):Show(bIsAutoCraft and bIsAtCraftingStation)
	if not bIsAtCraftingStation and bIsAutoCraft then
		self.wndMain:FindChild("RightBottomCraftPreview"):SetText(Apollo.GetString("Crafting_NotNearStation"))
	else
		self.wndMain:FindChild("RightBottomCraftPreview"):SetText("")
	end
end

function TradeskillSchematics:OnTopLevelBtnToggle(wndHandler, wndControl)
	self.wndMain:FindChild("RightSide"):Show(false)
	self:RedrawFromUI()
end

function TradeskillSchematics:OnMiddleLevelBtnToggle(wndHandler, wndControl)
	self.wndMain:FindChild("RightSide"):Show(false)
	self:RedrawFromUI()
end

function TradeskillSchematics:OnBottomItemUncheck(wndhandler, wndControl)
	self.wndMain:FindChild("RightSide"):Show(false)
	self:RedrawFromUI()
end

function TradeskillSchematics:OnBottomItemCheck(wndHandler, wndControl) -- BottomItemBtn, data is tSchematic
	-- Search and View All both use this UI button
	if self.wndLastBottomItemBtnBlue then -- TODO HACK
		self.wndLastBottomItemBtnBlue:SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
	end

	local tSchematicInfo = CraftingLib.GetSchematicInfo(wndHandler:GetData().nSchematicId)
	local tTradeskillInfo = CraftingLib.GetTradeskillInfo(tSchematicInfo.eTradeskillId)
	self.bCoordCraft = tTradeskillInfo.bIsCoordinateCrafting

	self:DrawSchematic(wndHandler:GetData())
	self:OnTimerCraftingStationCheck()
end

function TradeskillSchematics:OnFiltersChanged(wndHandler, wndControl)
	self.wndMain:FindChild("LeftSideRefreshAnimation"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self.wndMain:FindChild("LeftSideScroll"):DestroyChildren()

	self.tSavedData.bFilterLocked = self.wndMain:FindChild("LeftSideFilterLocked"):IsChecked()
	self.tSavedData.bFilterMats = self.wndMain:FindChild("LeftSideFilterMaterials"):IsChecked()
	if self.wndMain:FindChild("SearchTopLeftInputBox"):GetText() ~= "" then
		self:OnSearchTopLeftInputBoxChanged()--reset the search results to use filters
	end
	self:FullRedraw()
	self.wndMain:FindChild("LeftSideScroll"):SetVScrollPos(0)
end

-----------------------------------------------------------------------------------------------
-- Schematics
-----------------------------------------------------------------------------------------------

function TradeskillSchematics:DrawSchematic(tSchematic)
	local tSchematicInfo = CraftingLib.GetSchematicInfo(tSchematic.nSchematicId)
	local wndSchem = self.wndMain:FindChild("RightSide")

	if not tSchematicInfo or not wndSchem then
		return
	end

	-- Source Achievement
	local achSource = tSchematicInfo.achSource
	if achSource then
		local bComplete = achSource:IsComplete()
		local nNumNeeded = achSource:GetNumNeeded()
		local nNumCompleted = bComplete and nNumNeeded or achSource:GetNumCompleted()

		if nNumNeeded == 0 and achSource:IsChecklist() then
			local tChecklistItems = achSource:GetChecklistItems()
			nNumNeeded = #tChecklistItems
			nNumCompleted = 0
			for idx, tData in ipairs(achSource:GetChecklistItems()) do
				if tData.schematicId and tData.isComplete then
					nNumCompleted = nNumCompleted + 1
				end
			end
		end

		wndSchem:FindChild("LockedLinkCheckmark"):Show(bComplete)
		wndSchem:FindChild("LockedLinkProgBar"):SetMax(nNumNeeded)
		wndSchem:FindChild("LockedLinkProgBar"):SetProgress(nNumCompleted)
		wndSchem:FindChild("LockedLinkProgBar"):EnableGlow(nNumCompleted > 0 and not bComplete)
		wndSchem:FindChild("LockedLinkBtn"):SetData(achSource)
		wndSchem:FindChild("LockedLinkProgText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), nNumCompleted, nNumNeeded))
	end
	wndSchem:FindChild("LockedLinkBtn"):Show(achSource and not tSchematic.bIsKnown and not tSchematic.bIsAutoLearn)

	-- Materials
	local bHaveEnoughMats = true
	local nNumCraftable = 9000
	wndSchem:FindChild("MaterialsScroll"):DestroyChildren()
	for key, tMaterial in pairs(tSchematicInfo.tMaterials) do
		if tMaterial.nAmount > 0 then
			local wndMaterial = Apollo.LoadForm(self.xmlDoc, "MaterialsItem", wndSchem:FindChild("MaterialsScroll"), self)
			local nOwnedCount = tMaterial.itemMaterial:GetBackpackCount() + tMaterial.itemMaterial:GetBankCount()
			wndMaterial:FindChild("MaterialsIcon"):SetSprite(tMaterial.itemMaterial:GetIcon())
			wndMaterial:FindChild("MaterialsName"):SetText(tMaterial.itemMaterial:GetName())
			wndMaterial:FindChild("MaterialsIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), nOwnedCount, tMaterial.nAmount))
			wndMaterial:FindChild("MaterialsIconNotEnough"):Show(nOwnedCount < tMaterial.nAmount)
			self:HelperBuildItemTooltip(wndMaterial, tMaterial.itemMaterial)

			nNumCraftable = math.min(nNumCraftable, math.floor(nOwnedCount / tMaterial.nAmount))
			bHaveEnoughMats = bHaveEnoughMats and nOwnedCount >= tMaterial.nAmount
		end
	end

	-- Fake Material (Power Cores)
	if not self.bCoordCraft then
		local tAvailableCores = CraftingLib.GetAvailablePowerCores(tSchematic.nSchematicId)
		if tAvailableCores then -- Some crafts won't have power cores
			local wndMaterial = Apollo.LoadForm(self.xmlDoc, "MaterialsItem", wndSchem:FindChild("MaterialsScroll"), self)
			local nBackpackCount = 0
			for idx, itemMaterial in pairs(tAvailableCores) do
				nBackpackCount = nBackpackCount + itemMaterial:GetStackCount() -- Makes sense to not include Power Cores in bank
			end

			local strPowerCore = Apollo.GetString("CBCrafting_PowerCore")
			if karPowerCoreTierToString[tSchematicInfo.eTier] then
				strPowerCore = String_GetWeaselString(Apollo.GetString("Tradeskills_AnyPowerCore"), karPowerCoreTierToString[tSchematicInfo.eTier])
			end

			wndMaterial:FindChild("MaterialsIcon"):SetSprite("Icon_CraftingUI_Item_Crafting_PowerCore_Green")
			wndMaterial:FindChild("MaterialsIcon"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), nBackpackCount, "1"))
			wndMaterial:FindChild("MaterialsName"):SetText(strPowerCore)
			wndMaterial:FindChild("MaterialsIconNotEnough"):Show(nBackpackCount < 1)
			wndMaterial:SetTooltip(Apollo.GetString("CBCrafting_PowerCoreHelperTooltip"))
			nNumCraftable = math.min(nNumCraftable, nBackpackCount)
		end
	end

	local bIsCooking = tSchematicInfo.eTradeskillId == CraftingLib.CodeEnumTradeskill.Cooking
	wndSchem:Show(true)
	wndSchem:SetData(tSchematic)
	wndSchem:FindChild("SchematicIcon"):SetData(tSchematicInfo.itemOutput) -- GOTCHA: RightBottomCraftBtn can be enabled with no mats, it just goes to a preview screen
	wndSchem:FindChild("RightBottomCraftBtn"):SetData(tSchematic.nSchematicId) -- This is also updated on OnTimerCraftingStationCheck based on RightBottomCraftPreview
	wndSchem:FindChild("RightBottomSimpleCraftBtn"):SetData(tSchematic.nSchematicId) -- This is also updated on OnTimerCraftingStationCheck based on RightBottomCraftPreview
	wndSchem:FindChild("RightBottomSimpleCraftBtn"):Enable(bHaveEnoughMats and (tSchematic.bIsKnown or tSchematic.bIsOneUse))

	wndSchem:FindChild("SchematicName"):SetText(tSchematicInfo.strName)
	wndSchem:FindChild("SchematicIcon"):SetSprite(tSchematicInfo.itemOutput:GetIcon())
	wndSchem:FindChild("SchematicIcon"):SetText(tSchematicInfo.nCreateCount <= 1 and "" or tSchematicInfo.nCreateCount)
	wndSchem:FindChild("RightCookingMessage"):Show(not tSchematic.bIsKnown and bIsCooking)
	wndSchem:FindChild("SchematicIconLockBG"):Show(not tSchematic.bIsKnown and not tSchematic.bIsOneUse)
	wndSchem:FindChild("RightNoLinkMessage"):Show(not tSchematic.bIsKnown and not tSchematic.bIsAutoLearn and not bIsCooking and not achSource)
	self:HelperBuildItemTooltip(wndSchem:FindChild("SchematicIcon"), tSchematicInfo.itemOutput)

	-- Three line text
	local nRequiredLevel = tSchematicInfo.itemOutput:GetRequiredLevel()
	local strRequiredLevelAppend = nRequiredLevel == 0 and "" or (String_GetWeaselString(Apollo.GetString("Tradeskills_RequiredLevel"), nRequiredLevel) .." \n")
	local strNumCraftable = nNumCraftable == 0 and "" or String_GetWeaselString(Apollo.GetString("Tradeskills_MaterialsForX"), nNumCraftable)
	wndSchem:FindChild("SchematicItemType"):SetText(tSchematic.strItemTypeName.." \n"..strRequiredLevelAppend..strNumCraftable)

	-- TODO: Resize depending if there are Subrecipes
	local nLeft, nTop, nRight, nBottom = wndSchem:FindChild("RightTopBG"):GetAnchorOffsets()
	wndSchem:FindChild("RightTopBG"):SetAnchorOffsets(nLeft, nTop, nRight, #tSchematicInfo.tSubRecipes > 0 and 310 or 480) -- TODO: SUPER HARDCODED FORMATTING

	-- Subrecipes
	wndSchem:FindChild("RightSubrecipes"):Show(#tSchematicInfo.tSubRecipes > 0)
	wndSchem:FindChild("SubrecipesListScroll"):DestroyChildren()

	for key, tSubrecipe in pairs(tSchematicInfo.tSubRecipes) do
		local tSubrecipeInfo = CraftingLib.GetSchematicInfo(tSubrecipe.nSchematicId)
		local wndSubrecipe = Apollo.LoadForm(self.xmlDoc, "SubrecipesItem", wndSchem:FindChild("SubrecipesListScroll"), self)
		local wndSubrecipesLeftName = wndSubrecipe:FindChild("SubrecipesLeftName")
		wndSubrecipe:FindChild("SubrecipesLeftDiscoverableBG"):Show(not tSubrecipe.bIsKnown and tSubrecipe.bIsUndiscovered)
		wndSubrecipe:FindChild("SubrecipesLeftLockedBG"):Show(not tSubrecipe.bIsKnown and not tSubrecipe.bIsUndiscovered)
		wndSubrecipe:FindChild("SubrecipesLeftIcon"):SetSprite(tSubrecipe.itemOutput:GetIcon())
		wndSubrecipe:FindChild("SubrecipesLeftIcon"):SetText(tSubrecipeInfo.nCreateCount <= 1 and "" or tSubrecipeInfo.nCreateCount)
		wndSubrecipe:FindChild("SubrecipesLeftName"):SetText(tSubrecipe.itemOutput:GetName())
		wndSubrecipesLeftName:SetAML(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</P>", tSubrecipe.itemOutput:GetName()))
		local nLeftRecipe, nTopRecipe, nRightRecipe, nBottomRecipe = wndSubrecipesLeftName:GetAnchorOffsets()
		wndSubrecipesLeftName:SetHeightToContentHeight()

		if wndSubrecipesLeftName:GetHeight() >= 47 then -- 47 is height of ~2 lines
			wndSubrecipesLeftName:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">%s</P>", tSubrecipe.itemOutput:GetName()))
			wndSubrecipesLeftName:SetAnchorOffsets(nLeftRecipe, nTopRecipe, nRightRecipe, 47)
		else
			wndSubrecipesLeftName:SetAML(string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</P>", tSubrecipe.itemOutput:GetName()))
		end

		wndSubrecipe:FindChild("SubrecipesLeftNameVertContainer"):ArrangeChildrenVert(1)

		self:HelperBuildItemTooltip(wndSubrecipe, tSubrecipe.itemOutput)
		-- TODO SubrecipesRight for Critical Successes
	end

	wndSchem:FindChild("MaterialsScroll"):ArrangeChildrenTiles(0)
	wndSchem:FindChild("SubrecipesListScroll"):ArrangeChildrenTiles(0)
end

function TradeskillSchematics:OnLockedLinkBtn(wndHandler, wndControl) -- LockedLinkBtn, data is achSource
	Event_FireGenericEvent("GenericEvent_OpenToSpecificTechTree", wndHandler:GetData())
end

function TradeskillSchematics:OnRightBottomCraftBtn(wndHandler, wndControl) -- RightBottomCraftBtn, data is tSchematicId
	Event_FireGenericEvent("GenericEvent_CraftFromPL", wndHandler:GetData())
	Event_FireGenericEvent("AlwaysHideTradeskills")
end

function TradeskillSchematics:OnRightBottomSimpleCraftBtn(wndHandler, wndControl) -- RightBottomSimpleCraftBtn, data is tSchematicId
	local nSimpleCraftId = wndHandler:GetData()
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	if tCurrentCraft and tCurrentCraft.nSchematicId ~= 0 then
		Event_FireGenericEvent("GenericEvent_CraftFromPL", nSimpleCraftId)
	else
		-- Order is important, must clear first
		Event_FireGenericEvent("GenericEvent_ClearCraftSummary")

		-- Count materials
		local tSchematicInfo = CraftingLib.GetSchematicInfo(nSimpleCraftId)
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

		CraftingLib.CraftItem(nSimpleCraftId)
	end
	Event_FireGenericEvent("AlwaysHideTradeskills")
end

-----------------------------------------------------------------------------------------------
-- Search
-----------------------------------------------------------------------------------------------

function TradeskillSchematics:ClearSearchBoxFocus(wndHandler, wndControl)
	wndHandler:SetFocus()
end

function TradeskillSchematics:OnSearchTopLeftClearBtn(wndHandler, wndControl)
	self.wndMain:FindChild("SearchTopLeftInputBox"):SetText("")
	self:OnSearchTopLeftInputBoxChanged(self.wndMain:FindChild("SearchTopLeftInputBox"), self.wndMain:FindChild("SearchTopLeftInputBox"))
	wndHandler:SetFocus() -- Focus on close button to steal focus from input
end

function TradeskillSchematics:OnSearchTopLeftInputBoxChanged() -- Also called in Lua
	local strInput = self.wndMain:FindChild("SearchTopLeftInputBox"):GetText():lower()
	local bInputExists = string.len(strInput) > 1

	self.wndMain:FindChild("LeftSideSearch"):Show(bInputExists)
	self.wndMain:FindChild("SearchTopLeftClearBtn"):Show(bInputExists)
	self.wndMain:FindChild("LeftSideSearchResultsList"):DestroyChildren()

	if not bInputExists then
		return
	end

	-- Search
	-- All Tradeskills -> All Schematics -> If Valid Schematics (hobby or right tier) then Draw Result
	for idx, tCurrTradeskill in ipairs(CraftingLib.GetKnownTradeskills()) do
		if tCurrTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Runecrafting then
			local tCurrTradeskillInfo = CraftingLib.GetTradeskillInfo(tCurrTradeskill.eId)
			for idx2, tSchematic in pairs(CraftingLib.GetSchematicList(tCurrTradeskill.eId, nil, nil, true)) do
				if tCurrTradeskillInfo.bIsActive and (tCurrTradeskillInfo.bIsHobby or tCurrTradeskillInfo.eTier >= tSchematic.eTier) then
					self:HelperSearchBuildResult(self:HelperSearchNameMatch(tSchematic, strInput), nil)
					for idx3, tSubSchem in pairs(self:HelperSearchSubschemNameMatch(tSchematic, strInput)) do
						self:HelperSearchBuildResult(tSchematic, tSubSchem)
					end
				end
			end
		end
	end

	local bNoResults = #self.wndMain:FindChild("LeftSideSearchResultsList"):GetChildren() == 0
	local strEmptyMessage = ""
	if bNoResults and (self.wndMain:FindChild("LeftSideFilterMaterials"):IsChecked() or not self.wndMain:FindChild("LeftSideFilterLocked"):IsChecked()) then
		strEmptyMessage = Apollo.GetString("Tradeskills_NoResultsFilter")
	elseif bNoResults then
		strEmptyMessage = Apollo.GetString("Tradeskills_NoResults")
	end
	self.wndMain:FindChild("LeftSideSearchResultsList"):SetText(strEmptyMessage)
	self.wndMain:FindChild("LeftSideSearchResultsList"):ArrangeChildrenVert(0)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function TradeskillSchematics:OnSchematicIconMouseUp(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndHandler:GetData() then
		Event_FireGenericEvent("GenericEvent_ContextMenuItem", wndHandler:GetData())
	end
end

function TradeskillSchematics:HelperHaveEnoughMaterials(tSchematic)
	local bValidOneUse = true
	local bHasEnoughMaterials = true

	-- Materials
	local tSchematicInfo = CraftingLib.GetSchematicInfo(tSchematic.nSchematicId)
	for key, tMaterial in pairs(tSchematicInfo.tMaterials) do
		local nOwnedCount = tMaterial.itemMaterial:GetBackpackCount() + tMaterial.itemMaterial:GetBankCount()
		if nOwnedCount < tMaterial.nAmount then
			bHasEnoughMaterials = false
		end
	end

	-- Fake Material
	if not self.bCoordCraft then
		local tAvailableCores = CraftingLib.GetAvailablePowerCores(tSchematic.nSchematicId)
		if tAvailableCores then -- Some crafts won't have power cores
			local nBackpackCount = 0
			for idx, tMaterial in pairs(tAvailableCores) do
				nBackpackCount = nBackpackCount + tMaterial:GetBackpackCount() -- Makes sense to not include Power Cores in bank
			end
			if nBackpackCount < 1 then
				bHasEnoughMaterials = false
			end
		end
	end

	-- One Use
	if tSchematic.bIsOneUse then
		local tFirstMat = tSchematicInfo.tMaterials[1] -- GOTCHA: Design has assured the recipe is always the first
		bValidOneUse = (tFirstMat.itemMaterial:GetBackpackCount() + tFirstMat.itemMaterial:GetBankCount()) >= tFirstMat.nAmount
	end

	return bHasEnoughMaterials, bValidOneUse
end

function TradeskillSchematics:HelperSearchBuildResult(tSchematic, tSubSchem) -- 2nd arg optional
	if not tSchematic then
		return
	end

	local tSchematicToUse = tSubSchem and tSubSchem or tSchematic
	local bShowLock = not tSchematicToUse.bIsKnown
	local bShowMatsWarning = not bShowLock and not self:HelperHaveEnoughMaterials(tSchematicToUse)
	local bOneTime = not bShowLock and not bShowMatsWarning and tSchematicToUse.bIsOneUse

	-- Helper will determine if the schematic should be included in the results
	local bAddSchematic = self:HelperTestSchematic(tSchematicToUse)
	if bAddSchematic then
		local wndBottomItem = self:LoadByName("BottomItem", self.wndMain:FindChild("LeftSideSearchResultsList"), tSchematicToUse.strName..tSchematicToUse.nSchematicId)
		wndBottomItem:FindChild("BottomItemBtn"):SetData(tSchematic) -- GOTCHA: The Button will intentionally always open the parent schematic
		wndBottomItem:FindChild("BottomItemLockIcon"):Show(bShowLock)
		wndBottomItem:FindChild("BottomItemOneTimeIcon"):Show(bOneTime)
		wndBottomItem:FindChild("BottomItemMatsWarningIcon"):Show(bShowMatsWarning)
		wndBottomItem:FindChild("BottomItemBtn"):SetText(tSubSchem and String_GetWeaselString(Apollo.GetString("Tradeskills_SubAbrev"), tSubSchem.strName) or tSchematic.strName)
		if Apollo.GetTextWidth("CRB_InterfaceMedium_B", wndBottomItem:FindChild("BottomItemBtn"):GetText()) > wndBottomItem:FindChild("BottomItemBtn"):GetWidth() then -- TODO QUICK HACK
			local nBottomLeft, nBottomTop, nBottomRight, nBottomBottom = wndBottomItem:GetAnchorOffsets()
			wndBottomItem:SetAnchorOffsets(nBottomLeft, nBottomTop, nBottomRight, nBottomTop + (self.knBottomLevelHeight * 1.5))
		end

	end
end

function TradeskillSchematics:HelperTestSchematic(tSchematicToUse)
	local bFilterLocked = self.wndMain:FindChild("LeftSideFilterLocked"):IsChecked()
	local bFilterMaterials = self.wndMain:FindChild("LeftSideFilterMaterials"):IsChecked()
	if not bFilterLocked and not bFilterMaterials then --neither filter buttons are pressed
		return tSchematicToUse.bIsKnown

	elseif not bFilterLocked and bFilterMaterials then --only have materials is pressed
		return tSchematicToUse.bIsKnown and self:HelperHaveEnoughMaterials(tSchematicToUse)

	elseif bFilterLocked and not bFilterMaterials then --only show locked is pressed
		return true --show everything

	elseif bFilterLocked and bFilterMaterials then --both filter buttons are pressed
		return self:HelperHaveEnoughMaterials(tSchematicToUse)
	end
end

function TradeskillSchematics:HelperSearchNameMatch(tSchematic, strInput) -- strInput already :lower()
	local strBase = tSchematic.strName
	if strBase:lower():find(strInput, 1, true) then
		return tSchematic
	else
		return false
	end
end

function TradeskillSchematics:HelperSearchSubschemNameMatch(tSchematic, strInput) -- strInput already :lower()
	local tResult = {}
	for key, tSubrecipe in pairs(tSchematic.tSubRecipes or {}) do
		if tSubrecipe.strName:lower():find(strInput, 1, true) then
			table.insert(tResult, tSubrecipe)
		end
	end
	return tResult
end

function TradeskillSchematics:HelperBuildItemTooltip(wndArg, itemCurr)
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemCurr:GetEquippedItemForItemType()})
end

function TradeskillSchematics:LoadByName(strForm, wndParent, strCustomName)
	local wndNew = wndParent:FindChild(strCustomName)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strForm, wndParent, self)
		wndNew:SetName(strCustomName)
	end
	return wndNew
end

local TradeskillSchematicsInst = TradeskillSchematics:new()
TradeskillSchematicsInst:Init()
