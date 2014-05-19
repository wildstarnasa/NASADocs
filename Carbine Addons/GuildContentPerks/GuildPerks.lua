-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildPerks
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "ChatSystemLib"
require "GameLib"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"
require "AchievementsLib"

local GuildPerks = {}

-- NOTE!: Really more of a note. All perks are the same; we're parsing out the special ones for formatting so this has to be kept up to date
local karTiers =  -- key is id, value is tier.
{
	[GuildLib.Perk.Tier2Unlock] = 2,
	[GuildLib.Perk.Tier3Unlock] = 3,
	[GuildLib.Perk.Tier4Unlock] = 4,
	[GuildLib.Perk.Tier5Unlock] = 5,
	[GuildLib.Perk.Tier6Unlock] = 6,
}

--[[
local karCapLimits =  -- key is id, value is limit then sequence.
{
	[0] 						= {40,  1}, -- find out
	[GuildLib.Perk.MemberCap1] 	= {80,  2},
	[GuildLib.Perk.MemberCap2] 	= {160, 3},
	[GuildLib.Perk.MemberCap3] 	= {240, 4},
	[GuildLib.Perk.MemberCap4] 	= {320, 5},
	[GuildLib.Perk.MemberCap5] 	= {400, 6},
	[GuildLib.Perk.MemberCap6] 	= {500, 7},
}
--]]

local karBankTabs =  -- key is id, value is tab unlock.
{
	[0]  						= 0,
	[GuildLib.Perk.BankTab1] 	= 1,
	[GuildLib.Perk.BankTab2]	= 2,
	[GuildLib.Perk.BankTab3] 	= 3,
	[GuildLib.Perk.BankTab4] 	= 4,
	[GuildLib.Perk.BankTab5] 	= 5,
}

local kcrDisabledText 		= ApolloColor.new("UI_TextMetalBody")
local kcrEnabledText 		= ApolloColor.new("white")
local kcrDisabledTextRed 	= ApolloColor.new("AddonError") -- used on cash
local knMaxInfluence = 2000000 -- TODO: hardcoded limit that we'll have to track

function GuildPerks:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GuildPerks:Init()
    Apollo.RegisterAddon(self)
end

function GuildPerks:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildPerks.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function GuildPerks:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("Guild_TogglePerks",           "OnTogglePerks", self)
    Apollo.RegisterEventHandler("GuildWindowHasBeenClosed",		"OnClose", self)

	Apollo.RegisterEventHandler("GuildPerkUnlocked", 			"OnUpdateEntry", self)
	Apollo.RegisterEventHandler("GuildPerkActivated", 			"OnUpdateEntry", self)
	Apollo.RegisterEventHandler("GuildPerkDeactivated ", 		"OnUpdateEntry", self)
	Apollo.RegisterEventHandler("GuildInfluenceAndMoney", 		"OnInfluenceUpdated", self)
 	Apollo.RegisterEventHandler("AchievementUpdated", 			"OnAchievementUpdated", self)   
end

