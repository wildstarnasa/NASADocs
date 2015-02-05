-----------------------------------------------------------------------------------------------
-- Client Lua Script for TradeskillTree
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CraftingLib"
require "AchievementsLib"

local TradeskillTree = {}
local knMaxCols = 9
local knXpOffset = 29
local kstrArrow = "arrow"
local kstrSpriteTalentPoint = "ClientSprites:ComboStarFull"

function TradeskillTree:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	o.tDrawnAchievements = {}
    return o
end

function TradeskillTree:Init()
    Apollo.RegisterAddon(self, false, "", {"ToolTips"})
end

function TradeskillTree:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TradeskillTree.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function TradeskillTree:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

    Apollo.RegisterEventHandler("GenericEvent_InitializeAchievementTree", "Initialize", self)
	Apollo.RegisterEventHandler("ProfessionAchievementUpdated", "OnProfessionAchievementUpdated", self)
end

function TradeskillTree:OnProfessionAchievementUpdated(achUpdated)
	if self.tDrawnAchievements[achUpdated:GetId()] ~= nil then
		self:FullRedraw(nil) -- Intentionally nil to not change the selection
	end
end

function TradeskillTree:Initialize(wndParent, achievementData)
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "TradeskillTreeForm", wndParent, self)
		self.nLeftScroll, self.nTopScroll, self.nRightScroll, self.nBottomScroll = self.wndMain:FindChild("TradeskillTreeScroll"):GetAnchorOffsets()
		self.nLeftContainer, self.nTopContainer, self.nRightContainer, self.nBottomContainer = self.wndMain:FindChild("OriginPieceContainer"):GetAnchorOffsets()

		self.wndGrid = self.wndMain:FindChild("FullGrid") -- Note there is a Hackish mirrored version called "HAMLayer" which was originally this (in order to turn off noclip)
		self.wndExtraInfoScreen = nil -- "ExtraInfoScreen"

		local wndHeight = Apollo.LoadForm(self.xmlDoc, "ExtraInfoScreen", wndParent, self)
		self.knExtraInfoSchemHeight = wndHeight:FindChild("ExtraInfoSchemArt"):GetHeight()
		self.knExtraInfoRewardHeight = wndHeight:FindChild("ExtraInfoRewardArt"):GetHeight()
		wndHeight:Destroy()

		self.knHAMvsGridWidth = self.wndMain:FindChild("HAMLayer"):GetWidth() - self.wndMain:FindChild("FullGrid"):GetWidth()
		self.knHAMvsGridHeight = self.wndMain:FindChild("HAMLayer"):GetHeight() - self.wndMain:FindChild("FullGrid"):GetHeight()

		self.wndMain:FindChild("OriginPieceDropdownBtn"):AttachWindow(self.wndMain:FindChild("OriginPieceDropdownArt")) -- TODO TEMP
	end

	self:FullRedraw(achievementData)
end

