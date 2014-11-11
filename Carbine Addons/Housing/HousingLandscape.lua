-----------------------------------------------------------------------------------------------
-- Client Lua Script for HousingLandscape
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "HousingLib"
require "GuildLib"
 
-----------------------------------------------------------------------------------------------
-- HousingLandscape Module Definition
-----------------------------------------------------------------------------------------------
local HousingLandscape 			= {}
local LandscapeCurrentControl 	= {}
local LandscapeProposedControl 	= {}
local PlotGrid 					= {}
local GridCell 					= {}
local PlotDetail 				= {}

---------------------------------------------------------------------------------------------------
-- global
---------------------------------------------------------------------------------------------------
local gidZone = 0
local knStarterTentPlugItemId = 18
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local LuaEnumPlotType = 
{
	HousingPlot1x1 		= 1,
	HousingPlot1x2 		= 2,
	HousingPlot2x1 		= 3,
	HousingPlot2x2 		= 42,
	Warplot1x3Travel 	= 47,
	Warplot1x3Vehicle 	= 48,
	Warplot4x3Large 	= 49,
	Warplot3x2Small 	= 50,
	Warplot2x3Super 	= 51,
	Warplot2x3Raid 		= 53
}	

local knTotalHousingPlots 	= 7
local knTotalWarplots 		= 9
local knDefaultEntryHieght 	= 30
local knExpandedEntryHieght = 160

local kcrEnabledColor 	= ApolloColor.new("UI_TextHoloTitle")
local kcrDisabledColor 	= ApolloColor.new("xkcdReddish")
local kcrPrunedColor 	= CColor.new(0.3,0.3,0.3,1.0)

---------------------------------------------------------------------------------------------------
-- LandscapeCurrentControl data/methods
---------------------------------------------------------------------------------------------------
function LandscapeCurrentControl:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.luaPlotGrid = PlotGrid:new()
	o.luaPlotDetail = PlotDetail:new()
	o.ePlotSelectionType = 0
	o.strPlotBGArt = nil

	return o
end

function LandscapeCurrentControl:OnLoad(wndParent)
	self.luaPlotGrid:OnLoad(wndParent)
	self.luaPlotDetail:OnLoad(wndParent)
	--self.plotBGArt = parent:FindChild("CurrentPlugViewFrame")
	--self.plotBGArt:Show(false)
end

function LandscapeCurrentControl:OnPlotsUpdated()
	self.luaPlotGrid:OnPlotsUpdated()
	
	local iPlot = GetSelectedPlotIndex()
	--Print("PlotsUpdated(): " .. curPlotInfoId .. ", " .. self.plotSelectionType)
	if iPlot > 0 then
		self:OnSelectPlot(iPlot, self.ePlotSelectionType)
	end
end

function LandscapeCurrentControl:OnSelectPlot(iPlot, eSelectionType)
	--Print("onSelectPlot")
	local idPlugItem = 0
	
	if eSelectionType ~= nil then
		--Print("onSelectPlot(): " .. selectionType )
		self.ePlotSelectionType = eSelectionType
	end
	
	local tPlotInfo = HousingLib.GetPlot(iPlot)
	local idPlugItem = tPlotInfo ~= nil and tPlotInfo.nPlugItemId or 0
	
	if tPlotInfo ~= nil and tPlotInfo.ePlotType ~= nil and tPlotInfo.ePlotType ~= 0 then
		self.ePlotSelectionType = tPlotInfo.ePlotType
	end

	--Print("plugItemId: " .. plugItemId)
	self.luaPlotDetail:clear(true)
	if(idPlugItem ~= 0) then
		self.luaPlotDetail:set(tPlotInfo, iPlot)
	else	
		self.luaPlotDetail:set(nil)
	end

end

---------------------------------------------------------------------------------------------------
-- LandscapeProposedControl methods
---------------------------------------------------------------------------------------------------
function LandscapeProposedControl:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	o.wndPlaceBtn 				= nil
	o.wndRePlaceBtn 			= nil
	o.wndDestroyFromCrateBtn 	= nil

	o.wndInfo 					= nil
	o.wndName 					= nil
	o.wndCurrPlugBG 			= nil
	o.wndPreview 				= nil
	
	o.luaHousingLandscapeInst 	= nil
	return o
end

function LandscapeProposedControl:OnLoad(wndParent, luaHousingLandscapeInst)
    self.wndBuyBtn 					= wndParent:FindChild("BuyBtn")
	self.wndPlaceBtn 				= wndParent:FindChild("PlaceBtn")
	self.wndDestroyFromCrateBtn 	= wndParent:FindChild("DeleteBtn")
	self.luaHousingLandscapeInst 	= luaHousingLandscapeInst
end

function LandscapeProposedControl:clear()
	local iPlot = GetSelectedPlotIndex()
	local tPlotInfo = HousingLib.GetPlot(iPlot)
	if tPlotInfo ~= nil then
	    self.wndBuyBtn:Enable(false)
		self.wndBuyBtn:Show(tPlotInfo.nPlugItemId ~= 0)
        self.wndPlaceBtn:Show(not tPlotInfo.nPlugItemId ~= 0)
        self.wndPlaceBtn:Enable(false)
	end

	self.wndBuyBtn:Show(not self.wndPlaceBtn:IsShown())
end

function LandscapeProposedControl:HandleDestroyBtnVisibility(strVendorOrCrate)
	if(strVendorOrCrate ~= nil) then
		self.wndDestroyFromCrateBtn:Show(strVendorOrCrate == "crate")
		self.wndDestroyFromCrateBtn:Enable(false)
	end
end

function LandscapeProposedControl:IsNotUnique(tItemData, iPlot)
	local bNotUnique = true
	local tFlags = tItemData.tFlags
	if tFlags.bIsUnique then
		local nPlotCount = HousingLib.GetPlotCount()
		for idx = 1, nPlotCount do
			local tPlotInfo = HousingLib.GetPlot(idx)
			if tPlotInfo.nPlugItemId == tItemData.nId then
				bNotUnique = false
			end
		end
	elseif tFlags.bIsUniqueHarvest then
		local nPlotCount = HousingLib.GetPlotCount()
		for idx = 1, nPlotCount do
			if idx ~= iPlot then
				local tPlotInfo = HousingLib.GetPlot(idx)
				local idPlugItem = tPlotInfo.nPlugItemId
				local tPlugItems = HousingLib.GetPlugItem(idPlugItem)
				local tPlugItemData = self.luaHousingLandscapeInst:GetItem(idPlugItem, tPlugItems)
				if tPlugItemData ~= nil then
					local tPlugFlags = tPlugItemData.tFlags
					
					if tPlugFlags.bIsUniqueHarvest then
						bNotUnique = false
						break
					end
				end
			end
		end
	elseif tFlags.bIsUniqueGarden then
		local nPlotCount = HousingLib.GetPlotCount()
		for idx = 1, nPlotCount do
			if idx ~= iPlot then
				local tPlotInfo = HousingLib.GetPlot(idx)
				local idPlugItem = tPlotInfo.nPlugItemId
				local tPlugItems = HousingLib.GetPlugItem(idPlugItem)
				local tPlugItemData = self.luaHousingLandscapeInst:GetItem(idPlugItem, tPlugItems)
				if tPlugItemData ~= nil then
					local tPlugFlags = tPlugItemData.tFlags
					
					if tPlugFlags.bIsUniqueGarden then
						bNotUnique = false
						break
					end
				end
			end
		end
	end
	
	return bNotUnique
end

function LandscapeProposedControl:set(tItemData, iPlot, strVendorOrCrate)
	if tItemData == nil or strVendorOrCrate == nil then
		self:clear()
		return	  
	end

	-- Disable the place button if this plugItem is unique and we already have one placed
	local bNotUnique = self:IsNotUnique(tItemData, iPlot)
	
	local tPlotInfo = HousingLib.GetPlot(iPlot)
	local bIsBuilding = tPlotInfo.bIsBuilding
	local bHaveEnoughCash = tItemData.bAreCostRequirementsMet
	local bEnableButton = not bIsBuilding and bNotUnique and (bHaveEnoughCash or strVendorOrCrate == "crate")
	self:HandlePlaceButton(iPlot, bEnableButton)
	self.wndBuyBtn:Enable(bEnableButton)
	self.wndBuyBtn:Show(not self.wndPlaceBtn:IsShown())
	--self.destroyFromCrateBtn:Enable(vendorOrCrate == "crate")
end

-- if you have the cash, and there's an appropriate plot selected , enable the place or replace button
function LandscapeProposedControl:HandlePlaceButton(iPlot, bEnableButton )
	local tPlotInfo = HousingLib.GetPlot(iPlot)
	
    if tPlotInfo == nil or tPlotInfo.nPlugItemId ~= 0 then
        self.wndPlaceBtn:Show(false)
        --self.rePlaceBtn:Show(true)
        --self.rePlaceBtn:Enable(enableButton)
    else
    	self.wndPlaceBtn:Show(true)
	    self.wndPlaceBtn:Enable(bEnableButton)
	    --self.rePlaceBtn:Show(false)
    end
end

---------------------------------------------------------------------------------------------------
-- PlotGrid methods
---------------------------------------------------------------------------------------------------
function PlotGrid:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	o.bIsWarplot			= false
	o.nTotalPlots			= nil
	o.tCells 				= {}
	o.wndLandscape 			= nil
	o.wndGuidelines 		= nil
	o.wndHousingLandscape 	= nil
	o.wndHousingGuidelines 	= nil
	o.wndWarplotLandscape 	= nil
	o.wndWarplotGuidelines 	= nil
	o.tOccupiedMark 		= {}
	o.tDisabledMark 		= {}
	o.tPlugItemIds 			= {}
	o.wndPlugFacingMarks 	= {}
	
	return o
end

-- PlotGrid's load should handle all the button/property "magic"
function PlotGrid:OnLoad(wndParent)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 		"OnPlotRefreshTimer", self)	

	self.wndCashLandscape 	= wndParent:FindChild("CashWindow")
	self.wndHousingLandscape  = wndParent:FindChild("LandscapeFrame")
	self.wndHousingGuidelines = wndParent:FindChild("PlotGuidelines")
	self.wndWarplotLandscape  = wndParent:FindChild("WarplotLandscapeFrame")
	self.wndMaintenanceCost   = self.wndWarplotLandscape:FindChild("MaintenanceCostLabel")
	self.wndWarplotGuidelines = wndParent:FindChild("WarplotGuidelines")
	self.wndLandscape 		= self.wndHousingLandscape
	self.wndGuidelines 		= self.wndHousingGuidelines
	self.wndParent 			= wndParent
	
	-- force a refresh
	self.bIsWarplot = not HousingLib.IsWarplotResidence()

	self:OnPlotRefreshTimer()
end

---------------------------------------------------------------------------------------------------
function PlotGrid:OnPlotRefreshTimer()	
	self:OnPlotsUpdated()
	if HousingLib.IsWarplotResidence() then	
		self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
		self.wndCashLandscape:SetAmount(GetWarCoins())
		self.wndMaintenanceCost:SetText(String_GetWeaselString(Apollo.GetString("Warparty_TotalBattleMaintenance"), HousingLib.GetWarplotMaintenanceCost()))
	else
		self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
		self.wndCashLandscape:SetAmount(GameLib.GetPlayerCurrency())
	end
end

