-----------------------------------------------------------------------------------------------
-- Client Lua Script for Stuck
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "HousingLib"

local Stuck = {}

function Stuck:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Stuck:Init()
    Apollo.RegisterAddon(self)
end

function Stuck:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Stuck.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function Stuck:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
    Apollo.RegisterSlashCommand("stuck", 				"OnStuckToggle", self)
	Apollo.RegisterEventHandler("ToggleStuckWindow", 	"OnStuckToggle", self)

	Apollo.RegisterTimerHandler("Stuck_OneSecondTimer", "RedrawCooldowns", self)
	Apollo.CreateTimer("Stuck_OneSecondTimer", 1, false)
end


-----------------------------------------------------------------------------------------------
-- Stuck Functions
-----------------------------------------------------------------------------------------------

function Stuck:OnStuckToggle()
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "StuckForm", nil, self)
		
		if self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
		self:RedrawCooldowns()
	else
		self.wndMain:Show(not self.wndMain:IsShown())
		Apollo.StopTimer("Stuck_OneSecondTimer")
	end

end

function Stuck:RedrawCooldowns()
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
		local tCooldowns = GameLib.GetStuckCooldowns()
		local nBindTime = tCooldowns[GameLib.SupportStuckAction.RecallBind].fCooldownTime
		local nHomeTime = tCooldowns[GameLib.SupportStuckAction.RecallHouse].fCooldownTime
		self.wndMain:FindChild("BindButton"):Enable(nBindTime == 0)
		self.wndMain:FindChild("BindButton"):Show(GameLib.HasBindPoint())
		self.wndMain:FindChild("BindCooldownText"):SetText(self:HelperConvertTimeToString(nBindTime))
		self.wndMain:FindChild("HomeButton"):Enable(nHomeTime == 0)
		self.wndMain:FindChild("HomeButton"):Show(HousingLib.IsResidenceOwner())
		self.wndMain:FindChild("HomeCooldownText"):SetText(self:HelperConvertTimeToString(nHomeTime))
		self.wndMain:FindChild("ArrangeHorz"):ArrangeChildrenHorz(1)
		Apollo.StartTimer("Stuck_OneSecondTimer")
	end
end

function Stuck:HelperConvertTimeToString(nTime)
	return nTime == 0 and "" or string.format("%d:%.02d", math.floor(nTime / 60), nTime % 60)
end

-----------------------------------------------------------------------------------------------
-- StuckForm Functions
-----------------------------------------------------------------------------------------------

function Stuck:OnClose()
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
		Apollo.StopTimer("Stuck_OneSecondTimer")
	end
end

function Stuck:OnBind()
	GameLib.SupportStuck(GameLib.SupportStuckAction.RecallBind)
	self:OnClose()
end

function Stuck:OnHome()
	GameLib.SupportStuck(GameLib.SupportStuckAction.RecallHouse)
	self:OnClose()
end

function Stuck:OnPickDeath()
	if not self.wndConfirm or not self.wndConfirm:IsValid() then
		self.wndConfirm = Apollo.LoadForm(self.xmlDoc, "DeathConfirm", self.wndMain, self)
	end
	self.wndMain:FindChild("Blocker"):Show(true)

	local tCooldowns = GameLib.GetStuckCooldowns()
	if tCooldowns[GameLib.SupportStuckAction.RecallDeath].fCooldownTime == 0 then
		self.wndConfirm:FindChild("NoticeText"):SetText(Apollo.GetString("CRB_Stuck_Death_ConfirmFree"))
	else
		self.wndConfirm:FindChild("NoticeText"):SetText(Apollo.GetString("CRB_Stuck_Death_Confirm"))
	end
end

function Stuck:OnYes() -- After OnPickDeath
	GameLib.SupportStuck(GameLib.SupportStuckAction.RecallDeath)
	self:OnClose()
end

function Stuck:OnNo() -- After OnPickDeath
	self.wndMain:FindChild("Blocker"):Show(false)
	self.wndConfirm:Destroy()
end

