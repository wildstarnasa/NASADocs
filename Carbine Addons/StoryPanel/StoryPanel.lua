-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "DialogSys"
require "Quest"
require "DialogResponse"
require "GameLib"

local StoryPanel = {}
local kcrAlertColor = "UI_BtnTextRedNormal"
local kcrInfoColor = "UI_TextHoloTitle"
local kstrAlertFont = "CRB_HeaderMedium"
local kstrInfoFont = "CRB_HeaderMedium"

function StoryPanel:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function StoryPanel:Init()
	Apollo.RegisterAddon(self)
end

function StoryPanel:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("StoryPanel.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function StoryPanel:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("StoryPanelDialog_Show", 			"OnStoryShow", self)
	Apollo.RegisterEventHandler("StoryPanelDialog_Hide", 			"HideStoryPanel", self)
	Apollo.RegisterEventHandler("ChangeWorld",						"HideStoryPanel", self)

	self.tVariants =
	{
		[GameLib.CodeEnumStoryPanel.Default] 					= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelBubble", nil, self), strCallback = "OnTimerDefault" },
		[GameLib.CodeEnumStoryPanel.Low] 						= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelBubbleLow", nil, self), strCallback = "OnTimerLow" },
		[GameLib.CodeEnumStoryPanel.Center] 					= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelBubbleCenter", nil, self), strCallback = "OnTimerCenter" },
		[GameLib.CodeEnumStoryPanel.FullScreen] 				= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelFullScreen", nil, self), strCallback = "OnTimerFullscreen" },
		[GameLib.CodeEnumStoryPanel.Whiteout] 					= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelWhiteout", nil, self), strCallback = "OnTimerWhiteout" },
		[GameLib.CodeEnumStoryPanel.Urgent] 					= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelUrgent", nil, self), strCallback = "OnTimerUrgent" },
		[GameLib.CodeEnumStoryPanel.FullScreenBlackNoFlash] 	= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelBlackout", nil, self), strCallback = "OnTimerFullScreenBlackNoFlash" },
		[GameLib.CodeEnumStoryPanel.Informational] 				= { wndStory = Apollo.LoadForm(self.xmlDoc, "StoryPanelInformational", nil, self), strCallback = "OnTimerInformational" },
	}
	self.xmlDoc = nil

	for idx, tCurr in pairs(self.tVariants) do
		tCurr.wndStory:Close()
		tCurr.wndStory:Show(false)
	end
	
end

function StoryPanel:OnStoryShow(eWindowType, tLines, nDisplayLength)
	if eWindowType > #self.tVariants then
        eWindowType = 1
    end

	local wndCurr = (self.tVariants[eWindowType] and self.tVariants[eWindowType].wndStory or nil)
	if not wndCurr then
		return
	end
	
	local oTimer = ApolloTimer.Create(nDisplayLength, false, (self.tVariants[eWindowType] and self.tVariants[eWindowType].strCallback or "HideStoryPanel"), self)
	wndCurr:SetData(oTimer)

	-- Text if there is text
	local wndStoryPanelText = wndCurr:FindChild("StoryPanelText")
	if wndStoryPanelText then
		-- Format text line by line
		local strAMLText = ""
		local bTextFound = false
		for idx, strCurr in ipairs(tLines) do
			if strCurr then
				bTextFound = true
				if eWindowType == GameLib.CodeEnumStoryPanel.Urgent then
					strAMLText = string.format("%s<P Align=\"Center\" Font=\"%s\" TextColor=\"%s\">%s</P>", strAMLText, kstrAlertFont, kcrAlertColor, strCurr)
				elseif eWindowType == GameLib.CodeEnumStoryPanel.Informational then
					strAMLText = string.format("%s<P Align=\"Center\" Font=\"%s\" TextColor=\"%s\">%s</P>", strAMLText, kstrInfoFont, kcrInfoColor, strCurr)
				else
					strAMLText = string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</P>", strAMLText, kcrInfoColor, strCurr)
				end
			end
		end

		if bTextFound then
			wndStoryPanelText:SetAML(strAMLText)
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			local nTextWidth, nTextHeight = wndStoryPanelText:SetHeightToContentHeight()
			wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nTextHeight + 70) -- Hardcoded size increase

			if eWindowType == GameLib.CodeEnumStoryPanel.FullScreen or eWindowType == GameLib.CodeEnumStoryPanel.FullScreenBlackNoFlash then
				wndStoryPanelText:BeginDoogie(200) -- Hardcoded doogie time
			end
		end

		wndStoryPanelText:Show(bTextFound)
		wndStoryPanelText:ToFront()
	end

	wndCurr:Show(true, eWindowType == GameLib.CodeEnumStoryPanel.Urgent)
	wndCurr:ToFront()
end

---------------------------------------------------------------------------------------------------
-- Story Panel Hide Timers
-- Callback methods called by ApolloTimer objects specific to each Story Panel type
---------------------------------------------------------------------------------------------------

function StoryPanel:OnTimerDefault()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.Default].wndStory)
end

function StoryPanel:OnTimerLow()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.Low].wndStory)
end

function StoryPanel:OnTimerCenter()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.Center].wndStory)
end

function StoryPanel:OnTimerFullscreen()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.FullScreen].wndStory)
end

function StoryPanel:OnTimerWhiteout()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.Whiteout].wndStory)
end

function StoryPanel:OnTimerUrgent()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.Urgent].wndStory)
end

function StoryPanel:OnTimerFullScreenBlackNoFlash()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.FullScreenBlackNoFlash].wndStory)
end

function StoryPanel:OnTimerInformational()
	self:HideStoryPanel(self.tVariants[GameLib.CodeEnumStoryPanel.Informational].wndStory)
end

---------------------------------------------------------------------------------------------------
-- UI Closing Methods
---------------------------------------------------------------------------------------------------

function StoryPanel:OnStoryPanelMouseDown(wndHandler, wndControl, eMouseButton, nX, nY, bDoubleClick)
	self:HideStoryPanel(wndHandler)
	return true -- stop propogation (don't want to accidentally click through it)
end

function StoryPanel:OnStoryPanelCloseClick()
    self:HideStoryPanel()
end

function StoryPanel:OnStoryPanelMouseEnter(wndHandler, wndControl, nX, nY)
	if wndHandler == wndControl and wndHandler:FindChild("ClosePrompt") then
		wndHandler:FindChild("ClosePrompt"):Invoke()
	end
end

function StoryPanel:OnStoryPanelMouseExit(wndHandler, wndControl, nX, nY)
	if wndHandler == wndControl and wndHandler:FindChild("ClosePrompt") then
		wndHandler:FindChild("ClosePrompt"):Show(false)

	end
end

function StoryPanel:HideStoryPanel(wndStory)
	if wndStory and wndStory:FindChild("ClosePrompt") then
		wndStory:FindChild("ClosePrompt"):Show(false)
	end
	
	if wndStory then
		wndStory:Close()
		wndStory:Show(false)
		wndStory:SetData(nil)
	else
		for idx, tCurr in pairs(self.tVariants) do
			tCurr.wndStory:Close()
			tCurr.wndStory:SetData(nil)
			if tCurr.wndStory and tCurr.wndStory:FindChild("ClosePrompt") then
				tCurr.wndStory:FindChild("ClosePrompt"):Show(false)
			end
		end
	end
end

local StoryPanelInst = StoryPanel:new()
StoryPanelInst:Init()
