-----------------------------------------------------------------------------------------------
-- Client Lua Script for RaidFrameReady
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local RaidFrameReady = {}

local knReadyCheckTimeout = 14 -- in seconds
local knReadyCheckcooldown = 16 -- in seconds

function RaidFrameReady:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RaidFrameReady:Init()
    Apollo.RegisterAddon(self)
end

function RaidFrameReady:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RaidFrameReady.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function RaidFrameReady:OnDocumentReady()
	Apollo.RegisterSlashCommand("readycheck",						"OnSlashReadyCheck", self)
	Apollo.RegisterEventHandler("Group_ReadyCheck",					"OnGroup_ReadyCheck", self)
	Apollo.RegisterEventHandler("CharacterCreated", 				"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("Group_ReadyCheckCooldownExpired", 	"DestroyAll", self)

	Apollo.RegisterTimerHandler("Raid_OneSecTimer", 				"OnRaid_OneSecTimer", self)
	Apollo.CreateTimer("Raid_OneSecTimer", 0.25, true)
	Apollo.StopTimer("Raid_OneSecTimer")

	Apollo.RegisterTimerHandler("Raid_ReadyCheckTimeout", 			"OnRaid_ReadyCheckTimeout", self)
	Apollo.CreateTimer("Raid_ReadyCheckTimeout", knReadyCheckTimeout, false)
	Apollo.StopTimer("Raid_ReadyCheckTimeout")

	Apollo.RegisterTimerHandler("Raid_ReadyCheckMaxTime", 			"DestroyAll", self)
	Apollo.CreateTimer("Raid_ReadyCheckMaxTime", knReadyCheckcooldown, false)
	Apollo.StopTimer("Raid_ReadyCheckMaxTime")

	self.wndReadyResults = nil
	self.wndReadyCheckPopup = nil
	self.nNumReadyCheckResponses = -1 -- -1 means no check, 0 and higher means there is a check

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self:OnCharacterCreated()
	end
end

function RaidFrameReady:OnCharacterCreated()
	-- If a player reloads ui during a ready check, and one is active, we'll just auto fail instead of waiting for a time out
	local bSomeoneHasSetReady = false
	local bPersonalHasSetReady = false
	local strMyName = GameLib.GetPlayerUnit():GetName()
	for idx = 1, GroupLib.GetMemberCount() do
		local tMemberData = GroupLib.GetGroupMember(idx)
		if tMemberData.strCharacterName == strMyName then
			bPersonalHasSetReady = tMemberData.bHasSetReady
		else
			bSomeoneHasSetReady = tMemberData.bHasSetReady
		end
	end

	local bReadyCheckOnCooldown = GroupLib.IsReadyCheckOnCooldown()
	if (bReadyCheckOnCooldown or bSomeoneHasSetReady) and not bPersonalHasSetReady then
		GroupLib.SetReady(false)
	end
end

function RaidFrameReady:OnSlashReadyCheck()
	GroupLib.ReadyCheck(Apollo.GetString("RaidFrame_AreYouReady")) -- Sanitized in code
end

function RaidFrameReady:OnGroup_ReadyCheck(nMemberIdx, strMessage) -- This displays the "Are you ready?" pop up
	-- Create the "Are you ready?" pop up
	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		self.wndReadyCheckPopup:Destroy()
	end

	self.wndReadyCheckPopup = Apollo.LoadForm(self.xmlDoc, "ReadyCheckPopup", nil, self)
	self.wndReadyCheckPopup:SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:FindChild("ReadyCheckNoBtn"):SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:FindChild("ReadyCheckYesBtn"):SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:FindChild("ReadyCheckCloseBtn"):SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:Invoke()

	-- Format data inside the "Are you ready?" pop up
	local tMember = GroupLib.GetGroupMember(nMemberIdx)
	local strFormatting = "<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloBodyHighlight\" Align=\"Center\">"
	local strInitiator = String_GetWeaselString(Apollo.GetString("RaidFrame_ReadyCheckStarted"), tMember and tMember.strCharacterName or Apollo.GetString("RaidFrame_TheRaid"))
	self.wndReadyCheckPopup:FindChild("ReadyCheckMessage"):SetAML(strFormatting..strInitiator.."<P TextColor=\"0\">.</P>"..strFormatting..strMessage.."</P></P>")
	self.wndReadyCheckPopup:FindChild("ReadyCheckMessage"):SetHeightToContentHeight()
	self.wndReadyCheckPopup:FindChild("ReadyCheckScroll"):ArrangeChildrenVert(1)

	-- Also Create the results of everyone's ready check
	if self.wndReadyResults and self.wndReadyResults:IsValid() then
		self.wndReadyResults:Destroy()
	end
	self.wndReadyResults = Apollo.LoadForm(self.xmlDoc, "ReadyCheckResults", nil, self)

	Apollo.StartTimer("Raid_OneSecTimer")
	Apollo.StartTimer("Raid_ReadyCheckTimeout")
	Apollo.StartTimer("Raid_ReadyCheckMaxTime")
	self.nNumReadyCheckResponses = 0
end

function RaidFrameReady:OnRaid_OneSecTimer()
	-- Early exit and close if we're done the check
	if self.nNumReadyCheckResponses == -1 or not self.wndReadyResults or not self.wndReadyResults:IsValid() then
		return
	end

	local nGroupMemberCount = GroupLib.GetMemberCount()
	if nGroupMemberCount == 0 then
		return
	end

	-- If active, recount entirely
	local nYesResponses = 0
	self.nNumReadyCheckResponses = 0
	for idx = 1, nGroupMemberCount do
		local tMemberData = GroupLib.GetGroupMember(idx)
		if tMemberData.bHasSetReady then -- Has clicked 1 of the 2 buttons (Can be Yes or No though)
			self.nNumReadyCheckResponses = self.nNumReadyCheckResponses + 1 -- Can use tMemberData.bReady to determine if they clicked Yes or No
			nYesResponses = nYesResponses + (tMemberData.bReady and 1 or 0)
		end
	end

	local strNoResponseFull = String_GetWeaselString(Apollo.GetString("RaidFrame_NoReadyResponse"), self:HelperBuildNotReadyString())
	local bNeedToShrinkText = Apollo.GetTextWidth("CRB_InterfaceSmall", strNoResponseFull) >self.wndReadyResults:FindChild("ReadyCheckResultsNoResponse"):GetWidth()	
	self.wndReadyResults:SetTooltip(strNoResponseFull)
	self.wndReadyResults:FindChild("ReadyCheckResultsNoResponse"):SetText(bNeedToShrinkText and string.sub(strNoResponseFull, 0, 30).."..." or strNoResponseFull)
	self.wndReadyResults:FindChild("ReadyCheckResultsCount"):SetText(String_GetWeaselString(Apollo.GetString("CRB_NOutOfN"), nYesResponses, nGroupMemberCount))

	if self.nNumReadyCheckResponses == nGroupMemberCount then
		self:DestroyAll() -- Force and pretend the ready check just finished
	end
end

function RaidFrameReady:OnRaid_ReadyCheckTimeout() -- You took too long to reply
	Apollo.StopTimer("Raid_ReadyCheckTimeout")
	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		self.wndReadyCheckPopup:Destroy()
		self.wndReadyCheckPopup = nil
	end
end

function RaidFrameReady:OnReadyCheckResponse(wndHandler, wndControl) -- ReadyCheckYesBtn, ReadyCheckNoBtn
	if wndHandler == wndControl then
		GroupLib.SetReady(wndHandler:GetName() == "ReadyCheckYesBtn") -- TODO Quick Hack
	end

	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		self.wndReadyCheckPopup:Destroy()
		self.wndReadyCheckPopup = nil
	end
end

function RaidFrameReady:DestroyAll()
	if self.wndReadyResults and self.wndReadyResults:IsValid() then
		self.wndReadyResults:Destroy()
		self.wndReadyResults = nil
	end

	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		self.wndReadyCheckPopup:Destroy()
		self.wndReadyCheckPopup = nil
	end

	-- If it's not already finished, write what we have to chat log
	if self.nNumReadyCheckResponses >= 0 then
		local strNotReadyString = self:HelperBuildNotReadyString()
		local strFinal = strNotReadyString == "" and Apollo.GetString("RaidFrame_ReadyCheckSuccess") or String_GetWeaselString(Apollo.GetString("RaidFrame_ReadyCheckFail"), strNotReadyString)
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Party, strFinal, "")
	end

	self.nNumReadyCheckResponses = -1
	Apollo.StopTimer("Raid_OneSecTimer")
	Apollo.StopTimer("Raid_ReadyCheckTimeout")
	Apollo.StopTimer("Raid_ReadyCheckMaxTime")
end

function RaidFrameReady:HelperBuildNotReadyString()
	local strNotReadyList = ""
	for idx = 1, GroupLib.GetMemberCount() do
		local tMemberData = GroupLib.GetGroupMember(idx)
		if not tMemberData.bHasSetReady or not tMemberData.bReady then
			local strCurrName = tMemberData.strCharacterName
			strNotReadyList = strNotReadyList == "" and strCurrName or String_GetWeaselString(Apollo.GetString("RaidFrame_NotReadyList"), strNotReadyList, strCurrName)
		end
	end
	return strNotReadyList
end

local RaidFrameReadyInst = RaidFrameReady:new()
RaidFrameReadyInst:Init()
