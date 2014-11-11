-----------------------------------------------------------------------------------------------
-- Client Lua Script for SocialPanel
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "ApolloCursor"
require "GameLib"
require "Item"

-----------------------------------------------------------------------------------------------
-- LootConfirm Module Definition
-----------------------------------------------------------------------------------------------
local LootConfirm = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local knMaxItems = 5
local kidBackpack = 0
local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "ItemQuality_Inferior",
	[Item.CodeEnumItemQuality.Average] 		= "ItemQuality_Average",
	[Item.CodeEnumItemQuality.Good] 			= "ItemQuality_Good",
	[Item.CodeEnumItemQuality.Excellent] 	= "ItemQuality_Excellent",
	[Item.CodeEnumItemQuality.Superb] 		= "ItemQuality_Superb",
	[Item.CodeEnumItemQuality.Legendary] 	= "ItemQuality_Legendary",
	[Item.CodeEnumItemQuality.Artifact]		= "ItemQuality_Artifact",
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function LootConfirm:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function LootConfirm:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- LootConfirm OnLoad
-----------------------------------------------------------------------------------------------
function LootConfirm:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("LootConfirm.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	
	self.arLootList = {}
	self.arItemList = {}
	self.nItemIndex = 1
	
	self.timerRefresh = ApolloTimer.Create(1, true, "RedrawAll", self)
	self.timerRefresh:Stop()
end

function LootConfirm:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("LootBindcheck", 	"OnLootBindCheck", self)
	Apollo.RegisterEventHandler("LootTakenBy", 		"OnLootTakenBy", self)
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "LootForm", nil, self)
	self.wndParent = self.wndMain:FindChild("MainScroll")
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
	local nMainHeight = nBottom - nTop
	
	nLeft, nTop, nRight, nBottom = self.wndParent:GetRect()
	self.nParentHeight = nBottom - nTop
	self.nParentBuffer = nMainHeight - self.nParentHeight + 10
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	self.wndMain:Close()
end

function LootConfirm:OnWindowManagementReady()
	--Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("CRB_Loot_Distribution")})
end

