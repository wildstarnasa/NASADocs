-----------------------------------------------------------------------------------------------
-- Client Lua Script for ResourceConversion
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Tooltip"
require "XmlDoc"
require "Unit"
require "GameLib"

local ResourceConversion = {}
local kTickDuration = .25

local knSaveVersion = 1

function ResourceConversion:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ResourceConversion:Init()
    Apollo.RegisterAddon(self)
end

function ResourceConversion:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSaved = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	
	return tSaved
end

function ResourceConversion:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function ResourceConversion:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ResourceConversion.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function ResourceConversion:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
    Apollo.RegisterEventHandler("ResourceConversionOpen", 	"OnResourceConversionOpen", self)
	Apollo.RegisterEventHandler("UpdateInventory", 			"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("ResourceConversionClose", 	"OnCloseBtn", self)
	
	Apollo.RegisterTimerHandler("ItemIncreaseConversionTimer", "OnItemIncreaseConversionTimer", self)
	Apollo.RegisterTimerHandler("ItemDecreaseConversionTimer", "OnItemDecreaseConversionTimer", self)
	
	self.wndMain = nil
	self.CurrentHandler = nil
end

function ResourceConversion:OnCloseBtn() -- Also WindowClosed and "ResourceConversionClose"
	Event_CancelConverting()
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end
end

function ResourceConversion:OnUpdateInventory()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local nVScrollPos = self.wndMain:FindChild("ConversionContainer"):GetVScrollPos()
	self:OnResourceConversionOpen(self.wndMain:GetData())
	self.wndMain:FindChild("ConversionContainer"):SetVScrollPos(nVScrollPos)
end

function ResourceConversion:OnResourceConversionOpen(unitVendor)
	if self.wndMain then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ResourceConversionForm", nil, self)
	self.wndMain:FindChild("VendorName"):SetText(unitVendor:GetName())
	self.wndMain:SetData(unitVendor)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	-- Get the conversions the vendor has available
	local arVendorConversions = unitVendor:GetResourceConversions()
	
	if arVendorConversions then
		-- sort by availableCount
		table.sort(arVendorConversions , function(a,b) return a.nAvailableCount < b.nAvailableCount end)
		
		for idx, tConversion in ipairs(unitVendor:GetResourceConversions()) do
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "ConversionItem", self.wndMain:FindChild("ConversionContainer"), self)
			wndCurr:FindChild("ConversionLeftEditBox"):SetData(wndCurr)
			wndCurr:FindChild("SliderLeft"):SetData(wndCurr)
			wndCurr:FindChild("SliderRight"):SetData(wndCurr)
			wndCurr:FindChild("ConversionBtn"):SetData(wndCurr)
			wndCurr:FindChild("MainSlider"):SetData(wndCurr)
			wndCurr:SetData(tConversion)
		
			-- left item
			local itemLeft = tConversion.itemSource
			wndCurr:FindChild("ConversionIconLeft"):SetSprite(itemLeft:GetIcon())
			wndCurr:FindChild("ConversionIconLeftText"):SetText(tConversion.nSourceCount)
			self:HelperBuildItemTooltip(wndCurr:FindChild("ConversionIconLeft"), itemLeft)
			
			-- right item
			local strRightItem = ""
			if tConversion.eType == Unit.CodeEnumResourceConversionType.Item2Rep then
				local idReputation = tConversion.idTtarget
				strRightItem = String_GetWeaselString(Apollo.GetString("ResourceConversion_ToRep"), tConversion.strName)
				wndCurr:FindChild("ConversionIconRightText"):SetText(tConversion.nTargetCount)
				wndCurr:FindChild("ConversionIconRight"):SetTooltip(String_GetWeaselString(Apollo.GetString("ResourceConversion_ToRep"), idReputation))
			else
				local itemRight = tConversion.itemTarget
				strRightItem = itemRight:GetName()
				wndCurr:FindChild("ConversionIconRight"):SetSprite(itemRight:GetIcon())
				wndCurr:FindChild("ConversionIconRightText"):SetText(String_GetWeaselString(Apollo.GetString("ResourceConversion_NumInBag"), itemRight:GetBackpackCount()))
				self:HelperBuildItemTooltip(wndCurr:FindChild("ConversionIconRight"), itemRight)
			end
			
			wndCurr:FindChild("MainSlider"):SetMinMax(0, tConversion.nAvailableCount, tConversion.nSourceCount)
			wndCurr:FindChild("MainSlider"):SetValue(0)
			wndCurr:FindChild("ConversionBtn"):Enable(false)
			wndCurr:FindChild("ConversionLeftEditBox"):SetText(0)
			
			-- count 
			local nEmptyInInventory = tConversion.nAvailableCount
			
			if tConversion.nAvailableCount > 0 then
				wndCurr:FindChild("SliderLeft"):Enable(true)
				wndCurr:FindChild("SliderRight"):Enable(true)
				wndCurr:FindChild("ConversionBlockerBlackFillIconContainer"):Show(false)
				wndCurr:FindChild("ConversionBlockerBlackFill"):Show(false)
				wndCurr:FindChild("ConversionItemNames"):SetText(String_GetWeaselString(Apollo.GetString("ResourceConversion_AvailToConvert"), tConversion.nAvailableCount, itemLeft:GetName()))
				wndCurr:FindChild("ConversionItemResult"):SetText("")
			else
				wndCurr:FindChild("SliderLeft"):Enable(false)
				wndCurr:FindChild("SliderRight"):Enable(false)
				wndCurr:FindChild("ConversionBlockerBlackFillIconContainer"):Show(true)
				wndCurr:FindChild("ConversionBlockerBlackFill"):Show(true)
				wndCurr:FindChild("ConversionLeftEditBox"):SetText(0)
				wndCurr:FindChild("ConversionItemNames"):SetTextColor(ApolloColor.new("ff444444"))
				wndCurr:FindChild("ConversionItemNames"):SetText(String_GetWeaselString(Apollo.GetString("ResourceConversion_NotEnough"), itemLeft:GetName()))
				wndCurr:FindChild("ConversionItemResult"):SetText("")
			end
		end
		self.wndMain:FindChild("ConversionContainer"):ArrangeChildrenVert(0)
	end
