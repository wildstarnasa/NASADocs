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
    return o
end

function Guild:Init()
    Apollo.RegisterAddon(self)
end

function Guild:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildMain.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	Apollo.RegisterEventHandler("InterfaceOptionsLoaded", "OnDocumentReady", self)
end

function Guild:OnDocumentReady()
	if  self.xmlDoc == nil or not g_InterfaceOptionsLoaded then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_InitializeGuild", "OnGenericEvent_InitializeGuild", self)
	Apollo.RegisterEventHandler("GenericEvent_DestroyGuild", 	"OnGenericEvent_DestroyGuild", self)
	Apollo.RegisterEventHandler("GenericEvent_ClearGuild",		"OnGenericEvent_ClearGuild", self)
	Apollo.RegisterEventHandler("GuildChange", 					"OnGuildChange", self) -- notification that a guild was added / removed.
	Apollo.RegisterEventHandler("GuildInvite", 					"OnGuildInvite", self) -- notification you got a guild/circle invite
	Apollo.RegisterEventHandler("GuildResult", 					"OnGuildResult", self) -- notification about an action that occured with the guild (Likely from self)

	Apollo.RegisterTimerHandler("RetryLoadingGuilds", 			"RetryLoadingGuilds", self)
end

function Guild:OnGenericEvent_InitializeGuild(wndParent)
	if self.wndMain and self.wndMain:IsValid() then
		return
	end

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildMainForm", wndParent, self)
    self.wndOptions = self.wndMain:FindChild("TopTabContainer")

	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.nLastSelection = -1
	self.tContent = {}
	for idx = 1, 3 do
		self.tContent[idx] = self.wndMain:FindChild("ContentWnd_" .. idx)
		self.tContent[idx]:Show(false)
	end

	Event_FireGenericEvent("Guild_WindowLoaded")
	Event_FireGenericEvent("GuildMainLoaded")

	self.wndMain:Show(true)
	self:OnGuildOn()
end

function Guild:OnGenericEvent_DestroyGuild()
	if self.wndMain and self.wndMain:IsValid() then
		Event_FireGenericEvent("GuildWindowHasBeenClosed")
		self.wndMain:Destroy()
	end
end

function Guild:OnGenericEvent_ClearGuild()
	if self.wndMain and self.wndMain:IsValid() then
		Event_FireGenericEvent("GuildWindowHasBeenClosed")
	end
end

function Guild:OnGuildOn()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local bGuildTableIsEmpty = true
	for key, guildData in pairs(GuildLib.GetGuilds()) do
		if guildData:GetType() == GuildLib.GuildType_Guild then
			bGuildTableIsEmpty = false
			self.wndMain:SetData(guildData)
		end
	end

	if bGuildTableIsEmpty or GuildLib:IsLoading() then
		self.wndMain:FindChild("JoinContainer"):Show(true)
		self.wndMain:FindChild("GuildOption1"):Enable(false)
		self.wndMain:FindChild("GuildOption2"):Enable(false)
		self.wndMain:FindChild("GuildOption3"):Enable(false)
		self.wndMain:Show(true)

		Apollo.CreateTimer("RetryLoadingGuilds", 1.0, false)
		Apollo.StartTimer("RetryLoadingGuilds")
		return
	end

	self.wndMain:FindChild("JoinContainer"):Show(false)
	self.wndMain:FindChild("GuildOption1"):Enable(true)
	self.wndMain:FindChild("GuildOption2"):Enable(true)
	self.wndMain:FindChild("GuildOption3"):Enable(true)

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
	Apollo.StopTimer("RetryLoadingGuilds")
	self:OnGuildOn()
end

function Guild:ToggleInfo()
	self.wndMain:Show(true)
	self.wndMain:ToFront()
	self.wndOptions:SetRadioSel("GuildOptions", 1)
	self:OnGuildOptionCheck()
end

function Guild:ToggleRoster()
	self.wndMain:Show(true)
	self.wndMain:ToFront()
	self.wndOptions:SetRadioSel("GuildOptions", 2)
	self:OnGuildOptionCheck()
end

function Guild:TogglePerks()
	self.wndMain:Show(true)
	self.wndMain:ToFront()
	self.wndOptions:SetRadioSel("GuildOptions", 3)
	self:OnGuildOptionCheck()
end

