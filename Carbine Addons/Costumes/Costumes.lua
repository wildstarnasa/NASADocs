-----------------------------------------------------------------------------------------------
-- Client Lua Script for Costumes
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "GameLib"
require "CostumesLib"
require "HousingLib"
require "Item"
require "Costume"


local Costumes = {}

local knNumCostumes = 10
local knCostumeBtnHolderBuffer = 45
local knDisplayedItemCount = 8
local knResetDyeId = 0
local knEmptySlotId = -1
local knEquipmentCostumeIndex = 0
local knStaticAnimationValue = 5612
local knTokenItemId = 50763

local kstrDyeSpriteBase = "CRB_DyeRampSprites:sprDyeRamp_"

local knXCursorOffset = 10
local knYCursorOffset = 25

local ktManneqinIds =
{
	[Unit.CodeEnumGender.Male] = 47305,
	[Unit.CodeEnumGender.Female] = 56135,
}

local knWeaponModelId = 70573

local keOverlayType =
{
	["None"] = 0,
	["UndoClose"] = 1,
	["UndoSwap"] = 2,
	["RemoveItem"] = 3,
	["Error"] = 4,
}

local karCostumeSlots =
{
	GameLib.CodeEnumItemSlots.Weapon,
	GameLib.CodeEnumItemSlots.Head,
	GameLib.CodeEnumItemSlots.Shoulder,
	GameLib.CodeEnumItemSlots.Chest,
	GameLib.CodeEnumItemSlots.Hands,
	GameLib.CodeEnumItemSlots.Legs,
	GameLib.CodeEnumItemSlots.Feet,
}

local ktSlotToString =
{
	[GameLib.CodeEnumItemSlots.Weapon] 		= "CRB_Weapon",
	[GameLib.CodeEnumItemSlots.Head] 		= "InventorySlot_Head",
	[GameLib.CodeEnumItemSlots.Shoulder] 	= "InventorySlot_Shoulder",
	[GameLib.CodeEnumItemSlots.Chest] 		= "InventorySlot_Chest",
	[GameLib.CodeEnumItemSlots.Hands] 		= "InventorySlot_Hands",
	[GameLib.CodeEnumItemSlots.Legs] 		= "InventorySlot_Legs",
	[GameLib.CodeEnumItemSlots.Feet] 		= "InventorySlot_Feet",
}

local ktItemSlotToEquippedItems =
{
	[GameLib.CodeEnumEquippedItems.Chest] = 		GameLib.CodeEnumItemSlots.Chest, 
	[GameLib.CodeEnumEquippedItems.Legs] = 			GameLib.CodeEnumItemSlots.Legs,
	[GameLib.CodeEnumEquippedItems.Head] = 			GameLib.CodeEnumItemSlots.Head,
	[GameLib.CodeEnumEquippedItems.Shoulder] = 		GameLib.CodeEnumItemSlots.Shoulder,
	[GameLib.CodeEnumEquippedItems.Feet] = 			GameLib.CodeEnumItemSlots.Feet,
	[GameLib.CodeEnumEquippedItems.Hands] = 		GameLib.CodeEnumItemSlots.Hands,
	[GameLib.CodeEnumEquippedItems.WeaponPrimary] = GameLib.CodeEnumItemSlots.Weapon,
}

local ktItemSlotToCamera =
{
	[GameLib.CodeEnumItemSlots.Chest] 		= "Armor_Chest",
	[GameLib.CodeEnumItemSlots.Legs] 		= "Armor_Pants",
	[GameLib.CodeEnumItemSlots.Head] 		= "Armor_Head",
	[GameLib.CodeEnumItemSlots.Shoulder] 	= "Armor_Shoulders",
	[GameLib.CodeEnumItemSlots.Feet] 		= "Armor_Boots",
	[GameLib.CodeEnumItemSlots.Hands] 		= "Armor_Gloves",
}

local ktItemCategoryToCamera =
{
	[8] = "Weapon_Sword2H",
	[12] = "Weapon_Resonator",
	[16] = "Weapon_Pistols1H",
	[22] = "Weapon_Psyblade",
	[24] = "Weapon_Claws",
	[108] = "Weapon_Launcher",
}

local ktClassToWeaponCamera =
{
	[GameLib.CodeEnumClass.Warrior] 		= "Weapon_Sword2H",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Weapon_Pistols1H",
	[GameLib.CodeEnumClass.Stalker] 		= "Weapon_Claws",
	[GameLib.CodeEnumClass.Esper] 			= "Weapon_Psyblade",
	[GameLib.CodeEnumClass.Engineer] 		= "Weapon_Launcher",
	[GameLib.CodeEnumClass.Medic] 			= "Weapon_Resonator",
}

local ktUnlockFailureStrings =
{
	[CostumesLib.CostumeUnlockResult.AlreadyKnown] 			= Apollo.GetString("Costumes_AlreadyUnlocked"),
	[CostumesLib.CostumeUnlockResult.OutOfSpace] 			= Apollo.GetString("Costumes_TooManyItems"),
	[CostumesLib.CostumeUnlockResult.UnknownFailure] 		= Apollo.GetString("Costumes_UnknownError"),
	[CostumesLib.CostumeUnlockResult.ForgetItemFailed] 		= Apollo.GetString("Costumes_UnknownError"),
	[CostumesLib.CostumeUnlockResult.FailedPrerequisites] 	= Apollo.GetString("Costumes_InvalidItem"),
	[CostumesLib.CostumeUnlockResult.InsufficientCredits] 	= Apollo.GetString("Costumes_NeedMoreCredits"),
	[CostumesLib.CostumeUnlockResult.ItemInUse] 			= Apollo.GetString("Costumes_ItemInUse"),
	[CostumesLib.CostumeUnlockResult.ItemNotKnown] 			= Apollo.GetString("Costumes_ItemNotUnlocked"),
	[CostumesLib.CostumeUnlockResult.InvalidItem] 			= Apollo.GetString("Costumes_ItemNotUnlocked"),
}

local ktSaveFailureStrings =
{
	[CostumesLib.CostumeSaveResult.InvalidCostumeIndex] 	= Apollo.GetString("Costumes_InvalidCostume"),
	[CostumesLib.CostumeSaveResult.CostumeIndexNotUnlocked] = Apollo.GetString("Costumes_InvalidCostume"),
	[CostumesLib.CostumeSaveResult.UnknownMannequinError] 	= Apollo.GetString("Costumes_UnknownError"),
	[CostumesLib.CostumeSaveResult.ItemNotUnlocked] 		= Apollo.GetString("Costumes_SaveItemInvalid"),
	[CostumesLib.CostumeSaveResult.InvalidItem] 			= Apollo.GetString("Costumes_SaveItemInvalid"),
	[CostumesLib.CostumeSaveResult.UnusableItem] 			= Apollo.GetString("Costumes_SaveItemInvalid"),
	[CostumesLib.CostumeSaveResult.InvalidDye] 				= Apollo.GetString("Costumes_SaveDyeInvalid"),
	[CostumesLib.CostumeSaveResult.DyeNotUnlocked] 			= Apollo.GetString("Costumes_SaveDyeInvalid"),
	[CostumesLib.CostumeSaveResult.NotEnoughTokens] 		= Apollo.GetString("Costumes_CantAfford"),
	[CostumesLib.CostumeSaveResult.InsufficientFunds] 		= Apollo.GetString("Costumes_CantAfford"),
	[CostumesLib.CostumeSaveResult.UnknownError] 			= Apollo.GetString("Costumes_UnknownError"),
}

local ktItemQualityToColor =
{
	[Item.CodeEnumItemQuality.Average] 		= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 		= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent]	= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 		= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 	= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact] 	= ApolloColor.new("ItemQuality_Artifact"),
	[Item.CodeEnumItemQuality.Inferior] 	= ApolloColor.new("ItemQuality_Inferior"),
}

function Costumes:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Costumes:Init()
	Apollo.RegisterAddon(self)
end