function GuildPerks:Initialize(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then 
		return 
	end
	
	self.guildOwner = guildOwner
	
	-- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildPerksForm", wndParent, self)
    self.wndMain:Show(true)
	self.wndConfirm = self.wndMain:FindChild("ConfirmOverlay")
	self.wndConfirm:Show(false)

	self.guildOwner = guildOwner
	self.bPermissions = false -- do I have tPerk permissions

	self.tTierContainers 	= {}
	self.tCapContainers 	= {}
	self.tPerkEntries 		= {}
	self.tPerkDependencies 	= {}
	self.tAchDependencies 	= {}
	self.tTabContainers 	= {}

	-- Permissions
	local tRanks = self.guildOwner:GetRanks()
	local tMyRankPermissions = tRanks[self.guildOwner:GetMyRank()]
	self.bPermissions = tMyRankPermissions.bSpendInfluence

	-- this is all the stuff we'll move out into a load event
	local arPerks 			= self.guildOwner:GetPerks()
	local arTiersTemp 		= {}
	local arBankTabsTemp 	= {}
	local arPerksTemp 		= {}

	for key, tPerk in pairs(arPerks) do
		if karTiers[tPerk.idPerk] ~= nil then
			tPerk.nTier = karTiers[tPerk.idPerk]
			table.insert(arTiersTemp, tPerk)
		elseif karBankTabs[tPerk.idPerk] ~= nil then
			tPerk.nPos = karBankTabs[tPerk.idPerk]
			table.insert(arBankTabsTemp, tPerk)
		elseif tPerk.idPerk ~= nil then -- standard tPerk
			table.insert(arPerksTemp, tPerk)
		end
	end

	-- build everything first to ensure we have the containers to load perks into
	self:BuildTierDisplays(arTiersTemp, arPerksTemp)
	
	local tFirstTab = 
	{
		nPos = 0,
		idPerk = 0,
		bIsUnlocked = true,
	}
	
	table.insert(arBankTabsTemp, tFirstTab)
	self:BuildTabDisplay(arBankTabsTemp)

	self:BuildPerkEntries(arPerksTemp)
	self:UpdateInfluenceDisplay(self.guildOwner:GetInfluence(), self.guildOwner:GetBonusInfluenceRemaining())
end

function GuildPerks:OnTogglePerks(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then 
		return 
	end
	
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize(wndParent)
	else
		self.wndConfirm:Show(false)
		self.wndMain:Show(true)
	end
end

function GuildPerks:OnClose()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function GuildPerks:BuildTabDisplay(arBankTabsTemp)
	for idx, tBankTab in pairs(arBankTabsTemp) do
		tBankTab.wnd = self.wndMain:FindChild("TabDisplay"):FindChild("CapContainer" .. tBankTab.nPos)
		self.tTabContainers[tBankTab.idPerk] = tBankTab
	end

	self:UpdateTabDisplay()
end

function GuildPerks:UpdateTabDisplay()
	local nHighestTabUnlocked = 0
	local wndContainer = self.wndMain:FindChild("TabDisplay")
	wndContainer:FindChild("UpgradeCost"):SetText(Apollo.GetString("GuildBank_Max"))
	wndContainer:FindChild("UpgradeCost"):SetTextColor(kcrDisabledText)
	wndContainer:FindChild("UpgradeLabel"):SetTextColor(kcrDisabledText)
	wndContainer:FindChild("UpgradeButton"):Show(false)

	for idx, tBankTab in pairs(self.tTabContainers) do
		if tBankTab.bIsUnlocked and tBankTab.nPos >= nHighestTabUnlocked then
			nHighestTabUnlocked = tBankTab.nPos
		end
	end

	if nHighestTabUnlocked == 0 then
		wndContainer:FindChild("TabDisplay"):SetTooltip(Apollo.GetString("Bank_BankTabNeedsUnlock"))
	else
		wndContainer:FindChild("TabDisplay"):SetTooltip("")
	end
	
	for idx, tBankTab in pairs(self.tTabContainers) do
		if tBankTab.nPos == nHighestTabUnlocked then
			tBankTab.wnd:SetSprite("CRB_Basekit:kitBtn_Holo_DatachronOptionPressed")
			tBankTab.wnd:SetTextColor(ApolloColor.new("white"))
		else
			tBankTab.wnd:SetSprite("CRB_Basekit:kitBtn_Holo_DatachronOptionDisabled")
			tBankTab.wnd:SetTextColor(ApolloColor.new("UI_BtnTextHoloNormal"))
		end

		if tBankTab.nPos == nHighestTabUnlocked + 1 then
			wndContainer:FindChild("UpgradeCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_Cost"), tBankTab.nPurchaseInfluenceCost))
			wndContainer:FindChild("UpgradeButton"):SetData(tBankTab.idPerk)

			local bUnlocked = true
			for key, idReqPerk in pairs (tBankTab.arRequiredIds) do
				local tPerkInfo = self.tTierContainers[idReqPerk]
				if not tPerkInfo then
					tPerkInfo = self.tTabContainers[idReqPerk]
				end

				if bUnlocked == false or (tPerkInfo and tPerkInfo.bIsUnlocked == false) then
					bUnlocked = false
				end
			end

			wndContainer:FindChild("UpgradeButton"):Enable(tBankTab.nPurchaseInfluenceCost <= self.guildOwner:GetInfluence() and bUnlocked == true)
			if tBankTab.nPurchaseInfluenceCost >= self.guildOwner:GetInfluence() then
				wndContainer:FindChild("UpgradeCost"):SetTextColor(kcrDisabledTextRed)
			else
				wndContainer:FindChild("UpgradeCost"):SetTextColor(kcrEnabledText)
			end

			if self.bPermissions == true then
				wndContainer:FindChild("UpgradeButton"):Show(true)
				wndContainer:FindChild("UpgradeLabel"):SetTextColor(kcrEnabledText)
			end
		end
	end
	
	wndContainer:FindChild("UpgradeLabel"):Show(wndContainer:FindChild("UpgradeCost"):GetText() ~= Apollo.GetString("GuildPerk_NoneRemaining"))
end

function GuildPerks:BuildTierDisplays(arTiersTemp)
	self.wndMain:FindChild("TierContainer"):DestroyChildren() -- shouldn't be needed
	self.tTierContainers = {}

	local tPerkInfo = {}
	local wndFirst = Apollo.LoadForm(self.xmlDoc, "TierContainerForm", self.wndMain:FindChild("TierContainer"), self)
	--local wndFirst = self.wndMain:FindChild("TierContainer"):FindChild("TierContainerForm0")
	wndFirst:FindChild("LeftContainer"):FindChild("TierIndexLabel"):SetText("1")
	wndFirst:FindChild("LeftContainer"):FindChild("TierCost"):Show(false)
	wndFirst:FindChild("TierUnlockBtn"):Show(false)
	tPerkInfo.bIsUnlocked = true
	tPerkInfo.idPerk = 0
	tPerkInfo.nTier = 1
	tPerkInfo.wndContainer = wndFirst
	self.tTierContainers[0] = tPerkInfo

	for idx, tTierPerk in pairs(arTiersTemp) do
		local wndContainer = Apollo.LoadForm(self.xmlDoc, "TierContainerForm", self.wndMain:FindChild("TierContainer"), self)
		tTierPerk.wndContainer = wndContainer
		self.tTierContainers[tTierPerk.idPerk] = tTierPerk
	end

	self:FormatTierDisplays()

	for key, tTierInfo in pairs(self.tTierContainers) do
		tTierInfo.wndContainer:FindChild("PerkList"):ArrangeChildrenHorz(1)
	end
end

