-----------------------------------------------------------------------------------------------
-- Client Lua Script for Masterloot
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "GroupLib"
require "ICCommLib"
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

	Apollo.RegisterEventHandler("GenericEvent_ToggleGroupBag", "OnToggleGroupBag", self)

	self.chanMasterLoot = ICCommLib.JoinChannel("CRBMasterLoot", "OnLooterMessage", self)

	self.wndMasterLoot = nil
	self.wndLooter = nil
	self.tOld_MasterLootList = {}

	-- Master Looter Global Vars
	self.tMasterLootSelectedItem = nil
	self.tMasterLootSelectedLooter = nil

	-- ICCommLib Recieved Player Requests
	self.tMasterLootRecievedRequests = {}

	-- Looter Global Vars
	self.tLooterItemRequests = {}

end

----------------------------

-- Generic event from Group or Raid Frame ML Available Button
function MasterLoot:OnToggleGroupBag()
	local tMasterLoot = GameLib.GetMasterLoot()
	self:MasterLootWindowBuilder(tMasterLoot)
end

----------------------------

function MasterLoot:OnMasterLootUpdate()
	
	local tMasterLoot = GameLib.GetMasterLoot()
	local bNewItem = true
	for idx, tCur in pairs(tMasterLoot or {}) do
		local bFound = false
		for idxOld, tCurOld in pairs(self.tOld_MasterLootList) do
			if tCur.nLootId == tCurOld.nLootId then
				bFound = true
				break
			end
		end
		bNewItem = not bFound
	end
	if bNewItem then
		self.tOld_MasterLootList = tMasterLoot
		self:MasterLootWindowBuilder(tMasterLoot)
	end
	
end

----------------------------

function MasterLoot:MasterLootWindowBuilder(tMasterLoot)

	self.tMasterLootSelectedItem = nil
	self.tMasterLootSelectedLooter = nil

	if tMasterLoot and #tMasterLoot > 0 then
		local tMasterLootItemList = {}
		local tLooterItemList = {}

		for idx, tLootItem in ipairs(tMasterLoot) do
			if tLootItem.bIsMaster then
				table.insert(tMasterLootItemList, tLootItem)
			else
				table.insert(tLooterItemList, tLootItem)
			end
		end

		self:MasterLootHelper(tMasterLootItemList)
		self:LooterHelper(tLooterItemList)

	else
		if self.wndMasterLoot then
			self.locSavedMasterWindowLoc = self.wndMasterLoot:GetLocation()
			self.wndMasterLoot:Destroy()
		end
		if self.wndLooter then
			self.locSavedLooterWindowLoc = self.wndLooter:GetLocation()
			self.wndLooter:Destroy()
		end
	end
end

----------------------------

function MasterLoot:MasterLootHelper(tMasterLootItemList)

	if tMasterLootItemList and #tMasterLootItemList > 0 then

		if not self.wndMasterLoot or not self.wndMasterLoot:IsValid() then
			self.wndMasterLoot = Apollo.LoadForm(self.xmlDoc, "MasterLootWindow", nil, self)
			self.wndMasterLoot:SetSizingMinimum(550, 310)
			if self.locSavedMasterWindowLoc then
				self.wndMasterLoot:MoveToLocation(self.locSavedMasterWindowLoc)
			end
			self.wndMasterLoot:FindChild("MasterLoot_Filter_All"):SetCheck(true)
		end

		local wndItemList = self.wndMasterLoot:FindChild("ItemList")
		local wndLooterList = self.wndMasterLoot:FindChild("LooterList")

		wndItemList:DestroyChildren()
		wndLooterList:DestroyChildren()

		for idx, tItem in ipairs (tMasterLootItemList) do
			local wndCurrentItem = Apollo.LoadForm(self.xmlDoc, "ItemButton", wndItemList, self)
			wndCurrentItem:FindChild("ItemIcon"):SetSprite(tItem.itemDrop:GetIcon())
			wndCurrentItem:FindChild("ItemName"):SetText(tItem.itemDrop:GetName())
			wndCurrentItem:SetData(tItem)
			Tooltip.GetItemTooltipForm(self, wndCurrentItem , tItem.itemDrop, {bPrimary = true, bSelling = false})
		end
		wndItemList:ArrangeChildrenVert(0)

		self.wndMasterLoot:Show(true)
	end
end

----------------------------