local StuckInst = Stuck:new()
StuckInst:Init()
Picture="1" Sprite="BK3:UI_BK3_Holo_Framing_3_StoryPanel" BGColor="ffffffff" TextColor="ff87dedb" Visible="0" TooltipColor="" Escapable="1" Overlapped="1" TestAlpha="1">
        <Control Name="StoryPanelText" Class="MLWindow" LAnchorPoint="0" LAnchorOffset="36" TAnchorPoint="0" TAnchorOffset="35" RAnchorPoint="1" RAnchorOffset="-36" BAnchorPoint="1" BAnchorOffset="-32" DT_WORDBREAK="1" Font="CRB_Dialog" TextColor="0xff000000" BGColor="ffffffff" IgnoreMouse="1" TooltipColor=""/>
        <Event Name="MouseButtonDown" Function="OnStoryPanelMouseDown"/>
        <Event Name="MouseEnter" Function="OnStoryPanelMouseEnter"/>
        <Event Name="MouseExit" Function="OnStoryPanelMouseExit"/>
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="ClosePrompt" BGColor="ffffffff" TextColor="ffffffff" Picture="1" IgnoreMouse="1" Sprite="" NoClip="1" Visible="0" TooltipColor="" TestAlpha="1">
            <Pixie LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" BGColor="eeffffff" Font="Default" TextColor="ffffffff" Text="" Sprite="BK3:UI_BK3_Holo_Framing_3_StoryPanel" Line="0"/>
            <Pixie LAnchorPoint=".5" LAnchorOffset="-20" TAnchorPoint=".5" TAnchorOffset="-20" RAnchorPoint=".5" RAnchorOffset="20" BAnchorPoint=".5" BAnchorOffset="20" Sprite="ClientSprites:LootCloseBox_Holo" BGColor="ccffffff" TextColor="black" Rotation="0" Font="Default"/>
        </Control>
    </Form>
    <Form Name="StoryPanelFullScreen" Class="Window" LAnchorPoint="0.0" LAnchorOffset="0" TAnchorPoint="0.0" TAnchorOffset="0" RAnchorPoint="1.0" RAnchorOffset="2" BAnchorPoint="1.0" BAnchorOffset="0" Border="0" SwallowMouseClicks="1" Escapeable="1" Overlapped="1" NoClip="1" NewControlDepth="11000" NewWindowDepth="1" AutoFade="0" AutoHideScroll="1" Template="Default" Picture="1" Sprite="WhiteFill" BGColor="0xff000000" TextColor="ffffffff" Visible="0" TooltipColor="" Escapable="0">
        <Control Name="StoryPanelText" Class="MLWindow" LAnchorPoint=".5" LAnchorOffset="-200" TAnchorPoint=".5" TAnchorOffset="-108" RAnchorPoint=".5" RAnchorOffset="200" BAnchorPoint=".5" BAnchorOffset="92" DT_WORDBREAK="1" Font="CRB_InterfaceLarge" TextColor="0xffEEC900" BGColor="ffffffff" DT_VCENTER="1" DT_CENTER="1" TooltipColor=""/>
        <Control Class="Window" LAnchorPoint=".5" LAnchorOffset="-220" TAnchorPoint=".5" TAnchorOffset="-128" RAnchorPoint=".5" RAnchorOffset="220" BAnchorPoint=".5" BAnchorOffset="112" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="StoryPanelFlash" BGColor="ffffffff" TextColor="ffffffff" Picture="1" IgnoreMouse="1" TooltipColor=""/>
    </Form>
    <Form Name="StoryPanelWhiteout" Class="Window" LAnchorPoint="0.0" LAnchorOffset="0" TAnchorPoint="0.0" TAnchorOffset="0" RAnchorPoint="1.0" RAnchorOffset="0" BAnchorPoint="1.0" BAnchorOffset="0" Border="0" SwallowMouseClicks="1" Escapeable="1" Overlapped="1" NoClip="1" NewControlDepth="11000" NewWindowDepth="1" AutoFade="1" AutoHideScroll="1" Template="Default" Picture="1" Sprite="WhiteFill" BGColor="0xffffffff" TextColor="ffffffff" Visible="0" TooltipColor="">
        <Control Name="StoryPanelText" Class="MLWindow" LAnchorPoint="0.75" LAnchorOffset="-200" TAnchorPoint="0.75" TAnchorOffset="-100" RAnchorPoint="0.75" RAnchorOffset="200" BAnchorPoint="0.75" BAnchorOffset="100" DT_WORDBREAK="1" Font="CRB_Dialog" TextColor="0xffEEC900" BGColor="ffffffff" TooltipColor=""/>
    </Form>
    <Form Name="StoryPanelUrgent" Class="Window" LAnchorPoint="0.5" LAnchorOffset="-225" RAnchorPoint="0.5" RAnchorOffset="225" TAnchorPoint="0" TAnchorOffset="100" BAnchorPoint="0" BAnchorOffset="208" Template="Default" Pict