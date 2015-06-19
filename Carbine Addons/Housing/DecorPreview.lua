-----------------------------------------------------------------------------------------------
-- Client Lua Script for DecorPreview
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "HousingLib"

local DecorPreview = {}

function DecorPreview:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	o.decorInfoId = 0
    return o
end

function DecorPreview:Init()
    Apollo.RegisterAddon(self)
end

function DecorPreview:OnLoad()
	Apollo.RegisterEventHandler("GenericEvent_LoadDecorPreview", "OnGenericEvent_LoadDecorPreview", self)
	Apollo.RegisterEventHandler("DecorPreviewClose", "OnCloseDecorPreviewWindow", self)
end

function DecorPreview:OnGenericEvent_LoadDecorPreview(idDecorInfo)
	if not self.wndDecorPreview or not self.wndDecorPreview:IsValid() then
		self.wndDecorPreview 	= Apollo.LoadForm("DecorPreview.xml", "DecorPreviewWindow", nil, self)
		self.wndModelWindow 	= self.wndDecorPreview:FindChild("ModelWindow")
		self.wndRotateRight 	= self.wndDecorPreview:FindChild("RotateRightButton")
		self.wndRotateLeft 		= self.wndDecorPreview:FindChild("RotateLeftButton")

		self.wndDecorPreview:SetSizingMinimum(280, 270)
		self.wndDecorPreview:SetSizingMaximum(800, 700)
	end

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
	self.wndDecorPreview:Destroy()
	self.wndDecorPreview = nil
	self.tModelAssetPath = nil
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
