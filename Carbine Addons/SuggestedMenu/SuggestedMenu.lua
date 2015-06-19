-----------------------------------------------------------------------------------------------
-- Client Lua Script for SuggestedMenu
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "FriendshipLib"
SuggestedMenu = {} 

local knMaxRecentEntries = 10
local kMaxShownEntries = 4
local kstrColorNonSelectedEntry = "UI_BtnTextHoloNormal"

local eSuggestedOperator = {
		And = 1, 
		Or  = 2,
		Not = 3,
}

local eSuggestedRelation = {
		Friends 		= 1, 
		AccountFriends 	= 2, 
		Groups 			= 3, 
		Neighbors 		= 4, 
		Recent 			= 5, 
}

function SuggestedMenu:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	return o
end

function SuggestedMenu:delete()
	Apollo.UnlinkAddon(self.luaOwner, self)
end

function SuggestedMenu:Init(luaOwner, xmlDoc)
	--this self.bFailed is tested for in the SuggestedTextBoxSubclass, don't remove
	if not luaOwner or not xmlDoc then
		self.bFailed = true
		return
	end
	Apollo.RegisterAddon(self)
	Apollo.LinkAddon(luaOwner, self)

	--these tables must be initialized before OnDocumentReady
	self.tRecent = {}
	self.tRelations = {}

	self.luaOwner = luaOwner
	self.xmlDoc = xmlDoc
	
	Apollo.RegisterEventHandler("FriendshipAccountFriendsRecieved",  	"OnFriendshipAccountFriendsRecieved", self)
	Apollo.RegisterEventHandler("FriendshipAccountFriendRemoved",   	"OnFriendshipAccountFriendRemoved", self)
	Apollo.RegisterEventHandler("FriendshipLoaded", 					"OnFriendshipLoaded", self)
	Apollo.RegisterEventHandler("FriendshipUpdate", 					"OnFriendshipUpdate", self)
	Apollo.RegisterEventHandler("FriendshipRemove", 					"OnFriendshipRemove", self)
	Apollo.RegisterEventHandler("Group_Join",							"OnGroupJoin", self)
	Apollo.RegisterEventHandler("Group_Left", 							"OnGroupLeft", self)
	Apollo.RegisterEventHandler("Group_Add",							"OnGroupAdd", self)
	Apollo.RegisterEventHandler("Group_Remove",							"OnGroupRemove", self)
	Apollo.RegisterEventHandler("HousingNeighborUpdate", 				"OnHousingNeighborUpdate", self)
	Apollo.RegisterEventHandler("HousingNeighborsLoaded", 				"OnHousingNeighborUpdate", self)
	Apollo.RegisterEventHandler("UpdateRecent", 						"OnUpdateRecent", self)

	Apollo.RegisterEventHandler("InputChangedUpdateSuggested", 			"OnInputChangedUpdateSuggested", self)
	Apollo.RegisterEventHandler("InputReturn", 							"OnInputReturn", self)

	
	if FriendshipLib.IsLoaded() then
		self:OnFriendshipLoaded()
		self:OnHousingNeighborUpdate()
	end
	
	if GroupLib.InGroup() then
		self:OnGroupJoin()
	end
end

function SuggestedMenu:CreateAndInitializeMap(wndTextBox)
	local wndMain = Apollo.LoadForm(self.xmlDoc, "SuggestedMenuForm", wndTextBox, self)
	self.tWindowMap =
	{
		["Main"] = wndMain,
		["SuggestedMenuContent"] = wndMain:FindChild("SuggestedMenuContent"),
		["Title"] = wndMain:FindChild("Title"),
		["wndTextBox"] = wndTextBox,
	}

	self.tWindowMap["Main"]:Show(false, true)

	--sizing maybe comeback and optimize!
	local wndSuggestedMenuEntry = Apollo.LoadForm(self.xmlDoc, "SuggestedMenuEntryForm", nil, self)
	self.nEntrySize = wndSuggestedMenuEntry:GetHeight()
	wndSuggestedMenuEntry:Destroy()
	wndSuggestedMenuEntry = nil
		
		
	local nLeft, nTop, nRight, nBottom = self.tWindowMap["Main"]:GetAnchorOffsets()
	self.nDefaultMenuTop = nTop
