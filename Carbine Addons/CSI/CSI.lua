-----------------------------------------------------------------------------------------------
-- Client Lua Script for CSI
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "GameLib"
require "CSIsLib"

local kstrPrecisionArrowRight = "CRB_Basekit:kitIProgBar_HoloFrame_CapArrowR"
local kstrPrecisionArrowLeft = "CRB_Basekit:kitIProgBar_HoloFrame_CapArrowL"
local kcrPrecisionBarReady = ApolloColor.new("ffffffff")
local kcrPrecisionBarHit = ApolloColor.new("green")

local knSaveVersion = 6

local CSI = {}

function CSI:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function CSI:Init()
    Apollo.RegisterAddon(self)
end

function CSI:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local bIsYesNo = false
	local tActiveCSI = CSIsLib.GetActiveCSI()
	if tActiveCSI and tActiveCSI.eType == CSIsLib.ClientSideInteractionType_YesNo then
		bIsYesNo = true
	end
	
	local locMemory = self.wndMemory and self.wndMemory:GetLocation() or self.locMemoryLocation
	local locKeypad = self.wndKeypad and self.wndKeypad:GetLocation() or self.locKeypadLocation
	local locYesNo = (bIsYesNo and self.wndProgress) and self.wndProgress:GetLocation() or self.locYesNoLocation
	local tSave = 
	{
		tMemoryLocation = locMemory and locMemory:ToTable() or nil,
		tKeypadLocation = locKeypad and locKeypad:ToTable() or nil,
		tYesNoLocation = locYesNo and locYesNo:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	return tSave
end

function CSI:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		
		if tSavedData.tMemoryLocation then
			self.locMemoryLocation = WindowLocation.new(tSavedData.tMemoryLocation)
		end
		
		if tSavedData.tKeypadLocation then
			self.locKeypadLocation = WindowLocation.new(tSavedData.tKeypadLocation)
		end
		
		if tSavedData.tYesNoLocation then
			self.locYesNoLocation = WindowLocation.new(tSavedData.tYesNoLocation)
		end
	end
end

function CSI:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CSI.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function CSI:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("CSIKeyPressed", "OnCSIKeyPressed", self) -- Hitting the 'F' key
	Apollo.RegisterEventHandler("SetProgressClickTimes", "OnSetProgressClickTimes", self) -- Resizing the target rectangle
	Apollo.RegisterEventHandler("ProgressClickHighlightTime", "OnProgressClickHighlightTime", self) -- Flagging rectangle green
	Apollo.RegisterEventHandler("ProgressClickWindowDisplay", "OnProgressClickWindowDisplay", self)	-- Starting a CSI
	Apollo.RegisterEventHandler("ProgressClickWindowCompletionLevel", "OnProgressClickWindowCompletionLevel", self) -- Updates Progress Bar
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", "OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterTimerHandler("CalculateTimeRemaining", "OnCalculateTimeRemaining", self)

	self.nLocation1Left = 0
	self.nLocation1Right = 0
	self.nLocation2Left = 0
    self.nLocation2Right = 0
	self.nMetronomeMisses = 0
	self.bMetronomeLastDirection1 = true
	self.bMetronomeLastDirection2 = true
	self.bMetronomeLastDirectionAll = false

	self.wndProgress = nil
	
	self.wndKeypad = Apollo.LoadForm(self.xmlDoc, "CSI_Keypad", nil, self) -- TODO: Refactor so we don't load these until needed
	if self.locKeypadLocation then
		self.wndKeypad:MoveToLocation(self.locKeypadLocation)
	end
	self.wndKeypad:Show(false, true)
	
	self.wndMemory = Apollo.LoadForm(self.xmlDoc, "CSI_Memory", nil, self)
	if self.locMemoryLocation then
		self.wndMemory:MoveToLocation(self.locMemoryLocation)
	end		
	self.wndMemory:Show(false, true)

	self.tMemoryOptions =
	{
		self.wndMemory:FindChild("OptionBtn1"),
		self.wndMemory:FindChild("OptionBtn2"),
		self.wndMemory:FindChild("OptionBtn3"),
		self.wndMemory:FindChild("OptionBtn4")
	}

	self.tMemoryOptions[1]:SetData({ strTextColor = "ffec9200", id = 1, sound = Sound.PlayUIMemoryButton1}) -- ffb62e
	self.tMemoryOptions[2]:SetData({ strTextColor = "ff37ff00", id = 2, sound = Sound.PlayUIMemoryButton2})
	self.tMemoryOptions[3]:SetData({ strTextColor = "ff31fcf6", id = 3, sound = Sound.PlayUIMemoryButton3})
	self.tMemoryOptions[4]:SetData({ strTextColor = "ffd000ff", id = 4, sound = Sound.PlayUIMemoryButton4})

	Apollo.RegisterTimerHandler("MemoryDisplayTimer", "OnMemoryDisplayTimer", self)
	Apollo.RegisterEventHandler("AcceptProgressInput", "OnAcceptProgressInput", self)
	Apollo.RegisterEventHandler("HighlightProgressOption", "OnHighlightProgressOption", self)

	for idx = 0, 9 do
		self.wndKeypad:FindChild("KeypadButtonContainer:Button"..idx):SetData(idx) -- Requires exactly named windows
	end

	-- TODO: Persistance through reloadui via GetActiveCSI? (Memory and Keypad possibly had this)
end

function CSI:OnProgressClickWindowDisplay(bShow)
	local tActiveCSI = CSIsLib.GetActiveCSI()
	if not tActiveCSI then
		return
	end
	
	if self.wndProgress then
		self.wndProgress:Destroy()
	end
	
	local eType = tActiveCSI.eType

	if eType == CSIsLib.ClientSideInteractionType_YesNo then
		self:BuildYesNo(tActiveCSI, bShow)
	elseif eType == CSIsLib.ClientSideInteractionType_Memory then
		self:BuildMemory(tActiveCSI, bShow)
	elseif eType == CSIsLib.ClientSideInteractionType_Keypad then
		self:BuildKeypad(tActiveCSI, bShow)
	elseif eType == CSIsLib.ClientSideInteractionType_PressAndHold then
		self:BuildPressAndHold(tActiveCSI, bShow, Apollo.GetString("ProgressClick_ClickAndHoldUnit"))
	elseif eType == CSIsLib.ClientSideInteractionType_RapidTapping or eType == CSIsLib.ClientSideInteractionType_RapidTappingInverse then
		self:BuildRapidTap(tActiveCSI, bShow, Apollo.GetString("ProgressClick_RapidClickUnit"))
	elseif eType == CSIsLib.ClientSideInteractionType_PrecisionTapping or eType == CSIsLib.ClientSideInteractionType_Metronome then
		self:BuildPrecisionTap(tActiveCSI, bShow, Apollo.GetString("ProgressClick_PrecisionClickUnit"))
	end

	self:OnCalculateTimeRemaining()
end

-----------------------------------------------------------------------------------------------
-- Yes No
-----------------------------------------------------------------------------------------------

function CSI:BuildYesNo(tActiveCSI, bShow)
	if not bShow then 
		return 
	end

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "CSI_YesNo", nil, self)

	wndCurr:FindChild("NoButton"):SetData(wndCurr)
	wndCurr:FindChild("YesButton"):SetData(wndCurr)
	wndCurr:FindChild("CloseButton"):SetData(wndCurr)
	if tActiveCSI.strContext then
		wndCurr:FindChild("BodyText"):SetText(tActiveCSI.strContext)
	end

	if self.locYesNoLocation then
		wndCurr:MoveToLocation(self.locYesNoLocation)
	end
	self.wndProgress = wndCurr