function PlotGrid:OnPlotsUpdated()
	if self.bIsWarplot ~= HousingLib.IsWarplotResidence() or self.nTotalPlots == nil then
		self.bIsWarplot = HousingLib.IsWarplotResidence()	

		if self.bIsWarplot then
			self.nTotalPlots = knTotalWarplots
			self.wndLandscape = self.wndWarplotLandscape
			self.wndGuidelines = self.wndWarplotGuidelines
			self.wndWarplotLandscape:Show(true)
			self.wndWarplotGuidelines:Show(true)
			self.wndHousingLandscape:Show(false)
			self.wndHousingGuidelines:Show(false)
		else
			self.nTotalPlots = knTotalHousingPlots
			self.wndLandscape = self.wndHousingLandscape
			self.wndGuidelines = self.wndHousingGuidelines
			self.wndWarplotLandscape:Show(false)
			self.wndWarplotGuidelines:Show(false)
			self.wndHousingLandscape:Show(true)
			self.wndHousingGuidelines:Show(true)
		end

		for idx = 1, self.nTotalPlots do
			--print("winOccupiedMark - " .. ix)

			self.tOccupiedMark[idx] = self.wndLandscape:FindChild("OccupiedSprite." .. tostring(idx))
			self.tOccupiedMark[idx]:Show(false)
			
			self.tDisabledMark[idx] = self.wndLandscape:FindChild("DisabledSprite." .. tostring(idx))
			self.tDisabledMark[idx]:Show(false)
			
			if not self.bIsWarplot then
				self.wndPlugFacingMarks[idx] = 
				{
					[HousingLib.HousingPlugFacing.North] 	= self.wndLandscape:FindChild("FacingSpriteN." .. tostring(idx)),
					[HousingLib.HousingPlugFacing.South] 	= self.wndLandscape:FindChild("FacingSpriteS." .. tostring(idx)),	
					[HousingLib.HousingPlugFacing.East] 	= self.wndLandscape:FindChild("FacingSpriteE." .. tostring(idx)),
					[HousingLib.HousingPlugFacing.West] 	= self.wndLandscape:FindChild("FacingSpriteW." .. tostring(idx)),
					
				}
				self.wndPlugFacingMarks[idx][HousingLib.HousingPlugFacing.North]:Show(false)
				self.wndPlugFacingMarks[idx][HousingLib.HousingPlugFacing.South]:Show(false)
				self.wndPlugFacingMarks[idx][HousingLib.HousingPlugFacing.East]:Show(false)
				self.wndPlugFacingMarks[idx][HousingLib.HousingPlugFacing.West]:Show(false)
			end
		end
	end

	self.tPlugItemIds = {}

	local nCount = HousingLib.GetPlotCount()
		
	if not nCount or nCount > self.nTotalPlots then
		nCount = self.nTotalPlots
	end
	local nFirstIndex = 1
	if self.bIsWarplot then
		nFirstIndex = 2
	end

	for idx = nFirstIndex, nCount do
		local tPlotInfo = HousingLib.GetPlot(idx)
		if tPlotInfo ~= nil then
            self.tOccupiedMark[idx]:Show(tPlotInfo.nPlugItemId > 0 and tPlotInfo.bActive)
            self.tDisabledMark[idx]:Show(not tPlotInfo.bActive)
            self.tPlugItemIds[idx] = tPlotInfo.nPlugItemId

			if not self.bIsWarplot then
				for iFacing = 1, #self.wndPlugFacingMarks[idx] do
					local bVisible = false
					if tPlotInfo.nPlugItemId > 0 and iFacing == tPlotInfo.ePlugFacing and tPlotInfo.bCanBeRotated then
						bVisible = true;
					end
					self.wndPlugFacingMarks[idx][iFacing]:Show(bVisible)
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- PlotDetail methods
---------------------------------------------------------------------------------------------------
function PlotDetail:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	-- plugItem
	o.tPlugItem 		= {}
	o.wndPlugName 		= nil
	o.wndPlugView 		= nil
	o.wndRemove 		= nil
	o.wndPlugUpgrade 	= nil
	o.wndUpgrade 		= nil

	return o
end

function PlotDetail:OnLoad(wndParent)
	Apollo.RegisterTimerHandler("PlotDetailRefreshTimer", "OnPlotDetailRefreshTimer", self)
	
	self.wndPlugName 				= wndParent:FindChild("CurrentPlugLongName")
	self.wndRemove 					= wndParent:FindChild("DeleteBtn")
	self.wndPlugInfoFrameBuilt 		= wndParent:FindChild("PlotInfoFrame_Built")
	self.wndPlugInfoFrameBuilding 	= wndParent:FindChild("PlotInfoFrame_Building")
	self.wndPlugUpkeepTimeLabel 	= wndParent:FindChild("UpkeepTimeRemainingLabel")
	self.wndPlugUpkeepTimeText 		= wndParent:FindChild("UpkeepTimeRemainingText")
	self.wndPlugUpkeepChargesLabel 	= wndParent:FindChild("UpkeepChargesRemainingLabel")
	self.wndPlugUpkeepChargesText 	= wndParent:FindChild("UpkeepChargesRemainingText")
	self.wndPlugUpkeepNone 			= wndParent:FindChild("UpgradeNone")
	self.wndPlugBuildTimeLabel 		= wndParent:FindChild("BuildTimeLabel")
	self.wndPlugBuildTimeText 		= wndParent:FindChild("BuildTimeText")
	self.wndPlugInfoFrame 			= wndParent:FindChild("PlugInfoFrame")
	self.wndUpgrade 				= wndParent:FindChild("UpgradeBtn")
	self.wndView 					= wndParent:FindChild("ViewBtn")
	self.wndRotate 					= wndParent:FindChild("RotateBtn")
	self.wndFrame 					= wndParent
	self.nChosenPlot = nil
	
	local bResetPlugName = false
	self:clear(bResetPlugName)
end

function PlotDetail:clear(bResetPlugName)
	if bResetPlugName == true then
		self.wndPlugName:SetText(Apollo.GetString("HousingLandscape_None"))
	end
	
    self.wndPlugInfoFrameBuilt:Show(false)
    self.wndPlugInfoFrameBuilding:Show(false)
	self.wndPlugInfoFrame:Show(false)
	
	self.wndRemove:Enable(false)
	self.wndUpgrade:Enable(false)
	self.wndUpgrade:SetText(Apollo.GetString("HousingLandscape_NoUpgrade"))
	self.wndRotate:Enable(false)
	self.wndView:Show(false)
	self.nChosenPlot = nil
end

-----------------------------------------------------------------------------------------------
function PlotDetail:OnPlotDetailRefreshTimer()
	if self.wndFrame:IsShown() then
		if self.nChosenPlot ~= nil then
			self:set(nil, self.nChosenPlot)
		end
	end
end


-----------------------------------------------------------------------------------------------
function PlotDetail:set(tPlotInfo, iPlot)
	-- plug name
	if iPlot ~= nil then
		self.nChosenPlot = iPlot
		tPlotInfo = HousingLib.GetPlot(iPlot)
	else
		if tPlotInfo == nil then
			self.nChosenPlot = nil
		    return
		end
	end
	
	self.wndPlugName:SetText(tPlotInfo.strName)
	self.wndRemove:Enable(tPlotInfo.nPlugItemId ~= knStarterTentPlugItemId)  
	
	self.wndView:Show(true)
	if tPlotInfo.bIsBuilding then
	    self.wndPlugInfoFrameBuilt:Show(false)
	    self.wndPlugInfoFrameBuilding:Show(true)
	    self:HelperFormatTimeRemainingString(tPlotInfo.fBuildTimeRemainingHours, true)
	else
		self.wndPlugInfoFrameBuilt:Show(true)
	    self.wndPlugInfoFrameBuilding:Show(false)
	    
        if tPlotInfo.bHasUpgrade then
            self.wndUpgrade:Enable(true)
			self.wndUpgrade:SetText(Apollo.GetString("HousingLandscape_UpgradeEnhancement"))
        else
            self.wndUpgrade:Enable(false)
			self.wndUpgrade:SetText(Apollo.GetString("HousingLandscape_NoUpgrade"))
        end
        
        if tPlotInfo.bActive then
            if tPlotInfo.eUpkeepType == HousingLib.HousingUpkeepType.Permanent or tPlotInfo.eUpkeepType == HousingLib.HousingUpkeepType.Decay then
                self.wndView:Enable(false)
				self.wndPlugUpkeepTimeLabel:Show(false)
                self.wndPlugUpkeepTimeText:Show(false)
                self.wndPlugUpkeepChargesLabel:Show(false)
                self.wndPlugUpkeepChargesText:Show(false)
            elseif tPlotInfo.eUpkeepType == HousingLib.HousingUpkeepType.StructurePoints then
				self.wndView:Enable(true)
				self.wndView:SetText(Apollo.GetString("HousingLandscape_ViewInfo"))
				self.wndPlugUpkeepTimeLabel:Show(false)
                self.wndPlugUpkeepTimeText:Show(false)
				self.wndPlugUpkeepChargesLabel:Show(false)
				self.wndPlugUpkeepChargesText:Show(false)
            elseif tPlotInfo.eUpkeepType == HousingLib.HousingUpkeepType.Timed or tPlotInfo.eUpkeepType == HousingLib.HousingUpkeepType.TimedCharged then
                self.wndPlugUpkeepTimeLabel:Show(true)
                self.wndPlugUpkeepTimeText:Show(true)
				self:HelperFormatTimeRemainingString(tPlotInfo.fRemainingHours)
				self.wndView:Enable(true)
				self.wndView:SetText(Apollo.GetString("HousingLandscape_ViewInfo"))
				self.wndPlugUpkeepChargesLabel:Show(false)
                self.wndPlugUpkeepChargesText:Show(false)
            elseif tPlotInfo.eUpkeepType == HousingLib.HousingUpkeepType.Charged or tPlotInfo.eUpkeepType == HousingLib.HousingUpkeepType.TimedCharged then
				self.wndView:Enable(true)
				self.wndView:SetText(Apollo.GetString("HousingLandscape_ViewInfo"))
				self.wndPlugUpkeepTimeLabel:Show(false)
                self.wndPlugUpkeepTimeText:Show(false)
                self.wndPlugUpkeepChargesLabel:Show(true)
                self.wndPlugUpkeepChargesText:Show(true)
                self.wndPlugUpkeepChargesText:SetText(tPlotInfo.nChargesRemaining)
            end
			
			if not HousingLib.IsWarplotResidence() then	
				self.wndRotate:Enable(tPlotInfo.bCanBeRotated)
			end
        else
            self.wndView:Enable(true)
			self.wndView:SetText(Apollo.GetString("HousingLandscape_Repair"))
			self.wndPlugUpkeepTimeLabel:Show(true)
            self.wndPlugUpkeepTimeText:Show(true)
			self.wndPlugInfoFrame:FindChild("InfoRepairBtn"):Show(true)
			self.wndPlugInfoFrame:FindChild("InfoRepairBtn"):Enable(true)
			self.wndPlugUpkeepTimeText:SetText(Apollo.GetString("HousingLandscape_NeedsRepair"))
			self.wndPlugUpkeepTimeText:SetTextColor(kcrDisabledColor)
            self.wndPlugUpkeepChargesLabel:Show(false)
            self.wndPlugUpkeepChargesText:Show(false)
			self.wndRotate:Enable(false)
        end
	end
end

-----------------------------------------------------------------------------------------------
function HousingLandscape:HelperClearInfo()
	self.wndPlugInfoFrame:FindChild("Title"):SetText(Apollo.GetString("HousingLandscape_NoEnhancementFound"))
	self.wndPlugInfoFrame:FindChild("PlugDescription"):SetText(Apollo.GetString("HousingLandscape_NoEnhancementOnPlot"))
	self.wndPlugInfoFrame:FindChild("PlugPrereqs"):SetText("")
	self.wndPlugInfoFrame:FindChild("PlugFlags"):SetText("")
	self.wndPlugInfoFrame:FindChild("CostEntryContainer"):DestroyChildren()
	self.wndPlugInfoFrame:FindChild("RepairEntryContainer"):DestroyChildren()
	self.wndPlugInfoFrame:FindChild("CostComplex"):Show(false)	
	self.wndPlugInfoFrame:FindChild("RepairComplex"):Show(false)	
	
	
	local wndPlugInfoPanel = self.wndPlugInfoFrame:FindChild("UpgradePlugFrame")
	local nPadding = 8 -- how much vert padding between entries

	wndPlugInfoPanel:FindChild("Title"):SetText(Apollo.GetString("HousingLandscape_NoEnhancementFound"))
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame:PlugDescription"):SetText(Apollo.GetString("HousingLandscape_NoEnhancementExpanded"))
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame:PlugDescription"):SetHeightToContentHeight() -- will be 0 if no text
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame"):RecalculateContentExtents()
end

