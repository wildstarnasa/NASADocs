require "Window"
require "Apollo"
require "ApolloCursor"
require "GameLib"
require "Item"

local ImprovedSalvage = {}

local kidBackpack = 0
local knSavedVersion = 100

function ImprovedSalvage:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function ImprovedSalvage:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc

	local tSaved =
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion
	}
	return tSaved
end

function ImprovedSalvage:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSavedVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
		
		if self.wndMain then
			--self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
	end
end

function ImprovedSalvage:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ImprovedSalvage.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function ImprovedSalvage:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("RequestSalvageAll", "OnSalvageAll", self) -- using this for bag changes
	Apollo.RegisterSlashCommand("salvageall", "OnSalvageAll", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ImprovedSalvageForm", nil, self)
	self.xmlDoc = nil
	self.wndItemDisplay = self.wndMain:FindChild("ItemDisplayWindow")
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	self.tContents = self.wndMain:FindChild("HiddenBagWindow")
	self.arItemList = nil
	self.nItemIndex = nil

	self.wndMain:Show(false, true)
end

--------------------//-----------------------------
function ImprovedSalvage:OnSalvageAll()
	self.arItemList = {}
	self.nItemIndex = 1
	
	local tInvItems = GameLib.GetPlayerUnit():GetInventoryItems()
	for idx, tItem in ipairs(tInvItems) do
		if tItem and tItem.itemInBag and tItem.itemInBag:CanSalvage() then
			table.insert(self.arItemList, tItem.itemInBag)
		end
	end

	self:RedrawAll()
end

function ImprovedSalvage:RedrawAll()
	local itemCurr = self.arItemList[self.nItemIndex]
	
	if itemCurr ~= nil then
		self:HelperBuildResultDisplay(self, self.wndItemDisplay, itemCurr )
		self.wndMain:SetData(itemCurr)
		self.wndMain:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, itemCurr:GetInventoryId())
		self.wndMain:Show(true)
		self.wndMain:ToFront()
	else
		self.wndMain:Show(false)
	end
	
end

function ImprovedSalvage:HelperBuildResultDisplay(wndOwner, wndParent, itemCurr, itemModData )
	--local nVScrollPos = self.wndMain:FindChild("MainScroll"):GetVScrollPos()
	wndParent:DestroyChildren()
	
	local tResult = Tooltip.GetItemTooltipForm(wndOwner, wndParent, itemCurr, { bPermanent = true, wndParent = wndParent, bNotEquipped = true, bPrimary = true })
	local wndTooltip = nil
	if tResult ~= nil then
		if type(tResult) == 'table' then
			wndTooltip = tResult[0]
		elseif type(tResult) == 'userdata' then
			wndTooltip = tResult
		end
	end 
	if wndTooltip ~= nil then
		local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
		wndParent:SetAnchorOffsets(nLeft, nTop, nRight, nTop + wndTooltip:GetHeight())
		self.wndMain:FindChild("MainScroll"):SetVScrollPos(0)
		self.wndMain:FindChild("MainScroll"):RecalculateContentExtents()
	end
	
	--self.wndMain:FindChild("MainScroll"):SetVScrollPos(nVScrollPos)
	--self.wndMain:FindChild("MainScroll"):RecalculateContentExtents()
end


function ImprovedSalvage:OnSalvageNext()
	self.nItemIndex = self.nItemIndex + 1
	self:RedrawAll()
end

function ImprovedSalvage:OnSalvageCurr()
	self.nItemIndex = self.nItemIndex + 1
	self:RedrawAll()
end

function ImprovedSalvage:OnCloseBtn()
	self.arItemList = {}
	self.wndMain:SetData(nil)
	self.wndMain:Show(false)
end

----------------globals----------------------------

local ImprovedSalvage_Singleton = ImprovedSalvage:new()
Apollo.RegisterAddon(ImprovedSalvage_Singleton)
