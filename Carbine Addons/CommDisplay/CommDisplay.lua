-- Client lua script
require "CommunicatorLib"
require "Window"
require "Apollo"
require "DialogSys"
require "Quest"
require "MailSystemLib"
require "Sound"
require "GameLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "CommunicatorLib"
require "Unit"

---------------------------------------------------------------------------------------------------
-- CommDisplay
---------------------------------------------------------------------------------------------------
local CommDisplay = {}
local knDefaultWidth = 500
local knDefaultHeight = 173

-- TODO Hardcoded Colors for Items
local arEvalColors =
{
	[Item.CodeEnumItemQuality.Average] 		= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 		= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent]	= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 		= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 	= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact] 	= ApolloColor.new("ItemQuality_Artifact"),
	[Item.CodeEnumItemQuality.Inferior] 	= ApolloColor.new("ItemQuality_Inferior"),
}

local knSaveVersion = 4

---------------------------------------------------------------------------------------------------
-- CommDisplay initialization
---------------------------------------------------------------------------------------------------
function CommDisplay:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CommDisplay:Init()
    Apollo.RegisterAddon(self)
end

function CommDisplay:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSavedData = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	return tSavedData
end

function CommDisplay:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function CommDisplay:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CommDisplay.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function CommDisplay:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	if self.wndMain == nil then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "CommDisplayForm", nil, self) -- Do not rename. Datachron.lua references this.
		self.wndMain:Show(false, true)
		if self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
		
		local tOffsets = {self.wndMain:GetAnchorOffsets()}
		self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
		self.nRewardLeft, self.nRewardTop, self.nRewardRight, self.nRewardBottom = self.wndMain:FindChild("RewardsContainer"):GetAnchorOffsets()
		self.nDialogLeft, self.nDialogTop, self.nDialogRight, self.nDialogBottom = self.wndMain:FindChild("DialogFraming"):GetAnchorOffsets()
	end

	Apollo.RegisterEventHandler("ShowCommDisplay", 			"OnShowCommDisplay", self)
	Apollo.RegisterEventHandler("HideCommDisplay", 			"OnHideCommDisplay", self)
	Apollo.RegisterEventHandler("CloseCommDisplay", 		"OnHideCommDisplay", self)
	Apollo.RegisterEventHandler("StopTalkingCommDisplay", 	"OnStopTalkingCommDisplay", self)
	Apollo.RegisterEventHandler("CommDisplayQuestText", 	"OnCommDisplayQuestText", self)
	Apollo.RegisterEventHandler("CommDisplayRegularText", 	"OnCommDisplayRegularText", self)

	self.tGivenRewardData = {}
	self.tGivenRewardIcons = {}

	self.tChoiceRewardData = {}
	self.tChoiceRewardIcons = {}

	self.wndCommPortraitLeft = self.wndMain:FindChild("CommPortraitLeft")
	self.wndCommPortraitRight = self.wndMain:FindChild("CommPortraitRight")
end

function CommDisplay:OnMouseButtonUp()
	-- Update starting position if clicked/moved
	local tOffsets = {self.wndMain:GetAnchorOffsets()}
	self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
	return false
end

function CommDisplay:OnCloseBtn()
	local tOffsets = {self.wndMain:GetAnchorOffsets()}
	self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
	Event_FireGenericEvent("CommDisplay_Closed") -- Let the datachron know we exited early
	--self:OnHideCommDisplay() -- Trust the datachron will send this hide UI event to us, so we don't accidentally double hide queued msgs
end

---------------------------------------------------------------------------------------------------
-- CommDisplay Events
---------------------------------------------------------------------------------------------------

function CommDisplay:OnShowCommDisplay()
	self.wndMain:Show(true)
	self.wndCommPortraitLeft:Show(true)
	self.wndCommPortraitRight:Show(true)
end

function CommDisplay:OnHideCommDisplay()
	self.wndMain:Show(false)
	self.wndCommPortraitLeft:Show(false)
	self.wndCommPortraitLeft:StopTalkSequence()
	self.wndCommPortraitRight:Show(false)
	self.wndCommPortraitRight:StopTalkSequence()
	self:OnCloseCommDisplay()
end