-----------------------------------------------------------------------------------------------
function HousingLandscape:DrawInfo(iPlot, eSelectionType)
	
	if iPlot <= 0 then
		return
	end

	self:HelperClearInfo()
	
	if eSelectionType ~= nil then
		self.ePlotSelectionType = eSelectionType
	else
		return
	end
	
	local tPlotInfo = HousingLib.GetPlot(iPlot)
	local idPlugItem = tPlotInfo ~= nil and tPlotInfo.nPlugItemId or 0
	
	if tPlotInfo.ePlotType and tPlotInfo.ePlotType ~= 0 then
		self.ePlotSectionType = tPlotInfo.ePlotType
	end

	if idPlugItem == 0 then
		return
	end
	
	local wndPlugInfoPanel = self.wndPlugInfoFrame:FindChild("ViewPlugInfoFrame")
 	local iPlot = GetSelectedPlotIndex()
	local tPlotInfo2 = HousingLib.GetPlot(iPlot)
	local idPlugItem2 = tPlotInfo2.nPlugItemId
    local tItemList = HousingLib.GetPlugItem(idPlugItem2)
    local tItemInfo = self:GetItem(idPlugItem2, tItemList)
	
	if tItemInfo == nil then 
		return 
	end
	
	local nPadding = 8 -- how much vert padding between entries
	wndPlugInfoPanel:FindChild("Title"):SetText(tItemInfo.strName)
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame:PlugDescription"):SetText(tItemInfo.strTooltip)
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame:PlugDescription"):SetHeightToContentHeight(20) -- will be 0 if no text
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame"):RecalculateContentExtents()

	local nRepairCount = 0
	local nRepairEntryHeight = 0
	local wndRepair = wndPlugInfoPanel:FindChild("RepairComplex")	
	local bCanRepair = true
	local tRepairRequirements = tItemInfo.tRepairRequirements
	
	if tPlotInfo.bNeedsRepair then
		tRepairRequirements = tPlotInfo.tRepairCosts
	end
	
	wndRepair:FindChild("RepairEntryContainer"):DestroyChildren()
	for idx, tCost in ipairs(tRepairRequirements) do
	    local wndCost = Apollo.LoadForm(self.xmlDoc, "CostEntry", wndRepair:FindChild("RepairEntryContainer"), self)
		nRepairCount = nRepairCount + 1
		nRepairEntryHeight = wndCost:GetHeight()

	    if tCost.eType == 1 then -- cash
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("ItemLabel"):Show(false)
	        wndCost:FindChild("CashWindow"):Show(true)
	        wndCost:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.Credits, tCost.nRequiredCost)
	        wndCost:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
	        wndCost:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndCost:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)

			if tCost.nRequiredCost > GameLib.GetPlayerCurrency():GetAmount() then
				wndCost:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
				bCanRepair = false
			end
			
	    elseif tCost.eType == 2 and tCost.itemRepairReq ~= nil then -- item
	        wndCost:FindChild("CashWindow"):Show(false)
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("ItemLabel"):Show(true)
	        wndCost:FindChild("ItemLabel"):SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_ItemCostLabel"), tCost.nRequiredCost, tCost.itemRepairReq:GetName()))
            wndCost:FindChild("SourceIcon"):SetSprite(tCost.itemRepairReq:GetIcon())
            wndCost:FindChild("SourceIcon"):SetItemInfo(tCost.itemRepairReq, tCost.nRequiredCost)
			wndCost:FindChild("ItemLabel"):SetTextColor(kcrEnabledColor)
			
			if tCost.nAvailableCount ~= nil and tCost.nAvailableCount < tCost.nRequiredCost then
				wndCost:FindChild("ItemLabel"):SetTextColor(kcrDisabledColor)
				wndCost:FindChild("ItemLabel"):SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_ItemCostBackpack"), tCost.nAvailableCount, tCost.nRequiredCost, tCost.itemRepairReq:GetName()))
				bCanRepair = false
			end
			
        elseif tCost.eType == 3 then -- other currency			
	        wndCost:FindChild("ItemLabel"):Show(false)
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("CashWindow"):Show(true)
	        wndCost:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.Renown, tCost.nRequiredCost)
	        wndCost:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.Renown)
	        wndCost:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndCost:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)
			
			if tCost.nRequiredCost > GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount() then
				wndCost:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
				bCanRepair = false
			end			
        elseif tCost.eType == 4 then -- War Coins
	        wndCost:FindChild("ItemLabel"):Show(false)
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("CashWindow"):Show(true)
	        wndCost:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.GroupCurrency, tCost.nRequiredCost, Money.CodeEnumGroupCurrencyType.WarCoins)
	        wndCost:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
	        wndCost:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndCost:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)
			
			if tCost.nRequiredCost > GetWarCoins() then
				wndCost:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
				bCanRepair = false
			end			
	    end
	end
	
	wndRepair:FindChild("RepairEntryContainer"):ArrangeChildrenVert(0)
	local nRepairLeft, nRepairTop, nRepairRight, nRepairBottom = wndRepair:GetAnchorOffsets()
	local nLeftDif, nTopDif, nRightDif, nBottomDif = wndRepair:FindChild("RepairEntryContainer"):GetAnchorOffsets()
	
	if nRepairCount > 0 then
		wndRepair:Show(true)
		nRepairLeft, nRepairTop, nRepairRight, nRepairBottom = wndRepair:GetAnchorOffsets()
		self.wndPlugInfoFrame:FindChild("InfoRepairBtn"):Show(true)
		local nLeftBtn, nTopBtn, nRightBtn, nBottomBtn = self.wndPlugInfoFrame:FindChild("InfoRepairBtn"):GetAnchorOffsets()
		nRepairLeft, nRepairTop, nRepairRight, nRepairBottom = self.wndPlugInfoFrame:FindChild("InfoRepairBtn"):GetAnchorOffsets()
		
		local bEnable = (not tPlotInfo.bIsBuilding and not tPlotInfo.bActive and bCanRepair == true) or tPlotInfo.bNeedsRepair
	
		self.wndPlugInfoFrame:FindChild("InfoRepairBtn"):Enable(bEnable)
	else
		wndRepair:Show(false)
		nRepairBottom = nDescriptionBottom
	end
end

-----------------------------------------------------------------------------------------------
function HousingLandscape:DrawTierUpgradeInfo(tItemData, tOldItemData)


	if tItemData == nil then 
		return 
	end
	
	self.idUniqueItem = tItemData.nId
	
	local wndPlugInfoPanel = self.wndPlugInfoFrame:FindChild("UpgradePlugFrame")  
	local nPadding = 8 -- how much vert padding between entries
	wndPlugInfoPanel:FindChild("Title"):SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_UpgradeTitle"), tItemData.strName))
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame:PlugDescription"):SetText(tItemData.strTooltip)
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame:PlugDescription"):SetHeightToContentHeight() -- will be 0 if no text
	wndPlugInfoPanel:FindChild("PlugDescriptionFrame"):RecalculateContentExtents()
	local nLeft1, nTop1, nRight1, nBottom1 = wndPlugInfoPanel:FindChild("PlugDescription"):GetAnchorOffsets()
	local bCanUpgrade = true
	
	-- Pre-reqs
	local wndPrereq = wndPlugInfoPanel:FindChild("PlugPrereqs")
	local strPrereq = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_BtnTextGreenNormal\">%s</T>", Apollo.GetString("HousingLandscape_Requirements"))
	if #tItemData.tPrerequisites > 0 then
		local nCount = 0
		local strPrereqList = ""
        for idx, tPrereq in ipairs(tItemData.tPrerequisites) do
            if nCount > 0 then
				strPrereqList = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloTitle\">%s</T>", String_GetWeaselString(Apollo.GetString("Archive_TextList"), strPrereqList, tPrereq.strTooltip))
			else
				strPrereqList = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloTitle\">%s</T>", tPrereq.strTooltip)
			end
			nCount = nCount + 1
			if tPrereq["bPrerequisiteMet"] ~= true then
			    bCanUpgrade = false
			end
        end
		strPrereq = String_GetWeaselString(strPrereq, strPrereqList)
        wndPrereq:SetText(strPrereq)
	end
	
	local nLeftOrig, nTopOrig, nRightOrig, nBottomOrig = wndPrereq:GetAnchorOffsets()
	wndPrereq:SetHeightToContentHeight() -- will be 0 if no text
	local nLeftNew, nTopNew, nRightNew, nBottomNew = wndPrereq:GetAnchorOffsets()
	local nLeftDescFrame, nTopDescFrame, nRightDescFrame, nBottomDescFrame = wndPlugInfoPanel:FindChild("PlugDescriptionFrame"):GetAnchorOffsets()

	if wndPrereq:GetHeight() > 0 then
		wndPlugInfoPanel:FindChild("PlugDescriptionFrame"):SetAnchorOffsets(nLeftDescFrame, nTopDescFrame, nRightDescFrame, nTopNew - nPadding)	
	else
		wndPlugInfoPanel:FindChild("PlugDescriptionFrame"):SetAnchorOffsets(nLeftDescFrame, nTopDescFrame, nRightDescFrame, nBottomOrig - nPadding)	
	end

	local nRepairCount = 0
	local nRepairEntryHeight = 0
	local wndRepair = wndPlugInfoPanel:FindChild("RepairComplex")
	
	wndRepair:FindChild("RepairEntryContainer"):DestroyChildren()
	for idx, tCost in ipairs(tItemData.tCostRequirements) do
	    local wndCost = Apollo.LoadForm(self.xmlDoc, "CostEntry", wndRepair:FindChild("RepairEntryContainer"), self)
		nRepairCount = nRepairCount + 1
		nRepairEntryHeight = wndCost:GetHeight()

	    if tCost.eType == 1 then -- cash
	        wndCost:FindChild("ItemLabel"):Show(false)
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("CashWindow"):Show(true)
	        wndCost:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.Credits, tCost.nRequiredCost)
	        wndCost:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
	        wndCost:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndCost:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)

			if tCost.nRequiredCost > GameLib.GetPlayerCurrency():GetAmount() then
				wndCost:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
				bCanUpgrade = false
			end
			
	    elseif tCost.eType == 2 and tCost.itemCostReq ~= nil then -- tItemData
	        wndCost:FindChild("CashWindow"):Show(false)
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("ItemLabel"):Show(true)
	        wndCost:FindChild("ItemLabel"):SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_ItemCostLabel"), tCost.nRequiredCost, tCost.itemCostReq:GetName()))
            wndCost:FindChild("SourceIcon"):SetSprite(tCost.itemCostReq:GetIcon())
            wndCost:FindChild("SourceIcon"):SetItemInfo(tCost.itemCostReq, tCost.nRequiredCost)
			wndCost:FindChild("ItemLabel"):SetTextColor(kcrEnabledColor)
			
			if tCost.nAvailableCount ~= nil and tCost.nAvailableCount < tCost.nRequiredCost then
				wndCost:FindChild("ItemLabel"):SetTextColor(kcrDisabledColor)
				wndCost:FindChild("ItemLabel"):SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_ItemCostBackpack"), tCost.nAvailableCount, tCost.nRequiredCost, tCost.itemCostReq:GetName()))
				bCanUpgrade = false
			end
			
        elseif tCost.eType == 3 then -- other currency			
	        wndCost:FindChild("ItemLabel"):Show(false)
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("CashWindow"):Show(true)
	        wndCost:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.Renown, tCost.nRequiredCost)
	        wndCost:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.Renown)
	        wndCost:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndCost:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)
			
			if tCost.nRequiredCost > GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount() then
				wndCost:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
				bCanUpgrade = false
			end	
					
        elseif tCost.eType == 4 then -- War Coins
	        wndCost:FindChild("ItemLabel"):Show(false)
	        wndCost:FindChild("SourceIcon"):Show(true)
	        wndCost:FindChild("CashWindow"):Show(true)
	        wndCost:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.GroupCurrency, tCost.nRequiredCost, Money.CodeEnumGroupCurrencyType.WarCoins)
	        wndCost:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
	        wndCost:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndCost:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)
			
			if tCost.nRequiredCost > GetWarCoins() then
				wndCost:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
				bCanUpgrade = false
			end			
	    end
	end
	
	wndRepair:FindChild("RepairEntryContainer"):ArrangeChildrenVert(0)
	local nLeft4, nTop4, nRight4, nBottom4 = wndRepair:GetAnchorOffsets()
	local nLeftDif, nTopDif, nRightDif, nRightDif = wndRepair:FindChild("RepairEntryContainer"):GetAnchorOffsets()
	
	if nRepairCount > 0 then
		wndRepair:Show(true)
		--wndRepair:SetAnchorOffsets(nLeft4, nBottom2 + nPadding, nRight4, nBottom2 + nPadding + nTopDif + (nRepairEntryHeight*nRepairCount) - nRightDif) -- last one is negative
		nLeft4, nTop4, nRight4, nBottom4 = wndRepair:GetAnchorOffsets()
		local wndUpgradeBtn = self.wndPlugInfoFrame:FindChild("UpgradePlugFrame:InfoUpgradeBtn")
		wndUpgradeBtn:Show(true)
		local nLeftBtn, nTopBtn, nRightBtn, nBottomBtn = wndUpgradeBtn:GetAnchorOffsets()
		--wndUpgradeBtn:SetAnchorOffsets(nLeftBtn, nBottom4 + 2, nRightBtn, nBottom4 + 2 + (nBottomBtn - nTopBtn))
		nLeft4, nTop4, nRight4, nBottom4 = wndUpgradeBtn:GetAnchorOffsets()
		self.wndPlugInfoFrame:FindChild("UpgradePlugFrame:InfoUpgradeBtn"):Enable(bCanUpgrade)
	else
		wndRepair:Show(false)
		nBottom4 = nBottom1
	end
	
	wndPlugInfoPanel:Show(true)
	self.luaLandscapeProposedControl:clear()