end

function CSI:OnYesNo_WindowClosed(wndHandler) -- wndHandler is "CSI_YesNo"
	self.locYesNoLocation = wndHandler:GetLocation()
	wndHandler:Destroy()
end

function CSI:OnYesNo_NoPicked(wndHandler, wndControl) -- wndHandler are the "NoButton/CloseButton", and the data is the window "CSI_YesNo"
	if not wndHandler or not wndHandler:GetData() then 
		return 
	end 
	self.locYesNoLocation = wndHandler:GetData():GetLocation()
	wndHandler:GetData():Destroy()

	local tCSI = CSIsLib.GetActiveCSI()
	if tCSI and CSIsLib.IsCSIRunning() then
        CSIsLib.CSIProcessInteraction(false)
    end
end

function CSI:OnYesNo_YesPicked(wndHandler, wndControl) -- wndHandler is "YesButton", and the data is the window "CSI_YesNo"
	if not wndHandler or not wndHandler:GetData() then 
		return 
	end 
	self.locYesNoLocation = wndHandler:GetData():GetLocation()
	wndHandler:GetData():Destroy()

	local tCSI = CSIsLib.GetActiveCSI()
	if tCSI and CSIsLib.IsCSIRunning() then
        CSIsLib.CSIProcessInteraction(true)
    end
end

-----------------------------------------------------------------------------------------------
-- Press and Hold and Rapid Tap and Precision Tap and Memory and Keypad
-----------------------------------------------------------------------------------------------

function CSI:BuildPressAndHold(tActiveCSI, bShow, strBodyText)
	if not bShow then
		if self.wndProgress and self.wndProgress:IsValid() then
			self.wndProgress:Destroy()
		end
		return
	end

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "CSI_Progress", nil, self)
	wndCurr:Show(true) -- to get the animation
	wndCurr:FindChild("BodyText"):SetText(strBodyText)
	wndCurr:FindChild("ProgressButton"):SetText(GameLib.GetKeyBinding("Interact"))
	wndCurr:FindChild("HoldButtonDecoration"):Show(true)
	self.wndProgress = wndCurr
end

function CSI:BuildRapidTap(tActiveCSI, bShow)
	if not bShow then
		if self.wndProgress and self.wndProgress:IsValid() then
			self.wndProgress:Destroy()
		end
		return
	end

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "CSI_Progress", nil, self)
	wndCurr:Show(true) -- to get the animation
	wndCurr:FindChild("ProgressButton"):SetText(GameLib.GetKeyBinding("Interact"))
	self.wndProgress = wndCurr
end