function CommDisplay:OnStopTalkingCommDisplay()
	self.wndMain:UnpauseAnim()
	self.wndCommPortraitLeft:StopTalkSequence()
	self.wndCommPortraitRight:StopTalkSequence()
end

function CommDisplay:OnCloseCommDisplay()
	local tOffsets = {self.wndMain:GetAnchorOffsets()}
	self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
	self.tChoiceRewardData = {}
	self.tGivenRewardData = {}
	self.nCurTextHeight = 0

	if self.wndMain ~= nil then
		self.wndMain:Show(false)
	end
end

function CommDisplay:OnCommDisplayRegularText(idMsg, idCreature, strMessageText, tLayout)
	local pmMission = CommunicatorLib.GetPathMissionDelivered(idMsg)
	if pmMission then
		return
	end

	if CommunicatorLib.PlaySpamVO(idMsg) then
		-- if we can play a real VO, then wait for the signal that that VO ended
		self.wndMain:SetAnimElapsedTime(9.0)
		self.wndMain:PauseAnim()
		Sound.Play(Sound.PlayUIDatachronSpam)
	else
		self.wndMain:PlayAnim(0)
		Sound.Play(Sound.PlayUIDatachronSpamNoVO)
	end

	self.wndCommPortraitLeft:PlayTalkSequence()
	self.wndCommPortraitRight:PlayTalkSequence()
	
	local tOffsets = {self.wndMain:GetAnchorOffsets()}
	self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}

	self.wndMain:FindChild("CloseBtn"):Show(true)
	self:DrawText(strMessageText, "", true, tLayout, idCreature, nil, nil) -- 2nd argument: bIsCommCall
end

function CommDisplay:OnCommDisplayQuestText(idState, idQuest, bIsCommCall, tLayout)
	-- From Datachron
	self.wndMain:DetachAnim()

	self:OnShowCommDisplay()

	self.wndCommPortraitLeft:PlayTalkSequence()
	self.wndCommPortraitRight:PlayTalkSequence()
	self.wndMain:FindChild("DialogText"):SetAML("")
	self.wndMain:FindChild("CloseBtn"):Show(false)

	self.tChoiceRewardData = {}
	self.tGivenRewardData = {}
	local unitNpc = DialogSys.GetNPC() -- Note: this will be nil if this is a communicator or we're talking to an item

	local strMessageText = DialogSys.GetNPCText(idQuest)
	if strMessageText == nil or string.len(strMessageText) == 0 then strMessageText = "" end
	
	local tOffsets = {self.wndMain:GetAnchorOffsets()}
	self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}

	self:DrawText(strMessageText, "", bIsCommCall, tLayout, DialogSys.GetCommCreatureId(), idState, idQuest)
end

---------------------------------------------------------------------------------------------------
-- CommDisplay private methods
---------------------------------------------------------------------------------------------------

