-----------------------------------------------------------------------------------------------
-- Client Lua Script for CrowdControlGameplay
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "GameLib"

local CrowdControlGameplay = {}

function CrowdControlGameplay:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function CrowdControlGameplay:Init()
    Apollo.RegisterAddon(self)
end

function CrowdControlGameplay:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CrowdControlGameplay.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function CrowdControlGameplay:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("ActivateCCStateStun", "OnActivateCCStateStun", self) -- Starting the UI
	Apollo.RegisterEventHandler("UpdateCCStateStun", "OnUpdateCCStateStun", self) -- Hitting the interact key
	Apollo.RegisterEventHandler("RemoveCCStateStun", "OnRemoveCCStateStun", self) -- Close the UI
	Apollo.RegisterEventHandler("StunVGPressed", "OnStunVGPressed", self)
	
	self.wndProgress = nil
end

-----------------------------------------------------------------------------------------------
-- Rapid Tap
-----------------------------------------------------------------------------------------------

function CrowdControlGameplay:OnActivateCCStateStun(eChosenDirection)
	if self.wndProgress and self.wndProgress:IsValid() then
		self.wndProgress:Destroy()
		self.wndProgress = nil
	end

	self.wndProgress = Apollo.LoadForm(self.xmlDoc, "ButtonHit_Progress", nil, self)
	self.wndProgress:Show(true) -- to get the animation
	self.wndProgress:FindChild("TimeRemainingContainer"):Show(false)

	local strNone		= Apollo.GetString("Keybinding_Unbound")
	local strLeft 		= GameLib.GetKeyBinding("StunBreakoutLeft")
	local strUp 		= GameLib.GetKeyBinding("StunBreakoutUp")
	local strRight 		= GameLib.GetKeyBinding("StunBreakoutRight")
	local strDown 		= GameLib.GetKeyBinding("StunBreakoutDown")
	local bLeftUnbound 	= strLeft == strNone
	local bUpUnbound 	= strUp == strNone
	local bRightUnbound = strRight == strNone
	local bDownUnbound 	= strDown == strNone
	local bLeft 		= eChosenDirection == Unit.CodeEnumCCStateStunVictimGameplay.Left
	local bUp 			= eChosenDirection == Unit.CodeEnumCCStateStunVictimGameplay.Forward
	local bRight 		= eChosenDirection == Unit.CodeEnumCCStateStunVictimGameplay.Right
	local bDown 		= eChosenDirection == Unit.CodeEnumCCStateStunVictimGameplay.Backward

	-- TODO: Swap to Stun Breakout Keys when they exist
	self.wndProgress:FindChild("ProgressButtonArtLeft"):SetText(bLeftUnbound and "" or strLeft)
	self.wndProgress:FindChild("ProgressButtonArtUp"):SetText(bUpUnbound and "" or strUp)
	self.wndProgress:FindChild("ProgressButtonArtRight"):SetText(bRightUnbound and "" or strRight)
	self.wndProgress:FindChild("ProgressButtonArtDown"):SetText(bDownUnbound and "" or strDown)

	-- Disabled is invisible text, which will hide the button text
	self.wndProgress:FindChild("ProgressButtonArtLeft"):Enable(bLeft)
	self.wndProgress:FindChild("ProgressButtonArtUp"):Enable(bUp)
	self.wndProgress:FindChild("ProgressButtonArtRight"):Enable(bRight)
	self.wndProgress:FindChild("ProgressButtonArtDown"):Enable(bDown)

	self.wndProgress:FindChild("NoBindsWarning"):Show(bLeftUnbound or bUpUnbound or bRightUnbound or bDownUnbound)
	
	if not bLeft and not bUp and not bRight and not bDown then -- Error Case
		self:OnRemoveCCStateStun()
		return
	end

	self:OnCalculateTimeRemaining()
end

function CrowdControlGameplay:OnRemoveCCStateStun() -- Also from lua
	if self.wndProgress and self.wndProgress:IsValid() then
		self.wndProgress:Destroy()
		self.wndProgress = nil
	end
end

function CrowdControlGameplay:OnUpdateCCStateStun(fProgress) -- Updates Progress Bar
	if not self.wndProgress or not self.wndProgress:IsValid() then
		return
	end

	if self.wndProgress:FindChild("ProgressBar") then
		self.wndProgress:FindChild("ProgressBar"):SetMax(100)
		self.wndProgress:FindChild("ProgressBar"):SetFloor(0)
		self.wndProgress:FindChild("ProgressBar"):SetProgress(fProgress * 100)
	end

	self:OnCalculateTimeRemaining()
end

function CrowdControlGameplay:OnCalculateTimeRemaining()
	local nTimeRemaining = GameLib.GetCCStateStunTimeRemaining()
	if not nTimeRemaining or nTimeRemaining <= 0 then
		if self.wndProgress and self.wndProgress:IsValid() then
			self.wndProgress:Show(false)
			--timers currently can't be started during their callbacks, because of a Code bug.
			self.timerCalculateRemaining = ApolloTimer.Create(0.1, false, "OnCalculateTimeRemaining", self)
		end
		return
	end

	if self.wndProgress and self.wndProgress:IsValid() and self.wndProgress:FindChild("TimeRemainingContainer") then
		self.wndProgress:Show(true)
		self.wndProgress:FindChild("TimeRemainingContainer"):Show(true)
		
		local nMaxTime = self.wndProgress:FindChild("TimeRemainingBar"):GetData()
		if not nMaxTime or nTimeRemaining > nMaxTime then
			nMaxTime = nTimeRemaining
			self.wndProgress:FindChild("TimeRemainingBar"):SetMax(100)
			self.wndProgress:FindChild("TimeRemainingBar"):SetData(nMaxTime)
			self.wndProgress:FindChild("TimeRemainingBar"):SetProgress(100)
		end
		self.wndProgress:FindChild("TimeRemainingBar"):SetProgress(math.min(math.max(nTimeRemaining / nMaxTime * 100, 0), 100), 50) -- 2nd Arg is the rate
	end

	if nTimeRemaining > 0 then
		--timers currently can't be started during their callbacks, because of a Code bug.
		self.timerCalculateRemaining = ApolloTimer.Create(0.1, false, "OnCalculateTimeRemaining", self)
	end
end

function CrowdControlGameplay:OnStunVGPressed(bPushed)
	if self.wndProgress and self.wndProgress:IsValid() then
		self.wndProgress:FindChild("ProgressButtonArtLeft"):SetCheck(bPushed)
		self.wndProgress:FindChild("ProgressButtonArtUp"):SetCheck(bPushed)
		self.wndProgress:FindChild("ProgressButtonArtDown"):SetCheck(bPushed)
		self.wndProgress:FindChild("ProgressButtonArtRight"):SetCheck(bPushed)
	end
end

local CrowdControlGameplayInst = CrowdControlGameplay:new()
CrowdControlGameplayInst:Init()