function TradeskillTree:FullRedraw(achievementData)
	local tXpProgress = self:DrawDropdownPicker(achievementData)

	local nCurrentSelection = self.wndMain:FindChild("OriginPieceDropdownBtn"):GetData()
	if not nCurrentSelection then
		return
	end

	if tXpProgress[nCurrentSelection] then
		local nCurr = tXpProgress[nCurrentSelection].nXp or 0
		local nMax = tXpProgress[nCurrentSelection].nXpForNextTier or 1
		local strPercent = String_GetWeaselString(Apollo.GetString("CRB_Percent"), nCurr / nMax * 100)
		local strTradeSkill = tXpProgress[nCurrentSelection].strName .. " " .. strPercent
		local strXPValue = string.format("%s / %s", Apollo.FormatNumber(nCurr, 0, true), Apollo.FormatNumber(nMax, 0, true))

		self.wndMain:FindChild("TradeSkillValue"):SetText(strTradeSkill)
		self.wndMain:FindChild("XpValue"):SetText(strXPValue)
		self.wndMain:FindChild("XPBarFill"):SetMax(nMax)
		self.wndMain:FindChild("XPBarFill"):SetProgress(nCurr)

		self.wndMain:FindChild("XPBarContainer"):Show(true)
		self.wndMain:FindChild("Divider"):Show(true)
		self.wndMain:FindChild("TradeskillTreeScroll"):SetAnchorOffsets(self.nLeftScroll, self.nTopScroll + knXpOffset, self.nRightScroll, self.nBottomScroll)
		self.wndMain:FindChild("OriginPieceContainer"):SetAnchorOffsets(self.nLeftContainer, self.nTopContainer + knXpOffset, self.nRightContainer, self.nBottomContainer)
	else
		self.wndMain:FindChild("Divider"):Show(false)
		self.wndMain:FindChild("XPBarContainer"):Show(false)
		self.wndMain:FindChild("TradeskillTreeScroll"):SetAnchorOffsets(self.nLeftScroll, self.nTopScroll, self.nRightScroll, self.nBottomScroll)
		self.wndMain:FindChild("OriginPieceContainer"):SetAnchorOffsets(self.nLeftContainer, self.nTopContainer, self.nRightContainer, self.nBottomContainer)
	end

	-- Calculate max rows
	self.wndGrid:DestroyChildren() -- TODO: Remove
	self.wndMain:FindChild("HAMLayer"):DestroyChildren() -- TODO: Remove
	local nRows = 0
	for key, tCurrAchieve in pairs(AchievementsLib.GetTradeskillAchievementLayout(nCurrentSelection)) do
		local tPos = tCurrAchieve:GetTradeskillLayout()
		if tPos.y > nRows then
			nRows = tPos.y
		end
	end

	for nY = 1, (nRows + 1) do
		for nX = 1, knMaxCols do
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "GridSquare", self.wndGrid, self)
			wndCurr:SetData(nY * knMaxCols + nX)
		end
	end
	self.wndGrid:ArrangeChildrenTiles(1)

	self:SlotHAMs(nCurrentSelection, achievementData)
	self:PickAllArrowGraphics(nRows)

	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("TradeskillTreeContainer"):GetAnchorOffsets()
	self.wndMain:FindChild("TradeskillTreeContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + 169 + (nRows * 80)) -- TODO: TEMP hardcoded
	self.wndMain:FindChild("TradeskillTreeScroll"):RecalculateContentExtents()

	if self.wndExtraInfoScreen and self.wndExtraInfoScreen:IsValid() then
		self:OnHAMItemBtnShowExtraInfo(self.wndExtraInfoScreen:GetData(), self.wndExtraInfoScreen:GetData())
	end
end

function TradeskillTree:DrawDropdownPicker(achievementData)
	local tXpProgress = {}
	self.wndMain:FindChild("OriginPieceDropdownContainer"):DestroyChildren()

	for idx, tCurrTradeskill in ipairs(CraftingLib.GetKnownTradeskills()) do
		local tCurrInfo = CraftingLib.GetTradeskillInfo(tCurrTradeskill.eId)
		if tCurrInfo.bIsActive and tCurrTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Farmer and tCurrTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Runecrafting then
			-- Header
			local strTradeskillName = tCurrInfo.bIsHobby and Apollo.GetString("Tradeskills_Hobby") or tCurrTradeskill.strName
			local wndHeader = self:FactoryProduce(self.wndMain:FindChild("OriginPieceDropdownContainer"), "OriginPieceDropdownHeader", strTradeskillName)
			wndHeader:FindChild("OriginPieceDropdownHeaderText"):SetText(tCurrInfo.nXp < tCurrInfo.nXpForNextTier and
			string.format("%s (%s/%s XP)", strTradeskillName, Apollo.FormatNumber(tCurrInfo.nXp, 0, true), Apollo.FormatNumber(tCurrInfo.nXpForNextTier, 0, true)) or strTradeskillName)

			-- Header items
			if not tCurrInfo.bIsHarvesting then -- harvesting check is later to show the XP
				local tMiddleCategories = AchievementsLib.GetTradeskillAchievementCategoryTree(tCurrTradeskill.eId)
				if tMiddleCategories and tMiddleCategories.tSubGroups then
					for idx2, tCategory in pairs(tMiddleCategories.tSubGroups) do
						if tCurrInfo.nXpForNextTier > 0 then
							tXpProgress[tCategory.nSubGroupId] = tCurrInfo
						end

						local wndCurr = self:FactoryProduce(self.wndMain:FindChild("OriginPieceDropdownContainer"), "OriginPieceDropdownListItem", tCategory.nSubGroupId)
						if wndCurr and wndCurr:FindChild("OriginPieceDropdownListItemBtn") then
							wndCurr:FindChild("OriginPieceDropdownListItemBtn"):SetData(tCategory.nSubGroupId)
							wndCurr:FindChild("OriginPieceDropdownListLockIcon"):Show(idx2 > tCurrInfo.eTier)
							wndCurr:FindChild("OriginPieceDropdownListItemText"):SetText(tCategory.strSubGroupName)
							wndCurr:FindChild("OriginPieceDropdownListItemText"):SetData(tCategory.strSubGroupName)
						end
					end
				end
			end
		end
	end
	self.wndMain:FindChild("OriginPieceDropdownContainer"):ArrangeChildrenVert(0)

	-- Default pick the one we're told to show, else the 2nd item in the list if nothing has been selected yet
	local wndFirstItem = nil
	if achievementData and achievementData:GetCategoryId() then
		wndFirstItem = self.wndMain:FindChild("OriginPieceDropdownContainer"):FindChildByUserData(achievementData:GetCategoryId())
	elseif not self.wndMain:FindChild("OriginPieceDropdownBtn"):GetData() then
		wndFirstItem = self.wndMain:FindChild("OriginPieceDropdownContainer"):GetChildren()[2]
	end

	if wndFirstItem and wndFirstItem:IsValid() then
		self:OnOriginPieceItemBtnClick(wndFirstItem:FindChild("OriginPieceDropdownListItemBtn"), wndFirstItem:FindChild("OriginPieceDropdownListItemBtn"))
	end

	return tXpProgress
end

function TradeskillTree:OnOriginPieceItemBtnClick(wndHandler, wndControl) -- wndHandler is "OriginPieceDropdownListItemBtn" and its data is tCategory.id
	if not wndHandler or wndHandler ~= wndControl then
		return
	end

	self.wndMain:FindChild("TradeskillTreeScroll"):SetVScrollPos(0)
	self.wndMain:FindChild("OriginPieceDropdownBtnText"):SetText(wndHandler:FindChild("OriginPieceDropdownListItemText"):GetData())
	self.wndMain:FindChild("OriginPieceDropdownBtn"):SetData(wndHandler:GetData())
	self.wndMain:FindChild("OriginPieceDropdownArt"):Close()
	self.wndMain:FindChild("OriginPieceAccent"):Show(true)
	self:FullRedraw(nil) -- Intentionally nil to not change the selection
end

function TradeskillTree:SlotHAMs(nCurrentSelection, achievementData)
	self.tDrawnAchievements = {}

	for idx, achCurr in pairs(AchievementsLib.GetTradeskillAchievementLayout(nCurrentSelection)) do
		self.tDrawnAchievements[achCurr:GetId()] = true

		local tPos = achCurr:GetTradeskillLayout()
		local wndGridItem = self.wndGrid:FindChildByUserData(tPos.y * knMaxCols + tPos.x)
		wndGridItem:SetText(achCurr:GetName()) -- Behind the scenes: Set text as name (for arrow calculation) but load HAM windows into a different layer

		-- For each parent, draw arrows now
		local arParents = tPos.arParents
		for idx2, tCurr in pairs(arParents) do
			self:TreeHelperDrawArrowsToParent(tPos.x, tPos.y, tCurr.x, tCurr.y)
		end

		-- Insert
		local wndHAM = Apollo.LoadForm(self.xmlDoc, "HAMItemBtn", self.wndMain:FindChild("HAMLayer"), self)
		wndHAM:SetData({achCurr, wndGridItem})
		wndHAM:FindChild("ItemTitle"):SetText(achCurr:GetName())

		-- Position (Hackish)
		local nLeft, nTop, nRight, nBottom = wndGridItem:GetAnchorOffsets()
		local nLeft2, nTop2, nRight2, nBottom2 = wndHAM:GetAnchorOffsets()
		wndHAM:SetAnchorOffsets(nLeft + nLeft2 + self.knHAMvsGridWidth / 2, nTop + nTop2 + self.knHAMvsGridHeight, nLeft + nRight2 + self.knHAMvsGridWidth / 2, nTop + nBottom2 + self.knHAMvsGridHeight)

		-- Progress
		local nNumNeeded = achCurr:GetNumNeeded()
		local nNumCompleted = achCurr:GetNumCompleted()

		if nNumNeeded == 0 and achCurr:IsChecklist() then
			local tChecklistItems = achCurr:GetChecklistItems()
			nNumNeeded = #tChecklistItems
			nNumCompleted = 0
			for idx, tData in ipairs(tChecklistItems) do
				if tData.idSchematic and tData.bIsComplete then
					nNumCompleted = nNumCompleted + 1
				end
			end
		end

		wndHAM:FindChild("ItemProgBar"):SetMax(nNumNeeded)
		wndHAM:FindChild("ItemProgBar"):SetProgress(nNumCompleted)
		wndHAM:FindChild("ItemProgTextCheckmark"):SetText(nNumNeeded > 100 and String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nNumCompleted / nNumNeeded * 100)) or
														(String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nNumCompleted, nNumNeeded)))

		if achCurr:IsComplete() then
			wndHAM:ChangeArt("CRB_TechTree:CRB_TechTree_GreenBtn")
			wndHAM:FindChild("ItemTitle"):SetTextColor(ApolloColor.new("ff80ffb9"))
			wndHAM:FindChild("ItemProgBar"):SetMax(1)
			wndHAM:FindChild("ItemProgBar"):SetProgress(1)
			wndHAM:FindChild("ItemProgTextCheckmark"):SetText("")
			wndHAM:FindChild("ItemProgTextCheckmarkVisual"):SetSprite("CRB_TechTree:CRB_TechTree_ProgCheckmark2")
		elseif not wndHAM:FindChild("HAMItemBtnHasTalentPoint") then -- Implicit not complete
			local tRewards = achCurr:GetTradeskillRewards()
			if tRewards and tRewards.nTalentPoints > 0 then
				Apollo.LoadForm(self.xmlDoc, "HAMItemBtnHasTalentPoint", wndHAM, self)
			end
		end

		if achievementData and achievementData:GetId() == achCurr:GetId() then
			wndHAM:SetCheck(true)
			self:OnHAMItemBtnShowExtraInfo(wndHAM, wndHAM)
			self.wndMain:FindChild("TradeskillTreeScroll"):SetVScrollPos(math.max(0, tPos.y - 2) * 80)
		else
			wndHAM:SetCheck(false)
		end
	end