end

-----------------------------------------------------------------------------------------------
-- Conversion Item Increase/Decrease Buttons
-----------------------------------------------------------------------------------------------
function ResourceConversion:OnItemIncreaseConversionTimer()
	
	local wndParent = self.CurrentHandler:GetData()
	local tConversion = wndParent:GetData()
	local nNumber = tonumber(wndParent:FindChild("ConversionLeftEditBox"):GetText())
	
	local nLeftInterval = 1
	local nRightInterval = 1
	local nRate = tConversion.nSourceCount / tConversion.nTargetCount
	
	if nRate >= 1 then
		nLeftInterval = nRate
	else
		nRightInterval = 1 / nRate
	end
	
	local nValue = 0
	
	if ((nNumber * nLeftInterval) + nLeftInterval) <= tConversion.nAvailableCount then
		nValue = nNumber * nLeftInterval + nLeftInterval
	else
		nValue = tConversion.nAvailableCount * nLeftInterval
	end
	
	self:HelperEditBoxAutoRound(nValue, wndParent)
	
end

function ResourceConversion:OnItemDecreaseConversionTimer()

	local wndParent = self.CurrentHandler:GetData()
	local tConversion = wndParent:GetData()
	local nNumber = tonumber(wndParent:FindChild("ConversionLeftEditBox"):GetText())
	
	local nLeftInterval = 1
	local nRightInterval = 1
	local nRate = tConversion.nSourceCount / tConversion.nTargetCount
	
	if nRate >= 1 then
		nLeftInterval = nRate
	else
		nRightInterval = 1 / nRate
	end
	
	local nValue = 0
	
	if ((nNumber * nLeftInterval) > tConversion.nAvailableCount) then
		nValue = tConversion.nAvailableCount * nLeftInterval
	elseif ((nNumber * nLeftInterval) - nLeftInterval) >= 0 then
		nValue = (nNumber * nLeftInterval) - nLeftInterval
	end
	
	self:HelperEditBoxAutoRound(nValue, wndParent)
	
end

function ResourceConversion:OnConversionAddSubBtn(wndHandler, wndControl)
	wndHandler:SetFocus()
	self.CurrentHandler = wndHandler
	if wndHandler:GetName() == "SliderRight" then
		self:OnItemIncreaseConversionTimer()
		Apollo.CreateTimer("ItemIncreaseConversionTimer", kTickDuration, true)	
	elseif wndHandler:GetName() == "SliderLeft" then
		self:OnItemDecreaseConversionTimer()
		Apollo.CreateTimer("ItemDecreaseConversionTimer", kTickDuration, true)
	end
end

function ResourceConversion:OnConversionAddSubBtnUp(wndHandler, wndControl)
	if wndHandler:GetName() == "SliderRight" then
		Apollo.StopTimer("ItemIncreaseConversionTimer")
	elseif wndHandler:GetName() == "SliderLeft" then
		Apollo.StopTimer("ItemDecreaseConversionTimer")
	end
end

---------------------------------------------------------------------------------------------------
-- Edit Box
---------------------------------------------------------------------------------------------------

function ResourceConversion:OnConversionLeftEditBoxChanged(wndHandler, wndControl, strNew)
	self.CurrentHandler = wndHandler
	self:HelperEditBoxAutoRound(tonumber(strNew), wndHandler:GetData())
	wndHandler:SetSel(string.len(strNew))
