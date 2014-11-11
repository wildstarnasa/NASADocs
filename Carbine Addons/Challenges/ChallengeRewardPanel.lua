-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeRewardPanel
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "ChallengesLib"

-----------------------------------------------------------------------------------------------
-- ChallengeRewardPanel Module Definition
-----------------------------------------------------------------------------------------------
local ChallengeRewardPanel = {}

--TODO: lots of hardcoded sizes
local knItemWidth 				= 80  -- How wide is a reward item? MUST MATCH XML
local knWindowFramePadding 		= 80 -- How much padding on either side the list (divide by 2)

local kcrDoubleMarkerOff 		= ApolloColor.new("UI_BtnTextHoloNormal")
local kcrDoubleMarkerHighlight 	= ApolloColor.new("UI_BtnTextHoloFlyby")
local kcrDoubleMarkerSelected 	= ApolloColor.new("xkcdReddish")

local kfFlashDurationShort 		= 0.150 -- short flash timer duration
local kfFlashDurationMedium 	= 0.300 -- short flash timer duration
local kfFlashDurationLong 		= 0.800 -- long flash timer duration
local kfCloseDelayDuration 		= 3.0 -- how long the panel is shown after the reward is given
local knFlashCountMax 			= 12 -- how many quick flashes before the randomizer winds down
local knMediumFlashCountMax 	= 6 -- how many medium flashes before the randomizer winds down
local kstrTickSound 			= Sound.PlayUI11To13GenericPushButtonDigital01
local kstrAwardSound 			= Sound.PlayUIAlertPopUpMessageReceived

local ktTierColors =
{
	CColor.new(164/255, 82/255, 0, 0.6), 		-- bronze
	CColor.new(175/255, 175/255, 175/255, 1.0), -- silver
	CColor.new(138/255, 138/255, 0, 1.0), 		-- gold
	CColor.new(64/255, 1.0, 1.0, 1.0), 			-- non-tier
}

local ktTierStrings =
{
	{Apollo.GetString("ChallengeReward_BestChance"), Apollo.GetString("ChallengeReward_BestTooltip")},
	{Apollo.GetString("ChallengeReward_MidChance"), Apollo.GetString("ChallengeReward_MidTooltip")},
	{Apollo.GetString("ChallengeReward_BadChance"), Apollo.GetString("ChallengeReward_BadTooltip")},
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ChallengeRewardPanel:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here
	self.wndSelectedListItem = nil -- keep track of which list item is currently selected
	self.idChallenge = nil
	self.idChallengeReward = nil

    return o
end

function ChallengeRewardPanel:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- ChallengeRewardPanel OnLoad
-----------------------------------------------------------------------------------------------
function ChallengeRewardPanel:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ChallengeRewardPanel.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ChallengeRewardPanel:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("ChallengeRewardShow", 		"OnChallengeRewardShow", self) -- fire generic event "ChallengeRewardShow" to open the panel
	Apollo.RegisterEventHandler("ChallengeRewardListReady", "OnChallengeRewardListReady", self)
	Apollo.RegisterEventHandler("ChallengeRewardReady", 	"OnChallengeRewardReady", self)

	--timers currently can't be started during their callbacks, because of a Code bug.
	--as a work around, will re-assign the references to the timers in their callbacks.
	self.timerShort			= ApolloTimer.Create(kfFlashDurationShort, false, "OnRandomizerDelayShort", self)
	self.timerShort:Stop()

	self.timerMedium		= ApolloTimer.Create(kfFlashDurationMedium, false, "OnRandomizerDelayMedium", self)
	self.timerMedium:Stop()

	self.timerLong			= ApolloTimer.Create(kfFlashDurationLong, false, "OnRandomizerDelayLong", self)
	self.timerLong:Stop()

	self.timerWindowClose	= ApolloTimer.Create(kfCloseDelayDuration, false, "OnWindowCloseDelay", self)
	self.timerWindowClose:Stop()

	self.timerChosen		= ApolloTimer.Create(1.0, false, "OnRandomizerChosenDelay", self)
	self.timerChosen:Stop()

    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "ChallengeRewardPanelForm", nil, self)
	self.wndText = self.wndMain:FindChild("BodyText")
	self.wndMain:Show(false)

	-- item list
	self.wndItemList 		= self.wndMain:FindChild("ItemList")
	self.tItems 			= {} -- keep track of all the list items
	self.tDividers 			= {} -- keep track of all the tier dividers
	self.nItems 			= 0
	self.nDividers 			= 0
	self.bInRandomizer 		= false
	self.bHasTiers 			= false

	self.tValidWindows 		= {} -- what windows are the randomizer applied to
	self.nShortFlashCount 	= 0 -- how many flashes have been shown
	self.nMediumFlashCount 	= 0 -- how many flashes have been shown
	self.nLongFlashCount 	= 0 -- How many have been shown
	self.nLongFlashMax 		= 0 -- How many long flashes will there be (gets randomized)
	self.iReward 			= 0 -- index for the rewarded item; 0 is "not ready"
	self.iRewardTier 		= 0 -- index of received reward tier
	self.nLastRandom 		= 0