function CSI:BuildPrecisionTap(tActiveCSI, bShow, strBodyText)
	if not bShow then
		if self.wndProgress and self.wndProgress:IsValid() then
			self.wndProgress:Destroy()
		end
		return
	end

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "CSI_Precision", nil, self)
	wndCurr:SetData(tActiveCSI)
	wndCurr:FindChild("BodyText"):SetText(strBodyText)

	local strInteractKey = GameLib.GetKeyBinding("Interact")
	wndCurr:FindChild("ProgressButton:StartProgressButtonText"):SetText(strInteractKey)
	wndCurr:FindChild("ClickTimeFrame:PreviewProgressButtonWindow"):Show(true)
	wndCurr:FindChild("ClickTimeFrame:PreviewProgressButtonWindow:PreviewProgressButtonText"):SetText(strInteractKey)
	wndCurr:FindChild("ClickTimeFrame:ClickProgressButton:ProgressButtonText"):SetText(strInteractKey)
	wndCurr:FindChild("ClickTimeFrame:ClickProgressButton:ProgressButtonGlow"):SetText(strInteractKey)
	wndCurr:FindChild("ClickTimeFrame2:PreviewProgressButtonWindow"):Show(true)
	wndCurr:FindChild("ClickTimeFrame2:PreviewProgressButtonWindow:PreviewProgressButtonText"):SetText(strInteractKey)
	wndCurr:FindChild("ClickTimeFrame2:ClickProgressButton:ProgressButtonText"):SetText(strInteractKey)
	wndCurr:FindChild("ClickTimeFrame2:ClickProgressButton:ProgressButtonGlow"):SetText(strInteractKey)
	wndCurr:FindChild("ProgressBar"):SetGlowSprite(kstrPrecisionArrowRight)

	wndCurr:FindChild("MetronomeProgress"):Show(tActiveCSI.eType == CSIsLib.ClientSideInteractionType_Metronome)
	self.wndProgress = wndCurr
	self.nMetronomeMisses = 0
	self.nMetronomeHits = 0
	self.bMetronomeLastDirection1 = true
	self.bMetronomeLastDirection2 = true
	self.bMetronomeLastDirectionAll = false
end

function CSI:BuildKeypad(tActiveCSI, bShow)
	if not tActiveCSI then
		self.wndKeypad:Show(false)
	    return
	end

	self.nKeypadCount = 0
	self.strKeypadDisplay = ""
	self.wndKeypad:FindChild("KeypadButtonContainer:Enter"):Enable(false)
	self.wndKeypad:FindChild("KeypadTopBG:KeypadText"):Show(true)
	self.wndKeypad:FindChild("KeypadTopBG:TextDisplay"):SetText("")

	if tActiveCSI.strContext and string.len(tActiveCSI.strContext) > 0 then
		self.wndKeypad:FindChild("KeypadTopBG:KeypadText"):SetText(tActiveCSI.strContext)
	else
		self.wndKeypad:FindChild("KeypadTopBG:KeypadText"):SetText(Apollo.GetString("CRB_Enter_the_code"))
	end

	self.wndKeypad:Show(bShow)
	self.wndKeypad:FindChild("TimeRemainingContainer"):Show(false)
end

function CSI:BuildMemory(tActiveCSI, bShow)
	-- TODO: Create a new one here (and later destroy)
	self.wndMemory:Show(bShow and tActiveCSI)
	self.wndMemory:FindChild("OptionBtn1"):Enable(false)
	self.wndMemory:FindChild("OptionBtn2"):Enable(false)
	self.wndMemory:FindChild("OptionBtn3"):Enable(false)
	self.wndMemory:FindChild("OptionBtn4"):Enable(false)
	self.wndMemory:FindChild("StartBtnBG"):Show(bShow and tActiveCSI)
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleText"):SetAML("")
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleReadyText"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Shared
-----------------------------------------------------------------------------------------------

