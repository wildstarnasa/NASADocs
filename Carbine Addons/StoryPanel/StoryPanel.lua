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
local kcrAlertColor = "ffffeba4"
local kcrInfoColor = "ffffffff"
local kstrAlertFont = "CRB_HeaderLarge"
local kstrInfoFont = "CRB_HeaderHuge"

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
	Apollo.RegisterTimerHandler("StoryDisplayLengthTimer", 			"HideStoryPanel", self)
	Apollo.RegisterEventHandler("MessageManager_HideStoryPanel", 	"HideStoryPanel", self)
	Apollo.RegisterEventHandler("MessageManager_DisplayStoryPanel", "ShowStoryPanel", self)
	Apollo.RegisterEventHandler("ChangeWorld",						"HideStoryPanel", self)

	self.tVariants =
	{
		[GameLib.CodeEnumStoryPanel.Default] 					= Apollo.LoadForm(self.xmlDoc, "StoryPanelBubble", nil, self),
		[GameLib.CodeEnumStoryPanel.Low] 						= Apollo.LoadForm(self.xmlDoc, "StoryPanelBubbleLow", nil, self),
		[GameLib.CodeEnumStoryPanel.Center] 					= Apollo.LoadForm(self.xmlDoc, "StoryPanelBubbleCenter", nil, self),
		[GameLib.CodeEnumStoryPanel.FullScreen] 				= Apollo.LoadForm(self.xmlDoc, "StoryPanelFullScreen", nil, self),
		[GameLib.CodeEnumStoryPanel.Whiteout] 					= Apollo.LoadForm(self.xmlDoc, "StoryPanelWhiteout", nil, self),
		[GameLib.CodeEnumStoryPanel.Urgent] 					= Apollo.LoadForm(self.xmlDoc, "StoryPanelUrgent", nil, self),
		[GameLib.CodeEnumStoryPanel.FullScreenBlackNoFlash] 	= Apollo.LoadForm(self.xmlDoc, "StoryPanelBlackout", nil, self),
		[GameLib.CodeEnumStoryPanel.Informational] 				= Apollo.LoadForm(self.xmlDoc, "StoryPanelInformational", nil, self),
	}
	self.xmlDoc = nil

	for idx, wndCurr in pairs(self.tVariants) do
		wndCurr:Show(false, true)
	end

	self.wndCurrentVariant = nil
end

function StoryPanel:OnStoryShow(eWindowType, tLines, nDisplayLength)
	self:ShowStoryPanel(eWindowType, tLines, nDisplayLength)
	
	-- Chat Message (if not full screen)
	if eWindowType ~= GameLib.CodeEnumStoryPanel.FullScreen then
		local tParams = { iWindowType = eWindowType, tLines = tLines, nDisplayLength = nDisplayLength }
		Event_FireGenericEvent("RequestShowStoryPanel", LuaEnumMessageType.StoryPanel, tParams)
	end	
end

function StoryPanel:ShowStoryPanel(eWindowType, tLines, nDisplayLength, bReposition)
	if eWindowType > #self.tVariants then
        eWindowType = 1
    end

	self.wndCurrentVariant = self.tVariants[eWindowType]
	Apollo.StopTimer("StoryDisplayLengthTimer")
	Apollo.CreateTimer("StoryDisplayLengthTimer", nDisplayLength, false)

	local wndCurr = self.tVariants[eWindowType]
	if not wndCurr then
		return
	end

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
					strAMLText = string.format("%s<P Font=\"CRB_InterfaceLarge\" TextColor=\"ff87dedb\">%s</P>", strAMLText, strCurr)
				end
			end
		end

		if bTextFound then
			wndStoryPanelText:SetAML(strAMLText)
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			local nTextWidth, nTextHeight = wndStoryPanelText:SetHeightToContentHeight()
			wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nTextHeight + 20) -- Hardcoded size increase

			if eWindowType == GameLib.CodeEnumStoryPanel.FullScreen or eWindowType == GameLib.CodeEnumStoryPanel.FullScreenBlackNoFlash then
				wndStoryPanelText:BeginDoogie(200) -- Hardcoded doogie time
			end
		end

		wndStoryPanelText:Show(bTextFound)
		wndStoryPanelText:ToFront()
	end

	if bReposition then
		wndCurr:Reposition()
	end

	wndCurr:Show(true, eWindowType == GameLib.CodeEnumStoryPanel.Urgent)
	wndCurr:ToFront()
end

---------------------------------------------------------------------------------------------------
-- UI Closing Methods
---------------------------------------------------------------------------------------------------

function StoryPanel:OnStoryPanelMouseDown(wndHandler, wndControl, eMouseButton, nX, nY, bDoubleClick)
	self:HideStoryPanel(true)
	return true -- stop propogation (don't want to accidentally click through it)
end

function StoryPanel:OnStoryPanelCloseClick()
    self:HideStoryPanel()
end

function StoryPanel:OnStoryPanelMouseEnter(wndHandler, wndControl, nX, nY)
	if wndHandler == wndControl and wndHandler:FindChild("ClosePrompt") then
		wndHandler:FindChild("ClosePrompt"):Show(true)
	end
end

function StoryPanel:OnStoryPanelMouseExit(wndHandler, wndControl, nX, nY)
	if wndHandler == wndControl and wndHandler:FindChild("ClosePrompt") then
		wndHandler:FindChild("ClosePrompt"):Show(false)
	end
end

function StoryPanel:HideStoryPanel(bManuallyClosed)
	if self.wndCurrentVariant then
		self.wndCurrentVariant:Show(false, bManuallyClosed or false)
		Event_FireGenericEvent("StoryPanel_StoryPanelHidden", LuaEnumMessageType.StoryPanel)
	end
end

local StoryPanelInst = StoryPanel:new()
StoryPanelInst:Init()
