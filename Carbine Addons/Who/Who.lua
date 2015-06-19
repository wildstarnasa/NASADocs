-----------------------------------------------------------------------------------------------
-- Client Lua Script for Who
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "ChatSystemLib"
require "Apollo"
require "DialogSys"
require "GameLib"
require "PlayerPathLib"
require "Tooltip"
require "XmlDoc"

local Who = {}
local knSaveVersion = 1
local knDefaultNearbyLimit = 5
local kstrNearbyPlayersQuestMarker = "99WhoNearbyPlayers"

local karSortTypes =
{
	NameAsc			= 1,
	NameDesc		= 2,
	LocationAsc		= 3,
	LocationDesc	= 4,
	LevelAsc		= 5,
	LevelDesc		= 6,
	ClassAsc		= 7,
	ClassDesc		= 8,
	PathAsc			= 9,
	PathDesc		= 10,
}

local ktClassToIcon =
{
	[GameLib.CodeEnumClass.Warrior] 		= "HUD_ClassIcons:spr_Icon_HUD_Class_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "HUD_ClassIcons:spr_Icon_HUD_Class_Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "HUD_ClassIcons:spr_Icon_HUD_Class_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "HUD_ClassIcons:spr_Icon_HUD_Class_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "HUD_ClassIcons:spr_Icon_HUD_Class_Stalker",
	[GameLib.CodeEnumClass.Spellslinger]	= "HUD_ClassIcons:spr_Icon_HUD_Class_Spellslinger",
}

local ktClassToIconPanel =
{
	[GameLib.CodeEnumClass.Warrior] 		= "IconSprites:Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "IconSprites:Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "IconSprites:Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "IconSprites:Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "IconSprites:Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Spellslinger]	= "IconSprites:Icon_Windows_UI_CRB_Spellslinger",
}

local c_arClassStrings =
{
	[GameLib.CodeEnumClass.Warrior] 		= "ClassWarrior",
	[GameLib.CodeEnumClass.Engineer] 		= "ClassEngineer",
	[GameLib.CodeEnumClass.Esper] 			= "ClassESPER",
	[GameLib.CodeEnumClass.Medic] 			= "ClassMedic",
	[GameLib.CodeEnumClass.Stalker] 		= "ClassStalker",
	[GameLib.CodeEnumClass.Spellslinger] 	= "CRB_Spellslinger",
}


local ktPathToIcon = {
	[PlayerPathLib.PlayerPathType_Soldier] 		= "HUD_ClassIcons:spr_Icon_HUD_Path_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "HUD_ClassIcons:spr_Icon_HUD_Path_Settler",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "HUD_ClassIcons:spr_Icon_HUD_Path_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "HUD_ClassIcons:spr_Icon_HUD_Path_Explorer",
}

local ktPathToIconPanel = {
	[PlayerPathLib.PlayerPathType_Soldier] 		= "bk3:UI_Icon_CharacterCreate_Path_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "bk3:UI_Icon_CharacterCreate_Path_Settler",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "bk3:UI_Icon_CharacterCreate_Path_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "bk3:UI_Icon_CharacterCreate_Path_Explorer",
}

local c_arPathStrings = {
	[PlayerPathLib.PlayerPathType_Soldier] 		= "CRB_Soldier",
	[PlayerPathLib.PlayerPathType_Settler] 		= "CRB_Settler",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "CRB_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "CRB_Explorer",
}

function Who:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	
	o.tWndRefs = { }

	return o
end

function Who:Init()
    Apollo.RegisterAddon(self)
end

function Who:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Who.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 	"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("ObjectiveTrackerLoaded", 		"OnObjectiveTrackerLoaded", self)
	
	Apollo.RegisterEventHandler("PlayerCreated", 				"Initialize", self)
	Apollo.RegisterEventHandler("CharacterCreated", 			"Initialize", self)
	Apollo.RegisterEventHandler("UnitCreated", 					"OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", 				"OnUnitDestroyed", self)
	Apollo.RegisterEventHandler("WhoResponse", 					"OnWhoResponse", self)
	
	Apollo.RegisterEventHandler("FriendshipUpdate", 			"HelperDelayResetUI", self)
	Apollo.RegisterEventHandler("FriendshipRemove", 			"HelperDelayResetUI", self)
	
	Apollo.RegisterEventHandler("Group_Join", 					"HelperDelayResetUI", self)
	Apollo.RegisterEventHandler("Group_Left", 					"HelperDelayResetUI", self)
	Apollo.RegisterEventHandler("Group_FlagsChanged", 			"HelperDelayResetUI", self)
	
	self.wndObjectiveTracker = nil
	self.nWhoSort = karSortTypes.NameAsc
	self.nNearbySort = karSortTypes.NameAsc
	self.nLimitPreference = knDefaultNearbyLimit
	self.nLimit = knDefaultNearbyLimit
	self.bFormLoaded = false
	self.bObjectiveTrackerLoaded = false
	self.bShowSearchResults = true
	self.bShowNearbyPlayers = true
	self.bMinimized = false
	self.bFloating = false
	self.tNearbyPlayers = {}
	self.tWhoPlayers = {}
	
	self.bTimerRunning = false
	self.timer = ApolloTimer.Create(5, true, "OnTimer", self)
	self.timer:Stop()
	
	Event_FireGenericEvent("ObjectiveTracker_RequestParent")
