require "Window"
require "Sound"
require "GameLib"

--Non Combat Casting Bars
local NCCB = {}

function NCCB:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function NCCB:Init()
	--Apollo.DPF("Initializing NCCB")
	Apollo.RegisterAddon(self)
end

function NCCB:OnLoad()
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnUpdate", self)
	Apollo.RegisterEventHandler("Interaction", "Interact",self)

	Apollo.LoadSprites("NonCombatCastBarSprites.xml")
	self.NCCB = Apollo.LoadForm("NonCombatCastBar.xml", "NonCombatCastBar", nil, self)
	self.NCCB:Show(false)
	
	self.Test = Apollo.LoadForm("NonCombatCastBar.xml", "NonCombatTestMenu", nil, self)
	self.Test:Show(false)

	self.Box1 = self.NCCB:FindChild("Box1")
	self.Box1:Show(false)
	
	self.l, self.t, self.r, self.b = self.Box1:GetRect()
	self.h = self.b - self.t
	self.w = self.r - self.l
		
	self.Box2 = self.NCCB:FindChild("Box2")
	self.Box2:Show(false)
	
	self.l2, self.t2, self.r2, self.b2 = self.Box2:GetRect()
	self.h2 = self.b2 - self.t2
	self.w2 = self.r2 - self.l2
	
	self.Box3 = self.NCCB:FindChild("Box3")
	self.Box3:Show(false)
	
	self.l3, self.t3, self.r3, self.b3 = self.Box3:GetRect()
	self.h3 = self.b3 - self.t3
	self.w3 = self.r3 - self.l3
	
	self.Box4 = self.NCCB:FindChild("Box4")
	self.Box4:Show(false)
	
	self.l4, self.t4, self.r4, self.b4 = self.Box4:GetRect()
	self.h4 = self.b4 - self.t4
	self.w4 = self.r4 - self.l4
	
	self.tEvent={}
	self.tEvent["Direction"] = "pos" --pos or neg
	self.tEvent["BarText"] = "Testing"
	self.tEvent["StartTime"] = 0
	self.tEvent["CurrentTime"] = 0
	self.tEvent["Progress"] = 0
	self.tEvent["Duration"] = 3
	self.tEvent["Glow"] = true
	self.tEvent["SweetSpot"] = 0
	self.tEvent["Width1"] = 0
	self.tEvent["Width2"] = 0
	self.tEvent["Layered"] = 0
	self.tEvent["TimeMin1"] = 0
	self.tEvent["TimeMax1"] = 0
	self.tEvent["TimeMin2"] = 0
	self.tEvent["TimeMax2"] = 0
	
	self.bSwapDirection = true
	
end

function NCCB:OnSave(eType)
	return nil
end

function NCCB:OnRestore(eType, t)
end

function NCCB:OnUpdate()
	if self.NCCB:IsVisible() == false then 
		return 
	end
	local iCount = GameLib.GetGameTime() - self.tEvent.CurrentTime

	self.tEvent.CurrentTime = GameLib.GetGameTime()
		
		--------------------------------------positive----------------------------------
	if self.tEvent.Direction == "pos" then
		
		self:AddativeProgressBar(iCount)
		
		if self.tEvent.Progress >= self.tEvent.Duration then
			self.NCCB:Show(false)
			self.Box1:Show(false)
			self.Box2:Show(false)
			Interaction_Result(self.win)
		end
		--------------------------------------negative----------------------------------
	elseif self.tEvent.Direction == "neg" then
		self:SubtractiveProgressBar(iCount)
		
		if self.tEvent.Progress <= tonumber(0) then
			self.win = 0
			self.NCCB:Show(false)
			self.Test:Show(false)
			self.Box1:Show(false)
			self.Box2:Show(false)
			Interaction_Result(self.win)
		end
		--------------------------------------Bounce---------------------------------
	elseif self.tEvent.Direction == "Bounce" then
	
		if self.bSwapDirection == true then
			self:SubtractiveProgressBar(iCount)
			if self.tEvent.Progress <= 0 then
				self.bSwapDirection = false
			end
		end
		
		if self.bSwapDirection == false then
			self:AddativeProgressBar(iCount)
			if self.tEvent.Progress >= self.tEvent.Duration then
				self.bSwapDirection = true
			end
		end	
		
		--Apollo.DPF("tEvent.Progress:    " .. self.tEvent.Progress)
	else
		--Apollo.DPF("Invalid Direction")
	end	