end

function ResourceConversion:OnConversionLeftEditBoxReturn(wndHandler, wndControl, strNew)
	self:HelperEditBoxAutoRound(tonumber(strNew), wndHandler:GetData())
	wndHandler:SetFocus()
	wndHandler:SetSel(string.len(strNew))
end

---------------------------------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------------------------------

function ResourceConversion:OnMainSliderChanged(wndHandler, wndControl, strNew) -- MainSlider
	self.CurrentHandler = wndHandler
	wndHandler:SetFocus()
	self:HelperEditBoxAutoRound(tonumber(strNew), wndHandler:GetData())
end

---------------------------------------------------------------------------------------------------
-- Round Helper
---------------------------------------------------------------------------------------------------

function ResourceConversion:HelperEditBoxAutoRound(nEntryValue, wndParent)

	if nEntryValue == nil or nEntryValue == "" or nEntryValue == 0 then
		self:DisplayHelper(wndParent, 0)
		return
	end

	local tConversion = wndParent:GetData()
	local nLeftInterval = 1
	local nRate = tConversion.nSourceCount / tConversion.nTargetCount
	if nRate >= 1 then
		nLeftInterval = nRate
	end

	-- Restrict the entry
	nEntryValue = math.max(nEntryValue, nLeftInterval)
	nEntryValue = math.min(nEntryValue, tConversion.nAvailableCount)
	if nLeftInterval ~= 1 and nEntryValue % nLeftInterval ~= 0 then
		nEntryValue = nEntryValue - (nEntryValue % nLeftInterval)
	end
		
	self:DisplayHelper(wndParent, nEntryValue)
	
end

---------------------------------------------------------------------------------------------------
-- Value Helper
---------------------------------------------------------------------------------------------------

function ResourceConversion:DisplayHelper(wndParent, nValue)

	local tConversion = wndParent:GetData()

	local itemLeft = tConversion.itemSource
	local itemRight = tConversion.itemTarget
	local itemLeftName = itemLeft:GetName()
	
	local nLeftInterval = 1
	local nRightInterval = 1
	local nRate = tConversion.nSourceCount / tConversion.nTargetCount
	
	if nRate >= 1 then
		nLeftInterval = nRate
	else
		nRightInterval = 1 / nRate
	end
	
	if not nValue or nValue == 0 then
		wndParent:FindChild("ConversionItemResult"):SetText("")
		wndParent:FindChild("ConversionBtn"):Enable(false)
		if tConversion.nAvailableCount > 0 then
			wndParent:FindChild("ConversionItemNames"):SetText(String_GetWeaselString(Apollo.GetString("ResourceConversion_AvailToConvert"), tConversion.nAvailableCount, itemLeft:GetName()))
		else
			wndParent:FindChild("ConversionItemNames"):SetText(String_GetWeaselString(Apollo.GetString("ResourceConversion_NotEnough"), itemLeft:GetName()))
		end
	else
		wndParent:FindChild("ConversionBtn"):Enable(true)
		
		local strRightItem = ""
		
		if tConversion.eType == Unit.CodeEnumResourceConversionType.Item2Rep then
			strRightItem = tConversion.strName
		else
			strRightItem = itemRight:GetName()
		end
		wndParent:FindChild("ConversionItemNames"):SetText(String_GetWeaselString(Apollo.GetString("ResourceConversion_Converting"), nValue, tConversion.nAvailableCount, itemLeft:GetName()))
		wndParent:FindChild("ConversionItemResult"):SetText(String_GetWeaselString(Apollo.GetString("ResourceConversion_Result"), nValue * nRightInterval, strRightItem))
	end
	
	wndParent:FindChild("MainSlider"):SetValue(nValue)
	wndParent:FindChild("ConversionLeftEditBox"):SetText(nValue)
	
end
		
---------------------------------------------------------------------------------------------------
-- Conversion Button
---------------------------------------------------------------------------------------------------

function ResourceConversion:OnConversionBtn(wndHandler, wndControl) -- ConversionBtn
	local wndParent = wndHandler:GetData()
	local tConversion = wndParent:GetData()
	local unitVendor = self.wndMain:GetData()
	unitVendor:ConvertResource(tConversion.idConversion, wndParent:FindChild("ConversionLeftEditBox"):GetText())
end

---------------------------------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------------------------------

function ResourceConversion:HelperBuildItemTooltip(wndArg, itemCurr)
	wndArg:SetTooltipDoc(nil)
	wndArg:SetTooltipDocSecondary(nil)
	local itemEquipped = itemCurr:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	if itemCurr then
		Tooltip.GetItemTooltipForm(self, wndArg, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = itemCurr})
	end
end

local ResourceConversionInst = ResourceConversion:new()
ResourceConversionInst:Init()
