-----------------------------------------------------------------------------------------------
-- Client Lua Script for AbilityVendor
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "AbilityBook"
require "Tooltip"
require "Spell"
require "string"
require "math"
require "Sound"
require "Item"
require "Money"
require "AbilityBook"

local AbilityVendor = {}

local knVersion = 1

local ktstrEnumToString =
{
	[Spell.CodeEnumSpellTag.Assault] = "AbilityBuilder_Assault",
	[Spell.CodeEnumSpellTag.Support] = "AbilityBuilder_Support",
	[Spell.CodeEnumSpellTag.Utility] = "AbilityBuilder_Utility",
}

function AbilityVendor:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWndRefs = {}

    return o
end

function AbilityVendor:Init()
    Apollo.RegisterAddon(self)
end

function AbilityVendor:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AbilityVendor.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function AbilityVendor:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("ToggleAbilitiesWindow", 				"OnAbilityVendorToggle", self)
	Apollo.RegisterEventHandler("AbilitiesWindowClose", 				"OnClose", self)

	Apollo.RegisterEventHandler("PlayerLevelChange", 					"RedrawAll", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 				"RedrawAll", self)
	Apollo.RegisterEventHandler("CharacterEldanAugmentationsUpdated", 	"RedrawRespec", self)
end

function AbilityVendor:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.tWndRefs.wndMain and self.tWndRefs.wndMain:GetLocation() or self.locSavedWindowLoc

	local tSave = 
	{
		tLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nVersion = knVersion,
	}
	
	return tSave
end

function AbilityVendor:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nVersion  == knVersion then
		if tSavedData.tLocation then
			self.locSavedWindowLoc = WindowLocation.new(tSavedData.tLocation)
		end
	end
end

function AbilityVendor:OnClose(wndHandler, wndControl)
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		Event_CancelTraining()
		self.locSavedWindowLoc = self.tWndRefs.wndMain:GetLocation()
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end
end

function AbilityVendor:OnAbilityVendorToggle(bAtVendor)
	if not bAtVendor then
		return
	end

	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Close()
	else
		self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "AbilityVendorForm", nil, self)
	end

	self.tNextAbilityId = nil

	self.tWndRefs.wndBuyBtn = self.tWndRefs.wndMain:FindChild("BGBottom:BuyBtn")
	self.tWndRefs.wndBuyBtn:Enable(false)
	
	if self.locSavedWindowLoc then
		self.tWndRefs.wndMain:MoveToLocation(self.locSavedWindowLoc)
		self.locSavedWindowLoc = nil
	end

	self:RedrawAll()
end

