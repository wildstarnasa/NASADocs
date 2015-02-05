-----------------------------------------------------------------------------------------------
-- Client Lua Script for PathScientistExperimentation
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local PathScientistExperimentation = {}
local kstrButtonStatePass = Apollo.GetString("ScientistMission_Success")
local kstrButtonStateFail = Apollo.GetString("ScientistMission_ExperimentFailed")
local kstrPatternTooltipStringFormula = "<P Font=\"CRB_InterfaceLarge_B\" TextColor=\"ff9d9d9d\">%s</P><P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s</P>"
local knAttemptsToDisplayBeforeVScroll = 5

local knSaveVersion = 2

function PathScientistExperimentation:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PathScientistExperimentation:Init()
    Apollo.RegisterAddon(self)
end

function PathScientistExperimentation:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSave = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	
	return tSave
end

function PathScientistExperimentation:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function PathScientistExperimentation:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathScientistExperimentation.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function PathScientistExperimentation:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("InvokeScientistExperimentation", "OnInvokeScientistExperimentation", self)
	Apollo.RegisterEventHandler("ScientistExperimentationResult", "OnScientistExperimentationResult", self)
end

function PathScientistExperimentation:Initialize()
	if self.wndMain then
		return
	end

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "PathScientistExperimentationForm", nil, self)
	self.wndMain:FindChild("RunExperimentBtn"):Enable(false)
	
	self.wndMain:FindChild("RunExperimentBtn"):Show(true)
	self.wndMain:FindChild("RetryExperimentBtn"):Show(false)

	local wndGroupPopout1 = Apollo.LoadForm(self.xmlDoc, "GuessPopout", self.wndMain:FindChild("GuessBtn1"), self)
	local wndGroupPopout2 = Apollo.LoadForm(self.xmlDoc, "GuessPopout", self.wndMain:FindChild("GuessBtn2"), self)
	local wndGroupPopout3 = Apollo.LoadForm(self.xmlDoc, "GuessPopout", self.wndMain:FindChild("GuessBtn3"), self)
	local wndGroupPopout4 = Apollo.LoadForm(self.xmlDoc, "GuessPopout", self.wndMain:FindChild("GuessBtn4"), self)

	self.wndMain:FindChild("GuessBtn1"):AttachWindow(wndGroupPopout1)
	self.wndMain:FindChild("GuessBtn2"):AttachWindow(wndGroupPopout2)
	self.wndMain:FindChild("GuessBtn3"):AttachWindow(wndGroupPopout3)
	self.wndMain:FindChild("GuessBtn4"):AttachWindow(wndGroupPopout4)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.nDefaultMainLeft, self.nDefaultMainTop, self.nDefaultMainRight, self.nDefaultMainBottom = self.wndMain:GetAnchorOffsets()
	local wndTemp = Apollo.LoadForm(self.xmlDoc, "AttemptRow", self.wndMain:FindChild("ResultContainer"), self)
	local nLeft, nTop, nRight, nBottom = wndTemp:GetAnchorOffsets()
	self.nAttemptRowHeight = nBottom - nTop
	wndTemp:Destroy()
end

function PathScientistExperimentation:OnInvokeScientistExperimentation(pmExperiment)
	self:Initialize()

	self.wndMain:SetData(pmExperiment)
	--self.wndMain:FindChild("BGRulesText"):Show(true)
	self.wndMain:FindChild("TutorialRunner"):Show(true)
	self.wndMain:FindChild("RunExperimentBtn"):Show(true)
	self.wndMain:FindChild("RetryExperimentBtn"):Show(false)
	
	--self.wndMain:FindChild("RunExperimentBtn"):ChangeArt("CRB_Basekit:kitBtn_Metal_MediumGreen")
	self.wndMain:FindChild("RunExperimentBtn"):SetText(Apollo.GetString("ScientistMission_RunExperiment"))
	self.wndMain:FindChild("RunExperimentBtn"):Enable(false)
	self.wndMain:FindChild("ResultContainer"):DestroyChildren()

	self:ResetAndDraw(pmExperiment)

	local tInfo = pmExperiment:GetScientistExperimentationInfo()
	if not tInfo then
		return
	end

	for idx = 1, tInfo.nAttempts do
		local wndAttemptRow = Apollo.LoadForm(self.xmlDoc, "AttemptRow", self.wndMain:FindChild("ResultContainer"), self)
		wndAttemptRow:SetName(idx)
		wndAttemptRow:SetData("ReadyForAnything")
		wndAttemptRow:FindChild("CountText"):SetText(idx)
	end
	self.wndMain:FindChild("ResultContainer"):ArrangeChildrenVert(0)

	local nAttemptsHeight = math.min((tInfo.nAttempts * self.nAttemptRowHeight), (knAttemptsToDisplayBeforeVScroll * self.nAttemptRowHeight))
	if not self.locSavedWindowLoc then
		self.wndMain:SetAnchorOffsets(self.nDefaultMainLeft, self.nDefaultMainTop, self.nDefaultMainRight, self.nDefaultMainBottom + nAttemptsHeight)
	end
	self.wndMain:Show(true)