end

function Who:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSave =
	{
		nSaveVersion = knSaveVersion,
		bMinimized = self.bMinimized,
		bFloating = self.bFloating,
		bShowNearbyPlayers = self.bShowNearbyPlayers,
		nWhoSort = self.nWhoSort,
		nNearbySort = self.nNearbySort,
		nLimitPreference = self.nLimitPreference,
	}

	return tSave
end

function Who:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character and tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bMinimized = tSavedData.bMinimized
		self.bFloating = tSavedData.bFloating
		self.bShowNearbyPlayers = tSavedData.bShowNearbyPlayers
		self.nWhoSort = tSavedData.nWhoSort or karSortTypes.NameAsc
		self.nNearbySort = tSavedData.nNearbySort or karSortTypes.NameAsc
		self.nLimitPreference = tSavedData.nLimitPreference or knDefaultNearbyLimit
		self.nLimit = self.bShowNearbyPlayers and self.nLimitPreference or 0
	end
end

function Who:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end
	
	Apollo.RegisterEventHandler("ChangeWorld", 				"HelperDelayResetUI", self)
	Apollo.RegisterEventHandler("SubZoneChanged",			"HelperDelayResetUI", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("WindowManagementUpdate", 	"OnWindowManagementUpdate", self)
	Apollo.RegisterEventHandler("ToggleWhoWindow", 			"OnWhoButtonClicked", self)
	Apollo.RegisterEventHandler("ToggleShowNearbyPlayers", 	"OnToggleShowNearbyPlayers", self)
	
	self:Initialize()
	
	return true
end

function Who:OnInterfaceMenuListHasLoaded()
	local tData = {
		"ToggleWhoWindow", 
		"", 
		"Icon_Windows32_UI_CRB_InterfaceMenu_Social"
	}
	
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("Who_WindowTitle"), tData)
end

function Who:OnObjectiveTrackerLoaded(wndForm)
	self.wndObjectiveTracker = wndForm
	
	local tData = {
		["strAddon"]				= Apollo.GetString("Who_NearbyPlayers"),
		["strEventMouseLeft"]	= "ToggleShowNearbyPlayers", 
		["strEventMouseRight"]	= "ToggleWhoWindow", 
		["strIcon"]					= "spr_ObjectiveTracker_IconNearbyPlayers",
		["strDefaultSort"]			= kstrNearbyPlayersQuestMarker,
	}
	
	Event_FireGenericEvent("ObjectiveTracker_NewAddOn", tData)
	
	if not self.tWndRefs.wndTrackerHeader or self.tWndRefs.wndTrackerHeader and self.tWndRefs.wndTrackerHeader:GetParent() == nil then
		self:HelperAttachToObjectiveTracker()
	end
	
	if self.bFormLoaded then
		self:HelperDelayResetUI()
	else
		self:Initialize()
	end
end

function Who:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", 
		{
			wnd = self.tWndRefs.wndMain, 
			strName = Apollo.GetString("Who_WindowTitle"), 
			nSaveVersion = 1
		}
	)
	
	Event_FireGenericEvent("WindowManagementAdd", 
		{
			wnd = self.tWndRefs.wndPlayerForm, 
			strName = Apollo.GetString("Who_NearbyFloater"), 
			nSaveVersion = 1
		}
	)
end

function Who:Initialize()
	if GameLib:GetPlayerUnit() == nil or self.bFormLoaded then
		return
	end
	
	self:HelperLoadForms()
	
	self.tWndRefs.wndMain:SetSizingMinimum(500, 500)
	self.tWndRefs.wndMain:Show(false)
	
	self.tWndRefs.wndShowNearbyPlayers:SetCheck(self.nLimit > 0)
	self.tWndRefs.wndShowOnHUDLimit:SetText(self.nLimit)
	
	self.bMoveable = self.tWndRefs.wndPlayerForm:IsStyleOn("Moveable")
	
	self:HelperResetUI()
end

function Who:OnWindowManagementUpdate(tSettings)
	local bOldMoveable = self.bMoveable

	if tSettings and tSettings.wnd and tSettings.wnd:IsValid() and tSettings.wnd == self.tWndRefs.wndPlayerForm then
		self.bMoveable = self.tWndRefs.wndPlayerForm:IsStyleOn("Moveable")
		
		self.tWndRefs.wndPlayerForm:SetSprite(self.bMoveable and "BK3:UI_BK3_Holo_InsetFlyout" or "")
		self.tWndRefs.wndPlayerForm:SetStyle("IgnoreMouse", not self.bMoveable)
	end
