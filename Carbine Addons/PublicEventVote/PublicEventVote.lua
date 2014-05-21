-----------------------------------------------------------------------------------------------
-- Client Lua Script for PublicEventVote
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "PublicEvent"

-----------------------------------------------------------------------------------------------
-- PublicEventVote Module Definition
-----------------------------------------------------------------------------------------------
local PublicEventVote = {}

local knSaveVersion = 1

function PublicEventVote:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PublicEventVote:Init()
    Apollo.RegisterAddon(self)
end

function PublicEventVote:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return false
	end
	
	local tSavedData = 
	{
		bIsShown = self.bWindowShown, 
		nSelectedVote = self.nSelectedVote,
		nSaveVersion = knSaveVersion,
	}
	
	return tSavedData
end

function PublicEventVote:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.bIsShown then
		self:Initialize()
		self:OnPublicEventInitiateVote()
		if tSavedData.nSelectedVote then
			for key, wndCurr in pairs(self.wndMain:FindChild("VoteFrameScroll"):GetChildren()) do
				if wndCurr:FindChild("VoteOptionBtn"):GetData() == tSavedData.nSelectedVote then
					wndCurr:FindChild("VoteOptionBtnCheck"):Show(true)
				end
				wndCurr:FindChild("VoteOptionBtn"):Enable(false)
			end
			self.nSelectedVote = tSavedData.nSelectedVote
		end
	end	
end

function PublicEventVote:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PublicEventVote.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function PublicEventVote:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("PublicEventInitiateVote", 	"OnPublicEventInitiateVote", self)
	Apollo.RegisterEventHandler("PublicEventVoteTallied", 	"OnPublicEventVoteTallied", self)
	Apollo.RegisterEventHandler("PublicEventVoteEnded", 	"OnPublicEventVoteEnded", self)
	
	Apollo.RegisterTimerHandler("VoteUpdateTimer", 			"OnOneSecTimer", self)
	Apollo.RegisterTimerHandler("HideWinnerTimer", 			"OnPublicEventInitiateVote", self)
	
	Apollo.CreateTimer("VoteUpdateTimer", 1, true)
	Apollo.StopTimer("VoteUpdateTimer")
	

	self.wndMain = nil
	self.bWindowShown = false
end

function PublicEventVote:Initialize()
	if self.wndMain then
		Apollo.StopTimer("VoteUpdateTimer")
		self.wndMain:Destroy()
	end

	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "PublicEventVoteForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Guild_ChatFlagVote")})
		
		Apollo.StartTimer("VoteUpdateTimer")
	end
	
	self.wndMain:Show(true)
	self.bWindowShown = true
end

function PublicEventVote:OnPublicEventInitiateVote() -- The close checking also routes here
	Apollo.StopTimer("HideWinnerTimer")
 
	local tVoteData = PublicEvent.GetActiveVote()
	if not tVoteData then
		if self.wndMain then
			self.wndMain:Destroy()
			self.bWindowShown = false
		end
		return
	end

	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		self:Initialize()
	end

	-- Note math.floor(tVoteData.timeRemaining) won't be 100% accurate and will have fraction errors, but we'll live with that
	self.wndMain:FindChild("VoteTitle"):SetText(tVoteData.strTitle .. " (" .. math.floor(tVoteData.fTimeRemaining) .. ")")
	self.wndMain:FindChild("VoteDescription"):SetText(tVoteData.strDescription)

	-- Vote Options
	self.wndMain:FindChild("VoteFrameScroll"):DestroyChildren()
	for key, tOptionData in pairs(tVoteData.arOptions) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "VoteOptionItem", self.wndMain:FindChild("VoteFrameScroll"), self)
		wndCurr:FindChild("VoteOptionBtn"):SetData(tOptionData.nChoice)
		wndCurr:FindChild("VoteOptionBtnCheck"):SetData(tOptionData.nTally)
		wndCurr:FindChild("VoteOptionTitle"):SetText(tOptionData.strLabel)
		wndCurr:FindChild("VoteOptionText"):SetAML("<P Font=\"CRB_InterfaceMedium\">" .. tOptionData.strChoiceDescription .. "</P>")

		-- Resize
		local nWidth, nHeight = wndCurr:FindChild("VoteOptionText"):SetHeightToContentHeight()
		local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
		wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(nHeight, nBottom) + 34) -- b is the minimum height for one line descriptions
		wndCurr:FindChild("VoteOptionArrangeVert"):ArrangeChildrenVert(1) -- If at minimum height this will vertical center align
	end
	self.wndMain:FindChild("VoteFrameScroll"):ArrangeChildrenVert(0)
	Sound.Play(Sound.PlayUIWindowPublicEventVoteOpen)
