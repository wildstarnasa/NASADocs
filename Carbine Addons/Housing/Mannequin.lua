-----------------------------------------------------------------------------------------------
-- Client Lua Script for Mannequin
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "HousingLib"
 
-----------------------------------------------------------------------------------------------
-- Mannequin Module Definition
-----------------------------------------------------------------------------------------------
local Mannequin = {} 


local ktSlotWindowNameToTooltip = 
{
	["HeadSlot"] 		= "Character_HeadEmpty",
	["ShoulderSlot"] 	= "Character_ShoulderEmpty",
	["ChestSlot"] 		= "Character_ChestEmpty",
	["HandsSlot"] 		= "Character_HandsEmpty",
	["LegsSlot"] 		= "Character_LegsEmpty",
	["FeetSlot"] 		= "Character_FeetEmpty",
	["WeaponSlot"] 		= "Character_WeaponEmpty",
}
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Mannequin:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    
    self.tPoseItems = {}

    return o
end

function Mannequin:Init()
    Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- Mannequin OnLoad
-----------------------------------------------------------------------------------------------
function Mannequin:OnLoad()
    -- Register events
	Apollo.RegisterEventHandler("HousingMannequinOpen", "OnMannequinWindowOpen", self)
	Apollo.RegisterEventHandler("HousingMannequinClose", "OnMannequinWindowClose", self)
	Apollo.RegisterEventHandler("CloseVendorWindow", 		"OnCloseVendorWindow", self)
    
    -- load our forms
    self.xmlDoc = XmlDoc.CreateFromFile("Mannequin.xml")
    self.wndMannequin = Apollo.LoadForm(self.xmlDoc, "MannequinWindow", nil, self)
    self.wndCostume = self.wndMannequin:FindChild("Costume")
    
    self.btnPoseSelect = self.wndMannequin:FindChild("PoseSelectButton")
    self.wndPoseFrame = self.wndMannequin:FindChild("PoseListFrame")
    self.wndPoseList = self.wndPoseFrame:FindChild("PoseList")
    
    self.wndMannequin:Show(false)
end


-----------------------------------------------------------------------------------------------
-- Mannequin Functions
-----------------------------------------------------------------------------------------------

function Mannequin:OnMannequinWindowOpen()
    self:ShowMannequinWindow()
    self.wndMannequin:ToFront()
end

---------------------------------------------------------------------------------------------------
function Mannequin:ShowMannequinWindow()
    -- don't do any of this if the Housing List isn't visible
	if self.wndMannequin:IsVisible() then
		return
	end
	
	local unitMannequin = GameLib.GetTargetUnit()
	self.wndCostume:SetCostume(unitMannequin)
	self.wndCostume:SetSheathed(true)
	
	local tPoseList = HousingLib.GetMannequinPoseList()
	local nPoseId = HousingLib.GetMannequinPose()
	self.btnPoseSelect:SetText(tPoseList[nPoseId].strPoseName)
	
    self.wndMannequin:Show(true)
end

---------------------------------------------------------------------------------------------------
function Mannequin:OnWindowClosed(wndHandler, wndControl)
	-- called after the window is closed by:
	--	self.winMasterCustomizeFrame:Close() or 
	--  hitting ESC or
	--  C++ calling Event_CloseMannequinWindow()
	
	if wndControl ~= wndHandler then
	    return
	end
	
	Event_CancelHousingMannequin()
	
	Sound.Play(Sound.PlayUIWindowClose)
end

---------------------------------------------------------------------------------------------------
function Mannequin:OnMannequinWindowClose()
	-- close the window which will trigger OnWindowClosed
	self:DestroyPoseList()
	self.wndMannequin:Close()
end

function Mannequin:OnCloseVendorWindow()
	self.wndMannequin:Close() -- just close the window which will trigger OnWindowClosed
end

---------------------------------------------------------------------------------------------------
function Mannequin:OnSlotClick(wndControl, wndHandler, eButton, nX, nY)
	--Sound.Play(Sound.PlayUI49EquipClothingArmorVirtual)
	
	local unitMannequin = GameLib.GetTargetUnit()
	self.wndCostume:SetCostume(unitMannequin)
	self.wndCostume:SetSheathed(true)
end

function Mannequin:OnRotateRight()
	self.wndCostume:ToggleLeftSpin(true)
end

function Mannequin:OnRotateRightCancel()
	self.wndCostume:ToggleLeftSpin(false)
end

function Mannequin:OnRotateLeft()
	self.wndCostume:ToggleRightSpin(true)
end

function Mannequin:OnRotateLeftCancel()
	self.wndCostume:ToggleRightSpin(false)
end

function Mannequin:OnPoseSelectCheck()
    self.wndPoseFrame:Show(true)
    self:PopulatePoseList()
end

function Mannequin:OnPoseSelectUncheck()
    self.wndPoseFrame:Show(false)
    self:PopulatePoseList()
end

function Mannequin:OnPoseWindowClosed()
    self.btnPoseSelect:SetCheck(false)
end

-- populate item list
function Mannequin:PopulatePoseList()
	-- make sure the tItemData list is empty to start with
	self:DestroyPoseList()
	self.wndPoseList:DestroyChildren()

    -- grab the list of categories
    local tPoseList = HousingLib.GetMannequinPoseList()
	
	-- populate the list
    if tPoseList ~= nil then
        for idx = 1, #tPoseList do
			self:AddPoseEntry(idx, tPoseList[idx])
        end
    end
	
	-- now all the items are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndPoseList:ArrangeChildrenVert()
end

function Mannequin:DestroyPoseList()
	-- destroy all the wnd inside the list
	for idx, wndListItem in ipairs(self.tPoseItems) do
		wndListItem:Destroy()
	end

	-- clear the list item array
	self.tPoseItems = {}
end

-- add a pose into the pose list
function Mannequin:AddPoseEntry(nIndex, tItemData)
	-- load the window tItemData for the list tItemData
	local wndListItem = Apollo.LoadForm(self.xmlDoc, "PoseListItem", self.wndPoseList, self)
	
	-- keep track of the window tItemData created
	self.tPoseItems[nIndex] = wndListItem

	-- give it a piece of data to refer to 
	local wndItemBtn = wndListItem:FindChild("PoseBtn")
	if wndItemBtn then -- make sure the text wndListItem exist
	    local strName = tItemData.strPoseName
		wndItemBtn:SetText(strName)
		wndItemBtn:SetData(tItemData)
	end
end

function Mannequin:OnPoseSelected(wndHandler, wndControl)
    local tPoseData = wndControl:GetData()
    
    HousingLib.SetMannequinPose(tPoseData.nId)
    
    self.btnPoseSelect:SetCheck(false)
    self.wndPoseFrame:Show(false)
    self.btnPoseSelect:SetText(tPoseData.strPoseName)
end

---------------------------------------------------------------------------------------------------
function Mannequin:OnGenerateTooltip(wndHandler, wndControl, eType, itemCurr, idx)
	if eType == Tooltip.TooltipGenerateType_ItemInstance then
		if itemCurr == nil then
			local strTooltip = ""
			if wndControl:GetName() then
				strTooltip = Apollo.GetString(ktSlotWindowNameToTooltip[wndControl:GetName()])
			end
			if strTooltip then
				wndControl:SetTooltip("<P Font=\"CRB_InterfaceSmall_O\">"..strTooltip.."</P>")
			end
		else
			local itemEquipped = nil
			
			Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = true, itemCompare = itemEquipped})
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Mannequin Instance
-----------------------------------------------------------------------------------------------
local MannequinInst = Mannequin:new()
MannequinInst:Init()