function CSI:OnProgressClickWindowCompletionLevel(nPercentage, bIsReversed) -- Updates Progress Bar
	if not self.wndProgress or not self.wndProgress:IsValid() then
		return
	end

	if nPercentage > 100 then
		nPercentage = 100
	elseif nPercentage < 0 then
		nPercentage = 0
	end

	-- Draw ClickTimeFrames
	if nPercentage > 0 and self.wndProgress:FindChild("ClickTimeFrame") then
		self.wndProgress:FindChild("BodyText"):SetText("")
		self.wndProgress:FindChild("ProgressButton"):Show(false)
		local wndClickTimeFrame = self.wndProgress:FindChild("ClickTimeFrame")
		local wndClickTimeFrame2 = self.wndProgress:FindChild("ClickTimeFrame2")
		local wndProgressButton = wndClickTimeFrame:FindChild("ClickProgressButton")
		local wndProgressButton2 = wndClickTimeFrame2:FindChild("ClickProgressButton")
		
		wndProgressButton:Show(true)
		wndProgressButton2:Show(nPercentage > self.nLocation1Right)

		-- Special glowing (only once) when they enter it
		local wndButtonGlow = wndProgressButton:FindChild("ProgressButtonGlow")
		if nPercentage > self.nLocation1Left and nPercentage < self.nLocation1Right and not wndProgressButton:FindChild("ProgressButtonFail"):IsShown() then
			if not wndButtonGlow:GetData() then
				wndButtonGlow:Show(true)
				wndButtonGlow:SetData(true)
				wndButtonGlow:SetSprite("sprWinAnim_BirthSmallTempLoop")
			end
		else
			wndButtonGlow:Show(false)
		end

		local wndButtonGlow2 = wndProgressButton2:FindChild("ProgressButtonGlow")
		if nPercentage > self.nLocation2Left and nPercentage < self.nLocation2Right and not wndProgressButton2:FindChild("ProgressButtonFail"):IsShown() then
			if not wndButtonGlow2:GetData() then
				wndButtonGlow2:Show(true)
				wndButtonGlow2:SetData(true)
				wndButtonGlow2:SetSprite("sprWinAnim_BirthSmallTempLoop")
			end
		else
			wndButtonGlow2:Show(false)
		end

		-- Fail if they missed it
		local tCSI = CSIsLib.GetActiveCSI()
		local bFailed1 = nPercentage > self.nLocation1Right and not wndProgressButton:FindChild("ProgressButtonCheck"):IsShown()
		local bFailed2 = nPercentage > self.nLocation2Right and not wndProgressButton2:FindChild("ProgressButtonCheck"):IsShown()

		if tCSI.eType == CSIsLib.ClientSideInteractionType_Metronome then -- Special case for reversing Metronome (compare < instead of >)
			if bIsReversed then
				bFailed1 = nPercentage < self.nLocation1Left and nPercentage < self.nLocation1Right and not wndProgressButton:FindChild("ProgressButtonCheck"):IsShown()
				bFailed2 = nPercentage < self.nLocation2Left and nPercentage < self.nLocation2Right and not wndProgressButton2:FindChild("ProgressButtonCheck"):IsShown()
			end
			self.wndProgress:FindChild("ProgressBarFrame:ProgressBar"):SetData(nPercentage)
			wndProgressButton:Show(self.nLocation2Left ~= 0)

			-- Miss tracking
			if bFailed1 and self.tMetronomeLastDirection1 ~= bIsReversed then
				self.tMetronomeLastDirection1 = bIsReversed
				if not wndProgressButton:FindChild("ProgressButtonFail"):IsShown() then
					self.nMetronomeMisses = self.nMetronomeMisses + 1
				end
			end
			if bFailed2 and self.tMetronomeLastDirection2 ~= bIsReversed then
				self.tMetronomeLastDirection2 = bIsReversed
				if not wndProgressButton2:FindChild("ProgressButtonFail"):IsShown() then
					self.nMetronomeMisses = self.nMetronomeMisses + 1
				end
			end
			
			local wndMissThresholdText = self.wndProgress:FindChild("MetronomeMissThresholdText")
			if wndMissThresholdText and tCSI.nThreshold > 1 and self.nMetronomeMisses > 0 then
				wndMissThresholdText:SetText(String_GetWeaselString(Apollo.GetString("CSI_MissedCount"), self.nMetronomeMisses, (tCSI.nThreshold + 1)))
			elseif wndMissThresholdText then
				wndMissThresholdText:SetText("")
			end
			if self.tMetronomeLastDirectionAll ~= bIsReversed then
				self.tMetronomeLastDirectionAll = bIsReversed
				self.tMetronomeLastDirection1 = not bIsReversed
				self.tMetronomeLastDirection2 = not bIsReversed
			end
		end

		if bFailed1 then
			wndProgressButton:FindChild("ProgressButtonFail"):Show(true)
			wndProgressButton:FindChild("ProgressButtonText"):Show(false)
		end

		if bFailed2 then
			wndProgressButton2:FindChild("ProgressButtonFail"):Show(true)
			wndProgressButton2:FindChild("ProgressButtonText"):Show(false)
		end
	end

	-- Draw Progress Bar
	--local wndProgressBar = 
	local wndProgressBar = self.wndProgress:FindChild("ProgressBarFrame:ProgressBar") or self.wndProgress:FindChild("ProgressBar")
	if wndProgressBar then
		wndProgressBar:SetMax(100)
		wndProgressBar:SetFloor(0)

		local tCSI = CSIsLib.GetActiveCSI()
		if tCSI and tCSI.eType == CSIsLib.ClientSideInteractionType_RapidTappingInverse then
			wndProgressBar:SetProgress(100 - nPercentage)
		else
			wndProgressBar:SetProgress(nPercentage)
		end

		-- Reset ClickTimeFrames for Metronome at the 0 and 100 point
		if tCSI and tCSI.eType == CSIsLib.ClientSideInteractionType_Metronome and (nPercentage < 1 or nPercentage > 95) then
			local wndProgressButton = self.wndProgress:FindChild("ClickTimeFrame"):FindChild("ClickProgressButton")
			local wndProgressButton2 = self.wndProgress:FindChild("ClickTimeFrame2"):FindChild("ClickProgressButton")
			
			wndProgressButton:FindChild("ProgressButtonText"):Show(true)
			wndProgressButton:FindChild("ProgressButtonFail"):Show(false)
			wndProgressButton:FindChild("ProgressButtonCheck"):Show(false)
			wndProgressButton2:FindChild("ProgressButtonText"):Show(true)
			wndProgressButton2:FindChild("ProgressButtonFail"):Show(false)
			wndProgressButton2:FindChild("ProgressButtonCheck"):Show(false)

			if nPercentage < 1 then
				wndProgressBar:SetGlowSprite(kstrPrecisionArrowRight)
			else
				wndProgressBar:SetGlowSprite(kstrPrecisionArrowLeft)
			end
		end
		-- Needs to be at very end (after reverse check in Metronome)
		wndProgressBar:SetData(nPercentage)
	end
