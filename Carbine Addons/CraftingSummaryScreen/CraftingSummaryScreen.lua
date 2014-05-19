-----------------------------------------------------------------------------------------------
-- Client Lua Script for CraftingSummaryScreen
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CraftingLib"

local CraftingSummaryScreen = {}

local ktDiscoveryHotOrColdString =
{
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Cold] 	= Apollo.GetString("Crafting_DiscoveryCold"),
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Warm] 	= Apollo.GetString("Crafting_DiscoveryWarm"),
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Hot] 		= Apollo.GetString("Crafting_DiscoveryHot"),
	[CraftingLib.CodeEnumCraftingDiscoveryHotCold.Success] 	= Apollo.GetString("Crafting_DiscoverySuccess"),
}

local knSaveVersion = 1
local knNumRandomCastBarFlavor = 12 -- This requires exact string naming: CraftingSummary_RandomFlavor_1, CraftingSummary_RandomFlavor_2, etc.

function CraftingSummaryScreen:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function CraftingSummaryScreen:Init()
    Apollo.RegisterAddon(self)
end

function CraftingSummaryScreen:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	--[[local tSave =
	{
		nSaveVersion = knSaveVersion,
	}
	return tSave]]--
end

function CraftingSummaryScreen:OnRestore(eType, tSavedData)
	--if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
	--end
end

function CraftingSummaryScreen:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CraftingSummaryScreen.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function CraftingSummaryScreen:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	math.randomseed(os.time())

	Apollo.RegisterEventHandler("GenericEvent_BotchCraft", 			"OnGenericEvent_BotchCraft", self)
	Apollo.RegisterEventHandler("GenericEvent_CraftSummaryMsg", 	"OnGenericEvent_CraftSummaryMsg", self)
	Apollo.RegisterEventHandler("GenericEvent_ClearCraftSummary", 	"OnGenericEvent_ClearCraftSummary", self)
	Apollo.RegisterEventHandler("GenericEvent_StartCraftCastBar", 	"OnGenericEvent_StartCraftCastBar", self)
	Apollo.RegisterEventHandler("CraftingSchematicComplete", 		"OnCraftingSchematicComplete", self)

	Apollo.RegisterTimerHandler("CraftingSummary_StationTimer", 	"OnCraftingSummary_StationTimer", self)
	Apollo.CreateTimer("CraftingSummary_StationTimer", 1, false)
	Apollo.StopTimer("CraftingSummary_StationTimer")

	-- These pump async into the text field
	Apollo.RegisterEventHandler("TradeSkillFloater", 				"OnTradeSkillFloater", self)
	Apollo.RegisterEventHandler("CraftingDiscoveryHotCold", 		"OnCraftingDiscoveryHotCold", self)
	Apollo.RegisterEventHandler("CraftingSchematicLearned", 		"OnCraftingSchematicLearned", self)
	Apollo.RegisterEventHandler("TradeskillAchievementUpdate", 		"OnTradeskillAchievementUpdate", self)
	Apollo.RegisterEventHandler("CraftingInterrupted",				"OnCraftingInterrupted", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "CraftingSummaryScreenForm", wndParent, self) -- Needs to start initialized so it can listen to messages
	self.wndMain:Show(false, true)
	self.wndCraftingCastBar = nil

	self.bBotchCraft = false
	self.strOnGoingMessage = ""
end

