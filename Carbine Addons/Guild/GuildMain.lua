-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildMain
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

local Guild = {}


function Guild:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tWndRefs = {}

    return o
end

function Guild:Init()
    Apollo.RegisterAddon(self)
end

function Guild:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Guild:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_InitializeGuild", "OnGenericEvent_InitializeGuild", self)
	Apollo.RegisterEventHandler("GenericEvent_DestroyGuild", 	"OnGenericEvent_DestroyGuild", self)
	Apollo.RegisterEventHandler("GenericEvent_ClearGuild",		"OnGenericEvent_ClearGuild", self)
	Apollo.RegisterEventHandler("GuildChange", 					"OnGuildChange", self) -- notification that a guild was added / removed.
	Apollo.RegisterEventHandler("GuildInvite", 					"OnGuildInvite", self) -- notification you got a guild/circle invite
	Apollo.RegisterEventHandler("GuildResult", 					"OnGuildResult", self) -- notification about an action that occured with the guild (Likely from self)

end

function Guild:OnGenericEvent_InitializeGuild(wndParent)
	if self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		return
	end

    self.tWndRefs.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildMainForm", wndParent, self)
    self.tWndRefs.wndOptions = self.tWndRefs.wndMain:FindChild("TopTabContainer")

	if self.locSavedWindowLoc then
		self.tWndRefs.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.nLastSelection = -1
	self.tWndRefs.tContent = {}
	for idx = 1, 3 do
		self.tWndRefs.tContent[idx] = self.tWndRefs.wndMain:FindChild("ContentWnd_" .. idx)
		self.tWndRefs.tContent[idx]:Show(false)
	end

	Event_FireGenericEvent("Guild_WindowLoaded")
	Event_FireGenericEvent("GuildMainLoaded")

	self.tWndRefs.wndMain:Show(true)
	self:OnGuildOn()
end

function Guild:OnGenericEvent_DestroyGuild()
	if self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
		Event_FireGenericEvent("GuildWindowHasBeenClosed")
	end
end

function Guild:OnGenericEvent_ClearGuild()
	if self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		Event_FireGenericEvent("GuildWindowHasBeenClosed")
	end
end

function Guild:OnGuildOn()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	local bGuildTableIsEmpty = true
	for key, guildData in pairs(GuildLib.GetGuilds()) do
		if guildData:GetType() == GuildLib.GuildType_Guild then
			bGuildTableIsEmpty = false
			self.tWndRefs.wndMain:SetData(guildData)
		end
	end

	if bGuildTableIsEmpty or GuildLib:IsLoading() then
		self.tWndRefs.wndMain:FindChild("JoinContainer"):Show(true)
		self.tWndRefs.wndMain:FindChild("GuildOption1"):Enable(false)
		self.tWndRefs.wndMain:FindChild("GuildOption2"):Enable(false)
		self.tWndRefs.wndMain:FindChild("GuildOption3"):Enable(false)
		self.tWndRefs.wndMain:Show(true)

		self.timerLoadGuild	= ApolloTimer.Create(1.0, false, "RetryLoadingGuilds", self)
		return
	end

	self.tWndRefs.wndMain:FindChild("JoinContainer"):Show(false)
	self.tWndRefs.wndMain:FindChild("GuildOption1"):Enable(true)
	self.tWndRefs.wndMain:FindChild("GuildOption2"):Enable(true)
	self.tWndRefs.wndMain:FindChild("GuildOption3"):Enable(true)

	if self.nLastSelection == nil or self.nLastSelection == 1 then 
		self:ToggleInfo()
	elseif self.nLastSelection == 2 then 
		self:ToggleRoster()
	elseif self.nLastSelection == 3 then 
		self:TogglePerks()
	else 
		self:ToggleInfo() 
	end
end

function Guild:RetryLoadingGuilds()
	self:OnGuildOn()
end

function Guild:ToggleInfo()
	self.tWndRefs.wndMain:Show(true)
	self.tWndRefs.wndMain:ToFront()
	self.tWndRefs.wndOptions:SetRadioSel("GuildOptions", 1)
	self:OnGuildOptionCheck()
end

function Guild:ToggleRoster()
	self.tWndRefs.wndMain:Show(true)
	self.tWndRefs.wndMain:ToFront()
	self.tWndRefs.wndOptions:SetRadioSel("GuildOptions", 2)
	self:OnGuildOptionCheck()
end

