-----------------------------------------------------------------------------------------------
-- Client Lua Script for VanityPets
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- VanityPets Module Definition
-----------------------------------------------------------------------------------------------
local VanityPets = {} 

local kstrContainerEventName = "VanityPets"
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function VanityPets:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function VanityPets:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- VanityPets OnLoad
-----------------------------------------------------------------------------------------------
function VanityPets:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("VanityPets.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- VanityPets OnDocLoaded
-----------------------------------------------------------------------------------------------
function VanityPets:OnDocLoaded()
	if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() then
		return
	end
	
	Apollo.RegisterEventHandler("GenericEvent_CollectablesReady", "OnRegisterContainer", self)
	Apollo.RegisterEventHandler("GenericEvent_VanityPetsChecked", "OnPetsShow", self)
	Apollo.RegisterEventHandler("GenericEvent_VanityPetsUnchecked", "OnPetsHide", self)
	Apollo.RegisterEventHandler("GenericEvent_CollectablesClose", "OnClose", self)
	Apollo.RegisterEventHandler("AbilityBookChange", "UpdatePetLists", self)
	
	self.tKnownPets = {}
	self.tUnknownPets = {}
	
	self.bShowUnknown = true
	
	Event_FireGenericEvent("GenericEvent_RequestCollectablesReady")
end

-----------------------------------------------------------------------------------------------
-- VanityPets Functions
-----------------------------------------------------------------------------------------------
function VanityPets:OnRegisterContainer(wndParent)
	if not self.bRegistered then
		self.wndParent = wndParent
		
		-- Needs nTabOrder, strEventBase, strLabel
		Event_FireGenericEvent("GenericEvent_RegisterCollectableWindow", 200, kstrContainerEventName, Apollo.GetString("CRB_Pets"))
		
		self.bRegistered = true
	end
end

function VanityPets:OnClose()
	if self.wndMain then
		self.wndMain:FindChild("PetList"):DestroyChildren()
		self.wndMain:Destroy()
		self.wndMain = nil
		
		self.tKnownPets = {}
		self.tUnknownPets = {}
	end
end

function VanityPets:OnPetsShow()
	if not self.wndMain then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "PetsForm", self.wndParent, self)
	end
	
	self.wndMain:FindChild("FooterBG:ShowUnknown:ShowUnknownBtn"):SetCheck(self.bShowUnknown)
	
	self:UpdatePetLists()
	
	self.wndMain:Show(true)
end

function VanityPets:OnPetsHide()
	self.wndMain:Show(false)
end

