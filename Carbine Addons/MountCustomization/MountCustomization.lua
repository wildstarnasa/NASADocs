-----------------------------------------------------------------------------------------------
-- Client Lua Script for MountScreen
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "PetFlair"
require "PetCustomization"
require "PetCustomizationLib"

local MountScreen = {}

local knSaveVersion = 5
local kstrContainerEventName = "Mounts"

function MountScreen:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function MountScreen:Init()
    Apollo.RegisterAddon(self)
end

function MountScreen:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local tSave =
	{
		nSaveVersion = knSaveVersion,
	}

	return tSave
end

function MountScreen:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
end

-----------------------------------------------------------------------------------------------
-- MountScreen OnLoad
-----------------------------------------------------------------------------------------------
function MountScreen:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MountCustomization.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function MountScreen:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("GenericEvent_CollectablesReady", 					"OnCollectablesReady", self)
	Apollo.RegisterEventHandler("GenericEvent_MountsChecked",						"OnMountsChecked", self)
	Apollo.RegisterEventHandler("GenericEvent_MountsUnchecked", 					"OnMountsUnchecked", self)
	Apollo.RegisterEventHandler("GenericEvent_CollectablesClose",					"OnClose", self)
	Apollo.RegisterEventHandler("MountUnlocked",									"BuildMountList", self)
	Apollo.RegisterEventHandler("PetFlairUnlocked", 								"RebuildFlairList", self)
	
	self.bShowUnknown = true
	self.tKnownMounts = {}
	self.tUnknownMounts = {}
	self.wndParent = nil
	
	Event_FireGenericEvent("GenericEvent_RequestCollectablesReady")
end

function MountScreen:OnCollectablesReady(wndParent)
	if not self.bRegistered then
		Event_FireGenericEvent("GenericEvent_RegisterCollectableWindow", 100, kstrContainerEventName, Apollo.GetString("InterfaceMenu_Mounts"))
		self.wndParent = wndParent
		
		self.bRegistered = true
	end
end

function MountScreen:OnMountsUnchecked()
	self.wndMain:Show(false)
end

function MountScreen:OnMountsChecked()
	if not self.wndMain and self.wndParent then
		self:BuildMountWindow()
	end
	
	self:BuildMountList()
	self.wndMain:Show(true)
end

function MountScreen:BuildMountWindow()
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "MountScreenForm", self.wndParent, self)
	self.wndMain:Show(false)
	
	self.wndMain:FindChild("FooterBG:ShowUnknown:ShowUnknownBtn"):SetCheck(self.bShowUnknown)
	
	--Initialize flair data
	self.wndGroundFlairSlots = self.wndMain:FindChild("GroundMountFlair")
	self.wndGroundFlairSlots:FindChild("CustomizeFront"):SetData({eTypeId = PetCustomizationLib.PetFlairType_GroundMountFront, eSlotId = PetCustomizationLib.MountSlot.Front})
	self.wndGroundFlairSlots:FindChild("CustomizeBack"):SetData({eTypeId = PetCustomizationLib.PetFlairType_GroundMountBack, eSlotId = PetCustomizationLib.MountSlot.Back})
	self.wndGroundFlairSlots:FindChild("CustomizeLeft"):SetData({eTypeId = PetCustomizationLib.PetFlairType_GroundMountSide, eSlotId = PetCustomizationLib.MountSlot.Left})
	self.wndGroundFlairSlots:FindChild("CustomizeRight"):SetData({eTypeId = PetCustomizationLib.PetFlairType_GroundMountSide, eSlotId = PetCustomizationLib.MountSlot.Right})
	
	self.wndHoverFlairSlots = self.wndMain:FindChild("HoverMountFlair")
	self.wndHoverFlairSlots:FindChild("CustomizeFront"):SetData({eTypeId = PetCustomizationLib.PetFlairType_HoverMountFront, eSlotId = PetCustomizationLib.HoverboardSlot.Front})
	self.wndHoverFlairSlots:FindChild("CustomizeBack"):SetData({eTypeId = PetCustomizationLib.PetFlairType_HoverMountBack, eSlotId = PetCustomizationLib.HoverboardSlot.Back})
	self.wndHoverFlairSlots:FindChild("CustomizeSide"):SetData({eTypeId = PetCustomizationLib.PetFlairType_HoverMountSide, eSlotId = PetCustomizationLib.HoverboardSlot.Sides})
