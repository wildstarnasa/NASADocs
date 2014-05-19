-----------------------------------------------------------------------------------------------
-- Client Lua Script for ItemDyeing
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Item"
require "Money"

-----------------------------------------------------------------------------------------------
-- ItemDyeing Module Definition
-----------------------------------------------------------------------------------------------
local ItemDyeing = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local ktDyeSlots = {2,3,0,5,1,4} -- these are the equip slot id's of dye-able items
local kstrDefault = Apollo.GetString("Dyeing_NoDye")
local kcrDefaultColor = ApolloColor.new("UI_TextHoloBody")

local knSaveVersion

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ItemDyeing:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	-- initialize variables here

	return o
end

function ItemDyeing:Init()
	Apollo.RegisterAddon(self)
end

function ItemDyeing:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSaved = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSavedVersion = knSaveVersion,
	}
	
	return tSaved
end

function ItemDyeing:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSavedVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	
		if self.wndMain and self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- ItemDyeing OnLoad
-----------------------------------------------------------------------------------------------
function ItemDyeing:OnLoad()
	-- Register handlers for events, slash commands and timer, etc.
	-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
	--Apollo.RegisterEventHandler("ShowDye", 							"OnItemDyeingOn", self)
	Apollo.RegisterEventHandler("HideDye",							"OnClose", self)
	Apollo.RegisterEventHandler("DyeLearned",						"OnDyeLearned", self)
	Apollo.RegisterSlashCommand("dye", 								"OnItemDyeingOn", self)
	Apollo.RegisterEventHandler("PersonaUpdateCharacterStats", 		"OnGearUpdate", self)
	Apollo.RegisterEventHandler("CharacterPanel_CostumeUpdated", 	"OnGearUpdate", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 			"OnCurrencyChanged", self)
	Apollo.RegisterTimerHandler("ItemDyeingItemSwapColorUpdateTimer", 		"ItemSwapColorUpdateTimer", self)

	Apollo.CreateTimer("ItemDyeingItemSwapColorUpdateTimer", 0.5, false)


	-- load our forms
	self.wndMain = Apollo.LoadForm("ItemDyeing.xml", "ItemDyeWindow", nil, self)
	self.wndMain:Show(false)

	self.wndCostume 	= self.wndMain:FindChild("Costume")
	self.wndDyeList 	= self.wndMain:FindChild("DyeList")
	self.wndChannelList = self.wndMain:FindChild("ChannelList")
	self.wndCost 		= self.wndMain:FindChild("Cost")
	self.wndPlayerMoney = self.wndMain:FindChild("PlayerMoney")
	self.wndBlocker 	= self.wndMain:FindChild("RightSideBlocker")
	self.wndResetBtn	= self.wndMain:FindChild("ResetBtn")
	self.wndDyeButton	= self.wndMain:FindChild("DyeButton")

	self.tSlotWindows = {}
	for idx, nSlot in pairs(ktDyeSlots) do -- todo: prepping for programatic draw
		local wndContainer = self.wndMain:FindChild("ItemToggleContainer"):FindChild("ItemContainer_" .. nSlot)
		self.tSlotWindows[idx] =
		{
			wndContainer 	= wndContainer,
			wndSlot 		= wndContainer:FindChild("ItemSlot"),
			wndButton 		= wndContainer:FindChild("ToggleItemBtn"),
			wndCantBeDyed	= wndContainer:FindChild("CantBeDyedWarning"),
		}
		self.tSlotWindows[idx].wndSlot:Enable(false)
		self.tSlotWindows[idx].wndButton:SetData(idx)
	end

	self.tChannelWindows = {}
	for idx = 1, 3 do
		self.tChannelWindows[idx] = self.wndChannelList:FindChild("DyeChannel_" .. idx)
		self.wndChannelList:FindChild("RemoveDyeBtn_" .. idx):SetData(idx)
	end
end

-----------------------------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------------------------
function ItemDyeing:OnItemDyeingOn()
	local unitPlayer = GameLib.GetPlayerUnit()
	self.wndCostume:SetCostume(unitPlayer)
	self.wndCostume:SetSheathed(true)

	self:Reset()
	self.wndMain:Show(true) -- show the window
