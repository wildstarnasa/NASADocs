-----------------------------------------------------------------------------------------------
-- Client Lua Script for AbilityAMPs
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "AbilityBook"

local AbilityAMPs = {}

-- TODO: Replace with enums
local knCategoryUtilityId 			= 1
local knCategorySupportId 			= 2
local knCategoryDamageId 			= 3
local knCategoryDamageSupportId 	= 4
local knCategoryDamageUtilitytId 	= 5
local knCategorySupportUtilityId 	= 6

local karCategoryToConstantData =
{
	[knCategoryUtilityId] 			= {strLightBulbName = "LightBulbS",		strLightBulbSprite = "spr_AMPS_MiddleGlow_S", 	strName = Apollo.GetString("AMP_Utility"),		strLabelName = "LabelUtility",		strButtonLabel = "UtilityLabel" },
	[knCategorySupportId]			= {strLightBulbName = "LightBulbNE",	strLightBulbSprite = "spr_AMPS_MiddleGlow_NE",	strName = Apollo.GetString("AMP_Support"), 		strLabelName = "LabelSupport",		strButtonLabel = "SupportLabel" },
	[knCategoryDamageId] 			= {strLightBulbName = "LightBulbNW",	strLightBulbSprite = "spr_AMPS_MiddleGlow_NW", 	strName = Apollo.GetString("AMP_Assault"),		strLabelName = "LabelAssault",		strButtonLabel = "AssaultLabel" },
	[knCategoryDamageSupportId] 	= {strLightBulbName = "LightBulbN",		strLightBulbSprite = "spr_AMPS_MiddleGlow_N", 	strName = Apollo.GetString("AMP_Hybrid"),		strLabelName = "LabelHybrid",		strButtonLabel = "AssaultSupportLabel" },
	[knCategoryDamageUtilitytId] 	= {strLightBulbName = "LightBulbSE",	strLightBulbSprite = "spr_AMPS_MiddleGlow_SW", 	strName = Apollo.GetString("AMP_PvPOffense"),	strLabelName = "LabelPvPOffense",	strButtonLabel = "AssaultUtilityLabel" },
	[knCategorySupportUtilityId] 	= {strLightBulbName = "LightBulbSW",	strLightBulbSprite = "spr_AMPS_MiddleGlow_SE", 	strName = Apollo.GetString("AMP_PvPDefense"),	strLabelName = "LabelPvPDefense",	strButtonLabel = "UtilitySupportLabel" },
}

local karCategoriesInClockwiseOrder =
{
	knCategoryUtilityId,
	knCategoryDamageUtilitytId,
	knCategoryDamageId,
	knCategoryDamageSupportId,
	knCategorySupportId,
	knCategorySupportUtilityId,
}

local knDefaultZoom						= 21.31				-- 21.47 without top banner
local knLowestZoom						= 21.31				-- 21.47 without top banner
local knColumnsPerCategory 				= 8 				-- How many columns exist for each category (columns)
local knNumRows 						= 12 				-- Number of rows in the radial grid

local knAugmentationActivatedColor 		= "btn_AMPS_CirclePressed"		-- On
local knAugmentationInactivatedColor 	= "btn_AMPS_CircleNormal"		-- Can Click
local knAugmentationAlmostThereColor 	= "spr_AMPs_LockStretch_Blue"	-- 1 Away from Can Click
local knAugmentationInaccessibleColor 	= "spr_AMPs_LockStretch_Grey"
local knAugmentationUnavailableColor 	= "spr_AMPs_LockStretch_Red"

local ktAugmentationValidationResult =
{
	[ActionSetLib.CodeEnumLimitedActionSetResult.Ok]									= Apollo.GetString("EldanAugmentation_Ok"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_LockedInlaid]		= Apollo.GetString("EldanAugmentation_LockedInlaidAugmentation"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_LockedCategoryTier]	= Apollo.GetString("EldanAugmentation_LockedCategoryTier"), -- TODO rename to rank
	[ActionSetLib.CodeEnumLimitedActionSetResult.UnknownClassId]						= Apollo.GetString("EldanAugmentation_InvalidClass"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_InvalidSeries] 		= Apollo.GetString("EldanAugmentation_InvalidSeries"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_InvalidId]			= Apollo.GetString("EldanAugmentation_InvalidEldanAugmentationId"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_InvalidCategoryId]	= Apollo.GetString("EldanAugmentation_InvalidAugmentationCategoryId"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_InvalidCategoryTier]	= Apollo.GetString("EldanAugmentation_InvalidAugmentationCategoryTier"),
}

function AbilityAMPs:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWndRefs = {}

    return o
end

function AbilityAMPs:Init()
    Apollo.RegisterAddon(self)
end