end

-----------------------------------------------------------------------------------------------
-- SuggestedMenu Getting Data
-----------------------------------------------------------------------------------------------
--AccountFriends
function SuggestedMenu:OnFriendshipAccountFriendsRecieved(tFriendAccountList)
	local strPlayerRealm = GameLib.GetRealmName()
	for idx, tAccountFriend in ipairs(tFriendAccountList) do
		self:UpdateRelations(tAccountFriend.strCharacterName, {bAccountFriends = true})
		if tAccountFriend.arCharacters then
			for idx, tMemberInfo in pairs(tAccountFriend.arCharacters) do
				local strPlayerNameWithRealm = tMemberInfo.strCharacterName
				if strPlayerRealm and strPlayerRealm ~= tMemberInfo.strRealm then
					strPlayerNameWithRealm = strPlayerNameWithRealm.."@"..tMemberInfo.strRealm
				end
				self:UpdateRelations(strPlayerNameWithRealm, {bFriends = true})
			end
		end
	end
end

function SuggestedMenu:OnFriendshipAccountFriendRemoved(nFriendId)
	local tAccountFriend = FriendshipLib.GetAccountById( nFriendId )
	if not tAccountFriend or not tAccountFriend.strCharacterName then
		return
	end

	if self.tRelations[tAccountFriend.strCharacterName] then
		self:UpdateRelations(tAccountFriend.strCharacterName, {bAccountFriends = false})
	end

	local strPlayerRealm = GameLib.GetRealmName()
	for key, tCharacter in pairs(tAccountFriend.arCharacters or {}) do --get info on account friend's character that is logged in
		if tCharacter.strCharacterName then
			if strPlayerRealm and strPlayerRealm ~= tCharacter.strRealm then
				local strPlayerNameWithRealm = tAccountFriend.strCharacterName.."@"..tCharacter.strRealm
				self:UpdateRelations(strPlayerNameWithRealm, {bAccountFriends = false})
			elseif self.tRelations[tCharacter.strCharacterName] then
				self:UpdateRelations(tCharacter.strCharacterName, {bAccountFriends = false})
			end
		end
	end
end

--Friends
function SuggestedMenu:OnFriendshipLoaded()
	local strPlayerRealm = GameLib.GetRealmName()
	for key, tAccountFriend in pairs(FriendshipLib.GetAccountList()) do	
		for key, tCharacter in pairs(tAccountFriend.arCharacters or {}) do --get info on account friend's character that is logged in
			local strName = tCharacter.strCharacterName..""
			if strPlayerRealm and strPlayerRealm ~= tCharacter.strRealm then
				strName = strName .."@"..tCharacter.strRealm
			end
			self:UpdateRelations(strName, {bFriends = true})
		end
		self:UpdateRelations(tAccountFriend.strCharacterName, {bAccountFriends = true})
	end
	--may or may not have loaded yet, if loads latter, then OnFriendshipUpdate will handle adding friends
	for key, tFriend in pairs(FriendshipLib.GetList()) do
		if tFriend.strCharacterName and not tFriend.bIgnore then --only add people who arent ignored
			self:UpdateRelations(tFriend.strCharacterName, {bFriends = true})
		end
	end
end

function SuggestedMenu:OnFriendshipUpdate(nFriendId) -- this is for log in when needing to add non account friends, account friends are added OnFriendshipLoaded
	local tFriend = FriendshipLib.GetById( nFriendId ) --or FriendshipLib.GetAccountById( nFriendId )
	if not tFriend or not tFriend.strCharacterName then
		return
	end
	self:UpdateRelations(tFriend.strCharacterName, {bFriends = true})
end

