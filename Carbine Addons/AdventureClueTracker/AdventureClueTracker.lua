-----------------------------------------------------------------------------------------------
-- Client Lua Script for ClueTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

local ClueTracker = {}

local knSaveVersion = 1

function ClueTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ClueTracker:Init()
    Apollo.RegisterAddon(self)
end

function ClueTracker:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSaved = 
	{
		bIsShown = self.bIsShown, 
		tClueList = self.tClues,
		nSaveVersion = knSaveVersion,
	}
	return tSaved
end

function ClueTracker:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.bIsShown then
		local bIsMalgrave = false
		local tPublicEvents = PublicEvent.GetActiveEvents()
		
		for idx, peEvent in pairs(tPublicEvents) do
			if peEvent:GetEventType() == PublicEvent.PublicEventType_Adventure_Malgrave then
				bIsMalgrave = true
			end
		end
		
		if bIsMalgrave then
			self:Initialize()
			for idx, strClue in pairs(tSavedData.tClueList) do
				self:OnPopulate(idx, strClue)
			end
		end
	end
end

function ClueTracker:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AdventureClueTracker.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function ClueTracker:OnDocumentReady()
    Apollo.RegisterSlashCommand("cluetracker", "Initialize", self)
    Apollo.RegisterEventHandler("ShowClueUI", "Initialize", self) -- Disabled for now, wait for PopulateClueUI to show
	Apollo.RegisterEventHandler("HideClueUI", "OnHide", self)
	Apollo.RegisterEventHandler("PopulateClueUI", "OnPopulate", self)
	
	self.bIsShown = false
	self.tClues = {}
end

function ClueTracker:Initialize()
    if not self.wndMain or not self.wndMain:IsValid() then -- To save memory, don't load until needed
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "ClueTrackerForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("ClueTracker_Clues")})
	end
	
	self.wndMain:Show(true)
	self.bIsShown = true
end

function ClueTracker:OnHide()
	if self.wndMain then
		self.wndMain:Destroy()
		self.wndMain = nil
		self.bIsShown = false
	end
end

function ClueTracker:OnPopulate(nWhich, strText)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end
	
	self.tClues[nWhich] = strText

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "ClueFrame", self.wndMain:FindChild("ClueFrameScroll"), self)
	wndCurr:FindChild("ClueNumber"):SetText(Apollo.GetString("NumberCharacter") .. nWhich)
	wndCurr:FindChild("ClueText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">"..Apollo.GetString(strText).."</P>")
	local nTextWidth, nTextHeight = wndCurr:FindChild("ClueText"):SetHeightToContentHeight()
	local l,t,r,b = wndCurr:GetAnchorOffsets()
	nTextHeight = math.max(27, nTextHeight) -- Minimum height for the text
	wndCurr:SetAnchorOffsets(l,t,r,t + nTextHeight + 29) -- +2 is for lower g height and padding

	self.wndMain:FindChild("ClueFrameScroll"):ArrangeChildrenVert(0)
end

-----------------------------------------------------------------------------------------------
-- ClueTracker Instance
-----------------------------------------------------------------------------------------------
local ClueTrackerInst = ClueTracker:new()
ClueTrackerInst:Init()
olor="white" NewControlDepth="2" WindowSoundTemplate="HoloButtonSmall" Text="" TextId="" TooltipColor="" NormalTextColor="white" PressedTextColor="white" FlybyTextColor="white" PressedFlybyTextColor="white" DisabledTextColor="white" TestAlpha="1">
                <Event Name="ButtonSignal" Function="OnCancel"/>
            </Control>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffs