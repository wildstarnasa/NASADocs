-----------------------------------------------------------------------------------------------
-- Client Lua Script for ContextMenuPlayer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "GroupLib"
require "ChatSystemLib"
require "FriendshipLib"
require "MatchingGame"

local knXCursorOffset = 10
local knYCursorOffset = 25

local ContextMenuPlayer = {}
local ktSortOrder =
{
	["nil"] 				= 0,
	["BtnLeaveGroup"] 		= 1,
	["BtnKick"]				= 1,
	["BtnInvite"] 			= 1,
	["BtnWhisper"] 			= 2,
	["BtnAccountWhisper"] 	= 2,
	["BtnTrade"] 			= 3,
	["BtnDuel"] 			= 4,
	["BtnForfeit"] 			= 4,
	["BtnUnignore"] 		= 5,
	["BtnIgnore"] 			= 5,
	["BtnSocialList"] 		= 6,
		-- Social List: BtnAddFriend 				BtnUnfriend
		-- Social List: BtnAddRival					BtnUnrival
		-- Social List: BtnAddNeighbor				BtnUnneighbor
	["BtnGroupList"] 		= 7,
		-- Group List: BtnMentor,					BtnStopMentor
		-- Group List: BtnGroupTakeInvite, 			BtnGroupGiveInvite
		-- Group List: BtnGroupTakeKick, 			BtnGroupGiveKick
		-- Group List: BtnGroupTakeMark, 			BtnGroupGiveMark
		-- Group List: BtnVoteToKick
		-- Group List: BtnVoteToDisband
		-- Group List: BtnPromote
		-- Group List: BtnPromote
		-- Group List: BtnLocate
	["BtnInspect"]			= 8,
	["BtnClearFocus"] 		= 9,
	["BtnSetFocus"] 		= 9,
	["BtnAssist"] 			= 10,
	["BtnMarkerList"]		= 11,
		-- 8 Markers
		-- BtnMarkClear
	["BtnMarkTarget"] 		= 12,
}

local kstrRaidMarkerToSprite =
{
	"Icon_Windows_UI_CRB_Marker_Bomb",
	"Icon_Windows_UI_CRB_Marker_Ghost",
	"Icon_Windows_UI_CRB_Marker_Mask",
	"Icon_Windows_UI_CRB_Marker_Octopus",
	"Icon_Windows_UI_CRB_Marker_Pig",
	"Icon_Windows_UI_CRB_Marker_Chicken",
	"Icon_Windows_UI_CRB_Marker_Toaster",
	"Icon_Windows_UI_CRB_Marker_UFO",
}

function ContextMenuPlayer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ContextMenuPlayer:Init()
    Apollo.RegisterAddon(self)
end

function ContextMenuPlayer:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ContextMenuPlayer.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ContextMenuPlayer:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("GenericEvent_NewContextMenuPlayer", 			"Initialize", self) -- 2 args + 1 optional
	Apollo.RegisterEventHandler("GenericEvent_NewContextMenuPlayerDetailed", 	"Initialize", self) -- 3 args
	Apollo.RegisterEventHandler("GenericEvent_NewContextMenuFriend", 			"InitializeFriend", self) -- 2 args

	-- Just to recalculate sizing/arrangement (e.g. group button shows up)
	Apollo.RegisterEventHandler("Group_Join", 			"OnEventRequestResize", self)
	Apollo.RegisterEventHandler("Group_Left", 			"OnEventRequestResize", self)
	Apollo.RegisterEventHandler("FriendshipUpdate", 	"OnEventRequestResize", self)
	Apollo.RegisterEventHandler("TargetUnitChanged", 	"OnTargetUnitChanged", self)
end

function ContextMenuPlayer:SharedInitialize(wndParent)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ContextMenuPlayerForm", "TooltipStratum", self)
	self.wndMain:Invoke()

	self.bSortedAndSized = false
	self.tPlayerFaction = self.tPlayerFaction or GameLib.GetPlayerUnit():GetFaction()

	local tCursor = Apollo.GetMouse()
	self.wndMain:Move(tCursor.x - knXCursorOffset, tCursor.y - knYCursorOffset, self.wndMain:GetWidth(), self.wndMain:GetHeight())
end

function ContextMenuPlayer:InitializeFriend(wndParent, nFriendId)
	self:SharedInitialize(wndParent)

	self.tFriend = FriendshipLib.GetById(nFriendId)
	if self.tFriend ~= nil then
		self.strTarget = self.tFriend.strCharacterName
	end

	self.tAccountFriend = FriendshipLib.GetAccountById(nFriendId)
	if self.tAccountFriend ~= nil then
		if self.tAccountFriend.arCharacters and self.tAccountFriend.arCharacters[1] ~= nil then
			self.strTarget = self.tAccountFriend.arCharacters[1].strCharacterName
		end
	end

	self:RedrawAllFriend()