end

function ItemDyeing:OnGearUpdate()
	if self.wndMain:IsShown() then
		for idx = 1, #self.tSlotWindows do
			local tEquippedItems = {}
			local tItemWindows = self.tSlotWindows[idx]
			tItemWindows.wndButton:Show(tItemWindows.wndSlot:GetItem() ~= nil)

			if not tItemWindows.wndButton:IsShown() then
				tItemWindows.wndButton:SetCheck(false)
				tItemWindows.wndContainer:FindChild("SelectedMark"):Show(false)
			end
		end

		self:HelperPreviewItems()
		self:HelperUpdateBlocker()
	end

	Apollo.StartTimer("ItemDyeingItemSwapColorUpdateTimer")
end

function ItemDyeing:ItemSwapColorUpdateTimer()
	self:HelperPreviewItems()
end

function ItemDyeing:OnCurrencyChanged()
	self.wndPlayerMoney:SetAmount(GameLib.GetPlayerCurrency(), false)
end

function ItemDyeing:OnDyeLearned()
	self:FillDyes()
end

-----------------------------------------------------------------------------------------------
-- ItemDyeingForm Functions
-----------------------------------------------------------------------------------------------
function ItemDyeing:OnGenerateTooltip(wndHandler, wndControl, eToolTipType, nX, nY)
	if wndHandler ~= wndControl then return end
	if eToolTipType == Tooltip.TooltipGenerateType_ItemInstance then
		local itemCurrent = wndControl:GetitemCurrent()

		if itemCurrent ~= nil then
			Tooltip.GetitemCurrentTooltipForm(self, wndControl, itemCurrent, {bPrimary = true, bSelling = false})
		end
	end
end

function ItemDyeing:Reset(bRetainSlots)
	local tEquippedItems = {}
	for idx = 1, #self.tSlotWindows do
		if self.tSlotWindows[idx].wndSlot:GetItem() ~= nil then
			table.insert(tEquippedItems, self.tSlotWindows[idx].wndSlot:GetItem())
		end
	end

	if #tEquippedItems > 0 then
		self.wndCostume:SetItemDye(tEquippedItems, 0, 0, 0)
	end

	for idx = 1, #self.tChannelWindows do
		self.tChannelWindows[idx]:SetData(nil)
		self.tChannelWindows[idx]:FindChild("CurrentDye"):SetText(kstrDefault)
		self.tChannelWindows[idx]:FindChild("CurrentDye"):SetTextColor(kcrDefaultColor)
		self.tChannelWindows[idx]:SetCheck(idx == 1)
	end

	self:FillDyes()
	self.wndChannelList:SetRadioSel("DyeChannel", 1)

	if not bRetainSlots then
		self:HelperResetSlotBtns()
	end

	self:HelperSelectDye(0)
	self:ValidateBuyBtn()
	self:HelperUpdateBlocker()
end

function ItemDyeing:GetSelectedItems()
	local tSelectedItems = {}
	for idx = 1, #self.tSlotWindows do
		if self.tSlotWindows[idx].wndButton:IsChecked() then
			local itemCurr = self.tSlotWindows[idx].wndSlot:GetItem()
			if itemCurr then
				table.insert(tSelectedItems, itemCurr)
			end
		end
	end

	return tSelectedItems
end

function ItemDyeing:FillDyes()
	self.wndDyeList:DestroyChildren()

	local tDyeSort = GameLib.GetKnownDyes()

	table.sort(tDyeSort, function (a,b) return a.nId < b.nId end)

	for idx, tDyeInfo in ipairs(tDyeSort) do
		local wndNewDye = Apollo.LoadForm("ItemDyeing.xml", "DyeColor", self.wndDyeList, self)
		local strName = ""

		if tDyeInfo.strName and tDyeInfo.strName:len() > 0 then
			strName = tDyeInfo.strName
		else
			strName = String_GetWeaselString(Apollo.GetString("CRB_CurlyBrackets"), "", tDyeInfo.nRampIndex)
		end

		wndNewDye:FindChild("DyeSwatch"):SetSprite("CRB_DyeRampSprites:sprDyeRamp_" .. tDyeInfo.nRampIndex)
		wndNewDye:SetTooltip(strName)

		local tNewDyeInfo = {}
		tNewDyeInfo.id = tDyeInfo.nId
		tNewDyeInfo.strName = strName
		wndNewDye:SetData(tNewDyeInfo)
	end
	self.wndDyeList:ArrangeChildrenTiles()
