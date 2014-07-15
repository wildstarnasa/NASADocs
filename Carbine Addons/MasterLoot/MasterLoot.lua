-----------------------------------------------------------------------------------------------
-- Client Lua Script for Masterloot
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "GroupLib"
require "Item"
require "GameLib"

local MasterLoot = {}

local ktClassToIcon =
{
	[GameLib.CodeEnumClass.Medic]       	= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Esper]       	= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Warrior]     	= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Stalker]     	= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Engineer]    	= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger]  	= "Icon_Windows_UI_CRB_Spellslinger",
}

function MasterLoot:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function MasterLoot:Init()
	Apollo.RegisterAddon(self)
end

function MasterLoot:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MasterLoot.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function MasterLoot:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("MasterLootUpdate",	"OnMasterLootUpdate", self)
	Apollo.RegisterEventHandler("LootAssigned",	"OnLootAssigned", self)
	
	Apollo.RegisterEventHandler("Group_Updated", "OnGroupUpdated", self)
	
	Apollo.RegisterEventHandler("GenericEvent_ToggleGroupBag", "OnToggleGroupBag", self)

	-- Master Looter Window
	self.wndMasterLoot = Apollo.LoadForm(self.xmlDoc, "MasterLootWindow", nil, self)
	self.wndMasterLoot:SetSizingMinimum(550, 310)
	if self.locSavedMasterWindowLoc then
		self.wndMasterLoot:MoveToLocation(self.locSavedMasterWindowLoc)
	end
	self.wndMasterLoot_ItemList = self.wndMasterLoot:FindChild("ItemList")
	self.wndMasterLoot_LooterList = self.wndMasterLoot:FindChild("LooterList")
	self.wndMasterLoot:Show(false)
	
	-- Looter Window
	self.wndLooter = Apollo.LoadForm(self.xmlDoc, "LooterWindow", nil, self)
	if self.locSavedLooterWindowLoc then
		self.wndLooter:MoveToLocation(self.locSavedLooterWindowLoc)
	end
	self.wndLooter_ItemList = self.wndLooter:FindChild("ItemList")
	self.wndLooter:Show(false)
	
	self.tOld_MasterLootList = {}

	-- Master Looter Global Vars
	self.tMasterLootSelectedItem = nil
	self.tMasterLootSelectedLooter = nil

end

----------------------------

-- Generic event from Group or Raid Frame ML Available Button
function MasterLoot:OnToggleGroupBag()
	self:OnMasterLootUpdate(true) -- true makes it force open if we have items
end

----------------------------