end

function PathScientistExperimentation:ResetAndDraw(pmExperiment)
	local tInfo = pmExperiment:GetScientistExperimentationInfo()
	if not tInfo then
		return
	end

	local strButtonState = ""
	if self.wndMain:FindChild("RunExperimentBtn"):IsShown() then
		strButtonState = self.wndMain:FindChild("RunExperimentBtn"):GetData()
	elseif self.wndMain:FindChild("RetryExperimentBtn"):IsShown() then
		strButtonState = self.wndMain:FindChild("RetryExperimentBtn"):GetData()
	end	
	
	self.wndMain:FindChild("RunExperimentBtn"):Enable(strButtonState == kstrButtonStatePass or strButtonState == kstrButtonStateFail)

	local tGuessBtns = {self.wndMain:FindChild("GuessBtn1"), self.wndMain:FindChild("GuessBtn2"), self.wndMain:FindChild("GuessBtn3"), self.wndMain:FindChild("GuessBtn4")}
	for key, wndGuessBtn in pairs(tGuessBtns) do
		wndGuessBtn:SetData(nil)
		wndGuessBtn:SetCheck(false)
		wndGuessBtn:FindChild("GuessBtnIcon"):SetTooltip("")

		if strButtonState == kstrButtonStatePass then
			wndGuessBtn:Enable(false)
			wndGuessBtn:FindChild("GuessBtnIcon"):SetSprite("Icon_Windows_UI_CRB_Checkmark")
		elseif strButtonState == kstrButtonStateFail then
			wndGuessBtn:Enable(false)
			wndGuessBtn:FindChild("GuessBtnIcon"):SetSprite("LootCloseBox")
		else
			wndGuessBtn:Enable(true)
			wndGuessBtn:FindChild("GuessBtnIcon"):SetSprite("")
		end

		-- Now for the guess pop out
		local tPatterns = pmExperiment:GetScientistExperimentationCurrentPatterns()
		if tPatterns ~= nil then
			local tGuessIcons = {wndGuessBtn:FindChild("GuessOption1"), wndGuessBtn:FindChild("GuessOption2"), wndGuessBtn:FindChild("GuessOption3"), wndGuessBtn:FindChild("GuessOption4")}
			for idx, tPattern in pairs(tPatterns) do
				tGuessIcons[idx]:SetData({tPattern, wndGuessBtn, idx})
				tGuessIcons[idx]:FindChild("GuessOptionIcon"):SetSprite(tPattern.strIcon)
				tGuessIcons[idx]:FindChild("GuessOptionIcon"):SetTooltip(string.format(kstrPatternTooltipStringFormula, tPattern.strName, tPattern.strDescription))
			end
		end
	end
end

function PathScientistExperimentation:OnGuessOptionClicked(wndHandler, wndControl)
	local wndGuessBtnData 	= wndHandler:GetData()
	local tPattern 			= wndGuessBtnData[1]
	local wndGuessBtn 		= wndGuessBtnData[2]
	local nPatternNum		= wndGuessBtnData[3]

	wndGuessBtn:SetData({tPattern, nPatternNum})
	wndGuessBtn:FindChild("GuessBtnIcon"):SetSprite(tPattern.strIcon)
	wndGuessBtn:FindChild("GuessBtnIcon"):SetTooltip(string.format(kstrPatternTooltipStringFormula, tPattern.strName, tPattern.strDescription))
	wndGuessBtn:FindChild("GuessPopout"):Close()

	self.wndMain:FindChild("RunExperimentBtn"):Enable(self.wndMain:FindChild("GuessBtn1"):GetData() and self.wndMain:FindChild("GuessBtn2"):GetData() and
													  self.wndMain:FindChild("GuessBtn3"):GetData() and self.wndMain:FindChild("GuessBtn4"):GetData())
end

