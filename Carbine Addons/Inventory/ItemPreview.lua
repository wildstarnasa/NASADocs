-----------------------------------------------------------------------------------------------
-- Client Lua Script for ItemPreview
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Item"

local ItemPreview = {}

local ktValidItemPreviewSlots =
{
	2,
	3,
	0,
	5,
	1,
	4,
	16
}

local knSaveVersion = nil

function ItemPreview:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ItemPreview:Init()
    Apollo.RegisterAddon(self)
end

function ItemPreview:OnSave(eType)
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

function ItemPreview:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function ItemPreview:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ItemPreview.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ItemPreview:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_LoadItemPreview", "OnGenericEvent_LoadItemPreview", self)
	self.bSheathed = false
end

function ItemPreview:OnGenericEvent_LoadItemPreview(item)
	if item == nil then
		return
	end

	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "ItemPreviewForm", "TooltipStratum", self)
		self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	
		local nWndLeft, nWndTop, nWndRight, nWndBottom = self.wndMain:GetRect()
		local nWndWidth = nWndRight - nWndLeft
		local nWndHeight = nWndBottom - nWndTop
		self.wndMain:SetSizingMinimum(nWndWidth - 10, nWndHeight - 10)

		if self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
	end

	self.wndMain:FindChild("PreviewWindow"):SetItem(item)

	local strItem = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloTitle\" Align=\"Center\">%s</T>", item:GetName())
	self.wndMain:FindChild("ItemLabel"):SetAML("<P Align=\"Center\">"..String_GetWeaselString(strItem).."</P>")

	-- set sheathed or not
	local eItemType = item:GetItemType()
	self.bSheathed = eItemType == Item.CodeEnumItemType.WeaponMHEnergy or not self:HelperCheckForWeapon(eItemType)

	self.wndMain:FindChild("PreviewWindow"):SetSheathed(self.bSheathed)
	self:HelperFormatSheathButton(self.bSheathed)
	self.wndMain:FindChild("SheathButton"):Enable(eItemType ~= Item.CodeEnumItemType.WeaponMHEnergy) -- Psyblades can't be unsheathed

	self.wndMain:Show(true)
end

function ItemPreview:HelperCheckForWeapon(eItemType)
	return eItemType >= Item.CodeEnumItemType.WeaponMHPistols and eItemType <= Item.CodeEnumItemType.WeaponMHSword
end

function ItemPreview:HelperFormatSheathButton(bSheathed)
	self.wndMain:FindChild("SheathButton"):SetText(bSheathed and Apollo.GetString("Inventory_DrawWeapons") or Apollo.GetString("Inventory_Sheathe"))
end

function ItemPreview:OnWindowClosed( wndHandler, wndControl )
	if self.wndMain ~= nil then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function ItemPreview:OnCloseBtn( wndHandler, wndControl, eMouseButton )
	self:OnWindowClosed()
end

function ItemPreview:OnToggleSheathButton( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("PreviewWindow"):SetSheathed(wndControl:IsChecked())
end

function ItemPreview:OnToggleSheathed( wndHandler, wndControl, eMouseButton )
	local bSheathed = not self.bSheathed
	self.wndMain:FindChild("PreviewWindow"):SetSheathed(bSheathed)
	self:HelperFormatSheathButton(bSheathed)

	self.bSheathed = bSheathed
end

-- Spin Code

function ItemPreview:OnRotateRight()
	self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(true)
end

function ItemPreview:OnRotateRightCancel()
	self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(false)
end

function ItemPreview:OnRotateLeft()
	self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(true)
end

function ItemPreview:OnRotateLeftCancel()
	self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(false)
end

local ItemPreviewInst = ItemPreview:new()
ItemPreviewInst:Init()
rOffset="63" RelativeToClient="1" Font="CRB_HeaderMedium" Text="" Template="Default" TooltipType="OnCursor" Name="TitleForm" BGColor="black" TextColor="UI_WindowTitleYellow" TooltipColor="" TextId="CRB_Salvage" DT_VCENTER="1" DT_CENTER="1"/>
        <Control Class="ActionConfirmButton" Base="BK3:btnHolo_Blue_Med" Font="CRB_Button" ButtonType="PushButton" RadioGroup="" LAnchorPoint="1" LAnchorOffset="-200" TAnchorPoint="1" TAnchorOffset="-103" RAnchorPoint="1" RAnchorOffset="-42" BAnchorPoint="1" BAnchorOffset="-29" DT_VCENTER="1" DT_CENTER="1" Name="SalvageBtn" BGColor="green" TextColor="UI_BtnTextGreenNormal" NormalTextColor="UI_BtnTextGreenNormal" PressedTextColor="UI_BtnTextGreenPressed" FlybyTextColor="UI_BtnTextGreenFlyby" PressedFlybyTextColor="UI_BtnTextGreenPressedFlyby" WindowSoundTemplate="PushbuttonDigi02" TextId="GVT_Salvage" DisabledTextColor="UI_BtnTextHoloDisabled" Text="" TooltipColor="" TestAlpha="1" DT_WORDBREAK="1" ButtonTextXMargin="18">
            <Event Name="SalvageItemRequested" Function="OnSalvageCurr"/>
        </Control>
    </Form>
    <Form Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="0" BAnchorOffset="65" RelativeToClient="1" Name="SalvageListItem" Overlapped="1" Text="" TextId="" BGColor="ffffffff" TextColor="ffffffff" TooltipType="OnCursor" IgnoreMouse="1" TooltipColor="" Tooltip="" HideInEditor="0">
        <Control Class="Button" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="-2" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Name="SalvageListItemBtn" Overlapped="0" Text="" TextId="" Base="BK3:btnHolo_ListView_Simple" ButtonType="Check" GlobalRadioGroup="Salvage_ListItemRadioGroup" Visible="1" BGColor="ffffffff" TextColor="ffffffff" NormalTextColor="ffffffff" PressedTextColor="ffffffff" FlybyTextColor="ffffffff" PressedFlybyTextColor="ffffffff" DisabledTextColor="ffffffff" TooltipType="OnCursor" RadioGroup="" IgnoreMouse="0" RadioDisallowNonSelection="0" TooltipColor="" IgnoreTooltipDelay="1" HideInEditor="0">
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="6" RAnchorPoint="0" RAnchorOffset="61" BAnchorPoint="1" BAnchorOffset="-6" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="SalvageListItemIconBG" BGColor="ffffffff" TextColor="ffffffff" Picture="1" IgnoreMouse="1" Sprite="BK3:UI_BK3_Holo_InsetSimple" TooltipColor="" NewControlDepth="1"/>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="12" TAnchorPoint="0" TAnchorOffset="10" RAnchorPoint="0" RAnchorOffset="57" BAnchorPoint="1" BAnchorOffset="-10" RelativeToClient="1" Text="" Name="SalvageListItemIcon" Picture="1" IgnoreMouse="1" Sprite="" BGColor="ffffffff" TextColor="ffffffff" NewControlDepth="1" DT_BOTTOM="1" Tooltip="" DT_RIGHT="1" Font="CRB_InterfaceMedium_B" TooltipColor="" IgnoreTooltipDelay="1" TooltipType="OnCursor" Subclass="ItemWindowSubclass"/>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="13" TAnchorPoint="0" TAnchorOffset="11" RAnchorPoint="0" RAnchorOffset="33" BAnchorPoint="0" BAnchorOffset="31" RelativeToClient="1" Text="" Name="SalvageListItemCantUse" Picture="1" IgnoreMouse="1" Sprite="ClientSprites:Icon_Windows_UI_CRB_Tooltip_Restricted" BGColor="ffffffff" TextColor="ffffffff" NewControlDepth="1" 