end

function CSI:OnSetProgressClickTimes(nWidth, nLocation1, nLocation2, nSwingCount)
	if not self.wndProgress or not self.wndProgress:IsValid() then
		return
	end
	
	local wndProgressBar = self.wndProgress:FindChild("ProgressBarFrame:ProgressBar") or self.wndProgress:FindChild("ProgressBar")
	if not wndProgressBar then
		return
	end

	local nWidthOverTwo = nWidth / 2
	local nLeft, nTop, nRight, nBottom = wndProgressBar:GetRect()
	local nProgressWidth = nRight - nLeft
	local nTicks = nProgressWidth / 100

	self.nLocation1Left = nLocation1 - nWidthOverTwo
	self.nLocation1Right = nLocation1 + nWidthOverTwo
	self.nLocation2Left = nLocation2 - nWidthOverTwo
	self.nLocation2Right = nLocation2 + nWidthOverTwo

	nWidth = nWidth + nTicks
	nLocation1 = nLocation1 * nTicks
	nLocation2 = nLocation2 * nTicks
	nWidthOverTwo = nWidthOverTwo * nTicks

	local nLocationsPerSwing = 0

	if nLocation1 ~= 0 then
		local nLeftEdge = nLocation1 - nWidthOverTwo + nLeft
		local nRightEdge = nLocation1 + nWidthOverTwo + nLeft
		local nClickLeft, nClickTop, nClickRight, nClickBottom = self.wndProgress:FindChild("ClickTimeFrame"):GetRect()
		self.wndProgress:FindChild("ClickTimeFrame"):Move(nLeftEdge, nClickTop, nRightEdge - nLeftEdge, nClickBottom - nClickTop)
		self.wndProgress:FindChild("ClickTimeFrame"):Show(true)
		nLocationsPerSwing = nLocationsPerSwing + 1
	end

	if nLocation2 ~= 0 then
		local nLeftEdge = nLocation2 - nWidthOverTwo + nLeft
		local nRightEdge = nLocation2 + nWidthOverTwo + nLeft
		local nClickLeft, nClickTop, nClickRight, nClickBottom = self.wndProgress:FindChild("ClickTimeFrame2"):GetRect()
		self.wndProgress:FindChild("ClickTimeFrame2"):Move(nLeftEdge, nClickTop, nRightEdge - nLeftEdge, nClickBottom - nClickTop)
		self.wndProgress:FindChild("ClickTimeFrame2"):Show(true)
		nLocationsPerSwing = nLocationsPerSwing + 1
	end

	self.nProgressSwingCount = nSwingCount * nLocationsPerSwing

	local tActiveCSI = CSIsLib.GetActiveCSI()
	if tActiveCSI and tActiveCSI.eType == CSIsLib.ClientSideInteractionType_Metronome then
		self.wndProgress:FindChild("MetronomeProgress"):SetText(String_GetWeaselString(Apollo.GetString("CSI_MetronomeCountStart"), self.nProgressSwingCount))
	end

end

function CSI:OnProgressClickHighlightTime(idx, nPercentageHighlight)
	if not self.wndProgress or not self.wndProgress:IsValid() or not self.wndProgress:FindChild("ClickTimeFrame") then
		return
	end
	
	local wndClickTimeFrame = self.wndProgress:FindChild("ClickTimeFrame")
	local wndClickTimeFrame2 = self.wndProgress:FindChild("ClickTimeFrame2")
	local wndProgressButton = wndClickTimeFrame:FindChild("ClickProgressButton")
	local wndProgressButton2 = wndClickTimeFrame2:FindChild("ClickProgressButton")

	local fRed = 1.0
	local fBlue = 1.0
	local fGreen = 1.0
	local crBarColor = kcrPrecisionBarReady

	if nPercentageHighlight > 0 and idx == 0 and not wndProgressButton:FindChild("ProgressButtonFail"):IsShown() then
		fRed = 1 - nPercentageHighlight / 100
		fBlue = 1 - nPercentageHighlight / 100
		wndProgressButton:FindChild("ProgressButtonCheck"):Show(true)
		wndProgressButton:FindChild("ProgressButtonGlow"):Show(false)
		wndProgressButton:FindChild("ProgressButtonText"):Show(false)
		crBarColor = kcrPrecisionBarHit
	elseif nPercentageHighlight > 0 and idx == 1 and not wndProgressButton2:FindChild("ProgressButtonFail"):IsShown() then
		fRed = 1 - nPercentageHighlight / 100
		fBlue = 1 - nPercentageHighlight / 100
		wndProgressButton2:FindChild("ProgressButtonCheck"):Show(true)
		wndProgressButton2:FindChild("ProgressButtonGlow"):Show(false)
		wndProgressButton2:FindChild("ProgressButtonText"):Show(false)
		crBarColor = kcrPrecisionBarHit
	end

	if idx == 0 then
		wndClickTimeFrame:SetBGColor(CColor.new (fRed, fGreen, fBlue, 1.0))
		local pixieClickBar = wndClickTimeFrame:GetPixieInfo(1)
		pixieClickBar.cr = crBarColor
		wndClickTimeFrame:UpdatePixie(1, pixieClickBar)
	elseif idx == 1 then
		wndClickTimeFrame2:SetBGColor(CColor.new (fRed, fGreen, fBlue, 1.0))
		local pixieClickBar = wndClickTimeFrame2:GetPixieInfo(1)
		pixieClickBar.cr = crBarColor
		wndClickTimeFrame2:UpdatePixie(1, pixieClickBar)
	end