end

function TradeskillTree:TreeHelperDrawArrowsToParent(nCursorX, nCursorY, nDestinationX, nDestinationY)
	local nTrapped = 0
	while nCursorY > (nDestinationY + 1) and nTrapped < 9000 do
		nTrapped = nTrapped + 1
		nCursorY = nCursorY - 1

		local wndTarget = self.wndGrid:FindChildByUserData(nCursorY * knMaxCols + nCursorX)
		if wndTarget and #wndTarget:GetChildren() > 0 then
			-- TODO: Drawing arrow over a HAM, do nothing
		elseif wndTarget then
			wndTarget:SetText(kstrArrow)
		end
	end

	while (nCursorX > nDestinationX or nCursorX < nDestinationX) and nTrapped < 9000 do
		nTrapped = nTrapped + 1
		if nCursorX > nDestinationX then
			nCursorX = nCursorX - 1
		else
			nCursorX = nCursorX + 1
		end

		local wndTarget = self.wndGrid:FindChildByUserData(nCursorY * knMaxCols + nCursorX)
		if wndTarget and #wndTarget:GetChildren() > 0 then
			-- TODO: Drawing arrow over a HAM, do nothing
		elseif wndTarget then
			wndTarget:SetText(kstrArrow)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- HAM Extra Info
