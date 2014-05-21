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