end

function ContextMenuPlayer:RedrawAllFriend()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local strTarget = self.strTarget
	local unitTarget = self.unitTarget
	if unitTarget == nil and self.tFriend ~= nil then
		unitTarget = FriendshipLib.GetUnitById(self.tFriend.nId)
	end
	local tFriend = self.tFriend
	local tAccountFriend = self.tAccountFriend
	local wndButtonList = self.wndMain:FindChild("ButtonList")

	-- Repeated use booleans
	local unitPlayer = GameLib.GetPlayerUnit()
	local bInGroup = GroupLib.InGroup()
	local tCharacterData = GameLib.SearchRelationshipStatusByCharacterName(strTarget)

	local bCanWhisper = tFriend ~= nil and tFriend.fLastOnline == 0 and not tFriend.bIgnore and tFriend.nFactionId == unitPlayer:GetFaction()
	local bCanAccountWisper = tAccountFriend ~= nil and tAccountFriend.arCharacters and tAccountFriend.arCharacters[1] ~= nil

	if bCanAccountWisper then
		bCanWhisper = tAccountFriend.arCharacters[1] ~= nil
			and tAccountFriend.arCharacters[1].strRealm == GameLib.GetRealmName()
			and tAccountFriend.arCharacters[1].nFactionId == unitPlayer:GetFaction()
	end

	if bCanWhisper then
		self:HelperBuildRegularButton(wndButtonList, "BtnWhisper", Apollo.GetString("ContextMenu_Whisper"))
	end

	if bCanAccountWisper then
		self:HelperBuildRegularButton(wndButtonList, "BtnAccountWhisper", Apollo.GetString("ContextMenu_AccountWhisper"))
	end

	if not bInGroup or (GroupLib.GetGroupMember(1).bCanInvite and bCanWhisper) then 
	--In SocialPanel, we don't care if they are part of a group, because we can't reliably test it.
	self:HelperBuildRegularButton(wndButtonList, "BtnInvite", Apollo.GetString("ContextMenu_InviteToGroup"))
	end

	local btnSocialList = self:FactoryProduce(wndButtonList, "BtnSocialList", "BtnSocialList")
	local wndSocialListItems = btnSocialList:FindChild("SocialListPopoutItems")
	btnSocialList:AttachWindow(btnSocialList:FindChild("SocialListPopoutFrame"))

	local bIsFriend = (tFriend ~= nil and tFriend.bFriend) or (tCharacterData ~= nil and tCharacterData.tFriend ~= nil and tCharacterData.tFriend.bFriend)
	local bIsRival = tFriend ~= nil and tFriend.bRival or (tCharacterData ~= nil and tCharacterData.tFriend ~= nil and tCharacterData.tFriend.bRival)
	local bIsNeighbor = tFriend ~= nil and tFriend.bNeighbor or (tCharacterData ~= nil and tCharacterData.tFriend ~= nil and tCharacterData.tFriend.bNeighbor)
	local bIsAccountFriend = tAccountFriend ~= nil or (tCharacterData == nil or tCharacterData.tAccountFriend ~= nil)

	if bIsFriend then
		if tAccountFriend == nil then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnUnfriend", Apollo.GetString("ContextMenu_RemoveFriend"))
		end
	elseif (tFriend ~= nil and tFriend.nFactionId == unitPlayer:GetFaction()) or (bCanAccountWisper and bCanWhisper) then
		self:HelperBuildRegularButton(wndSocialListItems, "BtnAddFriend", Apollo.GetString("ContextMenu_AddFriend"))
	end

	if bIsRival then
		if tAccountFriend == nil then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnUnrival", Apollo.GetString("ContextMenu_RemoveRival"))
		end
	elseif tFriend ~= nil or bCanAccountWisper then
		self:HelperBuildRegularButton(wndSocialListItems, "BtnAddRival", Apollo.GetString("ContextMenu_AddRival"))
	end

	if bIsNeighbor then
		if tAccountFriend == nil then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnUnneighbor", Apollo.GetString("ContextMenu_RemoveNeighbor"))
		end
	elseif tFriend ~= nil or bCanAccountWisper then
		self:HelperBuildRegularButton(wndSocialListItems, "BtnAddNeighbor", Apollo.GetString("ContextMenu_AddNeighbor"))
	end

	if bIsFriend and not bIsAccountFriend then
		self:HelperBuildRegularButton(wndSocialListItems, "BtnAccountFriend", Apollo.GetString("ContextMenu_PromoteFriend"))
	end

	if tAccountFriend ~= nil and bIsAccountFriend then
		self:HelperBuildRegularButton(wndSocialListItems, "BtnUnaccountFriend", Apollo.GetString("ContextMenu_UnaccountFriend"))
	end

	if tFriend and tFriend.bIgnore then
		self:HelperBuildRegularButton(wndButtonList, "BtnUnignore", Apollo.GetString("ContextMenu_Unignore"))
	elseif tAccountFriend == nil or tAccountFriend.fLastOnline == 0 then
		self:HelperBuildRegularButton(wndButtonList, "BtnIgnore", Apollo.GetString("ContextMenu_Ignore"))
	end

	self:ResizeAndRedraw()