function CraftingSummaryScreen:OnCraftingSummary_StationTimer() -- Hackish: These are async from the rest of the UI (and definitely can't handle data being set)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	Apollo.StartTimer("CraftingSummary_StationTimer")

	local bResult = true
	local tSchematicInfo = CraftingLib.GetSchematicInfo(self.wndMain:GetData()) -- Data can be either a main or subschematic ID
	if not CraftingLib.IsAtCraftingStation() then
		bResult = false
	elseif tSchematicInfo then
		for idx, tMaterialData in pairs(tSchematicInfo.tMaterials) do
			if tMaterialData.nAmount > tMaterialData.itemMaterial:GetBackpackCount() then
				bResult = false
				break
			end
		end
	end

	self.wndMain:FindChild("CraftingSummaryRecraftBtn"):Enable(bResult)
end

-----------------------------------------------------------------------------------------------
-- Step One: Cast Bar
-----------------------------------------------------------------------------------------------

function CraftingSummaryScreen:OnGenericEvent_StartCraftCastBar(wndParent)
	if self.wndCraftingCastBar and self.wndCraftingCastBar:IsValid() then
		self.wndCraftingCastBar:Destroy()
	end

	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end

	self.wndCraftingCastBar = Apollo.LoadForm(self.xmlDoc, "CraftingCastBar", wndParent, self)
	self.wndCraftingCastBar:FindChild("CraftingCastBarFlavor"):SetText(Apollo.GetString("CraftingSummary_RandomFlavor_"..math.random(1, knNumRandomCastBarFlavor)) or "")
	self.wndCraftingCastBar:FindChild("CraftingProgBar"):SetProgress(1, 1 / 2.5) -- TODO Magic Number

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "CraftingSummaryScreenForm", wndParent, self)
	self.wndMain:Show(false, true)
end

function CraftingSummaryScreen:OnGenericEvent_ClearCraftSummary()
	self.strOnGoingMessage = ""
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("CraftingSummaryDetails"):SetAML("")
	end
end

-----------------------------------------------------------------------------------------------
-- Step Two: Main Draw Method
-----------------------------------------------------------------------------------------------

function CraftingSummaryScreen:OnCraftingInterrupted()
	if self.wndCraftingCastBar then
		self.wndCraftingCastBar:Destroy()
		self.wndCraftingCastBar = nil
	end

	self.bBotchCraft = true
	self:OnClose()
end