end

function CSI:HelperComputeProgressFailOrWin()
	-- This is relying on the UI and Server to be in sync, and can result in false passes if there is lag
	if not self.wndProgress or not self.wndProgress:IsValid() or not self.wndProgress:FindChild("ClickTimeFrame") or self.wndProgress:FindChild("ProgressButton"):IsShown() then
		return
	end
	
	local wndClickTimeFrame = self.wndProgress:FindChild("ClickTimeFrame")
	local wndClickTimeFrame2 = self.wndProgress:FindChild("ClickTimeFrame2")
	local wndProgressButton = wndClickTimeFrame:FindChild("ClickProgressButton")
	local wndProgressButton2 = wndClickTimeFrame2:FindChild("ClickProgressButton")

	local nPercentage = self.wndProgress:FindChild("ProgressBar"):GetData()
	-- If an extra click happens on the left
	if nPercentage < self.nLocation1Left then
		wndProgressButton:FindChild("ProgressButtonFail"):Show(true)
		wndProgressButton:FindChild("ProgressButtonText"):Show(false)
		wndProgressButton:FindChild("ProgressButtonCheck"):Show(false)
		self.nMetronomeMisses = self.nMetronomeMisses + 1
	elseif nPercentage < self.nLocation1Right and wndProgressButton:FindChild("ProgressButtonFail"):IsShown() then
		self.nMetronomeMisses = self.nMetronomeMisses + 1
	end

	if nPercentage < self.nLocation2Left and nPercentage > self.nLocation1Right then
		wndProgressButton2:FindChild("ProgressButtonFail"):Show(true)
		wndProgressButton2:FindChild("ProgressButtonText"):Show(false)
		wndProgressButton2:FindChild("ProgressButtonCheck"):Show(false)
		self.nMetronomeMisses = self.nMetronomeMisses + 1
	elseif nPercentage < self.nLocation2Right and wndProgressButton2:FindChild("ProgressButtonFail"):IsShown() then
		self.nMetronomeMisses = self.nMetronomeMisses + 1
	end

	-- If an extra click happens on the right
	if nPercentage > self.nLocation1Right and not wndClickTimeFrame2:IsShown() then
		if not wndProgressButton:FindChild("ProgressButtonFail"):IsShown() then
			self.nMetronomeMisses = self.nMetronomeMisses + 1
		end
		wndProgressButton:FindChild("ProgressButtonFail"):Show(true)
		wndProgressButton:FindChild("ProgressButtonText"):Show(false)
		wndProgressButton:FindChild("ProgressButtonCheck"):Show(false)
	end

	if nPercentage > self.nLocation2Right and wndClickTimeFrame2:IsShown() then
		if not wndProgressButton2:FindChild("ProgressButtonFail"):IsShown() then
			self.nMetronomeMisses = self.nMetronomeMisses + 1
		end
		wndProgressButton2:FindChild("ProgressButtonFail"):Show(true)
		wndProgressButton2:FindChild("ProgressButtonText"):Show(false)
		wndProgressButton2:FindChild("ProgressButtonCheck"):Show(false)
	end

	if nPercentage >= self.nLocation1Left and nPercentage <= self.nLocation1Right then
		self.nMetronomeHits = self.nMetronomeHits + 1
		self.wndProgress:FindChild("MetronomeProgress"):SetText(String_GetWeaselString(Apollo.GetString("CSI_MetronomeCount"), self.nMetronomeHits, self.nProgressSwingCount))
	end

	if nPercentage >= self.nLocation2Left and nPercentage <= self.nLocation2Right then
		self.nMetronomeHits = self.nMetronomeHits + 1
		self.wndProgress:FindChild("MetronomeProgress"):SetText(String_GetWeaselString(Apollo.GetString("CSI_MetronomeCount"), self.nMetronomeHits, self.nProgressSwingCount))
	end
end

-----------------------------------------------------------------------------------------------
-- UI and CSI Lib Events
-----------------------------------------------------------------------------------------------

function CSI:OnCancel(wndHandler, wndControl)
	if wndHandler == wndControl then
		if CSIsLib.GetActiveCSI() then
		    CSIsLib.CancelActiveCSI()
		end

		self.wndMemory:Show(false)
		self.wndKeypad:Show(false)
	end
end

function CSI:OnCSIKeyPressed(bKeyDown)
	if bKeyDown then
		self:OnButtonDown()
	else
		self:OnButtonUp()
	end

	if self.wndProgress and self.wndProgress:IsValid() then
		self.wndProgress:FindChild("ProgressButton"):SetCheck(bKeyDown)
    end

	Event_FireGenericEvent("GenericEvent_HideInteractPrompt")