end

function Who:HelperLoadForms()
	self:HelperDestroyForms()
	
	self.tWndRefs.wndMain 				= Apollo.LoadForm(self.xmlDoc, "WhoForm", nil, self)
	self.tWndRefs.wndMainContent		= self.tWndRefs.wndMain:FindChild("Content")
	self.tWndRefs.wndNearbyPlayers		= self.tWndRefs.wndMain:FindChild("btnNearbyPlayers")
	self.tWndRefs.wndSearchResults		= self.tWndRefs.wndMain:FindChild("btnSearchResults")
	self.tWndRefs.wndShowNearbyPlayers	= self.tWndRefs.wndMain:FindChild("btnShowNearbyPlayers")
	self.tWndRefs.wndShowOnHUDLimit 	= self.tWndRefs.wndMain:FindChild("ShowOnHUDLimitEditBox")
	
	self.tWndRefs.wndMainWhoContent		= self.tWndRefs.wndMain:FindChild("Controls_Who")
	self.tWndRefs.wndMainNearbyContent	= self.tWndRefs.wndMain:FindChild("Controls_Nearby")
	
	self.tWndRefs.wndPlayerForm 		= Apollo.LoadForm(self.xmlDoc, "PlayerForm", "FixedHudStratum", self)
	self.tWndRefs.wndPlayerFormContent 	= self.tWndRefs.wndPlayerForm:FindChild("Content")
	
	self.tWndRefs.wndFormWhoHeader 		= self:FactoryProduce(self.tWndRefs.wndMainContent, "FormHeader", "NearbyPlayersFormHeader")
	self.tWndRefs.wndFormWhoContent		= self.tWndRefs.wndFormWhoHeader:FindChild("EpisodeGroupContainer")
	self.tWndRefs.wndFormWhoTitle 		= self.tWndRefs.wndFormWhoHeader:FindChild("EpisodeGroupTitle")
	
	self.tWndRefs.wndFormNearbyHeader 	= self:FactoryProduce(self.tWndRefs.wndMainContent, "FormHeader", "NearbyPlayersFormHeader")
	self.tWndRefs.wndFormNearbyContent	= self.tWndRefs.wndFormNearbyHeader:FindChild("EpisodeGroupContainer")
	self.tWndRefs.wndFormNearbyTitle 	= self.tWndRefs.wndFormNearbyHeader:FindChild("EpisodeGroupTitle")
	
	self.tWndRefs.wndFloaterHeader		= self:FactoryProduce(self.tWndRefs.wndPlayerFormContent, "TrackerHeader", "NearbyPlayersFloaterHeader")
	self.tWndRefs.wndFloaterContent 	= self.tWndRefs.wndFloaterHeader:FindChild("EpisodeGroupContainer")
	self.tWndRefs.wndFloaterTitle 		= self.tWndRefs.wndFloaterHeader:FindChild("EpisodeGroupTitle")
	self.knInitialEpisodeGroupHeight 	= self.tWndRefs.wndFloaterHeader:GetHeight()
	
	self.tWndRefs.wndMinimizeFloater 	= self.tWndRefs.wndFloaterHeader:FindChild("EpisodeGroupMinimizeBtn")
	self.tWndRefs.wndPopoutFloater 		= self.tWndRefs.wndFloaterHeader:FindChild("EpisodeGroupPopoutBtn")
	
	self:HelperAttachToObjectiveTracker()
	
	self.bFormLoaded = true
end

function Who:HelperAttachToObjectiveTracker()
	if not self.wndObjectiveTracker or not self.wndObjectiveTracker:IsValid() then
		return
	end
	
	self.tWndRefs.wndTrackerHeader		= self:FactoryProduce(self.wndObjectiveTracker, "TrackerHeader", kstrNearbyPlayersQuestMarker)
	
	self.tWndRefs.wndTrackerContent		= self.tWndRefs.wndTrackerHeader:FindChild("EpisodeGroupContainer")
	self.tWndRefs.wndTrackerTitle		= self.tWndRefs.wndTrackerHeader:FindChild("EpisodeGroupTitle")
	
	self.tWndRefs.wndMinimizeTracker 	= self.tWndRefs.wndTrackerHeader:FindChild("EpisodeGroupMinimizeBtn")
	self.tWndRefs.wndPopoutTracker		= self.tWndRefs.wndTrackerHeader:FindChild("EpisodeGroupPopoutBtn")
	
	self.bObjectiveTrackerLoaded = true
end

function Who:HelperDestroyForms()
	self.bFormLoaded = false
	
	for _, wnd in pairs(self.tWndRefs) do
		wnd:Destroy()
	end
	
	self.tWndRefs = { }
end

function Who:OnTimer()
	self:HelperResetUI()
end

function Who:OnUnitCreated(unit)
	if unit:GetType() == "Player" then
		self.tNearbyPlayers[unit:GetName()] = unit
		
		self:HelperDelayResetUI()
	end