end

function ChallengeRewardPanel:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("CRB_ChallengeRewardPanel")})
end

-----------------------------------------------------------------------------------------------
-- ChallengeRewardPanel Functions
-----------------------------------------------------------------------------------------------
function ChallengeRewardPanel:OnChallengeRewardShow(idChallenge)
	self.idChallenge = idChallenge
	self.bInRandomizer = false
	self:DestroyItemList() -- We will wait for ChallengeRewardListReady to populate
	--self.wndText:SetText(Apollo.GetString("Challenges_Loading"))
	--self.wndText:SetFont("CRB_InterfaceMedium")
	ChallengesLib.GenerateRewardList(idChallenge)
	self.wndMain:Show(true)
	self.wndMain:ToFront()
end

function ChallengeRewardPanel:OnChallengeRewardListReady(idChallenge, iRewardTier)
	self:DestroyItemList()
	self.iRewardTier = iRewardTier
	self:PopulateItemList()
	self:FormatItemList()
end

function ChallengeRewardPanel:OnChallengeRewardReady(idChallenge, iReward)
	if not self.wndMain:IsVisible() then -- if the window was closed before the reward came down
		if self.iReward == 0 then
			ChallengesLib.AcceptRewards(idChallenge)
			Event_FireGenericEvent("ChallengeReward_SpinEnd")
			return
		end
	end

	self.iReward = iReward -- set the index; non-zero means ready
	self.idChallengeReward = idChallenge -- in case it's different from the one shown
end

function ChallengeRewardPanel:OnCancel()
	self.wndMain:Show(false) -- hide the window
	self.timerShort:Stop()
	self.timerLong:Stop()
	self.timerWindowClose:Stop()

	if self.iReward ~= 0 then -- if a reward is ready, deliver it.
		ChallengesLib.AcceptRewards(self.idChallengeReward)
		Event_FireGenericEvent("ChallengeReward_SpinEnd")
	end
end

-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
function ChallengeRewardPanel:DestroyItemList()
	for idx, wndCurrent in ipairs(self.tItems) do
		wndCurrent:Destroy()
	end

	-- clear the list item array
	self.tItems = {}
	self.tDividers = {}
	self.wndItemList:DestroyChildren()
	self.nItems = 0
	self.nDividers = 0
	self.bHasTiers = false

	self.tTierCounts = {0, 0, 0}

	self.wndMain:FindChild("RarityList"):DestroyChildren()

	local nLeftMain, nTopMain, nRightMain, nBottomMain = self.wndMain:GetAnchorOffsets()
	local nCurrentCenter = nRightMain - ((nRightMain - nLeftMain) / 2)
	local nCenteredValue = (knItemWidth + knWindowFramePadding) / 2
	self.wndMain:SetAnchorOffsets(-nCenteredValue + nCurrentCenter, nTopMain, nCenteredValue + nCurrentCenter, nBottomMain)

	-- clear randomizer stuff
	self.tValidWindows = {}
	self.nShortFlashCount = 0
	self.nMediumFlashCount = 0
	self.nLongFlashCount = 0
	self.bInRandomizer = false
	self.iReward = 0
	self.iRewardTier = 0
