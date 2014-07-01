-----------------------------------------------------------------------------------------------
-- Client Lua Script for NeedVsGreed
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Sound"

local NeedVsGreed = {}

local ktEvalColors = 
{
	[Item.CodeEnumItemQuality.Inferior] 		= ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 			= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= ApolloColor.new("ItemQuality_Artifact"),
}

function NeedVsGreed:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NeedVsGreed:Init()
    Apollo.RegisterAddon(self)
end

function NeedVsGreed:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("NeedVsGreed.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function NeedVsGreed:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("LootRollUpdate",		"OnGroupLoot", self)
    Apollo.RegisterTimerHandler("WinnerCheckTimer", 	"OnOneSecTimer", self)
    Apollo.RegisterEventHandler("LootRollWon", 			"OnLootRollWon", self)
    Apollo.RegisterEventHandler("LootRollAllPassed", 	"OnLootRollAllPassed", self)
	
	Apollo.RegisterEventHandler("LootRollSelected", 	"OnLootRollSelected", self)
	Apollo.RegisterEventHandler("LootRollPassed", 		"OnLootRollPassed", self)
	Apollo.RegisterEventHandler("LootRoll", 			"OnLootRoll", self)

	--Apollo.RegisterEventHandler("GroupBagItemAdded", 	"OnGroupBagItemAdded", self) -- Appears deprecated

	Apollo.CreateTimer("WinnerCheckTimer", 1.0, false)
	Apollo.StopTimer("WinnerCheckTimer")
	self.wndMain = nil
	
	self.bTimerRunning = false
	self.tKnownLoot = nil
	self.tLootRolls = nil
	self.tMostRelevant = nil
	
	if GameLib.GetLootRolls() then
		self:OnGroupLoot()
	end
end

function NeedVsGreed:Close()
	if self.wndMain then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

-----------------------------------------------------------------------------------------------
-- Main Draw Method
-----------------------------------------------------------------------------------------------
function NeedVsGreed:OnGroupLoot()
	if not self.bTimerRunning then
		Apollo.StartTimer("WinnerCheckTimer")
		self.bTimerRunning = true
	end
end

function NeedVsGreed:UpdateKnownLoot()
	self.tLootRolls = GameLib.GetLootRolls()
	if not self.tLootRolls or #self.tLootRolls <= 0 then
		self.tKnownLoot = nil
		self.tLootRolls = nil
		self.tMostRelevant = nil
		return
	end

	self.tKnownLoot = {}
	for idx, tCurrentElement in ipairs(self.tLootRolls) do
		self.tKnownLoot[tCurrentElement.nLootId] = tCurrentElement
	end
	
	if self.tMostRelevant then
		self.tMostRelevant = self.tKnownLoot[self.tMostRelevant.nLootId]
	end
	
	-- NOTE: self.tMostRelevant may have been set to nil above.
	if not self.tMostRelevant then
		for nLootId, tCurrentElement in pairs(self.tKnownLoot) do
			if not self.tMostRelevant or self.tMostRelevant.nTimeLeft > tCurrentElement.nTimeLeft then
				self.tMostRelevant = tCurrentElement
				--Print(math.floor(tCurrentElement.nTimeLeft / 1000))
			end
		end
	end
end

function NeedVsGreed:OnOneSecTimer()
	self:UpdateKnownLoot()

	if not self.tLootRolls and self.wndMain and self.wndMain:IsShown() then
		self:Close()
	end

	if self.tMostRelevant then
		self:DrawLoot(self.tMostRelevant, #self.tLootRolls)
	end

	-- Art based on anchor
	if self.wndMain and self.wndMain:IsValid() then
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
		if nLeft < 1 then
			self.wndMain:SetSprite("BK3:UI_BK3_Holo_Framing_2")
		else
			self.wndMain:SetSprite("BK3:UI_BK3_Holo_Framing_2")
		end
	end

	if self.tLootRolls and #self.tLootRolls > 0 then
		Apollo.StartTimer("WinnerCheckTimer")
	else
		self.bTimerRunning = false
	end
end

function NeedVsGreed:DrawLoot(tCurrentElement, nItemsInQueue)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() then
		self:Close()
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "NeedVsGreedForm", nil, self)
		Sound.Play(Sound.PlayUIWindowNeedVsGreedOpen)
	end
	self.wndMain:SetData(tCurrentElement.nLootId)

	local itemCurrent = tCurrentElement.itemDrop
	local itemModData = tCurrentElement.tModData
	local tGlyphData = tCurrentElement.tSigilData
	self.wndMain:FindChild("LootTitle"):SetText(itemCurrent:GetName())
	self.wndMain:FindChild("LootTitle"):SetTextColor(ktEvalColors[itemCurrent:GetItemQuality()])
	self.wndMain:FindChild("GiantItemIcon"):SetSprite(itemCurrent:GetIcon())
	self:HelperBuildItemTooltip(self.wndMain:FindChild("GiantItemIcon"), itemCurrent, itemModData, tGlyphData)

	if nItemsInQueue > 1 then -- Do items in queue
		self.wndMain:FindChild("ItemsInQueueIcon"):SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\">%s</P>", String_GetWeaselString(Apollo.GetString("NeedVsGreed_NumItems"), nItemsInQueue)))
		self.wndMain:FindChild("ItemsInQueueText"):SetText(nItemsInQueue)
	end
	self.wndMain:FindChild("ItemsInQueueIcon"):Show(nItemsInQueue > 1)
	self.wndMain:FindChild("NeedBtn"):Enable(GameLib.IsNeedRollAllowed(tCurrentElement.nLootId))

	-- TODO Timelimit
	local nTimeLeft = math.floor(tCurrentElement.nTimeLeft / 1000)
	self.wndMain:FindChild("TimeLeftText"):Show(true)
	
	local nTimeLeftSecs = nTimeLeft % 60
	local nTimeLeftMins = math.floor(nTimeLeft / 60)
	
	local strTimeLeft = tostring(nTimeLeftMins)
	if nTimeLeft < 0 then
		strTimeLeft = "0:00"
	elseif nTimeLeftSecs < 10 then
		strTimeLeft = strTimeLeft .. ":0" .. tostring(nTimeLeftSecs)
	else
		strTimeLeft = strTimeLeft .. ":" .. tostring(nTimeLeftSecs)
	end
	self.wndMain:FindChild("TimeLeftText"):SetText(strTimeLeft)