function Costumes:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Costumes.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Costumes:OnDocumentReady()
	if not self.xmlDoc then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 				"OnInterfaceMenuLoaded", self)
	
	Apollo.RegisterEventHandler("GenericEvent_OpenCostumes", 				"OnInit", self)
	Apollo.RegisterEventHandler("HousingMannequinOpen",						"OnMannequinInit", self)
	
	Apollo.RegisterEventHandler("CostumeForgetResult",						"OnForgetResult", self)
	Apollo.RegisterEventHandler("GenericEvent_CostumeUnlock",				"OnItemUnlock", self)
	Apollo.RegisterEventHandler("CostumeUnlockResult",						"OnUnlockResult", self)
	Apollo.RegisterEventHandler("AppearanceChanged", 						"RedrawCostume", self)
	
	Apollo.RegisterEventHandler("CostumeSet", 								"OnCostumeChanged", self)
	
	Apollo.RegisterEventHandler("CostumeSaveResult",						"OnSaveResult", self)
	
	Apollo.RegisterEventHandler("HousingMannequinClose",					"OnClose", self)
	Apollo.RegisterEventHandler("CloseVendorWindow",						"OnClose", self)
	Apollo.RegisterEventHandler("ChangeWorld",								"OnConfirmClose", self)
	
	self.eSelectedSlot = nil
	self.costumeDisplayed = nil
	self.tEquipmentMap = {}
	self.tCostumeSlots = {}
	self.tKnownDyes = {}
	self.tSelectedDyeChannels = {}
	self.tUnlockedItems = {}
	self.nUnlockedCostumeCount = 0
	self.bUseToken = false
	self.bAutoEquip = false
	self.bIsSheathed = false
	self.nDisplayedCostumeId = nil
	self.nSelectedCostumeId = nil
	self.strSelectedCostumeName = ""
	
	self.unitPlayer = nil
	
	-- Saves Dye ids
	self.tCurrentDyes = 
	{
		[GameLib.CodeEnumItemSlots.Head] 		= {0,0,0},
		[GameLib.CodeEnumItemSlots.Shoulder] 	= {0,0,0},
		[GameLib.CodeEnumItemSlots.Chest]		= {0,0,0},
		[GameLib.CodeEnumItemSlots.Hands] 		= {0,0,0},
		[GameLib.CodeEnumItemSlots.Legs] 		= {0,0,0},
		[GameLib.CodeEnumItemSlots.Feet] 		= {0,0,0},
		[GameLib.CodeEnumItemSlots.Weapon]		= {0,0,0},
	}
end

function Costumes:OnInterfaceMenuLoaded()
	local tData = {"GenericEvent_OpenCostumes", "", "Icon_Windows32_UI_CRB_InterfaceMenu_MountCustomization"}
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("Costumes_Title"), tData)
end

----------------------
-- Setup
----------------------
function Costumes:OnInit()
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 	"MapEquipment", self)
	Apollo.RegisterEventHandler("DyeLearned",					"OnDyeLearned", self)
	
	if self.wndMain then
		self:OnConfirmClose()
	end
	
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "CharacterWindow", nil, self)
	self.wndPreview = self.wndMain:FindChild("Right:Costume")
	
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Costumes_Title"), nSaveVersion = 2})
	
	-- Set up the costume controls
	self.nDisplayedCostumeId = CostumesLib.GetCostumeIndex()
	self.costumeDisplayed = CostumesLib.GetCostume(self.nDisplayedCostumeId)
	self.unitPlayer = GameLib.GetPlayerUnit()
	
	self:SharedInit()
	
	-- Setup the costume selection list
	local wndDropdownBtn = self.wndMain:FindChild("Left:SelectCostumeWindowToggle")
	local wndSelectionFrame = self.wndMain:FindChild("Left:CostumeBtnHolder")
	local wndCostumeSelectionList = wndSelectionFrame:FindChild("Framing")
	
	local wndDefaultCostumeBtn = Apollo.LoadForm(self.xmlDoc, "CostumeBtn", wndCostumeSelectionList, self)
	wndDefaultCostumeBtn:SetText(Apollo.GetString("Character_ClearBtn"))
	wndDefaultCostumeBtn:SetNormalTextColor(ApolloColor.new("AddonError"))
	wndDefaultCostumeBtn:ChangeArt("BK3:btnHolo_ListView_Top")
	wndDefaultCostumeBtn:SetData(knEquipmentCostumeIndex)
	
	self.nUnlockedCostumeCount = CostumesLib.GetCostumeCount()

	local strLabel = self.nDisplayedCostumeId > knEquipmentCostumeIndex and Apollo.GetString("EngravingStation_Equipped") or Apollo.GetString("Character_ClearBtn")
	for idx = 1, self.nUnlockedCostumeCount do
		local wndCostumeBtn = Apollo.LoadForm(self.xmlDoc, "CostumeBtn", wndCostumeSelectionList, self)
		local strLabel = String_GetWeaselString(Apollo.GetString("Character_CostumeNum"), idx)
		wndCostumeBtn:SetText(strLabel)
		wndCostumeBtn:SetData(idx)
		
		if idx == self.nUnlockedCostumeCount then
			wndCostumeBtn:ChangeArt("BK3:btnHolo_ListView_Btm")
		end
		
		if self.nDisplayedCostumeId == idx then
			wndCostumeBtn:SetCheck(true)
			wndDropdownBtn:SetText(strLabel)
			strLabel = String_GetWeaselString(Apollo.GetString("Costumes_EquipCostume"), strLabel)
		end
	end
	
	wndCostumeSelectionList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	
	local nLeft, nTop, nRight, nBottom = wndSelectionFrame:GetAnchorOffsets()
	wndSelectionFrame:SetAnchorOffsets(nLeft, nTop, nRight, nTop + knCostumeBtnHolderBuffer + (wndDefaultCostumeBtn:GetHeight() * (self.nUnlockedCostumeCount + 1)))
	
	wndDropdownBtn:AttachWindow(wndSelectionFrame)
	
	self:HelperToggleEquippedBtn()
	self:MapEquipment()
	self:RedrawCostume()
end

function Costumes:OnMannequinInit()
	Apollo.RegisterEventHandler("DyeLearned",	"OnDyeLearned", self)

	if self.wndMain then
		self:OnConfirmClose()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "CharacterWindow", nil, self)
	self.wndPreview = self.wndMain:FindChild("Right:Costume")

	self.wndMain:FindChild("Border:Title"):SetText(Apollo.GetString("Housing_MannequinTitle"))

	self.unitPlayer = GameLib.GetTargetUnit()
	self.costumeDisplayed = CostumesLib.GetActiveMannequinCostume()

	self:SharedInit()

	self:RedrawCostume()

	local wndLeftControls = self.wndMain:FindChild("Left")
	wndLeftControls:FindChild("NoCostumeBlocker"):Show(false)
	wndLeftControls:FindChild("SelectCostumeWindowToggle"):Show(false)
	wndLeftControls:FindChild("CostumeBtnHolder"):Show(false)

	local tPoseList = HousingLib.GetMannequinPoseList()
	local idCurrentPose = HousingLib.GetMannequinPose()

	self.wndPreview:SetModelSequence(tPoseList[idCurrentPose].nModelSequence)

	local wndRightControls = self.wndMain:FindChild("Right")
	local wndDropdownBtn = wndLeftControls:FindChild("SelectCostumeWindowToggle")
	local wndPoseContainer = wndLeftControls:FindChild("CostumeBtnHolder")
	local wndPoseSelectionList = wndPoseContainer:FindChild("Framing")

	wndDropdownBtn:Show(true)

	local wndPoseHeight = nil
	local nPoseCount = 0
	for idPose, tPoseInfo in pairs(tPoseList) do
		local wndPoseBtn = Apollo.LoadForm(self.xmlDoc, "MannequinPoseEntry", wndPoseSelectionList, self)
		local strLabel = tPoseInfo.strPoseName
		wndPoseBtn:SetText(strLabel)
		wndPoseBtn:SetData(tPoseInfo)

		if idPose == nUnlockedCostumeCount then
			wndPoseBtn:SetArt("BK3:btnHolo_ListView_Btm")
		end

		if idCurrentPose == idPose then
			wndPoseBtn:SetCheck(true)
			wndDropdownBtn:SetText(strLabel)
		end

		if not wndPoseHeight then
			wndPoseHeight = wndPoseBtn:GetHeight()
		end

		nPoseCount = nPoseCount + 1
	end
	
	wndPoseSelectionList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)

	local nLeft, nTop, nRight, nBottom = wndPoseContainer:GetAnchorOffsets()
	wndPoseContainer:SetAnchorOffsets(nLeft, nTop, nRight, nTop + knCostumeBtnHolderBuffer + (wndPoseHeight * nPoseCount))

	wndDropdownBtn:AttachWindow(wndPoseContainer)
	
	self.wndMain:FindChild("EquipBtn"):Show(false)
end