-----------------------------------------------------------------------------------------------

function TradeskillTree:OnHAMItemBtnUncheck(wndHandler, wndControl)
	if self.wndExtraInfoScreen and self.wndExtraInfoScreen:IsValid() and self.wndExtraInfoScreen:IsVisible() then
		self.wndExtraInfoScreen:Destroy()
		self.wndExtraInfoScreen = nil
	end
end

function TradeskillTree:OnExtraInfoScreenWindowClosed() -- Also from code
	if self.wndExtraInfoScreen and self.wndExtraInfoScreen:GetData() then
		self.wndExtraInfoScreen:GetData():SetCheck(false)
	end
	if self.wndExtraInfoScreen then
		self.wndExtraInfoScreen:Destroy()
		self.wndExtraInfoScreen = nil
	end
end

function TradeskillTree:OnHAMItemBtnShowExtraInfo(wndHandler, wndControl) -- Note code can also manually call this with the correct wndHandler
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local wndParent = wndHandler
	local achCurr = wndHandler:GetData()[1]
	local wndGridSquare = wndHandler:GetData()[2]

	if self.wndExtraInfoScreen and self.wndExtraInfoScreen:IsValid() then
		self.wndExtraInfoScreen:Destroy()
		self.wndExtraInfoScreen = nil
	end

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "ExtraInfoScreen", self.wndMain:FindChild("TradeskillTreeScroll"), self)
	self.wndExtraInfoScreen = wndCurr
	wndCurr:SetData(wndParent)

	if wndGridSquare then
		local nLeft, nTop, nRight, nBottom = wndGridSquare:GetAnchorOffsets()
		local nLeft2, nTop2, nRight2, nBottom2 = wndCurr:GetAnchorOffsets()
		wndCurr:SetAnchorOffsets(nLeft + nLeft2, nTop + nTop2, nLeft + nRight2, nTop + nBottom2)
	end

	local strDescription = achCurr:IsComplete() and achCurr:GetDescription() or achCurr:GetProgressText()
	strDescription = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff7fffb9\" Align=\"Center\">" .. strDescription .. "</P>"

	local nNumNeeded = achCurr:GetNumNeeded()
	local nNumCompleted = achCurr:GetNumCompleted()
	if nNumNeeded > 100 then
		strDescription = strDescription .. "<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"ff7fffb9\" Align=\"Center\"> (" .. nNumCompleted .. "/" .. nNumNeeded .. ")</P>"
	end

	if wndParent:FindChild("ItemTitle") and wndParent:FindChild("ItemTitle"):GetData() and string.len(wndParent:FindChild("ItemTitle"):GetData()) > 0 then
		strDescription = strDescription .. wndParent:FindChild("ItemTitle"):GetData()
	end

	wndCurr:FindChild("ExtraInfoDescription"):SetText(strDescription)

	-- Checklist Special formatting TODO TEMP
	local tChecklistTable = {}
	local tSchematicIdList = {}
	if achCurr:IsChecklist() then
		for idx, tData in ipairs(achCurr:GetChecklistItems()) do
			if tData.idSchematic then
				tChecklistTable[tData.idSchematic] = tData.bIsComplete
				tSchematicIdList[tData.idSchematic] = tData.idSchematic
			end
		end
	else
		tSchematicIdList = achCurr:GetTradeskillSchematicsRequired()
	end

	-- Schematic Links
	local bRescanForDuplicates = false
	for key, idLinkSchematic in pairs(tSchematicIdList) do
		wndCurr:FindChild("ExtraInfoSchemArt"):Show(true)
		
		local tSchematicLinkInfo = CraftingLib.GetSchematicInfo(idLinkSchematic)
		if tSchematicLinkInfo then
			local wndSchematicBtn = Apollo.LoadForm(self.xmlDoc, "ExtraInfoSchemItemBtn", wndCurr:FindChild("ExtraInfoSchemContainer"), self)
			wndSchematicBtn:SetData({ tSchematicLinkInfo }) -- For OnExtraInfoSchemItemBtn (GOTCHA: Needs to be a table to interact with FindChildByUserData)
			wndSchematicBtn:FindChild("ExtraInfoSchemItemText"):SetText(tSchematicLinkInfo.strName)
			wndSchematicBtn:FindChild("ExtraInfoSchemItemCheckIcon"):Show(tChecklistTable[idLinkSchematic])

			if tSchematicLinkInfo.bIsOneUse then
				bRescanForDuplicates = true
			end
		end
	end

	-- If there's a OneUse AND something with the same name, pick which one to keep
	if bRescanForDuplicates then
		local tKillList = {}
		local tComparisonList = {}
		for idx, wndCurr in pairs(wndCurr:FindChild("ExtraInfoSchemContainer"):GetChildren()) do
			local tSchematicLinkInfo = wndCurr:GetData()[1]
			if tComparisonList[tSchematicLinkInfo.strName] then -- Have a collision, resolve
				local tCompetitor = tComparisonList[tSchematicLinkInfo.strName].tSchematicLinkInfo
				if tSchematicLinkInfo.bIsOneUse and tCompetitor.bIsKnown then
					table.insert(tKillList, wndCurr)
				elseif tSchematicLinkInfo.bIsKnown and tCompetitor.bIsOneUse then
					table.insert(tKillList, tCompetitor.wndCurr)
				elseif tSchematicLinkInfo.bIsOneUse then
					table.insert(tKillList, wndCurr)
				elseif tCompetitor.bIsOneUse then
					table.insert(tKillList, tCompetitor.wndCurr)
				end
			else
				tComparisonList[tSchematicLinkInfo.strName] = { wndCurr = wndCurr, tSchematicLinkInfo = tSchematicLinkInfo }
			end
		end

		for idx, wndCurr in pairs(tKillList) do
			wndCurr:Destroy()
			wndCurr = nil
		end
	end

	wndCurr:FindChild("ExtraInfoSchemContainer"):ArrangeChildrenVert(0)

	-- Rewards
	local tRewards = achCurr:GetTradeskillRewards()
	if tRewards then
		local nRewards = #tRewards.arSchematics + tRewards.nTalentPoints + #tRewards.arBonuses

		wndCurr:FindChild("ExtraInfoRewardArt"):Show(nRewards > 0)
		wndCurr:FindChild("ExtraInfoRewardTitle"):Show(nRewards > 0)

		for idx, tSchematic in ipairs(tRewards.arSchematics) do
			if tSchematic.itemCrafted then
				local wndReward = Apollo.LoadForm(self.xmlDoc, "ItemReward", wndCurr:FindChild("ExtraInfoRewardContainer"), self)
				wndReward:FindChild("ItemRewardSprite"):SetSprite(tSchematic.itemCrafted:GetIcon())
				self:HelperBuildItemTooltip(wndReward, tSchematic.itemCrafted)
			end
		end

		if tRewards.nTalentPoints > 0 then
			local wndReward = Apollo.LoadForm(self.xmlDoc, "ItemReward", wndCurr:FindChild("ExtraInfoRewardContainer"), self)
			wndReward:FindChild("ItemRewardSprite"):SetText(tRewards.nTalentPoints)
			wndReward:FindChild("ItemRewardSprite"):SetSprite(kstrSpriteTalentPoint)
			wndReward:FindChild("ItemRewardSprite"):SetBGColor(ApolloColor.new("ff31fcf6"))

			local tTalentPointInfo =
			{
				["count"] = tRewards.nTalentPoints,
				["name"] = Apollo.GetString("Tradeskills_TalentPoint")
			}

			wndReward:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall_O\">%s</P>", String_GetWeaselString(Apollo.GetString("CRB_Multiple"), tTalentPointInfo)))
		end

		for idx, tBonus in ipairs(tRewards.arBonuses) do
			local wndReward = Apollo.LoadForm(self.xmlDoc, "ItemReward", wndCurr:FindChild("ExtraInfoRewardContainer"), self)

			local strIcon = tBonus.strIcon
			if string.len(strIcon) == 0 then
				strIcon = "ClientSprites:Icon_ItemMisc_UI_Item_Gears"
			end

			local strName = tBonus.strName
			if string.len(strName) == 0 then
				strName = Apollo.GetString("Tradeskills_TalentPlaceholder")
			end

			wndReward:FindChild("ItemRewardSprite"):SetSprite(strIcon)
			wndReward:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff9aaea3\">%s</P><P Font=\"CRB_InterfaceSmall_O\">%s</P>", strName, tBonus.strTooltip))
		end

		wndCurr:FindChild("ExtraInfoRewardContainer"):ArrangeChildrenHorz(0)
	end

	-- Resize
	local nWidth, nHeight = wndCurr:FindChild("ExtraInfoDescription"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndCurr:FindChild("ExtraInfoDescription"):GetAnchorOffsets()
	nHeight = nHeight + 18 -- Extra padding for below the text
	wndCurr:FindChild("ExtraInfoDescription"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight)

	if wndCurr:FindChild("ExtraInfoSchemArt"):IsShown() then
		nHeight = nHeight + self.knExtraInfoSchemHeight
	end
	if wndCurr:FindChild("ExtraInfoRewardArt"):IsShown() then
		nHeight = nHeight + self.knExtraInfoRewardHeight
	end
	wndCurr:FindChild("ExtraInfoArrangeVert"):ArrangeChildrenVert(0)

	-- If too nHeight is too low, use the smaller version and align it
	if nHeight > 100 then
		local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
		wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + nHeight)
	else
		local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
		wndCurr:SetAnchorOffsets(nLeft, nTop, nLeft + 300, nTop + 125) -- TODO: Hardcoded minimum size

		nLeft, nTop, nRight, nBottom = wndCurr:FindChild("ExtraInfoScreenBG"):GetAnchorOffsets()
		wndCurr:FindChild("ExtraInfoScreenBG"):SetAnchorOffsets(30, 8, nRight, -8) -- TODO: Hardcoded background art
		wndCurr:FindChild("ExtraInfoScreenBG"):SetSprite("kitBase_HoloBlue_PopoutSmall")
	end

	-- Parent button things
	wndParent:AttachWindow(wndCurr)
