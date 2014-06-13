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

	Apollo.RegisterTimerHandler("LootStackUpdate",		"OnLootStackUpdate", self)
	Apollo.CreateTimer("LootStackUpdate", 0.1, true)

	Apollo.RegisterTimerHandler("LootStack_CashTimer", 	"OnLootStack_CashTimer", self)
	Apollo.CreateTimer("LootStack_CashTimer", 5.0, false)
	Apollo.StartTimer("LootStack_CashTimer")

	self.wndLootStack = Apollo.LoadForm(self.xmlDoc, "LootStackForm", "FixedHudStratumHigh", self)
	self.xmlDoc = nil
	self.wndCashDisplay = self.wndLootStack:FindChild("LootFloaters:CashComplex:CashDisplay")
	self.wndCashComplex = self.wndLootStack:FindChild("LootFloaters:CashComplex")
	self.wndCashComplex:Show(false)
	
	-- This will be updated the first time we go through LootStackUpdate
	self.bIsMoveable = nil

	for idx = 1, knMaxEntryData do
		local wndEntry = self.wndLootStack:FindChild("LootFloaters:LootedItem_"..idx)
		wndEntry:Show(false, true)
		self.arEntries[idx] = wndEntry
	end
	local wndEntry = self.wndLootStack:FindChild("LootFloaters:LootedItem_4")
	wndEntry:Show(false, true)

	self:UpdateDisplay()
end

function LootStack:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndLootStack, strName = Apollo.GetString("HUDAlert_VacuumLoot")})
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

	Apollo.StopTimer("LootStack_CashTimer")
	Apollo.StartTimer("LootStack_CashTimer")
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
	self.fLastTimeAdded = GameLib.GetGameTime()
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

	-- push this item on the end of the table
	local fCurrTime = GameLib.GetGameTime()
	local nBtnIdx = #self.tEntryData + 1
	self.tEntryData[nBtnIdx] = tQueuedData
	self.tEntryData[nBtnIdx].fTimeAdded = fCurrTime -- adds a delay for vaccuum looting by switching logged to "shown" time

	self.fLastTimeAdded = fCurrTime

	-- animate the entry down
	--self.arEntries[btnIdx]:PlayAnim(0)
end

function LootStack:RemoveItem(idx)
	-- validate our inputs
	if idx < 1 or idx > #self.tEntryData then
		return false
	end

	-- remove that item and alert inventory
	local tEntryData = self.tEntryData[idx]
	table.remove(self.tEntryData, idx)
	return true
end

function LootStack:UpdateDisplay()
	-- iterate over our entry data updating all the buttons
	for idx, wndEntry in ipairs(self.arEntries) do
		local tCurrEntryData = self.tEntryData[idx]
		local tCurrItem = tCurrEntryData and tCurrEntryData.itemInstance or false

		if tCurrEntryData then
			wndEntry:Invoke()
		else
			wndEntry:Close()
		end
		
		if tCurrEntryData and tCurrItem and tCurrEntryData.nButton ~= idx then
			local bGivenQuest = tCurrItem:GetGivenQuest()
			local eItemQuality = tCurrItem and tCurrItem:GetItemQuality() or 1
			wndEntry:FindChild("Text"):SetTextColor(bGivenQuest and "white" or karEvalColors[eItemQuality])
			wndEntry:FindChild("LootIcon"):SetSprite(bGivenQuest and "sprMM_QuestGiver" or tCurrItem:GetIcon())
			wndEntry:FindChild("RarityBracket"):SetSprite(bGivenQuest and "sprTooltip_Header_White" or karQualitySquareSprite[eItemQuality])

			if tCurrEntryData.nCount == 1 then
				wndEntry:FindChild("Text"):SetText(tCurrItem:GetName())
			else
				wndEntry:FindChild("Text"):SetText(String_GetWeaselString(Apollo.GetString("CombatLog_MultiItem"), tCurrEntryData.nCount, tCurrItem:GetName()))
			end
			tCurrEntryData.nButton = idx
		end
	end

	self.wndLootStack:FindChild("LootFloaters"):ArrangeChildrenVert(2)
end

local LootStackInst = LootStack:new()
LootStackInst:Init()