end

function ChallengeRewardPanel:PopulateItemList()
	local tRewardList = ChallengesLib.GetRewardList(self.idChallenge)
	if not tRewardList then
		return
	end

	local nLowestTier = 0
	for idx, tReward in ipairs(tRewardList) do
        if tReward.nChallengeTier > nLowestTier then
			self.bHasTiers = true
			self:AddDivider(tReward.nChallengeTier)
			nLowestTier = tReward.nChallengeTier
		end
		self:AddItem(idx, tReward)
	end
	self:AddDivider(nLowestTier+1)
end

function ChallengeRewardPanel:AddDivider(idx)
	self.tDividers[idx] = Apollo.LoadForm(self.xmlDoc, "TierDividerItem", self.wndItemList, self)
	self.nDividers = self.nDividers + 1
end

function ChallengeRewardPanel:AddItem(idx, tRewards) -- add an item into the item list
	local wndChallengeItem = Apollo.LoadForm(self.xmlDoc, "ChallengeItem", self.wndItemList, self)
	self.tItems[idx] = wndChallengeItem -- keep track of the window item created
	self.nItems = self.nItems+1

	if tRewards.itemReward then
		wndChallengeItem:FindChild("LootIcon"):SetItemInfo(tRewards.itemReward, tRewards.nAmount)
		wndChallengeItem:FindChild("ChallengeItemBtn"):SetData(tRewards.itemReward)
	elseif tRewards.monReward then
		wndChallengeItem:FindChild("LootIcon"):SetMoneyInfo(tRewards.monReward, tRewards.nAmount)
	elseif tRewards.splReward then
		wndChallengeItem:FindChild("LootIcon"):SetSpellInfo(tRewards.splReward)
	elseif tRewards.nXp then
		wndChallengeItem:FindChild("LootIcon"):SetXpInfo(tRewards.nXp)
	elseif tRewards.nRepId then
		wndChallengeItem:FindChild("LootIcon"):SetReputationInfo(tRewards.nRepId, tRewards.nRepAmount)
	end

	self.tTierCounts[tRewards.nChallengeTier] = self.tTierCounts[tRewards.nChallengeTier] + 1

	wndChallengeItem:FindChild("ChallengeItemBtn"):SetBGColor(CColor.new(1.0, 1.0, 1.0, 1.0))
	wndChallengeItem:FindChild("Backer"):SetBGColor(CColor.new(1.0, 1.0, 1.0, 1.0))
	wndChallengeItem:FindChild("LootIcon"):SetBGColor(CColor.new(1.0, 1.0, 1.0, 1.0))
	wndChallengeItem:FindChild("2xMarker"):SetText(String_GetWeaselString(Apollo.GetString("ChallengeReward_Multiplier"), ChallengesLib.GetLootBonusMultiplier(self.iRewardTier)))
	wndChallengeItem:FindChild("2xMarker"):SetTextColor(kcrDoubleMarkerOff)
	self.tValidWindows[idx] = wndChallengeItem
	wndChallengeItem:FindChild("LootIconBlocker"):SetBGColor(CColor.new(0, 0, 0, 0))
	wndChallengeItem:FindChild("LootIconBlocker"):SetData(true)
	wndChallengeItem:FindChild("LootIconBlocker"):Enable(true)

	wndChallengeItem:FindChild("ChallengeItemBtn"):Enable(true)
	wndChallengeItem:FindChild("2xMarker"):Show(true)

	wndChallengeItem:SetData(idx)
end