end

function CSI:OnButtonDown()
	local tCSI = CSIsLib.GetActiveCSI()
	if not tCSI then
		return
	end

	if not CSIsLib.IsCSIRunning() and tCSI.eType ~= CSIsLib.ClientSideInteractionType_Metronome and tCSI.eType ~= CSIsLib.ClientSideInteractionType_PrecisionTapping then
		CSIsLib.StartActiveCSI()
		self:OnCalculateTimeRemaining()
	end

	if CSIsLib.IsCSIRunning() or tCSI.eType == CSIsLib.ClientSideInteractionType_PressAndHold or tCSI.eType == CSIsLib.ClientSideInteractionType_RapidTapping then
		CSIsLib.CSIProcessInteraction(true)
	end

	if not CSIsLib.IsCSIRunning() and (tCSI.eType == CSIsLib.ClientSideInteractionType_Metronome or tCSI.eType == CSIsLib.ClientSideInteractionType_PrecisionTapping) then
		CSIsLib.StartActiveCSI()
		self.wndProgress:FindChild("MetronomeProgress"):SetText(String_GetWeaselString(Apollo.GetString("CSI_MetronomeCount"), self.nMetronomeHits, self.nProgressSwingCount))
		self.wndProgress:FindChild("ClickTimeFrame"):FindChild("PreviewProgressButtonWindow"):Show(false)
		self.wndProgress:FindChild("ClickTimeFrame2"):FindChild("PreviewProgressButtonWindow"):Show(false)
		self:OnCalculateTimeRemaining()
    end

	self:HelperComputeProgressFailOrWin()
end

function CSI:OnButtonUp()
	local tCSI = CSIsLib.GetActiveCSI()
	if not tCSI then
		return
	end

	if tCSI.eType == CSIsLib.ClientSideInteractionType_PressAndHold then
        CSIsLib.CSIProcessInteraction(false)
    end
end

function CSI:OnCalculateTimeRemaining()
	local tCSI = CSIsLib.GetActiveCSI()
	local fTimeRemaining = CSIsLib.GetTimeRemainingForActiveCSI()

	if not fTimeRemaining or fTimeRemaining == 0 or not CSIsLib.IsCSIRunning() then
		return
	end

	local wndToUpdate = nil -- TODO: Refactor
	if self.wndProgress and self.wndProgress:IsShown() and self.wndProgress:FindChild("TimeRemainingContainer") then
		wndToUpdate = self.wndProgress
	elseif self.wndKeypad and self.wndKeypad:IsShown() and self.wndKeypad:FindChild("TimeRemainingContainer") then
		wndToUpdate = self.wndKeypad
	end

	if wndToUpdate then
		wndToUpdate:FindChild("TimeRemainingContainer"):Show(true)

		local wndTimeRemainingBar = wndToUpdate:FindChild("TimeRemainingContainer:TimeRemainingBarBG:TimeRemainingBar")
		local nData = wndTimeRemainingBar:GetData()
		if not nData or fTimeRemaining > nData then
			wndTimeRemainingBar:SetMax(fTimeRemaining)
			wndTimeRemainingBar:SetData(fTimeRemaining)
		end
		wndTimeRemainingBar:SetProgress(fTimeRemaining)
	end

	if fTimeRemaining > 0 then
		Apollo.CreateTimer("CalculateTimeRemaining", 0.05, false)
	end
end

-----------------------------------------------------------------------------------------------
-- Keypad
-----------------------------------------------------------------------------------------------

function CSI:OnKeypadSignal(wndDisplayed, wndControl)
	local tCSI = CSIsLib.GetActiveCSI()
	if tCSI == nil or tCSI.eType ~= CSIsLib.ClientSideInteractionType_Keypad then
		return
    end

	if not CSIsLib.IsCSIRunning() then
		CSIsLib.StartActiveCSI()
	end

	if self.nKeypadCount > 10 then
		return
	end

	self.nKeypadCount = self.nKeypadCount + 1
	self.strKeypadDisplay = self.strKeypadDisplay .. tostring(wndDisplayed:GetData())
	self.wndKeypad:FindChild("KeypadButtonContainer:Enter"):Enable(true)
	self.wndKeypad:FindChild("KeypadTopBG:KeypadText"):Show(false)
	self.wndKeypad:FindChild("KeypadTopBG:TextDisplay"):SetText(self.strKeypadDisplay)

	self:OnCalculateTimeRemaining()
end

function CSI:OnKeypadEnter(wndHandler, wndControl)
	local tCSI = CSIsLib.GetActiveCSI()
	if tCSI == nil or tCSI.eType ~= CSIsLib.ClientSideInteractionType_Keypad or not CSIsLib.IsCSIRunning() then
		return
    end

	if string.len(self.strKeypadDisplay) == 0 then
		return
	end

	CSIsLib.SelectCSIOption(tonumber(self.strKeypadDisplay))
end

