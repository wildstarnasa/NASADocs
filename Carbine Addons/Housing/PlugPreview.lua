-----------------------------------------------------------------------------------------------
-- Client Lua Script for PlugPreview
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "HousingLib"
 
-----------------------------------------------------------------------------------------------
-- PlugPreview Module Definition
-----------------------------------------------------------------------------------------------
local PlugPreview = {} 
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PlugPreview:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

	-- initialize our variables
	o.plugItem = nil
	o.numScreenshots = 0
	o.currScreen = 0
    return o
end

function PlugPreview:Init()
    Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- PlugPreview OnLoad
-----------------------------------------------------------------------------------------------
function PlugPreview:OnLoad()
    -- Register events
	Apollo.RegisterEventHandler("PlugPreviewOpen", "OnOpenPreviewPlug", self)
	Apollo.RegisterEventHandler("PlugPreviewClose", "OnClosePlugPreviewWindow", self)
    
    -- load our forms
    self.winPlugPreview = Apollo.LoadForm("PlugPreview.xml", "PlugPreviewWindow", nil, self)
    self.winScreen = self.winPlugPreview:FindChild("Screenshot01")
    self.btnPrevious = self.winPlugPreview:FindChild("PreviousButton")
    self.btnNext = self.winPlugPreview:FindChild("NextButton")
end


-----------------------------------------------------------------------------------------------
-- PlugPreview Functions
-----------------------------------------------------------------------------------------------

function PlugPreview:OnOpenPreviewPlug(plugItemId)
    self.winPlugPreview:Show(true)
    local itemList = HousingLib.GetPlugItem(plugItemId)
    local ix, item
    for ix = 1, #itemList do
        item = itemList[ix]
        if item["id"] == plugItemId then
          self.plugItem = item
        end
    end

    self:ShowPlugPreviewWindow()
    self.winPlugPreview:ToFront()
end

---------------------------------------------------------------------------------------------------
function PlugPreview:ShowPlugPreviewWindow()
    -- don't do any of this if the Housing List isn't visible
	if self.winPlugPreview:IsVisible() then
		self.numScreenshots = #self.plugItem["screenshots"]
	    self.currScreen = 1

        if self.numScreenshots > 1 then
            self.btnPrevious:Enable(true)
            self.btnNext:Enable(true)
        else
            self.btnPrevious:Enable(false)
            self.btnNext:Enable(false)
        end
	    
	    self:DrawScreenshot()
		return
	end
	
end

---------------------------------------------------------------------------------------------------
function PlugPreview:OnWindowClosed()
	-- called after the window is closed by:
	--	self.winMasterCustomizeFrame:Close() or 
	--  hitting ESC or
	--  C++ calling Event_ClosePlugPreviewWindow()
	
	Sound.Play(Sound.PlayUIWindowClose)
end

---------------------------------------------------------------------------------------------------
function PlugPreview:OnClosePlugPreviewWindow()
	-- close the window which will trigger OnWindowClosed
	self.winPlugPreview:Close()
end

---------------------------------------------------------------------------------------------------
function PlugPreview:OnNextButton()
    self.currScreen = self.currScreen + 1
    if self.currScreen > self.numScreenshots then
        self.currScreen = 1
    end
    
    self:DrawScreenshot()
end

---------------------------------------------------------------------------------------------------
function PlugPreview:OnPreviousButton()
    self.currScreen = self.currScreen - 1
    if self.currScreen < 1 then
        self.currScreen = self.numScreenshots
    end
    
    self:DrawScreenshot()
end

---------------------------------------------------------------------------------------------------
function PlugPreview:DrawScreenshot()
    if self.numScreenshots > 0 and self.plugItem ~= nil then
        local spriteList = self.plugItem["screenshots"]
        local sprite = spriteList[self.currScreen].sprite
        self.winScreen:SetSprite("ClientSprites:"..sprite)
    else
        self.winScreen:SetSprite("")
    end
end

---------------------------------------------------------------------------------------------------
function PlugPreview:GetItem(id, itemlist)
  local ix, item
  for ix = 1, #itemlist do
    item = itemlist[ix]
    if item["id"] == id then
      return item
    end
  end
  return nil
end

-----------------------------------------------------------------------------------------------
-- PlugPreview Instance
-----------------------------------------------------------------------------------------------
local PlugPreviewInst = PlugPreview:new()
PlugPreviewInst:Init()
st()
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
="640" Stretchy="1" HotspotX="0" HotspotY="0" Duration="1.000" StartColor="ffffffff" EndColor="ffffffff" />
    </Sprite>
    <Sprite Name="sprProperty11" Cycle="1">
        <Frame Texture="UI\Tex