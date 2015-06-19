-----------------------------------------------------------------------------------------------
-- Client Lua Script for AdventureLevianBay
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
local AdventureLevianBay = {} 

local ktTeam =
{
	One = 1,
	Two = 2,
}

local ktSetPieces =
{
	Intro 				= 0,
	IntroTransition 	= 1,
	One 				= 2,
	OneTransition 		= 3,
	Two 				= 4,
	TwoTransition 		= 5,
	Three 				= 6,
}

local kstrCompletedSprite = "BK3:UI_BK3_Holo_Adventure_MilestoneUpdate_Upcoming"
local kstrActiveSprite = "BK3:UI_BK3_Holo_Adventure_MilestoneUpdate_Active"
local kstrActivePulse = "BK3:UI_BK3_Holo_Adventure_MilestoneUpdate_ActivePulse"
 
function AdventureLevianBay:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function AdventureLevianBay:Init()
	Apollo.RegisterAddon(self)
end
 
function AdventureLevianBay:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("AdventureLevianBay.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	
	Apollo.RegisterEventHandler("ChangeWorld", "HideUI", self)
end

function AdventureLevianBay:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("AdvLevianBayHideUI", 			"HideUI", self)
	Apollo.RegisterEventHandler("AdvLevianBayUpdateProgress", 	"AdvLevianBayProgress", self)
	Apollo.RegisterEventHandler("AdvLevianBayUpdatePosition", 	"UpdatePosition", self)
	Apollo.RegisterEventHandler("AdvLevianBayTeamDead", 		"TeamDead", self)
	
	self.wndMain 		= Apollo.LoadForm(self.xmlDoc, "AdvLevianBayForm", nil, self)
	self.wndTeam1 		= self.wndMain:FindChild("wndTeam1")
	self.wndTeam2 		= self.wndMain:FindChild("wndTeam2")
	self.wndPlayerTeam 	= self.wndMain:FindChild("wndPlayerTeam")
	
	self:HideUI()
end

function AdventureLevianBay:ShowUI()
	if not self.wndMain or not self.wndMain:IsValid() or self.wndMain:IsShown() then	-- UI is not present / valid / already shown, exit
		return
	end

	self.wndMain:Show(true)
end

function AdventureLevianBay:HideUI()
	self.wndTeam1:SetData(0)
	self.wndTeam2:SetData(0)
	self.wndPlayerTeam:SetData(0)
	
	--Reset the positions to be the Intro, keeping into account if the team is dead.
	local bTeam1Dead = self.wndMain:FindChild("wndTeam1Dead"):IsShown()
	local bTeam2Dead = self.wndMain:FindChild("wndTeam2Dead"):IsShown()
	self:UpdatePosition(ktTeam.One, ktSetPieces.IntroTransition, 0, bTeam1Dead)
	self:UpdatePosition(ktTeam.Two, ktSetPieces.IntroTransition, 0, bTeam2Dead)
	self:AdvLevianBayProgress(ktSetPieces.Intro)
	
	--Calling UpdatePosition and AdvLevianBayProgress shows the UI, so must show(false) after them.
	self.wndMain:Show(false)
end

function AdventureLevianBay:AdvLevianBayProgress(nSetPiece)
	self:ShowUI()
	if nSetPiece >= ktSetPieces.Intro then
		self.wndMain:FindChild("wndSet0"):SetSprite(kstrCompletedSprite)
	end
	
	if nSetPiece == ktSetPieces.One then	--In Progress
		self.wndMain:FindChild("wndSet1"):SetSprite(kstrActiveSprite)
		self.wndMain:FindChild("wndSet1"):FindChild("wndSet1Pulse"):SetSprite(kstrActivePulse)
	elseif nSetPiece > ktSetPieces.One then	--Completed
		self.wndMain:FindChild("wndSet1"):SetSprite(kstrCompletedSprite)
		self.wndMain:FindChild("wndSet1"):FindChild("wndSet1Pulse"):SetSprite("")
	end
	
	if nSetPiece == ktSetPieces.Two then	--In Progress
		self.wndMain:FindChild("wndSet2"):SetSprite(kstrActiveSprite)
		self.wndMain:FindChild("wndSet2"):FindChild("wndSet2Pulse"):SetSprite(kstrActivePulse)
	elseif nSetPiece > ktSetPieces.Two then	--Completed
		self.wndMain:FindChild("wndSet2"):SetSprite(kstrCompletedSprite)
		self.wndMain:FindChild("wndSet2"):FindChild("wndSet2Pulse"):SetSprite("")
	end

	if nSetPiece == ktSetPieces.Three then --In Progress
		self.wndMain:FindChild("wndSet3"):SetSprite(kstrActiveSprite)
		self.wndMain:FindChild("wndSet3"):FindChild("wndSet3Pulse"):SetSprite(kstrActivePulse)
	elseif nSetPiece > ktSetPieces.Three then	--Completed
		self.wndMain:FindChild("wndSet3"):SetSprite(kstrCompletedSprite)
		self.wndMain:FindChild("wndSet3"):FindChild("wndSet3Pulse"):SetSprite("")
	end
end

function AdventureLevianBay:UpdatePosition(nTeam, nLeg, nPosition, bIsDead)
	self:ShowUI()
	local wndTeam = self.wndMain:FindChild("wndPlayerTeam")
	local wndSetIcon = nil
	local wndTeamIcon = nil
	local wndTeamDead = nil
	local wndStart = nil
	local wndEnd = nil
	
	if nTeam == ktTeam.One then
		wndTeam = self.wndMain:FindChild("wndTeam1")
		wndSetIcon = wndTeam:FindChild("wndTeam1SetPiece")
		wndTeamDead = wndTeam:FindChild("wndTeam1Dead")
		wndTeamIcon = wndTeam:FindChild("wndTeam1Icon")
	elseif nTeam == ktTeam.Two then
		wndTeam = self.wndMain:FindChild("wndTeam2")
		wndSetIcon = wndTeam:FindChild("wndTeam2SetPiece")
		wndTeamDead = wndTeam:FindChild("wndTeam2Dead")
		wndTeamIcon = wndTeam:FindChild("wndTeam2Icon")
	end
	
	if wndTeamDead and wndTeamIcon then
		wndTeamDead:Show(bIsDead)
		wndTeamIcon:Show(not bIsDead)
	end	
	
	if nLeg == ktSetPieces.IntroTransition then
		wndStart = self.wndMain:FindChild("wndSet0")
		wndEnd = self.wndMain:FindChild("wndSet1")
	elseif nLeg == ktSetPieces.One then
		wndStart = self.wndMain:FindChild("wndSet1")
		wndEnd = self.wndMain:FindChild("wndSet1")
	elseif nLeg == ktSetPieces.OneTransition then
		wndStart = self.wndMain:FindChild("wndSet1")
		wndEnd = self.wndMain:FindChild("wndSet2")
	elseif nLeg == ktSetPieces.Two then
		wndStart = self.wndMain:FindChild("wndSet2")
		wndEnd = self.wndMain:FindChild("wndSet2")
	elseif nLeg == ktSetPieces.TwoTransition then
		wndStart = self.wndMain:FindChild("wndSet2")
		wndEnd = self.wndMain:FindChild("wndSet3")
	elseif nLeg == ktSetPieces.Three then
		wndStart = self.wndMain:FindChild("wndSet3")
		wndEnd = self.wndMain:FindChild("wndSet3")
	else
		return
	end

	local nTeamLeft, nTeamTop, nTeamRight, nTeamBottom = wndTeam:GetAnchorOffsets()	-- wndTeam's current position on the track
	local nStartLeft, nStartTop, nStartRight, nStartBottom = wndStart:GetAnchorOffsets()
	local nEndLeft, nEndTop, nEndRight, nEndBottom = wndEnd:GetAnchorOffsets()
	local nLegWidth = nEndLeft - nStartRight
	local nWidth = wndTeam:GetWidth()
	local nNewPosition = (nLegWidth * nPosition / 100) - 13
	
	wndTeam:SetData(nStartRight + nNewPosition)
	wndTeam:Show(true)
	if nLeg == ktSetPieces.One or nLeg == ktSetPieces.Two or nLeg == ktSetPieces.Three then
		wndTeam:SetAnchorOffsets((nStartLeft + nStartRight) / 2 - (13), nTeamTop, (nStartLeft+nStartRight) / 2 - (13) + nWidth, nTeamBottom)
		
		if wndSetIcon ~= nil then
			wndSetIcon:Show(true)
		end
	else
		wndTeam:SetAnchorOffsets(nStartRight + nNewPosition, nTeamTop, nStartRight + nNewPosition + nWidth, nTeamBottom)	-- wndTeam's new position
		
		if wndSetIcon ~= nil then
			wndSetIcon:Show(false)
		end
	end
	
	local bPlayerIsWinning = self.wndPlayerTeam:GetData() > self.wndTeam1:GetData() and self.wndPlayerTeam:GetData() > self.wndTeam2:GetData()
	self.wndMain:SetSprite(bPlayerIsWinning and "BK3:UI_BK3_Holo_Framing_3" or "BK3:UI_BK3_Holo_Framing_3_Alert")
end

function AdventureLevianBay:TeamDead(nTeam)
	self:ShowUI()
	local wndTeam = self.wndMain:FindChild("wndTeam2Dead")
	local wndTeamIcon = self.wndMain:FindChild("wndTeam2Icon")
	local wndTeamFraming = self.wndMain:FindChild("wndTeam2SetPiece")
	
	if nTeam == ktTeam.One then
		wndTeam = self.wndMain:FindChild("wndTeam1Dead")
		wndTeamIcon = self.wndMain:FindChild("wndTeam1Icon")
		wndTeamFraming = self.wndMain:FindChild("wndTeam1SetPiece")
	end
	
	wndTeam:Show(true)
	wndTeamFraming:Show(false)
	wndTeamIcon:Show(false)
end

local AdventureLevianBayInst = AdventureLevianBay:new()
AdventureLevianBayInst:Init()