function CSI:OnKeypadClear(wndHandler, wndControl)
	local tCSI = CSIsLib.GetActiveCSI()
	if tCSI == nil or tCSI.eType ~= CSIsLib.ClientSideInteractionType_Keypad or not CSIsLib.IsCSIRunning() then
		return
    end

	self.nKeypadCount = 0
	self.strKeypadDisplay = ""
	self.wndKeypad:FindChild("KeypadButtonContainer:Enter"):Enable(false)
	self.wndKeypad:FindChild("KeypadTopBG:KeypadText"):Show(true)
	self.wndKeypad:FindChild("KeypadTopBG:TextDisplay"):SetText("")
end

-----------------------------------------------------------------------------------------------
-- Memory
-----------------------------------------------------------------------------------------------

function CSI:OnMemoryStart(wndHandler, wndControl)
	if not CSIsLib.IsCSIRunning() then
		self.wndMemory:SetData(nil)
		self.wndMemory:FindChild("StartBtnBG"):Show(false)
		self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleText"):SetAML("")
		self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleReadyText"):SetData(false)
        CSIsLib.StartActiveCSI()
		Sound.Play(Sound.PlayUIMemoryStart)
	end
end

function CSI:OnAcceptProgressInput(bShouldAccept)
	if bShouldAccept then
		self.wndMemory:FindChild("OptionBtn1"):Enable(true)
		self.wndMemory:FindChild("OptionBtn2"):Enable(true)
		self.wndMemory:FindChild("OptionBtn3"):Enable(true)
		self.wndMemory:FindChild("OptionBtn4"):Enable(true)
		self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleReadyText"):Show(true, true)
	end

	self.wndMemory:SetData(nil)
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleReadyText"):SetData(bShouldAccept)

	for key, wndCurr in pairs(self.tMemoryOptions) do
		wndCurr:FindChild("OptionBtnFlash"):Show(false)
	end
end

function CSI:OnHighlightProgressOption(nOption)
	if not self.wndMemory or not self.wndMemory:IsValid() then
		return
	end

	self.wndMemory:FindChild("OptionBtn1"):Enable(false)
	self.wndMemory:FindChild("OptionBtn2"):Enable(false)
	self.wndMemory:FindChild("OptionBtn3"):Enable(false)
	self.wndMemory:FindChild("OptionBtn4"):Enable(false)
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleText"):SetAML("")
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleReadyText"):Show(false)

	local wndCurrFlash = self.tMemoryOptions[nOption]
	if wndCurrFlash then
		self.wndMemory:SetData(wndCurrFlash)
		wndCurrFlash:FindChild("OptionBtnFlash"):Show(true)
		Sound.Play(wndCurrFlash:GetData().sound)
		Apollo.CreateTimer("MemoryDisplayTimer", 0.5, false)
	end
end

function CSI:OnMemoryDisplayTimer() -- When we're done the flash
	if not self.wndMemory or not self.wndMemory:IsValid() then
		return
	end

	for key, wndCurr in pairs(self.tMemoryOptions) do
		wndCurr:FindChild("OptionBtnFlash"):Show(false)
	end
end

function CSI:OnMemoryBtn(wndHandler, wndControl)
	if not self:HelperVerifyCSIMemory() then
		return
	end

	-- Stomp on a flash if the player is super fast
	for key, wndCurr in pairs(self.tMemoryOptions) do
		wndCurr:FindChild("OptionBtnFlash"):Show(false)
	end

	local strTextColor = wndHandler:GetData().strTextColor
	local strRandomString = self:HelperBuildRandomString(5)
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleText"):SetAML("<P Font=\"CRB_AlienLarge\" TextColor=\""..strTextColor.."\" Align=\"Center\">"..strRandomString.."</P>")
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleText"):BeginDoogie(500)
	self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleReadyText"):Show(false)
	Sound.Play(wndHandler:GetData().sound)
	CSIsLib.SelectCSIOption(wndHandler:GetData().id)
end

function CSI:HelperBuildRandomString(nArgLength)
    local strResult = ""
    for idx = 1, nArgLength do
        strResult = strResult .. string.char(math.random(97, 122)) -- Lower case a-z
    end
    return strResult
end

function CSI:HelperVerifyCSIMemory()
	if not self.wndMemory or not self.wndMemory:IsValid() or not self.wndMemory:FindChild("BGArtCenterCircle:BGArtCenterCircleReadyText"):GetData() then
		return false
	end

	local tCSI = CSIsLib.GetActiveCSI()
	if not tCSI or tCSI.eType ~= CSIsLib.ClientSideInteractionType_Memory or not CSIsLib.IsCSIRunning() then
		return false
    end

	return true
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function CSI:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == nil then
		return false
	end

	local tRect = {}

	if eAnchor == GameLib.CodeEnumTutorialAnchor.PressAndHold and self.wndProgress ~= nil then
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndProgress:GetRect()
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.RapidTapping and self.wndProgress ~= nil then
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndProgress:GetRect()
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.PrecisionTapping and self.wndProgress ~= nil then
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndProgress:GetRect()
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.Memory and self.wndMemory ~= nil then
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMemory:GetRect()
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.Keypad and self.wndKeypad ~= nil then
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndKeypad:GetRect()
	elseif eAnchor == GameLib.CodeEnumTutorialAnchor.Metronome and self.wndProgress ~= nil then
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndProgress:GetRect()
	else
		return
	end

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

local CSIInst = CSI:new()
CSIInst:Init()
