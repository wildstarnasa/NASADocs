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

	o.tWndRefs = {}

    return o
end

function CraftingSummaryScreen:Init()
    Apollo.RegisterAddon(self)
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

	-- These pump async into the text field
	Apollo.RegisterEventHandler("TradeSkillFloater", 				"OnTradeSkillFloater", self)
	Apollo.RegisterEventHandler("CraftingDiscoveryHotCold", 		"OnCraftingDiscoveryHotCold", self)
	Apollo.RegisterEventHandler("CraftingSchematicLearned", 		"OnCraftingSchematicLearned", self)
	Apollo.RegisterEventHandler("TradeskillAchievementUpdate", 		"OnTradeskillAchievementUpdate", self)
	Apollo.RegisterEventHandler("CraftingInterrupted",				"OnCraftingInterrupted", self)

	self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "CraftingSummaryScreenForm", wndParent, self) -- Needs to start initialized so it can listen to messages
	self.tWndRefs.wndMain:Show(false, true)
	self.tWndRefs.wndCraftingCastBar = nil

	self.itemTooltipOverride = nil
	self.bBotchCraft = false
	self.strOnGoingMessage = ""
end

function CraftingSummaryScreen:OnCraftingSummary_StationTimer() -- Hackish: These are async from the rest of the UI (and definitely can't handle data being set)
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsVisible() then
		return
	end

	----timers currently can't be started during their callbacks, because of a Code bug.
	self.timerStation = ApolloTimer.Create(1.0, false, "OnCraftingSummary_StationTimer", self)

	local bResult = true
	local tSchematicInfo = CraftingLib.GetSchematicInfo(self.tWndRefs.wndMain:GetData()) -- Data can be either a main or subschematic ID
	if not CraftingLib.IsAtCraftingStation() then
		bResult = false
	elseif tSchematicInfo then
		for idx, tMaterialData in pairs(tSchematicInfo.tMaterials) do
			if tMaterialData.nAmount > (tMaterialData.itemMaterial:GetBackpackCount() + tMaterialData.itemMaterial:GetBankCount()) then
				bResult = false
				break
			end
		end
	end

	self.tWndRefs.wndMain:FindChild("CraftingSummaryRecraftBtn"):Enable(bResult)
end

-----------------------------------------------------------------------------------------------
-- Step One: Cast Bar
-----------------------------------------------------------------------------------------------

function CraftingSummaryScreen:OnGenericEvent_StartCraftCastBar(wndParent, itemOutput)
	if self.tWndRefs.wndCraftingCastBar and self.tWndRefs.wndCraftingCastBar:IsValid() then
		self.tWndRefs.wndCraftingCastBar:Destroy()
	end

	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
	end

	self.tWndRefs.wndCraftingCastBar = Apollo.LoadForm(self.xmlDoc, "CraftingCastBar", wndParent, self)
	self.tWndRefs.wndCraftingCastBar:FindChild("CraftingCastBarFlavor"):SetText(Apollo.GetString("CraftingSummary_RandomFlavor_"..math.random(1, knNumRandomCastBarFlavor)) or "")
	self.tWndRefs.wndCraftingCastBar:FindChild("CraftingProgBar"):SetProgress(1, 1 / 2.5) -- TODO Magic Number

	self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "CraftingSummaryScreenForm", wndParent, self)
	self.tWndRefs.wndMain:Show(false, true)

	self.itemTooltipOverride = itemOutput -- Technically this is the most accurate
end

function CraftingSummaryScreen:OnGenericEvent_ClearCraftSummary()
	self.strOnGoingMessage = ""
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:FindChild("CraftingSummaryDetails"):SetAML("")
	end
end

-----------------------------------------------------------------------------------------------
-- Step Two: Main Draw Method
-----------------------------------------------------------------------------------------------

function CraftingSummaryScreen:OnCraftingInterrupted()
	if self.tWndRefs.wndCraftingCastBar then
		self.tWndRefs.wndCraftingCastBar:Destroy()
		self.tWndRefs.wndCraftingCastBar = nil
	end

	Event_FireGenericEvent("GenericEvent_LootChannelMessage", Apollo.GetString("CoordCrafting_MovementInterrupt"))

	self.bBotchCraft = true
	self:OnClose()
end