end

function PublicEventVote:OnOneSecTimer()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then return end

	local tVoteData = PublicEvent.GetActiveVote()
	if tVoteData then
		self.wndMain:FindChild("VoteTitle"):SetText(tVoteData.strTitle .. " (" .. math.floor(tVoteData.fTimeRemaining) .. ")")
	end
end

function PublicEventVote:OnPublicEventVoteTallied(nChoice)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then 
		return 
	end

	for key, wndCurr in pairs(self.wndMain:FindChild("VoteFrameScroll"):GetChildren()) do
		if wndCurr:FindChild("VoteOptionBtn"):GetData() == nChoice then
			wndCurr:FindChild("VoteOptionBtnCheck"):SetData(wndCurr:FindChild("VoteOptionBtnCheck"):GetData() + 1)
		end
	end
end

function PublicEventVote:OnVoteOptionBtn(wndHandler, wndControl) -- VoteOptionBtn, data is tOptionData
	if not PublicEvent.CanVote() or not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then 
		return 
	end

	PublicEvent.CastVote(wndHandler:GetData())
	wndHandler:FindChild("VoteOptionBtnCheck"):Show(true)
	-- OnPublicEventVoteTallied should get fired and update this

	-- Disable all other buttons
	for key, wndCurr in pairs(self.wndMain:FindChild("VoteFrameScroll"):GetChildren()) do
		if wndCurr ~= wndHandler then
			wndCurr:FindChild("VoteOptionBtn"):Enable(false)
		end
	end
	
	self.nSelectedVote = wndHandler:GetData()
end

function PublicEventVote:OnPublicEventVoteEnded(nWinner)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end

	local bResultFound = false
	for key, wndCurr in pairs(self.wndMain:FindChild("VoteFrameScroll"):GetChildren()) do
		if wndCurr:FindChild("VoteOptionBtn"):GetData() == nWinner then
			bResultFound = true
			wndCurr:FindChild("VoteOptionBtn"):Enable(false)
			
			local tVoteInfo =
			{
				["name"] = Apollo.GetString("PublicEventVote_Votes"),
				["count"] = wndCurr:FindChild("VoteOptionBtnCheck"):GetData(),
			}
			wndCurr:FindChild("VoteOptionText"):SetAML("<P Font=\"CRB_InterfaceMedium_B\">" .. String_GetWeaselString(Apollo.GetString("PublicEventVote_Winner"), tVoteInfo) .. "</P>")
		else
			wndCurr:Destroy()
		end
	end

	if not bResultFound then
		self.wndMain:FindChild("VoteDescription"):SetText(Apollo.GetString("PublicEventVote_NonePicked"))
	end

	self.wndMain:Show(true)
	self.wndMain:FindChild("VoteTitle"):SetText(Apollo.GetString("PublicEventVote_VotingComplete"))
	self.wndMain:FindChild("VoteFrameScroll"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("VoteFrameScroll"):RecalculateContentExtents()
	self.wndMain:FindChild("VoteFrameScroll"):SetVScrollPos(0)

	Apollo.StopTimer("VoteUpdateTimer")
	Apollo.CreateTimer("HideWinnerTimer", 5.0, false)
	Apollo.StartTimer("HideWinnerTimer")
	
	self.nSelectedVote = nil
	
	Sound.Play(Sound.PlayUIWindowPublicEventVoteVotingEnd)
end

function PublicEventVote:OnVoteFrameHideBtn(wndHandler, wndControl)
	self.wndMain:Destroy()
	Sound.Play(Sound.PlayUIWindowPublicEventVoteClose)
end

local PublicEventVoteInst = PublicEventVote:new()
PublicEventVoteInst:Init()
