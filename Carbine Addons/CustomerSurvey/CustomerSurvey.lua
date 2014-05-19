-----------------------------------------------------------------------------------------------
-- Client Lua Script for CustomerSurvey
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "CustomerSurveyTypeLib"
require "CustomerSurveyLib"

local CustomerSurvey = {}
function CustomerSurvey:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function CustomerSurvey:Init()
    Apollo.RegisterAddon(self)
end

function CustomerSurvey:OnLoad()
   	Apollo.RegisterEventHandler("NewCustomerSurveyRequest", "OnSurveyRequest", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnEnteredCombat", self)
end

function CustomerSurvey:Initialize()
	if self.wndMain and self.wndMain:IsValid() then
		return
	end

    self.wndMain = Apollo.LoadForm("CustomerSurvey.xml", "CustomerSurveyForm", nil, self)
	self.wndAlertContainer = nil
	self.wndCommentEntry = nil
	self.csActiveSurvey = nil
	self.bInCombat = false
	self.tRadios = {}
	self.nAnswered = 0
end

function CustomerSurvey:OnSurveyRequest()
	self:Initialize()
	self:RedrawAll()
end

function CustomerSurvey:OnEnteredCombat(unit, bInCombat)
	if self.wndMain and unit == GameLib.GetPlayerUnit() then
		self.bInCombat = bInCombat
		if bInCombat then
			self:RedrawAll()
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Main Draw Method
-----------------------------------------------------------------------------------------------

function CustomerSurvey:RedrawAll()
	self:UpdateAlert()
	self:UpdateSurvey()
end

function CustomerSurvey:UpdateAlert()
	if self.wndAlertContainer and self.wndAlertContainer:IsValid() then
		self.wndAlertContainer:Destroy()
	end

	self.wndAlertContainer = Apollo.LoadForm("CustomerSurvey.xml", "CustomerSurveyAlertContainer", "FixedHudStratum", self)
	for idx = 1, 3 do
		local tSurvey = CustomerSurveyLib.GetPending(idx)
		if tSurvey then
			local wndAlert = Apollo.LoadForm("CustomerSurvey.xml", "CustomerSurveyAlert", self.wndAlertContainer:FindChild("List"), self)
			wndAlert:SetData(tSurvey)
			wndAlert:FindChild("CustomerSurveyAlertBtn"):SetData(tSurvey)
			wndAlert:SetTooltip(String_GetWeaselString(Apollo.GetString("CustomerSurvey_ClickToTake"), tSurvey:GetTitle()))
		end
	end

	self.wndAlertContainer:FindChild("List"):ArrangeChildrenHorz(0)
	self.wndAlertContainer:FindChild("List"):SetText(CustomerSurveyLib.GetPendingCount() > 3 and Apollo.GetString("CRB_Elipsis") or "")
	if #self.wndAlertContainer:FindChild("List"):GetChildren() <= 1 then
		self.wndAlertContainer:Destroy()
	end
end

function CustomerSurvey:UpdateSurvey()
	local bDoShow = false
	if self.csActiveSurvey == nil then
		self.csActiveSurvey = CustomerSurveyLib.GetPending(1)
	end
	
	if self.csActiveSurvey then
		local tQuestions = self.csActiveSurvey:GetQuestions()
		if tQuestions then
			bDoShow = true
			self.wndMain:FindChild("OkButton"):Enable(false)
			self.wndMain:FindChild("TitleLabel"):SetText(self.csActiveSurvey:GetTitle())
			self.wndMain:FindChild("QuestionsForm"):DestroyChildren()
			
			self.nAnswered = 0
			
			for idx, strQuestion in pairs(tQuestions) do
				local wndCurr = Apollo.LoadForm("CustomerSurvey.xml", "QuestionEntry", self.wndMain:FindChild("QuestionsForm"), self)
				wndCurr:FindChild("QuestionLabel"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloTitle\">"..strQuestion.."</P>")
				local nWidth, nHeight = wndCurr:FindChild("QuestionLabel"):SetHeightToContentHeight()

				local nPicked = self.csActiveSurvey:GetResults(idx)
				if nPicked and nPicked > 0 then
					wndCurr:FindChild("BottomForm"):FindChild("SurveyResultForm"):SetRadioSel("SurveyResult", nPicked)
					self.nAnswered = self.nAnswered + 1
				end
				
				local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
				wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 50)
			end

			if not self.wndCommentEntry or not self.wndCommentEntry:IsValid() then
				self.wndCommentEntry = Apollo.LoadForm("CustomerSurvey.xml", "CommentEntry", self.wndMain:FindChild("QuestionsForm"), self)
			end
			self.wndCommentEntry:FindChild("BottomForm"):FindChild("CommentTextBox"):SetText(self.csActiveSurvey:GetComment() or "")

			self.wndMain:FindChild("QuestionsForm"):ArrangeChildrenVert(0)
		end
	end
	
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Show(bDoShow and not self.bInCombat)
	end
end

function CustomerSurvey:SaveEntries()
	if self.csActiveSurvey then
		local tResults = {}
		for idx, wndEntry in pairs(self.wndMain:FindChild("QuestionsForm"):GetChildren()) do
			if wndEntry and wndEntry:IsValid() and wndEntry ~= self.wndCommentEntry then
				tResults[idx] = wndEntry:FindChild("BottomForm"):FindChild("SurveyResultForm"):GetRadioSel("SurveyResult")
			end
		end

		self.csActiveSurvey:SetResults(tResults)
		self.csActiveSurvey:SetComment(self.wndCommentEntry:FindChild("BottomForm"):FindChild("CommentTextBox"):GetText())
	end
end

-----------------------------------------------------------------------------------------------
-- CustomerSurveyForm Functions
-----------------------------------------------------------------------------------------------

function CustomerSurvey:OnOK()
	self:SaveEntries()
	if self.csActiveSurvey then
		self.csActiveSurvey:SendResult()
		self.tRadios = {}
		self.nAnswered = 0
		self.csActiveSurvey = nil
	end
	self:RedrawAll()
end

function CustomerSurvey:OnClose()
	if self.csActiveSurvey then
		self.csActiveSurvey:Cancel()
		self.tRadios = {}
		self.nAnswered = 0
		self.csActiveSurvey = nil
	end
	self:RedrawAll()
end

function CustomerSurvey:OnCustomerSurveyAlertBtn(wndHandler, wndControl, eMouseButton)
	if wndControl ~= wndControl or not wndControl:GetData() then
		return
	end
	self.csActiveSurvey = wndControl:GetData()
	self:UpdateSurvey()
end

function CustomerSurvey:OnAnyInputFromUI(wndHandler, wndControl)

	local wndParent = wndHandler:GetParent()
	local nFoundIndex = 0
	
	for idx, tInfo in pairs(self.tRadios) do
		if self.tRadios[idx].wndContainer and self.tRadios[idx].wndContainer == wndParent then
			nFoundIndex = idx
			break
		end
	end
	if nFoundIndex == 0 then
		local tInputInfo = 
		{
			wndContainer = wndParent,
			bChecked = true,
		}
		
		table.insert(self.tRadios, tInputInfo)
		
		self.nAnswered = self.nAnswered + 1
	end

	if self.nAnswered == #self.csActiveSurvey:GetQuestions() then
		self.wndMain:FindChild("OkButton"):Enable(true)
	else
		self.wndMain:FindChild("OkButton"):Enable(false)
	end
end

local CustomerSurveyInst = CustomerSurvey:new()
CustomerSurveyInst:Init()