function CommDisplay:DrawText(strMessageText, strSubTitleText, bIsCommCall, tLayout, idCreature, idState, idQuest)
	-- TODO Lots of format hardcoding
	--[[ Possible options on tLayout
		duration
		portraitPlacement: 0 left, 1 Right
		overlay: 0 default, 1 lightstatic, 2 heavystatic
		background: 0 default, 1 exiles, 2 dominion
	]]--
	self.wndMain:FindChild("PortraitContainerLeft"):Show(not tLayout or tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Left)
	self.wndMain:FindChild("PortraitContainerRight"):Show(tLayout and tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Right)
	--self.wndMain:FindChild("PortraitAccentL"):Show(tLayout and tLayout.eBackground > CommunicatorLib.CommunicatorBackground_Default)
	--self.wndMain:FindChild("PortraitAccentR"):Show(tLayout and tLayout.eBackground > CommunicatorLib.CommunicatorBackground_Default)
	self.wndMain:FindChild("HorizontalTopContainer"):ArrangeChildrenHorz(0)

	if tLayout then
		if tLayout.eBackground == CommunicatorLib.CommunicatorBackground_Exiles then
			--self.wndMain:FindChild("PortraitAccentL"):SetSprite("CRB_Basekit:kitAccent_Corner_Exile")
			--self.wndMain:FindChild("PortraitAccentR"):SetSprite("CRB_Basekit:kitAccent_Corner_Exile")
		elseif tLayout.eBackground == CommunicatorLib.CommunicatorBackground_Dominion then
			--self.wndMain:FindChild("PortraitAccentL"):SetSprite("CRB_Basekit:kitAccent_Corner_Dominion")
			--self.wndMain:FindChild("PortraitAccentR"):SetSprite("CRB_Basekit:kitAccent_Corner_Dominion")
		end

		if tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Right then
			self.wndMain:FindChild("HorizontalTopContainer"):ArrangeChildrenHorz(2)
		else
			self.wndMain:FindChild("HorizontalTopContainer"):ArrangeChildrenHorz(0)
		end
	end

	if not tLayout or tLayout.eOverlay == CommunicatorLib.CommunicatorOverlay_Default then
		self.wndMain:FindChild("StaticContainerL"):SetSprite("")
		self.wndMain:FindChild("StaticContainerR"):SetSprite("")
	elseif tLayout.eOverlay == CommunicatorLib.CommunicatorOverlay_LightStatic then
		self.wndMain:FindChild("StaticContainerL"):SetSprite("sprComm_StaticComposite")
		self.wndMain:FindChild("StaticContainerR"):SetSprite("sprComm_StaticComposite")
	elseif tLayout.eOverlay == CommunicatorLib.CommunicatorOverlay_HeavyStatic then
		self.wndMain:FindChild("StaticContainerL"):SetSprite("sprComm_StaticComposite")
		self.wndMain:FindChild("StaticContainerR"):SetSprite("sprComm_StaticComposite")
	end

	-- format the given text to display
	local strLeftOrRight = "Left"
	local strCreatureName = ""

	if tLayout and tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Right then
		strLeftOrRight = "Right"
	end

	if idCreature and idCreature ~= 0 then
		self.wndCommPortraitLeft:SetCostumeToCreatureId(idCreature)
		self.wndCommPortraitRight:SetCostumeToCreatureId(idCreature)

		if Creature_GetName(idCreature) then
			strCreatureName = Creature_GetName(idCreature)
		end
	end

	local strSubtitleAppend = ""
	local strTextColor = "ff8096a8"

	if bIsCommCall then
		strTextColor = "ff62b383"
	end

	if strSubTitleText and strSubTitleText ~= "" then
		strSubtitleAppend = string.format("<P Font=\"CRB_InterfaceLarge_B\" TextColor=\"%s\" Align=\"%s\">%s</P>", strTextColor, strLeftOrRight, strSubTitleText)
	end

	self.wndMain:FindChild("DialogName"):SetAML(string.format("<P Font=\"CRB_HeaderMedium\" TextColor=\"%s\" Align=\"%s\">%s</P>", "UI_TextHoloTitle", strLeftOrRight, strCreatureName))
	self.wndMain:FindChild("DialogText"):SetAML(string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"%s\" Align=\"%s\">%s</P>", strSubtitleAppend, strTextColor, strLeftOrRight, strMessageText))

	-- Draw Rewards
	local nRewardHeight = 0

	if idState ~= DialogSys.DialogState_TopicChoice then
		nRewardHeight = self:DrawRewards(self.wndMain, idState, idQuest)
	end

	self.wndMain:FindChild("RewardsContainer"):Show(nRewardHeight > 0)

	-- Resize for text over four lines (four lines is equal to 68 pixels at the moment) -- TODO Hardcoded formatting
	self.wndMain:FindChild("DialogText"):SetHeightToContentHeight()
	local nContentX, nContentY = self.wndMain:FindChild("DialogText"):GetContentSize()
	local nOffsetY = 0
	self.wndMain:FindChild("DialogFraming"):SetAnchorOffsets(self.nDialogLeft, self.nDialogTop, self.nDialogRight, self.nDialogBottom)


	if nContentY > 68 then
		nOffsetY = nContentY - 68 + 5 -- The +5 is for lower g-height
		self.wndMain:FindChild("DialogFraming"):SetAnchorOffsets(self.nDialogLeft, self.nDialogTop, self.nDialogRight, self.nDialogBottom + nContentY - 64)

	end
	-- Excess text expands down, & Rewards expand down
	self.wndMain:SetAnchorOffsets(self.tDefaultOffsets[1], self.tDefaultOffsets[2], self.tDefaultOffsets[3], self.tDefaultOffsets[4] + nRewardHeight + nOffsetY)
	self.wndMain:FindChild("RewardsContainer"):SetAnchorOffsets(self.nRewardLeft, self.nRewardTop + nOffsetY, self.nRewardRight, self.nRewardBottom)