end

-----------------------------------------------------------------------------------------------
function PlotDetail:HelperFormatTimeRemainingString(fHours, bBuilding)
	local nDays =  math.floor(fHours / 24)
	local nHours = math.floor(fHours -(nDays * 24))	
	--local nHours = math.floor(((fHours/24) - nDays)*10)
	local nMinutes = math.floor((fHours-(nDays * 24) - nHours) * 60) 
	
	local strRemainingTime = ""
	if bBuilding then
		if nDays > 1 then
			strRemainingTime = String_GetWeaselString(Apollo.GetString("HousingLandscape_DaysHours"), nDays, nHours)
		elseif nMinutes < 10 and nMinutes > 0 then
			strRemainingTime = String_GetWeaselString(Apollo.GetString("HousingLandscape_HoursMinsWithZero"), nHours, nMinutes)
		elseif nMinutes < 1 then --fHours * 60.0 < 1.0 then
			strRemainingTime = Apollo.GetString("HousingLandscape_LessThanMinute")
		else
			strRemainingTime = String_GetWeaselString(Apollo.GetString("HousingLandscape_HoursMins"), nHours, nMinutes)
		end 
		
		self.wndPlugBuildTimeText:SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_Building"), strRemainingTime))
		return	
	end
	
	self.wndPlugUpkeepTimeText:SetTextColor(kcrEnabledColor)	
	if nDays > 1 then
		strRemainingTime = String_GetWeaselString(Apollo.GetString("HousingLandscape_UpkeepDaysHours"), nDays, nHours)
	elseif nMinutes < 10 and nMinutes > 0 then
		strRemainingTime = String_GetWeaselString(Apollo.GetString("HousingLandscape_UpkeepHoursMinsWithZero"), nHours, nMinutes)
		self.wndPlugUpkeepTimeText:SetTextColor(kcrDisabledColor)
    elseif nMinutes < 1 then --fHours * 60.0 < 1.0 then
		strRemainingTime = Apollo.GetString("HousingLandscape_UpkeepLessThanMin")
		self.wndPlugUpkeepTimeText:SetTextColor(kcrDisabledColor)
    else
		strRemainingTime = String_GetWeaselString(Apollo.GetString("HousingLandscape_UpkeepHoursMins"), nHours, nMinutes)
    end  
	self.wndPlugUpkeepTimeText:SetText(strRemainingTime)
end

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function HousingLandscape:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

	-- initialize our variables
	o.wndLandscape 					= nil
	o.wndListView 					= nil
	o.wndOkButton 					= nil
	o.wndCashLandscape 				= nil
	o.wndMaintenanceCost			= nil
	
	o.wndDestroyUnderPopup			= nil
	o.wndCrateUnderPopup 			= nil
	o.wndDelete_OldDestroy 			= nil
	o.wndConfirmCheck_OldDestroy 	= nil
	
	o.wndSortByList 				= nil
	o.tCategoryItems 				= {}
	
	o.tVendorItemsLandscape 		= {}
	o.tStorageItemsLandscape 		= {}
	
	o.luaLandscapeCurrentControl 	= LandscapeCurrentControl:new()
	o.luaLandscapeProposedControl 	= LandscapeProposedControl:new()
	
	o.iNumScreenshots = 0
	o.iCurrScreen = 0
	o.iCurrPrevPlugItemId = 0

    return o
end

function HousingLandscape:Init()
    Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- HousingLandscape OnLoad
-----------------------------------------------------------------------------------------------
function HousingLandscape:OnLoad()
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("HousingButtonLandscape", 		"OnHousingButtonLandscape", self)
	Apollo.RegisterEventHandler("HousingButtonCrate", 			"OnHousingButtonCrate", self)
	Apollo.RegisterEventHandler("HousingButtonVendor", 			"OnHousingButtonCrate", self)
	Apollo.RegisterEventHandler("HousingButtonList", 			"OnHousingButtonList", self)
	Apollo.RegisterEventHandler("HousingButtonRemodel", 		"OnHousingButtonRemodel", self)
	Apollo.RegisterEventHandler("HousingVendorListRecieved", 	"OnHousingPlugItemsUpdated", self)
	Apollo.RegisterEventHandler("HousingStorageListRecieved", 	"OnHousingPlugItemsUpdated", self)
	Apollo.RegisterEventHandler("HousingPanelControlOpen", 		"OnOpenPanelControl", self)
	Apollo.RegisterEventHandler("HousingPanelControlClose", 	"OnClosePanelControl", self)
	Apollo.RegisterEventHandler("HousingConfirmReplace", 		"OnConfirmReplaceRequest", self)
	Apollo.RegisterEventHandler("HousingPlotsRecieved", 		"OnPlotsUpdated", self)
	Apollo.RegisterEventHandler("ChangeWorld", 					"OnCloseHousingLandscapeWindow", self)	

	Apollo.CreateTimer("PlotDetailRefreshTimer", 1.0, true)
	Apollo.StopTimer("PlotDetailRefreshTimer")
    
    -- load our forms
    self.xmlDoc = XmlDoc.CreateFromFile("HousingLandscape.xml")
    self.wndLandscape 		= Apollo.LoadForm(self.xmlDoc, "HousingLandscapeWindow", nil, self)
	self.wndStructureList 	= self.wndLandscape:FindChild("StructureListWnd")
	self.wndBuyButton 		= self.wndLandscape:FindChild("BuyBtn")
	self.wndPlaceButton 	= self.wndLandscape:FindChild("PlaceBtn")
	self.wndDeleteButton 	= self.wndLandscape:FindChild("DeleteBtn")
	self.wndCancelButton 	= self.wndLandscape:FindChild("CancelBtn")
	self.wndMaintenanceCost = self.wndLandscape:FindChild("MaintenanceCostLabel")
	self.wndCashLandscape 	= self.wndLandscape:FindChild("CashWindow")
	self.wndSearch 			= self.wndLandscape:FindChild("SearchBox")
	self.wndClearSearchBtn 	= self.wndLandscape:FindChild("ClearSearchBtn")
	self.wndPlugInfoFrame 	= self.wndLandscape:FindChild("PlugInfoFrame")
	self.wndTogglePreview   = self.wndLandscape:FindChild("PreviewPlugToggle")
	self.wndPreview         = self.wndLandscape:FindChild("PreviewPlugFrame")
	self.wndLandscape:Show(false, true)
	
	self.luaLandscapeProposedControl:OnLoad(self.wndLandscape, self)
	self.luaLandscapeCurrentControl:OnLoad(self.wndLandscape)
	
	--self.wndCrateUnderPopup 	= Apollo.LoadForm(self.xmlDoc, "PopupCrateUnder", nil, self)

	self.wndBuyButton:Enable(false)
	self.wndPlaceButton:Enable(false)
	self.wndDeleteButton:Enable(false)
	self.wndCancelButton:Enable(true)
	self.wndClearSearchBtn:Show(false)
	
	self.wndSortByList = self.wndLandscape:FindChild("SortByList")
	self:PopulateCategoryList()
	
	-- landscape item lists
	HousingLib.RequestVendorList()

	if HousingLib.IsWarplotResidence() then	
        self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
		self.wndCashLandscape:SetAmount(GetWarCoins(), true)
		self.wndMaintenanceCost:SetText(String_GetWeaselString(Apollo.GetString("Warparty_TotalBattleMaintenance"), HousingLib.GetWarplotMaintenanceCost()))
	else
        self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
		self.wndCashLandscape:SetAmount(GameLib.GetPlayerCurrency(), true)
	end
	
	self.luaLandscapeProposedControl:clear()
	
	self:ResetPopups()
	
	self:HelperSetPlotlines()
	
	HousingLib.RefreshUI()
	
	self:HelperTogglePreview(false)
	
	-- TODO: Re-Enable once category selection is set up
	self.wndLandscape:FindChild("SortByBtn"):Enable(false)	
end

function HousingLandscape:OnWindowManagementReady()
	local strName = string.format("%s: %s", Apollo.GetString("CRB_Housing"), Apollo.GetString("CRB_Landscape"))
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndLandscape, strName = strName})
end

function HousingLandscape:ResetPopups()
    if self.wndCrateUnderPopup ~= nil then
	    self.wndCrateUnderPopup:Destroy()
	    self.wndCrateUnderPopup = nil
	end
	
	if self.wndDestroyUnderPopup ~= nil then
	    self.wndDestroyUnderPopup:Destroy()
	    self.wndDestroyUnderPopup = nil
	end    
	
	if self.wndRemovePopup ~= nil then
	    self.wndRemovePopup:Destroy()
	    self.wndRemovePopup = nil
	end    

    if self.wndRotatePopup ~= nil then
	    self.wndRotatePopup:Destroy()
	    self.wndRotatePopup = nil
	end  
	
	self.wndPlugInfoFrame:Show(false)
	self:HelperTogglePreview(false)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPlotsUpdated()
	--Print("OnPlotsUpdated()")
	self.luaLandscapeCurrentControl:OnPlotsUpdated()
	self:OnHousingPlugItemsUpdated()
end


---------------------------------------------------------------------------------------------------
function HousingLandscape:OnOpenPanelControl(idPropertyInfo, idZone, bPlayerIsInside)
	if self.bPlayerIsInside ~= bPlayerIsInside then
		self:OnCloseHousingLandscapeWindow()
	end	
	
	gidZone = idZone
	self.idPropertyInfo = idPropertyInfo
	self.bPlayerIsInside = bPlayerIsInside == true --make sure we get true/false
end


---------------------------------------------------------------------------------------------------
function HousingLandscape:OnClosePanelControl()
	self:OnCloseHousingLandscapeWindow() -- you've left your property!
	
end