function MasterLoot:OnMasterLootUpdate(bForceOpen)
	
	local tMasterLoot = GameLib.GetMasterLoot()
	
	local tMasterLootItemList = {}
	local tLooterItemList = {}
	
	local bWeHaveLoot = false
	local bWeHaveNewLoot = false
	local bLootWasRemoved = false
	local bLootersChanged = false
	
	-- Go through NEW items
	for idxNewItem, tCurNewItem in pairs(tMasterLoot) do
		
		bWeHaveLoot = true
	
		-- Break items out into MasterLooter and Looter lists (which UI displays them)
		if tCurNewItem.bIsMaster then
			table.insert(tMasterLootItemList, tCurNewItem)
		else
			table.insert(tLooterItemList, tCurNewItem)
		end
		
		-- Search through last MasterLootList to see if we got NEW items
		local bFoundItem = false
		for idxOldItem, tCurOldItem in pairs (self.tOld_MasterLootList) do
			if tCurNewItem.nLootId == tCurOldItem.nLootId then -- persistant item
			
				bFoundItem = true
				
				local bNewLooter = false
				local bLostLooter = false
				
				for idxNewLooter, unitNewLooter in pairs (tCurNewItem.tLooters) do
					local bFoundLooter = false
					for idxOldLooter, unitOldLooter in pairs (tCurOldItem.tLooters) do
						if unitNewLooter == unitOldLooter then
							bFoundLooter = true
							break
						end
					end
					if not bFoundLooter then
						bNewLooter = true
						break
					end
				end
				
				if not bNewLooter then
					for idxOldLooter, unitOldLooter in pairs (tCurOldItem.tLooters) do
						local bFoundLooter = false
						for idxNewLooter, unitNewLooter in pairs (tCurNewItem.tLooters) do
							if unitOldLooter == unitNewLooter then
								bFoundLooter = true
								break
							end
						end
						if not bFoundLooter then
							bLostLooter = true
							break
						end
					end
				end
				
				if bNewLooter or bLostLooter then
					bLootersChanged = true
					break
				end
				
			end
		end
		
		if not bFoundItem then
			bWeHaveNewLoot = true
		end
		
	end
	
	-- Go through OLD items
	for idxOldItem, tCurOldItem in pairs (self.tOld_MasterLootList) do
		-- Search through new list to see if we LOST any items
		local bFound = false
		for idxNewItem, tCurNewItem in pairs(tMasterLoot) do
		
			if tCurNewItem.nLootId == tCurOldItem.nLootId then -- persistant item
				bFound = true
				break
			end
		
		end
		if not bFound then
			bLootWasRemoved = true
			break
		end
	end	
	
	self.tOld_MasterLootList = tMasterLoot
	
	if bForceOpen == true and bWeHaveLoot then -- pop window if closed, update open windows
		if next(tMasterLootItemList) then
			self.wndMasterLoot:Show(true)
			self:RefreshMasterLootItemList(tMasterLootItemList)
			self:RefreshMasterLootLooterList(tMasterLootItemList)
		end
		if next(tLooterItemList) then
			self.wndLooter:Show(true)
			self:RefreshLooterItemList(tLooterItemList)
		end
		
	elseif bWeHaveLoot then
		if bWeHaveNewLoot then -- pop window if closed, update open windows
			if next(tMasterLootItemList) then
				self.wndMasterLoot:Show(true)
				self:RefreshMasterLootItemList(tMasterLootItemList)
				self:RefreshMasterLootLooterList(tMasterLootItemList)
			end
			if next(tLooterItemList) then
				self.wndLooter:Show(true)
				self:RefreshLooterItemList(tLooterItemList)
			end
		elseif bLootWasRemoved or bLootersChanged then  -- update open windows
			if self.wndMasterLoot:IsShown() and next(tMasterLootItemList) then
				self:RefreshMasterLootItemList(tMasterLootItemList)
				self:RefreshMasterLootLooterList(tMasterLootItemList)
			end
			if self.wndLooter:IsShown() and next(tLooterItemList) then
				self:RefreshLooterItemList(tLooterItemList)
			end
		end
	else
		-- close any open windows
		if self.wndMasterLoot:IsShown() then
			self.locSavedMasterWindowLoc = self.wndMasterLoot:GetLocation()
			self.tMasterLootSelectedItem = nil
			self.tMasterLootSelectedLooter = nil
			self.wndMasterLoot_ItemList:DestroyChildren()
			self.wndMasterLoot_LooterList:DestroyChildren()
			self.wndMasterLoot:Show(false)
		end
		if self.wndLooter:IsShown() then
			self.locSavedLooterWindowLoc = self.wndLooter:GetLocation()
			self.wndLooter_ItemList:DestroyChildren()
			self.wndLooter:Show(false)
		end
	end
	
	if self.tMasterLootSelectedItem ~= nil and self.tMasterLootSelectedLooter ~= nil then
		self.wndMasterLoot:FindChild("Assignment"):Enable(true)
	else
		self.wndMasterLoot:FindChild("Assignment"):Enable(false)
	end
	
end