function AbilityAMPs:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AbilityAMPs.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function AbilityAMPs:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_OpenEldanAugmentation", 		"Initialize", self)
	Apollo.RegisterEventHandler("GenericEvent_CloseEldanAugmentation", 		"OnClose", self)
	Apollo.RegisterEventHandler("CharacterUnlockedInlaidEldanAugmentation", "BuildFromEvent", self)
	Apollo.RegisterEventHandler("CharacterEldanAugmentationsUpdated", 		"BuildFromEvent", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 						"BuildFromEvent", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AMPPoint",					"BuildFromEvent", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 					"OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("PlayerResurrected", 						"OnPlayerResurrected", self)
	Apollo.RegisterEventHandler("ShowResurrectDialog", 						"OnShowResurrectDialog", self)
	--unkown duration, setting default. later will be set correctly on HelperCreateMessage
	self.timerMessageDisplay = ApolloTimer.Create(1.0, false, "OnMessageDisplayTimer", self)
	self.timerMessageDisplay:Stop()

	self.tWndRefs.wndMain = nil
	self.nVScrollPos = 170
	self.nZoomLevel = knDefaultZoom
end

function AbilityAMPs:Initialize(wndParent)
	self.arHighestUnlockedTier = {}
	self:OnStartRedrawAll(wndParent)
end

function AbilityAMPs:OnStartRedrawAll(wndParent)
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end

	self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "AbilityAMPsForm", wndParent, self)
	self.tWndRefs.wndMiddle = Apollo.LoadForm(self.xmlDoc, "MiddleBG", self.tWndRefs.wndMain:FindChild("ScrollContainer:LightBulbLayer"), self)
	self.tWndRefs.wndMiddle:ToFront()
	self.tWndRefs.wndMessage = self.tWndRefs.wndMain:FindChild("UpdateMessage")

	self.tWndRefs.wndMain:FindChild("UpdateMessage"):Show(false, true)
	self.tWndRefs.wndMain:FindChild("ResetFrame:ResetBtn"):AttachWindow(self.tWndRefs.wndMain:FindChild("ResetFrame:ResetConfirm"))

	self.nOrigMiddleLeft, self.nOrigMiddleTop, self.nOrigMiddleRight, self.nOrigMiddleBot = self.tWndRefs.wndMiddle:GetAnchorOffsets()
	
	self:RedrawAll()
end

function AbilityAMPs:OnPlayerCurrencyChanged()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() and self.tWndRefs.wndMain:IsVisible() then
		local bIsAlive = self.bResurrected or GameLib.GetPlayerUnit() and not GameLib.GetPlayerUnit():IsDead() 
		local nAmount = AbilityBook.GetEldanAugmentationRespecCost()
		local bCanAfford = nAmount <= GameLib.GetPlayerCurrency():GetAmount()
		local bLockedInPoints = AbilityBook.GetAvailableLockedInPower() < AbilityBook.GetTotalPower()

		local strColor = ApolloColor.new("UI_TextHoloBodyHighlight")
		if not bCanAfford then
			strColor = ApolloColor.new("xkcdReddish")
		elseif not bLockedInPoints then
			strColor = ApolloColor.new("UI_BtnTextBlueDisabled")
		end
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetLabel"):SetTextColor(strColor)
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetCost"):SetTextColor(strColor)
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetCost"):SetAmount(nAmount, true)
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetBtn"):Enable(bCanAfford and bLockedInPoints and bIsAlive)
	end
end

function AbilityAMPs:OnShowResurrectDialog()
	self:OnPlayerCurrencyChanged()
end

function AbilityAMPs:OnPlayerResurrected()
	self.bResurrected = true
	self:OnPlayerCurrencyChanged()
end

