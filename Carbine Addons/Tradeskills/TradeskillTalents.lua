-----------------------------------------------------------------------------------------------
-- Client Lua Script for TradeskillTalents
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local TradeskillTalents = {}

function TradeskillTalents:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TradeskillTalents:Init()
    Apollo.RegisterAddon(self)
end


function TradeskillTalents:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TradeskillTalents.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function TradeskillTalents:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_InitializeTradeskillTalents", "Initialize", self)

	Apollo.RegisterTimerHandler("TradeskillTalents_DelayedRedraw", "OnTradeskillTalents_DelayedRedraw", self)
	Apollo.CreateTimer("TradeskillTalents_DelayedRedraw", 1, false)
	Apollo.StopTimer("TradeskillTalents_DelayedRedraw")
end

function TradeskillTalents:Initialize(wndParent)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "TradeskillTalentsForm", wndParent, self)
	self:BuildTradeskills()
end

function TradeskillTalents:BuildTradeskills()
	local tValidTradeskills = {}
	for idx, tCurrTradeskill in ipairs(CraftingLib.GetKnownTradeskills()) do
		local tCurrInfo = CraftingLib.GetTradeskillInfo(tCurrTradeskill.eId)
		if tCurrInfo.bIsActive and tCurrTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Farmer and tCurrTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Runecrafting then
			table.insert(tValidTradeskills, {tCurrInfo, tCurrTradeskill})
		end
	end

	local tWindowParents = {self.wndMain:FindChild("LeftSide"), self.wndMain:FindChild("MiddleSide"), self.wndMain:FindChild("RightSide")}
	for idx, wndParent in ipairs(tWindowParents) do
		if tValidTradeskills[idx] then
			self:BuildColumn(wndParent, tValidTradeskills[idx])
		end
	end
end

function TradeskillTalents:BuildColumn(wndParent, tData)
	local tCurrInfo = tData[1]
	local tCurrTradeskill = tData[2]

	-- EARLY EXIT: If Harvesting
	wndParent:FindChild("HarvestingMessage"):Show(false)
	if tCurrInfo.bIsHarvesting then
		wndParent:FindChild("HarvestingMessage"):Show(true)
		wndParent:FindChild("HarvestingMessage"):SetText(tCurrInfo.strName)

		-- Harvesting XP
		local tCategoryTree = AchievementsLib.GetTradeskillAchievementCategoryTree(tCurrTradeskill.eId)
		local strTierName = tCategoryTree and tCategoryTree.tSubGroups[tCurrInfo.eTier] or "Tier "..tCurrInfo.eTier -- TODO STRING
		wndParent:FindChild("HarvestingXP"):SetText(String_GetWeaselString(Apollo.GetString("Tradeskills_HarvestingXP"), strTierName, tCurrInfo.nXp, tCurrInfo.nXpForNextTier))
		return
	end

	wndParent:FindChild("TierItemContainer"):DestroyChildren()
	local nNextLevelCost = 0
	local nNextLevelTier = 0
	local tTalentData = CraftingLib.GetTradeskillTalents(tCurrTradeskill.eId)
	for idx, tTierData in pairs(tTalentData) do
		local wndTier = Apollo.LoadForm(self.xmlDoc, "TierItem", wndParent:FindChild("TierItemContainer"), self)
		local strLevel = String_GetWeaselString(Apollo.GetString("Tradeskills_Level"), idx)
		wndTier:FindChild("TierItemCostText"):SetText(strLevel)
		wndTier:FindChild("TierItemCostText"):SetTooltip(String_GetWeaselString(Apollo.GetString("Tradeskills_Achieved"), strLevel))

		if tCurrInfo.nTalentPoints < tTierData.nPointsRequired then
			wndTier:FindChild("TierItemCostText"):SetTextColor(ApolloColor.new("ff5f6662"))
			wndTier:FindChild("TierItemCostText"):SetTooltip(String_GetWeaselString(Apollo.GetString("Tradeskills_PointsNeeded"), tCurrInfo.nTalentPoints, tTierData.nPointsRequired))
			if nNextLevelCost == 0 then
				nNextLevelCost = tTierData.nPointsRequired
				nNextLevelTier = idx
			end
		end

		local bPicked = false
		for idx2, tTalent in pairs(tTierData.tTalents) do
			if tTalent and tTalent.nTalentId then
				local wndTalent = Apollo.LoadForm(self.xmlDoc, "TalentItem", wndTier:FindChild("TalentItemContainer"), self)
				wndTalent:FindChild("TalentItemBtn"):SetData({ idTradeskill = tCurrTradeskill.eId, nLevel = idx, idTalent = tTalent.nTalentId })

				if tCurrInfo.nTalentPoints < tTierData.nPointsRequired then
					wndTalent:FindChild("TalentItemBtn"):Enable(false)
					wndTalent:FindChild("TalentItemBlackFill"):Show(true)
				end

				local strIcon = tTalent.strIcon
				if tTalent.bActive then
					bPicked = true
					strIcon = "ClientSprites:Icon_Windows_UI_CRB_Checkmark"
				elseif string.len(strIcon) == 0 then
					strIcon = "ClientSprites:Icon_ItemMisc_UI_Item_Gears"
				end
				wndTalent:FindChild("TalentItemIcon"):SetSprite(strIcon)

				local strName = Apollo.GetString("Tradeskills_TalentPlaceholder")
				if string.len(tTalent.strName) > 0 then
					strName = tTalent.strName
				end
				wndTalent:FindChild("TalentItemIcon"):SetTooltip(
					string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff9aaea3\">%s</P><P Font=\"CRB_InterfaceSmall_O\">%s</P>", strName, tTalent.strTooltip))
			end
		end

		if bPicked then
			for idx, wndTalent in pairs(wndTier:FindChild("TalentItemContainer"):GetChildren()) do
				wndTalent:FindChild("TalentItemBtn"):Enable(false)
			end
		end
		wndTier:FindChild("TalentItemContainer"):ArrangeChildrenHorz(0)
	end
	wndParent:FindChild("TierItemContainer"):ArrangeChildrenVert(0)

	-- Points available
	local strHeaderText = tCurrInfo.strName
	if tCurrInfo.nTalentPoints > 0 and nNextLevelCost > 0 then
		strHeaderText = String_GetWeaselString(Apollo.GetString("Tradeskills_ToLevel"), tCurrInfo.strName, tCurrInfo.nTalentPoints, nNextLevelCost, nNextLevelTier)
	end
	wndParent:FindChild("HeaderTitle"):SetText(strHeaderText)

	-- Reset Points
	local monRespecCost = CraftingLib.GetTradeskillTalentRespecCost(tCurrTradeskill.eId)
	local eMoneyType = monRespecCost:GetMoneyType()
	local monPlayerCurrencyAmount = GameLib.GetPlayerCurrency(eMoneyType):GetAmount()
	local bCanAffordReset = monRespecCost:GetAmount() <= monPlayerCurrencyAmount
	wndParent:FindChild("ResetPoints"):Show(true)
	wndParent:FindChild("ResetPointsConfirmYes"):SetData(tCurrTradeskill.eId)
	wndParent:FindChild("ResetPointsConfirmNo"):SetData(wndParent:FindChild("ResetPointsConfirmBubble"))
	wndParent:FindChild("ResetPointsConfirmYes"):Enable(bCanAffordReset)
	wndParent:FindChild("ResetPointsCostCashWindow"):SetMoneySystem(eMoneyType)
	wndParent:FindChild("ResetPointsCostCashWindow"):SetAmount(monRespecCost, true)
	wndParent:FindChild("ResetPointsHaveCashWindow"):SetMoneySystem(eMoneyType)
	wndParent:FindChild("ResetPointsHaveCashWindow"):SetAmount(monPlayerCurrencyAmount, true)
	wndParent:FindChild("ResetPointsBtn"):AttachWindow(wndParent:FindChild("ResetPointsConfirmBubble"))
	if bCanAffordReset then
		wndParent:FindChild("ResetPointsCostCashWindow"):SetTextColor(ApolloColor.new("white"))
	else
		wndParent:FindChild("ResetPointsCostCashWindow"):SetTextColor(ApolloColor.new("red"))
	end
