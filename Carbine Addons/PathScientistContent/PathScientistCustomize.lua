-----------------------------------------------------------------------------------------------
-- Client Lua Script for PathScientistCustomize
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "PetFlair"
require "PetCustomization"
require "PetCustomizationLib"

local PathScientistCustomize = {}
local knDurationOfCast = 7.5
local knSaveVersion = 2

function PathScientistCustomize:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PathScientistCustomize:Init()
    Apollo.RegisterAddon(self)
end

function PathScientistCustomize:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSave = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	
	return tSave
end

function PathScientistCustomize:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

-----------------------------------------------------------------------------------------------
-- PathScientistCustomize OnLoad
-----------------------------------------------------------------------------------------------
function PathScientistCustomize:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathScientistCustomize.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PathScientistCustomize:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("PetFlairUnlocked", "OnPetFlairUnlocked", self)
	Apollo.RegisterEventHandler("GenericEvent_ToggleScanBotCustomize", "Initialize", self)
	Apollo.RegisterEventHandler("PlayerPathScientistScanBotCooldown",	"OnScanBotCooldown", self)
	Apollo.RegisterTimerHandler("ScanBotCooldownCastBar",				"OnScanBotCooldownProgress", self)
end

function PathScientistCustomize:InitializeShow()
	self:Initialize(true)
end

function PathScientistCustomize:Initialize(bShow)
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
		if not bShow then
			return
		end
	end

	if PlayerPathLib and PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Scientist then
		return
	end

	if not self.bHasInitialized then
		Apollo.RegisterEventHandler("PetCustomizationFailed", 	"OnPetCustomizationFailed", self)
		Apollo.RegisterEventHandler("PetCustomizationUpdated", 	"OnPetCustomizationUpdated", self)
		Apollo.RegisterEventHandler("PlayerPathScientistScanBotDeployed",	"OnScanBotDeployed", self)
		Apollo.RegisterEventHandler("PlayerPathScientistScanBotDespawned",	"OnScanBotDespawned", self)
		Apollo.RegisterEventHandler("ScanBotCooldownComplete",				"OnScanBotCooldownComplete", self)
		--Apollo.RegisterEventHandler("PetFlairCleared", "OnPetFlairCleared", self) -- Deprecated? Not used?

		Apollo.RegisterTimerHandler("RedrawAllTimer", 						"RedrawAll", self)
		Apollo.RegisterTimerHandler("ScanBotCustomize_ErrorMessageTimer", 	"OnScanBotCustomize_ErrorMessageTimer", self)
		Apollo.RegisterTimerHandler("IncrementScanBotCastBar", 				"OnIncrementScanBotCastBar", self)
		Apollo.RegisterTimerHandler("DoneScanBotCastBar", 					"OnDoneScanBotCastBar", self)
	end

	-- Summon the bot (for portrait and data)
	--local unitPlayerScanBot = PlayerPathLib.ScientistGetScanBotUnit()
	if not PlayerPathLib.ScientistHasScanBot() then
		PlayerPathLib.ScientistToggleScanBot()
	end

	self.bHasInitialized = true
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PathScientistCustomizeForm", nil, self)
	self.wndMain:FindChild("ProfileDropdownBtn"):AttachWindow(self.wndMain:FindChild("ProfileDropdownBG"))
	self.wndMain:FindChild("RenameBtn"):AttachWindow(self.wndMain:FindChild("RenameFrameBG"))
	self.wndMain:FindChild("TabROMBtn"):AttachWindow(self.wndMain:FindChild("AvailableROMList"))
	self.wndMain:FindChild("TabVanityBtn"):AttachWindow(self.wndMain:FindChild("AvailableVanityList"))
	self.wndMain:FindChild("ScanBotProtraitErrorMessage"):Show(false, true)
	
	self.wndMain:FindChild("RenameFrameUpdate"):Enable(false)
	self.wndMain:FindChild("RenameValidAlert"):Show(true)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	if PlayerPathLib.ScientistHasScanBot() then
		self:OnScanBotDeployed() 
	else
		self:OnScanBotDespawned()
	end

	self:RedrawAll()
end

function PathScientistCustomize:OnPetFlairUnlocked(petFlair)
	local eFlairType = petFlair:GetFlairType()
	if eFlairType == PetCustomizationLib.PetFlairType_ScanBotRom 
		or eFlairType == PetCustomizationLib.PetFlairType_ScanBotVanity then
		self:InitializeShow()
	end