end

function TradeskillTree:OnExtraInfoSchemItemBtn(wndHandler, wndControl) -- wndHandler is "ExtraInfoSchemItemBtn"
	local tSchematicInfo = wndHandler:GetData()[1]
	if tSchematicInfo and tSchematicInfo.strName then
		Event_FireGenericEvent("GenericEvent_OpenToSearchSchematic", tSchematicInfo.strName)
		self:OnExtraInfoScreenWindowClosed()
	end
end

-----------------------------------------------------------------------------------------------
-- Picking Arrow Graphics
-----------------------------------------------------------------------------------------------

function TradeskillTree:PickAllArrowGraphics(nMaxRows)
	local tArrowsToEvaluate = {}
	for idx, wndCurr in pairs(self.wndGrid:GetChildren()) do -- wndCurr is a "GridSquare"
		if wndCurr:GetText() == kstrArrow then -- GetText() is AchievementName or kstrArrow. GetData() is the position.
			tArrowsToEvaluate[wndCurr:GetData()] = wndCurr
		end
	end

	for nPos, wndCurr in pairs(tArrowsToEvaluate) do
		local wndBelow = self.wndGrid:FindChildByUserData(nPos + 9)
		local wndAbove = self.wndGrid:FindChildByUserData(nPos - 9)
		local wndRight = self.wndGrid:FindChildByUserData(nPos + 1)
		local wndLeft = self.wndGrid:FindChildByUserData(nPos - 1)

		local bAbove = wndAbove and wndAbove:GetText() ~= ""
		local bBelow = wndBelow and wndBelow:GetText() ~= ""
		local bRight = nPos % knMaxCols ~= 0 and wndRight and wndRight:GetText() ~= ""
		local bLeft = (nPos - 1) % knMaxCols ~= 0 and wndLeft and wndLeft:GetText() ~= ""

		--Full Sprite Name: CRB_TechTree_ArrowLTRB
		-- NOTE: Relies on strictly named sprites
		local strText = ""
		if bLeft then
			strText = strText.."L"
		end
		if bAbove then
			strText = strText.."T"
		end
		if bRight then
			strText = strText.."R"
		end
		if bBelow then
			strText = strText.."B"
		end

		-- Special art ones
		if strText == "LB" and bBelow and wndBelow and wndBelow:GetText() ~= kstrArrow then
			strText = strText .. "2"
		end
		if strText == "RB" and bBelow and wndBelow and wndBelow:GetText() ~= kstrArrow then
			strText = strText .. "2"
		end
		if strText == "LT" and bAbove and wndAbove and wndAbove:GetText() ~= kstrArrow then
			strText = strText .. "2"
		end
		if strText == "TR" and bAbove and wndAbove and wndAbove:GetText() ~= kstrArrow then
			strText = strText .. "2"
		end
		wndCurr:SetSprite("CRB_TechTree_Arrow" .. strText)
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function TradeskillTree:HelperBuildItemTooltip(wndArg, itemCurr)
	wndArg:SetTooltipDoc(nil)
	local itemEquipped = itemCurr:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	--if itemEquipped ~= nil then -- OLD
	--	Tooltip.GetItemTooltipForm(self, wndArg, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = itemCurr})
	--end
