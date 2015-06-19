-----------------------------------------------------------------------------------------------
-- Client Lua Script for HousingList
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "HousingLib"
 
-----------------------------------------------------------------------------------------------
-- HousingList Module Definition
-----------------------------------------------------------------------------------------------
local HousingList = {} 

-----------------------------------------------------------------------------------------------
-- global
-----------------------------------------------------------------------------------------------
local gidZone = 0
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function HousingList:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

	-- initialize our variables
	o.wndDecorList 		= nil
	o.wndListView 		= nil
	o.wndRecallButton 	= nil
	o.wndDeleteButton 	= nil
	o.tCategoryItems 	= {}

    return o
end

function HousingList:Init()
    Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- HousingList OnLoad
-----------------------------------------------------------------------------------------------
function HousingList:OnLoad()
    -- Register events
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("HousingButtonList", 				"OnHousingButtonList", self)
	Apollo.RegisterEventHandler("HousingButtonRemodel", 			"OnHousingButtonRemodel", self)
	Apollo.RegisterEventHandler("HousingButtonLandscape", 			"OnHousingButtonLandscape", self)
	Apollo.RegisterEventHandler("HousingButtonCrate", 				"OnHousingButtonCrate", self)
	Apollo.RegisterEventHandler("HousingButtonVendor", 				"OnHousingButtonCrate", self)
	Apollo.RegisterEventHandler("HousingPanelControlOpen", 			"OnOpenPanelControl", self)
	Apollo.RegisterEventHandler("HousingPanelControlClose", 		"OnClosePanelControl", self)
	Apollo.RegisterEventHandler("HousingMyResidenceDecorChanged", 	"OnMyResidenceDecorChanged", self)
	Apollo.RegisterEventHandler("HousingFreePlaceControlClose", 	"OnCloseFreePlaceControl", self)
	Apollo.RegisterEventHandler("HousingDestroyDecorControlOpen", 	"OnOpenDestroyDecorControl", self)
	Apollo.RegisterEventHandler("HousingExitEditMode", 				"OnExitEditMode", self)
	Apollo.RegisterEventHandler("HousingBuildStarted", 				"OnBuildStarted", self)
    
    -- load our forms
    self.xmlDoc = XmlDoc.CreateFromFile("HousingList.xml")
    self.wndDecorList 		= Apollo.LoadForm(self.xmlDoc, "HousingListWindow", nil, self)
	self.wndListView 		= self.wndDecorList:FindChild("StructureList")
	self.wndRecallButton 	= self.wndDecorList:FindChild("RecallBtn")
	self.wndDeleteButton 	= self.wndDecorList:FindChild("DeleteBtn")
	self.wndRecallButton:Enable(false)
	self.wndDeleteButton:Enable(false)
	
	self.wndCrateUnderPopup = Apollo.LoadForm(self.xmlDoc, "PopupCrateUnder", nil, self)
	self.wndCrateUnderPopup:Show(false, true)
	
	HousingLib.RefreshUI()
end

function HousingList:OnWindowManagementReady()
	local strName = string.format("%s: %s", Apollo.GetString("CRB_Housing"), Apollo.GetString("HousingList_Header"))
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndDecorList, strName = strName})
end

-----------------------------------------------------------------------------------------------
-- HousingList Functions
-----------------------------------------------------------------------------------------------

function HousingList:OnHousingButtonList()
    if not self.wndDecorList:IsVisible() then
        self.wndDecorList:Show(true)
        self:ShowHousingListWindow()
        self.wndDecorList:ToFront()
        
		Event_FireGenericEvent("HousingEnterEditMode")
		HousingLib.SetEditMode(true)		
	else
	    self:OnCloseHousingListWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingList:OnHousingButtonCrate()
	if self.wndDecorList:IsVisible() or (self.wndCrateUnderPopup ~= nil and self.wndCrateUnderPopup:IsVisible()) then
		self:OnCloseHousingListWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingList:OnHousingButtonRemodel()
	if self.wndDecorList:IsVisible() or (self.wndCrateUnderPopup ~= nil and self.wndCrateUnderPopup:IsVisible()) then
		self:OnCloseHousingListWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingList:OnHousingButtonLandscape()
	if self.wndDecorList:IsVisible() or (self.wndCrateUnderPopup ~= nil and self.wndCrateUnderPopup:IsVisible()) then
		self:OnCloseHousingListWindow()
	end
end	

