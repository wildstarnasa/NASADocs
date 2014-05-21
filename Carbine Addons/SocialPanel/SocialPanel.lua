-----------------------------------------------------------------------------------------------
-- Client Lua Script for SocialPanel
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "FriendshipLib"

local SocialPanel = {}
local knMaxNumberOfCircles = 5

function SocialPanel:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function SocialPanel:Init()
    Apollo.RegisterAddon(self)
end

function SocialPanel:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("SocialPanel.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function SocialPanel:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 			"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 		"OnTutorial_RequestUIAnchor", self)

	Apollo.RegisterEventHandler("EventGeneric_OpenSocialPanel", 		"OnToggleSocialWindow", self)
	Apollo.RegisterEventHandler("ToggleSocialWindow", 					"OnToggleSocialWindow", self)

	-- Open to Right Tab
	Apollo.RegisterEventHandler("ToggleGuild", 							"OnToggleGuild", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenGuildPanel", 			"OnToggleGuild", self)
	Apollo.RegisterEventHandler("InvokeNeighborsList", 					"OnInvokeNeighborsList", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenNeighborsPanel", 		"OnInvokeNeighborsList", self)
	Apollo.RegisterEventHandler("InvokeFriendsList", 					"OnInvokeFriendsList", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenFriendsPanel", 		"OnInvokeFriendsList", self)

	-- Only if already visible
	Apollo.RegisterEventHandler("HousingBasicsUpdated",					"FullRedrawIfVisible", self)
	Apollo.RegisterEventHandler("GuildChange", 							"FullRedrawIfVisible", self)  -- notification that a guild was added / removed.
	Apollo.RegisterEventHandler("GuildName", 							"FullRedrawIfVisible", self) -- notification that the guild name has changed.

	Apollo.RegisterTimerHandler("RetryLoadingSocialPanel", 				"FullRedrawIfVisible", self)
	Apollo.CreateTimer("RetryLoadingSocialPanel", 1.0, false)
	Apollo.StartTimer("RetryLoadingSocialPanel")
	
	Apollo.RegisterTimerHandler("RecalculateInvitesTimer",				"CalcFriendInvites", self)
	Apollo.CreateTimer("RecalculateInvitesTimer", 0.1, false)
	Apollo.StopTimer("RecalculateInvitesTimer")

	-- Friend Events
	Apollo.RegisterEventHandler("FriendshipAccountInvitesRecieved",  	"OnFriendshipInviteChange", self)
    Apollo.RegisterEventHandler("FriendshipAccountInviteRemoved",   	"OnFriendshipInviteChange", self)
	Apollo.RegisterEventHandler("FriendshipInvitesRecieved",  			"OnFriendshipInviteChange", self)
    Apollo.RegisterEventHandler("FriendshipInviteRemoved",   			"OnFriendshipInviteChange", self)
	Apollo.RegisterEventHandler("EventGeneric_FriendInviteSeen", 		"OnFriendshipInviteChange", self)
	Apollo.RegisterEventHandler("FriendshipAccountDataUpdate",  		"CalcFriendInvites", self)
	Apollo.RegisterEventHandler("FriendshipUpdateOnline", 				"CalcFriendInvites", self)

    self.wndMain = nil
end

function SocialPanel:OnToggleSocialWindow(strArg) -- 1st Arg may be objects from code and such
	self:Initialize()

	if self.wndMain:IsShown() then
		self.wndMain:Close()
	else
		self.wndMain:Invoke()
		self:FullyDrawSplashScreen()

		if strArg and type(strArg) == "string" and string.len(strArg) > 0 then
			self.wndContactsFrame:Show(strArg == "ContactsFrame")
			self.wndNeighborsFrame:Show(strArg == "NeighborsFrame")
			self.wndGuildFrame:Show(strArg == "GuildFrame")
			self.wndCirclesFrame:Show(strArg == "CirclesFrame")

			Event_FireGenericEvent("GenericEvent_DestroyFriends")
			Event_FireGenericEvent("GenericEvent_DestroyNeighbors")
			Event_FireGenericEvent("GenericEvent_DestroyGuild")
			Event_FireGenericEvent("GenericEvent_DestroyCircles")

			if strArg == "ContactsFrame" then
				Event_FireGenericEvent("GenericEvent_InitializeFriends", self.wndContactsFrame)
			elseif strArg == "NeighborsFrame" then
				Event_FireGenericEvent("GenericEvent_InitializeNeighbors", self.wndNeighborsFrame)
			elseif strArg == "GuildFrame" then
				Event_FireGenericEvent("GenericEvent_InitializeGuild", self.wndGuildFrame)
			end
		end
	end
end

function SocialPanel:OnToggleGuild()
	self:OnToggleSocialWindow("GuildFrame")
end

function SocialPanel:OnInvokeNeighborsList()
	local bIsResidenceOwner = HousingLib.IsResidenceOwner()
	if bIsResidenceOwner then
		self:OnToggleSocialWindow("NeighborsFrame")
	else
		self:OnToggleSocialWindow()
	end
end

function SocialPanel:OnInvokeFriendsList()
	self:OnToggleSocialWindow("ContactsFrame")
end

function SocialPanel:OnFriendshipInviteChange(tInvite)
	self:FullRedrawIfVisible()
	Apollo.StartTimer("RecalculateInvitesTimer")
end

function SocialPanel:FullRedrawIfVisible()
	if self.wndMain and self.wndMain:IsShown() then
		self:FullyDrawSplashScreen()
	end
end

-----------------------------------------------------------------------------------------------
-- Main Redraw
-----------------------------------------------------------------------------------------------

function SocialPanel:Initialize()
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "SocialPanelForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_Social")})
			
		self.wndMain:FindChild("SplashFriendsBtnAlert"):Show(false, true)

		self.wndContactsFrame	= self.wndMain:FindChild("ContactsFrame")
		self.wndNeighborsFrame	= self.wndMain:FindChild("NeighborsFrame")
		self.wndGuildFrame		= self.wndMain:FindChild("GuildFrame")
		self.wndCirclesFrame	= self.wndMain:FindChild("CirclesFrame")

		self.wndMain:FindChild("SplashFriendsBtn"):AttachWindow(self.wndContactsFrame)
		self.wndMain:FindChild("SplashNeighborsBtn"):AttachWindow(self.wndNeighborsFrame)
		self.wndMain:FindChild("SplashGuildBtn"):AttachWindow(self.wndGuildFrame)
		self.wndMain:FindChild("SplashCircleBtn"):AttachWindow(self.wndCirclesFrame)

		--TODO: If we save tab settings then we need to update default load
		Event_FireGenericEvent("GenericEvent_InitializeFriends", self.wndContactsFrame)

		if self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
		
		self:CalcFriendInvites()
	end
