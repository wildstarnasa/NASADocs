local ItemWindowSubclass = {}
local ItemWindowSubclassRegistrarInst = {}

function ItemWindowSubclass:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ItemWindowSubclass:OnAttached(wnd, strParam)
end

function ItemWindowSubclass:OnDetached(wnd)
end

function ItemWindowSubclass:OnDestroyed(wnd)
end

function ItemWindowSubclass:OnHide(wnd)
end

function ItemWindowSubclass:OnShow(wnd)
end

function ItemWindowSubclass:OnShowing(wnd, fShown)
end

function ItemWindowSubclass:OnHiding(wnd, fShown)
end

function ItemWindowSubclass:OnShowComplete(wnd)
end

function ItemWindowSubclass:OnHideComplete(wnd)
end

function ItemWindowSubclass:SetItem(itemCurr)
    if not itemCurr or (not Item.isInstance(itemCurr) and not Item.isData(itemCurr)) then
	    self:SetItemData(itemCurr, #ItemWindowSubclassRegistrarInst.arQualityColors + 1, "")
	    return
	end
	if itemCurr then
		local eQuality = Item.GetDetailedInfo(itemCurr).tPrimary.eQuality
		if eQuality == 0 then
			eQuality = itemCurr:GetItemQuality()
		end
		self:SetItemData(itemCurr, eQuality, itemCurr:GetIcon())
	end
end

function ItemWindowSubclass:SetItemData(itemCurr, eQuality, strIcon)
	self.eQuality = eQuality
	self.strIcon = strIcon
	self.wnd:SetData(itemCurr) -- Can be nil
	self.wnd:SetSprite(self.strIcon)
	if self.tPixieOverlay == nil then
		self.tPixieOverlay =
		{
			strSprite = ItemWindowSubclassRegistrarInst.arQualitySprites[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualitySprites))],
			loc = {fPoints = {0, 0, 1, 1}, nOffsets = {0, 0, 0, 0}},
			--cr = ItemWindowSubclassRegistrarInst.arQualityColors[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualityColors))]
		}
		self.tPixieOverlay.id = self.wnd:AddPixie(self.tPixieOverlay)
	else
		self.tPixieOverlay.strSprite = ItemWindowSubclassRegistrarInst.arQualitySprites[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualitySprites))]
		--self.tPixieOverlay.cr = ItemWindowSubclassRegistrarInst.arQualityColors[math.max(1, math.min(eQuality, #ItemWindowSubclassRegistrarInst.arQualityColors))]
		self.wnd:UpdatePixie(self.tPixieOverlay.id, self.tPixieOverlay)
	end
end

function ItemWindowSubclass:OnMouseButtonUp(wndHandler, wndControl, eMouseButton)
	if wndHandler and wndHandler == wndControl then
		local itemArg = self.wnd:GetData()
		local bCorrectKey = eMouseButton == GameLib.CodeEnumInputMouse.Right and (Apollo.IsShiftKeyDown() or Apollo.IsControlKeyDown() or Apollo.IsAltKeyDown())
		if bCorrectKey and itemArg and (Item.isInstance(itemArg) or Item.isData(itemCurr)) then
			Event_FireGenericEvent("GenericEvent_ContextMenuItem", itemArg)
			return
		end
	end
end

local ItemWindowSubclassRegistrar = {}

function ItemWindowSubclassRegistrar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.arQualityColors =
	{
		ApolloColor.new("ItemQuality_Inferior"),
		ApolloColor.new("ItemQuality_Average"),
		ApolloColor.new("ItemQuality_Good"),
		ApolloColor.new("ItemQuality_Excellent"),
		ApolloColor.new("ItemQuality_Superb"),
		ApolloColor.new("ItemQuality_Legendary"),
		ApolloColor.new("ItemQuality_Artifact"),
		ApolloColor.new("00000000")
	}

	o.arQualitySprites =
	{
		"UI_RarityBorder_Grey",
		"UI_RarityBorder_White",
		"UI_RarityBorder_Green",
		"UI_RarityBorder_Blue",
		"UI_RarityBorder_Purple",
		"UI_RarityBorder_Orange",
		"UI_RarityBorder_Pink",
		"UI_RarityBorder_White",
	}

    return o
end

function ItemWindowSubclassRegistrar:Init()
    Apollo.RegisterAddon(self)
	local tEventHandlers =
	{
		{strEvent = "MouseButtonUp", strFunction = "OnMouseButtonUp"},
	}
	Apollo.RegisterWindowSubclass("ItemWindowSubclass", self, tEventHandlers)
end

-----------------------------------------------------------------------------------------------
-- ItemWindowSubclassRegistrar:OnLoad
-----------------------------------------------------------------------------------------------

function ItemWindowSubclassRegistrar:OnLoad()

end

function ItemWindowSubclassRegistrar:SubclassWindow(wndNew, strSubclass, strParam)
	local subclass = ItemWindowSubclass:new({wnd = wndNew})
	wndNew:SetWindowSubclass(subclass, strParam)
end

ItemWindowSubclassRegistrarInst = ItemWindowSubclassRegistrar:new()
ItemWindowSubclassRegistrarInst:Init()
ta({ idTradeskill = tCurrTradeskill.eId, nLevel = idx, idTalent = tTalent.nTalentId })

				if tCurrInfo.nTalentPoints < tTierData.nPointsRequired then
					wndTalent:FindChild("TalentItemBtn"):Enable(false)
					wndTalent:FindChild("TalentItemIcon"):SetBGColor("UI_AlphaPercent30")
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

----------------------------------------------------------