end

-----------------------------------------------------------------------------------------------
-- Main Redraw
-----------------------------------------------------------------------------------------------

function PathScientistCustomize:RedrawAll()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	-- Dropdown
	self.wndMain:FindChild("ProfileDropdownList"):DestroyChildren()
	local sbpCurrentProfile = PlayerPathLib.ScientistGetScanBotProfile()
	for idx, sbpProfile in ipairs(PlayerPathLib.ScientistAllGetScanBotProfiles()) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "PickProfileBtn", self.wndMain:FindChild("ProfileDropdownList"), self)
		wndCurr:SetText(sbpProfile:GetName())
		wndCurr:SetData(sbpProfile)

		if sbpProfile == sbpCurrentProfile then
			wndCurr:SetCheck(true)
			self.wndMain:FindChild("ProfileDropdownList"):EnsureChildVisible(wndCurr)
			if PlayerPathLib.GetScannerName() == "" then
				self.wndMain:FindChild("ProfileDropdownBtn"):SetText(sbpProfile:GetName())
			else
				self.wndMain:FindChild("ProfileDropdownBtn"):SetText(String_GetWeaselString(Apollo.GetString("ScientistMission_ScanBotProfile"), PlayerPathLib.GetScannerName(), sbpProfile:GetName()))

			end
		end
	end
	self.wndMain:FindChild("ProfileDropdownList"):ArrangeChildrenVert(0)

	-- Slots (Vanity and ROM)
	local tScanBotData = PlayerPathLib.ScientistGetScanBotProfile():GetCustomization()
	local tActiveSelectedNames = {}
	local tAvailableSlots =
	{
		tScanBotData:GetSlotsByFlairType(PetCustomizationLib.PetFlairType_ScanBotVanity),
		tScanBotData:GetSlotsByFlairType(PetCustomizationLib.PetFlairType_ScanBotRom)
	}

	self.wndMain:FindChild("CurrentList"):DestroyChildren()
	for nTableId, tCurrTable in pairs(tAvailableSlots) do
		for idx2, tSlotData in pairs(tCurrTable) do
			local nSlotIndex = tSlotData.nSlot
			local tFlairData = tSlotData.pcFlair
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "CurrentFlairItem", self.wndMain:FindChild("CurrentList"), self)
			--wndCurr:FindChild("CurrentFlairAvailable"):Show(not tFlairData)
			wndCurr:FindChild("CurrentFlairAvailable"):SetBGColor(nTableId == 2 and "ffffff00" or "ffffffff")
			wndCurr:FindChild("CurrentFlairAvailable"):SetTooltip(nTableId == 2 and Apollo.GetString("ScientistMission_AvailableROMSlot") or Apollo.GetString("ScientistMission_AvailableVanitySlot"))
			wndCurr:FindChild("CurrentFlairIcon"):SetSprite(tFlairData and tFlairData:GetIconPath() or "")
			wndCurr:FindChild("CurrentFlairBtn"):Show(tFlairData)
			wndCurr:FindChild("CurrentFlairBtn"):SetData({ nTableId, tFlairData, nSlotIndex })
			wndCurr:FindChild("CurrentFlairBtn"):SetBGColor(nTableId == 2 and "ffffff00" or "ffffffff")
			wndCurr:FindChild("CurrentFlairBtn"):SetTooltip(not tFlairData and "" or string.format(
			"<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s</P><P Font=\"CRB_InterfaceSmall\">%s</P>", tFlairData:GetName(), tFlairData:GetDescription()))

			if tFlairData then
				tActiveSelectedNames[tFlairData:GetId()] = true
			end
		end
	end
	self.wndMain:FindChild("CurrentList"):ArrangeChildrenHorz(1)

	-- Vanity
	local nVanityScrollPos = self.wndMain:FindChild("AvailableVanityList"):GetVScrollPos()
	self.wndMain:FindChild("AvailableVanityList"):DestroyChildren()
	for idx, tFlairData in pairs(PetCustomizationLib.GetUnlockedPetFlairByType(PetCustomizationLib.PetFlairType_ScanBotVanity) or {}) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "FlairItem", self.wndMain:FindChild("AvailableVanityList"), self)
		wndCurr:FindChild("FlairItemBtn"):SetData({ 1, tFlairData })
		wndCurr:FindChild("FlairItemBtn"):SetTooltip(tFlairData:GetTooltip())
		wndCurr:FindChild("FlairItemBtn"):SetCheck(tActiveSelectedNames[tFlairData:GetId()])
		wndCurr:FindChild("FlairItemIcon"):SetSprite(tFlairData:GetIconPath())
		wndCurr:FindChild("FlairItemName"):SetText(tFlairData:GetName())
	end
	self.wndMain:FindChild("AvailableVanityList"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("AvailableVanityList"):SetVScrollPos(nVanityScrollPos)

	-- ROMs
	local nROMScrollPos = self.wndMain:FindChild("AvailableROMList"):GetVScrollPos()
	self.wndMain:FindChild("AvailableROMList"):DestroyChildren()
	for idx, tFlairData in pairs(PetCustomizationLib.GetUnlockedPetFlairByType(PetCustomizationLib.PetFlairType_ScanBotRom) or {}) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "FlairItem", self.wndMain:FindChild("AvailableROMList"), self)
		wndCurr:FindChild("FlairItemBtn"):SetData({ 2, tFlairData })
		wndCurr:FindChild("FlairItemBtn"):SetTooltip(tFlairData:GetTooltip())
		wndCurr:FindChild("FlairItemBtn"):SetCheck(tActiveSelectedNames[tFlairData:GetId()])
		wndCurr:FindChild("FlairItemIcon"):SetSprite(tFlairData:GetIconPath())
		wndCurr:FindChild("FlairItemName"):SetText(tFlairData:GetName())

		-- Make this button Green
		wndCurr:FindChild("FlairItemBtn"):SetBGColor("ffffff00")
		wndCurr:FindChild("FlairItemName"):SetTextColor("ff7fffb9")
	end
	self.wndMain:FindChild("AvailableROMList"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("AvailableROMList"):SetVScrollPos(nROMScrollPos)

	self.wndMain:FindChild("AvailableROMEmptyLabel"):Show(self.wndMain:FindChild("AvailableROMList"):IsVisible() and #self.wndMain:FindChild("AvailableROMList"):GetChildren() == 0)
	self.wndMain:FindChild("AvailableVanityEmptyLabel"):Show(self.wndMain:FindChild("AvailableVanityList"):IsVisible() and #self.wndMain:FindChild("AvailableVanityList"):GetChildren() == 0)
end

-----------------------------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------------------------

function PathScientistCustomize:OnPetCustomizationFailed(eReason, tFlairData)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self:RedrawAll()

	-- Reset the scanbot rename field if they try to change to an invalid name
	if eReason == PetCustomizationLib.PetCustomizeResult.InvalidName then
		self.wndMain:FindChild("RenameFrameEditBox"):SetText(PlayerPathLib.GetScannerName())
	end

	self.wndMain:FindChild("ScanBotProtraitErrorMessage"):Show(true)
	Apollo.CreateTimer("ScanBotCustomize_ErrorMessageTimer", 3, false)
end

function PathScientistCustomize:OnScanBotCustomize_ErrorMessageTimer()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.wndMain:FindChild("ScanBotProtraitErrorMessage"):Show(false)
end

function PathScientistCustomize:OnPetCustomizationUpdated(tCustomize, tFlairData)
	Apollo.CreateTimer("RedrawAllTimer", 0.25, false) -- For animations to fully play
end

-- Fake Progress Bar
function PathScientistCustomize:OnIncrementScanBotCastBar()
	if self.wndMain and self.wndMain:IsValid() then
		local nCurrent = math.min(1, self.wndMain:FindChild("CraftingCastBarMove"):GetData() or 0)
		self.wndMain:FindChild("CraftingCastBarMove"):SetMax(1)
		self.wndMain:FindChild("CraftingCastBarMove"):SetProgress(nCurrent + 0.02)
		self.wndMain:FindChild("CraftingCastBarMove"):SetData(nCurrent + 0.02)
	end
end

function PathScientistCustomize:OnDoneScanBotCastBar() -- Extract also routes here, as extract is instant
	Apollo.StopTimer("DoneScanBotCastBar")
	Apollo.StopTimer("IncrementScanBotCastBar")
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("CraftingCastBarMove"):SetData(0)
	end
end

function PathScientistCustomize:OnScanBotDeployed()
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() then
		local unitPlayerScanBot = PlayerPathLib.ScientistGetScanBotUnit()
		self.wndMain:FindChild("ScanBotPortrait"):SetCostume(unitPlayerScanBot)
		self.wndMain:FindChild("ScanBotPortrait"):SetModelSequence(150)
		self.wndMain:FindChild("ScanBotPortrait"):Show(true)
		self.wndMain:FindChild("CurrentList"):Show(true)
		self.wndMain:FindChild("ScanBotPortraitSummonBtn"):Show(false)
		self.wndMain:FindChild("ScanBotPortraitSummonWaiting"):Show(false)
	end
end

function PathScientistCustomize:OnScanBotDespawned()
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() then
		self.wndMain:FindChild("ScanBotPortrait"):Show(false)
		self.wndMain:FindChild("CurrentList"):Show(false)
		self.wndMain:FindChild("ScanBotPortraitSummonWaiting"):Show(true)
	end
end

function PathScientistCustomize:OnScanBotCooldown(fCooldown)
	fCooldown = math.max(1, fCooldown)
	Apollo.CreateTimer("ScanBotCooldownCastBar", fCooldown / 100, true) -- We want to update 1% at a time
end

function PathScientistCustomize:OnScanBotCooldownProgress()
	self.fCooldownProgress = math.min(1, self.fCooldownProgress or 0)
	self.fCooldownProgress = self.fCooldownProgress + 0.013
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("CraftingCastBarMove"):SetMax(1)
		self.wndMain:FindChild("CraftingCastBarMove"):SetProgress(self.fCooldownProgress)
		self.wndMain:FindChild("CraftingCastBarMove"):SetData(self.fCooldownProgress)
	end
end

function PathScientistCustomize:OnScanBotCooldownComplete()
	Apollo.StopTimer("ScanBotCooldownCastBar")
	self.fCooldownProgress = 0
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("ScanBotPortraitSummonBtn"):Show(true)
		self.wndMain:FindChild("ScanBotPortraitSummonWaiting"):Show(false)
		self.wndMain:FindChild("CraftingCastBarMove"):SetProgress(0)
	end
end

-----------------------------------------------------------------------------------------------
-- Interaction
-----------------------------------------------------------------------------------------------

function PathScientistCustomize:OnCloseBtn(wndHandler, wndControl)
	self.locSavedWindowLoc = self.wndMain:GetLocation()
	self.wndMain:Destroy()
	self.wndMain = nil
end

function PathScientistCustomize:OnCurrentFlairMouseEnter(wndHandler, wndControl)
	local wndParent = wndHandler:GetParent()
	if wndParent and wndParent:IsVisible() and wndParent:FindChild("CurrentFlairMouseOver") then
		wndParent:FindChild("CurrentFlairMouseOver"):Show(true)
	end
end

function PathScientistCustomize:OnCurrentFlairMouseExit(wndHandler, wndControl)
	local wndParent = wndHandler:GetParent()
	if wndParent and wndParent:IsVisible() and wndParent:FindChild("CurrentFlairMouseOver") then
		wndParent:FindChild("CurrentFlairMouseOver"):Show(false)
	end
end

function PathScientistCustomize:OnCurrentFlairBtn(wndHandler, wndControl) -- CurrentFlairBtn, data is { eType, flair object, nSlotIndex }
	local tScanBotData = PlayerPathLib.ScientistGetScanBotProfile():GetCustomization()
	tScanBotData:ClearFlairInSlot(wndHandler:GetData()[3])
	self:RedrawAll()
end

function PathScientistCustomize:OnFlairItemCheck(wndHandler, wndControl) -- wndHandler is FlairItemBtn, data is a { eType , flair object }
	if wndHandler ~= wndControl or not wndHandler:GetData() then
		return
	end

	local nResult = 1
	local eFlairType = wndHandler:GetData()[1]
	local objFlair = wndHandler:GetData()[2]

	for idx, wndCurr in pairs(self.wndMain:FindChild("CurrentList"):GetChildren()) do
		local tBtnData = wndCurr:FindChild("CurrentFlairBtn"):GetData() -- data is { eType, flair object, nSlotIndex }
		if tBtnData[1] == eFlairType then
			nResult = tBtnData[3]
			if not tBtnData[2] then
				break
			end
		end
	end

	local tScanBotData = PlayerPathLib.ScientistGetScanBotProfile():GetCustomization()
	tScanBotData:SetFlairInSlot(objFlair, nResult)
end

function PathScientistCustomize:OnFlairItemUncheck(wndHandler, wndControl) -- wndHandler is FlairItemBtn, data is a { eType , flair object }
	local nResult = 1
	local eFlairType = wndHandler:GetData()[1]
	local objFlair = wndHandler:GetData()[2]
	for idx, wndCurr in pairs(self.wndMain:FindChild("CurrentList"):GetChildren()) do
		local tBtnData = wndCurr:FindChild("CurrentFlairBtn"):GetData() -- data is { eType, flair object, nSlotIndex }
		if tBtnData[1] == eFlairType and tBtnData[2] and tBtnData[2]:GetName() == objFlair:GetName() then
			nResult = tBtnData[3]
		end
	end

	local tScanBotData = PlayerPathLib.ScientistGetScanBotProfile():GetCustomization()
	tScanBotData:ClearFlairInSlot(nResult)
end

function PathScientistCustomize:OnScanBotPortraitSummonBtn(wndHandler, wndControl) -- ScanBotPortraitSummonBtn
	PlayerPathLib.ScientistToggleScanBot()
	wndHandler:Show(false)
	self:RedrawAll()
end

-- Swap Profiles
function PathScientistCustomize:OnPickProfileBtn(wndHandler, wndControl) -- PickProfileBtn
	PlayerPathLib.ScientistSetScanBotProfile(wndHandler:GetData())
	if PlayerPathLib.ScientistHasScanBot() then
		PlayerPathLib.ScientistToggleScanBot()
	end

	self.wndMain:FindChild("ProfileDropdownBG"):Show(false)
	self:RedrawAll() -- No update event?

	Apollo.StopTimer("DoneScanBotCastBar")
	Apollo.StopTimer("IncrementScanBotCastBar")
	Apollo.CreateTimer("IncrementScanBotCastBar", knDurationOfCast / 50, true)
	Apollo.CreateTimer("DoneScanBotCastBar", knDurationOfCast, false)
	self.wndMain:FindChild("CraftingCastBarMove"):SetData(0)
end

-- Renaming
function PathScientistCustomize:OnRenameFrameUpdate(wndHandler, wndControl)
	local strNewName = self.wndMain:FindChild("RenameFrameEditBox"):GetText()
	PlayerPathLib.SetScannerName(strNewName)
	self.wndMain:FindChild("RenameFrameBG"):Show(false)
	self.wndMain:SetSprite("WhiteFlash")
end

function PathScientistCustomize:OnRenameFrameCancel(wndHandler, wndControl)
	self.wndMain:FindChild("RenameFrameBG"):Show(false)
end

function PathScientistCustomize:OnRenameFrameEditBoxChanged(wndHandler, wndControl)
	local strInput = wndHandler:GetText()
	if strInput and string.len(strInput) > 0 then
		local bIsTextValid = GameLib.IsTextValid(strInput, GameLib.CodeEnumUserText.ScientistScanbotName, GameLib.CodeEnumUserTextFilterClass.Strict) and strInput ~= GameLib.GetPlayerUnit():GetName()

		self.wndMain:FindChild("RenameFrameUpdate"):Enable(bIsTextValid)
		self.wndMain:FindChild("RenameValidAlert"):Show(not bIsTextValid)
	else
		self.wndMain:FindChild("RenameFrameUpdate"):Enable(false)
	end
end

-- Rotating
function PathScientistCustomize:OnRotateRight()
	self.wndMain:FindChild("ScanBotPortrait"):ToggleLeftSpin(true)
end

function PathScientistCustomize:OnRotateRightCancel()
	self.wndMain:FindChild("ScanBotPortrait"):ToggleLeftSpin(false)
end

function PathScientistCustomize:OnRotateLeft()
	self.wndMain:FindChild("ScanBotPortrait"):ToggleRightSpin(true)
end

function PathScientistCustomize:OnRotateLeftCancel()
	self.wndMain:FindChild("ScanBotPortrait"):ToggleRightSpin(false)
end

local PathScientistCustomizeInst = PathScientistCustomize:new()
PathScientistCustomizeInst:Init()
