-----------------------------------------------------------------------------------------------
-- Client Lua Script for TradeskillTrainer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "XmlDoc"
require "Apollo"
require "CraftingLib"


local TradeskillTrainer = {}

local knMaxTradeskills = 2 -- how many skills is the player allowed to learn

function TradeskillTrainer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TradeskillTrainer:Init()
    Apollo.RegisterAddon(self)
end

function TradeskillTrainer:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("TradeskillTrainer.xml")
    self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function TradeskillTrainer:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end

	Apollo.RegisterEventHandler("InvokeTradeskillTrainerWindow", "OnInvokeTradeskillTrainer", self)
	Apollo.RegisterEventHandler("CloseTradeskillTrainerWindow", "OnClose", self)

	self.nActiveTradeskills = 0
end

function TradeskillTrainer:OnInvokeTradeskillTrainer(unitTrainer)
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "TradeskillTrainerForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("DialogResponse_TradskillTraining")})

		if self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
	end

	self.nActiveTradeskills = 0
	self.wndMain:FindChild("ListContainer"):DestroyChildren()

	self.wndMain:FindChild("SwapTradeskillBtn1"):SetData(nil)
	self.wndMain:FindChild("SwapTradeskillBtn2"):SetData(nil)

	for idx, tTradeskill in ipairs(unitTrainer:GetTrainerTradeskills()) do
		local tInfo = CraftingLib.GetTradeskillInfo(tTradeskill.eTradeskillId)
		if not tInfo.bIsHobby then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "ProfListItem", self.wndMain:FindChild("ListContainer"), self)
			wndCurr:FindChild("ListItemBtn"):SetData(tTradeskill.eTradeskillId)
			wndCurr:FindChild("ListItemText"):SetText(tInfo.strName)
			wndCurr:FindChild("ListItemCheck"):Show(tInfo.bIsActive)

			if tInfo.bIsActive then
				self.nActiveTradeskills = self.nActiveTradeskills + 1

				if self.wndMain:FindChild("SwapTradeskillBtn1"):GetData() == nil then
					self.wndMain:FindChild("SwapTradeskillBtn1"):SetData(tTradeskill.eTradeskillId)
					self.wndMain:FindChild("SwapTradeskillBtn1"):SetText(String_GetWeaselString(Apollo.GetString("TradeskillTrainer_SwapWith"), tInfo.strName))
				else
					self.wndMain:FindChild("SwapTradeskillBtn2"):SetData(tTradeskill.eTradeskillId)
					self.wndMain:FindChild("SwapTradeskillBtn2"):SetText(String_GetWeaselString(Apollo.GetString("TradeskillTrainer_SwapWith"), tInfo.strName))
				end
			end
		end
	end

	for idx, tTradeskill in ipairs(CraftingLib.GetKnownTradeskills()) do
		local tInfo = CraftingLib.GetTradeskillInfo(tTradeskill.eId)
		if tInfo.bIsHobby and tTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Farmer then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "HobbyListItem", self.wndMain:FindChild("ListContainer"), self)
			wndCurr:FindChild("ListItemBtn"):SetData(tTradeskill.eId)
			wndCurr:FindChild("ListItemText"):SetText(tInfo.strName)
			wndCurr:FindChild("ListItemCheck"):Show(true)
		end
	end

	self.wndMain:FindChild("ListContainer"):ArrangeChildrenVert(0)
end

function TradeskillTrainer:OnClose()
	if self.wndMain then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
	Event_CancelTradeskillTraining()
end

function TradeskillTrainer:OnWindowClosed(wndHandler, wndControl)
	self:OnClose()
end

