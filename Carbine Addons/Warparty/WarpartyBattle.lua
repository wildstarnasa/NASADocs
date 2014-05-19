-----------------------------------------------------------------------------------------------
-- Client Lua Script for Warparty Boss Tokens
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GuildLib"
require "GuildTypeLib"
require "GroupLib"
require "GameLib"
require "MatchingGame"

---------------------------------------------------------------------------------------------------
-- WarpartyBattle module definition
---------------------------------------------------------------------------------------------------
local WarpartyBattle = {}

local kWidthOffset = 86
local kHeightOffset = 157
local kEntrySize = 50
local kMinimumCountX = 7
local kMinimumCountY = 5

local knSaveVersion = 1

function WarpartyBattle:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	self.bHasTokens = false
	self.bIsOpening = false
	self.nMaxIndex = 0

	return o
end

function WarpartyBattle:Init()
    Apollo.RegisterAddon(self)
end

function WarpartyBattle:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	local tSave =
	{
		tOffsets = self.wndMain and {self.wndMain:GetAnchorOffsets()} or self.tSavedOffsets,
		nSaveVersion = knSaveVersion,
	}
	
	return tSave
end

function WarpartyBattle:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then 
		return
	end
	
	if tSavedData.tOffsets then
		self.sOffsets = tSavedData.tOffsets;
	end
end

function WarpartyBattle:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("WarpartyBattle.xml")
    self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function WarpartyBattle:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end

	Apollo.RegisterEventHandler("WarPartyBattleOpen", 			"OnOpen", self)
	Apollo.RegisterEventHandler("WarPartyBattleClose", 			"OnClosed", self)
	Apollo.RegisterEventHandler("WarplotBattleStateChanged",	"OnBattleStateChanged", self)
	Apollo.RegisterEventHandler("WarPartyBossTokensUpdated", 	"OnBossTokensUpdated", self)
	Apollo.RegisterEventHandler("GuildResult", 					"OnGuildResult", self)
	Apollo.RegisterEventHandler("HousingEnterEditMode", 		"OnEnterEditMode", self)
	Apollo.RegisterEventHandler("HousingExitEditMode", 			"OnExitEditMode", self)
    
    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "WarpartyBattleForm", nil, self)
    self.wndMain:Show(false)

	local wndL, wndT, wndR, wndB = self.wndMain:GetAnchorOffsets()	
	wndL = (wndL + wndR - kWidthOffset) / 2
	wndT = (wndT + wndB - kHeightOffset) / 2
	wndR = wndL + kWidthOffset
	wndB = wndT + kHeightOffset
	
	HousingLib.SetEditMode(false)

	
	self.wndMain:SetAnchorOffsets(wndL, wndT, wndR, wndB)

	if self.sOffsets then
		self.wndMain:SetAnchorOffsets(unpack(self.sOffsets))
	end
	self.btnHousingDecorate = self.wndMain:FindChild("BGFooter"):FindChild("BtnHousingDecorate")
end

function WarpartyBattle:OnOpen(guildWarparty)
	if self.bHasTokens or not guildWarparty then
		self:UpdateTokenList(guildWarparty)
    	self.wndMain:Show(true)
	else
		self.bIsOpening = true
		guildWarparty:ListBossTokens()
	end
end

function WarpartyBattle:OnClosed()

	self.currentType = nil
	Apollo.StopTimer("RetryLoadingGuilds")
	if self.btnHousingDecorate:IsChecked() then
		HousingLib.SetEditMode(false)
		Event_FireGenericEvent("HousingExitEditMode")
	end
	self.wndMain:Close()
end

function WarpartyBattle:OnEnterEditMode()
	self.btnHousingDecorate:SetCheck(true)
end

function WarpartyBattle:OnExitEditMode()
	self.btnHousingDecorate:SetCheck(false)
end

function WarpartyBattle:OnBossTokensUpdated(guildWarparty)
	if guildWarparty == nil or guildWarparty:GetType() ~= GuildLib.GuildType_WarParty then
		return
	end

	self.bHasTokens = true
	if self.bIsOpening then
		self:UpdateTokenList(guildWarparty)
		self.wndMain:Show(true)
	elseif self.wndMain:IsShown() then
		self:UpdateTokenList(guildWarparty)
	end
	self.bIsOpening = false
end

function WarpartyBattle:OnGuildResult( guildWarparty, strName, nRank, eResult )
	if guildWarparty == nil or guildWarparty:GetType() ~= GuildLib.GuildType_WarParty then
		return
	end
	if self.bIsOpening and not self.wndMain:IsShown() then
		self.bIsOpening = false
		self.bHasTokens = true
		self:UpdateTokenList(guildWarparty)
		self.wndMain:Show(true)
	end
end