end

---------------------------------------------------------------------------------------------------
-- Button Functions
---------------------------------------------------------------------------------------------------
function ItemDyeing:OnClose( wndHandler, wndControl, eMouseButton )
	self.wndMain:Show(false) -- hide the window
	Event_CancelDyeWindow()
end

function ItemDyeing:OnChannelSelect( wndHandler, wndControl, eMouseButton )
	if wndHandler ~= wndControl then
		return
	end
	local channelDye = wndControl:GetData()
	if channelDye ~= nil then
		self:HelperSelectDye(channelDye)
	else
		self:HelperSelectDye(0)
	end
end

function ItemDyeing:OnToggleItemBtn( wndHandler, wndControl, eMouseButton )
	if wndHandler ~= wndControl then
		return
	end

	local itemToggled = self.tSlotWindows[wndControl:GetData()].wndSlot:GetItem()
	self.tSlotWindows[wndControl:GetData()].wndContainer:FindChild("SelectedMark"):Show(wndControl:IsChecked())

	if itemToggled then
		local arChannels = {0,0,0}
		if wndControl:IsChecked() then
			arChannels = self:HelperGetDyedChannels()
		end
		self.wndCostume:SetItemDye(itemToggled, arChannels[1], arChannels[2], arChannels[3])
	end
	self:ValidateBuyBtn()
	self:HelperUpdateBlocker()
end

function ItemDyeing:OnDyeSelect( wndHandler, wndControl, eMouseButton )
	if wndHandler ~= wndControl then return end
	local wndDyeChannel = self.wndChannelList:GetRadioSelButton("DyeChannel")
	local tDye = wndControl:GetData()

	wndDyeChannel:FindChild("CurrentDye"):SetText(tDye.strName)
	wndDyeChannel:FindChild("CurrentDye"):SetTextColor(ApolloColor.new("white"))
	wndDyeChannel:SetData(tDye.id)

	self:HelperPreviewItems()
	self:ValidateBuyBtn()
end

function ItemDyeing:OnRemoveDyeBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then return false end

	local wndChannel = self.tChannelWindows[wndControl:GetData()]
	wndChannel:SetData(nil)
	wndChannel:FindChild("CurrentDye"):SetText(kstrDefault)
	wndChannel:FindChild("CurrentDye"):SetTextColor(kcrDefaultColor)

	if wndChannel:IsChecked() then
		self:HelperSelectDye(0)
	end

	self:HelperPreviewItems()
	self:ValidateBuyBtn()
end