function VanityPets:UpdatePetLists()
	if not self.wndMain then
		return
	end
	
	local wndPetList = self.wndMain:FindChild("PetList")
	local arPetList = GameLib.GetVanityPetList()
	
	table.sort(arPetList, function(a,b) return (a.bIsKnown and not b.bIsKnown) or (a.bIsKnown == b.bIsKnown and a.strName < b.strName) end)
	
	for idx = 1, #arPetList do
		local tPetInfo = arPetList[idx]
		local wndPet = nil
		
		-- Windows are stored in tables.  We should only have to create new windows the first time this function runs.
		if self.tKnownPets[tPetInfo.nSpellId] then
			wndPet = self.tKnownPets[tPetInfo.nSpellId]
		elseif self.tUnknownPets[tPetInfo.nSpellId] then
			wndPet = self.tUnknownPets[tPetInfo.nSpellId]
		else
			wndPet = Apollo.LoadForm(self.xmlDoc, "PetItem", wndPetList, self)
			local wndActionButton = wndPet:FindChild("ActionBarButton")

			wndActionButton:SetData(tPetInfo.nId)
			wndActionButton:SetSprite(tPetInfo.splObject and tPetInfo.splObject:GetIcon() or "Icon_ItemArmorWaist_Unidentified_Buckle_0001")
			wndPet:FindChild("PetName"):SetText(tPetInfo.strName)
		end
		
		wndPet:SetData(tPetInfo)
		
		if not self.nSelectedId or self.nSelectedId == tPetInfo.nId then
			wndPet:SetCheck(true)
			self:OnPetItemClick(wndPet, wndPet)
			self.nSelectedId = tPetInfo.nId
		end
		
		if tPetInfo.bIsKnown then
			self.tKnownPets[tPetInfo.nSpellId] = wndPet
			self.tUnknownPets[tPetInfo.nSpellId] = nil
			wndPet:FindChild("DisabledShade"):Show(false)
			wndPet:FindChild("PetName"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
			wndPet:FindChild("ActionBarButton"):Enable(true)
		else
			self.tKnownPets[tPetInfo.nSpellId] = nil
			self.tUnknownPets[tPetInfo.nSpellId] = wndPet
			wndPet:FindChild("DisabledShade"):Show(true)
			wndPet:FindChild("PetName"):SetTextColor(ApolloColor.new("UI_BtnTextHoloDisabled"))
			wndPet:FindChild("ActionBarButton"):Enable(false)
		end
	end
	
	self:ArrangeList()
	
	for idx, wndPet in pairs(self.tUnknownPets) do
		wndPet:Show(self.bShowUnknown)
	end
	
	self:OnSearchFieldChanged(nil, nil, self.wndMain:FindChild("SearchField"):GetText())
	
	self.wndMain:FindChild("PortraitContainer"):Show(self.nSelectedId)		
end

function VanityPets:OnPetItemClick(wndHandler, wndControl)
	local tPetData = wndHandler:GetData()
	local wndParent = wndHandler:GetParent()

	self.wndMain:FindChild("PetName"):SetText(tPetData.strName)
	self.wndMain:FindChild("PetPreview"):SetCostumeToCreatureId(tPetData.nPreviewCreatureId)
	self.wndMain:FindChild("PetPreview"):SetModelSequence(150)
	
	self.nSelectedId = tPetData.nId
	self.wndMain:FindChild("PortraitContainer"):Show(true)	

	local arPets = GameLib.GetPlayerPets()
	local bPetSummoned = false
	if arPets then
		for idx, unitPet in pairs (arPets) do
			if unitPet:GetName() == tPetData.strName then
				bPetSummoned = true
				break
			end
		end
	end
	
	local wndSummon = self.wndMain:FindChild("SummonPetBtn")	
	wndSummon:Show(not bPetSummoned)
	wndSummon:SetData(tPetData)
	wndSummon:Enable(tPetData.bIsKnown)
	
	local wndDismiss = self.wndMain:FindChild("DismissPetBtn")
	wndDismiss:SetData(tPetData)
	wndDismiss:Show(bPetSummoned)
end

function VanityPets:OnSummonPet(wndHandler, wndControl)
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end
	
	GameLib.SummonVanityPet(self.nSelectedId)
	
	Event_FireGenericEvent("GenericEvent_CloseCollectablesWindow")
end

-----------------------------------------------------------------------------------------------
-- PetsForm Functions
-----------------------------------------------------------------------------------------------

function VanityPets:OnRotateLeft( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("PetPreview"):ToggleRightSpin(true)
end

function VanityPets:OnRotateLeftCancel( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("PetPreview"):ToggleRightSpin(false)
end

function VanityPets:OnRotateRight( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("PetPreview"):ToggleLeftSpin(true)
end

function VanityPets:OnRotateRightCancel( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("PetPreview"):ToggleLeftSpin(false)
end

function VanityPets:OnHideUnknown()
	for idx, wndPet in pairs(self.tUnknownPets) do
		wndPet:Show(false)
	end
	self.bShowUnknown = false
	
	self:ArrangeList()
end

function VanityPets:OnShowUnknown()
	for idx, wndPet in pairs(self.tUnknownPets) do
		-- Only show the ones that are both unknown and meet the current search criteria
		local tSearchIndices = string.find(string.lower(wndPet:GetData().strName), string.lower(self.wndMain:FindChild("SearchField"):GetText()))
		wndPet:Show(tSearchIndices)
	end
	self.bShowUnknown = true
	
	self:ArrangeList()
end

function VanityPets:OnPetBeginDragDrop(wndHander, wndControl)
	Apollo.BeginDragDrop(wndHander, "DDNonCombat", wndHander:GetSprite(), wndHander:GetData())
end

function VanityPets:OnSearchFieldChanged(wndHandler, wndControl, strText)
	local wndPetList = self.wndMain:FindChild("PetList")
	
	self.wndMain:FindChild("FooterBG:SearchByName:SearchClearBtn"):Show(strText ~= "")
	
	for idx, wndPet in pairs(wndPetList:GetChildren()) do
		local tData = wndPet:GetData()
		
		if (tData.bIsKnown or self.bShowUnknown) and string.find(string.lower(tData.strName), string.lower(strText)) then
			wndPet:Show(true)
		else
			wndPet:Show(false)
		end
	end	
	
	self:ArrangeList()
end

function VanityPets:OnClearSearch(wndHandler, wndControl)
	local wndSearchField = wndHandler:GetParent():FindChild("SearchField")
	wndSearchField:ClearText()
	self:OnSearchFieldChanged(wndSearchField, wndSearchField, "")
	wndHandler:Show(false)
end

function VanityPets:ArrangeList()
	local wndPetList = self.wndMain:FindChild("PetList")
	
	wndPetList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop,
		function(a,b) return (a:GetData().bIsKnown and not b:GetData().bIsKnown) or (a:GetData().bIsKnown == b:GetData().bIsKnown and a:GetData().strName < b:GetData().strName) end)	
	
	wndPetList:SetVScrollPos(0)
	wndPetList:RecalculateContentExtents()
end

-----------------------------------------------------------------------------------------------
-- VanityPets Instance
-----------------------------------------------------------------------------------------------
local PetsInst = VanityPets:new()
PetsInst:Init()