---------------------------------------------------------------------------------------------------
function HousingList:OnExitEditMode()
	if self.wndDecorList:IsVisible() then
		self:OnCloseHousingListWindow()
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:OnBuildStarted(plotIndex)
	if plotIndex == 1 and self.wndDecorList:IsVisible() then
		self:OnCloseHousingListWindow()
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:OnOpenPanelControl(idPropertyInfo, idZone, bPlayerIsInside)
	if self.bPlayerIsInside ~= bPlayerIsInside and HousingLib.IsHousingWorld() then
		self:OnCloseHousingListWindow()
	end	

	gidZone = idZone
	self.idPropertyInfo = idPropertyInfo
	self.bPlayerIsInside = bPlayerIsInside == true --make sure we get true/false
	self.bIsWarplot = HousingLib.IsWarplotResidence()
end

---------------------------------------------------------------------------------------------------
function HousingList:ResetPopups()
    if self.wndCrateUnderPopup ~= nil then
	    self.wndCrateUnderPopup:Destroy()
	    self.wndCrateUnderPopup = nil
	end    
end

---------------------------------------------------------------------------------------------------
function HousingList:OnConfirmCrateAll(wndControl, wndHandler)
    Sound.Play(Sound.PlayUIHousingCrateItem)
	HousingLib.CrateAllDecor()
    self:CancelPreviewDecor(true)
    Event_FireGenericEvent("HousingDeactivateDecorIcon", self.nPreviewDecorHandle)
    Event_FireGenericEvent("HousingFreePlaceControlClose", self.nPreviewDecorHandle)
    self:ShowHousingListWindow()
    self:OnCloseHousingListWindow()
end

---------------------------------------------------------------------------------------------------
function HousingList:OnCancelCrateAll(wndControl, wndHandler)
    self.wndDecorList:Show(true)
    self:ResetPopups()
end

---------------------------------------------------------------------------------------------------
function HousingList:OnDecoratePreview(wndControl, wndHandler)
	local nRow = self.wndListView:GetCurrentRow() 
	local tItemData = self.wndListView:GetCellData(nRow, 1)
	local idLow = tItemData.nDecorId
	local idHi = tItemData.nDecorIdHi
	
	-- remove any existing preview decor
	if self.nPreviewDecorHandle ~= 0 then
	    HousingLib.FreePlaceDecorDisplacement_Cancel(self.nPreviewDecorHandle)
	end

	self:CancelPreviewDecor(false)

	local nItemHandle = HousingLib.PreviewPlacedDecor(idLow, idHi)
	if nItemHandle ~= nil and nItemHandle ~= 0 then
	    if self.bPlayerIsInside then
	        Event_FireGenericEvent("HousingFreePlaceDecorQuery", nItemHandle, true, HousingLib.CodeEnumDecorHookType.FreePlace)
		elseif self.bIsWarplot then
	        Event_FireGenericEvent("HousingFreePlaceDecorQuery", nItemHandle, true, HousingLib.CodeEnumDecorHookType.WarplotFreePlace)
	    else
	        Event_FireGenericEvent("HousingFreePlaceDecorQuery", nItemHandle, false, tItemData.eHookType)
	    end
		Sound.Play(Sound.PlayUIHousingHardwareAddition)
		self.nPreviewDecorHandle = nItemHandle
		self.wndRecallButton:Enable(true)
		self.wndDeleteButton:Enable(HousingLib:IsOnMyResidence())
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:CancelPreviewDecor(bRemoveFromWorld)
	if bRemoveFromWorld and self.nPreviewDecorHandle ~= 0 then
		HousingLib.FreePlaceDecorDisplacement_Cancel(self.nPreviewDecorHandle)
	end
	
	self.nPreviewDecorHandle = 0
	
	self.wndRecallButton:Enable(false)
	self.wndDeleteButton:Enable(false)
end

---------------------------------------------------------------------------------------------------
function HousingList:OnRecallBtn(wndControl, wndHandler)
    if self.nPreviewDecorHandle ~= 0 then
        self:CrateDecorItem(self.nPreviewDecorHandle)
        self:CancelPreviewDecor(true)
        Event_FireGenericEvent("HousingDeactivateDecorIcon", self.nPreviewDecorHandle)
        Event_FireGenericEvent("HousingFreePlaceControlClose", self.nPreviewDecorHandle)
        self:ShowHousingListWindow()
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:OnRecallAllBtn(wndControl, wndHandler)
    self:ResetPopups()
    self.wndCrateUnderPopup = Apollo.LoadForm(self.xmlDoc, "PopupCrateUnder", nil, self)
    self.wndCrateUnderPopup:Show(true)
    self.wndCrateUnderPopup:ToFront()
    self.wndDecorList:Show(false)
end