---------------------------------------------------------------------------------------------------
function HousingLandscape:OnConfirmReplaceRequest(idPlotInfo, idPlugItem, bFromCrate)
    self:ResetPopups()
    self.wndDestroyUnderPopup = Apollo.LoadForm(self.xmlDoc, "PopupDestroyUnder", nil, self)
	self.wndDestroyUnderPopup:Show(true)
	local wndWarningText = self.wndDestroyUnderPopup:FindChild("Disclaimer")
	local wndWarningText2 = self.wndDestroyUnderPopup:FindChild("Disclaimer2")

	
	local iPlot = GetSelectedPlotIndex()
	local tPlotInfo2 = HousingLib.GetPlot(iPlot)
	local idPlugItem2 = tPlotInfo2.nPlugItemId
    local tItemList = HousingLib.GetPlugItem(idPlugItem2)
    local tItemInfo = self:GetItem(idPlugItem2, tItemList)
    
    local tItemList2 = HousingLib.GetPlugItem(self.idUniqueItem)
    local tItemInfo2 = self:GetItem(self.idUniqueItem, tItemList2)
    
	wndWarningText:SetAML(string.format("<P Font=\"CRB_InterfaceMedium\" Align=\"Center\" TextColor=\"UI_TextHoloBodyHighlight\">"..String_GetWeaselString(Apollo.GetString("HousingLandscape_DestroyWarning"), tItemInfo.strName, tItemInfo2.strName).."</P>"))
	wndWarningText2:SetAML(string.format("<P Font=\"CRB_InterfaceMedium\" Align=\"Center\" TextColor=\"UI_TextHoloBody\">"..Apollo.GetString("HousingLandscape_CrateWarning").."</P>"))
	
	--Resize this window based on content
	wndWarningText:SetHeightToContentHeight()
	wndWarningText2:SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wndWarningText:GetAnchorOffsets()
	local nLeft2, nTop2, nRight2, nBottom2 = wndWarningText2:GetAnchorOffsets()
	local nLeft3, nTop3, nRight3, nBottom3 = self.wndDestroyUnderPopup:GetAnchorOffsets()
	wndWarningText2:SetAnchorOffsets(nLeft2, nBottom + 10, nRight2, wndWarningText2:GetHeight() + nBottom + 10)
	self.wndDestroyUnderPopup:SetAnchorOffsets(nLeft3, nTop3, nRight3, nTop3 + wndWarningText:GetHeight() + wndWarningText2:GetHeight() + 190)

	
	self.wndDestroyUnderPopup:ToFront()
	self.wndLandscape:Show(false)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:RemoveCurrentPlug()
	local iCurrPlot = GetSelectedPlotIndex()
	if iCurrPlot == 0 then
		return
	end

	HousingLib.ClearPlot(iCurrPlot)
	
	self.luaLandscapeCurrentControl.luaPlotDetail:clear(true)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:PlaceNewPlug(bConfirmed)
	if self.idUniqueItem == nil then
		return
	end

	local idPlotInfo = GetSelectedPlotIndex()
	HousingLib.PlaceFromVendor(idPlotInfo, self.idUniqueItem, bConfirmed)
	
    if bConfirmed then
        self.luaLandscapeProposedControl:clear()
		if HousingLib.IsWarplotResidence() then
			self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
			self.wndCashLandscape:SetAmount(GetWarCoins(), idPlotInfo)
			self.wndMaintenanceCost:SetText(String_GetWeaselString(Apollo.GetString("Warparty_TotalBattleMaintenance"), HousingLib.GetWarplotMaintenanceCost()))
		else
			self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
			self.wndCashLandscape:SetAmount(GameLib.GetPlayerCurrency(), idPlotInfo)
		end
    end   
end

-----------------------------------------------------------------------------------------------
-- HousingLandscape Functions
-----------------------------------------------------------------------------------------------
function HousingLandscape:ResetAll()
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_SelectPlot"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(true)	
	self:HelperSetPlotlines()
	self.tLandscapeEntries = {}
	self.wndStructureList:DestroyChildren()
	self.wndStructureList:RecalculateContentExtents()
	self.iNumScreenshots = 0
	self.iCurrScreen = 0
	self.iCurrPrevPlugItemId = 0
	self.wndTogglePreview:Enable(false)
	self.tVendorItemsLandscape = nil

	if HousingLib.IsWarplotResidence() then
		-- reset left side panel, too
		self.luaLandscapeCurrentControl.luaPlotDetail:clear(true)		
		local wndButtons = self.wndLandscape:FindChild("WarplotLandscapeFrame")
		
		for idx = 1,knTotalWarplots do
			wndButtons:FindChild("Plot" .. idx):SetCheck(false)
		end
		
		wndButtons:SetRadioSel("WarplotGroup", 1)
	else
		-- reset left side panel, too
		self.luaLandscapeCurrentControl.luaPlotDetail:clear(true)		
		local wndButtons = self.wndLandscape:FindChild("LandscapeFrame")
		
		for idx = 1,knTotalHousingPlots do
			wndButtons:FindChild("Plot" .. idx):SetCheck(false)
		end
		
		wndButtons:SetRadioSel("PlotGroup", 0)
	end
end

function HousingLandscape:OnSortByUncheck()
	self.wndLandscape:FindChild("SortByList"):Show(false)
end

function HousingLandscape:OnSortByCheck()
	self.wndLandscape:FindChild("SortByList"):Show(true)
end

function HousingLandscape:OnSortByName(wndHandler, wndControl)
	if not wndHandler then 
		return 
	end
	--self.eSortType = 1
	self:HelperOnSortByUpdateDropdown(wndHandler:GetText())
end

function HousingLandscape:OnSortByZone(wndHandler, wndControl)
	if not wndHandler then return end
	--self.eSortType = 2
	self:HelperOnSortByUpdateDropdown(wndHandler:GetText())
end

function HousingLandscape:OnSortByUpdated(wndHandler, wndControl)
	if not wndHandler then return end
	--self.eSortType = 3
	self:HelperOnSortByUpdateDropdown(wndHandler:GetText())
end

function HousingLandscape:HelperOnSortByUpdateDropdown(strDropdownText)
	self.wndLandscape:FindChild("SortByBtn"):SetCheck(false)
	self.wndLandscape:FindChild("SortByList"):Show(false)
	self.wndLandscape:FindChild("SortByBtnLabel"):SetText(strDropdownText)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnHousingButtonLandscape()
    if not self.wndLandscape:IsVisible() then
		self:ResetAll()
		self.wndLandscape:Show(true)
        HousingLib.RequestVendorList()
        HousingLib.RefreshUI()
        self.wndLandscape:ToFront()
		Apollo.StartTimer("PlotDetailRefreshTimer")
		Event_ShowTutorial(GameLib.CodeEnumTutorial.Housing_Landscape)
	else
	    self:OnCloseHousingLandscapeWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnHousingButtonCrate()
	if self.wndLandscape:IsVisible() then
		self:OnCloseHousingLandscapeWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnHousingButtonList()
	if self.wndLandscape:IsVisible() then
		self:OnCloseHousingLandscapeWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnHousingButtonRemodel()
	if self.wndLandscape:IsVisible() then
		self:OnCloseHousingLandscapeWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnCancelReplace(wndHandler, wndControl)
    self:PlaceNewPlug(false)
	self:ResetPopups()
	self.wndLandscape:Show(true)	
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnBuyBtn(wndControl, wndHandler)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	
	Sound.Play(Sound.PlayUIHousingHardwareFinalized)
	Sound.Play(Sound.PlayUI16BuyVirtual)

	--local bUserConfirmed = false
	self:PlaceNewPlug(false)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPlaceBtn(wndControl, wndHandler)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	
	Sound.Play(Sound.PlayUIHousingHardwareFinalized)
	Sound.Play(Sound.PlayUI16BuyVirtual)

	--local bUserConfirmed = false
	self:PlaceNewPlug(false)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnReplaceBtn(wndControl, wndHandler)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	
	Sound.Play(Sound.PlayUIHousingHardwareFinalized)
	Sound.Play(Sound.PlayUI16BuyVirtual)

	--local bUserConfirmed = false
	self:PlaceNewPlug(false)
end

--------------------------------------------------------------------------------------------------
function HousingLandscape:OnCancelBtn(wndControl, wndHandler)
    Sound.Play(Sound.PlayUIHousingItemCancelled)
    self:OnCloseHousingLandscapeWindow()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnDeleteBtn(wndControl, wndHandler)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	self:ResetPopups()
	self.wndRemovePopup = Apollo.LoadForm(self.xmlDoc, "PopupRemove", nil, self)
	self.wndRemovePopup:Show(true)	
	self.wndRemovePopup:ToFront()
	self.wndLandscape:Show(false)
end

function HousingLandscape:OnRemoveDestroy()
	self:RemoveCurrentPlug()
	self:ResetPopups()
	self.wndLandscape:Show(true)
	self.bHasChanged = true
end

function HousingLandscape:OnRemoveCancel()
	self:ResetPopups()
	self.wndLandscape:Show(true)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnClosePlugInfoBtn(wndControl, wndHandler)
	self.wndPlugInfoFrame:Show(false)
end
---------------------------------------------------------------------------------------------------
function HousingLandscape:OnUpgradeBtn(wndControl, wndHandler)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	
	if self.wndPlugInfoFrame:IsShown() and self.wndPlugInfoFrame:FindChild("UpgradePlugFrame"):IsShown()then
		self.wndPlugInfoFrame:Show(false)
		return
	end
	
	local iPlot = GetSelectedPlotIndex()
    local tUpgrade = HousingLib.GetPlugUpgradeList(iPlot)
	
	local tPlug = HousingLib.GetPlot(iPlot)
	local idPlugItem = tPlug.nPlugItemId
    local tItemList = HousingLib.GetPlugItem(idPlugItem)
    local tOldItemData = self:GetItem(idPlugItem, tItemList)
	
	local bHasUpgrade = false
	self.wndPlugInfoFrame:FindChild("ViewPlugInfoFrame"):Show(false)
	for idx = 1, #tUpgrade do --will show incorrectly if there's ever more than one in the table
		local tItemData = tUpgrade[idx]
		if self:SelectionMatches(tItemData.eType) then
			bHasUpgrade = true
			self:DrawTierUpgradeInfo(tItemData, tOldItemData)
		end
	end
	
	self.wndPlugInfoFrame:Show(bHasUpgrade)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnRotateBtn(wndHandler, wndControl)
	self:ResetPopups()
	
	local iPlot = GetSelectedPlotIndex()
	local tPlotInfo = HousingLib.GetPlot(iPlot)
	self.eCurrPlotFacing = tPlotInfo.ePlugFacing
	self:RotateWndUpdateFacing()
	
	self.wndRotatePopup = Apollo.LoadForm(self.xmlDoc, "PopupRotate", nil, self)
	self.wndRotatePopup:Show(true)
	self.wndRotatePopup:ToFront()
	self.wndLandscape:Show(false)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnRotateRightBtn(wndHandler, wndControl, eMouseButton)

	if self.luaLandscapeCurrentControl.ePlotSelectionType == LuaEnumPlotType.HousingPlot1x2 then
		if self.eCurrPlotFacing == HousingLib.HousingPlugFacing.West then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.East
		else 
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.West
		end
	else
		if self.eCurrPlotFacing == HousingLib.HousingPlugFacing.North then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.East
		elseif self.eCurrPlotFacing == HousingLib.HousingPlugFacing.East then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.South
		elseif self.eCurrPlotFacing == HousingLib.HousingPlugFacing.South then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.West
		elseif self.eCurrPlotFacing == HousingLib.HousingPlugFacing.West then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.North
		end
	end
	
	self:RotateWndUpdateFacing()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnRotateLeftBtn(wndHandler, wndControl, eMouseButton)
	--Could we turn facings into a bit field and shift them?
	if self.luaLandscapeCurrentControl.ePlotSelectionType == LuaEnumPlotType.HousingPlot1x2 then
		if self.eCurrPlotFacing == HousingLib.HousingPlugFacing.West then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.East
		else 
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.West
		end
	else
		if self.eCurrPlotFacing == HousingLib.HousingPlugFacing.North then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.West
		elseif self.eCurrPlotFacing == HousingLib.HousingPlugFacing.West then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.South
		elseif self.eCurrPlotFacing == HousingLib.HousingPlugFacing.South then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.East
		elseif self.eCurrPlotFacing == HousingLib.HousingPlugFacing.East then
			self.eCurrPlotFacing = HousingLib.HousingPlugFacing.North
		end	
	end

	self:RotateWndUpdateFacing()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnRotatePlace(wndHandler, wndControl, eMouseButton)
	self:ResetPopups()
	
	local iPlot = GetSelectedPlotIndex()
	local tPlotInfo = HousingLib.GetPlot(iPlot)
	if tPlotInfo ~= nil then
		local idPlugItem = tPlotInfo.nPlugItemId

		HousingLib.SetPlugRotation(iPlot, idPlugItem, self.eCurrPlotFacing)
	end
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnRotateCancel(wndHandler, wndControl, eMouseButton)
	self:ResetPopups()
	self.wndLandscape:Show(true)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:RotateWndUpdateFacing()
	
	local strPlotType = ""
	if self.luaLandscapeCurrentControl.ePlotSelectionType == LuaEnumPlotType.HousingPlot2x2 then
		self.wndRotatePopup:FindChild("Plot2x2"):Show(true)
		self.wndRotatePopup:FindChild("Plot1x2"):Show(false)
		self.wndRotatePopup:FindChild("Plot1x1"):Show(false)
		strPlotType = "Plot2x2"
	elseif self.luaLandscapeCurrentControl.ePlotSelectionType == LuaEnumPlotType.HousingPlot1x2 then
		self.wndRotatePopup:FindChild("Plot2x2"):Show(false)
		self.wndRotatePopup:FindChild("Plot1x2"):Show(true)
		self.wndRotatePopup:FindChild("Plot1x1"):Show(false)
		strPlotType = "Plot1x2"
	else
		self.wndRotatePopup:FindChild("Plot2x2"):Show(false)
		self.wndRotatePopup:FindChild("Plot1x2"):Show(false)
		self.wndRotatePopup:FindChild("Plot1x1"):Show(true)
		strPlotType = "Plot1x1"
	end
	
	local tFacingSprites = 
	{ 
		[HousingLib.HousingPlugFacing.North] 	= "FacingSpriteN", 
		[HousingLib.HousingPlugFacing.South] 	= "FacingSpriteS", 
		[HousingLib.HousingPlugFacing.East] 	= "FacingSpriteE", 
		[HousingLib.HousingPlugFacing.West] 	= "FacingSpriteW" 
	}
	
	for idx, strSprite in pairs (tFacingSprites) do
		local bEnable = idx == (self.eCurrPlotFacing)
		-- 1x2 plots can only rotate E/W
		if idx < 3 and self.luaLandscapeCurrentControl.ePlotSelectionType == LuaEnumPlotType.HousingPlot1x2 then
			enable = false
		end
		
		self.wndRotatePopup:FindChild(strPlotType):FindChild(tFacingSprites[idx]):Show(bEnable)
	end