end

function ContextMenuPlayer:Initialize(wndParent, strTarget, unitTarget, nReportId) -- unitTarget may be nil
	self:SharedInitialize(wndParent)

	self.strTarget = strTarget or ""
	self.unitTarget = unitTarget or nil
	self.nReportId = nReportId or nil
    self:RedrawAll()
end

function ContextMenuPlayer:RedrawAll()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local strTarget = self.strTarget
	local unitTarget = self.unitTarget
	local wndButtonList = self.wndMain:FindChild("ButtonList")

	-- Repeated use booleans
	local unitPlayer = GameLib.GetPlayerUnit()
	local bInGroup = GroupLib.InGroup()
	local bAmIGroupLeader = GroupLib.AmILeader()
	local tMyGroupData = GroupLib.GetGroupMember(1)
	local tCharacterData = GameLib.SearchRelationshipStatusByCharacterName(strTarget)
	local tTargetGroupData = (tCharacterData and tCharacterData.nPartyIndex) and GroupLib.GetGroupMember(tCharacterData.nPartyIndex) or nil

	-----------------------------------------------------------------------------------------------
	-- Even if hostile/neutral
	-----------------------------------------------------------------------------------------------

	if unitTarget and unitTarget == unitPlayer:GetAlternateTarget()	 then
		self:HelperBuildRegularButton(wndButtonList, "BtnClearFocus", Apollo.GetString("ContextMenu_ClearFocus"))
	elseif unitTarget and unitTarget:GetHealth() ~= nil and unitTarget:GetType() ~= "Simple" then
		self:HelperBuildRegularButton(wndButtonList, "BtnSetFocus", Apollo.GetString("ContextMenu_SetFocus"))
	end

	if unitTarget and bInGroup and tMyGroupData.bCanMark then
		self:HelperBuildRegularButton(wndButtonList, "BtnMarkTarget", Apollo.GetString("ContextMenu_MarkTarget"))

		local btnMarkerList = self:FactoryProduce(wndButtonList, "BtnMarkerList", "BtnMarkerList")
		local wndMarkerListItems = btnMarkerList:FindChild("MarkerListPopoutItems")
		btnMarkerList:AttachWindow(btnMarkerList:FindChild("MarkerListPopoutFrame"))

		for idx = 1, 8 do
			local wndCurr = self:FactoryProduce(wndMarkerListItems, "BtnMarkerIcon", "BtnMark"..idx)
			wndCurr:FindChild("BtnMarkerIconSprite"):SetSprite(kstrRaidMarkerToSprite[idx])
			wndCurr:FindChild("BtnMarkerMouseCatcher"):SetData("BtnMark"..idx)

			local nCurrentTargetMarker = unitTarget and unitTarget:GetTargetMarker() or ""
			if nCurrentTargetMarker == idx then
				wndCurr:SetCheck(true)
			end
		end

		local wndClear = self:FactoryProduce(wndMarkerListItems, "BtnMarkerIcon", "BtnMarkClear")
		wndClear:FindChild("BtnMarkerMouseCatcher"):SetData("BtnMarkClear")
		--wndClear:SetText("X")
	end

	if unitTarget and (self.tPlayerFaction ~= unitTarget:GetFaction() or not unitTarget:IsACharacter()) then
		if unitTarget:IsACharacter() then
			if tCharacterData and tCharacterData.tFriend and tCharacterData.tFriend.bRival then
				self:HelperBuildRegularButton(wndButtonList, "BtnUnrival", Apollo.GetString("ContextMenu_RemoveRival"))
			else
				self:HelperBuildRegularButton(wndButtonList, "BtnAddRival", Apollo.GetString("ContextMenu_AddRival"))
			end
		end

		self:ResizeAndRedraw()
		return
	end

	-----------------------------------------------------------------------------------------------
	-- Early exit, else continue only if target is a character
	-----------------------------------------------------------------------------------------------

	if unitTarget and unitTarget:IsACharacter() then
		if unitTarget ~= unitPlayer then
			self:HelperBuildRegularButton(wndButtonList, "BtnInspect", Apollo.GetString("ContextMenu_Inspect"))
		end

		if unitTarget ~= unitPlayer then -- Trade always visible, just enabled/disabled
			local eCanTradeResult = P2PTrading.CanInitiateTrade(unitTarget)
			local wndCurr = self:HelperBuildRegularButton(wndButtonList, "BtnTrade", Apollo.GetString("ContextMenu_Trade"))
			self:HelperEnableDisableRegularButton(wndCurr, eCanTradeResult == P2PTrading.P2PTradeError_Ok or eCanTradeResult == P2PTrading.P2PTradeError_TargetRangeMax)
		end

		if unitTarget ~= unitPlayer then -- Assist always visible
			local wndCurr = self:HelperBuildRegularButton(wndButtonList, "BtnAssist", Apollo.GetString("ContextMenu_Assist"))
			self:HelperEnableDisableRegularButton(wndCurr, unitTarget:GetTarget())
		end

		-- Duel
		local eCurrentZonePvPRules = GameLib.GetCurrentZonePvpRules()
		if unitTarget ~= unitPlayer and (not eCurrentZonePvPRules or eCurrentZonePvPRules ~= GameLib.CodeEnumZonePvpRules.Sanctuary) then
			if GameLib.GetDuelOpponent(unitPlayer) == unitTarget then
				if GameLib.GetDuelState() == GameLib.CodeEnumDuelState.Dueling then
					self:HelperBuildRegularButton(wndButtonList, "BtnForfeit", Apollo.GetString("ContextMenu_ForfeitDuel")) --TODO: LOCALIZATION
				end
			else
				self:HelperBuildRegularButton(wndButtonList, "BtnDuel", Apollo.GetString("ContextMenu_Duel"))
			end
		end
	end

	if unitTarget == nil or unitTarget ~= unitPlayer then

		local bCanWhisper = true
		local bCanAccountWisper = false

		if tCharacterData and tCharacterData.tAccountFriend then
			bCanAccountWisper = true

			bCanWhisper = tCharacterData.tAccountFriend.arCharacters[1] ~= nil
				and tCharacterData.tAccountFriend.arCharacters[1].strRealm == GameLib.GetRealmName()
				and tCharacterData.tAccountFriend.arCharacters[1].nFactionId == GameLib.GetPlayerUnit():GetFaction()
		end

		if bCanWhisper then
			self:HelperBuildRegularButton(wndButtonList, "BtnWhisper", Apollo.GetString("ContextMenu_Whisper"))
		end
		if bCanAccountWisper then
			self:HelperBuildRegularButton(wndButtonList, "BtnAccountWhisper", Apollo.GetString("ContextMenu_AccountWhisper"))
		end

		if not bInGroup or (tMyGroupData.bCanInvite and (unitTarget and not unitTarget:IsInYourGroup())) then
			self:HelperBuildRegularButton(wndButtonList, "BtnInvite", Apollo.GetString("ContextMenu_InviteToGroup"))
		end

		if tCharacterData and tCharacterData.tFriend and tCharacterData.tFriend.bIgnore then
			self:HelperBuildRegularButton(wndButtonList, "BtnUnignore", Apollo.GetString("ContextMenu_Unignore"))
		else
			self:HelperBuildRegularButton(wndButtonList, "BtnIgnore", Apollo.GetString("ContextMenu_Ignore"))
		end
	end

	-----------------------------------------------------------------------------------------------
	-- Social Lists
	-----------------------------------------------------------------------------------------------

	if unitTarget == nil or unitTarget ~= unitPlayer then
		local btnSocialList = self:FactoryProduce(wndButtonList, "BtnSocialList", "BtnSocialList")
		local wndSocialListItems = btnSocialList:FindChild("SocialListPopoutItems")
		btnSocialList:AttachWindow(btnSocialList:FindChild("SocialListPopoutFrame"))

		local bIsFriend = tCharacterData and tCharacterData.tFriend and tCharacterData.tFriend.bFriend
		local bIsRival = tCharacterData and tCharacterData.tFriend and tCharacterData.tFriend.bRival
		local bIsNeighbor = tCharacterData and tCharacterData.tFriend and tCharacterData.tFriend.bNeighbor
		local bIsAccountFriend = tCharacterData and tCharacterData.tAccountFriend

		if bIsFriend then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnUnfriend", Apollo.GetString("ContextMenu_RemoveFriend"))
		else
			self:HelperBuildRegularButton(wndSocialListItems, "BtnAddFriend", Apollo.GetString("ContextMenu_AddFriend"))
		end

		if bIsRival then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnUnrival", Apollo.GetString("ContextMenu_RemoveRival"))
		else
			self:HelperBuildRegularButton(wndSocialListItems, "BtnAddRival", Apollo.GetString("ContextMenu_AddRival"))
		end

		if bIsNeighbor then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnUnneighbor", Apollo.GetString("ContextMenu_RemoveNeighbor"))
		else
			self:HelperBuildRegularButton(wndSocialListItems, "BtnAddNeighbor", Apollo.GetString("ContextMenu_AddNeighbor"))
		end

		if bIsFriend and not bIsAccountFriend then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnAccountFriend", Apollo.GetString("ContextMenu_PromoteFriend"))
		end

		if bIsAccountFriend then
			self:HelperBuildRegularButton(wndSocialListItems, "BtnUnaccountFriend", Apollo.GetString("ContextMenu_UnaccountFriend"))
			self.tAccountFriend = tCharacterData.tAccountFriend
		end

		-- TODO Invite to Guild
	end

	-----------------------------------------------------------------------------------------------
	-- Group Lists
	-----------------------------------------------------------------------------------------------

	if bInGroup and unitTarget ~= unitPlayer then
		local btnGroupList = self:FactoryProduce(wndButtonList, "BtnGroupList", "BtnGroupList")
		local wndGroupListItems = btnGroupList:FindChild("GroupPopoutItems")
		btnGroupList:AttachWindow(btnGroupList:FindChild("GroupPopoutFrame"))

		-- see if tMygroupData is currently mentoring tTargetGroupData
		if tTargetGroupData then
			local bMentoringTarget = false
			for _, nMentorIdx in ipairs(tTargetGroupData.tMentoredBy) do
				if tMyGroupData.nMemberIdx == nMentorIdx then
					bMentoringTarget = true
					break
				end
			end

			if tTargetGroupData.bIsOnline and not bMentoringTarget and tTargetGroupData.nLevel < tMyGroupData.nLevel then
				self:HelperBuildRegularButton(wndGroupListItems, "BtnMentor", Apollo.GetString("ContextMenu_Mentor"))
			end
		end

		if tMyGroupData.bIsMentoring or tMyGroupData.bIsMentored then
			self:HelperBuildRegularButton(wndGroupListItems, "BtnStopMentor", Apollo.GetString("ContextMenu_StopMentor"))
		end

		if tTargetGroupData then
			self:HelperBuildRegularButton(wndGroupListItems, "BtnLocate", Apollo.GetString("ContextMenu_Locate"))
		end

		if tTargetGroupData and bAmIGroupLeader then
			self:HelperBuildRegularButton(wndGroupListItems, "BtnPromote", Apollo.GetString("ContextMenu_Promote"))
		end

		if tTargetGroupData and tMyGroupData.bCanKick then
			self:HelperBuildRegularButton(wndGroupListItems, "BtnKick", Apollo.GetString("ContextMenu_Kick"))
		end

		local bInMatchingGame = MatchingGame.IsInMatchingGame()
		local bIsMatchingGameFinished = MatchingGame.IsMatchingGameFinished()

		if tTargetGroupData and bInMatchingGame and not bIsMatchingGameFinished then
			local wndCurr = self:HelperBuildRegularButton(wndGroupListItems, "BtnVoteToKick", Apollo.GetString("ContextMenu_VoteToKick"))
			self:HelperEnableDisableRegularButton(wndCurr, not MatchingGame.IsVoteKickActive())
		end

		if tTargetGroupData and bInMatchingGame and not bIsMatchingGameFinished then
			local tMatchState = MatchingGame:GetPVPMatchState()
			if tMatchState and tMatchState.eRules ~= MatchingGame.Rules.DeathmatchPool then
				local wndCurr = self:HelperBuildRegularButton(wndGroupListItems, "BtnVoteToDisband", Apollo.GetString("ContextMenu_VoteToDisband"))
				self:HelperEnableDisableRegularButton(wndCurr, not MatchingGame.IsVoteSurrenderActive())
			end
		end

		if tTargetGroupData and bAmIGroupLeader then
			if tTargetGroupData.bCanKick then
				self:HelperBuildRegularButton(wndGroupListItems, "BtnGroupTakeKick", Apollo.GetString("ContextMenu_DenyKicks"))
			else
				self:HelperBuildRegularButton(wndGroupListItems, "BtnGroupGiveKick", Apollo.GetString("ContextMenu_AllowKicks"))
			end

			if tTargetGroupData.bCanInvite then
				self:HelperBuildRegularButton(wndGroupListItems, "BtnGroupTakeInvite", Apollo.GetString("ContextMenu_DenyInvites"))
			else
				self:HelperBuildRegularButton(wndGroupListItems, "BtnGroupGiveInvite", Apollo.GetString("ContextMenu_AllowInvites"))
			end

			if tTargetGroupData.bCanMark then
				self:HelperBuildRegularButton(wndGroupListItems, "BtnGroupTakeMark", Apollo.GetString("ContextMenu_DenyMarking"))
			else
				self:HelperBuildRegularButton(wndGroupListItems, "BtnGroupGiveMark", Apollo.GetString("ContextMenu_AllowMarking"))
			end
		end

		if not tTargetGroupData and tMyGroupData.bCanInvite then
			self:HelperBuildRegularButton(wndGroupListItems, "BtnInvite", Apollo.GetString("ContextMenu_Invite"))
		end

		if #btnGroupList:FindChild("GroupPopoutItems"):GetChildren() == 0 then
			btnGroupList:Destroy()
		end
	end

	if bInGroup and unitTarget == unitPlayer then
		self:HelperBuildRegularButton(wndButtonList, "BtnLeaveGroup", Apollo.GetString("ContextMenu_LeaveGroup"))
	end

	if self.nReportId then
		self:HelperBuildRegularButton(wndButtonList, "BtnReportChat", Apollo.GetString("ContextMenu_ReportSpam"))
	end

	self:ResizeAndRedraw()
