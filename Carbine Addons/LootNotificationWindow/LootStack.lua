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
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndLootStack, strName = Apollo.GetString("HUDAlert_VacuumLoot"), nSaveVersion=2})
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
	
	self.timerUpdate:Start()
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

	-- animate the entry down
	--self.arEntries[btnIdx]:PlayAnim(0)
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
eToClient="1" Name="Btn" Overlapped="0" Text="" TextId="" Base="BK3:btnHolo_ListView_Simple" ButtonType="Check" GlobalRadioGroup="Salvage_ListItemRadioGroup" Visible="1" BGColor="ffffffff" TextColor="ffffffff" NormalTextColor="ffffffff" PressedTextColor="ffffffff" FlybyTextColor="ffffffff" PressedFlybyTextColor="ffffffff" DisabledTextColor="ffffffff" TooltipType="OnCursor" RadioGroup="" IgnoreMouse="0" RadioDisallowNonSelection="0" TooltipColor="" IgnoreTooltipDelay="1" HideInEditor="0">
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="7" TAnchorPoint="0" TAnchorOffset="6" RAnchorPoint="0" RAnchorOffset="57" BAnchorPoint="1" BAnchorOffset="-6" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="IconBG" BGColor="ffffffff" TextColor="ffffffff" Picture="1" IgnoreMouse="1" Sprite="BK3:UI_BK3_Holo_InsetSimple" TooltipColor="" NewControlDepth="1"/>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="9" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="0" RAnchorOffset="55" BAnchorPoint="1" BAnchorOffset="-8" RelativeToClient="1" Text="" Name="Icon" Picture="1" IgnoreMouse="1" Sprite="" BGColor="ffffffff" TextColor="ffffffff" NewControlDepth="1" DT_BOTTOM="1" Tooltip="" DT_RIGHT="1" Font="CRB_InterfaceMedium_B" TooltipColor="" IgnoreTooltipDelay="1" TooltipType="OnCursor" Subclass="ItemWindowSubclass"/>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="7" RAnchorPoint="0" RAnchorOffset="28" BAnchorPoint="0" BAnchorOffset="28" RelativeToClient="1" Text="" Name="CantUse" Picture="1" IgnoreMouse="1" Sprite="ClientSprites:Icon_Windows_UI_CRB_Tooltip_Restricted" BGColor="ffffffff" TextColor="ffffffff" NewControlDepth="1" DT_BOTTOM="1" Tooltip="" DT_RIGHT="1" Font="CRB_InterfaceMedium_B" TooltipColor="" IgnoreTooltipDelay="1" TooltipType="OnCursor" Visible="0" TooltipFont="CRB_InterfaceSmall_O" TooltipId="Dialog_CantUseTooltip"/>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="63" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-5" BAnchorPoint=".6" BAnchorOffset="12" RelativeToClient="1" Font="CRB_InterfaceMedium_B" Text="" Name="Title" TextId="" BGColor="ffffffff" TextColor="UI_TextHoloTitle" DT_VCENTER="0" DT_WORDBREAK="1" TooltipColor=""/>
            <Event Name="ButtonCheck" Function="OnLootListItemCheck"/>
            <Event Name="GenerateTooltip" Function="OnLootListItemGenerateTooltip"/>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="63" TAnchorPoint=".6" TAnchorOffset="-2" RAnchorPoint="1" RAnchorOffset="-5" BAnchorPoint="1" BAnchorOffset="-1" RelativeToClient="1" Font="CRB_InterfaceSmall" Text="" Name="Type" TextId="" BGColor="ffffffff" TextColor="UI_TextHoloBody" DT_VCENTER="1" DT_WORDBREAK="1" TooltipColor=""/>
            <Event Name="MouseEnter" Function="OnLootBtnMouseEnter"/>
            <Event Name="MouseExit" Function="OnLootBtnMouseExit"/>
        </Control>
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Font="CRB_HeaderMedium" Text="" BGColor="UI_AlphaPercent60" TextColor="UI_TextHoloBodyHighlight" Template="Default" TooltipType="OnCursor" Name="Blocker" TooltipColor="" Visible="0" Picture="1" Sprite="BasicSprites:BlackFill" NewControlDepth="5" IgnoreMouse="0" DoNotBlockTooltip="1" TextId="CRB_Test_Set_name" DT_CENTER="1" DT_VCENTER="1" HideInEditor="0" DT_WORDBREAK="1"/>
    </Form>
</Forms>
ner" BGColor="ffffffff" TextColor="ffffffff" TooltipColor=""/>
    </Form>
    <Form Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="0" BAnchorOffset="20" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="LiveObjectiveItem" Border="0" Picture="0" SwallowMouseClicks="1" Moveable="0" Escapable="0" Overlappe