function PathScientistExperimentation:OnRunExperimentClick(wndHandler, wndControl)
	if wndHandler:GetData() == kstrButtonStatePass then
		self:OnCloseBtn()
		return
	end

	local pmExperiment = self.wndMain:GetData()
	if wndHandler:GetData() == kstrButtonStateFail then
		self.wndMain:FindChild("RunExperimentBtn"):SetData("")
		pmExperiment:RefreshScientistExperimentation()
		return
	end

	local wndResultToUse = nil
	for key, wndCurr in pairs(self.wndMain:FindChild("ResultContainer"):GetChildren()) do
		if wndCurr:GetData() == "ReadyForAnything" then
			wndResultToUse = wndCurr
			break
		end
	end

	local tAttemptFrames = {wndResultToUse:FindChild("AttemptFrame1"), wndResultToUse:FindChild("AttemptFrame2"), wndResultToUse:FindChild("AttemptFrame3"), wndResultToUse:FindChild("AttemptFrame4")}
	local tGuessBtns = {self.wndMain:FindChild("GuessBtn1"), self.wndMain:FindChild("GuessBtn2"), self.wndMain:FindChild("GuessBtn3"), self.wndMain:FindChild("GuessBtn4")}

	if wndResultToUse then
		wndResultToUse:SetData("WaitingForResult")
		for idx, wndCurr in pairs(tAttemptFrames) do
			local wndGuessBtnData 	= tGuessBtns[idx]:GetData()
			local tPattern 			= wndGuessBtnData[1]
			local nPatternNum		= wndGuessBtnData[2]
			
			wndCurr:Show(true)
			wndCurr:FindChild("AttemptIcon"):SetSprite(tPattern.strIcon)
			wndCurr:FindChild("AttemptIcon"):SetTooltip(string.format(kstrPatternTooltipStringFormula, tPattern.strName, tPattern.strDescription))
		end
	end

	local tCode = 
	{
		["Choice1"] = self.wndMain:FindChild("GuessBtn1"):GetData()[1].idPattern,
		["Choice2"] = self.wndMain:FindChild("GuessBtn2"):GetData()[1].idPattern,
		["Choice3"] = self.wndMain:FindChild("GuessBtn3"):GetData()[1].idPattern,
		["Choice4"] = self.wndMain:FindChild("GuessBtn4"):GetData()[1].idPattern,
	}
	
	pmExperiment:AttemptScientistExperimentation(4, tCode)

	self:ResetAndDraw(pmExperiment)
	--self.wndMain:FindChild("BGRulesText"):Show(false)
end

function PathScientistExperimentation:OnScientistExperimentationResult(arResults)
	local wndResultToUse = self.wndMain:FindChild("ResultContainer"):FindChildByUserData("WaitingForResult")
	if not wndResultToUse then
		return
	end

	local nExact = 0
	local nPartial = 0
	for idx, eCurrResult in ipairs(arResults) do
		if eCurrResult == PathMission.ScientistExperimentationResult_Correct then
			local wndIcon = Apollo.LoadForm(self.xmlDoc, "AttemptRowIcon", wndResultToUse:FindChild("ExactIconContainer"), self)
			wndIcon:SetSprite("kitIcon_Holo_Checkmark")
			nExact = nExact + 1
		elseif eCurrResult == PathMission.ScientistExperimentationResult_CorrectPattern then
			local wndIcon = Apollo.LoadForm(self.xmlDoc, "AttemptRowIcon", wndResultToUse:FindChild("PartialIconContainer"), self)
			wndIcon:SetSprite("kitIcon_Holo_QuestionMark")
			nPartial = nPartial + 1
		end
	end

	wndResultToUse:SetData("AttemptUsed")
	wndResultToUse:FindChild("ExactCorrectText"):Show(nExact > 0)
	wndResultToUse:FindChild("PartialCorrectText"):Show(nPartial > 0)

	local tMatchInfo = {["name"] = nil, ["count"] = nil}
	
	tMatchInfo["name"] = Apollo.GetString("ScientistMission_ExactMatch")
	tMatchInfo["count"] = nExact
		
	wndResultToUse:FindChild("ExactCorrectText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Multiple"), tMatchInfo))

	tMatchInfo["name"] = Apollo.GetString("ScientistMission_PartialMatch")
	tMatchInfo["count"] = nPartial
		
	wndResultToUse:FindChild("PartialCorrectText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Multiple"), tMatchInfo))
	

	wndResultToUse:FindChild("ExactIconContainer"):ArrangeChildrenHorz(2)
	wndResultToUse:FindChild("PartialIconContainer"):ArrangeChildrenHorz(2)
	self.wndMain:FindChild("ResultContainer"):ArrangeChildrenVert(0)

	-- Check for win
	if nExact == 4 then
		self.wndMain:FindChild("RunExperimentBtn"):SetText(Apollo.GetString("ScientistMission_Success"))
		self.wndMain:FindChild("RunExperimentBtn"):SetData(kstrButtonStatePass)
		return
	end

	-- Check for loss
	if not self.wndMain:FindChild("ResultContainer"):FindChildByUserData("ReadyForAnything") then
		self.wndMain:FindChild("RunExperimentBtn"):Show(false)
		self.wndMain:FindChild("RetryExperimentBtn"):SetData(kstrButtonStateFail)
		self.wndMain:FindChild("RetryExperimentBtn"):Show(true)
		
		return
	end