function SuggestedMenu:OnFriendshipRemove(nFriendId)
	local tFriend = FriendshipLib.GetById( nFriendId )

	if tFriend and tFriend.strCharacterName and self.tRelations[tFriend.strCharacterName] then
		self:UpdateRelations(tFriend.strCharacterName, {bFriends = false})
	end
end

--Group
function SuggestedMenu:OnGroupLeft(eReason)
	for key, tInfo in pairs(self.tRelations or {}) do
		if tInfo.bGroups then
			tInfo.bGroups = false
		end
	end
end

function SuggestedMenu:OnGroupJoin(strName)
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then return end
	local strPlayerName = unitPlayer:GetName()
	local nGroupMemberCount = GroupLib.GetMemberCount()
	if nGroupMemberCount > 0 then
		for idx = 1, nGroupMemberCount do
			local tGroupMemberInfo = GroupLib.GetGroupMember(idx)
			if tGroupMemberInfo ~= nil and strPlayerName ~= tGroupMemberInfo.strCharacterName then 
				self:UpdateRelations(tGroupMemberInfo.strCharacterName, {bGroups = true})
			end
		end
	end
end

function SuggestedMenu:OnGroupAdd(strName)
	if not strName then 
		return 
	end
	self:UpdateRelations(strName, {bGroups = true})
end

function SuggestedMenu:OnGroupRemove(strName, eReason)
	if not strName then 
		return 
	end
	self:UpdateRelations(strName , {bGroups = false})
end

--Neighbor
function SuggestedMenu:OnHousingNeighborUpdate()--called on load and updating neighbor information 
	--no events to determine add or remove neighbor, clearing to remove neighbor entries that are removed
	for key, tCurInfo in pairs(self.tRelations or {}) do
		if tCurInfo.bNeighbors then
			tCurInfo.bNeighbors = false
		end
	end
	
	for key, tCurrNeighbor in pairs(HousingLib.GetNeighborList()) do
		if tCurrNeighbor.strCharacterName ~= nil then --first update is neighborlist loaded however tCurrNeighbor.strCharacterName hasnt been set yet
			self:UpdateRelations(tCurrNeighbor.strCharacterName, {bNeighbors = true})
		end
	end
end

--Recent
--OnUpdateRecent will receive a table containing the most recent names, this is maintained by chatlog
function SuggestedMenu:OnUpdateRecent(tRecent)
	if not tRecent then
		return
	end
	self.tRecent = tRecent
end

function SuggestedMenu:UpdateRelations(strAddName, tUpdateInfo)
	if not self.tRelations or not strAddName or not tUpdateInfo then
		return
	end

	--creating default new record for this name if it didn't exist
	if not self.tRelations[strAddName] then
		self.tRelations[strAddName] = {bFriends = false, bAccountFriends = false, bNeighbors = false, bGroups = false,}
	end

	--Go to the record that is to be updated, find any values to be updated, make record retain the newly updated values
	--strInfo will be: bFriends, bAccountFriends, bNeighbors, or bGroups (or any combination)
	if self.tRelations[strAddName] then
		for strInfo, bValue in pairs(tUpdateInfo) do
			self.tRelations[strAddName][strInfo] = bValue
		end
	end

end

-----------------------------------------------------------------------------------------------
-- SuggestedMenu Functions
-----------------------------------------------------------------------------------------------

function SuggestedMenu:GetEnumAnd()
	return eSuggestedOperator and eSuggestedOperator.And or nil
end

function SuggestedMenu:GetEnumNot()
	return eSuggestedOperator and eSuggestedOperator.Not or nil
end

function SuggestedMenu:GetEnumOr()
	return eSuggestedOperator and eSuggestedOperator.Or or nil
end

function SuggestedMenu:GetEnumFriends()
	return eSuggestedRelation and eSuggestedRelation.Friends or nil
end

function SuggestedMenu:GetEnumAccountFriends()
	return eSuggestedRelation and eSuggestedRelation.AccountFriends or nil