end

function Who:OnUnitDestroyed(unit)
	if unit:GetType() == "Player" then
		self.tNearbyPlayers[unit:GetName()] = nil
		
		self:HelperDelayResetUI()
	end
end

function Who:OnWhoResponse(arResponse, eWhoResult, strResponse)	
	if eWhoResult == GameLib.CodeEnumWhoResult.OK or eWhoResult == GameLib.CodeEnumWhoResult.Partial then
		self.tWhoPlayers = arResponse
	elseif eWhoResult == GameLib.CodeEnumWhoResult.UnderCooldown then
		--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, Apollo.GetString("Who_UnderCooldown"), "")
	end
	
	self.bShowSearchResults = true
	self:HelperResetUI()
	self.tWndRefs.wndMain:Show(true)
end

function Who:OnWhoButtonClicked(wndHandler, wndControl)
	self.bShowSearchResults = false
	
	self:HelperResetUI()
	self.tWndRefs.wndMain:Show(not self.tWndRefs.wndMain:IsShown())
end

function Who:OnToggleShowNearbyPlayers()
	self.bShowNearbyPlayers = not self.bShowNearbyPlayers
	self.nLimit = self.bShowNearbyPlayers and self.nLimitPreference or 0
	
	self:HelperResetUI()
end

function Who:OnCancel(wndHandler, wndControl)
	self.tWndRefs.wndMain:Close()
end

function Who:OnSearchResultsContent(wndHandler, wndControl)
	self.bShowSearchResults = true
	
	self:HelperResetUI()
end

function Who:OnNearbyPlayersContent(wndHandler, wndControl)
	self.bShowSearchResults = false
	
	self:HelperResetUI()
end

function Who:HelperDelayResetUI()
	if not self.bTimerRunning then
		self.bTimerRunning = true
		self.timer:Start()
	end
end