function WarpartyBattle:UpdateTokenList(guildWarparty)
	local nDisplayCount = 0

	if guildWarparty == nil or guildWarparty:GetType() ~= GuildLib.GuildType_WarParty then
		self.wndMain:SetData(nil)
		self:HelperHideExcessWindows(0)
		self.wndMain:FindChild('BtnHousingDecorate'):Enable(false)
	else	
		self.wndMain:SetData(guildWarparty)

		local arTokens = guildWarparty:GetBossTokens()

		local nTokenCount = #arTokens
		nDisplayCount = math.ceil(math.sqrt(nTokenCount))
		
		for nIndex = 1,nTokenCount do
			local itemBossToken = Item.GetDataFromId(arTokens[nIndex].nItemId)
			self:HelperDrawBossToken(itemBossToken, nIndex, arTokens[nIndex].nCount)		
		end
		
		self:HelperHideExcessWindows(nTokenCount)
		self.wndMain:FindChild('BtnHousingDecorate'):Enable(true)
	end
	
	local wndL, wndT, wndR, wndB = self.wndMain:GetAnchorOffsets()
	
	local nDisplayCountX = math.max(nDisplayCount, kMinimumCountX)
	local nDisplayCountY = math.max(nDisplayCount, kMinimumCountY)
		
	local nWidhtOffset = kWidthOffset + kEntrySize * nDisplayCountX
	local nHeightOffset = kHeightOffset + kEntrySize * nDisplayCountY

	wndL = (wndL + wndR - nWidhtOffset) / 2
	wndT = (wndT + wndB - nHeightOffset) / 2
	wndR = wndL + nWidhtOffset
	wndB = wndT + nHeightOffset
	
	self.wndMain:SetAnchorOffsets(wndL, wndT, wndR, wndB)

	local wndParent = self.wndMain:FindChild("BossTokenEntries")
	wndParent:ArrangeChildrenTiles(0)
end

function WarpartyBattle:GetBossTokenWnd(nIndex)
	local wndParent = self.wndMain:FindChild("BossTokenEntries")
	local wnd = wndParent:FindChildByUserData(nIndex)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, "BossTokenEntry", wndParent, self)
		wnd:SetData(nIndex)
	end
	if self.nMaxIndex < nIndex then
		self.nMaxIndex = nIndex
	end
	return wnd
end

function WarpartyBattle:HelperDrawBossToken(itemBossToken, nIndex, nStackCount)
	local wndItem = self:GetBossTokenWnd(nIndex)
	local wndItemBtn = wndItem:FindChild("BossTokenEntryIcon")
	wndItemBtn:SetData(itemBossToken)
	wndItemBtn:SetContentId(itemBossToken:GetItemId())
	wndItem:Show(true)
end

function WarpartyBattle:HelperHideExcessWindows(nLastValidIndex)
	local wndItem
	local nIndex = nLastValidIndex + 1
	while nIndex <= self.nMaxIndex do
		wndItem = self:GetBossTokenWnd(nIndex)
		wndItem:Show(false)
		nIndex = nIndex + 1
	end
end

---------------------------------------------------------------------------------------------------
-- WarpartyBattleForm Functions
---------------------------------------------------------------------------------------------------
function WarpartyBattle:OnCloseBtn(wndHandler, wndControl)
	self:OnClosed()
end

function WarpartyBattle:OnHousingDecorateChecked()
	Event_FireGenericEvent("DatachronDecorateBtn", false)
	Event_FireGenericEvent("HousingEnterEditMode")
end

function WarpartyBattle:OnHousingDecorateUnchecked()
    HousingLib.SetEditMode(false)
	Event_FireGenericEvent("HousingExitEditMode")
end

---------------------------------------------------------------------------------------------------
-- OnBattleStateChanged Functions
---------------------------------------------------------------------------------------------------
function WarpartyBattle:OnBattleStateChanged()
	local tBattleState = MatchingGame:GetWarPlotBattleState()
	for idx,tState in pairs(tBattleState) do
		local wndPlug = self.wndMain:FindChild("WndPlug" .. tostring(tState.nPlugIndex))
		if wndPlug ~= nil then
			local nPercHealth = tState.nCurrentHealth * 1.0 / tState.nMaxHealth
			local wndHp = wndPlug:FindChild("LblHealth")			
			wndHp:SetText(String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(100 * nPercHealth)))
			wndHp:SetTextColor(CColor.new( 1.0 - nPercHealth, nPercHealth, nPercHealth / 2, 1.0 ))
			
			wndPlug:FindChild("LblTier"):SetText( tostring(tState.nUpgradeTier) )			
		end
	end
end

---------------------------------------------------------------------------------------------------
-- WarpartyBattleForm Functions
---------------------------------------------------------------------------------------------------

function WarpartyBattle:OnBossTokens( wndHandler, wndControl, eMouseButton )
	local wndBossToken = self.wndMain:FindChild("BossTokenEntries")
	local wndWarplotLayout = self.wndMain:FindChild("WarplotLayout")
	wndBossToken:Show(true)
	wndWarplotLayout:Show(false)
end

function WarpartyBattle:OnWarplotLayout( wndHandler, wndControl, eMouseButton  )
	local wndBossToken = self.wndMain:FindChild("BossTokenEntries")
	local wndWarplotLayout = self.wndMain:FindChild("WarplotLayout")
	wndBossToken:Show(false)
	wndWarplotLayout:Show(true)
	self:OnBattleStateChanged()
end

---------------------------------------------------------------------------------------------------
-- BossTokenEntry Functions
---------------------------------------------------------------------------------------------------
function WarpartyBattle:OnGenerateTooltip(wndControl, wndHandler, eType, oArg1, oArg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemInstance then
		Tooltip.GetItemTooltipForm(self, wndControl, oArg1, {bPrimary = true})
	elseif eType == Tooltip.TooltipGenerateType_ItemData then
		Tooltip.GetItemTooltipForm(self, wndControl, oArg1, {bPrimary = true})
	elseif eType == Tooltip.TooltipGenerateType_GameCommand then
		xml = XmlDoc.new()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Macro then
		xml = XmlDoc.new()
		xml:AddLine(oArg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, oArg1)
	elseif eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	end
end

-----------------------------------------------------------------------------------------------
-- WarpartyBattleInstance
-----------------------------------------------------------------------------------------------
local WarpartyBattleInst = WarpartyBattle:new()
WarpartyBattleInst:Init()