function MasterLoot:LooterHelper(tLooterItemList)

	if tLooterItemList and #tLooterItemList> 0 then

		if not self.wndLooter or not self.wndLooter:IsValid() then
			self.wndLooter = Apollo.LoadForm(self.xmlDoc, "LooterWindow", nil, self)
			if self.locSavedLooterWindowLoc then self.wndLooter:MoveToLocation(self.locSavedLooterWindowLoc) end
		end

		local wndItemList = self.wndLooter:FindChild("ItemList")
		wndItemList:DestroyChildren()

		for idx, tItem in ipairs (tLooterItemList) do
			local wndCurrentItem = Apollo.LoadForm(self.xmlDoc, "LooterItemButton", wndItemList, self)
			wndCurrentItem:FindChild("ItemIcon"):SetSprite(tItem.itemDrop:GetIcon())
			wndCurrentItem:FindChild("ItemName"):SetText(tItem.itemDrop:GetName())
			wndCurrentItem:SetData(tItem)
			Tooltip.GetItemTooltipForm(self, wndCurrentItem , tItem.itemDrop, {bPrimary = true, bSelling = false})
		end

		wndItemList:ArrangeChildrenVert(0)
		self.wndLooter:Show(true)
	end
end
----------------------------

function MasterLoot:OnItemCheck(wndHandler, wndControl, eMouseButton)

	if not wndHandler then return end
	if not self.wndMasterLoot or not self.wndMasterLoot:IsValid() then return end

	local tItemInfo = wndHandler:GetData()

	if tItemInfo and tItemInfo.bIsMaster and self.wndMasterLoot then

		self.tMasterLootSelectedItem = wndHandler

		self.tMasterLootSelectedLooter = nil

		self.wndMasterLoot:FindChild("LooterList"):DestroyChildren()

		for idx, unitLooter in ipairs(tItemInfo.tLooters) do

			local nUnitLooterId = unitLooter:GetId()
			local bDraw = true
			local bDidThisLooterRequest = false

			if unitLooter:GetId() ~= GameLib:GetPlayerUnit():GetId() then -- if we are not checking the Master Looter
				for idxMasterLootRecievedRequests, tCurMasterLootRecievedRequests in ipairs(self.tMasterLootRecievedRequests) do -- loop over loot requests
					if nUnitLooterId == tCurMasterLootRecievedRequests.Looter then -- if looter matches a recieved looter who made a request
						for idxRequestedItems, curRequestedItem in pairs(tCurMasterLootRecievedRequests.tMsg) do -- loop over recieved looters requested items
							if curRequestedItem == tItemInfo.nLootId then -- id and nLootId's match
								bDidThisLooterRequest = true -- that looter did request the selected item
							end
						end
					end
				end
			else
				bDidThisLooterRequest = true -- Skip checking if MasterLooter is the unitLooter and always list
			end

			-- Early out if Filter by Requested is Selected
			if self.wndMasterLoot:FindChild("MasterLoot_Filter_Request"):IsChecked() and (bDidThisLooterRequest == false) then
				bDraw = false
			end

			if bDraw then
				local wndCurrentLooter = Apollo.LoadForm(self.xmlDoc, "CharacterButton", self.wndMasterLoot:FindChild("LooterList"), self)

				wndCurrentLooter:FindChild("CharacterName"):SetText(unitLooter:GetName())
				wndCurrentLooter:FindChild("CharacterLevel"):SetText(unitLooter:GetBasicStats().nLevel)
				wndCurrentLooter:FindChild("ClassIcon"):SetSprite(ktClassToIcon[unitLooter:GetClassId()])
				wndCurrentLooter:SetData(unitLooter)
				wndCurrentLooter:FindChild("Check"):Show(bDidThisLooterRequest)
			end
		end

		self.wndMasterLoot:FindChild("LooterList"):ArrangeChildrenVert(0)

	end
end

----------------------------

function MasterLoot:OnItemUncheck(wndHandler, wndControl, eMouseButton)
	self.wndMasterLoot:FindChild("LooterList"):DestroyChildren()
	self.tMasterLootSelectedItem = nil
	self.tMasterLootSelectedLooter = nil
end
----------------------------

function MasterLoot:OnCharacterCheck(wndHandler, wndControl, eMouseButton)
	self.tMasterLootSelectedLooter = wndControl:GetData()
end

----------------------------

function MasterLoot:OnCharacterUncheck(wndHandler, wndControl, eMouseButton)
	self.tMasterLootSelectedLooter = nil
end

----------------------------