-----------------------------------------------------------------------------------------------
-- Start Btn and Spinning
-----------------------------------------------------------------------------------------------
function ChallengeRewardPanel:OnChallengeItemBtn(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then -- Right click should always be safe, instead of only safe on certain buttons
		if wndHandler:GetData() then -- Can be nil, E.G. XP has no item data
			Event_FireGenericEvent("GenericEvent_ContextMenuItem", wndHandler:GetData())
		end
		return
	end

	self.bInRandomizer = true
	for idx = 1, #self.tItems do
		if not self.tItems[idx]:FindChild("ChallengeItemBtn"):IsChecked() then
			self.tItems[idx]:FindChild("ChallengeItemBtn"):Enable(false)
			self.tItems[idx]:FindChild("LootIconBlocker"):Enable(false)
			self.tItems[idx]:FindChild("2xMarker"):SetTextColor(CColor.new(0, 0, 0, .25))
		else
			self.tItems[idx]:FindChild("ChallengeItemBtn"):Enable(false)
			self.tItems[idx]:FindChild("LootIconBlocker"):Enable(false)
		end
	end

	local wndParent = wndControl:GetParent()
	--self.wndText:SetFont("CRB_HeaderHuge")
	self.wndText:SetText(Apollo.GetString("ChallengeReward_Spinning"))
	wndParent:FindChild("2xMarker"):SetTextColor(kcrDoubleMarkerSelected)

	--spin!!!!
	-- Note: If the second argument is invalid/faked then it will just use a default value
	ChallengesLib.ProcessRewards(self.idChallenge, wndParent:GetData())
	Event_FireGenericEvent("ChallengeReward_SpinBegin") -- send the signal that we're running the randomizer
	self:OnRandomizerDelayShort()
end

function ChallengeRewardPanel:OnIconBlockerClick(wndHandler, wndControl, eMouseButton) -- lets us click the item icon to start the spin
	if wndHandler ~= wndControl then return end

	local bCanSelect = wndControl:GetData()
	local wndBtn = wndControl:GetParent():FindChild("ChallengeItemBtn")

	if bCanSelect then
		self:OnChallengeItemBtn(wndBtn, wndBtn, eMouseButton)
	end
end

function ChallengeRewardPanel:OnRandomizerDelayShort() -- quick flashes
	self:HelperStopAllSpinTimers()
	self.nShortFlashCount = self.nShortFlashCount + 1
	Sound.Play(kstrTickSound)

	if self.tValidWindows and #self.tValidWindows > 0 then
		local nRandom = self:HelperSpinDice(1, #self.tValidWindows)
		self.tValidWindows[nRandom]:FindChild("ItemFlash"):SetSprite("sprCh_OrangeFlashFast")

		if self.nShortFlashCount <= knFlashCountMax then
			self.timerShort = ApolloTimer.Create(kfFlashDurationShort, false, "OnRandomizerDelayShort", self) -- :Start()
		else
			self.timerMedium:Set(kfFlashDurationShort, false)
		end
	end
end

function ChallengeRewardPanel:OnRandomizerDelayMedium() -- medium flashes
	self:HelperStopAllSpinTimers()
	self.nMediumFlashCount = self.nMediumFlashCount + 1
	Sound.Play(kstrTickSound)

	if self.tValidWindows and #self.tValidWindows > 0 then
		local nRandom = self:HelperSpinDice(1, #self.tValidWindows)
		self.tValidWindows[nRandom]:FindChild("ItemFlash"):SetSprite("sprCh_OrangeFlashMedium")

		if self.nMediumFlashCount <= knMediumFlashCountMax then
			self.timerMedium = ApolloTimer.Create(kfFlashDurationMedium, false, "OnRandomizerDelayMedium", self)
		else
			self.nLongFlashMax = math.random(2, 4) -- randomize the number of long flashes
			self.timerLong:Set(kfFlashDurationMedium, false)
		end
	end
end

function ChallengeRewardPanel:OnRandomizerDelayLong() -- winding down
	self:HelperStopAllSpinTimers()
	self.nLongFlashCount = self.nLongFlashCount + 1
	Sound.Play(kstrTickSound)

	if self.nLongFlashCount > self.nLongFlashMax + 10 then
		return -- Sanity Check
	end

	if self.iReward == 0 then -- still waiting on CPP to pass a reward down
		self.nLongFlashCount = self.nLongFlashCount - 1
		self.timerLong = ApolloTimer.Create(kfFlashDurationLong, false, "OnRandomizerDelayLong", self)
		return
	end
	
	if self.tValidWindows and #self.tValidWindows > 0 then
		local nRandom = math.random(1, #self.tValidWindows)	-- set random flash
		if self.nLongFlashCount <= self.nLongFlashMax then
			self.tValidWindows[nRandom]:FindChild("ItemFlash"):SetSprite("sprCh_OrangeFlashSlow")
			self.timerLong = ApolloTimer.Create(kfFlashDurationLong, false, "OnRandomizerDelayLong", self)
		else -- Ready to give rewards
			if self.tValidWindows[self.iReward] == nil then -- got a bad value
				self:OnCancel()
			else -- all good, show the final reward
				self.timerChosen:Start()
				self.timerWindowClose:Start()
				self.tValidWindows[self.iReward]:FindChild("ItemFlash"):SetSprite("sprCh_OrangeFlashSelected")
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Simple UI Handlers
-----------------------------------------------------------------------------------------------
function ChallengeRewardPanel:OnChallengeItemEnter(wndHandler, wndControl, nX, nY)
	if wndHandler ~= wndControl or self.bInRandomizer then return end
	wndControl:GetParent():FindChild("2xMarker"):SetTextColor(kcrDoubleMarkerHighlight)
end

function ChallengeRewardPanel:OnChallengeItemExit(wndHandler, wndControl, nX, nY)
	if wndHandler ~= wndControl or self.bInRandomizer then return end
	wndControl:GetParent():FindChild("2xMarker"):SetTextColor(kcrDoubleMarkerOff)
end

function ChallengeRewardPanel:OnRandomizerChosenDelay()
	self.wndText:SetText(Apollo.GetString("Challenges_RewardChosen"))
	Sound.Play(kstrAwardSound)
end

function ChallengeRewardPanel:OnWindowCloseDelay()
	ChallengesLib.AcceptRewards(self.idChallengeReward)
	Event_FireGenericEvent("ChallengeReward_SpinEnd")
	self.wndMain:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------
function ChallengeRewardPanel:HelperStopAllSpinTimers()
	self.timerShort:Stop()
	self.timerMedium:Stop()
	self.timerLong:Stop()
end

function ChallengeRewardPanel:HelperSpinDice(nMin, nMax)
	local nRandom = math.random(nMin, nMax)	-- set random flash
	if nRandom == self.nLastRandom then
		nRandom = math.random(nMin, nMax)	-- if same as the last shown, give it one more spin
	end

	self.nLastRandom = nRandom -- set the last used window
	return nRandom
end

-- TODO: Refactor to pass in an argument rather than rely on static tables
function ChallengeRewardPanel:FormatItemList() -- arrange the item containers, size as needed
	local nTotalWidth = 0
	local strUnlock = String_GetWeaselString(Apollo.GetString("Challenges_Completed"), ChallengesLib.GetLootBonusMultiplier(self.iRewardTier))

	if self.bHasTiers == true then
		strUnlock = String_GetWeaselString(Apollo.GetString("Challenges_RankedComplete"), ChallengesLib.GetTierName(self.iRewardTier), ChallengesLib.GetLootBonusMultiplier(self.iRewardTier))
	end

	-- Add our rarity labels
	local tLabels = {}
	local tLabelsWidth = {}
	local tLabelDividers = {}
	local nDividerWidth = 8
	for idx = 1, 3 do
		if self.tTierCounts[idx] ~= 0 then

			-- Create label divider
			nDividerWidth = nDividerWidth + 8
			tLabelDividers[idx] = Apollo.LoadForm(self.xmlDoc, "TierDividerItem", self.wndMain:FindChild("RarityList"), self)

			-- Set label text
			local wndLabel = Apollo.LoadForm(self.xmlDoc, "TierLabelItem", self.wndMain:FindChild("RarityList"), self)
			wndLabel:FindChild("TierWndLabel"):SetText(idx)
			wndLabel:FindChild("TierWndLabel"):SetText(ktTierStrings[idx][1])
			wndLabel:FindChild("TierWndLabel"):SetTooltip(ktTierStrings[idx][2])

			-- Set label width
			local nLabelWidth = Apollo.GetTextWidth("CRB_InterfaceMedium_B", wndLabel:FindChild("TierWndLabel"):GetText())
			local nLeft,nTop,nRight,nBottom = wndLabel:GetAnchorOffsets()
			tLabelsWidth[idx] = math.max(knItemWidth*self.tTierCounts[idx],nLabelWidth)
			wndLabel:SetAnchorOffsets(nLeft,nTop,tLabelsWidth[idx],nBottom)

			-- Adjust divider width on each side
			if nLabelWidth > knItemWidth*self.tTierCounts[idx] then

				-- Calculate differences
				local nDiff = nLabelWidth - knItemWidth*self.tTierCounts[idx]
				nDividerWidth = nDividerWidth + nDiff

				-- Left divider
				nLeft,nTop,nRight,nBottom = self.tDividers[idx]:GetAnchorOffsets()
				self.tDividers[idx]:SetAnchorOffsets(nLeft,nTop,nRight + (nDiff/2),nBottom)

				-- Right divider
				nLeft,nTop,nRight,nBottom = self.tDividers[idx+1]:GetAnchorOffsets()
				self.tDividers[idx+1]:SetAnchorOffsets(nLeft- (nDiff/2),nTop,nRight,nBottom)
			end
		end
	end
	tLabelDividers[4] = Apollo.LoadForm(self.xmlDoc, "TierDividerItem", self.wndMain:FindChild("RarityList"), self)

	-- Resize the window
	local nTotalWidth = knWindowFramePadding + nDividerWidth + (knItemWidth * math.max(self.nItems, 4))
	local nLeftMain, nTopMain, nRightMain, nBottomMain = self.wndMain:GetAnchorOffsets()
	local nCurrentCenter = nRightMain - ((nRightMain - nLeftMain)/ 2)
	local nCenteredValue = (nTotalWidth + knWindowFramePadding) / 2
	self.wndMain:SetAnchorOffsets(-nCenteredValue + nCurrentCenter, nTopMain, nCenteredValue + nCurrentCenter, nBottomMain)

	-- Arrange list
	self.wndMain:FindChild("RarityList"):ArrangeChildrenHorz(1)
	self.wndItemList:ArrangeChildrenHorz(1)

	--self.wndText:SetFont("CRB_InterfaceMedium")
	self.wndText:SetText(strUnlock)
end

function ChallengeRewardPanel:OnGenerateTooltip(wndHandler, wndControl, eType, Arg1, Arg2)
	-- For reward icon events from XML
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemData then
		local itemReward = Arg1
		local itemEquipped = itemReward:GetEquippedItemForItemType()

		Tooltip.GetItemTooltipForm(self, wndControl, itemReward, {bPrimary = true, bSelling = self.bVendorOpen, itemCompare = itemEquipped})
	elseif eType == Tooltip.TooltipGenerateType_Reputation or eType == Tooltip.TooltipGenerateType_Xp then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(Arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(Arg1:GetMoneyString(), CColor.new(1, 1, 1, 1), "CRB_InterfaceMedium")
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, Arg1)
	else
		wndControl:SetTooltipDoc(nil)
	end
end

-----------------------------------------------------------------------------------------------
-- ChallengeRewardPanel Instance
-----------------------------------------------------------------------------------------------
local ChallengeRewardPanelInst = ChallengeRewardPanel:new()
ChallengeRewardPanelInst:Init()