function CraftingSummaryScreen:OnCraftingSchematicComplete(idSchematic, bPass, nEarnedXp, arMaterialReturnedIds, idSchematicCrafted, idItemCrafted) -- Main starting method
	if idItemCrafted == 0 then -- No item was made
		return
	end

	if self.tWndRefs.wndCraftingCastBar then
		self.tWndRefs.wndCraftingCastBar:Destroy()
		self.tWndRefs.wndCraftingCastBar = nil
	end

	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then -- GOTCHA: This is possible if the parent UI was deleted
		self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "CraftingSummaryScreenForm", nil, self)
	end

	if self.bBotchCraft then -- Skip entire UI if botch craft (e.g. Abandon Button)
		self.bBotchCraft = false
		return
	end

	self.tWndRefs.wndMain:Invoke()
	self.tWndRefs.wndMain:SetData(idSchematic)
	self.tWndRefs.wndMain:FindChild("CraftingSummaryRecraftBtn"):SetData(idSchematic)

	-- Draw Pass / Fail
	local tSchemInfo = CraftingLib.GetSchematicInfo(idSchematicCrafted) -- GOTCHA: idSchematicCrafted vs idSchematic
	if tSchemInfo then
		if bPass then
			-- self.itemTooltipOverride will cover any modded items so they display correctly, while tSchemInfo.itemOutput covers simple crafts (which won't have an override).
			local itemTooltip = self.itemTooltipOverride or tSchemInfo.itemOutput
			self.tWndRefs.wndMain:FindChild("CraftingSummaryItemIcon"):SetSprite(tSchemInfo.itemOutput:GetIcon())
			self.tWndRefs.wndMain:FindChild("CraftingSummaryResultsTitle"):SetTextColor("UI_TextHoloTitle")
			self.tWndRefs.wndMain:FindChild("CraftingSummaryResultsTitle"):SetText(String_GetWeaselString(Apollo.GetString("CraftSummary_CraftingSuccess"), tSchemInfo.itemOutput:GetName()))
			Tooltip.GetItemTooltipForm(self, self.tWndRefs.wndMain:FindChild("CraftingSummaryItemIcon"), itemTooltip, {itemCompare = itemTooltip:GetEquippedItemForItemType()})
			Sound.Play(Sound.PlayUICraftingSuccess)
		else
			self.tWndRefs.wndMain:FindChild("CraftingSummaryItemIcon"):SetSprite("ClientSprites:LootCloseBox")
			self.tWndRefs.wndMain:FindChild("CraftingSummaryResultsTitle"):SetTextColor("xkcdReddish")
			self.tWndRefs.wndMain:FindChild("CraftingSummaryResultsTitle"):SetText(String_GetWeaselString(Apollo.GetString("CraftingSummary_CraftFailedText"), tSchemInfo.itemOutput:GetName()))
			self.tWndRefs.wndMain:FindChild("CraftingSummaryItemIcon"):SetTooltip(Apollo.GetString("CraftingSummary_CraftFailedTooltip"))
			Sound.Play(Sound.PlayUICraftingFailure)
		end

		-- XP Bar
		local tTradeskillInfo = CraftingLib.GetTradeskillInfo(tSchemInfo.eTradeskillId)
		self.tWndRefs.wndMain:FindChild("CraftingSummaryXPProgBG"):Show(nEarnedXp > 0)

		if nEarnedXp > 0 then -- Assume crafts will always give > 0 xp at non-max tiers
			local nCurrXP = tTradeskillInfo.nXp
			local nNextXP = tTradeskillInfo.nXpForNextTier
			local strProgText = String_GetWeaselString(Apollo.GetString("CraftingSummary_ProgressText"), nEarnedXp, tTradeskillInfo.strName, nCurrXP + nEarnedXp, nNextXP)
			self.tWndRefs.wndMain:FindChild("CraftingSummaryXPProgBar"):SetMax(nNextXP)
			self.tWndRefs.wndMain:FindChild("CraftingSummaryXPProgBar"):SetProgress(nCurrXP)
			self.tWndRefs.wndMain:FindChild("CraftingSummaryXPProgBar"):EnableGlow(nCurrXP > 0 and nCurrXP < nNextXP)
			self.tWndRefs.wndMain:FindChild("CraftingSummaryXPProgText"):SetText(strProgText)
			self.tWndRefs.wndMain:FindChild("CraftingSummaryXPProgText"):SetTooltip(strProgText .. "\n" .. Apollo.GetString("CraftingSummary_TierUnlockTooltip"))
		end
	end

	local nLeft, nRight, nTop, nBottom = self.tWndRefs.wndMain:FindChild("CraftingSummaryDetailsScroll"):GetAnchorOffsets()
	self.tWndRefs.wndMain:FindChild("CraftingSummaryDetailsScroll"):SetAnchorOffsets(nLeft, nRight, nTop, self.tWndRefs.wndMain:FindChild("CraftingSummaryXPProgBG"):IsVisible() and -85 or -7)

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
	Event_FireGenericEvent("GenericEvent_CraftingSummary_Closed")
	self.tWndRefs.wndMain:Close()
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

	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:FindChild("CraftingSummaryDetails"):SetAML(self.strOnGoingMessage)
		self.tWndRefs.wndMain:FindChild("CraftingSummaryDetails"):SetHeightToContentHeight()
		self.tWndRefs.wndMain:FindChild("CraftingSummaryDetailsScroll"):RecalculateContentExtents()
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
			tAxisNames[2],
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[1], tAxisNames[2]),
			tAxisNames[1],
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[1], tAxisNames[4]),
			tAxisNames[4],
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[3], tAxisNames[4]),
			tAxisNames[3],
			String_GetWeaselString(Apollo.GetString("CoordCrafting_AxisCombine"), tAxisNames[3], tAxisNames[2]),
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