function MasterLoot:RefreshMasterLootItemList(tMasterLootItemList)

	self.wndMasterLoot_ItemList:DestroyChildren()
	
	for idx, tItem in ipairs (tMasterLootItemList) do
		local wndCurrentItem = Apollo.LoadForm(self.xmlDoc, "ItemButton", self.wndMasterLoot_ItemList, self)
		wndCurrentItem:FindChild("ItemIcon"):SetSprite(tItem.itemDrop:GetIcon())
		wndCurrentItem:FindChild("ItemName"):SetText(tItem.itemDrop:GetName())
		wndCurrentItem:SetData(tItem)
		if self.tMasterLootSelectedItem ~= nil and (self.tMasterLootSelectedItem.nLootId == tItem.nLootId) then
			wndCurrentItem:SetCheck(true)
			self:RefreshMasterLootLooterList(tMasterLootItemList)
		end
		Tooltip.GetItemTooltipForm(self, wndCurrentItem , tItem.itemDrop, {bPrimary = true, bSelling = false})
	end
	
	self.wndMasterLoot_ItemList:ArrangeChildrenVert(0)
		
end

function MasterLoot:RefreshMasterLootLooterList(tMasterLootItemList)

	self.wndMasterLoot_LooterList:DestroyChildren()
	
	if self.tMasterLootSelectedItem ~= nil then
		for idx, tItem in pairs (tMasterLootItemList) do
			if tItem.nLootId == self.tMasterLootSelectedItem.nLootId then
				local bStillHaveLooter = false
				for idx, unitLooter in pairs(tItem.tLooters) do
					local wndCurrentLooter = Apollo.LoadForm(self.xmlDoc, "CharacterButton", self.wndMasterLoot_LooterList, self)
					wndCurrentLooter:FindChild("CharacterName"):SetText(unitLooter:GetName())
					wndCurrentLooter:FindChild("CharacterLevel"):SetText(unitLooter:GetBasicStats().nLevel)
					wndCurrentLooter:FindChild("ClassIcon"):SetSprite(ktClassToIcon[unitLooter:GetClassId()])
					wndCurrentLooter:SetData(unitLooter)
					if self.tMasterLootSelectedLooter == unitLooter then
						wndCurrentLooter:SetCheck(true)
						bStillHaveLooter = true
					end
				end
				
				if not bStillHaveLooter then
					self.tMasterLootSelectedLooter = nil
				end
		
				-- get out of range people
				-- tLootersOutOfRange
				if tItem.tLootersOutOfRange and next(tItem.tLootersOutOfRange) then
					for idx, strLooterOOR in pairs(tItem.tLootersOutOfRange) do
						local wndCurrentLooter = Apollo.LoadForm(self.xmlDoc, "CharacterButton", self.wndMasterLoot_LooterList, self)
						wndCurrentLooter:FindChild("CharacterName"):SetText(strLooterOOR)
						wndCurrentLooter:FindChild("ClassIcon"):SetSprite("CRB_GroupFrame:sprGroup_Disconnected")
						wndCurrentLooter:Enable(false)
					end
				end
				self.wndMasterLoot_LooterList:ArrangeChildrenVert(0)
			end
		end
	end
end

function MasterLoot:RefreshLooterItemList(tLooterItemList)

	self.wndLooter_ItemList:DestroyChildren()

	for idx, tItem in pairs (tLooterItemList) do
		local wndCurrentItem = Apollo.LoadForm(self.xmlDoc, "LooterItemButton", self.wndLooter_ItemList, self)
		wndCurrentItem:FindChild("ItemIcon"):SetSprite(tItem.itemDrop:GetIcon())
		wndCurrentItem:FindChild("ItemName"):SetText(tItem.itemDrop:GetName())
		Tooltip.GetItemTooltipForm(self, wndCurrentItem , tItem.itemDrop, {bPrimary = true, bSelling = false})
	end

	self.wndLooter_ItemList:ArrangeChildrenVert(0)
	
end
	
----------------------------

function MasterLoot:OnGroupUpdated()
	if GroupLib.AmILeader() then
		if self.wndLooter:IsShown() then
			self:OnCloseLooterWindow()
			self:OnMasterLootUpdate(true)
		end
	else
		if self.wndMasterLoot:IsShown() then
			self:OnCloseMasterWindow()
			self:OnMasterLootUpdate(true)
		end
	end
end

----------------------------