--------------------//-----------------------------
--LootBindCheck( tLootDetail = { nLootId = #, itemDrop = item } ) which will be fired for each item that needs validation. 
function LootConfirm:OnLootBindCheck(tLootDetail)
	if tLootDetail then
		if not self.arLootList[tLootDetail.nLootId] then
			table.insert(self.arItemList, tLootDetail)
			
			self.arLootList[tLootDetail.nLootId] = tLootDetail
		end
	end
	
	self:RedrawAll()
end

--LootTakenBy( tDetail = { nLootId = #, itemLoot = item, unitLooter = unit } ) 
function LootConfirm:OnLootTakenBy(tLootDetail)
	if tLootDetail and tLootDetail.nLootId then
		if self.arLootList[tLootDetail.nLootId] then
			self.arLootList[tLootDetail.nLootId] = tLootDetail
			
			self:RedrawAll()
		end
	end
end

function LootConfirm:OnLootListItemCheck(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end
	
	self.nItemIndex = wndHandler:GetData().nIdx
	
	local itemCurr = self.arItemList[self.nItemIndex]
	self.wndMain:FindChild("LootBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.LootItem, itemCurr.nLootId)
	self.wndMain:FindChild("LootBtn"):Enable(true)
end

function LootConfirm:OnLootListItemGenerateTooltip(wndControl, wndHandler) -- wndHandler is VendorListItemIcon
	if wndHandler ~= wndControl then
		return
	end

	wndControl:SetTooltipDoc(nil)

	local tListItem = wndHandler:GetData().tItem
	local tPrimaryTooltipOpts = {}

	tPrimaryTooltipOpts.bPrimary = true
	tPrimaryTooltipOpts.itemModData = tListItem.itemModData
	tPrimaryTooltipOpts.strMaker = tListItem.strMaker
	tPrimaryTooltipOpts.arGlyphIds = tListItem.arGlyphIds
	tPrimaryTooltipOpts.tGlyphData = tListItem.itemGlyphData
	tPrimaryTooltipOpts.itemCompare = tListItem:GetEquippedItemForItemType()
	tPrimaryTooltipOpts.nStackCount = tListItem.nStackSize

	if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
		Tooltip.GetItemTooltipForm(self, wndControl, tListItem, tPrimaryTooltipOpts)
	end
end

function LootConfirm:RedrawAll()
	local nTotalItems = 0
	local itemCurr = nil
	local nScrollPos = self.wndParent:GetVScrollPos()
	self.wndParent:DestroyChildren()
	
	local nElementHeight = 0
	for idx, tData in ipairs(self.arItemList) do
		local unitLooter = self.arLootList[tData.nLootId].unitLooter or nil
		
		if not unitLooter or not GameLib.GetPlayerUnit() or unitLooter and GameLib.GetPlayerUnit() and GameLib.GetPlayerUnit() ~= unitLooter then
			local tItem = tData.itemDrop			
			
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "LootListItem", self.wndParent, self)
			nElementHeight = wndCurr:GetHeight()
			nTotalItems = nTotalItems + 1
			
			if unitLooter then
				wndCurr:FindChild("Blocker"):SetText(unitLooter:GetName())
				wndCurr:FindChild("Blocker"):Show(true)
			else
				if nTotalItems == self.nItemIndex then
					itemCurr = tData
				end
			end
			
			wndCurr:FindChild("Btn"):SetData({nIdx = idx, tItem=tItem})
			wndCurr:FindChild("Btn"):SetCheck(nTotalItems == self.nItemIndex)
			
			wndCurr:FindChild("Title"):SetTextColor(karEvalColors[tItem:GetItemQuality()])
			wndCurr:FindChild("Title"):SetText(tItem:GetName())
			
			local bTextColorRed = self:HelperPrereqFailed(tItem)
			wndCurr:FindChild("Type"):SetTextColor(bTextColorRed and "xkcdReddish" or "UI_TextHoloBodyCyan")
			wndCurr:FindChild("Type"):SetText(tItem:GetItemTypeName())
			
			wndCurr:FindChild("CantUse"):Show(bTextColorRed)
			wndCurr:FindChild("Icon"):GetWindowSubclass():SetItem(tItem)
		end
	end
	
	if nElementHeight > 0 then
		--Reduce the height of the window if it doesn't require a scrollbar.
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		
		nTop = nTotalItems > knMaxItems and nBottom - (knMaxItems * nElementHeight) or nBottom - (nTotalItems * nElementHeight)
		self.wndMain:SetAnchorOffsets(nLeft, nTop-self.nParentBuffer, nRight, nBottom)
	end
	
	self.wndParent:ArrangeChildrenVert(0)
	self.wndParent:SetVScrollPos(nScrollPos)
	if nTotalItems > 0 and GameLib.CanVacuum() then	
		if itemCurr ~= nil then
			self.wndMain:FindChild("LootBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.LootItem, itemCurr.nLootId)
		end
		
		if not self.wndMain:IsShown() then
			self.timerRefresh:Start()
		end
		
		self.wndMain:FindChild("TitleForm"):SetText(string.format("%s (%s)", Apollo.GetString("CRB_Bind_on_pickup"), nTotalItems))
		self.wndMain:FindChild("LootBtn"):Enable(itemCurr ~= nil)
		self.wndMain:Invoke()
	else
		self.wndMain:Close()
	end
end

function LootConfirm:HelperPrereqFailed(tCurrItem)
	return tCurrItem and tCurrItem:IsEquippable() and not tCurrItem:CanEquip()
end

function LootConfirm:OnLootCurr()
	if self.nItemIndex == #self.arItemList then 
		self.nItemIndex = self.nItemIndex - 1
	end

	self:RedrawAll()
end

function LootConfirm:OnLootBtnMouseEnter(wndHandler, wndControl)
	self.timerRefresh:Stop()
end

function LootConfirm:OnLootBtnMouseExit(wndHandler, wndControl)
	if self.wndMain:IsShown() then
		self.timerRefresh:Start()
	end
end

function LootConfirm:OnCloseBtn()	
	self.wndMain:Close()
end

function LootConfirm:OnClose()
	self.arLootList = {}
	self.arItemList = {}
	self.nItemIndex = 1

	self.timerRefresh:Stop()
end

local LootConfirmInst = LootConfirm:new()
LootConfirmInst:Init()