function ItemDyeing:OnDyeBtnClicked(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	if not GameLib.CanDye() then return end

	local tSelectedItems = self:GetSelectedItems()
	if #tSelectedItems > 0 then
		local arChannels = self:HelperGetDyedChannels()
		GameLib.DyeItems(tSelectedItems, arChannels[1], arChannels[2], arChannels[3])
	end

	self:Reset()
end

function ItemDyeing:OnResetBtn(wndHandler, wndControl)
	self:Reset(true) -- tell the function to retain the slot selection
end

function ItemDyeing:OnRemoveCostumeBtn(wndHandler, wndControl)
	GameLib.SetCostumeIndex(nil)
	self:HelperUpdateBlocker()
end

function ItemDyeing:OnRotateRight()
	self.wndCostume:ToggleLeftSpin(true)
end

function ItemDyeing:OnRotateRightCancel()
	self.wndCostume:ToggleLeftSpin(false)
end

function ItemDyeing:OnRotateLeft()
	self.wndCostume:ToggleRightSpin(true)
end

function ItemDyeing:OnRotateLeftCancel()
	self.wndCostume:ToggleRightSpin(false)
end

---------------------------------------------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------------------------------------------
function ItemDyeing:ValidateBuyBtn()
	local monCost = 0
	local tSelectedItems = self:GetSelectedItems()
	if #tSelectedItems > 0 then
		local arChannels = self:HelperGetDyedChannels()
		monCost = GameLib.GetDyeCost(tSelectedItems, arChannels[1], arChannels[2], arChannels[3])
	end

	if type(monCost) ~= "number" then
		self.wndDyeButton:Enable(GameLib.CanDye() and monCost:GetAmount() > 0 and monCost:GetAmount() <= GameLib.GetPlayerCurrency():GetAmount())
		self.wndResetBtn:Enable(monCost:GetAmount() > 0)
	else -- monCost is 0
		self.wndDyeButton:Enable(false)
		self.wndResetBtn:Enable(false)
	end

	self.wndCost:SetAmount(monCost, false)
	self.wndPlayerMoney:SetAmount(GameLib.GetPlayerCurrency(), false)

	if self.wndBlocker:IsShown() then
		self.wndDyeButton:Enable(false)
		self.wndResetBtn:Enable(false)
	end
end

function ItemDyeing:HelperSelectDye(idDye)
	local wndFound = self.wndDyeList:FindChildByUserData(idDye)
	if not wndFound then
		for idx, wnd in ipairs(self.wndDyeList:GetChildren()) do
			wnd:SetCheck(false)
		end
	else
		self.wndDyeList:SetRadioSelButton("Dyes", wndFound)
	end
	return true
end

function ItemDyeing:HelperGetDyedChannels()
	local tDyes = {0,0,0}
	for idx = 1, #self.tChannelWindows do
		if self.tChannelWindows[idx]:GetData() ~= nil then
			tDyes[idx] = self.tChannelWindows[idx]:GetData()
		end
	end

	return tDyes
end

function ItemDyeing:HelperPreviewItems()
	local tSelectedItems = self:GetSelectedItems()
	if #tSelectedItems > 0 then
		local arChannels = self:HelperGetDyedChannels()
		self.wndCostume:SetItemDye(tSelectedItems, arChannels[1], arChannels[2], arChannels[3])
	end
end


function ItemDyeing:HelperResetSlotBtns()
	if wndHandler ~= wndControl then return end
	--self:ToggleSlot(wndHandler:GetParent(), eToggle.Toggle)

	for idx = 1, #self.tSlotWindows do
		local wndSlot = self.tSlotWindows[idx]
		local itemCurr = wndSlot.wndSlot:GetItem()
		wndSlot.wndButton:SetCheck(false)
		wndSlot.wndButton:Show(itemCurr ~= nil)
		wndSlot.wndContainer:FindChild("SelectedMark"):Show(false)

		local bCanBeDyed = false
		if itemCurr then
			for idx, bCurr in pairs(itemCurr:GetAvailableDyeChannel()) do
				if bCurr then
					bCanBeDyed = true
					break
				end
			end
		end
		wndSlot.wndCantBeDyed:Show(not bCanBeDyed)
	end
end

function ItemDyeing:HelperUpdateBlocker()
	local bWearingCostume = GameLib.GetCostumeIndex() ~= nil and GameLib.GetCostumeIndex() > 0
	local bNoSlotSelected = #self:GetSelectedItems() == 0
	local bNoDyes = #GameLib.GetKnownDyes() == 0
	local bDrawBlocker = bWearingCostume or bNoSlotSelected or bNoDyes

	self.wndBlocker:Show(bDrawBlocker)
	self.wndChannelList:Show(not bDrawBlocker)
	self.wndBlocker:FindChild("Prompt_NoItemSelected"):Show(bNoSlotSelected and not bWearingCostume and not bNoDyes) -- costume gets priority
	self.wndBlocker:FindChild("Prompt_CostumeWorn"):Show(bWearingCostume and not bNoDyes)
	self.wndBlocker:FindChild("Prompt_NoKnownDyes"):Show(bNoDyes)
	self.wndMain:FindChild("DyeListContainer"):Show(not bDrawBlocker)
	self:ValidateBuyBtn()
end

-----------------------------------------------------------------------------------------------
-- ItemDyeing Instance
-----------------------------------------------------------------------------------------------
local ItemDyeingInst = ItemDyeing:new()
ItemDyeingInst:Init()