function CraftingSummaryScreen:OnCraftingSchematicComplete(idSchematic, bPass, nEarnedXp, arMaterialReturnedIds, idSchematicCrafted, idItemCrafted) -- Main starting method
	if idItemCrafted == 0 then--no item was made
		return
	end
	
	if self.wndCraftingCastBar then
		self.wndCraftingCastBar:Destroy()
		self.wndCraftingCastBar = nil
	end

	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if self.bBotchCraft then -- Skip entire UI if botch craft (e.g. Abandon Button)
		self.bBotchCraft = false
		return
	end

	local tSchemInfo = CraftingLib.GetSchematicInfo(idSchematicCrafted) -- GOTCHA: idSchematicCrafted vs idSchematic
	if tSchemInfo and tSchemInfo.eTradeskillId == CraftingLib.CodeEnumTradeskill.Runecrafting then
		return
	end

	self.wndMain:ToFront()
	self.wndMain:Show(true)
	self.wndMain:SetData(idSchematic)
	self.wndMain:FindChild("CraftingSummaryRecraftBtn"):SetData(idSchematic)

	-- Draw Pass / Fail
	if tSchemInfo then
		local itemSchem = tSchemInfo.itemOutput
		if bPass then
			self.wndMain:FindChild("CraftingSummaryItemIcon"):SetSprite(itemSchem:GetIcon())
			self.wndMain:FindChild("CraftingSummaryResultsTitle"):SetTextColor("UI_WindowTitleYellow")
			self.wndMain:FindChild("CraftingSummaryResultsTitle"):SetText(String_GetWeaselString(Apollo.GetString("CraftSummary_CraftingSuccess"), itemSchem:GetName()))
			Tooltip.GetItemTooltipForm(self, self.wndMain:FindChild("CraftingSummaryItemIcon"), itemSchem, {itemCompare = itemSchem:GetEquippedItemForItemType()})
			Sound.Play(Sound.PlayUICraftingSuccess)
		else
			self.wndMain:FindChild("CraftingSummaryItemIcon"):SetSprite("ClientSprites:LootCloseBox")
			self.wndMain:FindChild("CraftingSummaryResultsTitle"):SetTextColor("AddonError")
			self.wndMain:FindChild("CraftingSummaryResultsTitle"):SetText(String_GetWeaselString(Apollo.GetString("CraftingSummary_CraftFailedText"), itemSchem:GetName()))
			self.wndMain:FindChild("CraftingSummaryItemIcon"):SetTooltip(Apollo.GetString("CraftingSummary_CraftFailedTooltip"))
			Sound.Play(Sound.PlayUICraftingFailure)
		end

		-- XP Bar
		local tTradeskillInfo = CraftingLib.GetTradeskillInfo(tSchemInfo.eTradeskillId)
		self.wndMain:FindChild("CraftingSummaryXPProgBG"):Show(nEarnedXp > 0)

		if nEarnedXp > 0 then -- Assume crafts will always give > 0 xp at non-max tiers
			local nCurrXP = tTradeskillInfo.nXp
			local nNextXP = tTradeskillInfo.nXpForNextTier
			local strProgText = String_GetWeaselString(Apollo.GetString("CraftingSummary_ProgressText"), nEarnedXp, tTradeskillInfo.strName, nCurrXP, nNextXP)
			self.wndMain:FindChild("CraftingSummaryXPProgBar"):SetMax(nNextXP)
			self.wndMain:FindChild("CraftingSummaryXPProgBar"):SetProgress(nCurrXP)
			self.wndMain:FindChild("CraftingSummaryXPProgBar"):EnableGlow(nCurrXP > 0 and nCurrXP < nNextXP)
			self.wndMain:FindChild("CraftingSummaryXPProgText"):SetText(strProgText)
			self.wndMain:FindChild("CraftingSummaryXPProgText"):SetTooltip(strProgText .. "\n" .. Apollo.GetString("CraftingSummary_TierUnlockTooltip"))
		end
	end

	local nLeft, nRight, nTop, nBottom = self.wndMain:FindChild("CraftingSummaryDetailsScroll"):GetAnchorOffsets()
	self.wndMain:FindChild("CraftingSummaryDetailsScroll"):SetAnchorOffsets(nLeft, nRight, nTop, self.wndMain:FindChild("CraftingSummaryXPProgBG"):IsVisible() and -70 or 0)

	-- Summary Detail Messages
	if arMaterialReturnedIds then
		for idx, nReturnedId in pairs(arMaterialReturnedIds) do
			local itemObject = Item.GetDataFromId(nReturnedId)
			if itemObject then
				self:HelperWriteToCraftingSummaryDetails(String_GetWeaselString(Apollo.GetString("CraftingSummary_ReturnedMaterials"), itemObject:GetName()))
			end
		end
	end
	self:HelperWriteToCraftingSummaryDetails("")

	-- Start station timer and check immediately, so it doesn't flash enabled/disabled for a second
	Apollo.CreateTimer("CraftingSummary_StationTimer", 1, false)
	self:OnCraftingSummary_StationTimer()
end

-----------------------------------------------------------------------------------------------
-- UI Interaction
-----------------------------------------------------------------------------------------------

function CraftingSummaryScreen:OnCraftingSummaryRecraftBtn(wndHandler, wndControl) -- Data is idSchematic
	self:OnClose()

	local idSchematic = wndHandler:GetData()
	local tSchematicInfo = CraftingLib.GetSchematicInfo(idSchematic)
	if not tSchematicInfo then
		return
	end

	if tSchematicInfo.bIsAutoCraft then
		Event_FireGenericEvent("AlwaysShowTradeskills")
	else
		Event_FireGenericEvent("GenericEvent_CraftFromPL", idSchematic)
	end
end

function CraftingSummaryScreen:OnCraftingSummaryOkBtn(wndHandler, wndControl)
	if wndHandler == wndControl then
		Event_FireGenericEvent("GenericEvent_CraftingSummaryIsFinished")
		self:OnClose()
	end
end

function CraftingSummaryScreen:OnCraftingSummaryCloseBtn(wndHandler, wndControl)
	if wndHandler == wndControl then
		self:OnClose()
	end
end