function AbilityVendor:RedrawAll()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	local nPlayerLevel = GameLib.GetPlayerLevel()
	local nPlayerMoney = GameLib.GetPlayerCurrency():GetAmount()
	self.tWndRefs.wndMain:FindChild("BGBottom:BottomInfoInnerBG:CurrentCash"):SetAmount(nPlayerMoney, false)

	-- TEMP HACK, until we have filter
	local tHugeAbilityList =
	{
		[Spell.CodeEnumSpellTag.Assault] = {},
		[Spell.CodeEnumSpellTag.Support] = {},
		[Spell.CodeEnumSpellTag.Utility] = {},
	}
	for idx, tAbilityInfo in pairs(AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Assault)) do
		tHugeAbilityList[Spell.CodeEnumSpellTag.Assault][idx] = tAbilityInfo
	end
	for idx, tAbilityInfo in pairs(AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Support)) do
		tHugeAbilityList[Spell.CodeEnumSpellTag.Support][idx] = tAbilityInfo
	end
	for idx, tAbilityInfo in pairs(AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Utility)) do
		tHugeAbilityList[Spell.CodeEnumSpellTag.Utility][idx] = tAbilityInfo
	end

	-- Build List
	local wndItemList = self.tWndRefs.wndMain:FindChild("ItemList")
	local nVScrollPos = wndItemList:GetVScrollPos()
	wndItemList:DestroyChildren()
	for eCategory, tFilteredAbilityList in pairs(tHugeAbilityList) do
		for idx, tBaseContainer in pairs(tFilteredAbilityList) do
			local tTierOne = tBaseContainer.tTiers[1]
			if not tBaseContainer.bIsActive and tTierOne.bCanPurchase then
				local wndCurr = Apollo.LoadForm(self.xmlDoc, "AbilityItem", wndItemList, self)
				local wndAbilityBtn = wndCurr:FindChild("AbilityItemBtn")
				local wndCost = wndAbilityBtn:FindChild("AbilityCostCash")
				local wndBlocker = wndCurr:FindChild("AbilityLockBlocker")
				local wndIcon = wndAbilityBtn:FindChild("AbilityIcon")
				
				wndCurr:SetData(tTierOne.nLevelReq) -- For sorting
				wndAbilityBtn:SetData(tTierOne.nId) -- For buy button
				wndIcon:SetSprite(tTierOne.splObject:GetIcon())
				wndAbilityBtn:FindChild("AbilityCategory"):SetText(Apollo.GetString(ktstrEnumToString[eCategory]))
				wndCost:SetAmount(tTierOne.nTrainingCost, true)
				wndCost:SetTextColor(tTierOne.nTrainingCost > nPlayerMoney and "UI_WindowTextRed" or "ffffffff")
				wndAbilityBtn:Enable(tTierOne.nLevelReq <= nPlayerLevel and tTierOne.nTrainingCost <= nPlayerMoney)

				if tTierOne.nLevelReq > nPlayerLevel then
					wndBlocker:Show(true)
					wndBlocker:SetTooltip(String_GetWeaselString(Apollo.GetString("ABV_UnlockLevel")..tTierOne.nLevelReq))
					wndAbilityBtn:FindChild("AbilityTitle"):SetText(String_GetWeaselString(Apollo.GetString("ABV_AbilityTitle"), tTierOne.strName, tTierOne.nLevelReq))
				else
					wndAbilityBtn:FindChild("AbilityTitle"):SetText(tTierOne.strName)
					Tooltip.GetSpellTooltipForm(self, wndIcon, tTierOne.splObject, {bTiers = true})
				end

				if self.tNextAbilityId and self.tNextAbilityId == tTierOne.nId then
					wndAbilityBtn:SetCheck(true)
					self.tWndRefs.wndBuyBtn:Enable(tTierOne.nLevelReq <= nPlayerLevel and tTierOne.nTrainingCost <= nPlayerMoney)
				end
			end
		end
	end

	-- Respec AMPs Item
	self:RedrawRespec()

	-- Sort
	wndItemList:ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)
	wndItemList:SetVScrollPos(nVScrollPos)
	wndItemList:SetText(#wndItemList:GetChildren() == 0 and Apollo.GetString("AbilityBuilder_OutOfAbilities") or "")
end

function AbilityVendor:RedrawRespec()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	
	local nPlayerLevel = GameLib.GetPlayerLevel()
	local bAllPointsAvailable = AbilityBook.GetTotalPower() == AbilityBook.GetAvailablePower()
	local wndRespec = self.tWndRefs.wndMain:FindChild("ItemList:RespecAMPsItem")
	
	if not wndRespec or not wndRespec:IsValid() then
		wndRespec = Apollo.LoadForm(self.xmlDoc, "RespecAMPsItem", self.tWndRefs.wndMain:FindChild("ItemList"), self)
	end
	
	local wndRespecBtn = wndRespec:FindChild("RespecAMPsItemBtn")
	
	wndRespecBtn:SetData("RespecAMPsItemBtn")
	wndRespecBtn:Enable(nPlayerLevel >= 6 and not bAllPointsAvailable)	
	wndRespecBtn:FindChild("RespecAMPsSubtitle"):Show(bAllPointsAvailable)
	wndRespecBtn:FindChild("RespecAMPsTitle"):SetText(String_GetWeaselString(Apollo.GetString("ABV_RespecAmps"), nPlayerLevel < 6 and Apollo.GetString("ABV_Level6") or ""))
	
	wndRespec:SetData(9000) -- For sorting
	wndRespec:FindChild("RespecAMPsBlocker"):Show(nPlayerLevel < 6)
end

function AbilityVendor:OnBuyBtn(wndHandler, wndControl) -- BuyBtn
	if not wndHandler:GetData() then
		return
	end

	if wndHandler:GetData() == "RespecAMPsItemBtn" then
		AbilityBook.UpdateEldanAugmentationSpec(AbilityBook.GetCurrentSpec(), 0, {})
		AbilityBook.CommitEldanAugmentationSpec()
		self:OnClose()
		return
	end

	self.tNextAbilityId = nil
	local nAbilityIdToLearn = wndHandler:GetData()
	local tListOfItems = self.tWndRefs.wndMain:FindChild("ItemList"):GetChildren()

	for idx, wndCurr in pairs(tListOfItems) do
		if wndCurr:FindChild("AbilityItemBtn"):GetData() == nAbilityIdToLearn then
			local wndNextAbility = tListOfItems[idx + 1]
			local wndAbilityBtn = wndNextAbility:FindChild("AbilityItemBtn")
			if wndNextAbility and wndAbilityBtn and wndAbilityBtn:GetData() then
				self.tNextAbilityId = wndAbilityBtn:GetData()
			end
			break
		end
	end

	AbilityBook.ActivateSpell(nAbilityIdToLearn, true)
	self.tWndRefs.wndBuyBtn:SetData(self.tNextAbilityId)
end

function AbilityVendor:OnAbilityItemToggle(wndHandler, wndControl) -- AbilityItemBtn, data is abilityId
	local wndBuyBtn = self.tWndRefs.wndBuyBtn
	wndBuyBtn:SetData(wndHandler:GetData())
	wndBuyBtn:Enable(wndHandler:IsChecked())
end

local AbilityVendorInst = AbilityVendor:new()
AbilityVendorInst:Init()
