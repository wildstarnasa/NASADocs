-----------------------------------------------------------------------------------------------
-- Client Lua Script for LootStack
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Sound"
require "GameLib"

local LootStack = {}

local knMaxEntryData = 4 -- Previously 3
local kfMaxItemTime = 7	-- item display time (seconds)
local kfTimeBetweenItems = 2 -- Previously .3			-- delay between items; also determines clearing time (seconds)
local knType_Invalid = 0
local knType_Item = 1

local karQualitySquareSprite =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "CRB_Tooltips:sprTooltip_Header_Silver",
	[Item.CodeEnumItemQuality.Average] 			= "CRB_Tooltips:sprTooltip_Header_White",
	[Item.CodeEnumItemQuality.Good] 			= "CRB_Tooltips:sprTooltip_Header_Green",
	[Item.CodeEnumItemQuality.Excellent] 		= "CRB_Tooltips:sprTooltip_Header_Blue",
	[Item.CodeEnumItemQuality.Superb] 			= "CRB_Tooltips:sprTooltip_Header_Purple",
	[Item.CodeEnumItemQuality.Legendary] 		= "CRB_Tooltips:sprTooltip_Header_Orange",
	[Item.CodeEnumItemQuality.Artifact]		 	= "CRB_Tooltips:sprTooltip_Header_Pink",
}

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

function LootStack:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	o.arEntries = {}
	o.tEntryData = {}
	o.tQueuedEntryData = {}
	o.fLastTimeAdded = 0
    return o
end

function LootStack:Init()
    Apollo.RegisterAddon(self)
end

function LootStack:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("LootStack.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function LootStack:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("LootedItem", 			"OnLootedItem", self)
	Apollo.RegisterEventHandler("LootedMoney", 			"OnLootedMoney", self)
	
	self.timerUpdate = ApolloTimer.Create(0.1, true, "OnLootStackUpdate", self)

	self.timerCash = ApolloTimer.Create(5.0, false, "OnLootStack_CashTimer", self)

	self.wndLootStack = Apollo.LoadForm(self.xmlDoc, "LootStackForm", "FixedHudStratumHigh", self)
	self.xmlDoc = nil
	self.wndCashDisplay = self.wndLootStack:FindChild("LootFloaters:CashComplex:CashDisplay")
	self.wndCashComplex = self.wndLootStack:FindChild("LootFloaters:CashComplex")
	
	-- This will be updated the first time we go through LootStackUpdate
	self.bIsMoveable = nil

	for idx = 1, knMaxEntryData do
		self.arEntries[idx] = self.wndLootStack:FindChild("LootFloaters:LootedItem_"..idx)
	end

	self:UpdateDisplay()
end

function LootStack:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndLootStack, strName = Apollo.GetString("HUDAlert_VacuumLoot"), nSaveVersion=2})
end

function LootStack:OnGenerateTooltip(wndHandler, wndControl)
	if not wndControl or not wndControl:IsValid() or not wndControl:GetData() then
		return
	end
	
	itemCurr = wndHandler:GetData()
	
	wndControl:SetTooltipDoc(nil)
	if itemCurr ~= nil then
		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemCurr:GetEquippedItemForItemType()})
	end
end

function LootStack:OnMouseEnter(wndHandler, wndControl)
	self.bPause = true
	self.timerUpdate:Stop()
end

function LootStack:OnMouseExit(wndHandler, wndControl)
	self.bPause = false
	self.timerUpdate:Start()
end

-----------------------------------------------------------------------------------------------
-- CASH FUNCTIONS
-----------------------------------------------------------------------------------------------

function LootStack:OnLootedMoney(monLooted)
	local eCurrencyType = monLooted:GetMoneyType()
	if eCurrencyType ~= Money.CodeEnumCurrencyType.Credits then
		return
	end

	self.wndCashDisplay:SetAmount(self.wndCashDisplay:GetAmount() + monLooted:GetAmount())
	self.wndCashComplex:Invoke()

	self.timerCash:Stop()
	self.timerCash:Start()
end

function LootStack:OnLootStack_CashTimer()
	self.wndCashComplex:Show(false)
	self.wndCashDisplay:SetAmount(0)
end

-----------------------------------------------------------------------------------------------
-- ITEM FUNCTIONS
-----------------------------------------------------------------------------------------------