function GuildPerks:FormatTierDisplays()
	local nLastUnlock = 1
	for idx, tTierPerk in pairs(self.tTierContainers) do
		tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierIndexLabel"):SetText(tTierPerk.nTier)
		tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierCost"):Show(not tTierPerk.bIsUnlocked)
		tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_TierCost"), tTierPerk.nPurchaseInfluenceCost))
		tTierPerk.wndContainer:FindChild("TierUnlockBtn"):Show(not tTierPerk.bIsUnlocked)
		tTierPerk.wndContainer:FindChild("TierBGArt_LeftBack"):Show(true)
		tTierPerk.wndContainer:FindChild("TierBGArt_LeftBackNext"):Show(false)
		--tTierPerk.wndContainer:FindChild("TierBGArt_RightBackFrame"):Show(tTierPerk.bIsUnlocked)

		if tTierPerk.bIsUnlocked == true then
			--tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierLabel"):SetTextColor(UI_TextHoloTitle)
			--tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierIndexLabel"):SetTextColor(UI_TextHoloTitle)
			tTierPerk.wndContainer:FindChild("TierBGArt_RightBack"):SetBGColor(CColor.new(1,1,1,1))
			tTierPerk.wndContainer:FindChild("TierBGArt_LeftBack"):SetBGColor(CColor.new(1,1,1,1))
			if tTierPerk.nTier >= nLastUnlock then
				nLastUnlock = tTierPerk.nTier
			end
		else
			tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierLabel"):SetTextColor(kcrDisabledText)
			tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierIndexLabel"):SetTextColor(kcrDisabledText)
			tTierPerk.wndContainer:FindChild("TierBGArt_RightBack"):SetBGColor(CColor.new(0.5,0.5,0.5,1))
			tTierPerk.wndContainer:FindChild("TierBGArt_LeftBack"):SetBGColor(CColor.new(0.5,0.5,0.5,1))
			tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierCost"):SetTextColor(kcrDisabledText)
		end
	end

	for idx, tTierPerk in pairs(self.tTierContainers) do
		local bIsNextTier = tTierPerk.nTier == nLastUnlock + 1

		tTierPerk.wndContainer:FindChild("TierUnlockBtn"):Show(self.bPermissions and bIsNextTier)
		tTierPerk.wndContainer:FindChild("TierArrangeBuffer"):Show(self.bPermissions and bIsNextTier)
		--if tTierPerk.wndContainer:FindChild("TierUnlockBtn"):IsShown() then
		if bIsNextTier then
			if self.guildOwner:GetInfluence() >= tTierPerk.nPurchaseInfluenceCost then
				tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierCost"):SetTextColor(kcrEnabledText)
				tTierPerk.wndContainer:FindChild("TierUnlockBtn"):SetData(tTierPerk.idPerk)
				tTierPerk.wndContainer:FindChild("TierUnlockBtn"):Enable(true)
			else
				tTierPerk.wndContainer:FindChild("LeftContainer"):FindChild("TierCost"):SetTextColor(kcrDisabledTextRed)
				tTierPerk.wndContainer:FindChild("TierUnlockBtn"):Enable(false)
			end

			if self.bPermissions == true then
				tTierPerk.wndContainer:FindChild("TierBGArt_LeftBack"):Show(false)
				tTierPerk.wndContainer:FindChild("TierBGArt_LeftBackNext"):Show(true)
			end
		end

		tTierPerk.wndContainer:FindChild("LeftContainer"):ArrangeChildrenVert(1)
	end

	self.wndMain:FindChild("TierContainer"):ArrangeChildrenVert()
end

function GuildPerks:BuildPerkEntries(arPerksTemp)

	self.tPerkDependencies = {}
	self.tAchDependencies = {}

	for key, tTierPerk in pairs(self.tTierContainers) do
		tTierPerk.wndContainer:FindChild("PerkList"):DestroyChildren()
	end

	-- build and distribute perks
	self.tPerkEntries = {}
	for key, tPerk in pairs(arPerksTemp) do
		local nTier = 0
		for key2, tReqPerk in pairs(tPerk.arRequiredIds) do
			if karTiers[tReqPerk] ~= nil then
				nTier = tReqPerk
			else
				self.tPerkDependencies[tReqPerk] = tPerk.idPerk -- index the req to the one to be updated
			end
		end

		if tPerk.achRequired ~= nil then
			self.tAchDependencies[tPerk.achRequired:GetId()] = tPerk.idPerk -- index the req to the one to be updated
		end

		local wndEntry = Apollo.LoadForm(self.xmlDoc, "IndividualPerkEntry", self.tTierContainers[nTier].wndContainer:FindChild("PerkList"), self)
		tPerk.nParent = self.tTierContainers[nTier].idPerk
		tPerk.wndParent = self.tTierContainers[nTier].wndContainer
		tPerk.wndContainer = wndEntry
		tPerk.wndContainer:SetData(tPerk.idPerk)

		self.tPerkEntries[tPerk.idPerk] = tPerk

	end

	-- after the whole list is done, format
	for idPerk, tPerkEntry in pairs(self.tPerkEntries) do
		self:FormatPerkWindow(idPerk) -- indexed by id
	end

	for key, tiers in pairs(self.tTierContainers) do
		tiers.wndContainer:FindChild("PerkList"):ArrangeChildrenHorz(1)
	end
end