end

function SocialPanel:FullyDrawSplashScreen(bHide)
	self:Initialize()

	self.wndMain:FindChild("SplashCircleItemContainer"):DestroyChildren() -- TODO: See if we can remove this

	-- Circles
	local nNumberOfCircles = 0
	local arGuilds = GuildLib.GetGuilds()
	table.sort(arGuilds, function(a,b) return (self:HelperSortCirclesChannelOrder(a,b)) end)
	for key, guildCurr in pairs(arGuilds) do
		if guildCurr:GetType() == GuildLib.GuildType_Circle then
			nNumberOfCircles = nNumberOfCircles + 1

			local wndCurr = Apollo.LoadForm(self.xmlDoc, "SplashCirclesPickerItem", self.wndMain:FindChild("SplashCircleItemContainer"), self)
			wndCurr:FindChild("SplashCirclesPickerBtn"):SetData(guildCurr)
			wndCurr:FindChild("SplashCirclesPickerBtnText"):SetText(guildCurr:GetName())
		end
	end

	-- Circle Add Btn
	if nNumberOfCircles < knMaxNumberOfCircles then
		Apollo.LoadForm(self.xmlDoc, "SplashCirclesAddItem", self.wndMain:FindChild("SplashCircleItemContainer"), self)
		nNumberOfCircles = nNumberOfCircles + 1
	end

	-- Circle Blank Btn
	for idx = nNumberOfCircles + 1, knMaxNumberOfCircles do -- Fill in the rest with blanks
		Apollo.LoadForm(self.xmlDoc, "SplashCirclesUnusedItem", self.wndMain:FindChild("SplashCircleItemContainer"), self)
	end
	self.wndMain:FindChild("SplashCircleItemContainer"):ArrangeChildrenHorz(0)

	-- Neighbours
	local bIsResidenceOwner = HousingLib.IsResidenceOwner()
	self.wndMain:FindChild("SplashNeighborsBtn"):Show(bIsResidenceOwner)
	self.wndMain:FindChild("SplashNeighborsDisabledBtn"):Show(not bIsResidenceOwner)

	-- Retry, in case Guild Lib is still loading
	Apollo.StopTimer("RetryLoadingSocialPanel")
	if nNumberOfCircles > 0 and GuildLib:IsLoading() and self.wndMain:IsShown() then
		Apollo.StartTimer("RetryLoadingSocialPanel")
	end

	self.wndMain:Show(true)
	Event_ShowTutorial(GameLib.CodeEnumTutorial.General_Social)