end

function TradeskillTree:OnGenerateTooltip(wndHandler, wndControl, eType, arg1, arg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemData then
		local itemCurr = arg1
		local itemEquipped = itemCurr:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = self.bVendorOpen, itemCompare = itemEquipped})
	elseif eType == Tooltip.TooltipGenerateType_Reputation or eType == Tooltip.TooltipGenerateType_TradeSkill then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1:GetMoneyString(), CColor.new(1, 1, 1, 1), "CRB_InterfaceMedium")
		wndControl:SetTooltipDoc(xml)
	else
		wndControl:SetTooltipDoc(nil)
	end
end

function TradeskillTree:FactoryProduce(wndParent, strFormName, tObject)
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

local TradeskillTreeInst = TradeskillTree:new()
TradeskillTreeInst:Init()
2="0" x3="0" x4="0" x5="32" y0="0" y1="32" y2="32" y3="32" y4="32" y5="32" Stretchy="1" StateBits="15" Direction="Across"/>
    <AutoButton Name="btn_collapse_Hologram" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_592_112.tga" x0="0" x1="28" x2="28" x3="28" x4="28" x5="28" y0="0" y1="0" y2="0" y3="0" y4="0" y5="29" Stretchy="1" StateBits="15" Direction="Across"/>
    <AutoButton Name="btn_scroll_HologramBarSide" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_658_151.tga" x0="0" x1="7" x2="13" x3="22" x4="29" x5="35" y0="0" y1="0" y2="0" y3="0" y4="0" y5="15" Stretchy="1" StateBits="5" Direction="Across"/>
    <AutoButton Name="btn_scrollBarSide" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_439_151.tga" x0="0" x1="5" x2="10" x3="22" x4="26" x5="32" y0="0" y1="0" y2="0" y3="0" y4="0" y5="15" Stretchy="1" StateBits="5" Direction="Across"/>
    <AutoButton Name="btn_scrollLeft" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_439_169.tga" x0="0" x1="0" x2="0" x3="0" x4="0" x5="15" y0="0" y1="0" y2="0" y3="0" y4="0" y5="15" Stretchy="1" StateBits="31" Direction="Across"/>
    <AutoButton Name="btn_scrollRight" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_515_169.tga" x0="0" x1="0" x2="0" x3="0" x4="0" x5="15" y0="0" y1="0" y2="0" y3="0" y4="0" y5="15" Stretchy="1" StateBits="31" Direction="Across"/>
    <AutoButton Name="btn_scrollHologramLeft" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_504_151.tga" x0="0" x1="0" x2="0" x3="0" x4="0" x5="15" y0="0" y1="0" y2="0" y3="0" y4="0" y5="15" Stretchy="1" StateBits="31" Direction="Across"/>
    <AutoButton Name="btn_scrollHologramRight" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_581_151.tga" x0="0" x1="0" x2="0" x3="0" x4="0" x5="15" y0="0" y1="0" y2="0" y3="0" y4="0" y5="15" Stretchy="1" StateBits="31" Direction="Across"/>
    <AutoButton Name="btn_hologram" Texture="UI\Assets\TexPieces\UI_CRB_UIKITButtons_633_14