function GuildPerks:FormatPerkWindow(idPerk)
	local tPerkEntry = self.tPerkEntries[idPerk]
	local wndFrameToUse = tPerkEntry.wndContainer:FindChild("ButtonAssets")
	tPerkEntry.wndContainer:FindChild("ButtonAssets"):Show(false)
	tPerkEntry.wndContainer:FindChild("NoButtonAssets"):Show(false)

	if tPerkEntry == nil or tPerkEntry.wndContainer == nil then
		return
	end

	local bTierUnlocked = self.tTierContainers[tPerkEntry.nParent] ~= nil and self.tTierContainers[tPerkEntry.nParent].bIsUnlocked

	if bTierUnlocked == false then -- tier locked; can ignore permissions and cost
		wndFrameToUse = tPerkEntry.wndContainer:FindChild("NoButtonAssets")
		wndFrameToUse:FindChild("BGArtTierOpen"):Show(false)
		wndFrameToUse:FindChild("BGArtTierClosed"):Show(true)
		wndFrameToUse:FindChild("BGArtTierClosed"):FindChild("Icon"):SetSprite(tPerkEntry.strSprite)
		wndFrameToUse:FindChild("UnlockCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_Cost"), tPerkEntry.nPurchaseInfluenceCost))
		--wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrDisabledText)
		wndFrameToUse:FindChild("LockOverlay"):Show(true) -- not needed since the whole tier is locked
		wndFrameToUse:FindChild("ActivateFrame"):Show(false)
	elseif tPerkEntry.bIsUnlocked == true then -- tier unlocked, tPerkEntry unlocked, draws the same for everyone
		if self.bPermissions == true and tPerkEntry.nActivateInfluenceCost > 0 then
			wndFrameToUse = tPerkEntry.wndContainer:FindChild("ButtonAssets")
			wndFrameToUse:FindChild("BGArtTierOpen"):Show(true)
			wndFrameToUse:FindChild("BGArtTierClosed"):Show(false)
			wndFrameToUse:FindChild("ActivateBtn"):Show(true)
			wndFrameToUse:FindChild("UnlockBtn"):Show(false)
			wndFrameToUse:FindChild("UnlockCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_Cost"), tPerkEntry.nActivateInfluenceCost))
			wndFrameToUse:FindChild("UnlockBtn"):Enable(self.guildOwner:GetInfluence() >= tPerkEntry.nActivateInfluenceCost)
			wndFrameToUse:FindChild("ActivateBtn"):SetData(tPerkEntry.idPerk)
			wndFrameToUse:FindChild("Icon"):SetSprite(tPerkEntry.strSprite)

			if self.guildOwner:GetInfluence() >= tPerkEntry.nActivateInfluenceCost then
				wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrEnabledText)
			else
				wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrDisabledTextRed)
			end
		else
			wndFrameToUse = tPerkEntry.wndContainer:FindChild("NoButtonAssets")
			wndFrameToUse:FindChild("BGArtTierOpen"):Show(true)
			wndFrameToUse:FindChild("BGArtTierClosed"):Show(false)
			wndFrameToUse:FindChild("BGArtTierOpen"):FindChild("Icon"):SetSprite(tPerkEntry.strSprite)
			wndFrameToUse:FindChild("UnlockCost"):SetText(Apollo.GetString("GuildPerk_Owned"))
			wndFrameToUse:FindChild("UnlockCost"):SetTextColor(ApolloColor.new("vdarkgray"))
			wndFrameToUse:FindChild("Icon"):SetSprite(tPerkEntry.strSprite)
		end

		wndFrameToUse:FindChild("LockOverlay"):Show(false)
		wndFrameToUse:FindChild("ActivateFrame"):Show(tPerkEntry.nActivateInfluenceCost > 0)
		local bActive = tPerkEntry.fDurationInDays ~= 0 and tPerkEntry.fDurationInDays ~= nil
		wndFrameToUse:FindChild("ActivateFrame"):FindChild("Activate_Inop"):Show(not bActive)
		wndFrameToUse:FindChild("ActivateFrame"):FindChild("Activate_Running"):Show(bActive)

	else -- unlocked tier, locked tPerkEntry
		local bCanAffordInf = self.guildOwner:GetInfluence() >= tPerkEntry.nPurchaseInfluenceCost
		local bPrereqsMet = true
		local bAchMet = true

		for idx, nPrereq in pairs(tPerkEntry.arRequiredIds) do
			if nPrereq ~= nil and self.tPerkEntries[nPrereq] ~= nil then -- exists, not a tier
				if self.tPerkEntries[nPrereq].bIsUnlocked == false then
					bPrereqsMet = false
				end
			end
		end

		if tPerkEntry.achRequired ~= nil then
			bAchMet = tPerkEntry.achRequired:IsComplete()
		end

		if self.bPermissions == true then -- can unlock
			wndFrameToUse = tPerkEntry.wndContainer:FindChild("ButtonAssets")
			wndFrameToUse:FindChild("Icon"):SetSprite(tPerkEntry.strSprite)
			wndFrameToUse:FindChild("LockOverlay"):Show(true)
			wndFrameToUse:FindChild("ActivateBtn"):Show(false)
			wndFrameToUse:FindChild("UnlockBtn"):Show(true)
			wndFrameToUse:FindChild("UnlockBtn"):Enable(bPrereqsMet and bAchMet and bCanAffordInf)
			wndFrameToUse:FindChild("UnlockBtn"):SetData(tPerkEntry.idPerk)
		else
			wndFrameToUse = tPerkEntry.wndContainer:FindChild("NoButtonAssets")
			wndFrameToUse:FindChild("BGArtTierOpen"):FindChild("Icon"):SetSprite(tPerkEntry.strSprite)
			wndFrameToUse:FindChild("LockOverlay"):Show(true)
		end

		wndFrameToUse:FindChild("ActivateFrame"):Show(false)
		wndFrameToUse:FindChild("UnlockCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_Cost"), tPerkEntry.nPurchaseInfluenceCost))
		wndFrameToUse:FindChild("BGArtTierOpen"):Show(true)
		wndFrameToUse:FindChild("BGArtTierClosed"):Show(false)

		if bCanAffordInf == false then
			wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrDisabledTextRed)
		else
			wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrEnabledText)
		end
	end

	wndFrameToUse:Show(true)