function LootStack:OnLootedItem(itemInstance, nCount)
	local tNewEntry =
	{
		eType = knType_Item,
		itemInstance = itemInstance,
		nCount = nCount,
		money = nil,
		fTimeAdded = GameLib.GetGameTime()
	}
	table.insert(self.tQueuedEntryData, tNewEntry)
	
	if not self.bPause then
		self.timerUpdate:Start()
	end
end

function LootStack:OnLootStackUpdate(strVar, nValue)
	if self.wndLootStack == nil then
		return
	end
	
	local bCanMove = self.wndLootStack:IsStyleOn("Moveable")
	if bCanMove ~= self.bIsMoveable then
		self.bIsMoveable = bCanMove
		self.wndLootStack:SetStyle("IgnoreMouse", not self.bIsMoveable)
		self.wndLootStack:FindChild("Backer"):Show(self.bIsMoveable)
	end
	
	local fCurrTime = GameLib.GetGameTime()

	-- remove any old items
	for idx, tEntryData in ipairs(self.tEntryData) do   --TODO: time the remove to delay
		if fCurrTime - tEntryData.fTimeAdded >= kfMaxItemTime then
			self:RemoveItem(idx)
		end
	end

	-- add a new item if its time
	if #self.tQueuedEntryData > 0 then
		if fCurrTime - self.fLastTimeAdded >= kfTimeBetweenItems then
			self:AddQueuedItem()
		end
	end

	-- update all the items
	self:UpdateDisplay()
	
	if #self.tEntryData == 0 then
		self.timerUpdate:Stop()
	end
end

function LootStack:AddQueuedItem()
	-- gather our entryData we need
	local tQueuedData = self.tQueuedEntryData[1]
	table.remove(self.tQueuedEntryData, 1)
	if tQueuedData == nil then
		return
	end

	if tQueuedData.eType == knType_Item and tQueuedData.nCount == 0 then
		return
	end

	-- ensure there's room
	while #self.tEntryData >= knMaxEntryData do
		if not self:RemoveItem(1) then
			break
		end
	end

	if tQueuedData.itemInstance and tQueuedData.itemInstance:CanTakeFromSupplySatchel() then
		Event_FireGenericEvent("LootStackItemSentToTradeskillBag", tQueuedData)
	end

	-- push this item on the end of the table
	local fCurrTime = GameLib.GetGameTime()
	local nBtnIdx = #self.tEntryData + 1
	self.tEntryData[nBtnIdx] = tQueuedData
	self.tEntryData[nBtnIdx].fTimeAdded = fCurrTime -- adds a delay for vaccuum looting by switching logged to "shown" time

	self.fLastTimeAdded = fCurrTime
end

function LootStack:RemoveItem(idx)
	-- validate our inputs
	if idx < 1 or idx > #self.tEntryData then
		return false
	end

	-- remove that item and alert inventory
	table.remove(self.tEntryData, idx)
	return true
end

function LootStack:UpdateDisplay()
	-- iterate over our entry data updating all the buttons
	for idx, wndEntry in ipairs(self.arEntries) do
		local tCurrEntryData = self.tEntryData[idx]
		local itemCurr = tCurrEntryData and tCurrEntryData.itemInstance or false

		if tCurrEntryData then
			wndEntry:Invoke()
		else
			wndEntry:Show(false, true)
		end
		
		if tCurrEntryData and itemCurr and tCurrEntryData.nButton ~= idx then
			local bGivenQuest = itemCurr:GetGivenQuest()
			local eItemQuality = itemCurr and itemCurr:GetItemQuality() or 1
			wndEntry:SetData(itemCurr)
			wndEntry:SetTooltipDoc(nil)
			wndEntry:FindChild("Text"):SetTextColor(bGivenQuest and "white" or karEvalColors[eItemQuality])
			wndEntry:FindChild("LootIcon"):SetSprite(bGivenQuest and "sprMM_QuestGiver" or itemCurr:GetIcon())
			wndEntry:FindChild("RarityBracket"):SetSprite(bGivenQuest and "sprTooltip_Header_White" or karQualitySquareSprite[eItemQuality])

			if tCurrEntryData.nCount == 1 then
				wndEntry:FindChild("Text"):SetText(itemCurr:GetName())
			else
				wndEntry:FindChild("Text"):SetText(String_GetWeaselString(Apollo.GetString("CombatLog_MultiItem"), tCurrEntryData.nCount, itemCurr:GetName()))
			end
			
			tCurrEntryData.nButton = idx
		end
	end

	self.wndLootStack:FindChild("LootFloaters"):ArrangeChildrenVert(2)
end

local LootStackInst = LootStack:new()
LootStackInst:Init()