---------------------------------------------------------------------------------------------------
function HousingList:OnPlaceBtn(wndControl, wndHandler)

	HousingLib.PlaceDecorFromCrate(self.nPreviewDecorHandle)
	Sound.Play(Sound.PlayUIHousingHardwareFinalized)
	Sound.Play(Sound.PlayUI16BuyVirtual)

	self:CancelPreviewDecor(false)
end

---------------------------------------------------------------------------------------------------
function HousingList:OnDeleteBtn(wndControl, wndHandler)
	if self.nPreviewDecorHandle ~= 0 then
	    Event_FireGenericEvent("HousingDestroyDecorControlOpen2", self.nPreviewDecorHandle)
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:OnWindowClosed()
	-- called after the window is closed by:
	--	self.winMasterCustomizeFrame:Close() or 
	--  hitting ESC or
	--  C++ calling Event_CloseHousingListWindow()
	
	-- any preview decorItems reset
	self:CancelPreviewDecor(false)
	self.wndRecallButton:Enable(false)
	self.wndDeleteButton:Enable(false)
	self.tDecorList = nil
	
	Sound.Play(Sound.PlayUIWindowClose)
end

---------------------------------------------------------------------------------------------------
function HousingList:OnCloseHousingListWindow()
	-- close the window which will trigger OnWindowClosed
	self:ResetPopups()
	self.wndDecorList:Close()
end

---------------------------------------------------------------------------------------------------
function HousingList:ShowHousingListWindow()
    -- don't do any of this if the Housing List isn't visible
	if not self.wndDecorList:IsVisible() then
		return
	end
	
    -- Find a list of all placed decor items
    self.tDecorList = (self.bIsWarplot and HousingLib.GetPlacedDecorListWarplot()) or HousingLib.GetPlacedDecorList()
    self:ShowItems(self.wndListView, self.tDecorList, 0)
	
	-- remove any existing preview decor
	self:CancelPreviewDecor(false)
end
	
---------------------------------------------------------------------------------------------------
function HousingList:CrateDecorItem(nDecorHandle)
	if nDecorHandle ~= 0 then
		Sound.Play(Sound.PlayUIHousingCrateItem)
		HousingLib.CrateDecor(nDecorHandle)
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:OnMyResidenceDecorChanged(eDecorType)
	if not self.wndDecorList:IsVisible() then
		return
	end
	
	-- we don't need to do anything on decorations (and since they are numerous messages, bail!)
	if eDecorType == kDecorType_HookDecor then
		return
	end

	-- refresh the UI
	self:ShowHousingListWindow()

	-- remove any existing preview decor
	self:CancelPreviewDecor(false)
 end
 

---------------------------------------------------------------------------------------------------
-- DecorateItemList Functions
---------------------------------------------------------------------------------------------------
function HousingList:OnDecorateListItemChange(wndControl, wndHandler, nX, nY)
	-- Preview the selected item
	local nRow = wndControl:GetCurrentRow()
	if nRow ~= nil then
		self:OnDecoratePreview(wndControl, wndHandler)
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:ShowItems(wndListControl, tItemList, idPrune)
	if wndListControl ~= nil then
		wndListControl:DeleteAll()
	end

	if tItemList ~= nil then

	    -- Here we have an example of a nameless function being declared within another function's parameter list!
		table.sort(tItemList, function(a,b)	return (a.strName < b.strName)	end)

		-- populate the buttons with the item data
		for idx = 1, #tItemList do
	
			local tItemData = tItemList[idx]
			--if self:SelectionMatches(item["type"]) then
			
				-- AddRow implicitly works on column one.  Every column can have it's own hidden data associated with it!
				local idx = wndListControl:AddRow("  " .. tItemData.strName, "", tItemData)
				local bPruned = false

				-- this pruneId means we've want to disallow this item (let's show it as a disabled row) 
				if idPrune == tItemData.nDecorId --[[or gidZone ~= item["zoneId"]--]] then
					--Print("pruneId: " .. pruneId)
					bPruned = true
					wndListControl:EnableRow(idx, false)
				end
				
				--listControl:SetCellData(i, 2, item["zoneId"], "", item["zoneId"])
				
			--end
		end
	end
end

---------------------------------------------------------------------------------------------------
function HousingList:GetItem(idItem, tItemList)
  local idx, idItem
  for idx = 1, #tItemlist do
    tItemData = tItemList[idx]
    if tItemData["decorId"] == idx then
      return tItemData
    end
  end
  return nil
end

-----------------------------------------------------------------------------------------------
-- HousingList Instance
-----------------------------------------------------------------------------------------------
local HousingListInst = HousingList:new()
HousingListInst:Init()