end


function GuildPerks:UpdateInfluenceDisplay(nCurrent, nBonusRemaining)
	self.wndMain:FindChild("InfluenceProgressBar"):SetMax(knMaxInfluence)
	self.wndMain:FindChild("InfluenceProgressBar"):SetProgress(nCurrent)
	self.wndMain:FindChild("InfluenceProgressBar"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_InfluenceListing"), nCurrent, knMaxInfluence, nBonusRemaining))

	self.wndMain:FindChild("InfluenceBonusProgressBar"):SetMax(knMaxInfluence)
	self.wndMain:FindChild("InfluenceBonusProgressBar"):SetProgress(nCurrent + nBonusRemaining)
end


function GuildPerks:DrawConfirmWindow(wndBtn, nId, strName, bActivate)

	self.wndConfirm:FindChild("ConfirmActivateBtn"):SetData(nId)
	self.wndConfirm:FindChild("ConfirmBuyBtn"):SetData(nId)

	local strConfirm = Apollo.GetString("GuildPerk_UnlockingPerk")
	if bActivate == true then
		strConfirm = Apollo.GetString("GuildPerk_ActivatingPerk")
	end

	self.wndConfirm:FindChild("ConfirmActivateBtn"):Show(bActivate)
	self.wndConfirm:FindChild("ConfirmBuyBtn"):Show(not bActivate)

	self.wndConfirm:FindChild("TitleText"):SetText(String_GetWeaselString(strConfirm, strName))

	self.wndConfirm:Show(true, true)
	self.wndConfirm:ToFront()
end

-----------------------------------------------------------------------------------------------
-- Update Event Functions
-----------------------------------------------------------------------------------------------

function GuildPerks:OnUpdateEntry(guildOwner, idPerk)
	-- Our generic handler for updating all kids of perks when enabled/disabled/activated/deactivated
	if not self.wndMain or not self.wndMain:IsValid() or self.guildOwner == nil or self.guildOwner ~= guildOwner or not self.wndMain:IsShown() then
		return
	end

	local tUpdatedPerk = self.guildOwner:GetPerk( idPerk )

	-- update the tPerkEntry's table while perserving our created values (tiers, etc)
	if self.tTierContainers[idPerk] ~= nil then
		self:UpdateEntryValues(self.tTierContainers[idPerk], tUpdatedPerk)
		self:FormatTierDisplays()
		self:UpdateTabDisplay()

		for idx, tPerk in pairs(self.tPerkEntries) do
			if tPerk.nParent == idPerk then
				self:FormatPerkWindow(tPerk.idPerk)
			end
		end
	--[[
	elseif karCapLimits[idPerk] ~= nil then
		self:UpdateEntryValues(self.tCapContainers[idPerk], tUpdatedPerk)
		self:UpdateCapDisplay()
	--]]
	elseif karBankTabs[idPerk] ~= nil then
		self:UpdateEntryValues(self.tTabContainers[idPerk], tUpdatedPerk)
		self:UpdateTabDisplay()

	elseif self.tPerkEntries[idPerk] ~= nil then
		self:UpdateEntryValues(self.tPerkEntries[idPerk], tUpdatedPerk)
		self:FormatPerkWindow(idPerk)

		if self.tPerkDependencies[idPerk] ~= nil then -- update any this depended on
			self:UpdateEntryValues(self.tPerkEntries[idPerk], tUpdatedPerk)
			self:FormatPerkWindow(self.tPerkDependencies[idPerk])
		end
	end
end

function GuildPerks:UpdateEntryValues(tActivatablePerk, tUpdatedPerk) -- update with new values
	tActivatablePerk.bIsUnlocked = tUpdatedPerk.bIsUnlocked
	tActivatablePerk.fDurationInDays = tUpdatedPerk.fDurationInDays
	tActivatablePerk.nActivateInfluenceCost = tUpdatedPerk.nActivateInfluenceCost
end

function GuildPerks:OnAchievementUpdated(achUpdated)
	if not self.wndMain or not self.wndMain:IsValid() or self.guildOwner == nil or not self.wndMain:IsShown() then
		return
	end

	if self.tPerkDependencies[achUpdated:GetId()] ~= nil then
		self:FormatPerkWindow(self.tPerkDependencies[achUpdated:GetId()])
	end
end

function GuildPerks:OnInfluenceUpdated(guildOwner, nInfluence, monCash)
	if not self.wndMain or not self.wndMain:IsValid() or self.guildOwner == nil or self.guildOwner ~= guildOwner or not self.wndMain:IsShown() then
		return
	end

	self:UpdateInfluenceDisplay(self.guildOwner:GetInfluence(), self.guildOwner:GetBonusInfluenceRemaining())
	self:AdjustCosts(self.guildOwner:GetInfluence())
end

function GuildPerks:AdjustCosts(nInfluence)
	self:FormatTierDisplays()
	--self:UpdateCapDisplay()
	self:UpdateTabDisplay()

	-- find locked but available entries
	local tPerksToAdjust = {}
	for idx, tPerkEntry in pairs(self.tPerkEntries) do
		self:FormatPerkWindow(tPerkEntry.idPerk)
	end
end

function GuildPerks:DrawMoreInfoWindow(idEntry, nLeft, nTop)

	if idEntry == nil then
		return false
	end

	if self.wndMoreInfo ~= nil then
		local idCurrent = self.wndMoreInfo:GetData()
		if idCurrent ~= nil and idCurrent ~= idEntry then
			self.wndMoreInfo:Destroy()
			self.wndMoreInfo = nil
		else
			return
		end
	end

	self.wndMoreInfo = Apollo.LoadForm(self.xmlDoc, "GuildPerkDetail", self.wndMain:FindChild("MoreInfoOverlayContainer"), self)
	self.wndMoreInfo:SetData(idEntry)
	self.wndMoreInfo:ToFront()

	local tPerkEntry = self.tPerkEntries[idEntry]
	if tPerkEntry == nil or self.wndMoreInfo == nil then
		return
	end

	local wndFrameToUse = self.wndMoreInfo:FindChild("NoButtonAssets")
	self.wndMoreInfo:FindChild("ButtonAssets"):Show(false)
	self.wndMoreInfo:FindChild("NoButtonAssets"):Show(false)

	local bTierUnlocked = self.tTierContainers[tPerkEntry.nParent] ~= nil and self.tTierContainers[tPerkEntry.nParent].bIsUnlocked

	if bTierUnlocked == false then -- tier locked; can ignore permissions and cost
		wndFrameToUse = self.wndMoreInfo:FindChild("NoButtonAssets")
		wndFrameToUse:FindChild("ActivateFrame"):Show(false)
		wndFrameToUse:FindChild("UnlockCost"):SetTextColor(ApolloColor.new("vdarkgray"))
		wndFrameToUse:FindChild("UnlockCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_Cost"), tPerkEntry.nPurchaseInfluenceCost))
		self.wndMoreInfo:FindChild("Status"):SetText(Apollo.GetString("GuildPerk_TierLocked"))

	elseif tPerkEntry.bIsUnlocked == true then -- tier unlocked, tPerkEntry unlocked, draws the same for everyone
		if self.bPermissions == true and tPerkEntry.nActivateInfluenceCost > 0 then
			wndFrameToUse = self.wndMoreInfo:FindChild("ButtonAssets")
			wndFrameToUse:FindChild("ActivateBtn"):Show(true)
			wndFrameToUse:FindChild("UnlockBtn"):Show(false)
			wndFrameToUse:FindChild("UnlockCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_Cost"), tPerkEntry.nActivateInfluenceCost))
			wndFrameToUse:FindChild("UnlockBtn"):Enable(self.guildOwner:GetInfluence() >= tPerkEntry.nActivateInfluenceCost)
			wndFrameToUse:FindChild("ActivateBtn"):SetData(tPerkEntry.idPerk)

			if self.guildOwner:GetInfluence() >= tPerkEntry.nActivateInfluenceCost then
				wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrEnabledText)
			else
				wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrDisabledTextRed)
			end
		else
			wndFrameToUse = self.wndMoreInfo:FindChild("NoButtonAssets")
			wndFrameToUse:FindChild("UnlockCost"):SetText(Apollo.GetString("GuildPerk_Owned"))
			wndFrameToUse:FindChild("UnlockCost"):SetTextColor(ApolloColor.new("vdarkgray"))
		end

		wndFrameToUse:FindChild("ActivateFrame"):Show(tPerkEntry.nActivateInfluenceCost > 0)
		local bActive = tPerkEntry.fDurationInDays ~= 0 and tPerkEntry.fDurationInDays ~= nil
		wndFrameToUse:FindChild("ActivateFrame"):FindChild("Activate_Inop"):Show(not bActive)
		wndFrameToUse:FindChild("ActivateFrame"):FindChild("Activate_Running"):Show(bActive)

		if tPerkEntry.nActivateInfluenceCost > 0 then
			if bActive then
				self.wndMoreInfo:FindChild("Status"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_CurrentlyActive"), self:HelperCalculateTimeRemaining(tPerkEntry.fDurationInDays)))
			else
				self.wndMoreInfo:FindChild("Status"):SetText(Apollo.GetString("GuildPerk_NeedsToBeActivated"))
			end
		else
			self.wndMoreInfo:FindChild("Status"):SetText("")
		end

	else -- unlocked tier, locked tPerkEntry
		local bCanAfford = self.guildOwner:GetInfluence() >= tPerkEntry.nPurchaseInfluenceCost
		local bPrereqPerksMet = true
		local bPrereqAchMet = true
		self.wndMoreInfo:FindChild("Status"):SetText(Apollo.GetString("GuildPerk_Locked"))

		for idx, nPrereqId in pairs(tPerkEntry.arRequiredIds) do
			if nPrereqId ~= nil and self.tPerkEntries[nPrereqId] ~= nil then -- exists, not a tier
				if self.tPerkEntries[nPrereqId].bIsUnlocked == false then
					bPrereqPerksMet = false
				end
			end
		end

		if tPerkEntry.achRequired ~= nil then
			bPrereqAchMet = tPerkEntry.achRequired:IsComplete()
		end

		if self.bPermissions == true then -- can unlock
			wndFrameToUse = self.wndMoreInfo:FindChild("ButtonAssets")
			wndFrameToUse:FindChild("ActivateBtn"):Show(false)
			wndFrameToUse:FindChild("UnlockBtn"):Show(true)
			wndFrameToUse:FindChild("UnlockBtn"):Enable(bPrereqPerksMet and bPrereqAchMet and bCanAfford)
			wndFrameToUse:FindChild("UnlockBtn"):SetData(tPerkEntry.idPerk)
		else
			wndFrameToUse = self.wndMoreInfo:FindChild("NoButtonAssets")
		end

		wndFrameToUse:FindChild("ActivateFrame"):Show(false)
		wndFrameToUse:FindChild("UnlockCost"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_Cost"), tPerkEntry.nPurchaseInfluenceCost))

		if bCanAfford == false then
			wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrDisabledTextRed)
		else
			wndFrameToUse:FindChild("UnlockCost"):SetTextColor(kcrEnabledText)
		end
	end

	self.wndMoreInfo:FindChild("Title"):SetText(tPerkEntry.strTitle)
	self.wndMoreInfo:FindChild("Title"):SetHeightToContentHeight()
	wndFrameToUse:FindChild("Icon"):SetSprite(tPerkEntry.strSprite)
	wndFrameToUse:FindChild("LockOverlay"):Show(not tPerkEntry.bIsUnlocked)

	wndFrameToUse:Show(true)


	-- Lower Panel Formatting
	self.wndMoreInfo:FindChild("Description"):SetText(tPerkEntry.strDescription)
	self.wndMoreInfo:FindChild("Description"):SetHeightToContentHeight()
	self.wndMoreInfo:FindChild("Description"):Show(true)

	-- Required Achievements
	self.wndMoreInfo:FindChild("AchContainer"):Show(tPerkEntry.achRequired ~= nil)
	self.wndMoreInfo:FindChild("AchBuffer"):Show(tPerkEntry.achRequired ~= nil)
	if tPerkEntry.achRequired ~= nil then
		self.wndMoreInfo:FindChild("AchContainer"):FindChild("AchText"):SetText(tPerkEntry.achRequired:GetName())
		if tPerkEntry.achRequired:IsComplete() then
			self.wndMoreInfo:FindChild("AchContainer"):FindChild("AchText"):SetTextColor(kcrEnabledText)
			self.wndMoreInfo:FindChild("AchContainer"):FindChild("AchIcon"):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Checkmark")
		else
			self.wndMoreInfo:FindChild("AchContainer"):FindChild("AchText"):SetTextColor(kcrDisabledTextRed)
			self.wndMoreInfo:FindChild("AchContainer"):FindChild("AchIcon"):SetSprite("ClientSprites:LootCloseBox")
		end
	end

	-- Required Perks
	local nPerksRequired = 0
	local wndPerkReq = self.wndMoreInfo:FindChild("PerkContainer")
	for idx, nPrereqId in pairs(tPerkEntry.arRequiredIds) do
		if nPrereqId ~= nil and self.tPerkEntries[nPrereqId] ~= nil then -- exists, not a tier
			nPerksRequired = nPerksRequired + 1
			local wndRequiredEntry = wndPerkReq:FindChild("EntryContainer_" .. nPerksRequired)
			wndRequiredEntry:FindChild("Text"):SetText(self.tPerkEntries[nPrereqId].strTitle)

			if self.tPerkEntries[nPrereqId].bIsUnlocked == true then
				wndRequiredEntry:FindChild("Text"):SetTextColor(kcrEnabledText)
				wndRequiredEntry:FindChild("Icon"):SetSprite("ClientSprites:Icon_Windows_UI_CRB_Checkmark")
			else
				wndRequiredEntry:FindChild("Text"):SetTextColor(kcrDisabledTextRed)
				wndRequiredEntry:FindChild("Icon"):SetSprite("ClientSprites:LootCloseBox")
			end
		end
	end

	if nPerksRequired > 0 then
		local nEntryLeft, nEntryTop, nEntryRight, nEntryBottom = wndPerkReq:FindChild("EntryContainer_" .. nPerksRequired):GetAnchorOffsets()
		local nParentLeft, nParentTop, nParentRight, nParentBottom = wndPerkReq:GetAnchorOffsets()
		wndPerkReq:SetAnchorOffsets(nParentLeft, nParentTop, nParentRight, nParentTop + nEntryBottom)
	end

	wndPerkReq:Show(nPerksRequired > 0)
	self.wndMoreInfo:FindChild("PerkBuffer"):Show(nPerksRequired > 0)

	-- Activation Costs
	self.wndMoreInfo:FindChild("ActivateCost"):FindChild("Amount"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_TierCost"), tPerkEntry.nActivateInfluenceCost))
	self.wndMoreInfo:FindChild("ActivateCost"):Show(tPerkEntry.nActivateInfluenceCost > 0)
	if self.guildOwner:GetInfluence() < tPerkEntry.nActivateInfluenceCost then
		self.wndMoreInfo:FindChild("ActivateCost"):FindChild("Amount"):SetTextColor(kcrDisabledTextRed)
	else
		self.wndMoreInfo:FindChild("ActivateCost"):FindChild("Amount"):SetTextColor(kcrEnabledText)
	end

	-- Unlock Costs
	self.wndMoreInfo:FindChild("UnlockCostDisplay"):FindChild("Amount"):SetText(String_GetWeaselString(Apollo.GetString("GuildPerk_TierCost"), tPerkEntry.nPurchaseInfluenceCost))
	if tPerkEntry.bIsUnlocked then
		self.wndMoreInfo:FindChild("UnlockCostDisplay"):FindChild("Amount"):SetTextColor(kcrDisabledText)
	elseif self.guildOwner:GetInfluence() < tPerkEntry.nPurchaseInfluenceCost then
		self.wndMoreInfo:FindChild("UnlockCostDisplay"):FindChild("Amount"):SetTextColor(kcrDisabledTextRed)
	else
		self.wndMoreInfo:FindChild("UnlockCostDisplay"):FindChild("Amount"):SetTextColor(kcrEnabledText)
	end

	self.wndMoreInfo:FindChild("UpperSortContainer"):ArrangeChildrenVert()
	self.wndMoreInfo:FindChild("LowerSortContainer"):ArrangeChildrenVert()

	local nFrameLeft, nFrameTop, nFrameRight, bFrame = self.wndMoreInfo:GetAnchorOffsets()
	local nSortLeft, nSortTop, nSortRight, nSortBottom = self.wndMoreInfo:FindChild("LowerSortContainer"):GetAnchorOffsets()
	local nBaseLeft, nBaseTop, nBaseRight, nBaseBottom = self.wndMoreInfo:FindChild("LowerBound"):GetAnchorOffsets()
	self.wndMoreInfo:SetAnchorOffsets(nFrameLeft, nFrameTop, nFrameRight, nSortTop + nBaseBottom)

	local nWidth = self.wndMoreInfo:GetWidth()
	local nHeight = self.wndMoreInfo:GetHeight()

	self.wndMoreInfo:Move(nLeft, nTop, nWidth, nHeight)
end

-----------------------------------------------------------------------------------------------
-- GuildPerksForm Functions
-----------------------------------------------------------------------------------------------

function GuildPerks:OnEntryMouseEnter(wndHandler, wndControl)

	if wndHandler ~= wndControl then
		return false
	end

	local wndEntry = wndControl:GetParent()
	local nId = wndEntry:GetData()

	-- dicey if windows get moved/added
	local nEntryLeft, nEntryTop, nEntryRight, nEntryBottom = wndEntry:GetRect()
	local nListLeft, nListTop, nListRight, nListBottom = wndEntry:GetParent():GetRect()
	local nTierLeft, nTierTop, nTierRight, nTierBottom = wndEntry:GetParent():GetParent():GetRect()

	local nLeft = nEntryLeft + nListLeft + nTierLeft
	local nTop = nEntryTop + nListTop + nTierTop

	if wndControl:ContainsMouse() and nId ~= nil then
		self:DrawMoreInfoWindow(nId, nLeft, nTop)
	end
end

function GuildPerks:OnEntryMouseExit(wndHandler, wndControl)
	if wndHandler ~= wndControl or wndControl:ContainsMouse() == true then
		return
	end

	local wndEntry = wndControl:GetParent()
	local nId = wndEntry:GetData()

	if self.wndMoreInfo ~= nil and nId == self.wndMoreInfo:GetData() then
		self.wndMoreInfo:Destroy()
		self.wndMoreInfo = nil
	end
end

function GuildPerks:OnUnlockBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local nId = wndControl:GetData()
	if nId ~= nil then
		self:DrawConfirmWindow(wndControl, nId, self.tPerkEntries[nId].strTitle, false)
	end
end

function GuildPerks:OnUnlockTierBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local nId = wndControl:GetData()
	if nId ~= nil then
		self:DrawConfirmWindow(wndControl, nId, self.tTierContainers[nId].strTitle, false)
	end
end

function GuildPerks:OnUnlockTabBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local nId = wndControl:GetData()
	if nId ~= nil then
		self:DrawConfirmWindow(wndControl, nId, self.tTabContainers[nId].strTitle, false)
	end
end

function GuildPerks:OnUnlockCapBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local nId = wndControl:GetData()
	if nId ~= nil then
		self:DrawConfirmWindow(wndControl, nId, self.tCapContainers[nId].strTitle, false)
	end
end

function GuildPerks:OnActivateBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local nId = wndControl:GetData()
	if nId ~= nil then
		self:DrawConfirmWindow(wndControl, nId, self.tPerkEntries[nId].strTitle, true)
	end
end

function GuildPerks:OnCancel(wndHandler, wndControl)
	self.wndMain:Show(false)
end

function GuildPerks:ApproveConfirmBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local nId = wndControl:GetData()
	if nId ~= nil then
		self.guildOwner:PurchasePerk(nId)
	end

	self.wndConfirm:Show(false)
end

function GuildPerks:ApproveActivateBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local nId = wndControl:GetData()
	if nId ~= nil then
		self.guildOwner:ActivatePerk(nId)
	end

	self.wndConfirm:Show(false)
end

function GuildPerks:CancelConfirmBtn()
	self.wndConfirm:Show(false)
end

function GuildPerks:OnSocialPanelBtn(wndHandler, wndControl)
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	Event_FireGenericEvent("EventGeneric_OpenSocialPanel", { ["x"] = nLeft, ["y"] = nTop })
	self:OnCancel()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------
function GuildPerks:HelperCalculateTimeRemaining(fDays)
	local tTimeData =
	{
		["name"]	= "",
		["count"]	= nil,
	}

	local nDaysRounded = math.floor(fDays / 1)
	local fHours = fDays * 24
	local nHoursRounded = math.floor(fHours)
	local nMinutes = math.floor(fHours * 60)

	local strReturn = nil

	if nDaysRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Day")
		tTimeData["count"] = nDaysRounded
	elseif nHoursRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Hour")
		tTimeData["count"] = nHoursRounded
	elseif nMinutes > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = nMinutes
	else
		strReturn = Apollo.GetString("GuildPerk_LessThanAMinute")
	end

	if not strReturn then
		strReturn = String_GetWeaselString(Apollo.GetString("CRB_Multiple"), tTimeData)
	end

	return strReturn
end

-----------------------------------------------------------------------------------------------
-- GuildPerks Instance
-----------------------------------------------------------------------------------------------
local GuildPerksInst = GuildPerks:new()
GuildPerksInst:Init()