end

function MountScreen:OnClose()
	if self.wndMain then
		self.wndMain:Destroy()
		self.wndMain = nil
		
		self.tKnownMounts = {}
		self.tUnknownMounts = {}
	end
end

function MountScreen:BuildMountList()
	if not self.wndMain then
		return
	end
	
	local arMountList = GameLib.GetMountList()
	table.sort(arMountList, function(a,b) return (a.bIsKnown and not b.bIsKnown) or (a.bIsKnown == b.bIsKnown and a.strName < b.strName) end)
	
	local wndMountList = self.wndMain:FindChild("StableList")
	for idx = 1, table.getn(arMountList) do
		local tMountData = arMountList[idx]
		local wndMount = nil

		if self.tKnownMounts[tMountData.nSpellId] then
			wndMount = self.tKnownMounts[tMountData.nSpellId]
		elseif self.tUnknownMounts[tMountData.nSpellId] then
			wndMount = self.tUnknownMounts[tMountData.nSpellId]
		else		
			wndMount = Apollo.LoadForm(self.xmlDoc, "MountItem", wndMountList, self)
			local wndActionBarBtn = wndMount:FindChild("ActionBarButton")
			
			wndMount:FindChild("MountName"):SetText(tMountData.strName)
			wndActionBarBtn:SetData(tMountData.nId)
			wndMount:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\">%s</P><P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s</P>", tMountData.strName, tMountData.strDescription))
			wndActionBarBtn:SetSprite(tMountData.splObject and tMountData.splObject:GetIcon() or "Icon_ItemArmorWaist_Unidentified_Buckle_0001")
		end
		
		wndMount:SetData(tMountData)
		
		if not self.tLastSelectedData or self.tLastSelectedData.nId == tMountData.nId then
			wndMount:SetCheck(true)
			self:OnMountSelected(tMountData)
		end
		
		if tMountData.bIsKnown then
			self.tUnknownMounts[tMountData.nSpellId] = nil
			self.tKnownMounts[tMountData.nSpellId] = wndMount
			wndMount:FindChild("DisabledShade"):Show(false)
			wndMount:FindChild("MountName"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
			wndMount:FindChild("ActionBarButton"):Enable(true)
		else
			self.tUnknownMounts[tMountData.nSpellId] = wndMount
			self.tKnownMounts[tMountData.nSpellId] = nil
			wndMount:FindChild("DisabledShade"):Show(true)
			wndMount:FindChild("MountName"):SetTextColor(ApolloColor.new("UI_BtnTextHoloDisabled"))
			wndMount:FindChild("ActionBarButton"):Enable(false)
		end
	end
	
	self.wndMain:FindChild("PortraitContainer"):SetText(table.getn(self.wndMain:FindChild("StableList"):GetChildren()) == 0 and Apollo.GetString("MountScreen_NothingUnlocked") or "")
	
	for idx, wndMount in pairs(self.tUnknownMounts) do
		wndMount:Show(self.bShowUnknown)
	end
	
	self:ArrangeList()
end

function MountScreen:OnMountSelected(tMountData)
	if not tMountData then
		return
	end

	local wndOptionContainers = nil
	local bCanCustomize = false -- Some mounts simply can't be customized ever
	local custCurrentCustomization = nil
	
	self.tLastSelectedData = tMountData

	if tMountData.bIsHoverboard then
		wndOptionContainers = self.wndMain:FindChild("HoverMountFlair")
		self.wndMain:FindChild("GroundMountFlair"):Show(false)
		bCanCustomize = PetCustomizationLib.CanCustomize(PetCustomizationLib.PetType.HoverBoard, tMountData.nSpellId) and tMountData.bIsKnown
		custCurrentCustomization = PetCustomizationLib.GetCustomization(PetCustomizationLib.PetType.HoverBoard, tMountData.nSpellId)
	else
		wndOptionContainers = self.wndMain:FindChild("GroundMountFlair")
		self.wndMain:FindChild("HoverMountFlair"):Show(false)
		bCanCustomize = PetCustomizationLib.CanCustomize(PetCustomizationLib.PetType.GroundMount, tMountData.nSpellId) and tMountData.bIsKnown
		custCurrentCustomization = PetCustomizationLib.GetCustomization(PetCustomizationLib.PetType.GroundMount, tMountData.nSpellId)
	end
	wndOptionContainers:Show(true)

	-- Costume Preview
	self.wndMain:FindChild("PortraitContainer:MountName"):SetText(tMountData.strName)
	self.wndMain:FindChild("MountPortrait"):SetCostumeToCreatureId(tMountData.nPreviewCreatureId)
	
	if tMountData.bIsHoverboard then
		self.wndMain:FindChild("MountPortrait"):SetCamera("HoverboardTarget")
	else
		self.wndMain:FindChild("MountPortrait"):SetCamera("Paperdoll")
	end
	
	if tMountData.bIsHoverboard then
		self.wndMain:FindChild("MountPortrait"):SetAttachment(PetCustomizationLib.HoverboardAttachmentPoint, tMountData.nPreviewHoverboardItemDisplay)
	end
	
	self.wndMain:FindChild("MountPortrait"):SetModelSequence(150)
	
	self:BuildFlairList(wndOptionContainers, custCurrentCustomization, bCanCustomize)
end

function MountScreen:BuildFlairList(wndFlairContainers, custCurrentCustomization, bCanCustomize)
	for idx, wndCustomization in pairs(wndFlairContainers:GetChildren()) do
		local wndFlairList = wndCustomization:FindChild("CustomizationList")
		
		wndCustomization:FindChild("Blocker"):Show(not bCanCustomize)
		wndFlairList:DestroyChildren()
		
		if bCanCustomize then
			local tData = wndCustomization:GetData()
			local eFlairType = tData.eTypeId
			local eCurrSlot = tData.eSlotId
			local custEquippedFlair = custCurrentCustomization:GetSlotFlair(eCurrSlot)

			-- Flair Items
			for idx, custFlair in pairs(PetCustomizationLib.GetUnlockedPetFlairByType(eFlairType) or {}) do
				local wndCurr = Apollo.LoadForm(self.xmlDoc, "CustomizeFlairItem", wndFlairList, self)
				wndCurr:FindChild("CustomizeFlairBtn"):SetData({ custFlair = custFlair, eSlotId = eCurrSlot, custEquipped = custCurrentCustomization, wndList = wndFlairList })
				wndCurr:FindChild("CustomizeFlairBtn"):SetCheck(custEquippedFlair and custEquippedFlair:GetId() == custFlair:GetId())
				wndCurr:FindChild("CustomizeFlairBtn"):SetTooltip(custFlair:GetTooltip())

				if eFlairType ~= PetCustomizationLib.PetFlairType_GroundMountSide then
					wndCurr:FindChild("CustomizeFlairBtn"):SetText(custFlair:GetName() or "")
				else
					wndCurr:FindChild("CustomizeFlairBtn"):SetText((custFlair:GetName() .. " (" .. custFlair:GetUnlockCount() .. ")") or "")
					if custFlair:GetUnlockCount() == 1 then
						if custEquippedFlair == nil or custEquippedFlair:GetId() ~= custFlair:GetId() then
							local eOtherSideSlot = eCurrSlot == PetCustomizationLib.MountSlot.Left and PetCustomizationLib.MountSlot.Right or PetCustomizationLib.MountSlot.Left
							local custOtherSideFlair = custCurrentCustomization:GetSlotFlair(eOtherSideSlot)
							if custOtherSideFlair and custOtherSideFlair:GetId() == custFlair:GetId() then
								wndCurr:FindChild("CustomizeFlairBtn"):Enable(false)
								wndCurr:SetTooltip(Apollo.GetString("MountCustomization_FlairAlreadyAssigned"))
							end
						end
					end
				end
			end

			if custEquippedFlair then
				self.wndMain:FindChild("MountPortrait"):SetAttachment(custCurrentCustomization:GetPreviewAttachSlot(eCurrSlot), custEquippedFlair:GetItemDisplay(eCurrSlot))
			end

			wndFlairList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
			wndFlairList:Show(table.getn(wndFlairList:GetChildren()) > 0)
		end
	end
end

function MountScreen:RebuildFlairList()
	if not self.tLastSelectedData or not self.wndMain then
		return
	end
	
	local wndOptionContainers = nil
	local custCurrentCustomization = nil
	local bCanCustomize = nil
	
	if self.tLastSelectedData.bIsHoverboard then
		wndOptionContainers = self.wndMain:FindChild("HoverMountFlair")
		bCanCustomize = PetCustomizationLib.CanCustomize(PetCustomizationLib.PetType.HoverBoard, self.tLastSelectedData.nSpellId) and self.tLastSelectedData.bIsKnown
		custCurrentCustomization = PetCustomizationLib.GetCustomization(PetCustomizationLib.PetType.HoverBoard, self.tLastSelectedData.nSpellId)
	else
		wndOptionContainers = self.wndMain:FindChild("GroundMountFlair")
		bCanCustomize = PetCustomizationLib.CanCustomize(PetCustomizationLib.PetType.GroundMount, self.tLastSelectedData.nSpellId) and self.tLastSelectedData.bIsKnown
		custCurrentCustomization = PetCustomizationLib.GetCustomization(PetCustomizationLib.PetType.GroundMount, self.tLastSelectedData.nSpellId)
	end
		
	self:BuildFlairList(wndOptionContainers, custCurrentCustomization, bCanCustomize)
end

----------------------------------------------------------------------------------------------
-- Interaction
-----------------------------------------------------------------------------------------------

function MountScreen:OnMountItemClick(wndHandler, wndControl) -- MountItemMouseCatcher
	local tMountData = wndHandler:GetData()
	self.tLastSelectedData = tMountData
	self:OnMountSelected(tMountData)
end

function MountScreen:OnCustomizeFlairCheck(wndHandler, wndControl) -- CustomizeFlairBtn, data is { tFlairData, nSlotIndex }
	local tData = wndHandler:GetData()
	
	tData.custEquipped:SetFlairInSlot(tData.custFlair, tData.eSlotId)

	-- Update the preview window
	self.wndMain:FindChild("MountPortrait"):SetAttachment(tData.custEquipped:GetPreviewAttachSlot(tData.eSlotId), tData.custFlair:GetItemDisplay(tData.eSlotId))

	local custPrevFlair = nil
	-- Uncheck other buttons (can't use global radio group as there's 4 buckets)
	for idx, wndCurr in pairs(tData.wndList:GetChildren()) do
		if wndCurr and wndCurr:FindChild("CustomizeFlairBtn") then
			if wndCurr:FindChild("CustomizeFlairBtn"):IsChecked() and wndCurr:FindChild("CustomizeFlairBtn") ~= wndHandler then
				custPrevFlair = wndCurr:FindChild("CustomizeFlairBtn"):GetData().custFlair
			end
			wndCurr:FindChild("CustomizeFlairBtn"):SetCheck(wndCurr:FindChild("CustomizeFlairBtn") == wndHandler)
		end
	end

	local nUnlockCount = tData.custFlair:GetUnlockCount()
	local nPrevUnlockCount = custPrevFlair and custPrevFlair:GetUnlockCount() or 0
	if tData.custFlair:GetFlairType() == PetCustomizationLib.PetFlairType_GroundMountSide and (nUnlockCount == 1 or nPrevUnlockCount == 1) and not self.tLastSelectedData.bIsHoverboard then
		local wndOtherFlairList = nil
		
		if tData.eSlotId == PetCustomizationLib.MountSlot.Left then
			wndOtherFlairList = self.wndGroundFlairSlots:FindChild("CustomizeRight")
		elseif tData.eSlotId == PetCustomizationLib.MountSlot.Right then
			wndOtherFlairList = self.wndGroundFlairSlots:FindChild("CustomizeLeft")
		end

		if wndOtherFlairList then
			for idx, wndCurr in pairs(wndOtherFlairList:GetChildren()) do
				local wndCustomizeBtn = wndCurr:FindChild("CustomizeFlairBtn")
				if wndCustomizeBtn then
					if nUnlockCount == 1 and wndCustomizeBtn:GetData().custFlair == tData.custFlair then
						wndCustomizeBtn:Enable(false)
						wndCurr:SetTooltip(Apollo.GetString("MountCustomization_FlairAlreadyAssigned"))
					end

					if nPrevUnlockCount == 1 and wndCustomizeBtn:GetData().custFlair == custPrevFlair then
						wndCustomizeBtn:Enable(true)
					end
				end
			end
		end
	end
end

function MountScreen:OnCustomizeFlairUncheck(wndHandler, wndControl) -- CustomizeFlairBtn, data is { tFlairData, nSlotIndex }
	local tData = wndHandler:GetData()

	tData.custEquipped:ClearFlairInSlot(tData.eSlotId)

	-- Update the preview window
	self.wndMain:FindChild("MountPortrait"):SetAttachment(tData.custEquipped:GetPreviewAttachSlot(tData.eSlotId), 0)

	if tData.custFlair:GetFlairType() == PetCustomizationLib.PetFlairType_GroundMountSide and tData.custFlair:GetUnlockCount() == 1 and not self.tLastSelectedData.bIsHoverboard then
		local wndOtherFlairList = nil
		if tData.eSlotId == PetCustomizationLib.MountSlot.Left then
			wndOtherFlairList = self.wndGroundFlairSlots:FindChild("CustomizeRight")
		elseif tData.eSlotId == PetCustomizationLib.MountSlot.Right then
			wndOtherFlairList = self.wndGroundFlairSlots:FindChild("CustomizeLeft")
		end

		
		for idx, wndCurr in pairs(wndOtherFlairList:GetChildren()) do
			local wndCustomizeBtn = wndCurr:FindChild("CustomizeFlairBtn")
			if wndCustomizeBtn and wndCustomizeBtn:GetData().custFlair == tData.custFlair then
				wndCustomizeBtn:Enable(true)
			end
		end
	end
end

function MountScreen:OnMountBeginDragDrop(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	Apollo.BeginDragDrop(wndControl, "DDNonCombat", wndControl:GetSprite(), wndControl:GetData())
	return true
end

-----------------------------------------------------------------------------------------------
-- Rotating
-----------------------------------------------------------------------------------------------

function MountScreen:OnRotateRight()
	self.wndMain:FindChild("MountPortrait"):ToggleLeftSpin(true)
end

function MountScreen:OnRotateRightCancel()
	self.wndMain:FindChild("MountPortrait"):ToggleLeftSpin(false)
end

function MountScreen:OnRotateLeft()
	self.wndMain:FindChild("MountPortrait"):ToggleRightSpin(true)
end

function MountScreen:OnRotateLeftCancel()
	self.wndMain:FindChild("MountPortrait"):ToggleRightSpin(false)
end

function MountScreen:OnShowUnknown(wndControl, wndHandler)
	for idx, wndMount in pairs(self.tUnknownMounts) do
		-- Only show the ones that are both unknown and meet the current search criteria
		local tSearchIndices = string.find(string.lower(wndMount:GetData().strName), string.lower(self.wndMain:FindChild("SearchField"):GetText()))
		wndMount:Show(tSearchIndices)
	end
	self.bShowUnknown = true
	
	self:ArrangeList()
end

function MountScreen:OnHideUnknown(wndControl, wndHandler)
	for idx, wndMount in pairs(self.tUnknownMounts) do
		wndMount:Show(false)
	end
	
	self.bShowUnknown = false
	
	self.wndMain:FindChild("StableList"):SetVScrollPos(0)
	self.wndMain:FindChild("StableList"):RecalculateContentExtents()
end

function MountScreen:OnSearchFieldChanged(wndHandler, wndControl, strText)
	local wndMountList = self.wndMain:FindChild("StableList")
	strText = string.lower(strText)
	
	wndHandler:GetParent():FindChild("SearchClearBtn"):Show(strText ~= "")
	
	for idx, wndMount in pairs(wndMountList:GetChildren()) do
		local tData = wndMount:GetData()
		
		if (tData.bIsKnown or self.bShowUnknown) and string.find(string.lower(tData.strName), strText) then
			wndMount:Show(true)
		else
			wndMount:Show(false)
		end
	end	
	
	self:ArrangeList()
end

function MountScreen:OnClearSearch(wndHandler, wndControl)
	local wndSearchField = wndHandler:GetParent():FindChild("SearchField")
	wndSearchField:ClearText()
	self:OnSearchFieldChanged(wndSearchField, wndSearchField, "")
	wndHandler:Show(false)
end

function MountScreen:ArrangeList()
	local wndMountList = self.wndMain:FindChild("StableList")
	
	wndMountList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop,
		function(a,b) return (a:GetData().bIsKnown and not b:GetData().bIsKnown) or (a:GetData().bIsKnown == b:GetData().bIsKnown and a:GetData().strName < b:GetData().strName) end)	
	
	wndMountList:SetVScrollPos(0)
	wndMountList:RecalculateContentExtents()
end

local MountScreenInst = MountScreen:new()
MountScreenInst:Init()