end

---------------------------------------------------------------------------------------------------
 function HousingLandscape:OnViewBtn(wndControl, wndHandler)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	if self.wndPlugInfoFrame:IsShown() and self.wndPlugInfoFrame:FindChild("ViewPlugInfoFrame"):IsShown() then
		self.wndPlugInfoFrame:Show(false)
	else
		if self.bHasChanged then
			local iPlot = GetSelectedPlotIndex()
			self:DrawInfo(iPlot, self.luaLandscapeCurrentControl.ePlotSelectionType)
			self.bHasChanged = false
		end
		self.wndPlugInfoFrame:Show(true)
		self.wndPlugInfoFrame:FindChild("UpgradePlugFrame"):Show(false)
		self.wndPlugInfoFrame:FindChild("ViewPlugInfoFrame"):Show(true)
	end
 end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnCancelRepairBtn(wndControl, wndHandler)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

    self.wndLandscape:Show(true)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnRepairConfirmBtn(wndControl, wndHandler)
    local iPlot = GetSelectedPlotIndex()
    HousingLib.RepairPlot(iPlot)
    
    self.wndLandscape:Show(true)
	self.wndPlugInfoFrame:FindChild("InfoRepairBtn"):Enable(false)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:HelperTogglePreview(bShowWnd)
	self.wndTogglePreview:Show(not bShowWnd)
	self.wndPreview:Show(bShowWnd)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPreviewWindowToggleOut(wndHandler, wndCtrl)
	self:HelperTogglePreview(true)
	self.bHidePreview = false
	self:ShowPlugPreviewWindow()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPreviewWindowToggleIn(wndHandler, wndCtrl)
	self:HelperTogglePreview(false)
	self.bHidePreview = true
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPreviewNextBtn()
    self.iCurrScreen = self.iCurrScreen + 1
    if self.iCurrScreen > self.iNumScreenshots then
        self.iCurrScreen = 1
    end
    
    self:DrawPreviewScreenshot()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPreviewPrevBtn()
    self.iCurrScreen = self.iCurrScreen - 1
    if self.iCurrScreen < 1 then
        self.iCurrScreen = self.iNumScreenshots
    end
    
    self:DrawPreviewScreenshot()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:DrawPreviewScreenshot()
    local tPlugItemData = self:GetItem(self.iCurrPrevPlugItemId, self.tVendorItemsLandscape)	
    if self.iNumScreenshots > 0 and tPlugItemData ~= nil then
        local tSpriteList = tPlugItemData.tScreenshots
        local strSprite = tSpriteList[self.iCurrScreen].strSprite
        self.wndPreview:FindChild("Screenshot01"):SetSprite("ClientSprites:"..strSprite)
    else
        self.wndPreview:FindChild("Screenshot01"):SetSprite("")
    end
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:ShowPlugPreviewWindow()
    -- don't do any of this if the Housing List isn't visible
	if self.wndPreview:IsVisible() then
	    local tPlugItemData = self:GetItem(self.iCurrPrevPlugItemId, self.tVendorItemsLandscape)
	    if tPlugItemData == nil then
	        return
	    end    
	    
		self.iNumScreenshots = #tPlugItemData.tScreenshots
	    self.iCurrScreen = 1

        if self.iNumScreenshots > 1 then
            self.wndPreview:FindChild("PrevButton"):Enable(true)
            self.wndPreview:FindChild("NextButton"):Enable(true)
        else
            self.wndPreview:FindChild("PrevButton"):Enable(false)
            self.wndPreview:FindChild("NextButton"):Enable(false)
        end
	    
	    self:DrawPreviewScreenshot()
		return
	end
	
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWindowClosed()
	-- called after the window is closed by:
	--	self.OnCloseHousingLandscapeWindow() or 
	--  hitting ESC or
	--  C++ calling Event_CloseHousingLandscapeWindow()
	
	-- popup windows reset
	self:ResetPopups()
	
	self.wndSearch:SetText("")
	self.wndClearSearchBtn:Show(false)
	self.wndTogglePreview:Enable(false)
	
	Sound.Play(Sound.PlayUIWindowClose)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnCloseHousingLandscapeWindow()
	-- close the window which will trigger OnWindowClosed
	
	self.wndLandscape:Close()
	self:ResetPopups()
	Apollo.StopTimer("PlotDetailRefreshTimer")
	self.tVendorItemsLandscape = nil
	self:DestroyCategoryList()
	self:ResetAll()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnReplaceOldDestroy(wndHandler, wndControl)
	local bUserConfirmed = true
	self:PlaceNewPlug(bUserConfirmed)
	self:ResetPopups()
	self.wndLandscape:Show(true)	
	self.bHasChanged = true
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnReplaceOldPack(wndHandler, wndControl)
	local bUserConfirmed = true
	self:PackCurrentPlug()	-- pack old plug
	self:PlaceNewPlug(bUserConfirmed) -- place new
	--self.wndCrateUnderPopup:Show(false)
	self:ResetPopups()
	self.wndLandscape:Show(true)
	self.bHasChanged = true	
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnAffordOnlyToggle(wndHandler, wndControl)
    self.wndSearch:ClearFocus()
	self:OnSearchChanged()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnLandscapeListItemChanged(wndHandler, wndControl, nX, nY) 
	if wndControl ~= wndHandler then
		return
	end
	
	local idItem = wndControl:GetData()
	self.iCurrPrevPlugItemId = idItem
	
	if idItem == nil then 
		return 
	end
	
	self.wndTogglePreview:Enable(true)
	self:HelperTogglePreview(not self.bHidePreview)
    self:ShowPlugPreviewWindow()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnLandscapeListItemCheck(wndHandler, wndControl, nX, nY) 
    self.wndSearch:ClearFocus()

	if wndControl ~= wndHandler then
		return
	end
	
	local idItem = wndControl:GetData()
	self.iCurrPrevPlugItemId = idItem
	
	if idItem == nil then 
		return 
	end
	
	if not wndControl:IsChecked() then -- unselected
		local nWndLeft, nWndTop, nWndRight, nWndBottom = wndControl:GetAnchorOffsets()
		wndControl:SetAnchorOffsets(nWndLeft, nWndTop, nWndRight, nWndTop + knDefaultEntryHieght)
		wndControl:FindChild("Title"):SetFont("CRB_InterfaceMedium_B")
		wndControl:FindChild("Title"):SetTextColor(self:HelperChooseTitleColor(self:GetItem(idItem, self.tVendorItemsLandscape)))
		wndControl:FindChild("CostComplex"):Show(false)
		wndControl:FindChild("PlugPrereqs"):SetText("")
		wndControl:FindChild("PlugFlags"):SetText("")
		wndControl:FindChild("PlugDescription"):SetText("")
		self.wndStructureList:ArrangeChildrenVert()		
		self.idUniqueItem = nil 
		self.luaLandscapeProposedControl:clear()
		return
	end
	
	local wndCurrent = nil
	
	for idx, wndEntry in pairs(self.tLandscapeEntries) do
		if wndEntry:IsChecked() and wndEntry:GetData() ~= idItem then
			wndEntry:SetCheck(false)
			local nLeft, nTop, nRight, nBottom = wndEntry:GetAnchorOffsets()
			wndEntry:SetAnchorOffsets(nLeft, nTop, nRight, nTop + knDefaultEntryHieght)
			wndEntry:FindChild("Title"):SetFont("CRB_InterfaceMedium_B")
			wndEntry:FindChild("Title"):SetTextColor(self:HelperChooseTitleColor(self:GetItem(wndEntry:GetData(), self.tVendorItemsLandscape )))			
			wndEntry:FindChild("CostComplex"):Show(false)
			wndEntry:FindChild("PlugPrereqs"):SetText("")
			wndEntry:FindChild("PlugFlags"):SetText("")
			wndEntry:FindChild("PlugDescription"):SetText("")
		elseif wndEntry:IsChecked() and wndEntry:GetData() == idItem then
			wndEntry:SetCheck(true)
			wndCurrent = wndEntry
			wndEntry:FindChild("Title"):SetFont("CRB_InterfaceMedium_B")
			wndEntry:FindChild("Title"):SetTextColor(self:HelperChooseTitleColor(self:GetItem(wndEntry:GetData(), self.tVendorItemsLandscape )))			
		end
	end
	
	self.idUniqueItem = idItem

	-- Formatting of the button/info begins here
	if wndCurrent == nil then 
		return 
	end

	local nPadding = 3 -- how much vert padding between entries
	local tItemData = self:GetItem(idItem, self.tVendorItemsLandscape )
	
	wndCurrent:FindChild("PlugDescriptionFrame:PlugDescription"):SetText(tItemData.strTooltip)
	wndCurrent:FindChild("PlugDescriptionFrame:PlugDescription"):SetHeightToContentHeight(20) -- will be 0 if no text
	--wndCurrent:FindChild("PlugDescriptionFrame"):RecalculateContentExtents()
	local nLeft1, nTop1, nRight1, nBottom1 = wndCurrent:FindChild("PlugDescription"):GetAnchorOffsets()


	-- Pre-reqs
	local wndPrereq = wndCurrent:FindChild("PlugPrereqs")
	local strPrereq = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_BtnTextGreenNormal\">%s</T>", Apollo.GetString("HousingLandscape_Requirements"))
	if #tItemData.tPrerequisites > 0 then
		local strPrereqList = ""
		local nCount = 0
		
		local strColor = "UI_TextHoloTitle"	
		if tItemData ~= nil then
			if not tItemData.bAreCostRequirementsMet then
				strColor = "xkcdReddish"	
			end	
		end	
			
        for idx, tPrereq in ipairs(tItemData.tPrerequisites) do
            if nCount > 0 then
				strPrereqList = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strColor , String_GetWeaselString(Apollo.GetString("Archive_TextList"), strPrereqList, tPrereq.strTooltip))
			else
				strPrereqList = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strColor , tPrereq.strTooltip)
			end
			nCount = nCount + 1
        end
		strPrereq = String_GetWeaselString(strPrereq, strPrereqList)
        wndPrereq:SetText(strPrereq)
	end
	
	wndPrereq:SetHeightToContentHeight() -- will be 0 if no text
	local nLeft2, nTop2, nRight2, nBottom2 = wndPrereq:GetAnchorOffsets()
	
	if wndPrereq:GetHeight() > 0 then
		wndPrereq:SetAnchorOffsets(nLeft2, nBottom1 + nPadding, nRight2, nBottom1 + (nBottom2 - nTop2) + nPadding)
	else
		wndPrereq:SetAnchorOffsets(nLeft2, nBottom1, nRight2, nBottom1)
	end

	nLeft2, nTop2, nRight2, nBottom2 = wndPrereq:GetAnchorOffsets()
	
	-- Flags
	local wndFlags = wndCurrent:FindChild("PlugFlags")
	if tItemData.tFlags.bIsUnique then
		wndFlags:SetFont("CRB_InterfaceSmall")
		wndFlags:SetTextColor(kcrEnabledColor)
		local nPlots = HousingLib.GetPlotCount()
		for idx = 1, nPlots do
			local tPlotInfo = HousingLib.GetPlot(idx)
			if tPlotInfo.nPlugItemId == tItemData.nId then
				wndFlags:SetTextColor(kcrDisabledColor)
			end
		end
		wndFlags:SetText(Apollo.GetString("HousingLandscape_Unique"))
	elseif tItemData.tFlags.bIsUniqueHarvest then
		wndFlags:SetFont("CRB_InterfaceSmall")
		wndFlags:SetTextColor(kcrEnabledColor)
		local nPlots = HousingLib.GetPlotCount()
		for idx = 1, nPlots do
			local tPlotInfo = HousingLib.GetPlot(idx)
			local idPlugItem = tPlotInfo.nPlugItemId
			local tPlugItems = HousingLib.GetPlugItem(idPlugItem)
			local tPlugItemData = self:GetItem(idPlugItem, tPlugItems)
			if tPlugItemData ~= nil then
				local tPlugFlags = tPlugItemData.tFlags
				if tPlugFlags.bIsUniqueHarvest then
					wndFlags:SetTextColor(kcrDisabledColor)
				end
			end
		end
		wndFlags:SetText(Apollo.GetString("HousingLandscape_HarvestFlag"))
	elseif tItemData.tFlags.bIsUniqueGarden then
		wndFlags:SetFont("CRB_InterfaceSmall")
		wndFlags:SetTextColor(kcrEnabledColor)
		local nPlots = HousingLib.GetPlotCount()
		for idx = 1, nPlots do
			local tPlotInfo = HousingLib.GetPlot(idx)
			local idPlugItem = tPlotInfo.nPlugItemId
			local tPlugItems = HousingLib.GetPlugItem(idPlugItem)
			local tPlugItemData = self:GetItem(idPlugItem, tPlugItems)
			if tPlugItemData ~= nil then
				local tPlugFlags = tPlugItemData.tFlags
				if tPlugFlags.bIsUniqueGarden then
					wndFlags:SetTextColor(kcrDisabledColor)
				end
			end
		end
		wndFlags:SetText(Apollo.GetString("HousingLandscape_Unique"))
	end
	
	wndFlags:SetHeightToContentHeight() -- will be 0 if no text
	local nLeft3, nTop3, nRight3, nBottom3 = wndFlags:GetAnchorOffsets()
	
	if wndFlags:GetHeight() > 0 then
		wndFlags:SetAnchorOffsets(nLeft3, nBottom2 + nPadding, nRight3, nBottom2 + (nBottom3 - nTop3) + nPadding)
	else
		wndFlags:SetAnchorOffsets(nLeft3, nBottom2, nRight3, nBottom2)
	end

	nLeft3, nTop3, nRight3, nBottom3 = wndFlags:GetAnchorOffsets()	

	local nCostCount = 0
	local nCostEntryHeight = 0
	local wndCost = wndCurrent:FindChild("CostComplex")

	for idx, tCost in ipairs(tItemData.tCostRequirements) do
	    local wndMoney = Apollo.LoadForm(self.xmlDoc, "CostEntry", wndCost:FindChild("CostEntryContainer"), self)
		nCostCount = nCostCount + 1
		nCostEntryHeight = wndMoney:GetHeight()

	    if tCost.eType == 1 then -- cash
	        wndMoney:FindChild("ItemLabel"):Show(false)
	        wndMoney:FindChild("SourceIcon"):Show(true)
	        wndMoney:FindChild("CashWindow"):Show(true)
	        wndMoney:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.Credits, tCost.nRequiredCost)
	        wndMoney:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
	        wndMoney:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndMoney:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)

			if tCost.nRequiredCost > GameLib.GetPlayerCurrency():GetAmount() then
				wndMoney:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
			end
			
	    elseif tCost.eType == 2 and tCost.itemCostReq ~= nil then -- item
	        wndMoney:FindChild("CashWindow"):Show(false)
	        wndMoney:FindChild("SourceIcon"):Show(true)
	        wndMoney:FindChild("ItemLabel"):Show(true)
	        wndMoney:FindChild("ItemLabel"):SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_ItemCostLabel"), tCost.nRequiredCost, tCost.itemCostReq:GetName()))
            wndMoney:FindChild("SourceIcon"):SetSprite(tCost.itemCostReq:GetIcon())
            wndMoney:FindChild("SourceIcon"):SetItemInfo(tCost.itemCostReq, tCost.nRequiredCost)
			wndMoney:FindChild("ItemLabel"):SetTextColor(kcrEnabledColor)
			
			if tCost.nAvailableCount ~= nil and tCost.nAvailableCount < tCost.nRequiredCost then
				wndMoney:FindChild("ItemLabel"):SetTextColor(kcrDisabledColor)
				wndMoney:FindChild("ItemLabel"):SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_ItemCostBackpack"), tCost.nAvailableCount, tCost.nRequiredCost, tCost.itemCostReq:GetName()))
			end
			
        elseif tCost.eType == 3 then -- other currency			
	        wndMoney:FindChild("ItemLabel"):Show(false)
	        wndMoney:FindChild("SourceIcon"):Show(true)
	        wndMoney:FindChild("CashWindow"):Show(true)
	        wndMoney:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.Renown, tCost.nRequiredCost)
	        wndMoney:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.Renown)
	        wndMoney:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndMoney:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)
			
			if tCost.nRequiredCost > GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount() then
				wndMoney:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
			end			
			
        elseif tCost.eType == 4 then -- War Coins			
	        wndMoney:FindChild("ItemLabel"):Show(false)
	        wndMoney:FindChild("SourceIcon"):Show(true)
	        wndMoney:FindChild("CashWindow"):Show(true)
	        wndMoney:FindChild("SourceIcon"):SetMoneyInfo(Money.CodeEnumCurrencyType.GroupCurrency, tCost.nRequiredCost, Money.CodeEnumGroupCurrencyType.WarCoins)
	        wndMoney:FindChild("CashWindow"):SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
	        wndMoney:FindChild("CashWindow"):SetAmount(tCost.nRequiredCost)
			wndMoney:FindChild("CashWindow"):SetTextColor(kcrEnabledColor)
			
			if tCost.nRequiredCost > GetWarCoins() then
				wndMoney:FindChild("CashWindow"):SetTextColor(kcrDisabledColor)
			end			
	    end
	end	
	
	wndCost:FindChild("CostEntryContainer"):ArrangeChildrenVert()
	
	local nLeft4, nTop4, nRight4, nBottom4 = wndCost:GetAnchorOffsets()
	local nLeftDif, nTopDif, nRightDif, nBottomDif = wndCost:FindChild("CostEntryContainer"):GetAnchorOffsets()
	
	if nCostCount > 0 then
		wndCost:Show(true)
		wndCost:SetAnchorOffsets(nLeft4, nBottom3 + nPadding, nRight4, nBottom3 + nPadding + nTopDif + (nCostEntryHeight * nCostCount) - nBottomDif) -- last one is negative
		nLeft4, nTop4, nRight4, nBottom4 = wndCost:GetAnchorOffsets()
	else
		wndCost:Show(false)
		nBottom4 = nBottom3
	end
	
	-- need to send plotInfo in here too - to handle AreResourcesMet()
	local iPlot = GetSelectedPlotIndex()
	self.luaLandscapeProposedControl:set(tItemData, iPlot, 1)
	
	-- window resize, adjust scroller:
	local nWndLeft, nWndTop, nWndRight, nWndBottom = wndCurrent:GetAnchorOffsets()
	wndCurrent:SetAnchorOffsets(nWndLeft, nWndTop, nWndRight, nWndTop + nBottom4)	
	
	self.wndStructureList:ArrangeChildrenVert()
	
	self.wndTogglePreview:Enable(true)
	self:HelperTogglePreview(not self.bHidePreview)
	self:ShowPlugPreviewWindow()