function Guild:OnGuildOptionCheck(wndHandler, wndControl, bToggledFromCall, tUserData)
	local nGuildOption = self.wndOptions:GetRadioSel("GuildOptions")
	if nGuildOption ~= 1 then -- the player's switched to anything but Info (which auto-selects)
		Event_FireGenericEvent("Guild_TabChanged") -- stops anything going on in the window
	end

	for idx = 1, 3 do
		self.tContent[idx]:Show(false)
	end

	if nGuildOption == 1 then
		Event_FireGenericEvent("Guild_ToggleInfo", self.tContent[nGuildOption])
	elseif nGuildOption == 2 then
		Event_FireGenericEvent("Guild_ToggleRoster", self.tContent[nGuildOption])
	elseif nGuildOption == 3 then
		Event_FireGenericEvent("Guild_TogglePerks", self.tContent[nGuildOption])
	end

	self.nLastSelection = nGuildOption -- Save last selection
	self.tContent[nGuildOption]:Show(true)

	if not self.wndMain:IsVisible() then -- in case it's responding to a key or Datachron toggle
		self.wndMain:Show(true)
		self.wndMain:ToFront()
	end
end

-----------------------------------------------------------------------------------------------
-- Guild Invite Window
-----------------------------------------------------------------------------------------------

function Guild:OnGuildInvite( strGuildName, strInvitorName, guildType, tFlags )
	if guildType ~= GuildLib.GuildType_Guild then return end

	if self.wndGuildInvite ~= nil then
		self.wndGuildInvite:Destroy()
	end

	if self:FilterRequest(strInvitorName) then
		self.wndGuildInvite = Apollo.LoadForm(self.xmlDoc, "GuildInviteConfirmation", nil, self)
		local nLeft, nTop, nRight, nBottom = self.wndGuildInvite:FindChild("GuildInviteLabel"):GetAnchorOffsets()

		if tFlags.bTax then
			self.wndGuildInvite:FindChild("GuildInviteTaxes"):Show(true)
			self.wndGuildInvite:FindChild("GuildInviteLabel"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + 61)
		else
			self.wndGuildInvite:FindChild("GuildInviteTaxes"):Show(false)
			self.wndGuildInvite:FindChild("GuildInviteLabel"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + 96)
		end

		self.wndGuildInvite:FindChild("GuildInviteLabel"):SetText(String_GetWeaselString(Apollo.GetString("Guild_IncomingInvite"), strGuildName, strInvitorName))
		--self.wndGuildInvite:FindChild("GuildInviteTaxes"):Show( tFlags.bTax )
		self.wndGuildInvite:ToFront()
	else
		GuildLib.Decline()
	end
end

function Guild:OnGuildInviteAccept(wndHandler, wndControl)
	GuildLib.Accept()
	if self.wndGuildInvite then
		self.wndGuildInvite:Destroy()
	end
end

function Guild:OnGuildInviteDecline() -- This can come from a variety of sources
	GuildLib.Decline()
	if self.wndGuildInvite then
		self.wndGuildInvite:Destroy()
	end
end

function Guild:OnFilterBtn(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bFilterGuildInvite = wndHandler:IsChecked()
end

-----------------------------------------------------------------------------------------------
-- OnGuildResult
-----------------------------------------------------------------------------------------------

function Guild:OnGuildResult(guildCurr, strName, nRank, eResult)
	if eResult == GuildLib.GuildResult_PendingInviteExpired and self.wndGuildInvite ~= nil then
		self.wndGuildInvite:Destroy()
	end
end

-- Feedback Messages
-----------------------------------------------------------------------------------------------
function Guild:OnGuildChange()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	-- a guild was added or removed.
	for idx = 1, 3 do
		self.tContent[idx]:Show(false)
	end
	
	self.nLastSelection = -1

	self.wndMain:Show(false)
	Event_FireGenericEvent("GuildWindowHasBeenClosed")
	self:OnGuildOn()
end

function Guild:FilterRequest(strInvitor)
	if not g_InterfaceOptions.Carbine.bFilterGuildInvite then
		
		return true
	end
	
	local bPassedFilter = false
	
	local tRelationships = GameLib.SearchRelationshipStatusByCharacterName(strInvitor)
	if tRelationships and (tRelationships.tFriend or tRelationships.tAccountFriend or tRelationships.tGuilds or tRelationships.nGuildIndex) then
		bPassedFilter = true
	end
	
	return bPassedFilter
end

local GuildInst = Guild:new()
GuildInst:Init()
