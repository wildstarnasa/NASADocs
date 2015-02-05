-----------------------------------------------------------------------------------------------
-- Client Lua Script for RuneSets
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local RuneSets = {}

function RuneSets:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RuneSets:Init()
    Apollo.RegisterAddon(self)
end

function RuneSets:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RuneSets.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function RuneSets:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenu_ToggleSets", 	"RedrawSets", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 	"OnUpdateEvent", self)
	Apollo.RegisterEventHandler("ItemModified", 				"OnUpdateEvent", self)
	Apollo.RegisterEventHandler("ToggleCharacterWindow", 		"OnToggleCharacterWindow", self)
end

-----------------------------------------------------------------------------------------------
-- Sets
-----------------------------------------------------------------------------------------------

function RuneSets:RedrawSets(wndParent)
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "RuneSetsForm", wndParent, self)
		if self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
	end

	-- Sets from equipped items only
	local tListOfSets = {}
	local bHeaderBag = true -- TODO
	local bHeaderEquipped = true -- TODO
	for idx, itemCurr in pairs(CraftingLib.GetItemsWithRuneSlots(bHeaderEquipped, bHeaderBag)) do
		for idx2, tSetInfo in ipairs(itemCurr:GetSetBonuses()) do
			if tSetInfo and tSetInfo.strName and not tListOfSets[tSetInfo.strName] then
				tListOfSets[tSetInfo.strName] = tSetInfo
			end
		end
	end

	-- Current Runes
	for idx, itemRune in pairs(CraftingLib.GetValidRuneItems()) do
		local tMicrochipData = itemRune:GetMicrochipInfo()
		for idx, tSetInfo in pairs(tMicrochipData.tSet or {}) do
			if tSetInfo and tSetInfo.strName and not tListOfSets[tSetInfo.strName] then
				tSetInfo.nPower = 0 -- HACK
				tListOfSets[tSetInfo.strName] = tSetInfo
			end
		end
	end

	-- Draw sets now
	local strFullText = ""
	local kstrLineBreak = "<P Font=\"CRB_InterfaceLarge_B\" TextColor=\"0\">.</P>" -- TODO TEMP HACK
	for idx, tSetInfo in pairs(tListOfSets) do
		local strLocalSetText = string.format("<P Font=\"CRB_InterfaceLarge\" TextColor=\"UI_TextHoloTitle\">%s</P>",
		String_GetWeaselString(Apollo.GetString("EngravingStation_RuneSetText"), tSetInfo.strName, tSetInfo.nPower, tSetInfo.nMaxPower))

		local tBonuses = tSetInfo.arBonuses
		table.sort(tBonuses, function(a,b) return a.nPower < b.nPower end)

		for idx3, tBonusInfo in pairs(tBonuses) do
			-- tBonusInfo.active, tBonusInfo.power, tBonusInfo.spell:GetFlavor()
			local strLocalColor = tBonusInfo.bIsActive and "ItemQuality_Good" or "UI_TextHoloBody"
			strLocalSetText = string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</P><P TextColor=\"0\">.</P>", strLocalSetText, strLocalColor,
			String_GetWeaselString(Apollo.GetString("Tooltips_RuneDetails"), tBonusInfo.nPower, tBonusInfo.splBonus:GetName(), tBonusInfo.splBonus:GetFlavor() or ""))

		end

		strFullText = strFullText .. kstrLineBreak .. strLocalSetText
	end

	self.wndMain:FindChild("SetsListNormalText"):SetAML(strFullText)
	self.wndMain:FindChild("SetsListNormalText"):SetHeightToContentHeight()
	self.wndMain:FindChild("SetsListContainer"):RecalculateContentExtents()
	self.wndMain:FindChild("SetsListContainer"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("SetsListEmptyText"):Show(strFullText == "")
end

function RuneSets:OnSetsClose(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end
end

function RuneSets:OnUpdateEvent()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then -- Will consider parents as well
		return
	end
	self:RedrawSets()
end

function RuneSets:OnToggleCharacterWindow()
	if not self.wndMain or not self.wndMain:IsValid() then -- Doesn't care about visibility (as it's false while being opened)
		return
	end
	self:RedrawSets()
end

local RuneSetsInst = RuneSets:new()
RuneSetsInst:Init()
lo.RegisterEventHandler("KeyBindingKeyChanged", "OnKeyBindingUpdated", self)
		return Apollo.AddonLoadStatus.Loaded
	end
	return Apollo.AddonLoadStatus.Loading 
end

function RewardIcons:OnKeyBindingUpdated(strKeybind)
	if strKeybind ~= "Path Action" and strKeybind ~= "Cast Objective Ability" then
		return
	end

	self.strPathActionKeybind = GameLib.GetKeyBinding("PathAction")
	self.bPathActionUsesIcon = false
	if self.strPathActionKeybind == "Unbound" or #self.strPathActionKeybind > 1 then -- Don't show interact
		self.bPathActionUsesIcon = true
	end

	self.strQuestActionKeybind = GameLib.GetKeyBinding("CastObjectiveAbility")
	self.bQuestActionUsesIcon = false
	if self.strQuestActionKeybind == "Unbound" or #self.strQuestActionKeybind > 1 then -- Don't show interact
		self.bQuestActionUsesIcon = true
	end
end

function RewardIcons:HelperDrawRewardTooltip(tRewardInfo, wndRewardIcon, strBracketText, strUnitName, tRewardString)
	if not tRewardInfo or not wndRewardIcon then
		return
	end
	tRewardString = tRewardString or ""

	local strMessage = tRewardInfo.strTitle
	if tRewardInfo.pmMission and tRewardInfo.pmMission:GetName() then
		local pmMission = tRewardInfo.pmMission
		if tRewardInfo.bIsActivated and PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Explorer then -- todo: see if we can remove this requirement
			strMessage = String_GetWeaselString(Apollo.GetString("Nameplates_ActivateForMission"), pmMission:GetName())
		else
			strMessage = String_GetWeaselString(Apollo.GetString("TargetFrame_MissionProgress"), pmMission:GetName(), pmMission:GetNumCompleted(), pmMission:GetNumNeeded())
		end
	end

	local strProgress = ""
	local nNeeded = tRewardInfo.nNeeded
	local nCompleted = tRewardInfo.nCompleted
	local bShowCount = tRewardInfo.bShowCount
	local bShowPercent = false
	
	if tRewardInfo.eType == Unit.CodeEnumRewardInfoType.PublicEvent and tRewardInfo.peoObjective ~= nil then
		bShowPercent = tRewardInfo.peoObjective:ShowPercent()
	end
	
	if nCompleted ~= nil and nNeeded ~= nil and nNeeded > 0 then
		if bShowCount then
			strProgress = String_GetWeaselString(Apollo.GetString("TargetFrame_Progress"), nCompleted, nNeeded)
		else
			strProgress = String_GetWeaselString(Apollo.GetString("TargetFrame_ProgressPercent"), nCompleted)
		end
	end

	local strNewEntry = ""
	if wndRewardIcon:IsShown() then -- already have a tooltip
		strNewEntry = string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("TargetFrame_RewardProgressTooltip"), strBracketText, strMessage, strProgress))
		tRewardString = tRewardString .. strNewEntry
	else
		strNewEntry = string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"Yellow\">%s</P><P Font=\"CRB_InterfaceMedium\">%s</P>", String_GetWeaselString(Apollo.GetString("TargetFrame_UnitText"), strUnitName, strBracketText), String_GetWeaselString(Apollo.GetString("TargetFrame_ShortProgress"), strMessage, strProgress))
		tRewardString = tRewardString .. strNewEntry
		wndRewardIcon:SetTooltip(tRewardString)
	end

	return tRewardString
end

function RewardIcons:HelperDrawBasicRewardTooltip(wndRewardIcon, strBracketText, strUnitName, tRewardString)
	if not wndRewardIcon then
		return
	end
	tRewardString = tRewardString or ""

	return string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</P>", tRewardString, strBracketText)
end

function RewardIcons:HelperLoadRewardIcon(wndRewardPanel, eType)
	local wndCurr = wndRewardPanel:FindChild(karRewardIcons[eType].strName)
	if wndCurr then
