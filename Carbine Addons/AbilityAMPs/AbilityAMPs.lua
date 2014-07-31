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
	[knCategoryUtilityId] 			= {"LightBulbS",	"spr_AMPS_MiddleGlow_S", 	Apollo.GetString("AMP_Utility"),	"LabelUtility",		},
	[knCategorySupportId]			= {"LightBulbNE",	"spr_AMPS_MiddleGlow_NE",	Apollo.GetString("AMP_Support"), 	"LabelSupport",		},
	[knCategoryDamageId] 			= {"LightBulbNW",	"spr_AMPS_MiddleGlow_NW", 	Apollo.GetString("AMP_Assault"),	"LabelAssault",		},
	[knCategoryDamageSupportId] 	= {"LightBulbN",	"spr_AMPS_MiddleGlow_N", 	Apollo.GetString("AMP_Hybrid"),		"LabelHybrid",		},
	[knCategoryDamageUtilitytId] 	= {"LightBulbSE",	"spr_AMPS_MiddleGlow_SW", 	Apollo.GetString("AMP_PvPOffense"),	"LabelPvPOffense",	},
	[knCategorySupportUtilityId] 	= {"LightBulbSW",	"spr_AMPS_MiddleGlow_SE", 	Apollo.GetString("AMP_PvPDefense"),	"LabelPvPDefense",	},
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

local knDefaultZoom						= 21.47
local knLowestZoom						= 21.47
local knColumnsPerCategory 				= 8 				-- How many columns exist for each category (columns)
local knNumRows 						= 12 				-- Number of rows in the radial grid

local knAugmentationActivatedColor 		= "btn_AMPS_CirclePressed"		-- On
local knAugmentationInactivatedColor 	= "btn_AMPS_CircleNormal"		-- Can Click
local knAugmentationAlmostThereColor 	= "spr_AMPs_LockStretch_Blue"	-- 1 Away from Can Click
local knAugmentationInaccessibleColor 	= "spr_AMPs_LockStretch_Grey"
local knAugmentationUnavailableColor 	= "spr_AMPs_LockStretch_Red"

local ktAugmentationValidationResult =
{
	[ActionSetLib.CodeEnumLimitedActionSetResult.Ok]										= Apollo.GetString("EldanAugmentation_Ok"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_LockedInlaid]			= Apollo.GetString("EldanAugmentation_LockedInlaidAugmentation"),
	[ActionSetLib.CodeEnumLimitedActionSetResult.EldanAugmentation_LockedCategoryTier]	= Apollo.GetString("EldanAugmentation_LockedCategoryTier"), -- TODO rename to rank
	[ActionSetLib.CodeEnumLimitedActionSetResult.UnknownClassId]							= Apollo.GetString("EldanAugmentation_InvalidClass"),
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
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 					"OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AMPPoint",					"OnLevelUpUnlock_AMPPoint", self)
	Apollo.RegisterTimerHandler("AbilityAMPs_MessageDisplayTimer", 			"OnMessageDisplayTimer", self)

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
		local nAmount = AbilityBook.GetEldanAugmentationRespecCost()
		local bCanAfford = nAmount < GameLib.GetPlayerCurrency():GetAmount()
		local bLockedInPoints = AbilityBook.GetAvailableLockedInPower() < AbilityBook.GetTotalPower()

		local strColor = ApolloColor.new("UI_TextHoloBodyHighlight")
		if not bCanAfford then
			strColor = ApolloColor.new("UI_WindowTextRed")
		elseif not bLockedInPoints then
			strColor = ApolloColor.new("UI_BtnTextBlueDisabled")
		end
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetLabel"):SetTextColor(strColor)
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetCost"):SetTextColor(strColor)
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetCost"):SetAmount(nAmount, true)
		self.tWndRefs.wndMain:FindChild("ResetFrame:ResetBtn"):Enable(bCanAfford and bLockedInPoints)
	end
end