-- This is part of both normal and mannequin init functions.
function Costumes:SharedInit()
	Event_FireGenericEvent("GenerciEvent_CostumesWindowOpened")

	local wndCostumeContainer = self.wndMain:FindChild("CostumeListContainer")
	local wndSpacer = Apollo.LoadForm(self.xmlDoc, "CostumeEntrySpacer", wndCostumeContainer, self)

	wndSpacer:FindChild("DyeColumn1"):SetData(1)
	wndSpacer:FindChild("DyeColumn2"):SetData(2)
	wndSpacer:FindChild("DyeColumn3"):SetData(3)

	local nUnlockedCount = CostumesLib.GetUnlockItemCount().nCurrent
	for idx = 1, #karCostumeSlots do
		local eSlotId = karCostumeSlots[idx]
		local wndCostumeEntry = Apollo.LoadForm(self.xmlDoc, "CostumeEntryForm", wndCostumeContainer, self)
		local wndEmptyCostumeSlot = wndCostumeEntry:FindChild("EmptySlotControls")
		wndEmptyCostumeSlot:FindChild("CostumePieceTitle"):SetText(Apollo.GetString(ktSlotToString[eSlotId]))

		if eSlotId == GameLib.CodeEnumItemSlots.Weapon then
			wndCostumeEntry:FindChild("VisibleBtn"):Show(false)
		end

		local tSlotData =
		{
			eSlot = eSlotId,
			wndCostumeItem = wndCostumeEntry,
		}

		wndCostumeEntry:FindChild("VisibleBtn"):SetData(eSlotId)
		wndCostumeEntry:FindChild("FilledSlotControls:CostumeSlot"):SetData(tSlotData)
		wndCostumeEntry:FindChild("EmptySlotControls:SlotEmptyBtn"):SetData(tSlotData)

		self.tUnlockedItems[eSlotId] = CostumesLib.GetUnlockedSlotItems(eSlotId, 0, nUnlockedCount)
		self.tCostumeSlots[eSlotId] = wndCostumeEntry
	end

	wndCostumeContainer:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)

	local wndCostumeList = self.wndMain:FindChild("CostumeList")
	for idx = 1, knDisplayedItemCount do
		local wndDisplay = Apollo.LoadForm(self.xmlDoc, "CostumeListItem", wndCostumeList, self)
		wndDisplay:Show(false)
	end

	wndCostumeList:ArrangeChildrenTiles(Window.CodeEnumArrangeOrigin.LeftOrTop)

	self.wndMain:FindChild("Right:SetSheatheBtn"):SetCheck(self.bIsSheathed)
	self.wndPreview:SetSheathed(self.bIsSheathed)

	self.wndMain:FindChild("Footer:SubmitBtn"):Enable(false)

	self:HideContentContainer()

	if CostumesLib.GetUnlockItemCount().nCurrent > 0 then
		self:SetHelpString(Apollo.GetString("Costumes_DefaultHelper"))
	else
		self:SetHelpString(Apollo.GetString("Costumes_NoUnlockedItems"))
	end
	
	self:CheckForTokens()
end