end

function SuggestedMenu:GetEnumGroups()
	return eSuggestedRelation and eSuggestedRelation.Groups or nil
end

function SuggestedMenu:GetEnumNeighbors()
	return eSuggestedRelation and eSuggestedRelation.Neighbors or nil
end

function SuggestedMenu:GetEnumRecent()
	return eSuggestedRelation and eSuggestedRelation.Recent or nil
end

function SuggestedMenu:OnInputReturn()
	if self.tWindowMap and self.tWindowMap["Main"]:IsShown() and self.tResultBtns and self.tResultBtns[self.nSuggestedResultPos] then --select the suggested name
		self:OnSuggestedMenuEntry(self.tResultBtns[self.nSuggestedResultPos], self.tResultBtns[self.nSuggestedResultPos])
	end
end

function SuggestedMenu:HideSuggestedMenu()
	if not self.tWindowMap then
		return
	end

	self:OnSuggestedMenuHide()
end

function SuggestedMenu:OnSuggestedMenuNavigate()
	if not self.tWindowMap or not self.tWindowMap["Main"] or not self.tWindowMap["Main"]:IsShown() then
		return
	end
	self:HelperTabThroughSuggestedEntries()
end

function SuggestedMenu:OnInputChangedUpdateSuggested(wndTextBox, strText)
	if not wndTextBox or not strText then
		return
	end

	--if there is is the first time set up or the text box has changed, CreateAndInitializeMap
	if not self.tWindowMap or (self.tWindowMap and wndTextBox:GetId() ~= self.tWindowMap["wndTextBox"]:GetId()) then
		self:CreateAndInitializeMap(wndTextBox)
	end
	
	self.strLastText = strText
	
	if strText~= "" then
		self:OnShowSuggestedMenu()
	else
		self:OnSuggestedMenuHide()
	end
end

function SuggestedMenu:OnSuggestedMenuHide()
	self.tWindowMap["Main"]:Show(false)
	self.tResultBtns = {}
end