function TradeskillTrainer:OnProfListItemClick(wndHandler, wndControl) -- wndHandler is "ListItemBtn", data is tradeskill id
	for key, wndCurr in pairs(self.wndMain:FindChild("BGLeft:ListContainer"):GetChildren()) do
		if wndCurr:FindChild("ListItemBtn") then
			wndCurr:FindChild("ListItemBtn"):SetCheck(false)
			if wndCurr:GetName() == "HobbyListItem" then
				wndCurr:FindChild("ListItemBtn:ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))
			else
				wndCurr:FindChild("ListItemBtn:ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
			end
		end
	end
	wndHandler:SetCheck(true)
	wndHandler:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))

	-- Main's right panel formatting
	local idTradeskill = wndHandler:GetData()
	local bAtMax = self.nActiveTradeskills == knMaxTradeskills
	local tTradeskillInfo = CraftingLib.GetTradeskillInfo(idTradeskill)	
	local bAlreadyKnown = wndHandler:FindChild("ListItemCheck"):IsShown()

	self.wndMain:FindChild("RightContainer:BottomBG:AlreadyKnown"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:HobbyMessage"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:CooldownLocked"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:SwapContainer"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:LearnTradeskillBtn"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:LearnTradeskillBtn"):SetData(wndHandler:GetData()) -- Also used in Swap
	self.wndMain:FindChild("RightContainer:BottomBG:FullDescription"):SetText(tTradeskillInfo.strDescription)

	local nCooldownCurrent = CraftingLib.GetRelearnCooldown() or 0
	local nCooldownNew = tTradeskillInfo and tTradeskillInfo.nRelearnCooldownDays or 0
	if nCooldownCurrent > 0 then
		local strCooldownText = ""
		if nCooldownCurrent < 1 then
			strCooldownText = Apollo.GetString("TradeskillTrainer_SwapOnCooldownShort")
		else
			strCooldownText = String_GetWeaselString(Apollo.GetString("TradeskillTrainer_SwapOnCooldown"), tostring(math.floor(nCooldownCurrent + 0.5)))
		end
		self.wndMain:FindChild("RightContainer:BottomBG:CooldownLocked"):Show(true)
		self.wndMain:FindChild("RightContainer:BottomBG:CooldownLocked:CooldownLockedText"):SetText(strCooldownText)
	elseif bAlreadyKnown then
		self.wndMain:FindChild("RightContainer:BottomBG:AlreadyKnown"):Show(true)
	elseif bAtMax and not bAlreadyKnown then
		local nRelearnCost = CraftingLib.GetRelearnCost(idTradeskill):GetAmount()
		local strCooldown = String_GetWeaselString(Apollo.GetString("Tradeskill_Trainer_CooldownDynamic"), nCooldownNew)
		local strCooldownTooltip = String_GetWeaselString(Apollo.GetString("Tradeskill_Trainer_CooldownDynamicTooltip"), nCooldownNew)

		local wndSwapContainer = self.wndMain:FindChild("RightContainer:BottomBG:SwapContainer")
		wndSwapContainer:Show(true)
		wndSwapContainer:FindChild("CostWindow"):Show(nRelearnCost > 0 or nCooldownNew > 0)
		wndSwapContainer:FindChild("CostWindow:SwapCashWindow"):SetAmount(nRelearnCost)
		wndSwapContainer:FindChild("SwapTimeWarningContainer"):Show(nRelearnCost > 0 or nCooldownNew > 0)
		wndSwapContainer:FindChild("SwapTimeWarningContainer"):SetTooltip(strCooldownTooltip)
		wndSwapContainer:FindChild("SwapTimeWarningContainer:SwapTimeWarningLabel"):SetText(strCooldown)
	elseif not bAtMax and not bAlreadyKnown then
		self.wndMain:FindChild("LearnTradeskillBtn"):Show(true)
	end

	-- Current Craft Blocker
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	self.wndMain:FindChild("RightContainer:BottomBG:BotchCraftBlocker"):Show(tCurrentCraft and tCurrentCraft.nSchematicId)
end

function TradeskillTrainer:OnHobbyListItemClick(wndHandler, wndControl)
	for key, wndCurr in pairs(self.wndMain:FindChild("ListContainer"):GetChildren()) do
		if wndCurr:FindChild("ListItemBtn") then
			wndCurr:FindChild("ListItemBtn"):SetCheck(false)
			if wndCurr:GetName() == "HobbyListItem" then
				wndCurr:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))
			else
				wndCurr:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
			end
		end
	end
	wndHandler:SetCheck(true)
	wndHandler:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))

	-- Main's right panel formatting
	self.wndMain:FindChild("AlreadyKnown"):Show(false)
	self.wndMain:FindChild("CooldownLocked"):Show(false)
	self.wndMain:FindChild("SwapContainer"):Show(false)
	self.wndMain:FindChild("LearnTradeskillBtn"):Show(false)
	self.wndMain:FindChild("FullDescription"):SetText(CraftingLib.GetTradeskillInfo(wndHandler:GetData()).strDescription)

	self.wndMain:FindChild("HobbyMessage"):Show(true)
end

function TradeskillTrainer:OnLearnTradeskillBtn(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local nCurrentTradeskill = self.wndMain:FindChild("LearnTradeskillBtn"):GetData()
	local tCurrTradeskillInfo = CraftingLib.GetTradeskillInfo(nCurrentTradeskill)
		if not tCurrTradeskillInfo.bIsHarvesting then
			Event_FireGenericEvent("TradeskillLearnedFromTHOR")
		else
	end
	CraftingLib.LearnTradeskill(nCurrentTradeskill)
	self:OnClose()
end

function TradeskillTrainer:OnSwapTradeskillBtn(wndHandler, wndControl) --SwapTradeskillBtn1 or SwapTradeskillBtn2, data is nTradeskillId
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local nCurrentTradeskill = self.wndMain:FindChild("LearnTradeskillBtn"):GetData()
	local tCurrTradeskillInfo = CraftingLib.GetTradeskillInfo(nCurrentTradeskill)
		if not tCurrTradeskillInfo.bIsHarvesting then
			Event_FireGenericEvent("TradeskillLearnedFromTHOR")
		else
	end

	CraftingLib.LearnTradeskill(nCurrentTradeskill, wndHandler:GetData())
	self:OnClose()
end

local TradeskillTrainerInst = TradeskillTrainer:new()
TradeskillTrainerInst:Init()