end

-----------------------------------------------------------------------------------------------
-- Reset Points
-----------------------------------------------------------------------------------------------

function TradeskillTalents:OnResetPointsConfirmYes(wndHandler, wndControl) -- Parent can be 3 buttons, but data will be tradeskill id
	if wndHandler ~= wndControl or not wndHandler:GetData() then return end
	CraftingLib.ResetTradeskillTalents(wndHandler:GetData())
	Apollo.StartTimer("TradeskillTalents_DelayedRedraw")
end

function TradeskillTalents:OnResetPointsConfirmNo(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:GetData() then
		wndHandler:GetData():Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Learn Talent
-----------------------------------------------------------------------------------------------

function TradeskillTalents:OnTalentItemBtn(wndHandler, wndControl) -- Data is { tCurrTradeskill.id, nTierIdx, tTalentData.talentId }
	if self.wndBubble and self.wndBubble:IsValid() then
		self.wndBubble:Destroy()
	end

	local wndBubble = Apollo.LoadForm(self.xmlDoc, "LearnConfirmBubble", wndHandler, self)
	wndBubble:FindChild("LearnConfirmYes"):SetData(wndBubble)
	wndBubble:FindChild("LearnConfirmNo"):SetData(wndBubble)
	wndBubble:Show(true)
	wndBubble:SetData(wndHandler:GetData()) -- Data is { tCurrTradeskill.id, nTierIdx, tTalentData.talentId }
	self.wndBubble = wndBubble
end

function TradeskillTalents:OnLearnConfirmNo(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:GetData() then
		wndHandler:GetData():Show(false)
	end
end

function TradeskillTalents:OnLearnConfirmYes(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler:GetData() then
		return
	end

	local wndParent = wndHandler:GetData()
	wndParent:Show(false)

	local tData = wndParent:GetData() -- Data is { tCurrTradeskill.id, nTierIdx, tTalentData.talentId }
	CraftingLib.PickTradeskillTalent(tData.idTradeskill, tData.nLevel, tData.idTalent)
	Apollo.StartTimer("TradeskillTalents_DelayedRedraw")
end

function TradeskillTalents:OnTradeskillTalents_DelayedRedraw()
	Apollo.StopTimer("TradeskillTalents_DelayedRedraw")
	if self.wndMain and self.wndMain:IsValid() then
		Event_FireGenericEvent("GenericEvent_InitializeTradeskillTalents", self.wndMain:GetParent())
	end
end

local TradeskillTalentsInst = TradeskillTalents:new()
TradeskillTalentsInst:Init()