function MasterLoot:OnAssignDown(wndHandler, wndControl, eMouseButton)

	if self.tMasterLootSelectedItem ~= nil and self.tMasterLootSelectedLooter ~= nil then

		-- gotta save before it gets wiped out by event
		local SelectedLooterId = self.tMasterLootSelectedLooter:GetId()
		local SelectedItemLootId = self.tMasterLootSelectedItem:GetData().nLootId

		GameLib.AssignMasterLoot(SelectedItemLootId , self.tMasterLootSelectedLooter)

		-- Clean up distributed item from all looter requests
		for idx, tCur in ipairs(self.tMasterLootRecievedRequests or {}) do
			if tCur.Looter == SelectedLooterId then
				for idxRequests, nCurRequest in ipairs(tCur.tMsg) do
					if nCurRequest == SelectedItemLootId then
						tCur.tMsg[idxRequests] = nil
					end
				end
			end
		end

	end

	local tMasterLoot = GameLib.GetMasterLoot()
	self.tOld_MasterLootList = tMasterLoot
	self:MasterLootWindowBuilder(tMasterLoot)

end

----------------------------

function MasterLoot:OnCloseMasterWindow()
	if self.wndMasterLoot then
		self.locSavedMasterWindowLoc = self.wndMasterLoot:GetLocation()
		self.wndMasterLoot:Destroy()
	end
end

------------------------------------

function MasterLoot:OnLooterItemCheck(wndHandler, wndControl, eMouseButton)

	local tItemInfo = wndHandler:GetData()
	table.insert(self.tLooterItemRequests, tItemInfo.nLootId)

	wndControl:FindChild("Check"):Show(true)
	self:SendMLMessage(self.tLooterItemRequests)

end

----------------------------

function MasterLoot:OnLooterItemUncheck(wndHandler, wndControl, eMouseButton)

	local tItemInfo = wndHandler:GetData()
	for idx, tCur in ipairs(self.tLooterItemRequests) do
		if tCur == tItemInfo.nLootId then
			table.remove(self.tLooterItemRequests, idx)
			break
		end
	end
	self:SendMLMessage(self.tLooterItemRequests)
	wndControl:FindChild("Check"):Show(false)
end

----------------------------

function MasterLoot:OnCloseLooterWindow()
	if self.wndLooter then
		self.locSavedLooterWindowLoc = self.wndLooter:GetLocation()
		self.wndLooter:Destroy()
	end
end

----------------------------

function MasterLoot:SendMLMessage(tMsg)
	self.chanMasterLoot:SendMessage({["Looter"] = GameLib.GetPlayerUnit():GetId(), ["tMsg"] = tMsg})
end

----------------------------

function MasterLoot:OnLooterMessage(channel, tMsg)

	for idx, tCur in ipairs(self.tMasterLootRecievedRequests or {}) do
		if tCur.Looter == tMsg.Looter then
			table.remove(self.tMasterLootRecievedRequests, idx)
		end
	end

	if #tMsg.tMsg > 0 then
		table.insert(self.tMasterLootRecievedRequests, tMsg)
	end

	-- We need to redraw Master Loot Recipients based on what Available Item is selected
	-- Fake Item Click to force Recipient update
	self:OnItemCheck(self.tMasterLootSelectedItem)

end

----------------------------

function MasterLoot:OnLootAssigned(objItem, strLooter)
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", String_GetWeaselString(Apollo.GetString("CRB_MasterLoot_AssignMsg"), objItem:GetName(), strLooter))
end


function MasterLoot:OnFilterBtn(wndHandler, wndControl, eMouseButton)

	if self.wndMasterLoot then

		local btnFilterAll = self.wndMasterLoot:FindChild("MasterLoot_Filter_All")
		local btnFilterRequest = self.wndMasterLoot:FindChild("MasterLoot_Filter_Request")

		if wndControl == btnFilterAll then
			if btnFilterAll:IsChecked() then
				btnFilterRequest:SetCheck(false)
			else
				btnFilterRequest:SetCheck(true)
			end
		elseif wndControl == btnFilterRequest then
			if btnFilterRequest:IsChecked()then
				btnFilterAll:SetCheck(false)
			else
				btnFilterAll:SetCheck(true)
			end
		end

		-- We need to redraw Master Loot Recipients based on what Available Item is selected
		-- Fake Item Click to force Recipient update
		self:OnItemCheck(self.tMasterLootSelectedItem)

	end

end

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