end

function ContextMenuPlayer:ResizeAndRedraw()
	local wndButtonList = self.wndMain:FindChild("ButtonList")
	if next(wndButtonList:GetChildren()) == nil then
		self.wndMain:Destroy()
		return
	end

	if not self.bSortedAndSized then
		self.bSortedAndSized = true
		local nHeight = wndButtonList:ArrangeChildrenVert(0, function(a,b) return (ktSortOrder[a:GetData()] or 0) > (ktSortOrder[b:GetData()] or 0) end)
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 62)

		-- Other lists
		if self.wndMain:FindChild("GroupPopoutItems") then
			nHeight = self.wndMain:FindChild("GroupPopoutItems"):ArrangeChildrenVert(0)
			nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("GroupPopoutFrame"):GetAnchorOffsets()
			self.wndMain:FindChild("GroupPopoutFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 62)
		end
		if self.wndMain:FindChild("SocialListPopoutItems") then
			nHeight = self.wndMain:FindChild("SocialListPopoutItems"):ArrangeChildrenVert(0)
			nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("SocialListPopoutFrame"):GetAnchorOffsets()
			self.wndMain:FindChild("SocialListPopoutFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 62)
		end
		if self.wndMain:FindChild("MarkerListPopoutItems") then
			self.wndMain:FindChild("MarkerListPopoutItems"):ArrangeChildrenTiles(0)
		end
	end

	self:CheckWindowBounds()
end

function ContextMenuPlayer:CheckWindowBounds()
	local tMouse = Apollo.GetMouse()

	local nWidth =  self.wndMain:GetWidth()
	local nHeight = self.wndMain:GetHeight()

	local nMaxScreenWidth, nMaxScreenHeight = Apollo.GetScreenSize()
	local nNewX = nWidth + tMouse.x - knXCursorOffset
	local nNewY = nHeight + tMouse.y - knYCursorOffset

	local bSafeX = true
	local bSafeY = true

	if nNewX > nMaxScreenWidth then
		bSafeX = false
	end

	if nNewY > nMaxScreenHeight then
		bSafeY = false
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	if bSafeX == false then
		local nRightOffset = nNewX - nMaxScreenWidth
		nLeft = nLeft - nRightOffset
		nRight = nRight - nRightOffset
	end

	if bSafeY == false then
		nBottom = nTop + knYCursorOffset
		nTop = nBottom - nHeight
	end

	if bSafeX == false or bSafeY == false then
		self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
	end
end

-----------------------------------------------------------------------------------------------
-- Interaction Events
-----------------------------------------------------------------------------------------------

function ContextMenuPlayer:ProcessContextClick(eButtonType)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	local strTarget = self.strTarget
	local unitTarget = self.unitTarget
	local tCharacterData = GameLib.SearchRelationshipStatusByCharacterName(strTarget)
	local nGroupMemberId = (tCharacterData and tCharacterData.nPartyIndex) or nil

	if unitTarget == nil and nGroupMemberId ~= nil then
		unitTarget = GroupLib.GetUnitForGroupMember(nGroupMemberId)
	end

	if eButtonType == "BtnWhisper" then
		Event_FireGenericEvent("GenericEvent_ChatLogWhisper", strTarget)
	elseif eButtonType == "BtnAccountWhisper" then
		if tCharacterData.tAccountFriend ~= nil
			and tCharacterData.tAccountFriend.arCharacters ~= nil
			and tCharacterData.tAccountFriend.arCharacters[1] ~= nil then
			local strDisplayName = tCharacterData.tAccountFriend.strCharacterName
			local strRealmName = tCharacterData.tAccountFriend.arCharacters[1].strRealm
			Event_FireGenericEvent("Event_EngageAccountWhisper", strDisplayName, strTarget, strRealmName)
		end
	elseif eButtonType == "BtnSetFocus" and unitTarget then
		unitPlayer:SetAlternateTarget(unitTarget)
	elseif eButtonType == "BtnClearFocus" then
		unitPlayer:SetAlternateTarget(nil)
	elseif eButtonType == "BtnInspect" and unitTarget then
		unitTarget:Inspect()
	elseif eButtonType == "BtnAssist" and unitTarget then
		GameLib.SetTargetUnit(unitTarget:GetTarget())
	elseif eButtonType == "BtnDuel" and unitTarget then
		GameLib.InitiateDuel(unitTarget)
	elseif eButtonType == "BtnForfeit" and unitTarget then
		GameLib.ForfeitDuel(unitTarget)
	elseif eButtonType == "BtnLeaveGroup" then
		GroupLib.LeaveGroup()
	elseif eButtonType == "BtnInvite" then
		GroupLib.Invite(strTarget)
	elseif eButtonType == "BtnKick" then
		GroupLib.Kick(nGroupMemberId)
	elseif eButtonType == "BtnPromote" then
		GroupLib.Promote(nGroupMemberId, "")
	elseif eButtonType == "BtnGroupGiveMark" then
		GroupLib.SetCanMark(nGroupMemberId, true)
	elseif eButtonType == "BtnGroupTakeMark" then
		GroupLib.SetCanMark(nGroupMemberId, false)
	elseif eButtonType == "BtnGroupGiveKick" then
		GroupLib.SetKickPermission(nGroupMemberId, true)
	elseif eButtonType == "BtnGroupTakeKick" then
		GroupLib.SetKickPermission(nGroupMemberId, false)
	elseif eButtonType == "BtnGroupGiveInvite" then
		GroupLib.SetInvitePermission(nGroupMemberId, true)
	elseif eButtonType == "BtnGroupTakeInvite" then
		GroupLib.SetInvitePermission(nGroupMemberId, false)
	elseif eButtonType == "BtnLocate" and unitTarget then
		unitTarget:ShowHintArrow()
	elseif eButtonType == "BtnAddRival" then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Rival, strTarget)
	elseif eButtonType == "BtnIgnore" then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Ignore, strTarget)
	elseif eButtonType == "BtnAddFriend" then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Friend, strTarget)
	elseif eButtonType == "BtnUnrival" then
		FriendshipLib.Remove(tCharacterData.tFriend.nId, FriendshipLib.CharacterFriendshipType_Rival)
	elseif eButtonType == "BtnUnfriend" then
		FriendshipLib.Remove(tCharacterData.tFriend.nId, FriendshipLib.CharacterFriendshipType_Friend)
	elseif eButtonType == "BtnUnignore" then
		FriendshipLib.Remove(tCharacterData.tFriend.nId, FriendshipLib.CharacterFriendshipType_Ignore)
	elseif eButtonType == "BtnAddNeighbor" then
		HousingLib.NeighborInviteByName(strTarget)
	elseif eButtonType == "BtnUnneighbor" then
		--HousingLib.NeighborEvict(tCurr.nId)
		Print(Apollo.GetString("ContextMenu_NeighborRemoveFailed")) -- TODO!
	elseif eButtonType == "BtnAccountFriend" then
		FriendshipLib.AccountAddByUpgrade(tCharacterData.tFriend.nId)
	elseif eButtonType == "BtnUnaccountFriend" then
		if self.tAccountFriend and self.tAccountFriend.nId then
			Event_FireGenericEvent("EventGeneric_ConfirmRemoveAccountFriend", self.tAccountFriend.nId)
		end
	elseif eButtonType == "BtnTrade" and unitTarget then
		local eCanTradeResult = P2PTrading.CanInitiateTrade(unitTarget)
		if eCanTradeResult == P2PTrading.P2PTradeError_Ok then
			Event_FireGenericEvent("P2PTradeWithTarget", unitTarget)
		elseif eCanTradeResult == P2PTrading.P2PTradeError_TargetRangeMax then
			Event_FireGenericEvent("GenericFloater", unitPlayer, Apollo.GetString("ContextMenu_PlayerOutOfRange"))
			unitTarget:ShowHintArrow()
		else
			Event_FireGenericEvent("GenericFloater", unitPlayer, Apollo.GetString("ContextMenu_TradeFailed"))
		end
	elseif eButtonType == "BtnMarkTarget" and unitTarget then
		local nResult = 8
		local nCurrent = unitTarget:GetTargetMarker() or 0
		local tAvailableMarkers = GameLib.GetAvailableTargetMarkers()
		for idx = nCurrent, 8 do
			if tAvailableMarkers[idx] then
				nResult = idx
				break
			end
		end
		unitTarget:SetTargetMarker(nResult)
	elseif eButtonType == "BtnMarkClear" and unitTarget then
		unitTarget:ClearTargetMarker()
	elseif eButtonType == "BtnVoteToDisband" then
		MatchingGame.InitiateVoteToSurrender()
	elseif eButtonType == "BtnVoteToKick" then
		MatchingGame.InitiateVoteToKick(nGroupMemberId)
	elseif eButtonType == "BtnMentor" then
		GroupLib.AcceptMentoring(unitTarget)
	elseif eButtonType == "BtnStopMentor" then
		GroupLib.CancelMentoring()
	elseif eButtonType == "BtnReportChat" and self.nReportId then
		local tResult = ChatSystemLib.PrepareInfractionReport(self.nReportId)
		self:BuildReportConfirmation(tResult.strDescription, tResult.bSuccess)
	elseif eButtonType and string.find(eButtonType, "BtnMark") ~= 0 and unitTarget then
		unitTarget:SetTargetMarker(tonumber(string.sub(eButtonType, string.len("BtnMark_"))))
	end