----------------------
-- Costumes
----------------------
function Costumes:OnCostumeBtnChecked(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	self.nSelectedCostumeId = wndHandler:GetData()
	self.strSelectedCostumeName = wndHandler:GetText()
	
	if self.costumeDisplayed and self.costumeDisplayed:HasChanges() then
		self:ToggleOverlay(keOverlayType.UndoSwap)
	else
		self:SwapCostume()
	end
end

function Costumes:SwapCostume()
	self.nDisplayedCostumeId = self.nSelectedCostumeId
	self.costumeDisplayed = CostumesLib.GetCostume(self.nDisplayedCostumeId)

	self.wndMain:FindChild("Left:CostumeBtnHolder"):Show(false)
	self.wndMain:FindChild("Left:SelectCostumeWindowToggle"):SetText(self.strSelectedCostumeName)

	self:HelperToggleEquippedBtn()
	
	self.tSelectedDyeChannels = {}
	
	self:ToggleOverlay(keOverlayType.None)
	self:ResetChannelControls()
	self:HideContentContainer()
	self:RedrawCostume()
end

function Costumes:RedrawCostume()
	if not self.wndMain then
		return
	end

	self.wndPreview:SetCostume(self.unitPlayer)
	
	if self.costumeDisplayed then
		for idx = 1, #karCostumeSlots do
			local eSlot = karCostumeSlots[idx]
			local itemEquipped = self.costumeDisplayed:GetSlotItem(eSlot) 
			local bIsVisible = self.costumeDisplayed:IsSlotVisible(eSlot)

			if itemEquipped then
				self:FillSlot(eSlot, bIsVisible, itemEquipped)
			else
				self:EmptySlot(eSlot, bIsVisible)
			end
			
			self.tCostumeSlots[eSlot]:FindChild("VisibleBtn"):SetCheck(bIsVisible)
		end
		
		self.wndMain:FindChild("Left:NoCostumeBlocker"):Show(false)
		self.wndMain:FindChild("Left:CostumeListContainer"):Show(true)
	else
		self.wndMain:FindChild("Left:NoCostumeBlocker"):Show(true)
		self.wndMain:FindChild("Left:CostumeListContainer"):Show(false)
	end
	
	self:UpdateCost()
end

function Costumes:FillSlot(eSlot, bIsVisible, itemShown, bIsEquippedItem)
	local wndSlotFilled = self.tCostumeSlots[eSlot]:FindChild("FilledSlotControls")
	
	if itemShown then
		self.tCostumeSlots[eSlot]:FindChild("EmptySlotControls"):Show(false)
		wndSlotFilled:Show(true)
		
		local wndCostumeIcon = wndSlotFilled:FindChild("CostumeSlot:CostumeIcon")
		wndCostumeIcon:SetTooltipForm(nil)
		wndCostumeIcon:SetTooltipDoc(nil)
		wndCostumeIcon:SetBGColor(bIsEquippedItem and "UI_AlphaPercent25" or "UI_BtnBGDefault")
		
		local luaSubclass = wndCostumeIcon:GetWindowSubclass()
		luaSubclass:SetItem(itemShown)
		
		local tAvailableDyeChannels = itemShown:GetAvailableDyeChannel()
		local arAvailableDyeChannels =
		{
			tAvailableDyeChannels.bDyeChannel1,
			tAvailableDyeChannels.bDyeChannel2,
			tAvailableDyeChannels.bDyeChannel3,
		}
		
		local tDyeContainers =
		{
			wndSlotFilled:FindChild("DyeColor1Container"),
			wndSlotFilled:FindChild("DyeColor2Container"),
			wndSlotFilled:FindChild("DyeColor3Container"),
		}
		
		local arDyes = self.costumeDisplayed:GetSlotDyes(eSlot)
		for idx = 1, #tDyeContainers do
			local tDyeInfo = arDyes[idx]
			local wndDyeColor = tDyeContainers[idx]:FindChild("DyeColor" .. idx)
			
			tDyeContainers[idx]:FindChild("DyeSwatch"):SetSprite(tDyeInfo.nId > 0 and kstrDyeSpriteBase .. tDyeInfo.nRampIndex or "")
			tDyeContainers[idx]:SetData({eSlot = eSlot, nDyeChannel = idx, tDyeInfo = tDyeInfo,})
			self.tCurrentDyes[eSlot][idx] = tDyeInfo.nId or 0
			
			wndDyeColor:Enable(bIsVisible and arAvailableDyeChannels[idx])
			wndDyeColor:SetCheck(false)
		end
		
		if bIsVisible then
			self.wndPreview:SetItem(itemShown)
			self.wndPreview:SetItemDye(itemShown, arDyes[1].nId, arDyes[2].nId, arDyes[3].nId)
		else
			self.wndPreview:RemoveItem(eSlot)
		end
		
		self.tCostumeSlots[eSlot]:FindChild("VisibleBtn"):Enable(true)
		
		self:ClearSlotDyeSelection(eSlot)
		self:UpdateCost()
	end
end

function Costumes:EmptySlot(eSlot, bIsVisible)
	self.costumeDisplayed:SetSlotItem(eSlot, knEmptySlotId)
	
	if self.tEquipmentMap[eSlot] then
		self:FillSlot(eSlot, bIsVisible, self.tEquipmentMap[eSlot], true)
		return
	end
	self.wndPreview:RemoveItem(eSlot)
	
	local wndEmptySlotControls = self.tCostumeSlots[eSlot]:FindChild("EmptySlotControls")	
	self.tCostumeSlots[eSlot]:FindChild("FilledSlotControls"):Show(false)
	wndEmptySlotControls:Show(true)
	self.tCostumeSlots[eSlot]:FindChild("VisibleBtn"):Enable(false)
	
	self:ClearSlotDyeSelection(eSlot)
	
	self:UpdateCost()
end

function Costumes:OnSlotClick(wndHandler, wndControl, eMouseButton)
	if self.nDisplayedCostumeId == knEquipmentCostumeIndex then
		return
	end
	
	local eSlot = wndHandler:GetData().eSlot

	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		-- Remove the item
		self:SetHelpString(Apollo.GetString("Costumes_DefaultHelper"))
		self:HideContentContainer()
		
		local tSlotInfo = wndHandler:GetData()
		self:EmptySlot(eSlot, self.costumeDisplayed:IsSlotVisible(eSlot))
	else
		self:ShowCostumeContent()
		self.itemSelected = self.costumeDisplayed:GetSlotItem(eSlot)

		if self.eSelectedSlot ~= eSlot then
			self.eSelectedSlot = eSlot
			self.arDisplayedItems = self.tUnlockedItems[eSlot]
			table.sort(self.arDisplayedItems, function(a,b) return a:GetName() < b:GetName() end)
			self:HelperUpdatePageItems(1)
		end
	end
end

-- This should only be called if the player has a costume
function Costumes:OnVisibleBtnCheck(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local bVisible = wndHandler:IsChecked()
	local eSlot = wndHandler:GetData()
	local itemShown = nil
	
	-- Set the state
	self.costumeDisplayed:SetSlotVisible(eSlot, bVisible)
	
	-- Update the preview
	if not bVisible then
		self.wndPreview:RemoveItem(eSlot)
		self:ClearSlotDyeSelection(eSlot)
	else
		local itemShown = self.costumeDisplayed:GetSlotItem(eSlot) or self.tEquipmentMap[eSlot]
		local arDyes = self.costumeDisplayed:GetSlotDyes(eSlot)
		self.wndPreview:SetItem(itemShown)
		self.wndPreview:SetItemDye(itemShown, arDyes[1].nId, arDyes[2].nId, arDyes[3].nId)
	end
		
	-- Block the player from dying hidden slots
	local wndFilledSlot = wndHandler:GetParent():FindChild("FilledSlotControls")
	if wndFilledSlot:IsShown() then
		wndFilledSlot:FindChild("DyeColor1Container:DyeColor1"):Enable(bVisible)
		wndFilledSlot:FindChild("DyeColor2Container:DyeColor2"):Enable(bVisible)
		wndFilledSlot:FindChild("DyeColor3Container:DyeColor3"):Enable(bVisible)
		wndFilledSlot:FindChild("DyeColor1Container"):SetBGColor(bVisible and "UI_AlphaPercent100" or "UI_AlphaPercent50")
		wndFilledSlot:FindChild("DyeColor2Container"):SetBGColor(bVisible and "UI_AlphaPercent100" or "UI_AlphaPercent50")
		wndFilledSlot:FindChild("DyeColor3Container"):SetBGColor(bVisible and "UI_AlphaPercent100" or "UI_AlphaPercent50")
	end
	
	self:UpdateCost()
end

function Costumes:OnPreviewBtnChecked(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	self.itemSelected = wndHandler:GetData()
	
	self.wndPreview:SetItem(self.itemSelected)
	self.costumeDisplayed:SetSlotItem(self.eSelectedSlot, self.itemSelected:GetItemId())
	self:FillSlot(self.eSelectedSlot, true, self.itemSelected)
end

function Costumes:OnPageUp(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	self:HelperUpdatePageItems(wndHandler:GetData())
end

function Costumes:OnPageDown(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	self:HelperUpdatePageItems(wndHandler:GetData())
end

function Costumes:OnSearchContent(wndHandler, wndControl, strText)
	local wndSearchContainer = wndHandler:GetParent()
	local bHasText = strText ~= ""
	wndSearchContainer:FindChild("ClearBtn"):Show(bHasText)
	wndSearchContainer:FindChild("SearchIcon"):Show(not bHasText)
	
	local wndDyeList = self.wndMain:FindChild("Center:ContentContainer:DyeList")
	
	if self.wndMain:FindChild("Center:ContentContainer:CostumeWindows"):IsShown() then
		self.arDisplayedItems = {}
		for idx, itemInfo in pairs(self.tUnlockedItems[self.eSelectedSlot]) do
			if string.find(string.lower(itemInfo:GetName()), string.lower(strText)) then
				table.insert(self.arDisplayedItems, itemInfo)
			end
		end
		table.sort(self.arDisplayedItems, function(a,b) return a:GetName() < b:GetName() end)
		
		self:HelperUpdatePageItems(1)
	elseif wndDyeList:IsShown() then
		for idx, wndDye in pairs(wndDyeList:GetChildren()) do
			wndDye:Show(string.find(string.lower(wndDye:FindChild("DyeSwatchTitle"):GetText()), string.lower(strText)))
		end
		
		local nListHeight = wndDyeList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return a:GetData().nId == knResetDyeId or 
			(a:GetData().nId ~= knResetDyeId and b:GetData().nId ~= knResetDyeId and a:GetData().nId < b:GetData().nId) end)
		
		if nListHeight == 0 then
			self:SetHelpString(Apollo.GetString("Costumes_NoneFound"))
			self.wndMain:FindChild("HelpContentContainer"):Show(true)
		else
			self.wndMain:FindChild("HelpContentContainer"):Show(false)
		end
		
		wndDyeList:SetVScrollPos(0)
		wndDyeList:RecalculateContentExtents()
	end
end

function Costumes:OnClearSearch()
	local wndSearchBar = self.wndMain:FindChild("ContentSearch")
	wndSearchBar:SetText("")
	self:OnSearchContent(wndSearchBar, wndSearchBar, "")
end

-- Updates the items for the preview slots.
function Costumes:HelperUpdatePageItems(nPageNumber)	
	local wndContentContainer = self.wndMain:FindChild("Center:ContentContainer")
	local arPreviewWindows = wndContentContainer:FindChild("CostumeWindows:CostumeList"):GetChildren()
	
	-- If there are no items in the page we were given, go back to the highest page with items
	local nOffset = knDisplayedItemCount * (nPageNumber - 1)
	while nPageNumber > 0 and not self.arDisplayedItems[nOffset + 1] do
		nPageNumber = nPageNumber - 1
		nOffset = knDisplayedItemCount * (nPageNumber - 1)
	end
	
	for idx = 1, knDisplayedItemCount do
		local nItemIdx = nOffset + idx
		local wndItemPreview = arPreviewWindows[idx]
		local wndMannequin = wndItemPreview:FindChild("CostumeWindow")

		if self.arDisplayedItems[nItemIdx] then
			wndMannequin:SetData(self.arDisplayedItems[nItemIdx])
			wndItemPreview:SetData(self.arDisplayedItems[nItemIdx])
			
			local wndCostumeBtn = wndItemPreview:FindChild("CostumeListItemBtn")
			wndCostumeBtn:SetData(self.arDisplayedItems[nItemIdx])
			wndCostumeBtn:SetCheck(self.itemSelected and self.itemSelected:GetItemId() == self.arDisplayedItems[nItemIdx]:GetItemId())
			
			local wndCostume = wndItemPreview:FindChild("CostumeWindow")
			wndCostume:SetTooltipForm(nil)
			wndCostume:SetTooltipDoc(nil)
			
			wndItemPreview:Show(true)

			if self.eSelectedSlot == GameLib.CodeEnumItemSlots.Weapon then
				wndMannequin:SetCamera(ktClassToWeaponCamera[GameLib.GetPlayerUnit():GetClassId()])
				wndMannequin:SetCostumeToCreatureId(knWeaponModelId)
			else
				wndMannequin:SetCamera(ktItemSlotToCamera[self.eSelectedSlot])
				wndMannequin:SetCostumeToCreatureId(ktManneqinIds[self.unitPlayer:GetGender()])
			end

			wndMannequin:SetItem(self.arDisplayedItems[nItemIdx])
			wndMannequin:SetSheathed(false)
		else
			wndItemPreview:Show(false)
		end
	end
	
	wndContentContainer:FindChild("CostumeList"):ArrangeChildrenTiles(Window.CodeEnumArrangeOrigin.LeftOrTop)
	
	local wndPageUp = wndContentContainer:FindChild("PageUp")
	if self.arDisplayedItems[nOffset + knDisplayedItemCount + 1] then
		wndPageUp:SetData(nPageNumber + 1)
		wndPageUp:Enable(true)
	else
		wndPageUp:Enable(false)
	end
	
	local wndPageDown = wndContentContainer:FindChild("PageDown")
	wndPageDown:Enable(nPageNumber > 1)
	wndPageDown:SetData(nPageNumber - 1)
	
	-- if we somehow got to page 0, exit since there's no items
	if nPageNumber <= 0 then
		self.wndMain:FindChild("Center:HelpContentContainer"):Show(true)
		wndContentContainer:Show(false)
		self:SetHelpString(Apollo.GetString("Costumes_NoneFound"))
	else
		wndContentContainer:Show(true)
		self.wndMain:FindChild("Center:HelpContentContainer"):Show(false)
	end
end

function Costumes:MapEquipment()
	local arItems = GameLib:GetPlayerUnit():GetEquippedItems()
	self.tEquipmentMap = {}
	
	for idx = 1, #arItems do
		local eSlot = ktItemSlotToEquippedItems[arItems[idx]:GetSlot()]
		if eSlot then
			self.tEquipmentMap[eSlot] = arItems[idx]
		end
	end
end

function Costumes:OnCostumeChanged(idCostume)
	if self.unitPlayer and self.unitPlayer == GameLib.GetPlayerUnit() and self.wndMain then
		local wndCostumeBtn = self.wndMain:FindChild("Left:CostumeBtnHolder:Framing"):FindChildByUserData(idCostume)
		
		if wndCostumeBtn then
			self:OnCostumeBtnChecked(wndCostumeBtn, wndCostumeBtn)
		end
	end
end

----------------------
-- Dyes
----------------------
function Costumes:GetDyeList()
	local arDyes = GameLib.GetKnownDyes()
	local wndDyeList = self.wndMain:FindChild("Center:ContentContainer:DyeList")
	
	if not self.tKnownDyes[knResetDyeId] then
		local strName = Apollo.GetString("Costumes_RemoveDye")
		local wndRemoveDye = Apollo.LoadForm(self.xmlDoc, "DyeColorListItem", wndDyeList, self)
		local tInfo = {nId = knResetDyeId, nRampIndex = 0}
		
		wndRemoveDye:FindChild("DyeSwatchTitle"):SetText(strName)
		wndRemoveDye:FindChild("DyeSwatch"):Show(false)
		wndRemoveDye:SetData(tInfo)
		
		self.tKnownDyes[knResetDyeId] = true
	end
	
	for idx = 1, #arDyes do
		local tDyeInfo = arDyes[idx]
		
		if not self.tKnownDyes[tDyeInfo.nId] then
			local wndNewDye = Apollo.LoadForm(self.xmlDoc, "DyeColorListItem", wndDyeList, self)
			
			local strName = ""
			if tDyeInfo.strName and tDyeInfo.strName:len() > 0 then
				strName = tDyeInfo.strName
			else
				strName = String_GetWeaselString(Apollo.GetString("CRB_CurlyBrackets"), "", tDyeInfo.idDye)
			end
			
			wndNewDye:FindChild("DyeSwatch"):SetSprite(tDyeInfo.nId > 0 and kstrDyeSpriteBase .. tDyeInfo.nRampIndex or "")
			wndNewDye:FindChild("DyeSwatchTitle"):SetText(strName)
			wndNewDye:SetData(tDyeInfo)
			
			self.tKnownDyes[tDyeInfo.nId] = true
		end
	end
	
	-- Remove Dye is at the top of the list.  Everything after should be alphabetical.
	wndDyeList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return a:GetData().nId == knResetDyeId or 
		(a:GetData().nId ~= knResetDyeId and b:GetData().nId ~= knResetDyeId and a:GetData().nId < b:GetData().nId) end)
end

function Costumes:OnDyeChannelChecked(wndHandler, wndControl)
	self:GetDyeList()
	self:ShowDyeContent()
	
	local tSlotData = wndHandler:GetParent():GetData()
	local eSlot = tSlotData.eSlot
	
	if not self.tSelectedDyeChannels[eSlot] then
		self.tSelectedDyeChannels[eSlot] = {}
	end
	
	self.tSelectedDyeChannels[eSlot][tSlotData.nDyeChannel] = wndHandler:GetParent()
	
	local nFoundIndex = nil
	local nWindowHeight = nil
	
	local wndDyeList = self.wndMain:FindChild("DyeList")
	for idx, wndDye in pairs (wndDyeList:GetChildren()) do
		local bIsSelected = tSlotData.tDyeInfo.nId == wndDye:GetData().nId
		wndDye:FindChild("DyeColorBtn"):SetCheck(bIsSelected)
		
		if bIsSelected then
			nFoundIndex = idx
			nWindowHeight = wndDye:GetHeight()
		end
	end
	
	if nFoundIndex then
		wndDyeList:SetVScrollPos((nFoundIndex - 1) * nWindowHeight)
	end
end

function Costumes:OnDyeChannelDeselect(wndHandler, wndControl)
	local tSlotData = wndHandler:GetParent():GetData()
	wndHandler:SetCheck(false)
	
	self.tSelectedDyeChannels[tSlotData.eSlot][tSlotData.nDyeChannel] = nil
		
	local bIsEmpty = true
	
	for eSlot, tDyeChannels in pairs(self.tSelectedDyeChannels) do
		for nDyeChannel, idDye in pairs(tDyeChannels) do
			bIsEmpty = false
			break
		end
	end
	
	if bIsEmpty then
		self.tSelectedDyeChannels[tSlotData.eSlot] = nil
		self.wndMain:FindChild("Center:ContentContainer"):Show(false)
		self.wndMain:FindChild("Center:HelpContentContainer"):Show(true)
	end
	
end

function Costumes:OnSelectAllDyeChannel(wndHandler, wndControl)
	local nSlotChannel = wndHandler:GetData()
	
	for idx = 1, #karCostumeSlots do
		local wndFilledSlot = self.tCostumeSlots[karCostumeSlots[idx]]:FindChild("FilledSlotControls")
		local wndDyeColor = wndFilledSlot:FindChild("DyeColor" .. nSlotChannel .. "Container:DyeColor" .. nSlotChannel)
		
		if wndFilledSlot:IsShown() and wndDyeColor:IsEnabled() then
			wndDyeColor:SetCheck(true)
			self:OnDyeChannelChecked(wndDyeColor, wndDyeColor)
		end
	end
end

function Costumes:OnDeselectAllDyeChannel(wndHandler, wndControl)
	local nSlotChannel = wndHandler:GetData()
	
	for idx = 1, #karCostumeSlots do
		local wndFilledSlot = self.tCostumeSlots[karCostumeSlots[idx]]:FindChild("FilledSlotControls")
		local wndDyeColor = wndFilledSlot:FindChild("DyeColor" .. nSlotChannel .. "Container:DyeColor" .. nSlotChannel)
		
		if wndFilledSlot:IsShown() and wndDyeColor:IsEnabled() and wndDyeColor:IsChecked() then
			wndDyeColor:SetCheck(false)
			self:OnDyeChannelDeselect(wndDyeColor, wndDyeColor)
		end
	end
end

function Costumes:OnDyeColorChecked(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local tDyeInfo = wndHandler:GetParent():GetData()
	for eSlot, tDyeWindows in pairs(self.tSelectedDyeChannels) do
		local bSlotChanged = false
		for nDyeChannel, wndDye in pairs(tDyeWindows) do
			self:UpdateSlotDye(eSlot, nDyeChannel, tDyeInfo)
			
			bSlotChanged = true
		end
		
		if bSlotChanged then
			self:UpdateItemDye(eSlot)
		end
	end
	
	self:UpdateCost()
end

function Costumes:UpdateSlotDye(eSlot, nChannel, tDyeInfo)
	self.tCurrentDyes[eSlot][nChannel] = tDyeInfo.nId
	
	local wndDyeChannel = self.tCostumeSlots[eSlot]:FindChild("FilledSlotControls:DyeColor" .. nChannel .. "Container")
	wndDyeChannel:FindChild("DyeSwatchArtHack:DyeSwatch"):SetSprite(kstrDyeSpriteBase .. tDyeInfo.nRampIndex)
	wndDyeChannel:SetData({eSlot = eSlot, nDyeChannel = nChannel, tDyeInfo = tDyeInfo})
end

function Costumes:UpdateItemDye(eSlot)
	local itemDyed = self.costumeDisplayed:GetSlotItem(eSlot) or self.tEquipmentMap[eSlot]
	self.costumeDisplayed:SetSlotDyes(eSlot, self.tCurrentDyes[eSlot][1], self.tCurrentDyes[eSlot][2], self.tCurrentDyes[eSlot][3])
	self.wndPreview:SetItemDye(itemDyed, self.tCurrentDyes[eSlot][1], self.tCurrentDyes[eSlot][2], self.tCurrentDyes[eSlot][3])
end

function Costumes:ClearSlotDyeSelection(eSlot)
	if self.tSelectedDyeChannels[eSlot] then
		for nDyeChannel, wndDye in pairs(self.tSelectedDyeChannels[eSlot]) do
			self.tSelectedDyeChannels[eSlot][nDyeChannel]:FindChild("DyeColor" .. nDyeChannel):SetCheck(false)
		end
		self.tSelectedDyeChannels[eSlot] = nil
	end
end

function Costumes:ResetChannelControls()
	local wndSpacer = self.wndMain:FindChild("CostumeEntrySpacer")
	
	wndSpacer:FindChild("DyeColumn1"):SetCheck(false)
	wndSpacer:FindChild("DyeColumn2"):SetCheck(false)
	wndSpacer:FindChild("DyeColumn3"):SetCheck(false)
end

----------------------
-- Mannequin
----------------------
function Costumes:OnPoseCheck(wndHandler, wndControl)
	local tPoseData = wndHandler:GetData()
	
	HousingLib.SetMannequinPose(tPoseData.nId)
end

----------------------
-- Window Controls
----------------------
function Costumes:OnReset(wndHandler, wndControl)
	if self.costumeDisplayed then
		self.costumeDisplayed:DiscardChanges()
		self:HideContentContainer()
		self:ResetChannelControls()
	
		-- RedrawCostume updates the cost
		self:RedrawCostume()
	end
end

function Costumes:OnEquip(wndHandler, wndControl)
	CostumesLib.SetCostumeIndex(self.nDisplayedCostumeId)
	
	Event_FireGenericEvent("CostumeSet", self.nDisplayedCostumeId)
end

function Costumes:OnUndoAccept(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local eUnlockType = wndHandler:GetData()
	
	if eUnlockType == keOverlayType.UndoClose then
		self:OnConfirmClose()
	elseif eUnlockType == keOverlayType.UndoSwap then
		self:SwapCostume()
	end
end

function Costumes:OnWindowClosed()
	Event_FireGenericEvent("GenerciEvent_CostumesWindowClosed")
end

function Costumes:OnClose()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	if self.costumeDisplayed and self.costumeDisplayed:HasChanges() then
		self:ToggleOverlay(keOverlayType.UndoClose)
	else
		self:OnConfirmClose()
	end
end

function Costumes:OnConfirmClose()
	Apollo.RemoveEventHandler("PlayerEquippedItemChanged", self)
	Apollo.RemoveEventHandler("DyeLearned", self)
	
	self.eSelectedSlot = nil
	self.costumeDisplayed = nil
	self.tCostumeSlots = {}
	self.tSelectedDyeChannels = {}
	self.tKnownDyes = {}
	self.tEquipmentMap = {}
	self.tUnlockedItems = {}
	self.unitPlayer = nil
	self.bUseToken = false
	
	for eSlot, tChannels in pairs(self.tCurrentDyes) do
		self.tCurrentDyes[eSlot] = {0,0,0}
	end
	
	self:OnContextMenuClose()
	
	if self.wndMain then
		self.wndMain:Close()
		self.wndMain:Destroy()
		self.wndMain = nil
		self.wndPreview = nil
	end
	
	Event_CancelHousingMannequin()
end

function Costumes:OnCloseCancel()
	self:ToggleOverlay(keOverlayType.None)
	
	local wndFraming = self.wndMain:FindChild("Left:CostumeBtnHolder:Framing")
	
	if self.nSelectedCostumeId and self.nDisplayedCostumeId then
		wndFraming:FindChildByUserData(self.nDisplayedCostumeId):SetCheck(true)
		wndFraming:FindChildByUserData(self.nSelectedCostumeId):SetCheck(false)
	end
end

----------------------
-- DragDrop Handlers
----------------------
function Costumes:OnDragDropQuery(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if strType ~= "DDBagItem" then
		return
	end

	local itemDragged = Item.GetItemFromInventoryLoc(nValue)
	local eItemFamily = itemDragged:GetItemFamily()
	if eItemFamily ~= Item.CodeEnumItem2Family.Weapon and eItemFamily ~= Item.CodeEnumItem2Family.Armor and eItemFamily ~= Item.CodeEnumItem2Family.Costume then
		return Apollo.DragDropQueryResult.Invalid
	end

	return Apollo.DragDropQueryResult.Accept
end

function Costumes:OnDragDropEnd(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if strType ~= "DDBagItem" then
		return
	end

	local itemDragged = Item.GetItemFromInventoryLoc(nValue)
	
	self.bAutoEquip = true
	self:OnItemUnlock(itemDragged)
end


----------------------
-- Unlock Item Controls
----------------------
function Costumes:OnItemUnlock(itemUnlock)
	if not itemUnlock then
		return
	end

	local eItemFamily = itemUnlock:GetItemFamily()
	if eItemFamily ~= Item.CodeEnumItem2Family.Weapon and eItemFamily ~= Item.CodeEnumItem2Family.Armor and eItemFamily ~= Item.CodeEnumItem2Family.Costume then
		return
	end

	if self.wndUnlock then
		self:OnCloseUnlock()
	end

	self.wndUnlock = Apollo.LoadForm(self.xmlDoc, "UnlockConfirmation", nil, self)
	local tUnlockInfo = itemUnlock:GetCostumeUnlockInfo()
	local tUnlockedItemsCount = CostumesLib.GetUnlockItemCount()
	local luaSubclass = self.wndUnlock:FindChild("ItemIcon"):GetWindowSubclass()
	
	luaSubclass:SetItem(itemUnlock)

	local wndItemName = self.wndUnlock:FindChild("ItemName")
	wndItemName:SetText(itemUnlock:GetName())
	self.wndUnlock:FindChild("ItemName"):SetTextColor(ktItemQualityToColor[itemUnlock:GetItemQuality()])
	
	self.wndUnlock:FindChild("CashWindow"):SetAmount(tUnlockInfo.monUnlockCost)
	
	local wndConfirmBtn = self.wndUnlock:FindChild("ConfirmBtn")
	wndConfirmBtn:SetActionData(GameLib.CodeEnumConfirmButtonType.UnlockCostumeItem, itemUnlock:GetInventoryId())
	
	local strMessage = Apollo.GetString("Costumes_UnlockNotice")
	local crText = nil
	local bCanAfford = tUnlockInfo.monUnlockCost and GameLib.GetPlayerCurrency():GetAmount() > tUnlockInfo.monUnlockCost:GetAmount()
	if tUnlockInfo.bUnlocked then
		strMessage = Apollo.GetString("Costumes_AlreadyUnlocked")
		crText = ApolloColor.new("AddonError")
		wndConfirmBtn:Enable(false)
	elseif not tUnlockInfo.bCanUnlock then
		strMessage = Apollo.GetString("Costumes_InvalidItem")
		crText = ApolloColor.new("AddonError")
		wndConfirmBtn:Enable(false)
	elseif tUnlockedItemsCount.nCurrent >= tUnlockedItemsCount.nMax then
		strMessage = Apollo.GetString("Costumes_TooManyItems")
		crText = ApolloColor.new("AddonError")
		wndConfirmBtn:Enable(false)
	elseif not bCanAfford then
		strMessage = Apollo.GetString("Costumes_NeedMoreCredits")
		crText = ApolloColor.new("AddonError")
		self.wndUnlock:FindChild("CashWindow"):SetTextColor(crText)
		wndConfirmBtn:Enable(false)
	end
	
	local wndMessageText = self.wndUnlock:FindChild("MessageText")
	if strMessage then
		wndMessageText:SetText(strMessage)
	end
	
	if crText then
		wndMessageText:SetTextColor(crText)
	end

	local wndConfirmPreview = self.wndUnlock:FindChild("CostumeWindow")

	
	local eItemSlot = ktItemSlotToEquippedItems[itemUnlock:GetSlot()]
	if eItemSlot == GameLib.CodeEnumItemSlots.Weapon then
		wndConfirmPreview:SetCostumeToCreatureId(knWeaponModelId)
		wndConfirmPreview:SetCamera(ktItemCategoryToCamera[itemUnlock:GetItemCategory()] or ktClassToWeaponCamera[GameLib.GetPlayerUnit():GetClassId()])
	else
		wndConfirmPreview:SetCostumeToCreatureId(ktManneqinIds[GameLib.GetPlayerUnit():GetGender()])
		wndConfirmPreview:SetCamera(ktItemSlotToCamera[eItemSlot])
	end
	wndConfirmPreview:SetItem(itemUnlock)
	
	local wndItemCount = self.wndUnlock:FindChild("CostumeItemCount")
	local fFilledCostumePct = tUnlockedItemsCount.nCurrent / tUnlockedItemsCount.nMax
	
	wndItemCount:SetText(String_GetWeaselString(Apollo.GetString("Costumes_UnlockItemCount"), tUnlockedItemsCount.nCurrent, tUnlockedItemsCount.nMax))
	
	if fFilledCostumePct > .7 then
		wndItemCount:SetTextColor(ApolloColor.new("AddonWarning"))
	elseif fFilledCostumePct >= 1.0 then
		wndItemCount:SetTextColor(ApolloColor.new("AddonError"))
	end
	
	self.wndUnlock:Invoke()
end

function Costumes:OnCloseUnlock(wndHandler, wndControl)
	if self.wndUnlock then
		self.wndUnlock:Destroy()
		self.wndUnlock = nil
	end
end

function Costumes:OnUnlockResult(itemData, eResult)
	if self.wndMain then
		if eResult == CostumesLib.CostumeUnlockResult.UnlockSuccess then
			local eSlot = ktItemSlotToEquippedItems[itemData:GetSlot()]
			table.insert(self.tUnlockedItems[eSlot], itemData)

			if self.eSelectedSlot and self.eSelectedSlot == eSlot then
				local wndSearchBar = self.wndMain:FindChild("ContentSearch")
				self:OnSearchContent(wndSearchBar, wndSearchBar, wndSearchBar:GetText())
				self:HelperUpdatePageItems((self.wndMain:FindChild("PageDown"):GetData() or 0) + 1)

				self.wndMain:FindChild("UnlockConfirmFlash"):SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")
			end

			if self.bAutoEquip then
				self.costumeDisplayed:SetSlotItem(eSlot, itemData:GetItemId())
				self:FillSlot(eSlot, self.costumeDisplayed:IsSlotVisible(eSlot), itemData)
			end
		end
		
		if eResult ~= CostumesLib.CostumeUnlockResult.UnlockRequested then
			self.bAutoEquip = false
		end
	end

	if self.wndUnlock then
		local wndText = self.wndUnlock:FindChild("MessageText")

		if eResult == CostumesLib.CostumeUnlockResult.UnlockSuccess then
			self:OnCloseUnlock()
		elseif eResult == CostumesLib.CostumeUnlockResult.AlreadyKnown then
			wndText:SetText(Apollo.GetString("Costumes_AlreadyUnlocked"))
		elseif eResult == CostumesLib.CostumeUnlockResult.OutOfSpace then
			wndText:SetText(Apollo.GetString("Costumes_TooManyItems"))
		elseif eResult == CostumesLib.CostumeUnlockResult.InsufficientCredits then
			wndText:SetText(Apollo.GetString("Costumes_NeedMoreCredits"))
		end
	end

	if self.wndUnlockItems then
		if eResult == CostumesLib.CostumeUnlockResult.UnlockSuccess then
			self:BuildUnlockList()
			self.wndUnlockItems:FindChild("ConfirmFlash"):SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")
		end
	end
end

----------------------
-- Unlock List Controls
----------------------

function Costumes:OpenItemUnlock(wndHandler, wndControl)
	if self.wndUnlockItems then
		return
	end

	self.wndUnlockItems = Apollo.LoadForm(self.xmlDoc, "UnlockList", nil, self)

	self:BuildUnlockList()
end

function Costumes:BuildUnlockList()
	if not self.wndUnlockItems then
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	local arInventoryItems = unitPlayer:GetInventoryItems()
	local arItems = unitPlayer:GetEquippedItems()

	if #arInventoryItems > 0 then
		for idx = 1, #arInventoryItems do
			table.insert(arItems, arInventoryItems[idx].itemInBag)
		end
	end

	local wndItemList = self.wndUnlockItems:FindChild("ItemContainer")
	wndItemList:DestroyChildren()

	self.wndUnlockItems:FindChild("NoItemText"):Show(false)
	for idx, itemCurr in pairs(arItems) do
		local tUnlockInfo = itemCurr:GetCostumeUnlockInfo()
		if tUnlockInfo.bCanUnlock and not tUnlockInfo.bUnlocked then
			local wndItem = Apollo.LoadForm(self.xmlDoc, "UnlockItem", wndItemList, self)
			wndItem:SetData(itemCurr)

			local luaSubclass = wndItem:FindChild("ItemIcon"):GetWindowSubclass()
			luaSubclass:SetItem(itemCurr)

			local wndItemName = wndItem:FindChild("ItemName")
			wndItemName:SetText(itemCurr:GetName())
			wndItemName:SetTextColor(ktItemQualityToColor[itemCurr:GetItemQuality()])
		end
	end

	wndItemList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return a:GetData():GetName() < b:GetData():GetName() end)
	wndItemList:RecalculateContentExtents()

	local wndFirstUnlockedItem = wndItemList:GetChildren()[1]
	if wndFirstUnlockedItem then
		wndFirstUnlockedItem:SetCheck(true)
		self:OnUnlockItemSelect(wndFirstUnlockedItem, wndFirstUnlockedItem)
	else
		self.wndUnlockItems:FindChild("NoItemText"):Show(true)
		self.wndUnlockItems:FindChild("ItemPreview"):SetCostumeToCreatureId(ktManneqinIds[self.unitPlayer:GetGender()])
		self.wndUnlockItems:FindChild("ItemPreview"):SetCamera("Paperdoll")
		self.wndUnlockItems:FindChild("UnlockConfirmBtn"):Enable(false)
	end
end

function Costumes:OnUnlockItemSelect(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	local wndConfirmBtn = self.wndUnlockItems:FindChild("UnlockConfirmBtn")
	local wndCost = self.wndUnlockItems:FindChild("UnlockCost")

	local itemUnlock = wndHandler:GetData()
	local monUnlockCost = itemUnlock:GetCostumeUnlockInfo().monUnlockCost
	wndConfirmBtn:SetActionData(GameLib.CodeEnumConfirmButtonType.UnlockCostumeItem, itemUnlock:GetInventoryId())
	wndCost:SetAmount(monUnlockCost)

	local bCanAfford = monUnlockCost:GetAmount() < GameLib.GetPlayerCurrency():GetAmount()
	local strTextColor = bCanAfford and "UI_TextHoloBodyHighlight" or "AddonError"
	wndCost:SetTextColor(ApolloColor.new(strTextColor))
	wndConfirmBtn:Enable(bCanAfford)

	local wndPreview = self.wndUnlockItems:FindChild("ItemPreview")
	local eItemSlot = ktItemSlotToEquippedItems[itemUnlock:GetSlot()]

	if eItemSlot == GameLib.CodeEnumItemSlots.Weapon then
		wndPreview:SetCostumeToCreatureId(knWeaponModelId)
		wndPreview:SetCamera(ktItemCategoryToCamera[itemUnlock:GetItemCategory()] or ktClassToWeaponCamera[GameLib.GetPlayerUnit():GetClassId()])
	else
		wndPreview:SetCostumeToCreatureId(ktManneqinIds[GameLib.GetPlayerUnit():GetGender()])
		wndPreview:SetCamera(ktItemSlotToCamera[eItemSlot])
	end

	wndPreview:SetItem(itemUnlock)
end

function Costumes:CloseItemUnlock(wndHandler, wndControl)
	if not self.wndUnlockItems then
		return
	end

	self.wndUnlockItems:Destroy()
	self.wndUnlockItems = nil
end

----------------------
-- Wardrobe Item Context Menu Controls
----------------------

function Costumes:OnWardrobeContextShow(wndHandler, wndControl, eMouseBtn, bDoubleClick)
	if eMouseBtn ~= GameLib.CodeEnumInputMouse.Right then
		return
	end
	
	self.wndContext = Apollo.LoadForm(self.xmlDoc, "ContextMenu", "TooltipStratum", self)
	
	local itemData = wndHandler:GetData()
	self.wndContext:FindChild("ContextEquipItem"):SetData(wndHandler:FindChild("CostumeListItemBtn"))
	self.wndContext:FindChild("ContextRemoveItem"):SetData(itemData)
	
	local tCursor = Apollo.GetMouse()
	local nWidth = self.wndContext:GetWidth()
	self.wndContext:Move(tCursor.x - nWidth + knXCursorOffset, tCursor.y - knYCursorOffset, nWidth, self.wndContext:GetHeight())
	
	self.wndContext:Invoke()
end

function Costumes:OnContextEquip(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local wndCostumeItemBtn = wndHandler:GetData()
	
	wndCostumeItemBtn:SetCheck(true)
	self:OnPreviewBtnChecked(wndCostumeItemBtn, wndCostumeItemBtn)
	
	self:OnContextMenuClose()
end

function Costumes:OnRemoveWardrobeItem(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local itemRemoved = wndHandler:GetData()
	
	local wndRemove = self.wndMain:FindChild("ConfirmationOverlay:RemoveItem")
	
	wndRemove:FindChild("AcceptOption"):SetActionData(GameLib.CodeEnumConfirmButtonType.ForgetCostumeItem, itemRemoved:GetItemId())
	wndRemove:FindChild("ItemIcon"):GetWindowSubclass():SetItem(itemRemoved)
	wndRemove:FindChild("ItemName"):SetText(itemRemoved:GetName())
	wndRemove:FindChild("ItemName"):SetTextColor(ktItemQualityToColor[itemRemoved:GetItemQuality()])
	
	self:ToggleOverlay(keOverlayType.RemoveItem)
	
	self:OnContextMenuClose()	
end

function Costumes:OnContextMenuClose(wndHandler, wndControl)
	if self.wndContext then
		self.wndContext:Destroy()
		self.wndContext = nil
	end
end

----------------------
-- Preview Window Controls
----------------------
function Costumes:OnSheatheCheck(wndHandler, wndControl)
	self.bIsSheathed = wndControl:IsChecked()
	self.wndPreview:SetSheathed(self.bIsSheathed)
end

function Costumes:OnRotateRight()
	self.wndPreview:ToggleLeftSpin(true)
end

function Costumes:OnRotateRightCancel()
	self.wndPreview:ToggleLeftSpin(false)
end

function Costumes:OnRotateLeft()
	self.wndPreview:ToggleRightSpin(true)
end

function Costumes:OnRotateLeftCancel()
	self.wndPreview:ToggleRightSpin(false)
end

function Costumes:OnGenerateTooltipEquipped(wndHandler, wndControl, eType, itemCurr, idx)
	if wndHandler ~= wndControl then
		return
	end

	local itemData = wndHandler:GetData()
	local strAppend = "<P>" .. Apollo.GetString("Costumes_ListItemsTooltip") .. "</P>"

	-- Checking if this item is actually on the costume.  Otherwise, it's an equipped item
	if itemData and itemData == self.costumeDisplayed:GetSlotItem(ktItemSlotToEquippedItems[itemData:GetSlot()]) then
		if self.nDisplayedCostumeId and self.nDisplayedCostumeId ~= 0 then
			strAppend = strAppend .. "<P>" .. Apollo.GetString("Costumes_RemoveTooltip") .. "</P>"
		else
			strAppend = nil
		end
	end

	
	if itemData and Tooltip and Tooltip.GetItemTooltipForm then
		Tooltip.GetItemTooltipForm(self, wndHandler, itemData, {bSimple = true, strAppend = strAppend})
	end
end

function Costumes:OnGenerateTooltipPreview(wndHandler, wndControl, eType, itemCurr, idx)
	if wndHandler ~= wndControl then
		return
	end
	
	local itemData = wndHandler:GetData()

	local strAppend = "<P>" .. Apollo.GetString("Costumes_CostumeItemTooltip") .. "</P>" .. "<P>" .. Apollo.GetString("Costumes_CostumeItemTooltipRightClick") .. "</P>"
	if itemData and Tooltip and Tooltip.GetItemTooltipForm then
		Tooltip.GetItemTooltipForm(self, wndHandler, itemData, {bSimple = true, strAppend = strAppend})
	end
end

----------------------
-- Helpers
----------------------
function Costumes:UpdateCost()
	local wndFooter = self.wndMain:FindChild("Footer")
	local wndCash = wndFooter:FindChild("CostPreview:TotalCost")
	local monCost = self.costumeDisplayed and self.costumeDisplayed:GetCostOfChanges() or Money.new()
	wndCash:SetAmount(monCost)
	
	local bCanBuy = self.costumeDisplayed and self.costumeDisplayed:HasChanges() and (monCost:GetAmount() < GameLib.GetPlayerCurrency():GetAmount() or self.bUseToken)
	
	local strColor = bCanBuy and "white" or "xkcdReddish"
	wndCash:SetTextColor(ApolloColor.new(strColor))
	
	local wndSubmit = wndFooter:FindChild("SubmitBtn")
	
	if bCanBuy then
		wndSubmit:SetActionData(GameLib.CodeEnumConfirmButtonType.SaveCostumeChanges, self.costumeDisplayed, self.bUseToken)
	end
	
	local wndCostPreview = self.wndMain:FindChild("CostPreview")
	wndCash:Show(not self.bUseToken)
	wndCostPreview:FindChild("TokenCost"):Show(self.bUseToken)
	
	if self.bUseToken then
		local itemToken = Item.GetDataFromId(knTokenItemId)
		wndCostPreview:FindChild("TokenLabel"):SetText(String_GetWeaselString(Apollo.GetString("ChallengeReward_Multiplier"), monCost:GetAmount() > 0 and 1 or 0))
		wndCostPreview:FindChild("TokenLabel"):SetTextColor(ktItemQualityToColor[itemToken:GetItemQuality()])
		
		wndCostPreview:FindChild("TokenIcon"):GetWindowSubclass():SetItem(itemToken)
	end
	
	wndSubmit:Enable(bCanBuy)
	wndFooter:FindChild("ResetBtn"):Enable(self.costumeDisplayed and self.costumeDisplayed:HasChanges())
end

function Costumes:HideContentContainer()
	self.wndMain:FindChild("ContentContainer"):Show(false)
	self.wndMain:FindChild("HelpContentContainer"):Show(true)
end

function Costumes:HelperToggleEquippedBtn()
	local wndEquip = self.wndMain:FindChild("EquipBtn")
	local bEquipped = self.nDisplayedCostumeId == CostumesLib.GetCostumeIndex()
	local strLabel = bEquipped and Apollo.GetString("EngravingStation_Equipped") or Apollo.GetString("CRB_Equip")
	
	wndEquip:Enable(not bEquipped)
	wndEquip:SetText(strLabel)
end

function Costumes:ShowDyeContent()
	local wndContainer = self.wndMain:FindChild("ContentContainer")
	self.wndMain:FindChild("HelpContentContainer"):Show(false)
	wndContainer:Show(true)
	
	wndContainer:FindChild("CostumeWindows"):Show(false)
	wndContainer:FindChild("DyeList"):Show(true)
end

function Costumes:ShowCostumeContent()
	local wndContainer = self.wndMain:FindChild("ContentContainer")
	local tItemInfo = CostumesLib.GetUnlockItemCount()
	self.wndMain:FindChild("HelpContentContainer"):Show(false)
	wndContainer:Show(true)

	wndContainer:FindChild("DyeList"):Show(false)
	wndContainer:FindChild("CostumeWindows"):Show(true)
end

function Costumes:SetHelpString(strText)
	local wndContainer = self.wndMain:FindChild("TextBlock")
	local wndText = wndContainer:FindChild("HelpText")
	local nDiff = wndContainer:GetHeight() - wndText:GetHeight() 
	
	wndText:SetText(strText)
	local nTextWidth, nTextHeight = wndText:SetHeightToContentHeight()
	
	local nLeft, nTop, nRight, nBottom = wndContainer:GetAnchorOffsets()
	wndContainer:SetAnchorOffsets(nLeft, nBottom - nTextHeight - nDiff, nRight, nBottom)	
end

function Costumes:OnForgetResult(itemRemoved, eResult)
	if eResult == CostumesLib.CostumeUnlockResult.ForgetItemSuccess then
		self:ToggleOverlay(keOverlayType.None)

		-- Rebuild the current page
		local eSlot = ktItemSlotToEquippedItems[itemRemoved:GetSlot()]
		self.tUnlockedItems[eSlot] = CostumesLib.GetUnlockedSlotItems(eSlot, 0, CostumesLib.GetUnlockItemCount().nCurrent)

		if self.eSelectedSlot and self.eSelectedSlot == eSlot then
			self.arDisplayedItems = self.tUnlockedItems[eSlot]
			table.sort(self.arDisplayedItems, function(a,b) return a:GetName() < b:GetName() end)
		
			self:HelperUpdatePageItems((self.wndMain:FindChild("PageDown"):GetData() or 0) + 1)
		end
		
		if self.tCostumeSlots[eSlot]:FindChild("CostumeIcon"):GetData() == itemRemoved then
			self:EmptySlot(eSlot, true)
		end
	else
		self.wndMain:FindChild("ConfirmationOverlay:ErrorPanel:ConfirmText"):SetText(ktUnlockFailureStrings[eResult] or ktUnlockFailureStrings[CostumesLib.CostumeUnlockResult.UnknownFailure])
		
		self:ToggleOverlay(keOverlayType.Error)
		
		self.timerError = ApolloTimer.Create(2.0, false, "OnHideError", self)
		self.timerError:Start()
	end
end

function Costumes:OnSaveResult(eCostumeType, nCostumeIdx, eResult)
	if not self.wndMain or eResult == CostumesLib.CostumeSaveResult.Saving then
		return
	end
	
	if eResult == CostumesLib.CostumeSaveResult.Saved then
		self.wndMain:FindChild("PurchaseConfirmFlash"):SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")

		-- Need to get a new instance of the costume every time we save
		if self.unitPlayer == GameLib.GetPlayerUnit() then
			CostumesLib.SetCostumeIndex(self.nDisplayedCostumeId)
			self.costumeDisplayed = CostumesLib.GetCostume(self.nDisplayedCostumeId)
		else
			self.costumeDisplayed = CostumesLib.GetActiveMannequinCostume()
		end

		self:ResetChannelControls()
		self:RedrawCostume()
		self:HideContentContainer()
		self:UpdateCost()
	else
		self.wndMain:FindChild("ConfirmationOverlay:ErrorPanel:ConfirmText"):SetText(ktSaveFailureStrings[eResult] or ktSaveFailureStrings[CostumesLib.CostumeSaveResult.UnknownError])
		
		self:ToggleOverlay(keOverlayType.Error)
		
		self.timerError = ApolloTimer.Create(2.0, false, "OnHideError", self)
		self.timerError:Start()
	end
end

function Costumes:OnHideError()
	self:ToggleOverlay(keOverlayType.None)
end

function Costumes:CheckForTokens()
	if self.wndMain and self.wndMain:IsValid() then
		local unitPlayer = GameLib.GetPlayerUnit()
		local tInventory = unitPlayer:GetInventoryItems()
		self.bHasToken = false
		for idx, tInventoryInfo in pairs(tInventory) do
			if not self.bHasToken and tInventoryInfo.itemInBag:GetItemId() == knTokenItemId then
				self.bHasToken = true
			end
		end
		
		local wndUseTokenBtn = self.wndMain:FindChild("UseTokenBtn")
		wndUseTokenBtn:Enable(self.bHasToken)
		wndUseTokenBtn:SetCheck(self.bHasToken and wndUseTokenBtn:IsChecked())
		
		self:OnUseTokenToggle(wndUseTokenBtn, wndUseTokenBtn)
	end
end

function Costumes:OnUseTokenToggle(wndHandler, wndControl)
	self.bUseToken = wndHandler:IsChecked()
	self:UpdateCost()
end

function Costumes:ToggleOverlay(eType)
	local wndOverlay = self.wndMain:FindChild("ConfirmationOverlay")
	if eType == keOverlayType.None then
		wndOverlay:Show(false)
	else
		local wndUndoPanel = wndOverlay:FindChild("UndoPanel")
		wndUndoPanel:Show(eType == keOverlayType.UndoClose or eType == keOverlayType.UndoSwap)
		wndUndoPanel:FindChild("AcceptOption"):SetData(eType)
		
		wndOverlay:FindChild("RemoveItem"):Show(eType == keOverlayType.RemoveItem)
		wndOverlay:FindChild("ErrorPanel"):Show(eType == keOverlayType.Error)

		wndOverlay:Show(true)
	end
end

----------------------
-- Instance
----------------------
local CostumesInstance = Costumes:new()
CostumesInstance:Init()