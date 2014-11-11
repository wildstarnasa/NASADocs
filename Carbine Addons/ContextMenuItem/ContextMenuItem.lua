-----------------------------------------------------------------------------------------------
-- Client Lua Script for ContextMenuItem
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "GroupLib"
require "ChatSystemLib"
require "FriendshipLib"
require "MatchingGame"

local knXCursorOffset = 10
local knYCursorOffset = 25

-- Head, Shoulder, Chest, Hands, Boots, etc.
local ktValidItemPreviewSlots = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [16] = true }

local ktValidRaceWeaponPreview =
{	-- Pistols, Psyblades, Claws, Sword, Resonators, Gun
	[GameLib.CodeEnumRace.Aurin] 	= {	[45] = true, [46] = true, [48] = true },
	[GameLib.CodeEnumRace.Draken] 	= {	[45] = true, [48] = true, [51] = true },
	[GameLib.CodeEnumRace.Granok] 	= {	[51] = true, [79] = true, [204] = true },
	[GameLib.CodeEnumRace.Mechari] 	= { [48] = true, [51] = true, [79] = true, [204] = true },
	[GameLib.CodeEnumRace.Chua] 	= {	[45] = true, [46] = true, [79] = true, [204] = true },
	[GameLib.CodeEnumRace.Mordesh] 	= { [45] = true, [48] = true, [51] = true, [79] = true,	[204] = true },
	[GameLib.CodeEnumRace.Human] 	= {	[45] = true, [46] = true, [48] = true, [51] = true, [79] = true, [204] = true },
}

local ContextMenuItem = {}

function ContextMenuItem:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ContextMenuItem:Init()
    Apollo.RegisterAddon(self)
end

function ContextMenuItem:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ContextMenuItem.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ContextMenuItem:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("ItemLink", 					"InitializeItemObject", self)
	Apollo.RegisterEventHandler("ShowItemInDressingRoom", 		"InitializeItemObject", self)
	Apollo.RegisterEventHandler("ToggleItemContextMenu", 		"InitializeItemObject", self) -- Potentially from code
	Apollo.RegisterEventHandler("GenericEvent_ContextMenuItem", "InitializeItemObject", self)

	-- Special Cases
	Apollo.RegisterEventHandler("SplitItemStack", 			"OnSplitItemStack", self)
	Apollo.RegisterEventHandler("DecorPreviewOpen", 		"OnDecorPreviewOpen", self)
end

function ContextMenuItem:InitializeItemObject(itemArg)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ContextMenuItemForm", "TooltipStratum", self)
	self.wndMain:SetData(itemArg)
	self.wndMain:Invoke()

	local tCursor = Apollo.GetMouse()
	self.wndMain:Move(tCursor.x - knXCursorOffset, tCursor.y - knYCursorOffset, self.wndMain:GetWidth(), self.wndMain:GetHeight())

	-- Enable / Disable the approriate buttons
	self.wndMain:FindChild("BtnEditRunes"):Enable(self:HelperValidateEditRunes(itemArg))
	self.wndMain:FindChild("BtnPreviewItem"):Enable(self:HelperValidatePreview(itemArg))
	self.wndMain:FindChild("BtnSplitStack"):Enable(itemArg and itemArg:GetStackCount() > 1)

	-- If Decor
	self.nDecorId = itemArg:GetHousingDecorInfoId()
	if self.nDecorId and self.nDecorId ~= 0 then
		self.wndMain:FindChild("BtnPreviewItem"):Enable(true)
	end
end

function ContextMenuItem:OnDecorPreviewOpen(nArgDecorId) -- Currently unable to offer Link to Chat, which requires the object
	Event_FireGenericEvent("GenericEvent_LoadDecorPreview", nArgDecorId)
end

function ContextMenuItem:OnSplitItemStack(itemArg) -- This is a common enough shortcut (Shift + Left Click) to skip the menu
	Event_FireGenericEvent("GenericEvent_SplitItemStack", itemArg)
end

function ContextMenuItem:OnRegularBtn(wndHandler, wndControl) -- Can be any of the buttons
	local itemArg = self.wndMain:GetData()
	local strButtonName = wndHandler:GetName()
	if strButtonName == "BtnSplitStack" then
		Event_FireGenericEvent("GenericEvent_SplitItemStack", itemArg)
	elseif strButtonName == "BtnLinkToChat" then
		Event_FireGenericEvent("GenericEvent_LinkItemToChat", itemArg)
	elseif strButtonName == "BtnEditRunes" then
		Event_FireGenericEvent("GenericEvent_RightClick_OpenEngraving", itemArg)
	elseif strButtonName == "BtnPreviewItem" and self.nDecorId and self.nDecorId ~= 0 then
		Event_FireGenericEvent("GenericEvent_LoadDecorPreview", self.nDecorId)
	elseif strButtonName == "BtnPreviewItem" then
		Event_FireGenericEvent("GenericEvent_LoadItemPreview", itemArg)
	end

	self.wndMain:Close()
	self.wndMain = nil
end

function ContextMenuItem:HelperValidateEditRunes(itemArg)
	if not itemArg or itemArg:GetStackCount() == 0 then
		return false
	end

	local tRunes = itemArg:GetRuneSlots()
	return tRunes and tRunes.arRuneSlots
end

function ContextMenuItem:HelperValidatePreview(itemArg)
	local bValidWeaponForRace = true
	local bValidItemPreview = ktValidItemPreviewSlots[itemArg:GetSlot()] -- See if this is an item type you can preview (i.e. not a gadget)

	-- For weapons only, see if it is a valid race weapon combo
	if bValidItemPreview and itemArg:GetSlot() == 16 then
		local unitPlayer = GameLib.GetPlayerUnit()
		local ePlayerRace = unitPlayer:GetRaceId()
		bValidWeaponForRace = ktValidRaceWeaponPreview[ePlayerRace] and ktValidRaceWeaponPreview[ePlayerRace][itemArg:GetItemType()]
	end

	return bValidItemPreview and bValidWeaponForRace

	--[[
	local bRightClassOrProf = false
	local tProficiency = itemArg:GetProficiencyInfo()
	local ePlayerClass = unitPlayer:GetClassId()

    if #eItemClass > 0 then
		for idx,tClass in ipairs(eItemClass) do
			if tClass.idClassReq == unitPlayer:GetClassId() then
				bRightClassOrProf = true
			end
		end
	elseif tProficiency then
		bRightClassOrProf = true -- tProficiency.bHasProficiency
	end
	]]--
end

local ContextMenuItemInst = ContextMenuItem:new()
ContextMenuItemInst:Init()