function CraftingSummaryScreen:OnClose()
	self.wndMain:Show(false)
end

---------------------------------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------------------------------

function CraftingSummaryScreen:HelperWriteToCraftingSummaryDetails(strMessage)
	-- Add a line break if not the first
	if strMessage ~= "" and self.strOnGoingMessage ~= "" and string.len(strMessage) > 0 and string.len(self.strOnGoingMessage) > 0 then
		strMessage = strMessage .. "<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"0\">.</P>"
	end

	if strMessage ~= "" and string.len(strMessage) > 0 then
		local strFont = "<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloBody\">"
		self.strOnGoingMessage = string.format("%s%s</P>%s%s</P>", strFont, strMessage, strFont, self.strOnGoingMessage or "")
	end

	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("CraftingSummaryDetails"):SetAML(self.strOnGoingMessage)
		self.wndMain:FindChild("CraftingSummaryDetails"):SetHeightToContentHeight()
		self.wndMain:FindChild("CraftingSummaryDetailsScroll"):RecalculateContentExtents()
	end
end

function CraftingSummaryScreen:OnCraftingDiscoveryHotCold(eHotCold, eDirection)
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	local tSchematicInfo = tCurrentCraft and tCurrentCraft.nSchematicId and CraftingLib.GetSchematicInfo(tCurrentCraft.nSchematicId)
	local tInfo = tSchematicInfo and CraftingLib.GetTradeskillInfo(tSchematicInfo.eTradeskillId)

	local strLineTwo = ""
	if tInfo and tInfo.tAxisNames and eDirection ~= CraftingLib.CodeEnumCraftingDirection.None and eHotCold ~= CraftingLib.CodeEnumCraftingDiscoveryHotCold.Success then
		local tAxisNames = tInfo.tAxisNames -- R, T, L, B
		local tMapping =
		{
			tAxisNames[1],
			tAxisNames[2],
			tAxisNames[3],
			tAxisNames[4],
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[1], tAxisNames[2]),
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[1], tAxisNames[4]),
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[3], tAxisNames[2]),
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[3], tAxisNames[4]),
		}
		strLineTwo = String_GetWeaselString(Apollo.GetString("Crafting_DiscoveryMore"), tostring(tMapping[eDirection]))
	end

	-- Discovery Result: Warm!
	-- Need more: Spicy
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", ktDiscoveryHotOrColdString[eHotCold] .. " " .. strLineTwo)
	self:HelperWriteToCraftingSummaryDetails(ktDiscoveryHotOrColdString[eHotCold] .. "\n" .. strLineTwo .. "\n")
end

function CraftingSummaryScreen:OnTradeskillAchievementUpdate(achUpdated, nValueCurr, nValueNeeded)
	if nValueNeeded == 0 then
		return
	end
	self:HelperWriteToCraftingSummaryDetails(String_GetWeaselString(Apollo.GetString("Crafting_AchievementProgress"), achUpdated:GetName(), nValueCurr, nValueNeeded))
end

function CraftingSummaryScreen:OnCraftingSchematicLearned(idTradeskill, idSchematic)
	local tSchemInfo = CraftingLib.GetSchematicInfo(idSchematic)
	self:HelperWriteToCraftingSummaryDetails(String_GetWeaselString(Apollo.GetString("Crafting_NewSchematic"), tSchemInfo.strName))
end

function CraftingSummaryScreen:OnTradeSkillFloater(unitAttach, strMessage)
	self:HelperWriteToCraftingSummaryDetails(strMessage)
end

function CraftingSummaryScreen:OnGenericEvent_CraftSummaryMsg(strMessage) -- From Lua
	self:HelperWriteToCraftingSummaryDetails(strMessage)
end

function CraftingSummaryScreen:OnGenericEvent_BotchCraft()
	self.bBotchCraft = true -- Skip entire UI if botch craft (e.g. Abandon Button)
end

local CraftingSummaryScreenInst = CraftingSummaryScreen:new()
CraftingSummaryScreenInst:Init()