end

function CommDisplay:DrawRewards(wndArg, idState, idQuest)
	-- Reset everything, especially if we don't even have rewards
	self.wndMain:FindChild("CashRewards"):Show(false)
	self.wndMain:FindChild("LootCashWindow"):Show(false)
	self.wndMain:FindChild("ReputationText"):Show(false)
	self.wndMain:FindChild("GivenContainer"):Show(false)
	self.wndMain:FindChild("ChoiceContainer"):Show(false)
	self.wndMain:FindChild("ChoiceRewardsText"):Show(false) -- Given Rewards Text lives in CashRewards
	self.wndMain:FindChild("GivenRewardsItems"):DestroyChildren()
	self.wndMain:FindChild("ChoiceRewardsItems"):DestroyChildren()

	if not idQuest or idQuest == 0 then
		return 0
	end

	local queView = DialogSys.GetViewableQuest(idQuest)

	if not queView then
		return 0
	end

	local tRewardInfo = queView:GetRewardData()

	local nGivenContainerHeight = 0
	if tRewardInfo.arFixedRewards and #tRewardInfo.arFixedRewards > 0 then
		for key, tCurrReward in ipairs(tRewardInfo.arFixedRewards) do
			if tCurrReward then
				wndArg:FindChild("CashRewards"):Show(true)
			end
			self:DrawLootItem(tCurrReward, wndArg:FindChild("GivenRewardsItems"))
		end

		nGivenContainerHeight = wndArg:FindChild("GivenRewardsItems"):ArrangeChildrenVert(0)
		wndArg:FindChild("GivenContainer"):SetAnchorOffsets(0, 0, 0, nGivenContainerHeight)
		wndArg:FindChild("GivenContainer"):Show(true)

		if wndArg:FindChild("CashRewards"):IsShown() then -- Since it can show twice
			nGivenContainerHeight = nGivenContainerHeight + wndArg:FindChild("CashRewards"):GetHeight()
		end -- Do resizing for the CashRewards after sizing the container
	end

	local nChoiceContainerHeight = 0
	if tRewardInfo.arRewardChoices and #tRewardInfo.arRewardChoices > 0 and idState ~= DialogSys.DialogState_QuestComplete then -- GOTCHA: Choices are shown in Player, not NPC for QuestComplete
		for key, tCurrReward in ipairs(tRewardInfo.arRewardChoices) do
			self:DrawLootItem(tCurrReward, wndArg:FindChild("ChoiceRewardsItems"))
		end

		nChoiceContainerHeight = wndArg:FindChild("ChoiceRewardsItems"):ArrangeChildrenVert(0, function(a,b) return b:FindChild("LootIconCantUse"):IsShown() end)
		wndArg:FindChild("ChoiceContainer"):SetAnchorOffsets(0, 0, 0, nChoiceContainerHeight)
		wndArg:FindChild("ChoiceContainer"):Show(true)
		wndArg:FindChild("ChoiceRewardsText"):Show(#tRewardInfo.arRewardChoices > 1)

		if #tRewardInfo.arRewardChoices > 1 then
			nChoiceContainerHeight = nChoiceContainerHeight + wndArg:FindChild("ChoiceRewardsText"):GetHeight()
		end -- Do text padding after SetAnchorOffsets so the box doesn't expand
	end

	wndArg:FindChild("RewardsArrangeVert"):ArrangeChildrenVert(0)
	if nGivenContainerHeight + nChoiceContainerHeight == 0 and not self.wndMain:FindChild("CashRewards"):IsShown() then
		return 0
	end
	return nGivenContainerHeight + nChoiceContainerHeight + 30 -- TODO hardcoded formatting
end

function CommDisplay:DrawLootItem(tCurrReward, wndParentArg)
	if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Money then
		self.wndMain:FindChild("CashRewards"):FindChild("LootCashWindow"):Show(true)
		self.wndMain:FindChild("CashRewards"):FindChild("LootCashWindow"):SetMoneySystem(tCurrReward.eCurrencyType or 0)
		self.wndMain:FindChild("CashRewards"):FindChild("LootCashWindow"):SetAmount(tCurrReward.nAmount, 0)
		
		local strText = ""
		if tCurrReward.nAmount >= 1000000 then
			strText = String_GetWeaselString(Apollo.GetString("CRB_Platinum"), math.floor(tCurrReward.nAmount / 1000000))
		end
		if tCurrReward.nAmount >= 10000 then
			strText = strText .. " " .. String_GetWeaselString(Apollo.GetString("CRB_Gold"), math.floor(tCurrReward.nAmount % 1000000 / 10000))
		end
		if tCurrReward.nAmount >= 100 then
			strText = strText .. " " .. String_GetWeaselString(Apollo.GetString("CRB_Silver"), math.floor(tCurrReward.nAmount % 10000 / 100))
		end
		strText = strText .. " " .. String_GetWeaselString(Apollo.GetString("CRB_Copper"), math.floor(tCurrReward.nAmount % 100))
		self.wndMain:FindChild("CashRewards"):FindChild("LootCashWindow"):SetTooltip(strText)
	end

	local strIconSprite = ""
	local wndCurrReward = nil
	if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Item then
		local itemReward = tCurrReward.itemReward
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)
		wndCurrReward:FindChild("LootIconCantUse"):Show(self:HelperPrereqFailed(itemReward))
		wndCurrReward:FindChild("LootDescription"):SetText(itemReward:GetName())
		wndCurrReward:FindChild("LootDescription"):SetTextColor(arEvalColors[itemReward:GetItemQuality()])
		Tooltip.GetItemTooltipForm(self, wndCurrReward, tCurrReward.itemReward, {bPrimary = true, bSelling = false, itemCompare = itemReward:GetEquippedItemForItemType()})
		strIconSprite = itemReward:GetIcon()

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_TradeSkillXp then
		-- Tradeskill has overloaded fields: objectId is factionId. objectAmount is rep amount.
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)

		local strText = String_GetWeaselString(Apollo.GetString("CommDisp_TradeXPReward"), tCurrReward.nXP, tCurrReward.strTradeskill)
		wndCurrReward:FindChild("LootDescription"):SetText(strText)
		wndCurrReward:SetTooltip(strText)
		strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_GrantTradeskill then
		-- Tradeskill has overloaded fields: objectId is tradeskillId.
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)
		wndCurrReward:FindChild("LootDescription"):SetText(tCurrReward.strTradeskill)
		wndCurrReward:SetTooltip("")
		strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Reputation then
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)
		strIconSprite = "Icon_ItemMisc_UI_Item_Parchment"
		wndCurrReward:FindChild("LootDescription"):SetText(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tCurrReward.nAmount, tCurrReward.strFactionName))
		wndCurrReward:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tCurrReward.nAmount, tCurrReward.strFactionName))
	end

	if wndCurrReward then
		wndCurrReward:FindChild("LootIcon"):SetSprite(strIconSprite)
	end
end

function CommDisplay:OnGenerateTooltip(wndHandler, wndControl, eType, arg1, arg2)
	-- For reward icon events from XML
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemData then
		local itemCurr = arg1
		local itemEquipped = itemCurr:GetEquippedItemForItemType()

		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = self.bVendorOpen, itemCompare = itemEquipped})

	elseif eType == Tooltip.TooltipGenerateType_Reputation or tType == Tooltip.TooltipGenerateType_TradeSkill then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1:GetMoneyString(), CColor.new(1, 1, 1, 1), "CRB_InterfaceMedium")
		wndControl:SetTooltipDoc(xml)
	else
		wndControl:SetTooltipDoc(nil)
	end
end

function CommDisplay:HelperPrereqFailed(tCurrItem)
	return tCurrItem and tCurrItem:IsEquippable() and not tCurrItem:CanEquip()
end

local CommDisplayInst = CommDisplay:new()
CommDisplayInst:Init()