end
function NCCB:AddativeProgressBar(icount)
	self.tEvent.Progress = icount + self.tEvent.Progress
	self.NCCB:FindChild("CastingProgress"):SetProgress(self.tEvent.Progress)
	--Apollo.DPF("Add icount:   " .. icount)
end

function NCCB:SubtractiveProgressBar(icount)
	self.tEvent.Progress = self.tEvent.Progress - icount
	self.NCCB:FindChild("CastingProgress"):SetProgress(self.tEvent.Progress)
	--Apollo.DPF("Subtract icount:   " .. icount)
end

-- Activate ----------------------------------------------------------------------------------------------------
function NCCB:ActivateBar()
	self.NCCB:FindChild("CastingProgress"):SetMax(self.tEvent.Duration)
	self.NCCB:FindChild("CastingProgress"):EnableGlow(self.tEvent.Glow) 
	self.NCCB:FindChild("CastingProgress"):SetText(self.tEvent.BarText)
	self:OnUpdate()
end

-- channel ----------------------------------------------------------------------------------------------------
function NCCB:ActivateChannelButton()
	if self.NCCB:IsVisible() ~= true then
		self.tEvent.Direction = "pos"
		self.tEvent.BarText = "Channeling"
		self.tEvent.StartTime = GameLib.GetGameTime()
		self.tEvent.Progress = 0
		self.tEvent.CurrentTime = GameLib.GetGameTime()
		
		self.NCCB:FindChild("CastingProgress"):SetTickLocations(0,0) 
		self.NCCB:Show(true)
		
		self:ActivateBar()
	else
		self.NCCB:Show(false)
	end
end

-- Drain ----------------------------------------------------------------------------------------------------
function NCCB:ActivateDrainButton()
	if self.NCCB:IsVisible() ~= true then
		self.tEvent.Direction = "neg"
		self.tEvent.BarText = Apollo.GetString("CRB_Draining")
		self.tEvent.StartTime = GameLib.GetGameTime()
		self.tEvent.Progress = self.tEvent.Duration
		self.tEvent.CurrentTime = GameLib.GetGameTime()

		self.NCCB:FindChild("CastingProgress"):SetTickLocations(0,0) 
		self.NCCB:Show(true)
		
		self:ActivateBar()
	else
		self.NCCB:Show(false)
	end
end

-- hold ----------------------------------------------------------------------------------------------------

function NCCB:PressHoldButton()
--hyjack hold for hit the targets
	if self.NCCB:IsVisible() ~= true then
		self.tEvent.Direction = "Bounce"
		self.tEvent.BarText = Apollo.GetString("CRB_Not_Hold")
		self.tEvent.StartTime = GameLib.GetGameTime()
		self.tEvent.Progress = self.tEvent.Duration
		self.tEvent.CurrentTime = GameLib.GetGameTime()
		
		self.NCCB:FindChild("CastingProgress"):SetTickLocations(0,0) 
		self.NCCB:Show(true)
		self:ActivateBar()
	end
end
--[[
function NCCB:PressHoldButton()	
	if self.NCCB:IsVisible() ~= true then
		self.win=1
		self.tEvent.Direction = "pos"
		self.tEvent.BarText = Apollo.GetString("CRB_Hold")
		self.tEvent.StartTime = GameLib.GetGameTime()
		self.tEvent.Progress = 0
		self.tEvent.CurrentTime = GameLib.GetGameTime()
		
		self.NCCB:FindChild("CastingProgress"):SetTickLocations(0,0) 
		self.NCCB:Show(true)
		self:ActivateBar()
	else
		self.win=1
		self.tEvent.Direction = "pos"
		self.tEvent.BarText = Apollo.GetString("CRB_That_was_close__idiot")
		self.tEvent.CurrentTime = GameLib.GetGameTime()		
		self:ActivateBar()
	end
end

function NCCB:ReleaseHoldButton()
	if self.NCCB:IsVisible() == true then
		self.win=0
		self.tEvent.Direction = "neg"
		self.tEvent.BarText = Apollo.GetString("CRB_ZOMG_DONT_LET_GO")
		self.tEvent.CurrentTime = GameLib.GetGameTime()
		self:ActivateBar()
	end
end
--]]
--Rapid Tap ----------------------------------------------------------------------------------------------------
function NCCB:PressRapidButton()
--	Sound.Play(Sound.PlayUITapButtonRapid)
	if self.NCCB:IsVisible() ~= true then
		self.tEvent.Direction = "neg"
		self.tEvent.BarText = Apollo.GetString("CRB_Keep_Clicking")
		self.tEvent.StartTime = GameLib.GetGameTime()
		self.tEvent.Progress = 1
		self.tEvent.CurrentTime = GameLib.GetGameTime()
		self.win=0
		self.NCCB:FindChild("CastingProgress"):SetTickLocations(0,0) 
		self.NCCB:Show(true)
		
		self:ActivateBar()
	else
		self.tEvent.Progress = self.tEvent.Progress + .25
		self.win=1
		
		if self.tEvent.Progress >= self.tEvent.Duration then
			Interaction_Result(self.win)
			self.NCCB:Show(false)
			self.Test:Show(false)
		end
	end	