end

function ContextMenuPlayer:OnTargetUnitChanged(unitNewTarget)
	if not unitNewTarget or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if not self.unitTarget or unitNewTarget ~= self.unitTarget then
		self:OnMainWindowClosed()
	end
end

function ContextMenuPlayer:OnMainWindowClosed(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end
end

function ContextMenuPlayer:OnRegularBtn(wndHandler, wndControl)
	self:ProcessContextClick(wndHandler:GetData())
	self:OnMainWindowClosed()
end

function ContextMenuPlayer:OnBtnRegularMouseDown(wndHandler, wndControl)
	self:OnRegularBtn(wndHandler:GetParent(), wndHandler:GetParent())
end

function ContextMenuPlayer:OnBtnCheckboxMouseDown(wndHandler, wndControl)
	for idx, wndCurr in pairs(self.wndMain:FindChild("ButtonList"):GetChildren()) do
		wndCurr:SetCheck(wndHandler == wndCurr:FindChild("BtnCheckboxMouseCatcher") and not wndCurr:IsChecked())
	end
	return true
end

function ContextMenuPlayer:OnBtnRegularMouseEnter(wndHandler, wndControl)
	wndHandler:GetParent():FindChild("BtnText"):SetTextColor("UI_BtnTextBlueFlyBy")
end

function ContextMenuPlayer:OnBtnRegularMouseExit(wndHandler, wndControl)
	wndHandler:GetParent():FindChild("BtnText"):SetTextColor("UI_BtnTextBlueNormal")
end

function ContextMenuPlayer:OnEventRequestResize()
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("ButtonList") then
		self.wndMain:FindChild("ButtonList"):DestroyChildren()
	end
	self.bSortedAndSized = false
	self:RedrawAll()
end

function ContextMenuPlayer:HelperBuildRegularButton(wndButtonList, eButtonType, strButtonText)
	-- TODO 2nd argument probably shouldn't be a string, and doesn't need to be localized
	local wndCurr = self:FactoryProduce(wndButtonList, "BtnRegular", eButtonType)
	wndCurr:FindChild("BtnText"):SetText(strButtonText)
	return wndCurr
end

function ContextMenuPlayer:HelperEnableDisableRegularButton(wndCurr, bEnable)
	if bEnable and wndCurr:ContainsMouse() then
		wndCurr:FindChild("BtnText"):SetTextColor("UI_BtnTextBlueFlyBy")
	elseif bEnable then
		wndCurr:FindChild("BtnText"):SetTextColor("UI_BtnTextBlueNormal")
	else
		wndCurr:FindChild("BtnText"):SetTextColor("UI_BtnTextBlueDisabled")
	end
	wndCurr:Enable(bEnable)
end

function ContextMenuPlayer:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end
-----------------------------------------------------------------------------------------------
-- Yes No
-----------------------------------------------------------------------------------------------

function ContextMenuPlayer:BuildReportConfirmation(strMessage, bYesNo)
	if not strMessage then return end
	self:ClearReportConfirmation()

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "ReportChat_YesNo", nil, self)
	if bYesNo then
		wndCurr:FindChild("CancelButton"):Show(false)
		wndCurr:FindChild("YesButton"):Show(true)
		wndCurr:FindChild("NoButton"):Show(true)
	else
		wndCurr:FindChild("CancelButton"):Show(true)
		wndCurr:FindChild("YesButton"):Show(false)
		wndCurr:FindChild("NoButton"):Show(false)
	end

	wndCurr:FindChild("BodyText"):SetAML( "<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloTitle\" >" .. strMessage .. "</P>")
	wndCurr:FindChild("BodyText"):SetHeightToContentHeight()
	wndCurr:FindChild("BodyTextBackground"):RecalculateContentExtents()

	self.wndChatReport = wndCurr
end

function ContextMenuPlayer:ClearReportConfirmation()
	if self.wndChatReport then
		self.wndChatReport:Destroy()
	end
end

function ContextMenuPlayer:ReportChat_WindowClosed(wndHandler)
	self:ClearReportConfirmation()
end

function ContextMenuPlayer:ReportChat_NoPicked(wndHandler, wndControl)
	self:ClearReportConfirmation()
end

function ContextMenuPlayer:ReportChat_YesPicked(wndHandler, wndControl)
	ChatSystemLib.SendInfractionReport()
	self:ClearReportConfirmation()
end

local ContextMenuPlayerInst = ContextMenuPlayer:new()
ContextMenuPlayerInst:Init()