end

function HousingLandscape:OnHousingPlugItemsUpdated()
	
	local iCurrPlot = GetSelectedPlotIndex()

  -- if self.upgradeListDisplayed then
   --     self.vendorItemsLandscape = HousingLib.GetPlugUpgradeList(curPlotIndex)
  --  else
	self.tVendorItemsLandscape = HousingLib.GetVendorList()
	--end
	
	self.tStorageItemsLandscape = HousingLib.GetStorageList()
	
	self.wndSearch:SetText("")
	self.wndClearSearchBtn:Show(false)
	
	self.idUniqueItem = nil

    self.wndTogglePreview:Enable(false)
	self:ShowItemList(self.wndStructureList, self.tVendorItemsLandscape)
	
	self:HelperTogglePreview(false)

	if HousingLib.IsWarplotResidence() then	
        self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, Money.CodeEnumGroupCurrencyType.WarCoins)
		self.wndCashLandscape:SetAmount(GetWarCoins())
		self.wndMaintenanceCost:SetText(String_GetWeaselString(Apollo.GetString("Warparty_TotalBattleMaintenance"), HousingLib.GetWarplotMaintenanceCost()))
	else
        self.wndCashLandscape:SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
		self.wndCashLandscape:SetAmount(GameLib.GetPlayerCurrency())
	end
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnSearchChanged(wndControl, wndHandler)
    if self.wndSearch:GetText() ~= "" then
        self.wndClearSearchBtn:Show(true)
    else
        self.wndClearSearchBtn:Show(false)
    end

    local iCurrPlot = GetSelectedPlotIndex()
   -- if self.upgradeListDisplayed then
    --    decorList = HousingLib.GetPlugUpgradeList(curPlotIndex)
    --else
	local tDecorList = HousingLib.GetVendorList()
	--end
    --self:ShowItems(self.winListView, decorList)
	self:ShowItemList(self.wndStructureList, tDecorList)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnClearSearchText(wndControl, wndHandler)
    self.wndSearch:ClearFocus()
	self.wndSearch:SetText("")
    self:OnSearchChanged(wndControl, wndHandler)
end