function SuggestedMenu:OnShowSuggestedMenu()
	self.tWindowMap["SuggestedMenuContent"]:DestroyChildren()
	self.tResultBtns = {}
	tAlphabatized = {}
	local tNames = self.bFilter and self.tFilteredResults or self:HelperGetAllRelations()
	for key, tSuggestedInfo in pairs(tNames or {}) do
		tSuggestedInfo.strCharacterName = key
		table.insert(tAlphabatized, tSuggestedInfo)
	end

	table.sort(tAlphabatized, function(a,b) return (a.strCharacterName < b.strCharacterName) end)
	for idx, tSuggestedInfo in pairs(tAlphabatized) do
		local strSuggestedSubString = string.sub(tSuggestedInfo.strCharacterName, 1 ,  string.len(self.strLastText))
		if Apollo.StringToLower(strSuggestedSubString) == Apollo.StringToLower(self.strLastText) then --potential result found to be shown, lower so not case sensitive
			self:CreateSuggestedMenuEntry(tSuggestedInfo)
		end
	end
	self.tWindowMap["Title"]:SetText(Apollo.GetString("Friends_SuggestedBtn"))

	if #self.tResultBtns > 0 then
		self.nSuggestedResultPos = 1
		self.tResultBtns[1]:FindChild("EntryName"):SetTextColor(ApolloColor.new("white"))
		local nLeft, nTop, nRight, nBottom = self.tWindowMap["Main"]:GetAnchorOffsets()
		self.tWindowMap["Main"]:SetAnchorOffsets(nLeft, self.nDefaultMenuTop - (math.min(#self.tResultBtns, kMaxShownEntries) * self.nEntrySize), nRight, nBottom)
		self.tWindowMap["SuggestedMenuContent"]:ArrangeChildrenVert()
		self.tWindowMap["Main"]:Invoke()
	else
		--purposely don't show any window if no results are shown
		self:OnSuggestedMenuHide()
	end
end

function SuggestedMenu:CreateSuggestedMenuEntry(tInfo)
	if not self.tResultBtns or not tInfo or not tInfo.strCharacterName then 
		return
	end

	local wndEntryForm = Apollo.LoadForm(self.xmlDoc, "SuggestedMenuEntryForm", self.tWindowMap["SuggestedMenuContent"], self)
	local wndMenuEntry = wndEntryForm:FindChild("SuggestedMenuEntry")
	wndMenuEntry:FindChild("EntryName"):SetText(tInfo.strCharacterName)
	wndMenuEntry:SetData(tInfo)
	table.insert(self.tResultBtns, wndMenuEntry)
end

function SuggestedMenu:OnSuggestedMenuEntry(wndHandler, wndControl)
	if wndHandler ~= wndControl or (self.tWindowMap and not self.tWindowMap["wndTextBox"]) then
		return
	end

	self:OnSuggestedMenuHide()
	Event_FireGenericEvent("SuggestedMenuResult", wndControl:FindChild("SuggestedMenuEntry"):GetData(), self.tWindowMap["wndTextBox"]:GetId())
end
-----------------------------------------------------------------------------------------------
-- SuggestedMenu HelperFunctions
-----------------------------------------------------------------------------------------------
function SuggestedMenu:HelperParseName(strText)
	if not strText then
		return
	end
	local nIndexOfSpace = string.find(strText, "%s")
	if nIndexOfSpace then --may not have a space
		return string.sub(strText, nIndexOfSpace + 1, string.len(strText))
	end
	--no need to parse return original
	return strText
end

function SuggestedMenu:HelperTabThroughSuggestedEntries()
	if self.tResultBtns and self.tResultBtns[self.nSuggestedResultPos] and self.nEntrySize then 
		if #self.tResultBtns == 1 then
			return
		end
		self.tResultBtns[self.nSuggestedResultPos]:FindChild("EntryName"):SetTextColor(ApolloColor.new(kstrColorNonSelectedEntry))
		self.nSuggestedResultPos =  Apollo.IsShiftKeyDown() and self.nSuggestedResultPos - 1 or self.nSuggestedResultPos + 1
		
		local nScrollPosition = self.tWindowMap["SuggestedMenuContent"]:GetVScrollPos()
		if self.nSuggestedResultPos > kMaxShownEntries - 1 then
			self.tWindowMap["SuggestedMenuContent"]:SetVScrollPos(nScrollPosition + self.nEntrySize)
		elseif #self.tResultBtns - self.nSuggestedResultPos >= kMaxShownEntries - 1 then
			self.tWindowMap["SuggestedMenuContent"]:SetVScrollPos(nScrollPosition - self.nEntrySize)
		end

		if self.nSuggestedResultPos > #self.tResultBtns then 
			self.nSuggestedResultPos = 1
			self.tWindowMap["SuggestedMenuContent"]:SetVScrollPos(0)
		elseif self.nSuggestedResultPos <= 0 then
			self.nSuggestedResultPos = #self.tResultBtns
			local nHeight = self.tWindowMap["SuggestedMenuContent"]:GetHeight()
			nScrollPosition = #self.tResultBtns > kMaxShownEntries and  nHeight - self.nEntrySize or nHeight - #self.tResultBtns * self.nEntrySize
			self.tWindowMap["SuggestedMenuContent"]:SetVScrollPos(nScrollPosition)
		end
		self.tResultBtns[self.nSuggestedResultPos]:FindChild("EntryName"):SetTextColor(ApolloColor.new("white"))
	end
end

function SuggestedMenu:HelperIsSuggestedMenuShown()
	return self.tWindowMap and self.tWindowMap["Main"] and self.tWindowMap["Main"]:IsShown()
end

function SuggestedMenu:SetFilters(tFilterIn)
	if not tFilterIn or not next(tFilterIn) then
		self.bFilter = false
		return {}
	end

	self.bFilter = true
	self.tFilteredResults = {}
	
	--Find the tables needed
	local tSets = {}
	--could be an enum representing a table or it could the table already converted
	if tFilterIn.arRelationFilters then
		for idx, oElement in pairs(tFilterIn.arRelationFilters) do
			if type(oElement) == "table" then
				tSets[idx] = self:SetFilters(oElement)
			elseif type(oElement) == "number" then
				tSets[idx]  = self:HelperGetFilterTable(oElement)
			end
		end
	elseif type(tFilterIn) == "table" then --Custom table!
		return tFilterIn
	end

	--Apply operators!
	local tTheResult = {}
	if tFilterIn.eOperator == eSuggestedOperator.And then --wants to have the things in common between sets
		--Scroll through the names in the first set, add the ones that are in all other sets
		for key, tEntry in pairs(tSets[1] or {}) do
			bAddEntry = true
			for idx, tSetInfo in pairs(tSets) do
				if idx ~= 1 then
					if not tSetInfo[key] then
						bAddEntry = false
					end	
				end
			end
			if bAddEntry then
				tTheResult[key] = tEntry
			end
		end
	elseif tFilterIn.eOperator == eSuggestedOperator.Or or not tFilterIn.eOperator then --wants to include all things from both sets
		for idx, tSetInfo in pairs(tSets) do
			for key, tEntry in pairs(tSetInfo) do
				tTheResult[key] = tEntry
			end
		end
	elseif tFilterIn.eOperator == eSuggestedOperator.Not then --wants the opposite of this set
		local tAllRelations = self:HelperGetAllRelations() or {}
		for key, tEntry in pairs(tAllRelations) do
			local bAddEntry = true
			for idx, tSetInfo in pairs(tSets) do
				if tSetInfo[key] then
					bAddEntry = false
				end	
			end
			if bAddEntry then
				tTheResult[key] = tEntry
			end
		end
	end
	self.tFilteredResults = tTheResult
	return tTheResult
end

function SuggestedMenu:HelperGetFilterTable(eRelationType)
	local tFilteredTable = {}
	if eRelationType == eSuggestedRelation.Recent then
		--the keys are the position in queue, so insert them by name and identify that they are recent
		for key, tEntry in pairs(self.tRecent or {}) do
			tEntry.bRecent = true --not used currently, just a helpful identifier that these were from recent
			tFilteredTable[tEntry.strCharacterName] = tEntry
		end
		return tFilteredTable
	end
	
	for key, tEntry in pairs(self.tRelations) do
		if  eRelationType == eSuggestedRelation.Friends 		and tEntry.bFriends or
			eRelationType == eSuggestedRelation.AccountFriends 	and tEntry.bAccountFriends or
			eRelationType == eSuggestedRelation.Groups 			and tEntry.bGroups or
			eRelationType == eSuggestedRelation.Neighbors 		and tEntry.bNeighbors then
				tFilteredTable[key] = tEntry
		end
	end

	return tFilteredTable
end

function SuggestedMenu:HelperGetAllRelations()
	local tAll = {}
	for key, tEntry in pairs(self.tRelations or {}) do
		tAll[key] = tEntry
	end

	for idx, tEntry in pairs(self.tRecent or {}) do
		if tEntry.strCharacterName then
			--setting up default entry for recent in case not already a relation.
			if not tAll[tEntry.strCharacterName] then
				tAll[tEntry.strCharacterName] = {bFriends = false, bAccountFriends = false, bNeighbors = false, bGroups = false,}
			end
			for strInfo, bValue in pairs(tEntry) do
				tAll[tEntry.strCharacterName][strInfo] = bValue
			end
			tAll[tEntry.strCharacterName].bRecent = true
		end
	end
	return tAll
end

-----------------------------------------------------------------------------------------------
-- SuggestedMenu Instance
-----------------------------------------------------------------------------------------------
local SuggestedMenuInst = SuggestedMenu:new()
SuggestedMenuInst:Init()
