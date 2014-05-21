-----------------------------------------------------------------------------------------------
-- Client Lua Script for BankViewer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "Money"

local BankViewer = {}
local knMaxBankBagSlots = 5
local knBagBoxSize = 50
local knSaveVersion = 1

function BankViewer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function BankViewer:Init()
    Apollo.RegisterAddon(self)
end

function BankViewer:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("BankViewer.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function BankViewer:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("HideBank", "HideBank", self)
	Apollo.RegisterEventHandler("ShowBank", "Initialize", self)
    Apollo.RegisterEventHandler("ToggleBank", "Initialize", self)
	Apollo.RegisterEventHandler("CloseVendorWindow", "HideBank", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", "ComputeCashLimits", self)
	Apollo.RegisterEventHandler("BankSlotPurchased", "OnBankSlotPurchased", self)
	Apollo.RegisterEventHandler("PersonaUpdateCharacterStats", "RefreshBagCount", self)

	Apollo.RegisterTimerHandler("BankViewer_NewBagPurchasedAlert", "OnBankViewer_NewBagPurchasedAlert", self)

	self.wndMain = nil -- TODO RESIZE CODE
end

function BankViewer:Initialize()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Close()
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm("BankViewer.xml", "BankViewerForm", nil, self)
	self.wndMain:FindChild("BankBuySlotBtn"):AttachWindow(self.wndMain:FindChild("BankBuySlotConfirm"))
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Bank_Header")})
	
	self:Build()
end

function BankViewer:Build()
	local nNumBagSlots = GameLib.GetNumBankBagSlots()

	self.wndMain:FindChild("ConfigureBagsContainer"):DestroyChildren()

	-- Configure Screen
	for idx = 1, knMaxBankBagSlots do
		local idBag = idx + 20
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "BankSlot", self.wndMain:FindChild("ConfigureBagsContainer"), self)
		local wndBagBtn = Apollo.LoadForm(self.xmlDoc, "BagBtn"..idBag, wndCurr:FindChild("BankSlotFrame"), self)
		if wndBagBtn:GetItem() then
			wndCurr:FindChild("BagCount"):SetText(wndBagBtn:GetItem():GetBagSlots())
		end
		wndCurr:FindChild("BagCount"):SetData(wndBagBtn)
		wndCurr:FindChild("BagLocked"):Show(idx > nNumBagSlots)
		wndCurr:FindChild("NewBagPurchasedAlert"):Show(false, true)
		wndBagBtn:Enable(idx <= nNumBagSlots)
	end
	self.wndMain:FindChild("ConfigureBagsContainer"):ArrangeChildrenHorz(1)

	-- Hide the bottom bar if at max
	if nNumBagSlots >= knMaxBankBagSlots then
		local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("BankGridArt"):GetAnchorOffsets()
		self.wndMain:FindChild("BankGridArt"):SetAnchorOffsets(nLeft, nTop, nRight, nBottom + 65) -- todo hardcoded formatting

		nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("BankBagArt"):GetAnchorOffsets()
		self.wndMain:FindChild("BankBagArt"):SetAnchorOffsets(nLeft, nTop + 65, nRight, nBottom + 65)
		self.wndMain:FindChild("BankBottomArt"):Show(false)
	else
		self:ComputeCashLimits()
	end

	-- Resize
	self:ResizeBankSlots()
end

function BankViewer:RefreshBagCount()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		return
	end

	for key, wndCurr in pairs(self.wndMain:FindChild("ConfigureBagsContainer"):GetChildren()) do
		local wndBagBtn = wndCurr:FindChild("BagCount"):GetData()
		if wndBagBtn and wndBagBtn:GetItem() then
			wndCurr:FindChild("BagCount"):SetText(wndBagBtn:GetItem():GetBagSlots())
		elseif wndBagBtn then
			wndCurr:FindChild("BagCount"):SetText("")
		end
	end
end

function BankViewer:OnWindowClosed()
	Event_CancelBanking()
	
	if self.wndMain then
		self.wndMain:Destroy()
	end
end

function BankViewer:HideBank()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Close()
		self.wndMain:Destroy()
	end
end

function BankViewer:ComputeCashLimits()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		return
	end

	local nNextBankBagCost = GameLib.GetNextBankBagCost():GetAmount()
	local nPlayerCash = GameLib.GetPlayerCurrency():GetAmount()
	if nNextBankBagCost > nPlayerCash then
		self.wndMain:FindChild("BankBuyPrice"):SetTextColor(ApolloColor.new("red"))
		self.wndMain:FindChild("BankBuyPrice"):SetTooltip(Apollo.GetString("Bank_CanNotAfford"))
		self.wndMain:FindChild("BankBuySlotBtn"):Enable(false)
	else
		self.wndMain:FindChild("BankBuyPrice"):SetTextColor(ApolloColor.new("white"))
		self.wndMain:FindChild("BankBuyPrice"):SetTooltip(Apollo.GetString("Bank_SlotPriceTooltip"))
		self.wndMain:FindChild("BankBuySlotBtn"):Enable(true)
	end
	self.wndMain:FindChild("BankBuyPrice"):SetAmount(nNextBankBagCost, true)
	self.wndMain:FindChild("PlayerMoney"):SetAmount(nPlayerCash)
end

function BankViewer:ResizeBankSlots()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		return
	end

	local nNumberOfBoxesPerRow = math.floor(self.wndMain:FindChild("MainBagWindow"):GetWidth() / knBagBoxSize)
	self.wndMain:FindChild("MainBagWindow"):SetBoxesPerRow(nNumberOfBoxesPerRow)

	-- Labels
	self:RefreshBagCount()

	-- Money
	local nNextBankBagCost = GameLib.GetNextBankBagCost():GetAmount()
	local nPlayerCash = GameLib.GetPlayerCurrency():GetAmount()
	self.wndMain:FindChild("PlayerMoney"):SetAmount(nPlayerCash)
	self.wndMain:FindChild("BankBuySlotBtn"):Enable(nNextBankBagCost <= nPlayerCash)
end

function BankViewer:OnBankViewerCloseBtn()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Close()
		self.wndMain:Destroy()
	end
end

function BankViewer:OnBankBuyConfirmClose()
	self.wndMain:FindChild("BankBuySlotBtn"):SetCheck(false)
end

function BankViewer:OnBankBuySlotConfirmYes()
	GameLib.BuyBankBagSlot()
	self.wndMain:FindChild("BankBuySlotBtn"):SetCheck(false)
	self:ResizeBankSlots()
end

function BankViewer:OnBankViewer_NewBagPurchasedAlert()
	if self.wndMain and self.wndMain:IsValid() then
		for idx, wndCurr in pairs(self.wndMain:FindChild("ConfigureBagsContainer"):GetChildren()) do
			wndCurr:FindChild("NewBagPurchasedAlert"):Show(false)
		end
		self.wndMain:FindChild("BankTitleText"):SetText(Apollo.GetString("Bank_Header"))
	end
end

function BankViewer:OnBankSlotPurchased()
	self.wndMain:FindChild("BankTitleText"):SetText(Apollo.GetString("Bank_BuySuccess"))
	Apollo.CreateTimer("BankViewer_NewBagPurchasedAlert", 12, false)
	self:Build()
end

function BankViewer:OnGenerateTooltip(wndControl, wndHandler, tType, item)
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then
		local itemEquipped = item:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	end
end

local BankViewerInst = BankViewer:new()
BankViewerInst:Init()