---------------------------------------------------------------------------------------------------
function HousingLandscape:ShowItemList(wndList, tItemList)

	local iCurrPlot = GetSelectedPlotIndex()
	
	if wndList ~= nil or iCurrPlot == 0 then
		wndList:DestroyChildren()
		wndList:RecalculateContentExtents()
		self.tLandscapeEntries = {}
	end

	local monPlayerCash = GameLib.GetPlayerCurrency():GetAmount()
	local wndAffordOnly = self.wndLandscape:FindChild("AffordOnlyBtn")
	
	if tItemList == nil or iCurrPlot == 0 then return end

	-- check for, and handle search filters
    local strSearch = Apollo.StringToLower(self.wndSearch:GetText())
    local tFilteredList = {}
    local nFilteredItems = 0 
	local bFiltersOn = false
 
    if strSearch ~= nil and strSearch ~= "" and not strSearch:match("%W") then
		bFiltersOn = true
        for idx = 1, #tItemList do
            local strItemName = Apollo.StringToLower(tItemList[idx].strName)
            if string.find(strItemName,strSearch) ~= nil then
                if not wndAffordOnly:IsChecked() or wndAffordOnly:IsChecked() and tItemList[idx].bAreCostRequirementsMet and self.luaLandscapeProposedControl:IsNotUnique(tItemList[idx], iCurrPlot) then
					nFilteredItems = nFilteredItems + 1
					tFilteredList[nFilteredItems] = tItemList[idx]
				end
            end
        end
	elseif	wndAffordOnly:IsChecked() then
		bFiltersOn = true
        for idx = 1, #tItemList do
            if tItemList[idx].bAreCostRequirementsMet and self.luaLandscapeProposedControl:IsNotUnique(tItemList[idx], iCurrPlot) then
				nFilteredItems = nFilteredItems + 1
				tFilteredList[nFilteredItems] = tItemList[idx]
			end
        end			
    end
		
	if bFiltersOn == true then
		if #tFilteredList > 0 then
			tItemList = tFilteredList
		else
			return
		end
	end
	
	table.sort(tItemList, function(a,b)	return (a.strName < b.strName)	end)

		-- populate the buttons with the tItemData data
	for idx, tItemData in pairs(tItemList) do
		if tItemData and self:SelectionMatches(tItemData.eType) then
			-- this pruneId means we've want to disallow this tItemData 
			local bPruned = false
			local tPrunedPlug = HousingLib.GetPlot(iCurrPlot)
			local idPrunedPlug = tPrunedPlug.nPlugItemId
			local tPrunedItems = HousingLib.GetPlugItem(idPrunedPlug)
			local tPrunedItemData = self:GetItem(idPrunedPlug, tPrunedItems)
			if tPrunedItemData == nil or tPrunedItemData ~= nil and tPrunedItemData.nId ~= tItemData.nId then				
				local wndEntry = Apollo.LoadForm(self.xmlDoc, "HousingLandscapeEntry", wndList, self)
				local nLeft, nTop, nRight, nBottom = wndEntry:GetAnchorOffsets()
				wndEntry:SetAnchorOffsets(nLeft, nTop, nRight, knDefaultEntryHieght)
				wndEntry:FindChild("Title"):SetText(tItemData.strName)

				if not tItemData.bAreCostRequirementsMet or not self.luaLandscapeProposedControl:IsNotUnique(tItemData, iCurrPlot)then
					wndEntry:FindChild("Title"):SetTextColor(kcrDisabledColor) 
				else
					wndEntry:FindChild("Title"):SetTextColor(kcrEnabledColor)
				end		

				wndEntry:SetData(tItemData.nId)
				table.insert(self.tLandscapeEntries, wndEntry)
			end
		end	
	end

	self.idUniqueItem = nil
	self.luaLandscapeProposedControl:clear()		
	wndList:ArrangeChildrenVert()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:HelperChooseTitleColor(tItemData)
	local crColor = kcrEnabledColor
	
	if tItemData ~= nil then
		if not tItemData.bAreCostRequirementsMet then
			crColor = kcrDisabledColor
		end	
	end

	return crColor
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:SelectionMatches(eType)
	if eType == self.luaLandscapeCurrentControl.ePlotSelectionType then
		return true
	end
  
	if self.luaLandscapeCurrentControl.ePlotSelectionType == LuaEnumPlotType.HousingPlot2x2 then
		if eType == 43 or eType == 44 or eType == 45 then -- Various Residence types TODO: These should really be an enum somewhere
			return true
		end
	end
    
	return false
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWarplotSelectionResidence(wndControl, wndHandler, iButton, nX, nY)
	-- should never be called.
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWarplotSelectionTravel(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_WarplotTravel"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)	
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.Warplot1x3Travel)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWarplotSelectionLarge(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_WarplotLarge"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)	
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.Warplot4x3Large)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWarplotSelectionSmall(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_WarplotSmall"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)	
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.Warplot3x2Small)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWarplotSelectionSuper(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_WarplotSuper"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)	
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.Warplot2x3Super)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWarplotSelectionRaid(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_WarplotRaid"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)	
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.Warplot2x3Raid)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnWarplotSelectionVehicle(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_WarplotVehicle"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)	
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.Warplot2x3Vehicle)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPlotSelection1x1(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_1x1Plot"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)	
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.HousingPlot1x1)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPlotSelection2x1(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_2x1Plot"))
	self.wndLandscape:FindChld("ActionPrompt"):Show(false)		
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.HousingPlot2x1)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPlotSelection1x2(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_1x2Plot"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)		
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, LuaEnumPlotType.HousingPlot1x2)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPlotSelection2x2(wndControl, wndHandler, iButton, nX, nY)
	if wndControl ~= wndHandler then
		return 1
	end
	self.wndLandscape:FindChild("CurrentPlotSizeText"):SetText(Apollo.GetString("HousingLandscape_2x2Plot"))
	self.wndLandscape:FindChild("ActionPrompt"):Show(false)		
	self:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY,  LuaEnumPlotType.HousingPlot2x2)
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnPlotSelectionGeneral(wndControl, wndHandler, iButton, nX, nY, eSelectionType)

    self.wndSearch:ClearFocus()
    --self.upgradeListDisplayed = false
	self.wndPlugInfoFrame:Show(true)
	local iPlot = GetSelectedPlotIndex()

	self.luaLandscapeCurrentControl:OnSelectPlot(iPlot, eSelectionType)
	self:DrawInfo(iPlot, eSelectionType)
	self:OnHousingPlugItemsUpdated()
	self:HelperSetPlotlines(iPlot)
	
	-- remember which radio button was just checked
	self.wndCheckedPlotBtn = wndControl
	
	self.luaLandscapeProposedControl:clear()
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:HelperSetPlotlines(iPlot)
	local wndContainer = nil
	local wndButtons = nil
	local nFirstIndex = nil
	local nTotalPlots = nil

	if HousingLib.IsWarplotResidence() then
		nFirstIndex = 2
		nTotalPlots = knTotalWarplots
		wndContainer = self.wndLandscape:FindChild("WarplotGuidelines")
		wndButtons =  self.wndLandscape:FindChild("WarplotLandscapeFrame")
	else
		nFirstIndex = 1
		nTotalPlots = knTotalHousingPlots
		wndContainer = self.wndLandscape:FindChild("PlotGuidelines")
		wndButtons =  self.wndLandscape:FindChild("LandscapeFrame")
	end	
	
	for idx = nFirstIndex, nTotalPlots do
		wndContainer:FindChild("PlotGuidelines_" .. idx):Show(false, true)
		--wndButtons:FindChild("Plot" .. idx):FindChild("Outline"):SetSprite("")
	end
	
	if iPlot ~= nil and iPlot < nTotalPlots then
		wndContainer:FindChild("PlotGuidelines_" .. iPlot):Show(true)
		wndContainer:FindChild("FlashSprite"):SetSprite("WhiteFlash")
		--wndButtons:FindChild("Plot" .. iPlot):FindChild("Outline"):SetSprite("CRB_Anim_Outline:spr_Anim_OutlineStretch")
	else	
		for idx = nFirstIndex, nTotalPlots do
			wndContainer:FindChild("PlotGuidelines_" .. idx):Show(false, true)
			--wndButtons:FindChild("Plot" .. idx):FindChild("Outline"):SetSprite("CRB_Anim_Outline:spr_Anim_OutlineStretch")
		end		
	end
end


---------------------------------------------------------------------------------------------------
function HousingLandscape:GetItem(idItem, tItemlist)
  for idx = 1, #tItemlist do
    local tItemData = tItemlist[idx]
    if tItemData.nId == idItem then
      return tItemData
    end
  end
  return nil
end

-----------------------------------------------------------------------------------------------
-- HousingLandscape Category Dropdown functions
-----------------------------------------------------------------------------------------------
-- populate item list
function HousingLandscape:PopulateCategoryList()
	-- make sure the item list is empty to start with
	self:DestroyCategoryList()
	
	nSortLeft, nSortTop, nSortRight, nSortBottom = self.wndSortByList:GetAnchorOffsets()
	
    -- add 5 items
	for idx = 1, 5 do
        self:AddCategoryItem(idx)
        nItemHeight = self.tCategoryItems[idx]:GetHeight()
	    self.wndSortByList:SetAnchorOffsets(nSortLeft, nSortTop, nSortRight, nSortTop + idx * nItemHeight)
	end
	
	-- now all the iteam are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndSortByList:ArrangeChildrenVert()
end

-- clear the item list
function HousingLandscape:DestroyCategoryList()
	-- destroy all the wnd inside the list
	for idx, wndEntry in ipairs(self.tCategoryItems) do
		wndEntry:Destroy()
	end

	-- clear the list item array
	self.tCategoryItems = {}
end

-- add an item into the item list
function HousingLandscape:AddCategoryItem(idx)
	-- load the window item for the list item
	local wndListItem = Apollo.LoadForm(self.xmlDoc, "CategoryListItem", self.wndSortByList, self)
	
	-- keep track of the window item created
	self.tCategoryItems[idx] = wndListItem

	-- give it a piece of data to refer to 
	local wndItemBtn = wndListItem:FindChild("CategoryBtn")
	if wndItemBtn then -- make sure the text wnd exist
		wndItemBtn:SetText(String_GetWeaselString(Apollo.GetString("HousingLandscape_Type"), idx)) -- set the item wnd's text to "item i"
	end
	wndListItem:SetData(idx)
end

-- when a list item is selected
function HousingLandscape:OnCategoryListItemSelected(wndHandler, wndControl)
    -- make sure the wndControl is valid
    if wndHandler ~= wndControl then
        return
    end
end

---------------------------------------------------------------------------------------------------
function HousingLandscape:OnGenerateTooltip(wndHandler, wndControl, eType, oArg1, oArg2)
	local xml = nil

	if eType == Tooltip.TooltipGenerateType_ItemData then
	    wndControl:SetTooltipDoc(nil)

	    if oArg1 ~= nil then
		    local itemEquipped = oArg1:GetEquippedItemForItemType()

		    Tooltip.GetItemTooltipForm(self, wndControl, oArg1, {bPrimary = true, bSelling = false, itemCompare = itemEquipped}, oArg2)
		    -- Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, false, itemCompare = oArg1}) -- OLD
	    end
	elseif eType == Tooltip.TooltipGenerateType_Reputation then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(oArg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(oArg1:GetMoneyString(), CColor.new(1, 1, 1, 1), "CRB_InterfaceMedium")
		wndControl:SetTooltipDoc(xml)
	end

    if xml then
        wndControl:SetTooltipDoc(xml)
    end
end

-----------------------------------------------------------------------------------------------
-- HousingLandscape Instance
-----------------------------------------------------------------------------------------------
local HousingLandscapeInst = HousingLandscape:new()
HousingLandscapeInst:Init()

function GetSelectedPlotIndex()
	if HousingLib.IsWarplotResidence() then	
		return tonumber(HousingLandscapeInst.wndLandscape:FindChild("WarplotLandscapeFrame"):GetRadioSel("WarplotGroup"))
	else
		return tonumber(HousingLandscapeInst.wndLandscape:FindChild("LandscapeFrame"):GetRadioSel("PlotGroup"))
	end
end

function GetWarCoins()
	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_WarParty then
			return guildCurr:GetWarCoins()
		end
	end
	return 0
end