end

function SocialPanel:HelperSortCirclesChannelOrder(guildLhs, guildRhs)
	local chanLhs = guildLhs and guildLhs:GetChannel()
	local chanRhs = guildRhs and guildRhs:GetChannel()
	local strCommandLhs = chanLhs and chanLhs:GetCommand() or ""
	local strCommandRhs = chanRhs and chanRhs:GetCommand() or ""
	return strCommandLhs < strCommandRhs
end

function SocialPanel:OnCloseBtn(wndHandler, wndControl)
	if wndHandler == wndControl then
		Apollo.StopTimer("RecalculateInvitesTimer")
		Apollo.StopTimer("RetryLoadingSocialPanel")
		Event_FireGenericEvent("SocialWindowHasBeenClosed")
		self.wndMain:Close()
	end
end

---------------------------------------------------------------------------------------------------
-- SocialPanelForm Functions
---------------------------------------------------------------------------------------------------

function SocialPanel:OnSplashContactsCheck(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	Event_FireGenericEvent("GenericEvent_InitializeFriends", self.wndContactsFrame)
end

function SocialPanel:OnSplashContactsUncheck( wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_DestroyFriends")
end

function SocialPanel:OnSplashNeighborCheck( wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_InitializeNeighbors", self.wndNeighborsFrame)
end

function SocialPanel:OnSplashNeighborUncheck( wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_DestroyNeighbors")
end

function SocialPanel:OnSplashGuildCheck( wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_InitializeGuild", self.wndGuildFrame)
end

function SocialPanel:OnSplashGuildUncheck( wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_DestroyGuild")
end

function SocialPanel:OnCircleItemCheck( wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_InitializeCircles", self.wndCirclesFrame, wndHandler:GetData())
end

function SocialPanel:OnCircleItemUncheck( wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_DestroyCircles")
end

-- Special Circle Handlers
function SocialPanel:OnSplashCirclesAddBtn(wndHandler, wndControl)
	Event_FireGenericEvent("EventGeneric_OpenCircleRegistrationPanel", self.wndMain)
end

function SocialPanel:OnSplashCirclesCheck( wndHandler, wndControl)
	self.wndMain:FindChild("SplashCircleItemContainerFrame"):Show(true)
end

function SocialPanel:OnSplashCirclesUncheck( wndHandler, wndControl)
	self.wndMain:FindChild("SplashCircleItemContainerFrame"):Show(false)
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------

function SocialPanel:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.Social or not self.wndMain or not self.wndMain:IsValid() then
		return 
	end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
	
	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

---------------------------------------------------------------------------------------------------
-- Interface Menu Interaction
---------------------------------------------------------------------------------------------------

function SocialPanel:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Social"), {"ToggleSocialWindow", "Social", "Icon_Windows32_UI_CRB_InterfaceMenu_Social"})
	self:CalcFriendInvites()
end

function SocialPanel:CalcFriendInvites()
	local nUnseenFriendInviteCount = 0
	for idx, tInvite in pairs(FriendshipLib.GetInviteList()) do
		if tInvite.bIsNew then
			nUnseenFriendInviteCount = nUnseenFriendInviteCount + 1
		end
	end
	for idx, tInvite in pairs(FriendshipLib.GetAccountInviteList()) do
		if tInvite.bIsNew then
			nUnseenFriendInviteCount = nUnseenFriendInviteCount + 1
		end
	end

	local nOnlineFriendCount = 0
	for idx, tFriend in pairs(FriendshipLib.GetList()) do
		if tFriend.fLastOnline == 0 then
			nOnlineFriendCount = nOnlineFriendCount + 1
		end
	end
	for idx, tFriend in pairs(FriendshipLib.GetAccountList()) do
		if tFriend.arCharacters then
			nOnlineFriendCount = nOnlineFriendCount + 1
		end
	end

	local tParams = nUnseenFriendInviteCount > 0 and {true, nil, nUnseenFriendInviteCount} or {false, nil, nOnlineFriendCount}
	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", Apollo.GetString("InterfaceMenu_Social"), tParams)
	
	if self.wndMain then
		local wndFriendInviteCounter = self.wndMain:FindChild("HeaderButtons:SplashFriendsBtn:SplashFriendsBtnAlert")
		wndFriendInviteCounter:FindChild("SplashFriendsBtnItemCount"):SetText(nUnseenFriendInviteCount)
		wndFriendInviteCounter:Show(nUnseenFriendInviteCount > 0)
	end

	return nUnseenFriendInviteCount
end

local SocialPanelInst = SocialPanel:new()
SocialPanelInst:Init()