function Who:HelperResetUI()
	self.bTimerRunning = false
	self.timer:Stop()
	
	local nWhoCount = 0
	local nPlayerCount = 0
	local nRivals = 0
	local strHeaderText = ""
	
	--Override floating pref if quest tracker isn't loaded.
	local bFloating = self.bFloating or not self.bObjectiveTrackerLoaded
	
	self.tWndRefs.wndShowNearbyPlayers:SetCheck(self.nLimit > 0)
	self.tWndRefs.wndShowOnHUDLimit:SetText(self.nLimit)
	
	self.tWndRefs.wndFormWhoContent:DestroyChildren()
	self.tWndRefs.wndFormNearbyContent:DestroyChildren()
	self.tWndRefs.wndFloaterContent:DestroyChildren()
	
	self.tWndRefs.wndMinimizeFloater:SetCheck(self.bMinimized)
	self.tWndRefs.wndPopoutFloater:SetCheck(bFloating)
	
	if self.bObjectiveTrackerLoaded then
		self.tWndRefs.wndTrackerContent:DestroyChildren()
		
		self.tWndRefs.wndMinimizeTracker:Show(self.bMinimized)
		self.tWndRefs.wndMinimizeTracker:SetCheck(self.bMinimized)
		self.tWndRefs.wndPopoutTracker:SetCheck(bFloating)
	end
	
	--Display /who results
	if self.bShowSearchResults then
		self.tWndRefs.wndFormNearbyHeader:Show(false)
		
		--Sorting
		if self.nWhoSort == karSortTypes.NameAsc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.strName < b.strName) end)
		elseif self.nWhoSort == karSortTypes.NameDesc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.strName > b.strName) end)
		elseif self.nWhoSort == karSortTypes.ClassAsc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.eClassId < b.eClassId) end)
		elseif self.nWhoSort == karSortTypes.ClassDesc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.eClassId > b.eClassId) end)
		elseif self.nWhoSort == karSortTypes.LevelAsc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.nLevel < b.nLevel) end)
		elseif self.nWhoSort == karSortTypes.LevelDesc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.nLevel > b.nLevel) end)
		elseif self.nWhoSort == karSortTypes.PathAsc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.ePlayerPathType < b.ePlayerPathType) end)
		elseif self.nWhoSort == karSortTypes.PathDesc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.ePlayerPathType > b.ePlayerPathType) end)
		elseif self.nWhoSort == karSortTypes.LocationAsc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.strZone..a.strSubZone < b.strZone..b.strSubZone) end)
		elseif self.nWhoSort == karSortTypes.LocationDesc then
			table.sort(self.tWhoPlayers, function(a,b) return (a.strZone..a.strSubZone > b.strZone..b.strSubZone) end)
		end
		
		for _, tResult in ipairs(self.tWhoPlayers) do
			nWhoCount = nWhoCount + 1
			
			local strClassIconSprite = ktClassToIconPanel[tResult.eClassId] or ""
			local strClass = Apollo.GetString(c_arClassStrings[tResult.eClassId]) or ""
			local strPathIconSprite = ktPathToIconPanel[tResult.ePlayerPathType] or ""
			local strPathType = Apollo.GetString(c_arPathStrings[tResult.ePlayerPathType]) or ""
			
			
			local strSubZone = tResult.strSubZone or nil
			local strLocation = strSubZone and string.format("%s: %s", tResult.strZone, strSubZone) or tResult.strZone
			
			local wndFormWhoListItem = self:FactoryProduce(self.tWndRefs.wndFormWhoContent, "WhoListItem", tResult)
			wndFormWhoListItem:FindChild("ListItemBig"):SetBGColor(ApolloColor.new(nWhoCount % 2 == 1 and "33ffffff" or "00ffffff"))
			wndFormWhoListItem:FindChild("ListItemName"):SetText(tResult.strName)
			wndFormWhoListItem:FindChild("ListItemLocation"):SetText(strLocation)
			wndFormWhoListItem:FindChild("ListItemIcon"):SetSprite(strClassIconSprite)
			wndFormWhoListItem:FindChild("ListItemIcon"):SetTooltip(strClass)
			wndFormWhoListItem:FindChild("ListItemLevel"):SetText(tostring(tResult.nLevel))
			wndFormWhoListItem:FindChild("ListItemPathIcon"):SetSprite(strPathIconSprite)
			wndFormWhoListItem:FindChild("ListItemPathIcon"):SetTooltip(strPathType)
		end
		
		local strHeaderText = nWhoCount ~= 1 and String_GetWeaselString(Apollo.GetString("Who_Results"), nWhoCount) or Apollo.GetString("Who_SearchResults")
		self.tWndRefs.wndFormWhoTitle:SetText(strHeaderText)
		
		self:OnResizeContainer(self.tWndRefs.wndFormWhoHeader, true)
		self.tWndRefs.wndFormWhoHeader:Show(nWhoCount > 0)
	else
		self.tWndRefs.wndFormWhoHeader:Show(false)
	end
	
	local tNearbyPlayers = { }
	for unitName, unit in pairs(self.tNearbyPlayers) do
		if not unit:IsInYourGroup() and not unit:IsThePlayer() then
			table.insert(tNearbyPlayers, unit)
		end
	end
	
	nPlayerCount = #tNearbyPlayers
	
	--Display nearby players
	if not self.bShowSearchResults or self.bShowNearbyPlayers then
		--Sorting
		if self.nNearbySort == karSortTypes.NameAsc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetName() < b:GetName()) end)
		elseif self.nNearbySort == karSortTypes.NameDesc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetName() > b:GetName()) end)
		elseif self.nNearbySort == karSortTypes.ClassAsc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetClassId() < b:GetClassId()) end)
		elseif self.nNearbySort == karSortTypes.ClassDesc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetClassId() > b:GetClassId()) end)
		elseif self.nNearbySort == karSortTypes.LevelAsc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetLevel() < b:GetLevel()) end)
		elseif self.nNearbySort == karSortTypes.LevelDesc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetLevel() > b:GetLevel()) end)
		elseif self.nNearbySort == karSortTypes.PathAsc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetPlayerPathType() < b:GetPlayerPathType()) end)
		elseif self.nNearbySort == karSortTypes.PathDesc then
			table.sort(tNearbyPlayers, function(a,b) return (a:GetPlayerPathType() > b:GetPlayerPathType()) end)
		end
		
		local nRowCount = 0
		local unitPlayer = GameLib:GetPlayerUnit()
		for unitName, unit in ipairs(tNearbyPlayers) do
			nRowCount = nRowCount + 1
			local strClassIconSprite = ktClassToIconPanel[unit:GetClassId()] or ""
			local strClass = c_arClassStrings[unit:GetClassId()] and Apollo.GetString(c_arClassStrings[unit:GetClassId()]) or ""
			local nPathId = unit and unit:IsValid() and unit:GetPlayerPathType() > 0 and unit:GetPlayerPathType() or 0
			local strPathIconSprite = ktPathToIconPanel[nPathId] or ""
			local strPathType = c_arPathStrings[nPathId] and Apollo.GetString(c_arPathStrings[nPathId]) or ""
			local strLocation = tostring(math.ceil(math.abs(unit:GetPosition().x - unitPlayer:GetPosition().x)))
			local strColor = ApolloColor.new(unit:GetDispositionTo(unitPlayer) == Unit.CodeEnumDisposition.Hostile and "DispositionHostile" or "UI_BtnTextHoloNormal")
			
			local wndFormListItem = self:FactoryProduce(self.tWndRefs.wndFormNearbyContent, "FormNearbyListItem", unit)
			wndFormListItem:FindChild("ListItemBig"):SetBGColor(ApolloColor.new(nRowCount % 2 == 1 and "33ffffff" or "00ffffff"))
			wndFormListItem:FindChild("ListItemBigBtn"):SetData(unit)
			wndFormListItem:FindChild("ListItemName"):SetText(unit:GetName())
			wndFormListItem:FindChild("ListItemName"):SetTextColor(strColor)
			wndFormListItem:FindChild("ListItemIcon"):SetSprite(strClassIconSprite)
			wndFormListItem:FindChild("ListItemIcon"):SetTooltip(strClass)
			wndFormListItem:FindChild("ListItemLevel"):SetText(unit:GetLevel())
			wndFormListItem:FindChild("ListItemPathIcon"):SetSprite(strPathIconSprite)
			wndFormListItem:FindChild("ListItemPathIcon"):SetTooltip(strPathType)
		end
		
		local tTrackerNearbyPlayers = { }
		local nTrackerLimit = self.nLimit
		--table.sort(self.tNearbyPlayers, function(a,b) return (math.abs(a:GetPosition().x - GameLib:GetPlayerUnit():GetPosition().x) < math.abs(b:GetPosition().x - GameLib:GetPlayerUnit():GetPosition().x)) end)
		for unitName, unit in ipairs(tNearbyPlayers) do
			if nTrackerLimit > 0 then
				nTrackerLimit = nTrackerLimit - 1
				table.insert(tTrackerNearbyPlayers, unit)
			end
		end
		
		local wndParent = bFloating and self.tWndRefs.wndFloaterHeader or self.tWndRefs.wndTrackerHeader
		local wndParentContent = bFloating and self.tWndRefs.wndFloaterContent or self.tWndRefs.wndTrackerContent
		for unitName, unit in ipairs(tTrackerNearbyPlayers) do
			local strClassIconSprite = ktClassToIcon[unit:GetClassId()] or ""
			local strClass = c_arClassStrings[unit:GetClassId()] and Apollo.GetString(c_arClassStrings[unit:GetClassId()]) or ""
			local nPathId = unit and unit:IsValid() and unit:GetPlayerPathType() > 0 and unit:GetPlayerPathType() or 0
			local strPathIconSprite = ktPathToIcon[nPathId] or ""
			local strPathType = c_arPathStrings[nPathId] and Apollo.GetString(c_arPathStrings[nPathId]) or ""
			local strLocation = tostring(math.ceil(math.abs(unit:GetPosition().x - unitPlayer:GetPosition().x)))
			local strColor = ApolloColor.new(unit:GetDispositionTo(unitPlayer) == Unit.CodeEnumDisposition.Hostile and "DispositionHostile" or "ffffffff")
			local strRivalSprite = unit:IsRival() and "IconSprites:Icon_Windows_UI_CRB_Rival" or unit:IsAccountFriend() and "IconSprites:Icon_Windows_UI_CRB_Friend" or unit:IsFriend() and "IconSprites:Icon_Windows_UI_CRB_Friend" or ""
			nRivals = unit:IsRival() and nRivals + 1 or nRivals + 0
			
			local wndTrackerListItem = self:FactoryProduce(wndParentContent, "TrackerListItem", unit)
			wndTrackerListItem:FindChild("ListItemBigBtn"):SetData(unit)
			wndTrackerListItem:FindChild("ListItemName"):SetText(unit:GetName())
			wndTrackerListItem:FindChild("ListItemName"):SetTextColor(strColor)
			wndTrackerListItem:FindChild("ListItemIcon"):SetSprite(strClassIconSprite)
			wndTrackerListItem:FindChild("ListItemIcon"):SetTooltip(strClass)
			wndTrackerListItem:FindChild("ListItemLevel"):SetText(unit:GetLevel())
			wndTrackerListItem:FindChild("ListItemPathIcon"):SetSprite(strPathIconSprite)
			wndTrackerListItem:FindChild("ListItemPathIcon"):SetTooltip(strPathType)
			wndTrackerListItem:FindChild("ListItemRivalIcon"):SetSprite(strRivalSprite)
		end
		
		strHeaderText = #tNearbyPlayers > #tTrackerNearbyPlayers and String_GetWeaselString(Apollo.GetString("QuestTracker_NearbyPlayersLimited"), #tTrackerNearbyPlayers, #tNearbyPlayers) or String_GetWeaselString(Apollo.GetString("QuestTracker_NearbyPlayers"), #tTrackerNearbyPlayers)
		self.tWndRefs.wndFloaterTitle:SetText(strHeaderText)
		self.tWndRefs.wndFormNearbyTitle:SetText(strHeaderText)
		
		local nHeight = self:OnResizeContainer(wndParent, self.bShowNearbyPlayers)
		local bShowTracker = self.bShowNearbyPlayers and #tTrackerNearbyPlayers > 0
		self.tWndRefs.wndFloaterHeader:Show(bFloating and bShowTracker)
		
		if self.bObjectiveTrackerLoaded then
			self.tWndRefs.wndTrackerTitle:SetText(strHeaderText)
			self.tWndRefs.wndTrackerHeader:Show(not bFloating and bShowTracker)
		end
		
		if bFloating then
			local nLeft, nTop, nRight, nBottom = self.tWndRefs.wndPlayerFormContent:GetAnchorOffsets()
			self.tWndRefs.wndPlayerFormContent:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight)
			self.tWndRefs.wndPlayerForm:RecalculateContentExtents()
		end
		
		self:OnResizeContainer(self.tWndRefs.wndFormNearbyHeader, true)
		self.tWndRefs.wndFormNearbyHeader:Show(not self.bShowSearchResults and #tNearbyPlayers > 0)
		self.tWndRefs.wndPlayerForm:Show(bFloating and #tTrackerNearbyPlayers > 0)
	else
		if self.tWndRefs.wndTrackerHeader then
			self.tWndRefs.wndTrackerHeader:Show(false)
		end
	end
	
	self.tWndRefs.wndMainContent:ArrangeChildrenVert()
	self.tWndRefs.wndMainWhoContent:Show(self.bShowSearchResults)
	self.tWndRefs.wndMainNearbyContent:Show(not self.bShowSearchResults)
	
	self.tWndRefs.wndSearchResults:SetCheck(self.bShowSearchResults)
	self.tWndRefs.wndSearchResults:FindChild("SplashBtnAlert"):Show(#self.tWhoPlayers > 0)
	self.tWndRefs.wndSearchResults:FindChild("SplashBtnItemCount"):SetText(tostring(#self.tWhoPlayers))
	
	self.tWndRefs.wndNearbyPlayers:SetCheck(not self.bShowSearchResults)
	self.tWndRefs.wndNearbyPlayers:FindChild("SplashBtnAlert"):Show(nPlayerCount > 0)
	self.tWndRefs.wndNearbyPlayers:FindChild("SplashBtnItemCount"):SetText(tostring(nPlayerCount))
	
	local tData = {
		["strAddon"]	= Apollo.GetString("Who_NearbyPlayers"),
		["strText"]		= nPlayerCount,
		["bAlert"]		= nRivals > 0,
		["bChecked"]	= self.bShowNearbyPlayers,
		["bEnabled"]	= nPlayerCount > 0,
	}

	Event_FireGenericEvent("ObjectiveTracker_UpdateAddOn", tData)
end

function Who:OnWhoSortToggle(wndHandler, wndControl)	
	--Class
	if self.tWndRefs.wndMainWhoContent:FindChild("SortBtnClass"):IsChecked() then
		if self.nWhoSort == karSortTypes.ClassAsc then
			self.nWhoSort = karSortTypes.ClassDesc
			self.tWndRefs.wndMainWhoContent:FindChild("SortBtnClass"):SetCheck(true)
		else
			self.nWhoSort = karSortTypes.ClassAsc
		end
	end
	if self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnClass"):IsChecked() then
		if self.nNearbySort == karSortTypes.ClassAsc then
			self.nNearbySort = karSortTypes.ClassDesc
			self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnClass"):SetCheck(true)
		else
			self.nNearbySort = karSortTypes.ClassAsc
		end
	end
	
	--Level
	if self.tWndRefs.wndMainWhoContent:FindChild("SortBtnLevel"):IsChecked() then
		if self.nWhoSort == karSortTypes.LevelAsc then
			self.nWhoSort = karSortTypes.LevelDesc
			self.tWndRefs.wndMainWhoContent:FindChild("SortBtnLevel"):SetCheck(true)
		else
			self.nWhoSort = karSortTypes.LevelAsc
		end
	end
	if self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnLevel"):IsChecked() then
		if self.nNearbySort == karSortTypes.LevelAsc then
			self.nNearbySort = karSortTypes.LevelDesc
			self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnLevel"):SetCheck(true)
		else
			self.nNearbySort = karSortTypes.LevelAsc
		end
	end
	
	--Location
	if self.tWndRefs.wndMainWhoContent:FindChild("SortBtnLocation"):IsChecked() then
		if self.nWhoSort == karSortTypes.LocationAsc then
			self.nWhoSort = karSortTypes.LocationDesc
			self.tWndRefs.wndMainWhoContent:FindChild("SortBtnLocation"):SetCheck(true)
		else
			self.nWhoSort = karSortTypes.LocationAsc
		end
	end
	
	--Name
	if self.tWndRefs.wndMainWhoContent:FindChild("SortBtnName"):IsChecked() then
		if self.nWhoSort == karSortTypes.NameAsc then
			self.nWhoSort = karSortTypes.NameDesc
			self.tWndRefs.wndMainWhoContent:FindChild("SortBtnName"):SetCheck(true)
		else
			self.nWhoSort = karSortTypes.NameAsc
		end
	end
	if self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnName"):IsChecked() then
		if self.nNearbySort == karSortTypes.NameAsc then
			self.nNearbySort = karSortTypes.NameDesc
			self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnName"):SetCheck(true)
		else
			self.nNearbySort = karSortTypes.NameAsc
		end
	end
	
	--Path
	if self.tWndRefs.wndMainWhoContent:FindChild("SortBtnPath"):IsChecked() then
		if self.nWhoSort == karSortTypes.PathAsc then
			self.nWhoSort = karSortTypes.PathDesc
			self.tWndRefs.wndMainWhoContent:FindChild("SortBtnPath"):SetCheck(true)
		else
			self.nWhoSort = karSortTypes.PathAsc
		end
	end
	if self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnPath"):IsChecked() then
		if self.nNearbySort == karSortTypes.PathAsc then
			self.nNearbySort = karSortTypes.PathDesc
			self.tWndRefs.wndMainNearbyContent:FindChild("SortBtnPath"):SetCheck(true)
		else
			self.nNearbySort = karSortTypes.PathAsc
		end
	end
	
	self:HelperResetUI()
end

function Who:OnResizeContainer(wndEpisodeGroup, bIsShown)
	local nOngoingGroupHeight = bIsShown and self.knInitialEpisodeGroupHeight or 0
	
	if not wndEpisodeGroup or not wndEpisodeGroup:IsValid() then
		return nOngoingGroupHeight
	end
	
	local wndEpisodeGroupContainer = wndEpisodeGroup:FindChild("EpisodeGroupContainer")
	local wndMinimize = wndEpisodeGroup:FindChild("EpisodeGroupMinimizeBtn")
	
	if bIsShown and (wndMinimize == nil or (wndMinimize and not wndMinimize:IsChecked())) then
		for idx, wndChild in pairs(wndEpisodeGroupContainer:GetChildren()) do
			nOngoingGroupHeight = nOngoingGroupHeight + wndChild:GetHeight()
		end
	end

	wndEpisodeGroupContainer:ArrangeChildrenVert(0)
	
	local nLeft, nTop, nRight, nBottom = wndEpisodeGroup:GetAnchorOffsets()
	wndEpisodeGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOngoingGroupHeight)
	wndEpisodeGroupContainer:Show(bIsShown)
	wndEpisodeGroupContainer:RecalculateContentExtents()
	
	return nOngoingGroupHeight
end

function Who:OnShowNearbyPlayersChecked(wndHandler, wndControl)
	self.nLimit = wndControl:IsChecked() and self.nLimitPreference or 0
	self.bShowNearbyPlayers = self.nLimit > 0
	
	self:HelperResetUI()
end

function Who:OnShowNearbyPlayersChanged(wndHandler, wndControl)
	self.nLimit = tonumber(wndControl:GetText()) or 0
	self.nLimitPreference = self.nLimit
	
	self:HelperResetUI()
end

function Who:OnEpisodeGroupControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("EpisodeGroupMinimizeBtn"):Show(true)
		wndHandler:FindChild("EpisodeGroupPopoutBtn"):Show(self.bObjectiveTrackerLoaded)
	end
end

function Who:OnEpisodeGroupControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		local wndBtn = wndHandler:FindChild("EpisodeGroupMinimizeBtn")
		wndBtn:Show(wndBtn:IsChecked())
		wndHandler:FindChild("EpisodeGroupPopoutBtn"):Show(false)
	end
end

function Who:OnEpisodeGroupMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	self.bMinimized = true
	
	self:HelperResetUI()
end

function Who:OnEpisodeGroupMinimizedBtnUnChecked(wndHandler, wndControl, eMouseButton)
	self.bMinimized = false
	
	self:HelperResetUI()
end

function Who:OnEpisodeGroupDockBtnChecked(wndHandler, wndControl, eMouseButton)
	self.bFloating = true
	
	self:HelperResetUI()
end

function Who:OnEpisodeGroupDockBtnUnChecked(wndHandler, wndControl, eMouseButton)
	self.bFloating = false
	
	self:HelperResetUI()
end

-----------------------------------------------------------------------------------------------
-- UI Events/Buttons
-----------------------------------------------------------------------------------------------

function Who:OnListItemMouseEnter(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
end

function Who:OnListItemMouseExit(wndHandler, wndControl)
	-- Has Mouse
	local bHasMouse = wndControl:GetParent():FindChild("ListItemMouseCatcher"):ContainsMouse()
	
	wndControl:GetParent():FindChild("ListItemHintArrowArt"):Show(bHasMouse)
end

function Who:OnListItemClicked(wndHandler, wndControl, eMouseButton, x, y)
	if not wndHandler or not wndHandler:GetData() then
		return
	end
	
	local unit = wndHandler:GetData()
	
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", nil, unit:GetName(), unit)
	else
		GameLib.SetTargetUnit(unit)
		unit:ShowHintArrow()
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function Who:FactoryProduce(wndParent, strFormName, oObject)
	local wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
	wnd:SetData(oObject)
	
	return wnd
end

local WhoInst = Who:new()
WhoInst:Init()