function AbilityAMPs:OnClose(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	Apollo.StopTimer("AbilityAMPs_MessageDisplayTimer")
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

	self.arUnlockedAugments = {}
	local tEldanAugmentationData = AbilityBook.GetEldanAugmentationData(AbilityBook.GetCurrentSpec())
	if not tEldanAugmentationData then
		return
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
		--elseif tCategory.nHighestTierUnlocked == 1 then
			--tTriangle.strSprite = "spr_AMPS_Triangle_Block2"
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

		-- GOTCHA: This needs to be outside the loop since tEldanAugmentationData.tCategories[tUnlockData.nUnlockCategoryId].fPowerInCategory is no go
		tCategoryPowers[tCategory.nId] = tCategory.fPowerInCategory

		-- Light Bulb
		local wndLightBulb = self.tWndRefs.wndMiddle:FindChild(karCategoryToConstantData[tCategory.nId][1])
		wndLightBulb:SetSprite(tCategory.nHighestTierUnlocked > 1 and karCategoryToConstantData[tCategory.nId][2] or "")
		wndLightBulb:FindChild("LightBulbText"):SetText("")
		--wndLightBulb:FindChild("LightBulbText"):SetText(nCurrPower == 0 and "" or nCurrPower) -- TODO RESTORE OR DELETE
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
			local strReqCategoryName = karCategoryToConstantData[tUnlockData.nUnlockCategoryId][3] or Apollo.GetString("AMP_NextTier")
			local nReqCategoryPower = tCategoryPowers[tUnlockData.nUnlockCategoryId] -- GOTCHA: tCategory's fPowerInCategory won't be accurate for inbetweens

			if tCategory.nHighestTierUnlocked == 1 and nReqCategoryPower < tUnlockData.nTier2Amount then
				nProgBarCurr = nProgBarCurr + nReqCategoryPower
				nProgBarMax = nProgBarMax + tUnlockData.nTier2Amount
				strSubLabel = String_GetWeaselString(Apollo.GetString("AMP_NextTierProgress"), nReqCategoryPower, tUnlockData.nTier2Amount or "0")
			elseif tCategory.nHighestTierUnlocked == 2 and nReqCategoryPower < tUnlockData.nTier3Amount then
				nProgBarCurr = nProgBarCurr + nReqCategoryPower
				nProgBarMax = nProgBarMax + tUnlockData.nTier3Amount
				strSubLabel = String_GetWeaselString(Apollo.GetString("AMP_NextTierProgress"), nReqCategoryPower, tUnlockData.nTier3Amount or "0")
			end
		end

		-- TODO: Refactor this code out
		-- Parent Level
		local wndLabel = wndFloatingLabels:FindChild(karCategoryToConstantData[tCategory.nId][4])
		wndLabel:FindChild("LabelProgBar"):SetMax(nProgBarMax)
		wndLabel:FindChild("LabelProgBar"):SetProgress(nProgBarCurr)
		wndLabel:SetTooltip(strSubLabel)
	end

	-- Amps
	local nColumns = knColumnsPerCategory * nNumCategories
	for idx = 1, #tEldanAugmentationData.tAugments do
		local tAmp = tEldanAugmentationData.tAugments[idx]
		if tAmp.eEldanAvailability == AbilityBook.CodeEnumEldanAvailability.Activated then
			self.arUnlockedAugments[tAmp.nId] = tAmp.nId
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

		if eEnum == AbilityBook.CodeEnumEldanAvailability.Unavailable then -- 0
			strSprite = knAugmentationUnavailableColor -- (tAmp.nItemIdUnlock and tAmp.nItemIdUnlock ~= 0) and knAugmentationInlaidLockColor

		elseif eEnum == AbilityBook.CodeEnumEldanAvailability.Inaccessible then -- 1
			strSprite = knAugmentationInaccessibleColor

		elseif eEnum == AbilityBook.CodeEnumEldanAvailability.Activated then -- 2
			strSprite = knAugmentationActivatedColor

		else -- Inactivated, some sort of blue
			if self.arUnlockedAugments[tAmp.nId] then
				strSprite = knAugmentationActivatedColor
			elseif not tAmp.nEldanAugmentationIdRequired or tAmp.nEldanAugmentationIdRequired == 0 or self.arUnlockedAugments[tAmp.nEldanAugmentationIdRequired] then
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
		
		-- Hide if 0
		--if nAvailablePower == 0 then		
		--	wndAmp:SetBGColor(ApolloColor.new("66ffffff"))
		--end	
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
	local wndParent = wndControl:GetParent()
	local tAugment = wndParent:GetData()

	if not tAugment or not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	if not self.wndTooltip or not self.wndTooltip:IsValid() then
		self.wndTooltip = Apollo.LoadForm(self.xmlDoc, "TooltipForm", self.tWndRefs.wndMain, self)
	end

	local strCategory = karCategoryToConstantData[tAugment.nCategoryId][3] or ""
	self.wndTooltip:FindChild("NameLabelWindow"):SetText(tAugment.strTitle or "")
	self.wndTooltip:FindChild("PowerCostLabelWindow"):SetText(String_GetWeaselString(Apollo.GetString("AMP_PowerCost"), tAugment.nPowerCost or ""))
	self.wndTooltip:FindChild("TierLabelWindow"):SetText(String_GetWeaselString(Apollo.GetString("AMP_TierLabel"), strCategory, tAugment.nCategoryTier or ""))
	self.wndTooltip:FindChild("DescriptionLabelWindow"):SetAML("<P TextColor=\"UI_TextHoloBody\" Font=\"CRB_InterfaceSmall\">"..tAugment.strDescription.."</P>")

	local nTextWidth, nTextHeight = self.wndTooltip:FindChild("DescriptionLabelWindow"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = self.wndTooltip:GetAnchorOffsets()
	self.wndTooltip:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nTextHeight + 68)
end

function AbilityAMPs:OnAugmentationTooltipEnd(wndHandler, wndControl, x, y)
	if self.wndTooltip then
		self.wndTooltip:Destroy()
		self.wndTooltip = nil
	end
end

function AbilityAMPs:OnAmpFormBtn(wndHandler, wndControl) -- AmpFormButton
	local tAugment = wndHandler:GetData()
	if self.arUnlockedAugments[tAugment.nId] then
		return
	end

	self.arUnlockedAugments[tAugment.nId] = tAugment.nId

	local nUnlockedAugments = 0
	for tAugmentId in pairs(self.arUnlockedAugments) do
		nUnlockedAugments = nUnlockedAugments + 1
	end

	local eResult = AbilityBook.ValidateEldanAugmentationSpec(AbilityBook.GetCurrentSpec(), nUnlockedAugments, self.arUnlockedAugments)
	if eResult ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
		local strMessage = ""
		if eResult == ActionSetLib.CodeEnumLimitedActionSetResult.NotEnoughPower then
			strMessage = AbilityBook.GetAvailablePower() == 0 and Apollo.GetString("EldanAugmentation_AtMaxPower") or Apollo.GetString("EldanAugmentation_NotEnoughPower")
		elseif ktAugmentationValidationResult[eResult] then
			strMessage = ktAugmentationValidationResult[eResult]
		end

		self:HelperCreateMessage(strMessage, 2)
		self.arUnlockedAugments[tAugment.nId] = nil
	else
		local bTryToSave = AbilityBook.UpdateEldanAugmentationSpec(AbilityBook.GetCurrentSpec(), nUnlockedAugments, self.arUnlockedAugments)
		if not bTryToSave then -- Show message if it didn't work
			if GameLib.GetPlayerUnit():IsInCombat() then
				self:HelperCreateMessage(Apollo.GetString("AbilityBuilder_BuildsCantBeChangedCombat"), 2)
			else
				self:HelperCreateMessage(String_GetWeaselString(Apollo.GetString("EldanAugmentation_SaveFailed"), nResult), 2)
			end
		end

		--self:DestroyAndBuild() -- Event should be called that'll do this
		Event_FireGenericEvent("AbilityAMPs_ToggleDirtyBit", true) -- Tell parent add-on that close should have a warning now
	end
end

function AbilityAMPs:HelperCreateMessage(strMessage, nDuration)
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() and self.tWndRefs.wndMain:IsShown() and strMessage ~= "" then
		self.tWndRefs.wndMessage:FindChild("MessageTextBG:MessageText"):SetText(strMessage)
		self.tWndRefs.wndMessage:Show(true)
		Apollo.StopTimer("AbilityAMPs_MessageDisplayTimer")
		Apollo.CreateTimer("AbilityAMPs_MessageDisplayTimer", nDuration, false)
	end
end

function AbilityAMPs:OnMessageDisplayTimer()
	Apollo.StopTimer("AbilityAMPs_MessageDisplayTimer")
	if self.tWndRefs.wndMessage and self.tWndRefs.wndMessage:IsValid() then
		self.tWndRefs.wndMessage:Show(false)
	end
end

function AbilityAMPs:OnUpdateMessageMouseClick(wndHandler, wndControl)
	self:OnMessageDisplayTimer()
end

function AbilityAMPs:OnLevelUpUnlock_AMPPoint()
	-- TODO
end

local AbilityAMPsInst = AbilityAMPs:new()
AbilityAMPsInst:Init()