function Guild:TogglePerks()
	self.tWndRefs.wndMain:Show(true)
	self.tWndRefs.wndMain:ToFront()
	self.tWndRefs.wndOptions:SetRadioSel("GuildOptions", 3)
	self:OnGuildOptionCheck()
end

function Guild:OnGuildOptionCheck(wndHandler, wndControl, bToggledFromCall, tUserData)
	local nGuildOption = self.tWndRefs.wndOptions:GetRadioSel("GuildOptions")
	if nGuildOption ~= 1 then -- the player's switched to anything but Info (which auto-selects)
		Event_FireGenericEvent("Guild_TabChanged") -- stops anything going on in the window
	end

	for idx = 1, 3 do
		self.tWndRefs.tContent[idx]:Show(false)
	end

	if nGuildOption == 1 then
		Event_FireGenericEvent("Guild_ToggleInfo", self.tWndRefs.tContent[nGuildOption])
	elseif nGuildOption == 2 then
		Event_FireGenericEvent("Guild_ToggleRoster", self.tWndRefs.tContent[nGuildOption])
	elseif nGuildOption == 3 then
		Event_FireGenericEvent("Guild_TogglePerks", self.tWndRefs.tContent[nGuildOption])
	end

	self.nLastSelection = nGuildOption -- Save last selection
	self.tWndRefs.tContent[nGuildOption]:Show(true)

	if not self.tWndRefs.wndMain:IsVisible() then -- in case it's responding to a key or Datachron toggle
		self.tWndRefs.wndMain:Show(true)
		self.tWndRefs.wndMain:ToFront()
	end
end

-----------------------------------------------------------------------------------------------
-- Guild Invite Window
-----------------------------------------------------------------------------------------------

function Guild:OnGuildInvite( strGuildName, strInvitorName, eGuildType, tFlags )
	if eGuildType ~= GuildLib.GuildType_Guild then 
		return 
	end

	if self.wndGuildInvite ~= nil and self.wndGuildInvite:IsValid() then
		self.wndGuildInvite:Destroy()
	end

	self.wndGuildInvite = Apollo.LoadForm(self.xmlDoc, "GuildInviteConfirmation", nil, self)
	local nLeft, nTop, nRight, nBottom = self.wndGuildInvite:FindChild("GuildInviteLabel"):GetAnchorOffsets()

	if tFlags.bTax then
		self.wndGuildInvite:FindChild("GuildInviteTaxes"):Show(true)
		self.wndGuildInvite:FindChild("GuildInviteLabel"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + 105)
	else
		self.wndGuildInvite:FindChild("GuildInviteTaxes"):Show(false)
		self.wndGuildInvite:FindChild("GuildInviteLabel"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + 141)
	end

	self.wndGuildInvite:FindChild("GuildInviteLabel"):SetText(String_GetWeaselString(Apollo.GetString("Guild_IncomingInvite"), strGuildName, strInvitorName))
	self.wndGuildInvite:ToFront()
end

function Guild:OnGuildInviteAccept(wndHandler, wndControl)
	GuildLib.Accept()
	if self.wndGuildInvite then
		self.wndGuildInvite:Destroy()
		self.wndGuildInvite = nil
	end
end

function Guild:OnReportGuildInviteSpamBtn(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_ReportPlayerGuildInvite")
	--self:OnGuildInviteDecline()
	self.wndGuildInvite:Destroy()
	self.wndGuildInvite = nil
end

function Guild:OnDecline()
	if self.wndGuildInvite then
		self.wndGuildInvite:Destroy()
		self.wndGuildInvite = nil
	end
	GuildLib.Decline()
end

-----------------------------------------------------------------------------------------------
-- OnGuildResult
-----------------------------------------------------------------------------------------------

function Guild:OnGuildResult(guildCurr, strName, nRank, eResult)
	if eResult == GuildLib.GuildResult_PendingInviteExpired and self.wndGuildInvite ~= nil then
		self.wndGuildInvite:Destroy()
		self.wndGuildInvite = nil
	end
end

-- Feedback Messages
-----------------------------------------------------------------------------------------------
function Guild:OnGuildChange()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	-- a guild was added or removed.
	for idx = 1, 3 do
		self.tWndRefs.tContent[idx]:Show(false)
	end
	
	self.nLastSelection = -1

	self.tWndRefs.wndMain:Show(false)
	Event_FireGenericEvent("GuildWindowHasBeenClosed")
	self:OnGuildOn()
end

local GuildInst = Guild:new()
GuildInst:Init()
