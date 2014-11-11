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

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)

	Apollo.RegisterEventHandler("GenericEvent_InitializeMountsCustomization", "OnGenericEvent_InitializeMountsCustomization", self)
	Apollo.RegisterEventHandler("GenericEvent_DestroyMountsCustomization", "OnGenericEvent_DestroyMountsCustomization", self)
end

function MountScreen:OnInterfaceMenuListHasLoaded()
	local strEvent = "GenericEvent_ToggleMountCustomize"
	local strIcon = "Icon_Windows32_UI_CRB_InterfaceMenu_MountCustomization"
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_MountCustomization"), {strEvent, "", strIcon})
end

function MountScreen:OpenMounts()
	-- TODO: This needs to open character panel to the right tab
end

function MountScreen:OnGenericEvent_DestroyMountCustomization()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function MountScreen:OnGenericEvent_InitializeMountsCustomization(wndParent, idMount)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "MountScreenForm", wndParent, self)

	-- The pet lib might not be loaded yet. It is quite slow.
	self.ktGroundMountFlairWindows =
	{
		["CustomizeFrontList"]	=	{ PetCustomizationLib.PetFlairType_GroundMountFront, PetCustomizationLib.MountSlot.Front, Apollo.GetString("MountScreen_FrontFlair") },
		["CustomizeBackList"]	=	{ PetCustomizationLib.PetFlairType_GroundMountBack, PetCustomizationLib.MountSlot.Back, Apollo.GetString("MountScreen_BackFlair") },
		["CustomizeLeftList"]	=	{ PetCustomizationLib.PetFlairType_GroundMountSide, PetCustomizationLib.MountSlot.Left, Apollo.GetString("MountScreen_LeftFlair") },
		["CustomizeRightList"]	=	{ PetCustomizationLib.PetFlairType_GroundMountSide, PetCustomizationLib.MountSlot.Right, Apollo.GetString("MountScreen_RightFlair") },
	}

	self.ktHoverMountFlairWindows =
	{
		["CustomizeFrontList"]	=	{ PetCustomizationLib.PetFlairType_HoverMountFront, PetCustomizationLib.HoverboardSlot.Front, Apollo.GetString("MountScreen_FrontFlair") },
		["CustomizeBackList"]	=	{ PetCustomizationLib.PetFlairType_HoverMountBack, PetCustomizationLib.HoverboardSlot.Back, Apollo.GetString("MountScreen_BackFlair") },
		["CustomizeLeftList"]	=	{ PetCustomizationLib.PetFlairType_HoverMountSide, PetCustomizationLib.HoverboardSlot.Sides, Apollo.GetString("MountScreen_LeftFlair") },
		["CustomizeRightList"]	=	{ PetCustomizationLib.PetFlairType_HoverMountSide, PetCustomizationLib.HoverboardSlot.Sides, Apollo.GetString("MountScreen_RightFlair") },
	}

	-- Stable
	local bFirstMountInList = nil
	local wndSelected = nil
	local tMountList = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}
	for idx, tMountData in pairs(tMountList) do
		if tMountData.bIsActive then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "MountItem", self.wndMain:FindChild("StableList"), self)
			wndCurr:FindChild("MountItemMouseCatcher"):SetData(tMountData)
			wndCurr:FindChild("MountItemActionBarBtn"):SetData(tMountData.nId)
			wndCurr:FindChild("MountItemActionBarBtn"):SetContentId(tMountData.nId)
			wndCurr:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\">%s</P><P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s</P>", tMountData.strName, tMountData.strAbilityDescription))

			local tMountTierData = tMountData.tTiers[tMountData.nCurrentTier]
			wndCurr:FindChild("MountItemActionBarBtn"):SetSprite(tMountTierData.splObject and tMountTierData.splObject:GetIcon() or "Icon_ItemArmorWaist_Unidentified_Buckle_0001")
			if not bFirstMountInList then
				bFirstMountInList = true
				wndSelected = wndCurr
			end
			
			if self.tLastSelectedData and tMountData.strName  == self.tLastSelectedData.strName then
				wndSelected = wndCurr
			end
			
			if idMount and tMountData.tTiers[1] and tMountData.tTiers[1].splObject:GetId() == idMount then
				local wndMouseCatcher = wndCurr:FindChild("MountItemMouseCatcher")
				self:OnMountItemClick(wndMouseCatcher, wndMouseCatcher)
			end
		end
	end

	if wndSelected then
		self:DrawNewMount(wndSelected:FindChild("MountItemMouseCatcher"):GetData())
		wndSelected:FindChild("MountItemMouseCatcherArt"):Show(true)
	end
	
	self.wndMain:FindChild("StableList"):ArrangeChildrenTiles(0)
	self.wndMain:FindChild("PortraitContainer"):SetText(#self.wndMain:FindChild("StableList"):GetChildren() == 0 and Apollo.GetString("MountScreen_NothingUnlocked") or "")
end

function MountScreen:DrawNewMount(tMountData)
	if not tMountData then
		return
	end

	local tMountTierData = tMountData.tTiers[tMountData.nCurrentTier]
	if not tMountTierData or not tMountTierData.nTierSpellId then
		return
	end

	local eTableToUse = nil
	local bCanCustomize = false -- Some mounts simply can't be customized ever
	local objPetCustomization = nil

	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("CustomizeBackBG"):GetAnchorOffsets()
	local nLeft3, nTop3, nRight3, nBottom3 = self.wndMain:FindChild("CustomizeLeftBG"):GetAnchorOffsets()
	local nLeft2, nTop2, nRight2, nBottom2 = self.wndMain:FindChild("CustomizeFrontBG"):GetAnchorOffsets()

	local nLeft4, nTop4, nRight4, nBottom4 = self.wndMain:FindChild("MouseBlocker1"):GetAnchorOffsets()
	local nLeft5, nTop5, nRight5, nBottom5 = self.wndMain:FindChild("MouseBlocker2"):GetAnchorOffsets()
	local nLeft6, nTop6, nRight6, nBottom6 = self.wndMain:FindChild("MouseBlocker4"):GetAnchorOffsets()

	if tMountTierData.bIsHoverboard then
		eTableToUse = self.ktHoverMountFlairWindows
		bCanCustomize = PetCustomizationLib.CanCustomize(2, tMountTierData.nTierSpellId)
		objPetCustomization = PetCustomizationLib.GetCustomization(2, tMountTierData.nTierSpellId)
		self.wndMain:FindChild("CustomizeRightBG"):Show(false)
		self.wndMain:FindChild("MouseBlocker3"):Show(false)
		self.wndMain:FindChild("CustomizeBackBG"):SetAnchorOffsets(nLeft, 207, nRight, 398)
		self.wndMain:FindChild("CustomizeFrontBG"):SetAnchorOffsets(nLeft2, 14, nRight2, 205)
		self.wndMain:FindChild("CustomizeLeftBG"):SetAnchorOffsets(nLeft3, 400, nRight3, 602)
		self.wndMain:FindChild("MouseBlocker1"):SetAnchorOffsets(nLeft4, 0, nRight4, 155)
		self.wndMain:FindChild("MouseBlocker2"):SetAnchorOffsets(nLeft5, 194, nRight5, 348)
		self.wndMain:FindChild("MouseBlocker4"):SetAnchorOffsets(nLeft6, 386, nRight6, 551)
		self.wndMain:FindChild("LeftFlairTitle"):SetText(Apollo.GetString("MountScreen_SideFlair"))
	else
		eTableToUse = self.ktGroundMountFlairWindows
		bCanCustomize = PetCustomizationLib.CanCustomize(1, tMountTierData.nTierSpellId)
		objPetCustomization = PetCustomizationLib.GetCustomization(1, tMountTierData.nTierSpellId)
		self.wndMain:FindChild("CustomizeRightBG"):Show(true)
		self.wndMain:FindChild("MouseBlocker3"):Show(true)
		self.wndMain:FindChild("CustomizeBackBG"):SetAnchorOffsets(nLeft, 161, nRight, 306)
		self.wndMain:FindChild("CustomizeFrontBG"):SetAnchorOffsets(nLeft2, 14, nRight2, 159)
		self.wndMain:FindChild("CustomizeLeftBG"):SetAnchorOffsets(nLeft3, 309, nRight3, 454)
		self.wndMain:FindChild("MouseBlocker1"):SetAnchorOffsets(nLeft4, 0, nRight4, 108)
		self.wndMain:FindChild("MouseBlocker2"):SetAnchorOffsets(nLeft5, 148, nRight5, 256)
		self.wndMain:FindChild("MouseBlocker4"):SetAnchorOffsets(nLeft6, 296, nRight6, 404)
		self.wndMain:FindChild("LeftFlairTitle"):SetText(Apollo.GetString("MountScreen_LeftFlair"))
	end

	-- Costume Preview
	self.wndMain:FindChild("MountName"):SetText(tMountData.strName)
	self.wndMain:FindChild("MountPortrait"):SetCostumeToCreatureId(tMountTierData.nPreviewCreatureId)
	self.wndMain:FindChild("MountPortrait"):SetCamera("Paperdoll")
	if tMountTierData.bIsHoverboard then
		self.wndMain:FindChild("MountPortrait"):SetAttachment(PetCustomizationLib.HoverboardAttachmentPoint, tMountTierData.nPreviewHoverboardItemDisplay)
	end
	self.wndMain:FindChild("MountPortrait"):SetModelSequence(150)
	self.wndMain:FindChild("MountCanCustomizeBlockers"):Show(not bCanCustomize)

	if not bCanCustomize then
		return
	end

	-- Detect previous flairs
	for strWindowName, tTableData in pairs(eTableToUse) do
		local eFlairType = tTableData[1]
		local eCurrSlot = tTableData[2]
		local strHeaderLabel = tTableData[3]
		local tCurrFlairInThatSlot = objPetCustomization:GetSlotFlair(eCurrSlot)

		-- 4x Flair Lists (Front, Back, Left, Right)
		local wndFlairList = self.wndMain:FindChild(strWindowName)
		wndFlairList:DestroyChildren()

		-- Flair Header
		--local wndHeader = Apollo.LoadForm("MountCustomization.xml", "CustomizeFrontLabel", wndFlairList, self)
		--wndHeader:SetText(strHeaderLabel)

		-- Flair Items
		for idx, tFlairData in pairs(PetCustomizationLib.GetUnlockedPetFlairByType(eFlairType) or {}) do
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "CustomizeFlairItem", wndFlairList, self)
			wndCurr:FindChild("CustomizeFlairBtn"):SetData({ tFlairData, tTableData[2], objPetCustomization, wndFlairList })
			wndCurr:FindChild("CustomizeFlairBtn"):SetCheck(tCurrFlairInThatSlot and tCurrFlairInThatSlot:GetId() == tFlairData:GetId())
			wndCurr:FindChild("CustomizeFlairBtn"):SetTooltip(tFlairData:GetTooltip())
			--wndCurr:FindChild("CustomizeFlairBtn"):AttachWindow(wndCurr:FindChild("CustomizeFlairCheck"))
			--wndCurr:FindChild("CustomizeFlairIcon"):SetSprite(tFlairData:GetIconPath())

			if eFlairType ~= PetCustomizationLib.PetFlairType_GroundMountSide then
				wndCurr:FindChild("CustomizeFlairBtn"):SetText(tFlairData:GetName() or "")
			else
				wndCurr:FindChild("CustomizeFlairBtn"):SetText((tFlairData:GetName() .. " (" .. tFlairData:GetUnlockCount() .. ")") or "")
				if tFlairData:GetUnlockCount() == 1 then
					if tCurrFlairInThatSlot == nil or tCurrFlairInThatSlot:GetId() ~= tFlairData:GetId() then
						local eOtherSideSlot = eCurrSlot == PetCustomizationLib.MountSlot.Left and PetCustomizationLib.MountSlot.Right or PetCustomizationLib.MountSlot.Left
						local tOtherSideFlair = objPetCustomization:GetSlotFlair(eOtherSideSlot)
						if tOtherSideFlair and tOtherSideFlair:GetId() == tFlairData:GetId() then
							wndCurr:FindChild("CustomizeFlairBtn"):Enable(false)
							wndCurr:SetTooltip(Apollo.GetString("MountCustomization_FlairAlreadyAssigned"))
						end
					end
				end
			end
		end

		if tCurrFlairInThatSlot then
			self.wndMain:FindChild("MountPortrait"):SetAttachment(objPetCustomization:GetPreviewAttachSlot(eCurrSlot), tCurrFlairInThatSlot:GetItemDisplay(eCurrSlot))
		end

		wndFlairList:ArrangeChildrenVert(0)
		wndFlairList:Show(#wndFlairList:GetChildren() > 0)
	end
end

-----------------------------------------------------------------------------------------------
-- Interaction
-----------------------------------------------------------------------------------------------

function MountScreen:OnMountItemClick(wndHandler, wndControl) -- MountItemMouseCatcher
	for idx, wndCurr in pairs(self.wndMain:FindChild("StableList"):GetChildren()) do
		if wndCurr:FindChild("MountItemMouseCatcherArt") then
			wndCurr:FindChild("MountItemMouseCatcherArt"):Show(false)
		end
	end
	wndHandler:FindChild("MountItemMouseCatcherArt"):Show(true)

	self.tLastSelectedData = wndHandler:GetData()
	self:DrawNewMount(wndHandler:GetData())
end

function MountScreen:OnCustomizeFlairCheck(wndHandler, wndControl) -- CustomizeFlairBtn, data is { tFlairData, nSlotIndex }
	local objFlair = wndHandler:GetData()[1]
	local eCustomizationSlot = wndHandler:GetData()[2]
	local objPetCustomization = wndHandler:GetData()[3]
	local wndFlairList = wndHandler:GetData()[4]
	objPetCustomization:SetFlairInSlot(objFlair, eCustomizationSlot)

	-- Update the preview window
	self.wndMain:FindChild("MountPortrait"):SetAttachment(objPetCustomization:GetPreviewAttachSlot(eCustomizationSlot), objFlair:GetItemDisplay(eCustomizationSlot))

	local objPrevFlair = nil
	-- Uncheck other buttons (can't use global radio group as there's 4 buckets)
	for idx, wndCurr in pairs(wndFlairList:GetChildren()) do
		if wndCurr and wndCurr:FindChild("CustomizeFlairBtn") then
			if wndCurr:FindChild("CustomizeFlairBtn"):IsChecked() and wndCurr:FindChild("CustomizeFlairBtn") ~= wndHandler then
				objPrevFlair = wndCurr:FindChild("CustomizeFlairBtn"):GetData()[1]
			end
			wndCurr:FindChild("CustomizeFlairBtn"):SetCheck(wndCurr:FindChild("CustomizeFlairBtn") == wndHandler)
		end
	end

	local nUnlockCount = objFlair:GetUnlockCount()
	local nPrevUnlockCount = objPrevFlair and objPrevFlair:GetUnlockCount() or 0
	if objFlair:GetFlairType() == PetCustomizationLib.PetFlairType_GroundMountSide and (nUnlockCount == 1 or nPrevUnlockCount == 1) then
		local wndOtherFlairList = nil
		if eCustomizationSlot == PetCustomizationLib.MountSlot.Left then
			wndOtherFlairList = self.wndMain:FindChild("CustomizeRightList")
		elseif eCustomizationSlot == PetCustomizationLib.MountSlot.Right then
			wndOtherFlairList = self.wndMain:FindChild("CustomizeLeftList")
		end

		for idx, wndCurr in pairs(wndOtherFlairList:GetChildren()) do
			local wndCustomizeBtn = wndCurr:FindChild("CustomizeFlairBtn")
			if wndCustomizeBtn then
				if nUnlockCount == 1 and wndCustomizeBtn:GetData()[1] == objFlair then
					wndCustomizeBtn:Enable(false)
					wndCurr:SetTooltip(Apollo.GetString("MountCustomization_FlairAlreadyAssigned"))
				end

				if nPrevUnlockCount == 1 and wndCustomizeBtn:GetData()[1] == objPrevFlair then
					wndCustomizeBtn:Enable(true)
				end
			end
		end
	end
end

function MountScreen:OnCustomizeFlairUncheck(wndHandler, wndControl) -- CustomizeFlairBtn, data is { tFlairData, nSlotIndex }
	local objFlair = wndHandler:GetData()[1]
	local eCustomizationSlot = wndHandler:GetData()[2]
	local objPetCustomization = wndHandler:GetData()[3]
	objPetCustomization:ClearFlairInSlot(eCustomizationSlot)

	-- Update the preview window
	self.wndMain:FindChild("MountPortrait"):SetAttachment(objPetCustomization:GetPreviewAttachSlot(eCustomizationSlot), 0)

	if objFlair:GetFlairType() == PetCustomizationLib.PetFlairType_GroundMountSide and objFlair:GetUnlockCount() == 1 then
		local wndOtherFlairList = nil
		if eCustomizationSlot == PetCustomizationLib.MountSlot.Left then
			wndOtherFlairList = self.wndMain:FindChild("CustomizeRightList")
		elseif eCustomizationSlot == PetCustomizationLib.MountSlot.Right then
			wndOtherFlairList = self.wndMain:FindChild("CustomizeLeftList")
		end

		for idx, wndCurr in pairs(wndOtherFlairList:GetChildren()) do
			local wndCustomizeBtn = wndCurr:FindChild("CustomizeFlairBtn")
			if wndCustomizeBtn and wndCustomizeBtn:GetData()[1] == objFlair then
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

local MountScreenInst = MountScreen:new()
MountScreenInst:Init()