function AbilityAMPs:OnClose(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	self.timerMessageDisplay:Stop()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
	end
end

function AbilityAMPs:BuildFromEvent()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then -- Incase the event gets called with the UI not active
		self:DestroyAndBuild()
	end
end

function AbilityAMPs:DestroyAndBuild()
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		local wndContainer = self.tWndRefs.wndMain:FindChild("ScrollContainer")
		self.nVScrollPos = wndContainer:GetVScrollPos()
	end
	self:OnStartRedrawAll(self.tWndRefs.wndMain and self.tWndRefs.wndMain:GetParent() or nil)
end

-----------------------------------------------------------------------------------------------
-- Main Draw
-----------------------------------------------------------------------------------------------

function AbilityAMPs:RedrawAll() -- Do not pass in arguments, this can come from multiple sources
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	self.tUnlockedAugments = {}
	local tEldanAugmentationData = AbilityBook.GetEldanAugmentationData(AbilityBook.GetCurrentSpec())
	if not tEldanAugmentationData then
		return
	end
	
	-- Create a map of dependencies and amps for easy access
	self.tDependencyMap = {}
	self.tAmpMap = {}
	self.tCachedAmps = {}
	for idx, tAmp in pairs(tEldanAugmentationData.tAugments) do
		if tAmp.nEldanAugmentationIdRequired ~= 0 then
			self.tDependencyMap[tAmp.nEldanAugmentationIdRequired] = tAmp
		end
		
		if not self.tAmpMap[tAmp.nCategoryId] then
			self.tAmpMap[tAmp.nCategoryId] = {}
		end
		
		self.tAmpMap[tAmp.nCategoryId][tAmp.nId] = tAmp
	end
	
	-- Categories in tEldanAugmentationData are indexed by the order they were added to the table, not by id.
	self.tCategoryInfo = {}
	for idx, tCategory in pairs(tEldanAugmentationData.tCategories) do
		self.tCategoryInfo[tCategory.nId] = tCategory
	end

	local wndContainer = self.tWndRefs.wndMain:FindChild("ScrollContainer")
	local wndAmps = wndContainer:FindChild("Amps")
	wndAmps:DestroyChildren()

	-- Update Respec Cost
	self:OnPlayerCurrencyChanged()

	-- Update Max Size
	local nNumCategories = #karCategoriesInClockwiseOrder
	local nMaxSize = self.nZoomLevel * (19 * 2) -- self.nZoomLevel * (knNumRows * 2)
	local nCenterX = nMaxSize / 2
	local nCenterY = nMaxSize / 2
	wndContainer:FindChild("Amps"):SetAnchorOffsets(0, 0, nMaxSize, nMaxSize)
	wndContainer:FindChild("Triangles"):SetAnchorOffsets(0, 0, nMaxSize, nMaxSize)
	wndContainer:FindChild("LightBulbLayer"):SetAnchorOffsets(0, 0, nMaxSize, nMaxSize)
	wndContainer:RecalculateContentExtents()

	-- Category Triangles (Valid Categories is for Show All)
	local tCategoryPowers = {}
	local tValidCategories = {}

	for idx = 1, #tEldanAugmentationData.tCategories do
		local tCategory = tEldanAugmentationData.tCategories[idx]
		if self.arHighestUnlockedTier[tCategory.nId] and self.arHighestUnlockedTier[tCategory.nId] < tCategory.nHighestTierUnlocked then
			self:HelperCreateMessage(String_GetWeaselString(Apollo.GetString("AMP_TierUnlockedMessage"), tCategory.strName, tCategory.nHighestTierUnlocked), 2)
		end
		self.arHighestUnlockedTier[tCategory.nId] = tCategory.nHighestTierUnlocked

		-- Triangle
		local nTweakValueSize = 9.5
		local nColumn = karCategoriesInClockwiseOrder[tCategory.nId]

		local nLeft = math.cos(2 * math.pi * 4 / nNumCategories)
		local nRight = math.cos(2 * math.pi * 5 / nNumCategories)
		local nRankDepth = math.sin(2 * math.pi * 4 / nNumCategories)

		local nTweakValueGap = nTweakValueSize - 1.5
		local nRankRotateValue = 2 * math.pi * ((nColumn * 2) + 1) / (nNumCategories * 2)
		local nRankCenterX = nCenterX + (self.nZoomLevel * nTweakValueGap * math.cos(nRankRotateValue))
		local nRankCenterY = nCenterY + (self.nZoomLevel * nTweakValueGap * math.sin(nRankRotateValue))

		local nHeight = self.nZoomLevel * nTweakValueSize * math.abs(nRankDepth)
		local nWidth = self.nZoomLevel * nTweakValueSize * math.abs(nRight - nLeft)

		local tTriangle =
		{
			loc =
			{
				nOffsets =
				{
					nRankCenterX - nWidth,
					nRankCenterY - nHeight,
					nRankCenterX + nWidth,
					nRankCenterY + nHeight,
				},
			},
			fRotation = nColumn * 60 + 120,
			strSprite = "",
		}

		-- Triangle Sprite
		local bIsAnInBetweenCategory = tCategory.nId == 4 or tCategory.nId == 5 or tCategory.nId == 6
		if tCategory.nHighestTierUnlocked == 1 then
			tTriangle.strSprite = "spr_AMPS_Triangle_Block2"
		elseif tCategory.nHighestTierUnlocked == 2 then
			tTriangle.strSprite = "spr_AMPS_Triangle_Block1"
		elseif tCategory.nHighestTierUnlocked == 3 then
			tTriangle.strSprite = "spr_AMPS_Triangle_Block0"
		end
		wndContainer:FindChild("Triangles"):AddPixie(tTriangle)

		-- Add to table later for AMPs
		if tCategory.nHighestTierUnlocked > 1 or not bIsAnInBetweenCategory then
			tValidCategories[tCategory.nId] = true -- GOTCHA: Don't use an array as it'll auto shift
		end

		tCategoryPowers[tCategory.nId] = tCategory.fPowerInCategory

		-- Light Bulb
		local wndLightBulb = self.tWndRefs.wndMiddle:FindChild(karCategoryToConstantData[tCategory.nId].strLightBulbName)
		wndLightBulb:SetSprite(tCategory.nHighestTierUnlocked > 1 and karCategoryToConstantData[tCategory.nId].strLightBulbSprite or "")
		wndLightBulb:FindChild("LightBulbText"):SetText("")
	end

	-- Progress Sub Labels
	local wndButtons = self.tWndRefs.wndMain:FindChild("Buttons")
	local wndFloatingLabels = self.tWndRefs.wndMain:FindChild("ScrollContainer"):FindChild("LightBulbLayer")
	for idx = 1, #tEldanAugmentationData.tCategories do
		local strSubLabel = ""
		local tCategory = tEldanAugmentationData.tCategories[idx]
		local bLabelBlackBackground = tCategory.nHighestTierUnlocked == 1 -- and bIsAnInBetweenCategory

		local nProgBarMax = 0
		local nProgBarCurr = 0
		for idx2, tUnlockData in pairs(tCategory.tUnlockedCategories or {}) do
			local strReqCategoryName = karCategoryToConstantData[tUnlockData.nUnlockCategoryId].strName or Apollo.GetString("AMP_NextTier")
			local nReqCategoryPower = tCategoryPowers[tUnlockData.nUnlockCategoryId] -- GOTCHA: tCategory's fPowerInCategory won't be accurate for inbetweens

			if tCategory.nHighestTierUnlocked == 1 and nReqCategoryPower < tUnlockData.nTier2Amount then
				nProgBarCurr = nProgBarCurr + nReqCategoryPower
				nProgBarMax = nProgBarMax + tUnlockData.nTier2Amount
				strSubLabel = String_GetWeaselString(Apollo.GetString("AMP_NextTierProgress"), nReqCategoryPower, tUnlockData.nTier2Amount or "0")
			elseif tCategory.nHighestTierUnlocked == 2 and nReqCategoryPower < tUnlockData.nTier3Amount then
				nProgBarCurr = nProgBarCurr + nReqCategoryPower
				nProgBarMax = nProgBarMax + tUnlockData.nTier3Amount
				strSubLabel = String_GetWeaselString(Apollo.GetString("AMP_NextTierProgress"), nReqCategoryPower, tUnlockData.nTier3Amount or "0")
				strSubLabel = strSubLabel .. "\n" .. Apollo.GetString("AMP_TierTwoExplanation")
			end
		end

		-- TODO: Refactor this code out
		-- Parent Level
		local wndLabel = wndFloatingLabels:FindChild(karCategoryToConstantData[tCategory.nId].strLabelName)
		local bEnableRespec = tCategoryPowers[tCategory.nId] > 0
		local monRespecCost = Money.new()

		monRespecCost:SetAmount(AbilityBook.GetEldanAugmentationRespecCost(AbilityBook.CodeEnumAMPRespecType.Section, tCategory.nId))
		wndLabel:FindChild("LabelProgBar"):SetMax(nProgBarMax)
		wndLabel:FindChild("LabelProgBar"):SetProgress(nProgBarCurr)
		wndLabel:SetTooltip(strSubLabel)
		wndLabel:FindChild("CategoryRespecBtn"):Enable(bEnableRespec)
		wndLabel:FindChild("CategoryRespecBtn"):SetData(tCategory.nId)

		local strTooltip = ""
		
		if bEnableRespec then
			if monRespecCost:GetAmount() > 0 then
				strTooltip = String_GetWeaselString(Apollo.GetString("AMP_ResetCategoryTooltip"), monRespecCost:GetMoneyString())
			else
				strTooltip = Apollo.GetString("Amps_ResetCategoryFree")
			end
		end
		
		wndLabel:FindChild("CategoryRespecBtn"):SetTooltip(strTooltip)

		local wndButtonLabel = self.tWndRefs.wndMain:FindChild("Buttons"):FindChild(karCategoryToConstantData[tCategory.nId].strButtonLabel)
		wndButtonLabel:FindChild("ButtonProgBar"):SetMax(nProgBarMax)
		wndButtonLabel:FindChild("ButtonProgBar"):SetProgress(nProgBarCurr)
		wndButtonLabel:SetTooltip(strSubLabel)
	end

	-- Amps
	local nColumns = knColumnsPerCategory * nNumCategories
	for idx = 1, #tEldanAugmentationData.tAugments do
		local tAmp = tEldanAugmentationData.tAugments[idx]

		if tAmp.eEldanAvailability == AbilityBook.CodeEnumEldanAvailability.Activated then
			if tAmp.bIsCached then
				self.tCachedAmps[tAmp.nId] = tAmp
			end
			
			self.tUnlockedAugments[tAmp.nId] = tAmp.nId
		end

		local wndAmpForm = Apollo.LoadForm(self.xmlDoc, "AmpForm", wndAmps, self)
		wndAmpForm:FindChild("AmpFormButton"):SetData(tAmp)
		wndAmpForm:SetData(tAmp)

		local nHalfWidth = wndAmpForm:GetWidth() / 2
		local nHalfHeight = wndAmpForm:GetHeight() / 2
		if self.nZoomLevel < 20 then
			nHalfWidth = nHalfWidth - 4
			nHalfHeight = nHalfHeight - 4
		elseif self.nZoomLevel < 34 then
			nHalfWidth = nHalfWidth
			nHalfHeight = nHalfHeight
		else
			nHalfWidth = nHalfWidth + 4
			nHalfHeight = nHalfHeight + 4
		end

		local nFudgedDisplayRow = tAmp.nDisplayRow + 4
		local nLineAngle = (tAmp.nDisplayColumn + (karCategoriesInClockwiseOrder[tAmp.nCategoryId] * knColumnsPerCategory)) / nColumns
		local x = nCenterX + (self.nZoomLevel * nFudgedDisplayRow) * math.cos(2 * math.pi * nLineAngle)
		local y = nCenterY + (self.nZoomLevel * nFudgedDisplayRow) * math.sin(2 * math.pi * nLineAngle)
		wndAmpForm:SetAnchorOffsets(x - nHalfWidth, y - nHalfHeight, x + nHalfWidth, y + nHalfHeight)
	end

	-- Connections (TODO REFACTOR)
	for idx, wndAmpForm in pairs(wndAmps:GetChildren()) do
		local tAmp = wndAmpForm:GetData()
		local nEldanAugmentIdRequired = tAmp.nEldanAugmentationIdRequired
		if nEldanAugmentIdRequired and nEldanAugmentIdRequired ~= 0 then

			for idx2, wndPrerequisiteAugment in pairs(wndAmps:GetChildren()) do
				local tPrerequisiteAugment = wndPrerequisiteAugment:GetData()
				if tPrerequisiteAugment.nId == nEldanAugmentIdRequired then
					local nX, nY = wndAmpForm:GetPos()
					local nHalfWidth = wndAmpForm:GetWidth() / 2
					local nHalfHeight = wndAmpForm:GetHeight() / 2
					local nPrerequisiteX, nPrerequisiteY = wndPrerequisiteAugment:GetPos()

					local tAmpRow =
					{
						loc =
						{
							nOffsets =
							{
								nPrerequisiteX + nHalfWidth,
								nPrerequisiteY + nHalfHeight,
								nX + nHalfWidth,
								nY + nHalfHeight,
							},
						},
						bLine = true,
						fWidth = 2,
						cr = ApolloColor.new("9dffffff"),
					}

					wndContainer:FindChild("Amps"):AddPixie(tAmpRow)
				end
			end
		end
	end

	-- Middle Center Piece
	local nMidZoom = self.nZoomLevel / 24
	self.tWndRefs.wndMiddle:SetAnchorOffsets(self.nOrigMiddleLeft * nMidZoom, self.nOrigMiddleTop * nMidZoom, self.nOrigMiddleRight * nMidZoom, self.nOrigMiddleBot * nMidZoom)

	-- Restore scroll pos
	wndContainer:SetVScrollPos(self.nVScrollPos)

	self:RedrawSelections(tEldanAugmentationData)
end

function AbilityAMPs:RedrawSelections(tEldanAugmentationData)
	-- AMP icon states
	for idx, wndAmp in pairs(self.tWndRefs.wndMain:FindChild("ScrollContainer:Amps"):GetChildren()) do
		local tAmp = wndAmp:GetData()
		local eEnum = tAmp.eEldanAvailability
		local strSprite = ""

		if self.tCachedAmps[tAmp.nId] then
			strSprite = "kitBtn_Dropdown_HoloPressedFlyby"	
		elseif eEnum == AbilityBook.CodeEnumEldanAvailability.Unavailable then -- 0
			strSprite = knAugmentationUnavailableColor -- (tAmp.nItemIdUnlock and tAmp.nItemIdUnlock ~= 0) and knAugmentationInlaidLockColor
		elseif eEnum == AbilityBook.CodeEnumEldanAvailability.Inaccessible then -- 1
			strSprite = knAugmentationInaccessibleColor
		elseif eEnum == AbilityBook.CodeEnumEldanAvailability.Activated then -- 2
			strSprite = knAugmentationActivatedColor
		else -- Inactivated, some sort of blue		
			if self.tUnlockedAugments[tAmp.nId] then
				strSprite = knAugmentationActivatedColor
			elseif not tAmp.nEldanAugmentationIdRequired or tAmp.nEldanAugmentationIdRequired == 0 or self.tUnlockedAugments[tAmp.nEldanAugmentationIdRequired] then
				strSprite = knAugmentationInactivatedColor
			else
				strSprite = knAugmentationAlmostThereColor
			end
		end

		-- Match Button to sprite (TODO REFACTOR)
		if strSprite == knAugmentationActivatedColor then
			wndAmp:FindChild("AmpFormButton"):ChangeArt("btn_AMPS_HoverOnlyRedCircle")
		elseif strSprite == knAugmentationInactivatedColor then
			wndAmp:FindChild("AmpFormButton"):ChangeArt("btn_AMPS_HoverOnlyBlueCircle")
		else
			wndAmp:FindChild("AmpFormButton"):ChangeArt("")
		end
		wndAmp:SetSprite(strSprite)
	end

	-- Middle Text

	local nTotalPower = AbilityBook.GetTotalPower()
	local nAvailablePower = AbilityBook.GetAvailablePower()
	local wndMiddleBG = self.tWndRefs.wndMain:FindChild("ScrollContainer:LightBulbLayer:MiddleBG")
	local wndAvailablePoints = wndMiddleBG:FindChild("PointsAvailable")
	local wndMaxPoints = wndMiddleBG:FindChild("PointsMaxText")
	local wndProgress = wndMiddleBG:FindChild("PointsProgBar")

	wndAvailablePoints:SetFont(self.nZoomLevel == knLowestZoom and "CRB_HeaderHuge" or "CRB_HeaderGigantic")
	wndAvailablePoints:SetText(nAvailablePower > 0 and nAvailablePower or "")
	wndMaxPoints:SetFont(self.nZoomLevel == knLowestZoom and "CRB_InterfaceSmall" or "CRB_InterfaceMedium_B")
	wndMaxPoints:SetText(nAvailablePower > 0 and "/"..nTotalPower or "") -- String_GetWeaselString(Apollo.GetString("AMP_AvailablePoints"), nAvailablePower)
	wndMiddleBG:FindChild("PointsReady"):Show(nAvailablePower == 0)
	wndProgress:SetMax(nTotalPower)
	wndProgress:SetProgress(nAvailablePower)
end

function AbilityAMPs:OnLabelShortcutBtn(wndHandler, wndControl)
	local strButtonName = wndHandler:GetName()
	if strButtonName == "ZoomToEverything" then
		self.nZoomLevel = knLowestZoom
	else
		self.nZoomLevel = knDefaultZoom
	end

	self:DestroyAndBuild()

	local nVScrollPos = 0
	if strButtonName == "ZoomToMiddle" then
		nVScrollPos = 170
	elseif strButtonName == "ZoomToEverything" then
		nVScrollPos = 170
	elseif strButtonName == "UtilityLabel" or strButtonName == "AssaultUtilityLabel" or strButtonName == "UtilitySupportLabel" then
		nVScrollPos = 999
	end

	-- TODO: Refactor/delete the other scroll position code
	local wndContainer = self.tWndRefs.wndMain:FindChild("ScrollContainer")
	wndContainer:SetVScrollPos(nVScrollPos)
end

-----------------------------------------------------------------------------------------------
-- Reset AMPs
-----------------------------------------------------------------------------------------------

function AbilityAMPs:OnResetConfirmYesBtn(wndHandler, wndControl)
	AbilityBook.RespecEldanAugmentations()
	self:DestroyAndBuild()
end

function AbilityAMPs:OnResetConfirmWindowClosed(wndHandler, wndControl)
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() and wndHandler == wndControl then
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetConfirm"):Show(false)
	end
end

function AbilityAMPs:OnAugmentationTooltip(wndHandler, wndControl, eToolTipType, x, y)
	local tAugment = wndHandler:GetData()
	if not tAugment then
		return
	end

	if self.wndTooltip and self.wndTooltip:IsValid() then
		self.wndTooltip:Destroy()
		self.wndTooltip = nil
	end

		local bAmpPurchased = tAugment.eEldanAvailability == AbilityBook.CodeEnumEldanAvailability.Activated

	local strCategory = karCategoryToConstantData[tAugment.nCategoryId].strName or ""
	self.wndTooltip = wndHandler:LoadTooltipForm("AbilityAMPs.xml", "TooltipForm", self)
	self.wndTooltip:FindChild("NameLabelWindow"):SetText(tAugment.strTitle or "")
	
	local wndPowerCostLabel = self.wndTooltip:FindChild("PowerCostLabelWindow")
	local wndTierLabel = self.wndTooltip:FindChild("TierLabelWindow")
	local wndDescription = self.wndTooltip:FindChild("DescriptionLabelWindow")
	wndPowerCostLabel:SetText(String_GetWeaselString(Apollo.GetString("AMP_PowerCost"), tAugment.nPowerCost or ""))
	wndTierLabel:SetText(String_GetWeaselString(Apollo.GetString("AMP_TierLabel"), strCategory, tAugment.nCategoryTier or ""))
	wndDescription:SetAML("<P TextColor=\"UI_TextHoloBody\" Font=\"CRB_InterfaceSmall\">" .. tAugment.strDescription .. "</P>")
	

	local nTextWidth, nTextHeight = wndDescription:SetHeightToContentHeight()
	
	if bAmpPurchased then
		local wndRespecLabel = self.wndTooltip:FindChild("RespecLabel")
		local wndCashWindow = self.wndTooltip:FindChild("RespecCost")
		
		wndRespecLabel:Show(true)
		wndCashWindow:Show(true)
		wndCashWindow:SetAmount(AbilityBook.GetEldanAugmentationRespecCost(AbilityBook.CodeEnumAMPRespecType.Single, tAugment.nId), true)
		
		local nRespecHeight = wndRespecLabel:GetHeight()
		
		nTextHeight = nTextHeight + nRespecHeight
		local nLeft, nTop, nRight, nBottom = wndTierLabel:GetAnchorOffsets()
		wndTierLabel:SetAnchorOffsets(nLeft, nTop - nRespecHeight, nRight, nBottom - nRespecHeight)
		
		local nPowerLeft, nPowerTop, nPowerRight, nPowerBottom = wndPowerCostLabel:GetAnchorOffsets()
		wndPowerCostLabel:SetAnchorOffsets(nPowerLeft, nPowerTop - nRespecHeight, nPowerRight, nPowerBottom - nRespecHeight)
	end
	
	local nTooltipLeft, nTooltipTop, nTooltipRight, nTooltipBottom = unpack(self.wndTooltip:GetOriginalLocation():ToTable().nOffsets)
	self.wndTooltip:SetAnchorOffsets(nTooltipLeft, nTooltipTop, nTooltipRight, nTooltipBottom + nTextHeight)
end

function AbilityAMPs:OnAmpFormBtn(wndHandler, wndControl, eMouseBtn) -- AmpFormButton
	local tAugment = wndHandler:GetData()
	
	if self.tUnlockedAugments[tAugment.nId] or self.tCachedAmps[tAugment.nId] then
		local tDependencies = {}
		local idCategory = tAugment.nCategoryId
		local nDependencyCount = 0
		
		local idCurrentAmp = tAugment.nId
		local bInactive = false
		while self.tDependencyMap[idCurrentAmp] and not bInactive do
			local tDependency = self.tDependencyMap[idCurrentAmp]
			if tDependency.eEldanAvailability == AbilityBook.CodeEnumEldanAvailability.Activated then
				idCurrentAmp = tDependency.nId
				tDependencies[tDependency.nId] = tDependency
				nDependencyCount = nDependencyCount + 1
			else
				bInactive = true
			end
		end
		
		local nPowerUsed = {0, 0, 0}
		local nPowerRequired = {0, 0, 0}
		
		if self.tCategoryInfo[idCategory].nHighestTierUnlocked > tAugment.nCategoryTier then
			-- Determine if this is a valid amp to remove
			if self.tCategoryInfo[idCategory].nHighestTierUnlocked > 1 then
				for idAmp, tAmpData in pairs(self.tAmpMap[idCategory]) do
					if tAmpData.eEldanAvailability == AbilityBook.CodeEnumEldanAvailability.Activated and tAmpData.nId ~= tAugment.nId and not tDependencies[tAmpData.nId] then
						nPowerUsed[tAmpData.nCategoryTier] = nPowerUsed[tAmpData.nCategoryTier] + tAmpData.nPowerCost
					end
				end
				
				nPowerRequired[2] = self.tCategoryInfo[idCategory].tUnlockedCategories[1].nTier2Amount
				nPowerRequired[3] = self.tCategoryInfo[idCategory].tUnlockedCategories[1].nTier3Amount
			end	
		end
		
		-- Tier 1 will never block a reset.  T2 doesn't block a reset if there is no T2 amp set or the remaining power is still enough to leave T2 unlocked.  T3 has the same requirements as T2, and T2 can't block the reset.
		local tValidTierReset = {true, false, false}
		tValidTierReset[2] = nPowerUsed[1] >= nPowerRequired[2] or nPowerUsed[2] == 0
		tValidTierReset[3] = tValidTierReset[2] and (nPowerUsed[1] + nPowerUsed[2] >= nPowerRequired[3] or nPowerUsed[3] == 0)
		
		local wndResetConfirmation = self.tWndRefs.wndMain:FindChild("ResetConfirmation")
		local wndConfirmationFrame = wndResetConfirmation:FindChild("ConfirmationFrame")
		local wndResetConfirm = wndConfirmationFrame:FindChild("ResetConfirm")
		
		-- Resetting an amp in the top category is always valid. Otherwise, use tValidTierReset to determine if the highest tier unlocked will block the reset or not.
		local bValidRespec = self.tCategoryInfo[idCategory].nHighestTierUnlocked == tAugment.nCategoryTier or (self.tCategoryInfo[idCategory].nHighestTierUnlocked == 2 and tValidTierReset[2]) or 
							(self.tCategoryInfo[idCategory].nHighestTierUnlocked == 3 and tValidTierReset[3])

		if bValidRespec then
			local nRespecCost = AbilityBook.GetEldanAugmentationRespecCost(AbilityBook.CodeEnumAMPRespecType.Single, tAugment.nId)
			if nRespecCost > 0 then
				-- Show the respec dialog
				local strRespecList = Apollo.GetString("AMP_ResetSingle") .. "\n" .. tAugment.strTitle
				
				local nResize = 10 * nDependencyCount
				
				if nDependencyCount > 0 then
					strRespecList = strRespecList .. "\n\n" .. Apollo.GetString("AMP_ResetDependency")
					for idAmp, tAmp in pairs(tDependencies) do
						strRespecList = strRespecList .. "\n" .. tAmp.strTitle
					end
				end
				
				local nResetLeft, nResetTop, nResetRight, nResetBottom = unpack(wndConfirmationFrame:GetOriginalLocation():ToTable().nOffsets)
				wndConfirmationFrame:SetAnchorOffsets(nResetLeft, nResetTop, nResetRight, nResetBottom + nResize)
				
				wndResetConfirm:FindChild("CashWindow"):SetAmount(nRespecCost, true)
				wndResetConfirm:SetData({eType = AbilityBook.CodeEnumAMPRespecType.Single, nId = tAugment.nId})
				wndResetConfirm:Enable(nRespecCost <= GameLib.GetPlayerCurrency():GetAmount())
				wndResetConfirmation:FindChild("BodyText"):SetText(strRespecList)
				
				wndResetConfirm:FindChild("CashWindow"):Show(true)
				wndResetConfirm:SetText(Apollo.GetString("Amps_ConfirmReset"))
				wndResetConfirm:FindChild("DisabledResetLabel"):Show(false)
				wndResetConfirmation:Show(true)
			else
				AbilityBook.RespecEldanAugmentations(AbilityBook.CodeEnumAMPRespecType.Single, tAugment.nId)
			end
		else
			-- Show the error dialog
			-- Disable the Reset button
			wndResetConfirm:Enable(false)
			
			-- Use the required amount and post-reset amount
			local nFailedTier = tValidTierReset[2] == false and 2 or 3
			local strErrorMessage = String_GetWeaselString(Apollo.GetString("AMP_ResetInvalid"), self.tCategoryInfo[idCategory].strName, nFailedTier, nPowerRequired[nFailedTier])
			wndConfirmationFrame:FindChild("BodyText"):SetText(strErrorMessage)
			
			wndResetConfirm:FindChild("CashWindow"):Show(false)
			wndResetConfirm:SetText("")
			wndResetConfirm:FindChild("DisabledResetLabel"):Show(true)
			wndResetConfirmation:Show(true)
		end
	else
		self.tUnlockedAugments[tAugment.nId] = tAugment.nId
		self.tCachedAmps[tAugment.nId] = tAugment

		local nUnlockedAugments = 0
		for tAugmentId in pairs(self.tUnlockedAugments) do
			nUnlockedAugments = nUnlockedAugments + 1
		end

		local eResult = AbilityBook.UpdateEldanAugmentationSpec(tAugment.nId)
		if eResult ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
			local strMessage = ""
			local nDuration = 4.5
			if eResult == ActionSetLib.CodeEnumLimitedActionSetResult.NotEnoughPower then
				strMessage = AbilityBook.GetAvailablePower() == 0 and Apollo.GetString("EldanAugmentation_AtMaxPower") or Apollo.GetString("EldanAugmentation_NotEnoughPower")
			elseif ktAugmentationValidationResult[eResult] then
				strMessage = ktAugmentationValidationResult[eResult]
			elseif GameLib.GetPlayerUnit():IsInCombat() then
				strMessage = Apollo.GetString("AbilityBuilder_BuildsCantBeChangedCombat")
				nDuration = 2
			else
				strMessage = String_GetWeaselString(Apollo.GetString("EldanAugmentation_SaveFailed"), eResult)
				nDuration = 2
			end

			self:HelperCreateMessage(strMessage, nDuration)
			self.tUnlockedAugments[tAugment.nId] = nil
			self.tCachedAmps[tAugment.nId] = nil
		end
	end
	
	self:HelperCheckCached()
end

function AbilityAMPs:OnResetCategoryBtn(wndHandler, wndControl)
	local idCategory = wndHandler:GetData()
	local monRespecCost = AbilityBook.GetEldanAugmentationRespecCost(AbilityBook.CodeEnumAMPRespecType.Section, idCategory)
	
	if monRespecCost <= 0 then
		AbilityBook.RespecEldanAugmentations(AbilityBook.CodeEnumAMPRespecType.Section, idCategory)
		self:HelperCheckCached()
		return
	end

	local wndResetConfirmation = self.tWndRefs.wndMain:FindChild("ResetConfirmation")
	local wndConfirmationFrame = wndResetConfirmation:FindChild("ConfirmationFrame")
	local wndResetConfirm = wndConfirmationFrame:FindChild("ResetConfirm")
	
	wndConfirmationFrame:FindChild("BodyText"):SetText(String_GetWeaselString(Apollo.GetString("AMP_ResetCategory"), karCategoryToConstantData[idCategory].strName))
	wndResetConfirm:FindChild("CashWindow"):SetAmount(monRespecCost)
	
	wndResetConfirm:SetData({eType = AbilityBook.CodeEnumAMPRespecType.Section, nId = idCategory})
	if GameLib.GetPlayerCurrency():GetAmount() >= monRespecCost then		
		wndResetConfirm:Enable(true)
		wndResetConfirm:FindChild("DisabledResetLabel"):Show(false)
		wndResetConfirm:SetText(Apollo.GetString("Amps_ConfirmReset"))
	else
		wndResetConfirm:Enable(false)
	end
	wndResetConfirmation:Show(true)
end

function AbilityAMPs:OnResetConfirm(wndHandler, wndControl)
	local tResetInfo = wndHandler:GetData()
	AbilityBook.RespecEldanAugmentations(tResetInfo.eType, tResetInfo.nId)
	AbilityBook.ClearCachedEldanAugmentationSpec()
	self.tWndRefs.wndMain:FindChild("ResetConfirmation"):Show(false)
	self:DestroyAndBuild()
end

function AbilityAMPs:OnResetCancel(wndHandler, wndControl)
	self.tWndRefs.wndMain:FindChild("ResetConfirmation"):Show(false)
end

function AbilityAMPs:HelperCreateMessage(strMessage, nDuration)
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() and self.tWndRefs.wndMain:IsShown() and strMessage ~= "" then
		self.tWndRefs.wndMessage:FindChild("MessageTextBG:MessageText"):SetText(strMessage)
		self.tWndRefs.wndMessage:Show(true)
		self.timerMessageDisplay:Stop()
		self.timerMessageDisplay:Set(nDuration, false)
		self.timerMessageDisplay:Start()
	end
end

function AbilityAMPs:OnMessageDisplayTimer()
	self.timerMessageDisplay:Stop()
	if self.tWndRefs.wndMessage and self.tWndRefs.wndMessage:IsValid() then
		self.tWndRefs.wndMessage:Show(false)
	end
end

function AbilityAMPs:OnUpdateMessageMouseClick(wndHandler, wndControl)
	self:OnMessageDisplayTimer()
end

function AbilityAMPs:OnConfigureAMPs()
	Event_FireGenericEvent("CharacterUnlockedInlaidEldanAugmentation")
	self.tWndRefs.wndDialogReset:Destroy()
end

function AbilityAMPs:OnResetAMPsClose()
	self.tWndRefs.wndDialogReset:Destroy()
end	

function AbilityAMPs:HelperCheckCached()
	local nCachedAmpCount = 0
	for idAmp, tAmp in pairs(self.tCachedAmps) do
		nCachedAmpCount = nCachedAmpCount + 1
	end
	
	Event_FireGenericEvent("AbilityAMPs_ToggleDirtyBit", nCachedAmpCount > 0) -- Tell parent add-on that close should have a warning now
end

local AbilityAMPsInst = AbilityAMPs:new()
AbilityAMPsInst:Init()