end

-- Tap ----------------------------------------------------------------------------------------------------------
function NCCB:ActivateTapBar()
	self.win = 0
	
	if self.NCCB:IsVisible() ~= true then
		self.tEvent.Direction = "pos"
		--self.tEvent.BarText = "text"
		self.tEvent.StartTime = GameLib.GetGameTime()
		self.tEvent.Progress = 0
		self.tEvent.CurrentTime = GameLib.GetGameTime()
	
		self.NCCB:Show(true)
		self.Box1:Show(true)
		if self.tEvent.Layered == false then
			self.Box2:Show(false)
		else
			self.Box2:Show(true)
		end
		
		local ProgressBar = {}
		ProgressBar.left, ProgressBar.top, ProgressBar.right, ProgressBar.bottom = self.NCCB:GetRect()
		ProgressBar.width =  ProgressBar.right - ProgressBar.left
		ProgressBar.height = ProgressBar.bottom - ProgressBar.top


-- Screen distance to progress bar, progress bar length.
		self:CalcBoxPosition(240)

		self:ActivateBar()
	else
		--Apollo.DPF("Mouse Check" .. " Position = " .. self.tEvent.Progress)

		if  self.tEvent.Progress > self.tEvent.TimeMin1 and self.tEvent.Progress < self.tEvent.TimeMax1 then
			--Apollo.DPF("I MADE IT")
			--Apollo.DPF("Progress:     " .. self.tEvent.Progress)
			self.NCCB:FindChild("CastingProgress"):SetBarColor(CColor.new(0.0, 1.0, 0.0, 1.0))
			
			if self.Test:IsVisible() == true then
				self.win = 2
				self.Test:Show(false)
			end
		elseif self.tEvent.Progress > self.tEvent.TimeMin2 and self.tEvent.Progress < self.tEvent.TimeMax2 then 
			self.NCCB:FindChild("CastingProgress"):SetBarColor(CColor.new(0.0, 1.0, 0.0, 1.0))
			
			if self.Test:IsVisible() == true then
				self.win = 1
				self.Test:Show(false)
			end
		else
			--Apollo.DPF("I FAILED T_T")
			self.NCCB:FindChild("CastingProgress"):SetBarColor(CColor.new(1.0, 0.0, 0.0, 1.0))
			
			--self.tEvent.BarText = "Failed"
			if self.Test:IsVisible() == true then
				self.win = 0
				self.Test:Show(false)
				self.Box1:Show(false)
				self.Box2:Show(false)
			end
		end
		
		self.NCCB:FindChild("CastingProgress"):SetText(self.tEvent.BarText)
	end
end

function NCCB:CalcBoxPosition(ProgressBarWidth)
--------------------------------------------------------------------------------------Box Position ------------------------------------------------------------------------------------------
		local HalfWidth1 = self.tEvent.Width1/2
		local HalfWidth2 = self.tEvent.Width2/2
		
		local TargetMin = ((self.tEvent.SweetSpot * .01) * ProgressBarWidth) - HalfWidth1
		local TargetMax = ((self.tEvent.SweetSpot * .01) * ProgressBarWidth) + HalfWidth1
		
		local TargetMin2 = ((self.tEvent.SweetSpot * .01) * ProgressBarWidth) - HalfWidth2
		local TargetMax2 = ((self.tEvent.SweetSpot * .01) * ProgressBarWidth) + HalfWidth2
		
		
		--move the Box1 to the correct location
		self.Box1:Move(TargetMin, self.t, self.tEvent.Width1, self.h)
		self.Box2:Move(TargetMin2, self.t2, self.tEvent.Width2, self.h2)