end

function PathScientistExperimentation:OnCloseBtn(wndHandler, wndControl, eMouseButton) -- WindowClosed also routes here
	self.wndMain:FindChild("RunExperimentBtn"):SetData("")
	--self.locSavedWindowLoc = self.wndMain:GetLocation()
	self.wndMain:Close()
	Event_CancelExperimentation() -- For Code?
end

function PathScientistExperimentation:OnHideTutorialRunner(wndHandler, wndControl)
	self.wndMain:FindChild("TutorialRunner"):Show(false)
end

local PathScientistExperimentationInst = PathScientistExperimentation:new()
PathScientistExperimentationInst:Init()
t_Flyout" Visible="1" HideInEditor="0" CloseOnExternalClick="0" Tooltip="" NoClip="1">
                <Control Class="Window" LAnchorPoint="0" LAnchorOffset="47" TAnchorPoint="0" TAnchorOffset="51" RAnchorPoint="1" RAnchorOffset="-45" BAnchorPoint="1" BAnchorOffset="-52" RelativeToClient="1" Font="Default" Text="" Template="Holo_ScrollListSmall" TooltipType="OnCursor" Name="ProfileDropdownList" BGColor="white" TextColor="white" TooltipColor="" Picture="0" IgnoreMouse="1" VScroll="1" Border="1" UseTemplateBG="1"/>
            </Control>
        </Control>
        <Control Class="Button" Base="CRB_Basekit:kitBtn_Dropdown_TextBaseHolo2" Font="CRB_Button" ButtonType="Check" RadioGroup="" LAnchorPoint="0" LAnchorOffset="48" TAnchorPoint="1" TAnchorOffset="-392" RAnchorPoint="0.5" RAnchorOffset="100" BAnchorPoint="1" BAnchorOffset="-356" DT_VCENTER="1" DT_CENTER="1" TooltipType="OnCursor" Name="ProfileDropdownBtn" BGColor="white" TextColor="white" TooltipColor="" NormalTextColor="UI_BtnTextHoloNormal" PressedTextColor="UI_BtnTextHoloPressed" FlybyTextColor="UI_BtnTextHoloFlyby" PressedFlybyTextColor="UI_BtnTextHoloPressedFlyby" DisabledTextColor="UI_BtnTextHoloDisabled" HideInEditor="0" Visible="1" RelativeToClient="1" Text="" TextId="CRB__2"/>
        <Control Class="Button" Base="BK3:btnHolo_Blue_Small" Font="CRB_Button" ButtonType="Check" RadioGroup="" LAnchorPoint="1" LAnchorOffset="-165" TAnchorPoint="1" TAnchorOffset="-401" RAnchorPoint="1" RAnchorOffset="-46" BAnchorPoint="1" BAnchorOffset="-348" DT_VCENTER="1" DT_CENTER="1" TooltipType="OnCursor" Name="RenameBtn" BGColor="white" TextColor="white" TooltipColor="" NormalTextColor="UI_BtnTextHoloNormal" PressedTextColor="UI_BtnTextHoloPressed" FlybyTextColor="UI_BtnTextHoloFlyby" PressedFlybyTextColor="UI_BtnTextHoloPressedFlyby" DisabledTextColor="UI_BtnTextHoloDisabled" Text="" TextId="ScientistMission_RenameBot" Tooltip="" NewWindowDepth="0" NewControlDepth="9" DrawAsCheckbox="0">
            <Event Name="ButtonSignal" Function="YourFunctionName"/>
        </Control>
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="344" TAnchorPoint="0" TAnchorOffset="129" RAnchorPoint="1" RAnchorOffset="-21" BAnchorPoint="1" BAnchorOffset="-172" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="RenameFrameBG" BGColor="UI_AlphaPercent60" TextColor="white" TooltipColor="" Sprite="" Picture="1" IgnoreMouse="0" Visible="0" HideInEditor="0" CloseOnExternalClick="1" NewWindowDepth="0" SwallowMouseClicks="1">
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="1" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="0" BAnchorOffset="118" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="RenameFrameBox" BGColor="white" TextColor="white" TooltipColor="" Picture="1" IgnoreMouse="1" Sprite="" NewControlDepth="1" CloseOnExternalClick="0" Visible="1" Tooltip="" HideInEditor="0" NoClip="1" SwallowMouseClicks="1">
                <Control Class="Window" LAnchorPoint="0" LAnchorOffset="-30" TAnchorPoint="0" TAnchorOffset="-30" RAnchorPoint="1" RAnchorOffset="30" BAnchorPoint="1" BAnchorOffset="30" RelativeToClient="1" Font="Defa