function MasterLoot:OnItemCheck(wndHandler, wndControl, eMouseButton)

	local tItemInfo = wndHandler:GetData()
	
	if tItemInfo and tItemInfo.bIsMaster then
		self.tMasterLootSelectedItem = tItemInfo
		self.tMasterLootSelectedLooter = nil
		self:OnMasterLootUpdate(true)
	end
	
end

----------------------------

function MasterLoot:OnItemUncheck(wndHandler, wndControl, eMouseButton)

	self.tMasterLootSelectedItem = nil
	self.tMasterLootSelectedLooter = nil
	self:OnMasterLootUpdate(true)
	
end
----------------------------

function MasterLoot:OnCharacterCheck(wndHandler, wndControl, eMouseButton)

	self.tMasterLootSelectedLooter = wndControl:GetData()
	if self.tMasterLootSelectedItem ~= nil then
		self.wndMasterLoot:FindChild("Assignment"):Enable(true)
	else
		self.wndMasterLoot:FindChild("Assignment"):Enable(false)
	end
	
end

----------------------------

function MasterLoot:OnCharacterUncheck(wndHandler, wndControl, eMouseButton)

	self.tMasterLootSelectedLooter = nil
	self.wndMasterLoot:FindChild("Assignment"):Enable(false)
end

----------------------------

function MasterLoot:OnAssignDown(wndHandler, wndControl, eMouseButton)

	if self.tMasterLootSelectedItem ~= nil and self.tMasterLootSelectedLooter ~= nil then

		-- gotta save before it gets wiped out by event
		local SelectedLooter = self.tMasterLootSelectedLooter
		local SelectedItemLootId = self.tMasterLootSelectedItem.nLootId

		self.tMasterLootSelectedLooter = nil
		self.tMasterLootSelectedItem = nil

		GameLib.AssignMasterLoot(SelectedItemLootId , SelectedLooter)
		
	end
	
end

----------------------------

function MasterLoot:OnCloseMasterWindow()
	
	self.locSavedMasterWindowLoc = self.wndMasterLoot:GetLocation()
	self.wndMasterLoot_ItemList:DestroyChildren()
	self.wndMasterLoot_LooterList:DestroyChildren()
	self.tMasterLootSelectedItem = nil
	self.tMasterLootSelectedLooter = nil
	self.wndMasterLoot:Show(false)
		
end

------------------------------------

function MasterLoot:OnCloseLooterWindow()

	self.locSavedLooterWindowLoc = self.wndLooter:GetLocation()
	self.wndLooter_ItemList:DestroyChildren()
	self.wndLooter:Show(false)

end

----------------------------

function MasterLoot:OnLootAssigned(objItem, strLooter)
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("CRB_MasterLoot_AssignMsg"), objItem:GetName(), strLooter))
end

----------------------------

local knSaveVersion = 1

function MasterLoot:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local locWindowMasterLoot = self.wndMasterLoot and self.wndMasterLoot:GetLocation() or self.locSavedMasterWindowLoc
	local locWindowLooter = self.wndLooter and self.wndLooter:GetLocation() or self.locSavedLooterWindowLoc

	local tSave =
	{
		tWindowMasterLocation = locWindowMasterLoot and locWindowMasterLoot:ToTable() or nil,
		tWindowLooterLocation = locWindowLooter and locWindowLooter:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}

	return tSave
end

function MasterLoot:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then

		if tSavedData.tWindowMasterLocation then
			self.locSavedMasterWindowLoc = WindowLocation.new(tSavedData.tWindowMasterLocation)
		end

		if tSavedData.tWindowLooterLocation then
			self.locSavedLooterWindowLoc = WindowLocation.new(tSavedData.tWindowLooterLocation )
		end

		local bShowWindow = #GameLib.GetMasterLoot() > 0
		if self.wndGroupBag and bShowWindow then
			self.wndGroupBag:Show(bShowWindow)
			self:RedrawMasterLootWindow()
		end
	end
end


local MasterLoot_Singleton = MasterLoot:new()
MasterLoot_Singleton:Init()



