-----------------------------------------------------------------------------------------------
-- Client Lua Script for DecorPreview
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "HousingLib"
 
-----------------------------------------------------------------------------------------------
-- DecorPreview Module Definition
-----------------------------------------------------------------------------------------------
local DecorPreview = {} 
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function DecorPreview:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

	-- initialize our variables
	o.decorInfoId = 0
    return o
end

function DecorPreview:Init()
    Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- DecorPreview OnLoad
-----------------------------------------------------------------------------------------------
function DecorPreview:OnLoad()
    -- Register events
	Apollo.RegisterEventHandler("DecorPreviewOpen", "OnOpenPreviewDecor", self)
	Apollo.RegisterEventHandler("DecorPreviewClose", "OnCloseDecorPreviewWindow", self)
    
    -- load our forms
    self.wndDecorPreview 	= Apollo.LoadForm("DecorPreview.xml", "DecorPreviewWindow", nil, self)
    self.wndModelWindow 	= self.wndDecorPreview:FindChild("ModelWindow")
    self.wndRotateRight 	= self.wndDecorPreview:FindChild("RotateRightButton")
    self.wndRotateLeft 		= self.wndDecorPreview:FindChild("RotateLeftButton")
end


-----------------------------------------------------------------------------------------------
-- DecorPreview Functions
-----------------------------------------------------------------------------------------------

function DecorPreview:OnOpenPreviewDecor(idDecorInfo)
    self.wndDecorPreview:Show(true)
    self.idDecorInfo = idDecorInfo
    self:ShowDecorPreviewWindow()
    self.wndDecorPreview:ToFront()
end

---------------------------------------------------------------------------------------------------
function DecorPreview:ShowDecorPreviewWindow()
    -- don't do any of this if the Housing List isn't visible
	if not self.wndDecorPreview:IsVisible() then
		return
	end
	
	self.wndModelWindow:SetAnimated(true)
	self.wndModelWindow:SetDecorInfo(self.idDecorInfo)
end

---------------------------------------------------------------------------------------------------
function DecorPreview:OnWindowClosed()
	-- called after the window is closed by:
	--	self.winMasterCustomizeFrame:Close() or 
	--  hitting ESC or
	--  C++ calling Event_CloseDecorPreviewWindow()
	
	Sound.Play(Sound.PlayUIWindowClose)
end

---------------------------------------------------------------------------------------------------
function DecorPreview:OnCloseDecorPreviewWindow()
	-- close the window which will trigger OnWindowClosed
	self.tModelAssetPath = nil
	self.wndDecorPreview:Close()
end

---------------------------------------------------------------------------------------------------
function DecorPreview:OnRotateRightBegin()
	self.wndModelWindow:ToggleLeftSpin(true)
end

---------------------------------------------------------------------------------------------------
function DecorPreview:OnRotateRightEnd()
	self.wndModelWindow:ToggleLeftSpin(false)
end

---------------------------------------------------------------------------------------------------
function DecorPreview:OnRotateLeftBegin()
	self.wndModelWindow:ToggleRightSpin(true)
end

---------------------------------------------------------------------------------------------------
function DecorPreview:OnRotateLeftEnd()
	self.wndModelWindow:ToggleRightSpin(false)
end

---------------------------------------------------------------------------------------------------
function DecorPreview:OnResetViewBtn()
    self.wndModelWindow:ResetSpin()
end

-----------------------------------------------------------------------------------------------
-- DecorPreview Instance
-----------------------------------------------------------------------------------------------
local DecorPreviewInst = DecorPreview:new()
DecorPreviewInst:Init()