--------------------------------------------------------------------------------------Percentage of time ------------------------------------------------------------------------------------------
		local PercentMin = (self.tEvent.SweetSpot * .01) - (HalfWidth1 / ProgressBarWidth)
		local PercentMax = (self.tEvent.SweetSpot * .01) + (HalfWidth1 / ProgressBarWidth)
		
		self.tEvent.TimeMin1 = PercentMin * self.tEvent.Duration
		self.tEvent.TimeMax1 = PercentMax * self.tEvent.Duration
		
		--Apollo.DPF("ProgressBarWidth     " .. ProgressBarWidth)
		--Apollo.DPF("Width1          " .. self.tEvent.Width1)
		--Apollo.DPF("HalfWidth1      " .. HalfWidth1)
		--Apollo.DPF("PercentMin:     " .. PercentMin)
		--Apollo.DPF("PercentMax:     " .. PercentMax)
		
		--Apollo.DPF("TimeMin:     " .. self.tEvent.TimeMin1)
		--Apollo.DPF("TimeMax:     " .. self.tEvent.TimeMax1)
		
		local PercentMin2 = self.tEvent.SweetSpot - (HalfWidth2 / ProgressBarWidth)
		local PercentMax2 = self.tEvent.SweetSpot + (HalfWidth2 / ProgressBarWidth)
		
		self.tEvent.TimeMin2 = PercentMin2 * self.tEvent.Duration
		self.tEvent.TimeMax2 = PercentMax2 * self.tEvent.Duration

end
-- Layered Tap ----------------------------------------------------------------------------------------------------------
function NCCB:ActivateLayeredTapBar()
	self.tEvent.Layered = true
end

function NCCB:ConvertFromPercentage(iPercent)
	return iPercent * 2.4
end
-- Interact with NPC ----------------------------------------------------------------------------------------------------------
function NCCB:Interact(text, bartype, speed, sweetspot, width1, width2)
--	Apollo.DPF("Interact text:      " ..text)
--	Apollo.DPF("Interact bartype:   " ..bartype)
--	Apollo.DPF("Interact speed:     " ..speed)
--	Apollo.DPF("Interact sweetspot: " .. sweetspot)
--	Apollo.DPF("Interact width1:    " ..width1)
--	Apollo.DPF("Interact width2:    " ..width2)
	
	self.NCCB:FindChild("CastingProgress"):SetBarColor(CColor.new(0.0, 0.0, 2.0, 1.0))
	self.Test:FindChild("ChannelBtn"):Show(false)
	self.Test:FindChild("DrainBtn"):Show(false)
	self.Test:FindChild("TapBtn"):Show(false)
	self.Test:FindChild("LayeredTapBtn"):Show(false)
	self.Test:FindChild("HoldBtn"):Show(false)
	self.Test:FindChild("RapidBtn"):Show(false)	
	
	self.tEvent.Duration = speed / 1000
	
	if self.Test:IsVisible() == false then
		self.Test:Show(true)
	else
		self.Test:Show(false)
	end
	
	if bartype == 0 then
		self.Test:FindChild("HoldBtn"):Show(true)
		
		if sweetspot > 5 or sweetspot < 0 then
			--Apollo.DPF("Invalid input: Please enter a number from 1-5")
		else
			self.tEvent.SweetSpot = sweetspot
		end
		
	elseif bartype == 1 then
		self.Test:FindChild("TapBtn"):Show(true)		
		self.tEvent.BarText = text
		self.tEvent.SweetSpot = sweetspot
		self.tEvent.Width1 = self:ConvertFromPercentage(width1)
		self.tEvent.Layered = false
		
		self.Box1:Move(self.l, self.t, self.w, self.h)
		self.Box2:Move(self.l2, self.t2, self.w2, self.h2)
		
	elseif bartype == 2 then
		self.Test:FindChild("LayeredTapBtn"):Show(true)
		self.tEvent.BarText = text
		self.tEvent.SweetSpot = sweetspot
		self.tEvent.Width1 = self:ConvertFromPercentage(width1)
		self.tEvent.Width2 = self:ConvertFromPercentage(width2)
		
		self.Box1:Move(self.l, self.t, self.w, self.h)
		self.Box2:Move(self.l2, self.t2, self.w2, self.h2)
		
	elseif bartype == 3 then
		self.Test:FindChild("RapidBtn"):Show(true)
	end
end

local NCCBInstance = NCCB:new()
NCCBInstance:Init()