end

-----------------------------------------------------------------------------------------------
-- Chat Message Events
-----------------------------------------------------------------------------------------------

function NeedVsGreed:OnLootRollAllPassed(itemLooted)
	-- Can be fired without self.wndMain
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Loot, String_GetWeaselString(Apollo.GetString("NeedVsGreed_EveryonePassed"), itemLooted:GetName()))
end

function NeedVsGreed:OnLootRollWon(itemLooted, strWinner, bNeed)
	-- Can be fired without self.wndMain
	local strNeedOrGreed = Apollo.GetString("NeedVsGreed_GreedRoll")
	if bNeed then
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_NeedRoll")
	end

	-- Example Message: Alvin used Greed Roll on Item Name for 45 (LootRoll).
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("NeedVsGreed_ItemWon"), strWinner, itemLooted:GetName(), strNeedOrGreed))
end

function NeedVsGreed:OnLootRollSelected(nLootItem, strPlayer, bNeed)

	local strNeedOrGreed = Apollo.GetString("NeedVsGreed_GreedRoll")
	if bNeed then
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_NeedRoll")
	end
	
	-- Example Message: strPlayer has selected to bNeed for nLootItem
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("NeedVsGreed_LootRollSelected"), strPlayer, strNeedOrGreed, nLootItem:GetName()))
end

function NeedVsGreed:OnLootRollPassed(nLootItem, strPlayer)

	-- Example Message: strPlayer passed on nLootItem
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("NeedVsGreed_PlayerPassed"), strPlayer, nLootItem:GetName()))
end

function NeedVsGreed:OnLootRoll(nLootItem, strPlayer, nRoll, bNeed)

	local strNeedOrGreed = Apollo.GetString("NeedVsGreed_GreedRoll")
	if bNeed then
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_NeedRoll")
	end
	-- Example String: strPlayer rolled nRoll for nLootItem (bNeed)
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("NeedVsGreed_OnLootRoll"), strPlayer, nRoll, nLootItem:GetName(), strNeedOrGreed ))
end

-----------------------------------------------------------------------------------------------
-- Buttons
-----------------------------------------------------------------------------------------------

function NeedVsGreed:OnNeedBtn(wndHandler, wndControl)
	GameLib.RollOnLoot(self.wndMain:GetData(), true)
	self:Close()
end

function NeedVsGreed:OnGreedBtn(wndHandler, wndControl)
	GameLib.RollOnLoot(self.wndMain:GetData(), false)
	self:Close()
end

function NeedVsGreed:OnPassBtn(wndHandler, wndControl)
	GameLib.PassOnLoot(self.wndMain:GetData())
	self:Close()
end

function NeedVsGreed:HelperBuildItemTooltip(wndArg, itemCurr, itemModData, tGlyphData)
	wndArg:SetTooltipDoc(nil)
	wndArg:SetTooltipDocSecondary(nil)
	local itemEquipped = itemCurr:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped, itemModData = itemModData, tGlyphData = tGlyphData})
	--if itemEquipped then -- OLD
	--	Tooltip.GetItemTooltipForm(self, wndArg, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = itemCurr})
	--end
end

local NeedVsGreedInst = NeedVsGreed:new()
NeedVsGreedInst:Init()
